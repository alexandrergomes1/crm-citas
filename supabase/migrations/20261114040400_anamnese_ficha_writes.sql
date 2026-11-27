-- Anamnese (porte): ações da ficha em UMA ida ao banco, com permissão, alcance e auditoria no banco.
-- Encoding: UTF-8
set client_encoding = 'UTF8';
--
-- A tabela anamneses está fechada para a API (20261114040000): as funções que leem ou gravam a ficha são
-- SECURITY DEFINER e conferem, nesta ordem, login, permissão e alcance (anamnese_in_scope) antes de tocar a linha.
-- Gravar na ficha exige preencher E leitura clínica (antes a RLS de leitura já exigia: sem ler, não há o que editar).
-- Funções que já existiam, recriadas com o alcance: 20261114040500.
--   anamnese_create_link        (recriada, INVOKER: só chama funções DEFINER) link só para ficha pendente e no prazo
--   anamnese_delete_pending     (recriada) alcance + trava da linha; devolve só fotos desta ficha (para o servidor
--                               apagar no Storage)
--   anamnese_save_professional  Ficha Profissional (antes: ler + nota + dados, 3 idas); registro, extras e fotos
--                               conferidos no resultado final
--   anamnese_photo_change       antes de o servidor enviar/apagar foto no Storage: alcance, ficha aberta, caminho
-- Auditoria (regra de 14/11): gatilho AFTER UPDATE/DELETE em anamneses (SECURITY DEFINER, sem execução para
-- ninguém) e anamnese_photo_change ao apagar. Foto nova só é registrada quando entra na ficha gravada (depois do
-- envio ter dado certo), pelo gatilho.

-- Recriada (20261114020100): o link só volta para ficha pendente e no prazo (atendimento que já tinha ficha
-- assinada devolve a ficha sem link).
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
  if pg_catalog.char_length(coalesce(p_client_name, '')) > 200 then
    raise exception 'Nome grande demais' using errcode = '22023';
  end if;
  v_ficha := public.create_anamnese_atomic(p_org_id, p_template_id, p_client_id, p_client_name, p_appointment_id, p_requires_professional);
  v_expires := v_ficha.token_expires_at;
  if v_ficha.status = 'pending' then
    if p_link_days is not null then
      v_expires := public.set_anamnese_link_validity(p_org_id, v_ficha.id, p_link_days);
    end if;
    if p_send_channel is not null then
      perform public.log_anamnese_send(p_org_id, v_ficha.id, p_send_channel);
    end if;
  end if;
  return pg_catalog.jsonb_build_object(
    'id', v_ficha.id,
    'token', case when v_ficha.status = 'pending' and v_expires >= pg_catalog.now() then v_ficha.public_token end,
    'expires_at', v_expires);
end;
$$;

-- Recriada (20261114020100): alcance e trava da linha. Auditoria (ANAMNESE_PENDING_DELETED): gatilho anamneses_audit.
-- Devolve só caminhos de foto desta ficha (<estúdio>/<ficha>/...): o servidor apaga esses arquivos com a chave de
-- serviço, então um caminho de outra ficha gravado na linha nunca vira exclusão.
create or replace function public.anamnese_delete_pending(p_org_id uuid, p_anamnese_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
  v_data jsonb;
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'anamnese.fill_professional')
     or not public.has_permission(p_org_id, 'clientes.view_clinical') then
    raise exception 'Sem permissão para revogar fichas' using errcode = '42501';
  end if;
  if not public.anamnese_in_scope(p_org_id, p_anamnese_id) then
    raise exception 'Ficha de anamnese não encontrada' using errcode = 'P0002';
  end if;
  select a.status, a.professional_data into v_status, v_data
  from public.anamneses a where a.org_id = p_org_id and a.id = p_anamnese_id
  for update;
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
  return coalesce((
    select pg_catalog.jsonb_agg(p)
    from pg_catalog.jsonb_array_elements_text(
      case when pg_catalog.jsonb_typeof(v_data -> 'photos') = 'array' then v_data -> 'photos' else '[]'::jsonb end) p
    where pg_catalog.left(p, pg_catalog.length(p_org_id::text || '/' || p_anamnese_id::text || '/'))
          = p_org_id::text || '/' || p_anamnese_id::text || '/'), '[]'::jsonb);
