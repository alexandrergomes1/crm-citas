-- Permissões pendentes (estado.md), parte 1: leitura interna para as funções das telas.
-- Encoding: UTF-8
set client_encoding = 'UTF8';
--
-- A parte 4 (20261114130300) fecha a leitura direta pela API: clientes só com clientes.view, catálogo só com
-- catalogo.view, comissão do serviço e custos só por função. Várias telas leem essas tabelas dentro de funções
-- SECURITY INVOKER (Agenda, Comanda, Financeiro, Mensagens, Marketing, Fidelidade, Ajustes, perfil da cliente).
-- Para não quebrá-las, a leitura dessas funções passa por visões no schema internal_read:
--   * mesmas colunas e mesma regra de antes (qualquer estúdio da pessoa logada: auth_org_ids; quem passava por cima
--     da RLS, como as funções DEFINER e o service_role, continua vendo tudo);
--   * o schema NÃO é exposto pela API (o PostgREST só expõe public e graphql_public; o pg_graphql só reflete o que
--     está no search_path), então só uma função do banco consegue usar as visões;
--   * só SELECT (as visões são atualizáveis por padrão: sem INSERT/UPDATE/DELETE concedido, ninguém grava por elas)
--     e security_barrier; internal_read.sales, sale_items e sale_payments servem às telas fora da comanda e do financeiro
--     (parte 5, 130400);
--   * cada função continua conferindo a própria permissão (agenda, comanda, financeiro, mensagens...). As listas que
--     não dependem de uma linha já visível ganharam a conferência que faltava: serviços e combos da agenda
--     (agenda_catalog_allowed) e o catálogo da comanda (checkout_catalog).
-- Trava de linha (FOR SHARE/UPDATE) não passa por visão sem UPDATE: a cliente do agendamento é travada por
-- agenda_lock_client (DEFINER, exige agenda.manage) e o serviço/produto editado continua travado na própria tabela.
-- As funções abaixo são as mesmas de antes, recriadas trocando public.<tabela> por internal_read.<tabela> na leitura;
-- as únicas outras mudanças estão marcadas com comentário (conferências novas, trava e catalog_screen).
-- Observação: visão com "select t.*" fixa as colunas na criação; coluna nova numa dessas tabelas exige recriar a visão
-- (o teste 10_security_checks compara as colunas de cada visão com as da tabela). As visões são security_barrier.

create schema if not exists internal_read;
revoke all on schema internal_read from public, anon;
grant usage on schema internal_read to authenticated, service_role;
comment on schema internal_read is
  'Leitura interna das funções do banco (não exposta pela API). Mesma visibilidade de antes: estúdios da pessoa logada.';

-- Quem já lia a tabela inteira (dona das tabelas, ou seja, as funções SECURITY DEFINER e as migrations; papéis com
-- BYPASSRLS, como service_role) continua lendo tudo pela visão, como na tabela; os demais, os próprios estúdios.
create or replace function internal_read.sees_all_rows()
returns boolean
language sql
stable
set search_path = ''
as $$
  select pg_catalog.pg_has_role(current_user, c.relowner, 'MEMBER')
      or coalesce((select r.rolbypassrls from pg_catalog.pg_roles r where r.rolname = current_user), false)
  from pg_catalog.pg_class c where c.oid = 'public.clients'::regclass;
$$;
revoke all on function internal_read.sees_all_rows() from public, anon;
grant execute on function internal_read.sees_all_rows() to authenticated, service_role;

-- Estúdios visíveis pela visão: todos para quem já via tudo; os da pessoa logada para os demais. Em forma de lista
-- calculada uma vez por consulta (array), sem "OR" na visão: o filtro por estúdio continua barato e usa o índice.
create or replace function internal_read.visible_org_ids()
returns setof uuid
language sql
stable
set search_path = ''
as $$
  select o from public.auth_org_ids() o where not (select internal_read.sees_all_rows())
  union all
  select g.id from public.organizations g where (select internal_read.sees_all_rows());
$$;
revoke all on function internal_read.visible_org_ids() from public, anon;
grant execute on function internal_read.visible_org_ids() to authenticated, service_role;

create or replace view internal_read.clients with (security_barrier) as
  select t.* from public.clients t
  where t.org_id = any (array(select internal_read.visible_org_ids()));
create or replace view internal_read.services with (security_barrier) as
  select t.* from public.services t
  where t.org_id = any (array(select internal_read.visible_org_ids()));
create or replace view internal_read.service_categories with (security_barrier) as
  select t.* from public.service_categories t
  where t.org_id = any (array(select internal_read.visible_org_ids()));
create or replace view internal_read.products with (security_barrier) as
  select t.* from public.products t
  where t.org_id = any (array(select internal_read.visible_org_ids()));
create or replace view internal_read.service_packages with (security_barrier) as
  select t.* from public.service_packages t
  where t.org_id = any (array(select internal_read.visible_org_ids()));
create or replace view internal_read.service_bundles with (security_barrier) as
  select t.* from public.service_bundles t
  where t.org_id = any (array(select internal_read.visible_org_ids()));
create or replace view internal_read.service_bundle_items with (security_barrier) as
  select t.* from public.service_bundle_items t
  where t.org_id = any (array(select internal_read.visible_org_ids()));
create or replace view internal_read.sales with (security_barrier) as
  select t.* from public.sales t
  where t.org_id = any (array(select internal_read.visible_org_ids()));
create or replace view internal_read.sale_items with (security_barrier) as
  select t.* from public.sale_items t
  where t.org_id = any (array(select internal_read.visible_org_ids()));
create or replace view internal_read.sale_payments with (security_barrier) as
  select t.* from public.sale_payments t
  where t.org_id = any (array(select internal_read.visible_org_ids()));

