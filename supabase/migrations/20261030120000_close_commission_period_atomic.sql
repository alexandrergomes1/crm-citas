-- Fechar o período de comissão: chave de origem única e fechamento atômico.
-- Encoding: UTF-8
--
-- Antes o app consultava a descrição "Comissão <nome> · mmm/aaaa" para saber se o mês já tinha
-- sido fechado e inseria as contas em seguida, sem constraint: dois cliques (ou duas abas)
-- duplicavam a conta, e uma venda estornada/quitada depois do fechamento não aparecia em lugar
-- nenhum.
--   * payables.source_key: chave de origem. Comissão = 'commission:<staff_id>:<AAAA-MM>';
--     ajuste do mesmo mês = 'commission:<staff_id>:<AAAA-MM>:adj:<total esperado em centavos>'.
--     Índice único parcial por (org_id, source_key): o segundo fechamento não duplica.
--   * close_commission_period_atomic(org, 'AAAA-MM'): calcula no banco a comissão de cada
--     profissional pelas vendas QUITADAS no mês (sales.paid_at, no fuso do estúdio), lança a conta
--     a pagar (insert idempotente, on conflict do nothing) e, se o mês já estava fechado mas a
--     comissão esperada aumentou (venda quitada depois do fechamento), lança só a diferença como
--     ajuste. Se diminuiu (venda estornada depois), devolve a diferença negativa para a tela
--     mostrar; não existe conta com valor negativo.
-- Regras iguais às de src/domain/commissions.ts: base = subtotal - desconto (sem gorjeta), por
-- venda arredondada em centavos, percentual atual da profissional.
-- Aditiva: coluna nova anulável e função nova; o app antigo continua fechando pela descrição.
set client_encoding = 'UTF8';

alter table public.payables add column if not exists source_key text;
comment on column public.payables.source_key is
  'Chave de origem para lançamentos automáticos idempotentes (ex.: commission:<staff_id>:<AAAA-MM>).';

create unique index if not exists payables_org_source_key_key
  on public.payables (org_id, source_key)
  where source_key is not null;

-- Contas de comissão já fechadas pela descrição ganham a chave (só quando a profissional é única).
with parsed as (
  select p.id, p.org_id, p.description,
         substring(p.description from '([a-z]{3}/[0-9]{4})$') as tail,
         substring(p.description from '/([0-9]{4})$') || '-' ||
           lpad(array_position(array['jan','fev','mar','abr','mai','jun','jul','ago','set','out','nov','dez'],
                  substring(p.description from '([a-z]{3})/[0-9]{4}$'))::text, 2, '0') as month
  from public.payables p
  where p.category = 'comissao' and p.source_key is null
    and p.description ~ ' · [a-z]{3}/[0-9]{4}$'
    and substring(p.description from '([a-z]{3})/[0-9]{4}$') = any (array['jan','fev','mar','abr','mai','jun','jul','ago','set','out','nov','dez'])
), matched as (
  select pr.id, pr.org_id,
         'commission:' || min(m.id::text) || ':' || pr.month as key
  from parsed pr
  join public.staff_members m
    on m.org_id = pr.org_id
   and pr.description = 'Comissão ' || coalesce(nullif(m.display_name, ''), m.name) || ' · ' || pr.tail
  group by pr.id, pr.org_id, pr.month
  having count(*) = 1
), keyed as (
  select id, org_id, key, row_number() over (partition by org_id, key order by id) as rn
  from matched
)
update public.payables p
   set source_key = k.key
  from keyed k
 where p.id = k.id and k.rn = 1
   and not exists (select 1 from public.payables q where q.org_id = k.org_id and q.source_key = k.key);

