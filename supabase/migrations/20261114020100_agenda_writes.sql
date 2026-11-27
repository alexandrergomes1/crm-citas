-- Agenda: ações que antes faziam 3 a 6 idas ao banco (ler, decidir no app, gravar em várias tabelas)
-- viram UMA função cada, tudo-ou-nada. Todas SECURITY INVOKER: a RLS vale como antes, e as funções
-- atômicas que elas chamam (update_appointment_atomic, reschedule_appointment_atomic, create_time_blocks_atomic,
-- refund_sale_atomic, create_client_note_atomic etc.) continuam conferindo permissão, conflito de horário,
-- regra de status e auditoria. Nenhuma regra muda; os textos de erro são os mesmos que o app mostrava.
-- Encoding: UTF-8
set client_encoding = 'UTF8';

-- Duração que vale para o item (src/domain/item-duration.ts · effectiveItemDuration + serviceSlotMinutes):
-- a gravada; senão a do catálogo (serviço sem duração ocupa 15 min); senão 60 min.
create or replace function public.agenda_item_duration(p_stored integer, p_catalog integer, p_has_service boolean)
returns integer
language sql
immutable
security invoker
set search_path = ''
as $$
  select case
    when p_stored is not null and p_stored > 0 then p_stored
    when p_has_service then case when p_catalog is not null and p_catalog > 0 then p_catalog else 15 end
    else 60
  end;
$$;

-- Itens gravados no formato que update_appointment_atomic recebe (src/domain/item-duration.ts · toRpcItem).
create or replace function public.agenda_rpc_items(p_org_id uuid, p_appointment_id uuid)
returns table (item_id uuid, item jsonb, qty integer, discount numeric, ord bigint)
language sql
stable
security invoker
set search_path = ''
as $$
  select i.id,
    pg_catalog.jsonb_build_object(
      'service_id', i.ref_id, 'service_name', i.name, 'price', coalesce(i.price, 0),
      'duration_minutes', public.agenda_item_duration(i.duration_minutes, s.duration_minutes, s.id is not null),
      'professional_id', i.professional_id, 'bundle_id', i.bundle_id, 'bundle_item_id', i.bundle_item_id,
      'bundle_name', i.bundle_name, 'bundle_item_position', i.bundle_item_position,
      'bundle_allocated_price', i.bundle_allocated_price,
      'bundle_original_price_snapshot', i.bundle_original_price_snapshot),
    i.qty, i.discount,
    pg_catalog.row_number() over (order by i.created_at, i.id)
  from public.appointment_items i
  left join public.services s on s.id = i.ref_id and s.org_id = i.org_id
  where i.org_id = p_org_id and i.appointment_id = p_appointment_id;
$$;

