-- ============================================================
-- KA Beauty OS - Agenda timezone and conflict-query indexes
-- Encoding: UTF-8
-- ============================================================

alter table public.organizations
  alter column timezone set default 'Europe/Madrid';

alter table public.locations
  alter column timezone set default 'Europe/Madrid';

update public.organizations
set timezone = 'Europe/Madrid'
where slug = 'ka-beauty'
  and timezone <> 'Europe/Madrid';

update public.locations l
set timezone = 'Europe/Madrid'
where l.org_id in (
  select o.id
  from public.organizations o
  where o.slug = 'ka-beauty'
)
  and l.timezone <> 'Europe/Madrid';

create index if not exists idx_appointments_org_staff_active_period
  on public.appointments (org_id, staff_id, start_at, end_at)
  where staff_id is not null
    and status not in ('Cancelado', 'Ausência');

create index if not exists idx_time_blocks_org_staff_period
  on public.time_blocks (org_id, staff_id, start_at, end_at);
