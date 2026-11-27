-- Mensagens e Marketing (porte, orçamento de chamadas): messages_overview, messages_templates_screen,
-- messages_history_screen, marketing_campaigns_screen, marketing_reviews_screen, marketing_audience e as ações
-- messaging_* e marketing_* das migrations 20261114090000, 20261114090100 e 20261114090200.
-- Cobre: isolamento entre estúdios, anônimo sem execução nem leitura, permissão por papel, nenhuma coluna de token nas
-- tabelas de mensagens, consentimento de marketing (quem pediu para não receber nunca entra na fila; descadastro e
-- volta pela função real do perfil da cliente), auditoria por gatilho que ninguém forja, caminhos felizes de cada
-- gravação, limites e cascata de estúdio. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000155010', 'dona@m155.local'),
  ('00000000-0000-0000-0000-000000155011', 'recep@m155.local'),
  ('00000000-0000-0000-0000-000000155012', 'donab@m155.local'),
  ('00000000-0000-0000-0000-000000155013', 'gerente@m155.local'),
  ('00000000-0000-0000-0000-000000155014', 'prof@m155.local'),
  ('00000000-0000-0000-0000-000000155015', 'viewer@m155.local');
insert into public.organizations (id, slug, name, timezone) values
  ('00000000-0000-0000-0000-00000000155a', 'm155-a', 'Mensagens 155 A', 'Europe/Madrid'),
  ('00000000-0000-0000-0000-00000000155b', 'm155-b', 'Mensagens 155 B', 'Europe/Madrid');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000155010', '00000000-0000-0000-0000-00000000155a', 'owner'),
  ('00000000-0000-0000-0000-000000155011', '00000000-0000-0000-0000-00000000155a', 'receptionist'),
  ('00000000-0000-0000-0000-000000155012', '00000000-0000-0000-0000-00000000155b', 'owner'),
  ('00000000-0000-0000-0000-000000155013', '00000000-0000-0000-0000-00000000155a', 'manager'),
  ('00000000-0000-0000-0000-000000155014', '00000000-0000-0000-0000-00000000155a', 'professional'),
  ('00000000-0000-0000-0000-000000155015', '00000000-0000-0000-0000-00000000155a', 'viewer');
insert into public.profiles (user_id, org_id, full_name) values
  ('00000000-0000-0000-0000-000000155013', '00000000-0000-0000-0000-00000000155a', 'Gerente Gabi')
on conflict (user_id, org_id) do update set full_name = excluded.full_name;

-- Plano do estúdio A (limite de mensagens automáticas vem do plano).
insert into public.org_subscriptions (org_id, plan_key) values ('00000000-0000-0000-0000-00000000155a', 'profissional')
  on conflict (org_id) do update set plan_key = excluded.plan_key, limits_override = '{}';

-- Clientes do estúdio A (hoje no fuso do estúdio = referência das datas).
create temp table today as select (now() at time zone 'Europe/Madrid')::date as d;
insert into public.clients (id, org_id, full_name, phone, phone_country_code, email, tags, status, last_visit, birth_date, total_spent) values
  ('00000000-0000-0000-0000-0000000155c1', '00000000-0000-0000-0000-00000000155a', 'Ana', '+34600000001', '+34', 'ana@m.local', '{VIP}', 'Ativo',
    (select d - 90 from today), ((select d from today) + 10 - interval '30 years')::date, 500),
  ('00000000-0000-0000-0000-0000000155c2', '00000000-0000-0000-0000-00000000155a', 'Bia', '600000002', '+34', null, '{}', 'Ativo',
    (select d - 10 from today), ((select d from today) + 45 - interval '25 years')::date, 100),
  ('00000000-0000-0000-0000-0000000155c3', '00000000-0000-0000-0000-00000000155a', 'Cris', '+34600000003', '+34', null, '{}', 'Ativo', null, null, 0),
  ('00000000-0000-0000-0000-0000000155c4', '00000000-0000-0000-0000-00000000155a', 'Dani', '+34600000004', '+34', null, '{}', 'Inativo', null, null, 0),
  ('00000000-0000-0000-0000-0000000155c5', '00000000-0000-0000-0000-00000000155a', 'Eva', null, null, null, '{}', 'Ativo', null, null, 0),
  ('00000000-0000-0000-0000-0000000155c6', '00000000-0000-0000-0000-00000000155a', 'Fran', '+34600000006', '+34', null, '{}', 'Ativo', null, null, 0),
  ('00000000-0000-0000-0000-0000000155c7', '00000000-0000-0000-0000-00000000155a', 'Gabi', '+34600000007', '+34', null, '{}', 'Inativo', null,
    ((select d from today) - 1 - interval '20 years')::date, 0),
  ('00000000-0000-0000-0000-0000000155c9', '00000000-0000-0000-0000-00000000155b', 'Bruno B', '+34600000009', '+34', null, '{VIP}', 'Ativo', null, null, 900);
insert into public.client_marketing_preferences (org_id, client_id, channel, marketing_allowed, opted_out_at) values
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155c1', 'whatsapp_manual', true, null),
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155c2', 'whatsapp_manual', true, null),
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155c3', 'whatsapp_manual', false, now()),
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155c6', 'whatsapp_manual', false, null);
-- Serviço usado pela Ana (filtro por serviço).
insert into public.services (id, org_id, name, price, duration_minutes, active) values
  ('00000000-0000-0000-0000-0000000155f1', '00000000-0000-0000-0000-00000000155a', 'Serviço A', 50, 60, true),
  ('00000000-0000-0000-0000-0000000155f2', '00000000-0000-0000-0000-00000000155a', 'Serviço inativo', 50, 60, false),
  ('00000000-0000-0000-0000-0000000155f9', '00000000-0000-0000-0000-00000000155b', 'Serviço B', 50, 60, true);
insert into public.appointments (id, org_id, client_id, client_name, start_at, end_at, duration_minutes, status) values
  ('00000000-0000-0000-0000-0000000155ee', '00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155c1',
   'Ana', '2031-05-06 10:30+00', '2031-05-06 11:30+00', 60, 'Agendado');
set local session_replication_role = replica;
insert into public.appointment_items (org_id, appointment_id, type, ref_id, name, price, qty) values
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155ee', 'service', '00000000-0000-0000-0000-0000000155f1', 'Serviço A', 50, 1);
set local session_replication_role = origin;
-- Um modelo de cada estúdio.
insert into public.marketing_message_templates (id, org_id, name, channel, purpose, language, body) values
  ('00000000-0000-0000-0000-0000000155d9', '00000000-0000-0000-0000-00000000155b', 'Modelo B', 'whatsapp_manual', 'manual', 'es', 'Hola B');

create temp table ids (k text primary key, v uuid);
grant all on ids to anon, authenticated;

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
create function pg_temp.logout() returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);
end $$;
create function pg_temp.audits(p_op text) returns bigint language sql as $$
  select count(*) from public.audit_logs where operation = p_op and org_id = '00000000-0000-0000-0000-00000000155a'
$$;
create function pg_temp.aud(p_op text) returns bigint language sql as $$
  select count(*) from public.audit_logs where operation = p_op and org_id = '00000000-0000-0000-0000-00000000155a'
$$;
create function pg_temp.audience(p_filter text, p_enforce boolean default false) returns text language sql as $$
  select coalesce(string_agg(full_name, ',' order by full_name), '')
  from public.marketing_audience('00000000-0000-0000-0000-00000000155a', p_filter::jsonb, p_enforce)
$$;
grant execute on function pg_temp.expect(boolean, text), pg_temp.state_of(text), pg_temp.login(uuid), pg_temp.logout(),
  pg_temp.audits(text), pg_temp.aud(text), pg_temp.audience(text, boolean) to anon, authenticated;

-- ─── Nenhuma coluna de token ou segredo nas tabelas de mensagens ──────────────────────────────────
select pg_temp.expect((select count(*) from information_schema.columns
  where table_schema = 'public'
    and table_name in ('messaging_connections', 'messaging_provider_log', 'marketing_message_queue', 'marketing_message_events',
                       'marketing_message_templates', 'marketing_campaigns', 'client_marketing_preferences')
    and column_name ~* '(token|secret|api_?key|password|bearer|credential)') = 0,
  'nenhuma tabela de mensagens tem coluna de token ou segredo');

-- ─── Anônimo: sem execução e sem leitura ──────────────────────────────────────────────────────────
set local role anon;
select pg_temp.expect(pg_temp.state_of($q$select public.messages_overview('00000000-0000-0000-0000-00000000155a', false)$q$) = '42501', 'anon: messages_overview');
select pg_temp.expect(pg_temp.state_of($q$select public.messages_templates_screen('00000000-0000-0000-0000-00000000155a')$q$) = '42501', 'anon: modelos');
select pg_temp.expect(pg_temp.state_of($q$select public.messages_history_screen('00000000-0000-0000-0000-00000000155a')$q$) = '42501', 'anon: histórico');
select pg_temp.expect(pg_temp.state_of($q$select public.marketing_campaigns_screen('00000000-0000-0000-0000-00000000155a', '[]')$q$) = '42501', 'anon: campanhas');
select pg_temp.expect(pg_temp.state_of($q$select public.marketing_reviews_screen('00000000-0000-0000-0000-00000000155a')$q$) = '42501', 'anon: avaliações');
select pg_temp.expect(pg_temp.state_of($q$select * from public.marketing_audience('00000000-0000-0000-0000-00000000155a', '{}', true)$q$) = '42501', 'anon: público');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_save_template('00000000-0000-0000-0000-00000000155a', null, 'x', 'whatsapp_manual', 'manual', 'es', null, 'x')$q$) = '42501', 'anon: salvar modelo');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_save_connection('00000000-0000-0000-0000-00000000155a', 'meta_cloud', 's', 'connected', null, null)$q$) = '42501', 'anon: conexão');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_log_test_send('00000000-0000-0000-0000-00000000155a', 'meta_cloud', 'whatsapp', '1', 'x')$q$) = '42501', 'anon: reservar registro de teste');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_log_test_result('00000000-0000-0000-0000-00000000155a', gen_random_uuid(), true, null, null)$q$) = '42501', 'anon: fechar registro de teste');
select pg_temp.expect(pg_temp.state_of($q$select public.marketing_client_eligible('00000000-0000-0000-0000-00000000155a', gen_random_uuid(), 'whatsapp_manual')$q$) = '42501', 'anon: elegibilidade é só do gatilho');
select pg_temp.expect(pg_temp.state_of($q$select public.marketing_create_campaign('00000000-0000-0000-0000-00000000155a', 'x', null, 'whatsapp_manual', 'manual', null, '{}')$q$) = '42501', 'anon: criar campanha');
select pg_temp.expect(pg_temp.state_of($q$select public.marketing_prepare_queue('00000000-0000-0000-0000-00000000155a', gen_random_uuid())$q$) = '42501', 'anon: preparar fila');
select pg_temp.expect(not has_function_privilege('anon', 'public.marketing_authorized(public.clients)', 'execute') and not has_function_privilege('anon', 'public.marketing_state(public.clients)', 'execute')
  and has_function_privilege('authenticated', 'public.marketing_authorized(public.clients)', 'execute'), 'anon: sem execução nas funções de estado de marketing');
-- Nenhuma política das tabelas de mensagens vale para anon (nem para "public"): ele não enxerga linha nenhuma.
select pg_temp.expect((select count(*) from pg_policies where schemaname = 'public'
  and tablename in ('messaging_connections', 'messaging_provider_log', 'marketing_message_queue', 'marketing_message_events',
                    'marketing_message_templates', 'marketing_campaigns')
  and (roles && array['anon', 'public']::name[])) = 0, 'anon: nenhuma política de mensagens vale para ele');
select pg_temp.logout();

-- Funções de auditoria: ninguém as chama (nem logado).
select pg_temp.login('00000000-0000-0000-0000-000000155010');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_connection_audit_row()$q$) = '42501', 'dona não chama a auditoria da conexão');
select pg_temp.expect(pg_temp.state_of($q$select public.marketing_campaign_audit_row()$q$) = '42501', 'dona não chama a auditoria da campanha');
select pg_temp.expect(pg_temp.state_of($q$select public.marketing_queue_audit_stmt()$q$) = '42501', 'dona não chama a auditoria da fila');
select pg_temp.expect(pg_temp.state_of($q$select public.marketing_client_eligible('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155c1', 'whatsapp_manual')$q$) = '42501', 'dona não chama a elegibilidade');
select pg_temp.expect(pg_temp.state_of($q$select public.marketing_queue_guard()$q$) = '42501', 'dona não chama a guarda da fila');
select pg_temp.logout();

