-- Clientes (20261030300000): cidade/estado, consentimento de imagem, mesclagem atômica e auditoria
-- da exportação. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000a701', 'dona@teste.local'),
  ('00000000-0000-0000-0000-00000000a702', 'recepcao@teste.local'),
  ('00000000-0000-0000-0000-00000000a703', 'visual@teste.local'),
  ('00000000-0000-0000-0000-00000000a704', 'outra@teste.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-00000000a70a', 'mescla-a', 'Estúdio A'),
  ('00000000-0000-0000-0000-00000000a70b', 'mescla-b', 'Estúdio B');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-00000000a701', '00000000-0000-0000-0000-00000000a70a', 'owner'),
  ('00000000-0000-0000-0000-00000000a702', '00000000-0000-0000-0000-00000000a70a', 'receptionist'),
  ('00000000-0000-0000-0000-00000000a703', '00000000-0000-0000-0000-00000000a70a', 'viewer'),
  ('00000000-0000-0000-0000-00000000a704', '00000000-0000-0000-0000-00000000a70b', 'owner');

-- K = cadastro que fica; M = duplicada; K2 = outra cliente; X = cliente de outro estúdio.
insert into public.clients (id, org_id, full_name, phone, tags, alert_type, alert_text, balance, total_spent, loyalty_points, last_visit, image_use_consent, city) values
  ('00000000-0000-0000-0000-00000000a7c1', '00000000-0000-0000-0000-00000000a70a', 'Marina Costa', null, array['VIP'], 'note', 'Prefere manhã', 20, 100, 100, '2035-01-10', false, 'Málaga'),
  ('00000000-0000-0000-0000-00000000a7c2', '00000000-0000-0000-0000-00000000a70a', 'Marina Costa Dias', '+34 600 111 222', array['Recorrente', 'VIP'], 'allergy', 'Látex', 30, 50, 60, '2035-03-05', true, null),
  ('00000000-0000-0000-0000-00000000a7c3', '00000000-0000-0000-0000-00000000a70a', 'Outra Cliente', null, '{}', 'none', null, 0, 0, 0, null, false, null),
  ('00000000-0000-0000-0000-00000000a7c4', '00000000-0000-0000-0000-00000000a70b', 'Cliente do B', null, '{}', 'none', null, 0, 0, 0, null, false, null);

insert into public.services (id, org_id, name, price, duration_minutes) values
  ('00000000-0000-0000-0000-00000000a7d1', '00000000-0000-0000-0000-00000000a70a', 'Limpeza', 50, 60);
insert into public.appointments (id, org_id, client_id, client_name, start_at, end_at, duration_minutes, total, status) values
  ('00000000-0000-0000-0000-00000000a7e1', '00000000-0000-0000-0000-00000000a70a', '00000000-0000-0000-0000-00000000a7c2', 'Marina Costa Dias',
   '2035-03-05 10:00+00', '2035-03-05 11:00+00', 60, 50, 'Agendado'),
  ('00000000-0000-0000-0000-00000000a7e2', '00000000-0000-0000-0000-00000000a70a', '00000000-0000-0000-0000-00000000a7c1', 'Marina Costa',
   '2035-04-05 10:00+00', '2035-04-05 11:00+00', 60, 50, 'Agendado');
update public.appointments set status = 'Concluído' where id = '00000000-0000-0000-0000-00000000a7e1';
insert into public.client_notes (id, org_id, client_id, appointment_id, author_name, content, note_type) values
  ('00000000-0000-0000-0000-00000000a7f1', '00000000-0000-0000-0000-00000000a70a', '00000000-0000-0000-0000-00000000a7c2', '00000000-0000-0000-0000-00000000a7e1', 'Ana', 'Nota do atendimento', 'appointment'),
  ('00000000-0000-0000-0000-00000000a7f2', '00000000-0000-0000-0000-00000000a70a', '00000000-0000-0000-0000-00000000a7c2', null, 'Ana', 'Nota geral', 'general');
