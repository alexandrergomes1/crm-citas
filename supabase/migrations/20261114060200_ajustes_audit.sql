-- Ajustes: auditoria por gatilho e integridade do perfil de cada acesso.
-- Auditoria (regras decididas 14/11, modelo catalog_audit_row de 20261114030100): gatilho AFTER, função SECURITY DEFINER
-- (grava para qualquer caminho: as funções novas, as antigas, a API direta), search_path vazio, execução revogada de
-- todos, usuário = auth.uid(), só o necessário, e guarda de cascata (apagar o estúdio inteiro não quebra).
-- A política audit_insert_member NÃO muda: as operações abaixo não estão na lista dela, então ninguém as forja pela API.
--   organizations     ORG_UPDATED: colunas do estúdio que mudaram (antes e depois); telefone, e-mail e endereço só pelo
--                     nome do campo ("mudou"), e de settings só os NOMES das chaves.
--   payment_accounts  PAYMENT_ACCOUNT_CREATED / _UPDATED / _DELETED: tipo, ativa, últimos 4 caracteres do IBAN/telefone/chave
--                     e quais campos mudaram (titular, BIC, banco: só o nome do campo).
--   staff_members     STAFF_CREATED / _UPDATED / _DELETED: conta ligada, ativa, visível, agenda online, comissão, função;
--                     nome, e-mail e telefone só como "mudou" (sem o valor: dado pessoal).
-- Acessos (user_roles) já têm auditoria por gatilho desde 20261028210000 (tg_audit_access_change); perfis e liberações são
-- auditados dentro das funções DEFINER (create_org_profile, set_role_permission, ...), cujas tabelas não aceitam gravação
-- direta da API.
-- Integridade: o perfil de um acesso (user_roles.profile_id) precisa ser do mesmo estúdio e ter o mesmo papel-base do
-- acesso. Antes, a API direta (proprietária/administração) aceitava qualquer perfil, inclusive de outro estúdio.
-- Encoding: UTF-8
set client_encoding = 'UTF8';

-- ─── Estúdio ───────────────────────────────────────────────────────────────────────────────────────────
create or replace function public.ajustes_audit_org()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old jsonb := pg_catalog.to_jsonb(old);
  v_new jsonb := pg_catalog.to_jsonb(new);
  v_col text;
  v_before jsonb := '{}'::jsonb;
  v_after jsonb := '{}'::jsonb;
  v_keys jsonb;
  v_contacts text[] := array[]::text[];
begin
  foreach v_col in array array['name', 'slug', 'city', 'timezone', 'currency', 'locale', 'plan', 'active', 'logo_url'] loop
    if (v_old -> v_col) is distinct from (v_new -> v_col) then
      v_before := v_before || pg_catalog.jsonb_build_object(v_col, v_old -> v_col);
      v_after := v_after || pg_catalog.jsonb_build_object(v_col, v_new -> v_col);
    end if;
  end loop;
  foreach v_col in array array['phone', 'email', 'address'] loop
    if (v_old -> v_col) is distinct from (v_new -> v_col) then
      v_contacts := pg_catalog.array_append(v_contacts, v_col);
    end if;
  end loop;
  if pg_catalog.cardinality(v_contacts) > 0 then
    v_after := v_after || pg_catalog.jsonb_build_object('changed', pg_catalog.to_jsonb(v_contacts));
  end if;
  select pg_catalog.jsonb_agg(k order by k) into v_keys
  from (
    select k from pg_catalog.jsonb_object_keys(coalesce(old.settings, '{}'::jsonb) || coalesce(new.settings, '{}'::jsonb)) k
    where (old.settings -> k) is distinct from (new.settings -> k)
  ) s;
  if v_keys is not null then
    v_after := v_after || pg_catalog.jsonb_build_object('settings_keys', v_keys);
  end if;
  if v_after = '{}'::jsonb then
    return null;
  end if;
  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (new.id, (select auth.uid()), 'organizations', 'ORG_UPDATED', new.id, nullif(v_before, '{}'::jsonb), v_after);
  return null;
end;
$$;
revoke all on function public.ajustes_audit_org() from public, anon, authenticated;

drop trigger if exists trg_ajustes_audit_org on public.organizations;
create trigger trg_ajustes_audit_org after update on public.organizations
  for each row execute function public.ajustes_audit_org();

-- ─── Contas de recebimento ─────────────────────────────────────────────────────────────────────────────
create or replace function public.ajustes_audit_payment_account()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.payment_accounts := coalesce(new, old);
  v_changed text[] := array[]::text[];
  v_op text;
