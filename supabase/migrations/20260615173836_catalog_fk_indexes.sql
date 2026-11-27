-- Cover tenant-aware catalog foreign keys in their constraint column order.
-- Encoding: UTF-8

create index if not exists package_services_package_org_idx
  on public.package_services(package_id, org_id);
create index if not exists package_services_service_org_idx
  on public.package_services(service_id, org_id);
create index if not exists products_category_org_idx
  on public.products(category_id, org_id);
create index if not exists services_category_org_idx
  on public.services(category_id, org_id);
create index if not exists services_anamnese_template_org_idx
  on public.services(anamnese_template_id, org_id);
create index if not exists service_staff_service_org_idx
  on public.service_staff(service_id, org_id);
create index if not exists service_staff_staff_org_idx
  on public.service_staff(staff_id, org_id);
