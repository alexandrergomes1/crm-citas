-- Financeiro, Checkout e Fidelidade: leituras das telas em UMA ida ao banco cada (porte para o TanStack Start,
-- orçamento de chamadas). Antes (beauty-system): a visão geral fazia 5 a 7 consultas (e somava no app TODOS os
-- lançamentos do período), Comandas 4, Caixa 5 a 8, Comissões 4, Checkout ~13, venda avulsa 7.
-- Regras gerais:
--   * SECURITY INVOKER e search_path vazio: a RLS das tabelas continua valendo exatamente como nas consultas
--     que estas funções substituem. A permissão da tela (financeiro.view / comanda.operate) é conferida aqui
--     também: a tela nunca é a única barreira.
--   * Totais (visão geral, comissões, caixa) calculados no banco sobre o conjunto inteiro, nunca a partir de
--     uma lista cortada. Listas têm limite e avisam quando cortam (campo *_truncated).
--   * Fuso do estúdio lido do banco (organizations.timezone, NOT NULL) sempre que um mês ou dia vira intervalo de
--     horas; sem fuso fixo de reserva.
--   * Dinheiro com 2 casas (round(.., 2)), como as funções de gravação.
-- Encoding: UTF-8
set client_encoding = 'UTF8';

-- ─── Apoio: fuso, "hoje" e contadores do painel ───────────────────────────────────────────────────

-- Fuso do estúdio (sem estúdio visível para a pessoa = recusa). A coluna é NOT NULL; vazio também recusa.
create or replace function public.finance_org_timezone(p_org_id uuid)
returns text
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_tz text;
begin
  if (select auth.uid()) is null then
    raise exception 'Sessão expirada' using errcode = '42501';
  end if;
  if p_org_id is null or p_org_id not in (select public.auth_org_ids()) then
    raise exception 'Sem acesso a este estúdio.' using errcode = '42501';
  end if;
  select nullif(pg_catalog.btrim(o.timezone), '') into v_tz from public.organizations o where o.id = p_org_id;
  if v_tz is null then
    raise exception 'Fuso do estúdio não configurado' using errcode = '22023';
  end if;
  return v_tz;
end;
$$;

-- Recusa padrão das telas do financeiro.
create or replace function public.finance_require(p_org_id uuid, p_full boolean)
returns void
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  perform public.finance_org_timezone(p_org_id);
  if p_full then
    if not public.has_permission(p_org_id, 'financeiro.view') then
      raise exception 'Sem permissão para ver o financeiro' using errcode = '42501';
    end if;
  elsif not (public.has_permission(p_org_id, 'financeiro.view') or public.has_permission(p_org_id, 'comanda.operate')) then
    raise exception 'Sem permissão para ver o financeiro' using errcode = '42501';
  end if;
end;
$$;

-- Contadores do painel do financeiro: comandas em rascunho e contas vencidas (só para quem vê o financeiro).
-- Exige a permissão de alguma tela do Financeiro (financeiro.view ou comanda.operate).
create or replace function public.finance_shell_counts(p_org_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_today date;
begin
  perform public.finance_require(p_org_id, false);
  v_today := (pg_catalog.now() at time zone public.finance_org_timezone(p_org_id))::date;
  return pg_catalog.jsonb_build_object(
    'comandas', (select pg_catalog.count(*) from public.sales s where s.org_id = p_org_id and s.status = 'draft'),
    'contas', case when public.has_permission(p_org_id, 'financeiro.view') then
      (select pg_catalog.count(*) from public.payables p
        where p.org_id = p_org_id and p.status <> 'paid' and p.due_date < v_today)
      else 0 end);
end;
$$;

-- ─── Visão geral ──────────────────────────────────────────────────────────────────────────────────
-- Receita e despesa operacionais por dia (mesma regra de src/domain/finance.ts: receita = entrada que não é
-- ajuste de saldo nem crédito/vale; despesa = saída que não é ajuste), do início da comparação ao fim do período.
create or replace function public.finance_overview_screen(
  p_org_id uuid, p_start date, p_end date, p_cmp_start date, p_cmp_end date
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_open_appts uuid[];
  v_blocked integer := 0;
  v_entries jsonb;
  v_clients jsonb;
begin
  perform public.finance_require(p_org_id, true);
  if p_start is null or p_end is null or p_cmp_start is null or p_cmp_end is null
     or p_end < p_start or p_cmp_end < p_cmp_start or p_cmp_start > p_start or p_end - p_cmp_start > 800 then
    raise exception 'Período inválido' using errcode = '22023';
  end if;

  select coalesce(pg_catalog.array_agg(distinct s.appointment_id), '{}') into v_open_appts
  from public.sales s
  where s.org_id = p_org_id and s.status in ('draft', 'partial') and s.appointment_id is not null;

  -- Comandas travadas pela Ficha Profissional: só para quem pode ver o status das fichas (como antes).
  if pg_catalog.cardinality(v_open_appts) > 0 and public.has_permission(p_org_id, 'anamnese.view_status') then
    select pg_catalog.count(distinct f.appointment_id) into v_blocked
    from public.list_anamnese_status(p_org_id, v_open_appts) f
    where f.requires_professional and f.professional_completed_at is null;
  end if;

  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
           'id', t.id, 'created_at', t.created_at, 'date', t.date, 'description', t.description,
           'client_name', t.client_name, 'type', t.type, 'value', t.value, 'method', t.method)
           order by t.created_at desc, t.id), '[]'::jsonb)
  into v_entries
  from (select x.* from public.transactions x
        where x.org_id = p_org_id and x.status = 'completed' and x.date between p_start and p_end
        order by x.created_at desc, x.id limit 201) t;

  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', c.id, 'name', c.full_name)
           order by c.full_name, c.id), '[]'::jsonb)
  into v_clients
  from (select x.id, x.full_name from public.clients x where x.org_id = p_org_id
        order by x.full_name, x.id limit 301) c;

  return pg_catalog.jsonb_build_object(
    'days', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('date', d.date, 'revenue', d.revenue, 'expense', d.expense) order by d.date)
      from (
        select t.date,
               pg_catalog.round(coalesce(sum(t.value) filter (where t.type = 'income'
                 and pg_catalog.lower(pg_catalog.btrim(coalesce(t.category, ''))) <> 'ajuste_saldo'
                 and pg_catalog.lower(pg_catalog.btrim(coalesce(t.method, ''))) not in ('client_credit', 'gift_card')), 0), 2) as revenue,
               pg_catalog.round(coalesce(sum(t.value) filter (where t.type = 'expense'
                 and pg_catalog.lower(pg_catalog.btrim(coalesce(t.category, ''))) <> 'ajuste_saldo'), 0), 2) as expense
        from public.transactions t
        where t.org_id = p_org_id and t.status = 'completed' and t.date between p_cmp_start and p_end
        group by t.date
      ) d), '[]'::jsonb),
    'receivable', (
      select pg_catalog.jsonb_build_object('count', pg_catalog.count(*), 'amount', coalesce(pg_catalog.round(sum(s.balance), 2), 0))
      from public.sales s
      where s.org_id = p_org_id and s.status in ('draft', 'partial') and s.balance > 0.009),
    'blocked', v_blocked,
    'next_payable', (
      select pg_catalog.jsonb_build_object('description', p.description, 'value', p.value, 'due_date', p.due_date, 'status', p.status)
      from public.payables p where p.org_id = p_org_id and p.status <> 'paid'
      order by p.due_date, p.id limit 1),
    'entries', (select coalesce(pg_catalog.jsonb_agg(e) filter (where n <= 200), '[]'::jsonb)
                from (select e, pg_catalog.row_number() over () as n from pg_catalog.jsonb_array_elements(v_entries) e) z),
    'entries_truncated', pg_catalog.jsonb_array_length(v_entries) > 200,
    'clients', (select coalesce(pg_catalog.jsonb_agg(c) filter (where n <= 300), '[]'::jsonb)
                from (select c, pg_catalog.row_number() over () as n from pg_catalog.jsonb_array_elements(v_clients) c) z),
    'clients_truncated', pg_catalog.jsonb_array_length(v_clients) > 300,
    'user_name', (select pr.full_name from public.profiles pr
                  where pr.org_id = p_org_id and pr.user_id = (select auth.uid()) limit 1),
    'counts', public.finance_shell_counts(p_org_id)
  );
