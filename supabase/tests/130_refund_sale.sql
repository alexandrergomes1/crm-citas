-- Estorno e cancelamento de comanda (20261030130000, 20261030140000): permissão, motivo, caixa,
-- crédito, vale, pacote, estoque, pontos, idempotência e nova cobrança depois do estorno.
-- Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000001301', 'dona-estorno@teste.local'),
  ('00000000-0000-0000-0000-000000001302', 'fin-estorno@teste.local'),
  ('00000000-0000-0000-0000-000000001303', 'recep-estorno@teste.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-00000000130a', 'estorno-a', 'Estúdio A');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000001301', '00000000-0000-0000-0000-00000000130a', 'owner'),
  ('00000000-0000-0000-0000-000000001302', '00000000-0000-0000-0000-00000000130a', 'finance'),
  ('00000000-0000-0000-0000-000000001303', '00000000-0000-0000-0000-00000000130a', 'receptionist');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-00000000130c', '00000000-0000-0000-0000-00000000130a', 'María José Núñez');
insert into public.staff_members (id, org_id, name) values
  ('00000000-0000-0000-0000-00000000130b', '00000000-0000-0000-0000-00000000130a', 'Karenn');
insert into public.services (id, org_id, name, price, duration_minutes) values
  ('00000000-0000-0000-0000-00000000130d', '00000000-0000-0000-0000-00000000130a', 'Limpeza de pele', 100, 60);
insert into public.products (id, org_id, name, price, stock_qty) values
  ('00000000-0000-0000-0000-00000000130e', '00000000-0000-0000-0000-00000000130a', 'Sérum', 10, 10);
insert into public.gift_cards (id, org_id, code, initial_value, remaining_value) values
  ('00000000-0000-0000-0000-00000000130f', '00000000-0000-0000-0000-00000000130a', 'VALE-130', 50, 50);
insert into public.client_entitlements (id, org_id, client_id, package_name, status, total_sessions, used_sessions, covered_services) values
  ('00000000-0000-0000-0000-0000000130a0', '00000000-0000-0000-0000-00000000130a', '00000000-0000-0000-0000-00000000130c', 'Pacote 5 sessões', 'active', 5, 0, '[]'::jsonb);

-- Cinco atendimentos Concluídos, prontos para cobrar (a inserção só aceita status inicial de agenda).
insert into public.appointments (id, org_id, client_id, client_name, staff_id, start_at, end_at, duration_minutes, status, source, total)
select ('00000000-0000-0000-0000-0000000130e' || n)::uuid, '00000000-0000-0000-0000-00000000130a', '00000000-0000-0000-0000-00000000130c',
       'María José Núñez', '00000000-0000-0000-0000-00000000130b', now() - make_interval(hours => n + 1), now() - make_interval(hours => n), 60,
       'Agendado', 'MANUAL', 100
from generate_series(1, 5) n;
update public.appointments set status = 'Concluído' where org_id = '00000000-0000-0000-0000-00000000130a';

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
create temp table t_out (k text primary key, r jsonb) on commit drop;
grant all on t_out to authenticated;
grant execute on function pg_temp.expect(boolean, text), pg_temp.state_of(text), pg_temp.login(uuid), pg_temp.logout() to authenticated;

-- ── S1: 100 pagos em dinheiro (60) e cartão (40), estorno no caixa ──
select pg_temp.login('00000000-0000-0000-0000-000000001301');
insert into t_out select 's1', public.confirm_checkout_atomic('00000000-0000-0000-0000-00000000130a', jsonb_build_object(
  'request_id', '00000000-0000-0000-0000-0000000130b1', 'appointment_id', '00000000-0000-0000-0000-0000000130e1', 'mode', 'finalize',
  'items', jsonb_build_array(jsonb_build_object('item_type', 'SERVICE', 'item_id', '00000000-0000-0000-0000-00000000130d', 'name', 'Limpeza de pele', 'unit_price', 100, 'quantity', 1)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'CASH', 'amount', 60), jsonb_build_object('method', 'CARD_DEBIT', 'amount', 40))));
