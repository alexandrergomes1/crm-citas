-- Perfis e liberações configuráveis por estúdio (spec 37, fase 1).
-- Encoding: UTF-8
--
-- Modelo: o padrão de cada papel vive em role_default_permissions() (espelho de
-- ROLE_PERMISSIONS em src/domain/access.ts, comparado por teste). Cada estúdio guarda só
-- as exceções em org_role_permissions. has_permission() resolve: owner tem tudo; exceção
-- do estúdio vence o padrão.
--
-- Fase 1 converte para has_permission: anamnese (leitura clínica, preenchimento, status,
-- fotos), caixa (fechar comanda, sinal, saldo do cliente) e leitura de transactions.
-- O restante continua com lista fixa de papéis até a fase 2.

-- 1. Padrão por papel --------------------------------------------------------------------------
create or replace function public.role_default_permissions()
returns table (role text, permission text)
language sql
immutable
set search_path = ''
as $$
  select r.role, p.permission
  from (values
    ('owner', array['agenda.view_all', 'agenda.view_own', 'agenda.manage', 'clientes.view', 'clientes.manage', 'clientes.view_clinical', 'catalogo.view', 'catalogo.manage', 'comanda.operate', 'comanda.refund', 'financeiro.view', 'financeiro.manage', 'anamnese.view_status', 'anamnese.fill_professional', 'anamnese.manage_templates', 'mensagens.use', 'mensagens.configure', 'equipe.view', 'equipe.manage', 'acesso.manage', 'acesso.grant_admin', 'ajustes.manage']),
    ('admin', array['agenda.view_all', 'agenda.view_own', 'agenda.manage', 'clientes.view', 'clientes.manage', 'clientes.view_clinical', 'catalogo.view', 'catalogo.manage', 'comanda.operate', 'comanda.refund', 'financeiro.view', 'financeiro.manage', 'anamnese.view_status', 'anamnese.fill_professional', 'anamnese.manage_templates', 'mensagens.use', 'mensagens.configure', 'equipe.view', 'equipe.manage', 'acesso.manage', 'ajustes.manage']),
    ('manager', array['agenda.view_all', 'agenda.view_own', 'agenda.manage', 'clientes.view', 'clientes.manage', 'clientes.view_clinical', 'catalogo.view', 'catalogo.manage', 'comanda.operate', 'comanda.refund', 'financeiro.view', 'financeiro.manage', 'anamnese.view_status', 'anamnese.fill_professional', 'anamnese.manage_templates', 'mensagens.use', 'mensagens.configure', 'equipe.view', 'equipe.manage']),
    ('receptionist', array['agenda.view_all', 'agenda.view_own', 'agenda.manage', 'clientes.view', 'clientes.manage', 'catalogo.view', 'comanda.operate', 'anamnese.view_status', 'mensagens.use', 'equipe.view']),
    ('professional', array['agenda.view_own', 'clientes.view', 'clientes.view_clinical', 'catalogo.view', 'anamnese.view_status', 'anamnese.fill_professional', 'mensagens.use']),
    ('finance', array['agenda.view_all', 'clientes.view', 'catalogo.view', 'comanda.operate', 'comanda.refund', 'financeiro.view', 'financeiro.manage', 'equipe.view']),
    ('viewer', array['agenda.view_all', 'clientes.view', 'catalogo.view', 'equipe.view'])
  ) as r(role, perms),
  unnest(r.perms) as p(permission);
$$;

-- 2. Exceções por estúdio ----------------------------------------------------------------------
create table if not exists public.org_role_permissions (
  org_id     uuid        not null references public.organizations(id) on delete cascade,
  role       text        not null check (role in ('admin', 'manager', 'receptionist', 'professional', 'finance', 'viewer')),
  permission text        not null,
  allowed    boolean     not null,
  updated_by uuid        references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  primary key (org_id, role, permission)
);
comment on table public.org_role_permissions is
  'Exceções do estúdio à matriz padrão de permissões por papel (spec 37). Sem linha vale o padrão.';

alter table public.org_role_permissions enable row level security;
revoke all on public.org_role_permissions from anon;
revoke insert, update, delete, truncate, trigger, references on public.org_role_permissions from authenticated;

