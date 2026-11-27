-- O1: my_access_context (slug ou id, com casco), client_list_summary e client_list_rows.
-- Isolamento: quem é do estúdio B não recebe nada do A por nenhuma das três. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000f10', 'dona@o1.local'),
  ('00000000-0000-0000-0000-000000000f11', 'recep@o1.local'),
  ('00000000-0000-0000-0000-000000000f12', 'donab@o1.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-000000000f1a', 'o1-a', 'Estúdio O1 A'),
  ('00000000-0000-0000-0000-000000000f1b', 'o1-b', 'Estúdio O1 B');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000000f10', '00000000-0000-0000-0000-000000000f1a', 'owner'),
  ('00000000-0000-0000-0000-000000000f11', '00000000-0000-0000-0000-000000000f1a', 'receptionist'),
  ('00000000-0000-0000-0000-000000000f12', '00000000-0000-0000-0000-000000000f1b', 'owner');
insert into public.profiles (user_id, org_id, full_name) values
  ('00000000-0000-0000-0000-000000000f10', '00000000-0000-0000-0000-000000000f1a', 'Dona Ana'),
  ('00000000-0000-0000-0000-000000000f11', '00000000-0000-0000-0000-000000000f1a', 'Recepção Rita')
on conflict (user_id, org_id) do update set full_name = excluded.full_name;
insert into public.user_preferences (user_id, org_id, prefs) values
  ('00000000-0000-0000-0000-000000000f10', '00000000-0000-0000-0000-000000000f1a', '{"mobile":{"startPage":"clientes"}}'),
  ('00000000-0000-0000-0000-000000000f11', '00000000-0000-0000-0000-000000000f1a', '{"mobile":{"startPage":"agenda"}}');

insert into public.clients (id, org_id, full_name, status, tags, balance, last_visit, birth_date) values
  ('00000000-0000-0000-0000-000000000fc1', '00000000-0000-0000-0000-000000000f1a', 'VIP Ativa', 'Ativo', '{VIP}', 10, '2020-01-01', '1990-03-04'),
  ('00000000-0000-0000-0000-000000000fc2', '00000000-0000-0000-0000-000000000f1a', 'Retoque', 'Ativo', '{"Retoque pendente"}', 0, current_date, null),
  ('00000000-0000-0000-0000-000000000fc3', '00000000-0000-0000-0000-000000000f1a', 'Arquivada', 'Inativo', '{VIP}', 5, null, '1991-05-06'),
  ('00000000-0000-0000-0000-000000000fc9', '00000000-0000-0000-0000-000000000f1b', 'Cliente B', 'Ativo', '{VIP}', 3, null, '1992-07-08');
insert into public.client_entitlements (org_id, client_id, package_name, total_sessions, used_sessions, status) values
  ('00000000-0000-0000-0000-000000000f1a', '00000000-0000-0000-0000-000000000fc1', 'Pacote A', 4, 1, 'active'),
  ('00000000-0000-0000-0000-000000000f1a', '00000000-0000-0000-0000-000000000fc3', 'Pacote arquivada', 4, 1, 'active'),
  ('00000000-0000-0000-0000-000000000f1b', '00000000-0000-0000-0000-000000000fc9', 'Pacote B', 4, 1, 'active');
insert into public.appointments (id, org_id, client_id, client_name, start_at, end_at, duration_minutes, status) values
  ('00000000-0000-0000-0000-000000000fa1', '00000000-0000-0000-0000-000000000f1a', '00000000-0000-0000-0000-000000000fc1',
   'VIP Ativa', '2031-05-06 10:30+00', '2031-05-06 11:30+00', 60, 'Agendado'),
  ('00000000-0000-0000-0000-000000000fa2', '00000000-0000-0000-0000-000000000f1a', '00000000-0000-0000-0000-000000000fc1',
   'VIP Ativa', '2030-05-06 10:30+00', '2030-05-06 11:30+00', 60, 'Agendado'),
  ('00000000-0000-0000-0000-000000000fa9', '00000000-0000-0000-0000-000000000f1b', '00000000-0000-0000-0000-000000000fc9',
   'Cliente B', '2031-05-06 10:30+00', '2031-05-06 11:30+00', 60, 'Agendado');