revoke all on all tables in schema internal_read from public, anon, authenticated, service_role;
grant select on all tables in schema internal_read to authenticated, service_role;

-- Serviços e combos fora de um agendamento (guia de novo agendamento): quem usa a agenda ou vê o catálogo.
create or replace function public.agenda_catalog_allowed(p_org_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select public.has_permission(p_org_id, 'catalogo.view')
      or public.has_permission(p_org_id, 'agenda.view_all')
      or public.has_permission(p_org_id, 'agenda.view_own')
      or public.has_permission(p_org_id, 'agenda.manage');
$$;
revoke all on function public.agenda_catalog_allowed(uuid) from public, anon;
grant execute on function public.agenda_catalog_allowed(uuid) to authenticated, service_role;

-- Trava a cliente durante a criação/edição do agendamento (antes: FOR SHARE na tabela, que agora pede clientes.view).
create or replace function public.agenda_lock_client(p_org_id uuid, p_client_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_permission(p_org_id, 'agenda.manage') then
    raise exception 'Sem permissão para alterar agendamentos' using errcode = '42501';
  end if;
  perform 1 from public.clients c where c.id = p_client_id and c.org_id = p_org_id for share;
end;
$$;
revoke all on function public.agenda_lock_client(uuid, uuid) from public, anon;
grant execute on function public.agenda_lock_client(uuid, uuid) to authenticated, service_role;

-- ═══ Agenda ═══
-- ─── agenda_appointment_detail ───
CREATE OR REPLACE FUNCTION public.agenda_appointment_detail(p_org_id uuid, p_appointment_id uuid, p_more boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
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
        from internal_read.clients c where c.id = a.client_id and c.org_id = a.org_id)),
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
    select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(s) order by s.created_at desc, s.id), '[]'::jsonb)
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
          from internal_read.sale_payments p where p.sale_id = s.id and p.org_id = s.org_id), '[]'::jsonb),
        'sale_items', coalesce((
          select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('item_type', si.item_type))
          from internal_read.sale_items si where si.sale_id = s.id and si.org_id = s.org_id), '[]'::jsonb))
      from internal_read.sales s
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
$function$
;

-- ─── agenda_change_client ───
CREATE OR REPLACE FUNCTION public.agenda_change_client(p_org_id uuid, p_appointment_id uuid, p_client_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_status text;
  v_old uuid;
  v_name text;
  v_blocked timestamptz;
begin
  if not public.has_permission(p_org_id, 'agenda.manage') then
    raise exception 'Sem permissão para alterar agendamentos' using errcode = '42501';
  end if;
  select a.status, a.client_id into v_status, v_old
  from public.appointments a where a.id = p_appointment_id and a.org_id = p_org_id for update;
  select c.full_name, c.blocked_at into v_name, v_blocked from internal_read.clients c where c.id = p_client_id and c.org_id = p_org_id;
  if v_status is null or v_name is null then
    raise exception 'Agendamento ou cliente não encontrado' using errcode = 'P0002';
  end if;
  if v_old is not distinct from p_client_id then
    return;
  end if;
  if v_status in ('Pago', 'Pago Parcial', 'Cancelado', 'Ausência') then
    raise exception 'Atendimento pago, cancelado ou com falta não muda mais.' using errcode = 'P0001';
  end if;
  if v_blocked is not null then
    raise exception 'Cliente possui bloqueio para novos agendamentos' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.appointment_deposits d
             where d.org_id = p_org_id and d.appointment_id = p_appointment_id and d.status = 'confirmed') then
    raise exception 'Este agendamento tem sinal registrado. Para trocar a cliente, cancele e crie outro agendamento.' using errcode = 'P0001';
  end if;
  if public.anamnese_exists_for(p_org_id, p_appointment_id, null) then
    raise exception 'Este agendamento tem ficha ligada. Para trocar a cliente, cancele e crie outro agendamento.' using errcode = 'P0001';
  end if;
  update public.appointments set client_id = p_client_id, client_name = v_name
  where id = p_appointment_id and org_id = p_org_id;
  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (p_org_id, (select auth.uid()), 'appointments', 'APPOINTMENT_CLIENT_CHANGED', p_appointment_id,
    pg_catalog.jsonb_build_object('client_id', v_old), pg_catalog.jsonb_build_object('client_id', p_client_id));
end;
$function$
;

-- ─── agenda_screen ───
CREATE OR REPLACE FUNCTION public.agenda_screen(p_org_id uuid, p_own boolean, p_from timestamp with time zone, p_to timestamp with time zone, p_tomorrow_from timestamp with time zone, p_tomorrow_to timestamp with time zone, p_waitlist boolean, p_packages boolean, p_open_statuses text[], p_since timestamp with time zone, p_light boolean DEFAULT false, p_detail_id uuid DEFAULT NULL::uuid, p_detail_more boolean DEFAULT false, p_repeat_id uuid DEFAULT NULL::uuid, p_suggest_since timestamp with time zone DEFAULT NULL::timestamp with time zone, p_card_client_id uuid DEFAULT NULL::uuid, p_card_more boolean DEFAULT false, p_card_packages boolean DEFAULT false, p_now timestamp with time zone DEFAULT now())
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
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
            from internal_read.clients c where c.id = a.client_id and c.org_id = a.org_id))
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
            from internal_read.service_categories sc where sc.id = s.category_id and sc.org_id = s.org_id))
        order by s.position, s.id)
      from internal_read.services s where s.org_id = p_org_id and s.active
        and public.agenda_catalog_allowed(p_org_id)), '[]'::jsonb),
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
                    from internal_read.clients c where c.id = a.client_id and c.org_id = a.org_id))
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
$function$
;