insert into public.anamneses (id, org_id, client_id, client_name, appointment_id, template_title, template_snapshot, answers,
  consent_text, status, public_token, token_expires_at, signature_name, signature_data_url, signed_at) values
  ('00000000-0000-0000-0000-00000000a7a1', '00000000-0000-0000-0000-00000000a70a', '00000000-0000-0000-0000-00000000a7c2', 'Marina Costa Dias',
   '00000000-0000-0000-0000-00000000a7e1', 'Ficha', '{"questions":[{"id":"q1","label":"Alergias?"}]}', '{"q1":"Látex"}',
   'Consinto', 'signed', 'tok_merge_signed_00000000000000000', now() + interval '1 day', 'Marina', 'data:image/png;base64,AAAA', now()),
  ('00000000-0000-0000-0000-00000000a7a2', '00000000-0000-0000-0000-00000000a70a', '00000000-0000-0000-0000-00000000a7c2', 'Marina Costa Dias',
   null, 'Ficha', '{"questions":[]}', '{}',
   'Consinto', 'pending', 'tok_merge_pending_0000000000000000', now() + interval '1 day', null, null, null);
insert into public.client_balance_entries (id, org_id, client_id, entry_type, amount, balance_before, balance_after, source_type, created_at) values
  ('00000000-0000-0000-0000-00000000a781', '00000000-0000-0000-0000-00000000a70a', '00000000-0000-0000-0000-00000000a7c1', 'manual_credit', 20, 0, 20, 'manual_adjustment', '2035-01-01 09:00+00'),
  ('00000000-0000-0000-0000-00000000a782', '00000000-0000-0000-0000-00000000a70a', '00000000-0000-0000-0000-00000000a7c2', 'manual_credit', 30, 0, 30, 'manual_adjustment', '2035-02-01 09:00+00');
insert into public.loyalty_point_entries (id, org_id, client_id, entry_type, points, balance_before, balance_after, source_type, created_at) values
  ('00000000-0000-0000-0000-00000000a791', '00000000-0000-0000-0000-00000000a70a', '00000000-0000-0000-0000-00000000a7c1', 'earn', 100, 0, 100, 'manual', '2035-01-01 09:00+00'),
  ('00000000-0000-0000-0000-00000000a792', '00000000-0000-0000-0000-00000000a70a', '00000000-0000-0000-0000-00000000a7c2', 'earn', 60, 0, 60, 'manual', '2035-02-01 09:00+00');
insert into public.client_entitlements (id, org_id, client_id, package_name, total_sessions) values
  ('00000000-0000-0000-0000-00000000a7b1', '00000000-0000-0000-0000-00000000a70a', '00000000-0000-0000-0000-00000000a7c2', 'Pacote Shadow', 3);
insert into public.client_entitlement_entries (org_id, entitlement_id, client_id, action, sessions_delta, sessions_before, sessions_after) values
  ('00000000-0000-0000-0000-00000000a70a', '00000000-0000-0000-0000-00000000a7b1', '00000000-0000-0000-0000-00000000a7c2', 'consume', -1, 3, 2);
insert into public.client_marketing_preferences (org_id, client_id, channel, marketing_allowed) values
  ('00000000-0000-0000-0000-00000000a70a', '00000000-0000-0000-0000-00000000a7c1', 'whatsapp_manual', true),
  ('00000000-0000-0000-0000-00000000a70a', '00000000-0000-0000-0000-00000000a7c2', 'whatsapp_manual', false),
  ('00000000-0000-0000-0000-00000000a70a', '00000000-0000-0000-0000-00000000a7c2', 'email_provider', true);
-- Item já cancelado (histórico): a guarda da fila não deixa criar rascunho para quem recusou o meio (teste 155).
insert into public.marketing_message_queue (org_id, client_id, channel, recipient, message_body, status) values
  ('00000000-0000-0000-0000-00000000a70a', '00000000-0000-0000-0000-00000000a7c2', 'whatsapp_manual', '+34600111222', 'Olá', 'cancelled');
insert into public.sales (id, org_id, client_id, client_name) values
  ('00000000-0000-0000-0000-00000000a7aa', '00000000-0000-0000-0000-00000000a70a', '00000000-0000-0000-0000-00000000a7c2', 'Marina Costa Dias');
insert into public.transactions (id, org_id, client_id, client_name, type, description, value, date) values
  ('00000000-0000-0000-0000-00000000a7ab', '00000000-0000-0000-0000-00000000a70a', '00000000-0000-0000-0000-00000000a7c2', 'Marina Costa Dias', 'income', 'Venda', 50, '2035-03-05');

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

-- 1. Permissão e entradas inválidas.
select pg_temp.login('00000000-0000-0000-0000-00000000a703');
select pg_temp.expect(pg_temp.state_of($q$select public.merge_clients_atomic('00000000-0000-0000-0000-00000000a70a', '00000000-0000-0000-0000-00000000a7c1', '00000000-0000-0000-0000-00000000a7c2')$q$) = '42501',
  'quem só visualiza não mescla');