end;
$$;

-- ─── Comandas do mês ──────────────────────────────────────────────────────────────────────────────
create or replace function public.finance_comandas_screen(p_org_id uuid, p_month text)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_tz text;
  v_from timestamptz;
  v_to timestamptz;
  v_rows jsonb;
  v_pending jsonb := '{}'::jsonb;
  v_open_appts uuid[];
begin
  perform public.finance_require(p_org_id, false);
  if p_month is null or p_month !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then
    raise exception 'Período inválido' using errcode = '22023';
  end if;
  v_tz := public.finance_org_timezone(p_org_id);
  v_from := ((p_month || '-01')::date)::timestamp at time zone v_tz;
  v_to := (((p_month || '-01')::date + interval '1 month')::date)::timestamp at time zone v_tz;

  -- Ficha Profissional pendente nas comandas abertas do mês (só para quem vê o status das fichas, como antes).
  select coalesce(pg_catalog.array_agg(distinct s.appointment_id), '{}') into v_open_appts
  from public.sales s
  where s.org_id = p_org_id and s.created_at >= v_from and s.created_at < v_to
    and s.status in ('draft', 'partial') and s.appointment_id is not null;
  if pg_catalog.cardinality(v_open_appts) > 0 and public.has_permission(p_org_id, 'anamnese.view_status') then
    select coalesce(pg_catalog.jsonb_object_agg(x.appointment_id, x.id), '{}'::jsonb) into v_pending
    from (
      select distinct on (f.appointment_id) f.appointment_id, f.id
      from public.list_anamnese_status(p_org_id, v_open_appts) f
      where f.requires_professional and f.professional_completed_at is null
      order by f.appointment_id, f.created_at, f.id desc
    ) x;
  end if;

  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
           'id', s.id, 'number', s.number, 'appointment_id', s.appointment_id, 'client_id', s.client_id,
           'client_name', s.client_name, 'status', s.status, 'total', s.total, 'paid_amount', s.paid_amount,
           'balance', s.balance, 'created_at', s.created_at,
           'appointment_start', (select a.start_at from public.appointments a where a.id = s.appointment_id and a.org_id = s.org_id),
           'client_phone', (select c.phone from public.clients c where c.id = s.client_id and c.org_id = s.org_id),
           'services', coalesce((select pg_catalog.jsonb_agg(i.name order by i.created_at, i.id)
                                 from public.sale_items i where i.sale_id = s.id and i.org_id = s.org_id), '[]'::jsonb),
           'payments', coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
                                   'method', pay.method, 'deposit', coalesce(pay.reference like 'DEPOSIT:%', false))
                                   order by pay.created_at, pay.id)
                                 from public.sale_payments pay where pay.sale_id = s.id and pay.org_id = s.org_id), '[]'::jsonb),
           'ficha_id', case when s.status in ('draft', 'partial') and s.appointment_id is not null
                            then v_pending ->> s.appointment_id::text end)
           order by s.created_at desc, s.id), '[]'::jsonb)
  into v_rows
  from (select x.* from public.sales x
        where x.org_id = p_org_id and x.created_at >= v_from and x.created_at < v_to
        order by x.created_at desc, x.id limit 5001) s;

  return pg_catalog.jsonb_build_object(
    'rows', (select coalesce(pg_catalog.jsonb_agg(r) filter (where n <= 5000), '[]'::jsonb)
             from (select r, pg_catalog.row_number() over () as n from pg_catalog.jsonb_array_elements(v_rows) r) z),
    'truncated', pg_catalog.jsonb_array_length(v_rows) > 5000,
    'counts', public.finance_shell_counts(p_org_id)
  );
end;
$$;

