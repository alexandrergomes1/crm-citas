-- ============================================================
-- KA Beauty OS — Anamnese (fichas + assinatura online LGPD/GDPR)
-- Encoding: UTF-8 — aplicar via MCP/conexão UTF-8
-- Idempotente onde possível.
-- ============================================================

-- ─── Templates de anamnese ───────────────────────────────────
create table if not exists anamnese_templates (
  id              uuid        primary key default gen_random_uuid(),
  org_id          uuid        not null references organizations on delete cascade,
  title           text        not null,
  description     text,
  questions       jsonb       not null default '[]'::jsonb, -- [{id,text,type,options?,required,explainWhenAnswer?,explanationLabel?}]
  consent_text    text        not null default 'Declaro que recebi as informações do procedimento, respondi a ficha com veracidade e autorizo o tratamento dos meus dados de saúde/estética conforme a LGPD/GDPR, para finalidade de atendimento, segurança e histórico clínico-estético.',
  consent_version text        not null default 'lgpd-v1',
  active          boolean     not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- ─── Fichas preenchidas ──────────────────────────────────────
create table if not exists anamneses (
  id                  uuid        primary key default gen_random_uuid(),
  org_id              uuid        not null references organizations on delete cascade,
  template_id         uuid        references anamnese_templates on delete set null,
  template_title      text        not null default 'Ficha de anamnese',
  template_snapshot   jsonb,      -- snapshot imutável de questions/consent no momento da geração
  client_id           uuid        references clients on delete set null,
  client_name         text        not null default '',
  appointment_id      uuid        references appointments on delete set null,
  status              text        not null default 'pending', -- pending | signed
  answers             jsonb       not null default '{}'::jsonb,
  professional_notes  text,
  public_token        text        unique not null,
  token_expires_at    timestamptz,
  consent_text        text        not null default '',
  consent_version     text        not null default 'lgpd-v1',
  consent_accepted    boolean     not null default false,
  signature_name      text,
  signature_data_url  text,
  signed_at           timestamptz,
  signer_ip           text,
  signer_user_agent   text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create index if not exists idx_anamnese_templates_org on anamnese_templates (org_id, active);
create index if not exists idx_anamneses_org_status    on anamneses (org_id, status, created_at desc);
create index if not exists idx_anamneses_client        on anamneses (org_id, client_id);
create index if not exists idx_anamneses_appointment   on anamneses (appointment_id);
create unique index if not exists idx_anamneses_token  on anamneses (public_token);

-- ─── RLS (workspace) ─────────────────────────────────────────
alter table anamnese_templates enable row level security;
alter table anamneses          enable row level security;

drop policy if exists "anamnese_tpl_select" on anamnese_templates;
drop policy if exists "anamnese_tpl_write"  on anamnese_templates;
create policy "anamnese_tpl_select" on anamnese_templates for select using (org_id in (select auth_org_ids()));
create policy "anamnese_tpl_write"  on anamnese_templates for all    using (org_id in (select auth_org_ids()) and auth_user_role(org_id) in ('owner','admin','manager','professional'));

drop policy if exists "anamneses_select" on anamneses;
drop policy if exists "anamneses_write"  on anamneses;
create policy "anamneses_select" on anamneses for select using (org_id in (select auth_org_ids()));
create policy "anamneses_write"  on anamneses for all    using (org_id in (select auth_org_ids()) and auth_user_role(org_id) in ('owner','admin','manager','receptionist','professional'));

-- ─── Acesso público por token (SECURITY DEFINER) ─────────────
-- O portal público (/forms/[token]) não tem sessão. Estas funções
-- operam SOMENTE na linha cujo token confere — não expõem outras.

create or replace function get_anamnese_by_token(p_token text)
returns jsonb
language sql security definer set search_path = public stable as $$
  select jsonb_build_object(
    'id',                 a.id,
    'status',             a.status,
    'client_name',        a.client_name,
    'org_name',           o.name,
    'template_title',     a.template_title,
    'questions',          coalesce(a.template_snapshot->'questions', '[]'::jsonb),
    'answers',            a.answers,
    'consent_text',       a.consent_text,
    'consent_version',    a.consent_version,
    'signature_name',     a.signature_name,
    'signature_data_url', a.signature_data_url,
    'signed_at',          a.signed_at,
    'expired',            (a.token_expires_at is not null and a.token_expires_at < now())
  )
  from anamneses a
  join organizations o on o.id = a.org_id
  where a.public_token = p_token;
$$;

create or replace function submit_anamnese_signature(
  p_token              text,
  p_answers            jsonb,
  p_signature_name     text,
  p_signature_data_url text,
  p_consent_accepted   boolean,
  p_user_agent         text
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v anamneses;
begin
  select * into v from anamneses where public_token = p_token;
  if not found then return jsonb_build_object('error','not_found'); end if;
  if v.status = 'signed' then return jsonb_build_object('error','already_signed'); end if;
  if v.token_expires_at is not null and v.token_expires_at < now() then
    return jsonb_build_object('error','expired');
  end if;
  if coalesce(p_consent_accepted,false) = false then
    return jsonb_build_object('error','consent_required');
  end if;
  if p_signature_data_url is null or length(p_signature_data_url) < 50 then
    return jsonb_build_object('error','signature_required');
  end if;

  update anamneses set
    answers            = coalesce(p_answers, '{}'::jsonb),
    signature_name     = p_signature_name,
    signature_data_url = p_signature_data_url,
    consent_accepted   = true,
    signer_user_agent  = p_user_agent,
    status             = 'signed',
    signed_at          = now(),
    updated_at         = now()
  where id = v.id;

  return jsonb_build_object('ok', true, 'signed_at', now());
end; $$;

revoke all on function get_anamnese_by_token(text) from public;
revoke all on function submit_anamnese_signature(text,jsonb,text,text,boolean,text) from public;
grant execute on function get_anamnese_by_token(text) to anon, authenticated;
grant execute on function submit_anamnese_signature(text,jsonb,text,text,boolean,text) to anon, authenticated;

-- ─── Triggers updated_at ─────────────────────────────────────
create or replace trigger trg_anamnese_tpl_updated_at before update on anamnese_templates for each row execute function update_updated_at();
create or replace trigger trg_anamneses_updated_at     before update on anamneses          for each row execute function update_updated_at();
