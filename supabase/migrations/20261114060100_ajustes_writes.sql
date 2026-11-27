-- Ajustes (porte, orçamento de chamadas): cada ação = acesso do pedido + UMA função daqui (tudo-ou-nada).
--   settings_update_studio     Estúdio: colunas do estúdio + dados do comprovante e políticas (antes 2 idas, sem transação).
--   settings_save_attendance   Atendimento: etapas + trava "exigir ficha ao iniciar" (antes 2 idas).
--   settings_save_ficha        Ficha de saúde: validade do link/modo estúdio + travas (antes 2 idas).
--   settings_save_payments     Pagamentos: formas aceitas + link de cobrança + contas ligadas/desligadas (antes 1 ida por item).
--   settings_save_payment_account  Conta de recebimento nova ou editada (antes direto na tabela, sem conferir ajustes.manage).
--   team_save_staff            Profissional + 7 turnos + conferência da conta ligada (antes 3 idas, sem transação).
--   team_set_staff_flags       Ativar/desativar, visível, agenda online.
--   team_access_begin          Antes de criar a conta de login: confere acesso.manage e o limite de 10 acessos novos por
--                              estúdio por dia; registra a tentativa (é ela que o limite conta).
--   team_grant_access          Acesso novo (papel + nome no estúdio + auditoria) para a conta de login que o servidor do app
--                              ACABOU de criar (Auth, chave de serviço) e mandou pelo id. Conta que já existia, ou que já
--                              tem papel em qualquer estúdio, é recusada: ninguém é ligado a um estúdio sem aceitar.
--                              SECURITY DEFINER (grava user_roles, que a API não grava mais). Não busca por e-mail.
--   team_access_abort          A conta recém-criada não ganhou papel: registra a falha antes de o servidor apagá-la.
--   access_apply_changes       Perfis e liberações: todas as trocas do Salvar numa transação (antes 2 idas POR troca).
--   assign_user_profile        Recriada (mesma assinatura): exige acesso.manage (antes equipe.manage), recusa escalada (quem
--                              não é dona não dá nem mexe em acesso com liberação que ela mesma não tem; Administração só
--                              com acesso.grant_admin) e trava a linha (for update).
-- Reaproveita as funções que já conferem permissão e gravam auditoria: set_org_settings, set_attendance_settings,
-- set_anamnese_gate, set_anamnese_settings, set_role_permission, set_profile_permission.
-- Regras de auditoria (decididas 14/11): a política audit_insert_member NÃO muda; nenhuma função de auditoria é
-- chamável pela API. Aqui a auditoria é gravada dentro de funções DEFINER que conferem login + estúdio + permissão;
-- as mudanças de tabela (estúdio, contas, equipe) são auditadas por gatilho (migration 20261114060200).
-- Encoding: UTF-8
set client_encoding = 'UTF8';

-- ─── Ajudantes internos (sem execução para a API) ──────────────────────────────────────────────────────
-- Liberações efetivas de um papel (+ perfil do estúdio), na ordem de has_permission: perfil > papel no estúdio > padrão.
-- Executável por quem está logado porque access_apply_changes (INVOKER) a usa como quem chama. Não revela nada além do
-- que a RLS já mostra: as exceções do estúdio só aparecem para quem tem acesso.manage nele; para os demais, só o padrão
-- do sistema (o mesmo de role_default_permissions, que já é público para quem está logado).
create or replace function public.access_permissions_of(p_org_id uuid, p_role text, p_profile_id uuid)
returns text[]
language sql
stable
security invoker
set search_path = ''
as $$
  select coalesce(pg_catalog.array_agg(c.permission order by c.permission), array[]::text[])
  from (select distinct d.permission from public.role_default_permissions() d where d.role = 'owner') c
  where p_role = 'owner' or coalesce(
    (select opp.allowed from public.org_profile_permissions opp
      where p_profile_id is not null and opp.profile_id = p_profile_id and opp.permission = c.permission),
    (select orp.allowed from public.org_role_permissions orp
      where orp.org_id = p_org_id and orp.role = p_role and orp.permission = c.permission),
    exists (select 1 from public.role_default_permissions() d where d.role = p_role and d.permission = c.permission)
  );
