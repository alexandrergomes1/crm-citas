-- Entrar e camada de serviço · spec 20261128-030000-entrar-servico · plan.md §3.2, §3.3 e §6 (M5) · ADR 0019 (D12 a D16).
-- Estúdios da pessoa (RF-13), escolha e troca com registro (RF-12, RF-24a) e a função de pré-pedido da Data API
-- (ADR 0018 · D6 e D16): roda dentro da transação de cada pedido, antes da consulta.

-- Chave do servidor (D16): só o SHA-256 dos bytes UTF-8 do cabeçalho x-chave-servidor. Até 2 (troca sem parada).
-- Gravada como postgres: no local pelo script do banco local; no remoto, pelo dono (passo a passo no pedido de merge).
create table app.chaves_servidor (
  hash      bytea       primary key check (octet_length(hash) = 32),
  criada_em timestamptz not null default now()
);
comment on table app.chaves_servidor is 'SHA-256 da chave que só o servidor manda à Data API (x-chave-servidor). Nunca a chave em si.';
alter table app.chaves_servidor enable row level security;
alter table app.chaves_servidor force row level security;
revoke all on table app.chaves_servidor from public, anon, authenticated, service_role;

create function app.chaves_servidor_no_maximo_duas()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('app.chaves_servidor', 0));
  if (select count(*) from app.chaves_servidor) >= 2 then
    raise exception 'No maximo duas chaves do servidor' using errcode = '23514';
  end if;
  return new;
end;
$$;
create trigger chaves_servidor_no_maximo_duas
  before insert on app.chaves_servidor
  for each row execute function app.chaves_servidor_no_maximo_duas();

-- Estúdios em que a pessoa tem papel ativo, por nome, até 50 (RF-13). A trava de estudios só mostra o estúdio
-- da sessão; por isso a leitura é security definer em app, presa a auth.uid() (ADR 0019 · D13).
create function app.meus_estudios()
returns table (org_id uuid, nome text)
language sql
stable
security definer
set search_path = ''
as $$
  select e.org_id, e.nome
    from public.membros m
    join public.estudios e on e.org_id = m.org_id
   where m.user_id = (select auth.uid()) and m.ativo
   order by e.nome, e.org_id
   limit 50
$$;

create function public.meus_estudios()
returns table (org_id uuid, nome text)
language sql
stable
security invoker
set search_path = ''
as $$
  select r.org_id, r.nome from app.meus_estudios() r
$$;

