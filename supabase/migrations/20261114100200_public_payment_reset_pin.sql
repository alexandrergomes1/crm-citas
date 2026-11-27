-- Páginas públicas, parte 3: cobrança por link (/pagar), limite do "Esqueci a senha" e PIN do modo estúdio.
-- Encoding: UTF-8
set client_encoding = 'UTF8';
--
-- /pagar: o token já era guardado só como hash (20261029020000). Agora:
--   public_payment_open          limite por IP e por token; inválido, vencido, pago, recusado ou cancelado: a MESMA
--                                resposta (null). Só o que a página mostra.
--   public_payment_proof_begin   reserva a vaga do arquivo e diz a pasta <estúdio>/<pedido> (o servidor gera o nome)
--   public_payment_proof_submit  registra o arquivo depois de o servidor conferir o tipo pelos primeiros bytes
--   Erros do link sempre 'not_found'; limite de arquivos 'limit'; o tamanho vem só do Storage (sem tamanho: inválido).
--   Saem get_payment_request_by_token, begin_payment_proof_upload e submit_payment_proof (o app usa só as novas).
-- Esqueci a senha: public_password_reset_allowed (5 pedidos por hora por IP, 3 por e-mail; só hashes).
-- PIN: bloqueio que cresce a cada bloqueio seguido (5 min, 10, 20 … até 24 h) e registro de cada bloqueio.

-- ─── /pagar ──────────────────────────────────────────────────────────────────────────────────────
-- p_bucket: cota do link separada para abrir a página (pay_token) e para o comprovante (pay_proof_token): abrir não gasta
-- as tentativas do envio.
create or replace function public.payment_request_by_token_internal(p_token text, p_client_key text, p_bucket text, p_token_limit integer)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_hash text;
  v_id uuid;
begin
  if not public.public_link_throttle_internal('pay_ip', p_client_key, 120, 600)
     or not public.public_link_throttle_internal('pay_miss_ip', p_client_key, 20, 600, false) then
    return null;
  end if;
  if p_token is not null and p_token ~ '^[A-Za-z0-9_-]{20,80}$' then
    v_hash := public.public_token_hash_internal(p_token);
    select r.id into v_id from public.payment_requests r
    where r.token_hash = v_hash
      and public.payment_request_public_status(r.status, r.expires_at) in ('pending', 'proof_sent')
      and public.org_has_module(r.org_id, 'cobranca');
  end if;
  if v_id is null then
    perform public.public_link_throttle_internal('pay_miss_ip', p_client_key, 20, 600);
    return null;
  end if;
  if not public.public_link_throttle_internal(p_bucket, v_hash, p_token_limit, 600) then return null; end if;
  return v_id;
end;
$$;
revoke all on function public.payment_request_by_token_internal(text, text, text, integer) from public, anon, authenticated, service_role;

