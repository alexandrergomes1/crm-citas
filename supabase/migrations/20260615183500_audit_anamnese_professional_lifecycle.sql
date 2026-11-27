-- KA Beauty OS - Audit professional anamnese lifecycle
-- Encoding: UTF-8

create or replace function public.save_anamnese_professional_data_atomic(
  p_org_id uuid,
  p_anamnese_id uuid,
  p_data jsonb,
  p_complete boolean default false
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_role text;
  v_row public.anamneses;
begin
  v_role := public.auth_user_role(p_org_id);
  if v_role not in ('owner', 'admin', 'manager', 'professional') then
    raise exception 'Sem permissao para editar a parte profissional'
      using errcode = '42501';
  end if;

  select *
  into v_row
  from public.anamneses
  where id = p_anamnese_id
    and org_id = p_org_id
  for update;

  if not found then
    raise exception 'Ficha de anamnese nao encontrada'
      using errcode = 'P0002';
  end if;

  if v_row.professional_completed_at is not null then
    raise exception 'A parte profissional esta concluida. Reabra antes de editar.'
      using errcode = '23514';
  end if;

  if not v_row.requires_professional
    and coalesce(v_row.template_snapshot -> 'professional_form', 'null'::jsonb) = 'null'::jsonb
  then
    raise exception 'Esta anamnese nao possui parte profissional habilitada'
      using errcode = '23514';
  end if;

  update public.anamneses
  set
    professional_data = coalesce(p_data, '{}'::jsonb),
    professional_completed_at = case when p_complete then pg_catalog.now() else null end,
    updated_at = pg_catalog.now()
  where id = p_anamnese_id
    and org_id = p_org_id;

  insert into public.audit_logs (
    org_id, user_id, table_name, operation, record_id, old_data, new_data
  )
  values (
    p_org_id,
    auth.uid(),
    'anamneses',
    case when p_complete then 'PROFESSIONAL_COMPLETED' else 'PROFESSIONAL_DRAFT_SAVED' end,
    p_anamnese_id,
    pg_catalog.jsonb_build_object(
      'completed', v_row.professional_completed_at is not null,
      'has_data', coalesce(v_row.professional_data, '{}'::jsonb) <> '{}'::jsonb
    ),
    pg_catalog.jsonb_build_object(
      'completed', p_complete,
      'has_data', coalesce(p_data, '{}'::jsonb) <> '{}'::jsonb
    )
  );
end;
$$;

create or replace function public.reopen_anamnese_professional_atomic(
  p_org_id uuid,
  p_anamnese_id uuid
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_role text;
  v_row public.anamneses;
begin
  v_role := public.auth_user_role(p_org_id);
  if v_role not in ('owner', 'admin', 'manager') then
    raise exception 'Somente a gestao pode reabrir uma parte profissional concluida'
      using errcode = '42501';
  end if;

  select *
  into v_row
  from public.anamneses
  where id = p_anamnese_id
    and org_id = p_org_id
  for update;

  if not found then
    raise exception 'Ficha de anamnese nao encontrada'
      using errcode = 'P0002';
  end if;

  if v_row.professional_completed_at is null then
    return;
  end if;

  update public.anamneses
  set
    professional_completed_at = null,
    updated_at = pg_catalog.now()
  where id = p_anamnese_id
    and org_id = p_org_id;

  insert into public.audit_logs (
    org_id, user_id, table_name, operation, record_id, old_data, new_data
  )
  values (
    p_org_id,
    auth.uid(),
    'anamneses',
    'PROFESSIONAL_REOPENED',
    p_anamnese_id,
    pg_catalog.jsonb_build_object(
      'professional_completed_at', v_row.professional_completed_at
    ),
    pg_catalog.jsonb_build_object(
      'professional_completed_at', null
    )
  );
end;
$$;

revoke all on function public.save_anamnese_professional_data_atomic(
  uuid, uuid, jsonb, boolean
) from public, anon;
grant execute on function public.save_anamnese_professional_data_atomic(
  uuid, uuid, jsonb, boolean
) to authenticated;

revoke all on function public.reopen_anamnese_professional_atomic(
  uuid, uuid
) from public, anon;
grant execute on function public.reopen_anamnese_professional_atomic(
  uuid, uuid
) to authenticated;
