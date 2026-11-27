-- ============================================================
-- KA Beauty OS — Migration 006: Financeiro
-- Encoding: UTF-8
-- ============================================================

-- ─── Sales (Comandas) ────────────────────────────────────────
create table sales (
  id               uuid          primary key default gen_random_uuid(),
  org_id           uuid          not null references organizations on delete cascade,
  appointment_id   uuid          references appointments,
  client_id        uuid          references clients,
  client_name      text          not null default '',
  staff_id         uuid          references staff_members,
  status           text          not null default 'draft', -- draft | partial | paid | cancelled
  subtotal         numeric(10,2) not null default 0,
  discount         numeric(10,2) not null default 0,
  tip              numeric(10,2) not null default 0,
  total            numeric(10,2) not null default 0,
  paid_amount      numeric(10,2) not null default 0,
  balance          numeric(10,2) generated always as (paid_amount - total) stored,
  notes            text,
  created_at       timestamptz   not null default now(),
  updated_at       timestamptz   not null default now()
);
comment on table sales is 'Comandas de venda (snapshot imutável após pago)';

-- ─── Sale Items ──────────────────────────────────────────────
create table sale_items (
  id                   uuid          primary key default gen_random_uuid(),
  org_id               uuid          not null references organizations on delete cascade,
  sale_id              uuid          not null references sales on delete cascade,
  item_type            text          not null, -- SERVICE | PRODUCT | PACKAGE | PLAN
  item_id              uuid,
  name                 text          not null,
  category             text,
  unit_price           numeric(10,2) not null default 0,
  quantity             int           not null default 1,
  total_price          numeric(10,2) not null default 0,
  entitlement_id       uuid,
  covered_by_entitlement boolean     not null default false,
  created_at           timestamptz   not null default now()
);

-- ─── Sale Payments ───────────────────────────────────────────
create table sale_payments (
  id               uuid          primary key default gen_random_uuid(),
  org_id           uuid          not null references organizations on delete cascade,
  sale_id          uuid          not null references sales on delete cascade,
  method           text          not null, -- CASH | CARD_MACHINE | CARD_MANUAL | PIX | TRANSFER | GIFT_CARD | CLIENT_CREDIT
  amount           numeric(10,2) not null,
  gift_card_code   text,
  reference        text,
  created_at       timestamptz   not null default now()
);

-- ─── Transactions (Caixa) ────────────────────────────────────
create table transactions (
  id               uuid          primary key default gen_random_uuid(),
  org_id           uuid          not null references organizations on delete cascade,
  sale_id          uuid          references sales,
  client_id        uuid          references clients,
  client_name      text,
  type             text          not null, -- income | expense
  category         text,
  description      text          not null,
  value            numeric(10,2) not null,
  method           text,
  date             date          not null,
  status           text          not null default 'completed', -- completed | pending | cancelled
  created_by       uuid          references auth.users,
  created_at       timestamptz   not null default now()
);
comment on table transactions is 'Lançamentos de caixa (receitas e despesas)';

-- ─── Payables (Contas a Pagar) ───────────────────────────────
create table payables (
  id               uuid          primary key default gen_random_uuid(),
  org_id           uuid          not null references organizations on delete cascade,
  description      text          not null,
  category         text,
  value            numeric(10,2) not null,
  due_date         date          not null,
  paid_date        date,
  paid_value       numeric(10,2),
  status           text          not null default 'pending', -- pending | paid | overdue | cancelled
  vendor           text,
  recurrence       text,
  notes            text,
  created_by       uuid          references auth.users,
  created_at       timestamptz   not null default now(),
  updated_at       timestamptz   not null default now()
);
comment on table payables is 'Contas a pagar da clínica';

-- ─── Gift Cards ──────────────────────────────────────────────
create table gift_cards (
  id               uuid          primary key default gen_random_uuid(),
  org_id           uuid          not null references organizations on delete cascade,
  code             text          unique not null,
  initial_value    numeric(10,2) not null,
  remaining_value  numeric(10,2) not null,
  issued_to        text,
  issued_by        uuid          references auth.users,
  expires_at       date,
  status           text          not null default 'active', -- active | used | expired | cancelled
  sale_id          uuid          references sales,
  created_at       timestamptz   not null default now()
);

-- ─── Índices ─────────────────────────────────────────────────
create index on sales          (org_id, created_at desc);
create index on sales          (org_id, client_id);
create index on sales          (org_id, status);
create index on sale_items     (sale_id);
create index on sale_items     (org_id);
create index on sale_payments  (sale_id);
create index on transactions   (org_id, date desc);
create index on transactions   (org_id, type, date desc);
create index on transactions   (org_id, status);
create index on payables       (org_id, due_date);
create index on payables       (org_id, status);
create index on gift_cards     (org_id, code);
create index on gift_cards     (org_id, status);

-- ─── RLS ─────────────────────────────────────────────────────
alter table sales          enable row level security;
alter table sale_items     enable row level security;
alter table sale_payments  enable row level security;
alter table transactions   enable row level security;
alter table payables       enable row level security;
alter table gift_cards     enable row level security;

-- Finance: leitura owner/admin/manager/finance, escrita manager+
create policy "sales_select" on sales
  for select using (
    org_id in (select auth_org_ids())
    and auth_user_role(org_id) in ('owner','admin','manager','finance','receptionist','professional')
  );
create policy "sales_write" on sales
  for all using (
    org_id in (select auth_org_ids())
    and auth_user_role(org_id) in ('owner','admin','manager','receptionist','professional')
  );

create policy "sale_items_select"    on sale_items    for select using (org_id in (select auth_org_ids()));
create policy "sale_payments_select" on sale_payments for select using (org_id in (select auth_org_ids()));
create policy "sale_items_write"     on sale_items    for all using (org_id in (select auth_org_ids()) and auth_user_role(org_id) in ('owner','admin','manager','receptionist','professional'));
create policy "sale_payments_write"  on sale_payments for all using (org_id in (select auth_org_ids()) and auth_user_role(org_id) in ('owner','admin','manager','receptionist','professional'));

create policy "tx_select"  on transactions for select using (org_id in (select auth_org_ids()) and auth_user_role(org_id) in ('owner','admin','manager','finance'));
create policy "tx_write"   on transactions for all    using (org_id in (select auth_org_ids()) and auth_user_role(org_id) in ('owner','admin','manager','finance'));

create policy "payables_select" on payables for select using (org_id in (select auth_org_ids()) and auth_user_role(org_id) in ('owner','admin','manager','finance'));
create policy "payables_write"  on payables for all    using (org_id in (select auth_org_ids()) and auth_user_role(org_id) in ('owner','admin','manager','finance'));

create policy "giftcards_select" on gift_cards for select using (org_id in (select auth_org_ids()));
create policy "giftcards_write"  on gift_cards for all    using (org_id in (select auth_org_ids()) and auth_user_role(org_id) in ('owner','admin','manager','receptionist'));

-- ─── Updated_at ──────────────────────────────────────────────
create trigger trg_sales_updated_at     before update on sales     for each row execute function set_updated_at();
create trigger trg_payables_updated_at  before update on payables  for each row execute function set_updated_at();
