-- Caixa do dia: abertura, sangria/suprimento, fechamento com conferência e reabertura (spec 32).
-- Encoding: UTF-8
set client_encoding = 'UTF8';
--
-- Antes o Caixa só listava as movimentações do dia. Agora o estúdio tem um caixa que se ABRE com o
-- troco em dinheiro e se FECHA com a contagem, guardando o esperado, o contado e a diferença:
--   * cash_sessions: uma linha por caixa (número sequencial no estúdio, responsável, horário,
--     troco inicial, snapshot do fechamento). Índice único parcial: um caixa aberto por estúdio.
--   * cash_movements: sangria (tira dinheiro da gaveta) e suprimento (reforço de troco), com motivo.
--   * transactions.cash_session_id: carimbado por gatilho com o caixa aberto no momento do lançamento
--     (comanda, sinal, estorno, lançamento manual, conta paga). Sem caixa aberto fica nulo e o app avisa;
--     ao abrir, os lançamentos do dia sem caixa podem ser incluídos.
--   * Funções atômicas (security definer): open/close/reopen_cash_session_atomic e
--     add_cash_movement_atomic. Gravam em audit_logs. Ninguém escreve nas tabelas pela API.
-- O esperado em dinheiro = troco + entradas em dinheiro - saídas em dinheiro + suprimentos - sangrias.
-- Cartão, Bizum e transferência: entradas - saídas na forma. Crédito da cliente, vale-presente, ajuste de
-- saldo e lançamento sem forma não passam pela gaveta e ficam fora da conferência.
-- Aditiva: tabelas e funções novas, uma coluna anulável e um gatilho em transactions.

create table if not exists public.cash_sessions (
  id                     uuid primary key default gen_random_uuid(),
  org_id                 uuid not null references public.organizations(id) on delete cascade,
  number                 integer not null check (number > 0),
  status                 text not null default 'open' check (status in ('open', 'closed')),
  business_date          date not null,
  opened_at              timestamptz not null default now(),
  opened_by              uuid references auth.users(id) on delete set null,
  responsible_name       text not null check (length(btrim(responsible_name)) between 1 and 80),
  opening_amount         numeric(12,2) not null default 0 check (opening_amount >= 0 and opening_amount <= 100000),
  opening_note           text check (opening_note is null or length(opening_note) <= 300),
  closed_at              timestamptz,
  closed_by              uuid references auth.users(id) on delete set null,
  expected               jsonb,
  counted                jsonb,
  differences            jsonb,
  difference_total       numeric(12,2),
  difference_reason      text check (difference_reason is null or length(difference_reason) <= 300),
  closing_notes          text check (closing_notes is null or length(closing_notes) <= 500),
  left_in_drawer         numeric(12,2) check (left_in_drawer is null or left_in_drawer >= 0),
  open_comandas_at_close integer,
  reopen_count           integer not null default 0,
  reopened_at            timestamptz,
  reopened_by            uuid references auth.users(id) on delete set null,
  reopen_reason          text,
  created_at             timestamptz not null default now(),
  constraint cash_sessions_id_org_key unique (id, org_id),
  constraint cash_sessions_org_number_key unique (org_id, number),
  constraint cash_sessions_closed_consistent check (
    (status = 'open' and closed_at is null) or (status = 'closed' and closed_at is not null)
  )
);
comment on table public.cash_sessions is
  'Caixa do dia (spec 32): abertura com troco, fechamento com esperado x contado. Escrita só pelas funções *_cash_session_atomic.';

create unique index if not exists cash_sessions_one_open_per_org on public.cash_sessions (org_id) where status = 'open';
create index if not exists cash_sessions_org_opened_idx on public.cash_sessions (org_id, opened_at desc);

create table if not exists public.cash_movements (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references public.organizations(id) on delete cascade,
  session_id  uuid not null,
  kind        text not null check (kind in ('sangria', 'suprimento')),
  amount      numeric(12,2) not null check (amount > 0 and amount <= 100000),
  reason      text not null check (length(btrim(reason)) between 3 and 200),
  created_by  uuid references auth.users(id) on delete set null,
  created_at  timestamptz not null default now(),
  constraint cash_movements_session_same_org foreign key (session_id, org_id)
    references public.cash_sessions (id, org_id) on delete cascade
);
comment on table public.cash_movements is
  'Sangria (retirada da gaveta) e suprimento (reforço de troco) de um caixa, sempre em dinheiro e com motivo.';
