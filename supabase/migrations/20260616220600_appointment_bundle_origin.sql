-- CAT-02B: preserve service bundle origin on appointment items.
-- Encoding: UTF-8

alter table public.appointment_items
  add column if not exists bundle_id uuid,
  add column if not exists bundle_item_id uuid,
  add column if not exists bundle_name text,
  add column if not exists bundle_item_position integer,
  add column if not exists bundle_allocated_price numeric(10,2),
  add column if not exists bundle_original_price_snapshot numeric(10,2);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'appointment_items_bundle_org_fkey'
      and conrelid = 'public.appointment_items'::regclass
  ) then
    alter table public.appointment_items
      add constraint appointment_items_bundle_org_fkey
      foreign key (bundle_id, org_id)
      references public.service_bundles(id, org_id)
      on delete restrict;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'appointment_items_bundle_snapshot_check'
      and conrelid = 'public.appointment_items'::regclass
  ) then
    alter table public.appointment_items
      add constraint appointment_items_bundle_snapshot_check
      check (
        (bundle_id is null)
        or (
          bundle_name is not null
          and btrim(bundle_name) <> ''
          and coalesce(bundle_allocated_price, 0) >= 0
          and coalesce(bundle_original_price_snapshot, 0) >= 0
          and coalesce(bundle_item_position, 0) >= 0
        )
      );
  end if;
end $$;

