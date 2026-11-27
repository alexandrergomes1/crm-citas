-- Permissões pendentes (migrations 20261114130000 a 20261114130300). Para cada fechamento, recepção, profissional e
-- leitura (viewer) SEM a permissão: recusado (a API direta não devolve linha ou dá erro de permissão); COM a
-- permissão: ok. E as telas de outros módulos continuam funcionando sem ver Clientes/Catálogo (leitura por
-- internal_read, com a conferência da própria tela). Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000001590', 'dona@p159.local'),
  ('00000000-0000-0000-0000-000000001591', 'recep@p159.local'),
  ('00000000-0000-0000-0000-000000001592', 'prof@p159.local'),
  ('00000000-0000-0000-0000-000000001593', 'viewer@p159.local'),
  ('00000000-0000-0000-0000-000000001594', 'fin@p159.local'),
  ('00000000-0000-0000-0000-000000001595', 'donab@p159.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-00000000159a', 'p159-a', 'Permissões 159 A'),
  ('00000000-0000-0000-0000-00000000159b', 'p159-b', 'Permissões 159 B');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000001590', '00000000-0000-0000-0000-00000000159a', 'owner'),
  ('00000000-0000-0000-0000-000000001591', '00000000-0000-0000-0000-00000000159a', 'receptionist'),
  ('00000000-0000-0000-0000-000000001592', '00000000-0000-0000-0000-00000000159a', 'professional'),
  ('00000000-0000-0000-0000-000000001593', '00000000-0000-0000-0000-00000000159a', 'viewer'),
  ('00000000-0000-0000-0000-000000001594', '00000000-0000-0000-0000-00000000159a', 'finance'),
  ('00000000-0000-0000-0000-000000001595', '00000000-0000-0000-0000-00000000159b', 'owner');
insert into public.staff_members (id, org_id, user_id, name, role, position, active) values
  ('00000000-0000-0000-0000-0000000159a1', '00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-000000001592', 'Pro Um', 'professional', 1, true);
insert into public.clients (id, org_id, full_name, phone, status) values
  ('00000000-0000-0000-0000-0000000159c1', '00000000-0000-0000-0000-00000000159a', 'Cliente Um', '+34600000159', 'Ativo'),
  ('00000000-0000-0000-0000-0000000159c9', '00000000-0000-0000-0000-00000000159b', 'Cliente B', '+34600000999', 'Ativo');
insert into public.service_categories (id, org_id, name, position) values
  ('00000000-0000-0000-0000-0000000159d1', '00000000-0000-0000-0000-00000000159a', 'Rosto', 1);
insert into public.services (id, org_id, category_id, name, price, duration_minutes, commission_pct, cost_amount) values
  ('00000000-0000-0000-0000-0000000159e1', '00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-0000000159d1', 'Limpeza', 50, 60, 40, 7);
insert into public.service_staff (org_id, service_id, staff_id) values
  ('00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-0000000159e1', '00000000-0000-0000-0000-0000000159a1');
insert into public.products (id, org_id, name, price, cost_price, stock_qty) values
  ('00000000-0000-0000-0000-0000000159f1', '00000000-0000-0000-0000-00000000159a', 'Sérum', 30, 12, 2);
insert into public.stock_entries (org_id, product_id, type, quantity, reason) values
  ('00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-0000000159f1', 'entrada', 2, 'Inicial');
insert into public.service_packages (id, org_id, name, price, sessions) values
  ('00000000-0000-0000-0000-0000000159b1', '00000000-0000-0000-0000-00000000159a', 'Pacote', 200, 4);
insert into public.package_services (org_id, package_id, service_id, qty) values
  ('00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-0000000159b1', '00000000-0000-0000-0000-0000000159e1', 1);
insert into public.service_bundles (id, org_id, name, price) values
  ('00000000-0000-0000-0000-0000000159b2', '00000000-0000-0000-0000-00000000159a', 'Combo', 45);
