-- Fatura anexada à conta a pagar (20261030150000). Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000001311', 'fin-fat@teste.local'),
  ('00000000-0000-0000-0000-000000001312', 'recep-fat@teste.local'),
  ('00000000-0000-0000-0000-000000001313', 'fin-outro@teste.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-00000000131a', 'fat-a', 'Estúdio A'),
  ('00000000-0000-0000-0000-00000000131b', 'fat-b', 'Estúdio B');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000001311', '00000000-0000-0000-0000-00000000131a', 'finance'),
  ('00000000-0000-0000-0000-000000001312', '00000000-0000-0000-0000-00000000131a', 'receptionist'),
  ('00000000-0000-0000-0000-000000001313', '00000000-0000-0000-0000-00000000131b', 'finance');

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

insert into storage.buckets (id, name) values ('payable-invoices', 'payable-invoices') on conflict do nothing;
insert into public.payables (id, org_id, description, value, due_date) values
  ('00000000-0000-0000-0000-0000000131c1', '00000000-0000-0000-0000-00000000131a', 'Aluguel', 100, '2026-11-05');

-- O caminho da fatura precisa começar pela pasta do próprio estúdio.
select pg_temp.expect(pg_temp.state_of($q$update public.payables
  set invoice_path = '00000000-0000-0000-0000-00000000131b/00000000-0000-0000-0000-0000000131c1/f.pdf', invoice_name = 'f.pdf'
  where id = '00000000-0000-0000-0000-0000000131c1'$q$) = '23514', 'fatura de outro estúdio é recusada');
select pg_temp.expect(pg_temp.state_of($q$update public.payables
  set invoice_path = '00000000-0000-0000-0000-00000000131a/../x.pdf' where id = '00000000-0000-0000-0000-0000000131c1'$q$) = '23514',
  'caminho com .. é recusado');
update public.payables
  set invoice_path = '00000000-0000-0000-0000-00000000131a/00000000-0000-0000-0000-0000000131c1/f.pdf', invoice_name = 'f.pdf'
  where id = '00000000-0000-0000-0000-0000000131c1';
select pg_temp.expect((select invoice_name = 'f.pdf' from public.payables where id = '00000000-0000-0000-0000-0000000131c1'),
  'fatura do próprio estúdio é aceita');

-- Arquivos: financeiro grava e lê na pasta do estúdio; recepção não; outro estúdio não.
select pg_temp.login('00000000-0000-0000-0000-000000001311');
insert into storage.objects (bucket_id, name)
values ('payable-invoices', '00000000-0000-0000-0000-00000000131a/00000000-0000-0000-0000-0000000131c1/f.pdf');
select pg_temp.expect((select count(*) from storage.objects where bucket_id = 'payable-invoices') = 1, 'financeiro lê a fatura');
select pg_temp.expect(pg_temp.state_of($q$insert into storage.objects (bucket_id, name)
  values ('payable-invoices', '00000000-0000-0000-0000-00000000131b/x/g.pdf')$q$) in ('42501', '42P17'),
  'financeiro não grava na pasta de outro estúdio');
reset role; select set_config('request.jwt.claims', '', true);

select pg_temp.login('00000000-0000-0000-0000-000000001312');
select pg_temp.expect((select count(*) from storage.objects where bucket_id = 'payable-invoices') = 0, 'recepção não lê fatura');
select pg_temp.expect(pg_temp.state_of($q$insert into storage.objects (bucket_id, name)
  values ('payable-invoices', '00000000-0000-0000-0000-00000000131a/x/h.pdf')$q$) in ('42501', '42P17'), 'recepção não grava fatura');
reset role; select set_config('request.jwt.claims', '', true);

select pg_temp.login('00000000-0000-0000-0000-000000001313');
select pg_temp.expect((select count(*) from storage.objects where bucket_id = 'payable-invoices') = 0, 'outro estúdio não lê a fatura');
reset role; select set_config('request.jwt.claims', '', true);

rollback;
\o
\echo 'fatura da conta a pagar: ok'
