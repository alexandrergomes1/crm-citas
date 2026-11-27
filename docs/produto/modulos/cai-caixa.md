# Módulo: Caixa (CAI)

> O caixa do dia: abre com o dinheiro da gaveta, recebe tudo o que é vendido, e fecha com a contagem, mostrando a diferença.
> O sistema registra; não emite nada fiscal.

**Telas e rotas:** `/{org}/financeiro/caixa` (`?caixa=<id>` abre um caixa; `?vista=historico` lista os anteriores) · **Código:** `src/workspace/financeiro/caixa/`, `src/workspace/financeiro/_components/caixa/`, regras em `src/domain/cash-session.ts` e `cash-day.ts` · **Spec(s):** sem spec no crm-agenda. As decisões estão na spec 32 do legado: `docs/produto/legado/specs/32-cash-session.md` (31/10/2026, "Implementada").

## Recursos
| ID | Recurso | Estado | Onde | Origem |
|---|---|---|---|---|
| CAI-01 | Abrir o caixa: troco inicial (sugere o "fica na gaveta" do último fechamento), responsável (padrão: quem está logado), horário (até 7 dias atrás, nunca no futuro), observação | pronto (antigo) · pronto "abrir caixa" (atual) | `/financeiro/caixa` | legado spec 32:54-56,84; R2 B STATUS:32 |
| CAI-02 | Um só caixa aberto por estúdio (quando houver unidades, um por unidade) | pronto (antigo) · não declarado (atual) | banco (índice único parcial) | legado spec 32:18-19 |
| CAI-03 | Lançamento entra no caixa aberto sozinho (comanda, sinal, estorno, devolução parcial, lançamento manual, conta paga), por forma de pagamento | pronto (antigo) · pronto "vender em dinheiro, estornar" (atual) | gatilho no banco | legado spec 32:20-23,85; R2 B STATUS:32 |
| CAI-04 | Aviso "N lançamentos de hoje sem caixa" e escolha de incluí-los ao abrir (padrão: sim, só os de hoje) | pronto (antigo) · não declarado (atual) | `/financeiro/caixa` | legado spec 32:24-26,54-56 |
| CAI-05 | Novo lançamento manual (entrada ou saída; saída pede motivo) | pronto (antigo) · não declarado (atual) | `/financeiro/caixa` | legado spec 32:57-59; R5 B scope-master:88 (fluxo de caixa pronto) |
| CAI-06 | Sangria e suprimento em dinheiro, com motivo; sangria maior que o dinheiro esperado é recusada; não são receita nem despesa | pronto (antigo) · não declarado (atual) | `/financeiro/caixa` | legado spec 32:33-34,86 |
| CAI-07 | Fechar: contagem cega em dinheiro; as outras formas vêm com o esperado e podem ser corrigidas; diferença pede motivo (5 a 300 letras); "Fica na gaveta"; observações | pronto (antigo) · não declarado (atual) | `/financeiro/caixa` | legado spec 32:35-39,87 |
| CAI-08 | Esperado por forma (dinheiro, débito, crédito, Bizum, transferência) calculado no banco e guardado como foto no fechamento | pronto (antigo) · não declarado (atual) | banco + `src/domain/cash-session.ts` | legado spec 32:27-32 |
| CAI-09 | Aviso de comanda aberta no fechamento, com "Fechar mesmo assim"; o banco recusa sem a confirmação | pronto (antigo) · não declarado (atual) | `/financeiro/caixa` | legado spec 32:38-39,88 |
| CAI-10 | Alerta "Feche o caixa de DD/MM antes de abrir o de hoje", com atalho; não bloqueia | pronto (antigo) · não declarado (atual) | `/financeiro/caixa` | legado spec 32:40-42,89 |
| CAI-11 | Reabrir o último caixa fechado: só proprietária e administração, com motivo, e só se não há outro aberto | pronto (antigo) · não declarado (atual) | `/financeiro/caixa` | legado spec 32:43-44,89 |
| CAI-12 | Histórico de caixas (data, responsável, esperado, contado, diferença), filtro "Com diferença", resumo e movimentos de cada caixa | pronto (antigo) · não declarado (atual) | `/financeiro/caixa?vista=historico` | legado spec 32:62-66,91 |
| CAI-13 | Quem usa: `comanda.operate` ou `financeiro.manage` opera; "Com diferença" e o resto do Financeiro pedem `financeiro.view`; escrita só pelas funções do banco | pronto (antigo) · não declarado (atual) | banco + tela | legado spec 32:14-17,45-47,92; R4 B 32 |
| CAI-14 | Auditoria de tudo: aberto, fechado, sangria, suprimento, reaberto | pronto (antigo) · não declarado (atual) | `audit_logs` | legado spec 32:49-50,92 |
| CAI-15 | Aviso no horário de fechamento do estúdio | planejado (antigo, depende de horário estruturado) · não declarado (atual) | a definir | legado spec 32:69-71,94; R5 B core-delivery-control:135 |
| CAI-16 | Campos de horário do Caixa e de Ajustes com o seletor de 15 minutos | planejado (antigo) · não declarado (atual) | a definir | R4 D (spec 48:3-5,27-28) |
| CAI-17 | Telas do Caixa conferidas a 390, 1024, 1280, 1366 e 1440 px, com Fechar | pronto (antigo) · não declarado (atual) | `/financeiro/caixa` | legado spec 32:93 |
| CAI-18 | Referência de mercado: Booksy só tem caixa ("registers") no tablet e na web | referência (atual) | — | R3 B booksy:113 |

