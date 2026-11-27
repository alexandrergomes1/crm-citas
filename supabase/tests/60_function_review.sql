-- Revisão de funções de 29 out: checkout, links públicos de anamnese, cobrança de crédito,
-- catálogo e auditoria. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000006a1', 'dona@teste.local'),
  ('00000000-0000-0000-0000-0000000006a2', 'recepcao@teste.local'),
  ('00000000-0000-0000-0000-0000000006a3', 'visual@teste.local');
insert into public.organizations (id, slug, name) values ('00000000-0000-0000-0000-0000000006aa', 'rev-a', 'Rev');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-0000000006a1', '00000000-0000-0000-0000-0000000006aa', 'owner'),
  ('00000000-0000-0000-0000-0000000006a2', '00000000-0000-0000-0000-0000000006aa', 'receptionist'),
  ('00000000-0000-0000-0000-0000000006a3', '00000000-0000-0000-0000-0000000006aa', 'viewer');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-0000000006c1', '00000000-0000-0000-0000-0000000006aa', 'Lucía Gómez');
insert into public.services (id, org_id, name, price, duration_minutes) values
  ('00000000-0000-0000-0000-0000000006d1', '00000000-0000-0000-0000-0000000006aa', 'Limpeza', 50, 60);
insert into public.appointments (id, org_id, client_id, client_name, start_at, end_at, duration_minutes, total, status) values
  ('00000000-0000-0000-0000-0000000006e1', '00000000-0000-0000-0000-0000000006aa', '00000000-0000-0000-0000-0000000006c1',
   'Lucía Gómez', now() + interval '2 days', now() + interval '2 days 1 hour', 60, 50, 'Agendado'),
  ('00000000-0000-0000-0000-0000000006e2', '00000000-0000-0000-0000-0000000006aa', '00000000-0000-0000-0000-0000000006c1',
   'Lucía Gómez', now() + interval '3 days', now() + interval '3 days 1 hour', 60, 50, 'Agendado');
update public.appointments set status = 'Cancelado' where id = '00000000-0000-0000-0000-0000000006e2';
insert into public.appointment_items (org_id, appointment_id, type, ref_id, name, price, cost_amount, qty, discount, commission_pct) values
  ('00000000-0000-0000-0000-0000000006aa', '00000000-0000-0000-0000-0000000006e1', 'service', '00000000-0000-0000-0000-0000000006d1', 'Limpeza', 50, 0, 1, 0, 0);

create function pg_temp.login(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;
create function pg_temp.expect(p_ok boolean, p_msg text) returns void language plpgsql as $$
begin
  if not coalesce(p_ok, false) then raise exception 'FALHOU: %', p_msg; end if;
end $$;
grant execute on function pg_temp.login(uuid), pg_temp.expect(boolean, text) to authenticated, anon, service_role;

-- 1. Sinal de 50, comanda de 50 com desconto de 20: os 20 a mais viram crédito da cliente.
select pg_temp.login('00000000-0000-0000-0000-0000000006a1');
select public.register_appointment_deposit_atomic('00000000-0000-0000-0000-0000000006aa',
  '00000000-0000-0000-0000-0000000006e1', 50, 'CASH', '00000000-0000-0000-0000-0000000006f1');
select public.confirm_checkout_atomic('00000000-0000-0000-0000-0000000006aa', jsonb_build_object(
  'request_id', '00000000-0000-0000-0000-0000000006f2',
  'appointment_id', '00000000-0000-0000-0000-0000000006e1',
  'mode', 'finalize', 'discount', 20,
  'items', jsonb_build_array(jsonb_build_object('item_type', 'service', 'item_id', '00000000-0000-0000-0000-0000000006d1',
    'name', 'Limpeza', 'unit_price', 50, 'quantity', 1)),
  'payments', '[]'::jsonb));
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select balance from public.clients where id = '00000000-0000-0000-0000-0000000006c1') = 20,
  'sinal maior que o total vira crédito de 20');
select pg_temp.expect(exists (select 1 from public.client_balance_entries
  where client_id = '00000000-0000-0000-0000-0000000006c1' and entry_type = 'overpayment_credit' and amount = 20),
  'lançamento overpayment_credit no extrato');

-- 2. Atendimento cancelado não é cobrado.
select pg_temp.login('00000000-0000-0000-0000-0000000006a1');
do $$
declare v_ok boolean := false;
begin
  begin
    perform public.confirm_checkout_atomic('00000000-0000-0000-0000-0000000006aa', jsonb_build_object(
      'request_id', '00000000-0000-0000-0000-0000000006f3',
      'appointment_id', '00000000-0000-0000-0000-0000000006e2', 'mode', 'finalize',
      'items', jsonb_build_array(jsonb_build_object('item_type', 'SERVICE', 'name', 'Limpeza', 'unit_price', 50, 'quantity', 1)),
      'payments', jsonb_build_array(jsonb_build_object('method', 'CASH', 'amount', 50))));
  exception when raise_exception then v_ok := sqlerrm like 'Atendimento cancelado%';
  end;
  perform pg_temp.expect(v_ok, 'recusa cobrar atendimento cancelado');
