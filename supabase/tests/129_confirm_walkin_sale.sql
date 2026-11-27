-- Venda avulsa atômica (20261030110000): atendimento + venda + pagamento numa transação só,
-- sem agenda.manage, sem conflito de horário, idempotente. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000001291', 'caixa-avulsa@teste.local'),
  ('00000000-0000-0000-0000-000000001292', 'prof-avulsa@teste.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-00000000129a', 'avulsa-a', 'Estúdio A');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000001291', '00000000-0000-0000-0000-00000000129a', 'finance'),
  ('00000000-0000-0000-0000-000000001292', '00000000-0000-0000-0000-00000000129a', 'professional');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-00000000129c', '00000000-0000-0000-0000-00000000129a', 'María José Núñez');
insert into public.staff_members (id, org_id, name) values
  ('00000000-0000-0000-0000-00000000129b', '00000000-0000-0000-0000-00000000129a', 'Karenn');
insert into public.services (id, org_id, name, price, duration_minutes) values
  ('00000000-0000-0000-0000-00000000129d', '00000000-0000-0000-0000-00000000129a', 'Limpeza de pele', 50, 30);

-- A profissional está ocupada agora: a venda avulsa não confere conflito de horário.
insert into public.appointments (id, org_id, client_id, client_name, staff_id, start_at, end_at, duration_minutes, status, source, total) values
  ('00000000-0000-0000-0000-0000000129e0', '00000000-0000-0000-0000-00000000129a', '00000000-0000-0000-0000-00000000129c',
   'María José Núñez', '00000000-0000-0000-0000-00000000129b', now() - interval '30 minutes', now() + interval '30 minutes', 60, 'Agendado', 'MANUAL', 0);

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
-- Comando de venda avulsa: um serviço de 50, pagamento e modo variáveis.
create function pg_temp.cmd(p_request uuid, p_mode text, p_payments jsonb, p_tip numeric default 0) returns jsonb language sql as $$
  select jsonb_build_object(
    'request_id', p_request, 'client_id', '00000000-0000-0000-0000-00000000129c', 'staff_id', '00000000-0000-0000-0000-00000000129b',
    'mode', p_mode, 'tip', p_tip,
    'items', jsonb_build_array(jsonb_build_object('item_type', 'SERVICE', 'item_id', '00000000-0000-0000-0000-00000000129d',
      'name', 'Limpeza de pele', 'unit_price', 50, 'quantity', 1, 'duration_minutes', 30)),
    'payments', p_payments)
$$;
create temp table t_out (k text primary key, r jsonb) on commit drop;
grant all on t_out to authenticated;
grant execute on function pg_temp.expect(boolean, text), pg_temp.state_of(text), pg_temp.login(uuid),
  pg_temp.cmd(uuid, text, jsonb, numeric) to authenticated;

-- Sem comanda.operate (profissional): recusado.
select pg_temp.login('00000000-0000-0000-0000-000000001292');
select pg_temp.expect(pg_temp.state_of($q$select public.confirm_walkin_sale_atomic('00000000-0000-0000-0000-00000000129a',
  pg_temp.cmd('00000000-0000-0000-0000-0000000129f1', 'finalize', '[{"method":"CASH","amount":50}]'::jsonb))$q$) = '42501',
  'profissional não registra venda avulsa');
reset role; select set_config('request.jwt.claims', '', true);

-- Caixa (finance: comanda.operate, sem agenda.manage) registra e paga em dinheiro.
select pg_temp.login('00000000-0000-0000-0000-000000001291');
insert into t_out select 'a', public.confirm_walkin_sale_atomic('00000000-0000-0000-0000-00000000129a',
  pg_temp.cmd('00000000-0000-0000-0000-0000000129f2', 'finalize', '[{"method":"CASH","amount":50}]'::jsonb));
-- Repetir a mesma chamada devolve a mesma venda.
insert into t_out select 'a2', public.confirm_walkin_sale_atomic('00000000-0000-0000-0000-00000000129a',
  pg_temp.cmd('00000000-0000-0000-0000-0000000129f2', 'finalize', '[{"method":"CASH","amount":50}]'::jsonb));
-- Mesma chave com outro conteúdo: recusada.
select pg_temp.expect(pg_temp.state_of($q$select public.confirm_walkin_sale_atomic('00000000-0000-0000-0000-00000000129a',
  pg_temp.cmd('00000000-0000-0000-0000-0000000129f2', 'finalize', '[{"method":"CASH","amount":50}]'::jsonb, 5))$q$) = '22023',
  'chave reutilizada com outro conteúdo');
reset role; select set_config('request.jwt.claims', '', true);

select pg_temp.expect((select r->>'status' = 'paid' and (r->>'duplicate')::boolean = false and (r->>'saleNumber')::int = 1 from t_out where k = 'a'),
  'venda avulsa paga com número 1');
select pg_temp.expect((select (r->>'duplicate')::boolean and r->>'saleId' = (select r->>'saleId' from t_out where k = 'a')
  and r->>'appointmentId' = (select r->>'appointmentId' from t_out where k = 'a') and (r->>'saleNumber')::int = 1 from t_out where k = 'a2'),
  'repetição devolve a mesma venda e o mesmo atendimento');
select pg_temp.expect((select count(*) = 2 from public.appointments where org_id = '00000000-0000-0000-0000-00000000129a'),
  'um atendimento novo só (mais o ocupando o horário)');
