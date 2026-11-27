-- ============================================================
-- KA Beauty OS — dados de teste do quadro V25 (estúdio em Benalmádena)
-- Encoding: UTF-8
--
-- Popula UM estúdio que já existe com o mundo dos mockups (docs/design/v25-mockups):
-- 2 profissionais com turnos, 4 categorias e 17 serviços, 1 pacote, 30 clientes,
-- agenda da semana atual e da próxima, 12 semanas de histórico, comandas (pagas,
-- parcial, rascunhos), contas a pagar, lançamentos, fichas de anamnese e modelos de
-- mensagem. Só dados fictícios (telefones +34 600 000 0xx, e-mails @exemplo.es).
-- Não muda nome nem slug do estúdio.
--
-- Uso (Supabase local ou banco de teste; nunca num estúdio com clientes reais):
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
--     -v org_id=<uuid do estúdio> -v owner_id=<uuid da usuária dona> \
--     -f supabase/seed/02_v25_dados_teste.sql
--
-- Pode rodar de novo: os IDs são md5(org_id || chave)::uuid; antes de recriar, o seed
-- apaga o que ele mesmo criou (as clientes do seed e tudo delas, os bloqueios das
-- profissionais do seed, as contas e lançamentos do seed). Datas são relativas a hoje
-- no fuso do estúdio. Agendamentos, status, sinais, comandas, fichas, saldos, bloqueios
-- e pagamentos de contas passam pelas funções reais, como a dona (request.jwt.claims +
-- role authenticated). Depois, as datas de criação/pagamento do histórico são
-- recuadas para o dia do atendimento (as funções sempre gravam "agora").
-- Opcional: -v hoje=AAAA-MM-DD trata essa data como "hoje" (ex.: 2026-10-27, o dia dos
-- mockups). Datas depois de hoje de verdade ficam presas em "agora" nos registros.
-- Partes: supabase/seed/02_v25/*.sql (incluídas abaixo com \ir).
-- ============================================================
\set ON_ERROR_STOP 1
set client_encoding = 'UTF8';
\if :{?org_id}
\else
  do $$ begin raise exception 'Informe -v org_id=<uuid do estúdio>'; end $$;
\endif
\if :{?owner_id}
\else
  do $$ begin raise exception 'Informe -v owner_id=<uuid da usuária dona>'; end $$;
\endif
\if :{?hoje}
\else
  \set hoje ''
\endif

begin;
select set_config('seed.org_id', :'org_id', true) as org_id, set_config('seed.owner_id', :'owner_id', true) as owner_id,
       set_config('seed.hoje', :'hoje', true) as hoje;
select set_config('request.jwt.claims', json_build_object('sub', :'owner_id', 'role', 'authenticated')::text, true) is not null as claims;

do $$
declare
  v_org uuid := current_setting('seed.org_id')::uuid;
  v_owner uuid := current_setting('seed.owner_id')::uuid;
begin
  if not exists (select 1 from public.organizations where id = v_org) then
    raise exception 'Estúdio % não existe', v_org;
  end if;
  if not exists (select 1 from public.user_roles where org_id = v_org and user_id = v_owner and role = 'owner' and active) then
    raise exception 'Usuária % não é dona ativa do estúdio %', v_owner, v_org;
  end if;
end $$;

-- ─── Funções auxiliares (só desta sessão) ────────────────────
create function pg_temp.sid(p_chave text) returns uuid language sql stable
as $$ select md5(current_setting('seed.org_id') || p_chave)::uuid $$;
create function pg_temp.cliente(p_n int) returns uuid language sql stable
as $$ select pg_temp.sid('cliente-' || lpad(p_n::text, 2, '0')) $$;
create function pg_temp.tz() returns text language sql stable
as $$ select timezone from public.organizations where id = current_setting('seed.org_id')::uuid $$;
create function pg_temp.dia(p_offset int) returns date language sql stable
as $$ select coalesce(nullif(current_setting('seed.hoje'), '')::date, (now() at time zone pg_temp.tz())::date) + p_offset $$;
-- Domingo é fechado: fora de hoje, o atendimento vai para o sábado (passado) ou a segunda (futuro).
create function pg_temp.dia_util(p_offset int) returns date language sql stable as $$
  select d + case when p_offset <> 0 and extract(isodow from d) = 7 then sign(p_offset)::int else 0 end
  from (select pg_temp.dia(p_offset) as d) x $$;
create function pg_temp.em(p_offset int, p_hora text) returns timestamptz language sql stable
as $$ select (pg_temp.dia_util(p_offset) + p_hora::time) at time zone pg_temp.tz() $$;
create function pg_temp.mes(p_data date) returns text language sql immutable as $$
  select (array['janeiro','fevereiro','março','abril','maio','junho','julho','agosto','setembro',
    'outubro','novembro','dezembro'])[extract(month from p_data)::int] $$;
-- Respostas "não" em todas as perguntas sim/não do modelo congelado na ficha.
create function pg_temp.respostas(p_snapshot jsonb) returns jsonb language sql immutable as $$
  select coalesce(jsonb_object_agg(q->>'id', coalesce(q->'options'->>1, 'NO')), '{}'::jsonb)
         || '{"__canal": "link", "__termo_principal": "aceito"}'::jsonb
  from jsonb_array_elements(coalesce(p_snapshot->'questions', '[]'::jsonb)) q
  where q->>'type' = 'yes_no' $$;
grant execute on all functions in schema pg_temp to authenticated;

-- ─── 1. Limpeza do que o seed criou numa rodada anterior ─────
do $$
declare
  v_org uuid := current_setting('seed.org_id')::uuid;
  v_clientes uuid[] := array(select pg_temp.cliente(n) from generate_series(1, 30) n);
  v_profs uuid[] := array[pg_temp.sid('prof-karenn'), pg_temp.sid('prof-bruna')];
  v_contas uuid[] := array(select pg_temp.sid('conta-' || lpad(n::text, 2, '0')) from generate_series(1, 14) n);
  v_lancs uuid[] := array(select pg_temp.sid(k) from unnest(array['lanc-01','lanc-02','lanc-03']) k)
    || array(select pg_temp.sid('despesa-conta-' || lpad(n::text, 2, '0')) from generate_series(1, 14) n);
  v_ags uuid[];
  v_vendas uuid[];
begin
  if not exists (select 1 from public.clients where org_id = v_org and id = any(v_clientes))
     and not exists (select 1 from public.payables where org_id = v_org and id = any(v_contas))
     and not exists (select 1 from public.time_blocks where org_id = v_org and staff_id = any(v_profs)) then
    return; -- primeira rodada
  end if;
  begin
    -- Fichas assinadas e o extrato são imutáveis pelos gatilhos; só a limpeza do próprio seed os desliga.
    perform set_config('session_replication_role', 'replica', true);
  exception when insufficient_privilege then
    raise exception 'Rodar o seed de novo exige poder usar session_replication_role (usuária postgres)';
  end;
  v_ags := array(select id from public.appointments where org_id = v_org and client_id = any(v_clientes));
  v_vendas := array(select id from public.sales where org_id = v_org
    and (client_id = any(v_clientes) or appointment_id = any(v_ags)));
  delete from public.anamnese_gate_overrides where org_id = v_org and appointment_id = any(v_ags);
  delete from public.appointment_deposits where org_id = v_org and (appointment_id = any(v_ags) or client_id = any(v_clientes));
  delete from public.client_balance_entries where org_id = v_org and client_id = any(v_clientes);
  delete from public.loyalty_point_entries where org_id = v_org and client_id = any(v_clientes);
  delete from public.client_entitlement_entries where org_id = v_org and client_id = any(v_clientes);
  delete from public.client_entitlements where org_id = v_org and client_id = any(v_clientes);
  delete from public.gift_card_redemptions where org_id = v_org and (client_id = any(v_clientes) or sale_id = any(v_vendas));
  delete from public.payment_requests where org_id = v_org and client_id = any(v_clientes);
  delete from public.client_notes where org_id = v_org and client_id = any(v_clientes);
  delete from public.client_marketing_preferences where org_id = v_org and client_id = any(v_clientes);
  delete from public.marketing_message_queue where org_id = v_org and client_id = any(v_clientes);
  delete from public.marketing_message_events where org_id = v_org and client_id = any(v_clientes);
  delete from public.transactions where org_id = v_org
    and (client_id = any(v_clientes) or sale_id = any(v_vendas) or id = any(v_lancs));
  delete from public.sale_payments where org_id = v_org and sale_id = any(v_vendas);
  delete from public.sale_items where org_id = v_org and sale_id = any(v_vendas);
  delete from public.sales where org_id = v_org and id = any(v_vendas);
  delete from public.checkout_requests where org_id = v_org and appointment_id = any(v_ags);
  delete from public.appointment_items where org_id = v_org and appointment_id = any(v_ags);
  delete from public.appointment_status_history where org_id = v_org and appointment_id = any(v_ags);
  delete from public.anamneses where org_id = v_org and (client_id = any(v_clientes) or appointment_id = any(v_ags));
  delete from public.appointments where org_id = v_org and id = any(v_ags);
  delete from public.clients where org_id = v_org and id = any(v_clientes);
  delete from public.time_blocks where org_id = v_org and staff_id = any(v_profs);
  delete from public.payables where org_id = v_org and id = any(v_contas);
  perform set_config('session_replication_role', 'origin', true);
end $$;

\ir 02_v25/10_cadastros.sql
\ir 02_v25/20_agenda.sql
\ir 02_v25/30_financeiro.sql
\ir 02_v25/40_datas.sql

commit;

-- ─── Resumo ──────────────────────────────────────────────────
select 'profissionais' as dado, count(*) from public.staff_members where org_id = :'org_id' and id in (md5(:'org_id' || 'prof-karenn')::uuid, md5(:'org_id' || 'prof-bruna')::uuid)
union all select 'serviços', count(*) from public.services where org_id = :'org_id' and id in (select md5(:'org_id' || 'servico-' || k)::uuid from unnest(array['shadow','microblading','brows_repair','retoque_anual','aquarele','lip_blush','hydragloss','diseno_lujo','diseno_basico','laminado','henna','depilacao','limpieza_profunda','peeling','hidratacao','limpieza_express','dermaplaning']) k)
union all select 'clientes', count(*) from public.clients where org_id = :'org_id' and id in (select md5(:'org_id' || 'cliente-' || lpad(n::text, 2, '0'))::uuid from generate_series(1, 30) n)
union all select 'agendamentos', count(*) from public.appointments a join public.clients c on c.id = a.client_id where a.org_id = :'org_id' and c.id in (select md5(:'org_id' || 'cliente-' || lpad(n::text, 2, '0'))::uuid from generate_series(1, 30) n)
union all select 'comandas', count(*) from public.sales s where s.org_id = :'org_id' and s.client_id in (select md5(:'org_id' || 'cliente-' || lpad(n::text, 2, '0'))::uuid from generate_series(1, 30) n)
union all select 'fichas', count(*) from public.anamneses f where f.org_id = :'org_id' and f.client_id in (select md5(:'org_id' || 'cliente-' || lpad(n::text, 2, '0'))::uuid from generate_series(1, 30) n)
union all select 'contas a pagar', count(*) from public.payables where org_id = :'org_id' and id in (select md5(:'org_id' || 'conta-' || lpad(n::text, 2, '0'))::uuid from generate_series(1, 14) n);
