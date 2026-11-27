-- UTF-8
-- Permite anular um sinal (appointment_deposits) registrado por engano, desde
-- que ainda esteja em status 'confirmed' (isto e, ainda nao aplicado a uma
-- venda finalizada). Reverte a transacao financeira associada marcando-a como
-- 'cancelled', em vez de apagar o registro (mantem trilha de auditoria).

create or replace function public.void_appointment_deposit_atomic(
  p_org_id uuid,
  p_deposit_id uuid
)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_role text;
  v_deposit public.appointment_deposits;
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
    raise exception 'Sem permissao para remover sinal' using errcode = '42501';
  end if;

  select *
    into v_deposit
  from public.appointment_deposits
  where id = p_deposit_id
    and org_id = p_org_id
  for update;

  if not found then
    raise exception 'Sinal nao encontrado' using errcode = 'P0002';
  end if;

  if v_deposit.status <> 'confirmed' then
    raise exception 'Sinal ja aplicado a uma venda e nao pode ser removido aqui'
      using errcode = 'P0001';
  end if;

  update public.appointment_deposits
  set status = 'cancelled', updated_at = now()
  where id = p_deposit_id and org_id = p_org_id;

  if v_deposit.transaction_id is not null then
    update public.transactions
    set status = 'cancelled'
    where id = v_deposit.transaction_id and org_id = p_org_id;
  end if;

  insert into public.audit_logs (
    org_id, user_id, table_name, operation, record_id, new_data
  )
  values (
    p_org_id,
    auth.uid(),
    'appointment_deposits',
    'deposit_voided',
    p_deposit_id,
    jsonb_build_object(
      'appointment_id', v_deposit.appointment_id,
      'amount', v_deposit.amount,
      'transaction_id', v_deposit.transaction_id
    )
  );
end;
$function$;

revoke all on function public.void_appointment_deposit_atomic(uuid, uuid) from public;
grant execute on function public.void_appointment_deposit_atomic(uuid, uuid) to authenticated;
