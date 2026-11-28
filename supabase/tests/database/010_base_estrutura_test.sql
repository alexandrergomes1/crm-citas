-- Item 3 · spec 20261128-010000-banco-ligacao · plan.md §5 · CA-03 e CA-06: estrutura da trava (vale para toda tabela futura de public)
-- Molde oficial: https://supabase.com/docs/guides/local-development/testing/overview
-- Login simulado: set_config('request.jwt.claims') + set local role authenticated (é o que auth.uid() lê).
-- Lista de privilégios atualizada pela spec 20261128-030000-entrar-servico (plan.md §6; ADR 0019 · D17 substitui
-- a linha D9 do ADR 0005): anon só as funções de entrar e o pré-pedido; authenticated só as da sessão e da trava,
-- mais app.pode, a função da matriz de permissões (ADR 0020 · D7; ADR 0019 · D21).
begin;
select plan(25);

-- Preparo (como postgres): pessoas e estúdios fictícios, escritos do zero (RG-07).
-- A = ...0a · B = ...0b · a1 dona A · a2 recepção A · a3 profissional A · b1 dona B
-- c1 e e1 sem papel · d1 vínculo inativo em A · f1 profissional em A (atual) e recepção em B
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'a1@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000a2', 'a2@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000a3', 'a3@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000b1', 'b1@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000c1', 'c1@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000d1', 'd1@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000e1', 'e1@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000f1', 'f1@exemplo.test');

insert into public.estudios (org_id, nome, moeda, idioma, fuso_horario) values
  ('00000000-0000-0000-0000-00000000000a', 'Estudio A', 'EUR', 'pt', 'Europe/Lisbon'),
  ('00000000-0000-0000-0000-00000000000b', 'Estudio B', 'EUR', 'es', 'Europe/Madrid');

insert into public.membros (org_id, user_id, papel, ativo, estudio_atual) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a1', 'dona', true, true),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a2', 'recepcao', true, true),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a3', 'profissional', true, true),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000b1', 'dona', true, true),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000d1', 'recepcao', false, true),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000f1', 'profissional', true, true),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000f1', 'recepcao', true, false);

select has_table('public', 'estudios', 'existe public.estudios');
select has_table('public', 'membros', 'existe public.membros');

select is(
  (select count(*)::int from pg_catalog.pg_class c
     join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p')
      and not exists (select 1 from pg_catalog.pg_attribute a
                       where a.attrelid = c.oid and a.attname = 'org_id'
                         and a.attnotnull and not a.attisdropped)),
  0, 'toda tabela de public tem org_id não nulo');

select is(
  (select count(*)::int from pg_catalog.pg_class c
     join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity),
  0, 'toda tabela de public tem RLS ligada');

select is(
  (select count(*)::int from pg_catalog.pg_class c
     join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relforcerowsecurity),
  0, 'toda tabela de public tem RLS forçada');

select is(
  (select count(*)::int from pg_catalog.pg_class c
     join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p')
      and not exists (select 1 from pg_catalog.pg_index i
                       join pg_catalog.pg_attribute a on a.attrelid = i.indrelid and a.attnum = i.indkey[0]
                      where i.indrelid = c.oid and a.attname = 'org_id')),
  0, 'toda tabela de public tem índice que começa por org_id');

select is(
  (select count(*)::int from information_schema.role_table_grants
    where grantee = 'anon' and table_schema = 'public'),
  0, 'anon sem privilégio em tabela de public');
select is(
  (select count(*)::int from information_schema.role_column_grants
    where grantee = 'anon' and table_schema = 'public'),
  0, 'anon sem privilégio em coluna de public');

select table_privs_are('public', 'estudios', 'authenticated', array['SELECT'],
  'authenticated só lê estudios (alteração só por coluna)');
select table_privs_are('public', 'membros', 'authenticated', array['SELECT', 'DELETE'],
  'authenticated lê e apaga membros (alterar só por coluna)');
select is(
  (select count(*)::int from information_schema.role_column_grants
    where grantee = 'authenticated' and table_schema = 'public' and table_name = 'membros' and privilege_type = 'INSERT'),
  0, 'authenticated não insere em membros, nem por coluna');

select is(
  (select count(*)::int from pg_catalog.pg_proc p
    where p.pronamespace = 'app'::regnamespace
      and p.proname in ('estudio_da_sessao', 'papel_da_sessao', 'eh_dona', 'escolher_estudio')
      and p.prosecdef and p.proconfig = array['search_path=""']),
  4, 'as 4 funções de app são security definer com search_path vazio');

select is(
  (select coalesce(array_agg(p.oid::regprocedure::text order by p.oid::regprocedure::text collate "C"), array[]::text[])
     from pg_catalog.pg_proc p
    where p.pronamespace in ('public'::regnamespace, 'app'::regnamespace)
      and pg_catalog.has_function_privilege('anon', p.oid, 'execute')),
  array['app.antes_do_pedido()', 'app.conferir_tentativa(bytea,bytea)', 'app.registrar_tentativa_falha(uuid)',
        'conferir_tentativa(bytea,bytea)', 'registrar_tentativa_falha(uuid)'],
  'anon executa só o pré-pedido e as duas funções de entrar');