insert into public.service_bundle_items (org_id, bundle_id, service_id, position, quantity, original_price_snapshot, allocated_price) values
  ('00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-0000000159b2', '00000000-0000-0000-0000-0000000159e1', 1, 1, 50, 45);
insert into public.subscription_plans (id, org_id, name, price) values
  ('00000000-0000-0000-0000-0000000159b3', '00000000-0000-0000-0000-00000000159a', 'Plano', 99);
insert into public.client_entitlements (id, org_id, client_id, package_id, package_name, total_sessions, used_sessions, status) values
  ('00000000-0000-0000-0000-0000000159b4', '00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-0000000159c1',
   '00000000-0000-0000-0000-0000000159b1', 'Pacote', 4, 1, 'active');

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
create function pg_temp.n(p_sql text) returns bigint language plpgsql as $$
declare v bigint;
begin
  execute p_sql into v;
  return v;
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
-- Liga/desliga uma liberação de um papel no estúdio A (como a tela Perfis e liberações faz).
create function pg_temp.perm(p_role text, p_permission text, p_allowed boolean) returns void language sql as $$
  insert into public.org_role_permissions (org_id, role, permission, allowed)
  values ('00000000-0000-0000-0000-00000000159a', p_role, p_permission, p_allowed)
  on conflict (org_id, role, permission) do update set allowed = excluded.allowed;
$$;
create function pg_temp.agenda(p_detail uuid default null) returns jsonb language sql as $$
  select public.agenda_screen('00000000-0000-0000-0000-00000000159a', false, '2035-03-01 00:00+00', '2035-03-02 00:00+00',
    '2035-03-02 00:00+00', '2035-03-03 00:00+00', false, false, array['Agendado'], '2035-01-01 00:00+00', false, p_detail)
$$;
create temp table t_ids (k text primary key, id uuid) on commit drop;
grant all on t_ids to authenticated;
grant execute on function pg_temp.expect(boolean, text), pg_temp.state_of(text), pg_temp.n(text), pg_temp.login(uuid),
  pg_temp.logout(), pg_temp.agenda(uuid) to authenticated;

-- Cada tabela fechada, contada pela API direta (o que a pessoa vê no estúdio A).
create function pg_temp.visible(p_table text) returns bigint language plpgsql as $$
declare v bigint;
begin
  execute format('select count(*) from public.%I where org_id = %L', p_table, '00000000-0000-0000-0000-00000000159a') into v;
  return v;
end $$;
grant execute on function pg_temp.visible(text) to authenticated;

-- Confere a mesma condição para várias pessoas (entra como cada uma).
create function pg_temp.each(p_uids uuid[], p_sql text, p_msg text) returns void language plpgsql as $$
declare u uuid; v boolean;
begin
  foreach u in array p_uids loop
    perform pg_temp.login(u);
    execute p_sql into v;
    perform pg_temp.expect(v, p_msg || ' (' || u || ')');
  end loop;
end $$;
grant execute on function pg_temp.each(uuid[], text, text) to authenticated;

-- ═══ (a) Clientes: ler exige clientes.view ═══════════════════════════════════════════════════════
-- Com a permissão (padrão dos três papéis): lê.
select pg_temp.each(array['00000000-0000-0000-0000-000000001591', '00000000-0000-0000-0000-000000001592', '00000000-0000-0000-0000-000000001593']::uuid[],
  'select pg_temp.visible(''clients'') = 1',
  'com clientes.view: lê a cliente');
select pg_temp.logout();
-- Sem a permissão: não lê nada pela API.
select pg_temp.perm(r, 'clientes.view', false) from unnest(array['receptionist', 'professional', 'viewer']) r;
select pg_temp.login('00000000-0000-0000-0000-000000001591');
select pg_temp.expect(pg_temp.visible('clients') = 0, 'recepção sem clientes.view: não lê clientes');
select pg_temp.login('00000000-0000-0000-0000-000000001592');
select pg_temp.expect(pg_temp.visible('clients') = 0, 'profissional sem clientes.view: não lê clientes');
select pg_temp.expect(public.client_profile('00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-0000000159c1', array['Concluído'], false) is null,
  'profissional sem clientes.view: perfil da cliente não existe para ela');
