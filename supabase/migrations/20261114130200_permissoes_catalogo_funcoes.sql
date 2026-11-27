-- Permissões pendentes (estado.md), parte 3: funções do Catálogo.
-- Encoding: UTF-8
set client_encoding = 'UTF8';
--
-- catalog_screen passa a exigir catalogo.view (ou catalogo.manage) no banco (antes só o app conferia) e devolve commission_pct (serviço)
-- e cost_price (produto) só para quem tem catalogo.manage ou financeiro.view; os demais recebem null.
-- A parte 4 (20261114130300) fecha essas colunas (e o custo do serviço, cost_amount) para a leitura direta pela
-- API; por isso as funções que leem a linha inteira (catalog_screen, catalog_save_service, catalog_save_product,
-- catalog_duplicate_item) leem por internal_read. Salvar continua travando a linha na própria tabela.

-- ─── catalog_screen ───
CREATE OR REPLACE FUNCTION public.catalog_screen(p_org_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  v_result jsonb;
  v_costs boolean;
begin
  -- Sem estúdio na sessão (ou estúdio de outra pessoa): resposta vazia seria enganosa; recusa.
  if p_org_id is null or p_org_id not in (select public.auth_org_ids()) then
    raise exception 'Sem acesso a este estúdio.' using errcode = '42501';
  end if;
  -- Mesma regra da leitura das tabelas (parte 4): ver o catálogo ou geri-lo.
  if not (public.has_permission(p_org_id, 'catalogo.view') or public.has_permission(p_org_id, 'catalogo.manage')) then
    raise exception 'Sem permissão para ver o catálogo.' using errcode = '42501';
  end if;
  -- Comissão do serviço e custo do produto: só gestão do catálogo ou financeiro (os demais recebem null).
  v_costs := public.has_permission(p_org_id, 'catalogo.manage') or public.has_permission(p_org_id, 'financeiro.view');

  select pg_catalog.jsonb_build_object(
    'services', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', s.id, 'name', s.name, 'description', s.description, 'category_id', s.category_id,
        'price', s.price, 'price_type', s.price_type, 'duration_minutes', s.duration_minutes,
        'buffer_minutes', s.buffer_minutes, 'commission_pct', case when v_costs then s.commission_pct end,
        'requires_anamnese', s.requires_anamnese, 'anamnese_template_id', s.anamnese_template_id,
        'online_booking', s.online_booking, 'active', s.active, 'position', s.position,
        'result_months', s.result_months, 'retouch_included_days', s.retouch_included_days,
        'deposit_type', s.deposit_type, 'deposit_value', s.deposit_value,
        'staff_ids', coalesce((
          select pg_catalog.jsonb_agg(ss.staff_id order by ss.staff_id)
          from public.service_staff ss where ss.service_id = s.id and ss.org_id = s.org_id), '[]'::jsonb))
        order by s.position, s.name, s.id)
      from (select * from internal_read.services x where x.org_id = p_org_id order by x.position, x.name, x.id limit 1000) s
    ), '[]'::jsonb),
    'categories', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', c.id, 'name', c.name, 'color', c.color, 'position', c.position) order by c.position, c.name, c.id)
      from (select * from public.service_categories x where x.org_id = p_org_id and x.active
            order by x.position, x.name, x.id limit 500) c
    ), '[]'::jsonb),
    'staff', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', m.id, 'name', m.name, 'display_name', m.display_name, 'role', m.role) order by m.position, m.name, m.id)
      from (select * from public.staff_members x where x.org_id = p_org_id and x.active
            order by x.position, x.name, x.id limit 500) m
    ), '[]'::jsonb),
    -- Só id e título: o modelo inteiro (perguntas, termos) não é usado nesta tela.
    'templates', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', t.id, 'title', t.title) order by t.title, t.id)
      from (select x.id, x.title from public.anamnese_templates x where x.org_id = p_org_id and x.active
            order by x.title, x.id limit 500) t
    ), '[]'::jsonb),
    'packages', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', p.id, 'name', p.name, 'description', p.description, 'price', p.price, 'sessions', p.sessions,
        'validity_days', p.validity_days, 'online_booking', p.online_booking, 'active', p.active,
        'position', p.position,
        'service_ids', coalesce((
          select pg_catalog.jsonb_agg(ps.service_id order by ps.service_id)
          from public.package_services ps where ps.package_id = p.id and ps.org_id = p.org_id), '[]'::jsonb),
        -- Vendas = direitos de sessões criados a partir do pacote (contados no banco, não no app).
        'sales', (select pg_catalog.count(*) from public.client_entitlements e
                  where e.org_id = p.org_id and e.package_id = p.id))
        order by p.position, p.name, p.id)
      from (select * from public.service_packages x where x.org_id = p_org_id
            order by x.position, x.name, x.id limit 500) p
    ), '[]'::jsonb),
    'products', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', r.id, 'name', r.name, 'description', r.description, 'brand', r.brand, 'category_id', r.category_id,
        'sku', r.sku, 'barcode', r.barcode, 'price', r.price, 'cost_price', case when v_costs then r.cost_price end, 'stock_qty', r.stock_qty,
        'stock_alert', r.stock_alert, 'unit', r.unit, 'online_booking', r.online_booking, 'active', r.active,
        'position', r.position) order by r.position, r.name, r.id)
      from (select * from internal_read.products x where x.org_id = p_org_id order by x.position, x.name, x.id limit 1000) r
    ), '[]'::jsonb),
    'bundles', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', b.id, 'name', b.name, 'description', b.description, 'category_id', b.category_id, 'price', b.price,
        'active', b.active, 'archived_at', b.archived_at, 'position', b.position,
        'items', coalesce((
          select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
            'service_id', i.service_id, 'position', i.position, 'quantity', i.quantity,
            'allocated_price', i.allocated_price) order by i.position, i.service_id)
          from public.service_bundle_items i where i.bundle_id = b.id and i.org_id = b.org_id), '[]'::jsonb))
        order by b.position, b.name, b.id)
      from (select * from public.service_bundles x where x.org_id = p_org_id
            order by x.position, x.name, x.id limit 500) b
    ), '[]'::jsonb),
    'plans', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', l.id, 'name', l.name, 'description', l.description, 'price', l.price,
        'billing_period', l.billing_period, 'sessions_per_period', l.sessions_per_period,
        'eligible_services', l.eligible_services, 'active', l.active, 'position', l.position)
        order by l.position, l.name, l.id)
      from (select * from public.subscription_plans x where x.org_id = p_org_id
            order by x.position, x.name, x.id limit 500) l
    ), '[]'::jsonb),
    -- Listas que passaram do limite e vieram cortadas (a tela avisa em vez de mostrar uma lista incompleta como se fosse tudo).
    'truncated', (
      select coalesce(pg_catalog.jsonb_agg(t.k), '[]'::jsonb) from (values
        ('services', (select pg_catalog.count(*) from (select 1 from internal_read.services x where x.org_id = p_org_id limit 1001) q) > 1000),
        ('products', (select pg_catalog.count(*) from (select 1 from internal_read.products x where x.org_id = p_org_id limit 1001) q) > 1000),
        ('categories', (select pg_catalog.count(*) from (select 1 from public.service_categories x where x.org_id = p_org_id and x.active limit 501) q) > 500),
        ('packages', (select pg_catalog.count(*) from (select 1 from public.service_packages x where x.org_id = p_org_id limit 501) q) > 500),
        ('bundles', (select pg_catalog.count(*) from (select 1 from public.service_bundles x where x.org_id = p_org_id limit 501) q) > 500),
        ('plans', (select pg_catalog.count(*) from (select 1 from public.subscription_plans x where x.org_id = p_org_id limit 501) q) > 500)
      ) t(k, cut) where t.cut)
  ) into v_result;
  return v_result;