select pg_temp.logout();
select pg_temp.expect((select total_spent = 100 and loyalty_points = 100 from public.clients where id = '00000000-0000-0000-0000-00000000130c'),
  'S1: cliente com 100 gastos e 100 pontos antes do estorno');

-- Sem comanda.refund (recepção): recusado. Motivo curto e destino inválido: recusados.
select pg_temp.login('00000000-0000-0000-0000-000000001303');
select pg_temp.expect(pg_temp.state_of(format($q$select public.refund_sale_atomic('00000000-0000-0000-0000-00000000130a', %L, 'Cliente desistiu')$q$,
  (select r->>'saleId' from t_out where k = 's1'))) = '42501', 'recepção não estorna');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000001302');
select pg_temp.expect(pg_temp.state_of(format($q$select public.refund_sale_atomic('00000000-0000-0000-0000-00000000130a', %L, 'ab')$q$,
  (select r->>'saleId' from t_out where k = 's1'))) = '22023', 'motivo curto recusado');
select pg_temp.expect(pg_temp.state_of(format($q$select public.refund_sale_atomic('00000000-0000-0000-0000-00000000130a', %L, 'Cliente desistiu', 'dinheiro')$q$,
  (select r->>'saleId' from t_out where k = 's1'))) = '22023', 'destino inválido recusado');
select pg_temp.expect(pg_temp.state_of($q$select public.refund_sale_atomic('00000000-0000-0000-0000-00000000130a',
  '00000000-0000-0000-0000-0000000130ff', 'Cliente desistiu')$q$) = 'P0002', 'comanda inexistente');

-- Financeiro estorna; a mesma chave repete sem efeito; outra chave é recusada.
insert into t_out select 'r1', public.refund_sale_atomic('00000000-0000-0000-0000-00000000130a', (select (r->>'saleId')::uuid from t_out where k = 's1'),
  'Cliente desistiu do serviço', 'caixa', false, '00000000-0000-0000-0000-0000000130c1');
insert into t_out select 'r1b', public.refund_sale_atomic('00000000-0000-0000-0000-00000000130a', (select (r->>'saleId')::uuid from t_out where k = 's1'),
  'Cliente desistiu do serviço', 'caixa', false, '00000000-0000-0000-0000-0000000130c1');
select pg_temp.expect(pg_temp.state_of(format($q$select public.refund_sale_atomic('00000000-0000-0000-0000-00000000130a', %L, 'Cliente desistiu do serviço', 'caixa', false, gen_random_uuid())$q$,
  (select r->>'saleId' from t_out where k = 's1'))) = 'P0001', 'segundo estorno com outra chave é recusado');
select pg_temp.logout();

select pg_temp.expect((select (r->>'amount')::numeric = 100 and r->>'destination' = 'caixa' and not (r->>'duplicate')::boolean from t_out where k = 'r1'), 'S1: estorno de 100 no caixa');
select pg_temp.expect((select (r->>'duplicate')::boolean and r->>'refundId' = (select r->>'refundId' from t_out where k = 'r1') from t_out where k = 'r1b'), 'S1: repetição devolve o mesmo estorno');
select pg_temp.expect((select status = 'cancelled' and balance = 0 and refunded_at is not null and refund_reason = 'Cliente desistiu do serviço'
  from public.sales where id = (select (r->>'saleId')::uuid from t_out where k = 's1')), 'S1: venda cancelada com motivo');
select pg_temp.expect((select count(*) = 2 and sum(value) = 100 and bool_and(type = 'expense' and category = 'estorno')
  from public.transactions where sale_id = (select (r->>'saleId')::uuid from t_out where k = 's1') and category = 'estorno'), 'S1: duas saídas de estorno somando 100');
