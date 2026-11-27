-- Financeiro: políticas de leitura (RLS) que conferem a permissão UMA vez por consulta, não uma vez por linha.
-- Antes: tx_select usava has_permission(org_id, 'financeiro.view') em cada lançamento; com 30 mil lançamentos a visão
-- geral de 2 anos levava ~5,8 s só nessa conferência (medido no banco local). Agora a política pergunta "em quais
-- estúdios a pessoa tem a permissão" (auth_orgs_with_permission, avaliada uma vez) e compara o org_id da linha.
-- Mesma regra de antes: has_permission (papel, perfil configurável e liberações do estúdio) de quem está logado,
-- só nos vínculos ativos. Políticas trocadas: transactions, payables, sales, gift_cards, cash_sessions,
-- cash_movements, sale_refunds, sale_partial_refunds (leitura) e a de gravação de payables (ALL, que também vale
-- para a leitura). As de gravação das outras tabelas continuam como estão (uma linha por vez).
-- Encoding: UTF-8
set client_encoding = 'UTF8';

-- Estúdios em que a pessoa logada tem a permissão. SECURITY DEFINER como has_permission/auth_org_ids (lê
-- user_roles): só devolve estúdios da própria pessoa (auth.uid()).
create or replace function public.auth_orgs_with_permission(p_permission text)
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select ur.org_id
  from public.user_roles ur
  where ur.user_id = (select auth.uid())
    and ur.active = true
    and public.has_permission(ur.org_id, p_permission);
$$;

-- Estúdios em que a pessoa logada tem um destes papéis (mesma regra de auth_user_role).
create or replace function public.auth_orgs_with_roles(p_roles text[])
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select ur.org_id
  from public.user_roles ur
  where ur.user_id = (select auth.uid())
    and ur.active = true
    and ur.role::text = any (p_roles);
$$;

revoke all on function public.auth_orgs_with_permission(text) from public, anon;
revoke all on function public.auth_orgs_with_roles(text[]) from public, anon;
grant execute on function public.auth_orgs_with_permission(text) to authenticated;
grant execute on function public.auth_orgs_with_roles(text[]) to authenticated;

drop policy if exists tx_select on public.transactions;
create policy tx_select on public.transactions for select to authenticated
  using (org_id in (select public.auth_orgs_with_permission('financeiro.view')));

drop policy if exists payables_select on public.payables;
create policy payables_select on public.payables for select to authenticated
  using (org_id in (select public.auth_orgs_with_permission('financeiro.view')));

drop policy if exists payables_write on public.payables;
create policy payables_write on public.payables for all to authenticated
  using (org_id in (select public.auth_orgs_with_permission('financeiro.manage')))
  with check (org_id in (select public.auth_orgs_with_permission('financeiro.manage')));

drop policy if exists sales_select on public.sales;
create policy sales_select on public.sales for select
  using (org_id in (select public.auth_orgs_with_roles(
    array['owner', 'admin', 'manager', 'finance', 'receptionist', 'professional'])));

drop policy if exists giftcards_select on public.gift_cards;
create policy giftcards_select on public.gift_cards for select to authenticated
  using (org_id in (select public.auth_orgs_with_permission('comanda.operate'))
         or org_id in (select public.auth_orgs_with_permission('financeiro.view')));

drop policy if exists cash_sessions_select on public.cash_sessions;
create policy cash_sessions_select on public.cash_sessions for select to authenticated
  using (org_id in (select public.auth_orgs_with_permission('financeiro.view'))
         or org_id in (select public.auth_orgs_with_permission('comanda.operate')));

drop policy if exists cash_movements_select on public.cash_movements;
create policy cash_movements_select on public.cash_movements for select to authenticated
  using (org_id in (select public.auth_orgs_with_permission('financeiro.view'))
         or org_id in (select public.auth_orgs_with_permission('comanda.operate')));

drop policy if exists sale_refunds_select on public.sale_refunds;
create policy sale_refunds_select on public.sale_refunds for select to authenticated
  using (org_id in (select public.auth_orgs_with_permission('financeiro.view'))
         or org_id in (select public.auth_orgs_with_permission('comanda.operate')));

drop policy if exists sale_partial_refunds_select on public.sale_partial_refunds;
create policy sale_partial_refunds_select on public.sale_partial_refunds for select to authenticated
  using (org_id in (select public.auth_orgs_with_permission('financeiro.view'))
         or org_id in (select public.auth_orgs_with_permission('comanda.operate')));
