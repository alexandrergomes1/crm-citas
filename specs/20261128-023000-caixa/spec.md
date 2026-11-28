# Spec · Caixa (núcleo): abrir, movimentar e fechar o dinheiro do balcão

- **Status:** Draft
- **Aprovação do dono:** (pendente)
- **Aprovação do merge:** (pendente)
- **Item da fila:** 5 (`docs/BACKLOG.md`), módulo Caixa do núcleo (E3·2), em paralelo por ordem do dono (E22·B)
- **Branch:** `feat/caixa` (a partir da `previas`), construção em PR de rascunho; nada é juntado sem o dono (E22·B)
- **Tipo:** Tela, com Banco e Código, e **dinheiro** (`docs/guias/processo-sdd.md` §3) · **Revisores:** Revisor de
  design, Engenheiro de dados (quem não fez), Auditor de risco e Engenheiro de segurança (dinheiro e acesso),
  Revisor de código e QA
- **Escrito por:** Analista de requisitos · **Norma:** IEEE 29148 e BABOK
- **Fontes:** E3·2; E21; E21·3 ("E21-3b"); E22·B; `docs/produto/caixa.md`, `checkout.md`, `financeiro.md` (branch
  `docs/produto-modulos`); `ARCHITECTURE.md` §3 a §7, §10 e §11; `SECURITY.md` §3 a §5; `DESIGN.md` §1 a §10;
  `src/*/AGENTS.md`; spec do item 3 (`specs/20261128-010000-banco-ligacao/spec.md`, branch `feat/banco-ligacao`,
  RG-01 a RG-08); spec do Checkout (`specs/20261128-022500-checkout/spec.md`, branch `feat/checkout`, versão dividida: E31·1 formas e Caixa, E31·2 quem fecha, E31·3 total zero e teto, RF-11 ligação com o Caixa; §12 = spec seguinte "Checkout · estorno e desconto").

## 1. Pedido do dono (literal)
> "Primeira versão com o núcleo (Agenda, Agendamento, Clientes, Formulários, Catálogo, Checkout, Caixa)" — E3·2, "A".

> "O banco de dados atual é tudo de desenvolvimento, todos os dados são fictícios. O que se tem são as tabelas e regras
> dele. Então use se precisar. E22b" — E22·B, 28/11/2026, https://claude.ai/code/session_018cV8b9epaQJNqguG5c5Aqb

Lista candidata aprovada (E21, `docs/produto/caixa.md`): abrir, retirar (sangria), reforçar (suprimento), fechar com
contagem cega, reabrir · aviso na hora de fechar. Para quem: dona, recepção.

## 2. Primeira versão (mínima) e depois
| Recurso candidato | Primeira versão | Motivo |
|---|---|---|
| Abrir o caixa com valor inicial (troco) | **sim** | é o começo do turno |
| Entradas vindas do Checkout (pagamentos) | **sim**, conforme **E31·1** (RF-11 do Checkout) | a gaveta só confere se o dinheiro do Checkout passar por ela |
| Saídas por estorno do Checkout | depois, com a spec "Checkout · estorno e desconto" (§12 do Checkout) | o estorno não está na v1 do Checkout |
| Sangria (retirada) e suprimento (reforço) | conforme **E32·1** | dinheiro: decisão do dono |
| Fechar com contagem, esperado e diferença registrados | **sim**; forma da contagem conforme **E32·2** | é o fim do turno |
| Aviso na hora de fechar (atendimentos de hoje sem checkout) | **sim**, só aviso, não impede (E32·2) | candidata; E32·2 |
| Histórico de caixas (lista e detalhe, só leitura) | **sim**; quem vê conforme **E32·3** | sem ele a diferença não se acompanha |
| Reabrir caixa fechado | conforme **E32·2** (recomendação: depois) | dinheiro: decisão do dono |
| Mais de um caixa aberto ao mesmo tempo (gavetas, pontos, pessoas) | conforme **E32·1** (recomendação: depois) | dinheiro: decisão do dono |
| Contagem por cédula e moeda | depois | a primeira versão conta o total em dinheiro |
| Conferência de cartão, Pix, Bizum e transferência contra extrato | depois | precisa da integração com processador ou banco (Engenheiro de integrações) |
| Lançamento manual de receita ou despesa, contas a pagar pagas pelo caixa | depois | é do Financeiro (`docs/produto/financeiro.md`) |
| Relatórios, resumo do mês, exportação, DRE | depois | Financeiro (E3·2, depois do núcleo) |
| Sugerir o valor inicial com o que ficou na gaveta no último fechamento | depois | conforto; não muda a conta |
| Imprimir ou enviar o fechamento | depois | envio passa pela fila de mensagens (depois) |
| Fechamento automático no fim do dia | depois | precisa de tarefa agendada; risco de fechar sem contagem |

