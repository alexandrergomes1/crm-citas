-- Itens do agendamento e anamnese: papel e trava no banco. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000009a1', 'dono@teste.local'),
  ('00000000-0000-0000-0000-0000000009a2', 'recep@teste.local'),
  ('00000000-0000-0000-0000-0000000009a3', 'prof@teste.local'),
  ('00000000-0000-0000-0000-0000000009a4', 'visu@teste.local');
insert into public.organizations (id, slug, name) values ('00000000-0000-0000-0000-0000000009aa', 'gate-a', 'Gate');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-0000000009a1', '00000000-0000-0000-0000-0000000009aa', 'owner'),
  ('00000000-0000-0000-0000-0000000009a2', '00000000-0000-0000-0000-0000000009aa', 'receptionist'),
  ('00000000-0000-0000-0000-0000000009a3', '00000000-0000-0000-0000-0000000009aa', 'professional'),
  ('00000000-0000-0000-0000-0000000009a4', '00000000-0000-0000-0000-0000000009aa', 'viewer');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-0000000009a5', '00000000-0000-0000-0000-0000000009aa', 'Lúcia Peña');
insert into public.staff_members (id, org_id, name) values
  ('00000000-0000-0000-0000-0000000009a6', '00000000-0000-0000-0000-0000000009aa', 'Karenn');
insert into public.services (id, org_id, name, price, duration_minutes) values
  ('00000000-0000-0000-0000-0000000009a7', '00000000-0000-0000-0000-0000000009aa', 'Limpeza de pele', 80, 60);

create function pg_temp.expect(p_ok boolean, p_msg text) returns void language plpgsql as $$
begin
  if not coalesce(p_ok, false) then raise exception 'FALHOU: %', p_msg; end if;
end $$;
grant execute on function pg_temp.expect(boolean, text) to authenticated;

create temp table t_ids (k text primary key, id uuid) on commit drop;
grant all on t_ids to authenticated;

-- Dois agendamentos pela RPC (como a dona): um aberto e um que vira Pago.
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000009a1', 'role', 'authenticated')::text, true);
select set_config('role', 'authenticated', true);
insert into t_ids values ('aberto', public.create_appointment_atomic(
  '00000000-0000-0000-0000-0000000009aa', '00000000-0000-0000-0000-0000000009a5', '00000000-0000-0000-0000-0000000009a6',
  '2030-02-04 10:00+00', '2030-02-04 11:00+00', 60, 'Agendado', 'MANUAL', null, null, 80,
  '[{"service_id":"00000000-0000-0000-0000-0000000009a7","service_name":"Limpeza de pele","price":80}]'::jsonb, false));
insert into t_ids values ('pago', public.create_appointment_atomic(
  '00000000-0000-0000-0000-0000000009aa', '00000000-0000-0000-0000-0000000009a5', '00000000-0000-0000-0000-0000000009a6',
  '2030-02-05 10:00+00', '2030-02-05 11:00+00', 60, 'Agendado', 'MANUAL', null, null, 80,
  '[{"service_id":"00000000-0000-0000-0000-0000000009a7","service_name":"Limpeza de pele","price":80}]'::jsonb, false));

reset role;
-- A trava poupa linhas escritas na transação atual (RPCs). Aqui tudo roda numa transação só;
-- o bloco com EXCEPTION abre uma subtransação, então a linha fica com outro xmin, como
-- ficaria se o atendimento tivesse sido pago numa chamada anterior.
do $$ begin
  update public.appointments set status = 'Pago' where id = (select id from t_ids where k = 'pago');
exception when others then raise;
end $$;

-- Dona mexe no item do aberto: ok. No do pago: barrado (update, insert e delete).
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000009a1', 'role', 'authenticated')::text, true);
select set_config('role', 'authenticated', true);
do $$
declare v_ok boolean; v_n int;
begin
  update public.appointment_items set price = 70 where appointment_id = (select id from t_ids where k = 'aberto');
  get diagnostics v_n = row_count;
  perform pg_temp.expect(v_n = 1, 'dona altera item de atendimento aberto');

  v_ok := false;
  begin
    update public.appointment_items set price = 1 where appointment_id = (select id from t_ids where k = 'pago');
  exception when check_violation then v_ok := true; end;
  perform pg_temp.expect(v_ok, 'item de atendimento pago não muda de preço');

  v_ok := false;
  begin
    delete from public.appointment_items where appointment_id = (select id from t_ids where k = 'pago');
  exception when check_violation then v_ok := true; end;
  perform pg_temp.expect(v_ok, 'item de atendimento pago não é apagado');

  v_ok := false;
  begin
    insert into public.appointment_items (org_id, appointment_id, type, name, price, qty)
    values ('00000000-0000-0000-0000-0000000009aa', (select id from t_ids where k = 'pago'), 'service', 'Extra', 10, 1);
  exception when check_violation then v_ok := true; end;
  perform pg_temp.expect(v_ok, 'não entra item novo em atendimento pago');
