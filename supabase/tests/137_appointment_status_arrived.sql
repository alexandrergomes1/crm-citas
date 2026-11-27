-- Status "Chegou" ponta a ponta (20261030220000): valor aceito pelo banco, transições, trava da
-- Ficha Cliente ao chegar, trilha de histórico com quem mudou, permissão e reagendamento.
-- Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000001290', 'dona@chegou.local'),
  ('00000000-0000-0000-0000-000000001291', 'recep@chegou.local'),
  ('00000000-0000-0000-0000-000000001292', 'prof@chegou.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-00000000129a', 'chegou-a', 'Chegou A');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000001290', '00000000-0000-0000-0000-00000000129a', 'owner'),
  ('00000000-0000-0000-0000-000000001291', '00000000-0000-0000-0000-00000000129a', 'receptionist'),
  ('00000000-0000-0000-0000-000000001292', '00000000-0000-0000-0000-00000000129a', 'professional');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-000000001293', '00000000-0000-0000-0000-00000000129a', 'Cliente Chegou');
insert into public.staff_members (id, org_id, name) values
  ('00000000-0000-0000-0000-000000001294', '00000000-0000-0000-0000-00000000129a', 'Karenn');
insert into public.anamnese_templates (id, org_id, title, questions) values
  ('00000000-0000-0000-0000-000000001295', '00000000-0000-0000-0000-00000000129a', 'Ficha facial',
   '[{"id":"q1","label":"Alergias?","type":"text"}]'::jsonb);
insert into public.services (id, org_id, name, price, duration_minutes, requires_anamnese, anamnese_template_id) values
  ('00000000-0000-0000-0000-000000001296', '00000000-0000-0000-0000-00000000129a', 'Massagem', 60, 60, false, null),
  ('00000000-0000-0000-0000-000000001297', '00000000-0000-0000-0000-00000000129a', 'Limpeza facial', 80, 60, true, '00000000-0000-0000-0000-000000001295');

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
create function pg_temp.mk(p_start text, p_service uuid default '00000000-0000-0000-0000-000000001296', p_status text default 'Agendado') returns uuid language sql as $$
  select public.create_appointment_atomic('00000000-0000-0000-0000-00000000129a', '00000000-0000-0000-0000-000000001293', '00000000-0000-0000-0000-000000001294',
    p_start::timestamptz, p_start::timestamptz + interval '60 minutes', 60, p_status, 'MANUAL', null, null, 60,
    format('[{"service_id":"%s","service_name":"Servico","price":60}]', p_service)::jsonb, false)
$$;
create function pg_temp.setst(p_id uuid, p_status text) returns text language sql as $$
  select pg_temp.err(format('select public.set_appointment_status_atomic(%L, %L, %L)', '00000000-0000-0000-0000-00000000129a', p_id, p_status))
$$;
create temp table t_ids (k text primary key, id uuid) on commit drop;
grant all on t_ids to authenticated;
grant execute on function pg_temp.expect(boolean, text), pg_temp.err(text), pg_temp.login(uuid), pg_temp.mk(text, uuid, text), pg_temp.setst(uuid, text) to authenticated;

select pg_temp.login('00000000-0000-0000-0000-000000001290');
insert into t_ids values
  ('flow', pg_temp.mk('2035-02-02 09:00+00')),
  ('conf', pg_temp.mk('2035-02-03 09:00+00')),
  ('res', pg_temp.mk('2035-02-04 09:00+00', '00000000-0000-0000-0000-000000001296', 'Reservado')),
  ('cancel', pg_temp.mk('2035-02-05 09:00+00')),
  ('ficha', pg_temp.mk('2035-02-07 09:00+00', '00000000-0000-0000-0000-000000001297')),
  ('prof', pg_temp.mk('2035-02-08 09:00+00'));
reset role;
select set_config('request.jwt.claims', '', true);

-- ═══ A. O banco aceita o valor e o fluxo Agendado -> Chegou -> Iniciado -> Concluído ═══
select pg_temp.expect((select pg_get_constraintdef(oid) like '%Chegou%' from pg_constraint where conname = 'appointments_status_canonical'),
  'a restrição de status inclui Chegou');
select pg_temp.expect(public.agenda_status_transition_allowed('Agendado', 'Chegou') and public.agenda_status_transition_allowed('Confirmado', 'Chegou')
  and public.agenda_status_transition_allowed('Chegou', 'Iniciado') and public.agenda_status_transition_allowed('Chegou', 'Cancelado'),
  'transições permitidas a partir de Agendado/Confirmado e de Chegou');
