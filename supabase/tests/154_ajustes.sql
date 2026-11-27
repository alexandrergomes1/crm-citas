-- Ajustes (porte, orçamento de chamadas): leituras e gravações das migrations 20261114060000..060500.
-- Isolamento entre estúdios, anônimo sem execução, permissão por papel, escalada de privilégio recusada (papel, perfil,
-- liberação; Administração só com acesso.grant_admin; criar acesso e trocar perfil com acesso.manage), conta que já
-- existia nunca ligada a um estúdio, limite de 10 acessos novos por dia, falha de criação auditada, proprietária
-- protegida, integridade do perfil do acesso, gravação direta em user_roles/organizations fechada, ajustes.manage dado à
-- gerência valendo, auditoria gravada (contatos só pelo nome do campo) e não forjável, limites (turno com fim depois do
-- início), tudo-ou-nada e caminhos felizes. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000001540', 'dona@a154.local'),
  ('00000000-0000-0000-0000-000000001541', 'admin@a154.local'),
  ('00000000-0000-0000-0000-000000001542', 'gerente@a154.local'),
  ('00000000-0000-0000-0000-000000001543', 'recep@a154.local'),
  ('00000000-0000-0000-0000-000000001544', 'prof@a154.local'),
  ('00000000-0000-0000-0000-000000001545', 'donab@b154.local'),
  ('00000000-0000-0000-0000-000000001546', 'Nova.Pessoa@a154.local'),
  ('00000000-0000-0000-0000-000000001547', 'outra@a154.local'),
  ('00000000-0000-0000-0000-000000001548', 'fin@a154.local');
-- Conta antiga, sem papel em nenhum estúdio (criada há 2 dias): não pode ser ligada a um estúdio por aqui.
insert into auth.users (id, email, created_at) values ('00000000-0000-0000-0000-000000001549', 'antiga@a154.local', now() - interval '2 days');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-00000000154a', 'a154', 'Ajustes 154 A'),
  ('00000000-0000-0000-0000-00000000154b', 'b154', 'Ajustes 154 B');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000001540', '00000000-0000-0000-0000-00000000154a', 'owner'),
  ('00000000-0000-0000-0000-000000001541', '00000000-0000-0000-0000-00000000154a', 'admin'),
  ('00000000-0000-0000-0000-000000001542', '00000000-0000-0000-0000-00000000154a', 'manager'),
  ('00000000-0000-0000-0000-000000001543', '00000000-0000-0000-0000-00000000154a', 'receptionist'),
  ('00000000-0000-0000-0000-000000001544', '00000000-0000-0000-0000-00000000154a', 'professional'),
  ('00000000-0000-0000-0000-000000001545', '00000000-0000-0000-0000-00000000154b', 'owner'),
  ('00000000-0000-0000-0000-000000001548', '00000000-0000-0000-0000-00000000154a', 'finance');
-- A dona deu à gerência acesso.manage e ajustes.manage; ao financeiro, equipe.manage (sem acesso.manage).
insert into public.org_role_permissions (org_id, role, permission, allowed) values
  ('00000000-0000-0000-0000-00000000154a', 'manager', 'acesso.manage', true),
  ('00000000-0000-0000-0000-00000000154a', 'manager', 'ajustes.manage', true),
  ('00000000-0000-0000-0000-00000000154a', 'finance', 'equipe.manage', true);
insert into public.profiles (user_id, org_id, full_name) values
  ('00000000-0000-0000-0000-000000001543', '00000000-0000-0000-0000-00000000154a', 'Recepção Rita')
on conflict (user_id, org_id) do update set full_name = excluded.full_name;
insert into public.staff_members (id, org_id, name, role, position, active, user_id) values
  ('00000000-0000-0000-0000-0000000154a1', '00000000-0000-0000-0000-00000000154a', 'Profissional Um', 'professional', 1, true, '00000000-0000-0000-0000-000000001544'),
  ('00000000-0000-0000-0000-0000000154b1', '00000000-0000-0000-0000-00000000154b', 'Profissional B', 'professional', 1, true, null);
insert into public.staff_shifts (org_id, staff_id, day_of_week, start_time, end_time, active) values
  ('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-0000000154a1', 1, '09:00', '18:00', true);
insert into public.payment_accounts (id, org_id, kind, holder_name, identifier) values
  ('00000000-0000-0000-0000-0000000154c1', '00000000-0000-0000-0000-00000000154a', 'bizum', 'Estúdio A', '+34600000154'),
  ('00000000-0000-0000-0000-0000000154c9', '00000000-0000-0000-0000-00000000154b', 'bizum', 'Estúdio B', '+34600000999');
insert into public.clients (org_id, full_name, phone) values
  ('00000000-0000-0000-0000-00000000154a', 'Cliente Um', '+34600000001'),
  ('00000000-0000-0000-0000-00000000154a', 'Cliente Dois', '+34600000002'),
  ('00000000-0000-0000-0000-00000000154b', 'Cliente B', '+34600000003');
-- Perfis do estúdio A: um "Recepção plus" (exceção: catalogo.manage) e um "Super recepção" com acesso.grant_admin (só a dona tem).
insert into public.org_profiles (id, org_id, name, base_role) values
  ('00000000-0000-0000-0000-0000000154e1', '00000000-0000-0000-0000-00000000154a', 'Recepção plus', 'receptionist'),
  ('00000000-0000-0000-0000-0000000154e2', '00000000-0000-0000-0000-00000000154a', 'Super recepção', 'receptionist'),
  ('00000000-0000-0000-0000-0000000154e3', '00000000-0000-0000-0000-00000000154a', 'Admin do estúdio', 'admin'),
  ('00000000-0000-0000-0000-0000000154e9', '00000000-0000-0000-0000-00000000154b', 'Perfil do B', 'receptionist');
