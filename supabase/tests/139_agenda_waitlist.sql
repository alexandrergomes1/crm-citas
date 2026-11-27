-- Lista de espera da Agenda (20261030240000): permissão agenda.manage, isolamento por estúdio,
-- regras da tabela e fluxo oferecer/agendar/remover. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000001310', 'dona@espera.local'),
  ('00000000-0000-0000-0000-000000001311', 'recep@espera.local'),
  ('00000000-0000-0000-0000-000000001312', 'prof@espera.local'),
  ('00000000-0000-0000-0000-000000001313', 'donab@espera.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-00000000131a', 'espera-a', 'Espera A'),
  ('00000000-0000-0000-0000-00000000131b', 'espera-b', 'Espera B');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000001310', '00000000-0000-0000-0000-00000000131a', 'owner'),
  ('00000000-0000-0000-0000-000000001311', '00000000-0000-0000-0000-00000000131a', 'receptionist'),
  ('00000000-0000-0000-0000-000000001312', '00000000-0000-0000-0000-00000000131a', 'professional'),
  ('00000000-0000-0000-0000-000000001313', '00000000-0000-0000-0000-00000000131b', 'owner');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-000000001314', '00000000-0000-0000-0000-00000000131a', 'Cliente A'),
  ('00000000-0000-0000-0000-000000001315', '00000000-0000-0000-0000-00000000131b', 'Cliente B');
insert into public.staff_members (id, org_id, name) values
  ('00000000-0000-0000-0000-000000001316', '00000000-0000-0000-0000-00000000131a', 'Karenn'),
  ('00000000-0000-0000-0000-000000001317', '00000000-0000-0000-0000-00000000131b', 'Equipe B');
insert into public.services (id, org_id, name, price, duration_minutes) values
  ('00000000-0000-0000-0000-000000001318', '00000000-0000-0000-0000-00000000131a', 'Limpeza', 60, 60);

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
create function pg_temp.anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  perform set_config('role', 'anon', true);
end $$;
grant execute on function pg_temp.expect(boolean, text), pg_temp.err(text), pg_temp.login(uuid), pg_temp.anon() to authenticated, anon;

-- ═══ A. Quem gerencia a agenda usa a lista ═══
select pg_temp.login('00000000-0000-0000-0000-000000001311');
insert into public.agenda_waitlist (id, org_id, client_id, service_id, staff_id, windows, notes) values
  ('00000000-0000-0000-0000-0000000013a1', '00000000-0000-0000-0000-00000000131a', '00000000-0000-0000-0000-000000001314',
   '00000000-0000-0000-0000-000000001318', '00000000-0000-0000-0000-000000001316',
   '[{"date":"2035-07-02","from":"09:00","to":"12:00"},{"weekday":3,"from":"14:00","to":"18:00"}]'::jsonb, 'Prefere de manhã');
select pg_temp.expect((select status = 'waiting' and created_by = '00000000-0000-0000-0000-000000001311' and offered_at is null
  from public.agenda_waitlist where id = '00000000-0000-0000-0000-0000000013a1'), 'entra como "waiting", com quem adicionou');
update public.agenda_waitlist set status = 'offered', offered_at = now(), offered_for = '2035-07-02 10:00+00'
where id = '00000000-0000-0000-0000-0000000013a1';
select pg_temp.expect((select status = 'offered' and offered_for = '2035-07-02 10:00+00' from public.agenda_waitlist where id = '00000000-0000-0000-0000-0000000013a1'), 'oferecer registra o horário oferecido');
update public.agenda_waitlist set status = 'waiting', offered_at = null, offered_for = null where id = '00000000-0000-0000-0000-0000000013a1';
select pg_temp.expect((select status = 'waiting' from public.agenda_waitlist where id = '00000000-0000-0000-0000-0000000013a1'), 'volta para a fila se a cliente não aceitar');
update public.agenda_waitlist set status = 'removed' where id = '00000000-0000-0000-0000-0000000013a1';
select pg_temp.expect((select count(*) = 1 and bool_and(status = 'removed') from public.agenda_waitlist), 'remover mantém o histórico');
select pg_temp.expect((select updated_at >= created_at from public.agenda_waitlist where id = '00000000-0000-0000-0000-0000000013a1'), 'updated_at acompanha');

-- Agendar liga a entrada ao agendamento criado.
select pg_temp.login('00000000-0000-0000-0000-000000001310');
do $$
declare v_appt uuid;
begin
  v_appt := public.create_appointment_atomic('00000000-0000-0000-0000-00000000131a', '00000000-0000-0000-0000-000000001314', '00000000-0000-0000-0000-000000001316',
    '2035-07-02 10:00+00', '2035-07-02 11:00+00', 60, 'Agendado', 'MANUAL', null, null, 60,
    '[{"service_id":"00000000-0000-0000-0000-000000001318","service_name":"Limpeza","price":60}]'::jsonb, false);
  update public.agenda_waitlist set status = 'scheduled', appointment_id = v_appt where id = '00000000-0000-0000-0000-0000000013a1';
  perform pg_temp.expect((select status = 'scheduled' and appointment_id = v_appt from public.agenda_waitlist where id = '00000000-0000-0000-0000-0000000013a1'), 'agendar liga a entrada ao agendamento');
end $$;

