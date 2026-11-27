-- Preço e profissional de um serviço do agendamento numa operação só (revisão de 29 out).
-- Encoding: UTF-8
-- Antes o app fazia duas escritas (item e total) com o total calculado de uma leitura antiga:
-- duas edições ao mesmo tempo deixavam o total errado, e não havia auditoria. Agora
-- o agendamento é travado, o total sai da soma no próprio banco e a mudança fica no audit_logs.

create or replace function public.update_appointment_item_atomic(
  p_org_id uuid,
  p_appointment_id uuid,
  p_item_id uuid,
  p_price numeric,
  p_professional_id uuid
) returns numeric
language plpgsql
set search_path = ''
as $$
declare
  v_role text;
  v_status text;
  v_old_price numeric;
  v_old_professional uuid;
  v_total numeric;
begin
  v_role := public.auth_user_role(p_org_id);
  if v_role is null or v_role not in ('owner', 'admin', 'manager', 'receptionist') then
    raise exception 'Sem permissao para alterar agendamentos'
      using errcode = '42501';
  end if;

  if p_price is null or p_price < 0 or p_price > 100000 then
    raise exception 'Preco invalido'
      using errcode = '23514';
  end if;

  select status
    into v_status
  from public.appointments
  where id = p_appointment_id
    and org_id = p_org_id
  for update;

  if not found then
    raise exception 'Agendamento nao encontrado'
      using errcode = 'P0002';
  end if;

  if v_status in ('Pago', 'Pago Parcial', 'Cancelado', 'Ausência', 'Ausencia') then
    raise exception 'Atendimento % nao aceita mudanca nos servicos', v_status
      using errcode = '23514';
  end if;

  select price, professional_id
    into v_old_price, v_old_professional
  from public.appointment_items
  where id = p_item_id
    and appointment_id = p_appointment_id
    and org_id = p_org_id
  for update;

  if not found then
    raise exception 'Servico nao encontrado neste agendamento'
      using errcode = 'P0002';
  end if;

  update public.appointment_items
  set price = p_price,
      professional_id = p_professional_id
  where id = p_item_id
    and appointment_id = p_appointment_id
    and org_id = p_org_id;

  select coalesce(sum(price * qty), 0)
    into v_total
  from public.appointment_items
  where appointment_id = p_appointment_id
    and org_id = p_org_id;

  update public.appointments
  set total = v_total,
      updated_at = pg_catalog.now()
  where id = p_appointment_id
    and org_id = p_org_id;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (
    p_org_id,
    auth.uid(),
    'appointment_items',
    'APPOINTMENT_ITEM_UPDATED',
    p_item_id,
    pg_catalog.jsonb_build_object('price', v_old_price, 'professional_id', v_old_professional),
    pg_catalog.jsonb_build_object('price', p_price, 'professional_id', p_professional_id, 'total', v_total)
  );

  return v_total;
end;
$$;

revoke all on function public.update_appointment_item_atomic(uuid, uuid, uuid, numeric, uuid) from public;
revoke all on function public.update_appointment_item_atomic(uuid, uuid, uuid, numeric, uuid) from anon;
grant execute on function public.update_appointment_item_atomic(uuid, uuid, uuid, numeric, uuid) to authenticated;
