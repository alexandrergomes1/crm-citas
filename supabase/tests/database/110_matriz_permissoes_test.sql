-- Spec 20261128-030000-entrar-servico · RF-18 · plan.md §5a · ADR 0020 (D3, D4, D7, D8) · ADR 0019 (D21).
-- Matriz de permissões: a cópia do banco é igual à do código, linha a linha, e a função app.pode decide pela sessão.
-- Molde oficial: https://supabase.com/docs/guides/local-development/testing/overview
-- Login simulado: set_config('request.jwt.claims') + set local role authenticated (é o que auth.uid() lê).
begin;
select plan(29);

-- Matriz do código: JSON.stringify(exportarMatriz()) de src/domain/acesso/matriz.ts, gerado, nunca escrito à mão.
-- supabase/matriz/matriz.test.ts (roda no `pnpm db:test`, antes do pgTAP) fica vermelho se esta linha não for
-- exatamente a exportação atual do código, e mostra a linha certa para colar aqui.
-- matriz-do-codigo:inicio
select set_config('teste.matriz', $json${"chaves":[],"linhas":[]}$json$, true);
-- matriz-do-codigo:fim

-- Estrutura (ADR 0019 · D1 e D21)
select has_table('app', 'chaves_permissao', 'existe app.chaves_permissao');
select has_table('app', 'matriz_permissoes', 'existe app.matriz_permissoes');
select has_index('app', 'matriz_permissoes', 'matriz_permissoes_chave_idx', array['chave'],
  'a chave estrangeira da matriz para o catálogo tem índice próprio');
select is(
  (select count(*)::int from pg_catalog.pg_class c
    where c.oid in ('app.chaves_permissao'::regclass, 'app.matriz_permissoes'::regclass)
      and c.relrowsecurity and c.relforcerowsecurity),
  2, 'catálogo e matriz com RLS ligada e forçada');
select is(
  (select count(*)::int from pg_catalog.pg_class c, unnest(array['anon', 'authenticated', 'service_role']) r(papel)
    where c.oid in ('app.chaves_permissao'::regclass, 'app.matriz_permissoes'::regclass)
      and pg_catalog.has_table_privilege(r.papel, c.oid, 'select, insert, update, delete, truncate, references, trigger')),
  0, 'ninguém com login (nem service_role) lê ou grava o catálogo e a matriz direto');
select is(
  (select count(*)::int from pg_catalog.pg_proc p
    where p.oid = 'app.pode(text,text)'::regprocedure
      and p.prosecdef and p.proconfig = array['search_path=""'] and p.provolatile = 's'),
  1, 'app.pode(chave, alcance): só chave e alcance (sem estúdio), security definer, search_path vazio, stable');

-- Comparação linha a linha com o código (ADR 0020 · D8): sobra no banco ou falta no banco → vermelho.
select set_eq(
  $$select chave from app.chaves_permissao$$,
  $$select jsonb_array_elements_text(current_setting('teste.matriz')::jsonb -> 'chaves')$$,
  'catálogo de chaves do banco = catálogo do código');
select set_eq(
  $$select papel, chave, alcance from app.matriz_permissoes$$,
  $$select l ->> 'papel' as papel, l ->> 'chave' as chave, l ->> 'alcance' as alcance
      from jsonb_array_elements(current_setting('teste.matriz')::jsonb -> 'linhas') l$$,
  'matriz do banco = matriz do código (papel, chave, alcance)');
select is(
  (select coalesce(array_agg(distinct m.r[1] order by m.r[1]), array[]::text[])
     from pg_catalog.pg_policies p,
          lateral regexp_matches(coalesce(p.qual, '') || ' ' || coalesce(p.with_check, ''),
                                 'app\.pode\(''([^'']+)''', 'g') m(r)
    where not exists (select 1 from app.chaves_permissao c where c.chave = m.r[1])),
  array[]::text[], 'toda chave usada por política existe no catálogo');

-- A tabela recusa o que a regra proíbe (ADR 0020 · D2, D4)
select throws_ok($$insert into app.matriz_permissoes (papel, chave, alcance) values ('dona', 'x.ver', 'todos')$$,
  '23514', null, 'a dona não tem linha (tem tudo por regra fixa)');
