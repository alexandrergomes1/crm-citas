# KA Beauty OS — Escopo Mestre (consolidado do legado + status atual)

> Consolida tudo que foi **construído** e **planejado** no sistema legado `ka-beauty`
> (ver `ka-beauty/docs/rebuild-inventory.md`, `product-modules.md`, `product-backlog-master.md`)
> e mapeia capacidades do beauty-system. A fila ativa e o status comprovado
> ficam em `core-delivery-control.md`.
> Espelho de produto: **Fresha** + SimplyBook.
> Requisitos detalhados do dono (refinamentos, prints Fresha, análises): ver **`product-vision-detail.md`**.
>
> Última atualização estrutural: 2026-06-14 (v5)
>
> As marcas abaixo indicam existência de superfície/capacidade, não maturidade
> nem aceite. O estado comprovado fica exclusivamente em
> `core-delivery-control.md`.

## Direção de produto (confirmada do legado)

- Mercado inicial: **Espanha / União Europeia**
- Moeda: **EUR** · Timezone: **Europe/Madrid** · **GDPR** desde o início
- Multi-tenant por organização, com roles: owner, admin, manager, professional, receptionist, finance, viewer
- Primeiro o **sistema operacional da clínica**; SaaS comercial/billing/marketplace depois

Legenda status: ✅ pronto · 🟡 parcial · ⛔ não iniciado

---

## Matriz de módulos (feature × status)

### Agenda — núcleo operacional
| Recurso | Status |
|---|---|
| Visual mobile-first, multi-profissional | ✅ |
| Criar / editar / reagendar / cancelar atendimento | ✅ |
| Status: agendado→confirmado→iniciado→concluído→pago / ausência / cancelado | ✅ |
| Itens de serviço/produto no atendimento | ✅ |
| Contexto do cliente (alertas, notas) na sheet | ✅ (relação carregada com o atendimento; sem waterfall dedicado) |
| Checkout integrado a partir do atendimento | ✅ |
| Anamnese vinculada ao atendimento | ✅ (criação/assinatura ✅; bloquear início sem ficha ✅) |
| Visualizações dia / 3 dias / semana / mês + zoom (S/M/G) | ✅ |
| Bloqueios e recorrências | ✅ (cliente, horário, criação e edição de série transacionais) |
| Conflitos de profissional (atendimento e bloqueio) | ✅ (validação completa + override gerencial auditado) |
| Filtros (profissional, pagamento, anamnese, origem, saldo, período) | 🟡 (multi-profissional ✅; demais ⛔) |
| Pagamento antecipado / parcial; uso de saldo cliente | 🟡 (parcial continuável+saldo ✅; antecipado ⛔) |
| Consumo de pacote/plano | ⛔ |
| Notificações cliente/profissional | ⛔ |

### Clientes (CRM 360°)
| Recurso | Status |
|---|---|
| Ficha completa (contato, endereço, documento, nascimento) | ✅ |
| Notas fixas, alertas clínicos/estéticos, tags | ✅ |
| Saldo crédito/débito | 🟡 (visão/ajuste ✅; falta ligar ledger de origem em todas as mutations) |
| Histórico de atendimentos | ✅ |
| Histórico financeiro | 🟡 |
| Benefícios de pacotes/planos (entitlements) | ✅ (tab Pacotes no perfil + criar no checkout 2026-06-12) |
| Fidelidade na ficha | 🟡 |
| Consentimentos | 🟡 (via anamnese) |

### Catálogo (fonte de verdade)
| Recurso | Status |
|---|---|
| Serviços (preço, custo, duração, buffer, categoria) | ✅ |
| Produtos (preço, custo, estoque, SKU, marca) | ✅ |
| Pacotes (itens vinculados) | ✅ (CRUD) |
| Planos / memberships (serviços elegíveis) | 🟡 (contratos/entitlements parciais; recorrência e operação comercial ⛔) |
| Serviço exige anamnese + template associado | ✅ (badge no card, selector de template no form, enforcement na agenda) |
| Profissionais permitidos / recursos (sala/equip.) | ⛔ |
| Impostos / comissão | 🟡 (comissão no staff) |

