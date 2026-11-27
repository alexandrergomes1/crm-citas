-- Cancelar com sinal numa transação só + motivo em coluna própria.
-- Encoding: UTF-8
set client_encoding = 'UTF8';
--
-- Antes: o app cancelava, depois lançava o crédito (adjust_client_balance_atomic) e depois anulava
-- o sinal (void_appointment_deposit_atomic) em chamadas separadas. Falha no meio deixava
-- agendamento cancelado com sinal ainda "confirmado" (ou crédito lançado sem anular o sinal).
-- O motivo ia anexado em internal_notes ("Cancelado: ...").
--
-- Agora uma função só: cancela (e, se pedido, os próximos da série), aplica a política escolhida
-- (crédito / devolver / cobrar como taxa) e grava o motivo em appointments.cancel_reason.
-- Repetir a chamada não duplica crédito: o agendamento já cancelado só acerta o sinal que
-- ainda estiver "confirmado", e o crédito usa o id do agendamento como chave de idempotência.
-- Aditiva: coluna nova opcional e função nova; o app antigo continua usando set_appointment_status_atomic.

alter table public.appointments add column if not exists cancel_reason text;
alter table public.appointments drop constraint if exists appointments_cancel_reason_length;
alter table public.appointments add constraint appointments_cancel_reason_length
  check (cancel_reason is null or char_length(cancel_reason) <= 120);

comment on column public.appointments.cancel_reason is
  'Motivo informado ao cancelar (até 120 caracteres). Notas antigas guardavam "Cancelado: motivo" em internal_notes.';

create or replace function public.cancel_appointment_settle_deposit_atomic(
  p_org_id uuid,
  p_appointment_id uuid,
  p_reason text default null,
  p_deposit_mode text default 'fee',
  p_series boolean default false
)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_reason text := nullif(pg_catalog.btrim(coalesce(p_reason, '')), '');
  v_appt public.appointments;
  v_ids uuid[] := array[]::uuid[];
  v_more uuid[];
  v_cancelled uuid[] := array[]::uuid[];
  v_already boolean := false;
  v_id uuid;
  v_client_id uuid;
  v_total numeric(12,2);
  v_credited numeric(12,2) := 0;
  v_kept numeric(12,2) := 0;
  v_voided integer := 0;
  v_deposit_id uuid;
begin
  if not public.has_permission(p_org_id, 'agenda.manage') then
    raise exception 'Sem permissao para cancelar agendamentos' using errcode = '42501';
  end if;
  if p_deposit_mode is null or p_deposit_mode not in ('credit', 'refund', 'fee') then
    raise exception 'Destino do sinal invalido' using errcode = '22023';
  end if;
  if v_reason is not null and char_length(v_reason) > 120 then
    raise exception 'Motivo longo demais' using errcode = '22023';
  end if;

  -- Trava o agendamento: duplo clique ou duas abas esperam a primeira chamada terminar.
  select * into v_appt
  from public.appointments a
  where a.id = p_appointment_id and a.org_id = p_org_id
  for update;
  if not found then
    raise exception 'Agendamento nao encontrado' using errcode = 'P0002';
  end if;

  if v_appt.status = 'Cancelado' then
    -- Nova tentativa de acertar o sinal: nada a cancelar de novo.
    v_already := true;
    v_ids := array[v_appt.id];
  else
    if not public.agenda_status_transition_allowed(v_appt.status, 'Cancelado') then
      raise exception 'Agendamento neste estado nao pode ser cancelado' using errcode = '22023';
    end if;
    v_ids := array[v_appt.id];
    if p_series and v_appt.recurrence_id is not null then
      select pg_catalog.array_agg(locked.id order by locked.start_at) into v_more
      from (
        select a.id, a.start_at
        from public.appointments a
        where a.org_id = p_org_id
          and a.recurrence_id = v_appt.recurrence_id
          and a.id <> v_appt.id
          and a.status in ('Reservado', 'Agendado', 'Confirmado')
          and a.start_at > v_appt.start_at
          and a.start_at >= pg_catalog.now()
        for update
      ) locked;
      v_ids := v_ids || coalesce(v_more, array[]::uuid[]);
    end if;

    update public.appointments
    set status = 'Cancelado', cancel_reason = v_reason
    where org_id = p_org_id and id = any(v_ids);
    v_cancelled := v_ids;

    insert into public.appointment_status_history (org_id, appointment_id, status, changed_by, notes)
    select p_org_id, c.appointment_id, 'Cancelado', auth.uid(),
           case when c.appointment_id = v_appt.id then v_reason else 'recurrence_cancelled' end
    from pg_catalog.unnest(v_ids) as c(appointment_id);

    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
    values (
      p_org_id, auth.uid(), 'appointments', 'STATUS_CHANGE', v_appt.id,
      pg_catalog.jsonb_build_object('status', v_appt.status),
      pg_catalog.jsonb_build_object(
        'status', 'Cancelado', 'cancel_reason', v_reason,
        'deposit_mode', p_deposit_mode, 'series', coalesce(p_series, false),
        'appointment_ids', pg_catalog.to_jsonb(v_ids)
      )
    );
  end if;

  -- Sinal de cada agendamento cancelado: só o que ainda está "confirmado" (não aplicado a venda).
  foreach v_id in array v_ids loop
    select coalesce(sum(d.amount), 0) into v_total
    from public.appointment_deposits d
    where d.org_id = p_org_id and d.appointment_id = v_id and d.status = 'confirmed';
    if v_total <= 0 then
      continue;
    end if;

    if p_deposit_mode = 'fee' then
      v_kept := v_kept + v_total;
      continue;
    end if;

    if not public.has_permission(p_org_id, 'comanda.operate') then
      raise exception 'Sem permissao para mexer no sinal' using errcode = '42501';
    end if;

    if p_deposit_mode = 'credit' then
      select a.client_id into v_client_id
      from public.appointments a where a.id = v_id and a.org_id = p_org_id;
      -- A chave (o id do agendamento) torna a repetição inofensiva; a função confere financeiro.manage.
      perform public.adjust_client_balance_atomic(
        p_org_id, v_client_id, 'credit', v_total, 'Sinal de agendamento cancelado', v_id
      );
      v_credited := v_credited + v_total;
    end if;

    for v_deposit_id in
      select d.id from public.appointment_deposits d
      where d.org_id = p_org_id and d.appointment_id = v_id and d.status = 'confirmed'
      order by d.created_at, d.id
    loop
      perform public.void_appointment_deposit_atomic(p_org_id, v_deposit_id);
      v_voided := v_voided + 1;
    end loop;
  end loop;

  return pg_catalog.jsonb_build_object(
    'appointment_id', v_appt.id,
    'already_cancelled', v_already,
    'cancelled_ids', pg_catalog.to_jsonb(v_cancelled),
    'cancelled_count', coalesce(pg_catalog.array_length(v_cancelled, 1), 0),
    'credited', v_credited,
    'voided', v_voided,
    'fee_kept', v_kept
  );
end;
$$;

revoke all on function public.cancel_appointment_settle_deposit_atomic(uuid, uuid, text, text, boolean) from public, anon;
grant execute on function public.cancel_appointment_settle_deposit_atomic(uuid, uuid, text, text, boolean) to authenticated, service_role;
