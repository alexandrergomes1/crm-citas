-- Trava clínica da anamnese, de ponta a ponta nas funções reais do banco:
--   * concluir/cobrar atendimento com ficha obrigatória pendente falha (RPC e UPDATE direto);
--   * ficha profissional pendente barra só a cobrança, não o início;
--   * ficha assinada é imutável (protect_signed_anamnese_evidence);
--   * link público: token vencido, segunda assinatura e leitura depois de assinada.
-- Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

-- Org A (ids 08xx): dona, recepção, profissional, visualizadora. Org B: outra dona, só para isolamento.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000810', 'dona@anam.local'),
  ('00000000-0000-0000-0000-000000000811', 'recep@anam.local'),
  ('00000000-0000-0000-0000-000000000812', 'prof@anam.local'),
  ('00000000-0000-0000-0000-000000000813', 'visu@anam.local'),
  ('00000000-0000-0000-0000-000000000814', 'donab@anam.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-00000000081a', 'anam-a', 'Clínica Anamnese A'),
  ('00000000-0000-0000-0000-00000000081b', 'anam-b', 'Clínica Anamnese B');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000000810', '00000000-0000-0000-0000-00000000081a', 'owner'),
  ('00000000-0000-0000-0000-000000000811', '00000000-0000-0000-0000-00000000081a', 'receptionist'),
  ('00000000-0000-0000-0000-000000000812', '00000000-0000-0000-0000-00000000081a', 'professional'),
  ('00000000-0000-0000-0000-000000000813', '00000000-0000-0000-0000-00000000081a', 'viewer'),
  ('00000000-0000-0000-0000-000000000814', '00000000-0000-0000-0000-00000000081b', 'owner');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-000000000815', '00000000-0000-0000-0000-00000000081a', 'Inés Valdés'),
  ('00000000-0000-0000-0000-000000000816', '00000000-0000-0000-0000-00000000081b', 'Cliente da B');
-- A profissional (812) é a Karenn: com o alcance da anamnese (20261114040000) ela preenche as fichas da agenda dela.
insert into public.staff_members (id, org_id, name, user_id) values
  ('00000000-0000-0000-0000-000000000817', '00000000-0000-0000-0000-00000000081a', 'Karenn', '00000000-0000-0000-0000-000000000812'),
  ('00000000-0000-0000-0000-000000000820', '00000000-0000-0000-0000-00000000081b', 'Equipe B', null);
-- Modelo 18: só a parte da cliente. Modelo 19: tem também a ficha profissional.
insert into public.anamnese_templates (id, org_id, title, questions, professional_form) values
  ('00000000-0000-0000-0000-000000000818', '00000000-0000-0000-0000-00000000081a', 'Ficha facial',
   '[{"id":"q1","label":"Alergias?","type":"text"}]'::jsonb, null),
  ('00000000-0000-0000-0000-000000000819', '00000000-0000-0000-0000-00000000081a', 'Ficha de peeling',
   '[{"id":"q1","label":"Gestante?","type":"text"}]'::jsonb, '{"fields":[{"id":"fototipo","label":"Fototipo"}]}'::jsonb),
  ('00000000-0000-0000-0000-000000000821', '00000000-0000-0000-0000-00000000081b', 'Modelo da B',
   '[]'::jsonb, null);
insert into public.services (id, org_id, name, price, duration_minutes, requires_anamnese, anamnese_template_id) values
  ('00000000-0000-0000-0000-00000000081c', '00000000-0000-0000-0000-00000000081a', 'Limpeza facial', 80, 60, true,  '00000000-0000-0000-0000-000000000818'),
  ('00000000-0000-0000-0000-00000000081d', '00000000-0000-0000-0000-00000000081a', 'Peeling',        120, 60, true,  '00000000-0000-0000-0000-000000000819'),
  -- Serviço sem modelo não pode mais ser salvo exigindo ficha (20261029180000); o caso de item
  -- antigo sem modelo é simulado mais abaixo direto no item.
  ('00000000-0000-0000-0000-00000000081e', '00000000-0000-0000-0000-00000000081a', 'Serviço sem modelo', 50, 60, false, null),
  ('00000000-0000-0000-0000-00000000081f', '00000000-0000-0000-0000-00000000081a', 'Massagem',        60, 60, false, null);

create function pg_temp.expect(p_ok boolean, p_msg text) returns void language plpgsql as $$
begin
  if not coalesce(p_ok, false) then raise exception 'FALHOU: %', p_msg; end if;
end $$;
-- Executa o SQL e devolve 'SQLSTATE mensagem' se falhar, ou 'OK'. A falha desfaz só esse comando.
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
-- 20261114100100: o link público passa pelo servidor (chave de serviço); "anon" aqui é a chamada do servidor.
create function pg_temp.anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  perform set_config('role', 'service_role', true);
end $$;
grant execute on function pg_temp.expect(boolean, text), pg_temp.err(text), pg_temp.login(uuid), pg_temp.anon()
  to authenticated, anon, service_role;