$$;

-- Quem age pode dar (ou mexer em) este papel/perfil? Uma regra só, usada por todas as funções de acesso:
-- proprietária não é dada por aqui; Administração só por quem tem acesso.grant_admin (a proprietária, por padrão);
-- e quem não é a proprietária não dá nada com liberação que ela mesma não tem.
create or replace function public.access_assert_can_grant(p_org_id uuid, p_actor_role text, p_role text, p_profile_id uuid)
returns void
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  if p_role = 'owner' then
    raise exception 'O papel de proprietária não é dado por aqui' using errcode = '42501';
  end if;
  if p_role = 'admin' and not public.has_permission(p_org_id, 'acesso.grant_admin') then
    raise exception 'Somente a proprietária dá ou tira Administração' using errcode = '42501';
  end if;
  if p_actor_role = 'owner' then
    return;
  end if;
  if not (public.access_permissions_of(p_org_id, p_role, p_profile_id) <@ public.my_permissions(p_org_id)) then
    raise exception 'Você não pode dar um acesso com liberações que você não tem' using errcode = '42501';
  end if;
end;
$$;

revoke all on function public.access_permissions_of(uuid, text, uuid) from public, anon, authenticated;
revoke all on function public.access_assert_can_grant(uuid, text, text, uuid) from public, anon, authenticated;

-- ─── Estúdio ───────────────────────────────────────────────────────────────────────────────────────────
create or replace function public.settings_update_studio(
  p_org_id uuid, p_name text, p_phone text, p_email text, p_address text, p_city text, p_timezone text, p_currency text,
  p_legal_name text, p_tax_id text, p_postal_code text, p_receipt_footer text, p_deposit_policy text, p_cancellation_policy text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text := pg_catalog.btrim(coalesce(p_name, ''));
begin
  -- DEFINER (a tabela organizations não aceita mais gravação direta da API): login + estúdio + ajustes.manage aqui.
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'ajustes.manage') then
    raise exception 'Sem permissão para alterar configurações' using errcode = '42501';
  end if;
  if pg_catalog.char_length(v_name) not between 2 and 120
     or pg_catalog.char_length(coalesce(p_phone, '')) > 40 or pg_catalog.char_length(coalesce(p_email, '')) > 254
     or pg_catalog.char_length(coalesce(p_address, '')) > 200 or pg_catalog.char_length(coalesce(p_city, '')) > 80
     or pg_catalog.char_length(coalesce(p_legal_name, '')) > 160 or pg_catalog.char_length(coalesce(p_tax_id, '')) > 20
     or pg_catalog.char_length(coalesce(p_postal_code, '')) > 12 or pg_catalog.char_length(coalesce(p_receipt_footer, '')) > 300
     or pg_catalog.char_length(coalesce(p_deposit_policy, '')) > 1000 or pg_catalog.char_length(coalesce(p_cancellation_policy, '')) > 1000
     or coalesce(p_currency, '') !~ '^[A-Z]{3}$'
     or not exists (select 1 from pg_catalog.pg_timezone_names tz where tz.name = p_timezone) then
    raise exception 'Dados do estúdio inválidos' using errcode = '22023';
  end if;

  -- Mescla só as chaves do comprovante e das políticas (as outras chaves de settings ficam como estão).
  perform public.set_org_settings(p_org_id, pg_catalog.jsonb_build_object(
    'business', pg_catalog.jsonb_build_object(
      'legal_name', nullif(p_legal_name, ''), 'tax_id', nullif(p_tax_id, ''),
      'postal_code', nullif(p_postal_code, ''), 'receipt_footer', nullif(p_receipt_footer, '')),
    'policies', pg_catalog.jsonb_build_object('deposit', nullif(p_deposit_policy, ''), 'cancellation', nullif(p_cancellation_policy, ''))
  ));
  update public.organizations o
     set name = v_name, phone = nullif(p_phone, ''), email = nullif(p_email, ''), address = nullif(p_address, ''),
         city = nullif(p_city, ''), timezone = p_timezone, currency = p_currency
   where o.id = p_org_id;
  if not found then
    raise exception 'Estúdio não encontrado' using errcode = 'P0002';
  end if;
