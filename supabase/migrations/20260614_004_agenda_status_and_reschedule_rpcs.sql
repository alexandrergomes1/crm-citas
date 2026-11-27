-- ============================================================
-- KA Beauty OS - Atomic status, reschedule and series cancellation
-- Encoding: UTF-8
-- ============================================================

create or replace function public.set_appointment_status_atomic(
  p_org_id uuid,
  p_appointment_id uuid,
  p_status text
)
returns public.appointments
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_role text;
  v_previous public.appointments;
  v_updated public.appointments;
begin
  v_role := public.auth_user_role(p_org_id);
  if v_role not in ('owner', 'admin', 'manager', 'receptionist', 'professional') then
    raise exception 'Sem permissao para alterar o status'
      using errcode = '42501';
  end if;

  select *
    into v_previous
  from public.appointments a
  where a.id = p_appointment_id
    and a.org_id = p_org_id
  for update;

  if not found then
    raise exception 'Agendamento nao encontrado' using errcode = 'P0002';
  end if;

  if p_status not in (
    'Reservado', 'Agendado', 'Confirmado', 'Iniciado', 'Concluído',
    'Pago Parcial', 'Pago', 'Ausência', 'Cancelado'
  ) then
    raise exception 'Status de agendamento invalido' using errcode = '22023';
  end if;

  if not public.agenda_status_transition_allowed(v_previous.status, p_status) then
    raise exception 'Transicao de status nao permitida' using errcode = '22023';
  end if;

  if p_status = v_previous.status then
    return v_previous;
  end if;

  if p_status = 'Iniciado' and exists (
    select 1
    from public.appointment_items ai
    join public.services s
      on s.id = ai.ref_id
      and s.org_id = p_org_id
    where ai.org_id = p_org_id
      and ai.appointment_id = p_appointment_id
      and s.requires_anamnese = true
      and not exists (
        select 1
        from public.anamneses an
        where an.id = v_previous.linked_anamnese_id
          and an.org_id = p_org_id
          and an.appointment_id = p_appointment_id
          and an.status = 'signed'
      )
  ) then
    raise exception 'Este atendimento exige anamnese assinada antes de iniciar'
      using errcode = 'P0001';
  end if;

  update public.appointments
  set status = p_status
  where id = p_appointment_id
    and org_id = p_org_id
  returning * into v_updated;

  insert into public.appointment_status_history (
    org_id, appointment_id, status, changed_by, notes
  )
  values (
    p_org_id, p_appointment_id, p_status, auth.uid(), null
  );

  insert into public.audit_logs (
    org_id, user_id, table_name, operation, record_id, old_data, new_data
  )
  values (
    p_org_id,
    auth.uid(),
    'appointments',
    'STATUS_CHANGE',
    p_appointment_id,
    pg_catalog.jsonb_build_object('status', v_previous.status),
    pg_catalog.jsonb_build_object('status', v_updated.status)
  );

  return v_updated;
end;
$$;

create or replace function public.reschedule_appointment_atomic(
  p_org_id uuid,
  p_appointment_id uuid,
  p_start_at timestamptz
)
returns public.appointments
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_role text;
  v_previous public.appointments;
  v_updated public.appointments;
  v_end_at timestamptz;
begin
  v_role := public.auth_user_role(p_org_id);
  if v_role not in ('owner', 'admin', 'manager', 'receptionist', 'professional') then
    raise exception 'Sem permissao para reagendar'
      using errcode = '42501';
  end if;

  select *
    into v_previous
  from public.appointments a
  where a.id = p_appointment_id
    and a.org_id = p_org_id
  for update;

  if not found then
    raise exception 'Agendamento nao encontrado' using errcode = 'P0002';
  end if;

  if v_previous.status not in ('Reservado', 'Agendado', 'Confirmado', 'Iniciado') then
    raise exception 'Agendamento neste estado nao pode ser reagendado'
      using errcode = 'P0001';
  end if;

  v_end_at := p_start_at
    + pg_catalog.make_interval(mins => v_previous.duration_minutes);

  perform public.agenda_assert_slot_available(
    p_org_id,
    v_previous.staff_id,
    p_start_at,
    v_end_at,
    array[p_appointment_id],
    false
  );

  update public.appointments
  set start_at = p_start_at,
      end_at = v_end_at
  where id = p_appointment_id
    and org_id = p_org_id
  returning * into v_updated;

  insert into public.audit_logs (
    org_id, user_id, table_name, operation, record_id, old_data, new_data
  )
  values (
    p_org_id,
    auth.uid(),
    'appointments',
    'APPOINTMENT_RESCHEDULED',
    p_appointment_id,
    pg_catalog.jsonb_build_object(
      'start_at', v_previous.start_at,
      'end_at', v_previous.end_at
    ),
    pg_catalog.jsonb_build_object(
      'start_at', v_updated.start_at,
      'end_at', v_updated.end_at
    )
  );

  return v_updated;
end;
$$;

create or replace function public.cancel_recurrence_series_atomic(
  p_org_id uuid,
  p_recurrence_id uuid
)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_role text;
  v_ids uuid[];
  v_count integer := 0;
begin
  v_role := public.auth_user_role(p_org_id);
  if v_role not in ('owner', 'admin', 'manager', 'receptionist', 'professional') then
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
      and a.status in ('Reservado', 'Agendado', 'Confirmado', 'Iniciado')
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

revoke all on function public.set_appointment_status_atomic(
  uuid, uuid, text
) from public, anon;
grant execute on function public.set_appointment_status_atomic(
  uuid, uuid, text
) to authenticated;

revoke all on function public.reschedule_appointment_atomic(
  uuid, uuid, timestamptz
) from public, anon;
grant execute on function public.reschedule_appointment_atomic(
  uuid, uuid, timestamptz
) to authenticated;

revoke all on function public.cancel_recurrence_series_atomic(
  uuid, uuid
) from public, anon;
grant execute on function public.cancel_recurrence_series_atomic(
  uuid, uuid
) to authenticated;
