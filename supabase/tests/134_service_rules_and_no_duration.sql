-- Catálogo (20261030301000): regras por serviço e serviço sem duração. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000b801', 'dona@teste.local'),
  ('00000000-0000-0000-0000-00000000b802', 'recepcao@teste.local'),
  ('00000000-0000-0000-0000-00000000b803', 'outra@teste.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-00000000b80a', 'regras-a', 'Estúdio A'),
  ('00000000-0000-0000-0000-00000000b80b', 'regras-b', 'Estúdio B');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-00000000b801', '00000000-0000-0000-0000-00000000b80a', 'owner'),
  ('00000000-0000-0000-0000-00000000b802', '00000000-0000-0000-0000-00000000b80a', 'receptionist'),
  ('00000000-0000-0000-0000-00000000b803', '00000000-0000-0000-0000-00000000b80b', 'owner');

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
grant execute on function pg_temp.expect(boolean, text), pg_temp.state_of(text), pg_temp.login(uuid) to authenticated;

create temp table t_ids (k text primary key, id uuid);
grant all on t_ids to authenticated;

-- 1. A dona grava com regras.
select pg_temp.login('00000000-0000-0000-0000-00000000b801');
insert into t_ids select 'shadow', public.upsert_catalog_service_atomic(
  '00000000-0000-0000-0000-00000000b80a', null, null, 'Shadow', null, 250, 'fixed', 120, 0, 0, false, null, true, true, '{}'::uuid[],
  '{"result_months": 18, "retouch_included_days": 60, "deposit_type": "fixed", "deposit_value": 30}'::jsonb);
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select result_months = 18 and retouch_included_days = 60 and deposit_type = 'fixed' and deposit_value = 30 and online_booking
  from public.services where id = (select id from t_ids where k = 'shadow')), 'regras gravadas');

-- 2. Edição sem p_rules (app anterior, 15 parâmetros) não apaga as regras.
select pg_temp.login('00000000-0000-0000-0000-00000000b801');
select public.upsert_catalog_service_atomic(
  '00000000-0000-0000-0000-00000000b80a', (select id from t_ids where k = 'shadow'), null, 'Shadow 3D', null, 260, 'fixed', 120, 0, 0, false, null, true, true, '{}'::uuid[]);
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select name = 'Shadow 3D' and price = 260 and result_months = 18 and retouch_included_days = 60 and deposit_type = 'fixed'
  from public.services where id = (select id from t_ids where k = 'shadow')), 'chamada antiga mantém as regras');

-- 3. Regras vazias limpam; sinal em porcentagem.
select pg_temp.login('00000000-0000-0000-0000-00000000b801');
select public.upsert_catalog_service_atomic(
  '00000000-0000-0000-0000-00000000b80a', (select id from t_ids where k = 'shadow'), null, 'Shadow 3D', null, 260, 'fixed', 120, 0, 0, false, null, true, true, '{}'::uuid[],
  '{"deposit_type": "percent", "deposit_value": 25}'::jsonb);
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select result_months is null and retouch_included_days is null and deposit_type = 'percent' and deposit_value = 25
  from public.services where id = (select id from t_ids where k = 'shadow')), 'regras ausentes limpam; sinal em %');

-- 4. Regras inválidas são recusadas pelo banco.
select pg_temp.login('00000000-0000-0000-0000-00000000b801');
select pg_temp.expect(pg_temp.state_of($q$select public.upsert_catalog_service_atomic('00000000-0000-0000-0000-00000000b80a', null, null, 'X', null, 10, 'fixed', 30, 0, 0, false, null, false, true, '{}'::uuid[], '{"deposit_type":"percent","deposit_value":150}'::jsonb)$q$) = '23514', 'sinal acima de 100 % recusado');
select pg_temp.expect(pg_temp.state_of($q$select public.upsert_catalog_service_atomic('00000000-0000-0000-0000-00000000b80a', null, null, 'X', null, 10, 'fixed', 30, 0, 0, false, null, false, true, '{}'::uuid[], '{"retouch_included_days":0}'::jsonb)$q$) = '23514', 'retoque de 0 dias recusado');
select pg_temp.expect(pg_temp.state_of($q$select public.upsert_catalog_service_atomic('00000000-0000-0000-0000-00000000b80a', null, null, 'X', null, 10, 'fixed', 30, 0, 0, false, null, false, true, '{}'::uuid[], '{"result_months":500}'::jsonb)$q$) = '23514', 'durabilidade de 500 meses recusada');
select pg_temp.expect(pg_temp.state_of($q$select public.upsert_catalog_service_atomic('00000000-0000-0000-0000-00000000b80a', null, null, 'X', null, 10, 'fixed', 10, 0, 0, false, null, false, true, '{}'::uuid[])$q$) = '22023', 'duração de 10 min continua recusada');
select pg_temp.expect(pg_temp.state_of($q$update public.services set deposit_value = 0 where id = (select id from t_ids where k = 'shadow')$q$) = '23514', 'sinal com valor zero recusado');

-- 5. Serviço sem duração: aceito, nunca online.
insert into t_ids select 'rapido', public.upsert_catalog_service_atomic(
  '00000000-0000-0000-0000-00000000b80a', null, null, 'Venda rápida', null, 0, 'free', 0, 0, 0, false, null, true, true, '{}'::uuid[]);
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select duration_minutes = 0 and not online_booking from public.services where id = (select id from t_ids where k = 'rapido')),
  'sem duração salvo e fora da reserva online');
select pg_temp.expect(pg_temp.state_of($q$update public.services set online_booking = true where id = (select id from t_ids where k = 'rapido')$q$) = '23514',
  'sem duração não liga a reserva online nem direto na tabela');

-- 6. Permissão e outro estúdio.
select pg_temp.login('00000000-0000-0000-0000-00000000b802');
select pg_temp.expect(pg_temp.state_of($q$select public.upsert_catalog_service_atomic('00000000-0000-0000-0000-00000000b80a', null, null, 'Y', null, 10, 'fixed', 30, 0, 0, false, null, false, true, '{}'::uuid[], '{"retouch_included_days":30}'::jsonb)$q$) = '42501',
  'recepção não grava serviço');
select pg_temp.login('00000000-0000-0000-0000-00000000b803');
select pg_temp.expect(pg_temp.state_of($q$select public.upsert_catalog_service_atomic('00000000-0000-0000-0000-00000000b80a', (select id from t_ids where k = 'shadow'), null, 'Roubado', null, 1, 'fixed', 30, 0, 0, false, null, false, true, '{}'::uuid[])$q$) = '42501',
  'dona de outro estúdio não grava aqui');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select name = 'Shadow 3D' from public.services where id = (select id from t_ids where k = 'shadow')), 'serviço intacto');

rollback;
\o
\echo 'regras por serviço e serviço sem duração: ok'
