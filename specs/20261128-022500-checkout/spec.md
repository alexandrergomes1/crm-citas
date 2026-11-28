# Spec · Checkout v1 (núcleo): fechar a conta de um agendamento e registrar o pagamento

- **Status:** Draft
- **Aprovação do dono:** (pendente)
- **Aprovação do merge:** (pendente)
- **Item da fila:** 5 (`docs/BACKLOG.md`), módulo Checkout do núcleo (E3·2), em paralelo por ordem do dono (E22·B)
- **Branch:** `feat/checkout` (a partir da `previas`), empilhada por merge sobre `feat/agendamento` e `feat/caixa` (e as
  bases delas), decisão do Engenheiro de DevOps; construção em PR de rascunho; nada é juntado sem o dono (E22·B)
- **Tipo:** Tela, com Banco e Código, e **dinheiro** (`docs/guias/processo-sdd.md` §3) · **Revisores:** Revisor de
  design, Engenheiro de dados (quem não fez), Auditor de risco e Engenheiro de segurança (dinheiro e acesso),
  Revisor de código e QA
- **Escrito por:** Analista de requisitos · **Norma:** IEEE 29148 e BABOK
- **Divisão (`AGENTS.md` §4):** a primeira versão desta spec passou de 3 dúvidas de dinheiro e foi bloqueada pelo
  Auditor de risco. Ficou dividida em duas: **esta** (fechar a conta) e a seguinte, **"Checkout · estorno e
  desconto"** (§12), logo depois, ainda no núcleo.
