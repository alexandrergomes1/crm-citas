-- Anamnese (porte): cada tela da ficha em UMA ida ao banco, com o alcance de 20261114040000.
-- Encoding: UTF-8
set client_encoding = 'UTF8';
--
-- SECURITY DEFINER (justificado): a recepção acompanha as fichas (anamnese.view_status) mas não lê a tabela da ficha
-- (spec 29). Por isso as leituras de lista devolvem só status e conferem dentro delas: sessão, permissão no
-- estúdio, alcance (anamnese_row_in_scope), cadastro só com clientes.view e atendimento só se a pessoa o enxerga.
-- Link público só para ficha pendente e no prazo. Totais e contagens são do banco (nada cortado em 1000).
-- A ficha aberta (anamnese_ficha_screen) e as fotos (anamnese_ficha_photos, anamnese_client_photos) gravam
-- CLINICAL_READ dentro delas, depois de conferir tudo (regra de auditoria de 14/11).
-- anamnese_template_screen e anamnese_client_fichas: SECURITY INVOKER (a RLS vale).

-- ─── Status sem dado clínico (agenda, perfil, telas) ────────────────────────────────────────────
drop function if exists public.list_anamnese_status(uuid, uuid[], uuid, uuid, text);
create function public.list_anamnese_status(
  p_org_id uuid,
  p_appointment_ids uuid[] default null,
  p_client_id uuid default null,
  p_template_id uuid default null,
  p_status text default null,
  p_ids uuid[] default null
)
returns table (
  id uuid, org_id uuid, template_id uuid, template_title text, client_id uuid, client_name text,
  appointment_id uuid, status text, requires_professional boolean, professional_completed_at timestamptz,
  source_service_id uuid, public_token text, token_expires_at timestamptz, consent_version text,
  consent_accepted boolean, signed_at timestamptz, created_at timestamptz, updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'anamnese.view_status') then
    raise exception 'Sem permissão para consultar fichas de anamnese' using errcode = '42501';
  end if;
  return query
  select
    a.id, a.org_id, a.template_id, a.template_title, a.client_id, a.client_name,
    a.appointment_id, a.status, a.requires_professional, a.professional_completed_at, a.source_service_id,
    case when a.status = 'pending' and a.token_expires_at >= pg_catalog.now() then a.public_token end,
    a.token_expires_at, a.consent_version, a.consent_accepted, a.signed_at, a.created_at, a.updated_at
  from public.anamneses a
  where a.org_id = p_org_id
    and (p_appointment_ids is null or a.appointment_id = any (p_appointment_ids))
    and (p_client_id is null or a.client_id = p_client_id)
    and (p_template_id is null or a.template_id = p_template_id)
    and (p_status is null or a.status = p_status)
    and (p_ids is null or a.id = any (p_ids))
    and public.anamnese_row_in_scope(a.org_id, a.appointment_id, a.created_by)
  order by a.created_at desc, a.id
  limit 1000;
end;
$$;
revoke all on function public.list_anamnese_status(uuid, uuid[], uuid, uuid, text, uuid[]) from public, anon;
grant execute on function public.list_anamnese_status(uuid, uuid[], uuid, uuid, text, uuid[]) to authenticated;

-- ─── Ajudantes internos (só para as funções DEFINER deste arquivo) ──────────────────────────────
-- Situação da ficha, igual a fichaStage (src/domain/anamnese-fichas.ts).
create or replace function public.anamnese_stage_internal(p_status text, p_requires boolean, p_completed timestamptz, p_expires timestamptz)
returns text
language sql
stable
set search_path = ''
as $$
  select case
    when p_status = 'signed' then case when p_requires and p_completed is null then 'profissional' else 'concluida' end
    when p_expires is not null and p_expires < pg_catalog.now() then 'expirado'
    else 'aguardando'
  end;
$$;
revoke all on function public.anamnese_stage_internal(text, boolean, timestamptz, timestamptz) from public, anon, authenticated;