select pg_temp.expect((select value = 60 from public.transactions where sale_id = (select (r->>'saleId')::uuid from t_out where k = 's1') and category = 'estorno' and method = 'CASH'),
  'S1: saída de 60 em dinheiro');
select pg_temp.expect((select total_spent = 0 and loyalty_points = 0 and balance = 0 from public.clients where id = '00000000-0000-0000-0000-00000000130c'),
  'S1: gasto, pontos e saldo voltam a zero');
select pg_temp.expect((select status = 'Concluído' from public.appointments where id = '00000000-0000-0000-0000-0000000130e1'), 'S1: atendimento volta a Concluído');
select pg_temp.expect((select count(*) = 1 from public.sale_refunds where org_id = '00000000-0000-0000-0000-00000000130a'
  and sale_id = (select (r->>'saleId')::uuid from t_out where k = 's1') and created_by = '00000000-0000-0000-0000-000000001302'), 'S1: histórico do estorno com quem fez');
select pg_temp.expect((select count(*) = 1 from public.audit_logs where org_id = '00000000-0000-0000-0000-00000000130a' and operation = 'SALE_REFUNDED'), 'S1: auditoria do estorno');

-- O histórico do estorno não se apaga nem se altera pela API.
select pg_temp.login('00000000-0000-0000-0000-000000001302');
select pg_temp.expect(pg_temp.state_of($q$delete from public.sale_refunds$q$) = '42501', 'S1: histórico do estorno não é apagável pela API');
select pg_temp.logout();

-- Cobrar de novo o mesmo atendimento: nova comanda com o número seguinte.
select pg_temp.login('00000000-0000-0000-0000-000000001301');
insert into t_out select 's1b', public.confirm_checkout_atomic('00000000-0000-0000-0000-00000000130a', jsonb_build_object(
  'request_id', '00000000-0000-0000-0000-0000000130b2', 'appointment_id', '00000000-0000-0000-0000-0000000130e1', 'mode', 'finalize',
  'items', jsonb_build_array(jsonb_build_object('item_type', 'SERVICE', 'item_id', '00000000-0000-0000-0000-00000000130d', 'name', 'Limpeza de pele', 'unit_price', 90, 'quantity', 1)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'CASH', 'amount', 90))));
select pg_temp.logout();
select pg_temp.expect((select r->>'status' = 'paid' and r->>'saleId' <> (select r->>'saleId' from t_out where k = 's1') from t_out where k = 's1b'),
  'S1: depois do estorno o atendimento é cobrado em nova comanda');
select pg_temp.expect((select number = 2 from public.sales where id = (select (r->>'saleId')::uuid from t_out where k = 's1b')), 'S1: nova comanda recebe o número 2');

-- ── S2: crédito 20 usado, paga 50 de 100 (falta 30), estorno em crédito ──
update public.clients set balance = 20 where id = '00000000-0000-0000-0000-00000000130c';
select pg_temp.login('00000000-0000-0000-0000-000000001301');
insert into t_out select 's2', public.confirm_checkout_atomic('00000000-0000-0000-0000-00000000130a', jsonb_build_object(
  'request_id', '00000000-0000-0000-0000-0000000130b3', 'appointment_id', '00000000-0000-0000-0000-0000000130e2', 'mode', 'finalize', 'use_credit', true,
  'items', jsonb_build_array(jsonb_build_object('item_type', 'SERVICE', 'item_id', '00000000-0000-0000-0000-00000000130d', 'name', 'Limpeza de pele', 'unit_price', 100, 'quantity', 1)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'CASH', 'amount', 50))));
select pg_temp.logout();
select pg_temp.expect((select balance = -30 from public.clients where id = '00000000-0000-0000-0000-00000000130c'), 'S2: antes do estorno a cliente deve 30');
select pg_temp.login('00000000-0000-0000-0000-000000001302');
insert into t_out select 'r2', public.refund_sale_atomic('00000000-0000-0000-0000-00000000130a', (select (r->>'saleId')::uuid from t_out where k = 's2'),
  'Erro de lançamento', 'credito');
