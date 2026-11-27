-- Permissões pendentes (estado.md), parte 5: ajustes da revisão do PR #37.
-- Encoding: UTF-8
set client_encoding = 'UTF8';
--
-- (1) Devolver sessão do pacote passa a SECURITY DEFINER: login, estúdio (has_permission só vale em vínculo ativo) e
--     comanda.operate conferidos dentro; com isso a tabela client_entitlement_entries não aceita gravação direta de
--     ninguém da API (parte 4; também sem REFERENCES/TRIGGER). Regras do corpo que continuam (14/11, migration
--     20261114080000): pacote cancelado ou vencido recusa; pacote com validade passada (expires_at < agora) recusa
--     devolver sessão; sem sessão usada recusa; descrição até 200 caracteres.
-- (3) Vendas (sales: cliente, valores) e seus itens e pagamentos (sale_items, sale_payments): ler pela API exige
--     comanda.operate ou financeiro.view (antes: qualquer papel, inclusive profissional). As funções que já conferem isso (checkout, Financeiro) continuam lendo a tabela; as de
--     outras telas leem por internal_read.sales (Agenda: detalhe, estornar e cancelar, cancelar com sinal; perfil da
--     cliente; uso do modelo de ficha; histórico de vendas ao excluir item do catálogo). Atenção: o detalhe do
--     agendamento e o histórico de compras do perfil continuam mostrando valores e formas de pagamento da cliente a quem
--     vê a agenda (agenda_appointment_detail) ou a cliente (client_sales_history, clientes.view), como antes. O histórico de compras do perfil (antes uma consulta direta) passa a ser a
--     função client_sales_history (clientes.view), mesma ida ao banco.
-- (5) Preferências de marketing: a política de gravação (ALL, que também vale na leitura) conferia o papel linha a
--     linha; agora uma vez por consulta (auth_orgs_with_roles), mesmos papéis.

