# Spec 06 - Cliente CRM 360

## Goal

Manter um cadastro único que conecte agenda, anamnese, comandas, saldo,
benefícios, fidelidade, comunicação e histórico.

## Business Rules

- Novo atendimento exige cliente cadastrado da mesma organização.
- Nome no atendimento é snapshot derivado do cadastro no servidor.
- Notas fixas, alergias e alertas são visíveis por relação, sem cópia obsoleta.
- Crédito e débito usam ledger com origem, referência e saldo posterior.
- Bloqueio de booking não equivale a inativação ou exclusão do cliente.
- Exclusão segue retenção e anonimização GDPR.

## Data

`clients`, `client_alerts`, `client_notes`, `client_balance_entries`,
`client_entitlements`, `loyalty_point_entries`, `audit_logs`.

## Status

Cadastro, histórico, alertas, saldo, benefícios e consentimentos estão parciais
ou prontos. Faltam alertas múltiplos históricos, bloqueio de booking, timeline
consolidada e anonimização.

## Acceptance Criteria

- [x] Cliente pode ser criado, editado e pesquisado.
- [x] Agenda e comanda exibem contexto essencial.
- [ ] Toda alteração sensível gera auditoria.
- [ ] E2E cobre cadastro, edição, saldo e bloqueio.