select is(
  (select coalesce(array_agg(p.oid::regprocedure::text order by p.oid::regprocedure::text collate "C"), array[]::text[])
     from pg_catalog.pg_proc p
    where p.pronamespace in ('public'::regnamespace, 'app'::regnamespace)
      and pg_catalog.has_function_privilege('authenticated', p.oid, 'execute')),
  array['app.antes_do_pedido()', 'app.contexto_da_sessao()', 'app.eh_dona()', 'app.encerrar_sessao(uuid)',
        'app.escolher_estudio(uuid)', 'app.escolher_estudio_da_sessao(uuid,uuid)', 'app.estudio_da_sessao()',
        'app.iniciar_sessao(uuid)', 'app.meus_estudios()', 'app.papel_da_sessao()', 'app.pode(text,text)',
        'app.registrar_recusa(text,text,uuid)',
        'contexto_da_sessao()', 'encerrar_sessao(uuid)', 'escolher_estudio(uuid,uuid)', 'iniciar_sessao(uuid)',
        'meus_estudios()', 'registrar_recusa(text,text,uuid)'],
  'authenticated executa só as funções da trava, da sessão, da matriz e o pré-pedido');
select is(
  (select coalesce(array_agg(p.oid::regprocedure::text order by p.oid::regprocedure::text collate "C"), array[]::text[])
     from pg_catalog.pg_proc p
    where p.pronamespace in ('public'::regnamespace, 'app'::regnamespace)
      and pg_catalog.has_function_privilege('service_role', p.oid, 'execute')),
  array['app.antes_do_pedido()'],
  'service_role executa só o pré-pedido (ADR 0019 · D17)');
select is(
  (select coalesce(array_agg(p.oid::regprocedure::text order by p.oid::regprocedure::text collate "C"), array[]::text[])
     from pg_catalog.pg_proc p
    where p.pronamespace in ('public'::regnamespace, 'app'::regnamespace)
      and pg_catalog.has_function_privilege('public', p.oid, 'execute')),
  array[]::text[], 'nenhuma função de public ou app executável por public');
select is(
  (select count(*)::int from pg_catalog.pg_proc p
    where p.pronamespace = 'public'::regnamespace and p.prosecdef),
  0, 'nenhuma função security definer em public (só passagens security invoker)');
select is(
  (select count(*)::int from pg_catalog.pg_proc p
    where p.pronamespace in ('public'::regnamespace, 'app'::regnamespace)
      and (p.proconfig is null or not (p.proconfig @> array['search_path=""']))),
  0, 'toda função de public e app tem search_path vazio');
select is(
  (select count(*)::int from pg_catalog.pg_class c
     join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where c.relkind = 'S' and n.nspname in ('public', 'app')
      and (pg_catalog.has_sequence_privilege('anon', c.oid, 'usage, select, update')
           or pg_catalog.has_sequence_privilege('authenticated', c.oid, 'usage, select, update'))),
  0, 'anon e authenticated sem uso de sequência em public e app');
select is(
  (select count(*)::int from pg_catalog.pg_class c
     join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'app' and c.relkind in ('r', 'p', 'v', 'm')
      and (pg_catalog.has_table_privilege('anon', c.oid, 'select, insert, update, delete, truncate, references, trigger')
           or pg_catalog.has_table_privilege('authenticated', c.oid, 'select, insert, update, delete, truncate, references, trigger'))),
  0, 'anon e authenticated sem privilégio em tabela de app (o uso do esquema serve só às funções)');
select is(
  (select count(*)::int from pg_catalog.pg_class c
     join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'app' and c.relkind in ('r', 'p') and not (c.relrowsecurity and c.relforcerowsecurity)),
  0, 'toda tabela de app tem RLS ligada e forçada');
select is(
  (select count(*)::int from pg_catalog.pg_publication_tables t where t.pubname = 'supabase_realtime'),
  0, 'nenhuma tabela na publicação do Realtime');
select is(
  case when pg_catalog.to_regclass('storage.buckets') is null then 0
       else ((pg_catalog.xpath('/row/n/text()',
               pg_catalog.query_to_xml('select count(*) as n from storage.buckets', false, true, '')))[1])::text::int
  end,
  0, 'nenhum balde de Storage');

select is(
  (select count(*)::int from pg_catalog.pg_proc p
    where p.pronamespace = 'app'::regnamespace
      and p.proname in ('estudio_da_sessao', 'papel_da_sessao', 'eh_dona') and p.pronargs > 0),
  0, 'a checagem não recebe parâmetro (o estúdio não vem do pedido)');

select ok(not pg_catalog.has_function_privilege('authenticated', 'app.conferir_fuso()', 'execute'),
  'authenticated não chama o gatilho do fuso direto');

select * from finish();
rollback;
