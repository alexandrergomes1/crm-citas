# Catálogo: Produtos, Combos e Planos

Sem migration: tabelas, RPCs e RLS já existiam (`products`, `stock_entries`, `service_bundles`, `subscription_plans`,
`register_stock_entry_atomic`, `upsert_service_bundle_atomic`, `archive_service_bundle`, `restore_service_bundle`,
`duplicate_service_bundle`). Todas continuam filtradas por `org_id` com RLS.

## Rotas
| Seção | Rota | Editor (URL) |
|---|---|---|
| Produtos | `/[org]/catalogo/produtos` | `?novo=1`, `?editar=<id>`, `?foco=estoque` (abre rolado no painel de estoque) |
| Combos | `/[org]/catalogo/combos` | `?novo=1`, `?editar=<id>` |
| Planos | `/[org]/catalogo/planos` | `?novo=1`, `?editar=<id>` |

Prévia com dados fictícios: `/dev/v25/catalogo/{produtos,combos,planos}` (só em desenvolvimento).

Redirecionamento permanente (308, `next.config.ts`) do catálogo antigo:
`/[org]/anterior/catalogo?aba=produtos` para `/catalogo/produtos`; `aba=bundles` (ou `combos`) para `/catalogo/combos`;
`aba=planos` para `/catalogo/planos`; `aba=pacotes` para `/catalogo/pacotes`; qualquer outro endereço antigo para `/catalogo`.
O código antigo (`app/(workspace)/[orgSlug]/anterior/catalogo`) foi removido.

## Estrutura (igual a Serviços e Pacotes)
- Cada seção: hook de dados, Desktop, Mobile, Editor, Tabela e Screen (arquivos de tela até 300 linhas).
- Computador: painel lateral com as 5 seções (com contagem, sem selo "Anterior") e as visões da seção; cartão com busca,
  Filtros, menu de visões, menu Opções (colunas, exportar CSV) e botão Novo; tabela com colunas configuráveis.
- Tablet e celular: controle segmentado de seções, chips de visão, linha de ordem e contagem, filtros em folha, segurar
  a linha abre as ações. Botões com no mínimo 44 px.
- Editor: painel lateral no computador, tela cheia no celular; sempre com botão Fechar (X) e Cancelar.

## Produtos
- Colunas: produto (marca e SKU), categoria, estoque (com mínimo), margem e lucro, preço, estado. Opcionais: custo, online.
- Visões: Todos, Ativos, Estoque baixo, Sem estoque, Inativos. Aviso na lista quando há produtos para repor.
- Estoque mínimo: no valor ou abaixo, o produto aparece como "Estoque baixo"; zero é "Sem estoque". O alerta aparece na
  lista, no editor (selo no painel de estoque) e reage ao mínimo digitado.
- Estoque só muda por movimento, nunca pelo formulário do produto (`updateProduct` ignora `stock_qty`):
  - Entrada soma; Saída subtrai e recusa abaixo de zero; Ajuste define o total contado (pode zerar).
  - Usa `register_stock_entry_atomic` (apenas gerente, com auditoria). A regra é espelhada no domínio (`applyStockMove`).
  - Histórico dos últimos 30 lançamentos no editor.
- Produto novo aceita estoque inicial, gravado na criação.
- Excluir: se há vendas ou lançamentos de estoque, o produto é arquivado (desativado) em vez de apagado.
- Duplicar e desativar/ativar pelo menu da linha.

## Combos
- Itens (serviços com quantidade e preço alocado) e preço do combo. Regra do banco: a soma de `preço alocado x
  quantidade` fecha com o preço do combo, com pelo menos 2 serviços diferentes.
- Combo novo rateia o preço automaticamente; o aviso "Ratear" fecha a diferença. Mostra preço avulso, economia e duração.
- Estados: Ativo, Inativo, Arquivado (Arquivar e Restaurar no rodapé do editor e no menu). Duplicar cria o combo inativo.

## Planos
- Assinatura recorrente: cobrança Mensal, Trimestral ou Anual, sessões por período, preço do período.
- Mostra valor por sessão e equivalente mensal. Serviços incluídos por marcação; nenhum marcado vale para todos.
- Estados: Ativo e Inativo ("Colocar à venda"). Editar um plano inativo não o reativa (o editor sempre envia `active`).

## Permissões e validações
Mesmas das ações antigas: `catalogo.manage`, validação Zod dos contratos (`src/domain/catalog-contracts.ts`) e
`revalidatePath(..., 'layout')` para atualizar as rotas aninhadas. Textos em pt-BR.

## Fora desta entrega
- Vender combo ou plano numa comanda (o checkout aceita SERVICE, PRODUCT e PACKAGE); por isso não há contagem de vendas
  em Combos e Planos.
- Importação em lote de produtos e planos (item desativado "Em breve" no menu Opções).

## Critérios de aceite
1. `/catalogo/produtos`, `/combos` e `/planos` abrem com painel de seções com contagem e sem selo "Anterior".
2. Cada uma tem busca, filtros, visões, colunas, exportar CSV, menu da linha e Novo; no celular, seções em controle
   segmentado, sem rolagem horizontal e sem a barra inferior cobrindo conteúdo (390 px).
3. Nada cortado em 1440, 1366, 1280, 1024 e 390 px.
4. Produto: criar com nome e preço; validar campos; entrada, saída e ajuste de estoque; alerta de estoque baixo.
5. Combo: criar com 2 ou mais serviços e preço fechando; arquivar e restaurar.
6. Plano: criar com recorrência, sessões, preço e serviços incluídos; desativar e colocar à venda.
7. `/anterior/catalogo?aba=...` redireciona com 308 para a nova rota.
8. `pnpm typecheck`, `pnpm lint` e `pnpm test` sem erros; E2E em `e2e/catalogo-v25.spec.ts` (prévia e rotas autenticadas).