-- 3. Resolução ---------------------------------------------------------------------------------
create or replace function public.has_permission(p_org_id uuid, p_permission text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role text;
  v_allowed boolean;
begin
  v_role := public.auth_user_role(p_org_id);
  if v_role is null then
    return false;
  end if;
  if v_role <> 'owner' then
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

drop policy if exists org_role_permissions_select on public.org_role_permissions;
create policy org_role_permissions_select on public.org_role_permissions
  for select to authenticated
  using (public.has_permission(org_id, 'acesso.manage'));

-- Lista efetiva da pessoa logada (a interface usa para esconder o que ela não pode).
create or replace function public.my_permissions(p_org_id uuid)
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(c.permission order by c.permission), array[]::text[])
  from (select distinct d.permission from public.role_default_permissions() d where d.role = 'owner') c
  where public.has_permission(p_org_id, c.permission);
$$;

-- Matriz completa para a tela de administração (só quem gerencia acessos).
create or replace function public.get_permission_matrix(p_org_id uuid)
returns table (role text, permission text, allowed boolean, is_override boolean, default_allowed boolean)
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
  select r.role, c.permission,
         coalesce(o.allowed, d.permission is not null) as allowed,
         o.allowed is not null as is_override,
         d.permission is not null as default_allowed
  from (select distinct x.role from public.role_default_permissions() x) r
  cross join (select distinct x.permission from public.role_default_permissions() x where x.role = 'owner') c
  left join public.role_default_permissions() d on d.role = r.role and d.permission = c.permission
  left join public.org_role_permissions o
    on o.org_id = p_org_id and o.role = r.role and o.permission = c.permission and r.role <> 'owner'
  order by r.role, c.permission;
end;
$$;

-- 4. Alteração auditada ------------------------------------------------------------------------
create or replace function public.set_role_permission(
  p_org_id uuid, p_role text, p_permission text, p_allowed boolean
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_role text;
  v_default boolean;
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
  if p_role not in ('admin', 'manager', 'receptionist', 'professional', 'finance', 'viewer') then
    raise exception 'Perfil nao editavel' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.role_default_permissions() d where d.role = 'owner' and d.permission = p_permission
  ) then
    raise exception 'Permissao desconhecida' using errcode = '22023';
  end if;
  -- Liberações da administração e de acessos só a proprietária altera.
  if v_actor_role <> 'owner' and (p_role = 'admin' or p_permission like 'acesso.%') then
    raise exception 'Somente a proprietaria altera esta liberacao' using errcode = '42501';
  end if;
  -- Quem não é proprietária não concede o que ela mesma não tem.
  if p_allowed and v_actor_role <> 'owner' and not public.has_permission(p_org_id, p_permission) then
    raise exception 'Voce nao pode conceder uma liberacao que nao possui' using errcode = '42501';
  end if;

  v_default := exists (
    select 1 from public.role_default_permissions() d where d.role = p_role and d.permission = p_permission
  );
  select orp.allowed into v_old
  from public.org_role_permissions orp
  where orp.org_id = p_org_id and orp.role = p_role and orp.permission = p_permission;
  v_old := coalesce(v_old, v_default);

  if p_allowed = v_default then
    delete from public.org_role_permissions
    where org_id = p_org_id and role = p_role and permission = p_permission;
  else
    insert into public.org_role_permissions (org_id, role, permission, allowed, updated_by)
    values (p_org_id, p_role, p_permission, p_allowed, auth.uid())
    on conflict (org_id, role, permission)
    do update set allowed = excluded.allowed, updated_by = excluded.updated_by, updated_at = now();
  end if;

  if v_old is distinct from p_allowed then
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
    values (
      p_org_id, auth.uid(), 'org_role_permissions', 'ROLE_PERMISSION_SET', null,
      pg_catalog.jsonb_build_object('role', p_role, 'permission', p_permission, 'allowed', v_old),
      pg_catalog.jsonb_build_object('role', p_role, 'permission', p_permission, 'allowed', p_allowed)
    );
  end if;
  return v_old is distinct from p_allowed;
end;
$$;

