-- Perfis e liberações configuráveis (spec 37): padrão, exceção do estúdio, auditoria, limites. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000ca1', 'dono@teste.local'),
  ('00000000-0000-0000-0000-000000000ca2', 'recep@teste.local'),
  ('00000000-0000-0000-0000-000000000ca3', 'prof@teste.local'),
  ('00000000-0000-0000-0000-000000000ca4', 'admin@teste.local'),
  ('00000000-0000-0000-0000-000000000ca5', 'visu@teste.local'),
  ('00000000-0000-0000-0000-000000000ca6', 'fora@teste.local'),
  ('00000000-0000-0000-0000-000000000ca7', 'gest@teste.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-000000000caa', 'perm-a', 'Estúdio A'),
  ('00000000-0000-0000-0000-000000000cab', 'perm-b', 'Estúdio B');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000000ca1', '00000000-0000-0000-0000-000000000caa', 'owner'),
  ('00000000-0000-0000-0000-000000000ca2', '00000000-0000-0000-0000-000000000caa', 'receptionist'),
  ('00000000-0000-0000-0000-000000000ca3', '00000000-0000-0000-0000-000000000caa', 'professional'),
  ('00000000-0000-0000-0000-000000000ca4', '00000000-0000-0000-0000-000000000caa', 'admin'),
  ('00000000-0000-0000-0000-000000000ca5', '00000000-0000-0000-0000-000000000caa', 'viewer'),
  ('00000000-0000-0000-0000-000000000ca7', '00000000-0000-0000-0000-000000000caa', 'manager'),
  ('00000000-0000-0000-0000-000000000ca6', '00000000-0000-0000-0000-000000000cab', 'owner');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-000000000cc1', '00000000-0000-0000-0000-000000000caa', 'Lúcia Peña');
insert into public.staff_members (id, org_id, name) values
  ('00000000-0000-0000-0000-000000000cc2', '00000000-0000-0000-0000-000000000caa', 'Karenn');
insert into public.anamnese_templates (id, org_id, title, questions) values
  ('00000000-0000-0000-0000-000000000cc3', '00000000-0000-0000-0000-000000000caa', 'Ficha facial',
   '[{"id":"q1","type":"text","label":"Alergias?"}]'::jsonb);
-- Gerada pela profissional (created_by vem do banco, 20261114040000): está no alcance dela; com parte profissional.
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000ca3', 'role', 'authenticated')::text, true);
insert into public.anamneses (id, org_id, client_id, client_name, template_id, template_title, status, answers,
  public_token, consent_accepted, requires_professional)
values ('00000000-0000-0000-0000-000000000cd1', '00000000-0000-0000-0000-000000000caa',
  '00000000-0000-0000-0000-000000000cc1', 'Lúcia Peña', '00000000-0000-0000-0000-000000000cc3', 'Ficha facial',
  'signed', '{"q1":"Alergia a látex"}'::jsonb, 'tok-perm-0123456789abcdef0123456789', true, true);
select set_config('request.jwt.claims', '', true);

create function pg_temp.expect(p_ok boolean, p_msg text) returns void language plpgsql as $$
begin
  if not coalesce(p_ok, false) then raise exception 'FALHOU: %', p_msg; end if;
end $$;
grant execute on function pg_temp.expect(boolean, text) to authenticated;