create temp table t_ids (k text primary key, id uuid) on commit drop;
create temp table t_tok (k text primary key, tok text) on commit drop;
grant all on t_ids, t_tok to authenticated, anon, service_role;

-- ── Agendamentos (como a dona), cada um num dia para não colidir na agenda ──
select pg_temp.login('00000000-0000-0000-0000-000000000810');
insert into t_ids values
  ('s1', public.create_appointment_atomic('00000000-0000-0000-0000-00000000081a', '00000000-0000-0000-0000-000000000815',
    '00000000-0000-0000-0000-000000000817', '2031-03-03 10:00+00', '2031-03-03 11:00+00', 60, 'Agendado', 'MANUAL', null, null, 80,
    '[{"service_id":"00000000-0000-0000-0000-00000000081c","service_name":"Limpeza facial","price":80}]'::jsonb, false)),
  ('s3', public.create_appointment_atomic('00000000-0000-0000-0000-00000000081a', '00000000-0000-0000-0000-000000000815',
    '00000000-0000-0000-0000-000000000817', '2031-03-04 10:00+00', '2031-03-04 11:00+00', 60, 'Agendado', 'MANUAL', null, null, 120,
    '[{"service_id":"00000000-0000-0000-0000-00000000081d","service_name":"Peeling","price":120}]'::jsonb, false)),
  ('s4', public.create_appointment_atomic('00000000-0000-0000-0000-00000000081a', '00000000-0000-0000-0000-000000000815',
    '00000000-0000-0000-0000-000000000817', '2031-03-05 10:00+00', '2031-03-05 11:00+00', 60, 'Agendado', 'MANUAL', null, null, 80,
    '[{"service_id":"00000000-0000-0000-0000-00000000081c","service_name":"Limpeza facial","price":80}]'::jsonb, false)),
  ('s5', public.create_appointment_atomic('00000000-0000-0000-0000-00000000081a', '00000000-0000-0000-0000-000000000815',
    '00000000-0000-0000-0000-000000000817', '2031-03-06 10:00+00', '2031-03-06 11:00+00', 60, 'Agendado', 'MANUAL', null, null, 50,
    '[{"service_id":"00000000-0000-0000-0000-00000000081e","service_name":"Serviço sem modelo","price":50}]'::jsonb, false)),
  ('s6', public.create_appointment_atomic('00000000-0000-0000-0000-00000000081a', '00000000-0000-0000-0000-000000000815',
    '00000000-0000-0000-0000-000000000817', '2031-03-07 10:00+00', '2031-03-07 11:00+00', 60, 'Agendado', 'MANUAL', null, null, 60,
    '[{"service_id":"00000000-0000-0000-0000-00000000081f","service_name":"Massagem","price":60}]'::jsonb, false));
reset role; select set_config('request.jwt.claims', '', true);
-- Item legado: exige ficha mas ficou sem modelo (cadastro de antes da regra do catálogo).
-- Sem gatilhos: a integridade do item copiaria de novo o cadastro atual do serviço.
set local session_replication_role = replica;
update public.appointment_items set requires_anamnese = true, anamnese_template_id = null
where appointment_id = (select id from t_ids where k = 's5');
set local session_replication_role = origin;

-- Agendamento da org B, criado direto (superusuário), para os testes de isolamento.
insert into public.appointments (id, org_id, client_id, client_name, start_at, end_at, duration_minutes, status) values
  ('00000000-0000-0000-0000-000000000822', '00000000-0000-0000-0000-00000000081b', '00000000-0000-0000-0000-000000000816',
   'Cliente da B', '2031-03-03 10:00+00', '2031-03-03 11:00+00', 60, 'Agendado');

-- ── 1. A ficha nasce sozinha, pendente, com link de 7 dias ──
select pg_temp.expect((select count(*) from public.anamneses where appointment_id = (select id from t_ids where k = 's1')) = 1,
  'serviço que exige ficha cria uma ficha para o atendimento');
select pg_temp.expect((select status = 'pending' and source_service_id = '00000000-0000-0000-0000-00000000081c'
    and public_token is null and token_hash ~ '^[0-9a-f]{64}$' and token_expires_at > now() + interval '6 days' and token_expires_at <= now() + interval '7 days'
  from public.anamneses where appointment_id = (select id from t_ids where k = 's1')),
  'ficha criada pendente, ligada ao serviço e com token de 7 dias');
select pg_temp.expect((select linked_anamnese_id = (select id from public.anamneses where appointment_id = a.id)
  from public.appointments a where a.id = (select id from t_ids where k = 's1')),
  'atendimento guarda o vínculo com a ficha');
-- 20261114100000: o banco guarda só o hash; o teste troca por links conhecidos (o gatilho grava o hash).
insert into t_tok values ('s1', 'tok96s1aaaaaaaaaaaaaaaaaaaaaaaaa'), ('s3', 'tok96s3aaaaaaaaaaaaaaaaaaaaaaaaa'), ('s4', 'tok96s4aaaaaaaaaaaaaaaaaaaaaaaaa');
update public.anamneses a set public_token = t.tok
from t_tok t join t_ids i on i.k = t.k where a.appointment_id = i.id;

