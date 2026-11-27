-- Agenda: reschedule_appointment_atomic, set_appointment_status_atomic (matriz completa de
-- transições), cancel_recurrence_series_atomic e o forçar conflito (p_force_override).
-- NOTA: reschedule_appointment_atomic NÃO tem p_force_override (sempre checa conflito);
-- o override existe em create_appointment_atomic / update_appointment_atomic e é testado ali.
-- Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000870', 'dona@agenda.local'),
  ('00000000-0000-0000-0000-000000000871', 'recep@agenda.local'),
  ('00000000-0000-0000-0000-000000000872', 'prof@agenda.local'),
  ('00000000-0000-0000-0000-000000000873', 'visu@agenda.local'),
  ('00000000-0000-0000-0000-000000000874', 'donab@agenda.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-00000000087a', 'agenda-a', 'Agenda A'),
  ('00000000-0000-0000-0000-00000000087b', 'agenda-b', 'Agenda B');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000000870', '00000000-0000-0000-0000-00000000087a', 'owner'),
  ('00000000-0000-0000-0000-000000000871', '00000000-0000-0000-0000-00000000087a', 'receptionist'),
  ('00000000-0000-0000-0000-000000000872', '00000000-0000-0000-0000-00000000087a', 'professional'),
  ('00000000-0000-0000-0000-000000000873', '00000000-0000-0000-0000-00000000087a', 'viewer'),
  ('00000000-0000-0000-0000-000000000874', '00000000-0000-0000-0000-00000000087b', 'owner');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-000000000875', '00000000-0000-0000-0000-00000000087a', 'Pilar Gómez'),
  ('00000000-0000-0000-0000-000000000876', '00000000-0000-0000-0000-00000000087b', 'Cliente da B');
insert into public.staff_members (id, org_id, name) values
  ('00000000-0000-0000-0000-000000000877', '00000000-0000-0000-0000-00000000087a', 'Karenn'),
  ('00000000-0000-0000-0000-000000000878', '00000000-0000-0000-0000-00000000087a', 'Lucía'),
  ('00000000-0000-0000-0000-00000000087d', '00000000-0000-0000-0000-00000000087b', 'Equipe B');
insert into public.services (id, org_id, name, price, duration_minutes) values
  ('00000000-0000-0000-0000-000000000879', '00000000-0000-0000-0000-00000000087a', 'Drenagem', 60, 60);
insert into public.time_block_types (id, org_id, name) values
  ('00000000-0000-0000-0000-00000000087c', '00000000-0000-0000-0000-00000000087a', 'Bloqueio de teste');
-- Agendamento e série da org B, criados direto, para os testes de isolamento.
insert into public.appointments (id, org_id, client_id, client_name, start_at, end_at, duration_minutes, status, recurrence_id, recurrence_index) values
  ('00000000-0000-0000-0000-00000000087e', '00000000-0000-0000-0000-00000000087b', '00000000-0000-0000-0000-000000000876',
   'Cliente da B', '2031-06-02 10:00+00', '2031-06-02 11:00+00', 60, 'Agendado', '00000000-0000-0000-0000-00000000087f', 1);

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
-- Atendimento da org A: início, duração em minutos, profissional (null = sem profissional) e status inicial.
create function pg_temp.mk(p_start text, p_min int, p_staff uuid default '00000000-0000-0000-0000-000000000877', p_status text default 'Agendado')
returns uuid language sql as $$
  select public.create_appointment_atomic('00000000-0000-0000-0000-00000000087a', '00000000-0000-0000-0000-000000000875', p_staff,
    p_start::timestamptz, p_start::timestamptz + make_interval(mins => p_min), p_min, p_status, 'MANUAL', null, null, 60,
    '[{"service_id":"00000000-0000-0000-0000-000000000879","service_name":"Drenagem","price":60}]'::jsonb, false)
$$;
create function pg_temp.resched(p_id uuid, p_start text, p_org uuid default '00000000-0000-0000-0000-00000000087a') returns text language sql as $$
  select pg_temp.err(format('select public.reschedule_appointment_atomic(%L, %L, %L)', p_org, p_id, p_start::timestamptz))
$$;
create function pg_temp.setst(p_id uuid, p_status text, p_org uuid default '00000000-0000-0000-0000-00000000087a') returns text language sql as $$
  select pg_temp.err(format('select public.set_appointment_status_atomic(%L, %L, %L)', p_org, p_id, p_status))
