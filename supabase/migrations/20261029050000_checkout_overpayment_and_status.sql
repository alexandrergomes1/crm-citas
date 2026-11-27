-- Revisão de funções de 29 out (achados da auditoria local com plpgsql_check).
-- Encoding: UTF-8.
-- confirm_checkout_atomic: definição de produção (conferida em 29 out; o repositório só
-- tinha 2 variáveis sem uso a mais, removidas aqui) com duas mudanças:
--   1. sinal confirmado maior que o total final vira crédito da cliente
--      (overpayment_credit), em vez de sumir;
--   2. atendimento Cancelado ou com Ausência não pode ser cobrado.
set client_encoding = 'UTF8';

CREATE OR REPLACE FUNCTION public.confirm_checkout_atomic(p_org_id uuid, p_command jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid := auth.uid();
  v_role text;
  v_request_id uuid;
  v_appointment_id uuid;
  v_mode text;
  v_hash text := md5(p_command::text);
  v_claimed uuid;
  v_saved_hash text;
  v_result jsonb;
  v_appointment public.appointments;
  v_client public.clients;
  v_sale public.sales;
  v_has_sale boolean := false;
  v_items jsonb := coalesce(p_command->'items', '[]'::jsonb);
  v_payments jsonb := coalesce(p_command->'payments', '[]'::jsonb);
  v_discount numeric(12,2);
  v_tip numeric(12,2);
  v_service_fee numeric(12,2);
  v_subtotal numeric(12,2);
  v_gross numeric(12,2);
  v_prepaid numeric(12,2) := 0;
  v_credit numeric(12,2) := 0;
  v_external_paid numeric(12,2) := 0;
  v_paid numeric(12,2) := 0;
  v_pending numeric(12,2) := 0;
  v_overpaid numeric(12,2) := 0;
  v_balance_delta numeric(12,2) := 0;
  v_balance_before numeric(12,2) := 0;
  v_balance_after numeric(12,2) := 0;
  v_points integer := 0;
  v_status text;
  v_appointment_status text;
  v_invalid boolean;
  v_increment numeric(12,2);
  v_old_gross numeric(12,2) := 0;
  v_old_total numeric(12,2) := 0;
  v_new_total numeric(12,2) := 0;
  v_spent_delta numeric(12,2) := 0;
  r_payment record;
  r_deposit record;
begin
  if v_user_id is null then
    raise exception 'Sessao expirada' using errcode = '42501';
  end if;
  v_role := public.auth_user_role(p_org_id);
  if v_role is null or v_role not in (
    'owner', 'admin', 'manager', 'receptionist', 'finance'
  ) then
    raise exception 'Sem permissao para registrar pagamentos'
      using errcode = '42501';
  end if;

  begin
    v_request_id := (p_command->>'request_id')::uuid;
    v_appointment_id := (p_command->>'appointment_id')::uuid;
  exception when invalid_text_representation then
    raise exception 'Identificador invalido' using errcode = '22023';
  end;

  v_mode := coalesce(p_command->>'mode', 'finalize');
  if v_mode not in ('finalize', 'draft') then
    raise exception 'Modo de checkout invalido' using errcode = '22023';
  end if;

  insert into public.checkout_requests (
    org_id, request_id, appointment_id, payload_hash, created_by
  )
  values (
    p_org_id, v_request_id, v_appointment_id, v_hash, v_user_id
  )
  on conflict (org_id, request_id) do nothing
  returning request_id into v_claimed;

  if v_claimed is null then
    select payload_hash, result
      into v_saved_hash, v_result
    from public.checkout_requests
    where org_id = p_org_id
      and request_id = v_request_id;

    if v_saved_hash is distinct from v_hash then
      raise exception 'Chave idempotente reutilizada com dados diferentes'
        using errcode = '22023';
    end if;
    if v_result is null then
      raise exception 'Checkout em processamento; tente novamente'
        using errcode = '40001';
    end if;
    return v_result;
  end if;

  select *
    into v_appointment
  from public.appointments
  where id = v_appointment_id
    and org_id = p_org_id
  for update;

  if not found then
    raise exception 'Agendamento nao encontrado' using errcode = 'P0002';
  end if;

  if v_appointment.client_id is not null then
    select *
      into v_client
    from public.clients
    where id = v_appointment.client_id
      and org_id = p_org_id
    for update;
    if not found then
      raise exception 'Cliente do agendamento nao encontrado'
        using errcode = 'P0002';
    end if;
  end if;

  select *
    into v_sale
  from public.sales
  where appointment_id = v_appointment_id
    and org_id = p_org_id
  for update;
  v_has_sale := found;

  if v_has_sale and v_sale.status = 'paid' then
    v_result := jsonb_build_object(
      'saleId', v_sale.id,
      'status', 'paid',
      'pendingAmount', v_sale.balance,
      'overpaidAmount', 0,
      'creditApplied', 0,
      'duplicate', true
    );
    update public.checkout_requests set result = v_result
    where org_id = p_org_id and request_id = v_request_id;
    return v_result;
  end if;

  -- Atendimento cancelado ou com ausência não vira Pago (a comanda já paga retornou acima).
  if v_appointment.status in ('Cancelado', 'Ausência') then
    raise exception 'Atendimento cancelado ou com ausência não pode ser cobrado'
      using errcode = 'P0001';
  end if;

  if jsonb_typeof(v_items) <> 'array' or jsonb_array_length(v_items) = 0 then
    raise exception 'Adicione pelo menos um item a comanda'
      using errcode = '22023';
  end if;
  if jsonb_typeof(v_payments) <> 'array' then
    raise exception 'Pagamentos invalidos' using errcode = '22023';
  end if;

  select exists (
    select 1
    from jsonb_array_elements(v_items) item
    where coalesce(item->>'name', '') = ''
      or coalesce((item->>'quantity')::integer, 0) < 1
      or coalesce((item->>'unit_price')::numeric, -1) < 0
      or upper(coalesce(item->>'item_type', '')) not in ('SERVICE', 'PRODUCT', 'PACKAGE')
  ) into v_invalid;
  if v_invalid then
    raise exception 'Item de comanda invalido' using errcode = '22023';
  end if;

  select exists (
    select 1
    from jsonb_array_elements(v_payments) payment
    where coalesce((payment->>'amount')::numeric, -1) < 0
      or coalesce(payment->>'method', '') not in (
        'CASH', 'BIZUM', 'CARD_DEBIT', 'CARD_CREDIT', 'TRANSFER', 'GIFT_CARD'
      )
  ) into v_invalid;
  if v_invalid then
    raise exception 'Pagamento invalido' using errcode = '22023';
  end if;

  select round(coalesce(sum(
    (item->>'unit_price')::numeric * (item->>'quantity')::integer
  ), 0), 2)
    into v_subtotal
  from jsonb_array_elements(v_items) item;

  v_discount := round(greatest(0, coalesce((p_command->>'discount')::numeric, 0)), 2);
  v_tip := round(greatest(0, coalesce((p_command->>'tip')::numeric, 0)), 2);
  v_service_fee := round(greatest(0, coalesce((p_command->>'service_fee')::numeric, 0)), 2);
  if v_discount > v_subtotal then v_discount := v_subtotal; end if;
  v_gross := round(greatest(0, v_subtotal - v_discount + v_tip + v_service_fee), 2);

  if v_has_sale and v_sale.status = 'partial' then
    if v_mode = 'draft' then
      raise exception 'Uma comanda parcial nao pode voltar para rascunho'
        using errcode = '22023';
    end if;

    -- Itens originais sao imutaveis: cada assinatura original deve continuar presente
    -- na mesma contagem (ou mais, no caso de servicos adicionados).
    select exists (
      select 1
      from (
        select concat_ws('|', item_type, coalesce(item_id::text, ''), name,
          coalesce(category, ''), round(unit_price * 100)::text, quantity::text) as fp,
          count(*) as c
        from public.sale_items
        where sale_id = v_sale.id and org_id = p_org_id
        group by 1
      ) o
      left join (
        select concat_ws('|', item->>'item_type', coalesce(item->>'item_id', ''), item->>'name',
          coalesce(item->>'category', ''), round((item->>'unit_price')::numeric * 100)::text,
          (item->>'quantity')::text) as fp,
          count(*) as c
        from jsonb_array_elements(v_items) item
        group by 1
      ) n on n.fp = o.fp
      where coalesce(n.c, 0) < o.c
    ) into v_invalid;
    if v_invalid then
      raise exception 'Os itens originais da comanda nao podem ser removidos ou alterados'
        using errcode = '22023';
    end if;

    -- Itens adicionados (produtos/pacotes/cobertos) nao sao permitidos: eles mexem em
    -- estoque/beneficios. Garantir que todo item nao-servico ja existia identico no original.
    select exists (
      select 1
      from (
        select concat_ws('|', item->>'item_type', coalesce(item->>'item_id', ''), item->>'name',
          coalesce(item->>'category', ''), round((item->>'unit_price')::numeric * 100)::text,
          (item->>'quantity')::text) as fp,
          count(*) as c
        from jsonb_array_elements(v_items) item
        where coalesce((item->>'covered_by_entitlement')::boolean, false)
          or upper(coalesce(item->>'item_type', '')) <> 'SERVICE'
        group by 1
      ) n
      left join (
        select concat_ws('|', item_type, coalesce(item_id::text, ''), name,
          coalesce(category, ''), round(unit_price * 100)::text, quantity::text) as fp,
          count(*) as c
        from public.sale_items
        where sale_id = v_sale.id and org_id = p_org_id
        group by 1
      ) o on o.fp = n.fp
      where coalesce(o.c, 0) <> n.c
    ) into v_invalid;
    if v_invalid then
      raise exception 'Produtos e pacotes nao podem ser adicionados ao pagar o restante; use uma nova comanda'
        using errcode = '22023';
    end if;

    -- Pagamentos registrados nao podem ser removidos/reduzidos.
    with current_payments as (
      select payment->>'method' as method,
        nullif(upper(pg_catalog.btrim(payment->>'gift_card_code')), '') as gift_card_code,
        round(sum((payment->>'amount')::numeric), 2) as amount
      from jsonb_array_elements(v_payments) payment
      group by 1, 2
    ), previous_payments as (
      select method, nullif(upper(pg_catalog.btrim(gift_card_code)), '') as gift_card_code,
        round(sum(amount), 2) as amount
      from public.sale_payments
      where sale_id = v_sale.id and org_id = p_org_id
      group by 1, 2
    )
    select exists (
      select 1 from previous_payments previous
      left join current_payments current
        on current.method = previous.method
       and current.gift_card_code is not distinct from previous.gift_card_code
      where current.amount is null or current.amount < previous.amount
    ) into v_invalid;
    if v_invalid then
      raise exception 'Pagamentos registrados nao podem ser removidos ou alterados'
        using errcode = '22023';
    end if;

    select round(coalesce(sum((payment->>'amount')::numeric), 0), 2)
      into v_paid
    from jsonb_array_elements(v_payments) payment;

    -- Reconciliacao: novo total = total anterior + diferenca de gross (servicos/gorjeta/desconto).
    -- gross calculado a partir dos campos persistidos (sem service_fee, que nao e armazenado).
    v_old_gross := round(greatest(0, v_sale.subtotal - v_sale.discount + v_sale.tip), 2);
    v_old_total := round(v_sale.total, 2);
    v_new_total := round(v_old_total + (round(greatest(0, v_subtotal - v_discount + v_tip), 2) - v_old_gross), 2);
    if v_new_total < 0 then v_new_total := 0; end if;

    v_increment := round(v_paid - v_sale.paid_amount, 2);
    if v_increment < 0 then
      raise exception 'Pagamentos registrados nao podem ser reduzidos' using errcode = '22023';
    end if;
    if v_increment < 0.01 and v_new_total = v_old_total then
      raise exception 'Adicione um novo pagamento ou um novo item' using errcode = '22023';
    end if;

    v_pending := round(greatest(0, v_new_total - v_paid), 2);
    v_overpaid := round(greatest(0, v_paid - v_new_total), 2);
    v_balance_delta := round(v_sale.balance - v_pending + v_overpaid, 2);
    v_status := case when v_pending > 0.009 then 'partial' else 'paid' end;

    -- Aplica apenas os pagamentos incrementais (diferenca por metodo/vale).
    for r_payment in
      with current_payments as (
        select payment->>'method' as method,
          nullif(upper(pg_catalog.btrim(payment->>'gift_card_code')), '') as gift_card_code,
          round(sum((payment->>'amount')::numeric), 2) as amount
        from jsonb_array_elements(v_payments) payment
        group by 1, 2
      ), previous_payments as (
        select method, nullif(upper(pg_catalog.btrim(gift_card_code)), '') as gift_card_code,
          round(sum(amount), 2) as amount
        from public.sale_payments
        where sale_id = v_sale.id and org_id = p_org_id
        group by 1, 2
      )
      select current.method, current.gift_card_code,
        round(current.amount - coalesce(previous.amount, 0), 2) as amount
      from current_payments current
      left join previous_payments previous
        on previous.method = current.method
       and previous.gift_card_code is not distinct from current.gift_card_code
      where current.amount > coalesce(previous.amount, 0)
    loop
      perform public.checkout_apply_payment_internal(
        p_org_id, v_sale.id, v_appointment_id, v_appointment.client_id,
        v_appointment.client_name, r_payment.method, r_payment.amount,
        r_payment.gift_card_code,
        'Pagamento adicional - ' || v_appointment.client_name
      );
    end loop;

    -- Substitui os itens (originais + servicos adicionados). Como apenas servicos pagos
    -- podem ser adicionados, nao ha efeito de estoque/beneficio a aplicar.
    delete from public.sale_items where sale_id = v_sale.id and org_id = p_org_id;
    insert into public.sale_items (
      org_id, sale_id, item_type, item_id, name, category, unit_price, quantity,
      total_price, entitlement_id, covered_by_entitlement
    )
    select p_org_id, v_sale.id, item->>'item_type',
      nullif(item->>'item_id', '')::uuid, item->>'name', nullif(item->>'category', ''),
      round((item->>'unit_price')::numeric, 2), (item->>'quantity')::integer,
      round((item->>'unit_price')::numeric * (item->>'quantity')::integer, 2),
      nullif(item->>'entitlement_id', '')::uuid,
      coalesce((item->>'covered_by_entitlement')::boolean, false)
    from jsonb_array_elements(v_items) item;

    update public.sales set
      status = v_status, subtotal = v_subtotal, discount = v_discount, tip = v_tip,
      total = v_new_total, paid_amount = v_paid, balance = v_pending,
      notes = nullif(p_command->>'note', '')
    where id = v_sale.id;

    -- Ajusta total_spent e pontos do cliente pela diferenca de total cobrado.
    if v_appointment.client_id is not null then
      v_spent_delta := round(v_new_total - v_old_total, 2);
      v_points := floor(v_new_total)::integer - floor(v_old_total)::integer;
      if v_spent_delta <> 0 or v_points <> 0 then
        update public.clients set
          total_spent = total_spent + v_spent_delta,
          loyalty_points = greatest(0, loyalty_points + v_points)
        where id = v_client.id;
        if v_points <> 0 then
          insert into public.loyalty_point_entries (
            org_id, client_id, entry_type, points, balance_before, balance_after,
            source_type, source_id, description, created_by
          ) values (
            p_org_id, v_client.id,
            case when v_points > 0 then 'credit' else 'debit' end,
            abs(v_points), v_client.loyalty_points,
            greatest(0, v_client.loyalty_points + v_points), 'sale', v_sale.id,
            'Ajuste de pontos no pagamento posterior', v_user_id
          );
        end if;
      end if;
    end if;

    -- Ajusta o saldo do cliente pela variacao da pendencia.
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
  else
    if v_has_sale and v_sale.status not in ('draft') then
      raise exception 'Esta comanda nao pode receber novos pagamentos'
        using errcode = '22023';
    end if;

    if v_mode = 'finalize' then
      for r_deposit in
        select * from public.appointment_deposits
        where org_id = p_org_id and appointment_id = v_appointment_id
          and status = 'confirmed'
        for update
      loop
        v_prepaid := v_prepaid + r_deposit.amount;
      end loop;

      if v_appointment.client_id is not null
        and coalesce((p_command->>'use_credit')::boolean, false) then
        v_credit := round(least(greatest(v_client.balance, 0),
          greatest(v_gross - v_prepaid, 0)), 2);
      end if;
      select round(coalesce(sum((payment->>'amount')::numeric), 0), 2)
        into v_external_paid
      from jsonb_array_elements(v_payments) payment;
    end if;

    v_pending := round(greatest(0, v_gross - v_prepaid - v_credit - v_external_paid), 2);
    -- Excedente inclui o sinal: sinal maior que o total final (ex.: desconto depois do
    -- sinal) vira crédito da cliente em vez de sumir.
    v_overpaid := round(greatest(0, v_external_paid + v_prepaid + v_credit - v_gross), 2);
    v_balance_delta := round(-v_credit - v_pending + v_overpaid, 2);
    v_status := case
      when v_mode = 'draft' then 'draft'
      when v_pending > 0.009 then 'partial'
      else 'paid'
    end;

    if v_has_sale then
      delete from public.sale_items where sale_id = v_sale.id and org_id = p_org_id;
      delete from public.sale_payments where sale_id = v_sale.id and org_id = p_org_id;
      update public.sales set
        client_id = v_appointment.client_id,
        client_name = v_appointment.client_name,
        staff_id = v_appointment.staff_id,
        status = v_status, subtotal = v_subtotal, discount = v_discount, tip = v_tip,
        total = v_gross - v_credit,
        paid_amount = case when v_mode = 'draft' then 0 else v_external_paid + v_prepaid end,
        balance = v_pending, notes = nullif(p_command->>'note', '')
      where id = v_sale.id returning * into v_sale;
    else
      insert into public.sales (
        org_id, appointment_id, client_id, client_name, staff_id, status,
        subtotal, discount, tip, total, paid_amount, balance, notes
      ) values (
        p_org_id, v_appointment_id, v_appointment.client_id,
        v_appointment.client_name, v_appointment.staff_id, v_status,
        v_subtotal, v_discount, v_tip, v_gross - v_credit,
        case when v_mode = 'draft' then 0 else v_external_paid + v_prepaid end,
        v_pending, nullif(p_command->>'note', '')
      ) returning * into v_sale;
    end if;

    insert into public.sale_items (
      org_id, sale_id, item_type, item_id, name, category, unit_price, quantity,
      total_price, entitlement_id, covered_by_entitlement
    )
    select p_org_id, v_sale.id, item->>'item_type',
      nullif(item->>'item_id', '')::uuid, item->>'name', nullif(item->>'category', ''),
      round((item->>'unit_price')::numeric, 2), (item->>'quantity')::integer,
      round((item->>'unit_price')::numeric * (item->>'quantity')::integer, 2),
      nullif(item->>'entitlement_id', '')::uuid,
      coalesce((item->>'covered_by_entitlement')::boolean, false)
    from jsonb_array_elements(v_items) item;

    if v_mode = 'finalize' then
      insert into public.sale_payments (
        org_id, sale_id, method, amount, reference
      )
      select p_org_id, v_sale.id, method, amount, 'DEPOSIT:' || id::text
      from public.appointment_deposits
      where org_id = p_org_id and appointment_id = v_appointment_id
        and status = 'confirmed';

      for r_payment in
        select payment->>'method' as method,
          nullif(upper(pg_catalog.btrim(payment->>'gift_card_code')), '') as gift_card_code,
          round(sum((payment->>'amount')::numeric), 2) as amount
        from jsonb_array_elements(v_payments) payment
        group by 1, 2
        having round(sum((payment->>'amount')::numeric), 2) > 0
      loop
        perform public.checkout_apply_payment_internal(
          p_org_id, v_sale.id, v_appointment_id, v_appointment.client_id,
          v_appointment.client_name, r_payment.method, r_payment.amount,
          r_payment.gift_card_code, 'Atendimento - ' || v_appointment.client_name
        );
      end loop;

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
        if v_points > 0 then
          insert into public.loyalty_point_entries (
            org_id, client_id, entry_type, points, balance_before, balance_after,
            source_type, source_id, description, created_by
          ) values (
            p_org_id, v_client.id, 'credit', v_points, v_client.loyalty_points,
            v_client.loyalty_points + v_points, 'sale', v_sale.id,
            'Pontos do atendimento', v_user_id
          );
        end if;
      end if;

      perform public.checkout_apply_benefits_internal(
        p_org_id, v_sale.id, v_appointment_id, v_appointment.client_id, v_items
      );

      update public.appointment_deposits
      set status = 'applied', sale_id = v_sale.id
      where org_id = p_org_id and appointment_id = v_appointment_id
        and status = 'confirmed';
    end if;
  end if;

  if v_status <> 'draft' then
    v_appointment_status := case
      when v_status = 'partial' then 'Pago Parcial'
      else 'Pago'
    end;
    update public.appointments set status = v_appointment_status
    where id = v_appointment_id and org_id = p_org_id;
    insert into public.appointment_status_history (
      org_id, appointment_id, status, changed_by, notes
    ) values (
      p_org_id, v_appointment_id, v_appointment_status, v_user_id,
      'Status atualizado pelo checkout'
    );
  end if;

  insert into public.audit_logs (
    org_id, user_id, table_name, operation, record_id, old_data, new_data
  ) values (
    p_org_id, v_user_id, 'sales',
    case when v_has_sale then 'checkout_update' else 'checkout_create' end,
    v_sale.id,
    case when v_has_sale then jsonb_build_object(
      'status', v_sale.status, 'paid_amount', v_sale.paid_amount, 'balance', v_sale.balance
    ) else null end,
    jsonb_build_object(
      'request_id', v_request_id, 'status', v_status,
      'paid_amount', (select paid_amount from public.sales where id = v_sale.id),
      'balance', v_pending, 'client_balance_delta', v_balance_delta
    )
  );

  v_result := jsonb_build_object(
    'saleId', v_sale.id,
    'status', v_status,
    'pendingAmount', v_pending,
    'overpaidAmount', v_overpaid,
    'creditApplied', v_credit,
    'duplicate', false
  );
  update public.checkout_requests set result = v_result
  where org_id = p_org_id and request_id = v_request_id;
  return v_result;
end;
$function$;