create index if not exists cash_movements_session_idx on public.cash_movements (session_id, created_at);
create index if not exists cash_movements_org_idx on public.cash_movements (org_id, created_at desc);

alter table public.transactions add column if not exists cash_session_id uuid;
alter table public.transactions
  add constraint transactions_cash_session_same_org foreign key (cash_session_id, org_id)
  references public.cash_sessions (id, org_id);
create index if not exists transactions_cash_session_idx on public.transactions (cash_session_id) where cash_session_id is not null;
comment on column public.transactions.cash_session_id is
  'Caixa aberto no momento do lançamento (gatilho). Nulo = lançado sem caixa aberto.';

-- RLS: leitura para quem vê o financeiro ou opera o caixa; escrita só pelas funções.
alter table public.cash_sessions enable row level security;
alter table public.cash_movements enable row level security;
revoke all on public.cash_sessions from public, anon, authenticated;
revoke all on public.cash_movements from public, anon, authenticated;
grant select on public.cash_sessions to authenticated;
grant select on public.cash_movements to authenticated;

drop policy if exists cash_sessions_select on public.cash_sessions;
create policy cash_sessions_select on public.cash_sessions for select to authenticated
  using (public.has_permission(org_id, 'financeiro.view') or public.has_permission(org_id, 'comanda.operate'));
drop policy if exists cash_movements_select on public.cash_movements;
create policy cash_movements_select on public.cash_movements for select to authenticated
  using (public.has_permission(org_id, 'financeiro.view') or public.has_permission(org_id, 'comanda.operate'));

-- Gatilho: todo lançamento novo leva o caixa aberto do estúdio (ou nulo). Sempre sobrescreve o valor
-- recebido, para ninguém empurrar lançamento para um caixa já fechado.
create or replace function public.stamp_transaction_cash_session()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  select s.id into new.cash_session_id
  from public.cash_sessions s
  where s.org_id = new.org_id and s.status = 'open'
  limit 1;
  return new;
end;
$$;
revoke all on function public.stamp_transaction_cash_session() from public, anon, authenticated;

drop trigger if exists trg_transactions_stamp_cash_session on public.transactions;
create trigger trg_transactions_stamp_cash_session
before insert on public.transactions
for each row execute function public.stamp_transaction_cash_session();

