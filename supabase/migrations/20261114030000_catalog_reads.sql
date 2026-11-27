-- Catálogo: leituras da tela em UMA ida ao banco cada (porte para o TanStack Start, orçamento de chamadas).
-- Antes (beauty-system): abrir qualquer aba do Catálogo fazia 10 consultas (serviços, categorias, equipe com
-- turnos, modelos de ficha com todas as perguntas, pacotes, vínculos serviço-profissional, vendas por pacote
-- contadas no app lendo TODOS os direitos de sessão do estúdio, produtos, combos, planos).
-- Agora: catalog_screen devolve só as colunas que a tela usa. SECURITY INVOKER: a RLS vale como nas consultas
-- que substitui (qualquer pessoa do estúdio lê o catálogo; outro estúdio não lê nada).
-- Limites de segurança por lista (o PostgREST já cortava em 1000 linhas): serviços e produtos 1000,
-- demais listas 500. Um estúdio de estética não chega perto.
-- Encoding: UTF-8
set client_encoding = 'UTF8';

-- ─── Tela do Catálogo (serviços, pacotes, produtos, combos e planos) ──────────────────────────────
create or replace function public.catalog_screen(p_org_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  -- Sem estúdio na sessão (ou estúdio de outra pessoa): resposta vazia seria enganosa; recusa.
  if p_org_id is null or p_org_id not in (select public.auth_org_ids()) then
    raise exception 'Sem acesso a este estúdio.' using errcode = '42501';
  end if;

  select pg_catalog.jsonb_build_object(
    'services', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', s.id, 'name', s.name, 'description', s.description, 'category_id', s.category_id,
        'price', s.price, 'price_type', s.price_type, 'duration_minutes', s.duration_minutes,
        'buffer_minutes', s.buffer_minutes, 'commission_pct', s.commission_pct,
        'requires_anamnese', s.requires_anamnese, 'anamnese_template_id', s.anamnese_template_id,
        'online_booking', s.online_booking, 'active', s.active, 'position', s.position,
        'result_months', s.result_months, 'retouch_included_days', s.retouch_included_days,
        'deposit_type', s.deposit_type, 'deposit_value', s.deposit_value,
        'staff_ids', coalesce((
          select pg_catalog.jsonb_agg(ss.staff_id order by ss.staff_id)
          from public.service_staff ss where ss.service_id = s.id and ss.org_id = s.org_id), '[]'::jsonb))
        order by s.position, s.name, s.id)
      from (select * from public.services x where x.org_id = p_org_id order by x.position, x.name, x.id limit 1000) s
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
        'sku', r.sku, 'barcode', r.barcode, 'price', r.price, 'cost_price', r.cost_price, 'stock_qty', r.stock_qty,
        'stock_alert', r.stock_alert, 'unit', r.unit, 'online_booking', r.online_booking, 'active', r.active,
        'position', r.position) order by r.position, r.name, r.id)
      from (select * from public.products x where x.org_id = p_org_id order by x.position, x.name, x.id limit 1000) r
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
        ('services', (select pg_catalog.count(*) from (select 1 from public.services x where x.org_id = p_org_id limit 1001) q) > 1000),
        ('products', (select pg_catalog.count(*) from (select 1 from public.products x where x.org_id = p_org_id limit 1001) q) > 1000),
        ('categories', (select pg_catalog.count(*) from (select 1 from public.service_categories x where x.org_id = p_org_id and x.active limit 501) q) > 500),
        ('packages', (select pg_catalog.count(*) from (select 1 from public.service_packages x where x.org_id = p_org_id limit 501) q) > 500),
        ('bundles', (select pg_catalog.count(*) from (select 1 from public.service_bundles x where x.org_id = p_org_id limit 501) q) > 500),
        ('plans', (select pg_catalog.count(*) from (select 1 from public.subscription_plans x where x.org_id = p_org_id limit 501) q) > 500)
      ) t(k, cut) where t.cut)
  ) into v_result;
  return v_result;
end;
$$;

-- ─── Histórico de estoque de um produto (painel de estoque do produto) ────────────────────────────
-- Antes: acesso + consulta; agora o produto é conferido junto (de outro estúdio = nada).
create or replace function public.catalog_stock_entries(p_org_id uuid, p_product_id uuid)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'id', e.id, 'type', e.type, 'quantity', e.quantity, 'reason', e.reason, 'created_at', e.created_at)
    order by e.created_at desc, e.id), '[]'::jsonb)
  from (
    select x.id, x.type, x.quantity, x.reason, x.created_at
    from public.stock_entries x
    where x.org_id = p_org_id and x.product_id = p_product_id
      and p_org_id in (select public.auth_org_ids())
    order by x.created_at desc, x.id
    limit 30
  ) e;
$$;

-- ─── Índices que cobrem as consultas novas ────────────────────────────────────────────────────────
-- Excluir serviço ou produto confere se há atendimento/venda ligados (por estúdio + item). Antes só havia
-- índice por estúdio, então a conferência lia todos os itens do estúdio.
-- Sem "concurrently": nenhuma migration do projeto usa (o CLI aplica cada arquivo numa transação) e as
-- tabelas ainda são pequenas (ver 20261114010100).
create index if not exists idx_appointment_items_org_type_ref
  on public.appointment_items (org_id, type, ref_id);
create index if not exists idx_sale_items_org_item
  on public.sale_items (org_id, item_id);

revoke all on function public.catalog_screen(uuid) from public, anon;
revoke all on function public.catalog_stock_entries(uuid, uuid) from public, anon;
grant execute on function public.catalog_screen(uuid) to authenticated;
grant execute on function public.catalog_stock_entries(uuid, uuid) to authenticated;
