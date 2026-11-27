-- Estorno e cancelamento de comanda: refund_sale_atomic.
-- Encoding: UTF-8
--
-- A tela "Estorno da comanda" (quadro ComandaFinalizada) só orientava a lançar o ajuste à mão
-- no saldo da cliente. Agora uma função atômica e idempotente faz tudo de uma vez, com
-- comanda.refund, motivo obrigatório e registro no histórico (sale_refunds) e na auditoria:
--   * a venda vira 'cancelled' (saldo zerado, motivo e data guardados; total e pago ficam para o histórico);
--   * dinheiro: para cada forma de pagamento, uma saída 'estorno' no caixa (destino 'caixa'), ou
--     um crédito na cliente (destino 'credito', saída 'estorno' com forma CLIENT_CREDIT);
--     vale-presente usado volta para o próprio vale;
--   * extrato da cliente: o que a venda moveu (crédito usado, dívida, excedente) é revertido;
--   * fidelidade: os pontos ganhos na venda saem; total gasto diminui;
--   * pacotes: sessões consumidas voltam; pacote vendido na comanda é cancelado (recusa se já teve uso);
--   * produtos: voltam ao estoque só se p_restock_products;
--   * sinal aplicado vira 'refunded'; atendimento Pago/Pago Parcial volta a Concluído.
-- Estorno é total (parcial fica fora). Comanda em rascunho ou parcial sem pagamento é cancelada
-- sem movimento de dinheiro. Repetir a chamada com a mesma chave devolve o mesmo resultado.
-- Aditiva: tabela e função novas, duas colunas anuláveis em sales.
set client_encoding = 'UTF8';

alter table public.sales
  add column if not exists refunded_at timestamptz,
  add column if not exists refund_reason text;

comment on column public.sales.refunded_at is 'Quando a comanda foi estornada/cancelada (refund_sale_atomic).';
comment on column public.sales.refund_reason is 'Motivo informado no estorno/cancelamento.';

create table if not exists public.sale_refunds (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references public.organizations(id) on delete cascade,
  sale_id          uuid not null,
  idempotency_key  uuid,
  amount           numeric(12,2) not null default 0 check (amount >= 0),
  destination      text not null check (destination in ('caixa', 'credito', 'nenhum')),
  reason           text not null check (length(btrim(reason)) between 5 and 300),
  restock_products boolean not null default false,
  details          jsonb not null default '{}'::jsonb,
  created_by       uuid references auth.users(id) on delete set null,
  created_at       timestamptz not null default now(),
  constraint sale_refunds_sale_same_org foreign key (sale_id, org_id) references public.sales (id, org_id)
);
comment on table public.sale_refunds is
  'Histórico de estornos e cancelamentos de comanda (uma linha por venda), gravado por refund_sale_atomic.';

create unique index if not exists sale_refunds_sale_org_key on public.sale_refunds (sale_id, org_id);
create unique index if not exists sale_refunds_org_idempotency_key
  on public.sale_refunds (org_id, idempotency_key) where idempotency_key is not null;

alter table public.sale_refunds enable row level security;
revoke all on public.sale_refunds from public, anon, authenticated;
grant select on public.sale_refunds to authenticated;

drop policy if exists sale_refunds_select on public.sale_refunds;
create policy sale_refunds_select on public.sale_refunds for select to authenticated
  using (public.has_permission(org_id, 'financeiro.view') or public.has_permission(org_id, 'comanda.operate'));

