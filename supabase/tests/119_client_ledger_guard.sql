-- Saldo e pontos só por extrato; ajuste de pontos atômico. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000e01', 'dono6@teste.local'),
  ('00000000-0000-0000-0000-000000000e02', 'recep6@teste.local');
insert into public.organizations (id, slug, name) values ('00000000-0000-0000-0000-000000000e0a', 'ledger-a', 'Estúdio A');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000000e01', '00000000-0000-0000-0000-000000000e0a', 'owner'),
  ('00000000-0000-0000-0000-000000000e02', '00000000-0000-0000-0000-000000000e0a', 'receptionist');
insert into public.clients (id, org_id, full_name, loyalty_points) values
  ('00000000-0000-0000-0000-000000000e0c', '00000000-0000-0000-0000-000000000e0a', 'Rocío Gil', 450);

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

-- Recepção edita a cliente, mas não o saldo nem os pontos; nem lança no extrato direto.
select pg_temp.login('00000000-0000-0000-0000-000000000e02');
do $$ begin
  perform pg_temp.expect(pg_temp.state_of($q$update public.clients set notes = 'ok' where id = '00000000-0000-0000-0000-000000000e0c'$q$) = 'ok', 'recepção edita dados comuns');
  perform pg_temp.expect(pg_temp.state_of($q$update public.clients set balance = 999 where id = '00000000-0000-0000-0000-000000000e0c'$q$) = '42501', 'saldo não muda direto');
  perform pg_temp.expect(pg_temp.state_of($q$update public.clients set loyalty_points = 9999 where id = '00000000-0000-0000-0000-000000000e0c'$q$) = '42501', 'pontos não mudam direto');
  perform pg_temp.expect(pg_temp.state_of($q$insert into public.loyalty_point_entries (org_id, client_id, entry_type, points, balance_before, balance_after, source_type, description)
    values ('00000000-0000-0000-0000-000000000e0a', '00000000-0000-0000-0000-000000000e0c', 'credit', 10, 0, 10, 'manual', 'x')$q$) = '42501', 'extrato de pontos não aceita INSERT direto');
  perform pg_temp.expect(pg_temp.state_of($q$select public.adjust_loyalty_points_atomic('00000000-0000-0000-0000-000000000e0a', '00000000-0000-0000-0000-000000000e0c', 10, 'x')$q$) = '42501', 'recepção não ajusta pontos');
end $$;

-- Dona ajusta pontos: extrato, saldo e nível juntos.
select pg_temp.login('00000000-0000-0000-0000-000000000e01');
select pg_temp.expect(public.adjust_loyalty_points_atomic('00000000-0000-0000-0000-000000000e0a', '00000000-0000-0000-0000-000000000e0c', 100, 'Bônus aniversário') = 550, 'novo saldo de pontos');
select pg_temp.expect(public.adjust_loyalty_points_atomic('00000000-0000-0000-0000-000000000e0a', '00000000-0000-0000-0000-000000000e0c', -9999, 'Correção') = 0, 'nunca fica negativo');
reset role;
select pg_temp.expect((select count(*) = 2 and sum(points) = -450 from public.loyalty_point_entries where client_id = '00000000-0000-0000-0000-000000000e0c'), 'extrato registra o que de fato mudou');
select pg_temp.expect((select loyalty_points = 0 and loyalty_tier = 'Classic' and notes = 'ok' from public.clients where id = '00000000-0000-0000-0000-000000000e0c'), 'cliente com pontos e nível coerentes');
select pg_temp.expect(public.loyalty_tier_for(1500) = 'Gold' and public.loyalty_tier_for(499) = 'Classic', 'níveis espelham o app');

rollback;
\o
\echo 'saldo e pontos protegidos: ok'