$$;
grant execute on function pg_temp.expect(boolean, text), pg_temp.err(text), pg_temp.login(uuid),
  pg_temp.mk(text, int, uuid, text), pg_temp.resched(uuid, text, uuid), pg_temp.setst(uuid, text, uuid) to authenticated;
create temp table t_ids (k text primary key, id uuid) on commit drop;
grant all on t_ids to authenticated;

-- ═══ A. reschedule_appointment_atomic ═══
select pg_temp.login('00000000-0000-0000-0000-000000000870');
insert into t_ids values
  ('x', pg_temp.mk('2031-06-02 10:00+00', 90)),               -- 10:00-11:30, vai ser movido
  ('y', pg_temp.mk('2031-06-02 13:00+00', 60)),               -- 13:00-14:00, mesma profissional
  ('z', pg_temp.mk('2031-06-03 10:00+00', 60, '00000000-0000-0000-0000-000000000878')),  -- outra profissional
  ('w', pg_temp.mk('2031-06-04 10:00+00', 60)),               -- será cancelado
  ('w2', pg_temp.mk('2031-06-04 12:00+00', 60));              -- terá Ausência
select pg_temp.setst((select id from t_ids where k = 'w'), 'Cancelado');
select pg_temp.setst((select id from t_ids where k = 'w2'), 'Ausência');

-- Conflito de horário
select pg_temp.expect(pg_temp.resched((select id from t_ids where k = 'x'), '2031-06-02 12:00+00') like '23P01%ja possui um atendimento%',
  'conflito: 12:00-13:30 invade o atendimento das 13:00');
select pg_temp.expect(pg_temp.resched((select id from t_ids where k = 'x'), '2031-06-02 12:30+00') like '23P01%',
  'conflito: 12:30-14:00 cobre o atendimento inteiro das 13:00');
select pg_temp.expect(pg_temp.resched((select id from t_ids where k = 'x'), '2031-06-02 13:30+00') like '23P01%',
  'conflito: começa no meio do atendimento das 13:00');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select start_at = '2031-06-02 10:00+00' and end_at = '2031-06-02 11:30+00' from public.appointments
  where id = (select id from t_ids where k = 'x')), 'conflito recusado não mexe no horário');
select pg_temp.expect(not exists (select 1 from public.audit_logs where operation = 'APPOINTMENT_RESCHEDULED'),
  'conflito recusado não gera auditoria de reagendamento');

-- Encostar não é conflito; a duração de 90 minutos se mantém.
select pg_temp.login('00000000-0000-0000-0000-000000000870');
select pg_temp.expect(pg_temp.resched((select id from t_ids where k = 'x'), '2031-06-02 14:00+00') = 'OK', 'começa quando o outro termina: ok');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select start_at = '2031-06-02 14:00+00' and end_at = '2031-06-02 15:30+00' and duration_minutes = 90
  from public.appointments where id = (select id from t_ids where k = 'x')), 'novo horário 14:00-15:30 e duração mantida em 90');
select pg_temp.expect((select (old_data ->> 'start_at')::timestamptz = '2031-06-02 10:00+00' and (new_data ->> 'start_at')::timestamptz = '2031-06-02 14:00+00'
    and user_id = '00000000-0000-0000-0000-000000000870'
  from public.audit_logs where operation = 'APPOINTMENT_RESCHEDULED' and record_id = (select id from t_ids where k = 'x')),
  'auditoria guarda horário antigo e novo');
select pg_temp.expect((select start_at = '2031-06-02 13:00+00' and end_at = '2031-06-02 14:00+00' from public.appointments
  where id = (select id from t_ids where k = 'y')), 'o outro atendimento não mudou');

select pg_temp.login('00000000-0000-0000-0000-000000000870');
select pg_temp.expect(pg_temp.resched((select id from t_ids where k = 'x'), '2031-06-02 11:30+00') = 'OK', 'termina quando o outro começa (11:30-13:00): ok');
select pg_temp.expect(pg_temp.resched((select id from t_ids where k = 'x'), '2031-06-02 11:30+00') = 'OK', 'mover para o próprio horário não conflita consigo');
select pg_temp.expect(pg_temp.resched((select id from t_ids where k = 'x'), '2031-06-02 11:00+00') = 'OK', 'deslocar 30 minutos sobre o próprio horário antigo: ok');
-- Outra profissional, atendimento cancelado e com ausência não bloqueiam.
select pg_temp.expect(pg_temp.resched((select id from t_ids where k = 'x'), '2031-06-03 10:00+00') = 'OK',
  'mesmo horário de OUTRA profissional não conflita');
