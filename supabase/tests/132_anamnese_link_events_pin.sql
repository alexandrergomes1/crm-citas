-- Anamnese: validade do link, envio/abertura, assinatura validada no banco, versão do modelo e PIN do modo estúdio.
-- Desfaz tudo no fim. Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000ca1', 'dono-c@teste.local'),
  ('00000000-0000-0000-0000-000000000ca2', 'recep-c@teste.local'),
  ('00000000-0000-0000-0000-000000000ca3', 'visu-c@teste.local'),
  ('00000000-0000-0000-0000-000000000ca4', 'dono-d@teste.local');
insert into public.organizations (id, slug, name, address, city, timezone) values
  ('00000000-0000-0000-0000-000000000caa', 'link-a', 'Estúdio A', 'Calle Mayor 1', 'Madrid', 'Europe/Madrid'),
  ('00000000-0000-0000-0000-000000000cab', 'link-b', 'Estúdio B', null, null, 'Europe/Madrid');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000000ca1', '00000000-0000-0000-0000-000000000caa', 'owner'),
  ('00000000-0000-0000-0000-000000000ca2', '00000000-0000-0000-0000-000000000caa', 'receptionist'),
  ('00000000-0000-0000-0000-000000000ca3', '00000000-0000-0000-0000-000000000caa', 'viewer'),
  ('00000000-0000-0000-0000-000000000ca4', '00000000-0000-0000-0000-000000000cab', 'owner');
insert into public.profiles (user_id, org_id, full_name) values
  ('00000000-0000-0000-0000-000000000ca2', '00000000-0000-0000-0000-000000000caa', 'Marta Gómez')
on conflict do nothing;
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-000000000cc1', '00000000-0000-0000-0000-000000000caa', 'Carmen Ruiz');
insert into public.appointments (id, org_id, client_id, client_name, start_at, end_at, duration_minutes, status) values
  ('00000000-0000-0000-0000-000000000cc2', '00000000-0000-0000-0000-000000000caa', '00000000-0000-0000-0000-000000000cc1',
   'Carmen Ruiz', '2031-05-06 10:30+00', '2031-05-06 11:30+00', 60, 'Agendado');
insert into public.appointment_items (org_id, appointment_id, type, name, price, qty) values
  ('00000000-0000-0000-0000-000000000caa', '00000000-0000-0000-0000-000000000cc2', 'service', 'Aquarele Lips', 120, 1);
insert into public.anamnese_templates (id, org_id, title, questions, consent_text, consent_version, country) values
  ('00000000-0000-0000-0000-000000000cc3', '00000000-0000-0000-0000-000000000caa', 'Ficha labial',
   '[{"id":"q1","type":"yes_no","text":"Alergias?","required":true,"explainWhenAnswer":"Sí"},
     {"id":"q2","type":"text","text":"Observações","required":false},
     {"id":"t1","type":"consent","text":"Imagem","required":false},
     {"id":"t2","type":"consent","text":"Procedimento","required":true}]'::jsonb,
   'Consinto o tratamento dos dados.', 'lgpd-v1', 'PT');

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
-- 20261114100100: o link público passa pelo servidor (chave de serviço); "anon" aqui é a chamada do servidor.
create function pg_temp.anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('role', 'service_role', true);
end $$;
grant execute on function pg_temp.expect(boolean, text), pg_temp.state_of(text), pg_temp.login(uuid), pg_temp.anon() to anon, authenticated, service_role;
create temp table t_ids (k text primary key, id uuid, tok text) on commit drop;
grant all on t_ids to anon, authenticated, service_role;

-- ── 1. Versão e país do modelo ──────────────────────────────────────────────────────────────
select pg_temp.expect((select version = 1 and country = 'PT' from public.anamnese_templates where id = '00000000-0000-0000-0000-000000000cc3'),
  'modelo nasce na versão 1 com o país informado');
update public.anamnese_templates set is_active = false where id = '00000000-0000-0000-0000-000000000cc3';
update public.anamnese_templates set is_active = true where id = '00000000-0000-0000-0000-000000000cc3';
select pg_temp.expect((select version = 1 from public.anamnese_templates where id = '00000000-0000-0000-0000-000000000cc3'),
  'ativar e desativar não muda a versão');