-- Regrava o agendamento com a nova lista de itens pela RPC (horário, status, conflito e auditoria).
create or replace function public.agenda_save_items(
  p_org_id uuid,
  p_appointment public.appointments,
  p_items jsonb,
  p_force boolean
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_minutes integer;
  v_total numeric;
begin
  if pg_catalog.jsonb_array_length(p_items) = 0 then
    raise exception 'O agendamento precisa de pelo menos um serviço.' using errcode = 'P0001';
  end if;
  select sum((e ->> 'duration_minutes')::integer), sum(pg_catalog.round((e ->> 'price')::numeric * 100)) / 100
  into v_minutes, v_total
  from pg_catalog.jsonb_array_elements(p_items) e;
  if v_minutes > 1440 then
    raise exception 'O atendimento passaria de 24 h.' using errcode = 'P0001';
  end if;
  perform public.update_appointment_atomic(
    p_org_id, p_appointment.id, p_appointment.client_id, p_appointment.staff_id,
    p_appointment.start_at, p_appointment.start_at + pg_catalog.make_interval(mins => v_minutes), v_minutes,
    p_appointment.status, coalesce(p_appointment.source, 'MANUAL'), p_appointment.notes, p_appointment.internal_notes,
    v_total, p_items, p_force and public.has_permission(p_org_id, 'agenda.override_conflict'));
end;
$$;

-- ─── Itens do agendamento: adicionar, editar, remover (spec 35) ─────────────────────────────────
-- Antes: acesso + agendamento + catálogo + RPC (4 idas). p_op: 'add' | 'update' | 'remove'.
-- Só preço/profissional (duração igual à atual): update_appointment_item_atomic, como antes.
create or replace function public.agenda_edit_items(
  p_org_id uuid,
  p_appointment_id uuid,
  p_op text,
  p_item_id uuid default null,
  p_service_id uuid default null,
  p_name text default null,
  p_price numeric default null,
  p_professional_id uuid default null,
  p_duration integer default null,
  p_force boolean default false
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_appt public.appointments;
  v_items jsonb;
  v_current integer;
  v_catalog integer;
begin
  if not public.has_permission(p_org_id, 'agenda.manage') then
    raise exception 'Sem permissão para alterar agendamentos' using errcode = '42501';
  end if;
  if p_op not in ('add', 'update', 'remove') then
    raise exception 'Operação inválida' using errcode = '22023';
  end if;
  if p_op = 'add' and (nullif(pg_catalog.btrim(p_name), '') is null or pg_catalog.char_length(p_name) > 200) then
    raise exception 'Nome do serviço inválido (até 200 caracteres).' using errcode = '22023';
  end if;
  if p_op <> 'remove' and (p_price is null or p_price < 0 or p_price > 100000) then
    raise exception 'Preço inválido.' using errcode = '22023';
  end if;

  -- Trava o agendamento até o fim: a leitura dos itens e a regravação veem o mesmo estado.
  select * into v_appt from public.appointments a
  where a.id = p_appointment_id and a.org_id = p_org_id
  for update;
  if not found then
    raise exception 'Agendamento não encontrado' using errcode = 'P0002';
  end if;
  if v_appt.status in ('Pago', 'Pago Parcial', 'Cancelado', 'Ausência') then
    raise exception 'Atendimento pago, cancelado ou com ausência não muda mais.' using errcode = 'P0001';
  end if;

  if p_op = 'add' then
    select s.duration_minutes into v_catalog from public.services s where s.id = p_service_id and s.org_id = p_org_id;
    if not found then
      raise exception 'Serviço não encontrado no catálogo' using errcode = 'P0002';
    end if;
  elsif not exists (select 1 from public.appointment_items i
                    where i.id = p_item_id and i.appointment_id = p_appointment_id and i.org_id = p_org_id) then
    raise exception 'Item não encontrado' using errcode = 'P0002';
  end if;

  if p_op = 'update' then
    select (r.item ->> 'duration_minutes')::integer into v_current
    from public.agenda_rpc_items(p_org_id, p_appointment_id) r where r.item_id = p_item_id;
    if p_duration is null or p_duration = v_current then
      -- Uma operação só: trava o agendamento, grava o item, soma o total e audita.
      perform public.update_appointment_item_atomic(p_org_id, p_appointment_id, p_item_id, p_price, p_professional_id);
      return;
    end if;
  end if;

  -- A RPC de regravação não preserva quantidade nem desconto por item.
  if exists (select 1 from public.agenda_rpc_items(p_org_id, p_appointment_id) r
             where coalesce(r.qty, 1) <> 1 or coalesce(r.discount, 0) <> 0) then
    raise exception 'Este agendamento tem quantidade ou desconto definidos por serviço, que seriam apagados. Ajuste pelo checkout.'
      using errcode = 'P0001';
  end if;

  select coalesce(pg_catalog.jsonb_agg(
      case when p_op = 'update' and r.item_id = p_item_id
        then r.item || pg_catalog.jsonb_build_object('price', p_price, 'professional_id', p_professional_id, 'duration_minutes', p_duration)
        else r.item end
      order by r.ord) filter (where not (p_op = 'remove' and r.item_id = p_item_id)), '[]'::jsonb)
  into v_items
  from public.agenda_rpc_items(p_org_id, p_appointment_id) r;

  if p_op = 'add' then
    v_items := v_items || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'service_id', p_service_id, 'service_name', p_name, 'price', p_price,
      'duration_minutes', public.agenda_item_duration(null, v_catalog, true),
      'professional_id', p_professional_id, 'bundle_id', null, 'bundle_item_id', null));
  end if;

  perform public.agenda_save_items(p_org_id, v_appt, v_items, p_op = 'update' and p_force);
end;
$$;

