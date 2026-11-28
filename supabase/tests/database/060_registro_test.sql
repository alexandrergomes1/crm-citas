-- Entrar e camada de serviço · spec 20261128-030000-entrar-servico · plan.md §6 e §9 · CA-09, CA-10, CA-11, RF-24 a RF-27
-- Molde oficial: https://supabase.com/docs/guides/local-development/testing/overview
-- Login simulado: set_config('request.jwt.claims') + set local role authenticated; cabeçalhos em request.headers.
begin;
select plan(28);

-- Preparo (como postgres): dados fictícios, escritos do zero. A = ...0a · B = ...0b · a1 dona A · b1 dona B
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'a1@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000b1', 'b1@exemplo.test');
insert into public.estudios (org_id, nome, moeda, idioma, fuso_horario) values
  ('00000000-0000-0000-0000-00000000000a', 'Estudio A', 'EUR', 'pt', 'Europe/Lisbon'),
  ('00000000-0000-0000-0000-00000000000b', 'Estudio B', 'EUR', 'es', 'Europe/Madrid');
insert into public.membros (org_id, user_id, papel, ativo, estudio_atual) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a1', 'dona', true, true),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000b1', 'dona', true, true);

-- Tabela de módulo de faz de conta, com a trava e o gatilho de registro (some no rollback).
create table public.teste_registro (
  org_id uuid not null references public.estudios (org_id),
  id     uuid not null default gen_random_uuid() primary key,
  texto  text not null
);
alter table public.teste_registro enable row level security;
alter table public.teste_registro force row level security;
grant select, insert, update, delete on table public.teste_registro to authenticated;
create policy teste_registro_tudo on public.teste_registro for all to authenticated
  using (org_id = (select app.estudio_da_sessao())) with check (org_id = (select app.estudio_da_sessao()));
create trigger teste_registro_registro after insert or update or delete on public.teste_registro
  for each row execute function app.registrar_mudanca('id');
insert into app.acoes_que_gravam (acao) values ('teste.registro.gravar');

-- Estrutura e privilégios
select has_table('app', 'registro', 'existe app.registro');
select table_privs_are('app', 'registro', 'anon', array[]::text[], 'anon sem privilégio no registro');
select table_privs_are('app', 'registro', 'authenticated', array[]::text[], 'authenticated sem privilégio no registro');
select ok((select c.relrowsecurity and c.relforcerowsecurity from pg_catalog.pg_class c where c.oid = 'app.registro'::regclass),
  'registro com RLS ligada e forçada');

-- Ninguém altera nem apaga (nem o dono da tabela)
insert into app.registro (evento, resultado, usuario_id, org_id, pedido_id) values
  ('teste.linha', 'ok', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000000a',
   '10000000-0000-0000-0000-000000000001');
select throws_ok($$update app.registro set resultado = 'conflito'$$, '42501', null, 'registro não se altera');
select throws_ok($$delete from app.registro$$, '42501', null, 'registro não se apaga');
select throws_ok($$truncate app.registro$$, '42501', null, 'registro não se esvazia');

-- Forma da linha (nada de texto livre)
select throws_ok($$insert into app.registro (evento, resultado, pedido_id) values ('Texto Livre', 'ok', gen_random_uuid())$$,
  '23514', null, 'evento só com [a-z_.]');
select throws_ok($$insert into app.registro (evento, resultado, pedido_id) values ('teste.linha', 'qualquer', gen_random_uuid())$$,
  '23514', null, 'resultado só da lista fechada');
select throws_ok($$insert into app.registro (evento, resultado, usuario_id, pedido_id)
                   values ('sessao.entrar', 'sem_login', '00000000-0000-0000-0000-0000000000a1', gen_random_uuid())$$,
  '23514', null, 'falha de entrar não guarda pessoa');
select throws_ok($$insert into app.registro (evento, resultado, objetos, pedido_id)
                   values ('teste.linha', 'ok', (select array_agg(gen_random_uuid()) from generate_series(1, 11)), gen_random_uuid())$$,
  '23514', null, 'no máximo 10 objetos');

-- Quem tem login não grava direto nem lê
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$insert into app.registro (evento, resultado, pedido_id) values ('teste.linha', 'ok', gen_random_uuid())$$,
  '42501', null, 'authenticated não acrescenta linha direto');
select throws_ok($$select 1 from app.registro$$, '42501', null, 'authenticated não lê o registro');
reset role;
select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_ok($$select 1 from app.registro$$, '42501', null, 'anon não lê o registro');
reset role;

