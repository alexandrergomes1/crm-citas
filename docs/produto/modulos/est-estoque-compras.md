# Módulo: Estoque e Compras (EST)

> Saber quanto há de cada produto, de onde veio e para onde foi, e repor na hora certa.
> Hoje só existe a metade do estoque (produtos com entrada, saída e ajuste); fornecedores, pedidos e reposição nunca foram feitos.

**Telas e rotas:** não há tela própria. O estoque mora dentro do Catálogo: `/{org}/catalogo/produtos` (existe) · **Código:** `src/workspace/catalogo/_products/` (`ProductsTable`, `ProductEditor`, `ProductEditorFields`); não existe pasta de estoque, compras ou fornecedores em `src/workspace` · **Spec(s):** sem spec no crm-agenda. Antigo: `docs/produto/legado/specs/18-inventory-purchase-orders.md` (só intenção, tudo P3) e `catalog-02-produtos-combos-planos.md` (o que existe).

## Recursos
| ID | Recurso | Estado | Onde | Origem |
|---|---|---|---|---|
| EST-01 | Produto com estoque guardado por movimento (entrada, saída, ajuste); mínimo; avisos "Estoque baixo" e "Sem estoque"; estoque inicial ao criar; margem e lucro; visões Todos, Ativos, Estoque baixo, Sem estoque e Inativos com aviso na lista; arquivar em vez de excluir quando há venda ou lançamento; o formulário do produto nunca muda o estoque | pronto (antigo) · pronto "produtos e estoque" (atual) | `/catalogo/produtos` | R4 B catalog-02:29-40; R2 B history:37; plano de recuperação 22/11 §2 (linha Catálogo) |
| EST-02 | Histórico dos últimos 30 lançamentos de estoque do produto | pronto (antigo) · não declarado (atual) | `/catalogo/produtos` | R4 B catalog-02:29-40; R4 B 18:23 ("ajustes e histórico existem") |
| EST-03 | Entrada manual de estoque só por proprietária, administração e gestão; ajuste pode zerar; saída sem estoque é recusada; tudo audita `STOCK_*` | pronto (antigo) · pronto "lançar estoque exige `catalogo.manage`" (atual) | banco + `/catalogo/produtos` | legado spec 18:32-35; R2 B history:37 |
| EST-04 | Todo movimento tem tipo, quantidade, origem, custo e autor; o estoque nunca muda sem um movimento | planejado (P3, critério `[ ]`) (antigo) · não declarado (atual) | a definir | legado spec 18:9,28; R4 B 18 |
| EST-05 | Venda e consumo de insumo baixam o estoque na mesma transação da comanda; cancelar restaura por movimento inverso | planejado (P3) (antigo) · não declarado (atual) | checkout | legado spec 18:10-11 |
| EST-06 | Fornecedores por produto, com prazo de entrega, lote mínimo e fornecedor preferido | planejado P3 (antigo) · não declarado (atual) | a definir | legado spec 18:12,23-24; R5 B product-vision-detail:66-69 |
| EST-07 | Consumo de insumo por serviço (o serviço gasta produto) | planejado P3 (antigo) · não declarado (atual) | a definir | legado spec 18:23-24 |
| EST-08 | Sugestão de reposição: usa estoque disponível, mínimo, consumo médio e prazo de entrega; ou a periodicidade que a pessoa informa e o sistema calcula | planejado P3 (antigo) · não declarado (atual) | a definir | legado spec 18:13; R5 B product-vision-detail:66-69 |
| EST-09 | Pedidos de compra: rascunho → pedido → recebido em parte → recebido → cancelado | planejado P3 (antigo) · não declarado (atual) | a definir | legado spec 18:14; R5 B roadmap:214 |
| EST-10 | Recebimento atualiza custo e saldo em uma só transação; recebimento parcial | planejado P3 (antigo) · não declarado (atual) | a definir | legado spec 18:23-24,29 |
| EST-11 | Relatório que explica consumo, perda, venda e compra | planejado P3 (antigo) · não declarado (atual) | a definir | legado spec 18:30 |
| EST-12 | Módulo "Estoque e compras" como extra do plano (12 € no Profissional, incluído no Completo; preço de exemplo); alinhar as chaves de módulo (reserva, estoque, relatórios, unidades) com o que existe | planejado, só como dado (antigo) · não declarado (atual) | Ajustes › Plano | legado spec 29 (tabela de módulos); R5 B revisao-30-10:11 |
| EST-13 | Permissão de estoque em lista fixa de papéis, ainda sem liberação configurável | planejado (fase 2 de perfis) | banco | legado spec 37:75-77; R5 B revisao-codigo-e-banco:129-135 |

