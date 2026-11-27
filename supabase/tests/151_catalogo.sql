-- Catálogo (porte, orçamento de chamadas): catalog_screen, catalog_stock_entries e as ações catalog_* das
-- migrations 20261114030000 e 20261114030100. Isolamento entre estúdios, anônimo sem execução, permissão por
-- papel (recepção, profissional e financeiro leem mas não gravam; gerente e quem recebeu catalogo.manage gravam),
-- caminhos felizes de cada gravação, limites de texto e valor, tudo-ou-nada e auditoria. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000001510', 'dona@c151.local'),
  ('00000000-0000-0000-0000-000000001511', 'recep@c151.local'),
  ('00000000-0000-0000-0000-000000001512', 'donab@c151.local'),
  ('00000000-0000-0000-0000-000000001513', 'gerente@c151.local'),
  ('00000000-0000-0000-0000-000000001514', 'prof@c151.local'),
  ('00000000-0000-0000-0000-000000001515', 'fin@c151.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-00000000151a', 'c151-a', 'Catálogo 151 A'),
  ('00000000-0000-0000-0000-00000000151b', 'c151-b', 'Catálogo 151 B');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000001510', '00000000-0000-0000-0000-00000000151a', 'owner'),
  ('00000000-0000-0000-0000-000000001511', '00000000-0000-0000-0000-00000000151a', 'receptionist'),
  ('00000000-0000-0000-0000-000000001512', '00000000-0000-0000-0000-00000000151b', 'owner'),
  ('00000000-0000-0000-0000-000000001513', '00000000-0000-0000-0000-00000000151a', 'manager'),
  ('00000000-0000-0000-0000-000000001514', '00000000-0000-0000-0000-00000000151a', 'professional'),
  ('00000000-0000-0000-0000-000000001515', '00000000-0000-0000-0000-00000000151a', 'finance');
insert into public.profiles (user_id, org_id, full_name) values
  ('00000000-0000-0000-0000-000000001510', '00000000-0000-0000-0000-00000000151a', 'Dona Ana')
on conflict (user_id, org_id) do update set full_name = excluded.full_name;

-- Estúdio A: uma categoria, duas profissionais, um modelo de ficha, um serviço usado em atendimento e um pacote vendido.
insert into public.service_categories (id, org_id, name, color, position) values
  ('00000000-0000-0000-0000-0000000151c1', '00000000-0000-0000-0000-00000000151a', 'Sobrancelhas', '#112233', 1),
  ('00000000-0000-0000-0000-0000000151c9', '00000000-0000-0000-0000-00000000151b', 'Categoria B', '#445566', 1);
insert into public.staff_members (id, org_id, name, display_name, role, position, active) values
  ('00000000-0000-0000-0000-0000000151a1', '00000000-0000-0000-0000-00000000151a', 'Profissional Um', 'Pro Um', 'professional', 1, true),
  ('00000000-0000-0000-0000-0000000151a2', '00000000-0000-0000-0000-00000000151a', 'Profissional Dois', null, 'manager', 2, true),
  ('00000000-0000-0000-0000-0000000151a3', '00000000-0000-0000-0000-00000000151a', 'Inativa', null, 'professional', 3, false),
  ('00000000-0000-0000-0000-0000000151a9', '00000000-0000-0000-0000-00000000151b', 'Profissional B', null, 'professional', 1, true);
insert into public.anamnese_templates (id, org_id, title, questions) values
  ('00000000-0000-0000-0000-0000000151e1', '00000000-0000-0000-0000-00000000151a', 'Ficha de cílios', '[{"id":"q1"}]'),
  ('00000000-0000-0000-0000-0000000151e9', '00000000-0000-0000-0000-00000000151b', 'Ficha B', '[]');
insert into public.services (id, org_id, name, price, duration_minutes, position) values
  ('00000000-0000-0000-0000-0000000151f1', '00000000-0000-0000-0000-00000000151a', 'Serviço usado', 50, 60, 0),
  ('00000000-0000-0000-0000-0000000151f2', '00000000-0000-0000-0000-00000000151a', 'Serviço livre', 30, 30, 1),
  ('00000000-0000-0000-0000-0000000151f3', '00000000-0000-0000-0000-00000000151a', 'Serviço no combo', 20, 30, 2),
  ('00000000-0000-0000-0000-0000000151f9', '00000000-0000-0000-0000-00000000151b', 'Serviço B', 40, 60, 0);
insert into public.service_packages (id, org_id, name, price, sessions) values
  ('00000000-0000-0000-0000-0000000151b1', '00000000-0000-0000-0000-00000000151a', 'Pacote vendido', 200, 4);
insert into public.package_services (org_id, package_id, service_id, qty) values
  ('00000000-0000-0000-0000-00000000151a', '00000000-0000-0000-0000-0000000151b1', '00000000-0000-0000-0000-0000000151f2', 1);
insert into public.clients (id, org_id, full_name, phone) values
  ('00000000-0000-0000-0000-0000000151d1', '00000000-0000-0000-0000-00000000151a', 'Cliente Um', '+34600000001');
insert into public.client_entitlements (org_id, client_id, package_id, package_name, total_sessions, used_sessions, status) values
  ('00000000-0000-0000-0000-00000000151a', '00000000-0000-0000-0000-0000000151d1', '00000000-0000-0000-0000-0000000151b1', 'Pacote vendido', 4, 0, 'active'),
  ('00000000-0000-0000-0000-00000000151a', '00000000-0000-0000-0000-0000000151d1', '00000000-0000-0000-0000-0000000151b1', 'Pacote vendido', 4, 1, 'active');
insert into public.products (id, org_id, name, price, stock_qty) values
  ('00000000-0000-0000-0000-0000000151aa', '00000000-0000-0000-0000-00000000151a', 'Produto com histórico', 10, 5),
  ('00000000-0000-0000-0000-0000000151ab', '00000000-0000-0000-0000-00000000151a', 'Produto sem histórico', 12, 0),
  ('00000000-0000-0000-0000-0000000151ac', '00000000-0000-0000-0000-00000000151b', 'Produto B', 9, 3);
insert into public.stock_entries (org_id, product_id, type, quantity, reason) values
  ('00000000-0000-0000-0000-00000000151a', '00000000-0000-0000-0000-0000000151aa', 'entrada', 5, 'Inicial'),
  ('00000000-0000-0000-0000-00000000151b', '00000000-0000-0000-0000-0000000151ac', 'entrada', 3, 'Inicial B');
-- Atendimento com o serviço usado (pula os gatilhos só para montar o cenário; desfeito no rollback).
insert into public.appointments (id, org_id, client_id, client_name, start_at, end_at, duration_minutes, status) values
  ('00000000-0000-0000-0000-0000000151ee', '00000000-0000-0000-0000-00000000151a', '00000000-0000-0000-0000-0000000151d1',
   'Cliente Um', '2031-05-06 10:30+00', '2031-05-06 11:30+00', 60, 'Agendado');
set local session_replication_role = replica;
insert into public.appointment_items (org_id, appointment_id, type, ref_id, name, price, qty) values
  ('00000000-0000-0000-0000-00000000151a', '00000000-0000-0000-0000-0000000151ee', 'service', '00000000-0000-0000-0000-0000000151f1', 'Serviço usado', 50, 1);
set local session_replication_role = origin;
-- Estúdio B: um plano e um combo (não podem aparecer no A).
insert into public.subscription_plans (id, org_id, name, price) values
  ('00000000-0000-0000-0000-0000000151d9', '00000000-0000-0000-0000-00000000151b', 'Plano B', 99);
-- A profissional ganha catalogo.manage por liberação do estúdio (perfil configurável).
insert into public.org_role_permissions (org_id, role, permission, allowed) values
  ('00000000-0000-0000-0000-00000000151a', 'professional', 'catalogo.manage', true);

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
create function pg_temp.msg_of(p_sql text) returns table (message text) language plpgsql as $$
begin
  execute p_sql;
  message := 'ok'; return next;
exception when others then
  message := sqlerrm; return next;
end $$;
grant execute on function pg_temp.msg_of(text) to anon, authenticated;
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
  select count(*) from public.audit_logs where operation = p_op and org_id = '00000000-0000-0000-0000-00000000151a'
$$;
create function pg_temp.changed(p_table text, p_col text) returns bigint language sql as $$
  select count(*) from public.audit_logs where operation = 'CATALOG_UPDATED' and table_name = p_table
    and org_id = '00000000-0000-0000-0000-00000000151a' and new_data ? p_col
$$;
grant execute on function pg_temp.changed(text, text) to anon, authenticated;
grant execute on function pg_temp.expect(boolean, text), pg_temp.state_of(text), pg_temp.login(uuid), pg_temp.logout(),
  pg_temp.audits(text) to anon, authenticated;

-- ─── Leitura: dona do estúdio A ───────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001510');
create temp table s_a on commit drop as select public.catalog_screen('00000000-0000-0000-0000-00000000151a') as s;
select pg_temp.expect((select array_agg(k order by k) from s_a, jsonb_object_keys(s) k)
  = array['bundles', 'categories', 'packages', 'plans', 'products', 'services', 'staff', 'templates', 'truncated'], 'as listas da tela e o aviso de corte');
