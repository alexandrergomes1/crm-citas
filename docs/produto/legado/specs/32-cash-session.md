# Spec 32 - Caixa do dia: abertura, fechamento e conferência

## Status

**Implementada** (V25 · Financeiro › Caixa), em 31 out 2026. Substitui a tela "Caixa do dia" do desenho anterior,
que só listava as movimentações de um dia, sem abrir nem fechar.

## Objetivo

Controlar entradas e saídas de cada dia com um caixa que se **abre** com o valor em espécie de partida e se
**fecha** com a contagem, mostrando a diferença. Melhora o controle financeiro sem virar obrigação fiscal (o
sistema registra; não emite nada).

## Decisões (31 out 2026)

1. **Sem módulo extra.** O Caixa fica dentro do módulo `financeiro`; não existe módulo `caixa` no plano. A
   permissão "Operar o caixa" (`comanda.operate`) já existente abre, movimenta e fecha; `financeiro.manage` também.
2. **Um caixa aberto por estúdio** (índice único parcial). Não há unidades no produto ainda; quando houver, o
   índice passa a ser por unidade.
3. **Vínculo por gatilho.** Todo lançamento novo em `transactions` (comanda, sinal, estorno, devolução parcial,
   lançamento manual, conta paga) recebe `cash_session_id` do caixa aberto no instante em que é gravado. Nenhuma
   função de checkout precisou mudar. O valor enviado pelo app é ignorado (ninguém empurra lançamento para um caixa
   fechado). Sem caixa aberto o campo fica nulo, o lançamento continua válido e o app avisa.
4. **Não trava a operação.** Cobrar uma comanda sem caixa aberto não é bloqueado (pedido do responsável: nada de
   bloqueio rígido). O Caixa mostra "N lançamentos de hoje sem caixa"; ao abrir, a pessoa escolhe incluí-los
   (padrão: sim, só os de hoje).
5. **Esperado por forma** (calculado no banco no fechamento e gravado como foto):
   - Dinheiro = troco inicial + entradas em dinheiro − saídas em dinheiro + suprimentos − sangrias.
   - Cartão débito, cartão crédito, Bizum, transferência = entradas − saídas na forma (pode ficar negativo quando um
     estorno passa das entradas; a contagem aceita negativo nessas formas).
   - **Fora da conferência:** crédito da cliente, vale-presente, ajuste de saldo e lançamento sem forma (ex.: conta
     paga sem forma informada). Aparecem na lista de movimentos, marcados "não passa pela gaveta".
6. **Sangria e suprimento** são movimentos de dinheiro do caixa (`cash_movements`), com motivo obrigatório. Não são
   receita nem despesa: não aparecem na Visão geral nem no DRE. Sangria maior que o dinheiro esperado é recusada.
7. **Fechamento:** contagem em dinheiro obrigatória (sem valor sugerido, para a contagem ser cega); as demais formas
   vêm preenchidas com o esperado e podem ser corrigidas. Diferença em qualquer forma exige motivo (5 a 300
   caracteres). Campo "Fica na gaveta" (padrão: o contado) sugere o troco do próximo dia. Observações opcionais.
8. **Comanda aberta no fechamento:** comandas em rascunho ou parcial criadas desde o início do dia do caixa avisam e
   exigem a confirmação "Fechar mesmo assim". A função do banco recusa sem a confirmação; guarda quantas ficaram.
9. **Caixa de dias anteriores aberto:** se o caixa aberto é de um dia anterior, a tela mostra o alerta "Feche o caixa
   de DD/MM antes de abrir o de hoje" com atalho para fechar. Não bloqueia a operação (os lançamentos continuam
   indo para esse caixa até ele ser fechado).
10. **Reabrir:** só proprietária e administração, só o **último** caixa fechado, e só se não há outro aberto; motivo
    obrigatório; a foto do fechamento anterior vai para a auditoria e o caixa volta a "aberto" (`reopen_count`).
