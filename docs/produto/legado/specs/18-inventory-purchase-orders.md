# Spec 18 - Inventário, fornecedores e compras

## Goal

Controlar estoque vendável e insumos, sugerir reposição e registrar compras.

## Business Rules

- Todo movimento possui tipo, quantidade, origem, custo e autor.
- Venda e consumo de insumo baixam estoque na mesma transação da comanda.
- Cancelamento restaura estoque por movimento inverso.
- Produto pode ter fornecedores, lead time, lote mínimo e fornecedor preferido.
- Sugestão usa estoque disponível, mínimo, consumo médio e lead time.
- Pedido passa por draft, ordered, partially_received, received e cancelled.

## Data

`suppliers`, `product_suppliers`, `stock_entries`, `inventory_movements`,
`purchase_orders`, `purchase_order_items`, `audit_logs`.

## Status

Ajustes e histórico de stock existem. Fornecedores, consumo por serviço,
pedidos, recebimento parcial e reposição estão em P3.

## Acceptance Criteria

- [ ] Estoque nunca muda sem movimento correspondente.
- [ ] Recebimento atualiza custo e saldo de forma transacional.
- [ ] Relatório explica consumo, perda, venda e compra.

## Regras do banco (29 out 2026)

- Entrada manual de estoque: só owner, admin e manager. Ajuste pode zerar; saída sem estoque é
  recusada; tudo audita `STOCK_*`.
