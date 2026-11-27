-- ============================================================
-- Cobrança por transferência: permissões, link público, comprovante,
-- confirmação única e encerramento. Roda numa transação e desfaz tudo.
-- Encoding: UTF-8
-- ============================================================
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000c1', 'dona-c@teste.local'),
  ('00000000-0000-0000-0000-0000000000c2', 'recep-c@teste.local'),
  ('00000000-0000-0000-0000-0000000000c3', 'prof-c@teste.local'),
  ('00000000-0000-0000-0000-0000000000d1', 'dona-d@teste.local'),
  ('00000000-0000-0000-0000-0000000000f2', 'master2@teste.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-00000000000c', 'teste-c', 'Estúdio C'),
  ('00000000-0000-0000-0000-00000000000d', 'teste-d', 'Estúdio D');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-00000000000c', 'owner'),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-00000000000c', 'receptionist'),
  ('00000000-0000-0000-0000-0000000000c3', '00000000-0000-0000-0000-00000000000c', 'professional'),
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-00000000000d', 'owner');
insert into public.platform_admins (user_id) values ('00000000-0000-0000-0000-0000000000f2');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-00000000000c', 'Sofía Martín');
insert into public.appointments (id, org_id, client_id, client_name, start_at, end_at, duration_minutes, total) values
  ('00000000-0000-0000-0000-0000000000a9', '00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-0000000000e1',
   'Sofía Martín', now() + interval '1 day', now() + interval '1 day 1 hour', 60, 105);
insert into public.payment_accounts (id, org_id, kind, holder_name, identifier, active) values
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-00000000000c', 'bizum', 'Karenn Guimarães', '+34600000000', true),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-00000000000c', 'sepa', 'Karenn Guimarães', 'ES9121000418450200051332', false),
  ('00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-00000000000d', 'sepa', 'Outra', 'ES7921000813610123456789', true);

