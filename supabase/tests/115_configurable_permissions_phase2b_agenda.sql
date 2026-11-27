-- Liberações configuráveis, fase 2b (spec 37): agenda. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000db1', 'dono3@teste.local'),
  ('00000000-0000-0000-0000-000000000db2', 'prof3@teste.local'),
  ('00000000-0000-0000-0000-000000000db3', 'recep3@teste.local'),
  ('00000000-0000-0000-0000-000000000db4', 'leitura3@teste.local'),
  ('00000000-0000-0000-0000-000000000db5', 'fora3@teste.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-000000000dba', 'perm3-a', 'Estúdio A'),
  ('00000000-0000-0000-0000-000000000dbb', 'perm3-b', 'Estúdio B');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000000db1', '00000000-0000-0000-0000-000000000dba', 'owner'),
  ('00000000-0000-0000-0000-000000000db2', '00000000-0000-0000-0000-000000000dba', 'professional'),
  ('00000000-0000-0000-0000-000000000db3', '00000000-0000-0000-0000-000000000dba', 'receptionist'),
  ('00000000-0000-0000-0000-000000000db4', '00000000-0000-0000-0000-000000000dba', 'viewer'),
  ('00000000-0000-0000-0000-000000000db5', '00000000-0000-0000-0000-000000000dbb', 'owner');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-000000000dbc', '00000000-0000-0000-0000-000000000dba', 'Lucía Prado');
insert into public.services (id, org_id, name, price, duration_minutes) values
  ('00000000-0000-0000-0000-000000000dbd', '00000000-0000-0000-0000-000000000dba', 'Limpeza', 30, 60);
-- Cada estúdio nasce com tipos de bloqueio; guarda um de cada para os testes.
create temp table t_types on commit drop as
  select distinct on (org_id) org_id, id from public.time_block_types
  where org_id in ('00000000-0000-0000-0000-000000000dba', '00000000-0000-0000-0000-000000000dbb')
  order by org_id, name;
grant select on t_types to authenticated;

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
-- Agendamento pela RPC (o caminho do app); n desloca o dia para não conflitar.
create function pg_temp.mk_sql(p_n int) returns text language sql as $$
  select format($q$select public.create_appointment_atomic('00000000-0000-0000-0000-000000000dba', '00000000-0000-0000-0000-000000000dbc', null,
    %L::timestamptz, %L::timestamptz, 60, 'Agendado', 'MANUAL', null, null, 30,
    '[{"service_id":"00000000-0000-0000-0000-000000000dbd","service_name":"Limpeza","price":30}]'::jsonb, false)$q$,
    '2033-02-01 09:00+00'::timestamptz + make_interval(days => p_n), '2033-02-01 10:00+00'::timestamptz + make_interval(days => p_n))
$$;
create function pg_temp.block_sql(p_org uuid, p_n int) returns text language sql as $$
  select format($q$insert into public.time_blocks (org_id, time_block_type_id, start_at, end_at)
    values (%L, %L, %L::timestamptz, %L::timestamptz)$q$,
    p_org, (select id from t_types where org_id = p_org), '2033-03-01 13:00+00'::timestamptz + make_interval(days => p_n), '2033-03-01 14:00+00'::timestamptz + make_interval(days => p_n))
$$;
select pg_temp.expect((select count(*) = 2 from t_types), 'os dois estúdios têm tipo de bloqueio');
grant execute on function pg_temp.expect(boolean, text), pg_temp.state_of(text), pg_temp.login(uuid),
  pg_temp.mk_sql(int), pg_temp.block_sql(uuid, int) to authenticated;

-- Padrão: recepção agenda; profissional e leitura não; profissional bloqueia horário.
select pg_temp.login('00000000-0000-0000-0000-000000000db3');
do $$ begin
  perform pg_temp.expect(pg_temp.state_of(pg_temp.mk_sql(1)) = 'ok', 'recepção cria agendamento');
end $$;

