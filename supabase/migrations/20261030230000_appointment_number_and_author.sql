-- Número do agendamento (sequencial por estúdio) e quem criou.
-- Encoding: UTF-8
set client_encoding = 'UTF8';
--
-- A tela mostrava "#" + 4 letras do id e "Criado em <data>". Agora:
--   * appointments.number: 1, 2, 3... por estúdio, atribuído no INSERT por um contador com trava
--     (duas criações ao mesmo tempo não repetem número; transação desfeita não deixa buraco);
--     agendamentos antigos recebem número pela ordem de criação; único por (org_id, number).
--   * appointments.created_by: quem criou (auth.uid() no INSERT; antigos pela primeira linha
--     do histórico de status). O autor de cada mudança de status já existe em
--     appointment_status_history.changed_by.
-- Aditiva e compatível com o app antigo: ele insere sem número e sem autor e o gatilho preenche.

alter table public.appointments add column if not exists number integer;
alter table public.appointments add column if not exists created_by uuid references auth.users (id) on delete set null;

-- Contador por estúdio (sem política: só o gatilho, que roda como dono, mexe nele).
create table if not exists public.appointment_counters (
  org_id uuid primary key references public.organizations (id) on delete cascade,
  last_number integer not null default 0
);
alter table public.appointment_counters enable row level security;
revoke all on public.appointment_counters from anon, authenticated;

-- Retroativo: número pela ordem de criação; autor pela primeira linha do histórico.
update public.appointments a
set number = r.rn
from (
  select id, row_number() over (partition by org_id order by created_at, id) as rn
  from public.appointments
) r
where a.id = r.id and a.number is null;

update public.appointments a
set created_by = h.changed_by
from (
  select distinct on (appointment_id) appointment_id, changed_by
  from public.appointment_status_history
  where changed_by is not null
  order by appointment_id, created_at, id
) h
where h.appointment_id = a.id and a.created_by is null;

insert into public.appointment_counters (org_id, last_number)
select org_id, max(number) from public.appointments group by org_id
on conflict (org_id) do update set last_number = greatest(public.appointment_counters.last_number, excluded.last_number);

-- Gatilho: o número vem sempre do contador (valor enviado pelo cliente é ignorado).
create or replace function public.assign_appointment_number()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_number integer;
begin
  insert into public.appointment_counters as c (org_id, last_number)
  values (new.org_id, 1)
  on conflict (org_id) do update set last_number = c.last_number + 1
  returning c.last_number into v_number;
  new.number := v_number;
  if new.created_by is null then
    new.created_by := (select auth.uid());
  end if;
  return new;
end;
$$;

revoke all on function public.assign_appointment_number() from public, anon, authenticated;

drop trigger if exists trg_assign_appointment_number on public.appointments;
create trigger trg_assign_appointment_number
  before insert on public.appointments
  for each row execute function public.assign_appointment_number();

-- Depois de gravados, o número e o autor não mudam (nem pela API, nem por quem pode editar o agendamento).
-- O autor só zera quando a conta é apagada (on delete set null).
create or replace function public.protect_appointment_number()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.number is distinct from old.number then
    raise exception 'O numero do agendamento nao pode ser alterado' using errcode = '42501';
  end if;
  if old.created_by is not null and new.created_by is not null and new.created_by is distinct from old.created_by then
    raise exception 'O autor do agendamento nao pode ser alterado' using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke all on function public.protect_appointment_number() from public, anon, authenticated;

drop trigger if exists trg_protect_appointment_number on public.appointments;
create trigger trg_protect_appointment_number
  before update of number, created_by on public.appointments
  for each row execute function public.protect_appointment_number();

alter table public.appointments alter column number set not null;
alter table public.appointments drop constraint if exists appointments_org_number_key;
alter table public.appointments add constraint appointments_org_number_key unique (org_id, number);
create index if not exists idx_appointments_created_by on public.appointments (created_by) where created_by is not null;

comment on column public.appointments.number is 'Número sequencial do agendamento dentro do estúdio.';
comment on column public.appointments.created_by is 'Quem criou o agendamento (usuário). Mudanças de status: appointment_status_history.changed_by.';