-- ═══ B. Regras da tabela ═══
select pg_temp.expect(pg_temp.err($q$insert into public.agenda_waitlist (org_id, client_id, status) values
  ('00000000-0000-0000-0000-00000000131a', '00000000-0000-0000-0000-000000001314', 'esperando')$q$) like '23514%', 'status fora da lista é recusado');
select pg_temp.expect(pg_temp.err($q$insert into public.agenda_waitlist (org_id, client_id, windows) values
  ('00000000-0000-0000-0000-00000000131a', '00000000-0000-0000-0000-000000001314', '{"date":"2035-07-02"}'::jsonb)$q$) like '23514%', 'janelas precisam ser uma lista');
select pg_temp.expect(pg_temp.err(format($q$insert into public.agenda_waitlist (org_id, client_id, windows) values
  ('00000000-0000-0000-0000-00000000131a', '00000000-0000-0000-0000-000000001314', %L::jsonb)$q$,
  (select jsonb_agg(jsonb_build_object('weekday', 1, 'from', '09:00', 'to', '10:00')) from generate_series(1, 21)))) like '23514%', 'no máximo 20 janelas');
select pg_temp.expect(pg_temp.err($q$insert into public.agenda_waitlist (org_id, client_id, status) values
  ('00000000-0000-0000-0000-00000000131a', '00000000-0000-0000-0000-000000001314', 'scheduled')$q$) like '23514%', 'agendada precisa do agendamento');
select pg_temp.expect(pg_temp.err(format($q$insert into public.agenda_waitlist (org_id, client_id, notes) values
  ('00000000-0000-0000-0000-00000000131a', '00000000-0000-0000-0000-000000001314', %L)$q$, repeat('x', 501))) like '23514%', 'observação com mais de 500 caracteres');
-- Cliente, serviço e profissional de outro estúdio são recusados.
select pg_temp.expect(pg_temp.err($q$insert into public.agenda_waitlist (org_id, client_id) values
  ('00000000-0000-0000-0000-00000000131a', '00000000-0000-0000-0000-000000001315')$q$) like '23503%', 'cliente de outro estúdio');
select pg_temp.expect(pg_temp.err($q$insert into public.agenda_waitlist (org_id, client_id, staff_id) values
  ('00000000-0000-0000-0000-00000000131a', '00000000-0000-0000-0000-000000001314', '00000000-0000-0000-0000-000000001317')$q$) like '23503%', 'profissional de outro estúdio');

-- ═══ C. Quem não gerencia a agenda não vê nem mexe ═══
select pg_temp.login('00000000-0000-0000-0000-000000001312');
select pg_temp.expect((select count(*) = 0 from public.agenda_waitlist), 'profissional não lê a lista');
select pg_temp.expect(pg_temp.err($q$insert into public.agenda_waitlist (org_id, client_id) values
  ('00000000-0000-0000-0000-00000000131a', '00000000-0000-0000-0000-000000001314')$q$) like '42501%', 'nem escreve');
select pg_temp.expect(pg_temp.err($q$delete from public.agenda_waitlist$q$) = 'OK', 'apagar não falha, mas não alcança nenhuma linha');
select pg_temp.login('00000000-0000-0000-0000-000000001310');
select pg_temp.expect((select count(*) = 1 from public.agenda_waitlist), 'e a linha continua lá');

-- Liberação concedida: a profissional passa a usar a lista.
select public.set_role_permission('00000000-0000-0000-0000-00000000131a', 'professional', 'agenda.manage', true);
select pg_temp.login('00000000-0000-0000-0000-000000001312');
select pg_temp.expect((select count(*) = 1 from public.agenda_waitlist), 'com agenda.manage ela lê');

-- ═══ D. Outro estúdio e visitante ═══
select pg_temp.login('00000000-0000-0000-0000-000000001313');
select pg_temp.expect((select count(*) = 0 from public.agenda_waitlist), 'dona de outro estúdio não vê');
select pg_temp.expect(pg_temp.err($q$insert into public.agenda_waitlist (org_id, client_id) values
  ('00000000-0000-0000-0000-00000000131a', '00000000-0000-0000-0000-000000001314')$q$) like '42501%', 'nem escreve no estúdio alheio');
select pg_temp.anon();
select pg_temp.expect(pg_temp.err('select count(*) from public.agenda_waitlist') like '42501%', 'visitante sem acesso');

-- ═══ E. Apagar a cliente leva a entrada junto ═══
reset role;
select set_config('request.jwt.claims', '', true);
insert into public.clients (id, org_id, full_name) values ('00000000-0000-0000-0000-000000001319', '00000000-0000-0000-0000-00000000131a', 'Cliente C');
insert into public.agenda_waitlist (id, org_id, client_id) values ('00000000-0000-0000-0000-0000000013a2', '00000000-0000-0000-0000-00000000131a', '00000000-0000-0000-0000-000000001319');
select pg_temp.expect((select count(*) = 2 from public.agenda_waitlist), 'duas entradas antes');
delete from public.clients where id = '00000000-0000-0000-0000-000000001319';
select pg_temp.expect((select count(*) = 1 and min(id::text) = '00000000-0000-0000-0000-0000000013a1' from public.agenda_waitlist), 'entrada sai com a cliente, a outra fica');

rollback;
\o
\echo 'lista de espera: ok'