-- ── 2. Ficha do cliente pendente: não inicia, não conclui, não cobra ──
select pg_temp.login('00000000-0000-0000-0000-000000000810');
select pg_temp.expect((select string_agg(issue_code, ',') from public.get_appointment_anamnese_gate(
    '00000000-0000-0000-0000-00000000081a', (select id from t_ids where k = 's1'), 'start')) = 'CLIENT_PENDING',
  'gate de início aponta CLIENT_PENDING');
select pg_temp.expect((select string_agg(issue_code, ',') from public.get_appointment_anamnese_gate(
    '00000000-0000-0000-0000-00000000081a', (select id from t_ids where k = 's1'), 'checkout')) = 'CLIENT_PENDING',
  'gate de cobrança aponta CLIENT_PENDING');
select public.set_appointment_status_atomic('00000000-0000-0000-0000-00000000081a', (select id from t_ids where k = 's1'), 'Confirmado');
select pg_temp.expect(pg_temp.err($q$select public.set_appointment_status_atomic('00000000-0000-0000-0000-00000000081a',
    (select id from t_ids where k = 's1'), 'Iniciado')$q$) like 'P0001%ainda nao foi assinada pelo cliente%',
  'RPC de status: Iniciado com ficha pendente falha');
select pg_temp.expect(pg_temp.err($q$update public.appointments set status = 'Iniciado'
    where id = (select id from t_ids where k = 's1')$q$) like 'P0001%ainda nao foi assinada%',
  'UPDATE direto para Iniciado também é barrado pelo gatilho');
-- A cobrança falha inteira: nada de venda, pagamento, caixa, pontos ou saldo.
select pg_temp.expect(pg_temp.err($q$select public.confirm_checkout_atomic('00000000-0000-0000-0000-00000000081a', jsonb_build_object(
    'request_id', '00000000-0000-0000-0000-000000000830', 'appointment_id', (select id from t_ids where k = 's1'), 'mode', 'finalize',
    'items', jsonb_build_array(jsonb_build_object('item_type', 'service', 'item_id', '00000000-0000-0000-0000-00000000081c',
      'name', 'Limpeza facial', 'unit_price', 80, 'quantity', 1)),
    'payments', jsonb_build_array(jsonb_build_object('method', 'CASH', 'amount', 80))))$q$) like 'P0001%ainda nao foi assinada%',
  'cobrar com ficha pendente falha');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select status from public.appointments where id = (select id from t_ids where k = 's1')) = 'Confirmado',
  'atendimento continua Confirmado depois das tentativas barradas');
select pg_temp.expect(not exists (select 1 from public.sales where org_id = '00000000-0000-0000-0000-00000000081a')
  and not exists (select 1 from public.sale_payments where org_id = '00000000-0000-0000-0000-00000000081a')
  and not exists (select 1 from public.transactions where org_id = '00000000-0000-0000-0000-00000000081a')
  and not exists (select 1 from public.checkout_requests where org_id = '00000000-0000-0000-0000-00000000081a'),
  'cobrança barrada não deixa venda, pagamento, caixa nem chave de idempotência');
select pg_temp.expect((select total_spent = 0 and loyalty_points = 0 and balance = 0 from public.clients
  where id = '00000000-0000-0000-0000-000000000815'), 'cliente sem gasto, pontos ou saldo');

-- UPDATE direto para Pago / Pago Parcial (sem RPC) também passa pela trava de cobrança.
select pg_temp.login('00000000-0000-0000-0000-000000000810');
select pg_temp.expect(pg_temp.err($q$update public.appointments set status = 'Pago'
    where id = (select id from t_ids where k = 's4')$q$) like 'P0001%',
  'UPDATE direto para Pago com ficha pendente falha');
select pg_temp.expect(pg_temp.err($q$update public.appointments set status = 'Pago Parcial'
    where id = (select id from t_ids where k = 's4')$q$) like 'P0001%',
  'UPDATE direto para Pago Parcial com ficha pendente falha');
reset role; select set_config('request.jwt.claims', '', true);

-- BUG: a trava de status chama get_appointment_anamnese_gate, que exige papel de membro. Sem usuário
-- no JWT (service_role, rotina agendada, superusuário) qualquer mudança para Iniciado/Pago/Pago Parcial
-- falha com 42501, mesmo em atendimento SEM ficha. Documentado com o comportamento atual; o certo seria
-- a trava pular a checagem de papel quando não há sessão de usuário (ou rodar como security definer).
select pg_temp.expect(pg_temp.err($q$update public.appointments set status = 'Iniciado'
    where id = (select id from t_ids where k = 's6')$q$) like '42501%',
  'BUG (comportamento atual): sem usuário no JWT a mudança de status para Iniciado falha com 42501');

-- ── 3. Link público: leitura antes de assinar ──
select pg_temp.anon();
select pg_temp.expect((select (public.public_anamnese_open(tok, repeat('1', 64), false) ->> 'status') = 'pending'
    and jsonb_array_length(public.public_anamnese_open(tok, repeat('1', 64), false) -> 'questions') = 1
    and (public.public_anamnese_open(tok, repeat('1', 64), false) ->> 'expired')::boolean = false
    and (public.public_anamnese_open(tok, repeat('1', 64), false) ->> 'consent_text') is not null
  from t_tok where k = 's1'), 'ficha pendente mostra perguntas e termo');
