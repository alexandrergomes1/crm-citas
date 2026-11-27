-- ============================================================
-- KA Beauty OS · Cobrança por transferência com comprovante (spec 30)
-- Encoding: UTF-8
--
-- 1. payment_accounts: contas de recebimento do estúdio (Bizum, SEPA, Pix).
-- 2. payment_requests: pedido de pagamento com link público (token só como hash).
-- 3. bucket privado payment-proofs (comprovantes), leitura só do estúdio.
-- 4. RPCs: criar, ler pelo link, registrar comprovante, confirmar, recusar, cancelar.
--
-- A confirmação lança o valor como sinal do agendamento
-- (register_appointment_deposit_atomic) ou crédito da cliente
-- (adjust_client_balance_atomic), uma única vez. O comprovante sozinho nunca dá baixa.
-- Sem regra fiscal: o sistema registra, não emite documento.
-- Depende de 20261028210000_access_modules_platform.sql (has_org_role, org_has_module).
-- ============================================================
set client_encoding = 'UTF8';

-- ─── 1. Contas de recebimento ───────────────────────────────
create table if not exists public.payment_accounts (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid not null references public.organizations(id) on delete cascade,
  kind         text not null check (kind in ('bizum', 'sepa', 'pix')),
  holder_name  text not null check (length(btrim(holder_name)) between 2 and 120),
  identifier   text not null check (length(btrim(identifier)) between 4 and 80),  -- IBAN, telefone Bizum ou chave Pix
  bic          text check (bic is null or bic ~ '^[A-Z0-9]{8}([A-Z0-9]{3})?$'),
  bank_name    text check (bank_name is null or length(bank_name) <= 80),
  active       boolean not null default true,
  position     int not null default 0,
  created_by   uuid references auth.users(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists idx_payment_accounts_org on public.payment_accounts (org_id, active, position);
comment on table public.payment_accounts is 'Contas para a cliente pagar por transferência. identifier = IBAN, telefone Bizum ou chave Pix.';

alter table public.payment_accounts enable row level security;

drop policy if exists payment_accounts_select on public.payment_accounts;
create policy payment_accounts_select on public.payment_accounts for select to authenticated
  using (org_id in (select public.auth_org_ids()));
drop policy if exists payment_accounts_write on public.payment_accounts;
create policy payment_accounts_write on public.payment_accounts for all to authenticated
  using (public.has_org_role(org_id, array['owner', 'admin']))
  with check (public.has_org_role(org_id, array['owner', 'admin']));

revoke all on public.payment_accounts from anon;
revoke truncate, trigger, references on public.payment_accounts from authenticated;

-- ─── 2. Pedidos de pagamento ────────────────────────────────
create table if not exists public.payment_requests (
  id                 uuid primary key default gen_random_uuid(),
  org_id             uuid not null references public.organizations(id) on delete cascade,
  client_id          uuid not null,
  appointment_id     uuid,
  purpose            text not null check (purpose in ('deposit', 'credit')),
  amount             numeric(12,2) not null check (amount > 0 and amount <= 100000),
  currency           text not null default 'EUR' check (currency ~ '^[A-Z]{3}$'),
  reason             text not null check (length(btrim(reason)) between 2 and 140),
  reference          text not null check (length(reference) between 3 and 40),
  accounts           jsonb not null check (jsonb_typeof(accounts) = 'array' and jsonb_array_length(accounts) > 0),
  token_hash         text not null unique,
  expires_at         timestamptz not null,
  status             text not null default 'pending'
                     check (status in ('pending', 'proof_sent', 'confirmed', 'rejected', 'canceled')),
  proof_path         text,
  proof_mime         text,
  proof_size         int,
  proof_note         text check (proof_note is null or length(proof_note) <= 300),
  proof_uploaded_at  timestamptz,
  proof_uploads_issued int not null default 0 check (proof_uploads_issued between 0 and 5),
  confirmed_method   text,
  confirmed_by       uuid references auth.users(id) on delete set null,
  confirmed_at       timestamptz,
  rejected_by        uuid references auth.users(id) on delete set null,
  rejected_at        timestamptz,
  reject_reason      text check (reject_reason is null or length(reject_reason) <= 300),
  result             jsonb,
  created_by         uuid references auth.users(id) on delete set null,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  foreign key (client_id) references public.clients(id) on delete cascade,
  foreign key (appointment_id) references public.appointments(id) on delete set null
);
create index if not exists idx_payment_requests_org_status on public.payment_requests (org_id, status, created_at desc);
create index if not exists idx_payment_requests_client on public.payment_requests (client_id);
create index if not exists idx_payment_requests_appointment on public.payment_requests (appointment_id);
comment on table public.payment_requests is 'Cobrança por link. accounts = cópia das contas no momento do pedido. Status "expirado" é calculado por expires_at.';

alter table public.payment_requests enable row level security;

-- Leitura para quem opera comanda; escrita só pelas RPCs abaixo.
drop policy if exists payment_requests_select on public.payment_requests;
create policy payment_requests_select on public.payment_requests for select to authenticated
  using (public.has_org_role(org_id, array['owner', 'admin', 'manager', 'receptionist', 'finance']));

revoke all on public.payment_requests from anon;
revoke insert, update, delete, truncate, trigger, references on public.payment_requests from authenticated;

-- ─── 3. Bucket privado de comprovantes ──────────────────────
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('payment-proofs', 'payment-proofs', false, 10485760,
        array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'application/pdf'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Pasta = org_id/pedido/arquivo. O upload é feito pelo servidor (service_role) depois de
-- validar o link; o estúdio só lê (URL assinada curta).
drop policy if exists payment_proofs_select on storage.objects;
create policy payment_proofs_select on storage.objects for select to authenticated
  using (
    case
      when bucket_id = 'payment-proofs'
           and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then public.has_org_role(((storage.foldername(name))[1])::uuid,
                                 array['owner', 'admin', 'manager', 'receptionist', 'finance'])
      else false
    end
  );

-- ─── 4. RPCs ────────────────────────────────────────────────
create or replace function public.payment_request_public_status(p_status text, p_expires_at timestamptz)
returns text
language sql
stable
set search_path to ''
as $$
  select case when p_status in ('pending', 'proof_sent') and p_expires_at < now() then 'expired' else p_status end;
$$;

-- Cria o pedido e devolve o token uma única vez (o banco guarda só o hash).
create or replace function public.create_payment_request(
  p_org_id uuid,
  p_client_id uuid,
  p_appointment_id uuid,
  p_purpose text,
  p_amount numeric,
  p_reason text,
  p_account_ids uuid[],
  p_expires_in_hours int default 24
) returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_token text;
  v_accounts jsonb;
  v_reference text;
  v_id uuid;
  v_appt public.appointments;
begin
  if v_uid is null then raise exception 'Sessão expirada' using errcode = '42501'; end if;
  if not public.has_org_role(p_org_id, array['owner', 'admin', 'manager', 'receptionist', 'finance']) then
    raise exception 'Sem permissão para cobrar' using errcode = '42501';
  end if;
  if not public.org_has_module(p_org_id, 'cobranca') then
    raise exception 'Cobrança por transferência não está no plano' using errcode = '42501';
  end if;
  if p_purpose not in ('deposit', 'credit') then
    raise exception 'Tipo de cobrança inválido' using errcode = '22023';
  end if;
  -- Crédito segue a regra do saldo da cliente: só quem pode lançar crédito pode cobrar.
  if p_purpose = 'credit' and not public.has_org_role(p_org_id, array['owner', 'admin', 'manager']) then
    raise exception 'Só proprietária, administração ou gestão cobram crédito' using errcode = '42501';
  end if;
  if p_amount is null or round(p_amount, 2) <= 0 or p_amount > 100000 then
    raise exception 'Valor inválido' using errcode = '22003';
  end if;
  if p_expires_in_hours is null or p_expires_in_hours not between 1 and 336 then
    raise exception 'Validade deve ficar entre 1 hora e 14 dias' using errcode = '22023';
  end if;
  if not exists (select 1 from public.clients c where c.id = p_client_id and c.org_id = p_org_id) then
    raise exception 'Cliente não encontrada' using errcode = 'P0002';
  end if;
  if p_purpose = 'deposit' then
    select * into v_appt from public.appointments a where a.id = p_appointment_id and a.org_id = p_org_id;
    if not found or v_appt.client_id is distinct from p_client_id then
      raise exception 'Agendamento não encontrado para esta cliente' using errcode = 'P0002';
    end if;
    if v_appt.status not in ('Reservado', 'Agendado', 'Confirmado') then
      raise exception 'Sinal só antes do início do atendimento' using errcode = 'P0001';
    end if;
    -- Mesmo limite do registro de sinal: não passar do valor do atendimento.
    if coalesce(nullif((select sum(ai.price * ai.qty) from public.appointment_items ai
                        where ai.org_id = p_org_id and ai.appointment_id = p_appointment_id), 0), v_appt.total, 0) > 0
       and round(p_amount, 2) + (select coalesce(sum(ad.amount), 0) from public.appointment_deposits ad
                                 where ad.org_id = p_org_id and ad.appointment_id = p_appointment_id
                                   and ad.status in ('confirmed', 'applied'))
           > coalesce(nullif((select sum(ai.price * ai.qty) from public.appointment_items ai
                              where ai.org_id = p_org_id and ai.appointment_id = p_appointment_id), 0), v_appt.total, 0) then
      raise exception 'Sinal maior que o valor do atendimento' using errcode = '22003';
    end if;
  elsif p_appointment_id is not null
        and not exists (select 1 from public.appointments a where a.id = p_appointment_id and a.org_id = p_org_id) then
    raise exception 'Agendamento não encontrado' using errcode = 'P0002';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'kind', pa.kind, 'holder_name', pa.holder_name, 'identifier', pa.identifier,
           'bic', pa.bic, 'bank_name', pa.bank_name) order by pa.position, pa.created_at), '[]'::jsonb)
    into v_accounts
  from public.payment_accounts pa
  where pa.org_id = p_org_id and pa.active and pa.id = any (coalesce(p_account_ids, '{}'));
  if jsonb_array_length(v_accounts) = 0 then
    raise exception 'Escolha pelo menos uma conta ativa' using errcode = '22023';
  end if;

  v_token := translate(encode(extensions.gen_random_bytes(24), 'base64'), '+/=', '-_');
  v_reference := case when p_purpose = 'deposit' then 'SINAL-' else 'PAG-' end
                 || upper(substr(md5(v_token), 1, 6));

  insert into public.payment_requests (
    org_id, client_id, appointment_id, purpose, amount, reason, reference, accounts,
    token_hash, expires_at, created_by
  ) values (
    p_org_id, p_client_id, p_appointment_id, p_purpose, round(p_amount, 2), btrim(p_reason), v_reference,
    v_accounts, encode(extensions.digest(v_token, 'sha256'), 'hex'),
    now() + make_interval(hours => p_expires_in_hours), v_uid
  ) returning id into v_id;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
  values (p_org_id, v_uid, 'payment_requests', 'PAYMENT_REQUEST_CREATED', v_id,
          jsonb_build_object('purpose', p_purpose, 'amount', round(p_amount, 2), 'reference', v_reference));

  return jsonb_build_object('id', v_id, 'token', v_token, 'reference', v_reference);
