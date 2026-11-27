-- Saldo da cliente: adjust_client_balance_atomic e reverse_client_balance_entry_atomic.
--   * ajuste de crédito/débito grava saldo, extrato (balance_before/after), caixa e auditoria;
--   * estorno restaura o saldo, não reverte duas vezes, não reverte estorno;
--   * idempotência pela chave; limites do estúdio e dos papéis. Desfaz tudo no fim.
-- Papéis (SQL): ajustar = owner/admin/manager; estornar = owner/admin/manager/finance.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

-- Org A (3a): um usuário por papel. Org B (3b): outra dona e uma cliente.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000830', 'owner@saldo.local'),
  ('00000000-0000-0000-0000-000000000831', 'admin@saldo.local'),
  ('00000000-0000-0000-0000-000000000832', 'manager@saldo.local'),
  ('00000000-0000-0000-0000-000000000833', 'finance@saldo.local'),
  ('00000000-0000-0000-0000-000000000834', 'recep@saldo.local'),
  ('00000000-0000-0000-0000-000000000835', 'prof@saldo.local'),
  ('00000000-0000-0000-0000-000000000836', 'viewer@saldo.local'),
  ('00000000-0000-0000-0000-000000000837', 'donab@saldo.local'),
  ('00000000-0000-0000-0000-000000000838', 'fora@saldo.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-00000000083a', 'saldo-a', 'Saldo A'),
  ('00000000-0000-0000-0000-00000000083b', 'saldo-b', 'Saldo B');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000000830', '00000000-0000-0000-0000-00000000083a', 'owner'),
  ('00000000-0000-0000-0000-000000000831', '00000000-0000-0000-0000-00000000083a', 'admin'),
  ('00000000-0000-0000-0000-000000000832', '00000000-0000-0000-0000-00000000083a', 'manager'),
  ('00000000-0000-0000-0000-000000000833', '00000000-0000-0000-0000-00000000083a', 'finance'),
  ('00000000-0000-0000-0000-000000000834', '00000000-0000-0000-0000-00000000083a', 'receptionist'),
  ('00000000-0000-0000-0000-000000000835', '00000000-0000-0000-0000-00000000083a', 'professional'),
  ('00000000-0000-0000-0000-000000000836', '00000000-0000-0000-0000-00000000083a', 'viewer'),
  ('00000000-0000-0000-0000-000000000837', '00000000-0000-0000-0000-00000000083b', 'owner');
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-000000000839', '00000000-0000-0000-0000-00000000083a', 'Rocío Ibáñez'),
  ('00000000-0000-0000-0000-00000000083c', '00000000-0000-0000-0000-00000000083a', 'Nuria Pons'),
  ('00000000-0000-0000-0000-00000000083d', '00000000-0000-0000-0000-00000000083b', 'Cliente da B');
insert into public.staff_members (id, org_id, name) values
  ('00000000-0000-0000-0000-00000000083e', '00000000-0000-0000-0000-00000000083a', 'Karenn');
insert into public.services (id, org_id, name, price, duration_minutes) values
  ('00000000-0000-0000-0000-00000000083f', '00000000-0000-0000-0000-00000000083a', 'Drenagem', 80, 60);

create function pg_temp.expect(p_ok boolean, p_msg text) returns void language plpgsql as $$
begin
  if not coalesce(p_ok, false) then raise exception 'FALHOU: %', p_msg; end if;
