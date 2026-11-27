-- O2: client_profile, restore_entitlement_session_atomic e update_client_atomic.
-- Isolamento: quem é do estúdio B não lê nem grava nada do A. Anônimo não executa. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000e20', 'dona@o2.local'),
  ('00000000-0000-0000-0000-000000000e21', 'recep@o2.local'),
  ('00000000-0000-0000-0000-000000000e22', 'donab@o2.local'),
  ('00000000-0000-0000-0000-000000000e23', 'fin@o2.local'),
  ('00000000-0000-0000-0000-000000000e24', 'prof@o2.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-000000000e2a', 'o2-a', 'Estúdio O2 A'),
  ('00000000-0000-0000-0000-000000000e2b', 'o2-b', 'Estúdio O2 B');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000000e20', '00000000-0000-0000-0000-000000000e2a', 'owner'),
  ('00000000-0000-0000-0000-000000000e21', '00000000-0000-0000-0000-000000000e2a', 'receptionist'),
  ('00000000-0000-0000-0000-000000000e22', '00000000-0000-0000-0000-000000000e2b', 'owner'),
  ('00000000-0000-0000-0000-000000000e23', '00000000-0000-0000-0000-000000000e2a', 'finance'),
  ('00000000-0000-0000-0000-000000000e24', '00000000-0000-0000-0000-000000000e2a', 'professional');
-- Profissional com clientes.manage liberado pela dona (mas fora da política de consentimento de marketing).
insert into public.org_role_permissions (org_id, role, permission, allowed) values
  ('00000000-0000-0000-0000-000000000e2a', 'professional', 'clientes.manage', true);
insert into public.profiles (user_id, org_id, full_name) values
  ('00000000-0000-0000-0000-000000000e20', '00000000-0000-0000-0000-000000000e2a', 'Dona Ana')
on conflict (user_id, org_id) do update set full_name = excluded.full_name;

insert into public.clients (id, org_id, full_name, phone, phone_country_code, status, tags, email, city) values
  ('00000000-0000-0000-0000-000000000ec1', '00000000-0000-0000-0000-000000000e2a', 'Cliente A', '+34 600 123', '+34', 'Ativo', '{VIP}', 'a@o2.local', 'Lisboa'),
  ('00000000-0000-0000-0000-000000000ec9', '00000000-0000-0000-0000-000000000e2b', 'Cliente B', '+351 912 345 678', '+351', 'Ativo', '{}', null, null);
insert into public.client_entitlements (id, org_id, client_id, package_name, total_sessions, used_sessions, status) values
  ('00000000-0000-0000-0000-000000000ee1', '00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1', 'Pacote A', 4, 1, 'active'),
  ('00000000-0000-0000-0000-000000000ee2', '00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1', 'Pacote A zerado', 4, 0, 'active'),
  ('00000000-0000-0000-0000-000000000ee3', '00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1', 'Pacote A cancelado', 4, 2, 'cancelled'),
  ('00000000-0000-0000-0000-000000000ee4', '00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1', 'Pacote A vencido', 4, 2, 'expired'),
  ('00000000-0000-0000-0000-000000000ee5', '00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1', 'Pacote A esgotado', 4, 4, 'exhausted'),
  ('00000000-0000-0000-0000-000000000ee9', '00000000-0000-0000-0000-000000000e2b', '00000000-0000-0000-0000-000000000ec9', 'Pacote B', 4, 2, 'active');
insert into public.client_notes (org_id, client_id, content, note_type) values
  ('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1', 'Nota A', 'client'),
  ('00000000-0000-0000-0000-000000000e2b', '00000000-0000-0000-0000-000000000ec9', 'Nota B', 'client');
-- Marketing só para quem disse SIM (20261114110000): a guarda da fila pede aceite registrado (o aceite sai logo depois: a cliente fica sem preferência).
insert into public.client_marketing_preferences (org_id, client_id, channel, marketing_allowed) values
  ('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1', 'whatsapp_manual', true);
insert into public.marketing_message_queue (org_id, client_id, channel, recipient, message_body, status) values
  ('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1', 'whatsapp_manual', '+34 600 123', 'Olá A', 'draft');