select pg_temp.expect(public.public_anamnese_open('0123456789abcdef0123456789abcdef', repeat('1', 64), false) is null, 'token inexistente não devolve nada');
select pg_temp.expect((public.public_anamnese_sign('0123456789abcdef0123456789abcdef', repeat('1', 64), '{}'::jsonb, 'X', 'data:image/png;base64,' || repeat('A', 60), true, 'ua', null) ->> 'error') = 'not_found', 'assinar token inexistente: not_found');
select pg_temp.expect((select public.public_anamnese_sign(tok, repeat('1', 64), '{"q1":"Sem alergias"}'::jsonb, 'Inés Valdés', 'data:image/png;base64,' || repeat('A', 60), false, 'ua', null) ->> 'error' from t_tok where k = 's1') = 'consent_required',
  'sem aceitar o termo não assina');
select pg_temp.expect((select public.public_anamnese_sign(tok, repeat('1', 64), '{"q1":"Sem alergias"}'::jsonb, 'Inés Valdés', 'https://exemplo.com/assinatura.png' || repeat('A', 60), true, 'ua', null) ->> 'error' from t_tok where k = 's1') = 'invalid_payload',
  'assinatura que não é imagem data: é recusada');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select status = 'pending' and signed_at is null from public.anamneses
  where token_hash = encode(extensions.digest((select tok from t_tok where k = 's1'), 'sha256'), 'hex')), 'tentativas inválidas deixam a ficha pendente');

-- ── 4. Assinar: ok uma vez; a segunda falha e não troca as respostas ──
select pg_temp.anon();
select pg_temp.expect((select public.public_anamnese_sign(tok, repeat('1', 64), '{"q1":"Sem alergias","__canal":"link","__termo_principal":"aceito"}'::jsonb, 'Inés Valdés', 'data:image/png;base64,' || repeat('A', 60), true, 'Mozilla/5.0', null) ->> 'ok' from t_tok where k = 's1') = 'true',
  'primeira assinatura funciona');
select pg_temp.expect((select public.public_anamnese_sign(tok, repeat('1', 64), '{"q1":"Mudei de ideia"}'::jsonb, 'Outra Pessoa', 'data:image/png;base64,' || repeat('B', 60), true, 'Outro/1.0', null) ->> 'error' from t_tok where k = 's1') = 'not_found',
  'segunda assinatura devolve not_found (igual a link inexistente)');
-- Depois de assinada o link responde igual a um link inexistente: nada da ficha volta (LGPD/RGPD).
select pg_temp.expect((select public.public_anamnese_open(tok, repeat('1', 64), false) is null
  from t_tok where k = 's1'), 'ficha assinada: o link não devolve nada (igual a inexistente)');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select answers = '{"q1":"Sem alergias","__canal":"link","__termo_principal":"aceito"}'::jsonb and signature_name = 'Inés Valdés'
    and signature_data_url like '%AAAA' and signer_user_agent = 'Mozilla/5.0'
  from public.anamneses where token_hash = encode(extensions.digest((select tok from t_tok where k = 's1'), 'sha256'), 'hex')),
  'a segunda tentativa não altera respostas, assinatura nem navegador');

-- ── 5. Ficha assinada libera o início ──
select pg_temp.login('00000000-0000-0000-0000-000000000810');
select pg_temp.expect((select count(*) from public.get_appointment_anamnese_gate(
    '00000000-0000-0000-0000-00000000081a', (select id from t_ids where k = 's1'), 'checkout')) = 0,
  'gate vazio com a ficha assinada (sem parte profissional)');
select public.set_appointment_status_atomic('00000000-0000-0000-0000-00000000081a', (select id from t_ids where k = 's1'), 'Iniciado');
reset role; select set_config('request.jwt.claims', '', true);

-- Item novo que exige outra ficha, em atendimento já iniciado, é barrado pelo gatilho de item.
select pg_temp.login('00000000-0000-0000-0000-000000000810');
select pg_temp.expect(pg_temp.err($q$insert into public.appointment_items (org_id, appointment_id, type, ref_id, name, price, qty)
    values ('00000000-0000-0000-0000-00000000081a', (select id from t_ids where k = 's1'), 'service',
      '00000000-0000-0000-0000-00000000081d', 'Peeling', 120, 1)$q$) like 'P0001%',
  'item com ficha obrigatória não entra em atendimento iniciado enquanto a ficha nova estiver pendente');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select count(*) from public.anamneses where appointment_id = (select id from t_ids where k = 's1')) = 1,
  'a tentativa barrada não deixou ficha extra');

