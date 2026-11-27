-- Remove políticas FOR ALL antigas que furavam as liberações por perfil (revisão de segurança 29 out).
-- Encoding: UTF-8
--
-- Políticas permissivas somam (OR). As FOR ALL de 2026-06 valiam também para SELECT e para
-- escrita direta pela API, por cima das regras novas:
--   transactions  tx_write: recepção e profissional liam o caixa inteiro (furava financeiro.view)
--                 e podiam inserir, editar e apagar lançamentos.
--   sales, sale_items, sale_payments *_write: recepção e profissional reescreviam vendas e
--                 pagamentos sem passar pelo fechamento de comanda (confirm_checkout_atomic).
--   gift_cards    giftcards_write: escrita direta; e a leitura era aberta a todo membro.
--   clients       "clients: criar e editar": profissional editava e APAGAVA clientes (o apagar
--                 leva junto histórico de saldo e fidelidade).
-- Todas as escritas legítimas de vendas e caixa passam por funções SECURITY DEFINER, que não
-- dependem destas políticas.

-- 1. Caixa: só lançamento manual de quem gerencia o financeiro; nada de editar ou apagar.
drop policy if exists tx_write on public.transactions;
create policy tx_insert on public.transactions for insert to authenticated
  with check (public.has_permission(org_id, 'financeiro.manage'));

-- 2. Vendas: escrita só pelas funções do checkout.
drop policy if exists sales_write on public.sales;
drop policy if exists sale_items_write on public.sale_items;
drop policy if exists sale_payments_write on public.sale_payments;

-- 3. Vale-presente: quem opera o caixa vende e baixa; leitura para caixa e financeiro.
drop policy if exists giftcards_write on public.gift_cards;
drop policy if exists giftcards_select on public.gift_cards;
create policy giftcards_select on public.gift_cards for select to authenticated
  using (public.has_permission(org_id, 'comanda.operate') or public.has_permission(org_id, 'financeiro.view'));
create policy giftcards_insert on public.gift_cards for insert to authenticated
  with check (public.has_permission(org_id, 'comanda.operate'));
create policy giftcards_update on public.gift_cards for update to authenticated
  using (public.has_permission(org_id, 'comanda.operate'))
  with check (public.has_permission(org_id, 'comanda.operate'));

-- 4. Clientes: cadastrar e editar com clientes.manage; apagar de vez não existe pela API
--    (exclusão por LGPD/GDPR será uma função própria, com retenção legal).
drop policy if exists "clients: criar e editar" on public.clients;
create policy "clients: criar" on public.clients for insert to authenticated
  with check (public.has_permission(org_id, 'clientes.manage'));
create policy "clients: editar" on public.clients for update to authenticated
  using (public.has_permission(org_id, 'clientes.manage'))
  with check (public.has_permission(org_id, 'clientes.manage'));
-- As RPCs da agenda leem a cliente com FOR SHARE, que no RLS exige passar no USING de UPDATE.
-- Quem só tem agenda.manage (sem clientes.manage) precisa travar a linha, nunca alterá-la:
-- WITH CHECK (false) recusa qualquer gravação vinda só desta política.
create policy "clients: travar na agenda" on public.clients for update to authenticated
  using (public.has_permission(org_id, 'agenda.manage'))
  with check (false);

do $rewrite$
declare
  v_def text;
  v_count integer;
  v_pattern constant text := 'if\s+v_role\s+is\s+null\s+or\s+v_role\s+not\s+in\s*\([^)]*\)\s+then';
begin
  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p
  where p.pronamespace = 'public'::regnamespace and p.proname = 'set_client_booking_block_atomic';
  if v_def is null then
    raise exception 'Funcao set_client_booking_block_atomic nao encontrada';
  end if;
  select count(*) into v_count from regexp_matches(v_def, v_pattern, 'g');
  if v_count <> 1 then
    raise exception 'set_client_booking_block_atomic: padrao encontrado % vez(es), esperado 1', v_count;
  end if;
  execute regexp_replace(v_def, v_pattern, 'if not public.has_permission(p_org_id, ''clientes.manage'') then');
end;
$rewrite$;
