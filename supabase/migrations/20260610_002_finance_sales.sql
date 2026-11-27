-- ============================================================
-- KA Beauty OS — Migration 20260610_002: Financeiro (Comandas/Vendas)
-- Encoding: UTF-8
--
-- Cria as tabelas de venda/caixa ausentes no schema aplicado
-- (série 20260609_*). Idempotente: pode rodar com segurança mais
-- de uma vez (IF NOT EXISTS + DROP POLICY IF EXISTS).
--
-- Depende de: organizations, appointments, clients, staff_members,
-- user_roles, e helpers auth_org_ids()/auth_user_role() (RLS),
-- e da trigger fn update_updated_at() (foundation 20260609_001).
-- ============================================================

-- ─── Sales (Comandas) ────────────────────────────────────────
create table if not exists sales (
  id             uuid          primary key default gen_random_uuid(),
  org_id         uuid          not null references organizations on delete cascade,
  appointment_id uuid          references appointments,
  client_id      uuid          references clients,
  client_name    text          not null default '',
  staff_id       uuid          references staff_members,
  status         text          not null default 'draft', -- draft | partial | paid | cancelled
  subtotal       numeric(10,2) not null default 0,
  discount       numeric(10,2) not null default 0,
  tip            numeric(10,2) not null default 0,
  total          numeric(10,2) not null default 0,
  paid_amount    numeric(10,2) not null default 0,
  balance        numeric(10,2) not null default 0, -- saldo pendente (débito) da comanda
  notes          text,
  created_at     timestamptz   not null default now(),
  updated_at     timestamptz   not null default now()
);
comment on table sales is 'Comandas de venda (snapshot do atendimento no fechamento)';

-- ─── Sale Items ──────────────────────────────────────────────
create table if not exists sale_items (
  id                     uuid          primary key default gen_random_uuid(),
  org_id                 uuid          not null references organizations on delete cascade,
  sale_id                uuid          not null references sales on delete cascade,
  item_type              text          not null, -- SERVICE | PRODUCT | PACKAGE | PLAN
  item_id                uuid,
  name                   text          not null,
  category               text,
  unit_price             numeric(10,2) not null default 0,
  quantity               int           not null default 1,
  total_price            numeric(10,2) not null default 0,
  entitlement_id         uuid,
  covered_by_entitlement boolean       not null default false,
  created_at             timestamptz   not null default now()
);

-- ─── Sale Payments ───────────────────────────────────────────
create table if not exists sale_payments (
  id             uuid          primary key default gen_random_uuid(),
  org_id         uuid          not null references organizations on delete cascade,
  sale_id        uuid          not null references sales on delete cascade,
  method         text          not null, -- CASH | PIX | CARD_DEBIT | CARD_CREDIT | TRANSFER | CLIENT_CREDIT
  amount         numeric(10,2) not null,
  gift_card_code text,
  reference      text,
  created_at     timestamptz   not null default now()
);

-- ─── Transactions (Caixa) ────────────────────────────────────
create table if not exists transactions (
  id          uuid          primary key default gen_random_uuid(),
  org_id      uuid          not null references organizations on delete cascade,
  sale_id     uuid          references sales,
  client_id   uuid          references clients,
  client_name text,
  type        text          not null, -- income | expense
  category    text,
  description text          not null,
  value       numeric(10,2) not null,
  method      text,
  date        date          not null,
  status      text          not null default 'completed', -- completed | pending | cancelled
  created_by  uuid          references auth.users,
  created_at  timestamptz   not null default now()
);
comment on table transactions is 'Lançamentos de caixa (receitas e despesas)';

-- ─── Payables (Contas a Pagar) ───────────────────────────────
create table if not exists payables (
  id          uuid          primary key default gen_random_uuid(),
  org_id      uuid          not null references organizations on delete cascade,
  description text          not null,
  category    text,
  value       numeric(10,2) not null,
  due_date    date          not null,
  paid_date   date,
  paid_value  numeric(10,2),
  status      text          not null default 'pending', -- pending | paid | overdue | cancelled
  vendor      text,
  recurrence  text,
  notes       text,
  created_by  uuid          references auth.users,
  created_at  timestamptz   not null default now(),
  updated_at  timestamptz   not null default now()
);
comment on table payables is 'Contas a pagar da clínica';