-- Escolher ou trocar (RF-12): passa só por app.escolher_estudio e grava estudio.escolher (primeira vez na sessão)
-- ou estudio.trocar, com o org_id escolhido, na mesma transação. Sem vínculo ativo: sem_permissao, nada muda.
create function app.escolher_estudio_da_sessao(p_org_id uuid, p_pedido uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_usuario uuid := auth.uid();
  v_sessao  uuid := app.id_da_sessao();
  v_antes   timestamptz;
begin
  if v_usuario is null or v_sessao is null or not app.sessao_viva() then
    perform app.recusar('sem_login');
  end if;
  if p_pedido is null then
    perform app.recusar('entrada_invalida');
  end if;
  select s.estudio_escolhido_em into v_antes from app.sessoes s where s.session_id = v_sessao for update;
  begin
    perform app.escolher_estudio(p_org_id);
  exception when insufficient_privilege then
    perform app.recusar('sem_permissao');
  end;
  update app.sessoes set estudio_escolhido_em = now() where session_id = v_sessao;
  insert into app.registro (evento, resultado, usuario_id, org_id, pedido_id)
  values (case when v_antes is null then 'estudio.escolher' else 'estudio.trocar' end, 'ok',
          v_usuario, p_org_id, p_pedido);
  return true;
end;
$$;

create function public.escolher_estudio(p_org_id uuid, p_pedido uuid)
returns boolean
language sql
volatile
security invoker
set search_path = ''
as $$
  select app.escolher_estudio_da_sessao(p_org_id, p_pedido)
$$;
comment on function public.escolher_estudio(uuid, uuid) is 'Passagem (security invoker, RF-12) para app.escolher_estudio, com registro.';

-- Pré-pedido da Data API. Ordem: chave do servidor (todo papel) → x-pedido em pedido que grava → papel.
-- anon: só as duas funções de entrar. authenticated: sessão viva (menos iniciar e encerrar, que se conferem
-- sozinhas), x-estudio-esperado igual ao estúdio da sessão (obrigatório fora das funções de sessão) e, em pedido
-- que grava fora das funções de sessão, x-acao da lista fechada. service_role: só a chave. Outro papel: recusa.
create function app.antes_do_pedido()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_papel    text := pg_catalog.current_setting('role', true);
  v_metodo   text := pg_catalog.upper(coalesce(pg_catalog.current_setting('request.method', true), ''));
  v_caminho  text := pg_catalog.ltrim(coalesce(pg_catalog.current_setting('request.path', true), ''), '/');
  v_chave    text := app.cabecalho('x-chave-servidor');
  v_esperado text := app.cabecalho('x-estudio-esperado');
  v_acao     text := app.cabecalho('x-acao');
  v_grava    boolean;
  v_sessao   boolean;
begin
  v_grava := v_metodo not in ('GET', 'HEAD');

  if v_chave is null or not exists (
       select 1 from app.chaves_servidor c
        where c.hash = pg_catalog.sha256(pg_catalog.convert_to(v_chave, 'UTF8'))) then
    perform app.recusar('sem_login');
  end if;

  if v_grava and not app.eh_uuid(app.cabecalho('x-pedido')) then
    perform app.recusar('erro_interno');
  end if;

  if v_papel = 'anon' then
    if v_caminho not in ('rpc/conferir_tentativa', 'rpc/registrar_tentativa_falha') then
      perform app.recusar('sem_login');
    end if;
    return;
  elsif v_papel = 'service_role' then
    return;
  elsif v_papel is distinct from 'authenticated' then
    perform app.recusar('sem_login');
  end if;

  v_sessao := v_caminho in ('rpc/iniciar_sessao', 'rpc/encerrar_sessao', 'rpc/contexto_da_sessao',
                            'rpc/meus_estudios', 'rpc/escolher_estudio', 'rpc/registrar_recusa');

  if v_caminho not in ('rpc/iniciar_sessao', 'rpc/encerrar_sessao') and not app.sessao_viva() then
    perform app.recusar('sem_login');
  end if;

  if v_esperado is not null then
    if not app.eh_uuid(v_esperado) or app.estudio_da_sessao() is distinct from v_esperado::uuid then
      perform app.recusar('estudio_trocado');
    end if;
  elsif not v_sessao then
    perform app.recusar('erro_interno');
  end if;

  if v_grava and not v_sessao
     and (v_acao is null or not exists (select 1 from app.acoes_que_gravam a where a.acao = v_acao)) then
    perform app.recusar('erro_interno');
  end if;
end;
$$;
comment on function app.antes_do_pedido() is 'Pré-pedido da Data API (pgrst.db_pre_request; ADR 0018 · D6 e D16).';

revoke all on function app.chaves_servidor_no_maximo_duas() from public, anon, authenticated, service_role;
revoke all on function app.meus_estudios() from public, anon, authenticated, service_role;
revoke all on function public.meus_estudios() from public, anon, authenticated, service_role;
revoke all on function app.escolher_estudio_da_sessao(uuid, uuid) from public, anon, authenticated, service_role;
revoke all on function public.escolher_estudio(uuid, uuid) from public, anon, authenticated, service_role;
revoke all on function app.antes_do_pedido() from public, anon, authenticated, service_role;

grant execute on function app.meus_estudios() to authenticated;
grant execute on function public.meus_estudios() to authenticated;
grant execute on function app.escolher_estudio_da_sessao(uuid, uuid) to authenticated;
grant execute on function public.escolher_estudio(uuid, uuid) to authenticated;
-- O PostgREST chama o pré-pedido com o papel do pedido: os três precisam executá-lo (e só ele, no caso de service_role).
grant usage on schema app to service_role;
grant execute on function app.antes_do_pedido() to anon, authenticated, service_role;

-- Registro do pré-pedido (guia oficial "Securing your API"). Vale para o PostgREST local e o remoto.
alter role authenticator set pgrst.db_pre_request = 'app.antes_do_pedido';
notify pgrst, 'reload config';
