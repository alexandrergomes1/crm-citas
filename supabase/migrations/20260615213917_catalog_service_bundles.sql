-- CAT-02A: service bundles are same-appointment combos, separate from session packages.
-- Encoding: UTF-8

create table if not exists public.service_bundles (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  category_id uuid,
  name text not null,
  description text,
  price numeric(10,2) not null default 0,
  active boolean not null default true,
  archived_at timestamptz,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint service_bundles_id_org_key unique (id, org_id),
  constraint service_bundles_category_org_fkey
    foreign key (category_id, org_id)
    references public.service_categories(id, org_id)
    on delete restrict,
  constraint service_bundles_values_check check (
    btrim(name) <> ''
    and price >= 0
    and position >= 0
  )
);

create table if not exists public.service_bundle_items (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  bundle_id uuid not null,
  service_id uuid not null,
  position integer not null default 0,
  quantity integer not null default 1,
  original_price_snapshot numeric(10,2) not null,
  allocated_price numeric(10,2) not null,
  created_at timestamptz not null default now(),
  constraint service_bundle_items_bundle_org_fkey
    foreign key (bundle_id, org_id)
    references public.service_bundles(id, org_id)
    on delete cascade,
  constraint service_bundle_items_service_org_fkey
    foreign key (service_id, org_id)
    references public.services(id, org_id)
    on delete restrict,
  constraint service_bundle_items_service_unique unique (bundle_id, service_id),
  constraint service_bundle_items_values_check check (
    position >= 0
    and quantity >= 1
    and original_price_snapshot >= 0
    and allocated_price >= 0
  )
);
comment on table public.service_bundles is
  'Combos de servicos executados juntos no mesmo atendimento; nao representam credito/sessoes futuras.';
comment on table public.service_bundle_items is
  'allocated_price e por unidade; a soma quantity * allocated_price deve fechar com service_bundles.price.';

create index if not exists service_bundles_org_active_idx
  on public.service_bundles(org_id, active, archived_at, position);
create index if not exists service_bundles_org_category_idx
  on public.service_bundles(org_id, category_id);
create index if not exists service_bundle_items_org_bundle_idx
  on public.service_bundle_items(org_id, bundle_id, position);
create index if not exists service_bundle_items_org_service_idx
  on public.service_bundle_items(org_id, service_id);

drop trigger if exists trg_service_bundles_updated_at on public.service_bundles;
create trigger trg_service_bundles_updated_at
  before update on public.service_bundles
  for each row execute function public.update_updated_at();

create or replace function public.enforce_service_bundle_integrity()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_bundle_id uuid;
  v_org_id uuid;
  v_distinct_services integer;
  v_allocated_total numeric(10,2);
  v_bundle_price numeric(10,2);
begin
  if tg_table_name = 'service_bundle_items' then
    v_bundle_id := coalesce(new.bundle_id, old.bundle_id);
    v_org_id := coalesce(new.org_id, old.org_id);
  else
    v_bundle_id := new.id;
    v_org_id := new.org_id;
  end if;

  select price
  into v_bundle_price
  from public.service_bundles
  where id = v_bundle_id
    and org_id = v_org_id;

  if v_bundle_price is null then
    return null;
  end if;

  select count(distinct service_id), coalesce(sum(quantity * allocated_price), 0)
  into v_distinct_services, v_allocated_total
  from public.service_bundle_items
  where bundle_id = v_bundle_id
    and org_id = v_org_id;

  if v_distinct_services < 2 then
    raise exception 'service bundle must contain at least two distinct services' using errcode = '23514';
  end if;

  if round(v_allocated_total, 2) <> round(v_bundle_price, 2) then
    raise exception 'allocated bundle total must equal bundle price' using errcode = '23514';
  end if;

  return null;
end;
$$;
drop trigger if exists service_bundle_integrity_on_bundle on public.service_bundles;
create constraint trigger service_bundle_integrity_on_bundle
  after insert or update on public.service_bundles
  deferrable initially deferred
  for each row execute function public.enforce_service_bundle_integrity();
drop trigger if exists service_bundle_integrity_on_items on public.service_bundle_items;
create constraint trigger service_bundle_integrity_on_items
  after insert or update or delete on public.service_bundle_items
  deferrable initially deferred
  for each row execute function public.enforce_service_bundle_integrity();

alter table public.service_bundles enable row level security;
alter table public.service_bundle_items enable row level security;
drop policy if exists catalog_bundles_select on public.service_bundles;
drop policy if exists catalog_bundles_insert on public.service_bundles;
drop policy if exists catalog_bundles_update on public.service_bundles;
drop policy if exists catalog_bundle_items_select on public.service_bundle_items;
drop policy if exists catalog_bundle_items_insert on public.service_bundle_items;
drop policy if exists catalog_bundle_items_update on public.service_bundle_items;
drop policy if exists catalog_bundle_items_delete on public.service_bundle_items;

