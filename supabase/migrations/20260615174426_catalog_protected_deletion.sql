-- Prevent direct API deletes from erasing catalog items with operational history.
-- Encoding: UTF-8

create or replace function public.prevent_used_catalog_item_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_table_name = 'services' and (
    exists (
      select 1 from public.appointment_items
      where org_id = old.org_id and type = 'service' and ref_id = old.id
    )
    or exists (
      select 1 from public.sale_items
      where org_id = old.org_id and item_type = 'SERVICE' and item_id = old.id
    )
    or exists (
      select 1 from public.package_services
      where org_id = old.org_id and service_id = old.id
    )
  ) then
    raise exception 'service has operational references; archive it instead'
      using errcode = '23503';
  end if;

  if tg_table_name = 'products' and (
    exists (
      select 1 from public.sale_items
      where org_id = old.org_id and item_type = 'PRODUCT' and item_id = old.id
    )
    or exists (
      select 1 from public.stock_entries
      where org_id = old.org_id and product_id = old.id
    )
  ) then
    raise exception 'product has operational references; archive it instead'
      using errcode = '23503';
  end if;

  if tg_table_name = 'service_packages' and (
    exists (
      select 1 from public.sale_items
      where org_id = old.org_id and item_type = 'PACKAGE' and item_id = old.id
    )
    or exists (
      select 1 from public.client_entitlements
      where org_id = old.org_id and package_id = old.id
    )
  ) then
    raise exception 'package has operational references; archive it instead'
      using errcode = '23503';
  end if;

  return old;
end;
$$;

drop trigger if exists protect_used_service_delete on public.services;
create trigger protect_used_service_delete
  before delete on public.services
  for each row execute function public.prevent_used_catalog_item_delete();

drop trigger if exists protect_used_product_delete on public.products;
create trigger protect_used_product_delete
  before delete on public.products
  for each row execute function public.prevent_used_catalog_item_delete();

drop trigger if exists protect_used_package_delete on public.service_packages;
create trigger protect_used_package_delete
  before delete on public.service_packages
  for each row execute function public.prevent_used_catalog_item_delete();

revoke all on function public.prevent_used_catalog_item_delete() from public, anon, authenticated;
