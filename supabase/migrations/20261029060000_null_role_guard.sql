-- Revisão de funções de 29 out, parte 3: papel nulo (quem não é membro do estúdio).
-- Encoding: UTF-8.
-- Nas RPCs SECURITY INVOKER, `if v_role not in (...)` deixava passar papel nulo (NULL not in
-- (...) é NULL, e o IF não dispara). Hoje a RLS segura essas chamadas, mas a regra precisa
-- valer na própria função. Esta migration ajusta todas as funções do schema public com
-- esses dois padrões, sem reescrever o resto do corpo:
--   if v_role not in (                       -> if v_role is null or v_role not in (
--   if public.auth_user_role(p_org_id) not in ( -> if coalesce(public.auth_user_role(p_org_id), '') not in (
-- Linhas do tipo `if p_force_override and v_role not in (...)` não mudam (vêm depois da
-- guarda principal, que já barrou o papel nulo).
set client_encoding = 'UTF8';

do $$
declare
  r record;
  v_def text;
  v_new text;
  v_count integer := 0;
begin
  for r in
    select p.oid, p.proname
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prokind = 'f'
      and (p.prosrc ~ 'if v_role not in \(' or p.prosrc ~ 'if public\.auth_user_role\(p_org_id\) not in \(')
  loop
    v_def := pg_catalog.pg_get_functiondef(r.oid);
    v_new := pg_catalog.regexp_replace(v_def, 'if v_role not in \(', 'if v_role is null or v_role not in (', 'g');
    v_new := pg_catalog.regexp_replace(v_new, 'if public\.auth_user_role\(p_org_id\) not in \(',
      'if coalesce(public.auth_user_role(p_org_id), '''') not in (', 'g');
    if v_new = v_def then
      raise exception 'Nada a ajustar em %', r.proname;
    end if;
    execute v_new;
    v_count := v_count + 1;
  end loop;

  if exists (
    select 1
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and (p.prosrc ~ 'if v_role not in \(' or p.prosrc ~ 'if public\.auth_user_role\(p_org_id\) not in \(')
  ) then
    raise exception 'Ainda há função sem a guarda de papel nulo';
  end if;
  raise notice 'Guarda de papel nulo aplicada em % funções', v_count;
end $$;
