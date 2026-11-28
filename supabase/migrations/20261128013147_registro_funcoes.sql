-- Entrar e camada de serviço · spec 20261128-030000-entrar-servico · plan.md §6 (M2) · ADR 0019 (D4 a D7).
-- Quem grava no registro: (a) o gatilho genérico de cada tabela do estúdio, na mesma transação (RF-27);
-- (b) a recusa nas portas 2 a 5, pela própria pessoa; (d) a tentativa de entrar que falha, por anon, com teto.
-- (c) entrar, sair, escolher e trocar gravam nas funções de sessão (migrations sessoes e estudios_da_pessoa...).
-- Funções que gravam: security definer em app (fora da API), search_path vazio. Em public só passagens
-- security invoker (ADR 0005 · D1).

-- Cabeçalho do pedido da Data API (PostgREST põe em request.headers, nomes em minúsculas).
create function app.cabecalho(p_nome text)
returns text
language sql
stable
set search_path = ''
as $$
  select nullif(coalesce(nullif(pg_catalog.current_setting('request.headers', true), ''), '{}')::jsonb ->> p_nome, '')
$$;

-- Lista fechada das ações que gravam (D6 do ADR 0018). Cada módulo acrescenta as suas na própria migration:
--   insert into app.acoes_que_gravam (acao) values ('agenda.bloqueio.criar');
create table app.acoes_que_gravam (
  acao      text        primary key check (char_length(acao) <= 64 and acao ~ '^[a-z_]+(\.[a-z_]+)+$'),
  criada_em timestamptz not null default now()
);
comment on table app.acoes_que_gravam is 'Ações que gravam (x-acao). Preenchida pela migration de cada módulo.';
alter table app.acoes_que_gravam enable row level security;
alter table app.acoes_que_gravam force row level security;
revoke all on table app.acoes_que_gravam from public, anon, authenticated, service_role;

-- (a) Gatilho genérico: after insert or update or delete for each row, em toda tabela do estúdio.
-- Argumentos: nomes das colunas uuid que identificam os objetos tocados (até 10), ex.:
--   create trigger <tabela>_registro after insert or update or delete on public.<tabela>
--     for each row execute function app.registrar_mudanca('id');
-- Sem x-acao da lista, sem x-pedido uuid, sem pessoa ou com org_id diferente do estúdio da sessão: recusa,
-- e a gravação inteira é desfeita (RF-27).
create function app.registrar_mudanca()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_acao    text := app.cabecalho('x-acao');
  v_pedido  text := app.cabecalho('x-pedido');
  v_usuario uuid := auth.uid();
  v_estudio uuid := app.estudio_da_sessao();
  v_linha   jsonb := case when tg_op = 'DELETE' then pg_catalog.to_jsonb(old) else pg_catalog.to_jsonb(new) end;
  v_objetos uuid[];
begin
  if v_acao is null or not exists (select 1 from app.acoes_que_gravam a where a.acao = v_acao)
     or not app.eh_uuid(v_pedido) or v_usuario is null or v_estudio is null
     or tg_nargs > 10 then
    perform app.recusar('erro_interno');
  end if;
  if (v_linha ->> 'org_id') is distinct from v_estudio::text
     or (tg_op = 'UPDATE' and (pg_catalog.to_jsonb(old) ->> 'org_id') is distinct from v_estudio::text) then
    perform app.recusar('erro_interno');
  end if;
  select pg_catalog.array_agg((v_linha ->> c.nome)::uuid order by c.ordem)
    into v_objetos
    from pg_catalog.unnest(tg_argv) with ordinality as c (nome, ordem)
   where v_linha ->> c.nome is not null;
  insert into app.registro (evento, resultado, usuario_id, org_id, objetos, pedido_id)
  values (v_acao, 'ok', v_usuario, v_estudio, v_objetos, v_pedido::uuid);
  return null;
end;
$$;
comment on function app.registrar_mudanca() is 'Gatilho de registro (porta 6, ADR 0018 · D7a). Argumentos: colunas uuid dos objetos.';