insert into public.org_profile_permissions (profile_id, org_id, permission, allowed) values
  ('00000000-0000-0000-0000-0000000154e1', '00000000-0000-0000-0000-00000000154a', 'catalogo.manage', true),
  ('00000000-0000-0000-0000-0000000154e2', '00000000-0000-0000-0000-00000000154a', 'acesso.grant_admin', true);

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
create function pg_temp.logout() returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);
end $$;
create function pg_temp.audits(p_op text) returns bigint language sql as $$
  select count(*) from public.audit_logs where operation = p_op and org_id = '00000000-0000-0000-0000-00000000154a'
$$;
grant execute on function pg_temp.expect(boolean, text), pg_temp.state_of(text), pg_temp.login(uuid), pg_temp.logout(),
  pg_temp.audits(text) to anon, authenticated;

-- ─── Anônimo: nenhuma função nova executa ─────────────────────────────────────────────────────────────
select pg_temp.expect(not exists (
  select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace
    and p.proname in ('settings_section_read', 'team_screen', 'access_screen', 'profiles_screen', 'settings_update_studio',
      'settings_save_attendance', 'settings_save_ficha', 'settings_save_payments', 'settings_save_payment_account',
      'team_save_staff', 'team_set_staff_flags', 'team_grant_access', 'team_access_begin', 'team_access_abort',
      'access_apply_changes', 'assign_user_profile',
      'access_permissions_of', 'access_assert_can_grant', 'ajustes_audit_org', 'ajustes_audit_payment_account',
      'ajustes_audit_staff', 'user_roles_profile_guard')
    and has_function_privilege('anon', p.oid, 'execute')), 'anônimo não executa nenhuma função dos Ajustes');
select pg_temp.expect(not exists (
  select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace
    and p.proname in ('access_assert_can_grant', 'ajustes_audit_org', 'ajustes_audit_payment_account', 'ajustes_audit_staff', 'user_roles_profile_guard')
    and has_function_privilege('authenticated', p.oid, 'execute')), 'ajudantes e gatilhos: ninguém logado executa pela API');
select pg_temp.expect((select bool_and(p.prosecdef = (p.proname in ('team_grant_access', 'team_access_begin', 'team_access_abort',
      'assign_user_profile', 'settings_update_studio', 'ajustes_audit_org',
      'ajustes_audit_payment_account', 'ajustes_audit_staff', 'user_roles_profile_guard'))
    and p.proconfig @> array['search_path=""'])
  from pg_proc p where p.pronamespace = 'public'::regnamespace
    and p.proname in ('settings_section_read', 'team_screen', 'access_screen', 'profiles_screen', 'settings_update_studio',
      'settings_save_attendance', 'settings_save_ficha', 'settings_save_payments', 'settings_save_payment_account',
      'team_save_staff', 'team_set_staff_flags', 'team_grant_access', 'team_access_begin', 'team_access_abort',
      'access_apply_changes', 'assign_user_profile',
      'access_permissions_of', 'access_assert_can_grant', 'ajustes_audit_org', 'ajustes_audit_payment_account',
      'ajustes_audit_staff', 'user_roles_profile_guard')), 'INVOKER por padrão, DEFINER só onde justificado; search_path vazio em todas');
select pg_temp.login(null);
select pg_temp.expect(pg_temp.state_of($q$select public.team_screen('00000000-0000-0000-0000-00000000154a')$q$) = '42501', 'sem login: recusado');
select pg_temp.logout();

-- ─── Leituras: dona do A ─────────────────────────────────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001540');
select pg_temp.expect((public.settings_section_read('00000000-0000-0000-0000-00000000154a', 'dados') ->> 'client_count')::int = 2, 'dados: só as clientes do A');
select pg_temp.expect((public.settings_section_read('00000000-0000-0000-0000-00000000154a', 'plano') ->> 'active_staff')::int = 1, 'plano: profissionais ativas do A');
select pg_temp.expect(public.settings_section_read('00000000-0000-0000-0000-00000000154a', 'plano') ? 'modules', 'plano: módulos (estúdio com assinatura de teste)');
select pg_temp.expect(jsonb_array_length(public.settings_section_read('00000000-0000-0000-0000-00000000154a', 'pagamentos') -> 'accounts') = 1, 'pagamentos: só as contas do A');
select pg_temp.expect(public.settings_section_read('00000000-0000-0000-0000-00000000154a', 'ficha') -> 'pin' ->> 'configured' = 'false', 'ficha: PIN não definido');
select pg_temp.expect(pg_temp.state_of($q$select public.settings_section_read('00000000-0000-0000-0000-00000000154a', 'segredo')$q$) = '22023', 'seção desconhecida: recusada');
create temp table t_team on commit drop as select public.team_screen('00000000-0000-0000-0000-00000000154a') as s;
select pg_temp.expect((select jsonb_array_length(s -> 'staff') from t_team) = 1, 'equipe: só a do A');
select pg_temp.expect((select jsonb_array_length(s -> 'staff' -> 0 -> 'staff_shifts') from t_team) = 1, 'equipe: turnos juntos');
select pg_temp.expect((select not (s -> 'staff' -> 0 ? 'org_id') and not (s -> 'staff' -> 0 ? 'created_at') from t_team), 'equipe: só as colunas da tela');
select pg_temp.expect((select jsonb_array_length(s -> 'accounts') from t_team) = 6, 'equipe: contas ativas do A para ligar');
create temp table t_access on commit drop as select public.access_screen('00000000-0000-0000-0000-00000000154a') as s;
select pg_temp.expect((select jsonb_array_length(s -> 'profiles') from t_access) = 3, 'acessos: perfis só do A');
select pg_temp.expect((select s -> 'linked' -> 0 ->> 'name' from t_access) = 'Profissional Um', 'acessos: conta ligada à profissional');
select pg_temp.expect((select s -> 'accounts' @> '[{"full_name": "Recepção Rita"}]'::jsonb from t_access), 'acessos: nome no estúdio');
create temp table t_prof on commit drop as select public.profiles_screen('00000000-0000-0000-0000-00000000154a') as s;
select pg_temp.expect((select jsonb_array_length(s -> 'roles') > 0 and jsonb_array_length(s -> 'profile_rows') > 0 from t_prof), 'perfis: duas matrizes');
select pg_temp.expect((select not (s -> 'profile_rows' @> '[{"profile_id": "00000000-0000-0000-0000-0000000154e9"}]'::jsonb) from t_prof), 'perfis: nada do B');
select pg_temp.logout();

