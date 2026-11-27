-- ============================================================
-- KA Beauty OS — Migration 003: Catálogo (Serviços, Produtos, Recursos)
-- Encoding: UTF-8
-- ============================================================

-- ─── Service Categories ──────────────────────────────────────
create table service_categories (
  id           uuid        primary key default gen_random_uuid(),
  org_id       uuid        not null references organizations on delete cascade,
  name         text        not null,
  color        text        not null default '#F43F5E',
  position     int         not null default 0,
  active       boolean     not null default true,
  created_at   timestamptz not null default now()
);

-- ─── Services ────────────────────────────────────────────────
create table services (
  id                    uuid          primary key default gen_random_uuid(),
  org_id                uuid          not null references organizations on delete cascade,
  category_id           uuid          references service_categories,
  name                  text          not null,
  description           text,
  price                 numeric(10,2) not null default 0,
  price_type            text          not null default 'FIXED', -- FIXED | FROM | FREE
  cost_amount           numeric(10,2) not null default 0,
  duration_minutes      int           not null default 60,
  buffer_minutes        int           not null default 0,       -- tempo de intervalo pós-serviço
  requires_anamnese     boolean       not null default false,
  anamnese_template_id  uuid,
  online_booking        boolean       not null default true,
  commission_pct        numeric(5,2)  not null default 0,
  position              int           not null default 0,
  active                boolean       not null default true,
  created_at            timestamptz   not null default now(),
  updated_at            timestamptz   not null default now()
);
comment on table services is 'Serviços do catálogo por organização';

-- ─── Products ────────────────────────────────────────────────
create table products (
  id               uuid          primary key default gen_random_uuid(),
  org_id           uuid          not null references organizations on delete cascade,
  name             text          not null,
  description      text,
  sku              text,
  barcode          text,
  price            numeric(10,2) not null default 0,
  cost_amount      numeric(10,2) not null default 0,
  stock_quantity   int           not null default 0,
  stock_min        int           not null default 0,
  unit             text          not null default 'un',
  category         text,
  active           boolean       not null default true,
  created_at       timestamptz   not null default now(),
  updated_at       timestamptz   not null default now()
);
comment on table products is 'Produtos para venda e uso em serviços';

-- ─── Resources (Rooms, Equipment) ────────────────────────────
create table resources (
  id           uuid        primary key default gen_random_uuid(),
  org_id       uuid        not null references organizations on delete cascade,
  location_id  uuid        references locations,
  name         text        not null,
  type         text        not null default 'room', -- room | equipment
  capacity     int         not null default 1,
  active       boolean     not null default true,
  created_at   timestamptz not null default now()
);

-- ─── Service Packages ────────────────────────────────────────
create table service_packages (
  id               uuid          primary key default gen_random_uuid(),
  org_id           uuid          not null references organizations on delete cascade,
  name             text          not null,
  description      text,
  price            numeric(10,2) not null default 0,
  validity_days    int           not null default 180,
  active           boolean       not null default true,
  created_at       timestamptz   not null default now()
);

create table service_package_items (
  id           uuid  primary key default gen_random_uuid(),
  package_id   uuid  not null references service_packages on delete cascade,
  service_id   uuid  not null references services on delete cascade,
  quantity     int   not null default 1
);

-- ─── Subscription Plans ──────────────────────────────────────
create table subscription_plans (
  id                    uuid          primary key default gen_random_uuid(),
  org_id                uuid          not null references organizations on delete cascade,
  name                  text          not null,
  description           text,
  price                 numeric(10,2) not null default 0,
  frequency             text          not null default 'MONTHLY', -- MONTHLY | WEEKLY | YEARLY
  validity_days         int,
  sessions_limit        int,
  active                boolean       not null default true,
  created_at            timestamptz   not null default now()
);

create table subscription_plan_services (
  id          uuid primary key default gen_random_uuid(),
  plan_id     uuid not null references subscription_plans on delete cascade,
  service_id  uuid not null references services on delete cascade
);

-- ─── Índices ─────────────────────────────────────────────────
create index on service_categories    (org_id, position);
create index on services              (org_id, active);
create index on services              (org_id, category_id);
create index on products              (org_id, active);
create index on resources             (org_id);
create index on service_packages      (org_id, active);
create index on subscription_plans    (org_id, active);

-- ─── RLS ─────────────────────────────────────────────────────
alter table service_categories      enable row level security;
alter table services                enable row level security;
alter table products                enable row level security;
alter table resources               enable row level security;
alter table service_packages        enable row level security;
alter table service_package_items   enable row level security;
alter table subscription_plans      enable row level security;
alter table subscription_plan_services enable row level security;

-- Leitura: qualquer membro da org
create policy "catalog_select" on service_categories for select using (org_id in (select auth_org_ids()));
create policy "services_select"  on services         for select using (org_id in (select auth_org_ids()));
create policy "products_select"  on products         for select using (org_id in (select auth_org_ids()));
create policy "resources_select" on resources        for select using (org_id in (select auth_org_ids()));
create policy "packages_select"  on service_packages for select using (org_id in (select auth_org_ids()));
create policy "plans_select"     on subscription_plans for select using (org_id in (select auth_org_ids()));

-- Itens de pacote/plano: join com tabela principal
create policy "pkg_items_select" on service_package_items
  for select using (
    exists (select 1 from service_packages p where p.id = package_id and p.org_id in (select auth_org_ids()))
  );

create policy "plan_services_select" on subscription_plan_services
  for select using (
    exists (select 1 from subscription_plans p where p.id = plan_id and p.org_id in (select auth_org_ids()))
  );

-- Escrita: apenas owner, admin, manager
create policy "catalog_write" on service_categories for all using (auth_user_role(org_id) in ('owner','admin','manager'));
create policy "services_write"  on services  for all using (auth_user_role(org_id) in ('owner','admin','manager'));
create policy "products_write"  on products  for all using (auth_user_role(org_id) in ('owner','admin','manager'));
create policy "resources_write" on resources for all using (auth_user_role(org_id) in ('owner','admin','manager'));
create policy "packages_write"  on service_packages for all using (auth_user_role(org_id) in ('owner','admin','manager'));
create policy "plans_write"     on subscription_plans for all using (auth_user_role(org_id) in ('owner','admin','manager'));

-- ─── Updated_at ──────────────────────────────────────────────
create trigger trg_services_updated_at before update on services for each row execute function set_updated_at();
create trigger trg_products_updated_at  before update on products  for each row execute function set_updated_at();
