-- KA Beauty OS - Index client balance reversal foreign keys
-- Encoding: UTF-8

create index if not exists idx_client_balance_entries_reversal_of_entry_fk
  on public.client_balance_entries (reversal_of_entry_id)
  where reversal_of_entry_id is not null;

create index if not exists idx_client_balance_entries_reversed_by_entry_fk
  on public.client_balance_entries (reversed_by_entry_id)
  where reversed_by_entry_id is not null;

create index if not exists idx_client_balance_entries_reversed_by_fk
  on public.client_balance_entries (reversed_by)
  where reversed_by is not null;