-- ─── Arrastar para reagendar (dia, hora e, opcional, profissional) ──────────────────────────────
-- Antes: acesso + agendamento + catálogo + RPC (até 4 idas). Mesma profissional: reagenda atômica;
-- troca de profissional: regrava pela RPC de atualização (os itens da profissional antiga passam para a nova).
create or replace function public.agenda_move_appointment(
  p_org_id uuid,
  p_appointment_id uuid,
  p_start_at timestamptz,
  p_staff_id uuid default null
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_appt public.appointments;
  v_minutes integer;
  v_items jsonb;
begin
  if not public.has_permission(p_org_id, 'agenda.manage') then
    raise exception 'Sem permissão para reagendar' using errcode = '42501';
  end if;
  select * into v_appt from public.appointments a where a.id = p_appointment_id and a.org_id = p_org_id for update;
  if not found then
    raise exception 'Agendamento não encontrado' using errcode = 'P0002';
  end if;

  if p_staff_id is null or p_staff_id = v_appt.staff_id then
    perform public.reschedule_appointment_atomic(p_org_id, p_appointment_id, p_start_at);
    return;
  end if;

  if exists (select 1 from public.agenda_rpc_items(p_org_id, p_appointment_id) r
             where coalesce(r.qty, 1) <> 1 or coalesce(r.discount, 0) <> 0) then
    raise exception 'Este agendamento tem desconto por serviço; troque a profissional pelo checkout.' using errcode = 'P0001';
  end if;

  select coalesce(pg_catalog.jsonb_agg(
      r.item || pg_catalog.jsonb_build_object('professional_id',
        case when r.item ->> 'professional_id' is null or (r.item ->> 'professional_id')::uuid = v_appt.staff_id
          then p_staff_id else (r.item ->> 'professional_id')::uuid end)
      order by r.ord), '[]'::jsonb)
  into v_items
  from public.agenda_rpc_items(p_org_id, p_appointment_id) r;

  v_minutes := pg_catalog.round(extract(epoch from (v_appt.end_at - v_appt.start_at)) / 60)::integer;
  perform public.update_appointment_atomic(
    p_org_id, p_appointment_id, v_appt.client_id, p_staff_id, p_start_at,
    p_start_at + pg_catalog.make_interval(mins => v_minutes), v_minutes, v_appt.status,
    coalesce(v_appt.source, 'MANUAL'), v_appt.notes, v_appt.internal_notes,
    (select coalesce(sum(pg_catalog.round((e ->> 'price')::numeric * 100)), 0) / 100 from pg_catalog.jsonb_array_elements(v_items) e),
    v_items, false);
end;
$$;

-- ─── Nota interna do atendimento, espelhada no histórico da cliente ─────────────────────────────
-- Antes: acesso + gravação + notas da cliente + criar/editar nota (4 idas), sem transação.
create or replace function public.agenda_set_internal_note(
  p_org_id uuid,
  p_appointment_id uuid,
  p_note text,
  p_note_date date
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_note text := nullif(pg_catalog.btrim(p_note), '');
  v_client uuid;
  v_existing record;
begin
  if not public.has_permission(p_org_id, 'agenda.manage') then
    raise exception 'Sem permissão' using errcode = '42501';
  end if;
  update public.appointments set internal_notes = v_note
  where id = p_appointment_id and org_id = p_org_id
  returning client_id into v_client;
  if not found then
    raise exception 'Agendamento não encontrado' using errcode = 'P0002';
  end if;
  if v_note is null or v_client is null then
    return;
  end if;

  select n.id, n.note_date into v_existing
  from public.client_notes n
  where n.org_id = p_org_id and n.client_id = v_client and n.appointment_id = p_appointment_id
    and n.note_type = 'appointment' and n.deleted_at is null
  order by n.note_date desc, n.created_at desc
  limit 1;
  if found then
    perform public.update_client_note_atomic(p_org_id, v_existing.id, v_client, v_note, v_existing.note_date);
  else
    perform public.create_client_note_atomic(p_org_id, v_client, p_appointment_id, 'appointment', v_note, p_note_date);
  end if;
end;
$$;

-- ─── Trocar a cliente do agendamento ────────────────────────────────────────────────────────────
-- Antes: acesso + agendamento + cliente + gravação (4 idas). Recusa quando o agendamento já tem sinal
-- confirmado ou ficha ligada (pertencem à cliente anterior) e quando a cliente nova tem bloqueio para novos
-- agendamentos (mesma trava de update_appointment_atomic). Grava a troca em audit_logs (antiga e nova).
create or replace function public.agenda_change_client(p_org_id uuid, p_appointment_id uuid, p_client_id uuid)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_status text;
  v_old uuid;
  v_name text;
  v_blocked timestamptz;
begin
  if not public.has_permission(p_org_id, 'agenda.manage') then
    raise exception 'Sem permissão para alterar agendamentos' using errcode = '42501';
  end if;
  select a.status, a.client_id into v_status, v_old
  from public.appointments a where a.id = p_appointment_id and a.org_id = p_org_id for update;
  select c.full_name, c.blocked_at into v_name, v_blocked from public.clients c where c.id = p_client_id and c.org_id = p_org_id;
  if v_status is null or v_name is null then
    raise exception 'Agendamento ou cliente não encontrado' using errcode = 'P0002';
  end if;
  if v_old is not distinct from p_client_id then
    return;
  end if;
  if v_status in ('Pago', 'Pago Parcial', 'Cancelado', 'Ausência') then
    raise exception 'Atendimento pago, cancelado ou com falta não muda mais.' using errcode = 'P0001';
  end if;
  if v_blocked is not null then
    raise exception 'Cliente possui bloqueio para novos agendamentos' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.appointment_deposits d
             where d.org_id = p_org_id and d.appointment_id = p_appointment_id and d.status = 'confirmed') then
    raise exception 'Este agendamento tem sinal registrado. Para trocar a cliente, cancele e crie outro agendamento.' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.anamneses f where f.org_id = p_org_id and f.appointment_id = p_appointment_id) then
    raise exception 'Este agendamento tem ficha ligada. Para trocar a cliente, cancele e crie outro agendamento.' using errcode = 'P0001';
  end if;
  update public.appointments set client_id = p_client_id, client_name = v_name
  where id = p_appointment_id and org_id = p_org_id;
  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (p_org_id, (select auth.uid()), 'appointments', 'APPOINTMENT_CLIENT_CHANGED', p_appointment_id,
    pg_catalog.jsonb_build_object('client_id', v_old), pg_catalog.jsonb_build_object('client_id', p_client_id));