select throws_ok($$insert into app.matriz_permissoes (papel, chave, alcance) values ('recepcao', 'fora.ver', 'todos')$$,
  '23503', null, 'linha com chave fora do catálogo é recusada');

-- Preparo (como postgres): pessoas, estúdios e um catálogo fictício só desta transação (RG-07).
-- A = ...0a · B = ...0b · a1 dona A · a2 recepção A · a3 profissional A
-- c1 sem papel · d1 vínculo inativo em A · f1 profissional em A (atual) e recepção em B
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'a1@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000a2', 'a2@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000a3', 'a3@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000c1', 'c1@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000d1', 'd1@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000f1', 'f1@exemplo.test');

insert into public.estudios (org_id, nome, moeda, idioma, fuso_horario) values
  ('00000000-0000-0000-0000-00000000000a', 'Estudio A', 'EUR', 'pt', 'Europe/Lisbon'),
  ('00000000-0000-0000-0000-00000000000b', 'Estudio B', 'EUR', 'es', 'Europe/Madrid');

insert into public.membros (org_id, user_id, papel, ativo, estudio_atual) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a1', 'dona', true, true),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a2', 'recepcao', true, true),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a3', 'profissional', true, true),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000d1', 'recepcao', false, true),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000f1', 'profissional', true, true),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000f1', 'recepcao', true, false);

insert into app.chaves_permissao (chave) values ('teste.ver'), ('teste.remover');
insert into app.matriz_permissoes (papel, chave, alcance) values
  ('recepcao', 'teste.ver', 'todos'),
  ('profissional', 'teste.ver', 'proprios');

-- dona de A: tudo no catálogo, nada fora dele (ADR 0020 · D4; ASVS V4.1.5)
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
set local role authenticated;
select is(app.pode('teste.ver', 'todos'), true, 'dona pode chave com linha');
select is(app.pode('teste.remover', 'todos'), true, 'dona pode chave sem linha (tem tudo)');
select is(app.pode('nao.existe', 'todos'), false, 'dona não pode chave fora do catálogo');
select is(app.pode('teste.ver', 'qualquer'), false, 'alcance fora da lista = não');
select is(app.pode(null, 'todos'), false, 'chave nula = não');
reset role;

-- recepção de A: todos em teste.ver; teste.remover ausente
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}', true);
set local role authenticated;
select is(app.pode('teste.ver', 'todos'), true, 'recepção com todos pode o que pede todos');
select is(app.pode('teste.ver', 'proprios'), true, 'quem tem todos também passa onde basta próprios');
select is(app.pode('teste.remover', 'proprios'), false, 'célula ausente = não pode');
reset role;

-- profissional de A: só próprios em teste.ver
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a3","role":"authenticated"}', true);
set local role authenticated;
select is(app.pode('teste.ver', 'proprios'), true, 'profissional com próprios passa onde basta próprios');
select is(app.pode('teste.ver', 'todos'), false, 'profissional com próprios não passa onde pede todos');
select is(app.pode('nao.existe', 'proprios'), false, 'chave fora do catálogo = não');
reset role;

-- o papel é o do estúdio da sessão
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f1","role":"authenticated"}', true);
set local role authenticated;
select is(app.pode('teste.ver', 'todos'), false, 'profissional em A (escolhido): não tem todos');
select ok(app.escolher_estudio('00000000-0000-0000-0000-00000000000b'), 'ela escolhe B');
select is(app.pode('teste.ver', 'todos'), true, 'em B é recepção: passa a ter todos');
reset role;

-- falha fechada: sem papel, vínculo inativo, sem login
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c1","role":"authenticated"}', true);
set local role authenticated;
select is(app.pode('teste.ver', 'proprios'), false, 'sem papel em estúdio nenhum = não');
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d1","role":"authenticated"}', true);
set local role authenticated;
select is(app.pode('teste.ver', 'proprios'), false, 'vínculo inativo = não');
reset role;
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
set local role authenticated;
select is(app.pode('teste.ver', 'proprios'), false, 'sem sub no token = não');
reset role;
select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_ok($$select app.pode('teste.ver', 'todos')$$, '42501', null, 'sem login não chama a função');
reset role;

select * from finish();
rollback;
