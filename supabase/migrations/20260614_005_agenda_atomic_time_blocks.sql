-- ============================================================
-- KA Beauty OS - Atomic time block create/delete
-- Encoding: UTF-8
-- ============================================================

create or replace function public.create_time_blocks_atomic(
  p_org_id uuid,
  p_staff_id uuid,
  p_reason text,
  p_repeat_rule text,
  p_occurrences jsonb
)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_role text;
  v_occurrence jsonb;
  v_start_at timestamptz;
  v_end_at timestamptz;
  v_first_id uuid;
  v_inserted_id uuid;
  v_count integer;
begin
  v_role := public.auth_user_role(p_org_id);
  if v_role not in ('owner', 'admin', 'manager', 'receptionist', 'professional') then
    raise exception 'Sem permissao para bloquear horarios'
      using errcode = '42501';
  end if;

  if pg_catalog.length(coalesce(p_reason, '')) > 120 then
    raise exception 'Motivo deve ter no maximo 120 caracteres'
      using errcode = '22001';
  end if;

  if pg_catalog.jsonb_typeof(p_occurrences) <> 'array' then
    raise exception 'Ocorrencias invalidas' using errcode = '22023';
  end if;

  v_count := pg_catalog.jsonb_array_length(p_occurrences);
  if v_count < 1 or v_count > 12 then
    raise exception 'Quantidade de ocorrencias invalida'
      using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_org_id::text || ':' || p_staff_id::text, 0)
  );

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

  for v_occurrence in
    select value from pg_catalog.jsonb_array_elements(p_occurrences)
  loop
    v_start_at := (v_occurrence ->> 'start_at')::timestamptz;
    v_end_at := (v_occurrence ->> 'end_at')::timestamptz;

    if v_end_at <= v_start_at then
      raise exception 'Horario final deve ser posterior ao inicial'
        using errcode = '22023';
    end if;

    if exists (
      select 1
      from public.appointments a
      where a.org_id = p_org_id
        and a.staff_id = p_staff_id
        and a.status not in ('Cancelado', 'Ausência')
        and a.start_at < v_end_at
        and a.end_at > v_start_at
    ) then
      raise exception 'Nao e possivel bloquear um horario que ja possui atendimento'
        using errcode = '23P01';
    end if;

    if exists (
      select 1
      from public.time_blocks tb
      where tb.org_id = p_org_id
        and (tb.staff_id = p_staff_id or tb.staff_id is null)
        and tb.start_at < v_end_at
        and tb.end_at > v_start_at
    ) then
      raise exception 'Ja existe um bloqueio neste horario'
        using errcode = '23P01';
    end if;
  end loop;

  for v_occurrence in
    select value from pg_catalog.jsonb_array_elements(p_occurrences)
  loop
    insert into public.time_blocks (
      org_id, staff_id, resource_id, location_id,
      start_at, end_at, reason, repeat_rule, created_by
    )
    values (
      p_org_id,
      p_staff_id,
      null,
      null,
      (v_occurrence ->> 'start_at')::timestamptz,
      (v_occurrence ->> 'end_at')::timestamptz,
      nullif(pg_catalog.btrim(p_reason), ''),
      nullif(pg_catalog.btrim(p_repeat_rule), ''),
      auth.uid()
    )
    returning id into v_inserted_id;

    if v_first_id is null then
      v_first_id := v_inserted_id;
    end if;
  end loop;

  insert into public.audit_logs (
    org_id, user_id, table_name, operation, record_id, new_data
  )
  values (
    p_org_id,
    auth.uid(),
    'time_blocks',
    'TIME_BLOCKS_CREATED',
    v_first_id,
    pg_catalog.jsonb_build_object(
      'staff_id', p_staff_id,
      'count', v_count,
      'repeat_rule', nullif(pg_catalog.btrim(p_repeat_rule), '')
    )
  );

  return v_count;
end;
$$;

create or replace function public.delete_time_block_atomic(
  p_org_id uuid,
  p_time_block_id uuid
)
returns boolean
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_role text;
  v_previous public.time_blocks;
begin
  v_role := public.auth_user_role(p_org_id);
  if v_role not in ('owner', 'admin', 'manager', 'receptionist', 'professional') then
    raise exception 'Sem permissao para remover bloqueios'
      using errcode = '42501';
  end if;

  select *
    into v_previous
  from public.time_blocks tb
  where tb.id = p_time_block_id
    and tb.org_id = p_org_id
  for update;

  if not found then
    raise exception 'Bloqueio nao encontrado' using errcode = 'P0002';
  end if;

  delete from public.time_blocks
  where id = p_time_block_id
    and org_id = p_org_id;

  insert into public.audit_logs (
    org_id, user_id, table_name, operation, record_id, old_data
  )
  values (
    p_org_id,
    auth.uid(),
    'time_blocks',
    'TIME_BLOCK_DELETED',
    p_time_block_id,
    pg_catalog.jsonb_build_object(
      'staff_id', v_previous.staff_id,
      'start_at', v_previous.start_at,
      'end_at', v_previous.end_at,
      'reason', v_previous.reason
    )
  );

  return true;
end;
$$;

revoke all on function public.create_time_blocks_atomic(
  uuid, uuid, text, text, jsonb
) from public, anon;
grant execute on function public.create_time_blocks_atomic(
  uuid, uuid, text, text, jsonb
) to authenticated;

revoke all on function public.delete_time_block_atomic(
  uuid, uuid
) from public, anon;
grant execute on function public.delete_time_block_atomic(
  uuid, uuid
) to authenticated;
