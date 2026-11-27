# Specs

This folder stores active functional and technical contracts for product capabilities.

A spec is not a brainstorming note. A spec defines what must be true for a capability to be considered implemented.

## When to update a spec

Update a spec when any of these changes:

- business rule;
- data contract;
- permission/RLS expectation;
- workflow;
- status model;
- validation;
- acceptance criteria;
- required tests;
- integration boundary.

Do not update specs for small copy changes or temporary execution notes unless they change the contract.

## Relationship with other docs

- `../core-delivery-control.md`: current proven status and active blockers.
- `../agenda-operational-scope.md`: detailed operational scope for the agenda-centered flow.
- `../roadmap.md`: phase direction.
- `../scope-master.md`: broad product inventory.
- `../product-vision-detail.md`: product-owner refinements that must be migrated into specs when executable.

## Naming standard

Use numeric prefix when order/history matters, followed by clear kebab-case:

```txt
01-client-profile.md
08-packages-memberships.md
24-agenda-fresha-parity-handoff.md
```

Avoid vague names:

```txt
fixes.md
new-spec.md
claude-task.md
final.md
```

## Execution rule

Codex and Claude should not receive the entire specs folder as an execution task. ChatGPT selects the relevant spec and prepares a short phase prompt with acceptance criteria.

## Current known active specs

Known active specs include, at minimum:

- `08-packages-memberships.md`
- `22-operational-integrity-and-audit.md`
- `24-agenda-fresha-parity-handoff.md`
- `29-access-roles-modules.md`
- `30-payment-request-transfer.md`
- `31-user-preferences.md`
- `32-cash-session.md` (implementada: caixa com abertura, fechamento e conferência)
- `33-studio-settings-receipt.md`
- `35-appointment-item-duration.md`
- `36-agenda-hover-preview.md`
- `37-perfis-liberacoes-configuraveis.md`
- `41-finance-reports-dre-saldos-vales.md` (Relatórios, DRE, Saldos e Vales no desenho V25)

A numeração pula o 34: a spec 34 (importação de clientes do Fresha) vive no PR #15, fora da fila até
o sistema estar validado.

This index should be expanded when the full spec inventory is listed or when a spec is touched.
