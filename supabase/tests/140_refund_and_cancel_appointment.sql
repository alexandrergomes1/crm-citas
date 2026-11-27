-- Estornar e cancelar o agendamento numa ação só: refund_sale_atomic com p_cancel_appointment
-- (20261031100000). Cobre estorno + cancelamento, estorno sem cancelar (assinatura antiga de 6
-- parâmetros e a nova com false), permissão negada, idempotência, Pago Parcial, rascunho,
-- "cobrar de novo" quando NÃO cancelou e cancelar Concluído sem comanda ativa.
-- Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000001401', 'dona-cancela-estorno@teste.local'),
  ('00000000-0000-0000-0000-000000001402', 'fin-cancela-estorno@teste.local'),
  ('00000000-0000-0000-0000-000000001403', 'recep-cancela-estorno@teste.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-00000000140a', 'cancela-estorno-a', 'Estúdio A');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000001401', '00000000-0000-0000-0000-00000000140a', 'owner'),
  ('00000000-0000-0000-0000-000000001402', '00000000-0000-0000-0000-00000000140a', 'finance'),
  ('00000000-0000-0000-0000-000000001403', '00000000-0000-0000-0000-00000000140a', 'receptionist');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-0000000014c1', '00000000-0000-0000-0000-00000000140a', 'Cliente Um'),
  ('00000000-0000-0000-0000-0000000014c2', '00000000-0000-0000-0000-00000000140a', 'Cliente Dois'),
  ('00000000-0000-0000-0000-0000000014c3', '00000000-0000-0000-0000-00000000140a', 'Cliente Três'),
  ('00000000-0000-0000-0000-0000000014c4', '00000000-0000-0000-0000-00000000140a', 'Cliente Quatro'),
  ('00000000-0000-0000-0000-0000000014c5', '00000000-0000-0000-0000-00000000140a', 'Cliente Cinco'),
  ('00000000-0000-0000-0000-0000000014c6', '00000000-0000-0000-0000-00000000140a', 'Cliente Seis'),
  ('00000000-0000-0000-0000-0000000014c7', '00000000-0000-0000-0000-00000000140a', 'Cliente Sete');
insert into public.staff_members (id, org_id, name) values
  ('00000000-0000-0000-0000-00000000140b', '00000000-0000-0000-0000-00000000140a', 'Karenn');
insert into public.services (id, org_id, name, price, duration_minutes) values
  ('00000000-0000-0000-0000-00000000140d', '00000000-0000-0000-0000-00000000140a', 'Limpeza de pele', 100, 60);

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
  reset role;
  perform set_config('request.jwt.claims', '', true);
end $$;
-- Agendamento de uma cliente, Agendado, em n dias; opcionalmente com sinal.
create function pg_temp.booked(p_client uuid, p_n integer) returns uuid language sql as $$
  select public.create_appointment_atomic(
    '00000000-0000-0000-0000-00000000140a', p_client, '00000000-0000-0000-0000-00000000140b',
    now() + make_interval(days => p_n), now() + make_interval(days => p_n, hours => 1), 60, 'Agendado', 'MANUAL', null, null, 100,
    '[{"service_id":"00000000-0000-0000-0000-00000000140d","service_name":"Limpeza de pele","price":100,"duration_minutes":60}]'::jsonb, false)
$$;
create function pg_temp.conclude(p_appt uuid) returns void language plpgsql as $$
begin
  perform public.set_appointment_status_atomic('00000000-0000-0000-0000-00000000140a', p_appt, 'Iniciado');
  perform public.set_appointment_status_atomic('00000000-0000-0000-0000-00000000140a', p_appt, 'Concluído');
end $$;
create function pg_temp.checkout(p_appt uuid, p_req uuid, p_mode text, p_payments jsonb) returns jsonb language sql as $$
  select public.confirm_checkout_atomic('00000000-0000-0000-0000-00000000140a', jsonb_build_object(
    'request_id', p_req, 'appointment_id', p_appt, 'mode', p_mode,
    'items', jsonb_build_array(jsonb_build_object('item_type', 'SERVICE', 'item_id', '00000000-0000-0000-0000-00000000140d',
      'name', 'Limpeza de pele', 'unit_price', 100, 'quantity', 1)),
    'payments', p_payments))
$$;
create temp table t_out (k text primary key, r jsonb) on commit drop;
create temp table t_ids (k text primary key, id uuid) on commit drop;
grant all on t_out, t_ids to authenticated;
grant execute on function pg_temp.expect(boolean, text), pg_temp.state_of(text), pg_temp.login(uuid), pg_temp.logout(),
  pg_temp.booked(uuid, integer), pg_temp.conclude(uuid), pg_temp.checkout(uuid, uuid, text, jsonb) to authenticated;