-- Concluir e cobrar com a ficha assinada funciona e fecha como Pago.
select pg_temp.login('00000000-0000-0000-0000-000000000810');
select public.set_appointment_status_atomic('00000000-0000-0000-0000-00000000081a', (select id from t_ids where k = 's1'), 'Concluído');
select public.confirm_checkout_atomic('00000000-0000-0000-0000-00000000081a', jsonb_build_object(
  'request_id', '00000000-0000-0000-0000-000000000831', 'appointment_id', (select id from t_ids where k = 's1'), 'mode', 'finalize',
  'items', jsonb_build_array(jsonb_build_object('item_type', 'service', 'item_id', '00000000-0000-0000-0000-00000000081c',
    'name', 'Limpeza facial', 'unit_price', 80, 'quantity', 1)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'CASH', 'amount', 80))));
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select status from public.appointments where id = (select id from t_ids where k = 's1')) = 'Pago',
  'com ficha assinada o atendimento é cobrado e fica Pago');

-- ── 6. Ficha profissional pendente: inicia e conclui, mas não cobra ──
select pg_temp.anon();
select public.public_anamnese_sign(tok, repeat('1', 64), '{"q1":"Não","__canal":"link","__termo_principal":"aceito"}'::jsonb, 'Inés Valdés', 'data:image/png;base64,' || repeat('C', 60), true, 'ua', null) from t_tok where k = 's3';
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select requires_professional and professional_completed_at is null from public.anamneses
  where appointment_id = (select id from t_ids where k = 's3')), 'modelo com parte profissional marca requires_professional');

select pg_temp.login('00000000-0000-0000-0000-000000000810');
select pg_temp.expect((select count(*) from public.get_appointment_anamnese_gate(
    '00000000-0000-0000-0000-00000000081a', (select id from t_ids where k = 's3'), 'start')) = 0,
  'a parte profissional não barra o início');
select public.set_appointment_status_atomic('00000000-0000-0000-0000-00000000081a', (select id from t_ids where k = 's3'), 'Iniciado');
select public.set_appointment_status_atomic('00000000-0000-0000-0000-00000000081a', (select id from t_ids where k = 's3'), 'Concluído');
select pg_temp.expect((select string_agg(issue_code, ',') from public.get_appointment_anamnese_gate(
    '00000000-0000-0000-0000-00000000081a', (select id from t_ids where k = 's3'), 'checkout')) = 'PROFESSIONAL_PENDING',
  'gate de cobrança aponta PROFESSIONAL_PENDING');
select pg_temp.expect(pg_temp.err($q$select public.confirm_checkout_atomic('00000000-0000-0000-0000-00000000081a', jsonb_build_object(
    'request_id', '00000000-0000-0000-0000-000000000832', 'appointment_id', (select id from t_ids where k = 's3'), 'mode', 'finalize',
    'items', jsonb_build_array(jsonb_build_object('item_type', 'service', 'item_id', '00000000-0000-0000-0000-00000000081d',
      'name', 'Peeling', 'unit_price', 120, 'quantity', 1)),
    'payments', jsonb_build_array(jsonb_build_object('method', 'CASH', 'amount', 120))))$q$) like 'P0001%ficha profissional%',
  'cobrar com ficha profissional pendente falha');

-- Liberar o fechamento sem a avaliação (spec 12): recepção não pode; motivo obrigatório; libera só o
-- fechamento (a avaliação continua pendente na ficha).
select pg_temp.login('00000000-0000-0000-0000-000000000811');
select pg_temp.expect(pg_temp.err($q$select public.override_anamnese_checkout_gate('00000000-0000-0000-0000-00000000081a',
    (select id from t_ids where k = 's3'), 'Cliente com pressa')$q$) like '42501%', 'recepção não libera o fechamento por padrão');
select pg_temp.login('00000000-0000-0000-0000-000000000810');
select pg_temp.expect(pg_temp.err($q$select public.override_anamnese_checkout_gate('00000000-0000-0000-0000-00000000081a',
    (select id from t_ids where k = 's3'), 'ok')$q$) like '22023%', 'liberar exige motivo');
select pg_temp.expect(public.override_anamnese_checkout_gate('00000000-0000-0000-0000-00000000081a',
    (select id from t_ids where k = 's3'), 'Profissional preenche a avaliação amanhã') = 1, 'dona libera com motivo');
select pg_temp.expect((select count(*) from public.get_appointment_anamnese_gate(
    '00000000-0000-0000-0000-00000000081a', (select id from t_ids where k = 's3'), 'checkout')) = 0,
  'com a liberação, a avaliação pendente não barra a cobrança');
select pg_temp.expect(pg_temp.err($q$select public.override_anamnese_checkout_gate('00000000-0000-0000-0000-00000000081a',
    (select id from t_ids where k = 's4'), 'Motivo qualquer válido')$q$) like 'P0001%', 'sem avaliação pendente não há o que liberar');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select count(*) = 1 from public.audit_logs where operation = 'ANAMNESE_GATE_OVERRIDE'), 'liberação auditada');
select pg_temp.expect((select professional_completed_at is null from public.anamneses
  where appointment_id = (select id from t_ids where k = 's3')), 'a avaliação continua pendente na ficha');
