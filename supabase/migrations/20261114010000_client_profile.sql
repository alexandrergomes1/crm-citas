-- O2: perfil da cliente em uma ida ao banco, e as ações do perfil com várias tabelas viram uma função.
-- Encoding: UTF-8
--
-- As três funções são SECURITY INVOKER: rodam com o usuário logado, então a RLS de cada tabela vale
-- exatamente como nas consultas que elas substituem. Nada de regra nova de acesso.
--
-- 1. client_profile: tudo o que a tela do perfil lê (antes ~10 consultas: cliente, agendamentos com
--    serviços, 2 contagens de agendamentos, extrato de saldo + nomes + números de comanda, notas,
--    pacotes, status das fichas, fotos das fichas, fila de mensagens, serviços com retoque).
--    Os limites e a ordem são os mesmos das consultas antigas. As regras (normalizar extrato, montar
--    fotos, retoques) continuam no app, em src/domain.
-- 2. restore_entitlement_session_atomic: devolver uma sessão do pacote (antes 3 passos sem transação:
--    ler, atualizar o pacote, gravar o extrato).
-- 3. update_client_atomic: editar a cliente (antes ler o telefone guardado, atualizar e gravar o
--    consentimento de marketing em 3 idas, sem transação).
-- 4. Auditoria: as duas ações gravam em audit_logs como a própria pessoa (funções INVOKER), então os
--    três pares novos (tabela, operação) entram na lista da política audit_insert_member.

-- ─── 1. Leitura do perfil ─────────────────────────────────────────────────────────────────────
-- p_done_statuses: status que contam como visita (DONE_STATUSES no app).
-- p_with_photos: o app só pede as fotos para quem tem clientes.view_clinical (e a RLS de anamneses
-- também exige isso). Das fichas só sai o caminho das fotos (professional_data.photos), nada clínico.
-- Status das fichas: só para quem tem anamnese.view_status (a mesma regra de list_anamnese_status,
-- que é chamada aqui); sem essa liberação o cartão volta vazio, como antes. Até 100, sem token público.
-- Sem clientes.view: nulo.
-- Cliente de outro estúdio ou inexistente: nulo (a RLS esconde a linha).
create or replace function public.client_profile(
  p_org_id uuid,
  p_client_id uuid,
  p_done_statuses text[],
  p_with_photos boolean default false
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_client jsonb;
  v_anamneses jsonb := '[]'::jsonb;
  v_photos jsonb := '[]'::jsonb;
begin
  if (select auth.uid()) is null then
    raise exception 'Autenticação obrigatória' using errcode = '42501';
  end if;
  -- Sem clientes.view o perfil não existe para a pessoa (o app já confere; o banco também).
  if not public.has_permission(p_org_id, 'clientes.view') then
    return null;
  end if;

  select pg_catalog.to_jsonb(c) into v_client
  from public.clients c
  where c.org_id = p_org_id and c.id = p_client_id;
  if v_client is null then
    return null;
  end if;

  if public.has_permission(p_org_id, 'anamnese.view_status') then
    select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', s.id, 'template_title', s.template_title, 'status', s.status,
        'signed_at', s.signed_at, 'created_at', s.created_at) order by s.created_at desc, s.id), '[]'::jsonb)
    into v_anamneses
    from (
      select * from public.list_anamnese_status(p_org_id, null, p_client_id, null, null) ls
      order by ls.created_at desc, ls.id
      limit 100
    ) s;
  end if;

  if p_with_photos then
    select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', x.id, 'template_title', x.template_title, 'created_at', x.created_at, 'signed_at', x.signed_at,
        'professional_data', pg_catalog.jsonb_build_object('photos', x.photos)) order by x.created_at desc), '[]'::jsonb)
    into v_photos
    from (
      select a.id, a.template_title, a.created_at, a.signed_at, a.professional_data -> 'photos' as photos
      from public.anamneses a
      where a.org_id = p_org_id and a.client_id = p_client_id
      order by a.created_at desc
      limit 100
    ) x
    where pg_catalog.jsonb_typeof(x.photos) = 'array' and pg_catalog.jsonb_array_length(x.photos) > 0;
  end if;

  return pg_catalog.jsonb_build_object(
    'client', v_client,
    'appointments', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(a) || pg_catalog.jsonb_build_object('appointment_items', coalesce((
          select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(i) order by i.created_at, i.id)
          from public.appointment_items i
          where i.appointment_id = a.id and i.org_id = p_org_id), '[]'::jsonb))
        order by a.start_at desc)
      from (
        select ap.* from public.appointments ap
        where ap.org_id = p_org_id and ap.client_id = p_client_id
        order by ap.start_at desc
        limit 30
      ) a), '[]'::jsonb),
    'appointment_count', (
      select pg_catalog.count(*) from public.appointments ap
      where ap.org_id = p_org_id and ap.client_id = p_client_id),
    'visits', (
      select pg_catalog.count(*) from public.appointments ap
      where ap.org_id = p_org_id and ap.client_id = p_client_id and ap.status = any (p_done_statuses)),
    'ledger', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'id', e.id, 'entry_type', e.entry_type, 'amount', e.amount, 'balance_before', e.balance_before,
          'balance_after', e.balance_after, 'source_type', e.source_type, 'source_id', e.source_id,
          'description', e.description, 'created_by', e.created_by, 'created_at', e.created_at,
          'appointment_id', e.appointment_id, 'sale_id', e.sale_id, 'payment_id', e.payment_id,
          'transaction_id', e.transaction_id, 'reversal_of_entry_id', e.reversal_of_entry_id,
          'reversed_by_entry_id', e.reversed_by_entry_id, 'reversed_at', e.reversed_at,
          'reversal_reason', e.reversal_reason,
          'created_by_name', (select p.full_name from public.profiles p
                              where p.org_id = p_org_id and p.user_id = e.created_by limit 1),
          'sale_number', (select s.number from public.sales s where s.org_id = p_org_id and s.id = e.sale_id))
        order by e.created_at desc)
      from (
        select be.* from public.client_balance_entries be
        where be.org_id = p_org_id and be.client_id = p_client_id
        order by be.created_at desc
        limit 30
      ) e), '[]'::jsonb),
    'notes', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(n) order by n.note_date desc, n.created_at desc)
      from public.client_notes n
      where n.org_id = p_org_id and n.client_id = p_client_id and n.deleted_at is null), '[]'::jsonb),
    'credits', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(ce) order by ce.purchased_at desc)
      from public.client_entitlements ce
      where ce.org_id = p_org_id and ce.client_id = p_client_id), '[]'::jsonb),
    'anamneses', v_anamneses,
    'photo_sources', v_photos,
    'messages', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'id', m.id, 'channel', m.channel, 'status', m.status, 'message_subject', m.message_subject,
          'message_body', m.message_body, 'created_at', m.created_at) order by m.created_at desc)
      from (
        select q.* from public.marketing_message_queue q
        where q.org_id = p_org_id and q.client_id = p_client_id
        order by q.created_at desc
        limit 30
      ) m), '[]'::jsonb),
    'message_count', (
      select pg_catalog.count(*) from public.marketing_message_queue q
      where q.org_id = p_org_id and q.client_id = p_client_id),
    'retouch_rules', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'id', sv.id, 'name', sv.name, 'retouch_included_days', sv.retouch_included_days) order by sv.name, sv.id)
      from public.services sv
      where sv.org_id = p_org_id and sv.retouch_included_days is not null), '[]'::jsonb)
  );
