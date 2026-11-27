-- ============================================================
-- KA Beauty OS · Preferências da pessoa por estúdio (spec 31)
-- Encoding: UTF-8
-- Tela inicial, visão da agenda e atalhos do celular, separados por aparelho.
-- Cada pessoa só lê e grava as próprias preferências.
-- ============================================================
set client_encoding = 'UTF8';

create table if not exists public.user_preferences (
  user_id    uuid not null references auth.users(id) on delete cascade,
  org_id     uuid not null references public.organizations(id) on delete cascade,
  prefs      jsonb not null default '{}'::jsonb check (jsonb_typeof(prefs) = 'object' and pg_column_size(prefs) < 8192),
  updated_at timestamptz not null default now(),
  primary key (user_id, org_id)
);
create index if not exists idx_user_preferences_org on public.user_preferences (org_id);
comment on table public.user_preferences is 'Preferências de interface por pessoa e estúdio. prefs: {"mobile": {...}, "desktop": {...}}.';

alter table public.user_preferences enable row level security;

drop policy if exists user_preferences_own on public.user_preferences;
create policy user_preferences_own on public.user_preferences for all to authenticated
  using (user_id = (select auth.uid()) and org_id in (select public.auth_org_ids()))
  with check (user_id = (select auth.uid()) and org_id in (select public.auth_org_ids()));

revoke all on public.user_preferences from anon;
revoke truncate, trigger, references on public.user_preferences from authenticated;
