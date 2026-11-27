-- Relatórios e DRE agregados no banco (20261031610000): permissão, fuso do estúdio, quebras e período.
-- Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000001441', 'dona-rel@teste.local'),
  ('00000000-0000-0000-0000-000000001442', 'fin-rel@teste.local'),
  ('00000000-0000-0000-0000-000000001443', 'recep-rel@teste.local'),
  ('00000000-0000-0000-0000-000000001444', 'outra-rel@teste.local');
insert into public.organizations (id, slug, name, timezone) values
  ('00000000-0000-0000-0000-00000000144a', 'rel-a', 'Estúdio A', 'Europe/Madrid'),
  ('00000000-0000-0000-0000-00000000144b', 'rel-b', 'Estúdio B', 'Europe/Madrid');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000001441', '00000000-0000-0000-0000-00000000144a', 'owner'),
  ('00000000-0000-0000-0000-000000001442', '00000000-0000-0000-0000-00000000144a', 'finance'),
  ('00000000-0000-0000-0000-000000001443', '00000000-0000-0000-0000-00000000144a', 'receptionist'),
  ('00000000-0000-0000-0000-000000001444', '00000000-0000-0000-0000-00000000144b', 'owner');
insert into public.staff_members (id, org_id, name) values
  ('00000000-0000-0000-0000-00000000144c', '00000000-0000-0000-0000-00000000144a', 'Bruna Reis'),
  ('00000000-0000-0000-0000-00000000144d', '00000000-0000-0000-0000-00000000144a', 'Karenn');

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

-- S1: Bruna, quitada 05/out (95 = 100 - 10 + 5 de gorjeta), pago em dinheiro e vale.
-- S2: quitada 31/out 23:30 UTC = 1º de novembro em Madrid (fora de outubro).
-- S3: Karenn, quitada 20/out, 200 no cartão. S4 cancelada e S5 rascunho ficam de fora.
insert into public.sales (id, org_id, client_name, staff_id, status, subtotal, discount, tip, total, paid_amount, paid_at) values
  ('00000000-0000-0000-0000-0000000144a1', '00000000-0000-0000-0000-00000000144a', 'A', '00000000-0000-0000-0000-00000000144c', 'paid', 100, 10, 5, 95, 95, '2026-10-05 12:00+00'),
  ('00000000-0000-0000-0000-0000000144a2', '00000000-0000-0000-0000-00000000144a', 'B', '00000000-0000-0000-0000-00000000144c', 'paid', 50, 0, 0, 50, 50, '2026-10-31 23:30+00'),
  ('00000000-0000-0000-0000-0000000144a3', '00000000-0000-0000-0000-00000000144a', 'C', '00000000-0000-0000-0000-00000000144d', 'paid', 200, 0, 0, 200, 200, '2026-10-20 12:00+00'),
  ('00000000-0000-0000-0000-0000000144a4', '00000000-0000-0000-0000-00000000144a', 'D', '00000000-0000-0000-0000-00000000144d', 'cancelled', 80, 0, 0, 80, 80, '2026-10-10 12:00+00'),
  ('00000000-0000-0000-0000-0000000144a5', '00000000-0000-0000-0000-00000000144a', 'E', null, 'draft', 40, 0, 0, 40, 0, null);
insert into public.sale_items (org_id, sale_id, item_type, name, unit_price, quantity, total_price) values
  ('00000000-0000-0000-0000-00000000144a', '00000000-0000-0000-0000-0000000144a1', 'SERVICE', 'Limpeza de pele', 100, 1, 100),
  ('00000000-0000-0000-0000-00000000144a', '00000000-0000-0000-0000-0000000144a3', 'SERVICE', 'Dermaplaning', 100, 2, 200),
  ('00000000-0000-0000-0000-00000000144a', '00000000-0000-0000-0000-0000000144a4', 'SERVICE', 'Dermaplaning', 80, 1, 80);
insert into public.sale_payments (org_id, sale_id, method, amount) values
  ('00000000-0000-0000-0000-00000000144a', '00000000-0000-0000-0000-0000000144a1', 'CASH', 60),
  ('00000000-0000-0000-0000-00000000144a', '00000000-0000-0000-0000-0000000144a1', 'GIFT_CARD', 35),
  ('00000000-0000-0000-0000-00000000144a', '00000000-0000-0000-0000-0000000144a3', 'CARD_DEBIT', 200),
  ('00000000-0000-0000-0000-00000000144a', '00000000-0000-0000-0000-0000000144a4', 'CASH', 80);