select pg_temp.expect((select s -> 'truncated' from s_a) = '[]'::jsonb, 'nenhuma lista cortada');
select pg_temp.expect((select jsonb_array_length(s -> 'services') from s_a) = 3, 'só os serviços do A');
select pg_temp.expect((select jsonb_array_length(s -> 'products') from s_a) = 2, 'só os produtos do A');
select pg_temp.expect((select jsonb_array_length(s -> 'plans') from s_a) = 0, 'plano do B não aparece no A');
select pg_temp.expect((select jsonb_array_length(s -> 'categories') from s_a) = 1, 'categorias do A');
select pg_temp.expect((select jsonb_array_length(s -> 'staff') from s_a) = 2, 'equipe ativa do A (a inativa fica fora)');
select pg_temp.expect((select s -> 'staff' -> 0 ->> 'display_name' from s_a) = 'Pro Um', 'equipe com nome de exibição e papel');
select pg_temp.expect((select s -> 'templates' from s_a) = '[{"id": "00000000-0000-0000-0000-0000000151e1", "title": "Ficha de cílios"}]'::jsonb,
  'modelos de ficha: só id e título (sem as perguntas)');
select pg_temp.expect((select (s -> 'packages' -> 0 ->> 'sales')::int from s_a) = 2, 'vendas do pacote contadas no banco');
select pg_temp.expect((select s -> 'packages' -> 0 -> 'service_ids' from s_a) = '["00000000-0000-0000-0000-0000000151f2"]'::jsonb, 'serviços do pacote');
select pg_temp.expect((select (s -> 'services' -> 0 ->> 'price')::numeric from s_a) = 50, 'preço do serviço como número');
select pg_temp.expect((select s -> 'services' -> 0 -> 'staff_ids' from s_a) = '[]'::jsonb, 'serviço sem profissionais: lista vazia (toda a equipe)');
select pg_temp.expect((select not exists (select 1 from jsonb_array_elements(s -> 'services') e where e ? 'cost_amount' or e ? 'org_id' or e ? 'created_at') from s_a),
  'serviço só com as colunas da tela (sem org_id, custo interno nem datas)');
select pg_temp.expect(jsonb_array_length(public.catalog_stock_entries('00000000-0000-0000-0000-00000000151a', '00000000-0000-0000-0000-0000000151aa')) = 1,
  'histórico de estoque do produto');
select pg_temp.expect(jsonb_array_length(public.catalog_stock_entries('00000000-0000-0000-0000-00000000151a', '00000000-0000-0000-0000-0000000151ac')) = 0,
  'produto do B pelo estúdio do A: histórico vazio');
select pg_temp.expect(jsonb_array_length(public.catalog_stock_entries('00000000-0000-0000-0000-00000000151b', '00000000-0000-0000-0000-0000000151ac')) = 0,
  'estúdio do B pela dona do A: histórico vazio');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_screen('00000000-0000-0000-0000-00000000151b')$q$) = '42501', 'dona do A não lê o catálogo do B');

-- Quem só lê (recepção, profissional, financeiro) abre a tela.
select pg_temp.login('00000000-0000-0000-0000-000000001511');
select pg_temp.expect(jsonb_array_length(public.catalog_screen('00000000-0000-0000-0000-00000000151a') -> 'services') = 3, 'recepção lê o catálogo');
select pg_temp.login('00000000-0000-0000-0000-000000001515');
select pg_temp.expect(jsonb_array_length(public.catalog_screen('00000000-0000-0000-0000-00000000151a') -> 'services') = 3, 'financeiro lê o catálogo');
-- Dona do B.
select pg_temp.login('00000000-0000-0000-0000-000000001512');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_screen('00000000-0000-0000-0000-00000000151a')$q$) = '42501', 'dona do B não lê o catálogo do A');
select pg_temp.expect(jsonb_array_length(public.catalog_screen('00000000-0000-0000-0000-00000000151b') -> 'plans') = 1, 'dona do B vê o plano do B');

-- ─── Permissão por papel: recepção, financeiro e profissional (sem a liberação) não gravam ──────────
create function pg_temp.writes(p_org uuid) returns table (fn text, state text) language plpgsql as $f$
declare
  v_org text := quote_literal(p_org);
begin
  fn := 'save_category'; state := pg_temp.state_of(format($q$select public.catalog_save_category(%s, null, 'X', '#112233', null)$q$, v_org)); return next;
  fn := 'save_service'; state := pg_temp.state_of(format($q$select public.catalog_save_service(%s, null, null, 'X', null, 10, 'fixed', 30, 0, 0, false, null, false, true, '{}')$q$, v_org)); return next;
  fn := 'save_package'; state := pg_temp.state_of(format($q$select public.catalog_save_package(%s, null, 'X', null, 10, 1, 30, false, true, array['00000000-0000-0000-0000-0000000151f2']::uuid[])$q$, v_org)); return next;
  fn := 'save_bundle'; state := pg_temp.state_of(format($q$select public.catalog_save_bundle(%s, null, 'X', null, null, 50, true, 0, '[{"service_id":"00000000-0000-0000-0000-0000000151f2","quantity":1,"allocated_price":30,"position":0},{"service_id":"00000000-0000-0000-0000-0000000151f3","quantity":1,"allocated_price":20,"position":1}]')$q$, v_org)); return next;
  fn := 'save_product'; state := pg_temp.state_of(format($q$select public.catalog_save_product(%s, null, 'X', null, 10, 5, null, null, null, 'un', 0, 5, null, false, true)$q$, v_org)); return next;
  fn := 'save_plan'; state := pg_temp.state_of(format($q$select public.catalog_save_plan(%s, null, 'X', null, 10, 'monthly', 1, '{}', true)$q$, v_org)); return next;
  fn := 'set_flags'; state := pg_temp.state_of(format($q$select public.catalog_set_flags(%s, 'service', '00000000-0000-0000-0000-0000000151f2', false, null)$q$, v_org)); return next;
  fn := 'delete_item'; state := pg_temp.state_of(format($q$select public.catalog_delete_item(%s, 'service', '00000000-0000-0000-0000-0000000151f2')$q$, v_org)); return next;
  fn := 'duplicate_item'; state := pg_temp.state_of(format($q$select public.catalog_duplicate_item(%s, 'service', '00000000-0000-0000-0000-0000000151f2')$q$, v_org)); return next;
  fn := 'reorder_services'; state := pg_temp.state_of(format($q$select public.catalog_reorder_services(%s, array['00000000-0000-0000-0000-0000000151f2']::uuid[])$q$, v_org)); return next;
  fn := 'stock'; state := pg_temp.state_of(format($q$select public.register_stock_entry_atomic(%s, '00000000-0000-0000-0000-0000000151aa', 'entrada', 1, null)$q$, v_org)); return next;
end $f$;
grant execute on function pg_temp.writes(uuid) to anon, authenticated;
select pg_temp.login('00000000-0000-0000-0000-000000001511');
select pg_temp.expect((select count(*) from pg_temp.writes('00000000-0000-0000-0000-00000000151a') where state = '42501') = 11, 'recepção: nenhuma gravação do catálogo passa');
select pg_temp.login('00000000-0000-0000-0000-000000001515');
select pg_temp.expect((select count(*) from pg_temp.writes('00000000-0000-0000-0000-00000000151a') where state = '42501') = 11, 'financeiro: nenhuma gravação do catálogo passa');
-- Dona do B tentando gravar no A: recusa de permissão em todas as ações (isolamento).
select pg_temp.login('00000000-0000-0000-0000-000000001512');
select pg_temp.expect((select count(*) from pg_temp.writes('00000000-0000-0000-0000-00000000151a') where state = '42501') = 11, 'dona do B: nenhuma gravação no catálogo do A');
select pg_temp.logout();
select pg_temp.expect((select count(*) from public.services where org_id = '00000000-0000-0000-0000-00000000151a') = 3, 'nada foi gravado pelas recusas');

-- ─── Sem login ────────────────────────────────────────────────
reset role;
select pg_temp.expect(not has_function_privilege('anon', 'public.catalog_screen(uuid)', 'execute'), 'anon sem execute em catalog_screen');
select pg_temp.expect(not has_function_privilege('anon', 'public.catalog_stock_entries(uuid, uuid)', 'execute'), 'anon sem execute em catalog_stock_entries');
select pg_temp.expect(not has_function_privilege('anon', 'public.catalog_save_service(uuid, uuid, uuid, text, text, numeric, text, integer, integer, numeric, boolean, uuid, boolean, boolean, uuid[], jsonb)', 'execute'), 'anon sem execute em catalog_save_service');
select pg_temp.expect(not has_function_privilege('anon', 'public.catalog_delete_item(uuid, text, uuid)', 'execute'), 'anon sem execute em catalog_delete_item');
select pg_temp.expect(not has_function_privilege('public', 'public.catalog_save_plan(uuid, uuid, text, text, numeric, text, integer, uuid[], boolean)', 'execute'), 'public sem execute em catalog_save_plan');
select pg_temp.expect((select count(*) from pg_catalog.pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname like 'catalog\_%'
  and p.proname <> 'catalog_audit_row'
  and (p.prosecdef or p.proconfig is null or not (p.proconfig @> array['search_path=""']))) = 0,
  'funções catalog_*: todas SECURITY INVOKER com search_path vazio');
select pg_temp.expect((select p.prosecdef and p.proconfig @> array['search_path=""'] from pg_catalog.pg_proc p where p.proname = 'catalog_audit_row'),
  'função do gatilho de auditoria: SECURITY DEFINER com search_path vazio (única DEFINER do catálogo)');
select pg_temp.expect(not has_function_privilege('authenticated', 'public.catalog_audit_row()', 'execute')
  and not has_function_privilege('anon', 'public.catalog_audit_row()', 'execute')
  and not has_function_privilege('public', 'public.catalog_audit_row()', 'execute'), 'função do gatilho: execução revogada de todos');
select pg_temp.expect(not exists (select 1 from pg_catalog.pg_proc where proname = 'catalog_audit'), 'não existe função de auditoria chamável (catalog_audit)');
select pg_temp.expect((select count(*) from pg_catalog.pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname like 'catalog\_%'
  and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('public', p.oid, 'execute'))) = 0,
  'nenhuma função catalog_* executável por anon ou public');
