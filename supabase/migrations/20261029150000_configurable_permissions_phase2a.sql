-- Perfis e liberações configuráveis, fase 2a (spec 37): catálogo, equipe e marketing.
-- Encoding: UTF-8. Os padrões por papel não mudam (as listas fixas antigas eram exatamente
-- owner/admin/manager), então nada muda para ninguém até o estúdio ajustar.

-- 1. Funções do catálogo -------------------------------------------------------------------------
do $rewrite$
declare
  r record;
  v_def text;
  v_count integer;
begin
  for r in
    select * from (values
      ('archive_service_bundle', 'coalesce\(public\.auth_user_role\(p_org_id\), ''''\) not in \(''owner'',\s*''admin'',\s*''manager''\)'),
      ('duplicate_service_bundle', 'coalesce\(public\.auth_user_role\(p_org_id\), ''''\) not in \(''owner'',\s*''admin'',\s*''manager''\)'),
      ('restore_service_bundle', 'coalesce\(public\.auth_user_role\(p_org_id\), ''''\) not in \(''owner'',\s*''admin'',\s*''manager''\)'),
      ('upsert_service_bundle_atomic', 'coalesce\(public\.auth_user_role\(p_org_id\), ''''\) not in \(''owner'',\s*''admin'',\s*''manager''\)'),
      ('replace_service_staff_atomic', 'coalesce\(public\.auth_user_role\(p_org_id\), ''''\) not in \(''owner'',\s*''admin'',\s*''manager''\)'),
      ('upsert_catalog_service_atomic', 'coalesce\(public\.auth_user_role\(p_org_id\), ''''\) not in \(''owner'',\s*''admin'',\s*''manager''\)'),
      ('upsert_service_package_atomic', 'coalesce\(public\.auth_user_role\(p_org_id\), ''''\) not in \(''owner'',\s*''admin'',\s*''manager''\)')
    ) as t(fn, pattern)
  loop
    select pg_get_functiondef(p.oid) into v_def
    from pg_proc p
    where p.pronamespace = 'public'::regnamespace and p.proname = r.fn;
    if v_def is null then
      raise exception 'Funcao % nao encontrada', r.fn;
    end if;
    select count(*) into v_count from regexp_matches(v_def, r.pattern, 'g');
    if v_count <> 1 then
      raise exception 'Funcao %: padrao encontrado % vez(es), esperado 1', r.fn, v_count;
    end if;
    execute regexp_replace(v_def, r.pattern, 'not public.has_permission(p_org_id, ''catalogo.manage'')');
  end loop;
end;
$rewrite$;

-- 2. Políticas do catálogo (catalogo.manage) ---------------------------------------------------

drop policy if exists catalog_services_insert on public.services;
create policy catalog_services_insert on public.services for insert to authenticated
  with check (public.has_permission(org_id, 'catalogo.manage'));
drop policy if exists catalog_services_update on public.services;
create policy catalog_services_update on public.services for update to authenticated
  using (public.has_permission(org_id, 'catalogo.manage'))
  with check (public.has_permission(org_id, 'catalogo.manage'));
drop policy if exists catalog_services_delete on public.services;
create policy catalog_services_delete on public.services for delete to authenticated
  using (public.has_permission(org_id, 'catalogo.manage'));
drop policy if exists catalog_categories_insert on public.service_categories;
create policy catalog_categories_insert on public.service_categories for insert to authenticated
  with check (public.has_permission(org_id, 'catalogo.manage'));
drop policy if exists catalog_categories_update on public.service_categories;
create policy catalog_categories_update on public.service_categories for update to authenticated
  using (public.has_permission(org_id, 'catalogo.manage'))
  with check (public.has_permission(org_id, 'catalogo.manage'));
drop policy if exists catalog_categories_delete on public.service_categories;
create policy catalog_categories_delete on public.service_categories for delete to authenticated
  using (public.has_permission(org_id, 'catalogo.manage'));
drop policy if exists catalog_bundles_insert on public.service_bundles;
create policy catalog_bundles_insert on public.service_bundles for insert to authenticated
  with check (public.has_permission(org_id, 'catalogo.manage'));
drop policy if exists catalog_bundles_update on public.service_bundles;
create policy catalog_bundles_update on public.service_bundles for update to authenticated
  using (public.has_permission(org_id, 'catalogo.manage'))
  with check (public.has_permission(org_id, 'catalogo.manage'));
drop policy if exists catalog_bundle_items_insert on public.service_bundle_items;
create policy catalog_bundle_items_insert on public.service_bundle_items for insert to authenticated
  with check (public.has_permission(org_id, 'catalogo.manage'));
drop policy if exists catalog_bundle_items_update on public.service_bundle_items;
create policy catalog_bundle_items_update on public.service_bundle_items for update to authenticated
  using (public.has_permission(org_id, 'catalogo.manage'))
  with check (public.has_permission(org_id, 'catalogo.manage'));
drop policy if exists catalog_bundle_items_delete on public.service_bundle_items;
create policy catalog_bundle_items_delete on public.service_bundle_items for delete to authenticated
  using (public.has_permission(org_id, 'catalogo.manage'));
drop policy if exists catalog_packages_insert on public.service_packages;
create policy catalog_packages_insert on public.service_packages for insert to authenticated
  with check (public.has_permission(org_id, 'catalogo.manage'));
drop policy if exists catalog_packages_update on public.service_packages;
create policy catalog_packages_update on public.service_packages for update to authenticated
  using (public.has_permission(org_id, 'catalogo.manage'))
  with check (public.has_permission(org_id, 'catalogo.manage'));
drop policy if exists catalog_packages_delete on public.service_packages;
create policy catalog_packages_delete on public.service_packages for delete to authenticated
  using (public.has_permission(org_id, 'catalogo.manage'));
drop policy if exists catalog_package_services_insert on public.package_services;
create policy catalog_package_services_insert on public.package_services for insert to authenticated
  with check (public.has_permission(org_id, 'catalogo.manage'));
drop policy if exists catalog_package_services_update on public.package_services;
create policy catalog_package_services_update on public.package_services for update to authenticated
  using (public.has_permission(org_id, 'catalogo.manage'))
  with check (public.has_permission(org_id, 'catalogo.manage'));
drop policy if exists catalog_package_services_delete on public.package_services;
create policy catalog_package_services_delete on public.package_services for delete to authenticated
  using (public.has_permission(org_id, 'catalogo.manage'));
drop policy if exists catalog_service_staff_insert on public.service_staff;
create policy catalog_service_staff_insert on public.service_staff for insert to authenticated
  with check (public.has_permission(org_id, 'catalogo.manage'));
drop policy if exists catalog_service_staff_delete on public.service_staff;
create policy catalog_service_staff_delete on public.service_staff for delete to authenticated
  using (public.has_permission(org_id, 'catalogo.manage'));
drop policy if exists catalog_products_insert on public.products;
create policy catalog_products_insert on public.products for insert to authenticated
  with check (public.has_permission(org_id, 'catalogo.manage'));
drop policy if exists catalog_products_update on public.products;
create policy catalog_products_update on public.products for update to authenticated
  using (public.has_permission(org_id, 'catalogo.manage'))
  with check (public.has_permission(org_id, 'catalogo.manage'));
drop policy if exists catalog_products_delete on public.products;
create policy catalog_products_delete on public.products for delete to authenticated
  using (public.has_permission(org_id, 'catalogo.manage'));
drop policy if exists catalog_plans_insert on public.subscription_plans;
create policy catalog_plans_insert on public.subscription_plans for insert to authenticated
  with check (public.has_permission(org_id, 'catalogo.manage'));
drop policy if exists catalog_plans_update on public.subscription_plans;
create policy catalog_plans_update on public.subscription_plans for update to authenticated
  using (public.has_permission(org_id, 'catalogo.manage'))
  with check (public.has_permission(org_id, 'catalogo.manage'));
drop policy if exists catalog_plans_delete on public.subscription_plans;
create policy catalog_plans_delete on public.subscription_plans for delete to authenticated
  using (public.has_permission(org_id, 'catalogo.manage'));

-- 3. Equipe (equipe.manage) ------------------------------------------------------------------------
drop policy if exists "staff: admin gerencia" on public.staff_members;
create policy "staff: admin gerencia" on public.staff_members for all
  using (public.has_permission(org_id, 'equipe.manage'))
  with check (public.has_permission(org_id, 'equipe.manage'));

drop policy if exists "shifts: admin gerencia" on public.staff_shifts;
create policy "shifts: admin gerencia" on public.staff_shifts for all
  using (public.has_permission(org_id, 'equipe.manage'))
  with check (public.has_permission(org_id, 'equipe.manage'));

-- 4. Marketing (mensagens.configure) ---------------------------------------------------------------
drop policy if exists marketing_campaigns_manage on public.marketing_campaigns;
create policy marketing_campaigns_manage on public.marketing_campaigns for all
  using (public.has_permission(org_id, 'mensagens.configure'))
  with check (public.has_permission(org_id, 'mensagens.configure'));

drop policy if exists marketing_queue_manage on public.marketing_message_queue;
create policy marketing_queue_manage on public.marketing_message_queue for all
  using (public.has_permission(org_id, 'mensagens.configure'))
  with check (public.has_permission(org_id, 'mensagens.configure'));

drop policy if exists marketing_templates_manage on public.marketing_message_templates;
create policy marketing_templates_manage on public.marketing_message_templates for all
  using (public.has_permission(org_id, 'mensagens.configure'))
  with check (public.has_permission(org_id, 'mensagens.configure'));

drop policy if exists marketing_segments_manage on public.marketing_segments;
create policy marketing_segments_manage on public.marketing_segments for all
  using (public.has_permission(org_id, 'mensagens.configure'))
  with check (public.has_permission(org_id, 'mensagens.configure'));

drop policy if exists marketing_events_insert on public.marketing_message_events;
create policy marketing_events_insert on public.marketing_message_events for insert
  with check (public.has_permission(org_id, 'mensagens.configure'));
