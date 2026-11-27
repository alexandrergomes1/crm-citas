-- Permissões pendentes (estado.md), parte 4: a leitura e a gravação direta pela API seguem a permissão.
-- Encoding: UTF-8
set client_encoding = 'UTF8';
--
-- (a) clients: ler exige clientes.view (antes: qualquer pessoa do estúdio). Padrão de 20261114050300: a permissão é
--     conferida UMA vez por consulta (auth_orgs_with_permission), não uma vez por linha. As telas de outros módulos
--     (Agenda, Comanda, Financeiro, Mensagens, Marketing, Fidelidade, Ajustes) leem por internal_read (partes 1 e 2).
-- (b) client_entitlement_entries: ninguém grava direto pela API (antes: qualquer papel do estúdio). As gravações são por
--     função DEFINER (devolver sessão exige comanda.operate; checkout e estorno).
-- (c) catálogo (serviços, categorias, produtos, pacotes e seus serviços, combos e seus itens, planos, estoque e
--     profissionais do serviço): ler exige catalogo.view (ou catalogo.manage: quem grava o catálogo lê o que grava;
--     há perfis com catalogo.manage sem catalogo.view, teste 152). A comissão do serviço (commission_pct), o custo do serviço
--     (cost_amount) e o custo do produto (cost_price) saem da leitura direta (privilégio de coluna): só por função,
--     e catalog_screen os devolve só para catalogo.manage ou financeiro.view (parte 3).
--     Consequência: "select *" pela API em services/products passa a dar erro de permissão; o app pede colunas.
--     Coluna nova em services ou products precisa de "grant select (coluna)" (se não for custo) e de recriar a
--     visão internal_read correspondente.
-- As políticas de gravação não mudam (catalogo.manage, clientes.manage...).

-- ─── (a) Clientes ────────────────────────────────────────────────────────────────────────────────
drop policy if exists "clients: ver" on public.clients;
create policy "clients: ver" on public.clients for select to authenticated
  using (org_id in (select public.auth_orgs_with_permission('clientes.view')));
-- A trava FOR SHARE de quem agenda sem editar a cliente (agenda.manage) agora é agenda_lock_client (DEFINER).
drop policy if exists "clients: travar na agenda" on public.clients;

-- ─── (b) Movimentos do pacote ───────────────────────────────────────────────────────────────────
-- Ninguém da API grava direto: o app só grava por função. Devolver sessão (a única função INVOKER que gravava) passa a
-- SECURITY DEFINER com login, estúdio e comanda.operate conferidos dentro (20261114130400); checkout e estorno já eram.
drop policy if exists entitlement_entries_insert on public.client_entitlement_entries;
revoke insert, update, delete, truncate on public.client_entitlement_entries from anon, authenticated;

-- ─── (c) Catálogo: leitura ─────────────────────────────────────────────────────────────────────
drop policy if exists catalog_services_select on public.services;
create policy catalog_services_select on public.services for select to authenticated
  using (org_id in (select public.auth_orgs_with_permission('catalogo.view'))
         or org_id in (select public.auth_orgs_with_permission('catalogo.manage')));

drop policy if exists catalog_categories_select on public.service_categories;
create policy catalog_categories_select on public.service_categories for select to authenticated
  using (org_id in (select public.auth_orgs_with_permission('catalogo.view'))
         or org_id in (select public.auth_orgs_with_permission('catalogo.manage')));

drop policy if exists catalog_products_select on public.products;
create policy catalog_products_select on public.products for select to authenticated
  using (org_id in (select public.auth_orgs_with_permission('catalogo.view'))
         or org_id in (select public.auth_orgs_with_permission('catalogo.manage')));

drop policy if exists catalog_packages_select on public.service_packages;
create policy catalog_packages_select on public.service_packages for select to authenticated
  using (org_id in (select public.auth_orgs_with_permission('catalogo.view'))
         or org_id in (select public.auth_orgs_with_permission('catalogo.manage')));

drop policy if exists catalog_package_services_select on public.package_services;
create policy catalog_package_services_select on public.package_services for select to authenticated
  using (org_id in (select public.auth_orgs_with_permission('catalogo.view'))
         or org_id in (select public.auth_orgs_with_permission('catalogo.manage')));

drop policy if exists catalog_bundles_select on public.service_bundles;
create policy catalog_bundles_select on public.service_bundles for select to authenticated
  using (org_id in (select public.auth_orgs_with_permission('catalogo.view'))
         or org_id in (select public.auth_orgs_with_permission('catalogo.manage')));

drop policy if exists catalog_bundle_items_select on public.service_bundle_items;
create policy catalog_bundle_items_select on public.service_bundle_items for select to authenticated
  using (org_id in (select public.auth_orgs_with_permission('catalogo.view'))
         or org_id in (select public.auth_orgs_with_permission('catalogo.manage')));

drop policy if exists catalog_plans_select on public.subscription_plans;
create policy catalog_plans_select on public.subscription_plans for select to authenticated
  using (org_id in (select public.auth_orgs_with_permission('catalogo.view'))
         or org_id in (select public.auth_orgs_with_permission('catalogo.manage')));

drop policy if exists stock_entries_select on public.stock_entries;
create policy stock_entries_select on public.stock_entries for select to authenticated
  using (org_id in (select public.auth_orgs_with_permission('catalogo.view'))
         or org_id in (select public.auth_orgs_with_permission('catalogo.manage')));

drop policy if exists catalog_service_staff_select on public.service_staff;
create policy catalog_service_staff_select on public.service_staff for select to authenticated
  using (org_id in (select public.auth_orgs_with_permission('catalogo.view'))
         or org_id in (select public.auth_orgs_with_permission('catalogo.manage')));

-- ─── (c) Catálogo: comissão e custos fora da leitura direta ───────────────────────────────────────
revoke select on public.services from anon, authenticated;
grant select (id, org_id, category_id, name, description, price, price_type, duration_minutes, buffer_minutes,
              requires_anamnese, anamnese_template_id, online_booking, position, active, created_at, updated_at,
              result_months, retouch_included_days, deposit_type, deposit_value)
  on public.services to authenticated;

revoke select on public.products from anon, authenticated;
grant select (id, org_id, name, description, price, sku, barcode, stock_qty, stock_alert, category_id, brand, unit,
              online_booking, active, position, created_at, updated_at)
  on public.products to authenticated;