create function pg_temp.login(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;
create function pg_temp.anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  perform set_config('role', 'anon', true);
end $$;
create function pg_temp.service() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
  perform set_config('role', 'service_role', true);
end $$;
create function pg_temp.expect(p_ok boolean, p_msg text) returns void language plpgsql as $$
begin
  if not coalesce(p_ok, false) then raise exception 'FALHOU: %', p_msg; end if;
end $$;
create temp table t (k text primary key, v text);
grant all on t to authenticated, anon, service_role;
grant execute on function pg_temp.login(uuid), pg_temp.anon(), pg_temp.service(), pg_temp.expect(boolean, text) to authenticated, anon, service_role;

-- 1. profissional não cobra
select pg_temp.login('00000000-0000-0000-0000-0000000000c3');
do $$ begin
  begin
    perform public.create_payment_request('00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-0000000000e1',
      '00000000-0000-0000-0000-0000000000a9', 'deposit', 30, 'Sinal', array['00000000-0000-0000-0000-0000000000b1']::uuid[], 24);
    raise exception 'FALHOU: profissional criou cobrança';
  exception when insufficient_privilege then null; end;
end $$;
reset role; select set_config('request.jwt.claims', '', true);

-- 2. recepção cria sinal; conta inativa ou de outro estúdio não entra; sinal acima do total recusado
select pg_temp.login('00000000-0000-0000-0000-0000000000c2');
do $$
declare r jsonb;
begin
  begin
    perform public.create_payment_request('00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-0000000000e1',
      '00000000-0000-0000-0000-0000000000a9', 'deposit', 30, 'Sinal', array['00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000b3']::uuid[], 24);
    raise exception 'FALHOU: aceitou só contas inválidas';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.create_payment_request('00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-0000000000e1',
      '00000000-0000-0000-0000-0000000000a9', 'deposit', 200, 'Sinal', array['00000000-0000-0000-0000-0000000000b1']::uuid[], 24);
    raise exception 'FALHOU: sinal maior que o atendimento';
  exception when numeric_value_out_of_range then null; end;
  r := public.create_payment_request('00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-0000000000e1',
    '00000000-0000-0000-0000-0000000000a9', 'deposit', 30, 'Sinal do atendimento de sexta', array['00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000b3']::uuid[], 24);
  perform pg_temp.expect(r->>'reference' like 'SINAL-%', 'referência de sinal');
  perform pg_temp.expect(length(r->>'token') >= 30, 'token longo');
  insert into t values ('token', r->>'token'), ('id', r->>'id');
end $$;
select pg_temp.expect((select jsonb_array_length(accounts) from public.payment_requests where id = (select v::uuid from t where k = 'id')) = 1,
  'conta de outro estúdio fica fora da cópia');
select pg_temp.expect((select token_hash <> (select v from t where k = 'token') from public.payment_requests where id = (select v::uuid from t where k = 'id')),
  'banco guarda só o hash');
reset role; select set_config('request.jwt.claims', '', true);

-- 3. link público
-- 20261114100200: o link passa pelo servidor (chave de serviço); anon não lê nem pela função antiga.
select pg_temp.service();
select pg_temp.expect((public.public_payment_open((select v from t where k = 'token'), repeat('1', 64)))->>'status' = 'pending', 'link mostra pendente');
select pg_temp.expect((public.public_payment_open((select v from t where k = 'token'), repeat('1', 64)))->>'client_first_name' = 'Sofía', 'só o primeiro nome');
select pg_temp.expect(public.public_payment_open('x' || repeat('a', 31), repeat('1', 64)) is null, 'token errado não mostra nada');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.anon();
do $$ begin
  begin
    perform public.public_payment_open((select v from t where k = 'token'), repeat('1', 64));
    raise exception 'FALHOU: anon chamou a função do link direto';
  exception when insufficient_privilege then null; end;
end $$;
do $$ begin
  begin
    perform count(*) from public.payment_requests;
    raise exception 'FALHOU: anon leu pedidos';
  exception when insufficient_privilege then null; end;
end $$;
do $$ begin
  begin
    perform public.public_payment_proof_begin((select v from t where k = 'token'), repeat('1', 64), true);
    raise exception 'FALHOU: anon chamou o envio de comprovante direto';
  exception when insufficient_privilege then null; end;
  begin
    perform public.public_payment_proof_submit((select v from t where k = 'token'), repeat('1', 64), 'x', 'application/pdf', null);
    raise exception 'FALHOU: anon registrou comprovante direto';
  exception when insufficient_privilege then null; end;
end $$;
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.service();
-- 20261114100200: as funções antigas saíram; o servidor usa public_payment_proof_begin/submit.
select pg_temp.expect(to_regprocedure('public.begin_payment_proof_upload(text, boolean)') is null
  and to_regprocedure('public.get_payment_request_by_token(text)') is null, 'funções antigas pelo token removidas');
select pg_temp.expect((public.public_payment_proof_begin((select v from t where k = 'token'), repeat('1', 64), true))->>'folder' like '00000000-0000-0000-0000-00000000000c/%', 'pasta do pedido');
-- vagas: 1 usada acima; mais 4 e a 6ª é recusada (pedidos em paralelo não passam de 5)
select public.public_payment_proof_begin((select v from t where k = 'token'), repeat('1', 64), true) from generate_series(1, 4);
select pg_temp.expect((public.public_payment_proof_begin((select v from t where k = 'token'), repeat('1', 64), true))->>'error' = 'limit', 'passou de 5 arquivos: recusa');
select pg_temp.expect((public.public_payment_proof_begin((select v from t where k = 'token'), repeat('1', 64), false))->>'folder' is not null, 'conferir sem reservar continua valendo');
reset role; select set_config('request.jwt.claims', '', true);

-- arquivo gravado pelo servidor (service_role) na pasta do pedido
insert into storage.objects (bucket_id, name, metadata) values
  ('payment-proofs', '00000000-0000-0000-0000-00000000000c/' || (select v from t where k = 'id') || '/11111111-1111-4111-8111-111111111111.pdf', '{"size": 2048}'),
  ('payment-proofs', '00000000-0000-0000-0000-00000000000c/' || (select v from t where k = 'id') || '/22222222-2222-4222-8222-222222222222.pdf', '{}'),
  ('payment-proofs', '00000000-0000-0000-0000-00000000000d/outro/arquivo.pdf', '{"size": 10}');

select pg_temp.service();
select pg_temp.expect((public.public_payment_proof_submit((select v from t where k = 'token'), repeat('1', 64), '00000000-0000-0000-0000-00000000000d/outro/arquivo.pdf', 'application/pdf', null))->>'error' = 'invalid',
  'arquivo de outra pasta: recusa');
select pg_temp.expect((public.public_payment_proof_submit((select v from t where k = 'token'), repeat('1', 64),
  '00000000-0000-0000-0000-00000000000c/' || (select v from t where k = 'id') || '/11111111-1111-4111-8111-111111111111.pdf', 'application/x-msdownload', null))->>'error' = 'invalid',
  'tipo de arquivo perigoso: recusa');
select pg_temp.expect((public.public_payment_proof_submit((select v from t where k = 'token'), repeat('1', 64),
  '00000000-0000-0000-0000-00000000000c/' || (select v from t where k = 'id') || '/22222222-2222-4222-8222-222222222222.pdf', 'application/pdf', null))->>'error' = 'invalid',
  'arquivo sem tamanho no Storage: recusa');
select public.public_payment_proof_submit((select v from t where k = 'token'), repeat('1', 64),
  '00000000-0000-0000-0000-00000000000c/' || (select v from t where k = 'id') || '/11111111-1111-4111-8111-111111111111.pdf', 'application/pdf', 'Paguei agora');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select status from public.payment_requests where id = (select v::uuid from t where k = 'id')) = 'proof_sent', 'comprovante enviado');
