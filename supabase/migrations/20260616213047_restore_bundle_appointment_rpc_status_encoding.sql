-- HOTFIX CAT-02B: restore canonical UTF-8 appointment statuses in bundle-aware RPCs.
-- Encoding: UTF-8

do $$
declare
  v_function_name text;
  v_function_oid oid;
  v_definition text;
  v_fixed_definition text;
  v_bad_concluido text := 'Conclu' || chr(195) || chr(173) || 'do';
  v_bad_ausencia text := 'Aus' || chr(195) || chr(170) || 'ncia';
begin
  foreach v_function_name in array array[
    'create_appointment_atomic',
    'update_appointment_atomic'
  ]
  loop
    select p.oid
      into v_function_oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = v_function_name
    order by p.oid desc
    limit 1;

    if v_function_oid is null then
      raise exception 'Function %.% not found', 'public', v_function_name
        using errcode = '42883';
    end if;

    v_definition := pg_get_functiondef(v_function_oid);
    v_fixed_definition := replace(
      replace(v_definition, v_bad_concluido, 'Concluído'),
      v_bad_ausencia,
      'Ausência'
    );

    if v_definition <> v_fixed_definition then
      execute v_fixed_definition;
    end if;
  end loop;
end $$;

do $$
declare
  v_create_definition text;
  v_update_definition text;
  v_bad_concluido text := 'Conclu' || chr(195) || chr(173) || 'do';
  v_bad_ausencia text := 'Aus' || chr(195) || chr(170) || 'ncia';
begin
  select pg_get_functiondef(p.oid)
    into v_create_definition
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'create_appointment_atomic'
  order by p.oid desc
  limit 1;

  select pg_get_functiondef(p.oid)
    into v_update_definition
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'update_appointment_atomic'
  order by p.oid desc
  limit 1;

  if v_create_definition like '%' || v_bad_concluido || '%'
    or v_create_definition like '%' || v_bad_ausencia || '%'
    or v_update_definition like '%' || v_bad_concluido || '%'
    or v_update_definition like '%' || v_bad_ausencia || '%'
  then
    raise exception 'Appointment RPC status mojibake remains after hotfix'
      using errcode = '22023';
  end if;

  if v_create_definition not like '%Concluído%'
    or v_create_definition not like '%Ausência%'
    or v_update_definition not like '%Ausência%'
  then
    raise exception 'Appointment RPC canonical status check failed after hotfix'
      using errcode = '22023';
  end if;
end $$;
