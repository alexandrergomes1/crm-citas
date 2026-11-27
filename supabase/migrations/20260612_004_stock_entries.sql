-- Migration: stock_entries
-- 2026-06-12  Encoding: UTF-8

create table if not exists public.stock_entries (
  id          uuid        primary key default gen_random_uuid(),
  org_id      uuid        not null references public.organizations(id)  on delete cascade,
  product_id  uuid        not null references public.products(id)       on delete cascade,
  type        text        not null check (type in ('entrada', 'saida', 'ajuste')),
  quantity    integer     not null,
  reason      text,
  created_at  timestamptz not null default now(),
  created_by  uuid        references auth.users(id)
);

alter table public.stock_entries enable row level security;

drop policy if exists "stock_entries_select" on public.stock_entries;
drop policy if exists "stock_entries_insert" on public.stock_entries;

create policy "stock_entries_select" on public.stock_entries
  for select using (org_id in (select public.auth_org_ids()));

create policy "stock_entries_insert" on public.stock_entries
  for insert with check (
    org_id in (select public.auth_org_ids())
    and public.auth_user_role(org_id) in ('owner', 'admin', 'manager', 'receptionist')
  );

create index if not exists stock_entries_product_idx on public.stock_entries(product_id, created_at desc);
create index if not exists stock_entries_org_idx     on public.stock_entries(org_id, created_at desc);

grant select, insert on public.stock_entries to authenticated;
