-- Anamnese: envio de foto registrado e limitado; "existe ficha?" com permissão. Dado de saúde (RGPD art. 9).
-- Encoding: UTF-8
set client_encoding = 'UTF8';
--
-- 1. anamnese_photo_change (recriada de 20261114040400):
--    - 'add' grava PROFESSIONAL_PHOTO_UPLOAD_AUTHORIZED (quem, qual caminho) na hora em que autoriza o envio, mesmo
--      que a ficha nunca seja salva com a foto (PROFESSIONAL_PHOTO_ADDED, ao salvar, segue pelo gatilho);
--    - 'add' recusa ficha sem parte profissional (mesma regra de anamnese_save_professional);
--    - 'add' recusa quando o Storage já tem 50 arquivos no prefixo <estúdio>/<ficha>/ (limite mole: dois envios
--      ao mesmo tempo podem passar de 50; o que sobrar sai na limpeza ao revogar).
-- 2. anamnese_exists_for (recriada de 20261114040600): continua executável por authenticated, porque
--    agenda_change_client e catalog_delete_item são SECURITY INVOKER e a chamam com os direitos de quem chama.
--    Exige a permissão de quem GRAVA (agendamento → agenda.manage; serviço → catalogo.manage); sem ela, ou fora do
--    estúdio, responde TRUE ("tem ficha": bloqueia a troca / só arquiva), nunca false.
-- 3. anamnese_delete_pending (recriada de 20261114040400): devolve as PASTAS a limpar no Storage, não mais os
--    caminhos salvos: a da ficha apagada e até 19 pastas <estúdio>/<ficha>/ do mesmo estúdio cuja ficha não existe
--    mais (fotos órfãs de limpezas que falharam antes). É a faxina: roda no fluxo de revogar, sem tarefa agendada.
-- 4. anamnese_ficha_screen (recriada de 20261114040200): "Últimos acessos" também mostra
--    PROFESSIONAL_PHOTO_UPLOAD_AUTHORIZED. Resto igual.

create or replace function public.anamnese_photo_change(p_org_id uuid, p_anamnese_id uuid, p_path text, p_action text)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_prefix text := p_org_id::text || '/' || p_anamnese_id::text || '/';
  v_row public.anamneses;
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'anamnese.fill_professional')
     or not public.has_permission(p_org_id, 'clientes.view_clinical') then
    raise exception 'Sem permissão' using errcode = '42501';
  end if;
  if p_action is null or p_action not in ('add', 'remove')
     or pg_catalog.left(coalesce(p_path, ''), pg_catalog.length(v_prefix)) <> v_prefix
     or pg_catalog.substr(p_path, pg_catalog.length(v_prefix) + 1) !~ '^[0-9a-f-]{36}\.(jpg|png|webp|heic)$' then
    raise exception 'Caminho inválido' using errcode = '22023';
  end if;
  select a.* into v_row from public.anamneses a
  where a.org_id = p_org_id and a.id = p_anamnese_id
    and public.anamnese_row_in_scope(a.org_id, a.appointment_id, a.created_by)
  for update;
  if not found then
    raise exception 'Ficha de anamnese não encontrada' using errcode = 'P0002';
  end if;
  if v_row.professional_completed_at is not null then
    raise exception 'A parte profissional está concluída. Reabra antes de editar.' using errcode = '23514';
  end if;

  if p_action = 'add' then
    if not v_row.requires_professional
       and coalesce(v_row.template_snapshot -> 'professional_form', 'null'::jsonb) = 'null'::jsonb then
      raise exception 'Esta anamnese não possui parte profissional habilitada' using errcode = '23514';
    end if;
    if (select pg_catalog.count(*) from storage.objects o
        where o.bucket_id = 'anamnese-photos' and o.name like v_prefix || '%') >= 50 then
      raise exception 'Limite de 50 fotos por ficha' using errcode = '22023';
    end if;
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
    values (p_org_id, (select auth.uid()), 'anamneses', 'PROFESSIONAL_PHOTO_UPLOAD_AUTHORIZED', p_anamnese_id,
            pg_catalog.jsonb_build_object('path', p_path));
  else
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
    values (p_org_id, (select auth.uid()), 'anamneses', 'PROFESSIONAL_PHOTO_REMOVED', p_anamnese_id,
            pg_catalog.jsonb_build_object('path', p_path));
  end if;
