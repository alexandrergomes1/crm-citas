-- Número sequencial da comanda por estúdio e data de quitação (20261030100000). Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values ('00000000-0000-0000-0000-000000001271', 'num@teste.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-00000000127a', 'num-a', 'Estúdio A'),
  ('00000000-0000-0000-0000-00000000127b', 'num-b', 'Estúdio B');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000001271', '00000000-0000-0000-0000-00000000127a', 'owner');

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
grant execute on function pg_temp.expect(boolean, text), pg_temp.state_of(text) to authenticated;

-- Numeração por estúdio, sem repetir (as quatro vendas entram em instruções separadas).
insert into public.sales (id, org_id, client_name, status) values
  ('00000000-0000-0000-0000-0000000127a1', '00000000-0000-0000-0000-00000000127a', 'Ana', 'draft');
insert into public.sales (id, org_id, client_name, status) values
  ('00000000-0000-0000-0000-0000000127a2', '00000000-0000-0000-0000-00000000127a', 'Bia', 'paid');
insert into public.sales (id, org_id, client_name, status) values
  ('00000000-0000-0000-0000-0000000127a3', '00000000-0000-0000-0000-00000000127a', 'Cris', 'partial');
insert into public.sales (id, org_id, client_name, status) values
  ('00000000-0000-0000-0000-0000000127b1', '00000000-0000-0000-0000-00000000127b', 'Dani', 'draft');
select pg_temp.expect((select number from public.sales where id = '00000000-0000-0000-0000-0000000127a1') = 1
  and (select number from public.sales where id = '00000000-0000-0000-0000-0000000127a2') = 2
  and (select number from public.sales where id = '00000000-0000-0000-0000-0000000127a3') = 3, 'estúdio A numera 1, 2, 3');
select pg_temp.expect((select number from public.sales where id = '00000000-0000-0000-0000-0000000127b1') = 1,
  'estúdio B começa em 1 (contador por estúdio)');
select pg_temp.expect((select last_number from public.sale_counters where org_id = '00000000-0000-0000-0000-00000000127a') = 3,
  'contador do estúdio A em 3');
select pg_temp.expect(pg_temp.state_of($q$insert into public.sales (org_id, client_name, number)
  values ('00000000-0000-0000-0000-00000000127a', 'Dup', 2)$q$) = '23505', 'número repetido no estúdio é recusado');

-- Venda desfeita devolve o número.
do $$
begin
  begin
    insert into public.sales (org_id, client_name) values ('00000000-0000-0000-0000-00000000127a', 'Desfeita');
    raise exception 'desfaz';
  exception when raise_exception then null;
  end;
end $$;
insert into public.sales (id, org_id, client_name) values
  ('00000000-0000-0000-0000-0000000127a4', '00000000-0000-0000-0000-00000000127a', 'Eva');
select pg_temp.expect((select number from public.sales where id = '00000000-0000-0000-0000-0000000127a4') = 4,
  'número da venda desfeita é reaproveitado, sem buraco');

-- A quitação grava paid_at; rascunho e parcial não.
select pg_temp.expect((select paid_at is not null from public.sales where id = '00000000-0000-0000-0000-0000000127a2'),
  'venda criada já paga tem paid_at');
select pg_temp.expect((select paid_at is null from public.sales where id = '00000000-0000-0000-0000-0000000127a1'),
  'rascunho não tem paid_at');
select pg_temp.expect((select paid_at is null from public.sales where id = '00000000-0000-0000-0000-0000000127a3'),
  'parcial não tem paid_at');
update public.sales set paid_at = '2026-09-10 12:00+00' where id = '00000000-0000-0000-0000-0000000127a2';
update public.sales set status = 'paid' where id = '00000000-0000-0000-0000-0000000127a3';
select pg_temp.expect((select paid_at is not null from public.sales where id = '00000000-0000-0000-0000-0000000127a3'),
  'parcial quitada ganha paid_at na quitação');
update public.sales set notes = 'x', status = 'paid' where id = '00000000-0000-0000-0000-0000000127a2';
select pg_temp.expect((select paid_at = '2026-09-10 12:00+00' from public.sales where id = '00000000-0000-0000-0000-0000000127a2'),
  'paid_at não muda quando a venda já estava paga');

-- Contador só pelo banco: ninguém lê nem escreve pela API.
set local role authenticated;
select pg_temp.expect(pg_temp.state_of($q$select * from public.sale_counters$q$) = '42501', 'sale_counters fechado para a API');
reset role;

rollback;
\o
\echo 'número da comanda e paid_at: ok'
