-- ============================================================
-- KA Beauty OS - Atomic appointment create/update
-- Encoding: UTF-8
-- ============================================================

create or replace function public.agenda_status_transition_allowed(
  p_current text,
  p_next text
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_current = p_next or case p_current
    when 'Reservado' then p_next in ('Confirmado', 'Ausência', 'Cancelado')
    when 'Agendado' then p_next in ('Confirmado', 'Ausência', 'Cancelado')
    when 'Confirmado' then p_next in ('Iniciado', 'Ausência', 'Cancelado')
    when 'Iniciado' then p_next in ('Concluído', 'Cancelado')
    when 'Concluído' then p_next in ('Pago Parcial', 'Pago')
    when 'Pago Parcial' then p_next = 'Pago'
    else false
  end;
$$;

create or replace function public.agenda_assert_slot_available(
  p_org_id uuid,
  p_staff_id uuid,
  p_start_at timestamptz,
  p_end_at timestamptz,
  p_exclude_appointment_ids uuid[] default '{}'::uuid[],
  p_force_override boolean default false
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if p_end_at <= p_start_at then
    raise exception 'Horario final deve ser posterior ao inicial'
      using errcode = '22023';
  end if;

  if p_staff_id is null then
    return;
  end if;

  if not exists (
    select 1
    from public.staff_members sm
    where sm.id = p_staff_id
      and sm.org_id = p_org_id
      and sm.active = true
  ) then
    raise exception 'Profissional nao encontrado nesta organizacao'
      using errcode = 'P0002';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_org_id::text || ':' || p_staff_id::text, 0)
  );

  if p_force_override then
    return;
  end if;

  if exists (
    select 1
    from public.appointments a
    where a.org_id = p_org_id
      and a.staff_id = p_staff_id
      and a.id <> all(coalesce(p_exclude_appointment_ids, '{}'::uuid[]))
      and a.status not in ('Cancelado', 'Ausência')
      and a.start_at < p_end_at
      and a.end_at > p_start_at
  ) then
    raise exception 'O profissional ja possui um atendimento neste horario'
      using errcode = '23P01';
  end if;

  if exists (
    select 1
    from public.time_blocks tb
    where tb.org_id = p_org_id
      and (tb.staff_id = p_staff_id or tb.staff_id is null)
      and tb.start_at < p_end_at
      and tb.end_at > p_start_at
  ) then
    raise exception 'O profissional possui um bloqueio neste horario'
      using errcode = '23P01';
  end if;
end;
$$;