-- Linhas da lista (FichaItem) para as fichas pedidas, na ordem pedida. Quem chama já conferiu permissão e alcance.
create or replace function public.anamnese_items_internal(p_org_id uuid, p_ids uuid[])
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'id', a.id, 'status', a.status, 'token_expires_at', a.token_expires_at, 'signed_at', a.signed_at,
      'requires_professional', a.requires_professional, 'professional_completed_at', a.professional_completed_at,
      'created_at', a.created_at, 'client_id', a.client_id, 'client_name', a.client_name,
      'template_id', a.template_id, 'template_title', a.template_title, 'appointment_id', a.appointment_id,
      'public_token', case when a.status = 'pending' and a.token_expires_at >= pg_catalog.now() then a.public_token end,
      'client_phone', case when public.has_permission(p_org_id, 'clientes.view') then c.phone end,
      'client_alert', case when public.has_permission(p_org_id, 'clientes.view') then c.alert_text end,
      'appointment_at', ap.start_at,
      'service_label', case when ap.id is not null then (
        select pg_catalog.string_agg(i.name, ' · ' order by i.created_at, i.id)
        from public.appointment_items i
        where i.appointment_id = ap.id and i.org_id = p_org_id and pg_catalog.lower(i.type) = 'service') end)
    order by o.ord), '[]'::jsonb)
  from pg_catalog.unnest(p_ids) with ordinality o(id, ord)
  join public.anamneses a on a.id = o.id and a.org_id = p_org_id
  left join public.clients c on c.id = a.client_id and c.org_id = p_org_id
  -- Atendimento só se a pessoa o enxerga (agenda inteira ou dela).
  left join public.appointments ap on ap.id = a.appointment_id and ap.org_id = p_org_id
    and public.anamnese_row_in_scope(p_org_id, ap.id, null);
$$;
revoke all on function public.anamnese_items_internal(uuid, uuid[]) from public, anon, authenticated;

-- Contagem por situação de todas as fichas no alcance (sem corte).
create or replace function public.anamnese_counts_internal(p_org_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'todas', pg_catalog.count(*),
    'aguardando', pg_catalog.count(*) filter (where s = 'aguardando'),
    'profissional', pg_catalog.count(*) filter (where s = 'profissional'),
    'concluida', pg_catalog.count(*) filter (where s = 'concluida'),
    'expirado', pg_catalog.count(*) filter (where s = 'expirado'))
  from (
    select public.anamnese_stage_internal(a.status, a.requires_professional, a.professional_completed_at, a.token_expires_at) s
    from public.anamneses a
    where a.org_id = p_org_id and public.anamnese_row_in_scope(a.org_id, a.appointment_id, a.created_by)
  ) x;
$$;
revoke all on function public.anamnese_counts_internal(uuid) from public, anon, authenticated;

create or replace function public.anamnese_require_status_internal(p_org_id uuid)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'anamnese.view_status') then
    raise exception 'Sem permissão para consultar fichas de anamnese' using errcode = '42501';
  end if;
end;
$$;
revoke all on function public.anamnese_require_status_internal(uuid) from public, anon, authenticated;

