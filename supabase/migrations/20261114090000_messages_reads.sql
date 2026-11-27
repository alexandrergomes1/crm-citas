-- Mensagens e Marketing: leituras das telas em UMA ida ao banco cada (porte para o TanStack Start, orçamento de chamadas).
-- Antes (beauty-system): toda tela de Mensagens lia TODOS os modelos só para contar o selo; o histórico fazia 6 consultas
-- (fila, clientes, modelos, campanhas, perfis, eventos); Campanhas fazia 9 (campanhas, modelos, fila, serviços e 4 previews,
-- cada um lendo até 1000 clientes e as preferências de consentimento); Avaliações lia modelos e histórico inteiros.
-- Agora cada tela é UMA função, só com as colunas que ela usa (nunca token: nenhuma destas tabelas guarda token; o
-- segredo do WhatsApp, da Meta e do e-mail fica no servidor, em variável de ambiente).
-- SECURITY INVOKER + search_path vazio: a RLS das tabelas continua valendo por baixo. Cada função confere o estúdio e a
-- liberação (mensagens.use ou mensagens.configure; Campanhas e Avaliações pedem mensagens.configure, como o menu já pedia).
-- Público das campanhas: contado e listado NO BANCO (marketing_audience), com o consentimento aplicado aqui e não só
-- na tela. Os filtros são os do sistema antigo (etiqueta, inatividade, serviço, aniversário, gasto, consentimento e
-- canal); o teste 155 confere cada um, o consentimento e o cancelamento da inscrição.
-- Encoding: UTF-8
set client_encoding = 'UTF8';

-- ─── Índices das listas ordenadas por data ─────────────────────────────────────────────────────────
create index if not exists idx_marketing_queue_org_created
  on public.marketing_message_queue (org_id, created_at desc, id);
create index if not exists idx_marketing_campaigns_org_created
  on public.marketing_campaigns (org_id, created_at desc, id);
create index if not exists idx_messaging_log_org_purpose_created
  on public.messaging_provider_log (org_id, purpose, created_at desc);
create index if not exists idx_marketing_templates_org_name
  on public.marketing_message_templates (org_id, name, id) where archived_at is null;

-- ─── Regras de consentimento (um lugar só) ─────────────────────────────────────────────────────────
-- A recusa vale por MEIO, não por canal exato: quem recusou em qualquer canal de WhatsApp (manual ou automático) está
-- fora das campanhas dos dois; e-mail e SMS idem (cada um é o seu meio).
create or replace function public.marketing_channel_family(p_channel text)
returns text[]
language sql
immutable
security invoker
set search_path = ''
as $$
  select case
    when p_channel in ('whatsapp_manual', 'whatsapp_provider') then array['whatsapp_manual', 'whatsapp_provider']
    when p_channel = 'email_provider' then array['email_provider']
    when p_channel = 'sms_provider' then array['sms_provider']
    when p_channel = 'internal_note' then array['internal_note']
  end
$$;

-- DECISÃO PENDENTE (Alexandre, RGPD): cliente SEM preferência de marketing registrada conta como "pode receber"
-- (regra do sistema antigo, mantida por enquanto). Para exigir consentimento registrado, uma migration nova troca o
-- `true` abaixo por `false`: o público, a fila e a guarda do banco passam a seguir juntos. É o único lugar da regra.
create or replace function public.marketing_missing_consent_counts_as_allowed()
returns boolean
language plpgsql
stable
security invoker
set search_path = ''
as $$ begin return true; end $$;