## 3. Quem usa
Dona e recepção (`docs/produto/caixa.md`). O que cada papel faz (abrir, sangria e suprimento, fechar, ver o caixa
aberto, ver o histórico) segue a **E32·3**. O estúdio vem sempre da sessão (`ARCHITECTURE.md` §4, porta 2).

## 4. Telas e estados (nomes do `DESIGN.md`)
Lugar no menu: módulo **Caixa**, com as seções **Caixa atual** e **Histórico**. No computador, um item do menu
principal com submenu; no celular, dentro de **Mais** (a barra de baixo é fixa no `DESIGN.md` §5). O lugar vem do mapa
único da navegação (`DESIGN.md` §7).

| Tela | Computador (1440) | Celular (390) |
|---|---|---|
| **Caixa atual · fechado** | estado vazio: "Nenhum caixa aberto" e a ação principal **Abrir caixa** | igual; o preto do celular é o Agendar da barra, então Abrir caixa abre tela sem barra com o botão preto do rodapé (`DESIGN.md` §5) |
| **Abrir caixa** | painel à direita (480 px): Valor inicial* (com o símbolo da moeda), Observação (opcional, até 300); Salvar · Cancelar | tela sem barra, ‹ voltar, mesmo campo, botão preto no rodapé |
| **Caixa atual · aberto** | bloco "Aberto por <pessoa> em <data e hora>"; lista do que entrou e saiu (hora, tipo, forma, valor, quem), paginada; resumo por forma; "Dinheiro esperado" se E32·2·B; ação principal **Fechar caixa**; Opções ▾ com Sangria e Suprimento (E32·1) | igual, lista em linhas de 64; ⋮ com Sangria e Suprimento; Fechar caixa abre tela sem barra |
| **Sangria · Suprimento** | janelinha (340): Valor*, Motivo* (3 a 200; o campo avisa para não escrever dado de cliente ou de saúde); Salvar · Cancelar | folha de baixo, mesmos campos |
| **Fechar caixa** | passo 1: aviso (se houver) "N atendimentos de hoje sem checkout", sem impedir; campo **Dinheiro contado***; passo 2: esperado, contado e diferença com palavra e ícone (Confere · Sobra · Falta); Motivo da diferença* quando ≠ 0; confirmação na janelinha ("não se desfaz") | tela sem barra, os mesmos passos, ‹ volta um passo, botão preto no rodapé |
| **Histórico** | tabela paginada (20 por página, mais recente primeiro): abertura, fechamento, quem abriu, quem fechou, entradas em dinheiro, diferença (com palavra) | lista em linhas de 64 com os mesmos dados resumidos |
| **Ver caixa** | detalhe só leitura: abertura, movimentos, entradas e saídas por forma, esperado, contado, diferença, motivo, quem e quando | igual, ‹ voltar |

**Estados** (`DESIGN.md` §8): vazio (sem caixa aberto; histórico sem caixas: "Ainda não há caixas fechados") · sem
resultado (não há busca nem filtro na primeira versão) · carregando (linhas cinza depois de 0,3 s, anunciado ao leitor)
· erro ("Tentar de novo"; mensagens próprias para "já existe um caixa aberto", "este caixa já foi fechado", "sangria
maior que o dinheiro esperado", "entrou um pagamento novo, confira a contagem", "sem permissão") · sucesso (aviso
embaixo, sem "Desfazer": abrir, movimentar e fechar não se desfazem pela tela).

