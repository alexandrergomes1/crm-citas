-- Páginas públicas (porte de /forms, modo estúdio e /pagar), parte 1: limite de tentativas e token da ficha como hash.
-- Encoding: UTF-8
set client_encoding = 'UTF8';
--
-- 1. public_link_hits: contador por janela (IP, token, e-mail), só tocado por funções do banco. Guarda só o hash
--    (sha256) do IP ou do e-mail, calculado no servidor; janelas de mais de 1 dia são apagadas aos poucos.
-- 2. anamneses.token_hash: o link continua com o token em claro, o banco guarda só o sha256. public_token passa a
--    ficar sempre vazio (CHECK). Quem ainda grava public_token (testes antigos, app antigo) tem o valor trocado pelo
--    hash antes de gravar (gatilho), então o token em claro nunca fica no banco.
-- 3. create_anamnese_atomic devolve o token só na criação (no registro devolvido, nunca na tabela).
--    anamnese_create_link: ficha pendente que já existia ganha link NOVO (o anterior deixa de valer).
--    anamnese_issue_link: "Reenviar"/"Renovar" gera link novo (com ou sem nova validade). Sem hash não há como
--    mostrar o link antigo de novo.
-- Auditoria do link novo: gatilho anamneses_audit (20261114100100).

-- ─── 1. Limite de tentativas ─────────────────────────────────────────────────────────────────────
create table if not exists public.public_link_hits (
  bucket       text        not null check (bucket in (
                 'form_ip', 'form_miss_ip', 'form_token', 'sign_token',
                 'pay_ip', 'pay_miss_ip', 'pay_token', 'pay_proof_token', 'reset_ip', 'reset_email')),
  key_hash     text        not null check (key_hash ~ '^[0-9a-f]{64}$'),
  window_start timestamptz not null,
  hits         integer     not null default 0 check (hits >= 0),
  primary key (bucket, key_hash, window_start)
);
comment on table public.public_link_hits is
  'Contador de tentativas das páginas públicas (sem org_id: o IP ou o token ainda não tem estúdio). Só hash (sha256), '
  'nunca IP, token ou e-mail em claro; janelas de mais de 1 dia são apagadas. Sem acesso pela API.';
alter table public.public_link_hits enable row level security;
revoke all on table public.public_link_hits from public, anon, authenticated, service_role;
create index if not exists idx_public_link_hits_window on public.public_link_hits (window_start);

-- Conta (p_count) e diz se ainda está dentro do limite. Chave fora do formato (sha256 em hex) é erro: o servidor sempre
-- manda o hash (sem IP, o de uma chave fixa "sem-ip"). Só para outras funções do banco (sem execução para ninguém).
create or replace function public.public_link_throttle_internal(
  p_bucket text, p_key text, p_limit integer, p_window_seconds integer, p_count boolean default true
)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_key text := p_key;
  v_start timestamptz := pg_catalog.to_timestamp(
    pg_catalog.floor(extract(epoch from pg_catalog.now()) / p_window_seconds) * p_window_seconds);
  v_hits integer;
begin
  if p_key is null or p_key !~ '^[0-9a-f]{64}$' then
    raise exception 'Chave do limite fora do formato' using errcode = '22023';
  end if;
  if p_count then
    insert into public.public_link_hits as h (bucket, key_hash, window_start, hits)
    values (p_bucket, v_key, v_start, 1)
    on conflict (bucket, key_hash, window_start) do update set hits = h.hits + 1
    returning h.hits into v_hits;
    -- Faxina aos poucos: janelas de mais de 1 dia.
    if pg_catalog.random() < 0.02 then
      delete from public.public_link_hits
      where ctid in (select ctid from public.public_link_hits
                     where window_start < pg_catalog.now() - interval '1 day' limit 500);
    end if;
  else
    select h.hits into v_hits from public.public_link_hits h
    where h.bucket = p_bucket and h.key_hash = v_key and h.window_start = v_start;
  end if;
  return coalesce(v_hits, 0) <= p_limit;
