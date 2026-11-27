-- Leituras da lista de Clientes em menos idas ao banco. As duas funções são SECURITY INVOKER:
-- rodam com o usuário logado, então a RLS de clients, client_entitlements, appointments e
-- appointment_items vale exatamente como nas consultas que substituem. Só leitura.
-- Regras (etiqueta VIP, retoque, corte de "sem visita", status) continuam vindo do app como parâmetro;
-- o cálculo de crédito aberto e de aniversário continua no app (src/domain).
-- Encoding: UTF-8

-- Painel da lista (antes: 1 consulta de créditos + 1 de aniversários + 5 a 6 contagens).
-- Devolve as contagens simples e os dados crus que o app usa para retoque e aniversariantes.
-- p_birthday_month: mês de hoje no fuso do estúdio (1-12); só volta quem faz aniversário nele
-- (o app confere de novo com isBirthdayMonth). Crédito × cliente ativa por junção (chave primária),
-- não por varredura da lista de ativas a cada crédito (20 mil clientes / 4 mil créditos: 2,3 s → 21 ms).
create or replace function public.client_list_summary(
  p_org_id uuid,
  p_vip_tag text,
  p_retouch_tag text,
  p_inactive_before date,
  p_birthday_month integer
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with active as (
    select c.id, c.tags, c.balance, c.last_visit, c.birth_date
    from public.clients c
    where c.org_id = p_org_id and c.status = 'Ativo'
  )
  select pg_catalog.jsonb_build_object(
    'todos', (select count(*) from active),
    'vip', (select count(*) from active a where a.tags @> array[p_vip_tag]),
    'saldo', (select count(*) from active a where a.balance <> 0),
    'sem_visita', (select count(*) from active a where a.last_visit < p_inactive_before),
    'retouch_tagged', coalesce((select pg_catalog.jsonb_agg(a.id) from active a where a.tags @> array[p_retouch_tag]), '[]'::jsonb),
    'birthdays', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', a.id, 'birth_date', a.birth_date))
      from active a
      where a.birth_date is not null and extract(month from a.birth_date) = p_birthday_month), '[]'::jsonb),
    'credits', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'client_id', e.client_id, 'package_name', e.package_name, 'total_sessions', e.total_sessions,
        'used_sessions', e.used_sessions, 'expires_at', e.expires_at, 'status', e.status,
        'client_active', c.id is not null))
      from public.client_entitlements e
      left join public.clients c on c.id = e.client_id and c.org_id = e.org_id and c.status = 'Ativo'
      where e.org_id = p_org_id and e.status = 'active'), '[]'::jsonb)
  );
$$;
revoke all on function public.client_list_summary(uuid, text, text, date, integer) from public, anon;
grant execute on function public.client_list_summary(uuid, text, text, date, integer) to authenticated;

-- Dados de cada linha da página (antes: 3 consultas): próximo e último atendimento com os serviços,
-- e créditos ativos das clientes da página. Mesmos filtros e limites das consultas antigas.
create or replace function public.client_list_rows(
  p_org_id uuid,
  p_ids uuid[],
  p_now timestamptz,
  p_upcoming_statuses text[],
  p_done_statuses text[]
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'upcoming', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(x) order by x.start_at asc)
      from (
        select a.client_id, a.start_at,
          (select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('name', i.name)), '[]'::jsonb)
           from public.appointment_items i where i.appointment_id = a.id) as appointment_items
        from public.appointments a
        where a.org_id = p_org_id and a.client_id = any(p_ids)
          and a.start_at >= p_now and a.status = any(p_upcoming_statuses)
        order by a.start_at asc
        limit pg_catalog.cardinality(p_ids) * 4
      ) x), '[]'::jsonb),
    'past', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(x) order by x.start_at desc)
      from (
        select a.client_id, a.start_at,
          (select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('name', i.name)), '[]'::jsonb)
           from public.appointment_items i where i.appointment_id = a.id) as appointment_items
        from public.appointments a
        where a.org_id = p_org_id and a.client_id = any(p_ids)
          and a.start_at < p_now and a.status = any(p_done_statuses)
        order by a.start_at desc
        limit pg_catalog.cardinality(p_ids) * 6
      ) x), '[]'::jsonb),
    'credits', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'client_id', e.client_id, 'package_name', e.package_name, 'total_sessions', e.total_sessions,
        'used_sessions', e.used_sessions, 'expires_at', e.expires_at, 'status', e.status))
      from public.client_entitlements e
      where e.org_id = p_org_id and e.client_id = any(p_ids) and e.status = 'active'), '[]'::jsonb)
  );
$$;
revoke all on function public.client_list_rows(uuid, uuid[], timestamptz, text[], text[]) from public, anon;
grant execute on function public.client_list_rows(uuid, uuid[], timestamptz, text[], text[]) to authenticated;
