-- Caixa do dia (20261031600000): abrir, sangria/suprimento, fechar com conferência, reabrir, RLS e auditoria.
-- Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000001431', 'dona-caixa@teste.local'),
  ('00000000-0000-0000-0000-000000001432', 'fin-caixa@teste.local'),
  ('00000000-0000-0000-0000-000000001433', 'recep-caixa@teste.local'),
  ('00000000-0000-0000-0000-000000001434', 'viewer-caixa@teste.local'),
  ('00000000-0000-0000-0000-000000001435', 'outra-dona@teste.local');
insert into public.organizations (id, slug, name, timezone) values
  ('00000000-0000-0000-0000-00000000143a', 'caixa-a', 'Estúdio A', 'Europe/Madrid'),
  ('00000000-0000-0000-0000-00000000143b', 'caixa-b', 'Estúdio B', 'Europe/Madrid');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000001431', '00000000-0000-0000-0000-00000000143a', 'owner'),
  ('00000000-0000-0000-0000-000000001432', '00000000-0000-0000-0000-00000000143a', 'finance'),
  ('00000000-0000-0000-0000-000000001433', '00000000-0000-0000-0000-00000000143a', 'receptionist'),
  ('00000000-0000-0000-0000-000000001434', '00000000-0000-0000-0000-00000000143a', 'viewer'),
  ('00000000-0000-0000-0000-000000001435', '00000000-0000-0000-0000-00000000143b', 'owner');

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
  reset role;
  perform set_config('request.jwt.claims', '', true);
end $$;
create temp table t_out (k text primary key, r jsonb) on commit drop;
grant all on t_out to authenticated;
grant execute on function pg_temp.expect(boolean, text), pg_temp.state_of(text), pg_temp.login(uuid), pg_temp.logout() to authenticated;

-- Hoje no fuso do estúdio (o caixa usa o dia do estúdio, não o dia UTC).
create function pg_temp.today() returns date language sql as $$ select (now() at time zone 'Europe/Madrid')::date $$;

-- Lançamentos de antes da abertura: dois de hoje (entram no caixa ao abrir) e um de ontem (não entra).
insert into public.transactions (org_id, type, category, description, value, method, date, status) values
  ('00000000-0000-0000-0000-00000000143a', 'income',  'servico',  'Venda da manhã',   50, 'CASH',     pg_temp.today(),     'completed'),
  ('00000000-0000-0000-0000-00000000143a', 'expense', 'material', 'Compra por transf.', 20, 'TRANSFER', pg_temp.today(),     'completed'),
  ('00000000-0000-0000-0000-00000000143a', 'income',  'servico',  'Venda de ontem',   99, 'CASH',     pg_temp.today() - 1, 'completed');
select pg_temp.expect((select count(*) = 3 and bool_and(cash_session_id is null) from public.transactions where org_id = '00000000-0000-0000-0000-00000000143a'),
  'sem caixa aberto o lançamento fica sem caixa');

-- 1. Abrir: viewer não abre; valores e horários inválidos são recusados; recepção abre.
select pg_temp.login('00000000-0000-0000-0000-000000001434');
select pg_temp.expect(pg_temp.state_of($q$select public.open_cash_session_atomic('00000000-0000-0000-0000-00000000143a', 100, 'Ana')$q$) = '42501',
  'viewer não abre o caixa');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000001433');
select pg_temp.expect(pg_temp.state_of($q$select public.open_cash_session_atomic('00000000-0000-0000-0000-00000000143a', -1, 'Ana')$q$) = '22023',
  'troco negativo recusado');
select pg_temp.expect(pg_temp.state_of($q$select public.open_cash_session_atomic('00000000-0000-0000-0000-00000000143a', 100, '  ')$q$) = '22023',
  'responsável obrigatório');
select pg_temp.expect(pg_temp.state_of($q$select public.open_cash_session_atomic('00000000-0000-0000-0000-00000000143a', 100, 'Ana', now() + interval '2 hours')$q$) = '22023',
  'horário futuro recusado');
insert into t_out select 'open1', public.open_cash_session_atomic('00000000-0000-0000-0000-00000000143a', 100, 'Ana Recepção');
select pg_temp.expect(pg_temp.state_of($q$select public.open_cash_session_atomic('00000000-0000-0000-0000-00000000143a', 50, 'Outra')$q$) = 'P0001',
  'só um caixa aberto por estúdio');
