-- Cancelar com sinal numa transação só: cancel_appointment_settle_deposit_atomic (20261030210000).
-- Cobre caminho feliz (crédito, devolução, taxa), permissão, repetição sem duplicar crédito,
-- desfazer tudo quando o sinal não pode ser acertado, motivo em coluna própria e série.
-- Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000001280', 'dona@cancela.local'),
  ('00000000-0000-0000-0000-000000001281', 'recep@cancela.local'),
  ('00000000-0000-0000-0000-000000001282', 'prof@cancela.local'),
  ('00000000-0000-0000-0000-000000001283', 'outra@cancela.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-00000000128a', 'cancela-a', 'Cancela A'),
  ('00000000-0000-0000-0000-00000000128b', 'cancela-b', 'Cancela B');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000001280', '00000000-0000-0000-0000-00000000128a', 'owner'),
  ('00000000-0000-0000-0000-000000001281', '00000000-0000-0000-0000-00000000128a', 'receptionist'),
  ('00000000-0000-0000-0000-000000001282', '00000000-0000-0000-0000-00000000128a', 'professional'),
  ('00000000-0000-0000-0000-000000001283', '00000000-0000-0000-0000-00000000128b', 'owner');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-000000001284', '00000000-0000-0000-0000-00000000128a', 'Cliente Cancela');
insert into public.staff_members (id, org_id, name) values
  ('00000000-0000-0000-0000-000000001285', '00000000-0000-0000-0000-00000000128a', 'Karenn');
insert into public.services (id, org_id, name, price, duration_minutes) values
  ('00000000-0000-0000-0000-000000001286', '00000000-0000-0000-0000-00000000128a', 'Limpeza', 60, 60);

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
  select public.create_appointment_atomic('00000000-0000-0000-0000-00000000128a', '00000000-0000-0000-0000-000000001284', '00000000-0000-0000-0000-000000001285',
    p_start::timestamptz, p_start::timestamptz + interval '60 minutes', 60, 'Agendado', 'MANUAL', null, null, 60,
    '[{"service_id":"00000000-0000-0000-0000-000000001286","service_name":"Limpeza","price":60}]'::jsonb, false)
$$;
create function pg_temp.dep(p_appt uuid, p_amount numeric, p_key text) returns void language sql as $$
  select public.register_appointment_deposit_atomic('00000000-0000-0000-0000-00000000128a', p_appt, p_amount, 'CASH', p_key::uuid)
$$;
create function pg_temp.cancel_sql(p_appt uuid, p_reason text, p_mode text, p_series boolean default false) returns text language sql as $$
  select format('select public.cancel_appointment_settle_deposit_atomic(%L, %L, %L, %L, %L)',
    '00000000-0000-0000-0000-00000000128a', p_appt, p_reason, p_mode, p_series)
$$;
create function pg_temp.cancel_json(p_appt uuid, p_reason text, p_mode text, p_series boolean default false) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  execute pg_temp.cancel_sql(p_appt, p_reason, p_mode, p_series) into v;
  return v;
end $$;
create temp table t_ids (k text primary key, id uuid) on commit drop;
grant all on t_ids to authenticated;
grant execute on function pg_temp.expect(boolean, text), pg_temp.err(text), pg_temp.login(uuid), pg_temp.mk(text),
  pg_temp.dep(uuid, numeric, text), pg_temp.cancel_sql(uuid, text, text, boolean), pg_temp.cancel_json(uuid, text, text, boolean) to authenticated;

-- Agendamentos (um por cenário), cada um com o seu sinal.
select pg_temp.login('00000000-0000-0000-0000-000000001280');
insert into t_ids values
  ('credit', pg_temp.mk('2036-03-03 09:00+00')),
  ('legacy', pg_temp.mk('2036-03-04 09:00+00')),
  ('refund', pg_temp.mk('2036-03-05 09:00+00')),
  ('fee', pg_temp.mk('2036-03-06 09:00+00')),
  ('nocredit', pg_temp.mk('2036-03-07 09:00+00')),
  ('none', pg_temp.mk('2036-03-08 09:00+00')),
  ('done', pg_temp.mk('2036-03-09 09:00+00'));
