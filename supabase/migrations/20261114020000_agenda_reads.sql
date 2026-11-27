-- Agenda: leituras da tela em UMA ida ao banco cada (porte para o TanStack Start, orçamento de chamadas).
-- Todas SECURITY INVOKER: rodam com a pessoa logada, então a RLS de appointments, time_blocks, clients,
-- appointment_deposits, sales, client_entitlements, agenda_waitlist etc. vale exatamente como nas consultas
-- que substituem (inclusive o alcance "só a minha agenda" da migration 20261030200000).
-- As regras (status que reservam pacote, janelas de data no fuso do estúdio, alcance pedido) continuam no app
-- (src/domain) e chegam como parâmetro; o banco só junta as linhas cruas que o app já usava.
-- Fichas: list_anamnese_status / list_anamnese_events (SECURITY DEFINER) só são chamadas quando a pessoa tem
-- anamnese.view_status, como antes (quem não tem via a agenda sem o status da ficha).
-- Encoding: UTF-8
set client_encoding = 'UTF8';

-- ─── Pacotes da cliente (marca "Incluído no pacote" e sessões livres) ─────────────────────────────
-- Antes: 2 consultas (créditos ativos + agendamentos abertos dos últimos 60 dias). O cálculo continua
-- no app (assignPackageCoverage, src/domain/agenda-package-coverage).
create or replace function public.agenda_package_rows(
  p_org_id uuid,
  p_client_ids uuid[],
  p_open_statuses text[],
  p_since timestamptz
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with ent as (
    select e.id, e.client_id, e.package_name, e.total_sessions, e.used_sessions, e.covered_services,
      e.expires_at, e.purchased_at
    from public.client_entitlements e
    where e.org_id = p_org_id and e.status = 'active' and e.client_id = any(coalesce(p_client_ids, '{}'::uuid[]))
  )
  select pg_catalog.jsonb_build_object(
    'entitlements', coalesce((select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(ent)) from ent), '[]'::jsonb),
    'appointments', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'client_id', a.client_id, 'start_at', a.start_at,
        'appointment_items', coalesce((
          select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', i.id, 'type', i.type, 'ref_id', i.ref_id, 'qty', i.qty)
                                      order by i.created_at, i.id)
          from public.appointment_items i where i.appointment_id = a.id and i.org_id = a.org_id), '[]'::jsonb)))
      from (
        select a.id, a.org_id, a.client_id, a.start_at
        from public.appointments a
        where a.org_id = p_org_id
          and a.client_id in (select distinct ent.client_id from ent)
          and a.status = any(p_open_statuses)
          and a.start_at >= p_since
        order by a.start_at
        limit 1000
      ) a), '[]'::jsonb)
  );
$$;

-- ─── Cartão da cliente (novo agendamento) ───────────────────────────────────────────────────────
-- Antes: 5 consultas (cliente, fichas assinadas, contagem de visitas, pacotes, últimos atendimentos).
-- p_more: e-mail, aniversário, pontos, "cliente desde" e os últimos serviços (só quem vê a agenda toda ou gerencia).
-- p_packages: pacotes com sessão livre (só quem vê a agenda toda).
create or replace function public.agenda_client_card(
  p_org_id uuid,
  p_client_id uuid,
  p_more boolean,
  p_packages boolean,
  p_now timestamptz,
  p_open_statuses text[],
  p_since timestamptz
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_client jsonb;
begin
  select case when p_more
    then pg_catalog.jsonb_build_object('id', c.id, 'full_name', c.full_name, 'phone', c.phone, 'email', c.email,
      'balance', c.balance, 'fixed_notes', c.fixed_notes, 'alert_type', c.alert_type, 'alert_text', c.alert_text,
      'birth_date', c.birth_date, 'loyalty_points', c.loyalty_points, 'created_at', c.created_at)
    else pg_catalog.jsonb_build_object('id', c.id, 'full_name', c.full_name, 'phone', c.phone,
      'balance', c.balance, 'fixed_notes', c.fixed_notes, 'alert_type', c.alert_type, 'alert_text', c.alert_text)
    end
  into v_client
  from public.clients c
  where c.org_id = p_org_id and c.id = p_client_id;
  if v_client is null then
    return null;
  end if;

  return pg_catalog.jsonb_build_object(
    'client', v_client,
    'signed_at', case when public.has_permission(p_org_id, 'anamnese.view_status') then (
      select max(s.signed_at) from public.list_anamnese_status(p_org_id, null, p_client_id, null, 'signed') s) end,
    'visits', (select count(*) from public.appointments a
               where a.org_id = p_org_id and a.client_id = p_client_id and a.status in ('Concluído', 'Pago', 'Pago Parcial')),
    'past', case when p_more then coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'start_at', a.start_at,
        'appointment_items', coalesce((
          select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('service_id', i.ref_id, 'name', i.name, 'price', i.price)
                                      order by i.created_at, i.id)
          from public.appointment_items i where i.appointment_id = a.id and i.org_id = a.org_id), '[]'::jsonb))
        order by a.start_at desc)
      from (
        select a.id, a.org_id, a.start_at from public.appointments a
        where a.org_id = p_org_id and a.client_id = p_client_id and a.status <> 'Cancelado' and a.start_at <= p_now
        order by a.start_at desc
        limit 8
      ) a), '[]'::jsonb) end,
    'packages', case when p_packages
      then public.agenda_package_rows(p_org_id, array[p_client_id], p_open_statuses, p_since) end
  );