select pg_temp.logout();

select pg_temp.expect((select (r->>'number')::int = 1 and (r->>'adopted')::int = 2 from t_out where k = 'open1'),
  'caixa nº 1 aberto adotando os 2 lançamentos de hoje sem caixa');
select pg_temp.expect((select count(*) = 1 from public.cash_sessions where org_id = '00000000-0000-0000-0000-00000000143a'
  and status = 'open' and responsible_name = 'Ana Recepção' and opening_amount = 100 and business_date = pg_temp.today()), 'sessão gravada');
select pg_temp.expect((select count(*) = 1 from public.transactions where description = 'Venda de ontem' and cash_session_id is null),
  'lançamento de ontem não entra no caixa de hoje');

-- 2. Lançamentos novos levam o caixa aberto (comanda, sinal, estorno, manual...). Valor enviado de fora é ignorado.
insert into public.transactions (org_id, type, category, description, value, method, date, status) values
  ('00000000-0000-0000-0000-00000000143a', 'income',  'servico',      'Comanda 1 dinheiro',  80,  'CASH',        pg_temp.today(), 'completed'),
  ('00000000-0000-0000-0000-00000000143a', 'income',  'servico',      'Comanda 1 cartão',    120, 'CARD_DEBIT',  pg_temp.today(), 'completed'),
  ('00000000-0000-0000-0000-00000000143a', 'income',  'servico',      'Sinal Bizum',         30,  'BIZUM',       pg_temp.today(), 'completed'),
  ('00000000-0000-0000-0000-00000000143a', 'income',  'servico',      'Pago com crédito',    40,  'CLIENT_CREDIT', pg_temp.today(), 'completed'),
  ('00000000-0000-0000-0000-00000000143a', 'income',  'ajuste_saldo', 'Ajuste de saldo',     10,  'CASH',        pg_temp.today(), 'completed'),
  ('00000000-0000-0000-0000-00000000143a', 'expense', 'material',     'Compra de luvas',     15,  'CASH',        pg_temp.today(), 'completed'),
  ('00000000-0000-0000-0000-00000000143a', 'expense', 'conta_paga',   'Conta paga sem forma', 25, null,          pg_temp.today(), 'completed');
select pg_temp.expect((select count(*) = 7 from public.transactions t join public.cash_sessions s on s.id = t.cash_session_id
  where t.description in ('Comanda 1 dinheiro','Comanda 1 cartão','Sinal Bizum','Pago com crédito','Ajuste de saldo','Compra de luvas','Conta paga sem forma')
    and s.status = 'open'), 'os 7 lançamentos novos levam o caixa aberto');

-- 3. Suprimento e sangria: motivo obrigatório, valor positivo, sangria não passa do dinheiro da gaveta.
select pg_temp.login('00000000-0000-0000-0000-000000001433');
select pg_temp.expect(pg_temp.state_of($q$select public.add_cash_movement_atomic('00000000-0000-0000-0000-00000000143a', 'suprimento', 50, '')$q$) = '22023',
  'motivo obrigatório');
select pg_temp.expect(pg_temp.state_of($q$select public.add_cash_movement_atomic('00000000-0000-0000-0000-00000000143a', 'suprimento', 0, 'Troco')$q$) = '22023',
  'valor positivo');
select pg_temp.expect(pg_temp.state_of($q$select public.add_cash_movement_atomic('00000000-0000-0000-0000-00000000143a', 'outro', 5, 'Troco')$q$) = '22023',
  'tipo inválido');
select pg_temp.expect(pg_temp.state_of($q$select public.add_cash_movement_atomic('00000000-0000-0000-0000-00000000143a', 'sangria', 5000, 'Cofre')$q$) = 'P0001',
  'sangria maior que o dinheiro da gaveta recusada');
select public.add_cash_movement_atomic('00000000-0000-0000-0000-00000000143a', 'suprimento', 50, 'Reforço de troco');
select public.add_cash_movement_atomic('00000000-0000-0000-0000-00000000143a', 'sangria', 30, 'Levado ao cofre');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000001434');
select pg_temp.expect(pg_temp.state_of($q$select public.add_cash_movement_atomic('00000000-0000-0000-0000-00000000143a', 'suprimento', 5, 'Troco')$q$) = '42501',
  'viewer não movimenta o caixa');
