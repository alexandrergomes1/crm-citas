-- Ajustes (porte, orçamento de chamadas): cada tela abre com o acesso do pedido (my_access_context) + UMA função
-- daqui. Antes: Plano 5 consultas, Profissionais 3, Acessos 4, Perfis 3, Importar e exportar 4, Ficha 1.
--   settings_section_read(org, seção): o que as seções de Ajustes precisam além do estúdio (que já vem no acesso):
--     'plano' (assinatura, módulos, regras do plano, exceções do estúdio, profissionais ativas), 'pagamentos'
--     (contas de recebimento, se o módulo cobranca está ligado), 'dados' (total de clientes), 'ficha' (situação do PIN).
--   team_screen(org): profissionais com turnos e, para quem gerencia a equipe, as contas que podem ser ligadas.
--   access_screen(org): contas do estúdio, quem está ligado a qual profissional e os perfis do estúdio.
--   profiles_screen(org): as duas matrizes de liberações e os perfis do estúdio.
-- Todas SECURITY INVOKER (a RLS das tabelas continua valendo) com search_path vazio; a permissão da tela é conferida
-- no banco antes de ler (42501). Só as colunas que a tela usa. Nada muda de regra.
-- Encoding: UTF-8
set client_encoding = 'UTF8';

-- ─── Seções de Ajustes ───────────────────────────────────────────────────────────────────────────────
create or replace function public.settings_section_read(p_org_id uuid, p_section text)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_sub record;
  v_pin jsonb;
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'ajustes.manage') then
    raise exception 'Sem permissão para ver os ajustes' using errcode = '42501';
  end if;

  if p_section = 'plano' then
    -- Assinatura: a RLS só mostra para proprietária/administração (sem linha = "plano não configurado").
    select s.plan_key, s.status, s.trial_ends_at, s.limits_override, p.name, p.monthly_price_cents, p.currency, p.limits
      into v_sub
    from public.org_subscriptions s
    left join public.plans p on p.key = s.plan_key
    where s.org_id = p_org_id;
    if not found then
      return pg_catalog.jsonb_build_object('subscription', null, 'active_staff',
        (select pg_catalog.count(*) from public.staff_members sm where sm.org_id = p_org_id and sm.active));
    end if;
    return pg_catalog.jsonb_build_object(
      'subscription', pg_catalog.jsonb_build_object(
        'plan_key', v_sub.plan_key, 'status', v_sub.status, 'trial_ends_at', v_sub.trial_ends_at,
        'limits_override', v_sub.limits_override,
        'plan', case when v_sub.name is null then null else pg_catalog.jsonb_build_object(
          'name', v_sub.name, 'monthly_price_cents', v_sub.monthly_price_cents, 'currency', v_sub.currency, 'limits', v_sub.limits) end),
      'modules', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'key', m.key, 'name', m.name, 'description', m.description, 'is_core', m.is_core,
          'depends_on', m.depends_on, 'position', m.position) order by m.position)
        from public.modules m where m.active), '[]'::jsonb),
      'rules', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'module_key', pm.module_key, 'mode', pm.mode, 'extra_price_cents', pm.extra_price_cents))
        from public.plan_modules pm where pm.plan_key = v_sub.plan_key), '[]'::jsonb),
      'overrides', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'module_key', om.module_key, 'enabled', om.enabled, 'price_cents', om.price_cents))
        from public.org_modules om where om.org_id = p_org_id), '[]'::jsonb),
      'active_staff', (select pg_catalog.count(*) from public.staff_members sm where sm.org_id = p_org_id and sm.active)
    );
  elsif p_section = 'pagamentos' then
    if not public.org_has_module(p_org_id, 'cobranca') then
      return pg_catalog.jsonb_build_object('accounts', null);
    end if;
    return pg_catalog.jsonb_build_object('accounts', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', a.id, 'kind', a.kind, 'holder_name', a.holder_name, 'identifier', a.identifier,
        'bic', a.bic, 'bank_name', a.bank_name, 'active', a.active, 'position', a.position) order by a.position, a.created_at)
      from public.payment_accounts a where a.org_id = p_org_id), '[]'::jsonb));
  elsif p_section = 'dados' then
    return pg_catalog.jsonb_build_object('client_count',
      (select pg_catalog.count(*) from public.clients c where c.org_id = p_org_id));
  elsif p_section = 'ficha' then
    -- Mesma regra do sistema antigo: sem leitura do PIN, a tela mostra "não definido".
    if public.has_permission(p_org_id, 'anamnese.view_status') then
      v_pin := public.studio_pin_status(p_org_id);
    end if;
    return pg_catalog.jsonb_build_object('pin', coalesce(v_pin, '{}'::jsonb));
  end if;
  raise exception 'Seção inválida' using errcode = '22023';