-- Esta cliente pode receber marketing neste meio? (usada pela guarda da fila; o público faz a mesma conta em conjunto)
-- Fora: cliente de outro estúdio, mesclada, bloqueada, ou com recusa em qualquer canal do meio (descadastro ou
-- marketing_allowed = false). Sem preferência registrada: vale marketing_missing_consent_counts_as_allowed().
-- SECURITY DEFINER para ler as preferências sem depender da RLS de quem chama; só o gatilho a executa.
create or replace function public.marketing_client_eligible(p_org_id uuid, p_client_id uuid, p_channel text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select c.merged_into is null and c.blocked_at is null
    and not exists (
      select 1 from public.client_marketing_preferences p
      where p.org_id = p_org_id and p.client_id = p_client_id and p.channel = any (public.marketing_channel_family(p_channel))
        and (p.opted_out_at is not null or p.marketing_allowed = false))
    and (public.marketing_missing_consent_counts_as_allowed() or exists (
      select 1 from public.client_marketing_preferences p
      where p.org_id = p_org_id and p.client_id = p_client_id and p.channel = any (public.marketing_channel_family(p_channel))))
  from public.clients c
  where c.id = p_client_id and c.org_id = p_org_id
$$;
revoke all on function public.marketing_client_eligible(uuid, uuid, text) from public, anon, authenticated;

-- ─── Público de uma campanha (consentimento incluído) ──────────────────────────────────────────────
-- Filtro (jsonb) com as mesmas chaves de MarketingAudienceFilter: clientStatus, tagsAny, serviceIdsAny, inactiveDays,
-- birthdayWindowDays, totalSpentMin, totalSpentMax, marketingConsent (any | allowed | missing_or_allowed) e channel
-- (um dos cinco canais; o consentimento é conferido no MEIO do canal).
-- Sempre fora: cliente mesclada em outra (merged_into) e bloqueada (blocked_at).
-- p_enforce_consent = true: NUNCA devolve quem recusou o meio (descadastro ou marketing_allowed = false), qualquer que
-- seja o filtro (é o que a fila de envio usa).
-- Desempenho: o plano é refeito com os valores do filtro (plan_cache_mode), o filtro por serviço vira UM conjunto de
-- clientes calculado uma vez e as preferências entram agregadas por cliente (uma linha por cliente).
create or replace function public.marketing_audience(
  p_org_id uuid,
  p_filter jsonb,
  p_enforce_consent boolean default true
)
returns table (client_id uuid, full_name text, phone text, email text, phone_country_code text)
language plpgsql
stable
security invoker
set search_path = ''
set plan_cache_mode = force_custom_plan
as $$
#variable_conflict use_column
declare
  v_filter jsonb := coalesce(p_filter, '{}'::jsonb);
  v_today date;
  v_status text := v_filter ->> 'clientStatus';
  v_channel text := v_filter ->> 'channel';
  v_family text[];
  v_consent text := coalesce(v_filter ->> 'marketingConsent', 'missing_or_allowed');
  v_missing_ok boolean := public.marketing_missing_consent_counts_as_allowed();
  v_tags text[];
  v_services uuid[];
  v_svc_clients uuid[];
  v_inactive integer := (v_filter ->> 'inactiveDays')::integer;
  v_birthday integer := (v_filter ->> 'birthdayWindowDays')::integer;
  v_min numeric := (v_filter ->> 'totalSpentMin')::numeric;
  v_max numeric := (v_filter ->> 'totalSpentMax')::numeric;
begin
  if p_org_id is null or p_org_id not in (select public.auth_org_ids()) then
    raise exception 'Sem acesso a este estúdio.' using errcode = '42501';
  end if;
  if not public.has_permission(p_org_id, 'mensagens.configure') then
    raise exception 'Sem permissão para ver o público das campanhas.' using errcode = '42501';
  end if;
  if pg_catalog.jsonb_typeof(v_filter) <> 'object' then
    raise exception 'Filtro de público inválido.' using errcode = '22023';
  end if;
  if v_consent not in ('any', 'allowed', 'missing_or_allowed') then
    raise exception 'Filtro de consentimento inválido.' using errcode = '22023';
  end if;
  if v_channel is not null then
    v_family := public.marketing_channel_family(v_channel);
    if v_family is null then
      raise exception 'Canal do filtro inválido.' using errcode = '22023';
    end if;
  end if;
  -- O consentimento é por meio: sem canal não há como saber quem recusou (o sistema antigo tratava como "aceitou").
  if v_channel is null and (p_enforce_consent or v_consent <> 'any') then
    raise exception 'Escolha o canal do público.' using errcode = '22023';
  end if;

  select coalesce(pg_catalog.array_agg(t), '{}') into v_tags
  from pg_catalog.jsonb_array_elements_text(coalesce(v_filter -> 'tagsAny', '[]'::jsonb)) t;
  select coalesce(pg_catalog.array_agg(s::uuid), '{}') into v_services
  from pg_catalog.jsonb_array_elements_text(coalesce(v_filter -> 'serviceIdsAny', '[]'::jsonb)) s;

  -- Quem usou algum dos serviços: UM conjunto de clientes (não uma consulta por cliente).
  if pg_catalog.cardinality(v_services) > 0 then
    select coalesce(pg_catalog.array_agg(distinct a.client_id), '{}') into v_svc_clients
    from public.appointment_items i
    join public.appointments a on a.id = i.appointment_id and a.org_id = i.org_id
    where i.org_id = p_org_id and i.type = 'service' and i.ref_id = any (v_services) and a.client_id is not null;
  end if;

  -- Hoje no fuso do estúdio (o sistema antigo usava um fuso fixo).
  select (pg_catalog.now() at time zone coalesce(nullif(o.timezone, ''), 'Europe/Madrid'))::date into v_today
  from public.organizations o where o.id = p_org_id;

  return query
  select c.id, c.full_name, c.phone, c.email, c.phone_country_code
  from public.clients c
  left join (
    select p.client_id, pg_catalog.bool_or(p.opted_out_at is not null or p.marketing_allowed = false) as refused
    from public.client_marketing_preferences p
    where p.org_id = p_org_id and p.channel = any (v_family)
    group by p.client_id
  ) pref on pref.client_id = c.id
  where c.org_id = p_org_id
    and c.merged_into is null
    and c.blocked_at is null
    and (v_status is null or v_status = 'any' or c.status = v_status)
    and (pg_catalog.cardinality(v_tags) = 0 or c.tags && v_tags)
    and (v_svc_clients is null or c.id = any (v_svc_clients))
    and (v_inactive is null or (c.last_visit is not null and (v_today - c.last_visit) >= v_inactive))
    and (v_birthday is null or (
      c.birth_date is not null
      and (
        -- dias até o próximo aniversário (29/02 em ano sem bissexto cai em 01/03, como no sistema antigo)
        case
          when ((pg_catalog.date_trunc('year', v_today::timestamp)
                 + ((pg_catalog.date_part('month', c.birth_date)::integer - 1) * interval '1 month')
                 + ((pg_catalog.date_part('day', c.birth_date)::integer - 1) * interval '1 day'))::date) >= v_today
            then ((pg_catalog.date_trunc('year', v_today::timestamp)
                 + ((pg_catalog.date_part('month', c.birth_date)::integer - 1) * interval '1 month')
                 + ((pg_catalog.date_part('day', c.birth_date)::integer - 1) * interval '1 day'))::date) - v_today
          else ((pg_catalog.date_trunc('year', v_today::timestamp) + interval '1 year'
                 + ((pg_catalog.date_part('month', c.birth_date)::integer - 1) * interval '1 month')
                 + ((pg_catalog.date_part('day', c.birth_date)::integer - 1) * interval '1 day'))::date) - v_today
        end) <= v_birthday))
    and (v_min is null or c.total_spent >= v_min)
    and (v_max is null or c.total_spent <= v_max)
    and (
      v_consent = 'any'
      or (case when v_consent = 'allowed' then coalesce(not pref.refused, false) else coalesce(not pref.refused, v_missing_ok) end)
    )
    and (not p_enforce_consent or coalesce(not pref.refused, v_missing_ok))
  order by c.full_name, c.id;
end;
$$;

-- ─── Mensagens: selos e plano (Conversas, Automações e Canais) ─────────────────────────────────────
create or replace function public.messages_overview(p_org_id uuid, p_with_plan boolean default false)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_limit numeric;
begin
  if p_org_id is null or p_org_id not in (select public.auth_org_ids()) then
    raise exception 'Sem acesso a este estúdio.' using errcode = '42501';
  end if;
  if not (public.has_permission(p_org_id, 'mensagens.use') or public.has_permission(p_org_id, 'mensagens.configure')) then
    raise exception 'Sem permissão para ver as mensagens.' using errcode = '42501';
  end if;

  -- Limite mensal de mensagens automáticas: só para quem gerencia o plano (como no sistema antigo).
  if p_with_plan and public.has_permission(p_org_id, 'ajustes.manage') then
    select coalesce(nullif(s.limits_override ->> 'automated_messages_month', '')::numeric,
                    nullif(p.limits ->> 'automated_messages_month', '')::numeric)
      into v_limit
    from public.org_subscriptions s
    join public.plans p on p.key = s.plan_key
    where s.org_id = p_org_id;
  end if;

  return pg_catalog.jsonb_build_object(
    'templates_count', (select pg_catalog.count(*) from public.marketing_message_templates t
                        where t.org_id = p_org_id and t.archived_at is null),
    'monthly_limit', v_limit
  );
end;
$$;

-- ─── Mensagens › Modelos (lista e editor) ──────────────────────────────────────────────────────────
create or replace function public.messages_templates_screen(p_org_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_total integer;
begin
  if p_org_id is null or p_org_id not in (select public.auth_org_ids()) then
    raise exception 'Sem acesso a este estúdio.' using errcode = '42501';
  end if;
  if not (public.has_permission(p_org_id, 'mensagens.use') or public.has_permission(p_org_id, 'mensagens.configure')) then
    raise exception 'Sem permissão para ver as mensagens.' using errcode = '42501';
  end if;

  select pg_catalog.count(*) into v_total from public.marketing_message_templates t
  where t.org_id = p_org_id and t.archived_at is null;

  return pg_catalog.jsonb_build_object(
    'templates', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', t.id, 'name', t.name, 'channel', t.channel, 'purpose', t.purpose, 'language', t.language,
        'subject', t.subject, 'body', t.body, 'active', t.active, 'archived_at', t.archived_at,
        'version', t.version, 'updated_at', t.updated_at) order by t.name, t.id)
      from (select * from public.marketing_message_templates x
            where x.org_id = p_org_id and x.archived_at is null order by x.name, x.id limit 500) t
    ), '[]'::jsonb),
    'templates_count', v_total,
    'truncated', v_total > 500
  );
