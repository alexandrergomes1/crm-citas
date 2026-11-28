-- Entrar e camada de serviço · spec 20261128-030000-entrar-servico · plan.md §3.1, §3.4, §6 e §9 · RF-05 a RF-07, CA-13, CA-15
-- Molde oficial: https://supabase.com/docs/guides/local-development/testing/overview
-- Token simulado em request.jwt.claims (sub, session_id e amr como o Supabase Auth emite); tempo empurrado para
-- trás nas linhas de app.sessoes (relógio controlado, CA-15). A sessão nunca ressuscita.
begin;
select plan(35);

-- Preparo (como postgres): dados fictícios, escritos do zero.
-- a1 dona A · a2 recepção A · a3 profissional A · c1 sem papel · g1 recepção em B, sem estúdio escolhido
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'a1@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000a2', 'a2@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000a3', 'a3@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000c1', 'c1@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000e1', 'e1@exemplo.test');
insert into public.estudios (org_id, nome, moeda, idioma, fuso_horario) values
  ('00000000-0000-0000-0000-00000000000a', 'Estudio A', 'EUR', 'pt', 'Europe/Lisbon'),
  ('00000000-0000-0000-0000-00000000000b', 'Estudio B', 'EUR', 'es', 'Europe/Madrid');
insert into public.membros (org_id, user_id, papel, ativo, estudio_atual) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a1', 'dona', true, true),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a2', 'recepcao', true, true),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a3', 'profissional', true, true),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000e1', 'recepcao', true, false);

-- Token de entrada por senha agora (amr.timestamp = agora - p_segundos).
create function pg_temp.token(p_sub text, p_sessao text, p_segundos int default 0, p_metodo text default 'password')
returns void language sql as $$
  select set_config('request.jwt.claims', pg_catalog.jsonb_build_object(
    'sub', p_sub, 'role', 'authenticated', 'session_id', p_sessao,
    'amr', pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'method', p_metodo, 'timestamp', extract(epoch from now())::bigint - p_segundos)))::text, true)
$$;

select has_table('app', 'sessoes', 'existe app.sessoes');
select table_privs_are('app', 'sessoes', 'authenticated', array[]::text[], 'authenticated sem privilégio em app.sessoes');

-- Entrar
select pg_temp.token('00000000-0000-0000-0000-0000000000a1', '51000000-0000-0000-0000-000000000001');
set local role authenticated;
select is(public.iniciar_sessao('52000000-0000-0000-0000-000000000001'), 1, 'entrar devolve o número de estúdios ativos');
select is((select org_id from public.contexto_da_sessao()), '00000000-0000-0000-0000-00000000000a'::uuid,
  'contexto traz o estúdio da sessão');
select is((select papel from public.contexto_da_sessao()), 'dona', 'contexto traz o papel');
select is((select idioma from public.contexto_da_sessao()), 'pt', 'contexto traz o idioma do estúdio');
select throws_ok($$select public.iniciar_sessao(gen_random_uuid())$$,
  'PGRST', '{"code": "sem_login", "message": "sem_login"}', 'o mesmo session_id não inicia duas vezes');
reset role;
select results_eq(
  $$select evento, resultado, usuario_id, org_id from app.registro where pedido_id = '52000000-0000-0000-0000-000000000001'$$,
  $$values ('sessao.entrar'::text, 'ok'::text, '00000000-0000-0000-0000-0000000000a1'::uuid, null::uuid)$$,
  'entrar grava sessao.entrar com a pessoa e o estúdio vazio (RF-24a)');

-- Entrada antiga, sem senha ou sem session_id: recusada, nenhuma linha nasce
select pg_temp.token('00000000-0000-0000-0000-0000000000a1', '51000000-0000-0000-0000-000000000002', 61);
set local role authenticated;
select throws_ok($$select public.iniciar_sessao(gen_random_uuid())$$,
  'PGRST', '{"code": "sem_login", "message": "sem_login"}', 'senha de mais de 60 s não inicia sessão');
reset role;
select pg_temp.token('00000000-0000-0000-0000-0000000000a1', '51000000-0000-0000-0000-000000000002', 0, 'refresh_token');
set local role authenticated;
select throws_ok($$select public.iniciar_sessao(gen_random_uuid())$$,
  'PGRST', '{"code": "sem_login", "message": "sem_login"}', 'sem amr de senha não inicia sessão');
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select public.iniciar_sessao(gen_random_uuid())$$,
  'PGRST', '{"code": "sem_login", "message": "sem_login"}', 'sem session_id não inicia sessão');
reset role;
select is((select count(*)::int from app.sessoes where session_id = '51000000-0000-0000-0000-000000000002'), 0,
  'nenhuma linha nasceu das tentativas recusadas');

-- Sem estúdio ativo: devolve 0 e a linha nasce encerrada (o session_id nunca vale)
select pg_temp.token('00000000-0000-0000-0000-0000000000c1', '51000000-0000-0000-0000-000000000003');
set local role authenticated;
select is(public.iniciar_sessao('52000000-0000-0000-0000-000000000003'), 0, 'sem estúdio ativo devolve 0');
select throws_ok($$select public.contexto_da_sessao()$$,
  'PGRST', '{"code": "sem_login", "message": "sem_login"}', 'e não há sessão viva');
select throws_ok($$select public.iniciar_sessao(gen_random_uuid())$$,
  'PGRST', '{"code": "sem_login", "message": "sem_login"}', 'nem uma segunda tentativa com o mesmo session_id');
