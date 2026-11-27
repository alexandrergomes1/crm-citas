-- Saldo, total gasto e pontos da cliente só mudam pelas funções que gravam o extrato.
-- Encoding: UTF-8
--
-- Revisão de banco (29 out): balance, total_spent, loyalty_points e loyalty_tier podiam ser
-- editados direto pela API por quem edita clientes, e os extratos (saldo, fidelidade,
-- resgate de vale-presente) aceitavam INSERT direto, sem mexer no saldo. O ajuste manual de
-- pontos fazia 3 passos no app sem transação (o último sem checar erro).
--
-- 1. Gatilho recusa mudança dessas colunas vinda direto da API (current_user authenticated
--    ou anon). As funções SECURITY DEFINER (checkout, saldo) rodam como dona e passam.
-- 2. Ajuste manual de pontos vira função atômica com extrato e nível.
-- 3. Sem INSERT direto nos extratos e sem UPDATE direto de sinais.

create or replace function public.guard_client_ledger_columns()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('authenticated', 'anon')
     and (new.balance is distinct from old.balance
       or new.total_spent is distinct from old.total_spent
       or new.loyalty_points is distinct from old.loyalty_points
       or new.loyalty_tier is distinct from old.loyalty_tier) then
    raise exception 'Saldo e pontos mudam só por lançamento no extrato'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_client_ledger_columns on public.clients;
create trigger trg_guard_client_ledger_columns
before update on public.clients
for each row execute function public.guard_client_ledger_columns();

create or replace function public.loyalty_tier_for(p_points integer)
returns text
language sql
immutable
set search_path = ''
as $$
  -- Espelho de TIERS em src/domain/loyalty-presentation.ts.
  select case
    when p_points >= 4000 then 'Black'
    when p_points >= 1500 then 'Gold'
    when p_points >= 500 then 'Silver'
    else 'Classic'
  end;
$$;

create or replace function public.adjust_loyalty_points_atomic(
  p_org_id uuid,
  p_client_id uuid,
  p_delta integer,
  p_reason text
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_before integer;
  v_after integer;
begin
  if not public.has_permission(p_org_id, 'financeiro.manage') then
    raise exception 'Sem permissao para ajustar pontos' using errcode = '42501';
  end if;
  if p_delta is null or p_delta = 0 then
    raise exception 'Informe quantos pontos ajustar' using errcode = '22023';
  end if;
  if p_reason is null or pg_catalog.length(pg_catalog.btrim(p_reason)) = 0 or pg_catalog.length(p_reason) > 200 then
    raise exception 'Motivo obrigatorio (ate 200 caracteres)' using errcode = '22023';
  end if;

  select coalesce(c.loyalty_points, 0) into v_before
  from public.clients c
  where c.id = p_client_id and c.org_id = p_org_id
  for update;
  if not found then
    raise exception 'Cliente nao encontrado nesta organizacao' using errcode = 'P0002';
  end if;

  v_after := greatest(0, v_before + p_delta);

  insert into public.loyalty_point_entries (
    org_id, client_id, entry_type, points, balance_before, balance_after, source_type, source_id, description
  ) values (
    p_org_id, p_client_id, 'adjustment', v_after - v_before, v_before, v_after, 'manual', null, pg_catalog.btrim(p_reason)
  );

  update public.clients
     set loyalty_points = v_after,
         loyalty_tier = public.loyalty_tier_for(v_after)
   where id = p_client_id and org_id = p_org_id;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (p_org_id, (select auth.uid()), 'clients', 'LOYALTY_ADJUST', p_client_id,
          pg_catalog.jsonb_build_object('points', v_before),
          pg_catalog.jsonb_build_object('points', v_after, 'reason', pg_catalog.btrim(p_reason)));

  return v_after;
end;
$$;

revoke all on function public.adjust_loyalty_points_atomic(uuid, uuid, integer, text) from public, anon;
grant execute on function public.adjust_loyalty_points_atomic(uuid, uuid, integer, text) to authenticated;

drop policy if exists client_balance_entries_insert on public.client_balance_entries;
drop policy if exists loyalty_point_entries_insert on public.loyalty_point_entries;
drop policy if exists gift_card_redemptions_insert on public.gift_card_redemptions;
drop policy if exists appointment_deposits_update on public.appointment_deposits;