end;
$$;
revoke all on function public.anamnese_delete_pending(uuid, uuid) from public, anon;
grant execute on function public.anamnese_delete_pending(uuid, uuid) to authenticated;

-- ─── Ficha Profissional ────────────────────────────────────────────────────────────────────────
-- Rascunho ou conclusão. p_record: só as 7 chaves do registro V25. p_extras: sessões (micropigmentação, laser) e
-- fotos; chave fora dessa lista só se vier igual ao que já está gravado (fichas antigas). O resultado final
-- (gravado || extras || registro) é conferido: fotos só desta ficha (<estúdio>/<ficha>/<uuid>.<ext>, até 50) e
-- tamanho total. Nota até 5000. Auditoria: gatilho.
create or replace function public.anamnese_save_professional(
  p_org_id uuid,
  p_anamnese_id uuid,
  p_record jsonb,
  p_extras jsonb,
  p_note text,
  p_complete boolean
)
returns timestamptz
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_row public.anamneses;
  v_note text := nullif(pg_catalog.btrim(coalesce(p_note, '')), '');
  v_data jsonb;
  v_key text;
  v_photo text;
  v_prefix text := p_org_id::text || '/' || p_anamnese_id::text || '/';
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'anamnese.fill_professional')
     or not public.has_permission(p_org_id, 'clientes.view_clinical') then
    raise exception 'Sem permissão para preencher a Ficha Profissional' using errcode = '42501';
  end if;
  if pg_catalog.jsonb_typeof(p_record) is distinct from 'object' or pg_catalog.jsonb_typeof(p_extras) is distinct from 'object'
     or pg_catalog.char_length(coalesce(p_note, '')) > 5000 or p_complete is null
     or exists (select 1 from pg_catalog.jsonb_object_keys(p_record) k
                where k not in ('skin_type', 'phototype', 'conditions', 'product', 'batch', 'action_time', 'checklist')) then
    raise exception 'Dados da ficha inválidos' using errcode = '22023';
  end if;
  if not public.anamnese_in_scope(p_org_id, p_anamnese_id) then
    raise exception 'Ficha de anamnese não encontrada' using errcode = 'P0002';
  end if;

  select a.* into v_row from public.anamneses a
  where a.org_id = p_org_id and a.id = p_anamnese_id
  for update;
  if not found then
    raise exception 'Ficha de anamnese não encontrada' using errcode = 'P0002';
  end if;
  if v_row.professional_completed_at is not null then
    raise exception 'A parte profissional está concluída. Reabra antes de editar.' using errcode = '23514';
  end if;
  if not v_row.requires_professional
     and coalesce(v_row.template_snapshot -> 'professional_form', 'null'::jsonb) = 'null'::jsonb then
    raise exception 'Esta anamnese não possui parte profissional habilitada' using errcode = '23514';
  end if;

  for v_key in select pg_catalog.jsonb_object_keys(p_extras) loop
    if v_key not in ('photos', 'skinCondition', 's1_brows', 's2_brows', 's1_lips', 's2_lips', 'procedure', 'sessions')
       and (p_extras -> v_key) is distinct from (v_row.professional_data -> v_key) then
      raise exception 'Dados da ficha inválidos' using errcode = '22023';
    end if;
  end loop;

  v_data := coalesce(v_row.professional_data, '{}'::jsonb) || p_extras || p_record;
  if pg_catalog.octet_length(v_data::text) > 250000 then
    raise exception 'Dados da ficha grandes demais' using errcode = '22023';
  end if;
  if v_data ? 'photos' then
    if pg_catalog.jsonb_typeof(v_data -> 'photos') <> 'array' or pg_catalog.jsonb_array_length(v_data -> 'photos') > 50 then
      raise exception 'Fotos inválidas' using errcode = '22023';
    end if;
    for v_photo in select pg_catalog.jsonb_array_elements_text(v_data -> 'photos') loop
      if pg_catalog.left(v_photo, pg_catalog.length(v_prefix)) <> v_prefix
         or pg_catalog.substr(v_photo, pg_catalog.length(v_prefix) + 1) !~ '^[0-9a-f-]{36}\.(jpg|png|webp|heic)$' then
        raise exception 'Fotos inválidas' using errcode = '22023';
      end if;
    end loop;
  end if;

  update public.anamneses set
    professional_data = v_data,
    professional_notes = v_note,
    professional_completed_at = case when p_complete then pg_catalog.now() end,
    updated_at = pg_catalog.now()
  where org_id = p_org_id and id = p_anamnese_id;
  return pg_catalog.now();
