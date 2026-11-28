-- Entrar e camada de serviço · spec 20261128-030000-entrar-servico · plan.md §3.2, §6 e §9 · RF-15, CA-05, CA-06, CA-13
-- Molde oficial: https://supabase.com/docs/guides/local-development/testing/overview
-- O pré-pedido roda como o PostgREST o chama: com o papel do pedido (set local role) e request.method,
-- request.path (forma real "/rpc/<função>" e "/<tabela>", conferida no PostgREST local 16.6), request.headers
-- e request.jwt.claims postos no teste.
begin;
select plan(33);

-- Preparo (como postgres): dados fictícios, escritos do zero.
-- a1 dona A (sessão viva) · a2 recepção A (sessão encerrada) · a3 profissional A (sessão de 13 h)
-- f1 profissional em A (atual) e recepção em B (sessão viva)
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'a1@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000a2', 'a2@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000a3', 'a3@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000f1', 'f1@exemplo.test');
insert into public.estudios (org_id, nome, moeda, idioma, fuso_horario) values
  ('00000000-0000-0000-0000-00000000000a', 'Estudio A', 'EUR', 'pt', 'Europe/Lisbon'),
  ('00000000-0000-0000-0000-00000000000b', 'Estudio B', 'EUR', 'es', 'Europe/Madrid');
insert into public.membros (org_id, user_id, papel, ativo, estudio_atual) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a1', 'dona', true, true),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a2', 'recepcao', true, true),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a3', 'profissional', true, true),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000f1', 'profissional', true, true),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000f1', 'recepcao', true, false);
insert into app.sessoes (session_id, user_id, entrou_em, ultimo_uso, encerrada_em, motivo_fim) values
  ('a1000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a1', now(), now(), null, null),
  ('a1000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000a2', now(), now(), now(), 'sair'),
  ('a1000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000a3', now() - interval '13 hours', now(), null, null),
  ('a1000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000f1', now(), now(), null, null);
delete from app.chaves_servidor;
insert into app.chaves_servidor (hash) values (pg_catalog.sha256(convert_to('chave-de-teste-do-servidor', 'UTF8')));
insert into app.acoes_que_gravam (acao) values ('teste.pre_pedido.gravar');

-- Monta o pedido como o PostgREST: método, caminho, cabeçalhos (a chave certa entra por padrão) e token.
create function pg_temp.pedido(p_metodo text, p_caminho text, p_cabecalhos jsonb default '{}',
                               p_sub text default null, p_sessao text default null, p_chave text default 'chave-de-teste-do-servidor')
returns void language plpgsql as $$
begin
  perform set_config('request.method', p_metodo, true);
  perform set_config('request.path', p_caminho, true);
  perform set_config('request.headers',
    (case when p_chave is null then '{}'::jsonb else jsonb_build_object('x-chave-servidor', p_chave) end || p_cabecalhos)::text, true);
  perform set_config('request.jwt.claims',
    case when p_sub is null then '{"role":"anon"}'
         else jsonb_build_object('sub', p_sub, 'role', 'authenticated', 'session_id', p_sessao)::text end, true);
end;
$$;

select is((select array_to_string(rolconfig, ',') like '%pgrst.db_pre_request=app.antes_do_pedido%'
             from pg_catalog.pg_roles where rolname = 'authenticator'),
  true, 'o pré-pedido está registrado no papel authenticator');