### Checkout / Vendas / Comandas
| Recurso | Status |
|---|---|
| Comanda por atendimento (não POS genérico) | ✅ |
| Carrinho serviços/produtos + extras | ✅ |
| Desconto, taxa de serviço, gorjeta, nota | ✅ |
| Split payments | ✅ |
| Métodos: dinheiro, cartão déb/créd, transferência, **Bizum** | ✅ |
| Vale-presente como pagamento | ✅ (método GIFT_CARD + validação de código + resgatar) |
| Crédito do cliente (abater saldo) | 🟡 (opcional, parser e reconciliação corrigidos; E2E financeiro completo pendente) |
| Pagamento parcial → débito; excedente → crédito | ✅ |
| Status venda: draft/paid/partial/cancelled | ✅ |
| Snapshot auditável (sales/sale_items/sale_payments) | ✅ |
| Margem bruta por item | 🟡 (campos/domínio parciais; consolidação no checkout ⛔) |

### Financeiro
| Recurso | Status |
|---|---|
| Fluxo de caixa (lançamentos receita/despesa) | ✅ |
| Comandas/vendas no caixa | ✅ |
| Contas a pagar (pendente/pago/vencido) | ✅ |
| Resumo mensal / breakdown por método/categoria | 🟡 |
| Vales-presente (entidade financeira) | ✅ |
| Dívidas e créditos por cliente | 🟡 |
| Relatórios (período, cliente, serviço, profissional, método) + CSV | ✅ (RelatoriosView + export CSV 2026-06-12) |
| Permissão por role financeira | ✅ (RLS) |

### Anamnese & GDPR
| Recurso | Status |
|---|---|
| Templates por procedimento (form builder multi-campo) | ✅ |
| Perguntas condicionais (justificativa) | ✅ |
| Respostas obrigatórias | ✅ |
| Token público com expiração | 🟡 (expiração existe; leitura de ficha assinada expirada precisa endurecimento) |
| Assinatura manual/digital (canvas) | ✅ |
| Consentimento explícito + versão | ✅ |
| Snapshot imutável do template | ✅ (evidência assinada protegida por trigger e RLS) |
| Recibo de consentimento (imprimir/PDF) | ✅ |
| Notas profissionais pré/pós atendimento | ✅ (viewer de ficha assinada + textarea profissional 2026-06-12) |
| Vínculo com agenda + consulta a anteriores | 🟡 |
| Serviço que exige anamnese bloqueia início sem ficha assinada | ✅ |

### Fidelidade
| Recurso | Status |
|---|---|
| Pontos por checkout | ✅ (creditados no checkout + ledger 2026-06-12) |
| Tiers Classic/Silver/Gold/Black + progresso | ✅ (escada + ranking + progress bar 2026-06-12) |
| Recompensas + resgate | ⛔ |
| Ledger de pontos (extrato) | ✅ (loyalty_point_entries + viewer 2026-06-12) |
| Ajuste manual de pontos | ✅ (adjustPointsAction com motivo 2026-06-12) |

### Marketing
| Recurso | Status |
|---|---|
| Segmentos (VIP, fiéis, novos, inativos, aniversário) | 🟡 (segmentos derivados ✅) |
| Automações: confirmação, lembrete, pós-atendimento, aniversário, recuperação | ⛔ (planejadas/listadas) |
| Canais WhatsApp/email/SMS | ⛔ |
| Opt-out, logs, limites diários, template variables | ⛔ |

### Vale-presente (gift cards)
| Recurso | Status |
|---|---|
| Tabela `gift_cards` criada | ✅ (schema) |
| Emissão no financeiro, código, validade, saldo, status | ✅ (tab Vales + dialog emissão + cancelamento) |
| Redenções auditáveis, uso no checkout | 🟡 (uso ✅; ledger `gift_card_redemptions` ⛔) |

### Outros / futuros
- **Google Reviews**: convite pós-atendimento + opt-out + painel reputação — ⛔
- **Booking público** (`/booking/[org]`): portal de reserva 24/7 — ⛔ (rota pública já liberada no proxy)
- **Notificações** (WhatsApp/email) — ⛔
- **SaaS Admin / billing / onboarding / limites por plano** — ⛔ (depois do operacional)
- **Configurador de métodos de pagamento** por clínica — ✅

---

## Entidades de domínio (do legado — reaproveitar contratos)
Client · Appointment · AppointmentServiceItem · Service · Product · ServicePackage ·
SubscriptionPlan · ClientEntitlement · ClientEntitlementEntry · Transaction · Sale ·
SaleLineItem · SalePayment · GiftCard · GiftCardRedemption · Payable · Professional ·
AnamneseTemplate · AnamneseQuestion · FilledAnamnese · MarketingConfig · LoyaltyReward ·
LoyaltyTier · WorkingDay · TimeBlock