-- ─── agenda_waitlist_open ───
CREATE OR REPLACE FUNCTION public.agenda_waitlist_open(p_org_id uuid, p_own boolean)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
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
  left join internal_read.clients c on c.id = w.client_id and c.org_id = w.org_id
  left join internal_read.services s on s.id = w.service_id and s.org_id = w.org_id
  left join public.staff_members sm on sm.id = w.staff_id and sm.org_id = w.org_id;
$function$
;

-- ─── agenda_rpc_items ───
CREATE OR REPLACE FUNCTION public.agenda_rpc_items(p_org_id uuid, p_appointment_id uuid)
 RETURNS TABLE(item_id uuid, item jsonb, qty integer, discount numeric, ord bigint)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select i.id,
    pg_catalog.jsonb_build_object(
      'service_id', i.ref_id, 'service_name', i.name, 'price', coalesce(i.price, 0),
      'duration_minutes', public.agenda_item_duration(i.duration_minutes, s.duration_minutes, s.id is not null),
      'professional_id', i.professional_id, 'bundle_id', i.bundle_id, 'bundle_item_id', i.bundle_item_id,
      'bundle_name', i.bundle_name, 'bundle_item_position', i.bundle_item_position,
      'bundle_allocated_price', i.bundle_allocated_price,
      'bundle_original_price_snapshot', i.bundle_original_price_snapshot),
    i.qty, i.discount,
    pg_catalog.row_number() over (order by i.created_at, i.id)
  from public.appointment_items i
  left join internal_read.services s on s.id = i.ref_id and s.org_id = i.org_id
  where i.org_id = p_org_id and i.appointment_id = p_appointment_id;
$function$
;

-- ─── agenda_edit_items ───
CREATE OR REPLACE FUNCTION public.agenda_edit_items(p_org_id uuid, p_appointment_id uuid, p_op text, p_item_id uuid DEFAULT NULL::uuid, p_service_id uuid DEFAULT NULL::uuid, p_name text DEFAULT NULL::text, p_price numeric DEFAULT NULL::numeric, p_professional_id uuid DEFAULT NULL::uuid, p_duration integer DEFAULT NULL::integer, p_force boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_appt public.appointments;
  v_items jsonb;
  v_current integer;
  v_catalog integer;
begin
  if not public.has_permission(p_org_id, 'agenda.manage') then
    raise exception 'Sem permissão para alterar agendamentos' using errcode = '42501';
  end if;
  if p_op not in ('add', 'update', 'remove') then
    raise exception 'Operação inválida' using errcode = '22023';
  end if;
  if p_op = 'add' and (nullif(pg_catalog.btrim(p_name), '') is null or pg_catalog.char_length(p_name) > 200) then
    raise exception 'Nome do serviço inválido (até 200 caracteres).' using errcode = '22023';
  end if;
  if p_op <> 'remove' and (p_price is null or p_price < 0 or p_price > 100000) then
    raise exception 'Preço inválido.' using errcode = '22023';
  end if;

  -- Trava o agendamento até o fim: a leitura dos itens e a regravação veem o mesmo estado.
  select * into v_appt from public.appointments a
  where a.id = p_appointment_id and a.org_id = p_org_id
  for update;
  if not found then
    raise exception 'Agendamento não encontrado' using errcode = 'P0002';
  end if;
  if v_appt.status in ('Pago', 'Pago Parcial', 'Cancelado', 'Ausência') then
    raise exception 'Atendimento pago, cancelado ou com ausência não muda mais.' using errcode = 'P0001';
  end if;

  if p_op = 'add' then
    select s.duration_minutes into v_catalog from internal_read.services s where s.id = p_service_id and s.org_id = p_org_id;
    if not found then
      raise exception 'Serviço não encontrado no catálogo' using errcode = 'P0002';
    end if;
  elsif not exists (select 1 from public.appointment_items i
                    where i.id = p_item_id and i.appointment_id = p_appointment_id and i.org_id = p_org_id) then
    raise exception 'Item não encontrado' using errcode = 'P0002';
  end if;

  if p_op = 'update' then
    select (r.item ->> 'duration_minutes')::integer into v_current
    from public.agenda_rpc_items(p_org_id, p_appointment_id) r where r.item_id = p_item_id;
    if p_duration is null or p_duration = v_current then
      -- Uma operação só: trava o agendamento, grava o item, soma o total e audita.
      perform public.update_appointment_item_atomic(p_org_id, p_appointment_id, p_item_id, p_price, p_professional_id);
      return;
    end if;
  end if;

  -- A RPC de regravação não preserva quantidade nem desconto por item.
  if exists (select 1 from public.agenda_rpc_items(p_org_id, p_appointment_id) r
             where coalesce(r.qty, 1) <> 1 or coalesce(r.discount, 0) <> 0) then
    raise exception 'Este agendamento tem quantidade ou desconto definidos por serviço, que seriam apagados. Ajuste pelo checkout.'
      using errcode = 'P0001';
  end if;

  select coalesce(pg_catalog.jsonb_agg(
      case when p_op = 'update' and r.item_id = p_item_id
        then r.item || pg_catalog.jsonb_build_object('price', p_price, 'professional_id', p_professional_id, 'duration_minutes', p_duration)
        else r.item end
      order by r.ord) filter (where not (p_op = 'remove' and r.item_id = p_item_id)), '[]'::jsonb)
  into v_items
  from public.agenda_rpc_items(p_org_id, p_appointment_id) r;

  if p_op = 'add' then
    v_items := v_items || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'service_id', p_service_id, 'service_name', p_name, 'price', p_price,
      'duration_minutes', public.agenda_item_duration(null, v_catalog, true),
      'professional_id', p_professional_id, 'bundle_id', null, 'bundle_item_id', null));
  end if;

  perform public.agenda_save_items(p_org_id, v_appt, v_items, p_op = 'update' and p_force);
end;
$function$
;