-- ── 2. Validade padrão do estúdio e ficha nova ───────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000000ca2');
select pg_temp.expect(pg_temp.state_of($q$select public.set_anamnese_settings('00000000-0000-0000-0000-000000000caa', 15, true)$q$) = '42501',
  'recepção não altera a validade padrão');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.login('00000000-0000-0000-0000-000000000ca1');
select pg_temp.expect(pg_temp.state_of($q$select public.set_anamnese_settings('00000000-0000-0000-0000-000000000caa', 5, true)$q$) = '22023',
  'validade fora da lista é recusada');
select public.set_anamnese_settings('00000000-0000-0000-0000-000000000caa', 15, true);
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select settings #>> '{anamnese,link_days}' = '15' and (settings #>> '{anamnese,studio_mode}')::boolean
  from public.organizations where id = '00000000-0000-0000-0000-000000000caa'), 'validade padrão gravada nos ajustes');

select pg_temp.login('00000000-0000-0000-0000-000000000ca2');
insert into t_ids (k, id) values ('f1', (public.create_anamnese_atomic('00000000-0000-0000-0000-000000000caa',
  '00000000-0000-0000-0000-000000000cc3', null, 'x', '00000000-0000-0000-0000-000000000cc2')).id);
reset role; select set_config('request.jwt.claims', '', true);
-- 20261114100000: o banco guarda só o hash; o teste troca por um link conhecido (o gatilho grava o hash).
update t_ids set tok = 'tok132f1aaaaaaaaaaaaaaaaaaaaaaaa' where k = 'f1';
update public.anamneses set public_token = 'tok132f1aaaaaaaaaaaaaaaaaaaaaaaa' where id = (select id from t_ids where k = 'f1');
select pg_temp.expect((select token_expires_at > now() + interval '14 days' and token_expires_at <= now() + interval '15 days'
  from public.anamneses where id = (select id from t_ids where k = 'f1')), 'ficha nova usa a validade padrão de 15 dias');
select pg_temp.expect((select template_snapshot ->> 'template_version' = '1' and template_snapshot ->> 'template_country' = 'PT'
  from public.anamneses where id = (select id from t_ids where k = 'f1')), 'snapshot guarda versão e país do modelo');

-- Editar o modelo sobe a versão e não mexe na ficha já enviada.
update public.anamnese_templates set questions = questions || '[{"id":"q3","type":"text","text":"Nova","required":false}]'::jsonb
where id = '00000000-0000-0000-0000-000000000cc3';
select pg_temp.expect((select version = 2 from public.anamnese_templates where id = '00000000-0000-0000-0000-000000000cc3'),
  'editar o conteúdo sobe a versão do modelo');
select pg_temp.expect((select template_snapshot ->> 'template_version' = '1' and jsonb_array_length(template_snapshot -> 'questions') = 4
  from public.anamneses where id = (select id from t_ids where k = 'f1')), 'ficha enviada continua na versão 1 com as 4 perguntas');

-- ── 3. Validade escolhida na hora do envio ───────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000000ca2');
select pg_temp.expect(pg_temp.state_of(format($q$select public.set_anamnese_link_validity('00000000-0000-0000-0000-000000000caa', %L, 2)$q$,
  (select id from t_ids where k = 'f1'))) = '22023', 'validade de 2 dias não existe');
select public.set_anamnese_link_validity('00000000-0000-0000-0000-000000000caa', (select id from t_ids where k = 'f1'), 1);
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select token_expires_at > now() + interval '23 hours' and token_expires_at <= now() + interval '24 hours'
  from public.anamneses where id = (select id from t_ids where k = 'f1')), 'validade de 24 horas aplicada');
select pg_temp.login('00000000-0000-0000-0000-000000000ca3');
select pg_temp.expect(pg_temp.state_of(format($q$select public.set_anamnese_link_validity('00000000-0000-0000-0000-000000000caa', %L, 7)$q$,
  (select id from t_ids where k = 'f1'))) = '42501', 'visualizadora não altera a validade');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.login('00000000-0000-0000-0000-000000000ca4');
