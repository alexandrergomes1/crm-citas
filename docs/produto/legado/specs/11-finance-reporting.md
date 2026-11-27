# Spec — Financeiro

## Goal
Visibilidade financeira operacional da clínica: lançamentos de caixa do dia/período, contas a pagar com controle de vencimento, e resumo de receitas x despesas.

## Users
Owner, admin, manager, finance. Receptionist vê apenas Caixa (sem contas a pagar).

## Screens
1. `/[orgSlug]/financeiro` — página principal com 3 tabs
   - **Caixa** — lançamentos de entrada/saída, filtro por data, totalizadores
   - **Contas a pagar** — lista de payables com CRUD
   - **Resumo** — KPIs: receita do dia, receita do mês, despesas do mês, saldo

## Main Flow
### Caixa
- Abre no dia atual, filtro de data para navegar entre dias/semanas
- Receitas geradas automaticamente pelo Checkout (type=income)
- Receitas/despesas manuais podem ser lançadas direto no caixa
- Cada linha: data, descrição, cliente, método, valor, tipo (badge)

### Contas a Pagar
- Lista filtrável por status: pending | paid | overdue
- Badge de vencimento colorido (verde/amarelo/vermelho)
- Criar nova conta: descrição, valor, data de vencimento, categoria, fornecedor
- Marcar como paga: informe valor pago e data

### Resumo
- KPIs do dia atual e do mês corrente
- Receita (transactions.type=income), Despesas (type=expense + payables pagos), Saldo

## Business Rules
- Transações de checkout são criadas automaticamente (type=income)
- Lançamentos manuais: qualquer type, validação de valor > 0
- Payable vencido = due_date < today e status=pending
- Ao marcar payable como pago: cria transaction type=expense automaticamente

## Data Contract
- `transactions`: id, org_id, type (income|expense), description, value, method, date, status, client_name
- `payables`: id, org_id, description, category, value, due_date, paid_date, paid_value, status, vendor

## UX States
- loading: skeleton
- empty caixa: banner "Nenhum lançamento para este período"
- empty payables: EmptyState com CTA "Nova conta"
- overdue payable: row destacada em vermelho

## Acceptance Criteria
- [ ] Caixa lista transações filtradas por data com totalizadores
- [ ] Lançamento manual de receita/despesa funciona
- [ ] Payables CRUD completo (criar, editar, marcar pago)
- [ ] Marcar pago cria transaction de despesa
- [ ] Resumo KPIs corretos
- [ ] typecheck + lint + build passando

## Out Of Scope (MVP)
- Relatórios exportáveis (PDF/Excel)
- Comissões de profissionais
- Conciliação bancária
- DRE completo