-- Totais do caixa para quem opera o caixa. A recepção (comanda.operate sem financeiro.view) não lê lançamentos
-- (RLS de transactions exige financeiro.view), mas abre, confere e fecha o caixa (spec 32): precisa do esperado por
-- forma. SECURITY DEFINER só para somar: confere o estúdio e a permissão do caixa antes, devolve somas por tipo,
-- forma, categoria conhecida (as outras como "outros") e situação (nenhum lançamento individual, nome ou descrição) e quantos lançamentos de hoje estão
-- sem caixa. Mesma regra de esperado de cash_session_expected_internal (as somas entram em summarizeCash na tela).
create or replace function public.finance_cash_totals(p_org_id uuid, p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tz text;
begin
  if (select auth.uid()) is null then
    raise exception 'Sessão expirada' using errcode = '42501';
  end if;
  if p_org_id is null or p_org_id not in (select public.auth_org_ids()) then
    raise exception 'Sem acesso a este estúdio.' using errcode = '42501';
  end if;
  if not (public.has_permission(p_org_id, 'financeiro.view') or public.has_permission(p_org_id, 'comanda.operate')) then
    raise exception 'Sem permissão para ver o caixa' using errcode = '42501';
  end if;
  select nullif(pg_catalog.btrim(o.timezone), '') into v_tz from public.organizations o where o.id = p_org_id;
  return pg_catalog.jsonb_build_object(
    'groups', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
               'type', g.type, 'method', g.method, 'category', g.category, 'status', g.status,
               'value', g.value, 'count', g.n) order by g.type, g.method, g.category, g.status)
      from (
        -- Só as categorias que a tela usa (ajuste de saldo fica fora da gaveta; sinal, estorno e conta paga têm
        -- rótulo próprio); as demais (texto livre do lançamento manual) entram somadas como "outros".
        select t.type, t.method,
               case when t.category in ('ajuste_saldo', 'sinal', 'estorno', 'conta_paga') then t.category else 'outros' end as category,
               t.status, pg_catalog.round(sum(t.value), 2) as value, pg_catalog.count(*) as n
        from public.transactions t
        join public.cash_sessions cs on cs.id = t.cash_session_id and cs.org_id = t.org_id
        where p_session_id is not null and t.org_id = p_org_id and t.cash_session_id = p_session_id
        group by 1, 2, 3, 4
      ) g), '[]'::jsonb),
    'orphans_today', (
      select pg_catalog.count(*) from public.transactions t
      where t.org_id = p_org_id and t.cash_session_id is null and t.status = 'completed'
        and t.date = (pg_catalog.now() at time zone v_tz)::date));
end;
$$;

-- ─── Caixa ────────────────────────────────────────────────────────────────────────────────────────
-- O caixa aberto (ou o escolhido entre os 40 últimos), seus lançamentos e movimentos, comandas abertas desde o
-- dia do caixa e o histórico. A lista de lançamentos tem limite (2000) e segue a RLS (só quem tem financeiro.view);
-- o resumo do caixa sai de tx_groups (finance_cash_totals), que soma TODOS os lançamentos do caixa, também para a
-- recepção.
create or replace function public.finance_caixa_screen(p_org_id uuid, p_session_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_tz text;
  v_open public.cash_sessions;
  v_shown public.cash_sessions;
  v_txs jsonb := '[]'::jsonb;
  v_moves jsonb := '[]'::jsonb;
  v_totals jsonb;
begin
  perform public.finance_require(p_org_id, false);
  v_tz := public.finance_org_timezone(p_org_id);

  select * into v_open from public.cash_sessions cs where cs.org_id = p_org_id and cs.status = 'open' limit 1;
  if p_session_id is not null then
    select h.* into v_shown from (
      select cs.* from public.cash_sessions cs where cs.org_id = p_org_id order by cs.number desc limit 40
    ) h where h.id = p_session_id;
  end if;
  if v_shown.id is null then
    v_shown := v_open;
  end if;
  v_totals := public.finance_cash_totals(p_org_id, v_shown.id);

  if v_shown.id is not null then
    select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
             'id', t.id, 'created_at', t.created_at, 'description', t.description, 'client_name', t.client_name,
             'type', t.type, 'value', t.value, 'method', t.method, 'category', t.category, 'sale_id', t.sale_id,
             'status', t.status) order by t.created_at desc, t.id), '[]'::jsonb)
    into v_txs
    from (select x.* from public.transactions x where x.org_id = p_org_id and x.cash_session_id = v_shown.id
          order by x.created_at desc, x.id limit 2001) t;

    select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
             'id', m.id, 'kind', m.kind, 'amount', m.amount, 'reason', m.reason, 'created_at', m.created_at,
             'by', (select pr.full_name from public.profiles pr where pr.org_id = p_org_id and pr.user_id = m.created_by limit 1))
             order by m.created_at desc, m.id), '[]'::jsonb)
    into v_moves
    from (select x.* from public.cash_movements x where x.org_id = p_org_id and x.session_id = v_shown.id
          order by x.created_at desc, x.id limit 1001) m;
  end if;

  return pg_catalog.jsonb_build_object(
    'open_id', v_open.id,
    'shown_id', v_shown.id,
    'history', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
               'id', h.id, 'number', h.number, 'status', h.status, 'business_date', h.business_date,
               'opened_at', h.opened_at, 'responsible_name', h.responsible_name, 'opening_amount', h.opening_amount,
               'opening_note', h.opening_note, 'closed_at', h.closed_at, 'expected', h.expected, 'counted', h.counted,
               'difference_total', h.difference_total, 'difference_reason', h.difference_reason,
               'closing_notes', h.closing_notes, 'left_in_drawer', h.left_in_drawer,
               'open_comandas_at_close', h.open_comandas_at_close, 'reopen_count', h.reopen_count,
               'reopen_reason', h.reopen_reason,
               'opened_by', (select pr.full_name from public.profiles pr where pr.org_id = p_org_id and pr.user_id = h.opened_by limit 1),
               'closed_by', (select pr.full_name from public.profiles pr where pr.org_id = p_org_id and pr.user_id = h.closed_by limit 1))
               order by h.number desc)
      from (
        select cs.* from public.cash_sessions cs where cs.org_id = p_org_id order by cs.number desc limit 40
      ) h), '[]'::jsonb),
    -- O caixa aberto pode estar fora dos 40 últimos? Não: é sempre o de número mais alto. Vai junto por garantia.
    'open', case when v_open.id is null then null else pg_catalog.jsonb_build_object(
               'id', v_open.id, 'number', v_open.number, 'status', v_open.status, 'business_date', v_open.business_date,
               'opened_at', v_open.opened_at, 'responsible_name', v_open.responsible_name,
               'opening_amount', v_open.opening_amount, 'opening_note', v_open.opening_note, 'closed_at', null,
               'expected', null, 'counted', null, 'difference_total', null, 'difference_reason', null,
               'closing_notes', null, 'left_in_drawer', null, 'open_comandas_at_close', null,
               'reopen_count', v_open.reopen_count, 'reopen_reason', v_open.reopen_reason,
               'opened_by', (select pr.full_name from public.profiles pr where pr.org_id = p_org_id and pr.user_id = v_open.opened_by limit 1),
               'closed_by', null) end,
    'txs', (select coalesce(pg_catalog.jsonb_agg(t) filter (where n <= 2000), '[]'::jsonb)
            from (select t, pg_catalog.row_number() over () as n from pg_catalog.jsonb_array_elements(v_txs) t) z),
    'txs_truncated', pg_catalog.jsonb_array_length(v_txs) > 2000,
    'tx_groups', v_totals -> 'groups',
    'movements', (select coalesce(pg_catalog.jsonb_agg(m) filter (where n <= 1000), '[]'::jsonb)
                  from (select m, pg_catalog.row_number() over () as n from pg_catalog.jsonb_array_elements(v_moves) m) z),
    'movements_truncated', pg_catalog.jsonb_array_length(v_moves) > 1000,
    'open_comandas', case when v_shown.status = 'open' then (
      select pg_catalog.jsonb_build_object(
               'count', pg_catalog.count(*),
               'amount', coalesce(pg_catalog.round(sum(greatest(0, s.total - s.paid_amount)), 2), 0))
      from public.sales s
      where s.org_id = p_org_id and s.status in ('draft', 'partial')
        and s.created_at >= (v_shown.business_date::timestamp at time zone v_tz))
      else pg_catalog.jsonb_build_object('count', 0, 'amount', 0) end,
    'orphans', case when v_open.id is null then (v_totals ->> 'orphans_today')::int else 0 end,
    'user_name', (select pr.full_name from public.profiles pr
                  where pr.org_id = p_org_id and pr.user_id = (select auth.uid()) limit 1),
    'counts', public.finance_shell_counts(p_org_id)
  );
