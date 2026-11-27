# Módulo: Financeiro (FIN)

> Mostra para onde foi o dinheiro do estúdio: contas a pagar, comissões, relatórios, DRE, saldos das clientes e vales-presente.
> O Caixa do dia tem arquivo próprio (`cai-caixa.md`), o link de cobrança também (`cob-cobrancas.md`).

**Telas e rotas:** `/{org}/financeiro` (Visão geral) · `/financeiro/comandas` · `/financeiro/caixa` · `/financeiro/relatorios` · `/financeiro/dre` · `/financeiro/contas` · `/financeiro/comissoes` · `/financeiro/saldos` · `/financeiro/vales` (todas existem em `src/routes/$orgSlug/financeiro/`) · **Código:** `src/workspace/financeiro/` e regras em `src/domain/` (`finance`, `finance-report`, `finance-overview`, `dre`, `commissions`) · **Spec(s):** sem spec no crm-agenda. Antigo: `docs/produto/legado/specs/11-finance-reporting.md` (MVP, em parte superada) e `41-finance-reports-dre-saldos-vales.md`.

## Recursos
| ID | Recurso | Estado | Onde | Origem |
|---|---|---|---|---|
| FIN-01 | Visão geral: lançamentos de entrada e saída, resumo do dia e do mês (receita, despesa, saldo) | pronto (antigo; a spec 11 ainda tem os critérios sem marcar) · pronto (atual) | `/financeiro` | legado spec 11:9-36,48-54; R5 B scope-master:88,91 (resumo mensal "parcial"); R2 B STATUS:32; R3 B audit:28 |
| FIN-02 | Seções do Financeiro com painel lateral (tela larga), chips (tela média e celular) e botão Fechar em toda tela | pronto (antigo) · não declarado (atual) | todas as telas do Financeiro | legado spec 41:8-28; R4 B 41 |
| FIN-03 | Contas a pagar: criar, editar, marcar como paga (gera a saída sozinha), pendente/paga/vencida, categoria e fornecedor | pronto (antigo; spec 11 com critérios em aberto) · pronto (atual) | `/financeiro/contas` | legado spec 11:17-24,48-54; R5 B scope-master:90; R2 B STATUS:32 |
| FIN-04 | Fatura anexada à conta a pagar | pronto (antigo) · não declarado (atual) | `/financeiro/contas` | R5 B core-delivery-control:54 |
| FIN-05 | Relatórios por Hoje, Semana, Mês ou período livre, com comparação, ticket médio, descontos, gorjetas, estornos | pronto (antigo) · pronto (atual) | `/financeiro/relatorios` | legado spec 41:30-45,77; R5 B scope-master:94; R3 B audit:28 |
| FIN-06 | Relatórios: quebras por profissional, item vendido, forma de pagamento e dia; gráfico de barras com "Ver como tabela" | pronto (antigo) · pronto (atual) | `/financeiro/relatorios` | legado spec 41:38-45 |
| FIN-07 | DRE simples em regime de caixa: receita bruta, estornos, comissões, despesas por categoria, resultado e margem | pronto (antigo) · pronto (atual) | `/financeiro/dre` | legado spec 41:47-62,78; R3 B audit:28 |
| FIN-08 | Exportar CSV (relatórios, DRE, saldos, vales) | pronto (antigo) · pronto (atual, no corte de 1000 linhas resolvido pelo banco) | botão de exportar de cada tela | legado spec 41:45,62,67,71; R5 A product-vision-detail:49-50 |
| FIN-09 | Comissões como seção própria (comissão pela data de quitação, chave única; contas de comissão pagas entram no DRE) | pronto (antigo; a spec 41 só cita, não descreve) · pronto (atual) | `/financeiro/comissoes` · `src/domain/commissions.ts` | legado spec 41:23,53; R5 B core-delivery-control:54; R2 B STATUS:32 |
| FIN-10 | Comissão com mais de uma profissional na mesma comanda; fechamento de comissão por período | planejado (antigo, P1) · não declarado (atual) | a definir | R5 B revisao-30-10:30 |
| FIN-11 | Saldos das clientes: crédito e dívida, busca, filtro, ordenação, CSV; a linha abre o perfil | pronto (antigo) · pronto (atual) | `/financeiro/saldos` | legado spec 41:64-67,79; R5 B scope-master:93 (dívidas e créditos "parcial") |
| FIN-12 | Vales-presente: emitir (valor, código, destinatário, validade), copiar código, cancelar com confirmação, saldo em circulação, filtro por situação | pronto (antigo) · pronto (atual) | `/financeiro/vales` | legado spec 41:69-72; R5 B scope-master:132-133 |
| FIN-13 | Vale-presente no checkout: pede o código, mostra o saldo, usa até o que falta; histórico de usos (ledger) | pronto o uso, ledger "parcial" (antigo) · "resgatar vale no checkout sem teste" (atual) | checkout (ver `comanda-checkout`) | R1 A L-1111-03 (reg:60); R5 B scope-master:134; plano de recuperação 22/11 §2 (linha Comanda e Financeiro); R3 B audit:28 |
| FIN-14 | Quem vê cada seção: Visão geral, Relatórios, DRE, Contas, Comissões e Saldos pedem `financeiro.view`; Comandas, Caixa e Vales também aceitam `comanda.operate` | pronto (antigo) · não declarado (atual) | todas as telas | legado spec 41:11-28 |
| FIN-15 | Aviso quando uma lista é cortada (contas 2000, saldos e vales 5000, comissões 5000, caixa 2000, checkouts 5000) | pronto (atual) · antigo cortava em 1000 linhas e era "aberto" | `TruncatedNotice.tsx` | R2 B STATUS:55 (fatos e limites); R5 B finance-core (1000 linhas, aberto) |
| FIN-16 | Receita em pagamento a mais (cliente paga 100 € por venda de 90 €): receita operacional = o menor entre o pago e o total; o excesso é crédito da cliente, não receita | aberto (antigo, recomendação REL-FIN-06) · não declarado (atual; há teste de cenários) | a definir | R5 B finance-core-scenarios-2026-06-17:46-78; R5 F; `src/domain/finance-core-scenarios.test.ts` |
| FIN-17 | Relatórios e DRE separam receita de valor guardado e de ajustes; precisa conferência humana com exemplos | parcial (antigo) · não declarado (atual) | `/financeiro/relatorios` · `/dre` | R5 B implementation-gap-map:46,140-154 |
| FIN-18 | Validação de cenários de dinheiro (venda total, parcial, dividida, com crédito, estorno, histórico de venda concluída) | planejado (atual, CORE-FIN-VALIDATION) · testes de domínio existem (antigo, 17/06) | `src/domain/finance-core-scenarios.test.ts` | R3 B opm:444-455; R5 B finance-core-scenarios |
| FIN-19 | Testes de ponta a ponta do Financeiro pulados em silêncio (dependiam da vitrine `/dev` que não veio) | sem teste (atual) | `e2e/` | R3 B audit:44; R3 D (testes pulados) |
| FIN-20 | Fidelidade com dois limites diferentes para "Ouro" (1.500 e 3.000 pontos), listada junto ao Financeiro | parcial (atual) · — (antigo) | `src/workspace/fidelidade` | R3 B audit:28; BACKLOG item 19 (Fase 4) |
| FIN-21 | Relatórios avançados e DRE só no plano "Completo" (preço de exemplo; o módulo existe só como dado) | planejado (antigo, spec 29) · planejado (atual) | Ajustes › Plano | legado spec 29 (tabela de módulos); R5 F (MODULE_KEYS) |
| FIN-22 | Abrir "Comandas abertas e parciais" a partir do Financeiro | planejado (antigo, roadmap) · seção `/financeiro/comandas` existe (atual, dono é `comanda-checkout`) | `/financeiro/comandas` | R5 B roadmap:156; legado spec 41:20 |