delete from public.client_marketing_preferences where client_id = '00000000-0000-0000-0000-000000000ec1';
insert into public.services (org_id, name, retouch_included_days) values
  ('00000000-0000-0000-0000-000000000e2a', 'Sobrancelha fio a fio', 30),
  ('00000000-0000-0000-0000-000000000e2a', 'Sem retoque', null),
  ('00000000-0000-0000-0000-000000000e2b', 'Retoque B', 45);
insert into public.appointments (id, org_id, client_id, client_name, start_at, end_at, duration_minutes, status) values
  ('00000000-0000-0000-0000-000000000ea1', '00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1',
   'Cliente A', '2031-05-06 10:30+00', '2031-05-06 11:30+00', 60, 'Agendado'),
  ('00000000-0000-0000-0000-000000000ea2', '00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1',
   'Cliente A', '2030-05-06 10:30+00', '2030-05-06 11:30+00', 60, 'Agendado'),
  ('00000000-0000-0000-0000-000000000ea9', '00000000-0000-0000-0000-000000000e2b', '00000000-0000-0000-0000-000000000ec9',
   'Cliente B', '2031-05-06 10:30+00', '2031-05-06 11:30+00', 60, 'Agendado');
-- Atendimento pago, itens, extrato e ficha com fotos: pula os gatilhos só para montar o cenário (desfeito no rollback).
set local session_replication_role = replica;
update public.appointments set status = 'Pago', start_at = '2020-05-06 10:30+00', end_at = '2020-05-06 11:30+00'
where id = '00000000-0000-0000-0000-000000000ea2';
insert into public.appointment_items (org_id, appointment_id, type, name, price, qty) values
  ('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ea1', 'service', 'Sobrancelha', 50, 1),
  ('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ea2', 'service', 'Lábios', 120, 1),
  ('00000000-0000-0000-0000-000000000e2b', '00000000-0000-0000-0000-000000000ea9', 'service', 'Serviço B', 80, 1);
insert into public.client_balance_entries (org_id, client_id, entry_type, amount, balance_before, balance_after, source_type, created_by) values
  ('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1', 'credit', 10, 0, 10, 'manual', '00000000-0000-0000-0000-000000000e20'),
  ('00000000-0000-0000-0000-000000000e2b', '00000000-0000-0000-0000-000000000ec9', 'credit', 5, 0, 5, 'manual', '00000000-0000-0000-0000-000000000e22');
-- Fotos: duas desta ficha e uma com caminho de outra ficha (não conta: só <estúdio>/<ficha>/...).
insert into public.anamneses (id, org_id, client_id, template_title, status, token_hash, professional_data) values
  ('00000000-0000-0000-0000-000000000ef1', '00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1', 'Ficha com fotos', 'signed', encode(extensions.digest('tok-o2-a1', 'sha256'), 'hex'),
   '{"photos": ["00000000-0000-0000-0000-000000000e2a/00000000-0000-0000-0000-000000000ef1/11111111-1111-4111-8111-111111111111.jpg",
                "00000000-0000-0000-0000-000000000e2a/00000000-0000-0000-0000-000000000ef1/22222222-2222-4222-8222-222222222222.jpg",
                "00000000-0000-0000-0000-000000000e2a/00000000-0000-0000-0000-000000000ef9/33333333-3333-4333-8333-333333333333.jpg"],
     "observacao_clinica": "não pode sair"}'),
  (gen_random_uuid(), '00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1', 'Ficha sem fotos', 'pending', encode(extensions.digest('tok-o2-a2', 'sha256'), 'hex'), '{}'),
  (gen_random_uuid(), '00000000-0000-0000-0000-000000000e2b', '00000000-0000-0000-0000-000000000ec9', 'Ficha B', 'signed', encode(extensions.digest('tok-o2-b1', 'sha256'), 'hex'),
   '{"photos": ["00000000-0000-0000-0000-000000000e2b/b.jpg"]}');
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
create function pg_temp.logout() returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);
end $$;
create function pg_temp.profile(p_org uuid, p_client uuid, p_photos boolean default true) returns jsonb language sql as $$
  select public.client_profile(p_org, p_client, array['Concluído','Concluido','Pago Parcial','Pago'], p_photos)