-- ─── create_appointment_atomic ───
CREATE OR REPLACE FUNCTION public.create_appointment_atomic(p_org_id uuid, p_client_id uuid, p_staff_id uuid, p_start_at timestamp with time zone, p_end_at timestamp with time zone, p_duration_minutes integer, p_status text, p_source text, p_notes text, p_internal_notes text, p_total numeric, p_items jsonb, p_force_override boolean DEFAULT false)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_role text;
  v_client public.clients;
  v_staff_name text := '';
  v_appointment_id uuid;
  v_item jsonb;
  v_item_duration integer;
  v_service_id uuid;
  v_professional_id uuid;
  v_bundle_id uuid;
  v_bundle_item_id uuid;
  v_bundle_name text;
  v_bundle_item_position integer;
  v_bundle_allocated_price numeric;
  v_bundle_original_price_snapshot numeric;
  v_internal_notes text := nullif(pg_catalog.btrim(p_internal_notes), '');
begin
  v_role := public.auth_user_role(p_org_id);
  if not public.has_permission(p_org_id, 'agenda.manage') then
    raise exception 'Sem permissao para criar agendamentos'
      using errcode = '42501';
  end if;

  if p_force_override and not public.has_permission(p_org_id, 'agenda.override_conflict') then
    raise exception 'Somente gestores podem forcar conflitos'
      using errcode = '42501';
  end if;

  if p_duration_minutes < 1 or p_duration_minutes > 1440 then
    raise exception 'Duracao invalida' using errcode = '22023';
  end if;

  if p_status not in (
    'Reservado', 'Agendado', 'Confirmado', 'Iniciado', 'Concluído',
    'Pago Parcial', 'Pago', 'Ausência', 'Cancelado'
  ) then
    raise exception 'Status de agendamento invalido' using errcode = '22023';
  end if;

  if p_source not in ('MANUAL', 'WHATSAPP', 'ONLINE', 'PHONE') then
    raise exception 'Origem de agendamento invalida' using errcode = '22023';
  end if;

  if p_total < 0 or p_total > 1000000 then
    raise exception 'Total do agendamento invalido' using errcode = '22003';
  end if;

  if pg_catalog.jsonb_typeof(coalesce(p_items, '[]'::jsonb)) <> 'array' then
    raise exception 'Itens invalidos' using errcode = '22023';
  end if;

  -- Trava a cliente (FOR SHARE) por função própria: a leitura vem de internal_read, que não aceita trava.
  perform public.agenda_lock_client(p_org_id, p_client_id);
  select *
    into v_client
  from internal_read.clients c
  where c.id = p_client_id
    and c.org_id = p_org_id;

  if not found then
    raise exception 'Cliente nao encontrado nesta organizacao'
      using errcode = 'P0002';
  end if;

  if v_client.blocked_at is not null and not p_force_override then
    raise exception 'Cliente possui bloqueio para novos agendamentos'
      using errcode = 'P0001';
  end if;

  perform public.agenda_assert_slot_available(
    p_org_id,
    p_staff_id,
    p_start_at,
    p_end_at,
    '{}'::uuid[],
    p_force_override
  );

  if p_staff_id is not null then
    select coalesce(sm.display_name, sm.name)
      into v_staff_name
    from public.staff_members sm
    where sm.id = p_staff_id
      and sm.org_id = p_org_id;
  end if;

  if p_force_override then
    v_internal_notes := pg_catalog.concat_ws(
      E'\n',
      pg_catalog.format(
        '[CONFLITO FORCADO - %s - %s]',
        v_role,
        pg_catalog.to_char(pg_catalog.now(), 'YYYY-MM-DD HH24:MI')
      ),
      v_internal_notes
    );
  end if;

  insert into public.appointments (
    org_id, client_id, client_name, staff_id, staff_name,
    start_at, end_at, duration_minutes, status, notes, internal_notes,
    source, total, discount, tip
  )
  values (
    p_org_id, p_client_id, v_client.full_name, p_staff_id, coalesce(v_staff_name, ''),
    p_start_at, p_end_at, p_duration_minutes, p_status,
    nullif(pg_catalog.btrim(p_notes), ''), v_internal_notes,
    p_source, pg_catalog.round(p_total, 2), 0, 0
  )
  returning id into v_appointment_id;

  for v_item in
    select value
    from pg_catalog.jsonb_array_elements(coalesce(p_items, '[]'::jsonb))
  loop
    if nullif(pg_catalog.btrim(v_item ->> 'service_name'), '') is null then
      raise exception 'Servico invalido' using errcode = '22023';
    end if;

    if (v_item ->> 'price')::numeric < 0 then
      raise exception 'Preco de servico invalido' using errcode = '22003';
    end if;

    v_item_duration := nullif(v_item ->> 'duration_minutes', '')::integer;
    if v_item_duration is not null and (v_item_duration < 5 or v_item_duration > 720) then
      raise exception 'Duracao do item invalida' using errcode = '22023';
    end if;

    v_service_id := nullif(v_item ->> 'service_id', '')::uuid;
    v_professional_id := coalesce(
      nullif(v_item ->> 'professional_id', '')::uuid,
      p_staff_id
    );
    v_bundle_id := nullif(v_item ->> 'bundle_id', '')::uuid;
    v_bundle_item_id := nullif(v_item ->> 'bundle_item_id', '')::uuid;
    v_bundle_name := nullif(pg_catalog.btrim(coalesce(v_item ->> 'bundle_name', '')), '');
    v_bundle_item_position := nullif(v_item ->> 'bundle_item_position', '')::integer;
    v_bundle_allocated_price := nullif(v_item ->> 'bundle_allocated_price', '')::numeric;
    v_bundle_original_price_snapshot := nullif(v_item ->> 'bundle_original_price_snapshot', '')::numeric;

    if v_service_id is not null and not exists (
      select 1 from internal_read.services s
      where s.id = v_service_id and s.org_id = p_org_id
    ) then
      raise exception 'Servico nao pertence a esta organizacao'
        using errcode = '23503';
    end if;

    if v_professional_id is not null and not exists (
      select 1 from public.staff_members sm
      where sm.id = v_professional_id and sm.org_id = p_org_id
    ) then
      raise exception 'Profissional do servico invalido'
        using errcode = '23503';
    end if;

    if v_bundle_id is not null and not exists (
      select 1 from internal_read.service_bundles b
      where b.id = v_bundle_id and b.org_id = p_org_id
    ) then
      raise exception 'Bundle nao pertence a esta organizacao'
        using errcode = '23503';
    end if;

    insert into public.appointment_items (
      org_id, appointment_id, type, ref_id, name, price,
      cost_amount, qty, discount, commission_pct, professional_id,
      bundle_id, bundle_item_id, bundle_name, bundle_item_position,
      bundle_allocated_price, bundle_original_price_snapshot, duration_minutes
    )
    values (
      p_org_id, v_appointment_id, 'service', v_service_id,
      v_item ->> 'service_name', (v_item ->> 'price')::numeric,
      0, 1, 0, 0, v_professional_id,
      v_bundle_id, v_bundle_item_id, v_bundle_name, v_bundle_item_position,
      v_bundle_allocated_price, v_bundle_original_price_snapshot, v_item_duration
    );
  end loop;

  insert into public.appointment_status_history (
    org_id, appointment_id, status, changed_by, notes
  )
  values (
    p_org_id, v_appointment_id, p_status, auth.uid(), 'appointment_created'
  );

  insert into public.audit_logs (
    org_id, user_id, table_name, operation, record_id, new_data
  )
  values (
    p_org_id,
    auth.uid(),
    'appointments',
    'APPOINTMENT_CREATED',
    v_appointment_id,
    pg_catalog.jsonb_build_object(
      'client_id', p_client_id,
      'staff_id', p_staff_id,
      'start_at', p_start_at,
      'end_at', p_end_at,
      'item_count', pg_catalog.jsonb_array_length(coalesce(p_items, '[]'::jsonb)),
      'force_override', p_force_override
    )
  );

  return v_appointment_id;
