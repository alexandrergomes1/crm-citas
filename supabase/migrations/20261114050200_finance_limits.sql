-- Limites de valores e textos do financeiro também no banco (antes só no app): vale para qualquer caminho de
-- gravação (funções novas, antigas e API direta). NOT VALID + VALIDATE: a conferência das linhas que já existem
-- roda na mesma transação; as tabelas são pequenas (dezenas a milhares de linhas por estúdio) e os dados atuais
-- do banco de desenvolvimento cabem com folga (conferido em 14/11: maior conta 650,00; maior descrição 29 letras;
-- recorrência só nula, e o CHECK aceita nula; nenhum vale-presente).
-- Encoding: UTF-8
set client_encoding = 'UTF8';

alter table public.payables
  add constraint payables_value_max check (value <= 1000000 and (paid_value is null or paid_value <= 1000000)) not valid,
  add constraint payables_text_limits check (
    pg_catalog.char_length(description) <= 200
    and (vendor is null or pg_catalog.char_length(vendor) <= 100)
    and (category is null or pg_catalog.char_length(category) <= 60)
    and (notes is null or pg_catalog.char_length(notes) <= 500)
    and (invoice_name is null or pg_catalog.char_length(invoice_name) <= 80)) not valid,
  add constraint payables_recurrence_check check (recurrence is null or recurrence in ('weekly', 'monthly', 'yearly')) not valid;

alter table public.transactions
  add constraint transactions_value_max check (value <= 1000000) not valid,
  add constraint transactions_text_limits check (
    (method is null or pg_catalog.char_length(method) <= 40)
    and (category is null or pg_catalog.char_length(category) <= 60)) not valid;

alter table public.gift_cards
  add constraint gift_cards_value_limits check (initial_value > 0 and initial_value <= 100000) not valid,
  add constraint gift_cards_text_limits check (
    pg_catalog.char_length(code) between 1 and 40
    and (issued_to is null or pg_catalog.char_length(issued_to) <= 120)) not valid,
  add constraint gift_cards_status_check check (status in ('active', 'used', 'expired', 'cancelled')) not valid;

alter table public.payables validate constraint payables_value_max;
alter table public.payables validate constraint payables_text_limits;
alter table public.payables validate constraint payables_recurrence_check;
alter table public.transactions validate constraint transactions_value_max;
alter table public.transactions validate constraint transactions_text_limits;
alter table public.gift_cards validate constraint gift_cards_value_limits;
alter table public.gift_cards validate constraint gift_cards_text_limits;
alter table public.gift_cards validate constraint gift_cards_status_check;