end;
$$;

-- ─── Agendamento aberto (?ag=) ──────────────────────────────────────────────────────────────────
-- Antes: 8 a 10 consultas (agendamento, fichas, sinais, histórico, atendimentos da cliente, fichas assinadas,
-- comanda, eventos de cada ficha, nomes de quem mexeu). Pacotes vêm à parte (agenda_package_rows).
-- p_more: aniversário, total gasto, pontos e saldo da cliente (mesma regra do cartão: só quem vê a agenda toda
-- ou gerencia; quem só tem agenda.view_own não recebe). Token da ficha só para ficha pendente e dentro da validade.
create or replace function public.agenda_appointment_detail(
  p_org_id uuid,
  p_appointment_id uuid,
  p_more boolean default false
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_row jsonb;
  v_client_id uuid;
  v_created_by uuid;
  v_fichas boolean := public.has_permission(p_org_id, 'anamnese.view_status');
  v_history jsonb;
  v_ficha_rows jsonb := '[]'::jsonb;
begin
  select pg_catalog.to_jsonb(a) || pg_catalog.jsonb_build_object(
      'appointment_items', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(i) order by i.created_at, i.id)
        from public.appointment_items i where i.appointment_id = a.id and i.org_id = a.org_id), '[]'::jsonb),
      'clients', (
        select pg_catalog.jsonb_build_object('id', c.id, 'full_name', c.full_name, 'alert_text', c.alert_text,
          'alert_type', c.alert_type, 'fixed_notes', c.fixed_notes, 'phone', c.phone)
          || case when p_more then pg_catalog.jsonb_build_object('balance', c.balance, 'total_spent', c.total_spent,
               'loyalty_points', c.loyalty_points, 'birth_date', c.birth_date) else '{}'::jsonb end
        from public.clients c where c.id = a.client_id and c.org_id = a.org_id)),
    a.client_id, a.created_by
  into v_row, v_client_id, v_created_by
  from public.appointments a
  where a.org_id = p_org_id and a.id = p_appointment_id;
  if v_row is null then
    return null;
  end if;

  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'status', h.status, 'created_at', h.created_at, 'changed_by', h.changed_by) order by h.created_at desc), '[]'::jsonb)
  into v_history
  from public.appointment_status_history h
  where h.org_id = p_org_id and h.appointment_id = p_appointment_id;

  if v_fichas then
    select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(s) || pg_catalog.jsonb_build_object('public_token',
        case when s.status = 'pending' and (s.token_expires_at is null or s.token_expires_at > pg_catalog.now())
          then s.public_token end) order by s.created_at desc, s.id), '[]'::jsonb)
    into v_ficha_rows
    from public.list_anamnese_status(p_org_id, array[p_appointment_id], null, null, null) s;
  end if;

  return pg_catalog.jsonb_build_object(
    'appointment', v_row,
    'fichas', v_ficha_rows,
    'deposits', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', d.id, 'amount', d.amount, 'method', d.method, 'created_at', d.created_at) order by d.created_at)
      from public.appointment_deposits d
      where d.org_id = p_org_id and d.appointment_id = p_appointment_id and d.status = 'confirmed'), '[]'::jsonb),
    'history', v_history,
    'client_appointments', case when v_client_id is null then '[]'::jsonb else coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', x.id, 'start_at', x.start_at, 'status', x.status,
        'appointment_items', coalesce((
          select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('name', i.name) order by i.created_at, i.id)
          from public.appointment_items i where i.appointment_id = x.id and i.org_id = x.org_id), '[]'::jsonb))
        order by x.start_at desc)
      from (
        -- Os 200 mais recentes (o app reordena do mais antigo para o mais novo).
        select a.id, a.org_id, a.start_at, a.status from public.appointments a
        where a.org_id = p_org_id and a.client_id = v_client_id
        order by a.start_at desc
        limit 200
      ) x), '[]'::jsonb) end,
    'client_signed_at', case when v_fichas and v_client_id is not null then (
      select max(s.signed_at) from public.list_anamnese_status(p_org_id, null, v_client_id, null, 'signed') s) end,
    'sale', (
      select pg_catalog.jsonb_build_object(
        'id', s.id, 'number', s.number, 'status', s.status, 'total', s.total, 'paid_amount', s.paid_amount,
        'sale_payments', coalesce((
          select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('method', p.method, 'amount', p.amount) order by p.created_at, p.id)
          from public.sale_payments p where p.sale_id = s.id and p.org_id = s.org_id), '[]'::jsonb),
        'sale_items', coalesce((
          select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('item_type', si.item_type))
          from public.sale_items si where si.sale_id = s.id and si.org_id = s.org_id), '[]'::jsonb))
      from public.sales s
      where s.org_id = p_org_id and s.appointment_id = p_appointment_id and s.status <> 'cancelled'
      order by s.created_at desc
      limit 1),
    'ficha_events', case when v_fichas then coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(e) order by f.ord, e.created_at desc)
      from pg_catalog.jsonb_array_elements(v_ficha_rows) with ordinality as f(ficha, ord)
      cross join lateral public.list_anamnese_events(p_org_id, (f.ficha ->> 'id')::uuid, 20) e), '[]'::jsonb)
      else '[]'::jsonb end,
    'names', coalesce((
      select pg_catalog.jsonb_object_agg(p.user_id, p.full_name)
      from public.profiles p
      where p.org_id = p_org_id
        and p.user_id in (
          select v_created_by
          union
          select (h ->> 'changed_by')::uuid from pg_catalog.jsonb_array_elements(v_history) h)
        and nullif(pg_catalog.btrim(p.full_name), '') is not null), '{}'::jsonb)
  );
