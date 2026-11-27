-- Índices para as chaves estrangeiras compostas por estúdio (20261029210000).
-- Encoding: UTF-8
--
-- Sem índice que cubra (coluna, org_id), apagar ou mudar a linha-mãe (atendimento, venda,
-- profissional, cliente) obriga o banco a varrer a tabela-filha inteira para conferir a
-- chave. Apontado pelo assistente de desempenho do Supabase em 29 out.

create index if not exists appointments_staff_org_idx on public.appointments (staff_id, org_id);
create index if not exists appointment_items_appointment_org_idx on public.appointment_items (appointment_id, org_id);
create index if not exists appointment_deposits_appointment_org_idx on public.appointment_deposits (appointment_id, org_id);
create index if not exists anamnese_gate_overrides_appointment_org_idx on public.anamnese_gate_overrides (appointment_id, org_id);
create index if not exists sales_staff_org_idx on public.sales (staff_id, org_id);
create index if not exists sales_appointment_org_idx on public.sales (appointment_id, org_id);
create index if not exists sale_items_sale_org_idx on public.sale_items (sale_id, org_id);
create index if not exists sale_payments_sale_org_idx on public.sale_payments (sale_id, org_id);
create index if not exists transactions_sale_org_idx on public.transactions (sale_id, org_id);
create index if not exists transactions_org_client_idx on public.transactions (org_id, client_id);