end;
$$;

-- Link público (sem login): só o necessário para pagar.
create or replace function public.get_payment_request_by_token(p_token text)
returns jsonb
language sql
stable
security definer
set search_path to ''
as $$
  select jsonb_build_object(
    'org_name', o.name,
    'client_first_name', split_part(btrim(c.full_name), ' ', 1),
    'amount', r.amount,
    'currency', r.currency,
    'reason', r.reason,
    'reference', r.reference,
    'accounts', r.accounts,
    'expires_at', r.expires_at,
    'status', public.payment_request_public_status(r.status, r.expires_at),
    'proof_uploaded_at', r.proof_uploaded_at,
    'guidance', o.settings #>> '{payment_request,guidance}'
  )
  from public.payment_requests r
  join public.organizations o on o.id = r.org_id
  join public.clients c on c.id = r.client_id
  where length(coalesce(p_token, '')) between 20 and 80
    and r.token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex');
$$;

-- Passo 1 do envio do comprovante (chamado só pelo servidor, com service_role):
-- confere o link, reserva uma das 5 vagas de arquivo e diz a pasta.
-- p_reserve = false só confere (usado ao registrar o arquivo já enviado).
create or replace function public.begin_payment_proof_upload(p_token text, p_reserve boolean default true)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  r public.payment_requests;
begin
  select * into r from public.payment_requests
  where length(coalesce(p_token, '')) between 20 and 80
    and token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
  for update;
  if not found then raise exception 'Link inválido' using errcode = 'P0002'; end if;
  if public.payment_request_public_status(r.status, r.expires_at) not in ('pending', 'proof_sent')
     or not public.org_has_module(r.org_id, 'cobranca') then
    raise exception 'Este pedido não aceita mais comprovante' using errcode = 'P0001';
  end if;
  if p_reserve then
    -- Reserva antes de entregar a URL de upload: pedidos em paralelo não passam de 5.
    if r.proof_uploads_issued >= 5 then
      raise exception 'Limite de arquivos deste pedido atingido' using errcode = '54000';
    end if;
    update public.payment_requests set proof_uploads_issued = proof_uploads_issued + 1 where id = r.id;
  end if;
  return jsonb_build_object('folder', r.org_id::text || '/' || r.id::text, 'proof_path', r.proof_path);
