-- Corrigir ficha assinada (migrations 20261114120000 e 20261114120100): a original assinada nunca muda; "Corrigir
-- respostas" grava versão nova com motivo e auditoria (só ids das perguntas); "Reenviar para a cliente corrigir" cria
-- a ficha nova preenchida e a anterior só vira "substituída" quando a nova é assinada (a trava do checkout segue a que
-- vale); permissão, alcance ("só a minha agenda") e isolamento entre estúdios. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000001580', 'dona@fc158.local'),
  ('00000000-0000-0000-0000-000000001581', 'prof@fc158.local'),
  ('00000000-0000-0000-0000-000000001582', 'recep@fc158.local'),
  ('00000000-0000-0000-0000-000000001584', 'donab@fc158.local');
insert into public.organizations (id, slug, name, timezone) values
  ('00000000-0000-0000-0000-00000000158a', 'fc158-a', 'Correção 158 A', 'Europe/Madrid'),
  ('00000000-0000-0000-0000-00000000158b', 'fc158-b', 'Correção 158 B', 'Europe/Madrid');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000001580', '00000000-0000-0000-0000-00000000158a', 'owner'),
  ('00000000-0000-0000-0000-000000001581', '00000000-0000-0000-0000-00000000158a', 'professional'),
  ('00000000-0000-0000-0000-000000001582', '00000000-0000-0000-0000-00000000158a', 'receptionist'),
  ('00000000-0000-0000-0000-000000001584', '00000000-0000-0000-0000-00000000158b', 'owner');
insert into public.profiles (user_id, org_id, full_name) values
  ('00000000-0000-0000-0000-000000001581', '00000000-0000-0000-0000-00000000158a', 'Profa Bia')
on conflict (user_id, org_id) do update set full_name = excluded.full_name;
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-0000000158c1', '00000000-0000-0000-0000-00000000158a', 'Lucía Prado'),
  ('00000000-0000-0000-0000-0000000158c2', '00000000-0000-0000-0000-00000000158a', 'Marta Gil');
insert into public.staff_members (id, org_id, name, user_id) values
  ('00000000-0000-0000-0000-0000000158a1', '00000000-0000-0000-0000-00000000158a', 'Profa Bia', '00000000-0000-0000-0000-000000001581'),
  ('00000000-0000-0000-0000-0000000158a2', '00000000-0000-0000-0000-00000000158a', 'Outra', null);
insert into public.anamnese_templates (id, org_id, title, questions, consent_text, professional_form) values
  ('00000000-0000-0000-0000-0000000158f1', '00000000-0000-0000-0000-00000000158a', 'Ficha facial',
   '[{"id":"q1","type":"text","text":"Alergias?","required":true},
     {"id":"q2","type":"yes_no","text":"Gestante?","required":true,"explainWhenAnswer":"Sim"},
     {"id":"c1","type":"consent","text":"Imagem","required":true}]'::jsonb, 'Consinto', '{"type":"geral"}'::jsonb);
insert into public.services (id, org_id, name, price, duration_minutes, requires_anamnese, anamnese_template_id) values
  ('00000000-0000-0000-0000-0000000158d1', '00000000-0000-0000-0000-00000000158a', 'Limpeza', 60, 60, true,
   '00000000-0000-0000-0000-0000000158f1');

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
create function pg_temp.logout() returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);
end $$;
create function pg_temp.sig() returns text language sql immutable as $$
  select 'data:image/png;base64,' || repeat('A', 80) $$;
create temp table t (k text primary key, id uuid) on commit drop;
grant all on t to authenticated;
grant execute on function pg_temp.expect(boolean, text), pg_temp.state_of(text), pg_temp.login(uuid), pg_temp.logout(),
  pg_temp.sig() to authenticated;