select pg_temp.dep((select id from t_ids where k = 'credit'), 30, '00000000-0000-0000-0000-0000000012d1');
select pg_temp.dep((select id from t_ids where k = 'legacy'), 40, '00000000-0000-0000-0000-0000000012d2');
select pg_temp.dep((select id from t_ids where k = 'refund'), 25, '00000000-0000-0000-0000-0000000012d3');
select pg_temp.dep((select id from t_ids where k = 'fee'), 15, '00000000-0000-0000-0000-0000000012d4');
select pg_temp.dep((select id from t_ids where k = 'nocredit'), 10, '00000000-0000-0000-0000-0000000012d5');
select public.set_appointment_status_atomic('00000000-0000-0000-0000-00000000128a', (select id from t_ids where k = 'done'), 'Iniciado');
select public.set_appointment_status_atomic('00000000-0000-0000-0000-00000000128a', (select id from t_ids where k = 'done'), 'Concluído');
reset role;
select set_config('request.jwt.claims', '', true);
-- Concluído com comanda ativa (rascunho) não se cancela; sem comanda ativa pode (20261031100000).
insert into public.sales (org_id, appointment_id, client_name, status)
select '00000000-0000-0000-0000-00000000128a', id, 'Cliente Cancela', 'draft' from t_ids where k = 'done';

-- ═══ A. Crédito: cancela, lança crédito e anula o sinal juntos ═══
select pg_temp.login('00000000-0000-0000-0000-000000001280');
do $$
declare v jsonb;
begin
  v := pg_temp.cancel_json((select id from t_ids where k = 'credit'), 'A cliente pediu', 'credit');
  perform pg_temp.expect((v ->> 'credited')::numeric = 30 and (v ->> 'voided')::int = 1 and (v ->> 'cancelled_count')::int = 1
    and (v ->> 'already_cancelled')::boolean = false, 'resultado: crédito 30, um sinal anulado, um cancelado');
end $$;
reset role;
select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select status = 'Cancelado' and cancel_reason = 'A cliente pediu' from public.appointments where id = (select id from t_ids where k = 'credit')),
  'cancelado, com o motivo na coluna própria');
select pg_temp.expect((select coalesce(internal_notes, '') not like '%Cancelado%' from public.appointments where id = (select id from t_ids where k = 'credit')),
  'o motivo não vai mais para a nota interna');
select pg_temp.expect((select balance = 30 from public.clients where id = '00000000-0000-0000-0000-000000001284'), 'saldo da cliente subiu 30');
select pg_temp.expect((select status = 'cancelled' from public.appointment_deposits where appointment_id = (select id from t_ids where k = 'credit')), 'sinal anulado');
select pg_temp.expect((select count(*) = 1 from public.appointment_status_history
  where appointment_id = (select id from t_ids where k = 'credit') and status = 'Cancelado' and notes = 'A cliente pediu'
    and changed_by = '00000000-0000-0000-0000-000000001280'), 'histórico guarda o status, o motivo e quem cancelou');
select pg_temp.expect((select count(*) = 1 from public.audit_logs
  where operation = 'STATUS_CHANGE' and record_id = (select id from t_ids where k = 'credit') and new_data ->> 'status' = 'Cancelado'
    and new_data ->> 'deposit_mode' = 'credit'), 'auditoria da troca de status com o destino do sinal');

-- Repetir não duplica crédito nem histórico.
select pg_temp.login('00000000-0000-0000-0000-000000001280');
do $$
declare v jsonb;
begin
  v := pg_temp.cancel_json((select id from t_ids where k = 'credit'), 'A cliente pediu', 'credit');
  perform pg_temp.expect((v ->> 'already_cancelled')::boolean = true and (v ->> 'credited')::numeric = 0 and (v ->> 'cancelled_count')::int = 0,
    'repetir: já cancelado, nada de crédito novo');
end $$;
reset role;
select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select balance = 30 from public.clients where id = '00000000-0000-0000-0000-000000001284'), 'repetir não duplica o crédito');
select pg_temp.expect((select count(*) = 1 from public.appointment_status_history where appointment_id = (select id from t_ids where k = 'credit') and status = 'Cancelado'),
  'repetir não duplica o histórico');
select pg_temp.expect((select count(*) = 1 from public.client_balance_entries where idempotency_key = (select id from t_ids where k = 'credit')),
  'um só lançamento no extrato, com o agendamento como chave');