end;
$$;

-- ─── Atendimento e ficha ───────────────────────────────────────────────────────────────────────────────
create or replace function public.settings_save_attendance(p_org_id uuid, p_settings jsonb, p_gate_start boolean, p_gate_checkout boolean)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'ajustes.manage') then
    raise exception 'Sem permissão para alterar configurações' using errcode = '42501';
  end if;
  if (p_gate_start is null) <> (p_gate_checkout is null) then
    raise exception 'Trava inválida' using errcode = '22023';
  end if;
  perform public.set_attendance_settings(p_org_id, p_settings);
  if p_gate_start is not null then
    perform public.set_anamnese_gate(p_org_id, p_gate_start, p_gate_checkout);
  end if;
end;
$$;

create or replace function public.settings_save_ficha(
  p_org_id uuid, p_link_days integer, p_studio_mode boolean, p_gate_start boolean, p_gate_checkout boolean
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'ajustes.manage') then
    raise exception 'Sem permissão para alterar configurações' using errcode = '42501';
  end if;
  if (p_link_days is null) <> (p_studio_mode is null) or (p_gate_start is null) <> (p_gate_checkout is null)
     or (p_link_days is null and p_gate_start is null) then
    raise exception 'Ajuste inválido' using errcode = '22023';
  end if;
  if p_link_days is not null then
    perform public.set_anamnese_settings(p_org_id, p_link_days, p_studio_mode);
  end if;
  if p_gate_start is not null then
    perform public.set_anamnese_gate(p_org_id, p_gate_start, p_gate_checkout);
  end if;
end;
$$;

