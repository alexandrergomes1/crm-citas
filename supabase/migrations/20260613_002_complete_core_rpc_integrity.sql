-- ============================================================
-- KA Beauty OS - Complete core RPC integrity on remote schema
-- Encoding: UTF-8
-- ============================================================

create or replace function public.auth_org_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select ur.org_id
  from public.user_roles ur
  where ur.user_id = (select auth.uid())
    and ur.active = true;
$$;

create or replace function public.auth_user_role(p_org_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select ur.role::text
  from public.user_roles ur
  where ur.user_id = (select auth.uid())
    and ur.org_id = p_org_id
    and ur.active = true
  limit 1;
$$;

revoke all on function public.auth_org_ids() from public;
revoke all on function public.auth_org_ids() from anon;
revoke all on function public.auth_user_role(uuid) from public;
revoke all on function public.auth_user_role(uuid) from anon;
grant execute on function public.auth_org_ids() to authenticated;
grant execute on function public.auth_user_role(uuid) to authenticated;

create or replace function public.register_stock_entry_atomic(
  p_org_id uuid,
  p_product_id uuid,
  p_type text,
  p_quantity integer,
  p_reason text default null
)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  current_quantity integer;
  next_quantity integer;
begin
  if p_type not in ('entrada', 'saida', 'ajuste') then
    raise exception 'Tipo de movimento de estoque invalido'
      using errcode = '22023';
  end if;

  if p_quantity <= 0 then
    raise exception 'Quantidade deve ser maior que zero'
      using errcode = '22023';
  end if;

  select stock_qty
    into current_quantity
  from public.products
  where id = p_product_id
    and org_id = p_org_id
  for update;

  if not found then
    raise exception 'Produto nao encontrado'
      using errcode = 'P0002';
  end if;

  next_quantity := case p_type
    when 'entrada' then current_quantity + p_quantity
    when 'saida' then greatest(0, current_quantity - p_quantity)
    else p_quantity
  end;

  update public.products
  set stock_qty = next_quantity
  where id = p_product_id
    and org_id = p_org_id;

  insert into public.stock_entries (
    org_id,
    product_id,
    type,
    quantity,
    reason,
    created_by
  )
  values (
    p_org_id,
    p_product_id,
    p_type,
    p_quantity,
    nullif(pg_catalog.btrim(p_reason), ''),
    auth.uid()
  );

  return next_quantity;
end;
$$;

revoke all on function public.register_stock_entry_atomic(
  uuid, uuid, text, integer, text
) from public;
revoke all on function public.register_stock_entry_atomic(
  uuid, uuid, text, integer, text
) from anon;
grant execute on function public.register_stock_entry_atomic(
  uuid, uuid, text, integer, text
) to authenticated;

revoke all on function public.set_appointment_status_atomic(
  uuid, uuid, text
) from anon;
revoke all on function public.register_appointment_deposit_atomic(
  uuid, uuid, numeric, text, uuid
) from anon;

alter function public.update_updated_at()
  set search_path = '';