## Decisões
Todas vêm da spec 18 ou do mapa do produto, sem frase do dono.

| ID | Decisão | Situação | Origem |
|---|---|---|---|
| EST-D01 | Todo movimento de estoque tem tipo, quantidade, origem, custo e autor | **sugestão a confirmar** (sem prova) | legado spec 18:9 |
| EST-D02 | Venda e consumo de insumo baixam o estoque na mesma transação da comanda; cancelar devolve por movimento inverso | **sugestão a confirmar** (sem prova) | legado spec 18:10-11 |
| EST-D03 | Produto pode ter fornecedores, prazo de entrega, lote mínimo e fornecedor preferido | **sugestão a confirmar** (sem prova) | legado spec 18:12 |
| EST-D04 | A sugestão de reposição usa estoque disponível, mínimo, consumo médio e prazo de entrega | **sugestão a confirmar** (sem prova) | legado spec 18:13 |
| EST-D05 | Estados do pedido de compra: draft, ordered, partially_received, received, cancelled | **sugestão a confirmar** (sem prova) | legado spec 18:14 |
| EST-D06 | Entrada manual só owner, admin e manager; ajuste pode zerar; saída sem estoque recusada; auditoria `STOCK_*` (29/10/2026) | **sugestão a confirmar** (sem prova) | legado spec 18:32-35 |
| EST-D07 | Fornecedores, pedidos, recebimento parcial e reposição ficam na Fase 3 (P3) | **sugestão a confirmar** (sem prova) | legado spec 18:23-24; R5 B roadmap:214 |
| EST-D08 | Produtos moram no Catálogo (seção Produtos), com Serviços, Pacotes, Combos e Planos | **sugestão a confirmar** (sem prova) | legado spec 28-nav regra 4 |

## Regras de negócio
- O estoque só muda por movimento (entrada soma, saída subtrai e recusa abaixo de zero, ajuste define o total contado); o formulário do produto não mexe nele. Já é assim hoje para os lançamentos manuais; a regra para venda e compra ainda é intenção.
- Saída sem estoque suficiente é recusada.
- Venda baixa o estoque junto com a comanda; cancelar devolve com movimento inverso.
- Recebimento de compra atualiza custo e saldo de uma só vez.
- Produto vendido não é apagado, é arquivado (tem histórico).
- Só quem tem `catalogo.manage` (proprietária, administração, gestão) lança estoque.

## Pendências e perguntas
| Pergunta ou pendência | Origem |
|---|---|
| Módulo "só tem metade": fornecedores, consumo por serviço, pedidos, recebimento parcial e reposição nunca foram feitos e não têm dono nem data | R4 B 18; R4 F; R5 F (possivelmente perdido) |
| Falta uma spec de funcionalidade no crm-agenda; o estoque aparece só como parte do Catálogo | R2 B history:37; R3 F-25 |
| A baixa de estoque na comanda (EST-05) está só como intenção; conferir o que o checkout do atual já faz | legado spec 18:10-11 |
| Alinhar as chaves de módulo com o que existe (reserva, estoque, relatórios, unidades) | R5 B revisao-30-10:11 |
| A spec 29 trata "Estoque e compras" como módulo com preço próprio; a spec 28 põe Produtos dentro do Catálogo. Qual vale? | legado spec 28-nav regra 4; legado spec 29 (tabela de módulos) |

## Referências
- Legado: `docs/produto/legado/specs/18-inventory-purchase-orders.md`, `catalog-02-produtos-combos-planos.md`, `28-navegacao-marketing-ajustes.md` (regra 4), `29-access-roles-modules.md`, `37-perfis-liberacoes-configuraveis.md`.
- Legado de produto: `docs/produto/legado/produto/product-vision-detail.md:66-69`, `roadmap.md:214`, `revisao-30-10.md:11`.
- Banco: migration `supabase/migrations/20261029060200_stock_entry_rules.sql`.

Regra: só vale decisão registrada em `docs/decisoes/` (molde de pergunta). Tudo desta tabela é **a confirmar**; a situação antiga fica entre parênteses só como histórico e volta a ser perguntada quando o módulo for trabalhado (resposta 15a do dono, 24/11/2026).
