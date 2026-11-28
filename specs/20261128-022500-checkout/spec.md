# Spec · Checkout (núcleo): fechar a conta de um agendamento e registrar o pagamento

- **Status:** Draft
- **Aprovação do dono:** (pendente)
- **Aprovação do merge:** (pendente)
- **Item da fila:** 5 (`docs/BACKLOG.md`), módulo Checkout do núcleo (E3·2), em paralelo por ordem do dono (E22·B)
- **Branch:** `feat/checkout` (a partir da `previas`), construção em PR de rascunho; nada é juntado sem o dono (E22·B)
- **Tipo:** Tela, com Banco e Código, e **dinheiro** (`docs/guias/processo-sdd.md` §3) · **Revisores:** Revisor de
  design, Engenheiro de dados (quem não fez), Auditor de risco e Engenheiro de segurança (dinheiro e acesso),
  Revisor de código e QA
- **Escrito por:** Analista de requisitos · **Norma:** IEEE 29148 e BABOK
- **Fontes:** E3·2; E21; E21·3 ("E21-3b"); E22·B; `docs/produto/checkout.md`, `caixa.md`, `financeiro.md` (PR #2,
  branch `docs/produto-modulos`); `ARCHITECTURE.md` §3 a §7, §10 e §11; `SECURITY.md` §3 e §4; `DESIGN.md` §5 a §9;
  `src/*/AGENTS.md`; spec do item 3 (`specs/20261128-010000-banco-ligacao/spec.md`, branch `feat/banco-ligacao`,
  RG-01 a RG-08 e anexo A); spec do Agendamento (`specs/20261128-020500-agendamento/spec.md`, branch
  `feat/agendamento`). No projeto antigo, "Comanda" é este módulo.

## 1. Pedido do dono (literal)
> "Primeira versão com o núcleo (Agenda, Agendamento, Clientes, Formulários, Catálogo, Checkout, Caixa)" — E3·2, "A".

> "E21-3b" — E21·3, 28/11/2026: cobrança à cliente (link de pagamento, sinal) e vale-presente são recursos do
> Checkout e do Financeiro, **depois do núcleo**. https://claude.ai/code/session_018cV8b9epaQJNqguG5c5Aqb

> "O banco de dados atual é tudo de desenvolvimento, todos os dados são fictícios. O que se tem são as tabelas e regras
> dele. Então use se precisar. E22b" — E22·B, 28/11/2026, https://claude.ai/code/session_018cV8b9epaQJNqguG5c5Aqb

Lista candidata aprovada (E21, `docs/produto/checkout.md`): comanda por atendimento e venda avulsa · etapas revisar,
pagar, concluído · várias formas no mesmo pagamento · desconto, gorjeta e taxa · usar crédito da cliente · reembolso
· comprovante interno sem valor fiscal · cobrança por link e sinal.

## 2. Primeira versão (mínima) e depois
| Recurso candidato | Primeira versão | Motivo |
|---|---|---|
| Checkout de um agendamento | **sim** | é o núcleo do módulo |
| Etapas Revisar, Pagar, Concluído | **sim** | `DESIGN.md` §6 ("Checkout", "Pagar <valor>") |
| Várias formas no mesmo pagamento, registradas à mão | **sim** | sem processador; a recepção anota o que a cliente pagou |
| Desconto | conforme **E31·1** | dinheiro: decisão do dono |
| Estorno (reembolso) total | **sim**, conforme **E31·3** | sem ele um erro de registro não se corrige |
| Venda avulsa (sem agendamento) | depois | precisa de produtos e Estoque (depois do núcleo) |
| Gorjeta e taxa | depois | gorjeta vai para comissões (Financeiro, depois); taxa de cartão vem com a integração |
| Crédito da cliente, saldo devedor, pagamento parcial | depois | saldo da cliente é Clientes/Financeiro, depois (spec de Clientes) |
| Troco calculado | depois | na primeira versão registra-se o valor que fica |
| Estorno parcial | depois | o total cobre o erro de registro; parcial pede regra por item |
| Comprovante interno (imprimir, enviar) | depois | envio passa pela fila de mensagens (depois); a tela Concluído mostra o resumo |
| Ficha que "Bloqueia o checkout" | depois | spec de Formulários (depois) |
| Link de pagamento, sinal, vale-presente | depois | E21·3·B |
| Integração com processador de pagamento | depois | Engenheiro de integrações, spec própria (`ARCHITECTURE.md` §10) |