-- Volta ao estado anterior para os próximos passos do teste.
delete from public.anamnese_gate_overrides;
-- A tabela é fechada para a API: o id da ficha do s3 é lido aqui, como superusuário.
insert into t_ids select 'f3', id from public.anamneses where appointment_id = (select id from t_ids where k = 's3');

-- Rascunho da parte profissional (não conclui) continua barrando.
select pg_temp.login('00000000-0000-0000-0000-000000000812');
select public.anamnese_save_professional('00000000-0000-0000-0000-00000000081a',
  (select id from t_ids where k = 'f3'), '{"phototype":"III"}'::jsonb, '{}'::jsonb, '', false);
select pg_temp.login('00000000-0000-0000-0000-000000000810');
select pg_temp.expect((select string_agg(issue_code, ',') from public.get_appointment_anamnese_gate(
    '00000000-0000-0000-0000-00000000081a', (select id from t_ids where k = 's3'), 'checkout')) = 'PROFESSIONAL_PENDING',
  'rascunho da parte profissional ainda barra a cobrança');

-- A profissional conclui a parte dela; depois não edita mais, a recepção não reabre, a dona reabre.
select pg_temp.login('00000000-0000-0000-0000-000000000812');
select public.anamnese_save_professional('00000000-0000-0000-0000-00000000081a',
  (select id from t_ids where k = 'f3'), '{"phototype":"III"}'::jsonb, '{}'::jsonb, '', true);
select pg_temp.expect(pg_temp.err($q$select public.anamnese_save_professional('00000000-0000-0000-0000-00000000081a',
    (select id from t_ids where k = 'f3'), '{"phototype":"IV"}'::jsonb, '{}'::jsonb, '', false)$q$)
    like '23514%', 'parte profissional concluída não aceita edição');
select pg_temp.login('00000000-0000-0000-0000-000000000811');
select pg_temp.expect(pg_temp.err($q$select public.reopen_anamnese_professional_atomic('00000000-0000-0000-0000-00000000081a',
    (select id from t_ids where k = 'f3'))$q$) like '42501%',
  'recepção não reabre a parte profissional');
select pg_temp.login('00000000-0000-0000-0000-000000000810');
select public.reopen_anamnese_professional_atomic('00000000-0000-0000-0000-00000000081a',
  (select id from t_ids where k = 'f3'));
select pg_temp.expect((select count(*) from public.get_appointment_anamnese_gate(
    '00000000-0000-0000-0000-00000000081a', (select id from t_ids where k = 's3'), 'checkout')) = 1,
  'reabrir a parte profissional volta a barrar a cobrança');
select pg_temp.login('00000000-0000-0000-0000-000000000812');
select public.anamnese_save_professional('00000000-0000-0000-0000-00000000081a',
  (select id from t_ids where k = 'f3'), '{"phototype":"III"}'::jsonb, '{}'::jsonb, '', true);
select pg_temp.login('00000000-0000-0000-0000-000000000810');
select public.confirm_checkout_atomic('00000000-0000-0000-0000-00000000081a', jsonb_build_object(
  'request_id', '00000000-0000-0000-0000-000000000833', 'appointment_id', (select id from t_ids where k = 's3'), 'mode', 'finalize',
  'items', jsonb_build_array(jsonb_build_object('item_type', 'service', 'item_id', '00000000-0000-0000-0000-00000000081d',
    'name', 'Peeling', 'unit_price', 120, 'quantity', 1)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'CASH', 'amount', 120))));
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select status from public.appointments where id = (select id from t_ids where k = 's3')) = 'Pago',
  'ficha completa dos dois lados: cobrança passa e fica Pago');

-- ── 7. Link vencido: não assina, não mostra perguntas e continua barrando o atendimento ──
update public.anamneses set token_expires_at = now() - interval '1 minute'
where token_hash = encode(extensions.digest((select tok from t_tok where k = 's4'), 'sha256'), 'hex');
select pg_temp.anon();
select pg_temp.expect((select public.public_anamnese_sign(tok, repeat('1', 64), '{"q1":"x"}'::jsonb, 'Inés Valdés', 'data:image/png;base64,' || repeat('A', 60), true, 'ua', null) ->> 'error' from t_tok where k = 's4') = 'not_found',
  'token vencido: assinatura devolve not_found (igual a link inexistente)');
select pg_temp.expect((select public.public_anamnese_open(tok, repeat('1', 64), false) is null
  from t_tok where k = 's4'), 'token vencido: o link não devolve nada (igual a inexistente)');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select status = 'pending' and signed_at is null and answers = '{}'::jsonb from public.anamneses
  where token_hash = encode(extensions.digest((select tok from t_tok where k = 's4'), 'sha256'), 'hex')), 'token vencido deixa a ficha pendente e vazia');
select pg_temp.login('00000000-0000-0000-0000-000000000810');
select pg_temp.expect(pg_temp.err($q$select public.set_appointment_status_atomic('00000000-0000-0000-0000-00000000081a',
    (select id from t_ids where k = 's4'), 'Iniciado')$q$) like 'P0001%',
  'ficha com link vencido continua barrando o início');
reset role; select set_config('request.jwt.claims', '', true);

