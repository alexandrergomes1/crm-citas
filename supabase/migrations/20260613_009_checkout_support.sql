-- ============================================================
-- KA Beauty OS - Checkout idempotency and transactional helpers
-- Encoding: UTF-8
-- ============================================================

create table if not exists public.checkout_requests (
  org_id uuid not null references public.organizations(id) on delete cascade,
  request_id uuid not null,
  appointment_id uuid not null references public.appointments(id) on delete cascade,
  payload_hash text not null,
  result jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (org_id, request_id)
);

create unique index if not exists idx_sales_org_appointment_unique
  on public.sales (org_id, appointment_id)
  where appointment_id is not null;

create index if not exists idx_checkout_requests_appointment
  on public.checkout_requests (org_id, appointment_id, created_at desc);

alter table public.checkout_requests enable row level security;
revoke all on public.checkout_requests from public, anon, authenticated;

create or replace function public.checkout_apply_payment_internal(
  p_org_id uuid,
  p_sale_id uuid,
  p_appointment_id uuid,
  p_client_id uuid,
  p_client_name text,
  p_method text,
  p_amount numeric,
  p_gift_card_code text,
  p_description text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_card public.gift_cards;
begin
  if p_method = 'GIFT_CARD' then
    if p_gift_card_code is null then
      raise exception 'Informe o codigo do vale presente' using errcode = '22023';
    end if;
    select * into v_card
    from public.gift_cards
    where org_id = p_org_id and upper(code) = p_gift_card_code
    for update;
    if not found or v_card.status <> 'active'
      or (v_card.expires_at is not null and v_card.expires_at < current_date)
      or v_card.remaining_value < p_amount then
      raise exception 'Vale presente invalido ou com saldo insuficiente'
        using errcode = '22023';
    end if;
    update public.gift_cards
    set remaining_value = remaining_value - p_amount,
        status = case when remaining_value - p_amount <= 0 then 'used' else 'active' end,
        sale_id = p_sale_id
    where id = v_card.id;
    insert into public.gift_card_redemptions (
      org_id, gift_card_id, sale_id, appointment_id, client_id, amount,
      balance_before, balance_after, redeemed_by
    ) values (
      p_org_id, v_card.id, p_sale_id, p_appointment_id, p_client_id, p_amount,
      v_card.remaining_value, v_card.remaining_value - p_amount, auth.uid()
    );
  end if;

  insert into public.sale_payments (
    org_id, sale_id, method, amount, gift_card_code
  ) values (
    p_org_id, p_sale_id, p_method, p_amount, p_gift_card_code
  );
  insert into public.transactions (
    org_id, sale_id, client_id, client_name, type, category, description,
    value, method, date, status, created_by
  ) values (
    p_org_id, p_sale_id, p_client_id, p_client_name, 'income', 'servico',
    p_description, p_amount, p_method, current_date, 'completed', auth.uid()
  );
end;
$$;

create or replace function public.checkout_apply_benefits_internal(
  p_org_id uuid,
  p_sale_id uuid,
  p_appointment_id uuid,
  p_client_id uuid,
  p_items jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entitlement public.client_entitlements;
  v_package public.service_packages;
  v_covered_services jsonb;
  v_stock integer;
  r_item record;
  r_product record;
begin
  for r_item in
    select item, (item->>'quantity')::integer as quantity
    from jsonb_array_elements(p_items) item
    where coalesce((item->>'covered_by_entitlement')::boolean, false)
  loop
    if p_client_id is null then
      raise exception 'Beneficio exige cliente vinculado' using errcode = '22023';
    end if;
    select * into v_entitlement
    from public.client_entitlements
    where id = nullif(r_item.item->>'entitlement_id', '')::uuid
      and org_id = p_org_id and client_id = p_client_id
    for update;
    if not found or v_entitlement.status <> 'active'
      or (v_entitlement.expires_at is not null and v_entitlement.expires_at < now())
      or v_entitlement.used_sessions + r_item.quantity > v_entitlement.total_sessions then
      raise exception 'Pacote indisponivel ou sem sessoes suficientes'
        using errcode = '22023';
    end if;
    if jsonb_array_length(v_entitlement.covered_services) > 0
      and not exists (
        select 1
        from jsonb_array_elements(v_entitlement.covered_services) covered
        where covered->>'service_id' = r_item.item->>'item_id'
      ) then
      raise exception 'O pacote nao cobre este servico' using errcode = '22023';
    end if;
    update public.client_entitlements set
      used_sessions = used_sessions + r_item.quantity,
      status = case
        when used_sessions + r_item.quantity >= total_sessions then 'exhausted'
        else 'active'
      end
    where id = v_entitlement.id;
    insert into public.client_entitlement_entries (
      org_id, entitlement_id, client_id, appointment_id, service_name,
      action, sessions_delta, sessions_before, sessions_after, created_by
    ) values (
      p_org_id, v_entitlement.id, p_client_id, p_appointment_id,
      r_item.item->>'name', 'consume', -r_item.quantity,
      v_entitlement.used_sessions,
      v_entitlement.used_sessions + r_item.quantity, auth.uid()
    );
  end loop;

  for r_item in
    select item, (item->>'quantity')::integer as quantity
    from jsonb_array_elements(p_items) item
    where upper(item->>'item_type') = 'PACKAGE'
  loop
    if p_client_id is null then
      raise exception 'Pacote exige cliente vinculado' using errcode = '22023';
    end if;
    select * into v_package
    from public.service_packages
    where id = nullif(r_item.item->>'item_id', '')::uuid
      and org_id = p_org_id and active = true;
    if not found then
      raise exception 'Pacote nao encontrado' using errcode = 'P0002';
    end if;
    select coalesce(jsonb_agg(jsonb_build_object(
      'service_id', ps.service_id, 'service_name', s.name, 'qty', ps.qty
    ) order by s.name), '[]'::jsonb)
      into v_covered_services
    from public.package_services ps
    join public.services s on s.id = ps.service_id
    where ps.package_id = v_package.id;
    insert into public.client_entitlements (
      org_id, client_id, package_id, package_name, sale_id, status,
      total_sessions, used_sessions, covered_services, expires_at
    ) values (
      p_org_id, p_client_id, v_package.id, v_package.name, p_sale_id, 'active',
      v_package.sessions * r_item.quantity, 0, v_covered_services,
      now() + make_interval(days => v_package.validity_days)
    );
  end loop;

  for r_product in
    select nullif(item->>'item_id', '')::uuid as product_id,
      sum((item->>'quantity')::integer)::integer as quantity
    from jsonb_array_elements(p_items) item
    where upper(item->>'item_type') = 'PRODUCT'
    group by 1
  loop
    if r_product.product_id is null then
      raise exception 'Produto sem identificador' using errcode = '22023';
    end if;
    select stock_qty into v_stock
    from public.products
    where id = r_product.product_id and org_id = p_org_id and active = true
    for update;
    if not found or v_stock < r_product.quantity then
      raise exception 'Estoque insuficiente para concluir a comanda'
        using errcode = '22023';
    end if;
    update public.products set stock_qty = stock_qty - r_product.quantity
    where id = r_product.product_id;
    insert into public.stock_entries (
      org_id, product_id, type, quantity, reason, created_by
    ) values (
      p_org_id, r_product.product_id, 'saida', r_product.quantity,
      'Venda na comanda ' || p_sale_id::text, auth.uid()
    );
  end loop;
end;
$$;

revoke all on function public.checkout_apply_payment_internal(
  uuid, uuid, uuid, uuid, text, text, numeric, text, text
) from public, anon, authenticated;
revoke all on function public.checkout_apply_benefits_internal(
  uuid, uuid, uuid, uuid, jsonb
) from public, anon, authenticated;
