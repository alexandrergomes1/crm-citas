-- Financeiro, Checkout e Fidelidade (porte, orçamento de chamadas): leituras e gravações das migrations
-- 20261114050000, 20261114050100 e 20261114050200. Isolamento entre estúdios, anônimo sem execução, papéis
-- (recepção, financeiro, profissional), caminhos felizes, idempotência (pagar conta, cobrar, estornar), caixa
-- abrir/fechar, auditoria gravada por gatilho e não forjável, limites no banco. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000001530', 'dona@f153.local'),
  ('00000000-0000-0000-0000-000000001531', 'recep@f153.local'),
  ('00000000-0000-0000-0000-000000001532', 'donab@f153.local'),
  ('00000000-0000-0000-0000-000000001534', 'prof@f153.local'),
  ('00000000-0000-0000-0000-000000001535', 'fin@f153.local'),
  ('00000000-0000-0000-0000-000000001536', 'leitura@f153.local');
insert into public.organizations (id, slug, name, timezone) values
  ('00000000-0000-0000-0000-00000000153a', 'f153-a', 'Financeiro 153 A', 'Europe/Madrid'),
  ('00000000-0000-0000-0000-00000000153b', 'f153-b', 'Financeiro 153 B', 'Europe/Madrid');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000001530', '00000000-0000-0000-0000-00000000153a', 'owner'),
  ('00000000-0000-0000-0000-000000001531', '00000000-0000-0000-0000-00000000153a', 'receptionist'),
  ('00000000-0000-0000-0000-000000001532', '00000000-0000-0000-0000-00000000153b', 'owner'),
  ('00000000-0000-0000-0000-000000001534', '00000000-0000-0000-0000-00000000153a', 'professional'),
  ('00000000-0000-0000-0000-000000001535', '00000000-0000-0000-0000-00000000153a', 'finance'),
  ('00000000-0000-0000-0000-000000001536', '00000000-0000-0000-0000-00000000153a', 'viewer');
-- Perfil "só vê o financeiro": visualizadora com financeiro.view liberado (sem comanda.operate nem status das fichas).
insert into public.org_role_permissions (org_id, role, permission, allowed) values
  ('00000000-0000-0000-0000-00000000153a', 'viewer', 'financeiro.view', true);
insert into public.profiles (user_id, org_id, full_name) values
  ('00000000-0000-0000-0000-000000001530', '00000000-0000-0000-0000-00000000153a', 'Dona Ana')
on conflict (user_id, org_id) do update set full_name = excluded.full_name;

insert into public.staff_members (id, org_id, name, display_name, commission_pct) values
  ('00000000-0000-0000-0000-0000000153a1', '00000000-0000-0000-0000-00000000153a', 'Karenn Guimarães', 'Karenn', 10),
  ('00000000-0000-0000-0000-0000000153b1', '00000000-0000-0000-0000-00000000153b', 'Profissional B', null, 50);
insert into public.services (id, org_id, name, price, duration_minutes, retouch_included_days) values
  ('00000000-0000-0000-0000-0000000153d1', '00000000-0000-0000-0000-00000000153a', 'Limpeza de pele', 100, 60, 30),
  ('00000000-0000-0000-0000-0000000153d9', '00000000-0000-0000-0000-00000000153b', 'Serviço B', 40, 60, null);
insert into public.clients (id, org_id, full_name, phone, balance, loyalty_points) values
  ('00000000-0000-0000-0000-0000000153c1', '00000000-0000-0000-0000-00000000153a', 'María Núñez', '+34600000001', 0, 0),
  ('00000000-0000-0000-0000-0000000153c9', '00000000-0000-0000-0000-00000000153b', 'Cliente B', '+34600000009', 25, 40);
insert into public.payables (id, org_id, description, vendor, category, value, due_date, status, recurrence) values
  ('00000000-0000-0000-0000-0000000153f1', '00000000-0000-0000-0000-00000000153a', 'Aluguel', 'Imobiliária', 'aluguel', 650,
   current_date - 3, 'pending', 'monthly'),
  ('00000000-0000-0000-0000-0000000153f9', '00000000-0000-0000-0000-00000000153b', 'Conta B', null, null, 10, current_date - 1, 'pending', null);
insert into public.gift_cards (id, org_id, code, initial_value, remaining_value) values
  ('00000000-0000-0000-0000-0000000153e9', '00000000-0000-0000-0000-00000000153b', 'VALE-B', 50, 50);
insert into public.transactions (org_id, type, description, value, date, method, status) values
  ('00000000-0000-0000-0000-00000000153b', 'income', 'Venda B', 999, current_date, 'CASH', 'completed');
-- Atendimento Concluído do A pronto para cobrar (a inserção só aceita status inicial de agenda).
insert into public.appointments (id, org_id, client_id, client_name, staff_id, start_at, end_at, duration_minutes, status, source, total) values
  ('00000000-0000-0000-0000-0000000153aa', '00000000-0000-0000-0000-00000000153a', '00000000-0000-0000-0000-0000000153c1',
   'María Núñez', '00000000-0000-0000-0000-0000000153a1', now() - interval '2 hours', now() - interval '1 hour', 60, 'Agendado', 'MANUAL', 100);
set local session_replication_role = replica;
insert into public.appointment_items (org_id, appointment_id, type, ref_id, name, price, qty) values
  ('00000000-0000-0000-0000-00000000153a', '00000000-0000-0000-0000-0000000153aa', 'service', '00000000-0000-0000-0000-0000000153d1', 'Limpeza de pele', 100, 1);
set local session_replication_role = origin;
-- Atendimentos extra do A: com ficha obrigatória sem preencher (ab), para a recepção cobrar (ac) e para pagar em
-- duas vezes (ad).
insert into public.anamnese_templates (id, org_id, title, questions) values
  ('00000000-0000-0000-0000-0000000153f5', '00000000-0000-0000-0000-00000000153a', 'Ficha facial', '[{"id":"q1","label":"Alergias?","type":"text"}]');
insert into public.services (id, org_id, name, price, duration_minutes, requires_anamnese, anamnese_template_id) values
  ('00000000-0000-0000-0000-0000000153d2', '00000000-0000-0000-0000-00000000153a', 'Peeling', 120, 60, true, '00000000-0000-0000-0000-0000000153f5');
insert into public.appointments (id, org_id, client_id, client_name, staff_id, start_at, end_at, duration_minutes, status, source, total)
select ('00000000-0000-0000-0000-0000000153' || k)::uuid, '00000000-0000-0000-0000-00000000153a', '00000000-0000-0000-0000-0000000153c1',
       'María Núñez', '00000000-0000-0000-0000-0000000153a1', now() - interval '3 hours', now() - interval '2 hours', 60, 'Agendado', 'MANUAL', 100
from unnest(array['ab', 'ac', 'ad']) k;
set local session_replication_role = replica;
insert into public.appointment_items (org_id, appointment_id, type, ref_id, name, price, qty, requires_anamnese, anamnese_template_id) values
  ('00000000-0000-0000-0000-00000000153a', '00000000-0000-0000-0000-0000000153ab', 'service', '00000000-0000-0000-0000-0000000153d2', 'Peeling', 120, 1, true, '00000000-0000-0000-0000-0000000153f5'),
  ('00000000-0000-0000-0000-00000000153a', '00000000-0000-0000-0000-0000000153ac', 'service', '00000000-0000-0000-0000-0000000153d1', 'Limpeza de pele', 100, 1, false, null),
  ('00000000-0000-0000-0000-00000000153a', '00000000-0000-0000-0000-0000000153ad', 'service', '00000000-0000-0000-0000-0000000153d1', 'Limpeza de pele', 100, 1, false, null);