## Decisões
Todas são da spec 32 (31/10/2026), escritas sem a frase do dono. Nenhuma tem resposta dele registrada, então ficam como sugestão.

| ID | Decisão | Situação | Origem |
|---|---|---|---|
| CAI-D01 | Sem módulo extra: o Caixa mora no Financeiro. Abrir, mexer e fechar com `comanda.operate` (ou `financeiro.manage`) (spec 32 #1) | **sugestão a confirmar** (sem prova) | legado spec 32:14-17 |
| CAI-D02 | Um caixa aberto por estúdio; por unidade quando houver unidades (spec 32 #2) | **sugestão a confirmar** (sem prova) | legado spec 32:18-19 |
| CAI-D03 | O vínculo é por gatilho: todo lançamento novo recebe o caixa aberto no instante em que é gravado; o valor enviado pelo app é ignorado; sem caixa aberto fica vazio e o app avisa (spec 32 #3) | **sugestão a confirmar** (sem prova) | legado spec 32:20-23 |
| CAI-D04 | Não trava a operação: cobrar sem caixa aberto não é bloqueado. "Pedido do responsável: nada de bloqueio rígido" (spec 32 #4) | **sugestão a confirmar** (a fonte cita o pedido sem aspas, 31/10) | legado spec 32:24-26; R4 A spec 32 #4 |
| CAI-D05 | Esperado em dinheiro = troco + entradas − saídas + suprimentos − sangrias; nas outras formas = entradas − saídas (pode ficar negativo). Fora da conferência: crédito da cliente, vale-presente, ajuste de saldo e lançamento sem forma, marcados "não passa pela gaveta" (spec 32 #5) | **sugestão a confirmar** (sem prova) | legado spec 32:27-32; R4 F |
| CAI-D06 | Sangria e suprimento têm motivo obrigatório e não aparecem na Visão geral nem no DRE; sangria maior que o dinheiro esperado é recusada (spec 32 #6) | **sugestão a confirmar** (sem prova) | legado spec 32:33-34 |
| CAI-D07 | Fechamento: contagem em dinheiro cega (sem valor sugerido); diferença exige motivo de 5 a 300 letras; "Fica na gaveta" sugere o troco do dia seguinte (spec 32 #7) | **sugestão a confirmar** (sem prova) | legado spec 32:35-37 |
| CAI-D08 | Comanda em rascunho ou parcial criada desde o início do dia do caixa avisa e exige "Fechar mesmo assim"; o banco também recusa sem confirmação (spec 32 #8) | **sugestão a confirmar** (sem prova) | legado spec 32:38-39 |
| CAI-D09 | Caixa de dia anterior aberto só gera alerta com atalho; não bloqueia, e os lançamentos continuam indo para ele até ser fechado (spec 32 #9) | **sugestão a confirmar** (sem prova) | legado spec 32:40-42 |
| CAI-D10 | Reabrir: só proprietária e administração, só o último caixa fechado, só sem outro aberto, com motivo; a foto do fechamento anterior vai para a auditoria (spec 32 #10) | **sugestão a confirmar** (sem prova) | legado spec 32:43-44 |
| CAI-D11 | Permissões de tela: quem opera o caixa vê o atual e o histórico; "Com diferença" e o resto do Financeiro pedem `financeiro.view`; escrita só pelas funções `open/close/reopen_cash_session_atomic` e `add_cash_movement_atomic` (spec 32 #11) | **sugestão a confirmar** (sem prova) | legado spec 32:45-48 |
| CAI-D12 | Auditoria gravada dentro das funções: `CASH_OPENED`, `CASH_CLOSED`, `CASH_DRAIN`, `CASH_SUPPLY`, `CASH_REOPENED` (spec 32 #12) | **sugestão a confirmar** (sem prova) | legado spec 32:49-50 |
| CAI-D13 | Fora de escopo: TPV, gaveta física, emissão fiscal, conciliação bancária automática, vários caixas ao mesmo tempo, push no fechamento | **sugestão a confirmar** (sem prova) | legado spec 32:67-71 |

## Regras de negócio
- Só existe um caixa aberto por vez; ninguém grava lançamento em caixa fechado.
- Vender sem caixa aberto nunca é bloqueado; o app avisa e o lançamento fica "sem caixa".
- Dinheiro esperado = troco inicial + entradas em dinheiro − saídas em dinheiro + suprimentos − sangrias.
- Crédito da cliente, vale-presente, ajuste de saldo e lançamento sem forma não entram na conta da gaveta.
- Diferença no fechamento sempre pede motivo; reabrir pede motivo e deixa a foto do fechamento na auditoria.
- Sangria e suprimento não são receita nem despesa.
- As regras de esperado e diferença são as mesmas no banco e em `src/domain/cash-session.ts`, com teste.

## Pendências e perguntas
| Pergunta ou pendência | Origem |
|---|---|
| Estado diverge: a spec 32 diz "Implementada" (31/10) e o controle do antigo diz "Caixa do dia (spec 32) planejado sem data". O atual diz "pronto: abrir, vender, estornar". Conferir o que o código faz de verdade (sangria, fechar, reabrir) | R4 B 32; R5 B core-delivery-control:135; R2 B STATUS:32 |
| A spec 32 existe só no sistema antigo; não há spec no crm-agenda. Escrever a spec do Caixa (molde de funcionalidade) antes de mexer | R2 B STATUS:32; R4 A spec 32 |
| As specs 11 e 41 ainda descrevem o "Caixa do dia" antigo (lista); a spec 32 diz que substitui | R4 F |
| Regra de negócio a preservar: crédito, vale e ajuste de saldo ficam fora da gaveta | R4 F |
| Aviso no horário de fechamento depende de o horário de funcionamento ser estruturado (Ajustes › Horário) | legado spec 32:69-71,94 |
| Teste de ponta a ponta do Financeiro está pulado; o do caixa depende de ambiente | R3 B audit:44 |
| Guia de testes do painel antigo lista "caixa do dia" como item a testar | R5 D painel-da-jornada.html:139-145 |

## Referências
- Legado: `docs/produto/legado/specs/32-cash-session.md`, `41-finance-reports-dre-saldos-vales.md` (rota do Caixa), `11-finance-reporting.md` (Caixa antigo).
- Banco (antigo): migration `20261031600000_cash_sessions.sql`, teste `supabase/tests/145_cash_session.sql`.
- Atual: `docs/STATUS.md:32`; `docs/referencias-mercado/booksy.md:113`.

Regra: só vale decisão registrada em `docs/decisoes/` (molde de pergunta). Tudo desta tabela é **a confirmar**; a situação antiga fica entre parênteses só como histórico e volta a ser perguntada quando o módulo for trabalhado (resposta 15a do dono, 24/11/2026).