end;
$$;

-- ─── Cancelar um agendamento já pago: estorna e cancela (e, se pedido, o próximo da série) ──────
-- Antes: acesso + comanda + estorno + série (até 5 idas). A comanda é achada aqui pelo agendamento.
-- A série é um passo à parte (bloco próprio): se falhar, o estorno e o cancelamento deste já valem e
-- o resultado diz series_failed (o app avisa o que faltou), como antes.
create or replace function public.agenda_refund_and_cancel(
  p_org_id uuid,
  p_appointment_id uuid,
  p_reason text,
  p_destination text,
  p_restock_products boolean,
  p_idempotency_key uuid,
  p_series boolean
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_sale uuid;
  v_result jsonb;
  v_current record;
  v_next uuid;
  v_series_failed boolean := false;
begin
  if not public.has_permission(p_org_id, 'agenda.manage') then
    raise exception 'Seu perfil não cancela agendamentos.' using errcode = '42501';
  end if;
  -- Repetição com a mesma chave (duplo clique, rede): devolve o estorno já feito, sem estornar de novo.
  select pg_catalog.jsonb_build_object('amount', r.amount, 'destination', r.destination, 'duplicate', true, 'series_failed', false)
  into v_result
  from public.sale_refunds r join public.sales s on s.id = r.sale_id and s.org_id = r.org_id
  where r.org_id = p_org_id and r.idempotency_key = p_idempotency_key and s.appointment_id = p_appointment_id
  limit 1;
  if v_result is not null then
    return v_result;
  end if;

  select s.id into v_sale from public.sales s
  where s.org_id = p_org_id and s.appointment_id = p_appointment_id and s.status <> 'cancelled'
  order by s.created_at desc
  limit 1;
  if v_sale is null then
    raise exception 'Não achei o checkout deste agendamento. Atualize a tela e tente de novo.' using errcode = 'P0002';
  end if;

  v_result := public.refund_sale_atomic(p_org_id, v_sale, p_reason, p_destination, p_restock_products, p_idempotency_key, true);

  if p_series then
    begin
      select a.recurrence_id, a.start_at into v_current
      from public.appointments a where a.org_id = p_org_id and a.id = p_appointment_id;
      if v_current.recurrence_id is not null then
        select a.id into v_next from public.appointments a
        where a.org_id = p_org_id and a.recurrence_id = v_current.recurrence_id
          and a.status in ('Reservado', 'Agendado', 'Confirmado') and a.start_at > v_current.start_at
        order by a.start_at
        limit 1;
        if v_next is not null then
          perform public.cancel_appointment_settle_deposit_atomic(p_org_id, v_next, 'Série cancelada',
            case when p_destination = 'credito' then 'credit' else 'refund' end, true);
        end if;
      end if;
    exception when others then
      v_series_failed := true;
    end;
  end if;

  return coalesce(v_result, '{}'::jsonb) || pg_catalog.jsonb_build_object('series_failed', v_series_failed);
end;
$$;

-- ─── Bloqueios de horário: criar (uma profissional ou a equipe toda) e editar ───────────────────
-- Antes: criar para a equipe = 1 ida por profissional; editar = ler + apagar + criar (+ recolocar se falhar).
-- Agora uma ida. Editar troca o bloqueio numa transação: se o novo não puder ser criado, o antigo fica.
-- Quem só vê a própria agenda bloqueia só a própria agenda (a regra do app, repetida aqui).
create or replace function public.agenda_save_time_blocks(
  p_org_id uuid,
  p_replace_id uuid,
  p_staff_id uuid,
  p_all_staff boolean,
  p_time_block_type_id uuid,
  p_title text,
  p_notes text,
  p_allow_online_booking boolean,
  p_recurrence_frequency text,
  p_recurrence_count integer,
  p_occurrences jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_full boolean := public.has_permission(p_org_id, 'agenda.view_all');
  v_own constant text := 'Seu acesso mostra só a sua agenda: bloqueie e remova apenas horários seus.';
  v_member record;
  v_skipped text[] := '{}';
  v_total integer := 0;
  v_first_state text;
begin
  if not public.has_permission(p_org_id, 'agenda.block_time') then
    raise exception 'Sem permissão para bloquear horários' using errcode = '42501';
  end if;
  if p_replace_id is not null and p_all_staff then
    raise exception 'Editar um bloqueio não o multiplica pela equipe' using errcode = '22023';
  end if;
  if not v_full and (p_all_staff or not exists (
    select 1 from public.staff_members sm
    where sm.org_id = p_org_id and sm.id = p_staff_id and sm.user_id = (select auth.uid()))) then
    raise exception '%', v_own using errcode = 'P0001';
  end if;

  if p_replace_id is not null then
    if not v_full and not exists (
      select 1 from public.time_blocks b join public.staff_members sm on sm.id = b.staff_id and sm.org_id = b.org_id
      where b.org_id = p_org_id and b.id = p_replace_id and sm.user_id = (select auth.uid())) then
      raise exception '%', v_own using errcode = 'P0001';
    end if;
    perform public.delete_time_block_atomic(p_org_id, p_replace_id);
  end if;

  if not p_all_staff then
    perform public.create_time_blocks_atomic(p_org_id, p_staff_id, p_time_block_type_id, p_title, p_notes,
      p_allow_online_booking, p_recurrence_frequency, p_recurrence_count, p_occurrences);
    return pg_catalog.jsonb_build_object('skipped', '[]'::jsonb);
  end if;

  -- Equipe toda: um bloqueio por profissional ativa. Quem já tem atendimento no horário é pulado e
  -- avisado, em vez de desfazer o bloqueio de todas as outras.
  for v_member in
    select sm.id, coalesce(nullif(pg_catalog.btrim(sm.display_name), ''), sm.name) as label
    from public.staff_members sm where sm.org_id = p_org_id and sm.active
    order by sm.position, sm.id
  loop
    v_total := v_total + 1;
    begin
      perform public.create_time_blocks_atomic(p_org_id, v_member.id, p_time_block_type_id, p_title, p_notes,
        p_allow_online_booking, p_recurrence_frequency, p_recurrence_count, p_occurrences);
    exception when others then
      v_skipped := v_skipped || v_member.label;
      v_first_state := coalesce(v_first_state, sqlstate);
    end;
  end loop;
  if v_total = 0 then
    raise exception 'Nenhuma profissional ativa para bloquear' using errcode = 'P0001';
  end if;
  if pg_catalog.cardinality(v_skipped) = v_total then
    -- Texto nosso, nunca a mensagem crua do banco.
    if v_first_state in ('23P01', 'P0001') then
      raise exception 'Nenhuma profissional pôde ser bloqueada: todas já têm atendimento ou bloqueio nesse horário.' using errcode = 'P0001';
    end if;
    raise exception 'Não foi possível bloquear o horário da equipe.' using errcode = 'P0001';
  end if;
  return pg_catalog.jsonb_build_object('skipped', pg_catalog.to_jsonb(v_skipped));
end;
$$;

-- Remover bloqueio. Antes: acesso + (alcance "own") profissional da pessoa + bloqueio + RPC.
create or replace function public.agenda_delete_time_block(p_org_id uuid, p_time_block_id uuid)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_staff uuid;
begin
  if not public.has_permission(p_org_id, 'agenda.block_time') then
    raise exception 'Sem permissão para remover bloqueios' using errcode = '42501';
  end if;
  if not public.has_permission(p_org_id, 'agenda.view_all') then
    select b.staff_id into v_staff from public.time_blocks b where b.org_id = p_org_id and b.id = p_time_block_id;
    if not found then
      raise exception 'Bloqueio não encontrado' using errcode = 'P0002';
    end if;
    if v_staff is null or not exists (
      select 1 from public.staff_members sm
      where sm.org_id = p_org_id and sm.id = v_staff and sm.user_id = (select auth.uid())) then
      raise exception 'Seu acesso mostra só a sua agenda: bloqueie e remova apenas horários seus.' using errcode = 'P0001';
    end if;
  end if;
  perform public.delete_time_block_atomic(p_org_id, p_time_block_id);
end;
$$;

-- ─── Editar a série (horário, duração, profissional, observação) ────────────────────────────────
-- Antes: acesso + agendamentos da série + RPC (3 idas). O novo horário de cada ocorrência é o mesmo dia
-- (no fuso do estúdio, lido aqui em organizations.timezone) com a hora pedida, como replaceTimeInTimeZone
-- (src/domain/agenda). Hora que não existe naquele dia (mudança para o horário de verão) é recusada.
create or replace function public.agenda_update_series(
  p_org_id uuid,
  p_recurrence_id uuid,
  p_staff_id uuid,
  p_time text,
  p_duration_minutes integer,
  p_notes text,
  p_from timestamptz,
  p_force_override boolean
)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_tz text;
  v_updates jsonb;
  v_bad date;
begin
  if p_time !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then
    raise exception 'Horário inválido' using errcode = '22023';
  end if;
  if pg_catalog.char_length(coalesce(p_notes, '')) > 1000 then
    raise exception 'Observação longa demais (até 1000 caracteres).' using errcode = '22023';
  end if;
  select o.timezone into v_tz from public.organizations o where o.id = p_org_id;
  if v_tz is null then
    raise exception 'Estúdio não encontrado' using errcode = 'P0002';
  end if;

  with moves as (
    select a.id, (a.start_at at time zone v_tz)::date as day,
      (((a.start_at at time zone v_tz)::date + p_time::time) at time zone v_tz) as start_at
    from public.appointments a
    where a.org_id = p_org_id and a.recurrence_id = p_recurrence_id
      and a.status in ('Reservado', 'Agendado', 'Confirmado', 'Chegou', 'Iniciado')
      and (p_from is null or a.start_at >= p_from)
  )
  select
    pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', m.id, 'start_at', m.start_at,
      'end_at', m.start_at + pg_catalog.make_interval(mins => p_duration_minutes)) order by m.start_at),
    min(m.day) filter (where pg_catalog.to_char(m.start_at at time zone v_tz, 'HH24:MI') <> p_time)
  into v_updates, v_bad
  from moves m;
  if v_bad is not null then
    raise exception 'O horário % não existe em % (mudança de horário de verão). Escolha outro horário.',
      p_time, pg_catalog.to_char(v_bad, 'DD/MM/YYYY') using errcode = 'P0001';
  end if;
  if v_updates is null then
    return 0;
  end if;
  return public.update_recurrence_series_atomic(p_org_id, p_recurrence_id, p_staff_id, p_duration_minutes,
    p_notes, v_updates, coalesce(p_force_override, false));