-- anon: chave do servidor obrigatória; só as duas funções de entrar
select pg_temp.pedido('POST', '/rpc/conferir_tentativa', '{"x-pedido":"a2000000-0000-0000-0000-000000000001"}', p_chave => null);
set local role anon;
select throws_ok('select app.antes_do_pedido()', 'PGRST', '{"code": "sem_login", "message": "sem_login"}', 'anon sem chave do servidor: recusa');
reset role;
select pg_temp.pedido('POST', '/rpc/conferir_tentativa', '{"x-pedido":"a2000000-0000-0000-0000-000000000001"}', p_chave => 'chave-errada');
set local role anon;
select throws_ok('select app.antes_do_pedido()', 'PGRST', '{"code": "sem_login", "message": "sem_login"}', 'anon com chave errada: recusa');
reset role;
select pg_temp.pedido('POST', '/rpc/conferir_tentativa', '{"x-pedido":"a2000000-0000-0000-0000-000000000001"}');
set local role anon;
select lives_ok('select app.antes_do_pedido()', 'anon com a chave certa conta a tentativa');
reset role;
select pg_temp.pedido('POST', '/rpc/registrar_tentativa_falha');
set local role anon;
select throws_ok('select app.antes_do_pedido()', 'PGRST', '{"code": "erro_interno", "message": "erro_interno"}', 'anon gravando sem x-pedido: recusa');
reset role;
select pg_temp.pedido('GET', '/estudios');
set local role anon;
select throws_ok('select app.antes_do_pedido()', 'PGRST', '{"code": "sem_login", "message": "sem_login"}', 'anon fora das funções de entrar: recusa');
reset role;

-- authenticated com sessão viva (a1, estúdio A)
select pg_temp.pedido('GET', '/rpc/meus_estudios', '{}', '00000000-0000-0000-0000-0000000000a1', 'a1000000-0000-0000-0000-0000000000a1', null);
set local role authenticated;
select throws_ok('select app.antes_do_pedido()', 'PGRST', '{"code": "sem_login", "message": "sem_login"}',
  'token válido sem chave do servidor: recusa (chamada direta à Data API, CA-13)');
reset role;
select pg_temp.pedido('GET', '/rpc/meus_estudios', '{}', '00000000-0000-0000-0000-0000000000a1', 'a1000000-0000-0000-0000-0000000000a1', 'chave-errada');
set local role authenticated;
select throws_ok('select app.antes_do_pedido()', 'PGRST', '{"code": "sem_login", "message": "sem_login"}', 'token válido com chave errada: recusa');
reset role;
select pg_temp.pedido('GET', '/rpc/meus_estudios', '{}', '00000000-0000-0000-0000-0000000000a1', 'a1000000-0000-0000-0000-0000000000a1');
set local role authenticated;
select lives_ok('select app.antes_do_pedido()', 'função de sessão sem estúdio esperado passa');
reset role;
select pg_temp.pedido('GET', '/estudios', '{"x-estudio-esperado":"00000000-0000-0000-0000-00000000000a"}',
  '00000000-0000-0000-0000-0000000000a1', 'a1000000-0000-0000-0000-0000000000a1');
set local role authenticated;
select lives_ok('select app.antes_do_pedido()', 'leitura com o estúdio certo passa');
reset role;
select pg_temp.pedido('GET', '/estudios', '{"x-estudio-esperado":"00000000-0000-0000-0000-00000000000b"}',
  '00000000-0000-0000-0000-0000000000a1', 'a1000000-0000-0000-0000-0000000000a1');
set local role authenticated;
select throws_ok('select app.antes_do_pedido()', 'PGRST', '{"code": "estudio_trocado", "message": "estudio_trocado"}',
  'estúdio de B mandado por quem está em A: estudio_trocado (CA-05)');
reset role;
select pg_temp.pedido('GET', '/estudios', '{"x-estudio-esperado":"nao-e-uuid"}',
  '00000000-0000-0000-0000-0000000000a1', 'a1000000-0000-0000-0000-0000000000a1');
set local role authenticated;
select throws_ok('select app.antes_do_pedido()', 'PGRST', '{"code": "estudio_trocado", "message": "estudio_trocado"}', 'estúdio esperado fora do formato: recusa');
reset role;
select pg_temp.pedido('GET', '/estudios', '{}', '00000000-0000-0000-0000-0000000000a1', 'a1000000-0000-0000-0000-0000000000a1');
set local role authenticated;
select throws_ok('select app.antes_do_pedido()', 'PGRST', '{"code": "erro_interno", "message": "erro_interno"}',
  'tabela do estúdio sem estúdio esperado: recusa');
reset role;

-- Pedido que grava: x-pedido uuid e x-acao da lista
select pg_temp.pedido('PATCH', '/estudios',
  '{"x-estudio-esperado":"00000000-0000-0000-0000-00000000000a","x-pedido":"a2000000-0000-0000-0000-000000000002","x-acao":"teste.pre_pedido.gravar"}',
  '00000000-0000-0000-0000-0000000000a1', 'a1000000-0000-0000-0000-0000000000a1');
