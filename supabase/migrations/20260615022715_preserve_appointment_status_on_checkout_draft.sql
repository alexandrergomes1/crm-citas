-- Saving a checkout draft must not complete the related appointment.
do $migration$
declare
  v_definition text;
  v_old_block constant text := $old$
  v_appointment_status := case
    when v_status = 'draft' then 'Concluído'
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
$old$;
  v_new_block constant text := $new$
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
$new$;
begin
  select pg_get_functiondef(
    'public.confirm_checkout_atomic(uuid,jsonb)'::regprocedure
  ) into v_definition;

  if position(v_old_block in v_definition) = 0 then
    raise exception
      'confirm_checkout_atomic does not contain the expected appointment status block';
  end if;

  execute replace(v_definition, v_old_block, v_new_block);
end;
$migration$;
