-- ============================================================
-- KA Beauty OS - Client balance reversal ledger flow
-- Encoding: UTF-8
--
-- Reversals are compensating entries. Historical ledger rows and
-- transactions are never deleted or mutated beyond reversal metadata.
-- ============================================================

alter table public.client_balance_entries
  add column if not exists reversal_of_entry_id uuid references public.client_balance_entries(id) on delete restrict,
  add column if not exists reversed_by_entry_id uuid references public.client_balance_entries(id) on delete restrict,
  add column if not exists reversed_at timestamptz,
  add column if not exists reversed_by uuid references auth.users(id) on delete set null,
  add column if not exists reversal_reason text;

create unique index if not exists idx_client_balance_entries_reversal_once
  on public.client_balance_entries (org_id, reversal_of_entry_id)
  where reversal_of_entry_id is not null;

create index if not exists idx_client_balance_entries_reversal_lookup
  on public.client_balance_entries (org_id, reversed_by_entry_id)
  where reversed_by_entry_id is not null;

create or replace function public.reverse_client_balance_entry_atomic(
  p_org_id uuid,
  p_entry_id uuid,
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
  v_original public.client_balance_entries;
  v_existing public.client_balance_entries;
  v_client public.clients;
  v_original_tx public.transactions;
  v_reversal_amount numeric(12,2);
  v_balance_before numeric(12,2);
  v_balance_after numeric(12,2);
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_description text;
  v_reversal_tx_id uuid;
  v_reversal_entry_id uuid;
begin
  if v_user_id is null then
    raise exception 'Sessao expirada' using errcode = '42501';
  end if;

  v_role := public.auth_user_role(p_org_id);
  if v_role is null or v_role not in ('owner', 'admin', 'manager', 'finance') then
    raise exception 'Sem permissao para reverter saldo'
      using errcode = '42501';
  end if;

  if p_entry_id is null then
    raise exception 'Lancamento original obrigatorio' using errcode = '22023';
  end if;

  if p_idempotency_key is not null then
    select *
      into v_existing
    from public.client_balance_entries
    where org_id = p_org_id
      and idempotency_key = p_idempotency_key
    for update;

    if found then
      if v_existing.reversal_of_entry_id = p_entry_id then
        select *
          into v_original
        from public.client_balance_entries
        where id = p_entry_id
          and org_id = p_org_id;

        return jsonb_build_object(
          'entryId', p_entry_id,
          'reversalEntryId', v_existing.id,
          'transactionId', v_existing.transaction_id,
          'balance', v_existing.balance_after,
          'duplicate', true,
          'originalAlreadyReversed', v_original.reversed_by_entry_id is not null
        );
      end if;

      raise exception 'Chave de idempotencia ja usada em outra operacao'
        using errcode = '23505';
    end if;
  end if;

  select *
    into v_original
  from public.client_balance_entries
  where id = p_entry_id
    and org_id = p_org_id
  for update;

  if not found then
    raise exception 'Lancamento de saldo nao encontrado' using errcode = 'P0002';
  end if;

  if v_original.reversal_of_entry_id is not null then
    raise exception 'Lancamento de reversao nao pode ser revertido por esta operacao'
      using errcode = '22023';
  end if;

  if v_original.reversed_by_entry_id is not null then
    raise exception 'Lancamento de saldo ja revertido' using errcode = '23505';
  end if;

  if abs(round(v_original.amount, 2)) < 0.01 then
    raise exception 'Lancamento sem valor nao pode ser revertido' using errcode = '22023';
  end if;

  select *
    into v_client
  from public.clients
  where id = v_original.client_id
    and org_id = p_org_id
  for update;

  if not found then
    raise exception 'Cliente do lancamento nao encontrado' using errcode = 'P0002';
  end if;

  v_reversal_amount := round(-v_original.amount, 2);
  v_balance_before := round(coalesce(v_client.balance, 0), 2);
  v_balance_after := round(v_balance_before + v_reversal_amount, 2);
  v_description := concat(
    'Reversao de lancamento de saldo ',
    v_original.entry_type,
    case when v_reason is null then '' else ' - ' || v_reason end
  );

  if v_original.transaction_id is not null then
    select *
      into v_original_tx
    from public.transactions
    where id = v_original.transaction_id
      and org_id = p_org_id
    for update;

    if not found then
      raise exception 'Transacao original do lancamento nao encontrada' using errcode = 'P0002';
    end if;

    if v_original_tx.type not in ('income', 'expense') then
      raise exception 'Tipo de transacao original invalido para reversao' using errcode = '22023';
    end if;

    insert into public.transactions (
      org_id, sale_id, client_id, client_name, type, category, description,
      value, method, date, status, created_by
    ) values (
      p_org_id,
      v_original_tx.sale_id,
      v_original.client_id,
      coalesce(v_original_tx.client_name, v_client.full_name),
      case when v_original_tx.type = 'income' then 'expense' else 'income' end,
      coalesce(v_original_tx.category, 'ajuste_saldo'),
      v_description,
      abs(v_reversal_amount),
      v_original_tx.method,
      current_date,
      'completed',
      v_user_id
    )
    returning id into v_reversal_tx_id;
  end if;

  update public.clients
  set balance = v_balance_after
  where id = v_client.id
    and org_id = p_org_id;

  if not found then
    raise exception 'Saldo do cliente nao foi atualizado' using errcode = 'P0002';
  end if;

  insert into public.client_balance_entries (
    org_id, client_id, entry_type, amount, balance_before, balance_after,
    source_type, source_id, description, created_by,
    appointment_id, sale_id, payment_id, transaction_id, idempotency_key,
    reversal_of_entry_id, reversal_reason
  ) values (
    p_org_id, v_original.client_id, 'reversal', v_reversal_amount,
    v_balance_before, v_balance_after,
    'reversal', v_original.id, v_description, v_user_id,
    v_original.appointment_id, v_original.sale_id, v_original.payment_id,
    v_reversal_tx_id, p_idempotency_key, v_original.id, v_reason
  )
  returning id into v_reversal_entry_id;

  update public.client_balance_entries
  set reversed_by_entry_id = v_reversal_entry_id,
      reversed_at = now(),
      reversed_by = v_user_id,
      reversal_reason = v_reason
  where id = v_original.id
    and org_id = p_org_id
    and reversed_by_entry_id is null;

  if not found then
    raise exception 'Lancamento de saldo ja revertido' using errcode = '23505';
  end if;

  insert into public.audit_logs (
    org_id, user_id, table_name, operation, record_id, old_data, new_data
  ) values (
    p_org_id, v_user_id, 'client_balance_entries', 'balance_reversal', v_original.id,
    jsonb_build_object(
      'entry_id', v_original.id,
      'client_id', v_original.client_id,
      'amount', v_original.amount,
      'balance_before', v_balance_before
    ),
    jsonb_build_object(
      'reversal_entry_id', v_reversal_entry_id,
      'reversal_transaction_id', v_reversal_tx_id,
      'amount', v_reversal_amount,
      'balance_after', v_balance_after,
      'reason', v_reason
    )
  );

  return jsonb_build_object(
    'entryId', v_original.id,
    'reversalEntryId', v_reversal_entry_id,
    'transactionId', v_reversal_tx_id,
    'balance', v_balance_after,
    'duplicate', false
  );
end;
$$;

revoke all on function public.reverse_client_balance_entry_atomic(
  uuid, uuid, text, uuid
) from public, anon;
grant execute on function public.reverse_client_balance_entry_atomic(
  uuid, uuid, text, uuid
) to authenticated;
