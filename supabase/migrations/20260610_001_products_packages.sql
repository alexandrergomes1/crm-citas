-- Migration: Products + Service Packages (combos/bundles)
-- Encoding: UTF-8

-- ─── Products ────────────────────────────────────────────────────────────────
-- Physical products sold at checkout (serums, creams, tools, etc.)

CREATE TABLE IF NOT EXISTS products (
  id            uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  org_id        uuid        NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name          text        NOT NULL,
  description   text,
  price         numeric(10,2) NOT NULL DEFAULT 0,
  cost_price    numeric(10,2) NOT NULL DEFAULT 0,
  sku           text,
  barcode       text,
  stock_qty     integer     NOT NULL DEFAULT 0,
  stock_alert   integer     NOT NULL DEFAULT 5,
  category_id   uuid        REFERENCES service_categories(id) ON DELETE SET NULL,
  brand         text,
  unit          text        NOT NULL DEFAULT 'un',
  online_booking boolean   NOT NULL DEFAULT false,
  active        boolean     NOT NULL DEFAULT true,
  position      integer     NOT NULL DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "products_org_access" ON products;
CREATE POLICY "products_org_access" ON products
  FOR ALL
  USING (org_id IN (
    SELECT org_id FROM user_roles
    WHERE user_id = auth.uid() AND active = true
  ));

CREATE INDEX IF NOT EXISTS idx_products_org_active ON products (org_id, active);

-- ─── Service Packages ────────────────────────────────────────────────────────
-- Bundles / combos: prepaid set of sessions with one or more services

CREATE TABLE IF NOT EXISTS service_packages (
  id              uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  org_id          uuid        NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name            text        NOT NULL,
  description     text,
  price           numeric(10,2) NOT NULL DEFAULT 0,
  sessions        integer     NOT NULL DEFAULT 1,
  validity_days   integer     NOT NULL DEFAULT 365,
  highlight_color text,
  online_booking  boolean     NOT NULL DEFAULT false,
  active          boolean     NOT NULL DEFAULT true,
  position        integer     NOT NULL DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE service_packages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "packages_org_access" ON service_packages;
CREATE POLICY "packages_org_access" ON service_packages
  FOR ALL
  USING (org_id IN (
    SELECT org_id FROM user_roles
    WHERE user_id = auth.uid() AND active = true
  ));

CREATE INDEX IF NOT EXISTS idx_service_packages_org_active ON service_packages (org_id, active);

-- ─── Package ↔ Services (junction) ───────────────────────────────────────────

CREATE TABLE IF NOT EXISTS package_services (
  id          uuid    DEFAULT gen_random_uuid() PRIMARY KEY,
  package_id  uuid    NOT NULL REFERENCES service_packages(id) ON DELETE CASCADE,
  service_id  uuid    NOT NULL REFERENCES services(id)         ON DELETE CASCADE,
  qty         integer NOT NULL DEFAULT 1,
  UNIQUE (package_id, service_id)
);

ALTER TABLE package_services ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "package_services_access" ON package_services;
CREATE POLICY "package_services_access" ON package_services
  FOR ALL
  USING (package_id IN (
    SELECT id FROM service_packages
    WHERE org_id IN (
      SELECT org_id FROM user_roles
      WHERE user_id = auth.uid() AND active = true
    )
  ));