select pg_temp.login('00000000-0000-0000-0000-000000001593');
select pg_temp.expect(pg_temp.visible('clients') = 0, 'viewer sem clientes.view: não lê clientes');
-- Outro estúdio nunca.
select pg_temp.login('00000000-0000-0000-0000-000000001595');
select pg_temp.expect(pg_temp.visible('clients') = 0, 'dona do B: não lê clientes do A');

-- As telas de outros módulos continuam (recepção sem clientes.view, com agenda e comanda).
select pg_temp.login('00000000-0000-0000-0000-000000001591');
insert into t_ids values ('appt', public.create_appointment_atomic('00000000-0000-0000-0000-00000000159a',
  '00000000-0000-0000-0000-0000000159c1', '00000000-0000-0000-0000-0000000159a1', '2035-03-01 10:00+00', '2035-03-01 11:00+00', 60,
  'Agendado', 'MANUAL', null, null, 50,
  jsonb_build_array(jsonb_build_object('service_id', '00000000-0000-0000-0000-0000000159e1', 'service_name', 'Limpeza', 'price', 50)), false));
select pg_temp.expect((select id from t_ids where k = 'appt') is not null, 'agenda: recepção sem clientes.view cria agendamento');
select pg_temp.expect(pg_temp.agenda() -> 'appointments' -> 0 -> 'clients' ->> 'phone' = '+34600000159',
  'agenda: telefone da cliente no quadro sem clientes.view');
select pg_temp.expect(pg_temp.agenda((select id from t_ids where k = 'appt')) -> 'detail' -> 'appointment' -> 'clients' ->> 'full_name' = 'Cliente Um',
  'agenda: cliente no detalhe do agendamento sem clientes.view');
select pg_temp.expect(public.checkout_walkin_screen('00000000-0000-0000-0000-00000000159a', null) -> 'clients' -> 0 ->> 'name' = 'Cliente Um',
  'comanda: venda avulsa lista a cliente sem clientes.view');
select pg_temp.expect(pg_temp.state_of($q$select public.messages_history_screen('00000000-0000-0000-0000-00000000159a')$q$) = 'ok',
  'mensagens: histórico abre sem clientes.view');
-- A trava da cliente por função pede agenda.manage.
select pg_temp.login('00000000-0000-0000-0000-000000001593');
select pg_temp.expect(pg_temp.state_of($q$select public.agenda_lock_client('00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-0000000159c1')$q$) = '42501',
  'viewer: travar cliente recusado');
select pg_temp.logout();
select pg_temp.perm(r, 'clientes.view', true) from unnest(array['receptionist', 'professional', 'viewer']) r;

-- ═══ (b) Movimentos do pacote: ninguém grava direto; devolver sessão só com comanda.operate ════════
create function pg_temp.entry() returns text language sql as $$
  select pg_temp.state_of($q$insert into public.client_entitlement_entries (org_id, entitlement_id, client_id, action, sessions_delta,
    sessions_before, sessions_after) values ('00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-0000000159b4',
    '00000000-0000-0000-0000-0000000159c1', 'adjust', 1, 1, 2)$q$)
$$;
create function pg_temp.restore() returns text language sql as $$
  select pg_temp.state_of($q$select public.restore_entitlement_session_atomic('00000000-0000-0000-0000-00000000159a',
    '00000000-0000-0000-0000-0000000159b4', 'Devolvida')$q$)
$$;
grant execute on function pg_temp.entry(), pg_temp.restore() to authenticated;
-- Linha forjada pela API: recusada para todos, inclusive quem opera a comanda e a dona.
select pg_temp.each(array['00000000-0000-0000-0000-000000001591', '00000000-0000-0000-0000-000000001592',
                          '00000000-0000-0000-0000-000000001593', '00000000-0000-0000-0000-000000001590',
                          '00000000-0000-0000-0000-000000001595']::uuid[],
  $s$select pg_temp.entry() = '42501'$s$, 'movimento do pacote forjado pela API recusado');