end;
$$;
revoke all on function public.public_link_throttle_internal(text, text, integer, integer, boolean) from public, anon, authenticated, service_role;

-- sha256 em hex (o mesmo cálculo do servidor e dos links).
create or replace function public.public_token_hash_internal(p_token text)
returns text
language sql
immutable
set search_path = ''
as $$
  select pg_catalog.encode(extensions.digest(p_token, 'sha256'), 'hex');
$$;
revoke all on function public.public_token_hash_internal(text) from public, anon, authenticated, service_role;

-- Token novo: 128 bits aleatórios em hex (32 caracteres), como sempre foi.
create or replace function public.public_token_new_internal()
returns text
language sql
volatile
set search_path = ''
as $$
  select pg_catalog.encode(extensions.gen_random_bytes(16), 'hex');
$$;
revoke all on function public.public_token_new_internal() from public, anon, authenticated, service_role;

-- ─── 2. Ficha: token só como hash ───────────────────────────────────────────────────────────────
alter table public.anamneses add column if not exists token_hash text;
alter table public.anamneses alter column public_token drop not null;

-- Migração dos links existentes: o link já enviado continua valendo (mesmo token, agora pelo hash).
-- A trava de evidência da ficha assinada fica desligada só durante esta troca (nada da evidência muda).
alter table public.anamneses disable trigger trg_protect_signed_anamnese_evidence;
alter table public.anamneses disable trigger trg_anamneses_updated_at;
update public.anamneses
   set token_hash = public.public_token_hash_internal(public_token), public_token = null
 where public_token is not null;
alter table public.anamneses enable trigger trg_anamneses_updated_at;
alter table public.anamneses enable trigger trg_protect_signed_anamnese_evidence;

-- Quem grava public_token (testes e app antigos) tem o valor trocado pelo hash antes de gravar.
create or replace function public.anamneses_hash_public_token()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.public_token is not null then
    new.token_hash := pg_catalog.encode(extensions.digest(new.public_token, 'sha256'), 'hex');
    new.public_token := null;
  end if;
  return new;
end;
$$;
revoke all on function public.anamneses_hash_public_token() from public, anon, authenticated, service_role;
drop trigger if exists trg_anamneses_hash_public_token on public.anamneses;
-- Nome começa com "trg_anamneses_h": roda antes da trava de evidência (ordem alfabética dos gatilhos BEFORE).
create trigger trg_anamneses_hash_public_token
  before insert or update of public_token on public.anamneses
  for each row execute function public.anamneses_hash_public_token();

alter table public.anamneses
  add constraint anamneses_public_token_never_stored check (public_token is null) not valid,
  add constraint anamneses_token_hash_format check (token_hash is null or token_hash ~ '^[0-9a-f]{64}$') not valid;
alter table public.anamneses validate constraint anamneses_public_token_never_stored;
alter table public.anamneses validate constraint anamneses_token_hash_format;
create unique index if not exists idx_anamneses_token_hash on public.anamneses (token_hash) where token_hash is not null;
drop index if exists public.idx_anamneses_token;

-- ─── 3. Criar a ficha: token devolvido só na criação ────────────────────────────────────────────
-- Igual à versão vigente (20261114040500) com o token gravado como hash; o token em claro vai só no registro
-- devolvido (v_result.public_token), nunca na tabela. Ficha que já existia volta sem token.
CREATE OR REPLACE FUNCTION public.create_anamnese_atomic(p_org_id uuid, p_template_id uuid, p_client_id uuid, p_client_name text, p_appointment_id uuid DEFAULT NULL::uuid, p_requires_professional boolean DEFAULT NULL::boolean)
 RETURNS anamneses
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_role text;
  v_clinical boolean;
  v_template public.anamnese_templates;
  v_appointment public.appointments;
  v_client public.clients;
  v_result public.anamneses;
  v_client_id uuid := p_client_id;
  v_client_name text := nullif(pg_catalog.btrim(p_client_name), '');
  v_token text;