## Decisões
| ID | Decisão | Situação | Origem |
|---|---|---|---|
| FIN-D01 | Relatórios no modelo híbrido: exportar CSV em cada tela + uma tela de Relatórios só com os consolidados que cruzam módulos (R5 pedido original: "Recomendação") | **sugestão a confirmar** (sem prova) | R5 A product-vision-detail:49-50 |
| FIN-D02 | DRE em regime de caixa, na mesma base da Visão geral (lançamentos concluídos); descontos e contas em aberto aparecem só como memorando | **sugestão a confirmar** (sem prova) | legado spec 41:47-62; R4 A spec 41 |
| FIN-D03 | Relatórios contam só vendas quitadas (`sales.paid_at`, fuso do estúdio), a mesma regra das comissões; estorno total sai da base, parcial aparece à parte | **sugestão a confirmar** (sem prova) | legado spec 41:35-37; R4 A spec 41 |
| FIN-D04 | Conta paga entra no DRE pelo valor pago e pela categoria da conta (a saída `conta_paga` não é somada de novo) | **sugestão a confirmar** (sem prova) | legado spec 41:58-62 |
| FIN-D05 | Agregação dos relatórios no banco (`finance_report_summary`, `finance_dre_summary`), sem limite de 1000 linhas | **sugestão a confirmar** (sem prova) | legado spec 41:45,60 |
| FIN-D06 | Emitir e cancelar vale exigem `comanda.operate` (regra anterior mantida) | **sugestão a confirmar** (sem prova) | legado spec 41:69-72 |
| FIN-D07 | O sistema registra o dinheiro por inteiro (pagamentos, sinais, estornos, receita); não emite fatura nem decide imposto. "Evitar reporte à Hacienda" não é requisito | **sugestão a confirmar** ("decisão de 28 out" sem frase; item 9 corrigido depois) | legado spec 33:24-26; R5 A product-vision-detail:150-160 |
| FIN-D08 | Vale-presente: pede o código, mostra o saldo, usa até o que falta (L-1111-03) | **sugestão a confirmar** (sem prova; 11/11, 17h57) | R1/R5 A registro.md:60 |
| FIN-D09 | Comissão é paga pela data de quitação da venda, com chave única | **sugestão a confirmar** (sem prova) | R5 B core-delivery-control:54 |
| FIN-D10 | Receita operacional em pagamento a mais = o menor entre o pago e o total da venda (REL-FIN-06) | **sugestão a confirmar** (recomendação de auditoria, aberta) | R5 D finance-core-scenarios-2026-06-17:62-78 |
| FIN-D11 | Comissões, DRE e conciliação bancária estavam "fora do MVP" na spec 11; entraram depois (specs 17, 41). Fora de escopo agora: relatório em PDF/Excel e conciliação bancária | **sugestão a confirmar** (sem prova) | legado spec 11:56-60; R4 F |