end;
$$;

-- ─── Lista de espera: adicionar ─────────────────────────────────────────────────────────────────
-- Antes: acesso + (alcance "own") profissional da pessoa + gravação.
create or replace function public.agenda_waitlist_add(
  p_org_id uuid,
  p_client_id uuid,
  p_service_id uuid,
  p_staff_id uuid,
  p_windows jsonb,
  p_notes text
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if not public.has_permission(p_org_id, 'agenda.manage') then
    raise exception 'Sem permissão para a lista de espera' using errcode = '42501';
  end if;
  if p_staff_id is not null and not public.has_permission(p_org_id, 'agenda.view_all') and not exists (
    select 1 from public.staff_members sm
    where sm.org_id = p_org_id and sm.id = p_staff_id and sm.user_id = (select auth.uid())) then
    raise exception 'Sem acesso à agenda desta profissional' using errcode = 'P0001';
  end if;
  insert into public.agenda_waitlist (org_id, client_id, service_id, staff_id, windows, notes)
  values (p_org_id, p_client_id, p_service_id, p_staff_id, p_windows, p_notes)
  returning id into v_id;
  return v_id;
end;
$$;

-- ─── Ficha pelo agendamento: gerar o link (e registrar validade e envio) ─────────────────────────
-- Antes: acesso + criar + validade + envio (até 4 idas).
create or replace function public.anamnese_create_link(
  p_org_id uuid,
  p_template_id uuid,
  p_client_id uuid,
  p_client_name text,
  p_appointment_id uuid,
  p_requires_professional boolean,
  p_link_days integer,
  p_send_channel text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_ficha public.anamneses;
  v_expires timestamptz;
begin
  v_ficha := public.create_anamnese_atomic(p_org_id, p_template_id, p_client_id, p_client_name, p_appointment_id, p_requires_professional);
  v_expires := v_ficha.token_expires_at;
  -- Ficha já assinada (atendimento que já tinha uma): não há link a ajustar nem a registrar.
  if v_ficha.status = 'pending' then
    if p_link_days is not null then
      v_expires := public.set_anamnese_link_validity(p_org_id, v_ficha.id, p_link_days);
    end if;
    if p_send_channel is not null then
      perform public.log_anamnese_send(p_org_id, v_ficha.id, p_send_channel);
    end if;
  end if;
  return pg_catalog.jsonb_build_object('id', v_ficha.id, 'token', v_ficha.public_token, 'expires_at', v_expires);
end;
$$;

-- Revogar o link: apaga a ficha pendente (assinada nunca) e devolve as fotos a remover do armazenamento.
-- Antes: ler + apagar (2 idas) além do acesso. A auditoria é gravada ANTES de apagar pelo gatilho
-- trg_protect_signed_anamnese_evidence (ANAMNESE_PENDING_DELETED: status, cliente, agendamento e modelo; sem respostas).
create or replace function public.anamnese_delete_pending(p_org_id uuid, p_anamnese_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_status text;
  v_data jsonb;
begin
  select a.status, a.professional_data into v_status, v_data
  from public.anamneses a where a.org_id = p_org_id and a.id = p_anamnese_id;
  if not found then
    raise exception 'Ficha de anamnese não encontrada' using errcode = 'P0002';
  end if;
  if v_status = 'signed' then
    raise exception 'Fichas assinadas não podem ser excluídas' using errcode = 'P0001';
  end if;
  delete from public.anamneses a where a.org_id = p_org_id and a.id = p_anamnese_id and a.status = 'pending';
  if not found then
    raise exception 'Ficha pendente não encontrada' using errcode = 'P0002';
  end if;
  return case when pg_catalog.jsonb_typeof(v_data -> 'photos') = 'array' then v_data -> 'photos' else '[]'::jsonb end;
end;
$$;

revoke all on function public.agenda_item_duration(integer, integer, boolean) from public, anon;
revoke all on function public.agenda_rpc_items(uuid, uuid) from public, anon;
revoke all on function public.agenda_save_items(uuid, public.appointments, jsonb, boolean) from public, anon;
revoke all on function public.agenda_edit_items(uuid, uuid, text, uuid, uuid, text, numeric, uuid, integer, boolean) from public, anon;
revoke all on function public.agenda_move_appointment(uuid, uuid, timestamptz, uuid) from public, anon;
revoke all on function public.agenda_set_internal_note(uuid, uuid, text, date) from public, anon;
revoke all on function public.agenda_change_client(uuid, uuid, uuid) from public, anon;
revoke all on function public.agenda_refund_and_cancel(uuid, uuid, text, text, boolean, uuid, boolean) from public, anon;
revoke all on function public.agenda_save_time_blocks(uuid, uuid, uuid, boolean, uuid, text, text, boolean, text, integer, jsonb) from public, anon;
revoke all on function public.agenda_delete_time_block(uuid, uuid) from public, anon;
revoke all on function public.agenda_update_series(uuid, uuid, uuid, text, integer, text, timestamptz, boolean) from public, anon;
revoke all on function public.agenda_waitlist_add(uuid, uuid, uuid, uuid, jsonb, text) from public, anon;
revoke all on function public.anamnese_create_link(uuid, uuid, uuid, text, uuid, boolean, integer, text) from public, anon;
revoke all on function public.anamnese_delete_pending(uuid, uuid) from public, anon;

-- Ajudantes (agenda_item_duration, agenda_rpc_items, agenda_save_items) também precisam de execute: as funções
-- acima rodam como a pessoa logada. Não dão acesso a mais nada: são INVOKER, sob a RLS, e a gravação passa pela RPC.
grant execute on function public.agenda_item_duration(integer, integer, boolean) to authenticated;
grant execute on function public.agenda_rpc_items(uuid, uuid) to authenticated;
grant execute on function public.agenda_save_items(uuid, public.appointments, jsonb, boolean) to authenticated;
grant execute on function public.agenda_edit_items(uuid, uuid, text, uuid, uuid, text, numeric, uuid, integer, boolean) to authenticated;
grant execute on function public.agenda_move_appointment(uuid, uuid, timestamptz, uuid) to authenticated;
grant execute on function public.agenda_set_internal_note(uuid, uuid, text, date) to authenticated;
grant execute on function public.agenda_change_client(uuid, uuid, uuid) to authenticated;
grant execute on function public.agenda_refund_and_cancel(uuid, uuid, text, text, boolean, uuid, boolean) to authenticated;
grant execute on function public.agenda_save_time_blocks(uuid, uuid, uuid, boolean, uuid, text, text, boolean, text, integer, jsonb) to authenticated;
grant execute on function public.agenda_delete_time_block(uuid, uuid) to authenticated;
grant execute on function public.agenda_update_series(uuid, uuid, uuid, text, integer, text, timestamptz, boolean) to authenticated;
grant execute on function public.agenda_waitlist_add(uuid, uuid, uuid, uuid, jsonb, text) to authenticated;
grant execute on function public.anamnese_create_link(uuid, uuid, uuid, text, uuid, boolean, integer, text) to authenticated;
grant execute on function public.anamnese_delete_pending(uuid, uuid) to authenticated;

-- ─── Auditoria gravada por agenda_change_client (INVOKER) ───────────────────────────────────────
-- Mesma política da versão vigente (20261114010000_client_profile.sql), com todos os pares de lá e um novo no fim.
drop policy if exists audit_insert_member on public.audit_logs;
create policy audit_insert_member on public.audit_logs for insert to authenticated
  with check (
    org_id in (select public.auth_org_ids())
    and user_id = (select auth.uid())
    and public.has_org_role(org_id, array['owner', 'admin', 'manager', 'receptionist', 'professional', 'finance'])
    and (
      (table_name, operation) in (
        ('appointments', 'APPOINTMENT_CREATED'),
        ('appointments', 'APPOINTMENT_UPDATED'),
        ('appointments', 'APPOINTMENT_RESCHEDULED'),
        ('appointments', 'STATUS_CHANGE'),
        ('appointments', 'RECURRENCE_CREATED'),
        ('appointments', 'RECURRENCE_UPDATED'),
        ('appointments', 'RECURRENCE_CANCELLED'),
        ('appointment_items', 'APPOINTMENT_ITEM_UPDATED'),
        ('time_blocks', 'TIME_BLOCKS_CREATED'),
        ('time_blocks', 'TIME_BLOCK_DELETED'),
        ('anamneses', 'ANAMNESE_PENDING_DELETED'),
        ('anamneses', 'PROFESSIONAL_DRAFT_SAVED'),
        ('anamneses', 'PROFESSIONAL_COMPLETED'),
        ('anamneses', 'PROFESSIONAL_NOTES_UPDATED'),
        ('anamneses', 'PROFESSIONAL_REOPENED'),
        ('anamneses', 'CLINICAL_READ'),
        ('clients', 'CLIENT_BOOKING_BLOCKED'),
        ('clients', 'CLIENT_BOOKING_UNBLOCKED'),
        ('organizations', 'SETTINGS_SET'),
        -- register_stock_entry_atomic grava 'STOCK_' || upper(p_type), p_type em entrada/saida/ajuste.
        ('products', 'STOCK_ENTRADA'),
        ('products', 'STOCK_SAIDA'),
        ('products', 'STOCK_AJUSTE'),
        -- O2 (este arquivo): editar cliente, consentimento de marketing e devolução de sessão.
        ('clients', 'CLIENT_UPDATED'),
        ('clients', 'MARKETING_CONSENT_SET'),
        ('client_entitlements', 'ENTITLEMENT_SESSION_RESTORED'),
        -- Agenda (este arquivo): troca da cliente do agendamento (agenda_change_client).
        ('appointments', 'APPOINTMENT_CLIENT_CHANGED')
      )
    )
  );
