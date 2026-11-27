-- ============================================================
-- Corrige o texto de duas funções que chegaram ao banco com acentos
-- corrompidos ("ConcluÃ­do" em vez de "Concluído").
--
-- Efeito em produção antes desta correção: a agenda não conseguia mudar um
-- atendimento de "Iniciado" para "Concluído", nem marcar "Ausência", porque a
-- regra de transição comparava com o texto corrompido. As mensagens de erro das
-- notas da cliente também apareciam com caracteres estranhos.
--
-- O conteúdo é o mesmo de 20260619225200_agenda_status_notes_core_02.sql,
-- agora aplicado com o arquivo lido como UTF-8. Não altera dados.
-- Encoding: UTF-8
-- ============================================================
set client_encoding = 'UTF8';

create or replace function public.create_client_note_atomic(
  p_org_id uuid,
  p_client_id uuid,
  p_appointment_id uuid,
  p_note_type text,
  p_body text,
  p_note_date date default current_date
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_note_id uuid;
  v_author_id uuid;
  v_author_name text;
begin
  if not exists (
    select 1 from public.user_roles ur
    where ur.org_id = p_org_id
      and ur.user_id = auth.uid()
      and ur.active
      and ur.role::text in ('owner', 'admin', 'manager', 'receptionist', 'professional')
  ) then
    raise exception 'Sem permissão para criar notas';
  end if;

  if p_note_type not in ('client', 'appointment', 'fixed') then
    raise exception 'Tipo de nota inválido';
  end if;
  if length(btrim(coalesce(p_body, ''))) not between 1 and 5000 then
    raise exception 'A nota deve ter entre 1 e 5000 caracteres';
  end if;
  if not exists (select 1 from public.clients c where c.org_id = p_org_id and c.id = p_client_id) then
    raise exception 'Cliente não pertence à organização';
  end if;
  if p_note_type = 'appointment' and p_appointment_id is null then
    raise exception 'Atendimento obrigatório para nota de atendimento';
  end if;
  if p_appointment_id is not null and not exists (
    select 1 from public.appointments a
    where a.org_id = p_org_id and a.client_id = p_client_id and a.id = p_appointment_id
  ) then
    raise exception 'Atendimento não pertence ao cliente ou à organização';
  end if;

  select p.id, p.full_name into v_author_id, v_author_name
  from public.profiles p
  where p.org_id = p_org_id and p.user_id = auth.uid()
  order by p.created_at
  limit 1;

  if v_author_id is null then
    raise exception 'Perfil do autor não encontrado na organização';
  end if;

  insert into public.client_notes (
    org_id, client_id, appointment_id, author_id, author_name, content, note_type, note_date
  ) values (
    p_org_id, p_client_id, p_appointment_id, v_author_id,
    coalesce(nullif(btrim(v_author_name), ''), 'Utilizador'), btrim(p_body), p_note_type,
    coalesce(p_note_date, current_date)
  ) returning id into v_note_id;

  insert into public.audit_logs (
    org_id, user_id, table_name, operation, record_id, new_data
  ) values (
    p_org_id, auth.uid(), 'client_notes', 'CLIENT_NOTE_CREATED', v_note_id,
    pg_catalog.jsonb_build_object(
      'client_id', p_client_id,
      'appointment_id', p_appointment_id,
      'note_type', p_note_type,
      'note_date', coalesce(p_note_date, current_date)
    )
  );

  return v_note_id;
end;
$$;

revoke all on function public.create_client_note_atomic(uuid, uuid, uuid, text, text, date) from public;
revoke all on function public.create_client_note_atomic(uuid, uuid, uuid, text, text, date) from anon;
grant execute on function public.create_client_note_atomic(uuid, uuid, uuid, text, text, date) to authenticated;

create or replace function public.agenda_status_transition_allowed(p_current text, p_next text)
returns boolean
language sql
immutable
set search_path = public, pg_temp
as $$
  select p_current = p_next or case p_current
    when 'Reservado' then p_next in ('Confirmado', 'Ausência', 'Cancelado')
    when 'Agendado' then p_next in ('Confirmado', 'Iniciado', 'Ausência', 'Cancelado')
    when 'Confirmado' then p_next in ('Iniciado', 'Ausência', 'Cancelado')
    when 'Iniciado' then p_next in ('Concluído', 'Cancelado')
    when 'Concluído' then p_next in ('Pago Parcial', 'Pago')
    when 'Pago Parcial' then p_next = 'Pago'
    else false
  end;
$$;

-- Falha a migration se o texto ainda estiver corrompido (ex.: cliente sem UTF-8).
do $$
begin
  if not public.agenda_status_transition_allowed('Iniciado', 'Concluído')
     or not public.agenda_status_transition_allowed('Agendado', 'Ausência') then
    raise exception 'Transições de status continuam com acentos corrompidos';
  end if;
end $$;
