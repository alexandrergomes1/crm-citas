-- Permissões pendentes (estado.md), parte 2: Comanda, Financeiro, Fidelidade, Mensagens, Marketing, Ajustes, perfil
-- da cliente e modelos de ficha leem clientes e serviços por internal_read (parte 1, 20261114130000).
-- Encoding: UTF-8
set client_encoding = 'UTF8';
--
-- Mesmas funções de antes; só a leitura de public.clients / public.services / public.products /
-- public.service_categories / public.service_packages passou a internal_read. Cada uma mantém a própria conferência
-- (comanda.operate, financeiro, mensagens.*, ajustes.manage, clientes.view, anamnese.view_status). A exceção é
-- checkout_catalog, que não conferia nada (a RLS fazia o papel) e ganhou a conferência marcada no corpo.

-- ─── checkout_screen ───
CREATE OR REPLACE FUNCTION public.checkout_screen(p_org_id uuid, p_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  v_tz text;
  v_today date;
  v_sale public.sales;
  v_appt public.appointments;
  v_appt_id uuid;
  v_client_id uuid;
  v_redirect uuid;
  v_open boolean;
  v_gate jsonb := '[]'::jsonb;
  v_fichas jsonb := '[]'::jsonb;
begin
  perform public.finance_org_timezone(p_org_id);
  if not (public.has_permission(p_org_id, 'comanda.operate') or public.has_permission(p_org_id, 'financeiro.view')) then
    raise exception 'Sem permissão para ver o checkout' using errcode = '42501';
  end if;
  if p_id is null then
    return pg_catalog.jsonb_build_object('not_found', true);
  end if;
  v_tz := public.finance_org_timezone(p_org_id);
  v_today := (pg_catalog.now() at time zone v_tz)::date;

  select * into v_sale from public.sales s where s.id = p_id and s.org_id = p_org_id;
  if v_sale.id is null then
    -- Depois de um estorno o atendimento pode ganhar uma comanda nova: a cancelada fica só no histórico.
    select s.id into v_redirect from public.sales s
    where s.org_id = p_org_id and s.appointment_id = p_id and s.status <> 'cancelled'
    order by s.created_at desc, s.id limit 1;
    if v_redirect is not null then
      return pg_catalog.jsonb_build_object('redirect', v_redirect);
    end if;
    v_appt_id := p_id;
  else
    v_appt_id := v_sale.appointment_id;
  end if;

  if v_appt_id is not null then
    select * into v_appt from public.appointments a where a.id = v_appt_id and a.org_id = p_org_id;
  end if;
  if v_sale.id is null and v_appt.id is null then
    return pg_catalog.jsonb_build_object('not_found', true);
  end if;

  v_client_id := coalesce(v_appt.client_id, v_sale.client_id);
  v_open := v_sale.id is null or v_sale.status in ('draft', 'partial');

  if v_appt.id is not null and public.has_permission(p_org_id, 'anamnese.view_status') then
    select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
             'id', f.id, 'template_title', f.template_title, 'status', f.status, 'signed_at', f.signed_at,
             'requires_professional', f.requires_professional, 'professional_completed_at', f.professional_completed_at,
             'superseded_by', f.superseded_by)
             order by f.created_at desc, f.id), '[]'::jsonb)
    into v_fichas
    from public.list_anamnese_status(p_org_id, array[v_appt.id]) f;
  end if;

  -- Trava da Ficha só para quem cobra (o gate exige comanda.operate ou anamnese.view_status); quem só vê o
  -- financeiro abre a comanda em leitura sem a trava.
  if v_open and v_appt.id is not null
     and (public.has_permission(p_org_id, 'comanda.operate') or public.has_permission(p_org_id, 'anamnese.view_status')) then
    select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(g)), '[]'::jsonb) into v_gate
    from public.get_appointment_anamnese_gate(p_org_id, v_appt.id, 'checkout') g;
  end if;

  return pg_catalog.jsonb_build_object(
    'today', v_today,
    'timezone', v_tz,
    'sale', case when v_sale.id is null then null else pg_catalog.jsonb_build_object(
      'id', v_sale.id, 'number', v_sale.number, 'appointment_id', v_sale.appointment_id, 'client_id', v_sale.client_id,
      'client_name', v_sale.client_name, 'staff_id', v_sale.staff_id, 'status', v_sale.status,
      'subtotal', v_sale.subtotal, 'discount', v_sale.discount, 'tip', v_sale.tip, 'total', v_sale.total,
      'paid_amount', v_sale.paid_amount, 'balance', v_sale.balance, 'notes', v_sale.notes,
      'created_at', v_sale.created_at, 'updated_at', v_sale.updated_at, 'refunded_at', v_sale.refunded_at,
      'refund_reason', v_sale.refund_reason,
      'items', coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
                  'id', i.id, 'item_type', i.item_type, 'item_id', i.item_id, 'name', i.name, 'category', i.category,
                  'unit_price', i.unit_price, 'quantity', i.quantity, 'total_price', i.total_price,
                  'entitlement_id', i.entitlement_id, 'covered_by_entitlement', i.covered_by_entitlement)
                  order by i.created_at, i.id)
                from public.sale_items i where i.sale_id = v_sale.id and i.org_id = p_org_id), '[]'::jsonb),
      'payments', coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
                  'method', pay.method, 'amount', pay.amount, 'gift_card_code', pay.gift_card_code,
                  'reference', pay.reference, 'created_at', pay.created_at) order by pay.created_at, pay.id)
                from public.sale_payments pay where pay.sale_id = v_sale.id and pay.org_id = p_org_id), '[]'::jsonb)
    ) end,
    'appointment', case when v_appt.id is null then null else pg_catalog.jsonb_build_object(
      'id', v_appt.id, 'number', v_appt.number, 'client_id', v_appt.client_id, 'client_name', v_appt.client_name,
      'staff_id', v_appt.staff_id, 'start_at', v_appt.start_at, 'internal_notes', v_appt.internal_notes,
      'items', coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
                  'id', i.id, 'type', i.type, 'ref_id', i.ref_id, 'name', i.name, 'price', i.price, 'qty', i.qty,
                  'duration_minutes', i.duration_minutes, 'professional_id', i.professional_id,
                  'requires_anamnese', i.requires_anamnese) order by i.created_at, i.id)
                from public.appointment_items i where i.appointment_id = v_appt.id and i.org_id = p_org_id), '[]'::jsonb),
      'fichas', v_fichas
    ) end,
    'catalog', public.checkout_catalog(p_org_id),
    'staff', coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
               'id', m.id, 'name', m.name, 'display_name', m.display_name, 'commission_pct', m.commission_pct)
               order by m.position, m.name, m.id)
             from (select x.* from public.staff_members x where x.org_id = p_org_id order by x.position, x.name, x.id limit 500) m), '[]'::jsonb),
    'deposits', case when v_appt.id is null then '[]'::jsonb else coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', d.id, 'amount', d.amount, 'method', d.method, 'created_at', d.created_at)
               order by d.created_at, d.id)
      from public.appointment_deposits d
      where d.org_id = p_org_id and d.appointment_id = v_appt.id and d.status = 'confirmed'), '[]'::jsonb) end,
    'entitlements', case when v_client_id is null then '[]'::jsonb else coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
               'id', e.id, 'package_name', e.package_name, 'total_sessions', e.total_sessions,
               'used_sessions', e.used_sessions, 'covered_services', e.covered_services, 'expires_at', e.expires_at)
               order by e.purchased_at desc, e.id)
      from (select x.* from public.client_entitlements x
            where x.org_id = p_org_id and x.client_id = v_client_id and x.status = 'active'
            order by x.purchased_at desc, x.id limit 200) e), '[]'::jsonb) end,
    'client', case when v_client_id is null then null else (
      select pg_catalog.jsonb_build_object(
               'full_name', c.full_name, 'phone', c.phone, 'email', c.email, 'tags', c.tags, 'balance', c.balance,
               'fixed_notes', c.fixed_notes, 'alert_text', c.alert_text)
      from internal_read.clients c where c.id = v_client_id and c.org_id = p_org_id) end,
    'visits', case when v_client_id is null then 0 else (
      select pg_catalog.count(*) from public.sales s where s.org_id = p_org_id and s.client_id = v_client_id and s.status = 'paid') end,
    'gate', v_gate,
    'refund', case when v_sale.status = 'cancelled' then (
      select pg_catalog.jsonb_build_object('amount', r.amount, 'destination', r.destination, 'details', r.details)
      from public.sale_refunds r where r.org_id = p_org_id and r.sale_id = v_sale.id
      order by r.created_at desc, r.id limit 1) end,
    'partial_refunded', case when v_sale.status in ('paid', 'partial') then (
      select coalesce(pg_catalog.round(sum(r.amount), 2), 0) from public.sale_partial_refunds r
      where r.org_id = p_org_id and r.sale_id = v_sale.id) else 0 end,
    -- Retoques incluídos: regras do catálogo e os 200 atendimentos concluídos mais recentes da cliente
    -- (a conta da janela é feita em src/domain/service-rules.ts, no fuso do estúdio).
    'retouch_rules', case when v_open and v_client_id is not null then coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('service_id', s.id, 'name', s.name, 'days', s.retouch_included_days)
               order by s.name, s.id)
      from internal_read.services s where s.org_id = p_org_id and s.retouch_included_days is not null), '[]'::jsonb)
      else '[]'::jsonb end,
    'retouch_history', case when v_open and v_client_id is not null then coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
               'status', a.status, 'start_at', a.start_at,
               'service_ids', coalesce((select pg_catalog.jsonb_agg(i.ref_id order by i.created_at, i.id)
                                        from public.appointment_items i
                                        where i.appointment_id = a.id and i.org_id = a.org_id and i.ref_id is not null), '[]'::jsonb))
               order by a.start_at desc)
      from (select x.* from public.appointments x
            where x.org_id = p_org_id and x.client_id = v_client_id
              and x.status in ('Concluído', 'Concluido', 'Pago Parcial', 'Pago')
              and x.id is distinct from v_appt.id
            order by x.start_at desc limit 200) a), '[]'::jsonb)
      else '[]'::jsonb end
  );
