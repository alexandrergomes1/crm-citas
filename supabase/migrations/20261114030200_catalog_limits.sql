-- Catálogo: limites de texto e valor também na tabela (CHECK), não só nas funções. Quem grava pela API direto
-- (UPDATE/INSERT com a liberação catalogo.manage) e as funções antigas passam a respeitar os mesmos tetos:
-- nome até 200 caracteres, descrição até 2000, preço (e custo) até 100000.
-- NOT VALID primeiro e VALIDATE logo depois, que confere as linhas que já existem. Tudo roda na MESMA transação da migration,
-- então o ADD CONSTRAINT segura o bloqueio da tabela até o fim; aqui é aceitável porque as tabelas do catálogo são pequenas
-- (centenas de linhas por estúdio). Em tabela grande seria preciso separar o VALIDATE em outra transação.
-- Encoding: UTF-8
set client_encoding = 'UTF8';

alter table public.services
  add constraint services_limits_check check (
    pg_catalog.char_length(name) <= 200 and (description is null or pg_catalog.char_length(description) <= 2000)
    and price <= 100000
  ) not valid;
alter table public.services validate constraint services_limits_check;

alter table public.products
  add constraint products_limits_check check (
    pg_catalog.char_length(name) <= 200 and (description is null or pg_catalog.char_length(description) <= 2000)
    and price <= 100000 and cost_price <= 100000
  ) not valid;
alter table public.products validate constraint products_limits_check;

alter table public.service_packages
  add constraint service_packages_limits_check check (
    pg_catalog.char_length(name) <= 200 and (description is null or pg_catalog.char_length(description) <= 2000)
    and price <= 100000
  ) not valid;
alter table public.service_packages validate constraint service_packages_limits_check;

alter table public.subscription_plans
  add constraint subscription_plans_limits_check check (
    pg_catalog.char_length(name) <= 200 and (description is null or pg_catalog.char_length(description) <= 2000)
    and price <= 100000
  ) not valid;
alter table public.subscription_plans validate constraint subscription_plans_limits_check;

alter table public.service_bundles
  add constraint service_bundles_limits_check check (
    pg_catalog.char_length(name) <= 200 and (description is null or pg_catalog.char_length(description) <= 2000)
    and price <= 100000
  ) not valid;
alter table public.service_bundles validate constraint service_bundles_limits_check;

alter table public.service_bundle_items
  add constraint service_bundle_items_limits_check check (allocated_price <= 100000) not valid;
alter table public.service_bundle_items validate constraint service_bundle_items_limits_check;
