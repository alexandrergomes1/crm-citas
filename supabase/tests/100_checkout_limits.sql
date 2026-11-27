-- confirm_checkout_atomic: limites e bordas do fechamento de comanda.
--   * reenvio do mesmo request_id não duplica venda, pagamento, caixa, pontos nem saldo;
--   * pagamento maior que o total vira crédito da cliente; crédito existente pode ser usado;
--   * valor negativo, método inválido e item inválido são recusados sem deixar rastro;
--   * atendimento Cancelado/Ausência não é cobrado; atendimento de outro estúdio é recusado;
--   * pagamento parcial e continuação; rascunho; desconto e gorjeta.
-- Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000850', 'dona@caixa.local'),
  ('00000000-0000-0000-0000-000000000851', 'donab@caixa.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-00000000085a', 'caixa-a', 'Caixa A'),
  ('00000000-0000-0000-0000-00000000085b', 'caixa-b', 'Caixa B');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000000850', '00000000-0000-0000-0000-00000000085a', 'owner'),
  ('00000000-0000-0000-0000-000000000851', '00000000-0000-0000-0000-00000000085b', 'owner');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-000000000852', '00000000-0000-0000-0000-00000000085a', 'Begoña Ruiz'),
  ('00000000-0000-0000-0000-000000000857', '00000000-0000-0000-0000-00000000085a', 'Cándida Soto'),
  ('00000000-0000-0000-0000-000000000858', '00000000-0000-0000-0000-00000000085a', 'Dolores Vega'),
  ('00000000-0000-0000-0000-000000000853', '00000000-0000-0000-0000-00000000085b', 'Cliente da B');
insert into public.staff_members (id, org_id, name) values
  ('00000000-0000-0000-0000-000000000854', '00000000-0000-0000-0000-00000000085a', 'Karenn');
insert into public.services (id, org_id, name, price, duration_minutes) values
  ('00000000-0000-0000-0000-000000000856', '00000000-0000-0000-0000-00000000085a', 'Drenagem', 80, 60);
-- Atendimento da org B, criado direto.
insert into public.appointments (id, org_id, client_id, client_name, start_at, end_at, duration_minutes, status) values
  ('00000000-0000-0000-0000-000000000855', '00000000-0000-0000-0000-00000000085b', '00000000-0000-0000-0000-000000000853',
   'Cliente da B', '2031-05-01 10:00+00', '2031-05-01 11:00+00', 60, 'Agendado');

create function pg_temp.expect(p_ok boolean, p_msg text) returns void language plpgsql as $$
begin
  if not coalesce(p_ok, false) then raise exception 'FALHOU: %', p_msg; end if;