end;
$function$
;

-- ─── create_recurring_appointments_atomic ───
CREATE OR REPLACE FUNCTION public.create_recurring_appointments_atomic(p_org_id uuid, p_client_id uuid, p_staff_id uuid, p_staff_name text, p_status text, p_source text, p_notes text, p_internal_notes text, p_duration_minutes integer, p_total numeric, p_occurrences jsonb, p_items jsonb, p_force_override boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_role text;
  v_client public.clients;
  v_occurrence jsonb;
  v_item jsonb;
  v_item_duration integer;
  v_start timestamptz;
  v_end timestamptz;
  v_index integer;
  v_count integer;
  v_recurrence_id uuid := gen_random_uuid();
  v_appointment_id uuid;
  v_first_appointment_id uuid;
  v_internal_notes text := p_internal_notes;
begin
  v_role := public.auth_user_role(p_org_id);
  if not public.has_permission(p_org_id, 'agenda.manage') then
    raise exception 'Sem permissao para criar agendamentos'
      using errcode = '42501';
  end if;

  if p_force_override and not public.has_permission(p_org_id, 'agenda.override_conflict') then
    raise exception 'Somente gestores podem forcar conflitos'
      using errcode = '42501';
  end if;

  if p_duration_minutes < 1 or p_duration_minutes > 1440 then
    raise exception 'Duracao invalida'
      using errcode = '22023';
  end if;

  if pg_catalog.jsonb_typeof(p_occurrences) <> 'array' then
    raise exception 'Ocorrencias invalidas'
      using errcode = '22023';
  end if;

  v_count := pg_catalog.jsonb_array_length(p_occurrences);
  if v_count < 2 or v_count > 52 then
    raise exception 'Quantidade de ocorrencias invalida'
      using errcode = '22023';
  end if;

  if pg_catalog.jsonb_typeof(coalesce(p_items, '[]'::jsonb)) <> 'array' then
    raise exception 'Itens invalidos'
      using errcode = '22023';
  end if;

  -- Trava a cliente (FOR SHARE) por função própria: a leitura vem de internal_read, que não aceita trava.
  perform public.agenda_lock_client(p_org_id, p_client_id);
  select *
    into v_client
  from internal_read.clients
  where id = p_client_id
    and org_id = p_org_id;

  if not found then
    raise exception 'Cliente nao encontrado'
      using errcode = 'P0002';
  end if;

  if v_client.blocked_at is not null and not p_force_override then
    raise exception 'Cliente possui bloqueio para novos agendamentos'
      using errcode = 'P0001';
  end if;

  if p_staff_id is not null then
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(p_org_id::text || ':' || p_staff_id::text, 0)
    );
  end if;

  for v_occurrence in
    select value from pg_catalog.jsonb_array_elements(p_occurrences)
  loop
    v_start := (v_occurrence ->> 'start_at')::timestamptz;
    v_end := (v_occurrence ->> 'end_at')::timestamptz;
    v_index := (v_occurrence ->> 'index')::integer;

    if v_end <= v_start then
      raise exception 'Horario final deve ser posterior ao inicial'
        using errcode = '22023';
    end if;

    if p_staff_id is not null and not p_force_override then
      if exists (
        select 1
        from public.appointments a
        where a.org_id = p_org_id
          and a.staff_id = p_staff_id
          and a.status not in ('Cancelado', 'Ausência')
          and a.start_at < v_end
          and a.end_at > v_start
      ) then
        raise exception 'O profissional ja possui um atendimento em uma das ocorrencias'
          using errcode = '23P01';
      end if;

      if exists (
        select 1
        from public.time_blocks tb
        where tb.org_id = p_org_id
          and (tb.staff_id = p_staff_id or tb.staff_id is null)
          and tb.start_at < v_end
          and tb.end_at > v_start
      ) then
        raise exception 'O profissional possui um bloqueio em uma das ocorrencias'
          using errcode = '23P01';
      end if;
    end if;
  end loop;

  if p_force_override then
    v_internal_notes := pg_catalog.concat_ws(
      E'\n',
      pg_catalog.format(
        '[CONFLITO FORCADO - %s - %s]',
        v_role,
        pg_catalog.to_char(pg_catalog.now(), 'YYYY-MM-DD HH24:MI')
      ),
      nullif(p_internal_notes, '')
    );
  end if;

  for v_occurrence in
    select value
    from pg_catalog.jsonb_array_elements(p_occurrences)
    order by (value ->> 'index')::integer
  loop
    v_start := (v_occurrence ->> 'start_at')::timestamptz;
    v_end := (v_occurrence ->> 'end_at')::timestamptz;
    v_index := (v_occurrence ->> 'index')::integer;

    insert into public.appointments (
      org_id,
      client_id,
      client_name,
      staff_id,
      staff_name,
      start_at,
      end_at,
      duration_minutes,
      status,
      notes,
      internal_notes,
      source,
      total,
      discount,
      tip,
      recurrence_id,
      recurrence_index
    )
    values (
      p_org_id,
      p_client_id,
      v_client.full_name,
      p_staff_id,
      coalesce(p_staff_name, ''),
      v_start,
      v_end,
      p_duration_minutes,
      p_status,
      p_notes,
      v_internal_notes,
      p_source,
      p_total,
      0,
      0,
      v_recurrence_id,
      v_index
    )
    returning id into v_appointment_id;

    if v_first_appointment_id is null then
      v_first_appointment_id := v_appointment_id;
    end if;

    for v_item in
      select value from pg_catalog.jsonb_array_elements(coalesce(p_items, '[]'::jsonb))
    loop
      if nullif(pg_catalog.btrim(v_item ->> 'service_name'), '') is null then
        raise exception 'Servico invalido'
          using errcode = '22023';
      end if;

      v_item_duration := nullif(v_item ->> 'duration_minutes', '')::integer;
      if v_item_duration is not null and (v_item_duration < 5 or v_item_duration > 720) then
        raise exception 'Duracao do item invalida' using errcode = '22023';
      end if;

      insert into public.appointment_items (
        org_id,
        appointment_id,
        type,
        ref_id,
        name,
        price,
        cost_amount,
        qty,
        discount,
        commission_pct,
        professional_id,
        duration_minutes
      )
      values (
        p_org_id,
        v_appointment_id,
        'service',
        nullif(v_item ->> 'service_id', '')::uuid,
        v_item ->> 'service_name',
        (v_item ->> 'price')::numeric,
        0,
        1,
        0,
        0,
        coalesce(
          nullif(v_item ->> 'professional_id', '')::uuid,
          p_staff_id
        ),
        v_item_duration
      );
    end loop;

    insert into public.appointment_status_history (
      org_id,
      appointment_id,
      status,
      changed_by,
      notes
    )
    values (
      p_org_id,
      v_appointment_id,
      p_status,
      auth.uid(),
      'recurrence_created'
    );
  end loop;

  insert into public.audit_logs (
    org_id,
    user_id,
    table_name,
    operation,
    record_id,
    new_data
  )
  values (
    p_org_id,
    auth.uid(),
    'appointments',
    'RECURRENCE_CREATED',
    v_recurrence_id,
    pg_catalog.jsonb_build_object(
      'recurrence_id', v_recurrence_id,
      'client_id', p_client_id,
      'staff_id', p_staff_id,
      'count', v_count,
      'force_override', p_force_override
    )
  );

  return pg_catalog.jsonb_build_object(
    'first_appointment_id', v_first_appointment_id,
    'recurrence_id', v_recurrence_id,
    'count', v_count
  );
