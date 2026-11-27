-- Itens do agendamento e ficha clínica: papel e travas no banco (revisão de 29 out).
-- Encoding: UTF-8
-- 1) appointment_items: só quem opera a agenda (owner/admin/manager/receptionist) grava.
--    Antes qualquer membro (inclusive visualizadora e profissional) gravava por PostgREST.
-- 2) Trava: item de atendimento Pago, Pago Parcial, Cancelado ou Ausência não muda preço,
--    quantidade, desconto, duração, nome, tipo, profissional nem some. Exceção: linhas
--    criadas na mesma transação do agendamento (RPCs de criação).
-- 3) Notas profissionais da anamnese: recepção não grava; RLS de UPDATE em anamneses idem.

drop policy if exists "appt_items: gerenciar" on public.appointment_items;

create policy "appt_items: inserir" on public.appointment_items
  for insert to authenticated
  with check (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in ('owner', 'admin', 'manager', 'receptionist')
  );

create policy "appt_items: alterar" on public.appointment_items
  for update to authenticated
  using (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in ('owner', 'admin', 'manager', 'receptionist')
  )
  with check (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in ('owner', 'admin', 'manager', 'receptionist')
  );

create policy "appt_items: apagar" on public.appointment_items
  for delete to authenticated
  using (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in ('owner', 'admin', 'manager', 'receptionist')
  );

create or replace function public.lock_closed_appointment_items()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_appointment_id uuid;
  v_status text;
  v_created_now boolean;
begin
  if tg_op = 'UPDATE' then
    if new.appointment_id is not distinct from old.appointment_id
      and new.price is not distinct from old.price
      and new.qty is not distinct from old.qty
      and new.discount is not distinct from old.discount
      and new.duration_minutes is not distinct from old.duration_minutes
      and new.name is not distinct from old.name
      and new.type is not distinct from old.type
      and new.ref_id is not distinct from old.ref_id
      and new.professional_id is not distinct from old.professional_id
      and new.commission_pct is not distinct from old.commission_pct
      and new.cost_amount is not distinct from old.cost_amount
    then
      return new;
    end if;
  end if;

  v_appointment_id := case when tg_op = 'DELETE' then old.appointment_id else new.appointment_id end;

  select a.status, (a.xmin::text = (txid_current() % 4294967296)::text)
    into v_status, v_created_now
  from public.appointments a
  where a.id = v_appointment_id;

  -- Agendamento criado ou reescrito na mesma transação (RPC), ou já removido (cascata).
  if v_status is null or coalesce(v_created_now, false) then
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  if v_status in ('Pago', 'Pago Parcial', 'Cancelado', 'Ausência', 'Ausencia') then
    raise exception 'Atendimento % não aceita mudança nos serviços', v_status
      using errcode = '23514';
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

drop trigger if exists trg_lock_closed_appointment_items on public.appointment_items;
create trigger trg_lock_closed_appointment_items
  before insert or update or delete on public.appointment_items
  for each row execute function public.lock_closed_appointment_items();

create or replace function public.save_anamnese_professional_notes_atomic(
  p_org_id uuid, p_anamnese_id uuid, p_notes text
) returns void
language plpgsql
set search_path = ''
as $$
declare
  v_role text;
  v_old  text;
begin
  v_role := public.auth_user_role(p_org_id);
  if v_role is null or v_role not in ('owner', 'admin', 'manager', 'professional') then
    raise exception 'Sem permissao para registrar notas profissionais'
      using errcode = '42501';
  end if;

  select professional_notes
    into v_old
  from public.anamneses
  where id = p_anamnese_id
    and org_id = p_org_id
  for update;

  if not found then
    raise exception 'Ficha de anamnese nao encontrada'
      using errcode = 'P0002';
  end if;

  update public.anamneses
  set
    professional_notes = nullif(pg_catalog.btrim(coalesce(p_notes, '')), ''),
    updated_at         = pg_catalog.now()
  where id     = p_anamnese_id
    and org_id = p_org_id;

  insert into public.audit_logs (
    org_id, user_id, table_name, operation, record_id, old_data, new_data
  )
  values (
    p_org_id,
    auth.uid(),
    'anamneses',
    'PROFESSIONAL_NOTES_UPDATED',
    p_anamnese_id,
    pg_catalog.jsonb_build_object('professional_notes', v_old),
    pg_catalog.jsonb_build_object(
      'professional_notes',
      nullif(pg_catalog.btrim(coalesce(p_notes, '')), '')
    )
  );
end;
$$;

drop policy if exists anamneses_update on public.anamneses;
create policy anamneses_update on public.anamneses
  for update to authenticated
  using (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in ('owner', 'admin', 'manager', 'professional')
  )
  with check (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in ('owner', 'admin', 'manager', 'professional')
  );