-- ─── Isolamento: dona do B não lê nem grava o A ──────────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001545');
select pg_temp.expect(pg_temp.state_of($q$select public.settings_section_read('00000000-0000-0000-0000-00000000154a', 'dados')$q$) = '42501', 'B não lê ajustes do A');
select pg_temp.expect(pg_temp.state_of($q$select public.team_screen('00000000-0000-0000-0000-00000000154a')$q$) = '42501', 'B não lê equipe do A');
select pg_temp.expect(pg_temp.state_of($q$select public.access_screen('00000000-0000-0000-0000-00000000154a')$q$) = '42501', 'B não lê acessos do A');
select pg_temp.expect(pg_temp.state_of($q$select public.profiles_screen('00000000-0000-0000-0000-00000000154a')$q$) = '42501', 'B não lê liberações do A');
select pg_temp.expect(pg_temp.state_of($q$select public.settings_update_studio('00000000-0000-0000-0000-00000000154a', 'Invadido', '', '', '', '', 'Europe/Madrid', 'EUR', '', '', '', '', '', '')$q$) = '42501', 'B não muda o estúdio A');
select pg_temp.expect(pg_temp.state_of($q$select public.settings_save_payments('00000000-0000-0000-0000-00000000154b', null, null, '[{"id": "00000000-0000-0000-0000-0000000154c1", "active": false}]')$q$) = 'P0002', 'B não desliga conta do A pelo próprio estúdio');
select pg_temp.expect(pg_temp.state_of($q$select public.settings_save_payment_account('00000000-0000-0000-0000-00000000154b', '00000000-0000-0000-0000-0000000154c1', 'bizum', 'Golpe', '+34611111111', '', '')$q$) = 'P0002', 'B não edita conta do A');
select pg_temp.expect(pg_temp.state_of($q$select public.team_set_staff_flags('00000000-0000-0000-0000-00000000154b', '00000000-0000-0000-0000-0000000154a1', false, null, null)$q$) = 'P0002', 'B não desativa profissional do A');
select pg_temp.expect(pg_temp.state_of($q$select public.team_grant_access('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001547', 'X', 'viewer', null)$q$) = '42501', 'B não dá acesso ao A');
select pg_temp.expect(pg_temp.state_of($q$select public.team_access_begin('00000000-0000-0000-0000-00000000154a')$q$) = '42501', 'B não começa acesso no A');
select pg_temp.expect(pg_temp.state_of($q$select public.access_apply_changes('00000000-0000-0000-0000-00000000154a', '[{"role": "viewer", "permission": "catalogo.manage", "allowed": true}]')$q$) = '42501', 'B não muda liberação do A');
select pg_temp.expect(pg_temp.state_of($q$select public.access_apply_changes('00000000-0000-0000-0000-00000000154b', '[{"profile_id": "00000000-0000-0000-0000-0000000154e1", "permission": "catalogo.manage", "allowed": false}]')$q$) = '22023', 'B não muda perfil do A pelo próprio estúdio');
select pg_temp.expect(pg_temp.state_of($q$select public.team_grant_access('00000000-0000-0000-0000-00000000154b', '00000000-0000-0000-0000-000000001547', 'X', null, '00000000-0000-0000-0000-0000000154e2')$q$) = '22023', 'B não usa perfil do A');
select pg_temp.logout();
select pg_temp.expect((select name from public.organizations where id = '00000000-0000-0000-0000-00000000154a') = 'Ajustes 154 A', 'A intacto');
select pg_temp.expect((select active from public.payment_accounts where id = '00000000-0000-0000-0000-0000000154c1'), 'conta do A intacta');

-- ─── Papéis: recepção e profissional ─────────────────────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001543');
select pg_temp.expect(pg_temp.state_of($q$select public.settings_section_read('00000000-0000-0000-0000-00000000154a', 'dados')$q$) = '42501', 'recepção não abre Ajustes do estúdio');
select pg_temp.expect(jsonb_array_length(public.team_screen('00000000-0000-0000-0000-00000000154a') -> 'accounts') = 0, 'recepção vê a equipe, sem as contas');
select pg_temp.expect(pg_temp.state_of($q$select public.team_save_staff('00000000-0000-0000-0000-00000000154a', null, 'Nova', '', '', '', '', null, '#112233', 0, true, true, '[{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"}]')$q$) = '42501', 'recepção não cadastra profissional');
select pg_temp.expect(pg_temp.state_of($q$select public.settings_save_payment_account('00000000-0000-0000-0000-00000000154a', null, 'bizum', 'Golpe', '+34611111111', '', '')$q$) = '42501', 'recepção não cria conta de recebimento');
select pg_temp.expect(pg_temp.state_of($q$select public.team_grant_access('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001547', 'X', 'viewer', null)$q$) = '42501', 'recepção não dá acesso');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000001544');
select pg_temp.expect(pg_temp.state_of($q$select public.team_screen('00000000-0000-0000-0000-00000000154a')$q$) = '42501', 'profissional não abre a equipe');
select pg_temp.expect(pg_temp.state_of($q$select public.access_screen('00000000-0000-0000-0000-00000000154a')$q$) = '42501', 'profissional não abre acessos');
select pg_temp.logout();