-- ─── Público (marketing_audience): mesmos casos do teste de domínio, consentimento no banco ───────
select pg_temp.login('00000000-0000-0000-0000-000000155013');
select pg_temp.expect(pg_temp.audience('{"channel":"whatsapp_manual","clientStatus":"Ativo","marketingConsent":"missing_or_allowed"}') = 'Ana,Bia',
  'todas: só quem aceitou (Cris saiu; Fran recusou; Eva não tem preferência registrada e fica fora)');
select pg_temp.expect(pg_temp.audience('{"channel":"whatsapp_manual","clientStatus":"Ativo","marketingConsent":"missing_or_allowed","tagsAny":["VIP"]}') = 'Ana', 'VIP');
select pg_temp.expect(pg_temp.audience('{"channel":"whatsapp_manual","clientStatus":"Ativo","marketingConsent":"missing_or_allowed","inactiveDays":60}') = 'Ana',
  'inativas há 60 dias: quem nunca veio não entra');
select pg_temp.expect(pg_temp.audience('{"channel":"whatsapp_manual","clientStatus":"Ativo","marketingConsent":"missing_or_allowed","birthdayWindowDays":30}') = 'Ana',
  'aniversário em 30 dias: Bia (45) e quem fez ontem (364) ficam de fora');
select pg_temp.expect(pg_temp.audience('{"channel":"whatsapp_manual","clientStatus":"any","marketingConsent":"any","birthdayWindowDays":365}') like '%Gabi%',
  'aniversário de ontem entra numa janela de um ano (próximo ano)');
select pg_temp.expect(pg_temp.audience('{"channel":"whatsapp_manual","clientStatus":"Ativo","marketingConsent":"missing_or_allowed","totalSpentMin":300}') = 'Ana', 'gasto mínimo');
select pg_temp.expect(pg_temp.audience('{"channel":"whatsapp_manual","clientStatus":"Ativo","marketingConsent":"missing_or_allowed","totalSpentMax":150}') = 'Bia', 'gasto máximo');
select pg_temp.expect(pg_temp.audience('{"channel":"whatsapp_manual","clientStatus":"Ativo","marketingConsent":"allowed"}') = 'Ana,Bia', 'só quem aceitou');
select pg_temp.expect(pg_temp.audience('{"channel":"whatsapp_manual","clientStatus":"Ativo","marketingConsent":"any"}') = 'Ana,Bia,Cris,Eva,Fran', 'auditoria de consentimento vê todas');
select pg_temp.expect(pg_temp.audience('{"channel":"whatsapp_manual","clientStatus":"Ativo","marketingConsent":"any"}', true) = 'Ana,Bia',
  'com o consentimento imposto, quem recusou ou nunca respondeu não volta (nem na auditoria)');
select pg_temp.expect(pg_temp.audience('{"channel":"whatsapp_manual","clientStatus":"Ativo","marketingConsent":"missing_or_allowed","serviceIdsAny":["00000000-0000-0000-0000-0000000155f1"]}') = 'Ana', 'por serviço');
select pg_temp.expect(pg_temp.audience('{"channel":"whatsapp_manual","clientStatus":"Inativo","marketingConsent":"any"}') = 'Dani,Gabi', 'status inativo');
select pg_temp.expect(pg_temp.state_of($q$select * from public.marketing_audience('00000000-0000-0000-0000-00000000155a', '{"clientStatus":"Ativo"}', true)$q$) = '22023', 'sem canal, o consentimento não pode ser conferido: recusa');
select pg_temp.expect(pg_temp.audience('{"clientStatus":"Ativo","marketingConsent":"any"}') = 'Ana,Bia,Cris,Eva,Fran', 'sem canal e sem exigir consentimento: lista tudo');
select pg_temp.expect(pg_temp.state_of($q$select * from public.marketing_audience('00000000-0000-0000-0000-00000000155a', '{"marketingConsent":"qualquer"}', true)$q$) = '22023', 'consentimento inválido');
select pg_temp.expect(pg_temp.state_of($q$select * from public.marketing_audience('00000000-0000-0000-0000-00000000155a', '[]', true)$q$) = '22023', 'filtro que não é objeto');
select pg_temp.expect(pg_temp.state_of($q$select * from public.marketing_audience('00000000-0000-0000-0000-00000000155b', '{}', true)$q$) = '42501', 'gerente do A não vê o público do B');
select pg_temp.expect(pg_temp.audience('{"channel":"whatsapp_manual","clientStatus":"any","marketingConsent":"any"}') not like '%Bruno%', 'cliente do outro estúdio nunca aparece');
select pg_temp.logout();

-- Recepção, profissional e viewer não veem o público.
select pg_temp.login('00000000-0000-0000-0000-000000155011');
select pg_temp.expect(pg_temp.state_of($q$select * from public.marketing_audience('00000000-0000-0000-0000-00000000155a', '{}', true)$q$) = '42501', 'recepção não vê o público');
select pg_temp.expect(pg_temp.state_of($q$select public.marketing_campaigns_screen('00000000-0000-0000-0000-00000000155a', '[]')$q$) = '42501', 'recepção não abre Campanhas');
select pg_temp.expect(pg_temp.state_of($q$select public.marketing_reviews_screen('00000000-0000-0000-0000-00000000155a')$q$) = '42501', 'recepção não abre Avaliações');
select pg_temp.logout();

-- ─── Modelos: gravar ──────────────────────────────────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000155013');
insert into ids select 'tpl', public.messaging_save_template('00000000-0000-0000-0000-00000000155a', null, '  Lembrete  ', 'whatsapp_manual', 'aftercare', 'pt', '', ' Olá {cliente}, até já! ');
insert into ids select 'tplrev', public.messaging_save_template('00000000-0000-0000-0000-00000000155a', null, 'Agradecimento', 'whatsapp_manual', 'review_request', 'es', 'Gracias', 'Gracias {cliente}');
select pg_temp.expect((select name = 'Lembrete' and body = 'Olá {cliente}, até já!' and subject is null and version = 1
  and created_by = '00000000-0000-0000-0000-000000155013' and org_id = '00000000-0000-0000-0000-00000000155a'
  from public.marketing_message_templates where id = (select v from ids where k = 'tpl')), 'criar: texto aparado, assunto vazio vira nulo, autor e estúdio do servidor');
select pg_temp.expect((public.messaging_save_template('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'tpl'), 'Lembrete 2', 'email_provider', 'promotion', 'en', 'Assunto', 'Hi')) = (select v from ids where k = 'tpl'), 'editar devolve o mesmo id');
select pg_temp.expect((select name = 'Lembrete 2' and version = 2 and channel = 'email_provider' and subject = 'Assunto' from public.marketing_message_templates where id = (select v from ids where k = 'tpl')), 'editar: nova versão');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_save_template('00000000-0000-0000-0000-00000000155a', gen_random_uuid(), 'x', 'whatsapp_manual', 'manual', 'es', null, 'x')$q$) = 'P0002', 'editar modelo que não existe');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_save_template('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155d9', 'x', 'whatsapp_manual', 'manual', 'es', null, 'x')$q$) = 'P0002', 'modelo do outro estúdio: não encontrado');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_save_template('00000000-0000-0000-0000-00000000155a', null, '   ', 'whatsapp_manual', 'manual', 'es', null, 'x')$q$) = '22023', 'nome vazio');
select pg_temp.expect(pg_temp.state_of(format($q$select public.messaging_save_template('00000000-0000-0000-0000-00000000155a', null, %L, 'whatsapp_manual', 'manual', 'es', null, 'x')$q$, repeat('n', 121))) = '22023', 'nome longo');
select pg_temp.expect(pg_temp.state_of(format($q$select public.messaging_save_template('00000000-0000-0000-0000-00000000155a', null, 'x', 'whatsapp_manual', 'manual', 'es', null, %L)$q$, repeat('b', 2001))) = '22023', 'texto longo');
select pg_temp.expect(pg_temp.state_of(format($q$select public.messaging_save_template('00000000-0000-0000-0000-00000000155a', null, 'x', 'whatsapp_manual', 'manual', 'es', %L, 'x')$q$, repeat('s', 161))) = '22023', 'assunto longo');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_save_template('00000000-0000-0000-0000-00000000155a', null, 'x', 'fax', 'manual', 'es', null, 'x')$q$) = '22023', 'canal inválido');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_save_template('00000000-0000-0000-0000-00000000155a', null, 'x', 'whatsapp_manual', 'spam', 'es', null, 'x')$q$) = '22023', 'finalidade inválida');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_save_template('00000000-0000-0000-0000-00000000155a', null, 'x', 'whatsapp_manual', 'manual', 'fr', null, 'x')$q$) = '22023', 'idioma inválido');
-- Duplicar e arquivar (com desfazer).
insert into ids select 'dup', public.messaging_duplicate_template('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'tpl'));
select pg_temp.expect((select name = 'Lembrete 2 (cópia)' and body = 'Hi' and version = 1 from public.marketing_message_templates where id = (select v from ids where k = 'dup')), 'duplicar: cópia nova');
insert into ids select 'dupl', public.messaging_save_template('00000000-0000-0000-0000-00000000155a', null, repeat('n', 120), 'whatsapp_manual', 'manual', 'es', null, 'x');
insert into ids select 'dupl2', public.messaging_duplicate_template('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'dupl'));
select pg_temp.expect((select char_length(name) = 120 and name not like '%(cópia)' from public.marketing_message_templates
  where id = (select v from ids where k = 'dupl2')), 'duplicar corta o nome em 120');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_duplicate_template('00000000-0000-0000-0000-00000000155a', gen_random_uuid())$q$) = 'P0002', 'duplicar modelo que não existe');
select public.messaging_archive_template('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'dup'), true);
select pg_temp.expect((select archived_at is not null and not active from public.marketing_message_templates where id = (select v from ids where k = 'dup')), 'arquivar');
select pg_temp.expect(not exists (select 1 from jsonb_array_elements(public.messages_templates_screen('00000000-0000-0000-0000-00000000155a') -> 'templates') t
  where (t ->> 'id')::uuid = (select v from ids where k = 'dup')), 'arquivado some da lista');
select public.messaging_archive_template('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'dup'), false);
select pg_temp.expect((select archived_at is null and active from public.marketing_message_templates where id = (select v from ids where k = 'dup')), 'desfazer arquivamento');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_archive_template('00000000-0000-0000-0000-00000000155a', gen_random_uuid(), true)$q$) = 'P0002', 'arquivar modelo que não existe');
select pg_temp.logout();