-- ── 8. Serviço que exige ficha mas está sem modelo configurado ──
select pg_temp.expect(not exists (select 1 from public.anamneses where appointment_id = (select id from t_ids where k = 's5')),
  'sem modelo, nenhuma ficha é criada');
select pg_temp.login('00000000-0000-0000-0000-000000000810');
select pg_temp.expect((select string_agg(issue_code, ',') from public.get_appointment_anamnese_gate(
    '00000000-0000-0000-0000-00000000081a', (select id from t_ids where k = 's5'), 'start')) = 'MISSING_TEMPLATE_CONFIG',
  'gate aponta MISSING_TEMPLATE_CONFIG');
select pg_temp.expect(pg_temp.err($q$select public.set_appointment_status_atomic('00000000-0000-0000-0000-00000000081a',
    (select id from t_ids where k = 's5'), 'Iniciado')$q$) like 'P0001%nao possui modelo configurado%',
  'serviço sem modelo não inicia');

-- ── 9. Ficha avulsa vinculada ao atendimento também barra; cancelar continua livre ──
select pg_temp.expect((select count(*) from public.get_appointment_anamnese_gate(
    '00000000-0000-0000-0000-00000000081a', (select id from t_ids where k = 's6'), 'start')) = 0,
  'serviço sem exigência: gate vazio');
select pg_temp.login('00000000-0000-0000-0000-000000000811');
insert into t_ids values ('avulsa', (public.create_anamnese_atomic('00000000-0000-0000-0000-00000000081a',
  '00000000-0000-0000-0000-000000000818', null, 'qualquer', (select id from t_ids where k = 's6'))).id);
select pg_temp.expect((public.create_anamnese_atomic('00000000-0000-0000-0000-00000000081a',
  '00000000-0000-0000-0000-000000000818', null, 'qualquer', (select id from t_ids where k = 's6'))).id = (select id from t_ids where k = 'avulsa'),
  'gerar a mesma ficha de novo devolve a existente');
-- A recepção não lê a tabela da ficha (spec 29 §4c): confere pelo status.
select pg_temp.expect((select client_name = 'Inés Valdés' and client_id = '00000000-0000-0000-0000-000000000815' and source_service_id is null
  from public.list_anamnese_status('00000000-0000-0000-0000-00000000081a',
    p_appointment_ids => array[(select id from t_ids where k = 's6')])
  where id = (select id from t_ids where k = 'avulsa')), 'ficha avulsa assume a cliente do atendimento');
select pg_temp.expect((select string_agg(issue_code, ',') from public.get_appointment_anamnese_gate(
    '00000000-0000-0000-0000-00000000081a', (select id from t_ids where k = 's6'), 'start')) = 'CLIENT_PENDING',
  'ficha avulsa pendente barra o início');
select pg_temp.expect(pg_temp.err($q$select public.set_appointment_status_atomic('00000000-0000-0000-0000-00000000081a',
    (select id from t_ids where k = 's6'), 'Iniciado')$q$) like 'P0001%',
  'início barrado por ficha avulsa pendente');
select public.set_appointment_status_atomic('00000000-0000-0000-0000-00000000081a', (select id from t_ids where k = 's6'), 'Cancelado');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select status from public.appointments where id = (select id from t_ids where k = 's6')) = 'Cancelado',
  'cancelar atendimento com ficha pendente continua permitido');

-- Quem gera ficha e quem consulta o gate: papel e organização.
select pg_temp.login('00000000-0000-0000-0000-000000000813');
select pg_temp.expect(pg_temp.err($q$select public.create_anamnese_atomic('00000000-0000-0000-0000-00000000081a',
    '00000000-0000-0000-0000-000000000818', '00000000-0000-0000-0000-000000000815', 'x')$q$) like '42501%',
  'visualizadora não gera ficha');
select pg_temp.expect(pg_temp.err($q$select * from public.get_appointment_anamnese_gate('00000000-0000-0000-0000-00000000081a',
    (select id from t_ids where k = 's1'), 'start')$q$) like '42501%', 'visualizadora não consulta o gate clínico');
select pg_temp.login('00000000-0000-0000-0000-000000000814');
select pg_temp.expect(pg_temp.err($q$select * from public.get_appointment_anamnese_gate('00000000-0000-0000-0000-00000000081a',
    (select id from t_ids where k = 's1'), 'start')$q$) like '42501%', 'dona de outra clínica não consulta o gate');
select pg_temp.expect(pg_temp.err($q$select public.create_anamnese_atomic('00000000-0000-0000-0000-00000000081b',
    '00000000-0000-0000-0000-000000000821', null, 'x', (select id from t_ids where k = 's1'))$q$) like 'P0002%',
  'atendimento de outra clínica não recebe ficha');
select pg_temp.login('00000000-0000-0000-0000-000000000810');
select pg_temp.expect(pg_temp.err($q$select public.create_anamnese_atomic('00000000-0000-0000-0000-00000000081a',
    '00000000-0000-0000-0000-000000000821', '00000000-0000-0000-0000-000000000815', 'x')$q$) like 'P0002%',
  'modelo de outra clínica não é aceito');