select pg_temp.expect(pg_temp.state_of(format($q$select public.set_anamnese_link_validity('00000000-0000-0000-0000-000000000cab', %L, 7)$q$,
  (select id from t_ids where k = 'f1'))) = 'P0002', 'ficha de outro estúdio não é encontrada');
reset role; select set_config('request.jwt.claims', '', true);

-- ── 4. O link mostra validade e atendimento; abrir registra uma vez ───────────────────────────
select pg_temp.anon();
select pg_temp.expect((select public.public_anamnese_open(tok, repeat('1', 64), false) ->> 'appointment_service' = 'Aquarele Lips'
    and public.public_anamnese_open(tok, repeat('1', 64), false) ->> 'org_timezone' = 'Europe/Madrid'
    and public.public_anamnese_open(tok, repeat('1', 64), false) ->> 'org_address' = 'Calle Mayor 1, Madrid'
    and (public.public_anamnese_open(tok, repeat('1', 64), false) ->> 'expires_at') is not null
    and (public.public_anamnese_open(tok, repeat('1', 64), false) ->> 'appointment_at') is not null
  from t_ids where k = 'f1'), 'link traz validade, atendimento, serviço e fuso');
select pg_temp.expect((select not (public.public_anamnese_open(tok, repeat('1', 64), false) ? 'professional_notes') and not (public.public_anamnese_open(tok, repeat('1', 64), false) ? 'client_id')
    and not (public.public_anamnese_open(tok, repeat('1', 64), false) ? 'signer_ip') from t_ids where k = 'f1'), 'link não expõe campos internos');
select public.public_anamnese_open(tok, repeat('1', 64), false) from t_ids where k = 'f1';
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select first_opened_at is null and last_opened_at is null from public.anamneses where id = (select id from t_ids where k = 'f1')),
  'ler sem registrar não marca abertura (robô de pré-visualização)');
select pg_temp.anon();
select public.public_anamnese_open(tok, repeat('1', 64), true) from t_ids where k = 'f1';
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select first_opened_at is not null and last_opened_at = first_opened_at from public.anamneses
  where id = (select id from t_ids where k = 'f1')), 'primeira abertura registrada');
select pg_temp.expect((select count(*) = 1 from public.anamnese_events where anamnese_id = (select id from t_ids where k = 'f1') and kind = 'opened'),
  'um evento de abertura');
-- Segunda abertura em seguida: não regrava (no máximo uma por minuto) e não duplica o evento.
select pg_temp.anon();
select public.public_anamnese_open(tok, repeat('1', 64), true) from t_ids where k = 'f1';
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select count(*) = 1 from public.anamnese_events where anamnese_id = (select id from t_ids where k = 'f1') and kind = 'opened'),
  'abrir de novo não duplica o evento');
-- Uma hora depois: a última abertura anda, a primeira fica e o evento continua um só.
update public.anamneses set last_opened_at = now() - interval '2 hours', first_opened_at = now() - interval '3 hours'
where id = (select id from t_ids where k = 'f1');
select pg_temp.anon();
select public.public_anamnese_open(tok, repeat('1', 64), true) from t_ids where k = 'f1';
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select last_opened_at > now() - interval '1 minute' and first_opened_at < now() - interval '2 hours'
  from public.anamneses where id = (select id from t_ids where k = 'f1')), 'última abertura anda; a primeira não muda');

-- Token que não existe ou curto não registra nada nem quebra.
select pg_temp.anon();
select pg_temp.expect(public.public_anamnese_open('curto', repeat('1', 64), true) is null, 'token curto devolve nulo');
select pg_temp.expect(public.public_anamnese_open('0123456789abcdef0123456789abcdef', repeat('1', 64), true) is null, 'token inexistente devolve nulo');
reset role; select set_config('request.jwt.claims', '', true);

-- ── 5. Envio registrado (canal e quem enviou), com tolerância a clique duplo ────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000000ca2');
select public.log_anamnese_send('00000000-0000-0000-0000-000000000caa', (select id from t_ids where k = 'f1'), 'whatsapp');
select public.log_anamnese_send('00000000-0000-0000-0000-000000000caa', (select id from t_ids where k = 'f1'), 'whatsapp');
select public.log_anamnese_send('00000000-0000-0000-0000-000000000caa', (select id from t_ids where k = 'f1'), 'qr');
select pg_temp.expect(pg_temp.state_of(format($q$select public.log_anamnese_send('00000000-0000-0000-0000-000000000caa', %L, 'sms')$q$,
  (select id from t_ids where k = 'f1'))) = '22023', 'canal desconhecido recusado');
