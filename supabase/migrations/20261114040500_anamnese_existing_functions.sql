-- Anamnese (porte): funções que já existiam, recriadas com o alcance de 20261114040000 e sem auditoria própria.
-- Encoding: UTF-8
set client_encoding = 'UTF8';
--
-- create_anamnese_atomic (agendamento só no alcance), set_anamnese_link_validity e log_anamnese_send (ficha no
-- alcance): mesmo corpo da versão vigente + a checagem. As da parte profissional deixam de gravar auditoria (o
-- gatilho de 20261114040400 grava; a da nota guardava o texto inteiro da nota); as de dados e de nota saem do app
-- e perdem a execução pela API; a de reabrir (usada pelo app) ganha o alcance e vira DEFINER (tabela fechada).

-- create_anamnese_atomic: igual à versão vigente (20261029110000 + 20261029130000), com o alcance do agendamento.
CREATE OR REPLACE FUNCTION public.create_anamnese_atomic(p_org_id uuid, p_template_id uuid, p_client_id uuid, p_client_name text, p_appointment_id uuid DEFAULT NULL::uuid, p_requires_professional boolean DEFAULT NULL::boolean)
 RETURNS anamneses
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_role text;
  v_clinical boolean;
  v_template public.anamnese_templates;
  v_appointment public.appointments;
  v_client public.clients;
  v_result public.anamneses;
  v_client_id uuid := p_client_id;
  v_client_name text := nullif(pg_catalog.btrim(p_client_name), '');
begin
  v_role := public.auth_user_role(p_org_id);
  if v_role is null or not public.has_permission(p_org_id, 'anamnese.view_status') then
    raise exception 'Sem permissao para gerar fichas de anamnese'
      using errcode = '42501';
  end if;
  v_clinical := public.has_permission(p_org_id, 'clientes.view_clinical');

  select * into v_template
  from public.anamnese_templates t
  where t.id = p_template_id
    and t.org_id = p_org_id
    and t.active = true;

  if not found then
    raise exception 'Modelo de anamnese ativo nao encontrado'
      using errcode = 'P0002';
  end if;

  if p_appointment_id is not null then
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(
        p_org_id::text || ':' || p_appointment_id::text || ':' || p_template_id::text,
        0
      )
    );

    select * into v_appointment
    from public.appointments a
    where a.id = p_appointment_id
      and a.org_id = p_org_id
    for update;

    -- Alcance (20261114040400): só o agendamento que a pessoa enxerga (agenda inteira ou dela).
    if not found or not public.anamnese_row_in_scope(p_org_id, p_appointment_id, null) then
      raise exception 'Agendamento não encontrado'
        using errcode = 'P0002';
    end if;

    v_client_id := v_appointment.client_id;
    v_client_name := v_appointment.client_name;

    select * into v_result
    from public.anamneses an
    where an.org_id = p_org_id
      and an.appointment_id = p_appointment_id
      and an.template_id = p_template_id;

    if found then
      if not v_clinical then
        v_result.answers := '{}'::jsonb;
        v_result.professional_notes := null;
        v_result.professional_data := null;
        v_result.signature_name := null;
        v_result.signature_data_url := null;
        v_result.signer_ip := null;
        v_result.signer_user_agent := null;
      end if;
      return v_result;
    end if;
  elsif v_client_id is not null then
    select * into v_client
    from public.clients c
    where c.id = v_client_id
      and c.org_id = p_org_id;

    if not found then
      raise exception 'Cliente nao encontrado nesta organizacao'
        using errcode = 'P0002';
    end if;
    v_client_name := v_client.full_name;
  end if;

  if v_client_name is null then
    raise exception 'Informe o cliente'
      using errcode = '22023';
  end if;

  insert into public.anamneses (
    org_id,
    template_id,
    template_title,
    template_snapshot,
    client_id,
    client_name,
    appointment_id,
    status,
    requires_professional,
    source_service_id,
    public_token,
    token_expires_at,
    consent_text,
    consent_version
  )
  values (
    p_org_id,
    v_template.id,
    v_template.title,
    pg_catalog.jsonb_build_object(
      'questions', v_template.questions,
      'consent_text', v_template.consent_text,
      'professional_form', v_template.professional_form
    ),
    v_client_id,
    v_client_name,
    p_appointment_id,
    'pending',
    coalesce(
      p_requires_professional,
      v_template.professional_form is not null
    ),
    null,
    pg_catalog.encode(extensions.gen_random_bytes(16), 'hex'),
    pg_catalog.now() + interval '7 days',
    v_template.consent_text,
    v_template.consent_version
  )
  returning * into v_result;

  if p_appointment_id is not null then
    update public.appointments
    set linked_anamnese_id = coalesce(linked_anamnese_id, v_result.id)
    where id = p_appointment_id
      and org_id = p_org_id;
  end if;

  insert into public.audit_logs (
    org_id, user_id, table_name, operation, record_id, new_data
  )
  values (
    p_org_id,
    auth.uid(),
    'anamneses',
    'ANAMNESE_CREATED',
    v_result.id,
    pg_catalog.jsonb_build_object(
      'appointment_id', p_appointment_id,
      'template_id', p_template_id,
      'client_id', v_client_id
    )
  );

  -- Ficha nova ainda não tem dado clínico; a limpeza vale só por consistência.
  if not v_clinical then
    v_result.answers := '{}'::jsonb;
    v_result.professional_notes := null;
    v_result.professional_data := null;
    v_result.signature_name := null;
    v_result.signature_data_url := null;
    v_result.signer_ip := null;
    v_result.signer_user_agent := null;
  end if;
  return v_result;
