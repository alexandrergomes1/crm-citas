-- Pagar conta numa transação só (20261029300000). Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000fa1', 'fin-pagar@teste.local'),
  ('00000000-0000-0000-0000-000000000fa2', 'recep-pagar@teste.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-000000000faa', 'pagar-a', 'Estúdio A');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000000fa1', '00000000-0000-0000-0000-000000000faa', 'finance'),
  ('00000000-0000-0000-0000-000000000fa2', '00000000-0000-0000-0000-000000000faa', 'receptionist');
insert into public.payables (id, org_id, description, value, due_date, status) values
  ('00000000-0000-0000-0000-000000000fab', '00000000-0000-0000-0000-000000000faa', 'Aluguel novembro', 900, '2026-11-01', 'overdue');

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
grant execute on function pg_temp.expect(boolean, text), pg_temp.state_of(text), pg_temp.login(uuid) to authenticated;

-- Recepção não paga contas.
select pg_temp.login('00000000-0000-0000-0000-000000000fa2');
select pg_temp.expect(pg_temp.state_of($q$select public.pay_payable_atomic('00000000-0000-0000-0000-000000000faa',
  '00000000-0000-0000-0000-000000000fab', 900, '2026-11-02')$q$) = '42501', 'recepção não paga conta');
reset role; select set_config('request.jwt.claims', '', true);

-- Financeiro paga: conta paga e despesa lançada juntas, com a descrição da conta.
select pg_temp.login('00000000-0000-0000-0000-000000000fa1');
select pg_temp.expect(pg_temp.state_of($q$select public.pay_payable_atomic('00000000-0000-0000-0000-000000000faa',
  '00000000-0000-0000-0000-000000000fab', 0, '2026-11-02')$q$) = '22023', 'valor zero recusado');
select public.pay_payable_atomic('00000000-0000-0000-0000-000000000faa', '00000000-0000-0000-0000-000000000fab', 905.5, '2026-11-02');
select pg_temp.expect(pg_temp.state_of($q$select public.pay_payable_atomic('00000000-0000-0000-0000-000000000faa',
  '00000000-0000-0000-0000-000000000fab', 905.5, '2026-11-02')$q$) = 'P0001', 'segunda tentativa recusada (sem despesa dupla)');
reset role; select set_config('request.jwt.claims', '', true);

select pg_temp.expect((select status = 'paid' and paid_value = 905.5 and paid_date = '2026-11-02' from public.payables
  where id = '00000000-0000-0000-0000-000000000fab'), 'conta marcada como paga');
select pg_temp.expect((select count(*) = 1 from public.transactions
  where org_id = '00000000-0000-0000-0000-000000000faa' and type = 'expense' and category = 'conta_paga'
    and description = 'Aluguel novembro' and value = 905.5 and created_by = '00000000-0000-0000-0000-000000000fa1'),
  'uma despesa com a descrição da conta e quem pagou');

rollback;
\o
\echo 'pagar conta numa transação só: ok'