end;
$function$
;

-- ─── checkout_walkin_screen ───
CREATE OR REPLACE FUNCTION public.checkout_walkin_screen(p_org_id uuid, p_client_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  v_tz text;
  v_clients jsonb;
begin
  v_tz := public.finance_org_timezone(p_org_id);
  if not public.has_permission(p_org_id, 'comanda.operate') then
    raise exception 'Sem permissão para registrar vendas' using errcode = '42501';
  end if;
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', c.id, 'name', c.full_name, 'phone', c.phone)
           order by c.full_name, c.id), '[]'::jsonb)
  into v_clients
  from (select x.id, x.full_name, x.phone from internal_read.clients x
        where x.org_id = p_org_id and x.status <> 'archived'
        order by x.full_name, x.id limit 501) c;

  return pg_catalog.jsonb_build_object(
    'today', (pg_catalog.now() at time zone v_tz)::date,
    'timezone', v_tz,
    'catalog', public.checkout_catalog(p_org_id),
    'client', case when p_client_id is null then null else (
      select pg_catalog.jsonb_build_object(
               'id', c.id, 'full_name', c.full_name, 'phone', c.phone, 'email', c.email, 'tags', c.tags,
               'balance', c.balance, 'fixed_notes', c.fixed_notes, 'alert_text', c.alert_text)
      from internal_read.clients c where c.id = p_client_id and c.org_id = p_org_id) end,
    'clients', (select coalesce(pg_catalog.jsonb_agg(c) filter (where n <= 500), '[]'::jsonb)
                from (select c, pg_catalog.row_number() over () as n from pg_catalog.jsonb_array_elements(v_clients) c) z),
    'clients_truncated', pg_catalog.jsonb_array_length(v_clients) > 500,
    'me', (select pg_catalog.jsonb_build_object('id', m.id, 'name', m.name, 'display_name', m.display_name, 'commission_pct', m.commission_pct)
           from public.staff_members m
           where m.org_id = p_org_id and m.user_id = (select auth.uid()) and m.active
           order by m.position, m.id limit 1),
    'entitlements', case when p_client_id is null then '[]'::jsonb else coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
               'id', e.id, 'package_name', e.package_name, 'total_sessions', e.total_sessions,
               'used_sessions', e.used_sessions, 'covered_services', e.covered_services, 'expires_at', e.expires_at)
               order by e.purchased_at desc, e.id)
      from (select x.* from public.client_entitlements x
            where x.org_id = p_org_id and x.client_id = p_client_id and x.status = 'active'
            order by x.purchased_at desc, x.id limit 200) e), '[]'::jsonb) end
  );
end;
$function$
;

