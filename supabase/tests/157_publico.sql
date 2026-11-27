-- Páginas públicas (migrations 20261114100000 a 20261114100200): token da ficha só como hash, link novo ao reenviar,
-- inválido/vencido/usado com a MESMA resposta, limite de tentativas por IP e por token, assinatura tudo-ou-nada e
-- imutável, modo estúdio com alcance e PIN com bloqueio crescente, isolamento entre estúdios, anon sem nada (só o
-- servidor chama as funções públicas), auditoria por gatilho, /pagar e "Esqueci a senha". Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000001570', 'dona@pub157.local'),
  ('00000000-0000-0000-0000-000000001571', 'recep@pub157.local'),
  ('00000000-0000-0000-0000-000000001574', 'donab@pub157.local');
insert into public.organizations (id, slug, name, timezone, address, city) values
  ('00000000-0000-0000-0000-00000000157a', 'pub157-a', 'Estúdio 157 A', 'Europe/Madrid', 'Calle Uno 1', 'Madrid'),
  ('00000000-0000-0000-0000-00000000157b', 'pub157-b', 'Estúdio 157 B', 'Europe/Madrid', null, null);
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000001570', '00000000-0000-0000-0000-00000000157a', 'owner'),
  ('00000000-0000-0000-0000-000000001571', '00000000-0000-0000-0000-00000000157a', 'receptionist'),
  ('00000000-0000-0000-0000-000000001574', '00000000-0000-0000-0000-00000000157b', 'owner');
insert into public.clients (id, org_id, full_name, phone, email) values
  ('00000000-0000-0000-0000-0000000157c1', '00000000-0000-0000-0000-00000000157a', 'Lucía Prado', '+34600000157', 'lucia@exemplo.es'),
  ('00000000-0000-0000-0000-0000000157c9', '00000000-0000-0000-0000-00000000157b', 'Cliente B', '+34600000159', null);
insert into public.anamnese_templates (id, org_id, title, questions, consent_text) values
  ('00000000-0000-0000-0000-0000000157f1', '00000000-0000-0000-0000-00000000157a', 'Ficha facial',
   '[{"id":"q1","type":"text","text":"Alergias?","required":true}]'::jsonb, 'Consinto'),
  ('00000000-0000-0000-0000-0000000157f9', '00000000-0000-0000-0000-00000000157b', 'Ficha do B',
   '[{"id":"q1","type":"text","text":"Alergias?"}]'::jsonb, 'Consinto');

create function pg_temp.expect(p_ok boolean, p_msg text) returns void language plpgsql as $$
begin
  if not coalesce(p_ok, false) then raise exception 'FALHOU: %', p_msg; end if;