select pg_temp.expect((select proof_size from public.payment_requests where id = (select v::uuid from t where k = 'id')) = 2048, 'tamanho vem do Storage, não do chamador');

-- 4. outro estúdio não vê nem confirma
select pg_temp.login('00000000-0000-0000-0000-0000000000d1');
select pg_temp.expect((select count(*) from public.payment_requests) = 0, 'estúdio D não vê pedidos do C');
do $$ begin
  begin
    perform public.confirm_payment_request('00000000-0000-0000-0000-00000000000c', (select v::uuid from t where k = 'id'), 'BIZUM');
    raise exception 'FALHOU: outro estúdio confirmou';
  exception when insufficient_privilege then null; end;
end $$;
reset role; select set_config('request.jwt.claims', '', true);

-- 5. recepção confirma uma vez só; vira sinal do agendamento
select pg_temp.login('00000000-0000-0000-0000-0000000000c2');
select public.confirm_payment_request('00000000-0000-0000-0000-00000000000c', (select v::uuid from t where k = 'id'), 'BIZUM');
select pg_temp.expect((public.confirm_payment_request('00000000-0000-0000-0000-00000000000c', (select v::uuid from t where k = 'id'), 'BIZUM'))->>'duplicate' = 'true', 'segunda confirmação é repetição');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select count(*) from public.appointment_deposits where appointment_id = '00000000-0000-0000-0000-0000000000a9') = 1, 'um único sinal');
select pg_temp.expect((select amount from public.appointment_deposits where appointment_id = '00000000-0000-0000-0000-0000000000a9') = 30, 'valor do sinal');
select pg_temp.service();
-- 20261114100200: pago responde igual a link inexistente.
select pg_temp.expect(public.public_payment_open((select v from t where k = 'token'), repeat('1', 64)) is null, 'link pago não mostra nada');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select status = 'confirmed' from public.payment_requests where id = (select v::uuid from t where k = 'id')), 'pedido fica pago');
select pg_temp.service();
select pg_temp.expect((public.public_payment_proof_begin((select v from t where k = 'token'), repeat('1', 64), true))->>'error' = 'not_found', 'recusado: pedido pago não aceita comprovante');
reset role; select set_config('request.jwt.claims', '', true);

-- 6. crédito: recepção não lança crédito (regra do saldo); proprietária lança
select pg_temp.login('00000000-0000-0000-0000-0000000000c1');
do $$
declare r jsonb;
begin
  r := public.create_payment_request('00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-0000000000e1',
    null, 'credit', 50, 'Pacote de manutenção', array['00000000-0000-0000-0000-0000000000b1']::uuid[], 48);
  perform pg_temp.expect(r->>'reference' like 'PAG-%', 'referência de pagamento');
  insert into t values ('credit_id', r->>'id'), ('credit_token', r->>'token');
end $$;
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.login('00000000-0000-0000-0000-0000000000c2');
do $$ begin
  begin
    perform public.create_payment_request('00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-0000000000e1',
      null, 'credit', 10, 'Crédito', array['00000000-0000-0000-0000-0000000000b1']::uuid[], 24);
    raise exception 'FALHOU: recepção criou cobrança de crédito';
  exception when insufficient_privilege then null; end;
  begin
    perform public.confirm_payment_request('00000000-0000-0000-0000-00000000000c', (select v::uuid from t where k = 'credit_id'), 'TRANSFER');
    raise exception 'FALHOU: recepção lançou crédito';
  exception when insufficient_privilege then null; end;