create or replace function public.public_payment_open(p_token text, p_client_key text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_id uuid := public.payment_request_by_token_internal(p_token, p_client_key, 'pay_token', 60);
begin
  if v_id is null then return null; end if;
  return (
    select pg_catalog.jsonb_build_object(
      'org_name', o.name,
      'client_first_name', pg_catalog.split_part(pg_catalog.btrim(c.full_name), ' ', 1),
      'amount', r.amount,
      'currency', r.currency,
      'reason', r.reason,
      'reference', r.reference,
      'accounts', r.accounts,
      'expires_at', r.expires_at,
      'status', public.payment_request_public_status(r.status, r.expires_at),
      'proof_uploaded_at', r.proof_uploaded_at,
      'guidance', o.settings #>> '{payment_request,guidance}')
    from public.payment_requests r
    join public.organizations o on o.id = r.org_id
    join public.clients c on c.id = r.client_id and c.org_id = r.org_id
    where r.id = v_id);
end;
$$;
revoke all on function public.public_payment_open(text, text) from public, anon, authenticated;
grant execute on function public.public_payment_open(text, text) to service_role;

-- Passo 1 do comprovante: o link vale; reserva uma das 5 vagas (p_reserve) e devolve a pasta. O nome do arquivo é
-- gerado no servidor (<pasta>/<uuid>.<ext>).
create or replace function public.public_payment_proof_begin(p_token text, p_client_key text, p_reserve boolean)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_id uuid := public.payment_request_by_token_internal(p_token, p_client_key, 'pay_proof_token', 20);
  r public.payment_requests;
begin
  if v_id is null then return pg_catalog.jsonb_build_object('error', 'not_found'); end if;
  select * into r from public.payment_requests where id = v_id for update;
  if coalesce(p_reserve, false) then
    if r.proof_uploads_issued >= 5 then return pg_catalog.jsonb_build_object('error', 'limit'); end if;
    update public.payment_requests set proof_uploads_issued = proof_uploads_issued + 1 where id = r.id;
  end if;
  return pg_catalog.jsonb_build_object('folder', r.org_id::text || '/' || r.id::text, 'proof_path', r.proof_path);
end;
$$;
revoke all on function public.public_payment_proof_begin(text, text, boolean) from public, anon, authenticated;
grant execute on function public.public_payment_proof_begin(text, text, boolean) to service_role;

-- Passo 2: registra o arquivo (tamanho lido do Storage, não do chamador). Mesmas regras de submit_payment_proof.
create or replace function public.public_payment_proof_submit(
  p_token text, p_client_key text, p_path text, p_mime text, p_note text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_id uuid := public.payment_request_by_token_internal(p_token, p_client_key, 'pay_proof_token', 20);
  r public.payment_requests;
  v_size bigint;
begin
  if v_id is null then return pg_catalog.jsonb_build_object('error', 'not_found'); end if;
  select * into r from public.payment_requests where id = v_id for update;
  if p_path is null or pg_catalog.char_length(p_path) > 200
     or p_path !~ ('^' || r.org_id::text || '/' || r.id::text || '/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp|heic|pdf)$')
     or p_path is not distinct from r.proof_path
     or p_mime is null or p_mime not in ('image/jpeg', 'image/png', 'image/webp', 'image/heic', 'application/pdf')
     or pg_catalog.char_length(coalesce(p_note, '')) > 300 then
    return pg_catalog.jsonb_build_object('error', 'invalid');
  end if;
  select (o.metadata ->> 'size')::bigint into v_size
  from storage.objects o where o.bucket_id = 'payment-proofs' and o.name = p_path;
  if not found or v_size is null or v_size not between 1 and 10485760 then
    return pg_catalog.jsonb_build_object('error', 'invalid');
  end if;

  update public.payment_requests set
    status = 'proof_sent', proof_path = p_path, proof_mime = p_mime, proof_size = v_size,
    proof_note = nullif(pg_catalog.left(pg_catalog.btrim(coalesce(p_note, '')), 300), ''),
    proof_uploaded_at = pg_catalog.now(), updated_at = pg_catalog.now()
  where id = r.id;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
  values (r.org_id, null, 'payment_requests', 'PAYMENT_PROOF_SUBMITTED', r.id,
          pg_catalog.jsonb_build_object('mime', p_mime, 'size', v_size));
  return pg_catalog.jsonb_build_object('status', 'proof_sent');
end;
$$;
revoke all on function public.public_payment_proof_submit(text, text, text, text, text) from public, anon, authenticated;
grant execute on function public.public_payment_proof_submit(text, text, text, text, text) to service_role;

-- As antigas pelo token saem (o app usa só as public_payment_*; a de leitura era executável por anon).
drop function if exists public.get_payment_request_by_token(text);
drop function if exists public.begin_payment_proof_upload(text, boolean);
drop function if exists public.submit_payment_proof(text, text, text, int, text);

-- ─── Esqueci a senha ─────────────────────────────────────────────────────────────────────────────
-- O servidor pergunta antes de pedir o e-mail ao Supabase Auth. Conta sempre (exista ou não o e-mail): a resposta
-- para a pessoa é a mesma nos dois casos.
create or replace function public.public_password_reset_allowed(p_client_key text, p_email_hash text)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_ip boolean := public.public_link_throttle_internal('reset_ip', p_client_key, 5, 3600);
  v_email boolean := public.public_link_throttle_internal('reset_email', p_email_hash, 3, 3600);
begin
  return v_ip and v_email;
end;
$$;
revoke all on function public.public_password_reset_allowed(text, text) from public, anon, authenticated;
grant execute on function public.public_password_reset_allowed(text, text) to service_role;

-- ─── PIN do modo estúdio ─────────────────────────────────────────────────────────────────────────
alter table public.studio_mode_pins add column if not exists lock_count integer not null default 0;
alter table public.studio_mode_pins drop constraint if exists studio_mode_pins_lock_count_check;
alter table public.studio_mode_pins add constraint studio_mode_pins_lock_count_check check (lock_count between 0 and 1000);

-- Definir ou trocar o PIN: igual à versão vigente (20261030400200), zerando também o bloqueio crescente.
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

  insert into public.studio_mode_pins (org_id, pin_hash, failed_attempts, locked_until, lock_count, updated_by, updated_at)
  values (p_org_id, extensions.crypt(p_pin, extensions.gen_salt('bf', 10)), 0, null, 0, v_uid, pg_catalog.now())
  on conflict (org_id) do update
    set pin_hash = excluded.pin_hash, failed_attempts = 0, locked_until = null, lock_count = 0,
        updated_by = excluded.updated_by, updated_at = excluded.updated_at;

  -- O PIN nunca entra no registro.
  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id)
  values (p_org_id, v_uid, 'organizations', 'STUDIO_PIN_SET', p_org_id);
end;
$$;
revoke all on function public.set_studio_pin(uuid, text) from public, anon;
grant execute on function public.set_studio_pin(uuid, text) to authenticated;

-- Igual à versão vigente (20261030400200) com o bloqueio crescente: 5 erros seguidos travam por 5 min; cada novo
-- bloqueio sem acerto no meio dobra o tempo (até 24 h). Acerto zera. Cada bloqueio vai para a auditoria.
create or replace function public.verify_studio_pin(p_org_id uuid, p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v record;
  v_fails integer;
  v_minutes integer;
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
    update public.studio_mode_pins set failed_attempts = 0, locked_until = null, lock_count = 0 where org_id = p_org_id;
    return pg_catalog.jsonb_build_object('ok', true);
  end if;

  v_fails := v.failed_attempts + 1;
  if v_fails >= 5 then
    v_minutes := least(5 * (2 ^ least(v.lock_count, 9))::integer, 1440);
    update public.studio_mode_pins
       set failed_attempts = 0, locked_until = pg_catalog.now() + pg_catalog.make_interval(mins => v_minutes),
           lock_count = least(v.lock_count + 1, 1000)
     where org_id = p_org_id;
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
    values (p_org_id, (select auth.uid()), 'studio_mode_pins', 'STUDIO_PIN_LOCKED', null,
            pg_catalog.jsonb_build_object('minutes', v_minutes, 'lock_count', v.lock_count + 1));
    return pg_catalog.jsonb_build_object('ok', false, 'reason', 'locked', 'retry_after_seconds', v_minutes * 60);
  end if;
  update public.studio_mode_pins set failed_attempts = v_fails where org_id = p_org_id;
  return pg_catalog.jsonb_build_object('ok', false, 'reason', 'wrong', 'remaining', 5 - v_fails);
end;
$$;
revoke all on function public.verify_studio_pin(uuid, text) from public, anon;
grant execute on function public.verify_studio_pin(uuid, text) to authenticated;
