-- Cancelar série só nas ocorrências futuras em aberto e sem profissional; chave de ajuste de
-- saldo não vale para outra cliente. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000010a1', 'dono3@teste.local'),
  ('00000000-0000-0000-0000-0000000010a2', 'prof3@teste.local');
insert into public.organizations (id, slug, name) values ('00000000-0000-0000-0000-0000000010aa', 'serie-a', 'Serie');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-0000000010a1', '00000000-0000-0000-0000-0000000010aa', 'owner'),
  ('00000000-0000-0000-0000-0000000010a2', '00000000-0000-0000-0000-0000000010aa', 'professional');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-0000000010a3', '00000000-0000-0000-0000-0000000010aa', 'Lúcia Peña'),
  ('00000000-0000-0000-0000-0000000010a6', '00000000-0000-0000-0000-0000000010aa', 'Marta Díaz');
insert into public.staff_members (id, org_id, name) values
  ('00000000-0000-0000-0000-0000000010a4', '00000000-0000-0000-0000-0000000010aa', 'Karenn');

create function pg_temp.expect(p_ok boolean, p_msg text) returns void language plpgsql as $$
begin
  if not coalesce(p_ok, false) then raise exception 'FALHOU: %', p_msg; end if;
end $$;
grant execute on function pg_temp.expect(boolean, text) to authenticated;

-- Quatro ocorrências da mesma série: passada aberta, iniciada, futura aberta e paga.
insert into public.appointments (id, org_id, client_id, client_name, staff_id, start_at, end_at, duration_minutes, status, recurrence_id)
select ('00000000-0000-0000-0000-00000000108' || n)::uuid, '00000000-0000-0000-0000-0000000010aa',
       '00000000-0000-0000-0000-0000000010a3', 'Lúcia Peña', '00000000-0000-0000-0000-0000000010a4',
       t, t + interval '1 hour', 60, 'Agendado', '00000000-0000-0000-0000-0000000010ab'
from (values (1, now() - interval '3 days', 'Agendado'), (2, now() - interval '1 hour', 'Iniciado'),
             (3, now() + interval '3 days', 'Confirmado'), (4, now() + interval '5 days', 'Pago')) v(n, t, s);

-- O banco só aceita agendamento novo como Agendado/Reservado/Confirmado: ajusta depois, como a dona.
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000010a1', 'role', 'authenticated')::text, true);
select set_config('role', 'authenticated', true);
update public.appointments set status = 'Iniciado' where id = '00000000-0000-0000-0000-000000001082';
update public.appointments set status = 'Confirmado' where id = '00000000-0000-0000-0000-000000001083';
update public.appointments set status = 'Pago' where id = '00000000-0000-0000-0000-000000001084';

select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000010a2', 'role', 'authenticated')::text, true);
select set_config('role', 'authenticated', true);
do $$
declare v_ok boolean := false;
begin
  begin
    perform public.cancel_recurrence_series_atomic('00000000-0000-0000-0000-0000000010aa', '00000000-0000-0000-0000-0000000010ab');
  exception when insufficient_privilege then v_ok := true; end;
  perform pg_temp.expect(v_ok, 'profissional não cancela série');
end $$;

select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000010a1', 'role', 'authenticated')::text, true);
do $$
declare v_n integer;
begin
  v_n := public.cancel_recurrence_series_atomic('00000000-0000-0000-0000-0000000010aa', '00000000-0000-0000-0000-0000000010ab');
  perform pg_temp.expect(v_n = 1, 'só a ocorrência futura em aberto é cancelada');
  perform pg_temp.expect((select status from public.appointments where id = '00000000-0000-0000-0000-000000001081') = 'Agendado', 'passada fica');
  perform pg_temp.expect((select status from public.appointments where id = '00000000-0000-0000-0000-000000001082') = 'Iniciado', 'iniciada fica');
  perform pg_temp.expect((select status from public.appointments where id = '00000000-0000-0000-0000-000000001083') = 'Cancelado', 'futura aberta cancela');
  perform pg_temp.expect((select status from public.appointments where id = '00000000-0000-0000-0000-000000001084') = 'Pago', 'paga fica');
end $$;

-- Chave de idempotência do ajuste de saldo.
do $$
declare v_r jsonb; v_ok boolean := false;
begin
  v_r := public.adjust_client_balance_atomic('00000000-0000-0000-0000-0000000010aa', '00000000-0000-0000-0000-0000000010a3',
    'credit', 30, 'teste', '00000000-0000-0000-0000-0000000010c1');
  perform pg_temp.expect((v_r ->> 'balance')::numeric = 30 and (v_r ->> 'duplicate')::boolean = false, 'ajuste grava saldo 30');
  v_r := public.adjust_client_balance_atomic('00000000-0000-0000-0000-0000000010aa', '00000000-0000-0000-0000-0000000010a3',
    'credit', 30, 'teste', '00000000-0000-0000-0000-0000000010c1');
  perform pg_temp.expect((v_r ->> 'duplicate')::boolean = true and (v_r ->> 'balance')::numeric = 30, 'mesma chave, mesma cliente: repete sem somar');
  begin
    perform public.adjust_client_balance_atomic('00000000-0000-0000-0000-0000000010aa', '00000000-0000-0000-0000-0000000010a6',
      'credit', 30, 'teste', '00000000-0000-0000-0000-0000000010c1');
  exception when check_violation then v_ok := true; end;
  perform pg_temp.expect(v_ok, 'mesma chave com outra cliente é recusada');
  perform pg_temp.expect((select balance from public.clients where id = '00000000-0000-0000-0000-0000000010a6') = 0, 'outra cliente não recebe saldo');
end $$;

reset role;
rollback;
\o
\echo 'série e chave de saldo: ok'
