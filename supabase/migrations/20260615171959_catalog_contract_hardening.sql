-- CAT-01: catalog schema convergence and tenant integrity.
-- Encoding: UTF-8

alter table public.service_categories
  add column if not exists icon text;

alter table public.products
  add column if not exists cost_price numeric(10,2) not null default 0,
  add column if not exists stock_qty integer not null default 0,
  add column if not exists stock_alert integer not null default 5,
  add column if not exists category_id uuid,
  add column if not exists brand text,
  add column if not exists online_booking boolean not null default false,
  add column if not exists position integer not null default 0;

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'products' and column_name = 'cost_amount'
  ) then
    execute 'update public.products set cost_price = cost_amount where cost_price = 0 and cost_amount <> 0';
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'products' and column_name = 'stock_quantity'
  ) then
    execute 'update public.products set stock_qty = stock_quantity where stock_qty = 0 and stock_quantity <> 0';
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'products' and column_name = 'stock_min'
  ) then
    execute 'update public.products set stock_alert = stock_min where stock_alert = 5 and stock_min <> 0';
  end if;
end;
$$;

alter table public.service_packages
  add column if not exists sessions integer not null default 1,
  add column if not exists highlight_color text,
  add column if not exists online_booking boolean not null default false,
  add column if not exists position integer not null default 0,
  add column if not exists updated_at timestamptz not null default now();

alter table public.subscription_plans
  add column if not exists billing_period text not null default 'monthly',
  add column if not exists sessions_per_period integer not null default 1,
  add column if not exists eligible_services jsonb not null default '[]'::jsonb,
  add column if not exists highlight_color text,
  add column if not exists online_booking boolean not null default false,
  add column if not exists position integer not null default 0,
  add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'subscription_plans' and column_name = 'frequency'
  ) then
    execute $sql$
      update public.subscription_plans
      set billing_period = case upper(frequency)
        when 'YEARLY' then 'annually'
        when 'QUARTERLY' then 'quarterly'
        else 'monthly'
      end
      where billing_period = 'monthly'
    $sql$;
  end if;
end;
$$;

update public.services
set price_type = lower(price_type);

alter table public.package_services
  add column if not exists org_id uuid;

update public.package_services items
set org_id = packages.org_id
from public.service_packages packages
where packages.id = items.package_id
  and items.org_id is null;

alter table public.package_services
  alter column org_id set not null;

alter table public.package_services
  drop constraint if exists package_services_org_id_fkey,
  add constraint package_services_org_id_fkey
    foreign key (org_id) references public.organizations(id) on delete cascade;

alter table public.service_categories
  add constraint service_categories_id_org_key unique (id, org_id);
alter table public.services
  add constraint services_id_org_key unique (id, org_id);
alter table public.products
  add constraint products_id_org_key unique (id, org_id);
alter table public.service_packages
  add constraint service_packages_id_org_key unique (id, org_id);
alter table public.staff_members
  add constraint staff_members_id_org_key unique (id, org_id);
alter table public.anamnese_templates
  add constraint anamnese_templates_id_org_key unique (id, org_id);

alter table public.services
  drop constraint if exists services_category_id_fkey,
  add constraint services_category_org_fkey
    foreign key (category_id, org_id)
    references public.service_categories(id, org_id)
    on delete restrict,
  add constraint services_anamnese_template_org_fkey
    foreign key (anamnese_template_id, org_id)
    references public.anamnese_templates(id, org_id)
    on delete restrict;

alter table public.products
  drop constraint if exists products_category_id_fkey,
  add constraint products_category_org_fkey
    foreign key (category_id, org_id)
    references public.service_categories(id, org_id)
    on delete restrict;

alter table public.service_staff
  add constraint service_staff_service_org_fkey
    foreign key (service_id, org_id)
    references public.services(id, org_id)
    on delete cascade,
  add constraint service_staff_staff_org_fkey
    foreign key (staff_id, org_id)
    references public.staff_members(id, org_id)
    on delete cascade;

alter table public.package_services
  add constraint package_services_package_org_fkey
    foreign key (package_id, org_id)
    references public.service_packages(id, org_id)
    on delete cascade,
  add constraint package_services_service_org_fkey
    foreign key (service_id, org_id)
    references public.services(id, org_id)
    on delete restrict;

alter table public.services
  add constraint services_catalog_values_check check (
    btrim(name) <> ''
    and price >= 0
    and price_type in ('free', 'from', 'fixed', 'on_request')
    and duration_minutes between 15 and 480
    and buffer_minutes between 0 and 120
    and commission_pct between 0 and 100
    and (price_type not in ('free', 'on_request') or price = 0)
  );

alter table public.products
  add constraint products_catalog_values_check check (
    btrim(name) <> ''
    and price >= 0
    and cost_price >= 0
    and stock_qty >= 0
    and stock_alert >= 0
    and btrim(unit) <> ''
  );

alter table public.service_packages
  add constraint service_packages_catalog_values_check check (
    btrim(name) <> ''
    and price >= 0
    and sessions >= 1
    and validity_days >= 1
  );

create index if not exists package_services_org_package_idx
  on public.package_services(org_id, package_id);
create index if not exists package_services_org_service_idx
  on public.package_services(org_id, service_id);
create index if not exists products_org_category_idx
  on public.products(org_id, category_id);
