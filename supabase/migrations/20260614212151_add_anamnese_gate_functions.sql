create or replace function public.get_appointment_anamnese_gate(
  p_org_id uuid,
  p_appointment_id uuid,
  p_stage text
)
returns table (
  issue_code text,
  template_id uuid,
  template_title text,
  service_name text,
  anamnese_id uuid
)
language plpgsql
security invoker
set search_path = ''
stable
as $$
declare
  v_role text;
begin
  v_role := public.auth_user_role(p_org_id);
  if v_role not in (
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

create or replace function public.assert_appointment_anamnese_gate(
  p_org_id uuid,
  p_appointment_id uuid,
  p_stage text
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_message text;
begin
  select pg_catalog.string_agg(
    case gate.issue_code
      when 'MISSING_TEMPLATE_CONFIG' then
        pg_catalog.format(
          'O servico "%s" exige anamnese, mas nao possui modelo configurado.',
          gate.service_name
        )
      when 'MISSING_FORM' then
        pg_catalog.format(
          'A ficha "%s" ainda nao foi vinculada ao atendimento.',
          gate.template_title
        )
      when 'CLIENT_PENDING' then
        pg_catalog.format(
          'A ficha "%s" ainda nao foi assinada pelo cliente.',
          gate.template_title
        )
      when 'PROFESSIONAL_PENDING' then
        pg_catalog.format(
          'A ficha profissional de "%s" ainda nao foi concluida.',
          gate.template_title
        )
    end,
    ' '
  )
  into v_message
  from public.get_appointment_anamnese_gate(
    p_org_id,
    p_appointment_id,
    p_stage
  ) gate;

  if v_message is not null then
    raise exception '%', v_message using errcode = 'P0001';
  end if;
end;
$$;

create or replace function public.enforce_appointment_anamnese_status_gate()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.status is not distinct from old.status then
    return new;
  end if;

  if new.status = 'Iniciado' then
    perform public.assert_appointment_anamnese_gate(
      new.org_id,
      new.id,
      'start'
    );
  elsif new.status in ('Pago Parcial', 'Pago') then
    perform public.assert_appointment_anamnese_gate(
      new.org_id,
      new.id,
      'checkout'
    );
  end if;

  return new;
end;
$$;

create or replace function public.enforce_appointment_item_anamnese_gate()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_status text;
begin
  select a.status
    into v_status
  from public.appointments a
  where a.id = new.appointment_id
    and a.org_id = new.org_id;

  if v_status = 'Iniciado' then
    perform public.assert_appointment_anamnese_gate(
      new.org_id,
      new.appointment_id,
      'start'
    );
  elsif v_status in ('Pago Parcial', 'Pago') then
    perform public.assert_appointment_anamnese_gate(
      new.org_id,
      new.appointment_id,
      'checkout'
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_appointment_anamnese_status_gate
  on public.appointments;
create trigger trg_enforce_appointment_anamnese_status_gate
before update of status on public.appointments
for each row
execute function public.enforce_appointment_anamnese_status_gate();

drop trigger if exists trg_verify_appointment_item_anamnese_gate
  on public.appointment_items;
create trigger trg_verify_appointment_item_anamnese_gate
after insert or update on public.appointment_items
for each row
execute function public.enforce_appointment_item_anamnese_gate();

revoke all on function public.get_appointment_anamnese_gate(
  uuid, uuid, text
) from public, anon;
grant execute on function public.get_appointment_anamnese_gate(
  uuid, uuid, text
) to authenticated;

revoke all on function public.assert_appointment_anamnese_gate(
  uuid, uuid, text
) from public, anon;
grant execute on function public.assert_appointment_anamnese_gate(
  uuid, uuid, text
) to authenticated;

revoke all on function public.enforce_appointment_anamnese_status_gate()
  from public, anon, authenticated;
revoke all on function public.enforce_appointment_item_anamnese_gate()
  from public, anon, authenticated;