-- ── Preparação (dona): sete atendimentos; A recebe um sinal de 20 antes de concluir ──
select pg_temp.login('00000000-0000-0000-0000-000000001401');
insert into t_ids values
  ('a', pg_temp.booked('00000000-0000-0000-0000-0000000014c1', 1)),
  ('b', pg_temp.booked('00000000-0000-0000-0000-0000000014c2', 2)),
  ('c', pg_temp.booked('00000000-0000-0000-0000-0000000014c3', 3)),
  ('d', pg_temp.booked('00000000-0000-0000-0000-0000000014c4', 4)),
  ('e', pg_temp.booked('00000000-0000-0000-0000-0000000014c5', 5)),
  ('f', pg_temp.booked('00000000-0000-0000-0000-0000000014c6', 6)),
  ('g', pg_temp.booked('00000000-0000-0000-0000-0000000014c7', 7));
select public.register_appointment_deposit_atomic('00000000-0000-0000-0000-00000000140a', (select id from t_ids where k = 'a'),
  20, 'BIZUM', '00000000-0000-0000-0000-0000000014d1');
select pg_temp.conclude(id) from t_ids;
-- A: total 100, sinal 20 + 80 em dinheiro.
insert into t_out select 'sa', pg_temp.checkout((select id from t_ids where k = 'a'), '00000000-0000-0000-0000-0000000014e1', 'finalize',
  jsonb_build_array(jsonb_build_object('method', 'CASH', 'amount', 80)));
select pg_temp.logout();
select pg_temp.expect((select status = 'Pago' from public.appointments where id = (select id from t_ids where k = 'a')), 'A: atendimento Pago antes do estorno');
select pg_temp.expect((select status = 'applied' from public.appointment_deposits where appointment_id = (select id from t_ids where k = 'a')), 'A: sinal aplicado antes do estorno');

-- ── 1. Permissão: recepção não estorna nem cancela por aqui ──
select pg_temp.login('00000000-0000-0000-0000-000000001403');
select pg_temp.expect(pg_temp.state_of(format($q$select public.refund_sale_atomic('00000000-0000-0000-0000-00000000140a', %L, 'Cliente desistiu', 'caixa', false, null, true)$q$,
  (select r->>'saleId' from t_out where k = 'sa'))) = '42501', 'recepção não estorna e cancela');
select pg_temp.logout();
select pg_temp.expect((select status = 'Pago' from public.appointments where id = (select id from t_ids where k = 'a')), 'A: negado não muda o atendimento');

-- ── 2. Estorna e cancela numa chamada; repetir com a mesma chave não duplica ──
select pg_temp.login('00000000-0000-0000-0000-000000001402');
insert into t_out select 'ra', public.refund_sale_atomic('00000000-0000-0000-0000-00000000140a', (select (r->>'saleId')::uuid from t_out where k = 'sa'),
  'Cliente desistiu do atendimento', 'caixa', false, '00000000-0000-0000-0000-0000000014f1', true);
insert into t_out select 'ra2', public.refund_sale_atomic('00000000-0000-0000-0000-00000000140a', (select (r->>'saleId')::uuid from t_out where k = 'sa'),
  'Cliente desistiu do atendimento', 'caixa', false, '00000000-0000-0000-0000-0000000014f1', true);
select pg_temp.expect(pg_temp.state_of(format($q$select public.refund_sale_atomic('00000000-0000-0000-0000-00000000140a', %L, 'Cliente desistiu do atendimento', 'caixa', false, gen_random_uuid(), true)$q$,
  (select r->>'saleId' from t_out where k = 'sa'))) = 'P0001', 'segunda chamada com outra chave é recusada');
select pg_temp.logout();

select pg_temp.expect((select (r->>'amount')::numeric = 100 and r->>'destination' = 'caixa' and not (r->>'duplicate')::boolean and (r->>'appointmentCancelled')::boolean
  from t_out where k = 'ra'), 'A: estorno de 100 (sinal + dinheiro) no caixa com agendamento cancelado');
select pg_temp.expect((select (r->>'duplicate')::boolean and (r->>'appointmentCancelled')::boolean and r->>'refundId' = (select r->>'refundId' from t_out where k = 'ra')
  from t_out where k = 'ra2'), 'A: repetição devolve o mesmo resultado, ainda cancelado');
select pg_temp.expect((select status = 'Cancelado' and cancel_reason = 'Cliente desistiu do atendimento'
  from public.appointments where id = (select id from t_ids where k = 'a')), 'A: agendamento Cancelado com o motivo');