select pg_temp.login('00000000-0000-0000-0000-00000000a704');
select pg_temp.expect(pg_temp.state_of($q$select public.merge_clients_atomic('00000000-0000-0000-0000-00000000a70a', '00000000-0000-0000-0000-00000000a7c1', '00000000-0000-0000-0000-00000000a7c2')$q$) = '42501',
  'dona de outro estúdio não mescla aqui');
select pg_temp.login('00000000-0000-0000-0000-00000000a701');
select pg_temp.expect(pg_temp.state_of($q$select public.merge_clients_atomic('00000000-0000-0000-0000-00000000a70a', '00000000-0000-0000-0000-00000000a7c1', '00000000-0000-0000-0000-00000000a7c1')$q$) = '22023',
  'não mescla a cliente com ela mesma');
select pg_temp.expect(pg_temp.state_of($q$select public.merge_clients_atomic('00000000-0000-0000-0000-00000000a70a', '00000000-0000-0000-0000-00000000a7c1', '00000000-0000-0000-0000-00000000a7c4')$q$) = 'P0002',
  'cliente de outro estúdio não entra na mesclagem');

-- 2. Mesclagem: a recepção também mescla (clientes.manage); aqui a dona.
select pg_temp.expect((public.merge_clients_atomic('00000000-0000-0000-0000-00000000a70a', '00000000-0000-0000-0000-00000000a7c1', '00000000-0000-0000-0000-00000000a7c2') ->> 'already_merged')::boolean = false,
  'primeira mesclagem executa');
reset role; select set_config('request.jwt.claims', '', true);

select pg_temp.expect((select count(*) = 2 from public.appointments where client_id = '00000000-0000-0000-0000-00000000a7c1'), 'atendimentos movidos');
select pg_temp.expect((select client_name = 'Marina Costa' from public.appointments where id = '00000000-0000-0000-0000-00000000a7e1'), 'nome do atendimento acompanha');
select pg_temp.expect((select count(*) = 2 from public.client_notes where client_id = '00000000-0000-0000-0000-00000000a7c1'), 'notas movidas (com e sem atendimento)');
select pg_temp.expect((select count(*) = 2 from public.anamneses where client_id = '00000000-0000-0000-0000-00000000a7c1'), 'fichas movidas, inclusive a assinada');
select pg_temp.expect((select answers = '{"q1":"Látex"}'::jsonb and signature_name = 'Marina' and client_name = 'Marina Costa Dias' from public.anamneses where id = '00000000-0000-0000-0000-00000000a7a1'),
  'evidência da ficha assinada intacta');
select pg_temp.expect((select client_id = '00000000-0000-0000-0000-00000000a7c1' from public.sales where id = '00000000-0000-0000-0000-00000000a7aa'), 'venda movida');
select pg_temp.expect((select client_id = '00000000-0000-0000-0000-00000000a7c1' from public.transactions where id = '00000000-0000-0000-0000-00000000a7ab'), 'lançamento movido');
select pg_temp.expect((select client_id = '00000000-0000-0000-0000-00000000a7c1' from public.client_entitlements where id = '00000000-0000-0000-0000-00000000a7b1'), 'pacote movido');
select pg_temp.expect((select count(*) = 1 from public.client_entitlement_entries where client_id = '00000000-0000-0000-0000-00000000a7c1'), 'extrato do pacote movido');
select pg_temp.expect((select count(*) = 1 from public.marketing_message_queue where client_id = '00000000-0000-0000-0000-00000000a7c1'), 'mensagens movidas');
select pg_temp.expect((select count(*) = 0 from public.client_balance_entries where client_id = '00000000-0000-0000-0000-00000000a7c2')
  and (select count(*) = 2 from public.client_balance_entries where client_id = '00000000-0000-0000-0000-00000000a7c1'), 'extrato de saldo movido');

-- Saldo e pontos somados; extrato continua fechando em ordem de data.
select pg_temp.expect((select balance = 50 and total_spent = 150 and loyalty_points = 160 and last_visit = '2035-03-05' from public.clients where id = '00000000-0000-0000-0000-00000000a7c1'),
  'saldo, total gasto, pontos e última visita somados');