set local session_replication_role = origin;
update public.appointments set status = 'Concluído'
where id in ('00000000-0000-0000-0000-0000000153aa', '00000000-0000-0000-0000-0000000153ab', '00000000-0000-0000-0000-0000000153ac', '00000000-0000-0000-0000-0000000153ad');

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
create function pg_temp.anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  perform set_config('role', 'anon', true);
end $$;
create function pg_temp.logout() returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);
end $$;
create function pg_temp.audits(p_op text) returns bigint language sql as $$
  select count(*) from public.audit_logs where operation = p_op and org_id = '00000000-0000-0000-0000-00000000153a'
$$;
create temp table t_out (k text primary key, r jsonb) on commit drop;
grant all on t_out to authenticated, anon;
grant execute on function pg_temp.expect(boolean, text), pg_temp.state_of(text), pg_temp.login(uuid), pg_temp.logout(),
  pg_temp.anon(), pg_temp.audits(text) to anon, authenticated;

\set A '''00000000-0000-0000-0000-00000000153a'''
\set B '''00000000-0000-0000-0000-00000000153b'''
-- "Hoje" do estúdio (o caixa adota os lançamentos do dia no fuso do estúdio, não no do servidor).
\set HOJE '(now() at time zone ''Europe/Madrid'')::date'

-- ─── Anônimo: nenhuma função executa ───────────────────────────────────────────────────────────────
select pg_temp.anon();
select pg_temp.expect(pg_temp.state_of(q) = '42501', 'anônimo não executa: ' || q) from unnest(array[
  $q$select public.finance_overview_screen('00000000-0000-0000-0000-00000000153a', current_date, current_date, current_date, current_date)$q$,
  $q$select public.finance_comandas_screen('00000000-0000-0000-0000-00000000153a', '2026-11')$q$,
  $q$select public.finance_caixa_screen('00000000-0000-0000-0000-00000000153a', null)$q$,
  $q$select public.finance_payables_screen('00000000-0000-0000-0000-00000000153a')$q$,
  $q$select public.checkout_screen('00000000-0000-0000-0000-00000000153a', '00000000-0000-0000-0000-0000000153aa')$q$,
  $q$select public.finance_create_entry('00000000-0000-0000-0000-00000000153a', 'income', 'x', 1, current_date, null, null, null, gen_random_uuid())$q$,
  $q$select public.finance_record_export('00000000-0000-0000-0000-00000000153a', 'saldos', 1, null)$q$,
  $q$select public.loyalty_screen('00000000-0000-0000-0000-00000000153a')$q$
]) q;
select pg_temp.logout();
select pg_temp.expect(not has_function_privilege('anon', p.oid, 'execute'), 'anon sem execução: ' || p.proname)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in (
  'finance_org_timezone', 'finance_shell_counts', 'finance_require', 'finance_overview_screen', 'finance_comandas_screen',
  'finance_caixa_screen', 'finance_commissions_screen', 'finance_payables_screen', 'finance_reports_screen',
  'finance_balances_screen', 'finance_gift_cards_screen', 'checkout_catalog', 'checkout_screen', 'checkout_walkin_screen',
  'loyalty_screen', 'payment_request_context', 'finance_create_entry', 'finance_pay_payable', 'finance_save_payable',
  'finance_delete_payable', 'finance_set_payable_invoice', 'finance_payable_invoice_path', 'checkout_confirm',
  'finance_record_export', 'finance_audit_row', 'finance_cash_totals', 'finance_request_existing', 'checkout_request_done', 'auth_orgs_with_permission',
  'auth_orgs_with_roles');
select pg_temp.expect(not has_function_privilege('authenticated', 'public.finance_audit_row()', 'execute'), 'gatilho de auditoria não é chamável');
select pg_temp.expect((select bool_and(not p.prosecdef) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname in ('finance_overview_screen', 'finance_comandas_screen', 'finance_caixa_screen',
    'finance_commissions_screen', 'finance_payables_screen', 'checkout_screen', 'checkout_walkin_screen', 'finance_create_entry',
    'finance_pay_payable', 'finance_save_payable', 'finance_delete_payable', 'finance_set_payable_invoice', 'checkout_confirm')),
  'leituras e gravações são SECURITY INVOKER (a RLS vale)');
select pg_temp.expect((select bool_and(p.proconfig @> array['search_path=""']) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and (p.proname like 'finance\_%' or p.proname like 'checkout\_%' or p.proname in ('loyalty_screen', 'payment_request_context'))),
  'search_path vazio em todas');

-- ─── Isolamento: dona do B não lê nem grava no A ───────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001532');
select pg_temp.expect(pg_temp.state_of(q) = '42501', 'dona do B recusada no A: ' || q) from unnest(array[
  $q$select public.finance_overview_screen('00000000-0000-0000-0000-00000000153a', current_date, current_date, current_date, current_date)$q$,
  $q$select public.finance_comandas_screen('00000000-0000-0000-0000-00000000153a', '2026-11')$q$,
  $q$select public.finance_caixa_screen('00000000-0000-0000-0000-00000000153a', null)$q$,
  $q$select public.finance_commissions_screen('00000000-0000-0000-0000-00000000153a', '2026-11')$q$,
  $q$select public.finance_payables_screen('00000000-0000-0000-0000-00000000153a')$q$,
  $q$select public.finance_balances_screen('00000000-0000-0000-0000-00000000153a')$q$,
  $q$select public.finance_gift_cards_screen('00000000-0000-0000-0000-00000000153a')$q$,
  $q$select public.finance_reports_screen('00000000-0000-0000-0000-00000000153a', 'report', current_date, current_date, current_date, current_date)$q$,
  $q$select public.checkout_screen('00000000-0000-0000-0000-00000000153a', '00000000-0000-0000-0000-0000000153aa')$q$,
  $q$select public.checkout_walkin_screen('00000000-0000-0000-0000-00000000153a', null)$q$,
  $q$select public.loyalty_screen('00000000-0000-0000-0000-00000000153a')$q$,
  $q$select public.payment_request_context('00000000-0000-0000-0000-00000000153a', '00000000-0000-0000-0000-0000000153c1', null)$q$,
  $q$select public.finance_create_entry('00000000-0000-0000-0000-00000000153a', 'income', 'x', 1, current_date, null, null, null, gen_random_uuid())$q$,
  $q$select public.finance_pay_payable('00000000-0000-0000-0000-00000000153a', '00000000-0000-0000-0000-0000000153f1', 650, current_date)$q$,
  $q$select public.finance_save_payable('00000000-0000-0000-0000-00000000153a', null, 'x', null, null, 1, current_date, null, null, false, gen_random_uuid())$q$,
  $q$select public.finance_delete_payable('00000000-0000-0000-0000-00000000153a', '00000000-0000-0000-0000-0000000153f1')$q$,
  $q$select public.finance_set_payable_invoice('00000000-0000-0000-0000-00000000153a', '00000000-0000-0000-0000-0000000153f1', null, null)$q$,
  $q$select public.checkout_confirm('00000000-0000-0000-0000-00000000153a', '{"appointment_id":"00000000-0000-0000-0000-0000000153aa","mode":"draft"}')$q$,
  $q$select public.finance_record_export('00000000-0000-0000-0000-00000000153a', 'saldos', 1, null)$q$
]) q;
-- O id do A passado no estúdio B não vaza nada.
select pg_temp.expect(public.checkout_screen('00000000-0000-0000-0000-00000000153b', '00000000-0000-0000-0000-0000000153aa') = '{"not_found": true}'::jsonb,
  'agendamento do A pelo estúdio B: não encontrado');
select pg_temp.expect(jsonb_array_length(public.finance_payables_screen('00000000-0000-0000-0000-00000000153b') -> 'rows') = 1, 'B vê só a sua conta');
select pg_temp.logout();
select pg_temp.expect((select status from public.payables where id = '00000000-0000-0000-0000-0000000153f1') = 'pending', 'conta do A intacta');

