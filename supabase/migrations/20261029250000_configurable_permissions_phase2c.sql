-- Perfis e liberações configuráveis, fase 2c (spec 37): modelos de anamnese, pacotes da cliente
-- e contas a pagar. Encoding: UTF-8
--
-- - anamnese_templates: a lista fixa incluía a profissional, mas a matriz (spec 29) dá modelos só
--   a proprietária, administração e gestão. Agora anamnese.manage_templates (editável): a dona
--   liga para a profissional se quiser.
-- - client_entitlements: UPDATE aceitava QUALQUER membro (até "somente leitura" mexia nas sessões
--   usadas). Agora comanda.operate, igual ao INSERT (mesmos papéis de antes).
-- - payables: lista fixa owner/admin/manager/finance = financeiro.view (ler) e financeiro.manage
--   (escrever), os mesmos papéis por padrão.

drop policy if exists anamnese_tpl_write on public.anamnese_templates;
create policy anamnese_tpl_write on public.anamnese_templates for all to authenticated
  using (public.has_permission(org_id, 'anamnese.manage_templates'))
  with check (public.has_permission(org_id, 'anamnese.manage_templates'));

drop policy if exists entitlements_insert on public.client_entitlements;
create policy entitlements_insert on public.client_entitlements for insert to authenticated
  with check (public.has_permission(org_id, 'comanda.operate'));
drop policy if exists entitlements_update on public.client_entitlements;
create policy entitlements_update on public.client_entitlements for update to authenticated
  using (public.has_permission(org_id, 'comanda.operate'))
  with check (public.has_permission(org_id, 'comanda.operate'));

drop policy if exists payables_select on public.payables;
create policy payables_select on public.payables for select to authenticated
  using (public.has_permission(org_id, 'financeiro.view'));
drop policy if exists payables_write on public.payables;
create policy payables_write on public.payables for all to authenticated
  using (public.has_permission(org_id, 'financeiro.manage'))
  with check (public.has_permission(org_id, 'financeiro.manage'));