- **Fontes:** E3·2; E6·1; E21; E21·3 ("E21-3b"); E22·B; `docs/produto/checkout.md`, `caixa.md`, `financeiro.md`
  (PR #2, branch `docs/produto-modulos`); `ARCHITECTURE.md` §3 a §7, §10 e §11; `SECURITY.md` §3 a §5; `DESIGN.md`
  §5 a §9; `src/*/AGENTS.md`; spec do item 3 (`specs/20261128-010000-banco-ligacao/spec.md`, branch
  `feat/banco-ligacao`, RG-01 a RG-08 e anexo A); spec do Agendamento (`specs/20261128-020500-agendamento/spec.md`,
  branch `feat/agendamento`). No projeto antigo, "Comanda" é este módulo.

## 1. Pedido do dono (literal)
> "Primeira versão com o núcleo (Agenda, Agendamento, Clientes, Formulários, Catálogo, Checkout, Caixa)" — E3·2, "A".

> "E21-3b" — E21·3, 28/11/2026: cobrança à cliente (link de pagamento, sinal) e vale-presente são recursos do
> Checkout e do Financeiro, **depois do núcleo**. https://claude.ai/code/session_018cV8b9epaQJNqguG5c5Aqb

> "O banco de dados atual é tudo de desenvolvimento, todos os dados são fictícios. O que se tem são as tabelas e regras
> dele. Então use se precisar. E22b" — E22·B, 28/11/2026, https://claude.ai/code/session_018cV8b9epaQJNqguG5c5Aqb

Lista candidata aprovada (E21, `docs/produto/checkout.md`): comanda por atendimento e venda avulsa · etapas revisar,
pagar, concluído · várias formas no mesmo pagamento · desconto, gorjeta e taxa · usar crédito da cliente · reembolso
· comprovante interno sem valor fiscal · cobrança por link e sinal.

## 2. Esta spec, a seguinte e depois
| Recurso candidato | Onde entra | Motivo |
|---|---|---|
| Checkout de um agendamento | **esta spec** | é o núcleo do módulo |
| Etapas Revisar, Pagar, Concluído | **esta spec** | `DESIGN.md` §6 ("Checkout", "Pagar <valor>") |
| Várias formas no mesmo pagamento, registradas à mão | **esta spec** | sem processador; a recepção anota o que a cliente pagou |
| Desconto | spec seguinte (§12) | dinheiro: teto e motivo são do dono |
| Estorno (reembolso) e cobrar de novo | spec seguinte (§12) | dinheiro e Caixa: decisões do dono |
| Venda avulsa (sem agendamento) | depois | precisa de produtos e Estoque (depois do núcleo) |
| Gorjeta e taxa | depois | gorjeta vai para comissões (Financeiro); taxa de cartão vem com a integração |
| Crédito da cliente, saldo devedor, pagamento parcial | depois | saldo da cliente é Clientes/Financeiro, depois (spec de Clientes) |
| Troco calculado | depois | nesta spec registra-se o valor que fica |
| Comprovante interno (imprimir, enviar) | depois | envio passa pela fila de mensagens (depois); a tela Concluído mostra o resumo |
| Ficha que "Bloqueia o checkout" | depois | spec de Formulários |
| Link de pagamento, sinal, vale-presente | depois | E21·3·B |
| Integração com processador de pagamento | depois | Engenheiro de integrações, spec própria (`ARCHITECTURE.md` §10) |

## 3. Quem usa
Dona e recepção (`docs/produto/checkout.md`); a profissional conforme a **E31·2**.

## 4. Telas e estados (nomes do `DESIGN.md`)
| Tela | Computador (1440) | Celular (390) |
|---|---|---|
| Entrada | botão "Checkout" no painel do agendamento (hoje desativado, spec do Agendamento); depois de pago, vira "Ver checkout" (`DESIGN.md` §6) | igual |
| **1 Revisar** | no painel à direita de 480 px: itens (serviço, preço, sem edição de preço), "Adicionar" serviço do Catálogo, ⋮ da linha para tirar; rodapé "Total ▴ valor" (`DESIGN.md` §5) | tela sem barra; rodapé com "Total ▴ valor" e o botão do rodapé (`DESIGN.md` §5) |
| **2 Pagar** | linhas forma + valor; "Adicionar" outra forma; quanto falta, à vista; botão preto "Pagar <valor>", ativo só quando a soma é igual ao total | igual, ‹ volta a Revisar |
| **3 Concluído** | resumo: itens, total, formas e valores, quem fechou e quando (ver RF-14); "Fechar" | igual |
| **Ver checkout** | o mesmo resumo, só leitura | igual |

**Estados** (`DESIGN.md` §8): vazio (agendamento sem serviço: "Ainda não há serviços" + "Adicionar serviço") ·
carregando (linhas cinza depois de 0,3 s, anunciado ao leitor) · erro ("Tentar de novo"; mensagens próprias para
"soma diferente do total", "agendamento já tem checkout", "sem permissão", "valor fora do limite" e, conforme E31·1,
"abra o caixa") · sucesso (aviso embaixo, sem "Desfazer": correção é da spec seguinte, §12).

**Nomes que faltam no `DESIGN.md` §6** (vão à ficha visual, etapa 6, e entram no `DESIGN.md` antes de construir):
avançar de Revisar para Pagar; os nomes das formas de pagamento.

## 5. Requisitos funcionais
| ID | Requisito | Fonte |
|---|---|---|
| RF-01 | Abrir o checkout de um agendamento nos status Chegou, Iniciado ou Concluído; nunca em Reservado, Confirmado, Ausência ou Cancelado. | Assumption 1 |
| RF-02 | Os itens começam com os serviços do agendamento; pode-se tirar um item ou adicionar outro serviço **ativo** do Catálogo. Mudar itens do checkout não muda o agendamento. | candidata; Assumption 2 |
| RF-03 | O preço de cada item é o do Catálogo no momento do pagamento (serviço arquivado conforme a E31·3) e **não se edita nesta spec** (desconto e ajuste: spec seguinte, §12). O servidor busca o preço no Catálogo e ignora preço ou total vindos da tela. | divisão (§12); ASVS V11.1 (lógica de negócio no servidor) |
| RF-04 | Cada item guarda cópia do nome e do preço do momento do pagamento; mudar o Catálogo depois não muda checkout pago. | princípio contábil do registro histórico |
| RF-05 | **Total** = soma dos preços dos itens (cada preço de 0 a 100.000,00, pela spec do Catálogo, E30·2). Total zero e teto por conta seguem a **E31·3**. | E31·3; spec do Catálogo (E30·2) |
| RF-06 | **Pagar:** com total maior que zero, uma ou mais linhas (até 5, limite de tela), cada uma com forma (lista da **E31·1**) e valor maior que zero, e a soma das linhas é **igual** ao total, nem mais nem menos. Com total zero (se a E31·3 permitir), a etapa Pagar não tem linhas: a conta fecha sem pagamento e o checkout fica **Sem valor**. | candidata; RN-03; E31·3 |
| RF-07 | Nada é gravado antes de "Pagar <valor>". Ao pagar, itens, total e pagamentos são gravados **de uma vez** (tudo ou nada) e o checkout nasce **Pago**. | ASVS V11.1.6 (ação atômica); Assumption 3 |
| RF-08 | **Um checkout fechado (Pago ou Sem valor) por agendamento**, exigido pelo banco (restrição única, não só pelo servidor): um segundo pedido é recusado com "agendamento já tem checkout". | ASVS V11.1.6; §7 |
| RF-09 | **Mesmo estúdio, exigido pelo banco:** checkout, itens e pagamentos ligam-se ao agendamento e ao serviço por chave composta com `org_id`, de modo que o banco recusa agendamento ou serviço de outro estúdio, mesmo que o pedido traga o id dele. O estúdio vem da sessão. | `ARCHITECTURE.md` §4 e §5; item 3 RF-03 |
| RF-10 | Checkout Pago, itens e pagamentos não se alteram nem se apagam, por ninguém e por nenhuma via, nesta spec. A correção entra pela spec seguinte (§12). | ASVS V11.1 |
| RF-11 | **Caixa:** a ligação de cada pagamento com o caixa aberto segue a **E31·1**. | `docs/produto/caixa.md`; E31·1 |
| RF-12 | Permissão por papel para fechar e ver conforme a **E31·2**; quem não pode não vê o botão e o servidor recusa. | `ARCHITECTURE.md` §4 e §6; E31·2 |
| RF-13 | Fechar passa pelas 6 portas e fica no registro (porta 6) com: ação, id do checkout e do agendamento, total, formas e valores, quem e quando. **Nunca** vão para o registro: nome de cliente, telefone, dado de saúde, **nem motivo ou qualquer texto livre**. | `ARCHITECTURE.md` §4 e §7 |
| RF-14 | **Exceção E6·1 (vale como está):** no modo "entrar como o estúdio", nada do que o dono faz fica registrado; o fechamento feito nesse modo não registra o dono no registro (porta 6) nem em "quem fechou". O plano diz como, sem contornar a exceção. | E6·1; `ARCHITECTURE.md` §6; `SECURITY.md` §5 |
| RF-15 | Valores mostrados na moeda e no formato do estúdio; o checkout guarda a moeda (código ISO 4217) com que foi pago. | `ARCHITECTURE.md` §11; ISO 4217 |
| RF-16 | **Plano B:** enquanto o Catálogo não tiver preço, ou o Caixa não existir, a parte que falta aparece "em desenvolvimento" (`DESIGN.md` §8) e os testes usam dados de exemplo locais, fictícios, escritos do zero (RG-07). | `DESIGN.md` §8; item 3 RG-07 |
| RF-17 | **Agendamento com checkout fechado não se cancela** (nem vai para Ausência): o servidor e o banco recusam a troca para Cancelado ou Ausência enquanto houver checkout Pago ou Sem valor, com a mensagem "tem checkout; cancelar depende do estorno". Isso fecha o caminho Chegou → Cancelado da spec do Agendamento (RF-07 de lá) para agendamento já pago; liberar fica para a spec "Checkout · estorno e desconto" (§12). | ASVS V11.1 (fluxo de negócio); spec do Agendamento RF-07 |
| RF-18 | **Ligação pagamento → caixa:** o Checkout é o dono da migration dessa ligação (coluna no pagamento, chave composta com `org_id` para o caixa do mesmo estúdio e a trava); a spec do Caixa só a usa (lê e confere), sem migration própria para ela. | §7; E31·1 |

### Regras de dinheiro (verificáveis, em `src/domain`)
| ID | Regra |
|---|---|
| RN-01 | Todo valor é **número inteiro na menor unidade da moeda** (centavos), na tela, no servidor e no banco; nunca número com vírgula flutuante. Não há porcentagem nesta spec, logo não há arredondamento. |
| RN-02 | Moedas de uso têm 2 casas (EUR, BRL, USD); moeda com outro número de casas é recusada nesta spec. |
| RN-03 | Total > 0: soma dos pagamentos ≠ total é recusada, e linha com valor ≤ 0 é recusada. Total = 0: qualquer linha de pagamento é recusada (zero linhas). |
| RN-04 | Total zero e teto por conta: conforme a **E31·3**. |

**Estados do checkout:** (não existe antes de fechar) → **Pago** (total > 0) ou **Sem valor** (total = 0, se a E31·3 permitir; na tela "Concluído, sem valor"). Outros estados entram pela spec seguinte (§12).

## 6. Requisitos não funcionais
| ID | Requisito | Fonte |
|---|---|---|
| RNF-01 | WCAG 2.2 AA: valores e estado com palavra (Pago), toque 44/40, foco visível, nada só por cor. | `DESIGN.md` §9 |
| RNF-02 | **Idempotência:** cada pedido de fechar leva uma chave presa a **estúdio + agendamento + resumo do conteúdo** (itens, valores, formas). A mesma chave com o mesmo conteúdo devolve o mesmo resultado, sem gravar de novo; **a mesma chave com outro conteúdo é recusada**. Toque duplo, repetição de rede ou duas pessoas ao mesmo tempo: um só checkout (RF-08). | ASVS V11.1.6; `ARCHITECTURE.md` §10 |
| RNF-03 | Nenhum dado pessoal ou de saúde em URL, registro de erro ou notificação; o checkout abre pelo id do agendamento. | `ARCHITECTURE.md` §7 |
| RNF-04 | Textos nos três idiomas (pt, es, en), pela estrutura de idiomas do item 4. | E3·1; `ARCHITECTURE.md` §11 |
| RNF-05 | Limite de idas ao banco por tela; lista de serviços para adicionar paginada. | `ARCHITECTURE.md` §5 e §11 |

## 7. Tabelas (do anexo A do item 3)
Lido só para entender (E22·B, nada copiado): `crm-agenda/supabase/migrations/` `20260601000006_finance.sql`,
`20260610_002_finance_sales.sql`, `20260613_009_checkout_support.sql`, `20261030100000_sales_number_and_paid_at.sql`,
`20261030130000_refund_sale_atomic.sql`, `20261031200000_partial_refund.sql`, `20261031600000_cash_sessions.sql`
(cabeçalhos e `create table`; funções lidas só no começo).

**Exigido nesta spec (o banco garante, com teste):**
- `org_id` obrigatório, trava RLS pela função de checagem do item 3, índice por `org_id` e teste de isolamento em
  cada tabela (RG-04).
- Chave composta com `org_id` em toda ligação: checkout → agendamento, item → checkout e serviço, pagamento →
  checkout (e → caixa, se E31·1·A ou B) (RF-09). A migration da ligação pagamento → caixa é **do Checkout** (RF-18);
  o Caixa só a usa.
- Restrição única: um checkout fechado (Pago ou Sem valor) por agendamento (RF-08); chave de idempotência única por estúdio (RNF-02).
- Valores em inteiro, com checagem no banco: preço do item ≥ 0; valor de pagamento > 0; total = soma dos itens;
  total > 0 exige soma dos pagamentos = total; total = 0 exige nenhum pagamento (e só se a E31·3 permitir); teto
  conforme E31·3.
- Troca do agendamento para Cancelado ou Ausência recusada com checkout fechado (RF-17).
- Itens e pagamentos sem alteração nem exclusão depois de gravados (RF-10); gravação numa só transação com a sessão da
  pessoa, sem chave de serviço.

**Saída de cada tabela do antigo (o Engenheiro de dados decide no plano, com ADR; RG-02):**

| Tabela (antigo) | Sugestão | Motivo |
|---|---|---|
| `sales` | **reescrever** | antigo usa `numeric(10,2)` (RN-01 pede inteiro em centavos), copia `client_name` (dado pessoal duplicado), tem rascunho, parcial, desconto, gorjeta e saldo (fora desta spec) |
| `sale_items` | **reescrever** | só serviço; sem produto, pacote, plano e "coberto por pacote" |
| `sale_payments` | **reescrever** | formas da E31·1; sem vale-presente e crédito da cliente; ligação com o caixa conforme E31·1 |
| `checkout_requests` | **reescrever** ou trocar por chave única | serve o RNF-02 (chave + resumo do conteúdo); forma escolhida com ADR |
| `sale_refunds`, `sale_partial_refunds` | **adiada** (spec seguinte, §12) | estorno |
| `sale_counters` | **descartar** (por ora) | número da comanda não aparece no `DESIGN.md`; volta com o comprovante |
| `transactions` | **adiada** (Caixa e Financeiro) | lançamento financeiro geral; a spec do Caixa decide como lê os pagamentos |
| `gift_cards`, `appointment_deposits` | **descartar** nesta spec | vale-presente e sinal: E21·3·B |

## 8. Critérios de aceite (verificáveis)
| ID | Critério | Prova |
|---|---|---|
| CA-01 | RN-01 a RN-04: total = soma dos itens, só inteiros, moeda de 2 casas, total zero e teto conforme E31·3. | unidade (`src/domain`) |
| CA-02 | Soma dos pagamentos igual ao total aceita; 1 centavo a mais ou a menos recusado; até 5 linhas; linha com valor 0 recusada; total zero com pagamento recusado e, se a E31·3 permitir, sem pagamento fecha "Sem valor". | unidade, servidor e banco |
| CA-02b | Agendamento com checkout Pago ou Sem valor não vai para Cancelado nem Ausência (servidor e banco). | teste de servidor e de banco |
| CA-03 | O servidor ignora preço e total vindos da tela e usa o Catálogo; preço do Catálogo mudado depois não muda checkout Pago. | teste de servidor |
| CA-04 | Checkout aceito em Chegou, Iniciado, Concluído; recusado nos outros status. | unidade |
| CA-05 | Segundo Pago para o mesmo agendamento recusado **pelo banco**; duas gravações simultâneas: só uma; mesma chave e mesmo conteúdo: mesmo resultado; mesma chave com outro conteúdo: recusada. | teste de banco na CI |
| CA-06 | Agendamento ou serviço de outro estúdio é recusado **pelo banco**, mesmo com id válido no pedido. | teste de banco na CI |
| CA-07 | Checkout Pago, itens e pagamentos não se alteram nem se apagam (nem com a sessão da dona). | teste de banco na CI |
| CA-08 | Caixa conforme a E31·1 (com caixa aberto, sem caixa aberto, cada forma). | teste de servidor e de banco |
| CA-09 | O estúdio A não lê, cria, altera nem apaga checkout, item ou pagamento do estúdio B; sem login ou sem papel, nada. | teste de isolamento na CI (molde do item 3) |
| CA-10 | Permissão por papel conforme E31·2 (cada papel × fechar e ver). | teste de servidor e de banco |
| CA-11 | Fechar gera registro (porta 6) com valores, sem dado pessoal e sem texto livre; URL só com id; no modo "entrar como o estúdio", nada do dono é registrado (E6·1). | teste automático e revisão do Engenheiro de segurança e do Auditor de risco |
| CA-12 | Ponta a ponta em 390 e 1440: fechar com duas formas, erro de soma, "Ver checkout". | Playwright (`e2e/`) |
| CA-13 | Estados vazio, carregando, erro e sucesso presentes; checklist do `DESIGN.md` §10 sem falha. | e2e e Revisor de design |
| CA-14 | Cada tabela do §7 tem ADR com saída, motivo, norma e o papel que conferiu; nada do antigo copiado sem ADR. | `docs/adr/` |
| CA-15 | Nada aplicado no banco remoto pela IA; banco só local até a "Aprovação do merge". | histórico da CI |
| CA-16 | Revisores do tipo (incluindo Auditor de risco e Engenheiro de segurança) sem "Bloqueia", veredito do QA e conferência do dono na prévia. | relatórios no PR |

## 9. Dependências
- **Spec "Entrar e camada de serviço"** (E36·A do dono, 28/11/2026: "E36a"; branch `feat/entrar-servico`): login,
  sessão e as 6 portas que fechar a conta usa.
- **Item 2** (CI, app vazio) · **item 3** (estúdio, papéis, função de checagem, molde do teste) · **item 4** (design
  system no código).
- **Agendamento:** status (RF-01), painel e botão "Checkout"; serviços do agendamento.
- **Catálogo** (spec sendo escrita em paralelo): serviço ativo, **preço em centavos** e moeda do estúdio. Se o
  Catálogo guardar preço de outro jeito (faixa, "a partir de", preço por profissional), esta spec volta ao dono.
- **Caixa** (spec própria): o caixa aberto, se E31·1·A ou B; sem ele, vale o plano B (RF-16). A ligação pagamento →
  caixa é migration do Checkout (RF-18); a do Caixa só a usa.
- **Agendamento:** a spec de lá precisa citar o RF-17 (sem cancelar agendamento com checkout fechado).
- **Clientes:** só o nome da cliente mostrado no resumo (lido de Clientes, não copiado).

## 10. Dúvidas ao dono (máx. 3; todas de dinheiro ou acesso)
**E31·1 · Formas de pagamento e o Caixa** (dinheiro)
- Formas nesta spec (registro à mão, sem maquininha ligada): Dinheiro · Cartão de débito · Cartão de crédito · Pix ·
  Bizum · Transferência · Outra. O estúdio esconder as que não usa vem com Ajustes (depois).
- **E31·1·A:** pagamento em **dinheiro** só com caixa aberto e entra nele; as outras formas entram no caixa aberto se
  houver, sem exigir.
- **E31·1·B:** qualquer forma só com caixa aberto.
- **E31·1·C:** sem ligação com o Caixa nesta spec.
- **Recomendo A:** a gaveta só confere se todo dinheiro passar pelo caixa, sem travar quem recebe por cartão ou Pix.
  Desfaz-se desligando a exigência; os registros ficam.

**E31·2 · Quem fecha a conta** (acesso e dinheiro)
- **E31·2·A:** dona e recepção.
- **E31·2·B:** dona e recepção, e a profissional nos próprios atendimentos.
- **Recomendo A:** quem recebe dinheiro fica no menor grupo possível (OWASP ASVS V4, menor privilégio).
  Desfaz-se dando a permissão ao papel.

**E31·3 · Valores da conta: total zero e teto** (dinheiro)
- Pela spec do Catálogo (E30·2·A recomendada), cada serviço custa de 0,00 a 100.000,00; 0 é avaliação gratuita.
- **E31·3·A:** total zero permitido quando vem só de serviços de preço 0: a conta fecha sem pagamento e fica
  "Concluído, sem valor"; sem teto por conta, vale só o limite por serviço do Catálogo.
- **E31·3·B:** como A, e um teto fixo por conta, nunca menor que 100.000,00 (o maior preço do Catálogo); acima, recusa.
- **E31·3·C:** total zero não é permitido; avaliação gratuita não passa pelo Checkout; sem teto por conta.
- **Nas três opções, serviço arquivado:** agendamento antigo com serviço que depois foi arquivado no Catálogo
  **(i)** cobra-se o preço do serviço guardado no Catálogo (o arquivado não perde o preço; o Agendamento não copia
  preço) — **recomendado**, para não travar a conta de quem já foi atendida; ou **(ii)** não deixa fechar até trocar o
  item por um serviço ativo. Responda junto: ex. "E31·3·A·i".
- **Recomendo A:** a avaliação gratuita fica registrada como atendida sem inventar pagamento, e o limite do Catálogo
  já barra valor absurdo por serviço (ASVS V5.1.4, limites de entrada). Se o dono escolher E30·2·C (preço > 0), a
  E31·3 perde o caso zero. Desfaz-se mudando a regra; nada gravado se perde.

## 11. Assumptions (decisões do papel, sem dinheiro nem acesso; recuse pelo número)
1. Checkout só em Chegou, Iniciado ou Concluído; pagar não muda o status do agendamento nesta spec.
2. Mudar itens no checkout não muda o agendamento (o agendamento guarda o que foi marcado; o checkout, o que foi pago).
3. Sem rascunho gravado: nada fica salvo antes de "Pagar <valor>"; sair no meio descarta.
4. Tabelas: a saída de cada tabela do antigo (§7) é decisão do Engenheiro de dados no plano, com ADR; as exigências
   do §7 não são opcionais.

## 12. Fora de escopo
- **Spec seguinte: "Checkout · estorno e desconto"** (logo depois desta, ainda no núcleo E3·2), com dúvidas próprias
  ao dono:
  - **Estorno:** quem estorna; prazo para estornar; estorno com o caixa daquele dia já fechado; estorno em dinheiro
    sem caixa aberto; estorno total e, talvez, parcial.
  - **Desconto:** em valor ou porcentagem (com a regra de arredondamento), teto do desconto e motivo obrigatório.
  - **Cobrar de novo** o mesmo agendamento depois de um estorno.
  - **Cancelar agendamento já pago:** hoje proibido (RF-17); a spec seguinte diz como estorno e cancelamento andam
    juntos.
  - **Achado da E6·1 no estorno:** no modo "entrar como o estúdio" o dono não é registrado (vale como está); um
    estorno feito nesse modo tira dinheiro sem registro de quem fez. Mostrar ao dono como risco, sem contornar a
    exceção.
  - Motivo do estorno e do desconto é texto livre: nunca vai para o registro (porta 6).
- Tudo marcado "depois" no §2, em especial link de pagamento, sinal e vale-presente (E21·3·B) e a integração com
  processador de pagamento (Engenheiro de integrações, spec própria, com aviso assinado e processado uma vez,
  `ARCHITECTURE.md` §10).
- **Documento fiscal** (nota fiscal no Brasil, factura na Espanha): o sistema **não** emite; o resumo não tem valor
  fiscal. Obrigação fiscal do estúdio fica fora do sistema por ora.
- Telas e regras do Caixa (abrir, sangria, fechar), relatórios e comissões (Financeiro).
- Avisos à cliente (WhatsApp, e-mail) e o sininho.
