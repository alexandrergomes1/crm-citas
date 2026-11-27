-- Duração por item do agendamento (spec 35). Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000000d1', 'dur@teste.local');
insert into public.organizations (id, slug, name) values ('00000000-0000-0000-0000-0000000000dd', 'dur-a', 'Dur');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000dd', 'owner');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000dd', 'Lúcia Peña');
insert into public.staff_members (id, org_id, name) values
  ('00000000-0000-0000-0000-0000000000d3', '00000000-0000-0000-0000-0000000000dd', 'Karenn');
insert into public.services (id, org_id, name, price, duration_minutes) values
  ('00000000-0000-0000-0000-0000000000d4', '00000000-0000-0000-0000-0000000000dd', 'Limpeza de pele', 80, 60);

create function pg_temp.expect(p_ok boolean, p_msg text) returns void language plpgsql as $$
begin
  if not coalesce(p_ok, false) then raise exception 'FALHOU: %', p_msg; end if;
end $$;
grant execute on function pg_temp.expect(boolean, text) to authenticated;

select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000000d1', 'role', 'authenticated')::text, true);
select set_config('role', 'authenticated', true);

-- Item com duração própria (30 min de um serviço de 60) e item antigo sem duração.
create temp table t_ids (k text primary key, id uuid) on commit drop;
grant all on t_ids to authenticated;
insert into t_ids values ('a', public.create_appointment_atomic(
  '00000000-0000-0000-0000-0000000000dd', '00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000d3',
  '2030-01-07 10:00+00', '2030-01-07 11:30+00', 90, 'Agendado', 'MANUAL', null, null, 160,
  '[{"service_id":"00000000-0000-0000-0000-0000000000d4","service_name":"Limpeza de pele","price":80,"duration_minutes":30},
    {"service_id":"00000000-0000-0000-0000-0000000000d4","service_name":"Limpeza de pele","price":80}]'::jsonb,
  false));

do $$ begin
  perform pg_temp.expect(
    (select array_agg(duration_minutes order by duration_minutes nulls last) from public.appointment_items
      where appointment_id = (select id from t_ids where k = 'a'))::text = '{30,NULL}',
    'grava 30 min no item e deixa nulo o item sem duração');
end $$;

-- Atualização troca a duração do item.
select public.update_appointment_atomic(
  '00000000-0000-0000-0000-0000000000dd', (select id from t_ids where k = 'a'),
  '00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000d3',
  '2030-01-07 10:00+00', '2030-01-07 10:45+00', 45, 'Agendado', 'MANUAL', null, null, 80,
  '[{"service_id":"00000000-0000-0000-0000-0000000000d4","service_name":"Limpeza de pele","price":80,"duration_minutes":45}]'::jsonb,
  false);
do $$ begin
  perform pg_temp.expect(
    (select duration_minutes from public.appointment_items where appointment_id = (select id from t_ids where k = 'a')) = 45,
    'atualização grava a nova duração');
end $$;

-- Fora dos limites: recusado pela RPC (e pela coluna).
do $$
declare v_ok boolean := false;
begin
  begin
    perform public.create_appointment_atomic(
      '00000000-0000-0000-0000-0000000000dd', '00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000d3',
      '2030-01-08 10:00+00', '2030-01-08 10:03+00', 3, 'Agendado', 'MANUAL', null, null, 80,
      '[{"service_id":"00000000-0000-0000-0000-0000000000d4","service_name":"Limpeza de pele","price":80,"duration_minutes":3}]'::jsonb,
      false);
  exception when invalid_parameter_value then v_ok := sqlerrm = 'Duracao do item invalida';
  end;
  perform pg_temp.expect(v_ok, 'recusa item com 3 min');

  v_ok := false;
  begin
    perform public.create_recurring_appointments_atomic(
      '00000000-0000-0000-0000-0000000000dd', '00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000d3',
      'Karenn', 'Agendado', 'MANUAL', null, null, 60, 80,
      '[{"index":1,"start_at":"2030-02-01 10:00+00","end_at":"2030-02-01 11:00+00"},{"index":2,"start_at":"2030-02-08 10:00+00","end_at":"2030-02-08 11:00+00"}]'::jsonb,
      '[{"service_id":"00000000-0000-0000-0000-0000000000d4","service_name":"Limpeza de pele","price":80,"duration_minutes":900}]'::jsonb,
      false);
  exception when invalid_parameter_value then v_ok := sqlerrm = 'Duracao do item invalida';
  end;
  perform pg_temp.expect(v_ok, 'recorrência recusa item com 900 min');
end $$;

reset role;
do $$
declare v_ok boolean := false;
begin
  begin
    update public.appointment_items set duration_minutes = 1000
    where appointment_id = (select id from t_ids where k = 'a');
  exception when check_violation then v_ok := true;
  end;
  perform pg_temp.expect(v_ok, 'coluna recusa 1000 min');
end $$;

rollback;
\o
\echo 'duração por item: ok'