$$;
grant execute on function pg_temp.expect(boolean, text), pg_temp.state_of(text), pg_temp.login(uuid), pg_temp.logout(),
  pg_temp.profile(uuid, uuid, boolean) to anon, authenticated;

-- ─── client_profile: dona do estúdio A ───────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000000e20');
create temp table p_a on commit drop as
  select pg_temp.profile('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1') as p;
select pg_temp.expect((select p -> 'client' ->> 'full_name' from p_a) = 'Cliente A', 'cliente');
select pg_temp.expect((select p -> 'client' -> 'marketing_state' from p_a) = '{"whatsapp": "none", "email": "none"}'::jsonb, 'cliente sem preferência de marketing: sem autorização nos dois meios');
select pg_temp.expect((select p -> 'client' -> 'tags' from p_a) = '["VIP"]'::jsonb, 'cliente com todas as colunas (tags)');
select pg_temp.expect((select pg_catalog.jsonb_array_length(p -> 'appointments') from p_a) = 2, 'agendamentos da cliente');
select pg_temp.expect((select p -> 'appointments' -> 0 ->> 'id' from p_a) = '00000000-0000-0000-0000-000000000ea1', 'agendamentos do mais novo para o mais antigo');
select pg_temp.expect((select p -> 'appointments' -> 0 -> 'appointment_items' -> 0 ->> 'name' from p_a) = 'Sobrancelha', 'serviços do agendamento');
select pg_temp.expect((select (p ->> 'appointment_count')::int from p_a) = 2, 'total de agendamentos');
select pg_temp.expect((select (p ->> 'visits')::int from p_a) = 1, 'visitas concluídas');
select pg_temp.expect((select pg_catalog.jsonb_array_length(p -> 'ledger') from p_a) = 1, 'extrato de saldo');
select pg_temp.expect((select p -> 'ledger' -> 0 ->> 'created_by_name' from p_a) = 'Dona Ana', 'extrato com o nome de quem lançou');
select pg_temp.expect((select (p -> 'ledger' -> 0 ->> 'amount')::numeric from p_a) = 10, 'extrato com o valor');
select pg_temp.expect((select p -> 'notes' -> 0 ->> 'content' from p_a) = 'Nota A', 'notas');
select pg_temp.expect((select pg_catalog.jsonb_array_length(p -> 'credits') from p_a) = 5, 'pacotes');
select pg_temp.expect((select pg_catalog.jsonb_array_length(p -> 'anamneses') from p_a) = 2, 'status das fichas');
select pg_temp.expect((select pg_catalog.array_agg(k order by k) from p_a, pg_catalog.jsonb_array_elements(p -> 'anamneses') e,
  pg_catalog.jsonb_object_keys(e) k) = array['created_at', 'created_at', 'id', 'id', 'signed_at', 'signed_at', 'status', 'status', 'template_title', 'template_title'],
  'status das fichas: só id, título, situação e datas (sem token público nem respostas)');
select pg_temp.expect((select (p ->> 'photo_count')::int from p_a) = 2, 'número de fotos (só caminhos da própria ficha)');
select pg_temp.expect((select not (p ? 'photo_sources') from p_a), 'o perfil não traz caminho de foto nem dado da ficha');
select pg_temp.expect((select (p ->> 'message_count')::int from p_a) = 1, 'contagem de mensagens');
select pg_temp.expect((select p -> 'messages' -> 0 ->> 'message_body' from p_a) = 'Olá A', 'mensagens');
select pg_temp.expect((select p -> 'retouch_rules' from p_a) = (select pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
  'id', s.id, 'name', 'Sobrancelha fio a fio', 'retouch_included_days', 30)) from public.services s where s.name = 'Sobrancelha fio a fio'),
  'só serviços do estúdio com retoque');
select pg_temp.expect((pg_temp.profile('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1', false) ->> 'photo_count')::int = 0,
  'sem pedir fotos: nada das fichas');

-- isolamento: cliente do B pelo id do A, do B pelo id do B, id do A com estúdio trocado
select pg_temp.expect(pg_temp.profile('00000000-0000-0000-0000-000000000e2b', '00000000-0000-0000-0000-000000000ec9') is null, 'dona A não lê cliente do B');
select pg_temp.expect(pg_temp.profile('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec9') is null, 'cliente do B com o estúdio do A: nulo');
select pg_temp.expect(pg_temp.profile('00000000-0000-0000-0000-000000000e2b', '00000000-0000-0000-0000-000000000ec1') is null, 'cliente do A com o estúdio do B: nulo');