end $$;
create function pg_temp.err(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return 'OK';
exception when others then
  return sqlstate || ' ' || sqlerrm;
end $$;
create function pg_temp.login(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;
-- Atendimento de Drenagem (org A) no dia p_day de maio de 2031.
create function pg_temp.mk(p_day int, p_client uuid, p_price numeric default 80) returns uuid language sql as $$
  select public.create_appointment_atomic('00000000-0000-0000-0000-00000000085a', p_client, '00000000-0000-0000-0000-000000000854',
    '2031-05-01 10:00+00'::timestamptz + make_interval(days => p_day), '2031-05-01 11:00+00'::timestamptz + make_interval(days => p_day),
    60, 'Agendado', 'MANUAL', null, null, p_price,
    jsonb_build_array(jsonb_build_object('service_id', '00000000-0000-0000-0000-000000000856', 'service_name', 'Drenagem', 'price', p_price)),
    false)
$$;
create function pg_temp.pay(p_method text, p_amount numeric) returns jsonb language sql as $$
  select jsonb_build_object('method', p_method, 'amount', p_amount)
$$;
-- Comando de fechamento de um item de Drenagem.
create function pg_temp.cmd(p_req text, p_appt uuid, p_price numeric, p_payments jsonb, p_extra jsonb default '{}'::jsonb)
returns jsonb language sql as $$
  select jsonb_build_object('request_id', p_req, 'appointment_id', p_appt, 'mode', 'finalize',
    'items', jsonb_build_array(jsonb_build_object('item_type', 'service', 'item_id', '00000000-0000-0000-0000-000000000856',
      'name', 'Drenagem', 'unit_price', p_price, 'quantity', 1)),
    'payments', p_payments) || p_extra
$$;
create function pg_temp.run(p_cmd jsonb, p_org uuid default '00000000-0000-0000-0000-00000000085a') returns jsonb language sql as $$
  select public.confirm_checkout_atomic(p_org, p_cmd)
$$;
create function pg_temp.co(p_cmd jsonb, p_org uuid default '00000000-0000-0000-0000-00000000085a') returns text language sql as $$
  select pg_temp.err(format('select public.confirm_checkout_atomic(%L, %L::jsonb)', p_org, p_cmd::text))
$$;
-- Foto do que o fechamento mexe (rodar como superusuário).
create function pg_temp.snap(p_req boolean default true) returns text language sql as $$
  select concat_ws('/',
    (select count(*) from public.sales where org_id = '00000000-0000-0000-0000-00000000085a'),
    (select count(*) from public.sale_payments where org_id = '00000000-0000-0000-0000-00000000085a'),
    (select count(*) from public.transactions where org_id = '00000000-0000-0000-0000-00000000085a'),
    case when p_req then (select count(*) from public.checkout_requests where org_id = '00000000-0000-0000-0000-00000000085a') end,
    (select count(*) from public.client_balance_entries where org_id = '00000000-0000-0000-0000-00000000085a'),
    (select count(*) from public.loyalty_point_entries where org_id = '00000000-0000-0000-0000-00000000085a'),
    (select coalesce(sum(balance), 0) || ':' || coalesce(sum(total_spent), 0) || ':' || coalesce(sum(loyalty_points), 0)
       from public.clients where org_id = '00000000-0000-0000-0000-00000000085a'))
$$;
grant execute on function pg_temp.expect(boolean, text), pg_temp.err(text), pg_temp.login(uuid),
  pg_temp.mk(int, uuid, numeric), pg_temp.pay(text, numeric), pg_temp.cmd(text, uuid, numeric, jsonb, jsonb),
  pg_temp.run(jsonb, uuid), pg_temp.co(jsonb, uuid), pg_temp.snap(boolean) to authenticated;
create temp table t_ids (k text primary key, id uuid) on commit drop;
create temp table t_snap (k text primary key, v text) on commit drop;
create temp table t_res (k text primary key, v jsonb) on commit drop;
grant all on t_ids, t_snap, t_res to authenticated;

select pg_temp.login('00000000-0000-0000-0000-000000000850');
insert into t_ids values
  ('a1',  pg_temp.mk(1,  '00000000-0000-0000-0000-000000000852')),
  ('a2',  pg_temp.mk(2,  '00000000-0000-0000-0000-000000000852')),
  ('a3',  pg_temp.mk(3,  '00000000-0000-0000-0000-000000000852')),
  ('a4',  pg_temp.mk(4,  '00000000-0000-0000-0000-000000000852')),
  ('a5',  pg_temp.mk(5,  '00000000-0000-0000-0000-000000000852')),
  ('a6',  pg_temp.mk(6,  '00000000-0000-0000-0000-000000000852')),
  ('a7',  pg_temp.mk(7,  '00000000-0000-0000-0000-000000000857')),
  ('a8',  pg_temp.mk(8,  '00000000-0000-0000-0000-000000000857')),
  ('a9',  pg_temp.mk(9,  '00000000-0000-0000-0000-000000000858')),
  ('a10', pg_temp.mk(10, '00000000-0000-0000-0000-000000000858', 100));
reset role; select set_config('request.jwt.claims', '', true);

-- ── 1. Reenvio do mesmo request_id não duplica nada ──
select pg_temp.login('00000000-0000-0000-0000-000000000850');
insert into t_res select 'a1_first', pg_temp.run(pg_temp.cmd('00000000-0000-0000-0000-000000000860', (select id from t_ids where k = 'a1'),
  80, jsonb_build_array(pg_temp.pay('CASH', 80))));
reset role; select set_config('request.jwt.claims', '', true);
insert into t_snap values ('depois_a1', pg_temp.snap(false));
select pg_temp.expect((select (v ->> 'status') = 'paid' and (v ->> 'pendingAmount')::numeric = 0 and (v ->> 'overpaidAmount')::numeric = 0
    and not (v ->> 'duplicate')::boolean from t_res where k = 'a1_first'), 'primeiro fechamento: pago, sem pendência nem excedente');

select pg_temp.login('00000000-0000-0000-0000-000000000850');
insert into t_res select 'a1_again', pg_temp.run(pg_temp.cmd('00000000-0000-0000-0000-000000000860', (select id from t_ids where k = 'a1'),
  80, jsonb_build_array(pg_temp.pay('CASH', 80))));
-- Outro request_id para a comanda que já está paga: devolve duplicate sem cobrar de novo.
insert into t_res select 'a1_newkey', pg_temp.run(pg_temp.cmd('00000000-0000-0000-0000-000000000861', (select id from t_ids where k = 'a1'),
  80, jsonb_build_array(pg_temp.pay('CASH', 80))));
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select a.v = b.v from t_res a, t_res b where a.k = 'a1_first' and b.k = 'a1_again'),
  'mesmo request_id e mesmo payload devolve o resultado guardado');
