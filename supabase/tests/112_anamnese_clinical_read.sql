-- Anamnese: leitura clínica só para quem tem acesso clínico; recepção vê status. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000ba1', 'dono@teste.local'),
  ('00000000-0000-0000-0000-000000000ba2', 'recep@teste.local'),
  ('00000000-0000-0000-0000-000000000ba3', 'prof@teste.local'),
  ('00000000-0000-0000-0000-000000000ba4', 'visu@teste.local'),
  ('00000000-0000-0000-0000-000000000ba5', 'fora@teste.local'),
  ('00000000-0000-0000-0000-000000000ba6', 'fin@teste.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-000000000baa', 'clin-a', 'Clínica A'),
  ('00000000-0000-0000-0000-000000000bab', 'clin-b', 'Clínica B');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000000ba1', '00000000-0000-0000-0000-000000000baa', 'owner'),
  ('00000000-0000-0000-0000-000000000ba2', '00000000-0000-0000-0000-000000000baa', 'receptionist'),
  ('00000000-0000-0000-0000-000000000ba3', '00000000-0000-0000-0000-000000000baa', 'professional'),
  ('00000000-0000-0000-0000-000000000ba4', '00000000-0000-0000-0000-000000000baa', 'viewer'),
  ('00000000-0000-0000-0000-000000000ba6', '00000000-0000-0000-0000-000000000baa', 'finance'),
  ('00000000-0000-0000-0000-000000000ba5', '00000000-0000-0000-0000-000000000bab', 'owner');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-000000000bc1', '00000000-0000-0000-0000-000000000baa', 'Lúcia Peña');
insert into public.staff_members (id, org_id, name) values
  ('00000000-0000-0000-0000-000000000bc2', '00000000-0000-0000-0000-000000000baa', 'Karenn');
insert into public.anamnese_templates (id, org_id, title, questions) values
  ('00000000-0000-0000-0000-000000000bc3', '00000000-0000-0000-0000-000000000baa', 'Ficha facial',
   '[{"id":"q1","type":"text","label":"Alergias?"}]'::jsonb);

insert into public.services (id, org_id, name, price, duration_minutes, requires_anamnese, anamnese_template_id) values
  ('00000000-0000-0000-0000-000000000bc4', '00000000-0000-0000-0000-000000000baa', 'Peeling', 20, 30, true,
   '00000000-0000-0000-0000-000000000bc3');

-- Uma ficha assinada com dado clínico (escrita como dono do banco).
insert into public.anamneses (id, org_id, client_id, client_name, template_id, template_title, status, answers,
  professional_notes, professional_data, public_token, signature_name, signature_data_url, signed_at,
  signer_ip, signer_user_agent, consent_accepted)
values ('00000000-0000-0000-0000-000000000bd1', '00000000-0000-0000-0000-000000000baa',
  '00000000-0000-0000-0000-000000000bc1', 'Lúcia Peña', '00000000-0000-0000-0000-000000000bc3', 'Ficha facial',
  'signed', '{"q1":"Alergia a látex"}'::jsonb, 'nota clínica', '{"photos":["x.jpg"]}'::jsonb,
  'tok-clin-0123456789abcdef0123456789', 'Lúcia Peña', 'data:image/png;base64,AAAA', now(),
  '203.0.113.9', 'Mozilla/5.0', true);

create function pg_temp.expect(p_ok boolean, p_msg text) returns void language plpgsql as $$
begin
  if not coalesce(p_ok, false) then raise exception 'FALHOU: %', p_msg; end if;
end $$;
grant execute on function pg_temp.expect(boolean, text) to authenticated;
-- A tabela anamneses e as fotos são fechadas para a API (20261114040000): ler direto dá permissão negada.
create function pg_temp.denied(p_sql text) returns boolean language plpgsql as $$
begin
  execute p_sql;
  return false;
exception when insufficient_privilege then return true;
end $$;
grant execute on function pg_temp.denied(text) to authenticated;

create temp table t_ids (k text primary key, id uuid) on commit drop;
grant all on t_ids to authenticated;

