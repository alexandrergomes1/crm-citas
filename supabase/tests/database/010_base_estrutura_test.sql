-- Item 3 · spec 20261128-010000-banco-ligacao · plan.md §5 · CA-03 e CA-06: estrutura da trava (vale para toda tabela futura de public)
-- Molde oficial: https://supabase.com/docs/guides/local-development/testing/overview
-- Login simulado: set_config('request.jwt.claims') + set local role authenticated (é o que auth.uid() lê).
begin;
select plan(14);

-- Preparo (como postgres): pessoas e estúdios fictícios, escritos do zero (RG-07).
-- A = ...0a · B = ...0b · a1 dona A · a2 recepção A · a3 profissional A · b1 dona B
-- c1 sem papel · d1 vínculo inativo em A · m1 profissional em A (atual) e recepção em B
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
  'authenticated lê e apaga membros (criar e alterar só por coluna)');

select is(
  (select count(*)::int from pg_catalog.pg_proc p
    where p.pronamespace = 'app'::regnamespace
      and p.proname in ('estudio_da_sessao', 'papel_da_sessao', 'eh_dona', 'escolher_estudio')
      and p.prosecdef and p.proconfig = array['search_path=""']),
  4, 'as 4 funções de app são security definer com search_path vazio');

select is(
  (select count(*)::int from pg_catalog.pg_proc p
    where p.pronamespace = 'app'::regnamespace and pg_catalog.has_function_privilege('anon', p.oid, 'execute')),
  0, 'anon não executa nenhuma função de app');
select ok(not pg_catalog.has_schema_privilege('anon', 'app', 'usage'), 'anon sem uso do esquema app');

select is(
  (select count(*)::int from pg_catalog.pg_proc p
    where p.pronamespace = 'app'::regnamespace
      and p.proname in ('estudio_da_sessao', 'papel_da_sessao', 'eh_dona') and p.pronargs > 0),
  0, 'a checagem não recebe parâmetro (o estúdio não vem do pedido)');

select ok(not pg_catalog.has_function_privilege('authenticated', 'app.conferir_fuso()', 'execute'),
  'authenticated não chama o gatilho do fuso direto');

select * from finish();
rollback;