-- Gatilho genérico (porta 6): gravou → linha na mesma transação; sem cabeçalho certo → desfaz (CA-11, RF-27)
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
select set_config('request.headers',
  '{"x-acao":"teste.registro.gravar","x-pedido":"20000000-0000-0000-0000-000000000001"}', true);
set local role authenticated;
insert into public.teste_registro (org_id, id, texto)
  values ('00000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-000000000001', 'texto secreto da cliente');
reset role;
select results_eq(
  $$select evento, resultado, usuario_id, org_id, objetos, pedido_id from app.registro where evento = 'teste.registro.gravar'$$,
  $$values ('teste.registro.gravar'::text, 'ok'::text, '00000000-0000-0000-0000-0000000000a1'::uuid,
            '00000000-0000-0000-0000-00000000000a'::uuid, array['30000000-0000-0000-0000-000000000001'::uuid],
            '20000000-0000-0000-0000-000000000001'::uuid)$$,
  'inserir grava evento, pessoa, estúdio, objeto e pedido');
select is((select count(*)::int from app.registro r where pg_catalog.to_jsonb(r)::text like '%secreto%'),
  0, 'o texto digitado não vai ao registro (CA-09)');

set local role authenticated;
update public.teste_registro set texto = 'outro texto' where id = '30000000-0000-0000-0000-000000000001';
reset role;
select is((select count(*)::int from app.registro where evento = 'teste.registro.gravar'), 2, 'alterar também grava');

select set_config('request.headers', '{"x-pedido":"20000000-0000-0000-0000-000000000002"}', true);
set local role authenticated;
select throws_ok($$insert into public.teste_registro (org_id, texto) values ('00000000-0000-0000-0000-00000000000a', 'sem acao')$$,
  'PGRST', '{"code": "erro_interno", "message": "erro_interno"}', 'sem x-acao: recusa');
reset role;
select set_config('request.headers',
  '{"x-acao":"fora.da.lista","x-pedido":"20000000-0000-0000-0000-000000000003"}', true);
set local role authenticated;
select throws_ok($$insert into public.teste_registro (org_id, texto) values ('00000000-0000-0000-0000-00000000000a', 'fora')$$,
  'PGRST', '{"code": "erro_interno", "message": "erro_interno"}', 'x-acao fora da lista: recusa');
reset role;
select set_config('request.headers', '{"x-acao":"teste.registro.gravar","x-pedido":"nao-e-uuid"}', true);
set local role authenticated;
select throws_ok($$delete from public.teste_registro$$,
  'PGRST', '{"code": "erro_interno", "message": "erro_interno"}', 'x-pedido fora do formato: recusa');
reset role;
select is((select count(*)::int from public.teste_registro), 1, 'as gravações recusadas foram desfeitas (CA-11)');
select is((select count(*)::int from app.registro where evento = 'teste.registro.gravar'), 2,
  'e nenhuma linha de registro sobrou delas');

-- Recusa nas portas 2 a 5: só a própria pessoa, código da lista, teto por pessoa
select set_config('request.headers', '{}', true);
set local role authenticated;
select ok(public.registrar_recusa('agenda.bloqueio.criar', 'sem_permissao', '20000000-0000-0000-0000-000000000004'),
  'recusa gravada');
select throws_ok($$select public.registrar_recusa('agenda.bloqueio.criar', 'ok', gen_random_uuid())$$,
  'PGRST', '{"code": "entrada_invalida", "message": "entrada_invalida"}', 'recusa não aceita ok');
select throws_ok($$select public.registrar_recusa('Agenda criar', 'sem_permissao', gen_random_uuid())$$,
  'PGRST', '{"code": "entrada_invalida", "message": "entrada_invalida"}', 'nome de ação só no formato');
select is((select (count(*) filter (where r))::int from (select public.registrar_recusa('agenda.bloqueio.criar', 'entrada_invalida', gen_random_uuid()) r
                                                       from generate_series(1, 31)) t),
  29, 'teto de 30 recusas por pessoa por minuto');
reset role;
select results_eq(
  $$select evento, resultado, usuario_id, org_id from app.registro where pedido_id = '20000000-0000-0000-0000-000000000004'$$,
  $$values ('agenda.bloqueio.criar'::text, 'sem_permissao'::text, '00000000-0000-0000-0000-0000000000a1'::uuid,
            '00000000-0000-0000-0000-00000000000a'::uuid)$$,
  'a linha da recusa tem a pessoa e o estúdio da sessão');
select is((select count(*)::int from app.registro where evento = 'registro.teto'), 1,
  'acima do teto, uma só linha de resumo (limite)');

select * from finish();
rollback;