-- ─── Papéis no A ───────────────────────────────────────────────────────────────────────────────────
-- Recepção: comandas, caixa, vales e checkout sim; visão geral, contas, comissões, saldos, relatórios e gravações de gestão não.
select pg_temp.login('00000000-0000-0000-0000-000000001531');
select pg_temp.expect(pg_temp.state_of($q$select public.finance_comandas_screen('00000000-0000-0000-0000-00000000153a', '2026-11')$q$) = 'ok', 'recepção lê comandas');
select pg_temp.expect(pg_temp.state_of($q$select public.finance_caixa_screen('00000000-0000-0000-0000-00000000153a', null)$q$) = 'ok', 'recepção lê o caixa');
select pg_temp.expect(pg_temp.state_of($q$select public.finance_gift_cards_screen('00000000-0000-0000-0000-00000000153a')$q$) = 'ok', 'recepção lê vales');
select pg_temp.expect(pg_temp.state_of($q$select public.checkout_screen('00000000-0000-0000-0000-00000000153a', '00000000-0000-0000-0000-0000000153aa')$q$) = 'ok', 'recepção abre o checkout');
select pg_temp.expect(pg_temp.state_of(q) = '42501', 'recepção recusada: ' || q) from unnest(array[
  $q$select public.finance_overview_screen('00000000-0000-0000-0000-00000000153a', current_date, current_date, current_date, current_date)$q$,
  $q$select public.finance_payables_screen('00000000-0000-0000-0000-00000000153a')$q$,
  $q$select public.finance_commissions_screen('00000000-0000-0000-0000-00000000153a', '2026-11')$q$,
  $q$select public.finance_balances_screen('00000000-0000-0000-0000-00000000153a')$q$,
  $q$select public.finance_reports_screen('00000000-0000-0000-0000-00000000153a', 'dre', current_date, current_date, current_date, current_date)$q$,
  $q$select public.finance_create_entry('00000000-0000-0000-0000-00000000153a', 'income', 'x', 1, current_date, null, null, null, gen_random_uuid())$q$,
  $q$select public.finance_pay_payable('00000000-0000-0000-0000-00000000153a', '00000000-0000-0000-0000-0000000153f1', 650, current_date)$q$,
  $q$select public.finance_record_export('00000000-0000-0000-0000-00000000153a', 'saldos', 1, null)$q$
]) q;
select pg_temp.expect(pg_temp.state_of($q$select public.finance_record_export('00000000-0000-0000-0000-00000000153a', 'comandas', 3, '2026-11')$q$) = 'ok',
  'recepção exporta a lista de comandas (registrada)');
select pg_temp.expect((select (finance_shell_counts -> 'contas')::int from public.finance_shell_counts('00000000-0000-0000-0000-00000000153a')) = 0,
  'recepção não vê o número de contas vencidas');
select pg_temp.logout();
select pg_temp.expect(pg_temp.audits('FINANCE_EXPORT') = 1, 'exportação registrada com quem fez');
select pg_temp.expect((select user_id = '00000000-0000-0000-0000-000000001531' and new_data = '{"kind": "comandas", "rows": 3, "period": "2026-11"}'::jsonb
  from public.audit_logs where operation = 'FINANCE_EXPORT' and org_id = :A), 'exportação: só tipo, linhas e período');

-- Profissional: nada do financeiro (nem o checkout).
select pg_temp.login('00000000-0000-0000-0000-000000001534');
select pg_temp.expect(pg_temp.state_of(q) = '42501', 'profissional recusada: ' || q) from unnest(array[
  $q$select public.finance_comandas_screen('00000000-0000-0000-0000-00000000153a', '2026-11')$q$,
  $q$select public.finance_caixa_screen('00000000-0000-0000-0000-00000000153a', null)$q$,
  $q$select public.checkout_screen('00000000-0000-0000-0000-00000000153a', '00000000-0000-0000-0000-0000000153aa')$q$,
  $q$select public.checkout_confirm('00000000-0000-0000-0000-00000000153a', '{"appointment_id":"00000000-0000-0000-0000-0000000153aa","mode":"draft"}')$q$,
  $q$select public.finance_record_export('00000000-0000-0000-0000-00000000153a', 'comandas', 1, null)$q$
]) q;
select pg_temp.logout();

-- ─── Financeiro: lê e grava ────────────────────────────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001535');
-- Lançamento manual: limites e categoria reservada; caminho feliz.
select pg_temp.expect(pg_temp.state_of($q$select public.finance_create_entry('00000000-0000-0000-0000-00000000153a', 'income', 'Ajuste', 10, current_date, null, 'ajuste_saldo', null, gen_random_uuid())$q$) = '22023', 'ajuste_saldo reservado');
select pg_temp.expect(pg_temp.state_of($q$select public.finance_create_entry('00000000-0000-0000-0000-00000000153a', 'income', 'X', 0.004, current_date, null, null, null, gen_random_uuid())$q$) = '22023', 'valor que arredonda para zero recusado');
select pg_temp.expect(pg_temp.state_of($q$select public.finance_create_entry('00000000-0000-0000-0000-00000000153a', 'income', 'X', 1000001, current_date, null, null, null, gen_random_uuid())$q$) = '22023', 'valor acima do teto recusado');
select pg_temp.expect(pg_temp.state_of(format($q$select public.finance_create_entry('00000000-0000-0000-0000-00000000153a', 'income', %L, 10, current_date, null, null, null, gen_random_uuid())$q$, repeat('x', 201))) = '22023', 'descrição longa recusada');
insert into t_out select 'e1', public.finance_create_entry(:A, 'income', 'Venda de balcão', 40.005, :HOJE, 'CASH', 'servicos', 'María Núñez', '00000000-0000-0000-0000-0000000153e1');
insert into t_out select 'e1b', public.finance_create_entry(:A, 'income', 'Venda de balcão', 40.005, :HOJE, 'CASH', 'servicos', 'María Núñez', '00000000-0000-0000-0000-0000000153e1');
select pg_temp.expect((select r ->> 'duplicate' from t_out where k = 'e1') = 'false' and (select r ->> 'duplicate' from t_out where k = 'e1b') = 'true'
  and (select r ->> 'id' from t_out where k = 'e1') = (select r ->> 'id' from t_out where k = 'e1b'), 'lançamento repetido com a mesma chave: duplicate, mesmo id');
select pg_temp.expect((select count(*) from public.transactions where org_id = :A and description = 'Venda de balcão') = 1, 'um lançamento só');
select pg_temp.expect(pg_temp.state_of($q$select public.finance_create_entry('00000000-0000-0000-0000-00000000153a', 'income', 'Venda de balcão', 41, (now() at time zone 'Europe/Madrid')::date, 'CASH', 'servicos', 'María Núñez', '00000000-0000-0000-0000-0000000153e1')$q$) = '22023',
  'mesma chave com outro valor: recusada (Chave reutilizada com dados diferentes)');
select pg_temp.expect(pg_temp.state_of($q$select public.finance_create_entry('00000000-0000-0000-0000-00000000153a', 'income', 'x', 1, current_date, null, null, null, null)$q$) = '22023', 'sem chave do pedido: recusado');
select public.finance_create_entry(:A, 'income', 'Crédito usado', 15, :HOJE, 'CLIENT_CREDIT', null, null, gen_random_uuid());
select public.finance_create_entry(:A, 'expense', 'Material', 12.5, :HOJE, 'CARD_DEBIT', 'material', 'Fornecedor', gen_random_uuid());
insert into t_out select 'ov', public.finance_overview_screen(:A, date_trunc('month', :HOJE)::date,
  (date_trunc('month', :HOJE) + interval '1 month - 1 day')::date,
  (date_trunc('month', :HOJE) - interval '1 month')::date, (date_trunc('month', :HOJE) - interval '1 day')::date);
select pg_temp.expect((select (r -> 'days' -> -1 ->> 'revenue')::numeric = 40.01 and (r -> 'days' -> -1 ->> 'expense')::numeric = 12.5 from t_out where k = 'ov'),
  'visão geral: receita operacional sem crédito usado, despesa, 2 casas');