-- ─── client_profile: recepção (sem acesso clínico) ───────────
select pg_temp.login('00000000-0000-0000-0000-000000000e21');
select pg_temp.expect((pg_temp.profile('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1') ->> 'photo_count')::int = 0,
  'recepção pedindo fotos: sem leitura clínica, zero');
select pg_temp.expect(pg_catalog.jsonb_array_length(pg_temp.profile('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1') -> 'anamneses') = 2,
  'recepção vê o status das fichas');

-- ─── client_profile: financeiro (sem anamnese.view_status) ───
select pg_temp.login('00000000-0000-0000-0000-000000000e23');
select pg_temp.expect(pg_temp.state_of($q$select pg_temp.profile('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1')$q$) = 'ok',
  'financeiro abre o perfil sem erro');
select pg_temp.expect(coalesce(pg_catalog.jsonb_array_length(pg_temp.profile('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1') -> 'anamneses'), 0) = 0,
  'financeiro: cartão de fichas vazio');

-- ─── client_profile: sem clientes.view ───────────────────────
select pg_temp.logout();
insert into public.org_role_permissions (org_id, role, permission, allowed) values
  ('00000000-0000-0000-0000-000000000e2a', 'finance', 'clientes.view', false);
select pg_temp.login('00000000-0000-0000-0000-000000000e23');
select pg_temp.expect(pg_temp.profile('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1') is null, 'sem clientes.view: nulo');
select pg_temp.logout();
delete from public.org_role_permissions where role = 'finance' and permission = 'clientes.view'
  and org_id = '00000000-0000-0000-0000-000000000e2a';

-- ─── client_profile: dona do B ───────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000000e22');
select pg_temp.expect(pg_temp.profile('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1') is null, 'dona B não lê cliente do A');
select pg_temp.expect((pg_temp.profile('00000000-0000-0000-0000-000000000e2b', '00000000-0000-0000-0000-000000000ec9') -> 'ledger' -> 0 ->> 'created_by_name') is null,
  'dona B: o próprio perfil abre (sem nome cadastrado no extrato)');

-- ─── restore_entitlement_session_atomic ──────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000000e20');
select pg_temp.expect((public.restore_entitlement_session_atomic('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ee1', 'Devolvida') ->> 'used_sessions')::int = 0,
  'devolve uma sessão');
select pg_temp.logout();
select pg_temp.expect((select used_sessions from public.client_entitlements where id = '00000000-0000-0000-0000-000000000ee1') = 0, 'pacote com uma sessão usada a menos');
select pg_temp.expect((select count(*) from public.client_entitlement_entries where entitlement_id = '00000000-0000-0000-0000-000000000ee1'
  and action = 'restore' and created_by = '00000000-0000-0000-0000-000000000e20' and description = 'Devolvida') = 1, 'extrato com quem devolveu');
select pg_temp.login('00000000-0000-0000-0000-000000000e20');
select pg_temp.expect(pg_temp.state_of($q$select public.restore_entitlement_session_atomic('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ee2', '')$q$) = 'P0001',
  'sem sessão usada: recusa');
select pg_temp.expect(pg_temp.state_of($q$select public.restore_entitlement_session_atomic('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ee3', '')$q$) = 'P0001',
  'pacote cancelado: recusa');
select pg_temp.expect(pg_temp.state_of($q$select public.restore_entitlement_session_atomic('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ee4', '')$q$) = 'P0001',
  'pacote vencido: recusa');
select pg_temp.expect(pg_temp.state_of($q$select public.restore_entitlement_session_atomic('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ee1', repeat('x', 201))$q$) = '22023',
  'descrição acima de 200 caracteres: recusa');
select pg_temp.expect((public.restore_entitlement_session_atomic('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ee5', '  ') ->> 'used_sessions')::int = 3,
  'pacote esgotado: devolve');
select pg_temp.expect(pg_temp.state_of($q$select public.restore_entitlement_session_atomic('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ee9', '')$q$) = 'P0002',
  'pacote do B pelo estúdio do A: não encontrado');
