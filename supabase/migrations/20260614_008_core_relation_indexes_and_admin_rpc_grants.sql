-- Core relation indexes used by agenda, checkout, client balance and anamnese.
create index if not exists idx_anamneses_client_id
  on public.anamneses (client_id);
create index if not exists idx_anamneses_template_id
  on public.anamneses (template_id);

create index if not exists idx_appointment_deposits_appointment_id
  on public.appointment_deposits (appointment_id);
create index if not exists idx_appointment_deposits_client_id
  on public.appointment_deposits (client_id);

create index if not exists idx_appointment_items_org_id
  on public.appointment_items (org_id);
create index if not exists idx_appointment_items_professional_id
  on public.appointment_items (professional_id);

create index if not exists idx_appointment_status_history_appointment_id
  on public.appointment_status_history (appointment_id);
create index if not exists idx_checkout_requests_appointment_id
  on public.checkout_requests (appointment_id);
create index if not exists idx_client_balance_entries_client_id
  on public.client_balance_entries (client_id);

-- This helper is administrative infrastructure and must not be exposed as an RPC.
revoke all on function public.rls_auto_enable() from public, anon, authenticated;