end;
$$;

-- Passo 2 (só servidor, depois de conferir o tipo real do arquivo): registra o
-- arquivo enviado pela URL assinada. O tamanho vem do Storage, não do chamador.
create or replace function public.submit_payment_proof(
  p_token text, p_path text, p_mime text, p_size int, p_note text default null
) returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  r public.payment_requests;
  v_size bigint;
begin
  select * into r from public.payment_requests
  where length(coalesce(p_token, '')) between 20 and 80
    and token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
  for update;
  if not found then raise exception 'Link inválido' using errcode = 'P0002'; end if;
  if public.payment_request_public_status(r.status, r.expires_at) not in ('pending', 'proof_sent') then
    raise exception 'Este pedido não aceita mais comprovante' using errcode = 'P0001';
  end if;
  if p_path is null or p_path not like r.org_id::text || '/' || r.id::text || '/%' or p_path like '%..%' then
    raise exception 'Arquivo inválido' using errcode = '22023';
  end if;
  if p_mime not in ('image/jpeg', 'image/png', 'image/webp', 'image/heic', 'application/pdf') then
    raise exception 'Envie foto ou PDF de até 10 MB' using errcode = '22023';
  end if;
  select coalesce((o.metadata ->> 'size')::bigint, p_size) into v_size
  from storage.objects o where o.bucket_id = 'payment-proofs' and o.name = p_path;
  if not found then
    raise exception 'Arquivo não encontrado' using errcode = 'P0002';
  end if;
  if v_size is null or v_size not between 1 and 10485760 then
    raise exception 'Envie foto ou PDF de até 10 MB' using errcode = '22023';
  end if;

  update public.payment_requests set
    status = 'proof_sent', proof_path = p_path, proof_mime = p_mime, proof_size = v_size,
    proof_note = nullif(left(btrim(coalesce(p_note, '')), 300), ''), proof_uploaded_at = now(), updated_at = now()
  where id = r.id;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
  values (r.org_id, null, 'payment_requests', 'PAYMENT_PROOF_SUBMITTED', r.id,
          jsonb_build_object('mime', p_mime, 'size', v_size));

  return jsonb_build_object('status', 'proof_sent');
