-- Matriz de papéis: os 7 papéis chamam as RPCs principais e o resultado (permitido/negado) é
-- comparado com a matriz ROLE_PERMISSIONS de src/domain/access.ts (spec 29, seção 3).
--
-- Origem da matriz: t_perm abaixo é cópia literal de ROLE_PERMISSIONS (conferida em 29 out 2026).
-- Se access.ts mudar, atualize t_perm; o teste de contagem logo abaixo avisa se a cópia desviar.
--
-- RPC → permissão da matriz:
--   checkout (confirm_checkout_atomic), sinal (register/void_appointment_deposit_atomic) → comanda.operate
--   estorno de saldo (reverse_client_balance_entry_atomic)                              → comanda.refund
--   ajuste de saldo (adjust_client_balance_atomic) → financeiro.manage (spec 37)
--   criar, mudar status, reagendar, cancelar série → agenda.manage
--   parte profissional da anamnese               → anamnese.fill_professional
--
-- Onde o banco difere da matriz, a diferença fica declarada em t_div (com BUG: quando o banco é MAIS
-- permissivo que a matriz). O teste falha se surgir diferença nova ou se uma declarada sumir
-- (nesse caso, remova a linha de t_div). Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email)
select ('00000000-0000-0000-0000-0000000008e' || n)::uuid, 'papel' || n || '@matriz.local' from generate_series(0, 7) n;
insert into public.organizations (id, slug, name) values ('00000000-0000-0000-0000-0000000008ea', 'matriz-a', 'Matriz A');
create temp table t_roles (role text primary key, uid uuid, ord int) on commit drop;
insert into t_roles values
  ('owner',        '00000000-0000-0000-0000-0000000008e0', 0),
  ('admin',        '00000000-0000-0000-0000-0000000008e1', 1),
  ('manager',      '00000000-0000-0000-0000-0000000008e2', 2),
  ('receptionist', '00000000-0000-0000-0000-0000000008e3', 3),
  ('professional', '00000000-0000-0000-0000-0000000008e4', 4),
  ('finance',      '00000000-0000-0000-0000-0000000008e5', 5),
  ('viewer',       '00000000-0000-0000-0000-0000000008e6', 6);
insert into public.user_roles (user_id, org_id, role)
select uid, '00000000-0000-0000-0000-0000000008ea', role from t_roles;
insert into public.clients (id, org_id, full_name) values
  ('00000000-0000-0000-0000-0000000008ec', '00000000-0000-0000-0000-0000000008ea', 'Amparo Ríos');
insert into public.services (id, org_id, name, price, duration_minutes) values
  ('00000000-0000-0000-0000-0000000008ed', '00000000-0000-0000-0000-0000000008ea', 'Drenagem', 10, 60);

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

-- ── Cópia de ROLE_PERMISSIONS (src/domain/access.ts) ──
create temp table t_perm (role text, perm text, primary key (role, perm)) on commit drop;
with allp(perm) as (values
  ('agenda.view_all'), ('agenda.view_own'), ('agenda.manage'), ('agenda.block_time'), ('agenda.override_conflict'),
  ('clientes.view'), ('clientes.manage'), ('clientes.view_clinical'),
  ('catalogo.view'), ('catalogo.manage'),
  ('comanda.operate'), ('comanda.refund'),
  ('financeiro.view'), ('financeiro.manage'),
  ('anamnese.view_status'), ('anamnese.fill_professional'), ('anamnese.manage_templates'),
  ('anamnese.override_checkout_gate'),
  ('mensagens.use'), ('mensagens.configure'),
  ('equipe.view'), ('equipe.manage'),
  ('acesso.manage'), ('acesso.grant_admin'),
  ('ajustes.manage'))
insert into t_perm
select 'owner', perm from allp
union all select 'admin', perm from allp where perm <> 'acesso.grant_admin'
union all select 'manager', perm from allp where perm not in ('acesso.grant_admin', 'acesso.manage', 'ajustes.manage')
union all select 'receptionist', perm from (values
  ('agenda.view_all'), ('agenda.view_own'), ('agenda.manage'), ('agenda.block_time'), ('clientes.view'), ('clientes.manage'),
  ('catalogo.view'), ('comanda.operate'), ('anamnese.view_status'), ('mensagens.use'), ('equipe.view')) v(perm)
union all select 'professional', perm from (values
  ('agenda.view_own'), ('agenda.block_time'), ('clientes.view'), ('clientes.view_clinical'), ('catalogo.view'),
  ('anamnese.view_status'), ('anamnese.fill_professional'), ('mensagens.use')) v(perm)
