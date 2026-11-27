-- Lista de espera da Agenda.
-- Encoding: UTF-8
set client_encoding = 'UTF8';
--
-- Cliente que quer um horário que ainda não existe: fica na lista com o serviço, a profissional
-- (opcional) e as janelas em que topa ser chamada. Quando um horário abre, a recepção oferece
-- (status "offered", com o horário oferecido) e, se a cliente aceitar, agenda e a entrada vira
-- "scheduled" ligada ao agendamento. "removed" tira da fila sem apagar o histórico.
-- Só quem tem agenda.manage lê e escreve. Tabela nova: o app antigo não a conhece.

create table if not exists public.agenda_waitlist (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  client_id uuid not null,
  service_id uuid,
  staff_id uuid,
  -- Janelas desejadas: [{"date":"2026-11-03","from":"09:00","to":"12:00"}, {"weekday":2,"from":"14:00","to":"18:00"}]
  windows jsonb not null default '[]'::jsonb,
  notes text,
  status text not null default 'waiting',
  offered_at timestamptz,
  offered_for timestamptz,
  appointment_id uuid,
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint agenda_waitlist_status_check check (status in ('waiting', 'offered', 'scheduled', 'removed')),
  constraint agenda_waitlist_windows_check check (jsonb_typeof(windows) = 'array' and jsonb_array_length(windows) <= 20),
  constraint agenda_waitlist_notes_length check (notes is null or char_length(notes) <= 500),
  constraint agenda_waitlist_scheduled_check check (status <> 'scheduled' or appointment_id is not null),
  constraint agenda_waitlist_client_same_org foreign key (org_id, client_id) references public.clients (org_id, id) on delete cascade,
  constraint agenda_waitlist_service_same_org foreign key (service_id, org_id) references public.services (id, org_id) on delete cascade,
  constraint agenda_waitlist_staff_same_org foreign key (staff_id, org_id) references public.staff_members (id, org_id) on delete cascade,
  constraint agenda_waitlist_appointment_same_org foreign key (appointment_id, org_id) references public.appointments (id, org_id) on delete cascade
);

create index if not exists agenda_waitlist_org_status_idx on public.agenda_waitlist (org_id, status, created_at);
create index if not exists agenda_waitlist_client_org_idx on public.agenda_waitlist (org_id, client_id);
create index if not exists agenda_waitlist_service_org_idx on public.agenda_waitlist (service_id, org_id) where service_id is not null;
create index if not exists agenda_waitlist_staff_org_idx on public.agenda_waitlist (staff_id, org_id) where staff_id is not null;
create index if not exists agenda_waitlist_appointment_org_idx on public.agenda_waitlist (appointment_id, org_id) where appointment_id is not null;

drop trigger if exists agenda_waitlist_updated_at on public.agenda_waitlist;
create trigger agenda_waitlist_updated_at
  before update on public.agenda_waitlist
  for each row execute function public.update_updated_at();

alter table public.agenda_waitlist enable row level security;

drop policy if exists "agenda_waitlist_select" on public.agenda_waitlist;
create policy "agenda_waitlist_select" on public.agenda_waitlist for select to authenticated
  using (public.has_permission(org_id, 'agenda.manage'));

drop policy if exists "agenda_waitlist_insert" on public.agenda_waitlist;
create policy "agenda_waitlist_insert" on public.agenda_waitlist for insert to authenticated
  with check (public.has_permission(org_id, 'agenda.manage'));

drop policy if exists "agenda_waitlist_update" on public.agenda_waitlist;
create policy "agenda_waitlist_update" on public.agenda_waitlist for update to authenticated
  using (public.has_permission(org_id, 'agenda.manage'))
  with check (public.has_permission(org_id, 'agenda.manage'));

drop policy if exists "agenda_waitlist_delete" on public.agenda_waitlist;
create policy "agenda_waitlist_delete" on public.agenda_waitlist for delete to authenticated
  using (public.has_permission(org_id, 'agenda.manage'));

revoke all on public.agenda_waitlist from anon;
grant select, insert, update, delete on public.agenda_waitlist to authenticated;

comment on table public.agenda_waitlist is 'Fila de espera da Agenda: cliente, serviço, profissional opcional e janelas desejadas.';