-- ─── Criar acesso e trocar perfil exigem acesso.manage (equipe.manage não basta) ────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001548');
select pg_temp.expect(pg_temp.state_of($q$select public.team_access_begin('00000000-0000-0000-0000-00000000154a')$q$) = '42501', 'financeiro com equipe.manage não começa acesso');
select pg_temp.expect(pg_temp.state_of($q$select public.team_grant_access('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001547', 'X', 'viewer', null)$q$) = '42501', 'financeiro com equipe.manage não dá acesso');
select pg_temp.expect(pg_temp.state_of($q$select public.assign_user_profile('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001543', 'viewer', null)$q$) = '42501', 'financeiro com equipe.manage não troca perfil');
select pg_temp.expect(jsonb_array_length(public.team_screen('00000000-0000-0000-0000-00000000154a') -> 'staff') = 1, 'mas gerencia a equipe');
select pg_temp.logout();

-- ─── Escalada: gerente (com acesso.manage dado pela dona, sem acesso.grant_admin) ───────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001542');
select pg_temp.expect(pg_temp.state_of($q$select public.team_grant_access('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001547', 'Outra', 'admin', null)$q$) = '42501', 'gerente não dá Administração');
select pg_temp.expect(pg_temp.state_of($q$select public.team_grant_access('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001547', 'Outra', 'owner', null)$q$) = '22023', 'ninguém dá proprietária por aqui');
select pg_temp.expect(pg_temp.state_of($q$select public.team_grant_access('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001547', 'Outra', null, '00000000-0000-0000-0000-0000000154e2')$q$) = '42501', 'gerente não dá perfil com liberação que não tem (acesso.grant_admin)');
select pg_temp.expect(pg_temp.state_of($q$select public.assign_user_profile('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001543', null, '00000000-0000-0000-0000-0000000154e2')$q$) = '42501', 'gerente não troca perfil para um acima do próprio');
select pg_temp.expect(pg_temp.state_of($q$select public.assign_user_profile('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001541', 'viewer', null)$q$) = '42501', 'gerente não mexe na administração');
select pg_temp.expect(pg_temp.state_of($q$select public.assign_user_profile('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001540', 'viewer', null)$q$) = '42501', 'gerente não mexe na proprietária');
select pg_temp.expect(pg_temp.state_of($q$select public.assign_user_profile('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001542', 'admin', null)$q$) = '42501', 'ninguém troca o próprio perfil');
select pg_temp.expect(pg_temp.state_of($q$select public.team_grant_access('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001542', 'Eu', 'viewer', null)$q$) = '42501', 'ninguém se dá acesso');
-- Conta que já existia: nunca ligada a um estúdio por aqui (tem papel noutro estúdio, ou foi criada há mais de 15 min).
select pg_temp.expect(pg_temp.state_of($q$select public.team_grant_access('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001545', 'Dona B', 'viewer', null)$q$) = '42501', 'conta com papel noutro estúdio: recusada');
select pg_temp.expect(pg_temp.state_of($q$select public.team_grant_access('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001543', 'Rita', 'viewer', null)$q$) = '42501', 'quem já tem acesso não é sobrescrito');
select pg_temp.expect(pg_temp.state_of($q$select public.team_grant_access('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001540', 'Dona', 'viewer', null)$q$) = '42501', 'proprietária não é rebaixada por um acesso novo');
select pg_temp.expect(pg_temp.state_of($q$select public.team_grant_access('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001549', 'Antiga', 'viewer', null)$q$) = '42501', 'conta antiga sem estúdio: recusada');
select pg_temp.expect(pg_temp.state_of($q$select public.team_grant_access('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-0000000015ff', 'Ninguém', 'viewer', null)$q$) = '42501', 'conta inexistente: recusada');
-- Caminhos felizes do gerente: começa (limite), dá Recepção plus (só liberações que ele tem) e troca a recepção de perfil.
select public.team_access_begin('00000000-0000-0000-0000-00000000154a');
select pg_temp.expect(public.team_grant_access('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001546', ' Nova Pessoa ', null, '00000000-0000-0000-0000-0000000154e1')
  = '{"user_id": "00000000-0000-0000-0000-000000001546", "role": "receptionist"}'::jsonb, 'gerente dá acesso com perfil permitido para a conta recém-criada');
select pg_temp.expect(public.assign_user_profile('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001543', 'viewer', null), 'gerente troca recepção para Visualização');
-- Uma conta de uma tentativa que falhou: o abort registra antes do servidor apagar; conta com papel não é "órfã".
select public.team_access_abort('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001549');
select pg_temp.expect(pg_temp.state_of($q$select public.team_access_abort('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001543')$q$) = '42501', 'abort não vale para conta com papel');
select pg_temp.logout();
select pg_temp.expect((select role = 'receptionist' and profile_id = '00000000-0000-0000-0000-0000000154e1' and active
  from public.user_roles where user_id = '00000000-0000-0000-0000-000000001546' and org_id = '00000000-0000-0000-0000-00000000154a'), 'acesso novo: papel-base do perfil');
