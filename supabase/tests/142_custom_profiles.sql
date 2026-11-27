-- Perfis personalizados: criar, liberar, atribuir, apagar e travas. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000f101', 'dona-f@teste.local'),
  ('00000000-0000-0000-0000-00000000f102', 'recep-f@teste.local'),
  ('00000000-0000-0000-0000-00000000f103', 'admin-f@teste.local'),
  ('00000000-0000-0000-0000-00000000f104', 'outra-f@teste.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-00000000f1a0', 'perfis-a', 'Estúdio A'),
  ('00000000-0000-0000-0000-00000000f1b0', 'perfis-b', 'Estúdio B');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-00000000f101', '00000000-0000-0000-0000-00000000f1a0', 'owner'),
  ('00000000-0000-0000-0000-00000000f102', '00000000-0000-0000-0000-00000000f1a0', 'receptionist'),
  ('00000000-0000-0000-0000-00000000f103', '00000000-0000-0000-0000-00000000f1a0', 'admin'),
  ('00000000-0000-0000-0000-00000000f104', '00000000-0000-0000-0000-00000000f1a0', 'professional');

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
create function pg_temp.as_user(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;
grant execute on function pg_temp.expect(boolean, text), pg_temp.state_of(text), pg_temp.as_user(uuid) to authenticated;

select pg_temp.as_user('00000000-0000-0000-0000-00000000f101');

-- Dona cria o perfil e libera o financeiro para ele.
create temp table t_ids (profile uuid);
grant all on t_ids to authenticated;
insert into t_ids select public.create_org_profile('00000000-0000-0000-0000-00000000f1a0', 'Recepção sênior', 'receptionist');
select pg_temp.expect((select profile is not null from t_ids), 'perfil criado');
select pg_temp.expect(pg_temp.state_of($q$select public.create_org_profile('00000000-0000-0000-0000-00000000f1a0', '  recepção SÊNIOR ', 'viewer')$q$) = '23505', 'nome repetido é recusado');
select pg_temp.expect(pg_temp.state_of($q$select public.create_org_profile('00000000-0000-0000-0000-00000000f1a0', 'X', 'viewer')$q$) = '22023', 'nome curto é recusado');
select pg_temp.expect(pg_temp.state_of($q$select public.create_org_profile('00000000-0000-0000-0000-00000000f1a0', 'Dona 2', 'owner')$q$) = '22023', 'perfil-base owner é recusado');

select pg_temp.expect(public.set_profile_permission('00000000-0000-0000-0000-00000000f1a0', (select profile from t_ids), 'financeiro.view', true), 'liberação gravada');
select pg_temp.expect(public.set_profile_permission('00000000-0000-0000-0000-00000000f1a0', (select profile from t_ids), 'agenda.manage', false), 'bloqueio gravado');
select pg_temp.expect(not public.set_profile_permission('00000000-0000-0000-0000-00000000f1a0', (select profile from t_ids), 'financeiro.view', true), 'repetir não muda nada');

-- Sem atribuição, a recepção segue no padrão.
select pg_temp.as_user('00000000-0000-0000-0000-00000000f102');
select pg_temp.expect(not public.has_permission('00000000-0000-0000-0000-00000000f1a0', 'financeiro.view'), 'recepção padrão não vê financeiro');
select pg_temp.expect(public.has_permission('00000000-0000-0000-0000-00000000f1a0', 'agenda.manage'), 'recepção padrão agenda');

-- Dona atribui o perfil à recepção.
select pg_temp.as_user('00000000-0000-0000-0000-00000000f101');
select pg_temp.expect(public.assign_user_profile('00000000-0000-0000-0000-00000000f1a0', '00000000-0000-0000-0000-00000000f102', null, (select profile from t_ids)), 'perfil atribuído');
select pg_temp.as_user('00000000-0000-0000-0000-00000000f102');
select pg_temp.expect(public.has_permission('00000000-0000-0000-0000-00000000f1a0', 'financeiro.view'), 'perfil libera financeiro');
select pg_temp.expect(not public.has_permission('00000000-0000-0000-0000-00000000f1a0', 'agenda.manage'), 'perfil bloqueia agenda.manage');
select pg_temp.expect(public.has_permission('00000000-0000-0000-0000-00000000f1a0', 'clientes.view'), 'o resto segue o papel-base');
select pg_temp.expect(pg_temp.state_of($q$select public.create_org_profile('00000000-0000-0000-0000-00000000f1a0', 'Intruso', 'viewer')$q$) = '42501', 'recepção não cria perfil');
select pg_temp.expect(pg_temp.state_of($q$select public.set_profile_permission('00000000-0000-0000-0000-00000000f1a0', (select profile from t_ids), 'financeiro.manage', true)$q$) = '42501', 'recepção não altera liberações');

-- Administração: não cria perfil-base admin, não altera acesso.%, não altera a si mesma.
select pg_temp.as_user('00000000-0000-0000-0000-00000000f103');
select pg_temp.expect(pg_temp.state_of($q$select public.create_org_profile('00000000-0000-0000-0000-00000000f1a0', 'Admin 2', 'admin')$q$) = '42501', 'admin não cria perfil baseado em admin');
select pg_temp.expect(pg_temp.state_of($q$select public.set_profile_permission('00000000-0000-0000-0000-00000000f1a0', (select profile from t_ids), 'acesso.manage', true)$q$) = '42501', 'admin não mexe em acesso.%');
select pg_temp.expect(pg_temp.state_of($q$select public.assign_user_profile('00000000-0000-0000-0000-00000000f1a0', '00000000-0000-0000-0000-00000000f103', 'viewer', null)$q$) = '42501', 'não altera o próprio perfil');
select pg_temp.expect(pg_temp.state_of($q$select public.assign_user_profile('00000000-0000-0000-0000-00000000f1a0', '00000000-0000-0000-0000-00000000f101', 'viewer', null)$q$) = '42501', 'perfil da dona não muda');
select pg_temp.expect(public.assign_user_profile('00000000-0000-0000-0000-00000000f1a0', '00000000-0000-0000-0000-00000000f104', 'finance', null), 'admin troca papel de outra pessoa');
select pg_temp.expect(pg_temp.state_of($q$select public.assign_user_profile('00000000-0000-0000-0000-00000000f1a0', '00000000-0000-0000-0000-00000000f104', 'finance', (select profile from t_ids))$q$) = '22023', 'papel e perfil juntos são recusados');
select pg_temp.expect(pg_temp.state_of($q$select public.assign_user_profile('00000000-0000-0000-0000-00000000f1a0', '00000000-0000-0000-0000-00000000f104', 'owner', null)$q$) = '22023', 'não vira dona por atribuição');

-- Outro estúdio não enxerga nem usa o perfil.
select pg_temp.as_user('00000000-0000-0000-0000-00000000f104');
select pg_temp.expect(pg_temp.state_of($q$select public.get_profile_matrix('00000000-0000-0000-0000-00000000f1a0')$q$) = '42501', 'quem não gerencia acessos não lê a matriz');

reset role;
select pg_temp.expect((select count(*) = 1 from public.audit_logs where org_id = '00000000-0000-0000-0000-00000000f1a0' and operation = 'PROFILE_CREATED'), 'criação auditada');
select pg_temp.expect((select count(*) = 2 from public.audit_logs where org_id = '00000000-0000-0000-0000-00000000f1a0' and operation = 'PROFILE_PERMISSION_SET'), 'liberações auditadas');
select pg_temp.expect((select count(*) = 2 from public.audit_logs where org_id = '00000000-0000-0000-0000-00000000f1a0' and operation = 'ACCESS_PROFILE_CHANGED'), 'atribuições auditadas');

-- Apagar o perfil devolve a pessoa ao padrão do papel-base.
select pg_temp.as_user('00000000-0000-0000-0000-00000000f101');
select pg_temp.expect(public.delete_org_profile('00000000-0000-0000-0000-00000000f1a0', (select profile from t_ids)), 'perfil apagado');
select pg_temp.as_user('00000000-0000-0000-0000-00000000f102');
select pg_temp.expect(not public.has_permission('00000000-0000-0000-0000-00000000f1a0', 'financeiro.view'), 'sem perfil, volta ao padrão');
select pg_temp.expect(public.has_permission('00000000-0000-0000-0000-00000000f1a0', 'agenda.manage'), 'sem perfil, agenda volta');

reset role;
select pg_temp.expect((select profile_id is null from public.user_roles where user_id = '00000000-0000-0000-0000-00000000f102'), 'user_roles.profile_id limpo');
select pg_temp.expect(not exists (select 1 from public.org_profile_permissions where org_id = '00000000-0000-0000-0000-00000000f1a0'), 'liberações do perfil removidas');

rollback;
\o
\echo 'perfis personalizados: ok'
