create or replace function public.create_anamnese_atomic(
  p_org_id uuid,
  p_template_id uuid,
  p_client_id uuid,
  p_client_name text,
  p_appointment_id uuid default null,
  p_requires_professional boolean default null
)
returns public.anamneses
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_role text;
  v_template public.anamnese_templates;
  v_appointment public.appointments;
  v_client public.clients;
  v_result public.anamneses;
  v_client_id uuid := p_client_id;
  v_client_name text := nullif(pg_catalog.btrim(p_client_name), '');
begin
  v_role := public.auth_user_role(p_org_id);
  if v_role not in (
    'owner', 'admin', 'manager', 'receptionist', 'professional'
  ) then
    raise exception 'Sem permissao para gerar fichas de anamnese'
      using errcode = '42501';
  end if;

  select *
    into v_template
  from public.anamnese_templates t
  where t.id = p_template_id
    and t.org_id = p_org_id
    and t.active = true;

  if not found then
    raise exception 'Modelo de anamnese ativo nao encontrado'
      using errcode = 'P0002';
  end if;

  if p_appointment_id is not null then
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(
        p_org_id::text || ':' || p_appointment_id::text || ':' || p_template_id::text,
        0
      )
    );

    select *
      into v_appointment
    from public.appointments a
    where a.id = p_appointment_id
      and a.org_id = p_org_id
    for update;

    if not found then
      raise exception 'Agendamento nao encontrado'
        using errcode = 'P0002';
    end if;

    v_client_id := v_appointment.client_id;
    v_client_name := v_appointment.client_name;

    select *
      into v_result
    from public.anamneses an
    where an.org_id = p_org_id
      and an.appointment_id = p_appointment_id
      and an.template_id = p_template_id;

    if found then
      return v_result;
    end if;
  elsif v_client_id is not null then
    select *
      into v_client
    from public.clients c
    where c.id = v_client_id
      and c.org_id = p_org_id;

    if not found then
      raise exception 'Cliente nao encontrado nesta organizacao'
        using errcode = 'P0002';
    end if;
    v_client_name := v_client.full_name;
  end if;

  if v_client_name is null then
    raise exception 'Informe o cliente'
      using errcode = '22023';
  end if;

  insert into public.anamneses (
    org_id,
    template_id,
    template_title,
    template_snapshot,
    client_id,
    client_name,
    appointment_id,
    status,
    requires_professional,
    source_service_id,
    public_token,
    token_expires_at,
    consent_text,
    consent_version
  )
  values (
    p_org_id,
    v_template.id,
    v_template.title,
    pg_catalog.jsonb_build_object(
      'questions', v_template.questions,
      'consent_text', v_template.consent_text,
      'professional_form', v_template.professional_form
    ),
    v_client_id,
    v_client_name,
    p_appointment_id,
    'pending',
    coalesce(
      p_requires_professional,
      v_template.professional_form is not null
    ),
    null,
    pg_catalog.encode(extensions.gen_random_bytes(16), 'hex'),
    pg_catalog.now() + interval '7 days',
    v_template.consent_text,
    v_template.consent_version
  )
  returning * into v_result;

  if p_appointment_id is not null then
    update public.appointments
    set linked_anamnese_id = coalesce(linked_anamnese_id, v_result.id)
    where id = p_appointment_id
      and org_id = p_org_id;
  end if;

  insert into public.audit_logs (
    org_id, user_id, table_name, operation, record_id, new_data
  )
  values (
    p_org_id,
    auth.uid(),
    'anamneses',
    'ANAMNESE_CREATED',
    v_result.id,
    pg_catalog.jsonb_build_object(
      'appointment_id', p_appointment_id,
      'template_id', p_template_id,
      'client_id', v_client_id
    )
  );

  return v_result;
end;
$$;

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

  if p_status = 'Iniciado' then
    perform public.assert_appointment_anamnese_gate(
      p_org_id,
      p_appointment_id,
      'start'
    );
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

revoke all on function public.create_anamnese_atomic(
  uuid, uuid, uuid, text, uuid, boolean
) from public, anon;
grant execute on function public.create_anamnese_atomic(
  uuid, uuid, uuid, text, uuid, boolean
) to authenticated;