-- Atendimentos: um da profissional (ap1) e um de outra pessoa (ap2); o serviço cria a ficha sozinho.
select pg_temp.login('00000000-0000-0000-0000-000000001580');
insert into t values
  ('ap1', public.create_appointment_atomic('00000000-0000-0000-0000-00000000158a', '00000000-0000-0000-0000-0000000158c1',
    '00000000-0000-0000-0000-0000000158a1', '2031-05-03 10:00+00', '2031-05-03 11:00+00', 60, 'Agendado', 'MANUAL', null, null, 60,
    '[{"service_id":"00000000-0000-0000-0000-0000000158d1","service_name":"Limpeza","price":60}]'::jsonb, false)),
  ('ap2', public.create_appointment_atomic('00000000-0000-0000-0000-00000000158a', '00000000-0000-0000-0000-0000000158c2',
    '00000000-0000-0000-0000-0000000158a2', '2031-05-04 10:00+00', '2031-05-04 11:00+00', 60, 'Agendado', 'MANUAL', null, null, 60,
    '[{"service_id":"00000000-0000-0000-0000-0000000158d1","service_name":"Limpeza","price":60}]'::jsonb, false));
select pg_temp.logout();
insert into t select 'f1', a.id from public.anamneses a where a.appointment_id = (select id from t where k = 'ap1');
insert into t select 'f2', a.id from public.anamneses a where a.appointment_id = (select id from t where k = 'ap2');
select pg_temp.expect((select count(*) = 2 from t where k in ('f1', 'f2')), 'o serviço criou as fichas (ON CONFLICT com o índice novo)');

-- Assinadas pela cliente (caminho real da assinatura).
select pg_temp.expect((public.anamnese_sign_internal((select id from t where k = k1), 'link',
    '{"q1":"Pólen","q2":"Não","c1":"aceito","__canal":"link","__termo_principal":"aceito","__dados_nome":"Lucía Prado"}',
    'Lucía Prado', pg_temp.sig(), true, 'ua', null)) ->> 'ok' = 'true', 'assina ' || k1)
from unnest(array['f1', 'f2']) k1;
-- Ficha Profissional da f1 concluída (assim a trava do checkout só depende da ficha da cliente).
update public.anamneses set professional_completed_at = now() where id = (select id from t where k = 'f1');
create temp table orig on commit drop as select * from public.anamneses where id in (select id from t where k in ('f1', 'f2'));

-- ─── 1. Permissão e entradas ───────────────────────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001582');
select pg_temp.expect(pg_temp.state_of($q$select public.anamnese_correct_answers('00000000-0000-0000-0000-00000000158a',
  (select id from t where k = 'f1'), '{"q1":"Nada"}', 'motivo')$q$) like '42501%', 'recepção não corrige respostas');
select pg_temp.expect(pg_temp.state_of($q$select public.anamnese_correction_request('00000000-0000-0000-0000-00000000158a',
  (select id from t where k = 'f1'))$q$) like '42501%', 'recepção (sem dado clínico) não reenvia para correção');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000001584');
select pg_temp.expect(pg_temp.state_of($q$select public.anamnese_correct_answers('00000000-0000-0000-0000-00000000158a',
  (select id from t where k = 'f1'), '{"q1":"Nada"}', 'motivo')$q$) like '42501%', 'dona de outro estúdio: sem permissão no estúdio A');
select pg_temp.expect(pg_temp.state_of($q$select public.anamnese_correct_answers('00000000-0000-0000-0000-00000000158b',
  (select id from t where k = 'f1'), '{"q1":"Nada"}', 'motivo')$q$) like 'P0002%', 'ficha de outro estúdio pelo próprio estúdio: não encontrada');
select pg_temp.expect(pg_temp.state_of($q$select public.anamnese_correction_request('00000000-0000-0000-0000-00000000158b',
  (select id from t where k = 'f1'))$q$) like 'P0002%', 'reenviar ficha de outro estúdio: não encontrada');
select pg_temp.logout();

select pg_temp.login('00000000-0000-0000-0000-000000001581');
select pg_temp.expect(pg_temp.state_of($q$select public.anamnese_correct_answers('00000000-0000-0000-0000-00000000158a',
  (select id from t where k = 'f2'), '{"q1":"Nada"}', 'motivo')$q$) like 'P0002%', 'alcance: a profissional não corrige ficha da agenda de outra');
