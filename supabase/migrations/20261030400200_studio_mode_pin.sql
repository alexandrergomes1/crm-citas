-- Modo estúdio: PIN da equipe guardado no servidor (hash com sal por estúdio, limite de tentativas).
-- Encoding: UTF-8
--
-- Antes o PIN ficava só no aparelho (localStorage) e cada aparelho tinha o seu. Agora há um PIN por
-- estúdio, definido e redefinido por quem tem "ajustes.manage"; o aparelho só guarda se está
-- desbloqueado. O hash é bcrypt (pgcrypto): o sal é gerado a cada gravação, então dois estúdios com o
-- mesmo PIN têm hashes diferentes. Tabela sem nenhuma política: ninguém lê pela API, só as funções.
--
-- Tentativas: 5 erros seguidos travam a conferência por 5 minutos (vale para o estúdio todo, em todos os
-- aparelhos); acertar zera o contador. A função NÃO levanta erro quando o PIN está errado, senão o
-- contador voltaria atrás junto com a transação.
--
-- Aditiva: tabela e funções novas; nada que o app em produção chama muda.
set client_encoding = 'UTF8';

create table if not exists public.studio_mode_pins (
  org_id          uuid        primary key references public.organizations(id) on delete cascade,
  pin_hash        text        not null,
  failed_attempts integer     not null default 0 check (failed_attempts >= 0),
  locked_until    timestamptz,
  updated_by      uuid,
  updated_at      timestamptz not null default now()
);
comment on table public.studio_mode_pins is
  'PIN do modo estúdio (bcrypt). Só por função: set_studio_pin, verify_studio_pin, studio_pin_status.';

alter table public.studio_mode_pins enable row level security;
revoke all on public.studio_mode_pins from anon, authenticated;

-- Definir ou redefinir (gestão do estúdio) ---------------------------------------------------------
create or replace function public.set_studio_pin(p_org_id uuid, p_pin text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null or not public.has_permission(p_org_id, 'ajustes.manage') then
    raise exception 'Sem permissão para definir o PIN do modo estúdio' using errcode = '42501';
  end if;
  if p_pin is null or p_pin !~ '^[0-9]{4,6}$' then
    raise exception 'O PIN tem de 4 a 6 números' using errcode = '22023';
  end if;

  insert into public.studio_mode_pins (org_id, pin_hash, failed_attempts, locked_until, updated_by, updated_at)
  values (p_org_id, extensions.crypt(p_pin, extensions.gen_salt('bf', 10)), 0, null, v_uid, pg_catalog.now())
  on conflict (org_id) do update
    set pin_hash = excluded.pin_hash, failed_attempts = 0, locked_until = null,
        updated_by = excluded.updated_by, updated_at = excluded.updated_at;

  -- O PIN nunca entra no registro.
  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id)
  values (p_org_id, v_uid, 'organizations', 'STUDIO_PIN_SET', p_org_id);
end;
$$;
revoke all on function public.set_studio_pin(uuid, text) from public, anon;
grant execute on function public.set_studio_pin(uuid, text) to authenticated;

-- Existe PIN? (a equipe precisa saber se pode entregar o aparelho) ---------------------------------
create or replace function public.studio_pin_status(p_org_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v record;
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'anamnese.view_status') then
    raise exception 'Sem permissão para consultar o modo estúdio' using errcode = '42501';
  end if;
  select p.updated_at, p.locked_until into v from public.studio_mode_pins p where p.org_id = p_org_id;
  if not found then
    return pg_catalog.jsonb_build_object('configured', false);
  end if;
  return pg_catalog.jsonb_build_object('configured', true, 'updated_at', v.updated_at,
    'locked', coalesce(v.locked_until > pg_catalog.now(), false));
end;
$$;
revoke all on function public.studio_pin_status(uuid) from public, anon;
grant execute on function public.studio_pin_status(uuid) to authenticated;

-- Conferir o PIN para sair do modo estúdio ---------------------------------------------------------
create or replace function public.verify_studio_pin(p_org_id uuid, p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v record;
  v_fails integer;
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'anamnese.view_status') then
    raise exception 'Sem permissão para usar o modo estúdio' using errcode = '42501';
  end if;

  select * into v from public.studio_mode_pins p where p.org_id = p_org_id for update;
  if not found then
    return pg_catalog.jsonb_build_object('ok', false, 'reason', 'not_configured');
  end if;
  if v.locked_until is not null and v.locked_until > pg_catalog.now() then
    return pg_catalog.jsonb_build_object('ok', false, 'reason', 'locked',
      'retry_after_seconds', ceil(extract(epoch from (v.locked_until - pg_catalog.now())))::integer);
  end if;

  if p_pin is not null and p_pin ~ '^[0-9]{4,6}$' and extensions.crypt(p_pin, v.pin_hash) = v.pin_hash then
    update public.studio_mode_pins set failed_attempts = 0, locked_until = null where org_id = p_org_id;
    return pg_catalog.jsonb_build_object('ok', true);
  end if;

  v_fails := v.failed_attempts + 1;
  if v_fails >= 5 then
    update public.studio_mode_pins set failed_attempts = 0, locked_until = pg_catalog.now() + interval '5 minutes'
     where org_id = p_org_id;
    return pg_catalog.jsonb_build_object('ok', false, 'reason', 'locked', 'retry_after_seconds', 300);
  end if;
  update public.studio_mode_pins set failed_attempts = v_fails where org_id = p_org_id;
  return pg_catalog.jsonb_build_object('ok', false, 'reason', 'wrong', 'remaining', 5 - v_fails);
end;
$$;
revoke all on function public.verify_studio_pin(uuid, text) from public, anon;
grant execute on function public.verify_studio_pin(uuid, text) to authenticated;