select set_config('request.jwt.claims', '', true);
select set_config('role', 'anon', true);
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_screen('00000000-0000-0000-0000-00000000151a')$q$) = '42501', 'anônimo não executa catalog_screen');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_set_flags('00000000-0000-0000-0000-00000000151a', 'service', '00000000-0000-0000-0000-0000000151f2', false, null)$q$) = '42501', 'anônimo não executa catalog_set_flags');
select pg_temp.expect(pg_temp.state_of($q$select public.register_stock_entry_atomic('00000000-0000-0000-0000-00000000151a', '00000000-0000-0000-0000-0000000151aa', 'entrada', 1, null)$q$) = '42501', 'anônimo não executa o estoque');

-- ─── Gravações: dona do estúdio A ─────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001510');

-- Categoria: cria e edita (a posição só vale na criação).
create temp table ids (k text primary key, v uuid) on commit drop;
grant all on ids to authenticated;
insert into ids select 'cat', public.catalog_save_category('00000000-0000-0000-0000-00000000151a', null, '  Lábios  ', '#AABBCC', '💋', 7);
select pg_temp.expect((select name || color || icon || position from public.service_categories where id = (select v from ids where k = 'cat')) = 'Lábios#AABBCC💋7', 'categoria criada (nome aparado, posição inicial)');
select public.catalog_save_category('00000000-0000-0000-0000-00000000151a', (select v from ids where k = 'cat'), 'Lábios e olhos', '#AABBCC', null, 99);
select pg_temp.expect((select name || position from public.service_categories where id = (select v from ids where k = 'cat')) = 'Lábios e olhos7', 'categoria editada sem mexer na posição');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_category('00000000-0000-0000-0000-00000000151a', null, repeat('a', 81), '#AABBCC', null)$q$) = '22023', 'categoria: nome acima de 80');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_category('00000000-0000-0000-0000-00000000151a', null, 'X', 'vermelho', null)$q$) = '22023', 'categoria: cor inválida');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_category('00000000-0000-0000-0000-00000000151a', '00000000-0000-0000-0000-0000000151c9', 'Invasão', '#AABBCC', null)$q$) = 'P0002', 'categoria do B pelo A: não encontrada');

-- Serviço: cria com profissionais e regras; edita (preço muda → auditoria); recusas.
insert into ids select 'svc', public.catalog_save_service('00000000-0000-0000-0000-00000000151a', null, '00000000-0000-0000-0000-0000000151c1',
  '  Brow lamination ', 'Descrição', 80, 'fixed', 45, 10, 30, true, '00000000-0000-0000-0000-0000000151e1', true, true,
  array['00000000-0000-0000-0000-0000000151a1', '00000000-0000-0000-0000-0000000151a1', '00000000-0000-0000-0000-0000000151a2']::uuid[],
  '{"result_months": 6, "retouch_included_days": 60, "deposit_type": "fixed", "deposit_value": 20}');
select pg_temp.expect((select name from public.services where id = (select v from ids where k = 'svc')) = 'Brow lamination', 'serviço criado com nome aparado');
select pg_temp.expect((select count(*) from public.service_staff where service_id = (select v from ids where k = 'svc')) = 2, 'profissionais repetidas viram uma só');
select pg_temp.expect((select result_months = 6 and retouch_included_days = 60 and deposit_type = 'fixed' and deposit_value = 20 and online_booking
  from public.services where id = (select v from ids where k = 'svc')), 'regras gravadas e reserva online ligada');
select pg_temp.expect(pg_temp.audits('CATALOG_UPDATED') = 0, 'criar não é mudança de preço');
-- Editar sem p_rules não apaga as regras; preço novo audita.
select public.catalog_save_service('00000000-0000-0000-0000-00000000151a', (select v from ids where k = 'svc'), null, 'Brow lamination', null, 90, 'fixed', 45, 10, 30,
  false, null, true, true, array['00000000-0000-0000-0000-0000000151a1']::uuid[]);
select pg_temp.expect((select retouch_included_days = 60 and price = 90 from public.services where id = (select v from ids where k = 'svc')), 'editar sem p_rules mantém as regras');
select pg_temp.expect((select count(*) from public.service_staff where service_id = (select v from ids where k = 'svc')) = 1, 'profissionais substituídas');
select pg_temp.expect(pg_temp.audits('CATALOG_UPDATED') = 1, 'preço mudou: uma linha de auditoria');
select pg_temp.expect((select old_data ->> 'price' = '80.00' and new_data ->> 'price' = '90.00' and user_id = '00000000-0000-0000-0000-000000001510'
  from public.audit_logs where operation = 'CATALOG_UPDATED' and record_id = (select v from ids where k = 'svc')), 'auditoria com preço antigo, novo e quem mudou');
select pg_temp.expect((select not (old_data ? 'commission_pct') and not (new_data ? 'active') and (select count(*) from jsonb_object_keys(new_data)) = 1
  from public.audit_logs where operation = 'CATALOG_UPDATED' and record_id = (select v from ids where k = 'svc')), 'payload só com a coluna que mudou');
-- Mesmo preço: nada novo na auditoria. Duração 0 desliga a reserva online. Preço grátis zera.
select public.catalog_save_service('00000000-0000-0000-0000-00000000151a', (select v from ids where k = 'svc'), null, 'Brow lamination', null, 90, 'fixed', 0, 10, 30,
  false, null, true, true, '{}');
select pg_temp.expect(pg_temp.audits('CATALOG_UPDATED') = 1, 'sem mudança de dinheiro: sem auditoria nova');
select pg_temp.expect((select not online_booking from public.services where id = (select v from ids where k = 'svc')), 'serviço sem duração fica fora da reserva online');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_set_flags('00000000-0000-0000-0000-00000000151a', 'service', (select v from ids where k = 'svc'), null, true)$q$) = '22023', 'sem duração não liga reserva online');
select public.catalog_save_service('00000000-0000-0000-0000-00000000151a', (select v from ids where k = 'svc'), null, 'Brow lamination', null, 70, 'free', 45, 10, 30, false, null, false, true, '{}', '{}');
select pg_temp.expect((select price = 0 from public.services where id = (select v from ids where k = 'svc')), 'preço "grátis" grava zero');
-- Recusas (cada uma sem gravar nada).
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_service('00000000-0000-0000-0000-00000000151a', null, null, repeat('a', 201), null, 1, 'fixed', 30, 0, 0, false, null, false, true, '{}')$q$) = '22023', 'serviço: nome acima de 200');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_service('00000000-0000-0000-0000-00000000151a', null, null, 'X', repeat('a', 2001), 1, 'fixed', 30, 0, 0, false, null, false, true, '{}')$q$) = '22023', 'serviço: descrição acima de 2000');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_service('00000000-0000-0000-0000-00000000151a', null, null, 'X', null, 100001, 'fixed', 30, 0, 0, false, null, false, true, '{}')$q$) = '22023', 'serviço: preço acima de 100000');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_service('00000000-0000-0000-0000-00000000151a', null, null, 'X', null, -1, 'fixed', 30, 0, 0, false, null, false, true, '{}')$q$) = '22023', 'serviço: preço negativo');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_service('00000000-0000-0000-0000-00000000151a', null, null, 'X', null, 1, 'fixed', 10, 0, 0, false, null, false, true, '{}')$q$) = '22023', 'serviço: duração fora da faixa');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_service('00000000-0000-0000-0000-00000000151a', null, null, 'X', null, 1, 'fixed', 30, 0, 101, false, null, false, true, '{}')$q$) = '22023', 'serviço: comissão acima de 100');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_service('00000000-0000-0000-0000-00000000151a', null, null, 'X', null, 1, 'fixed', 30, 0, 0, true, null, false, true, '{}')$q$) = '22023', 'serviço: exigir ficha sem escolher o modelo');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_service('00000000-0000-0000-0000-00000000151a', null, null, 'X', null, 1, 'fixed', 30, 0, 0, false, null, false, true, '{}', '{"deposit_type": "percent", "deposit_value": 101}')$q$) = '22023', 'serviço: sinal acima de 100%');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_service('00000000-0000-0000-0000-00000000151a', null, '00000000-0000-0000-0000-0000000151c9', 'X', null, 1, 'fixed', 30, 0, 0, false, null, false, true, '{}')$q$) = 'P0002', 'serviço: categoria do outro estúdio');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_service('00000000-0000-0000-0000-00000000151a', null, null, 'X', null, 1, 'fixed', 30, 0, 0, true, '00000000-0000-0000-0000-0000000151e9', false, true, '{}')$q$) = 'P0002', 'serviço: modelo de ficha do outro estúdio');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_service('00000000-0000-0000-0000-00000000151a', null, null, 'X', null, 1, 'fixed', 30, 0, 0, false, null, false, true, array['00000000-0000-0000-0000-0000000151a9']::uuid[])$q$) = 'P0002', 'serviço: profissional do outro estúdio');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_service('00000000-0000-0000-0000-00000000151a', '00000000-0000-0000-0000-0000000151f9', null, 'Invasão', null, 1, 'fixed', 30, 0, 0, false, null, false, true, '{}')$q$) = 'P0002', 'serviço do B pelo estúdio do A: não encontrado');
select pg_temp.logout();
select pg_temp.expect((select name from public.services where id = '00000000-0000-0000-0000-0000000151f9') = 'Serviço B', 'serviço do B intacto');
select pg_temp.login('00000000-0000-0000-0000-000000001510');
-- Tudo-ou-nada: a falha no fim (profissional do B) não deixa o serviço criado.
select pg_temp.expect((select count(*) from public.services where org_id = '00000000-0000-0000-0000-00000000151a' and name = 'X') = 0, 'recusas não criaram serviço');