select pg_temp.expect(pg_temp.state_of($q$select public.anamnese_correction_request('00000000-0000-0000-0000-00000000158a',
  (select id from t where k = 'f2'))$q$) like 'P0002%', 'alcance: a profissional não reenvia ficha da agenda de outra');
select pg_temp.expect(pg_temp.state_of(format($q$select public.anamnese_correct_answers('00000000-0000-0000-0000-00000000158a',
  %L, '{"q1":"Nada"}', '   ')$q$, (select id from t where k = 'f1'))) like '22023%motivo%', 'motivo obrigatório');
select pg_temp.expect(pg_temp.state_of(format($q$select public.anamnese_correct_answers('00000000-0000-0000-0000-00000000158a',
  %L, '{"q1":"Nada"}', %L)$q$, (select id from t where k = 'f1'), repeat('m', 501))) like '22023%500%', 'motivo até 500');
select pg_temp.expect(pg_temp.state_of(format($q$select public.anamnese_correct_answers('00000000-0000-0000-0000-00000000158a',
  %L, %L, 'motivo')$q$, (select id from t where k = 'f1'), x)) like '22023%', 'recusa: ' || x)
from unnest(array['{"c1":"recusado"}', '{"__canal":"tablet"}', '{"zz":"x"}', '{"q1":"Pólen"}', '{"q1":""}', '{"q2":"Sim"}', '{"q1":1}']) x;
select pg_temp.expect(pg_temp.state_of($q$select * from public.anamnese_answer_versions$q$) like '42501%', 'versões fechadas para a API');

-- ─── 2. Corrigir respostas: versão nova, original intocada, auditoria sem respostas ────────────────
select pg_temp.expect((public.anamnese_correct_answers('00000000-0000-0000-0000-00000000158a', (select id from t where k = 'f1'),
  '{"q1":"Pólen e látex","q2":"Sim","q2__explain":"12 semanas"}', 'Cliente avisou por telefone')) ->> 'version' = '1', 'versão 1 gravada');
select pg_temp.expect(pg_temp.state_of(format($q$select public.anamnese_correct_answers('00000000-0000-0000-0000-00000000158a',
  %L, '{"q2__explain":""}', 'tirar detalhe')$q$, (select id from t where k = 'f1'))) like '22023%obrigat%',
  'detalhe pedido depois do "Sim" continua obrigatório');
do $$
declare v jsonb;
begin
  v := public.anamnese_ficha_screen('00000000-0000-0000-0000-00000000158a', (select id from t where k = 'f1'), 'ficha') -> 'ficha';
  perform pg_temp.expect(v -> 'answers' ->> 'q1' = 'Pólen e látex' and v -> 'answers' ->> 'q2__explain' = '12 semanas'
    and v -> 'answers' ->> '__canal' = 'link', 'ficha aberta mostra as respostas que valem');
  perform pg_temp.expect(v -> 'signed_answers' ->> 'q1' = 'Pólen' and v -> 'signed_answers' ->> 'q2' = 'Não', 'original assinada consultável');
  perform pg_temp.expect(v -> 'correction' -> 'edit' ->> 'edited_by_name' = 'Profa Bia'
    and v -> 'correction' -> 'edit' ->> 'reason' = 'Cliente avisou por telefone'
    and v -> 'correction' -> 'edit' -> 'changed' = '["q1","q2","q2__explain"]'::jsonb, 'aviso: quem, quando, motivo e perguntas');
end $$;
select pg_temp.logout();
select pg_temp.expect((select a.answers = o.answers and a.signature_data_url = o.signature_data_url and a.signed_at = o.signed_at
  from public.anamneses a join orig o on o.id = a.id where a.id = (select id from t where k = 'f1')), 'a ficha assinada não mudou');
select pg_temp.expect(pg_temp.state_of($q$update public.anamneses set answers = '{"q1":"x"}' where id = (select id from t where k = 'f1')$q$)
  like '23514%', 'a trava da ficha assinada continua (nem o dono do banco troca as respostas)');