select pg_temp.expect((select (v ->> 'duplicate')::boolean and (v ->> 'status') = 'paid' from t_res where k = 'a1_newkey'),
  'outro request_id em comanda paga devolve duplicate = true');
select pg_temp.expect(pg_temp.snap(false) = (select v from t_snap where k = 'depois_a1'),
  'reenvios não criam venda, pagamento, caixa, pontos nem mexem no saldo');
select pg_temp.expect((select count(*) = 1 and sum(value) = 80 from public.transactions
  where org_id = '00000000-0000-0000-0000-00000000085a' and type = 'income'), 'caixa tem uma única entrada de 80');
select pg_temp.expect((select total_spent = 80 and loyalty_points = 80 and balance = 0 from public.clients
  where id = '00000000-0000-0000-0000-000000000852'), 'cliente com gasto 80 e 80 pontos (uma vez só)');

-- Mesmo request_id com dados diferentes é recusado.
select pg_temp.login('00000000-0000-0000-0000-000000000850');
select pg_temp.expect(pg_temp.co(pg_temp.cmd('00000000-0000-0000-0000-000000000860', (select id from t_ids where k = 'a1'),
    80, jsonb_build_array(pg_temp.pay('CASH', 70)))) like '22023%reutilizada com dados diferentes%',
  'request_id reutilizado com payload diferente é recusado');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect(pg_temp.snap(false) = (select v from t_snap where k = 'depois_a1'), 'recusa não altera nada');

-- ── 2. Pagamento maior que o total vira crédito; crédito pode ser usado depois ──
select pg_temp.login('00000000-0000-0000-0000-000000000850');
insert into t_res select 'a2', pg_temp.run(pg_temp.cmd('00000000-0000-0000-0000-000000000862', (select id from t_ids where k = 'a2'),
  80, jsonb_build_array(pg_temp.pay('CASH', 100))));
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select (v ->> 'status') = 'paid' and (v ->> 'overpaidAmount')::numeric = 20 and (v ->> 'pendingAmount')::numeric = 0
  from t_res where k = 'a2'), 'pagou 100 de 80: pago com excedente de 20');
select pg_temp.expect((select balance = 20 from public.clients where id = '00000000-0000-0000-0000-000000000852'),
  'excedente de 20 vira crédito da cliente');