end;
$$;
revoke all on function public.anamnese_photo_change(uuid, uuid, text, text) from public, anon;
grant execute on function public.anamnese_photo_change(uuid, uuid, text, text) to authenticated;

create or replace function public.anamnese_exists_for(p_org_id uuid, p_appointment_id uuid, p_service_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  -- Na dúvida, "tem ficha" (bloqueia): sem estúdio, sem alvo ou sem a permissão de quem grava.
  select case
    when p_org_id is null or p_org_id not in (select public.auth_org_ids())
         or (p_appointment_id is null and p_service_id is null)
         or (p_appointment_id is not null and not public.has_permission(p_org_id, 'agenda.manage'))
         or (p_service_id is not null and not public.has_permission(p_org_id, 'catalogo.manage')) then true
    else exists (
      select 1 from public.anamneses a
      where a.org_id = p_org_id
        and (p_appointment_id is null or a.appointment_id = p_appointment_id)
        and (p_service_id is null or a.source_service_id = p_service_id))
  end;
$$;
revoke all on function public.anamnese_exists_for(uuid, uuid, uuid) from public, anon;
grant execute on function public.anamnese_exists_for(uuid, uuid, uuid) to authenticated;

create or replace function public.anamnese_delete_pending(p_org_id uuid, p_anamnese_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
  v_org text := p_org_id::text || '/';
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'anamnese.fill_professional')
     or not public.has_permission(p_org_id, 'clientes.view_clinical') then
    raise exception 'Sem permissão para revogar fichas' using errcode = '42501';
  end if;
  if not public.anamnese_in_scope(p_org_id, p_anamnese_id) then
    raise exception 'Ficha de anamnese não encontrada' using errcode = 'P0002';
  end if;
  select a.status into v_status
  from public.anamneses a where a.org_id = p_org_id and a.id = p_anamnese_id
  for update;
  if not found then
    raise exception 'Ficha de anamnese não encontrada' using errcode = 'P0002';
  end if;
  if v_status = 'signed' then
    raise exception 'Fichas assinadas não podem ser excluídas' using errcode = 'P0001';
  end if;
  delete from public.anamneses a where a.org_id = p_org_id and a.id = p_anamnese_id and a.status = 'pending';
  if not found then
    raise exception 'Ficha pendente não encontrada' using errcode = 'P0002';
  end if;
  -- Pastas a limpar: a desta ficha primeiro e as órfãs do estúdio (só ids; nada da cliente).
  return pg_catalog.jsonb_build_array(v_org || p_anamnese_id::text || '/') || coalesce((
    select pg_catalog.jsonb_agg(v_org || f.id || '/')
    from (
      select distinct pg_catalog.split_part(o.name, '/', 2) as id
      from storage.objects o
      where o.bucket_id = 'anamnese-photos' and o.name like v_org || '%'
    ) f
    where f.id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      and f.id <> p_anamnese_id::text
      and not exists (select 1 from public.anamneses a where a.id = f.id::uuid)
    limit 19), '[]'::jsonb);
end;
$$;
revoke all on function public.anamnese_delete_pending(uuid, uuid) from public, anon;
grant execute on function public.anamnese_delete_pending(uuid, uuid) to authenticated;

CREATE OR REPLACE FUNCTION public.anamnese_ficha_screen(p_org_id uuid, p_anamnese_id uuid, p_view text DEFAULT 'ficha'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $$
declare
  v_uid uuid := (select auth.uid());
  v_row public.anamneses;
  v_status jsonb;
  v_ficha jsonb;
begin
  if p_view is null or p_view not in ('ficha', 'janela') then
    raise exception 'Visão inválida' using errcode = '22023';
  end if;
  if v_uid is null or not (public.has_permission(p_org_id, 'anamnese.view_status') or public.has_permission(p_org_id, 'clientes.view_clinical')) then
    raise exception 'Sem permissão para consultar fichas de anamnese' using errcode = '42501';
  end if;

  if not public.has_permission(p_org_id, 'clientes.view_clinical') then
    select pg_catalog.to_jsonb(s) into v_status
    from public.list_anamnese_status(p_org_id, p_ids => array[p_anamnese_id]) s;
    return case when v_status is null then null else pg_catalog.jsonb_build_object('clinical', false, 'ficha', v_status) end;
  end if;

  select a.* into v_row
  from public.anamneses a
  where a.org_id = p_org_id and a.id = p_anamnese_id
    and public.anamnese_row_in_scope(a.org_id, a.appointment_id, a.created_by);
  if not found then
    return null;
  end if;

  -- Sem registro da leitura, a ficha não é entregue (a falha do INSERT desfaz tudo).
  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
  values (p_org_id, v_uid, 'anamneses', 'CLINICAL_READ', v_row.id, pg_catalog.jsonb_build_object('source', p_view));

  v_ficha := (pg_catalog.to_jsonb(v_row) - array['public_token', 'created_by', 'signer_ip'])
    || pg_catalog.jsonb_build_object(
      'public_token', case when v_row.status = 'pending' and v_row.token_expires_at >= pg_catalog.now() then v_row.public_token end,
      'signer_ip', public.anamnese_mask_ip_internal(v_row.signer_ip));
  if p_view = 'janela' then
    return pg_catalog.jsonb_build_object('clinical', true,
      'ficha', v_ficha - array['professional_notes', 'professional_data']
        || pg_catalog.jsonb_build_object('professional_notes', null, 'professional_data', null));
  end if;

  return pg_catalog.jsonb_build_object(
    'clinical', true,
    'ficha', v_ficha,
    'client', case when public.has_permission(p_org_id, 'clientes.view') then (
      select pg_catalog.jsonb_build_object('id', c.id, 'full_name', c.full_name, 'phone', c.phone, 'email', c.email,
        'birth_date', c.birth_date, 'alert_text', c.alert_text)
      from public.clients c where c.id = v_row.client_id and c.org_id = p_org_id) end,
    'appointment', (
      select pg_catalog.jsonb_build_object('start_at', ap.start_at, 'status', ap.status, 'service_label', (
        select pg_catalog.string_agg(i.name, ' · ' order by i.created_at, i.id)
        from public.appointment_items i
        where i.appointment_id = ap.id and i.org_id = p_org_id and pg_catalog.lower(i.type) = 'service'))
      from public.appointments ap
      where ap.id = v_row.appointment_id and ap.org_id = p_org_id and public.anamnese_row_in_scope(p_org_id, ap.id, null)),
    -- Últimos acessos: só para quem lê a auditoria (dona, administração, gestão; mesma regra de audit_select_manager)
    -- e só as operações que esta ficha gera (leitura clínica e Ficha Profissional), nunca outra coisa com o mesmo id.
    'accesses', case when public.auth_user_role(p_org_id) in ('owner', 'admin', 'manager') then coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'operation', l.operation, 'created_at', l.created_at,
          'user_name', (select p.full_name from public.profiles p where p.org_id = p_org_id and p.user_id = l.user_id limit 1))
        order by l.created_at desc, l.id)
      from (
        select al.id, al.operation, al.created_at, al.user_id from public.audit_logs al
        where al.org_id = p_org_id and al.table_name = 'anamneses' and al.record_id = v_row.id
          and al.operation in ('CLINICAL_READ', 'PROFESSIONAL_DRAFT_SAVED', 'PROFESSIONAL_COMPLETED',
                               'PROFESSIONAL_NOTES_UPDATED', 'PROFESSIONAL_REOPENED',
                               'PROFESSIONAL_PHOTO_ADDED', 'PROFESSIONAL_PHOTO_REMOVED', 'PROFESSIONAL_PHOTO_UPLOAD_AUTHORIZED')
        order by al.created_at desc, al.id
        limit 8
      ) l), '[]'::jsonb) else '[]'::jsonb end,
    'events', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'id', e.id, 'anamnese_id', e.anamnese_id, 'client_name', v_row.client_name, 'kind', e.kind, 'channel', e.channel,
          'user_name', (select p.full_name from public.profiles p where p.org_id = p_org_id and p.user_id = e.user_id limit 1),
          'meta', e.meta, 'created_at', e.created_at) order by e.created_at desc, e.id)
      from (
        select ev.* from public.anamnese_events ev
        where ev.org_id = p_org_id and ev.anamnese_id = v_row.id
        order by ev.created_at desc, ev.id
        limit 50
      ) e), '[]'::jsonb)
  );
end;
$$;
revoke all on function public.anamnese_ficha_screen(uuid, uuid, text) from public, anon;
grant execute on function public.anamnese_ficha_screen(uuid, uuid, text) to authenticated;