**Nomes e peças que faltam no `DESIGN.md`** (vão à ficha visual, etapa 6, e entram no `DESIGN.md` antes de construir):
o módulo Caixa na tabela do §7 e no mapa da navegação; os botões Abrir caixa, Fechar caixa, Sangria e Suprimento
(§6); as palavras e ícones de Confere, Sobra e Falta (§5); o lugar da ação principal do Caixa no celular.

## 5. Requisitos funcionais
| ID | Requisito | Fonte |
|---|---|---|
| RF-01 | **Abrir:** quem a E32·3 permite abre um caixa informando o valor inicial em dinheiro (RN-03) e, se quiser, uma observação; o caixa nasce **Aberto**, com quem abriu, quando e a moeda do estúdio (ISO 4217). | candidata |
| RF-02 | **Quantos abertos:** conforme **E32·1** (recomendação: no máximo um caixa Aberto por estúdio); um segundo pedido de abrir é recusado com "já existe um caixa aberto". | E32·1 |
| RF-03 | **Entradas do Checkout:** cada pagamento do Checkout fica ligado ao caixa Aberto no momento, conforme **E31·1** (recomendação A do Checkout: dinheiro só com caixa aberto; as outras formas entram se houver caixa aberto, sem exigir). A ligação é feita pelo servidor, nunca pelo pedido da tela. | E31·1; spec do Checkout RF-11 |
| RF-04 | **Abertura e dias:** valor inicial zero permitido ou não, e caixa aberto de um dia para o outro, conforme **E32·1**. | E32·1 |
| RF-05 | **Sangria e suprimento** (conforme E32·1): valor (RN-03) e motivo obrigatório (3 a 200 caracteres), sempre em dinheiro, só com caixa Aberto; a sangria nunca é maior que o dinheiro esperado na gaveta naquele momento. | E32·1; RN-05 |
| RF-06 | **Fechar:** informa-se o dinheiro contado (RN-03); o sistema calcula e grava, de uma vez (tudo ou nada), o esperado em dinheiro (RN-04), o contado, a diferença (RN-06) e o resumo por forma; o caixa vira **Fechado**, com quem fechou e quando. Diferença ≠ 0 exige motivo (5 a 300 caracteres; o campo avisa para não escrever dado de cliente ou de saúde). | candidata; E32·2 |
| RF-07 | **Contagem:** cega ou aberta conforme **E32·2** (recomendação: cega, o esperado só aparece depois de informado o contado). | E32·2 |
| RF-08 | **Aviso ao fechar:** se houver atendimentos de hoje (fuso do estúdio) em Chegou, Iniciado ou Concluído **sem checkout**, a tela mostra quantos, sem nomes, e deixa fechar (E32·2). Atendimento com checkout fechado com total zero ("Concluído, sem valor", se a E31·3 permitir) **não conta**: já tem checkout. | candidata ("aviso na hora de fechar"); E32·2; E31·3 |
| RF-09 | **Fechado não muda:** caixa Fechado, seus movimentos, contagem, esperado e diferença não se alteram nem se apagam, por ninguém e por nenhuma via; nenhum pagamento, sangria ou suprimento entra nele. Reabrir conforme **E32·2**. | ASVS V11.1 (regra de negócio); E32·2 |
| RF-10 | **Corrida com o fechamento:** se entrar pagamento ou movimento entre a tela de contagem e a confirmação, o fechamento é recusado com "entrou um pagamento novo, confira a contagem". Nenhum pagamento entra num caixa fechado. Conforme a E31·1·A: **só dinheiro exige caixa aberto** (sem ele, é recusado); cartão, Pix e as outras formas entram no caixa aberto, se houver, **senão ficam registrados sem caixa** (no Checkout) e não aparecem em nenhum fechamento. | ASVS V11.1.6 |
| RF-11 | **Histórico:** lista paginada dos caixas (Aberto e Fechados), mais recente primeiro, e o detalhe só leitura de cada um; quem vê conforme **E32·3**. | candidata; E32·3 |
| RF-12 | Abrir, sangria, suprimento e fechar passam pelas 6 portas e ficam no registro (porta 6): ação, valores, quem e quando, **sem** nome de cliente, telefone, motivo em texto livre ou dado de saúde. **Exceção E6·1 (vale como está):** no modo "entrar como o estúdio", abrir, sangria, suprimento e fechar feitos pelo dono ficam **sem autor registrado** (nem na porta 6 nem em "quem abriu" ou "quem fechou"); risco aceito pelo dono, à vista: o estúdio não sabe quem mexeu no dinheiro nesse modo e pode atribuir a diferença a uma funcionária. O plano diz como, sem contornar a exceção (RG-08). | `ARCHITECTURE.md` §4, §6 e §7; E6·1; `SECURITY.md` §5 |
| RF-13 | Valores mostrados na moeda e no formato do idioma da pessoa e da moeda do estúdio; o caixa guarda a moeda com que foi aberto, e nada de outra moeda entra nele. | `ARCHITECTURE.md` §11; ISO 4217 |
| RF-14 | **Plano B:** enquanto o Checkout não existir, o Caixa funciona só com abertura, movimentos e fechamento (entradas do Checkout = 0, mostradas "em desenvolvimento", `DESIGN.md` §8); os testes usam dados de exemplo locais, fictícios, escritos do zero (RG-07). | `DESIGN.md` §8; item 3 RG-07 |