end;
$$;

-- ─── Mensagens › Histórico de envios ───────────────────────────────────────────────────────────────
create or replace function public.messages_history_screen(p_org_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  if p_org_id is null or p_org_id not in (select public.auth_org_ids()) then
    raise exception 'Sem acesso a este estúdio.' using errcode = '42501';
  end if;
  if not (public.has_permission(p_org_id, 'mensagens.use') or public.has_permission(p_org_id, 'mensagens.configure')) then
    raise exception 'Sem permissão para ver as mensagens.' using errcode = '42501';
  end if;

  return pg_catalog.jsonb_build_object(
    'templates_count', (select pg_catalog.count(*) from public.marketing_message_templates t
                        where t.org_id = p_org_id and t.archived_at is null),
    'truncated', (select pg_catalog.count(*) from public.marketing_message_queue x where x.org_id = p_org_id) > 500,
    'items', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', q.id, 'created_at', q.created_at, 'client_id', q.client_id, 'client_name', c.full_name,
        'template_id', q.template_id, 'template_name', t.name, 'campaign_id', q.campaign_id, 'campaign_name', ca.name,
        'channel', q.channel, 'status', q.status, 'event_status', ev.status, 'sent_by', pr.full_name)
        order by q.created_at desc, q.id)
      from (select x.id, x.created_at, x.client_id, x.template_id, x.campaign_id, x.channel, x.status, x.created_by
            from public.marketing_message_queue x where x.org_id = p_org_id
            order by x.created_at desc, x.id limit 500) q
      left join public.clients c on c.id = q.client_id and c.org_id = p_org_id
      left join public.marketing_message_templates t on t.id = q.template_id and t.org_id = p_org_id
      left join public.marketing_campaigns ca on ca.id = q.campaign_id and ca.org_id = p_org_id
      left join public.profiles pr on pr.user_id = q.created_by and pr.org_id = p_org_id
      left join lateral (
        select e.status from public.marketing_message_events e
        where e.org_id = p_org_id and e.queue_id = q.id order by e.created_at desc, e.id desc limit 1) ev on true
    ), '[]'::jsonb)
  );