select pg_temp.expect((select full_name from public.profiles where user_id = '00000000-0000-0000-0000-000000001546' and org_id = '00000000-0000-0000-0000-00000000154a') = 'Nova Pessoa', 'acesso novo: nome no estúdio');
select pg_temp.expect((select role from public.user_roles where user_id = '00000000-0000-0000-0000-000000001540' and org_id = '00000000-0000-0000-0000-00000000154a') = 'owner', 'proprietária continua proprietária');
select pg_temp.expect(pg_temp.audits('ACCESS_CREATED') = 1 and pg_temp.audits('ACCESS_CREATE_STARTED') = 1 and pg_temp.audits('ACCESS_CREATE_FAILED') = 1, 'acesso novo, tentativa e falha auditados');
select pg_temp.expect((select new_data = '{"role": "receptionist", "profile_id": "00000000-0000-0000-0000-0000000154e1"}'::jsonb
  from public.audit_logs where operation = 'ACCESS_CREATED' and org_id = '00000000-0000-0000-0000-00000000154a'), 'auditoria do acesso: só o que o banco sabe (sem e-mail nem dado alegado pela tela)');
select pg_temp.expect(pg_temp.audits('ACCESS_PROFILE_CHANGED') = 1, 'troca de perfil auditada');

-- ─── Administração: tira e dá Administração só quem tem acesso.grant_admin ──────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001541');
select pg_temp.expect(pg_temp.state_of($q$select public.assign_user_profile('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001542', 'admin', null)$q$) = '42501', 'administração não dá Administração');
select pg_temp.expect(pg_temp.state_of($q$select public.assign_user_profile('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001542', null, '00000000-0000-0000-0000-0000000154e3')$q$) = '42501', 'administração não dá perfil baseado em Administração');
select pg_temp.expect(pg_temp.state_of($q$select public.assign_user_profile('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001542', null, '00000000-0000-0000-0000-0000000154e2')$q$) = '42501', 'administração não dá perfil com acesso.grant_admin');
select pg_temp.expect(public.assign_user_profile('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001544', 'finance', null), 'administração dá papel operacional');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000001540');
select pg_temp.expect(pg_temp.state_of($q$select public.assign_user_profile('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001540', 'viewer', null)$q$) = '42501', 'dona não troca o próprio perfil');
select pg_temp.expect(public.assign_user_profile('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001548', null, '00000000-0000-0000-0000-0000000154e3'), 'dona dá perfil baseado em Administração');
select pg_temp.expect(public.assign_user_profile('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001548', 'finance', null), 'dona tira Administração');
-- Limite: 10 acessos novos por estúdio a cada 24 h (o do gerente já contou 1).
do $$ begin
  for i in 1..9 loop perform public.team_access_begin('00000000-0000-0000-0000-00000000154a'); end loop;
end $$;
select pg_temp.expect(pg_temp.state_of($q$select public.team_access_begin('00000000-0000-0000-0000-00000000154a')$q$) = 'P0001', '11ª tentativa no dia: recusada');
select pg_temp.expect(public.team_grant_access('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001547', 'Outra', null, '00000000-0000-0000-0000-0000000154e2') ->> 'user_id'
  = '00000000-0000-0000-0000-000000001547', 'dona dá qualquer perfil do estúdio');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000001545');
select public.team_access_begin('00000000-0000-0000-0000-00000000154b');
select pg_temp.logout();
select pg_temp.expect((select count(*) from public.audit_logs where operation = 'ACCESS_CREATE_STARTED' and org_id = '00000000-0000-0000-0000-00000000154b') = 1, 'limite é por estúdio');

-- ─── Proprietária protegida e perfil do acesso íntegro ──────────────────────────────────────────────
select pg_temp.expect(pg_temp.state_of($q$update public.user_roles set active = false where user_id = '00000000-0000-0000-0000-000000001540' and org_id = '00000000-0000-0000-0000-00000000154a'$q$) = '23514', 'última proprietária não sai');
select pg_temp.expect(pg_temp.state_of($q$update public.user_roles set profile_id = '00000000-0000-0000-0000-0000000154e9' where user_id = '00000000-0000-0000-0000-000000001544' and org_id = '00000000-0000-0000-0000-00000000154a'$q$) = '23514', 'perfil de outro estúdio recusado (mesmo sem a API)');
select pg_temp.expect(pg_temp.state_of($q$update public.user_roles set profile_id = '00000000-0000-0000-0000-0000000154e1' where user_id = '00000000-0000-0000-0000-000000001544' and org_id = '00000000-0000-0000-0000-00000000154a'$q$) = '23514', 'perfil de outro papel-base recusado');
-- Gravação direta pela API: fechada para todos (só pelas funções).
select pg_temp.login('00000000-0000-0000-0000-000000001540');
select pg_temp.expect(pg_temp.state_of($q$insert into public.user_roles (user_id, org_id, role) values ('00000000-0000-0000-0000-000000001547', '00000000-0000-0000-0000-00000000154a', 'viewer')$q$) = '42501', 'dona não grava user_roles direto');
select pg_temp.expect(pg_temp.state_of($q$update public.user_roles set role = 'viewer' where user_id = '00000000-0000-0000-0000-000000001543'$q$) = '42501', 'dona não altera user_roles direto');
select pg_temp.expect(pg_temp.state_of($q$delete from public.user_roles where user_id = '00000000-0000-0000-0000-000000001543'$q$) = '42501', 'dona não apaga user_roles direto');
select pg_temp.expect(pg_temp.state_of($q$update public.organizations set settings = '{}' where id = '00000000-0000-0000-0000-00000000154a'$q$) = '42501', 'dona não regrava settings direto');
select pg_temp.expect(pg_temp.state_of($q$update public.organizations set name = 'Direto' where id = '00000000-0000-0000-0000-00000000154a'$q$) = '42501', 'dona não altera o estúdio direto');
select pg_temp.expect(pg_temp.state_of($q$insert into public.organizations (slug, name) values ('x154', 'X')$q$) = '42501', 'ninguém cria estúdio pela API');
select pg_temp.logout();

