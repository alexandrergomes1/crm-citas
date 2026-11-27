-- Etapas do atendimento e gorjeta configuráveis (P4, aprovado em 07/11).
-- Encoding: UTF-8
--
-- Fica em organizations.settings.attendance (o mesmo lugar das travas da ficha, settings.anamnese):
--   confirm_enabled, start_enabled, separate_arrival, require_stage_before_checkout (booleanos),
--   tip_mode ('off' | 'menu' | 'step'), labels e descriptions (texto por etapa, escrito pela empresa).
-- Só quem tem ajustes.manage grava. A troca de status continua conferida por agenda_status_transition_allowed:
-- desligar uma etapa só tira a opção do menu (Agendado já pode ir direto para Chegou ou Iniciado).

create or replace function public.set_attendance_settings(p_org_id uuid, p_settings jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_clean jsonb;
  v_key text;
  v_labels jsonb := '{}'::jsonb;
  v_descriptions jsonb := '{}'::jsonb;
  v_text text;
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'ajustes.manage') then
    raise exception 'Sem permissão para alterar configurações' using errcode = '42501';
  end if;
  if p_settings is null or pg_catalog.jsonb_typeof(p_settings) <> 'object' then
    raise exception 'Configuração inválida' using errcode = '22023';
  end if;
  if coalesce(p_settings ->> 'tip_mode', 'menu') not in ('off', 'menu', 'step') then
    raise exception 'Gorjeta inválida' using errcode = '22023';
  end if;

  -- Só as etapas conhecidas e textos curtos (nome até 20, descrição até 120).
  foreach v_key in array array['pendente', 'confirmado', 'chegou', 'atendimento', 'faltou', 'cancelar'] loop
    v_text := pg_catalog.btrim(coalesce(p_settings -> 'labels' ->> v_key, ''));
    if v_text <> '' then
      if char_length(v_text) > 20 then raise exception 'Nome da etapa longo demais' using errcode = '22023'; end if;
      v_labels := v_labels || pg_catalog.jsonb_build_object(v_key, v_text);
    end if;
    v_text := pg_catalog.btrim(coalesce(p_settings -> 'descriptions' ->> v_key, ''));
    if v_text <> '' then
      if char_length(v_text) > 120 then raise exception 'Descrição da etapa longa demais' using errcode = '22023'; end if;
      v_descriptions := v_descriptions || pg_catalog.jsonb_build_object(v_key, v_text);
    end if;
  end loop;

  v_clean := pg_catalog.jsonb_build_object(
    'confirm_enabled', coalesce((p_settings ->> 'confirm_enabled')::boolean, true),
    'start_enabled', coalesce((p_settings ->> 'start_enabled')::boolean, true),
    'separate_arrival', coalesce((p_settings ->> 'separate_arrival')::boolean, false),
    'require_stage_before_checkout', coalesce((p_settings ->> 'require_stage_before_checkout')::boolean, false),
    'tip_mode', coalesce(p_settings ->> 'tip_mode', 'menu'),
    'labels', v_labels,
    'descriptions', v_descriptions
  );

  update public.organizations o
     set settings = pg_catalog.jsonb_set(coalesce(o.settings, '{}'::jsonb), '{attendance}', v_clean, true)
   where o.id = p_org_id;
  if not found then
    raise exception 'Estúdio não encontrado' using errcode = 'P0002';
  end if;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
  values (p_org_id, (select auth.uid()), 'organizations', 'ATTENDANCE_SETTINGS_SET', p_org_id, v_clean);
end;
$$;

revoke all on function public.set_attendance_settings(uuid, jsonb) from public, anon;
grant execute on function public.set_attendance_settings(uuid, jsonb) to authenticated, service_role;
