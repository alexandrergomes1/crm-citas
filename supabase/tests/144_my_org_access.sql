-- my_org_access: estúdio, papel, módulos e permissões numa ida só; sem acesso vira nulo; sem login falha.
-- Desfaz tudo no fim. Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000e10', 'dona@acc.local'),
  ('00000000-0000-0000-0000-000000000e11', 'recep@acc.local'),
  ('00000000-0000-0000-0000-000000000e12', 'donab@acc.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-000000000e1a', 'acc-a', 'Estúdio Acesso A'),
  ('00000000-0000-0000-0000-000000000e1b', 'acc-b', 'Estúdio Acesso B');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000000e10', '00000000-0000-0000-0000-000000000e1a', 'owner'),
  ('00000000-0000-0000-0000-000000000e11', '00000000-0000-0000-0000-000000000e1a', 'receptionist'),
  ('00000000-0000-0000-0000-000000000e12', '00000000-0000-0000-0000-000000000e1b', 'owner');

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
grant execute on function pg_temp.expect(boolean, text), pg_temp.state_of(text), pg_temp.login(uuid) to anon, authenticated;

select pg_temp.login('00000000-0000-0000-0000-000000000e10');
select pg_temp.expect((select public.my_org_access('acc-a') ->> 'role') = 'owner', 'dona recebe o papel owner');
select pg_temp.expect((select public.my_org_access('acc-a') -> 'org' ->> 'id') = '00000000-0000-0000-0000-000000000e1a', 'devolve o estúdio certo');
select pg_temp.expect((select pg_catalog.jsonb_array_length(public.my_org_access('acc-a') -> 'modules')) > 0, 'traz módulos');
select pg_temp.expect((select public.my_org_access('acc-a') -> 'permissions') @> '"ajustes.manage"'::jsonb, 'dona tem ajustes.manage');
select pg_temp.expect(public.my_org_access('acc-b') is null, 'estúdio de outra pessoa vira nulo');
select pg_temp.expect(public.my_org_access('nao-existe') is null, 'slug inexistente vira nulo');

select pg_temp.login('00000000-0000-0000-0000-000000000e11');
select pg_temp.expect((select public.my_org_access('acc-a') ->> 'role') = 'receptionist', 'recepção recebe o próprio papel');
select pg_temp.expect(not ((select public.my_org_access('acc-a') -> 'permissions') @> '"ajustes.manage"'::jsonb), 'recepção não tem ajustes.manage');

reset role;
select set_config('request.jwt.claims', '', true);
select set_config('role', 'anon', true);
select pg_temp.expect(pg_temp.state_of($q$select public.my_org_access('acc-a')$q$) in ('42501'), 'anônimo não executa');

rollback;
\o
\echo 'my_org_access: ok'
