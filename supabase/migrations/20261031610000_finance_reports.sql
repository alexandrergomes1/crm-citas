-- Relatórios e DRE agregados no banco (spec 41).
-- Encoding: UTF-8
set client_encoding = 'UTF8';
--
-- A tela de Relatórios lia todas as vendas do período no app (1000 linhas por página) e somava em
-- memória; o DRE somava 12 meses de lançamentos do mesmo jeito. Agora duas funções somam no banco e
-- devolvem só os totais, sem truncar:
--   * finance_report_summary(org, início, fim): vendas quitadas no período (sales.paid_at no fuso do
--     estúdio, igual às comissões): faturamento, atendimentos, descontos, gorjetas, estornos e as
--     quebras por profissional, item vendido, forma de pagamento e dia.
--   * finance_dre_summary(org, início, fim): demonstrativo em regime de caixa, mesma base da Visão
--     geral (lançamentos concluídos): receitas por categoria, estornos, despesas de lançamentos e
--     contas pagas por categoria, descontos concedidos e contas ainda em aberto no período.
-- Security invoker: a RLS das tabelas continua valendo; a permissão é conferida de novo aqui.
-- Aditiva: só funções novas e um índice.

create index if not exists transactions_org_status_date_idx on public.transactions (org_id, status, date);

create or replace function public.finance_report_summary(p_org_id uuid, p_start date, p_end date)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_tz text;
  v_from timestamptz;
  v_to timestamptz;
begin
  if (select auth.uid()) is null then
    raise exception 'Sessão expirada' using errcode = '42501';
  end if;
  if not public.has_permission(p_org_id, 'financeiro.view') then
    raise exception 'Sem permissão para ver relatórios' using errcode = '42501';
  end if;
  if p_start is null or p_end is null or p_end < p_start or p_end - p_start > 400 then
    raise exception 'Período inválido' using errcode = '22023';
  end if;

  select coalesce(nullif(o.timezone, ''), 'UTC') into v_tz from public.organizations o where o.id = p_org_id;
  if v_tz is null then
    raise exception 'Estúdio não encontrado' using errcode = 'P0002';
  end if;
  v_from := p_start::timestamp at time zone v_tz;
  v_to := (p_end + 1)::timestamp at time zone v_tz;

  return (
    with paid as materialized (
      select s.id, s.staff_id, s.total, s.discount, s.tip, (s.paid_at at time zone v_tz)::date as day
      from public.sales s
      where s.org_id = p_org_id and s.status = 'paid' and s.paid_at >= v_from and s.paid_at < v_to
    ),
    totals as (
      select pg_catalog.jsonb_build_object(
               'sales', count(*),
               'revenue', coalesce(pg_catalog.round(sum(total), 2), 0),
               'discounts', coalesce(pg_catalog.round(sum(discount), 2), 0),
               'tips', coalesce(pg_catalog.round(sum(tip), 2), 0)) as j
      from paid
    ),
    refunds as (
      select pg_catalog.jsonb_build_object(
               'full', coalesce((select pg_catalog.round(sum(r.amount), 2) from public.sale_refunds r
                                  where r.org_id = p_org_id and r.created_at >= v_from and r.created_at < v_to), 0),
               'partial', coalesce((select pg_catalog.round(sum(r.amount), 2) from public.sale_partial_refunds r
                                     where r.org_id = p_org_id and r.created_at >= v_from and r.created_at < v_to), 0)) as j
    ),
    staff as (
      select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
               'staffId', x.staff_id, 'name', x.name, 'count', x.cnt, 'revenue', x.revenue) order by x.revenue desc, x.name), '[]'::jsonb) as j
      from (
        select p.staff_id,
               coalesce(nullif(m.display_name, ''), m.name, 'Sem profissional') as name,
               count(*) as cnt,
               pg_catalog.round(sum(p.total), 2) as revenue
        from paid p
        left join public.staff_members m on m.id = p.staff_id and m.org_id = p_org_id
        group by p.staff_id, coalesce(nullif(m.display_name, ''), m.name, 'Sem profissional')
      ) x
    ),
    items as (
      select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
               'name', x.name, 'kind', x.kind, 'qty', x.qty, 'revenue', x.revenue) order by x.revenue desc, x.name), '[]'::jsonb) as j
      from (
        select i.name, pg_catalog.lower(i.item_type) as kind, sum(i.quantity) as qty, pg_catalog.round(sum(i.total_price), 2) as revenue
        from public.sale_items i
        join paid p on p.id = i.sale_id
        where i.org_id = p_org_id
        group by i.name, pg_catalog.lower(i.item_type)
        order by 4 desc, 1
        limit 40
      ) x
    ),
    methods as (
      select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
               'method', x.method, 'count', x.cnt, 'amount', x.amount) order by x.amount desc, x.method), '[]'::jsonb) as j
      from (
        select pg_catalog.upper(pg_catalog.btrim(pay.method)) as method, count(distinct pay.sale_id) as cnt,
               pg_catalog.round(sum(pay.amount), 2) as amount
        from public.sale_payments pay
        join paid p on p.id = pay.sale_id
        where pay.org_id = p_org_id
        group by 1
      ) x
    ),
    days as (
      select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
               'date', d.day, 'count', coalesce(a.cnt, 0), 'revenue', coalesce(a.revenue, 0)) order by d.day), '[]'::jsonb) as j
      from (select p_start + g as day from pg_catalog.generate_series(0, p_end - p_start) as g) d
      left join (
        select p.day, count(*) as cnt, pg_catalog.round(sum(p.total), 2) as revenue from paid p group by p.day
      ) a on a.day = d.day
    )
    select pg_catalog.jsonb_build_object(
      'period', pg_catalog.jsonb_build_object('start', p_start, 'end', p_end),
      'totals', totals.j, 'refunds', refunds.j, 'byStaff', staff.j, 'byItem', items.j,
      'byMethod', methods.j, 'byDay', days.j)
    from totals, refunds, staff, items, methods, days
  );