11. **Permissões de tela:** quem opera o caixa (`comanda.operate`) vê o caixa atual e o histórico; "Com diferença" e as
    demais seções do Financeiro exigem `financeiro.view`. Leitura das tabelas: RLS `financeiro.view` ou
    `comanda.operate`. Escrita: só pelas funções `open/close/reopen_cash_session_atomic` e `add_cash_movement_atomic`
    (nenhum insert/update/delete direto).
12. **Auditoria** (`audit_logs`, gravada dentro das funções): `CASH_OPENED`, `CASH_CLOSED` (esperado, contado, diferenças,
    motivo, comandas abertas), `CASH_DRAIN`, `CASH_SUPPLY`, `CASH_REOPENED` (com a foto do fechamento desfeito).

## Fluxo

1. **Abrir:** troco inicial (sugerido: o "fica na gaveta" do último fechamento), responsável (lista da equipe, padrão
   quem está logado), horário (padrão: agora; aceita até 7 dias atrás, nunca no futuro), observação, e "incluir os N
   lançamentos de hoje sem caixa".
2. **Durante o dia:** comandas, sinais, estornos e lançamentos manuais entram sozinhos. Botões: Novo lançamento
   (entrada/saída, saída pede motivo), Sangria, Suprimento. Movimentos do dia por forma, saldo e esperado em dinheiro
   sempre à vista.
3. **Fechar:** painel com esperado x contado por forma, diferença em tempo real, motivo, "fica na gaveta",
   observações e aviso de comandas abertas.
4. **Fechado:** resumo do fechamento (esperado, contado, diferença, motivo, quem fechou e quando) e botão de reabrir
   (quem pode). Lançamentos novos depois do fechamento ficam "sem caixa".
5. **Histórico:** caixas anteriores com data, responsável, dinheiro esperado, contado e diferença; filtro "Com
   diferença"; abrir um caixa mostra o resumo e os movimentos dele.

## Fora de escopo

Integração com TPV, gaveta física, emissão fiscal, conciliação bancária automática, vários caixas simultâneos,
notificação push no horário de fechamento (o aviso por horário de fechamento de Configurações › Horários fica para
quando o horário de funcionamento do estúdio for estruturado; hoje o alerta é por dia).

## Dados

`cash_sessions` (org_id, number, status open/closed, business_date, opened_at/by, responsible_name, opening_amount,
closed_at/by, expected/counted/differences jsonb por forma, difference_total, difference_reason, closing_notes,
left_in_drawer, open_comandas_at_close, reopen_*), `cash_movements` (org_id, session_id, kind sangria/suprimento,
amount, reason, created_by), `transactions.cash_session_id`. Migration `20261031600000_cash_sessions.sql`; teste
`supabase/tests/145_cash_session.sql`. Regras puras de esperado/diferença em `src/domain/cash-session.ts` (iguais às
do banco, com teste).

## Critérios de aceite

- [x] Abrir com troco, responsável e horário; um só caixa aberto; lançamentos de hoje sem caixa podem entrar.
- [x] Comanda, sinal, estorno e lançamento manual entram no caixa aberto (gatilho), por forma de pagamento.
- [x] Sangria e suprimento com motivo; sangria não passa do dinheiro esperado.
- [x] Fechar com contagem por forma, diferença com motivo obrigatório, "fica na gaveta" e observações.
- [x] Comanda aberta avisa e exige confirmação; o banco também recusa sem ela.
- [x] Caixa de dia anterior aberto mostra alerta com atalho para fechar.
- [x] Reabrir só proprietária/administração, último caixa, com motivo e auditoria.
- [x] Histórico com diferenças e detalhe de cada caixa.
- [x] RLS por org_id; escrita só pelas funções; auditoria de tudo.
- [x] Telas a 390, 1024, 1280, 1366 e 1440 px, com Fechar em toda tela.
- [ ] Aviso no horário de fechamento do estúdio (depende do horário estruturado; ver fora de escopo).