select pg_temp.expect((select count(*) = 1 from public.sales where org_id = '00000000-0000-0000-0000-00000000129a'), 'uma venda só');
select pg_temp.expect((select a.status = 'Pago' and a.source = 'MANUAL' and a.internal_notes = 'Venda avulsa' and a.total = 50
    and a.staff_id = '00000000-0000-0000-0000-00000000129b' and a.duration_minutes = 30
  from public.appointments a where a.id = (select (r->>'appointmentId')::uuid from t_out where k = 'a')),
  'atendimento Pago, avulso, com a profissional e 30 min');
select pg_temp.expect((select count(*) = 1 and sum(price) = 50 and min(duration_minutes) = 30 from public.appointment_items
  where appointment_id = (select (r->>'appointmentId')::uuid from t_out where k = 'a')), 'item do atendimento com preço e duração');
select pg_temp.expect((select count(*) = 3 from public.appointment_status_history
  where appointment_id = (select (r->>'appointmentId')::uuid from t_out where k = 'a')), 'histórico: Agendado, Concluído, Pago');
select pg_temp.expect((select s.status = 'paid' and s.total = 50 and s.paid_amount = 50 and s.staff_id = '00000000-0000-0000-0000-00000000129b'
    and s.paid_at is not null and s.appointment_id = (select (r->>'appointmentId')::uuid from t_out where k = 'a')
  from public.sales s where s.id = (select (r->>'saleId')::uuid from t_out where k = 'a')), 'venda paga ligada ao atendimento e à profissional');
select pg_temp.expect((select count(*) = 1 and sum(value) = 50 from public.transactions
  where sale_id = (select (r->>'saleId')::uuid from t_out where k = 'a') and type = 'income' and method = 'CASH'), 'caixa recebe 50 uma vez');
select pg_temp.expect((select total_spent = 50 and loyalty_points = 50 from public.clients where id = '00000000-0000-0000-0000-00000000129c'),
  'cliente com gasto e pontos da venda');
select pg_temp.expect((select count(*) = 1 from public.audit_logs where org_id = '00000000-0000-0000-0000-00000000129a' and operation = 'WALKIN_SALE'),
  'auditoria registra a venda avulsa');

-- Pagamento que falha desfaz o atendimento junto (nada órfão).
select pg_temp.login('00000000-0000-0000-0000-000000001291');
select pg_temp.expect(pg_temp.state_of($q$select public.confirm_walkin_sale_atomic('00000000-0000-0000-0000-00000000129a',
  pg_temp.cmd('00000000-0000-0000-0000-0000000129f3', 'finalize', '[{"method":"GIFT_CARD","amount":50,"gift_card_code":"NAOEXISTE"}]'::jsonb))$q$) = '22023',
  'vale inexistente recusa o pagamento');
select pg_temp.expect(pg_temp.state_of($q$select public.confirm_walkin_sale_atomic('00000000-0000-0000-0000-00000000129a',
  jsonb_build_object('request_id', '00000000-0000-0000-0000-0000000129f4', 'client_id', '00000000-0000-0000-0000-0000000129ff',
  'mode', 'finalize', 'items', pg_temp.cmd('00000000-0000-0000-0000-0000000129f4', 'finalize', '[]'::jsonb)->'items', 'payments', '[]'::jsonb))$q$) = 'P0002',
  'cliente de outro estúdio ou inexistente');
select pg_temp.expect(pg_temp.state_of($q$select public.confirm_walkin_sale_atomic('00000000-0000-0000-0000-00000000129a',
  jsonb_build_object('request_id', '00000000-0000-0000-0000-0000000129f5', 'client_id', '00000000-0000-0000-0000-00000000129c',
  'mode', 'finalize', 'items', '[]'::jsonb, 'payments', '[]'::jsonb))$q$) = '22023', 'sem itens recusado');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select count(*) = 2 from public.appointments where org_id = '00000000-0000-0000-0000-00000000129a'),
  'falhas não deixam atendimento órfão');
select pg_temp.expect((select count(*) = 1 from public.sales where org_id = '00000000-0000-0000-0000-00000000129a'), 'falhas não deixam venda');
select pg_temp.expect((select count(*) = 1 from public.transactions where org_id = '00000000-0000-0000-0000-00000000129a'), 'falhas não lançam no caixa');

-- Pagamento parcial e rascunho.
select pg_temp.login('00000000-0000-0000-0000-000000001291');
insert into t_out select 'p', public.confirm_walkin_sale_atomic('00000000-0000-0000-0000-00000000129a',
  pg_temp.cmd('00000000-0000-0000-0000-0000000129f6', 'finalize', '[{"method":"CARD_DEBIT","amount":20}]'::jsonb));
insert into t_out select 'd', public.confirm_walkin_sale_atomic('00000000-0000-0000-0000-00000000129a',
  pg_temp.cmd('00000000-0000-0000-0000-0000000129f7', 'draft', '[]'::jsonb));
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select r->>'status' = 'partial' and (r->>'pendingAmount')::numeric = 30 and (r->>'saleNumber')::int = 2 from t_out where k = 'p'),
  'parcial: falta 30, número 2');
select pg_temp.expect((select status = 'Pago Parcial' from public.appointments where id = (select (r->>'appointmentId')::uuid from t_out where k = 'p')),
  'atendimento Pago Parcial');
select pg_temp.expect((select balance = -30 from public.clients where id = '00000000-0000-0000-0000-00000000129c'), 'cliente deve 30');
select pg_temp.expect((select r->>'status' = 'draft' and (r->>'saleNumber')::int = 3 from t_out where k = 'd'), 'rascunho com número 3');
select pg_temp.expect((select status = 'Concluído' from public.appointments where id = (select (r->>'appointmentId')::uuid from t_out where k = 'd')),
  'rascunho deixa o atendimento Concluído, à espera da cobrança');

rollback;
\o
\echo 'venda avulsa atômica: ok'
