# Spec 10 - Políticas de pagamento e depósitos

## Goal

Reduzir no-show e remarcações com sinal ou pré-pagamento integrado à comanda.

## Business Rules

- Política pode variar por serviço, cliente, canal e antecedência.
- Depósito confirmado reduz o saldo da comanda; não vira crédito genérico
  desconectado do atendimento.
- Pagamento, webhook, estorno e expiração são idempotentes e reconciliáveis.
- Cancelamento e remarcação aplicam política registrada no momento da reserva.
- Toda receita é integralmente registrada conforme obrigações locais.

## Data

`payment_policies`, `appointment_deposits`, `webhook_events`, `transactions`,
`client_balance_entries`, `audit_logs`.

## Status

Sinal manual possui entidade própria, idempotência e RPC transacional para
depósito, caixa, nota e auditoria. A comanda deduz sinais confirmados sem usar o
saldo genérico do cliente. Política, link online, webhook, reconciliação e
estorno permanecem P2.

## Acceptance Criteria

- [x] Sinal é vinculado ao atendimento e abatido na mesma comanda.
- [ ] Reenvio de webhook não duplica pagamento.
- [ ] Estorno restaura saldos e registra auditoria.
