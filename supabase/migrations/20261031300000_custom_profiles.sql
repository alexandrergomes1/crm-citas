-- Perfis personalizados por estúdio (spec 28/Lote 3).
-- Encoding: UTF-8
--
-- Modelo: um perfil personalizado é um nome + um papel-base (admin, manager, receptionist,
-- professional, finance, viewer). O papel-base continua em user_roles.role, então toda política
-- de RLS que olha o papel segue valendo. As liberações próprias do perfil (org_profile_permissions)
-- são exceções ao papel-base e valem onde o banco já usa has_permission().
-- Ordem de resolução: exceção do perfil > exceção do papel no estúdio > padrão do papel.

-- 1. Perfis ------------------------------------------------------------------------------------
create table if not exists public.org_profiles (
  id         uuid        primary key default gen_random_uuid(),
  org_id     uuid        not null references public.organizations(id) on delete cascade,
  name       text        not null check (char_length(btrim(name)) between 2 and 40),
  base_role  text        not null check (base_role in ('admin', 'manager', 'receptionist', 'professional', 'finance', 'viewer')),
  created_by uuid        references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
comment on table public.org_profiles is 'Perfis de acesso criados pelo estúdio, apoiados num papel-base.';
create unique index if not exists org_profiles_org_name_key on public.org_profiles (org_id, lower(btrim(name)));
create index if not exists org_profiles_created_by_idx on public.org_profiles (created_by) where created_by is not null;

create table if not exists public.org_profile_permissions (
  profile_id uuid        not null references public.org_profiles(id) on delete cascade,
  org_id     uuid        not null references public.organizations(id) on delete cascade,
  permission text        not null,
  allowed    boolean     not null,
  updated_by uuid        references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  primary key (profile_id, permission)
);
comment on table public.org_profile_permissions is 'Exceções de um perfil personalizado ao padrão do papel-base. Sem linha vale o padrão do papel-base.';
create index if not exists org_profile_permissions_org_idx on public.org_profile_permissions (org_id);
create index if not exists org_profile_permissions_updated_by_idx on public.org_profile_permissions (updated_by) where updated_by is not null;

alter table public.user_roles add column if not exists profile_id uuid references public.org_profiles(id) on delete set null;
create index if not exists user_roles_profile_idx on public.user_roles (profile_id) where profile_id is not null;

alter table public.org_profiles enable row level security;
alter table public.org_profile_permissions enable row level security;
revoke all on public.org_profiles from anon;
revoke all on public.org_profile_permissions from anon;
revoke insert, update, delete, truncate, trigger, references on public.org_profiles from authenticated;
revoke insert, update, delete, truncate, trigger, references on public.org_profile_permissions from authenticated;

drop policy if exists org_profiles_select on public.org_profiles;
create policy org_profiles_select on public.org_profiles
  for select to authenticated
  using (public.has_permission(org_id, 'acesso.manage') or public.has_permission(org_id, 'equipe.manage'));

drop policy if exists org_profile_permissions_select on public.org_profile_permissions;
create policy org_profile_permissions_select on public.org_profile_permissions
  for select to authenticated
  using (public.has_permission(org_id, 'acesso.manage'));

-- 2. Resolução ---------------------------------------------------------------------------------
create or replace function public.has_permission(p_org_id uuid, p_permission text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role text;
  v_profile uuid;
  v_allowed boolean;
begin
  select ur.role::text, ur.profile_id into v_role, v_profile
  from public.user_roles ur
  where ur.user_id = (select auth.uid()) and ur.org_id = p_org_id and ur.active = true
  limit 1;
  if v_role is null then
    return false;
  end if;
  if v_role <> 'owner' then
    if v_profile is not null then
      select opp.allowed into v_allowed
      from public.org_profile_permissions opp
      where opp.profile_id = v_profile and opp.permission = p_permission;
      if found then
        return v_allowed;
      end if;
    end if;
    select orp.allowed into v_allowed
    from public.org_role_permissions orp
    where orp.org_id = p_org_id and orp.role = v_role and orp.permission = p_permission;
    if found then
      return v_allowed;
    end if;
  end if;
  return exists (
    select 1 from public.role_default_permissions() d
    where d.role = v_role and d.permission = p_permission
  );
end;
$$;

-- 3. Criar e apagar perfil ---------------------------------------------------------------------
create or replace function public.create_org_profile(p_org_id uuid, p_name text, p_base_role text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_role text;
  v_id uuid;
  v_name text := pg_catalog.btrim(coalesce(p_name, ''));
begin
  if auth.uid() is null then
    raise exception 'Autenticacao obrigatoria' using errcode = '42501';
  end if;
  v_actor_role := public.auth_user_role(p_org_id);
  if v_actor_role is null or not public.has_permission(p_org_id, 'acesso.manage') then
    raise exception 'Sem permissao para criar perfis' using errcode = '42501';
  end if;
  if p_base_role not in ('admin', 'manager', 'receptionist', 'professional', 'finance', 'viewer') then
    raise exception 'Perfil-base invalido' using errcode = '22023';
  end if;
  if pg_catalog.char_length(v_name) < 2 or pg_catalog.char_length(v_name) > 40 then
    raise exception 'Nome invalido' using errcode = '22023';
  end if;
  if p_base_role = 'admin' and v_actor_role <> 'owner' then
    raise exception 'Somente a proprietaria cria perfil baseado em Administracao' using errcode = '42501';
  end if;
  insert into public.org_profiles (org_id, name, base_role, created_by)
  values (p_org_id, v_name, p_base_role, auth.uid())
  returning id into v_id;
  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (p_org_id, auth.uid(), 'org_profiles', 'PROFILE_CREATED', v_id, null,
          pg_catalog.jsonb_build_object('name', v_name, 'base_role', p_base_role));
  return v_id;
end;
$$;

create or replace function public.delete_org_profile(p_org_id uuid, p_profile_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_role text;
  v_profile public.org_profiles%rowtype;
  v_users integer;
begin
  if auth.uid() is null then
    raise exception 'Autenticacao obrigatoria' using errcode = '42501';
  end if;
  v_actor_role := public.auth_user_role(p_org_id);
  if v_actor_role is null or not public.has_permission(p_org_id, 'acesso.manage') then
    raise exception 'Sem permissao para apagar perfis' using errcode = '42501';
  end if;
  select * into v_profile from public.org_profiles where id = p_profile_id and org_id = p_org_id;
  if not found then
    return false;
  end if;
  if v_profile.base_role = 'admin' and v_actor_role <> 'owner' then
    raise exception 'Somente a proprietaria apaga este perfil' using errcode = '42501';
  end if;
  select pg_catalog.count(*) into v_users from public.user_roles where org_id = p_org_id and profile_id = p_profile_id;
  delete from public.org_profiles where id = p_profile_id and org_id = p_org_id;
  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (p_org_id, auth.uid(), 'org_profiles', 'PROFILE_DELETED', p_profile_id,
          pg_catalog.jsonb_build_object('name', v_profile.name, 'base_role', v_profile.base_role, 'users', v_users), null);
  return true;
end;
$$;

-- 4. Liberações do perfil ----------------------------------------------------------------------
create or replace function public.set_profile_permission(
  p_org_id uuid, p_profile_id uuid, p_permission text, p_allowed boolean
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_role text;
  v_profile public.org_profiles%rowtype;
  v_base boolean;
  v_old boolean;
begin
  if auth.uid() is null then
    raise exception 'Autenticacao obrigatoria' using errcode = '42501';
  end if;
  v_actor_role := public.auth_user_role(p_org_id);
  if v_actor_role is null or not public.has_permission(p_org_id, 'acesso.manage') then
    raise exception 'Sem permissao para alterar liberacoes' using errcode = '42501';
  end if;
  if p_allowed is null then
    raise exception 'Valor invalido' using errcode = '22023';
  end if;
  select * into v_profile from public.org_profiles where id = p_profile_id and org_id = p_org_id;
  if not found then
    raise exception 'Perfil inexistente' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.role_default_permissions() d where d.role = 'owner' and d.permission = p_permission
  ) then
    raise exception 'Permissao desconhecida' using errcode = '22023';
  end if;
  if v_actor_role <> 'owner' and (v_profile.base_role = 'admin' or p_permission like 'acesso.%') then
    raise exception 'Somente a proprietaria altera esta liberacao' using errcode = '42501';
  end if;
  if p_allowed and v_actor_role <> 'owner' and not public.has_permission(p_org_id, p_permission) then
    raise exception 'Voce nao pode conceder uma liberacao que nao possui' using errcode = '42501';
  end if;

  -- Padrão do papel-base já com as exceções do estúdio.
  select coalesce(
    (select orp.allowed from public.org_role_permissions orp
      where orp.org_id = p_org_id and orp.role = v_profile.base_role and orp.permission = p_permission),
    exists (select 1 from public.role_default_permissions() d where d.role = v_profile.base_role and d.permission = p_permission)
  ) into v_base;
  select opp.allowed into v_old
  from public.org_profile_permissions opp
  where opp.profile_id = p_profile_id and opp.permission = p_permission;
  v_old := coalesce(v_old, v_base);

  if p_allowed = v_base then
    delete from public.org_profile_permissions where profile_id = p_profile_id and permission = p_permission;
  else
    insert into public.org_profile_permissions (profile_id, org_id, permission, allowed, updated_by)
    values (p_profile_id, p_org_id, p_permission, p_allowed, auth.uid())
    on conflict (profile_id, permission)
    do update set allowed = excluded.allowed, updated_by = excluded.updated_by, updated_at = now();
  end if;

  if v_old is distinct from p_allowed then
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
    values (
      p_org_id, auth.uid(), 'org_profile_permissions', 'PROFILE_PERMISSION_SET', p_profile_id,
      pg_catalog.jsonb_build_object('profile', v_profile.name, 'permission', p_permission, 'allowed', v_old),
      pg_catalog.jsonb_build_object('profile', v_profile.name, 'permission', p_permission, 'allowed', p_allowed)
    );
  end if;
  return v_old is distinct from p_allowed;
end;
$$;

create or replace function public.set_profile_permissions(p_org_id uuid, p_profile_id uuid, p_changes jsonb)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_change jsonb;
  v_count integer := 0;
begin
  if p_changes is null or pg_catalog.jsonb_typeof(p_changes) <> 'array'
     or pg_catalog.jsonb_array_length(p_changes) = 0 or pg_catalog.jsonb_array_length(p_changes) > 10 then
    raise exception 'Lista de liberacoes invalida' using errcode = '22023';
  end if;
  for v_change in select * from pg_catalog.jsonb_array_elements(p_changes) loop
    if pg_catalog.jsonb_typeof(v_change -> 'permission') <> 'string'
       or pg_catalog.jsonb_typeof(v_change -> 'allowed') <> 'boolean' then
      raise exception 'Liberacao invalida' using errcode = '22023';
    end if;
    perform public.set_profile_permission(p_org_id, p_profile_id, v_change ->> 'permission', (v_change ->> 'allowed')::boolean);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- Matriz dos perfis personalizados para a tela de administração.
create or replace function public.get_profile_matrix(p_org_id uuid)
returns table (profile_id uuid, permission text, allowed boolean, is_override boolean, default_allowed boolean)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.has_permission(p_org_id, 'acesso.manage') then
    raise exception 'Sem permissao para ver as liberacoes' using errcode = '42501';
  end if;
  return query
  select p.id, c.permission,
         coalesce(o.allowed, b.base_allowed) as allowed,
         o.allowed is not null as is_override,
         b.base_allowed as default_allowed
  from public.org_profiles p
  cross join (select distinct x.permission from public.role_default_permissions() x where x.role = 'owner') c
  cross join lateral (
    select coalesce(
      (select orp.allowed from public.org_role_permissions orp
        where orp.org_id = p.org_id and orp.role = p.base_role and orp.permission = c.permission),
      exists (select 1 from public.role_default_permissions() d where d.role = p.base_role and d.permission = c.permission)
    ) as base_allowed
  ) b
  left join public.org_profile_permissions o on o.profile_id = p.id and o.permission = c.permission
  where p.org_id = p_org_id
  order by p.created_at, c.permission;
end;
$$;

-- 5. Perfil de cada acesso ---------------------------------------------------------------------
-- p_profile_id nulo + p_role: papel padrão do sistema. p_profile_id preenchido: perfil personalizado
-- (o papel gravado passa a ser o papel-base do perfil).
create or replace function public.assign_user_profile(p_org_id uuid, p_user_id uuid, p_role text, p_profile_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_role text;
  v_old public.user_roles%rowtype;
  v_new_role text;
  v_profile public.org_profiles%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Autenticacao obrigatoria' using errcode = '42501';
  end if;
  v_actor_role := public.auth_user_role(p_org_id);
  if v_actor_role is null or not public.has_permission(p_org_id, 'equipe.manage') then
    raise exception 'Sem permissao para alterar acessos' using errcode = '42501';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'Voce nao altera o proprio perfil' using errcode = '42501';
  end if;
  if (p_role is null) = (p_profile_id is null) then
    raise exception 'Informe o papel ou o perfil' using errcode = '22023';
  end if;
  select * into v_old from public.user_roles where org_id = p_org_id and user_id = p_user_id and active = true;
  if not found then
    raise exception 'Acesso inexistente' using errcode = '22023';
  end if;
  if v_old.role = 'owner' then
    raise exception 'O perfil da proprietaria nao muda' using errcode = '42501';
  end if;
  if p_profile_id is not null then
    select * into v_profile from public.org_profiles where id = p_profile_id and org_id = p_org_id;
    if not found then
      raise exception 'Perfil inexistente' using errcode = '22023';
    end if;
    v_new_role := v_profile.base_role;
  else
    if p_role not in ('admin', 'manager', 'receptionist', 'professional', 'finance', 'viewer') then
      raise exception 'Papel invalido' using errcode = '22023';
    end if;
    v_new_role := p_role;
  end if;
  -- Administração só é dada ou retirada pela proprietária ou por outra administração.
  if (v_new_role = 'admin' or v_old.role = 'admin') and v_actor_role not in ('owner', 'admin') then
    raise exception 'Somente a proprietaria ou a administracao alteram Administracao' using errcode = '42501';
  end if;

  update public.user_roles set role = v_new_role, profile_id = p_profile_id
  where id = v_old.id;
  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (p_org_id, auth.uid(), 'user_roles', 'ACCESS_PROFILE_CHANGED', p_user_id,
          pg_catalog.jsonb_build_object('role', v_old.role, 'profile_id', v_old.profile_id),
          pg_catalog.jsonb_build_object('role', v_new_role, 'profile_id', p_profile_id));
  return true;
end;
$$;

-- 6. Permissões de execução --------------------------------------------------------------------
revoke all on function public.has_permission(uuid, text) from public, anon;
revoke all on function public.create_org_profile(uuid, text, text) from public, anon;
revoke all on function public.delete_org_profile(uuid, uuid) from public, anon;
revoke all on function public.set_profile_permission(uuid, uuid, text, boolean) from public, anon;
revoke all on function public.set_profile_permissions(uuid, uuid, jsonb) from public, anon;
revoke all on function public.get_profile_matrix(uuid) from public, anon;
revoke all on function public.assign_user_profile(uuid, uuid, text, uuid) from public, anon;
grant execute on function public.has_permission(uuid, text) to authenticated, service_role;
grant execute on function public.create_org_profile(uuid, text, text) to authenticated;
grant execute on function public.delete_org_profile(uuid, uuid) to authenticated;
grant execute on function public.set_profile_permission(uuid, uuid, text, boolean) to authenticated;
grant execute on function public.set_profile_permissions(uuid, uuid, jsonb) to authenticated;
grant execute on function public.get_profile_matrix(uuid) to authenticated;
grant execute on function public.assign_user_profile(uuid, uuid, text, uuid) to authenticated;