select pg_temp.logout();
-- Devolver sessão (função): sem comanda.operate, recusado.
select pg_temp.perm('receptionist', 'comanda.operate', false);
select pg_temp.each(array['00000000-0000-0000-0000-000000001591', '00000000-0000-0000-0000-000000001592',
                          '00000000-0000-0000-0000-000000001593', '00000000-0000-0000-0000-000000001595']::uuid[],
  $s$select pg_temp.restore() = '42501'$s$, 'sem comanda.operate: devolver sessão recusado');
select pg_temp.logout();
select pg_temp.expect((select used_sessions from public.client_entitlements where id = '00000000-0000-0000-0000-0000000159b4') = 1,
  'recusas não mexeram no pacote');
-- Com comanda.operate: devolve, e o movimento fica em nome de quem devolveu.
select pg_temp.perm('receptionist', 'comanda.operate', true);
select pg_temp.login('00000000-0000-0000-0000-000000001591');
select pg_temp.expect(pg_temp.restore() = 'ok', 'recepção com comanda.operate: devolve sessão');
select pg_temp.logout();
select pg_temp.expect((select count(*) from public.client_entitlement_entries
  where entitlement_id = '00000000-0000-0000-0000-0000000159b4' and action = 'restore'
    and created_by = '00000000-0000-0000-0000-000000001591') = 1, 'movimento gravado pela função, em nome da recepção');

-- ═══ (3) Vendas: ler exige comanda.operate ou financeiro.view ═══════════════════════════════════
insert into public.sales (id, org_id, client_id, client_name, status, subtotal, total, appointment_id) values
  ('00000000-0000-0000-0000-0000000159f9', '00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-0000000159c1',
   'Cliente Um', 'draft', 50, 50, (select id from t_ids where k = 'appt'));
-- Profissional e viewer (sem comanda nem financeiro) e outro estúdio: não leem vendas pela API.
select pg_temp.each(array['00000000-0000-0000-0000-000000001592', '00000000-0000-0000-0000-000000001593',
                          '00000000-0000-0000-0000-000000001595']::uuid[],
  $s$select pg_temp.visible('sales') = 0$s$, 'sem comanda.operate/financeiro.view: não lê vendas');
-- Recepção (comanda.operate) e financeiro (financeiro.view): leem.
select pg_temp.each(array['00000000-0000-0000-0000-000000001591', '00000000-0000-0000-0000-000000001594']::uuid[],
  $s$select pg_temp.visible('sales') = 1$s$, 'com comanda.operate/financeiro.view: lê vendas');
select pg_temp.logout();
select pg_temp.perm('receptionist', 'comanda.operate', false);
select pg_temp.login('00000000-0000-0000-0000-000000001591');
select pg_temp.expect(pg_temp.visible('sales') = 0, 'recepção sem comanda.operate: não lê vendas');
select pg_temp.logout();
select pg_temp.perm('receptionist', 'comanda.operate', true);
-- ...mas o perfil e a Agenda continuam mostrando a venda (profissional: clientes.view e a própria agenda).
select pg_temp.login('00000000-0000-0000-0000-000000001592');
select pg_temp.expect(jsonb_array_length(public.client_sales_history('00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-0000000159c1')) = 1,
  'perfil: histórico de compras sem comanda/financeiro');
select pg_temp.expect(public.agenda_appointment_detail('00000000-0000-0000-0000-00000000159a', (select id from t_ids where k = 'appt'), true)
  -> 'sale' ->> 'id' = '00000000-0000-0000-0000-0000000159f9', 'agenda: venda no detalhe do agendamento sem comanda/financeiro');
select pg_temp.logout();
-- Itens e pagamentos da venda: mesma regra de sales.
insert into public.sale_items (org_id, sale_id, item_type, item_id, name, unit_price, quantity, total_price) values
  ('00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-0000000159f9', 'product', '00000000-0000-0000-0000-0000000159f1', 'Sérum', 30, 1, 30);