-- Ligar/desligar e reordenar.
select public.catalog_set_flags('00000000-0000-0000-0000-00000000151a', 'service', (select v from ids where k = 'svc'), false, null);
select pg_temp.expect((select not active from public.services where id = (select v from ids where k = 'svc')), 'serviço arquivado');
select pg_temp.expect(pg_temp.changed('services', 'active') = 1, 'arquivar audita');
select public.catalog_set_flags('00000000-0000-0000-0000-00000000151a', 'service', (select v from ids where k = 'svc'), false, null);
select pg_temp.expect(pg_temp.changed('services', 'active') = 1, 'arquivar de novo não audita de novo');
select public.catalog_set_flags('00000000-0000-0000-0000-00000000151a', 'service', (select v from ids where k = 'svc'), true, true);
select pg_temp.expect((select active and online_booking from public.services where id = (select v from ids where k = 'svc')), 'serviço reativado e na reserva online');
select pg_temp.expect(pg_temp.changed('services', 'active') = 2, 'reativar audita');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_set_flags('00000000-0000-0000-0000-00000000151a', 'service', '00000000-0000-0000-0000-0000000151f9', false, null)$q$) = 'P0002', 'ligar/desligar serviço do B pelo A');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_set_flags('00000000-0000-0000-0000-00000000151a', 'service', '00000000-0000-0000-0000-0000000151f2', null, null)$q$) = '22023', 'sem alteração informada');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_set_flags('00000000-0000-0000-0000-00000000151a', 'plan', '00000000-0000-0000-0000-0000000151d9', null, true)$q$) = '22023', 'plano não tem reserva online');
select public.catalog_reorder_services('00000000-0000-0000-0000-00000000151a', array[(select v from ids where k = 'svc'), '00000000-0000-0000-0000-0000000151f3', '00000000-0000-0000-0000-0000000151f2', '00000000-0000-0000-0000-0000000151f1']::uuid[]);
select pg_temp.expect((select array_agg(position order by position) from public.services where org_id = '00000000-0000-0000-0000-00000000151a') = array[0, 1, 2, 3], 'ordem gravada como 0, 1, 2, 3');
select pg_temp.expect((select position from public.services where id = '00000000-0000-0000-0000-0000000151f2') = 2, 'posição do serviço = lugar na lista');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_reorder_services('00000000-0000-0000-0000-00000000151a', array['00000000-0000-0000-0000-0000000151f2', '00000000-0000-0000-0000-0000000151f9']::uuid[])$q$) = 'P0002', 'reordenar com serviço do B: recusa');
select pg_temp.expect((select position from public.services where id = '00000000-0000-0000-0000-0000000151f2') = 2, 'a recusa não mexeu em nenhuma posição');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_reorder_services('00000000-0000-0000-0000-00000000151a', array['00000000-0000-0000-0000-0000000151f2', '00000000-0000-0000-0000-0000000151f2']::uuid[])$q$) = '22023', 'reordenar com id repetido');

-- Duplicar.
insert into ids select 'svc2', public.catalog_duplicate_item('00000000-0000-0000-0000-00000000151a', 'service', '00000000-0000-0000-0000-0000000151f1');
select pg_temp.expect((select name = 'Cópia de Serviço usado' and not online_booking and active and price = 50 from public.services where id = (select v from ids where k = 'svc2')), 'cópia do serviço: fora da reserva online, ativa');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_duplicate_item('00000000-0000-0000-0000-00000000151a', 'service', '00000000-0000-0000-0000-0000000151f9')$q$) = 'P0002', 'duplicar serviço do B pelo A');
insert into ids select 'pkgcopy', public.catalog_duplicate_item('00000000-0000-0000-0000-00000000151a', 'package', '00000000-0000-0000-0000-0000000151b1');
select pg_temp.expect((select not active and not online_booking and name = 'Cópia de Pacote vendido' from public.service_packages where id = (select v from ids where k = 'pkgcopy')), 'cópia do pacote fora de venda');
select pg_temp.expect((select count(*) from public.package_services where package_id = (select v from ids where k = 'pkgcopy')) = 1, 'cópia do pacote leva os serviços');
insert into ids select 'prodcopy', public.catalog_duplicate_item('00000000-0000-0000-0000-00000000151a', 'product', '00000000-0000-0000-0000-0000000151aa');
select pg_temp.expect((select stock_qty = 0 and sku is null and not active and price = 10 from public.products where id = (select v from ids where k = 'prodcopy')), 'cópia do produto: sem estoque, sem código, desligada');

-- Pacote: cria, edita (preço muda → auditoria), recusas.
insert into ids select 'pkg', public.catalog_save_package('00000000-0000-0000-0000-00000000151a', null, 'Pacote novo', null, 150, 3, 90, true, true,
  array['00000000-0000-0000-0000-0000000151f2', '00000000-0000-0000-0000-0000000151f3']::uuid[]);
select pg_temp.expect((select count(*) from public.package_services where package_id = (select v from ids where k = 'pkg')) = 2, 'pacote com dois serviços');
select public.catalog_save_package('00000000-0000-0000-0000-00000000151a', (select v from ids where k = 'pkg'), 'Pacote novo', null, 120, 3, 90, true, false,
  array['00000000-0000-0000-0000-0000000151f2']::uuid[]);
select pg_temp.expect((select count(*) from public.package_services where package_id = (select v from ids where k = 'pkg')) = 1, 'serviços do pacote substituídos');
select pg_temp.expect(pg_temp.changed('service_packages', 'price') = 1, 'pacote: preço mudou, auditado');
select pg_temp.expect(pg_temp.changed('service_packages', 'active') = 1, 'pacote: desativar audita');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_package('00000000-0000-0000-0000-00000000151a', null, 'X', null, 1, 1, 30, false, true, '{}')$q$) = '22023', 'pacote sem serviço');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_package('00000000-0000-0000-0000-00000000151a', null, 'X', null, 1, 1, 30, false, true, array['00000000-0000-0000-0000-0000000151f9']::uuid[])$q$) = 'P0002', 'pacote com serviço do outro estúdio');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_package('00000000-0000-0000-0000-00000000151a', null, 'X', null, 1, 1000, 30, false, true, array['00000000-0000-0000-0000-0000000151f2']::uuid[])$q$) = '22023', 'pacote com mais de 999 sessões');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_package('00000000-0000-0000-0000-00000000151a', null, 'X', null, 1, 1, 3651, false, true, array['00000000-0000-0000-0000-0000000151f2']::uuid[])$q$) = '22023', 'pacote com validade acima de 3650 dias');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_package('00000000-0000-0000-0000-00000000151a', '00000000-0000-0000-0000-0000000151b1', 'Invasão', null, 1, 1, 30, false, true, array['00000000-0000-0000-0000-0000000151f9']::uuid[])$q$) = 'P0002', 'pacote: serviço do B recusado, nada muda');
select pg_temp.expect((select name from public.service_packages where id = '00000000-0000-0000-0000-0000000151b1') = 'Pacote vendido', 'pacote intacto após a recusa');
select public.catalog_set_flags('00000000-0000-0000-0000-00000000151a', 'package', (select v from ids where k = 'pkg'), true, true);
select pg_temp.expect((select active and online_booking from public.service_packages where id = (select v from ids where k = 'pkg')), 'pacote ligado');

-- Combo: cria (total fecha com o preço), edita, arquiva, restaura, duplica.
insert into ids select 'bundle', public.catalog_save_bundle('00000000-0000-0000-0000-00000000151a', null, 'Combo olhar', 'Descrição', '00000000-0000-0000-0000-0000000151c1', 50, true, 2,
  '[{"service_id":"00000000-0000-0000-0000-0000000151f2","quantity":1,"allocated_price":30,"position":1},{"service_id":"00000000-0000-0000-0000-0000000151f3","quantity":1,"allocated_price":20,"position":0}]');
select pg_temp.expect((select array_agg(service_id order by position) from public.service_bundle_items where bundle_id = (select v from ids where k = 'bundle'))
  = array['00000000-0000-0000-0000-0000000151f3', '00000000-0000-0000-0000-0000000151f2']::uuid[], 'itens do combo na ordem pedida');
select pg_temp.expect((select original_price_snapshot = 20 from public.service_bundle_items where bundle_id = (select v from ids where k = 'bundle') and service_id = '00000000-0000-0000-0000-0000000151f3'), 'preço original do serviço guardado no item');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_bundle('00000000-0000-0000-0000-00000000151a', null, 'X', null, null, 60, true, 0, '[{"service_id":"00000000-0000-0000-0000-0000000151f2","quantity":1,"allocated_price":30,"position":1},{"service_id":"00000000-0000-0000-0000-0000000151f3","quantity":1,"allocated_price":20,"position":0}]')$q$) = '22023', 'combo: soma não fecha com o preço');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_bundle('00000000-0000-0000-0000-00000000151a', null, 'X', null, null, 30, true, 0, '[{"service_id":"00000000-0000-0000-0000-0000000151f2","quantity":1,"allocated_price":30,"position":0}]')$q$) = '22023', 'combo com um serviço só');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_bundle('00000000-0000-0000-0000-00000000151a', null, 'X', null, null, 50, true, 0, '[{"service_id":"00000000-0000-0000-0000-0000000151f2","quantity":1,"allocated_price":30,"position":1},{"service_id":"00000000-0000-0000-0000-0000000151f9","quantity":1,"allocated_price":20,"position":0}]')$q$) = 'P0002', 'combo com serviço do outro estúdio');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_bundle('00000000-0000-0000-0000-00000000151a', null, 'X', null, null, 50, true, 0, '[{"service_id":"00000000-0000-0000-0000-0000000151f2","quantity":0,"allocated_price":30,"position":1},{"service_id":"00000000-0000-0000-0000-0000000151f3","quantity":1,"allocated_price":20,"position":0}]')$q$) = '22023', 'combo com quantidade zero');
select public.catalog_save_bundle('00000000-0000-0000-0000-00000000151a', (select v from ids where k = 'bundle'), 'Combo olhar', null, null, 45, true, 2,
  '[{"service_id":"00000000-0000-0000-0000-0000000151f2","quantity":1,"allocated_price":25,"position":1},{"service_id":"00000000-0000-0000-0000-0000000151f3","quantity":1,"allocated_price":20,"position":0}]');
