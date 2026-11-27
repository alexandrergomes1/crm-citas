-- Anamnese (porte): migrations 20261114040000 a 20261114040700. Isolamento entre estúdios, anônimo sem execução,
-- papéis (recepção e financeiro sem conteúdo clínico; profissional só com a própria agenda vê e mexe só nas suas),
-- tabela e fotos fechadas para a API direta (nem dona, nem profissional, nem recepção leem, inserem, alteram ou
-- apagam: só pelas funções), created_by gravado pelo banco, link só para ficha pendente e no prazo, auditoria por
-- gatilho/DEFINER, não forjável e com a data do banco, só caminhos de foto da própria ficha, troca de cliente
-- barrada com ficha ligada (mesmo para quem não lê fichas), totais do banco e caminhos felizes.
-- Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000001520', 'dona@an152.local'),
  ('00000000-0000-0000-0000-000000001521', 'profa@an152.local'),
  ('00000000-0000-0000-0000-000000001522', 'recep@an152.local'),
  ('00000000-0000-0000-0000-000000001523', 'fin@an152.local'),
  ('00000000-0000-0000-0000-000000001524', 'donab@an152.local');
insert into public.organizations (id, slug, name, timezone) values
  ('00000000-0000-0000-0000-00000000152a', 'an152-a', 'Anamnese 152 A', 'Europe/Madrid'),
  ('00000000-0000-0000-0000-00000000152b', 'an152-b', 'Anamnese 152 B', 'Europe/Madrid');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000001520', '00000000-0000-0000-0000-00000000152a', 'owner'),
  ('00000000-0000-0000-0000-000000001521', '00000000-0000-0000-0000-00000000152a', 'professional'),
  ('00000000-0000-0000-0000-000000001522', '00000000-0000-0000-0000-00000000152a', 'receptionist'),
  ('00000000-0000-0000-0000-000000001523', '00000000-0000-0000-0000-00000000152a', 'finance'),
  ('00000000-0000-0000-0000-000000001524', '00000000-0000-0000-0000-00000000152b', 'owner');
insert into public.profiles (user_id, org_id, full_name) values
  ('00000000-0000-0000-0000-000000001520', '00000000-0000-0000-0000-00000000152a', 'Dona Ana')
on conflict (user_id, org_id) do update set full_name = excluded.full_name;
insert into public.clients (id, org_id, full_name, phone, alert_text) values
  ('00000000-0000-0000-0000-0000000015c1', '00000000-0000-0000-0000-00000000152a', 'Cliente Um', '+34600000001', 'Alergia'),
  ('00000000-0000-0000-0000-0000000015c2', '00000000-0000-0000-0000-00000000152a', 'Cliente Dois', '+34600000002', null),
  ('00000000-0000-0000-0000-0000000015c9', '00000000-0000-0000-0000-00000000152b', 'Cliente B', '+34600000009', null);
insert into public.staff_members (id, org_id, name, user_id, position) values
  ('00000000-0000-0000-0000-0000000015a1', '00000000-0000-0000-0000-00000000152a', 'Profissional A', '00000000-0000-0000-0000-000000001521', 1),
  ('00000000-0000-0000-0000-0000000015a2', '00000000-0000-0000-0000-00000000152a', 'Profissional B', null, 2);
insert into public.anamnese_templates (id, org_id, title, questions, professional_form) values
  ('00000000-0000-0000-0000-0000000015f1', '00000000-0000-0000-0000-00000000152a', 'Ficha facial',
   '[{"id":"q1","type":"text","text":"Alergias?"}]'::jsonb, '{"type":"geral"}'::jsonb),
  ('00000000-0000-0000-0000-0000000015f9', '00000000-0000-0000-0000-00000000152b', 'Ficha do B',
   '[{"id":"q1","type":"text","text":"Alergias?"}]'::jsonb, null);
insert into public.services (id, org_id, name, price, duration_minutes, requires_anamnese, anamnese_template_id) values
  ('00000000-0000-0000-0000-0000000015d1', '00000000-0000-0000-0000-00000000152a', 'Limpeza', 60, 60, false,
   '00000000-0000-0000-0000-0000000015f1');

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
-- Auditoria lida como dono do banco (só a gestão lê audit_logs pela RLS).
create function pg_temp.audits(p_where text) returns bigint language plpgsql security definer set search_path = '' as $$
declare v bigint;
begin
  execute 'select count(*) from public.audit_logs where ' || p_where into v;
  return v;
end $$;
create temp table t_ids (k text primary key, id uuid) on commit drop;
grant all on t_ids to authenticated;
grant execute on function pg_temp.expect(boolean, text), pg_temp.state_of(text), pg_temp.login(uuid), pg_temp.logout(),
  pg_temp.audits(text) to anon, authenticated;

-- Cenário (como dono do banco): no A, um agendamento da profissional A (e1) e um da B (e2); ficha b1 no e1 (pendente),
-- b2 no e2 (assinada, com dado clínico e foto), b3 sem atendimento gerada pela profissional A (link vencido).
insert into public.appointments (id, org_id, client_id, client_name, staff_id, start_at, end_at, duration_minutes, status) values
  ('00000000-0000-0000-0000-0000000015e1', '00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015c1',
   'Cliente Um', '00000000-0000-0000-0000-0000000015a1', now() + interval '2 days', now() + interval '2 days 1 hour', 60, 'Agendado'),
  ('00000000-0000-0000-0000-0000000015e2', '00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015c2',
   'Cliente Dois', '00000000-0000-0000-0000-0000000015a2', now() + interval '3 days', now() + interval '3 days 1 hour', 60, 'Agendado');
insert into public.anamneses (id, org_id, client_id, client_name, template_id, template_title, appointment_id, status,
  public_token, token_expires_at, requires_professional, template_snapshot, created_at) values
  ('00000000-0000-0000-0000-0000000015b1', '00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015c1',
   'Cliente Um', '00000000-0000-0000-0000-0000000015f1', 'Ficha facial', '00000000-0000-0000-0000-0000000015e1', 'pending',
   'tok-152-pendente-0123456789abcdef', now() + interval '5 days', true, '{"questions":[],"professional_form":{"type":"geral"}}', now() - interval '2 days');
insert into public.anamneses (id, org_id, client_id, client_name, template_id, template_title, appointment_id, status, answers,
  professional_notes, professional_data, public_token, token_expires_at, signature_name, signed_at, requires_professional, signer_ip)