end $$;
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select status from public.payment_requests where id = (select v::uuid from t where k = 'credit_id')) = 'pending', 'falha não muda o pedido');
select pg_temp.login('00000000-0000-0000-0000-0000000000c1');
select public.confirm_payment_request('00000000-0000-0000-0000-00000000000c', (select v::uuid from t where k = 'credit_id'), 'TRANSFER');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select balance from public.clients where id = '00000000-0000-0000-0000-0000000000e1') = 50, 'crédito na cliente');
select pg_temp.expect((select t2.method from public.transactions t2 join public.client_balance_entries e on e.transaction_id = t2.id
  where e.idempotency_key = (select v::uuid from t where k = 'credit_id')) = 'TRANSFER', 'caixa registra transferência, não dinheiro');

-- 7. vencido, recusa e cancelamento
select pg_temp.login('00000000-0000-0000-0000-0000000000c1');
do $$
declare r jsonb;
begin
  r := public.create_payment_request('00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-0000000000e1',
    null, 'credit', 20, 'Teste vencido', array['00000000-0000-0000-0000-0000000000b1']::uuid[], 1);
  insert into t values ('old_id', r->>'id'), ('old_token', r->>'token');
  begin
    perform public.close_payment_request('00000000-0000-0000-0000-00000000000c', (r->>'id')::uuid, 'reject', '');
    raise exception 'FALHOU: recusou sem motivo';
  exception when invalid_parameter_value then null; end;
end $$;
reset role; select set_config('request.jwt.claims', '', true);
update public.payment_requests set expires_at = now() - interval '1 minute' where id = (select v::uuid from t where k = 'old_id');
select pg_temp.service();
-- 20261114100200: vencido responde igual a link inexistente; o upload também.
select pg_temp.expect(public.public_payment_open((select v from t where k = 'old_token'), repeat('1', 64)) is null, 'link vencido não mostra nada');
select pg_temp.expect((public.public_payment_proof_begin((select v from t where k = 'old_token'), repeat('1', 64), true)) ->> 'error' = 'not_found',
  'link vencido não recebe comprovante');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.login('00000000-0000-0000-0000-0000000000c1');
select public.close_payment_request('00000000-0000-0000-0000-00000000000c', (select v::uuid from t where k = 'old_id'), 'cancel');
do $$
declare v_ok boolean := false;
begin
  begin
    perform public.confirm_payment_request('00000000-0000-0000-0000-00000000000c', (select v::uuid from t where k = 'old_id'), 'TRANSFER');
  exception when raise_exception then v_ok := true; end;
  perform pg_temp.expect(v_ok, 'recusado: confirmou cancelado');
end $$;
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select count(*) from public.audit_logs where table_name = 'payment_requests' and org_id = '00000000-0000-0000-0000-00000000000c') >= 6, 'tudo auditado');

-- 8. sem o módulo, não cria
select pg_temp.login('00000000-0000-0000-0000-0000000000f2');
insert into public.org_modules (org_id, module_key, enabled) values ('00000000-0000-0000-0000-00000000000c', 'cobranca', false);
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.login('00000000-0000-0000-0000-0000000000c1');
do $$ begin
  begin
    perform public.create_payment_request('00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-0000000000e1',
      null, 'credit', 10, 'Sem módulo', array['00000000-0000-0000-0000-0000000000b1']::uuid[], 24);
    raise exception 'FALHOU: criou sem o módulo';
  exception when insufficient_privilege then null; end;
end $$;
reset role; select set_config('request.jwt.claims', '', true);

-- 9. contas: só proprietária/administração escrevem; recepção lê
select pg_temp.login('00000000-0000-0000-0000-0000000000c2');
select pg_temp.expect((select count(*) from public.payment_accounts) = 2, 'recepção lê as contas do estúdio');
do $$ begin
  update public.payment_accounts set identifier = 'ES0000000000000000000000' where org_id = '00000000-0000-0000-0000-00000000000c';
  perform pg_temp.expect(not exists (select 1 from public.payment_accounts where identifier = 'ES0000000000000000000000'), 'recepção não altera conta');
end $$;
reset role; select set_config('request.jwt.claims', '', true);

rollback;
\o
\echo 'cobrança por transferência: ok'