-- ─── (1) Devolver sessão do pacote ───────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.restore_entitlement_session_atomic(p_org_id uuid, p_entitlement_id uuid, p_description text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := (select auth.uid());
  v_client uuid;
  v_used integer;
  v_status text;
  v_expires timestamptz;
  v_description text := nullif(pg_catalog.btrim(coalesce(p_description, '')), '');
begin
  if v_uid is null then
    raise exception 'Autenticação obrigatória' using errcode = '42501';
  end if;
  if not public.has_permission(p_org_id, 'comanda.operate') then
    raise exception 'Sem permissão para restaurar sessão' using errcode = '42501';
  end if;
  if pg_catalog.char_length(v_description) > 200 then
    raise exception 'A descrição deve ter no máximo 200 caracteres' using errcode = '22023';
  end if;

  select e.client_id, e.used_sessions, e.status, e.expires_at into v_client, v_used, v_status, v_expires
  from public.client_entitlements e
  where e.id = p_entitlement_id and e.org_id = p_org_id
  for update;
  if not found then
    raise exception 'Pacote não encontrado' using errcode = 'P0002';
  end if;
  if v_status in ('cancelled', 'expired') then
    raise exception 'Pacote cancelado ou vencido: não dá para restaurar sessão' using errcode = 'P0001';
  end if;
  if v_expires is not null and v_expires < pg_catalog.now() then
    raise exception 'Pacote vencido: não dá para restaurar sessão' using errcode = 'P0001';
  end if;
  if v_used <= 0 then
    raise exception 'Nenhuma sessão para restaurar' using errcode = 'P0001';
  end if;

  update public.client_entitlements
  set used_sessions = v_used - 1, status = 'active'
  where id = p_entitlement_id and org_id = p_org_id;

  insert into public.client_entitlement_entries (
    org_id, entitlement_id, client_id, action, sessions_delta, sessions_before, sessions_after, description, created_by
  ) values (
    p_org_id, p_entitlement_id, v_client, 'restore', 1, v_used, v_used - 1, v_description, v_uid
  );

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (
    p_org_id, v_uid, 'client_entitlements', 'ENTITLEMENT_SESSION_RESTORED', p_entitlement_id,
    pg_catalog.jsonb_build_object('used_sessions', v_used, 'status', v_status),
    pg_catalog.jsonb_build_object('used_sessions', v_used - 1, 'status', 'active', 'description', v_description)
  );

  return pg_catalog.jsonb_build_object('used_sessions', v_used - 1);
end;
$function$
;

revoke references, trigger on public.client_entitlement_entries from anon, authenticated;

revoke all on function public.restore_entitlement_session_atomic(uuid, uuid, text) from public, anon;
grant execute on function public.restore_entitlement_session_atomic(uuid, uuid, text) to authenticated, service_role;

-- ─── (3) Vendas ─────────────────────────────────────────────────────────────────────────────────
drop policy if exists sales_select on public.sales;
create policy sales_select on public.sales for select to authenticated
  using (org_id in (select public.auth_orgs_with_permission('comanda.operate'))
         or org_id in (select public.auth_orgs_with_permission('financeiro.view')));

drop policy if exists sale_items_select on public.sale_items;
create policy sale_items_select on public.sale_items for select to authenticated
  using (org_id in (select public.auth_orgs_with_permission('comanda.operate'))
         or org_id in (select public.auth_orgs_with_permission('financeiro.view')));

drop policy if exists sale_payments_select on public.sale_payments;
create policy sale_payments_select on public.sale_payments for select to authenticated
  using (org_id in (select public.auth_orgs_with_permission('comanda.operate'))
         or org_id in (select public.auth_orgs_with_permission('financeiro.view')));

-- Histórico de compras do perfil da cliente (aba Financeiro do perfil): quem vê clientes.
create or replace function public.client_sales_history(p_org_id uuid, p_client_id uuid)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'clientes.view') then
    raise exception 'Sem permissão para ver clientes' using errcode = '42501';
  end if;
  return coalesce((
    select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'id', s.id, 'number', s.number, 'status', s.status, 'subtotal', s.subtotal, 'discount', s.discount,
      'total', s.total, 'created_at', s.created_at, 'appointment_id', s.appointment_id,
      'sale_items', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('name', i.name, 'quantity', i.quantity, 'total_price', i.total_price)
          order by i.created_at, i.id)
        from internal_read.sale_items i where i.sale_id = s.id and i.org_id = s.org_id), '[]'::jsonb),
      'sale_payments', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('method', p.method) order by p.created_at, p.id)
        from internal_read.sale_payments p where p.sale_id = s.id and p.org_id = s.org_id), '[]'::jsonb))
      order by s.created_at desc, s.id)
    from (select x.* from internal_read.sales x
          where x.org_id = p_org_id and x.client_id = p_client_id
          order by x.created_at desc, x.id limit 50) s), '[]'::jsonb);
end;
$$;
revoke all on function public.client_sales_history(uuid, uuid) from public, anon;
grant execute on function public.client_sales_history(uuid, uuid) to authenticated, service_role;