end;
$function$;

-- set_anamnese_link_validity: igual à versão vigente (20261030400000), com o alcance.
CREATE OR REPLACE FUNCTION public.set_anamnese_link_validity(p_org_id uuid, p_anamnese_id uuid, p_days integer)
 RETURNS timestamp with time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := (select auth.uid());
  v_ficha record;
  v_until timestamptz;
begin
  if v_uid is null or not public.has_permission(p_org_id, 'anamnese.view_status') then
    raise exception 'Sem permissão para alterar a validade do link' using errcode = '42501';
  end if;
  -- Alcance (20261114040400): ficha fora do alcance é como inexistente.
  if not public.anamnese_in_scope(p_org_id, p_anamnese_id) then
    raise exception 'Ficha não encontrada' using errcode = 'P0002';
  end if;
  if p_days is null or p_days not in (1, 3, 7, 15, 30) then
    raise exception 'Validade inválida' using errcode = '22023';
  end if;

  select a.id, a.status, a.token_expires_at into v_ficha
  from public.anamneses a where a.id = p_anamnese_id and a.org_id = p_org_id for update;
  if not found then
    raise exception 'Ficha não encontrada' using errcode = 'P0002';
  end if;
  if v_ficha.status = 'signed' then
    raise exception 'Ficha já assinada' using errcode = 'P0001';
  end if;

  v_until := pg_catalog.now() + pg_catalog.make_interval(days => p_days);
  update public.anamneses set token_expires_at = v_until where id = p_anamnese_id and org_id = p_org_id;

  -- Link que já tinha vencido e foi reaberto fica registrado.
  if v_ficha.token_expires_at < pg_catalog.now() then
    insert into public.anamnese_events (org_id, anamnese_id, kind, user_id, meta)
    values (p_org_id, p_anamnese_id, 'renewed', v_uid,
            pg_catalog.jsonb_build_object('days', p_days, 'expires_at', v_until));
  end if;
  return v_until;
end;
$function$;

