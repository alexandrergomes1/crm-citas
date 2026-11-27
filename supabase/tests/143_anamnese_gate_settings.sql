-- Travas da anamnese configuráveis por estúdio: padrão ligado, desligar iniciar/cobrar separadamente,
-- permissão de ajustes, auditoria e isolamento entre estúdios. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000d10', 'dona@gate.local'),
  ('00000000-0000-0000-0000-000000000d11', 'recep@gate.local'),
  ('00000000-0000-0000-0000-000000000d12', 'donab@gate.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-000000000d1a', 'gate-a', 'Estúdio Trava A'),
  ('00000000-0000-0000-0000-000000000d1b', 'gate-b', 'Estúdio Trava B');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000000d10', '00000000-0000-0000-0000-000000000d1a', 'owner'),
  ('00000000-0000-0000-0000-000000000d11', '00000000-0000-0000-0000-000000000d1a', 'receptionist'),
  ('00000000-0000-0000-0000-000000000d12', '00000000-0000-0000-0000-000000000d1b', 'owner');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-000000000d13', '00000000-0000-0000-0000-000000000d1a', 'Rosa Lima');
insert into public.staff_members (id, org_id, name) values
  ('00000000-0000-0000-0000-000000000d14', '00000000-0000-0000-0000-000000000d1a', 'Karenn');
insert into public.anamnese_templates (id, org_id, title, questions, professional_form) values
  ('00000000-0000-0000-0000-000000000d15', '00000000-0000-0000-0000-000000000d1a', 'Ficha facial',
   '[{"id":"q1","label":"Alergias?","type":"text"}]'::jsonb, null);
insert into public.services (id, org_id, name, price, duration_minutes, requires_anamnese, anamnese_template_id) values
  ('00000000-0000-0000-0000-000000000d16', '00000000-0000-0000-0000-000000000d1a', 'Limpeza facial', 80, 60, true, '00000000-0000-0000-0000-000000000d15');

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
create temp table t_ids (k text primary key, id uuid) on commit drop;
grant all on t_ids to authenticated;

select pg_temp.login('00000000-0000-0000-0000-000000000d10');
insert into t_ids values
  ('s1', public.create_appointment_atomic('00000000-0000-0000-0000-000000000d1a', '00000000-0000-0000-0000-000000000d13',
    '00000000-0000-0000-0000-000000000d14', '2031-04-03 10:00+00', '2031-04-03 11:00+00', 60, 'Agendado', 'MANUAL', null, null, 80,
    '[{"service_id":"00000000-0000-0000-0000-000000000d16","service_name":"Limpeza facial","price":80}]'::jsonb, false));

-- 1. Padrão: as duas travas ligadas ──────────────────────────────────────────────────────────
select pg_temp.expect(public.anamnese_gate_enabled('00000000-0000-0000-0000-000000000d1a', 'start')
  and public.anamnese_gate_enabled('00000000-0000-0000-0000-000000000d1a', 'checkout'), 'padrão: iniciar e cobrar travados');
select pg_temp.expect((select string_agg(issue_code, ',') from public.get_appointment_anamnese_gate(
    '00000000-0000-0000-0000-000000000d1a', (select id from t_ids where k = 's1'), 'start')) = 'CLIENT_PENDING', 'gate de início ativo');

-- 2. Desligar só o início ────────────────────────────────────────────────────────────────────
select public.set_anamnese_gate('00000000-0000-0000-0000-000000000d1a', false, true);
select pg_temp.expect(not public.anamnese_gate_enabled('00000000-0000-0000-0000-000000000d1a', 'start'), 'início destravado');
select pg_temp.expect(public.anamnese_gate_enabled('00000000-0000-0000-0000-000000000d1a', 'checkout'), 'cobrança continua travada');
select pg_temp.expect((select count(*) from public.get_appointment_anamnese_gate(
    '00000000-0000-0000-0000-000000000d1a', (select id from t_ids where k = 's1'), 'start')) = 0, 'sem pendência de início quando destravado');
select pg_temp.expect((select string_agg(issue_code, ',') from public.get_appointment_anamnese_gate(
    '00000000-0000-0000-0000-000000000d1a', (select id from t_ids where k = 's1'), 'checkout')) = 'CLIENT_PENDING', 'cobrança segue apontando pendência');
select public.set_appointment_status_atomic('00000000-0000-0000-0000-000000000d1a', (select id from t_ids where k = 's1'), 'Confirmado');
select public.set_appointment_status_atomic('00000000-0000-0000-0000-000000000d1a', (select id from t_ids where k = 's1'), 'Iniciado');
select pg_temp.expect((select status from public.appointments where id = (select id from t_ids where k = 's1')) = 'Iniciado',
  'com a trava de início desligada o atendimento inicia sem ficha');

-- 3. A validade/modo estúdio não apagam as travas ────────────────────────────────────────────
select public.set_anamnese_settings('00000000-0000-0000-0000-000000000d1a', 15, false);
select pg_temp.expect(not public.anamnese_gate_enabled('00000000-0000-0000-0000-000000000d1a', 'start'), 'salvar validade mantém trava de início desligada');
select pg_temp.expect((select settings -> 'anamnese' ->> 'link_days' from public.organizations where id = '00000000-0000-0000-0000-000000000d1a') = '15',
  'validade gravada');

-- 4. Permissão, valor inválido e etapa inválida ──────────────────────────────────────────────
select pg_temp.expect(pg_temp.state_of($q$select public.set_anamnese_gate('00000000-0000-0000-0000-000000000d1a', null, true)$q$) = '22023', 'valor nulo recusado');
select pg_temp.expect(pg_temp.state_of($q$select * from public.get_appointment_anamnese_gate('00000000-0000-0000-0000-000000000d1a', gen_random_uuid(), 'xx')$q$) = '22023', 'etapa inválida recusada');
select pg_temp.login('00000000-0000-0000-0000-000000000d11');
select pg_temp.expect(pg_temp.state_of($q$select public.set_anamnese_gate('00000000-0000-0000-0000-000000000d1a', true, true)$q$) = '42501', 'recepção não altera as travas');
select pg_temp.login('00000000-0000-0000-0000-000000000d12');
select pg_temp.expect(pg_temp.state_of($q$select public.set_anamnese_gate('00000000-0000-0000-0000-000000000d1a', true, true)$q$) = '42501', 'outro estúdio não altera');
-- Estúdio B não é afetado e a consulta cruzada continua negada.
select pg_temp.expect(public.anamnese_gate_enabled('00000000-0000-0000-0000-000000000d1b', 'start'), 'estúdio B segue com o padrão');
select pg_temp.expect(pg_temp.state_of($q$select count(*) from public.get_appointment_anamnese_gate('00000000-0000-0000-0000-000000000d1a', gen_random_uuid(), 'start')$q$) = '42501',
  'travado desligado não vaza o agendamento de outro estúdio (a validação de papel continua)');

-- 5. Auditoria ────────────────────────────────────────────────────────────────────────────────
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select count(*) from public.audit_logs where org_id = '00000000-0000-0000-0000-000000000d1a' and operation = 'ANAMNESE_GATE_SET') = 1,
  'troca das travas auditada');

rollback;
\o
\echo 'travas da anamnese configuráveis: ok'
