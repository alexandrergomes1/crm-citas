-- UTF-8. AGENDA-CORE-02: status operational contract and historical notes timeline.

create table if not exists public.client_notes (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  client_id uuid not null,
  appointment_id uuid,
  author_id uuid,
  author_name text not null default 'Utilizador',
  content text not null,
  note_type text not null default 'client',
  note_date date not null default current_date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

alter table public.client_notes add column if not exists appointment_id uuid;
alter table public.client_notes add column if not exists author_name text not null default 'Utilizador';
alter table public.client_notes add column if not exists note_date date not null default current_date;
alter table public.client_notes add column if not exists updated_at timestamptz not null default now();
alter table public.client_notes add column if not exists deleted_at timestamptz;
alter table public.client_notes alter column note_type set default 'client';

alter table public.client_notes drop constraint if exists client_notes_note_type_check;
alter table public.client_notes drop constraint if exists client_notes_content_check;
alter table public.client_notes add constraint client_notes_note_type_check
  check (note_type in ('client', 'appointment', 'fixed', 'general', 'pre', 'post', 'alert'));
alter table public.client_notes add constraint client_notes_content_check
  check (length(btrim(content)) between 1 and 5000);
alter table public.client_notes add constraint client_notes_appointment_type_check
  check (note_type <> 'appointment' or appointment_id is not null);

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'clients_org_id_id_key') then
    alter table public.clients add constraint clients_org_id_id_key unique (org_id, id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'appointments_org_client_id_id_key') then
    alter table public.appointments add constraint appointments_org_client_id_id_key unique (org_id, client_id, id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'client_notes_org_client_fk') then
    alter table public.client_notes add constraint client_notes_org_client_fk
      foreign key (org_id, client_id) references public.clients(org_id, id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'client_notes_org_client_appointment_fk') then
    alter table public.client_notes add constraint client_notes_org_client_appointment_fk
      foreign key (org_id, client_id, appointment_id)
      references public.appointments(org_id, client_id, id) on delete restrict;
  end if;
end $$;

create index if not exists client_notes_org_client_timeline_idx
  on public.client_notes (org_id, client_id, note_date desc, created_at desc)
  where deleted_at is null;
create index if not exists client_notes_org_appointment_idx
  on public.client_notes (org_id, appointment_id, note_date desc)
  where appointment_id is not null and deleted_at is null;

alter table public.client_notes enable row level security;
drop policy if exists client_notes_select on public.client_notes;
drop policy if exists client_notes_write on public.client_notes;
drop policy if exists client_notes_insert on public.client_notes;

create policy client_notes_select on public.client_notes
for select to authenticated
using (
  exists (
    select 1 from public.user_roles ur
    where ur.org_id = client_notes.org_id
      and ur.user_id = (select auth.uid())
      and ur.active
      and ur.role::text in ('owner', 'admin', 'manager', 'receptionist', 'professional')
  )
);

create policy client_notes_insert on public.client_notes
for insert to authenticated
with check (
  exists (
    select 1 from public.user_roles ur
    where ur.org_id = client_notes.org_id
      and ur.user_id = (select auth.uid())
      and ur.active
      and ur.role::text in ('owner', 'admin', 'manager', 'receptionist', 'professional')
  )
  and exists (
    select 1 from public.profiles p
    where p.id = client_notes.author_id
      and p.org_id = client_notes.org_id
      and p.user_id = (select auth.uid())
  )
);

revoke all on table public.client_notes from anon;
revoke all on table public.client_notes from authenticated;
grant select on table public.client_notes to authenticated;

create or replace function public.create_client_note_atomic(
  p_org_id uuid,
  p_client_id uuid,
  p_appointment_id uuid,
  p_note_type text,
  p_body text,
  p_note_date date default current_date
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_note_id uuid;
  v_author_id uuid;
  v_author_name text;
begin
  if not exists (
    select 1 from public.user_roles ur
    where ur.org_id = p_org_id
      and ur.user_id = auth.uid()
      and ur.active
      and ur.role::text in ('owner', 'admin', 'manager', 'receptionist', 'professional')
  ) then
    raise exception 'Sem permissão para criar notas';
  end if;

  if p_note_type not in ('client', 'appointment', 'fixed') then
    raise exception 'Tipo de nota inválido';
  end if;
  if length(btrim(coalesce(p_body, ''))) not between 1 and 5000 then
    raise exception 'A nota deve ter entre 1 e 5000 caracteres';
  end if;
  if not exists (select 1 from public.clients c where c.org_id = p_org_id and c.id = p_client_id) then
    raise exception 'Cliente não pertence à organização';
  end if;
  if p_note_type = 'appointment' and p_appointment_id is null then
    raise exception 'Atendimento obrigatório para nota de atendimento';
  end if;
  if p_appointment_id is not null and not exists (
    select 1 from public.appointments a
    where a.org_id = p_org_id and a.client_id = p_client_id and a.id = p_appointment_id
  ) then
    raise exception 'Atendimento não pertence ao cliente ou à organização';
  end if;

  select p.id, p.full_name into v_author_id, v_author_name
  from public.profiles p
  where p.org_id = p_org_id and p.user_id = auth.uid()
  order by p.created_at
  limit 1;

  if v_author_id is null then
    raise exception 'Perfil do autor não encontrado na organização';
  end if;

  insert into public.client_notes (
    org_id, client_id, appointment_id, author_id, author_name, content, note_type, note_date
  ) values (
    p_org_id, p_client_id, p_appointment_id, v_author_id,
    coalesce(nullif(btrim(v_author_name), ''), 'Utilizador'), btrim(p_body), p_note_type,
    coalesce(p_note_date, current_date)
  ) returning id into v_note_id;

  insert into public.audit_logs (
    org_id, user_id, table_name, operation, record_id, new_data
  ) values (
    p_org_id, auth.uid(), 'client_notes', 'CLIENT_NOTE_CREATED', v_note_id,
    pg_catalog.jsonb_build_object(
      'client_id', p_client_id,
      'appointment_id', p_appointment_id,
      'note_type', p_note_type,
      'note_date', coalesce(p_note_date, current_date)
    )
  );

  return v_note_id;
end;
$$;

revoke all on function public.create_client_note_atomic(uuid, uuid, uuid, text, text, date) from public;
revoke all on function public.create_client_note_atomic(uuid, uuid, uuid, text, text, date) from anon;
grant execute on function public.create_client_note_atomic(uuid, uuid, uuid, text, text, date) to authenticated;

create or replace function public.agenda_status_transition_allowed(p_current text, p_next text)
returns boolean
language sql
immutable
set search_path = public, pg_temp
as $$
  select p_current = p_next or case p_current
    when 'Reservado' then p_next in ('Confirmado', 'Ausência', 'Cancelado')
    when 'Agendado' then p_next in ('Confirmado', 'Iniciado', 'Ausência', 'Cancelado')
    when 'Confirmado' then p_next in ('Iniciado', 'Ausência', 'Cancelado')
    when 'Iniciado' then p_next in ('Concluído', 'Cancelado')
    when 'Concluído' then p_next in ('Pago Parcial', 'Pago')
    when 'Pago Parcial' then p_next = 'Pago'
    else false
  end;
$$;

