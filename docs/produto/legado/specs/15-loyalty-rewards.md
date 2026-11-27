# Spec 15 - Fidelidade e recompensas

## Goal

Acumular pontos por regras configuráveis e permitir resgates auditáveis.

## Business Rules

- Pontos são lançados em ledger, nunca apenas sobrescritos no cliente.
- Regra pode usar valor, serviço, quantidade, tier e período.
- Checkout idempotente não duplica pontos.
- Cancelamento ou estorno gera lançamento inverso.
- Recompensa valida elegibilidade, saldo, validade e limite.

## Data

`loyalty_accounts`, `loyalty_point_entries`, `loyalty_tiers`,
`loyalty_rewards`, `loyalty_redemptions`.

## Status

Pontos, ledger, ajuste e tiers existem. Catálogo de recompensas e resgate
transacional permanecem P3.

## Acceptance Criteria

- [x] Extrato explica cada movimento.
- [ ] Resgate ocorre na mesma transação da comanda.
- [ ] Estorno devolve benefício e pontos corretamente.