set local role authenticated;
select lives_ok('select app.antes_do_pedido()', 'gravação com pedido e ação da lista passa');
reset role;
select pg_temp.pedido('PATCH', '/estudios',
  '{"x-estudio-esperado":"00000000-0000-0000-0000-00000000000a","x-acao":"teste.pre_pedido.gravar"}',
  '00000000-0000-0000-0000-0000000000a1', 'a1000000-0000-0000-0000-0000000000a1');
set local role authenticated;
select throws_ok('select app.antes_do_pedido()', 'PGRST', '{"code": "erro_interno", "message": "erro_interno"}', 'gravação sem x-pedido: recusa');
reset role;
select pg_temp.pedido('POST', '/estudios',
  '{"x-estudio-esperado":"00000000-0000-0000-0000-00000000000a","x-pedido":"123","x-acao":"teste.pre_pedido.gravar"}',
  '00000000-0000-0000-0000-0000000000a1', 'a1000000-0000-0000-0000-0000000000a1');
set local role authenticated;
select throws_ok('select app.antes_do_pedido()', 'PGRST', '{"code": "erro_interno", "message": "erro_interno"}', 'x-pedido fora do formato: recusa');
reset role;
select pg_temp.pedido('DELETE', '/estudios',
  '{"x-estudio-esperado":"00000000-0000-0000-0000-00000000000a","x-pedido":"a2000000-0000-0000-0000-000000000003"}',
  '00000000-0000-0000-0000-0000000000a1', 'a1000000-0000-0000-0000-0000000000a1');
set local role authenticated;
select throws_ok('select app.antes_do_pedido()', 'PGRST', '{"code": "erro_interno", "message": "erro_interno"}', 'gravação sem x-acao: recusa');
reset role;
select pg_temp.pedido('POST', '/rpc/agenda_bloqueio_criar',
  '{"x-estudio-esperado":"00000000-0000-0000-0000-00000000000a","x-pedido":"a2000000-0000-0000-0000-000000000004","x-acao":"agenda.fora.da.lista"}',
  '00000000-0000-0000-0000-0000000000a1', 'a1000000-0000-0000-0000-0000000000a1');
set local role authenticated;
select throws_ok('select app.antes_do_pedido()', 'PGRST', '{"code": "erro_interno", "message": "erro_interno"}', 'x-acao fora da lista: recusa');
reset role;
select pg_temp.pedido('POST', '/rpc/escolher_estudio', '{"x-pedido":"a2000000-0000-0000-0000-000000000005"}',
  '00000000-0000-0000-0000-0000000000a1', 'a1000000-0000-0000-0000-0000000000a1');
set local role authenticated;
select lives_ok('select app.antes_do_pedido()', 'função de sessão grava sem x-acao (registra por conta própria)');
reset role;

-- Sessão morta (encerrada, vencida ou desconhecida): só iniciar e encerrar passam (D4 do ADR 0018)
select pg_temp.pedido('GET', '/rpc/meus_estudios', '{}', '00000000-0000-0000-0000-0000000000a2', 'a1000000-0000-0000-0000-0000000000a2');
set local role authenticated;
select throws_ok('select app.antes_do_pedido()', 'PGRST', '{"code": "sem_login", "message": "sem_login"}', 'sessão encerrada: recusa (CA-13)');
reset role;
select pg_temp.pedido('POST', '/rpc/contexto_da_sessao', '{"x-pedido":"a2000000-0000-0000-0000-000000000006"}',
  '00000000-0000-0000-0000-0000000000a3', 'a1000000-0000-0000-0000-0000000000a3');