end;
$$;
revoke all on function public.finance_report_summary(uuid, date, date) from public, anon;
grant execute on function public.finance_report_summary(uuid, date, date) to authenticated;

create or replace function public.finance_dre_summary(p_org_id uuid, p_start date, p_end date)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_tz text;
  v_from timestamptz;
  v_to timestamptz;
  v_revenue jsonb;
  v_refunds numeric(12,2);
  v_manual jsonb;
  v_paid jsonb;
  v_discounts numeric(12,2);
  v_open jsonb;
begin
  if (select auth.uid()) is null then
    raise exception 'Sessão expirada' using errcode = '42501';
  end if;
  if not public.has_permission(p_org_id, 'financeiro.view') then
    raise exception 'Sem permissão para ver o DRE' using errcode = '42501';
  end if;
  if p_start is null or p_end is null or p_end < p_start or p_end - p_start > 800 then
    raise exception 'Período inválido' using errcode = '22023';
  end if;

  select coalesce(nullif(o.timezone, ''), 'UTC') into v_tz from public.organizations o where o.id = p_org_id;
  if v_tz is null then
    raise exception 'Estúdio não encontrado' using errcode = 'P0002';
  end if;
  v_from := p_start::timestamp at time zone v_tz;
  v_to := (p_end + 1)::timestamp at time zone v_tz;

  -- Receita operacional: entradas concluídas, sem ajuste de saldo e sem crédito/vale (não é dinheiro novo).
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('category', x.category, 'amount', x.amount) order by x.amount desc, x.category), '[]'::jsonb)
    into v_revenue
  from (
    select coalesce(nullif(pg_catalog.btrim(t.category), ''), 'outros') as category, pg_catalog.round(sum(t.value), 2) as amount
    from public.transactions t
    where t.org_id = p_org_id and t.status = 'completed' and t.type = 'income'
      and t.date between p_start and p_end
      and coalesce(t.category, '') <> 'ajuste_saldo'
      and pg_catalog.lower(coalesce(t.method, '')) not in ('client_credit', 'gift_card')
    group by 1
  ) x;

  select coalesce(pg_catalog.round(sum(t.value), 2), 0) into v_refunds
  from public.transactions t
  where t.org_id = p_org_id and t.status = 'completed' and t.type = 'expense' and t.category = 'estorno'
    and t.date between p_start and p_end;

  -- Despesas lançadas à mão e saídas do caixa (conta_paga entra pelas contas pagas abaixo, sem contar duas vezes).
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('category', x.category, 'amount', x.amount) order by x.amount desc, x.category), '[]'::jsonb)
    into v_manual
  from (
    select coalesce(nullif(pg_catalog.btrim(t.category), ''), 'outros') as category, pg_catalog.round(sum(t.value), 2) as amount
    from public.transactions t
    where t.org_id = p_org_id and t.status = 'completed' and t.type = 'expense'
      and t.date between p_start and p_end
      and coalesce(t.category, '') not in ('ajuste_saldo', 'estorno', 'conta_paga')
    group by 1
  ) x;

  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('category', x.category, 'amount', x.amount) order by x.amount desc, x.category), '[]'::jsonb)
    into v_paid
  from (
    select coalesce(nullif(pg_catalog.btrim(p.category), ''), 'outros') as category,
           pg_catalog.round(sum(coalesce(p.paid_value, p.value)), 2) as amount
    from public.payables p
    where p.org_id = p_org_id and p.status = 'paid' and p.paid_date between p_start and p_end
    group by 1
  ) x;

  select coalesce(pg_catalog.round(sum(s.discount), 2), 0) into v_discounts
  from public.sales s
  where s.org_id = p_org_id and s.status = 'paid' and s.paid_at >= v_from and s.paid_at < v_to;

  select pg_catalog.jsonb_build_object('count', count(*), 'amount', coalesce(pg_catalog.round(sum(p.value), 2), 0))
    into v_open
  from public.payables p
  where p.org_id = p_org_id and p.status in ('pending', 'overdue') and p.due_date between p_start and p_end;

  return pg_catalog.jsonb_build_object(
    'period', pg_catalog.jsonb_build_object('start', p_start, 'end', p_end),
    'revenue', v_revenue,
    'refunds', v_refunds,
    'manualExpenses', v_manual,
    'paidPayables', v_paid,
    'discounts', v_discounts,
    'openPayables', v_open);
end;
$$;
revoke all on function public.finance_dre_summary(uuid, date, date) from public, anon;
grant execute on function public.finance_dre_summary(uuid, date, date) to authenticated;
