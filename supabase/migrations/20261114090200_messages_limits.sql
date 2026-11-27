-- Mensagens e Marketing: limites de tamanho também nas tabelas (CHECK), não só nas funções. Quem grava pela API direto
-- (com mensagens.configure) e o sistema antigo passam a respeitar os mesmos tetos das funções 20261114090100:
-- modelo (nome 120, assunto 160, texto 2000), campanha (nome 120, descrição 500), item da fila (destino 200, assunto 200,
-- texto 10000), registro de envio (destino 200, texto 10000: o envio real pode ter o texto inteiro do modelo; o de teste vai até 1000; erro 500) e conexão (sessão 120, telefone 40, nome 120).
-- Conferido no banco de desenvolvimento antes: 5 modelos (maior texto 144), 0 campanhas, 0 itens de fila, 0 registros,
-- 0 conexões; nenhuma linha passa dos limites.
-- NOT VALID primeiro e VALIDATE logo depois, que confere as linhas que já existem. Tudo roda na MESMA transação da migration,
-- então o ADD CONSTRAINT segura o bloqueio da tabela até o fim; aqui é aceitável porque estas tabelas são pequenas
-- (dezenas a poucos milhares de linhas por estúdio). Em tabela grande seria preciso separar o VALIDATE em outra transação.
-- Encoding: UTF-8
set client_encoding = 'UTF8';

alter table public.marketing_message_templates
  add constraint marketing_templates_limits_check check (
    pg_catalog.char_length(name) <= 120 and pg_catalog.char_length(body) <= 2000
    and (subject is null or pg_catalog.char_length(subject) <= 160)
  ) not valid;
alter table public.marketing_message_templates validate constraint marketing_templates_limits_check;

alter table public.marketing_campaigns
  add constraint marketing_campaigns_limits_check check (
    pg_catalog.char_length(name) <= 120 and (description is null or pg_catalog.char_length(description) <= 500)
  ) not valid;
alter table public.marketing_campaigns validate constraint marketing_campaigns_limits_check;

alter table public.marketing_message_queue
  add constraint marketing_queue_limits_check check (
    pg_catalog.char_length(recipient) <= 200 and pg_catalog.char_length(message_body) <= 10000
    and (message_subject is null or pg_catalog.char_length(message_subject) <= 200)
  ) not valid;
alter table public.marketing_message_queue validate constraint marketing_queue_limits_check;

alter table public.messaging_provider_log
  add constraint messaging_log_limits_check check (
    pg_catalog.char_length(recipient) <= 200 and pg_catalog.char_length(body) <= 10000
    and (error_message is null or pg_catalog.char_length(error_message) <= 500)
  ) not valid;
alter table public.messaging_provider_log validate constraint messaging_log_limits_check;

alter table public.messaging_connections
  add constraint messaging_connections_limits_check check (
    pg_catalog.char_length(session_name) <= 120 and (phone is null or pg_catalog.char_length(phone) <= 40)
    and (display_name is null or pg_catalog.char_length(display_name) <= 120)
  ) not valid;
alter table public.messaging_connections validate constraint messaging_connections_limits_check;