select pg_temp.logout();

-- Esperado: dinheiro = 100 + 50 + 80 - 15 + 50 - 30 = 235; débito 120; Bizum 30; transferência -20.
select pg_temp.expect(public.cash_session_expected_internal('00000000-0000-0000-0000-00000000143a',
  (select id from public.cash_sessions where org_id = '00000000-0000-0000-0000-00000000143a' and status = 'open'))
  = '{"CASH": 235.00, "CARD_DEBIT": 120.00, "BIZUM": 30.00, "TRANSFER": -20.00}'::jsonb, 'esperado por forma');

-- 4. Fechar: dinheiro obrigatório, forma desconhecida, diferença exige motivo, comanda aberta exige confirmação.
insert into public.sales (id, org_id, client_name, status, subtotal, total, paid_amount) values
  ('00000000-0000-0000-0000-0000000143c1', '00000000-0000-0000-0000-00000000143a', 'Cliente aberta', 'draft', 40, 40, 0);

select pg_temp.login('00000000-0000-0000-0000-000000001433');
select pg_temp.expect(pg_temp.state_of(format($q$select public.close_cash_session_atomic('00000000-0000-0000-0000-00000000143a', %L, '{"CARD_DEBIT": 120}'::jsonb)$q$,
  (select id from public.cash_sessions where status = 'open' and org_id = '00000000-0000-0000-0000-00000000143a'))) = '22023', 'dinheiro contado obrigatório');
select pg_temp.expect(pg_temp.state_of(format($q$select public.close_cash_session_atomic('00000000-0000-0000-0000-00000000143a', %L, '{"CASH": 235, "PIX": 1}'::jsonb)$q$,
  (select id from public.cash_sessions where status = 'open' and org_id = '00000000-0000-0000-0000-00000000143a'))) = '22023', 'forma desconhecida recusada');
select pg_temp.expect(pg_temp.state_of(format($q$select public.close_cash_session_atomic('00000000-0000-0000-0000-00000000143a', %L, '{"CASH": 235, "CARD_DEBIT": 120}'::jsonb, null, null, null, true)$q$,
  (select id from public.cash_sessions where status = 'open' and org_id = '00000000-0000-0000-0000-00000000143a'))) = 'P0001',
  'Bizum e transferência esperados e não contados: recusa pedindo para conferir');
select pg_temp.expect(pg_temp.state_of(format($q$select public.close_cash_session_atomic('00000000-0000-0000-0000-00000000143a', %L, '{"CASH": 230, "CARD_DEBIT": 120, "BIZUM": 30, "TRANSFER": -20}'::jsonb, null, null, null, true)$q$,
  (select id from public.cash_sessions where status = 'open' and org_id = '00000000-0000-0000-0000-00000000143a'))) = '22023',
  'diferença de 5 sem motivo é recusada');
select pg_temp.expect(pg_temp.state_of(format($q$select public.close_cash_session_atomic('00000000-0000-0000-0000-00000000143a', %L, '{"CASH": 230, "CARD_DEBIT": 120, "BIZUM": 30, "TRANSFER": -20}'::jsonb, 'Troco dado a mais', null, null, false)$q$,
  (select id from public.cash_sessions where status = 'open' and org_id = '00000000-0000-0000-0000-00000000143a'))) = 'P0001',
  'comanda aberta sem confirmação impede o fechamento');
select pg_temp.expect(pg_temp.state_of(format($q$select public.close_cash_session_atomic('00000000-0000-0000-0000-00000000143a', %L, '{"CASH": 230, "CARD_DEBIT": 120, "BIZUM": 30, "TRANSFER": -20}'::jsonb, 'Troco dado a mais', null, 500, true)$q$,
  (select id from public.cash_sessions where status = 'open' and org_id = '00000000-0000-0000-0000-00000000143a'))) = '22023',
  'o que fica na gaveta não passa do contado');
insert into t_out select 'close1', public.close_cash_session_atomic('00000000-0000-0000-0000-00000000143a',
  (select id from public.cash_sessions where status = 'open' and org_id = '00000000-0000-0000-0000-00000000143a'),
  '{"CASH": 230, "CARD_DEBIT": 120, "BIZUM": 30, "TRANSFER": -20}'::jsonb, 'Troco dado a mais', 'Tudo conferido', 130, true);
select pg_temp.logout();