-- ─── Pagamentos ────────────────────────────────────────────────────────────────────────────────────────
-- p_methods: ["CASH", ...] ou null (sem mudança); p_payment_request: {"expires_hours": 1..336, "guidance": texto|null}
-- ou null; p_accounts: [{"id": uuid, "active": bool}, ...] ou null.
create or replace function public.settings_save_payments(p_org_id uuid, p_methods jsonb, p_payment_request jsonb, p_accounts jsonb)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_patch jsonb := '{}'::jsonb;
  v_item jsonb;
  v_hours integer;
  v_guidance text;
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'ajustes.manage') then
    raise exception 'Sem permissão para alterar configurações' using errcode = '42501';
  end if;
  if p_methods is null and p_payment_request is null and p_accounts is null then
    raise exception 'Nada para salvar' using errcode = '22023';
  end if;

  if p_methods is not null then
    if pg_catalog.jsonb_typeof(p_methods) <> 'array' or pg_catalog.jsonb_array_length(p_methods) not between 1 and 5
       or exists (select 1 from pg_catalog.jsonb_array_elements(p_methods) m
                  where pg_catalog.jsonb_typeof(m) <> 'string' or m #>> '{}' not in ('CASH', 'BIZUM', 'CARD_DEBIT', 'CARD_CREDIT', 'TRANSFER')) then
      raise exception 'Formas de pagamento inválidas' using errcode = '22023';
    end if;
    v_patch := v_patch || pg_catalog.jsonb_build_object('payment_methods', p_methods);
  end if;

  if p_payment_request is not null then
    if pg_catalog.jsonb_typeof(p_payment_request) <> 'object' or pg_catalog.jsonb_typeof(p_payment_request -> 'expires_hours') <> 'number' then
      raise exception 'Link de cobrança inválido' using errcode = '22023';
    end if;
    v_hours := (p_payment_request ->> 'expires_hours')::numeric::integer;
    v_guidance := nullif(pg_catalog.btrim(coalesce(p_payment_request ->> 'guidance', '')), '');
    if v_hours not between 1 and 336 or pg_catalog.char_length(coalesce(v_guidance, '')) > 500 then
      raise exception 'Link de cobrança inválido' using errcode = '22023';
    end if;
    v_patch := v_patch || pg_catalog.jsonb_build_object('payment_request',
      pg_catalog.jsonb_build_object('expires_hours', v_hours, 'guidance', v_guidance));
  end if;

  if p_accounts is not null then
    if pg_catalog.jsonb_typeof(p_accounts) <> 'array' or pg_catalog.jsonb_array_length(p_accounts) > 50 then
      raise exception 'Contas inválidas' using errcode = '22023';
    end if;
    for v_item in select * from pg_catalog.jsonb_array_elements(p_accounts) loop
      if pg_catalog.jsonb_typeof(v_item -> 'active') <> 'boolean' or pg_catalog.jsonb_typeof(v_item -> 'id') <> 'string' then
        raise exception 'Conta inválida' using errcode = '22023';
      end if;
      update public.payment_accounts a
         set active = (v_item ->> 'active')::boolean, updated_at = pg_catalog.now()
       where a.id = (v_item ->> 'id')::uuid and a.org_id = p_org_id;
      if not found then
        raise exception 'Conta não encontrada' using errcode = 'P0002';
      end if;
    end loop;
  end if;

  if v_patch <> '{}'::jsonb then
    perform public.set_org_settings(p_org_id, v_patch);
  end if;
end;
$$;

-- Conta nova (p_id nulo) ou editada. A RLS da tabela continua exigindo proprietária/administração; os CHECKs da tabela
-- conferem tipo, tamanhos e o BIC. Devolve o id.
create or replace function public.settings_save_payment_account(
  p_org_id uuid, p_id uuid, p_kind text, p_holder_name text, p_identifier text, p_bic text, p_bank_name text
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'ajustes.manage') then
    raise exception 'Sem permissão para alterar contas de recebimento' using errcode = '42501';
  end if;
  if p_id is null then
    insert into public.payment_accounts (org_id, kind, holder_name, identifier, bic, bank_name, created_by)
    values (p_org_id, p_kind, p_holder_name, p_identifier, nullif(p_bic, ''), nullif(p_bank_name, ''), (select auth.uid()))
    returning id into v_id;
  else
    update public.payment_accounts a
       set kind = p_kind, holder_name = p_holder_name, identifier = p_identifier,
           bic = nullif(p_bic, ''), bank_name = nullif(p_bank_name, ''), updated_at = pg_catalog.now()
     where a.id = p_id and a.org_id = p_org_id
    returning a.id into v_id;
    if v_id is null then
      raise exception 'Conta não encontrada' using errcode = 'P0002';
    end if;
  end if;
  return v_id;
end;
$$;

-- ─── Equipe ────────────────────────────────────────────────────────────────────────────────────────────
-- p_shifts: 7 itens (domingo = 0 ... sábado = 6) {"active": bool, "start": "HH:MM", "end": "HH:MM"}.
create or replace function public.team_save_staff(
  p_org_id uuid, p_staff_id uuid, p_name text, p_display_name text, p_role text, p_email text, p_phone text,
  p_user_id uuid, p_color text, p_commission_pct numeric, p_online_booking boolean, p_visible boolean, p_shifts jsonb
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_id uuid;
  v_shift jsonb;
  v_day integer := 0;
  v_name text := pg_catalog.btrim(coalesce(p_name, ''));
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'equipe.manage') then
    raise exception 'Sem permissão para gerenciar equipe' using errcode = '42501';
  end if;
  if pg_catalog.char_length(v_name) not between 1 and 120
     or p_commission_pct is null or p_commission_pct < 0 or p_commission_pct > 100
     or p_online_booking is null or p_visible is null
     or p_shifts is null or pg_catalog.jsonb_typeof(p_shifts) <> 'array' or pg_catalog.jsonb_array_length(p_shifts) <> 7 then
    raise exception 'Dados da profissional inválidos' using errcode = '22023';
  end if;
  for v_shift in select * from pg_catalog.jsonb_array_elements(p_shifts) loop
    if pg_catalog.jsonb_typeof(v_shift -> 'active') <> 'boolean'
       or coalesce(v_shift ->> 'start', '') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
       or coalesce(v_shift ->> 'end', '') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then
      raise exception 'Horário inválido (use HH:MM)' using errcode = '22023';
    end if;
    if (v_shift ->> 'active')::boolean and (v_shift ->> 'end') <= (v_shift ->> 'start') then
      raise exception 'O fim do turno precisa ser depois do início' using errcode = '22023';
    end if;
  end loop;
  -- A conta ligada precisa ter acesso ativo a este estúdio.
  if p_user_id is not null and not exists (
    select 1 from public.user_roles ur where ur.org_id = p_org_id and ur.user_id = p_user_id and ur.active
  ) then
    raise exception 'Esta conta não faz parte do estúdio' using errcode = '22023';
  end if;

  if p_staff_id is null then
    insert into public.staff_members (org_id, name, display_name, role, email, phone, user_id, color, commission_pct,
                                      online_booking, visible, position, active)
    values (p_org_id, v_name, nullif(pg_catalog.btrim(p_display_name), ''),
            coalesce(nullif(pg_catalog.btrim(p_role), ''), 'professional'), nullif(pg_catalog.btrim(p_email), ''),
            nullif(pg_catalog.btrim(p_phone), ''), p_user_id, p_color, p_commission_pct, p_online_booking, p_visible, 0, true)
    returning id into v_id;
  else
    update public.staff_members sm
       set name = v_name, display_name = nullif(pg_catalog.btrim(p_display_name), ''),
           role = coalesce(nullif(pg_catalog.btrim(p_role), ''), sm.role), email = nullif(pg_catalog.btrim(p_email), ''),
           phone = nullif(pg_catalog.btrim(p_phone), ''), user_id = p_user_id, color = p_color,
           commission_pct = p_commission_pct, online_booking = p_online_booking, visible = p_visible, updated_at = pg_catalog.now()
     where sm.id = p_staff_id and sm.org_id = p_org_id
    returning sm.id into v_id;
    if v_id is null then
      raise exception 'Profissional não encontrada' using errcode = 'P0002';
    end if;
  end if;

  for v_shift in select * from pg_catalog.jsonb_array_elements(p_shifts) loop
    insert into public.staff_shifts (org_id, staff_id, day_of_week, start_time, end_time, active)
    values (p_org_id, v_id, v_day, v_shift ->> 'start', v_shift ->> 'end', (v_shift ->> 'active')::boolean)
    on conflict (staff_id, day_of_week)
    do update set start_time = excluded.start_time, end_time = excluded.end_time, active = excluded.active;
    v_day := v_day + 1;
  end loop;
  return v_id;
end;
$$;

create or replace function public.team_set_staff_flags(
  p_org_id uuid, p_staff_id uuid, p_active boolean, p_visible boolean, p_online_booking boolean
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'equipe.manage') then
    raise exception 'Sem permissão para gerenciar equipe' using errcode = '42501';
  end if;
  if p_active is null and p_visible is null and p_online_booking is null then
    raise exception 'Alteração inválida' using errcode = '22023';
  end if;
  update public.staff_members sm
     set active = coalesce(p_active, sm.active), visible = coalesce(p_visible, sm.visible),
         online_booking = coalesce(p_online_booking, sm.online_booking), updated_at = pg_catalog.now()
   where sm.id = p_staff_id and sm.org_id = p_org_id;
  if not found then
    raise exception 'Profissional não encontrada' using errcode = 'P0002';
  end if;
end;
$$;

-- ─── Acesso novo ───────────────────────────────────────────────────────────────────────────────────────
-- Limite de contas novas: 10 por estúdio a cada 24 h, contando as tentativas (inclusive as que falharam). Chamada ANTES de
-- o servidor criar a conta de login, para o limite valer também para a chave de serviço.
create or replace function public.team_access_begin(p_org_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'acesso.manage') then
    raise exception 'Sem permissão para criar acessos' using errcode = '42501';
  end if;
  -- Duas criações ao mesmo tempo no mesmo estúdio não passam juntas do limite.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('team_access_begin:' || p_org_id::text, 0));
  if (select pg_catalog.count(*) from public.audit_logs al
      where al.org_id = p_org_id and al.table_name = 'user_roles' and al.operation = 'ACCESS_CREATE_STARTED'
        and al.created_at > pg_catalog.now() - interval '24 hours') >= 10 then
    raise exception 'Limite de 10 acessos novos por dia neste estúdio. Tente de novo amanhã.' using errcode = 'P0001';
  end if;
  insert into public.audit_logs (org_id, user_id, table_name, operation)
  values (p_org_id, (select auth.uid()), 'user_roles', 'ACCESS_CREATE_STARTED');