-- ─── checkout_catalog ───
CREATE OR REPLACE FUNCTION public.checkout_catalog(p_org_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  -- Só quem opera a comanda, vê o financeiro ou vê o catálogo (lê as tabelas por internal_read).
  select case when public.has_permission(p_org_id, 'comanda.operate') or public.has_permission(p_org_id, 'financeiro.view')
    or public.has_permission(p_org_id, 'catalogo.view') then pg_catalog.jsonb_build_object(
    'services', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
               'id', s.id, 'name', s.name, 'price', s.price, 'duration_minutes', s.duration_minutes,
               'requires_anamnese', s.requires_anamnese, 'category', c.name) order by s.position, s.name, s.id)
      from (select x.* from internal_read.services x where x.org_id = p_org_id and x.active
            order by x.position, x.name, x.id limit 1000) s
      left join internal_read.service_categories c on c.id = s.category_id and c.org_id = s.org_id), '[]'::jsonb),
    'products', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
               'id', p.id, 'name', p.name, 'price', p.price, 'category', c.name) order by p.position, p.name, p.id)
      from (select x.* from internal_read.products x where x.org_id = p_org_id and x.active
            order by x.position, x.name, x.id limit 1000) p
      left join internal_read.service_categories c on c.id = p.category_id and c.org_id = p.org_id), '[]'::jsonb),
    'packages', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', k.id, 'name', k.name, 'price', k.price)
               order by k.position, k.name, k.id)
      from (select x.* from internal_read.service_packages x where x.org_id = p_org_id and x.active
            order by x.position, x.name, x.id limit 500) k), '[]'::jsonb)
  ) else pg_catalog.jsonb_build_object('services', '[]'::jsonb, 'products', '[]'::jsonb, 'packages', '[]'::jsonb) end;
$function$
;

-- ─── payment_request_context ───
CREATE OR REPLACE FUNCTION public.payment_request_context(p_org_id uuid, p_client_id uuid, p_appointment_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  v_client_id uuid := p_client_id;
  v_appt public.appointments;
  v_total numeric;
  v_paid numeric;
  v_suggested numeric;
  v_client jsonb;
begin
  perform public.finance_org_timezone(p_org_id);
  if not public.has_permission(p_org_id, 'comanda.operate') then
    raise exception 'Sem permissão para cobrar por link.' using errcode = '42501';
  end if;
  if p_appointment_id is not null then
    select * into v_appt from public.appointments a where a.id = p_appointment_id and a.org_id = p_org_id;
    if v_appt.client_id is null then
      return pg_catalog.jsonb_build_object('error', 'no_appointment_client');
    end if;
    v_client_id := v_appt.client_id;
    select coalesce(sum(i.price * i.qty), 0) into v_total
    from public.appointment_items i where i.appointment_id = v_appt.id and i.org_id = p_org_id;
    if v_total = 0 then
      v_total := coalesce(v_appt.total, 0);
    end if;
    select coalesce(sum(d.amount), 0) into v_paid
    from public.appointment_deposits d
    where d.appointment_id = v_appt.id and d.org_id = p_org_id and d.status in ('confirmed', 'applied');
    v_suggested := case when v_total > v_paid then pg_catalog.round(v_total - v_paid, 2) end;
  end if;
  if v_client_id is null then
    return pg_catalog.jsonb_build_object('error', 'no_client');
  end if;
  select pg_catalog.jsonb_build_object('id', c.id, 'full_name', c.full_name, 'phone', c.phone) into v_client
  from internal_read.clients c where c.id = v_client_id and c.org_id = p_org_id;
  if v_client is null then
    return pg_catalog.jsonb_build_object('error', 'client_not_found');
  end if;
  return pg_catalog.jsonb_build_object(
    'client', v_client,
    'suggested', v_suggested,
    'accounts', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
               'id', a.id, 'kind', a.kind, 'holder_name', a.holder_name, 'identifier', a.identifier, 'bic', a.bic,
               'bank_name', a.bank_name, 'active', a.active, 'position', a.position) order by a.position, a.created_at, a.id)
      from public.payment_accounts a where a.org_id = p_org_id and a.active), '[]'::jsonb)
  );
end;
$function$
;

-- ─── finance_balances_screen ───
CREATE OR REPLACE FUNCTION public.finance_balances_screen(p_org_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  v_rows jsonb;
begin
  perform public.finance_require(p_org_id, true);
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
           'id', c.id, 'full_name', c.full_name, 'phone', c.phone, 'balance', c.balance) order by c.balance, c.id), '[]'::jsonb)
  into v_rows
  from (select x.id, x.full_name, x.phone, x.balance from internal_read.clients x
        where x.org_id = p_org_id and x.balance <> 0 order by x.balance, x.id limit 5001) c;
  return pg_catalog.jsonb_build_object(
    'rows', (select coalesce(pg_catalog.jsonb_agg(r) filter (where n <= 5000), '[]'::jsonb)
             from (select r, pg_catalog.row_number() over () as n from pg_catalog.jsonb_array_elements(v_rows) r) z),
    'truncated', pg_catalog.jsonb_array_length(v_rows) > 5000,
    'counts', public.finance_shell_counts(p_org_id)
  );
end;
$function$
;

-- ─── finance_comandas_screen ───
CREATE OR REPLACE FUNCTION public.finance_comandas_screen(p_org_id uuid, p_month text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  v_tz text;
  v_from timestamptz;
  v_to timestamptz;
  v_rows jsonb;
  v_pending jsonb := '{}'::jsonb;
  v_open_appts uuid[];
begin
  perform public.finance_require(p_org_id, false);
  if p_month is null or p_month !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then
    raise exception 'Período inválido' using errcode = '22023';
  end if;
  v_tz := public.finance_org_timezone(p_org_id);
  v_from := ((p_month || '-01')::date)::timestamp at time zone v_tz;
  v_to := (((p_month || '-01')::date + interval '1 month')::date)::timestamp at time zone v_tz;

  -- Ficha Profissional pendente nas comandas abertas do mês (só para quem vê o status das fichas, como antes).
  select coalesce(pg_catalog.array_agg(distinct s.appointment_id), '{}') into v_open_appts
  from public.sales s
  where s.org_id = p_org_id and s.created_at >= v_from and s.created_at < v_to
    and s.status in ('draft', 'partial') and s.appointment_id is not null;
  if pg_catalog.cardinality(v_open_appts) > 0 and public.has_permission(p_org_id, 'anamnese.view_status') then
    select coalesce(pg_catalog.jsonb_object_agg(x.appointment_id, x.id), '{}'::jsonb) into v_pending
    from (
      select distinct on (f.appointment_id) f.appointment_id, f.id
      from public.list_anamnese_status(p_org_id, v_open_appts) f
      where f.requires_professional and f.professional_completed_at is null
      order by f.appointment_id, f.created_at, f.id desc
    ) x;
  end if;

  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
           'id', s.id, 'number', s.number, 'appointment_id', s.appointment_id, 'client_id', s.client_id,
           'client_name', s.client_name, 'status', s.status, 'total', s.total, 'paid_amount', s.paid_amount,
           'balance', s.balance, 'created_at', s.created_at,
           'appointment_start', (select a.start_at from public.appointments a where a.id = s.appointment_id and a.org_id = s.org_id),
           'client_phone', (select c.phone from internal_read.clients c where c.id = s.client_id and c.org_id = s.org_id),
           'services', coalesce((select pg_catalog.jsonb_agg(i.name order by i.created_at, i.id)
                                 from public.sale_items i where i.sale_id = s.id and i.org_id = s.org_id), '[]'::jsonb),
           'payments', coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
                                   'method', pay.method, 'deposit', coalesce(pay.reference like 'DEPOSIT:%', false))
                                   order by pay.created_at, pay.id)
                                 from public.sale_payments pay where pay.sale_id = s.id and pay.org_id = s.org_id), '[]'::jsonb),
           'ficha_id', case when s.status in ('draft', 'partial') and s.appointment_id is not null
                            then v_pending ->> s.appointment_id::text end)
           order by s.created_at desc, s.id), '[]'::jsonb)
  into v_rows
  from (select x.* from public.sales x
        where x.org_id = p_org_id and x.created_at >= v_from and x.created_at < v_to
        order by x.created_at desc, x.id limit 5001) s;

  return pg_catalog.jsonb_build_object(
    'rows', (select coalesce(pg_catalog.jsonb_agg(r) filter (where n <= 5000), '[]'::jsonb)
             from (select r, pg_catalog.row_number() over () as n from pg_catalog.jsonb_array_elements(v_rows) r) z),
    'truncated', pg_catalog.jsonb_array_length(v_rows) > 5000,
    'counts', public.finance_shell_counts(p_org_id)
  );
