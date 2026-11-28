-- Entrar e camada de serviço · spec 20261128-030000-entrar-servico · plan.md §3.1 passo 3 e §6 (M4) · ADR 0019 (D11).
-- Limite de tentativas de entrar (ADR 0018 · D8): contador fora do registro e fora da API, que expira sozinho.
-- O banco nunca vê IP nem e-mail: só a chave HMAC-SHA-256 (32 bytes) calculada no servidor (RF-08, RGPD art. 5(1)(c), (e)).
-- 10 por conta e 30 por IP em 15 min (janela fixa a partir da primeira tentativa); teto global de linhas.

create table app.tentativas_entrada (
  tipo          text        not null check (tipo in ('ip', 'conta')),
  chave         bytea       not null check (octet_length(chave) = 32),
  janela_inicio timestamptz not null default now(),
  contagem      integer     not null default 1 check (contagem > 0),
  primary key (tipo, chave)
);
comment on table app.tentativas_entrada is 'Contador de tentativas de entrar por chave HMAC de IP e de conta. Linhas vencidas (15 min) são apagadas a cada chamada.';

create index tentativas_entrada_janela_idx on app.tentativas_entrada (janela_inicio);

alter table app.tentativas_entrada enable row level security;
alter table app.tentativas_entrada force row level security;
revoke all on table app.tentativas_entrada from public, anon, authenticated, service_role;

-- Conta esta tentativa e diz se pode seguir (true) ou se passou do limite (false → limite).
create function app.conferir_tentativa(p_chave_ip bytea, p_chave_conta bytea)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_janela     constant interval := interval '15 minutes';
  v_max_conta  constant int := 10;
  v_max_ip     constant int := 30;
  v_teto       constant int := 10000;
  v_linhas     int;
  v_conta      int;
  v_ip         int;
begin
  if p_chave_ip is null or p_chave_conta is null
     or octet_length(p_chave_ip) <> 32 or octet_length(p_chave_conta) <> 32 then
    perform app.recusar('entrada_invalida');
  end if;
  -- Uma chamada por vez: o teto global e as contagens ficam exatos.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('app.conferir_tentativa', 0));

  delete from app.tentativas_entrada t where t.janela_inicio <= now() - v_janela;

  select count(*) into v_linhas from app.tentativas_entrada;
  if v_linhas + 2 > v_teto and (
       not exists (select 1 from app.tentativas_entrada t where t.tipo = 'ip' and t.chave = p_chave_ip)
       or not exists (select 1 from app.tentativas_entrada t where t.tipo = 'conta' and t.chave = p_chave_conta)) then
    return false;
  end if;

  insert into app.tentativas_entrada as t (tipo, chave) values ('ip', p_chave_ip)
  on conflict (tipo, chave) do update set contagem = t.contagem + 1
  returning t.contagem into v_ip;
  insert into app.tentativas_entrada as t (tipo, chave) values ('conta', p_chave_conta)
  on conflict (tipo, chave) do update set contagem = t.contagem + 1
  returning t.contagem into v_conta;

  return v_conta <= v_max_conta and v_ip <= v_max_ip;
end;
$$;

create function public.conferir_tentativa(p_chave_ip bytea, p_chave_conta bytea)
returns boolean
language sql
volatile
security invoker
set search_path = ''
as $$
  select app.conferir_tentativa(p_chave_ip, p_chave_conta)
$$;
comment on function public.conferir_tentativa(bytea, bytea) is 'Passagem (security invoker) para anon: conta a tentativa de entrar e diz se passou do limite.';

revoke all on function app.conferir_tentativa(bytea, bytea) from public, anon, authenticated, service_role;
revoke all on function public.conferir_tentativa(bytea, bytea) from public, anon, authenticated, service_role;
grant execute on function app.conferir_tentativa(bytea, bytea) to anon;
grant execute on function public.conferir_tentativa(bytea, bytea) to anon;
