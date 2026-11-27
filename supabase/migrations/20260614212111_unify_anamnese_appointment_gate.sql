-- KA Beauty OS - Canonical appointment anamnese link and clinical gate
-- Encoding: UTF-8

alter table public.appointment_items
  add column if not exists requires_anamnese boolean not null default false,
  add column if not exists anamnese_template_id uuid;

alter table public.anamneses
  add column if not exists source_service_id uuid;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'appointment_items_anamnese_template_id_fkey'
      and conrelid = 'public.appointment_items'::regclass
  ) then
    alter table public.appointment_items
      add constraint appointment_items_anamnese_template_id_fkey
      foreign key (anamnese_template_id)
      references public.anamnese_templates(id)
      on delete set null;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'anamneses_source_service_id_fkey'
      and conrelid = 'public.anamneses'::regclass
  ) then
    alter table public.anamneses
      add constraint anamneses_source_service_id_fkey
      foreign key (source_service_id)
      references public.services(id)
      on delete set null;
  end if;
end;
$$;

create index if not exists idx_appointment_items_anamnese_gate
  on public.appointment_items (org_id, appointment_id, anamnese_template_id)
  where requires_anamnese = true;

create index if not exists idx_anamneses_appointment_template
  on public.anamneses (org_id, appointment_id, template_id);

create unique index if not exists uq_anamneses_appointment_template
  on public.anamneses (org_id, appointment_id, template_id)
  where appointment_id is not null and template_id is not null;

create or replace function public.enforce_anamnese_relation_integrity()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_appointment public.appointments;
begin
  if new.template_id is not null and not exists (
    select 1
    from public.anamnese_templates t
    where t.id = new.template_id
      and t.org_id = new.org_id
  ) then
    raise exception 'Modelo de anamnese nao pertence a esta organizacao'
      using errcode = '23503';
  end if;

  if new.client_id is not null and not exists (
    select 1
    from public.clients c
    where c.id = new.client_id
      and c.org_id = new.org_id
  ) then
    raise exception 'Cliente da anamnese nao pertence a esta organizacao'
      using errcode = '23503';
  end if;

  if new.source_service_id is not null and not exists (
    select 1
    from public.services s
    where s.id = new.source_service_id
      and s.org_id = new.org_id
  ) then
    raise exception 'Servico da anamnese nao pertence a esta organizacao'
      using errcode = '23503';
  end if;

  if new.appointment_id is not null then
    select *
      into v_appointment
    from public.appointments a
    where a.id = new.appointment_id
      and a.org_id = new.org_id;

    if not found then
      raise exception 'Agendamento da anamnese nao pertence a esta organizacao'
        using errcode = '23503';
    end if;

    if new.client_id is distinct from v_appointment.client_id then
      raise exception 'A ficha deve pertencer ao cliente do atendimento'
        using errcode = '23514';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_anamnese_relation_integrity
  on public.anamneses;
create trigger trg_enforce_anamnese_relation_integrity
before insert or update on public.anamneses
for each row
execute function public.enforce_anamnese_relation_integrity();

update public.appointments a
set linked_anamnese_id = (
  select an.id
  from public.anamneses an
  where an.org_id = a.org_id
    and an.appointment_id = a.id
  order by an.created_at, an.id
  limit 1
)
where a.linked_anamnese_id is null
  and exists (
    select 1
    from public.anamneses an
    where an.org_id = a.org_id
      and an.appointment_id = a.id
  );

create or replace function public.enforce_appointment_item_integrity()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_service public.services;
begin
  if new.type <> 'service' then
    raise exception 'Tipo de item de agendamento invalido'
      using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.appointments a
    where a.id = new.appointment_id
      and a.org_id = new.org_id
  ) then
    raise exception 'Agendamento nao pertence a esta organizacao'
      using errcode = '23503';
  end if;

  if pg_catalog.current_setting(
    'app.anamnese_snapshot_backfill',
    true
  ) = 'on' then
    null;
  elsif tg_op = 'UPDATE'
    and new.ref_id is not distinct from old.ref_id
    and new.org_id is not distinct from old.org_id
  then
    new.requires_anamnese := old.requires_anamnese;
    new.anamnese_template_id := old.anamnese_template_id;
  elsif new.ref_id is not null then
    select *
      into v_service
    from public.services s
    where s.id = new.ref_id
      and s.org_id = new.org_id;

    if not found then
      raise exception 'Servico nao pertence a esta organizacao'
        using errcode = '23503';
    end if;

    new.requires_anamnese := v_service.requires_anamnese;
    new.anamnese_template_id := v_service.anamnese_template_id;
  else
    new.requires_anamnese := false;
    new.anamnese_template_id := null;
  end if;

  if new.professional_id is not null
    and (
      tg_op = 'INSERT'
      or new.professional_id is distinct from old.professional_id
      or new.org_id is distinct from old.org_id
    )
    and not exists (
    select 1
    from public.staff_members sm
    where sm.id = new.professional_id
      and sm.org_id = new.org_id
      and sm.active = true
  ) then
    raise exception 'Profissional do servico invalido'
      using errcode = '23503';
  end if;

  if new.price < 0 or new.qty <= 0 then
    raise exception 'Valores do item de agendamento invalidos'
      using errcode = '22003';
  end if;

  return new;
