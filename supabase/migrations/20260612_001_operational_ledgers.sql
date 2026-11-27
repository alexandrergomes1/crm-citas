-- ============================================================
-- KA Beauty OS - Operational ledgers and atomic status history
-- Encoding: UTF-8
-- ============================================================

create table if not exists public.audit_logs (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references public.organizations(id) on delete cascade,
  user_id     uuid references auth.users(id) on delete set null,
  table_name  text not null,
  operation   text not null,
  record_id   uuid,
  old_data    jsonb,
  new_data    jsonb,
  ip_address  inet,
  user_agent  text,
  created_at  timestamptz not null default now()
);

create table if not exists public.client_balance_entries (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references public.organizations(id) on delete cascade,
  client_id      uuid not null references public.clients(id) on delete cascade,
  entry_type     text not null,
  amount         numeric(12,2) not null check (amount <> 0),
  balance_before numeric(12,2) not null,
  balance_after  numeric(12,2) not null,
  source_type    text not null,
  source_id      uuid,
  description    text,
  created_by     uuid references auth.users(id) on delete set null,
  created_at     timestamptz not null default now()
);

create table if not exists public.loyalty_point_entries (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references public.organizations(id) on delete cascade,
  client_id      uuid not null references public.clients(id) on delete cascade,
  entry_type     text not null,
  points         integer not null check (points <> 0),
  balance_before integer not null,
  balance_after  integer not null,
  source_type    text not null,
  source_id      uuid,
  description    text,
  created_by     uuid references auth.users(id) on delete set null,
  created_at     timestamptz not null default now()
);

create table if not exists public.gift_card_redemptions (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references public.organizations(id) on delete cascade,
  gift_card_id   uuid not null references public.gift_cards(id) on delete restrict,
  sale_id        uuid references public.sales(id) on delete set null,
  appointment_id uuid references public.appointments(id) on delete set null,
  client_id      uuid references public.clients(id) on delete set null,
  amount         numeric(12,2) not null check (amount > 0),
  balance_before numeric(12,2) not null,
  balance_after  numeric(12,2) not null,
  redeemed_by    uuid references auth.users(id) on delete set null,
  created_at     timestamptz not null default now()
);

create index if not exists idx_audit_logs_org_created
  on public.audit_logs (org_id, created_at desc);
create index if not exists idx_client_balance_entries_client_created
  on public.client_balance_entries (org_id, client_id, created_at desc);
create index if not exists idx_loyalty_point_entries_client_created
  on public.loyalty_point_entries (org_id, client_id, created_at desc);
create index if not exists idx_gift_card_redemptions_card_created
  on public.gift_card_redemptions (org_id, gift_card_id, created_at desc);
create index if not exists idx_gift_card_redemptions_sale
  on public.gift_card_redemptions (sale_id);

alter table public.audit_logs enable row level security;
alter table public.client_balance_entries enable row level security;
alter table public.loyalty_point_entries enable row level security;
alter table public.gift_card_redemptions enable row level security;

drop policy if exists "audit_select_manager" on public.audit_logs;
drop policy if exists "audit_insert_member" on public.audit_logs;
create policy "audit_select_manager"
  on public.audit_logs for select
  using (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in ('owner', 'admin', 'manager')
  );
create policy "audit_insert_member"
  on public.audit_logs for insert
  with check (org_id in (select public.auth_org_ids()));

drop policy if exists "client_balance_entries_select" on public.client_balance_entries;
drop policy if exists "client_balance_entries_insert" on public.client_balance_entries;
create policy "client_balance_entries_select"
  on public.client_balance_entries for select
  using (org_id in (select public.auth_org_ids()));
create policy "client_balance_entries_insert"
  on public.client_balance_entries for insert
  with check (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in (
      'owner', 'admin', 'manager', 'finance', 'receptionist'
    )
  );

drop policy if exists "loyalty_point_entries_select" on public.loyalty_point_entries;
drop policy if exists "loyalty_point_entries_insert" on public.loyalty_point_entries;
create policy "loyalty_point_entries_select"
  on public.loyalty_point_entries for select
  using (org_id in (select public.auth_org_ids()));
create policy "loyalty_point_entries_insert"
  on public.loyalty_point_entries for insert
  with check (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in (
      'owner', 'admin', 'manager', 'finance', 'receptionist'
    )
  );

drop policy if exists "gift_card_redemptions_select" on public.gift_card_redemptions;
drop policy if exists "gift_card_redemptions_insert" on public.gift_card_redemptions;
create policy "gift_card_redemptions_select"
  on public.gift_card_redemptions for select
  using (org_id in (select public.auth_org_ids()));
create policy "gift_card_redemptions_insert"
  on public.gift_card_redemptions for insert
  with check (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in (
      'owner', 'admin', 'manager', 'finance', 'receptionist'
    )
  );

grant select, insert on public.audit_logs to authenticated;
grant select, insert on public.client_balance_entries to authenticated;
grant select, insert on public.loyalty_point_entries to authenticated;
grant select, insert on public.gift_card_redemptions to authenticated;

create or replace function public.set_appointment_status_atomic(
  p_org_id uuid,
  p_appointment_id uuid,
  p_status text
)
returns public.appointments
language plpgsql
security invoker
set search_path = ''
as $$
declare
  updated_appointment public.appointments;
begin
  update public.appointments
  set status = p_status
  where id = p_appointment_id
    and org_id = p_org_id
  returning * into updated_appointment;

  if not found then
    raise exception 'Agendamento nao encontrado'
      using errcode = 'P0002';
  end if;

  insert into public.appointment_status_history (
    org_id,
    appointment_id,
    status,
    changed_by,
    notes
  )
  values (
    p_org_id,
    p_appointment_id,
    p_status,
    auth.uid(),
    null
  );

  return updated_appointment;
end;
$$;

grant execute on function public.set_appointment_status_atomic(uuid, uuid, text)
  to authenticated;
