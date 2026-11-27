-- ============================================================
-- KA Beauty OS — Migration 001: Foundation
-- Encoding: UTF-8
-- Rodar em: Supabase → Database → SQL Editor
-- ============================================================

-- ─── Extensões ───────────────────────────────────────────────────────────────
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ─── Organizations ───────────────────────────────────────────────────────────
create table if not exists organizations (
  id          uuid primary key default gen_random_uuid(),
  slug        text unique not null,
  name        text not null,
  logo_url    text,
  phone       text,
  email       text,
  address     text,
  city        text,
  timezone    text not null default 'America/Sao_Paulo',
  currency    text not null default 'BRL',
  locale      text not null default 'pt-BR',
  plan        text not null default 'starter',
  settings    jsonb not null default '{}',
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ─── Locations ───────────────────────────────────────────────────────────────
create table if not exists locations (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references organizations(id) on delete cascade,
  name        text not null,
  address     text,
  city        text,
  phone       text,
  timezone    text not null default 'America/Sao_Paulo',
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

-- ─── Profiles ────────────────────────────────────────────────────────────────
create table if not exists profiles (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  org_id      uuid not null references organizations(id) on delete cascade,
  full_name   text not null default '',
  avatar_url  text,
  phone       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (user_id, org_id)
);

-- ─── User Roles ──────────────────────────────────────────────────────────────
create table if not exists user_roles (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  org_id      uuid not null references organizations(id) on delete cascade,
  role        text not null check (role in ('owner','admin','manager','professional','receptionist','finance','viewer')),
  location_id uuid references locations(id),
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  unique (user_id, org_id)
);

-- ─── Service Categories ──────────────────────────────────────────────────────
create table if not exists service_categories (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references organizations(id) on delete cascade,
  name        text not null,
  color       text not null default '#F43F5E',
  icon        text,
  position    int not null default 0,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

-- ─── Services ────────────────────────────────────────────────────────────────
create table if not exists services (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references organizations(id) on delete cascade,
  category_id         uuid references service_categories(id),
  name                text not null,
  description         text,
  price               numeric(10,2) not null default 0,
  price_type          text not null default 'fixed',
  cost_amount         numeric(10,2) not null default 0,
  duration_minutes    int not null default 60,
  buffer_minutes      int not null default 0,
  requires_anamnese   boolean not null default false,
  anamnese_template_id uuid,
  online_booking      boolean not null default false,
  commission_pct      numeric(5,2) not null default 0,
  position            int not null default 0,
  active              boolean not null default true,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- ─── Clients ─────────────────────────────────────────────────────────────────
create table if not exists clients (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references organizations(id) on delete cascade,
  full_name     text not null,
  phone         text,
  email         text,
  birth_date    date,
  gender        text,
  cpf           text,
  notes         text,
  fixed_notes   text,
  alert_text    text,
  alert_type    text not null default 'none',
  tags          text[] not null default '{}',
  contact_pref  text not null default 'whatsapp',
  status        text not null default 'active',
  balance       numeric(10,2) not null default 0,
  total_spent   numeric(10,2) not null default 0,
  loyalty_points int not null default 0,
  loyalty_tier  text not null default 'bronze',
  last_visit    date,
  source        text,
  location_id   uuid references locations(id),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ─── Staff Members ───────────────────────────────────────────────────────────
create table if not exists staff_members (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references organizations(id) on delete cascade,
  user_id         uuid references auth.users(id),
  location_id     uuid references locations(id),
  name            text not null,
  display_name    text,
  email           text,
  phone           text,
  color           text not null default '#F43F5E',
  avatar_url      text,
  bio             text,
  role            text not null default 'professional',
  commission_pct  numeric(5,2) not null default 0,
  online_booking  boolean not null default true,
  visible         boolean not null default true,
  active          boolean not null default true,
  position        int not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- ─── Staff Shifts ────────────────────────────────────────────────────────────
create table if not exists staff_shifts (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references organizations(id) on delete cascade,
  staff_id    uuid not null references staff_members(id) on delete cascade,
  day_of_week int not null check (day_of_week between 0 and 6),
  start_time  text not null,
  end_time    text not null,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

-- ─── Appointments ────────────────────────────────────────────────────────────
create table if not exists appointments (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references organizations(id) on delete cascade,
  location_id         uuid references locations(id),
  client_id           uuid references clients(id),
  client_name         text not null,
  staff_id            uuid references staff_members(id),
  staff_name          text not null default '',
  resource_id         uuid,
  start_at            timestamptz not null,
  end_at              timestamptz not null,
  duration_minutes    int not null,
  status              text not null default 'Agendado',
  notes               text,
  internal_notes      text,
  color               text,
  source              text not null default 'MANUAL',
  linked_anamnese_id  uuid,
  total               numeric(10,2) not null default 0,
  discount            numeric(10,2) not null default 0,
  tip                 numeric(10,2) not null default 0,
  recurrence_id       uuid,
  recurrence_index    int,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- ─── Appointment Items ───────────────────────────────────────────────────────
create table if not exists appointment_items (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references organizations(id) on delete cascade,
  appointment_id  uuid not null references appointments(id) on delete cascade,
  type            text not null default 'service',
  ref_id          uuid,
  name            text not null,
  price           numeric(10,2) not null default 0,
  cost_amount     numeric(10,2) not null default 0,
  qty             int not null default 1,
  discount        numeric(10,2) not null default 0,
  commission_pct  numeric(5,2) not null default 0,
  professional_id uuid references staff_members(id),
  created_at      timestamptz not null default now()
);

-- ─── Appointment Status History ──────────────────────────────────────────────
create table if not exists appointment_status_history (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references organizations(id) on delete cascade,
  appointment_id  uuid not null references appointments(id) on delete cascade,
  status          text not null,
  changed_by      uuid references auth.users(id),
  notes           text,
  created_at      timestamptz not null default now()
);

-- ─── Índices de performance ──────────────────────────────────────────────────
create index if not exists idx_appointments_org_start    on appointments(org_id, start_at);
create index if not exists idx_appointments_staff        on appointments(staff_id);
create index if not exists idx_appointments_client       on appointments(client_id);
create index if not exists idx_appointment_items_appt    on appointment_items(appointment_id);
create index if not exists idx_clients_org              on clients(org_id);
create index if not exists idx_user_roles_user          on user_roles(user_id);
create index if not exists idx_staff_members_org        on staff_members(org_id);

-- ─── Updated_at trigger ──────────────────────────────────────────────────────
create or replace function update_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace trigger trg_organizations_updated_at
  before update on organizations
  for each row execute function update_updated_at();

create or replace trigger trg_services_updated_at
  before update on services
  for each row execute function update_updated_at();

create or replace trigger trg_clients_updated_at
  before update on clients
  for each row execute function update_updated_at();

create or replace trigger trg_staff_members_updated_at
  before update on staff_members
  for each row execute function update_updated_at();

create or replace trigger trg_appointments_updated_at
  before update on appointments
  for each row execute function update_updated_at();