end;
$function$
;

-- ─── finance_overview_screen ───
CREATE OR REPLACE FUNCTION public.finance_overview_screen(p_org_id uuid, p_start date, p_end date, p_cmp_start date, p_cmp_end date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  v_open_appts uuid[];
  v_blocked integer := 0;
  v_entries jsonb;
  v_clients jsonb;
begin
  perform public.finance_require(p_org_id, true);
  if p_start is null or p_end is null or p_cmp_start is null or p_cmp_end is null
     or p_end < p_start or p_cmp_end < p_cmp_start or p_cmp_start > p_start or p_end - p_cmp_start > 800 then
    raise exception 'Período inválido' using errcode = '22023';
  end if;

  select coalesce(pg_catalog.array_agg(distinct s.appointment_id), '{}') into v_open_appts
  from public.sales s
  where s.org_id = p_org_id and s.status in ('draft', 'partial') and s.appointment_id is not null;

  -- Comandas travadas pela Ficha Profissional: só para quem pode ver o status das fichas (como antes).
  if pg_catalog.cardinality(v_open_appts) > 0 and public.has_permission(p_org_id, 'anamnese.view_status') then
    select pg_catalog.count(distinct f.appointment_id) into v_blocked
    from public.list_anamnese_status(p_org_id, v_open_appts) f
    where f.requires_professional and f.professional_completed_at is null;
  end if;

  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
           'id', t.id, 'created_at', t.created_at, 'date', t.date, 'description', t.description,
           'client_name', t.client_name, 'type', t.type, 'value', t.value, 'method', t.method)
           order by t.created_at desc, t.id), '[]'::jsonb)
  into v_entries
  from (select x.* from public.transactions x
        where x.org_id = p_org_id and x.status = 'completed' and x.date between p_start and p_end
        order by x.created_at desc, x.id limit 201) t;

  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', c.id, 'name', c.full_name)
           order by c.full_name, c.id), '[]'::jsonb)
  into v_clients
  from (select x.id, x.full_name from internal_read.clients x where x.org_id = p_org_id
        order by x.full_name, x.id limit 301) c;

  return pg_catalog.jsonb_build_object(
    'days', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('date', d.date, 'revenue', d.revenue, 'expense', d.expense) order by d.date)
      from (
        select t.date,
               pg_catalog.round(coalesce(sum(t.value) filter (where t.type = 'income'
                 and pg_catalog.lower(pg_catalog.btrim(coalesce(t.category, ''))) <> 'ajuste_saldo'
                 and pg_catalog.lower(pg_catalog.btrim(coalesce(t.method, ''))) not in ('client_credit', 'gift_card')), 0), 2) as revenue,
               pg_catalog.round(coalesce(sum(t.value) filter (where t.type = 'expense'
                 and pg_catalog.lower(pg_catalog.btrim(coalesce(t.category, ''))) <> 'ajuste_saldo'), 0), 2) as expense
        from public.transactions t
        where t.org_id = p_org_id and t.status = 'completed' and t.date between p_cmp_start and p_end
        group by t.date
      ) d), '[]'::jsonb),
    'receivable', (
      select pg_catalog.jsonb_build_object('count', pg_catalog.count(*), 'amount', coalesce(pg_catalog.round(sum(s.balance), 2), 0))
      from public.sales s
      where s.org_id = p_org_id and s.status in ('draft', 'partial') and s.balance > 0.009),
    'blocked', v_blocked,
    'next_payable', (
      select pg_catalog.jsonb_build_object('description', p.description, 'value', p.value, 'due_date', p.due_date, 'status', p.status)
      from public.payables p where p.org_id = p_org_id and p.status <> 'paid'
      order by p.due_date, p.id limit 1),
    'entries', (select coalesce(pg_catalog.jsonb_agg(e) filter (where n <= 200), '[]'::jsonb)
                from (select e, pg_catalog.row_number() over () as n from pg_catalog.jsonb_array_elements(v_entries) e) z),
    'entries_truncated', pg_catalog.jsonb_array_length(v_entries) > 200,
    'clients', (select coalesce(pg_catalog.jsonb_agg(c) filter (where n <= 300), '[]'::jsonb)
                from (select c, pg_catalog.row_number() over () as n from pg_catalog.jsonb_array_elements(v_clients) c) z),
    'clients_truncated', pg_catalog.jsonb_array_length(v_clients) > 300,
    'user_name', (select pr.full_name from public.profiles pr
                  where pr.org_id = p_org_id and pr.user_id = (select auth.uid()) limit 1),
    'counts', public.finance_shell_counts(p_org_id)
  );
end;
$function$
;

-- ─── loyalty_screen ───
CREATE OR REPLACE FUNCTION public.loyalty_screen(p_org_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
begin
  perform public.finance_org_timezone(p_org_id);
  -- Nomes e pontos das clientes: quem vê clientes ou o financeiro.
  if not (public.has_permission(p_org_id, 'clientes.view') or public.has_permission(p_org_id, 'financeiro.view')) then
    raise exception 'Sem permissão para ver a fidelidade' using errcode = '42501';
  end if;
  return pg_catalog.jsonb_build_object(
    'top', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
               'id', c.id, 'full_name', c.full_name, 'loyalty_points', c.loyalty_points, 'loyalty_tier', c.loyalty_tier)
               order by c.loyalty_points desc, c.id)
      from (select x.id, x.full_name, x.loyalty_points, x.loyalty_tier from internal_read.clients x
            where x.org_id = p_org_id and x.loyalty_points > 0 order by x.loyalty_points desc, x.id limit 20) c), '[]'::jsonb),
    'summary', (select pg_catalog.jsonb_build_object('total_points', coalesce(sum(c.loyalty_points), 0), 'clients_with_points', pg_catalog.count(*))
                from internal_read.clients c where c.org_id = p_org_id and c.loyalty_points > 0)
  );
