-- Clientes: cidade e estado, consentimento de uso de imagem, mesclagem atômica e auditoria da exportação.
-- Encoding: UTF-8
--
-- Pendências do redesenho V25 (quadros PClientesEditor, PPerfil e PClientesDuplicados):
--   1. Cidade e "estado ou província" no cadastro.
--   2. Consentimento de uso de imagem (fotos de antes e depois para divulgação), com quem/quando
--      e registro no histórico de auditoria.
--   3. Mesclar cadastros duplicados numa transação só (merge_clients_atomic).
--   4. Exportar clientes deixa rastro (log_clients_export).
--
-- Compatibilidade com o app anterior: colunas novas com padrão/nulo; funções novas; a única função
-- existente alterada (protect_signed_anamnese_evidence) mantém a assinatura e o comportamento para
-- qualquer chamada que não seja a mesclagem.

-- ─── 1. Colunas ──────────────────────────────────────────────────────────────

alter table public.clients
  add column if not exists city text,
  add column if not exists state_region text,
  add column if not exists image_use_consent boolean not null default false,
  add column if not exists image_use_consent_at timestamptz,
  add column if not exists image_use_consent_by uuid references auth.users(id) on delete set null,
  add column if not exists merged_into uuid,
  add column if not exists merged_at timestamptz,
  add column if not exists merged_by uuid references auth.users(id) on delete set null;

alter table public.clients drop constraint if exists clients_location_text_check;
alter table public.clients add constraint clients_location_text_check check (
  (city is null or pg_catalog.char_length(pg_catalog.btrim(city)) between 1 and 120)
  and (state_region is null or pg_catalog.char_length(pg_catalog.btrim(state_region)) between 1 and 120)
);

-- Cadastro mesclado aponta para o que ficou (mesma organização). Referência própria: não conta
-- para o teste "uma ligação por par de tabelas" (126), que ignora tabela ligada a si mesma.
alter table public.clients drop constraint if exists clients_merged_into_fkey;
alter table public.clients add constraint clients_merged_into_fkey
  foreign key (org_id, merged_into) references public.clients (org_id, id);
alter table public.clients drop constraint if exists clients_merged_into_not_self;
alter table public.clients add constraint clients_merged_into_not_self check (merged_into is null or merged_into <> id);

create index if not exists idx_clients_merged_into on public.clients (org_id, merged_into) where merged_into is not null;

-- A nota ligada a um atendimento acompanha o atendimento quando a cliente do atendimento muda
-- (mesclagem). Sem ON UPDATE CASCADE a troca de cliente do atendimento falharia.
alter table public.client_notes drop constraint if exists client_notes_org_client_appointment_fk;
alter table public.client_notes add constraint client_notes_org_client_appointment_fk
  foreign key (org_id, client_id, appointment_id) references public.appointments (org_id, client_id, id)
  on update cascade on delete restrict;

-- ─── 2. Consentimento de imagem: quem e quando saem do banco, não do formulário ────────────────

create or replace function public.stamp_client_image_consent()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
begin
  if tg_op = 'INSERT' then
    if new.image_use_consent then
      new.image_use_consent_at := pg_catalog.now();
      new.image_use_consent_by := v_user;
      insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
      values (new.org_id, v_user, 'clients', 'IMAGE_CONSENT_GRANTED', new.id,
              pg_catalog.jsonb_build_object('image_use_consent', false),
              pg_catalog.jsonb_build_object('image_use_consent', true));
    else
      new.image_use_consent_at := null;
      new.image_use_consent_by := null;
    end if;
    return new;
  end if;

  if new.image_use_consent is distinct from old.image_use_consent then
    new.image_use_consent_at := pg_catalog.now();
    new.image_use_consent_by := v_user;
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
    values (new.org_id, v_user, 'clients',
            case when new.image_use_consent then 'IMAGE_CONSENT_GRANTED' else 'IMAGE_CONSENT_REVOKED' end,
            new.id,
            pg_catalog.jsonb_build_object('image_use_consent', old.image_use_consent, 'at', old.image_use_consent_at),
            pg_catalog.jsonb_build_object('image_use_consent', new.image_use_consent));
  else
    -- Sem mudança do consentimento, "quando" e "quem" não se editam pela API.
    new.image_use_consent_at := old.image_use_consent_at;
    new.image_use_consent_by := old.image_use_consent_by;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_clients_image_consent on public.clients;
create trigger trg_clients_image_consent
before insert or update on public.clients
for each row execute function public.stamp_client_image_consent();

