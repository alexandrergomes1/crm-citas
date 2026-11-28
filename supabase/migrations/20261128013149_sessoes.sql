-- Entrar e camada de serviço · spec 20261128-030000-entrar-servico · plan.md §3.1, §3.4 e §6 (M3) · ADR 0019 (D8 a D10).
-- A sessão conferida no banco a cada pedido (ADR 0018 · D4 e D5): uma linha por session_id do token.
-- Nenhuma linha é apagada: sair, vencer (12 h) e parar (30 min) só marcam encerrada_em, que nunca volta a nulo.
-- iniciar_sessao recusa session_id já visto e entrada por senha com mais de 60 s: um cookie antigo não renasce.

-- Os três limites numa só função (E39·3·B; se o dono escolher A ou C, muda só aqui).
create function app.limites_da_sessao(out maximo interval, out parada interval, out entrada_recente interval)
language sql
immutable
set search_path = ''
as $$
  select interval '12 hours', interval '30 minutes', interval '60 seconds'
$$;

create function app.id_da_sessao()
returns uuid
language sql
stable
set search_path = ''
as $$
  select case when app.eh_uuid(auth.jwt() ->> 'session_id') then (auth.jwt() ->> 'session_id')::uuid end
$$;

create table app.sessoes (
  session_id           uuid        primary key,
  user_id              uuid        not null,
  entrou_em            timestamptz not null default now(),
  ultimo_uso           timestamptz not null default now(),
  estudio_escolhido_em timestamptz,
  encerrada_em         timestamptz,
  motivo_fim           text        check (motivo_fim in ('sair', 'tempo', 'parada', 'sem_estudio')),
  constraint sessoes_fim_com_motivo check ((encerrada_em is null) = (motivo_fim is null))
);
comment on table app.sessoes is 'Sessões de entrada (ADR 0018 · D4). Sem dado pessoal além do id da pessoa. Nenhuma linha é apagada nesta spec; o prazo de guarda é decisão do dono.';
comment on column app.sessoes.user_id is 'Sem chave estrangeira para auth.users: apagar a conta não pode apagar nem bloquear o histórico (ADR 0019 · D8).';

create index sessoes_user_id_idx on app.sessoes (user_id);

alter table app.sessoes enable row level security;
alter table app.sessoes force row level security;
revoke all on table app.sessoes from public, anon, authenticated, service_role;

-- Linha nunca apagada; encerrada nunca reabre; entrada nunca empurrada para frente.
create function app.sessoes_conferir_mudanca()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op in ('DELETE', 'TRUNCATE') then
    raise exception 'Sessao nunca e apagada' using errcode = '42501';
  end if;
  if new.session_id <> old.session_id or new.user_id <> old.user_id or new.entrou_em > old.entrou_em
     or (old.encerrada_em is not null and (new.encerrada_em is distinct from old.encerrada_em
                                           or new.motivo_fim is distinct from old.motivo_fim
                                           or new.ultimo_uso <> old.ultimo_uso
                                           or new.estudio_escolhido_em is distinct from old.estudio_escolhido_em)) then
    raise exception 'Sessao encerrada nao muda' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger sessoes_sem_apagar_nem_reabrir
  before update or delete on app.sessoes
  for each row execute function app.sessoes_conferir_mudanca();
create trigger sessoes_sem_truncate
  before truncate on app.sessoes
  for each statement execute function app.sessoes_conferir_mudanca();

-- Viva = do token atual, da própria pessoa, não encerrada, menos de 12 h desde a entrada e de 30 min parada.
create function app.sessao_viva()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from app.sessoes s, app.limites_da_sessao() l
     where s.session_id = app.id_da_sessao()
       and s.user_id = (select auth.uid())
       and s.encerrada_em is null
       and s.entrou_em > now() - l.maximo
       and s.ultimo_uso > now() - l.parada)
$$;