insert into public.sale_payments (org_id, sale_id, method, amount) values
  ('00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-0000000159f9', 'CASH', 30);
select pg_temp.each(array['00000000-0000-0000-0000-000000001592', '00000000-0000-0000-0000-000000001593',
                          '00000000-0000-0000-0000-000000001595']::uuid[],
  $s$select pg_temp.visible('sale_items') = 0 and pg_temp.visible('sale_payments') = 0$s$,
  'sem comanda.operate/financeiro.view: não lê itens nem pagamentos da venda');
select pg_temp.each(array['00000000-0000-0000-0000-000000001591', '00000000-0000-0000-0000-000000001594']::uuid[],
  $s$select pg_temp.visible('sale_items') = 1 and pg_temp.visible('sale_payments') = 1$s$,
  'com comanda.operate/financeiro.view: lê itens e pagamentos da venda');
select pg_temp.logout();
-- Perfil e Agenda (profissional) continuam com itens e forma de pagamento.
select pg_temp.login('00000000-0000-0000-0000-000000001592');
select pg_temp.expect(public.client_sales_history('00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-0000000159c1') -> 0 -> 'sale_items' -> 0 ->> 'name' = 'Sérum'
  and public.client_sales_history('00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-0000000159c1') -> 0 -> 'sale_payments' -> 0 ->> 'method' = 'CASH',
  'perfil: itens e pagamento da compra sem comanda/financeiro');
select pg_temp.expect(public.agenda_appointment_detail('00000000-0000-0000-0000-00000000159a', (select id from t_ids where k = 'appt'), true)
  -> 'sale' -> 'sale_payments' -> 0 ->> 'method' = 'CASH', 'agenda: pagamento no detalhe sem comanda/financeiro');
select pg_temp.logout();
-- Profissional com catalogo.manage (sem ver vendas): produto vendido só arquiva (o histórico é lido por internal_read).
select pg_temp.perm('professional', 'catalogo.manage', true);
select pg_temp.login('00000000-0000-0000-0000-000000001592');
select pg_temp.expect(public.catalog_delete_item('00000000-0000-0000-0000-00000000159a', 'product', '00000000-0000-0000-0000-0000000159f1') = 'archived',
  'catálogo: produto com venda só arquiva para quem não vê vendas');
select pg_temp.logout();
select pg_temp.perm('professional', 'catalogo.manage', false);
update public.products set active = true where id = '00000000-0000-0000-0000-0000000159f1';
select pg_temp.expect(not has_table_privilege('authenticated', 'public.client_entitlement_entries', 'REFERENCES')
  and not has_table_privilege('authenticated', 'public.client_entitlement_entries', 'TRIGGER')
  and not has_table_privilege('authenticated', 'public.client_entitlement_entries', 'INSERT'),
  'movimentos do pacote: authenticated só lê');

select pg_temp.perm('viewer', 'clientes.view', false);
select pg_temp.login('00000000-0000-0000-0000-000000001593');
select pg_temp.expect(pg_temp.state_of($q$select public.client_sales_history('00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-0000000159c1')$q$) = '42501',
  'viewer sem clientes.view: histórico de compras recusado');
select pg_temp.login('00000000-0000-0000-0000-000000001595');
select pg_temp.expect(pg_temp.state_of($q$select public.client_sales_history('00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-0000000159c1')$q$) = '42501',
  'dona do B: histórico do A recusado');
select pg_temp.logout();
select pg_temp.perm('viewer', 'clientes.view', true);

-- ═══ (6) Sem a política "travar na agenda" ════════════════════════════════════════════════════
select pg_temp.expect(not exists (select 1 from pg_policies where tablename = 'clients' and policyname = 'clients: travar na agenda'),
  'política antiga de trava removida');