create or replace function public.reset_role_permissions(p_org_id uuid, p_role text)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_role text;
  v_removed integer;
  v_before jsonb;
begin
  if auth.uid() is null then
    raise exception 'Autenticacao obrigatoria' using errcode = '42501';
  end if;
  v_actor_role := public.auth_user_role(p_org_id);
  if v_actor_role is null or not public.has_permission(p_org_id, 'acesso.manage') then
    raise exception 'Sem permissao para alterar liberacoes' using errcode = '42501';
  end if;
  if p_role not in ('admin', 'manager', 'receptionist', 'professional', 'finance', 'viewer') then
    raise exception 'Perfil nao editavel' using errcode = '22023';
  end if;
  if v_actor_role <> 'owner' and p_role = 'admin' then
    raise exception 'Somente a proprietaria altera esta liberacao' using errcode = '42501';
  end if;

  -- Quem não é proprietária não mexe nas exceções de acesso (acesso.*).
  select coalesce(pg_catalog.jsonb_object_agg(o.permission, o.allowed), '{}'::jsonb)
    into v_before
  from public.org_role_permissions o
  where o.org_id = p_org_id and o.role = p_role
    and (v_actor_role = 'owner' or o.permission not like 'acesso.%');

  delete from public.org_role_permissions o
  where o.org_id = p_org_id and o.role = p_role
    and (v_actor_role = 'owner' or o.permission not like 'acesso.%');
  get diagnostics v_removed = row_count;

  if v_removed > 0 then
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
    values (
      p_org_id, auth.uid(), 'org_role_permissions', 'ROLE_PERMISSIONS_RESET', null,
      pg_catalog.jsonb_build_object('role', p_role, 'overrides', v_before),
      pg_catalog.jsonb_build_object('role', p_role, 'overrides', '{}'::jsonb)
    );
  end if;
  return v_removed;
end;
$$;

revoke all on function public.role_default_permissions() from public, anon;
revoke all on function public.has_permission(uuid, text) from public, anon;
revoke all on function public.my_permissions(uuid) from public, anon;
revoke all on function public.get_permission_matrix(uuid) from public, anon;
revoke all on function public.set_role_permission(uuid, text, text, boolean) from public, anon;
revoke all on function public.reset_role_permissions(uuid, text) from public, anon;
grant execute on function public.role_default_permissions() to authenticated, service_role;
grant execute on function public.has_permission(uuid, text) to authenticated, service_role;
grant execute on function public.my_permissions(uuid) to authenticated, service_role;
grant execute on function public.get_permission_matrix(uuid) to authenticated, service_role;
grant execute on function public.set_role_permission(uuid, text, text, boolean) to authenticated, service_role;
grant execute on function public.reset_role_permissions(uuid, text) to authenticated, service_role;

-- 5. Funções que passam a respeitar as liberações -----------------------------------------------
-- Cada troca é exata: o padrão precisa aparecer uma única vez, senão a migration falha.
do $rewrite$
declare
  r record;
  v_def text;
  v_count integer;
