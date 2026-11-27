# SDD — Specification Driven Development

## Regra de Trabalho

Nenhum módulo evolui por tela isolada. Cada entrega passa por spec, contrato de dados, fluxo operacional, regras de negócio, segurança e testes.

## Fluxo de Artefatos

```
0. Rastreabilidade
   → Roadmap, backlog, spec, architecture, design system

1. Spec
   → docs/specs/XX-modulo.md
   → Problema, usuário, fluxo principal, fluxos alternativos, critérios de aceite

2. Domain Model
   → Tabelas, tipos, estados, invariantes, eventos
   → src/domain/

3. UX Contract
   → Estados: loading, empty, error, saving, mobile, permissão negada
   → src/design-system/ + src/features/

4. Security Contract
   → org_id, roles, RLS, PII/GDPR, audit logs, service role

5. Implementation
   → Migration (supabase/migrations/)
   → Domain service (src/domain/)
   → Server Action / API Route (src/features/)
   → UI (src/features/ + src/design-system/)
   → Tests (src/**/*.test.ts)

6. Acceptance
   → pnpm typecheck — zero erros
   → pnpm lint — zero warnings
   → pnpm test — testes de domínio passando
   → pnpm build — build limpo
   → pnpm test:e2e — E2E passando
   → Screenshot desktop 1440px + mobile 390px
```

## Template de Spec

```md
# Spec - <Módulo>/<Feature>

## Feature Trace
- Roadmap:
- Product Backlog:
- Architecture:
- Design System:

## Goal
## Users
## Screens
## Main Flow
## Business Rules
## Data Contract (Input / Output schemas Zod)
## RLS And Permissions
## UX States (loading / empty / error / saving / mobile)
## Acceptance Criteria
## Tests
## Out Of Scope
```

## Cadência Prática

1. Localizar o item no roadmap e backlog
2. Criar spec em `docs/specs/`
3. Criar migration + RLS
4. Criar domain module + testes Vitest
5. Criar componentes de tela usando design-system
6. Criar E2E Playwright
7. Validar gate de qualidade (typecheck + lint + test + build + E2E)
8. Screenshot desktop + mobile

## Agentes Por Fase

| Fase | Agente Principal |
|---|---|
| Spec | product-architect |
| Domain | domain-engineer |
| UX | ux-system-designer |
| Security | security-privacy-engineer |
| Implementation | frontend-engineer |
| Tests | qa-engineer |
| Deploy | devops-engineer |
