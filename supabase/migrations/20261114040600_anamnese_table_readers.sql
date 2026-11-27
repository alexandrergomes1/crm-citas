-- Anamnese (porte): o que fora do módulo lia a tabela anamneses direto (agora fechada para a API, 20261114040000).
-- Encoding: UTF-8
set client_encoding = 'UTF8';
--
-- 1. anamnese_exists_for (DEFINER): só "existe ficha ligada?" para um agendamento ou serviço do estúdio de quem
--    chama. Usada por agenda_change_client (a recepção não lê fichas, mas precisa ser barrada ao trocar a cliente
--    de um atendimento com ficha) e por catalog_delete_item (serviço citado em ficha é arquivado, não apagado).
-- 2. anamnese_client_photo_count (DEFINER): quantas fotos a cliente tem, para o número da seção Fotos do perfil;
--    leitura clínica + alcance, só caminhos da própria ficha. As fotos em si saem por anamnese_client_photos.
-- 3. agenda_change_client (20261114020100), catalog_delete_item (20261114030100) e client_profile (20261114010000)
--    recriadas iguais à versão vigente, trocando só a leitura direta pela função acima. client_profile devolve
--    photo_count no lugar de photo_sources (os caminhos não saem mais junto do perfil).

create or replace function public.anamnese_exists_for(p_org_id uuid, p_appointment_id uuid, p_service_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_org_id in (select public.auth_org_ids())
     and (p_appointment_id is not null or p_service_id is not null)
     and exists (
       select 1 from public.anamneses a
       where a.org_id = p_org_id
         and (p_appointment_id is null or a.appointment_id = p_appointment_id)
         and (p_service_id is null or a.source_service_id = p_service_id));
$$;
revoke all on function public.anamnese_exists_for(uuid, uuid, uuid) from public, anon;
grant execute on function public.anamnese_exists_for(uuid, uuid, uuid) to authenticated;

create or replace function public.anamnese_client_photo_count(p_org_id uuid, p_client_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select case when (select auth.uid()) is null or not public.has_permission(p_org_id, 'clientes.view_clinical') then 0
  else coalesce((
    select pg_catalog.count(*)::integer
    from public.anamneses a
    cross join lateral pg_catalog.jsonb_array_elements_text(
      case when pg_catalog.jsonb_typeof(a.professional_data -> 'photos') = 'array' then a.professional_data -> 'photos' else '[]'::jsonb end) p
    where a.org_id = p_org_id and a.client_id = p_client_id
      and public.anamnese_row_in_scope(a.org_id, a.appointment_id, a.created_by)
      and p like a.org_id::text || '/' || a.id::text || '/%'), 0) end;
$$;
revoke all on function public.anamnese_client_photo_count(uuid, uuid) from public, anon;
grant execute on function public.anamnese_client_photo_count(uuid, uuid) to authenticated;

CREATE OR REPLACE FUNCTION public.agenda_change_client(p_org_id uuid, p_appointment_id uuid, p_client_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $$
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
  if public.anamnese_exists_for(p_org_id, p_appointment_id, null) then
    raise exception 'Este agendamento tem ficha ligada. Para trocar a cliente, cancele e crie outro agendamento.' using errcode = 'P0001';
  end if;
  update public.appointments set client_id = p_client_id, client_name = v_name
  where id = p_appointment_id and org_id = p_org_id;
  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (p_org_id, (select auth.uid()), 'appointments', 'APPOINTMENT_CLIENT_CHANGED', p_appointment_id,
    pg_catalog.jsonb_build_object('client_id', v_old), pg_catalog.jsonb_build_object('client_id', p_client_id));
end;
$$;

CREATE OR REPLACE FUNCTION public.catalog_delete_item(p_org_id uuid, p_kind text, p_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO ''
AS $$
declare
  v_name text;
  v_where text;
  v_refs boolean;
begin
  if not public.has_permission(p_org_id, 'catalogo.manage') then
    raise exception 'Sem permissão para gerenciar o catálogo.' using errcode = '42501';
  end if;
  if p_kind not in ('service', 'product') then
    raise exception 'Tipo de item inválido.' using errcode = '22023';
  end if;

  if p_kind = 'service' then
    select s.name into v_name from public.services s
    where s.id = p_id and s.org_id = p_org_id for update;
    if not found then raise exception 'Serviço não encontrado.' using errcode = 'P0002'; end if;

    select b.name into v_where
    from public.service_bundle_items i
    join public.service_bundles b on b.id = i.bundle_id and b.org_id = i.org_id
    where i.org_id = p_org_id and i.service_id = p_id and b.active and b.archived_at is null
    order by b.name limit 1;
    if found then
      raise exception 'Está no combo "%": tire de lá antes.', v_where using errcode = '22023';
    end if;
    select k.name into v_where
    from public.package_services i
    join public.service_packages k on k.id = i.package_id and k.org_id = i.org_id
    where i.org_id = p_org_id and i.service_id = p_id and k.active
    order by k.name limit 1;
    if found then
      raise exception 'Está no pacote "%": tire de lá antes.', v_where using errcode = '22023';
    end if;
    -- Plano de assinatura: os serviços incluídos ficam num jsonb (sem chave estrangeira), então a conferência é pelo conteúdo.
    select pl.name into v_where
    from public.subscription_plans pl
    where pl.org_id = p_org_id and pl.active
      and pl.eligible_services @> pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('service_id', p_id::text))
    order by pl.name limit 1;
    if found then
      raise exception 'Está no plano "%": tire de lá antes.', v_where using errcode = '22023';
    end if;

    v_refs := exists (select 1 from public.appointment_items i where i.org_id = p_org_id and i.type = 'service' and i.ref_id = p_id)
      or exists (select 1 from public.sale_items i where i.org_id = p_org_id and pg_catalog.lower(i.item_type) = 'service' and i.item_id = p_id)
      or exists (select 1 from public.package_services i where i.org_id = p_org_id and i.service_id = p_id)
      or exists (select 1 from public.service_bundle_items i where i.org_id = p_org_id and i.service_id = p_id)
      or exists (select 1 from public.agenda_waitlist i where i.org_id = p_org_id and i.service_id = p_id)
      or public.anamnese_exists_for(p_org_id, null, p_id)
      or exists (select 1 from public.subscription_plans pl where pl.org_id = p_org_id
                 and pl.eligible_services @> pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('service_id', p_id::text)));
    if v_refs then
      update public.services set active = false where id = p_id and org_id = p_org_id;
      return 'archived';
    end if;
    delete from public.services where id = p_id and org_id = p_org_id;
    return 'deleted';
  end if;

  perform 1 from public.products s where s.id = p_id and s.org_id = p_org_id for update;
  if not found then raise exception 'Produto não encontrado.' using errcode = 'P0002'; end if;
  v_refs := exists (select 1 from public.sale_items i where i.org_id = p_org_id and pg_catalog.lower(i.item_type) = 'product' and i.item_id = p_id)
    or exists (select 1 from public.stock_entries i where i.org_id = p_org_id and i.product_id = p_id);
  if v_refs then
    update public.products set active = false where id = p_id and org_id = p_org_id;
    return 'archived';
  end if;
  delete from public.products where id = p_id and org_id = p_org_id;
  return 'deleted';
end;
$$;

CREATE OR REPLACE FUNCTION public.client_profile(p_org_id uuid, p_client_id uuid, p_done_statuses text[], p_with_photos boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $$
declare
  v_client jsonb;
  v_anamneses jsonb := '[]'::jsonb;
  v_photo_count integer := 0;
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
    v_photo_count := public.anamnese_client_photo_count(p_org_id, p_client_id);
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
    'photo_count', v_photo_count,
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