begin
  if not exists (select 1 from public.organizations o where o.id = v_row.org_id) then
    return null;
  end if;
  if tg_op = 'UPDATE' then
    if old.kind is distinct from new.kind then v_changed := pg_catalog.array_append(v_changed, 'kind'); end if;
    if old.holder_name is distinct from new.holder_name then v_changed := pg_catalog.array_append(v_changed, 'holder_name'); end if;
    if old.identifier is distinct from new.identifier then v_changed := pg_catalog.array_append(v_changed, 'identifier'); end if;
    if old.bic is distinct from new.bic then v_changed := pg_catalog.array_append(v_changed, 'bic'); end if;
    if old.bank_name is distinct from new.bank_name then v_changed := pg_catalog.array_append(v_changed, 'bank_name'); end if;
    if old.active is distinct from new.active then v_changed := pg_catalog.array_append(v_changed, 'active'); end if;
    if pg_catalog.cardinality(v_changed) = 0 then
      return null;
    end if;
  end if;
  v_op := case tg_op when 'INSERT' then 'PAYMENT_ACCOUNT_CREATED' when 'UPDATE' then 'PAYMENT_ACCOUNT_UPDATED' else 'PAYMENT_ACCOUNT_DELETED' end;
  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (
    v_row.org_id, (select auth.uid()), 'payment_accounts', v_op, v_row.id,
    case when tg_op in ('UPDATE', 'DELETE') then pg_catalog.jsonb_build_object(
      'kind', old.kind, 'active', old.active, 'identifier_end', pg_catalog.right(old.identifier, 4)) end,
    case when tg_op in ('INSERT', 'UPDATE') then pg_catalog.jsonb_build_object(
      'kind', new.kind, 'active', new.active, 'identifier_end', pg_catalog.right(new.identifier, 4),
      'changed', pg_catalog.to_jsonb(v_changed)) end
  );
  return null;
end;
$$;
revoke all on function public.ajustes_audit_payment_account() from public, anon, authenticated;

drop trigger if exists trg_ajustes_audit_payment_account on public.payment_accounts;
create trigger trg_ajustes_audit_payment_account after insert or update or delete on public.payment_accounts
  for each row execute function public.ajustes_audit_payment_account();

-- ─── Equipe ────────────────────────────────────────────────────────────────────────────────────────────
create or replace function public.ajustes_audit_staff()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.staff_members := coalesce(new, old);
  v_old jsonb := case when tg_op <> 'INSERT' then pg_catalog.to_jsonb(old) end;
  v_new jsonb := case when tg_op <> 'DELETE' then pg_catalog.to_jsonb(new) end;
  v_col text;
  v_before jsonb := '{}'::jsonb;
  v_after jsonb := '{}'::jsonb;
  v_personal text[] := array[]::text[];
begin
  if not exists (select 1 from public.organizations o where o.id = v_row.org_id) then
    return null;
  end if;
  foreach v_col in array array['user_id', 'active', 'visible', 'online_booking', 'commission_pct', 'role'] loop
    if tg_op = 'UPDATE' then
      if (v_old -> v_col) is distinct from (v_new -> v_col) then
        v_before := v_before || pg_catalog.jsonb_build_object(v_col, v_old -> v_col);
        v_after := v_after || pg_catalog.jsonb_build_object(v_col, v_new -> v_col);
      end if;
    elsif tg_op = 'INSERT' then
      v_after := v_after || pg_catalog.jsonb_build_object(v_col, v_new -> v_col);
    else
      v_before := v_before || pg_catalog.jsonb_build_object(v_col, v_old -> v_col);
    end if;
  end loop;
  if tg_op = 'UPDATE' then
    foreach v_col in array array['name', 'display_name', 'email', 'phone'] loop
      if (v_old -> v_col) is distinct from (v_new -> v_col) then v_personal := pg_catalog.array_append(v_personal, v_col); end if;
    end loop;
    if pg_catalog.cardinality(v_personal) > 0 then
      v_after := v_after || pg_catalog.jsonb_build_object('changed', pg_catalog.to_jsonb(v_personal));
    end if;
    if v_after = '{}'::jsonb then
      return null;
    end if;
  end if;
  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (v_row.org_id, (select auth.uid()), 'staff_members',
          case tg_op when 'INSERT' then 'STAFF_CREATED' when 'UPDATE' then 'STAFF_UPDATED' else 'STAFF_DELETED' end,
          v_row.id, nullif(v_before, '{}'::jsonb), nullif(v_after, '{}'::jsonb));
  return null;
end;
$$;
revoke all on function public.ajustes_audit_staff() from public, anon, authenticated;

drop trigger if exists trg_ajustes_audit_staff on public.staff_members;
create trigger trg_ajustes_audit_staff after insert or update or delete on public.staff_members
  for each row execute function public.ajustes_audit_staff();

-- ─── Perfil do acesso: mesmo estúdio e mesmo papel-base ───────────────────────────────────────────────
create or replace function public.user_roles_profile_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.profile_id is not null and not exists (
    select 1 from public.org_profiles op
    where op.id = new.profile_id and op.org_id = new.org_id and op.base_role = new.role
  ) then
    raise exception 'Perfil de outro estúdio ou de outro papel' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function public.user_roles_profile_guard() from public, anon, authenticated;

drop trigger if exists trg_user_roles_profile_guard on public.user_roles;
create trigger trg_user_roles_profile_guard before insert or update of profile_id, role, org_id on public.user_roles
  for each row execute function public.user_roles_profile_guard();