end;
$$;

select pg_catalog.set_config('app.anamnese_snapshot_backfill', 'on', true);

update public.appointment_items ai
set
  requires_anamnese = s.requires_anamnese,
  anamnese_template_id = s.anamnese_template_id
from public.services s
where s.id = ai.ref_id
  and s.org_id = ai.org_id;

select pg_catalog.set_config('app.anamnese_snapshot_backfill', 'off', true);

create or replace function public.ensure_appointment_anamnese_for_item()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_appointment public.appointments;
  v_template public.anamnese_templates;
  v_anamnese_id uuid;
begin
  if not new.requires_anamnese or new.anamnese_template_id is null then
    return new;
  end if;

  select *
    into v_appointment
  from public.appointments a
  where a.id = new.appointment_id
    and a.org_id = new.org_id;

  select *
    into v_template
  from public.anamnese_templates t
  where t.id = new.anamnese_template_id
    and t.org_id = new.org_id;

  if not found then
    raise exception 'Modelo de anamnese nao pertence a esta organizacao'
      using errcode = '23503';
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
    new.org_id,
    v_template.id,
    v_template.title,
    pg_catalog.jsonb_build_object(
      'questions', v_template.questions,
      'consent_text', v_template.consent_text,
      'professional_form', v_template.professional_form
    ),
    v_appointment.client_id,
    v_appointment.client_name,
    v_appointment.id,
    'pending',
    v_template.professional_form is not null,
    new.ref_id,
    pg_catalog.encode(extensions.gen_random_bytes(16), 'hex'),
    pg_catalog.now() + interval '7 days',
    v_template.consent_text,
    v_template.consent_version
  )
  on conflict (org_id, appointment_id, template_id)
    where appointment_id is not null and template_id is not null
  do nothing
  returning id into v_anamnese_id;

  if v_anamnese_id is null then
    select an.id
      into v_anamnese_id
    from public.anamneses an
    where an.org_id = new.org_id
      and an.appointment_id = new.appointment_id
      and an.template_id = new.anamnese_template_id;
  else
    insert into public.audit_logs (
      org_id, user_id, table_name, operation, record_id, new_data
    )
    values (
      new.org_id,
      auth.uid(),
      'anamneses',
      'ANAMNESE_AUTO_LINKED',
      v_anamnese_id,
      pg_catalog.jsonb_build_object(
        'appointment_id', new.appointment_id,
        'template_id', new.anamnese_template_id,
        'service_id', new.ref_id
      )
    );
  end if;

  update public.appointments
  set linked_anamnese_id = coalesce(linked_anamnese_id, v_anamnese_id)
  where id = new.appointment_id
    and org_id = new.org_id;

  return new;
end;
$$;

drop trigger if exists trg_ensure_appointment_anamnese_for_item
  on public.appointment_items;
create trigger trg_ensure_appointment_anamnese_for_item
after insert or update on public.appointment_items
for each row
execute function public.ensure_appointment_anamnese_for_item();

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
select distinct on (ai.org_id, ai.appointment_id, ai.anamnese_template_id)
  ai.org_id,
  t.id,
  t.title,
  pg_catalog.jsonb_build_object(
    'questions', t.questions,
    'consent_text', t.consent_text,
    'professional_form', t.professional_form
  ),
  a.client_id,
  a.client_name,
  a.id,
  'pending',
  t.professional_form is not null,
  ai.ref_id,
  pg_catalog.encode(extensions.gen_random_bytes(16), 'hex'),
  pg_catalog.now() + interval '7 days',
  t.consent_text,
  t.consent_version
from public.appointment_items ai
join public.appointments a
  on a.id = ai.appointment_id
  and a.org_id = ai.org_id
join public.anamnese_templates t
  on t.id = ai.anamnese_template_id
  and t.org_id = ai.org_id
where ai.requires_anamnese = true
  and ai.anamnese_template_id is not null
on conflict (org_id, appointment_id, template_id)
  where appointment_id is not null and template_id is not null
do nothing;

update public.appointments a
set linked_anamnese_id = (
  select an.id
  from public.anamneses an
  where an.org_id = a.org_id
    and an.appointment_id = a.id
  order by an.created_at, an.id
  limit 1
)
where a.linked_anamnese_id is null
  and exists (
    select 1
    from public.anamneses an
    where an.org_id = a.org_id
      and an.appointment_id = a.id
  );

revoke all on function public.enforce_anamnese_relation_integrity()
  from public, anon, authenticated;
revoke all on function public.enforce_appointment_item_integrity()
  from public, anon, authenticated;
revoke all on function public.ensure_appointment_anamnese_for_item()
  from public, anon, authenticated;
