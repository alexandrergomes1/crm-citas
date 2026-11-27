-- ============================================================
-- KA Beauty OS - Agenda: bloqueios de horario
-- Encoding: UTF-8
-- ============================================================

create table if not exists public.time_blocks (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references public.organizations(id) on delete cascade,
  staff_id    uuid references public.staff_members(id) on delete cascade,
  resource_id uuid,
  location_id uuid references public.locations(id) on delete set null,
  start_at    timestamptz not null,
  end_at      timestamptz not null,
  reason      text,
  repeat_rule text,
  created_by  uuid references auth.users(id) on delete set null,
  created_at  timestamptz not null default now(),
  constraint time_blocks_valid_range check (end_at > start_at)
);

comment on table public.time_blocks is
  'Bloqueios de horario e indisponibilidades da agenda';

create index if not exists idx_time_blocks_org_period
  on public.time_blocks (org_id, start_at, end_at);

create index if not exists idx_time_blocks_staff_start
  on public.time_blocks (staff_id, start_at);

alter table public.time_blocks enable row level security;

drop policy if exists "time_blocks_select" on public.time_blocks;
create policy "time_blocks_select"
  on public.time_blocks
  for select
  using (org_id in (select public.auth_org_ids()));

drop policy if exists "time_blocks_write" on public.time_blocks;
create policy "time_blocks_write"
  on public.time_blocks
  for all
  using (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in (
      'owner',
      'admin',
      'manager',
      'receptionist',
      'professional'
    )
  )
  with check (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in (
      'owner',
      'admin',
      'manager',
      'receptionist',
      'professional'
    )
  );

grant select, insert, update, delete on public.time_blocks to authenticated;