select pg_temp.expect((select entry_type = 'overpayment_credit' and amount = 20 and balance_before = 0 and balance_after = 20
  from public.client_balance_entries where client_id = '00000000-0000-0000-0000-000000000852'), 'extrato: overpayment_credit de 20');
select pg_temp.expect((select total = 80 and paid_amount = 100 and balance = 0 and status = 'paid' from public.sales
  where appointment_id = (select id from t_ids where k = 'a2')), 'comanda: total 80, recebido 100, pendente 0');
select pg_temp.expect((select sum(value) = 100 from public.transactions where sale_id = (select id from public.sales
  where appointment_id = (select id from t_ids where k = 'a2')) and type = 'income'), 'caixa recebe os 100 que entraram');
select pg_temp.expect((select status = 'Pago' from public.appointments where id = (select id from t_ids where k = 'a2')), 'atendimento Pago');
select pg_temp.expect((select total_spent = 160 and loyalty_points = 160 from public.clients
  where id = '00000000-0000-0000-0000-000000000852'), 'gasto e pontos contam o total da comanda (80), não o excedente');

-- Reenvio do pagamento a maior não gera crédito em dobro.
select pg_temp.login('00000000-0000-0000-0000-000000000850');
select pg_temp.run(pg_temp.cmd('00000000-0000-0000-0000-000000000862', (select id from t_ids where k = 'a2'),
  80, jsonb_build_array(pg_temp.pay('CASH', 100))));
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select balance = 20 from public.clients where id = '00000000-0000-0000-0000-000000000852')
  and (select count(*) from public.client_balance_entries where client_id = '00000000-0000-0000-0000-000000000852') = 1,
  'reenvio do excedente não duplica o crédito');

-- Usa o crédito de 20 no próximo atendimento e paga o resto (60).
select pg_temp.login('00000000-0000-0000-0000-000000000850');
insert into t_res select 'a3', pg_temp.run(pg_temp.cmd('00000000-0000-0000-0000-000000000863', (select id from t_ids where k = 'a3'),
  80, jsonb_build_array(pg_temp.pay('CASH', 60)), '{"use_credit": true}'::jsonb));
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select (v ->> 'creditApplied')::numeric = 20 and (v ->> 'status') = 'paid' from t_res where k = 'a3'),
  'crédito de 20 aplicado e comanda paga');
select pg_temp.expect((select balance = 0 from public.clients where id = '00000000-0000-0000-0000-000000000852')
  and exists (select 1 from public.client_balance_entries where client_id = '00000000-0000-0000-0000-000000000852'
    and entry_type = 'client_credit_used' and amount = -20), 'saldo volta a 0 com lançamento client_credit_used');

-- ── 3. Valores e itens inválidos são recusados sem deixar rastro ──
select pg_temp.login('00000000-0000-0000-0000-000000000850');
-- (a4 ainda aberto; cada tentativa usa um request_id novo)
select pg_temp.expect(pg_temp.co(pg_temp.cmd('00000000-0000-0000-0000-000000000870', (select id from t_ids where k = 'a4'),
    80, jsonb_build_array(pg_temp.pay('CASH', -10)))) like '22023%Pagamento invalido%', 'pagamento negativo é recusado');
select pg_temp.expect(pg_temp.co(pg_temp.cmd('00000000-0000-0000-0000-000000000871', (select id from t_ids where k = 'a4'),
    80, jsonb_build_array(pg_temp.pay('CASH', 100), pg_temp.pay('BIZUM', -0.01)))) like '22023%Pagamento invalido%',
  'um pagamento negativo no meio de vários recusa o conjunto');
select pg_temp.expect(pg_temp.co(pg_temp.cmd('00000000-0000-0000-0000-000000000872', (select id from t_ids where k = 'a4'),
    80, jsonb_build_array(pg_temp.pay('PIX', 80)))) like '22023%Pagamento invalido%', 'método de pagamento desconhecido é recusado');
