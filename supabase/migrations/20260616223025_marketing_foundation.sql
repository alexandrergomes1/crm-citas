-- MKT-01A: marketing foundation without external providers.
-- Encoding: UTF-8

create table if not exists public.marketing_segments (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references public.organizations(id) on delete cascade,
  name        text not null,
  description text,
  filters     jsonb not null default '{}',
  unsupported_filters jsonb not null default '[]',
  active      boolean not null default true,
  archived_at timestamptz,
  created_by  uuid references auth.users(id) on delete set null,
  updated_by  uuid references auth.users(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  check (jsonb_typeof(filters) = 'object'),
  check (jsonb_typeof(unsupported_filters) = 'array')
);

create table if not exists public.marketing_message_templates (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references public.organizations(id) on delete cascade,
  name        text not null,
  channel     text not null,
  purpose     text not null,
  language    text not null default 'es',
  subject     text,
  body        text not null,
  active      boolean not null default true,
  archived_at timestamptz,
  version     integer not null default 1,
  created_by  uuid references auth.users(id) on delete set null,
  updated_by  uuid references auth.users(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  check (channel in ('whatsapp_manual', 'whatsapp_provider', 'sms_provider', 'email_provider', 'internal_note')),
  check (purpose in ('birthday', 'inactive_recovery', 'aftercare', 'review_request', 'promotion', 'announcement', 'manual')),
  check (language in ('es', 'pt', 'en', 'auto')),
  check (btrim(name) <> ''),
  check (btrim(body) <> '')
);

create table if not exists public.marketing_campaigns (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references public.organizations(id) on delete cascade,
  name        text not null,
  description text,
  status      text not null default 'draft',
  planned_channel text not null,
  purpose     text not null default 'manual',
  segment_id  uuid references public.marketing_segments(id) on delete set null,
  template_id uuid references public.marketing_message_templates(id) on delete set null,
  audience_filter jsonb not null default '{}',
  audience_snapshot jsonb not null default '{}',
  estimated_audience_count integer not null default 0,
  scheduled_for timestamptz,
  archived_at timestamptz,
  created_by  uuid references auth.users(id) on delete set null,
  updated_by  uuid references auth.users(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  check (status in ('draft', 'ready', 'paused', 'sent', 'archived')),
  check (planned_channel in ('whatsapp_manual', 'whatsapp_provider', 'sms_provider', 'email_provider', 'internal_note')),
  check (purpose in ('birthday', 'inactive_recovery', 'aftercare', 'review_request', 'promotion', 'announcement', 'manual')),
  check (estimated_audience_count >= 0),
  check (jsonb_typeof(audience_filter) = 'object'),
  check (jsonb_typeof(audience_snapshot) = 'object'),
  check (btrim(name) <> '')
);

create table if not exists public.client_marketing_preferences (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references public.organizations(id) on delete cascade,
  client_id   uuid not null references public.clients(id) on delete cascade,
  channel     text not null,
  operational_allowed boolean not null default true,
  marketing_allowed boolean not null default false,
  opted_out_at timestamptz,
  opt_out_reason text,
  language text not null default 'es',
  source text not null default 'internal',
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (org_id, client_id, channel),
  check (channel in ('whatsapp_manual', 'whatsapp_provider', 'sms_provider', 'email_provider', 'internal_note')),
  check (language in ('es', 'pt', 'en', 'auto')),
  check (opted_out_at is null or marketing_allowed = false)
);

create table if not exists public.marketing_message_queue (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references public.organizations(id) on delete cascade,
  campaign_id uuid references public.marketing_campaigns(id) on delete cascade,
  template_id uuid references public.marketing_message_templates(id) on delete set null,
  segment_id  uuid references public.marketing_segments(id) on delete set null,
  client_id   uuid not null references public.clients(id) on delete cascade,
  channel     text not null,
  recipient   text not null,
  message_subject text,
  message_body text not null,
  status      text not null default 'draft',
  scheduled_for timestamptz,
  idempotency_key text,
  provider text,
  provider_message_id text,
  metadata jsonb not null default '{}',
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (org_id, idempotency_key),
  check (channel in ('whatsapp_manual', 'whatsapp_provider', 'sms_provider', 'email_provider', 'internal_note')),
  check (status in ('draft', 'manual_ready', 'cancelled', 'skipped')),
  check (btrim(recipient) <> ''),
  check (btrim(message_body) <> ''),
  check (jsonb_typeof(metadata) = 'object'),
  check (provider is null and provider_message_id is null)
);

create table if not exists public.marketing_message_events (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references public.organizations(id) on delete cascade,
  queue_id    uuid references public.marketing_message_queue(id) on delete cascade,
  campaign_id uuid references public.marketing_campaigns(id) on delete cascade,
  client_id   uuid references public.clients(id) on delete set null,
  channel     text not null,
  event_type  text not null,
  status      text not null,
  provider    text,
  provider_message_id text,
  error_message text,
  metadata jsonb not null default '{}',
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  check (channel in ('whatsapp_manual', 'whatsapp_provider', 'sms_provider', 'email_provider', 'internal_note')),
  check (event_type in ('draft_created', 'manual_ready', 'manual_link_opened', 'cancelled', 'skipped', 'provider_event')),
  check (status in ('draft', 'manual_ready', 'cancelled', 'skipped', 'opened_manual_link', 'provider_pending', 'provider_sent', 'provider_delivered', 'provider_failed')),
  check (jsonb_typeof(metadata) = 'object')
);

create index if not exists idx_marketing_segments_org_active
  on public.marketing_segments(org_id, active, created_at desc);
create index if not exists idx_marketing_templates_org_channel
  on public.marketing_message_templates(org_id, channel, active);
create index if not exists idx_marketing_campaigns_org_status
  on public.marketing_campaigns(org_id, status, created_at desc);
create index if not exists idx_client_marketing_preferences_client
  on public.client_marketing_preferences(org_id, client_id);
create index if not exists idx_marketing_queue_org_status
  on public.marketing_message_queue(org_id, status, created_at desc);
create index if not exists idx_marketing_queue_campaign
  on public.marketing_message_queue(org_id, campaign_id);
create index if not exists idx_marketing_events_queue
  on public.marketing_message_events(org_id, queue_id, created_at desc);

alter table public.marketing_segments enable row level security;
alter table public.marketing_message_templates enable row level security;
alter table public.marketing_campaigns enable row level security;
alter table public.client_marketing_preferences enable row level security;
alter table public.marketing_message_queue enable row level security;
alter table public.marketing_message_events enable row level security;

drop policy if exists "marketing_segments_select" on public.marketing_segments;
drop policy if exists "marketing_segments_manage" on public.marketing_segments;
create policy "marketing_segments_select"
  on public.marketing_segments for select
  using (org_id in (select public.auth_org_ids()));
create policy "marketing_segments_manage"
  on public.marketing_segments for all
  using (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'))
  with check (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));

drop policy if exists "marketing_templates_select" on public.marketing_message_templates;
drop policy if exists "marketing_templates_manage" on public.marketing_message_templates;
create policy "marketing_templates_select"
  on public.marketing_message_templates for select
  using (org_id in (select public.auth_org_ids()));
create policy "marketing_templates_manage"
  on public.marketing_message_templates for all
  using (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'))
  with check (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));

drop policy if exists "marketing_campaigns_select" on public.marketing_campaigns;
drop policy if exists "marketing_campaigns_manage" on public.marketing_campaigns;
create policy "marketing_campaigns_select"
  on public.marketing_campaigns for select
  using (org_id in (select public.auth_org_ids()));
create policy "marketing_campaigns_manage"
  on public.marketing_campaigns for all
  using (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'))
  with check (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));

drop policy if exists "client_marketing_preferences_select" on public.client_marketing_preferences;
drop policy if exists "client_marketing_preferences_manage" on public.client_marketing_preferences;
create policy "client_marketing_preferences_select"
  on public.client_marketing_preferences for select
  using (org_id in (select public.auth_org_ids()));
create policy "client_marketing_preferences_manage"
  on public.client_marketing_preferences for all
  using (public.auth_user_role(org_id) in ('owner', 'admin', 'manager', 'receptionist'))
  with check (public.auth_user_role(org_id) in ('owner', 'admin', 'manager', 'receptionist'));

drop policy if exists "marketing_queue_select" on public.marketing_message_queue;
drop policy if exists "marketing_queue_manage" on public.marketing_message_queue;
create policy "marketing_queue_select"
  on public.marketing_message_queue for select
  using (org_id in (select public.auth_org_ids()));
create policy "marketing_queue_manage"
  on public.marketing_message_queue for all
  using (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'))
  with check (public.auth_user_role(org_id) in ('owner', 'admin', 'manager'));

drop policy if exists "marketing_events_select" on public.marketing_message_events;
drop policy if exists "marketing_events_insert" on public.marketing_message_events;
create policy "marketing_events_select"
  on public.marketing_message_events for select
  using (org_id in (select public.auth_org_ids()));
create policy "marketing_events_insert"
  on public.marketing_message_events for insert
  with check (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in ('owner', 'admin', 'manager')
  );

create or replace trigger trg_marketing_segments_updated_at
  before update on public.marketing_segments
  for each row execute function public.update_updated_at();
create or replace trigger trg_marketing_templates_updated_at
  before update on public.marketing_message_templates
  for each row execute function public.update_updated_at();
create or replace trigger trg_marketing_campaigns_updated_at
  before update on public.marketing_campaigns
  for each row execute function public.update_updated_at();
create or replace trigger trg_client_marketing_preferences_updated_at
  before update on public.client_marketing_preferences
  for each row execute function public.update_updated_at();
create or replace trigger trg_marketing_queue_updated_at
  before update on public.marketing_message_queue
  for each row execute function public.update_updated_at();

grant select, insert, update on public.marketing_segments to authenticated;
grant select, insert, update on public.marketing_message_templates to authenticated;
grant select, insert, update on public.marketing_campaigns to authenticated;
grant select, insert, update on public.client_marketing_preferences to authenticated;
grant select, insert, update on public.marketing_message_queue to authenticated;
grant select, insert on public.marketing_message_events to authenticated;