end;
$$;

-- Confirma o recebimento (dinheiro visto na conta). Lança sinal ou crédito uma única vez.
create or replace function public.confirm_payment_request(p_org_id uuid, p_request_id uuid, p_method text)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_uid uuid := (select auth.uid());
  r public.payment_requests;
  v_result jsonb;
begin
  if v_uid is null then raise exception 'Sessão expirada' using errcode = '42501'; end if;
  if not public.has_org_role(p_org_id, array['owner', 'admin', 'manager', 'receptionist', 'finance']) then
    raise exception 'Sem permissão para confirmar pagamento' using errcode = '42501';
  end if;
  if p_method not in ('TRANSFER', 'BIZUM') then
    raise exception 'Forma de recebimento inválida' using errcode = '22023';
  end if;

  select * into r from public.payment_requests where id = p_request_id and org_id = p_org_id for update;
  if not found then raise exception 'Pedido não encontrado' using errcode = 'P0002'; end if;
  if r.status = 'confirmed' then
    return coalesce(r.result, '{}'::jsonb) || jsonb_build_object('duplicate', true);
  end if;
  -- Pedido vencido ainda pode ser confirmado: o dinheiro pode ter chegado depois do prazo.
  if r.status not in ('pending', 'proof_sent') then
    raise exception 'Pedido recusado ou cancelado não pode ser confirmado' using errcode = 'P0001';
  end if;

  -- O id do pedido é a chave de idempotência do lançamento.
  if r.purpose = 'deposit' then
    v_result := public.register_appointment_deposit_atomic(p_org_id, r.appointment_id, r.amount, p_method, r.id);
  else
    v_result := public.adjust_client_balance_atomic(p_org_id, r.client_id, 'credit', r.amount,
                  'Pagamento por transferência ' || r.reference, r.id);
    -- O ajuste de saldo grava o caixa como dinheiro; corrige para a forma real.
    update public.transactions t set method = p_method
    where t.org_id = p_org_id
      and t.id = (select e.transaction_id from public.client_balance_entries e
                  where e.org_id = p_org_id and e.id = (v_result ->> 'entryId')::uuid);
  end if;

  update public.payment_requests set
    status = 'confirmed', confirmed_method = p_method, confirmed_by = v_uid, confirmed_at = now(),
    result = v_result, updated_at = now()
  where id = r.id;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (p_org_id, v_uid, 'payment_requests', 'PAYMENT_REQUEST_CONFIRMED', r.id,
          jsonb_build_object('status', r.status),
          jsonb_build_object('status', 'confirmed', 'method', p_method, 'amount', r.amount, 'result', v_result));

  return v_result || jsonb_build_object('duplicate', false);
