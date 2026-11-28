-- MOLDE do teste do gatilho de registro (porta 6) por tabela do estúdio
-- (spec 20261128-030000-entrar-servico, plan.md §6; ADR 0018 · D7; ADR 0019 · D5).
-- Fica fora de supabase/tests/ para não rodar. Cada spec de módulo copia para
-- supabase/tests/database/<nnn>_registro_<tabela>_test.sql e troca os marcadores:
--   <tabela>          nome da tabela em public (org_id, RLS e o gatilho:
--                       create trigger <tabela>_registro after insert or update or delete on public.<tabela>
--                         for each row execute function app.registrar_mudanca('<coluna_id>');)
--   <coluna_id>       coluna uuid que identifica a linha (vai para objetos)
--   <colunas>         colunas obrigatórias para criar uma linha, além de org_id e <coluna_id>
--   <valores_a>       valores dessas colunas para a linha de A (fictícios, escritos do zero)
--   <coluna_texto>    uma coluna que a dona pode alterar
--   <acao_criar>      nome da ação que grava, como na migration do módulo (app.acoes_que_gravam)
-- Mantenha as provas: gravou → uma linha com evento, pessoa, estúdio, objeto e pedido; sem x-acao da lista ou sem
-- x-pedido → recusa e nada fica (RF-27); o texto gravado nunca aparece no registro (RF-25).
-- O preparo de pessoas e estúdios é igual ao de 020_isolamento_estudios_test.sql (copie de lá).
begin;
select plan(6);

-- [preparo: copie de 020_isolamento_estudios_test.sql]

-- dona de A, com os cabeçalhos que o servidor manda (x-acao e x-pedido)
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
select set_config('request.headers', '{"x-acao":"<acao_criar>","x-pedido":"e0000000-0000-0000-0000-000000000001"}', true);
set local role authenticated;
insert into public.<tabela> (org_id, <coluna_id>, <colunas>)
  values ('00000000-0000-0000-0000-00000000000a', 'e1000000-0000-0000-0000-000000000001', <valores_a>);
reset role;
select results_eq(
  $$select evento, resultado, usuario_id, org_id, objetos from app.registro
     where pedido_id = 'e0000000-0000-0000-0000-000000000001'$$,
  $$values ('<acao_criar>'::text, 'ok'::text, '00000000-0000-0000-0000-0000000000a1'::uuid,
            '00000000-0000-0000-0000-00000000000a'::uuid, array['e1000000-0000-0000-0000-000000000001'::uuid])$$,
  'criar <tabela> grava uma linha de registro');
select is((select count(*)::int from app.registro r, public.<tabela> t
            where t.<coluna_id> = 'e1000000-0000-0000-0000-000000000001'
              and pg_catalog.to_jsonb(r)::text like '%' || t.<coluna_texto>::text || '%'),
  0, 'o texto gravado não vai ao registro');

-- sem x-acao
select set_config('request.headers', '{"x-pedido":"e0000000-0000-0000-0000-000000000002"}', true);
set local role authenticated;
select throws_ok($$update public.<tabela> set <coluna_texto> = <coluna_texto> where <coluna_id> = 'e1000000-0000-0000-0000-000000000001'$$,
  'PGRST', '{"code": "erro_interno", "message": "erro_interno"}', 'sem x-acao: recusa e desfaz');
reset role;
-- x-acao fora da lista
select set_config('request.headers', '{"x-acao":"fora.da.lista","x-pedido":"e0000000-0000-0000-0000-000000000003"}', true);
set local role authenticated;
select throws_ok($$delete from public.<tabela> where <coluna_id> = 'e1000000-0000-0000-0000-000000000001'$$,
  'PGRST', '{"code": "erro_interno", "message": "erro_interno"}', 'x-acao fora da lista: recusa e desfaz');
reset role;
-- sem x-pedido
select set_config('request.headers', '{"x-acao":"<acao_criar>"}', true);
set local role authenticated;
select throws_ok($$delete from public.<tabela> where <coluna_id> = 'e1000000-0000-0000-0000-000000000001'$$,
  'PGRST', '{"code": "erro_interno", "message": "erro_interno"}', 'sem x-pedido: recusa e desfaz');
reset role;
select is((select count(*)::int from public.<tabela> where <coluna_id> = 'e1000000-0000-0000-0000-000000000001'),
  1, 'a linha continua lá (as gravações recusadas foram desfeitas)');

select * from finish();
rollback;
