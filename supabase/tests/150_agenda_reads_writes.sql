-- Agenda (porte, orçamento de chamadas): leituras agenda_* e ações agenda_* / anamnese_* das migrations
-- 20261114020000 e 20261114020100. Isolamento entre estúdios, alcance "só a minha agenda", anônimo sem execução,
-- série com mudança de horário (inclusive hora inexistente no horário de verão), estorno e repetição, ficha
-- pelo agendamento, edição recusada quando Pago e troca de cliente recusada com sinal.
-- Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000001490', 'dona@ag149.local'),
  ('00000000-0000-0000-0000-000000001491', 'profa@ag149.local'),
  ('00000000-0000-0000-0000-000000001492', 'donab@ag149.local');
insert into public.organizations (id, slug, name, timezone) values
  ('00000000-0000-0000-0000-00000000149a', 'ag149-a', 'Agenda 149 A', 'Europe/Madrid'),
  ('00000000-0000-0000-0000-00000000149b', 'ag149-b', 'Agenda 149 B', 'Europe/Madrid');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000001490', '00000000-0000-0000-0000-00000000149a', 'owner'),
  ('00000000-0000-0000-0000-000000001491', '00000000-0000-0000-0000-00000000149a', 'professional'),
  ('00000000-0000-0000-0000-000000001492', '00000000-0000-0000-0000-00000000149b', 'owner');
insert into public.profiles (user_id, org_id, full_name) values
  ('00000000-0000-0000-0000-000000001490', '00000000-0000-0000-0000-00000000149a', 'Dona Ana')
on conflict (user_id, org_id) do update set full_name = excluded.full_name;
insert into public.clients (id, org_id, full_name, phone) values
  ('00000000-0000-0000-0000-0000000014c1', '00000000-0000-0000-0000-00000000149a', 'Cliente Um', '+34600000001'),
  ('00000000-0000-0000-0000-0000000014c2', '00000000-0000-0000-0000-00000000149a', 'Cliente Dois', '+34600000002'),
  ('00000000-0000-0000-0000-0000000014c9', '00000000-0000-0000-0000-00000000149b', 'Cliente B', '+34600000009');
insert into public.staff_members (id, org_id, name, user_id, position) values
  ('00000000-0000-0000-0000-0000000014a1', '00000000-0000-0000-0000-00000000149a', 'Profissional A', '00000000-0000-0000-0000-000000001491', 1),
  ('00000000-0000-0000-0000-0000000014a2', '00000000-0000-0000-0000-00000000149a', 'Profissional B', null, 2),
  ('00000000-0000-0000-0000-0000000014b1', '00000000-0000-0000-0000-00000000149b', 'Profissional do B', null, 1);
insert into public.anamnese_templates (id, org_id, title, questions) values
  ('00000000-0000-0000-0000-0000000014f1', '00000000-0000-0000-0000-00000000149a', 'Ficha facial',
   '[{"id":"q1","type":"text","label":"Alergias?"}]'::jsonb);
insert into public.services (id, org_id, name, price, duration_minutes) values
  ('00000000-0000-0000-0000-0000000014d1', '00000000-0000-0000-0000-00000000149a', 'Limpeza', 60, 60),
  ('00000000-0000-0000-0000-0000000014d2', '00000000-0000-0000-0000-00000000149a', 'Retoque', 30, 30),
  ('00000000-0000-0000-0000-0000000014d9', '00000000-0000-0000-0000-00000000149b', 'Serviço B', 80, 60);
insert into public.client_entitlements (org_id, client_id, package_name, total_sessions, used_sessions, status) values
  ('00000000-0000-0000-0000-00000000149a', '00000000-0000-0000-0000-0000000014c1', 'Pacote A', 4, 1, 'active'),
  ('00000000-0000-0000-0000-00000000149b', '00000000-0000-0000-0000-0000000014c9', 'Pacote B', 4, 1, 'active');

create function pg_temp.expect(p_ok boolean, p_msg text) returns void language plpgsql as $$
begin
  if not coalesce(p_ok, false) then raise exception 'FALHOU: %', p_msg; end if;
end $$;
create function pg_temp.state_of(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return sqlstate || ': ' || sqlerrm;
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
create function pg_temp.mk(p_org uuid, p_client uuid, p_staff uuid, p_service uuid, p_start text) returns uuid language sql as $$
  select public.create_appointment_atomic(p_org, p_client, p_staff,
    p_start::timestamptz, p_start::timestamptz + interval '60 minutes', 60, 'Agendado', 'MANUAL', null, null, 60,
    pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('service_id', p_service, 'service_name', 'Serviço', 'price', 60)), false)
$$;
create function pg_temp.screen(p_org uuid, p_own boolean, p_detail uuid default null, p_card uuid default null) returns jsonb language sql as $$
  select public.agenda_screen(p_org, p_own, '2034-05-01 22:00+00', '2034-05-02 22:00+00', '2034-05-02 22:00+00', '2034-05-03 22:00+00',
    true, not p_own, array['Reservado','Agendado','Confirmado','Chegou','Iniciado','Concluído'], '2034-03-01 00:00+00',
    false, p_detail, true, null, '2034-02-01 00:00+00', p_card, true, not p_own, '2034-05-02 12:00+00')