-- ─── Visão geral ────────────────────────────────────────────────────────────────────────────────
-- Contagens do banco (todas e do mês [p_month_start, p_month_end), pela data do atendimento ou da criação),
-- "vencem em 30 dias", as fichas candidatas a "Precisa de atenção" (até 10 por tipo) e à "Atividade recente"
-- (as 10 mais recentes) e os 20 últimos envios/aberturas.
create or replace function public.anamnese_overview(p_org_id uuid, p_month_start timestamptz, p_month_end timestamptz)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_ids uuid[];
begin
  perform public.anamnese_require_status_internal(p_org_id);
  with f as (
    select a.id, a.appointment_id, a.created_at, a.signed_at, a.professional_completed_at, a.token_expires_at,
           public.anamnese_stage_internal(a.status, a.requires_professional, a.professional_completed_at, a.token_expires_at) s,
           (select ap.start_at from public.appointments ap where ap.id = a.appointment_id and ap.org_id = a.org_id) appt
    from public.anamneses a
    where a.org_id = p_org_id and public.anamnese_row_in_scope(a.org_id, a.appointment_id, a.created_by)
  )
  select pg_catalog.array_agg(distinct id) into v_ids from (
    (select id from f where s = 'aguardando' and appt between pg_catalog.now() - interval '1 day' and pg_catalog.now() + interval '8 days' order by appt limit 10)
    union all (select id from f where s = 'profissional' order by signed_at limit 10)
    union all (select id from f where s = 'expirado' order by token_expires_at desc limit 10)
    union all (select id from f order by greatest(created_at, signed_at, professional_completed_at) desc limit 10)
  ) x;

  return pg_catalog.jsonb_build_object(
    'counts', public.anamnese_counts_internal(p_org_id),
    'month', (
      select pg_catalog.jsonb_build_object(
        'total', pg_catalog.count(*),
        'aguardando', pg_catalog.count(*) filter (where s = 'aguardando'),
        'profissional', pg_catalog.count(*) filter (where s = 'profissional'),
        'concluida', pg_catalog.count(*) filter (where s = 'concluida'))
      from (
        select public.anamnese_stage_internal(a.status, a.requires_professional, a.professional_completed_at, a.token_expires_at) s,
               coalesce((select ap.start_at from public.appointments ap where ap.id = a.appointment_id and ap.org_id = a.org_id), a.created_at) d
        from public.anamneses a
        where a.org_id = p_org_id and public.anamnese_row_in_scope(a.org_id, a.appointment_id, a.created_by)
      ) m where d >= p_month_start and d < p_month_end),
    -- Concluídas cuja validade (12 meses depois da assinatura) termina nos próximos 30 dias; a mais próxima.
    'expiring', (
      select pg_catalog.jsonb_build_object('count', pg_catalog.count(*),
        'first', (pg_catalog.array_agg(pg_catalog.jsonb_build_object('client_name', e.client_name, 'until', e.until) order by e.until))[1])
      from (
        select a.client_name, a.signed_at + interval '12 months' until
        from public.anamneses a
        where a.org_id = p_org_id and a.status = 'signed'
          and (not a.requires_professional or a.professional_completed_at is not null)
          and a.signed_at + interval '12 months' between pg_catalog.now() - interval '1 day' and pg_catalog.now() + interval '31 days'
          and public.anamnese_row_in_scope(a.org_id, a.appointment_id, a.created_by)
      ) e),
    'rows', public.anamnese_items_internal(p_org_id, coalesce(v_ids, '{}'::uuid[])),
    'events', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'id', e.id, 'anamnese_id', e.anamnese_id, 'client_name', e.client_name, 'kind', e.kind, 'channel', e.channel,
          'user_name', e.user_name, 'meta', e.meta, 'created_at', e.created_at) order by e.created_at desc, e.id)
      from (
        select ev.id, ev.anamnese_id, a.client_name, ev.kind, ev.channel, ev.meta, ev.created_at,
               (select p.full_name from public.profiles p where p.org_id = ev.org_id and p.user_id = ev.user_id limit 1) user_name
        from public.anamnese_events ev
        join public.anamneses a on a.id = ev.anamnese_id and a.org_id = ev.org_id
        where ev.org_id = p_org_id and public.anamnese_row_in_scope(a.org_id, a.appointment_id, a.created_by)
        order by ev.created_at desc, ev.id
        limit 20
      ) e), '[]'::jsonb)
  );
end;
$$;
revoke all on function public.anamnese_overview(uuid, timestamptz, timestamptz) from public, anon;
grant execute on function public.anamnese_overview(uuid, timestamptz, timestamptz) to authenticated;