select pg_temp.expect((select count(*) = 3 from public.list_anamnese_events('00000000-0000-0000-0000-000000000caa', (select id from t_ids where k = 'f1'))),
  'dois envios (whatsapp repetido conta uma vez) e a abertura');
select pg_temp.expect((select count(*) = 2 and bool_and(user_name = 'Marta Gómez')
  from public.list_anamnese_events('00000000-0000-0000-0000-000000000caa') where kind = 'sent'), 'visão geral lista os envios');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select count(*) = 2 and bool_and(user_id = '00000000-0000-0000-0000-000000000ca2') from public.anamnese_events where kind = 'sent'),
  'envio guarda quem enviou');
select pg_temp.login('00000000-0000-0000-0000-000000000ca3');
select pg_temp.expect(pg_temp.state_of(format($q$select public.log_anamnese_send('00000000-0000-0000-0000-000000000caa', %L, 'copy')$q$,
  (select id from t_ids where k = 'f1'))) = '42501', 'visualizadora não registra envio');
select pg_temp.expect(pg_temp.state_of($q$select * from public.list_anamnese_events('00000000-0000-0000-0000-000000000caa')$q$) = '42501',
  'visualizadora não lê o histórico');
select pg_temp.expect((select count(*) = 0 from public.anamnese_events), 'tabela de eventos fechada pela política');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.login('00000000-0000-0000-0000-000000000ca4');
select pg_temp.expect((select count(*) = 0 from public.list_anamnese_events('00000000-0000-0000-0000-000000000cab')), 'outro estúdio não vê eventos do A');
select pg_temp.expect(pg_temp.state_of($q$select * from public.list_anamnese_events('00000000-0000-0000-0000-000000000caa')$q$) = '42501',
  'outro estúdio não lista o histórico do A');
reset role; select set_config('request.jwt.claims', '', true);

-- ── 6. Link vencido: não abre, não assina, volta com nova validade ─────────────────────────────────────
update public.anamneses set token_expires_at = now() - interval '1 minute' where id = (select id from t_ids where k = 'f1');
update public.anamneses set last_opened_at = null, first_opened_at = null where id = (select id from t_ids where k = 'f1');
select pg_temp.anon();
select pg_temp.expect((select public.public_anamnese_open(tok, repeat('1', 64), false) is null from t_ids where k = 'f1'),
  'vencido: o link não devolve nada (igual a inexistente)');
select public.public_anamnese_open(tok, repeat('1', 64), true) from t_ids where k = 'f1';
select pg_temp.expect((select public.public_anamnese_sign(tok, repeat('1', 64), '{"q1":"No","__canal":"link","__termo_principal":"aceito","t2":"aceito","t1":"recusado"}'::jsonb, 'Carmen Ruiz', 'data:image/png;base64,' || repeat('A', 60), true, 'ua', '203.0.113.9') ->> 'error' from t_ids where k = 'f1') = 'not_found',
  'vencido: assinatura devolve not_found (igual a inexistente)');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select first_opened_at is null from public.anamneses where id = (select id from t_ids where k = 'f1')),
  'vencido: abrir não registra');
select pg_temp.login('00000000-0000-0000-0000-000000000ca2');
select public.set_anamnese_link_validity('00000000-0000-0000-0000-000000000caa', (select id from t_ids where k = 'f1'), 3);
select pg_temp.expect((select count(*) = 1 from public.list_anamnese_events('00000000-0000-0000-0000-000000000caa',
  (select id from t_ids where k = 'f1')) where kind = 'renewed'), 'reabrir link vencido fica registrado');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select not (public.public_anamnese_open(tok, repeat('1', 64), false) ->> 'expired')::boolean from t_ids
  where k = 'f1'), 'link renovado volta a valer');