end $$;
reset role; select set_config('request.jwt.claims', '', true);

-- 3. Link público de anamnese: assinada não devolve nada; assinatura só em imagem.
insert into public.anamneses (id, org_id, client_id, client_name, template_title, template_snapshot, answers,
  consent_text, status, public_token, token_expires_at, signature_name, signature_data_url, signed_at)
values
  ('00000000-0000-0000-0000-0000000006b1', '00000000-0000-0000-0000-0000000006aa', '00000000-0000-0000-0000-0000000006c1',
   'Lucía Gómez', 'Ficha', '{"questions":[{"id":"q1","label":"Alergias?"}]}', '{"q1":"Látex"}',
   'Consinto', 'signed', 'tok_signed_000000000000000000000', now() + interval '1 day', 'Lucía', 'data:image/png;base64,AAAA', now()),
  ('00000000-0000-0000-0000-0000000006b2', '00000000-0000-0000-0000-0000000006aa', '00000000-0000-0000-0000-0000000006c1',
   'Lucía Gómez', 'Ficha', '{"questions":[{"id":"q1","label":"Alergias?"}]}', '{}',
   'Consinto', 'pending', 'tok_pending_00000000000000000000', now() + interval '1 day', null, null, null);
-- 20261114100100: o link passa pelo servidor (chave de serviço) e assinada responde igual a inexistente.
select set_config('role', 'service_role', true);
select pg_temp.expect(public.public_anamnese_open('tok_signed_000000000000000000000', repeat('1', 64), false) is null,
  'assinada: nada (igual a link inexistente)');
select pg_temp.expect(jsonb_array_length(public.public_anamnese_open('tok_pending_00000000000000000000', repeat('1', 64), false) -> 'questions') = 1,
  'pendente: perguntas presentes');
select pg_temp.expect(public.public_anamnese_open('curto', repeat('1', 64), false) is null, 'token curto não consulta');
select pg_temp.expect((public.public_anamnese_sign('tok_pending_00000000000000000000', repeat('1', 64), '{"__canal":"link"}'::jsonb, 'Lucía',
  'javascript:alert(1)' || repeat('x', 60), true, 'ua', null)) ->> 'error' = 'invalid_payload', 'assinatura precisa ser imagem');
select pg_temp.expect((public.public_anamnese_sign('tok_pending_00000000000000000000', repeat('1', 64), '{"q1":"Nada","__canal":"link","__termo_principal":"aceito"}'::jsonb, 'Lucía',
  'data:image/png;base64,' || repeat('A', 60), true, repeat('u', 900), null)) ->> 'ok' = 'true', 'assina com dados válidos');
reset role;
select pg_temp.expect((select length(signer_user_agent) from public.anamneses where id = '00000000-0000-0000-0000-0000000006b2') = 500,
  'user agent cortado em 500');

-- 4. Cobrança de crédito: recepção não confirma.
insert into public.payment_requests (id, org_id, client_id, purpose, amount, reason, reference, token_hash, expires_at, status, accounts)
values ('00000000-0000-0000-0000-0000000006a9', '00000000-0000-0000-0000-0000000006aa', '00000000-0000-0000-0000-0000000006c1',
  'credit', 30, 'Crédito', 'KB-TESTE', repeat('a', 64), now() + interval '1 day', 'pending', '[{"kind":"bizum","identifier":"+34600000000"}]'::jsonb);
select pg_temp.login('00000000-0000-0000-0000-0000000006a2');
do $$
declare v_ok boolean := false;
begin
  begin
    perform public.confirm_payment_request('00000000-0000-0000-0000-0000000006aa', '00000000-0000-0000-0000-0000000006a9', 'BIZUM');
  exception when insufficient_privilege then v_ok := sqlerrm like 'Crédito da cliente só é confirmado pela gestão%';
  end;
  perform pg_temp.expect(v_ok, 'recepção não confirma crédito');
end $$;
reset role; select set_config('request.jwt.claims', '', true);

-- 5. Serviço com venda gravada em minúsculo não pode ser apagado.
do $$
declare v_ok boolean := false;
begin
  delete from public.appointment_items where ref_id = '00000000-0000-0000-0000-0000000006d1';
  begin
    delete from public.services where id = '00000000-0000-0000-0000-0000000006d1';
  exception when foreign_key_violation then v_ok := true;
  end;
  perform pg_temp.expect(v_ok, 'serviço vendido (item_type service) não é apagado');
end $$;

-- 6. Visualizadora não grava auditoria.
select pg_temp.login('00000000-0000-0000-0000-0000000006a3');
do $$
declare v_ok boolean := false;
begin
  begin
    insert into public.audit_logs (org_id, user_id, table_name, operation)
    values ('00000000-0000-0000-0000-0000000006aa', '00000000-0000-0000-0000-0000000006a3', 'payment_requests', 'PAYMENT_REQUEST_CONFIRMED');
  exception when insufficient_privilege then v_ok := true;
  end;
  perform pg_temp.expect(v_ok, 'visualizadora não grava auditoria');
end $$;
reset role; select set_config('request.jwt.claims', '', true);

rollback;
\o
\echo 'revisão de funções: ok'