begin
  for r in
    select * from (values
      ('adjust_client_balance_atomic',
       'v_role not in \(''owner'', ''admin'', ''manager''\)',
       'not public.has_permission(p_org_id, ''financeiro.manage'')'),
      ('reverse_client_balance_entry_atomic',
       'v_role not in \(''owner'', ''admin'', ''manager'', ''finance''\)',
       'not public.has_permission(p_org_id, ''comanda.refund'')'),
      ('confirm_checkout_atomic',
       'v_role not in \(\s*''owner'', ''admin'', ''manager'', ''receptionist'', ''finance''\s*\)',
       'not public.has_permission(p_org_id, ''comanda.operate'')'),
      ('register_appointment_deposit_atomic',
       'v_role not in \(\s*''owner'', ''admin'', ''manager'', ''receptionist'', ''finance''\s*\)',
       'not public.has_permission(p_org_id, ''comanda.operate'')'),
      ('void_appointment_deposit_atomic',
       'v_role not in \(\s*''owner'', ''admin'', ''manager'', ''receptionist'', ''finance''\s*\)',
       'not public.has_permission(p_org_id, ''comanda.operate'')'),
      ('create_anamnese_atomic',
       'v_role not in \(\s*''owner'', ''admin'', ''manager'', ''receptionist'', ''professional''\s*\)',
       'not public.has_permission(p_org_id, ''anamnese.view_status'')'),
      ('create_anamnese_atomic',
       'v_role in \(''owner'', ''admin'', ''manager'', ''professional''\)',
       'public.has_permission(p_org_id, ''clientes.view_clinical'')'),
      ('list_anamnese_status',
       'v_role not in \(\s*''owner'', ''admin'', ''manager'', ''receptionist'', ''professional''\s*\)',
       'not public.has_permission(p_org_id, ''anamnese.view_status'')'),
      ('get_appointment_anamnese_gate',
       'v_role not in \(\s*''owner'', ''admin'', ''manager'', ''receptionist'', ''professional'', ''finance''\s*\)',
       'not (public.has_permission(p_org_id, ''anamnese.view_status'') or public.has_permission(p_org_id, ''comanda.operate''))'),
      ('save_anamnese_professional_data_atomic',
       'v_role not in \(''owner'', ''admin'', ''manager'', ''professional''\)',
       'not public.has_permission(p_org_id, ''anamnese.fill_professional'')'),
      ('save_anamnese_professional_notes_atomic',
       'v_role not in \(''owner'', ''admin'', ''manager'', ''professional''\)',
       'not public.has_permission(p_org_id, ''anamnese.fill_professional'')')
    ) as t(fn, pattern, replacement)
  loop
    select pg_get_functiondef(p.oid) into v_def
    from pg_proc p
    where p.pronamespace = 'public'::regnamespace and p.proname = r.fn;
    if v_def is null then
      raise exception 'Funcao % nao encontrada', r.fn;
    end if;
    select count(*) into v_count from regexp_matches(v_def, r.pattern, 'g');
    if v_count <> 1 then
      raise exception 'Funcao %: padrao encontrado % vez(es), esperado 1', r.fn, v_count;
    end if;
    execute regexp_replace(v_def, r.pattern, r.replacement);
  end loop;
end;
$rewrite$;

-- 6. Políticas -----------------------------------------------------------------------------------
drop policy if exists anamneses_select on public.anamneses;
create policy anamneses_select on public.anamneses for select to authenticated
  using (public.has_permission(org_id, 'clientes.view_clinical'));

drop policy if exists anamneses_insert on public.anamneses;
create policy anamneses_insert on public.anamneses for insert to authenticated
  with check (public.has_permission(org_id, 'anamnese.view_status'));

drop policy if exists anamneses_update on public.anamneses;
create policy anamneses_update on public.anamneses for update to authenticated
  using (public.has_permission(org_id, 'anamnese.fill_professional'))
  with check (public.has_permission(org_id, 'anamnese.fill_professional'));

drop policy if exists anamneses_delete_pending on public.anamneses;
create policy anamneses_delete_pending on public.anamneses for delete to authenticated
  using (status = 'pending' and public.has_permission(org_id, 'anamnese.fill_professional'));

drop policy if exists tx_select on public.transactions;
create policy tx_select on public.transactions for select to authenticated
  using (public.has_permission(org_id, 'financeiro.view'));

drop policy if exists "anamnese_photos_select" on storage.objects;
drop policy if exists "anamnese_photos_insert" on storage.objects;
drop policy if exists "anamnese_photos_delete" on storage.objects;

create policy "anamnese_photos_select" on storage.objects for select to authenticated
using (
  bucket_id = 'anamnese-photos'
  and public.has_permission(((storage.foldername(name))[1])::uuid, 'clientes.view_clinical')
);

create policy "anamnese_photos_insert" on storage.objects for insert to authenticated
with check (
  bucket_id = 'anamnese-photos'
  and public.has_permission(((storage.foldername(name))[1])::uuid, 'anamnese.fill_professional')
);

create policy "anamnese_photos_delete" on storage.objects for delete to authenticated
using (
  bucket_id = 'anamnese-photos'
  and public.has_permission(((storage.foldername(name))[1])::uuid, 'anamnese.fill_professional')
);