end;
$function$
;

-- ─── marketing_audience ───
CREATE OR REPLACE FUNCTION public.marketing_audience(p_org_id uuid, p_filter jsonb, p_enforce_consent boolean DEFAULT true)
 RETURNS TABLE(client_id uuid, full_name text, phone text, email text, phone_country_code text)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
 SET plan_cache_mode TO 'force_custom_plan'
AS $function$
#variable_conflict use_column
declare
  v_filter jsonb := coalesce(p_filter, '{}'::jsonb);
  v_today date;
  v_status text := v_filter ->> 'clientStatus';
  v_channel text := v_filter ->> 'channel';
  v_family text[];
  v_consent text := coalesce(v_filter ->> 'marketingConsent', 'missing_or_allowed');
  v_missing_ok boolean := public.marketing_missing_consent_counts_as_allowed();
  v_tags text[];
  v_services uuid[];
  v_svc_clients uuid[];
  v_inactive integer := (v_filter ->> 'inactiveDays')::integer;
  v_birthday integer := (v_filter ->> 'birthdayWindowDays')::integer;
  v_min numeric := (v_filter ->> 'totalSpentMin')::numeric;
  v_max numeric := (v_filter ->> 'totalSpentMax')::numeric;
begin
  if p_org_id is null or p_org_id not in (select public.auth_org_ids()) then
    raise exception 'Sem acesso a este estúdio.' using errcode = '42501';
  end if;
  if not public.has_permission(p_org_id, 'mensagens.configure') then
    raise exception 'Sem permissão para ver o público das campanhas.' using errcode = '42501';
  end if;
  if pg_catalog.jsonb_typeof(v_filter) <> 'object' then
    raise exception 'Filtro de público inválido.' using errcode = '22023';
  end if;
  if v_consent not in ('any', 'allowed', 'missing_or_allowed') then
    raise exception 'Filtro de consentimento inválido.' using errcode = '22023';
  end if;
  if v_channel is not null then
    v_family := public.marketing_channel_family(v_channel);
    if v_family is null then
      raise exception 'Canal do filtro inválido.' using errcode = '22023';
    end if;
  end if;
  -- O consentimento é por meio: sem canal não há como saber quem recusou (o sistema antigo tratava como "aceitou").
  if v_channel is null and (p_enforce_consent or v_consent <> 'any') then
    raise exception 'Escolha o canal do público.' using errcode = '22023';
  end if;

  select coalesce(pg_catalog.array_agg(t), '{}') into v_tags
  from pg_catalog.jsonb_array_elements_text(coalesce(v_filter -> 'tagsAny', '[]'::jsonb)) t;
  select coalesce(pg_catalog.array_agg(s::uuid), '{}') into v_services
  from pg_catalog.jsonb_array_elements_text(coalesce(v_filter -> 'serviceIdsAny', '[]'::jsonb)) s;

  -- Quem usou algum dos serviços: UM conjunto de clientes (não uma consulta por cliente).
  if pg_catalog.cardinality(v_services) > 0 then
    select coalesce(pg_catalog.array_agg(distinct a.client_id), '{}') into v_svc_clients
    from public.appointment_items i
    join public.appointments a on a.id = i.appointment_id and a.org_id = i.org_id
    where i.org_id = p_org_id and i.type = 'service' and i.ref_id = any (v_services) and a.client_id is not null;
  end if;

  -- Hoje no fuso do estúdio (o sistema antigo usava um fuso fixo).
  select (pg_catalog.now() at time zone coalesce(nullif(o.timezone, ''), 'Europe/Madrid'))::date into v_today
  from public.organizations o where o.id = p_org_id;

  return query
  select c.id, c.full_name, c.phone, c.email, c.phone_country_code
  from internal_read.clients c
  left join (
    select p.client_id, pg_catalog.bool_or(p.opted_out_at is not null or p.marketing_allowed = false) as refused
    from public.client_marketing_preferences p
    where p.org_id = p_org_id and p.channel = any (v_family)
    group by p.client_id
  ) pref on pref.client_id = c.id
  where c.org_id = p_org_id
    and c.merged_into is null
    and c.blocked_at is null
    and (v_status is null or v_status = 'any' or c.status = v_status)
    and (pg_catalog.cardinality(v_tags) = 0 or c.tags && v_tags)
    and (v_svc_clients is null or c.id = any (v_svc_clients))
    and (v_inactive is null or (c.last_visit is not null and (v_today - c.last_visit) >= v_inactive))
    and (v_birthday is null or (
      c.birth_date is not null
      and (
        -- dias até o próximo aniversário (29/02 em ano sem bissexto cai em 01/03, como no sistema antigo)
        case
          when ((pg_catalog.date_trunc('year', v_today::timestamp)
                 + ((pg_catalog.date_part('month', c.birth_date)::integer - 1) * interval '1 month')
                 + ((pg_catalog.date_part('day', c.birth_date)::integer - 1) * interval '1 day'))::date) >= v_today
            then ((pg_catalog.date_trunc('year', v_today::timestamp)
                 + ((pg_catalog.date_part('month', c.birth_date)::integer - 1) * interval '1 month')
                 + ((pg_catalog.date_part('day', c.birth_date)::integer - 1) * interval '1 day'))::date) - v_today
          else ((pg_catalog.date_trunc('year', v_today::timestamp) + interval '1 year'
                 + ((pg_catalog.date_part('month', c.birth_date)::integer - 1) * interval '1 month')
                 + ((pg_catalog.date_part('day', c.birth_date)::integer - 1) * interval '1 day'))::date) - v_today
        end) <= v_birthday))
    and (v_min is null or c.total_spent >= v_min)
    and (v_max is null or c.total_spent <= v_max)
    and (
      v_consent = 'any'
      or (case when v_consent = 'allowed' then coalesce(not pref.refused, false) else coalesce(not pref.refused, v_missing_ok) end)
    )
    and (not p_enforce_consent or coalesce(not pref.refused, v_missing_ok))
  order by c.full_name, c.id;
end;
$function$
;

