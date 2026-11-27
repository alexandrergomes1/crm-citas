# Spec 09 - Comanda por atendimento e liquidação

## Status

Aprovada. Substitui a interpretação anterior de checkout como POS genérico.

## Goal

Manter uma única comanda vinculada ao atendimento, permitindo revisar itens,
registrar pagamentos, salvar sem pagar e liquidar valores pendentes sem perder
o contexto da agenda, do cliente ou do profissional.

## Modelo operacional

- O agregado raiz é o atendimento.
- A comanda é o registro comercial e financeiro desse atendimento.
- Checkout é a ação de liquidar a comanda, não um módulo de cesta independente.
- A rota `/[orgSlug]/checkout/[appointmentId]` é detalhe de implementação.
- Não existe checkout avulso ou carrinho global no escopo atual.
- A listagem de comandas abertas, parciais ou sem pagamento pertence à Agenda
  e ao Financeiro.

## Main Flow

1. Atendimento é aberto com cliente cadastrado e itens.
2. Usuário abre a comanda a partir do atendimento.
3. Pode ajustar itens, desconto, cupom, gorjeta, taxa e nota.
4. O uso de crédito positivo do cliente é opcional e desligado por padrão.
5. Usuário registra zero, um ou vários pagamentos.
6. Sem pagamento, a comanda permanece `draft`.
7. Pagamento insuficiente gera `partial` e débito rastreável.
8. Pagamentos posteriores são adicionados até zerar o saldo.
9. Quitação muda venda e atendimento para `paid`.

## Business Rules

- Novos atendimentos exigem `client_id` válido da mesma organização.
- Registros históricos sem cliente continuam legíveis e liquidáveis.
- Pagamentos persistidos não podem ser reduzidos ou substituídos na continuação.
- Apenas o incremento recebido gera nova transação financeira.
- Crédito positivo só é consumido por escolha explícita.
- Excedente recebido gera crédito no ledger do cliente.
- Toda venda mantém snapshot imutável de itens, preços, custos e pagamentos.
- Checkout deve ser transacional e idempotente conforme a Spec 22.
- Cancelar venda não exclui atendimento nem histórico financeiro.

## Payment Methods

Métodos iniciais configuráveis por organização:

`CASH | CARD_DEBIT | CARD_CREDIT | TRANSFER | BIZUM | CLIENT_CREDIT | GIFT_CARD`

Moeda operacional inicial: EUR.

## Data Contract

- `appointments`: origem operacional e estado do atendimento.
- `sales`: uma comanda por atendimento, status, totais e saldo pendente.
- `sale_items`: snapshot dos itens cobrados.
- `sale_payments`: pagamentos externos e benefícios aplicados.
- `transactions`: caixa efetivamente recebido ou estornado.
- `client_balance_entries`: origem de crédito, débito e abatimento.
- `gift_card_redemptions`: cada uso de vale-presente.
- `audit_logs`: abertura, alteração, pagamento, cancelamento e estorno.

## Performance

- Abertura não pode depender de consultas sequenciais evitáveis.
- Dados essenciais de atendimento, cliente e venda carregam em paralelo.
- Cache de dados operacionais mutáveis não pode mascarar consulta lenta.
- Meta de produção: p95 de leitura abaixo de 1,5 s e mutation abaixo de 2 s,
  medidos separadamente da compilação de desenvolvimento.

## Acceptance Criteria

- [x] Comanda abre apenas com `appointmentId`.
- [x] Pagamento parcial aceita quitação posterior.
- [x] Crédito positivo é opcional.
- [x] O valor textual `"false"` não ativa crédito nem benefício.
- [x] Alternar crédito reconcilia pagamento automático ou excedente sem apagar
  um pagamento parcial deliberado.
- [x] Métodos incluem dinheiro, cartões, transferência e Bizum.
- [x] Rota genérica de checkout redireciona para a agenda.
- [ ] RPC transacional e idempotente cobre toda a liquidação.
- [ ] Ledger de saldo e vale-presente é gravado na mesma transação.
- [ ] E2E cobre draft, total, parcial, continuação, crédito e vale.

## Out Of Scope

- POS genérico de balcão.
- Carrinho global sem atendimento.
- Fechamento de caixa dentro da comanda.
- Terminal físico e emissão fiscal.

## Regras do banco (29 out 2026)

- Sinal maior que o total final: o excedente vira crédito da cliente (`overpayment_credit`).
- Atendimento Cancelado ou Ausência não pode ser cobrado.
- Cobrança de crédito por link: só owner, admin e manager confirmam.