end;
$$;

-- ─── Comissões do mês ─────────────────────────────────────────────────────────────────────────────
-- Mesma regra de close_commission_period_atomic e de src/domain/commissions.ts: vendas quitadas no mês (paid_at
-- no fuso do estúdio), base = subtotal − desconto (nunca negativa), comissão = base × % arredondada por venda.
-- Totais por profissional sobre TODAS as vendas; linhas de detalhe com limite (5000).
create or replace function public.finance_commissions_screen(p_org_id uuid, p_month text)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_tz text;
  v_from timestamptz;
  v_to timestamptz;
  v_abbr text;
  v_lines jsonb;
begin
  perform public.finance_require(p_org_id, true);
  if p_month is null or p_month !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then
    raise exception 'Período inválido' using errcode = '22023';
  end if;
  v_tz := public.finance_org_timezone(p_org_id);
  v_from := ((p_month || '-01')::date)::timestamp at time zone v_tz;
  v_to := (((p_month || '-01')::date + interval '1 month')::date)::timestamp at time zone v_tz;
  v_abbr := (array['jan','fev','mar','abr','mai','jun','jul','ago','set','out','nov','dez'])[pg_catalog.substr(p_month, 6, 2)::int];

  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
           'sale_id', l.id, 'staff_id', l.staff_id, 'when', l.at, 'client_name', l.client_name,
           'service', l.service, 'base', l.base, 'pct', l.pct, 'commission', l.commission)
           order by l.at desc, l.id), '[]'::jsonb)
  into v_lines
  from (
    select s.id, s.staff_id, coalesce(s.paid_at, s.created_at) as at, s.client_name,
           coalesce(nullif((select pg_catalog.string_agg(i.name, ' · ' order by i.created_at, i.id)
                              from public.sale_items i
                             where i.sale_id = s.id and i.org_id = s.org_id and pg_catalog.upper(i.item_type) = 'SERVICE'), ''), '—') as service,
           pg_catalog.round(greatest(0, s.subtotal - least(s.discount, s.subtotal)), 2) as base,
           coalesce(m.commission_pct, 0) as pct,
           pg_catalog.round(pg_catalog.round(greatest(0, s.subtotal - least(s.discount, s.subtotal)), 2) * coalesce(m.commission_pct, 0) / 100, 2) as commission
    from public.sales s
    join public.staff_members m on m.id = s.staff_id and m.org_id = s.org_id
    where s.org_id = p_org_id and s.status = 'paid' and s.paid_at >= v_from and s.paid_at < v_to
    order by coalesce(s.paid_at, s.created_at) desc, s.id
    limit 5001
  ) l;

  return pg_catalog.jsonb_build_object(
    'staff', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
               'id', m.id, 'name', coalesce(nullif(m.display_name, ''), m.name), 'role', m.role,
               'pct', coalesce(m.commission_pct, 0)) order by m.position, m.name, m.id)
      from public.staff_members m where m.org_id = p_org_id), '[]'::jsonb),
    'totals', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
               'staff_id', x.staff_id, 'attendances', x.attendances, 'revenue', x.revenue,
               'base', x.base, 'commission', x.commission))
      from (
        select s.staff_id, pg_catalog.count(*) as attendances, pg_catalog.round(sum(s.total), 2) as revenue,
               sum(pg_catalog.round(greatest(0, s.subtotal - least(s.discount, s.subtotal)), 2)) as base,
               sum(pg_catalog.round(pg_catalog.round(greatest(0, s.subtotal - least(s.discount, s.subtotal)), 2)
                   * coalesce(m.commission_pct, 0) / 100, 2)) as commission
        from public.sales s
        join public.staff_members m on m.id = s.staff_id and m.org_id = s.org_id
        where s.org_id = p_org_id and s.status = 'paid' and s.paid_at >= v_from and s.paid_at < v_to
        group by s.staff_id
      ) x), '[]'::jsonb),
    'lines', (select coalesce(pg_catalog.jsonb_agg(l) filter (where n <= 5000), '[]'::jsonb)
              from (select l, pg_catalog.row_number() over () as n from pg_catalog.jsonb_array_elements(v_lines) l) z),
    'lines_truncated', pg_catalog.jsonb_array_length(v_lines) > 5000,
    -- Contas já lançadas no fechamento: pela chave "commission:<profissional>:<mês>" (e ajustes) ou, nas antigas,
    -- pela descrição "Comissão <nome> · mmm/aaaa".
    'closed', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('staff_id', c.staff_id, 'value', c.value, 'status', c.status))
      from (
        select pg_catalog.split_part(p.source_key, ':', 2) as staff_id, p.value, p.status
        from public.payables p
        where p.org_id = p_org_id and p.category = 'comissao' and p.source_key like 'commission:%:' || p_month || '%'
        union all
        select m.id::text, p.value, p.status
        from public.payables p
        join public.staff_members m on m.org_id = p.org_id
         and p.description = 'Comissão ' || coalesce(nullif(m.display_name, ''), m.name) || ' · ' || v_abbr || '/' || pg_catalog.substr(p_month, 1, 4)
        where p.org_id = p_org_id and p.category = 'comissao' and p.source_key is null
      ) c), '[]'::jsonb),
    'counts', public.finance_shell_counts(p_org_id)
  );