end $$;
create function pg_temp.err(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return 'OK';
exception when others then
  return sqlstate || ' ' || sqlerrm;
end $$;
create function pg_temp.login(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;
grant execute on function pg_temp.expect(boolean, text), pg_temp.err(text), pg_temp.login(uuid) to authenticated;
create temp table t_ids (k text primary key, id uuid) on commit drop;
grant all on t_ids to authenticated;

-- ── 1. Ajuste manual: crédito de 100 e débito de 30 ──
select pg_temp.login('00000000-0000-0000-0000-000000000830');
select public.adjust_client_balance_atomic('00000000-0000-0000-0000-00000000083a', '00000000-0000-0000-0000-000000000839',
  'credit', 100, 'Troca de produto', '00000000-0000-0000-0000-000000000840');
select public.adjust_client_balance_atomic('00000000-0000-0000-0000-00000000083a', '00000000-0000-0000-0000-000000000839',
  'debit', 30, null, '00000000-0000-0000-0000-000000000841');
reset role; select set_config('request.jwt.claims', '', true);

select pg_temp.expect((select balance from public.clients where id = '00000000-0000-0000-0000-000000000839') = 70,
  'saldo = 100 - 30');
select pg_temp.expect((select amount = 100 and balance_before = 0 and balance_after = 100 and entry_type = 'manual_credit'
    and source_type = 'manual_adjustment' and transaction_id is not null
  from public.client_balance_entries where idempotency_key = '00000000-0000-0000-0000-000000000840'),
  'extrato do crédito: antes 0, depois 100');
select pg_temp.expect((select amount = -30 and balance_before = 100 and balance_after = 70 and entry_type = 'manual_debit'
  from public.client_balance_entries where idempotency_key = '00000000-0000-0000-0000-000000000841'),
  'extrato do débito: antes 100, depois 70, valor negativo');
select pg_temp.expect((select type = 'income' and value = 100 and category = 'ajuste_saldo' and status = 'completed'
    and t.description like '%Troca de produto%'
  from public.transactions t join public.client_balance_entries e on e.transaction_id = t.id
  where e.idempotency_key = '00000000-0000-0000-0000-000000000840'), 'crédito entra no caixa como receita ajuste_saldo');
select pg_temp.expect((select type = 'expense' and value = 30 from public.transactions t
  join public.client_balance_entries e on e.transaction_id = t.id
  where e.idempotency_key = '00000000-0000-0000-0000-000000000841'), 'débito entra no caixa como despesa');
select pg_temp.expect((select count(*) from public.audit_logs where org_id = '00000000-0000-0000-0000-00000000083a'
  and operation = 'balance_adjustment') = 2, 'dois ajustes, duas linhas de auditoria');

-- ── 2. Idempotência do ajuste ──
select pg_temp.login('00000000-0000-0000-0000-000000000830');
select pg_temp.expect((public.adjust_client_balance_atomic('00000000-0000-0000-0000-00000000083a', '00000000-0000-0000-0000-000000000839',
    'debit', 30, null, '00000000-0000-0000-0000-000000000841') ->> 'duplicate')::boolean,
  'mesma chave e mesma cliente: duplicate = true');
select pg_temp.expect((public.adjust_client_balance_atomic('00000000-0000-0000-0000-00000000083a', '00000000-0000-0000-0000-000000000839',
    'credit', 999, 'valor diferente', '00000000-0000-0000-0000-000000000841') ->> 'balance')::numeric = 70,
  'mesma chave com valor diferente devolve o resultado original, sem aplicar');
select pg_temp.expect(pg_temp.err($q$select public.adjust_client_balance_atomic('00000000-0000-0000-0000-00000000083a',
    '00000000-0000-0000-0000-00000000083c', 'credit', 30, null, '00000000-0000-0000-0000-000000000841')$q$) like '23514%',
  'mesma chave com outra cliente é recusada');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select count(*) from public.client_balance_entries where org_id = '00000000-0000-0000-0000-00000000083a') = 2
  and (select count(*) from public.transactions where org_id = '00000000-0000-0000-0000-00000000083a') = 2
  and (select balance from public.clients where id = '00000000-0000-0000-0000-000000000839') = 70
  and (select balance from public.clients where id = '00000000-0000-0000-0000-00000000083c') = 0,
  'repetir a chave não duplica extrato, caixa nem mexe em outra cliente');

-- ── 3. Validações do ajuste ──
select pg_temp.login('00000000-0000-0000-0000-000000000830');
select pg_temp.expect(pg_temp.err($q$select public.adjust_client_balance_atomic('00000000-0000-0000-0000-00000000083a',
    '00000000-0000-0000-0000-000000000839', 'credit', 0)$q$) like '22023%', 'valor zero recusado');
select pg_temp.expect(pg_temp.err($q$select public.adjust_client_balance_atomic('00000000-0000-0000-0000-00000000083a',
    '00000000-0000-0000-0000-000000000839', 'credit', -5)$q$) like '22023%', 'valor negativo recusado');