-- Quem não configura não grava (função nem tabela); outro estúdio também não.
select pg_temp.login('00000000-0000-0000-0000-000000155011');
select pg_temp.expect(pg_temp.state_of(format($q$select public.messaging_save_template('00000000-0000-0000-0000-00000000155a', null, 'x', 'whatsapp_manual', 'manual', 'es', null, 'x')$q$)) = '42501', 'recepção não cria modelo');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_archive_template('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'tpl'), true)$q$) = '42501', 'recepção não arquiva');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_duplicate_template('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'tpl'))$q$) = '42501', 'recepção não duplica');
select pg_temp.expect(pg_temp.state_of($q$insert into public.marketing_message_templates (org_id, name, channel, purpose, body) values ('00000000-0000-0000-0000-00000000155a', 'x', 'whatsapp_manual', 'manual', 'x')$q$) = '42501', 'recepção não grava a tabela direto');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000155014');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_save_template('00000000-0000-0000-0000-00000000155a', null, 'x', 'whatsapp_manual', 'manual', 'es', null, 'x')$q$) = '42501', 'profissional não cria modelo');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000155012');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_save_template('00000000-0000-0000-0000-00000000155a', null, 'x', 'whatsapp_manual', 'manual', 'es', null, 'x')$q$) = '42501', 'dona de outro estúdio não cria modelo aqui');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_archive_template('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'tpl'), true)$q$) = '42501', 'nem arquiva');
select pg_temp.expect(pg_temp.state_of($q$select public.messages_templates_screen('00000000-0000-0000-0000-00000000155a')$q$) = '42501', 'nem lê');
select pg_temp.expect((select count(*) from public.marketing_message_templates where org_id = '00000000-0000-0000-0000-00000000155a') = 0, 'nem pela tabela');
select pg_temp.logout();

-- Tabela direta: gestão segue a liberação; limites de tamanho valem para quem grava pela API.
select pg_temp.login('00000000-0000-0000-0000-000000155010');
select pg_temp.expect(pg_temp.state_of(format($q$update public.marketing_message_templates set name = %L where id = (select v from ids where k = 'tpl')$q$, repeat('n', 121))) = '23514', 'CHECK: nome do modelo até 120 também pela API');
select pg_temp.expect(pg_temp.state_of(format($q$update public.marketing_message_templates set body = %L where id = (select v from ids where k = 'tpl')$q$, repeat('b', 2001))) = '23514', 'CHECK: texto até 2000');
select pg_temp.logout();

-- ─── Leituras das telas ───────────────────────────────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000155011');
select pg_temp.expect((public.messages_overview('00000000-0000-0000-0000-00000000155a', true) ->> 'templates_count')::int = 5, 'recepção vê o selo de modelos (sem arquivados)');
select pg_temp.expect((public.messages_overview('00000000-0000-0000-0000-00000000155a', true) -> 'monthly_limit') = 'null'::jsonb, 'recepção não vê o limite do plano');
select pg_temp.expect(jsonb_array_length(public.messages_templates_screen('00000000-0000-0000-0000-00000000155a') -> 'templates') = 5
  and (public.messages_templates_screen('00000000-0000-0000-0000-00000000155a') ->> 'truncated') = 'false', 'recepção lê a lista de modelos');
select pg_temp.expect((public.messages_templates_screen('00000000-0000-0000-0000-00000000155a') -> 'templates' -> 0) ?& array['id','name','channel','purpose','language','subject','body','active','archived_at','version','updated_at'],
  'modelo com as colunas da tela');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000155014');
select pg_temp.expect((public.messages_overview('00000000-0000-0000-0000-00000000155a') ->> 'templates_count')::int = 5, 'profissional (mensagens.use) abre Mensagens');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000155015');
select pg_temp.expect(pg_temp.state_of($q$select public.messages_overview('00000000-0000-0000-0000-00000000155a')$q$) = '42501', 'viewer não abre Mensagens');
select pg_temp.expect(pg_temp.state_of($q$select public.messages_history_screen('00000000-0000-0000-0000-00000000155a')$q$) = '42501', 'viewer não abre o histórico');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000155010');
select pg_temp.expect((public.messages_overview('00000000-0000-0000-0000-00000000155a', true) ->> 'monthly_limit')::int = 1000, 'dona vê o limite do plano');
select pg_temp.expect((public.messages_overview('00000000-0000-0000-0000-00000000155a', false) -> 'monthly_limit') = 'null'::jsonb, 'sem pedir o plano, não devolve');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000155013');
select pg_temp.expect((public.messages_overview('00000000-0000-0000-0000-00000000155a', true) -> 'monthly_limit') = 'null'::jsonb, 'gerente (sem ajustes.manage) não vê o limite');
select pg_temp.logout();

-- ─── Conexão do canal ─────────────────────────────────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000155013');
select public.messaging_save_connection('00000000-0000-0000-0000-00000000155a', 'meta_cloud', '123456', 'starting', null, null);
select pg_temp.expect(pg_temp.aud('MESSAGING_CHANNEL_CONNECTED') = 0 and pg_temp.aud('MESSAGING_CHANNEL_DISCONNECTED') = 0, 'iniciar a sessão não é conexão: sem auditoria');
select public.messaging_save_connection('00000000-0000-0000-0000-00000000155a', 'meta_cloud', '123456', 'awaiting_scan', null, null);
select public.messaging_save_connection('00000000-0000-0000-0000-00000000155a', 'meta_cloud', '123456', 'connected', '+34600000000', 'Estúdio');
select pg_temp.expect(pg_temp.aud('MESSAGING_CHANNEL_CONNECTED') = 1, 'conectar é auditado');
select pg_temp.expect((select user_id = '00000000-0000-0000-0000-000000155013' and new_data = '{"provider":"meta_cloud","status":"connected"}'::jsonb
  from public.audit_logs where operation = 'MESSAGING_CHANNEL_CONNECTED'), 'auditoria: quem, provedor e situação (sem telefone, sem token)');
select pg_temp.expect((select status_at from public.messaging_connections where org_id = '00000000-0000-0000-0000-00000000155a') is not null, 'conexão gravada');
-- Consulta repetida sem mudança: não grava de novo.
create temp table stamp as select status_at, updated_at from public.messaging_connections where org_id = '00000000-0000-0000-0000-00000000155a';
grant all on stamp to authenticated;
select public.messaging_save_connection('00000000-0000-0000-0000-00000000155a', 'meta_cloud', '123456', 'connected', '+34600000000', 'Estúdio');
select pg_temp.expect((select c.status_at = s.status_at and c.updated_at = s.updated_at from public.messaging_connections c, stamp s where c.org_id = '00000000-0000-0000-0000-00000000155a'), 'sem mudança, sem gravação');
select pg_temp.expect(pg_temp.aud('MESSAGING_CHANNEL_CONNECTED') = 1, 'e sem nova auditoria');
select public.messaging_save_connection('00000000-0000-0000-0000-00000000155a', 'meta_cloud', '123456', 'disconnected', null, null);
select pg_temp.expect(pg_temp.aud('MESSAGING_CHANNEL_DISCONNECTED') = 1, 'desconectar é auditado');
select public.messaging_save_connection('00000000-0000-0000-0000-00000000155a', 'meta_cloud', '123456', 'connected', '+34911111111', 'Meta');
select pg_temp.expect(pg_temp.aud('MESSAGING_CHANNEL_CONNECTED') = 2, 'trocar o número conectado: nova auditoria');
create temp table cstamp as select connected_at from public.messaging_connections where org_id = '00000000-0000-0000-0000-00000000155a';
grant all on cstamp to authenticated;
select pg_temp.expect((select connected_at is not null from cstamp), 'conectada: tem connected_at');
select public.messaging_save_connection('00000000-0000-0000-0000-00000000155a', 'meta_cloud', '123456', 'connected', '+34911111111', 'Meta (nome novo)');
select pg_temp.expect((select c.connected_at = s.connected_at and c.display_name = 'Meta (nome novo)' from public.messaging_connections c, cstamp s where c.org_id = '00000000-0000-0000-0000-00000000155a'),
  'só o nome mudou: connected_at (desde quando conectada) não é zerado');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_save_connection('00000000-0000-0000-0000-00000000155a', 'waha_qr', 's', 'connected', null, null)$q$) = '22023', 'WAHA não faz parte desta versão');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_save_connection('00000000-0000-0000-0000-00000000155a', 'x', 's', 'connected', null, null)$q$) = '22023', 'provedor inválido');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_save_connection('00000000-0000-0000-0000-00000000155a', 'meta_cloud', 's', 'ligado', null, null)$q$) = '22023', 'situação inválida');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_save_connection('00000000-0000-0000-0000-00000000155a', 'meta_cloud', '   ', 'connected', null, null)$q$) = '22023', 'sessão vazia');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000155011');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_save_connection('00000000-0000-0000-0000-00000000155a', 'meta_cloud', 's', 'connected', null, null)$q$) = '42501', 'recepção não conecta');
select pg_temp.expect((select count(*) from public.messaging_connections) = 1, 'recepção lê a conexão');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000155012');
select pg_temp.expect((select count(*) from public.messaging_connections) = 0, 'outro estúdio não vê a conexão');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_save_connection('00000000-0000-0000-0000-00000000155a', 'meta_cloud', 's', 'connected', null, null)$q$) = '42501', 'outro estúdio não conecta');
select pg_temp.logout();

-- ─── Registro de teste de envio: reservar ANTES, fechar DEPOIS, limite por hora ─────────────────
select pg_temp.login('00000000-0000-0000-0000-000000155010');
insert into ids select 'log1', public.messaging_log_test_send('00000000-0000-0000-0000-00000000155a', 'resend', 'email', 'alguem@teste.local', 'Teste de e-mail');
select pg_temp.expect((select status = 'failed' and error_message = 'Aguardando a resposta do provedor' and purpose = 'teste'
  and created_by = '00000000-0000-0000-0000-000000155010' and org_id = '00000000-0000-0000-0000-00000000155a'
  from public.messaging_provider_log where id = (select v from ids where k = 'log1')), 'reservar: linha de teste do próprio usuário, ainda sem resposta do provedor');
select public.messaging_log_test_result('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'log1'), true, 'msg-1', null);
select pg_temp.expect((select status = 'sent' and provider_message_id = 'msg-1' and error_message is null from public.messaging_provider_log where id = (select v from ids where k = 'log1')), 'fechar: enviado');
select pg_temp.expect(pg_temp.state_of(format($q$select public.messaging_log_test_result('00000000-0000-0000-0000-00000000155a', %L, false, null, 'x')$q$, (select v from ids where k = 'log1'))) = 'P0002', 'não dá para fechar duas vezes nem mudar um envio já fechado');
insert into ids select 'log2', public.messaging_log_test_send('00000000-0000-0000-0000-00000000155a', 'meta_cloud', 'whatsapp', '34600000000', 'Modelo hello_world');
select public.messaging_log_test_result('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'log2'), false, null, repeat('e', 900));
select pg_temp.expect((select status = 'failed' and char_length(error_message) = 500 from public.messaging_provider_log where id = (select v from ids where k = 'log2')), 'fechar: falha com o erro cortado em 500');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_log_test_send('00000000-0000-0000-0000-00000000155a', 'brevo', 'email', 'a', 'b')$q$) = '22023', 'provedor fora do teste');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_log_test_send('00000000-0000-0000-0000-00000000155a', 'waha_qr', 'whatsapp', 'a', 'b')$q$) = '22023', 'WAHA fora desta versão');
select pg_temp.expect(pg_temp.state_of(format($q$select public.messaging_log_test_send('00000000-0000-0000-0000-00000000155a', 'resend', 'email', 'a', %L)$q$, repeat('b', 1001))) = '22023', 'texto de teste até 1000');
-- Não forja pela API: finalidade real, autor alheio, situação "entregue/na fila" e outro estúdio são recusados.
select pg_temp.expect(pg_temp.state_of($q$insert into public.messaging_provider_log (org_id, provider, purpose, recipient, body, status, created_by)
  values ('00000000-0000-0000-0000-00000000155a', 'meta_cloud', 'manual', '34600000000', 'forjado', 'sent', '00000000-0000-0000-0000-000000155010')$q$) = '42501', 'não forja envio de verdade pela API');
select pg_temp.expect(pg_temp.state_of($q$insert into public.messaging_provider_log (org_id, provider, purpose, recipient, body, status, created_by)
  values ('00000000-0000-0000-0000-00000000155a', 'meta_cloud', 'teste', '34600000000', 'em nome de outra', 'sent', '00000000-0000-0000-0000-000000155011')$q$) = '42501', 'nem em nome de outra pessoa');
select pg_temp.expect(pg_temp.state_of($q$insert into public.messaging_provider_log (org_id, provider, purpose, recipient, body, status, created_by)
  values ('00000000-0000-0000-0000-00000000155a', 'meta_cloud', 'teste', '34600000000', 'entregue à mão', 'delivered', '00000000-0000-0000-0000-000000155010')$q$) = '42501', 'pela API só entra "enviado" ou "falhou" (entregue vem do aviso assinado)');
select pg_temp.expect(pg_temp.state_of($q$insert into public.messaging_provider_log (org_id, provider, purpose, recipient, body, created_by)
  values ('00000000-0000-0000-0000-00000000155a', 'meta_cloud', 'teste', '34600000000', 'na fila', '00000000-0000-0000-0000-000000155010')$q$) = '42501', 'nem "na fila"');
select pg_temp.expect(pg_temp.state_of($q$update public.messaging_provider_log set status = 'delivered'$q$) = '42501'
  and (select count(*) from public.messaging_provider_log where status = 'delivered') = 0, 'não há como atualizar o registro pela API (sem permissão)');
