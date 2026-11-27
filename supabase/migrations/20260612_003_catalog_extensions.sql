-- Migration: service_staff + subscription_plans
-- 2026-06-12  Encoding: UTF-8

-- ─── service_staff ─────────────────────────────────────────────────────────────
-- Defines which staff members are allowed to perform each service.
-- Empty = all staff can perform the service.

create table if not exists public.service_staff (
  service_id  uuid not null references public.services(id)       on delete cascade,
  staff_id    uuid not null references public.staff_members(id)  on delete cascade,
  org_id      uuid not null references public.organizations(id)  on delete cascade,
  primary key (service_id, staff_id)
);

alter table public.service_staff enable row level security;

drop policy if exists "service_staff_select" on public.service_staff;
drop policy if exists "service_staff_insert" on public.service_staff;
drop policy if exists "service_staff_delete" on public.service_staff;

create policy "service_staff_select" on public.service_staff
  for select using (org_id in (select public.auth_org_ids()));

create policy "service_staff_insert" on public.service_staff
  for insert with check (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in ('owner', 'admin', 'manager')
  );

create policy "service_staff_delete" on public.service_staff
  for delete using (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in ('owner', 'admin', 'manager')
  );

create index if not exists service_staff_service_idx on public.service_staff(service_id);
create index if not exists service_staff_staff_idx   on public.service_staff(staff_id);
create index if not exists service_staff_org_idx     on public.service_staff(org_id);

grant select, insert, delete on public.service_staff to authenticated;

-- ─── subscription_plans ────────────────────────────────────────────────────────
-- Monthly/periodic membership plans. Clients pay a recurring fee and get
-- sessions per period for eligible services. Distinct from service_packages.

create table if not exists public.subscription_plans (
  id                  uuid        primary key default gen_random_uuid(),
  org_id              uuid        not null references public.organizations(id) on delete cascade,
  name                text        not null,
  description         text,
  price               numeric(10,2) not null default 0,
  billing_period      text        not null default 'monthly',
  sessions_per_period int         not null default 1,
  eligible_services   jsonb       not null default '[]',
  highlight_color     text,
  online_booking      boolean     not null default false,
  active              boolean     not null default true,
  position            int         not null default 0,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

alter table public.subscription_plans enable row level security;

drop policy if exists "subscription_plans_select" on public.subscription_plans;
drop policy if exists "subscription_plans_insert" on public.subscription_plans;
drop policy if exists "subscription_plans_update" on public.subscription_plans;
drop policy if exists "subscription_plans_delete" on public.subscription_plans;

create policy "subscription_plans_select" on public.subscription_plans
  for select using (org_id in (select public.auth_org_ids()));

create policy "subscription_plans_insert" on public.subscription_plans
  for insert with check (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in ('owner', 'admin', 'manager')
  );

create policy "subscription_plans_update" on public.subscription_plans
  for update using (org_id in (select public.auth_org_ids()))
  with check (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));

create policy "subscription_plans_delete" on public.subscription_plans
  for delete using (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in ('owner', 'admin', 'manager')
  );

create index if not exists subscription_plans_org_idx on public.subscription_plans(org_id, active, position);

grant select, insert, update, delete on public.subscription_plans to authenticated;

create trigger subscription_plans_updated_at
  before update on public.subscription_plans
  for each row execute function public.update_updated_at();