-- ── 7. Assinatura revalidada no banco ─────────────────────────────────────────────────────────────────
select pg_temp.anon();
-- Sem aceitar o termo principal.
select pg_temp.expect((select public.public_anamnese_sign(tok, repeat('1', 64), '{"q1":"No","__canal":"link","t2":"aceito","t1":"recusado"}'::jsonb, 'Carmen Ruiz', 'data:image/png;base64,' || repeat('A', 60), true, 'ua', '203.0.113.9') ->> 'error' from t_ids where k = 'f1') = 'terms_required',
  'sem o termo principal não assina');
-- Termo obrigatório do modelo sem aceite.
select pg_temp.expect((select public.public_anamnese_sign(tok, repeat('1', 64), '{"q1":"No","__canal":"link","__termo_principal":"aceito","t1":"recusado"}'::jsonb, 'Carmen Ruiz', 'data:image/png;base64,' || repeat('A', 60), true, 'ua', '203.0.113.9') ->> 'error' from t_ids where k = 'f1') = 'terms_required',
  'termo obrigatório ausente não assina');
select pg_temp.expect((select public.public_anamnese_sign(tok, repeat('1', 64), '{"q1":"No","__canal":"link","__termo_principal":"aceito","t2":"recusado","t1":"aceito"}'::jsonb, 'Carmen Ruiz', 'data:image/png;base64,' || repeat('A', 60), true, 'ua', '203.0.113.9') ->> 'error' from t_ids where k = 'f1') = 'terms_required',
  'recusar termo obrigatório não assina');
-- Termo opcional sem resposta.
select pg_temp.expect((select public.public_anamnese_sign(tok, repeat('1', 64), '{"q1":"No","__canal":"link","__termo_principal":"aceito","t2":"aceito"}'::jsonb, 'Carmen Ruiz', 'data:image/png;base64,' || repeat('A', 60), true, 'ua', '203.0.113.9') ->> 'error' from t_ids where k = 'f1') = 'terms_required',
  'termo opcional sem resposta não assina');
-- Pergunta obrigatória vazia.
select pg_temp.expect((select public.public_anamnese_sign(tok, repeat('1', 64), '{"q1":"  ","__canal":"link","__termo_principal":"aceito","t2":"aceito","t1":"recusado"}'::jsonb, 'Carmen Ruiz', 'data:image/png;base64,' || repeat('A', 60), true, 'ua', '203.0.113.9') ->> 'error' from t_ids where k = 'f1') = 'answers_required',
  'pergunta obrigatória vazia não assina');
-- "Sim" sem o detalhe pedido.
select pg_temp.expect((select public.public_anamnese_sign(tok, repeat('1', 64), '{"q1":"Sí","__canal":"link","__termo_principal":"aceito","t2":"aceito","t1":"recusado"}'::jsonb, 'Carmen Ruiz', 'data:image/png;base64,' || repeat('A', 60), true, 'ua', '203.0.113.9') ->> 'error' from t_ids where k = 'f1') = 'answers_required',
  'sim sem detalhe não assina');
-- Canal ausente ou inventado.
select pg_temp.expect((select public.public_anamnese_sign(tok, repeat('1', 64), '{"q1":"No","__termo_principal":"aceito","t2":"aceito","t1":"recusado"}'::jsonb, 'Carmen Ruiz', 'data:image/png;base64,' || repeat('A', 60), true, 'ua', '203.0.113.9') ->> 'error' from t_ids where k = 'f1') = 'channel_invalid',
  'sem canal não assina');
select pg_temp.expect((select public.public_anamnese_sign(tok, repeat('1', 64), '{"q1":"No","__canal":"fax","__termo_principal":"aceito","t2":"aceito","t1":"recusado"}'::jsonb, 'Carmen Ruiz', 'data:image/png;base64,' || repeat('A', 60), true, 'ua', '203.0.113.9') ->> 'error' from t_ids where k = 'f1') = 'channel_invalid',
  'canal inventado não assina');
-- As funções antigas pelo token em claro (inclusive a de seis parâmetros do app antigo) não existem mais.
select pg_temp.expect(to_regprocedure('public.submit_anamnese_signature(text, jsonb, text, text, boolean, text)') is null
    and to_regprocedure('public.get_anamnese_by_token(text)') is null, 'funções antigas do link removidas');