insert into public.sale_refunds (org_id, sale_id, amount, destination, reason, created_at) values
  ('00000000-0000-0000-0000-00000000144a', '00000000-0000-0000-0000-0000000144a4', 80, 'caixa', 'Cobrança duplicada', '2026-10-12 10:00+00');
insert into public.sale_partial_refunds (org_id, sale_id, amount, destination, method, reason, created_at) values
  ('00000000-0000-0000-0000-00000000144a', '00000000-0000-0000-0000-0000000144a3', 15, 'caixa', 'CARD_DEBIT', 'Produto devolvido', '2026-10-21 10:00+00');

-- 1. Permissão e período.
select pg_temp.login('00000000-0000-0000-0000-000000001443');
select pg_temp.expect(pg_temp.state_of($q$select public.finance_report_summary('00000000-0000-0000-0000-00000000144a', '2026-10-01', '2026-10-31')$q$) = '42501',
  'recepção não vê relatórios');
select pg_temp.expect(pg_temp.state_of($q$select public.finance_dre_summary('00000000-0000-0000-0000-00000000144a', '2026-10-01', '2026-10-31')$q$) = '42501',
  'recepção não vê o DRE');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000001444');
select pg_temp.expect(pg_temp.state_of($q$select public.finance_report_summary('00000000-0000-0000-0000-00000000144a', '2026-10-01', '2026-10-31')$q$) = '42501',
  'outro estúdio não vê');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000001442');
select pg_temp.expect(pg_temp.state_of($q$select public.finance_report_summary('00000000-0000-0000-0000-00000000144a', '2026-10-31', '2026-10-01')$q$) = '22023', 'fim antes do início');
select pg_temp.expect(pg_temp.state_of($q$select public.finance_report_summary('00000000-0000-0000-0000-00000000144a', '2024-01-01', '2026-10-01')$q$) = '22023', 'período longo demais');

-- 2. Outubro e o 1º de novembro (fuso do estúdio).
insert into t_out select 'oct', public.finance_report_summary('00000000-0000-0000-0000-00000000144a', '2026-10-01', '2026-10-31');
insert into t_out select 'nov1', public.finance_report_summary('00000000-0000-0000-0000-00000000144a', '2026-11-01', '2026-11-01');
insert into t_out select 'dre', public.finance_dre_summary('00000000-0000-0000-0000-00000000144a', '2026-10-01', '2026-10-31');
select pg_temp.logout();

select pg_temp.expect((select r->'totals' = '{"sales": 2, "revenue": 295.00, "discounts": 10.00, "tips": 5.00}'::jsonb from t_out where k = 'oct'),
  'totais de outubro: 2 vendas quitadas, 295 de faturamento');
select pg_temp.expect((select r->'refunds' = '{"full": 80.00, "partial": 15.00}'::jsonb from t_out where k = 'oct'), 'estornos do período');
select pg_temp.expect((select (r->'totals'->>'sales')::int = 1 and (r->'totals'->>'revenue')::numeric = 50 from t_out where k = 'nov1'),
  'quitada às 00:30 de 1º de novembro em Madrid cai em novembro');
select pg_temp.expect((select jsonb_array_length(r->'byDay') = 31 and (r->'byDay'->4->>'date') = '2026-10-05' and (r->'byDay'->4->>'revenue')::numeric = 95
  and (r->'byDay'->4->>'count')::int = 1 and (r->'byDay'->0->>'revenue')::numeric = 0 from t_out where k = 'oct'), 'um item por dia, inclusive os sem venda');
select pg_temp.expect((select (r->'byStaff'->0->>'name') = 'Karenn' and (r->'byStaff'->0->>'revenue')::numeric = 200
  and (r->'byStaff'->1->>'name') = 'Bruna Reis' and (r->'byStaff'->1->>'revenue')::numeric = 95 and jsonb_array_length(r->'byStaff') = 2 from t_out where k = 'oct'),
  'por profissional, do maior para o menor');
select pg_temp.expect((select (r->'byItem'->0->>'name') = 'Dermaplaning' and (r->'byItem'->0->>'qty')::int = 2 and (r->'byItem'->0->>'kind') = 'service'
  and jsonb_array_length(r->'byItem') = 2 from t_out where k = 'oct'), 'por item vendido (a venda cancelada não conta)');
