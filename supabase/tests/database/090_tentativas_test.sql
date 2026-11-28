-- Entrar e camada de serviço · spec 20261128-030000-entrar-servico · plan.md §3.1, §6 e §9 · RF-08, RF-24a, CA-09a, CA-14
-- Molde oficial: https://supabase.com/docs/guides/local-development/testing/overview
-- Chaves de teste: SHA-256 de textos fictícios (no servidor é HMAC-SHA-256; o banco só vê os 32 bytes).
begin;
select plan(26);

create function pg_temp.k(p text) returns bytea language sql immutable as $$ select pg_catalog.sha256(convert_to(p, 'UTF8')) $$;
grant execute on function pg_temp.k(text) to anon;

select has_table('app', 'tentativas_entrada', 'existe app.tentativas_entrada');
select table_privs_are('app', 'tentativas_entrada', 'anon', array[]::text[], 'anon sem privilégio no contador');

-- 10 por conta em 15 min: a 11ª é recusada (CA-14)
set local role anon;
select is(
  (select array_agg(public.conferir_tentativa(pg_temp.k('ip-' || i), pg_temp.k('conta-1')) order by i)
     from generate_series(1, 11) i),
  array[true, true, true, true, true, true, true, true, true, true, false],
  '11ª tentativa da mesma conta passa do limite');
-- 30 por IP em 15 min: a 31ª é recusada
select is(
  (select count(*)::int from generate_series(1, 31) i
    where public.conferir_tentativa(pg_temp.k('ip-unico'), pg_temp.k('conta-ip-' || i))),
  30, '31ª tentativa do mesmo IP passa do limite');
select ok(not public.conferir_tentativa(pg_temp.k('ip-unico'), pg_temp.k('conta-ip-nova')),
  'IP acima do limite recebe limite também com conta nova');
reset role;
select is((select count(*)::int from app.tentativas_entrada
            where tipo = 'conta' and chave in (pg_temp.k('conta-ip-31'), pg_temp.k('conta-ip-nova'))),
  0, 'IP acima do limite não cria linha de conta (ASVS V2.2.1)');
-- Um IP com contas sempre novas não enche o teto global: no máximo 30 linhas de conta por janela
set local role anon;
select is((select count(*)::int from generate_series(1, 200) i
            where public.conferir_tentativa(pg_temp.k('ip-enchedor'), pg_temp.k('enchedor-conta-' || i))),
  30, 'IP com contas sempre novas para no limite');
reset role;
select is((select count(*)::int from app.tentativas_entrada t
            where t.tipo = 'conta' and t.chave in (select pg_temp.k('enchedor-conta-' || i) from generate_series(1, 200) i)),
  30, 'teto global não é enchido por um IP: só 30 linhas de conta dele');
set local role anon;
select ok(public.conferir_tentativa(pg_temp.k('ip-outro'), pg_temp.k('conta-outra')), 'outra conta e outro IP seguem');
select throws_ok($$select public.conferir_tentativa('\x01'::bytea, pg_temp.k('conta-1'))$$,
  'PGRST', '{"code": "entrada_invalida", "message": "entrada_invalida"}', 'chave fora de 32 bytes é recusada');
select throws_ok($$select public.conferir_tentativa(null, pg_temp.k('conta-1'))$$,
  'PGRST', '{"code": "entrada_invalida", "message": "entrada_invalida"}', 'chave vazia é recusada');
select throws_ok($$select 1 from app.tentativas_entrada$$, '42501', null, 'anon não lê o contador');
reset role;

-- O contador guarda só bytes do HMAC: nada de IP nem e-mail
select is((select count(*)::int from app.tentativas_entrada where octet_length(chave) <> 32), 0, 'só chaves de 32 bytes');
select is((select count(*)::int from app.registro where quando = now()), 0, 'contar tentativas não escreve no registro');

-- Vencimento: janela de 15 min, apagada a cada chamada (CA-09a)
update app.tentativas_entrada set janela_inicio = now() - interval '15 minutes 1 second'
 where tipo = 'conta' and chave = pg_temp.k('conta-1');
set local role anon;
select ok(public.conferir_tentativa(pg_temp.k('ip-novo'), pg_temp.k('conta-1')), 'depois de 15 min a conta volta a entrar');
reset role;
select is((select contagem from app.tentativas_entrada where tipo = 'conta' and chave = pg_temp.k('conta-1')), 1,
  'a linha vencida foi apagada e a contagem recomeçou');

-- Linha da tentativa que falha: só evento, resultado, quando e pedido (RF-24a)
set local role anon;
select lives_ok($$select public.registrar_tentativa_falha('91000000-0000-0000-0000-000000000001')$$, 'anon grava a falha');
select throws_ok($$select public.registrar_tentativa_falha(null)$$,
  'PGRST', '{"code": "entrada_invalida", "message": "entrada_invalida"}', 'sem pedido, recusa');
select throws_ok($$select 1 from app.registro$$, '42501', null, 'anon não lê o registro');
select throws_ok($$insert into app.registro (evento, resultado, pedido_id) values ('sessao.entrar', 'sem_login', gen_random_uuid())$$,
  '42501', null, 'anon não grava direto no registro');
reset role;
select results_eq(
  $$select evento, resultado, usuario_id, org_id, objetos from app.registro where pedido_id = '91000000-0000-0000-0000-000000000001'$$,
  $$values ('sessao.entrar'::text, 'sem_login'::text, null::uuid, null::uuid, null::uuid[])$$,
  'a linha de falha não tem pessoa, estúdio nem objetos');

-- Teto global por minuto (60): acima dele, uma só linha de resumo por minuto, sem erro
insert into app.registro (evento, resultado, pedido_id)
select 'sessao.entrar', 'sem_login', gen_random_uuid()
  from generate_series(1, 60 - (select count(*)::int from app.registro
                                  where evento = 'sessao.entrar' and resultado = 'sem_login'
                                    and quando >= date_trunc('minute', now())));
set local role anon;
select lives_ok($$select public.registrar_tentativa_falha('91000000-0000-0000-0000-000000000002')$$, 'acima do teto não dá erro');
select lives_ok($$select public.registrar_tentativa_falha('91000000-0000-0000-0000-000000000003')$$, 'nem na seguinte');
reset role;
select results_eq(
  $$select resultado from app.registro where pedido_id in ('91000000-0000-0000-0000-000000000002', '91000000-0000-0000-0000-000000000003')$$,
  $$values ('limite'::text)$$,
  'acima do teto grava uma só linha de resumo (limite), para o teto não esconder falhas');

-- Teto global de linhas do contador (10 000): chave nova recusada, chave já contada segue
insert into app.tentativas_entrada (tipo, chave)
select 'ip', pg_temp.k('enche-' || i)
  from generate_series(1, 10000 - (select count(*)::int from app.tentativas_entrada)) i;
set local role anon;
select ok(not public.conferir_tentativa(pg_temp.k('ip-de-fora'), pg_temp.k('conta-de-fora')),
  'contador cheio: chave nova recebe limite');
select ok(public.conferir_tentativa(pg_temp.k('ip-outro'), pg_temp.k('conta-outra')),
  'contador cheio: chaves já contadas seguem');
reset role;

select * from finish();
rollback;