-- ─── marketing_campaigns_screen ───
CREATE OR REPLACE FUNCTION public.marketing_campaigns_screen(p_org_id uuid, p_audiences jsonb DEFAULT '[]'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  v_audiences jsonb := '[]'::jsonb;
  v_item jsonb;
  v_campaigns integer;
  v_templates integer;
  v_queue integer;
  v_unauthorized integer;
  v_by_channel jsonb;
  v_missing boolean;
begin
  if p_org_id is null or p_org_id not in (select public.auth_org_ids()) then
    raise exception 'Sem acesso a este estúdio.' using errcode = '42501';
  end if;
  if not public.has_permission(p_org_id, 'mensagens.configure') then
    raise exception 'Sem permissão para ver as campanhas.' using errcode = '42501';
  end if;
  if pg_catalog.jsonb_typeof(coalesce(p_audiences, '[]'::jsonb)) <> 'array'
     or pg_catalog.jsonb_array_length(coalesce(p_audiences, '[]'::jsonb)) > 10 then
    raise exception 'Lista de públicos inválida.' using errcode = '22023';
  end if;

  for v_item in select * from pg_catalog.jsonb_array_elements(coalesce(p_audiences, '[]'::jsonb)) loop
    v_audiences := v_audiences || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'key', v_item ->> 'key',
      'count', (select pg_catalog.count(*) from public.marketing_audience(p_org_id, v_item -> 'filter', false))));
  end loop;

  select pg_catalog.count(*) into v_campaigns from public.marketing_campaigns x where x.org_id = p_org_id;
  select pg_catalog.count(*) into v_templates from public.marketing_message_templates x where x.org_id = p_org_id and x.archived_at is null;
  select pg_catalog.count(*) into v_queue from public.marketing_message_queue x where x.org_id = p_org_id;

  -- Clientes ativas (não mescladas nem bloqueadas) sem autorização de marketing: não entram nas campanhas; e, por meio
  -- (o do canal da campanha), as que o meio não deixa receber por falta de aceite ou por recusa. Mesma regra de
  -- marketing_channel_state (recusa na família do meio vence; registro sem recusa = autorizada; sem registro = nenhum),
  -- mas com as preferências resumidas UMA vez por cliente (group by) e juntadas, como em marketing_audience.
  -- Antes: 4 a 8 consultas por cliente (20 mil clientes: ~9 s).
  v_missing := public.marketing_missing_consent_counts_as_allowed();
  with pref as (
    select p.client_id,
      pg_catalog.bool_or(p.channel in ('whatsapp_manual', 'whatsapp_provider')) as wa_any,
      pg_catalog.bool_or(p.channel in ('whatsapp_manual', 'whatsapp_provider')
                         and (p.opted_out_at is not null or p.marketing_allowed = false)) as wa_refused,
      pg_catalog.bool_or(p.channel = 'email_provider') as em_any,
      pg_catalog.bool_or(p.channel = 'email_provider' and (p.opted_out_at is not null or p.marketing_allowed = false)) as em_refused,
      pg_catalog.bool_or(p.channel = 'sms_provider') as sms_any,
      pg_catalog.bool_or(p.channel = 'sms_provider' and (p.opted_out_at is not null or p.marketing_allowed = false)) as sms_refused
    from public.client_marketing_preferences p
    where p.org_id = p_org_id
    group by p.client_id
  ), st as (
    select
      case when coalesce(pr.wa_refused, false) then 'refused' when coalesce(pr.wa_any, false) then 'authorized' else 'none' end as wa,
      case when coalesce(pr.em_refused, false) then 'refused' when coalesce(pr.em_any, false) then 'authorized' else 'none' end as em,
      case when coalesce(pr.sms_refused, false) then 'refused' when coalesce(pr.sms_any, false) then 'authorized' else 'none' end as sms
    from internal_read.clients c
    left join pref pr on pr.client_id = c.id
    where c.org_id = p_org_id and c.status = 'Ativo' and c.merged_into is null and c.blocked_at is null
  )
  select
    pg_catalog.count(*) filter (where not (st.wa = 'authorized' or st.em = 'authorized' or st.sms = 'authorized')),
    pg_catalog.jsonb_build_object(
      'whatsapp_manual', pg_catalog.count(*) filter (where not (st.wa = 'authorized' or (st.wa = 'none' and v_missing))),
      'email_provider', pg_catalog.count(*) filter (where not (st.em = 'authorized' or (st.em = 'none' and v_missing))),
      'sms_provider', pg_catalog.count(*) filter (where not (st.sms = 'authorized' or (st.sms = 'none' and v_missing))))
  into v_unauthorized, v_by_channel
  from st;

  return pg_catalog.jsonb_build_object(
    'unauthorized_count', v_unauthorized,
    'unauthorized_by_channel', v_by_channel,
    'campaigns', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', c.id, 'name', c.name, 'status', c.status, 'planned_channel', c.planned_channel, 'purpose', c.purpose,
        'estimated_audience_count', c.estimated_audience_count) order by c.created_at desc, c.id)
      from (select * from public.marketing_campaigns x where x.org_id = p_org_id
            order by x.created_at desc, x.id limit 50) c
    ), '[]'::jsonb),
    'templates', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', t.id, 'name', t.name, 'channel', t.channel, 'purpose', t.purpose) order by t.created_at desc, t.id)
      from (select * from public.marketing_message_templates x where x.org_id = p_org_id and x.archived_at is null
            order by x.created_at desc, x.id limit 50) t
    ), '[]'::jsonb),
    'queue', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', q.id, 'recipient', q.recipient, 'status', q.status, 'message_body', q.message_body)
        order by q.created_at desc, q.id)
      from (select * from public.marketing_message_queue x where x.org_id = p_org_id
            order by x.created_at desc, x.id limit 50) q
    ), '[]'::jsonb),
    'services', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', s.id, 'name', s.name) order by s.position, s.name, s.id)
      from (select x.id, x.name, x.position from internal_read.services x
            where x.org_id = p_org_id and x.active order by x.position, x.name, x.id limit 500) s
    ), '[]'::jsonb),
    'audiences', v_audiences,
    'truncated', pg_catalog.to_jsonb(pg_catalog.array_remove(array[
      case when v_campaigns > 50 then 'campaigns' end,
      case when v_templates > 50 then 'templates' end,
      case when v_queue > 50 then 'queue' end], null))
  );
end;
$function$
;

