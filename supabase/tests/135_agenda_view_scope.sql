-- Agenda: agenda.view_all x agenda.view_own valem no banco (20261030200000). Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000001270', 'dona@escopo.local'),
  ('00000000-0000-0000-0000-000000001271', 'profa@escopo.local'),
  ('00000000-0000-0000-0000-000000001272', 'profb@escopo.local'),
  ('00000000-0000-0000-0000-000000001273', 'recep@escopo.local'),
  ('00000000-0000-0000-0000-000000001274', 'solta@escopo.local'),
  ('00000000-0000-0000-0000-000000001275', 'financeiro@escopo.local'),
  ('00000000-0000-0000-0000-000000001276', 'outra@escopo.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-00000000127a', 'escopo-a', 'Escopo A'),
  ('00000000-0000-0000-0000-00000000127b', 'escopo-b', 'Escopo B');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000001270', '00000000-0000-0000-0000-00000000127a', 'owner'),
  ('00000000-0000-0000-0000-000000001271', '00000000-0000-0000-0000-00000000127a', 'professional'),
  ('00000000-0000-0000-0000-000000001272', '00000000-0000-0000-0000-00000000127a', 'professional'),
  ('00000000-0000-0000-0000-000000001273', '00000000-0000-0000-0000-00000000127a', 'receptionist'),
  ('00000000-0000-0000-0000-000000001274', '00000000-0000-0000-0000-00000000127a', 'professional'),
  ('00000000-0000-0000-0000-000000001275', '00000000-0000-0000-0000-00000000127a', 'finance'),
  ('00000000-0000-0000-0000-000000001276', '00000000-0000-0000-0000-00000000127b', 'owner');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-000000001278', '00000000-0000-0000-0000-00000000127a', 'Cliente Escopo');
-- A profissional A é ligada à conta 1271, a B à 1272, a C ainda não tem conta.
insert into public.staff_members (id, org_id, name, user_id) values
  ('00000000-0000-0000-0000-0000000012a1', '00000000-0000-0000-0000-00000000127a', 'Profissional A', '00000000-0000-0000-0000-000000001271'),
  ('00000000-0000-0000-0000-0000000012a2', '00000000-0000-0000-0000-00000000127a', 'Profissional B', '00000000-0000-0000-0000-000000001272'),
  ('00000000-0000-0000-0000-0000000012a3', '00000000-0000-0000-0000-00000000127a', 'Profissional C', null);
insert into public.services (id, org_id, name, price, duration_minutes) values
  ('00000000-0000-0000-0000-000000001279', '00000000-0000-0000-0000-00000000127a', 'Limpeza', 60, 60);
create temp table t_types on commit drop as
  select id from public.time_block_types where org_id = '00000000-0000-0000-0000-00000000127a' order by name limit 1;
grant select on t_types to authenticated;

create function pg_temp.expect(p_ok boolean, p_msg text) returns void language plpgsql as $$
begin
  if not coalesce(p_ok, false) then raise exception 'FALHOU: %', p_msg; end if;