end;
$$;

-- Papel (ou perfil) no estúdio e nome da pessoa no estúdio, numa transação, para a conta que o servidor acabou de criar.
-- Recusa: sem acesso.manage; papel acima do próprio (access_assert_can_grant); conta que não é nova (criada há mais de
-- 15 min) ou que já tem papel em algum estúdio. Devolve {"user_id", "role"} (o papel-base gravado).
create or replace function public.team_grant_access(
  p_org_id uuid, p_user_id uuid, p_name text, p_role text, p_profile_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_actor_role text;
  v_role text;
  v_name text := pg_catalog.btrim(coalesce(p_name, ''));
begin
  if v_uid is null then
    raise exception 'Autenticação obrigatória' using errcode = '42501';
  end if;
  v_actor_role := public.auth_user_role(p_org_id);
  if v_actor_role is null or not public.has_permission(p_org_id, 'acesso.manage') then
    raise exception 'Sem permissão para criar acessos' using errcode = '42501';
  end if;
  if p_user_id is null or pg_catalog.char_length(v_name) not between 1 and 120 or (p_role is null) = (p_profile_id is null) then
    raise exception 'Dados do acesso inválidos' using errcode = '22023';
  end if;

  if p_profile_id is not null then
    select op.base_role into v_role from public.org_profiles op where op.id = p_profile_id and op.org_id = p_org_id;
    if v_role is null then
      raise exception 'Perfil inexistente' using errcode = '22023';
    end if;
  elsif p_role in ('admin', 'manager', 'receptionist', 'professional', 'finance', 'viewer') then
    v_role := p_role;
  else
    raise exception 'Papel inválido' using errcode = '22023';
  end if;
  perform public.access_assert_can_grant(p_org_id, v_actor_role, v_role, p_profile_id);

  if p_user_id = v_uid then
    raise exception 'Ninguém pode conceder papel a si mesmo' using errcode = '42501';
  end if;
  -- Só a conta recém-criada pelo servidor: nada de ligar ao estúdio uma conta que já existia (sem o aceite da pessoa).
  if not exists (select 1 from auth.users u where u.id = p_user_id and u.created_at > pg_catalog.now() - interval '15 minutes')
     or exists (select 1 from public.user_roles ur where ur.user_id = p_user_id) then
    raise exception 'Conta não disponível para um acesso novo' using errcode = '42501';
  end if;

  insert into public.user_roles (user_id, org_id, role, profile_id, active)
  values (p_user_id, p_org_id, v_role, p_profile_id, true);
  insert into public.profiles (user_id, org_id, full_name)
  values (p_user_id, p_org_id, v_name)
  on conflict (user_id, org_id) do update set full_name = excluded.full_name;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
  values (p_org_id, v_uid, 'user_roles', 'ACCESS_CREATED', p_user_id,
          pg_catalog.jsonb_build_object('role', v_role, 'profile_id', p_profile_id));
  return pg_catalog.jsonb_build_object('user_id', p_user_id, 'role', v_role);
end;
$$;

-- O banco recusou o papel: a conta recém-criada fica sem estúdio e o servidor vai apagá-la. Registra a falha (quem tentou,
-- qual conta) antes. Recusa se a conta já tiver papel em algum estúdio (não é uma conta órfã desta tentativa).
create or replace function public.team_access_abort(p_org_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'acesso.manage') then
    raise exception 'Sem permissão para criar acessos' using errcode = '42501';
  end if;
  if p_user_id is null or exists (select 1 from public.user_roles ur where ur.user_id = p_user_id) then
    raise exception 'Conta não é desta tentativa' using errcode = '42501';
  end if;
  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id)
  values (p_org_id, (select auth.uid()), 'user_roles', 'ACCESS_CREATE_FAILED', p_user_id);