-- Dona: lê tudo, inclusive o dado clínico.
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000ba1', 'role', 'authenticated')::text, true);
select set_config('role', 'authenticated', true);
do $$
begin
  perform pg_temp.expect(pg_temp.denied('select 1 from public.anamneses'), 'nem a dona lê a tabela direto');
  perform pg_temp.expect(public.anamnese_ficha_screen('00000000-0000-0000-0000-000000000baa', '00000000-0000-0000-0000-000000000bd1')
    -> 'ficha' -> 'answers' ->> 'q1' = 'Alergia a látex', 'dona lê as respostas pela função');
end $$;

-- Profissional (só a própria agenda): a ficha não é de atendimento dela nem gerada por ela, então não lê
-- (alcance de 20261114040000; antes lia qualquer ficha do estúdio pela API).
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000ba3', 'role', 'authenticated')::text, true);
do $$
begin
  perform pg_temp.expect(pg_temp.denied('select 1 from public.anamneses'), 'profissional não lê a tabela');
  perform pg_temp.expect(public.anamnese_ficha_screen('00000000-0000-0000-0000-000000000baa', '00000000-0000-0000-0000-000000000bd1') is null,
    'profissional não lê ficha fora do alcance');
end $$;

-- Recepção: a tabela fica fechada; o status vem pela função, sem campos clínicos.
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000ba2', 'role', 'authenticated')::text, true);
do $$
declare r record; v_ok boolean;
begin
  perform pg_temp.expect(pg_temp.denied('select 1 from public.anamneses'), 'recepção não lê a tabela da ficha');

  select * into r from public.list_anamnese_status('00000000-0000-0000-0000-000000000baa');
  perform pg_temp.expect(r.id = '00000000-0000-0000-0000-000000000bd1', 'recepção vê a ficha pelo status');
  perform pg_temp.expect(r.status = 'signed' and r.template_title = 'Ficha facial', 'status e título chegam');
  -- 20261114040000: o link só sai para ficha pendente e no prazo; esta está assinada.
  perform pg_temp.expect(not (pg_catalog.to_jsonb(r) ? 'public_token'), 'a lista não devolve o link (20261114100100: só o hash no banco)');
  perform pg_temp.expect(
    (to_jsonb(r) ?| array['answers', 'professional_notes', 'professional_data', 'signature_name',
                          'signature_data_url', 'signer_ip', 'signer_user_agent']) = false,
    'status não traz campo clínico');

  perform pg_temp.expect(
    (select count(*) from public.list_anamnese_status('00000000-0000-0000-0000-000000000baa', p_client_id => '00000000-0000-0000-0000-000000000bc1')) = 1,
    'filtro por cliente');
  perform pg_temp.expect(
    (select count(*) from public.list_anamnese_status('00000000-0000-0000-0000-000000000baa', p_status => 'pending')) = 0,
    'filtro por situação');

  -- Gerar ficha para o agendamento: a recepção cria; o retorno sai sem campos clínicos.
  insert into t_ids values ('agenda', public.create_appointment_atomic(
    '00000000-0000-0000-0000-000000000baa', '00000000-0000-0000-0000-000000000bc1', '00000000-0000-0000-0000-000000000bc2',
    '2030-03-04 10:00+00', '2030-03-04 11:00+00', 60, 'Agendado', 'MANUAL', null, null, 0,
    '[]'::jsonb, false));
  r := null;
  perform pg_temp.expect(
    (public.create_anamnese_atomic('00000000-0000-0000-0000-000000000baa', '00000000-0000-0000-0000-000000000bc3',
      null, 'x', (select id from t_ids where k = 'agenda'))).status = 'pending',
    'recepção gera a ficha do agendamento');
  perform pg_temp.expect(
    (select count(*) from public.list_anamnese_status('00000000-0000-0000-0000-000000000baa',
      p_appointment_ids => array[(select id from t_ids where k = 'agenda')])) = 1,
    'ficha gerada aparece no status do agendamento');

  -- Gate: a recepção enxerga a ficha pendente (sem ler a tabela).
  insert into public.appointment_items (org_id, appointment_id, type, ref_id, name, price, qty)
  values ('00000000-0000-0000-0000-000000000baa', (select id from t_ids where k = 'agenda'), 'service',
          '00000000-0000-0000-0000-000000000bc4', 'Peeling', 20, 1);
  perform pg_temp.expect(
    (select issue_code from public.get_appointment_anamnese_gate('00000000-0000-0000-0000-000000000baa',
      (select id from t_ids where k = 'agenda'), 'start') limit 1) = 'CLIENT_PENDING',
    'gate vê a ficha pendente para a recepção');

  -- Quem não é da clínica não lista.
  v_ok := false;
  begin
    perform public.list_anamnese_status('00000000-0000-0000-0000-000000000bab');
  exception when insufficient_privilege then v_ok := true; end;
  perform pg_temp.expect(v_ok, 'recepção não lista a ficha de outro estúdio');
