-- Edição de série: só ocorrências em aberto; duração vai para o item único. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000008a1', 'serie@teste.local');
insert into public.organizations (id, slug, name) values ('00000000-0000-0000-0000-0000000008aa', 'serie-a', 'Série');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-0000000008a1', '00000000-0000-0000-0000-0000000008aa', 'owner');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-0000000008c1', '00000000-0000-0000-0000-0000000008aa', 'Inés Ruiz');
insert into public.staff_members (id, org_id, name) values
  ('00000000-0000-0000-0000-0000000008b1', '00000000-0000-0000-0000-0000000008aa', 'Karenn');
insert into public.services (id, org_id, name, price, duration_minutes) values
  ('00000000-0000-0000-0000-0000000008d1', '00000000-0000-0000-0000-0000000008aa', 'Drenagem', 60, 60);

create function pg_temp.expect(p_ok boolean, p_msg text) returns void language plpgsql as $$
begin
  if not coalesce(p_ok, false) then raise exception 'FALHOU: %', p_msg; end if;
end $$;
grant execute on function pg_temp.expect(boolean, text) to authenticated;
create temp table t_serie (rec uuid) on commit drop;
grant all on t_serie to authenticated;

select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000008a1', 'role', 'authenticated')::text, true);
select set_config('role', 'authenticated', true);

insert into t_serie select (public.create_recurring_appointments_atomic(
  '00000000-0000-0000-0000-0000000008aa', '00000000-0000-0000-0000-0000000008c1', '00000000-0000-0000-0000-0000000008b1',
  'Karenn', 'Agendado', 'MANUAL', null, null, 60, 60,
  '[{"index":1,"start_at":"2031-03-03 10:00+00","end_at":"2031-03-03 11:00+00"},
    {"index":2,"start_at":"2031-03-10 10:00+00","end_at":"2031-03-10 11:00+00"}]'::jsonb,
  '[{"service_id":"00000000-0000-0000-0000-0000000008d1","service_name":"Drenagem","price":60,"duration_minutes":60}]'::jsonb,
  false) ->> 'recurrence_id')::uuid;

-- Duração nova da série vai para o item único.
select public.update_recurrence_series_atomic('00000000-0000-0000-0000-0000000008aa', (select rec from t_serie),
  '00000000-0000-0000-0000-0000000008b1', 90, null,
  (select jsonb_agg(jsonb_build_object('id', id, 'start_at', start_at, 'end_at', start_at + interval '90 minutes'))
     from public.appointments where recurrence_id = (select rec from t_serie)),
  false);
reset role;
select pg_temp.expect((select bool_and(i.duration_minutes = 90) from public.appointment_items i
  join public.appointments a on a.id = i.appointment_id where a.recurrence_id = (select rec from t_serie)),
  'item único recebe a duração da série');

-- Ocorrência com ausência não é reescrita.
update public.appointments set status = 'Ausência'
where recurrence_id = (select rec from t_serie) and recurrence_index = 1;
select set_config('role', 'authenticated', true);
do $$
declare v_ok boolean := false;
begin
  begin
    perform public.update_recurrence_series_atomic('00000000-0000-0000-0000-0000000008aa', (select rec from t_serie),
      '00000000-0000-0000-0000-0000000008b1', 45, null,
      (select jsonb_agg(jsonb_build_object('id', id, 'start_at', start_at, 'end_at', start_at + interval '45 minutes'))
         from public.appointments where recurrence_id = (select rec from t_serie)),
      false);
  exception when raise_exception then v_ok := sqlerrm like 'A serie mudou%';
  end;
  perform pg_temp.expect(v_ok, 'ocorrência com ausência não entra na edição da série');
end $$;
reset role;

rollback;
\o
\echo 'série recorrente: ok'