create policy catalog_bundles_select on public.service_bundles
  for select to authenticated
  using (org_id in (select public.auth_org_ids()));
create policy catalog_bundles_insert on public.service_bundles
  for insert to authenticated
  with check (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));
create policy catalog_bundles_update on public.service_bundles
  for update to authenticated
  using (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'))
  with check (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));

create policy catalog_bundle_items_select on public.service_bundle_items
  for select to authenticated
  using (org_id in (select public.auth_org_ids()));
create policy catalog_bundle_items_insert on public.service_bundle_items
  for insert to authenticated
  with check (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));
create policy catalog_bundle_items_update on public.service_bundle_items
  for update to authenticated
  using (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'))
  with check (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));
create policy catalog_bundle_items_delete on public.service_bundle_items
  for delete to authenticated
  using (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));

grant select, insert, update on public.service_bundles to authenticated;
grant select, insert, update, delete on public.service_bundle_items to authenticated;

create or replace function public.upsert_service_bundle_atomic(
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
set search_path = public
as $$
declare
  v_bundle_id uuid;
  v_item_count integer;
  v_allocated_total numeric(10,2);
begin
  if public.auth_user_role(p_org_id) not in ('owner', 'admin', 'manager') then
    raise exception 'catalog permission denied' using errcode = '42501';
  end if;

  if btrim(coalesce(p_name, '')) = ''
    or p_price < 0
    or p_position < 0
    or jsonb_typeof(coalesce(p_items, '[]'::jsonb)) <> 'array'
  then
    raise exception 'invalid service bundle data' using errcode = '22023';
  end if;

  if p_category_id is not null and not exists (
    select 1 from public.service_categories
    where id = p_category_id and org_id = p_org_id
  ) then
    raise exception 'category belongs to another organization' using errcode = '23514';
  end if;

  select count(distinct requested.service_id),
         coalesce(sum(requested.quantity * requested.allocated_price), 0)
  into v_item_count, v_allocated_total
  from jsonb_to_recordset(p_items) as requested(
    service_id uuid,
    quantity integer,
    allocated_price numeric
  );

  if v_item_count < 2 then
    raise exception 'service bundle must contain at least two distinct services' using errcode = '23514';
  end if;

  if round(v_allocated_total, 2) <> round(p_price, 2) then
    raise exception 'allocated bundle total must equal bundle price' using errcode = '23514';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_items) as requested(
      service_id uuid,
      quantity integer,
      allocated_price numeric
    )
    where requested.quantity < 1
      or requested.allocated_price < 0
      or not exists (
        select 1 from public.services service
        where service.id = requested.service_id and service.org_id = p_org_id
      )
  ) then
    raise exception 'invalid service bundle item' using errcode = '23514';
  end if;

  if p_bundle_id is null then
    insert into public.service_bundles (
      org_id, category_id, name, description, price, active, position
    )
    values (
      p_org_id, p_category_id, btrim(p_name),
      nullif(btrim(coalesce(p_description, '')), ''),
      p_price, p_active, p_position
    )
    returning id into v_bundle_id;
  else
    update public.service_bundles
    set category_id = p_category_id,
        name = btrim(p_name),
        description = nullif(btrim(coalesce(p_description, '')), ''),
        price = p_price,
        active = p_active,
        position = p_position,
        archived_at = case when p_active then null else archived_at end
    where id = p_bundle_id
      and org_id = p_org_id
    returning id into v_bundle_id;

    if v_bundle_id is null then
      raise exception 'service bundle not found' using errcode = 'P0002';
    end if;
  end if;

  delete from public.service_bundle_items
  where bundle_id = v_bundle_id
    and org_id = p_org_id;

  insert into public.service_bundle_items(
    org_id, bundle_id, service_id, position, quantity,
    original_price_snapshot, allocated_price
  )
  select p_org_id,
         v_bundle_id,
         requested.service_id,
         row_number() over (order by requested.position, requested.service_id) - 1,
         requested.quantity,
         service.price,
         requested.allocated_price
  from jsonb_to_recordset(p_items) as requested(
    service_id uuid,
    position integer,
    quantity integer,
    allocated_price numeric
  )
  join public.services service
    on service.id = requested.service_id
   and service.org_id = p_org_id
  order by requested.position, requested.service_id;

  return v_bundle_id;
end;
$$;

