-- Fatura anexada à conta a pagar (PDF ou foto, até 4 MB no app).
-- Encoding: UTF-8
--
-- O editor de contas dizia "Anexar fatura · Em breve". Agora a conta guarda o caminho do arquivo
-- num bucket privado e o estúdio abre a fatura por link assinado e temporário.
--   * payables.invoice_path / invoice_name: anuláveis (aditivo; o app antigo ignora);
--   * o caminho começa pela pasta do próprio estúdio ({org_id}/{conta}/{arquivo}), conferido por CHECK,
--     então uma conta não aponta para o arquivo de outro estúdio;
--   * bucket 'payable-invoices' privado, 5 MB, PDF e imagens;
--   * quem lê é financeiro.view; quem grava e apaga é financeiro.manage (mesmas permissões das contas).
set client_encoding = 'UTF8';

alter table public.payables
  add column if not exists invoice_path text,
  add column if not exists invoice_name text;

comment on column public.payables.invoice_path is 'Caminho da fatura no bucket payable-invoices: {org_id}/{payable_id}/{arquivo}.';
comment on column public.payables.invoice_name is 'Nome do arquivo da fatura, como foi enviado (só para exibir).';

alter table public.payables drop constraint if exists payables_invoice_path_org_check;
alter table public.payables add constraint payables_invoice_path_org_check
  check (
    invoice_path is null
    or (invoice_path like org_id::text || '/%' and invoice_path not like '%..%' and length(invoice_path) <= 300)
  );

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'payable-invoices', 'payable-invoices', false, 5242880,
  array['application/pdf', 'image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']
)
on conflict (id) do nothing;

drop policy if exists payable_invoices_select on storage.objects;
drop policy if exists payable_invoices_insert on storage.objects;
drop policy if exists payable_invoices_delete on storage.objects;

create policy payable_invoices_select on storage.objects for select to authenticated
  using (
    bucket_id = 'payable-invoices'
    and (storage.foldername(name))[1] ~ '^[0-9a-fA-F-]{36}$'
    and public.has_permission(((storage.foldername(name))[1])::uuid, 'financeiro.view')
  );

create policy payable_invoices_insert on storage.objects for insert to authenticated
  with check (
    bucket_id = 'payable-invoices'
    and (storage.foldername(name))[1] ~ '^[0-9a-fA-F-]{36}$'
    and public.has_permission(((storage.foldername(name))[1])::uuid, 'financeiro.manage')
  );

create policy payable_invoices_delete on storage.objects for delete to authenticated
  using (
    bucket_id = 'payable-invoices'
    and (storage.foldername(name))[1] ~ '^[0-9a-fA-F-]{36}$'
    and public.has_permission(((storage.foldername(name))[1])::uuid, 'financeiro.manage')
  );
