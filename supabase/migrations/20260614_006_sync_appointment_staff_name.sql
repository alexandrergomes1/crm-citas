-- ============================================================
-- KA Beauty OS - Keep appointment staff snapshot consistent
-- Encoding: UTF-8
-- ============================================================

create or replace function public.sync_appointment_staff_name()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.staff_id is null then
    new.staff_name := '';
    return new;
  end if;

  select coalesce(sm.display_name, sm.name)
    into new.staff_name
  from public.staff_members sm
  where sm.id = new.staff_id
    and sm.org_id = new.org_id;

  if not found then
    raise exception 'Profissional nao pertence a esta organizacao'
      using errcode = '23503';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_appointments_sync_staff_name
  on public.appointments;

create trigger trg_appointments_sync_staff_name
before insert or update of staff_id
on public.appointments
for each row
execute function public.sync_appointment_staff_name();

update public.appointments a
set staff_name = coalesce(sm.display_name, sm.name)
from public.staff_members sm
where a.staff_id = sm.id
  and a.org_id = sm.org_id
  and a.staff_name is distinct from coalesce(sm.display_name, sm.name);

revoke all on function public.sync_appointment_staff_name()
  from public, anon, authenticated;
