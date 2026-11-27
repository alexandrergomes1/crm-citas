-- Marketing só para quem disse SIM (decisão do Alexandre, 14/11/2026, RGPD): cliente sem preferência registrada
-- NÃO entra em campanha. A regra continua num lugar só (marketing_missing_consent_counts_as_allowed): o público, a fila
-- e a guarda do banco seguem juntos. Mesma assinatura, grants e search_path da versão de 20261114090000.
-- Também: estado de autorização de marketing por cliente (função "coluna calculada" para o filtro "sem consentimento"
-- da lista de Clientes), contagem no aviso de Campanhas e estado no perfil. Só leitura; nada é aplicado em banco aqui.
-- Encoding: UTF-8

create or replace function public.marketing_missing_consent_counts_as_allowed()
returns boolean
language plpgsql
stable
security invoker
set search_path = ''
as $$ begin return false; end $$;
revoke all on function public.marketing_missing_consent_counts_as_allowed() from public, anon;
grant execute on function public.marketing_missing_consent_counts_as_allowed() to authenticated;

-- Estado de marketing da cliente POR MEIO (a regra real é por meio: marketing_channel_family). 'refused' = há recusa
-- (descadastro ou marketing_allowed = false) em qualquer canal do meio; 'authorized' = há aceite no meio e nenhuma recusa;
-- 'none' = sem preferência registrada no meio. SECURITY INVOKER: vale a RLS de quem lê.
create or replace function public.marketing_channel_state(p_org_id uuid, p_client_id uuid, p_channel text)
returns text
language sql
stable
security invoker
set search_path = ''
as $$
  select case
    when exists (select 1 from public.client_marketing_preferences p
                 where p.org_id = p_org_id and p.client_id = p_client_id and p.channel = any (public.marketing_channel_family(p_channel))
                   and (p.opted_out_at is not null or p.marketing_allowed = false)) then 'refused'
    when exists (select 1 from public.client_marketing_preferences p
                 where p.org_id = p_org_id and p.client_id = p_client_id and p.channel = any (public.marketing_channel_family(p_channel))) then 'authorized'
    else 'none'
  end
$$;
revoke all on function public.marketing_channel_state(uuid, uuid, text) from public, anon;
grant execute on function public.marketing_channel_state(uuid, uuid, text) to authenticated;

-- A elegibilidade (guarda da fila) passa a usar o MESMO estado por meio: não diverge do aviso, do filtro nem do perfil.
-- Mesma assinatura e permissões de 20261114090000 (só o gatilho a executa).
create or replace function public.marketing_client_eligible(p_org_id uuid, p_client_id uuid, p_channel text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select c.merged_into is null and c.blocked_at is null
    and (s.st = 'authorized' or (s.st = 'none' and public.marketing_missing_consent_counts_as_allowed()))
  from public.clients c
  cross join lateral (select public.marketing_channel_state(p_org_id, p_client_id, p_channel) as st) s
  where c.id = p_client_id and c.org_id = p_org_id
$$;
revoke all on function public.marketing_client_eligible(uuid, uuid, text) from public, anon, authenticated;

-- Perfil: estado nos meios que a tela de cliente edita (WhatsApp e e-mail).
create or replace function public.marketing_state(c public.clients)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'whatsapp', public.marketing_channel_state(c.org_id, c.id, 'whatsapp_manual'),
    'email', public.marketing_channel_state(c.org_id, c.id, 'email_provider'))
$$;
revoke all on function public.marketing_state(public.clients) from public, anon;
grant execute on function public.marketing_state(public.clients) to authenticated;

-- Autorizada em ALGUM meio? (coluna calculada de clients: o filtro "Sem consentimento" da lista usa marketing_authorized = false,
-- isto é, sem autorização em NENHUM meio)
create or replace function public.marketing_authorized(c public.clients)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select public.marketing_channel_state(c.org_id, c.id, 'whatsapp_manual') = 'authorized'
      or public.marketing_channel_state(c.org_id, c.id, 'email_provider') = 'authorized'
      or public.marketing_channel_state(c.org_id, c.id, 'sms_provider') = 'authorized'
$$;
revoke all on function public.marketing_authorized(public.clients) from public, anon;
grant execute on function public.marketing_authorized(public.clients) to authenticated;

-- Campanhas: o mesmo corpo de 20261114090000 mais "unauthorized_count" (ativas sem autorização em NENHUM meio) e
-- "unauthorized_by_channel" (ativas que não podem receber naquele meio).
create or replace function public.marketing_campaigns_screen(p_org_id uuid, p_audiences jsonb default '[]'::jsonb)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_audiences jsonb := '[]'::jsonb;
  v_item jsonb;
  v_campaigns integer;
  v_templates integer;
  v_queue integer;
  v_unauthorized integer;
  v_by_channel jsonb;