$$;
create temp table t_ids (k text primary key, id uuid) on commit drop;
grant all on t_ids to authenticated;
grant execute on function pg_temp.expect(boolean, text), pg_temp.state_of(text), pg_temp.login(uuid), pg_temp.logout(),
  pg_temp.mk(uuid, uuid, uuid, uuid, text), pg_temp.screen(uuid, boolean, uuid, uuid) to anon, authenticated;

create temp table t_types on commit drop as
  select id from public.time_block_types where org_id = '00000000-0000-0000-0000-00000000149a' order by name limit 1;
grant select on t_types to authenticated;

-- Cenário: no A, um agendamento da profissional A (com a conta 1491) e um da B; no B, um agendamento.
select pg_temp.login('00000000-0000-0000-0000-000000001490');
insert into t_ids values
  ('a1', pg_temp.mk('00000000-0000-0000-0000-00000000149a', '00000000-0000-0000-0000-0000000014c1',
    '00000000-0000-0000-0000-0000000014a1', '00000000-0000-0000-0000-0000000014d1', '2034-05-02 08:00+00')),
  ('a2', pg_temp.mk('00000000-0000-0000-0000-00000000149a', '00000000-0000-0000-0000-0000000014c2',
    '00000000-0000-0000-0000-0000000014a2', '00000000-0000-0000-0000-0000000014d1', '2034-05-02 10:00+00'));
select public.register_appointment_deposit_atomic('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'a1'),
  20, 'CASH', '00000000-0000-0000-0000-0000000014e1');
insert into public.time_blocks (org_id, staff_id, time_block_type_id, start_at, end_at)
select '00000000-0000-0000-0000-00000000149a', s, (select id from t_types), '2034-05-02 14:00+00', '2034-05-02 15:00+00'
from (values ('00000000-0000-0000-0000-0000000014a1'::uuid), ('00000000-0000-0000-0000-0000000014a2'::uuid)) v(s);
select public.agenda_waitlist_add('00000000-0000-0000-0000-00000000149a', '00000000-0000-0000-0000-0000000014c2', null,
  '00000000-0000-0000-0000-0000000014a2', '[]'::jsonb, 'Quer manhã');
select pg_temp.login('00000000-0000-0000-0000-000000001492');
insert into t_ids values
  ('b1', pg_temp.mk('00000000-0000-0000-0000-00000000149b', '00000000-0000-0000-0000-0000000014c9',
    '00000000-0000-0000-0000-0000000014b1', '00000000-0000-0000-0000-0000000014d9', '2034-05-02 08:00+00'));
select pg_temp.logout();

-- ─── Leitura da tela: dona do A ─────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001490');
select pg_temp.expect(jsonb_array_length(pg_temp.screen('00000000-0000-0000-0000-00000000149a', false) -> 'appointments') = 2, 'dona vê os 2 agendamentos do dia');
select pg_temp.expect(jsonb_array_length(pg_temp.screen('00000000-0000-0000-0000-00000000149a', false) -> 'appointments' -> 0 -> 'appointment_items') = 1, 'itens vêm junto');
select pg_temp.expect((pg_temp.screen('00000000-0000-0000-0000-00000000149a', false) -> 'appointments' -> 0 -> 'clients' ->> 'phone') = '+34600000001', 'telefone da cliente junto');
select pg_temp.expect(jsonb_array_length(pg_temp.screen('00000000-0000-0000-0000-00000000149a', false) -> 'time_blocks') = 2, 'bloqueios do dia');
select pg_temp.expect(jsonb_array_length(pg_temp.screen('00000000-0000-0000-0000-00000000149a', false) -> 'staff') = 2, 'equipe ativa do A');
select pg_temp.expect(jsonb_array_length(pg_temp.screen('00000000-0000-0000-0000-00000000149a', false) -> 'services') = 2, 'serviços do A');
select pg_temp.expect((pg_temp.screen('00000000-0000-0000-0000-00000000149a', false) -> 'deposits' -> 0 ->> 'amount')::numeric = 20, 'sinal confirmado');
select pg_temp.expect((pg_temp.screen('00000000-0000-0000-0000-00000000149a', false) ->> 'waitlist_count')::int = 1, 'lista de espera conta 1');
select pg_temp.expect(jsonb_array_length(pg_temp.screen('00000000-0000-0000-0000-00000000149a', false) -> 'packages' -> 'entitlements') = 1, 'pacote da cliente do dia');
select pg_temp.expect(pg_temp.screen('00000000-0000-0000-0000-00000000149a', false) -> 'own_staff_ids' = 'null'::jsonb, 'alcance total não manda profissionais da pessoa');
select pg_temp.expect((pg_temp.screen('00000000-0000-0000-0000-00000000149a', false, (select id from t_ids where k = 'a1')) -> 'detail' -> 'appointment' ->> 'client_id') = '00000000-0000-0000-0000-0000000014c1', 'agendamento aberto vem junto');
select pg_temp.expect(jsonb_array_length(pg_temp.screen('00000000-0000-0000-0000-00000000149a', false, (select id from t_ids where k = 'a1')) -> 'detail' -> 'deposits') = 1, 'sinal no agendamento aberto');
select pg_temp.expect((pg_temp.screen('00000000-0000-0000-0000-00000000149a', false, (select id from t_ids where k = 'a1')) -> 'detail' -> 'names' ->> '00000000-0000-0000-0000-000000001490') = 'Dona Ana', 'nome de quem criou');
select pg_temp.expect((pg_temp.screen('00000000-0000-0000-0000-00000000149a', false, null, '00000000-0000-0000-0000-0000000014c1') -> 'card' -> 'client' ->> 'full_name') = 'Cliente Um', 'cartão da cliente');
select pg_temp.expect(jsonb_array_length(pg_temp.screen('00000000-0000-0000-0000-00000000149a', false) -> 'suggested') = 2, 'clientes sugeridas');
-- id do outro estúdio pedido na tela do A: nada vem.
select pg_temp.expect(pg_temp.screen('00000000-0000-0000-0000-00000000149a', false, (select id from t_ids where k = 'b1')) -> 'detail' = 'null'::jsonb, 'agendamento do B pelo A: nada');
select pg_temp.expect(pg_temp.screen('00000000-0000-0000-0000-00000000149a', false, null, '00000000-0000-0000-0000-0000000014c9') -> 'card' = 'null'::jsonb, 'cliente do B pelo A: nada');
select pg_temp.expect(public.agenda_marked_days('00000000-0000-0000-0000-00000000149a', false, '2034-05-01 00:00+00', '2034-06-01 00:00+00') = '["2034-05-02"]'::jsonb, 'dias marcados: distintos, no fuso do estúdio');
select pg_temp.expect(pg_temp.state_of($q$select public.agenda_screen('00000000-0000-0000-0000-00000000149a', false, '2034-01-01 00:00+00', '2034-03-01 00:00+00',
  '2034-01-01 00:00+00', '2034-01-02 00:00+00', false, false, array['Agendado'], '2034-01-01 00:00+00')$q$) like '22023%', 'tela recusa período maior que 43 dias');