reset role;
select is((select motivo_fim from app.sessoes where session_id = '51000000-0000-0000-0000-000000000003'), 'sem_estudio',
  'linha marcada sem_estudio');
select is((select count(*)::int from app.registro where pedido_id = '52000000-0000-0000-0000-000000000003'), 0,
  'nada no registro: o servidor grava a falha sem pessoa (RF-24a)');

-- Pessoa com estúdio ativo mas nenhum escolhido: contexto sem estúdio (sem_estudio no servidor)
select pg_temp.token('00000000-0000-0000-0000-0000000000e1', '51000000-0000-0000-0000-000000000004');
set local role authenticated;
select is(public.iniciar_sessao(gen_random_uuid()), 1, 'pessoa de B entra');
select results_eq('select usuario_id, org_id, papel from public.contexto_da_sessao()',
  $$values ('00000000-0000-0000-0000-0000000000e1'::uuid, null::uuid, null::text)$$,
  'sem estúdio escolhido: uma linha com a pessoa e org_id vazio');
reset role;

-- Sair: marca, não apaga; grava sessao.sair com o estúdio; o token não volta (CA-13)
select pg_temp.token('00000000-0000-0000-0000-0000000000a1', '51000000-0000-0000-0000-000000000001');
set local role authenticated;
select ok(public.encerrar_sessao('52000000-0000-0000-0000-000000000005'), 'sair marca a sessão');
select throws_ok($$select public.contexto_da_sessao()$$,
  'PGRST', '{"code": "sem_login", "message": "sem_login"}', 'depois de sair, o token é recusado');
select ok(not public.encerrar_sessao(gen_random_uuid()), 'sair de novo não muda nada');
select throws_ok($$select public.iniciar_sessao(gen_random_uuid())$$,
  'PGRST', '{"code": "sem_login", "message": "sem_login"}', 'sessão encerrada não ressuscita por iniciar_sessao');
reset role;
select results_eq(
  $$select evento, resultado, org_id from app.registro where pedido_id = '52000000-0000-0000-0000-000000000005'$$,
  $$values ('sessao.sair'::text, 'ok'::text, '00000000-0000-0000-0000-00000000000a'::uuid)$$,
  'sair grava sessao.sair com o estúdio da sessão');

-- 12 h desde a entrada e 1 h parada (E39·3·B, ajuste do dono: "1hr parado"), com o relógio empurrado para trás
insert into app.sessoes (session_id, user_id, entrou_em, ultimo_uso) values
  ('51000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-0000000000a2', now() - interval '12 hours 1 second', now()),
  ('51000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-0000000000a3', now() - interval '2 hours', now() - interval '61 minutes'),
  ('51000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-0000000000a3', now() - interval '11 hours', now() - interval '59 minutes'),
  ('51000000-0000-0000-0000-000000000009', '00000000-0000-0000-0000-0000000000a3', now() - interval '1 hour', now() - interval '30 seconds');
select pg_temp.token('00000000-0000-0000-0000-0000000000a2', '51000000-0000-0000-0000-000000000006', 3600);
set local role authenticated;
select throws_ok($$select public.contexto_da_sessao()$$,
  'PGRST', '{"code": "sem_login", "message": "sem_login"}', 'mais de 12 h desde a entrada: recusada');
select ok(public.encerrar_sessao('52000000-0000-0000-0000-000000000006'), 'a vencida é marcada');
reset role;
select is((select motivo_fim from app.sessoes where session_id = '51000000-0000-0000-0000-000000000006'), 'tempo', 'motivo tempo');
select pg_temp.token('00000000-0000-0000-0000-0000000000a3', '51000000-0000-0000-0000-000000000007', 3600);
set local role authenticated;
select throws_ok($$select public.contexto_da_sessao()$$,
  'PGRST', '{"code": "sem_login", "message": "sem_login"}', 'mais de 1 h parada: recusada');
reset role;
select pg_temp.token('00000000-0000-0000-0000-0000000000a3', '51000000-0000-0000-0000-000000000008', 3600);
set local role authenticated;
select is((select papel from public.contexto_da_sessao()), 'profissional', '59 min parada e 11 h: ainda viva');
reset role;
select ok((select ultimo_uso = now() from app.sessoes where session_id = '51000000-0000-0000-0000-000000000008'),
  'o uso empurra o último uso');
select pg_temp.token('00000000-0000-0000-0000-0000000000a3', '51000000-0000-0000-0000-000000000009', 3600);
set local role authenticated;
select lives_ok($$select public.contexto_da_sessao()$$, 'uso de 30 s atrás passa');
reset role;
select ok((select ultimo_uso < now() from app.sessoes where session_id = '51000000-0000-0000-0000-000000000009'),
  'último uso muda no máximo uma vez por minuto');

-- Linha nunca apagada, encerrada nunca reabre, entrada nunca vai para frente
select throws_ok($$delete from app.sessoes where session_id = '51000000-0000-0000-0000-000000000001'$$,
  '42501', null, 'sessão não se apaga');
select throws_ok($$truncate app.sessoes$$, '42501', null, 'sessões não se esvaziam');
select throws_ok($$update app.sessoes set encerrada_em = null, motivo_fim = null
                    where session_id = '51000000-0000-0000-0000-000000000001'$$,
  '42501', null, 'sessão encerrada não reabre');

select * from finish();
rollback;
