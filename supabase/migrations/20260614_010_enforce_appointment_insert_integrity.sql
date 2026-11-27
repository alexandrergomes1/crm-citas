-- Enforce tenant-safe appointment writes even when callers bypass Server Actions.

create or replace function public.enforce_appointment_insert_integrity()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.status not in ('Reservado', 'Agendado', 'Confirmado') then
    raise exception 'Status inicial de agendamento invalido'
      using errcode = '22023';
  end if;

  if new.end_at <= new.start_at then
    raise exception 'Horario final deve ser posterior ao inicial'
      using errcode = '22023';
  end if;

  if new.duration_minutes < 1 or new.duration_minutes > 1440 then
    raise exception 'Duracao invalida'
      using errcode = '22023';
  end if;

  if new.source not in ('MANUAL', 'WHATSAPP', 'ONLINE', 'PHONE') then
    raise exception 'Origem de agendamento invalida'
      using errcode = '22023';
  end if;

  if new.total < 0 or new.total > 1000000 then
    raise exception 'Total do agendamento invalido'
      using errcode = '22003';
  end if;

  if not exists (
    select 1
    from public.clients c
    where c.id = new.client_id
      and c.org_id = new.org_id
  ) then
    raise exception 'Cliente nao pertence a esta organizacao'
      using errcode = '23503';
  end if;

  if new.staff_id is not null and not exists (
    select 1
    from public.staff_members sm
    where sm.id = new.staff_id
      and sm.org_id = new.org_id
      and sm.active = true
  ) then
    raise exception 'Profissional nao pertence a esta organizacao'
      using errcode = '23503';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_appointment_insert_integrity
  on public.appointments;
create trigger trg_enforce_appointment_insert_integrity
before insert on public.appointments
for each row
execute function public.enforce_appointment_insert_integrity();

create or replace function public.enforce_appointment_item_integrity()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
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

  if new.ref_id is not null and not exists (
    select 1
    from public.services s
    where s.id = new.ref_id
      and s.org_id = new.org_id
  ) then
    raise exception 'Servico nao pertence a esta organizacao'
      using errcode = '23503';
  end if;

  if new.professional_id is not null and not exists (
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

drop trigger if exists trg_enforce_appointment_item_integrity
  on public.appointment_items;
create trigger trg_enforce_appointment_item_integrity
before insert or update on public.appointment_items
for each row
execute function public.enforce_appointment_item_integrity();

revoke all on function public.enforce_appointment_insert_integrity()
  from public, anon, authenticated;
revoke all on function public.enforce_appointment_item_integrity()
  from public, anon, authenticated;