select pg_temp.expect((select jsonb_array_length(r -> 'entries') = 3 and r ->> 'entries_truncated' = 'false' from t_out where k = 'ov'), 'lançamentos do período (só do A)');
select pg_temp.expect((select r -> 'next_payable' ->> 'description' = 'Aluguel' and (r -> 'counts' ->> 'contas')::int = 1 from t_out where k = 'ov'),
  'próxima conta e contas vencidas');
select pg_temp.expect((select r ->> 'user_name' is null from t_out where k = 'ov'), 'sem perfil, sem nome (o app usa o e-mail)');
select pg_temp.expect(pg_temp.state_of($q$select public.finance_overview_screen('00000000-0000-0000-0000-00000000153a', '2020-01-01', '2026-12-31', '2020-01-01', '2020-01-02')$q$) = '22023',
  'visão geral: teto do período');

-- Contas: criar já paga (paga com a data de hoje do estúdio), editar, pagar com idempotência e recorrência, excluir.
insert into t_out select 'np', public.finance_save_payable(:A, null, 'Internet', 'Operadora', 'servicos', 39.9, current_date + 10, 'none', null, true, '00000000-0000-0000-0000-0000000153e2');
insert into t_out select 'np2', public.finance_save_payable(:A, null, 'Internet', 'Operadora', 'servicos', 39.9, current_date + 10, 'none', null, true, '00000000-0000-0000-0000-0000000153e2');
select pg_temp.expect((select r ->> 'duplicate' from t_out where k = 'np2') = 'true' and (select r ->> 'id' from t_out where k = 'np2') = (select r ->> 'id' from t_out where k = 'np'),
  'conta nova e paga repetida com a mesma chave: duplicate');
select pg_temp.expect((select count(*) from public.payables where org_id = :A and description = 'Internet') = 1
  and (select count(*) from public.transactions where org_id = :A and description = 'Internet') = 1, 'uma conta e uma despesa só');
select pg_temp.expect(pg_temp.state_of($q$select public.finance_save_payable('00000000-0000-0000-0000-00000000153a', null, 'Internet', 'Operadora', 'servicos', 49.9, current_date + 10, 'none', null, true, '00000000-0000-0000-0000-0000000153e2')$q$) = '22023',
  'conta: mesma chave com outro valor recusada');
select pg_temp.expect((select status = 'paid' and paid_value = 39.9 from public.payables where id = (select (r ->> 'id')::uuid from t_out where k = 'np')),
  'conta criada já paga');
select pg_temp.expect(pg_temp.state_of(format($q$select public.finance_save_payable('00000000-0000-0000-0000-00000000153a', %L, 'Internet', null, null, 1, current_date, null, null, false, gen_random_uuid())$q$,
  (select r ->> 'id' from t_out where k = 'np'))) = '22023', 'conta paga não se edita');
select pg_temp.expect(pg_temp.state_of($q$select public.finance_save_payable('00000000-0000-0000-0000-00000000153a', '00000000-0000-0000-0000-0000000153f9', 'x', null, null, 1, current_date, null, null, false, gen_random_uuid())$q$) = 'P0002',
  'conta do B pelo A: não encontrada');
insert into t_out select 'p1', public.finance_pay_payable(:A, '00000000-0000-0000-0000-0000000153f1', 650, :HOJE);
insert into t_out select 'p2', public.finance_pay_payable(:A, '00000000-0000-0000-0000-0000000153f1', 650, :HOJE);
select pg_temp.expect((select r ->> 'duplicate' from t_out where k = 'p1') = 'false' and (select r ->> 'duplicate' from t_out where k = 'p2') = 'true',
  'pagar de novo com os mesmos dados devolve duplicate');
select pg_temp.expect(pg_temp.state_of($q$select public.finance_pay_payable('00000000-0000-0000-0000-00000000153a', '00000000-0000-0000-0000-0000000153f1', 600, current_date)$q$) = 'P0001',
  'pagar de novo com outro valor é recusado');
select pg_temp.expect((select count(*) from public.transactions where org_id = :A and category = 'conta_paga' and description = 'Aluguel') = 1,
  'uma despesa só');
select pg_temp.expect((select count(*) from public.payables where org_id = :A and description = 'Aluguel' and status = 'pending'
  and due_date = (current_date - 3 + interval '1 month')::date
  and source_key = 'recurrence:00000000-0000-0000-0000-0000000153f1') = 1, 'conta mensal ganha a próxima, uma vez (pela conta de origem)');
-- Recorrência semanal, mensal no fim do mês e anual em 29/fev.
insert into t_out select 'rw', public.finance_save_payable(:A, null, 'Faxina', null, null, 30, '2034-01-31', 'weekly', null, false, gen_random_uuid());
insert into t_out select 'rm', public.finance_save_payable(:A, null, 'Luz', null, null, 80, '2034-01-31', 'monthly', null, false, gen_random_uuid());
insert into t_out select 'ry', public.finance_save_payable(:A, null, 'Seguro', null, null, 300, '2032-02-29', 'yearly', null, false, gen_random_uuid());
select public.finance_pay_payable(:A, (r ->> 'id')::uuid, 30, '2034-01-31') from t_out where k = 'rw';
select public.finance_pay_payable(:A, (r ->> 'id')::uuid, 80, '2034-01-31') from t_out where k = 'rm';
select public.finance_pay_payable(:A, (r ->> 'id')::uuid, 300, '2032-02-29') from t_out where k = 'ry';
select pg_temp.expect((select due_date from public.payables where org_id = :A and description = 'Faxina' and status = 'pending') = '2034-02-07', 'semanal: +7 dias');
select pg_temp.expect((select due_date from public.payables where org_id = :A and description = 'Luz' and status = 'pending') = '2034-02-28', 'mensal: 31/jan vira 28/fev');
select pg_temp.expect((select due_date from public.payables where org_id = :A and description = 'Seguro' and status = 'pending') = '2033-02-28', 'anual: 29/fev vira 28/fev');
-- Pagar de novo a mesma conta (repetição) não cria outra próxima.
select public.finance_pay_payable(:A, (r ->> 'id')::uuid, 30, '2034-01-31') from t_out where k = 'rw';
select pg_temp.expect((select count(*) from public.payables where org_id = :A and description = 'Faxina') = 2, 'repetição não cria outra próxima');
delete from public.payables where org_id = :A and description in ('Faxina', 'Luz', 'Seguro') and status = 'pending';
select public.finance_delete_payable(:A, (select id from public.payables where org_id = :A and description = 'Aluguel' and status = 'pending'));
select public.finance_delete_payable(:A, '00000000-0000-0000-0000-0000000153ff');
select pg_temp.expect(pg_temp.state_of(format($q$select public.finance_delete_payable('00000000-0000-0000-0000-00000000153a', %L)$q$,
  (select r ->> 'id' from t_out where k = 'np'))) = '22023', 'conta paga não se exclui');
-- Fatura: só caminho da pasta do estúdio e da conta; devolve o anterior para apagar.
select pg_temp.expect(pg_temp.state_of($q$select public.finance_set_payable_invoice('00000000-0000-0000-0000-00000000153a', '00000000-0000-0000-0000-0000000153f1', '00000000-0000-0000-0000-00000000153b/00000000-0000-0000-0000-0000000153f1/x.pdf', 'f.pdf')$q$) = '22023',
  'fatura em pasta de outro estúdio recusada');
select public.finance_set_payable_invoice(:A, '00000000-0000-0000-0000-0000000153f1', '00000000-0000-0000-0000-00000000153a/00000000-0000-0000-0000-0000000153f1/a.pdf', 'fatura.pdf');
select pg_temp.expect(public.finance_set_payable_invoice(:A, '00000000-0000-0000-0000-0000000153f1', null, null) ->> 'previous'
  = '00000000-0000-0000-0000-00000000153a/00000000-0000-0000-0000-0000000153f1/a.pdf', 'tirar a fatura devolve o caminho anterior');