-- ═══ B. Cancelado antes (sinal ficou para trás): repetir acerta o sinal uma vez só ═══
update public.appointments set status = 'Cancelado' where id = (select id from t_ids where k = 'legacy');
select pg_temp.login('00000000-0000-0000-0000-000000001280');
do $$
declare v jsonb;
begin
  v := pg_temp.cancel_json((select id from t_ids where k = 'legacy'), null, 'credit');
  perform pg_temp.expect((v ->> 'already_cancelled')::boolean = true and (v ->> 'credited')::numeric = 40 and (v ->> 'voided')::int = 1,
    'cancelado sem acertar o sinal: o crédito sai agora');
  v := pg_temp.cancel_json((select id from t_ids where k = 'legacy'), null, 'credit');
  perform pg_temp.expect((v ->> 'credited')::numeric = 0 and (v ->> 'voided')::int = 0, 'e na segunda vez não sai de novo');
end $$;
reset role;
select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select balance = 70 from public.clients where id = '00000000-0000-0000-0000-000000001284'), 'saldo 30 + 40, sem duplicar');

-- ═══ C. Devolver: sinal anulado, sem crédito; recepção pode (comanda.operate) ═══
select pg_temp.login('00000000-0000-0000-0000-000000001281');
do $$
declare v jsonb;
begin
  v := pg_temp.cancel_json((select id from t_ids where k = 'refund'), 'Imprevisto do estúdio', 'refund');
  perform pg_temp.expect((v ->> 'credited')::numeric = 0 and (v ->> 'voided')::int = 1, 'devolver: sinal anulado, sem crédito');
end $$;
reset role;
select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select status = 'cancelled' from public.appointment_deposits where appointment_id = (select id from t_ids where k = 'refund')), 'sinal devolvido fica anulado');
select pg_temp.expect((select balance = 70 from public.clients where id = '00000000-0000-0000-0000-000000001284'), 'devolver não mexe no saldo');

-- ═══ D. Taxa: cancela e o sinal fica com o estúdio ═══
select pg_temp.login('00000000-0000-0000-0000-000000001281');
do $$
declare v jsonb;
begin
  v := pg_temp.cancel_json((select id from t_ids where k = 'fee'), null, 'fee');
  perform pg_temp.expect((v ->> 'fee_kept')::numeric = 15 and (v ->> 'voided')::int = 0 and (v ->> 'credited')::numeric = 0, 'taxa: 15 ficam com o estúdio');
end $$;
reset role;
select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select status = 'Cancelado' and cancel_reason is null from public.appointments where id = (select id from t_ids where k = 'fee')), 'cancelado sem motivo informado');
select pg_temp.expect((select status = 'confirmed' from public.appointment_deposits where appointment_id = (select id from t_ids where k = 'fee')), 'sinal da taxa continua confirmado');

-- ═══ E. Tudo ou nada: recepção não lança crédito, então nada muda ═══
select pg_temp.login('00000000-0000-0000-0000-000000001281');
select pg_temp.expect(pg_temp.err(pg_temp.cancel_sql((select id from t_ids where k = 'nocredit'), 'x', 'credit')) like '42501%',
  'recepção sem financeiro.manage não lança crédito');
reset role;
select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select status = 'Agendado' and cancel_reason is null from public.appointments where id = (select id from t_ids where k = 'nocredit')),
  'o agendamento NÃO foi cancelado');
select pg_temp.expect((select status = 'confirmed' from public.appointment_deposits where appointment_id = (select id from t_ids where k = 'nocredit')), 'o sinal continua confirmado');
select pg_temp.expect((select balance = 70 from public.clients where id = '00000000-0000-0000-0000-000000001284'), 'o saldo não mudou');
select pg_temp.expect((select count(*) = 1 from public.appointment_status_history where appointment_id = (select id from t_ids where k = 'nocredit')),
  'o histórico não ganhou linha de cancelamento');

