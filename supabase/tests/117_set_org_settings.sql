-- set_org_settings: mescla atômica de organizations.settings. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000de1', 'dono5@teste.local'),
  ('00000000-0000-0000-0000-000000000de2', 'recep5@teste.local'),
  ('00000000-0000-0000-0000-000000000de3', 'fora5@teste.local');
insert into public.organizations (id, slug, name, settings) values
  ('00000000-0000-0000-0000-000000000dea', 'cfg-a', 'Estúdio A',
   '{"business": {"legal_name": "Karenn SL"}, "working_hours": {"1": {"active": true, "open": "09:00", "close": "18:00"}}}'),
  ('00000000-0000-0000-0000-000000000deb', 'cfg-b', 'Estúdio B', '{}');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000000de1', '00000000-0000-0000-0000-000000000dea', 'owner'),
  ('00000000-0000-0000-0000-000000000de2', '00000000-0000-0000-0000-000000000dea', 'receptionist'),
  ('00000000-0000-0000-0000-000000000de3', '00000000-0000-0000-0000-000000000deb', 'owner');

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

select pg_temp.login('00000000-0000-0000-0000-000000000de1');
select public.set_org_settings('00000000-0000-0000-0000-000000000dea', '{"payment_methods": ["CASH", "BIZUM"]}');
do $$ begin
  perform pg_temp.expect(pg_temp.state_of($q$select public.set_org_settings('00000000-0000-0000-0000-000000000dea', '{"plan": "pro"}')$q$) = '22023', 'chave desconhecida recusada');
  perform pg_temp.expect(pg_temp.state_of($q$select public.set_org_settings('00000000-0000-0000-0000-000000000dea', '[]')$q$) = '22023', 'patch que não é objeto recusado');
  perform pg_temp.expect(pg_temp.state_of($q$select public.set_org_settings('00000000-0000-0000-0000-000000000deb', '{"policies": {}}')$q$) = '42501', 'outro estúdio recusado');
end $$;

select pg_temp.login('00000000-0000-0000-0000-000000000de2');
do $$ begin
  perform pg_temp.expect(pg_temp.state_of($q$select public.set_org_settings('00000000-0000-0000-0000-000000000dea', '{"policies": {}}')$q$) = '42501', 'recepção não altera configurações');
end $$;

reset role;
select pg_temp.expect((select settings -> 'payment_methods' = '["CASH", "BIZUM"]'::jsonb
    and settings -> 'business' ->> 'legal_name' = 'Karenn SL'
    and settings -> 'working_hours' ? '1'
  from public.organizations where id = '00000000-0000-0000-0000-000000000dea'), 'mescla preserva as outras chaves');
select pg_temp.expect((select count(*) = 1 from public.audit_logs
  where org_id = '00000000-0000-0000-0000-000000000dea' and operation = 'SETTINGS_SET'), 'alteração auditada');

rollback;
\o
\echo 'configurações do estúdio por mescla atômica: ok'