end;
$$;

-- ─── Profissionais ───────────────────────────────────────────────────────────────────────────────────
create or replace function public.team_screen(p_org_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'equipe.view') then
    raise exception 'Sem permissão para ver a equipe' using errcode = '42501';
  end if;
  return pg_catalog.jsonb_build_object(
    'staff', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', sm.id, 'name', sm.name, 'display_name', sm.display_name, 'role', sm.role, 'email', sm.email,
        'phone', sm.phone, 'user_id', sm.user_id, 'color', sm.color, 'commission_pct', sm.commission_pct,
        'online_booking', sm.online_booking, 'visible', sm.visible, 'active', sm.active,
        'staff_shifts', coalesce((
          select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
            'day_of_week', sh.day_of_week, 'start_time', sh.start_time, 'end_time', sh.end_time, 'active', sh.active)
            order by sh.day_of_week)
          from public.staff_shifts sh where sh.staff_id = sm.id and sh.org_id = p_org_id), '[]'::jsonb))
        order by sm.position, sm.created_at)
      from public.staff_members sm where sm.org_id = p_org_id), '[]'::jsonb),
    -- Contas que podem ser ligadas a uma profissional: só para quem gerencia a equipe.
    'accounts', case when public.has_permission(p_org_id, 'equipe.manage') then coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'user_id', ur.user_id, 'role', ur.role, 'profile_id', ur.profile_id,
        'full_name', (select pr.full_name from public.profiles pr where pr.user_id = ur.user_id and pr.org_id = p_org_id)))
      from public.user_roles ur where ur.org_id = p_org_id and ur.active), '[]'::jsonb)
      else '[]'::jsonb end
  );
end;
$$;

-- ─── Acessos ─────────────────────────────────────────────────────────────────────────────────────────
create or replace function public.access_screen(p_org_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'equipe.manage') then
    raise exception 'Sem permissão para ver os acessos' using errcode = '42501';
  end if;
  return pg_catalog.jsonb_build_object(
    'accounts', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'user_id', ur.user_id, 'role', ur.role, 'profile_id', ur.profile_id,
        'full_name', (select pr.full_name from public.profiles pr where pr.user_id = ur.user_id and pr.org_id = p_org_id)))
      from public.user_roles ur where ur.org_id = p_org_id and ur.active), '[]'::jsonb),
    'linked', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'user_id', sm.user_id, 'name', coalesce(nullif(sm.display_name, ''), sm.name)) order by sm.position, sm.created_at)
      from public.staff_members sm where sm.org_id = p_org_id and sm.user_id is not null), '[]'::jsonb),
    'profiles', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', op.id, 'name', op.name, 'base_role', op.base_role)
        order by op.created_at)
      from public.org_profiles op where op.org_id = p_org_id), '[]'::jsonb)
  );
end;
$$;

-- ─── Perfis e liberações ─────────────────────────────────────────────────────────────────────────────
create or replace function public.profiles_screen(p_org_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'acesso.manage') then
    raise exception 'Sem permissão para ver as liberações' using errcode = '42501';
  end if;
  return pg_catalog.jsonb_build_object(
    'roles', coalesce((select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(m)) from public.get_permission_matrix(p_org_id) m), '[]'::jsonb),
    'profiles', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', op.id, 'name', op.name, 'base_role', op.base_role)
        order by op.created_at)
      from public.org_profiles op where op.org_id = p_org_id), '[]'::jsonb),
    'profile_rows', coalesce((select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(m)) from public.get_profile_matrix(p_org_id) m), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.settings_section_read(uuid, text) from public, anon;
revoke all on function public.team_screen(uuid) from public, anon;
revoke all on function public.access_screen(uuid) from public, anon;
revoke all on function public.profiles_screen(uuid) from public, anon;
grant execute on function public.settings_section_read(uuid, text) to authenticated;
grant execute on function public.team_screen(uuid) to authenticated;
grant execute on function public.access_screen(uuid) to authenticated;
grant execute on function public.profiles_screen(uuid) to authenticated;