select pg_temp.expect(pg_temp.state_of($q$select public.restore_entitlement_session_atomic('00000000-0000-0000-0000-000000000e2b', '00000000-0000-0000-0000-000000000ee9', '')$q$) = '42501',
  'dona A no estúdio B: sem permissão');
select pg_temp.login('00000000-0000-0000-0000-000000000e22');
select pg_temp.expect(pg_temp.state_of($q$select public.restore_entitlement_session_atomic('00000000-0000-0000-0000-000000000e2b', '00000000-0000-0000-0000-000000000ee1', '')$q$) = 'P0002',
  'dona B não mexe em pacote do A');
select pg_temp.logout();
select pg_temp.expect((select count(*) from public.client_entitlement_entries where entitlement_id in (
  '00000000-0000-0000-0000-000000000ee2', '00000000-0000-0000-0000-000000000ee9')) = 0, 'recusas não gravaram extrato');
select pg_temp.expect((select used_sessions from public.client_entitlements where id = '00000000-0000-0000-0000-000000000ee9') = 2, 'pacote do B intacto');
select pg_temp.expect((select status = 'cancelled' and used_sessions = 2 from public.client_entitlements where id = '00000000-0000-0000-0000-000000000ee3'), 'cancelado intacto');
select pg_temp.expect((select status = 'active' and used_sessions = 3 from public.client_entitlements where id = '00000000-0000-0000-0000-000000000ee5'), 'esgotado volta a ativo');
select pg_temp.expect((select description is null from public.client_entitlement_entries where entitlement_id = '00000000-0000-0000-0000-000000000ee5'), 'descrição só com espaços vira nula');
select pg_temp.expect((select count(*) from public.audit_logs where table_name = 'client_entitlements' and operation = 'ENTITLEMENT_SESSION_RESTORED'
  and user_id = '00000000-0000-0000-0000-000000000e20' and record_id in ('00000000-0000-0000-0000-000000000ee1', '00000000-0000-0000-0000-000000000ee5')) = 2,
  'auditoria das duas devoluções');
select pg_temp.expect((select count(*) from public.audit_logs where operation = 'ENTITLEMENT_SESSION_RESTORED'
  and record_id in ('00000000-0000-0000-0000-000000000ee2', '00000000-0000-0000-0000-000000000ee3', '00000000-0000-0000-0000-000000000ee4', '00000000-0000-0000-0000-000000000ee9')) = 0,
  'recusas sem auditoria');

-- ─── update_client_atomic ────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000000e20');
-- mesmo telefone (o app manda já com o DDI) e sem telefone validado: mantém o texto guardado
select pg_temp.expect((public.update_client_atomic('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1',
  '{"full_name": "Cliente A Editada", "phone": "+34 600 123", "email": null, "tags": ["VIP", "Nova"], "org_id": "00000000-0000-0000-0000-000000000e2b", "balance": 999,
    "id": "00000000-0000-0000-0000-000000000ec9", "merged_into": "00000000-0000-0000-0000-000000000ec9"}',
  null, null, true, array['whatsapp_manual', 'email_provider']) ->> 'ok')::boolean, 'edita com o telefone guardado');
select pg_temp.logout();
select pg_temp.expect((select full_name = 'Cliente A Editada' and phone = '+34 600 123' and phone_country_code = '+34' and email is null
  and city = 'Lisboa' and tags = '{VIP,Nova}' and org_id = '00000000-0000-0000-0000-000000000e2a' and balance = 0
  from public.clients where id = '00000000-0000-0000-0000-000000000ec1'),
  'grava os campos enviados, mantém telefone, cidade (ausente), estúdio e saldo (fora da lista)');
select pg_temp.expect((select merged_into is null from public.clients where id = '00000000-0000-0000-0000-000000000ec1'), 'merged_into enviado é ignorado');
select pg_temp.expect((select full_name = 'Cliente B' from public.clients where id = '00000000-0000-0000-0000-000000000ec9'), 'id enviado é ignorado (cliente B intacta)');
select pg_temp.expect((select new_data = '{"columns": ["email", "full_name", "tags"]}'::jsonb and old_data is null
  from public.audit_logs where operation = 'CLIENT_UPDATED' and record_id = '00000000-0000-0000-0000-000000000ec1'
  and user_id = '00000000-0000-0000-0000-000000000e20'), 'auditoria só com os nomes das colunas alteradas');