end;
$$;

-- ─── Contas a pagar ───────────────────────────────────────────────────────────────────────────────
create or replace function public.finance_payables_screen(p_org_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_rows jsonb;
begin
  perform public.finance_require(p_org_id, true);
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
           'id', p.id, 'description', p.description, 'vendor', p.vendor, 'category', p.category, 'value', p.value,
           'due_date', p.due_date, 'status', p.status, 'recurrence', p.recurrence, 'notes', p.notes,
           'paid_date', p.paid_date,
           -- Só o nome: o caminho da fatura no armazenamento não vai para a tela.
           'invoice_name', case when p.invoice_path is not null then coalesce(p.invoice_name, 'Fatura') end)
           order by p.status = 'paid', p.due_date, p.id), '[]'::jsonb)
  into v_rows
  -- Não pagas primeiro: se a lista cortar no limite, saem só contas já pagas (as abertas e vencidas ficam todas).
  from (select x.* from public.payables x where x.org_id = p_org_id
        order by x.status = 'paid', x.due_date, x.id limit 2001) p;

  return pg_catalog.jsonb_build_object(
    'rows', (select coalesce(pg_catalog.jsonb_agg(r) filter (where n <= 2000), '[]'::jsonb)
             from (select r, pg_catalog.row_number() over () as n from pg_catalog.jsonb_array_elements(v_rows) r) z),
    'truncated', pg_catalog.jsonb_array_length(v_rows) > 2000,
    'counts', public.finance_shell_counts(p_org_id)
  );
end;
$$;

-- ─── Relatórios e DRE: período e comparação numa ida (as somas são as funções de 20261031610000) ─────
create or replace function public.finance_reports_screen(
  p_org_id uuid, p_kind text, p_start date, p_end date, p_cmp_start date, p_cmp_end date
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  perform public.finance_require(p_org_id, true);
  if p_kind = 'report' then
    return pg_catalog.jsonb_build_object(
      'current', public.finance_report_summary(p_org_id, p_start, p_end),
      'previous', public.finance_report_summary(p_org_id, p_cmp_start, p_cmp_end),
      'counts', public.finance_shell_counts(p_org_id));
  elsif p_kind = 'dre' then
    return pg_catalog.jsonb_build_object(
      'current', public.finance_dre_summary(p_org_id, p_start, p_end),
      'previous', public.finance_dre_summary(p_org_id, p_cmp_start, p_cmp_end),
      'counts', public.finance_shell_counts(p_org_id));
  end if;
  raise exception 'Relatório inválido' using errcode = '22023';
end;
$$;

-- ─── Saldos das clientes e vales-presente ─────────────────────────────────────────────────────────
create or replace function public.finance_balances_screen(p_org_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_rows jsonb;
begin
  perform public.finance_require(p_org_id, true);
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
           'id', c.id, 'full_name', c.full_name, 'phone', c.phone, 'balance', c.balance) order by c.balance, c.id), '[]'::jsonb)
  into v_rows
  from (select x.id, x.full_name, x.phone, x.balance from public.clients x
        where x.org_id = p_org_id and x.balance <> 0 order by x.balance, x.id limit 5001) c;
  return pg_catalog.jsonb_build_object(
    'rows', (select coalesce(pg_catalog.jsonb_agg(r) filter (where n <= 5000), '[]'::jsonb)
             from (select r, pg_catalog.row_number() over () as n from pg_catalog.jsonb_array_elements(v_rows) r) z),
    'truncated', pg_catalog.jsonb_array_length(v_rows) > 5000,
    'counts', public.finance_shell_counts(p_org_id)
  );
end;
$$;

create or replace function public.finance_gift_cards_screen(p_org_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_rows jsonb;
begin
  perform public.finance_require(p_org_id, false);
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
           'id', g.id, 'code', g.code, 'initial_value', g.initial_value, 'remaining_value', g.remaining_value,
           'issued_to', g.issued_to, 'expires_at', g.expires_at, 'status', g.status, 'created_at', g.created_at)
           order by g.created_at desc, g.id), '[]'::jsonb)
  into v_rows
  from (select x.* from public.gift_cards x where x.org_id = p_org_id order by x.created_at desc, x.id limit 5001) g;
  return pg_catalog.jsonb_build_object(
    'rows', (select coalesce(pg_catalog.jsonb_agg(r) filter (where n <= 5000), '[]'::jsonb)
             from (select r, pg_catalog.row_number() over () as n from pg_catalog.jsonb_array_elements(v_rows) r) z),
    'truncated', pg_catalog.jsonb_array_length(v_rows) > 5000,
    'counts', public.finance_shell_counts(p_org_id)
  );
end;
$$;

-- ─── Checkout (comanda) ───────────────────────────────────────────────────────────────────────────

-- Catálogo vendável no checkout: serviços, produtos e pacotes ativos (só o que a tela usa).
create or replace function public.checkout_catalog(p_org_id uuid)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'services', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
               'id', s.id, 'name', s.name, 'price', s.price, 'duration_minutes', s.duration_minutes,
               'requires_anamnese', s.requires_anamnese, 'category', c.name) order by s.position, s.name, s.id)
      from (select x.* from public.services x where x.org_id = p_org_id and x.active
            order by x.position, x.name, x.id limit 1000) s
      left join public.service_categories c on c.id = s.category_id and c.org_id = s.org_id), '[]'::jsonb),
    'products', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
               'id', p.id, 'name', p.name, 'price', p.price, 'category', c.name) order by p.position, p.name, p.id)
      from (select x.* from public.products x where x.org_id = p_org_id and x.active
            order by x.position, x.name, x.id limit 1000) p
      left join public.service_categories c on c.id = p.category_id and c.org_id = p.org_id), '[]'::jsonb),
    'packages', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', k.id, 'name', k.name, 'price', k.price)
               order by k.position, k.name, k.id)
      from (select x.* from public.service_packages x where x.org_id = p_org_id and x.active
            order by x.position, x.name, x.id limit 500) k), '[]'::jsonb)
  );