select pg_temp.expect(pg_temp.resched((select id from t_ids where k = 'x'), '2031-06-04 10:00+00') = 'OK', 'horário de atendimento Cancelado está livre');
select pg_temp.expect(pg_temp.resched((select id from t_ids where k = 'x'), '2031-06-04 12:00+00') = 'OK', 'horário de atendimento com Ausência está livre');
select pg_temp.expect(pg_temp.resched((select id from t_ids where k = 'x'), '2031-06-04 11:30+00') = 'OK',
  'entre um Cancelado (10:00) e uma Ausência (12:00) cabe sem conflito');

-- Bloqueio de agenda (da profissional e do estúdio inteiro)
reset role; select set_config('request.jwt.claims', '', true);
insert into public.time_blocks (org_id, staff_id, start_at, end_at, time_block_type_id) values
  ('00000000-0000-0000-0000-00000000087a', '00000000-0000-0000-0000-000000000877', '2031-06-05 09:00+00', '2031-06-05 12:00+00', '00000000-0000-0000-0000-00000000087c'),
  ('00000000-0000-0000-0000-00000000087a', null,                                   '2031-06-06 09:00+00', '2031-06-06 12:00+00', '00000000-0000-0000-0000-00000000087c'),
  ('00000000-0000-0000-0000-00000000087a', '00000000-0000-0000-0000-000000000878', '2031-06-07 09:00+00', '2031-06-07 12:00+00', '00000000-0000-0000-0000-00000000087c');
select pg_temp.login('00000000-0000-0000-0000-000000000870');
select pg_temp.expect(pg_temp.resched((select id from t_ids where k = 'x'), '2031-06-05 10:00+00') like '23P01%bloqueio%', 'bloqueio da profissional barra');
select pg_temp.expect(pg_temp.resched((select id from t_ids where k = 'x'), '2031-06-06 10:00+00') like '23P01%bloqueio%', 'bloqueio do estúdio inteiro barra');
select pg_temp.expect(pg_temp.resched((select id from t_ids where k = 'x'), '2031-06-07 10:00+00') = 'OK', 'bloqueio de OUTRA profissional não barra');
select pg_temp.expect(pg_temp.resched((select id from t_ids where k = 'x'), '2031-06-05 12:00+00') = 'OK', 'depois do fim do bloqueio: livre');

-- Estados que permitem ou não mover (atendimentos sem profissional, para não colidir)
create temp table t_rs (st text primary key, ok boolean, id uuid) on commit drop;
grant all on t_rs to authenticated;
insert into t_rs values ('Reservado', true, null), ('Agendado', true, null), ('Confirmado', true, null), ('Iniciado', true, null),
  ('Concluído', false, null), ('Pago Parcial', false, null), ('Pago', false, null), ('Cancelado', false, null), ('Ausência', false, null);
do $$
declare r record; v_id uuid; v_res text; v_start timestamptz;
begin
  for r in select * from t_rs order by st loop
    v_id := pg_temp.mk('2031-07-01 10:00+00', 60, null, case when r.st = 'Reservado' then 'Reservado' else 'Agendado' end);
    -- Direto no status (como a dona): a matriz de transições é testada na seção B.
    update public.appointments set status = r.st where id = v_id;
    update t_rs set id = v_id where st = r.st;
    v_res := pg_temp.resched(v_id, '2031-07-02 15:00+00');
    select start_at into v_start from public.appointments where id = v_id;
    if r.ok then
      perform pg_temp.expect(v_res = 'OK' and v_start = '2031-07-02 15:00+00', 'reagendar atendimento ' || r.st || ' funciona');
    else
      perform pg_temp.expect(v_res like 'P0001%nao pode ser reagendado%' and v_start = '2031-07-01 10:00+00',
        'reagendar atendimento ' || r.st || ' é recusado e não mexe no horário');
    end if;
  end loop;
end $$;

