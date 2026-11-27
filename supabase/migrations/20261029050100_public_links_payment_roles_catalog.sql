-- Revisão de funções de 29 out, parte 2 (links públicos, cobrança, catálogo, auditoria).
-- Encoding: UTF-8.
-- get_anamnese_by_token / submit_anamnese_signature: search_path vazio e nomes
--   qualificados; sem respostas nem assinatura depois de assinada ou vencida; limites
--   de tamanho e formato no envio.
-- confirm_payment_request: crédito só pela gestão (antes a recepção passava e a
--   confirmação falhava lá dentro, em adjust_client_balance_atomic).
-- prevent_used_catalog_item_delete: compara item_type sem diferenciar maiúsculas
--   (comandas gravam 'service').
-- audit_logs: visualizadora não grava auditoria.
set client_encoding = 'UTF8';

CREATE OR REPLACE FUNCTION public.get_anamnese_by_token(p_token text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  -- Link público: perguntas e respostas só enquanto a ficha está pendente e no prazo.
  -- Assinada ou vencida, devolve só o que a tela de confirmação usa (sem respostas
  -- nem assinatura), para o link não virar acesso permanente a dado de saúde (LGPD/RGPD).
  select jsonb_build_object(
    'id',                 a.id,
    'status',             a.status,
    'client_name',        a.client_name,
    'org_name',           o.name,
    'template_title',     a.template_title,
    'questions',          case when v.open then coalesce(a.template_snapshot->'questions', '[]'::jsonb) else '[]'::jsonb end,
    'answers',            case when v.open then coalesce(a.answers, '{}'::jsonb) else '{}'::jsonb end,
    'consent_text',       case when v.open then a.consent_text end,
    'consent_version',    a.consent_version,
    'signature_name',     null,
    'signature_data_url', null,
    'signed_at',          a.signed_at,
    'expired',            v.expired
  )
  from public.anamneses a
  join public.organizations o on o.id = a.org_id
  cross join lateral (
    select (a.token_expires_at is not null and a.token_expires_at < pg_catalog.now()) as expired
  ) e
  cross join lateral (
    select e.expired, (a.status <> 'signed' and not e.expired) as open
  ) v
  where p_token is not null
    and pg_catalog.length(p_token) between 16 and 200
    and a.public_token = p_token;
$function$;

CREATE OR REPLACE FUNCTION public.submit_anamnese_signature(p_token text, p_answers jsonb, p_signature_name text, p_signature_data_url text, p_consent_accepted boolean, p_user_agent text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v public.anamneses;
begin
  if p_token is null or pg_catalog.length(p_token) not between 16 and 200 then
    return pg_catalog.jsonb_build_object('error','not_found');
  end if;
  select * into v from public.anamneses where public_token = p_token for update;
  if not found then return pg_catalog.jsonb_build_object('error','not_found'); end if;
  if v.status = 'signed' then return pg_catalog.jsonb_build_object('error','already_signed'); end if;
  if v.token_expires_at is not null and v.token_expires_at < pg_catalog.now() then
    return pg_catalog.jsonb_build_object('error','expired');
  end if;
  if coalesce(p_consent_accepted,false) = false then
    return pg_catalog.jsonb_build_object('error','consent_required');
  end if;
  if p_signature_data_url is null or pg_catalog.length(p_signature_data_url) < 50 then
    return pg_catalog.jsonb_build_object('error','signature_required');
  end if;
  -- Link público: limita tamanho e formato (assinatura em imagem, respostas em objeto).
  if p_signature_data_url not like 'data:image/%'
     or pg_catalog.length(p_signature_data_url) > 1000000
     or pg_catalog.length(coalesce(p_signature_name, '')) > 160
     or (p_answers is not null and (pg_catalog.jsonb_typeof(p_answers) <> 'object'
         or pg_catalog.pg_column_size(p_answers) > 200000)) then
    return pg_catalog.jsonb_build_object('error','invalid_payload');
  end if;

  update public.anamneses set
    answers            = coalesce(p_answers, '{}'::jsonb),
    signature_name     = p_signature_name,
    signature_data_url = p_signature_data_url,
    consent_accepted   = true,
    signer_user_agent  = pg_catalog.left(p_user_agent, 500),
    status             = 'signed',
    signed_at          = pg_catalog.now(),
    updated_at         = pg_catalog.now()
  where id = v.id;

  return pg_catalog.jsonb_build_object('ok', true, 'signed_at', pg_catalog.now());
end; $function$;

CREATE OR REPLACE FUNCTION public.confirm_payment_request(p_org_id uuid, p_request_id uuid, p_method text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := (select auth.uid());
  r public.payment_requests;
  v_result jsonb;
begin
  if v_uid is null then raise exception 'Sessão expirada' using errcode = '42501'; end if;
  if not public.has_org_role(p_org_id, array['owner', 'admin', 'manager', 'receptionist', 'finance']) then
    raise exception 'Sem permissão para confirmar pagamento' using errcode = '42501';
  end if;
  if p_method not in ('TRANSFER', 'BIZUM') then
    raise exception 'Forma de recebimento inválida' using errcode = '22023';
  end if;

  select * into r from public.payment_requests where id = p_request_id and org_id = p_org_id for update;
  if not found then raise exception 'Pedido não encontrado' using errcode = 'P0002'; end if;
  if r.status = 'confirmed' then
    return coalesce(r.result, '{}'::jsonb) || jsonb_build_object('duplicate', true);
  end if;
  -- Pedido vencido ainda pode ser confirmado: o dinheiro pode ter chegado depois do prazo.
  if r.status not in ('pending', 'proof_sent') then
    raise exception 'Pedido recusado ou cancelado não pode ser confirmado' using errcode = 'P0001';
  end if;
  -- Crédito mexe no saldo da cliente: mesma regra de adjust_client_balance_atomic.
  if r.purpose = 'credit' and not public.has_org_role(p_org_id, array['owner', 'admin', 'manager']) then
    raise exception 'Crédito da cliente só é confirmado pela gestão' using errcode = '42501';
  end if;

  -- O id do pedido é a chave de idempotência do lançamento.
  if r.purpose = 'deposit' then
    v_result := public.register_appointment_deposit_atomic(p_org_id, r.appointment_id, r.amount, p_method, r.id);
  else
    v_result := public.adjust_client_balance_atomic(p_org_id, r.client_id, 'credit', r.amount,
                  'Pagamento por transferência ' || r.reference, r.id);
    -- O ajuste de saldo grava o caixa como dinheiro; corrige para a forma real.
    update public.transactions t set method = p_method
    where t.org_id = p_org_id
      and t.id = (select e.transaction_id from public.client_balance_entries e
                  where e.org_id = p_org_id and e.id = (v_result ->> 'entryId')::uuid);
  end if;

  update public.payment_requests set
    status = 'confirmed', confirmed_method = p_method, confirmed_by = v_uid, confirmed_at = now(),
    result = v_result, updated_at = now()
  where id = r.id;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (p_org_id, v_uid, 'payment_requests', 'PAYMENT_REQUEST_CONFIRMED', r.id,
          jsonb_build_object('status', r.status),
          jsonb_build_object('status', 'confirmed', 'method', p_method, 'amount', r.amount, 'result', v_result));

  return v_result || jsonb_build_object('duplicate', false);
end;
$function$;

CREATE OR REPLACE FUNCTION public.prevent_used_catalog_item_delete()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if tg_table_name = 'services' and (
    exists (
      select 1 from public.appointment_items
      where org_id = old.org_id and type = 'service' and ref_id = old.id
    )
    or exists (
      select 1 from public.sale_items
      where org_id = old.org_id and upper(item_type) = 'SERVICE' and item_id = old.id
    )
    or exists (
      select 1 from public.package_services
      where org_id = old.org_id and service_id = old.id
    )
  ) then
    raise exception 'service has operational references; archive it instead'
      using errcode = '23503';
  end if;

  if tg_table_name = 'products' and (
    exists (
      select 1 from public.sale_items
      where org_id = old.org_id and upper(item_type) = 'PRODUCT' and item_id = old.id
    )
    or exists (
      select 1 from public.stock_entries
      where org_id = old.org_id and product_id = old.id
    )
  ) then
    raise exception 'product has operational references; archive it instead'
      using errcode = '23503';
  end if;

  if tg_table_name = 'service_packages' and (
    exists (
      select 1 from public.sale_items
      where org_id = old.org_id and upper(item_type) = 'PACKAGE' and item_id = old.id
    )
    or exists (
      select 1 from public.client_entitlements
      where org_id = old.org_id and package_id = old.id
    )
  ) then
    raise exception 'package has operational references; archive it instead'
      using errcode = '23503';
  end if;

  return old;
end;
$function$;

drop policy if exists audit_insert_member on public.audit_logs;
create policy audit_insert_member on public.audit_logs for insert to authenticated
  with check (
    org_id in (select public.auth_org_ids())
    and user_id = (select auth.uid())
    and public.has_org_role(org_id, array['owner', 'admin', 'manager', 'receptionist', 'professional', 'finance'])
  );