end;
$$;

-- ─── Marketing › Campanhas ─────────────────────────────────────────────────────────────────────────
-- p_audiences: lista [{ "key": "...", "filter": {...} }] (até 10); a função devolve a contagem de cada uma.
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

  return pg_catalog.jsonb_build_object(
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

-- ─── Marketing › Avaliações ────────────────────────────────────────────────────────────────────────
create or replace function public.marketing_reviews_screen(p_org_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_tz text;
  v_month_start timestamptz;
begin
  if p_org_id is null or p_org_id not in (select public.auth_org_ids()) then
    raise exception 'Sem acesso a este estúdio.' using errcode = '42501';
  end if;
  if not public.has_permission(p_org_id, 'mensagens.configure') then
    raise exception 'Sem permissão para ver as avaliações.' using errcode = '42501';
  end if;

  select coalesce(nullif(o.timezone, ''), 'Europe/Madrid') into v_tz from public.organizations o where o.id = p_org_id;
  v_month_start := pg_catalog.date_trunc('month', pg_catalog.now() at time zone v_tz) at time zone v_tz;

  return pg_catalog.jsonb_build_object(
    'templates', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', t.id, 'name', t.name, 'channel', t.channel, 'language', t.language, 'body', t.body)
        order by t.name, t.id)
      from (select * from public.marketing_message_templates x
            where x.org_id = p_org_id and x.archived_at is null and x.purpose = 'review_request'
            order by x.name, x.id limit 500) t
    ), '[]'::jsonb),
    'month_sends', (
      select pg_catalog.count(*)
      from public.marketing_message_queue q
      join public.marketing_message_templates t on t.id = q.template_id and t.org_id = q.org_id
      where q.org_id = p_org_id and q.created_at >= v_month_start
        and t.archived_at is null and t.purpose = 'review_request'),
    'sends', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', q.id, 'created_at', q.created_at, 'client_id', q.client_id, 'client_name', c.full_name,
        'template_id', q.template_id, 'template_name', t.name, 'campaign_id', q.campaign_id, 'campaign_name', ca.name,
        'channel', q.channel, 'status', q.status, 'event_status', ev.status, 'sent_by', pr.full_name)
        order by q.created_at desc, q.id)
      from (select x.id, x.created_at, x.client_id, x.template_id, x.campaign_id, x.channel, x.status, x.created_by
            from public.marketing_message_queue x
            where x.org_id = p_org_id
              and x.template_id in (select r.id from public.marketing_message_templates r
                                    where r.org_id = p_org_id and r.archived_at is null and r.purpose = 'review_request')
            order by x.created_at desc, x.id limit 500) q
      left join public.clients c on c.id = q.client_id and c.org_id = p_org_id
      left join public.marketing_message_templates t on t.id = q.template_id and t.org_id = p_org_id
      left join public.marketing_campaigns ca on ca.id = q.campaign_id and ca.org_id = p_org_id
      left join public.profiles pr on pr.user_id = q.created_by and pr.org_id = p_org_id
      left join lateral (
        select e.status from public.marketing_message_events e
        where e.org_id = p_org_id and e.queue_id = q.id order by e.created_at desc, e.id desc limit 1) ev on true
    ), '[]'::jsonb)
  );
