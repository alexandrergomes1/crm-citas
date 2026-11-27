-- KA Beauty OS - Protect signed clinical evidence and narrow anamnese RLS
-- Encoding: UTF-8

create or replace function public.protect_signed_anamnese_evidence()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if old.status = 'signed' then
    if tg_op = 'DELETE' then
      raise exception 'Fichas assinadas nao podem ser excluidas'
        using errcode = '23514';
    end if;

    if (
      pg_catalog.to_jsonb(new)
        - array['professional_notes', 'professional_data', 'professional_completed_at', 'updated_at']
    ) is distinct from (
      pg_catalog.to_jsonb(old)
        - array['professional_notes', 'professional_data', 'professional_completed_at', 'updated_at']
    ) then
      raise exception 'Evidencias de uma ficha assinada sao imutaveis'
        using errcode = '23514';
    end if;
  end if;

  if tg_op = 'DELETE' then
    insert into public.audit_logs (
      org_id, user_id, table_name, operation, record_id, old_data
    )
    values (
      old.org_id,
      auth.uid(),
      'anamneses',
      'ANAMNESE_PENDING_DELETED',
      old.id,
      pg_catalog.jsonb_build_object(
        'status', old.status,
        'client_id', old.client_id,
        'appointment_id', old.appointment_id,
        'template_title', old.template_title
      )
    );
    return old;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_protect_signed_anamnese_evidence
  on public.anamneses;
create trigger trg_protect_signed_anamnese_evidence
before update or delete on public.anamneses
for each row
execute function public.protect_signed_anamnese_evidence();

drop policy if exists "anamneses_select" on public.anamneses;
drop policy if exists "anamneses_write" on public.anamneses;
drop policy if exists "anamneses_insert" on public.anamneses;
drop policy if exists "anamneses_update" on public.anamneses;
drop policy if exists "anamneses_delete_pending" on public.anamneses;

create policy "anamneses_select"
on public.anamneses
for select
to authenticated
using (
  org_id in (select public.auth_org_ids())
  and public.auth_user_role(org_id) in (
    'owner', 'admin', 'manager', 'receptionist', 'professional'
  )
);

create policy "anamneses_insert"
on public.anamneses
for insert
to authenticated
with check (
  org_id in (select public.auth_org_ids())
  and public.auth_user_role(org_id) in (
    'owner', 'admin', 'manager', 'receptionist', 'professional'
  )
);

create policy "anamneses_update"
on public.anamneses
for update
to authenticated
using (
  org_id in (select public.auth_org_ids())
  and public.auth_user_role(org_id) in (
    'owner', 'admin', 'manager', 'receptionist', 'professional'
  )
)
with check (
  org_id in (select public.auth_org_ids())
  and public.auth_user_role(org_id) in (
    'owner', 'admin', 'manager', 'receptionist', 'professional'
  )
);

create policy "anamneses_delete_pending"
on public.anamneses
for delete
to authenticated
using (
  status = 'pending'
  and org_id in (select public.auth_org_ids())
  and public.auth_user_role(org_id) in (
    'owner', 'admin', 'manager', 'professional'
  )
);

revoke all on table public.anamneses from anon;
grant select, insert, update, delete on table public.anamneses to authenticated;

revoke all on function public.protect_signed_anamnese_evidence()
  from public, anon, authenticated;