create or replace function public.create_appointment_atomic(
  p_org_id uuid,
  p_client_id uuid,
  p_staff_id uuid,
  p_start_at timestamptz,
  p_end_at timestamptz,
  p_duration_minutes integer,
  p_status text,
  p_source text,
  p_notes text,
  p_internal_notes text,
  p_total numeric,
  p_items jsonb,
  p_force_override boolean default false
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_role text;
  v_client public.clients;
  v_staff_name text := '';
  v_appointment_id uuid;
  v_item jsonb;
  v_service_id uuid;
  v_professional_id uuid;
  v_internal_notes text := nullif(pg_catalog.btrim(p_internal_notes), '');
begin
  v_role := public.auth_user_role(p_org_id);
  if v_role not in ('owner', 'admin', 'manager', 'receptionist', 'professional') then
    raise exception 'Sem permissao para criar agendamentos'
      using errcode = '42501';
  end if;

  if p_force_override and v_role not in ('owner', 'admin', 'manager') then
    raise exception 'Somente gestores podem forcar conflitos'
      using errcode = '42501';
  end if;

  if p_duration_minutes < 1 or p_duration_minutes > 1440 then
    raise exception 'Duracao invalida' using errcode = '22023';
  end if;

  if p_status not in (
    'Reservado', 'Agendado', 'Confirmado', 'Iniciado', 'Concluído',
    'Pago Parcial', 'Pago', 'Ausência', 'Cancelado'
  ) then
    raise exception 'Status de agendamento invalido' using errcode = '22023';
  end if;

  if p_source not in ('MANUAL', 'WHATSAPP', 'ONLINE', 'PHONE') then
    raise exception 'Origem de agendamento invalida' using errcode = '22023';
  end if;

  if p_total < 0 or p_total > 1000000 then
    raise exception 'Total do agendamento invalido' using errcode = '22003';
  end if;

  if pg_catalog.jsonb_typeof(coalesce(p_items, '[]'::jsonb)) <> 'array' then
    raise exception 'Itens invalidos' using errcode = '22023';
  end if;

  select *
    into v_client
  from public.clients c
  where c.id = p_client_id
    and c.org_id = p_org_id
  for share;

  if not found then
    raise exception 'Cliente nao encontrado nesta organizacao'
      using errcode = 'P0002';
  end if;

  if v_client.blocked_at is not null and not p_force_override then
    raise exception 'Cliente possui bloqueio para novos agendamentos'
      using errcode = 'P0001';
  end if;

  perform public.agenda_assert_slot_available(
    p_org_id,
    p_staff_id,
    p_start_at,
    p_end_at,
    '{}'::uuid[],
    p_force_override
  );

  if p_staff_id is not null then
    select coalesce(sm.display_name, sm.name)
      into v_staff_name
    from public.staff_members sm
    where sm.id = p_staff_id
      and sm.org_id = p_org_id;
  end if;

  if p_force_override then
    v_internal_notes := pg_catalog.concat_ws(
      E'\n',
      pg_catalog.format(
        '[CONFLITO FORCADO - %s - %s]',
        v_role,
        pg_catalog.to_char(pg_catalog.now(), 'YYYY-MM-DD HH24:MI')
      ),
      v_internal_notes
    );
  end if;

  insert into public.appointments (
    org_id, client_id, client_name, staff_id, staff_name,
    start_at, end_at, duration_minutes, status, notes, internal_notes,
    source, total, discount, tip
  )
  values (
    p_org_id, p_client_id, v_client.full_name, p_staff_id, coalesce(v_staff_name, ''),
    p_start_at, p_end_at, p_duration_minutes, p_status,
    nullif(pg_catalog.btrim(p_notes), ''), v_internal_notes,
    p_source, pg_catalog.round(p_total, 2), 0, 0
  )
  returning id into v_appointment_id;

  for v_item in
    select value
    from pg_catalog.jsonb_array_elements(coalesce(p_items, '[]'::jsonb))
  loop
    if nullif(pg_catalog.btrim(v_item ->> 'service_name'), '') is null then
      raise exception 'Servico invalido' using errcode = '22023';
    end if;

    if (v_item ->> 'price')::numeric < 0 then
      raise exception 'Preco de servico invalido' using errcode = '22003';
    end if;

    v_service_id := nullif(v_item ->> 'service_id', '')::uuid;
    v_professional_id := coalesce(
      nullif(v_item ->> 'professional_id', '')::uuid,
      p_staff_id
    );

    if v_service_id is not null and not exists (
      select 1 from public.services s
      where s.id = v_service_id and s.org_id = p_org_id
    ) then
      raise exception 'Servico nao pertence a esta organizacao'
        using errcode = '23503';
    end if;

    if v_professional_id is not null and not exists (
      select 1 from public.staff_members sm
      where sm.id = v_professional_id and sm.org_id = p_org_id
    ) then
      raise exception 'Profissional do servico invalido'
        using errcode = '23503';
    end if;

    insert into public.appointment_items (
      org_id, appointment_id, type, ref_id, name, price,
      cost_amount, qty, discount, commission_pct, professional_id
    )
    values (
      p_org_id, v_appointment_id, 'service', v_service_id,
      v_item ->> 'service_name', (v_item ->> 'price')::numeric,
      0, 1, 0, 0, v_professional_id
    );
  end loop;

  insert into public.appointment_status_history (
    org_id, appointment_id, status, changed_by, notes
  )
  values (
    p_org_id, v_appointment_id, p_status, auth.uid(), 'appointment_created'
  );

  insert into public.audit_logs (
    org_id, user_id, table_name, operation, record_id, new_data
  )
  values (
    p_org_id,
    auth.uid(),
    'appointments',
    'APPOINTMENT_CREATED',
    v_appointment_id,
    pg_catalog.jsonb_build_object(
      'client_id', p_client_id,
      'staff_id', p_staff_id,
      'start_at', p_start_at,
      'end_at', p_end_at,
      'item_count', pg_catalog.jsonb_array_length(coalesce(p_items, '[]'::jsonb)),
      'force_override', p_force_override
    )
  );

  return v_appointment_id;
end;
$$;

revoke all on function public.agenda_status_transition_allowed(text, text) from public, anon;
grant execute on function public.agenda_status_transition_allowed(text, text) to authenticated;

revoke all on function public.agenda_assert_slot_available(
  uuid, uuid, timestamptz, timestamptz, uuid[], boolean
) from public, anon;
grant execute on function public.agenda_assert_slot_available(
  uuid, uuid, timestamptz, timestamptz, uuid[], boolean
) to authenticated;

revoke all on function public.create_appointment_atomic(
  uuid, uuid, uuid, timestamptz, timestamptz, integer, text,
  text, text, text, numeric, jsonb, boolean
) from public, anon;
grant execute on function public.create_appointment_atomic(
  uuid, uuid, uuid, timestamptz, timestamptz, integer, text,
  text, text, text, numeric, jsonb, boolean
) to authenticated;
