-- Cancelar série e ajuste de saldo: dois furos da revisão de 29 out.
-- Encoding: UTF-8
-- 1) cancel_recurrence_series_atomic: só quem tem agenda.manage (profissional não), e só
--    cancela ocorrências futuras ainda abertas; atendimento Iniciado ou já passado fica.
-- 2) adjust_client_balance_atomic: reaproveitar a chave de idempotência com outra cliente
--    recusa, em vez de devolver o saldo de outra pessoa.

create or replace function public.cancel_recurrence_series_atomic(p_org_id uuid, p_recurrence_id uuid)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_role text;
  v_ids uuid[];
  v_count integer := 0;
begin
  v_role := public.auth_user_role(p_org_id);
  if v_role is null or v_role not in ('owner', 'admin', 'manager', 'receptionist') then
    raise exception 'Sem permissao para cancelar a serie'
      using errcode = '42501';
  end if;

  select pg_catalog.array_agg(locked.id)
    into v_ids
  from (
    select a.id
    from public.appointments a
    where a.org_id = p_org_id
      and a.recurrence_id = p_recurrence_id
      and a.status in ('Reservado', 'Agendado', 'Confirmado')
      and a.start_at >= pg_catalog.now()
    for update
  ) locked;

  if coalesce(pg_catalog.array_length(v_ids, 1), 0) = 0 then
    return 0;
  end if;

  update public.appointments
  set status = 'Cancelado'
  where org_id = p_org_id
    and id = any(v_ids);

  get diagnostics v_count = row_count;

  insert into public.appointment_status_history (
    org_id, appointment_id, status, changed_by, notes
  )
  select
    p_org_id,
    appointment_id,
    'Cancelado',
    auth.uid(),
    'recurrence_cancelled'
  from pg_catalog.unnest(v_ids) as item(appointment_id);

  insert into public.audit_logs (
    org_id, user_id, table_name, operation, record_id, new_data
  )
  values (
    p_org_id,
    auth.uid(),
    'appointments',
    'RECURRENCE_CANCELLED',
    p_recurrence_id,
    pg_catalog.jsonb_build_object(
      'recurrence_id', p_recurrence_id,
      'count', v_count,
      'appointment_ids', pg_catalog.to_jsonb(v_ids)
    )
  );

  return v_count;
end;
$$;

create or replace function public.adjust_client_balance_atomic(
  p_org_id uuid,
  p_client_id uuid,
  p_direction text,
  p_amount numeric,
  p_reason text default null::text,
  p_idempotency_key uuid default null::uuid
) returns jsonb
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
      if v_existing.client_id is distinct from p_client_id then
        raise exception 'Chave de idempotencia ja usada por outra cliente'
          using errcode = '23514';
      end if;
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