## Regras de negócio
- Todo lançamento do checkout nasce sozinho como entrada; lançamento manual tem valor maior que zero.
- Marcar uma conta como paga cria a saída correspondente.
- Estorno total tira a venda da base dos relatórios; devolução parcial aparece à parte.
- Crédito da cliente e vale-presente não são receita bruta no DRE; ajuste de saldo também não.
- Comissão paga entra no DRE; a data que vale é a da quitação.
- Relatório e DRE saem de agregação no banco, nunca de listas cortadas; as listas que cortam avisam.
- Cada seção respeita a permissão (`financeiro.view`, `comanda.operate`); o banco é a autoridade, a tela só esconde cedo.
- O sistema não emite documento fiscal: o comprovante é interno.

## Pendências e perguntas
| Pergunta ou pendência | Origem |
|---|---|
| Spec 41 manda a "Comissões" para uma tela que ela não descreve; a regra de cálculo da comissão não tem spec própria. Quem escreve? | R4 F (spec 41:22-23 × spec 11:56-60) |
| O estado do Financeiro diverge: "pronto" no STATUS, "ou se ligam ou saem" para os módulos de regra de vale e crédito usados só por testes, e testes pulados | R2 B STATUS:32; R3 B audit:37,44 |
| Fechar o item da regra de receita em pagamento a mais (FIN-16): o antigo diz "aberto"; o atual não cita | R5 D finance-core-scenarios:62-78; R5 F |
| Contas pagas antes da função `pay_payable_atomic` podem contar duas vezes no DRE (a produção não tem esse caso hoje) | legado spec 41:60-62 |
| Estorno parcial: v26 diz "fica para depois"; o inventário e o antigo listam "Reembolso total e parcial" como existente (dono é `comanda-checkout`) | R1 F-11; R5 B painel |
| Nome "Comanda" × "Checkout" nas rotas do Financeiro (`/financeiro/comandas`) | R4 F (spec 42 §9) |
| "Layout limpo": o Financeiro está numa onda planejada (spec 45), mas a spec 45 foi substituída pelo design system v1; confirmar se a onda ainda vale | R4 B 45; R4 F |
| Cupom, quitação de débito anterior e recibo (P1) estão em `cob-cobrancas.md` e `aju-ajustes.md` | R5 B revisao-30-10:30 |

## Referências
- Legado: `docs/produto/legado/specs/11-finance-reporting.md`, `41-finance-reports-dre-saldos-vales.md`, `32-cash-session.md` (Caixa), `37-perfis-liberacoes-configuraveis.md` (permissões financeiras), `29-access-roles-modules.md` (módulos do plano).
- Legado de produto: `docs/produto/legado/produto/product-vision-detail.md` (§7 Relatórios), `scope-master.md:88-95,132-134`, `revisao-30-10.md:30`.
- Atual: `docs/STATUS.md:32,55`; `docs/specs/plans/2026-11-22-auditoria-e-plano-de-recuperacao.md`; `docs/BACKLOG.md` item 19 (Fase 4: limite duplicado de "Ouro").
- Banco: `supabase/migrations/20261114050000_finance_reads.sql`.

Regra: só vale decisão registrada em `docs/decisoes/` (molde de pergunta). Tudo desta tabela é **a confirmar**; a situação antiga fica entre parênteses só como histórico e volta a ser perguntada quando o módulo for trabalhado (resposta 15a do dono, 24/11/2026).
