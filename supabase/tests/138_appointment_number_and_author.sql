-- Número do agendamento (sequencial por estúdio) e quem criou (20261030230000). Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000001300', 'dona@numero.local'),
  ('00000000-0000-0000-0000-000000001301', 'recep@numero.local'),
  ('00000000-0000-0000-0000-000000001302', 'donab@numero.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-00000000130a', 'numero-a', 'Número A'),
  ('00000000-0000-0000-0000-00000000130b', 'numero-b', 'Número B');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000001300', '00000000-0000-0000-0000-00000000130a', 'owner'),
  ('00000000-0000-0000-0000-000000001301', '00000000-0000-0000-0000-00000000130a', 'receptionist'),
  ('00000000-0000-0000-0000-000000001302', '00000000-0000-0000-0000-00000000130b', 'owner');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-000000001303', '00000000-0000-0000-0000-00000000130a', 'Cliente A'),
  ('00000000-0000-0000-0000-000000001304', '00000000-0000-0000-0000-00000000130b', 'Cliente B');
insert into public.staff_members (id, org_id, name) values
  ('00000000-0000-0000-0000-000000001305', '00000000-0000-0000-0000-00000000130a', 'Karenn');
insert into public.services (id, org_id, name, price, duration_minutes) values
  ('00000000-0000-0000-0000-000000001306', '00000000-0000-0000-0000-00000000130a', 'Limpeza', 60, 60);

create function pg_temp.expect(p_ok boolean, p_msg text) returns void language plpgsql as $$
begin
  if not coalesce(p_ok, false) then raise exception 'FALHOU: %', p_msg; end if;
