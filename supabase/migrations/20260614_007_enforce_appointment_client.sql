-- ============================================================
-- KA Beauty OS - Every appointment must reference a client
-- Encoding: UTF-8
-- ============================================================

with orphan_names as (
  select distinct
    a.org_id,
    pg_catalog.btrim(a.client_name) as full_name
  from public.appointments a
  where a.client_id is null
    and nullif(pg_catalog.btrim(a.client_name), '') is not null
)
insert into public.clients (org_id, full_name, source)
select orphan.org_id, orphan.full_name, 'appointment_backfill'
from orphan_names orphan
where not exists (
  select 1
  from public.clients c
  where c.org_id = orphan.org_id
    and pg_catalog.lower(pg_catalog.btrim(c.full_name))
      = pg_catalog.lower(orphan.full_name)
);

update public.appointments a
set client_id = (
  select c.id as client_id
  from public.clients c
  where c.org_id = a.org_id
    and pg_catalog.lower(pg_catalog.btrim(c.full_name))
      = pg_catalog.lower(pg_catalog.btrim(a.client_name))
  order by c.created_at, c.id
  limit 1
)
where a.client_id is null;

update public.sales s
set
  client_id = a.client_id,
  client_name = a.client_name
from public.appointments a
where s.org_id = a.org_id
  and s.appointment_id = a.id
  and s.client_id is null
  and a.client_id is not null;

update public.transactions t
set
  client_id = s.client_id,
  client_name = s.client_name
from public.sales s
where t.org_id = s.org_id
  and t.sale_id = s.id
  and t.client_id is null
  and s.client_id is not null;

do $$
begin
  if exists (
    select 1
    from public.appointments
    where client_id is null
  ) then
    raise exception 'Existem agendamentos sem nome de cliente para migrar';
  end if;
end;
$$;

alter table public.appointments
  alter column client_id set not null;

create index if not exists idx_appointments_org_client_start
  on public.appointments (org_id, client_id, start_at desc);