-- Papéis e estúdio
select pg_temp.expect(pg_temp.resched((select id from t_ids where k = 'x'), '2031-06-10 10:00+00') = 'OK', 'dona reagenda');
select pg_temp.login('00000000-0000-0000-0000-000000000871');
select pg_temp.expect(pg_temp.resched((select id from t_ids where k = 'x'), '2031-06-11 10:00+00') = 'OK', 'recepção reagenda');
select pg_temp.login('00000000-0000-0000-0000-000000000873');
select pg_temp.expect(pg_temp.resched((select id from t_ids where k = 'x'), '2031-06-12 10:00+00') like '42501%', 'visualizadora não reagenda');
select pg_temp.login('00000000-0000-0000-0000-000000000874');
select pg_temp.expect(pg_temp.resched((select id from t_ids where k = 'x'), '2031-06-12 10:00+00') like '42501%', 'dona de outro estúdio não reagenda (org A)');
select pg_temp.expect(pg_temp.resched((select id from t_ids where k = 'x'), '2031-06-12 10:00+00', '00000000-0000-0000-0000-00000000087b') like 'P0002%',
  'passando a própria org, o atendimento da A não existe');
select pg_temp.login('00000000-0000-0000-0000-000000000870');
select pg_temp.expect(pg_temp.resched('00000000-0000-0000-0000-00000000087e', '2031-06-12 10:00+00') like 'P0002%',
  'dona da A não move atendimento da B');
select pg_temp.expect(pg_temp.resched(gen_random_uuid(), '2031-06-12 10:00+00') like 'P0002%', 'atendimento inexistente');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select start_at = '2031-06-02 10:00+00' from public.appointments where id = '00000000-0000-0000-0000-00000000087e'),
  'atendimento da B intacto');
select pg_temp.expect((select start_at = '2031-06-11 10:00+00' from public.appointments where id = (select id from t_ids where k = 'x')),
  'x terminou onde a recepção o deixou');

-- ═══ B. set_appointment_status_atomic: matriz completa ═══
create temp table t_allowed (cur text, nxt text, primary key (cur, nxt)) on commit drop;
grant select on t_allowed to authenticated;
-- Espelha agenda_status_transition_allowed() e allowedTransitions de src/domain/appointment-status.ts.
insert into t_allowed values
  ('Reservado', 'Confirmado'), ('Reservado', 'Ausência'), ('Reservado', 'Cancelado'),
  ('Agendado', 'Confirmado'), ('Agendado', 'Iniciado'), ('Agendado', 'Ausência'), ('Agendado', 'Cancelado'),
  ('Confirmado', 'Iniciado'), ('Confirmado', 'Ausência'), ('Confirmado', 'Cancelado'),
  ('Iniciado', 'Concluído'), ('Iniciado', 'Cancelado'),
  ('Concluído', 'Pago Parcial'), ('Concluído', 'Pago'),
  ('Pago Parcial', 'Pago');
select pg_temp.login('00000000-0000-0000-0000-000000000870');
do $$
declare
  v_all text[] := array['Reservado','Agendado','Confirmado','Iniciado','Concluído','Pago Parcial','Pago','Ausência','Cancelado'];
  v_cur text; v_nxt text; v_id uuid; v_res text; v_status text; v_allowed int := 0; v_denied int := 0; v_same int := 0;
begin
  v_id := pg_temp.mk('2031-08-01 10:00+00', 60, null);
  foreach v_cur in array v_all loop
    foreach v_nxt in array v_all loop
      update public.appointments set status = v_cur where id = v_id;
      v_res := pg_temp.setst(v_id, v_nxt);
      select status into v_status from public.appointments where id = v_id;
      if v_cur = v_nxt then
        perform pg_temp.expect(v_res = 'OK' and v_status = v_cur, 'mesmo status ' || v_cur || ' é aceito e não muda nada');
        v_same := v_same + 1;
      elsif exists (select 1 from t_allowed where cur = v_cur and nxt = v_nxt) then
        perform pg_temp.expect(v_res = 'OK' and v_status = v_nxt, 'transição ' || v_cur || ' → ' || v_nxt || ' deve passar');
        v_allowed := v_allowed + 1;
      else
        perform pg_temp.expect(v_res like '22023%Transicao de status nao permitida%' and v_status = v_cur,
          'transição ' || v_cur || ' → ' || v_nxt || ' deve falhar sem mudar o status (veio: ' || v_res || ')');
        v_denied := v_denied + 1;
      end if;
    end loop;
  end loop;
  perform pg_temp.expect(v_allowed = 15 and v_same = 9 and v_denied = 57, 'matriz percorrida inteira: 15 permitidas, 9 iguais, 57 barradas');