union all select 'finance', perm from (values
  ('agenda.view_all'), ('clientes.view'), ('catalogo.view'), ('comanda.operate'), ('comanda.refund'),
  ('financeiro.view'), ('financeiro.manage'), ('equipe.view')) v(perm)
union all select 'viewer', perm from (values
  ('agenda.view_all'), ('clientes.view'), ('catalogo.view'), ('equipe.view')) v(perm);
select pg_temp.expect((select string_agg(role || '=' || n, ',' order by role) from (select role, count(*) n from t_perm group by role) c)
  = 'admin=24,finance=8,manager=22,owner=25,professional=8,receptionist=11,viewer=4',
  'a cópia da matriz tem o tamanho esperado de cada papel (confira src/domain/access.ts)');

create temp table t_map (rpc text primary key, perm text not null) on commit drop;
insert into t_map values
  ('checkout', 'comanda.operate'), ('deposit_register', 'comanda.operate'), ('deposit_void', 'comanda.operate'),
  ('balance_reverse', 'comanda.refund'), ('balance_adjust', 'financeiro.manage'),
  ('appointment_create', 'agenda.manage'), ('status_change', 'agenda.manage'), ('reschedule', 'agenda.manage'),
  ('series_cancel', 'agenda.manage'), ('anamnese_professional', 'anamnese.fill_professional');

-- Diferenças conhecidas entre o banco (RPCs) e a matriz.
create temp table t_div (rpc text, role text, note text, primary key (rpc, role)) on commit drop;
-- Nenhuma: a divergência da profissional na agenda foi resolvida na fase 2b (spec 37).


-- ── Objetos de cada tentativa (um por RPC e papel), preparados pela dona ──
create temp table t_ids (k text primary key, id uuid) on commit drop;
create temp table t_out (rpc text, role text, res text, primary key (rpc, role)) on commit drop;
grant all on t_ids, t_out to authenticated;
grant select on t_roles, t_perm, t_map, t_div to authenticated;

create function pg_temp.mk(p_n int) returns uuid language sql as $$
  select public.create_appointment_atomic('00000000-0000-0000-0000-0000000008ea', '00000000-0000-0000-0000-0000000008ec', null,
    '2031-12-01 08:00+00'::timestamptz + make_interval(days => p_n), '2031-12-01 09:00+00'::timestamptz + make_interval(days => p_n),
    60, 'Agendado', 'MANUAL', null, null, 10,
    '[{"service_id":"00000000-0000-0000-0000-0000000008ed","service_name":"Drenagem","price":10}]'::jsonb, false)
$$;
grant execute on function pg_temp.mk(int) to authenticated;

select pg_temp.login('00000000-0000-0000-0000-0000000008e0');
do $$
declare r record; n int := 0;
begin
  for r in select * from t_roles order by ord loop
    n := n + 1;
    insert into t_ids values ('checkout|' || r.role, pg_temp.mk(n));
    insert into t_ids values ('deposit_register|' || r.role, pg_temp.mk(10 + n));
    insert into t_ids values ('status_change|' || r.role, pg_temp.mk(20 + n));
    insert into t_ids values ('reschedule|' || r.role, pg_temp.mk(30 + n));
    insert into t_ids values ('deposit_void|' || r.role,
      (public.register_appointment_deposit_atomic('00000000-0000-0000-0000-0000000008ea', pg_temp.mk(40 + n), 5, 'CASH', gen_random_uuid()) ->> 'deposit_id')::uuid);
    insert into t_ids values ('balance_reverse|' || r.role,
      (public.adjust_client_balance_atomic('00000000-0000-0000-0000-0000000008ea', '00000000-0000-0000-0000-0000000008ec', 'credit', 1) ->> 'entryId')::uuid);
  end loop;
end $$;
reset role; select set_config('request.jwt.claims', '', true);
-- Série (uma ocorrência futura em aberto por papel) e ficha com parte profissional, direto.
insert into t_ids select 'series_cancel|' || role, gen_random_uuid() from t_roles;
insert into public.appointments (org_id, client_id, client_name, start_at, end_at, duration_minutes, status, recurrence_id, recurrence_index)
select '00000000-0000-0000-0000-0000000008ea', '00000000-0000-0000-0000-0000000008ec', 'Amparo Ríos',
  '2032-01-10 10:00+00'::timestamptz + make_interval(days => ord), '2032-01-10 11:00+00'::timestamptz + make_interval(days => ord),
  60, 'Agendado', (select id from t_ids where k = 'series_cancel|' || t_roles.role), 1