-- ─── marketing_reviews_screen ───
CREATE OR REPLACE FUNCTION public.marketing_reviews_screen(p_org_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  v_tz text;
  v_month_start timestamptz;
begin
  if p_org_id is null or p_org_id not in (select public.auth_org_ids()) then
    raise exception 'Sem acesso a este estúdio.' using errcode = '42501';
  end if;
  if not public.has_permission(p_org_id, 'mensagens.configure') then
    raise exception 'Sem permissão para ver as avaliações.' using errcode = '42501';
  end if;

  select coalesce(nullif(o.timezone, ''), 'Europe/Madrid') into v_tz from public.organizations o where o.id = p_org_id;
  v_month_start := pg_catalog.date_trunc('month', pg_catalog.now() at time zone v_tz) at time zone v_tz;

  return pg_catalog.jsonb_build_object(
    'templates', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', t.id, 'name', t.name, 'channel', t.channel, 'language', t.language, 'body', t.body)
        order by t.name, t.id)
      from (select * from public.marketing_message_templates x
            where x.org_id = p_org_id and x.archived_at is null and x.purpose = 'review_request'
            order by x.name, x.id limit 500) t
    ), '[]'::jsonb),
    'month_sends', (
      select pg_catalog.count(*)
      from public.marketing_message_queue q
      join public.marketing_message_templates t on t.id = q.template_id and t.org_id = q.org_id
      where q.org_id = p_org_id and q.created_at >= v_month_start
        and t.archived_at is null and t.purpose = 'review_request'),
    'sends', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', q.id, 'created_at', q.created_at, 'client_id', q.client_id, 'client_name', c.full_name,
        'template_id', q.template_id, 'template_name', t.name, 'campaign_id', q.campaign_id, 'campaign_name', ca.name,
        'channel', q.channel, 'status', q.status, 'event_status', ev.status, 'sent_by', pr.full_name)
        order by q.created_at desc, q.id)
      from (select x.id, x.created_at, x.client_id, x.template_id, x.campaign_id, x.channel, x.status, x.created_by
            from public.marketing_message_queue x
            where x.org_id = p_org_id
              and x.template_id in (select r.id from public.marketing_message_templates r
                                    where r.org_id = p_org_id and r.archived_at is null and r.purpose = 'review_request')
            order by x.created_at desc, x.id limit 500) q
      left join internal_read.clients c on c.id = q.client_id and c.org_id = p_org_id
      left join public.marketing_message_templates t on t.id = q.template_id and t.org_id = p_org_id
      left join public.marketing_campaigns ca on ca.id = q.campaign_id and ca.org_id = p_org_id
      left join public.profiles pr on pr.user_id = q.created_by and pr.org_id = p_org_id
      left join lateral (
        select e.status from public.marketing_message_events e
        where e.org_id = p_org_id and e.queue_id = q.id order by e.created_at desc, e.id desc limit 1) ev on true
    ), '[]'::jsonb)
  );
end;
$function$
;

-- ─── messages_history_screen ───
CREATE OR REPLACE FUNCTION public.messages_history_screen(p_org_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
begin
  if p_org_id is null or p_org_id not in (select public.auth_org_ids()) then
    raise exception 'Sem acesso a este estúdio.' using errcode = '42501';
  end if;
  if not (public.has_permission(p_org_id, 'mensagens.use') or public.has_permission(p_org_id, 'mensagens.configure')) then
    raise exception 'Sem permissão para ver as mensagens.' using errcode = '42501';
  end if;

  return pg_catalog.jsonb_build_object(
    'templates_count', (select pg_catalog.count(*) from public.marketing_message_templates t
                        where t.org_id = p_org_id and t.archived_at is null),
    'truncated', (select pg_catalog.count(*) from public.marketing_message_queue x where x.org_id = p_org_id) > 500,
    'items', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', q.id, 'created_at', q.created_at, 'client_id', q.client_id, 'client_name', c.full_name,
        'template_id', q.template_id, 'template_name', t.name, 'campaign_id', q.campaign_id, 'campaign_name', ca.name,
        'channel', q.channel, 'status', q.status, 'event_status', ev.status, 'sent_by', pr.full_name)
        order by q.created_at desc, q.id)
      from (select x.id, x.created_at, x.client_id, x.template_id, x.campaign_id, x.channel, x.status, x.created_by
            from public.marketing_message_queue x where x.org_id = p_org_id
            order by x.created_at desc, x.id limit 500) q
      left join internal_read.clients c on c.id = q.client_id and c.org_id = p_org_id
      left join public.marketing_message_templates t on t.id = q.template_id and t.org_id = p_org_id
      left join public.marketing_campaigns ca on ca.id = q.campaign_id and ca.org_id = p_org_id
      left join public.profiles pr on pr.user_id = q.created_by and pr.org_id = p_org_id
      left join lateral (
        select e.status from public.marketing_message_events e
        where e.org_id = p_org_id and e.queue_id = q.id order by e.created_at desc, e.id desc limit 1) ev on true
    ), '[]'::jsonb)
  );
end;
$function$
;

-- ─── settings_section_read ───
CREATE OR REPLACE FUNCTION public.settings_section_read(p_org_id uuid, p_section text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  v_sub record;
  v_pin jsonb;
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'ajustes.manage') then
    raise exception 'Sem permissão para ver os ajustes' using errcode = '42501';
  end if;

  if p_section = 'plano' then
    -- Assinatura: a RLS só mostra para proprietária/administração (sem linha = "plano não configurado").
    select s.plan_key, s.status, s.trial_ends_at, s.limits_override, p.name, p.monthly_price_cents, p.currency, p.limits
      into v_sub
    from public.org_subscriptions s
    left join public.plans p on p.key = s.plan_key
    where s.org_id = p_org_id;
    if not found then
      return pg_catalog.jsonb_build_object('subscription', null, 'active_staff',
        (select pg_catalog.count(*) from public.staff_members sm where sm.org_id = p_org_id and sm.active));
    end if;
    return pg_catalog.jsonb_build_object(
      'subscription', pg_catalog.jsonb_build_object(
        'plan_key', v_sub.plan_key, 'status', v_sub.status, 'trial_ends_at', v_sub.trial_ends_at,
        'limits_override', v_sub.limits_override,
        'plan', case when v_sub.name is null then null else pg_catalog.jsonb_build_object(
          'name', v_sub.name, 'monthly_price_cents', v_sub.monthly_price_cents, 'currency', v_sub.currency, 'limits', v_sub.limits) end),
      'modules', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'key', m.key, 'name', m.name, 'description', m.description, 'is_core', m.is_core,
          'depends_on', m.depends_on, 'position', m.position) order by m.position)
        from public.modules m where m.active), '[]'::jsonb),
      'rules', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'module_key', pm.module_key, 'mode', pm.mode, 'extra_price_cents', pm.extra_price_cents))
        from public.plan_modules pm where pm.plan_key = v_sub.plan_key), '[]'::jsonb),
      'overrides', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'module_key', om.module_key, 'enabled', om.enabled, 'price_cents', om.price_cents))
        from public.org_modules om where om.org_id = p_org_id), '[]'::jsonb),
      'active_staff', (select pg_catalog.count(*) from public.staff_members sm where sm.org_id = p_org_id and sm.active)
    );
  elsif p_section = 'pagamentos' then
    if not public.org_has_module(p_org_id, 'cobranca') then
      return pg_catalog.jsonb_build_object('accounts', null);
    end if;
    return pg_catalog.jsonb_build_object('accounts', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', a.id, 'kind', a.kind, 'holder_name', a.holder_name, 'identifier', a.identifier,
        'bic', a.bic, 'bank_name', a.bank_name, 'active', a.active, 'position', a.position) order by a.position, a.created_at)
      from public.payment_accounts a where a.org_id = p_org_id), '[]'::jsonb));
  elsif p_section = 'dados' then
    return pg_catalog.jsonb_build_object('client_count',
      (select pg_catalog.count(*) from internal_read.clients c where c.org_id = p_org_id));
  elsif p_section = 'ficha' then
    -- Mesma regra do sistema antigo: sem leitura do PIN, a tela mostra "não definido".
    if public.has_permission(p_org_id, 'anamnese.view_status') then
      v_pin := public.studio_pin_status(p_org_id);
    end if;
    return pg_catalog.jsonb_build_object('pin', coalesce(v_pin, '{}'::jsonb));
  end if;
  raise exception 'Seção inválida' using errcode = '22023';