end;
$$;

-- Recusa (comprovante não confere) ou cancela (cobrança não é mais necessária).
create or replace function public.close_payment_request(p_org_id uuid, p_request_id uuid, p_action text, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_uid uuid := (select auth.uid());
  r public.payment_requests;
begin
  if v_uid is null then raise exception 'Sessão expirada' using errcode = '42501'; end if;
  if not public.has_org_role(p_org_id, array['owner', 'admin', 'manager', 'receptionist', 'finance']) then
    raise exception 'Sem permissão' using errcode = '42501';
  end if;
  if p_action not in ('reject', 'cancel') then raise exception 'Ação inválida' using errcode = '22023'; end if;
  if p_action = 'reject' and length(btrim(coalesce(p_reason, ''))) < 3 then
    raise exception 'Diga o motivo da recusa' using errcode = '22023';
  end if;

  select * into r from public.payment_requests where id = p_request_id and org_id = p_org_id for update;
  if not found then raise exception 'Pedido não encontrado' using errcode = 'P0002'; end if;
  if r.status not in ('pending', 'proof_sent') then
    raise exception 'Pedido já encerrado' using errcode = 'P0001';
  end if;

  update public.payment_requests set
    status = case when p_action = 'reject' then 'rejected' else 'canceled' end,
    rejected_by = v_uid, rejected_at = now(),
    reject_reason = nullif(left(btrim(coalesce(p_reason, '')), 300), ''), updated_at = now()
  where id = r.id;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (p_org_id, v_uid, 'payment_requests',
          case when p_action = 'reject' then 'PAYMENT_REQUEST_REJECTED' else 'PAYMENT_REQUEST_CANCELED' end,
          r.id, jsonb_build_object('status', r.status), jsonb_build_object('reason', p_reason));

  return jsonb_build_object('status', case when p_action = 'reject' then 'rejected' else 'canceled' end);
end;
$$;

-- Permissões: link público só lê e envia comprovante; o resto exige login.
revoke all on function public.payment_request_public_status(text, timestamptz) from public, anon;
grant execute on function public.payment_request_public_status(text, timestamptz) to authenticated, service_role;
revoke all on function public.create_payment_request(uuid, uuid, uuid, text, numeric, text, uuid[], int) from public, anon;
grant execute on function public.create_payment_request(uuid, uuid, uuid, text, numeric, text, uuid[], int) to authenticated, service_role;
revoke all on function public.get_payment_request_by_token(text) from public;
grant execute on function public.get_payment_request_by_token(text) to anon, authenticated, service_role;
-- Envio de comprovante só pelo servidor (service_role), que confere o arquivo antes.
revoke all on function public.begin_payment_proof_upload(text, boolean) from public, anon, authenticated;
grant execute on function public.begin_payment_proof_upload(text, boolean) to service_role;
revoke all on function public.submit_payment_proof(text, text, text, int, text) from public, anon, authenticated;
grant execute on function public.submit_payment_proof(text, text, text, int, text) to service_role;
revoke all on function public.confirm_payment_request(uuid, uuid, text) from public, anon;
grant execute on function public.confirm_payment_request(uuid, uuid, text) to authenticated, service_role;
revoke all on function public.close_payment_request(uuid, uuid, text, text) from public, anon;
grant execute on function public.close_payment_request(uuid, uuid, text, text) to authenticated, service_role;