select pg_temp.expect(pg_temp.changed('service_bundles', 'price') = 1, 'combo: preço mudou, auditado');
select public.catalog_set_flags('00000000-0000-0000-0000-00000000151a', 'bundle', (select v from ids where k = 'bundle'), false, null);
select pg_temp.expect((select not active and archived_at is not null from public.service_bundles where id = (select v from ids where k = 'bundle')), 'combo arquivado');
select pg_temp.expect(pg_temp.changed('service_bundles', 'archived_at') = 1, 'combo: arquivar audita');
insert into ids select 'bundlecopy', public.catalog_duplicate_item('00000000-0000-0000-0000-00000000151a', 'bundle', (select v from ids where k = 'bundle'));
select pg_temp.expect((select not active and name = 'Cópia de Combo olhar' and price = 45 and position = 3 from public.service_bundles where id = (select v from ids where k = 'bundlecopy')), 'cópia do combo desligada');
select pg_temp.expect((select count(*) from public.service_bundle_items where bundle_id = (select v from ids where k = 'bundlecopy')) = 2, 'cópia do combo leva os itens');
select public.catalog_set_flags('00000000-0000-0000-0000-00000000151a', 'bundle', (select v from ids where k = 'bundle'), true, null);
select pg_temp.expect((select active and archived_at is null from public.service_bundles where id = (select v from ids where k = 'bundle')), 'combo restaurado');

-- Produto: cria com estoque inicial; edição não mexe no estoque; preço audita; estoque pela função; apagar.
insert into ids select 'prod', public.catalog_save_product('00000000-0000-0000-0000-00000000151a', null, 'Creme', 'Hidratante', 21.5, 8, ' SKU1 ', null, 'Marca', 'un', 7, 3,
  '00000000-0000-0000-0000-0000000151c1', false, true);
select pg_temp.expect((select stock_qty = 7 and sku = 'SKU1' and barcode is null and position = 0 from public.products where id = (select v from ids where k = 'prod')), 'produto criado com estoque inicial');
select public.catalog_save_product('00000000-0000-0000-0000-00000000151a', (select v from ids where k = 'prod'), 'Creme', null, 25, 8, null, null, null, 'un', 999, 4, null, true, true);
select pg_temp.expect((select stock_qty = 7 and price = 25 and stock_alert = 4 and sku is null from public.products where id = (select v from ids where k = 'prod')), 'editar o produto ignora o estoque do formulário');
select pg_temp.expect(pg_temp.changed('products', 'price') = 1, 'produto: preço mudou, auditado');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_product('00000000-0000-0000-0000-00000000151a', null, 'X', null, 1, 1, null, null, null, '', 0, 0, null, false, true)$q$) = '22023', 'produto sem unidade');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_product('00000000-0000-0000-0000-00000000151a', null, 'X', null, 100001, 1, null, null, null, 'un', 0, 0, null, false, true)$q$) = '22023', 'produto: preço acima de 100000');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_product('00000000-0000-0000-0000-00000000151a', null, 'X', null, 1, 1, repeat('a', 61), null, null, 'un', 0, 0, null, false, true)$q$) = '22023', 'produto: código acima de 60');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_product('00000000-0000-0000-0000-00000000151a', null, 'X', null, 1, 1, null, null, null, 'un', -1, 0, null, false, true)$q$) = '22023', 'produto: estoque negativo');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_product('00000000-0000-0000-0000-00000000151a', null, 'X', null, 1, 1, null, null, null, 'un', 0, 0, '00000000-0000-0000-0000-0000000151c9', false, true)$q$) = 'P0002', 'produto: categoria do outro estúdio');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_product('00000000-0000-0000-0000-00000000151a', '00000000-0000-0000-0000-0000000151ac', 'Invasão', null, 1, 1, null, null, null, 'un', 0, 0, null, false, true)$q$) = 'P0002', 'produto do B pelo A: não encontrado');
select pg_temp.expect(public.register_stock_entry_atomic('00000000-0000-0000-0000-00000000151a', (select v from ids where k = 'prod'), 'saida', 2, 'Venda') = 5, 'saída de estoque devolve o saldo');
select pg_temp.expect((select count(*) from public.audit_logs where operation = 'STOCK_SAIDA') = 1, 'movimento de estoque auditado');
select pg_temp.expect(jsonb_array_length(public.catalog_stock_entries('00000000-0000-0000-0000-00000000151a', (select v from ids where k = 'prod'))) = 1, 'histórico mostra o movimento');
select pg_temp.expect(pg_temp.state_of(format($q$select public.register_stock_entry_atomic('00000000-0000-0000-0000-00000000151a', %L, 'saida', 99, null)$q$, (select v from ids where k = 'prod'))) = '22003', 'saída maior que o estoque');
select pg_temp.expect(pg_temp.state_of($q$select public.register_stock_entry_atomic('00000000-0000-0000-0000-00000000151a', '00000000-0000-0000-0000-0000000151ac', 'entrada', 1, null)$q$) = 'P0002', 'estoque de produto do B pelo A');
-- Apagar: sem histórico exclui (e audita); com histórico só arquiva.
select pg_temp.expect(public.catalog_delete_item('00000000-0000-0000-0000-00000000151a', 'product', '00000000-0000-0000-0000-0000000151ab') = 'deleted', 'produto sem histórico é excluído');
select pg_temp.expect(not exists (select 1 from public.products where id = '00000000-0000-0000-0000-0000000151ab'), 'produto sumiu');
select pg_temp.expect((select old_data ->> 'name' = 'Produto sem histórico' from public.audit_logs where operation = 'CATALOG_DELETED' and table_name = 'products'), 'exclusão do produto auditada com o nome');
select pg_temp.expect(public.catalog_delete_item('00000000-0000-0000-0000-00000000151a', 'product', '00000000-0000-0000-0000-0000000151aa') = 'archived', 'produto com estoque lançado só arquiva');
select pg_temp.expect((select not active from public.products where id = '00000000-0000-0000-0000-0000000151aa'), 'produto arquivado continua na tabela');
select pg_temp.expect(public.catalog_delete_item('00000000-0000-0000-0000-00000000151a', 'service', '00000000-0000-0000-0000-0000000151f1') = 'archived', 'serviço usado em atendimento só arquiva');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_delete_item('00000000-0000-0000-0000-00000000151a', 'service', '00000000-0000-0000-0000-0000000151f3')$q$) = '22023', 'serviço em combo ativo: recusa');
select pg_temp.expect((select m like 'Está no combo "Combo olhar": tire de lá antes.' from (select (select message from pg_temp.msg_of($q$select public.catalog_delete_item('00000000-0000-0000-0000-00000000151a', 'service', '00000000-0000-0000-0000-0000000151f3')$q$)) m) x), 'recusa diz qual combo');
select public.catalog_set_flags('00000000-0000-0000-0000-00000000151a', 'bundle', (select v from ids where k = 'bundle'), false, null);
select pg_temp.expect(public.catalog_delete_item('00000000-0000-0000-0000-00000000151a', 'service', '00000000-0000-0000-0000-0000000151f3') = 'archived', 'serviço em combo arquivado só arquiva');
select pg_temp.expect(public.catalog_delete_item('00000000-0000-0000-0000-00000000151a', 'service', (select v from ids where k = 'svc2')) = 'deleted', 'cópia do serviço sem histórico é excluída');
select pg_temp.expect((select count(*) from public.audit_logs where operation = 'CATALOG_DELETED' and table_name = 'services') = 1, 'exclusão do serviço auditada');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_delete_item('00000000-0000-0000-0000-00000000151a', 'service', '00000000-0000-0000-0000-0000000151f9')$q$) = 'P0002', 'excluir serviço do B pelo A');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_delete_item('00000000-0000-0000-0000-00000000151a', 'plan', '00000000-0000-0000-0000-0000000151d9')$q$) = '22023', 'só serviço e produto se excluem');
select pg_temp.logout();
select pg_temp.expect((select name from public.services where id = '00000000-0000-0000-0000-0000000151f9') = 'Serviço B', 'serviço do B intacto');
select pg_temp.login('00000000-0000-0000-0000-000000001510');

-- Plano: serviços incluídos conferidos; vazio = todos; preço audita; duplicar.
insert into ids select 'plan', public.catalog_save_plan('00000000-0000-0000-0000-00000000151a', null, 'Glow mensal', null, 90, 'quarterly', 3,
  array['00000000-0000-0000-0000-0000000151f2', '00000000-0000-0000-0000-0000000151f2']::uuid[], true);
select pg_temp.expect((select eligible_services = '[{"qty": 1, "service_id": "00000000-0000-0000-0000-0000000151f2", "service_name": "Serviço livre"}]'::jsonb
  and billing_period = 'quarterly' and sessions_per_period = 3 from public.subscription_plans where id = (select v from ids where k = 'plan')), 'plano com o serviço incluído (nome gravado)');