select pg_temp.expect(pg_temp.err($q$select public.adjust_client_balance_atomic('00000000-0000-0000-0000-00000000083a',
    '00000000-0000-0000-0000-000000000839', 'credit', 0.004)$q$) like '22023%', 'valor que arredonda para zero recusado');
select pg_temp.expect(pg_temp.err($q$select public.adjust_client_balance_atomic('00000000-0000-0000-0000-00000000083a',
    '00000000-0000-0000-0000-000000000839', 'credit', null)$q$) like '22023%', 'valor nulo recusado');
select pg_temp.expect(pg_temp.err($q$select public.adjust_client_balance_atomic('00000000-0000-0000-0000-00000000083a',
    '00000000-0000-0000-0000-000000000839', 'refund', 10)$q$) like '22023%', 'direção inválida recusada');
select pg_temp.expect(pg_temp.err($q$select public.adjust_client_balance_atomic('00000000-0000-0000-0000-00000000083a',
    gen_random_uuid(), 'credit', 10)$q$) like 'P0002%', 'cliente inexistente recusada');
select pg_temp.expect(pg_temp.err($q$select public.adjust_client_balance_atomic('00000000-0000-0000-0000-00000000083a',
    '00000000-0000-0000-0000-00000000083d', 'credit', 10)$q$) like 'P0002%', 'cliente de outro estúdio recusada');
select pg_temp.expect(pg_temp.err($q$select public.adjust_client_balance_atomic('00000000-0000-0000-0000-00000000083b',
    '00000000-0000-0000-0000-00000000083d', 'credit', 10)$q$) like '42501%', 'dona da A não ajusta saldo na org B');
-- Débito maior que o saldo é permitido: o saldo vira dívida (negativo).
select pg_temp.expect((public.adjust_client_balance_atomic('00000000-0000-0000-0000-00000000083a', '00000000-0000-0000-0000-00000000083c',
    'debit', 12.34, 'cobrança manual') ->> 'balance')::numeric = -12.34, 'débito sem saldo vira dívida de 12,34');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select balance from public.clients where id = '00000000-0000-0000-0000-000000000839') = 70,
  'validações recusadas não mexem no saldo');
select pg_temp.expect((select count(*) from public.client_balance_entries where org_id = '00000000-0000-0000-0000-00000000083a') = 3,
  'validações recusadas não deixam extrato');

-- ── 4. Estorno: restaura o saldo, com contrapartida no caixa ──
insert into t_ids select 'e_credit', id from public.client_balance_entries where idempotency_key = '00000000-0000-0000-0000-000000000840';
insert into t_ids select 'e_debit',  id from public.client_balance_entries where idempotency_key = '00000000-0000-0000-0000-000000000841';
select pg_temp.login('00000000-0000-0000-0000-000000000830');
select pg_temp.expect((public.reverse_client_balance_entry_atomic('00000000-0000-0000-0000-00000000083a',
    (select id from t_ids where k = 'e_debit'), 'Lançado por engano', '00000000-0000-0000-0000-000000000842') ->> 'balance')::numeric = 100,
  'estornar o débito de 30 devolve o saldo para 100');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select r.entry_type = 'reversal' and r.amount = 30 and r.balance_before = 70 and r.balance_after = 100
    and r.reversal_of_entry_id = o.id and r.reversal_reason = 'Lançado por engano' and r.transaction_id is not null
    and o.reversed_by_entry_id = r.id and o.reversed_at is not null and o.reversed_by = '00000000-0000-0000-0000-000000000830'
  from public.client_balance_entries o join public.client_balance_entries r on r.reversal_of_entry_id = o.id
  where o.id = (select id from t_ids where k = 'e_debit')), 'estorno liga original e reversão nos dois sentidos');
select pg_temp.expect((select t.type = 'income' and t.value = 30 and t.category = 'ajuste_saldo' and t.status = 'completed'
  from public.transactions t join public.client_balance_entries r on r.transaction_id = t.id
  where r.reversal_of_entry_id = (select id from t_ids where k = 'e_debit')),
  'a despesa estornada gera receita de contrapartida de 30');
select pg_temp.expect((select count(*) from public.audit_logs where operation = 'balance_reversal'
  and record_id = (select id from t_ids where k = 'e_debit')) = 1, 'estorno auditado');