select pg_temp.expect((select proconfig from pg_proc where oid = 'public.list_service_bundles_catalog(uuid, boolean)'::regprocedure) = array['search_path=""'],
  'list_service_bundles_catalog com search_path vazio');

-- ═══ (5) Campanhas: contagem de consentimento em uma passada, mesmos números da regra por cliente ═════
insert into public.clients (id, org_id, full_name, status)
select ('00000000-0000-0000-0000-0000001590' || lpad(g::text, 2, '0'))::uuid, '00000000-0000-0000-0000-00000000159a', 'Mkt ' || g, 'Ativo'
from generate_series(10, 21) g;
insert into public.client_marketing_preferences (org_id, client_id, channel, marketing_allowed, opted_out_at) values
  ('00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-000000159010', 'whatsapp_manual', true, null),
  ('00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-000000159011', 'whatsapp_provider', true, null),
  ('00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-000000159012', 'whatsapp_manual', true, null),
  ('00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-000000159012', 'whatsapp_provider', false, now()),
  ('00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-000000159013', 'email_provider', true, null),
  ('00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-000000159014', 'email_provider', false, null),
  ('00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-000000159015', 'sms_provider', true, null),
  ('00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-000000159016', 'internal_note', true, null),
  ('00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-000000159017', 'whatsapp_manual', false, null),
  ('00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-000000159017', 'email_provider', true, null);
update public.clients set blocked_at = now() where id = '00000000-0000-0000-0000-000000159018';
update public.clients set status = 'Inativo' where id = '00000000-0000-0000-0000-000000159019';
create temp table t_mkt on commit drop as
select
  count(*) filter (where not public.marketing_authorized(c)) as total,
  count(*) filter (where public.marketing_channel_state(c.org_id, c.id, 'whatsapp_manual') <> 'authorized') as wa,
  count(*) filter (where public.marketing_channel_state(c.org_id, c.id, 'email_provider') <> 'authorized') as em,
  count(*) filter (where public.marketing_channel_state(c.org_id, c.id, 'sms_provider') <> 'authorized') as sms
from public.clients c
where c.org_id = '00000000-0000-0000-0000-00000000159a' and c.status = 'Ativo' and c.merged_into is null and c.blocked_at is null;
grant select on t_mkt to authenticated;
select pg_temp.login('00000000-0000-0000-0000-000000001590');
select pg_temp.expect((select (public.marketing_campaigns_screen('00000000-0000-0000-0000-00000000159a', '[]'::jsonb) ->> 'unauthorized_count')::bigint = total from t_mkt),
  'campanhas: sem autorização igual à regra por cliente');
select pg_temp.expect((select public.marketing_campaigns_screen('00000000-0000-0000-0000-00000000159a', '[]'::jsonb) -> 'unauthorized_by_channel'
  = jsonb_build_object('whatsapp_manual', wa, 'email_provider', em, 'sms_provider', sms) from t_mkt),
  'campanhas: por meio igual à regra por cliente');
select pg_temp.expect((select total > 0 and wa <> sms and total <> wa from t_mkt), 'cenário de campanhas tem casos diferentes por meio');
select pg_temp.logout();
-- Política de gravação das preferências: mesmos papéis (recepção grava, profissional não).
select pg_temp.login('00000000-0000-0000-0000-000000001592');
select pg_temp.expect(pg_temp.state_of($q$insert into public.client_marketing_preferences (org_id, client_id, channel, marketing_allowed)
  values ('00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-000000159020', 'email_provider', true)$q$) = '42501',
  'profissional não grava preferência de marketing');
select pg_temp.login('00000000-0000-0000-0000-000000001591');
select pg_temp.expect(pg_temp.state_of($q$insert into public.client_marketing_preferences (org_id, client_id, channel, marketing_allowed)
  values ('00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-000000159020', 'email_provider', true)$q$) = 'ok',
  'recepção grava preferência de marketing');
select pg_temp.logout();

