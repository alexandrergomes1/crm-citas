-- ============================================================
-- KA Beauty OS - Agenda: tipos, recorrência e filtros de bloqueio
-- Encoding: UTF-8
-- ============================================================

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.set_agenda_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := pg_catalog.now();
  return new;
end;
$$;

revoke all on function private.set_agenda_updated_at()
  from public, anon, authenticated;

create table public.time_block_types (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  color text not null default '#64748B',
  is_paid boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint time_block_types_name_length check (
    char_length(btrim(name)) between 1 and 80
  ),
  constraint time_block_types_color_format check (
    color ~ '^#[0-9A-Fa-f]{6}$'
  ),
  constraint time_block_types_org_name_unique unique (org_id, name),
  constraint time_block_types_org_id_unique unique (org_id, id)
);

comment on table public.time_block_types is
  'Tipos de indisponibilidade configuráveis por organização';

create index time_block_types_org_active_name_idx
  on public.time_block_types (org_id, active, name);

create trigger trg_time_block_types_updated_at
  before update on public.time_block_types
  for each row execute function private.set_agenda_updated_at();

alter table public.time_block_types enable row level security;

create policy "time_block_types_select"
  on public.time_block_types for select
  to authenticated
  using (org_id in (select public.auth_org_ids()));

create policy "time_block_types_insert"
  on public.time_block_types for insert
  to authenticated
  with check (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in ('owner', 'admin', 'manager')
  );

create policy "time_block_types_update"
  on public.time_block_types for update
  to authenticated
  using (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in ('owner', 'admin', 'manager')
  )
  with check (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in ('owner', 'admin', 'manager')
  );

create policy "time_block_types_delete"
  on public.time_block_types for delete
  to authenticated
  using (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in ('owner', 'admin', 'manager')
  );

grant select, insert, update, delete on public.time_block_types to authenticated;

create or replace function private.seed_default_time_block_types_for_org()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.time_block_types (org_id, name, color, is_paid)
  values
    (new.id, 'Indisponível', '#64748B', false),
    (new.id, 'Reunião', '#2563EB', false),
    (new.id, 'Almoço', '#F59E0B', false),
    (new.id, 'Pausa', '#8B5CF6', false),
    (new.id, 'Formação', '#16A34A', true),
    (new.id, 'Outro', '#6B7280', false)
  on conflict (org_id, name) do nothing;
  return new;
end;
$$;

revoke all on function private.seed_default_time_block_types_for_org()
  from public, anon, authenticated;

create trigger trg_organizations_default_time_block_types
  after insert on public.organizations
  for each row execute function private.seed_default_time_block_types_for_org();

insert into public.time_block_types (org_id, name, color, is_paid)
select organization.id, default_type.name, default_type.color, default_type.is_paid
from public.organizations organization
cross join (
  values
    ('Indisponível', '#64748B', false),
    ('Reunião', '#2563EB', false),
    ('Almoço', '#F59E0B', false),
    ('Pausa', '#8B5CF6', false),
    ('Formação', '#16A34A', true),
    ('Outro', '#6B7280', false)
) as default_type(name, color, is_paid)
on conflict (org_id, name) do nothing;

alter table public.time_blocks
  add column time_block_type_id uuid,
  add column title text,
  add column notes text,
  add column allow_online_booking boolean not null default false,
  add column recurrence_frequency text not null default 'none',
  add column recurrence_count smallint not null default 1,
  add column recurrence_series_id uuid,
  add column updated_at timestamptz not null default now(),
  add constraint time_blocks_title_length check (
    title is null or char_length(title) <= 120
  ),
  add constraint time_blocks_notes_length check (
    notes is null or char_length(notes) <= 255
  ),
  add constraint time_blocks_recurrence_frequency_check check (
    recurrence_frequency in ('none', 'daily', 'weekly', 'monthly')
  ),
  add constraint time_blocks_recurrence_count_check check (
    recurrence_count between 1 and 60
  );