end;
$$;

-- ─── Tela da Agenda (quadro + agendamento aberto + novo agendamento) ─────────────────────────────
-- Antes: 10 a 12 consultas só para o quadro (agendamentos, fichas, bloqueios, tipos, equipe, serviços, pacotes,
-- "a confirmar amanhã", lista de espera, sinais, pacotes das clientes, profissional da pessoa) e mais 8 a 15
-- com ?ag=, ?novo=1 ou ?repetir=.
-- Só as colunas que o quadro usa (nada de linha inteira). Período de no máximo 43 dias (a grade do mês com as
-- semanas vizinhas tem até 42). p_light (vista do mês): sem observação, telefone, alerta, nome da profissional
-- nem preço/duração dos serviços, que a grade do mês não mostra.
-- p_own: alcance "só a minha agenda" (o app decide pelo agendaScopeOf; a RLS repete a regra).
-- p_packages: alcance "todas" (marca de pacote precisa ver todos os agendamentos abertos da cliente).
-- p_detail_more / p_card_more: dados extras da cliente (agenda toda ou gerencia).
create or replace function public.agenda_screen(
  p_org_id uuid,
  p_own boolean,
  p_from timestamptz,
  p_to timestamptz,
  p_tomorrow_from timestamptz,
  p_tomorrow_to timestamptz,
  p_waitlist boolean,
  p_packages boolean,
  p_open_statuses text[],
  p_since timestamptz,
  p_light boolean default false,
  p_detail_id uuid default null,
  p_detail_more boolean default false,
  p_repeat_id uuid default null,
  p_suggest_since timestamptz default null,
  p_card_client_id uuid default null,
  p_card_more boolean default false,
  p_card_packages boolean default false,
  p_now timestamptz default pg_catalog.now()
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_own uuid[];
  v_appts jsonb;
  v_ids uuid[];
  v_detail jsonb;
  v_package_clients uuid[] := '{}'::uuid[];
begin
  if p_to <= p_from or p_to - p_from > interval '43 days' then
    raise exception 'Período da agenda inválido (até 43 dias)' using errcode = '22023';
  end if;
  if p_own then
    select coalesce(pg_catalog.array_agg(sm.id), '{}'::uuid[]) into v_own
    from public.staff_members sm
    where sm.org_id = p_org_id and sm.user_id = (select auth.uid());
  end if;

  select coalesce(pg_catalog.jsonb_agg(x.j order by x.start_at, x.id), '[]'::jsonb), coalesce(pg_catalog.array_agg(x.id), '{}'::uuid[])
  into v_appts, v_ids
  from (
    select a.id, a.start_at, pg_catalog.jsonb_build_object(
        'id', a.id, 'staff_id', a.staff_id, 'start_at', a.start_at, 'end_at', a.end_at, 'client_id', a.client_id,
        'client_name', a.client_name, 'status', a.status, 'total', a.total, 'source', a.source,
        'recurrence_id', a.recurrence_id)
      || case when p_light then pg_catalog.jsonb_build_object('appointment_items', coalesce((
          select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', i.id, 'name', i.name, 'ref_id', i.ref_id,
            'bundle_id', i.bundle_id) order by i.created_at, i.id)
          from public.appointment_items i where i.appointment_id = a.id and i.org_id = a.org_id), '[]'::jsonb))
        else pg_catalog.jsonb_build_object(
          'staff_name', a.staff_name, 'notes', a.notes,
          'appointment_items', coalesce((
            select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', i.id, 'name', i.name, 'ref_id', i.ref_id,
              'bundle_id', i.bundle_id, 'price', i.price, 'qty', i.qty, 'duration_minutes', i.duration_minutes)
              order by i.created_at, i.id)
            from public.appointment_items i where i.appointment_id = a.id and i.org_id = a.org_id), '[]'::jsonb),
          'clients', (
            select pg_catalog.jsonb_build_object('phone', c.phone, 'alert_text', c.alert_text)
            from public.clients c where c.id = a.client_id and c.org_id = a.org_id))
        end as j
    from public.appointments a
    where a.org_id = p_org_id and a.start_at >= p_from and a.start_at < p_to
      and (not p_own or a.staff_id = any(v_own))
  ) x;

  if p_packages then
    select coalesce(pg_catalog.array_agg(distinct (e ->> 'client_id')::uuid), '{}'::uuid[]) into v_package_clients
    from pg_catalog.jsonb_array_elements(v_appts) e
    where e ->> 'client_id' is not null and e ->> 'status' = any(p_open_statuses);
  end if;

  if p_detail_id is not null then
    v_detail := public.agenda_appointment_detail(p_org_id, p_detail_id, p_detail_more);
    if p_packages and v_detail -> 'appointment' ->> 'client_id' is not null then
      v_package_clients := v_package_clients || ((v_detail -> 'appointment' ->> 'client_id')::uuid);
    end if;
  end if;
  if p_card_packages and p_card_client_id is not null then
    v_package_clients := v_package_clients || p_card_client_id;
  end if;

  return pg_catalog.jsonb_build_object(
    'own_staff_ids', case when p_own then pg_catalog.to_jsonb(v_own) end,
    'appointments', v_appts,
    -- Só o estado da ficha por agendamento (o quadro mostra pendente/assinada); nada de token.
    'anamneses', case when public.has_permission(p_org_id, 'anamnese.view_status') and pg_catalog.cardinality(v_ids) > 0 then coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('appointment_id', s.appointment_id, 'status', s.status)
        order by s.created_at desc, s.id)
      from public.list_anamnese_status(p_org_id, v_ids, null, null, null) s), '[]'::jsonb) else '[]'::jsonb end,
    'time_blocks', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'id', b.id, 'staff_id', b.staff_id, 'start_at', b.start_at, 'end_at', b.end_at, 'title', b.title,
          'reason', b.reason, 'notes', b.notes, 'time_block_type_id', b.time_block_type_id,
          'recurrence_frequency', b.recurrence_frequency, 'recurrence_count', b.recurrence_count,
          'allow_online_booking', b.allow_online_booking) order by b.start_at, b.id)
      from public.time_blocks b
      -- Piso no início: bloqueio dura menos de 24 h; o índice por início serve à busca.
      where b.org_id = p_org_id and b.start_at < p_to and b.end_at > p_from and b.start_at > p_from - interval '24 hours'
        and (not p_own or b.staff_id is null or b.staff_id = any(v_own))), '[]'::jsonb),
    'block_types', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', t.id, 'name', t.name) order by t.name, t.id)
      from public.time_block_types t where t.org_id = p_org_id and t.active), '[]'::jsonb),
    'staff', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', sm.id, 'name', sm.name, 'display_name', sm.display_name,
          'staff_shifts', coalesce((
            select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('day_of_week', sh.day_of_week, 'start_time', sh.start_time,
              'end_time', sh.end_time, 'active', sh.active) order by sh.day_of_week, sh.start_time, sh.id)
            from public.staff_shifts sh where sh.staff_id = sm.id and sh.org_id = sm.org_id), '[]'::jsonb))
        order by sm.position, sm.id)
      from public.staff_members sm where sm.org_id = p_org_id and sm.active), '[]'::jsonb),
    'services', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', s.id, 'name', s.name, 'price', s.price,
          'duration_minutes', s.duration_minutes, 'requires_anamnese', s.requires_anamnese, 'deposit_type', s.deposit_type,
          'deposit_value', s.deposit_value, 'retouch_included_days', s.retouch_included_days,
          'service_categories', (
            select pg_catalog.jsonb_build_object('id', sc.id, 'name', sc.name)
            from public.service_categories sc where sc.id = s.category_id and sc.org_id = s.org_id))
        order by s.position, s.id)
      from public.services s where s.org_id = p_org_id and s.active), '[]'::jsonb),
    'bundles', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', b.id, 'name', b.name, 'price', b.price,
        'service_bundle_items', b.service_bundle_items))
      from public.list_service_bundles_catalog(p_org_id, true) b), '[]'::jsonb),
    'unconfirmed_tomorrow', (
      select count(*) from public.appointments a
      where a.org_id = p_org_id and a.status in ('Reservado', 'Agendado')
        and a.start_at >= p_tomorrow_from and a.start_at < p_tomorrow_to
        and (not p_own or a.staff_id = any(v_own))),
    'waitlist_count', case when p_waitlist then (
      select count(*) from public.agenda_waitlist w
      where w.org_id = p_org_id and w.status in ('waiting', 'offered')
        and (not p_own or w.staff_id is null or w.staff_id = any(v_own))) else 0 end,
    'deposits', case when pg_catalog.cardinality(v_ids) > 0 then coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('appointment_id', d.appointment_id, 'amount', d.amount))
      from public.appointment_deposits d
      where d.org_id = p_org_id and d.status = 'confirmed' and d.appointment_id = any(v_ids)), '[]'::jsonb) else '[]'::jsonb end,
    'packages', case when pg_catalog.cardinality(v_package_clients) > 0
      then public.agenda_package_rows(p_org_id, v_package_clients, p_open_statuses, p_since) end,
    'detail', v_detail,
    'repeat', case when p_repeat_id is not null then (
      select pg_catalog.jsonb_build_object('id', a.id, 'staff_id', a.staff_id, 'start_at', a.start_at, 'end_at', a.end_at,
        'appointment_items', coalesce((
          select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', i.id, 'name', i.name, 'ref_id', i.ref_id,
            'price', i.price, 'qty', i.qty, 'discount', i.discount, 'duration_minutes', i.duration_minutes,
            'professional_id', i.professional_id) order by i.created_at, i.id)
          from public.appointment_items i where i.appointment_id = a.id and i.org_id = a.org_id), '[]'::jsonb))
      from public.appointments a where a.org_id = p_org_id and a.id = p_repeat_id) end,
    'suggested', case when p_suggest_since is not null then coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'client_id', a.client_id, 'client_name', a.client_name, 'start_at', a.start_at, 'status', a.status,
        'appointment_items', coalesce((
          select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('name', i.name) order by i.created_at, i.id)
          from public.appointment_items i where i.appointment_id = a.id and i.org_id = a.org_id), '[]'::jsonb),
        'clients', (select pg_catalog.jsonb_build_object('phone', c.phone)
                    from public.clients c where c.id = a.client_id and c.org_id = a.org_id))
        order by a.start_at desc)
      from (
        select a.id, a.org_id, a.client_id, a.client_name, a.start_at, a.status from public.appointments a
        where a.org_id = p_org_id and a.start_at >= p_suggest_since and a.status <> 'Cancelado'
        order by a.start_at desc
        limit 120
      ) a), '[]'::jsonb) end,
    'card', case when p_card_client_id is not null
      then public.agenda_client_card(p_org_id, p_card_client_id, p_card_more, false, p_now, p_open_statuses, p_since) end
  );
