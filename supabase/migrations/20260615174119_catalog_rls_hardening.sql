-- CAT-01: catalog read access for members and writes for management roles.
-- Encoding: UTF-8

do $$
declare
  catalog_table text;
  catalog_policy record;
begin
  foreach catalog_table in array array[
    'service_categories',
    'services',
    'products',
    'service_packages',
    'package_services',
    'service_staff',
    'subscription_plans'
  ]
  loop
    for catalog_policy in
      select policyname
      from pg_policies
      where schemaname = 'public'
        and tablename = catalog_table
    loop
      execute format('drop policy %I on public.%I', catalog_policy.policyname, catalog_table);
    end loop;
  end loop;
end;
$$;

create policy catalog_categories_select on public.service_categories
  for select to authenticated
  using (org_id in (select public.auth_org_ids()));
create policy catalog_categories_insert on public.service_categories
  for insert to authenticated
  with check (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));
create policy catalog_categories_update on public.service_categories
  for update to authenticated
  using (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'))
  with check (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));
create policy catalog_categories_delete on public.service_categories
  for delete to authenticated
  using (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));

create policy catalog_services_select on public.services
  for select to authenticated
  using (org_id in (select public.auth_org_ids()));
create policy catalog_services_insert on public.services
  for insert to authenticated
  with check (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));
create policy catalog_services_update on public.services
  for update to authenticated
  using (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'))
  with check (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));
create policy catalog_services_delete on public.services
  for delete to authenticated
  using (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));

create policy catalog_products_select on public.products
  for select to authenticated
  using (org_id in (select public.auth_org_ids()));
create policy catalog_products_insert on public.products
  for insert to authenticated
  with check (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));
create policy catalog_products_update on public.products
  for update to authenticated
  using (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'))
  with check (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));
create policy catalog_products_delete on public.products
  for delete to authenticated
  using (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));

create policy catalog_packages_select on public.service_packages
  for select to authenticated
  using (org_id in (select public.auth_org_ids()));
create policy catalog_packages_insert on public.service_packages
  for insert to authenticated
  with check (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));
create policy catalog_packages_update on public.service_packages
  for update to authenticated
  using (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'))
  with check (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));
create policy catalog_packages_delete on public.service_packages
  for delete to authenticated
  using (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));

create policy catalog_package_services_select on public.package_services
  for select to authenticated
  using (org_id in (select public.auth_org_ids()));
create policy catalog_package_services_insert on public.package_services
  for insert to authenticated
  with check (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));
create policy catalog_package_services_update on public.package_services
  for update to authenticated
  using (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'))
  with check (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));
create policy catalog_package_services_delete on public.package_services
  for delete to authenticated
  using (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));

create policy catalog_service_staff_select on public.service_staff
  for select to authenticated
  using (org_id in (select public.auth_org_ids()));
create policy catalog_service_staff_insert on public.service_staff
  for insert to authenticated
  with check (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));
create policy catalog_service_staff_delete on public.service_staff
  for delete to authenticated
  using (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));

create policy catalog_plans_select on public.subscription_plans
  for select to authenticated
  using (org_id in (select public.auth_org_ids()));
create policy catalog_plans_insert on public.subscription_plans
  for insert to authenticated
  with check (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));
create policy catalog_plans_update on public.subscription_plans
  for update to authenticated
  using (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'))
  with check (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));
create policy catalog_plans_delete on public.subscription_plans
  for delete to authenticated
  using (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));

grant select, insert, update, delete on public.service_categories to authenticated;
grant select, insert, update, delete on public.services to authenticated;
grant select, insert, update, delete on public.products to authenticated;
grant select, insert, update, delete on public.service_packages to authenticated;
grant select, insert, update, delete on public.package_services to authenticated;
grant select, insert, delete on public.service_staff to authenticated;
grant select, insert, update, delete on public.subscription_plans to authenticated;
