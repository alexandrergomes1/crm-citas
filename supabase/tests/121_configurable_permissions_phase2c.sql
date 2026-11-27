-- Fase 2c (spec 37): modelos de anamnese, pacotes da cliente e contas a pagar. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000e21', 'dono8@teste.local'),
  ('00000000-0000-0000-0000-000000000e22', 'prof8@teste.local'),
  ('00000000-0000-0000-0000-000000000e23', 'leitura8@teste.local'),
  ('00000000-0000-0000-0000-000000000e24', 'fin8@teste.local'),
  ('00000000-0000-0000-0000-000000000e25', 'recep8@teste.local');
insert into public.organizations (id, slug, name) values ('00000000-0000-0000-0000-000000000e2a', 'perm8-a', 'Estúdio A');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000000e21', '00000000-0000-0000-0000-000000000e2a', 'owner'),
  ('00000000-0000-0000-0000-000000000e22', '00000000-0000-0000-0000-000000000e2a', 'professional'),
  ('00000000-0000-0000-0000-000000000e23', '00000000-0000-0000-0000-000000000e2a', 'viewer'),
  ('00000000-0000-0000-0000-000000000e24', '00000000-0000-0000-0000-000000000e2a', 'finance'),
  ('00000000-0000-0000-0000-000000000e25', '00000000-0000-0000-0000-000000000e2a', 'receptionist');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-000000000e2c', '00000000-0000-0000-0000-000000000e2a', 'Nerea Ruiz');
insert into public.client_entitlements (id, org_id, client_id, package_name, total_sessions, used_sessions, status)
values ('00000000-0000-0000-0000-000000000e2d', '00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000e2c',
        'Pacote 5 sessões', 5, 1, 'active');
insert into public.payables (org_id, description, category, value, due_date, status)
values ('00000000-0000-0000-0000-000000000e2a', 'Aluguel', 'aluguel', 900, '2026-11-05', 'pending');

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

select pg_temp.login('00000000-0000-0000-0000-000000000e22');
do $$ begin
  perform pg_temp.expect(pg_temp.state_of($q$insert into public.anamnese_templates (org_id, title, questions)
    values ('00000000-0000-0000-0000-000000000e2a', 'Modelo da profissional', '[]')$q$) = '42501', 'profissional não cria modelo por padrão');
end $$;

select pg_temp.login('00000000-0000-0000-0000-000000000e23');
do $$ begin
  update public.client_entitlements set used_sessions = 0 where id = '00000000-0000-0000-0000-000000000e2d';
  perform pg_temp.expect((select count(*) from public.payables) = 0, 'somente leitura não lê contas a pagar');
end $$;

select pg_temp.login('00000000-0000-0000-0000-000000000e25');
do $$ begin
  perform pg_temp.expect((select count(*) from public.payables) = 0, 'recepção não lê contas a pagar');
end $$;

select pg_temp.login('00000000-0000-0000-0000-000000000e24');
do $$ begin
  perform pg_temp.expect((select count(*) from public.payables) = 1, 'financeiro lê contas a pagar');
  perform pg_temp.expect(pg_temp.state_of($q$update public.payables set notes = 'ok' where org_id = '00000000-0000-0000-0000-000000000e2a'$q$) = 'ok', 'financeiro edita contas a pagar');
end $$;

reset role;
select pg_temp.expect((select used_sessions from public.client_entitlements where id = '00000000-0000-0000-0000-000000000e2d') = 1,
  'somente leitura não mexe nas sessões do pacote');

-- Dona libera modelos para a profissional.
select pg_temp.login('00000000-0000-0000-0000-000000000e21');
select public.set_role_permission('00000000-0000-0000-0000-000000000e2a', 'professional', 'anamnese.manage_templates', true);
select pg_temp.login('00000000-0000-0000-0000-000000000e22');
do $$ begin
  perform pg_temp.expect(pg_temp.state_of($q$insert into public.anamnese_templates (org_id, title, questions)
    values ('00000000-0000-0000-0000-000000000e2a', 'Modelo da profissional', '[]')$q$) = 'ok', 'profissional com liberação cria modelo');
end $$;

reset role;
rollback;
\o
\echo 'liberações fase 2c (modelos, pacotes, contas a pagar): ok'
