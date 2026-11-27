-- ============================================================
-- KA Beauty OS — Migration 002: Clientes
-- Encoding: UTF-8
-- ============================================================

-- ─── Clients ─────────────────────────────────────────────────
create table clients (
  id               uuid        primary key default gen_random_uuid(),
  org_id           uuid        not null references organizations on delete cascade,
  full_name        text        not null,
  phone            text,
  email            text,
  birth_date       date,
  gender           text,
  cpf              text,
  notes            text,
  fixed_notes      text,                        -- Observações fixas (sempre visíveis)
  alert_text       text,                        -- Alerta clínico/estético
  alert_type       text default 'note',         -- note | allergy | condition | vip
  tags             text[]      not null default '{}',
  contact_pref     text        not null default 'whatsapp', -- whatsapp | email | sms
  status           text        not null default 'Ativo',    -- Ativo | Inativo
  balance          numeric(10,2) not null default 0,        -- saldo devedor/credor
  total_spent      numeric(10,2) not null default 0,
  loyalty_points   int         not null default 0,
  loyalty_tier     text        not null default 'Classic',  -- Classic | Silver | Gold | Black
  last_visit       date,
  source           text,                        -- MANUAL | ONLINE | REFERRAL
  location_id      uuid        references locations,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
comment on table clients is 'Clientes da clínica por organização';

-- ─── Client Notes History ────────────────────────────────────
create table client_notes (
  id           uuid        primary key default gen_random_uuid(),
  org_id       uuid        not null references organizations on delete cascade,
  client_id    uuid        not null references clients on delete cascade,
  author_id    uuid        references auth.users,
  author_name  text,
  content      text        not null,
  note_type    text        not null default 'general', -- general | pre | post | alert
  created_at   timestamptz not null default now()
);
comment on table client_notes is 'Histórico de notas e observações do cliente';

-- ─── Índices ─────────────────────────────────────────────────
create index on clients      (org_id);
create index on clients      (org_id, status);
create index on clients      (org_id, phone);
create index on clients      (org_id, email);
create index on clients      (org_id, last_visit desc);
create index on client_notes (client_id, created_at desc);

-- ─── RLS ─────────────────────────────────────────────────────
alter table clients      enable row level security;
alter table client_notes enable row level security;

create policy "clients_select" on clients
  for select using (org_id in (select auth_org_ids()));

create policy "clients_write" on clients
  for all using (
    org_id in (select auth_org_ids())
    and auth_user_role(org_id) in ('owner','admin','manager','receptionist','professional')
  );

create policy "client_notes_select" on client_notes
  for select using (org_id in (select auth_org_ids()));

create policy "client_notes_write" on client_notes
  for insert with check (org_id in (select auth_org_ids()));

-- ─── Updated_at ──────────────────────────────────────────────
create trigger trg_clients_updated_at
  before update on clients
  for each row execute function set_updated_at();