end;
$$;

-- ─── Leituras sob demanda do quadro ─────────────────────────────────────────────────────────────

-- Dias do mês com agendamento (pontos do calendário). Antes: 1 consulta (até 2000 linhas) + profissional da pessoa
-- (alcance "own"). Agora devolve só os dias distintos (AAAA-MM-DD) já no fuso do estúdio, lido no banco: até 42.
create or replace function public.agenda_marked_days(
  p_org_id uuid,
  p_own boolean,
  p_from timestamptz,
  p_to timestamptz
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select coalesce(pg_catalog.jsonb_agg(d.day order by d.day), '[]'::jsonb)
  from (
    select distinct pg_catalog.to_char(a.start_at at time zone o.timezone, 'YYYY-MM-DD') as day
    from public.appointments a
    join public.organizations o on o.id = a.org_id
    where a.org_id = p_org_id and a.start_at >= p_from and a.start_at < p_to and a.status <> 'Cancelado'
      and p_to - p_from <= interval '43 days'
      and (not p_own or a.staff_id in (
        select sm.id from public.staff_members sm where sm.org_id = p_org_id and sm.user_id = (select auth.uid())))
  ) d;
$$;

-- Expediente e horários ocupados de uma profissional num período de até 32 dias (o passo "Quando" do guia lê
-- a faixa de dias e a busca da próxima data livre numa ida só). Antes: 3 consultas por dia (+1 no alcance "own").
-- Nulo quando o alcance "own" não inclui a profissional pedida ou o período é inválido.
create or replace function public.agenda_staff_day(
  p_org_id uuid,
  p_own boolean,
  p_staff_id uuid,
  p_from timestamptz,
  p_to timestamptz,
  p_exclude_id uuid default null
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select case
    when p_to <= p_from or p_to - p_from > interval '32 days' then null
    when p_own and not exists (
      select 1 from public.staff_members sm
      where sm.org_id = p_org_id and sm.id = p_staff_id and sm.user_id = (select auth.uid()))
    then null
    else pg_catalog.jsonb_build_object(
      'shifts', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('day_of_week', sh.day_of_week,
          'start_time', sh.start_time, 'end_time', sh.end_time, 'active', sh.active))
        from public.staff_shifts sh where sh.org_id = p_org_id and sh.staff_id = p_staff_id), '[]'::jsonb),
      'busy', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('start_at', o.start_at, 'end_at', o.end_at))
        from (
          select a.start_at, a.end_at from public.appointments a
          where a.org_id = p_org_id and a.staff_id = p_staff_id and a.start_at < p_to and a.end_at > p_from
            and a.start_at > p_from - interval '24 hours'
            and a.status not in ('Cancelado', 'Ausência') and (p_exclude_id is null or a.id <> p_exclude_id)
          union all
          select b.start_at, b.end_at from public.time_blocks b
          where b.org_id = p_org_id and (b.staff_id = p_staff_id or b.staff_id is null)
            and b.start_at < p_to and b.end_at > p_from and b.start_at > p_from - interval '24 hours'
        ) o), '[]'::jsonb))
  end;
