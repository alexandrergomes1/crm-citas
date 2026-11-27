-- Contexto de acesso do pedido em UMA ida ao banco, pelo slug OU pelo id do estúdio:
-- estúdio, papel, módulos ativos e permissões (como my_org_access) e, com p_shell, o nome no menu
-- (profiles.full_name) e as preferências (user_preferences.prefs) da própria pessoa.
-- Antes: por id eram organizations + user_roles + org_enabled_modules + my_permissions (4 idas);
-- o casco somava my_org_access + profiles + user_preferences (3 idas).
-- Não muda regra nenhuma: reaproveita org_enabled_modules e my_permissions, que continuam sendo a autoridade;
-- perfil e preferências só da pessoa logada, no estúdio em que ela tem papel ativo. RLS das tabelas não muda.
-- Encoding: UTF-8
create or replace function public.my_access_context(
  p_slug text default null,
  p_org_id uuid default null,
  p_shell boolean default false
)
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
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Autenticação obrigatória' using errcode = '42501';
  end if;
  if p_slug is null and p_org_id is null then
    return null;
  end if;

  select o.* into v_org
  from public.organizations o
  join public.user_roles ur on ur.org_id = o.id and ur.user_id = v_uid and ur.active
  where (p_slug is null or o.slug = p_slug)
    and (p_org_id is null or o.id = p_org_id)
    and o.active
  limit 1;
  if not found then
    return null;
  end if;

  select ur.role::text into v_role
  from public.user_roles ur
  where ur.org_id = v_org.id and ur.user_id = v_uid and ur.active
  limit 1;

  v_result := pg_catalog.jsonb_build_object(
    'org', pg_catalog.jsonb_build_object(
      'id', v_org.id, 'slug', v_org.slug, 'name', v_org.name, 'logo_url', v_org.logo_url, 'plan', v_org.plan,
      'timezone', v_org.timezone, 'currency', v_org.currency, 'locale', v_org.locale, 'settings', v_org.settings,
      'phone', v_org.phone, 'email', v_org.email, 'address', v_org.address, 'city', v_org.city),
    'role', v_role,
    'modules', coalesce((select pg_catalog.jsonb_agg(m) from public.org_enabled_modules(v_org.id) as m), '[]'::jsonb),
    'permissions', pg_catalog.to_jsonb(public.my_permissions(v_org.id))
  );

  if p_shell then
    v_result := v_result || pg_catalog.jsonb_build_object(
      'display_name', (select p.full_name from public.profiles p
                       where p.org_id = v_org.id and p.user_id = v_uid limit 1),
      'prefs', (select up.prefs from public.user_preferences up
                where up.org_id = v_org.id and up.user_id = v_uid)
    );
  end if;

  return v_result;
end;
$$;
revoke all on function public.my_access_context(text, uuid, boolean) from public, anon;
grant execute on function public.my_access_context(text, uuid, boolean) to authenticated;
