-- ============================================================
-- KA Beauty OS — Migration 005: Agendamentos
-- Encoding: UTF-8
-- ============================================================

-- ─── Appointments ────────────────────────────────────────────
create table appointments (
  id                uuid          primary key default gen_random_uuid(),
  org_id            uuid          not null references organizations on delete cascade,
  location_id       uuid          references locations,
  client_id         uuid          references clients,
  client_name       text          not null default '',
  staff_id          uuid          references staff_members,
  staff_name        text          not null default '',
  resource_id       uuid          references resources,

  -- Horário
  start_at          timestamptz   not null,
  end_at            timestamptz   not null,
  duration_minutes  int           not null default 0,

  -- Status
  status            text          not null default 'Agendado',
  -- Reservado | Agendado | Confirmado | Iniciado | Concluído | Pago Parcial | Pago | Ausência | Cancelado | Bloqueio

  -- Dados operacionais
  notes             text,
  internal_notes    text,
  color             text,
  source            text          not null default 'MANUAL', -- MANUAL | WHATSAPP | ONLINE | PHONE
  linked_anamnese_id uuid,

  -- Financeiro
  total             numeric(10,2) not null default 0,
  discount          numeric(10,2) not null default 0,
  tip               numeric(10,2) not null default 0,

  -- Recorrência
  recurrence_id     uuid,         -- link para grupo de recorrência
  recurrence_index  int,

  created_at        timestamptz   not null default now(),
  updated_at        timestamptz   not null default now()
);
comment on table appointments is 'Agendamentos da clínica';

-- ─── Appointment Items ───────────────────────────────────────
create table appointment_items (
  id                    uuid          primary key default gen_random_uuid(),
  org_id                uuid          not null references organizations on delete cascade,
  appointment_id        uuid          not null references appointments on delete cascade,
  item_type             text          not null, -- SERVICE | PRODUCT | PACKAGE | PLAN
  item_id               uuid,
  name                  text          not null,
  category              text,
  price                 numeric(10,2) not null default 0,
  original_price        numeric(10,2),
  cost_amount           numeric(10,2) not null default 0,
  duration_minutes      int           not null default 0,
  quantity              int           not null default 1,
  entitlement_id        uuid,         -- se coberto por pacote/plano
  entitlement_name      text,
  covered_by_entitlement boolean      not null default false,
  requires_anamnese     boolean       not null default false,
  anamnese_template_id  uuid,
  position              int           not null default 0,
  created_at            timestamptz   not null default now()
);
comment on table appointment_items is 'Serviços e produtos do agendamento';

-- ─── Appointment Status History ──────────────────────────────
create table appointment_status_history (
  id              uuid        primary key default gen_random_uuid(),
  org_id          uuid        not null references organizations on delete cascade,
  appointment_id  uuid        not null references appointments on delete cascade,
  status          text        not null,
  changed_by      uuid        references auth.users,
  changed_by_name text,
  notes           text,
  created_at      timestamptz not null default now()
);

-- ─── Time Blocks (Bloqueios de agenda) ───────────────────────
create table time_blocks (
  id           uuid        primary key default gen_random_uuid(),
  org_id       uuid        not null references organizations on delete cascade,
  staff_id     uuid        references staff_members,
  resource_id  uuid        references resources,
  location_id  uuid        references locations,
  start_at     timestamptz not null,
  end_at       timestamptz not null,
  reason       text,
  repeat_rule  text,        -- iCal RRULE opcional
  created_by   uuid        references auth.users,
  created_at   timestamptz not null default now()
);
comment on table time_blocks is 'Bloqueios de horário e indisponibilidades';