select pg_temp.expect((select count(*) = 1 from public.audit_logs l where l.record_id = (select id from t where k = 'f1')
  and l.operation = 'ANAMNESE_ANSWERS_CORRECTED' and l.user_id = '00000000-0000-0000-0000-000000001581'
  and l.new_data = '{"version":1,"changed":["q1","q2","q2__explain"]}'::jsonb), 'auditoria: quem, versão e quais perguntas (só ids)');
select pg_temp.expect(not exists (select 1 from public.audit_logs l where l.org_id = '00000000-0000-0000-0000-00000000158a'
  and (coalesce(l.new_data::text, '') ~ 'látex|semanas|telefone' or coalesce(l.old_data::text, '') ~ 'látex|semanas|telefone')),
  'auditoria sem respostas nem motivo');
select pg_temp.expect(pg_temp.state_of($q$set local role authenticated; insert into public.anamnese_answer_versions
  (org_id, anamnese_id, version, answers, changed_keys, reason) values ('00000000-0000-0000-0000-00000000158a',
  (select id from t where k = 'f1'), 9, '{}', '{q1}', 'x')$q$) like '42501%', 'gravar versão direto pela API: negado');
reset role;

-- ─── 3. Reenviar para a cliente corrigir ───────────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001580');
insert into t select 'f1b', (public.anamnese_correction_request('00000000-0000-0000-0000-00000000158a', (select id from t where k = 'f1')) ->> 'id')::uuid;
select pg_temp.expect((public.anamnese_correction_request('00000000-0000-0000-0000-00000000158a', (select id from t where k = 'f1')))
  = jsonb_build_object('id', (select id from t where k = 'f1b'), 'created', false), 'pedir de novo devolve a mesma correção pendente');
select pg_temp.expect(pg_temp.state_of(format($q$select public.anamnese_correction_request('00000000-0000-0000-0000-00000000158a', %L)$q$,
  (select id from t where k = 'f1b'))) like 'P0001%', 'ficha pendente não se reenvia para correção');
select pg_temp.logout();
select pg_temp.expect((select a.status = 'pending' and a.replaces_anamnese_id = (select id from t where k = 'f1')
    and a.appointment_id = (select id from t where k = 'ap1') and a.template_id = '00000000-0000-0000-0000-0000000158f1'
    and a.client_id = '00000000-0000-0000-0000-0000000158c1' and not a.requires_professional
    and a.template_snapshot = (select template_snapshot from orig where id = (select id from t where k = 'f1'))
    and a.answers = '{"q1":"Pólen e látex","q2":"Sim","q2__explain":"12 semanas","__dados_nome":"Lucía Prado"}'::jsonb
  from public.anamneses a where a.id = (select id from t where k = 'f1b')),
  'correção: mesmo modelo, cliente e atendimento, respostas que valem sem canal nem termos');
select pg_temp.expect((select public.anamnese_public_payload_internal((select id from t where k = 'f1b')) -> 'answers' ->> 'q1') = 'Pólen e látex',
  'o formulário da cliente abre preenchido');
select pg_temp.expect((select count(*) = 1 from public.audit_logs where record_id = (select id from t where k = 'f1b')
  and operation = 'ANAMNESE_CREATED' and new_data ->> 'replaces' = (select id from t where k = 'f1')::text), 'criação registrada com a ligação');

-- Antes de assinar a nova, a anterior continua valendo.
select pg_temp.login('00000000-0000-0000-0000-000000001580');
select pg_temp.expect(not exists (select 1 from public.get_appointment_anamnese_gate('00000000-0000-0000-0000-00000000158a',
  (select id from t where k = 'ap1'), 'checkout')), 'correção pendente não trava o checkout (vale a anterior)');
select pg_temp.expect((select array_agg(s.id) = array[(select id from t where k = 'f1')] and bool_and(s.superseded_by is null)
  from public.list_anamnese_status('00000000-0000-0000-0000-00000000158a', array[(select id from t where k = 'ap1')]) s),
  'pelo atendimento: só a anterior, ainda não substituída');
