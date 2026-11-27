-- Acesso do estúdio em UMA ida ao banco: estúdio (por slug), papel, módulos ativos e permissões da pessoa logada.
-- Antes: user_roles + org_enabled_modules + my_permissions (3 idas, 2 níveis em série) a cada clique.
-- Não muda regra nenhuma: reaproveita org_enabled_modules e my_permissions, que continuam sendo a autoridade.
-- Encoding: UTF-8
create or replace function public.my_org_access(p_slug text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_org public.organizations%rowtype;
  v_role text;
begin
  if v_uid is null then
    raise exception 'Autenticação obrigatória' using errcode = '42501';
  end if;

  select o.* into v_org
  from public.organizations o
  join public.user_roles ur on ur.org_id = o.id and ur.user_id = v_uid and ur.active
  where o.slug = p_slug and o.active
  limit 1;
  if not found then
    return null;
  end if;

  select ur.role::text into v_role
  from public.user_roles ur
  where ur.org_id = v_org.id and ur.user_id = v_uid and ur.active
  limit 1;

  return pg_catalog.jsonb_build_object(
    'org', pg_catalog.jsonb_build_object(
      'id', v_org.id, 'slug', v_org.slug, 'name', v_org.name, 'logo_url', v_org.logo_url, 'plan', v_org.plan,
      'timezone', v_org.timezone, 'currency', v_org.currency, 'locale', v_org.locale, 'settings', v_org.settings,
      'phone', v_org.phone, 'email', v_org.email, 'address', v_org.address, 'city', v_org.city),
    'role', v_role,
    'modules', coalesce((select pg_catalog.jsonb_agg(m) from public.org_enabled_modules(v_org.id) as m), '[]'::jsonb),
    'permissions', pg_catalog.to_jsonb(public.my_permissions(v_org.id))
  );
end;
$$;
revoke all on function public.my_org_access(text) from public, anon;
grant execute on function public.my_org_access(text) to authenticated;
