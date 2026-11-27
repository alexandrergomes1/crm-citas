-- CHECKs de status e valor em vendas, caixa e contas a pagar.
-- Encoding: UTF-8
--
-- Revisão de banco (29 out), continuação de 20261029260000: as funções do checkout e do
-- caixa já validam, mas quem tem financeiro.manage grava direto em transactions e payables
-- pela API, e nada no banco impedia status fora da lista ou valor negativo/zero, que
-- distorcem os relatórios. Valores conferidos em produção antes (todos dentro da lista).

-- Vendas (escritas só pelas funções do checkout).
alter table public.sales
  add constraint sales_status_check check (status in ('draft', 'partial', 'paid', 'cancelled')),
  add constraint sales_amounts_check check (subtotal >= 0 and total >= 0 and paid_amount >= 0);

alter table public.sale_items
  add constraint sale_items_type_check check (lower(item_type) in ('service', 'product', 'package')),
  add constraint sale_items_values_check check (quantity > 0 and unit_price >= 0 and total_price >= 0);

alter table public.sale_payments
  add constraint sale_payments_amount_check check (amount > 0);

-- Caixa: estorno é um lançamento do tipo oposto com valor positivo, nunca valor negativo.
alter table public.transactions
  add constraint transactions_type_check check (type in ('income', 'expense')),
  add constraint transactions_status_check check (status in ('completed', 'pending', 'cancelled')),
  add constraint transactions_value_check check (value > 0);

-- Contas a pagar.
alter table public.payables
  add constraint payables_status_check check (status in ('pending', 'overdue', 'paid')),
  add constraint payables_value_check check (value > 0 and (paid_value is null or paid_value > 0));