### Regras de dinheiro (verificáveis, em `src/domain`)
| ID | Regra |
|---|---|
| RN-01 | Todo valor é **número inteiro na menor unidade da moeda** (centavos); nunca número com vírgula flutuante, nem na tela, nem no servidor, nem no banco (igual à RN-01 do Checkout). |
| RN-02 | Moedas de uso têm 2 casas (EUR, BRL, USD); outra quantidade de casas é recusada na primeira versão (RN-02 do Checkout). |
| RN-03 | Valor inicial ≥ 0 ou > 0 conforme **E32·1**; dinheiro contado ≥ 0; sangria e suprimento > 0. Todos só dentro do **limite técnico do tipo** escolhido pelo Engenheiro de dados (inteiro de 64 bits); acima, recusado. Fração de centavo recusada. O teto da **E31·3** é por conta do Checkout e não se aplica à gaveta; teto de gaveta, sangria ou suprimento fica para depois (Financeiro). |
| RN-04 | **Esperado em dinheiro** = valor inicial + pagamentos em dinheiro do caixa + suprimentos − sangrias. Outras formas não entram no esperado em dinheiro; aparecem só no resumo por forma (soma das entradas). Saídas por estorno entram com a spec "Checkout · estorno e desconto". |
| RN-05 | Sangria > esperado em dinheiro no momento: recusada (a gaveta não fica negativa). |
| RN-06 | **Diferença** = contado − esperado. 0 = Confere; > 0 = Sobra; < 0 = Falta. Mostrada sempre com palavra e ícone, nunca só pela cor. |
| RN-07 | Todo movimento pertence a um único caixa, do mesmo estúdio e da mesma moeda; o caixa de cada movimento é decidido pelo servidor no momento da gravação. |

**Estados do caixa:** (não existe) → **Aberto** → **Fechado** (final na primeira versão, salvo E32·2·C).

## 6. Requisitos não funcionais
| ID | Requisito | Fonte |
|---|---|---|
| RNF-01 | WCAG 2.2 AA: estado do caixa e diferença com palavra (Aberto, Fechado, Confere, Sobra, Falta), toque 44/40, foco visível, nada só por cor. | `DESIGN.md` §9 |
| RNF-02 | **Idempotência:** cada pedido de abrir, sangria, suprimento e fechar leva uma chave presa a **estúdio + caixa + resumo do conteúdo** (ação, valor, contado; em abrir, o caixa é "nenhum aberto"). A mesma chave com o mesmo conteúdo devolve o mesmo resultado, sem gravar de novo; **a mesma chave com outro conteúdo é recusada**. Toque duplo, repetição de rede ou duas pessoas ao mesmo tempo: um caixa aberto, um fechamento, um movimento. Mesmo molde do RNF-02 do Checkout. | ASVS V11.1.6; `ARCHITECTURE.md` §10 |
| RNF-03 | Fechar e gravar pagamento do Checkout ao mesmo tempo nunca deixam pagamento em caixa fechado nem fora da conta (RF-10). | ASVS V11.1.6 |
| RNF-04 | Nenhum dado pessoal ou de saúde em URL, registro de erro ou notificação; o caixa abre pelo id. | `ARCHITECTURE.md` §7 |
| RNF-05 | Textos nos três idiomas (pt, es, en), pela estrutura de idiomas do item 4. | E3·1; `ARCHITECTURE.md` §11 |
| RNF-06 | Listas do caixa aberto e do histórico paginadas; limite de idas ao banco por tela. | `ARCHITECTURE.md` §5 e §11 |
| RNF-07 | Datas e "hoje" no fuso do estúdio. | `ARCHITECTURE.md` §11 |

