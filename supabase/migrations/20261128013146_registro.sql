-- Entrar e camada de serviço · spec 20261128-030000-entrar-servico · plan.md §6 (M1) · ADR 0019 (D1 a D3).
-- O registro (porta 6, auditoria): quem fez o quê, só com identificadores, nunca texto livre (RF-24, RF-25).
-- Fora da API (esquema app), RLS ligada e forçada sem política, nenhum privilégio para quem chama.
-- Ninguém altera nem apaga uma linha (RF-26): gatilho recusa update, delete e truncate.

-- Recusa padrão: a Data API (PostgREST) devolve só o código no corpo, sem texto do banco (RF-22).
create function app.recusar(p_codigo text)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_codigo text := case
    when p_codigo in ('sem_login', 'estudio_trocado', 'sem_estudio', 'sem_permissao',
                      'entrada_invalida', 'conflito', 'limite', 'erro_interno') then p_codigo
    else 'erro_interno' end;
  v_status int := case v_codigo
    when 'sem_login' then 401
    when 'estudio_trocado' then 409
    when 'sem_estudio' then 403
    when 'sem_permissao' then 403
    when 'entrada_invalida' then 400
    when 'conflito' then 409
    when 'limite' then 429
    else 500 end;
begin
  raise sqlstate 'PGRST' using
    message = pg_catalog.jsonb_build_object('code', v_codigo, 'message', v_codigo)::text,
    detail = pg_catalog.jsonb_build_object('status', v_status, 'headers', pg_catalog.jsonb_build_object())::text;
end;
$$;
comment on function app.recusar(text) is 'Recusa com um código de RF-22 (raise sqlstate PGRST). Texto do banco nunca sai.';

create function app.eh_uuid(p_valor text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(p_valor ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', false)
$$;

create table app.registro (
  id         bigint      generated always as identity primary key,
  quando     timestamptz not null default now(),
  evento     text        not null check (evento ~ '^[a-z_.]{1,64}$'),
  resultado  text        not null check (resultado in ('ok', 'sem_login', 'estudio_trocado', 'sem_estudio',
                         'sem_permissao', 'entrada_invalida', 'conflito', 'limite', 'erro_interno')),
  usuario_id uuid,
  org_id     uuid,
  objetos    uuid[]      check (objetos is null or (cardinality(objetos) between 1 and 10
                                                     and array_position(objetos, null) is null)),
  pedido_id  uuid        not null,
  -- Tentativa de entrar que falha: só evento, resultado, quando e pedido (RF-24a).
  constraint registro_falha_de_entrar_sem_pessoa check (
    evento <> 'sessao.entrar' or resultado = 'ok'
    or (usuario_id is null and org_id is null and objetos is null))
);
comment on table app.registro is 'Registro de auditoria (porta 6). Só identificadores; sem nome, e-mail, IP ou texto digitado (RF-25). Nenhuma linha é alterada nem apagada nesta spec; o prazo de guarda é decisão do dono.';

create index registro_org_quando_idx on app.registro (org_id, quando);
create index registro_usuario_quando_idx on app.registro (usuario_id, quando);
create index registro_evento_quando_idx on app.registro (evento, quando);

alter table app.registro enable row level security;
alter table app.registro force row level security;
revoke all on table app.registro from public, anon, authenticated, service_role;

create function app.registro_somente_acrescenta()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'O registro so aceita linhas novas' using errcode = '42501';
end;
$$;

create trigger registro_sem_alterar_nem_apagar
  before update or delete on app.registro
  for each row execute function app.registro_somente_acrescenta();
create trigger registro_sem_truncate
  before truncate on app.registro
  for each statement execute function app.registro_somente_acrescenta();

revoke all on function app.recusar(text) from public, anon, authenticated, service_role;
revoke all on function app.eh_uuid(text) from public, anon, authenticated, service_role;
revoke all on function app.registro_somente_acrescenta() from public, anon, authenticated, service_role;