-- Entrar (plan.md §3.1 passo 5). Devolve o número de estúdios com papel ativo.
-- Zero: a linha nasce já encerrada (sem_estudio), para o session_id nunca valer; nada no registro (o servidor
-- grava a falha por registrar_tentativa_falha, com a mesma resposta de senha errada, RF-11).
create function app.iniciar_sessao(p_pedido uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_usuario  uuid := auth.uid();
  v_sessao   uuid := app.id_da_sessao();
  v_amr      jsonb := auth.jwt() -> 'amr';
  v_recente  interval := (select l.entrada_recente from app.limites_da_sessao() l);
  v_agora    numeric := extract(epoch from now());
  v_estudios integer;
begin
  if v_usuario is null or v_sessao is null then
    perform app.recusar('sem_login');
  end if;
  if p_pedido is null then
    perform app.recusar('entrada_invalida');
  end if;
  if exists (select 1 from app.sessoes s where s.session_id = v_sessao) then
    perform app.recusar('sem_login');
  end if;
  if v_amr is null or pg_catalog.jsonb_typeof(v_amr) <> 'array' or not exists (
       select 1 from pg_catalog.jsonb_array_elements(v_amr) a
        where pg_catalog.jsonb_typeof(a) = 'object'
          and a ->> 'method' = 'password'
          and pg_catalog.jsonb_typeof(a -> 'timestamp') = 'number'
          and (a ->> 'timestamp')::numeric between v_agora - extract(epoch from v_recente)
                                               and v_agora + extract(epoch from v_recente)) then
    perform app.recusar('sem_login');
  end if;

  select count(*) into v_estudios from public.membros m where m.user_id = v_usuario and m.ativo;

  begin
    if v_estudios = 0 then
      insert into app.sessoes (session_id, user_id, encerrada_em, motivo_fim)
      values (v_sessao, v_usuario, now(), 'sem_estudio');
    else
      insert into app.sessoes (session_id, user_id) values (v_sessao, v_usuario);
      insert into app.registro (evento, resultado, usuario_id, pedido_id)
      values ('sessao.entrar', 'ok', v_usuario, p_pedido);
    end if;
  exception when unique_violation then
    perform app.recusar('sem_login');
  end;
  return v_estudios;
end;
$$;

-- Sair (plan.md §3.4) e marcar a sessão vencida. Passa pelo pré-pedido mesmo com a sessão morta (ADR 0019 · D12).
-- Marca a linha (nunca apaga) e grava sessao.sair com o estúdio da sessão ou vazio: resultado ok quando a
-- sessão estava viva, sem_login quando já tinha vencido. Já encerrada ou sem linha: devolve false, nada muda.
create function app.encerrar_sessao(p_pedido uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_usuario uuid := auth.uid();
  v_sessao  uuid := app.id_da_sessao();
  v_linha   app.sessoes;
  v_lim     record;
  v_motivo  text;
begin
  if v_usuario is null or v_sessao is null then
    perform app.recusar('sem_login');
  end if;
  if p_pedido is null then
    perform app.recusar('entrada_invalida');
  end if;
  select * into v_linha from app.sessoes s
   where s.session_id = v_sessao and s.user_id = v_usuario
   for update;
  if not found or v_linha.encerrada_em is not null then
    return false;
  end if;
  select * into v_lim from app.limites_da_sessao();
  v_motivo := case
    when v_linha.entrou_em <= now() - v_lim.maximo then 'tempo'
    when v_linha.ultimo_uso <= now() - v_lim.parada then 'parada'
    else 'sair' end;
  update app.sessoes set encerrada_em = now(), motivo_fim = v_motivo where session_id = v_sessao;
  insert into app.registro (evento, resultado, usuario_id, org_id, pedido_id)
  values ('sessao.sair', case when v_motivo = 'sair' then 'ok' else 'sem_login' end,
          v_usuario, app.estudio_da_sessao(), p_pedido);
  return true;
end;
$$;

-- Contexto da sessão (portas 1 e 2 no banco, plan.md §3.2 passo 3). Sempre uma linha. Atualiza o último uso no
-- máximo uma vez por minuto. Sem estúdio escolhido: org_id, papel, idioma, fuso e moeda vêm nulos (o servidor
-- devolve sem_estudio).
create function app.contexto_da_sessao()
returns table (usuario_id uuid, org_id uuid, papel text, idioma text, fuso text, moeda text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_usuario uuid := auth.uid();
  v_sessao  uuid := app.id_da_sessao();
begin
  if not app.sessao_viva() then
    perform app.recusar('sem_login');
  end if;
  update app.sessoes s set ultimo_uso = now()
   where s.session_id = v_sessao and s.ultimo_uso < now() - interval '1 minute';
  return query
    select v_usuario, m.org_id, m.papel, e.idioma, e.fuso_horario, e.moeda
      from (select 1) um
      left join public.membros m on m.user_id = v_usuario and m.ativo and m.estudio_atual
      left join public.estudios e on e.org_id = m.org_id;
end;
$$;

-- Passagens em public (security invoker, só com o token da pessoa).
create function public.iniciar_sessao(p_pedido uuid)
returns integer
language sql
volatile
security invoker
set search_path = ''
as $$
  select app.iniciar_sessao(p_pedido)
$$;

create function public.encerrar_sessao(p_pedido uuid)
returns boolean
language sql
volatile
security invoker
set search_path = ''
as $$
  select app.encerrar_sessao(p_pedido)
$$;

create function public.contexto_da_sessao()
returns table (usuario_id uuid, org_id uuid, papel text, idioma text, fuso text, moeda text)
language sql
volatile
security invoker
set search_path = ''
as $$
  select c.usuario_id, c.org_id, c.papel, c.idioma, c.fuso, c.moeda from app.contexto_da_sessao() c
$$;

revoke all on function app.limites_da_sessao() from public, anon, authenticated, service_role;
revoke all on function app.id_da_sessao() from public, anon, authenticated, service_role;
revoke all on function app.sessoes_conferir_mudanca() from public, anon, authenticated, service_role;
revoke all on function app.sessao_viva() from public, anon, authenticated, service_role;
revoke all on function app.iniciar_sessao(uuid) from public, anon, authenticated, service_role;
revoke all on function app.encerrar_sessao(uuid) from public, anon, authenticated, service_role;
revoke all on function app.contexto_da_sessao() from public, anon, authenticated, service_role;
revoke all on function public.iniciar_sessao(uuid) from public, anon, authenticated, service_role;
revoke all on function public.encerrar_sessao(uuid) from public, anon, authenticated, service_role;
revoke all on function public.contexto_da_sessao() from public, anon, authenticated, service_role;

grant execute on function app.iniciar_sessao(uuid) to authenticated;
grant execute on function app.encerrar_sessao(uuid) to authenticated;
grant execute on function app.contexto_da_sessao() to authenticated;
grant execute on function public.iniciar_sessao(uuid) to authenticated;
grant execute on function public.encerrar_sessao(uuid) to authenticated;
grant execute on function public.contexto_da_sessao() to authenticated;
