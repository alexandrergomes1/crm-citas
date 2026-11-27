-- Ajustes: fim da gravação direta pela API em user_roles e organizations (revisão de segurança de 14/11).
-- Antes, proprietária e administração gravavam user_roles direto (sem a regra "nada acima do próprio acesso" e sem
-- conferir o perfil) e organizations direto em qualquer coluna (inclusive settings inteiro, sem a lista de chaves de
-- set_org_settings). Agora só pelas funções do banco, que conferem login + estúdio + permissão:
--   user_roles     team_grant_access, assign_user_profile (e, como antes, os gatilhos de guarda e auditoria).
--   organizations  settings_update_studio, set_org_settings (agora DEFINER), set_attendance_settings, set_anamnese_gate,
--                  set_anamnese_settings. Criar estúdio continua fora da API (plataforma, com a chave de serviço).
-- Efeito bom: ajustes.manage dado pela proprietária à gerência passa a valer (a política antiga só aceitava owner/admin).
-- Contas de recebimento: gravação por ajustes.manage, avaliado uma vez por consulta (auth_orgs_with_permission).
-- Efeito no app antigo (beauty-system, mesmo banco de desenvolvimento): telas de lá que gravavam organizations ou
-- user_roles direto deixam de gravar (o app antigo não vai para produção).
-- Encoding: UTF-8
set client_encoding = 'UTF8';

-- ─── user_roles ────────────────────────────────────────────────────────────────────────────────────────
drop policy if exists user_roles_insert on public.user_roles;
drop policy if exists user_roles_update on public.user_roles;
drop policy if exists user_roles_delete on public.user_roles;
revoke insert, update, delete, truncate on public.user_roles from anon, authenticated;

-- ─── organizations ─────────────────────────────────────────────────────────────────────────────────────
drop policy if exists "org: owner pode editar" on public.organizations;
drop policy if exists orgs_update_owner on public.organizations;
revoke insert, update, delete, truncate on public.organizations from anon, authenticated;

-- set_org_settings passa a DEFINER (a tabela não aceita mais UPDATE da API). Mesma regra de antes, com o login conferido
-- explicitamente; a auditoria SETTINGS_SET continua gravada aqui.
create or replace function public.set_org_settings(p_org_id uuid, p_patch jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_key text;
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'ajustes.manage') then
    raise exception 'Sem permissao para alterar configuracoes' using errcode = '42501';
  end if;
  if p_patch is null or pg_catalog.jsonb_typeof(p_patch) <> 'object' or p_patch = '{}'::jsonb then
    raise exception 'Configuracao invalida' using errcode = '22023';
  end if;
  for v_key in select pg_catalog.jsonb_object_keys(p_patch) loop
    if v_key not in ('business', 'policies', 'payment_methods', 'working_hours', 'payment_request') then
      raise exception 'Configuracao desconhecida: %', v_key using errcode = '22023';
    end if;
  end loop;

  update public.organizations o
     set settings = coalesce(o.settings, '{}'::jsonb) || p_patch
   where o.id = p_org_id;
  if not found then
    raise exception 'Estudio nao encontrado' using errcode = 'P0002';
  end if;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
  values (p_org_id, (select auth.uid()), 'organizations', 'SETTINGS_SET', p_org_id,
          pg_catalog.jsonb_build_object('keys', (select pg_catalog.jsonb_agg(k) from pg_catalog.jsonb_object_keys(p_patch) k)));
end;
$$;
revoke all on function public.set_org_settings(uuid, jsonb) from public, anon;
grant execute on function public.set_org_settings(uuid, jsonb) to authenticated;

-- ─── payment_accounts ──────────────────────────────────────────────────────────────────────────────────
drop policy if exists payment_accounts_write on public.payment_accounts;
create policy payment_accounts_write on public.payment_accounts for all to authenticated
  using (org_id in (select public.auth_orgs_with_permission('ajustes.manage')))
  with check (org_id in (select public.auth_orgs_with_permission('ajustes.manage')));