-- ═══ (c) Catálogo: ler exige catalogo.view; comissão e custos só por função ═════════════════════
create function pg_temp.catalog_count() returns bigint language sql as $$
  select pg_temp.visible('services') + pg_temp.visible('service_categories') + pg_temp.visible('products')
       + pg_temp.visible('service_packages') + pg_temp.visible('package_services') + pg_temp.visible('service_bundles')
       + pg_temp.visible('service_bundle_items') + pg_temp.visible('subscription_plans') + pg_temp.visible('stock_entries')
       + pg_temp.visible('service_staff')
$$;
grant execute on function pg_temp.catalog_count() to authenticated;
-- Com catalogo.view (padrão): lê as dez tabelas (uma linha em cada).
select pg_temp.each(array['00000000-0000-0000-0000-000000001591', '00000000-0000-0000-0000-000000001592', '00000000-0000-0000-0000-000000001593']::uuid[],
  'select pg_temp.catalog_count() = 10',
  'com catalogo.view: lê o catálogo');
-- Comissão e custos: nem quem tem catalogo.view lê direto (nem a dona: só por função).
select pg_temp.each(array['00000000-0000-0000-0000-000000001591', '00000000-0000-0000-0000-000000001592', '00000000-0000-0000-0000-000000001593', '00000000-0000-0000-0000-000000001590']::uuid[],
  'select (pg_temp.state_of(''select commission_pct from public.services'') = ''42501''
     and pg_temp.state_of(''select cost_amount from public.services'') = ''42501''
     and pg_temp.state_of(''select cost_price from public.products'') = ''42501''
     and pg_temp.state_of(''select * from public.services'') = ''42501''
     and pg_temp.state_of(''select id, name, price from public.services'') = ''ok'')',
  'comissão e custos fechados na leitura direta');
-- Pela tela do Catálogo: recepção, profissional e viewer (sem gestão nem financeiro) recebem null; gerente/financeiro, o valor.
select pg_temp.each(array['00000000-0000-0000-0000-000000001591', '00000000-0000-0000-0000-000000001592', '00000000-0000-0000-0000-000000001593']::uuid[],
  'select (public.catalog_screen(''00000000-0000-0000-0000-00000000159a'') -> ''services'' -> 0 -> ''commission_pct'' = ''null''::jsonb
     and public.catalog_screen(''00000000-0000-0000-0000-00000000159a'') -> ''products'' -> 0 -> ''cost_price'' = ''null''::jsonb
     and (public.catalog_screen(''00000000-0000-0000-0000-00000000159a'') -> ''services'' -> 0 ->> ''price'')::numeric = 50)',
  'catálogo sem gestão/financeiro: comissão e custo escondidos');
select pg_temp.each(array['00000000-0000-0000-0000-000000001590', '00000000-0000-0000-0000-000000001594']::uuid[],
  'select ((public.catalog_screen(''00000000-0000-0000-0000-00000000159a'') -> ''services'' -> 0 ->> ''commission_pct'')::numeric = 40
     and (public.catalog_screen(''00000000-0000-0000-0000-00000000159a'') -> ''products'' -> 0 ->> ''cost_price'')::numeric = 12)',
  'catálogo com gestão/financeiro: comissão e custo');
select pg_temp.logout();
-- Recepção com catalogo.manage liberado: vê comissão e custo.
select pg_temp.perm('receptionist', 'catalogo.manage', true);
select pg_temp.login('00000000-0000-0000-0000-000000001591');
select pg_temp.expect((public.catalog_screen('00000000-0000-0000-0000-00000000159a') -> 'services' -> 0 ->> 'commission_pct')::numeric = 40,
  'recepção com catalogo.manage: vê a comissão');
select pg_temp.logout();
select pg_temp.perm('receptionist', 'catalogo.manage', false);

-- Sem catalogo.view: nada pela API, tela do Catálogo recusada.
select pg_temp.perm(r, 'catalogo.view', false) from unnest(array['receptionist', 'professional', 'viewer']) r;
select pg_temp.login('00000000-0000-0000-0000-000000001591');
select pg_temp.expect(pg_temp.catalog_count() = 0, 'recepção sem catalogo.view: não lê o catálogo');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_screen('00000000-0000-0000-0000-00000000159a')$q$) = '42501',
  'recepção sem catalogo.view: tela do Catálogo recusada');