end;
$$;
revoke all on function public.client_profile(uuid, uuid, text[], boolean) from public, anon;
grant execute on function public.client_profile(uuid, uuid, text[], boolean) to authenticated;

-- ─── 2. Devolver uma sessão do pacote ─────────────────────────────────────────────────────────
-- Regra: comanda.operate; precisa ter sessão usada; só pacote ativo ou esgotado volta a "active"
-- (cancelado ou vencido é recusado). Numa transação só, com a linha travada (dois cliques não
-- devolvem duas vezes a mesma sessão). Extrato e auditoria guardam quem devolveu.
-- p_description: até 200 caracteres (espaços das pontas tirados); vazio vira nulo.
create or replace function public.restore_entitlement_session_atomic(
  p_org_id uuid,
  p_entitlement_id uuid,
  p_description text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_client uuid;
  v_used integer;
  v_status text;
  v_description text := nullif(pg_catalog.btrim(coalesce(p_description, '')), '');
begin
  if v_uid is null then
    raise exception 'Autenticação obrigatória' using errcode = '42501';
  end if;
  if not public.has_permission(p_org_id, 'comanda.operate') then
    raise exception 'Sem permissão para restaurar sessão' using errcode = '42501';
  end if;
  if pg_catalog.char_length(v_description) > 200 then
    raise exception 'A descrição deve ter no máximo 200 caracteres' using errcode = '22023';
  end if;

  select e.client_id, e.used_sessions, e.status into v_client, v_used, v_status
  from public.client_entitlements e
  where e.id = p_entitlement_id and e.org_id = p_org_id
  for update;
  if not found then
    raise exception 'Pacote não encontrado' using errcode = 'P0002';
  end if;
  if v_status in ('cancelled', 'expired') then
    raise exception 'Pacote cancelado ou vencido: não dá para restaurar sessão' using errcode = 'P0001';
  end if;
  if v_used <= 0 then
    raise exception 'Nenhuma sessão para restaurar' using errcode = 'P0001';
  end if;

  update public.client_entitlements
  set used_sessions = v_used - 1, status = 'active'
  where id = p_entitlement_id and org_id = p_org_id;

  insert into public.client_entitlement_entries (
    org_id, entitlement_id, client_id, action, sessions_delta, sessions_before, sessions_after, description, created_by
  ) values (
    p_org_id, p_entitlement_id, v_client, 'restore', 1, v_used, v_used - 1, v_description, v_uid
  );

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (
    p_org_id, v_uid, 'client_entitlements', 'ENTITLEMENT_SESSION_RESTORED', p_entitlement_id,
    pg_catalog.jsonb_build_object('used_sessions', v_used, 'status', v_status),
    pg_catalog.jsonb_build_object('used_sessions', v_used - 1, 'status', 'active', 'description', v_description)
  );

  return pg_catalog.jsonb_build_object('used_sessions', v_used - 1);
end;
$$;
revoke all on function public.restore_entitlement_session_atomic(uuid, uuid, text) from public, anon;
grant execute on function public.restore_entitlement_session_atomic(uuid, uuid, text) to authenticated;

-- ─── 3. Editar a cliente ──────────────────────────────────────────────────────────────────────
-- p_changes: campos do formulário (só as colunas da lista abaixo são usadas; o resto, como org_id,
--   id, saldo e mesclagem, é ignorado). Campo ausente fica como está; presente com nulo apaga.
--   p_changes.phone é o telefone enviado, só para comparar com o guardado.
-- Telefone: se o enviado tem os mesmos dígitos do guardado (com ou sem o DDI guardado), o texto e
--   o DDI guardados ficam como estão (espelho de isSameStoredPhone em src/domain/client-identity.ts).
--   Senão vale o telefone já validado pelo app (p_checked_phone / p_checked_country); sem ele
--   (número novo que não passou na regra do país) nada é gravado e volta {ok:false, reason:'phone_invalid'}.
-- p_marketing_consent: nulo não mexe; sim/não grava os canais de p_marketing_channels. Só os canais
--   que mudam são gravados (não: opted_out_at = agora; quem mudou em updated_by). Quem não pode mexer
--   no consentimento (política de client_marketing_preferences: dona, administração, gestão e recepção)
--   e tenta mudar recebe {ok:false, reason:'marketing_forbidden'} antes de qualquer gravação.
-- Auditoria: CLIENT_UPDATED só com os nomes das colunas alteradas (sem valores: dado pessoal) e
--   MARKETING_CONSENT_SET com o sim/não e os canais.
-- Tudo numa transação: dados e consentimento entram juntos ou nenhum entra.
create or replace function public.update_client_atomic(
  p_org_id uuid,
  p_client_id uuid,
  p_changes jsonb,
  p_checked_phone text,
  p_checked_country text,
  p_marketing_consent boolean default null,
  p_marketing_channels text[] default '{}'
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_columns constant text[] := array[
    'full_name', 'phone', 'phone_country_code', 'document_type', 'document_number', 'cpf', 'tags', 'email',
    'birth_date', 'gender', 'city', 'state_region', 'source', 'alert_text', 'notes', 'fixed_notes',
    'image_use_consent', 'alert_type', 'contact_pref', 'status'];
  v_old public.clients%rowtype;
  v_new public.clients%rowtype;
  v_changes jsonb;
  v_changed text[];
  v_channels text[];
  v_sent text;
  v_phone text;
  v_country text;
begin
  if v_uid is null then
    raise exception 'Autenticação obrigatória' using errcode = '42501';
  end if;
  if not public.has_permission(p_org_id, 'clientes.manage') then
    raise exception 'Sem permissão para atualizar clientes' using errcode = '42501';
  end if;

  select c.* into v_old
  from public.clients c
  where c.id = p_client_id and c.org_id = p_org_id
  for update;
  if not found then
    raise exception 'Cliente não encontrada' using errcode = 'P0002';
  end if;

  v_sent := pg_catalog.regexp_replace(coalesce(p_changes ->> 'phone', ''), '[^0-9]', '', 'g');
  if v_sent <> '' and v_old.phone is not null and (
       v_sent = pg_catalog.regexp_replace(v_old.phone, '[^0-9]', '', 'g')
    or v_sent = pg_catalog.regexp_replace(coalesce(v_old.phone_country_code, '') || v_old.phone, '[^0-9]', '', 'g')) then
    v_phone := v_old.phone;
    v_country := v_old.phone_country_code;
  elsif p_checked_phone is null then
    return pg_catalog.jsonb_build_object('ok', false, 'reason', 'phone_invalid');
  else
    v_phone := p_checked_phone;
    v_country := p_checked_country;
  end if;

  -- Canais cujo consentimento muda de fato (canal ainda sem linha conta como mudança, como o upsert de antes).
  if p_marketing_consent is not null then
    select coalesce(pg_catalog.array_agg(ch order by ch), '{}'::text[]) into v_channels
    from (select distinct ch from pg_catalog.unnest(coalesce(p_marketing_channels, '{}'::text[])) as ch) u
    where not exists (
      select 1 from public.client_marketing_preferences m
      where m.org_id = p_org_id and m.client_id = p_client_id and m.channel = u.ch
        and m.marketing_allowed = p_marketing_consent);
    if pg_catalog.cardinality(v_channels) > 0
       and coalesce(public.auth_user_role(p_org_id) not in ('owner', 'admin', 'manager', 'receptionist'), true) then
      return pg_catalog.jsonb_build_object('ok', false, 'reason', 'marketing_forbidden');
    end if;
  end if;

  select coalesce(pg_catalog.jsonb_object_agg(k, v), '{}'::jsonb) into v_changes
  from pg_catalog.jsonb_each(coalesce(p_changes, '{}'::jsonb)) as ch(k, v)
  where k = any (v_columns) and k not in ('phone', 'phone_country_code');
  v_changes := v_changes || pg_catalog.jsonb_build_object('phone', v_phone, 'phone_country_code', v_country);
  v_new := pg_catalog.jsonb_populate_record(v_old, v_changes);

  select coalesce(pg_catalog.array_agg(n.key order by n.key), '{}'::text[]) into v_changed
  from pg_catalog.jsonb_each(pg_catalog.to_jsonb(v_new)) as n(key, value)
  where n.key = any (v_columns) and n.value is distinct from (pg_catalog.to_jsonb(v_old) -> n.key);

  if pg_catalog.cardinality(v_changed) > 0 then
    update public.clients c set
      full_name = v_new.full_name,
      phone = v_new.phone,
      phone_country_code = v_new.phone_country_code,
      document_type = v_new.document_type,
      document_number = v_new.document_number,
      cpf = v_new.cpf,
      tags = v_new.tags,
      email = v_new.email,
      birth_date = v_new.birth_date,
      gender = v_new.gender,
      city = v_new.city,
      state_region = v_new.state_region,
      source = v_new.source,
      alert_text = v_new.alert_text,
      notes = v_new.notes,
      fixed_notes = v_new.fixed_notes,
      image_use_consent = v_new.image_use_consent,
      alert_type = v_new.alert_type,
      contact_pref = v_new.contact_pref,
      status = v_new.status
    where c.id = p_client_id and c.org_id = p_org_id;

    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
    values (p_org_id, v_uid, 'clients', 'CLIENT_UPDATED', p_client_id, null,
            pg_catalog.jsonb_build_object('columns', pg_catalog.to_jsonb(v_changed)));
  end if;

  if pg_catalog.cardinality(coalesce(v_channels, '{}'::text[])) > 0 then
    insert into public.client_marketing_preferences (
      org_id, client_id, channel, marketing_allowed, opted_out_at, source, updated_by)
    select p_org_id, p_client_id, ch, p_marketing_consent,
           case when p_marketing_consent then null else pg_catalog.now() end, 'internal', v_uid
    from pg_catalog.unnest(v_channels) as ch
    on conflict (org_id, client_id, channel) do update
      set marketing_allowed = excluded.marketing_allowed,
          opted_out_at = excluded.opted_out_at,
          source = excluded.source,
          updated_by = excluded.updated_by;

    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
    values (p_org_id, v_uid, 'clients', 'MARKETING_CONSENT_SET', p_client_id, null,
            pg_catalog.jsonb_build_object('marketing_allowed', p_marketing_consent, 'channels', pg_catalog.to_jsonb(v_channels)));
  end if;

  return pg_catalog.jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.update_client_atomic(uuid, uuid, jsonb, text, text, boolean, text[]) from public, anon;
grant execute on function public.update_client_atomic(uuid, uuid, jsonb, text, text, boolean, text[]) to authenticated;

-- ─── 4. Auditoria gravada pelas funções acima (INVOKER) ───────────────────────────────────────
-- Mesma política de 20261029280000 com três pares novos no fim da lista.
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
        ('client_entitlements', 'ENTITLEMENT_SESSION_RESTORED')
      )
    )
  );
