-- Fechar o período de comissão: data de quitação, chave única, idempotência e ajuste (20261030120000).
-- Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000001281', 'fin-com@teste.local'),
  ('00000000-0000-0000-0000-000000001282', 'recep-com@teste.local');
insert into public.organizations (id, slug, name, timezone) values
  ('00000000-0000-0000-0000-00000000128a', 'com-a', 'Estúdio A', 'Europe/Madrid');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000001281', '00000000-0000-0000-0000-00000000128a', 'finance'),
  ('00000000-0000-0000-0000-000000001282', '00000000-0000-0000-0000-00000000128a', 'receptionist');
insert into public.staff_members (id, org_id, name, commission_pct) values
  ('00000000-0000-0000-0000-00000000128b', '00000000-0000-0000-0000-00000000128a', 'Bruna Reis', 10),
  ('00000000-0000-0000-0000-00000000128c', '00000000-0000-0000-0000-00000000128a', 'Sem Comissão', 0);

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
create temp table t_out (k text primary key, r jsonb) on commit drop;
grant all on t_out to authenticated;
grant execute on function pg_temp.expect(boolean, text), pg_temp.state_of(text), pg_temp.login(uuid) to authenticated;

-- A: criada em 31/out e paga em 03/nov (novembro). B: criada em setembro e quitada em outubro (outubro).
-- C: quitada em 31/out às 23:30 UTC = 1º de novembro em Madrid (novembro). D: com desconto, em outubro.
-- E: profissional sem comissão. F: cancelada (estornada).
insert into public.sales (id, org_id, client_name, staff_id, status, subtotal, discount, total, paid_amount, created_at, paid_at) values
  ('00000000-0000-0000-0000-0000000128a1', '00000000-0000-0000-0000-00000000128a', 'A', '00000000-0000-0000-0000-00000000128b', 'paid', 100, 0, 100, 100, '2026-10-31 12:00+00', '2026-11-03 12:00+00'),
  ('00000000-0000-0000-0000-0000000128a2', '00000000-0000-0000-0000-00000000128a', 'B', '00000000-0000-0000-0000-00000000128b', 'paid', 200, 0, 200, 200, '2026-09-20 12:00+00', '2026-10-05 12:00+00'),
  ('00000000-0000-0000-0000-0000000128a3', '00000000-0000-0000-0000-00000000128a', 'C', '00000000-0000-0000-0000-00000000128b', 'paid', 300, 0, 300, 300, '2026-10-30 12:00+00', '2026-10-31 23:30+00'),
  ('00000000-0000-0000-0000-0000000128a4', '00000000-0000-0000-0000-00000000128a', 'D', '00000000-0000-0000-0000-00000000128b', 'paid', 100, 20, 80, 80, '2026-10-10 12:00+00', '2026-10-10 12:00+00'),
  ('00000000-0000-0000-0000-0000000128a5', '00000000-0000-0000-0000-00000000128a', 'E', '00000000-0000-0000-0000-00000000128c', 'paid', 100, 0, 100, 100, '2026-10-10 12:00+00', '2026-10-10 12:00+00'),
  ('00000000-0000-0000-0000-0000000128a6', '00000000-0000-0000-0000-00000000128a', 'F', '00000000-0000-0000-0000-00000000128b', 'cancelled', 100, 0, 100, 100, '2026-10-10 12:00+00', '2026-10-10 12:00+00');

-- Recepção não fecha comissão; período inválido é recusado.
select pg_temp.login('00000000-0000-0000-0000-000000001282');
select pg_temp.expect(pg_temp.state_of($q$select public.close_commission_period_atomic('00000000-0000-0000-0000-00000000128a', '2026-10')$q$) = '42501',
  'recepção não fecha comissão');
reset role; select set_config('request.jwt.claims', '', true);

select pg_temp.login('00000000-0000-0000-0000-000000001281');
select pg_temp.expect(pg_temp.state_of($q$select public.close_commission_period_atomic('00000000-0000-0000-0000-00000000128a', '2026-13')$q$) = '22023',
  'período inválido recusado');
insert into t_out select 'oct1', public.close_commission_period_atomic('00000000-0000-0000-0000-00000000128a', '2026-10');
insert into t_out select 'oct2', public.close_commission_period_atomic('00000000-0000-0000-0000-00000000128a', '2026-10');
reset role; select set_config('request.jwt.claims', '', true);

-- Outubro: B (200) + D (100 - 20 = 80) = 280 a 10% = 28. A e C (novembro), E (0%) e F (cancelada) ficam de fora.
select pg_temp.expect((select (r->>'created')::int = 1 from t_out where k = 'oct1'), 'primeiro fechamento cria 1 conta');
select pg_temp.expect((select (r->>'created')::int = 0 and (r->>'unchanged')::int = 1 from t_out where k = 'oct2'),
  'segundo fechamento não duplica');