create or replace function public.refund_sale_atomic(
  p_org_id uuid,
  p_sale_id uuid,
  p_reason text,
  p_destination text default 'caixa',
  p_restock_products boolean default false,
  p_idempotency_key uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_reason text := nullif(pg_catalog.btrim(coalesce(p_reason, '')), '');
  v_sale public.sales;
  v_refund public.sale_refunds;
  v_client public.clients;
  v_appointment_status text;
  v_label text;
  v_tz text;
  v_today date;
  v_money numeric(12,2) := 0;
  v_gift numeric(12,2) := 0;
  v_destination text;
  v_ledger_net numeric(12,2) := 0;
  v_credit_used numeric(12,2) := 0;
  v_points_net integer := 0;
  v_points_before integer;
  v_points_after integer;
  v_restored integer := 0;
  v_cancelled_packages integer := 0;
  v_restocked integer := 0;
  v_deposits integer := 0;
  v_after integer;
  r record;
begin
  if v_user_id is null then
    raise exception 'Sessão expirada' using errcode = '42501';
  end if;
  if not public.has_permission(p_org_id, 'comanda.refund') then
    raise exception 'Sem permissão para estornar comandas' using errcode = '42501';
  end if;
  if v_reason is null or pg_catalog.length(v_reason) < 5 or pg_catalog.length(v_reason) > 300 then
    raise exception 'Informe o motivo do estorno (de 5 a 300 caracteres)' using errcode = '22023';
  end if;
  if p_destination is null or p_destination not in ('caixa', 'credito') then
    raise exception 'Destino do estorno inválido' using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_org_id::text || ':refund:' || p_sale_id::text, 0));

  select * into v_sale
  from public.sales s
  where s.id = p_sale_id and s.org_id = p_org_id
  for update;
  if not found then
    raise exception 'Comanda não encontrada' using errcode = 'P0002';
  end if;

  -- Já estornada: a mesma chave devolve o resultado guardado; qualquer outra tentativa é recusada.
  select * into v_refund
  from public.sale_refunds rf
  where rf.sale_id = p_sale_id and rf.org_id = p_org_id;
  if found then
    if p_idempotency_key is not null and v_refund.idempotency_key is not distinct from p_idempotency_key then
      return pg_catalog.jsonb_build_object(
        'saleId', v_sale.id, 'refundId', v_refund.id, 'status', 'cancelled',
        'amount', v_refund.amount, 'destination', v_refund.destination, 'duplicate', true);
    end if;
    raise exception 'Esta comanda já foi estornada' using errcode = 'P0001';
  end if;
  if p_idempotency_key is not null and exists (
    select 1 from public.sale_refunds rf where rf.org_id = p_org_id and rf.idempotency_key = p_idempotency_key
  ) then
    raise exception 'Chave de idempotência já usada em outra comanda' using errcode = '22023';
  end if;
  if v_sale.status not in ('draft', 'partial', 'paid') then
    raise exception 'Esta comanda já está cancelada' using errcode = 'P0001';
  end if;

  v_label := 'Comanda #' || pg_catalog.lpad(v_sale.number::text, 4, '0');
  select coalesce(nullif(o.timezone, ''), 'UTC') into v_tz from public.organizations o where o.id = p_org_id;
  v_today := (pg_catalog.now() at time zone coalesce(v_tz, 'UTC'))::date;

  select coalesce(sum(p.amount) filter (where p.method <> 'GIFT_CARD'), 0),
         coalesce(sum(p.amount) filter (where p.method = 'GIFT_CARD'), 0)
    into v_money, v_gift
  from public.sale_payments p
  where p.sale_id = v_sale.id and p.org_id = p_org_id;

  v_destination := case when v_money < 0.01 then 'nenhum' else p_destination end;
  if v_destination = 'credito' and v_sale.client_id is null then
    raise exception 'Estorno em crédito exige uma cliente cadastrada na comanda' using errcode = '22023';
  end if;

  if v_sale.client_id is not null then
    select * into v_client
    from public.clients c
    where c.id = v_sale.client_id and c.org_id = p_org_id
    for update;
  end if;

  -- 1. Dinheiro: saída no caixa por forma de pagamento (ou uma saída em crédito da cliente).
  if v_destination = 'caixa' then
    for r in
      select p.method, pg_catalog.round(sum(p.amount), 2) as amount
      from public.sale_payments p
      where p.sale_id = v_sale.id and p.org_id = p_org_id and p.method <> 'GIFT_CARD'
      group by p.method
      having sum(p.amount) > 0
    loop
      insert into public.transactions (
        org_id, sale_id, client_id, client_name, type, category, description, value, method, date, status, created_by
      ) values (
        p_org_id, v_sale.id, v_sale.client_id, v_sale.client_name, 'expense', 'estorno',
        'Estorno ' || v_label || ' - ' || v_sale.client_name, r.amount, r.method, v_today, 'completed', v_user_id
      );
    end loop;
  elsif v_destination = 'credito' then
    insert into public.transactions (
      org_id, sale_id, client_id, client_name, type, category, description, value, method, date, status, created_by
    ) values (
      p_org_id, v_sale.id, v_sale.client_id, v_sale.client_name, 'expense', 'estorno',
      'Estorno em crédito ' || v_label || ' - ' || v_sale.client_name, pg_catalog.round(v_money, 2),
      'CLIENT_CREDIT', v_today, 'completed', v_user_id
    );
  end if;

  -- 2. Vale-presente usado volta para o vale.
  for r in
    select upper(pg_catalog.btrim(p.gift_card_code)) as code, pg_catalog.round(sum(p.amount), 2) as amount
    from public.sale_payments p
    where p.sale_id = v_sale.id and p.org_id = p_org_id and p.method = 'GIFT_CARD' and p.gift_card_code is not null
    group by 1
  loop
    update public.gift_cards g
       set remaining_value = least(g.initial_value, g.remaining_value + r.amount),
           status = case when g.status = 'used' then 'active' else g.status end
     where g.org_id = p_org_id and upper(g.code) = r.code;
  end loop;

  -- 3. Sinal aplicado nesta comanda.
  update public.appointment_deposits d
     set status = 'refunded'
   where d.org_id = p_org_id and d.sale_id = v_sale.id and d.status = 'applied';
  get diagnostics v_deposits = row_count;

  -- 4. Extrato da cliente e fidelidade (só comanda que chegou a ser cobrada).
  if v_sale.client_id is not null and v_sale.status in ('partial', 'paid') then
    select coalesce(sum(e.amount), 0),
           coalesce(-sum(e.amount) filter (where e.entry_type = 'client_credit_used'), 0)
      into v_ledger_net, v_credit_used
    from public.client_balance_entries e
    where e.org_id = p_org_id and e.client_id = v_sale.client_id and e.sale_id = v_sale.id;

    if abs(v_ledger_net) >= 0.01 then
      perform public.apply_client_balance_entry_internal(
        p_org_id, v_sale.client_id, v_sale.id, 'sale_refund_reversal', pg_catalog.round(-v_ledger_net, 2),
        'sale_refund', 'Estorno ' || v_label || ': desfaz o que a venda moveu no saldo', v_user_id);
    end if;
    if v_destination = 'credito' then
      perform public.apply_client_balance_entry_internal(
        p_org_id, v_sale.client_id, v_sale.id, 'refund_credit', pg_catalog.round(v_money, 2),
        'sale_refund', 'Estorno ' || v_label || ' em crédito', v_user_id);
    end if;

    select coalesce(sum(case l.entry_type when 'credit' then abs(l.points) when 'debit' then -abs(l.points) else l.points end), 0)
      into v_points_net
    from public.loyalty_point_entries l
    where l.org_id = p_org_id and l.client_id = v_sale.client_id and l.source_type = 'sale' and l.source_id = v_sale.id;

    v_points_before := coalesce(v_client.loyalty_points, 0);
    v_points_after := greatest(0, v_points_before - greatest(v_points_net, 0));
    if v_points_after <> v_points_before then
      insert into public.loyalty_point_entries (
        org_id, client_id, entry_type, points, balance_before, balance_after,
        source_type, source_id, description, created_by
      ) values (
        p_org_id, v_sale.client_id, 'debit', v_points_before - v_points_after, v_points_before, v_points_after,
        'sale_refund', v_sale.id, 'Pontos devolvidos no estorno ' || v_label, v_user_id
      );
    end if;
    update public.clients c
       set loyalty_points = v_points_after,
           loyalty_tier = public.loyalty_tier_for(v_points_after),
           total_spent = greatest(0, coalesce(c.total_spent, 0) - (coalesce(v_sale.total, 0) + v_credit_used))
     where c.id = v_sale.client_id and c.org_id = p_org_id;
  end if;

  -- 5. Pacotes: sessões consumidas neste atendimento voltam; pacote vendido nesta comanda é cancelado.
  if v_sale.status in ('partial', 'paid') then
    if v_sale.appointment_id is not null then
      for r in
        select e.entitlement_id, -sum(e.sessions_delta) as net
        from public.client_entitlement_entries e
        where e.org_id = p_org_id and e.appointment_id = v_sale.appointment_id and e.action in ('consume', 'restore')
        group by e.entitlement_id
        having -sum(e.sessions_delta) > 0
      loop
        select greatest(0, en.used_sessions - r.net) into v_after
        from public.client_entitlements en
        where en.id = r.entitlement_id and en.org_id = p_org_id
        for update;
        if found then
          insert into public.client_entitlement_entries (
            org_id, entitlement_id, client_id, appointment_id, service_name, action,
            sessions_delta, sessions_before, sessions_after, description, created_by
          )
          select p_org_id, en.id, en.client_id, v_sale.appointment_id, null, 'restore',
                 en.used_sessions - v_after, en.used_sessions, v_after, 'Sessão devolvida no estorno ' || v_label, v_user_id
          from public.client_entitlements en
          where en.id = r.entitlement_id and en.used_sessions - v_after > 0;
          update public.client_entitlements en
             set used_sessions = v_after,
                 status = case when en.status = 'exhausted' then 'active' else en.status end
           where en.id = r.entitlement_id and en.org_id = p_org_id;
          v_restored := v_restored + 1;
        end if;
      end loop;
    end if;

    for r in
      select en.id, en.package_name, en.used_sessions
      from public.client_entitlements en
      where en.org_id = p_org_id and en.sale_id = v_sale.id and en.status <> 'cancelled'
      for update
    loop
      if r.used_sessions > 0 then
        raise exception 'O pacote "%" vendido nesta comanda já teve % sessão(ões) usada(s). Devolva o consumo antes de estornar.',
          r.package_name, r.used_sessions using errcode = 'P0001';
      end if;
      update public.client_entitlements en set status = 'cancelled' where en.id = r.id;
      v_cancelled_packages := v_cancelled_packages + 1;
    end loop;
  end if;

  -- 6. Produtos voltam ao estoque somente quando a gestão marcou a devolução.
  if p_restock_products and v_sale.status in ('partial', 'paid') then
    for r in
      select i.item_id, sum(i.quantity)::integer as quantity
      from public.sale_items i
      where i.sale_id = v_sale.id and i.org_id = p_org_id and upper(i.item_type) = 'PRODUCT' and i.item_id is not null
      group by i.item_id
    loop
      update public.products pr set stock_qty = pr.stock_qty + r.quantity
       where pr.id = r.item_id and pr.org_id = p_org_id;
      if found then
        insert into public.stock_entries (org_id, product_id, type, quantity, reason, created_by)
        values (p_org_id, r.item_id, 'entrada', r.quantity, 'Estorno ' || v_label, v_user_id);
        v_restocked := v_restocked + 1;
      end if;
    end loop;
  end if;

  -- 7. Venda, atendimento e histórico.
  update public.sales s
     set status = 'cancelled', balance = 0, refunded_at = pg_catalog.now(), refund_reason = v_reason
   where s.id = v_sale.id and s.org_id = p_org_id;

  if v_sale.appointment_id is not null then
    select a.status into v_appointment_status
    from public.appointments a
    where a.id = v_sale.appointment_id and a.org_id = p_org_id
    for update;
    if v_appointment_status in ('Pago', 'Pago Parcial') then
      update public.appointments set status = 'Concluído'
       where id = v_sale.appointment_id and org_id = p_org_id;
      insert into public.appointment_status_history (org_id, appointment_id, status, changed_by, notes)
      values (p_org_id, v_sale.appointment_id, 'Concluído', v_user_id, 'Comanda estornada: ' || v_reason);
    end if;
  end if;

  insert into public.sale_refunds (
    org_id, sale_id, idempotency_key, amount, destination, reason, restock_products, details, created_by
  ) values (
    p_org_id, v_sale.id, p_idempotency_key, pg_catalog.round(v_money, 2), v_destination, v_reason,
    coalesce(p_restock_products, false) and v_sale.status in ('partial', 'paid'),
    pg_catalog.jsonb_build_object(
      'previous_status', v_sale.status, 'total', v_sale.total, 'paid_amount', v_sale.paid_amount,
      'gift_card_returned', v_gift, 'ledger_reversed', pg_catalog.round(-v_ledger_net, 2),
      'points_returned', greatest(v_points_net, 0), 'sessions_restored_entitlements', v_restored,
      'packages_cancelled', v_cancelled_packages, 'products_restocked', v_restocked,
      'deposits_refunded', v_deposits),
    v_user_id
  )
  returning * into v_refund;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (
    p_org_id, v_user_id, 'sales',
    case when v_sale.status = 'draft' then 'SALE_CANCELLED' else 'SALE_REFUNDED' end,
    v_sale.id,
    pg_catalog.jsonb_build_object('status', v_sale.status, 'total', v_sale.total, 'paid_amount', v_sale.paid_amount),
    pg_catalog.jsonb_build_object(
      'refund_id', v_refund.id, 'reason', v_reason, 'destination', v_destination,
      'amount', v_refund.amount, 'details', v_refund.details)
  );

  return pg_catalog.jsonb_build_object(
    'saleId', v_sale.id, 'refundId', v_refund.id, 'status', 'cancelled',
    'amount', v_refund.amount, 'destination', v_destination, 'duplicate', false);
end;
$$;

revoke all on function public.refund_sale_atomic(uuid, uuid, text, text, boolean, uuid) from public, anon;
grant execute on function public.refund_sale_atomic(uuid, uuid, text, text, boolean, uuid) to authenticated;