$$;

-- Lista de espera em aberto com os nomes. Antes: 4 consultas (+1 no alcance "own").
create or replace function public.agenda_waitlist_open(p_org_id uuid, p_own boolean)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(w) || pg_catalog.jsonb_build_object(
      'client_name', c.full_name, 'client_phone', c.phone, 'service_name', s.name, 'staff_name', sm.name)
    order by w.created_at, w.id), '[]'::jsonb)
  from (
    select w.* from public.agenda_waitlist w
    where w.org_id = p_org_id and w.status in ('waiting', 'offered')
      and (not p_own or w.staff_id is null or w.staff_id in (
        select m.id from public.staff_members m where m.org_id = p_org_id and m.user_id = (select auth.uid())))
    order by w.created_at
    limit 200
  ) w
  left join public.clients c on c.id = w.client_id and c.org_id = w.org_id
  left join public.services s on s.id = w.service_id and s.org_id = w.org_id
  left join public.staff_members sm on sm.id = w.staff_id and sm.org_id = w.org_id;
$$;

-- Fichas do agendamento e modelos ativos (painel do agendamento). Antes: 2 consultas.
-- Quem chama já conferiu anamnese.view_status; sem ela, list_anamnese_status recusa (42501).
-- Agendamento que a pessoa não enxerga (outro estúdio, ou de outra profissional no alcance "own"): vazio.
-- Token do link só para ficha pendente e dentro da validade.
create or replace function public.agenda_appointment_fichas(p_org_id uuid, p_appointment_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  if not exists (select 1 from public.appointments a where a.org_id = p_org_id and a.id = p_appointment_id) then
    return pg_catalog.jsonb_build_object('fichas', '[]'::jsonb, 'templates', '[]'::jsonb);
  end if;
  return pg_catalog.jsonb_build_object(
    'fichas', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'id', s.id, 'template_title', s.template_title, 'status', s.status, 'signed_at', s.signed_at,
          'requires_professional', s.requires_professional, 'professional_completed_at', s.professional_completed_at,
          'public_token', case when s.status = 'pending' and (s.token_expires_at is null or s.token_expires_at > pg_catalog.now())
            then s.public_token end)
        order by s.created_at desc, s.id)
      from public.list_anamnese_status(p_org_id, array[p_appointment_id], null, null, null) s), '[]'::jsonb),
    'templates', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', t.id, 'title', t.title) order by t.title, t.id)
      from public.anamnese_templates t where t.org_id = p_org_id and t.active), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.agenda_package_rows(uuid, uuid[], text[], timestamptz) from public, anon;