## 7. Tabelas · sugestão para o Engenheiro de dados decidir no plano (RG-02)
Lido só para entender (E22·B, nada copiado): `crm-agenda/supabase/migrations/20261031600000_cash_sessions.sql`
(tabelas, índices, trava e o começo das funções de abrir, movimentar e fechar).

| Tabela (antigo) | Sugestão | Motivo |
|---|---|---|
| `cash_sessions` | **reescrever** | antigo usa `numeric(12,2)` (RN-01 pede inteiro em centavos); guarda `responsible_name` em texto (dado pessoal duplicado; basta quem abriu, pelo id); esperado, contado e diferença em `jsonb` (a primeira versão conta só dinheiro: colunas inteiras); campos de reabrir e `left_in_drawer` (depois, salvo E32·2·C); servem as ideias: índice único parcial de um Aberto por estúdio, checagem Aberto/Fechado coerente, `unique (id, org_id)` para ligar filhos do mesmo estúdio |
| `cash_movements` | **reescrever** | só sangria e suprimento, em centavos, motivo obrigatório, chave estrangeira composta com `org_id` (a ideia do antigo serve); sem alteração nem exclusão depois de gravado |
| `transactions.cash_session_id` e o gatilho que carimba o caixa | **descartar** nesta spec | `transactions` é do Financeiro (depois); a ligação pagamento → caixa é criada pela **migration do Checkout** (dono dela) e gravada na mesma transação do pagamento; o Caixa só a usa (RF-03) |
| `transactions` | **adiada** (Financeiro) | lançamento financeiro geral |

Regras que valem (RG-04): `org_id` obrigatório, trava RLS pela função de checagem do item 3, índice por `org_id` e
teste de isolamento em cada tabela. **Exigido no banco (não é sugestão):** (a) restrição única parcial que permite no
máximo **um caixa Aberto por estúdio** (RF-02, se E32·1·A ou B); (b) a ligação dos movimentos (sangria e
suprimento) com o caixa por **chave estrangeira composta (caixa, `org_id`)**, para nunca ligar a caixa de outro
estúdio; a tabela do caixa oferece `unique (id, org_id)` para a mesma ligação composta, que a **migration do
Checkout** cria nos pagamentos (o Caixa não mexe nas tabelas do Checkout); (c) chave de idempotência única por estúdio (RNF-02). Sugestões ao Engenheiro de dados: valores em inteiro de
64 bits com checagem no banco (RN-03); moeda na linha do caixa; fechamento e sangria numa só transação, com
trava na linha do caixa Aberto, a mesma que o Checkout usa ao ligar o pagamento (para o RF-10) e com a sessão da pessoa (sem chave de serviço); esperado gravado no
fechamento (cópia), não recalculado depois. A forma exata é decisão dele, com ADR, combinada com o Engenheiro de dados
do Checkout, que é o dono da coluna de caixa em `sale_payments` (ou equivalente); `sale_refunds` entra com a spec de
estorno.