-- Esperado por forma de pagamento de um caixa (interna; o app só lê o resultado gravado no fechamento).
create or replace function public.cash_session_expected_internal(p_org_id uuid, p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_opening numeric(12,2);
  v_supply numeric(12,2);
  v_drain numeric(12,2);
  v_result jsonb;
  r record;
begin
  select s.opening_amount into v_opening
  from public.cash_sessions s where s.id = p_session_id and s.org_id = p_org_id;
  if not found then
    return null;
  end if;
  select coalesce(sum(m.amount) filter (where m.kind = 'suprimento'), 0),
         coalesce(sum(m.amount) filter (where m.kind = 'sangria'), 0)
    into v_supply, v_drain
  from public.cash_movements m where m.session_id = p_session_id and m.org_id = p_org_id;

  v_result := pg_catalog.jsonb_build_object('CASH', pg_catalog.round(v_opening + v_supply - v_drain, 2));
  for r in
    select pg_catalog.upper(pg_catalog.btrim(t.method)) as method,
           pg_catalog.round(sum(case t.type when 'income' then t.value else -t.value end), 2) as net
    from public.transactions t
    where t.org_id = p_org_id and t.cash_session_id = p_session_id and t.status = 'completed'
      and coalesce(t.category, '') <> 'ajuste_saldo'
      and pg_catalog.upper(pg_catalog.btrim(coalesce(t.method, ''))) in ('CASH', 'CARD_DEBIT', 'CARD_CREDIT', 'BIZUM', 'TRANSFER')
    group by 1
  loop
    v_result := v_result || pg_catalog.jsonb_build_object(
      r.method, pg_catalog.round(coalesce((v_result ->> r.method)::numeric, 0) + r.net, 2));
  end loop;
  return v_result;
end;
$$;
revoke all on function public.cash_session_expected_internal(uuid, uuid) from public, anon, authenticated;

-- Abrir o caixa.
create or replace function public.open_cash_session_atomic(
  p_org_id uuid,
  p_opening_amount numeric,
  p_responsible text,
  p_opened_at timestamptz default null,
  p_note text default null,
  p_adopt_orphans boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_name text := nullif(pg_catalog.btrim(coalesce(p_responsible, '')), '');
  v_amount numeric(12,2) := pg_catalog.round(coalesce(p_opening_amount, 0), 2);
  v_at timestamptz := coalesce(p_opened_at, pg_catalog.now());
  v_note text := nullif(pg_catalog.btrim(coalesce(p_note, '')), '');
  v_tz text;
  v_date date;
  v_number integer;
  v_id uuid;
  v_adopted integer := 0;
  v_open public.cash_sessions;
begin
  if v_user is null then
    raise exception 'Sessão expirada' using errcode = '42501';
  end if;
  if not (public.has_permission(p_org_id, 'comanda.operate') or public.has_permission(p_org_id, 'financeiro.manage')) then
    raise exception 'Sem permissão para abrir o caixa' using errcode = '42501';
  end if;
  if v_name is null or pg_catalog.length(v_name) > 80 then
    raise exception 'Informe quem está abrindo o caixa' using errcode = '22023';
  end if;
  if v_amount < 0 or v_amount > 100000 then
    raise exception 'Valor inicial inválido' using errcode = '22023';
  end if;
  if v_at > pg_catalog.now() + interval '5 minutes' then
    raise exception 'O horário de abertura não pode ser no futuro' using errcode = '22023';
  end if;
  if v_at < pg_catalog.now() - interval '7 days' then
    raise exception 'O horário de abertura é antigo demais' using errcode = '22023';
  end if;
  if v_note is not null and pg_catalog.length(v_note) > 300 then
    raise exception 'Observação longa demais' using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_org_id::text || ':cash-open', 0));

  select * into v_open from public.cash_sessions s where s.org_id = p_org_id and s.status = 'open';
  if found then
    raise exception 'Já existe um caixa aberto (nº %, de %). Feche-o antes de abrir outro.',
      v_open.number, pg_catalog.to_char(v_open.business_date, 'DD/MM/YYYY') using errcode = 'P0001';
  end if;

  select coalesce(nullif(o.timezone, ''), 'UTC') into v_tz from public.organizations o where o.id = p_org_id;
  if v_tz is null then
    raise exception 'Estúdio não encontrado' using errcode = 'P0002';
  end if;
  v_date := (v_at at time zone v_tz)::date;
  select coalesce(max(s.number), 0) + 1 into v_number from public.cash_sessions s where s.org_id = p_org_id;

  insert into public.cash_sessions (org_id, number, status, business_date, opened_at, opened_by, responsible_name, opening_amount, opening_note)
  values (p_org_id, v_number, 'open', v_date, v_at, v_user, v_name, v_amount, v_note)
  returning id into v_id;

  if coalesce(p_adopt_orphans, true) then
    update public.transactions t
       set cash_session_id = v_id
     where t.org_id = p_org_id and t.cash_session_id is null and t.status = 'completed' and t.date = v_date;
    get diagnostics v_adopted = row_count;
  end if;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (p_org_id, v_user, 'cash_sessions', 'CASH_OPENED', v_id, null,
    pg_catalog.jsonb_build_object('number', v_number, 'business_date', v_date, 'opening_amount', v_amount,
      'responsible', v_name, 'adopted_transactions', v_adopted));

  return pg_catalog.jsonb_build_object('sessionId', v_id, 'number', v_number, 'adopted', v_adopted);
end;
$$;
revoke all on function public.open_cash_session_atomic(uuid, numeric, text, timestamptz, text, boolean) from public, anon;
grant execute on function public.open_cash_session_atomic(uuid, numeric, text, timestamptz, text, boolean) to authenticated;

