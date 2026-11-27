-- Regra de negócio (Alexandre, 14/11/2026): pacote cancelado ou vencido nunca volta a ficar ativo.
-- Encoding: UTF-8
--
-- Vale para qualquer caminho que grave em client_entitlements: funções do app (devolver sessão,
-- estorno de venda, checkout), funções antigas e UPDATE direto pela API.
-- 1. Cancelado ou vencido não pode virar 'active' nem 'exhausted' (recusa com 22023).
--    Vencido pode virar cancelado (estorno da venda do pacote); cancelado continua cancelado.
--    Mudar só o contador de sessões (estorno que devolve sessão) mantém o status como está.
-- 2. Pacote que ficaria 'active' com a validade já passada fica 'expired' (ex.: devolver sessão
--    ou estornar um pacote esgotado cuja data venceu).
-- Gatilho BEFORE UPDATE, função INVOKER sem acesso a nada além da própria linha.
-- 3. Devolver sessão (restore_entitlement_session_atomic, recriada abaixo igual à de 20261114010000)
--    também recusa pacote com validade passada, mesmo que o status ainda diga esgotado ou ativo:
--    assim a auditoria nunca registra "ativo" para um pacote que ficou vencido.

create or replace function public.client_entitlements_status_guard()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if old.status in ('cancelled', 'expired') and new.status in ('active', 'exhausted') then
    raise exception 'Pacote cancelado ou vencido não volta a ficar ativo' using errcode = '22023';
  end if;
  if old.status = 'cancelled' and new.status <> 'cancelled' then
    raise exception 'Pacote cancelado continua cancelado' using errcode = '22023';
  end if;
  if new.status = 'active' and new.expires_at is not null and new.expires_at < pg_catalog.now() then
    new.status := 'expired';
  end if;
  return new;
end;
$$;
revoke all on function public.client_entitlements_status_guard() from public, anon, authenticated;

drop trigger if exists trg_client_entitlements_status_guard on public.client_entitlements;
create trigger trg_client_entitlements_status_guard
  before update of status, used_sessions, expires_at on public.client_entitlements
  for each row execute function public.client_entitlements_status_guard();

create or replace function public.restore_entitlement_session_atomic(
  p_org_id uuid,
  p_entitlement_id uuid,
  p_description text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_client uuid;
  v_used integer;
  v_status text;
  v_expires timestamptz;
  v_description text := nullif(pg_catalog.btrim(coalesce(p_description, '')), '');
begin
  if v_uid is null then
    raise exception 'Autenticação obrigatória' using errcode = '42501';
  end if;
  if not public.has_permission(p_org_id, 'comanda.operate') then
    raise exception 'Sem permissão para restaurar sessão' using errcode = '42501';
  end if;
  if pg_catalog.char_length(v_description) > 200 then
    raise exception 'A descrição deve ter no máximo 200 caracteres' using errcode = '22023';
  end if;

  select e.client_id, e.used_sessions, e.status, e.expires_at into v_client, v_used, v_status, v_expires
  from public.client_entitlements e
  where e.id = p_entitlement_id and e.org_id = p_org_id
  for update;
  if not found then
    raise exception 'Pacote não encontrado' using errcode = 'P0002';
  end if;
  if v_status in ('cancelled', 'expired') then
    raise exception 'Pacote cancelado ou vencido: não dá para restaurar sessão' using errcode = 'P0001';
  end if;
  if v_expires is not null and v_expires < pg_catalog.now() then
    raise exception 'Pacote vencido: não dá para restaurar sessão' using errcode = 'P0001';
  end if;
  if v_used <= 0 then
    raise exception 'Nenhuma sessão para restaurar' using errcode = 'P0001';
  end if;

  update public.client_entitlements
  set used_sessions = v_used - 1, status = 'active'
  where id = p_entitlement_id and org_id = p_org_id;

  insert into public.client_entitlement_entries (
    org_id, entitlement_id, client_id, action, sessions_delta, sessions_before, sessions_after, description, created_by
  ) values (
    p_org_id, p_entitlement_id, v_client, 'restore', 1, v_used, v_used - 1, v_description, v_uid
  );

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (
    p_org_id, v_uid, 'client_entitlements', 'ENTITLEMENT_SESSION_RESTORED', p_entitlement_id,
    pg_catalog.jsonb_build_object('used_sessions', v_used, 'status', v_status),
    pg_catalog.jsonb_build_object('used_sessions', v_used - 1, 'status', 'active', 'description', v_description)
  );

  return pg_catalog.jsonb_build_object('used_sessions', v_used - 1);
end;
$$;
revoke all on function public.restore_entitlement_session_atomic(uuid, uuid, text) from public, anon;
grant execute on function public.restore_entitlement_session_atomic(uuid, uuid, text) to authenticated;