$$;

-- Comanda por id da venda ou do agendamento. Sem venda com esse id mas com venda (não cancelada) no agendamento:
-- devolve {redirect: <id da venda>}. Nem venda nem agendamento visível: {not_found: true}.
create or replace function public.checkout_screen(p_org_id uuid, p_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_tz text;
  v_today date;
  v_sale public.sales;
  v_appt public.appointments;
  v_appt_id uuid;
  v_client_id uuid;
  v_redirect uuid;
  v_open boolean;
  v_gate jsonb := '[]'::jsonb;
  v_fichas jsonb := '[]'::jsonb;
begin
  perform public.finance_org_timezone(p_org_id);
  if not (public.has_permission(p_org_id, 'comanda.operate') or public.has_permission(p_org_id, 'financeiro.view')) then
    raise exception 'Sem permissão para ver o checkout' using errcode = '42501';
  end if;
  if p_id is null then
    return pg_catalog.jsonb_build_object('not_found', true);
  end if;
  v_tz := public.finance_org_timezone(p_org_id);
  v_today := (pg_catalog.now() at time zone v_tz)::date;

  select * into v_sale from public.sales s where s.id = p_id and s.org_id = p_org_id;
  if v_sale.id is null then
    -- Depois de um estorno o atendimento pode ganhar uma comanda nova: a cancelada fica só no histórico.
    select s.id into v_redirect from public.sales s
    where s.org_id = p_org_id and s.appointment_id = p_id and s.status <> 'cancelled'
    order by s.created_at desc, s.id limit 1;
    if v_redirect is not null then
      return pg_catalog.jsonb_build_object('redirect', v_redirect);
    end if;
    v_appt_id := p_id;
  else
    v_appt_id := v_sale.appointment_id;
  end if;

  if v_appt_id is not null then
    select * into v_appt from public.appointments a where a.id = v_appt_id and a.org_id = p_org_id;
  end if;
  if v_sale.id is null and v_appt.id is null then
    return pg_catalog.jsonb_build_object('not_found', true);
  end if;

  v_client_id := coalesce(v_appt.client_id, v_sale.client_id);
  v_open := v_sale.id is null or v_sale.status in ('draft', 'partial');

  if v_appt.id is not null and public.has_permission(p_org_id, 'anamnese.view_status') then
    select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
             'id', f.id, 'template_title', f.template_title, 'status', f.status, 'signed_at', f.signed_at,
             'requires_professional', f.requires_professional, 'professional_completed_at', f.professional_completed_at)
             order by f.created_at desc, f.id), '[]'::jsonb)
    into v_fichas
    from public.list_anamnese_status(p_org_id, array[v_appt.id]) f;
  end if;

  -- Trava da Ficha só para quem cobra (o gate exige comanda.operate ou anamnese.view_status); quem só vê o
  -- financeiro abre a comanda em leitura sem a trava.
  if v_open and v_appt.id is not null
     and (public.has_permission(p_org_id, 'comanda.operate') or public.has_permission(p_org_id, 'anamnese.view_status')) then
    select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(g)), '[]'::jsonb) into v_gate
    from public.get_appointment_anamnese_gate(p_org_id, v_appt.id, 'checkout') g;
  end if;

  return pg_catalog.jsonb_build_object(
    'today', v_today,
    'timezone', v_tz,
    'sale', case when v_sale.id is null then null else pg_catalog.jsonb_build_object(
      'id', v_sale.id, 'number', v_sale.number, 'appointment_id', v_sale.appointment_id, 'client_id', v_sale.client_id,
      'client_name', v_sale.client_name, 'staff_id', v_sale.staff_id, 'status', v_sale.status,
      'subtotal', v_sale.subtotal, 'discount', v_sale.discount, 'tip', v_sale.tip, 'total', v_sale.total,
      'paid_amount', v_sale.paid_amount, 'balance', v_sale.balance, 'notes', v_sale.notes,
      'created_at', v_sale.created_at, 'updated_at', v_sale.updated_at, 'refunded_at', v_sale.refunded_at,
      'refund_reason', v_sale.refund_reason,
      'items', coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
                  'id', i.id, 'item_type', i.item_type, 'item_id', i.item_id, 'name', i.name, 'category', i.category,
                  'unit_price', i.unit_price, 'quantity', i.quantity, 'total_price', i.total_price,
                  'entitlement_id', i.entitlement_id, 'covered_by_entitlement', i.covered_by_entitlement)
                  order by i.created_at, i.id)
                from public.sale_items i where i.sale_id = v_sale.id and i.org_id = p_org_id), '[]'::jsonb),
      'payments', coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
                  'method', pay.method, 'amount', pay.amount, 'gift_card_code', pay.gift_card_code,
                  'reference', pay.reference, 'created_at', pay.created_at) order by pay.created_at, pay.id)
                from public.sale_payments pay where pay.sale_id = v_sale.id and pay.org_id = p_org_id), '[]'::jsonb)
    ) end,
    'appointment', case when v_appt.id is null then null else pg_catalog.jsonb_build_object(
      'id', v_appt.id, 'number', v_appt.number, 'client_id', v_appt.client_id, 'client_name', v_appt.client_name,
      'staff_id', v_appt.staff_id, 'start_at', v_appt.start_at, 'internal_notes', v_appt.internal_notes,
      'items', coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
                  'id', i.id, 'type', i.type, 'ref_id', i.ref_id, 'name', i.name, 'price', i.price, 'qty', i.qty,
                  'duration_minutes', i.duration_minutes, 'professional_id', i.professional_id,
                  'requires_anamnese', i.requires_anamnese) order by i.created_at, i.id)
                from public.appointment_items i where i.appointment_id = v_appt.id and i.org_id = p_org_id), '[]'::jsonb),
      'fichas', v_fichas
    ) end,
    'catalog', public.checkout_catalog(p_org_id),
    'staff', coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
               'id', m.id, 'name', m.name, 'display_name', m.display_name, 'commission_pct', m.commission_pct)
               order by m.position, m.name, m.id)
             from (select x.* from public.staff_members x where x.org_id = p_org_id order by x.position, x.name, x.id limit 500) m), '[]'::jsonb),
    'deposits', case when v_appt.id is null then '[]'::jsonb else coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', d.id, 'amount', d.amount, 'method', d.method, 'created_at', d.created_at)
               order by d.created_at, d.id)
      from public.appointment_deposits d
      where d.org_id = p_org_id and d.appointment_id = v_appt.id and d.status = 'confirmed'), '[]'::jsonb) end,
    'entitlements', case when v_client_id is null then '[]'::jsonb else coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
               'id', e.id, 'package_name', e.package_name, 'total_sessions', e.total_sessions,
               'used_sessions', e.used_sessions, 'covered_services', e.covered_services, 'expires_at', e.expires_at)
               order by e.purchased_at desc, e.id)
      from (select x.* from public.client_entitlements x
            where x.org_id = p_org_id and x.client_id = v_client_id and x.status = 'active'
            order by x.purchased_at desc, x.id limit 200) e), '[]'::jsonb) end,
    'client', case when v_client_id is null then null else (
      select pg_catalog.jsonb_build_object(
               'full_name', c.full_name, 'phone', c.phone, 'email', c.email, 'tags', c.tags, 'balance', c.balance,
               'fixed_notes', c.fixed_notes, 'alert_text', c.alert_text)
      from public.clients c where c.id = v_client_id and c.org_id = p_org_id) end,
    'visits', case when v_client_id is null then 0 else (
      select pg_catalog.count(*) from public.sales s where s.org_id = p_org_id and s.client_id = v_client_id and s.status = 'paid') end,
    'gate', v_gate,
    'refund', case when v_sale.status = 'cancelled' then (
      select pg_catalog.jsonb_build_object('amount', r.amount, 'destination', r.destination, 'details', r.details)
      from public.sale_refunds r where r.org_id = p_org_id and r.sale_id = v_sale.id
      order by r.created_at desc, r.id limit 1) end,
    'partial_refunded', case when v_sale.status in ('paid', 'partial') then (
      select coalesce(pg_catalog.round(sum(r.amount), 2), 0) from public.sale_partial_refunds r
      where r.org_id = p_org_id and r.sale_id = v_sale.id) else 0 end,
    -- Retoques incluídos: regras do catálogo e os 200 atendimentos concluídos mais recentes da cliente
    -- (a conta da janela é feita em src/domain/service-rules.ts, no fuso do estúdio).
    'retouch_rules', case when v_open and v_client_id is not null then coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('service_id', s.id, 'name', s.name, 'days', s.retouch_included_days)
               order by s.name, s.id)
      from public.services s where s.org_id = p_org_id and s.retouch_included_days is not null), '[]'::jsonb)
      else '[]'::jsonb end,
    'retouch_history', case when v_open and v_client_id is not null then coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
               'status', a.status, 'start_at', a.start_at,
               'service_ids', coalesce((select pg_catalog.jsonb_agg(i.ref_id order by i.created_at, i.id)
                                        from public.appointment_items i
                                        where i.appointment_id = a.id and i.org_id = a.org_id and i.ref_id is not null), '[]'::jsonb))
               order by a.start_at desc)
      from (select x.* from public.appointments x
            where x.org_id = p_org_id and x.client_id = v_client_id
              and x.status in ('Concluído', 'Concluido', 'Pago Parcial', 'Pago')
              and x.id is distinct from v_appt.id
            order by x.start_at desc limit 200) a), '[]'::jsonb)
      else '[]'::jsonb end
  );
