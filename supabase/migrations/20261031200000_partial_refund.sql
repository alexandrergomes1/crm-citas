-- Devolução parcial de comanda cobrada (V26).
-- Encoding: UTF-8
set client_encoding = 'UTF8';
--
-- A comanda continua paga; só sai dinheiro do caixa (ou entra crédito da cliente) pelo valor devolvido.
-- Não desfaz pontos, pacotes, estoque nem comissão (isso é do estorno total). Várias devoluções
-- parciais somam até o valor pago. Depois de uma devolução parcial o estorno total fica bloqueado
-- (a cliente recebe o restante pelo mesmo caminho parcial), para o dinheiro nunca ser devolvido duas vezes.
-- Aditiva: tabela nova, função nova, e um bloqueio extra em refund_sale_atomic (7 parâmetros).

create table if not exists public.sale_partial_refunds (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references public.organizations(id) on delete cascade,
  sale_id         uuid not null,
  idempotency_key uuid,
  amount          numeric(12,2) not null check (amount > 0),
  destination     text not null check (destination in ('caixa', 'credito')),
  method          text,
  reason          text not null check (length(btrim(reason)) between 5 and 300),
  created_by      uuid references auth.users(id) on delete set null,
  created_at      timestamptz not null default now(),
  constraint sale_partial_refunds_sale_same_org foreign key (sale_id, org_id) references public.sales (id, org_id)
);
comment on table public.sale_partial_refunds is
  'Devoluções parciais de comanda cobrada (várias por venda), gravadas por partial_refund_sale_atomic.';

create index if not exists sale_partial_refunds_sale_org_idx on public.sale_partial_refunds (sale_id, org_id);
create unique index if not exists sale_partial_refunds_org_idempotency_key
  on public.sale_partial_refunds (org_id, idempotency_key) where idempotency_key is not null;

alter table public.sale_partial_refunds enable row level security;
revoke all on public.sale_partial_refunds from public, anon, authenticated;
grant select on public.sale_partial_refunds to authenticated;

drop policy if exists sale_partial_refunds_select on public.sale_partial_refunds;
create policy sale_partial_refunds_select on public.sale_partial_refunds for select to authenticated
  using (public.has_permission(org_id, 'financeiro.view') or public.has_permission(org_id, 'comanda.operate'));

