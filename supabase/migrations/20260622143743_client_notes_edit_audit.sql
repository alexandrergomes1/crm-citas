-- UTF-8. CLIENT-NOTES-UX-03: authorized and audited note editing.

create or replace function public.update_client_note_atomic(
  p_org_id uuid,
  p_note_id uuid,
  p_client_id uuid,
  p_body text,
  p_note_date date
) returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_note_type text;
  v_appointment_id uuid;
begin
  if not exists (
    select 1 from public.user_roles ur
    where ur.org_id = p_org_id
      and ur.user_id = (select auth.uid())
      and ur.active
      and ur.role::text in ('owner', 'admin', 'manager', 'receptionist', 'professional')
  ) then
    raise exception 'Sem permissão para editar notas';
  end if;

  if length(btrim(coalesce(p_body, ''))) not between 1 and 5000 then
    raise exception 'A nota deve ter entre 1 e 5000 caracteres';
  end if;
  if p_note_date is null then
    raise exception 'Data da nota obrigatória';
  end if;

  select note_type, appointment_id
    into v_note_type, v_appointment_id
  from public.client_notes
  where id = p_note_id
    and org_id = p_org_id
    and client_id = p_client_id
    and deleted_at is null
  for update;

  if not found then
    raise exception 'Nota não pertence ao cliente ou à organização';
  end if;

  update public.client_notes
  set content = btrim(p_body),
      note_date = p_note_date,
      updated_at = now()
  where id = p_note_id;

  insert into public.audit_logs (
    org_id, user_id, table_name, operation, record_id, new_data
  ) values (
    p_org_id, (select auth.uid()), 'client_notes', 'CLIENT_NOTE_UPDATED', p_note_id,
    pg_catalog.jsonb_build_object(
      'client_id', p_client_id,
      'appointment_id', v_appointment_id,
      'note_type', v_note_type,
      'note_date', p_note_date
    )
  );

  return true;
end;
$$;

revoke all on function public.update_client_note_atomic(uuid, uuid, uuid, text, date) from public;
revoke all on function public.update_client_note_atomic(uuid, uuid, uuid, text, date) from anon;
grant execute on function public.update_client_note_atomic(uuid, uuid, uuid, text, date) to authenticated;
