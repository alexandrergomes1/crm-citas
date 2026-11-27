-- Travas da anamnese configuráveis por estúdio (Ajustes › Ficha de saúde).
-- Padrão: as duas travas ligadas (iniciar exige a Ficha Cliente assinada; cobrar exige também a Ficha Profissional).
-- O estúdio pode desligar cada uma. O que cada serviço exige continua sendo definido no Catálogo.
-- Encoding: UTF-8

-- 1. Leitura da configuração (padrão: ligado) ---------------------------------------------------------------
create or replace function public.anamnese_gate_enabled(p_org_id uuid, p_stage text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select case o.settings -> 'anamnese' -> 'gate' ->> p_stage when 'false' then false when 'true' then true else null end
       from public.organizations o where o.id = p_org_id),
    true
  );
$$;
revoke all on function public.anamnese_gate_enabled(uuid, text) from public, anon;
grant execute on function public.anamnese_gate_enabled(uuid, text) to authenticated;

-- 2. A consulta da trava passa a respeitar a configuração ---------------------------------------------------
alter function public.get_appointment_anamnese_gate(uuid, uuid, text) rename to get_appointment_anamnese_gate_raw;
revoke all on function public.get_appointment_anamnese_gate_raw(uuid, uuid, text) from public, anon, authenticated;

create or replace function public.get_appointment_anamnese_gate(p_org_id uuid, p_appointment_id uuid, p_stage text)
returns table (issue_code text, template_id uuid, template_title text, service_name text, anamnese_id uuid)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_stage not in ('start', 'checkout') then
    raise exception 'Etapa do gate clinico invalida' using errcode = '22023';
  end if;
  -- A validação de papel e de agendamento continua na função original; aqui só a chave liga/desliga.
  if not public.anamnese_gate_enabled(p_org_id, p_stage) then
    perform count(*) from public.get_appointment_anamnese_gate_raw(p_org_id, p_appointment_id, p_stage);
    return;
  end if;
  return query select * from public.get_appointment_anamnese_gate_raw(p_org_id, p_appointment_id, p_stage);
end;
$$;
revoke all on function public.get_appointment_anamnese_gate(uuid, uuid, text) from public, anon;
grant execute on function public.get_appointment_anamnese_gate(uuid, uuid, text) to authenticated;

-- 3. Gravar as travas ---------------------------------------------------------------------------------------
create or replace function public.set_anamnese_gate(p_org_id uuid, p_gate_start boolean, p_gate_checkout boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'ajustes.manage') then
    raise exception 'Sem permissão para alterar configurações' using errcode = '42501';
  end if;
  if p_gate_start is null or p_gate_checkout is null then
    raise exception 'Trava inválida' using errcode = '22023';
  end if;
  update public.organizations o
     set settings = pg_catalog.jsonb_set(
           coalesce(o.settings, '{}'::jsonb), '{anamnese}',
           coalesce(o.settings -> 'anamnese', '{}'::jsonb)
             || pg_catalog.jsonb_build_object('gate', pg_catalog.jsonb_build_object('start', p_gate_start, 'checkout', p_gate_checkout)), true)
   where o.id = p_org_id;
  if not found then
    raise exception 'Estúdio não encontrado' using errcode = 'P0002';
  end if;
  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
  values (p_org_id, (select auth.uid()), 'organizations', 'ANAMNESE_GATE_SET', p_org_id,
          pg_catalog.jsonb_build_object('start', p_gate_start, 'checkout', p_gate_checkout));
end;
$$;
revoke all on function public.set_anamnese_gate(uuid, boolean, boolean) from public, anon;
grant execute on function public.set_anamnese_gate(uuid, boolean, boolean) to authenticated;

-- 4. As configurações de validade/modo estúdio não apagam mais as travas ------------------------------------
create or replace function public.set_anamnese_settings(p_org_id uuid, p_link_days integer, p_studio_mode boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'ajustes.manage') then
    raise exception 'Sem permissão para alterar configurações' using errcode = '42501';
  end if;
  if p_link_days is null or p_link_days not in (1, 3, 7, 15, 30) then
    raise exception 'Validade inválida' using errcode = '22023';
  end if;
  if p_studio_mode is null then
    raise exception 'Modo estúdio inválido' using errcode = '22023';
  end if;

  update public.organizations o
     set settings = pg_catalog.jsonb_set(
           coalesce(o.settings, '{}'::jsonb), '{anamnese}',
           coalesce(o.settings -> 'anamnese', '{}'::jsonb)
             || pg_catalog.jsonb_build_object('link_days', p_link_days, 'studio_mode', p_studio_mode), true)
   where o.id = p_org_id;
  if not found then
    raise exception 'Estúdio não encontrado' using errcode = 'P0002';
  end if;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
  values (p_org_id, (select auth.uid()), 'organizations', 'ANAMNESE_SETTINGS_SET', p_org_id,
          pg_catalog.jsonb_build_object('link_days', p_link_days, 'studio_mode', p_studio_mode));
end;
$$;
