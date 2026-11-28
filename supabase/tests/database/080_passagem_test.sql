-- Entrar e camada de serviço · spec 20261128-030000-entrar-servico · plan.md §3.3, §6 e §9 · RF-12, RF-13, CA-05, CA-17, CA-18
-- Molde oficial: https://supabase.com/docs/guides/local-development/testing/overview
-- Passagens em public: security invoker (só funcionam com o token da pessoa); quem grava é a função de app.
begin;
select plan(36);

-- Preparo (como postgres): dados fictícios, escritos do zero.
-- a1 dona A · d1 vínculo inativo em A · c1 sem papel · f1 profissional em A (atual) e recepção em B
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'a1@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000c1', 'c1@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000d1', 'd1@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000f1', 'f1@exemplo.test');
insert into public.estudios (org_id, nome, moeda, idioma, fuso_horario) values
  ('00000000-0000-0000-0000-00000000000a', 'Estudio A', 'EUR', 'pt', 'Europe/Lisbon'),
  ('00000000-0000-0000-0000-00000000000b', 'Beleza B', 'EUR', 'es', 'Europe/Madrid');
insert into public.membros (org_id, user_id, papel, ativo, estudio_atual) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a1', 'dona', true, true),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000d1', 'recepcao', false, true),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000f1', 'profissional', true, true),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000f1', 'recepcao', true, false);
insert into app.sessoes (session_id, user_id) values
  ('81000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a1'),
  ('81000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000c1'),
  ('81000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000d1'),
  ('81000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000f1');

-- As 8 passagens: security invoker, search_path vazio, função de app por trás é security definer
select isnt_definer('public', 'iniciar_sessao', array['uuid'], 'iniciar_sessao é security invoker');
select isnt_definer('public', 'encerrar_sessao', array['uuid'], 'encerrar_sessao é security invoker');
select isnt_definer('public', 'contexto_da_sessao', array[]::name[], 'contexto_da_sessao é security invoker');
select isnt_definer('public', 'meus_estudios', array[]::name[], 'meus_estudios é security invoker');
select isnt_definer('public', 'escolher_estudio', array['uuid', 'uuid'], 'escolher_estudio é security invoker (RF-12)');
select isnt_definer('public', 'registrar_recusa', array['text', 'text', 'uuid'], 'registrar_recusa é security invoker');
select isnt_definer('public', 'conferir_tentativa', array['bytea', 'bytea'], 'conferir_tentativa é security invoker');
select isnt_definer('public', 'registrar_tentativa_falha', array['uuid'], 'registrar_tentativa_falha é security invoker');
select is_definer('app', 'escolher_estudio_da_sessao', array['uuid', 'uuid'], 'a gravação da escolha mora em app');
select is_definer('app', 'antes_do_pedido', array[]::name[], 'o pré-pedido é security definer em app');

-- Sem execução para public e anon nas passagens de quem tem login (CA-17)
select ok(not has_function_privilege('public', 'public.escolher_estudio(uuid, uuid)', 'execute'), 'public não executa escolher_estudio');
select ok(not has_function_privilege('anon', 'public.escolher_estudio(uuid, uuid)', 'execute'), 'anon não executa escolher_estudio');
select ok(not has_function_privilege('anon', 'public.meus_estudios()', 'execute'), 'anon não executa meus_estudios');
select ok(not has_function_privilege('anon', 'public.iniciar_sessao(uuid)', 'execute'), 'anon não executa iniciar_sessao');
select ok(not has_function_privilege('anon', 'public.encerrar_sessao(uuid)', 'execute'), 'anon não executa encerrar_sessao');
select ok(not has_function_privilege('anon', 'public.contexto_da_sessao()', 'execute'), 'anon não executa contexto_da_sessao');
select ok(not has_function_privilege('anon', 'public.registrar_recusa(text, text, uuid)', 'execute'), 'anon não executa registrar_recusa');
select ok(not has_function_privilege('authenticated', 'public.conferir_tentativa(bytea, bytea)', 'execute'),
  'authenticated não executa conferir_tentativa (só anon, antes de entrar)');
select ok(not has_function_privilege('public', 'public.conferir_tentativa(bytea, bytea)', 'execute'), 'public não executa conferir_tentativa');

set local role anon;
select throws_ok($$select public.escolher_estudio('00000000-0000-0000-0000-00000000000a', gen_random_uuid())$$,
  '42501', null, 'sem login não escolhe estúdio');