## Tabelas/recursos do legado ainda ausentes ou pendentes
`memberships` · uso operacional ampliado de `audit_logs` · `client_entitlements` · `client_entitlement_entries` ·
`marketing_configs` · `marketing_opt_outs` · `marketing_message_logs` ·
escrita completa em `client_balance_entries` · escrita completa em `loyalty_point_entries` ·
`loyalty_rewards`/`loyalty_tiers` · `public_booking_requests` ·
integração completa de `gift_card_redemptions` ao checkout atômico ·
`subscription_plans`/`packages` (packages ✅)

## Regras de negócio críticas a preservar (do legado)
- **Agenda**: conflito de horário, bloqueios, status, filtros, origem, local, contexto do cliente
- **Checkout**: parcial, crédito/débito, taxa, split, vale-presente, status de venda
- **Vendas**: snapshot de itens/pagamentos, margem bruta, categoria do item no momento
- **Catálogo**: pacotes, planos, estoque, custo, SKU, duração, anamnese obrigatória
- **Entitlements**: compra, consumo, restauração, cobertura de serviços por pacote/plano
- **Anamnese**: token público, expiração, assinatura, consentimento, snapshot
- **Fidelidade**: pontos por checkout, tiers, progresso, resgate, ajustes (ledger)
- **Financeiro**: período, fluxo, CSV, mensalização, permissões por role

---

## Backlog priorizado (próximos passos, ordem de execução)
1. 🟡 **Saldo crédito/débito do cliente** — BalanceCard + ajuste manual ✅; tabela de ledger aplicada, escrita ainda não ligada a toda mutation
2. ✅ **Configurador de métodos de pagamento** por clínica — aba Pagamentos em Config + checkout respeita (feito 2026-06-11)
3. 🟡 **Catálogo: planos/memberships** + ~~flag "exige anamnese" + template associado~~ (flag+template ✅ 2026-06-11; planos/memberships ⛔)
4. ✅ **Agenda × Anamnese**: bloquear início de atendimento que exige ficha sem assinatura (feito 2026-06-11)
5. ✅ **Entitlements** (pacotes/planos): compra no checkout + tab Pacotes no perfil (feito 2026-06-12)
6. ✅ **Vale-presente**: emissão no financeiro + uso no checkout (feito 2026-06-11)
7. ✅ **Fidelidade**: ledger, ajuste manual, progresso de tier (feito 2026-06-12); recompensas/resgate ⛔
8. ✅ **Financeiro**: relatórios + CSV + breakdown método/categoria/profissional (feito 2026-06-12)
9. 🟡 **Agenda avançada**: ✅ views + zoom S/M/G + filtro profissional + bloqueio semanal + conflitos + criação/edição transacional de série; faltam atividade completa e filtros operacionais
10. **Marketing**: automações + canais (WhatsApp/email)
11. **Booking público** 24/7
12. **SaaS Admin / billing**

---

## Auditoria Fresha e legado - 2026-06-12

As Specs `24-agenda-fresha-parity-handoff.md` e `08-packages-memberships.md`
substituem o uso genérico de "avaliar" para os cinco prints recebidos.

### Lacunas confirmadas da agenda

- criação de recorrência de atendimento;
- timeline de atividade com `audit_logs`;
- ação rápida para gerar/vincular anamnese;
- nova reserva herdando cliente;
- bloqueio de booking com motivo;
- teste de contato;
- agendamento em grupo;
- tratamento de erro consistente em ausência/cancelamento;
- transações para sinal e edição de série.

### Lacunas confirmadas do catálogo

- separar bundle, pacote de sessões e membership;
- bundle com ordem e preço alocado por serviço;
- busca, filtros e ordenação;
- duplicar, arquivar/restaurar e exclusão protegida;
- locais, recursos, adicionais, imagens e disponibilidade avançada;
- tipo de preço gratuito explícito;
- preço/duração por profissional ou local.

### Prioridade corrigida

1. P0 integridade transversal: transações, idempotência, performance e E2E.
2. P1 fechamento integrado dos cinco módulos core: Cliente, Anamnese, Catálogo,
   Financeiro/Comanda e Agenda.
3. Gate obrigatório do fluxo completo antes de qualquer módulo secundário.
4. P2 booking, depósito online, comunicação e waitlist.
5. P3 grupos, compras/fornecedores, reputação e SaaS admin.

O cronograma vigente passa a ser `docs/roadmap.md`.
