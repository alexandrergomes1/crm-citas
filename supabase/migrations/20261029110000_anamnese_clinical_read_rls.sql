-- Leitura clínica da anamnese só para quem tem acesso clínico (revisão de 29 out).
-- Encoding: UTF-8
-- Antes: a recepção lia a ficha inteira (respostas, assinatura, IP, dados da profissional) direto
-- pela API; o app escondia, o banco não. E as fotos da ficha abriam para qualquer membro.
-- Agora:
--   1. anamneses_select: owner, admin, manager e professional (a recepção sai);
--   2. list_anamnese_status: lista só o status (título, situação, link, datas) para a recepção
--      e para as telas que não precisam de dado clínico;
--   3. gate clínico, auto-vínculo por item e geração de ficha viram security definer, porque a
--      recepção os usa e não lê mais a tabela; create_anamnese_atomic devolve a ficha sem
--      campos clínicos para quem não tem acesso clínico;
--   4. fotos da ficha (storage): só os mesmos quatro papéis.

-- 1. Tabela ---------------------------------------------------------------------------------
drop policy if exists anamneses_select on public.anamneses;
create policy anamneses_select on public.anamneses
  for select to authenticated
  using (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) = any (array['owner', 'admin', 'manager', 'professional'])
  );

-- 2. Status sem dado clínico ----------------------------------------------------------------
create or replace function public.list_anamnese_status(
  p_org_id uuid,
  p_appointment_ids uuid[] default null,
  p_client_id uuid default null,
  p_template_id uuid default null,
  p_status text default null
)
returns table (
  id uuid,
  org_id uuid,
  template_id uuid,
  template_title text,
  client_id uuid,
  client_name text,
  appointment_id uuid,
  status text,
  requires_professional boolean,
  professional_completed_at timestamptz,
  source_service_id uuid,
  public_token text,
  token_expires_at timestamptz,
  consent_version text,
  consent_accepted boolean,
  signed_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path to ''
as $$
declare
  v_role text;
begin
  v_role := public.auth_user_role(p_org_id);
  if v_role is null or v_role not in (
    'owner', 'admin', 'manager', 'receptionist', 'professional'
  ) then
    raise exception 'Sem permissao para consultar fichas de anamnese'
      using errcode = '42501';
  end if;

  return query
  select
    a.id, a.org_id, a.template_id, a.template_title, a.client_id, a.client_name,
    a.appointment_id, a.status, a.requires_professional, a.professional_completed_at,
    a.source_service_id, a.public_token, a.token_expires_at, a.consent_version,
    a.consent_accepted, a.signed_at, a.created_at, a.updated_at
  from public.anamneses a
  where a.org_id = p_org_id
    and (p_appointment_ids is null or a.appointment_id = any (p_appointment_ids))
    and (p_client_id is null or a.client_id = p_client_id)
    and (p_template_id is null or a.template_id = p_template_id)
    and (p_status is null or a.status = p_status)
  order by a.created_at desc, a.id;
end;
$$;

revoke all on function public.list_anamnese_status(uuid, uuid[], uuid, uuid, text) from public;
revoke all on function public.list_anamnese_status(uuid, uuid[], uuid, uuid, text) from anon;
grant execute on function public.list_anamnese_status(uuid, uuid[], uuid, uuid, text) to authenticated;

-- 3a. Gate clínico (a recepção abre e fecha atendimento) --------------------------------------
create or replace function public.get_appointment_anamnese_gate(
  p_org_id uuid, p_appointment_id uuid, p_stage text
)
returns table (
  issue_code text, template_id uuid, template_title text, service_name text, anamnese_id uuid
)
language plpgsql
stable
security definer
set search_path to ''
as $$
declare
  v_role text;
begin
  v_role := public.auth_user_role(p_org_id);
  if v_role is null or v_role not in (
    'owner', 'admin', 'manager', 'receptionist', 'professional', 'finance'
  ) then
    raise exception 'Sem permissao para consultar o gate clinico'
      using errcode = '42501';
  end if;

  if p_stage not in ('start', 'checkout') then
    raise exception 'Etapa do gate clinico invalida'
      using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.appointments a
    where a.id = p_appointment_id
      and a.org_id = p_org_id
  ) then
    raise exception 'Agendamento nao encontrado'
      using errcode = 'P0002';
  end if;

  return query
  with required_items as (
    select
      ai.anamnese_template_id as required_template_id,
      pg_catalog.string_agg(
        distinct ai.name,
        ', ' order by ai.name
      ) as required_service_name
    from public.appointment_items ai
    where ai.org_id = p_org_id
      and ai.appointment_id = p_appointment_id
      and ai.requires_anamnese = true
    group by ai.anamnese_template_id
  ),
  required_issues as (
    select
      case
        when ri.required_template_id is null then 'MISSING_TEMPLATE_CONFIG'
        when an.id is null then 'MISSING_FORM'
        when an.status <> 'signed' then 'CLIENT_PENDING'
        when p_stage = 'checkout'
          and an.requires_professional
          and an.professional_completed_at is null
          then 'PROFESSIONAL_PENDING'
        else null
      end as code,
      ri.required_template_id,
      coalesce(an.template_title, t.title, 'Anamnese') as title,
      ri.required_service_name,
      an.id
    from required_items ri
    left join public.anamnese_templates t
      on t.id = ri.required_template_id
      and t.org_id = p_org_id
    left join public.anamneses an
      on an.org_id = p_org_id
      and an.appointment_id = p_appointment_id
      and an.template_id = ri.required_template_id
  ),
  manual_issues as (
    select
      case
        when an.status <> 'signed' then 'CLIENT_PENDING'
        when p_stage = 'checkout'
          and an.requires_professional
          and an.professional_completed_at is null
          then 'PROFESSIONAL_PENDING'
        else null
      end as code,
      an.template_id,
      an.template_title,
      null::text as required_service_name,
      an.id
    from public.anamneses an
    where an.org_id = p_org_id
      and an.appointment_id = p_appointment_id
      and an.source_service_id is null
      and not exists (
        select 1
        from required_items ri
        where ri.required_template_id = an.template_id
      )
  )
  select
    issues.code,
    issues.required_template_id,
    issues.title,
    issues.required_service_name,
    issues.id
  from (
    select * from required_issues
    union all
    select * from manual_issues
  ) issues
  where issues.code is not null
  order by issues.required_service_name nulls last, issues.title;