end $$;

-- Recepção opera; profissional e visualizadora não gravam item.
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000009a2', 'role', 'authenticated')::text, true);
do $$
declare v_n int;
begin
  update public.appointment_items set price = 75 where appointment_id = (select id from t_ids where k = 'aberto');
  get diagnostics v_n = row_count;
  perform pg_temp.expect(v_n = 1, 'recepção altera item de atendimento aberto');
end $$;

select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000009a3', 'role', 'authenticated')::text, true);
do $$
declare v_n int; v_ok boolean;
begin
  update public.appointment_items set price = 1 where appointment_id = (select id from t_ids where k = 'aberto');
  get diagnostics v_n = row_count;
  perform pg_temp.expect(v_n = 0, 'profissional não altera item por PostgREST');
  delete from public.appointment_items where appointment_id = (select id from t_ids where k = 'aberto');
  get diagnostics v_n = row_count;
  perform pg_temp.expect(v_n = 0, 'profissional não apaga item');
  v_ok := false;
  begin
    insert into public.appointment_items (org_id, appointment_id, type, name, price, qty)
    values ('00000000-0000-0000-0000-0000000009aa', (select id from t_ids where k = 'aberto'), 'service', 'Extra', 10, 1);
  exception when insufficient_privilege then v_ok := true; end;
  perform pg_temp.expect(v_ok, 'profissional não insere item');
end $$;

select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000009a4', 'role', 'authenticated')::text, true);
do $$
declare v_n int;
begin
  update public.appointment_items set price = 1 where appointment_id = (select id from t_ids where k = 'aberto');
  get diagnostics v_n = row_count;
  perform pg_temp.expect(v_n = 0, 'visualizadora não altera item');
end $$;

-- Anamnese: recepção não grava nota profissional nem atualiza a linha.
reset role;
-- Gerada pela profissional (created_by vem do banco: 20261114040000), com parte profissional.
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000009a3', 'role', 'authenticated')::text, true);
insert into public.anamneses (id, org_id, client_name, status, public_token, requires_professional)
values ('00000000-0000-0000-0000-0000000009b1', '00000000-0000-0000-0000-0000000009aa', 'Lúcia Peña', 'pending', 'tok-gate-0123456789abcdef0123456789', true);
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000009a2', 'role', 'authenticated')::text, true);
select set_config('role', 'authenticated', true);
do $$
declare v_ok boolean;
begin
  v_ok := false;
  begin
    perform public.anamnese_save_professional('00000000-0000-0000-0000-0000000009aa', '00000000-0000-0000-0000-0000000009b1', '{}'::jsonb, '{}'::jsonb, 'nota', false);
  exception when insufficient_privilege then v_ok := true; end;
  perform pg_temp.expect(v_ok, 'recepção não grava nota profissional');

  v_ok := false;
  begin
    update public.anamneses set professional_notes = 'x' where id = '00000000-0000-0000-0000-0000000009b1';
  exception when insufficient_privilege then v_ok := true; end;
  perform pg_temp.expect(v_ok, 'recepção não atualiza a ficha por PostgREST (tabela fechada)');
end $$;

select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000009a3', 'role', 'authenticated')::text, true);
do $$
begin
  perform public.anamnese_save_professional('00000000-0000-0000-0000-0000000009aa', '00000000-0000-0000-0000-0000000009b1', '{}'::jsonb, '{}'::jsonb, 'nota da profissional', false);
end $$;

reset role;
select pg_temp.expect((select professional_notes from public.anamneses where id = '00000000-0000-0000-0000-0000000009b1') = 'nota da profissional', 'profissional grava nota');
rollback;
\o
\echo 'itens e anamnese por papel: ok'