-- (b) Recusa nas portas 2 a 5: só a própria pessoa, só código de RF-22, teto por pessoa por minuto.
-- Acima do teto grava uma linha de resumo por minuto (evento registro.teto, resultado limite) e devolve false.
create function app.registrar_recusa(p_acao text, p_codigo text, p_pedido uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_usuario uuid := auth.uid();
  v_minuto  timestamptz := pg_catalog.date_trunc('minute', now());
  v_teto    constant int := 30;
  v_feitas  int;
begin
  if v_usuario is null then
    perform app.recusar('sem_login');
  end if;
  if p_acao is null or char_length(p_acao) > 64 or p_acao !~ '^[a-z_]+(\.[a-z_]+)+$'
     or p_codigo is null or p_codigo not in ('sem_login', 'estudio_trocado', 'sem_estudio', 'sem_permissao',
                                             'entrada_invalida', 'conflito', 'limite', 'erro_interno')
     or p_pedido is null then
    perform app.recusar('entrada_invalida');
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('app.registrar_recusa:' || v_usuario::text, 0));
  select count(*) into v_feitas
    from app.registro r
   where r.usuario_id = v_usuario and r.quando >= v_minuto and r.resultado <> 'ok' and r.evento <> 'registro.teto';
  if v_feitas >= v_teto then
    if not exists (select 1 from app.registro r
                    where r.usuario_id = v_usuario and r.quando >= v_minuto and r.evento = 'registro.teto') then
      insert into app.registro (evento, resultado, usuario_id, org_id, pedido_id)
      values ('registro.teto', 'limite', v_usuario, app.estudio_da_sessao(), p_pedido);
    end if;
    return false;
  end if;
  insert into app.registro (evento, resultado, usuario_id, org_id, pedido_id)
  values (p_acao, p_codigo, v_usuario, app.estudio_da_sessao(), p_pedido);
  return true;
end;
$$;

create function public.registrar_recusa(p_acao text, p_codigo text, p_pedido uuid)
returns boolean
language sql
volatile
security invoker
set search_path = ''
as $$
  select app.registrar_recusa(p_acao, p_codigo, p_pedido)
$$;
comment on function public.registrar_recusa(text, text, uuid) is 'Passagem (security invoker) para app.registrar_recusa. Melhor esforço: a resposta ao navegador não depende dela.';

-- (d) Tentativa de entrar que falha (anon): só evento, resultado, quando e pedido (RF-24a).
-- Teto global por minuto; acima dele, uma só linha de resumo por minuto com resultado limite, sem erro.
create function app.registrar_tentativa_falha(p_pedido uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_minuto timestamptz := pg_catalog.date_trunc('minute', now());
  v_teto   constant int := 60;
  v_feitas int;
begin
  if p_pedido is null then
    perform app.recusar('entrada_invalida');
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('app.registrar_tentativa_falha', 0));
  select count(*) into v_feitas
    from app.registro r
   where r.evento = 'sessao.entrar' and r.resultado = 'sem_login' and r.quando >= v_minuto;
  if v_feitas < v_teto then
    insert into app.registro (evento, resultado, pedido_id) values ('sessao.entrar', 'sem_login', p_pedido);
  elsif not exists (select 1 from app.registro r
                     where r.evento = 'sessao.entrar' and r.resultado = 'limite' and r.quando >= v_minuto) then
    insert into app.registro (evento, resultado, pedido_id) values ('sessao.entrar', 'limite', p_pedido);
  end if;
end;
$$;

create function public.registrar_tentativa_falha(p_pedido uuid)
returns void
language sql
volatile
security invoker
set search_path = ''
as $$
  select app.registrar_tentativa_falha(p_pedido)
$$;
comment on function public.registrar_tentativa_falha(uuid) is 'Passagem (security invoker) para anon: grava a linha de falha de entrar, sem pessoa (RF-24a).';

-- Privilégios: nada para public; cada papel só o que usa (o teste 010_ confere a lista).
revoke all on function app.cabecalho(text) from public, anon, authenticated, service_role;
revoke all on function app.registrar_mudanca() from public, anon, authenticated, service_role;
revoke all on function app.registrar_recusa(text, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.registrar_recusa(text, text, uuid) from public, anon, authenticated, service_role;
revoke all on function app.registrar_tentativa_falha(uuid) from public, anon, authenticated, service_role;
revoke all on function public.registrar_tentativa_falha(uuid) from public, anon, authenticated, service_role;

grant execute on function app.registrar_recusa(text, text, uuid) to authenticated;
grant execute on function public.registrar_recusa(text, text, uuid) to authenticated;
grant usage on schema app to anon;
grant execute on function app.registrar_tentativa_falha(uuid) to anon;
grant execute on function public.registrar_tentativa_falha(uuid) to anon;
