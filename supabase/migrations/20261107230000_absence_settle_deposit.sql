-- Ausência com sinal (P2, aprovado em 07/11): marcar a ausência e acertar o sinal numa transação só.
-- Encoding: UTF-8
--
-- Igual ao cancelamento (cancel_appointment_settle_deposit_atomic), mas o destino do status é
-- 'Ausência' e o padrão da tela é ficar com o sinal ('fee'). Os destinos do sinal:
--   fee    · o sinal fica com a empresa (continua confirmado, como na taxa de cancelamento)
--   credit · vira crédito da cliente (adjust_client_balance_atomic, chave = id do agendamento)
--   refund · o sinal é anulado/estornado (void_appointment_deposit_atomic)
-- Repetir a chamada num agendamento já em Ausência só acerta o sinal que ainda estiver pendente.

create or replace function public.mark_absent_settle_deposit_atomic(
  p_org_id uuid,
  p_appointment_id uuid,
  p_deposit_mode text default 'fee'
)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_appt public.appointments;
  v_already boolean := false;
  v_total numeric(12,2);
  v_credited numeric(12,2) := 0;
  v_kept numeric(12,2) := 0;
  v_voided integer := 0;
  v_deposit_id uuid;
begin
  if not public.has_permission(p_org_id, 'agenda.manage') then
    raise exception 'Sem permissao para marcar ausencia' using errcode = '42501';
  end if;
  if p_deposit_mode is null or p_deposit_mode not in ('credit', 'refund', 'fee') then
    raise exception 'Destino do sinal invalido' using errcode = '22023';
  end if;

  select * into v_appt
  from public.appointments a
  where a.id = p_appointment_id and a.org_id = p_org_id
  for update;
  if not found then
    raise exception 'Agendamento nao encontrado' using errcode = 'P0002';
  end if;

  if v_appt.status = 'Ausência' then
    v_already := true;
  else
    if not public.agenda_status_transition_allowed(v_appt.status, 'Ausência') then
      raise exception 'Agendamento neste estado nao pode ser marcado como ausencia' using errcode = '22023';
    end if;

    update public.appointments
    set status = 'Ausência'
    where org_id = p_org_id and id = v_appt.id;

    insert into public.appointment_status_history (org_id, appointment_id, status, changed_by, notes)
    values (p_org_id, v_appt.id, 'Ausência', auth.uid(), 'deposit:' || p_deposit_mode);

    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
    values (
      p_org_id, auth.uid(), 'appointments', 'STATUS_CHANGE', v_appt.id,
      pg_catalog.jsonb_build_object('status', v_appt.status),
      pg_catalog.jsonb_build_object('status', 'Ausência', 'deposit_mode', p_deposit_mode)
    );
  end if;

  select coalesce(sum(d.amount), 0) into v_total
  from public.appointment_deposits d
  where d.org_id = p_org_id and d.appointment_id = v_appt.id and d.status = 'confirmed';

  if v_total > 0 then
    if p_deposit_mode = 'fee' then
      v_kept := v_total;
    else
      if not public.has_permission(p_org_id, 'comanda.operate') then
        raise exception 'Sem permissao para mexer no sinal' using errcode = '42501';
      end if;
      if p_deposit_mode = 'credit' then
        perform public.adjust_client_balance_atomic(
          p_org_id, v_appt.client_id, 'credit', v_total, 'Sinal de agendamento com ausência', v_appt.id
        );
        v_credited := v_total;
      end if;
      for v_deposit_id in
        select d.id from public.appointment_deposits d
        where d.org_id = p_org_id and d.appointment_id = v_appt.id and d.status = 'confirmed'
        order by d.created_at, d.id
      loop
        perform public.void_appointment_deposit_atomic(p_org_id, v_deposit_id);
        v_voided := v_voided + 1;
      end loop;
    end if;
  end if;

  return pg_catalog.jsonb_build_object(
    'appointment_id', v_appt.id,
    'already_absent', v_already,
    'credited', v_credited,
    'voided', v_voided,
    'fee_kept', v_kept
  );
end;
$$;

revoke all on function public.mark_absent_settle_deposit_atomic(uuid, uuid, text) from public, anon;
grant execute on function public.mark_absent_settle_deposit_atomic(uuid, uuid, text) to authenticated, service_role;