-- Pelo link, o canal só pode ser "link" (o modo estúdio assina por studio_anamnese_sign).
select pg_temp.expect((select public.public_anamnese_sign(tok, repeat('1', 64), '{"q1":"Sí","q1__explain":"Látex","__canal":"tablet","__termo_principal":"aceito","t2":"aceito","t1":"recusado"}'::jsonb,
  'Carmen Ruiz', 'data:image/png;base64,' || repeat('A', 60), true, 'Mozilla/5.0', '203.0.113.9') ->> 'error' from t_ids where k = 'f1') = 'channel_invalid',
  'pelo link não assina como modo estúdio');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select status = 'pending' and signed_at is null and signer_ip is null from public.anamneses
  where id = (select id from t_ids where k = 'f1')), 'tentativas inválidas deixam a ficha pendente');

-- Tudo certo: assina e grava o IP anonimizado.
select pg_temp.anon();
select pg_temp.expect((select public.public_anamnese_sign(tok, repeat('1', 64), '{"q1":"Sí","q1__explain":"Látex","__canal":"link","__termo_principal":"aceito","t2":"aceito","t1":"recusado"}'::jsonb, 'Carmen Ruiz', 'data:image/png;base64,' || repeat('A', 60), true, 'Mozilla/5.0', '203.0.113.9') ->> 'ok' from t_ids where k = 'f1') = 'true',
  'assina com tudo preenchido');
select pg_temp.expect((select public.public_anamnese_sign(tok, repeat('1', 64), '{"q1":"No","__canal":"link","__termo_principal":"aceito","t2":"aceito","t1":"recusado"}'::jsonb, 'Outra', 'data:image/png;base64,' || repeat('B', 60), true, 'ua', '198.51.100.7') ->> 'error' from t_ids where k = 'f1') = 'not_found',
  'segunda assinatura devolve not_found (igual a inexistente)');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select signer_ip = '203.0.113.0' and status = 'signed' and answers ->> 'q1' = 'Sí'
  from public.anamneses where id = (select id from t_ids where k = 'f1')), 'IP gravado sem o último octeto; a segunda tentativa não troca nada');
select pg_temp.expect((select public.anonymize_ip('203.0.113.9') = '203.0.113.0'
    and public.anonymize_ip('2001:DB8:1234:5678:9abc:def0:1234:5678') = '2001:db8:1234::'
    and public.anonymize_ip('2001:db8::1') = '2001:db8::'
    and public.anonymize_ip('::1') = '::'
    and public.anonymize_ip('lixo; drop table') is null
    and public.anonymize_ip(null) is null), 'anonimização de IPv4 e IPv6');
-- Assinada: o link responde como inexistente; a cliente ainda baixa o atendimento (adicionar ao calendário).
select pg_temp.anon();
select pg_temp.expect((select public.public_anamnese_open(tok, repeat('1', 64), false) is null
    and (public.public_anamnese_calendar(tok, repeat('1', 64)) ->> 'appointment_at') is not null
    and not (public.public_anamnese_calendar(tok, repeat('1', 64)) ? 'answers') from t_ids where k = 'f1'),
  'assinada: o link não devolve nada, o calendário ainda traz o atendimento');
select public.public_anamnese_open(tok, repeat('1', 64), true) from t_ids where k = 'f1';
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select last_opened_at is null from public.anamneses where id = (select id from t_ids where k = 'f1')),
  'assinada: abrir não registra');

-- ── 8. PIN do modo estúdio ─────────────────────────────────────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000000ca2');
select pg_temp.expect((public.studio_pin_status('00000000-0000-0000-0000-000000000caa') ->> 'configured') = 'false', 'sem PIN ainda');
select pg_temp.expect(pg_temp.state_of($q$select public.set_studio_pin('00000000-0000-0000-0000-000000000caa', '1234')$q$) = '42501',
  'recepção não define o PIN');
select pg_temp.expect((public.verify_studio_pin('00000000-0000-0000-0000-000000000caa', '1234') ->> 'reason') = 'not_configured', 'sem PIN, conferir avisa');
select pg_temp.expect(pg_temp.state_of($q$select * from public.studio_mode_pins$q$) = '42501', 'ninguém lê a tabela do PIN pela API');
reset role; select set_config('request.jwt.claims', '', true);