select pg_temp.expect(public.finance_payable_invoice_path(:A, '00000000-0000-0000-0000-0000000153f1') is null, 'conta sem fatura');
select pg_temp.expect((select r -> 'rows' -> 0 ? 'invoice_name' and not (r -> 'rows' -> 0 ? 'invoice_path')
  from (select public.finance_payables_screen(:A) as r) x), 'lista de contas sem o caminho da fatura');

-- ─── Caixa: abrir, cobrar no checkout, fechar ──────────────────────────────────────────────────────
select public.open_cash_session_atomic(:A, 50, 'Ana', now(), null, true);
insert into t_out select 'cx', public.finance_caixa_screen(:A, null);
select pg_temp.expect((select r ->> 'open_id' is not null and r ->> 'shown_id' = r ->> 'open_id' and jsonb_array_length(r -> 'history') = 1 from t_out where k = 'cx'),
  'caixa aberto aparece');
select pg_temp.expect((select (r -> 'txs_truncated')::boolean = false and jsonb_array_length(r -> 'txs') = 5 from t_out where k = 'cx'),
  'os 5 lançamentos de hoje (3 manuais, 2 contas pagas) entraram no caixa ao abrir');

-- Checkout: rascunho, depois cobra com a mesma chave duas vezes.
insert into t_out select 'ck0', public.checkout_screen(:A, '00000000-0000-0000-0000-0000000153aa');
select pg_temp.expect((select r -> 'sale' = 'null'::jsonb and r -> 'appointment' ->> 'id' = '00000000-0000-0000-0000-0000000153aa'
  and jsonb_array_length(r -> 'appointment' -> 'items') = 1 and r -> 'client' ->> 'full_name' = 'María Núñez'
  and jsonb_array_length(r -> 'catalog' -> 'services') = 2 and r ->> 'timezone' = 'Europe/Madrid' from t_out where k = 'ck0'),
  'checkout novo: agendamento, itens, cliente, catálogo do A e fuso do estúdio');
insert into t_out select 'c1', public.checkout_confirm(:A, jsonb_build_object(
  'request_id', '00000000-0000-0000-0000-0000000153b1', 'appointment_id', '00000000-0000-0000-0000-0000000153aa', 'mode', 'finalize',
  'items', jsonb_build_array(jsonb_build_object('item_type', 'SERVICE', 'item_id', '00000000-0000-0000-0000-0000000153d1', 'name', 'Limpeza de pele', 'unit_price', 100, 'quantity', 1)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'CASH', 'amount', 100))));
insert into t_out select 'c2', public.checkout_confirm(:A, jsonb_build_object(
  'request_id', '00000000-0000-0000-0000-0000000153b1', 'appointment_id', '00000000-0000-0000-0000-0000000153aa', 'mode', 'finalize',
  'items', jsonb_build_array(jsonb_build_object('item_type', 'SERVICE', 'item_id', '00000000-0000-0000-0000-0000000153d1', 'name', 'Limpeza de pele', 'unit_price', 100, 'quantity', 1)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'CASH', 'amount', 100))));
select pg_temp.expect((select r ->> 'status' = 'paid' and (r ->> 'saleNumber')::int > 0 and r ->> 'duplicate' = 'false' from t_out where k = 'c1'),
  'checkout cobra e devolve o número da comanda');
select pg_temp.expect((select r ->> 'duplicate' = 'true' and r ->> 'saleId' = (select r ->> 'saleId' from t_out where k = 'c1') from t_out where k = 'c2'),
  'mesma chave: duplicate, sem segunda cobrança');
select pg_temp.expect((select status from public.appointments where id = '00000000-0000-0000-0000-0000000153aa') = 'Pago', 'Pago só pelo checkout');
select pg_temp.expect(public.checkout_screen(:A, '00000000-0000-0000-0000-0000000153aa') ->> 'redirect' = (select r ->> 'saleId' from t_out where k = 'c1'),
  'id do agendamento com comanda: redireciona para a comanda');
insert into t_out select 'ck1', public.checkout_screen(:A, (select (r ->> 'saleId')::uuid from t_out where k = 'c1'));
select pg_temp.expect((select r -> 'sale' ->> 'status' = 'paid' and jsonb_array_length(r -> 'sale' -> 'payments') = 1 and (r ->> 'visits')::int = 1
  and r -> 'retouch_rules' = '[]'::jsonb from t_out where k = 'ck1'), 'comanda paga em leitura (sem retoques: não está aberta)');

-- Comissões: 10% de 100 para a Karenn; totais no banco.
insert into t_out select 'cm', public.finance_commissions_screen(:A, to_char(now() at time zone 'Europe/Madrid', 'YYYY-MM'));
select pg_temp.expect((select r -> 'totals' -> 0 ->> 'commission' = '10.00' and (r -> 'totals' -> 0 ->> 'attendances')::int = 1
  and jsonb_array_length(r -> 'lines') = 1 and r -> 'lines' -> 0 ->> 'service' = 'Limpeza de pele' from t_out where k = 'cm'),
  'comissão calculada no banco com a mesma regra do fechamento');

-- Comandas do mês.
insert into t_out select 'cl', public.finance_comandas_screen(:A, to_char(now() at time zone 'Europe/Madrid', 'YYYY-MM'));
select pg_temp.expect((select jsonb_array_length(r -> 'rows') = 1 and r -> 'rows' -> 0 -> 'services' = '["Limpeza de pele"]'::jsonb
  and r -> 'rows' -> 0 ->> 'client_phone' = '+34600000001' from t_out where k = 'cl'), 'comanda na lista do mês com serviços e telefone');

-- Estorno total com chave: repetir devolve duplicate (função já existente, reaproveitada).
insert into t_out select 'r1', public.refund_sale_atomic(:A, (select (r ->> 'saleId')::uuid from t_out where k = 'c1'), 'Cliente desistiu do serviço', 'caixa', false,
  '00000000-0000-0000-0000-0000000153c7', false);
insert into t_out select 'r2', public.refund_sale_atomic(:A, (select (r ->> 'saleId')::uuid from t_out where k = 'c1'), 'Cliente desistiu do serviço', 'caixa', false,
  '00000000-0000-0000-0000-0000000153c7', false);
select pg_temp.expect((select (r ->> 'duplicate')::boolean from t_out where k = 'r2'), 'estorno repetido devolve duplicate');
insert into t_out select 'ck2', public.checkout_screen(:A, (select (r ->> 'saleId')::uuid from t_out where k = 'c1'));
select pg_temp.expect((select (r -> 'refund' ->> 'amount')::numeric = 100 and r -> 'refund' ->> 'destination' = 'caixa' from t_out where k = 'ck2'),
  'comanda estornada mostra quanto e para onde');

-- Fechar o caixa: esperado em dinheiro = 50 de troco + 40,01 + 100 − 100 (estorno) = 90,01.
insert into t_out select 'cx2', public.finance_caixa_screen(:A, null);
select pg_temp.expect((select coalesce(sum((g ->> 'value')::numeric) filter (where g ->> 'type' = 'income' and g ->> 'method' = 'CASH'), 0) = 140.01
  from t_out, jsonb_array_elements(r -> 'tx_groups') g where k = 'cx2'), 'resumo do caixa soma todos os lançamentos (grupos)');
select public.close_cash_session_atomic(:A, (select (r ->> 'open_id')::uuid from t_out where k = 'cx2'),
  '{"CASH": 90.01, "CARD_DEBIT": -12.5}'::jsonb, null, null, null, false);
