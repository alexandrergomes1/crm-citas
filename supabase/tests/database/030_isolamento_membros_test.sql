-- Item 3 · spec 20261128-010000-banco-ligacao · plan.md §5 · CA-04 e CA-05: isolamento de public.membros
-- Molde oficial: https://supabase.com/docs/guides/local-development/testing/overview
-- Login simulado: set_config('request.jwt.claims') + set local role authenticated (é o que auth.uid() lê).
begin;
select plan(17);

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

-- dona de A
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from public.membros where org_id = '00000000-0000-0000-0000-00000000000b'),
  0, 'dona de A não lê vínculos de B');
select is((select count(*)::int from public.membros), 5, 'dona de A lê os 5 vínculos de A');
select throws_ok(
  $$insert into public.membros (org_id, user_id, papel) values ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000c1', 'dona')$$,
  '42501', null, 'dona de A não cria vínculo em B');
select lives_ok(
  $$insert into public.membros (org_id, user_id, papel) values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000e1', 'profissional')$$,
  'dona de A cria vínculo em A');
select results_eq(
  $$with u as (update public.membros set papel = 'profissional' where org_id = '00000000-0000-0000-0000-00000000000b' returning 1)
    select count(*)::int from u$$,
  array[0], 'dona de A não altera vínculo de B (0 linhas)');
select results_eq(
  $$with u as (delete from public.membros where org_id = '00000000-0000-0000-0000-00000000000b' returning 1)
    select count(*)::int from u$$,
  array[0], 'dona de A não apaga vínculo de B (0 linhas)');
select throws_ok(
  $$update public.membros set estudio_atual = true where user_id = '00000000-0000-0000-0000-0000000000e1'$$,
  '42501', null, 'ninguém grava estudio_atual direto');
select throws_ok(
  $$update public.membros set org_id = '00000000-0000-0000-0000-00000000000b' where user_id = '00000000-0000-0000-0000-0000000000a3'$$,
  '42501', null, 'ninguém troca o org_id de um vínculo');
reset role;
select is((select count(*)::int from public.membros where org_id = '00000000-0000-0000-0000-00000000000b'),
  2, 'B continua com os 2 vínculos');

-- recepção e profissional de A
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(
  $$insert into public.membros (org_id, user_id, papel) values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000c1', 'dona')$$,
  '42501', null, 'recepção de A não cria vínculo');
select results_eq(
  $$with u as (update public.membros set papel = 'dona' where user_id = '00000000-0000-0000-0000-0000000000a2' returning 1)
    select count(*)::int from u$$,
  array[0], 'recepção de A não se promove a dona');
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a3","role":"authenticated"}', true);
set local role authenticated;
select results_eq(
  $$with u as (delete from public.membros where org_id = '00000000-0000-0000-0000-00000000000a' returning 1)
    select count(*)::int from u$$,
  array[0], 'profissional de A não apaga vínculo');
reset role;

-- pessoa sem papel e vínculo inativo
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c1","role":"authenticated"}', true);
set local role authenticated;
select is_empty('select 1 from public.membros', 'pessoa sem papel não lê vínculo nenhum');
select throws_ok(
  $$insert into public.membros (org_id, user_id, papel) values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000c1', 'dona')$$,
  '42501', null, 'pessoa sem papel não se põe num estúdio');
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d1","role":"authenticated"}', true);
set local role authenticated;
select results_eq('select org_id from public.membros',
  array['00000000-0000-0000-0000-00000000000a'::uuid], 'vínculo inativo só vê a própria linha, nada mais de A');
reset role;

-- sem login
select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_ok('select 1 from public.membros', '42501', null, 'sem login não lê membros');
select throws_ok(
  $$insert into public.membros (org_id, user_id, papel) values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000c1', 'dona')$$,
  '42501', null, 'sem login não cria vínculo');
reset role;

select * from finish();
rollback;