values ('00000000-0000-0000-0000-0000000015b2', '00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015c2',
  'Cliente Dois', '00000000-0000-0000-0000-0000000015f1', 'Ficha facial', '00000000-0000-0000-0000-0000000015e2', 'signed',
  '{"q1":"Alergia a látex"}', 'nota clínica',
  '{"photos":["00000000-0000-0000-0000-00000000152a/00000000-0000-0000-0000-0000000015b2/11111111-1111-4111-8111-111111111111.jpg",
              "00000000-0000-0000-0000-00000000152a/00000000-0000-0000-0000-0000000015b1/99999999-9999-4999-8999-999999999999.jpg"]}',
  'tok-152-assinada-0123456789abcdef', now() + interval '5 days', 'Cliente Dois', now(), false, '203.0.113.0');
-- b3: gerada pela profissional A (o banco grava created_by = auth.uid(), mesmo que outro valor venha no INSERT).
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000001521', 'role', 'authenticated')::text, true);
insert into public.anamneses (id, org_id, client_id, client_name, template_id, template_title, status, public_token,
  token_expires_at, requires_professional, template_snapshot, created_by, created_at)
values ('00000000-0000-0000-0000-0000000015b3', '00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015c2',
  'Cliente Dois', '00000000-0000-0000-0000-0000000015f1', 'Ficha facial', 'pending', 'tok-152-gerada-pela-profa-0123456',
  now() - interval '1 day', false, '{"questions":[]}', '00000000-0000-0000-0000-000000001520', now() - interval '3 days');
select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select created_by = '00000000-0000-0000-0000-000000001521' from public.anamneses where id = '00000000-0000-0000-0000-0000000015b3'),
  'created_by vem do banco, não do INSERT');
update public.anamneses set created_by = '00000000-0000-0000-0000-000000001520' where id = '00000000-0000-0000-0000-0000000015b3';
select pg_temp.expect((select created_by = '00000000-0000-0000-0000-000000001521' from public.anamneses where id = '00000000-0000-0000-0000-0000000015b3'),
  'created_by não muda no UPDATE');
insert into public.anamneses (id, org_id, client_id, client_name, template_id, template_title, status, public_token, token_expires_at)
values ('00000000-0000-0000-0000-0000000015b9', '00000000-0000-0000-0000-00000000152b', '00000000-0000-0000-0000-0000000015c9',
  'Cliente B', '00000000-0000-0000-0000-0000000015f9', 'Ficha do B', 'pending', 'tok-152-do-estudio-b-0123456789', now() + interval '5 days');
-- b3 com um caminho de foto de OUTRA ficha gravado (dado antigo/forjado): nunca sai para assinar ou apagar.
update public.anamneses set professional_data = '{"photos":["00000000-0000-0000-0000-00000000152a/00000000-0000-0000-0000-0000000015b2/11111111-1111-4111-8111-111111111111.jpg"]}'
where id = '00000000-0000-0000-0000-0000000015b3';
-- Registro sem relação com a leitura da ficha, com o mesmo id (não pode aparecer em "últimos acessos"), e data forjada.
insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, created_at) values
  ('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-000000001520', 'anamneses', 'ANAMNESE_LINK_RENEWED',
   '00000000-0000-0000-0000-0000000015b2', '2000-01-01');
select pg_temp.expect(pg_temp.audits($w$record_id = '00000000-0000-0000-0000-0000000015b2' and created_at < now() - interval '1 minute'$w$) = 0,
  'audit_logs.created_at é sempre a hora do banco');
insert into storage.buckets (id, name) values ('anamnese-photos', 'anamnese-photos') on conflict do nothing;
insert into storage.objects (bucket_id, name) values
  ('anamnese-photos', '00000000-0000-0000-0000-00000000152a/00000000-0000-0000-0000-0000000015b2/11111111-1111-4111-8111-111111111111.jpg');

-- ─── Execução: anônimo nada; funções internas e de gatilho, ninguém ─────────────────────────────
select pg_temp.expect(not has_function_privilege('anon', p.oid, 'execute') and not has_function_privilege('public', p.oid, 'execute'),
  'anon/public sem execute em ' || p.proname)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and (p.proname like 'anamnese\_%' escape '\' or p.proname like 'anamneses\_%' escape '\'
  or p.proname in ('list_anamnese_status', 'save_anamnese_professional_data_atomic', 'save_anamnese_professional_notes_atomic'));