end;
$$;

-- ─── Trocar o perfil de um acesso (mesma assinatura, regras novas) ────────────────────────────────────
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
begin
  if auth.uid() is null then
    raise exception 'Autenticacao obrigatoria' using errcode = '42501';
  end if;
  v_actor_role := public.auth_user_role(p_org_id);
  if v_actor_role is null or not public.has_permission(p_org_id, 'acesso.manage') then
    raise exception 'Sem permissao para alterar acessos' using errcode = '42501';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'Voce nao altera o proprio perfil' using errcode = '42501';
  end if;
  if (p_role is null) = (p_profile_id is null) then
    raise exception 'Informe o papel ou o perfil' using errcode = '22023';
  end if;
  select * into v_old from public.user_roles where org_id = p_org_id and user_id = p_user_id and active = true for update;
  if not found then
    raise exception 'Acesso inexistente' using errcode = '22023';
  end if;
  if v_old.role = 'owner' then
    raise exception 'O perfil da proprietaria nao muda' using errcode = '42501';
  end if;
  if p_profile_id is not null then
    select op.base_role into v_new_role from public.org_profiles op where op.id = p_profile_id and op.org_id = p_org_id;
    if v_new_role is null then
      raise exception 'Perfil inexistente' using errcode = '22023';
    end if;
  else
    if p_role not in ('admin', 'manager', 'receptionist', 'professional', 'finance', 'viewer') then
      raise exception 'Papel invalido' using errcode = '22023';
    end if;
    v_new_role := p_role;
  end if;
  -- Nem dar, nem mexer em quem já tem, um acesso acima do próprio (Administração: só com acesso.grant_admin).
  perform public.access_assert_can_grant(p_org_id, v_actor_role, v_new_role, p_profile_id);
  perform public.access_assert_can_grant(p_org_id, v_actor_role, v_old.role, v_old.profile_id);

  update public.user_roles set role = v_new_role, profile_id = p_profile_id
  where id = v_old.id;
  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (p_org_id, auth.uid(), 'user_roles', 'ACCESS_PROFILE_CHANGED', p_user_id,
          pg_catalog.jsonb_build_object('role', v_old.role, 'profile_id', v_old.profile_id),
          pg_catalog.jsonb_build_object('role', v_new_role, 'profile_id', p_profile_id));
  return true;