select pg_temp.expect((select (r->'byMethod'->0->>'method') = 'CARD_DEBIT' and (r->'byMethod'->0->>'amount')::numeric = 200
  and (select sum((m->>'amount')::numeric) from jsonb_array_elements(r->'byMethod') m) = 295 from t_out where k = 'oct'),
  'por forma de pagamento soma o faturamento (vale incluído)');

-- 3. DRE em regime de caixa.
insert into public.transactions (org_id, type, category, description, value, method, date, status) values
  ('00000000-0000-0000-0000-00000000144a', 'income',  'servico',      'Serviço',            100, 'CASH',          '2026-10-05', 'completed'),
  ('00000000-0000-0000-0000-00000000144a', 'income',  'produto',      'Produto',             20, 'BIZUM',         '2026-10-06', 'completed'),
  ('00000000-0000-0000-0000-00000000144a', 'income',  'servico',      'Pago com vale',       35, 'GIFT_CARD',     '2026-10-05', 'completed'),
  ('00000000-0000-0000-0000-00000000144a', 'income',  'ajuste_saldo', 'Ajuste',               7, 'CASH',          '2026-10-05', 'completed'),
  ('00000000-0000-0000-0000-00000000144a', 'income',  'servico',      'Novembro',            11, 'CASH',          '2026-11-01', 'completed'),
  ('00000000-0000-0000-0000-00000000144a', 'expense', 'estorno',      'Estorno',             40, 'CASH',          '2026-10-12', 'completed'),
  ('00000000-0000-0000-0000-00000000144a', 'expense', 'material',     'Luvas',               30, 'CASH',          '2026-10-03', 'completed'),
  ('00000000-0000-0000-0000-00000000144a', 'expense', 'conta_paga',   'Aluguel (pago)',     650, null,            '2026-10-02', 'completed'),
  ('00000000-0000-0000-0000-00000000144a', 'expense', 'material',     'Cancelado',           99, 'CASH',          '2026-10-04', 'cancelled');
insert into public.payables (org_id, description, category, value, due_date, paid_date, paid_value, status) values
  ('00000000-0000-0000-0000-00000000144a', 'Aluguel', 'aluguel', 650, '2026-10-01', '2026-10-02', 650, 'paid'),
  ('00000000-0000-0000-0000-00000000144a', 'Comissão Bruna Reis · set/2026', 'comissao', 120, '2026-10-05', '2026-10-06', 118.50, 'paid'),
  ('00000000-0000-0000-0000-00000000144a', 'Fornecedor', 'material', 75, '2026-10-25', null, null, 'pending'),
  ('00000000-0000-0000-0000-00000000144a', 'Fora do período', 'material', 33, '2026-11-03', null, null, 'pending');

select pg_temp.login('00000000-0000-0000-0000-000000001441');
insert into t_out select 'dre2', public.finance_dre_summary('00000000-0000-0000-0000-00000000144a', '2026-10-01', '2026-10-31');
select pg_temp.logout();

select pg_temp.expect((select r->'revenue' = '[{"category": "servico", "amount": 100.00}, {"category": "produto", "amount": 20.00}]'::jsonb from t_out where k = 'dre2'),
  'receita: sem vale, sem ajuste de saldo e só do período');
select pg_temp.expect((select (r->>'refunds')::numeric = 40 from t_out where k = 'dre2'), 'estornos');
select pg_temp.expect((select r->'manualExpenses' = '[{"category": "material", "amount": 30.00}]'::jsonb from t_out where k = 'dre2'),
  'despesas lançadas: sem estorno, sem conta paga (que vem das contas) e sem cancelada');
select pg_temp.expect((select r->'paidPayables' = '[{"category": "aluguel", "amount": 650.00}, {"category": "comissao", "amount": 118.50}]'::jsonb from t_out where k = 'dre2'),
  'contas pagas por categoria, no valor pago');
select pg_temp.expect((select (r->>'discounts')::numeric = 10 and (r->'openPayables'->>'count')::int = 1 and (r->'openPayables'->>'amount')::numeric = 75 from t_out where k = 'dre2'),
  'descontos concedidos e contas em aberto com vencimento no período');
select pg_temp.expect((select r->'revenue' = '[]'::jsonb and r->'paidPayables' = '[]'::jsonb from t_out where k = 'dre'),
  'sem lançamentos ainda, as listas vêm vazias (a chamada anterior foi feita antes de inserir)');

\o
select 'relatórios: ok' as resultado;
rollback;