-- ─── Liberações: tudo do Salvar numa transação ──────────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001540');
select pg_temp.expect(public.access_apply_changes('00000000-0000-0000-0000-00000000154a', '[
  {"role": "viewer", "permission": "catalogo.manage", "allowed": true},
  {"role": "viewer", "permission": "catalogo.view", "allowed": true},
  {"profile_id": "00000000-0000-0000-0000-0000000154e1", "permission": "catalogo.manage", "allowed": false}
]') = 2, 'duas mudanças (a que já valia é pulada)');
select pg_temp.expect(pg_temp.audits('ROLE_PERMISSION_SET') = 1 and pg_temp.audits('PROFILE_PERMISSION_SET') = 1, 'cada mudança auditada, a pulada não');
select pg_temp.expect(pg_temp.state_of($q$select public.access_apply_changes('00000000-0000-0000-0000-00000000154a', '[
  {"role": "viewer", "permission": "financeiro.view", "allowed": true},
  {"role": "owner", "permission": "catalogo.manage", "allowed": false}]')$q$) = '22023', 'troca inválida recusa o lote');
select pg_temp.logout();
select pg_temp.expect(not exists (select 1 from public.org_role_permissions where org_id = '00000000-0000-0000-0000-00000000154a' and permission = 'financeiro.view'), 'tudo-ou-nada: nada do lote recusado ficou');
select pg_temp.login('00000000-0000-0000-0000-000000001541');
select pg_temp.expect(pg_temp.state_of($q$select public.access_apply_changes('00000000-0000-0000-0000-00000000154a', '[{"role": "receptionist", "permission": "acesso.manage", "allowed": true}]')$q$) = '42501', 'administração não dá acesso.manage (só a dona)');
select pg_temp.expect(pg_temp.state_of($q$select public.access_apply_changes('00000000-0000-0000-0000-00000000154a', '[{"role": "admin", "permission": "catalogo.manage", "allowed": false}]')$q$) = '42501', 'administração não mexe no próprio papel');
-- Já ligada para o papel: a administração reenvia sem esbarrar na regra de "dar o que não tem" (pulada).
select pg_temp.expect(public.access_apply_changes('00000000-0000-0000-0000-00000000154a', '[{"role": "viewer", "permission": "catalogo.manage", "allowed": true}]') = 0, 'troca que já vale: pulada');
select pg_temp.logout();

-- ─── ajustes.manage dado pela dona à gerência agora vale (antes a tabela só aceitava owner/admin) ─────
select pg_temp.login('00000000-0000-0000-0000-000000001542');
select public.settings_update_studio('00000000-0000-0000-0000-00000000154a', 'Estúdio da Gerência', '', '', '', '', 'Europe/Madrid', 'EUR', '', '', '', '', '', '');
select pg_temp.expect(public.settings_save_payment_account('00000000-0000-0000-0000-00000000154a', null, 'bizum', 'Gerência', '+34611111154', '', '') is not null, 'gerência com ajustes.manage cria conta de recebimento');
select public.set_org_settings('00000000-0000-0000-0000-00000000154a', '{"payment_methods": ["CASH"]}');
select pg_temp.logout();
select pg_temp.expect((select name from public.organizations where id = '00000000-0000-0000-0000-00000000154a') = 'Estúdio da Gerência', 'gerência com ajustes.manage salva o estúdio');
select pg_temp.login('00000000-0000-0000-0000-000000001548');
select pg_temp.expect(pg_temp.state_of($q$select public.settings_save_payment_account('00000000-0000-0000-0000-00000000154a', null, 'bizum', 'Golpe', '+34611111155', '', '')$q$) = '42501', 'financeiro sem ajustes.manage não cria conta');
select pg_temp.expect(pg_temp.state_of($q$insert into public.payment_accounts (org_id, kind, holder_name, identifier) values ('00000000-0000-0000-0000-00000000154a', 'bizum', 'Golpe', '+34611111156')$q$) = '42501', 'financeiro sem ajustes.manage não grava conta direto');
select pg_temp.expect(pg_temp.state_of($q$select public.set_org_settings('00000000-0000-0000-0000-00000000154a', '{"payment_methods": ["CASH"]}')$q$) = '42501', 'financeiro sem ajustes.manage não muda settings');
select pg_temp.logout();

-- ─── Estúdio, atendimento, ficha e pagamentos ───────────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001541');
select public.settings_update_studio('00000000-0000-0000-0000-00000000154a', 'Estúdio Novo', '+34 600', 'hola@a.es', 'Rua 1', 'Madrid',
  'Europe/Lisbon', 'EUR', 'Razão', 'X1234567L', '28001', 'Obrigada', 'Sinal 20%', '');
select pg_temp.expect(pg_temp.state_of($q$select public.settings_update_studio('00000000-0000-0000-0000-00000000154a', 'Estúdio', '', '', '', '', 'Marte/Base', 'EUR', '', '', '', '', '', '')$q$) = '22023', 'fuso inexistente: recusado');
select pg_temp.expect(pg_temp.state_of($q$select public.settings_update_studio('00000000-0000-0000-0000-00000000154a', 'E', '', '', '', '', 'Europe/Madrid', 'EUR', '', '', '', '', '', '')$q$) = '22023', 'nome curto: recusado');
select public.settings_save_attendance('00000000-0000-0000-0000-00000000154a', '{"tip_mode": "off", "labels": {"chegou": "Na casa"}}', true, false);
select pg_temp.expect(pg_temp.state_of($q$select public.settings_save_attendance('00000000-0000-0000-0000-00000000154a', '{}', true, null)$q$) = '22023', 'trava pela metade: recusada');
select public.settings_save_ficha('00000000-0000-0000-0000-00000000154a', 30, false, null, null);
select pg_temp.expect(pg_temp.state_of($q$select public.settings_save_ficha('00000000-0000-0000-0000-00000000154a', null, null, null, null)$q$) = '22023', 'ficha sem nada: recusada');
select public.settings_save_payments('00000000-0000-0000-0000-00000000154a', '["CASH", "BIZUM"]', '{"expires_hours": 48, "guidance": "Pague já"}',
  '[{"id": "00000000-0000-0000-0000-0000000154c1", "active": false}]');
select pg_temp.expect(pg_temp.state_of($q$select public.settings_save_payments('00000000-0000-0000-0000-00000000154a', '[]', null, null)$q$) = '22023', 'nenhuma forma de pagamento: recusado');
select pg_temp.expect(pg_temp.state_of($q$select public.settings_save_payments('00000000-0000-0000-0000-00000000154a', '["PIX_FALSO"]', null, null)$q$) = '22023', 'forma desconhecida: recusada');
select pg_temp.expect(pg_temp.state_of($q$select public.settings_save_payments('00000000-0000-0000-0000-00000000154a', '["CASH"]', '{"expires_hours": 999}', null)$q$) = '22023', 'validade fora do limite: recusada (e nada gravado)');
create temp table t_acc on commit drop as select public.settings_save_payment_account('00000000-0000-0000-0000-00000000154a', null, 'sepa', 'Estúdio A', 'ES9121000418450200051332', 'CAIXESBBXXX', 'CaixaBank') as id;
grant select on t_acc to authenticated;
select public.settings_save_payment_account('00000000-0000-0000-0000-00000000154a', (select id from t_acc), 'sepa', 'Estúdio A SL', 'ES9121000418450200051332', '', '');
select pg_temp.expect(pg_temp.state_of($q$select public.settings_save_payment_account('00000000-0000-0000-0000-00000000154a', null, 'sepa', 'A', 'ES91', '', '')$q$) = '23514', 'titular curto: CHECK da tabela');
select pg_temp.logout();
select pg_temp.expect((select name = 'Estúdio Novo' and timezone = 'Europe/Lisbon' and settings -> 'business' ->> 'tax_id' = 'X1234567L'
  and settings -> 'policies' ->> 'deposit' = 'Sinal 20%' and settings -> 'payment_methods' = '["CASH", "BIZUM"]'::jsonb
  and settings -> 'payment_request' ->> 'expires_hours' = '48' and settings -> 'attendance' ->> 'tip_mode' = 'off'
  and settings -> 'anamnese' -> 'gate' ->> 'start' = 'true' and (settings -> 'anamnese' ->> 'link_days')::int = 30
  from public.organizations where id = '00000000-0000-0000-0000-00000000154a'), 'estúdio, atendimento, ficha e pagamentos gravados juntos');
select pg_temp.expect(not (select active from public.payment_accounts where id = '00000000-0000-0000-0000-0000000154c1'), 'conta desligada');
select pg_temp.expect(pg_temp.audits('ORG_UPDATED') >= 1, 'mudança do estúdio auditada');
select pg_temp.expect((select bool_and(not (new_data ? 'settings') and (new_data -> 'settings_keys') is not null or new_data ? 'name')
  from public.audit_logs where operation = 'ORG_UPDATED' and org_id = '00000000-0000-0000-0000-00000000154a'), 'auditoria do estúdio: chaves de settings sem os valores');
select pg_temp.expect((select new_data ->> 'timezone' from public.audit_logs where operation = 'ORG_UPDATED' and org_id = '00000000-0000-0000-0000-00000000154a' and new_data ? 'timezone') = 'Europe/Lisbon', 'auditoria do estúdio: coluna que mudou');
select pg_temp.expect((select new_data -> 'changed' @> '["phone", "email", "address"]'::jsonb and new_data::text not like '%hola@a.es%'
  and new_data::text not like '%Rua 1%' and coalesce(old_data::text, '') not like '%hola@a.es%'
  from public.audit_logs where operation = 'ORG_UPDATED' and org_id = '00000000-0000-0000-0000-00000000154a' and new_data ? 'changed'), 'auditoria do estúdio: telefone, e-mail e endereço só pelo nome do campo');
select pg_temp.expect(pg_temp.audits('PAYMENT_ACCOUNT_CREATED') = 3 and pg_temp.audits('PAYMENT_ACCOUNT_UPDATED') = 2, 'contas: criadas (inclusive a do cenário e a da gerência), editada e desligada auditadas');
select pg_temp.expect(not exists (select 1 from public.audit_logs where table_name = 'payment_accounts' and org_id = '00000000-0000-0000-0000-00000000154a'
  and (new_data::text like '%ES9121000418450200051332%' or new_data::text like '%Estúdio A%')), 'auditoria da conta sem o IBAN inteiro nem o titular');
select pg_temp.expect((select new_data ->> 'identifier_end' from public.audit_logs where operation = 'PAYMENT_ACCOUNT_CREATED' and org_id = '00000000-0000-0000-0000-00000000154a' and new_data ->> 'kind' = 'sepa') = '1332', 'auditoria da conta: só o final');

-- ─── Equipe ──────────────────────────────────────────────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001542');
create temp table t_staff on commit drop as select public.team_save_staff('00000000-0000-0000-0000-00000000154a', null, ' Nova Pro ', '', '', 'pro@a.es', '', null, '#112233', 40, true, true,
  '[{"active":false,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":false,"start":"09:00","end":"14:00"}]') as id;
grant select on t_staff to authenticated;
select public.team_save_staff('00000000-0000-0000-0000-00000000154a', (select id from t_staff), 'Nova Pro', 'Nova', 'Esteticista', 'pro2@a.es', '', '00000000-0000-0000-0000-000000001543', '#112233', 45, true, true,
  '[{"active":false,"start":"09:00","end":"18:00"},{"active":true,"start":"10:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":false,"start":"09:00","end":"14:00"}]');
select pg_temp.expect(pg_temp.state_of($q$select public.team_save_staff('00000000-0000-0000-0000-00000000154a', null, 'X', '', '', '', '', '00000000-0000-0000-0000-000000001545', '#112233', 0, true, true, '[{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"}]')$q$) = '22023', 'conta de outro estúdio não liga');
select pg_temp.expect(pg_temp.state_of($q$select public.team_save_staff('00000000-0000-0000-0000-00000000154a', null, 'X', '', '', '', '', null, '#112233', 0, true, true, '[{"active":true,"start":"9h","end":"18:00"}]')$q$) = '22023', 'turnos inválidos: recusado');
select pg_temp.expect(pg_temp.state_of($q$select public.team_save_staff('00000000-0000-0000-0000-00000000154a', null, 'X', '', '', '', '', null, '#112233', 0, true, true, '[{"active":true,"start":"18:00","end":"09:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"}]')$q$) = '22023', 'turno ativo com fim antes do início: recusado');
select pg_temp.expect(pg_temp.state_of($q$select public.team_save_staff('00000000-0000-0000-0000-00000000154a', null, 'X', '', '', '', '', null, 'vermelho', 0, true, true, '[{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"},{"active":true,"start":"09:00","end":"18:00"}]')$q$) = '23514', 'cor inválida: CHECK da tabela');
select public.team_set_staff_flags('00000000-0000-0000-0000-00000000154a', (select id from t_staff), false, null, null);
select pg_temp.logout();
select pg_temp.expect((select name = 'Nova Pro' and display_name = 'Nova' and commission_pct = 45 and not active and role = 'Esteticista'
  and user_id = '00000000-0000-0000-0000-000000001543' from public.staff_members where id = (select id from t_staff)), 'profissional salva, editada e desativada');
select pg_temp.expect((select count(*) from public.staff_shifts where staff_id = (select id from t_staff)) = 7
  and (select start_time from public.staff_shifts where staff_id = (select id from t_staff) and day_of_week = 1) = '10:00', 'sete turnos, editados no lugar');
select pg_temp.expect(pg_temp.audits('STAFF_CREATED') = 2 and pg_temp.audits('STAFF_UPDATED') = 2, 'equipe auditada (inclusive a do cenário)');
select pg_temp.expect(pg_temp.state_of($q$update public.staff_shifts set end_time = '08:00' where staff_id = '00000000-0000-0000-0000-0000000154a1' and day_of_week = 1$q$) = '23514', 'CHECK: turno ativo com fim antes do início');
select pg_temp.expect((select new_data -> 'changed' = '["display_name", "email"]'::jsonb and not (new_data::text like '%pro2@a.es%')
  from public.audit_logs where operation = 'STAFF_UPDATED' and org_id = '00000000-0000-0000-0000-00000000154a' and new_data ? 'user_id'), 'auditoria da equipe: conta ligada e campos pessoais só pelo nome');

-- ─── Auditoria não forjável pela API ────────────────────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001540');
select pg_temp.expect(pg_temp.state_of($q$insert into public.audit_logs (org_id, user_id, table_name, operation) values ('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001540', 'organizations', 'ORG_UPDATED')$q$) = '42501', 'ORG_UPDATED à mão: recusado');
select pg_temp.expect(pg_temp.state_of($q$insert into public.audit_logs (org_id, user_id, table_name, operation) values ('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001540', 'user_roles', 'ACCESS_CREATED')$q$) = '42501', 'ACCESS_CREATED à mão: recusado');
select pg_temp.expect(pg_temp.state_of($q$insert into public.audit_logs (org_id, user_id, table_name, operation) values ('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001540', 'staff_members', 'STAFF_UPDATED')$q$) = '42501', 'STAFF_UPDATED à mão: recusado');
select pg_temp.expect(pg_temp.state_of($q$insert into public.audit_logs (org_id, user_id, table_name, operation) values ('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001540', 'payment_accounts', 'PAYMENT_ACCOUNT_UPDATED')$q$) = '42501', 'PAYMENT_ACCOUNT_UPDATED à mão: recusado');
select pg_temp.expect(pg_temp.state_of($q$insert into public.audit_logs (org_id, user_id, table_name, operation) values ('00000000-0000-0000-0000-00000000154a', '00000000-0000-0000-0000-000000001540', 'user_roles', 'ACCESS_CREATE_STARTED')$q$) = '42501', 'ACCESS_CREATE_STARTED à mão: recusado');
select pg_temp.expect(pg_temp.state_of($q$select public.ajustes_audit_org()$q$) = '42501', 'gatilho de auditoria não é chamável');
select pg_temp.expect(pg_temp.state_of($q$select public.access_assert_can_grant('00000000-0000-0000-0000-00000000154a', 'owner', 'admin', null)$q$) = '42501', 'ajudante de escalada não é chamável');
select pg_temp.logout();

-- Apagar o estúdio inteiro (cascata) não quebra por causa dos gatilhos.
select pg_temp.expect(pg_temp.state_of($q$delete from public.organizations where id = '00000000-0000-0000-0000-00000000154b'$q$) = 'ok', 'apagar estúdio em cascata: sem erro de auditoria');

rollback;
\o
\echo 'ajustes: telas e ações em uma ida, permissões e auditoria (154): ok'