end $$;

-- Os exemplos clássicos, direto
do $$
declare v_id uuid := pg_temp.mk('2031-08-02 10:00+00', 60, null);
begin
  update public.appointments set status = 'Pago' where id = v_id;
  perform pg_temp.expect(pg_temp.setst(v_id, 'Agendado') like '22023%Transicao%', 'Pago → Agendado falha');
  update public.appointments set status = 'Cancelado' where id = v_id;
  perform pg_temp.expect(pg_temp.setst(v_id, 'Iniciado') like '22023%Transicao%', 'Cancelado → Iniciado falha');
  perform pg_temp.expect(pg_temp.setst(v_id, 'Agendado') like '22023%Transicao%', 'Cancelado → Agendado falha');
  update public.appointments set status = 'Ausência' where id = v_id;
  perform pg_temp.expect(pg_temp.setst(v_id, 'Confirmado') like '22023%Transicao%', 'Ausência → Confirmado falha');
  update public.appointments set status = 'Concluído' where id = v_id;
  perform pg_temp.expect(pg_temp.setst(v_id, 'Cancelado') like '22023%Transicao%', 'Concluído → Cancelado falha (depois de concluir só cobra)');
  perform pg_temp.expect(pg_temp.setst(v_id, 'Iniciado') like '22023%Transicao%', 'Concluído → Iniciado falha (não volta)');
  perform pg_temp.expect(pg_temp.setst(v_id, 'Inventado') like '22023%Status de agendamento invalido%', 'status desconhecido falha');
  perform pg_temp.expect(pg_temp.setst(v_id, 'Concluido') like '22023%Status de agendamento invalido%', 'status sem acento não é aceito');
  perform pg_temp.expect(pg_temp.err(format('select public.set_appointment_status_atomic(%L, %L, null)', '00000000-0000-0000-0000-00000000087a', v_id)) <> 'OK',
    'status nulo falha');
  perform pg_temp.expect((select status = 'Concluído' from public.appointments where id = v_id), 'tentativas inválidas não mudaram o atendimento');
end $$;

-- Histórico e auditoria: só mudança real conta.
do $$
declare v_id uuid := pg_temp.mk('2031-08-03 10:00+00', 60, null); v_h int; v_a int;
begin
  perform public.set_appointment_status_atomic('00000000-0000-0000-0000-00000000087a', v_id, 'Confirmado');
  perform public.set_appointment_status_atomic('00000000-0000-0000-0000-00000000087a', v_id, 'Confirmado');
  select count(*) into v_h from public.appointment_status_history where appointment_id = v_id and status = 'Confirmado';
  select count(*) into v_a from public.audit_logs where record_id = v_id and operation = 'STATUS_CHANGE';
  perform pg_temp.expect(v_h = 1 and v_a = 1, 'repetir o mesmo status não duplica histórico nem auditoria');
  perform pg_temp.expect((select old_data ->> 'status' = 'Agendado' and new_data ->> 'status' = 'Confirmado'
    from public.audit_logs where record_id = v_id and operation = 'STATUS_CHANGE'), 'auditoria guarda status antigo e novo');
  perform pg_temp.expect((select changed_by = '00000000-0000-0000-0000-000000000870' from public.appointment_status_history
    where appointment_id = v_id and status = 'Confirmado'), 'histórico guarda quem mudou');
end $$;

-- Papéis e estúdio
select pg_temp.expect(pg_temp.setst((select id from t_ids where k = 'y'), 'Confirmado') = 'OK', 'dona muda status');
select pg_temp.login('00000000-0000-0000-0000-000000000873');
select pg_temp.expect(pg_temp.setst((select id from t_ids where k = 'y'), 'Iniciado') like '42501%', 'visualizadora não muda status');
select pg_temp.login('00000000-0000-0000-0000-000000000874');
select pg_temp.expect(pg_temp.setst((select id from t_ids where k = 'y'), 'Iniciado') like '42501%', 'dona de outro estúdio não muda status');
select pg_temp.expect(pg_temp.setst((select id from t_ids where k = 'y'), 'Iniciado', '00000000-0000-0000-0000-00000000087b') like 'P0002%',
  'atendimento da A não é achado pela org B');