select public.catalog_save_plan('00000000-0000-0000-0000-00000000151a', (select v from ids where k = 'plan'), 'Glow mensal', null, 100, 'monthly', 3, '{}', true);
select pg_temp.expect((select eligible_services = '[]'::jsonb from public.subscription_plans where id = (select v from ids where k = 'plan')), 'plano sem serviços = todos');
select pg_temp.expect(pg_temp.changed('subscription_plans', 'price') = 1 and pg_temp.changed('subscription_plans', 'billing_period') = 1
  and pg_temp.changed('subscription_plans', 'eligible_services') = 1, 'plano: preço, cobrança e serviços incluídos mudaram, auditados');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_plan('00000000-0000-0000-0000-00000000151a', null, 'X', null, 1, 'weekly', 1, '{}', true)$q$) = '22023', 'plano: cobrança inválida');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_plan('00000000-0000-0000-0000-00000000151a', null, 'X', null, 1, 'monthly', 0, '{}', true)$q$) = '22023', 'plano: zero sessões');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_plan('00000000-0000-0000-0000-00000000151a', null, 'X', null, 1, 'monthly', 1, array['00000000-0000-0000-0000-0000000151f9']::uuid[], true)$q$) = 'P0002', 'plano com serviço do outro estúdio');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_plan('00000000-0000-0000-0000-00000000151a', '00000000-0000-0000-0000-0000000151d9', 'Invasão', null, 1, 'monthly', 1, '{}', true)$q$) = 'P0002', 'plano do B pelo A: não encontrado');
select pg_temp.logout();
select pg_temp.expect((select name from public.subscription_plans where id = '00000000-0000-0000-0000-0000000151d9') = 'Plano B', 'plano do B intacto');
select pg_temp.login('00000000-0000-0000-0000-000000001510');
insert into ids select 'plancopy', public.catalog_duplicate_item('00000000-0000-0000-0000-00000000151a', 'plan', (select v from ids where k = 'plan'));
select pg_temp.expect((select not active and not online_booking and price = 100 and name = 'Cópia de Glow mensal' from public.subscription_plans where id = (select v from ids where k = 'plancopy')), 'cópia do plano desligada');
select public.catalog_set_flags('00000000-0000-0000-0000-00000000151a', 'plan', (select v from ids where k = 'plancopy'), true, null);
select pg_temp.expect((select active from public.subscription_plans where id = (select v from ids where k = 'plancopy')), 'plano ligado');

-- Depois de tudo, a tela mostra o que foi gravado (e continua sem o que é do B).
create temp table s_b on commit drop as select public.catalog_screen('00000000-0000-0000-0000-00000000151a') as s;
select pg_temp.expect((select jsonb_array_length(s -> 'plans') from s_b) = 2, 'tela: dois planos do A');
select pg_temp.expect((select jsonb_array_length(s -> 'bundles') from s_b) = 2, 'tela: dois combos do A');
select pg_temp.expect((select (select (b ->> 'price')::numeric from jsonb_array_elements(s -> 'bundles') b where b ->> 'name' = 'Combo olhar')
  from s_b) = 45, 'tela: combo com o preço novo');
select pg_temp.expect((select jsonb_array_length(b -> 'items') from s_b, jsonb_array_elements(s -> 'bundles') b where b ->> 'name' = 'Combo olhar') = 2, 'tela: itens do combo');
select pg_temp.expect((select s -> 'bundles' -> 0 ? 'archived_at' from s_b), 'tela: combo com archived_at');
select pg_temp.expect((select not exists (select 1 from jsonb_array_elements(s -> 'services') e where e ->> 'id' = '00000000-0000-0000-0000-0000000151f9') from s_b), 'tela: serviço do B nunca aparece');

-- ─── Gerente e profissional com a liberação gravam; o gerente audita ──────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001513');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_category('00000000-0000-0000-0000-00000000151a', null, 'Do gerente', '#112233', null)$q$) = 'ok', 'gerente grava categoria');
select public.catalog_save_product('00000000-0000-0000-0000-00000000151a', (select v from ids where k = 'prod'), 'Creme', null, 30, 8, null, null, null, 'un', 0, 4, null, true, true);
select pg_temp.logout();
select pg_temp.expect((select count(*) from public.audit_logs where table_name = 'products' and operation = 'CATALOG_UPDATED' and new_data ? 'price'
  and user_id = '00000000-0000-0000-0000-000000001513') = 1, 'gerente: preço do produto auditado em nome dele');
-- Profissional recebeu catalogo.manage do estúdio: o banco respeita a liberação (e o papel está na lista da auditoria).
select pg_temp.login('00000000-0000-0000-0000-000000001514');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_category('00000000-0000-0000-0000-00000000151a', null, 'Da profissional', '#112233', null)$q$) = 'ok', 'profissional com a liberação grava');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_set_flags('00000000-0000-0000-0000-00000000151a', 'product', '00000000-0000-0000-0000-0000000151aa', true, null)$q$) = 'ok', 'profissional com a liberação reativa produto (audita)');
select pg_temp.expect(public.register_stock_entry_atomic('00000000-0000-0000-0000-00000000151a', (select v from ids where k = 'prod'), 'entrada', 4, null) = 9, 'profissional com a liberação movimenta estoque');
-- Sem a liberação o banco recusa de novo.
select pg_temp.logout();
update public.org_role_permissions set allowed = false where org_id = '00000000-0000-0000-0000-00000000151a' and role = 'professional' and permission = 'catalogo.manage';
select pg_temp.login('00000000-0000-0000-0000-000000001514');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_category('00000000-0000-0000-0000-00000000151a', null, 'Barrada', '#112233', null)$q$) = '42501', 'liberação retirada: recusa');
select pg_temp.expect(pg_temp.state_of($q$select public.register_stock_entry_atomic('00000000-0000-0000-0000-00000000151a', (select v from ids where k = 'prod'), 'entrada', 1, null)$q$) = '42501', 'liberação retirada: estoque recusa');
select pg_temp.logout();

select pg_temp.login('00000000-0000-0000-0000-000000001510');
insert into ids select 'svcx', public.catalog_save_service('00000000-0000-0000-0000-00000000151a', null, null, 'Serviço extra', null, 15, 'fixed', 30, 0, 0, false, null, false, true, '{}');
create function pg_temp.items(p_a numeric, p_b numeric, p_c numeric) returns jsonb language sql as $$
  select jsonb_agg(e order by (e ->> 'position')::int) from (
    select jsonb_build_object('service_id', '00000000-0000-0000-0000-0000000151f2', 'quantity', 1, 'allocated_price', p_a, 'position', 1) e
    union all select jsonb_build_object('service_id', (select v from ids where k = 'svc'), 'quantity', 1, 'allocated_price', p_b, 'position', 0)
    union all select jsonb_build_object('service_id', (select v from ids where k = 'svcx'), 'quantity', 1, 'allocated_price', p_c, 'position', 2) where p_c is not null) t
$$;
grant execute on function pg_temp.items(numeric, numeric, numeric) to authenticated;
-- ─── Revisão: exclusão com uso, arquivados, auditoria por gatilho, viewer, limites na tabela ───────────
-- Serviço com fila de espera: arquiva (a fila apagaria em cascata); serviço em pacote ativo: recusa com o nome do pacote.
insert into ids select 'svcw', public.catalog_save_service('00000000-0000-0000-0000-00000000151a', null, null, 'Serviço da fila', null, 40, 'fixed', 30, 0, 0, null, null, false, true, '{}');
select pg_temp.expect((select not requires_anamnese from public.services where id = (select v from ids where k = 'svcw')), 'p_requires_anamnese nulo vale falso');
insert into public.agenda_waitlist (org_id, client_id, service_id, windows) values
  ('00000000-0000-0000-0000-00000000151a', '00000000-0000-0000-0000-0000000151d1', (select v from ids where k = 'svcw'), '[]');
select pg_temp.expect(public.catalog_delete_item('00000000-0000-0000-0000-00000000151a', 'service', (select v from ids where k = 'svcw')) = 'archived', 'serviço na fila de espera só arquiva');
select pg_temp.expect((select count(*) from public.agenda_waitlist where service_id = (select v from ids where k = 'svcw')) = 1, 'a fila de espera continua');
insert into ids select 'svca', public.catalog_save_service('00000000-0000-0000-0000-00000000151a', null, null, 'Serviço da ficha', null, 40, 'fixed', 30, 0, 0, false, null, false, true, '{}');
-- A ficha é gravada como dono do banco: a tabela anamneses é fechada para a API (20261114040000).
select pg_temp.logout();
insert into public.anamneses (org_id, public_token, source_service_id) values
  ('00000000-0000-0000-0000-00000000151a', 'tok-c151-1', (select v from ids where k = 'svca'));
