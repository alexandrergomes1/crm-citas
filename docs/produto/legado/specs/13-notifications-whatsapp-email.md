# Spec 13 - Notificações WhatsApp e email

## Goal

Enviar mensagens transacionais confiáveis para confirmação, lembrete,
anamnese, alteração, cancelamento e pós-atendimento.

## Business Rules

- Envio usa fila, retry limitado, idempotência e status persistido.
- Templates possuem versão, locale e variáveis validadas.
- Consentimento, preferência de canal e opt-out são respeitados.
- Chaves de provedores ficam somente no servidor.
- Falha de mensageria não desfaz operação clínica já confirmada.

## Data

`message_templates`, `message_jobs`, `message_logs`, `marketing_opt_outs`,
`integration_configs`.

## Status

Domínio inicial existe; dispatcher, provedores, fila e logs reais estão
planejados para P2.

## Acceptance Criteria

- [ ] Cada gatilho cria no máximo um job por ocorrência.
- [ ] Envio e falha ficam auditáveis.
- [ ] Opt-out impede marketing sem bloquear mensagens essenciais permitidas.
