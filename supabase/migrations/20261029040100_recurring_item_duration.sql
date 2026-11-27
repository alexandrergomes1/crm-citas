-- AGD-ITEM-EDIT-01 (spec 35), parte 2: recorrência grava a duração de cada item.
-- Encoding: UTF-8. Depende de 20261029040000 (coluna appointment_items.duration_minutes).
-- Definição de produção (md5 conferido) com só: declarar v_item_duration, validar 5..720 e gravar.
set client_encoding = 'UTF8';

CREATE OR REPLACE FUNCTION public.create_recurring_appointments_atomic(p_org_id uuid, p_client_id uuid, p_staff_id uuid, p_staff_name text, p_status text, p_source text, p_notes text, p_internal_notes text, p_duration_minutes integer, p_total numeric, p_occurrences jsonb, p_items jsonb, p_force_override boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_role text;
  v_client public.clients;
  v_occurrence jsonb;
  v_item jsonb;
  v_item_duration integer;
  v_start timestamptz;
  v_end timestamptz;
  v_index integer;
  v_count integer;
  v_recurrence_id uuid := gen_random_uuid();
  v_appointment_id uuid;
  v_first_appointment_id uuid;
  v_internal_notes text := p_internal_notes;
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
    raise exception 'Duracao invalida'
      using errcode = '22023';
  end if;

  if pg_catalog.jsonb_typeof(p_occurrences) <> 'array' then
    raise exception 'Ocorrencias invalidas'
      using errcode = '22023';
  end if;

  v_count := pg_catalog.jsonb_array_length(p_occurrences);
  if v_count < 2 or v_count > 52 then
    raise exception 'Quantidade de ocorrencias invalida'
      using errcode = '22023';
  end if;

  if pg_catalog.jsonb_typeof(coalesce(p_items, '[]'::jsonb)) <> 'array' then
    raise exception 'Itens invalidos'
      using errcode = '22023';
  end if;

  select *
    into v_client
  from public.clients
  where id = p_client_id
    and org_id = p_org_id
  for share;

  if not found then
    raise exception 'Cliente nao encontrado'
      using errcode = 'P0002';
  end if;

  if v_client.blocked_at is not null and not p_force_override then
    raise exception 'Cliente possui bloqueio para novos agendamentos'
      using errcode = 'P0001';
  end if;

  if p_staff_id is not null then
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(p_org_id::text || ':' || p_staff_id::text, 0)
    );
  end if;

  for v_occurrence in
    select value from pg_catalog.jsonb_array_elements(p_occurrences)
  loop
    v_start := (v_occurrence ->> 'start_at')::timestamptz;
    v_end := (v_occurrence ->> 'end_at')::timestamptz;
    v_index := (v_occurrence ->> 'index')::integer;

    if v_end <= v_start then
      raise exception 'Horario final deve ser posterior ao inicial'
        using errcode = '22023';
    end if;

    if p_staff_id is not null and not p_force_override then
      if exists (
        select 1
        from public.appointments a
        where a.org_id = p_org_id
          and a.staff_id = p_staff_id
          and a.status not in ('Cancelado', 'Ausência')
          and a.start_at < v_end
          and a.end_at > v_start
      ) then
        raise exception 'O profissional ja possui um atendimento em uma das ocorrencias'
          using errcode = '23P01';
      end if;

      if exists (
        select 1
        from public.time_blocks tb
        where tb.org_id = p_org_id
          and (tb.staff_id = p_staff_id or tb.staff_id is null)
          and tb.start_at < v_end
          and tb.end_at > v_start
      ) then
        raise exception 'O profissional possui um bloqueio em uma das ocorrencias'
          using errcode = '23P01';
      end if;
    end if;
  end loop;

  if p_force_override then
    v_internal_notes := pg_catalog.concat_ws(
      E'\n',
      pg_catalog.format(
        '[CONFLITO FORCADO - %s - %s]',
        v_role,
        pg_catalog.to_char(pg_catalog.now(), 'YYYY-MM-DD HH24:MI')
      ),
      nullif(p_internal_notes, '')
    );
  end if;

  for v_occurrence in
    select value
    from pg_catalog.jsonb_array_elements(p_occurrences)
    order by (value ->> 'index')::integer
  loop
    v_start := (v_occurrence ->> 'start_at')::timestamptz;
    v_end := (v_occurrence ->> 'end_at')::timestamptz;
    v_index := (v_occurrence ->> 'index')::integer;

    insert into public.appointments (
      org_id,
      client_id,
      client_name,
      staff_id,
      staff_name,
      start_at,
      end_at,
      duration_minutes,
      status,
      notes,
      internal_notes,
      source,
      total,
      discount,
      tip,
      recurrence_id,
      recurrence_index
    )
    values (
      p_org_id,
      p_client_id,
      v_client.full_name,
      p_staff_id,
      coalesce(p_staff_name, ''),
      v_start,
      v_end,
      p_duration_minutes,
      p_status,
      p_notes,
      v_internal_notes,
      p_source,
      p_total,
      0,
      0,
      v_recurrence_id,
      v_index
    )
    returning id into v_appointment_id;

    if v_first_appointment_id is null then
      v_first_appointment_id := v_appointment_id;
    end if;

    for v_item in
      select value from pg_catalog.jsonb_array_elements(coalesce(p_items, '[]'::jsonb))
    loop
      if nullif(pg_catalog.btrim(v_item ->> 'service_name'), '') is null then
        raise exception 'Servico invalido'
          using errcode = '22023';
      end if;

      v_item_duration := nullif(v_item ->> 'duration_minutes', '')::integer;
      if v_item_duration is not null and (v_item_duration < 5 or v_item_duration > 720) then
        raise exception 'Duracao do item invalida' using errcode = '22023';
      end if;

      insert into public.appointment_items (
        org_id,
        appointment_id,
        type,
        ref_id,
        name,
        price,
        cost_amount,
        qty,
        discount,
        commission_pct,
        professional_id,
        duration_minutes
      )
      values (
        p_org_id,
        v_appointment_id,
        'service',
        nullif(v_item ->> 'service_id', '')::uuid,
        v_item ->> 'service_name',
        (v_item ->> 'price')::numeric,
        0,
        1,
        0,
        0,
        coalesce(
          nullif(v_item ->> 'professional_id', '')::uuid,
          p_staff_id
        ),
        v_item_duration
      );
    end loop;

    insert into public.appointment_status_history (
      org_id,
      appointment_id,
      status,
      changed_by,
      notes
    )
    values (
      p_org_id,
      v_appointment_id,
      p_status,
      auth.uid(),
      'recurrence_created'
    );
  end loop;

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
    'appointments',
    'RECURRENCE_CREATED',
    v_recurrence_id,
    pg_catalog.jsonb_build_object(
      'recurrence_id', v_recurrence_id,
      'client_id', p_client_id,
      'staff_id', p_staff_id,
      'count', v_count,
      'force_override', p_force_override
    )
  );

  return pg_catalog.jsonb_build_object(
    'first_appointment_id', v_first_appointment_id,
    'recurrence_id', v_recurrence_id,
    'count', v_count
  );
end;
$function$;