-- ─── agenda_refund_and_cancel (leitura de vendas por internal_read) ───
CREATE OR REPLACE FUNCTION public.agenda_refund_and_cancel(p_org_id uuid, p_appointment_id uuid, p_reason text, p_destination text, p_restock_products boolean, p_idempotency_key uuid, p_series boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_sale uuid;
  v_result jsonb;
  v_current record;
  v_next uuid;
  v_series_failed boolean := false;
begin
  if not public.has_permission(p_org_id, 'agenda.manage') then
    raise exception 'Seu perfil não cancela agendamentos.' using errcode = '42501';
  end if;
  -- Repetição com a mesma chave (duplo clique, rede): devolve o estorno já feito, sem estornar de novo.
  select pg_catalog.jsonb_build_object('amount', r.amount, 'destination', r.destination, 'duplicate', true, 'series_failed', false)
  into v_result
  from public.sale_refunds r join internal_read.sales s on s.id = r.sale_id and s.org_id = r.org_id
  where r.org_id = p_org_id and r.idempotency_key = p_idempotency_key and s.appointment_id = p_appointment_id
  limit 1;
  if v_result is not null then
    return v_result;
  end if;

  select s.id into v_sale from internal_read.sales s
  where s.org_id = p_org_id and s.appointment_id = p_appointment_id and s.status <> 'cancelled'
  order by s.created_at desc
  limit 1;
  if v_sale is null then
    raise exception 'Não achei o checkout deste agendamento. Atualize a tela e tente de novo.' using errcode = 'P0002';
  end if;

  v_result := public.refund_sale_atomic(p_org_id, v_sale, p_reason, p_destination, p_restock_products, p_idempotency_key, true);

  if p_series then
    begin
      select a.recurrence_id, a.start_at into v_current
      from public.appointments a where a.org_id = p_org_id and a.id = p_appointment_id;
      if v_current.recurrence_id is not null then
        select a.id into v_next from public.appointments a
        where a.org_id = p_org_id and a.recurrence_id = v_current.recurrence_id
          and a.status in ('Reservado', 'Agendado', 'Confirmado') and a.start_at > v_current.start_at
        order by a.start_at
        limit 1;
        if v_next is not null then
          perform public.cancel_appointment_settle_deposit_atomic(p_org_id, v_next, 'Série cancelada',
            case when p_destination = 'credito' then 'credit' else 'refund' end, true);
        end if;
      end if;
    exception when others then
      v_series_failed := true;
    end;
  end if;

  return coalesce(v_result, '{}'::jsonb) || pg_catalog.jsonb_build_object('series_failed', v_series_failed);
end;
$function$
;

-- ─── cancel_appointment_settle_deposit_atomic (leitura de vendas por internal_read) ───
CREATE OR REPLACE FUNCTION public.cancel_appointment_settle_deposit_atomic(p_org_id uuid, p_appointment_id uuid, p_reason text DEFAULT NULL::text, p_deposit_mode text DEFAULT 'fee'::text, p_series boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_reason text := nullif(pg_catalog.btrim(coalesce(p_reason, '')), '');
  v_appt public.appointments;
  v_ids uuid[] := array[]::uuid[];
  v_more uuid[];
  v_cancelled uuid[] := array[]::uuid[];
  v_already boolean := false;
  v_id uuid;
  v_client_id uuid;
  v_total numeric(12,2);
  v_credited numeric(12,2) := 0;
  v_kept numeric(12,2) := 0;
  v_voided integer := 0;
  v_deposit_id uuid;
begin
  if not public.has_permission(p_org_id, 'agenda.manage') then
    raise exception 'Sem permissao para cancelar agendamentos' using errcode = '42501';
  end if;
  if p_deposit_mode is null or p_deposit_mode not in ('credit', 'refund', 'fee') then
    raise exception 'Destino do sinal invalido' using errcode = '22023';
  end if;
  if v_reason is not null and char_length(v_reason) > 120 then
    raise exception 'Motivo longo demais' using errcode = '22023';
  end if;

  -- Trava o agendamento: duplo clique ou duas abas esperam a primeira chamada terminar.
  select * into v_appt
  from public.appointments a
  where a.id = p_appointment_id and a.org_id = p_org_id
  for update;
  if not found then
    raise exception 'Agendamento nao encontrado' using errcode = 'P0002';
  end if;

  if v_appt.status = 'Cancelado' then
    -- Nova tentativa de acertar o sinal: nada a cancelar de novo.
    v_already := true;
    v_ids := array[v_appt.id];
  else
    -- Concluído sem comanda ativa (nunca cobrada, ou comanda estornada) também pode ser cancelado.
    if not (
      public.agenda_status_transition_allowed(v_appt.status, 'Cancelado')
      or (v_appt.status = 'Concluído' and not exists (
        select 1 from internal_read.sales s
        where s.org_id = p_org_id and s.appointment_id = v_appt.id and s.status <> 'cancelled'))
    ) then
      raise exception 'Agendamento neste estado nao pode ser cancelado' using errcode = '22023';
    end if;
    v_ids := array[v_appt.id];
    if p_series and v_appt.recurrence_id is not null then
      select pg_catalog.array_agg(locked.id order by locked.start_at) into v_more
      from (
        select a.id, a.start_at
        from public.appointments a
        where a.org_id = p_org_id
          and a.recurrence_id = v_appt.recurrence_id
          and a.id <> v_appt.id
          and a.status in ('Reservado', 'Agendado', 'Confirmado')
          and a.start_at > v_appt.start_at
          and a.start_at >= pg_catalog.now()
        for update
      ) locked;
      v_ids := v_ids || coalesce(v_more, array[]::uuid[]);
    end if;

    update public.appointments
    set status = 'Cancelado', cancel_reason = v_reason
    where org_id = p_org_id and id = any(v_ids);
    v_cancelled := v_ids;

    insert into public.appointment_status_history (org_id, appointment_id, status, changed_by, notes)
    select p_org_id, c.appointment_id, 'Cancelado', auth.uid(),
           case when c.appointment_id = v_appt.id then v_reason else 'recurrence_cancelled' end
    from pg_catalog.unnest(v_ids) as c(appointment_id);

    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
    values (
      p_org_id, auth.uid(), 'appointments', 'STATUS_CHANGE', v_appt.id,
      pg_catalog.jsonb_build_object('status', v_appt.status),
      pg_catalog.jsonb_build_object(
        'status', 'Cancelado', 'cancel_reason', v_reason,
        'deposit_mode', p_deposit_mode, 'series', coalesce(p_series, false),
        'appointment_ids', pg_catalog.to_jsonb(v_ids)
      )
    );
  end if;

  -- Sinal de cada agendamento cancelado: só o que ainda está "confirmado" (não aplicado a venda).
  foreach v_id in array v_ids loop
    select coalesce(sum(d.amount), 0) into v_total
    from public.appointment_deposits d
    where d.org_id = p_org_id and d.appointment_id = v_id and d.status = 'confirmed';
    if v_total <= 0 then
      continue;
    end if;

    if p_deposit_mode = 'fee' then
      v_kept := v_kept + v_total;
      continue;
    end if;

    if not public.has_permission(p_org_id, 'comanda.operate') then
      raise exception 'Sem permissao para mexer no sinal' using errcode = '42501';
    end if;

    if p_deposit_mode = 'credit' then
      select a.client_id into v_client_id
      from public.appointments a where a.id = v_id and a.org_id = p_org_id;
      -- A chave (o id do agendamento) torna a repetição inofensiva; a função confere financeiro.manage.
      perform public.adjust_client_balance_atomic(
        p_org_id, v_client_id, 'credit', v_total, 'Sinal de agendamento cancelado', v_id
      );
      v_credited := v_credited + v_total;
    end if;

    for v_deposit_id in
      select d.id from public.appointment_deposits d
      where d.org_id = p_org_id and d.appointment_id = v_id and d.status = 'confirmed'
      order by d.created_at, d.id
    loop
      perform public.void_appointment_deposit_atomic(p_org_id, v_deposit_id);
      v_voided := v_voided + 1;
    end loop;
  end loop;

  return pg_catalog.jsonb_build_object(
    'appointment_id', v_appt.id,
    'already_cancelled', v_already,
    'cancelled_ids', pg_catalog.to_jsonb(v_cancelled),
    'cancelled_count', coalesce(pg_catalog.array_length(v_cancelled, 1), 0),
    'credited', v_credited,
    'voided', v_voided,
    'fee_kept', v_kept
  );
end;
$function$
;

-- ─── anamnese_template_usage (leitura de vendas por internal_read) ───
CREATE OR REPLACE FUNCTION public.anamnese_template_usage(p_org_id uuid, p_template_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'anamnese.manage_templates') then
    raise exception 'Sem permissão para editar modelos de ficha' using errcode = '42501';
  end if;
  return coalesce((
    select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'appointment_id', s.appointment_id,
        'paid', s.appointment_id is not null and exists (
          select 1 from internal_read.sales sa
          where sa.org_id = p_org_id and sa.appointment_id = s.appointment_id and sa.status = 'paid')))
    from public.list_anamnese_status(p_org_id, p_template_id => p_template_id) s), '[]'::jsonb);
