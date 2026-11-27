-- ============================================================
-- KA Beauty OS - Atomic recurrence updates
-- Encoding: UTF-8
-- ============================================================

create or replace function public.update_recurrence_series_atomic(
  p_org_id uuid,
  p_recurrence_id uuid,
  p_staff_id uuid,
  p_duration_minutes integer,
  p_notes text,
  p_updates jsonb,
  p_force_override boolean default false
)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_role text;
  v_update jsonb;
  v_id uuid;
  v_start timestamptz;
  v_end timestamptz;
  v_expected integer;
  v_actual integer;
  v_updated integer := 0;
begin
  v_role := public.auth_user_role(p_org_id);
  if v_role not in ('owner', 'admin', 'manager', 'receptionist', 'professional') then
    raise exception 'Sem permissao para editar agendamentos'
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

  if pg_catalog.jsonb_typeof(p_updates) <> 'array' then
    raise exception 'Atualizacoes invalidas'
      using errcode = '22023';
  end if;

  v_expected := pg_catalog.jsonb_array_length(p_updates);
  if v_expected < 1 or v_expected > 52 then
    raise exception 'Quantidade de atualizacoes invalida'
      using errcode = '22023';
  end if;

  if p_staff_id is not null then
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(p_org_id::text || ':' || p_staff_id::text, 0)
    );
  end if;

  perform 1
  from public.appointments a
  where a.org_id = p_org_id
    and a.recurrence_id = p_recurrence_id
    and a.id in (
      select (value ->> 'id')::uuid
      from pg_catalog.jsonb_array_elements(p_updates)
    )
  for update;

  select pg_catalog.count(*)
    into v_actual
  from public.appointments a
  where a.org_id = p_org_id
    and a.recurrence_id = p_recurrence_id
    and a.status not in ('Cancelado', 'Pago', 'Pago Parcial')
    and a.id in (
      select (value ->> 'id')::uuid
      from pg_catalog.jsonb_array_elements(p_updates)
    );

  if v_actual <> v_expected then
    raise exception 'A serie mudou durante a edicao; atualize a agenda'
      using errcode = '40001';
  end if;

  for v_update in
    select value from pg_catalog.jsonb_array_elements(p_updates)
  loop
    v_id := (v_update ->> 'id')::uuid;
    v_start := (v_update ->> 'start_at')::timestamptz;
    v_end := (v_update ->> 'end_at')::timestamptz;

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
          and a.id not in (
            select (value ->> 'id')::uuid
            from pg_catalog.jsonb_array_elements(p_updates)
          )
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

  for v_update in
    select value from pg_catalog.jsonb_array_elements(p_updates)
  loop
    v_id := (v_update ->> 'id')::uuid;
    v_start := (v_update ->> 'start_at')::timestamptz;
    v_end := (v_update ->> 'end_at')::timestamptz;

    update public.appointments
    set
      staff_id = p_staff_id,
      start_at = v_start,
      end_at = v_end,
      duration_minutes = p_duration_minutes,
      notes = p_notes,
      internal_notes = pg_catalog.concat_ws(
        E'\n',
        nullif(internal_notes, ''),
        pg_catalog.format(
          '[SERIE EDITADA - %s - %s]',
          v_role,
          pg_catalog.to_char(pg_catalog.now(), 'YYYY-MM-DD HH24:MI')
        )
      )
    where id = v_id
      and org_id = p_org_id
      and recurrence_id = p_recurrence_id;

    v_updated := v_updated + 1;
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
    'RECURRENCE_UPDATED',
    p_recurrence_id,
    pg_catalog.jsonb_build_object(
      'recurrence_id', p_recurrence_id,
      'staff_id', p_staff_id,
      'count', v_updated,
      'force_override', p_force_override
    )
  );

  return v_updated;
end;
$$;

revoke all on function public.update_recurrence_series_atomic(
  uuid, uuid, uuid, integer, text, jsonb, boolean
) from public;
revoke all on function public.update_recurrence_series_atomic(
  uuid, uuid, uuid, integer, text, jsonb, boolean
) from anon;
grant execute on function public.update_recurrence_series_atomic(
  uuid, uuid, uuid, integer, text, jsonb, boolean
) to authenticated;