end;
$function$
;

-- ─── update_appointment_atomic ───
CREATE OR REPLACE FUNCTION public.update_appointment_atomic(p_org_id uuid, p_appointment_id uuid, p_client_id uuid, p_staff_id uuid, p_start_at timestamp with time zone, p_end_at timestamp with time zone, p_duration_minutes integer, p_status text, p_source text, p_notes text, p_internal_notes text, p_total numeric, p_items jsonb, p_force_override boolean DEFAULT false)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_role text;
  v_previous public.appointments;
  v_updated public.appointments;
  v_client public.clients;
  v_staff_name text := '';
  v_item jsonb;
  v_item_duration integer;
  v_service_id uuid;
  v_professional_id uuid;
  v_bundle_id uuid;
  v_bundle_item_id uuid;
  v_bundle_name text;
  v_bundle_item_position integer;
  v_bundle_allocated_price numeric;
  v_bundle_original_price_snapshot numeric;
  v_internal_notes text := nullif(pg_catalog.btrim(p_internal_notes), '');
begin
  v_role := public.auth_user_role(p_org_id);
  if not public.has_permission(p_org_id, 'agenda.manage') then
    raise exception 'Sem permissao para atualizar agendamentos'
      using errcode = '42501';
  end if;

  if p_force_override and not public.has_permission(p_org_id, 'agenda.override_conflict') then
    raise exception 'Somente gestores podem forcar conflitos'
      using errcode = '42501';
  end if;

  select *
    into v_previous
  from public.appointments a
  where a.id = p_appointment_id
    and a.org_id = p_org_id
  for update;

  if not found then
    raise exception 'Agendamento nao encontrado' using errcode = 'P0002';
  end if;

  if v_previous.status in ('Pago', 'Pago Parcial', 'Cancelado', 'Ausência') then
    raise exception 'Agendamento em estado terminal nao pode ser editado'
      using errcode = 'P0001';
  end if;

  if not public.agenda_status_transition_allowed(v_previous.status, p_status) then
    raise exception 'Transicao de status nao permitida' using errcode = '22023';
  end if;

  if p_duration_minutes < 1 or p_duration_minutes > 1440 then
    raise exception 'Duracao invalida' using errcode = '22023';
  end if;

  if p_source not in ('MANUAL', 'WHATSAPP', 'ONLINE', 'PHONE') then
    raise exception 'Origem de agendamento invalida' using errcode = '22023';
  end if;

  if p_total < 0 or p_total > 1000000 then
    raise exception 'Total do agendamento invalido' using errcode = '22003';
  end if;

  if pg_catalog.jsonb_typeof(coalesce(p_items, '[]'::jsonb)) <> 'array' then
    raise exception 'Itens invalidos' using errcode = '22023';
  end if;

  -- Trava a cliente (FOR SHARE) por função própria: a leitura vem de internal_read, que não aceita trava.
  perform public.agenda_lock_client(p_org_id, p_client_id);
  select *
    into v_client
  from internal_read.clients c
  where c.id = p_client_id
    and c.org_id = p_org_id;

  if not found then
    raise exception 'Cliente nao encontrado nesta organizacao'
      using errcode = 'P0002';
  end if;

  if v_client.blocked_at is not null
    and v_client.id <> v_previous.client_id
    and not p_force_override
  then
    raise exception 'Cliente possui bloqueio para novos agendamentos'
      using errcode = 'P0001';
  end if;

  perform public.agenda_assert_slot_available(
    p_org_id,
    p_staff_id,
    p_start_at,
    p_end_at,
    array[p_appointment_id],
    p_force_override
  );

  if p_staff_id is not null then
    select coalesce(sm.display_name, sm.name)
      into v_staff_name
    from public.staff_members sm
    where sm.id = p_staff_id
      and sm.org_id = p_org_id;
  end if;

  if p_force_override then
    v_internal_notes := pg_catalog.concat_ws(
      E'\n',
      pg_catalog.format(
        '[CONFLITO FORCADO - %s - %s]',
        v_role,
        pg_catalog.to_char(pg_catalog.now(), 'YYYY-MM-DD HH24:MI')
      ),
      v_internal_notes
    );
  end if;

  update public.appointments
  set
    client_id = p_client_id,
    client_name = v_client.full_name,
    staff_id = p_staff_id,
    staff_name = coalesce(v_staff_name, ''),
    start_at = p_start_at,
    end_at = p_end_at,
    duration_minutes = p_duration_minutes,
    status = p_status,
    notes = nullif(pg_catalog.btrim(p_notes), ''),
    internal_notes = v_internal_notes,
    source = p_source,
    total = pg_catalog.round(p_total, 2)
  where id = p_appointment_id
    and org_id = p_org_id
  returning * into v_updated;

  delete from public.appointment_items ai
  where ai.org_id = p_org_id
    and ai.appointment_id = p_appointment_id;

  for v_item in
    select value
    from pg_catalog.jsonb_array_elements(coalesce(p_items, '[]'::jsonb))
  loop
    if nullif(pg_catalog.btrim(v_item ->> 'service_name'), '') is null then
      raise exception 'Servico invalido' using errcode = '22023';
    end if;

    if (v_item ->> 'price')::numeric < 0 then
      raise exception 'Preco de servico invalido' using errcode = '22003';
    end if;

    v_item_duration := nullif(v_item ->> 'duration_minutes', '')::integer;
    if v_item_duration is not null and (v_item_duration < 5 or v_item_duration > 720) then
      raise exception 'Duracao do item invalida' using errcode = '22023';
    end if;

    v_service_id := nullif(v_item ->> 'service_id', '')::uuid;
    v_professional_id := coalesce(
      nullif(v_item ->> 'professional_id', '')::uuid,
      p_staff_id
    );
    v_bundle_id := nullif(v_item ->> 'bundle_id', '')::uuid;
    v_bundle_item_id := nullif(v_item ->> 'bundle_item_id', '')::uuid;
    v_bundle_name := nullif(pg_catalog.btrim(coalesce(v_item ->> 'bundle_name', '')), '');
    v_bundle_item_position := nullif(v_item ->> 'bundle_item_position', '')::integer;
    v_bundle_allocated_price := nullif(v_item ->> 'bundle_allocated_price', '')::numeric;
    v_bundle_original_price_snapshot := nullif(v_item ->> 'bundle_original_price_snapshot', '')::numeric;

    if v_service_id is not null and not exists (
      select 1 from internal_read.services s
      where s.id = v_service_id and s.org_id = p_org_id
    ) then
      raise exception 'Servico nao pertence a esta organizacao'
        using errcode = '23503';
    end if;

    if v_professional_id is not null and not exists (
      select 1 from public.staff_members sm
      where sm.id = v_professional_id and sm.org_id = p_org_id
    ) then
      raise exception 'Profissional do servico invalido'
        using errcode = '23503';
    end if;

    if v_bundle_id is not null and not exists (
      select 1 from internal_read.service_bundles b
      where b.id = v_bundle_id and b.org_id = p_org_id
    ) then
      raise exception 'Bundle nao pertence a esta organizacao'
        using errcode = '23503';
    end if;

    insert into public.appointment_items (
      org_id, appointment_id, type, ref_id, name, price,
      cost_amount, qty, discount, commission_pct, professional_id,
      bundle_id, bundle_item_id, bundle_name, bundle_item_position,
      bundle_allocated_price, bundle_original_price_snapshot, duration_minutes
    )
    values (
      p_org_id, p_appointment_id, 'service', v_service_id,
      v_item ->> 'service_name', (v_item ->> 'price')::numeric,
      0, 1, 0, 0, v_professional_id,
      v_bundle_id, v_bundle_item_id, v_bundle_name, v_bundle_item_position,
      v_bundle_allocated_price, v_bundle_original_price_snapshot, v_item_duration
    );
  end loop;

  if v_previous.status <> v_updated.status then
    insert into public.appointment_status_history (
      org_id, appointment_id, status, changed_by, notes
    )
    values (
      p_org_id, p_appointment_id, v_updated.status, auth.uid(), 'appointment_updated'
    );
  end if;

  insert into public.audit_logs (
    org_id, user_id, table_name, operation, record_id, old_data, new_data
  )
  values (
    p_org_id,
    auth.uid(),
    'appointments',
    'APPOINTMENT_UPDATED',
    p_appointment_id,
    pg_catalog.jsonb_build_object(
      'client_id', v_previous.client_id,
      'staff_id', v_previous.staff_id,
      'start_at', v_previous.start_at,
      'end_at', v_previous.end_at,
      'status', v_previous.status
    ),
    pg_catalog.jsonb_build_object(
      'client_id', v_updated.client_id,
      'staff_id', v_updated.staff_id,
      'start_at', v_updated.start_at,
      'end_at', v_updated.end_at,
      'status', v_updated.status,
      'item_count', pg_catalog.jsonb_array_length(coalesce(p_items, '[]'::jsonb)),
      'force_override', p_force_override
    )
  );

  return p_appointment_id;