create or replace function public.close_commission_period_atomic(p_org_id uuid, p_month text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tz text;
  v_start timestamptz;
  v_end timestamptz;
  v_due date;
  v_abbr text;
  v_created integer := 0;
  v_adjusted integer := 0;
  v_unchanged integer := 0;
  v_negative jsonb := '[]'::jsonb;
  v_rows integer;
  r record;
  v_key text;
  v_closed numeric(12,2);
  v_legacy text;
begin
  if auth.uid() is null then
    raise exception 'Sessão expirada' using errcode = '42501';
  end if;
  if not public.has_permission(p_org_id, 'financeiro.manage') then
    raise exception 'Sem permissão para fechar comissões' using errcode = '42501';
  end if;
  if p_month is null or p_month !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then
    raise exception 'Período inválido' using errcode = '22023';
  end if;

  select coalesce(nullif(o.timezone, ''), 'UTC') into v_tz
  from public.organizations o where o.id = p_org_id;
  if v_tz is null then
    raise exception 'Estúdio não encontrado' using errcode = 'P0002';
  end if;

  v_start := ((p_month || '-01')::date)::timestamp at time zone v_tz;
  v_end := (((p_month || '-01')::date + interval '1 month')::date)::timestamp at time zone v_tz;
  v_due := ((p_month || '-01')::date + interval '1 month')::date + 4;
  v_abbr := (array['jan','fev','mar','abr','mai','jun','jul','ago','set','out','nov','dez'])[substr(p_month, 6, 2)::int];

  for r in
    select s.staff_id,
           coalesce(nullif(m.display_name, ''), m.name) as staff_name,
           m.commission_pct as pct,
           count(*) as attendances,
           sum(pg_catalog.round(
             greatest(0, s.subtotal - least(s.discount, s.subtotal)) * m.commission_pct / 100, 2)) as expected
    from public.sales s
    join public.staff_members m on m.id = s.staff_id and m.org_id = s.org_id
    where s.org_id = p_org_id
      and s.status = 'paid'
      and s.paid_at >= v_start and s.paid_at < v_end
      and s.staff_id is not null
      and coalesce(m.commission_pct, 0) > 0
    group by s.staff_id, m.display_name, m.name, m.commission_pct
    order by 2
  loop
    if r.expected is null or r.expected < 0.01 then
      continue;
    end if;
    v_key := 'commission:' || r.staff_id::text || ':' || p_month;
    v_legacy := 'Comissão ' || r.staff_name || ' · ' || v_abbr || '/' || substr(p_month, 1, 4);

    -- Já fechado: contas com a chave do mês, seus ajustes e as antigas fechadas só pela descrição.
    select coalesce(sum(p.value), 0) into v_closed
    from public.payables p
    where p.org_id = p_org_id and p.category = 'comissao' and p.status in ('pending', 'overdue', 'paid')
      and (p.source_key = v_key or p.source_key like v_key || ':adj:%'
           or (p.source_key is null and p.description = v_legacy));

    if v_closed < 0.01 then
      insert into public.payables (org_id, description, vendor, category, value, due_date, status, notes, created_by, source_key)
      values (p_org_id, v_legacy, r.staff_name, 'comissao', r.expected, v_due, 'pending',
              r.attendances || ' atendimentos pagos · ' || r.pct || '% de comissão', auth.uid(), v_key)
      on conflict (org_id, source_key) where source_key is not null do nothing;
      get diagnostics v_rows = row_count;
      v_created := v_created + v_rows;
    elsif r.expected - v_closed >= 0.01 then
      insert into public.payables (org_id, description, vendor, category, value, due_date, status, notes, created_by, source_key)
      values (p_org_id, v_legacy || ' (ajuste)', r.staff_name, 'comissao',
              pg_catalog.round(r.expected - v_closed, 2), v_due, 'pending',
              'Vendas quitadas depois do fechamento do mês', auth.uid(),
              v_key || ':adj:' || (pg_catalog.round(r.expected * 100))::bigint::text)
      on conflict (org_id, source_key) where source_key is not null do nothing;
      get diagnostics v_rows = row_count;
      v_adjusted := v_adjusted + v_rows;
    else
      v_unchanged := v_unchanged + 1;
      if v_closed - r.expected >= 0.01 then
        v_negative := v_negative || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
          'staffId', r.staff_id, 'staffName', r.staff_name, 'difference', pg_catalog.round(r.expected - v_closed, 2)));
      end if;
    end if;
  end loop;

  if v_created + v_adjusted > 0 then
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
    values (p_org_id, auth.uid(), 'payables', 'COMMISSION_PERIOD_CLOSED', null,
            pg_catalog.jsonb_build_object('month', p_month, 'created', v_created, 'adjusted', v_adjusted));
  end if;

  return pg_catalog.jsonb_build_object(
    'month', p_month, 'created', v_created, 'adjusted', v_adjusted, 'unchanged', v_unchanged, 'negative', v_negative);
end;
$$;

revoke all on function public.close_commission_period_atomic(uuid, text) from public, anon;
grant execute on function public.close_commission_period_atomic(uuid, text) to authenticated;