reset role;
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select public.escolher_estudio('00000000-0000-0000-0000-00000000000a', gen_random_uuid())$$,
  'PGRST', '{"code": "sem_login", "message": "sem_login"}', 'token sem pessoa não escolhe');
reset role;

-- Estúdios da pessoa: só os de papel ativo, por nome (RF-13, CA-18)
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000f1","role":"authenticated","session_id":"81000000-0000-0000-0000-0000000000f1"}', true);
set local role authenticated;
select results_eq('select org_id, nome from public.meus_estudios()',
  $$values ('00000000-0000-0000-0000-00000000000b'::uuid, 'Beleza B'::text), ('00000000-0000-0000-0000-00000000000a'::uuid, 'Estudio A'::text)$$,
  'pessoa de A e B vê os dois, por nome');
reset role;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated","session_id":"81000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;
select results_eq('select org_id from public.meus_estudios()', array['00000000-0000-0000-0000-00000000000a'::uuid],
  'pessoa só de A vê só A');
reset role;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000d1","role":"authenticated","session_id":"81000000-0000-0000-0000-0000000000d1"}', true);
set local role authenticated;
select is_empty('select 1 from public.meus_estudios()', 'vínculo inativo não aparece');
reset role;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000c1","role":"authenticated","session_id":"81000000-0000-0000-0000-0000000000c1"}', true);
set local role authenticated;
select is_empty('select 1 from public.meus_estudios()', 'sem papel, nenhum estúdio');
reset role;

-- Escolher e trocar (RF-12, RF-24a, CA-05)
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated","session_id":"81000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;
select throws_ok($$select public.escolher_estudio('00000000-0000-0000-0000-00000000000b', '82000000-0000-0000-0000-000000000001')$$,
  'PGRST', '{"code": "sem_permissao", "message": "sem_permissao"}', 'pessoa só de A não escolhe B');
select is(app.estudio_da_sessao(), '00000000-0000-0000-0000-00000000000a'::uuid, 'e continua em A');
reset role;
select is((select count(*)::int from app.registro where pedido_id = '82000000-0000-0000-0000-000000000001'), 0,
  'a escolha recusada não grava (o servidor registra a recusa)');

select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000f1","role":"authenticated","session_id":"81000000-0000-0000-0000-0000000000f1"}', true);
set local role authenticated;
select ok(public.escolher_estudio('00000000-0000-0000-0000-00000000000a', '82000000-0000-0000-0000-000000000002'),
  'primeira escolha na sessão');
select ok(public.escolher_estudio('00000000-0000-0000-0000-00000000000b', '82000000-0000-0000-0000-000000000003'),
  'troca para B');
select is(app.estudio_da_sessao(), '00000000-0000-0000-0000-00000000000b'::uuid, 'o estúdio da sessão passa a ser B');
select results_eq('select org_id from public.estudios', array['00000000-0000-0000-0000-00000000000b'::uuid],
  'e só B é lido');
reset role;
select results_eq(
  $$select evento, org_id from app.registro where pedido_id in ('82000000-0000-0000-0000-000000000002',
                                                               '82000000-0000-0000-0000-000000000003') order by id$$,
  $$values ('estudio.escolher'::text, '00000000-0000-0000-0000-00000000000a'::uuid),
           ('estudio.trocar'::text, '00000000-0000-0000-0000-00000000000b'::uuid)$$,
  'escolher e trocar gravam o estúdio escolhido (o novo, na troca)');

-- Sessão encerrada não escolhe
update app.sessoes set encerrada_em = now(), motivo_fim = 'sair' where session_id = '81000000-0000-0000-0000-0000000000f1';
set local role authenticated;
select throws_ok($$select public.escolher_estudio('00000000-0000-0000-0000-00000000000a', gen_random_uuid())$$,
  'PGRST', '{"code": "sem_login", "message": "sem_login"}', 'sessão encerrada não escolhe estúdio');
select is(app.estudio_da_sessao(), '00000000-0000-0000-0000-00000000000b'::uuid, 'e nada muda');
reset role;
select is((select count(*)::int from app.registro r where r.evento like 'estudio.%' and r.usuario_id = '00000000-0000-0000-0000-0000000000f1'),
  2, 'só as duas escolhas válidas ficaram no registro');

select * from finish();
rollback;