-- Roda um comando e devolve o SQLSTATE do erro (ou 'ok').
create function pg_temp.state_of(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return sqlstate;
end $$;
grant execute on function pg_temp.state_of(text) to authenticated;

-- Resposta q1 da ficha pela função de leitura (a tabela é fechada para a API, 20261114040000); nulo sem leitura clínica.
create function pg_temp.q1() returns text language plpgsql as $$
begin
  return public.anamnese_ficha_screen('00000000-0000-0000-0000-000000000caa', '00000000-0000-0000-0000-000000000cd1') -> 'ficha' -> 'answers' ->> 'q1';
exception when insufficient_privilege then return null;
end $$;
grant execute on function pg_temp.q1() to authenticated;

create temp table t_ids (k text primary key, id uuid) on commit drop;
grant all on t_ids to authenticated;

select set_config('role', 'authenticated', true);

-- Dona: tudo liberado; matriz e lista efetiva completas.
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000ca1', 'role', 'authenticated')::text, true);
do $$
begin
  perform pg_temp.expect(public.has_permission('00000000-0000-0000-0000-000000000caa', 'comanda.refund'), 'dona tem tudo');
  perform pg_temp.expect(cardinality(public.my_permissions('00000000-0000-0000-0000-000000000caa')) = 25, 'dona: 25 permissões');
  perform pg_temp.expect(not public.has_permission('00000000-0000-0000-0000-000000000caa', 'inexistente.x'), 'permissão desconhecida não vale');
  perform pg_temp.expect(
    (select count(*) from public.get_permission_matrix('00000000-0000-0000-0000-000000000caa')) = 7 * 25, 'matriz 7 papéis x 25');
  perform pg_temp.expect(
    (select allowed from public.get_permission_matrix('00000000-0000-0000-0000-000000000caa')
      where role = 'receptionist' and permission = 'comanda.operate'), 'matriz: recepção opera comanda');
  perform pg_temp.expect(
    not (select allowed from public.get_permission_matrix('00000000-0000-0000-0000-000000000caa')
      where role = 'receptionist' and permission = 'clientes.view_clinical'), 'matriz: recepção sem leitura clínica');
end $$;

-- Padrão: recepção sem dado clínico, com caixa; gestão estorna; profissional sem caixa.
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000ca2', 'role', 'authenticated')::text, true);
do $$
begin
  perform pg_temp.expect(not public.has_permission('00000000-0000-0000-0000-000000000caa', 'clientes.view_clinical'), 'recepção: sem leitura clínica');
  perform pg_temp.expect(public.has_permission('00000000-0000-0000-0000-000000000caa', 'comanda.operate'), 'recepção: opera a comanda');
  perform pg_temp.expect(pg_temp.q1() is null, 'recepção não lê a ficha');
  perform pg_temp.expect(pg_temp.state_of($q$select public.set_role_permission('00000000-0000-0000-0000-000000000caa', 'receptionist', 'clientes.view_clinical', true)$q$) = '42501', 'recepção não altera liberações');
  perform pg_temp.expect(pg_temp.state_of($q$select * from public.get_permission_matrix('00000000-0000-0000-0000-000000000caa')$q$) = '42501', 'recepção não vê a matriz');
  perform pg_temp.expect((select count(*) from public.org_role_permissions) = 0, 'recepção não lê exceções');
end $$;
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000ca7', 'role', 'authenticated')::text, true);
do $$
begin
  perform pg_temp.expect(public.has_permission('00000000-0000-0000-0000-000000000caa', 'comanda.refund'), 'gestão estorna (comportamento mantido)');
  perform pg_temp.expect(not public.has_permission('00000000-0000-0000-0000-000000000caa', 'acesso.manage'), 'gestão não gerencia acessos');
end $$;
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000ca3', 'role', 'authenticated')::text, true);
do $$
begin
  perform pg_temp.expect(not public.has_permission('00000000-0000-0000-0000-000000000caa', 'comanda.operate'), 'profissional: sem caixa');
  perform pg_temp.expect(public.has_permission('00000000-0000-0000-0000-000000000caa', 'clientes.view_clinical'), 'profissional: lê o clínico');
  perform pg_temp.expect(pg_temp.q1() = 'Alergia a látex', 'profissional lê a ficha');
end $$;

-- Dona liga a leitura clínica para a recepção: muda, audita, e repetir não muda de novo.
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000ca1', 'role', 'authenticated')::text, true);
do $$
begin
  perform pg_temp.expect(public.set_role_permission('00000000-0000-0000-0000-000000000caa', 'receptionist', 'clientes.view_clinical', true), 'ligar muda');
  perform pg_temp.expect(not public.set_role_permission('00000000-0000-0000-0000-000000000caa', 'receptionist', 'clientes.view_clinical', true), 'ligar de novo não muda');
  perform pg_temp.expect((select count(*) from public.org_role_permissions) = 1, 'uma exceção gravada');
  perform pg_temp.expect(
    (select count(*) from public.audit_logs where operation = 'ROLE_PERMISSION_SET'
       and org_id = '00000000-0000-0000-0000-000000000caa') = 1, 'mudança auditada uma vez');
  perform pg_temp.expect(
    (select new_data ->> 'permission' from public.audit_logs where operation = 'ROLE_PERMISSION_SET'
       and org_id = '00000000-0000-0000-0000-000000000caa') = 'clientes.view_clinical', 'auditoria traz a permissão');
end $$;
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000ca2', 'role', 'authenticated')::text, true);
do $$
begin
  perform pg_temp.expect(public.has_permission('00000000-0000-0000-0000-000000000caa', 'clientes.view_clinical'), 'recepção agora lê o clínico');
  perform pg_temp.expect(pg_temp.q1() = 'Alergia a látex', 'recepção lê as respostas com a liberação');
  -- Ainda sem preencher (anamnese.fill_professional continua desligado).
  perform pg_temp.expect(pg_temp.state_of($q$select public.anamnese_save_professional('00000000-0000-0000-0000-000000000caa', '00000000-0000-0000-0000-000000000cd1', '{}'::jsonb, '{}'::jsonb, 'nota', false)$q$) = '42501', 'recepção ainda não preenche');
end $$;

-- Desligar de volta apaga a exceção (vale o padrão) e fecha o acesso.
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000ca1', 'role', 'authenticated')::text, true);
do $$
begin
  perform pg_temp.expect(public.set_role_permission('00000000-0000-0000-0000-000000000caa', 'receptionist', 'clientes.view_clinical', false), 'desligar muda');
  perform pg_temp.expect((select count(*) from public.org_role_permissions) = 0, 'voltou ao padrão: sem exceção');
end $$;
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000ca2', 'role', 'authenticated')::text, true);
do $$
begin
  perform pg_temp.expect(pg_temp.q1() is null, 'recepção volta a não ler a ficha');
end $$;

-- Caixa: desligar comanda.operate bloqueia o sinal; religar libera.
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000ca1', 'role', 'authenticated')::text, true);
do $$
begin
  insert into t_ids values ('agenda', public.create_appointment_atomic(
    '00000000-0000-0000-0000-000000000caa', '00000000-0000-0000-0000-000000000cc1', '00000000-0000-0000-0000-000000000cc2',
    '2030-03-04 10:00+00', '2030-03-04 11:00+00', 60, 'Agendado', 'MANUAL', null, null, 0,
    '[]'::jsonb, false));
  perform public.set_role_permission('00000000-0000-0000-0000-000000000caa', 'receptionist', 'comanda.operate', false);
end $$;
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000ca2', 'role', 'authenticated')::text, true);
do $$
begin
  perform pg_temp.expect(
    pg_temp.state_of(format($q$select public.register_appointment_deposit_atomic('00000000-0000-0000-0000-000000000caa', %L, 10, 'CASH', gen_random_uuid())$q$,
      (select id from t_ids where k = 'agenda'))) = '42501', 'sem comanda.operate o sinal é recusado');
end $$;
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000ca1', 'role', 'authenticated')::text, true);
do $$
begin
  perform public.set_role_permission('00000000-0000-0000-0000-000000000caa', 'receptionist', 'comanda.operate', true);
end $$;
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000ca2', 'role', 'authenticated')::text, true);
do $$
begin
  perform pg_temp.expect(
    pg_temp.state_of(format($q$select public.register_appointment_deposit_atomic('00000000-0000-0000-0000-000000000caa', %L, 10, 'CASH', gen_random_uuid())$q$,
      (select id from t_ids where k = 'agenda'))) = 'ok', 'com comanda.operate o sinal passa');
end $$;

-- Administração: altera papéis operacionais, mas não o próprio papel nem acessos.
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000ca4', 'role', 'authenticated')::text, true);
do $$
begin
  perform pg_temp.expect(public.set_role_permission('00000000-0000-0000-0000-000000000caa', 'receptionist', 'anamnese.fill_professional', true), 'admin libera preenchimento à recepção');
  perform pg_temp.expect(pg_temp.state_of($q$select public.set_role_permission('00000000-0000-0000-0000-000000000caa', 'admin', 'financeiro.view', false)$q$) = '42501', 'admin não mexe no papel admin');
  perform pg_temp.expect(pg_temp.state_of($q$select public.set_role_permission('00000000-0000-0000-0000-000000000caa', 'manager', 'acesso.manage', true)$q$) = '42501', 'admin não concede acesso.manage');
  perform pg_temp.expect(pg_temp.state_of($q$select public.set_role_permission('00000000-0000-0000-0000-000000000caa', 'owner', 'agenda.manage', false)$q$) = '22023', 'ninguém edita a dona');
  perform pg_temp.expect(pg_temp.state_of($q$select public.set_role_permission('00000000-0000-0000-0000-000000000caa', 'viewer', 'nao.existe', true)$q$) = '22023', 'permissão desconhecida é recusada');
end $$;
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000ca2', 'role', 'authenticated')::text, true);
do $$
begin
  perform pg_temp.expect(pg_temp.q1() is null, 'preencher não abre a leitura');
  -- Sem leitura clínica não há o que preencher (a função confere as duas permissões).
  perform pg_temp.expect(
    pg_temp.state_of($q$select public.anamnese_save_professional('00000000-0000-0000-0000-000000000caa', '00000000-0000-0000-0000-000000000cd1', '{}'::jsonb, '{}'::jsonb, 'nota da recepção', false)$q$) <> 'ok', 'preencher sem ler não funciona');
end $$;
-- Com leitura + preenchimento, a recepção edita a anamnese.
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000ca4', 'role', 'authenticated')::text, true);
do $$
begin
  perform public.set_role_permission('00000000-0000-0000-0000-000000000caa', 'receptionist', 'clientes.view_clinical', true);
end $$;
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000ca2', 'role', 'authenticated')::text, true);
do $$
begin
  perform pg_temp.expect(
    pg_temp.state_of($q$select public.anamnese_save_professional('00000000-0000-0000-0000-000000000caa', '00000000-0000-0000-0000-000000000cd1', '{}'::jsonb, '{}'::jsonb, 'nota da recepção', false)$q$) = 'ok', 'recepção preenche com as duas liberações');
end $$;
reset role;
select pg_temp.expect(
  (select professional_notes from public.anamneses where id = '00000000-0000-0000-0000-000000000cd1') = 'nota da recepção', 'nota gravada');
select set_config('role', 'authenticated', true);

-- Outro estúdio não vê nem altera.
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000ca6', 'role', 'authenticated')::text, true);
do $$
begin
  perform pg_temp.expect(pg_temp.state_of($q$select public.set_role_permission('00000000-0000-0000-0000-000000000caa', 'viewer', 'agenda.manage', true)$q$) = '42501', 'outro estúdio não altera');
  perform pg_temp.expect((select count(*) from public.org_role_permissions) = 0, 'outro estúdio não lê exceções');
  perform pg_temp.expect(not public.has_permission('00000000-0000-0000-0000-000000000caa', 'agenda.view_all'), 'outro estúdio não tem permissão aqui');
  perform pg_temp.expect(cardinality(public.my_permissions('00000000-0000-0000-0000-000000000caa')) = 0, 'outro estúdio: lista vazia');
end $$;

-- Somente leitura não vê a matriz.
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000ca5', 'role', 'authenticated')::text, true);
do $$
begin
  perform pg_temp.expect(pg_temp.state_of($q$select * from public.get_permission_matrix('00000000-0000-0000-0000-000000000caa')$q$) = '42501', 'viewer não vê a matriz');
end $$;

-- Reset: a dona volta o papel ao padrão e a mudança é auditada.
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000ca1', 'role', 'authenticated')::text, true);
do $$
begin
  perform pg_temp.expect(public.reset_role_permissions('00000000-0000-0000-0000-000000000caa', 'receptionist') = 2, 'reset apaga as exceções que sobraram');
  perform pg_temp.expect(public.reset_role_permissions('00000000-0000-0000-0000-000000000caa', 'receptionist') = 0, 'reset sem exceção não faz nada');
  perform pg_temp.expect(
    (select count(*) from public.audit_logs where operation = 'ROLE_PERMISSIONS_RESET') = 1, 'reset auditado');
  perform pg_temp.expect(not public.has_permission('00000000-0000-0000-0000-000000000caa', 'x.y'), 'fim');
end $$;

reset role;
rollback;
\o
\echo 'liberações configuráveis por perfil: ok'