select pg_temp.expect((select count(*) = 2 from public.list_anamnese_status('00000000-0000-0000-0000-00000000158a',
  p_client_id => '00000000-0000-0000-0000-0000000158c1')), 'no histórico da cliente aparecem as duas');
select pg_temp.expect((select v -> 'ficha' -> 'correction' -> 'pending_correction' ->> 'id' = (select id from t where k = 'f1b')::text
  and v -> 'ficha' -> 'correction' -> 'superseded_by' = 'null'::jsonb
  from (select public.anamnese_ficha_screen('00000000-0000-0000-0000-00000000158a', (select id from t where k = 'f1'), 'ficha') v) s),
  'a anterior mostra a correção pendente e não está substituída');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000001581');
select pg_temp.expect(pg_temp.state_of(format($q$select public.anamnese_correct_answers('00000000-0000-0000-0000-00000000158a',
  %L, '{"q1":"Outra"}', 'x')$q$, (select id from t where k = 'f1'))) like 'P0001%', 'com correção enviada à cliente, não corrige a anterior');
select pg_temp.logout();

-- A cliente assina a correção: a anterior vira substituída e a trava passa a usar a nova.
select pg_temp.expect((public.anamnese_sign_internal((select id from t where k = 'f1b'), 'link',
    '{"q1":"Só látex","q2":"Não","c1":"aceito","__canal":"link","__termo_principal":"aceito"}',
    'Lucía Prado', pg_temp.sig(), true, 'ua', null)) ->> 'ok' = 'true', 'assina a correção');
select pg_temp.expect((select a.answers = o.answers and a.status = 'signed' and a.signature_data_url = o.signature_data_url
  and a.updated_at = o.updated_at from public.anamneses a join orig o on o.id = a.id where a.id = (select id from t where k = 'f1')),
  'a anterior não mudou nada ao ser substituída');
select pg_temp.expect((select count(*) = 1 from public.audit_logs where record_id = (select id from t where k = 'f1')
  and operation = 'ANAMNESE_SUPERSEDED' and new_data ->> 'superseded_by' = (select id from t where k = 'f1b')::text), 'substituição registrada');
select pg_temp.login('00000000-0000-0000-0000-000000001580');
select pg_temp.expect((select s.superseded_by = (select id from t where k = 'f1b')
  from public.list_anamnese_status('00000000-0000-0000-0000-00000000158a', p_ids => array[(select id from t where k = 'f1')]) s),
  'a anterior aparece como substituída, com a ligação para a nova');
select pg_temp.expect((select v -> 'ficha' -> 'correction' -> 'replaces' ->> 'id' = (select id from t where k = 'f1')::text
  and v -> 'ficha' -> 'answers' ->> 'q1' = 'Só látex' and v -> 'ficha' -> 'signed_answers' = 'null'::jsonb
  from (select public.anamnese_ficha_screen('00000000-0000-0000-0000-00000000158a', (select id from t where k = 'f1b'), 'ficha') v) s),
  'a nova mostra a ligação para a anterior');
select pg_temp.expect(not exists (select 1 from public.get_appointment_anamnese_gate('00000000-0000-0000-0000-00000000158a',
  (select id from t where k = 'ap1'), 'checkout')), 'trava do checkout com a nova assinada: livre');
select pg_temp.expect(pg_temp.state_of(format($q$select public.anamnese_correction_request('00000000-0000-0000-0000-00000000158a', %L)$q$,
  (select id from t where k = 'f1'))) like 'P0001%substitu%', 'a substituída não se corrige de novo');
select pg_temp.logout();
-- Lista de Fichas: a substituída tem situação própria (não conta como concluída) e filtro próprio.
select pg_temp.login('00000000-0000-0000-0000-000000001580');
select pg_temp.expect((select (v -> 'counts' ->> 'substituida')::int = 1 and (v -> 'counts' ->> 'concluida')::int = 1
  from (select public.anamnese_fichas_page('00000000-0000-0000-0000-00000000158a', null, 'todas', null, 'atendimento', 1, 10, null, false, null) v) x),
  'totais: 1 substituída e só a nova como concluída');
