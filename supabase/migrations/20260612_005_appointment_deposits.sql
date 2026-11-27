-- ============================================================
-- KA Beauty OS - Appointment deposits
-- Encoding: UTF-8
-- ============================================================

create table if not exists public.appointment_deposits (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references public.organizations(id) on delete cascade,
  appointment_id  uuid not null references public.appointments(id) on delete restrict,
  client_id       uuid not null references public.clients(id) on delete restrict,
  transaction_id  uuid not null references public.transactions(id) on delete restrict,
  sale_id         uuid references public.sales(id) on delete set null,
  amount          numeric(12,2) not null check (amount > 0),
  method          text not null check (
    method in ('CASH', 'CARD_DEBIT', 'CARD_CREDIT', 'TRANSFER', 'BIZUM')
  ),
  status          text not null default 'confirmed' check (
    status in ('confirmed', 'applied', 'refunded', 'cancelled')
  ),
  idempotency_key uuid not null,
  created_by      uuid references auth.users(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (org_id, idempotency_key)
);

create index if not exists idx_appointment_deposits_appointment
  on public.appointment_deposits (org_id, appointment_id, status, created_at);
create index if not exists idx_appointment_deposits_client
  on public.appointment_deposits (org_id, client_id, created_at desc);

drop trigger if exists appointment_deposits_updated_at on public.appointment_deposits;
create trigger appointment_deposits_updated_at
  before update on public.appointment_deposits
  for each row execute function public.update_updated_at();

alter table public.appointment_deposits enable row level security;

drop policy if exists "appointment_deposits_select" on public.appointment_deposits;
drop policy if exists "appointment_deposits_update" on public.appointment_deposits;
create policy "appointment_deposits_select"
  on public.appointment_deposits for select
  using (org_id in (select public.auth_org_ids()));
create policy "appointment_deposits_update"
  on public.appointment_deposits for update
  using (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in (
      'owner', 'admin', 'manager', 'receptionist', 'finance'
    )
  )
  with check (org_id in (select public.auth_org_ids()));

grant select, update on public.appointment_deposits to authenticated;

create or replace function public.register_appointment_deposit_atomic(
  p_org_id uuid,
  p_appointment_id uuid,
  p_amount numeric,
  p_method text,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text;
  v_appointment public.appointments;
  v_existing public.appointment_deposits;
  v_deposit public.appointment_deposits;
  v_transaction_id uuid;
  v_note text;
  v_appointment_total numeric(12,2);
  v_existing_total numeric(12,2);
begin
  if auth.uid() is null then
    raise exception 'Autenticacao obrigatoria' using errcode = '42501';
  end if;

  select ur.role::text
    into v_role
  from public.user_roles ur
  where ur.org_id = p_org_id
    and ur.user_id = auth.uid()
    and ur.active = true
  limit 1;

  if v_role is null or v_role not in (
    'owner', 'admin', 'manager', 'receptionist', 'finance'
  ) then
    raise exception 'Sem permissao para registrar sinal' using errcode = '42501';
  end if;

  if p_amount is null or p_amount <= 0 or p_amount > 1000000 then
    raise exception 'Valor do sinal invalido' using errcode = '22003';
  end if;

  if p_method not in ('CASH', 'CARD_DEBIT', 'CARD_CREDIT', 'TRANSFER', 'BIZUM') then
    raise exception 'Metodo de pagamento invalido' using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_org_id::text || ':' || p_idempotency_key::text, 0)
  );

  select *
    into v_existing
  from public.appointment_deposits
  where org_id = p_org_id
    and idempotency_key = p_idempotency_key;

  if found then
    return pg_catalog.jsonb_build_object(
      'deposit_id', v_existing.id,
      'amount', v_existing.amount,
      'duplicate', true
    );
  end if;

  select *
    into v_appointment
  from public.appointments
  where id = p_appointment_id
    and org_id = p_org_id
  for update;

  if not found then
    raise exception 'Agendamento nao encontrado' using errcode = 'P0002';
  end if;

  if v_appointment.client_id is null then
    raise exception 'Agendamento sem cliente cadastrado' using errcode = '23502';
  end if;

  if v_appointment.status not in ('Reservado', 'Agendado', 'Confirmado') then
    raise exception 'O sinal so pode ser registrado antes do inicio do atendimento'
      using errcode = 'P0001';
  end if;

  select coalesce(sum(ai.price * ai.qty), 0)
    into v_appointment_total
  from public.appointment_items ai
  where ai.org_id = p_org_id
    and ai.appointment_id = p_appointment_id;

  if v_appointment_total <= 0 then
    v_appointment_total := coalesce(v_appointment.total, 0);
  end if;

  select coalesce(sum(ad.amount), 0)
    into v_existing_total
  from public.appointment_deposits ad
  where ad.org_id = p_org_id
    and ad.appointment_id = p_appointment_id
    and ad.status in ('confirmed', 'applied');

  if v_appointment_total > 0
    and v_existing_total + round(p_amount, 2) > v_appointment_total then
    raise exception 'Sinal excede o valor atual do atendimento' using errcode = '22003';
  end if;

  insert into public.transactions (
    org_id,
    client_id,
    client_name,
    type,
    category,
    description,
    value,
    method,
    date,
    status,
    created_by
  )
  values (
    p_org_id,
    v_appointment.client_id,
    v_appointment.client_name,
    'income',
    'sinal',
    'Sinal - ' || v_appointment.client_name,
    round(p_amount, 2),
    p_method,
    (pg_catalog.now() at time zone 'UTC')::date,
    'completed',
    auth.uid()
  )
  returning id into v_transaction_id;

  insert into public.appointment_deposits (
    org_id,
    appointment_id,
    client_id,
    transaction_id,
    amount,
    method,
    idempotency_key,
    created_by
  )
  values (
    p_org_id,
    p_appointment_id,
    v_appointment.client_id,
    v_transaction_id,
    round(p_amount, 2),
    p_method,
    p_idempotency_key,
    auth.uid()
  )
  returning * into v_deposit;

  v_note := pg_catalog.format(
    'Sinal de EUR %s registado em %s (%s)',
    round(p_amount, 2),
    pg_catalog.to_char(pg_catalog.now(), 'YYYY-MM-DD HH24:MI'),
    p_method
  );

  update public.appointments
  set internal_notes = case
    when internal_notes is null or pg_catalog.btrim(internal_notes) = '' then v_note
    else internal_notes || E'\n' || v_note
  end
  where id = p_appointment_id
    and org_id = p_org_id;

  insert into public.audit_logs (
    org_id,
    user_id,
    table_name,
    operation,
    record_id,
    new_data
  )
  values (
    p_org_id,
    auth.uid(),
    'appointment_deposits',
    'deposit_registered',
    v_deposit.id,
    pg_catalog.jsonb_build_object(
      'appointment_id', p_appointment_id,
      'client_id', v_appointment.client_id,
      'amount', v_deposit.amount,
      'method', v_deposit.method,
      'transaction_id', v_transaction_id
    )
  );

  return pg_catalog.jsonb_build_object(
    'deposit_id', v_deposit.id,
    'amount', v_deposit.amount,
    'duplicate', false
  );
end;
$$;

revoke all on function public.register_appointment_deposit_atomic(
  uuid, uuid, numeric, text, uuid
) from public;
grant execute on function public.register_appointment_deposit_atomic(
  uuid, uuid, numeric, text, uuid
) to authenticated;