select pg_temp.expect((select count(*) = 1 from public.appointment_status_history
  where appointment_id = (select id from t_ids where k = 'a') and status = 'Cancelado' and changed_by = '00000000-0000-0000-0000-000000001402'), 'A: histórico de status com quem cancelou');
select pg_temp.expect((select count(*) = 0 from public.appointment_status_history
  where appointment_id = (select id from t_ids where k = 'a') and status = 'Concluído' and notes like 'Comanda estornada%'), 'A: não volta a Concluído');
select pg_temp.expect((select count(*) = 1 from public.audit_logs where table_name = 'appointments' and operation = 'STATUS_CHANGE'
  and record_id = (select id from t_ids where k = 'a') and new_data ->> 'status' = 'Cancelado'
  and new_data ->> 'sale_id' = (select r->>'saleId' from t_out where k = 'sa')), 'A: auditoria da troca de status');
select pg_temp.expect((select status = 'cancelled' and balance = 0 from public.sales where id = (select (r->>'saleId')::uuid from t_out where k = 'sa')), 'A: venda cancelada');
select pg_temp.expect((select status = 'refunded' from public.appointment_deposits where appointment_id = (select id from t_ids where k = 'a')), 'A: sinal aplicado vai para refunded');
select pg_temp.expect((select count(*) > 0 and sum(value) = 100 from public.transactions
  where sale_id = (select (r->>'saleId')::uuid from t_out where k = 'sa') and category = 'estorno'), 'A: saídas de estorno somam 100 (sem duplicar na repetição)');
select pg_temp.expect((select (details ->> 'appointment_cancelled')::boolean from public.sale_refunds
  where sale_id = (select (r->>'saleId')::uuid from t_out where k = 'sa')), 'A: histórico do estorno registra o cancelamento');

-- ── 3. Estorno sem cancelar: assinatura antiga (6 parâmetros) e a nova com false ──
select pg_temp.login('00000000-0000-0000-0000-000000001401');
insert into t_out select 'sb', pg_temp.checkout((select id from t_ids where k = 'b'), '00000000-0000-0000-0000-0000000014e2', 'finalize',
  jsonb_build_array(jsonb_build_object('method', 'CASH', 'amount', 100)));
insert into t_out select 'sc', pg_temp.checkout((select id from t_ids where k = 'c'), '00000000-0000-0000-0000-0000000014e3', 'finalize',
  jsonb_build_array(jsonb_build_object('method', 'CASH', 'amount', 100)));
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000001402');
-- B: sem o 7º argumento (app antigo).
insert into t_out select 'rb', public.refund_sale_atomic('00000000-0000-0000-0000-00000000140a', (select (r->>'saleId')::uuid from t_out where k = 'sb'),
  'Valor lançado errado', 'caixa', false, '00000000-0000-0000-0000-0000000014f2');
-- C: 7 argumentos, cancelar = false.
insert into t_out select 'rc', public.refund_sale_atomic('00000000-0000-0000-0000-00000000140a', (select (r->>'saleId')::uuid from t_out where k = 'sc'),
  'Valor lançado errado', 'caixa', false, '00000000-0000-0000-0000-0000000014f3', false);
select pg_temp.logout();
select pg_temp.expect((select (r->>'amount')::numeric = 100 and not (r->>'appointmentCancelled')::boolean from t_out where k = 'rb'), 'B: assinatura antiga estorna 100 sem cancelar');
select pg_temp.expect((select (r->>'amount')::numeric = 100 and not (r->>'appointmentCancelled')::boolean from t_out where k = 'rc'), 'C: cancelar=false estorna 100 sem cancelar');
select pg_temp.expect((select count(*) = 2 and bool_and(status = 'Concluído' and cancel_reason is null)
  from public.appointments where id in ((select id from t_ids where k = 'b'), (select id from t_ids where k = 'c'))), 'B e C: atendimentos voltam a Concluído');

-- B: cobrar de novo o mesmo atendimento continua possível (nova comanda).
select pg_temp.login('00000000-0000-0000-0000-000000001401');
insert into t_out select 'sb2', pg_temp.checkout((select id from t_ids where k = 'b'), '00000000-0000-0000-0000-0000000014e4', 'finalize',
  jsonb_build_array(jsonb_build_object('method', 'CASH', 'amount', 100)));
select pg_temp.logout();
select pg_temp.expect((select r->>'status' = 'paid' and r->>'saleId' <> (select r->>'saleId' from t_out where k = 'sb') from t_out where k = 'sb2'), 'B: nova comanda depois do estorno sem cancelar');
select pg_temp.expect((select status = 'Pago' from public.appointments where id = (select id from t_ids where k = 'b')), 'B: atendimento Pago de novo');