end $$;
create function pg_temp.err(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return 'OK';
exception when others then
  return sqlstate || ' ' || sqlerrm;
end $$;
create function pg_temp.login(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;
create function pg_temp.mk(p_start text) returns uuid language sql as $$
  select public.create_appointment_atomic('00000000-0000-0000-0000-00000000130a', '00000000-0000-0000-0000-000000001303', '00000000-0000-0000-0000-000000001305',
    p_start::timestamptz, p_start::timestamptz + interval '60 minutes', 60, 'Agendado', 'MANUAL', null, null, 60,
    '[{"service_id":"00000000-0000-0000-0000-000000001306","service_name":"Limpeza","price":60}]'::jsonb, false)
$$;
create temp table t_ids (k text primary key, id uuid) on commit drop;
grant all on t_ids to authenticated;
grant execute on function pg_temp.expect(boolean, text), pg_temp.err(text), pg_temp.login(uuid), pg_temp.mk(text) to authenticated;

-- ═══ A. Numeração: 1, 2, 3 no estúdio; outro estúdio começa do 1 ═══
select pg_temp.login('00000000-0000-0000-0000-000000001300');
insert into t_ids values ('a1', pg_temp.mk('2035-06-01 09:00+00'));
select pg_temp.login('00000000-0000-0000-0000-000000001301');
insert into t_ids values ('a2', pg_temp.mk('2035-06-02 09:00+00')), ('a3', pg_temp.mk('2035-06-03 09:00+00'));
reset role;
select set_config('request.jwt.claims', '', true);
insert into public.appointments (id, org_id, client_id, client_name, start_at, end_at, duration_minutes, status) values
  ('00000000-0000-0000-0000-0000000013b1', '00000000-0000-0000-0000-00000000130b', '00000000-0000-0000-0000-000000001304', 'Cliente B',
   '2035-06-01 09:00+00', '2035-06-01 10:00+00', 60, 'Agendado');

select pg_temp.expect((select number from public.appointments where id = (select id from t_ids where k = 'a1')) = 1, 'primeiro agendamento do estúdio é o 1');
select pg_temp.expect((select number from public.appointments where id = (select id from t_ids where k = 'a2')) = 2
  and (select number from public.appointments where id = (select id from t_ids where k = 'a3')) = 3, 'depois o 2 e o 3');
select pg_temp.expect((select number from public.appointments where id = '00000000-0000-0000-0000-0000000013b1') = 1, 'o outro estúdio tem a sua própria sequência');

-- ═══ B. O número vem do banco: o enviado pelo app é ignorado; repetir é barrado ═══
insert into public.appointments (id, org_id, client_id, client_name, start_at, end_at, duration_minutes, status, number) values
  ('00000000-0000-0000-0000-0000000013b2', '00000000-0000-0000-0000-00000000130a', '00000000-0000-0000-0000-000000001303', 'Cliente A',
   '2035-06-04 09:00+00', '2035-06-04 10:00+00', 60, 'Agendado', 999);
select pg_temp.expect((select number from public.appointments where id = '00000000-0000-0000-0000-0000000013b2') = 4, 'número enviado é ignorado: segue a sequência');
select pg_temp.expect(pg_temp.err($q$insert into public.appointments (org_id, client_id, client_name, start_at, end_at, duration_minutes, status, number)
  values ('00000000-0000-0000-0000-00000000130a', '00000000-0000-0000-0000-000000001303', 'Cliente A', '2035-06-05 09:00+00', '2035-06-05 10:00+00', 60, 'Agendado', 1)$q$) = 'OK',
  'inserir informando um número usado não falha, porque o banco escolhe outro');
select pg_temp.expect((select count(distinct number) = count(*) from public.appointments where org_id = '00000000-0000-0000-0000-00000000130a'), 'nenhum número repetido no estúdio');
select pg_temp.expect(pg_temp.err($q$update public.appointments set number = 1 where id = '00000000-0000-0000-0000-0000000013b2'$q$) like '42501%',
  'número não muda depois de gravado');
select pg_temp.expect(pg_temp.err($q$insert into public.appointments (id, org_id, client_id, client_name, start_at, end_at, duration_minutes, status)
  values ('00000000-0000-0000-0000-0000000013b9', '00000000-0000-0000-0000-00000000130a', '00000000-0000-0000-0000-000000001303', 'Cliente A', '2035-06-09 09:00+00', '2035-06-09 10:00+00', 60, 'Agendado')$q$) = 'OK',
  'sem informar número, o banco atribui');
select pg_temp.expect((select count(*) = 1 from pg_constraint where conname = 'appointments_org_number_key' and contype = 'u'), 'número é único por estúdio');

-- ═══ C. Transação desfeita não deixa buraco na sequência ═══
do $$
declare v_before integer; v_after integer;
begin
  select max(number) into v_before from public.appointments where org_id = '00000000-0000-0000-0000-00000000130a';
  begin
    insert into public.appointments (org_id, client_id, client_name, start_at, end_at, duration_minutes, status)
    values ('00000000-0000-0000-0000-00000000130a', '00000000-0000-0000-0000-000000001303', 'Cliente A', '2035-06-06 09:00+00', '2035-06-06 10:00+00', 60, 'Agendado');
    raise exception 'desfaz de propósito';
  exception when others then null;
  end;
  insert into public.appointments (id, org_id, client_id, client_name, start_at, end_at, duration_minutes, status)
  values ('00000000-0000-0000-0000-0000000013b3', '00000000-0000-0000-0000-00000000130a', '00000000-0000-0000-0000-000000001303', 'Cliente A', '2035-06-07 09:00+00', '2035-06-07 10:00+00', 60, 'Agendado');
  select number into v_after from public.appointments where id = '00000000-0000-0000-0000-0000000013b3';
  perform pg_temp.expect(v_after = v_before + 1, 'agendamento desfeito não consome número');
end $$;

-- ═══ D. Autor: quem criou fica gravado; criação sem sessão fica sem autor ═══
select pg_temp.expect((select created_by = '00000000-0000-0000-0000-000000001300' from public.appointments where id = (select id from t_ids where k = 'a1')), 'autor do primeiro: a dona');
select pg_temp.expect((select created_by = '00000000-0000-0000-0000-000000001301' from public.appointments where id = (select id from t_ids where k = 'a2')), 'autor do segundo: a recepção');
select pg_temp.expect((select created_by is null from public.appointments where id = '00000000-0000-0000-0000-0000000013b2'), 'sem sessão de usuário, sem autor');
select pg_temp.expect(pg_temp.err(format($q$update public.appointments set created_by = '00000000-0000-0000-0000-000000001301' where id = %L$q$, (select id from t_ids where k = 'a1'))) like '42501%',
  'autor não é reescrito');
-- O autor da mudança de status já fica no histórico (changed_by).
select pg_temp.login('00000000-0000-0000-0000-000000001301');
select public.set_appointment_status_atomic('00000000-0000-0000-0000-00000000130a', (select id from t_ids where k = 'a1'), 'Confirmado');
reset role;
select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select changed_by = '00000000-0000-0000-0000-000000001301' from public.appointment_status_history
  where appointment_id = (select id from t_ids where k = 'a1') and status = 'Confirmado'), 'histórico guarda quem confirmou');
select pg_temp.expect((select number = 1 from public.appointments where id = (select id from t_ids where k = 'a1')), 'o número não muda ao mudar o status');

-- ═══ E. O contador é interno ═══
select pg_temp.login('00000000-0000-0000-0000-000000001300');
select pg_temp.expect(pg_temp.err('select * from public.appointment_counters') like '42501%', 'ninguém lê o contador pela API');
select pg_temp.expect(pg_temp.err($q$update public.appointment_counters set last_number = 0$q$) like '42501%', 'nem altera');

rollback;
\o
\echo 'número e autor do agendamento: ok'