-- ─── Fichas (lista paginada no banco) ───────────────────────────────────────────────────────────
-- Filtro: busca (cliente, modelo, serviço, telefone), situação e modelo; ordem 'atendimento' | 'cliente' |
-- 'validade' (mesmas regras de sortFichas). Página de até 100 (exportar: até 2000, sem o "Enviar ficha").
-- p_link: ficha do "Link pronto" (mesmo fora da página). p_send: clientes, próximos atendimentos e modelos.
create or replace function public.anamnese_fichas_page(
  p_org_id uuid, p_q text, p_stage text, p_template_id uuid, p_sort text, p_page integer, p_per_page integer,
  p_link uuid, p_send boolean, p_from timestamptz
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_q text := nullif(pg_catalog.btrim(coalesce(p_q, '')), '');
  v_ids uuid[];
  v_total integer;
  v_blocking integer;
  v_urgent uuid;
  v_matrix jsonb;
  v_out jsonb;
begin
  perform public.anamnese_require_status_internal(p_org_id);
  if pg_catalog.char_length(coalesce(p_q, '')) > 100 or coalesce(p_stage, 'todas') not in ('todas', 'aguardando', 'profissional', 'concluida', 'expirado')
     or coalesce(p_sort, 'atendimento') not in ('atendimento', 'cliente', 'validade')
     or p_page is null or p_page < 1 or p_per_page is null or p_per_page not between 1 and (case when p_send then 100 else 2000 end) then
    raise exception 'Filtro inválido' using errcode = '22023';
  end if;

  with b as (
    select a.id, a.client_name, a.created_at, a.signed_at, a.token_expires_at, a.template_id,
           public.anamnese_stage_internal(a.status, a.requires_professional, a.professional_completed_at, a.token_expires_at) s,
           ap.start_at appt
    from public.anamneses a
    left join public.appointments ap on ap.id = a.appointment_id and ap.org_id = a.org_id
      and public.anamnese_row_in_scope(a.org_id, ap.id, null)
    left join public.clients c on c.id = a.client_id and c.org_id = a.org_id
    where a.org_id = p_org_id
      and public.anamnese_row_in_scope(a.org_id, a.appointment_id, a.created_by)
      and (v_q is null or pg_catalog.concat_ws(' ', a.client_name, a.template_title,
            case when public.has_permission(p_org_id, 'clientes.view') then c.phone end,
            (select pg_catalog.string_agg(i.name, ' ') from public.appointment_items i
             where i.appointment_id = ap.id and i.org_id = a.org_id and pg_catalog.lower(i.type) = 'service'))
           operator(pg_catalog.~~*) ('%' || pg_catalog.replace(pg_catalog.replace(pg_catalog.replace(v_q, '\', '\\'), '%', '\%'), '_', '\_') || '%'))
  ), f as (
    select * from b where p_template_id is null or b.template_id = p_template_id
  ), g as (
    select * from f where coalesce(p_stage, 'todas') = 'todas' or s = p_stage
  ), o as (
    select id, pg_catalog.row_number() over (order by
      case when p_sort = 'cliente' then g.client_name end asc,
      case when p_sort = 'validade' then coalesce(g.signed_at + interval '12 months', g.token_expires_at) end asc nulls last,
      case when coalesce(p_sort, 'atendimento') = 'atendimento' then g.appt end desc nulls last,
      g.created_at desc, g.id) n
    from g
  )
  select (select pg_catalog.count(*) from g), (select pg_catalog.count(*) from g where s = 'profissional'),
         (select pg_catalog.array_agg(id order by n) from o where n > (p_page - 1) * p_per_page and n <= p_page * p_per_page),
         (select id from b where s = 'aguardando' and appt between pg_catalog.now() - interval '1 day' and pg_catalog.now() + interval '3 days'
          order by appt limit 1),
         -- Para o "Mostrar N fichas" da folha de filtros: com a busca atual, quantas por modelo e situação.
         (select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('template_id', m.template_id, 'stage', m.s, 'n', m.n)), '[]'::jsonb)
          from (select template_id, s, pg_catalog.count(*) n from b group by template_id, s) m)
  into v_total, v_blocking, v_ids, v_urgent, v_matrix;

  v_out := pg_catalog.jsonb_build_object(
    'rows', public.anamnese_items_internal(p_org_id, coalesce(v_ids, '{}'::uuid[])),
    'total', v_total,
    'blocking', v_blocking,
    'matrix', v_matrix,
    'counts', public.anamnese_counts_internal(p_org_id),
    'urgent', public.anamnese_items_internal(p_org_id, case when v_urgent is null then '{}'::uuid[] else array[v_urgent] end) -> 0,
    'link', case when p_link is not null and public.anamnese_in_scope(p_org_id, p_link)
                 then public.anamnese_items_internal(p_org_id, array[p_link]) -> 0 end);

  if p_send then
    v_out := v_out || pg_catalog.jsonb_build_object(
      'clients', case when public.has_permission(p_org_id, 'clientes.view') then coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', c.id, 'full_name', c.full_name, 'phone', c.phone,
          'last_visit', c.last_visit) order by c.full_name, c.id)
        from (select cl.id, cl.full_name, cl.phone, cl.last_visit from public.clients cl
              where cl.org_id = p_org_id order by cl.full_name, cl.id limit 200) c), '[]'::jsonb) else '[]'::jsonb end,
      'appointments', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', a.id, 'client_id', a.client_id, 'start_at', a.start_at,
          'status', a.status, 'items', coalesce((
            select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('name', i.name, 'templateId', i.anamnese_template_id) order by i.created_at, i.id)
            from public.appointment_items i
            where i.appointment_id = a.id and i.org_id = p_org_id and pg_catalog.lower(i.type) = 'service'), '[]'::jsonb))
          order by a.start_at, a.id)
        from (select ap.id, ap.client_id, ap.start_at, ap.status from public.appointments ap
              where ap.org_id = p_org_id and ap.start_at >= coalesce(p_from, pg_catalog.now() - interval '1 day')
                and public.anamnese_row_in_scope(p_org_id, ap.id, null)
              order by ap.start_at, ap.id limit 200) a), '[]'::jsonb),
      'templates', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', t.id, 'title', t.title, 'is_active', t.is_active,
          'professional_form', t.professional_form) order by t.title, t.id)
        from public.anamnese_templates t where t.org_id = p_org_id and t.active), '[]'::jsonb));
  end if;
  return v_out;
end;
$$;
revoke all on function public.anamnese_fichas_page(uuid, text, text, uuid, text, integer, integer, uuid, boolean, timestamptz) from public, anon;
grant execute on function public.anamnese_fichas_page(uuid, text, text, uuid, text, integer, integer, uuid, boolean, timestamptz) to authenticated;