select pg_temp.expect(not has_function_privilege('authenticated', p.oid, 'execute'), 'authenticated sem execute em ' || p.proname)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and (p.proname in ('anamnese_templates_audit', 'anamneses_audit', 'anamneses_set_created_by', 'audit_logs_force_created_at',
  'save_anamnese_professional_data_atomic', 'save_anamnese_professional_notes_atomic') or p.proname like 'anamnese\_%\_internal' escape '\');
select set_config('role', 'anon', true);
select pg_temp.expect(pg_temp.state_of($q$select public.anamnese_fichas_page('00000000-0000-0000-0000-00000000152a', null, 'todas', null,
  'atendimento', 1, 10, null, false, null)$q$) like '42501%', 'anônimo não lê');
select pg_temp.logout();
select pg_temp.expect(not has_table_privilege(r, 'public.anamneses', pr), r || ' sem ' || pr || ' na tabela anamneses')
from unnest(array['anon', 'authenticated']) r, unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE']) pr;
select pg_temp.expect(not exists (select 1 from pg_policies where schemaname = 'storage' and (qual ~ 'anamnese' or with_check ~ 'anamnese')),
  'fotos sem política no Storage (só o servidor, com a chave de serviço)');

-- ─── Dona: tudo do A, totais do banco, link só pendente e no prazo, leitura clínica registrada ─────
select pg_temp.login('00000000-0000-0000-0000-000000001520');
do $$
declare v jsonb; f jsonb;
begin
  v := public.anamnese_fichas_page('00000000-0000-0000-0000-00000000152a', null, 'todas', null, 'atendimento', 1, 50, null, true, now() - interval '1 day');
  perform pg_temp.expect((v ->> 'total')::int = 3 and pg_catalog.jsonb_array_length(v -> 'rows') = 3, 'dona vê as 3 fichas do A (nada do B)');
  perform pg_temp.expect((v -> 'counts' ->> 'todas')::int = 3 and (v -> 'counts' ->> 'aguardando')::int = 1
    and (v -> 'counts' ->> 'expirado')::int = 1 and (v -> 'counts' ->> 'concluida')::int = 1, 'contagem por situação');
  perform pg_temp.expect(v -> 'rows' -> 0 ->> 'id' = '00000000-0000-0000-0000-0000000015b2', 'ordem: atendimento mais recente primeiro');
  select x into f from pg_catalog.jsonb_array_elements(v -> 'rows') x where x ->> 'id' = '00000000-0000-0000-0000-0000000015b1';
  -- 20261114100000: o banco guarda só o hash; a lista nunca traz o link (reenviar gera um novo).
  perform pg_temp.expect(f ->> 'public_token' is null and f ->> 'client_phone' = '+34600000001'
    and f ->> 'client_alert' = 'Alergia' and f ->> 'appointment_at' is not null, 'pendente no prazo: cadastro e atendimento, sem link');
  perform pg_temp.expect(not (f ?| array['answers', 'professional_notes', 'professional_data', 'signature_name', 'signer_ip']), 'lista sem campo clínico');
  perform pg_temp.expect((select bool_and((x ->> 'public_token') is null) from pg_catalog.jsonb_array_elements(v -> 'rows') x
    where x ->> 'id' <> '00000000-0000-0000-0000-0000000015b1'), 'assinada e vencida sem link');
  perform pg_temp.expect(pg_catalog.jsonb_array_length(v -> 'clients') = 2 and pg_catalog.jsonb_array_length(v -> 'appointments') = 2
    and pg_catalog.jsonb_array_length(v -> 'templates') = 1, 'clientes, atendimentos e modelos do envio');
  perform pg_temp.expect(v -> 'urgent' ->> 'id' = '00000000-0000-0000-0000-0000000015b1', 'aviso: atendimento em até 2 dias sem assinatura');

  v := public.anamnese_fichas_page('00000000-0000-0000-0000-00000000152a', 'dois', 'todas', null, 'cliente', 2, 1,
    '00000000-0000-0000-0000-0000000015b1', false, null);
  perform pg_temp.expect((v ->> 'total')::int = 2 and pg_catalog.jsonb_array_length(v -> 'rows') = 1, 'busca e página no banco');
  perform pg_temp.expect(v -> 'link' ->> 'id' = '00000000-0000-0000-0000-0000000015b1', 'ficha do link pronto fora da página');
  perform pg_temp.expect(pg_temp.state_of($q$select public.anamnese_fichas_page('00000000-0000-0000-0000-00000000152a', null, 'x', null,
    'atendimento', 1, 10, null, false, null)$q$) like '22023%', 'filtro inválido recusado');

  v := public.anamnese_fichas_export('00000000-0000-0000-0000-00000000152a', 'Cliente', 'todas', null, 'cliente');
  perform pg_temp.expect(pg_catalog.jsonb_array_length(v -> 'rows') = 3, 'exportar: as linhas da lista');
  perform pg_temp.expect(pg_temp.audits($w$operation = 'ANAMNESE_FICHAS_EXPORTED' and user_id = '00000000-0000-0000-0000-000000001520'
    and record_id is null and (new_data ->> 'count')::int = 3 and (new_data ->> 'with_search')::boolean
    and new_data::text not like '%Cliente%'$w$) = 1, 'exportar: auditado com quantas e filtros, sem o texto da busca');

  v := public.anamnese_overview('00000000-0000-0000-0000-00000000152a', now() - interval '20 days', now() + interval '20 days');
  perform pg_temp.expect((v -> 'counts' ->> 'todas')::int = 3 and (v -> 'month' ->> 'total')::int = 3, 'visão geral: totais do banco');
  perform pg_temp.expect(pg_catalog.jsonb_array_length(v -> 'rows') = 3, 'visão geral: fichas candidatas');

  v := public.anamnese_catalog_screen('00000000-0000-0000-0000-00000000152a', true);
  perform pg_temp.expect((v -> 'usage' ->> '00000000-0000-0000-0000-0000000015f1')::int = 3 and (v ->> 'pending')::int = 1,
    'modelos: fichas por modelo e pendentes, sem linha de ficha');
  perform pg_temp.expect(pg_catalog.jsonb_array_length(v -> 'services') = 1 and (v -> 'templates' -> 0) ? 'questions', 'modelos: serviços e modelo inteiro');

  v := public.anamnese_ficha_screen('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015b2');
  perform pg_temp.expect((v ->> 'clinical')::boolean and v -> 'ficha' -> 'answers' ->> 'q1' = 'Alergia a látex', 'dona abre a ficha clínica');
  perform pg_temp.expect(v -> 'ficha' ->> 'public_token' is null and not ((v -> 'ficha') ? 'created_by'), 'ficha aberta sem link (assinada)');
  perform pg_temp.expect(v -> 'ficha' ->> 'signer_ip' = '203.0.•••.•••', 'IP mascarado no banco');
  perform pg_temp.expect(pg_temp.audits($w$record_id = '00000000-0000-0000-0000-0000000015b2' and operation = 'CLINICAL_READ'
    and user_id = '00000000-0000-0000-0000-000000001520'$w$) = 1, 'CLINICAL_READ gravado');
  perform pg_temp.expect(pg_catalog.jsonb_array_length(v -> 'accesses') >= 1, 'gestão vê os acessos');
  perform pg_temp.expect(not exists (select 1 from pg_catalog.jsonb_array_elements(v -> 'accesses') x where x ->> 'operation' = 'ANAMNESE_LINK_RENEWED'),
    'últimos acessos: só leitura clínica e Ficha Profissional');
  v := public.anamnese_ficha_screen('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015b2', 'janela');
  perform pg_temp.expect(v -> 'ficha' -> 'professional_data' = 'null'::jsonb and v -> 'ficha' -> 'professional_notes' = 'null'::jsonb
    and not (v ? 'accesses') and v -> 'ficha' -> 'answers' ->> 'q1' = 'Alergia a látex', 'janela do perfil: só o que mostra');

  perform pg_temp.expect(public.anamnese_ficha_screen('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015b9') is null,
    'ficha do outro estúdio: nulo');
  perform pg_temp.expect(pg_temp.state_of($q$select public.anamnese_fichas_page('00000000-0000-0000-0000-00000000152b', null, 'todas', null,
    'atendimento', 1, 10, null, false, null)$q$) like '42501%', 'dona do A não lê o B');
  perform pg_temp.expect(pg_temp.state_of($q$select public.anamnese_delete_pending('00000000-0000-0000-0000-00000000152b',
    '00000000-0000-0000-0000-0000000015b9')$q$) like '42501%', 'dona do A não apaga ficha do B');

  -- Perfil: client_profile não grava nada; as fotos saem sob demanda, com CLINICAL_READ.
  v := public.client_profile('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015c2', array['Concluído'], true);
  perform pg_temp.expect((v ->> 'photo_count')::int = 1 and not (v ? 'photo_sources'), 'perfil: só o número de fotos da própria ficha');
  perform pg_temp.expect(pg_temp.audits($w$operation = 'CLINICAL_READ' and new_data ->> 'source' = 'client_profile_photos'$w$) = 0,
    'abrir o perfil não grava leitura clínica');
  v := public.anamnese_client_photos('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015c2');
  perform pg_temp.expect(pg_catalog.jsonb_array_length(v) = 1, 'fotos da cliente sob demanda');
  perform pg_temp.expect(v -> 0 -> 'professional_data' -> 'photos' = '["00000000-0000-0000-0000-00000000152a/00000000-0000-0000-0000-0000000015b2/11111111-1111-4111-8111-111111111111.jpg"]'::jsonb,
    'fotos do perfil: só caminhos da própria ficha');
  perform pg_temp.expect(pg_temp.audits($w$record_id = '00000000-0000-0000-0000-0000000015b2' and operation = 'CLINICAL_READ'
    and new_data ->> 'source' = 'client_profile_photos'$w$) = 1, 'fotos do perfil gravam CLINICAL_READ');
  v := public.anamnese_client_fichas('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015c2');
  perform pg_temp.expect(pg_catalog.jsonb_array_length(v) = 2 and not ((v -> 0) ? 'answers'), 'perfil: fichas sem respostas');
  perform pg_temp.expect((select x ->> 'signature_name' from pg_catalog.jsonb_array_elements(v) x
    where x ->> 'id' = '00000000-0000-0000-0000-0000000015b2') = 'Cliente Dois', 'perfil: nome da assinatura para quem tem leitura clínica');
  perform pg_temp.expect(pg_temp.audits($w$record_id = '00000000-0000-0000-0000-0000000015b2' and operation = 'CLINICAL_READ'
    and new_data ->> 'source' = 'client_profile_fichas'$w$) = 1, 'nome da assinatura no perfil grava CLINICAL_READ');
end $$;

-- ─── Recepção: status sem conteúdo clínico, gera e renova link, não forja auditoria ────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001522');
do $$
declare v jsonb;
begin
  v := public.anamnese_overview('00000000-0000-0000-0000-00000000152a', now() - interval '20 days', now() + interval '20 days');
  perform pg_temp.expect((v -> 'counts' ->> 'todas')::int = 3, 'recepção vê o status das 3');
  v := public.anamnese_ficha_screen('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015b2');
  perform pg_temp.expect(not (v ->> 'clinical')::boolean and not ((v -> 'ficha') ?| array['answers', 'professional_notes', 'signature_name']),
    'recepção: ficha só com status');
  perform pg_temp.expect(pg_temp.audits($w$user_id = '00000000-0000-0000-0000-000000001522' and operation = 'CLINICAL_READ'$w$) = 0,
    'status não grava leitura clínica');
  perform pg_temp.expect((select count(*) from storage.objects where bucket_id = 'anamnese-photos') = 0, 'recepção não lê foto');
  -- B1: nada direto na tabela (nem forjar ficha "assinada", token, validade ou fotos).
  perform pg_temp.expect(pg_temp.state_of(f) like '42501%', 'recepção, API direta recusada: ' || f)
  from pg_catalog.unnest(array[
    $q$select count(*) from public.anamneses$q$,
    $q$insert into public.anamneses (org_id, client_name, status, public_token, token_expires_at, signed_at, signature_name)
      values ('00000000-0000-0000-0000-00000000152a', 'Forjada', 'signed', 'tok-152-forjado-0123456789abcdef', now() + interval '1 year', now(), 'X')$q$,
    $q$update public.anamneses set token_expires_at = now() + interval '1 year' where id = '00000000-0000-0000-0000-0000000015b1'$q$,
    $q$update public.anamneses set status = 'signed', signed_at = now() where id = '00000000-0000-0000-0000-0000000015b1'$q$,
    $q$delete from public.anamneses where id = '00000000-0000-0000-0000-0000000015b1'$q$]) f;
  -- D4: a recepção não lê fichas, mas a troca de cliente de um atendimento com ficha continua barrada.
  perform pg_temp.expect(pg_temp.state_of($q$select public.agenda_change_client('00000000-0000-0000-0000-00000000152a',
    '00000000-0000-0000-0000-0000000015e1', '00000000-0000-0000-0000-0000000015c2')$q$) like 'P0001: Este agendamento tem ficha%',
    'recepção não troca a cliente de atendimento com ficha');
  perform pg_temp.expect(public.anamnese_exists_for('00000000-0000-0000-0000-00000000152b', null, null)
    and public.anamnese_exists_for('00000000-0000-0000-0000-00000000152b', '00000000-0000-0000-0000-0000000015e1', null),
    'existe ficha? fora do próprio estúdio responde sim (bloqueia), sem revelar nada');

  perform public.set_anamnese_link_validity('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015b3', 7);
  perform pg_temp.expect(pg_temp.audits($w$record_id = '00000000-0000-0000-0000-0000000015b3' and operation = 'ANAMNESE_LINK_RENEWED'
    and user_id = '00000000-0000-0000-0000-000000001522'$w$) = 1, 'renovação auditada pelo gatilho');
  perform pg_temp.expect(public.log_anamnese_send('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015b3', 'copy') is not null,
    'envio registrado');
  perform pg_temp.expect(pg_temp.state_of($q$select public.set_anamnese_link_validity('00000000-0000-0000-0000-00000000152a',
    '00000000-0000-0000-0000-0000000015b9', 7)$q$) like 'P0002%', 'recepção não renova ficha do B');
  perform pg_temp.expect(pg_temp.state_of($q$select public.anamnese_save_professional('00000000-0000-0000-0000-00000000152a',
    '00000000-0000-0000-0000-0000000015b1', '{}', '{}', '', false)$q$) like '42501%', 'recepção não preenche a parte profissional');
  perform pg_temp.expect(pg_temp.state_of($q$select public.save_anamnese_professional_notes_atomic('00000000-0000-0000-0000-00000000152a',
    '00000000-0000-0000-0000-0000000015b1', 'x')$q$) like '42501%', 'função antiga sem execução pela API');
  perform pg_temp.expect(pg_temp.state_of($q$select public.anamnese_save_template('00000000-0000-0000-0000-00000000152a', null,
    '{"title":"X","questions":[{"id":"a","type":"text","text":"x"}]}', true)$q$) like '42501%', 'recepção não edita modelos');
  perform pg_temp.expect(pg_temp.state_of(f) like '42501%', 'auditoria não se forja: ' || f)
  from pg_catalog.unnest(array[
    $q$insert into public.audit_logs (org_id, user_id, table_name, operation, record_id) values ('00000000-0000-0000-0000-00000000152a',
      '00000000-0000-0000-0000-000000001522', 'anamneses', 'CLINICAL_READ', '00000000-0000-0000-0000-0000000015b2')$q$,
    $q$insert into public.audit_logs (org_id, user_id, table_name, operation, record_id) values ('00000000-0000-0000-0000-00000000152a',
      '00000000-0000-0000-0000-000000001522', 'anamneses', 'PROFESSIONAL_COMPLETED', '00000000-0000-0000-0000-0000000015b2')$q$,
    $q$insert into public.audit_logs (org_id, user_id, table_name, operation, record_id) values ('00000000-0000-0000-0000-00000000152a',
      '00000000-0000-0000-0000-000000001522', 'anamnese_templates', 'ANAMNESE_TEMPLATE_SAVED', '00000000-0000-0000-0000-0000000015f1')$q$,
    $q$insert into public.audit_logs (org_id, user_id, table_name, operation, record_id) values ('00000000-0000-0000-0000-00000000152a',
      '00000000-0000-0000-0000-000000001522', 'anamneses', 'ANAMNESE_LINK_RENEWED', '00000000-0000-0000-0000-0000000015b3')$q$,
    $q$insert into public.audit_logs (org_id, user_id, table_name, operation, record_id) values ('00000000-0000-0000-0000-00000000152a',
      '00000000-0000-0000-0000-000000001522', 'anamneses', 'ANAMNESE_PENDING_DELETED', '00000000-0000-0000-0000-0000000015b1')$q$]) f;

  v := public.anamnese_create_link('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015f1', null, 'x',
    '00000000-0000-0000-0000-0000000015e2', null, 7, 'whatsapp');
  perform pg_temp.expect(v ->> 'id' = '00000000-0000-0000-0000-0000000015b2' and v ->> 'token' is null,
    'atendimento com ficha assinada: devolve a ficha sem link');
end $$;

-- ─── Financeiro: nada da anamnese ───────────────────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001523');
select pg_temp.expect(pg_temp.state_of($q$select public.anamnese_overview('00000000-0000-0000-0000-00000000152a', now(), now())$q$) like '42501%', 'financeiro não lê fichas');
select pg_temp.expect(pg_temp.state_of($q$select public.anamnese_ficha_screen('00000000-0000-0000-0000-00000000152a',
  '00000000-0000-0000-0000-0000000015b2')$q$) like '42501%', 'financeiro não abre ficha');
select pg_temp.expect(pg_temp.state_of($q$select public.list_anamnese_status('00000000-0000-0000-0000-00000000152a')$q$) like '42501%', 'financeiro sem status');

-- ─── Profissional (só a própria agenda): só as suas, também pela API direta ────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001521');
do $$
declare v jsonb; v_n int; v_ok boolean;
begin
  v := public.anamnese_fichas_page('00000000-0000-0000-0000-00000000152a', null, 'todas', null, 'cliente', 1, 50, null, true, null);
  perform pg_temp.expect((select pg_catalog.array_agg(x ->> 'id' order by x ->> 'id') from pg_catalog.jsonb_array_elements(v -> 'rows') x)
    = array['00000000-0000-0000-0000-0000000015b1', '00000000-0000-0000-0000-0000000015b3'], 'lista: a do atendimento dela e a que gerou');
  perform pg_temp.expect((v -> 'counts' ->> 'todas')::int = 2 and pg_catalog.jsonb_array_length(v -> 'appointments') = 1, 'totais e atendimentos só dela');
  perform pg_temp.expect((select count(*) = 2 from public.list_anamnese_status('00000000-0000-0000-0000-00000000152a')), 'status com alcance');
  -- API direta: nada na tabela, nem nas próprias fichas (B1).
  perform pg_temp.expect(pg_temp.state_of(f) like '42501%', 'profissional, API direta recusada: ' || f)
  from pg_catalog.unnest(array[
    $q$select count(*) from public.anamneses$q$,
    $q$insert into public.anamneses (org_id, client_name, status, public_token, token_expires_at, signed_at, signature_name)
      values ('00000000-0000-0000-0000-00000000152a', 'Forjada', 'signed', 'tok-152-forjado-0123456789abcdef', now() + interval '1 year', now(), 'X')$q$,
    $q$update public.anamneses set professional_notes = 'invasão' where id = '00000000-0000-0000-0000-0000000015b2'$q$,
    $q$update public.anamneses set professional_data = '{"photos":["qualquer"]}' where id = '00000000-0000-0000-0000-0000000015b1'$q$,
    $q$update public.anamneses set public_token = 'tok-152-trocado-0123456789abcdef', token_expires_at = now() + interval '1 year'
      where id = '00000000-0000-0000-0000-0000000015b1'$q$,
    $q$delete from public.anamneses where id = '00000000-0000-0000-0000-0000000015b1'$q$]) f;
  -- API direta: Storage, nem na própria ficha (o servidor envia com a chave de serviço depois de anamnese_photo_change).
  perform pg_temp.expect((select count(*) from storage.objects where bucket_id = 'anamnese-photos') = 0, 'storage: não lê foto');
  v_ok := false;
  begin
    insert into storage.objects (bucket_id, name) values ('anamnese-photos',
      '00000000-0000-0000-0000-00000000152a/00000000-0000-0000-0000-0000000015b1/22222222-2222-4222-8222-222222222222.jpg');
  exception when insufficient_privilege then v_ok := true; end;
  perform pg_temp.expect(v_ok, 'storage: não grava foto direto');
  -- Funções.
  perform pg_temp.expect(public.anamnese_ficha_screen('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015b2') is null,
    'não abre ficha de outra agenda');
  perform pg_temp.expect(pg_temp.audits($w$user_id = '00000000-0000-0000-0000-000000001521' and operation = 'CLINICAL_READ'$w$) = 0,
    'fora do alcance: sem leitura');
  perform pg_temp.expect(pg_temp.state_of(f) like 'P0002%', 'fora do alcance recusado: ' || f)
  from pg_catalog.unnest(array[
    $q$select public.anamnese_save_professional('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015b2', '{}', '{}', '', false)$q$,
    $q$select public.anamnese_delete_pending('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015b2')$q$,
    $q$select public.set_anamnese_link_validity('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015b2', 7)$q$,
    $q$select public.log_anamnese_send('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015b2', 'copy')$q$,
    $q$select public.anamnese_photo_change('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015b2',
      '00000000-0000-0000-0000-00000000152a/00000000-0000-0000-0000-0000000015b2/22222222-2222-4222-8222-222222222222.jpg', 'add')$q$,
    $q$select public.create_anamnese_atomic('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015f1', null, 'x',
      '00000000-0000-0000-0000-0000000015e2')$q$]) f;
  perform pg_temp.expect(pg_catalog.jsonb_array_length(public.anamnese_client_photos('00000000-0000-0000-0000-00000000152a',
    '00000000-0000-0000-0000-0000000015c2')) = 0, 'perfil: sem fotos fora do alcance');

  -- Caminho feliz na própria ficha (b1): validação do resultado final.
  perform pg_temp.expect(pg_temp.state_of(f) like '22023%', 'recusado: ' || f)
  from pg_catalog.unnest(array[
    $q$select public.anamnese_save_professional('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015b1',
      '{"photos":["x"]}', '{}', '', false)$q$,
    $q$select public.anamnese_save_professional('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015b1', '{}',
      '{"photos":["00000000-0000-0000-0000-00000000152a/00000000-0000-0000-0000-0000000015b2/11111111-1111-4111-8111-111111111111.jpg",
              "00000000-0000-0000-0000-00000000152a/00000000-0000-0000-0000-0000000015b1/99999999-9999-4999-8999-999999999999.jpg"]}', '', false)$q$,
    $q$select public.anamnese_save_professional('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015b1', '{}',
      '{"qualquer":"coisa"}', '', false)$q$,
    $q$select public.anamnese_save_professional('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015b1', '{}',
      jsonb_build_object('procedure', repeat('x', 300000)), '', false)$q$]) f;
  perform public.anamnese_photo_change('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015b1',
    '00000000-0000-0000-0000-00000000152a/00000000-0000-0000-0000-0000000015b1/22222222-2222-4222-8222-222222222222.png', 'add');
  perform pg_temp.expect(pg_temp.audits($w$record_id = '00000000-0000-0000-0000-0000000015b1' and operation = 'PROFESSIONAL_PHOTO_ADDED'$w$) = 0,
    'autorizar o envio não registra foto (só quando ela entra na ficha)');
  perform public.anamnese_save_professional('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015b1',
    '{"skin_type":"Mista"}',
    '{"photos":["00000000-0000-0000-0000-00000000152a/00000000-0000-0000-0000-0000000015b1/22222222-2222-4222-8222-222222222222.png"],"procedure":"Lábios"}',
    'nota secreta', false);
  perform public.anamnese_save_professional('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015b1',
    '{"skin_type":"Seca"}', '{}', 'nota secreta', true);
  perform pg_temp.expect(pg_temp.audits($w$record_id = '00000000-0000-0000-0000-0000000015b1' and user_id = '00000000-0000-0000-0000-000000001521'
    and operation in ('PROFESSIONAL_PHOTO_ADDED', 'PROFESSIONAL_DRAFT_SAVED', 'PROFESSIONAL_NOTES_UPDATED', 'PROFESSIONAL_COMPLETED')$w$) = 4,
    'foto, rascunho, nota e conclusão auditados uma vez cada');
  perform pg_temp.expect(pg_temp.audits($w$record_id = '00000000-0000-0000-0000-0000000015b1'
    and (coalesce(new_data::text, '') like '%nota secreta%' or coalesce(old_data::text, '') like '%nota secreta%')$w$) = 0, 'auditoria sem o texto da nota');
  perform pg_temp.expect(pg_temp.state_of($q$select public.anamnese_save_professional('00000000-0000-0000-0000-00000000152a',
    '00000000-0000-0000-0000-0000000015b1', '{}', '{}', '', false)$q$) like '23514%', 'concluída não edita sem reabrir');
  perform pg_temp.expect(pg_temp.state_of($q$select public.anamnese_photo_change('00000000-0000-0000-0000-00000000152a',
    '00000000-0000-0000-0000-0000000015b1', '00000000-0000-0000-0000-00000000152a/00000000-0000-0000-0000-0000000015b1/33333333-3333-4333-8333-333333333333.png',
    'add')$q$) like '23514%', 'concluída não recebe foto');