-- Mesclagem e cadastro só mudam "mesclada em" pela função de mesclagem.
create or replace function public.guard_client_merge_columns()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('authenticated', 'anon') and (
       (tg_op = 'INSERT' and (new.merged_into is not null or new.merged_at is not null or new.merged_by is not null))
    or (tg_op = 'UPDATE' and (new.merged_into is distinct from old.merged_into
                              or new.merged_at is distinct from old.merged_at
                              or new.merged_by is distinct from old.merged_by))
  ) then
    raise exception 'Cadastros só são mesclados pela função de mesclagem'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_clients_guard_merge_columns on public.clients;
create trigger trg_clients_guard_merge_columns
before insert or update on public.clients
for each row execute function public.guard_client_merge_columns();

-- ─── 3. Ficha assinada: a mesclagem pode trocar a cliente, nada mais ──────────────────────────
-- Mesma função de 20260614172305. Acréscimo: quando quem executa é a função de mesclagem
-- (dona do banco, nunca a API) e ela sinalizou a operação, client_id pode mudar. As evidências
-- (respostas, assinatura, textos, data) continuam imutáveis.

create or replace function public.protect_signed_anamnese_evidence()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_ignored text[] := array['professional_notes', 'professional_data', 'professional_completed_at', 'updated_at'];
begin
  if old.status = 'signed' then
    if tg_op = 'DELETE' then
      raise exception 'Fichas assinadas nao podem ser excluidas'
        using errcode = '23514';
    end if;

    if current_user not in ('authenticated', 'anon')
       and coalesce(pg_catalog.current_setting('app.client_merge', true), '') = 'on' then
      v_ignored := v_ignored || array['client_id'];
    end if;

    if (
      pg_catalog.to_jsonb(new) - v_ignored
    ) is distinct from (
      pg_catalog.to_jsonb(old) - v_ignored
    ) then
      raise exception 'Evidencias de uma ficha assinada sao imutaveis'
        using errcode = '23514';
    end if;
  end if;

  if tg_op = 'DELETE' then
    insert into public.audit_logs (
      org_id, user_id, table_name, operation, record_id, old_data
    )
    values (
      old.org_id,
      auth.uid(),
      'anamneses',
      'ANAMNESE_PENDING_DELETED',
      old.id,
      pg_catalog.jsonb_build_object(
        'status', old.status,
        'client_id', old.client_id,
        'appointment_id', old.appointment_id,
        'template_title', old.template_title
      )
    );
    return old;
  end if;

  return new;
end;
$$;

-- ─── 4. Mesclagem atômica ────────────────────────────────────────────────────────────────────