select pg_temp.expect((select (r->>'differenceTotal')::numeric = -5 and (r->'differences'->>'CASH')::numeric = -5 and (r->>'openComandas')::int = 1
  from t_out where k = 'close1'), 'fechamento devolve a diferença e as comandas abertas');
select pg_temp.expect((select status = 'closed' and difference_total = -5 and difference_reason = 'Troco dado a mais' and left_in_drawer = 130
  and (expected->>'CASH')::numeric = 235 and (counted->>'CASH')::numeric = 230 and open_comandas_at_close = 1 and closed_by is not null
  from public.cash_sessions where org_id = '00000000-0000-0000-0000-00000000143a' and number = 1), 'snapshot do fechamento gravado');

-- 5. Fechado não aceita movimento nem lançamento novo (o lançamento fica sem caixa).
select pg_temp.login('00000000-0000-0000-0000-000000001433');
select pg_temp.expect(pg_temp.state_of($q$select public.add_cash_movement_atomic('00000000-0000-0000-0000-00000000143a', 'suprimento', 5, 'Troco')$q$) = 'P0001',
  'caixa fechado não recebe movimento');
select pg_temp.expect(pg_temp.state_of(format($q$select public.close_cash_session_atomic('00000000-0000-0000-0000-00000000143a', %L, '{"CASH": 1}'::jsonb)$q$,
  (select id from public.cash_sessions where number = 1 and org_id = '00000000-0000-0000-0000-00000000143a'))) = 'P0001', 'não fecha duas vezes');
select pg_temp.logout();
insert into public.transactions (org_id, type, category, description, value, method, date, status, cash_session_id)
values ('00000000-0000-0000-0000-00000000143a', 'income', 'servico', 'Depois de fechar', 10, 'CASH', pg_temp.today(), 'completed',
  (select id from public.cash_sessions where number = 1 and org_id = '00000000-0000-0000-0000-00000000143a'));
select pg_temp.expect((select cash_session_id is null from public.transactions where description = 'Depois de fechar'),
  'lançamento depois de fechar fica sem caixa, mesmo enviando o id do caixa fechado');

-- 6. Reabrir: só proprietária/administração, com motivo; não com outro caixa aberto.
select pg_temp.login('00000000-0000-0000-0000-000000001433');
select pg_temp.expect(pg_temp.state_of(format($q$select public.reopen_cash_session_atomic('00000000-0000-0000-0000-00000000143a', %L, 'Esqueci uma venda')$q$,
  (select id from public.cash_sessions where number = 1 and org_id = '00000000-0000-0000-0000-00000000143a'))) = '42501', 'recepção não reabre');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000001432');
select pg_temp.expect(pg_temp.state_of(format($q$select public.reopen_cash_session_atomic('00000000-0000-0000-0000-00000000143a', %L, 'Esqueci uma venda')$q$,
  (select id from public.cash_sessions where number = 1 and org_id = '00000000-0000-0000-0000-00000000143a'))) = '42501', 'financeiro não reabre');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000001431');
select pg_temp.expect(pg_temp.state_of(format($q$select public.reopen_cash_session_atomic('00000000-0000-0000-0000-00000000143a', %L, 'ok')$q$,
  (select id from public.cash_sessions where number = 1 and org_id = '00000000-0000-0000-0000-00000000143a'))) = '22023', 'motivo da reabertura obrigatório');
insert into t_out select 'reopen1', public.reopen_cash_session_atomic('00000000-0000-0000-0000-00000000143a',
  (select id from public.cash_sessions where number = 1 and org_id = '00000000-0000-0000-0000-00000000143a'), 'Esqueci uma venda');
select pg_temp.expect(pg_temp.state_of(format($q$select public.reopen_cash_session_atomic('00000000-0000-0000-0000-00000000143a', %L, 'Esqueci uma venda')$q$,
  (select id from public.cash_sessions where number = 1 and org_id = '00000000-0000-0000-0000-00000000143a'))) = 'P0001', 'caixa aberto não reabre de novo');
select pg_temp.logout();
select pg_temp.expect((select status = 'open' and closed_at is null and expected is null and reopen_count = 1 and reopen_reason = 'Esqueci uma venda' and reopened_by is not null
  from public.cash_sessions where org_id = '00000000-0000-0000-0000-00000000143a' and number = 1), 'reaberto volta a aberto e guarda o motivo');