end $$;
create function pg_temp.state_of(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return sqlstate || ': ' || sqlerrm;
end $$;
create function pg_temp.login(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;
-- "Servidor": a chave de serviço (as funções públicas só valem para ela).
create function pg_temp.server() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
  perform set_config('role', 'service_role', true);
end $$;
create function pg_temp.anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  perform set_config('role', 'anon', true);
end $$;
create function pg_temp.logout() returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);
end $$;
-- IP do servidor (sha256 do IP, calculado no Worker); cada bloco usa um IP para os limites não se misturarem.
create function pg_temp.ip(p_n int) returns text language sql immutable as $$
  select encode(extensions.digest('198.51.100.' || p_n, 'sha256'), 'hex') $$;
create function pg_temp.ok_answers() returns jsonb language sql immutable as $$
  select '{"q1":"Nenhuma","__canal":"link","__termo_principal":"aceito"}'::jsonb $$;
create function pg_temp.sig() returns text language sql immutable as $$
  select 'data:image/png;base64,' || repeat('A', 80) $$;
create temp table t (k text primary key, v text) on commit drop;
grant all on t to anon, authenticated, service_role;
grant execute on function pg_temp.expect(boolean, text), pg_temp.state_of(text), pg_temp.login(uuid), pg_temp.server(),
  pg_temp.anon(), pg_temp.logout(), pg_temp.ip(int), pg_temp.ok_answers(), pg_temp.sig() to anon, authenticated, service_role;

-- ─── 1. Token só como hash ───────────────────────────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001570');
insert into t select 'f1', (r).id::text from (select public.create_anamnese_atomic('00000000-0000-0000-0000-00000000157a',
  '00000000-0000-0000-0000-0000000157f1', '00000000-0000-0000-0000-0000000157c1', 'x') r) s;
insert into t values ('tok1', (public.anamnese_create_link('00000000-0000-0000-0000-00000000157a', '00000000-0000-0000-0000-0000000157f1',
  '00000000-0000-0000-0000-0000000157c1', 'x', null, null, 7, null)) ->> 'token');
select pg_temp.logout();
-- A segunda criação (sem agendamento) é outra ficha; usamos a do link.
update t set v = (select a.id::text from public.anamneses a where a.token_hash = encode(extensions.digest((select v from t where k = 'tok1'), 'sha256'), 'hex'))
where k = 'f1';
select pg_temp.expect((select v ~ '^[0-9a-f]{32}$' from t where k = 'tok1'), 'link com 128 bits (32 hex)');
select pg_temp.expect((select public_token is null and token_hash = encode(extensions.digest((select v from t where k = 'tok1'), 'sha256'), 'hex')
  from public.anamneses where id = (select v::uuid from t where k = 'f1')), 'banco guarda só o sha256 do token');
select pg_temp.expect((select count(*) = 0 from public.anamneses where public_token is not null), 'nenhum token em claro na tabela');
select pg_temp.expect(pg_temp.state_of($q$insert into public.anamneses (org_id, client_name, status, public_token, token_expires_at)
  values ('00000000-0000-0000-0000-00000000157a', 'Gravado direto', 'pending', 'tok157direto0000000000000000000000', now() + interval '1 day')$q$) = 'ok',
  'gravar direto (dono do banco) funciona');
select pg_temp.expect((select public_token is null and token_hash = encode(extensions.digest('tok157direto0000000000000000000000', 'sha256'), 'hex')
       from public.anamneses where client_name = 'Gravado direto'), 'quem grava public_token tem o valor trocado pelo hash');
select pg_temp.expect(pg_temp.state_of($q$alter table public.anamneses disable trigger trg_anamneses_hash_public_token;
  update public.anamneses set public_token = 'x' where client_name = 'Gravado direto'$q$) like '23514%', 'CHECK barra token em claro mesmo sem o gatilho');
alter table public.anamneses enable trigger trg_anamneses_hash_public_token;

-- ─── 2. Abrir: válido, e inválido/vencido/usado com a MESMA resposta ───────────────────────────────
select pg_temp.server();
select pg_temp.expect((select (x ->> 'client_name') = 'Lucía Prado' and (x ->> 'org_name') = 'Estúdio 157 A'
    and jsonb_array_length(x -> 'questions') = 1 and (x ->> 'reference') ~ '^AN-[0-9A-F]{8}$'
    and not (x ?| array['id', 'client_id', 'org_id', 'token_hash', 'signer_ip', 'professional_notes', 'professional_data',
                         'signature_data_url', 'client_phone', 'client_email', 'created_by'])
  from (select public.public_anamnese_open((select v from t where k = 'tok1'), pg_temp.ip(1), true) x) s), 'link válido: só o necessário');
select pg_temp.logout();
select pg_temp.expect((select first_opened_at is not null from public.anamneses where id = (select v::uuid from t where k = 'f1')), 'abertura registrada');
-- Uma ficha vencida e uma assinada, com links conhecidos.
insert into public.anamneses (id, org_id, client_name, template_title, template_snapshot, status, public_token, token_expires_at) values
  ('00000000-0000-0000-0000-0000000157e1', '00000000-0000-0000-0000-00000000157a', 'Vencida', 'Ficha', '{"questions":[]}', 'pending',
   'tok157vencida000000000000000000000', now() - interval '1 minute');
insert into public.anamneses (id, org_id, client_name, template_title, template_snapshot, status, public_token, token_expires_at,
  answers, signature_name, signature_data_url, signed_at, consent_accepted) values
  ('00000000-0000-0000-0000-0000000157e2', '00000000-0000-0000-0000-00000000157a', 'Assinada', 'Ficha', '{"questions":[]}', 'signed',
   'tok157assinada00000000000000000000', now() + interval '1 day', '{"q1":"Látex"}', 'Assinada', 'data:image/png;base64,AAAA', now(), true);
select pg_temp.server();
select pg_temp.expect(public.public_anamnese_open('tok157inexistente0000000000000000', pg_temp.ip(2), false) is null
  and public.public_anamnese_open('tok157vencida000000000000000000000', pg_temp.ip(2), false) is null
  and public.public_anamnese_open('tok157assinada00000000000000000000', pg_temp.ip(2), false) is null
  and public.public_anamnese_open('curto', pg_temp.ip(2), false) is null
  and public.public_anamnese_open(null, pg_temp.ip(2), false) is null, 'inválido, vencido, usado, curto e nulo: a mesma resposta (nada)');
select pg_temp.expect(
  (public.public_anamnese_sign('tok157inexistente0000000000000000', pg_temp.ip(3), pg_temp.ok_answers(), 'X', pg_temp.sig(), true, 'ua', null)) ->> 'error' = 'not_found'
  and (public.public_anamnese_sign('tok157vencida000000000000000000000', pg_temp.ip(3), pg_temp.ok_answers(), 'X', pg_temp.sig(), true, 'ua', null)) ->> 'error' = 'not_found'
  and (public.public_anamnese_sign('tok157assinada00000000000000000000', pg_temp.ip(3), pg_temp.ok_answers(), 'X', pg_temp.sig(), true, 'ua', null)) ->> 'error' = 'not_found',
  'assinar inválido, vencido ou usado: o mesmo erro');
select pg_temp.logout();
select pg_temp.expect((select status = 'pending' and signed_at is null from public.anamneses where id = '00000000-0000-0000-0000-0000000157e1'),
  'vencida continua pendente');
select pg_temp.expect((select answers = '{"q1":"Látex"}'::jsonb and signature_name = 'Assinada' from public.anamneses
  where id = '00000000-0000-0000-0000-0000000157e2'), 'assinada não muda');

-- ─── 3. Limite de tentativas ─────────────────────────────────────────────────────────────────────
select pg_temp.server();
-- IP 4: 20 links errados passam como "não achei"; do 21º em diante até o link certo responde igual (bloqueado).
select count(*) from generate_series(1, 21) n where public.public_anamnese_open('tok157chute' || lpad(n::text, 24, '0'), pg_temp.ip(4), false) is null;
select pg_temp.expect(public.public_anamnese_open((select v from t where k = 'tok1'), pg_temp.ip(4), false) is null,
  'IP com mais de 20 erros em 10 min: link certo responde igual a inexistente');
select pg_temp.expect(public.public_anamnese_open((select v from t where k = 'tok1'), pg_temp.ip(5), false) is not null,
  'outro IP continua abrindo');
select pg_temp.logout();
select pg_temp.expect((select count(*) = 0 from public.public_link_hits where key_hash !~ '^[0-9a-f]{64}$'), 'contador guarda só hash');
select pg_temp.expect((select coalesce(sum(hits), 0) >= 21 from public.public_link_hits where bucket = 'form_miss_ip' and key_hash = pg_temp.ip(4)),
  'erros contados por IP');

-- Por token: no máximo 10 tentativas de assinar em 10 min (mesmo de IPs diferentes).
select pg_temp.server();
select count(*) from generate_series(1, 10) n
where public.public_anamnese_sign((select v from t where k = 'tok1'), pg_temp.ip(10 + n), '{"__canal":"link"}'::jsonb, 'X', pg_temp.sig(), false, 'ua', null) ->> 'error' = 'consent_required';
select pg_temp.expect((public.public_anamnese_sign((select v from t where k = 'tok1'), pg_temp.ip(40), pg_temp.ok_answers(), 'Lucía', pg_temp.sig(), true, 'ua', null)) ->> 'error' = 'rate_limited',
  'link com mais de 10 tentativas de assinar: "tente mais tarde"');
select pg_temp.expect((public.public_anamnese_sign((select v from t where k = 'tok1'), pg_temp.ip(4), pg_temp.ok_answers(), 'Lucía', pg_temp.sig(), true, 'ua', null)) ->> 'error' = 'rate_limited',
  'IP bloqueado: assinar responde "tente mais tarde" (vale para qualquer link)');
select pg_temp.expect(pg_temp.state_of($q$select public.public_anamnese_open('x', 'nao-e-hash', false)$q$) like '22023%'
  and pg_temp.state_of($q$select public.public_password_reset_allowed(repeat('1', 64), 'A@B.C')$q$) like '22023%',
  'chave fora do formato no limitador é erro (inclusive o e-mail do "Esqueci a senha")');
select pg_temp.logout();
select pg_temp.expect((select status = 'pending' from public.anamneses where id = (select v::uuid from t where k = 'f1')), 'bloqueado não assina');
-- Libera a janela (o teste avança o relógio apagando o contador).
delete from public.public_link_hits where bucket = 'sign_token';

-- ─── 4. Assinatura tudo-ou-nada e imutável ───────────────────────────────────────────────────────
select pg_temp.server();
select pg_temp.expect((public.public_anamnese_sign((select v from t where k = 'tok1'), pg_temp.ip(41), '{"__canal":"link","__termo_principal":"aceito"}'::jsonb,
  'Lucía', pg_temp.sig(), true, 'ua', '203.0.113.9')) ->> 'error' = 'answers_required', 'pergunta obrigatória vazia não assina');
select pg_temp.expect((public.public_anamnese_sign((select v from t where k = 'tok1'), pg_temp.ip(41), pg_temp.ok_answers() || '{"q2":{"x":1}}'::jsonb,
  'Lucía', pg_temp.sig(), true, 'ua', '203.0.113.9')) ->> 'error' = 'invalid_payload', 'resposta que não é texto é recusada');
select pg_temp.expect((public.public_anamnese_sign((select v from t where k = 'tok1'), pg_temp.ip(41), pg_temp.ok_answers(),
  'Lucía', 'data:image/svg+xml;base64,' || repeat('A', 80), true, 'ua', '203.0.113.9')) ->> 'error' = 'invalid_payload', 'assinatura só em PNG');
select pg_temp.logout();
select pg_temp.expect((select status = 'pending' and answers = '{}'::jsonb and signature_data_url is null and signer_ip is null
    and not consent_accepted from public.anamneses where id = (select v::uuid from t where k = 'f1')), 'tentativa recusada não grava nada');
select pg_temp.server();
select pg_temp.expect((public.public_anamnese_sign((select v from t where k = 'tok1'), pg_temp.ip(41), pg_temp.ok_answers(),
  'Lucía Prado', pg_temp.sig(), true, 'Mozilla/5.0', '203.0.113.9')) ->> 'ok' = 'true', 'assina com tudo certo');
select pg_temp.expect((public.public_anamnese_sign((select v from t where k = 'tok1'), pg_temp.ip(41), pg_temp.ok_answers() || '{"q1":"Mudei"}',
  'Outra', pg_temp.sig(), true, 'ua', '198.51.100.7')) ->> 'error' = 'not_found', 'segunda assinatura: link usado');
select pg_temp.logout();
select pg_temp.expect((select status = 'signed' and answers ->> 'q1' = 'Nenhuma' and signature_name = 'Lucía Prado' and consent_accepted
    and signer_ip = '203.0.113.0' and signer_user_agent = 'Mozilla/5.0' and signed_at is not null
  from public.anamneses where id = (select v::uuid from t where k = 'f1')), 'respostas, consentimento, assinatura e prova gravados juntos; IP sem o último octeto');
select pg_temp.expect(pg_temp.state_of(format($q$update public.anamneses set answers = '{"q1":"trocada"}' where id = %L$q$,
  (select v from t where k = 'f1'))) like '23514%', 'assinada é imutável (nem o dono do banco troca respostas)');
select pg_temp.expect(pg_temp.state_of(format($q$delete from public.anamneses where id = %L$q$, (select v from t where k = 'f1'))) like '23514%',
  'assinada não se apaga');

-- ─── 5. Auditoria por gatilho ────────────────────────────────────────────────────────────────────
select pg_temp.expect((select count(*) = 1 and bool_and(user_id is null and new_data = '{"channel":"link"}'::jsonb)
  from public.audit_logs where record_id = (select v::uuid from t where k = 'f1') and operation = 'ANAMNESE_SIGNED'),
  'assinatura auditada (só o canal; nada das respostas, nome ou IP)');

-- ─── 6. Reenviar: link novo, o anterior deixa de valer ──────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001571');
insert into t values ('tok2', (public.anamnese_create_link('00000000-0000-0000-0000-00000000157a', '00000000-0000-0000-0000-0000000157f1',
  '00000000-0000-0000-0000-0000000157c1', 'x', null, null, 3, 'copy')) ->> 'token');
select pg_temp.logout();
insert into t select 'f2', a.id::text from public.anamneses a
where a.token_hash = encode(extensions.digest((select v from t where k = 'tok2'), 'sha256'), 'hex');
-- A janela da auditoria só conta link novo em outra transação: a ficha "nasceu antes".
update public.anamneses set created_at = now() - interval '1 hour' where id = (select v::uuid from t where k = 'f2');
select pg_temp.login('00000000-0000-0000-0000-000000001571');
insert into t values ('tok3', (public.anamnese_issue_link('00000000-0000-0000-0000-00000000157a', (select v::uuid from t where k = 'f2'), null)) ->> 'token');
select pg_temp.expect(pg_temp.state_of(format($q$select public.anamnese_issue_link('00000000-0000-0000-0000-00000000157a', %L, null)$q$,
  (select v from t where k = 'f1'))) like 'P0001%', 'ficha assinada não ganha link');
select pg_temp.logout();
select pg_temp.expect((select (select v from t where k = 'tok3') <> (select v from t where k = 'tok2')), 'reenviar gera token novo');
select pg_temp.server();
select pg_temp.expect(public.public_anamnese_open((select v from t where k = 'tok2'), pg_temp.ip(50), false) is null
  and public.public_anamnese_open((select v from t where k = 'tok3'), pg_temp.ip(50), false) is not null, 'o link antigo morre, o novo abre');
select pg_temp.logout();
select pg_temp.expect((select count(*) = 1 from public.audit_logs where record_id = (select v::uuid from t where k = 'f2')
  and operation = 'ANAMNESE_LINK_REISSUED' and user_id = '00000000-0000-0000-0000-000000001571'
  and not (new_data::text ~ (select v from t where k = 'tok3'))), 'link novo auditado (quem, sem o token)');
-- Vencida exige validade nova; com validade, volta com link novo.
update public.anamneses set token_expires_at = now() - interval '1 minute' where id = (select v::uuid from t where k = 'f2');
select pg_temp.login('00000000-0000-0000-0000-000000001571');
select pg_temp.expect(pg_temp.state_of(format($q$select public.anamnese_issue_link('00000000-0000-0000-0000-00000000157a', %L, null)$q$,
  (select v from t where k = 'f2'))) like 'P0001%', 'vencida sem validade nova: recusa');
select pg_temp.expect((select (x ->> 'token') ~ '^[0-9a-f]{32}$' and (x ->> 'expires_at')::timestamptz > now() + interval '2 days'
  from (select public.anamnese_issue_link('00000000-0000-0000-0000-00000000157a', (select v::uuid from t where k = 'f2'), 3) x) s), 'renovar devolve link novo e validade');
select pg_temp.logout();

select pg_temp.login('00000000-0000-0000-0000-000000001570');
select pg_temp.expect((select count(*) > 0 from public.list_anamnese_status('00000000-0000-0000-0000-00000000157a'))
  and not exists (select 1 from information_schema.routines r join information_schema.parameters p on p.specific_name = r.specific_name
                  where r.routine_name = 'list_anamnese_status' and p.parameter_name = 'public_token'),
  'leitura da equipe sem o campo do link');
select pg_temp.expect(not ((public.anamnese_ficha_screen('00000000-0000-0000-0000-00000000157a', (select v::uuid from t where k = 'f2'), 'janela')) -> 'ficha' ?| array['public_token', 'token_hash']),
  'ficha aberta sem link nem hash');
select pg_temp.logout();

-- ─── 7. Isolamento entre estúdios ────────────────────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001574');
select pg_temp.expect(pg_temp.state_of(format($q$select public.anamnese_issue_link('00000000-0000-0000-0000-00000000157a', %L, 3)$q$,
  (select v from t where k = 'f2'))) like '42501%', 'dona do B não gera link do A');
select pg_temp.expect(pg_temp.state_of(format($q$select public.anamnese_issue_link('00000000-0000-0000-0000-00000000157b', %L, 3)$q$,
  (select v from t where k = 'f2'))) like 'P0002%', 'ficha do A pelo estúdio B: não encontrada');
select pg_temp.expect(public.studio_anamnese_open('00000000-0000-0000-0000-00000000157b', (select v::uuid from t where k = 'f2'), false) is null,
  'modo estúdio do B não abre ficha do A');
select pg_temp.expect((public.studio_anamnese_sign('00000000-0000-0000-0000-00000000157b', (select v::uuid from t where k = 'f2'),
  '{"__canal":"tablet"}'::jsonb, 'X', pg_temp.sig(), true, 'ua', null)) ->> 'error' = 'not_found', 'modo estúdio do B não assina ficha do A');
select pg_temp.expect(pg_temp.state_of($q$select public.studio_team_screen('00000000-0000-0000-0000-00000000157a')$q$) like '42501%',
  'dona do B não vê a tela da equipe do A');
select pg_temp.logout();

-- ─── 8. anon: nada (nem tabela, nem função pública) ─────────────────────────────────────────────
select pg_temp.anon();
select pg_temp.expect(pg_temp.state_of(f) like '42501%', 'anon recusado: ' || f)
from unnest(array[
  $q$select public.public_anamnese_open('x', null, false)$q$,
  $q$select public.public_anamnese_sign('x', null, '{}', 'x', 'x', true, 'x', null)$q$,
  $q$select public.public_anamnese_calendar('x', null)$q$,
  $q$select public.public_payment_open('x', null)$q$,
  $q$select public.public_payment_proof_begin('x', null, true)$q$,
  $q$select public.public_password_reset_allowed(null, null)$q$,
  $q$select public.studio_anamnese_open('00000000-0000-0000-0000-00000000157a', '00000000-0000-0000-0000-00000000157a', false)$q$,
  $q$select public.anamnese_sign_internal('00000000-0000-0000-0000-00000000157a', 'link', '{}', 'x', 'x', true, 'x', null)$q$,
  $q$select count(*) from public.anamneses$q$,
  $q$select count(*) from public.public_link_hits$q$,
  $q$select count(*) from public.payment_requests$q$]) f;
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000001570');
select pg_temp.expect(pg_temp.state_of(f) like '42501%', 'pessoa logada também não chama a função do servidor: ' || f)
from unnest(array[
  $q$select public.public_anamnese_open('x', null, false)$q$,
  $q$select public.anamnese_sign_internal('00000000-0000-0000-0000-00000000157a', 'link', '{}', 'x', 'x', true, 'x', null)$q$,
  $q$select count(*) from public.public_link_hits$q$]) f;
select pg_temp.logout();
select pg_temp.expect(not exists (
  select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef and has_function_privilege('anon', p.oid, 'execute')), 'nenhuma função DEFINER executável por anon');

-- ─── 9. Modo estúdio ─────────────────────────────────────────────────────────────────────────────
insert into public.anamneses (id, org_id, client_name, template_title, template_snapshot, status, public_token, token_expires_at, consent_text) values
  ('00000000-0000-0000-0000-0000000157e3', '00000000-0000-0000-0000-00000000157a', 'No estúdio', 'Ficha',
   '{"questions":[]}', 'pending', 'tok157estudio000000000000000000000', now() + interval '1 day', 'Consinto');
select pg_temp.login('00000000-0000-0000-0000-000000001570');
select pg_temp.expect(pg_temp.state_of($q$select public.studio_mode_enter('00000000-0000-0000-0000-00000000157a', '00000000-0000-0000-0000-0000000157e3')$q$) like 'P0001%',
  'sem PIN não entrega o aparelho');
select public.set_studio_pin('00000000-0000-0000-0000-00000000157a', '2468');
select public.studio_mode_enter('00000000-0000-0000-0000-00000000157a', '00000000-0000-0000-0000-0000000157e3');
select pg_temp.expect(pg_temp.state_of($q$select public.studio_mode_enter('00000000-0000-0000-0000-00000000157a', '00000000-0000-0000-0000-0000000157e2')$q$) like 'P0001%',
  'ficha assinada não é entregue');
select pg_temp.expect((public.studio_anamnese_open('00000000-0000-0000-0000-00000000157a', '00000000-0000-0000-0000-0000000157e3', true)) ->> 'state' = 'open',
  'ficha aberta no aparelho');
select pg_temp.expect((public.studio_anamnese_sign('00000000-0000-0000-0000-00000000157a', '00000000-0000-0000-0000-0000000157e3',
  '{"__canal":"link","__termo_principal":"aceito"}'::jsonb, 'No estúdio', pg_temp.sig(), true, 'Tablet', '203.0.113.20')) ->> 'error' = 'channel_invalid',
  'modo estúdio grava só o canal do estúdio');
select pg_temp.expect((public.studio_anamnese_sign('00000000-0000-0000-0000-00000000157a', '00000000-0000-0000-0000-0000000157e3',
  '{"__canal":"tablet","__termo_principal":"aceito"}'::jsonb, 'No estúdio', pg_temp.sig(), true, 'Tablet', '203.0.113.20')) ->> 'ok' = 'true',
  'assina no aparelho do estúdio');
select pg_temp.expect((public.studio_anamnese_open('00000000-0000-0000-0000-00000000157a', '00000000-0000-0000-0000-0000000157e3', false)) ->> 'state' = 'signed'
  and (public.studio_anamnese_open('00000000-0000-0000-0000-00000000157a', '00000000-0000-0000-0000-0000000157e3', false)) -> 'answers' = '{}'::jsonb,
  'depois de assinada o aparelho não mostra as respostas');
select pg_temp.expect((select count(*) = 1 from public.anamnese_events where anamnese_id = '00000000-0000-0000-0000-0000000157e3' and kind = 'sent' and channel = 'studio'),
  'entrega registrada como envio pelo modo estúdio');
-- Modo desligado em Ajustes: nada abre.
select public.set_anamnese_settings('00000000-0000-0000-0000-00000000157a', 7, false);
select pg_temp.expect(pg_temp.state_of($q$select public.studio_team_screen('00000000-0000-0000-0000-00000000157a')$q$) like 'P0001%',
  'modo desligado: tela da equipe recusa');
select public.set_anamnese_settings('00000000-0000-0000-0000-00000000157a', 7, true);
select pg_temp.expect((public.studio_team_screen('00000000-0000-0000-0000-00000000157a')) ->> 'pin_configured' = 'true', 'tela da equipe sabe do PIN');

-- PIN: 5 erros travam 5 min; cada novo bloqueio seguido dobra; acerto zera.
select count(*) from generate_series(1, 4) n where (public.verify_studio_pin('00000000-0000-0000-0000-00000000157a', '0000')) ->> 'reason' = 'wrong';
select pg_temp.expect((public.verify_studio_pin('00000000-0000-0000-0000-00000000157a', '0000')) ->> 'retry_after_seconds' = '300', '5º erro trava 5 min');
select pg_temp.expect((public.verify_studio_pin('00000000-0000-0000-0000-00000000157a', '2468')) ->> 'reason' = 'locked', 'travado: nem o PIN certo passa');
select pg_temp.logout();
update public.studio_mode_pins set locked_until = now() - interval '1 second' where org_id = '00000000-0000-0000-0000-00000000157a';
select pg_temp.login('00000000-0000-0000-0000-000000001570');
select count(*) from generate_series(1, 4) n where (public.verify_studio_pin('00000000-0000-0000-0000-00000000157a', '1111')) ->> 'reason' = 'wrong';
select pg_temp.expect((public.verify_studio_pin('00000000-0000-0000-0000-00000000157a', '1111')) ->> 'retry_after_seconds' = '600', 'bloqueio seguido dobra (10 min)');
select pg_temp.logout();
update public.studio_mode_pins set locked_until = now() - interval '1 second' where org_id = '00000000-0000-0000-0000-00000000157a';
select pg_temp.expect((select count(*) = 2 from public.audit_logs where org_id = '00000000-0000-0000-0000-00000000157a' and operation = 'STUDIO_PIN_LOCKED'),
  'cada bloqueio do PIN auditado');
select pg_temp.login('00000000-0000-0000-0000-000000001570');
select pg_temp.expect((public.verify_studio_pin('00000000-0000-0000-0000-00000000157a', '2468')) ->> 'ok' = 'true', 'PIN certo libera');
select pg_temp.logout();
update public.studio_mode_pins set lock_count = 3, locked_until = now() + interval '1 hour' where org_id = '00000000-0000-0000-0000-00000000157a';
select pg_temp.login('00000000-0000-0000-0000-000000001570');
select public.set_studio_pin('00000000-0000-0000-0000-00000000157a', '1357');
select pg_temp.logout();
select pg_temp.expect((select lock_count = 0 and locked_until is null from public.studio_mode_pins where org_id = '00000000-0000-0000-0000-00000000157a'),
  'trocar o PIN zera o bloqueio crescente');
select pg_temp.expect((select lock_count = 0 and failed_attempts = 0 from public.studio_mode_pins where org_id = '00000000-0000-0000-0000-00000000157a'),
  'acerto zera o bloqueio crescente');

-- ─── 10. /pagar ──────────────────────────────────────────────────────────────────────────────────
insert into public.org_subscriptions (org_id, plan_key, status) values ('00000000-0000-0000-0000-00000000157a', 'completo', 'active')
on conflict (org_id) do update set plan_key = 'completo', status = 'active';
insert into public.payment_requests (id, org_id, client_id, purpose, amount, reason, reference, token_hash, expires_at, status, accounts) values
  ('00000000-0000-0000-0000-0000000157d1', '00000000-0000-0000-0000-00000000157a', '00000000-0000-0000-0000-0000000157c1', 'credit', 30,
   'Crédito', 'PAG-157001', encode(extensions.digest('pay157aberto0000000000000000', 'sha256'), 'hex'), now() + interval '1 day', 'pending',
   '[{"kind":"bizum","holder_name":"Estúdio","identifier":"+34600000000"}]'),
  ('00000000-0000-0000-0000-0000000157d2', '00000000-0000-0000-0000-00000000157a', '00000000-0000-0000-0000-0000000157c1', 'credit', 30,
   'Crédito', 'PAG-157002', encode(extensions.digest('pay157pago00000000000000000000', 'sha256'), 'hex'), now() + interval '1 day', 'confirmed',
   '[{"kind":"bizum","holder_name":"Estúdio","identifier":"+34600000000"}]'),
  ('00000000-0000-0000-0000-0000000157d3', '00000000-0000-0000-0000-00000000157a', '00000000-0000-0000-0000-0000000157c1', 'credit', 30,
   'Crédito', 'PAG-157003', encode(extensions.digest('pay157vencido000000000000000', 'sha256'), 'hex'), now() - interval '1 minute', 'pending',
   '[{"kind":"bizum","holder_name":"Estúdio","identifier":"+34600000000"}]');
select pg_temp.server();
select pg_temp.expect((select x ->> 'client_first_name' = 'Lucía' and x ->> 'status' = 'pending'
    and not (x ?| array['id', 'org_id', 'client_id', 'token_hash', 'proof_path'])
  from (select public.public_payment_open('pay157aberto0000000000000000', pg_temp.ip(60)) x) s), 'cobrança aberta: só o necessário');
select pg_temp.expect(public.public_payment_open('pay157pago00000000000000000000', pg_temp.ip(60)) is null
  and public.public_payment_open('pay157vencido000000000000000', pg_temp.ip(60)) is null
  and public.public_payment_open('pay157inexistente00000000000', pg_temp.ip(60)) is null, 'pago, vencido e inexistente: a mesma resposta');
select pg_temp.expect((public.public_payment_proof_begin('pay157aberto0000000000000000', pg_temp.ip(60), true)) ->> 'folder'
  = '00000000-0000-0000-0000-00000000157a/00000000-0000-0000-0000-0000000157d1', 'pasta do comprovante: <estúdio>/<pedido>');
select pg_temp.expect((public.public_payment_proof_submit('pay157aberto0000000000000000', pg_temp.ip(60),
  '00000000-0000-0000-0000-00000000157a/00000000-0000-0000-0000-0000000157d1/../x.pdf', 'application/pdf', null)) ->> 'error' = 'invalid',
  'caminho fora do formato gerado pelo servidor é recusado');
select pg_temp.expect((public.public_payment_proof_submit('pay157aberto0000000000000000', pg_temp.ip(60),
  '00000000-0000-0000-0000-00000000157a/00000000-0000-0000-0000-0000000157d1/11111111-1111-4111-8111-111111111111.pdf', 'application/pdf', null)) ->> 'error' = 'invalid',
  'arquivo que não está no Storage é recusado');
select pg_temp.logout();

-- Cota separada: abrir a página 60 vezes não gasta as tentativas do comprovante (e vice-versa).
select pg_temp.server();
select count(*) from generate_series(1, 59) n where public.public_payment_open('pay157aberto0000000000000000', pg_temp.ip(61)) is not null;
select pg_temp.expect(public.public_payment_open('pay157aberto0000000000000000', pg_temp.ip(62)) is null, 'abrir: passou de 60 no link, bloqueia');
select pg_temp.expect((public.public_payment_proof_begin('pay157aberto0000000000000000', pg_temp.ip(63), false)) ->> 'folder' is not null,
  'comprovante ainda vale depois de abrir a página muitas vezes');
select pg_temp.logout();

-- ─── 11. Esqueci a senha: 5 por hora por IP, 3 por e-mail ───────────────────────────────────────
select pg_temp.server();
select pg_temp.expect((select count(*) = 3 from generate_series(1, 4) n
  where public.public_password_reset_allowed(pg_temp.ip(70 + n), encode(extensions.digest('a@b.c', 'sha256'), 'hex'))), '3 pedidos por e-mail por hora');
select pg_temp.expect((select count(*) = 5 from generate_series(1, 6) n
  where public.public_password_reset_allowed(pg_temp.ip(80), encode(extensions.digest('p' || n || '@b.c', 'sha256'), 'hex'))), '5 pedidos por IP por hora');
select pg_temp.logout();

rollback;
\o
\echo 'páginas públicas: hash, mesma resposta, limites, assinatura tudo-ou-nada, estúdio e anon (157): ok'