end;
$$;

-- Venda avulsa (sem agendamento): catálogo, a cliente escolhida (?cliente=), a lista de clientes para escolher,
-- a profissional da pessoa logada e os pacotes da cliente.
create or replace function public.checkout_walkin_screen(p_org_id uuid, p_client_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_tz text;
  v_clients jsonb;
begin
  v_tz := public.finance_org_timezone(p_org_id);
  if not public.has_permission(p_org_id, 'comanda.operate') then
    raise exception 'Sem permissão para registrar vendas' using errcode = '42501';
  end if;
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', c.id, 'name', c.full_name, 'phone', c.phone)
           order by c.full_name, c.id), '[]'::jsonb)
  into v_clients
  from (select x.id, x.full_name, x.phone from public.clients x
        where x.org_id = p_org_id and x.status <> 'archived'
        order by x.full_name, x.id limit 501) c;

  return pg_catalog.jsonb_build_object(
    'today', (pg_catalog.now() at time zone v_tz)::date,
    'timezone', v_tz,
    'catalog', public.checkout_catalog(p_org_id),
    'client', case when p_client_id is null then null else (
      select pg_catalog.jsonb_build_object(
               'id', c.id, 'full_name', c.full_name, 'phone', c.phone, 'email', c.email, 'tags', c.tags,
               'balance', c.balance, 'fixed_notes', c.fixed_notes, 'alert_text', c.alert_text)
      from public.clients c where c.id = p_client_id and c.org_id = p_org_id) end,
    'clients', (select coalesce(pg_catalog.jsonb_agg(c) filter (where n <= 500), '[]'::jsonb)
                from (select c, pg_catalog.row_number() over () as n from pg_catalog.jsonb_array_elements(v_clients) c) z),
    'clients_truncated', pg_catalog.jsonb_array_length(v_clients) > 500,
    'me', (select pg_catalog.jsonb_build_object('id', m.id, 'name', m.name, 'display_name', m.display_name, 'commission_pct', m.commission_pct)
           from public.staff_members m
           where m.org_id = p_org_id and m.user_id = (select auth.uid()) and m.active
           order by m.position, m.id limit 1),
    'entitlements', case when p_client_id is null then '[]'::jsonb else coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
               'id', e.id, 'package_name', e.package_name, 'total_sessions', e.total_sessions,
               'used_sessions', e.used_sessions, 'covered_services', e.covered_services, 'expires_at', e.expires_at)
               order by e.purchased_at desc, e.id)
      from (select x.* from public.client_entitlements x
            where x.org_id = p_org_id and x.client_id = p_client_id and x.status = 'active'
            order by x.purchased_at desc, x.id limit 200) e), '[]'::jsonb) end
  );
end;
$$;