end;
$function$
;

-- ─── client_profile ───
CREATE OR REPLACE FUNCTION public.client_profile(p_org_id uuid, p_client_id uuid, p_done_statuses text[], p_with_photos boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  v_client jsonb;
  v_anamneses jsonb := '[]'::jsonb;
  v_photo_count integer := 0;
begin
  if (select auth.uid()) is null then
    raise exception 'Autenticação obrigatória' using errcode = '42501';
  end if;
  -- Sem clientes.view o perfil não existe para a pessoa (o app já confere; o banco também).
  if not public.has_permission(p_org_id, 'clientes.view') then
    return null;
  end if;

  select pg_catalog.to_jsonb(c) || pg_catalog.jsonb_build_object('marketing_state', public.marketing_state(c)) into v_client
  from public.clients c
  where c.org_id = p_org_id and c.id = p_client_id;
  if v_client is null then
    return null;
  end if;

  if public.has_permission(p_org_id, 'anamnese.view_status') then
    select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', s.id, 'template_title', s.template_title, 'status', s.status,
        'signed_at', s.signed_at, 'created_at', s.created_at) order by s.created_at desc, s.id), '[]'::jsonb)
    into v_anamneses
    from (
      select * from public.list_anamnese_status(p_org_id, null, p_client_id, null, null) ls
      order by ls.created_at desc, ls.id
      limit 100
    ) s;
  end if;

  if p_with_photos then
    v_photo_count := public.anamnese_client_photo_count(p_org_id, p_client_id);
  end if;

  return pg_catalog.jsonb_build_object(
    'client', v_client,
    'appointments', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(a) || pg_catalog.jsonb_build_object('appointment_items', coalesce((
          select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(i) order by i.created_at, i.id)
          from public.appointment_items i
          where i.appointment_id = a.id and i.org_id = p_org_id), '[]'::jsonb))
        order by a.start_at desc)
      from (
        select ap.* from public.appointments ap
        where ap.org_id = p_org_id and ap.client_id = p_client_id
        order by ap.start_at desc
        limit 30
      ) a), '[]'::jsonb),
    'appointment_count', (
      select pg_catalog.count(*) from public.appointments ap
      where ap.org_id = p_org_id and ap.client_id = p_client_id),
    'visits', (
      select pg_catalog.count(*) from public.appointments ap
      where ap.org_id = p_org_id and ap.client_id = p_client_id and ap.status = any (p_done_statuses)),
    'ledger', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'id', e.id, 'entry_type', e.entry_type, 'amount', e.amount, 'balance_before', e.balance_before,
          'balance_after', e.balance_after, 'source_type', e.source_type, 'source_id', e.source_id,
          'description', e.description, 'created_by', e.created_by, 'created_at', e.created_at,
          'appointment_id', e.appointment_id, 'sale_id', e.sale_id, 'payment_id', e.payment_id,
          'transaction_id', e.transaction_id, 'reversal_of_entry_id', e.reversal_of_entry_id,
          'reversed_by_entry_id', e.reversed_by_entry_id, 'reversed_at', e.reversed_at,
          'reversal_reason', e.reversal_reason,
          'created_by_name', (select p.full_name from public.profiles p
                              where p.org_id = p_org_id and p.user_id = e.created_by limit 1),
          'sale_number', (select s.number from internal_read.sales s where s.org_id = p_org_id and s.id = e.sale_id))
        order by e.created_at desc)
      from (
        select be.* from public.client_balance_entries be
        where be.org_id = p_org_id and be.client_id = p_client_id
        order by be.created_at desc
        limit 30
      ) e), '[]'::jsonb),
    'notes', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(n) order by n.note_date desc, n.created_at desc)
      from public.client_notes n
      where n.org_id = p_org_id and n.client_id = p_client_id and n.deleted_at is null), '[]'::jsonb),
    'credits', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(ce) order by ce.purchased_at desc)
      from public.client_entitlements ce
      where ce.org_id = p_org_id and ce.client_id = p_client_id), '[]'::jsonb),
    'anamneses', v_anamneses,
    'photo_count', v_photo_count,
    'messages', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'id', m.id, 'channel', m.channel, 'status', m.status, 'message_subject', m.message_subject,
          'message_body', m.message_body, 'created_at', m.created_at) order by m.created_at desc)
      from (
        select q.* from public.marketing_message_queue q
        where q.org_id = p_org_id and q.client_id = p_client_id
        order by q.created_at desc
        limit 30
      ) m), '[]'::jsonb),
    'message_count', (
      select pg_catalog.count(*) from public.marketing_message_queue q
      where q.org_id = p_org_id and q.client_id = p_client_id),
    'retouch_rules', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'id', sv.id, 'name', sv.name, 'retouch_included_days', sv.retouch_included_days) order by sv.name, sv.id)
      from internal_read.services sv
      where sv.org_id = p_org_id and sv.retouch_included_days is not null), '[]'::jsonb)
  );
end;
$function$
;

-- ─── anamnese_template_screen ───
CREATE OR REPLACE FUNCTION public.anamnese_template_screen(p_org_id uuid, p_template_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  v_tpl jsonb;
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'anamnese.view_status') then
    raise exception 'Sem permissão para consultar modelos de anamnese' using errcode = '42501';
  end if;
  select pg_catalog.jsonb_build_object(
      'id', t.id, 'title', t.title, 'questions', t.questions, 'consent_text', t.consent_text,
      'consent_version', t.consent_version, 'professional_form', t.professional_form,
      'is_active', t.is_active, 'version', t.version, 'country', t.country)
  into v_tpl
  from public.anamnese_templates t
  where t.org_id = p_org_id and t.id = p_template_id and t.active;
  if v_tpl is null then
    return null;
  end if;
  return pg_catalog.jsonb_build_object('template', v_tpl, 'services', coalesce((
    select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', sv.id, 'name', sv.name, 'requires_anamnese', sv.requires_anamnese)
      order by sv.position, sv.id)
    from internal_read.services sv
    where sv.org_id = p_org_id and sv.active and sv.anamnese_template_id = p_template_id), '[]'::jsonb));
end;
$function$
;