create index if not exists idx_appointment_items_org_bundle
  on public.appointment_items(org_id, bundle_id)
  where bundle_id is not null;

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
  v_bundle_id uuid;
  v_bundle_item_id uuid;
  v_bundle_name text;
  v_bundle_item_position integer;
  v_bundle_allocated_price numeric;
  v_bundle_original_price_snapshot numeric;
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
    v_bundle_id := nullif(v_item ->> 'bundle_id', '')::uuid;
    v_bundle_item_id := nullif(v_item ->> 'bundle_item_id', '')::uuid;
    v_bundle_name := nullif(pg_catalog.btrim(coalesce(v_item ->> 'bundle_name', '')), '');
    v_bundle_item_position := nullif(v_item ->> 'bundle_item_position', '')::integer;
    v_bundle_allocated_price := nullif(v_item ->> 'bundle_allocated_price', '')::numeric;
    v_bundle_original_price_snapshot := nullif(v_item ->> 'bundle_original_price_snapshot', '')::numeric;

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

    if v_bundle_id is not null and not exists (
      select 1 from public.service_bundles b
      where b.id = v_bundle_id and b.org_id = p_org_id
    ) then
      raise exception 'Bundle nao pertence a esta organizacao'
        using errcode = '23503';
    end if;

    insert into public.appointment_items (
      org_id, appointment_id, type, ref_id, name, price,
      cost_amount, qty, discount, commission_pct, professional_id,
      bundle_id, bundle_item_id, bundle_name, bundle_item_position,
      bundle_allocated_price, bundle_original_price_snapshot
    )
    values (
      p_org_id, v_appointment_id, 'service', v_service_id,
      v_item ->> 'service_name', (v_item ->> 'price')::numeric,
      0, 1, 0, 0, v_professional_id,
      v_bundle_id, v_bundle_item_id, v_bundle_name, v_bundle_item_position,
      v_bundle_allocated_price, v_bundle_original_price_snapshot
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

create or replace function public.update_appointment_atomic(
  p_org_id uuid,
  p_appointment_id uuid,
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
  v_previous public.appointments;
  v_updated public.appointments;
  v_client public.clients;
  v_staff_name text := '';
  v_item jsonb;
  v_service_id uuid;
  v_professional_id uuid;
  v_bundle_id uuid;
  v_bundle_item_id uuid;
  v_bundle_name text;
  v_bundle_item_position integer;
  v_bundle_allocated_price numeric;
  v_bundle_original_price_snapshot numeric;
  v_internal_notes text := nullif(pg_catalog.btrim(p_internal_notes), '');
begin
  v_role := public.auth_user_role(p_org_id);
  if v_role not in ('owner', 'admin', 'manager', 'receptionist', 'professional') then
    raise exception 'Sem permissao para atualizar agendamentos'
      using errcode = '42501';
  end if;

  if p_force_override and v_role not in ('owner', 'admin', 'manager') then
    raise exception 'Somente gestores podem forcar conflitos'
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

  if v_previous.status in ('Pago', 'Pago Parcial', 'Cancelado', 'Ausência') then
    raise exception 'Agendamento em estado terminal nao pode ser editado'
      using errcode = 'P0001';
  end if;

  if not public.agenda_status_transition_allowed(v_previous.status, p_status) then
    raise exception 'Transicao de status nao permitida' using errcode = '22023';
  end if;

  if p_duration_minutes < 1 or p_duration_minutes > 1440 then
    raise exception 'Duracao invalida' using errcode = '22023';
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

  if v_client.blocked_at is not null
    and v_client.id <> v_previous.client_id
    and not p_force_override
  then
    raise exception 'Cliente possui bloqueio para novos agendamentos'
      using errcode = 'P0001';
  end if;

  perform public.agenda_assert_slot_available(
    p_org_id,
    p_staff_id,
    p_start_at,
    p_end_at,
    array[p_appointment_id],
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

  update public.appointments
  set
    client_id = p_client_id,
    client_name = v_client.full_name,
    staff_id = p_staff_id,
    staff_name = coalesce(v_staff_name, ''),
    start_at = p_start_at,
    end_at = p_end_at,
    duration_minutes = p_duration_minutes,
    status = p_status,
    notes = nullif(pg_catalog.btrim(p_notes), ''),
    internal_notes = v_internal_notes,
    source = p_source,
    total = pg_catalog.round(p_total, 2)
  where id = p_appointment_id
    and org_id = p_org_id
  returning * into v_updated;

  delete from public.appointment_items ai
  where ai.org_id = p_org_id
    and ai.appointment_id = p_appointment_id;

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
    v_bundle_id := nullif(v_item ->> 'bundle_id', '')::uuid;
    v_bundle_item_id := nullif(v_item ->> 'bundle_item_id', '')::uuid;
    v_bundle_name := nullif(pg_catalog.btrim(coalesce(v_item ->> 'bundle_name', '')), '');
    v_bundle_item_position := nullif(v_item ->> 'bundle_item_position', '')::integer;
    v_bundle_allocated_price := nullif(v_item ->> 'bundle_allocated_price', '')::numeric;
    v_bundle_original_price_snapshot := nullif(v_item ->> 'bundle_original_price_snapshot', '')::numeric;

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

    if v_bundle_id is not null and not exists (
      select 1 from public.service_bundles b
      where b.id = v_bundle_id and b.org_id = p_org_id
    ) then
      raise exception 'Bundle nao pertence a esta organizacao'
        using errcode = '23503';
    end if;

    insert into public.appointment_items (
      org_id, appointment_id, type, ref_id, name, price,
      cost_amount, qty, discount, commission_pct, professional_id,
      bundle_id, bundle_item_id, bundle_name, bundle_item_position,
      bundle_allocated_price, bundle_original_price_snapshot
    )
    values (
      p_org_id, p_appointment_id, 'service', v_service_id,
      v_item ->> 'service_name', (v_item ->> 'price')::numeric,
      0, 1, 0, 0, v_professional_id,
      v_bundle_id, v_bundle_item_id, v_bundle_name, v_bundle_item_position,
      v_bundle_allocated_price, v_bundle_original_price_snapshot
    );
  end loop;

  if v_previous.status <> v_updated.status then
    insert into public.appointment_status_history (
      org_id, appointment_id, status, changed_by, notes
    )
    values (
      p_org_id, p_appointment_id, v_updated.status, auth.uid(), 'appointment_updated'
    );
  end if;

  insert into public.audit_logs (
    org_id, user_id, table_name, operation, record_id, old_data, new_data
  )
  values (
    p_org_id,
    auth.uid(),
    'appointments',
    'APPOINTMENT_UPDATED',
    p_appointment_id,
    pg_catalog.jsonb_build_object(
      'client_id', v_previous.client_id,
      'staff_id', v_previous.staff_id,
      'start_at', v_previous.start_at,
      'end_at', v_previous.end_at,
      'status', v_previous.status
    ),
    pg_catalog.jsonb_build_object(
      'client_id', v_updated.client_id,
      'staff_id', v_updated.staff_id,
      'start_at', v_updated.start_at,
      'end_at', v_updated.end_at,
      'status', v_updated.status,
      'item_count', pg_catalog.jsonb_array_length(coalesce(p_items, '[]'::jsonb)),
      'force_override', p_force_override
    )
  );

  return p_appointment_id;
end;
$$;

revoke all on function public.create_appointment_atomic(
  uuid, uuid, uuid, timestamptz, timestamptz, integer, text,
  text, text, text, numeric, jsonb, boolean
) from public, anon;
grant execute on function public.create_appointment_atomic(
  uuid, uuid, uuid, timestamptz, timestamptz, integer, text,
  text, text, text, numeric, jsonb, boolean
) to authenticated;

revoke all on function public.update_appointment_atomic(
  uuid, uuid, uuid, uuid, timestamptz, timestamptz, integer,
  text, text, text, text, numeric, jsonb, boolean
) from public, anon;
grant execute on function public.update_appointment_atomic(
  uuid, uuid, uuid, uuid, timestamptz, timestamptz, integer,
  text, text, text, text, numeric, jsonb, boolean
) to authenticated;
