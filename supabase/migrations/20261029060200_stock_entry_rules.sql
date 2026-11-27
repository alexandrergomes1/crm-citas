-- Revisão de funções de 29 out, parte 5: movimento manual de estoque.
-- Encoding: UTF-8.
-- register_stock_entry_atomic:
--   1. só gestão mexe no estoque pela função (o app já exigia; agora o banco também);
--   2. ajuste pode zerar o estoque (antes exigia quantidade > 0);
--   3. saída maior que o estoque é recusada (antes zerava em silêncio);
--   4. todo movimento manual vai para a auditoria.
set client_encoding = 'UTF8';

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
  if coalesce(public.auth_user_role(p_org_id), '') not in ('owner', 'admin', 'manager') then
    raise exception 'Sem permissao para movimentar estoque' using errcode = '42501';
  end if;

  if p_type not in ('entrada', 'saida', 'ajuste') then
    raise exception 'Tipo de movimento de estoque invalido' using errcode = '22023';
  end if;

  if p_quantity is null or p_quantity < 0 or (p_quantity = 0 and p_type <> 'ajuste') then
    raise exception 'Quantidade deve ser maior que zero' using errcode = '22023';
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

  update public.products
  set stock_qty = next_quantity
  where id = p_product_id
    and org_id = p_org_id;

  insert into public.stock_entries (org_id, product_id, type, quantity, reason, created_by)
  values (p_org_id, p_product_id, p_type, p_quantity, nullif(pg_catalog.btrim(p_reason), ''), auth.uid());

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (p_org_id, auth.uid(), 'products', 'STOCK_' || pg_catalog.upper(p_type), p_product_id,
    pg_catalog.jsonb_build_object('stock_qty', current_quantity),
    pg_catalog.jsonb_build_object('stock_qty', next_quantity, 'quantity', p_quantity));

  return next_quantity;
end;
$function$;