-- Exportar a lista (CSV): as mesmas linhas da tela (até 2000, sem envio) e um registro na auditoria com quantas
-- fichas saíram e os filtros (sem o texto da busca, que pode ter nome de cliente).
create or replace function public.anamnese_fichas_export(p_org_id uuid, p_q text, p_stage text, p_template_id uuid, p_sort text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_out jsonb := public.anamnese_fichas_page(p_org_id, p_q, p_stage, p_template_id, p_sort, 1, 2000, null, false, null);
begin
  insert into public.audit_logs (org_id, user_id, table_name, operation, new_data)
  values (p_org_id, (select auth.uid()), 'anamneses', 'ANAMNESE_FICHAS_EXPORTED',
          pg_catalog.jsonb_build_object('count', pg_catalog.jsonb_array_length(coalesce(v_out -> 'rows', '[]'::jsonb)),
            'stage', coalesce(p_stage, 'todas'), 'template_id', p_template_id,
            'with_search', nullif(pg_catalog.btrim(coalesce(p_q, '')), '') is not null));
  return v_out;
end;
$$;
revoke all on function public.anamnese_fichas_export(uuid, text, text, uuid, text) from public, anon;
grant execute on function public.anamnese_fichas_export(uuid, text, text, uuid, text) to authenticated;

-- ─── Modelos e termos ───────────────────────────────────────────────────────────────────────────
-- Modelos ativos inteiros, fichas por modelo e o número do painel (aguardando + profissional), sem linha de ficha.
create or replace function public.anamnese_catalog_screen(p_org_id uuid, p_with_services boolean)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.anamnese_require_status_internal(p_org_id);
  return pg_catalog.jsonb_build_object(
    'templates', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'id', t.id, 'title', t.title, 'description', t.description, 'questions', t.questions,
          'consent_text', t.consent_text, 'consent_version', t.consent_version, 'professional_form', t.professional_form,
          'version', t.version, 'country', t.country, 'is_active', t.is_active, 'created_at', t.created_at, 'updated_at', t.updated_at)
        order by t.title, t.id)
      from public.anamnese_templates t where t.org_id = p_org_id and t.active), '[]'::jsonb),
    'usage', coalesce((
      select pg_catalog.jsonb_object_agg(u.template_id, u.n)
      from (select a.template_id, pg_catalog.count(*) n from public.anamneses a
            where a.org_id = p_org_id and a.template_id is not null
              and public.anamnese_row_in_scope(a.org_id, a.appointment_id, a.created_by)
            group by a.template_id) u), '{}'::jsonb),
    'pending', (select (c ->> 'aguardando')::integer + (c ->> 'profissional')::integer from public.anamnese_counts_internal(p_org_id) c),
    'services', case when p_with_services then coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', sv.id, 'name', sv.name,
          'anamnese_template_id', sv.anamnese_template_id, 'requires_anamnese', sv.requires_anamnese) order by sv.position, sv.id)
      from public.services sv where sv.org_id = p_org_id and sv.active), '[]'::jsonb) else '[]'::jsonb end);
end;
$$;
revoke all on function public.anamnese_catalog_screen(uuid, boolean) from public, anon;
grant execute on function public.anamnese_catalog_screen(uuid, boolean) to authenticated;

-- ─── Editor de modelo (INVOKER) ─────────────────────────────────────────────────────────────────
create or replace function public.anamnese_template_screen(p_org_id uuid, p_template_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_tpl jsonb;
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'anamnese.view_status') then
    raise exception 'Sem permissão para consultar modelos de anamnese' using errcode = '42501';
  end if;
  select pg_catalog.jsonb_build_object(
      'id', t.id, 'title', t.title, 'questions', t.questions, 'consent_text', t.consent_text,
      'consent_version', t.consent_version, 'professional_form', t.professional_form,
      'is_active', t.is_active, 'version', t.version, 'country', t.country)
  into v_tpl
  from public.anamnese_templates t
  where t.org_id = p_org_id and t.id = p_template_id and t.active;
  if v_tpl is null then
    return null;
  end if;
  return pg_catalog.jsonb_build_object('template', v_tpl, 'services', coalesce((
    select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', sv.id, 'name', sv.name, 'requires_anamnese', sv.requires_anamnese)
      order by sv.position, sv.id)
    from public.services sv
    where sv.org_id = p_org_id and sv.active and sv.anamnese_template_id = p_template_id), '[]'::jsonb));
end;
$$;
revoke all on function public.anamnese_template_screen(uuid, uuid) from public, anon;
grant execute on function public.anamnese_template_screen(uuid, uuid) to authenticated;