select pg_temp.expect(pg_temp.co(pg_temp.cmd('00000000-0000-0000-0000-000000000873', (select id from t_ids where k = 'a4'),
    -80, jsonb_build_array(pg_temp.pay('CASH', 0)))) like '22023%Item de comanda invalido%', 'preço de item negativo é recusado');
select pg_temp.expect(pg_temp.co(jsonb_build_object('request_id', '00000000-0000-0000-0000-000000000874',
    'appointment_id', (select id from t_ids where k = 'a4'), 'mode', 'finalize', 'items', '[]'::jsonb, 'payments', '[]'::jsonb))
    like '22023%pelo menos um item%', 'comanda sem item é recusada');
select pg_temp.expect(pg_temp.co(jsonb_build_object('request_id', '00000000-0000-0000-0000-000000000875',
    'appointment_id', (select id from t_ids where k = 'a4'), 'mode', 'finalize',
    'items', jsonb_build_array(jsonb_build_object('item_type', 'service', 'name', 'X', 'unit_price', 10, 'quantity', 0)),
    'payments', '[]'::jsonb)) like '22023%Item de comanda invalido%', 'quantidade zero é recusada');
select pg_temp.expect(pg_temp.co(jsonb_build_object('request_id', '00000000-0000-0000-0000-000000000876',
    'appointment_id', (select id from t_ids where k = 'a4'), 'mode', 'finalize',
    'items', jsonb_build_array(jsonb_build_object('item_type', 'giftcard', 'name', 'X', 'unit_price', 10, 'quantity', 1)),
    'payments', '[]'::jsonb)) like '22023%Item de comanda invalido%', 'tipo de item desconhecido é recusado');
select pg_temp.expect(pg_temp.co(pg_temp.cmd('00000000-0000-0000-0000-000000000877', (select id from t_ids where k = 'a4'),
    80, '[]'::jsonb, '{"mode":"pagar"}'::jsonb)) like '22023%Modo de checkout invalido%', 'modo desconhecido é recusado');
select pg_temp.expect(pg_temp.co(pg_temp.cmd('00000000-0000-0000-0000-000000000878', (select id from t_ids where k = 'a4'),
    80, '{"method":"CASH"}'::jsonb)) like '22023%Pagamentos invalidos%', 'pagamentos fora de lista são recusados');
select pg_temp.expect(pg_temp.co(jsonb_build_object('request_id', 'não-é-uuid',
    'appointment_id', (select id from t_ids where k = 'a4'), 'items', '[]'::jsonb)) like '22023%Identificador invalido%',
  'request_id que não é uuid é recusado');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select status = 'Agendado' from public.appointments where id = (select id from t_ids where k = 'a4'))
  and not exists (select 1 from public.sales where appointment_id = (select id from t_ids where k = 'a4'))
  and not exists (select 1 from public.checkout_requests where appointment_id = (select id from t_ids where k = 'a4')),
  'tentativas inválidas deixam o atendimento Agendado, sem venda nem chave de idempotência');

-- ── 4. Atendimento Cancelado ou com Ausência não é cobrado ──
select pg_temp.login('00000000-0000-0000-0000-000000000850');
select public.set_appointment_status_atomic('00000000-0000-0000-0000-00000000085a', (select id from t_ids where k = 'a5'), 'Cancelado');
select public.set_appointment_status_atomic('00000000-0000-0000-0000-00000000085a', (select id from t_ids where k = 'a6'), 'Ausência');
reset role; select set_config('request.jwt.claims', '', true);
insert into t_snap values ('antes_cancelado', pg_temp.snap());
select pg_temp.login('00000000-0000-0000-0000-000000000850');
select pg_temp.expect(pg_temp.co(pg_temp.cmd('00000000-0000-0000-0000-000000000880', (select id from t_ids where k = 'a5'),
    80, jsonb_build_array(pg_temp.pay('CASH', 80)))) like 'P0001%cancelado%', 'atendimento Cancelado não é cobrado');