select pg_temp.expect((select balance_before = 20 and balance_after = 50 from public.client_balance_entries where id = '00000000-0000-0000-0000-00000000a782')
  and (select balance_before = 0 and balance_after = 20 from public.client_balance_entries where id = '00000000-0000-0000-0000-00000000a781'), 'sequência do saldo refeita');
select pg_temp.expect((select balance_before = 100 and balance_after = 160 from public.loyalty_point_entries where id = '00000000-0000-0000-0000-00000000a792'), 'sequência dos pontos refeita');

-- Etiquetas e alertas unidos; vazio preenchido; consentimento só se os dois deram.
select pg_temp.expect((select tags = array['Recorrente', 'VIP'] and alert_type = 'allergy' and alert_text = 'Prefere manhã · Látex'
  and phone = '+34 600 111 222' and city = 'Málaga' and image_use_consent = false from public.clients where id = '00000000-0000-0000-0000-00000000a7c1'),
  'etiquetas, alerta, telefone, cidade e consentimento');
select pg_temp.expect((select marketing_allowed = false from public.client_marketing_preferences where client_id = '00000000-0000-0000-0000-00000000a7c1' and channel = 'whatsapp_manual')
  and (select marketing_allowed from public.client_marketing_preferences where client_id = '00000000-0000-0000-0000-00000000a7c1' and channel = 'email_provider')
  and (select count(*) = 0 from public.client_marketing_preferences where client_id = '00000000-0000-0000-0000-00000000a7c2'), 'preferências: a recusa vale');

-- Duplicada arquivada e referenciada.
select pg_temp.expect((select status = 'Inativo' and merged_into = '00000000-0000-0000-0000-00000000a7c1' and merged_at is not null and merged_by = '00000000-0000-0000-0000-00000000a701'
  and balance = 0 and total_spent = 0 and loyalty_points = 0 from public.clients where id = '00000000-0000-0000-0000-00000000a7c2'), 'duplicada arquivada, zerada e com referência');

-- Auditoria.
select pg_temp.expect((select count(*) = 1 and bool_and((new_data -> 'moved' ->> 'appointments')::int = 1 and old_data ->> 'merged_id' = '00000000-0000-0000-0000-00000000a7c2')
  from public.audit_logs where operation = 'CLIENT_MERGED' and record_id = '00000000-0000-0000-0000-00000000a7c1' and user_id = '00000000-0000-0000-0000-00000000a701'),
  'auditoria da mesclagem');

-- 3. Idempotência e conflitos.
select pg_temp.login('00000000-0000-0000-0000-00000000a702');
select pg_temp.expect((public.merge_clients_atomic('00000000-0000-0000-0000-00000000a70a', '00000000-0000-0000-0000-00000000a7c1', '00000000-0000-0000-0000-00000000a7c2') ->> 'already_merged')::boolean = true,
  'repetir a mesclagem não faz nada (recepção também pode)');
select pg_temp.expect(pg_temp.state_of($q$select public.merge_clients_atomic('00000000-0000-0000-0000-00000000a70a', '00000000-0000-0000-0000-00000000a7c3', '00000000-0000-0000-0000-00000000a7c2')$q$) = 'P0001',
  'duplicada já mesclada não vai para outro cadastro');
select pg_temp.expect(pg_temp.state_of($q$select public.merge_clients_atomic('00000000-0000-0000-0000-00000000a70a', '00000000-0000-0000-0000-00000000a7c2', '00000000-0000-0000-0000-00000000a7c3')$q$) = 'P0001',
  'cadastro mesclado não pode ser o que fica');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select count(*) = 1 from public.audit_logs where operation = 'CLIENT_MERGED'), 'a repetição não duplica a auditoria');

-- 4. A API não mexe em "mesclada em" nem no que a ficha assinada guarda.
select pg_temp.login('00000000-0000-0000-0000-00000000a701');
select pg_temp.expect(pg_temp.state_of($q$update public.clients set merged_into = '00000000-0000-0000-0000-00000000a7c1' where id = '00000000-0000-0000-0000-00000000a7c3'$q$) = '42501',
  'merged_into não se edita pela API');
select pg_temp.expect(pg_temp.state_of($q$update public.anamneses set client_id = '00000000-0000-0000-0000-00000000a7c3' where id = '00000000-0000-0000-0000-00000000a7a1'$q$) = '42501',
  'ficha não se altera pela API (tabela fechada, 20261114040000)');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect(pg_temp.state_of($q$update public.anamneses set client_id = '00000000-0000-0000-0000-00000000a7c3' where id = '00000000-0000-0000-0000-00000000a7a1'$q$) = '23514',
  'ficha assinada não troca de cliente fora da mesclagem (gatilho)');