end;
$$;
revoke all on function public.anamnese_save_professional(uuid, uuid, jsonb, jsonb, text, boolean) from public, anon;
grant execute on function public.anamnese_save_professional(uuid, uuid, jsonb, jsonb, text, boolean) to authenticated;

-- ─── Fotos: antes de o servidor enviar ou apagar no Storage ─────────────────────────────────────
-- Confere preencher + alcance + Ficha Profissional aberta + caminho desta ficha. Ao apagar, grava
-- PROFESSIONAL_PHOTO_REMOVED (só o caminho). Ao enviar, não grava nada: a foto entra na auditoria quando entra na
-- ficha (gatilho), ou seja, só se o envio deu certo e a ficha foi salva com ela.
create or replace function public.anamnese_photo_change(p_org_id uuid, p_anamnese_id uuid, p_path text, p_action text)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_prefix text := p_org_id::text || '/' || p_anamnese_id::text || '/';
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'anamnese.fill_professional')
     or not public.has_permission(p_org_id, 'clientes.view_clinical') then
    raise exception 'Sem permissão' using errcode = '42501';
  end if;
  if p_action is null or p_action not in ('add', 'remove')
     or pg_catalog.left(coalesce(p_path, ''), pg_catalog.length(v_prefix)) <> v_prefix
     or pg_catalog.substr(p_path, pg_catalog.length(v_prefix) + 1) !~ '^[0-9a-f-]{36}\.(jpg|png|webp|heic)$' then
    raise exception 'Caminho inválido' using errcode = '22023';
  end if;
  perform 1 from public.anamneses a
  where a.org_id = p_org_id and a.id = p_anamnese_id
    and public.anamnese_row_in_scope(a.org_id, a.appointment_id, a.created_by)
  for update;
  if not found then
    raise exception 'Ficha de anamnese não encontrada' using errcode = 'P0002';
  end if;
  if exists (select 1 from public.anamneses a where a.id = p_anamnese_id and a.professional_completed_at is not null) then
    raise exception 'A parte profissional está concluída. Reabra antes de editar.' using errcode = '23514';
  end if;
  if p_action = 'remove' then
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
    values (p_org_id, (select auth.uid()), 'anamneses', 'PROFESSIONAL_PHOTO_REMOVED', p_anamnese_id,
            pg_catalog.jsonb_build_object('path', p_path));
  end if;
end;
$$;
revoke all on function public.anamnese_photo_change(uuid, uuid, text, text) from public, anon;
grant execute on function public.anamnese_photo_change(uuid, uuid, text, text) to authenticated;