-- Fechar o registro de outra pessoa: recusado.
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000155013');
insert into ids select 'log3', public.messaging_log_test_send('00000000-0000-0000-0000-00000000155a', 'resend', 'email', 'gerente@teste.local', 'Teste');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000155010');
select pg_temp.expect(pg_temp.state_of(format($q$select public.messaging_log_test_result('00000000-0000-0000-0000-00000000155a', %L, true, 'x', null)$q$, (select v from ids where k = 'log3'))) = 'P0002', 'não fecha o registro reservado por outra pessoa');
-- Limites: 3 por hora por pessoa e 5 por estúdio (já há 3: dona log1 e log2, gerente log3).
insert into ids select 'log4', public.messaging_log_test_send('00000000-0000-0000-0000-00000000155a', 'resend', 'email', 'a@teste.local', 'Teste');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_log_test_send('00000000-0000-0000-0000-00000000155a', 'resend', 'email', 'c@teste.local', 'Teste')$q$) = 'P0001', 'o 4º teste da MESMA pessoa na hora é recusado (limite por pessoa 3), mesmo com o estúdio abaixo de 5');
select pg_temp.expect((select count(*) from public.messaging_provider_log where purpose = 'teste') = 4, 'a recusa não deixa linha no registro');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000155013');
insert into ids select 'log5', public.messaging_log_test_send('00000000-0000-0000-0000-00000000155a', 'resend', 'email', 'b@teste.local', 'Teste');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_log_test_send('00000000-0000-0000-0000-00000000155a', 'resend', 'email', 'c@teste.local', 'Teste')$q$) = 'P0001', 'o 6º teste do estúdio é recusado (limite por estúdio 5), com a pessoa ainda abaixo de 3');
select pg_temp.expect((select count(*) from public.messaging_provider_log where purpose = 'teste') = 5, 'a recusa do estúdio também não deixa linha');
select pg_temp.logout();
-- Passada uma hora, libera de novo (as linhas antigas saem da conta).
update public.messaging_provider_log set created_at = now() - interval '2 hours' where id in ((select v from ids where k = 'log1'), (select v from ids where k = 'log2'));
select pg_temp.login('00000000-0000-0000-0000-000000155010');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_log_test_send('00000000-0000-0000-0000-00000000155a', 'resend', 'email', 'c@teste.local', 'Teste')$q$) = 'ok', 'depois de uma hora o limite libera');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000155011');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_log_test_send('00000000-0000-0000-0000-00000000155a', 'resend', 'email', 'a', 'b')$q$) = '42501', 'recepção não reserva teste');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_log_test_result('00000000-0000-0000-0000-00000000155a', gen_random_uuid(), true, null, null)$q$) = '42501', 'recepção não fecha teste');
select pg_temp.expect((select count(*) from public.messaging_provider_log) = 6, 'recepção (mensagens.use) lê os registros');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000155012');
select pg_temp.expect(pg_temp.state_of($q$select public.messaging_log_test_result('00000000-0000-0000-0000-00000000155a', gen_random_uuid(), true, null, null)$q$) = '42501', 'outro estúdio não fecha teste (função DEFINER confere o estúdio)');
select pg_temp.logout();
-- Limpa os registros para não pesar nas contagens seguintes.
delete from public.messaging_provider_log;

-- ─── Campanhas ────────────────────────────────────────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000155013');
insert into ids select 'camp', public.marketing_create_campaign('00000000-0000-0000-0000-00000000155a', ' Volta ', ' Descrição ', 'whatsapp_manual', 'inactive_recovery',
  (select v from ids where k = 'tplrev'), '{"channel":"whatsapp_manual","clientStatus":"Ativo","marketingConsent":"missing_or_allowed"}');
select pg_temp.expect((select name = 'Volta' and description = 'Descrição' and status = 'draft' and estimated_audience_count = 2
  and audience_snapshot ->> 'total' = '2' and created_by = '00000000-0000-0000-0000-000000155013' and org_id = '00000000-0000-0000-0000-00000000155a'
  from public.marketing_campaigns where id = (select v from ids where k = 'camp')), 'campanha: rascunho com público estimado calculado no banco');
select pg_temp.expect(pg_temp.aud('MARKETING_CAMPAIGN_CREATED') = 1, 'criar campanha é auditado');
select pg_temp.expect(pg_temp.state_of($q$select public.marketing_create_campaign('00000000-0000-0000-0000-00000000155a', 'x', null, 'whatsapp_manual', 'manual', null, '{"orgId":"x"}')$q$) = '22023', 'filtro com chave desconhecida');
select pg_temp.expect(pg_temp.state_of($q$select public.marketing_create_campaign('00000000-0000-0000-0000-00000000155a', 'x', null, 'whatsapp_manual', 'manual', '00000000-0000-0000-0000-0000000155d9', '{}')$q$) = 'P0002', 'modelo de outro estúdio');
select pg_temp.expect(pg_temp.state_of(format($q$select public.marketing_create_campaign('00000000-0000-0000-0000-00000000155a', %L, null, 'whatsapp_manual', 'manual', null, '{}')$q$, repeat('n', 121))) = '22023', 'nome longo');
select pg_temp.expect(pg_temp.state_of(format($q$select public.marketing_create_campaign('00000000-0000-0000-0000-00000000155a', 'x', %L, 'whatsapp_manual', 'manual', null, '{}')$q$, repeat('d', 501))) = '22023', 'descrição longa');
select pg_temp.expect(pg_temp.state_of($q$select public.marketing_create_campaign('00000000-0000-0000-0000-00000000155a', 'x', null, 'fax', 'manual', null, '{}')$q$) = '22023', 'canal inválido');
select pg_temp.expect(pg_temp.state_of($q$select public.marketing_create_campaign('00000000-0000-0000-0000-00000000155a', 'x', null, 'whatsapp_manual', 'spam', null, '{}')$q$) = '22023', 'finalidade inválida');

-- Consentimento: campanha de "auditoria" (consentimento: qualquer) nunca enfileira quem recusou.
insert into ids select 'audit', public.marketing_create_campaign('00000000-0000-0000-0000-00000000155a', 'Auditoria', null, 'whatsapp_manual', 'manual', null,
  '{"channel":"whatsapp_manual","clientStatus":"Ativo","marketingConsent":"any"}');
select pg_temp.expect((select estimated_audience_count = 5 from public.marketing_campaigns where id = (select v from ids where k = 'audit')), 'auditoria de consentimento estima as 5 (inclui quem recusou)');