select pg_temp.login('00000000-0000-0000-0000-000000000db2');
do $$ begin
  perform pg_temp.expect(pg_temp.state_of(pg_temp.mk_sql(2)) = '42501', 'profissional não cria agendamento por padrão');
  perform pg_temp.expect(pg_temp.state_of($q$update public.appointments set notes = 'x' where org_id = '00000000-0000-0000-0000-000000000dba'$q$) = 'ok', 'update da profissional não falha');
  perform pg_temp.expect(pg_temp.state_of(pg_temp.block_sql('00000000-0000-0000-0000-000000000dba', 1)) = 'ok', 'profissional bloqueia horário por padrão');
end $$;
reset role;
select pg_temp.expect((select count(*) from public.appointments where org_id = '00000000-0000-0000-0000-000000000dba' and notes = 'x') = 0,
  'profissional sem liberação não altera agendamento');

select pg_temp.login('00000000-0000-0000-0000-000000000db4');
do $$ begin
  perform pg_temp.expect(pg_temp.state_of($q$insert into public.appointments (org_id, client_id, client_name, start_at, end_at, duration_minutes, status)
    values ('00000000-0000-0000-0000-000000000dba', '00000000-0000-0000-0000-000000000dbc', 'Lucía Prado', '2033-04-01 09:00+00', '2033-04-01 10:00+00', 60, 'Agendado')$q$) = '42501',
    'somente leitura não insere agendamento direto pela API');
  perform pg_temp.expect(pg_temp.state_of(pg_temp.block_sql('00000000-0000-0000-0000-000000000dba', 2)) = '42501', 'somente leitura não bloqueia horário');
end $$;

-- Dona libera a agenda para a profissional e tira o bloqueio de horário.
select pg_temp.login('00000000-0000-0000-0000-000000000db1');
select public.set_role_permission('00000000-0000-0000-0000-000000000dba', 'professional', 'agenda.manage', true);
select public.set_role_permission('00000000-0000-0000-0000-000000000dba', 'professional', 'agenda.block_time', false);

select pg_temp.login('00000000-0000-0000-0000-000000000db2');
do $$
declare v_id uuid;
begin
  perform pg_temp.expect(pg_temp.state_of(pg_temp.mk_sql(3)) = 'ok', 'profissional com liberação cria agendamento');
  select id into v_id from public.appointments where org_id = '00000000-0000-0000-0000-000000000dba' order by start_at desc limit 1;
  perform pg_temp.expect(pg_temp.state_of(format($q$select public.set_appointment_status_atomic('00000000-0000-0000-0000-000000000dba', %L, 'Confirmado')$q$, v_id)) = 'ok',
    'profissional com liberação confirma agendamento');
  perform pg_temp.expect(pg_temp.state_of(pg_temp.block_sql('00000000-0000-0000-0000-000000000dba', 3)) = '42501', 'profissional sem a liberação de bloqueio é barrada');
end $$;

-- Forçar encaixe (agenda.override_conflict): recepção não força por padrão; a dona libera.
select pg_temp.login('00000000-0000-0000-0000-000000000db3');
do $$ begin
  perform pg_temp.expect(pg_temp.state_of(replace(pg_temp.mk_sql(5), 'false)', 'true)')) = '42501', 'recepção não força encaixe por padrão');
end $$;
select pg_temp.login('00000000-0000-0000-0000-000000000db1');
select public.set_role_permission('00000000-0000-0000-0000-000000000dba', 'receptionist', 'agenda.override_conflict', true);
select pg_temp.login('00000000-0000-0000-0000-000000000db3');
do $$ begin
  perform pg_temp.expect(pg_temp.state_of(replace(pg_temp.mk_sql(6), 'false)', 'true)')) = 'ok', 'recepção com liberação força encaixe');
end $$;
select pg_temp.login('00000000-0000-0000-0000-000000000db2');

-- Liberação não vaza para outro estúdio.
do $$ begin
  perform pg_temp.expect(pg_temp.state_of(pg_temp.block_sql('00000000-0000-0000-0000-000000000dbb', 4)) = '42501', 'nada vale em outro estúdio');
end $$;

reset role;
rollback;
\o
\echo 'liberações fase 2b (agenda): ok'