## 3. Quem usa
Dona e recepção (`docs/produto/checkout.md`); a profissional e o estorno seguem a **E31·3**.

## 4. Telas e estados (nomes do `DESIGN.md`)
| Tela | Computador (1440) | Celular (390) |
|---|---|---|
| Entrada | botão "Checkout" no painel do agendamento (hoje desativado, spec do Agendamento); depois de pago, vira "Ver checkout" (`DESIGN.md` §6) | igual |
| **1 Revisar** | no painel à direita de 480 px: itens (serviço, preço), "Adicionar" serviço do Catálogo, ⋮ da linha para tirar; desconto (E31·1); rodapé "Total ▴ valor" (`DESIGN.md` §5) | tela sem barra; rodapé com "Total ▴ valor" e o botão do rodapé (`DESIGN.md` §5) |
| **2 Pagar** | linhas forma + valor; "Adicionar" outra forma; falta pagar à vista; botão preto "Pagar <valor>", ativo só quando a soma fecha o total | igual, ‹ volta a Revisar |
| **3 Concluído** | resumo: itens, desconto, total, formas e valores, quem fechou e quando; "Fechar" | igual |
| **Ver checkout** | o resumo do Concluído; ⋮ com o estorno (E31·3), que pede motivo e a janelinha de confirmação (`DESIGN.md` §8) | igual |

**Estados** (`DESIGN.md` §8): vazio (agendamento sem serviço: "Ainda não há serviços" + "Adicionar serviço") ·
carregando (linhas cinza depois de 0,3 s, anunciado ao leitor) · erro ("Tentar de novo"; mensagens próprias para
"soma diferente do total", "agendamento já tem checkout", "sem permissão" e, se E31·2·A, "abra o caixa") · sucesso
(aviso embaixo, sem "Desfazer": desfaz-se pelo estorno).

**Nomes que faltam no `DESIGN.md` §6** (vão à ficha visual, etapa 6, e entram no `DESIGN.md` antes de construir):
avançar de Revisar para Pagar; o nome do estorno no ⋮; os nomes das formas de pagamento; o campo de desconto.

## 5. Requisitos funcionais
| ID | Requisito | Fonte |
|---|---|---|
| RF-01 | Abrir o checkout de um agendamento nos status Chegou, Iniciado ou Concluído; nunca em Reservado, Confirmado, Ausência ou Cancelado. | Assumption 1 |
| RF-02 | Os itens começam com os serviços do agendamento, ao preço atual do Catálogo; pode-se tirar um item ou adicionar outro serviço **ativo** do Catálogo. Mudar itens do checkout não muda o agendamento. | candidata; Assumption 2 |
| RF-03 | Cada item guarda nome e preço **do momento do pagamento** (cópia); mudar o Catálogo depois não muda checkout pago. | regra contábil; Assumption 3 |
| RF-04 | O preço do item não se edita na tela; ajuste de valor só pelo desconto (E31·1). | Assumption 4 |
| RF-05 | **Total** = soma dos itens − desconto; desconto entre 0 e a soma dos itens; o total é maior que zero (cortesia fica para depois). | E31·1; RN-01 a RN-04 |
| RF-06 | **Pagar:** uma ou mais linhas (até 5), cada uma com forma (lista da **E31·2**) e valor maior que zero; a soma das linhas é **igual** ao total, nem mais nem menos. | candidata; RN-05 |
| RF-07 | Nada é gravado antes de "Pagar <valor>". Ao pagar, itens, desconto, total e pagamentos são gravados **de uma vez** (tudo ou nada) e o checkout nasce **Pago**. | ASVS V11.1.6 (ação atômica); Assumption 5 |
| RF-08 | **Um checkout por agendamento:** um agendamento tem no máximo um checkout Pago; um segundo pedido é recusado com "agendamento já tem checkout". | pedido do papel que lançou; RNF-02 |
| RF-09 | Checkout Pago não se altera nem se apaga, por ninguém e por nenhuma via; corrige-se só pelo estorno. | ASVS V11.1 (regra de negócio); Assumption 6 |
| RF-10 | **Estorno total:** quem a E31·3 permite estorna um checkout Pago, com motivo obrigatório (5 a 300 caracteres; o campo avisa para não escrever dado de saúde); o checkout vira **Estornado**, guardando total, pagamentos, motivo, quem e quando. Estornado não volta a Pago. | candidata (reembolso); E31·3 |
| RF-11 | Depois do estorno, o agendamento pode ter um checkout novo (para refazer o registro certo). | Assumption 7 |
| RF-12 | **Caixa:** a ligação de cada pagamento e de cada estorno com o caixa aberto segue a **E31·2**. | pedido do papel que lançou; `docs/produto/caixa.md` |
| RF-13 | Permissão por papel para fechar, dar desconto, ver e estornar conforme a **E31·3**; o estúdio vem da sessão. | `ARCHITECTURE.md` §4 e §6 |
| RF-14 | Fechar e estornar passam pelas 6 portas e ficam no registro (porta 6): ação, valores, quem e quando, **sem** nome de cliente, telefone ou dado de saúde. | `ARCHITECTURE.md` §4 e §7 |
| RF-15 | Valores mostrados na moeda e no formato do estúdio; o checkout guarda a moeda (código ISO 4217) com que foi pago. | `ARCHITECTURE.md` §11; ISO 4217 |
| RF-16 | **Plano B:** enquanto o Catálogo não tiver preço, ou o Caixa não existir, a parte que falta aparece "em desenvolvimento" (`DESIGN.md` §8) e os testes usam dados de exemplo locais, fictícios, escritos do zero (RG-07). | `DESIGN.md` §8; item 3 RG-07 |