begin
  if p_org_id is null or p_org_id not in (select public.auth_org_ids()) then
    raise exception 'Sem acesso a este estúdio.' using errcode = '42501';
  end if;
  if not public.has_permission(p_org_id, 'mensagens.configure') then
    raise exception 'Sem permissão para ver as campanhas.' using errcode = '42501';
  end if;
  if pg_catalog.jsonb_typeof(coalesce(p_audiences, '[]'::jsonb)) <> 'array'
     or pg_catalog.jsonb_array_length(coalesce(p_audiences, '[]'::jsonb)) > 10 then
    raise exception 'Lista de públicos inválida.' using errcode = '22023';
  end if;

  for v_item in select * from pg_catalog.jsonb_array_elements(coalesce(p_audiences, '[]'::jsonb)) loop
    v_audiences := v_audiences || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'key', v_item ->> 'key',
      'count', (select pg_catalog.count(*) from public.marketing_audience(p_org_id, v_item -> 'filter', false))));
  end loop;

  select pg_catalog.count(*) into v_campaigns from public.marketing_campaigns x where x.org_id = p_org_id;
  select pg_catalog.count(*) into v_templates from public.marketing_message_templates x where x.org_id = p_org_id and x.archived_at is null;
  select pg_catalog.count(*) into v_queue from public.marketing_message_queue x where x.org_id = p_org_id;

  -- Clientes ativas (não mescladas nem bloqueadas) sem autorização de marketing: não entram nas campanhas.
  select pg_catalog.count(*) into v_unauthorized
  from public.clients c
  where c.org_id = p_org_id and c.status = 'Ativo' and c.merged_into is null and c.blocked_at is null
    and not public.marketing_authorized(c);

  -- Por meio (o do canal da campanha): ativas que o meio não deixa receber por falta de aceite ou por recusa.
  select pg_catalog.jsonb_object_agg(ch, (
    select pg_catalog.count(*) from public.clients c
    where c.org_id = p_org_id and c.status = 'Ativo' and c.merged_into is null and c.blocked_at is null
      and not (public.marketing_channel_state(c.org_id, c.id, ch) = 'authorized'
               or (public.marketing_channel_state(c.org_id, c.id, ch) = 'none' and public.marketing_missing_consent_counts_as_allowed()))))
  into v_by_channel
  from pg_catalog.unnest(array['whatsapp_manual', 'email_provider', 'sms_provider']) ch;

  return pg_catalog.jsonb_build_object(
    'unauthorized_count', v_unauthorized,
    'unauthorized_by_channel', v_by_channel,
    'campaigns', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', c.id, 'name', c.name, 'status', c.status, 'planned_channel', c.planned_channel, 'purpose', c.purpose,
        'estimated_audience_count', c.estimated_audience_count) order by c.created_at desc, c.id)
      from (select * from public.marketing_campaigns x where x.org_id = p_org_id
            order by x.created_at desc, x.id limit 50) c
    ), '[]'::jsonb),
    'templates', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', t.id, 'name', t.name, 'channel', t.channel, 'purpose', t.purpose) order by t.created_at desc, t.id)
      from (select * from public.marketing_message_templates x where x.org_id = p_org_id and x.archived_at is null
            order by x.created_at desc, x.id limit 50) t
    ), '[]'::jsonb),
    'queue', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', q.id, 'recipient', q.recipient, 'status', q.status, 'message_body', q.message_body)
        order by q.created_at desc, q.id)
      from (select * from public.marketing_message_queue x where x.org_id = p_org_id
            order by x.created_at desc, x.id limit 50) q
    ), '[]'::jsonb),
    'services', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', s.id, 'name', s.name) order by s.position, s.name, s.id)
      from (select x.id, x.name, x.position from public.services x
            where x.org_id = p_org_id and x.active order by x.position, x.name, x.id limit 500) s
    ), '[]'::jsonb),
    'audiences', v_audiences,
    'truncated', pg_catalog.to_jsonb(pg_catalog.array_remove(array[
      case when v_campaigns > 50 then 'campaigns' end,
      case when v_templates > 50 then 'templates' end,
      case when v_queue > 50 then 'queue' end], null))
  );
end;
$$;
revoke all on function public.marketing_campaigns_screen(uuid, jsonb) from public, anon;
grant execute on function public.marketing_campaigns_screen(uuid, jsonb) to authenticated;

-- Perfil da cliente: o mesmo corpo de 20261114040600 (versão vigente) mais "marketing_state" dentro de "client".
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

  select pg_catalog.to_jsonb(c) || pg_catalog.jsonb_build_object('marketing_state', public.marketing_state(c)) into v_client
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

revoke all on function public.client_profile(uuid, uuid, text[], boolean) from public, anon;
grant execute on function public.client_profile(uuid, uuid, text[], boolean) to authenticated;

notify pgrst, 'reload schema';
