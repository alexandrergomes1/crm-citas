-- Fluxo principal do estúdio, de ponta a ponta, nas funções reais do banco:
-- cliente → agendamento → sinal → atendimento → comanda → financeiro → saldo da cliente.
-- Cenário A: pagamento completo com sinal. Cenário B: pagamento parcial e quitação depois.
-- Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000000f1', 'fluxo@teste.local');
insert into public.organizations (id, slug, name) values ('00000000-0000-0000-0000-0000000000f0', 'fluxo-a', 'Fluxo');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000f0', 'owner');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-0000000000fc', '00000000-0000-0000-0000-0000000000f0', 'María José Núñez');
insert into public.staff_members (id, org_id, name) values
  ('00000000-0000-0000-0000-0000000000fb', '00000000-0000-0000-0000-0000000000f0', 'Karenn');
insert into public.services (id, org_id, name, price, duration_minutes) values
  ('00000000-0000-0000-0000-0000000000fd', '00000000-0000-0000-0000-0000000000f0', 'Limpeza de pele', 80, 60);

create function pg_temp.expect(p_ok boolean, p_msg text) returns void language plpgsql as $$
begin
  if not coalesce(p_ok, false) then raise exception 'FALHOU: %', p_msg; end if;
end $$;
create function pg_temp.as_owner() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000000f1', 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;
grant execute on function pg_temp.expect(boolean, text), pg_temp.as_owner() to authenticated;
create temp table t_ids (k text primary key, id uuid) on commit drop;
grant all on t_ids to authenticated;

select pg_temp.as_owner();

-- ── Cenário A: agenda, sinal de 20, atendimento, pagamento de 60 em dinheiro ──
insert into t_ids values ('a', public.create_appointment_atomic(
  '00000000-0000-0000-0000-0000000000f0', '00000000-0000-0000-0000-0000000000fc', '00000000-0000-0000-0000-0000000000fb',
  now() + interval '1 day', now() + interval '1 day 1 hour', 60, 'Agendado', 'WHATSAPP', null, null, 80,
  '[{"service_id":"00000000-0000-0000-0000-0000000000fd","service_name":"Limpeza de pele","price":80,"duration_minutes":60}]'::jsonb,
  false));
select public.set_appointment_status_atomic('00000000-0000-0000-0000-0000000000f0', (select id from t_ids where k = 'a'), 'Confirmado');
select public.register_appointment_deposit_atomic('00000000-0000-0000-0000-0000000000f0', (select id from t_ids where k = 'a'),
  20, 'BIZUM', '00000000-0000-0000-0000-0000000000a1');
-- Repetir o mesmo sinal (mesma chave) não duplica.
select public.register_appointment_deposit_atomic('00000000-0000-0000-0000-0000000000f0', (select id from t_ids where k = 'a'),
  20, 'BIZUM', '00000000-0000-0000-0000-0000000000a1');
select public.set_appointment_status_atomic('00000000-0000-0000-0000-0000000000f0', (select id from t_ids where k = 'a'), 'Iniciado');
select public.set_appointment_status_atomic('00000000-0000-0000-0000-0000000000f0', (select id from t_ids where k = 'a'), 'Concluído');
select public.confirm_checkout_atomic('00000000-0000-0000-0000-0000000000f0', jsonb_build_object(
  'request_id', '00000000-0000-0000-0000-0000000000a2',
  'appointment_id', (select id from t_ids where k = 'a'), 'mode', 'finalize',
  'items', jsonb_build_array(jsonb_build_object('item_type', 'service', 'item_id', '00000000-0000-0000-0000-0000000000fd',
    'name', 'Limpeza de pele', 'unit_price', 80, 'quantity', 1)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'CASH', 'amount', 60))));
reset role; select set_config('request.jwt.claims', '', true);

select pg_temp.expect((select status from public.appointments where id = (select id from t_ids where k = 'a')) = 'Pago',
  'A: atendimento fica Pago');
select pg_temp.expect((select count(*) from public.appointment_deposits where appointment_id = (select id from t_ids where k = 'a')) = 1,
  'A: sinal repetido não duplica');
select pg_temp.expect((select status = 'paid' and total = 80 and paid_amount = 80 and balance = 0 from public.sales
  where appointment_id = (select id from t_ids where k = 'a')), 'A: comanda paga 80/80');
