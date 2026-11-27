-- ============================================================
-- KA Beauty OS — Migration 001: Fundação Multi-Tenant
-- Encoding: UTF-8
-- ============================================================

-- ─── Extensions ──────────────────────────────────────────────
create extension if not exists "pgcrypto";

-- ─── Tipos ───────────────────────────────────────────────────
create type user_role as enum (
  'owner',
  'admin',
  'manager',
  'professional',
  'receptionist',
  'finance',
  'viewer'
);

-- ─── Organizations ───────────────────────────────────────────
create table organizations (
  id           uuid        primary key default gen_random_uuid(),
  slug         text        unique not null,
  name         text        not null,
  logo_url     text,
  phone        text,
  email        text,
  address      text,
  city         text,
  timezone     text        not null default 'America/Sao_Paulo',
  currency     text        not null default 'BRL',
  locale       text        not null default 'pt-BR',
  plan         text        not null default 'trial',
  settings     jsonb       not null default '{}',
  active       boolean     not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
comment on table organizations is 'Clínicas / tenants do SaaS';

-- ─── Locations ───────────────────────────────────────────────
create table locations (
  id           uuid        primary key default gen_random_uuid(),
  org_id       uuid        not null references organizations on delete cascade,
  name         text        not null,
  address      text,
  city         text,
  phone        text,
  timezone     text        not null default 'America/Sao_Paulo',
  active       boolean     not null default true,
  created_at   timestamptz not null default now()
);
comment on table locations is 'Unidades físicas da organização';

-- ─── Profiles ────────────────────────────────────────────────
create table profiles (
  id           uuid        primary key default gen_random_uuid(),
  user_id      uuid        not null references auth.users on delete cascade,
  org_id       uuid        not null references organizations on delete cascade,
  full_name    text        not null,
  avatar_url   text,
  phone        text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique(user_id, org_id)
);
comment on table profiles is 'Perfil de usuário por organização';

-- ─── User Roles ──────────────────────────────────────────────
create table user_roles (
  id           uuid        primary key default gen_random_uuid(),
  user_id      uuid        not null references auth.users on delete cascade,
  org_id       uuid        not null references organizations on delete cascade,
  role         user_role   not null default 'viewer',
  location_id  uuid        references locations,
  active       boolean     not null default true,
  created_at   timestamptz not null default now(),
  unique(user_id, org_id)
);
comment on table user_roles is 'Permissões de usuário por organização';

-- ─── Audit Logs ──────────────────────────────────────────────
create table audit_logs (
  id           uuid        primary key default gen_random_uuid(),
  org_id       uuid        not null references organizations on delete cascade,
  user_id      uuid        references auth.users,
  table_name   text        not null,
  operation    text        not null, -- INSERT, UPDATE, DELETE
  record_id    uuid,
  old_data     jsonb,
  new_data     jsonb,
  ip_address   inet,
  user_agent   text,
  created_at   timestamptz not null default now()
);
comment on table audit_logs is 'Log de auditoria de operações sensíveis';

-- ─── Índices ─────────────────────────────────────────────────
create index on locations  (org_id);
create index on profiles   (user_id);
create index on profiles   (org_id);
create index on user_roles (user_id);
create index on user_roles (org_id);
create index on audit_logs (org_id, created_at desc);
create index on audit_logs (user_id);

-- ─── RLS: Habilitar ──────────────────────────────────────────
alter table organizations    enable row level security;
alter table locations        enable row level security;
alter table profiles         enable row level security;
alter table user_roles       enable row level security;
alter table audit_logs       enable row level security;

-- ─── Helper function: org_ids do usuário ─────────────────────
create or replace function auth_org_ids()
returns setof uuid
language sql stable security definer
as $$
  select org_id from user_roles
  where user_id = auth.uid() and active = true
$$;

-- ─── Helper function: role do usuário na org ─────────────────
create or replace function auth_user_role(p_org_id uuid)
returns user_role
language sql stable security definer
as $$
  select role from user_roles
  where user_id = auth.uid() and org_id = p_org_id and active = true
  limit 1
$$;

-- ─── RLS Policies: organizations ─────────────────────────────
create policy "orgs_select" on organizations
  for select using (id in (select auth_org_ids()));

create policy "orgs_update_owner" on organizations
  for update using (auth_user_role(id) in ('owner', 'admin'));

-- ─── RLS Policies: locations ─────────────────────────────────
create policy "locations_select" on locations
  for select using (org_id in (select auth_org_ids()));

create policy "locations_write_manager" on locations
  for all using (auth_user_role(org_id) in ('owner', 'admin', 'manager'));

-- ─── RLS Policies: profiles ──────────────────────────────────
create policy "profiles_select_own_org" on profiles
  for select using (org_id in (select auth_org_ids()));

create policy "profiles_update_own" on profiles
  for update using (user_id = auth.uid());

create policy "profiles_insert_own" on profiles
  for insert with check (user_id = auth.uid());

-- ─── RLS Policies: user_roles ────────────────────────────────
create policy "roles_select_own_org" on user_roles
  for select using (org_id in (select auth_org_ids()));

create policy "roles_manage_owner" on user_roles
  for all using (auth_user_role(org_id) in ('owner', 'admin'));

-- ─── RLS Policies: audit_logs ────────────────────────────────
create policy "audit_select_manager" on audit_logs
  for select using (
    org_id in (select auth_org_ids())
    and auth_user_role(org_id) in ('owner', 'admin', 'manager')
  );

create policy "audit_insert_any" on audit_logs
  for insert with check (org_id in (select auth_org_ids()));

-- ─── Updated_at trigger ──────────────────────────────────────
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_organizations_updated_at
  before update on organizations
  for each row execute function set_updated_at();

create trigger trg_profiles_updated_at
  before update on profiles
  for each row execute function set_updated_at();