select pg_temp.login('00000000-0000-0000-0000-000000000ca1');
select pg_temp.expect(pg_temp.state_of($q$select public.set_studio_pin('00000000-0000-0000-0000-000000000caa', '12')$q$) = '22023', 'PIN curto recusado');
select pg_temp.expect(pg_temp.state_of($q$select public.set_studio_pin('00000000-0000-0000-0000-000000000caa', 'abcd')$q$) = '22023', 'PIN com letras recusado');
select public.set_studio_pin('00000000-0000-0000-0000-000000000caa', '4821');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.login('00000000-0000-0000-0000-000000000ca4');
select public.set_studio_pin('00000000-0000-0000-0000-000000000cab', '4821');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select count(distinct pin_hash) = 2 and bool_and(pin_hash not like '%4821%' and pin_hash like '$2%') from public.studio_mode_pins),
  'mesmo PIN, hashes diferentes (sal por estúdio) e nada em texto aberto');
select pg_temp.expect((select count(*) = 1 from public.audit_logs where operation = 'STUDIO_PIN_SET' and org_id = '00000000-0000-0000-0000-000000000caa'
  and new_data is null), 'redefinir o PIN fica no registro, sem o PIN');

select pg_temp.login('00000000-0000-0000-0000-000000000ca2');
select pg_temp.expect((public.verify_studio_pin('00000000-0000-0000-0000-000000000caa', '4821') ->> 'ok') = 'true', 'PIN certo libera');
select pg_temp.expect((public.verify_studio_pin('00000000-0000-0000-0000-000000000caa', '0000') ->> 'reason') = 'wrong', 'PIN errado');
select pg_temp.expect((public.verify_studio_pin('00000000-0000-0000-0000-000000000caa', '0001') ->> 'remaining')::int = 3, 'restam 3 tentativas');
select pg_temp.expect((public.verify_studio_pin('00000000-0000-0000-0000-000000000caa', '4821') ->> 'ok') = 'true', 'acertar zera as tentativas');
select public.verify_studio_pin('00000000-0000-0000-0000-000000000caa', '1111');
select public.verify_studio_pin('00000000-0000-0000-0000-000000000caa', '1112');
select public.verify_studio_pin('00000000-0000-0000-0000-000000000caa', '1113');
select public.verify_studio_pin('00000000-0000-0000-0000-000000000caa', '1114');
select pg_temp.expect((public.verify_studio_pin('00000000-0000-0000-0000-000000000caa', '1115') ->> 'reason') = 'locked', 'cinco erros travam');
select pg_temp.expect((public.verify_studio_pin('00000000-0000-0000-0000-000000000caa', '4821') ->> 'reason') = 'locked',
  'travado, nem o PIN certo entra');
select pg_temp.expect((public.studio_pin_status('00000000-0000-0000-0000-000000000caa') ->> 'locked') = 'true', 'status mostra o travamento');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select locked_until > now() + interval '4 minutes' from public.studio_mode_pins where org_id = '00000000-0000-0000-0000-000000000caa'),
  'trava de 5 minutos');
update public.studio_mode_pins set locked_until = now() - interval '1 second' where org_id = '00000000-0000-0000-0000-000000000caa';
select pg_temp.login('00000000-0000-0000-0000-000000000ca2');
select pg_temp.expect((public.verify_studio_pin('00000000-0000-0000-0000-000000000caa', '4821') ->> 'ok') = 'true', 'passado o prazo, o PIN certo volta a valer');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.login('00000000-0000-0000-0000-000000000ca3');
select pg_temp.expect(pg_temp.state_of($q$select public.verify_studio_pin('00000000-0000-0000-0000-000000000caa', '4821')$q$) = '42501',
  'visualizadora não confere o PIN');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.login('00000000-0000-0000-0000-000000000ca4');
select pg_temp.expect(pg_temp.state_of($q$select public.verify_studio_pin('00000000-0000-0000-0000-000000000caa', '4821')$q$) = '42501',
  'outro estúdio não confere o PIN do A');
reset role; select set_config('request.jwt.claims', '', true);

rollback;
\o
\echo 'anamnese: link, envio, abertura, assinatura, versão e PIN: ok'