-- ─── Fidelidade ───────────────────────────────────────────────────────────────────────────────────
create or replace function public.loyalty_screen(p_org_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  perform public.finance_org_timezone(p_org_id);
  -- Nomes e pontos das clientes: quem vê clientes ou o financeiro.
  if not (public.has_permission(p_org_id, 'clientes.view') or public.has_permission(p_org_id, 'financeiro.view')) then
    raise exception 'Sem permissão para ver a fidelidade' using errcode = '42501';
  end if;
  return pg_catalog.jsonb_build_object(
    'top', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
               'id', c.id, 'full_name', c.full_name, 'loyalty_points', c.loyalty_points, 'loyalty_tier', c.loyalty_tier)
               order by c.loyalty_points desc, c.id)
      from (select x.id, x.full_name, x.loyalty_points, x.loyalty_tier from public.clients x
            where x.org_id = p_org_id and x.loyalty_points > 0 order by x.loyalty_points desc, x.id limit 20) c), '[]'::jsonb),
    'summary', (select pg_catalog.jsonb_build_object('total_points', coalesce(sum(c.loyalty_points), 0), 'clients_with_points', pg_catalog.count(*))
                from public.clients c where c.org_id = p_org_id and c.loyalty_points > 0)
  );
end;
$$;

-- ─── Cobrança por link: o que o diálogo precisa para abrir ─────────────────────────────────────────
-- Cliente (do agendamento ou escolhida), valor sugerido (itens − sinais confirmados ou aplicados) e contas ativas.
create or replace function public.payment_request_context(p_org_id uuid, p_client_id uuid, p_appointment_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_client_id uuid := p_client_id;
  v_appt public.appointments;
  v_total numeric;
  v_paid numeric;
  v_suggested numeric;
  v_client jsonb;
begin
  perform public.finance_org_timezone(p_org_id);
  if not public.has_permission(p_org_id, 'comanda.operate') then
    raise exception 'Sem permissão para cobrar por link.' using errcode = '42501';
  end if;
  if p_appointment_id is not null then
    select * into v_appt from public.appointments a where a.id = p_appointment_id and a.org_id = p_org_id;
    if v_appt.client_id is null then
      return pg_catalog.jsonb_build_object('error', 'no_appointment_client');
    end if;
    v_client_id := v_appt.client_id;
    select coalesce(sum(i.price * i.qty), 0) into v_total
    from public.appointment_items i where i.appointment_id = v_appt.id and i.org_id = p_org_id;
    if v_total = 0 then
      v_total := coalesce(v_appt.total, 0);
    end if;
    select coalesce(sum(d.amount), 0) into v_paid
    from public.appointment_deposits d
    where d.appointment_id = v_appt.id and d.org_id = p_org_id and d.status in ('confirmed', 'applied');
    v_suggested := case when v_total > v_paid then pg_catalog.round(v_total - v_paid, 2) end;
  end if;
  if v_client_id is null then
    return pg_catalog.jsonb_build_object('error', 'no_client');
  end if;
  select pg_catalog.jsonb_build_object('id', c.id, 'full_name', c.full_name, 'phone', c.phone) into v_client
  from public.clients c where c.id = v_client_id and c.org_id = p_org_id;
  if v_client is null then
    return pg_catalog.jsonb_build_object('error', 'client_not_found');
  end if;
  return pg_catalog.jsonb_build_object(
    'client', v_client,
    'suggested', v_suggested,
    'accounts', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
               'id', a.id, 'kind', a.kind, 'holder_name', a.holder_name, 'identifier', a.identifier, 'bic', a.bic,
               'bank_name', a.bank_name, 'active', a.active, 'position', a.position) order by a.position, a.created_at, a.id)
      from public.payment_accounts a where a.org_id = p_org_id and a.active), '[]'::jsonb)
  );
end;
$$;

-- ─── Índice para o filtro novo (os de sales já existem: idx_sales_org_created, idx_sales_org_status) ────────────────────────────────────────────────────────────────
create index if not exists transactions_org_session_created_idx
  on public.transactions (org_id, cash_session_id, created_at desc);

-- ─── Execução: só quem está logado ────────────────────────────────────────────────────────────────
revoke all on function public.finance_org_timezone(uuid) from public, anon;
revoke all on function public.finance_shell_counts(uuid) from public, anon;
revoke all on function public.finance_cash_totals(uuid, uuid) from public, anon;
revoke all on function public.finance_require(uuid, boolean) from public, anon;
revoke all on function public.finance_overview_screen(uuid, date, date, date, date) from public, anon;
revoke all on function public.finance_comandas_screen(uuid, text) from public, anon;
revoke all on function public.finance_caixa_screen(uuid, uuid) from public, anon;
revoke all on function public.finance_commissions_screen(uuid, text) from public, anon;
revoke all on function public.finance_payables_screen(uuid) from public, anon;
revoke all on function public.finance_reports_screen(uuid, text, date, date, date, date) from public, anon;
revoke all on function public.finance_balances_screen(uuid) from public, anon;
revoke all on function public.finance_gift_cards_screen(uuid) from public, anon;
revoke all on function public.checkout_catalog(uuid) from public, anon;
revoke all on function public.checkout_screen(uuid, uuid) from public, anon;
revoke all on function public.checkout_walkin_screen(uuid, uuid) from public, anon;
revoke all on function public.loyalty_screen(uuid) from public, anon;
revoke all on function public.payment_request_context(uuid, uuid, uuid) from public, anon;

grant execute on function public.finance_org_timezone(uuid) to authenticated;
grant execute on function public.finance_shell_counts(uuid) to authenticated;
grant execute on function public.finance_cash_totals(uuid, uuid) to authenticated;
grant execute on function public.finance_require(uuid, boolean) to authenticated;
grant execute on function public.finance_overview_screen(uuid, date, date, date, date) to authenticated;
grant execute on function public.finance_comandas_screen(uuid, text) to authenticated;
grant execute on function public.finance_caixa_screen(uuid, uuid) to authenticated;
grant execute on function public.finance_commissions_screen(uuid, text) to authenticated;
grant execute on function public.finance_payables_screen(uuid) to authenticated;
grant execute on function public.finance_reports_screen(uuid, text, date, date, date, date) to authenticated;
grant execute on function public.finance_balances_screen(uuid) to authenticated;
grant execute on function public.finance_gift_cards_screen(uuid) to authenticated;
grant execute on function public.checkout_catalog(uuid) to authenticated;
grant execute on function public.checkout_screen(uuid, uuid) to authenticated;
grant execute on function public.checkout_walkin_screen(uuid, uuid) to authenticated;
grant execute on function public.loyalty_screen(uuid) to authenticated;
grant execute on function public.payment_request_context(uuid, uuid, uuid) to authenticated;