end;
$function$
;

-- ─── enforce_appointment_insert_integrity ───
CREATE OR REPLACE FUNCTION public.enforce_appointment_insert_integrity()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  if new.status not in ('Reservado', 'Agendado', 'Confirmado') then
    raise exception 'Status inicial de agendamento invalido'
      using errcode = '22023';
  end if;

  if new.end_at <= new.start_at then
    raise exception 'Horario final deve ser posterior ao inicial'
      using errcode = '22023';
  end if;

  if new.duration_minutes < 1 or new.duration_minutes > 1440 then
    raise exception 'Duracao invalida'
      using errcode = '22023';
  end if;

  if new.source not in ('MANUAL', 'WHATSAPP', 'ONLINE', 'PHONE') then
    raise exception 'Origem de agendamento invalida'
      using errcode = '22023';
  end if;

  if new.total < 0 or new.total > 1000000 then
    raise exception 'Total do agendamento invalido'
      using errcode = '22003';
  end if;

  if not exists (
    select 1
    from internal_read.clients c
    where c.id = new.client_id
      and c.org_id = new.org_id
  ) then
    raise exception 'Cliente nao pertence a esta organizacao'
      using errcode = '23503';
  end if;

  if new.staff_id is not null and not exists (
    select 1
    from public.staff_members sm
    where sm.id = new.staff_id
      and sm.org_id = new.org_id
      and sm.active = true
  ) then
    raise exception 'Profissional nao pertence a esta organizacao'
      using errcode = '23503';
  end if;

  return new;
