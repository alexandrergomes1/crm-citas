-- Sinal: arredonda antes de validar, repete só para o mesmo agendamento e usa o fuso do estúdio.
-- Encoding: UTF-8
-- Antes: 0,004 passava na checagem (> 0) e gravava sinal de 0,00; reaproveitar a chave de
-- idempotência com outro agendamento devolvia o sinal antigo sem avisar; a data do lançamento
-- e a hora da nota saíam em UTC (entre 00h e 01h de Madri caía no dia anterior).

create or replace function public.register_appointment_deposit_atomic(
  p_org_id uuid,
  p_appointment_id uuid,
  p_amount numeric,
  p_method text,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text;
  v_appointment public.appointments;
  v_existing public.appointment_deposits;
  v_deposit public.appointment_deposits;
  v_transaction_id uuid;
  v_note text;
  v_appointment_total numeric(12,2);
  v_existing_total numeric(12,2);
  v_amount numeric(12,2);
  v_tz text;
begin
  if auth.uid() is null then
    raise exception 'Autenticacao obrigatoria' using errcode = '42501';
  end if;

  select ur.role::text
    into v_role
  from public.user_roles ur
  where ur.org_id = p_org_id
    and ur.user_id = auth.uid()
    and ur.active = true
  limit 1;

  if v_role is null or v_role not in (
    'owner', 'admin', 'manager', 'receptionist', 'finance'
  ) then
    raise exception 'Sem permissao para registrar sinal' using errcode = '42501';
  end if;

  v_amount := round(p_amount, 2);
  if v_amount is null or v_amount <= 0 or v_amount > 1000000 then
    raise exception 'Valor do sinal invalido' using errcode = '22003';
  end if;

  if p_method not in ('CASH', 'CARD_DEBIT', 'CARD_CREDIT', 'TRANSFER', 'BIZUM') then
    raise exception 'Metodo de pagamento invalido' using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_org_id::text || ':' || p_idempotency_key::text, 0)
  );

  select *
    into v_existing
  from public.appointment_deposits
  where org_id = p_org_id
    and idempotency_key = p_idempotency_key;

  if found then
    if v_existing.appointment_id is distinct from p_appointment_id then
      raise exception 'Chave de idempotencia ja usada em outro agendamento'
        using errcode = '23514';
    end if;
    return pg_catalog.jsonb_build_object(
      'deposit_id', v_existing.id,
      'amount', v_existing.amount,
      'duplicate', true
    );
  end if;

  select *
    into v_appointment
  from public.appointments
  where id = p_appointment_id
    and org_id = p_org_id
  for update;

  if not found then
    raise exception 'Agendamento nao encontrado' using errcode = 'P0002';
  end if;

  if v_appointment.client_id is null then
    raise exception 'Agendamento sem cliente cadastrado' using errcode = '23502';
  end if;

  if v_appointment.status not in ('Reservado', 'Agendado', 'Confirmado') then
    raise exception 'O sinal so pode ser registrado antes do inicio do atendimento'
      using errcode = 'P0001';
  end if;

  select coalesce(sum(ai.price * ai.qty), 0)
    into v_appointment_total
  from public.appointment_items ai
  where ai.org_id = p_org_id
    and ai.appointment_id = p_appointment_id;

  if v_appointment_total <= 0 then
    v_appointment_total := coalesce(v_appointment.total, 0);
  end if;

  select coalesce(sum(ad.amount), 0)
    into v_existing_total
  from public.appointment_deposits ad
  where ad.org_id = p_org_id
    and ad.appointment_id = p_appointment_id
    and ad.status in ('confirmed', 'applied');

  if v_appointment_total > 0
    and v_existing_total + v_amount > v_appointment_total then
    raise exception 'Sinal excede o valor atual do atendimento' using errcode = '22003';
  end if;

  select coalesce(nullif(o.timezone, ''), 'UTC')
    into v_tz
  from public.organizations o
  where o.id = p_org_id;

  insert into public.transactions (
    org_id,
    client_id,
    client_name,
    type,
    category,
    description,
    value,
    method,
    date,
    status,
    created_by
  )
  values (
    p_org_id,
    v_appointment.client_id,
    v_appointment.client_name,
    'income',
    'sinal',
    'Sinal - ' || v_appointment.client_name,
    v_amount,
    p_method,
    (pg_catalog.now() at time zone coalesce(v_tz, 'UTC'))::date,
    'completed',
    auth.uid()
  )
  returning id into v_transaction_id;

  insert into public.appointment_deposits (
    org_id,
    appointment_id,
    client_id,
    transaction_id,
    amount,
    method,
    idempotency_key,
    created_by
  )
  values (
    p_org_id,
    p_appointment_id,
    v_appointment.client_id,
    v_transaction_id,
    v_amount,
    p_method,
    p_idempotency_key,
    auth.uid()
  )
  returning * into v_deposit;

  v_note := pg_catalog.format(
    'Sinal de EUR %s registrado em %s (%s)',
    v_amount,
    pg_catalog.to_char(pg_catalog.now() at time zone coalesce(v_tz, 'UTC'), 'YYYY-MM-DD HH24:MI'),
    p_method
  );

  update public.appointments
  set internal_notes = case
    when internal_notes is null or pg_catalog.btrim(internal_notes) = '' then v_note
    else internal_notes || E'\n' || v_note
  end
  where id = p_appointment_id
    and org_id = p_org_id;

  insert into public.audit_logs (
    org_id,
    user_id,
    table_name,
    operation,
    record_id,
    new_data
  )
  values (
    p_org_id,
    auth.uid(),
    'appointment_deposits',
    'deposit_registered',
    v_deposit.id,
    pg_catalog.jsonb_build_object(
      'appointment_id', p_appointment_id,
      'client_id', v_appointment.client_id,
      'amount', v_deposit.amount,
      'method', v_deposit.method,
      'transaction_id', v_transaction_id
    )
  );

  return pg_catalog.jsonb_build_object(
    'deposit_id', v_deposit.id,
    'amount', v_deposit.amount,
    'duplicate', false
  );
end;
$$;