select pg_temp.logout();
select pg_temp.expect((select balance = 70 from public.clients where id = '00000000-0000-0000-0000-00000000130c'),
  'S2: saldo = 20 de crédito original + 50 pagos devolvidos em crédito');
select pg_temp.expect((select count(*) = 1 and sum(value) = 50 and min(method) = 'CLIENT_CREDIT' from public.transactions
  where sale_id = (select (r->>'saleId')::uuid from t_out where k = 's2') and category = 'estorno'), 'S2: saída de 50 em crédito da cliente');
select pg_temp.expect((select destination = 'credito' and amount = 50 from public.sale_refunds where sale_id = (select (r->>'saleId')::uuid from t_out where k = 's2')),
  'S2: histórico com destino crédito');
select pg_temp.expect((select coalesce(sum(amount), 0) = 50 from public.client_balance_entries
  where sale_id = (select (r->>'saleId')::uuid from t_out where k = 's2')), 'S2: extrato da venda soma só o crédito devolvido');

-- ── S3: vale-presente 30 + dinheiro 30, produto 2 × 10 e serviço 40; estorno devolve vale e estoque ──
select pg_temp.login('00000000-0000-0000-0000-000000001301');
insert into t_out select 's3', public.confirm_checkout_atomic('00000000-0000-0000-0000-00000000130a', jsonb_build_object(
  'request_id', '00000000-0000-0000-0000-0000000130b4', 'appointment_id', '00000000-0000-0000-0000-0000000130e3', 'mode', 'finalize',
  'items', jsonb_build_array(
    jsonb_build_object('item_type', 'SERVICE', 'item_id', '00000000-0000-0000-0000-00000000130d', 'name', 'Limpeza de pele', 'unit_price', 40, 'quantity', 1),
    jsonb_build_object('item_type', 'PRODUCT', 'item_id', '00000000-0000-0000-0000-00000000130e', 'name', 'Sérum', 'unit_price', 10, 'quantity', 2)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'GIFT_CARD', 'amount', 30, 'gift_card_code', 'VALE-130'), jsonb_build_object('method', 'CASH', 'amount', 30))));
select pg_temp.logout();
select pg_temp.expect((select stock_qty = 8 from public.products where id = '00000000-0000-0000-0000-00000000130e'), 'S3: venda baixou 2 do estoque');
select pg_temp.expect((select remaining_value = 20 from public.gift_cards where id = '00000000-0000-0000-0000-00000000130f'), 'S3: vale usado 30');
select pg_temp.login('00000000-0000-0000-0000-000000001302');
insert into t_out select 'r3', public.refund_sale_atomic('00000000-0000-0000-0000-00000000130a', (select (r->>'saleId')::uuid from t_out where k = 's3'),
  'Produto devolvido', 'caixa', true);
select pg_temp.logout();
select pg_temp.expect((select remaining_value = 50 and status = 'active' from public.gift_cards where id = '00000000-0000-0000-0000-00000000130f'), 'S3: vale volta aos 50');
select pg_temp.expect((select stock_qty = 10 from public.products where id = '00000000-0000-0000-0000-00000000130e'), 'S3: estoque devolvido');
select pg_temp.expect((select count(*) = 1 and sum(value) = 30 and min(method) = 'CASH' from public.transactions
  where sale_id = (select (r->>'saleId')::uuid from t_out where k = 's3') and category = 'estorno'), 'S3: só o dinheiro sai do caixa (30)');
select pg_temp.expect((select count(*) = 1 from public.stock_entries where product_id = '00000000-0000-0000-0000-00000000130e' and type = 'entrada' and quantity = 2),
  'S3: entrada de estoque registrada');