-- ─── Gift Cards ──────────────────────────────────────────────
create table if not exists gift_cards (
  id              uuid          primary key default gen_random_uuid(),
  org_id          uuid          not null references organizations on delete cascade,
  code            text          unique not null,
  initial_value   numeric(10,2) not null,
  remaining_value numeric(10,2) not null,
  issued_to       text,
  issued_by       uuid          references auth.users,
  expires_at      date,
  status          text          not null default 'active', -- active | used | expired | cancelled
  sale_id         uuid          references sales,
  created_at      timestamptz   not null default now()
);

-- ─── Índices ─────────────────────────────────────────────────
create index if not exists idx_sales_org_created    on sales         (org_id, created_at desc);
create index if not exists idx_sales_org_client     on sales         (org_id, client_id);
create index if not exists idx_sales_org_status     on sales         (org_id, status);
create index if not exists idx_sales_appointment    on sales         (appointment_id);
create index if not exists idx_sale_items_sale      on sale_items    (sale_id);
create index if not exists idx_sale_items_org       on sale_items    (org_id);
create index if not exists idx_sale_payments_sale   on sale_payments (sale_id);
create index if not exists idx_tx_org_date          on transactions  (org_id, date desc);
create index if not exists idx_tx_org_type_date     on transactions  (org_id, type, date desc);
create index if not exists idx_tx_org_status        on transactions  (org_id, status);
create index if not exists idx_payables_org_due     on payables      (org_id, due_date);
create index if not exists idx_payables_org_status  on payables      (org_id, status);
create index if not exists idx_giftcards_org_code   on gift_cards    (org_id, code);
create index if not exists idx_giftcards_org_status on gift_cards    (org_id, status);

-- ─── RLS ─────────────────────────────────────────────────────
alter table sales         enable row level security;
alter table sale_items    enable row level security;
alter table sale_payments enable row level security;
alter table transactions  enable row level security;
alter table payables      enable row level security;
alter table gift_cards    enable row level security;

drop policy if exists "sales_select" on sales;
drop policy if exists "sales_write"  on sales;
create policy "sales_select" on sales for select using (
  org_id in (select auth_org_ids())
  and auth_user_role(org_id) in ('owner','admin','manager','finance','receptionist','professional'));
create policy "sales_write" on sales for all using (
  org_id in (select auth_org_ids())
  and auth_user_role(org_id) in ('owner','admin','manager','receptionist','professional'));

drop policy if exists "sale_items_select"    on sale_items;
drop policy if exists "sale_items_write"     on sale_items;
drop policy if exists "sale_payments_select" on sale_payments;
drop policy if exists "sale_payments_write"  on sale_payments;
create policy "sale_items_select"    on sale_items    for select using (org_id in (select auth_org_ids()));
create policy "sale_items_write"     on sale_items    for all using (org_id in (select auth_org_ids()) and auth_user_role(org_id) in ('owner','admin','manager','receptionist','professional'));
create policy "sale_payments_select" on sale_payments for select using (org_id in (select auth_org_ids()));
create policy "sale_payments_write"  on sale_payments for all using (org_id in (select auth_org_ids()) and auth_user_role(org_id) in ('owner','admin','manager','receptionist','professional'));

drop policy if exists "tx_select" on transactions;
drop policy if exists "tx_write"  on transactions;
create policy "tx_select" on transactions for select using (org_id in (select auth_org_ids()) and auth_user_role(org_id) in ('owner','admin','manager','finance'));
create policy "tx_write"  on transactions for all    using (org_id in (select auth_org_ids()) and auth_user_role(org_id) in ('owner','admin','manager','finance','receptionist','professional'));

drop policy if exists "payables_select" on payables;
drop policy if exists "payables_write"  on payables;
create policy "payables_select" on payables for select using (org_id in (select auth_org_ids()) and auth_user_role(org_id) in ('owner','admin','manager','finance'));
create policy "payables_write"  on payables for all    using (org_id in (select auth_org_ids()) and auth_user_role(org_id) in ('owner','admin','manager','finance'));

drop policy if exists "giftcards_select" on gift_cards;
drop policy if exists "giftcards_write"  on gift_cards;
create policy "giftcards_select" on gift_cards for select using (org_id in (select auth_org_ids()));
create policy "giftcards_write"  on gift_cards for all    using (org_id in (select auth_org_ids()) and auth_user_role(org_id) in ('owner','admin','manager','receptionist'));

-- ─── Triggers updated_at (usa update_updated_at do foundation) ─
create or replace trigger trg_sales_updated_at    before update on sales    for each row execute function update_updated_at();
create or replace trigger trg_payables_updated_at before update on payables for each row execute function update_updated_at();
