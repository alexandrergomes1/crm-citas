-- Preço e profissional do item numa operação só: total recalculado, trava, papel e auditoria.
-- Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000009c1', 'dono2@teste.local'),
  ('00000000-0000-0000-0000-0000000009c2', 'prof2@teste.local');
insert into public.organizations (id, slug, name) values ('00000000-0000-0000-0000-0000000009cc', 'item-a', 'Item');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-0000000009c1', '00000000-0000-0000-0000-0000000009cc', 'owner'),
  ('00000000-0000-0000-0000-0000000009c2', '00000000-0000-0000-0000-0000000009cc', 'professional');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-0000000009c3', '00000000-0000-0000-0000-0000000009cc', 'Lúcia Peña');
insert into public.staff_members (id, org_id, name) values
  ('00000000-0000-0000-0000-0000000009c4', '00000000-0000-0000-0000-0000000009cc', 'Karenn');
insert into public.services (id, org_id, name, price, duration_minutes) values
  ('00000000-0000-0000-0000-0000000009c5', '00000000-0000-0000-0000-0000000009cc', 'Limpeza de pele', 80, 60);

create function pg_temp.expect(p_ok boolean, p_msg text) returns void language plpgsql as $$
begin
  if not coalesce(p_ok, false) then raise exception 'FALHOU: %', p_msg; end if;
end $$;
grant execute on function pg_temp.expect(boolean, text) to authenticated;

create temp table t_ids (k text primary key, id uuid) on commit drop;
grant all on t_ids to authenticated;

select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000009c1', 'role', 'authenticated')::text, true);
select set_config('role', 'authenticated', true);
insert into t_ids values ('a', public.create_appointment_atomic(
  '00000000-0000-0000-0000-0000000009cc', '00000000-0000-0000-0000-0000000009c3', '00000000-0000-0000-0000-0000000009c4',
  '2030-03-04 10:00+00', '2030-03-04 12:00+00', 120, 'Agendado', 'MANUAL', null, null, 160,
  '[{"service_id":"00000000-0000-0000-0000-0000000009c5","service_name":"Limpeza de pele","price":80},
    {"service_id":"00000000-0000-0000-0000-0000000009c5","service_name":"Limpeza de pele","price":80}]'::jsonb, false));
insert into t_ids select 'item', id from public.appointment_items
  where appointment_id = (select id from t_ids where k = 'a') order by id limit 1;

do $$
declare v_total numeric; v_ok boolean;
begin
  v_total := public.update_appointment_item_atomic(
    '00000000-0000-0000-0000-0000000009cc', (select id from t_ids where k = 'a'), (select id from t_ids where k = 'item'),
    50, '00000000-0000-0000-0000-0000000009c4');
  perform pg_temp.expect(v_total = 130, 'total sai da soma dos itens (50 + 80)');
  perform pg_temp.expect((select total from public.appointments where id = (select id from t_ids where k = 'a')) = 130, 'total gravado no agendamento');
  perform pg_temp.expect((select price from public.appointment_items where id = (select id from t_ids where k = 'item')) = 50, 'preço do item gravado');
  perform pg_temp.expect(exists (select 1 from public.audit_logs where operation = 'APPOINTMENT_ITEM_UPDATED'
    and record_id = (select id from t_ids where k = 'item')), 'mudança fica no audit_logs');

  v_ok := false;
  begin
    perform public.update_appointment_item_atomic('00000000-0000-0000-0000-0000000009cc', (select id from t_ids where k = 'a'),
      (select id from t_ids where k = 'item'), -1, null);
  exception when check_violation then v_ok := true; end;
  perform pg_temp.expect(v_ok, 'preço negativo é recusado');

  v_ok := false;
  begin
    perform public.update_appointment_item_atomic('00000000-0000-0000-0000-0000000009cc', (select id from t_ids where k = 'a'),
      gen_random_uuid(), 10, null);
  exception when sqlstate 'P0002' then v_ok := true; end;
  perform pg_temp.expect(v_ok, 'item que não é do agendamento é recusado');
end $$;

-- Profissional não edita.
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000009c2', 'role', 'authenticated')::text, true);
do $$
declare v_ok boolean := false;
begin
  begin
    perform public.update_appointment_item_atomic('00000000-0000-0000-0000-0000000009cc', (select id from t_ids where k = 'a'),
      (select id from t_ids where k = 'item'), 1, null);
  exception when insufficient_privilege then v_ok := true; end;
  perform pg_temp.expect(v_ok, 'profissional não altera preço do item');
end $$;

-- Atendimento pago trava.
reset role;
do $$ begin
  update public.appointments set status = 'Pago' where id = (select id from t_ids where k = 'a');
exception when others then raise;
end $$;
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000009c1', 'role', 'authenticated')::text, true);
select set_config('role', 'authenticated', true);
do $$
declare v_ok boolean := false;
begin
  begin
    perform public.update_appointment_item_atomic('00000000-0000-0000-0000-0000000009cc', (select id from t_ids where k = 'a'),
      (select id from t_ids where k = 'item'), 1, null);
  exception when check_violation then v_ok := true; end;
  perform pg_temp.expect(v_ok, 'atendimento pago não aceita mudança de preço');
end $$;

reset role;
rollback;
\o
\echo 'item atômico: ok'