select pg_temp.login('00000000-0000-0000-0000-000000000870');
select pg_temp.expect(pg_temp.setst('00000000-0000-0000-0000-00000000087e', 'Confirmado') like 'P0002%', 'atendimento da B não é achado pela org A');
select pg_temp.expect(pg_temp.setst(gen_random_uuid(), 'Confirmado') like 'P0002%', 'atendimento inexistente');
reset role; select set_config('request.jwt.claims', '', true);

-- ═══ C. Forçar conflito (create/update_appointment_atomic) ═══
select pg_temp.login('00000000-0000-0000-0000-000000000870');
insert into t_ids values ('q', pg_temp.mk('2031-09-01 10:00+00', 60));
select pg_temp.expect(pg_temp.err($q$select pg_temp.mk('2031-09-01 10:30+00', 60)$q$) like '23P01%', 'criar em cima de outro atendimento: conflito');
select pg_temp.expect(pg_temp.err($q$select public.create_appointment_atomic('00000000-0000-0000-0000-00000000087a', '00000000-0000-0000-0000-000000000875',
    '00000000-0000-0000-0000-000000000877', '2031-09-01 10:30+00', '2031-09-01 11:30+00', 60, 'Agendado', 'MANUAL', null, null, 60,
    '[]'::jsonb, false)$q$) like '23P01%', 'p_force_override = false não ignora o conflito');
select pg_temp.expect(pg_temp.err($q$select public.create_appointment_atomic('00000000-0000-0000-0000-00000000087a', '00000000-0000-0000-0000-000000000875',
    '00000000-0000-0000-0000-000000000877', '2031-09-01 11:00+00', '2031-09-01 10:00+00', 60, 'Agendado', 'MANUAL', null, null, 60,
    '[]'::jsonb, true)$q$) like '22023%', 'fim antes do início é recusado até com override');
insert into t_ids values ('forced', public.create_appointment_atomic('00000000-0000-0000-0000-00000000087a', '00000000-0000-0000-0000-000000000875',
    '00000000-0000-0000-0000-000000000877', '2031-09-01 10:30+00', '2031-09-01 11:30+00', 60, 'Agendado', 'MANUAL', null, 'obs',
    60, '[]'::jsonb, true));
select pg_temp.expect((select internal_notes like '[CONFLITO FORCADO - owner - %' and internal_notes like '%obs' from public.appointments
  where id = (select id from t_ids where k = 'forced')), 'override da dona grava a marca [CONFLITO FORCADO] nas notas internas');
select pg_temp.expect((select (new_data ->> 'force_override')::boolean from public.audit_logs
  where record_id = (select id from t_ids where k = 'forced') and operation = 'APPOINTMENT_CREATED'), 'auditoria registra force_override');
select pg_temp.login('00000000-0000-0000-0000-000000000871');
select pg_temp.expect(pg_temp.err($q$select public.create_appointment_atomic('00000000-0000-0000-0000-00000000087a', '00000000-0000-0000-0000-000000000875',
    '00000000-0000-0000-0000-000000000877', '2031-09-01 10:30+00', '2031-09-01 11:30+00', 60, 'Agendado', 'MANUAL', null, null, 60,
    '[]'::jsonb, true)$q$) like '42501%Somente gestores%', 'recepção não força conflito ao criar');

-- update_appointment_atomic
select pg_temp.login('00000000-0000-0000-0000-000000000870');
insert into t_ids values ('k', pg_temp.mk('2031-09-02 10:00+00', 60)), ('l', pg_temp.mk('2031-09-02 12:00+00', 60));
select pg_temp.expect(pg_temp.err($q$select public.update_appointment_atomic('00000000-0000-0000-0000-00000000087a', (select id from t_ids where k = 'k'),
    '00000000-0000-0000-0000-000000000875', '00000000-0000-0000-0000-000000000877', '2031-09-02 12:00+00', '2031-09-02 13:00+00', 60,
    'Agendado', 'MANUAL', null, null, 60, '[]'::jsonb, false)$q$) like '23P01%', 'editar para cima de outro atendimento: conflito');
