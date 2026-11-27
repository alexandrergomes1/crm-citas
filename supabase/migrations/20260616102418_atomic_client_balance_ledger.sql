-- ============================================================
-- KA Beauty OS - Atomic client balance ledger
-- Encoding: UTF-8
--
-- Keeps clients.balance as the fast-read projection, but makes manual balance
-- changes transactional with ledger, cash transaction and audit trail.
-- ============================================================

alter table public.client_balance_entries
  add column if not exists appointment_id uuid references public.appointments(id) on delete set null,
  add column if not exists sale_id uuid references public.sales(id) on delete set null,
  add column if not exists payment_id uuid references public.sale_payments(id) on delete set null,
  add column if not exists transaction_id uuid references public.transactions(id) on delete set null,
  add column if not exists idempotency_key uuid;

create unique index if not exists idx_client_balance_entries_idempotency
  on public.client_balance_entries (org_id, idempotency_key)
  where idempotency_key is not null;

create index if not exists idx_client_balance_entries_refs
  on public.client_balance_entries (org_id, sale_id, appointment_id, payment_id)
  where sale_id is not null or appointment_id is not null or payment_id is not null;

create or replace function public.adjust_client_balance_atomic(
  p_org_id uuid,
  p_client_id uuid,
  p_direction text,
  p_amount numeric,
  p_reason text default null,
  p_idempotency_key uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_role text;
  v_client public.clients;
  v_existing public.client_balance_entries;
  v_delta numeric(12,2);
  v_amount numeric(12,2);
  v_balance_before numeric(12,2);
  v_balance_after numeric(12,2);
  v_description text;
  v_transaction_id uuid;
  v_entry_id uuid;
begin
  if v_user_id is null then
    raise exception 'Sessao expirada' using errcode = '42501';
  end if;

  v_role := public.auth_user_role(p_org_id);
  if v_role is null or v_role not in ('owner', 'admin', 'manager') then
    raise exception 'Sem permissao para ajustar saldo'
      using errcode = '42501';
  end if;

  if p_direction not in ('credit', 'debit') then
    raise exception 'Direcao de saldo invalida' using errcode = '22023';
  end if;

  v_amount := round(p_amount, 2);
  if v_amount is null or v_amount <= 0 then
    raise exception 'Valor deve ser maior que zero' using errcode = '22023';
  end if;

  if p_idempotency_key is not null then
    select *
      into v_existing
    from public.client_balance_entries
    where org_id = p_org_id
      and idempotency_key = p_idempotency_key
    for update;

    if found then
      return jsonb_build_object(
        'entryId', v_existing.id,
        'balance', v_existing.balance_after,
        'duplicate', true
      );
    end if;
  end if;

  select *
    into v_client
  from public.clients
  where id = p_client_id
    and org_id = p_org_id
  for update;

  if not found then
    raise exception 'Cliente nao encontrado' using errcode = 'P0002';
  end if;

  v_delta := case when p_direction = 'credit' then v_amount else -v_amount end;
  v_balance_before := round(coalesce(v_client.balance, 0), 2);
  v_balance_after := round(v_balance_before + v_delta, 2);
  v_description := concat(
    'Ajuste manual de saldo (',
    case when p_direction = 'credit' then 'credito' else 'debito' end,
    ')',
    case when nullif(btrim(coalesce(p_reason, '')), '') is null
      then ''
      else ' - ' || btrim(p_reason)
    end
  );

  update public.clients
  set balance = v_balance_after
  where id = v_client.id
    and org_id = p_org_id;

  if not found then
    raise exception 'Saldo do cliente nao foi atualizado' using errcode = 'P0002';
  end if;

  insert into public.transactions (
    org_id, client_id, client_name, type, category, description,
    value, method, date, status, created_by
  ) values (
    p_org_id, v_client.id, v_client.full_name,
    case when p_direction = 'credit' then 'income' else 'expense' end,
    'ajuste_saldo', v_description,
    v_amount, 'CASH', current_date, 'completed', v_user_id
  )
  returning id into v_transaction_id;

  insert into public.client_balance_entries (
    org_id, client_id, entry_type, amount, balance_before, balance_after,
    source_type, source_id, description, created_by, transaction_id,
    idempotency_key
  ) values (
    p_org_id, v_client.id,
    case when p_direction = 'credit' then 'manual_credit' else 'manual_debit' end,
    v_delta, v_balance_before, v_balance_after,
    'manual_adjustment', v_transaction_id, v_description, v_user_id,
    v_transaction_id, p_idempotency_key
  )
  returning id into v_entry_id;

  insert into public.audit_logs (
    org_id, user_id, table_name, operation, record_id, old_data, new_data
  ) values (
    p_org_id, v_user_id, 'clients', 'balance_adjustment', v_client.id,
    jsonb_build_object('balance', v_balance_before),
    jsonb_build_object(
      'balance', v_balance_after,
      'delta', v_delta,
      'entry_id', v_entry_id,
      'transaction_id', v_transaction_id
    )
  );

  return jsonb_build_object(
    'entryId', v_entry_id,
    'transactionId', v_transaction_id,
    'balance', v_balance_after,
    'duplicate', false
  );
end;
$$;

grant execute on function public.adjust_client_balance_atomic(
  uuid, uuid, text, numeric, text, uuid
) to authenticated;