begin
  v_role := public.auth_user_role(p_org_id);
  if v_role is null or not public.has_permission(p_org_id, 'anamnese.view_status') then
    raise exception 'Sem permissao para gerar fichas de anamnese'
      using errcode = '42501';
  end if;
  v_clinical := public.has_permission(p_org_id, 'clientes.view_clinical');

  select * into v_template
  from public.anamnese_templates t
  where t.id = p_template_id
    and t.org_id = p_org_id
    and t.active = true;

  if not found then
    raise exception 'Modelo de anamnese ativo nao encontrado'
      using errcode = 'P0002';
  end if;

  if p_appointment_id is not null then
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(
        p_org_id::text || ':' || p_appointment_id::text || ':' || p_template_id::text,
        0
      )
    );

    select * into v_appointment
    from public.appointments a
    where a.id = p_appointment_id
      and a.org_id = p_org_id
    for update;

    if not found or not public.anamnese_row_in_scope(p_org_id, p_appointment_id, null) then
      raise exception 'Agendamento não encontrado'
        using errcode = 'P0002';
    end if;

    v_client_id := v_appointment.client_id;
    v_client_name := v_appointment.client_name;

    select * into v_result
    from public.anamneses an
    where an.org_id = p_org_id
      and an.appointment_id = p_appointment_id
      and an.template_id = p_template_id;

    if found then
      if not v_clinical then
        v_result.answers := '{}'::jsonb;
        v_result.professional_notes := null;
        v_result.professional_data := null;
        v_result.signature_name := null;
        v_result.signature_data_url := null;
        v_result.signer_ip := null;
        v_result.signer_user_agent := null;
      end if;
      v_result.token_hash := null;
      return v_result;
    end if;
  elsif v_client_id is not null then
    select * into v_client
    from public.clients c
    where c.id = v_client_id
      and c.org_id = p_org_id;

    if not found then
      raise exception 'Cliente nao encontrado nesta organizacao'
        using errcode = 'P0002';
    end if;
    v_client_name := v_client.full_name;
  end if;

  if v_client_name is null then
    raise exception 'Informe o cliente'
      using errcode = '22023';
  end if;

  v_token := public.public_token_new_internal();
  insert into public.anamneses (
    org_id, template_id, template_title, template_snapshot, client_id, client_name, appointment_id, status,
    requires_professional, source_service_id, token_hash, token_expires_at, consent_text, consent_version
  )
  values (
    p_org_id,
    v_template.id,
    v_template.title,
    pg_catalog.jsonb_build_object(
      'questions', v_template.questions,
      'consent_text', v_template.consent_text,
      'professional_form', v_template.professional_form
    ),
    v_client_id,
    v_client_name,
    p_appointment_id,
    'pending',
    coalesce(p_requires_professional, v_template.professional_form is not null),
    null,
    public.public_token_hash_internal(v_token),
    pg_catalog.now() + interval '7 days',
    v_template.consent_text,
    v_template.consent_version
  )
  returning * into v_result;

  if p_appointment_id is not null then
    update public.appointments
    set linked_anamnese_id = coalesce(linked_anamnese_id, v_result.id)
    where id = p_appointment_id
      and org_id = p_org_id;
  end if;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
  values (p_org_id, auth.uid(), 'anamneses', 'ANAMNESE_CREATED', v_result.id,
    pg_catalog.jsonb_build_object('appointment_id', p_appointment_id, 'template_id', p_template_id, 'client_id', v_client_id));

  if not v_clinical then
    v_result.answers := '{}'::jsonb;
    v_result.professional_notes := null;
    v_result.professional_data := null;
    v_result.signature_name := null;
    v_result.signature_data_url := null;
    v_result.signer_ip := null;
    v_result.signer_user_agent := null;
  end if;
  -- O token em claro sai só aqui, uma vez; a tabela guarda só o hash.
  v_result.token_hash := null;
  v_result.public_token := v_token;
  return v_result;
end;
$function$;