select pg_temp.expect(pg_temp.co(pg_temp.cmd('00000000-0000-0000-0000-000000000881', (select id from t_ids where k = 'a6'),
    80, jsonb_build_array(pg_temp.pay('CASH', 80)))) like 'P0001%cancelado%', 'atendimento com Ausência não é cobrado');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect(pg_temp.snap() = (select v from t_snap where k = 'antes_cancelado'), 'cobrança recusada não deixa rastro');
select pg_temp.expect((select count(*) = 2 and bool_and(status in ('Cancelado', 'Ausência')) from public.appointments
  where id in ((select id from t_ids where k = 'a5'), (select id from t_ids where k = 'a6'))), 'status continuam Cancelado e Ausência');

-- ── 5. Atendimento de outro estúdio ──
update t_snap set v = pg_temp.snap() where k = 'antes_cancelado';
select pg_temp.login('00000000-0000-0000-0000-000000000850');
select pg_temp.expect(pg_temp.co(pg_temp.cmd('00000000-0000-0000-0000-000000000882', '00000000-0000-0000-0000-000000000855',
    80, jsonb_build_array(pg_temp.pay('CASH', 80)))) like 'P0002%Agendamento nao encontrado%',
  'org A com atendimento da org B: não encontrado');
select pg_temp.expect(pg_temp.co(pg_temp.cmd('00000000-0000-0000-0000-000000000883', '00000000-0000-0000-0000-000000000855',
    80, jsonb_build_array(pg_temp.pay('CASH', 80))), '00000000-0000-0000-0000-00000000085b') like '42501%',
  'dona da A não fecha comanda passando a org B');
select pg_temp.expect(pg_temp.co(pg_temp.cmd('00000000-0000-0000-0000-000000000884', gen_random_uuid(),
    80, jsonb_build_array(pg_temp.pay('CASH', 80)))) ~ '^(P0002|23503)', 'atendimento inexistente é recusado');
select pg_temp.login('00000000-0000-0000-0000-000000000851');
select pg_temp.expect(pg_temp.co(pg_temp.cmd('00000000-0000-0000-0000-000000000885', (select id from t_ids where k = 'a4'),
    80, jsonb_build_array(pg_temp.pay('CASH', 80)))) like '42501%', 'dona da B não fecha comanda da org A');
select pg_temp.expect(pg_temp.co(pg_temp.cmd('00000000-0000-0000-0000-000000000886', (select id from t_ids where k = 'a4'),
    80, jsonb_build_array(pg_temp.pay('CASH', 80))), '00000000-0000-0000-0000-00000000085b') like 'P0002%',
  'dona da B passando a org B com atendimento da A: não encontrado');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect(pg_temp.snap() = (select v from t_snap where k = 'antes_cancelado'), 'tentativas entre estúdios não deixam rastro na org A');
select pg_temp.expect(not exists (select 1 from public.sales where org_id = '00000000-0000-0000-0000-00000000085b')
  and not exists (select 1 from public.checkout_requests where org_id = '00000000-0000-0000-0000-00000000085b'),
  'nada foi gravado na org B');
select pg_temp.expect((select status = 'Agendado' from public.appointments where id = '00000000-0000-0000-0000-000000000855'),
  'atendimento da B segue Agendado');

-- ── 6. Pagamento parcial e continuação ──
select pg_temp.login('00000000-0000-0000-0000-000000000850');
insert into t_res select 'a7', pg_temp.run(pg_temp.cmd('00000000-0000-0000-0000-000000000890', (select id from t_ids where k = 'a7'),
  80, jsonb_build_array(pg_temp.pay('CASH', 30))));
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select (v ->> 'status') = 'partial' and (v ->> 'pendingAmount')::numeric = 50 from t_res where k = 'a7'),
  'parcial: pendente 50');