select pg_temp.expect(not public.agenda_status_transition_allowed('Reservado', 'Chegou') and not public.agenda_status_transition_allowed('Iniciado', 'Chegou')
  and not public.agenda_status_transition_allowed('Chegou', 'Confirmado') and not public.agenda_status_transition_allowed('Chegou', 'Agendado')
  and not public.agenda_status_transition_allowed('Chegou', 'Ausência') and not public.agenda_status_transition_allowed('Chegou', 'Concluído')
  and not public.agenda_status_transition_allowed('Concluído', 'Chegou'),
  'transições recusadas (não volta, não pula, falta só antes de chegar)');
select pg_temp.expect(public.agenda_status_transition_allowed('Agendado', 'Iniciado') and public.agenda_status_transition_allowed('Confirmado', 'Iniciado'),
  'o app antigo ainda inicia direto de Agendado/Confirmado');

select pg_temp.login('00000000-0000-0000-0000-000000001291');
select pg_temp.expect(pg_temp.setst((select id from t_ids where k = 'flow'), 'Confirmado') = 'OK', 'confirma');
select pg_temp.expect(pg_temp.setst((select id from t_ids where k = 'flow'), 'Chegou') = 'OK', 'Confirmado -> Chegou');
select pg_temp.expect(pg_temp.setst((select id from t_ids where k = 'flow'), 'Chegou') = 'OK', 'repetir Chegou não falha nem duplica');
select pg_temp.expect(pg_temp.setst((select id from t_ids where k = 'flow'), 'Ausência') like '22023%', 'quem já chegou não vira falta');
select pg_temp.expect(pg_temp.setst((select id from t_ids where k = 'flow'), 'Confirmado') like '22023%', 'quem chegou não volta para Confirmado');
select pg_temp.expect(pg_temp.setst((select id from t_ids where k = 'flow'), 'Iniciado') = 'OK', 'Chegou -> Iniciado');
select pg_temp.expect(pg_temp.setst((select id from t_ids where k = 'flow'), 'Chegou') like '22023%', 'Iniciado não volta para Chegou');
select pg_temp.expect(pg_temp.setst((select id from t_ids where k = 'flow'), 'Concluído') = 'OK', 'Iniciado -> Concluído');

-- Agendado vai direto para Chegou; Reservado precisa confirmar antes.
select pg_temp.expect(pg_temp.setst((select id from t_ids where k = 'conf'), 'Chegou') = 'OK', 'Agendado -> Chegou');
select pg_temp.expect(pg_temp.setst((select id from t_ids where k = 'res'), 'Chegou') like '22023%', 'Reservado não chega sem confirmar');
select pg_temp.expect(pg_temp.setst((select id from t_ids where k = 'cancel'), 'Chegou') = 'OK', 'chega');
select pg_temp.expect(pg_temp.setst((select id from t_ids where k = 'cancel'), 'Cancelado') = 'OK', 'quem chegou ainda pode ser cancelado');
reset role;
select set_config('request.jwt.claims', '', true);

-- ═══ B. Trilha: cada mudança no histórico, com quem mudou, e na auditoria ═══
-- (Tudo roda numa transação, então created_at é igual nas linhas: confere o conjunto, não a ordem.)
select pg_temp.expect((select count(*) = 5 and array_agg(status order by status) = array['Agendado', 'Chegou', 'Concluído', 'Confirmado', 'Iniciado']::text[]
  from public.appointment_status_history where appointment_id = (select id from t_ids where k = 'flow')),
  'histórico com as cinco etapas, sem Chegou duplicado');
select pg_temp.expect((select changed_by = '00000000-0000-0000-0000-000000001291' from public.appointment_status_history
  where appointment_id = (select id from t_ids where k = 'flow') and status = 'Chegou'), 'quem marcou a chegada fica registrado');
select pg_temp.expect((select changed_by = '00000000-0000-0000-0000-000000001290' from public.appointment_status_history
  where appointment_id = (select id from t_ids where k = 'flow') and status = 'Agendado'), 'quem criou fica no primeiro registro');
select pg_temp.expect((select count(*) = 1 from public.audit_logs where operation = 'STATUS_CHANGE' and record_id = (select id from t_ids where k = 'flow')
  and new_data ->> 'status' = 'Chegou' and old_data ->> 'status' = 'Confirmado'), 'auditoria da chegada');