select pg_temp.login('00000000-0000-0000-0000-000000001510');
select pg_temp.expect(public.catalog_delete_item('00000000-0000-0000-0000-00000000151a', 'service', (select v from ids where k = 'svca')) = 'archived', 'serviço de origem de uma ficha só arquiva');
select pg_temp.logout();
select pg_temp.expect((select source_service_id is not null from public.anamneses where token_hash = encode(extensions.digest('tok-c151-1', 'sha256'), 'hex')), 'a ficha mantém o serviço de origem');
select pg_temp.login('00000000-0000-0000-0000-000000001510');
insert into ids select 'svcp', public.catalog_save_service('00000000-0000-0000-0000-00000000151a', null, null, 'Serviço do pacote', null, 40, 'fixed', 30, 0, 0, false, null, false, true, '{}');
insert into ids select 'pkgp', public.catalog_save_package('00000000-0000-0000-0000-00000000151a', null, 'Pacote ativo', null, 40, 2, 30, false, true, array[(select v from ids where k = 'svcp')]);
select pg_temp.expect(pg_temp.state_of(format($q$select public.catalog_delete_item('00000000-0000-0000-0000-00000000151a', 'service', %L)$q$, (select v from ids where k = 'svcp'))) = '22023', 'serviço em pacote ativo: recusa');
select pg_temp.expect((select message = 'Está no pacote "Pacote ativo": tire de lá antes.' from pg_temp.msg_of(format($q$select public.catalog_delete_item('00000000-0000-0000-0000-00000000151a', 'service', %L)$q$, (select v from ids where k = 'svcp')))), 'recusa diz qual pacote');
-- Serviço em plano de assinatura: plano ativo recusa com o nome; plano desligado só faz arquivar.
insert into ids select 'svcl', public.catalog_save_service('00000000-0000-0000-0000-00000000151a', null, null, 'Serviço do plano', null, 40, 'fixed', 30, 0, 0, false, null, false, true, '{}');
insert into ids select 'planl', public.catalog_save_plan('00000000-0000-0000-0000-00000000151a', null, 'Plano com serviço', null, 30, 'monthly', 2, array[(select v from ids where k = 'svcl')], true);
select pg_temp.expect(pg_temp.state_of(format($q$select public.catalog_delete_item('00000000-0000-0000-0000-00000000151a', 'service', %L)$q$, (select v from ids where k = 'svcl'))) = '22023', 'serviço em plano ativo: recusa');
select pg_temp.expect((select message = 'Está no plano "Plano com serviço": tire de lá antes.' from pg_temp.msg_of(format($q$select public.catalog_delete_item('00000000-0000-0000-0000-00000000151a', 'service', %L)$q$, (select v from ids where k = 'svcl')))), 'recusa diz qual plano');
select public.catalog_set_flags('00000000-0000-0000-0000-00000000151a', 'plan', (select v from ids where k = 'planl'), false, null);
select pg_temp.expect(public.catalog_delete_item('00000000-0000-0000-0000-00000000151a', 'service', (select v from ids where k = 'svcl')) = 'archived', 'serviço em plano desligado só arquiva');
-- Serviço arquivado não entra em pacote nem combo novo; quem já estava pode continuar.
select pg_temp.expect(pg_temp.state_of(format($q$select public.catalog_save_package('00000000-0000-0000-0000-00000000151a', null, 'X', null, 1, 1, 30, false, true, array[%L]::uuid[])$q$, (select v from ids where k = 'svcw'))) = '22023', 'pacote novo recusa serviço arquivado');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_bundle('00000000-0000-0000-0000-00000000151a', null, 'X', null, null, 50, true, 0, '[{"service_id":"00000000-0000-0000-0000-0000000151f2","quantity":1,"allocated_price":30,"position":1},{"service_id":"00000000-0000-0000-0000-0000000151f3","quantity":1,"allocated_price":20,"position":0}]')$q$) = '22023', 'combo novo recusa serviço arquivado (f3)');
select pg_temp.expect(pg_temp.state_of(format($q$select public.catalog_save_bundle('00000000-0000-0000-0000-00000000151a', %L, 'Combo olhar', null, null, 45, true, 2, '[{"service_id":"00000000-0000-0000-0000-0000000151f2","quantity":1,"allocated_price":25,"position":1},{"service_id":"00000000-0000-0000-0000-0000000151f3","quantity":1,"allocated_price":20,"position":0}]')$q$, (select v from ids where k = 'bundle'))) = 'ok', 'combo que já tinha o serviço arquivado continua salvando');
-- Combo: salvar inativo e desligar na lista dão o mesmo estado (arquivado).
insert into ids select 'bundle2', public.catalog_save_bundle('00000000-0000-0000-0000-00000000151a', null, 'Combo inativo', null, null, 50, false, 5,
  pg_temp.items(30, 20, null));
select pg_temp.expect((select not active and archived_at is not null from public.service_bundles where id = (select v from ids where k = 'bundle2')), 'combo salvo inativo nasce arquivado');
select public.catalog_save_bundle('00000000-0000-0000-0000-00000000151a', (select v from ids where k = 'bundle2'), 'Combo inativo', null, null, 50, true, 5,
  pg_temp.items(30, 20, null));
select pg_temp.expect((select active and archived_at is null from public.service_bundles where id = (select v from ids where k = 'bundle2')), 'combo salvo ativo volta do arquivo');
select public.catalog_save_bundle('00000000-0000-0000-0000-00000000151a', (select v from ids where k = 'bundle2'), 'Combo inativo', null, null, 50, false, 5,
  pg_temp.items(30, 20, null));
select public.catalog_set_flags('00000000-0000-0000-0000-00000000151a', 'bundle', (select v from ids where k = 'bundle'), true, null);
select public.catalog_set_flags('00000000-0000-0000-0000-00000000151a', 'bundle', (select v from ids where k = 'bundle'), false, null);
select pg_temp.expect((select (select (active, archived_at is not null) from public.service_bundles where id = (select v from ids where k = 'bundle2'))
  = (select (active, archived_at is not null) from public.service_bundles where id = (select v from ids where k = 'bundle'))), 'salvar inativo e desligar na lista: mesmo estado');
-- Itens do combo auditados (preço do item, item tirado, item posto); sem mudança, sem linha.
select pg_temp.expect((select count(*) from public.audit_logs where table_name = 'service_bundle_items' and operation = 'CATALOG_UPDATED'
  and new_data ->> 'allocated_price' = '25.00' and old_data ->> 'allocated_price' = '30.00') >= 1, 'item do combo: preço novo auditado (antes e depois)');
select pg_temp.expect((select count(*) from public.audit_logs where table_name = 'service_bundle_items' and operation = 'CATALOG_UPDATED' and record_id = (select v from ids where k = 'bundle2')) = 0, 'itens iguais: nenhuma linha de auditoria');
select public.catalog_save_bundle('00000000-0000-0000-0000-00000000151a', (select v from ids where k = 'bundle2'), 'Combo inativo', null, null, 50, false, 5,
  pg_temp.items(30, 10, 10));
select pg_temp.expect((select count(*) from public.audit_logs where table_name = 'service_bundle_items' and operation = 'CATALOG_CREATED' and record_id = (select v from ids where k = 'bundle2')) >= 3, 'itens postos auditados');
select public.catalog_save_bundle('00000000-0000-0000-0000-00000000151a', (select v from ids where k = 'bundle2'), 'Combo inativo', null, null, 40, false, 5,
  pg_temp.items(30, 10, null));
select pg_temp.expect((select count(*) from public.audit_logs where table_name = 'service_bundle_items' and operation = 'CATALOG_DELETED' and record_id = (select v from ids where k = 'bundle2')) = 1, 'item tirado do combo auditado');
-- Pacote: sessões e validade auditadas.
select public.catalog_save_package('00000000-0000-0000-0000-00000000151a', (select v from ids where k = 'pkgp'), 'Pacote ativo', null, 40, 5, 60, false, true, array[(select v from ids where k = 'svcp')]);
select pg_temp.expect((select old_data = '{"sessions": 2, "validity_days": 30}'::jsonb and new_data = '{"sessions": 5, "validity_days": 60}'::jsonb
  from public.audit_logs where table_name = 'service_packages' and record_id = (select v from ids where k = 'pkgp') and operation = 'CATALOG_UPDATED'), 'pacote: sessões e validade auditadas (só o que mudou)');
-- UPDATE direto pela API (sem passar pelas funções) também audita; arredondamento de 2 casas não gera linha.
update public.services set price = 91 where id = (select v from ids where k = 'svcx');
select pg_temp.expect((select count(*) from public.audit_logs where table_name = 'services' and operation = 'CATALOG_UPDATED' and new_data ->> 'price' = '91.00'
  and user_id = '00000000-0000-0000-0000-000000001510') = 1, 'UPDATE direto de preço audita em nome de quem fez');