### Regras de dinheiro (verificáveis, em `src/domain`)
| ID | Regra |
|---|---|
| RN-01 | Todo valor é **número inteiro na menor unidade da moeda** (centavos); nunca número com vírgula flutuante, nem na tela, nem no servidor, nem no banco. |
| RN-02 | Moedas de uso têm 2 casas (EUR, BRL, USD); moeda com outro número de casas é recusada na primeira versão. |
| RN-03 | Desconto em porcentagem (se E31·1·B): valor = soma × % , arredondado **meio para cima** à menor unidade (ex.: 10 % de 3,35 = 0,335 → 0,34); o desconto em valor não se arredonda. |
| RN-04 | Desconto > soma, desconto < 0, porcentagem fora de 0 a 100 ou total ≤ 0: recusados. |
| RN-05 | Soma dos pagamentos ≠ total: recusado; o servidor recalcula o total a partir dos preços e não confia no total vindo da tela. |
| RN-06 | Limites por valor: preço, desconto e pagamento até 1.000.000,00 na moeda (100.000.000 centavos); acima disso, recusado. |

**Estados do checkout:** (não existe antes de pagar) → **Pago** → **Estornado** (final).

## 6. Requisitos não funcionais
| ID | Requisito | Fonte |
|---|---|---|
| RNF-01 | WCAG 2.2 AA: valores e estados com palavra (Pago, Estornado), toque 44/40, foco visível, nada só por cor. | `DESIGN.md` §9 |
| RNF-02 | Toque duplo, repetição de rede ou duas pessoas pagando o mesmo agendamento ao mesmo tempo: grava-se **um** checkout; a repetição do mesmo pedido devolve o mesmo resultado (chave de idempotência). | ASVS V11.1.6; RF-08 |
| RNF-03 | Estorno repetido (duplo toque, rede) estorna uma vez só. | ASVS V11.1.6 |
| RNF-04 | Nenhum dado pessoal ou de saúde em URL, registro de erro ou notificação; o checkout abre pelo id do agendamento. | `ARCHITECTURE.md` §7 |
| RNF-05 | Textos nos três idiomas (pt, es, en), pela estrutura de idiomas do item 4. | E3·1; `ARCHITECTURE.md` §11 |
| RNF-06 | Limite de idas ao banco por tela; lista de serviços para adicionar paginada. | `ARCHITECTURE.md` §5 e §11 |

## 7. Tabelas (do anexo A do item 3) · sugestão para o Engenheiro de dados decidir no plano (RG-02)
Lido só para entender (E22·B, nada copiado): `crm-agenda/supabase/migrations/` `20260601000006_finance.sql`,
`20260610_002_finance_sales.sql`, `20260613_009_checkout_support.sql`, `20261030100000_sales_number_and_paid_at.sql`,
`20261030130000_refund_sale_atomic.sql`, `20261031200000_partial_refund.sql`, `20261031600000_cash_sessions.sql`
(cabeçalhos e `create table`; funções lidas só no começo).