create or replace function public.archive_service_bundle(
  p_org_id uuid,
  p_bundle_id uuid
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  if public.auth_user_role(p_org_id) not in ('owner', 'admin', 'manager') then
    raise exception 'catalog permission denied' using errcode = '42501';
  end if;

  update public.service_bundles
  set active = false,
      archived_at = coalesce(archived_at, now())
  where id = p_bundle_id
    and org_id = p_org_id;

  if not found then
    raise exception 'service bundle not found' using errcode = 'P0002';
  end if;
end;
$$;

create or replace function public.restore_service_bundle(
  p_org_id uuid,
  p_bundle_id uuid
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  if public.auth_user_role(p_org_id) not in ('owner', 'admin', 'manager') then
    raise exception 'catalog permission denied' using errcode = '42501';
  end if;

  update public.service_bundles
  set active = true,
      archived_at = null
  where id = p_bundle_id
    and org_id = p_org_id;

  if not found then
    raise exception 'service bundle not found' using errcode = 'P0002';
  end if;
end;
$$;

create or replace function public.duplicate_service_bundle(
  p_org_id uuid,
  p_bundle_id uuid,
  p_name text
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_source public.service_bundles%rowtype;
  v_new_id uuid;
begin
  if public.auth_user_role(p_org_id) not in ('owner', 'admin', 'manager') then
    raise exception 'catalog permission denied' using errcode = '42501';
  end if;

  select * into v_source
  from public.service_bundles
  where id = p_bundle_id
    and org_id = p_org_id;

  if v_source.id is null then
    raise exception 'service bundle not found' using errcode = 'P0002';
  end if;

  insert into public.service_bundles(
    org_id, category_id, name, description, price, active, position
  )
  values (
    p_org_id, v_source.category_id,
    coalesce(nullif(btrim(p_name), ''), v_source.name || ' (copia)'),
    v_source.description, v_source.price, true, v_source.position + 1
  )
  returning id into v_new_id;

  insert into public.service_bundle_items(
    org_id, bundle_id, service_id, position, quantity,
    original_price_snapshot, allocated_price
  )
  select org_id, v_new_id, service_id, position, quantity,
         original_price_snapshot, allocated_price
  from public.service_bundle_items
  where bundle_id = p_bundle_id
    and org_id = p_org_id
  order by position;

  return v_new_id;
end;
$$;

create or replace function public.list_service_bundles_catalog(
  p_org_id uuid,
  p_active_only boolean default false
)
returns table (
  id uuid,
  org_id uuid,
  category_id uuid,
  name text,
  description text,
  price numeric,
  active boolean,
  archived_at timestamptz,
  "position" integer,
  created_at timestamptz,
  updated_at timestamptz,
  service_categories jsonb,
  service_bundle_items jsonb
)
language sql
security invoker
set search_path = public
as $$
  select bundle.id,
         bundle.org_id,
         bundle.category_id,
         bundle.name,
         bundle.description,
         bundle.price,
         bundle.active,
         bundle.archived_at,
         bundle.position,
         bundle.created_at,
         bundle.updated_at,
         case when category.id is null then null else jsonb_build_object(
           'id', category.id,
           'name', category.name,
           'color', category.color
         ) end as service_categories,
         coalesce(
           jsonb_agg(
             jsonb_build_object(
               'id', item.id,
               'org_id', item.org_id,
               'bundle_id', item.bundle_id,
               'service_id', item.service_id,
               'position', item.position,
               'quantity', item.quantity,
               'original_price_snapshot', item.original_price_snapshot,
               'allocated_price', item.allocated_price,
               'services', jsonb_build_object(
                 'id', service.id,
                 'name', service.name,
                 'price', service.price,
                 'duration_minutes', service.duration_minutes
               )
             )
             order by item.position
           ) filter (where item.id is not null),
           '[]'::jsonb
         ) as service_bundle_items
  from public.service_bundles bundle
  left join public.service_categories category
    on category.id = bundle.category_id
   and category.org_id = bundle.org_id
  left join public.service_bundle_items item
    on item.bundle_id = bundle.id
   and item.org_id = bundle.org_id
  left join public.services service
    on service.id = item.service_id
   and service.org_id = item.org_id
  where bundle.org_id = p_org_id
    and bundle.org_id in (select public.auth_org_ids())
    and (not p_active_only or (bundle.active and bundle.archived_at is null))
  group by bundle.id, category.id
  order by bundle.position, bundle.name;
$$;

revoke all on function public.enforce_service_bundle_integrity() from public, anon, authenticated;
revoke all on function public.upsert_service_bundle_atomic(
  uuid, uuid, text, text, uuid, numeric, boolean, integer, jsonb
) from public, anon;
revoke all on function public.archive_service_bundle(uuid, uuid) from public, anon;
revoke all on function public.restore_service_bundle(uuid, uuid) from public, anon;
revoke all on function public.duplicate_service_bundle(uuid, uuid, text) from public, anon;
revoke all on function public.list_service_bundles_catalog(uuid, boolean) from public, anon;

grant execute on function public.upsert_service_bundle_atomic(
  uuid, uuid, text, text, uuid, numeric, boolean, integer, jsonb
) to authenticated;
grant execute on function public.archive_service_bundle(uuid, uuid) to authenticated;
grant execute on function public.restore_service_bundle(uuid, uuid) to authenticated;
grant execute on function public.duplicate_service_bundle(uuid, uuid, text) to authenticated;
grant execute on function public.list_service_bundles_catalog(uuid, boolean) to authenticated;