end $$;

-- Auto-vínculo: ao incluir serviço que exige ficha, a ficha nasce mesmo para a recepção.
do $$
declare v_linked uuid;
begin
  insert into t_ids values ('agenda2', public.create_appointment_atomic(
    '00000000-0000-0000-0000-000000000baa', '00000000-0000-0000-0000-000000000bc1', '00000000-0000-0000-0000-000000000bc2',
    '2030-03-05 10:00+00', '2030-03-05 11:00+00', 60, 'Agendado', 'MANUAL', null, null, 0,
    '[]'::jsonb, false));
  insert into public.appointment_items (org_id, appointment_id, type, ref_id, name, price, qty)
  values ('00000000-0000-0000-0000-000000000baa', (select id from t_ids where k = 'agenda2'), 'service',
          '00000000-0000-0000-0000-000000000bc4', 'Peeling', 20, 1);
  select linked_anamnese_id into v_linked from public.appointments where id = (select id from t_ids where k = 'agenda2');
  perform pg_temp.expect(v_linked is not null, 'serviço com ficha obrigatória vincula a ficha para a recepção');
end $$;

-- Visualizadora e financeiro: nem tabela nem status.
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000ba4', 'role', 'authenticated')::text, true);
do $$
declare v_ok boolean;
begin
  perform pg_temp.expect(pg_temp.denied('select 1 from public.anamneses'), 'visualizadora não lê a tabela');
  v_ok := false;
  begin
    perform public.list_anamnese_status('00000000-0000-0000-0000-000000000baa');
  exception when insufficient_privilege then v_ok := true; end;
  perform pg_temp.expect(v_ok, 'visualizadora não lista status');
end $$;
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000ba6', 'role', 'authenticated')::text, true);
do $$
begin
  perform pg_temp.expect(pg_temp.denied('select 1 from public.anamneses'), 'financeiro não lê a tabela');
end $$;

-- Outro estúdio: a dona de B não vê nada de A, nem pelo status.
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000ba5', 'role', 'authenticated')::text, true);
do $$
declare v_ok boolean;
begin
  perform pg_temp.expect(pg_temp.denied('select 1 from public.anamneses'), 'estúdio B não lê fichas do A');
  v_ok := false;
  begin
    perform public.list_anamnese_status('00000000-0000-0000-0000-000000000baa');
  exception when insufficient_privilege then v_ok := true; end;
  perform pg_temp.expect(v_ok, 'estúdio B não lista status do A');
end $$;

-- Fotos da ficha: ninguém lê, grava ou apaga direto no Storage (nem a dona). O servidor faz isso com a chave de
-- serviço depois que uma função do banco autoriza o caminho.
reset role;
insert into storage.buckets (id, name) values ('anamnese-photos', 'anamnese-photos') on conflict do nothing;
insert into storage.objects (bucket_id, name)
values ('anamnese-photos', '00000000-0000-0000-0000-000000000baa/00000000-0000-0000-0000-000000000bd1/x.jpg');
select set_config('role', 'authenticated', true);
select pg_temp.expect(
  (select count(*) from storage.objects where bucket_id = 'anamnese-photos') = 0
  and pg_temp.denied($q$insert into storage.objects (bucket_id, name)
    values ('anamnese-photos', '00000000-0000-0000-0000-000000000baa/00000000-0000-0000-0000-000000000bd1/11111111-1111-4111-8111-111111111111.jpg')$q$),
  'foto: ' || u || ' não lê nem grava no Storage')
from (select set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true), u
      from unnest(array['00000000-0000-0000-0000-000000000ba1', '00000000-0000-0000-0000-000000000ba2',
                        '00000000-0000-0000-0000-000000000ba3']) u) x;

reset role;
rollback;
\o
\echo 'leitura clínica da anamnese por papel: ok'