end $$;
create function pg_temp.login(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;
create function pg_temp.mk(p_start text, p_staff uuid) returns uuid language sql as $$
  select public.create_appointment_atomic('00000000-0000-0000-0000-00000000127a', '00000000-0000-0000-0000-000000001278', p_staff,
    p_start::timestamptz, p_start::timestamptz + interval '60 minutes', 60, 'Agendado', 'MANUAL', null, null, 60,
    '[{"service_id":"00000000-0000-0000-0000-000000001279","service_name":"Limpeza","price":60}]'::jsonb, false)
$$;
-- Quantas linhas a pessoa logada enxerga em cada tabela da agenda.
create function pg_temp.seen(p_what text) returns bigint language plpgsql as $$
declare v bigint;
begin
  execute format('select count(*) from public.%I where org_id = %L', p_what, '00000000-0000-0000-0000-00000000127a') into v;
  return v;
end $$;
create temp table t_ids (k text primary key, id uuid) on commit drop;
grant all on t_ids to authenticated;
grant execute on function pg_temp.expect(boolean, text), pg_temp.login(uuid), pg_temp.mk(text, uuid), pg_temp.seen(text) to authenticated;

-- Três agendamentos (A, B e sem profissional), um sinal na A, e três bloqueios (A, B e estúdio inteiro).
select pg_temp.login('00000000-0000-0000-0000-000000001270');
insert into t_ids values
  ('a', pg_temp.mk('2034-05-02 09:00+00', '00000000-0000-0000-0000-0000000012a1')),
  ('b', pg_temp.mk('2034-05-02 11:00+00', '00000000-0000-0000-0000-0000000012a2')),
  ('n', pg_temp.mk('2034-05-02 13:00+00', null));
select public.register_appointment_deposit_atomic('00000000-0000-0000-0000-00000000127a', (select id from t_ids where k = 'a'),
  20, 'CASH', '00000000-0000-0000-0000-0000000012c1');
select public.register_appointment_deposit_atomic('00000000-0000-0000-0000-00000000127a', (select id from t_ids where k = 'b'),
  25, 'CASH', '00000000-0000-0000-0000-0000000012c2');
insert into public.time_blocks (org_id, staff_id, time_block_type_id, start_at, end_at)
select '00000000-0000-0000-0000-00000000127a', s, (select id from t_types), '2034-05-02 15:00+00', '2034-05-02 16:00+00'
from (values ('00000000-0000-0000-0000-0000000012a1'::uuid), ('00000000-0000-0000-0000-0000000012a2'::uuid), (null::uuid)) v(s);
reset role;
select set_config('request.jwt.claims', '', true);

select pg_temp.expect((select count(*) = 3 from public.appointments where org_id = '00000000-0000-0000-0000-00000000127a'), 'três agendamentos criados');
select pg_temp.expect((select count(*) = 3 from public.time_blocks where org_id = '00000000-0000-0000-0000-00000000127a'), 'três bloqueios criados');

-- ═══ A. Quem vê tudo ═══
-- Dona, recepção (view_all) e financeiro (financeiro.view) leem a agenda inteira.
select pg_temp.login('00000000-0000-0000-0000-000000001270');
select pg_temp.expect(pg_temp.seen('appointments') = 3 and pg_temp.seen('time_blocks') = 3, 'dona vê tudo');
select pg_temp.login('00000000-0000-0000-0000-000000001273');
select pg_temp.expect(pg_temp.seen('appointments') = 3 and pg_temp.seen('appointment_items') = 3
  and pg_temp.seen('appointment_deposits') = 2 and pg_temp.seen('time_blocks') = 3, 'recepção vê tudo, com itens e sinais');
select pg_temp.login('00000000-0000-0000-0000-000000001275');
select pg_temp.expect(pg_temp.seen('appointments') = 3, 'financeiro vê os agendamentos que a comanda e os relatórios usam');

-- ═══ B. Só agenda.view_own ═══
select pg_temp.login('00000000-0000-0000-0000-000000001271');
select pg_temp.expect(pg_temp.seen('appointments') = 1, 'profissional A vê só o próprio agendamento');
select pg_temp.expect((select staff_id = '00000000-0000-0000-0000-0000000012a1' from public.appointments where org_id = '00000000-0000-0000-0000-00000000127a'),
  'e é o dela');
select pg_temp.expect(pg_temp.seen('appointment_items') = 1, 'itens: só os do agendamento dela');
select pg_temp.expect(pg_temp.seen('appointment_deposits') = 1, 'sinais: só o do agendamento dela');
select pg_temp.expect(pg_temp.seen('appointment_status_history') = 1, 'histórico: só o do agendamento dela');
select pg_temp.expect(pg_temp.seen('time_blocks') = 2, 'bloqueios: o dela e o do estúdio inteiro, não o da colega');
select pg_temp.expect(not exists (select 1 from public.time_blocks where staff_id = '00000000-0000-0000-0000-0000000012a2'), 'bloqueio da colega fica fora');
select pg_temp.expect((select count(*) = 0 from public.appointments where id = (select id from t_ids where k = 'b')), 'agendamento da colega some até por id');
select pg_temp.expect((select count(*) = 0 from public.appointments where id = (select id from t_ids where k = 'n')), 'agendamento sem profissional não aparece para quem só vê o próprio');

select pg_temp.login('00000000-0000-0000-0000-000000001272');
select pg_temp.expect(pg_temp.seen('appointments') = 1 and (select staff_id = '00000000-0000-0000-0000-0000000012a2' from public.appointments where org_id = '00000000-0000-0000-0000-00000000127a'),
  'profissional B vê só o dela');

-- Profissional ainda sem conta ligada (conta 1274 não está em nenhuma profissional): não vê nada.
select pg_temp.login('00000000-0000-0000-0000-000000001274');
select pg_temp.expect(pg_temp.seen('appointments') = 0 and pg_temp.seen('appointment_items') = 0 and pg_temp.seen('appointment_deposits') = 0, 'sem ligação com profissional, nada de agendamento');
select pg_temp.expect(pg_temp.seen('time_blocks') = 1, 'sem ligação, só o bloqueio do estúdio inteiro');

-- ═══ C. Mudar a liberação muda o que vê ═══
select pg_temp.login('00000000-0000-0000-0000-000000001270');
select public.set_role_permission('00000000-0000-0000-0000-00000000127a', 'professional', 'agenda.view_all', true);
select pg_temp.login('00000000-0000-0000-0000-000000001271');
select pg_temp.expect(pg_temp.seen('appointments') = 3 and pg_temp.seen('time_blocks') = 3, 'com agenda.view_all a profissional vê a agenda inteira');
select pg_temp.login('00000000-0000-0000-0000-000000001270');
select public.set_role_permission('00000000-0000-0000-0000-00000000127a', 'professional', 'agenda.view_all', false);
select public.set_role_permission('00000000-0000-0000-0000-00000000127a', 'professional', 'agenda.view_own', false);
select pg_temp.login('00000000-0000-0000-0000-000000001271');
select pg_temp.expect(pg_temp.seen('appointments') = 0 and pg_temp.seen('appointment_items') = 0 and pg_temp.seen('time_blocks') = 0
  and pg_temp.seen('appointment_status_history') = 0, 'sem view_all nem view_own, a agenda não abre');
select pg_temp.login('00000000-0000-0000-0000-000000001270');
select public.set_role_permission('00000000-0000-0000-0000-00000000127a', 'professional', 'agenda.view_own', true);
select pg_temp.login('00000000-0000-0000-0000-000000001271');
select pg_temp.expect(pg_temp.seen('appointments') = 1, 'devolvendo view_own, volta a ver só o dela');

-- ═══ D. Isolamento entre estúdios ═══
select pg_temp.login('00000000-0000-0000-0000-000000001276');
select pg_temp.expect(pg_temp.seen('appointments') = 0 and pg_temp.seen('time_blocks') = 0, 'dona de outro estúdio não vê esta agenda');

-- ═══ E. Função de apoio: só as profissionais da própria pessoa ═══
select pg_temp.login('00000000-0000-0000-0000-000000001271');
select pg_temp.expect((select count(*) = 1 and bool_and(t.id = '00000000-0000-0000-0000-0000000012a1'::uuid) from public.agenda_my_staff_ids() as t(id)), 'agenda_my_staff_ids devolve só a profissional da conta');
select pg_temp.login('00000000-0000-0000-0000-000000001274');
select pg_temp.expect((select count(*) = 0 from public.agenda_my_staff_ids() as t(id)), 'conta sem profissional ligada não tem ids');

reset role;
rollback;
\o
\echo 'agenda: ver tudo x ver só a minha: ok'
