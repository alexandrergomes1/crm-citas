-- Índices das leituras do perfil da cliente (client_profile, 20261114010000).
-- Encoding: UTF-8
--
-- client_profile lê as fichas da cliente (fotos e status) e a fila de mensagens sempre por
-- estúdio + cliente, da mais nova para a mais antiga, com limite. Estes índices cobrem o filtro
-- e a ordem, então o banco lê só as linhas que vai devolver.
-- Sem "concurrently": as tabelas ainda são pequenas (desenvolvimento com dados de teste; produção
-- vazia até a virada) e nenhuma migration do projeto usa (o CLI aplica cada arquivo numa transação).
-- idx_anamneses_client (org_id, client_id) continua: outras consultas usam; avaliar remoção depois.

create index if not exists idx_anamneses_org_client_created
  on public.anamneses (org_id, client_id, created_at desc);

create index if not exists idx_marketing_queue_org_client_created
  on public.marketing_message_queue (org_id, client_id, created_at desc);