end;
$function$
;

-- ─── catalog_delete_item (histórico de vendas por internal_read: quem gere o catálogo sem ver vendas ainda só arquiva) ───
CREATE OR REPLACE FUNCTION public.catalog_delete_item(p_org_id uuid, p_kind text, p_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_name text;
  v_where text;
  v_refs boolean;
begin
  if not public.has_permission(p_org_id, 'catalogo.manage') then
    raise exception 'Sem permissão para gerenciar o catálogo.' using errcode = '42501';
  end if;
  if p_kind not in ('service', 'product') then
    raise exception 'Tipo de item inválido.' using errcode = '22023';
  end if;

  if p_kind = 'service' then
    select s.name into v_name from public.services s
    where s.id = p_id and s.org_id = p_org_id for update;
    if not found then raise exception 'Serviço não encontrado.' using errcode = 'P0002'; end if;

    select b.name into v_where
    from public.service_bundle_items i
    join public.service_bundles b on b.id = i.bundle_id and b.org_id = i.org_id
    where i.org_id = p_org_id and i.service_id = p_id and b.active and b.archived_at is null
    order by b.name limit 1;
    if found then
      raise exception 'Está no combo "%": tire de lá antes.', v_where using errcode = '22023';
    end if;
    select k.name into v_where
    from public.package_services i
    join public.service_packages k on k.id = i.package_id and k.org_id = i.org_id
    where i.org_id = p_org_id and i.service_id = p_id and k.active
    order by k.name limit 1;
    if found then
      raise exception 'Está no pacote "%": tire de lá antes.', v_where using errcode = '22023';
    end if;
    -- Plano de assinatura: os serviços incluídos ficam num jsonb (sem chave estrangeira), então a conferência é pelo conteúdo.
    select pl.name into v_where
    from public.subscription_plans pl
    where pl.org_id = p_org_id and pl.active
      and pl.eligible_services @> pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('service_id', p_id::text))
    order by pl.name limit 1;
    if found then
      raise exception 'Está no plano "%": tire de lá antes.', v_where using errcode = '22023';
    end if;

    v_refs := exists (select 1 from public.appointment_items i where i.org_id = p_org_id and i.type = 'service' and i.ref_id = p_id)
      or exists (select 1 from internal_read.sale_items i where i.org_id = p_org_id and pg_catalog.lower(i.item_type) = 'service' and i.item_id = p_id)
      or exists (select 1 from public.package_services i where i.org_id = p_org_id and i.service_id = p_id)
      or exists (select 1 from public.service_bundle_items i where i.org_id = p_org_id and i.service_id = p_id)
      or exists (select 1 from public.agenda_waitlist i where i.org_id = p_org_id and i.service_id = p_id)
      or public.anamnese_exists_for(p_org_id, null, p_id)
      or exists (select 1 from public.subscription_plans pl where pl.org_id = p_org_id
                 and pl.eligible_services @> pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('service_id', p_id::text)));
    if v_refs then
      update public.services set active = false where id = p_id and org_id = p_org_id;
      return 'archived';
    end if;
    delete from public.services where id = p_id and org_id = p_org_id;
    return 'deleted';
  end if;

  perform 1 from public.products s where s.id = p_id and s.org_id = p_org_id for update;
  if not found then raise exception 'Produto não encontrado.' using errcode = 'P0002'; end if;
  v_refs := exists (select 1 from internal_read.sale_items i where i.org_id = p_org_id and pg_catalog.lower(i.item_type) = 'product' and i.item_id = p_id)
    or exists (select 1 from public.stock_entries i where i.org_id = p_org_id and i.product_id = p_id);
  if v_refs then
    update public.products set active = false where id = p_id and org_id = p_org_id;
    return 'archived';
  end if;
  delete from public.products where id = p_id and org_id = p_org_id;
  return 'deleted';
end;
$function$
;


-- ─── (5) Preferências de marketing ─────────────────────────────────────────────────────────────
drop policy if exists client_marketing_preferences_manage on public.client_marketing_preferences;
create policy client_marketing_preferences_manage on public.client_marketing_preferences for all to authenticated
  using (org_id in (select public.auth_orgs_with_roles(array['owner', 'admin', 'manager', 'receptionist'])))
  with check (org_id in (select public.auth_orgs_with_roles(array['owner', 'admin', 'manager', 'receptionist'])));