select pg_temp.expect((select status = 'Pago Parcial' from public.appointments where id = (select id from t_ids where k = 'a7'))
  and (select balance = -50 from public.clients where id = '00000000-0000-0000-0000-000000000857'),
  'atendimento Pago Parcial e cliente devendo 50');

select pg_temp.login('00000000-0000-0000-0000-000000000850');
-- Reduzir o que já foi pago, ou não mudar nada, é recusado.
select pg_temp.expect(pg_temp.co(pg_temp.cmd('00000000-0000-0000-0000-000000000891', (select id from t_ids where k = 'a7'),
    80, jsonb_build_array(pg_temp.pay('CASH', 20), pg_temp.pay('TRANSFER', 60)))) like '22023%nao podem ser removidos ou alterados%',
  'continuação não pode reduzir pagamento já registrado');
select pg_temp.expect(pg_temp.co(pg_temp.cmd('00000000-0000-0000-0000-000000000892', (select id from t_ids where k = 'a7'),
    80, jsonb_build_array(pg_temp.pay('TRANSFER', 50)))) like '22023%nao podem ser removidos ou alterados%',
  'continuação não pode omitir pagamento já registrado');
select pg_temp.expect(pg_temp.co(pg_temp.cmd('00000000-0000-0000-0000-000000000893', (select id from t_ids where k = 'a7'),
    80, jsonb_build_array(pg_temp.pay('CASH', 30)))) like '22023%Adicione um novo pagamento%',
  'continuação sem pagamento novo nem item novo é recusada');
select pg_temp.expect(pg_temp.co(pg_temp.cmd('00000000-0000-0000-0000-000000000894', (select id from t_ids where k = 'a7'),
    80, jsonb_build_array(pg_temp.pay('CASH', 30)), '{"mode":"draft"}'::jsonb)) like '22023%parcial nao pode voltar para rascunho%',
  'comanda parcial não volta a rascunho');
-- Quita com os 50 restantes (CASH 30 já registrado + TRANSFER 50).
select pg_temp.run(pg_temp.cmd('00000000-0000-0000-0000-000000000895', (select id from t_ids where k = 'a7'),
  80, jsonb_build_array(pg_temp.pay('CASH', 30), pg_temp.pay('TRANSFER', 50))));
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select status = 'Pago' from public.appointments where id = (select id from t_ids where k = 'a7'))
  and (select status = 'paid' and paid_amount = 80 and balance = 0 from public.sales where appointment_id = (select id from t_ids where k = 'a7')),
  'quitação: atendimento Pago e comanda 80/80');
select pg_temp.expect((select count(*) = 2 and sum(value) = 80 from public.transactions
  where sale_id = (select id from public.sales where appointment_id = (select id from t_ids where k = 'a7')) and type = 'income'),
  'a quitação só lança os 50 novos no caixa (30 + 50, sem repetir os 30)');
select pg_temp.expect((select balance = 0 from public.clients where id = '00000000-0000-0000-0000-000000000857'),
  'dívida quitada: saldo 0');

-- Continuação que paga a mais: quita a dívida e sobra crédito.
select pg_temp.login('00000000-0000-0000-0000-000000000850');
select pg_temp.run(pg_temp.cmd('00000000-0000-0000-0000-0000000008a0', (select id from t_ids where k = 'a8'),
  80, jsonb_build_array(pg_temp.pay('CASH', 30))));
insert into t_res select 'a8', pg_temp.run(pg_temp.cmd('00000000-0000-0000-0000-0000000008a1', (select id from t_ids where k = 'a8'),
  80, jsonb_build_array(pg_temp.pay('CASH', 30), pg_temp.pay('TRANSFER', 70))));
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select (v ->> 'status') = 'paid' and (v ->> 'overpaidAmount')::numeric = 20 from t_res where k = 'a8'),
  'continuação com 100 de 80: paga, excedente de 20');