-- ─── Auditoria da ficha (gatilho) ──────────────────────────────────────────────────────────────────
-- Grava auth.uid(), a operação e só sinais (tem dados, concluída, tamanho da nota, nova validade, caminho da foto
-- nova). Nunca respostas, texto da nota ou dados da profissional. Validade ajustada na mesma transação em que a
-- ficha nasceu (gerar link com prazo escolhido) não conta como renovação: created_at = now() da transação.
-- Exclusão (só ficha pendente chega aqui; a assinada é barrada antes): ANAMNESE_PENDING_DELETED.
create or replace function public.anamneses_audit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if tg_op = 'DELETE' then
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data)
    values (old.org_id, v_uid, 'anamneses', 'ANAMNESE_PENDING_DELETED', old.id,
            pg_catalog.jsonb_build_object('status', old.status, 'client_id', old.client_id,
              'appointment_id', old.appointment_id, 'template_title', old.template_title));
    return null;
  end if;

  if new.professional_completed_at is distinct from old.professional_completed_at then
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
    values (new.org_id, v_uid, 'anamneses',
            case when new.professional_completed_at is null then 'PROFESSIONAL_REOPENED' else 'PROFESSIONAL_COMPLETED' end,
            new.id,
            pg_catalog.jsonb_build_object('completed', old.professional_completed_at is not null),
            pg_catalog.jsonb_build_object('completed', new.professional_completed_at is not null,
              'has_data', coalesce(new.professional_data, '{}'::jsonb) <> '{}'::jsonb));
  elsif new.professional_data is distinct from old.professional_data then
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
    values (new.org_id, v_uid, 'anamneses', 'PROFESSIONAL_DRAFT_SAVED', new.id,
            pg_catalog.jsonb_build_object('has_data', coalesce(old.professional_data, '{}'::jsonb) <> '{}'::jsonb),
            pg_catalog.jsonb_build_object('has_data', coalesce(new.professional_data, '{}'::jsonb) <> '{}'::jsonb));
  end if;

  -- Fotos que passaram a constar da ficha (uma linha por caminho).
  if new.professional_data -> 'photos' is distinct from old.professional_data -> 'photos'
     and pg_catalog.jsonb_typeof(new.professional_data -> 'photos') = 'array' then
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
    select new.org_id, v_uid, 'anamneses', 'PROFESSIONAL_PHOTO_ADDED', new.id, pg_catalog.jsonb_build_object('path', p)
    from pg_catalog.jsonb_array_elements_text(new.professional_data -> 'photos') p
    where not coalesce(old.professional_data -> 'photos', '[]'::jsonb) @> pg_catalog.jsonb_build_array(p);
  end if;

  if new.professional_notes is distinct from old.professional_notes then
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
    values (new.org_id, v_uid, 'anamneses', 'PROFESSIONAL_NOTES_UPDATED', new.id,
            pg_catalog.jsonb_build_object('has_note', new.professional_notes is not null,
              'length', pg_catalog.char_length(coalesce(new.professional_notes, ''))));
  end if;

  if new.token_expires_at is distinct from old.token_expires_at and new.status = 'pending'
     and old.created_at <> pg_catalog.now() then
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
    values (new.org_id, v_uid, 'anamneses', 'ANAMNESE_LINK_RENEWED', new.id,
            pg_catalog.jsonb_build_object('expires_at', old.token_expires_at),
            pg_catalog.jsonb_build_object('expires_at', new.token_expires_at));
  end if;
  return null;
end;
$$;
revoke all on function public.anamneses_audit() from public, anon, authenticated;

drop trigger if exists trg_anamneses_audit on public.anamneses;
create trigger trg_anamneses_audit
  after update of professional_completed_at, professional_data, professional_notes, token_expires_at or delete
  on public.anamneses
  for each row execute function public.anamneses_audit();

-- Recriada (20261030300000) sem o registro de exclusão (agora no gatilho DEFINER acima): continua só barrando
-- exclusão e alteração da evidência de ficha assinada.
create or replace function public.protect_signed_anamnese_evidence()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_ignored text[] := array['professional_notes', 'professional_data', 'professional_completed_at', 'updated_at'];
begin
  if old.status = 'signed' then
    if tg_op = 'DELETE' then
      raise exception 'Fichas assinadas nao podem ser excluidas' using errcode = '23514';
    end if;
    if current_user not in ('authenticated', 'anon')
       and coalesce(pg_catalog.current_setting('app.client_merge', true), '') = 'on' then
      v_ignored := v_ignored || array['client_id'];
    end if;
    if (pg_catalog.to_jsonb(new) - v_ignored) is distinct from (pg_catalog.to_jsonb(old) - v_ignored) then
      raise exception 'Evidencias de uma ficha assinada sao imutaveis' using errcode = '23514';
    end if;
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;
