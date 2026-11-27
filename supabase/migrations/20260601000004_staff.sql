-- ============================================================
-- KA Beauty OS — Migration 004: Equipe / Staff
-- Encoding: UTF-8
-- ============================================================

-- ─── Staff Members ───────────────────────────────────────────
create table staff_members (
  id               uuid        primary key default gen_random_uuid(),
  org_id           uuid        not null references organizations on delete cascade,
  user_id          uuid        references auth.users,           -- link ao auth (opcional)
  location_id      uuid        references locations,
  name             text        not null,
  display_name     text,
  email            text,
  phone            text,
  color            text        not null default '#F43F5E',       -- cor na agenda
  avatar_url       text,
  bio              text,
  role             text        not null default 'professional',  -- professional | manager | receptionist
  commission_pct   numeric(5,2) not null default 0,
  online_booking   boolean     not null default true,
  visible          boolean     not null default true,
  active           boolean     not null default true,
  position         int         not null default 0,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
comment on table staff_members is 'Profissionais e equipe da clínica';

-- ─── Staff ↔ Services ────────────────────────────────────────
create table staff_services (
  id          uuid primary key default gen_random_uuid(),
  staff_id    uuid not null references staff_members on delete cascade,
  service_id  uuid not null references services on delete cascade,
  unique(staff_id, service_id)
);

-- ─── Working Schedules ───────────────────────────────────────
create table staff_shifts (
  id             uuid        primary key default gen_random_uuid(),
  org_id         uuid        not null references organizations on delete cascade,
  staff_id       uuid        not null references staff_members on delete cascade,
  day_of_week    int         not null check (day_of_week between 0 and 6), -- 0=Dom..6=Sáb
  start_time     time        not null,
  end_time       time        not null,
  lunch_start    time,
  lunch_end      time,
  active         boolean     not null default true,
  created_at     timestamptz not null default now()
);
comment on table staff_shifts is 'Horários de trabalho por dia da semana';

-- ─── Índices ─────────────────────────────────────────────────
create index on staff_members (org_id, active);
create index on staff_members (org_id, visible);
create index on staff_services (staff_id);
create index on staff_services (service_id);
create index on staff_shifts (staff_id);
create index on staff_shifts (org_id);

-- ─── RLS ─────────────────────────────────────────────────────
alter table staff_members  enable row level security;
alter table staff_services enable row level security;
alter table staff_shifts   enable row level security;

create policy "staff_select" on staff_members
  for select using (org_id in (select auth_org_ids()));

create policy "staff_write" on staff_members
  for all using (auth_user_role(org_id) in ('owner','admin','manager'));

create policy "staff_services_select" on staff_services
  for select using (
    exists (select 1 from staff_members s where s.id = staff_id and s.org_id in (select auth_org_ids()))
  );

create policy "staff_services_write" on staff_services
  for all using (
    exists (
      select 1 from staff_members s
      where s.id = staff_id
        and auth_user_role(s.org_id) in ('owner','admin','manager')
    )
  );

create policy "staff_shifts_select" on staff_shifts
  for select using (org_id in (select auth_org_ids()));

create policy "staff_shifts_write" on staff_shifts
  for all using (auth_user_role(org_id) in ('owner','admin','manager'));

-- ─── Updated_at ──────────────────────────────────────────────
create trigger trg_staff_updated_at before update on staff_members for each row execute function set_updated_at();