select pg_temp.expect((select new_data from public.audit_logs where operation = 'MARKETING_CONSENT_SET' and record_id = '00000000-0000-0000-0000-000000000ec1')
  = '{"marketing_allowed": true, "channels": ["email_provider", "whatsapp_manual"]}'::jsonb, 'auditoria do consentimento');
select pg_temp.expect((select bool_and(updated_by = '00000000-0000-0000-0000-000000000e20' and opted_out_at is null)
  from public.client_marketing_preferences where client_id = '00000000-0000-0000-0000-000000000ec1'), 'consentimento com quem mudou');
select pg_temp.expect((select count(*) from public.client_marketing_preferences where client_id = '00000000-0000-0000-0000-000000000ec1' and marketing_allowed) = 2,
  'consentimento de marketing nos dois canais');
select pg_temp.login('00000000-0000-0000-0000-000000000e20');
-- mesmo número escrito com o DDI junto
select pg_temp.expect((public.update_client_atomic('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1',
  '{"phone": "+34600123"}', null, null) ->> 'ok')::boolean, 'mesmo número com DDI: aceito sem validação');
-- número novo sem validação do app: nada gravado
select pg_temp.expect((public.update_client_atomic('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1',
  '{"full_name": "Não grava", "phone": "+55 12345"}', null, null) ->> 'reason') = 'phone_invalid', 'número novo inválido: recusa');
-- número novo validado
select pg_temp.expect((public.update_client_atomic('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1',
  '{"phone": "11 91234-5678"}', '+55 11 91234 5678', '+55', false, array['whatsapp_manual', 'email_provider']) ->> 'ok')::boolean, 'número novo validado');
select pg_temp.logout();
select pg_temp.expect((select full_name = 'Cliente A Editada' and phone = '+55 11 91234 5678' and phone_country_code = '+55'
  from public.clients where id = '00000000-0000-0000-0000-000000000ec1'), 'recusa não gravou; validado gravou o número novo');
select pg_temp.expect((select count(*) from public.client_marketing_preferences where client_id = '00000000-0000-0000-0000-000000000ec1'
  and not marketing_allowed and opted_out_at is not null) = 2, 'consentimento retirado nos dois canais, com data de saída');
select pg_temp.expect((select count(*) from public.audit_logs where operation = 'CLIENT_UPDATED' and record_id = '00000000-0000-0000-0000-000000000ec1') = 2,
  'mesmo telefone sem outra mudança não gera auditoria; o número novo gera');
select pg_temp.expect(exists (select 1 from public.audit_logs where operation = 'CLIENT_UPDATED' and record_id = '00000000-0000-0000-0000-000000000ec1'
  and new_data = '{"columns": ["phone", "phone_country_code"]}'::jsonb), 'auditoria do telefone novo sem o número');
-- Atomicidade: o consentimento falha (canal fora da regra do banco) e os dados não ficam gravados.
select pg_temp.login('00000000-0000-0000-0000-000000000e20');
select pg_temp.expect(pg_temp.state_of($q$select public.update_client_atomic('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1',
  '{"full_name": "Não pode ficar", "phone": "+55 11 91234 5678"}', null, null, true, array['canal_inexistente'])$q$) = '23514',
  'consentimento inválido: erro');
-- Recusa clara: profissional com clientes.manage mas fora da política de consentimento.
select pg_temp.login('00000000-0000-0000-0000-000000000e24');
select pg_temp.expect((public.update_client_atomic('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1',
  '{"full_name": "Também não", "phone": "+55 11 91234 5678"}', null, null, true, array['whatsapp_manual']) ->> 'reason') = 'marketing_forbidden',
  'consentimento sem permissão: motivo claro, nada gravado');
select pg_temp.expect((public.update_client_atomic('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1',
  '{"city": "Porto", "phone": "+55 11 91234 5678"}', null, null, false, array['whatsapp_manual']) ->> 'ok')::boolean,
  'mesmo consentimento (sem mudança): profissional com clientes.manage salva');