update public.time_blocks block
set
  time_block_type_id = block_type.id,
  title = nullif(btrim(block.reason), ''),
  recurrence_frequency = case
    when block.repeat_rule like 'FREQ=WEEKLY%' then 'weekly'
    else 'none'
  end,
  recurrence_count = case
    when substring(block.repeat_rule from 'COUNT=([0-9]+)') is not null
      then least(60, substring(block.repeat_rule from 'COUNT=([0-9]+)')::smallint)
    else 1
  end
from public.time_block_types block_type
where block_type.org_id = block.org_id
  and block_type.name = 'Indisponível';

alter table public.time_blocks
  alter column time_block_type_id set not null,
  add constraint time_blocks_org_type_fkey
    foreign key (org_id, time_block_type_id)
    references public.time_block_types(org_id, id) on delete restrict;

create index time_blocks_org_type_period_idx
  on public.time_blocks (org_id, time_block_type_id, start_at);

create index time_blocks_recurrence_series_idx
  on public.time_blocks (recurrence_series_id)
  where recurrence_series_id is not null;

create trigger trg_time_blocks_updated_at
  before update on public.time_blocks
  for each row execute function private.set_agenda_updated_at();

drop policy if exists "time_blocks_select" on public.time_blocks;
create policy "time_blocks_select"
  on public.time_blocks for select
  to authenticated
  using (org_id in (select public.auth_org_ids()));

drop policy if exists "time_blocks_write" on public.time_blocks;
create policy "time_blocks_insert"
  on public.time_blocks for insert
  to authenticated
  with check (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in (
      'owner', 'admin', 'manager', 'receptionist', 'professional'
    )
  );

create policy "time_blocks_update"
  on public.time_blocks for update
  to authenticated
  using (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in (
      'owner', 'admin', 'manager', 'receptionist', 'professional'
    )
  )
  with check (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in (
      'owner', 'admin', 'manager', 'receptionist', 'professional'
    )
  );

create policy "time_blocks_delete"
  on public.time_blocks for delete
  to authenticated
  using (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in (
      'owner', 'admin', 'manager', 'receptionist', 'professional'
    )
  );

drop function public.create_time_blocks_atomic(uuid, uuid, text, text, jsonb);