-- ─── Client Entitlements (Pacotes / Planos adquiridos) ───────
create table client_entitlements (
  id                  uuid          primary key default gen_random_uuid(),
  org_id              uuid          not null references organizations on delete cascade,
  client_id           uuid          not null references clients on delete cascade,
  source_item_id      uuid          not null, -- package_id ou plan_id
  source_type         text          not null, -- PACKAGE | PLAN
  name                text          not null,
  status              text          not null default 'ACTIVE', -- ACTIVE | CONSUMED | EXPIRED | REFUNDED
  total_units         int,
  remaining_units     int,
  purchased_at        timestamptz   not null default now(),
  expires_at          date,
  appointment_id      uuid          references appointments,
  created_at          timestamptz   not null default now(),
  updated_at          timestamptz   not null default now()
);

create table client_entitlement_entries (
  id               uuid          primary key default gen_random_uuid(),
  org_id           uuid          not null references organizations on delete cascade,
  entitlement_id   uuid          not null references client_entitlements on delete cascade,
  client_id        uuid          not null references clients,
  appointment_id   uuid          references appointments,
  entry_type       text          not null, -- PURCHASE | USE | REFUND | ADJUSTMENT | EXPIRATION
  quantity         int           not null default 0,
  balance_after    int,
  description      text,
  created_at       timestamptz   not null default now()
);

-- ─── Índices ─────────────────────────────────────────────────
create index on appointments      (org_id, start_at);
create index on appointments      (org_id, staff_id, start_at);
create index on appointments      (org_id, client_id, start_at desc);
create index on appointments      (org_id, status);
create index on appointment_items (appointment_id);
create index on appointment_items (org_id);
create index on appointment_status_history (appointment_id, created_at desc);
create index on time_blocks       (org_id, start_at, end_at);
create index on time_blocks       (staff_id, start_at);
create index on client_entitlements (org_id, client_id);
create index on client_entitlements (org_id, status);
create index on client_entitlement_entries (entitlement_id, created_at desc);

-- ─── RLS ─────────────────────────────────────────────────────
alter table appointments                  enable row level security;
alter table appointment_items             enable row level security;
alter table appointment_status_history    enable row level security;
alter table time_blocks                   enable row level security;
alter table client_entitlements           enable row level security;
alter table client_entitlement_entries    enable row level security;

-- Appointments: leitura para todos da org, escrita para manager+
create policy "appts_select" on appointments
  for select using (org_id in (select auth_org_ids()));

create policy "appts_write" on appointments
  for all using (
    org_id in (select auth_org_ids())
    and auth_user_role(org_id) in ('owner','admin','manager','receptionist','professional')
  );

-- Items
create policy "appt_items_select" on appointment_items
  for select using (org_id in (select auth_org_ids()));

create policy "appt_items_write" on appointment_items
  for all using (
    org_id in (select auth_org_ids())
    and auth_user_role(org_id) in ('owner','admin','manager','receptionist','professional')
  );

-- Status history: readonly para todos, insert para authorized
create policy "appt_status_select" on appointment_status_history
  for select using (org_id in (select auth_org_ids()));

create policy "appt_status_insert" on appointment_status_history
  for insert with check (
    org_id in (select auth_org_ids())
    and auth_user_role(org_id) in ('owner','admin','manager','receptionist','professional')
  );

-- Time blocks
create policy "blocks_select" on time_blocks
  for select using (org_id in (select auth_org_ids()));

create policy "blocks_write" on time_blocks
  for all using (
    org_id in (select auth_org_ids())
    and auth_user_role(org_id) in ('owner','admin','manager','receptionist','professional')
  );

-- Entitlements
create policy "entitlements_select" on client_entitlements
  for select using (org_id in (select auth_org_ids()));

create policy "entitlements_write" on client_entitlements
  for all using (
    org_id in (select auth_org_ids())
    and auth_user_role(org_id) in ('owner','admin','manager','professional')
  );

create policy "entitlement_entries_select" on client_entitlement_entries
  for select using (org_id in (select auth_org_ids()));

create policy "entitlement_entries_write" on client_entitlement_entries
  for insert with check (org_id in (select auth_org_ids()));

-- ─── Updated_at ──────────────────────────────────────────────
create trigger trg_appointments_updated_at before update on appointments for each row execute function set_updated_at();
create trigger trg_entitlements_updated_at  before update on client_entitlements for each row execute function set_updated_at();
