-- Status "Chegou" ponta a ponta.
-- Encoding: UTF-8
set client_encoding = 'UTF8';
--
-- Fluxo: Agendado/Confirmado -> Chegou -> Iniciado (Em atendimento) -> Concluído -> Pago.
-- Até aqui "Marcar chegada" gravava Iniciado. Agora a chegada tem status próprio, com a mesma
-- trava da Ficha Cliente assinada (a que valia ao iniciar) e entra na trilha de histórico
-- (appointment_status_history, com quem mudou em changed_by).
-- Aditiva e compatível com o app antigo: o app antigo nunca grava "Chegou"; as transições
-- Agendado/Confirmado -> Iniciado continuam permitidas.

-- 1. Valor novo no check do status -----------------------------------------------------------------
alter table public.appointments drop constraint if exists appointments_status_canonical;
alter table public.appointments add constraint appointments_status_canonical
  check (status in ('Reservado', 'Agendado', 'Confirmado', 'Chegou', 'Iniciado', 'Concluído', 'Pago Parcial', 'Pago', 'Ausência', 'Cancelado'));

-- 2. Transições -----------------------------------------------------------------------------------
create or replace function public.agenda_status_transition_allowed(p_current text, p_next text)
returns boolean
language sql
immutable
set search_path = 'public', 'pg_temp'
as $$
  select p_current = p_next or case p_current
    when 'Reservado' then p_next in ('Confirmado', 'Ausência', 'Cancelado')
    when 'Agendado' then p_next in ('Confirmado', 'Chegou', 'Iniciado', 'Ausência', 'Cancelado')
    when 'Confirmado' then p_next in ('Chegou', 'Iniciado', 'Ausência', 'Cancelado')
    when 'Chegou' then p_next in ('Iniciado', 'Cancelado')
    when 'Iniciado' then p_next in ('Concluído', 'Cancelado')
    when 'Concluído' then p_next in ('Pago Parcial', 'Pago')
    when 'Pago Parcial' then p_next = 'Pago'
    else false
  end;
$$;

-- 3. Troca de status: aceita Chegou e aplica a trava da ficha ao chegar e ao iniciar ---------------
create or replace function public.set_appointment_status_atomic(
  p_org_id uuid,
  p_appointment_id uuid,
  p_status text
)
returns public.appointments
language plpgsql
set search_path = ''
as $$
declare
  v_role text;
  v_previous public.appointments;
  v_updated public.appointments;
begin
  v_role := public.auth_user_role(p_org_id);
  if not public.has_permission(p_org_id, 'agenda.manage') then
    raise exception 'Sem permissao para alterar o status'
      using errcode = '42501';
  end if;

  select * into v_previous
  from public.appointments a
  where a.id = p_appointment_id
    and a.org_id = p_org_id
  for update;

  if not found then
    raise exception 'Agendamento nao encontrado' using errcode = 'P0002';
  end if;

  if p_status not in (
    'Reservado', 'Agendado', 'Confirmado', 'Chegou', 'Iniciado', 'Concluído',
    'Pago Parcial', 'Pago', 'Ausência', 'Cancelado'
  ) then
    raise exception 'Status de agendamento invalido' using errcode = '22023';
  end if;

  if not public.agenda_status_transition_allowed(v_previous.status, p_status) then
    raise exception 'Transicao de status nao permitida' using errcode = '22023';
  end if;

  if p_status = v_previous.status then return v_previous; end if;

  if p_status in ('Chegou', 'Iniciado') then
    perform public.assert_appointment_anamnese_gate(
      p_org_id,
      p_appointment_id,
      'start'
    );
  end if;

  update public.appointments
  set status = p_status
  where id = p_appointment_id
    and org_id = p_org_id
  returning * into v_updated;

  insert into public.appointment_status_history (
    org_id, appointment_id, status, changed_by, notes
  ) values (
    p_org_id, p_appointment_id, p_status, auth.uid(), null
  );

  insert into public.audit_logs (
    org_id, user_id, table_name, operation, record_id, old_data, new_data
  ) values (
    p_org_id,
    auth.uid(),
    'appointments',
    'STATUS_CHANGE',
    p_appointment_id,
    pg_catalog.jsonb_build_object('status', v_previous.status),
    pg_catalog.jsonb_build_object('status', v_updated.status)
  );

  return v_updated;