end;
$$;

-- ─── Perfis e liberações: todas as trocas do Salvar ───────────────────────────────────────────────────
-- p_changes: [{"role": "receptionist" | "profile_id": uuid, "permission": "...", "allowed": bool}, ...] (até 400), na ordem
-- em que valem. Troca que já está no valor pedido é pulada (não grava nem audita); as demais passam por
-- set_role_permission / set_profile_permission, que conferem quem pode e gravam a auditoria. Devolve quantas mudaram.
create or replace function public.access_apply_changes(p_org_id uuid, p_changes jsonb)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_change jsonb;
  v_permission text;
  v_allowed boolean;
  v_current boolean;
  v_role text;
  v_profile uuid;
  v_count integer := 0;
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'acesso.manage') then
    raise exception 'Sem permissão para alterar liberações' using errcode = '42501';
  end if;
  if p_changes is null or pg_catalog.jsonb_typeof(p_changes) <> 'array'
     or pg_catalog.jsonb_array_length(p_changes) not between 1 and 400 then
    raise exception 'Lista de liberações inválida' using errcode = '22023';
  end if;

  for v_change in select * from pg_catalog.jsonb_array_elements(p_changes) loop
    if pg_catalog.jsonb_typeof(v_change -> 'permission') <> 'string' or pg_catalog.jsonb_typeof(v_change -> 'allowed') <> 'boolean'
       or (v_change ? 'role') = (v_change ? 'profile_id') then
      raise exception 'Liberação inválida' using errcode = '22023';
    end if;
    v_permission := v_change ->> 'permission';
    v_allowed := (v_change ->> 'allowed')::boolean;

    if v_change ? 'profile_id' then
      v_profile := (v_change ->> 'profile_id')::uuid;
      select op.base_role into v_role from public.org_profiles op where op.id = v_profile and op.org_id = p_org_id;
      if v_role is null then
        raise exception 'Perfil inexistente' using errcode = '22023';
      end if;
      v_current := v_permission = any (public.access_permissions_of(p_org_id, v_role, v_profile));
      if v_current is distinct from v_allowed then
        perform public.set_profile_permission(p_org_id, v_profile, v_permission, v_allowed);
        v_count := v_count + 1;
      end if;
    else
      v_role := v_change ->> 'role';
      if v_role is null or not (v_role = any (array['admin', 'manager', 'receptionist', 'professional', 'finance', 'viewer'])) then
        raise exception 'Perfil não editável' using errcode = '22023';
      end if;
      v_current := v_permission = any (public.access_permissions_of(p_org_id, v_role, null));
      if v_current is distinct from v_allowed then
        perform public.set_role_permission(p_org_id, v_role, v_permission, v_allowed);
        v_count := v_count + 1;
      end if;
    end if;
    v_role := null;
  end loop;
  return v_count;