-- log_anamnese_send: igual à versão vigente (20261030400000), com o alcance.
CREATE OR REPLACE FUNCTION public.log_anamnese_send(p_org_id uuid, p_anamnese_id uuid, p_channel text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := (select auth.uid());
  v_ficha record;
  v_id uuid;
begin
  if v_uid is null or not public.has_permission(p_org_id, 'anamnese.view_status') then
    raise exception 'Sem permissão para registrar envio de ficha' using errcode = '42501';
  end if;
  -- Alcance (20261114040400): ficha fora do alcance é como inexistente.
  if not public.anamnese_in_scope(p_org_id, p_anamnese_id) then
    raise exception 'Ficha não encontrada' using errcode = 'P0002';
  end if;
  if p_channel is null or p_channel not in ('whatsapp', 'qr', 'studio', 'copy') then
    raise exception 'Canal de envio inválido' using errcode = '22023';
  end if;

  select a.id, a.status, a.token_expires_at into v_ficha
  from public.anamneses a where a.id = p_anamnese_id and a.org_id = p_org_id for update;
  if not found then
    raise exception 'Ficha não encontrada' using errcode = 'P0002';
  end if;
  if v_ficha.status = 'signed' then
    raise exception 'Ficha já assinada' using errcode = 'P0001';
  end if;

  -- Duplo clique ou nova tentativa em 10 s: devolve o registro que já existe.
  select e.id into v_id from public.anamnese_events e
  where e.anamnese_id = p_anamnese_id and e.kind = 'sent' and e.channel = p_channel and e.user_id = v_uid
    and e.created_at > pg_catalog.now() - interval '10 seconds'
  order by e.created_at desc limit 1;
  if found then return v_id; end if;

  insert into public.anamnese_events (org_id, anamnese_id, kind, channel, user_id, meta)
  values (p_org_id, p_anamnese_id, 'sent', p_channel, v_uid,
          pg_catalog.jsonb_build_object('expires_at', v_ficha.token_expires_at))
  returning id into v_id;
  return v_id;
end;
$function$;

-- ─── Funções antigas da parte profissional, sem o próprio INSERT na auditoria ──────────────────────
-- Mesmo comportamento da versão vigente (20260615183500 / 20261029070000, com a troca para has_permission de
-- 20261029130000); só sai o INSERT em audit_logs, que agora é do gatilho. A nota antiga deixava o texto inteiro
-- da nota na auditoria; o gatilho guarda só se mudou e o tamanho.
create or replace function public.save_anamnese_professional_data_atomic(
  p_org_id uuid, p_anamnese_id uuid, p_data jsonb, p_complete boolean default false
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_row public.anamneses;
begin
  if not public.has_permission(p_org_id, 'anamnese.fill_professional') then
    raise exception 'Sem permissão para editar a parte profissional' using errcode = '42501';
  end if;
  select * into v_row from public.anamneses where id = p_anamnese_id and org_id = p_org_id for update;
  if not found then
    raise exception 'Ficha de anamnese não encontrada' using errcode = 'P0002';
  end if;
  if v_row.professional_completed_at is not null then
    raise exception 'A parte profissional está concluída. Reabra antes de editar.' using errcode = '23514';
  end if;
  if not v_row.requires_professional
     and coalesce(v_row.template_snapshot -> 'professional_form', 'null'::jsonb) = 'null'::jsonb then
    raise exception 'Esta anamnese não possui parte profissional habilitada' using errcode = '23514';
  end if;
  update public.anamneses set
    professional_data = coalesce(p_data, '{}'::jsonb),
    professional_completed_at = case when p_complete then pg_catalog.now() else null end,
    updated_at = pg_catalog.now()
  where id = p_anamnese_id and org_id = p_org_id;
end;
$$;

create or replace function public.save_anamnese_professional_notes_atomic(
  p_org_id uuid, p_anamnese_id uuid, p_notes text
) returns void
language plpgsql
set search_path = ''
as $$
begin
  if not public.has_permission(p_org_id, 'anamnese.fill_professional') then
    raise exception 'Sem permissão para registrar notas profissionais' using errcode = '42501';
  end if;
  perform 1 from public.anamneses where id = p_anamnese_id and org_id = p_org_id for update;
  if not found then
    raise exception 'Ficha de anamnese não encontrada' using errcode = 'P0002';
  end if;
  update public.anamneses set
    professional_notes = nullif(pg_catalog.btrim(coalesce(p_notes, '')), ''),
    updated_at = pg_catalog.now()
  where id = p_anamnese_id and org_id = p_org_id;
end;
$$;

-- Reabrir (usada pelo app): com o alcance.
create or replace function public.reopen_anamnese_professional_atomic(p_org_id uuid, p_anamnese_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.anamneses;
begin
  if public.auth_user_role(p_org_id) is null or public.auth_user_role(p_org_id) not in ('owner', 'admin', 'manager') then
    raise exception 'Somente a gestão pode reabrir uma parte profissional concluída' using errcode = '42501';
  end if;
  if not public.anamnese_in_scope(p_org_id, p_anamnese_id) then
    raise exception 'Ficha de anamnese não encontrada' using errcode = 'P0002';
  end if;
  select * into v_row from public.anamneses where id = p_anamnese_id and org_id = p_org_id for update;
  if not found then
    raise exception 'Ficha de anamnese não encontrada' using errcode = 'P0002';
  end if;
  if v_row.professional_completed_at is null then
    return;
  end if;
  update public.anamneses set professional_completed_at = null, updated_at = pg_catalog.now()
  where id = p_anamnese_id and org_id = p_org_id;
end;
$$;

revoke all on function public.reopen_anamnese_professional_atomic(uuid, uuid) from public, anon;
grant execute on function public.reopen_anamnese_professional_atomic(uuid, uuid) to authenticated;

-- O app não usa mais as duas (anamnese_save_professional as substitui): sem execução pela API.
revoke all on function public.save_anamnese_professional_data_atomic(uuid, uuid, jsonb, boolean) from public, anon, authenticated;
revoke all on function public.save_anamnese_professional_notes_atomic(uuid, uuid, text) from public, anon, authenticated;