end;
$function$
;

-- ─── catalog_save_service ───
CREATE OR REPLACE FUNCTION public.catalog_save_service(p_org_id uuid, p_service_id uuid, p_category_id uuid, p_name text, p_description text, p_price numeric, p_price_type text, p_duration_minutes integer, p_buffer_minutes integer, p_commission_pct numeric, p_requires_anamnese boolean, p_anamnese_template_id uuid, p_online_booking boolean, p_active boolean, p_staff_ids uuid[], p_rules jsonb DEFAULT NULL::jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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
    -- Trava na tabela; a linha inteira (com a comissão) vem de internal_read.
    perform 1 from public.services s where s.id = p_service_id and s.org_id = p_org_id for update;
    select * into v_old from internal_read.services s where s.id = p_service_id and s.org_id = p_org_id;
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
$function$
;

-- ─── catalog_save_product ───
CREATE OR REPLACE FUNCTION public.catalog_save_product(p_org_id uuid, p_product_id uuid, p_name text, p_description text, p_price numeric, p_cost_price numeric, p_sku text, p_barcode text, p_brand text, p_unit text, p_stock_qty integer, p_stock_alert integer, p_category_id uuid, p_online_booking boolean, p_active boolean)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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
    -- Trava na tabela; a linha inteira (com o custo) vem de internal_read.
    perform 1 from public.products r where r.id = p_product_id and r.org_id = p_org_id for update;
    select * into v_old from internal_read.products r where r.id = p_product_id and r.org_id = p_org_id;
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
$function$
;

-- ─── catalog_duplicate_item ───
CREATE OR REPLACE FUNCTION public.catalog_duplicate_item(p_org_id uuid, p_kind text, p_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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
    from internal_read.services s where s.id = p_id and s.org_id = p_org_id
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
    from internal_read.products s where s.id = p_id and s.org_id = p_org_id
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
$function$
;