-- 5. Cidade, estado e consentimento de imagem: quem e quando vêm do banco.
select pg_temp.login('00000000-0000-0000-0000-00000000a702');
update public.clients set city = 'Benalmádena', state_region = 'Málaga' where id = '00000000-0000-0000-0000-00000000a7c3';
select pg_temp.expect(pg_temp.state_of($q$update public.clients set city = '   ' where id = '00000000-0000-0000-0000-00000000a7c3'$q$) = '23514', 'cidade em branco recusada');
update public.clients set image_use_consent = true, image_use_consent_at = '2000-01-01', image_use_consent_by = '00000000-0000-0000-0000-00000000a701'
 where id = '00000000-0000-0000-0000-00000000a7c3';
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select city = 'Benalmádena' and state_region = 'Málaga' and image_use_consent
  and image_use_consent_by = '00000000-0000-0000-0000-00000000a702' and image_use_consent_at > now() - interval '1 minute'
  from public.clients where id = '00000000-0000-0000-0000-00000000a7c3'), 'consentimento carimbado com quem e quando, não com o que o app mandou');
select pg_temp.expect((select count(*) = 1 from public.audit_logs where operation = 'IMAGE_CONSENT_GRANTED' and record_id = '00000000-0000-0000-0000-00000000a7c3'
  and user_id = '00000000-0000-0000-0000-00000000a702'), 'auditoria do consentimento concedido');

select pg_temp.login('00000000-0000-0000-0000-00000000a702');
update public.clients set notes = 'x', image_use_consent_at = '2000-01-01' where id = '00000000-0000-0000-0000-00000000a7c3';
update public.clients set image_use_consent = false where id = '00000000-0000-0000-0000-00000000a7c3';
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select not image_use_consent and image_use_consent_at > now() - interval '1 minute' from public.clients where id = '00000000-0000-0000-0000-00000000a7c3'),
  'editar outro campo não mexe no carimbo; revogar carimba de novo');
select pg_temp.expect((select count(*) = 1 from public.audit_logs where operation = 'IMAGE_CONSENT_REVOKED' and record_id = '00000000-0000-0000-0000-00000000a7c3'), 'auditoria do consentimento revogado');

select pg_temp.login('00000000-0000-0000-0000-00000000a703');
update public.clients set image_use_consent = true where id = '00000000-0000-0000-0000-00000000a7c3';
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select not image_use_consent from public.clients where id = '00000000-0000-0000-0000-00000000a7c3'), 'quem só visualiza não concede consentimento');

-- Cadastro novo já com consentimento também carimba.
select pg_temp.login('00000000-0000-0000-0000-00000000a702');
insert into public.clients (id, org_id, full_name, image_use_consent) values
  ('00000000-0000-0000-0000-00000000a7c5', '00000000-0000-0000-0000-00000000a70a', 'Cliente Nova', true);
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select image_use_consent_by = '00000000-0000-0000-0000-00000000a702' and image_use_consent_at is not null from public.clients where id = '00000000-0000-0000-0000-00000000a7c5'),
  'consentimento no cadastro novo carimbado');

-- 6. Exportação deixa rastro com quem, quando e quantas.
select pg_temp.login('00000000-0000-0000-0000-00000000a703');
select public.log_clients_export('00000000-0000-0000-0000-00000000a70a', 42, '{"visao":"todos"}'::jsonb);
select pg_temp.expect(pg_temp.state_of($q$select public.log_clients_export('00000000-0000-0000-0000-00000000a70a', -1)$q$) = '22023', 'quantidade negativa recusada');
select pg_temp.login('00000000-0000-0000-0000-00000000a704');
select pg_temp.expect(pg_temp.state_of($q$select public.log_clients_export('00000000-0000-0000-0000-00000000a70a', 1)$q$) = '42501', 'outro estúdio não registra exportação aqui');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select count(*) = 1 and bool_and((new_data ->> 'count')::int = 42 and user_id = '00000000-0000-0000-0000-00000000a703' and created_at > now() - interval '1 minute')
  from public.audit_logs where operation = 'CLIENTS_EXPORTED' and org_id = '00000000-0000-0000-0000-00000000a70a'), 'auditoria da exportação');

rollback;
\o
\echo 'mesclagem atômica, cidade, consentimento de imagem e exportação: ok'
