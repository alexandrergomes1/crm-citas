-- Gravação direta no histórico de auditoria limitada (20261029280000). Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000ea1', 'dona-audit@teste.local'),
  ('00000000-0000-0000-0000-000000000ea2', 'prof-audit@teste.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-000000000eaa', 'audit-a', 'Estúdio A');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000000ea1', '00000000-0000-0000-0000-000000000eaa', 'owner'),
  ('00000000-0000-0000-0000-000000000ea2', '00000000-0000-0000-0000-000000000eaa', 'professional');

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

-- Dona, pela API: não forja entradas que só funções privilegiadas gravam.
select pg_temp.login('00000000-0000-0000-0000-000000000ea1');
select pg_temp.expect(pg_temp.state_of($q$insert into public.audit_logs (org_id, user_id, table_name, operation)
  values ('00000000-0000-0000-0000-000000000eaa', '00000000-0000-0000-0000-000000000ea1', 'org_role_permissions', 'ROLE_PERMISSION_SET')$q$) = '42501',
  'liberação de perfil forjada recusada');
select pg_temp.expect(pg_temp.state_of($q$insert into public.audit_logs (org_id, user_id, table_name, operation)
  values ('00000000-0000-0000-0000-000000000eaa', '00000000-0000-0000-0000-000000000ea1', 'sales', 'checkout_create')$q$) = '42501',
  'fechamento de comanda forjado recusado');
select pg_temp.expect(pg_temp.state_of($q$insert into public.audit_logs (org_id, user_id, table_name, operation)
  values ('00000000-0000-0000-0000-000000000eaa', '00000000-0000-0000-0000-000000000ea1', 'anamneses', 'ANAMNESE_GATE_OVERRIDE')$q$) = '42501',
  'liberação de trava de anamnese forjada recusada');
select pg_temp.expect(pg_temp.state_of($q$insert into public.audit_logs (org_id, user_id, table_name, operation)
  values ('00000000-0000-0000-0000-000000000eaa', '00000000-0000-0000-0000-000000000ea1', 'clients', 'STATUS_CHANGE')$q$) = '42501',
  'operação permitida em tabela errada recusada');
reset role; select set_config('request.jwt.claims', '', true);

-- Profissional: a leitura clínica é registrada só pelas funções DEFINER de leitura (20261114040000); pela API, não.
select pg_temp.login('00000000-0000-0000-0000-000000000ea2');
select pg_temp.expect(pg_temp.state_of($q$insert into public.audit_logs (org_id, user_id, table_name, operation)
  values ('00000000-0000-0000-0000-000000000eaa', '00000000-0000-0000-0000-000000000ea2', 'anamneses', 'CLINICAL_READ')$q$) = '42501',
  'leitura clínica não se grava pela API');
select pg_temp.expect(pg_temp.state_of($q$insert into public.audit_logs (org_id, user_id, table_name, operation)
  values ('00000000-0000-0000-0000-000000000eaa', '00000000-0000-0000-0000-000000000ea2', 'products', 'STOCK_ENTRADA')$q$) = '42501',
  'estoque não se grava pela API (gatilho DEFINER do Catálogo, 20261114030100; par removido em 20261114040000)');
select pg_temp.expect(pg_temp.state_of($q$insert into public.audit_logs (org_id, user_id, table_name, operation)
  values ('00000000-0000-0000-0000-000000000eaa', '00000000-0000-0000-0000-000000000ea1', 'anamneses', 'CLINICAL_READ')$q$) = '42501',
  'continua sem gravar em nome de outra pessoa');
reset role; select set_config('request.jwt.claims', '', true);

-- Toda operação gravada por função SECURITY INVOKER está na lista.
do $$
declare
  v_missing text;
begin
  select string_agg(p.proname || ':' || m[1] || '/' || m[2], ', ') into v_missing
  from pg_proc p
  cross join lateral regexp_matches(pg_get_functiondef(p.oid),
    'audit_logs\s*\([^)]*\)\s*values\s*\([^,]+,[^,]+,\s*''([a-z_]+)''\s*,\s*''([A-Z_]+)''', 'g') m
  where p.pronamespace = 'public'::regnamespace
    and not p.prosecdef
    and m[2] <> 'STOCK_'
    and not exists (
      select 1 from pg_policies pol
      where pol.tablename = 'audit_logs' and pol.policyname = 'audit_insert_member'
        and pol.with_check like '%(table_name = ''' || m[1] || '''::text) AND (operation = ''' || m[2] || '''::text)%'
    );
  perform pg_temp.expect(v_missing is null, 'operações de funções invoker fora da lista: ' || coalesce(v_missing, ''));
end $$;

rollback;
\o
\echo 'auditoria só aceita registros da lista: ok'
