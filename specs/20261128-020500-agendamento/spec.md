# Spec · Agendamento (núcleo): criar, remarcar, cancelar e mudar o status

- **Status:** Draft
- **Aprovação do dono:** (pendente)
- **Aprovação do merge:** (pendente)
- **Item da fila:** 5 (`docs/BACKLOG.md`), módulo Agendamento do núcleo (E3·2), em paralelo por ordem do dono (E22·B)
- **Branch:** `feat/agendamento` (a partir da `previas`), construção em PR de rascunho; nada é juntado sem o dono (E22·B)
- **Tipo:** Tela, com Banco e Código (`docs/guias/processo-sdd.md` §3) · **Revisores:** Revisor de design,
  Engenheiro de dados (quem não fez), Auditor de risco e Engenheiro de segurança (acesso), Revisor de código e QA
- **Escrito por:** Analista de requisitos · **Norma:** IEEE 29148 e BABOK
- **Fontes:** E3·2; E21; E21·3; E22·B; `docs/produto/agendamento.md` (PR #2); `ARCHITECTURE.md` §3 a §7 e §11;
  `DESIGN.md` §5 a §9; `src/*/AGENTS.md`; spec do item 3 (`specs/20261128-010000-banco-ligacao/spec.md`, branch
  `feat/banco-ligacao`, RG-01 a RG-08 e anexo A).

## 1. Pedido do dono (literal) e limite com a Agenda
> "Primeira versão com o núcleo (Agenda, Agendamento, Clientes, Formulários, Catálogo, Checkout, Caixa)" — E3·2, "A".

> "O banco de dados atual é tudo de desenvolvimento, todos os dados são fictícios. O que se tem são as tabelas e regras
> dele. Então use se precisar. E22b" — E22·B, 28/11/2026, https://claude.ai/code/session_018cV8b9epaQJNqguG5c5Aqb

Lista candidata aprovada (E21, `docs/produto/agendamento.md`): novo agendamento em etapas (cliente, serviços, data e
hora, conferência) · atendimento de balcão sem reserva · remarcar · status · notas · formulários do atendimento ·
atendimento repetido · linha do tempo do atendimento · política de cancelamento e falta.

| Módulo | Cuida de | Não cuida de |
|---|---|---|
| **Agenda** (spec própria, `feat/agenda`) | ver e organizar o calendário: visões, filtros, cartões, bloqueios de horário, lista de espera, arrastar | as regras de um agendamento |
| **Agendamento** (esta spec) | criar, remarcar, cancelar e mudar o status de **um** agendamento; a regra de conflito | desenhar o calendário |

A Agenda abre o "Novo agendamento" e o painel do agendamento, e o arrastar da Agenda usa a regra de remarcar desta spec
(RF-05 e RF-06). O "Bloqueio de horário" (`DESIGN.md` §5) é da Agenda e é sempre de uma profissional (RF-07 e RN-04 da spec da Agenda).
O arrastar e a lista de espera ficam **depois** (a Agenda não os tem na primeira versão).

## 2. Primeira versão (mínima) e depois
| Recurso candidato | Primeira versão | Motivo |
|---|---|---|
| Novo agendamento em etapas | **sim** | é o núcleo do módulo |
| Remarcar | **sim** | sem ele um erro de horário obriga a cancelar |
| Status (com cancelar) | **sim** | os status já estão no `DESIGN.md` §5 |
| Atendimento de balcão sem reserva | depois | depende do Checkout e da regra de horário passado |
| Notas | depois | texto livre pode receber dado de saúde; entra junto da spec de Formulários (`ARCHITECTURE.md` §7) |
| Formulários do atendimento | depois | depende da spec de Formulários e da ficha de saúde cifrada (E5·2, E21·2) |
| Atendimento repetido | depois | regras de série (editar uma ou todas) pedem spec própria |
| Linha do tempo do atendimento | depois (a tela) | o histórico de status já é gravado na primeira versão (RF-09) |
| Política de cancelamento e falta | depois | mexe com dinheiro (multa, sinal): E21·3 |

## 3. Quem usa
Dona, recepção e profissional (`ARCHITECTURE.md` §6). O que a profissional vê e faz segue as respostas da E26·1 e da
E26·2 da spec da Agenda (branch `feat/agenda`), aplicadas também aos agendamentos; quem é profissional é a E26·3.

## 4. Telas e estados (nomes do `DESIGN.md`)
| Tela | Computador (1440) | Celular (390) |
|---|---|---|
| **Novo agendamento** | aberto pelo botão "Novo agendamento" da Agenda; painel à direita de 480 px (`DESIGN.md` §8) | aberto pelo **Agendar** da barra de baixo; tela sem barra, com ‹ voltar uma etapa e o botão do rodapé "Salvar" (`DESIGN.md` §5 e §6) |
| Etapas | 1 Cliente (campo "Buscar cliente") · 2 Serviços (escolher entre os serviços do Catálogo; cadastrar serviço é do Catálogo) · 3 Data e hora (profissional, data, hora) · 4 Conferência ("Salvar") | igual |
| **Painel do agendamento** | painel à direita de 480 px: botão de status "ícone + nome ▾"; ⋮ do topo com as ações (remarcar, "Cancelar agendamento"); "Checkout" desativado com "em desenvolvimento" até a spec do Checkout (`DESIGN.md` §8) | igual, com as ações no ⋮ do topo do painel (`DESIGN.md` §5) |
| Remarcar | dentro do painel: profissional, data e hora; "Salvar" e "Cancelar" | igual |

**Estados de toda tela** (`DESIGN.md` §8): vazio ("Ainda não há clientes" / "Ainda não há serviços", com o
"Adicionar <coisa>" de contorno, conforme E27·1) · sem resultado (o que foi buscado e "Limpar filtros") · carregando
(linhas cinza depois de 0,3 s, anunciado ao leitor) · erro ("Tentar de novo"; no conflito, a mensagem diz que o
horário está ocupado, sem nome de cliente) · sucesso (aviso embaixo; "Desfazer" na troca de status, RF-08).

**Nomes que faltam no `DESIGN.md` §6** (vão à ficha visual, etapa 6, e entram no `DESIGN.md` antes de construir):
o botão de avançar etapa e o nome da ação de remarcar no ⋮.

## 5. Requisitos funcionais
| ID | Requisito | Fonte |
|---|---|---|
| RF-01 | Criar agendamento com: uma cliente, um ou mais serviços do Catálogo, uma profissional, data e hora de início. | candidata; E3·2 |
| RF-02 | O fim é o início mais a soma das durações dos serviços (do Catálogo), feitos em sequência pela mesma profissional. | candidata; Assumption 4 |
| RF-03 | Só se escolhe serviço ativo do Catálogo e uma profissional do estúdio (quem é profissional: E26·3 da Agenda); se o Catálogo tiver "quem faz cada serviço", vale essa regra. | dependência Catálogo e Agenda |
| RF-04 | **Conflito:** não se grava agendamento cujo intervalo [início, fim) cruza o de outro da mesma profissional com status diferente de Cancelado e Ausência, nem um bloqueio de horário dessa profissional (Agenda). Sem expediente na primeira versão, só bloqueios e agendamentos contam. Com E27·2·B, dona e recepção podem marcar mesmo assim. | E27·2; dependência Agenda |
| RF-05 | **Remarcar:** muda profissional, data e hora, com a mesma regra de conflito (ignorando o próprio agendamento); só nos status Reservado e Confirmado; Confirmado volta a Reservado. | candidata; Assumption 3 |
| RF-06 | Depois: quando a Agenda tiver o arrastar, ele chama a mesma regra do RF-05; não há segunda regra. | §1 |
| RF-07 | **Status e transições** (status do `DESIGN.md` §5, menos "Bloqueio de horário"): o agendamento nasce Reservado; só valem as transições da tabela abaixo; Concluído, Ausência e Cancelado são finais na primeira versão. | `DESIGN.md` §5; Assumption 1 e 2 |
| RF-08 | Troca para Cancelado ("Cancelar agendamento") ou Ausência pede a janelinha de confirmação; as outras trocas saem com aviso e "Desfazer", que só volta ao status imediatamente anterior. | `DESIGN.md` §6 e §8 |
| RF-09 | Toda troca de status grava histórico: status, quem e quando. | candidata (linha do tempo) |
| RF-10 | Toda criação, remarcação e troca de status passa pelas 6 portas e fica no registro (porta 6), sem nome, telefone ou dado de saúde no texto. | `ARCHITECTURE.md` §4 e §7 |
| RF-11 | Permissão por papel: dona e recepção em todos os agendamentos do estúdio; a profissional conforme a E26·1 e a E26·2 da Agenda. | `ARCHITECTURE.md` §6; E26·1; E26·2 |
| RF-12 | Horários no fuso do estúdio; o estúdio vem da sessão, nunca do pedido. | `ARCHITECTURE.md` §4 e §11 |
| RF-13 | Não se cria nem se remarca para início já passado (na primeira versão). | Assumption 5 |
| RF-14 | Cliente nova na etapa 1 conforme E27·1. | E27·1 |
| RF-15 | **Plano B:** enquanto Clientes ou Catálogo não existirem, a etapa correspondente aparece "em desenvolvimento" (`DESIGN.md` §8) e os testes usam dados de exemplo locais, fictícios, escritos do zero (RG-07). | `DESIGN.md` §8; item 3 RG-07 |

**Transições (RF-07):**

| De | Para |
|---|---|
| Reservado `clock` | Confirmado, Chegou, Ausência, Cancelado |
| Confirmado `thumbs-up` | Chegou, Ausência, Cancelado |
| Chegou `door-open` | Iniciado, Cancelado |
| Iniciado `play` | Concluído |
| Concluído · Ausência · Cancelado | nenhuma (finais) |

## 6. Requisitos não funcionais
| ID | Requisito | Fonte |
|---|---|---|
| RNF-01 | WCAG 2.2 AA: status com ícone e nome (no leitor), toque 44/40, foco visível, nada só por cor. | `DESIGN.md` §9 |
| RNF-02 | Duas pessoas marcando o mesmo horário ao mesmo tempo: só uma grava; a outra recebe o erro de conflito. | RF-04; ASVS V11.1.6 (ação atômica) |
| RNF-03 | Listas da etapa 1 e 2 paginadas; limite de idas ao banco por tela. | `ARCHITECTURE.md` §5 e §11 |
| RNF-04 | Nenhum dado pessoal ou de saúde em URL, registro de erro ou notificação (o painel abre pelo id, não pelo nome). | `ARCHITECTURE.md` §7 |
| RNF-05 | Textos nos três idiomas de uso (pt, es, en), pela estrutura de idiomas do item 4. | E3·1; `ARCHITECTURE.md` §11 |

## 7. Tabelas (do anexo A do item 3) · sugestão para o Engenheiro de dados decidir no plano (RG-02)
Lido só para entender (E22·B, nada copiado): `crm-agenda/supabase/migrations/` (`appointments`, transições e
conflito em `20261030220000_appointment_status_arrived.sql` e `20260614_002_agenda_atomic_appointment_rpcs.sql`).

| Tabela (antigo) | Sugestão | Motivo |
|---|---|---|
| `appointments` | **reescrever** | status do antigo ("Agendado", "Pago", "Pago Parcial") não batem com o `DESIGN.md`; colunas de dinheiro (`total`, `discount`, `tip`) são do Checkout (E21·3); nomes copiados (`client_name`, `staff_name`), cor, recorrência e ficha ligada ficam fora da primeira versão |
| `appointment_items` | **reescrever** | só serviço, duração e ordem; produto, pacote, plano, preço e custo ficam para Catálogo e Checkout |
| `appointment_status_history` | **reescrever** | serve o RF-09; sem o nome copiado (`changed_by_name`) |
| `appointment_counters` | **descartar** (primeira versão) | número do agendamento não aparece no `DESIGN.md`; volta se o Checkout pedir |
| `appointment_deposits` | **descartar** nesta spec | sinal é E21·3 (depois do núcleo) |

Regras que valem (RG-04): `org_id` obrigatório, trava RLS pela função de checagem do item 3, índice por `org_id` e
teste de isolamento em cada tabela. Como garantir o RNF-02 no banco é decisão do Engenheiro de dados, com ADR.

## 8. Critérios de aceite (verificáveis)
| ID | Critério | Prova |
|---|---|---|
| CA-01 | Cada transição da tabela do RF-07 é aceita, e cada par fora dela é recusado. | unidade (`src/domain`) |
| CA-02 | Conflito: cruzamento de intervalos recusado; encostar (fim = início do outro) aceito; Cancelado e Ausência não ocupam; bloqueio ocupa; remarcar ignora o próprio. | unidade |
| CA-03 | Fim = início + soma das durações; início no passado recusado; fuso do estúdio respeitado (inclui troca de horário de verão). | unidade |
| CA-04 | Duas gravações simultâneas no mesmo horário: só uma grava. | teste de banco na CI |
| CA-05 | O estúdio A não lê, cria, altera nem apaga agendamento, item ou histórico do estúdio B; sem login ou sem papel, nada. | teste de isolamento na CI (molde do item 3) |
| CA-06 | Permissão por papel conforme RF-11, E26·1 e E26·2 (cada papel × cada ação). | teste de servidor e de banco |
| CA-07 | Toda troca de status gera uma linha de histórico e um registro (porta 6), sem dado pessoal no texto. | teste automático |
| CA-08 | Ponta a ponta em 390 e 1440: criar nas 4 etapas, remarcar, trocar status com "Desfazer", cancelar com a janelinha, e o erro de conflito. | Playwright (`e2e/`) |
| CA-09 | Estados vazio, sem resultado, carregando, erro e sucesso presentes; checklist do `DESIGN.md` §10 sem falha. | e2e e Revisor de design |
| CA-10 | Nenhum dado pessoal na URL do painel nem nos registros. | teste e revisão do Engenheiro de segurança |
| CA-11 | Cada tabela do §7 tem ADR com saída, motivo, norma e o papel que conferiu; nada do antigo copiado sem ADR. | `docs/adr/` |
| CA-12 | Nada aplicado no banco remoto pela IA; banco só local até a "Aprovação do merge". | histórico da CI |
| CA-13 | Sem Clientes ou Catálogo, a etapa mostra "em desenvolvimento" e o e2e passa com os dados de exemplo locais (RF-15). | e2e |
| CA-14 | Revisores do tipo sem "Bloqueia", veredito do QA e conferência do dono na prévia. | relatórios no PR |

## 9. Dependências
- **Item 2** (CI, app vazio, Spec Kit) · **item 3** (estúdio, membros, papéis, função de checagem, molde do teste de
  isolamento) · **item 4** (design system no código).
- **Agenda:** quem é profissional (E26·3), acesso da profissional (E26·1, E26·2), bloqueios; o botão "Novo
  agendamento" e a abertura do painel. A Agenda não tem expediente na primeira versão (`staff_shifts` adiada), então a
  regra de horário usa só bloqueios e agendamentos.
- **Clientes:** a tabela e a busca da cliente (E27·1 depende dela). **Catálogo:** serviços e duração. Sem eles, vale
  o plano B (RF-15).
- **Checkout:** só o botão "Checkout" (desativado até a spec dele). **E22·B:** leitura do antigo e ADR por tabela.

## 10. Dúvidas ao dono (máx. 3)
O que a profissional pode fazer: respondido pela E26·1 e pela E26·2 da spec da Agenda (não se pergunta de novo).

**E27·1 · Cliente nova durante o agendamento** (dado de cliente)
- **E27·1·A:** na etapa Cliente, "Adicionar cliente" cadastra ali só nome e telefone; o resto se completa em Clientes.
- **E27·1·B:** só se escolhe cliente já cadastrada; cadastro só em Clientes.
- **Recomendo A:** evita sair do agendamento e pede o mínimo de dados (RGPD art. 5(1)(c)). Desfaz-se tirando o botão.

**E27·2 · Horário ocupado** (tela e acesso)
- **E27·2·A:** o sistema sempre impede marcar em horário ocupado ou bloqueado.
- **E27·2·B:** avisa, e dona e recepção podem marcar mesmo assim (encaixe), com registro.
- **Recomendo A na primeira versão:** regra simples e testável; o B entra depois sem mudar os dados.

## 11. Assumptions (decisões do papel, à vista na aprovação; recuse pelo número)
1. Todo agendamento nasce **Reservado** (o status "Agendado" do antigo não existe no `DESIGN.md`).
2. Tabela de transições do RF-07 (Iniciado só vai a Concluído; o engano se corrige pelo "Desfazer").
3. Remarcar só em Reservado e Confirmado; Confirmado volta a Reservado, porque a confirmação era do horário antigo.
4. Uma profissional por agendamento e serviços em sequência; vários profissionais num atendimento fica para depois.
5. Início no passado é recusado na primeira versão (o balcão sem reserva entra depois).
6. Intervalos [início, fim): encostar não é conflito.
7. Tabelas: as sugestões do §7 são do Engenheiro de dados decidir no plano, com ADR.

## 12. Fora de escopo
- Cobrança à cliente, sinal, multa de cancelamento ou falta, preço, desconto e gorjeta (E21·3; Checkout).
- Os recursos marcados "depois" no §2. Visões, filtros, cartões e bloqueios (Agenda); lista de espera e arrastar (depois, nas duas specs).
- Avisos à cliente (WhatsApp, e-mail, lembretes) e o sininho. Reserva online pela cliente (portal, E21·1).