create or replace function public.partial_refund_sale_atomic(
  p_org_id uuid,
  p_sale_id uuid,
  p_amount numeric,
  p_reason text,
  p_destination text,
  p_method text,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_reason text := nullif(pg_catalog.btrim(coalesce(p_reason, '')), '');
  v_amount numeric(12,2) := pg_catalog.round(coalesce(p_amount, 0), 2);
  v_sale public.sales;
  v_row public.sale_partial_refunds;
  v_label text;
  v_tz text;
  v_today date;
  v_paid numeric(12,2);
  v_prev numeric(12,2);
  v_left numeric(12,2);
  v_method text := nullif(pg_catalog.btrim(coalesce(p_method, '')), '');
begin
  if v_user_id is null then
    raise exception 'Sessão expirada' using errcode = '42501';
  end if;
  if not public.has_permission(p_org_id, 'comanda.refund') then
    raise exception 'Sem permissão para estornar comandas' using errcode = '42501';
  end if;
  if v_reason is null or pg_catalog.length(v_reason) < 5 or pg_catalog.length(v_reason) > 300 then
    raise exception 'Informe o motivo da devolução (de 5 a 300 caracteres)' using errcode = '22023';
  end if;
  if v_amount < 0.01 then
    raise exception 'Informe o valor a devolver' using errcode = '22023';
  end if;
  if p_destination is null or p_destination not in ('caixa', 'credito') then
    raise exception 'Destino da devolução inválido' using errcode = '22023';
  end if;

  -- Mesma trava do estorno total: as duas operações nunca correm juntas na mesma comanda.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_org_id::text || ':refund:' || p_sale_id::text, 0));

  select * into v_sale from public.sales s where s.id = p_sale_id and s.org_id = p_org_id for update;
  if not found then
    raise exception 'Comanda não encontrada' using errcode = 'P0002';
  end if;

  if p_idempotency_key is not null then
    select * into v_row from public.sale_partial_refunds r where r.org_id = p_org_id and r.idempotency_key = p_idempotency_key;
    if found then
      if v_row.sale_id <> p_sale_id then
        raise exception 'Chave de idempotência já usada em outra comanda' using errcode = '22023';
      end if;
      return pg_catalog.jsonb_build_object('saleId', v_sale.id, 'refundId', v_row.id, 'amount', v_row.amount, 'duplicate', true);
    end if;
  end if;

  if v_sale.status not in ('partial', 'paid') then
    raise exception 'Só é possível devolver parte de uma comanda cobrada' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.sale_refunds rf where rf.sale_id = p_sale_id and rf.org_id = p_org_id) then
    raise exception 'Esta comanda já foi estornada' using errcode = 'P0001';
  end if;

  select coalesce(sum(p.amount) filter (where p.method <> 'GIFT_CARD'), 0) into v_paid
  from public.sale_payments p where p.sale_id = v_sale.id and p.org_id = p_org_id;
  select coalesce(sum(r.amount), 0) into v_prev
  from public.sale_partial_refunds r where r.sale_id = v_sale.id and r.org_id = p_org_id;
  v_left := v_paid - v_prev;
  if v_amount > v_left then
    raise exception 'O valor passa do que pode ser devolvido (%)', pg_catalog.to_char(v_left, 'FM999999990.00') using errcode = '22023';
  end if;

  if p_destination = 'credito' and v_sale.client_id is null then
    raise exception 'Devolução em crédito exige uma cliente cadastrada na comanda' using errcode = '22023';
  end if;

  v_label := 'Comanda #' || pg_catalog.lpad(v_sale.number::text, 4, '0');
  select coalesce(nullif(o.timezone, ''), 'UTC') into v_tz from public.organizations o where o.id = p_org_id;
  v_today := (pg_catalog.now() at time zone coalesce(v_tz, 'UTC'))::date;

  if p_destination = 'caixa' then
    if v_method is null then
      select p.method into v_method from public.sale_payments p
      where p.sale_id = v_sale.id and p.org_id = p_org_id and p.method <> 'GIFT_CARD'
      group by p.method order by sum(p.amount) desc limit 1;
    elsif not exists (
      select 1 from public.sale_payments p
      where p.sale_id = v_sale.id and p.org_id = p_org_id and p.method = v_method and p.method <> 'GIFT_CARD'
    ) then
      raise exception 'A forma de pagamento não foi usada nesta comanda' using errcode = '22023';
    end if;
    insert into public.transactions (
      org_id, sale_id, client_id, client_name, type, category, description, value, method, date, status, created_by
    ) values (
      p_org_id, v_sale.id, v_sale.client_id, v_sale.client_name, 'expense', 'estorno',
      'Devolução parcial ' || v_label || ' - ' || v_sale.client_name, v_amount, v_method, v_today, 'completed', v_user_id
    );
  else
    v_method := 'CLIENT_CREDIT';
    insert into public.transactions (
      org_id, sale_id, client_id, client_name, type, category, description, value, method, date, status, created_by
    ) values (
      p_org_id, v_sale.id, v_sale.client_id, v_sale.client_name, 'expense', 'estorno',
      'Devolução parcial em crédito ' || v_label || ' - ' || v_sale.client_name, v_amount, 'CLIENT_CREDIT', v_today, 'completed', v_user_id
    );
    perform public.apply_client_balance_entry_internal(
      p_org_id, v_sale.client_id, v_sale.id, 'refund_credit', v_amount,
      'sale_refund', 'Devolução parcial ' || v_label || ' em crédito', v_user_id);
  end if;

  insert into public.sale_partial_refunds (org_id, sale_id, idempotency_key, amount, destination, method, reason, created_by)
  values (p_org_id, v_sale.id, p_idempotency_key, v_amount, p_destination, v_method, v_reason, v_user_id)
  returning * into v_row;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (
    p_org_id, v_user_id, 'sales', 'SALE_PARTIAL_REFUND', v_sale.id,
    pg_catalog.jsonb_build_object('paid', v_paid, 'already_refunded', v_prev),
    pg_catalog.jsonb_build_object('refund_id', v_row.id, 'amount', v_amount, 'destination', p_destination, 'method', v_method, 'reason', v_reason));

  return pg_catalog.jsonb_build_object(
    'saleId', v_sale.id, 'refundId', v_row.id, 'amount', v_amount, 'destination', p_destination,
    'remaining', pg_catalog.round(v_left - v_amount, 2), 'duplicate', false);
end;
$$;

revoke all on function public.partial_refund_sale_atomic(uuid, uuid, numeric, text, text, text, uuid) from public, anon;
grant execute on function public.partial_refund_sale_atomic(uuid, uuid, numeric, text, text, text, uuid) to authenticated;

-- Estorno total bloqueado depois de devolução parcial: patch da função vigente (mantém corpo, grants e assinatura).
do $patch$
declare
  v_def text;
  v_anchor constant text := E'  if v_sale.status not in (''draft'', ''partial'', ''paid'') then\n    raise exception ''Esta comanda já está cancelada'' using errcode = ''P0001'';\n  end if;\n';
  v_new text;
begin
  select pg_catalog.pg_get_functiondef('public.refund_sale_atomic(uuid, uuid, text, text, boolean, uuid, boolean)'::regprocedure) into v_def;
  if pg_catalog.strpos(v_def, v_anchor) = 0 then
    raise exception 'refund_sale_atomic: ponto de inserção não encontrado';
  end if;
  v_new := pg_catalog.replace(v_def, v_anchor, v_anchor
    || E'  if exists (select 1 from public.sale_partial_refunds pr where pr.sale_id = p_sale_id and pr.org_id = p_org_id) then\n'
    || E'    raise exception ''Esta comanda já teve devolução parcial. Devolva o restante pelo valor, em Devolver parte.'' using errcode = ''P0001'';\n'
    || E'  end if;\n');
  execute v_new;
end
$patch$;