from t_roles;
insert into t_ids select 'anamnese_professional|' || role, gen_random_uuid() from t_roles;
-- Cada ficha gerada pela pessoa do papel (created_by vem do banco, 20261114040000): a matriz mede permissão, não alcance.
do $$
declare r record;
begin
  for r in select uid, role from t_roles loop
    perform set_config('request.jwt.claims', json_build_object('sub', r.uid, 'role', 'authenticated')::text, true);
    insert into public.anamneses (id, org_id, client_name, status, public_token, requires_professional)
    values ((select id from t_ids where k = 'anamnese_professional|' || r.role), '00000000-0000-0000-0000-0000000008ea', 'Amparo Ríos',
      'pending', 'token-matriz-' || r.role || '-0123456789abcdef', true);
  end loop;
  perform set_config('request.jwt.claims', '', true);
end $$;

-- ── Chamada de cada RPC como cada papel ──
create function pg_temp.call(p_rpc text, p_role text) returns text language plpgsql as $$
declare
  v_id uuid := (select id from t_ids where k = p_rpc || '|' || p_role);
  v_org constant text := '00000000-0000-0000-0000-0000000008ea';
  v_sql text;
begin
  v_sql := case p_rpc
    when 'checkout' then format('select public.confirm_checkout_atomic(%L, %L::jsonb)', v_org, jsonb_build_object(
      'request_id', gen_random_uuid(), 'appointment_id', v_id, 'mode', 'finalize',
      'items', jsonb_build_array(jsonb_build_object('item_type', 'service', 'item_id', '00000000-0000-0000-0000-0000000008ed',
        'name', 'Drenagem', 'unit_price', 10, 'quantity', 1)),
      'payments', jsonb_build_array(jsonb_build_object('method', 'CASH', 'amount', 10)))::text)
    when 'deposit_register' then format('select public.register_appointment_deposit_atomic(%L, %L, 5, ''CASH'', gen_random_uuid())', v_org, v_id)
    when 'deposit_void' then format('select public.void_appointment_deposit_atomic(%L, %L)', v_org, v_id)
    when 'balance_reverse' then format('select public.reverse_client_balance_entry_atomic(%L, %L)', v_org, v_id)
    when 'balance_adjust' then format('select public.adjust_client_balance_atomic(%L, ''00000000-0000-0000-0000-0000000008ec'', ''credit'', 2)', v_org)
    when 'appointment_create' then format('select public.create_appointment_atomic(%L, ''00000000-0000-0000-0000-0000000008ec'', null, %L, %L, 60, ''Agendado'', ''MANUAL'', null, null, 0, ''[]''::jsonb, false)',
      v_org, '2032-03-01 10:00+00'::timestamptz + make_interval(days => (select ord from t_roles where role = p_role)),
      '2032-03-01 11:00+00'::timestamptz + make_interval(days => (select ord from t_roles where role = p_role)))
    when 'status_change' then format('select public.set_appointment_status_atomic(%L, %L, ''Confirmado'')', v_org, v_id)
    when 'reschedule' then format('select public.reschedule_appointment_atomic(%L, %L, ''2032-02-01 10:00+00'')', v_org, v_id)
    when 'series_cancel' then format('select public.cancel_recurrence_series_atomic(%L, %L)', v_org, v_id)
    when 'anamnese_professional' then format('select public.anamnese_save_professional(%L, %L, ''{"phototype":"III"}''::jsonb, ''{}''::jsonb, '''', false)', v_org, v_id)
  end;
  return pg_temp.err(v_sql);
end $$;
grant execute on function pg_temp.call(text, text) to authenticated;

do $$
declare r record; m record;
begin
  for r in select * from t_roles order by ord loop
    perform pg_temp.login(r.uid);
    for m in select rpc from t_map order by rpc loop
      insert into t_out values (m.rpc, r.role, pg_temp.call(m.rpc, r.role));
    end loop;
    reset role;
  end loop;
end $$;
select set_config('request.jwt.claims', '', true);

-- Toda recusa tem que ser de permissão (42501), nunca outro erro escondido.
select pg_temp.expect((select count(*) = 70 from t_out), '7 papéis × 10 RPCs = 70 tentativas');
select pg_temp.expect((select string_agg(rpc || '/' || role || ': ' || res, '; ') from t_out where res <> 'OK' and res not like '42501%') is null,
  'recusa que não é de permissão: ' || coalesce((select string_agg(rpc || '/' || role || ': ' || res, '; ') from t_out where res <> 'OK' and res not like '42501%'), ''));
-- Permitido/negado no banco contra a matriz (com as diferenças declaradas).
select pg_temp.expect((select string_agg(o.rpc || '/' || o.role || ' banco=' || (o.res = 'OK') || ' matriz=' || m.allowed, '; ')
    from t_out o
    join (select t.rpc, r.role, exists (select 1 from t_perm p where p.role = r.role and p.perm = t.perm) as allowed
          from t_map t cross join t_roles r) m using (rpc, role)
    where (o.res = 'OK') is distinct from (m.allowed <> exists (select 1 from t_div d where d.rpc = o.rpc and d.role = o.role))) is null,
  'RPC fora da matriz sem estar em t_div: ' || coalesce((select string_agg(o.rpc || '/' || o.role || ' banco=' || (o.res = 'OK') || ' matriz=' || m.allowed, '; ')
    from t_out o
    join (select t.rpc, r.role, exists (select 1 from t_perm p where p.role = r.role and p.perm = t.perm) as allowed
          from t_map t cross join t_roles r) m using (rpc, role)
    where (o.res = 'OK') is distinct from (m.allowed <> exists (select 1 from t_div d where d.rpc = o.rpc and d.role = o.role))), ''));
select pg_temp.expect((select count(*) = 0 from t_div), 'nenhuma diferença declarada');

-- Efeito colateral só dos permitidos: nada foi gravado por quem foi barrado.
select pg_temp.expect((select count(*) from public.sales) = 5, 'checkout: 5 papéis permitidos geraram venda (owner, admin, manager, receptionist, finance)');
select pg_temp.expect((select count(*) from public.appointment_deposits where status = 'cancelled') = 5, 'void de sinal: 5 papéis permitidos');
select pg_temp.expect((select count(*) from public.appointments where start_at >= '2032-03-01' and start_at < '2032-03-09') = 4,
  'criar atendimento: os 4 papéis da matriz (owner, admin, manager, receptionist)');
select pg_temp.expect((select count(*) from public.anamneses where professional_data is not null) = 4,
  'parte profissional: owner, admin, manager e professional gravaram');
select pg_temp.expect((select count(*) from public.appointments where recurrence_id is not null and status = 'Cancelado') = 4,
  'cancelar série: owner, admin, manager e receptionist');

-- ── Conceder papéis (desde 20261114060500: só pela função team_grant_access) ──
-- Gravação direta em user_roles: recusada para todos os papéis (49 tentativas). Pela função: a dona dá qualquer papel
-- menos proprietária; a administração dá os operacionais (sem acesso.grant_admin não dá Administração); quem não tem
-- acesso.manage não dá nenhum. Regra única no banco (access_assert_can_grant).
create temp table t_grant (actor text, target text, res text, direct text) on commit drop;
grant all on t_grant to authenticated;
do $$
declare a record; t record; v_res text; v_direct text;
begin
  for a in select * from t_roles order by ord loop
    for t in select role from t_roles order by ord loop
      perform pg_temp.login(a.uid);
      v_direct := pg_temp.err(format($q$insert into public.user_roles (user_id, org_id, role)
        values ('00000000-0000-0000-0000-0000000008e7', '00000000-0000-0000-0000-0000000008ea', %L)$q$, t.role));
      v_res := pg_temp.err(format($q$select public.team_grant_access('00000000-0000-0000-0000-0000000008ea',
        '00000000-0000-0000-0000-0000000008e7', 'Pessoa nova', %L, null)$q$, t.role));
      reset role;
      delete from public.user_roles where user_id = '00000000-0000-0000-0000-0000000008e7';
      insert into t_grant values (a.role, t.role, v_res, v_direct);
    end loop;
  end loop;
end $$;
select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select count(*) = 49 from t_grant), '7 × 7 tentativas de conceder papel');
select pg_temp.expect((select count(*) = 0 from t_grant where direct = 'OK'), 'gravação direta em user_roles: ninguém');
select pg_temp.expect((select string_agg(actor || '→' || target || ': ' || res, '; ') from t_grant
  where (res = 'OK') is distinct from (
    (actor = 'owner' and target <> 'owner') or (actor = 'admin' and target not in ('owner', 'admin')))) is null,
  'conceder papel difere da regra: ' || coalesce((select string_agg(actor || '→' || target || ': ' || res, '; ') from t_grant
  where (res = 'OK') is distinct from ((actor = 'owner' and target <> 'owner') or (actor = 'admin' and target not in ('owner', 'admin')))), ''));
select pg_temp.expect((select count(*) = 6 + 5 from t_grant where res = 'OK'), 'dona concede 6 papéis e administração 5');

rollback;
\o
\echo 'matriz de papéis: ok'
