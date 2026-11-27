-- Conexões de mensagem (WhatsApp por QR e, depois, API oficial) e registro de envios pelo provedor.
-- A chave do provedor fica no servidor (variável de ambiente); aqui só o estado da conexão.
-- Encoding: UTF-8

create table if not exists public.messaging_connections (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references public.organizations(id) on delete cascade,
  channel       text not null default 'whatsapp',
  provider      text not null,
  session_name  text not null,
  status        text not null default 'disconnected',
  phone         text,
  display_name  text,
  connected_at  timestamptz,
  status_at     timestamptz not null default now(),
  created_by    uuid references auth.users(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (org_id, channel),
  check (channel in ('whatsapp')),
  check (provider in ('waha_qr', 'meta_cloud')),
  check (status in ('disconnected', 'starting', 'awaiting_scan', 'connected', 'failed')),
  check (btrim(session_name) <> '')
);

create table if not exists public.messaging_provider_log (
  id                  uuid primary key default gen_random_uuid(),
  org_id              uuid not null references public.organizations(id) on delete cascade,
  connection_id       uuid references public.messaging_connections(id) on delete set null,
  client_id           uuid references public.clients(id) on delete set null,
  provider            text not null,
  purpose             text not null default 'manual',
  recipient           text not null,
  body                text not null,
  status              text not null default 'queued',
  provider_message_id text,
  error_message       text,
  created_by          uuid references auth.users(id) on delete set null,
  created_at          timestamptz not null default now(),
  check (provider in ('waha_qr', 'meta_cloud')),
  check (status in ('queued', 'sent', 'delivered', 'failed')),
  check (btrim(recipient) <> ''),
  check (btrim(body) <> '')
);

create index if not exists idx_messaging_log_org_created on public.messaging_provider_log(org_id, created_at desc);
create index if not exists idx_messaging_log_client on public.messaging_provider_log(client_id) where client_id is not null;

alter table public.messaging_connections enable row level security;
alter table public.messaging_provider_log enable row level security;
revoke all on public.messaging_connections from public, anon, authenticated;
revoke all on public.messaging_provider_log from public, anon, authenticated;
grant select, insert, update, delete on public.messaging_connections to authenticated;
grant select, insert on public.messaging_provider_log to authenticated;

drop policy if exists messaging_connections_select on public.messaging_connections;
create policy messaging_connections_select on public.messaging_connections for select to authenticated
  using (public.has_permission(org_id, 'mensagens.use'));
drop policy if exists messaging_connections_write on public.messaging_connections;
create policy messaging_connections_write on public.messaging_connections for all to authenticated
  using (public.has_permission(org_id, 'mensagens.configure'))
  with check (public.has_permission(org_id, 'mensagens.configure'));

drop policy if exists messaging_log_select on public.messaging_provider_log;
create policy messaging_log_select on public.messaging_provider_log for select to authenticated
  using (public.has_permission(org_id, 'mensagens.use'));
drop policy if exists messaging_log_insert on public.messaging_provider_log;
create policy messaging_log_insert on public.messaging_provider_log for insert to authenticated
  with check (public.has_permission(org_id, 'mensagens.use'));