-- Preparar a fila (modelo com {cliente}).
select pg_temp.expect((public.marketing_prepare_queue('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'camp')) ->> 'drafts')::int = 2, 'fila: Ana e Bia (Eva sem preferência registrada, Cris e Fran recusaram)');
select pg_temp.expect((select count(*) = 2 and bool_and(status = 'draft' and channel = 'whatsapp_manual' and created_by = '00000000-0000-0000-0000-000000155013' and org_id = '00000000-0000-0000-0000-00000000155a')
  and bool_or(recipient = '+34600000001' and message_body = 'Gracias Ana') and bool_or(recipient = '+34600000002' and message_body = 'Gracias Bia')
  from public.marketing_message_queue where campaign_id = (select v from ids where k = 'camp')), 'fila: destino com DDI e nome no texto');
select pg_temp.expect((public.marketing_prepare_queue('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'camp')) ->> 'drafts')::int = 2, 'preparar de novo devolve 2');
select pg_temp.expect((select count(*) from public.marketing_message_queue where campaign_id = (select v from ids where k = 'camp')) = 2, 'preparar de novo não duplica');
select pg_temp.expect(pg_temp.aud('MARKETING_QUEUE_PREPARED') = 1 and pg_temp.aud('MARKETING_QUEUE_UPDATED') = 0, 'fila: uma auditoria por comando; repreparar sem mudança não mexe em nada');
select pg_temp.expect((select new_data = '{"items": 2, "channel": "whatsapp_manual"}'::jsonb and record_id = (select v from ids where k = 'camp') and user_id = '00000000-0000-0000-0000-000000155013'
  from public.audit_logs where operation = 'MARKETING_QUEUE_PREPARED'), 'auditoria da fila: quem, campanha e quantos');
select pg_temp.expect((public.marketing_prepare_queue('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'audit')) ->> 'drafts')::int = 2, 'campanha de auditoria: 2 na fila');
select pg_temp.expect(not exists (select 1 from public.marketing_message_queue where campaign_id = (select v from ids where k = 'audit') and client_id in
    ('00000000-0000-0000-0000-0000000155c3', '00000000-0000-0000-0000-0000000155c6')), 'campanha de auditoria: quem recusou NUNCA entra na fila');
select pg_temp.logout();

-- Descadastro pela função real do perfil da cliente: sai da fila nova; voltar a aceitar, volta.
select pg_temp.login('00000000-0000-0000-0000-000000155011');
select pg_temp.expect((public.update_client_atomic('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155c1', '{"phone": "+34600000001"}', null, null, false, array['whatsapp_manual']) ->> 'ok')::boolean, 'recepção registra o descadastro da Ana');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000155013');
insert into ids select 'camp2', public.marketing_create_campaign('00000000-0000-0000-0000-00000000155a', 'Depois do descadastro', null, 'whatsapp_manual', 'manual', null,
  '{"channel":"whatsapp_manual","clientStatus":"Ativo","marketingConsent":"missing_or_allowed"}');
select pg_temp.expect((select estimated_audience_count = 1 from public.marketing_campaigns where id = (select v from ids where k = 'camp2')), 'descadastro: a Ana sai do público estimado');
select pg_temp.expect((public.marketing_prepare_queue('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'camp2')) ->> 'drafts')::int = 1, 'descadastro: a fila nova tem 1 item');
select pg_temp.expect((select recipient from public.marketing_message_queue where campaign_id = (select v from ids where k = 'camp2')) = '+34600000002', 'descadastro: a Ana não entra na fila (só a Bia)');
select pg_temp.expect((select message_body = 'Mensagem manual para Bia' and message_subject is null from public.marketing_message_queue where campaign_id = (select v from ids where k = 'camp2')), 'sem modelo: texto padrão com o nome');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000155011');
select pg_temp.expect((public.update_client_atomic('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155c1', '{"phone": "+34600000001"}', null, null, true, array['whatsapp_manual']) ->> 'ok')::boolean, 'volta a aceitar');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000155013');
select pg_temp.expect(pg_temp.audience('{"channel":"whatsapp_manual","clientStatus":"Ativo","marketingConsent":"missing_or_allowed"}', true) = 'Ana,Bia', 'voltou a aceitar: a Ana volta ao público');

-- Arquivar.
select public.marketing_archive_campaign('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'camp2'));
select pg_temp.expect((select status = 'archived' and archived_at is not null from public.marketing_campaigns where id = (select v from ids where k = 'camp2')), 'arquivada');
select pg_temp.expect(pg_temp.aud('MARKETING_CAMPAIGN_ARCHIVED') = 1, 'arquivar é auditado');
select pg_temp.expect(pg_temp.state_of($q$select public.marketing_prepare_queue('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'camp2'))$q$) = '22023', 'campanha arquivada não prepara fila');
select pg_temp.expect(pg_temp.state_of($q$select public.marketing_prepare_queue('00000000-0000-0000-0000-00000000155a', gen_random_uuid())$q$) = 'P0002', 'campanha que não existe');
select pg_temp.expect(pg_temp.state_of($q$select public.marketing_archive_campaign('00000000-0000-0000-0000-00000000155a', gen_random_uuid())$q$) = 'P0002', 'arquivar campanha que não existe');
select pg_temp.logout();

-- Permissão e isolamento das campanhas.
select pg_temp.login('00000000-0000-0000-0000-000000155011');
select pg_temp.expect(pg_temp.state_of($q$select public.marketing_create_campaign('00000000-0000-0000-0000-00000000155a', 'x', null, 'whatsapp_manual', 'manual', null, '{}')$q$) = '42501', 'recepção não cria campanha');
select pg_temp.expect(pg_temp.state_of($q$select public.marketing_prepare_queue('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'camp'))$q$) = '42501', 'recepção não prepara fila');
select pg_temp.expect(pg_temp.state_of($q$select public.marketing_archive_campaign('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'camp'))$q$) = '42501', 'recepção não arquiva');
select pg_temp.expect(pg_temp.state_of($q$update public.marketing_campaigns set status = 'sent' where org_id = '00000000-0000-0000-0000-00000000155a'$q$) = 'ok'
  and (select count(*) from public.marketing_campaigns where status = 'sent') = 0, 'recepção não muda campanha pela tabela');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000155012');
select pg_temp.expect(pg_temp.state_of($q$select public.marketing_prepare_queue('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'camp'))$q$) = '42501', 'outro estúdio não prepara fila');
select pg_temp.expect(pg_temp.state_of($q$select public.marketing_archive_campaign('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'camp'))$q$) = '42501', 'nem arquiva');
select pg_temp.expect((select count(*) from public.marketing_message_queue) = 0 and (select count(*) from public.marketing_campaigns) = 0, 'nem lê pela tabela');
select pg_temp.logout();
-- Dona do B tentando mandar o id da campanha do A com o próprio estúdio: não acha.
select pg_temp.login('00000000-0000-0000-0000-000000155012');
select pg_temp.expect(pg_temp.state_of($q$select public.marketing_prepare_queue('00000000-0000-0000-0000-00000000155b', (select v from ids where k = 'camp'))$q$) = 'P0002', 'id de campanha do A com o estúdio B: não encontrada');
select pg_temp.logout();

-- ─── Telas: histórico, Campanhas e Avaliações ─────────────────────────────────────────────────────
-- Eventos de entrega (o mais recente vale).
select pg_temp.login('00000000-0000-0000-0000-000000155010');
insert into public.marketing_message_events (org_id, queue_id, campaign_id, client_id, channel, event_type, status, created_at, created_by)
select q.org_id, q.id, q.campaign_id, q.client_id, q.channel, 'manual_ready', 'manual_ready', now() - interval '2 hours', '00000000-0000-0000-0000-000000155010'
from public.marketing_message_queue q where q.campaign_id = (select v from ids where k = 'camp') and q.recipient = '+34600000001';
insert into public.marketing_message_events (org_id, queue_id, campaign_id, client_id, channel, event_type, status, created_at, created_by)
select q.org_id, q.id, q.campaign_id, q.client_id, q.channel, 'manual_link_opened', 'opened_manual_link', now() - interval '1 hour', '00000000-0000-0000-0000-000000155010'
from public.marketing_message_queue q where q.campaign_id = (select v from ids where k = 'camp') and q.recipient = '+34600000001';
select pg_temp.logout();

select pg_temp.login('00000000-0000-0000-0000-000000155011');
select pg_temp.expect((select jsonb_array_length(h -> 'items') = 5 and (h ->> 'truncated') = 'false' and (h ->> 'templates_count')::int = 5
  from (select public.messages_history_screen('00000000-0000-0000-0000-00000000155a') h) x), 'histórico: 5 itens (2 + 2 + 1), selo de modelos');
select pg_temp.expect((select i ->> 'client_name' = 'Ana' and i ->> 'template_name' = 'Agradecimento' and i ->> 'campaign_name' = 'Volta'
  and i ->> 'event_status' = 'opened_manual_link' and i ->> 'sent_by' = 'Gerente Gabi' and i ->> 'status' = 'draft'
  from jsonb_array_elements(public.messages_history_screen('00000000-0000-0000-0000-00000000155a') -> 'items') i
  where i ->> 'client_name' = 'Ana' and i ->> 'campaign_name' = 'Volta'), 'histórico: nomes, último evento e quem preparou');
select pg_temp.expect((select (i -> 'template_name') = 'null'::jsonb and i ->> 'sent_by' = 'Gerente Gabi'
  from jsonb_array_elements(public.messages_history_screen('00000000-0000-0000-0000-00000000155a') -> 'items') i
  where i ->> 'campaign_name' = 'Depois do descadastro'), 'histórico: item sem modelo traz nulo (a tela mostra o texto padrão)');
select pg_temp.expect(not ((public.messages_history_screen('00000000-0000-0000-0000-00000000155a') -> 'items' -> 0) ? 'recipient'), 'histórico não traz o destino (telefone)');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000155012');
select pg_temp.expect(pg_temp.state_of($q$select public.messages_history_screen('00000000-0000-0000-0000-00000000155a')$q$) = '42501', 'outro estúdio não lê o histórico');
select pg_temp.expect(jsonb_array_length(public.messages_history_screen('00000000-0000-0000-0000-00000000155b') -> 'items') = 0, 'o histórico do B está vazio');
select pg_temp.logout();

select pg_temp.login('00000000-0000-0000-0000-000000155013');
select pg_temp.expect((select jsonb_array_length(s -> 'campaigns') = 3 and jsonb_array_length(s -> 'templates') = 5 and jsonb_array_length(s -> 'queue') = 5
  and jsonb_array_length(s -> 'services') = 1 and s -> 'truncated' = '[]'::jsonb
  from (select public.marketing_campaigns_screen('00000000-0000-0000-0000-00000000155a', '[]') s) x), 'campanhas: listas e só serviços ativos');
select pg_temp.expect(((public.marketing_campaigns_screen('00000000-0000-0000-0000-00000000155a', '[]') -> 'campaigns' -> 0) ?& array['id','name','status','planned_channel','purpose','estimated_audience_count'])
  and ((public.marketing_campaigns_screen('00000000-0000-0000-0000-00000000155a', '[]') -> 'queue' -> 0) ?& array['id','recipient','status','message_body']), 'campanhas: colunas da tela');
select pg_temp.expect((select (a -> 'count')::int from jsonb_array_elements(public.marketing_campaigns_screen('00000000-0000-0000-0000-00000000155a',
  '[{"key":"all","filter":{"channel":"whatsapp_manual","clientStatus":"Ativo","marketingConsent":"missing_or_allowed"}},{"key":"vip","filter":{"channel":"whatsapp_manual","clientStatus":"Ativo","marketingConsent":"missing_or_allowed","tagsAny":["VIP"]}}]') -> 'audiences') a where a ->> 'key' = 'all') = 2,
  'campanhas: público estimado por grupo calculado no banco (só quem aceitou: Ana e Bia)');
-- Aviso de Campanhas: ativas (não mescladas nem bloqueadas) que ainda não autorizaram = Cris e Fran (recusaram) e Eva (sem preferência).
select pg_temp.expect((public.marketing_campaigns_screen('00000000-0000-0000-0000-00000000155a', '[]') ->> 'unauthorized_count')::int = 3,
  'campanhas: contagem do aviso "ainda não autorizaram" (Cris, Eva, Fran; Dani e Gabi são inativas)');
select pg_temp.expect((select string_agg(full_name || ':' || (public.marketing_state(c) ->> 'whatsapp'), ',' order by full_name) from public.clients c
  where c.org_id = '00000000-0000-0000-0000-00000000155a' and c.full_name in ('Ana', 'Cris', 'Eva')) = 'Ana:authorized,Cris:refused,Eva:none',
  'estado de marketing no WhatsApp: aceitou, recusou e sem preferência');
select pg_temp.expect((select string_agg(full_name, ',' order by full_name) from public.clients c
  where c.org_id = '00000000-0000-0000-0000-00000000155a' and c.status = 'Ativo' and c.merged_into is null and not public.marketing_authorized(c)
    and c.full_name in ('Ana', 'Bia', 'Cris', 'Eva', 'Fran')) = 'Cris,Eva,Fran', 'filtro "sem consentimento" da lista (coluna calculada marketing_authorized)');
select pg_temp.expect((select (public.client_profile('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155c5', array['Concluído'], false) -> 'client' -> 'marketing_state') = '{"whatsapp": "none", "email": "none"}'::jsonb),
  'perfil: cliente sem preferência vem sem autorização em todos os meios');
-- Por meio: cliente que aceitou WhatsApp e recusou e-mail.
select pg_temp.logout();
insert into public.clients (id, org_id, full_name, phone, phone_country_code, status) values
  ('00000000-0000-0000-0000-0000000155ce', '00000000-0000-0000-0000-00000000155a', 'Mix Meios', '+34600000010', '+34', 'Ativo');
insert into public.client_marketing_preferences (org_id, client_id, channel, marketing_allowed, opted_out_at) values
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155ce', 'whatsapp_manual', true, null),
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155ce', 'email_provider', false, now());
select pg_temp.login('00000000-0000-0000-0000-000000155013');
select pg_temp.expect((select public.marketing_state(c) = '{"whatsapp": "authorized", "email": "refused"}'::jsonb from public.clients c where c.id = '00000000-0000-0000-0000-0000000155ce'),
  'aceitou WhatsApp e recusou e-mail: estado por meio');
select pg_temp.expect((select public.marketing_authorized(c) from public.clients c where c.id = '00000000-0000-0000-0000-0000000155ce'),
  'aceitou WhatsApp e recusou e-mail: autorizada em algum meio (fora do filtro "sem consentimento")');
select pg_temp.expect((public.client_profile('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155ce', array['Concluído'], false) -> 'client' -> 'marketing_state') = '{"whatsapp": "authorized", "email": "refused"}'::jsonb,
  'perfil devolve o estado por meio');
select pg_temp.expect(pg_temp.audience('{"channel":"whatsapp_manual","clientStatus":"Ativo","marketingConsent":"any"}', true) like '%Mix Meios%'
  and pg_temp.audience('{"channel":"email_provider","clientStatus":"Ativo","marketingConsent":"any"}', true) not like '%Mix Meios%',
  'o público segue o meio: entra no WhatsApp, fica fora do e-mail');
select pg_temp.expect((public.marketing_campaigns_screen('00000000-0000-0000-0000-00000000155a', '[]') ->> 'unauthorized_count')::int = 3
  and (public.marketing_campaigns_screen('00000000-0000-0000-0000-00000000155a', '[]') -> 'unauthorized_by_channel' ->> 'whatsapp_manual')::int = 3
  and (public.marketing_campaigns_screen('00000000-0000-0000-0000-00000000155a', '[]') -> 'unauthorized_by_channel' ->> 'email_provider')::int = 6,
  'aviso: geral = nenhum meio (Mix Meios não conta); por meio do canal: WhatsApp 3, e-mail 6 (Ana, Bia, Cris, Eva, Fran sem e-mail; Mix recusou)');
select pg_temp.logout();
delete from public.clients where id = '00000000-0000-0000-0000-0000000155ce';
select pg_temp.login('00000000-0000-0000-0000-000000155013');
select pg_temp.expect(pg_temp.state_of($q$select public.marketing_campaigns_screen('00000000-0000-0000-0000-00000000155a', '{}')$q$) = '22023', 'lista de públicos inválida');
select pg_temp.expect(pg_temp.state_of($q$select public.marketing_campaigns_screen('00000000-0000-0000-0000-00000000155a', (select jsonb_agg('{"key":"a","filter":{}}'::jsonb) from generate_series(1, 11)))$q$) = '22023', 'mais de 10 públicos');
select pg_temp.expect((select jsonb_array_length(s -> 'templates') = 1 and (s -> 'templates' -> 0 ->> 'name') = 'Agradecimento'
  and (s ->> 'month_sends')::int = 2 and jsonb_array_length(s -> 'sends') = 2
  from (select public.marketing_reviews_screen('00000000-0000-0000-0000-00000000155a') s) x), 'avaliações: só modelos de avaliação e os envios deles (2 itens do modelo Agradecimento neste mês)');
select pg_temp.logout();

-- ─── Auditoria que ninguém forja ──────────────────────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000155010');
select pg_temp.expect(pg_temp.state_of($q$insert into public.audit_logs (org_id, user_id, table_name, operation) values
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-000000155010', 'messaging_connections', 'MESSAGING_CHANNEL_CONNECTED')$q$) = '42501', 'conexão auditada à mão: recusada');
select pg_temp.expect(pg_temp.state_of($q$insert into public.audit_logs (org_id, user_id, table_name, operation) values
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-000000155010', 'marketing_campaigns', 'MARKETING_CAMPAIGN_CREATED')$q$) = '42501', 'campanha auditada à mão: recusada');
select pg_temp.expect(pg_temp.state_of($q$insert into public.audit_logs (org_id, user_id, table_name, operation) values
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-000000155010', 'marketing_message_queue', 'MARKETING_QUEUE_PREPARED')$q$) = '42501', 'fila auditada à mão: recusada');
select pg_temp.logout();

-- ═══ Revisão (14/11): recusa por meio, mesclada e bloqueada, preparar de novo, guardas, leitura, lotes ═══
-- Clientes de teste, todos com a etiqueta NEW155 (os filtros abaixo só olham para elas).
insert into public.clients (id, org_id, full_name, phone, phone_country_code, email, tags, status) values
  ('00000000-0000-0000-0000-0000000155b1', '00000000-0000-0000-0000-00000000155a', 'Nova Aceita', '+34610000001', '+34', 'n1@m.local', '{NEW155}', 'Ativo'),
  ('00000000-0000-0000-0000-0000000155b2', '00000000-0000-0000-0000-00000000155a', 'Nova Recusou Provider', '+34610000002', '+34', 'n2@m.local', '{NEW155}', 'Ativo'),
  ('00000000-0000-0000-0000-0000000155b3', '00000000-0000-0000-0000-00000000155a', 'Nova Recusou Manual', '+34610000003', '+34', 'n3@m.local', '{NEW155}', 'Ativo'),
  ('00000000-0000-0000-0000-0000000155b5', '00000000-0000-0000-0000-00000000155a', 'Nova Bloqueada', '+34610000005', '+34', 'n5@m.local', '{NEW155}', 'Ativo'),
  ('00000000-0000-0000-0000-0000000155b6', '00000000-0000-0000-0000-00000000155a', 'Nova Email Recusou', '+34610000006', '+34', 'n6@m.local', '{NEW155}', 'Ativo'),
  ('00000000-0000-0000-0000-0000000155b8', '00000000-0000-0000-0000-00000000155a', 'Mesc Destino', '+34610000008', '+34', 'n8@m.local', '{NEW155}', 'Ativo'),
  ('00000000-0000-0000-0000-0000000155b9', '00000000-0000-0000-0000-00000000155a', 'Mesc Origem', '+34610000009', '+34', 'n9@m.local', '{NEW155}', 'Ativo');
update public.clients set blocked_at = now() where id = '00000000-0000-0000-0000-0000000155b5';
insert into public.client_marketing_preferences (org_id, client_id, channel, marketing_allowed, opted_out_at) values
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155b2', 'whatsapp_provider', false, now()),
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155b3', 'whatsapp_manual', false, null),
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155b6', 'email_provider', false, now());
-- Marketing só para quem disse SIM (20261114110000): as clientes de teste aceitaram WhatsApp e e-mail, exceto onde há recusa
-- registrada acima; assim os casos abaixo continuam provando a recusa por MEIO, a mesclada e a bloqueada.
insert into public.client_marketing_preferences (org_id, client_id, channel, marketing_allowed, opted_out_at)
select c.org_id, c.id, ch, true, null from public.clients c cross join unnest(array['whatsapp_manual', 'email_provider']) ch
where c.org_id = '00000000-0000-0000-0000-00000000155a' and c.tags @> '{NEW155}'
on conflict (org_id, client_id, channel) do nothing;
-- Estúdio B: campanha e item de fila (para os testes de "outro estúdio").
insert into public.client_marketing_preferences (org_id, client_id, channel, marketing_allowed) values
  ('00000000-0000-0000-0000-00000000155b', '00000000-0000-0000-0000-0000000155c9', 'whatsapp_manual', true);
insert into public.marketing_campaigns (id, org_id, name, planned_channel) values
  ('00000000-0000-0000-0000-0000000155cb', '00000000-0000-0000-0000-00000000155b', 'Camp B', 'whatsapp_manual');
insert into public.marketing_message_queue (id, org_id, campaign_id, client_id, channel, recipient, message_body, idempotency_key) values
  ('00000000-0000-0000-0000-0000000155cc', '00000000-0000-0000-0000-00000000155b', '00000000-0000-0000-0000-0000000155cb',
   '00000000-0000-0000-0000-0000000155c9', 'whatsapp_manual', '+34600000009', 'oi B', 'kb');

create function pg_temp.new_audience(p_channel text, p_consent text default 'missing_or_allowed', p_enforce boolean default true) returns text language sql as $$
  select pg_temp.audience(jsonb_build_object('channel', p_channel, 'tagsAny', jsonb_build_array('NEW155'), 'clientStatus', 'Ativo', 'marketingConsent', p_consent)::text, p_enforce)
$$;
grant execute on function pg_temp.new_audience(text, text, boolean) to authenticated;

-- 1. Recusa por MEIO: quem recusou em qualquer canal de WhatsApp fica fora dos dois; e-mail é outro meio.
select pg_temp.login('00000000-0000-0000-0000-000000155013');
select pg_temp.expect(pg_temp.new_audience('whatsapp_manual') = 'Mesc Destino,Mesc Origem,Nova Aceita,Nova Email Recusou',
  'whatsapp_manual: fora quem recusou whatsapp_provider (Nova Recusou Provider) e quem recusou whatsapp_manual (Nova Recusou Manual), a bloqueada');
select pg_temp.expect(pg_temp.new_audience('whatsapp_provider') = 'Mesc Destino,Mesc Origem,Nova Aceita,Nova Email Recusou',
  'whatsapp_provider: recusou WhatsApp em qualquer canal, fora (a recusa de whatsapp_manual vale aqui)');
select pg_temp.expect(pg_temp.new_audience('email_provider') = 'Mesc Destino,Mesc Origem,Nova Aceita,Nova Recusou Manual,Nova Recusou Provider',
  'email_provider: quem só recusou WhatsApp continua; quem recusou e-mail sai');
select pg_temp.expect(pg_temp.new_audience('whatsapp_manual', 'allowed') = 'Mesc Destino,Mesc Origem,Nova Aceita,Nova Email Recusou', 'só quem aceitou de forma registrada: as mesmas');
-- 2. Mesclada e bloqueada: sempre fora, até na auditoria de consentimento (consentimento: qualquer, sem impor).
select pg_temp.expect(pg_temp.new_audience('whatsapp_manual', 'any', false) = 'Mesc Destino,Mesc Origem,Nova Aceita,Nova Email Recusou,Nova Recusou Manual,Nova Recusou Provider',
  'auditoria de consentimento: lista quem recusou, mas nunca a bloqueada');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000155010');
select pg_temp.expect((public.merge_clients_atomic('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155b8', '00000000-0000-0000-0000-0000000155b9')) is not null, 'mescla a origem no destino (função real)');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000155013');
select pg_temp.expect((select merged_into from public.clients where id = '00000000-0000-0000-0000-0000000155b9') = '00000000-0000-0000-0000-0000000155b8', 'a origem ficou marcada como mesclada');
select pg_temp.expect(pg_temp.new_audience('whatsapp_manual') = 'Mesc Destino,Nova Aceita,Nova Email Recusou', 'mesclada fora do público (o destino fica)');
select pg_temp.expect(pg_temp.new_audience('whatsapp_manual', 'any', false) not like '%Mesc Origem%', 'mesclada fora até com consentimento "qualquer"');
select pg_temp.expect(pg_temp.state_of($q$select * from public.marketing_audience('00000000-0000-0000-0000-00000000155a', '{"channel":"fax"}', false)$q$) = '22023', 'canal do filtro fora da lista: recusa');

-- 5. Canal único: o planejado manda; filtro sem canal usa o planejado; filtro com outro canal é recusado.
insert into ids select 'cwp', public.marketing_create_campaign('00000000-0000-0000-0000-00000000155a', 'WhatsApp automático', null, 'whatsapp_provider', 'manual', null,
  '{"tagsAny":["NEW155"],"clientStatus":"Ativo","marketingConsent":"missing_or_allowed"}');
select pg_temp.expect((select audience_filter ->> 'channel' = 'whatsapp_provider' and estimated_audience_count = 3 from public.marketing_campaigns where id = (select v from ids where k = 'cwp')),
  'filtro sem canal guarda o planejado; a estimativa já exclui quem recusou o meio');
select pg_temp.expect(pg_temp.state_of($q$select public.marketing_create_campaign('00000000-0000-0000-0000-00000000155a', 'x', null, 'whatsapp_provider', 'manual', null, '{"channel":"email_provider"}')$q$) = '22023', 'filtro com outro canal: recusa');
select pg_temp.expect((public.marketing_prepare_queue('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'cwp')) ->> 'drafts')::int = 3, 'fila da campanha de whatsapp_provider: 3 clientes');
select pg_temp.expect((select string_agg(c.full_name, ',' order by c.full_name) from public.marketing_message_queue q join public.clients c on c.id = q.client_id
  where q.campaign_id = (select v from ids where k = 'cwp')) = 'Mesc Destino,Nova Aceita,Nova Email Recusou',
  'quem recusou WhatsApp (manual ou provider) está fora da campanha whatsapp_provider; mesclada e bloqueada também');
-- Modelo: arquivado ou de outro canal não vale para a campanha.
insert into ids select 'tplemail', public.messaging_save_template('00000000-0000-0000-0000-00000000155a', null, 'Só e-mail', 'email_provider', 'manual', 'pt', 'Assunto', 'Olá');
select pg_temp.expect(pg_temp.state_of(format($q$select public.marketing_create_campaign('00000000-0000-0000-0000-00000000155a', 'x', null, 'whatsapp_manual', 'manual', %L, '{}')$q$, (select v from ids where k = 'tplemail'))) = '22023', 'modelo de outro canal');
insert into ids select 'tplarq', public.messaging_save_template('00000000-0000-0000-0000-00000000155a', null, 'Arquivado', 'whatsapp_manual', 'manual', 'pt', null, 'Olá');
select public.messaging_archive_template('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'tplarq'), true);
select pg_temp.expect(pg_temp.state_of(format($q$select public.marketing_create_campaign('00000000-0000-0000-0000-00000000155a', 'x', null, 'whatsapp_manual', 'manual', %L, '{}')$q$, (select v from ids where k = 'tplarq'))) = '22023', 'modelo arquivado');
select pg_temp.expect(not exists (select 1 from jsonb_array_elements(public.marketing_campaigns_screen('00000000-0000-0000-0000-00000000155a', '[]') -> 'templates') t
  where (t ->> 'id')::uuid = (select v from ids where k = 'tplarq')), 'a tela de Campanhas não oferece modelo arquivado');
select pg_temp.logout();

-- 3. Preparar de novo a MESMA campanha: o que saiu de rascunho não reabre; quem saiu do público vira "ignorado".
select pg_temp.login('00000000-0000-0000-0000-000000155013');
insert into ids select 'crep', public.marketing_create_campaign('00000000-0000-0000-0000-00000000155a', 'Repreparar', null, 'whatsapp_manual', 'manual', null,
  '{"tagsAny":["NEW155"],"clientStatus":"Ativo","marketingConsent":"missing_or_allowed"}');
select pg_temp.expect((public.marketing_prepare_queue('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'crep')) ->> 'drafts')::int = 3, 'repreparar: 1ª vez, 3 rascunhos (Destino, Aceita, Email Recusou)');
update public.marketing_message_queue set status = 'manual_ready'
  where campaign_id = (select v from ids where k = 'crep') and client_id = '00000000-0000-0000-0000-0000000155b1';
update public.marketing_message_queue set status = 'cancelled'
  where campaign_id = (select v from ids where k = 'crep') and client_id = '00000000-0000-0000-0000-0000000155b6';
select pg_temp.logout();
-- A Mesc Destino sai do público (descadastro) e chega uma cliente nova.
update public.client_marketing_preferences set marketing_allowed = false, opted_out_at = now()
  where client_id = '00000000-0000-0000-0000-0000000155b8' and channel = 'whatsapp_manual';
insert into public.clients (id, org_id, full_name, phone, phone_country_code, tags, status) values
  ('00000000-0000-0000-0000-0000000155b7', '00000000-0000-0000-0000-00000000155a', 'Nova Tardia', '+34610000007', '+34', '{NEW155}', 'Ativo');
insert into public.client_marketing_preferences (org_id, client_id, channel, marketing_allowed) values
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155b7', 'whatsapp_manual', true);
select pg_temp.login('00000000-0000-0000-0000-000000155013');
update public.marketing_campaigns set template_id = (select v from ids where k = 'tplrev') where id = (select v from ids where k = 'crep');
select pg_temp.expect((public.marketing_prepare_queue('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'crep')) ->> 'added')::int = 1, 'repreparar: entrou só a cliente nova');
create function pg_temp.qstatus(p_client uuid) returns text language sql as $$
  select status from public.marketing_message_queue where campaign_id = (select v from ids where k = 'crep') and client_id = p_client
$$;
grant execute on function pg_temp.qstatus(uuid) to authenticated;
select pg_temp.expect(pg_temp.qstatus('00000000-0000-0000-0000-0000000155b1') = 'manual_ready', 'repreparar: item pronto continua pronto (não reabre)');
select pg_temp.expect(pg_temp.qstatus('00000000-0000-0000-0000-0000000155b6') = 'cancelled', 'repreparar: item cancelado continua cancelado');
select pg_temp.expect(pg_temp.qstatus('00000000-0000-0000-0000-0000000155b8') = 'skipped', 'repreparar: rascunho de quem saiu do público vira ignorado');
select pg_temp.expect(pg_temp.qstatus('00000000-0000-0000-0000-0000000155b7') = 'draft', 'repreparar: cliente nova em rascunho');
select pg_temp.expect((select message_body = 'Gracias Nova Tardia' from public.marketing_message_queue where campaign_id = (select v from ids where k = 'crep') and client_id = '00000000-0000-0000-0000-0000000155b7'),
  'repreparar: o texto do modelo (agora ligado) entra na cliente nova');
select pg_temp.expect((select message_body <> 'Gracias Aceita' from public.marketing_message_queue where campaign_id = (select v from ids where k = 'crep') and client_id = '00000000-0000-0000-0000-0000000155b1'),
  'o item pronto não é reescrito');
select pg_temp.expect(pg_temp.aud('MARKETING_QUEUE_UPDATED') >= 1, 'a mudança do rascunho para ignorado é auditada');
select pg_temp.logout();
-- Volta a aceitar: o item ignorado continua ignorado (não reabre), e nada novo entra.
update public.client_marketing_preferences set marketing_allowed = true, opted_out_at = null
  where client_id = '00000000-0000-0000-0000-0000000155b8' and channel = 'whatsapp_manual';
select pg_temp.login('00000000-0000-0000-0000-000000155013');
select pg_temp.expect((select (r ->> 'added')::int = 0 and (r ->> 'drafts')::int = 1 and pg_temp.qstatus('00000000-0000-0000-0000-0000000155b8') = 'skipped'
  from (select public.marketing_prepare_queue('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'crep')) r) x), 'quem voltou ao público continua ignorado nesta campanha');
-- Item já PRONTO de quem recusou depois: preparar de novo também o marca como ignorado (e o pronto de quem aceita fica).
select pg_temp.expect(pg_temp.qstatus('00000000-0000-0000-0000-0000000155b1') = 'manual_ready', 'antes: Nova Aceita continua pronta');
select pg_temp.logout();
insert into public.client_marketing_preferences (org_id, client_id, channel, marketing_allowed, opted_out_at) values
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155b1', 'whatsapp_provider', false, now());
select pg_temp.login('00000000-0000-0000-0000-000000155013');
select public.marketing_prepare_queue('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'crep'));
select pg_temp.expect(pg_temp.qstatus('00000000-0000-0000-0000-0000000155b1') = 'skipped', 'preparar de novo: item PRONTO de quem recusou o meio (outro canal da mesma família) vira ignorado');
select pg_temp.logout();
delete from public.client_marketing_preferences where client_id = '00000000-0000-0000-0000-0000000155b1' and channel = 'whatsapp_provider';
select pg_temp.logout();

-- 6. Guarda no banco: vale também para quem grava a tabela direto.
select pg_temp.login('00000000-0000-0000-0000-000000155013');
select pg_temp.expect(pg_temp.state_of($q$insert into public.marketing_message_queue (org_id, client_id, channel, recipient, message_body, idempotency_key) values
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155c5', 'whatsapp_manual', '+34610000055', 'x', 'g0')$q$) = '23514', 'guarda: cliente SEM preferência registrada não entra na fila (marketing só para quem disse SIM)');
select pg_temp.expect(pg_temp.state_of($q$insert into public.marketing_message_queue (org_id, client_id, channel, recipient, message_body, idempotency_key) values
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155b2', 'whatsapp_manual', '+34610000002', 'x', 'g1')$q$) = '23514', 'guarda: recusou o meio (whatsapp_provider vale para whatsapp_manual)');
select pg_temp.expect(pg_temp.state_of($q$insert into public.marketing_message_queue (org_id, client_id, channel, recipient, message_body, idempotency_key) values
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155b3', 'whatsapp_provider', '+34610000003', 'x', 'g2')$q$) = '23514', 'guarda: recusou whatsapp_manual, recusa também em whatsapp_provider');
select pg_temp.expect(pg_temp.state_of($q$insert into public.marketing_message_queue (org_id, client_id, channel, recipient, message_body, idempotency_key) values
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155b9', 'whatsapp_manual', '+34610000009', 'x', 'g3')$q$) = '23514', 'guarda: cliente mesclada');
select pg_temp.expect(pg_temp.state_of($q$insert into public.marketing_message_queue (org_id, client_id, channel, recipient, message_body, idempotency_key) values
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155b5', 'whatsapp_manual', '+34610000005', 'x', 'g4')$q$) = '23514', 'guarda: cliente bloqueada');
select pg_temp.expect(pg_temp.state_of($q$insert into public.marketing_message_queue (org_id, client_id, channel, recipient, message_body, idempotency_key) values
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155c9', 'whatsapp_manual', '+34600000009', 'x', 'g5')$q$) = '23514', 'guarda: cliente de outro estúdio');
select pg_temp.expect(pg_temp.state_of($q$insert into public.marketing_message_queue (org_id, campaign_id, client_id, channel, recipient, message_body, idempotency_key) values
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155cb', '00000000-0000-0000-0000-0000000155b1', 'whatsapp_manual', '+34610000001', 'x', 'g6')$q$) = '23514', 'guarda: campanha de outro estúdio');
select pg_temp.expect(pg_temp.state_of($q$insert into public.marketing_message_queue (org_id, template_id, client_id, channel, recipient, message_body, idempotency_key) values
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155d9', '00000000-0000-0000-0000-0000000155b1', 'whatsapp_manual', '+34610000001', 'x', 'g7')$q$) = '23514', 'guarda: modelo de outro estúdio');
select pg_temp.expect(pg_temp.state_of($q$insert into public.marketing_message_queue (org_id, client_id, channel, recipient, message_body, idempotency_key) values
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155b1', 'whatsapp_manual', '+34610000001', 'x', 'g8')$q$) = 'ok', 'guarda: cliente que aceita entra');
-- Histórico de quem recusou: cancelar/ignorar sempre pode; voltar a rascunho/pronto não.
insert into public.marketing_message_queue (org_id, client_id, channel, recipient, message_body, status, idempotency_key) values
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155b2', 'whatsapp_manual', '+34610000002', 'x', 'cancelled', 'g9');
select pg_temp.expect(pg_temp.state_of($q$update public.marketing_message_queue set status = 'draft' where idempotency_key = 'g9'$q$) = '23514', 'guarda: não reabre item de quem recusou');
select pg_temp.expect(pg_temp.state_of($q$update public.marketing_message_queue set status = 'manual_ready' where idempotency_key = 'g9'$q$) = '23514', 'guarda: nem marca como pronto');
select pg_temp.expect(pg_temp.state_of($q$update public.marketing_message_queue set status = 'skipped' where idempotency_key = 'g9'$q$) = 'ok', 'guarda: ignorar é sempre permitido');
select pg_temp.expect(pg_temp.state_of($q$update public.marketing_message_queue set client_id = '00000000-0000-0000-0000-0000000155c9' where idempotency_key = 'g8'$q$) = '23514', 'guarda: não troca para cliente de outro estúdio');
select pg_temp.expect(pg_temp.state_of($q$update public.marketing_message_queue set campaign_id = '00000000-0000-0000-0000-0000000155cb' where idempotency_key = 'g8'$q$) = '23514', 'guarda: não troca para campanha de outro estúdio');
-- Campanha com modelo de outro estúdio (gatilho).
select pg_temp.expect(pg_temp.state_of($q$update public.marketing_campaigns set template_id = '00000000-0000-0000-0000-0000000155d9' where name = 'Repreparar'$q$) = '23514', 'guarda: campanha com modelo de outro estúdio');
select pg_temp.logout();

-- O estúdio de uma linha nunca muda: pessoa com mensagens.configure nos DOIS estúdios não move linha de um para o outro.
insert into auth.users (id, email) values ('00000000-0000-0000-0000-000000155016', 'dois@m155.local');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000155016', '00000000-0000-0000-0000-00000000155a', 'owner'),
  ('00000000-0000-0000-0000-000000155016', '00000000-0000-0000-0000-00000000155b', 'owner');
select pg_temp.login('00000000-0000-0000-0000-000000155016');
select pg_temp.expect(pg_temp.state_of($q$update public.marketing_message_queue set org_id = '00000000-0000-0000-0000-00000000155b' where idempotency_key = 'g8'$q$) = '23514', 'org_id da fila não muda');
select pg_temp.expect(pg_temp.state_of($q$update public.marketing_message_queue set org_id = '00000000-0000-0000-0000-00000000155b', campaign_id = '00000000-0000-0000-0000-0000000155cb', client_id = '00000000-0000-0000-0000-0000000155c9' where idempotency_key = 'g8'$q$) = '23514', 'nem trocando junto cliente e campanha para o outro estúdio');
select pg_temp.expect(pg_temp.state_of($q$update public.marketing_message_templates set org_id = '00000000-0000-0000-0000-00000000155b' where name = 'Só e-mail'$q$) = '23514', 'org_id do modelo não muda');
select pg_temp.expect(pg_temp.state_of($q$update public.marketing_campaigns set org_id = '00000000-0000-0000-0000-00000000155b' where name = 'Repreparar'$q$) = '23514', 'org_id da campanha não muda');
select pg_temp.state_of($q$update public.marketing_message_events set org_id = '00000000-0000-0000-0000-00000000155b'$q$);
select pg_temp.expect((select count(*) from public.marketing_message_events where org_id = '00000000-0000-0000-0000-00000000155b') = 0, 'org_id do evento não muda (a API nem atualiza evento; o gatilho vale se uma política surgir)');
select pg_temp.expect((select count(*) from pg_trigger where tgname = 'messaging_org_immutable' and not tgisinternal) = 6, 'o gatilho de estúdio imutável está nas 6 tabelas');
select pg_temp.expect(pg_temp.state_of($q$update public.messaging_provider_log set org_id = '00000000-0000-0000-0000-00000000155b' where id = (select id from public.messaging_provider_log where org_id = '00000000-0000-0000-0000-00000000155a' limit 1)$q$) = '42501', 'registro de envios: sem UPDATE para a API');
select pg_temp.expect((select count(*) from public.marketing_message_queue where org_id = '00000000-0000-0000-0000-00000000155b') = 1, 'a fila do outro estúdio continua só com a linha dele');
select pg_temp.logout();

-- Mesclar quando a cliente mantida recusou o meio: a mesclagem funciona e o rascunho movido vira "ignorado".
insert into public.clients (id, org_id, full_name, phone, tags, status) values
  ('00000000-0000-0000-0000-0000000155ba', '00000000-0000-0000-0000-00000000155a', 'Mesc Origem 2', '+34610000010', '{NEW155}', 'Ativo');
insert into public.client_marketing_preferences (org_id, client_id, channel, marketing_allowed) values
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155ba', 'whatsapp_manual', true);
insert into public.marketing_message_queue (id, org_id, client_id, channel, recipient, message_body, status, idempotency_key) values
  ('00000000-0000-0000-0000-0000000155bb', '00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155ba', 'whatsapp_manual', '+34610000010', 'x', 'draft', 'g10');
select pg_temp.login('00000000-0000-0000-0000-000000155010');
select pg_temp.expect((public.merge_clients_atomic('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155b2', '00000000-0000-0000-0000-0000000155ba')) is not null, 'mescla para uma cliente que recusou: a mesclagem não quebra');
select pg_temp.logout();
select pg_temp.expect((select client_id = '00000000-0000-0000-0000-0000000155b2' and status = 'skipped' from public.marketing_message_queue where id = '00000000-0000-0000-0000-0000000155bb'),
  'o rascunho movido para quem recusou vira ignorado');

-- Eventos: só os manuais, com o próprio usuário; fila/campanha/cliente do mesmo estúdio.
select pg_temp.login('00000000-0000-0000-0000-000000155013');
select pg_temp.expect(pg_temp.state_of($q$insert into public.marketing_message_events (org_id, channel, event_type, status, created_by) values
  ('00000000-0000-0000-0000-00000000155a', 'whatsapp_manual', 'provider_event', 'provider_sent', '00000000-0000-0000-0000-000000155013')$q$) = '42501', 'evento do provedor não entra pela API');
select pg_temp.expect(pg_temp.state_of($q$insert into public.marketing_message_events (org_id, channel, event_type, status, created_by) values
  ('00000000-0000-0000-0000-00000000155a', 'whatsapp_manual', 'manual_ready', 'provider_delivered', '00000000-0000-0000-0000-000000155013')$q$) = '42501', 'situação de provedor não entra pela API');
select pg_temp.expect(pg_temp.state_of($q$insert into public.marketing_message_events (org_id, channel, event_type, status, created_by) values
  ('00000000-0000-0000-0000-00000000155a', 'whatsapp_manual', 'manual_ready', 'manual_ready', '00000000-0000-0000-0000-000000155010')$q$) = '42501', 'evento em nome de outra pessoa');
select pg_temp.expect(pg_temp.state_of($q$insert into public.marketing_message_events (org_id, channel, event_type, status) values
  ('00000000-0000-0000-0000-00000000155a', 'whatsapp_manual', 'manual_ready', 'manual_ready')$q$) = '42501', 'evento sem autor');
select pg_temp.expect(pg_temp.state_of($q$insert into public.marketing_message_events (org_id, channel, event_type, status, created_by) values
  ('00000000-0000-0000-0000-00000000155a', 'whatsapp_manual', 'manual_ready', 'manual_ready', '00000000-0000-0000-0000-000000155013')$q$) = 'ok', 'evento manual com o próprio autor');
select pg_temp.expect(pg_temp.state_of($q$insert into public.marketing_message_events (org_id, queue_id, channel, event_type, status, created_by) values
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155cc', 'whatsapp_manual', 'manual_ready', 'manual_ready', '00000000-0000-0000-0000-000000155013')$q$) = '23514', 'evento com fila de outro estúdio');
select pg_temp.expect(pg_temp.state_of($q$insert into public.marketing_message_events (org_id, client_id, channel, event_type, status, created_by) values
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155c9', 'whatsapp_manual', 'manual_ready', 'manual_ready', '00000000-0000-0000-0000-000000155013')$q$) = '23514', 'evento com cliente de outro estúdio');
select pg_temp.logout();

-- 8. Leitura da fila, dos eventos, dos envios, das campanhas e dos modelos: mensagens.use ou configure.
select pg_temp.login('00000000-0000-0000-0000-000000155015');
select pg_temp.expect((select count(*) from public.marketing_message_queue) = 0 and (select count(*) from public.marketing_message_events) = 0
  and (select count(*) from public.marketing_campaigns) = 0 and (select count(*) from public.marketing_message_templates) = 0
  and (select count(*) from public.messaging_connections) = 0 and (select count(*) from public.messaging_provider_log) = 0,
  'viewer (sem mensagens.use) não lê fila, eventos, campanhas, modelos, conexão nem envios (destino e texto)');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000155014');
select pg_temp.expect((select count(*) from public.marketing_message_queue) > 0 and (select count(*) from public.marketing_message_templates) > 0, 'profissional (mensagens.use) lê a fila e os modelos');
select pg_temp.expect(pg_temp.state_of($q$insert into public.marketing_message_queue (org_id, client_id, channel, recipient, message_body, idempotency_key) values
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155b1', 'whatsapp_manual', '+34610000001', 'x', 'g11')$q$) = '42501', 'profissional lê, mas não grava a fila');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000155012');
select pg_temp.expect((select count(*) from public.marketing_message_queue where org_id = '00000000-0000-0000-0000-00000000155a') = 0, 'outro estúdio não lê a fila do A');
select pg_temp.logout();

-- 14. Fila em lotes de 50, em ordem estável: ninguém fica de fora da 51ª em diante.
insert into public.clients (org_id, full_name, phone, phone_country_code, tags, status)
select '00000000-0000-0000-0000-00000000155a', 'Bulk ' || lpad(g::text, 3, '0'), '+3462' || lpad(g::text, 7, '0'), '+34', '{BULK155}', 'Ativo' from generate_series(1, 120) g;
insert into public.client_marketing_preferences (org_id, client_id, channel, marketing_allowed)
select c.org_id, c.id, 'whatsapp_manual', true from public.clients c where c.org_id = '00000000-0000-0000-0000-00000000155a' and c.tags @> '{BULK155}';
select pg_temp.login('00000000-0000-0000-0000-000000155013');
insert into ids select 'cbulk', public.marketing_create_campaign('00000000-0000-0000-0000-00000000155a', 'Em lotes', null, 'whatsapp_manual', 'manual', null,
  '{"tagsAny":["BULK155"],"clientStatus":"Ativo","marketingConsent":"missing_or_allowed"}');
select pg_temp.expect((select estimated_audience_count = 120 from public.marketing_campaigns where id = (select v from ids where k = 'cbulk')), 'lotes: estimativa de 120');
select pg_temp.expect((select (r ->> 'added')::int = 50 and (r ->> 'remaining')::int = 70 and (r ->> 'drafts')::int = 50
  from (select public.marketing_prepare_queue('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'cbulk')) r) x), 'lotes: 1ª chamada 50, restam 70');
select pg_temp.expect((select string_agg(c.full_name, ',' order by c.full_name) from (select c2.full_name from public.marketing_message_queue q join public.clients c2 on c2.id = q.client_id
  where q.campaign_id = (select v from ids where k = 'cbulk') order by c2.full_name limit 2) c) = 'Bulk 001,Bulk 002', 'lotes: ordem estável (nome) começa do início');
select pg_temp.expect((select (r ->> 'added')::int = 50 and (r ->> 'remaining')::int = 20 from (select public.marketing_prepare_queue('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'cbulk')) r) x), 'lotes: 2ª chamada 50, restam 20');
select pg_temp.expect((select (r ->> 'added')::int = 20 and (r ->> 'remaining')::int = 0 and (r ->> 'drafts')::int = 120 from (select public.marketing_prepare_queue('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'cbulk')) r) x), 'lotes: 3ª chamada completa os 120');
select pg_temp.expect((select count(distinct client_id) = 120 from public.marketing_message_queue where campaign_id = (select v from ids where k = 'cbulk')), 'lotes: nenhum cliente repetido nem esquecido');
select pg_temp.logout();

-- Marketing só para quem disse SIM (20261114110000): cliente SEM preferência registrada fica fora do público e da fila.
insert into public.clients (id, org_id, full_name, phone, phone_country_code, tags, status) values
  ('00000000-0000-0000-0000-0000000155bc', '00000000-0000-0000-0000-00000000155a', 'Nova Sem Registro', '+34610000011', '+34', '{NEW155}', 'Ativo');
select pg_temp.login('00000000-0000-0000-0000-000000155013');
select pg_temp.expect(public.marketing_missing_consent_counts_as_allowed() = false, 'a regra vigente: sem preferência registrada NÃO conta como pode receber');
select pg_temp.expect(pg_temp.new_audience('whatsapp_manual') not like '%Sem Registro%' and pg_temp.new_audience('whatsapp_manual') like '%Nova Aceita%',
  'sem preferência registrada: fora do público (quem aceitou continua)');
select pg_temp.expect(pg_temp.new_audience('email_provider') not like '%Sem Registro%', 'sem preferência registrada: fora também no e-mail');
select pg_temp.expect(pg_temp.new_audience('whatsapp_manual', 'any', false) like '%Sem Registro%', 'a auditoria de consentimento (sem impor) ainda lista quem não tem registro');
select pg_temp.expect(pg_temp.state_of($q$insert into public.marketing_message_queue (org_id, client_id, channel, recipient, message_body, idempotency_key) values
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155bc', 'whatsapp_manual', '+34610000011', 'x', 'g12')$q$) = '23514', 'sem preferência registrada: a guarda da fila recusa');
insert into ids select 'csr', public.marketing_create_campaign('00000000-0000-0000-0000-00000000155a', 'Sem registro', null, 'whatsapp_manual', 'manual', null,
  '{"channel":"whatsapp_manual","tagsAny":["NEW155"],"clientStatus":"Ativo","marketingConsent":"any"}');
select public.marketing_prepare_queue('00000000-0000-0000-0000-00000000155a', (select v from ids where k = 'csr'));
select pg_temp.expect(not exists (select 1 from public.marketing_message_queue where campaign_id = (select v from ids where k = 'csr') and client_id = '00000000-0000-0000-0000-0000000155bc'),
  'sem preferência registrada: nunca entra na fila (nem em campanha com consentimento "qualquer")');
select pg_temp.logout();
-- A regra está num lugar só: trocar a função muda público, fila e guarda juntos (a troca é desfeita).
create or replace function public.marketing_missing_consent_counts_as_allowed() returns boolean language plpgsql stable set search_path = '' as $$ begin return true; end $$;
select pg_temp.login('00000000-0000-0000-0000-000000155013');
select pg_temp.expect(pg_temp.new_audience('whatsapp_manual') like '%Sem Registro%', 'regra antiga (sem registro conta como pode receber): entra no público');
select pg_temp.expect(pg_temp.state_of($q$insert into public.marketing_message_queue (org_id, client_id, channel, recipient, message_body, idempotency_key) values
  ('00000000-0000-0000-0000-00000000155a', '00000000-0000-0000-0000-0000000155bc', 'whatsapp_manual', '+34610000011', 'x', 'g13')$q$) = 'ok', 'regra antiga: a guarda deixa entrar na fila');
select pg_temp.logout();
create or replace function public.marketing_missing_consent_counts_as_allowed() returns boolean language plpgsql stable set search_path = '' as $$ begin return false; end $$;
select pg_temp.login('00000000-0000-0000-0000-000000155013');
select pg_temp.expect(pg_temp.new_audience('whatsapp_manual') not like '%Sem Registro%', 'regra de volta: sem registro fora do público');
select pg_temp.logout();

-- ─── Cascata: apagar o estúdio inteiro não quebra por causa dos gatilhos ──────────────────────────
insert into public.organizations (id, slug, name) values ('00000000-0000-0000-0000-00000000155c', 'm155-c', 'Mensagens 155 C');
insert into public.clients (id, org_id, full_name, phone) values ('00000000-0000-0000-0000-0000000155c8', '00000000-0000-0000-0000-00000000155c', 'Cliente C', '+34600000008');
insert into public.client_marketing_preferences (org_id, client_id, channel, marketing_allowed) values ('00000000-0000-0000-0000-00000000155c', '00000000-0000-0000-0000-0000000155c8', 'whatsapp_manual', true);
insert into public.messaging_connections (org_id, provider, session_name, status) values ('00000000-0000-0000-0000-00000000155c', 'waha_qr', 'org-c', 'connected');
insert into public.marketing_campaigns (id, org_id, name, planned_channel) values ('00000000-0000-0000-0000-0000000155ca', '00000000-0000-0000-0000-00000000155c', 'Camp C', 'whatsapp_manual');
insert into public.marketing_message_queue (org_id, campaign_id, client_id, channel, recipient, message_body, idempotency_key) values
  ('00000000-0000-0000-0000-00000000155c', '00000000-0000-0000-0000-0000000155ca', '00000000-0000-0000-0000-0000000155c8', 'whatsapp_manual', '+34600000008', 'oi', 'k1');
select pg_temp.expect(pg_temp.state_of($q$delete from public.organizations where id = '00000000-0000-0000-0000-00000000155c'$q$) = 'ok', 'apagar estúdio em cascata com conexão, campanha e fila: sem erro de auditoria');

rollback;
\o
\echo 'mensagens e marketing: leituras e ações em uma ida (155): ok'