create function public.create_time_blocks_atomic(
  p_org_id uuid,
  p_staff_id uuid,
  p_time_block_type_id uuid,
  p_title text,
  p_notes text,
  p_allow_online_booking boolean,
  p_recurrence_frequency text,
  p_recurrence_count integer,
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
  v_series_id uuid;
  v_type_name text;
  v_count integer;
  v_repeat_rule text;
begin
  v_role := public.auth_user_role(p_org_id);
  if v_role not in ('owner', 'admin', 'manager', 'receptionist', 'professional') then
    raise exception 'Sem permissao para bloquear horarios' using errcode = '42501';
  end if;

  if pg_catalog.char_length(coalesce(p_title, '')) > 120 then
    raise exception 'Titulo deve ter no maximo 120 caracteres' using errcode = '22001';
  end if;
  if pg_catalog.char_length(coalesce(p_notes, '')) > 255 then
    raise exception 'Descricao deve ter no maximo 255 caracteres' using errcode = '22001';
  end if;
  if p_recurrence_frequency not in ('none', 'daily', 'weekly', 'monthly') then
    raise exception 'Frequencia de recorrencia invalida' using errcode = '22023';
  end if;
  if pg_catalog.jsonb_typeof(p_occurrences) <> 'array' then
    raise exception 'Ocorrencias invalidas' using errcode = '22023';
  end if;

  v_count := pg_catalog.jsonb_array_length(p_occurrences);
  if v_count < 1 or v_count > 60 or v_count <> p_recurrence_count then
    raise exception 'Quantidade de ocorrencias invalida' using errcode = '22023';
  end if;
  if (p_recurrence_frequency = 'none' and v_count <> 1)
    or (p_recurrence_frequency <> 'none' and v_count < 2) then
    raise exception 'Recorrencia e quantidade de ocorrencias incompativeis'
      using errcode = '22023';
  end if;

  select block_type.name
    into v_type_name
  from public.time_block_types block_type
  where block_type.id = p_time_block_type_id
    and block_type.org_id = p_org_id
    and block_type.active = true;
  if not found then
    raise exception 'Tipo de bloqueio nao encontrado nesta organizacao'
      using errcode = 'P0002';
  end if;

  if not exists (
    select 1 from public.staff_members staff
    where staff.id = p_staff_id and staff.org_id = p_org_id and staff.active = true
  ) then
    raise exception 'Profissional nao encontrado nesta organizacao'
      using errcode = 'P0002';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_org_id::text || ':' || p_staff_id::text, 0)
  );

  for v_occurrence in select value from pg_catalog.jsonb_array_elements(p_occurrences)
  loop
    v_start_at := (v_occurrence ->> 'start_at')::timestamptz;
    v_end_at := (v_occurrence ->> 'end_at')::timestamptz;
    if v_end_at <= v_start_at then
      raise exception 'Horario final deve ser posterior ao inicial' using errcode = '22023';
    end if;
    if exists (
      select 1 from public.appointments appointment
      where appointment.org_id = p_org_id
        and appointment.staff_id = p_staff_id
        and appointment.status not in ('Cancelado', 'Ausência')
        and appointment.start_at < v_end_at and appointment.end_at > v_start_at
    ) then
      raise exception 'Nao e possivel bloquear um horario que ja possui atendimento'
        using errcode = '23P01';
    end if;
    if exists (
      select 1 from public.time_blocks block
      where block.org_id = p_org_id
        and (block.staff_id = p_staff_id or block.staff_id is null)
        and block.start_at < v_end_at and block.end_at > v_start_at
    ) then
      raise exception 'Ja existe um bloqueio neste horario' using errcode = '23P01';
    end if;
  end loop;

  v_series_id := case when v_count > 1 then pg_catalog.gen_random_uuid() else null end;
  v_repeat_rule := case when p_recurrence_frequency = 'none' then null else
    'FREQ=' || pg_catalog.upper(p_recurrence_frequency) || ';COUNT=' || v_count::text end;

  for v_occurrence in select value from pg_catalog.jsonb_array_elements(p_occurrences)
  loop
    insert into public.time_blocks (
      org_id, staff_id, start_at, end_at, reason, repeat_rule, created_by,
      time_block_type_id, title, notes, allow_online_booking,
      recurrence_frequency, recurrence_count, recurrence_series_id
    ) values (
      p_org_id, p_staff_id,
      (v_occurrence ->> 'start_at')::timestamptz,
      (v_occurrence ->> 'end_at')::timestamptz,
      coalesce(nullif(pg_catalog.btrim(p_title), ''), v_type_name),
      v_repeat_rule, auth.uid(), p_time_block_type_id,
      nullif(pg_catalog.btrim(p_title), ''),
      nullif(pg_catalog.btrim(p_notes), ''),
      p_allow_online_booking, p_recurrence_frequency, v_count, v_series_id
    ) returning id into v_inserted_id;
    v_first_id := coalesce(v_first_id, v_inserted_id);
  end loop;

  insert into public.audit_logs (
    org_id, user_id, table_name, operation, record_id, new_data
  ) values (
    p_org_id, auth.uid(), 'time_blocks', 'TIME_BLOCKS_CREATED', v_first_id,
    pg_catalog.jsonb_build_object(
      'staff_id', p_staff_id,
      'time_block_type_id', p_time_block_type_id,
      'recurrence_frequency', p_recurrence_frequency,
      'count', v_count,
      'allow_online_booking', p_allow_online_booking
    )
  );
  return v_count;
end;
$$;

revoke all on function public.create_time_blocks_atomic(
  uuid, uuid, uuid, text, text, boolean, text, integer, jsonb
) from public, anon;
grant execute on function public.create_time_blocks_atomic(
  uuid, uuid, uuid, text, text, boolean, text, integer, jsonb
) to authenticated;
