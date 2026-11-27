-- ============================================================
-- KA Beauty OS - Client entitlements (pacotes comprados)
-- Encoding: UTF-8
-- ============================================================

create table if not exists public.client_entitlements (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references public.organizations(id) on delete cascade,
  client_id        uuid not null references public.clients(id) on delete cascade,
  package_id       uuid references public.service_packages(id) on delete set null,
  package_name     text not null,
  sale_id          uuid references public.sales(id) on delete set null,
  status           text not null default 'active'
                     check (status in ('active', 'exhausted', 'expired', 'cancelled')),
  total_sessions   integer not null check (total_sessions > 0),
  used_sessions    integer not null default 0 check (used_sessions >= 0),
  covered_services jsonb not null default '[]'::jsonb,
  purchased_at     timestamptz not null default now(),
  expires_at       timestamptz,
  notes            text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create table if not exists public.client_entitlement_entries (
  id               uuid primary key default gen_random_uuid(),
  org_id           uuid not null references public.organizations(id) on delete cascade,
  entitlement_id   uuid not null references public.client_entitlements(id) on delete cascade,
  client_id        uuid not null references public.clients(id) on delete cascade,
  appointment_id   uuid references public.appointments(id) on delete set null,
  service_name     text,
  action           text not null check (action in ('consume', 'restore', 'adjust')),
  sessions_delta   integer not null check (sessions_delta <> 0),
  sessions_before  integer not null,
  sessions_after   integer not null,
  description      text,
  created_by       uuid references auth.users(id) on delete set null,
  created_at       timestamptz not null default now()
);

-- Trigger to keep updated_at fresh
create trigger entitlements_updated_at
  before update on public.client_entitlements
  for each row execute function public.update_updated_at();

-- Indexes
create index if not exists idx_client_entitlements_client
  on public.client_entitlements (org_id, client_id, status, expires_at);
create index if not exists idx_client_entitlement_entries_entitlement
  on public.client_entitlement_entries (entitlement_id, created_at desc);

-- RLS
alter table public.client_entitlements enable row level security;
alter table public.client_entitlement_entries enable row level security;

drop policy if exists "entitlements_select" on public.client_entitlements;
drop policy if exists "entitlements_insert" on public.client_entitlements;
drop policy if exists "entitlements_update" on public.client_entitlements;

create policy "entitlements_select"
  on public.client_entitlements for select
  using (org_id in (select public.auth_org_ids()));

create policy "entitlements_insert"
  on public.client_entitlements for insert
  with check (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in (
      'owner', 'admin', 'manager', 'finance', 'receptionist'
    )
  );

create policy "entitlements_update"
  on public.client_entitlements for update
  using (org_id in (select public.auth_org_ids()))
  with check (
    public.auth_user_role(org_id) in (
      'owner', 'admin', 'manager', 'finance', 'receptionist', 'professional'
    )
  );

drop policy if exists "entitlement_entries_select" on public.client_entitlement_entries;
drop policy if exists "entitlement_entries_insert" on public.client_entitlement_entries;

create policy "entitlement_entries_select"
  on public.client_entitlement_entries for select
  using (org_id in (select public.auth_org_ids()));

create policy "entitlement_entries_insert"
  on public.client_entitlement_entries for insert
  with check (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in (
      'owner', 'admin', 'manager', 'finance', 'receptionist', 'professional'
    )
  );

grant select, insert, update on public.client_entitlements to authenticated;
grant select, insert on public.client_entitlement_entries to authenticated;