## 8. Critérios de aceite (verificáveis)
| ID | Critério | Prova |
|---|---|---|
| CA-01 | RN-01 a RN-07: esperado com todos os tipos de movimento, diferença Confere/Sobra/Falta, valor inicial 0 conforme E32·1, negativo recusado, acima do limite técnico do tipo recusado, fração de centavo recusada, moeda de 3 casas recusada. | unidade (`src/domain`) |
| CA-02 | Abrir com caixa já Aberto recusado (E32·1), pela restrição única do banco; duas aberturas simultâneas: só uma; mesma chave e mesmo conteúdo: mesmo resultado; mesma chave com outro conteúdo: recusada. | teste de banco na CI |
| CA-03 | Sangria maior que o esperado em dinheiro recusada; sangria e suprimento sem caixa Aberto recusados; repetidos gravam um. | unidade e banco |
| CA-04 | Pagamento do Checkout ligado ao caixa Aberto conforme E31·1 (dinheiro sem caixa aberto: recusado; cartão ou Pix sem caixa aberto: gravado sem caixa e fora de todo fechamento; com caixa aberto: entra nele). O servidor ignora caixa vindo da tela; ligação a caixa de outro estúdio recusada pela chave composta. | teste de servidor e de banco |
| CA-05 | Fechar grava esperado, contado e diferença; diferença ≠ 0 sem motivo recusada; fechar duas vezes: um só fechamento. | unidade e banco |
| CA-06 | Pagamento gravado entre a contagem e a confirmação: fechamento recusado; pagamento e fechamento simultâneos: o pagamento fica no caixa antes de fechar ou é recusado, nunca em caixa fechado. | teste de banco na CI |
| CA-07 | Caixa Fechado e seus movimentos não se alteram nem se apagam (nem com a sessão da dona); nada entra nele. | teste de banco na CI |
| CA-08 | Contagem conforme E32·2 (cega: a resposta do servidor não traz o esperado antes de receber o contado; só o total em dinheiro é contado); aviso ao fechar conta só atendimento sem checkout, não conta "Concluído, sem valor", e não impede fechar. | teste de servidor |
| CA-09 | O estúdio A não lê, cria, altera nem apaga caixa ou movimento do estúdio B; sem login ou sem papel, nada. | teste de isolamento na CI (molde do item 3) |
| CA-10 | Permissão por papel conforme E32·3 (cada papel × abrir, sangria/suprimento, fechar, ver aberto, ver histórico). | teste de servidor e de banco |
| CA-11 | Abrir, movimentar e fechar geram registro (porta 6) com valores, sem dado pessoal nem motivo em texto livre; URL só com id; no modo "entrar como o estúdio", nada registrado e sem autor (E6·1). | teste automático e revisão do Engenheiro de segurança |
| CA-12 | Ponta a ponta em 390 e 1440: abrir, suprimento, sangria, pagamento em dinheiro (Checkout ou dado de exemplo), fechar com Falta e motivo, ver no Histórico. | Playwright (`e2e/`) |
| CA-13 | Estados vazio, carregando, erro e sucesso presentes; checklist do `DESIGN.md` §10 sem falha. | e2e e Revisor de design |
| CA-14 | Cada tabela do §7 tem ADR com saída, motivo, norma e o papel que conferiu; nada do antigo copiado sem ADR. | `docs/adr/` |
| CA-15 | Nada aplicado no banco remoto pela IA; banco só local até a "Aprovação do merge". | histórico da CI |
| CA-16 | Revisores do tipo (incluindo Auditor de risco e Engenheiro de segurança) sem "Bloqueia", veredito do QA e conferência do dono na prévia. | relatórios no PR |

## 9. Dependências
- **Item 2** (CI, app vazio) · **item 3** (estúdio, moeda e fuso do estúdio, papéis, função de checagem, molde do
  teste) · **item 4** (design system no código e idiomas).
- **Checkout** (spec em paralelo): pagamentos com forma e valor em centavos (RF-11 do Checkout; a migration do Checkout cria a ligação com o caixa), a resposta da
  **E31·1** e a da **E31·3** (total zero, para o aviso do RF-08). Se E31·1·C, o Caixa não recebe entradas do Checkout na primeira versão (RF-03 sai) e
  esta spec é ajustada antes do plano. Se E31·1·B, toda forma exige caixa aberto; o RF-03 muda só no texto.
- **Checkout · estorno e desconto** (spec seguinte, §12 do Checkout): traz as saídas por estorno para o caixa, com as
  regras dela (de qual caixa sai, gaveta sem ficar negativa).