select pg_temp.login('00000000-0000-0000-0000-000000000871');
select pg_temp.expect(pg_temp.err($q$select public.update_appointment_atomic('00000000-0000-0000-0000-00000000087a', (select id from t_ids where k = 'k'),
    '00000000-0000-0000-0000-000000000875', '00000000-0000-0000-0000-000000000877', '2031-09-02 12:00+00', '2031-09-02 13:00+00', 60,
    'Agendado', 'MANUAL', null, null, 60, '[]'::jsonb, true)$q$) like '42501%Somente gestores%', 'recepção não força conflito ao editar');
select pg_temp.login('00000000-0000-0000-0000-000000000870');
select pg_temp.expect(pg_temp.err($q$select public.update_appointment_atomic('00000000-0000-0000-0000-00000000087a', (select id from t_ids where k = 'k'),
    '00000000-0000-0000-0000-000000000875', '00000000-0000-0000-0000-000000000877', '2031-09-02 12:00+00', '2031-09-02 13:00+00', 60,
    'Agendado', 'MANUAL', null, null, 60, '[]'::jsonb, true)$q$) = 'OK', 'dona força conflito ao editar');
select pg_temp.expect((select internal_notes like '[CONFLITO FORCADO%' from public.appointments where id = (select id from t_ids where k = 'k')),
  'edição forçada fica marcada');
-- Atendimento em estado terminal não é editado.
update public.appointments set status = 'Pago' where id = (select id from t_ids where k = 'l');
select pg_temp.expect(pg_temp.err($q$select public.update_appointment_atomic('00000000-0000-0000-0000-00000000087a', (select id from t_ids where k = 'l'),
    '00000000-0000-0000-0000-000000000875', '00000000-0000-0000-0000-000000000877', '2031-09-03 12:00+00', '2031-09-03 13:00+00', 60,
    'Pago', 'MANUAL', null, null, 60, '[]'::jsonb, false)$q$) like 'P0001%estado terminal%', 'atendimento Pago não é editado');
reset role; select set_config('request.jwt.claims', '', true);

-- ═══ D. cancel_recurrence_series_atomic ═══
select pg_temp.login('00000000-0000-0000-0000-000000000870');
insert into t_ids values ('serie', (public.create_recurring_appointments_atomic(
  '00000000-0000-0000-0000-00000000087a', '00000000-0000-0000-0000-000000000875', '00000000-0000-0000-0000-000000000877',
  'Karenn', 'Agendado', 'MANUAL', null, null, 60, 60,
  '[{"index":1,"start_at":"2031-10-06 10:00+00","end_at":"2031-10-06 11:00+00"},
    {"index":2,"start_at":"2031-10-13 10:00+00","end_at":"2031-10-13 11:00+00"},
    {"index":3,"start_at":"2031-10-20 10:00+00","end_at":"2031-10-20 11:00+00"},
    {"index":4,"start_at":"2031-10-27 10:00+00","end_at":"2031-10-27 11:00+00"},
    {"index":5,"start_at":"2031-11-03 10:00+00","end_at":"2031-11-03 11:00+00"},
    {"index":6,"start_at":"2031-11-10 10:00+00","end_at":"2031-11-10 11:00+00"},
    {"index":7,"start_at":"2031-11-17 10:00+00","end_at":"2031-11-17 11:00+00"}]'::jsonb,
  '[{"service_id":"00000000-0000-0000-0000-000000000879","service_name":"Drenagem","price":60,"duration_minutes":60}]'::jsonb,
  false) ->> 'recurrence_id')::uuid);
-- Estados espalhados pela série: 1 Agendado, 2 Confirmado, 3 Pago, 4 Ausência, 5 Iniciado, 6 Pago Parcial, 7 Reservado.
update public.appointments set status = case recurrence_index
    when 2 then 'Confirmado' when 3 then 'Pago' when 4 then 'Ausência' when 5 then 'Iniciado' when 6 then 'Pago Parcial' when 7 then 'Reservado' end
