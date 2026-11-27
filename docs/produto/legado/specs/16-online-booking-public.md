# Spec 16 - Booking público

## Goal

Permitir reservas 24/7 usando a disponibilidade real da agenda.

## Business Rules

- Exibe apenas serviços, locais e profissionais ativos e publicáveis.
- Slot é recalculado no servidor antes da confirmação.
- Cliente é identificado ou criado sem duplicar telefone/email.
- Bloqueio de booking, capacidade, recursos e políticas são respeitados.
- Reserva pode exigir depósito e anamnese.
- Rate limiting, anti-spam e logs são obrigatórios.

## Data

`public_booking_requests`, `appointments`, `clients`, `payment_policies`,
`appointment_deposits`, `webhook_events`.

## Status

Ampliada pela spec 38 (site de agendamento do estúdio, proposta de 29 out 2026) e pela
spec 39 (portal/marketplace). Domínio inicial de slots existe. Fluxo público, persistência, confirmação,
depósito e E2E permanecem P2.

## Acceptance Criteria

- [ ] Duas reservas concorrentes não ocupam o mesmo slot.
- [ ] Reserva cria ou associa cliente cadastrado.
- [ ] Confirmação gera atendimento e eventos auditáveis.