select pg_temp.logout();
select pg_temp.expect((select full_name = 'Cliente A Editada' and city = 'Porto' from public.clients where id = '00000000-0000-0000-0000-000000000ec1'),
  'falhas não gravaram o nome; edição sem mudança de consentimento gravou');
select pg_temp.login('00000000-0000-0000-0000-000000000e20');
select pg_temp.expect(pg_temp.state_of($q$select public.update_client_atomic('00000000-0000-0000-0000-000000000e2b', '00000000-0000-0000-0000-000000000ec9',
  '{"full_name": "Invasão"}', null, null)$q$) = '42501', 'dona A no estúdio B: sem permissão');
select pg_temp.expect(pg_temp.state_of($q$select public.update_client_atomic('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec9',
  '{"full_name": "Invasão"}', null, null)$q$) = 'P0002', 'cliente do B pelo estúdio do A: não encontrada');
select pg_temp.login('00000000-0000-0000-0000-000000000e23');
select pg_temp.expect(pg_temp.state_of($q$select public.update_client_atomic('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1',
  '{"full_name": "Financeiro"}', null, null)$q$) = '42501', 'financeiro sem clientes.manage: recusa');
select pg_temp.login('00000000-0000-0000-0000-000000000e22');
select pg_temp.expect(pg_temp.state_of($q$select public.update_client_atomic('00000000-0000-0000-0000-000000000e2b', '00000000-0000-0000-0000-000000000ec1',
  '{"full_name": "Invasão"}', null, null)$q$) = 'P0002', 'dona B não edita cliente do A');
select pg_temp.logout();
select pg_temp.expect((select full_name from public.clients where id = '00000000-0000-0000-0000-000000000ec9') = 'Cliente B', 'cliente do B intacta');
select pg_temp.expect((select full_name from public.clients where id = '00000000-0000-0000-0000-000000000ec1') = 'Cliente A Editada', 'cliente do A intacta após recusas');

-- ─── sem login ───────────────────────────────────────────────
reset role;
select pg_temp.expect(not has_function_privilege('anon', 'public.client_profile(uuid, uuid, text[], boolean)', 'execute'), 'anon sem execute em client_profile');
select pg_temp.expect(not has_function_privilege('anon', 'public.restore_entitlement_session_atomic(uuid, uuid, text)', 'execute'), 'anon sem execute em restore_entitlement_session_atomic');
select pg_temp.expect(not has_function_privilege('anon', 'public.update_client_atomic(uuid, uuid, jsonb, text, text, boolean, text[])', 'execute'), 'anon sem execute em update_client_atomic');
select pg_temp.expect(not has_function_privilege('public', 'public.client_profile(uuid, uuid, text[], boolean)', 'execute'), 'public sem execute em client_profile');
select pg_temp.expect((select not p.prosecdef from pg_catalog.pg_proc p where p.oid = 'public.client_profile(uuid, uuid, text[], boolean)'::regprocedure), 'client_profile é SECURITY INVOKER');
select pg_temp.expect((select not p.prosecdef from pg_catalog.pg_proc p where p.oid = 'public.update_client_atomic(uuid, uuid, jsonb, text, text, boolean, text[])'::regprocedure), 'update_client_atomic é SECURITY INVOKER');
-- Regra de 20261114130400: devolver sessão é DEFINER (a tabela de movimentos não aceita gravação direta da API).
select pg_temp.expect((select p.prosecdef from pg_catalog.pg_proc p where p.oid = 'public.restore_entitlement_session_atomic(uuid, uuid, text)'::regprocedure), 'restore é SECURITY DEFINER');
select set_config('request.jwt.claims', '', true);
select set_config('role', 'anon', true);
select pg_temp.expect(pg_temp.state_of($q$select pg_temp.profile('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1')$q$) = '42501', 'anônimo não executa client_profile');
select pg_temp.expect(pg_temp.state_of($q$select public.restore_entitlement_session_atomic('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ee1', '')$q$) = '42501', 'anônimo não executa restore');
select pg_temp.expect(pg_temp.state_of($q$select public.update_client_atomic('00000000-0000-0000-0000-000000000e2a', '00000000-0000-0000-0000-000000000ec1', '{}', null, null)$q$) = '42501', 'anônimo não executa update_client_atomic');

rollback;
\o
\echo 'perfil da cliente e ações (O2): ok'