end;
$$;

-- 3b. Auto-vínculo da ficha ao incluir serviço (gatilho de appointment_items) --------------------
create or replace function public.ensure_appointment_anamnese_for_item()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_appointment public.appointments;
  v_template public.anamnese_templates;
  v_anamnese_id uuid;
begin
  if not new.requires_anamnese or new.anamnese_template_id is null then return new; end if;
  select * into v_appointment from public.appointments a
  where a.id = new.appointment_id and a.org_id = new.org_id;
  select * into v_template from public.anamnese_templates t
  where t.id = new.anamnese_template_id and t.org_id = new.org_id;
  if not found then
    raise exception 'Modelo de anamnese nao pertence a esta organizacao' using errcode = '23503';
  end if;
  insert into public.anamneses (
    org_id, template_id, template_title, template_snapshot, client_id,
    client_name, appointment_id, status, requires_professional,
    source_service_id, public_token, token_expires_at, consent_text, consent_version
  ) values (
    new.org_id, v_template.id, v_template.title,
    pg_catalog.jsonb_build_object(
      'questions', v_template.questions,
      'consent_text', v_template.consent_text,
      'professional_form', v_template.professional_form
    ),
    v_appointment.client_id, v_appointment.client_name, v_appointment.id,
    'pending', v_template.professional_form is not null, new.ref_id,
    pg_catalog.encode(extensions.gen_random_bytes(16), 'hex'),
    pg_catalog.now() + interval '7 days',
    v_template.consent_text, v_template.consent_version
  )
  on conflict (org_id, appointment_id, template_id)
    where appointment_id is not null and template_id is not null
  do nothing returning id into v_anamnese_id;
  if v_anamnese_id is null then
    select an.id into v_anamnese_id from public.anamneses an
    where an.org_id = new.org_id
      and an.appointment_id = new.appointment_id
      and an.template_id = new.anamnese_template_id;
  else
    insert into public.audit_logs (
      org_id, user_id, table_name, operation, record_id, new_data
    ) values (
      new.org_id, auth.uid(), 'anamneses', 'ANAMNESE_AUTO_LINKED', v_anamnese_id,
      pg_catalog.jsonb_build_object(
        'appointment_id', new.appointment_id,
        'template_id', new.anamnese_template_id,
        'service_id', new.ref_id
      )
    );
  end if;
  update public.appointments
  set linked_anamnese_id = coalesce(linked_anamnese_id, v_anamnese_id)
  where id = new.appointment_id and org_id = new.org_id;
  return new;
end;
$$;

-- 3c. Gerar ficha (a recepção gera; o retorno sai sem campos clínicos para quem não os lê) ------
create or replace function public.create_anamnese_atomic(
  p_org_id uuid,
  p_template_id uuid,
  p_client_id uuid,
  p_client_name text,
  p_appointment_id uuid default null,
  p_requires_professional boolean default null
)
returns public.anamneses
language plpgsql
security definer
set search_path to ''
as $$
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
  if v_role is null or v_role not in (
    'owner', 'admin', 'manager', 'receptionist', 'professional'
  ) then
    raise exception 'Sem permissao para gerar fichas de anamnese'
      using errcode = '42501';
  end if;
  v_clinical := v_role in ('owner', 'admin', 'manager', 'professional');

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

    if not found then
      raise exception 'Agendamento nao encontrado'
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
$$;

-- 4. Fotos da ficha ------------------------------------------------------------------------------
drop policy if exists "anamnese_photos_select" on storage.objects;
drop policy if exists "anamnese_photos_insert" on storage.objects;
drop policy if exists "anamnese_photos_delete" on storage.objects;

create policy "anamnese_photos_select" on storage.objects for select to authenticated
using (
  bucket_id = 'anamnese-photos'
  and public.auth_user_role(((storage.foldername(name))[1])::uuid)
    = any (array['owner', 'admin', 'manager', 'professional'])
);

create policy "anamnese_photos_insert" on storage.objects for insert to authenticated
with check (
  bucket_id = 'anamnese-photos'
  and public.auth_user_role(((storage.foldername(name))[1])::uuid)
    = any (array['owner', 'admin', 'manager', 'professional'])
);

create policy "anamnese_photos_delete" on storage.objects for delete to authenticated
using (
  bucket_id = 'anamnese-photos'
  and public.auth_user_role(((storage.foldername(name))[1])::uuid)
    = any (array['owner', 'admin', 'manager', 'professional'])
);
