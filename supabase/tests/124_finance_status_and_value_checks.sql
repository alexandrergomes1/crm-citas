-- CHECKs de vendas, caixa e contas a pagar (20261029290000). Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;
insert into public.organizations (id, slug, name) values ('00000000-0000-0000-0000-000000000f4a', 'checks-fin', 'Estúdio A');
insert into public.sales (id, org_id, client_name, status, subtotal, total, paid_amount)
values ('00000000-0000-0000-0000-000000000f4b', '00000000-0000-0000-0000-000000000f4a', 'X', 'draft', 50, 50, 0);

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

select pg_temp.expect(pg_temp.state_of($q$update public.sales set status = 'pago' where id = '00000000-0000-0000-0000-000000000f4b'$q$) = '23514',
  'status de venda fora da lista recusado');
select pg_temp.expect(pg_temp.state_of($q$update public.sales set total = -1 where id = '00000000-0000-0000-0000-000000000f4b'$q$) = '23514',
  'total negativo recusado');
select pg_temp.expect(pg_temp.state_of($q$insert into public.sale_items (org_id, sale_id, item_type, name, unit_price, quantity, total_price)
  values ('00000000-0000-0000-0000-000000000f4a', '00000000-0000-0000-0000-000000000f4b', 'service', 'A', 50, 0, 0)$q$) = '23514',
  'quantidade zero recusada');
select pg_temp.expect(pg_temp.state_of($q$insert into public.sale_items (org_id, sale_id, item_type, name, unit_price, quantity, total_price)
  values ('00000000-0000-0000-0000-000000000f4a', '00000000-0000-0000-0000-000000000f4b', 'brinde', 'A', 0, 1, 0)$q$) = '23514',
  'tipo de item desconhecido recusado');
select pg_temp.expect(pg_temp.state_of($q$insert into public.sale_items (org_id, sale_id, item_type, name, unit_price, quantity, total_price)
  values ('00000000-0000-0000-0000-000000000f4a', '00000000-0000-0000-0000-000000000f4b', 'SERVICE', 'A', 50, 1, 50)$q$) = 'ok',
  'item válido aceito (tipo em qualquer caixa)');
select pg_temp.expect(pg_temp.state_of($q$insert into public.sale_payments (org_id, sale_id, method, amount)
  values ('00000000-0000-0000-0000-000000000f4a', '00000000-0000-0000-0000-000000000f4b', 'CASH', 0)$q$) = '23514',
  'pagamento zerado recusado');
select pg_temp.expect(pg_temp.state_of($q$insert into public.transactions (org_id, type, category, description, value, method, date, status)
  values ('00000000-0000-0000-0000-000000000f4a', 'income', 'servico', 'A', -10, 'CASH', '2026-10-29', 'completed')$q$) = '23514',
  'lançamento de caixa negativo recusado');
select pg_temp.expect(pg_temp.state_of($q$insert into public.transactions (org_id, type, category, description, value, method, date, status)
  values ('00000000-0000-0000-0000-000000000f4a', 'transfer', 'servico', 'A', 10, 'CASH', '2026-10-29', 'completed')$q$) = '23514',
  'tipo de lançamento fora da lista recusado');
select pg_temp.expect(pg_temp.state_of($q$insert into public.transactions (org_id, type, category, description, value, method, date, status)
  values ('00000000-0000-0000-0000-000000000f4a', 'expense', 'fixas', 'Aluguel', 10, 'TRANSFER', '2026-10-29', 'completed')$q$) = 'ok',
  'lançamento válido aceito');
select pg_temp.expect(pg_temp.state_of($q$insert into public.payables (org_id, description, value, due_date, status)
  values ('00000000-0000-0000-0000-000000000f4a', 'Luz', 30, '2026-11-05', 'aberta')$q$) = '23514',
  'status de conta a pagar fora da lista recusado');

rollback;
\o
\echo 'CHECKs de vendas, caixa e contas a pagar: ok'