end;
$$;

-- 4. Gatilhos da Ficha Cliente: Chegou conta como começar o atendimento ---------------------------
create or replace function public.enforce_appointment_anamnese_status_gate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is not distinct from old.status then
    return new;
  end if;

  if new.status in ('Chegou', 'Iniciado') then
    perform public.assert_appointment_anamnese_gate(
      new.org_id,
      new.id,
      'start'
    );
  elsif new.status in ('Pago Parcial', 'Pago') then
    perform public.assert_appointment_anamnese_gate(
      new.org_id,
      new.id,
      'checkout'
    );
  end if;

  return new;
end;
$$;

create or replace function public.enforce_appointment_item_anamnese_gate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
begin
  select a.status
    into v_status
  from public.appointments a
  where a.id = new.appointment_id
    and a.org_id = new.org_id;

  if v_status in ('Chegou', 'Iniciado') then
    perform public.assert_appointment_anamnese_gate(
      new.org_id,
      new.appointment_id,
      'start'
    );
  elsif v_status in ('Pago Parcial', 'Pago') then
    perform public.assert_appointment_anamnese_gate(
      new.org_id,
      new.appointment_id,
      'checkout'
    );
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_appointment_item_anamnese_gate() from public, anon, authenticated;

-- 5. Reagendar: quem já chegou ainda pode mudar de horário, como quem já iniciou ------------------
create or replace function public.reschedule_appointment_atomic(
  p_org_id uuid,
  p_appointment_id uuid,
  p_start_at timestamp with time zone
)
returns public.appointments
language plpgsql
set search_path = ''
as $$
declare
  v_role text;
  v_previous public.appointments;
  v_updated public.appointments;
  v_end_at timestamptz;
begin
  v_role := public.auth_user_role(p_org_id);
  if not public.has_permission(p_org_id, 'agenda.manage') then
    raise exception 'Sem permissao para reagendar'
      using errcode = '42501';
  end if;

  select *
    into v_previous
  from public.appointments a
  where a.id = p_appointment_id
    and a.org_id = p_org_id
  for update;

  if not found then
    raise exception 'Agendamento nao encontrado' using errcode = 'P0002';
  end if;

  if v_previous.status not in ('Reservado', 'Agendado', 'Confirmado', 'Chegou', 'Iniciado') then
    raise exception 'Agendamento neste estado nao pode ser reagendado'
      using errcode = 'P0001';
  end if;

  v_end_at := p_start_at
    + pg_catalog.make_interval(mins => v_previous.duration_minutes);

  perform public.agenda_assert_slot_available(
    p_org_id,
    v_previous.staff_id,
    p_start_at,
    v_end_at,
    array[p_appointment_id],
    false
  );

  update public.appointments
  set start_at = p_start_at,
      end_at = v_end_at
  where id = p_appointment_id
    and org_id = p_org_id
  returning * into v_updated;

  insert into public.audit_logs (
    org_id, user_id, table_name, operation, record_id, old_data, new_data
  )
  values (
    p_org_id,
    auth.uid(),
    'appointments',
    'APPOINTMENT_RESCHEDULED',
    p_appointment_id,
    pg_catalog.jsonb_build_object(
      'start_at', v_previous.start_at,
      'end_at', v_previous.end_at
    ),
    pg_catalog.jsonb_build_object(
      'start_at', v_updated.start_at,
      'end_at', v_updated.end_at
    )
  );

  return v_updated;
end;
$$;

-- 6. Edição em série alcança também quem já chegou -------------------------------------------------
do $rewrite$
declare
  v_def text;
  v_old constant text := 'and a.status in (''Reservado'', ''Agendado'', ''Confirmado'', ''Iniciado'')';
  v_new constant text := 'and a.status in (''Reservado'', ''Agendado'', ''Confirmado'', ''Chegou'', ''Iniciado'')';
begin
  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p
  where p.pronamespace = 'public'::regnamespace and p.proname = 'update_recurrence_series_atomic';
  if v_def is null then
    raise exception 'Funcao update_recurrence_series_atomic nao encontrada';
  end if;
  if position(v_old in v_def) = 0 then
    raise exception 'update_recurrence_series_atomic: trecho de status nao encontrado';
  end if;
  execute replace(v_def, v_old, v_new);
end;
$rewrite$;
