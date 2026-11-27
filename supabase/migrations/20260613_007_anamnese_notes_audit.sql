-- KA Beauty OS - Notas profissionais com trilha de auditoria
-- Encoding: UTF-8

create or replace function public.save_anamnese_professional_notes_atomic(
  p_org_id      uuid,
  p_anamnese_id uuid,
  p_notes       text
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_role text;
  v_old  text;
begin
  v_role := public.auth_user_role(p_org_id);
  if v_role not in ('owner', 'admin', 'manager', 'receptionist', 'professional') then
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

revoke all on function public.save_anamnese_professional_notes_atomic(uuid, uuid, text) from public;
revoke all on function public.save_anamnese_professional_notes_atomic(uuid, uuid, text) from anon;
grant execute on function public.save_anamnese_professional_notes_atomic(uuid, uuid, text) to authenticated;