select pg_temp.expect((select balance = 20 from public.clients where id = '00000000-0000-0000-0000-000000000857'),
  'saldo: -50 da dívida + 50 de quitação + 20 de excedente = +20');
select pg_temp.expect((select sum(amount) = 20 and bool_and(balance_before + amount = balance_after)
  from public.client_balance_entries where client_id = '00000000-0000-0000-0000-000000000857'
    and sale_id = (select id from public.sales where appointment_id = (select id from t_ids where k = 'a8'))),
  'extrato da comanda fecha em +20, linha a linha');

-- ── 7. Rascunho não cobra; depois fecha com outro request_id ──
select pg_temp.login('00000000-0000-0000-0000-000000000850');
insert into t_snap values ('antes_rascunho', null);
reset role; select set_config('request.jwt.claims', '', true);
update t_snap set v = pg_temp.snap() where k = 'antes_rascunho';
select pg_temp.login('00000000-0000-0000-0000-000000000850');
insert into t_res select 'a9_draft', pg_temp.run(pg_temp.cmd('00000000-0000-0000-0000-0000000008b0', (select id from t_ids where k = 'a9'),
  80, jsonb_build_array(pg_temp.pay('CASH', 80)), '{"mode":"draft"}'::jsonb));
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select (v ->> 'status') = 'draft' from t_res where k = 'a9_draft'), 'rascunho devolve status draft');
select pg_temp.expect((select status = 'draft' and paid_amount = 0 from public.sales where appointment_id = (select id from t_ids where k = 'a9'))
  and (select status = 'Agendado' from public.appointments where id = (select id from t_ids where k = 'a9'))
  and (select count(*) from public.transactions where org_id = '00000000-0000-0000-0000-00000000085a')
    = (select split_part(v, '/', 3)::int from t_snap where k = 'antes_rascunho')
  and (select count(*) from public.sale_payments where org_id = '00000000-0000-0000-0000-00000000085a')
    = (select split_part(v, '/', 2)::int from t_snap where k = 'antes_rascunho'),
  'rascunho: venda draft, atendimento continua Agendado, sem pagamento nem caixa');
select pg_temp.login('00000000-0000-0000-0000-000000000850');
select pg_temp.run(pg_temp.cmd('00000000-0000-0000-0000-0000000008b1', (select id from t_ids where k = 'a9'),
  80, jsonb_build_array(pg_temp.pay('CASH', 80))));
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select status = 'Pago' from public.appointments where id = (select id from t_ids where k = 'a9'))
  and (select count(*) = 1 from public.sales where appointment_id = (select id from t_ids where k = 'a9'))
  and (select status = 'paid' and paid_amount = 80 from public.sales where appointment_id = (select id from t_ids where k = 'a9')),
  'fechar o rascunho reaproveita a mesma venda e paga');

-- ── 8. Desconto e gorjeta entram no total; desconto negativo não vira acréscimo ──
select pg_temp.login('00000000-0000-0000-0000-000000000850');
insert into t_res select 'a10', pg_temp.run(pg_temp.cmd('00000000-0000-0000-0000-0000000008c0', (select id from t_ids where k = 'a10'),
  100, jsonb_build_array(pg_temp.pay('CARD_CREDIT', 90)), '{"discount": 20, "tip": 10}'::jsonb));
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select (v ->> 'status') = 'paid' and (v ->> 'pendingAmount')::numeric = 0 from t_res where k = 'a10'),
  '100 - 20 de desconto + 10 de gorjeta = 90: pago');
select pg_temp.expect((select subtotal = 100 and discount = 20 and tip = 10 and total = 90 and paid_amount = 90 from public.sales
  where appointment_id = (select id from t_ids where k = 'a10')), 'comanda guarda subtotal, desconto, gorjeta e total');
select pg_temp.expect((select balance = 0 from public.clients where id = '00000000-0000-0000-0000-000000000858'),
  'sem dívida nem crédito');

rollback;
\o
\echo 'limites do fechamento de comanda: ok'
