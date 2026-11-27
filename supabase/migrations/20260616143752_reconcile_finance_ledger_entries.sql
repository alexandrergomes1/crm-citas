-- ============================================================
-- KA Beauty OS - Reconcile checkout ledger entries by financial origin
-- Encoding: UTF-8
--
-- Keeps checkout settlement atomic while separating client balance ledger
-- movements into auditable origins:
--   * client_credit_used
--   * sale_debit
--   * debt_payment
--   * overpayment_credit
-- ============================================================

create or replace function public.apply_client_balance_entry_internal(
  p_org_id uuid,
  p_client_id uuid,
  p_sale_id uuid,
  p_entry_type text,
  p_amount numeric,
  p_source_type text,
  p_description text,
  p_created_by uuid
)
returns numeric
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_client public.clients;
  v_amount numeric(12,2);
  v_balance_before numeric(12,2);
  v_balance_after numeric(12,2);
begin
  v_amount := round(coalesce(p_amount, 0), 2);
  if abs(v_amount) < 0.01 then
    select coalesce(balance, 0)
      into v_balance_after
    from public.clients
    where id = p_client_id and org_id = p_org_id;
    return coalesce(v_balance_after, 0);
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

  v_balance_before := round(coalesce(v_client.balance, 0), 2);
  v_balance_after := round(v_balance_before + v_amount, 2);

  update public.clients
  set balance = v_balance_after
  where id = p_client_id
    and org_id = p_org_id;

  if not found then
    raise exception 'Saldo do cliente nao foi atualizado' using errcode = 'P0002';
  end if;

  insert into public.client_balance_entries (
    org_id, client_id, entry_type, amount, balance_before, balance_after,
    source_type, source_id, sale_id, description, created_by
  ) values (
    p_org_id, p_client_id, p_entry_type, v_amount, v_balance_before, v_balance_after,
    p_source_type, p_sale_id, p_sale_id, p_description, p_created_by
  );

  return v_balance_after;
end;
$$;

revoke all on function public.apply_client_balance_entry_internal(
  uuid, uuid, uuid, text, numeric, text, text, uuid
) from public, anon, authenticated;

do $$
declare
  v_sql text;
  v_before text;
begin
  v_sql := pg_get_functiondef('public.confirm_checkout_atomic(uuid,jsonb)'::regprocedure);
  v_before := v_sql;

  v_sql := replace(v_sql, $old$
    if v_appointment.client_id is not null and abs(v_balance_delta) >= 0.01 then
      v_balance_before := v_client.balance;
      v_balance_after := round(v_balance_before + v_balance_delta, 2);
      update public.clients set balance = v_balance_after where id = v_client.id;
      insert into public.client_balance_entries (
        org_id, client_id, entry_type, amount, balance_before, balance_after,
        source_type, source_id, description, created_by
      ) values (
        p_org_id, v_client.id,
        case when v_balance_delta > 0 then 'credit' else 'debit' end,
        v_balance_delta, v_balance_before, v_balance_after,
        'sale_payment', v_sale.id, 'Pagamento posterior de comanda', v_user_id
      );
    end if;
$old$, $new$
    if v_appointment.client_id is not null then
      if round(v_sale.balance - v_pending, 2) >= 0.01 then
        perform public.apply_client_balance_entry_internal(
          p_org_id, v_client.id, v_sale.id, 'debt_payment',
          round(v_sale.balance - v_pending, 2), 'sale_payment',
          'Pagamento posterior de debito da comanda', v_user_id
        );
      end if;
      if v_overpaid >= 0.01 then
        perform public.apply_client_balance_entry_internal(
          p_org_id, v_client.id, v_sale.id, 'overpayment_credit',
          v_overpaid, 'sale_payment',
          'Excedente recebido no pagamento posterior', v_user_id
        );
      end if;
    end if;
$new$);

  if v_sql = v_before then
    raise exception 'confirm_checkout_atomic partial ledger block was not patched';
  end if;
  v_before := v_sql;

  v_sql := replace(v_sql, $old$
      if v_appointment.client_id is not null then
        v_balance_before := v_client.balance;
        v_balance_after := round(v_balance_before + v_balance_delta, 2);
        v_points := floor(v_gross);
        update public.clients set
          last_visit = current_date,
          total_spent = total_spent + v_gross,
          loyalty_points = loyalty_points + v_points,
          balance = v_balance_after
        where id = v_client.id;

        if abs(v_balance_delta) >= 0.01 then
          insert into public.client_balance_entries (
            org_id, client_id, entry_type, amount, balance_before, balance_after,
            source_type, source_id, description, created_by
          ) values (
            p_org_id, v_client.id,
            case when v_balance_delta > 0 then 'credit' else 'debit' end,
            v_balance_delta, v_balance_before, v_balance_after,
            'sale', v_sale.id, 'Efeito financeiro da comanda', v_user_id
          );
        end if;
$old$, $new$
      if v_appointment.client_id is not null then
        v_points := floor(v_gross);
        update public.clients set
          last_visit = current_date,
          total_spent = total_spent + v_gross,
          loyalty_points = loyalty_points + v_points
        where id = v_client.id;

        if v_credit >= 0.01 then
          perform public.apply_client_balance_entry_internal(
            p_org_id, v_client.id, v_sale.id, 'client_credit_used',
            -v_credit, 'sale_credit',
            'Credito do cliente usado na comanda', v_user_id
          );
        end if;
        if v_pending >= 0.01 then
          perform public.apply_client_balance_entry_internal(
            p_org_id, v_client.id, v_sale.id, 'sale_debit',
            -v_pending, 'sale',
            'Debito gerado por pagamento parcial', v_user_id
          );
        end if;
        if v_overpaid >= 0.01 then
          perform public.apply_client_balance_entry_internal(
            p_org_id, v_client.id, v_sale.id, 'overpayment_credit',
            v_overpaid, 'sale',
            'Excedente recebido na comanda', v_user_id
          );
        end if;
$new$);

  if v_sql = v_before then
    raise exception 'confirm_checkout_atomic initial ledger block was not patched';
  end if;

  execute v_sql;
end;
$$;

revoke all on function public.confirm_checkout_atomic(uuid, jsonb) from public, anon;
grant execute on function public.confirm_checkout_atomic(uuid, jsonb) to authenticated;
