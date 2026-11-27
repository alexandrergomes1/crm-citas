# Spec 41 - Financeiro V25: Relatórios, DRE, Saldos e Vales

## Status

**Implementada**, 31 out 2026. Substitui as telas "Anterior" de Relatórios, DRE, Saldos e Vales (e a rota
`/financeiro/anterior/<tela>`). O Caixa está na spec 32. Complementa a spec 11.

## Objetivo

Todas as seções do Financeiro no mesmo desenho: painel lateral de seções no computador (≥ 1280 px), faixa de chips
com scroll entre 1024 e 1279 px e no celular, números tabulares, Fechar em toda tela, sem selo "Anterior".

## Seções e rotas

| Seção | Rota | Quem vê |
|---|---|---|
| Visão geral | `/financeiro` | financeiro.view |
| Comandas | `/financeiro/comandas` | financeiro.view ou comanda.operate |
| Caixa | `/financeiro/caixa` (`?caixa=<id>`, `?vista=historico`) | financeiro.view ou comanda.operate |
| Relatórios | `/financeiro/relatorios` | financeiro.view |
| DRE | `/financeiro/dre` | financeiro.view |
| Contas a pagar | `/financeiro/contas` | financeiro.view |
| Comissões | `/financeiro/comissoes` | financeiro.view |
| Saldos | `/financeiro/saldos` | financeiro.view |
| Vales | `/financeiro/vales` | financeiro.view ou comanda.operate |

Endereços antigos (`/financeiro/anterior/caixa|vales|saldos|relatorios|dre|cobrancas` e `?tab=`) redirecionam
(`next.config.ts`); Cobranças por link abre a folha dentro de Comandas (`/comandas?cobrancas=1`).

## Relatórios

- **Período:** Hoje, Semana, Mês, Personalizado (`?de=&ate=`), com anterior/próximo; compara com o período anterior
  de mesmo tamanho (hoje x ontem; semana x semana anterior; mês x trecho equivalente do mês anterior; personalizado x
  o intervalo imediatamente anterior de mesmo tamanho).
- **Base:** vendas **quitadas** no período (`sales.paid_at` no fuso do estúdio), a mesma regra das comissões. Comanda
  com saldo entra quando for quitada. Estornos totais saem da base (a comanda vira cancelada); devoluções parciais
  aparecem à parte ("Estornos").
- **Números:** faturamento (total das vendas, com gorjeta), atendimentos, ticket médio (faturamento ÷ atendimentos),
  descontos, gorjetas, estornos (total e parcial) e variação contra o período anterior.
- **Quebras:** por profissional (atendimentos, faturamento, ticket, participação), por item vendido (serviço, produto,
  pacote; quantidade e valor de tabela), por forma de pagamento (inclui vale e crédito, marcados) e por dia.
- **Gráfico:** barras de faturamento por dia (por semana quando o período passa de 92 dias), com "Ver como tabela"
  (alternativa acessível), valor ao tocar e rótulo para leitor de tela.
- **Agregação no banco** (`finance_report_summary`, sem limite de 1000 linhas). **Exportação CSV** (formato longo:
  seção, item, quantidade, valor, participação) com todas as quebras.

## DRE

Demonstrativo gerencial simples em **regime de caixa**, na mesma base da Visão geral (lançamentos concluídos):

1. Receita bruta (entradas por categoria; sem crédito/vale e sem ajuste de saldo)
2. (−) Estornos
3. = Receita líquida
4. (−) Comissões (contas de comissão pagas)
5. (−) Custos e despesas por categoria (contas pagas + lançamentos de saída; sem estorno)
6. = Resultado e margem

Memorandos (não entram no resultado): descontos concedidos (já abatidos do cobrado) e contas ainda em aberto com
vencimento no período. Período e comparação como nos Relatórios (mês é o padrão). Exportação CSV. Conta paga entra pelo
valor pago e pela categoria da conta (a saída gravada como `conta_paga` não é somada de novo).
`finance_dre_summary` agrega no banco. Limitação conhecida: contas pagas antes da função `pay_payable_atomic` que
gravaram a saída com a categoria da conta podem contar duas vezes; os dados de produção não têm esse caso hoje.

## Saldos

Clientes com saldo diferente de zero: crédito (a favor da cliente) e dívida. Totais, busca, filtro Crédito/Dívida,
ordenação por valor, exportação CSV, e a linha abre o perfil da cliente.

## Vales

Vales-presente: saldo em circulação, busca, filtro por situação (ativo, utilizado, expirado, cancelado), emitir (valor,
código opcional, destinatário, validade), copiar o código, cancelar com confirmação. Emitir e cancelar exigem
`comanda.operate` (regra anterior mantida). Exportação CSV.

## Critérios de aceite

- [x] Relatórios por Hoje/Semana/Mês/Personalizado, com comparação, quebras, gráfico com tabela alternativa e CSV.
- [x] DRE com receitas, estornos, comissões, despesas por categoria, resultado, comparação e CSV.
- [x] Saldos e Vales sem perder função; confirmação ao cancelar vale.
- [x] Agregações no banco; testes de banco `146_finance_reports.sql`; testes de domínio.
- [x] Redirecionamento das URLs antigas; código do desenho anterior removido.
- [x] 390, 1024, 1280, 1366 e 1440 px sem corte; Fechar em toda tela.