end $$;
select pg_temp.logout();
select pg_temp.expect((select professional_completed_at is not null and professional_data ->> 'skin_type' = 'Seca'
  and professional_data ->> 'procedure' = 'Lábios' and pg_catalog.jsonb_array_length(professional_data -> 'photos') = 1
  and professional_notes = 'nota secreta' from public.anamneses where id = '00000000-0000-0000-0000-0000000015b1'),
  'concluída, extras e fotos mantidos, nota gravada');

-- ─── Dona: reabrir, modelos e revogar ───────────────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001520');
do $$
declare v_id uuid; v_copy uuid; v jsonb;
begin
  perform public.reopen_anamnese_professional_atomic('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015b1');
  perform pg_temp.expect(pg_temp.audits($w$record_id = '00000000-0000-0000-0000-0000000015b1' and operation = 'PROFESSIONAL_REOPENED'$w$) = 1,
    'reabertura auditada uma vez');

  v_id := public.anamnese_save_template('00000000-0000-0000-0000-00000000152a', null,
    '{"title":"Laser","questions":[{"id":"a","type":"text","text":"Pele?"}],"country":"PT","professional_form":{"type":"geral"}}', false);
  perform pg_temp.expect((select not is_active and country = 'PT' and consent_version = 'lgpd-v1' from public.anamnese_templates where id = v_id),
    'modelo novo em rascunho, versão do termo padrão da tabela');
  perform public.anamnese_save_template('00000000-0000-0000-0000-00000000152a', v_id,
    '{"title":"Laser 2","questions":[{"id":"a","type":"text","text":"Pele?"}]}', true);
  perform pg_temp.expect((select is_active and title = 'Laser 2' and version = 2 from public.anamnese_templates where id = v_id), 'publicado com versão nova');
  perform public.anamnese_save_template('00000000-0000-0000-0000-00000000152a', v_id,
    '{"title":"Laser 2","description":"Nova","questions":[{"id":"a","type":"text","text":"Pele?"}]}', false);
  perform pg_temp.expect(pg_temp.state_of($q$select public.anamnese_save_template('00000000-0000-0000-0000-00000000152a', null,
    jsonb_build_object('title', repeat('x', 121), 'questions', '[{"id":"a","type":"text","text":"x"}]'::jsonb), false)$q$) like '22023%',
    'título grande demais recusado');
  v_copy := public.anamnese_template_action('00000000-0000-0000-0000-00000000152a', v_id, 'duplicate');
  perform pg_temp.expect((select title = 'Laser 2 (cópia)' and not is_active from public.anamnese_templates where id = v_copy), 'cópia em rascunho');
  perform public.anamnese_template_action('00000000-0000-0000-0000-00000000152a', v_copy, 'delete');
  perform pg_temp.expect((select not active from public.anamnese_templates where id = v_copy), 'excluído sai das novas fichas');
  perform pg_temp.expect(pg_temp.audits($w$record_id = '$w$ || v_id || $w$' and table_name = 'anamnese_templates'
    and user_id = '00000000-0000-0000-0000-000000001520'$w$) = 4, 'modelo: criado, salvo, publicado, descrição salva');
  perform pg_temp.expect(pg_temp.audits($w$record_id = '$w$ || v_copy || $w$' and operation in ('ANAMNESE_TEMPLATE_CREATED', 'ANAMNESE_TEMPLATE_DELETED')$w$) = 2,
    'cópia: criada e excluída');
  perform pg_temp.expect(public.anamnese_import_templates('00000000-0000-0000-0000-00000000152a',
    '[{"title":"Laser 2","questions":[{"id":"b","type":"text","text":"Nova"}],"professional_form":{"type":"laser_removal"}},
      {"title":"Novo","questions":[{"id":"c","type":"text","text":"x"}],"professional_form":{"type":"micropigmentation"}}]') = 2, 'importa 2');
  perform pg_temp.expect((select count(*) = 1 from public.anamnese_templates where org_id = '00000000-0000-0000-0000-00000000152a'
    and title = 'Laser 2' and active), 'importar atualiza pelo título');
  v := public.anamnese_template_usage('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015f1');
  perform pg_temp.expect(pg_catalog.jsonb_array_length(v) = 3 and not ((v -> 0) ? 'client_name'), 'uso do modelo sem nomes');
  v := public.anamnese_template_screen('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015f1');
  perform pg_temp.expect(pg_catalog.jsonb_array_length(v -> 'services') = 1, 'editor: serviço vinculado');
  perform pg_temp.expect(public.anamnese_template_screen('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015f9') is null,
    'editor: modelo do B é nulo');

  v := public.anamnese_delete_pending('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015b3');
  perform pg_temp.expect(v = '["00000000-0000-0000-0000-00000000152a/00000000-0000-0000-0000-0000000015b3/"]'::jsonb,
    'revogar: volta só a pasta da própria ficha (o caminho de outra ficha gravado na linha não sai)');
  perform pg_temp.expect(not exists (select 1 from public.list_anamnese_status('00000000-0000-0000-0000-00000000152a',
    p_ids => array['00000000-0000-0000-0000-0000000015b3'::uuid])), 'pendente revogada');
  perform pg_temp.expect(pg_temp.audits($w$record_id = '00000000-0000-0000-0000-0000000015b3' and operation = 'ANAMNESE_PENDING_DELETED'$w$) = 1,
    'revogação auditada');
  perform pg_temp.expect(pg_temp.state_of($q$select public.anamnese_delete_pending('00000000-0000-0000-0000-00000000152a',
    '00000000-0000-0000-0000-0000000015b2')$q$) like 'P0001%', 'assinada não é apagada');
end $$;

-- ─── 20261114040700: envio de foto registrado e limitado, faxina das pastas, "existe ficha?" que bloqueia ──
select pg_temp.expect(pg_temp.audits($w$record_id = '00000000-0000-0000-0000-0000000015b1' and operation = 'PROFESSIONAL_PHOTO_UPLOAD_AUTHORIZED'
  and user_id = '00000000-0000-0000-0000-000000001521'
  and new_data ->> 'path' = '00000000-0000-0000-0000-00000000152a/00000000-0000-0000-0000-0000000015b1/22222222-2222-4222-8222-222222222222.png'$w$) = 1,
  'envio autorizado fica registrado, mesmo antes de salvar a ficha');
select pg_temp.logout();
-- b1 (reaberta pela dona) com 50 arquivos no prefixo, enviados e não salvos.
insert into storage.objects (bucket_id, name)
select 'anamnese-photos', '00000000-0000-0000-0000-00000000152a/00000000-0000-0000-0000-0000000015b1/' || gen_random_uuid() || '.jpg'
from generate_series(1, 50);
insert into t_ids values ('b4', gen_random_uuid());
insert into public.anamneses (id, org_id, client_id, client_name, template_title, status, public_token, token_expires_at,
  requires_professional, template_snapshot)
values ((select id from t_ids where k = 'b4'), '00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015c1', 'Cliente Um',
  'Sem parte profissional', 'pending', 'tok-152-sem-profissional-01234567', now() + interval '5 days', false, '{"questions":[]}');
select pg_temp.login('00000000-0000-0000-0000-000000001520');
select pg_temp.expect(pg_temp.state_of($q$select public.anamnese_photo_change('00000000-0000-0000-0000-00000000152a',
  '00000000-0000-0000-0000-0000000015b1', '00000000-0000-0000-0000-00000000152a/00000000-0000-0000-0000-0000000015b1/44444444-4444-4444-8444-444444444444.jpg',
  'add')$q$) like '22023%50 fotos%', 'com 50 arquivos no prefixo, o envio é recusado');
select pg_temp.expect(pg_temp.state_of(format($q$select public.anamnese_photo_change('00000000-0000-0000-0000-00000000152a', %L,
  '00000000-0000-0000-0000-00000000152a/' || %L || '/44444444-4444-4444-8444-444444444444.jpg', 'add')$q$,
  (select id from t_ids where k = 'b4'), (select id from t_ids where k = 'b4'))) like '23514%parte profissional%',
  'ficha sem parte profissional não recebe foto');
select pg_temp.expect(exists (select 1 from pg_catalog.jsonb_array_elements(
    public.anamnese_ficha_screen('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015b1') -> 'accesses') x
  where x ->> 'operation' = 'PROFESSIONAL_PHOTO_UPLOAD_AUTHORIZED'), 'últimos acessos mostram o envio autorizado');
select pg_temp.expect(public.anamnese_exists_for('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015e1', null),
  'dona: existe ficha no atendimento');

-- Faxina ao revogar: a pasta da ficha e as pastas órfãs do estúdio (ficha que não existe mais); nada de outro estúdio
-- nem de ficha que existe.
select pg_temp.logout();
insert into storage.objects (bucket_id, name) values
  ('anamnese-photos', '00000000-0000-0000-0000-00000000152a/' || (select id from t_ids where k = 'b4') || '/55555555-5555-4555-8555-555555555555.jpg'),
  ('anamnese-photos', '00000000-0000-0000-0000-00000000152a/00000000-0000-0000-0000-0000000015ee/66666666-6666-4666-8666-666666666666.jpg'),
  ('anamnese-photos', '00000000-0000-0000-0000-00000000152b/00000000-0000-0000-0000-0000000015ef/77777777-7777-4777-8777-777777777777.jpg');
select pg_temp.login('00000000-0000-0000-0000-000000001520');
select pg_temp.expect(public.anamnese_delete_pending('00000000-0000-0000-0000-00000000152a', (select id from t_ids where k = 'b4'))
  = pg_catalog.jsonb_build_array('00000000-0000-0000-0000-00000000152a/' || (select id from t_ids where k = 'b4') || '/',
                                 '00000000-0000-0000-0000-00000000152a/00000000-0000-0000-0000-0000000015ee/'),
  'revogar devolve a pasta da ficha e as órfãs do estúdio');

-- "Existe ficha?" exige a permissão de quem grava; sem ela responde SIM (bloqueia), nunca não.
select pg_temp.login('00000000-0000-0000-0000-000000001523');
select pg_temp.expect(public.anamnese_exists_for('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015e2', '00000000-0000-0000-0000-0000000015d1'),
  'sem agenda.manage / catalogo.manage: responde sim');
select pg_temp.login('00000000-0000-0000-0000-000000001524');
select pg_temp.expect(public.anamnese_exists_for('00000000-0000-0000-0000-00000000152a', '00000000-0000-0000-0000-0000000015e2', null),
  'outro estúdio: responde sim');
-- Recepção que grava sem ver: agenda.manage e catalogo.manage ligados, visões desligadas. Os chamadores continuam barrando.
select pg_temp.login('00000000-0000-0000-0000-000000001520');
select public.set_role_permission('00000000-0000-0000-0000-00000000152a', 'receptionist', k, v)
from (values ('agenda.view_all', false), ('agenda.view_own', false), ('catalogo.view', false), ('catalogo.manage', true)) x(k, v);
select pg_temp.logout();
insert into public.services (id, org_id, name, price, duration_minutes) values
  ('00000000-0000-0000-0000-0000000015d2', '00000000-0000-0000-0000-00000000152a', 'Serviço da ficha', 10, 30);
insert into public.anamneses (org_id, client_name, status, public_token, token_expires_at, source_service_id) values
  ('00000000-0000-0000-0000-00000000152a', 'Cliente Um', 'pending', 'tok-152-servico-origem-0123456789', now() + interval '5 days',
   '00000000-0000-0000-0000-0000000015d2');
select pg_temp.login('00000000-0000-0000-0000-000000001522');
select pg_temp.expect(pg_temp.state_of($q$select public.agenda_change_client('00000000-0000-0000-0000-00000000152a',
  '00000000-0000-0000-0000-0000000015e1', '00000000-0000-0000-0000-0000000015c2')$q$) like 'P0001: Este agendamento tem ficha%',
  'agenda.manage sem ver a agenda: troca de cliente com ficha continua recusada');
select pg_temp.expect(public.catalog_delete_item('00000000-0000-0000-0000-00000000152a', 'service', '00000000-0000-0000-0000-0000000015d2') = 'archived',
  'catalogo.manage sem catalogo.view: serviço de origem de ficha só arquiva');
select pg_temp.expect(not has_function_privilege('anon', 'public.anamnese_exists_for(uuid, uuid, uuid)', 'execute'),
  'anônimo não pergunta se existe ficha');

-- ─── Dona do B: nada do A ───────────────────────────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001524');
select pg_temp.expect(pg_temp.state_of($q$select public.anamnese_ficha_screen('00000000-0000-0000-0000-00000000152a',
  '00000000-0000-0000-0000-0000000015b2')$q$) like '42501%', 'B não abre ficha do A');
select pg_temp.expect(pg_temp.state_of($q$select public.anamnese_template_action('00000000-0000-0000-0000-00000000152a',
  '00000000-0000-0000-0000-0000000015f1', 'delete')$q$) like '42501%', 'B não exclui modelo do A');
select pg_temp.expect(pg_temp.state_of('select count(*) from public.anamneses') like '42501%', 'B não lê a tabela direto');
select pg_temp.expect(((public.anamnese_fichas_page('00000000-0000-0000-0000-00000000152b', null, 'todas', null, 'atendimento', 1, 10, null, false, null))
  ->> 'total')::int = 1, 'B vê só a sua ficha');

rollback;
\o
\echo 'anamnese: telas e ações em uma ida, alcance pela API (152): ok'