end;
$function$
;

-- ─── list_service_bundles_catalog ───
CREATE OR REPLACE FUNCTION public.list_service_bundles_catalog(p_org_id uuid, p_active_only boolean DEFAULT false)
 RETURNS TABLE(id uuid, org_id uuid, category_id uuid, name text, description text, price numeric, active boolean, archived_at timestamp with time zone, "position" integer, created_at timestamp with time zone, updated_at timestamp with time zone, service_categories jsonb, service_bundle_items jsonb)
 LANGUAGE sql
 SET search_path TO ''
AS $function$
  select bundle.id,
         bundle.org_id,
         bundle.category_id,
         bundle.name,
         bundle.description,
         bundle.price,
         bundle.active,
         bundle.archived_at,
         bundle.position,
         bundle.created_at,
         bundle.updated_at,
         case when category.id is null then null else pg_catalog.jsonb_build_object(
           'id', category.id,
           'name', category.name,
           'color', category.color
         ) end as service_categories,
         coalesce(
           pg_catalog.jsonb_agg(
             pg_catalog.jsonb_build_object(
               'id', item.id,
               'org_id', item.org_id,
               'bundle_id', item.bundle_id,
               'service_id', item.service_id,
               'position', item.position,
               'quantity', item.quantity,
               'original_price_snapshot', item.original_price_snapshot,
               'allocated_price', item.allocated_price,
               'services', pg_catalog.jsonb_build_object(
                 'id', service.id,
                 'name', service.name,
                 'price', service.price,
                 'duration_minutes', service.duration_minutes
               )
             )
             order by item.position
           ) filter (where item.id is not null),
           '[]'::jsonb
         ) as service_bundle_items
  from internal_read.service_bundles bundle
  left join internal_read.service_categories category
    on category.id = bundle.category_id
   and category.org_id = bundle.org_id
  left join internal_read.service_bundle_items item
    on item.bundle_id = bundle.id
   and item.org_id = bundle.org_id
  left join internal_read.services service
    on service.id = item.service_id
   and service.org_id = item.org_id
  where bundle.org_id = p_org_id
    and bundle.org_id in (select public.auth_org_ids())
    and public.agenda_catalog_allowed(p_org_id)
    and (not p_active_only or (bundle.active and bundle.archived_at is null))
  -- Pela visão o Postgres não deduz as colunas pela chave primária: o agrupamento lista todas.
  group by bundle.id, bundle.org_id, bundle.category_id, bundle.name, bundle.description, bundle.price, bundle.active,
           bundle.archived_at, bundle.position, bundle.created_at, bundle.updated_at, category.id, category.name, category.color
  order by bundle.position, bundle.name;
$function$
;