select pg_temp.expect((select status = 'closed' and difference_total = 0 from public.cash_sessions where org_id = :A), 'caixa fechado sem diferença');
insert into t_out select 'cx3', public.finance_caixa_screen(:A, (select (r ->> 'open_id')::uuid from t_out where k = 'cx2'));
select pg_temp.expect((select r ->> 'open_id' is null and r ->> 'shown_id' is not null and r -> 'history' -> 0 -> 'expected' ->> 'CASH' = '90.01'
  from t_out where k = 'cx3'), 'caixa fechado escolhido no histórico, com o esperado gravado');

-- Relatórios, saldos, vales, fidelidade.
select pg_temp.expect((select r ? 'current' and r ? 'previous' from (select public.finance_reports_screen(:A, 'dre', current_date - 30, current_date, current_date - 61, current_date - 31) as r) x),
  'DRE do período e da comparação numa ida');
select pg_temp.expect(pg_temp.state_of($q$select public.finance_reports_screen('00000000-0000-0000-0000-00000000153a', 'report', '2020-01-01', '2026-12-31', '2019-01-01', '2019-12-31')$q$) = '22023',
  'relatório: teto do período');
select pg_temp.expect(jsonb_array_length(public.finance_balances_screen(:A) -> 'rows') = 0, 'saldos do A (o B tem saldo, não aparece)');
select pg_temp.expect(jsonb_array_length(public.finance_gift_cards_screen(:A) -> 'rows') = 0, 'vale do B não aparece no A');
select pg_temp.expect((public.loyalty_screen(:A) -> 'summary' ->> 'clients_with_points')::int = 0, 'fidelidade: só clientes do A');
select pg_temp.logout();

-- ─── Vales-presente: limites no banco e auditoria ──────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001531');
select pg_temp.expect(pg_temp.state_of($q$insert into public.gift_cards (org_id, code, initial_value, remaining_value) values ('00000000-0000-0000-0000-00000000153a', 'GRANDE', 100001, 100001)$q$) = '23514',
  'vale acima do teto recusado pelo banco');
insert into public.gift_cards (id, org_id, code, initial_value, remaining_value, issued_to)
values ('00000000-0000-0000-0000-0000000153e1', :A, 'KA-153', 30, 30, 'Pessoa presenteada');
update public.gift_cards set status = 'cancelled' where id = '00000000-0000-0000-0000-0000000153e1';
select pg_temp.logout();

-- ─── Auditoria: gravada pelo gatilho com quem fez, sem texto livre; não forjável pela API ──────────
select pg_temp.expect(pg_temp.audits('TRANSACTION_CREATED') >= 4, 'lançamentos sem venda auditados (manuais e conta paga)');
select pg_temp.expect(pg_temp.audits('PAYABLE_CREATED') >= 2 and pg_temp.audits('PAYABLE_UPDATED') >= 2 and pg_temp.audits('PAYABLE_DELETED') >= 1,
  'contas: criar, pagar/fatura e excluir auditados');
select pg_temp.expect((select bool_and(user_id = '00000000-0000-0000-0000-000000001535') from public.audit_logs
  where org_id = :A and operation like 'PAYABLE\_%'), 'auditoria com auth.uid() de quem gravou');
-- Tudo roda numa transação (created_at igual): confere o conjunto, não a ordem.
select pg_temp.expect((select array_agg(new_data ->> 'invoice' order by new_data ->> 'invoice') = array['false', 'true']
  and bool_and(new_data - 'invoice' = '{}'::jsonb and old_data - 'invoice' = '{}'::jsonb)
  from public.audit_logs where org_id = :A and operation = 'PAYABLE_UPDATED' and new_data ? 'invoice'),
  'fatura: só "tem/não tem", nunca o caminho');
select pg_temp.expect(not exists (select 1 from public.audit_logs where org_id = :A and operation like 'TRANSACTION\_%'
  and (new_data ? 'description' or new_data ? 'client_name')), 'lançamento auditado sem descrição nem nome');
select pg_temp.expect(pg_temp.audits('GIFT_CARD_CREATED') = 1 and pg_temp.audits('GIFT_CARD_UPDATED') = 1
  and not exists (select 1 from public.audit_logs where org_id = :A and operation like 'GIFT\_CARD\_%' and (new_data ? 'code' or new_data ? 'issued_to')),
  'vale: emitir e cancelar auditados, sem código nem nome');
select pg_temp.login('00000000-0000-0000-0000-000000001535');
select pg_temp.expect(pg_temp.state_of($q$insert into public.audit_logs (org_id, user_id, table_name, operation) values ('00000000-0000-0000-0000-00000000153a', '00000000-0000-0000-0000-000000001535', 'payables', 'PAYABLE_DELETED')$q$) = '42501',
  'auditoria do financeiro não é forjável pela API');
select pg_temp.expect(pg_temp.state_of($q$select public.finance_record_export('00000000-0000-0000-0000-00000000153a', 'qualquer', 1, null)$q$) = '22023',
  'exportação: só os tipos fixos');
select pg_temp.expect(pg_temp.state_of($q$select public.finance_audit_row()$q$) = '42501', 'função do gatilho não é chamável');
select pg_temp.logout();

-- Limites das contas no banco (também pela API direta).
select pg_temp.expect(pg_temp.state_of($q$insert into public.payables (org_id, description, value, due_date, recurrence) values ('00000000-0000-0000-0000-00000000153a', 'x', 1, current_date, 'daily')$q$) = '23514',
  'recorrência fora da lista recusada');
select pg_temp.expect(pg_temp.state_of($q$insert into public.transactions (org_id, type, description, value, date, status) values ('00000000-0000-0000-0000-00000000153a', 'income', 'x', 1000001, current_date, 'completed')$q$) = '23514',
  'lançamento acima do teto recusado');


-- ─── Ficha Profissional na cobrança, repetição pela chave, continuação e recepção cobrando ────────────
select pg_temp.login('00000000-0000-0000-0000-000000001531');
-- Sem "mode": vale como fechar (padrão de confirm_checkout_atomic) e a ficha pendente volta como {gate}, sem gravar.
insert into t_out select 'g1', public.checkout_confirm(:A, jsonb_build_object(
  'request_id', '00000000-0000-0000-0000-0000000153b5', 'appointment_id', '00000000-0000-0000-0000-0000000153ab',
  'items', jsonb_build_array(jsonb_build_object('item_type', 'SERVICE', 'item_id', '00000000-0000-0000-0000-0000000153d2', 'name', 'Peeling', 'unit_price', 120, 'quantity', 1)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'CASH', 'amount', 120))));
select pg_temp.expect((select jsonb_array_length(r -> 'gate') >= 1 and not (r ? 'saleId') from t_out where k = 'g1'), 'sem mode: ficha pendente devolve {gate}');
-- A trava também está dentro da cobrança: chamar a função antiga direto pela API não pula a ficha.
select pg_temp.expect(pg_temp.state_of($q$select public.confirm_checkout_atomic('00000000-0000-0000-0000-00000000153a', jsonb_build_object(
  'request_id', '00000000-0000-0000-0000-0000000153b6', 'appointment_id', '00000000-0000-0000-0000-0000000153ab', 'mode', 'finalize',
  'items', jsonb_build_array(jsonb_build_object('item_type', 'SERVICE', 'item_id', '00000000-0000-0000-0000-0000000153d2', 'name', 'Peeling', 'unit_price', 120, 'quantity', 1)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'CASH', 'amount', 120))))$q$) = 'P0001', 'chamada direta com ficha pendente: recusada');
select pg_temp.expect(not exists (select 1 from public.sales where appointment_id = '00000000-0000-0000-0000-0000000153ab'), 'nada gravado com a ficha pendente');

-- Recepção cobra; a mesma chave repetida não cobra de novo (1 pagamento, 1 lançamento) e volta com duplicate.
insert into t_out select 'rc1', public.checkout_confirm(:A, jsonb_build_object(
  'request_id', '00000000-0000-0000-0000-0000000153b7', 'appointment_id', '00000000-0000-0000-0000-0000000153ac', 'mode', 'finalize',
  'items', jsonb_build_array(jsonb_build_object('item_type', 'SERVICE', 'item_id', '00000000-0000-0000-0000-0000000153d1', 'name', 'Limpeza de pele', 'unit_price', 100, 'quantity', 1)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'CARD_DEBIT', 'amount', 100))));
