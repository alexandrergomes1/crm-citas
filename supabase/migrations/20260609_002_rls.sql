-- ============================================================
-- KA Beauty OS — Migration 002: Row Level Security
-- Encoding: UTF-8
-- ============================================================

-- ─── Habilitar RLS em todas as tabelas ───────────────────────────────────────
alter table organizations            enable row level security;
alter table locations                enable row level security;
alter table profiles                 enable row level security;
alter table user_roles               enable row level security;
alter table service_categories       enable row level security;
alter table services                 enable row level security;
alter table clients                  enable row level security;
alter table staff_members            enable row level security;
alter table staff_shifts             enable row level security;
alter table appointments             enable row level security;
alter table appointment_items        enable row level security;
alter table appointment_status_history enable row level security;

-- ─── Helper: orgs do usuário logado ──────────────────────────────────────────
create or replace function auth_org_ids()
returns setof uuid
language sql security definer stable as $$
  select org_id from user_roles
  where user_id = auth.uid() and active = true;
$$;

-- ─── Helper: role do usuário em uma org ──────────────────────────────────────
create or replace function auth_user_role(p_org_id uuid)
returns text
language sql security definer stable as $$
  select role from user_roles
  where user_id = auth.uid() and org_id = p_org_id and active = true
  limit 1;
$$;

-- ─── Organizations ───────────────────────────────────────────────────────────
create policy "org: membros podem ver"
  on organizations for select
  using (id in (select auth_org_ids()));

create policy "org: owner pode editar"
  on organizations for update
  using (auth_user_role(id) in ('owner', 'admin'));

-- ─── Locations ───────────────────────────────────────────────────────────────
create policy "locations: ver"
  on locations for select
  using (org_id in (select auth_org_ids()));

create policy "locations: admin gerencia"
  on locations for all
  using (auth_user_role(org_id) in ('owner', 'admin'));

-- ─── Profiles ────────────────────────────────────────────────────────────────
create policy "profiles: ver da org"
  on profiles for select
  using (org_id in (select auth_org_ids()));

create policy "profiles: editar próprio"
  on profiles for update
  using (user_id = auth.uid());

create policy "profiles: inserir"
  on profiles for insert
  with check (org_id in (select auth_org_ids()));

-- ─── User Roles ──────────────────────────────────────────────────────────────
create policy "roles: ver da org"
  on user_roles for select
  using (org_id in (select auth_org_ids()));

create policy "roles: admin gerencia"
  on user_roles for all
  using (auth_user_role(org_id) in ('owner', 'admin'));

-- ─── Service Categories ──────────────────────────────────────────────────────
create policy "categories: ver"
  on service_categories for select
  using (org_id in (select auth_org_ids()));

create policy "categories: admin gerencia"
  on service_categories for all
  using (auth_user_role(org_id) in ('owner', 'admin', 'manager'));

-- ─── Services ────────────────────────────────────────────────────────────────
create policy "services: ver"
  on services for select
  using (org_id in (select auth_org_ids()));

create policy "services: admin gerencia"
  on services for all
  using (auth_user_role(org_id) in ('owner', 'admin', 'manager'));

-- ─── Clients ─────────────────────────────────────────────────────────────────
create policy "clients: ver"
  on clients for select
  using (org_id in (select auth_org_ids()));

create policy "clients: criar e editar"
  on clients for all
  using (auth_user_role(org_id) in ('owner', 'admin', 'manager', 'receptionist', 'professional'));

-- ─── Staff Members ───────────────────────────────────────────────────────────
create policy "staff: ver"
  on staff_members for select
  using (org_id in (select auth_org_ids()));

create policy "staff: admin gerencia"
  on staff_members for all
  using (auth_user_role(org_id) in ('owner', 'admin', 'manager'));

-- ─── Staff Shifts ────────────────────────────────────────────────────────────
create policy "shifts: ver"
  on staff_shifts for select
  using (org_id in (select auth_org_ids()));

create policy "shifts: admin gerencia"
  on staff_shifts for all
  using (auth_user_role(org_id) in ('owner', 'admin', 'manager'));

-- ─── Appointments ────────────────────────────────────────────────────────────
create policy "appointments: ver"
  on appointments for select
  using (org_id in (select auth_org_ids()));

create policy "appointments: criar"
  on appointments for insert
  with check (org_id in (select auth_org_ids()));

create policy "appointments: editar"
  on appointments for update
  using (org_id in (select auth_org_ids()) and
         auth_user_role(org_id) in ('owner', 'admin', 'manager', 'receptionist', 'professional'));

create policy "appointments: cancelar"
  on appointments for delete
  using (auth_user_role(org_id) in ('owner', 'admin', 'manager'));

-- ─── Appointment Items ───────────────────────────────────────────────────────
create policy "appt_items: ver"
  on appointment_items for select
  using (org_id in (select auth_org_ids()));

create policy "appt_items: gerenciar"
  on appointment_items for all
  using (org_id in (select auth_org_ids()));

-- ─── Appointment Status History ──────────────────────────────────────────────
create policy "appt_history: ver"
  on appointment_status_history for select
  using (org_id in (select auth_org_ids()));

create policy "appt_history: inserir"
  on appointment_status_history for insert
  with check (org_id in (select auth_org_ids()));