update public.services set price = 91.004 where id = (select v from ids where k = 'svcx');
select pg_temp.expect((select count(*) from public.audit_logs where table_name = 'services' and operation = 'CATALOG_UPDATED' and new_data ->> 'price' in ('91.00', '91.004')) = 1, 'diferença abaixo de 2 casas não audita');
update public.services set price_type = 'from' where id = (select v from ids where k = 'svcx');
update public.services set price_type = 'fixed' where id = (select v from ids where k = 'svcx');
update public.services set name = 'Outro nome', description = 'x' where id = (select v from ids where k = 'svcx');
select pg_temp.expect((select count(*) from public.audit_logs where table_name = 'services' and record_id = (select v from ids where k = 'svcx') and operation = 'CATALOG_UPDATED') = 3, 'nome e descrição não geram auditoria (só o preço e o tipo de preço)');
-- Exclusão direta audita (gatilho AFTER DELETE), com o nome.
insert into ids select 'svcd', public.catalog_save_service('00000000-0000-0000-0000-00000000151a', null, null, 'Apagar direto', null, 12, 'fixed', 30, 0, 0, false, null, false, true, '{}');
delete from public.services where id = (select v from ids where k = 'svcd');
select pg_temp.expect((select old_data ->> 'name' = 'Apagar direto' and (old_data ->> 'price')::numeric = 12 from public.audit_logs where record_id = (select v from ids where k = 'svcd') and operation = 'CATALOG_DELETED'), 'DELETE direto audita com nome e preço');
-- Sinal fixo acima do preço: recusado (na criação e na edição); percentual não tem essa regra.
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_service('00000000-0000-0000-0000-00000000151a', null, null, 'X', null, 10, 'fixed', 30, 0, 0, false, null, false, true, '{}', '{"deposit_type": "fixed", "deposit_value": 11}')$q$) = '22023', 'sinal fixo acima do preço: recusado');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_save_service('00000000-0000-0000-0000-00000000151a', null, null, 'X', null, 10, 'fixed', 30, 0, 0, false, null, false, true, '{}', '{"deposit_type": "percent", "deposit_value": 50}')$q$) = 'ok', 'sinal percentual segue valendo');
insert into ids select 'svcs', public.catalog_save_service('00000000-0000-0000-0000-00000000151a', null, null, 'Com sinal', null, 50, 'fixed', 45, 0, 0, false, null, false, true, '{}', '{"deposit_type": "fixed", "deposit_value": 10}');
select pg_temp.expect(pg_temp.state_of(format($q$select public.catalog_save_service('00000000-0000-0000-0000-00000000151a', %L, null, 'Com sinal', null, 5, 'fixed', 45, 0, 0, false, null, false, true, '{}')$q$, (select v from ids where k = 'svcs'))) = '22023', 'baixar o preço abaixo do sinal fixo gravado: recusado');
-- Duplicar serviço leva as profissionais.
insert into ids select 'svc3', public.catalog_duplicate_item('00000000-0000-0000-0000-00000000151a', 'service', (select v from ids where k = 'svc'));
select pg_temp.expect((select count(*) from public.service_staff where service_id = (select v from ids where k = 'svc3')) = (select count(*) from public.service_staff where service_id = (select v from ids where k = 'svc')), 'cópia do serviço leva as profissionais');
-- Limites também na tabela (UPDATE direto não passa deles).
select pg_temp.expect(pg_temp.state_of(format($q$update public.services set name = repeat('a', 201) where id = %L$q$, (select v from ids where k = 'svc'))) = '23514', 'tabela: nome do serviço acima de 200');
select pg_temp.expect(pg_temp.state_of(format($q$update public.services set price = 100001 where id = %L$q$, (select v from ids where k = 'svc'))) = '23514', 'tabela: preço do serviço acima de 100000');
select pg_temp.expect(pg_temp.state_of(format($q$update public.products set description = repeat('a', 2001) where id = %L$q$, (select v from ids where k = 'prod'))) = '23514', 'tabela: descrição do produto acima de 2000');
select pg_temp.expect(pg_temp.state_of(format($q$update public.products set cost_price = 100001 where id = %L$q$, (select v from ids where k = 'prod'))) = '23514', 'tabela: custo do produto acima de 100000');
select pg_temp.expect(pg_temp.state_of(format($q$update public.service_packages set price = 100001 where id = %L$q$, (select v from ids where k = 'pkg'))) = '23514', 'tabela: preço do pacote acima de 100000');
select pg_temp.expect(pg_temp.state_of(format($q$update public.subscription_plans set name = repeat('a', 201) where id = %L$q$, (select v from ids where k = 'plan'))) = '23514', 'tabela: nome do plano acima de 200');
select pg_temp.expect(pg_temp.state_of(format($q$update public.service_bundles set price = 100001 where id = %L$q$, (select v from ids where k = 'bundle'))) = '23514', 'tabela: preço do combo acima de 100000');
select pg_temp.logout();

-- Recepção não consegue mexer nem gravar auditoria (nem por update direto, nem inserindo a linha à mão).
select pg_temp.login('00000000-0000-0000-0000-000000001511');
select pg_temp.expect(pg_temp.state_of(format($q$update public.services set price = 1 where id = %L$q$, (select v from ids where k = 'svcx'))) = 'ok'
  and (select price from public.services where id = (select v from ids where k = 'svcx')) = 91, 'recepção: update direto não altera o serviço (RLS)');
select pg_temp.expect(pg_temp.state_of($q$insert into public.audit_logs (org_id, user_id, table_name, operation) values
  ('00000000-0000-0000-0000-00000000151a', '00000000-0000-0000-0000-000000001511', 'services', 'CATALOG_UPDATED')$q$) = '42501', 'recepção: não grava linha de auditoria do catálogo à mão');
select pg_temp.logout();
select pg_temp.expect((select count(*) from public.audit_logs where user_id = '00000000-0000-0000-0000-000000001511' and table_name in ('services', 'products')) = 0, 'recepção: nenhuma auditoria do catálogo em nome dela');

-- Viewer com catalogo.manage grava (a auditoria é do gatilho, não da política de inserção), inclusive estoque.
insert into auth.users (id, email) values ('00000000-0000-0000-0000-000000001516', 'viewer@c151.local');
insert into public.user_roles (user_id, org_id, role) values ('00000000-0000-0000-0000-000000001516', '00000000-0000-0000-0000-00000000151a', 'viewer');
insert into public.org_role_permissions (org_id, role, permission, allowed) values ('00000000-0000-0000-0000-00000000151a', 'viewer', 'catalogo.manage', true);
select pg_temp.login('00000000-0000-0000-0000-000000001516');
select pg_temp.expect(pg_temp.state_of(format($q$select public.catalog_save_product('00000000-0000-0000-0000-00000000151a', %L, 'Creme', null, 44, 8, null, null, null, 'un', 0, 4, null, true, true)$q$, (select v from ids where k = 'prod'))) = 'ok', 'viewer com a liberação grava produto');
select pg_temp.expect(public.register_stock_entry_atomic('00000000-0000-0000-0000-00000000151a', (select v from ids where k = 'prod'), 'saida', 2, 'Venda') = 7, 'viewer com a liberação movimenta estoque');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_set_flags('00000000-0000-0000-0000-00000000151a', 'service', '00000000-0000-0000-0000-0000000151f2', false, null)$q$) = 'ok', 'viewer com a liberação liga e desliga');
select pg_temp.logout();
select pg_temp.expect((select count(*) from public.audit_logs where user_id = '00000000-0000-0000-0000-000000001516' and table_name = 'products' and new_data ? 'price') = 1, 'viewer: preço do produto auditado em nome dele');
select pg_temp.expect((select new_data = '{"stock_qty": 7, "quantity": 2}'::jsonb and old_data = '{"stock_qty": 9}'::jsonb from public.audit_logs
  where user_id = '00000000-0000-0000-0000-000000001516' and operation = 'STOCK_SAIDA'), 'viewer: movimento de estoque auditado (tipo, quantidade, antes e depois)');
select pg_temp.expect((select count(*) from public.audit_logs where operation like 'STOCK\_%' and record_id = (select v from ids where k = 'prod')) = 3, 'estoque: uma linha por movimento (sem duplicar)');

-- Apagar o estúdio inteiro (cascata) não quebra por causa dos gatilhos de auditoria.
insert into public.organizations (id, slug, name) values ('00000000-0000-0000-0000-00000000151c', 'c151-c', 'Catálogo 151 C');
insert into public.services (id, org_id, name, price, duration_minutes) values
  ('00000000-0000-0000-0000-0000000151c5', '00000000-0000-0000-0000-00000000151c', 'S1', 5, 30),
  ('00000000-0000-0000-0000-0000000151c6', '00000000-0000-0000-0000-00000000151c', 'S2', 5, 30);
insert into public.products (org_id, name, price) values ('00000000-0000-0000-0000-00000000151c', 'P', 5);
insert into public.service_bundles (id, org_id, name, price) values ('00000000-0000-0000-0000-0000000151c7', '00000000-0000-0000-0000-00000000151c', 'B', 10);
insert into public.service_bundle_items (org_id, bundle_id, service_id, position, quantity, original_price_snapshot, allocated_price) values
  ('00000000-0000-0000-0000-00000000151c', '00000000-0000-0000-0000-0000000151c7', '00000000-0000-0000-0000-0000000151c5', 0, 1, 5, 5),
  ('00000000-0000-0000-0000-00000000151c', '00000000-0000-0000-0000-0000000151c7', '00000000-0000-0000-0000-0000000151c6', 1, 1, 5, 5);
select pg_temp.expect((select message = 'ok' from pg_temp.msg_of($q$delete from public.organizations where id = '00000000-0000-0000-0000-00000000151c'$q$)), 'apagar estúdio em cascata com catálogo: sem erro de auditoria');

-- ─── Auditoria: a política segue a versão vigente (sem pares do catálogo) e recusa o que não é da lista ────────
select pg_temp.expect((select count(*) from public.audit_logs where operation = 'CATALOG_UPDATED' and new_data -> 'active' = 'true'::jsonb) >= 3, 'auditorias de reativar gravadas');
select pg_temp.login('00000000-0000-0000-0000-000000001510');
select pg_temp.expect(pg_temp.state_of($q$insert into public.audit_logs (org_id, user_id, table_name, operation) values
  ('00000000-0000-0000-0000-00000000151a', '00000000-0000-0000-0000-000000001510', 'services', 'QUALQUER_COISA')$q$) = '42501', 'par fora da lista: recusado');
select pg_temp.expect(pg_temp.state_of($q$insert into public.audit_logs (org_id, user_id, table_name, operation) values
  ('00000000-0000-0000-0000-00000000151a', '00000000-0000-0000-0000-000000001510', 'services', 'CATALOG_UPDATED')$q$) = '42501', 'linha de auditoria do catálogo à mão: recusada (só o gatilho grava)');
select pg_temp.expect(pg_temp.state_of($q$insert into public.audit_logs (org_id, user_id, table_name, operation) values
  ('00000000-0000-0000-0000-00000000151a', '00000000-0000-0000-0000-000000001510', 'appointments', 'APPOINTMENT_CLIENT_CHANGED')$q$) = 'ok', 'par da agenda continua aceito');
select pg_temp.expect(pg_temp.state_of($q$insert into public.audit_logs (org_id, user_id, table_name, operation) values
  ('00000000-0000-0000-0000-00000000151a', '00000000-0000-0000-0000-000000001510', 'clients', 'CLIENT_UPDATED')$q$) = 'ok', 'par do perfil da cliente continua aceito');
select pg_temp.logout();

rollback;
\o
\echo 'catálogo: leituras e ações em uma ida (151): ok'