| Tabela (antigo) | Sugestão | Motivo |
|---|---|---|
| `sales` | **reescrever** | antigo usa `numeric(10,2)` (RN-01 pede inteiro em centavos), copia `client_name` (dado pessoal duplicado), tem estados de rascunho e parcial (fora da primeira versão), gorjeta e saldo (depois) |
| `sale_items` | **reescrever** | só serviço na primeira versão; sem produto, pacote, plano e "coberto por pacote" |
| `sale_payments` | **reescrever** | formas da E31·2; sem vale-presente e crédito da cliente (depois); ligação com o caixa conforme E31·2 |
| `sale_refunds` | **reescrever** | estorno total com motivo e chave de idempotência (a ideia do antigo serve); sem fidelidade, pacotes, estoque e crédito |
| `checkout_requests` | **reescrever** ou trocar por chave única | serve o RNF-02; o Engenheiro de dados escolhe a forma, com ADR |
| `sale_partial_refunds` | **descartar** (primeira versão) | estorno parcial é depois |
| `sale_counters` | **descartar** (primeira versão) | número da comanda não aparece no `DESIGN.md`; volta com o comprovante |
| `transactions` | **adiada** (Caixa e Financeiro) | lançamento financeiro geral; a spec do Caixa decide como lê os pagamentos |
| `gift_cards`, `appointment_deposits` | **descartar** nesta spec | vale-presente e sinal: E21·3·B |

Regras que valem (RG-04): `org_id` obrigatório, trava RLS pela função de checagem do item 3, índice por `org_id` e
teste de isolamento em cada tabela. Sugestões ao Engenheiro de dados: valores em inteiro de 64 bits com checagem
(`>= 0`, total = soma − desconto) no banco; índice único parcial (um Pago por agendamento); itens e pagamentos sem
alteração nem exclusão depois de gravados; gravação e estorno numa só transação com a sessão da pessoa (sem chave de
serviço). A forma exata é decisão dele, com ADR.

## 8. Critérios de aceite (verificáveis)
| ID | Critério | Prova |
|---|---|---|
| CA-01 | RN-01 a RN-06: total, desconto em valor e em %, arredondamento meio para cima (casos de borda .xx5), limites e recusas. | unidade (`src/domain`) |
| CA-02 | Soma dos pagamentos igual ao total aceita; 1 centavo a mais ou a menos recusado; até 5 linhas; linha com valor 0 recusada. | unidade e servidor |
| CA-03 | O servidor ignora total e preço vindos da tela e recalcula pelo Catálogo; preço do Catálogo mudado depois não muda checkout Pago. | teste de servidor |
| CA-04 | Status do agendamento: checkout aceito em Chegou, Iniciado, Concluído; recusado nos outros. | unidade |
| CA-05 | Segundo checkout Pago para o mesmo agendamento recusado; duas gravações simultâneas: só uma; mesmo pedido repetido: mesmo resultado; estorno repetido: um só. | teste de banco na CI |
| CA-06 | Checkout Pago, itens e pagamentos não se alteram nem se apagam (nem com a sessão da dona); só o estorno muda o estado. | teste de banco na CI |
| CA-07 | Estorno: exige motivo; Pago → Estornado; Estornado não volta; depois dele, checkout novo é aceito (RF-11). | unidade e banco |
| CA-08 | Caixa conforme a E31·2 (com caixa aberto, sem caixa aberto, estorno). | teste de servidor e de banco |
| CA-09 | O estúdio A não lê, cria, altera nem apaga checkout, item, pagamento ou estorno do estúdio B; sem login ou sem papel, nada. | teste de isolamento na CI (molde do item 3) |
| CA-10 | Permissão por papel conforme E31·3 (cada papel × fechar, desconto, ver, estornar). | teste de servidor e de banco |
| CA-11 | Fechar e estornar geram registro (porta 6) com valores e sem dado pessoal no texto; URL só com id. | teste automático e revisão do Engenheiro de segurança |
| CA-12 | Ponta a ponta em 390 e 1440: fechar com duas formas, erro de soma, "Ver checkout", estorno com janelinha. | Playwright (`e2e/`) |
| CA-13 | Estados vazio, carregando, erro e sucesso presentes; checklist do `DESIGN.md` §10 sem falha. | e2e e Revisor de design |
| CA-14 | Cada tabela do §7 tem ADR com saída, motivo, norma e o papel que conferiu; nada do antigo copiado sem ADR. | `docs/adr/` |
| CA-15 | Nada aplicado no banco remoto pela IA; banco só local até a "Aprovação do merge". | histórico da CI |
| CA-16 | Revisores do tipo (incluindo Auditor de risco e Engenheiro de segurança) sem "Bloqueia", veredito do QA e conferência do dono na prévia. | relatórios no PR |