revoke all on function public.agenda_client_card(uuid, uuid, boolean, boolean, timestamptz, text[], timestamptz) from public, anon;
revoke all on function public.agenda_appointment_detail(uuid, uuid, boolean) from public, anon;
revoke all on function public.agenda_screen(uuid, boolean, timestamptz, timestamptz, timestamptz, timestamptz, boolean, boolean, text[], timestamptz, boolean, uuid, boolean, uuid, timestamptz, uuid, boolean, boolean, timestamptz) from public, anon;
revoke all on function public.agenda_marked_days(uuid, boolean, timestamptz, timestamptz) from public, anon;
revoke all on function public.agenda_staff_day(uuid, boolean, uuid, timestamptz, timestamptz, uuid) from public, anon;
revoke all on function public.agenda_waitlist_open(uuid, boolean) from public, anon;
revoke all on function public.agenda_appointment_fichas(uuid, uuid) from public, anon;

grant execute on function public.agenda_package_rows(uuid, uuid[], text[], timestamptz) to authenticated;
grant execute on function public.agenda_client_card(uuid, uuid, boolean, boolean, timestamptz, text[], timestamptz) to authenticated;
grant execute on function public.agenda_appointment_detail(uuid, uuid, boolean) to authenticated;
grant execute on function public.agenda_screen(uuid, boolean, timestamptz, timestamptz, timestamptz, timestamptz, boolean, boolean, text[], timestamptz, boolean, uuid, boolean, uuid, timestamptz, uuid, boolean, boolean, timestamptz) to authenticated;
grant execute on function public.agenda_marked_days(uuid, boolean, timestamptz, timestamptz) to authenticated;
grant execute on function public.agenda_staff_day(uuid, boolean, uuid, timestamptz, timestamptz, uuid) to authenticated;
grant execute on function public.agenda_waitlist_open(uuid, boolean) to authenticated;
grant execute on function public.agenda_appointment_fichas(uuid, uuid) to authenticated;
