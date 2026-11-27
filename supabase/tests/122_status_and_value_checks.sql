-- CHECKs de status e valor (20261029260000). Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;
insert into public.organizations (id, slug, name) values ('00000000-0000-0000-0000-000000000e3a', 'checks-a', 'Estúdio A');
insert into public.clients (id, org_id, full_name) values ('00000000-0000-0000-0000-000000000e3c', '00000000-0000-0000-0000-000000000e3a', 'X');

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

-- A inserção já tinha gatilho; o furo era o UPDATE direto.
insert into public.appointments (id, org_id, client_id, client_name, start_at, end_at, duration_minutes, status)
values ('00000000-0000-0000-0000-000000000e3b', '00000000-0000-0000-0000-000000000e3a', '00000000-0000-0000-0000-000000000e3c', 'X', '2035-01-01 10:00+00', '2035-01-01 11:00+00', 60, 'Agendado');
select pg_temp.expect(pg_temp.state_of($q$update public.appointments set status = 'Ausencia' where id = '00000000-0000-0000-0000-000000000e3b'$q$) = '23514',
  'status fora da lista recusado no UPDATE');
select pg_temp.expect(pg_temp.state_of($q$update public.appointments set end_at = start_at where id = '00000000-0000-0000-0000-000000000e3b'$q$) = '23514',
  'fim igual ao início recusado');
select pg_temp.expect(pg_temp.state_of($q$update public.appointments set status = 'Cancelado' where id = '00000000-0000-0000-0000-000000000e3b'$q$) = 'ok',
  'status canônico aceito');
select pg_temp.expect(pg_temp.state_of($q$insert into public.gift_cards (org_id, code, initial_value, remaining_value)
  values ('00000000-0000-0000-0000-000000000e3a', 'VALE-122', 50, 80)$q$) = '23514', 'saldo do vale acima do valor inicial recusado');

rollback;
\o
\echo 'CHECKs de status e valor: ok'