select pg_temp.expect(pg_temp.err($q$select public.create_anamnese_atomic('00000000-0000-0000-0000-00000000081a',
    '00000000-0000-0000-0000-000000000818', null, 'x', '00000000-0000-0000-0000-000000000822')$q$) like 'P0002%',
  'atendimento da org B não é aceito na org A');
select pg_temp.expect(pg_temp.err($q$select * from public.get_appointment_anamnese_gate('00000000-0000-0000-0000-00000000081a',
    (select id from t_ids where k = 's1'), 'depois')$q$) like '22023%', 'etapa inválida do gate é recusada');
select pg_temp.expect(pg_temp.err($q$select * from public.get_appointment_anamnese_gate('00000000-0000-0000-0000-00000000081a',
    '00000000-0000-0000-0000-000000000822', 'start')$q$) like 'P0002%', 'gate não enxerga atendimento de outra clínica');
reset role; select set_config('request.jwt.claims', '', true);

-- ── 10. Ficha assinada é imutável (protect_signed_anamnese_evidence) ──
-- Pela API, nem a dona altera ou apaga a linha direto (tabela fechada; só funções).
select pg_temp.login('00000000-0000-0000-0000-000000000810');
select pg_temp.expect(pg_temp.err($q$update public.anamneses set professional_notes = 'x' where token_hash = encode(extensions.digest((select tok from t_tok where k = 's1'), 'sha256'), 'hex')$q$) like '42501%',
  'API: dona não altera a ficha direto');
select pg_temp.expect(pg_temp.err($q$delete from public.anamneses where token_hash = encode(extensions.digest((select tok from t_tok where k = 's1'), 'sha256'), 'hex')$q$) like '42501%',
  'API: dona não apaga a ficha direto');
reset role; select set_config('request.jwt.claims', '', true);
-- Mesmo sem a trava da API (superusuário), o gatilho segura cada campo da evidência.
select pg_temp.expect(pg_temp.err(format($q$update public.anamneses set %s where token_hash = encode(extensions.digest((select tok from t_tok where k = 's1'), 'sha256'), 'hex')$q$, c)) like '23514%imutaveis%',
  'ficha assinada recusa: ' || c)
from unnest(array[
  $c$answers = '{"q1":"adulterada"}'::jsonb$c$,
  $c$status = 'pending'$c$,
  $c$signature_name = 'Outra Pessoa'$c$,
  $c$signature_data_url = 'data:image/png;base64,ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ'$c$,
  $c$consent_text = 'texto trocado'$c$,
  $c$consent_accepted = false$c$,
  $c$client_name = 'Outro Nome'$c$,
  $c$signed_at = now() - interval '10 days'$c$,
  $c$signer_user_agent = 'forjado'$c$,
  $c$template_snapshot = '{}'::jsonb$c$,
  $c$public_token = 'novo-token-0123456789abcdef012345'$c$,
  $c$token_expires_at = now() + interval '30 days'$c$
]) as c;
-- Campos clínicos da profissional e updated_at continuam editáveis.
select pg_temp.expect(pg_temp.err($q$update public.anamneses set professional_notes = 'Pele sensível', updated_at = now()
    where token_hash = encode(extensions.digest((select tok from t_tok where k = 's1'), 'sha256'), 'hex')$q$) = 'OK', 'ficha assinada aceita nota profissional');
-- Superusuário passa da RLS, mas o gatilho segura.
select pg_temp.expect(pg_temp.err($q$delete from public.anamneses where token_hash = encode(extensions.digest((select tok from t_tok where k = 's1'), 'sha256'), 'hex')$q$)
    like '23514%nao podem ser excluidas%', 'gatilho: ficha assinada não é excluída nem por superusuário');
select pg_temp.expect(pg_temp.err($q$update public.anamneses set answers = '{}'::jsonb where token_hash = encode(extensions.digest((select tok from t_tok where k = 's1'), 'sha256'), 'hex')$q$)
    like '23514%', 'gatilho: ficha assinada não é alterada nem por superusuário');
select pg_temp.expect((select answers = '{"q1":"Sem alergias","__canal":"link","__termo_principal":"aceito"}'::jsonb and status = 'signed' and professional_notes = 'Pele sensível'
  from public.anamneses where token_hash = encode(extensions.digest((select tok from t_tok where k = 's1'), 'sha256'), 'hex')),
  'evidência continua intacta; só a nota profissional mudou');
-- Ficha pendente pode ser apagada, e a exclusão fica no audit log.
select pg_temp.expect(pg_temp.err($q$delete from public.anamneses where token_hash = encode(extensions.digest((select tok from t_tok where k = 's4'), 'sha256'), 'hex')$q$) = 'OK',
  'ficha pendente pode ser excluída');
select pg_temp.expect(exists (select 1 from public.audit_logs where org_id = '00000000-0000-0000-0000-00000000081a'
  and operation = 'ANAMNESE_PENDING_DELETED' and old_data ->> 'status' = 'pending'), 'exclusão da pendente vai para o audit log');

rollback;
\o
\echo 'trava clínica da anamnese: ok'