set local role authenticated;
select throws_ok('select app.antes_do_pedido()', 'PGRST', '{"code": "sem_login", "message": "sem_login"}', 'sessão de mais de 12 h: recusa');
reset role;
select pg_temp.pedido('GET', '/rpc/meus_estudios', '{}', '00000000-0000-0000-0000-0000000000a1', 'a1000000-0000-0000-0000-00000000ffff');
set local role authenticated;
select throws_ok('select app.antes_do_pedido()', 'PGRST', '{"code": "sem_login", "message": "sem_login"}', 'session_id sem linha: recusa');
reset role;
select pg_temp.pedido('GET', '/rpc/meus_estudios', '{}', '00000000-0000-0000-0000-0000000000a2', 'a1000000-0000-0000-0000-0000000000a1');
set local role authenticated;
select throws_ok('select app.antes_do_pedido()', 'PGRST', '{"code": "sem_login", "message": "sem_login"}', 'sessão de outra pessoa: recusa');
reset role;
select pg_temp.pedido('POST', '/rpc/iniciar_sessao', '{"x-pedido":"a2000000-0000-0000-0000-000000000007"}',
  '00000000-0000-0000-0000-0000000000a1', 'a1000000-0000-0000-0000-00000000ffff');
set local role authenticated;
select lives_ok('select app.antes_do_pedido()', 'iniciar_sessao sem linha viva passa ao pré-pedido');
select throws_ok('select public.iniciar_sessao(gen_random_uuid())', 'PGRST', '{"code": "sem_login", "message": "sem_login"}',
  'mas só passa pela conferência de D4 (aqui, sem amr de senha recente)');
reset role;
select pg_temp.pedido('POST', '/rpc/iniciar_sessao', '{"x-pedido":"a2000000-0000-0000-0000-000000000008"}',
  '00000000-0000-0000-0000-0000000000a1', 'a1000000-0000-0000-0000-00000000ffff', null);
set local role authenticated;
select throws_ok('select app.antes_do_pedido()', 'PGRST', '{"code": "sem_login", "message": "sem_login"}',
  'iniciar_sessao sem chave do servidor: recusa');
reset role;
select pg_temp.pedido('POST', '/rpc/encerrar_sessao', '{"x-pedido":"a2000000-0000-0000-0000-000000000009"}',
  '00000000-0000-0000-0000-0000000000a3', 'a1000000-0000-0000-0000-0000000000a3');
set local role authenticated;
select lives_ok('select app.antes_do_pedido()', 'encerrar_sessao passa com a sessão vencida, para marcá-la');
reset role;
select pg_temp.pedido('GET', '/estudios', '{"x-estudio-esperado":"00000000-0000-0000-0000-00000000000a"}',
  '00000000-0000-0000-0000-0000000000a2', 'a1000000-0000-0000-0000-0000000000a2');
set local role authenticated;
select throws_ok('select app.antes_do_pedido()', 'PGRST', '{"code": "sem_login", "message": "sem_login"}',
  'tabela do estúdio com sessão encerrada: recusa');
reset role;

-- Troca em outro aparelho (CA-06): f1 em A; o outro aparelho troca para B; a tela antiga ainda manda A
select pg_temp.pedido('GET', '/estudios', '{"x-estudio-esperado":"00000000-0000-0000-0000-00000000000a"}',
  '00000000-0000-0000-0000-0000000000f1', 'a1000000-0000-0000-0000-0000000000f1');
set local role authenticated;
select lives_ok('select app.antes_do_pedido()', 'f1 em A lê A');
select app.escolher_estudio('00000000-0000-0000-0000-00000000000b');
select throws_ok('select app.antes_do_pedido()', 'PGRST', '{"code": "estudio_trocado", "message": "estudio_trocado"}',
  'depois da troca no outro aparelho, a tela antiga recebe estudio_trocado');
reset role;

-- Outros papéis
select pg_temp.pedido('GET', '/estudios', '{}', p_chave => null);
set local role service_role;
select throws_ok('select app.antes_do_pedido()', 'PGRST', '{"code": "sem_login", "message": "sem_login"}', 'service_role sem chave: recusa');
reset role;
select pg_temp.pedido('GET', '/estudios');
set local role service_role;
select lives_ok('select app.antes_do_pedido()', 'service_role com a chave passa (tarefas internas)');
reset role;
select throws_ok('select app.antes_do_pedido()', 'PGRST', '{"code": "sem_login", "message": "sem_login"}',
  'papel fora de anon, authenticated e service_role: recusa');

select * from finish();
rollback;
