# Spec 00 — Product Operating Model

## Feature Trace
- Roadmap: Fase 0 — Scaffold + Fundação
- Source: `ka-beauty/docs/ka-beauty-os-complete-development-plan.md`

## Goal

Definir o modelo operacional do KA Beauty OS como produto — quem usa, como usa, o que promete e quais módulos o compõem.

## Users

| Perfil | Papel | Uso Principal |
|---|---|---|
| Dono/admin | owner | Configuração, relatórios, financeiro |
| Recepcionista | receptionist | Agenda, clientes, checkout |
| Esteticista | professional | Agenda pessoal, anamnese |
| Gerente | manager | Relatórios, equipe, metas |
| Financeiro | finance | Caixa, vendas, contas |
| Visualizador | viewer | Leitura apenas |

## Promessa do Produto

> Um sistema operacional premium para clínicas de estética que conecta agenda, cliente, anamnese, catálogo, checkout, financeiro, equipe, marketing e fidelidade em um fluxo único, rápido e confiável.

## Módulos

1. **Agenda** — núcleo operacional, tudo passa por aqui
2. **Clientes** — CRM 360 com histórico completo
3. **Catálogo** — serviços, produtos, recursos, pacotes, planos
4. **Comanda/Vendas** — comanda por atendimento, auditável e com múltiplos métodos
5. **Financeiro** — caixa, transações, relatórios, lucro real
6. **Anamnese/GDPR** — fichas por procedimento, consentimento digital
7. **Notificações** — WhatsApp, email, lembretes, review request
8. **Marketing** — campanhas, segmentação, reativação
9. **Fidelidade** — pontos, tiers, recompensas, pacotes, memberships
10. **Online Booking** — portal público 24/7
11. **Equipe** — staff, turnos, comissões, metas
12. **Integrações** — Google, Meta, WhatsApp API
13. **SaaS** — onboarding, billing, admin (futuro)

## Business Rules

1. Agenda é o centro — toda ação opera a partir de um atendimento
2. Checkout é disparado pela agenda, não é módulo isolado
3. Serviço pode sugerir/exigir um template, mas a anamnese criada é uma única
   entidade vinculada ao cliente e ao atendimento; a parte profissional vive
   nessa mesma anamnese
4. Pagamento parcial gera débito no cliente automaticamente
5. Crédito excedente vira saldo do cliente
6. Status do atendimento determina fluxo financeiro e de comunicação
7. Toda venda tem snapshot imutável (items + payments)
8. Marketing tem opt-out e limite diário por cliente
9. Toda tabela tem `org_id` com RLS

## Referência de Produto

Inspiração principal: Fresha for Business.
Diferencial: mais premium, mais mobile-first, mais forte em anamnese/GDPR, mais integrado, mais controle para a clínica (menos marketplace, menos taxas).

## Out Of Scope (v1)

- Marketplace multi-clínica público
- Billing SaaS (fase 14)
- Google Reserve
- Facebook/Instagram bookings
- Terminal físico de pagamento