-- Sangria (retirada) e suprimento (reforço de troco) no caixa aberto.
create or replace function public.add_cash_movement_atomic(
  p_org_id uuid,
  p_kind text,
  p_amount numeric,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_amount numeric(12,2) := pg_catalog.round(coalesce(p_amount, 0), 2);
  v_reason text := nullif(pg_catalog.btrim(coalesce(p_reason, '')), '');
  v_session public.cash_sessions;
  v_cash numeric(12,2);
  v_id uuid;
begin
  if v_user is null then
    raise exception 'Sessão expirada' using errcode = '42501';
  end if;
  if not (public.has_permission(p_org_id, 'comanda.operate') or public.has_permission(p_org_id, 'financeiro.manage')) then
    raise exception 'Sem permissão para movimentar o caixa' using errcode = '42501';
  end if;
  if p_kind is null or p_kind not in ('sangria', 'suprimento') then
    raise exception 'Tipo de movimento inválido' using errcode = '22023';
  end if;
  if v_amount <= 0 or v_amount > 100000 then
    raise exception 'Informe um valor maior que zero' using errcode = '22023';
  end if;
  if v_reason is null or pg_catalog.length(v_reason) < 3 or pg_catalog.length(v_reason) > 200 then
    raise exception 'Informe o motivo (de 3 a 200 caracteres)' using errcode = '22023';
  end if;

  select * into v_session from public.cash_sessions s where s.org_id = p_org_id and s.status = 'open' for update;
  if not found then
    raise exception 'Não há caixa aberto' using errcode = 'P0001';
  end if;

  if p_kind = 'sangria' then
    v_cash := (public.cash_session_expected_internal(p_org_id, v_session.id) ->> 'CASH')::numeric;
    if v_amount > v_cash then
      raise exception 'A retirada é maior que o dinheiro esperado na gaveta (%)', pg_catalog.to_char(v_cash, 'FM999999990.00') using errcode = 'P0001';
    end if;
  end if;

  insert into public.cash_movements (org_id, session_id, kind, amount, reason, created_by)
  values (p_org_id, v_session.id, p_kind, v_amount, v_reason, v_user)
  returning id into v_id;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (p_org_id, v_user, 'cash_movements', case p_kind when 'sangria' then 'CASH_DRAIN' else 'CASH_SUPPLY' end, v_id, null,
    pg_catalog.jsonb_build_object('session_id', v_session.id, 'number', v_session.number, 'amount', v_amount, 'reason', v_reason));

  return pg_catalog.jsonb_build_object('movementId', v_id, 'sessionId', v_session.id);
end;
$$;
revoke all on function public.add_cash_movement_atomic(uuid, text, numeric, text) from public, anon;
grant execute on function public.add_cash_movement_atomic(uuid, text, numeric, text) to authenticated;

-- Fechar o caixa com a contagem por forma de pagamento.
create or replace function public.close_cash_session_atomic(
  p_org_id uuid,
  p_session_id uuid,
  p_counted jsonb,
  p_difference_reason text default null,
  p_notes text default null,
  p_left_in_drawer numeric default null,
  p_ack_open_comandas boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_reason text := nullif(pg_catalog.btrim(coalesce(p_difference_reason, '')), '');
  v_notes text := nullif(pg_catalog.btrim(coalesce(p_notes, '')), '');
  v_session public.cash_sessions;
  v_tz text;
  v_expected jsonb;
  v_counted jsonb := '{}'::jsonb;
  v_diffs jsonb := '{}'::jsonb;
  v_total numeric(12,2) := 0;
  v_has_diff boolean := false;
  v_diff numeric(12,2);
  v_open_comandas integer;
  v_left numeric(12,2);
  r record;
begin
  if v_user is null then
    raise exception 'Sessão expirada' using errcode = '42501';
  end if;
  if not (public.has_permission(p_org_id, 'comanda.operate') or public.has_permission(p_org_id, 'financeiro.manage')) then
    raise exception 'Sem permissão para fechar o caixa' using errcode = '42501';
  end if;
  if p_counted is null or pg_catalog.jsonb_typeof(p_counted) <> 'object' then
    raise exception 'Informe a contagem' using errcode = '22023';
  end if;

  select * into v_session from public.cash_sessions s where s.id = p_session_id and s.org_id = p_org_id for update;
  if not found then
    raise exception 'Caixa não encontrado' using errcode = 'P0002';
  end if;
  if v_session.status <> 'open' then
    raise exception 'Este caixa já foi fechado' using errcode = 'P0001';
  end if;

  for r in select key, value from pg_catalog.jsonb_each_text(p_counted) loop
    if r.key not in ('CASH', 'CARD_DEBIT', 'CARD_CREDIT', 'BIZUM', 'TRANSFER') then
      raise exception 'Forma de pagamento inválida na contagem: %', r.key using errcode = '22023';
    end if;
    -- Negativo só nas formas sem gaveta (estorno maior que as entradas); o dinheiro contado nunca é negativo.
    if r.value !~ '^-?[0-9]{1,9}(\.[0-9]{1,2})?$' or (r.key = 'CASH' and r.value::numeric < 0) then
      raise exception 'Valor contado inválido em %', r.key using errcode = '22023';
    end if;
    v_counted := v_counted || pg_catalog.jsonb_build_object(r.key, pg_catalog.round(r.value::numeric, 2));
  end loop;
  if (v_counted ->> 'CASH') is null then
    raise exception 'Informe o dinheiro contado' using errcode = '22023';
  end if;

  v_expected := public.cash_session_expected_internal(p_org_id, p_session_id);
  for r in select key, value::numeric as amount from pg_catalog.jsonb_each_text(v_expected) loop
    if (v_counted ->> r.key) is null and r.amount <> 0 then
      raise exception 'Há lançamentos novos em %. Atualize a tela e confira a contagem de novo.', r.key using errcode = 'P0001';
    end if;
  end loop;

  for r in
    select k.key,
           coalesce((v_counted ->> k.key)::numeric, (v_expected ->> k.key)::numeric, 0) as counted,
           coalesce((v_expected ->> k.key)::numeric, 0) as expected
    from (select key from pg_catalog.jsonb_each_text(v_counted) union select key from pg_catalog.jsonb_each_text(v_expected)) k
  loop
    v_diff := pg_catalog.round(r.counted - r.expected, 2);
    v_diffs := v_diffs || pg_catalog.jsonb_build_object(r.key, v_diff);
    v_total := v_total + v_diff;
    if pg_catalog.abs(v_diff) >= 0.01 then
      v_has_diff := true;
    end if;
  end loop;
  if v_has_diff and (v_reason is null or pg_catalog.length(v_reason) < 5) then
    raise exception 'Explique a diferença (de 5 a 300 caracteres)' using errcode = '22023';
  end if;
  if v_reason is not null and pg_catalog.length(v_reason) > 300 then
    raise exception 'Explicação longa demais' using errcode = '22023';
  end if;
  if v_notes is not null and pg_catalog.length(v_notes) > 500 then
    raise exception 'Observação longa demais' using errcode = '22023';
  end if;

  v_left := pg_catalog.round(coalesce(p_left_in_drawer, (v_counted ->> 'CASH')::numeric), 2);
  if v_left < 0 or v_left > (v_counted ->> 'CASH')::numeric then
    raise exception 'O dinheiro que fica na gaveta não pode passar do contado' using errcode = '22023';
  end if;

  select coalesce(nullif(o.timezone, ''), 'UTC') into v_tz from public.organizations o where o.id = p_org_id;
  select count(*) into v_open_comandas
  from public.sales s
  where s.org_id = p_org_id and s.status in ('draft', 'partial')
    and s.created_at >= (v_session.business_date::timestamp at time zone v_tz);
  if v_open_comandas > 0 and not coalesce(p_ack_open_comandas, false) then
    raise exception 'Há % comanda(s) aberta(s) hoje. Confirme que quer fechar o caixa mesmo assim.', v_open_comandas using errcode = 'P0001';
  end if;

  update public.cash_sessions s
     set status = 'closed', closed_at = pg_catalog.now(), closed_by = v_user,
         expected = v_expected, counted = v_counted, differences = v_diffs, difference_total = v_total,
         difference_reason = case when v_has_diff then v_reason else null end,
         closing_notes = v_notes, left_in_drawer = v_left, open_comandas_at_close = v_open_comandas
   where s.id = p_session_id and s.org_id = p_org_id;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (p_org_id, v_user, 'cash_sessions', 'CASH_CLOSED', p_session_id, null,
    pg_catalog.jsonb_build_object('number', v_session.number, 'expected', v_expected, 'counted', v_counted,
      'differences', v_diffs, 'difference_total', v_total, 'reason', v_reason,
      'open_comandas', v_open_comandas, 'left_in_drawer', v_left));

  return pg_catalog.jsonb_build_object('sessionId', p_session_id, 'expected', v_expected, 'counted', v_counted,
    'differences', v_diffs, 'differenceTotal', v_total, 'openComandas', v_open_comandas);
end;
$$;
revoke all on function public.close_cash_session_atomic(uuid, uuid, jsonb, text, text, numeric, boolean) from public, anon;
grant execute on function public.close_cash_session_atomic(uuid, uuid, jsonb, text, text, numeric, boolean) to authenticated;

-- Reabrir o último caixa fechado (proprietária e administração), com motivo.
create or replace function public.reopen_cash_session_atomic(
  p_org_id uuid,
  p_session_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_reason text := nullif(pg_catalog.btrim(coalesce(p_reason, '')), '');
  v_session public.cash_sessions;
  v_last integer;
begin
  if v_user is null then
    raise exception 'Sessão expirada' using errcode = '42501';
  end if;
  if not public.has_org_role(p_org_id, array['owner', 'admin']) then
    raise exception 'Só a proprietária ou a administração reabrem um caixa' using errcode = '42501';
  end if;
  if v_reason is null or pg_catalog.length(v_reason) < 5 or pg_catalog.length(v_reason) > 300 then
    raise exception 'Informe o motivo da reabertura (de 5 a 300 caracteres)' using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_org_id::text || ':cash-open', 0));

  select * into v_session from public.cash_sessions s where s.id = p_session_id and s.org_id = p_org_id for update;
  if not found then
    raise exception 'Caixa não encontrado' using errcode = 'P0002';
  end if;
  if v_session.status <> 'closed' then
    raise exception 'Este caixa não está fechado' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.cash_sessions s where s.org_id = p_org_id and s.status = 'open') then
    raise exception 'Já existe outro caixa aberto. Feche-o antes de reabrir este.' using errcode = 'P0001';
  end if;
  select max(s.number) into v_last from public.cash_sessions s where s.org_id = p_org_id;
  if v_session.number <> v_last then
    raise exception 'Só o último caixa pode ser reaberto' using errcode = 'P0001';
  end if;

  update public.cash_sessions s
     set status = 'open', closed_at = null, closed_by = null,
         expected = null, counted = null, differences = null, difference_total = null,
         difference_reason = null, closing_notes = null, left_in_drawer = null, open_comandas_at_close = null,
         reopen_count = s.reopen_count + 1, reopened_at = pg_catalog.now(), reopened_by = v_user, reopen_reason = v_reason
   where s.id = p_session_id and s.org_id = p_org_id;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (p_org_id, v_user, 'cash_sessions', 'CASH_REOPENED', p_session_id,
    pg_catalog.jsonb_build_object('number', v_session.number, 'closed_at', v_session.closed_at, 'expected', v_session.expected,
      'counted', v_session.counted, 'differences', v_session.differences, 'difference_total', v_session.difference_total,
      'difference_reason', v_session.difference_reason),
    pg_catalog.jsonb_build_object('reason', v_reason, 'reopen_count', v_session.reopen_count + 1));

  return pg_catalog.jsonb_build_object('sessionId', p_session_id, 'number', v_session.number);
end;
$$;
revoke all on function public.reopen_cash_session_atomic(uuid, uuid, text) from public, anon;
grant execute on function public.reopen_cash_session_atomic(uuid, uuid, text) to authenticated;
