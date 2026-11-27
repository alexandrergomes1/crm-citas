-- Políticas FOR ALL antigas removidas (20261029190000): caixa, vendas, vale-presente e clientes.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000dc1', 'dono4@teste.local'),
  ('00000000-0000-0000-0000-000000000dc2', 'prof4@teste.local'),
  ('00000000-0000-0000-0000-000000000dc3', 'recep4@teste.local'),
  ('00000000-0000-0000-0000-000000000dc4', 'fin4@teste.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-000000000dca', 'perm4-a', 'Estúdio A');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000000dc1', '00000000-0000-0000-0000-000000000dca', 'owner'),
  ('00000000-0000-0000-0000-000000000dc2', '00000000-0000-0000-0000-000000000dca', 'professional'),
  ('00000000-0000-0000-0000-000000000dc3', '00000000-0000-0000-0000-000000000dca', 'receptionist'),
  ('00000000-0000-0000-0000-000000000dc4', '00000000-0000-0000-0000-000000000dca', 'finance');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-000000000dcc', '00000000-0000-0000-0000-000000000dca', 'Elena Sanz');
insert into public.transactions (org_id, type, category, description, value, method, date, status)
values ('00000000-0000-0000-0000-000000000dca', 'income', 'servico', 'Atendimento', 50, 'CASH', '2026-10-29', 'completed');
insert into public.sales (id, org_id, client_name, status, subtotal, total, paid_amount)
values ('00000000-0000-0000-0000-000000000dcd', '00000000-0000-0000-0000-000000000dca', 'Elena Sanz', 'paid', 50, 50, 50);

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

-- Profissional: não lê o caixa, não mexe em vendas, não cadastra nem apaga cliente.
select pg_temp.login('00000000-0000-0000-0000-000000000dc2');
do $$ begin
  perform pg_temp.expect((select count(*) from public.transactions) = 0, 'profissional não lê o caixa');
  perform pg_temp.expect(pg_temp.state_of($q$insert into public.transactions (org_id, type, category, description, value, method, date, status)
    values ('00000000-0000-0000-0000-000000000dca', 'income', 'x', 'x', 1, 'CASH', '2026-10-29', 'completed')$q$) = '42501', 'profissional não lança no caixa');
  perform pg_temp.expect(pg_temp.state_of($q$insert into public.sales (org_id, client_name, status, subtotal, total, paid_amount)
    values ('00000000-0000-0000-0000-000000000dca', 'X', 'paid', 1, 1, 1)$q$) = '42501', 'profissional não cria venda direto');
  perform pg_temp.expect(pg_temp.state_of($q$insert into public.clients (org_id, full_name) values ('00000000-0000-0000-0000-000000000dca', 'Nova')$q$) = '42501',
    'profissional não cadastra cliente por padrão');
  delete from public.clients where id = '00000000-0000-0000-0000-000000000dcc';
end $$;

-- Recepção: cadastra cliente e vende vale-presente; não lê o caixa nem altera venda.
select pg_temp.login('00000000-0000-0000-0000-000000000dc3');
do $$ begin
  perform pg_temp.expect((select count(*) from public.transactions) = 0, 'recepção não lê o caixa por padrão');
  perform pg_temp.expect(pg_temp.state_of($q$insert into public.clients (org_id, full_name) values ('00000000-0000-0000-0000-000000000dca', 'Nova')$q$) = 'ok',
    'recepção cadastra cliente');
  perform pg_temp.expect(pg_temp.state_of($q$insert into public.gift_cards (org_id, code, initial_value, remaining_value)
    values ('00000000-0000-0000-0000-000000000dca', 'VALE-TESTE-116', 30, 30)$q$) = 'ok', 'recepção emite vale-presente');
  update public.sales set total = 1 where id = '00000000-0000-0000-0000-000000000dcd';
  delete from public.clients where id = '00000000-0000-0000-0000-000000000dcc';
end $$;

-- Financeiro: lê e lança no caixa.
select pg_temp.login('00000000-0000-0000-0000-000000000dc4');
do $$ begin
  perform pg_temp.expect((select count(*) from public.transactions) = 1, 'financeiro lê o caixa');
  perform pg_temp.expect(pg_temp.state_of($q$insert into public.transactions (org_id, type, category, description, value, method, date, status)
    values ('00000000-0000-0000-0000-000000000dca', 'expense', 'aluguel', 'Aluguel', 500, 'TRANSFER', '2026-10-29', 'completed')$q$) = 'ok', 'financeiro lança despesa');
end $$;

reset role;
select pg_temp.expect((select total from public.sales where id = '00000000-0000-0000-0000-000000000dcd') = 50, 'ninguém alterou a venda direto');
select pg_temp.expect(exists (select 1 from public.clients where id = '00000000-0000-0000-0000-000000000dcc'), 'ninguém apagou a cliente pela API');

-- Profissional com agenda.manage (sem clientes.manage) agenda, mas não altera a cliente.
select pg_temp.login('00000000-0000-0000-0000-000000000dc1');
select public.set_role_permission('00000000-0000-0000-0000-000000000dca', 'professional', 'agenda.manage', true);
select pg_temp.login('00000000-0000-0000-0000-000000000dc2');
do $$ begin
  -- Regra de 20261114130300: sem a política "travar na agenda", o UPDATE não alcança nenhuma linha (nome intacto, abaixo).
  perform pg_temp.expect(pg_temp.state_of($q$update public.clients set full_name = 'Trocado' where id = '00000000-0000-0000-0000-000000000dcc'$q$) in ('ok', '42501'),
    'agenda.manage sozinha não altera cadastro de cliente');
  -- A trava para agendar agora é a função agenda_lock_client (DEFINER, exige agenda.manage).
  perform pg_temp.expect(pg_temp.state_of($q$select public.agenda_lock_client('00000000-0000-0000-0000-000000000dca', '00000000-0000-0000-0000-000000000dcc')$q$) = 'ok',
    'agenda.manage trava a cliente para agendar');
end $$;
reset role;
select pg_temp.expect((select full_name from public.clients where id = '00000000-0000-0000-0000-000000000dcc') = 'Elena Sanz', 'nome da cliente intacto');

-- Dona libera cadastro de cliente para a profissional.
select pg_temp.login('00000000-0000-0000-0000-000000000dc1');
select public.set_role_permission('00000000-0000-0000-0000-000000000dca', 'professional', 'clientes.manage', true);
select pg_temp.login('00000000-0000-0000-0000-000000000dc2');
do $$ begin
  perform pg_temp.expect(pg_temp.state_of($q$insert into public.clients (org_id, full_name) values ('00000000-0000-0000-0000-000000000dca', 'Outra')$q$) = 'ok',
    'profissional com liberação cadastra cliente');
end $$;

reset role;
rollback;
\o
\echo 'políticas antigas de escrita removidas: ok'