- **Agendamento:** status e data dos atendimentos de hoje, só para o aviso do RF-08 (sem ele, o aviso fica "em
  desenvolvimento").
- **`DESIGN.md`:** o módulo Caixa e os nomes do §4 entram nele, com o dono, na ficha visual (etapa 6).

## 10. Dúvidas ao dono (máx. 3; todas de dinheiro ou acesso)
**E32·1 · Abertura, dias e retiradas da gaveta** (dinheiro)
- **E32·1·A:** um caixa aberto por estúdio; valor inicial pode ser **zero** (estúdio sem troco); o caixa pode ficar
  aberto **de um dia para o outro**, com o aviso "aberto desde <data>"; sangria (retirada) e suprimento (reforço)
  sempre com motivo, e a retirada nunca passa do dinheiro que deveria estar na gaveta.
- **E32·1·B:** como A, mas o valor inicial é maior que zero e o caixa de um dia anterior precisa ser fechado antes de
  receber dinheiro hoje.
- **E32·1·C:** vários caixas abertos ao mesmo tempo (uma gaveta por ponto ou por pessoa); o resto como A.
- **Recomendo A:** uma gaveta por estúdio é o caso comum e a conta fecha com uma regra só; não trava o balcão de manhã
  por um esquecimento da véspera; sem sangria, tirar dinheiro vira "Falta" no fechamento. C entra depois sem refazer os
  dados. Desfaz-se mudando a regra de abertura; os registros ficam.

**E32·2 · Como se fecha o caixa** (dinheiro)
- **E32·2·A:** contagem **cega** só do **total em dinheiro** (sem cédula por cédula; cartão, Pix e outras formas
  aparecem só como resumo, sem contagem): quem fecha informa o contado antes de ver o esperado; a diferença fica
  gravada e, se não for zero, pede motivo. Ao fechar, um aviso mostra quantos atendimentos de hoje estão sem checkout,
  sem nomes, e **não impede** fechar. Fechado não reabre.
- **E32·2·B:** contagem **aberta**: o esperado aparece antes de contar; o resto como A (inclusive o aviso que não impede).
- **E32·2·C:** como A, e a dona pode reabrir um caixa fechado, com motivo, guardando o fechamento anterior.
- **Recomendo A:** a contagem cega evita ajustar a contagem ao esperado (controle interno, ISO 31000); sem reabrir, o
  fechado nunca muda e erro se corrige no caixa seguinte. C entra depois sem perder dados. Desfaz-se mostrando o
  esperado antes.

**E32·3 · Quem opera e quem vê o caixa** (acesso e dinheiro)
- **E32·3·A:** dona e recepção abrem, fazem sangria e suprimento, fecham e veem o caixa aberto; o **histórico** (os
  fechados e as diferenças) só a dona vê; a profissional não vê o Caixa.
- **E32·3·B:** dona e recepção fazem tudo, inclusive ver o histórico.
- **E32·3·C:** só a dona abre, movimenta e fecha; a recepção só vê o caixa aberto.
- **Recomendo A:** quem conta a gaveta não confere sozinho o próprio histórico (separação de funções e menor
  privilégio, OWASP ASVS V4; ISO 31000), sem travar a recepção no balcão. Desfaz-se mudando a permissão do papel.

## 11. Assumptions (decisões do papel, à vista na aprovação; recuse pelo número)
Nenhuma de dinheiro, acesso, dado de cliente ou de saúde (essas estão nas E31 e E32).
1. Sem número sequencial do caixa na primeira versão; ele se identifica por data, hora e quem abriu.
2. Tabelas: as sugestões do §7 são do Engenheiro de dados decidir no plano, com ADR (as exigências do §7 não são).

## 12. Fora de escopo
- Tudo marcado "depois" no §2, em especial reabrir (salvo E32·2·C), várias gavetas (salvo E32·1·C), relatórios,
  exportação, DRE e lançamentos manuais (Financeiro), e conferência de cartão e Pix com extrato (integração).
- Telas e regras do Checkout (formas de pagamento) e todo estorno e desconto, que entram com a spec "Checkout ·
  estorno e desconto" (§12 do Checkout).
- **Documento fiscal** e obrigações fiscais do estúdio: o sistema não emite nem calcula.
- Avisos à pessoa (WhatsApp, e-mail) e o sininho.
