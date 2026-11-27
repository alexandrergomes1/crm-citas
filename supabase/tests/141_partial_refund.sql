-- Devolução parcial (20261031200000): permissão, parcial em caixa e em crédito, idempotência,
-- limites (valor e forma de pagamento), soma até o valor pago e bloqueio do estorno total depois de parcial.
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

-- ── Preparação (dona): dois atendimentos concluídos e pagos em dinheiro (100 cada) ──
select pg_temp.login('00000000-0000-0000-0000-000000001401');
insert into t_ids values
  ('a', pg_temp.booked('00000000-0000-0000-0000-0000000014c1', 1)),
  ('b', pg_temp.booked('00000000-0000-0000-0000-0000000014c2', 2));
select pg_temp.conclude(id) from t_ids;
insert into t_out select 'sa', pg_temp.checkout((select id from t_ids where k = 'a'), '00000000-0000-0000-0000-0000000014e1', 'finalize',
  jsonb_build_array(jsonb_build_object('method', 'CASH', 'amount', 100)));
insert into t_out select 'sb', pg_temp.checkout((select id from t_ids where k = 'b'), '00000000-0000-0000-0000-0000000014e2', 'finalize',
  jsonb_build_array(jsonb_build_object('method', 'CASH', 'amount', 100)));
select pg_temp.logout();

-- ── 1. Recepção não devolve ──
select pg_temp.login('00000000-0000-0000-0000-000000001403');
select pg_temp.expect(pg_temp.state_of(format($q$select public.partial_refund_sale_atomic('00000000-0000-0000-0000-00000000140a', %L, 30, 'Cobrança a maior', 'caixa', null, null)$q$,
  (select r->>'saleId' from t_out where k = 'sa'))) = '42501', 'recepção não devolve parte');
select pg_temp.logout();

-- ── 2. Parcial no caixa (30 de 100), repetição com a mesma chave não duplica ──
select pg_temp.login('00000000-0000-0000-0000-000000001402');
insert into t_out select 'p1', public.partial_refund_sale_atomic('00000000-0000-0000-0000-00000000140a', (select (r->>'saleId')::uuid from t_out where k = 'sa'),
  30, 'Cobrança a maior', 'caixa', 'CASH', '00000000-0000-0000-0000-0000000014f1');
insert into t_out select 'p1b', public.partial_refund_sale_atomic('00000000-0000-0000-0000-00000000140a', (select (r->>'saleId')::uuid from t_out where k = 'sa'),
  30, 'Cobrança a maior', 'caixa', 'CASH', '00000000-0000-0000-0000-0000000014f1');
select pg_temp.expect((select (r->>'amount')::numeric = 30 and (r->>'remaining')::numeric = 70 and not (r->>'duplicate')::boolean from t_out where k = 'p1'), 'parcial de 30 deixa 70');
select pg_temp.expect((select (r->>'duplicate')::boolean and r->>'refundId' = (select r->>'refundId' from t_out where k = 'p1') from t_out where k = 'p1b'), 'mesma chave devolve o mesmo resultado');
select pg_temp.expect((select count(*) = 1 from public.sale_partial_refunds where sale_id = (select (r->>'saleId')::uuid from t_out where k = 'sa')), 'uma linha só');
select pg_temp.expect((select status = 'paid' from public.sales where id = (select (r->>'saleId')::uuid from t_out where k = 'sa')), 'comanda segue paga');
select pg_temp.expect((select count(*) = 1 and sum(value) = 30 from public.transactions
  where sale_id = (select (r->>'saleId')::uuid from t_out where k = 'sa') and category = 'estorno' and type = 'expense'), 'saída de 30 no caixa');

-- ── 3. Limites ──
select pg_temp.expect(pg_temp.state_of(format($q$select public.partial_refund_sale_atomic('00000000-0000-0000-0000-00000000140a', %L, 80, 'Valor passou', 'caixa', 'CASH', null)$q$,
  (select r->>'saleId' from t_out where k = 'sa'))) = '22023', 'valor acima do restante é recusado');
select pg_temp.expect(pg_temp.state_of(format($q$select public.partial_refund_sale_atomic('00000000-0000-0000-0000-00000000140a', %L, 10, 'Forma errada', 'caixa', 'BIZUM', null)$q$,
  (select r->>'saleId' from t_out where k = 'sa'))) = '22023', 'forma não usada na comanda é recusada');
select pg_temp.expect(pg_temp.state_of(format($q$select public.partial_refund_sale_atomic('00000000-0000-0000-0000-00000000140a', %L, 10, 'abc', 'caixa', 'CASH', null)$q$,
  (select r->>'saleId' from t_out where k = 'sa'))) = '22023', 'motivo curto é recusado');

-- ── 4. Estorno total fica bloqueado depois de parcial ──
select pg_temp.expect(pg_temp.state_of(format($q$select public.refund_sale_atomic('00000000-0000-0000-0000-00000000140a', %L, 'Cliente desistiu', 'caixa', false, null, false)$q$,
  (select r->>'saleId' from t_out where k = 'sa'))) = 'P0001', 'estorno total bloqueado depois de parcial');

-- ── 5. O restante em crédito da cliente; depois não sobra nada ──
insert into t_out select 'p2', public.partial_refund_sale_atomic('00000000-0000-0000-0000-00000000140a', (select (r->>'saleId')::uuid from t_out where k = 'sa'),
  70, 'Devolvendo o restante', 'credito', null, null);
select pg_temp.expect((select (r->>'remaining')::numeric = 0 and r->>'destination' = 'credito' from t_out where k = 'p2'), 'restante em crédito zera');
select pg_temp.expect((select sum(amount) = 100 from public.sale_partial_refunds where sale_id = (select (r->>'saleId')::uuid from t_out where k = 'sa')), 'soma das parciais = valor pago');
select pg_temp.expect(pg_temp.state_of(format($q$select public.partial_refund_sale_atomic('00000000-0000-0000-0000-00000000140a', %L, 1, 'Mais uma', 'caixa', 'CASH', null)$q$,
  (select r->>'saleId' from t_out where k = 'sa'))) = '22023', 'nada mais a devolver');

-- ── 6. Comanda sem parcial continua podendo ser estornada por inteiro ──
insert into t_out select 'full', public.refund_sale_atomic('00000000-0000-0000-0000-00000000140a', (select (r->>'saleId')::uuid from t_out where k = 'sb'),
  'Cliente desistiu', 'caixa', false, null, false);
select pg_temp.expect((select (r->>'amount')::numeric = 100 from t_out where k = 'full'), 'estorno total da outra comanda segue funcionando');
select pg_temp.expect(pg_temp.state_of(format($q$select public.partial_refund_sale_atomic('00000000-0000-0000-0000-00000000140a', %L, 10, 'Depois do total', 'caixa', 'CASH', null)$q$,
  (select r->>'saleId' from t_out where k = 'sb'))) in ('P0001', '22023'), 'sem parcial em comanda já estornada');
select pg_temp.logout();

rollback;
\o
\echo 'devolução parcial: ok'
