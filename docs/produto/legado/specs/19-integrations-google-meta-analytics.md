# Spec 19 - Integrações Google, Meta e analytics

## Goal

Conectar calendários, reviews, campanhas e métricas sem comprometer privacidade
ou integridade operacional.

## Business Rules

- OAuth e tokens ficam criptografados e somente no servidor.
- Webhooks possuem assinatura, idempotência, retry e log.
- Google Calendar começa unidirecional por profissional; duas vias exige regra
  explícita de conflito e reconciliação.
- Analytics não recebe dados clínicos, respostas de anamnese ou PII desnecessária.
- Revogação de integração interrompe jobs e remove tokens conforme política.

## Data

`integration_configs`, `oauth_connections`, `webhook_events`,
`calendar_sync_entries`, `review_requests`, `audit_logs`.

## Status

Não iniciado. Google Calendar entra após agenda estável; Meta e analytics após
booking e marketing.

## Acceptance Criteria

- [ ] Reenvio de webhook não duplica efeito.
- [ ] Falha externa não corrompe agenda.
- [ ] Usuário pode desconectar e auditar a integração.