-- Link novo para ficha pendente (o anterior deixa de valer). Só para outras funções do banco, que já conferiram
-- permissão e alcance. Devolve o token em claro (uma vez).
create or replace function public.anamnese_rotate_token_internal(p_org_id uuid, p_anamnese_id uuid)
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_token text := public.public_token_new_internal();
begin
  update public.anamneses set token_hash = public.public_token_hash_internal(v_token)
  where org_id = p_org_id and id = p_anamnese_id and status = 'pending';
  if not found then
    raise exception 'Ficha pendente não encontrada' using errcode = 'P0002';
  end if;
  return v_token;
end;
$$;
revoke all on function public.anamnese_rotate_token_internal(uuid, uuid) from public, anon, authenticated, service_role;

-- "Reenviar link" / "Renovar link": validade nova (opcional) e link novo, numa ida ao banco. Ficha vencida exige
-- validade nova. Permissão, alcance e "só pendente" conferidos aqui e em set_anamnese_link_validity.
create or replace function public.anamnese_issue_link(p_org_id uuid, p_anamnese_id uuid, p_days integer)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_status text;
  v_expires timestamptz;
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'anamnese.view_status') then
    raise exception 'Sem permissão para enviar fichas de anamnese' using errcode = '42501';
  end if;
  if not public.anamnese_in_scope(p_org_id, p_anamnese_id) then
    raise exception 'Ficha não encontrada' using errcode = 'P0002';
  end if;
  select a.status, a.token_expires_at into v_status, v_expires
  from public.anamneses a where a.org_id = p_org_id and a.id = p_anamnese_id for update;
  if not found then
    raise exception 'Ficha não encontrada' using errcode = 'P0002';
  end if;
  if v_status <> 'pending' then
    raise exception 'Ficha já assinada' using errcode = 'P0001';
  end if;
  if p_days is not null then
    v_expires := public.set_anamnese_link_validity(p_org_id, p_anamnese_id, p_days);
  elsif v_expires is null or v_expires < pg_catalog.now() then
    raise exception 'O link venceu: escolha a nova validade' using errcode = 'P0001';
  end if;
  return pg_catalog.jsonb_build_object(
    'token', public.anamnese_rotate_token_internal(p_org_id, p_anamnese_id),
    'expires_at', v_expires);
end;
$$;
revoke all on function public.anamnese_issue_link(uuid, uuid, integer) from public, anon;
grant execute on function public.anamnese_issue_link(uuid, uuid, integer) to authenticated;

-- Recriada (20261114040400): ficha nova devolve o token da criação; ficha pendente que já existia (mesmo
-- agendamento e modelo) ganha link novo, porque o anterior não pode ser mostrado de novo.
create or replace function public.anamnese_create_link(
  p_org_id uuid,
  p_template_id uuid,
  p_client_id uuid,
  p_client_name text,
  p_appointment_id uuid,
  p_requires_professional boolean,
  p_link_days integer,
  p_send_channel text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_ficha public.anamneses;
  v_expires timestamptz;
  v_token text;
begin
  if pg_catalog.char_length(coalesce(p_client_name, '')) > 200 then
    raise exception 'Nome grande demais' using errcode = '22023';
  end if;
  v_ficha := public.create_anamnese_atomic(p_org_id, p_template_id, p_client_id, p_client_name, p_appointment_id, p_requires_professional);
  v_expires := v_ficha.token_expires_at;
  v_token := v_ficha.public_token;
  if v_ficha.status = 'pending' then
    if p_link_days is not null then
      v_expires := public.set_anamnese_link_validity(p_org_id, v_ficha.id, p_link_days);
    end if;
    if v_token is null and v_expires >= pg_catalog.now() then
      v_token := (public.anamnese_issue_link(p_org_id, v_ficha.id, null)) ->> 'token';
    end if;
    if p_send_channel is not null then
      perform public.log_anamnese_send(p_org_id, v_ficha.id, p_send_channel);
    end if;
  end if;
  return pg_catalog.jsonb_build_object(
    'id', v_ficha.id,
    'token', case when v_ficha.status = 'pending' and v_expires >= pg_catalog.now() then v_token end,
    'expires_at', v_expires);
end;
$$;