select pg_temp.expect((select status from public.appointment_deposits where appointment_id = (select id from t_ids where k = 'a')) = 'applied',
  'A: sinal aplicado na comanda');
select pg_temp.expect((select sum(value) from public.transactions where org_id = '00000000-0000-0000-0000-0000000000f0'
  and type = 'income' and status = 'completed') = 80, 'A: caixa recebe 80 (20 de sinal + 60)');
select pg_temp.expect((select total_spent = 80 and loyalty_points = 80 and balance = 0 from public.clients
  where id = '00000000-0000-0000-0000-0000000000fc'), 'A: cliente com gasto 80, 80 pontos e saldo zero');

-- ── Cenário B: paga 30 de 80, fica devendo 50, quita depois ──
select pg_temp.as_owner();
insert into t_ids values ('b', public.create_appointment_atomic(
  '00000000-0000-0000-0000-0000000000f0', '00000000-0000-0000-0000-0000000000fc', '00000000-0000-0000-0000-0000000000fb',
  now() + interval '2 days', now() + interval '2 days 1 hour', 60, 'Agendado', 'MANUAL', null, null, 80,
  '[{"service_id":"00000000-0000-0000-0000-0000000000fd","service_name":"Limpeza de pele","price":80,"duration_minutes":60}]'::jsonb,
  false));
select public.confirm_checkout_atomic('00000000-0000-0000-0000-0000000000f0', jsonb_build_object(
  'request_id', '00000000-0000-0000-0000-0000000000b1',
  'appointment_id', (select id from t_ids where k = 'b'), 'mode', 'finalize',
  'items', jsonb_build_array(jsonb_build_object('item_type', 'service', 'item_id', '00000000-0000-0000-0000-0000000000fd',
    'name', 'Limpeza de pele', 'unit_price', 80, 'quantity', 1)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'CARD_DEBIT', 'amount', 30))));
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select status from public.appointments where id = (select id from t_ids where k = 'b')) = 'Pago Parcial',
  'B: atendimento fica Pago Parcial');
select pg_temp.expect((select balance from public.clients where id = '00000000-0000-0000-0000-0000000000fc') = -50,
  'B: cliente deve 50');

select pg_temp.as_owner();
select public.confirm_checkout_atomic('00000000-0000-0000-0000-0000000000f0', jsonb_build_object(
  'request_id', '00000000-0000-0000-0000-0000000000b2',
  'appointment_id', (select id from t_ids where k = 'b'), 'mode', 'finalize',
  'items', jsonb_build_array(jsonb_build_object('item_type', 'service', 'item_id', '00000000-0000-0000-0000-0000000000fd',
    'name', 'Limpeza de pele', 'unit_price', 80, 'quantity', 1)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'CARD_DEBIT', 'amount', 30),
                                jsonb_build_object('method', 'CASH', 'amount', 50))));
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select status from public.appointments where id = (select id from t_ids where k = 'b')) = 'Pago',
  'B: quitado, atendimento Pago');
select pg_temp.expect((select balance from public.clients where id = '00000000-0000-0000-0000-0000000000fc') = 0,
  'B: saldo da cliente volta a zero');
-- Tudo roda numa transação (created_at igual): confere a cadeia, não a ordem por data.
select pg_temp.expect(exists (select 1 from public.client_balance_entries
  where client_id = '00000000-0000-0000-0000-0000000000fc' and balance_before = -50 and balance_after = 0),
  'B: extrato tem o lançamento que zera a dívida');
select pg_temp.expect((select coalesce(sum(amount), 0) from public.client_balance_entries
  where client_id = '00000000-0000-0000-0000-0000000000fc') = 0, 'B: extrato soma zero');
select pg_temp.expect((select sum(value) from public.transactions where org_id = '00000000-0000-0000-0000-0000000000f0'
  and type = 'income' and status = 'completed') = 160, 'B: caixa total 160');
select pg_temp.expect((select count(*) from public.audit_logs where org_id = '00000000-0000-0000-0000-0000000000f0') >= 6,
  'auditoria registra o fluxo');

rollback;
\o
\echo 'fluxo principal: ok'
