-- CAT-01: atomic service/staff and package/item mutations.
-- Encoding: UTF-8

create or replace function public.replace_service_staff_atomic(
  p_org_id uuid,
  p_service_id uuid,
  p_staff_ids uuid[]
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

  if not exists (
    select 1 from public.services
    where id = p_service_id and org_id = p_org_id
  ) then
    raise exception 'service not found' using errcode = 'P0002';
  end if;

  if exists (
    select 1
    from unnest(coalesce(p_staff_ids, '{}'::uuid[])) as requested(staff_id)
    where not exists (
      select 1 from public.staff_members staff
      where staff.id = requested.staff_id and staff.org_id = p_org_id
    )
  ) then
    raise exception 'staff member belongs to another organization' using errcode = '23514';
  end if;

  delete from public.service_staff
  where service_id = p_service_id
    and org_id = p_org_id;

  insert into public.service_staff(service_id, staff_id, org_id)
  select p_service_id, selected.staff_id, p_org_id
  from (
    select distinct unnest(coalesce(p_staff_ids, '{}'::uuid[])) as staff_id
  ) selected;
end;
$$;

create or replace function public.upsert_catalog_service_atomic(
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
  p_staff_ids uuid[]
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_service_id uuid;
  v_price numeric(10,2);
begin
  if public.auth_user_role(p_org_id) not in ('owner', 'admin', 'manager') then
    raise exception 'catalog permission denied' using errcode = '42501';
  end if;

  if btrim(coalesce(p_name, '')) = ''
    or p_price < 0
    or p_price_type not in ('free', 'from', 'fixed', 'on_request')
    or p_duration_minutes not between 15 and 480
    or p_buffer_minutes not between 0 and 120
    or p_commission_pct not between 0 and 100
  then
    raise exception 'invalid service data' using errcode = '22023';
  end if;

  if p_category_id is not null and not exists (
    select 1 from public.service_categories
    where id = p_category_id and org_id = p_org_id
  ) then
    raise exception 'category belongs to another organization' using errcode = '23514';
  end if;

  if p_anamnese_template_id is not null and not exists (
    select 1 from public.anamnese_templates
    where id = p_anamnese_template_id and org_id = p_org_id
  ) then
    raise exception 'anamnese template belongs to another organization' using errcode = '23514';
  end if;

  if exists (
    select 1
    from unnest(coalesce(p_staff_ids, '{}'::uuid[])) as requested(staff_id)
    where not exists (
      select 1 from public.staff_members staff
      where staff.id = requested.staff_id and staff.org_id = p_org_id
    )
  ) then
    raise exception 'staff member belongs to another organization' using errcode = '23514';
  end if;

  v_price := case
    when p_price_type in ('free', 'on_request') then 0
    else p_price
  end;

  if p_service_id is null then
    insert into public.services (
      org_id, category_id, name, description, price, price_type, cost_amount,
      duration_minutes, buffer_minutes, requires_anamnese,
      anamnese_template_id, online_booking, commission_pct, position, active
    )
    values (
      p_org_id, p_category_id, btrim(p_name),
      nullif(btrim(coalesce(p_description, '')), ''), v_price, p_price_type, 0,
      p_duration_minutes, p_buffer_minutes, p_requires_anamnese,
      p_anamnese_template_id, p_online_booking, p_commission_pct, 0, p_active
    )
    returning id into v_service_id;
  else
    update public.services
    set category_id = p_category_id,
        name = btrim(p_name),
        description = nullif(btrim(coalesce(p_description, '')), ''),
        price = v_price,
        price_type = p_price_type,
        duration_minutes = p_duration_minutes,
        buffer_minutes = p_buffer_minutes,
        requires_anamnese = p_requires_anamnese,
        anamnese_template_id = p_anamnese_template_id,
        online_booking = p_online_booking,
        commission_pct = p_commission_pct,
        active = p_active
    where id = p_service_id
      and org_id = p_org_id
    returning id into v_service_id;

    if v_service_id is null then
      raise exception 'service not found' using errcode = 'P0002';
    end if;
  end if;

  perform public.replace_service_staff_atomic(p_org_id, v_service_id, p_staff_ids);
  return v_service_id;
end;
$$;

create or replace function public.upsert_service_package_atomic(
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
set search_path = public
as $$
declare
  v_package_id uuid;
begin
  if public.auth_user_role(p_org_id) not in ('owner', 'admin', 'manager') then
    raise exception 'catalog permission denied' using errcode = '42501';
  end if;

  if btrim(coalesce(p_name, '')) = ''
    or p_price < 0
    or p_sessions < 1
    or p_validity_days < 1
    or cardinality(coalesce(p_service_ids, '{}'::uuid[])) < 1
  then
    raise exception 'invalid package data' using errcode = '22023';
  end if;

  if exists (
    select 1
    from unnest(p_service_ids) as requested(service_id)
    where not exists (
      select 1 from public.services service
      where service.id = requested.service_id and service.org_id = p_org_id
    )
  ) then
    raise exception 'service belongs to another organization' using errcode = '23514';
  end if;

  if p_package_id is null then
    insert into public.service_packages (
      org_id, name, description, price, sessions, validity_days,
      online_booking, active, position
    )
    values (
      p_org_id, btrim(p_name), nullif(btrim(coalesce(p_description, '')), ''),
      p_price, p_sessions, p_validity_days, p_online_booking, p_active, 0
    )
    returning id into v_package_id;
  else
    update public.service_packages
    set name = btrim(p_name),
        description = nullif(btrim(coalesce(p_description, '')), ''),
        price = p_price,
        sessions = p_sessions,
        validity_days = p_validity_days,
        online_booking = p_online_booking,
        active = p_active
    where id = p_package_id
      and org_id = p_org_id
    returning id into v_package_id;

    if v_package_id is null then
      raise exception 'package not found' using errcode = 'P0002';
    end if;
  end if;

  delete from public.package_services
  where package_id = v_package_id
    and org_id = p_org_id;

  insert into public.package_services(org_id, package_id, service_id, qty)
  select p_org_id, v_package_id, selected.service_id, 1
  from (
    select distinct unnest(p_service_ids) as service_id
  ) selected;

  return v_package_id;
end;
$$;

revoke all on function public.replace_service_staff_atomic(uuid, uuid, uuid[])
  from public, anon;
revoke all on function public.upsert_catalog_service_atomic(
  uuid, uuid, uuid, text, text, numeric, text, integer, integer, numeric,
  boolean, uuid, boolean, boolean, uuid[]
) from public, anon;
revoke all on function public.upsert_service_package_atomic(
  uuid, uuid, text, text, numeric, integer, integer, boolean, boolean, uuid[]
) from public, anon;

grant execute on function public.replace_service_staff_atomic(uuid, uuid, uuid[])
  to authenticated;
grant execute on function public.upsert_catalog_service_atomic(
  uuid, uuid, uuid, text, text, numeric, text, integer, integer, numeric,
  boolean, uuid, boolean, boolean, uuid[]
) to authenticated;
grant execute on function public.upsert_service_package_atomic(
  uuid, uuid, text, text, numeric, integer, integer, boolean, boolean, uuid[]
) to authenticated;
