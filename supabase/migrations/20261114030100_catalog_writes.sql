-- Catálogo: ações em UMA ida ao banco cada, tudo-ou-nada (porte para o TanStack Start, orçamento de chamadas).
-- Antes (beauty-system): excluir serviço fazia 5 idas (acesso, 3 contagens, exclusão); duplicar serviço, produto,
-- pacote ou plano 3; duplicar combo 4 (cópia + desligar); reordenar N idas (uma por serviço); plano 4 (acesso,
-- conferir serviços, gravar). Agora cada ação é UMA função.
-- Todas SECURITY INVOKER: a RLS das tabelas do catálogo (catalogo.manage) continua valendo por baixo; cada função
-- confere a liberação (has_permission) ANTES de gravar, com mensagem em português, e a trava de linha (for update)
-- vale da leitura até a gravação.
-- Limites no banco: nome até 200 caracteres, descrição até 2000, preços até 100000, textos curtos até 60/80.
-- Auditoria (audit_logs): por GATILHO (no fim deste arquivo), não por função chamável: cobre estas funções, o UPDATE
-- direto pela API e as funções antigas. Preço, custo, comissão, sinal, estoque, ativo/arquivado, sessões e validade,
-- cobrança e serviços do plano e itens do combo; exclusão de serviço, produto, pacote, plano e combo.
-- Não mexe nas funções antigas (upsert_*_atomic etc.): o sistema atual continua usando.
-- Encoding: UTF-8
set client_encoding = 'UTF8';

