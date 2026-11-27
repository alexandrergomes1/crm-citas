-- Sinal: arredonda antes de validar e a chave de repetição vale só para o mesmo agendamento.
-- Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000011a1', 'dono4@teste.local');
insert into public.organizations (id, slug, name, timezone) values ('00000000-0000-0000-0000-0000000011aa', 'sinal-a', 'Sinal', 'Europe/Madrid');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-0000000011a1', '00000000-0000-0000-0000-0000000011aa', 'owner');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-0000000011a3', '00000000-0000-0000-0000-0000000011aa', 'Lúcia Peña');
insert into public.staff_members (id, org_id, name) values
  ('00000000-0000-0000-0000-0000000011a4', '00000000-0000-0000-0000-0000000011aa', 'Karenn');
insert into public.services (id, org_id, name, price, duration_minutes) values
  ('00000000-0000-0000-0000-0000000011a5', '00000000-0000-0000-0000-0000000011aa', 'Limpeza de pele', 80, 60);

create function pg_temp.expect(p_ok boolean, p_msg text) returns void language plpgsql as $$
begin
  if not coalesce(p_ok, false) then raise exception 'FALHOU: %', p_msg; end if;
end $$;
grant execute on function pg_temp.expect(boolean, text) to authenticated;
create temp table t_ids (k text primary key, id uuid) on commit drop;
grant all on t_ids to authenticated;

select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000011a1', 'role', 'authenticated')::text, true);
select set_config('role', 'authenticated', true);
insert into t_ids values ('a', public.create_appointment_atomic(
  '00000000-0000-0000-0000-0000000011aa', '00000000-0000-0000-0000-0000000011a3', '00000000-0000-0000-0000-0000000011a4',
  '2030-04-02 10:00+00', '2030-04-02 11:00+00', 60, 'Agendado', 'MANUAL', null, null, 80,
  '[{"service_id":"00000000-0000-0000-0000-0000000011a5","service_name":"Limpeza de pele","price":80}]'::jsonb, false));
insert into t_ids values ('b', public.create_appointment_atomic(
  '00000000-0000-0000-0000-0000000011aa', '00000000-0000-0000-0000-0000000011a3', '00000000-0000-0000-0000-0000000011a4',
  '2030-04-03 10:00+00', '2030-04-03 11:00+00', 60, 'Agendado', 'MANUAL', null, null, 80,
  '[{"service_id":"00000000-0000-0000-0000-0000000011a5","service_name":"Limpeza de pele","price":80}]'::jsonb, false));

do $$
declare v_ok boolean := false; v_r jsonb;
begin
  begin
    perform public.register_appointment_deposit_atomic('00000000-0000-0000-0000-0000000011aa', (select id from t_ids where k = 'a'),
      0.004, 'CASH', '00000000-0000-0000-0000-0000000011c1');
  exception when numeric_value_out_of_range then v_ok := true; end;
  perform pg_temp.expect(v_ok, 'sinal que arredonda para zero é recusado');

  v_r := public.register_appointment_deposit_atomic('00000000-0000-0000-0000-0000000011aa', (select id from t_ids where k = 'a'),
    20.005, 'CASH', '00000000-0000-0000-0000-0000000011c2');
  perform pg_temp.expect((v_r ->> 'amount')::numeric = 20.01 and (v_r ->> 'duplicate')::boolean = false, 'sinal arredondado a 20,01');
  v_r := public.register_appointment_deposit_atomic('00000000-0000-0000-0000-0000000011aa', (select id from t_ids where k = 'a'),
    20.005, 'CASH', '00000000-0000-0000-0000-0000000011c2');
  perform pg_temp.expect((v_r ->> 'duplicate')::boolean = true, 'mesma chave e mesmo agendamento repete');

  v_ok := false;
  begin
    perform public.register_appointment_deposit_atomic('00000000-0000-0000-0000-0000000011aa', (select id from t_ids where k = 'b'),
      20.005, 'CASH', '00000000-0000-0000-0000-0000000011c2');
  exception when check_violation then v_ok := true; end;
  perform pg_temp.expect(v_ok, 'mesma chave em outro agendamento é recusada');

  perform pg_temp.expect((select count(*) from public.appointment_deposits
    where appointment_id = (select id from t_ids where k = 'b')) = 0, 'outro agendamento não ganhou sinal');
end $$;

reset role;
rollback;
\o
\echo 'sinal arredondado: ok'
