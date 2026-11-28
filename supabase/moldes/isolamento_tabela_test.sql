-- MOLDE do teste de isolamento por estúdio (spec 20261128-010000-banco-ligacao, CA-07; plan.md §5).
-- Fica fora de supabase/tests/ para não rodar. Cada spec de módulo copia para
-- supabase/tests/database/<nnn>_isolamento_<tabela>_test.sql e troca os marcadores:
--   <tabela>          nome da tabela em public (tem org_id not null, RLS e índice por org_id)
--   <colunas>         colunas obrigatórias para criar uma linha, além de org_id
--   <valores_a>       valores dessas colunas para a linha de A (fictícios, escritos do zero)
--   <valores_b>       idem para B
--   <coluna_texto>    uma coluna que a dona pode alterar
--   <papel_sem_escrita>  um papel que a matriz do módulo não deixa gravar (se houver; senão apague o bloco)
-- Mantenha as provas: A não lê, não cria, não altera e não apaga linha de B; sem papel e sem login nada.
-- O preparo de pessoas e estúdios é igual ao de 020_isolamento_estudios_test.sql (copie de lá).
begin;
select plan(9);

-- [preparo: copie de 020_isolamento_estudios_test.sql]

insert into public.<tabela> (org_id, <colunas>) values
  ('00000000-0000-0000-0000-00000000000a', <valores_a>),
  ('00000000-0000-0000-0000-00000000000b', <valores_b>);

-- dona de A
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*)::int from public.<tabela> where org_id = '00000000-0000-0000-0000-00000000000b'),
  0, 'A não lê <tabela> de B');
select throws_ok(
  $$insert into public.<tabela> (org_id, <colunas>) values ('00000000-0000-0000-0000-00000000000b', <valores_b>)$$,
  '42501', null, 'A não cria <tabela> em B');
select results_eq(
  $$with u as (update public.<tabela> set <coluna_texto> = <coluna_texto> where org_id = '00000000-0000-0000-0000-00000000000b' returning 1)
    select count(*)::int from u$$,
  array[0], 'A não altera <tabela> de B (0 linhas)');
select results_eq(
  $$with u as (delete from public.<tabela> where org_id = '00000000-0000-0000-0000-00000000000b' returning 1)
    select count(*)::int from u$$,
  array[0], 'A não apaga <tabela> de B (0 linhas)');
reset role;
select is((select count(*)::int from public.<tabela> where org_id = '00000000-0000-0000-0000-00000000000b'),
  1, 'B continua com a sua linha');

-- pessoa sem papel
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c1","role":"authenticated"}', true);
set local role authenticated;
select is_empty('select 1 from public.<tabela>', 'sem papel não lê <tabela>');
select throws_ok(
  $$insert into public.<tabela> (org_id, <colunas>) values ('00000000-0000-0000-0000-00000000000a', <valores_a>)$$,
  '42501', null, 'sem papel não cria <tabela>');
reset role;

-- sem login
select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_ok('select 1 from public.<tabela>', '42501', null, 'sem login não lê <tabela>');
select throws_ok($$delete from public.<tabela>$$, '42501', null, 'sem login não apaga <tabela>');
reset role;

select * from finish();
rollback;