## 9. Dependências
- **Item 2** (CI, app vazio) · **item 3** (estúdio, papéis, função de checagem, molde do teste) · **item 4** (design
  system no código).
- **Agendamento:** status (RF-01), painel e botão "Checkout"; serviços do agendamento.
- **Catálogo** (spec sendo escrita em paralelo): serviço ativo, **preço em centavos** e moeda do estúdio. Se o
  Catálogo guardar preço de outro jeito (faixa, "a partir de", preço por profissional), esta spec volta ao dono.
- **Caixa** (spec própria): o caixa aberto, se E31·2·A ou B; sem ele, vale o plano B (RF-16).
- **Clientes:** só o nome da cliente mostrado no resumo (lido de Clientes, não copiado).

## 10. Dúvidas ao dono (máx. 3; todas de dinheiro ou acesso)
**E31·1 · Desconto no checkout** (dinheiro)
- **E31·1·A:** sem desconto na primeira versão; cobra-se o preço do Catálogo.
- **E31·1·B:** um desconto no total da conta, em valor ou em porcentagem, nunca maior que a conta.
- **E31·1·C:** como B, e também desconto por serviço.
- **Recomendo B:** cobre o caso comum (cliente fiel, promoção) com uma regra só e testável; C entra depois sem mudar
  os dados. Desfaz-se tirando o campo. Gorjeta e taxa ficam para depois em todas as opções.

**E31·2 · Formas de pagamento e o Caixa** (dinheiro)
- Formas na primeira versão (registro à mão, sem maquininha ligada): Dinheiro · Cartão de débito · Cartão de crédito ·
  Pix · Bizum · Transferência · Outra. O estúdio esconder as que não usa vem com Ajustes (depois).
- **E31·2·A:** pagamento em **dinheiro** só com caixa aberto e entra nele; as outras formas entram no caixa aberto se
  houver, sem exigir; o estorno em dinheiro sai do caixa aberto.
- **E31·2·B:** qualquer forma só com caixa aberto.
- **E31·2·C:** sem ligação com o Caixa na primeira versão.
- **Recomendo A:** a gaveta só confere se todo dinheiro passar pelo caixa, sem travar quem recebe por cartão ou Pix.
  Desfaz-se desligando a exigência; os registros ficam.

**E31·3 · Quem fecha e quem estorna** (acesso e dinheiro)
- **E31·3·A:** dona e recepção fecham (e dão desconto); só a dona estorna; a profissional não fecha.
- **E31·3·B:** dona e recepção fecham e estornam.
- **E31·3·C:** como A, e a profissional fecha os próprios atendimentos.
- **Recomendo A:** estorno tira dinheiro; menor privilégio e separação de funções (OWASP ASVS V4; ISO 31000).
  Desfaz-se mudando a permissão do papel.

## 11. Assumptions (decisões do papel, à vista na aprovação; recuse pelo número)
1. Checkout só em Chegou, Iniciado ou Concluído; pagar não muda o status do agendamento na primeira versão.
2. Mudar itens no checkout não muda o agendamento (o agendamento guarda o que foi marcado; o checkout, o que foi pago).
3. Itens guardam cópia de nome e preço no momento do pagamento.
4. Preço do item não se edita; só o desconto ajusta (E31·1).
5. Sem rascunho gravado: nada fica salvo antes de "Pagar <valor>"; sair no meio descarta.
6. Erro de registro se corrige por estorno e checkout novo; nunca por edição.
7. Depois do estorno, o mesmo agendamento pode ter checkout novo.
8. Até 5 formas por pagamento; limite de 1.000.000,00 por valor (RN-06).
9. Tabelas: as sugestões do §7 são do Engenheiro de dados decidir no plano, com ADR.

## 12. Fora de escopo
- Tudo marcado "depois" no §2, em especial link de pagamento, sinal e vale-presente (E21·3·B) e a integração com
  processador de pagamento (Engenheiro de integrações, spec própria, com aviso assinado e processado uma vez,
  `ARCHITECTURE.md` §10).
- **Documento fiscal** (nota fiscal no Brasil, factura na Espanha): o sistema **não** emite; o resumo não tem valor
  fiscal. Obrigação fiscal do estúdio fica fora do sistema na primeira versão.
- Telas e regras do Caixa (abrir, sangria, fechar), relatórios e comissões (Financeiro).
- Avisos à cliente (WhatsApp, e-mail) e o sininho.