-- ── 4. Pago Parcial: estorna e cancela, devolvendo em crédito ──
select pg_temp.login('00000000-0000-0000-0000-000000001401');
insert into t_out select 'sd', pg_temp.checkout((select id from t_ids where k = 'd'), '00000000-0000-0000-0000-0000000014e5', 'finalize',
  jsonb_build_array(jsonb_build_object('method', 'CASH', 'amount', 30)));
select pg_temp.logout();
select pg_temp.expect((select status = 'Pago Parcial' from public.appointments where id = (select id from t_ids where k = 'd')), 'D: atendimento Pago Parcial');
select pg_temp.login('00000000-0000-0000-0000-000000001402');
insert into t_out select 'rd', public.refund_sale_atomic('00000000-0000-0000-0000-00000000140a', (select (r->>'saleId')::uuid from t_out where k = 'sd'),
  'Cliente não voltou', 'credito', false, '00000000-0000-0000-0000-0000000014f4', true);
select pg_temp.logout();
select pg_temp.expect((select (r->>'amount')::numeric = 30 and r->>'destination' = 'credito' and (r->>'appointmentCancelled')::boolean from t_out where k = 'rd'), 'D: 30 devolvidos em crédito e agendamento cancelado');
select pg_temp.expect((select status = 'Cancelado' from public.appointments where id = (select id from t_ids where k = 'd')), 'D: agendamento Pago Parcial vira Cancelado');
select pg_temp.expect((select balance = 30 from public.clients where id = '00000000-0000-0000-0000-0000000014c4'), 'D: cliente fica com 30 de crédito (dívida desfeita)');

-- ── 5. Comanda em rascunho + atendimento Concluído: cancela as duas ──
select pg_temp.login('00000000-0000-0000-0000-000000001401');
insert into t_out select 'se', pg_temp.checkout((select id from t_ids where k = 'e'), '00000000-0000-0000-0000-0000000014e6', 'draft', '[]'::jsonb);
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000001402');
insert into t_out select 're', public.refund_sale_atomic('00000000-0000-0000-0000-00000000140a', (select (r->>'saleId')::uuid from t_out where k = 'se'),
  'Cliente desmarcou', 'caixa', false, '00000000-0000-0000-0000-0000000014f5', true);
select pg_temp.logout();
select pg_temp.expect((select (r->>'amount')::numeric = 0 and r->>'destination' = 'nenhum' and (r->>'appointmentCancelled')::boolean from t_out where k = 're'), 'E: rascunho cancelado sem dinheiro');
select pg_temp.expect((select status = 'Cancelado' from public.appointments where id = (select id from t_ids where k = 'e')), 'E: atendimento Concluído vira Cancelado');

-- ── 6. Cancelar Concluído sem comanda ativa (cancel_appointment_settle_deposit_atomic) ──
select pg_temp.login('00000000-0000-0000-0000-000000001401');
-- F: nunca cobrado.
select pg_temp.expect(pg_temp.state_of(format($q$select public.cancel_appointment_settle_deposit_atomic('00000000-0000-0000-0000-00000000140a', %L, 'Lançado por engano', 'fee', false)$q$,
  (select id from t_ids where k = 'f'))) = 'ok', 'F: Concluído sem comanda pode ser cancelado');
-- G: com comanda ativa (rascunho) continua recusado.
insert into t_out select 'sg', pg_temp.checkout((select id from t_ids where k = 'g'), '00000000-0000-0000-0000-0000000014e7', 'draft', '[]'::jsonb);
select pg_temp.expect(pg_temp.state_of(format($q$select public.cancel_appointment_settle_deposit_atomic('00000000-0000-0000-0000-00000000140a', %L, 'Teste', 'fee', false)$q$,
  (select id from t_ids where k = 'g'))) = '22023', 'G: Concluído com comanda ativa segue recusado');
-- C (estornado sem cancelar): sem comanda ativa, pode cancelar.
select pg_temp.expect(pg_temp.state_of(format($q$select public.cancel_appointment_settle_deposit_atomic('00000000-0000-0000-0000-00000000140a', %L, 'Cliente desistiu', 'fee', false)$q$,
  (select id from t_ids where k = 'c'))) = 'ok', 'C: Concluído com a comanda estornada pode ser cancelado');
select pg_temp.logout();
select pg_temp.expect((select status = 'Cancelado' and cancel_reason = 'Lançado por engano' from public.appointments where id = (select id from t_ids where k = 'f')), 'F: Cancelado com motivo');
select pg_temp.expect((select status = 'Cancelado' from public.appointments where id = (select id from t_ids where k = 'c')), 'C: Cancelado depois do estorno');

rollback;
\o
\echo 'estorno e cancelamento do agendamento: ok'