select pg_temp.expect((select count(*) = 1 and sum(value) = 28 and min(source_key) = 'commission:00000000-0000-0000-0000-00000000128b:2026-10'
  and min(description) = 'Comissão Bruna Reis · out/2026' and min(due_date) = date '2026-11-05'
  from public.payables where org_id = '00000000-0000-0000-0000-00000000128a' and category = 'comissao'),
  'uma conta de 28 com chave, descrição e vencimento no dia 5');
select pg_temp.expect(pg_temp.state_of($q$insert into public.payables (org_id, description, value, due_date, source_key)
  values ('00000000-0000-0000-0000-00000000128a', 'dup', 1, '2026-11-05', 'commission:00000000-0000-0000-0000-00000000128b:2026-10')$q$) = '23505',
  'a chave de origem é única por estúdio');

-- Novembro: A (100) + C (300) = 400 a 10% = 40.
select pg_temp.login('00000000-0000-0000-0000-000000001281');
insert into t_out select 'nov1', public.close_commission_period_atomic('00000000-0000-0000-0000-00000000128a', '2026-11');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select value = 40 from public.payables where org_id = '00000000-0000-0000-0000-00000000128a'
  and source_key = 'commission:00000000-0000-0000-0000-00000000128b:2026-11'), 'novembro paga 40 (quitação de 03/nov e 1º/nov em Madrid)');

-- Venda quitada em outubro depois do fechamento: só a diferença vira ajuste, uma vez.
insert into public.sales (id, org_id, client_name, staff_id, status, subtotal, discount, total, paid_amount, paid_at) values
  ('00000000-0000-0000-0000-0000000128a7', '00000000-0000-0000-0000-00000000128a', 'G', '00000000-0000-0000-0000-00000000128b', 'paid', 50, 0, 50, 50, '2026-10-20 12:00+00');
select pg_temp.login('00000000-0000-0000-0000-000000001281');
insert into t_out select 'oct3', public.close_commission_period_atomic('00000000-0000-0000-0000-00000000128a', '2026-10');
insert into t_out select 'oct4', public.close_commission_period_atomic('00000000-0000-0000-0000-00000000128a', '2026-10');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select (r->>'adjusted')::int = 1 and (r->>'created')::int = 0 from t_out where k = 'oct3'), 'ajuste lançado');
select pg_temp.expect((select (r->>'adjusted')::int = 0 and (r->>'unchanged')::int = 1 from t_out where k = 'oct4'), 'ajuste não repete');
select pg_temp.expect((select count(*) = 2 and sum(value) = 33 from public.payables
  where org_id = '00000000-0000-0000-0000-00000000128a' and category = 'comissao' and due_date = date '2026-11-05'
    and source_key like 'commission:00000000-0000-0000-0000-00000000128b:2026-10%'),
  'outubro: conta de 28 e ajuste de 5');

-- Venda estornada depois do fechamento: a diferença negativa é informada e nada é criado.
update public.sales set status = 'cancelled' where id = '00000000-0000-0000-0000-0000000128a2';
select pg_temp.login('00000000-0000-0000-0000-000000001281');
insert into t_out select 'oct5', public.close_commission_period_atomic('00000000-0000-0000-0000-00000000128a', '2026-10');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select (r->>'created')::int = 0 and (r->>'adjusted')::int = 0
  and (r->'negative'->0->>'difference')::numeric = -20 from t_out where k = 'oct5'),
  'estorno depois do fechamento: diferença de -20 informada');

-- Mês fechado só pela descrição (app antigo) não é fechado de novo.
insert into public.sales (id, org_id, client_name, staff_id, status, subtotal, discount, total, paid_amount, paid_at) values
  ('00000000-0000-0000-0000-0000000128a8', '00000000-0000-0000-0000-00000000128a', 'H', '00000000-0000-0000-0000-00000000128b', 'paid', 100, 0, 100, 100, '2026-09-15 12:00+00');
insert into public.payables (org_id, description, vendor, category, value, due_date, status) values
  ('00000000-0000-0000-0000-00000000128a', 'Comissão Bruna Reis · set/2026', 'Bruna Reis', 'comissao', 10, '2026-10-05', 'paid');
select pg_temp.login('00000000-0000-0000-0000-000000001281');
insert into t_out select 'sep1', public.close_commission_period_atomic('00000000-0000-0000-0000-00000000128a', '2026-09');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select (r->>'created')::int = 0 and (r->>'adjusted')::int = 0 from t_out where k = 'sep1'),
  'conta antiga fechada pela descrição conta como fechada');

rollback;
\o
\echo 'fechar comissão: ok'