where recurrence_id = (select id from t_ids where k = 'serie') and recurrence_index between 2 and 7;
reset role; select set_config('request.jwt.claims', '', true);
-- Uma ocorrência já passada, em aberto.
insert into public.appointments (id, org_id, client_id, client_name, staff_id, start_at, end_at, duration_minutes, status, recurrence_id, recurrence_index)
select '00000000-0000-0000-0000-000000000880', '00000000-0000-0000-0000-00000000087a', '00000000-0000-0000-0000-000000000875', 'Pilar Gómez',
  '00000000-0000-0000-0000-000000000877', '2020-01-06 10:00+00', '2020-01-06 11:00+00', 60, 'Agendado', id, 0
from t_ids where k = 'serie';

-- Quem não gerencia a agenda não cancela série; a série de outro estúdio não é tocada.
select pg_temp.login('00000000-0000-0000-0000-000000000872');
select pg_temp.expect(pg_temp.err(format('select public.cancel_recurrence_series_atomic(%L, %L)', '00000000-0000-0000-0000-00000000087a',
  (select id from t_ids where k = 'serie'))) like '42501%', 'profissional não cancela série');
select pg_temp.login('00000000-0000-0000-0000-000000000873');
select pg_temp.expect(pg_temp.err(format('select public.cancel_recurrence_series_atomic(%L, %L)', '00000000-0000-0000-0000-00000000087a',
  (select id from t_ids where k = 'serie'))) like '42501%', 'visualizadora não cancela série');
select pg_temp.login('00000000-0000-0000-0000-000000000874');
select pg_temp.expect(pg_temp.err(format('select public.cancel_recurrence_series_atomic(%L, %L)', '00000000-0000-0000-0000-00000000087a',
  (select id from t_ids where k = 'serie'))) like '42501%', 'dona de outro estúdio não cancela série da A');
select pg_temp.login('00000000-0000-0000-0000-000000000870');
select pg_temp.expect(public.cancel_recurrence_series_atomic('00000000-0000-0000-0000-00000000087a', '00000000-0000-0000-0000-00000000087f') = 0,
  'série da org B vista pela org A: 0 cancelamentos');
select pg_temp.expect(public.cancel_recurrence_series_atomic('00000000-0000-0000-0000-00000000087a', gen_random_uuid()) = 0, 'série inexistente: 0');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select status = 'Agendado' from public.appointments where id = '00000000-0000-0000-0000-00000000087e'), 'série da B intacta');

-- A recepção cancela: só as futuras abertas (Agendado, Confirmado, Reservado).
select pg_temp.login('00000000-0000-0000-0000-000000000871');
select pg_temp.expect(public.cancel_recurrence_series_atomic('00000000-0000-0000-0000-00000000087a', (select id from t_ids where k = 'serie')) = 3,
  'cancelou 3: Agendado, Confirmado e Reservado futuros');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select string_agg(coalesce(recurrence_index::text, '?') || '=' || status, ', ' order by recurrence_index)
    from public.appointments where recurrence_id = (select id from t_ids where k = 'serie'))
  = '0=Agendado, 1=Cancelado, 2=Cancelado, 3=Pago, 4=Ausência, 5=Iniciado, 6=Pago Parcial, 7=Cancelado',
  'Pago, Pago Parcial, Iniciado, Ausência e a ocorrência passada ficam como estavam');
select pg_temp.expect((select count(*) = 3 from public.appointment_status_history
  where notes = 'recurrence_cancelled' and appointment_id in (select id from public.appointments where recurrence_id = (select id from t_ids where k = 'serie'))),
  'três linhas de histórico recurrence_cancelled');
select pg_temp.expect((select (new_data ->> 'count')::int = 3 and user_id = '00000000-0000-0000-0000-000000000871' from public.audit_logs
  where operation = 'RECURRENCE_CANCELLED' and record_id = (select id from t_ids where k = 'serie')), 'auditoria RECURRENCE_CANCELLED com count 3');
-- Cancelar de novo não faz nada.
select pg_temp.login('00000000-0000-0000-0000-000000000870');
select pg_temp.expect(public.cancel_recurrence_series_atomic('00000000-0000-0000-0000-00000000087a', (select id from t_ids where k = 'serie')) = 0,
  'segundo cancelamento devolve 0');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select count(*) = 1 from public.audit_logs where operation = 'RECURRENCE_CANCELLED'
  and record_id = (select id from t_ids where k = 'serie')), 'segundo cancelamento não audita de novo');

rollback;
\o
\echo 'reagendar, status e série: ok'