-- Atendimento pago no passado e serviços: pula os gatilhos (agenda e anamnese) só para montar o cenário; desfeito no rollback.
set local session_replication_role = replica;
update public.appointments set status = 'Pago', start_at = '2020-05-06 10:30+00', end_at = '2020-05-06 11:30+00'
where id = '00000000-0000-0000-0000-000000000fa2';
insert into public.appointment_items (org_id, appointment_id, type, name, price, qty) values
  ('00000000-0000-0000-0000-000000000f1a', '00000000-0000-0000-0000-000000000fa1', 'service', 'Sobrancelha', 50, 1),
  ('00000000-0000-0000-0000-000000000f1a', '00000000-0000-0000-0000-000000000fa2', 'service', 'Lábios', 120, 1),
  ('00000000-0000-0000-0000-000000000f1b', '00000000-0000-0000-0000-000000000fa9', 'service', 'Serviço B', 80, 1);
set local session_replication_role = origin;

create function pg_temp.expect(p_ok boolean, p_msg text) returns void language plpgsql as $$
begin
  if not coalesce(p_ok, false) then raise exception 'FALHOU: %', p_msg; end if;
end $$;
create function pg_temp.state_of(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return sqlstate;
end $$;
create function pg_temp.login(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;
create function pg_temp.summary(p_org uuid, p_month int default 3) returns jsonb language sql as $$
  select public.client_list_summary(p_org, 'VIP', 'Retoque pendente', '2026-01-01'::date, p_month)
$$;
create function pg_temp.rows_of(p_org uuid) returns jsonb language sql as $$
  select public.client_list_rows(p_org,
    array['00000000-0000-0000-0000-000000000fc1', '00000000-0000-0000-0000-000000000fc9']::uuid[],
    '2026-11-13 12:00+00', array['Reservado','Agendado','Confirmado','Chegou'], array['Concluído','Pago'])
$$;
grant execute on function pg_temp.expect(boolean, text), pg_temp.state_of(text), pg_temp.login(uuid),
  pg_temp.summary(uuid, int), pg_temp.rows_of(uuid) to anon, authenticated;

-- ─── my_access_context ───────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000000f10');
select pg_temp.expect((select public.my_access_context('o1-a') ->> 'role') = 'owner', 'por slug: papel owner');
select pg_temp.expect((select public.my_access_context(null, '00000000-0000-0000-0000-000000000f1a') -> 'org' ->> 'slug') = 'o1-a', 'por id: estúdio certo');
select pg_temp.expect((select public.my_access_context('o1-a') = public.my_org_access('o1-a')), 'sem casco: igual a my_org_access');
select pg_temp.expect((select public.my_access_context('o1-a') ? 'prefs') = false, 'sem casco: não traz preferências');
select pg_temp.expect((select public.my_access_context('o1-a', null, true) ->> 'display_name') = 'Dona Ana', 'casco: nome da própria pessoa');
select pg_temp.expect((select public.my_access_context('o1-a', null, true) -> 'prefs' -> 'mobile' ->> 'startPage') = 'clientes', 'casco: preferências da própria pessoa');
select pg_temp.expect(public.my_access_context('o1-b') is null, 'estúdio de outra pessoa (slug) vira nulo');
select pg_temp.expect(public.my_access_context(null, '00000000-0000-0000-0000-000000000f1b', true) is null, 'estúdio de outra pessoa (id) vira nulo');
select pg_temp.expect(public.my_access_context('o1-a', '00000000-0000-0000-0000-000000000f1b') is null, 'slug e id de estúdios diferentes viram nulo');
select pg_temp.expect(public.my_access_context(null, null) is null, 'sem slug nem id vira nulo');

select pg_temp.login('00000000-0000-0000-0000-000000000f11');
select pg_temp.expect((select public.my_access_context(null, '00000000-0000-0000-0000-000000000f1a', true) ->> 'display_name') = 'Recepção Rita', 'recepção recebe o próprio nome');
select pg_temp.expect((select public.my_access_context('o1-a', null, true) -> 'prefs' -> 'mobile' ->> 'startPage') = 'agenda', 'recepção recebe as próprias preferências');
select pg_temp.expect(not ((select public.my_access_context('o1-a') -> 'permissions') @> '"ajustes.manage"'::jsonb), 'recepção não tem ajustes.manage');
select pg_temp.expect((select public.my_access_context(null, '00000000-0000-0000-0000-000000000f1a') = public.my_org_access('o1-a')), 'recepção: pelo id igual a my_org_access');
select pg_temp.expect((select public.my_access_context('o1-a') = public.my_org_access('o1-a')), 'recepção: pelo slug igual a my_org_access');

-- papel desativado e estúdio desativado: nulo (como my_org_access)
reset role;
select set_config('request.jwt.claims', '', true);
update public.user_roles set active = false
where user_id = '00000000-0000-0000-0000-000000000f11' and org_id = '00000000-0000-0000-0000-000000000f1a';
select pg_temp.login('00000000-0000-0000-0000-000000000f11');
select pg_temp.expect(public.my_access_context('o1-a') is null, 'papel inativo (slug) vira nulo');
select pg_temp.expect(public.my_access_context(null, '00000000-0000-0000-0000-000000000f1a', true) is null, 'papel inativo (id) vira nulo');
reset role;
select set_config('request.jwt.claims', '', true);
update public.user_roles set active = true
where user_id = '00000000-0000-0000-0000-000000000f11' and org_id = '00000000-0000-0000-0000-000000000f1a';
update public.organizations set active = false where id = '00000000-0000-0000-0000-000000000f1b';
select pg_temp.login('00000000-0000-0000-0000-000000000f12');
select pg_temp.expect(public.my_access_context('o1-b') is null, 'estúdio inativo (slug) vira nulo');
select pg_temp.expect(public.my_access_context(null, '00000000-0000-0000-0000-000000000f1b') is null, 'estúdio inativo (id) vira nulo');
reset role;
select set_config('request.jwt.claims', '', true);
update public.organizations set active = true where id = '00000000-0000-0000-0000-000000000f1b';

-- ─── client_list_summary ─────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000000f10');
select pg_temp.expect((pg_temp.summary('00000000-0000-0000-0000-000000000f1a') ->> 'todos')::int = 2, 'todos: só as ativas');
select pg_temp.expect((pg_temp.summary('00000000-0000-0000-0000-000000000f1a') ->> 'vip')::int = 1, 'vip: ativa com etiqueta');
select pg_temp.expect((pg_temp.summary('00000000-0000-0000-0000-000000000f1a') ->> 'saldo')::int = 1, 'saldo: ativa com saldo');
select pg_temp.expect((pg_temp.summary('00000000-0000-0000-0000-000000000f1a') ->> 'sem_visita')::int = 1, 'sem visita: antes do corte');
select pg_temp.expect((pg_temp.summary('00000000-0000-0000-0000-000000000f1a') -> 'retouch_tagged') = '["00000000-0000-0000-0000-000000000fc2"]'::jsonb, 'retoque por etiqueta');
select pg_temp.expect(pg_catalog.jsonb_array_length(pg_temp.summary('00000000-0000-0000-0000-000000000f1a') -> 'birthdays') = 1, 'aniversário: ativa com data no mês');
select pg_temp.expect(pg_catalog.jsonb_array_length(pg_temp.summary('00000000-0000-0000-0000-000000000f1a', 5) -> 'birthdays') = 0, 'aniversário: arquivada do mês não entra');
select pg_temp.expect(pg_catalog.jsonb_array_length(pg_temp.summary('00000000-0000-0000-0000-000000000f1a', 7) -> 'birthdays') = 0, 'aniversário: outro mês não entra');
select pg_temp.expect(pg_catalog.jsonb_array_length(pg_temp.summary('00000000-0000-0000-0000-000000000f1a') -> 'credits') = 2, 'créditos ativos do estúdio');
select pg_temp.expect((select count(*) from pg_catalog.jsonb_array_elements(pg_temp.summary('00000000-0000-0000-0000-000000000f1a') -> 'credits') c
  where (c ->> 'client_active')::boolean) = 1, 'crédito marca se a cliente está ativa');

select pg_temp.login('00000000-0000-0000-0000-000000000f12');
select pg_temp.expect((pg_temp.summary('00000000-0000-0000-0000-000000000f1a') ->> 'todos')::int = 0, 'dona B não conta clientes do A');
select pg_temp.expect(pg_catalog.jsonb_array_length(pg_temp.summary('00000000-0000-0000-0000-000000000f1a') -> 'credits') = 0, 'dona B não vê créditos do A');
select pg_temp.expect(pg_catalog.jsonb_array_length(pg_temp.summary('00000000-0000-0000-0000-000000000f1a') -> 'birthdays') = 0, 'dona B não vê aniversários do A');

-- ─── client_list_rows ────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000000f10');
select pg_temp.expect(pg_catalog.jsonb_array_length(pg_temp.rows_of('00000000-0000-0000-0000-000000000f1a') -> 'upcoming') = 1, 'próximo atendimento');
select pg_temp.expect((pg_temp.rows_of('00000000-0000-0000-0000-000000000f1a') -> 'upcoming' -> 0 -> 'appointment_items' -> 0 ->> 'name') = 'Sobrancelha', 'serviços do próximo');
select pg_temp.expect((pg_temp.rows_of('00000000-0000-0000-0000-000000000f1a') -> 'past' -> 0 -> 'appointment_items' -> 0 ->> 'name') = 'Lábios', 'serviços do último');
select pg_temp.expect(pg_catalog.jsonb_array_length(pg_temp.rows_of('00000000-0000-0000-0000-000000000f1a') -> 'credits') = 1, 'créditos das clientes da página');
select pg_temp.expect((select count(*) from pg_catalog.jsonb_array_elements(pg_temp.rows_of('00000000-0000-0000-0000-000000000f1a') -> 'upcoming') u
  where u ->> 'client_id' = '00000000-0000-0000-0000-000000000fc9') = 0, 'id do B pedido junto não aparece');
select pg_temp.expect(pg_catalog.jsonb_array_length(pg_temp.rows_of('00000000-0000-0000-0000-000000000f1b') -> 'upcoming') = 0, 'dona A não vê agenda do B');

select pg_temp.login('00000000-0000-0000-0000-000000000f12');
select pg_temp.expect(pg_catalog.jsonb_array_length(pg_temp.rows_of('00000000-0000-0000-0000-000000000f1a') -> 'upcoming') = 0, 'dona B não vê atendimentos do A');
select pg_temp.expect(pg_catalog.jsonb_array_length(pg_temp.rows_of('00000000-0000-0000-0000-000000000f1a') -> 'credits') = 0, 'dona B não vê créditos do A');

-- ─── sem login ───────────────────────────────────────────────
reset role;
select pg_temp.expect(not has_function_privilege('anon', 'public.my_access_context(text, uuid, boolean)', 'execute'), 'anon sem execute em my_access_context');
select pg_temp.expect(not has_function_privilege('anon', 'public.client_list_summary(uuid, text, text, date, integer)', 'execute'), 'anon sem execute em client_list_summary');
select pg_temp.expect(not has_function_privilege('anon', 'public.client_list_rows(uuid, uuid[], timestamptz, text[], text[])', 'execute'), 'anon sem execute em client_list_rows');
select pg_temp.expect(not has_function_privilege('public', 'public.my_access_context(text, uuid, boolean)', 'execute'), 'public sem execute em my_access_context');
select set_config('request.jwt.claims', '', true);
select set_config('role', 'anon', true);
select pg_temp.expect(pg_temp.state_of($q$select public.my_access_context('o1-a')$q$) = '42501', 'anônimo não executa my_access_context');
select pg_temp.expect(pg_temp.state_of($q$select pg_temp.summary('00000000-0000-0000-0000-000000000f1a')$q$) = '42501', 'anônimo não executa client_list_summary');
select pg_temp.expect(pg_temp.state_of($q$select pg_temp.rows_of('00000000-0000-0000-0000-000000000f1a')$q$) = '42501', 'anônimo não executa client_list_rows');

rollback;
\o
\echo 'acesso e listas de clientes (O1): ok'