-- ── 5. Não reverte duas vezes, não reverte estorno ──
select pg_temp.login('00000000-0000-0000-0000-000000000830');
select pg_temp.expect(pg_temp.err($q$select public.reverse_client_balance_entry_atomic('00000000-0000-0000-0000-00000000083a',
    (select id from t_ids where k = 'e_debit'), 'de novo', gen_random_uuid())$q$) like '23505%ja revertido%',
  'segundo estorno do mesmo lançamento (outra chave) é recusado');
select pg_temp.expect(pg_temp.err($q$select public.reverse_client_balance_entry_atomic('00000000-0000-0000-0000-00000000083a',
    (select id from t_ids where k = 'e_debit'), null, null)$q$) like '23505%ja revertido%',
  'segundo estorno sem chave também é recusado');
select pg_temp.expect(pg_temp.err($q$select public.reverse_client_balance_entry_atomic('00000000-0000-0000-0000-00000000083a',
    (select reversed_by_entry_id from public.client_balance_entries where id = (select id from t_ids where k = 'e_debit')),
    'estornar o estorno', gen_random_uuid())$q$) like '22023%',
  'o lançamento de estorno não pode ser estornado');
-- Repetir com a mesma chave devolve o mesmo resultado, sem lançar nada.
select pg_temp.expect((public.reverse_client_balance_entry_atomic('00000000-0000-0000-0000-00000000083a',
    (select id from t_ids where k = 'e_debit'), 'Lançado por engano', '00000000-0000-0000-0000-000000000842') ->> 'duplicate')::boolean,
  'mesma chave do estorno: duplicate = true');
select pg_temp.expect((public.reverse_client_balance_entry_atomic('00000000-0000-0000-0000-00000000083a',
    (select id from t_ids where k = 'e_debit'), 'Lançado por engano', '00000000-0000-0000-0000-000000000842') ->> 'balance')::numeric = 100,
  'repetição devolve o saldo da primeira vez (100)');
-- Chave já usada em outra operação (ajuste) não serve para estornar outro lançamento.
select pg_temp.expect(pg_temp.err($q$select public.reverse_client_balance_entry_atomic('00000000-0000-0000-0000-00000000083a',
    (select id from t_ids where k = 'e_credit'), null, '00000000-0000-0000-0000-000000000840')$q$) like '23505%',
  'chave de um ajuste não vale para estornar');
-- Mesma chave do estorno, mas apontando para outro lançamento: recusa.
select pg_temp.expect(pg_temp.err($q$select public.reverse_client_balance_entry_atomic('00000000-0000-0000-0000-00000000083a',
    (select id from t_ids where k = 'e_credit'), null, '00000000-0000-0000-0000-000000000842')$q$) like '23505%',
  'chave de um estorno não vale para outro lançamento');
select pg_temp.expect(pg_temp.err($q$select public.reverse_client_balance_entry_atomic('00000000-0000-0000-0000-00000000083a',
    null)$q$) like '22023%', 'lançamento nulo recusado');
select pg_temp.expect(pg_temp.err($q$select public.reverse_client_balance_entry_atomic('00000000-0000-0000-0000-00000000083a',
    gen_random_uuid())$q$) like 'P0002%', 'lançamento inexistente recusado');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select balance from public.clients where id = '00000000-0000-0000-0000-000000000839') = 100
  and (select count(*) from public.client_balance_entries where client_id = '00000000-0000-0000-0000-000000000839') = 3,
  'tentativas recusadas não mexem no saldo nem no extrato (2 lançamentos + 1 estorno)');

-- Estornar também o crédito de 100: saldo volta a zero e o extrato soma zero.
select pg_temp.login('00000000-0000-0000-0000-000000000833');
select pg_temp.expect((public.reverse_client_balance_entry_atomic('00000000-0000-0000-0000-00000000083a',
    (select id from t_ids where k = 'e_credit'), 'cliente desistiu') ->> 'balance')::numeric = 0, 'financeiro estorna o crédito: saldo 0');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select coalesce(sum(amount), 0) from public.client_balance_entries
  where client_id = '00000000-0000-0000-0000-000000000839') = 0
  and (select balance from public.clients where id = '00000000-0000-0000-0000-000000000839') = 0,
  'soma do extrato = saldo da cliente = 0');