insert into t_out select 'rc2', public.checkout_confirm(:A, jsonb_build_object(
  'request_id', '00000000-0000-0000-0000-0000000153b7', 'appointment_id', '00000000-0000-0000-0000-0000000153ac', 'mode', 'finalize',
  'items', jsonb_build_array(jsonb_build_object('item_type', 'SERVICE', 'item_id', '00000000-0000-0000-0000-0000000153d1', 'name', 'Limpeza de pele', 'unit_price', 100, 'quantity', 1)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'CARD_DEBIT', 'amount', 100))));
select pg_temp.logout();
select pg_temp.expect((select r ->> 'status' = 'paid' and r ->> 'duplicate' = 'false' from t_out where k = 'rc1'), 'recepção cobra com sucesso');
select pg_temp.expect((select r ->> 'duplicate' = 'true' and r ->> 'saleId' = (select r ->> 'saleId' from t_out where k = 'rc1') from t_out where k = 'rc2'),
  'mesma chave: duplicate');
select pg_temp.expect((select count(*) from public.sale_payments where sale_id = (select (r ->> 'saleId')::uuid from t_out where k = 'rc1')) = 1
  and (select count(*) from public.transactions where sale_id = (select (r ->> 'saleId')::uuid from t_out where k = 'rc1')) = 1,
  'repetição: 1 pagamento e 1 lançamento');

-- Pagar em duas vezes: a continuação (chave nova) não é repetição.
select pg_temp.login('00000000-0000-0000-0000-000000001535');
insert into t_out select 'pp1', public.checkout_confirm(:A, jsonb_build_object(
  'request_id', '00000000-0000-0000-0000-0000000153b8', 'appointment_id', '00000000-0000-0000-0000-0000000153ad', 'mode', 'finalize',
  'items', jsonb_build_array(jsonb_build_object('item_type', 'SERVICE', 'item_id', '00000000-0000-0000-0000-0000000153d1', 'name', 'Limpeza de pele', 'unit_price', 100, 'quantity', 1)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'CASH', 'amount', 40))));
insert into t_out select 'pp2', public.checkout_confirm(:A, jsonb_build_object(
  'request_id', '00000000-0000-0000-0000-0000000153b9', 'appointment_id', '00000000-0000-0000-0000-0000000153ad', 'mode', 'finalize',
  'items', jsonb_build_array(jsonb_build_object('item_type', 'SERVICE', 'item_id', '00000000-0000-0000-0000-0000000153d1', 'name', 'Limpeza de pele', 'unit_price', 100, 'quantity', 1)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'CASH', 'amount', 40), jsonb_build_object('method', 'CASH', 'amount', 60))));
select pg_temp.expect((select r ->> 'status' = 'partial' and r ->> 'duplicate' = 'false' from t_out where k = 'pp1')
  and (select r ->> 'status' = 'paid' and r ->> 'duplicate' = 'false' from t_out where k = 'pp2'), 'continuação com chave nova: duplicate false e quita');
-- Devolução parcial aparece na comanda.
select public.partial_refund_sale_atomic(:A, (select (r ->> 'saleId')::uuid from t_out where k = 'pp2'), 15, 'Cliente reclamou do serviço', 'caixa', 'CASH',
  '00000000-0000-0000-0000-0000000153ba');
select pg_temp.expect((public.checkout_screen(:A, (select (r ->> 'saleId')::uuid from t_out where k = 'pp2')) ->> 'partial_refunded')::numeric = 15,
  'devolução parcial aparece na comanda');

-- Comissões já fechadas aparecem como "closed" (conta lançada pelo fechamento).
select public.close_commission_period_atomic(:A, to_char(now() at time zone 'Europe/Madrid', 'YYYY-MM'));
select pg_temp.expect((select count(*) > 0 from jsonb_array_elements(public.finance_commissions_screen(:A, to_char(now() at time zone 'Europe/Madrid', 'YYYY-MM')) -> 'closed') c
  where c ->> 'staff_id' = '00000000-0000-0000-0000-0000000153a1'), 'comissão fechada aparece nas contas lançadas');

-- Virada de mês no fuso do estúdio: 30/abr 23:30 em Madri é abril; 1º/mai 00:30 em Madri (30/abr 22:30 UTC) é maio.
select pg_temp.logout();
insert into public.sales (org_id, client_name, status, subtotal, total, paid_amount, balance, created_at) values
  (:A, 'Abril', 'draft', 10, 10, 0, 10, '2034-04-30 21:30:00+00'),
  (:A, 'Maio', 'draft', 10, 10, 0, 10, '2034-04-30 22:30:00+00');
select pg_temp.login('00000000-0000-0000-0000-000000001535');
select pg_temp.expect((select jsonb_agg(x ->> 'client_name') from jsonb_array_elements(public.finance_comandas_screen(:A, '2034-04') -> 'rows') x) = '["Abril"]'::jsonb
  and (select jsonb_agg(x ->> 'client_name') from jsonb_array_elements(public.finance_comandas_screen(:A, '2034-05') -> 'rows') x) = '["Maio"]'::jsonb,
  'mês das comandas no fuso do estúdio');

-- Listas cortadas avisam: 201 lançamentos e 301 clientes na visão geral; contas não pagas vêm antes das pagas.
select pg_temp.logout();
insert into public.transactions (org_id, type, description, value, date, method, status)
select :A, 'income', 'Lote ' || g, 1, '2034-03-10', 'CASH', 'completed' from generate_series(1, 201) g;
insert into public.clients (org_id, full_name) select :A, 'Cliente ' || g from generate_series(1, 301) g;
insert into public.payables (org_id, description, value, due_date, status, paid_value, paid_date)
select :A, 'Paga ' || g, 1, '2020-01-01', 'paid', 1, '2020-01-01' from generate_series(1, 2001) g;
insert into public.payables (org_id, description, value, due_date, status) values (:A, 'Aberta de 2099', 5, '2099-01-01', 'pending');
select pg_temp.login('00000000-0000-0000-0000-000000001535');
insert into t_out select 'tr', public.finance_overview_screen(:A, '2034-03-01', '2034-03-31', '2034-02-01', '2034-02-28');
select pg_temp.expect((select (r ->> 'entries_truncated')::boolean and jsonb_array_length(r -> 'entries') = 200
  and (r ->> 'clients_truncated')::boolean and jsonb_array_length(r -> 'clients') = 300 from t_out where k = 'tr'), 'visão geral avisa o corte');
select pg_temp.expect((select (r -> 'days' -> 0 ->> 'revenue')::numeric = 201 from t_out where k = 'tr'), 'total do dia soma todos (não a lista cortada)');
insert into t_out select 'pt', public.finance_payables_screen(:A);
select pg_temp.expect((select (r ->> 'truncated')::boolean and r -> 'rows' -> 0 ->> 'status' <> 'paid'
  and exists (select 1 from jsonb_array_elements(r -> 'rows') x where x ->> 'description' = 'Aberta de 2099') from t_out where k = 'pt'),
  'contas cortadas: as não pagas primeiro');
select pg_temp.logout();

-- ─── Recepção e o caixa: vê os totais (para conferir e fechar), não os lançamentos ───────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001531');
select public.open_cash_session_atomic(:A, 20, 'Recepção', now(), null, false);
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000001535');
select public.finance_create_entry(:A, 'income', 'Venda no balcão', 35, :HOJE, 'CASH', null, null, gen_random_uuid());
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000001531');
insert into t_out select 'rcx', public.finance_caixa_screen(:A, null);
select pg_temp.expect((select jsonb_array_length(r -> 'txs') = 0 from t_out where k = 'rcx'), 'recepção não lê os lançamentos');
select pg_temp.expect((select coalesce(sum((g ->> 'value')::numeric) filter (where g ->> 'method' = 'CASH' and g ->> 'type' = 'income'), 0) = 35
  from t_out, jsonb_array_elements(r -> 'tx_groups') g where k = 'rcx'), 'recepção vê o total em dinheiro do caixa');