select pg_temp.expect(not (pg_temp.screen('00000000-0000-0000-0000-00000000149a', false) -> 'appointments' -> 0 ? 'internal_notes'), 'quadro sem colunas que não usa');
select pg_temp.expect(not (public.agenda_screen('00000000-0000-0000-0000-00000000149a', false, '2034-05-01 00:00+00', '2034-06-01 00:00+00',
  '2034-05-02 22:00+00', '2034-05-03 22:00+00', false, false, array['Agendado'], '2034-03-01 00:00+00', true) -> 'appointments' -> 0 ? 'clients'), 'grade do mês leve: sem dados da cliente');
select pg_temp.expect((pg_temp.screen('00000000-0000-0000-0000-00000000149a', false, (select id from t_ids where k = 'a1')) -> 'detail' -> 'appointment' -> 'clients') ? 'loyalty_points', 'detalhe completo para quem vê tudo');
select pg_temp.expect(not ((public.agenda_appointment_detail('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'a1'), false) -> 'appointment' -> 'clients') ? 'balance'), 'detalhe sem saldo/pontos/aniversário para alcance restrito');
select pg_temp.expect(jsonb_array_length(public.agenda_staff_day('00000000-0000-0000-0000-00000000149a', false, '00000000-0000-0000-0000-0000000014a1',
  '2034-05-01 22:00+00', '2034-05-02 22:00+00') -> 'busy') = 2, 'ocupação: atendimento + bloqueio');
select pg_temp.expect(jsonb_array_length(public.agenda_waitlist_open('00000000-0000-0000-0000-00000000149a', false)) = 1, 'lista de espera aberta');
select pg_temp.expect((public.agenda_waitlist_open('00000000-0000-0000-0000-00000000149a', false) -> 0 ->> 'client_name') = 'Cliente Dois', 'nome da cliente na lista de espera');
select pg_temp.expect(jsonb_array_length(public.agenda_client_card('00000000-0000-0000-0000-00000000149a', '00000000-0000-0000-0000-0000000014c1', true, true,
  '2034-05-02 12:00+00', array['Agendado'], '2034-03-01 00:00+00') -> 'packages' -> 'entitlements') = 1, 'cartão com pacotes');

-- ─── Isolamento: dona do B lendo o A ────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001492');
select pg_temp.expect(jsonb_array_length(pg_temp.screen('00000000-0000-0000-0000-00000000149a', false) -> 'appointments') = 0, 'B não vê agendamentos do A');
select pg_temp.expect(jsonb_array_length(pg_temp.screen('00000000-0000-0000-0000-00000000149a', false) -> 'time_blocks') = 0, 'B não vê bloqueios do A');
select pg_temp.expect(jsonb_array_length(pg_temp.screen('00000000-0000-0000-0000-00000000149a', false) -> 'staff') = 0, 'B não vê equipe do A');
select pg_temp.expect(jsonb_array_length(pg_temp.screen('00000000-0000-0000-0000-00000000149a', false) -> 'services') = 0, 'B não vê serviços do A');
select pg_temp.expect((pg_temp.screen('00000000-0000-0000-0000-00000000149a', false) ->> 'waitlist_count')::int = 0, 'B não conta a lista de espera do A');
select pg_temp.expect(pg_temp.screen('00000000-0000-0000-0000-00000000149a', false, (select id from t_ids where k = 'a1')) -> 'detail' = 'null'::jsonb, 'B não abre agendamento do A');
select pg_temp.expect(pg_temp.screen('00000000-0000-0000-0000-00000000149a', false, null, '00000000-0000-0000-0000-0000000014c1') -> 'card' = 'null'::jsonb, 'B não vê cliente do A');
select pg_temp.expect(public.agenda_appointment_detail('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'a1')) is null, 'B: detalhe do A nulo');
select pg_temp.expect(jsonb_array_length(public.agenda_marked_days('00000000-0000-0000-0000-00000000149a', false, '2034-05-01 00:00+00', '2034-06-01 00:00+00')) = 0, 'B: dias do A vazios');
select pg_temp.expect(public.agenda_appointment_fichas('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'a1')) = '{"fichas": [], "templates": []}'::jsonb, 'B: fichas do agendamento do A = vazio');
select pg_temp.expect(jsonb_array_length(public.agenda_staff_day('00000000-0000-0000-0000-00000000149a', false, '00000000-0000-0000-0000-0000000014a1',
  '2034-05-01 22:00+00', '2034-05-02 22:00+00') -> 'busy') = 0, 'B: ocupação do A vazia');
select pg_temp.expect(jsonb_array_length(public.agenda_waitlist_open('00000000-0000-0000-0000-00000000149a', false)) = 0, 'B: lista de espera do A vazia');
select pg_temp.expect(jsonb_array_length(public.agenda_package_rows('00000000-0000-0000-0000-00000000149a',
  array['00000000-0000-0000-0000-0000000014c1']::uuid[], array['Agendado'], '2034-03-01 00:00+00') -> 'entitlements') = 0, 'B: pacotes do A vazios');
-- Escritas do B no A: recusadas.
select pg_temp.expect(pg_temp.state_of($q$select public.agenda_move_appointment('00000000-0000-0000-0000-00000000149a',
  (select id from t_ids where k = 'a1'), '2034-05-02 09:00+00', null)$q$) like '42501%', 'B não move agendamento do A');
select pg_temp.expect(pg_temp.state_of($q$select public.agenda_set_internal_note('00000000-0000-0000-0000-00000000149a',
  (select id from t_ids where k = 'a1'), 'x', '2034-05-02')$q$) like '42501%', 'B não escreve nota no A');
select pg_temp.expect(pg_temp.state_of($q$select public.agenda_edit_items('00000000-0000-0000-0000-00000000149a',
  (select id from t_ids where k = 'a1'), 'remove', (select id from public.appointment_items limit 1))$q$) like '42501%', 'B não mexe nos itens do A');
select pg_temp.expect(pg_temp.state_of($q$select public.agenda_change_client('00000000-0000-0000-0000-00000000149a',
  (select id from t_ids where k = 'a1'), '00000000-0000-0000-0000-0000000014c9')$q$) like '42501%', 'B não troca cliente no A');
select pg_temp.expect(pg_temp.state_of($q$select public.agenda_waitlist_add('00000000-0000-0000-0000-00000000149a',
  '00000000-0000-0000-0000-0000000014c1', null, null, '[]', null)$q$) like '42501%', 'B não põe na lista de espera do A');
select pg_temp.expect(pg_temp.state_of($q$select public.agenda_save_time_blocks('00000000-0000-0000-0000-00000000149a', null,
  '00000000-0000-0000-0000-0000000014a1', false, (select id from t_types), null, null, false, 'none', 1,
  '[{"start_at":"2034-05-03 08:00+00","end_at":"2034-05-03 09:00+00"}]')$q$) like '42501%', 'B não bloqueia horário no A');
-- Cliente do B num agendamento do B, pelo id do A: nada muda (dona B não tem papel no A).
select pg_temp.expect(pg_temp.state_of($q$select public.agenda_refund_and_cancel('00000000-0000-0000-0000-00000000149a',
  (select id from t_ids where k = 'a1'), 'Motivo', 'caixa', false, gen_random_uuid(), false)$q$) like '42501%', 'B não estorna no A');

-- ─── Alcance "só a minha agenda" (profissional A) ───────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001491');
select pg_temp.expect(jsonb_array_length(pg_temp.screen('00000000-0000-0000-0000-00000000149a', true) -> 'appointments') = 1, 'profissional vê só o próprio agendamento');
select pg_temp.expect((pg_temp.screen('00000000-0000-0000-0000-00000000149a', true) -> 'own_staff_ids' ->> 0) = '00000000-0000-0000-0000-0000000014a1', 'profissionais da pessoa vêm na tela');
select pg_temp.expect(jsonb_array_length(pg_temp.screen('00000000-0000-0000-0000-00000000149a', true) -> 'time_blocks') = 1, 'profissional vê só o próprio bloqueio');
select pg_temp.expect(jsonb_array_length(pg_temp.screen('00000000-0000-0000-0000-00000000149a', false) -> 'appointments') = 1, 'profissional com p_own=false: a RLS ainda mostra só o próprio');
select pg_temp.expect(public.agenda_appointment_fichas('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'a2')) -> 'fichas' = '[]'::jsonb, 'profissional: fichas do agendamento de outra = vazio');
select pg_temp.expect(public.agenda_staff_day('00000000-0000-0000-0000-00000000149a', true, '00000000-0000-0000-0000-0000000014a2',
  '2034-05-01 22:00+00', '2034-05-02 22:00+00') is null, 'profissional não vê o dia de outra');
select pg_temp.expect(jsonb_array_length(public.agenda_marked_days('00000000-0000-0000-0000-00000000149a', true, '2034-05-01 00:00+00', '2034-06-01 00:00+00')) = 1, 'dias marcados só da própria');
select pg_temp.expect(pg_temp.state_of($q$select public.agenda_save_time_blocks('00000000-0000-0000-0000-00000000149a', null,
  '00000000-0000-0000-0000-0000000014a2', false, (select id from t_types), null, null, false, 'none', 1,
  '[{"start_at":"2034-05-03 08:00+00","end_at":"2034-05-03 09:00+00"}]')$q$) like 'P0001: Seu acesso mostra só a sua agenda%', 'profissional não bloqueia outra');
select pg_temp.expect(pg_temp.state_of($q$select public.agenda_save_time_blocks('00000000-0000-0000-0000-00000000149a', null,
  null, true, (select id from t_types), null, null, false, 'none', 1,
  '[{"start_at":"2034-05-03 08:00+00","end_at":"2034-05-03 09:00+00"}]')$q$) like 'P0001: Seu acesso mostra só a sua agenda%', 'profissional não bloqueia a equipe');
select pg_temp.expect(pg_temp.state_of($q$select public.agenda_save_time_blocks('00000000-0000-0000-0000-00000000149a', null,
  '00000000-0000-0000-0000-0000000014a1', false, (select id from t_types), 'Pausa', null, false, 'none', 1,
  '[{"start_at":"2034-05-03 08:00+00","end_at":"2034-05-03 09:00+00"}]')$q$) = 'ok', 'profissional bloqueia a própria agenda');
select pg_temp.expect(pg_temp.state_of($q$select public.agenda_delete_time_block('00000000-0000-0000-0000-00000000149a',
  (select id from public.time_blocks where staff_id = '00000000-0000-0000-0000-0000000014a1' and title = 'Pausa'))$q$) = 'ok', 'profissional remove o próprio bloqueio');

-- ─── Escritas da dona do A ──────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001490');
-- Mover trocando a profissional: itens da antiga passam para a nova.
select public.agenda_move_appointment('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'a1'),
  '2034-05-02 16:00+00', '00000000-0000-0000-0000-0000000014a2');
select pg_temp.expect((select staff_id = '00000000-0000-0000-0000-0000000014a2' and start_at = '2034-05-02 16:00+00' and end_at = '2034-05-02 17:00+00'
  from public.appointments where id = (select id from t_ids where k = 'a1')), 'move troca profissional e hora');
select pg_temp.expect((select professional_id = '00000000-0000-0000-0000-0000000014a2' from public.appointment_items
  where appointment_id = (select id from t_ids where k = 'a1')), 'item passa para a nova profissional');
-- Mesma profissional: só reagenda.
select public.agenda_move_appointment('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'a1'), '2034-05-02 17:00+00', null);
select pg_temp.expect((select start_at = '2034-05-02 17:00+00' from public.appointments where id = (select id from t_ids where k = 'a1')), 'reagenda na mesma profissional');
-- Conflito com outro atendimento da mesma profissional: erro do banco, nada muda.
select pg_temp.expect(pg_temp.state_of($q$select public.agenda_move_appointment('00000000-0000-0000-0000-00000000149a',
  (select id from t_ids where k = 'a1'), '2034-05-02 10:00+00', null)$q$) ilike '%horario%', 'conflito de horário recusado');
-- Itens: adicionar, mudar duração e remover.
select public.agenda_edit_items('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'a1'), 'add', null,
  '00000000-0000-0000-0000-0000000014d2', 'Retoque', 30, null);
select pg_temp.expect((select count(*) = 2 from public.appointment_items where appointment_id = (select id from t_ids where k = 'a1')), 'serviço adicionado');
select pg_temp.expect((select duration_minutes = 90 and total = 90 from public.appointments where id = (select id from t_ids where k = 'a1')), 'duração e total somados');
select public.agenda_edit_items('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'a1'), 'update',
  (select id from public.appointment_items where appointment_id = (select id from t_ids where k = 'a1') and name = 'Retoque'),
  null, null, 35, null, 45);
select pg_temp.expect((select duration_minutes = 105 and total = 95 from public.appointments where id = (select id from t_ids where k = 'a1')), 'duração nova regrava o agendamento');
select public.agenda_edit_items('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'a1'), 'update',
  (select id from public.appointment_items where appointment_id = (select id from t_ids where k = 'a1') and name = 'Retoque'),
  null, null, 40, null, null);
select pg_temp.expect((select total = 100 and duration_minutes = 105 from public.appointments where id = (select id from t_ids where k = 'a1')), 'só preço: total recalculado, duração igual');
select public.agenda_edit_items('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'a1'), 'remove',
  (select id from public.appointment_items where appointment_id = (select id from t_ids where k = 'a1') and name = 'Retoque'));
select pg_temp.expect((select count(*) = 1 from public.appointment_items where appointment_id = (select id from t_ids where k = 'a1')), 'serviço removido');
select pg_temp.expect(pg_temp.state_of($q$select public.agenda_edit_items('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'a1'), 'remove',
  (select id from public.appointment_items where appointment_id = (select id from t_ids where k = 'a1')))$q$) like 'P0001: O agendamento precisa de pelo menos um serviço%', 'último serviço não sai');
select pg_temp.expect(pg_temp.state_of($q$select public.agenda_edit_items('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'a1'), 'add', null,
  '00000000-0000-0000-0000-0000000014d9', 'Serviço B', 1, null)$q$) like 'P0002%', 'serviço do B não entra no A');
-- Nota interna espelhada no histórico da cliente (criar e depois editar a mesma).
select public.agenda_set_internal_note('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'a1'), ' Pele sensível ', '2034-05-02');
select pg_temp.expect((select internal_notes = 'Pele sensível' from public.appointments where id = (select id from t_ids where k = 'a1')), 'nota gravada sem espaços');
select public.agenda_set_internal_note('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'a1'), 'Pele muito sensível', '2034-05-03');
select pg_temp.expect((select count(*) = 1 and min(content) = 'Pele muito sensível' and min(note_date) = '2034-05-02' from public.client_notes
  where appointment_id = (select id from t_ids where k = 'a1') and note_type = 'appointment' and deleted_at is null), 'uma nota no histórico, editada');
-- Trocar cliente: recusada com sinal; feita sem sinal, com auditoria (antiga e nova).
select pg_temp.expect(pg_temp.state_of($q$select public.agenda_change_client('00000000-0000-0000-0000-00000000149a',
  (select id from t_ids where k = 'a1'), '00000000-0000-0000-0000-0000000014c2')$q$) like 'P0001: Este agendamento tem sinal%', 'troca recusada com sinal');
select public.agenda_change_client('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'a2'), '00000000-0000-0000-0000-0000000014c1');
select pg_temp.expect((select client_name = 'Cliente Um' from public.appointments where id = (select id from t_ids where k = 'a2')), 'cliente trocada');
select pg_temp.expect((select old_data ->> 'client_id' = '00000000-0000-0000-0000-0000000014c2' and new_data ->> 'client_id' = '00000000-0000-0000-0000-0000000014c1'
  from public.audit_logs where record_id = (select id from t_ids where k = 'a2') and operation = 'APPOINTMENT_CLIENT_CHANGED'), 'troca auditada');
select pg_temp.expect(pg_temp.state_of($q$select public.agenda_change_client('00000000-0000-0000-0000-00000000149a',
  (select id from t_ids where k = 'a2'), '00000000-0000-0000-0000-0000000014c9')$q$) like 'P0002%', 'cliente do B não entra no A');
-- Bloqueio para a equipe: quem já tem atendimento no horário é pulado.
select pg_temp.expect((public.agenda_save_time_blocks('00000000-0000-0000-0000-00000000149a', null, null, true, (select id from t_types),
  'Reunião', null, false, 'none', 1, '[{"start_at":"2034-05-02 10:00+00","end_at":"2034-05-02 10:30+00"}]') -> 'skipped' ->> 0) = 'Profissional B',
  'equipe toda: pula quem tem atendimento');
select pg_temp.expect((select count(*) = 1 from public.time_blocks where org_id = '00000000-0000-0000-0000-00000000149a' and title = 'Reunião'), 'equipe toda: bloqueou quem estava livre');
-- Editar bloqueio: troca numa transação; se o novo não cabe, o antigo fica.
select pg_temp.expect(pg_temp.state_of($q$select public.agenda_save_time_blocks('00000000-0000-0000-0000-00000000149a',
  (select id from public.time_blocks where title = 'Reunião'), '00000000-0000-0000-0000-0000000014a2', false, (select id from t_types),
  'Reunião 2', null, false, 'none', 1, '[{"start_at":"2034-05-02 10:00+00","end_at":"2034-05-02 10:30+00"}]')$q$) <> 'ok', 'edição que conflita é recusada');
select pg_temp.expect((select count(*) = 1 from public.time_blocks where title = 'Reunião'), 'bloqueio antigo mantido');
select public.agenda_save_time_blocks('00000000-0000-0000-0000-00000000149a', (select id from public.time_blocks where title = 'Reunião'),
  '00000000-0000-0000-0000-0000000014a1', false, (select id from t_types), 'Reunião 2', null, false, 'none', 1,
  '[{"start_at":"2034-05-02 18:00+00","end_at":"2034-05-02 18:30+00"}]');
select pg_temp.expect((select count(*) = 0 from public.time_blocks where title = 'Reunião')
  and (select count(*) = 1 from public.time_blocks where title = 'Reunião 2'), 'bloqueio trocado');
-- Ficha pelo agendamento: gerar com validade e envio; o painel mostra; revogar audita e apaga.
insert into t_ids select 'f1', (public.anamnese_create_link('00000000-0000-0000-0000-00000000149a', '00000000-0000-0000-0000-0000000014f1',
  '00000000-0000-0000-0000-0000000014c1', 'Cliente Um', (select id from t_ids where k = 'a1'), null, 7, 'whatsapp') ->> 'id')::uuid;
select pg_temp.expect((select token_expires_at > now() + interval '6 days' from public.list_anamnese_status('00000000-0000-0000-0000-00000000149a',
  p_ids => array[(select id from t_ids where k = 'f1')])), 'link com a validade pedida');
select pg_temp.expect((select count(*) = 1 from public.anamnese_events where anamnese_id = (select id from t_ids where k = 'f1') and channel = 'whatsapp'), 'envio registrado');
select pg_temp.expect((public.agenda_appointment_fichas('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'a1')) -> 'fichas' -> 0 ->> 'public_token') is null, 'ficha pendente não traz o link (20261114100000: o banco guarda só o hash; reenviar gera link novo)');
select pg_temp.expect(jsonb_array_length(public.agenda_appointment_fichas('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'a1')) -> 'templates') = 1, 'modelos ativos');
select pg_temp.expect(public.anamnese_delete_pending('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'f1'))
  = jsonb_build_array('00000000-0000-0000-0000-00000000149a/' || (select id from t_ids where k = 'f1') || '/'), 'revogar: a pasta da ficha para limpar');
select pg_temp.expect((select count(*) = 0 from public.list_anamnese_status('00000000-0000-0000-0000-00000000149a',
  p_ids => array[(select id from t_ids where k = 'f1')])), 'ficha pendente apagada');
select pg_temp.expect((select count(*) = 1 from public.audit_logs where record_id = (select id from t_ids where k = 'f1') and operation = 'ANAMNESE_PENDING_DELETED'
  and not (old_data ? 'answers')), 'exclusão auditada, sem respostas');
select pg_temp.expect(pg_temp.state_of($q$select public.anamnese_delete_pending('00000000-0000-0000-0000-00000000149a', gen_random_uuid())$q$) like 'P0002%', 'ficha inexistente');

-- Série: mudar o horário de todas (11:00 no fuso do estúdio); hora que não existe no dia do horário de verão é recusada.
insert into t_ids select 'r1', (public.create_recurring_appointments_atomic('00000000-0000-0000-0000-00000000149a', '00000000-0000-0000-0000-0000000014c2',
  '00000000-0000-0000-0000-0000000014a2', '', 'Agendado', 'MANUAL', null, null, 60, 60,
  '[{"index":0,"start_at":"2034-03-19 09:00+00","end_at":"2034-03-19 10:00+00"},
    {"index":1,"start_at":"2034-03-26 08:00+00","end_at":"2034-03-26 09:00+00"},
    {"index":2,"start_at":"2034-04-02 08:00+00","end_at":"2034-04-02 09:00+00"}]'::jsonb,
  '[{"service_id":"00000000-0000-0000-0000-0000000014d1","service_name":"Limpeza","price":60,"duration_minutes":60}]'::jsonb, false) ->> 'first_appointment_id')::uuid;
insert into t_ids select 'rs', recurrence_id from public.appointments where id = (select id from t_ids where k = 'r1');
select pg_temp.expect(pg_temp.state_of($q$select public.agenda_update_series('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'rs'),
  '00000000-0000-0000-0000-0000000014a2', '02:30', 60, null, null, false)$q$) like 'P0001: O horário 02:30 não existe em 26/03/2034%', 'hora inexistente no horário de verão recusada');
select pg_temp.expect(public.agenda_update_series('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'rs'),
  '00000000-0000-0000-0000-0000000014a2', '11:00', 45, 'Série nova', null, false) = 3, 'série: 3 atendimentos mudados');
select pg_temp.expect((select bool_and(to_char(start_at at time zone 'Europe/Madrid', 'HH24:MI') = '11:00' and end_at - start_at = interval '45 minutes')
  from public.appointments where recurrence_id = (select id from t_ids where k = 'rs')), 'série: 11:00 local em todos, antes e depois do horário de verão');
select pg_temp.expect(pg_temp.state_of($q$select public.agenda_update_series('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'rs'),
  null, '11:00', 45, repeat('x', 1001), null, false)$q$) like '22023%', 'observação da série até 1000');

-- Estorno e cancelamento de um atendimento pago; repetir com a mesma chave devolve duplicate.
insert into t_ids values ('p1', pg_temp.mk('00000000-0000-0000-0000-00000000149a', '00000000-0000-0000-0000-0000000014c2',
  '00000000-0000-0000-0000-0000000014a1', '00000000-0000-0000-0000-0000000014d1', '2034-05-09 08:00+00'));
select public.set_appointment_status_atomic('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'p1'), 'Iniciado');
select public.set_appointment_status_atomic('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'p1'), 'Concluído');
select public.confirm_checkout_atomic('00000000-0000-0000-0000-00000000149a', jsonb_build_object(
  'request_id', '00000000-0000-0000-0000-0000000014e7', 'appointment_id', (select id from t_ids where k = 'p1'), 'mode', 'finalize',
  'items', jsonb_build_array(jsonb_build_object('item_type', 'SERVICE', 'item_id', '00000000-0000-0000-0000-0000000014d1',
    'name', 'Limpeza', 'unit_price', 60, 'quantity', 1)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'CASH', 'amount', 60))));
select pg_temp.expect((select status = 'Pago' from public.appointments where id = (select id from t_ids where k = 'p1')), 'atendimento pago');
select pg_temp.expect(pg_temp.state_of($q$select public.agenda_edit_items('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'p1'), 'add', null,
  '00000000-0000-0000-0000-0000000014d2', 'Retoque', 30, null)$q$) like 'P0001: Atendimento pago%', 'pago: itens não mudam');
select pg_temp.expect(pg_temp.state_of($q$select public.agenda_edit_items('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'a1'), 'add', null,
  '00000000-0000-0000-0000-0000000014d2', repeat('x', 201), 30, null)$q$) like '22023%', 'nome do item até 200');
select pg_temp.expect(pg_temp.state_of($q$select public.agenda_edit_items('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'a1'), 'add', null,
  '00000000-0000-0000-0000-0000000014d2', 'Retoque', 100001, null)$q$) like '22023%', 'preço até 100000');
create temp table t_refund (k text primary key, r jsonb) on commit drop;
grant all on t_refund to authenticated;
insert into t_refund select 'first', public.agenda_refund_and_cancel('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'p1'),
  'Cliente desistiu do atendimento', 'caixa', false, '00000000-0000-0000-0000-0000000014e8', false);
select pg_temp.expect((select (r ->> 'amount')::numeric = 60 and (r ->> 'duplicate')::boolean = false from t_refund where k = 'first'), 'estorno de 60');
select pg_temp.expect((select status = 'Cancelado' from public.appointments where id = (select id from t_ids where k = 'p1')), 'pago estornado e cancelado');
insert into t_refund select 'again', public.agenda_refund_and_cancel('00000000-0000-0000-0000-00000000149a', (select id from t_ids where k = 'p1'),
  'Cliente desistiu do atendimento', 'caixa', false, '00000000-0000-0000-0000-0000000014e8', false);
select pg_temp.expect((select (r ->> 'duplicate')::boolean and (r ->> 'amount')::numeric = 60 from t_refund where k = 'again'), 'repetição: duplicate, sem estornar de novo');
select pg_temp.expect((select count(*) = 1 from public.sale_refunds where idempotency_key = '00000000-0000-0000-0000-0000000014e8'), 'um estorno só');
-- Comanda: sem comanda, mensagem clara e nada muda.
select pg_temp.expect(pg_temp.state_of($q$select public.agenda_refund_and_cancel('00000000-0000-0000-0000-00000000149a',
  (select id from t_ids where k = 'a2'), 'Motivo', 'caixa', false, gen_random_uuid(), false)$q$) like 'P0002: Não achei o checkout%', 'sem comanda');

-- ─── Anônimo: nenhuma função executa ────────────────────────────────────────
select pg_temp.logout();
select pg_temp.expect(not has_function_privilege('anon', p.oid, 'execute'), 'anon sem execute em ' || p.proname)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and (p.proname like 'agenda\_%' escape '\' and p.proname not in ('agenda_full_view_orgs', 'agenda_own_view_orgs', 'agenda_my_staff_ids', 'agenda_status_transition_allowed', 'agenda_assert_slot_available')
  or p.proname in ('anamnese_create_link', 'anamnese_delete_pending'));
select pg_temp.expect(not has_function_privilege('public', 'public.agenda_screen(uuid, boolean, timestamptz, timestamptz, timestamptz, timestamptz, boolean, boolean, text[], timestamptz, boolean, uuid, boolean, uuid, timestamptz, uuid, boolean, boolean, timestamptz)', 'execute'), 'public sem execute em agenda_screen');
select set_config('role', 'anon', true);
select pg_temp.expect(pg_temp.state_of($q$select pg_temp.screen('00000000-0000-0000-0000-00000000149a', false)$q$) like '42501%', 'anônimo não lê a tela');
select pg_temp.expect(pg_temp.state_of($q$select public.agenda_move_appointment('00000000-0000-0000-0000-00000000149a',
  (select id from t_ids where k = 'a1'), '2034-05-02 09:00+00', null)$q$) like '42501%', 'anônimo não move');

rollback;
\o
\echo 'agenda: leituras e ações em uma ida (150): ok'
