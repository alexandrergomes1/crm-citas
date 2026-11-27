# Spec 20 - Administração SaaS e billing

## Goal

Operar múltiplas clínicas, planos, limites, cobrança e suporte sem misturar
dados dos tenants.

## Business Rules

- Billing SaaS é separado do financeiro clínico.
- Superadmin não usa service role no navegador.
- Impersonation exige motivo, expiração e audit log.
- Limites de plano são validados no servidor.
- Suspensão preserva dados e segue política contratual.

## Data

`saas_plans`, `subscriptions`, `billing_events`, `usage_counters`,
`support_access_grants`, `audit_logs`.

## Status

Planejado para P3/P4, depois do núcleo operacional confiável.

## Acceptance Criteria

- [ ] Nenhum tenant acessa dados de outro.
- [ ] Webhooks de billing são idempotentes.
- [ ] Acesso de suporte é temporário e auditável.