-- ═══ C. Permissão ═══
select pg_temp.login('00000000-0000-0000-0000-000000001292');
select pg_temp.expect(pg_temp.setst((select id from t_ids where k = 'prof'), 'Chegou') like '42501%', 'profissional sem agenda.manage não marca chegada');
reset role;
select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select status = 'Agendado' from public.appointments where id = (select id from t_ids where k = 'prof')), 'e nada mudou');

-- ═══ D. Trava da Ficha Cliente vale ao chegar ═══
select pg_temp.login('00000000-0000-0000-0000-000000001290');
select pg_temp.expect(pg_temp.setst((select id from t_ids where k = 'ficha'), 'Chegou') like 'P0001%ainda nao foi assinada pelo cliente%',
  'ficha pendente: não marca chegada');
select pg_temp.expect(pg_temp.err($q$update public.appointments set status = 'Chegou' where id = (select id from t_ids where k = 'ficha')$q$) like 'P0001%ainda nao foi assinada%',
  'UPDATE direto para Chegou também é barrado');
select pg_temp.expect(pg_temp.setst((select id from t_ids where k = 'ficha'), 'Iniciado') like 'P0001%ainda nao foi assinada%', 'e iniciar continua barrado');
reset role;
select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select status = 'Agendado' from public.appointments where id = (select id from t_ids where k = 'ficha')), 'a chegada barrada não muda o status');
-- Com a ficha assinada (pelo link público, como a cliente faz), chega.
create temp table t_tok (tok text) on commit drop;
grant all on t_tok to anon, service_role;
-- 20261114100000: o banco guarda só o hash; o teste troca por um link conhecido. O link passa pelo servidor
-- (chave de serviço): "anon" aqui é a chamada do servidor.
insert into t_tok values ('tok137aaaaaaaaaaaaaaaaaaaaaaaaaa');
update public.anamneses set public_token = 'tok137aaaaaaaaaaaaaaaaaaaaaaaaaa' where appointment_id = (select id from t_ids where k = 'ficha');
create function pg_temp.anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
  perform set_config('role', 'service_role', true);
end $$;
grant execute on function pg_temp.anon(), pg_temp.expect(boolean, text) to anon, service_role;
select pg_temp.anon();
select pg_temp.expect((select public.public_anamnese_sign(tok, repeat('1', 64), '{"q1":"Sem alergias","__canal":"link","__termo_principal":"aceito"}'::jsonb, 'Cliente Chegou', 'data:image/png;base64,' || repeat('A', 60), true, 'Mozilla/5.0', null) ->> 'ok' from t_tok) = 'true', 'cliente assina a ficha pelo link');
reset role;
select set_config('request.jwt.claims', '', true);
select pg_temp.login('00000000-0000-0000-0000-000000001290');
select pg_temp.expect(pg_temp.setst((select id from t_ids where k = 'ficha'), 'Chegou') = 'OK', 'ficha assinada: marca a chegada');

-- ═══ E. Quem já chegou ainda pode reagendar; quem foi cancelado não ═══
select pg_temp.expect(pg_temp.err(format('select public.reschedule_appointment_atomic(%L, %L, %L)', '00000000-0000-0000-0000-00000000129a',
  (select id from t_ids where k = 'conf'), '2035-02-03 14:00+00'::timestamptz)) = 'OK', 'Chegou reagenda');
select pg_temp.expect(pg_temp.err(format('select public.reschedule_appointment_atomic(%L, %L, %L)', '00000000-0000-0000-0000-00000000129a',
  (select id from t_ids where k = 'cancel'), '2035-02-05 14:00+00'::timestamptz)) like 'P0001%', 'Cancelado não reagenda');

-- ═══ F. Agendamento novo não nasce como Chegou; valor inválido continua barrado ═══
select pg_temp.expect(pg_temp.err($q$select pg_temp.mk('2035-03-01 09:00+00', '00000000-0000-0000-0000-000000001296', 'Chegou')$q$) <> 'OK', 'não cria agendamento já com Chegou');
reset role;
select set_config('request.jwt.claims', '', true);
select pg_temp.expect(pg_temp.err($q$update public.appointments set status = 'Chegando' where id = (select id from t_ids where k = 'conf')$q$) like '23514%', 'valor fora da lista é recusado');

-- ═══ G. A edição de série alcança quem já chegou ═══
select pg_temp.expect((select pg_get_functiondef(p.oid) like '%''Chegou'', ''Iniciado''%'
  from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'update_recurrence_series_atomic'), 'update_recurrence_series_atomic inclui Chegou');

rollback;
\o
\echo 'status Chegou: ok'
