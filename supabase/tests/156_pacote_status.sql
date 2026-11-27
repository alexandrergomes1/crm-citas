-- Regra: pacote cancelado ou vencido nunca volta a ficar ativo (20261114080000).
-- Vale para a função de devolver sessão e para UPDATE direto. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000f60', 'dona@pacote.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-000000000f6a', 'pacote-a', 'Estúdio Pacote A');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000000f60', '00000000-0000-0000-0000-000000000f6a', 'owner');
insert into public.clients (id, org_id, full_name, status) values
  ('00000000-0000-0000-0000-000000000fc1', '00000000-0000-0000-0000-000000000f6a', 'Cliente Pacote', 'Ativo');
insert into public.client_entitlements (id, org_id, client_id, package_name, total_sessions, used_sessions, status, expires_at) values
  ('00000000-0000-0000-0000-000000000fe1', '00000000-0000-0000-0000-000000000f6a', '00000000-0000-0000-0000-000000000fc1', 'Cancelado', 4, 2, 'cancelled', null),
  ('00000000-0000-0000-0000-000000000fe2', '00000000-0000-0000-0000-000000000f6a', '00000000-0000-0000-0000-000000000fc1', 'Vencido', 4, 2, 'expired', null),
  ('00000000-0000-0000-0000-000000000fe3', '00000000-0000-0000-0000-000000000f6a', '00000000-0000-0000-0000-000000000fc1', 'Esgotado com data passada', 4, 4, 'exhausted', now() - interval '1 day'),
  ('00000000-0000-0000-0000-000000000fe4', '00000000-0000-0000-0000-000000000f6a', '00000000-0000-0000-0000-000000000fc1', 'Esgotado no prazo', 4, 4, 'exhausted', now() + interval '30 days'),
  ('00000000-0000-0000-0000-000000000fe5', '00000000-0000-0000-0000-000000000f6a', '00000000-0000-0000-0000-000000000fc1', 'Esgotado vencido (estorno)', 4, 4, 'exhausted', now() - interval '1 day');

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
create function pg_temp.status_of(p_id uuid) returns text language sql as $$
  select status from public.client_entitlements where id = p_id
$$;
grant execute on function pg_temp.expect(boolean, text), pg_temp.state_of(text), pg_temp.status_of(uuid) to authenticated;

-- UPDATE direto: cancelado e vencido não voltam a ativo nem a esgotado.
select pg_temp.expect(pg_temp.state_of($q$update public.client_entitlements set status = 'active' where id = '00000000-0000-0000-0000-000000000fe1'$q$) = '22023',
  'cancelado não volta a ativo');
select pg_temp.expect(pg_temp.state_of($q$update public.client_entitlements set status = 'exhausted' where id = '00000000-0000-0000-0000-000000000fe1'$q$) = '22023',
  'cancelado não vira esgotado');
select pg_temp.expect(pg_temp.state_of($q$update public.client_entitlements set status = 'expired' where id = '00000000-0000-0000-0000-000000000fe1'$q$) = '22023',
  'cancelado continua cancelado');
select pg_temp.expect(pg_temp.state_of($q$update public.client_entitlements set status = 'active' where id = '00000000-0000-0000-0000-000000000fe2'$q$) = '22023',
  'vencido não volta a ativo');

-- Mudar só as sessões (estorno que devolve sessão) mantém o status.
update public.client_entitlements set used_sessions = 1 where id = '00000000-0000-0000-0000-000000000fe1';
select pg_temp.expect(pg_temp.status_of('00000000-0000-0000-0000-000000000fe1') = 'cancelled', 'cancelado com sessão devolvida continua cancelado');
update public.client_entitlements set used_sessions = 1 where id = '00000000-0000-0000-0000-000000000fe2';
select pg_temp.expect(pg_temp.status_of('00000000-0000-0000-0000-000000000fe2') = 'expired', 'vencido com sessão devolvida continua vencido');

-- Gatilho: ficar ativo com validade passada vira vencido (ex.: estorno que devolve sessão).
update public.client_entitlements set used_sessions = 3, status = 'active' where id = '00000000-0000-0000-0000-000000000fe5';
select pg_temp.expect(pg_temp.status_of('00000000-0000-0000-0000-000000000fe5') = 'expired', 'ativo com validade passada vira vencido');

-- Vencido pode ser cancelado (estorno da venda do pacote).
update public.client_entitlements set status = 'cancelled' where id = '00000000-0000-0000-0000-000000000fe2';
select pg_temp.expect(pg_temp.status_of('00000000-0000-0000-0000-000000000fe2') = 'cancelled', 'vencido pode ser cancelado');

select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000f60', 'role', 'authenticated')::text, true);
set local role authenticated;
-- Devolver sessão pela função: esgotado com data passada é recusado e continua como estava.
select pg_temp.expect(pg_temp.state_of($q$select public.restore_entitlement_session_atomic('00000000-0000-0000-0000-000000000f6a', '00000000-0000-0000-0000-000000000fe3', '')$q$) = 'P0001',
  'pacote com validade passada recusa devolver sessão');
select pg_temp.expect(pg_temp.status_of('00000000-0000-0000-0000-000000000fe3') = 'exhausted', 'recusado não muda o pacote');
-- Esgotado dentro do prazo continua voltando a ativo.
select public.restore_entitlement_session_atomic('00000000-0000-0000-0000-000000000f6a', '00000000-0000-0000-0000-000000000fe4', 'Devolvida');
select pg_temp.expect(pg_temp.status_of('00000000-0000-0000-0000-000000000fe4') = 'active', 'esgotado no prazo volta a ativo');
reset role;
select set_config('request.jwt.claims', '', true);

-- A função do gatilho não é chamável por ninguém da API.
select pg_temp.expect(not has_function_privilege('authenticated', 'public.client_entitlements_status_guard()', 'execute'), 'authenticated sem execute no gatilho');
select pg_temp.expect(not has_function_privilege('anon', 'public.client_entitlements_status_guard()', 'execute'), 'anon sem execute no gatilho');

rollback;
\o
\echo 'pacote cancelado ou vencido não volta a ativo: ok'