-- ═══ F. Permissão, dados inválidos e isolamento ═══
select pg_temp.login('00000000-0000-0000-0000-000000001282');
select pg_temp.expect(pg_temp.err(pg_temp.cancel_sql((select id from t_ids where k = 'none'), null, 'fee')) like '42501%', 'profissional não cancela agendamento');
select pg_temp.login('00000000-0000-0000-0000-000000001283');
select pg_temp.expect(pg_temp.err(pg_temp.cancel_sql((select id from t_ids where k = 'none'), null, 'fee')) like '42501%', 'dona de outro estúdio não cancela');
select pg_temp.login('00000000-0000-0000-0000-000000001280');
select pg_temp.expect(pg_temp.err(pg_temp.cancel_sql((select id from t_ids where k = 'none'), null, 'perdoar')) like '22023%', 'destino do sinal inválido');
select pg_temp.expect(pg_temp.err(pg_temp.cancel_sql((select id from t_ids where k = 'none'), repeat('x', 121), 'fee')) like '22023%', 'motivo com mais de 120 caracteres');
select pg_temp.expect(pg_temp.err(pg_temp.cancel_sql('00000000-0000-0000-0000-0000000012ff', null, 'fee')) like 'P0002%', 'agendamento que não existe');
select pg_temp.expect(pg_temp.err(pg_temp.cancel_sql((select id from t_ids where k = 'done'), null, 'fee')) like '22023%', 'concluído com comanda ativa não se cancela');
-- Sem sinal: cancela e o destino escolhido não importa.
select pg_temp.expect(pg_temp.err(pg_temp.cancel_sql((select id from t_ids where k = 'none'), '   ', 'credit')) = 'OK', 'sem sinal cancela mesmo pedindo crédito');
reset role;
select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select status = 'Cancelado' and cancel_reason is null from public.appointments where id = (select id from t_ids where k = 'none')), 'motivo em branco vira vazio');

-- ═══ G. Série: este e os próximos, nunca os anteriores ═══
insert into public.appointments (id, org_id, client_id, client_name, staff_id, start_at, end_at, duration_minutes, status, recurrence_id, recurrence_index) values
  ('00000000-0000-0000-0000-0000000012e1', '00000000-0000-0000-0000-00000000128a', '00000000-0000-0000-0000-000000001284', 'Cliente Cancela', '00000000-0000-0000-0000-000000001285',
   '2037-01-05 09:00+00', '2037-01-05 10:00+00', 60, 'Agendado', '00000000-0000-0000-0000-0000000012f1', 1),
  ('00000000-0000-0000-0000-0000000012e2', '00000000-0000-0000-0000-00000000128a', '00000000-0000-0000-0000-000000001284', 'Cliente Cancela', '00000000-0000-0000-0000-000000001285',
   '2037-01-12 09:00+00', '2037-01-12 10:00+00', 60, 'Agendado', '00000000-0000-0000-0000-0000000012f1', 2),
  ('00000000-0000-0000-0000-0000000012e3', '00000000-0000-0000-0000-00000000128a', '00000000-0000-0000-0000-000000001284', 'Cliente Cancela', '00000000-0000-0000-0000-000000001285',
   '2037-01-19 09:00+00', '2037-01-19 10:00+00', 60, 'Confirmado', '00000000-0000-0000-0000-0000000012f1', 3);
select pg_temp.login('00000000-0000-0000-0000-000000001280');
do $$
declare v jsonb;
begin
  v := pg_temp.cancel_json('00000000-0000-0000-0000-0000000012e2', 'Viagem', 'fee', true);
  perform pg_temp.expect((v ->> 'cancelled_count')::int = 2, 'série: este e o próximo');
end $$;
reset role;
select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select status = 'Agendado' from public.appointments where id = '00000000-0000-0000-0000-0000000012e1'), 'a ocorrência anterior continua');
select pg_temp.expect((select status = 'Cancelado' and cancel_reason = 'Viagem' from public.appointments where id = '00000000-0000-0000-0000-0000000012e2'), 'a escolhida leva o motivo');
select pg_temp.expect((select status = 'Cancelado' from public.appointments where id = '00000000-0000-0000-0000-0000000012e3'), 'a seguinte é cancelada junto');
select pg_temp.expect((select notes = 'recurrence_cancelled' from public.appointment_status_history where appointment_id = '00000000-0000-0000-0000-0000000012e3' and status = 'Cancelado'),
  'histórico da seguinte marca o cancelamento da série');

rollback;
\o
\echo 'cancelar com sinal atômico: ok'