create or replace function public.merge_clients_atomic(
  p_org_id uuid,
  p_keep_id uuid,
  p_merge_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_id uuid;
  v_keep public.clients;
  v_merge public.clients;
  v_n_appointments integer;
  v_n_sales integer;
  v_n_transactions integer;
  v_n_balance integer;
  v_n_points integer;
  v_n_entitlements integer;
  v_n_entitlement_entries integer;
  v_n_anamneses integer;
  v_n_notes integer;
  v_n_deposits integer;
  v_n_payment_requests integer;
  v_n_messages integer;
  v_n_gift_cards integer;
  v_n_preferences integer;
  v_balance numeric(12,2);
  v_points integer;
  v_total numeric;
  v_alert_rank_keep integer;
  v_alert_rank_merge integer;
begin
  if v_user is null then
    raise exception 'Sessão expirada' using errcode = '42501';
  end if;
  if not public.has_permission(p_org_id, 'clientes.manage') then
    raise exception 'Sem permissão para mesclar clientes' using errcode = '42501';
  end if;
  if p_keep_id is null or p_merge_id is null or p_keep_id = p_merge_id then
    raise exception 'Escolha dois cadastros diferentes' using errcode = '22023';
  end if;

  -- Trava os dois cadastros sempre na mesma ordem: duas mesclagens ao mesmo tempo não se cruzam.
  for v_id in select x from pg_catalog.unnest(array[p_keep_id, p_merge_id]) as t(x) order by x loop
    perform 1 from public.clients c where c.id = v_id and c.org_id = p_org_id for update;
  end loop;

  select * into v_keep from public.clients c where c.id = p_keep_id and c.org_id = p_org_id;
  if not found then
    raise exception 'Cliente não encontrada nesta organização' using errcode = 'P0002';
  end if;
  select * into v_merge from public.clients c where c.id = p_merge_id and c.org_id = p_org_id;
  if not found then
    raise exception 'Cliente não encontrada nesta organização' using errcode = 'P0002';
  end if;

  -- Repetir a mesma mesclagem (duplo clique, segunda aba) não faz nada e não é erro.
  if v_merge.merged_into = p_keep_id then
    return pg_catalog.jsonb_build_object(
      'keep_id', p_keep_id, 'merged_id', p_merge_id, 'already_merged', true,
      'balance', v_keep.balance, 'loyalty_points', v_keep.loyalty_points);
  end if;
  if v_merge.merged_into is not null then
    raise exception 'Este cadastro já foi mesclado em outro' using errcode = 'P0001';
  end if;
  if v_keep.merged_into is not null then
    raise exception 'O cadastro que fica já foi mesclado em outro' using errcode = 'P0001';
  end if;

  -- Fichas assinadas só trocam de cliente dentro desta operação (ver protect_signed_anamnese_evidence).
  perform pg_catalog.set_config('app.client_merge', 'on', true);

  select pg_catalog.count(*) into v_n_notes
    from public.client_notes n where n.org_id = p_org_id and n.client_id = p_merge_id;

  -- Atendimentos primeiro: as notas ligadas a eles seguem junto (ON UPDATE CASCADE) e as fichas
  -- precisam achar a cliente nova.
  update public.appointments set client_id = p_keep_id, client_name = v_keep.full_name
   where org_id = p_org_id and client_id = p_merge_id;
  get diagnostics v_n_appointments = row_count;

  update public.client_notes set client_id = p_keep_id
   where org_id = p_org_id and client_id = p_merge_id;

  update public.anamneses set client_id = p_keep_id
   where org_id = p_org_id and client_id = p_merge_id;
  get diagnostics v_n_anamneses = row_count;

  update public.sales set client_id = p_keep_id, client_name = v_keep.full_name
   where org_id = p_org_id and client_id = p_merge_id;
  get diagnostics v_n_sales = row_count;

  update public.transactions set client_id = p_keep_id, client_name = v_keep.full_name
   where org_id = p_org_id and client_id = p_merge_id;
  get diagnostics v_n_transactions = row_count;

  update public.appointment_deposits set client_id = p_keep_id
   where org_id = p_org_id and client_id = p_merge_id;
  get diagnostics v_n_deposits = row_count;

  update public.payment_requests set client_id = p_keep_id
   where org_id = p_org_id and client_id = p_merge_id;
  get diagnostics v_n_payment_requests = row_count;

  update public.gift_card_redemptions set client_id = p_keep_id
   where org_id = p_org_id and client_id = p_merge_id;
  get diagnostics v_n_gift_cards = row_count;

  -- Pacotes e créditos da cliente.
  update public.client_entitlements set client_id = p_keep_id
   where org_id = p_org_id and client_id = p_merge_id;
  get diagnostics v_n_entitlements = row_count;

  update public.client_entitlement_entries set client_id = p_keep_id
   where client_id = p_merge_id
     and entitlement_id in (select e.id from public.client_entitlements e where e.org_id = p_org_id);
  get diagnostics v_n_entitlement_entries = row_count;

  -- Mensagens (fila e eventos).
  update public.marketing_message_queue set client_id = p_keep_id
   where org_id = p_org_id and client_id = p_merge_id;
  get diagnostics v_n_messages = row_count;
  update public.marketing_message_events set client_id = p_keep_id
   where org_id = p_org_id and client_id = p_merge_id;

  -- Preferências de contato: o canal que já existe nos dois fica com a regra mais restritiva
  -- (quem recusou marketing continua recusado); o que só existe na duplicada é movido.
  update public.client_marketing_preferences k
     set marketing_allowed = k.marketing_allowed and m.marketing_allowed,
         operational_allowed = k.operational_allowed and m.operational_allowed,
         opted_out_at = coalesce(k.opted_out_at, m.opted_out_at),
         opt_out_reason = coalesce(k.opt_out_reason, m.opt_out_reason)
    from public.client_marketing_preferences m
   where k.org_id = p_org_id and k.client_id = p_keep_id
     and m.org_id = p_org_id and m.client_id = p_merge_id
     and m.channel = k.channel;
  delete from public.client_marketing_preferences m
   where m.org_id = p_org_id and m.client_id = p_merge_id
     and exists (select 1 from public.client_marketing_preferences k
                  where k.org_id = p_org_id and k.client_id = p_keep_id and k.channel = m.channel);
  update public.client_marketing_preferences set client_id = p_keep_id
   where org_id = p_org_id and client_id = p_merge_id;
  get diagnostics v_n_preferences = row_count;

  -- Extratos de saldo e de pontos vão para a cliente que fica; o saldo é a soma dos dois e a
  -- sequência "antes → depois" é refeita em ordem de data para o extrato continuar fechando.
  update public.client_balance_entries set client_id = p_keep_id
   where org_id = p_org_id and client_id = p_merge_id;
  get diagnostics v_n_balance = row_count;

  update public.loyalty_point_entries set client_id = p_keep_id
   where org_id = p_org_id and client_id = p_merge_id;
  get diagnostics v_n_points = row_count;

  v_balance := pg_catalog.round(coalesce(v_keep.balance, 0) + coalesce(v_merge.balance, 0), 2);
  v_points := coalesce(v_keep.loyalty_points, 0) + coalesce(v_merge.loyalty_points, 0);

  if v_n_balance > 0 then
    select coalesce(pg_catalog.sum(e.amount), 0) into v_total
      from public.client_balance_entries e where e.org_id = p_org_id and e.client_id = p_keep_id;
    with ordered as (
      select e.id, pg_catalog.sum(e.amount) over (order by e.created_at, e.id) as running
        from public.client_balance_entries e
       where e.org_id = p_org_id and e.client_id = p_keep_id
    )
    update public.client_balance_entries e
       set balance_after = pg_catalog.round(v_balance - v_total + o.running, 2),
           balance_before = pg_catalog.round(v_balance - v_total + o.running - e.amount, 2)
      from ordered o
     where e.id = o.id;
  end if;

  if v_n_points > 0 then
    select coalesce(pg_catalog.sum(e.points), 0) into v_total
      from public.loyalty_point_entries e where e.org_id = p_org_id and e.client_id = p_keep_id;
    with ordered as (
      select e.id, pg_catalog.sum(e.points) over (order by e.created_at, e.id) as running
        from public.loyalty_point_entries e
       where e.org_id = p_org_id and e.client_id = p_keep_id
    )
    update public.loyalty_point_entries e
       set balance_after = (v_points - v_total + o.running)::integer,
           balance_before = (v_points - v_total + o.running - e.points)::integer
      from ordered o
     where e.id = o.id;
  end if;

  v_alert_rank_keep := case v_keep.alert_type when 'allergy' then 4 when 'condition' then 3 when 'vip' then 2 when 'note' then 1 else 0 end;
  v_alert_rank_merge := case v_merge.alert_type when 'allergy' then 4 when 'condition' then 3 when 'vip' then 2 when 'note' then 1 else 0 end;

  -- Cadastro que fica: preenche o que estava vazio, une etiquetas e alertas, soma os valores.
  update public.clients k set
    phone = coalesce(k.phone, v_merge.phone),
    phone_country_code = case when k.phone is null then v_merge.phone_country_code else k.phone_country_code end,
    email = coalesce(k.email, v_merge.email),
    birth_date = coalesce(k.birth_date, v_merge.birth_date),
    gender = coalesce(k.gender, v_merge.gender),
    cpf = coalesce(k.cpf, v_merge.cpf),
    document_type = case when k.document_number is null then v_merge.document_type else k.document_type end,
    document_number = coalesce(k.document_number, v_merge.document_number),
    source = coalesce(k.source, v_merge.source),
    location_id = coalesce(k.location_id, v_merge.location_id),
    city = coalesce(k.city, v_merge.city),
    state_region = coalesce(k.state_region, v_merge.state_region),
    notes = case
      when k.notes is null or pg_catalog.btrim(k.notes) = '' then v_merge.notes
      when v_merge.notes is null or pg_catalog.btrim(v_merge.notes) = '' or v_merge.notes = k.notes then k.notes
      else k.notes || E'\n' || v_merge.notes end,
    fixed_notes = case
      when k.fixed_notes is null or pg_catalog.btrim(k.fixed_notes) = '' then v_merge.fixed_notes
      when v_merge.fixed_notes is null or pg_catalog.btrim(v_merge.fixed_notes) = '' or v_merge.fixed_notes = k.fixed_notes then k.fixed_notes
      else k.fixed_notes || E'\n' || v_merge.fixed_notes end,
    tags = coalesce((select pg_catalog.array_agg(distinct t order by t)
                       from pg_catalog.unnest(coalesce(k.tags, '{}'::text[]) || coalesce(v_merge.tags, '{}'::text[])) as u(t)), '{}'::text[]),
    alert_type = case when v_alert_rank_merge > v_alert_rank_keep then v_merge.alert_type else k.alert_type end,
    alert_text = case
      when k.alert_text is null or pg_catalog.btrim(k.alert_text) = '' then v_merge.alert_text
      when v_merge.alert_text is null or pg_catalog.btrim(v_merge.alert_text) = '' or v_merge.alert_text = k.alert_text then k.alert_text
      else pg_catalog.left(k.alert_text || ' · ' || v_merge.alert_text, 200) end,
    balance = v_balance,
    total_spent = pg_catalog.round(coalesce(k.total_spent, 0) + coalesce(v_merge.total_spent, 0), 2),
    loyalty_points = v_points,
    loyalty_tier = case when v_merge.loyalty_points is not null and v_merge.loyalty_points <> 0 then public.loyalty_tier_for(v_points) else k.loyalty_tier end,
    last_visit = case
      when k.last_visit is null then v_merge.last_visit
      when v_merge.last_visit is null then k.last_visit
      else greatest(k.last_visit, v_merge.last_visit) end,
    -- Consentimento de imagem só vale se as duas cadastradas concordaram.
    image_use_consent = k.image_use_consent and v_merge.image_use_consent,
    blocked_at = case when k.blocked_at is null then v_merge.blocked_at else k.blocked_at end,
    blocked_reason = case when k.blocked_at is null then v_merge.blocked_reason else k.blocked_reason end,
    blocked_by = case when k.blocked_at is null then v_merge.blocked_by else k.blocked_by end
  where k.id = p_keep_id and k.org_id = p_org_id;

  -- Duplicada: arquivada, zerada (o histórico foi para a que ficou) e com a referência.
  update public.clients set
    status = 'Inativo',
    merged_into = p_keep_id,
    merged_at = pg_catalog.now(),
    merged_by = v_user,
    balance = 0,
    total_spent = 0,
    loyalty_points = 0,
    loyalty_tier = public.loyalty_tier_for(0)
  where id = p_merge_id and org_id = p_org_id;

  perform pg_catalog.set_config('app.client_merge', '', true);

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (p_org_id, v_user, 'clients', 'CLIENT_MERGED', p_keep_id,
    pg_catalog.jsonb_build_object(
      'merged_id', p_merge_id,
      'merged_name', v_merge.full_name,
      'merged_phone', v_merge.phone,
      'merged_email', v_merge.email,
      'merged_balance', v_merge.balance,
      'merged_loyalty_points', v_merge.loyalty_points,
      'kept_balance', v_keep.balance,
      'kept_loyalty_points', v_keep.loyalty_points),
    pg_catalog.jsonb_build_object(
      'balance', v_balance,
      'loyalty_points', v_points,
      'moved', pg_catalog.jsonb_build_object(
        'appointments', v_n_appointments, 'sales', v_n_sales, 'transactions', v_n_transactions,
        'balance_entries', v_n_balance, 'loyalty_entries', v_n_points,
        'entitlements', v_n_entitlements, 'entitlement_entries', v_n_entitlement_entries,
        'anamneses', v_n_anamneses, 'notes', v_n_notes, 'deposits', v_n_deposits,
        'payment_requests', v_n_payment_requests, 'messages', v_n_messages,
        'gift_card_redemptions', v_n_gift_cards, 'preferences', v_n_preferences)));

  return pg_catalog.jsonb_build_object(
    'keep_id', p_keep_id,
    'merged_id', p_merge_id,
    'already_merged', false,
    'balance', v_balance,
    'loyalty_points', v_points,
    'moved', pg_catalog.jsonb_build_object(
      'appointments', v_n_appointments, 'sales', v_n_sales, 'notes', v_n_notes,
      'anamneses', v_n_anamneses, 'entitlements', v_n_entitlements));
end;
$$;

revoke all on function public.merge_clients_atomic(uuid, uuid, uuid) from public, anon;
grant execute on function public.merge_clients_atomic(uuid, uuid, uuid) to authenticated;

-- ─── 5. Exportação de clientes deixa rastro ──────────────────────────────────────────────────

create or replace function public.log_clients_export(
  p_org_id uuid,
  p_count integer,
  p_filters jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_id uuid;
begin
  if v_user is null then
    raise exception 'Sessão expirada' using errcode = '42501';
  end if;
  if not public.has_permission(p_org_id, 'clientes.view') then
    raise exception 'Sem permissão para exportar clientes' using errcode = '42501';
  end if;
  if p_count is null or p_count < 0 or p_count > 1000000 then
    raise exception 'Quantidade inválida' using errcode = '22023';
  end if;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
  values (p_org_id, v_user, 'clients', 'CLIENTS_EXPORTED', null,
          pg_catalog.jsonb_build_object('count', p_count, 'filters', coalesce(p_filters, '{}'::jsonb)))
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.log_clients_export(uuid, integer, jsonb) from public, anon;
grant execute on function public.log_clients_export(uuid, integer, jsonb) to authenticated;