-- Fecha de novo, agora com a contagem certa: sem diferença não pede motivo e o motivo antigo não fica.
select pg_temp.login('00000000-0000-0000-0000-000000001433');
insert into t_out select 'close2', public.close_cash_session_atomic('00000000-0000-0000-0000-00000000143a',
  (select id from public.cash_sessions where number = 1 and org_id = '00000000-0000-0000-0000-00000000143a'),
  '{"CASH": 235, "CARD_DEBIT": 120, "BIZUM": 30, "TRANSFER": -20}'::jsonb, null, null, null, true);
select pg_temp.logout();
select pg_temp.expect((select (r->>'differenceTotal')::numeric = 0 from t_out where k = 'close2'), 'sem diferença');
select pg_temp.expect((select difference_reason is null and left_in_drawer = 235 from public.cash_sessions where org_id = '00000000-0000-0000-0000-00000000143a' and number = 1),
  'sem diferença não guarda motivo; o que fica na gaveta assume o contado');

-- 7. Só o último caixa reabre.
select pg_temp.login('00000000-0000-0000-0000-000000001433');
insert into t_out select 'open2', public.open_cash_session_atomic('00000000-0000-0000-0000-00000000143a', 235, 'Ana', null, 'Dia seguinte', false);
select pg_temp.logout();
select pg_temp.expect((select (r->>'number')::int = 2 and (r->>'adopted')::int = 0 from t_out where k = 'open2'), 'caixa nº 2');
select pg_temp.login('00000000-0000-0000-0000-000000001433');
select public.close_cash_session_atomic('00000000-0000-0000-0000-00000000143a',
  (select id from public.cash_sessions where number = 2 and org_id = '00000000-0000-0000-0000-00000000143a'), '{"CASH": 235}'::jsonb, null, null, null, true);
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000001431');
select pg_temp.expect(pg_temp.state_of(format($q$select public.reopen_cash_session_atomic('00000000-0000-0000-0000-00000000143a', %L, 'Quero conferir')$q$,
  (select id from public.cash_sessions where number = 1 and org_id = '00000000-0000-0000-0000-00000000143a'))) = 'P0001', 'só o último caixa reabre');
select pg_temp.logout();

-- 8. RLS: leitura por permissão e estúdio; nenhuma escrita direta.
select pg_temp.login('00000000-0000-0000-0000-000000001433');
select pg_temp.expect((select count(*) = 2 from public.cash_sessions), 'recepção lê os caixas do estúdio');
select pg_temp.expect((select count(*) = 2 from public.cash_movements), 'recepção lê os movimentos');
select pg_temp.expect(pg_temp.state_of($q$insert into public.cash_sessions (org_id, number, business_date, responsible_name) values ('00000000-0000-0000-0000-00000000143a', 9, current_date, 'x')$q$) = '42501',
  'sem insert direto em cash_sessions');
select pg_temp.expect(pg_temp.state_of($q$update public.cash_sessions set opening_amount = 0$q$) = '42501', 'sem update direto');
select pg_temp.expect(pg_temp.state_of($q$delete from public.cash_movements$q$) = '42501', 'sem delete direto');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000001434');
select pg_temp.expect((select count(*) = 0 from public.cash_sessions), 'viewer não lê caixas');
select pg_temp.logout();
select pg_temp.login('00000000-0000-0000-0000-000000001435');
select pg_temp.expect((select count(*) = 0 from public.cash_sessions), 'outro estúdio não lê');
select pg_temp.expect(pg_temp.state_of($q$select public.open_cash_session_atomic('00000000-0000-0000-0000-00000000143a', 1, 'Intrusa')$q$) = '42501', 'outro estúdio não abre');
select pg_temp.logout();

-- 9. Auditoria.
select pg_temp.expect((select count(*) filter (where operation = 'CASH_OPENED') = 2 and count(*) filter (where operation = 'CASH_CLOSED') = 3
  and count(*) filter (where operation = 'CASH_REOPENED') = 1 and count(*) filter (where operation = 'CASH_SUPPLY') = 1
  and count(*) filter (where operation = 'CASH_DRAIN') = 1
  from public.audit_logs where org_id = '00000000-0000-0000-0000-00000000143a'), 'auditoria de abrir, fechar, reabrir e movimentar');

\o
select 'caixa: ok' as resultado;
rollback;