end;
$$;
-- access_permissions_of é chamada daqui como quem chama (INVOKER): a pessoa logada precisa poder executá-la.
-- Ela só lê o que a RLS já mostra a quem tem acesso.manage (liberações do estúdio) e o padrão do sistema.
grant execute on function public.access_permissions_of(uuid, text, uuid) to authenticated;

-- ─── Permissões de execução ────────────────────────────────────────────────────────────────────────────
revoke all on function public.settings_update_studio(uuid, text, text, text, text, text, text, text, text, text, text, text, text, text) from public, anon;
revoke all on function public.settings_save_attendance(uuid, jsonb, boolean, boolean) from public, anon;
revoke all on function public.settings_save_ficha(uuid, integer, boolean, boolean, boolean) from public, anon;
revoke all on function public.settings_save_payments(uuid, jsonb, jsonb, jsonb) from public, anon;
revoke all on function public.settings_save_payment_account(uuid, uuid, text, text, text, text, text) from public, anon;
revoke all on function public.team_save_staff(uuid, uuid, text, text, text, text, text, uuid, text, numeric, boolean, boolean, jsonb) from public, anon;
revoke all on function public.team_set_staff_flags(uuid, uuid, boolean, boolean, boolean) from public, anon;
revoke all on function public.team_access_begin(uuid) from public, anon;
revoke all on function public.team_grant_access(uuid, uuid, text, text, uuid) from public, anon;
revoke all on function public.team_access_abort(uuid, uuid) from public, anon;
revoke all on function public.assign_user_profile(uuid, uuid, text, uuid) from public, anon;
revoke all on function public.access_apply_changes(uuid, jsonb) from public, anon;

grant execute on function public.settings_update_studio(uuid, text, text, text, text, text, text, text, text, text, text, text, text, text) to authenticated;
grant execute on function public.settings_save_attendance(uuid, jsonb, boolean, boolean) to authenticated;
grant execute on function public.settings_save_ficha(uuid, integer, boolean, boolean, boolean) to authenticated;
grant execute on function public.settings_save_payments(uuid, jsonb, jsonb, jsonb) to authenticated;
grant execute on function public.settings_save_payment_account(uuid, uuid, text, text, text, text, text) to authenticated;
grant execute on function public.team_save_staff(uuid, uuid, text, text, text, text, text, uuid, text, numeric, boolean, boolean, jsonb) to authenticated;
grant execute on function public.team_set_staff_flags(uuid, uuid, boolean, boolean, boolean) to authenticated;
grant execute on function public.team_access_begin(uuid) to authenticated;
grant execute on function public.team_grant_access(uuid, uuid, text, text, uuid) to authenticated;
grant execute on function public.team_access_abort(uuid, uuid) to authenticated;
grant execute on function public.assign_user_profile(uuid, uuid, text, uuid) to authenticated;
grant execute on function public.access_apply_changes(uuid, jsonb) to authenticated;