select pg_temp.expect((select bool_and(balance_before + amount = balance_after) from public.client_balance_entries
  where client_id = '00000000-0000-0000-0000-000000000839'), 'cada linha do extrato fecha (antes + valor = depois)');
select pg_temp.expect((select coalesce(sum(case type when 'income' then value else -value end), 0) from public.transactions
  where org_id = '00000000-0000-0000-0000-00000000083a' and client_id = '00000000-0000-0000-0000-000000000839'
    and category = 'ajuste_saldo') = 0, 'caixa de ajustes da cliente também fecha em zero');

-- ── 6. Limites do estúdio ──
-- A dona da A tenta estornar lançamento da B (e vice-versa): não existe para ela.
insert into public.client_balance_entries (id, org_id, client_id, entry_type, amount, balance_before, balance_after, source_type)
values ('00000000-0000-0000-0000-000000000843', '00000000-0000-0000-0000-00000000083b', '00000000-0000-0000-0000-00000000083d',
        'manual_credit', 10, 0, 10, 'manual_adjustment');
update public.clients set balance = 10 where id = '00000000-0000-0000-0000-00000000083d';
select pg_temp.login('00000000-0000-0000-0000-000000000830');
select pg_temp.expect(pg_temp.err($q$select public.reverse_client_balance_entry_atomic('00000000-0000-0000-0000-00000000083a',
    '00000000-0000-0000-0000-000000000843')$q$) like 'P0002%', 'lançamento de outro estúdio não é achado');
select pg_temp.expect(pg_temp.err($q$select public.reverse_client_balance_entry_atomic('00000000-0000-0000-0000-00000000083b',
    '00000000-0000-0000-0000-000000000843')$q$) like '42501%', 'dona da A não estorna passando a org B');
select pg_temp.login('00000000-0000-0000-0000-000000000838');
select pg_temp.expect(pg_temp.err($q$select public.reverse_client_balance_entry_atomic('00000000-0000-0000-0000-00000000083b',
    '00000000-0000-0000-0000-000000000843')$q$) like '42501%', 'quem não é membro não estorna');
select pg_temp.expect(pg_temp.err($q$select public.adjust_client_balance_atomic('00000000-0000-0000-0000-00000000083a',
    '00000000-0000-0000-0000-000000000839', 'credit', 1)$q$) like '42501%', 'quem não é membro não ajusta');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select balance from public.clients where id = '00000000-0000-0000-0000-00000000083d') = 10
  and (select reversed_by_entry_id is null from public.client_balance_entries where id = '00000000-0000-0000-0000-000000000843'),
  'lançamento da B segue intacto');

-- ── 7. Papéis (padrão da spec 37): ajustar = financeiro.manage (owner/admin/manager/finance); estornar = comanda.refund (idem) ──
-- Cada papel tenta um ajuste (cliente 3c) e um estorno de um lançamento próprio.
create temp table t_roles (role text primary key, uid uuid, can_adjust boolean, can_reverse boolean) on commit drop;
insert into t_roles values
  ('owner',        '00000000-0000-0000-0000-000000000830', true,  true),
  ('admin',        '00000000-0000-0000-0000-000000000831', true,  true),
  ('manager',      '00000000-0000-0000-0000-000000000832', true,  true),
  ('finance',      '00000000-0000-0000-0000-000000000833', true,  true),
  ('receptionist', '00000000-0000-0000-0000-000000000834', false, false),
  ('professional', '00000000-0000-0000-0000-000000000835', false, false),
  ('viewer',       '00000000-0000-0000-0000-000000000836', false, false);
grant select on t_roles to authenticated;
-- Um lançamento para cada papel tentar estornar (criado pela dona).
select pg_temp.login('00000000-0000-0000-0000-000000000830');
insert into t_ids
select 'r_' || role, (public.adjust_client_balance_atomic('00000000-0000-0000-0000-00000000083a', '00000000-0000-0000-0000-00000000083c',
  'credit', 1, 'para ' || role) ->> 'entryId')::uuid
from t_roles;
reset role; select set_config('request.jwt.claims', '', true);