end;
$$;

-- ─── Permissões de execução: só quem está logado ───────────────────────────────────────────────────
revoke all on function public.marketing_audience(uuid, jsonb, boolean) from public, anon;
revoke all on function public.marketing_channel_family(text) from public, anon;
revoke all on function public.marketing_missing_consent_counts_as_allowed() from public, anon;
revoke all on function public.messages_overview(uuid, boolean) from public, anon;
revoke all on function public.messages_templates_screen(uuid) from public, anon;
revoke all on function public.messages_history_screen(uuid) from public, anon;
revoke all on function public.marketing_campaigns_screen(uuid, jsonb) from public, anon;
revoke all on function public.marketing_reviews_screen(uuid) from public, anon;

grant execute on function public.marketing_audience(uuid, jsonb, boolean) to authenticated;
grant execute on function public.marketing_channel_family(text) to authenticated;
grant execute on function public.marketing_missing_consent_counts_as_allowed() to authenticated;
grant execute on function public.messages_overview(uuid, boolean) to authenticated;
grant execute on function public.messages_templates_screen(uuid) to authenticated;
grant execute on function public.messages_history_screen(uuid) to authenticated;
grant execute on function public.marketing_campaigns_screen(uuid, jsonb) to authenticated;
grant execute on function public.marketing_reviews_screen(uuid) to authenticated;
