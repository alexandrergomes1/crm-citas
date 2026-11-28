-- Item 3 · spec 20261128-010000-banco-ligacao · plan.md §5 · CA-04 e CA-05: isolamento de public.estudios
-- Molde oficial: https://supabase.com/docs/guides/local-development/testing/overview
-- Login simulado: set_config('request.jwt.claims') + set local role authenticated (é o que auth.uid() lê).
begin;
select plan(13);

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

-- dona de A
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
set local role authenticated;

select results_eq('select org_id from public.estudios',
  array['00000000-0000-0000-0000-00000000000a'::uuid], 'dona de A lê só A');
select results_eq(
  $$with u as (update public.estudios set nome = 'Invadido' where org_id = '00000000-0000-0000-0000-00000000000b' returning 1)
    select count(*)::int from u$$,
  array[0], 'dona de A não altera B (0 linhas)');
select results_eq(
  $$with u as (update public.estudios set nome = 'Estudio A2' where org_id = '00000000-0000-0000-0000-00000000000a' returning 1)
    select count(*)::int from u$$,
  array[1], 'dona de A altera A');
select throws_ok(
  $$insert into public.estudios (nome, moeda, idioma, fuso_horario) values ('Novo', 'EUR', 'pt', 'Europe/Lisbon')$$,
  '42501', null, 'ninguém com login cria estúdio');
select throws_ok($$delete from public.estudios where org_id = '00000000-0000-0000-0000-00000000000b'$$,
  '42501', null, 'ninguém com login apaga estúdio (B)');
select throws_ok($$delete from public.estudios where org_id = '00000000-0000-0000-0000-00000000000a'$$,
  '42501', null, 'ninguém com login apaga estúdio (o próprio)');
reset role;
select is((select nome from public.estudios where org_id = '00000000-0000-0000-0000-00000000000b'),
  'Estudio B', 'B continua igual');

-- recepção de A
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}', true);
set local role authenticated;
select results_eq(
  $$with u as (update public.estudios set nome = 'Recepcao mudou' where org_id = '00000000-0000-0000-0000-00000000000a' returning 1)
    select count(*)::int from u$$,
  array[0], 'recepção de A não altera A');
select results_eq('select org_id from public.estudios',
  array['00000000-0000-0000-0000-00000000000a'::uuid], 'recepção de A lê só A');
reset role;

-- pessoa sem papel
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c1","role":"authenticated"}', true);
set local role authenticated;
select is_empty('select 1 from public.estudios', 'pessoa sem papel não lê nenhum estúdio');
reset role;

-- vínculo inativo
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d1","role":"authenticated"}', true);
set local role authenticated;
select is_empty('select 1 from public.estudios', 'vínculo inativo não lê nenhum estúdio');
reset role;

-- sem login
select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_ok('select 1 from public.estudios', '42501', null, 'sem login não lê estudios');
select throws_ok($$update public.estudios set nome = 'x'$$, '42501', null, 'sem login não altera estudios');
reset role;

select * from finish();
rollback;