do $$
declare r record; v_adj text; v_rev text;
begin
  for r in select * from t_roles order by role loop
    perform pg_temp.login(r.uid);
    v_adj := pg_temp.err(format($q$select public.adjust_client_balance_atomic('00000000-0000-0000-0000-00000000083a',
      '00000000-0000-0000-0000-00000000083c', 'credit', 2, 'papel %s')$q$, r.role));
    v_rev := pg_temp.err(format($q$select public.reverse_client_balance_entry_atomic('00000000-0000-0000-0000-00000000083a',
      (select id from t_ids where k = 'r_%s'))$q$, r.role));
    perform pg_temp.expect(case when r.can_adjust then v_adj = 'OK' else v_adj like '42501%' end, 'ajuste de saldo: papel ' || r.role);
    perform pg_temp.expect(case when r.can_reverse then v_rev = 'OK' else v_rev like '42501%' end, 'estorno de saldo: papel ' || r.role);
    reset role;
  end loop;
end $$;
select set_config('request.jwt.claims', '', true);
-- 4 ajustes de teste de papel permitidos + os lançamentos dos papéis; só os 4 estornos permitidos foram feitos.
select pg_temp.expect((select count(*) from public.client_balance_entries where client_id = '00000000-0000-0000-0000-00000000083c'
  and entry_type = 'reversal') = 4, 'só os 4 papéis permitidos estornaram');

-- ── 8. Dívida de comanda (sale_debit) também é estornável, sem lançamento no caixa ──
select pg_temp.login('00000000-0000-0000-0000-000000000830');
insert into t_ids values ('appt', public.create_appointment_atomic('00000000-0000-0000-0000-00000000083a',
  '00000000-0000-0000-0000-000000000839', '00000000-0000-0000-0000-00000000083e', '2031-04-01 10:00+00', '2031-04-01 11:00+00', 60,
  'Agendado', 'MANUAL', null, null, 80,
  '[{"service_id":"00000000-0000-0000-0000-00000000083f","service_name":"Drenagem","price":80}]'::jsonb, false));
select public.confirm_checkout_atomic('00000000-0000-0000-0000-00000000083a', jsonb_build_object(
  'request_id', '00000000-0000-0000-0000-000000000844', 'appointment_id', (select id from t_ids where k = 'appt'), 'mode', 'finalize',
  'items', jsonb_build_array(jsonb_build_object('item_type', 'service', 'item_id', '00000000-0000-0000-0000-00000000083f',
    'name', 'Drenagem', 'unit_price', 80, 'quantity', 1)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'CASH', 'amount', 30))));
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select balance from public.clients where id = '00000000-0000-0000-0000-000000000839') = -50,
  'pagamento parcial de 30/80 deixa a cliente devendo 50');
insert into t_ids select 'e_sale', id from public.client_balance_entries
  where client_id = '00000000-0000-0000-0000-000000000839' and entry_type = 'sale_debit';
create temp table t_tx_before on commit drop as
  select count(*)::int as n from public.transactions where org_id = '00000000-0000-0000-0000-00000000083a';
select pg_temp.login('00000000-0000-0000-0000-000000000830');
select pg_temp.expect((public.reverse_client_balance_entry_atomic('00000000-0000-0000-0000-00000000083a',
    (select id from t_ids where k = 'e_sale'), 'perdoou a dívida') ->> 'balance')::numeric = 0, 'estornar a dívida da comanda zera o saldo');
reset role; select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select n from t_tx_before) = (select count(*) from public.transactions where org_id = '00000000-0000-0000-0000-00000000083a'),
  'dívida de comanda não tinha lançamento no caixa, então o estorno também não cria');
select pg_temp.expect((select r.transaction_id is null and r.sale_id = o.sale_id and r.sale_id is not null
  from public.client_balance_entries o join public.client_balance_entries r on r.reversal_of_entry_id = o.id
  where o.id = (select id from t_ids where k = 'e_sale')), 'estorno da dívida mantém a ligação com a comanda');
-- NOTA: o estorno técnico só mexe no saldo e no extrato; a comanda segue 'partial' com balance 50
-- e o atendimento 'Pago Parcial'. Se a regra de negócio for perdoar a dívida, falta fechar a comanda.
select pg_temp.expect((select status = 'partial' and balance = 50 from public.sales
  where appointment_id = (select id from t_ids where k = 'appt')), 'comanda não é alterada pelo estorno técnico (comportamento atual)');

rollback;
\o
\echo 'saldo: ajuste e estorno: ok'