-- ─── Categoria ─────────────────────────────────────────────────────────────────────────────────────
create or replace function public.catalog_save_category(
  p_org_id uuid, p_category_id uuid, p_name text, p_color text, p_icon text, p_position integer default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_name text := pg_catalog.btrim(coalesce(p_name, ''));
  v_id uuid;
begin
  if not public.has_permission(p_org_id, 'catalogo.manage') then
    raise exception 'Sem permissão para gerenciar o catálogo.' using errcode = '42501';
  end if;
  if v_name = '' or pg_catalog.char_length(v_name) > 80 then
    raise exception 'O nome da categoria vai de 1 a 80 caracteres.' using errcode = '22023';
  end if;
  if p_color is null or p_color !~ '^#[0-9a-fA-F]{6}$' then
    raise exception 'Cor da categoria inválida.' using errcode = '22023';
  end if;
  if pg_catalog.char_length(coalesce(p_icon, '')) > 4 then
    raise exception 'Ícone da categoria inválido.' using errcode = '22023';
  end if;
  if p_position is not null and p_position not between 0 and 10000 then
    raise exception 'Posição da categoria inválida.' using errcode = '22023';
  end if;

  if p_category_id is null then
    insert into public.service_categories (org_id, name, color, icon, position, active)
    values (p_org_id, v_name, p_color, nullif(p_icon, ''), coalesce(p_position, 0), true)
    returning id into v_id;
  else
    update public.service_categories
    set name = v_name, color = p_color, icon = nullif(p_icon, '')
    where id = p_category_id and org_id = p_org_id
    returning id into v_id;
    if v_id is null then
      raise exception 'Categoria não encontrada.' using errcode = 'P0002';
    end if;
  end if;
  return v_id;
end;
$$;

-- ─── Serviço (dados, regras e profissionais juntos) ────────────────────────────────────────────────
create or replace function public.catalog_save_service(
  p_org_id uuid,
  p_service_id uuid,
  p_category_id uuid,
  p_name text,
  p_description text,
  p_price numeric,
  p_price_type text,
  p_duration_minutes integer,
  p_buffer_minutes integer,
  p_commission_pct numeric,
  p_requires_anamnese boolean,
  p_anamnese_template_id uuid,
  p_online_booking boolean,
  p_active boolean,
  p_staff_ids uuid[],
  p_rules jsonb default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_name text := pg_catalog.btrim(coalesce(p_name, ''));
  v_desc text := nullif(pg_catalog.btrim(coalesce(p_description, '')), '');
  v_staff uuid[];
  v_price numeric(10,2);
  v_online boolean;
  v_has_rules boolean := p_rules is not null;
  v_req boolean := coalesce(p_requires_anamnese, false);
  v_result integer;
  v_retouch integer;
  v_dep_type text;
  v_dep_value numeric(10,2);
  v_old public.services;
  v_id uuid;
begin
  if not public.has_permission(p_org_id, 'catalogo.manage') then
    raise exception 'Sem permissão para gerenciar o catálogo.' using errcode = '42501';
  end if;
  if v_name = '' or pg_catalog.char_length(v_name) > 200 then
    raise exception 'O nome do serviço vai de 1 a 200 caracteres.' using errcode = '22023';
  end if;
  if pg_catalog.char_length(coalesce(v_desc, '')) > 2000 then
    raise exception 'A descrição do serviço passa de 2000 caracteres.' using errcode = '22023';
  end if;
  if p_price is null or p_price < 0 or p_price > 100000 then
    raise exception 'O preço do serviço vai de 0 a 100000.' using errcode = '22023';
  end if;
  if p_price_type is null or p_price_type not in ('free', 'from', 'fixed', 'on_request') then
    raise exception 'Tipo de preço inválido.' using errcode = '22023';
  end if;
  if p_duration_minutes is null or (p_duration_minutes <> 0 and p_duration_minutes not between 15 and 480) then
    raise exception 'Duração de 15 minutos a 8 horas, ou sem duração.' using errcode = '22023';
  end if;
  if p_buffer_minutes is null or p_buffer_minutes not between 0 and 120 then
    raise exception 'O intervalo vai de 0 a 120 minutos.' using errcode = '22023';
  end if;
  if p_commission_pct is null or p_commission_pct not between 0 and 100 then
    raise exception 'A comissão vai de 0 a 100.' using errcode = '22023';
  end if;
  if v_req and p_anamnese_template_id is null then
    raise exception 'Escolha o modelo da ficha de anamnese para este serviço.' using errcode = '22023';
  end if;
  if p_category_id is not null and not exists (
    select 1 from public.service_categories c where c.id = p_category_id and c.org_id = p_org_id) then
    raise exception 'Categoria não encontrada neste estúdio.' using errcode = 'P0002';
  end if;
  if p_anamnese_template_id is not null and not exists (
    select 1 from public.anamnese_templates t where t.id = p_anamnese_template_id and t.org_id = p_org_id) then
    raise exception 'Modelo de ficha não encontrado neste estúdio.' using errcode = 'P0002';
  end if;
  select pg_catalog.array_agg(distinct s) into v_staff from pg_catalog.unnest(coalesce(p_staff_ids, '{}'::uuid[])) s;
  if pg_catalog.cardinality(coalesce(v_staff, '{}'::uuid[])) > 500 then
    raise exception 'Profissionais demais neste serviço.' using errcode = '22023';
  end if;
  if (select pg_catalog.count(*) from public.staff_members m
      where m.org_id = p_org_id and m.id = any (coalesce(v_staff, '{}'::uuid[])))
     <> pg_catalog.cardinality(coalesce(v_staff, '{}'::uuid[])) then
    raise exception 'Profissional não encontrado neste estúdio.' using errcode = 'P0002';
  end if;
  if v_has_rules then
    if pg_catalog.jsonb_typeof(p_rules) <> 'object' then
      raise exception 'Regras do serviço inválidas.' using errcode = '22023';
    end if;
    v_result := nullif(p_rules ->> 'result_months', '')::integer;
    v_retouch := nullif(p_rules ->> 'retouch_included_days', '')::integer;
    v_dep_type := nullif(p_rules ->> 'deposit_type', '');
    v_dep_value := case when v_dep_type is null then null else nullif(p_rules ->> 'deposit_value', '')::numeric end;
    if (v_result is not null and v_result not between 1 and 120)
       or (v_retouch is not null and v_retouch not between 1 and 365)
       or (v_dep_type is not null and v_dep_type not in ('fixed', 'percent'))
       or (v_dep_type is not null and (v_dep_value is null or v_dep_value <= 0
           or v_dep_value > case v_dep_type when 'percent' then 100 else 100000 end)) then
      raise exception 'Regras do serviço inválidas (durabilidade, retoque ou sinal).' using errcode = '22023';
    end if;
  end if;

  v_price := case when p_price_type in ('free', 'on_request') then 0 else p_price end;
  -- Sem duração não vai para a reserva online.
  v_online := coalesce(p_online_booking, false) and p_duration_minutes > 0;

  if p_service_id is null and v_dep_type = 'fixed' and v_dep_value > v_price then
    raise exception 'O sinal não pode passar do preço do serviço.' using errcode = '22023';
  end if;

  if p_service_id is null then
    insert into public.services (
      org_id, category_id, name, description, price, price_type, cost_amount, duration_minutes, buffer_minutes,
      requires_anamnese, anamnese_template_id, online_booking, commission_pct, position, active,
      result_months, retouch_included_days, deposit_type, deposit_value
    ) values (
      p_org_id, p_category_id, v_name, v_desc, v_price, p_price_type, 0, p_duration_minutes, p_buffer_minutes,
      v_req, p_anamnese_template_id, v_online, p_commission_pct, 0, coalesce(p_active, true),
      v_result, v_retouch, v_dep_type, v_dep_value
    ) returning id into v_id;
  else
    select * into v_old from public.services s where s.id = p_service_id and s.org_id = p_org_id for update;
    if not found then
      raise exception 'Serviço não encontrado.' using errcode = 'P0002';
    end if;
    if (case when v_has_rules then v_dep_type else v_old.deposit_type end) = 'fixed'
       and (case when v_has_rules then v_dep_value else v_old.deposit_value end) > v_price then
      raise exception 'O sinal não pode passar do preço do serviço.' using errcode = '22023';
    end if;
    update public.services set
      category_id = p_category_id, name = v_name, description = v_desc, price = v_price, price_type = p_price_type,
      duration_minutes = p_duration_minutes, buffer_minutes = p_buffer_minutes,
      requires_anamnese = v_req, anamnese_template_id = p_anamnese_template_id,
      online_booking = v_online, commission_pct = p_commission_pct, active = coalesce(p_active, true),
      result_months = case when v_has_rules then v_result else result_months end,
      retouch_included_days = case when v_has_rules then v_retouch else retouch_included_days end,
      deposit_type = case when v_has_rules then v_dep_type else deposit_type end,
      deposit_value = case when v_has_rules then v_dep_value else deposit_value end
    where id = p_service_id and org_id = p_org_id
    returning id into v_id;

  end if;

  delete from public.service_staff where service_id = v_id and org_id = p_org_id;
  insert into public.service_staff (service_id, staff_id, org_id)
  select v_id, s, p_org_id from pg_catalog.unnest(coalesce(v_staff, '{}'::uuid[])) s;
  return v_id;
end;
$$;

-- ─── Pacote (dados e serviços juntos) ──────────────────────────────────────────────────────────────
create or replace function public.catalog_save_package(
  p_org_id uuid,
  p_package_id uuid,
  p_name text,
  p_description text,
  p_price numeric,
  p_sessions integer,
  p_validity_days integer,
  p_online_booking boolean,
  p_active boolean,
  p_service_ids uuid[]
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_name text := pg_catalog.btrim(coalesce(p_name, ''));
  v_desc text := nullif(pg_catalog.btrim(coalesce(p_description, '')), '');
  v_services uuid[];
  v_old public.service_packages;
  v_id uuid;
begin
  if not public.has_permission(p_org_id, 'catalogo.manage') then
    raise exception 'Sem permissão para gerenciar o catálogo.' using errcode = '42501';
  end if;
  if v_name = '' or pg_catalog.char_length(v_name) > 200 then
    raise exception 'O nome do pacote vai de 1 a 200 caracteres.' using errcode = '22023';
  end if;
  if pg_catalog.char_length(coalesce(v_desc, '')) > 2000 then
    raise exception 'A descrição do pacote passa de 2000 caracteres.' using errcode = '22023';
  end if;
  if p_price is null or p_price < 0 or p_price > 100000 then
    raise exception 'O preço do pacote vai de 0 a 100000.' using errcode = '22023';
  end if;
  if p_sessions is null or p_sessions not between 1 and 999 then
    raise exception 'O pacote tem de 1 a 999 sessões.' using errcode = '22023';
  end if;
  if p_validity_days is null or p_validity_days not between 1 and 3650 then
    raise exception 'A validade do pacote vai de 1 a 3650 dias.' using errcode = '22023';
  end if;
  select pg_catalog.array_agg(distinct s) into v_services from pg_catalog.unnest(coalesce(p_service_ids, '{}'::uuid[])) s;
  if v_services is null then
    raise exception 'Selecione ao menos um serviço.' using errcode = '22023';
  end if;
  if pg_catalog.cardinality(v_services) > 500 then
    raise exception 'Serviços demais neste pacote.' using errcode = '22023';
  end if;
  if (select pg_catalog.count(*) from public.services s where s.org_id = p_org_id and s.id = any (v_services))
     <> pg_catalog.cardinality(v_services) then
    raise exception 'Serviço não encontrado neste estúdio.' using errcode = 'P0002';
  end if;
  -- Serviço arquivado não entra de novo (quem já estava no pacote pode continuar até a pessoa tirar).
  if exists (
    select 1 from public.services s
    where s.org_id = p_org_id and s.id = any (v_services) and not s.active
      and (p_package_id is null or not exists (
        select 1 from public.package_services ps where ps.package_id = p_package_id and ps.service_id = s.id))
  ) then
    raise exception 'Há serviço arquivado na lista: reative-o ou tire-o do pacote.' using errcode = '22023';
  end if;

  if p_package_id is null then
    insert into public.service_packages (org_id, name, description, price, sessions, validity_days, online_booking, active, position)
    values (p_org_id, v_name, v_desc, p_price, p_sessions, p_validity_days, coalesce(p_online_booking, false), coalesce(p_active, true), 0)
    returning id into v_id;
  else
    select * into v_old from public.service_packages p where p.id = p_package_id and p.org_id = p_org_id for update;
    if not found then
      raise exception 'Pacote não encontrado.' using errcode = 'P0002';
    end if;
    update public.service_packages
    set name = v_name, description = v_desc, price = p_price, sessions = p_sessions, validity_days = p_validity_days,
        online_booking = coalesce(p_online_booking, false), active = coalesce(p_active, true)
    where id = p_package_id and org_id = p_org_id
    returning id into v_id;
  end if;

  delete from public.package_services where package_id = v_id and org_id = p_org_id;
  insert into public.package_services (org_id, package_id, service_id, qty)
  select p_org_id, v_id, s, 1 from pg_catalog.unnest(v_services) s;
  return v_id;
end;
$$;

-- ─── Combo (dados e itens juntos; o total dos itens fecha com o preço) ─────────────────────────────
create or replace function public.catalog_save_bundle(
  p_org_id uuid,
  p_bundle_id uuid,
  p_name text,
  p_description text,
  p_category_id uuid,
  p_price numeric,
  p_active boolean,
  p_position integer,
  p_items jsonb
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_name text := pg_catalog.btrim(coalesce(p_name, ''));
  v_desc text := nullif(pg_catalog.btrim(coalesce(p_description, '')), '');
  v_count integer;
  v_distinct integer;
  v_total numeric;
  v_old public.service_bundles;
  v_id uuid;
begin
  if not public.has_permission(p_org_id, 'catalogo.manage') then
    raise exception 'Sem permissão para gerenciar o catálogo.' using errcode = '42501';
  end if;
  if v_name = '' or pg_catalog.char_length(v_name) > 200 then
    raise exception 'O nome do combo vai de 1 a 200 caracteres.' using errcode = '22023';
  end if;
  if pg_catalog.char_length(coalesce(v_desc, '')) > 2000 then
    raise exception 'A descrição do combo passa de 2000 caracteres.' using errcode = '22023';
  end if;
  if p_price is null or p_price < 0 or p_price > 100000 then
    raise exception 'O preço do combo vai de 0 a 100000.' using errcode = '22023';
  end if;
  if p_position is null or p_position not between 0 and 10000 then
    raise exception 'Posição do combo inválida.' using errcode = '22023';
  end if;
  if p_items is null or pg_catalog.jsonb_typeof(p_items) <> 'array' or pg_catalog.jsonb_array_length(p_items) > 50 then
    raise exception 'Itens do combo inválidos.' using errcode = '22023';
  end if;
  if p_category_id is not null and not exists (
    select 1 from public.service_categories c where c.id = p_category_id and c.org_id = p_org_id) then
    raise exception 'Categoria não encontrada neste estúdio.' using errcode = 'P0002';
  end if;

  select pg_catalog.count(*), pg_catalog.count(distinct r.service_id),
         coalesce(pg_catalog.sum(r.quantity * r.allocated_price), 0)
  into v_count, v_distinct, v_total
  from pg_catalog.jsonb_to_recordset(p_items) as r(service_id uuid, quantity integer, allocated_price numeric);
  if v_distinct < 2 or v_distinct <> v_count then
    raise exception 'Selecione ao menos dois serviços diferentes.' using errcode = '22023';
  end if;
  if exists (
    select 1 from pg_catalog.jsonb_to_recordset(p_items) as r(service_id uuid, quantity integer, allocated_price numeric)
    where r.quantity is null or r.quantity not between 1 and 999
       or r.allocated_price is null or r.allocated_price < 0 or r.allocated_price > 100000
  ) then
    raise exception 'Quantidade ou preço de um serviço do combo inválido.' using errcode = '22023';
  end if;
  if pg_catalog.round(v_total, 2) <> pg_catalog.round(p_price, 2) then
    raise exception 'A soma dos preços dos serviços precisa fechar com o preço do combo.' using errcode = '22023';
  end if;
  if exists (
    select 1 from pg_catalog.jsonb_to_recordset(p_items) as r(service_id uuid, quantity integer, allocated_price numeric)
    where not exists (select 1 from public.services s where s.id = r.service_id and s.org_id = p_org_id)
  ) then
    raise exception 'Serviço não encontrado neste estúdio.' using errcode = 'P0002';
  end if;
  -- Serviço arquivado não entra de novo (quem já estava no combo pode continuar até a pessoa tirar).
  if exists (
    select 1 from pg_catalog.jsonb_to_recordset(p_items) as r(service_id uuid, quantity integer, allocated_price numeric)
    join public.services s on s.id = r.service_id and s.org_id = p_org_id
    where not s.active
      and (p_bundle_id is null or not exists (
        select 1 from public.service_bundle_items i where i.bundle_id = p_bundle_id and i.service_id = s.id))
  ) then
    raise exception 'Há serviço arquivado na lista: reative-o ou tire-o do combo.' using errcode = '22023';
  end if;

  -- Desativar o combo no editor ou desligá-lo na lista dá o mesmo estado: arquivado (archived_at), como
  -- bundleStatus em src/domain/catalog-bundles.ts (o estado "inativo" sem arquivo não é mais gerado por aqui).
  if p_bundle_id is null then
    insert into public.service_bundles (org_id, category_id, name, description, price, active, archived_at, position)
    values (p_org_id, p_category_id, v_name, v_desc, p_price, coalesce(p_active, true),
            case when coalesce(p_active, true) then null else pg_catalog.now() end, p_position)
    returning id into v_id;
  else
    select * into v_old from public.service_bundles b where b.id = p_bundle_id and b.org_id = p_org_id for update;
    if not found then
      raise exception 'Combo não encontrado.' using errcode = 'P0002';
    end if;
    update public.service_bundles
    set category_id = p_category_id, name = v_name, description = v_desc, price = p_price,
        active = coalesce(p_active, true), position = p_position,
        archived_at = case when coalesce(p_active, true) then null else coalesce(archived_at, pg_catalog.now()) end
    where id = p_bundle_id and org_id = p_org_id
    returning id into v_id;
  end if;

  -- Só mexe no que mudou (a auditoria por gatilho registra cada item tirado, posto ou com preço/quantidade novos).
  delete from public.service_bundle_items i
  where i.bundle_id = v_id and i.org_id = p_org_id
    and i.service_id not in (select r.service_id from pg_catalog.jsonb_to_recordset(p_items) as r(service_id uuid));
  insert into public.service_bundle_items (org_id, bundle_id, service_id, position, quantity, original_price_snapshot, allocated_price)
  select p_org_id, v_id, r.service_id,
         pg_catalog.row_number() over (order by r.position, r.service_id) - 1,
         r.quantity, s.price, r.allocated_price
  from pg_catalog.jsonb_to_recordset(p_items) as r(service_id uuid, position integer, quantity integer, allocated_price numeric)
  join public.services s on s.id = r.service_id and s.org_id = p_org_id
  on conflict (bundle_id, service_id) do update
    set position = excluded.position, quantity = excluded.quantity, allocated_price = excluded.allocated_price
    where (public.service_bundle_items.position, public.service_bundle_items.quantity, public.service_bundle_items.allocated_price)
      is distinct from (excluded.position, excluded.quantity, excluded.allocated_price);
  return v_id;
end;
$$;

-- ─── Produto (o estoque só muda por register_stock_entry_atomic; aqui só nasce com o inicial) ───────
create or replace function public.catalog_save_product(
  p_org_id uuid,
  p_product_id uuid,
  p_name text,
  p_description text,
  p_price numeric,
  p_cost_price numeric,
  p_sku text,
  p_barcode text,
  p_brand text,
  p_unit text,
  p_stock_qty integer,
  p_stock_alert integer,
  p_category_id uuid,
  p_online_booking boolean,
  p_active boolean
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_name text := pg_catalog.btrim(coalesce(p_name, ''));
  v_desc text := nullif(pg_catalog.btrim(coalesce(p_description, '')), '');
  v_sku text := nullif(pg_catalog.btrim(coalesce(p_sku, '')), '');
  v_barcode text := nullif(pg_catalog.btrim(coalesce(p_barcode, '')), '');
  v_brand text := nullif(pg_catalog.btrim(coalesce(p_brand, '')), '');
  v_unit text := pg_catalog.btrim(coalesce(p_unit, ''));
  v_old public.products;
  v_id uuid;
begin
  if not public.has_permission(p_org_id, 'catalogo.manage') then
    raise exception 'Sem permissão para gerenciar o catálogo.' using errcode = '42501';
  end if;
  if v_name = '' or pg_catalog.char_length(v_name) > 200 then
    raise exception 'O nome do produto vai de 1 a 200 caracteres.' using errcode = '22023';
  end if;
  if pg_catalog.char_length(coalesce(v_desc, '')) > 2000 then
    raise exception 'A descrição do produto passa de 2000 caracteres.' using errcode = '22023';
  end if;
  if p_price is null or p_price < 0 or p_price > 100000 or p_cost_price is null or p_cost_price < 0 or p_cost_price > 100000 then
    raise exception 'Preço e custo do produto vão de 0 a 100000.' using errcode = '22023';
  end if;
  if pg_catalog.char_length(coalesce(v_sku, '')) > 60 or pg_catalog.char_length(coalesce(v_barcode, '')) > 60
     or pg_catalog.char_length(coalesce(v_brand, '')) > 80 then
    raise exception 'Código, código de barras ou marca grande demais.' using errcode = '22023';
  end if;
  if v_unit = '' or pg_catalog.char_length(v_unit) > 10 then
    raise exception 'A unidade vai de 1 a 10 caracteres.' using errcode = '22023';
  end if;
  if p_stock_alert is null or p_stock_alert not between 0 and 1000000
     or (p_product_id is null and (p_stock_qty is null or p_stock_qty not between 0 and 1000000)) then
    raise exception 'Estoque inválido.' using errcode = '22023';
  end if;
  if p_category_id is not null and not exists (
    select 1 from public.service_categories c where c.id = p_category_id and c.org_id = p_org_id) then
    raise exception 'Categoria não encontrada neste estúdio.' using errcode = 'P0002';
  end if;

  if p_product_id is null then
    insert into public.products (org_id, name, description, price, cost_price, sku, barcode, brand, unit, stock_qty,
                                 stock_alert, category_id, online_booking, active, position)
    values (p_org_id, v_name, v_desc, p_price, p_cost_price, v_sku, v_barcode, v_brand, v_unit, p_stock_qty,
            p_stock_alert, p_category_id, coalesce(p_online_booking, false), coalesce(p_active, true), 0)
    returning id into v_id;
  else
    select * into v_old from public.products r where r.id = p_product_id and r.org_id = p_org_id for update;
    if not found then
      raise exception 'Produto não encontrado.' using errcode = 'P0002';
    end if;
    update public.products
    set name = v_name, description = v_desc, price = p_price, cost_price = p_cost_price, sku = v_sku,
        barcode = v_barcode, brand = v_brand, unit = v_unit, stock_alert = p_stock_alert, category_id = p_category_id,
        online_booking = coalesce(p_online_booking, false), active = coalesce(p_active, true)
    where id = p_product_id and org_id = p_org_id
    returning id into v_id;
  end if;
  return v_id;
end;
$$;

-- ─── Plano de assinatura (os serviços incluídos são conferidos e gravados juntos; vazio = todos) ────
create or replace function public.catalog_save_plan(
  p_org_id uuid,
  p_plan_id uuid,
  p_name text,
  p_description text,
  p_price numeric,
  p_billing_period text,
  p_sessions_per_period integer,
  p_service_ids uuid[],
  p_active boolean
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_name text := pg_catalog.btrim(coalesce(p_name, ''));
  v_desc text := nullif(pg_catalog.btrim(coalesce(p_description, '')), '');
  v_services uuid[];
  v_eligible jsonb;
  v_old public.subscription_plans;
  v_id uuid;
begin
  if not public.has_permission(p_org_id, 'catalogo.manage') then
    raise exception 'Sem permissão para gerenciar o catálogo.' using errcode = '42501';
  end if;
  if v_name = '' or pg_catalog.char_length(v_name) > 200 then
    raise exception 'O nome do plano vai de 1 a 200 caracteres.' using errcode = '22023';
  end if;
  if pg_catalog.char_length(coalesce(v_desc, '')) > 2000 then
    raise exception 'A descrição do plano passa de 2000 caracteres.' using errcode = '22023';
  end if;
  if p_price is null or p_price < 0 or p_price > 100000 then
    raise exception 'O preço do plano vai de 0 a 100000.' using errcode = '22023';
  end if;
  if p_billing_period is null or p_billing_period not in ('monthly', 'quarterly', 'annually') then
    raise exception 'Cobrança do plano inválida.' using errcode = '22023';
  end if;
  if p_sessions_per_period is null or p_sessions_per_period not between 1 and 999 then
    raise exception 'O plano tem de 1 a 999 sessões por período.' using errcode = '22023';
  end if;
  select pg_catalog.array_agg(distinct s) into v_services from pg_catalog.unnest(coalesce(p_service_ids, '{}'::uuid[])) s;
  if pg_catalog.cardinality(coalesce(v_services, '{}'::uuid[])) > 500 then
    raise exception 'Serviços demais neste plano.' using errcode = '22023';
  end if;
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('service_id', s.id, 'service_name', s.name, 'qty', 1)
                                       order by s.name, s.id), '[]'::jsonb)
  into v_eligible
  from public.services s where s.org_id = p_org_id and s.id = any (coalesce(v_services, '{}'::uuid[]));
  if pg_catalog.jsonb_array_length(v_eligible) <> pg_catalog.cardinality(coalesce(v_services, '{}'::uuid[])) then
    raise exception 'Um ou mais serviços do plano não pertencem a este estúdio.' using errcode = 'P0002';
  end if;

  if p_plan_id is null then
    insert into public.subscription_plans (org_id, name, description, price, billing_period, sessions_per_period,
                                           eligible_services, active)
    values (p_org_id, v_name, v_desc, p_price, p_billing_period, p_sessions_per_period, v_eligible, coalesce(p_active, true))
    returning id into v_id;
  else
    select * into v_old from public.subscription_plans l where l.id = p_plan_id and l.org_id = p_org_id for update;
    if not found then
      raise exception 'Plano não encontrado.' using errcode = 'P0002';
    end if;
    update public.subscription_plans
    set name = v_name, description = v_desc, price = p_price, billing_period = p_billing_period,
        sessions_per_period = p_sessions_per_period, eligible_services = v_eligible, active = coalesce(p_active, true)
    where id = p_plan_id and org_id = p_org_id
    returning id into v_id;
  end if;
  return v_id;
end;
$$;

-- ─── Ligar/desligar (ativo e reserva online) de serviço, pacote, produto, plano e combo ─────────────
-- p_kind: service | package | product | plan | bundle. Plano e combo não têm reserva online (p_online = null).
-- Combo: ativo = fora do arquivo; desligar arquiva (archived_at), ligar restaura. Salvar o combo como inativo no editor
-- (catalog_save_bundle) dá o MESMO estado (arquivado), como bundleStatus em src/domain/catalog-bundles.ts.
create or replace function public.catalog_set_flags(
  p_org_id uuid, p_kind text, p_id uuid, p_active boolean default null, p_online boolean default null
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_duration integer;
begin
  if not public.has_permission(p_org_id, 'catalogo.manage') then
    raise exception 'Sem permissão para gerenciar o catálogo.' using errcode = '42501';
  end if;
  if p_active is null and p_online is null then
    raise exception 'Nenhuma alteração informada.' using errcode = '22023';
  end if;
  if p_kind not in ('service', 'package', 'product', 'plan', 'bundle') then
    raise exception 'Tipo de item inválido.' using errcode = '22023';
  end if;
  if p_online is not null and p_kind in ('plan', 'bundle') then
    raise exception 'Este item não tem reserva online.' using errcode = '22023';
  end if;

  if p_kind = 'service' then
    select s.duration_minutes into v_duration from public.services s
    where s.id = p_id and s.org_id = p_org_id for update;
    if not found then raise exception 'Serviço não encontrado.' using errcode = 'P0002'; end if;
    if p_online and v_duration = 0 then
      raise exception 'Serviço sem duração não vai para a reserva online.' using errcode = '22023';
    end if;
    update public.services set active = coalesce(p_active, active), online_booking = coalesce(p_online, online_booking)
    where id = p_id and org_id = p_org_id;
  elsif p_kind = 'package' then
    perform 1 from public.service_packages s where s.id = p_id and s.org_id = p_org_id for update;
    if not found then raise exception 'Pacote não encontrado.' using errcode = 'P0002'; end if;
    update public.service_packages set active = coalesce(p_active, active), online_booking = coalesce(p_online, online_booking)
    where id = p_id and org_id = p_org_id;
  elsif p_kind = 'product' then
    perform 1 from public.products s where s.id = p_id and s.org_id = p_org_id for update;
    if not found then raise exception 'Produto não encontrado.' using errcode = 'P0002'; end if;
    update public.products set active = coalesce(p_active, active), online_booking = coalesce(p_online, online_booking)
    where id = p_id and org_id = p_org_id;
  elsif p_kind = 'plan' then
    perform 1 from public.subscription_plans s where s.id = p_id and s.org_id = p_org_id for update;
    if not found then raise exception 'Plano não encontrado.' using errcode = 'P0002'; end if;
    update public.subscription_plans set active = coalesce(p_active, active) where id = p_id and org_id = p_org_id;
  else
    perform 1 from public.service_bundles s where s.id = p_id and s.org_id = p_org_id for update;
    if not found then raise exception 'Combo não encontrado.' using errcode = 'P0002'; end if;
    if p_active is not null then
      update public.service_bundles
      set active = p_active, archived_at = case when p_active then null else coalesce(archived_at, pg_catalog.now()) end
      where id = p_id and org_id = p_org_id;
    end if;
  end if;

end;
$$;

-- ─── Excluir serviço ou produto: com histórico (atendimento, venda, pacote, combo, fila de espera, ficha, estoque) só arquiva ──
-- Devolve 'deleted' ou 'archived'. Antes: acesso + contagens + exclusão (5 idas).
-- Serviço dentro de combo ou pacote ATIVO: recusa (a pessoa tira de lá antes), em vez de arquivar sem avisar.
-- A fila de espera (agenda_waitlist.service_id) apaga em cascata: por isso conta como uso, como as fichas
-- (anamneses.source_service_id, que ficaria sem o serviço de origem).
create or replace function public.catalog_delete_item(p_org_id uuid, p_kind text, p_id uuid)
returns text
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_name text;
  v_where text;
  v_refs boolean;
begin
  if not public.has_permission(p_org_id, 'catalogo.manage') then
    raise exception 'Sem permissão para gerenciar o catálogo.' using errcode = '42501';
  end if;
  if p_kind not in ('service', 'product') then
    raise exception 'Tipo de item inválido.' using errcode = '22023';
  end if;

  if p_kind = 'service' then
    select s.name into v_name from public.services s
    where s.id = p_id and s.org_id = p_org_id for update;
    if not found then raise exception 'Serviço não encontrado.' using errcode = 'P0002'; end if;

    select b.name into v_where
    from public.service_bundle_items i
    join public.service_bundles b on b.id = i.bundle_id and b.org_id = i.org_id
    where i.org_id = p_org_id and i.service_id = p_id and b.active and b.archived_at is null
    order by b.name limit 1;
    if found then
      raise exception 'Está no combo "%": tire de lá antes.', v_where using errcode = '22023';
    end if;
    select k.name into v_where
    from public.package_services i
    join public.service_packages k on k.id = i.package_id and k.org_id = i.org_id
    where i.org_id = p_org_id and i.service_id = p_id and k.active
    order by k.name limit 1;
    if found then
      raise exception 'Está no pacote "%": tire de lá antes.', v_where using errcode = '22023';
    end if;
    -- Plano de assinatura: os serviços incluídos ficam num jsonb (sem chave estrangeira), então a conferência é pelo conteúdo.
    select pl.name into v_where
    from public.subscription_plans pl
    where pl.org_id = p_org_id and pl.active
      and pl.eligible_services @> pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('service_id', p_id::text))
    order by pl.name limit 1;
    if found then
      raise exception 'Está no plano "%": tire de lá antes.', v_where using errcode = '22023';
    end if;

    v_refs := exists (select 1 from public.appointment_items i where i.org_id = p_org_id and i.type = 'service' and i.ref_id = p_id)
      or exists (select 1 from public.sale_items i where i.org_id = p_org_id and pg_catalog.lower(i.item_type) = 'service' and i.item_id = p_id)
      or exists (select 1 from public.package_services i where i.org_id = p_org_id and i.service_id = p_id)
      or exists (select 1 from public.service_bundle_items i where i.org_id = p_org_id and i.service_id = p_id)
      or exists (select 1 from public.agenda_waitlist i where i.org_id = p_org_id and i.service_id = p_id)
      or exists (select 1 from public.anamneses i where i.org_id = p_org_id and i.source_service_id = p_id)
      or exists (select 1 from public.subscription_plans pl where pl.org_id = p_org_id
                 and pl.eligible_services @> pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('service_id', p_id::text)));
    if v_refs then
      update public.services set active = false where id = p_id and org_id = p_org_id;
      return 'archived';
    end if;
    delete from public.services where id = p_id and org_id = p_org_id;
    return 'deleted';
  end if;

  perform 1 from public.products s where s.id = p_id and s.org_id = p_org_id for update;
  if not found then raise exception 'Produto não encontrado.' using errcode = 'P0002'; end if;
  v_refs := exists (select 1 from public.sale_items i where i.org_id = p_org_id and pg_catalog.lower(i.item_type) = 'product' and i.item_id = p_id)
    or exists (select 1 from public.stock_entries i where i.org_id = p_org_id and i.product_id = p_id);
  if v_refs then
    update public.products set active = false where id = p_id and org_id = p_org_id;
    return 'archived';
  end if;
  delete from public.products where id = p_id and org_id = p_org_id;
  return 'deleted';
end;
$$;

-- ─── Duplicar (a cópia nasce fora da reserva online; menos o serviço, que nasce ativo, como antes) ────
-- p_kind: service | package | product | plan | bundle. Devolve o id da cópia.
create or replace function public.catalog_duplicate_item(p_org_id uuid, p_kind text, p_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if not public.has_permission(p_org_id, 'catalogo.manage') then
    raise exception 'Sem permissão para gerenciar o catálogo.' using errcode = '42501';
  end if;
  if p_kind not in ('service', 'package', 'product', 'plan', 'bundle') then
    raise exception 'Tipo de item inválido.' using errcode = '22023';
  end if;

  if p_kind = 'service' then
    insert into public.services (org_id, category_id, name, description, price, price_type, duration_minutes, buffer_minutes,
      commission_pct, online_booking, active, position, requires_anamnese, anamnese_template_id,
      result_months, retouch_included_days, deposit_type, deposit_value)
    select s.org_id, s.category_id, pg_catalog.left('Cópia de ' || s.name, 200), s.description, s.price, s.price_type,
      s.duration_minutes, s.buffer_minutes, s.commission_pct, false, true, s.position, s.requires_anamnese,
      s.anamnese_template_id, s.result_months, s.retouch_included_days, s.deposit_type, s.deposit_value
    from public.services s where s.id = p_id and s.org_id = p_org_id
    returning id into v_id;
    if v_id is null then raise exception 'Serviço não encontrado.' using errcode = 'P0002'; end if;
    insert into public.service_staff (service_id, staff_id, org_id)
    select v_id, ss.staff_id, ss.org_id from public.service_staff ss where ss.service_id = p_id and ss.org_id = p_org_id;
  elsif p_kind = 'package' then
    insert into public.service_packages (org_id, name, description, price, sessions, validity_days, online_booking, active, position)
    select s.org_id, pg_catalog.left('Cópia de ' || s.name, 200), s.description, s.price, s.sessions, s.validity_days, false, false, 0
    from public.service_packages s where s.id = p_id and s.org_id = p_org_id
    returning id into v_id;
    if v_id is null then raise exception 'Pacote não encontrado.' using errcode = 'P0002'; end if;
    insert into public.package_services (org_id, package_id, service_id, qty)
    select ps.org_id, v_id, ps.service_id, ps.qty from public.package_services ps
    where ps.package_id = p_id and ps.org_id = p_org_id;
  elsif p_kind = 'product' then
    insert into public.products (org_id, category_id, name, description, price, cost_price, sku, barcode, brand, unit,
      stock_qty, stock_alert, position, online_booking, active)
    select s.org_id, s.category_id, pg_catalog.left('Cópia de ' || s.name, 200), s.description, s.price, s.cost_price,
      null, null, s.brand, s.unit, 0, s.stock_alert, s.position, false, false
    from public.products s where s.id = p_id and s.org_id = p_org_id
    returning id into v_id;
    if v_id is null then raise exception 'Produto não encontrado.' using errcode = 'P0002'; end if;
  elsif p_kind = 'plan' then
    insert into public.subscription_plans (org_id, name, description, price, billing_period, sessions_per_period,
      eligible_services, position, online_booking, active)
    select s.org_id, pg_catalog.left('Cópia de ' || s.name, 200), s.description, s.price, s.billing_period,
      s.sessions_per_period, s.eligible_services, s.position, false, false
    from public.subscription_plans s where s.id = p_id and s.org_id = p_org_id
    returning id into v_id;
    if v_id is null then raise exception 'Plano não encontrado.' using errcode = 'P0002'; end if;
  else
    insert into public.service_bundles (org_id, category_id, name, description, price, active, position)
    select s.org_id, s.category_id, pg_catalog.left('Cópia de ' || s.name, 200), s.description, s.price, false, s.position + 1
    from public.service_bundles s where s.id = p_id and s.org_id = p_org_id
    returning id into v_id;
    if v_id is null then raise exception 'Combo não encontrado.' using errcode = 'P0002'; end if;
    insert into public.service_bundle_items (org_id, bundle_id, service_id, position, quantity, original_price_snapshot, allocated_price)
    select i.org_id, v_id, i.service_id, i.position, i.quantity, i.original_price_snapshot, i.allocated_price
    from public.service_bundle_items i where i.bundle_id = p_id and i.org_id = p_org_id;
  end if;
  return v_id;
end;
$$;

-- ─── Reordenar serviços (arrastar na lista) ────────────────────────────────────────────────────────
-- Antes: uma gravação por serviço (N idas). Agora uma só; a ordem recebida vira a posição 0, 1, 2...
create or replace function public.catalog_reorder_services(p_org_id uuid, p_ids uuid[])
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_ids uuid[] := coalesce(p_ids, '{}'::uuid[]);
begin
  if not public.has_permission(p_org_id, 'catalogo.manage') then
    raise exception 'Sem permissão para gerenciar o catálogo.' using errcode = '42501';
  end if;
  if pg_catalog.cardinality(v_ids) not between 1 and 1000
     or (select pg_catalog.count(distinct x) from pg_catalog.unnest(v_ids) x) <> pg_catalog.cardinality(v_ids) then
    raise exception 'Ordem inválida.' using errcode = '22023';
  end if;
  -- Trava na ordem do id: duas reordenações ao mesmo tempo esperam uma pela outra, sem impasse.
  perform 1 from public.services s where s.org_id = p_org_id and s.id = any (v_ids) order by s.id for update;
  if (select pg_catalog.count(*) from public.services s where s.org_id = p_org_id and s.id = any (v_ids))
     <> pg_catalog.cardinality(v_ids) then
    raise exception 'Serviço não encontrado.' using errcode = 'P0002';
  end if;
  update public.services s set position = t.ord - 1
  from pg_catalog.unnest(v_ids) with ordinality as t(id, ord)
  where s.id = t.id and s.org_id = p_org_id;
end;
$$;

-- ─── Movimento de estoque: a liberação passa a ser catalogo.manage (como o resto do catálogo) ─────────
-- Mesma função de 20261029060200, só a checagem muda: de "owner/admin/manager" fixo para a liberação
-- configurável do estúdio (spec 37). Nada mais muda (mesmas mensagens, trava, histórico e auditoria).
create or replace function public.register_stock_entry_atomic(
  p_org_id uuid, p_product_id uuid, p_type text, p_quantity integer, p_reason text default null
)
returns integer
language plpgsql
set search_path to ''
as $function$
declare
  current_quantity integer;
  next_quantity integer;
begin
  if not public.has_permission(p_org_id, 'catalogo.manage') then
    raise exception 'Sem permissao para movimentar estoque' using errcode = '42501';
  end if;

  if p_type not in ('entrada', 'saida', 'ajuste') then
    raise exception 'Tipo de movimento de estoque invalido' using errcode = '22023';
  end if;

  if p_quantity is null or p_quantity < 0 or (p_quantity = 0 and p_type <> 'ajuste') or p_quantity > 100000 then
    raise exception 'Quantidade deve ser maior que zero' using errcode = '22023';
  end if;
  if pg_catalog.char_length(coalesce(p_reason, '')) > 200 then
    raise exception 'O motivo vai até 200 caracteres.' using errcode = '22023';
  end if;

  select stock_qty
    into current_quantity
  from public.products
  where id = p_product_id
    and org_id = p_org_id
  for update;

  if not found then
    raise exception 'Produto nao encontrado' using errcode = 'P0002';
  end if;

  current_quantity := coalesce(current_quantity, 0);
  next_quantity := case p_type
    when 'entrada' then current_quantity + p_quantity
    when 'saida' then current_quantity - p_quantity
    else p_quantity
  end;

  if next_quantity < 0 then
    raise exception 'Estoque insuficiente: ha % unidade(s)', current_quantity
      using errcode = '22003';
  end if;

  -- O gatilho de auditoria de products (catalog_audit_row) grava a linha STOCK_ENTRADA/SAIDA/AJUSTE (com a
  -- quantidade do movimento) a partir deste aviso, válido só dentro desta transação. Assim quem tem
  -- catalogo.manage mas não está na lista de papéis da política de auditoria (ex.: viewer) também movimenta.
  perform pg_catalog.set_config('catalog.stock_move', p_type || ':' || p_quantity::text, true);
  update public.products
  set stock_qty = next_quantity
  where id = p_product_id
    and org_id = p_org_id;
  perform pg_catalog.set_config('catalog.stock_move', '', true);

  insert into public.stock_entries (org_id, product_id, type, quantity, reason, created_by)
  values (p_org_id, p_product_id, p_type, p_quantity, nullif(pg_catalog.btrim(p_reason), ''), auth.uid());

  return next_quantity;
end;
$function$;

-- A tabela de movimentos também segue a liberação: a política antiga aceitava os papéis fixos (inclusive
-- recepção) e recusava quem recebeu catalogo.manage por perfil configurável, mesmo com a função liberada.
drop policy if exists stock_entries_insert on public.stock_entries;
create policy stock_entries_insert on public.stock_entries for insert to authenticated
  with check (public.has_permission(org_id, 'catalogo.manage'));

-- ─── Permissões de execução: só quem está logado ─────────────────────────────────────────────────────
revoke all on function public.catalog_save_category(uuid, uuid, text, text, text, integer) from public, anon;
revoke all on function public.catalog_save_service(uuid, uuid, uuid, text, text, numeric, text, integer, integer, numeric, boolean, uuid, boolean, boolean, uuid[], jsonb) from public, anon;
revoke all on function public.catalog_save_package(uuid, uuid, text, text, numeric, integer, integer, boolean, boolean, uuid[]) from public, anon;
revoke all on function public.catalog_save_bundle(uuid, uuid, text, text, uuid, numeric, boolean, integer, jsonb) from public, anon;
revoke all on function public.catalog_save_product(uuid, uuid, text, text, numeric, numeric, text, text, text, text, integer, integer, uuid, boolean, boolean) from public, anon;
revoke all on function public.catalog_save_plan(uuid, uuid, text, text, numeric, text, integer, uuid[], boolean) from public, anon;
revoke all on function public.catalog_set_flags(uuid, text, uuid, boolean, boolean) from public, anon;
revoke all on function public.catalog_delete_item(uuid, text, uuid) from public, anon;
revoke all on function public.catalog_duplicate_item(uuid, text, uuid) from public, anon;
revoke all on function public.catalog_reorder_services(uuid, uuid[]) from public, anon;
revoke all on function public.register_stock_entry_atomic(uuid, uuid, text, integer, text) from public, anon;

grant execute on function public.catalog_save_category(uuid, uuid, text, text, text, integer) to authenticated;
grant execute on function public.catalog_save_service(uuid, uuid, uuid, text, text, numeric, text, integer, integer, numeric, boolean, uuid, boolean, boolean, uuid[], jsonb) to authenticated;
grant execute on function public.catalog_save_package(uuid, uuid, text, text, numeric, integer, integer, boolean, boolean, uuid[]) to authenticated;
grant execute on function public.catalog_save_bundle(uuid, uuid, text, text, uuid, numeric, boolean, integer, jsonb) to authenticated;
grant execute on function public.catalog_save_product(uuid, uuid, text, text, numeric, numeric, text, text, text, text, integer, integer, uuid, boolean, boolean) to authenticated;
grant execute on function public.catalog_save_plan(uuid, uuid, text, text, numeric, text, integer, uuid[], boolean) to authenticated;
grant execute on function public.catalog_set_flags(uuid, text, uuid, boolean, boolean) to authenticated;
grant execute on function public.catalog_delete_item(uuid, text, uuid) to authenticated;
grant execute on function public.catalog_duplicate_item(uuid, text, uuid) to authenticated;
grant execute on function public.catalog_reorder_services(uuid, uuid[]) to authenticated;
grant execute on function public.register_stock_entry_atomic(uuid, uuid, text, integer, text) to authenticated;

-- ─── Auditoria por gatilho ───────────────────────────────────────────────────────────────────────────
-- A política audit_insert_member NÃO é recriada aqui: fica a versão vigente (20261114020100_agenda_writes.sql).
-- As funções acima não gravam auditoria; estes gatilhos gravam, para QUALQUER caminho que mude o catálogo
-- (estas funções, as funções antigas, UPDATE/DELETE direto pela API). Função SECURITY DEFINER (grava mesmo para
-- papel que a política de auditoria não aceita, como viewer com catalogo.manage), search_path vazio, execução
-- revogada de todos, usuário = auth.uid(), payload só com as colunas que mudaram (antes e depois; números
-- comparados com 2 casas). Operações: CATALOG_UPDATED, CATALOG_CREATED (item de combo posto), CATALOG_DELETED
-- e, no estoque, STOCK_ENTRADA/SAIDA/AJUSTE (ver register_stock_entry_atomic).
create or replace function public.catalog_audit_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cols text[];
  v_col text;
  v_old_json jsonb;
  v_new_json jsonb;
  v_a jsonb;
  v_b jsonb;
  v_old jsonb := '{}'::jsonb;
  v_new jsonb := '{}'::jsonb;
  v_op text := 'CATALOG_UPDATED';
  v_move text;
  v_record uuid;
begin
  v_cols := case tg_table_name
    when 'services' then array['price', 'price_type', 'commission_pct', 'deposit_type', 'deposit_value', 'active']
    when 'products' then array['price', 'cost_price', 'stock_qty', 'active']
    when 'service_packages' then array['price', 'sessions', 'validity_days', 'active']
    when 'subscription_plans' then array['price', 'billing_period', 'sessions_per_period', 'eligible_services', 'active']
    when 'service_bundles' then array['price', 'active', 'archived_at']
    when 'service_bundle_items' then array['quantity', 'allocated_price']
  end;

  if tg_table_name = 'service_bundle_items' then
    v_record := coalesce(new.bundle_id, old.bundle_id);
  else
    v_record := coalesce(new.id, old.id);
  end if;

  -- Apagar o estúdio inteiro apaga o catálogo em cascata: sem estúdio não há onde gravar a auditoria.
  if not exists (select 1 from public.organizations o where o.id = coalesce(new.org_id, old.org_id)) then
    return null;
  end if;

  if tg_op = 'DELETE' then
    v_old_json := pg_catalog.to_jsonb(old);
    v_old := pg_catalog.jsonb_build_object('name', v_old_json -> 'name', 'service_id', v_old_json -> 'service_id');
    foreach v_col in array v_cols loop
      v_old := v_old || pg_catalog.jsonb_build_object(v_col, v_old_json -> v_col);
    end loop;
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
    values (old.org_id, auth.uid(), tg_table_name, 'CATALOG_DELETED', v_record,
            pg_catalog.jsonb_strip_nulls(v_old), null);
    return null;
  end if;

  if tg_op = 'INSERT' then
    v_new_json := pg_catalog.to_jsonb(new);
    v_new := pg_catalog.jsonb_build_object('service_id', v_new_json -> 'service_id');
    foreach v_col in array v_cols loop
      v_new := v_new || pg_catalog.jsonb_build_object(v_col, v_new_json -> v_col);
    end loop;
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
    values (new.org_id, auth.uid(), tg_table_name, 'CATALOG_CREATED', v_record, null, v_new);
    return null;
  end if;

  v_old_json := pg_catalog.to_jsonb(old);
  v_new_json := pg_catalog.to_jsonb(new);
  foreach v_col in array v_cols loop
    v_a := v_old_json -> v_col;
    v_b := v_new_json -> v_col;
    if pg_catalog.jsonb_typeof(v_a) = 'number' and pg_catalog.jsonb_typeof(v_b) = 'number' then
      if pg_catalog.round((v_a #>> '{}')::numeric, 2) is distinct from pg_catalog.round((v_b #>> '{}')::numeric, 2) then
        v_old := v_old || pg_catalog.jsonb_build_object(v_col, v_a);
        v_new := v_new || pg_catalog.jsonb_build_object(v_col, v_b);
      end if;
    elsif v_a is distinct from v_b then
      v_old := v_old || pg_catalog.jsonb_build_object(v_col, v_a);
      v_new := v_new || pg_catalog.jsonb_build_object(v_col, v_b);
    end if;
  end loop;
  if v_new = '{}'::jsonb then
    return null;
  end if;
  if tg_table_name = 'service_bundle_items' then
    v_new := v_new || pg_catalog.jsonb_build_object('service_id', v_new_json -> 'service_id');
  end if;

  -- Movimento de estoque: register_stock_entry_atomic avisa o tipo e a quantidade (tipo conferido aqui).
  if tg_table_name = 'products' and v_new ? 'stock_qty' then
    v_move := pg_catalog.current_setting('catalog.stock_move', true);
    if v_move ~ '^(entrada|saida|ajuste):[0-9]{1,6}$' then
      v_op := 'STOCK_' || pg_catalog.upper(pg_catalog.split_part(v_move, ':', 1));
      v_new := v_new || pg_catalog.jsonb_build_object('quantity', pg_catalog.split_part(v_move, ':', 2)::integer);
      -- Preço e outras colunas do mesmo UPDATE (não vêm pela função de estoque) ficam fora desta linha.
      v_old := pg_catalog.jsonb_build_object('stock_qty', v_old -> 'stock_qty');
      v_new := pg_catalog.jsonb_build_object('stock_qty', v_new -> 'stock_qty', 'quantity', v_new -> 'quantity');
    end if;
  end if;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (new.org_id, auth.uid(), tg_table_name, v_op, v_record, v_old, v_new);
  return null;
end;
$$;

revoke all on function public.catalog_audit_row() from public, anon, authenticated;

drop trigger if exists catalog_audit_update on public.services;
drop trigger if exists catalog_audit_delete on public.services;
create trigger catalog_audit_update after update on public.services
  for each row when (old.price is distinct from new.price or old.price_type is distinct from new.price_type
    or old.commission_pct is distinct from new.commission_pct or old.deposit_type is distinct from new.deposit_type
    or old.deposit_value is distinct from new.deposit_value or old.active is distinct from new.active)
  execute function public.catalog_audit_row();
create trigger catalog_audit_delete after delete on public.services
  for each row execute function public.catalog_audit_row();

drop trigger if exists catalog_audit_update on public.products;
drop trigger if exists catalog_audit_delete on public.products;
create trigger catalog_audit_update after update on public.products
  for each row when (old.price is distinct from new.price or old.cost_price is distinct from new.cost_price
    or old.stock_qty is distinct from new.stock_qty or old.active is distinct from new.active)
  execute function public.catalog_audit_row();
create trigger catalog_audit_delete after delete on public.products
  for each row execute function public.catalog_audit_row();

drop trigger if exists catalog_audit_update on public.service_packages;
drop trigger if exists catalog_audit_delete on public.service_packages;
create trigger catalog_audit_update after update on public.service_packages
  for each row when (old.price is distinct from new.price or old.sessions is distinct from new.sessions
    or old.validity_days is distinct from new.validity_days or old.active is distinct from new.active)
  execute function public.catalog_audit_row();
create trigger catalog_audit_delete after delete on public.service_packages
  for each row execute function public.catalog_audit_row();

drop trigger if exists catalog_audit_update on public.subscription_plans;
drop trigger if exists catalog_audit_delete on public.subscription_plans;
create trigger catalog_audit_update after update on public.subscription_plans
  for each row when (old.price is distinct from new.price or old.billing_period is distinct from new.billing_period
    or old.sessions_per_period is distinct from new.sessions_per_period
    or old.eligible_services is distinct from new.eligible_services or old.active is distinct from new.active)
  execute function public.catalog_audit_row();
create trigger catalog_audit_delete after delete on public.subscription_plans
  for each row execute function public.catalog_audit_row();

drop trigger if exists catalog_audit_update on public.service_bundles;
drop trigger if exists catalog_audit_delete on public.service_bundles;
create trigger catalog_audit_update after update on public.service_bundles
  for each row when (old.price is distinct from new.price or old.active is distinct from new.active
    or old.archived_at is distinct from new.archived_at)
  execute function public.catalog_audit_row();
create trigger catalog_audit_delete after delete on public.service_bundles
  for each row execute function public.catalog_audit_row();

drop trigger if exists catalog_audit_insert on public.service_bundle_items;
drop trigger if exists catalog_audit_update on public.service_bundle_items;
drop trigger if exists catalog_audit_delete on public.service_bundle_items;
create trigger catalog_audit_insert after insert on public.service_bundle_items
  for each row execute function public.catalog_audit_row();
create trigger catalog_audit_update after update on public.service_bundle_items
  for each row when (old.quantity is distinct from new.quantity or old.allocated_price is distinct from new.allocated_price)
  execute function public.catalog_audit_row();
create trigger catalog_audit_delete after delete on public.service_bundle_items
  for each row execute function public.catalog_audit_row();