select pg_temp.expect((select (v ->> 'total')::int = 1 and v -> 'rows' -> 0 ->> 'id' = (select id from t where k = 'f1')::text
    and v -> 'rows' -> 0 ->> 'superseded_by' = (select id from t where k = 'f1b')::text
  from (select public.anamnese_fichas_page('00000000-0000-0000-0000-00000000158a', null, 'substituida', null, 'atendimento', 1, 10, null, false, null) v) x),
  'filtro "substituida" traz só a anterior, com a ligação');
select pg_temp.expect((select (v -> 'counts' ->> 'substituida')::int = 1 from (select public.anamnese_overview('00000000-0000-0000-0000-00000000158a',
  now() - interval '1 year', now() + interval '10 years') v) x), 'visão geral conta a substituída à parte');
-- Agenda e Comanda: a original aparece com a ligação para a nova.
select pg_temp.expect((select f ->> 'superseded_by' = (select id from t where k = 'f1b')::text
  from jsonb_array_elements(public.agenda_appointment_fichas('00000000-0000-0000-0000-00000000158a', (select id from t where k = 'ap1')) -> 'fichas') f
  where f ->> 'id' = (select id from t where k = 'f1')::text), 'Agenda: fichas do atendimento com superseded_by');
select pg_temp.expect((select f ->> 'superseded_by' = (select id from t where k = 'f1b')::text
  from jsonb_array_elements(public.checkout_screen('00000000-0000-0000-0000-00000000158a', (select id from t where k = 'ap1')) -> 'appointment' -> 'fichas') f
  where f ->> 'id' = (select id from t where k = 'f1')::text), 'Comanda: fichas do atendimento com superseded_by');
select pg_temp.logout();

-- A trava segue a ficha que vale: Ficha Profissional pendente (na original) continua travando depois da substituição.
update public.anamneses set professional_completed_at = null where id = (select id from t where k = 'f1');
select pg_temp.login('00000000-0000-0000-0000-000000001580');
select pg_temp.expect((select string_agg(g.issue_code || ':' || g.anamnese_id, ',') from public.get_appointment_anamnese_gate(
  '00000000-0000-0000-0000-00000000158a', (select id from t where k = 'ap1'), 'checkout') g)
  = 'PROFESSIONAL_PENDING:' || (select id from t where k = 'f1'), 'Ficha Profissional pendente da original continua travando');
select pg_temp.expect((select (v -> 'counts' ->> 'substituida')::int = 0 and (v -> 'counts' ->> 'profissional')::int = 2
  from (select public.anamnese_fichas_page('00000000-0000-0000-0000-00000000158a', null, 'todas', null, 'atendimento', 1, 10, null, false, null) v) x),
  'substituída com a Ficha Profissional pendente aparece como profissional pendente');
select pg_temp.logout();

-- A correção pendente de f2 (revogada) libera pedir outra; enquanto pendente, a f2 vale.
select pg_temp.login('00000000-0000-0000-0000-000000001580');
insert into t select 'f2b', (public.anamnese_correction_request('00000000-0000-0000-0000-00000000158a', (select id from t where k = 'f2')) ->> 'id')::uuid;
select public.anamnese_delete_pending('00000000-0000-0000-0000-00000000158a', (select id from t where k = 'f2b'));
select pg_temp.expect((public.anamnese_correction_request('00000000-0000-0000-0000-00000000158a', (select id from t where k = 'f2'))) ->> 'created' = 'true',
  'revogada a correção pendente, dá para pedir outra');
select pg_temp.logout();
select pg_temp.expect((select a.answers = o.answers from public.anamneses a join orig o on o.id = a.id where a.id = (select id from t where k = 'f2')),
  'f2 continua igual');

rollback;
\o
\echo 'corrigir ficha assinada: original preservada, versões, substituição só após assinar, permissão, alcance, auditoria (158): ok'