-- ── S4: serviço coberto por pacote (sem dinheiro); estorno devolve a sessão ──
select pg_temp.login('00000000-0000-0000-0000-000000001301');
insert into t_out select 's4', public.confirm_checkout_atomic('00000000-0000-0000-0000-00000000130a', jsonb_build_object(
  'request_id', '00000000-0000-0000-0000-0000000130b5', 'appointment_id', '00000000-0000-0000-0000-0000000130e4', 'mode', 'finalize',
  'items', jsonb_build_array(jsonb_build_object('item_type', 'SERVICE', 'item_id', '00000000-0000-0000-0000-00000000130d', 'name', 'Limpeza de pele',
    'unit_price', 0, 'quantity', 1, 'entitlement_id', '00000000-0000-0000-0000-0000000130a0', 'covered_by_entitlement', true)),
  'payments', '[]'::jsonb));
select pg_temp.logout();
select pg_temp.expect((select used_sessions = 1 from public.client_entitlements where id = '00000000-0000-0000-0000-0000000130a0'), 'S4: pacote consumiu 1 sessão');
select pg_temp.login('00000000-0000-0000-0000-000000001302');
insert into t_out select 'r4', public.refund_sale_atomic('00000000-0000-0000-0000-00000000130a', (select (r->>'saleId')::uuid from t_out where k = 's4'), 'Sessão lançada por engano');
select pg_temp.logout();
select pg_temp.expect((select used_sessions = 0 and status = 'active' from public.client_entitlements where id = '00000000-0000-0000-0000-0000000130a0'), 'S4: sessão devolvida');
select pg_temp.expect((select count(*) = 1 from public.client_entitlement_entries where entitlement_id = '00000000-0000-0000-0000-0000000130a0' and action = 'restore' and sessions_delta = 1),
  'S4: extrato do pacote registra a devolução');
select pg_temp.expect((select destination = 'nenhum' and amount = 0 from public.sale_refunds where sale_id = (select (r->>'saleId')::uuid from t_out where k = 's4')),
  'S4: sem dinheiro, destino nenhum');

-- ── S5: rascunho cancelado, sem movimento ──
select pg_temp.login('00000000-0000-0000-0000-000000001301');
insert into t_out select 's5', public.confirm_checkout_atomic('00000000-0000-0000-0000-00000000130a', jsonb_build_object(
  'request_id', '00000000-0000-0000-0000-0000000130b6', 'appointment_id', '00000000-0000-0000-0000-0000000130e5', 'mode', 'draft',
  'items', jsonb_build_array(jsonb_build_object('item_type', 'SERVICE', 'item_id', '00000000-0000-0000-0000-00000000130d', 'name', 'Limpeza de pele', 'unit_price', 100, 'quantity', 1)),
  'payments', '[]'::jsonb));
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000001302');
insert into t_out select 'r5', public.refund_sale_atomic('00000000-0000-0000-0000-00000000130a', (select (r->>'saleId')::uuid from t_out where k = 's5'), 'Cliente não veio');
select pg_temp.logout();
select pg_temp.expect((select status = 'cancelled' from public.sales where id = (select (r->>'saleId')::uuid from t_out where k = 's5')), 'S5: rascunho cancelado');
select pg_temp.expect((select count(*) = 0 from public.transactions where sale_id = (select (r->>'saleId')::uuid from t_out where k = 's5')), 'S5: nenhum lançamento no caixa');
select pg_temp.expect((select count(*) = 1 from public.audit_logs where operation = 'SALE_CANCELLED'), 'S5: auditoria de cancelamento');

-- Pontos: só a comanda cobrada de novo (S1b, 90) e o crédito não estornado contam no fim.
select pg_temp.expect((select loyalty_points = 90 from public.clients where id = '00000000-0000-0000-0000-00000000130c'),
  'pontos finais: só a comanda S1b (90) ficou');

rollback;
\o
\echo 'estorno de comanda: ok'
