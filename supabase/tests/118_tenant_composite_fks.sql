-- FKs compostas: filho não aponta para pai de outro estúdio. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-000000000dfa', 'fk-a', 'Estúdio A'),
  ('00000000-0000-0000-0000-000000000dfb', 'fk-b', 'Estúdio B');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-000000000df1', '00000000-0000-0000-0000-000000000dfa', 'Cliente A'),
  ('00000000-0000-0000-0000-000000000df2', '00000000-0000-0000-0000-000000000dfb', 'Cliente B');
insert into public.appointments (id, org_id, client_id, client_name, start_at, end_at, duration_minutes, status) values
  ('00000000-0000-0000-0000-000000000df3', '00000000-0000-0000-0000-000000000dfa', '00000000-0000-0000-0000-000000000df1',
   'Cliente A', '2034-01-01 10:00+00', '2034-01-01 11:00+00', 60, 'Agendado');

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

-- Mesmo como superusuário (sem RLS), a relação entre estúdios é recusada.
select pg_temp.expect(pg_temp.state_of($q$update public.appointments set client_id = '00000000-0000-0000-0000-000000000df2'
  where id = '00000000-0000-0000-0000-000000000df3'$q$) = '23503', 'agendamento não aponta para cliente de outro estúdio');
select pg_temp.expect(pg_temp.state_of($q$insert into public.sales (org_id, appointment_id, client_name, status, subtotal, total, paid_amount)
  values ('00000000-0000-0000-0000-000000000dfb', '00000000-0000-0000-0000-000000000df3', 'X', 'draft', 0, 0, 0)$q$) = '23503',
  'venda não aponta para agendamento de outro estúdio');
select pg_temp.expect(pg_temp.state_of($q$insert into public.transactions (org_id, client_id, type, category, description, value, method, date, status)
  values ('00000000-0000-0000-0000-000000000dfa', '00000000-0000-0000-0000-000000000df2', 'income', 'x', 'x', 1, 'CASH', '2034-01-01', 'completed')$q$) = '23503',
  'lançamento não aponta para cliente de outro estúdio');
select pg_temp.expect(pg_temp.state_of($q$insert into public.sales (org_id, appointment_id, client_id, client_name, status, subtotal, total, paid_amount)
  values ('00000000-0000-0000-0000-000000000dfa', '00000000-0000-0000-0000-000000000df3', '00000000-0000-0000-0000-000000000df1', 'Cliente A', 'draft', 0, 0, 0)$q$) = 'ok',
  'mesmo estúdio continua valendo');

rollback;
\o
\echo 'FKs compostas por estúdio: ok'