-- ...mas a agenda e a comanda continuam com os serviços.
select pg_temp.expect(jsonb_array_length(pg_temp.agenda() -> 'services') = 1, 'agenda: serviços para agendar sem catalogo.view');
select pg_temp.expect(jsonb_array_length(pg_temp.agenda() -> 'bundles') = 1, 'agenda: combos para agendar sem catalogo.view');
select pg_temp.expect(jsonb_array_length(public.checkout_catalog('00000000-0000-0000-0000-00000000159a') -> 'products') = 1,
  'comanda: produtos para vender sem catalogo.view');
select pg_temp.login('00000000-0000-0000-0000-000000001592');
select pg_temp.expect(pg_temp.catalog_count() = 0, 'profissional sem catalogo.view: não lê o catálogo');
select pg_temp.expect(public.client_profile('00000000-0000-0000-0000-00000000159a', '00000000-0000-0000-0000-0000000159c1', array['Concluído'], false) is not null,
  'perfil da cliente abre sem catalogo.view');
select pg_temp.login('00000000-0000-0000-0000-000000001593');
select pg_temp.expect(pg_temp.catalog_count() = 0, 'viewer sem catalogo.view: não lê o catálogo');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_screen('00000000-0000-0000-0000-00000000159a')$q$) = '42501',
  'viewer sem catalogo.view: tela do Catálogo recusada');
select pg_temp.expect(jsonb_array_length(public.checkout_catalog('00000000-0000-0000-0000-00000000159a') -> 'services') = 0,
  'viewer sem catalogo.view nem comanda: catálogo da comanda vazio');
select pg_temp.logout();
-- Sem catálogo nem agenda: as listas de serviços e combos da agenda vêm vazias.
select pg_temp.perm('viewer', 'agenda.view_all', false);
select pg_temp.login('00000000-0000-0000-0000-000000001593');
select pg_temp.expect(jsonb_array_length(pg_temp.agenda() -> 'services') = 0, 'sem agenda nem catálogo: sem serviços na agenda');
select pg_temp.expect((select count(*) from public.list_service_bundles_catalog('00000000-0000-0000-0000-00000000159a')) = 0,
  'sem agenda nem catálogo: sem combos');
select pg_temp.login('00000000-0000-0000-0000-000000001595');
select pg_temp.expect(pg_temp.catalog_count() = 0, 'dona do B: não lê o catálogo do A');
select pg_temp.expect(pg_temp.state_of($q$select public.catalog_screen('00000000-0000-0000-0000-00000000159a')$q$) = '42501',
  'dona do B: tela do Catálogo do A recusada');
select pg_temp.logout();

-- ═══ internal_read: só para as funções do banco ═══════════════════════════════════════════════════
select pg_temp.expect(not has_schema_privilege('anon', 'internal_read', 'usage'), 'anon sem acesso ao schema internal_read');
select pg_temp.expect(not exists (
  select 1 from information_schema.role_table_grants
  where table_schema = 'internal_read' and grantee in ('anon', 'authenticated', 'PUBLIC') and privilege_type <> 'SELECT'),
  'internal_read: ninguém da API grava pelas visões');
select pg_temp.expect(not has_function_privilege('anon', 'public.agenda_lock_client(uuid, uuid)', 'execute'), 'anon sem trava de cliente');
-- A visão vê o mesmo que a RLS via antes: só os estúdios da pessoa.
select pg_temp.login('00000000-0000-0000-0000-000000001595');
select pg_temp.expect((select count(*) from internal_read.clients) = 1, 'internal_read: dona do B vê só a cliente do B');
select pg_temp.logout();

rollback;
\o
\echo 'permissões pendentes: clientes, movimentos do pacote, catálogo e custos (159): ok'
