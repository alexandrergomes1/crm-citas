-- Pagar conta: marcar paga e lançar a despesa numa transação só.
-- Encoding: UTF-8
--
-- Revisão (29 out): o app marcava a conta como paga e depois inseria a despesa no caixa.
-- Se a segunda escrita falhasse e a tentativa de desfazer também, a conta ficava paga sem
-- despesa; ao desfazer, uma conta vencida voltava como "pendente". A descrição da despesa
-- vinha do formulário, não da conta.

create or replace function public.pay_payable_atomic(
  p_org_id uuid,
  p_payable_id uuid,
  p_paid_value numeric,
  p_paid_date date
)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_payable record;
  v_transaction_id uuid;
begin
  if not public.has_permission(p_org_id, 'financeiro.manage') then
    raise exception 'Sem permissão para pagar contas' using errcode = '42501';
  end if;
  if p_paid_value is null or p_paid_value <= 0 or p_paid_value > 1000000 then
    raise exception 'Valor pago inválido' using errcode = '22023';
  end if;
  if p_paid_date is null then
    raise exception 'Data do pagamento obrigatória' using errcode = '22023';
  end if;

  -- Trava a conta: duplo clique ou duas abas não geram duas despesas.
  select p.id, p.description, p.category, p.status into v_payable
  from public.payables p
  where p.id = p_payable_id and p.org_id = p_org_id
  for update;
  if not found then
    raise exception 'Conta não encontrada' using errcode = 'P0002';
  end if;
  if v_payable.status not in ('pending', 'overdue') then
    raise exception 'Esta conta já foi paga' using errcode = 'P0001';
  end if;

  update public.payables
     set status = 'paid', paid_value = round(p_paid_value, 2), paid_date = p_paid_date
   where id = p_payable_id and org_id = p_org_id;

  insert into public.transactions (
    org_id, type, category, description, value, method, date, status, created_by
  ) values (
    p_org_id, 'expense', 'conta_paga', v_payable.description, round(p_paid_value, 2), null,
    p_paid_date, 'completed', (select auth.uid())
  )
  returning id into v_transaction_id;

  return v_transaction_id;
end;
$$;

revoke all on function public.pay_payable_atomic(uuid, uuid, numeric, date) from public, anon;
grant execute on function public.pay_payable_atomic(uuid, uuid, numeric, date) to authenticated;