select pg_temp.expect(not exists (select 1 from t_out, jsonb_array_elements(r -> 'tx_groups') g where k = 'rcx'
  and (g ? 'description' or g ? 'client_name' or g ? 'id')), 'totais sem lançamento individual');
select pg_temp.expect((select bool_and(g ->> 'category' in ('ajuste_saldo', 'sinal', 'estorno', 'conta_paga', 'outros'))
  from t_out, jsonb_array_elements(r -> 'tx_groups') g where k = 'rcx'), 'categorias livres somadas em "outros"');
select pg_temp.logout();

-- ─── Perfil que só vê o financeiro e Fidelidade ──────────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-000000001536');
select pg_temp.expect(pg_temp.state_of($q$select public.checkout_screen('00000000-0000-0000-0000-00000000153a', '00000000-0000-0000-0000-0000000153ab')$q$) = 'ok',
  'quem só vê o financeiro abre a comanda (sem a trava da ficha)');
select pg_temp.expect(pg_temp.state_of($q$select public.finance_payables_screen('00000000-0000-0000-0000-00000000153a')$q$) = 'ok', 'e as contas');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000001534');
select pg_temp.expect(pg_temp.state_of($q$select public.loyalty_screen('00000000-0000-0000-0000-00000000153a')$q$) = 'ok', 'profissional (vê clientes) abre a fidelidade');
select pg_temp.expect(pg_temp.state_of($q$select public.finance_shell_counts('00000000-0000-0000-0000-00000000153a')$q$) = '42501', 'contadores exigem permissão do financeiro');
select pg_temp.logout();
insert into public.org_role_permissions (org_id, role, permission, allowed) values (:A, 'professional', 'clientes.view', false);
select pg_temp.login('00000000-0000-0000-0000-000000001534');
select pg_temp.expect(pg_temp.state_of($q$select public.loyalty_screen('00000000-0000-0000-0000-00000000153a')$q$) = '42501', 'sem ver clientes: sem fidelidade');
select pg_temp.logout();

-- ─── Pacote cancelado ou vencido nunca volta a ativo (estorno que devolve sessão) ─────────────────────
insert into public.client_entitlements (id, org_id, client_id, package_name, status, total_sessions, used_sessions, covered_services) values
  ('00000000-0000-0000-0000-0000000153e7', :A, '00000000-0000-0000-0000-0000000153c1', 'Pacote 1 sessão', 'active', 1, 0, '[]'::jsonb);
insert into public.appointments (id, org_id, client_id, client_name, staff_id, start_at, end_at, duration_minutes, status, source, total) values
  ('00000000-0000-0000-0000-0000000153ae', :A, '00000000-0000-0000-0000-0000000153c1', 'María Núñez', '00000000-0000-0000-0000-0000000153a1',
   now() - interval '4 hours', now() - interval '3 hours', 60, 'Agendado', 'MANUAL', 0);
set local session_replication_role = replica;
insert into public.appointment_items (org_id, appointment_id, type, ref_id, name, price, qty, requires_anamnese) values
  (:A, '00000000-0000-0000-0000-0000000153ae', 'service', '00000000-0000-0000-0000-0000000153d1', 'Limpeza de pele', 0, 1, false);
set local session_replication_role = origin;
update public.appointments set status = 'Concluído' where id = '00000000-0000-0000-0000-0000000153ae';
select pg_temp.login('00000000-0000-0000-0000-000000001535');
insert into t_out select 'pk1', public.checkout_confirm(:A, jsonb_build_object(
  'request_id', '00000000-0000-0000-0000-0000000153bb', 'appointment_id', '00000000-0000-0000-0000-0000000153ae', 'mode', 'finalize',
  'items', jsonb_build_array(jsonb_build_object('item_type', 'SERVICE', 'item_id', '00000000-0000-0000-0000-0000000153d1', 'name', 'Limpeza de pele',
    'unit_price', 0, 'quantity', 1, 'entitlement_id', '00000000-0000-0000-0000-0000000153e7', 'covered_by_entitlement', true)),
  'payments', '[]'::jsonb));
select pg_temp.logout();
select pg_temp.expect((select status = 'exhausted' and used_sessions = 1 from public.client_entitlements where id = '00000000-0000-0000-0000-0000000153e7'),
  'pacote: sessão usada no checkout, esgotado');
-- O pacote venceu depois do uso; o estorno devolve a sessão mas não reativa.
update public.client_entitlements set expires_at = now() - interval '1 day' where id = '00000000-0000-0000-0000-0000000153e7';
select pg_temp.login('00000000-0000-0000-0000-000000001535');
select public.refund_sale_atomic(:A, (select (r ->> 'saleId')::uuid from t_out where k = 'pk1'), 'Cliente desistiu do serviço', 'caixa', false,
  '00000000-0000-0000-0000-0000000153bc', false);
select pg_temp.logout();
-- Regra do gatilho de 20261114080000 (main): o que viraria ativo com a validade passada fica vencido.
select pg_temp.expect((select status = 'expired' and used_sessions = 0 from public.client_entitlements where id = '00000000-0000-0000-0000-0000000153e7'),
  'estorno devolve a sessão de pacote com validade passada e ele fica vencido, não ativo');
-- Vencido não volta a ativo depois de outro estorno nem por gravação direta.
select pg_temp.expect(pg_temp.state_of($q$update public.client_entitlements set status = 'active' where id = '00000000-0000-0000-0000-0000000153e7'$q$) = '22023',
  'vencido não volta a ativo');
-- ─── Quem lança sem ver o financeiro (financeiro.manage sem financeiro.view): repetição devolve só o id ─────
insert into public.org_role_permissions (org_id, role, permission, allowed) values (:A, 'finance', 'financeiro.view', false);
select pg_temp.login('00000000-0000-0000-0000-000000001535');
insert into t_out select 'nv1', public.finance_create_entry(:A, 'income', 'Sem ver', 5, :HOJE, null, null, null, '00000000-0000-0000-0000-0000000153e3');
insert into t_out select 'nv2', public.finance_create_entry(:A, 'income', 'Sem ver', 5, :HOJE, null, null, null, '00000000-0000-0000-0000-0000000153e3');
select pg_temp.expect((select r ->> 'duplicate' = 'true' and r ->> 'id' = (select r ->> 'id' from t_out where k = 'nv1') and (r - 'id' - 'duplicate') = '{}'::jsonb
  from t_out where k = 'nv2'), 'sem financeiro.view: a repetição devolve o id (e só ele)');
insert into t_out select 'pv1', public.finance_save_payable(:A, null, 'Sem ver', null, null, 5, '2034-01-01', null, null, false, '00000000-0000-0000-0000-0000000153e4');
insert into t_out select 'pv2', public.finance_save_payable(:A, null, 'Sem ver', null, null, 5, '2034-01-01', null, null, false, '00000000-0000-0000-0000-0000000153e4');
select pg_temp.expect((select r ->> 'duplicate' = 'true' and r ->> 'id' = (select r ->> 'id' from t_out where k = 'pv1') from t_out where k = 'pv2'),
  'conta: idem');
select pg_temp.logout();

-- Apagar o estúdio inteiro (cascata) não quebra no gatilho de auditoria.
delete from public.organizations where id = :B;
select pg_temp.expect(not exists (select 1 from public.payables where org_id = :B), 'cascata do estúdio B ok');

rollback;
\o
\echo 'financeiro: leituras e ações em uma ida (153): ok'
