# Spec · Agenda (primeira versão)

- **Status:** Draft
- **Aprovação do dono:** (pendente)
- **Aprovação do merge:** (pendente)
- **Pasta:** `specs/20261128-020000-agenda/` · **Branch:** `feat/agenda`, empilhada por merge sobre `feat/banco-ligacao`,
  `feat/design-system-codigo` e `feat/entrar-servico` (decisão do Engenheiro de DevOps); construção em PR de
  rascunho, nada é juntado sem o dono (E22·B)
- **Item da fila:** 5 de `docs/BACKLOG.md` (núcleo, um módulo por spec; primeiro da lista: Agenda, E3·2)
- **Tipo:** Tela e Banco (`docs/guias/processo-sdd.md` §3 e §4): ficha visual, aprovação da spec, pedido de merge com
  o link da prévia · **Revisores:** Revisor de design; Engenheiro de dados (quem não fez) e Auditor de risco (banco e
  acesso); Engenheiro de segurança (acesso); QA
- **Escrito por:** Analista de requisitos · **Norma:** IEEE 29148 e BABOK · **Revisa:** Gerente de projeto (etapa 5b)
- **Fontes lidas:** `AGENTS.md`; `ARCHITECTURE.md` §2 a §7 e §11; `DESIGN.md` (inteiro); `docs/guias/processo-sdd.md`;
  `src/*/AGENTS.md`; `docs/produto/agenda.md`, `docs/produto/agendamento.md` e `docs/produto/README.md` (branch
  `docs/produto-modulos`, PR #2, E21); `docs/decisoes/2026-11-27-fundacao.md` (E3·2, E21, E22·B, mesma branch);
  `specs/20261128-010000-banco-ligacao/spec.md` (branch `feat/banco-ligacao`, §5 e anexo A). Do antigo (E22·B, só
  leitura, nada copiado): `crm-agenda/supabase/migrations/` 20260601000004, 20260611_001, 20260619165814 e
  20261030240000. Os quadros de Agenda do canvas (`docs/design/canvas/H6`…`N8`) são histórico e não valem como regra.

## 1. Pedido do dono (literal)
> "A" — E3·2: "Primeira versão com o núcleo (Agenda, Agendamento, Clientes, Formulários, Catálogo, Checkout, Caixa)".

> "O banco de dados atual é tudo de desenvolvimento, todos os dados são fictícios. O que se tem são as tabelas e regras
> dele. Então use se precisar. E22b Bom trabalho e obrigado." — E22·B, 28/11/2026,
> https://claude.ai/code/session_018cV8b9epaQJNqguG5c5Aqb

O módulo, pela E21 (`docs/produto/agenda.md`): "Mostra os horários do estúdio e de cada profissional, para ver o dia
e organizar os atendimentos." Para: dona, recepção, profissional.

## 2. O que é a primeira versão
A tela **Agenda** mostra **um dia** do estúdio em grade de horas, com uma coluna por profissional, os agendamentos
(com o status no cartão) e os bloqueios de horário. Permite trocar de dia, voltar a **Hoje**, escolher quais
profissionais ver (**Equipe N de M**), filtrar e criar, alterar e excluir um **bloqueio de horário único**.
Marcar, abrir e mudar um agendamento é do módulo Agendamento (spec própria); a Agenda só mostra e leva até ele.

### 2.1 Recursos da lista candidata (`docs/produto/agenda.md`)
| Recurso | Primeira versão | Motivo |
|---|---|---|
| visões dia, 3 dias, semana e mês | **só Dia** | é o uso do balcão; as outras no "Dia ▾" como "em desenvolvimento" (`DESIGN.md` §8) |
| status no cartão | **sim** | sem ele a grade não diz o que está acontecendo |
| bloqueio de horário | **só único** | repetido depois |
| conflito de horário | **sim, para bloqueio** | o conflito ao marcar agendamento é da spec do Agendamento |
| filtros | **sim: status e bloqueio** | profissional vai pelo "Equipe N de M"; serviço e etiqueta dependem de Catálogo e Clientes |
| altura das horas | depois | ajuste de conforto |
| lista de espera | depois | botão aparece como "em desenvolvimento" (`DESIGN.md` §7 e §8) |
| arrastar para remarcar | depois | remarcar é do Agendamento |
| resumo do dia | depois | pode envolver valores (dinheiro) |
| exportar e imprimir | depois | "Opções" aparece como "em desenvolvimento" |
| aviso no sininho | depois | depende de notificações e da fila de envios |
| ligação com Google Agenda | depois | integração externa, spec própria |

## 3. Quem usa e o que cada papel vê
| Papel | Vê | Pode |
|---|---|---|
| Dona | a agenda inteira do seu estúdio | ver; bloqueios conforme E26·2 |
| Recepção | a agenda inteira do seu estúdio | ver; bloqueios conforme E26·2 |
| Profissional | conforme E26·1 | conforme E26·2 |
| Sem papel no estúdio ou sem login | nada | nada |

Nenhum papel vê dado de outro estúdio (`ARCHITECTURE.md` §5). O cartão nunca mostra dado de saúde.

## 4. Telas e estados
Só peças, nomes e medidas do `DESIGN.md`. Peça que faltar para no caminho e entra no `DESIGN.md` com o dono primeiro.

**Tela Agenda** (título "Agenda", `DESIGN.md` §6; módulo sem seções, §7).
- **Computador (1440):** barra do topo: título e subtítulo (data do dia) · busca geral · Opções ("em
  desenvolvimento") · **Novo agendamento** (preto, única ação principal) · ajuda · Notificações · Sua conta. Barra da
  grade: Hoje · seta de dia anterior e seguinte · data em pílula com calendário · **Dia ▾** · **Equipe N de M** ·
  **Filtros ▾** · **Lista de espera** ("em desenvolvimento").
- **Celular (390):** cabeçalho com ☰ (abre as visões da Agenda: só Dia ativo), data, Hoje, funil, sininho e Sua conta
  (nível 1); barra de baixo com **Agendar** preto no meio, Agenda atual em azul. Filtros em folha de baixo.
  A disposição das colunas no celular sai da ficha visual (etapa 6).
- **Cartão do agendamento:** hora de início e fim, nome da cliente, serviço, ícone de status (no cartão pequeno só o
  ícone, com o nome no leitor de tela; ícones Lucide do `DESIGN.md` §5). Tocar abre o agendamento (spec do
  Agendamento).
- **Bloqueio na grade:** ícone `lock` e a palavra "Bloqueio", com o motivo se houver.
- **Bloqueio · criar e alterar:** campos profissional*, data*, início*, fim*, motivo; Salvar · Cancelar. Excluir no ⋮,
  em vermelho, com janelinha de confirmação e aviso depois. O ponto de entrada (de onde se abre) sai da ficha visual.

**Estados (`DESIGN.md` §8):** carregando (linhas cinza só depois de 0,3 s, anunciado ao leitor de tela) · vazio (dia
sem agendamento nem bloqueio: grade à vista, "Ainda não há agendamentos neste dia" e a ação do Agendamento) · sem
resultado (filtro esconde tudo: o que foi filtrado e "Limpar filtros") · sem profissional (estúdio sem ninguém que
atende: frase e caminho para a Equipe, "em desenvolvimento" até o módulo existir) · erro (o que houve e "Tentar de
novo") · sucesso (aviso depois de salvar ou excluir bloqueio, com "Desfazer" no excluir).

## 5. Requisitos funcionais
| ID | Requisito | Fonte |
|---|---|---|
| RF-01 | A Agenda abre no dia de hoje, no fuso do estúdio. | `ARCHITECTURE.md` §11 |
| RF-02 | A pessoa troca de dia (anterior, seguinte, calendário) e volta com **Hoje**. | `DESIGN.md` §6 e §7 |
| RF-03 | Há uma coluna por profissional que atende (quem é profissional: E26·3); **Equipe N de M** escolhe quais aparecem; N é o número à vista e M o total. | `DESIGN.md` §6 e §7 |
| RF-04 | A grade mostra os agendamentos e os bloqueios do dia de cada coluna à vista. | `docs/produto/agenda.md` |
| RF-05 | O cartão mostra o status com o ícone do `DESIGN.md` §5 e o nome acessível. | `DESIGN.md` §5 e §9 |
| RF-06 | **Filtros** por status e por bloqueio (mostrar ou esconder), com a pílula de contador de filtros ligados e "Limpar filtros". | `DESIGN.md` §5 e §7 |
| RF-07 | Criar, alterar e excluir bloqueio único de uma profissional, com início e fim no mesmo dia. | `docs/produto/agenda.md` |
| RF-08 | **Novo agendamento** (computador) e **Agendar** (celular) levam ao fluxo do Agendamento; tocar num cartão abre o agendamento. Sem a spec do Agendamento construída, aparecem como "em desenvolvimento". | `DESIGN.md` §5 e §8 |
| RF-09 | Toda ação passa pelas 6 portas; criar, alterar e excluir bloqueio fica no registro (porta 6), sem dado pessoal nem o texto do motivo. | `ARCHITECTURE.md` §4 |

## 6. Regras de negócio (verificáveis)
| ID | Regra |
|---|---|
| RN-01 | O dia vai de 00:00 a 24:00 no fuso do estúdio, inclusive nos dias de troca de horário de verão (23 h ou 25 h). |
| RN-02 | Agendamento ou bloqueio que cruza a meia-noite aparece nos dois dias, cortado na borda. |
| RN-03 | Bloqueio: fim depois do início; mínimo 5 min; início e fim no mesmo dia do estúdio; motivo opcional, até 200 caracteres. |
| RN-04 | Bloqueio não pode sobrepor outro bloqueio nem agendamento ativo (que não seja Cancelado nem Ausência) da mesma profissional; a tela diz o conflito e não salva. Encostar (fim de um = início do outro) não é conflito. |
| RN-05 | Itens sobrepostos na mesma coluna aparecem lado a lado, sem esconder nenhum. |
| RN-06 | Cancelados não aparecem por padrão; o filtro de status os mostra. |
| RN-07 | O estúdio de toda leitura e gravação vem da sessão, nunca do pedido; a profissional do bloqueio tem de ser do mesmo estúdio. |
| RN-08 | A consulta de um dia traz só o dia e as colunas à vista, com teto de itens; passou do teto, a tela avisa em vez de cortar calado. |

## 7. Tabelas
Base da trava (estúdio, membros, papéis, função de checagem) vem do item 3. Cada linha abaixo é **sugestão** do
Analista; quem decide é o Engenheiro de dados no plano, com ADR e revisão de outro papel (E16·1; RG-02 do item 3).

| Tabela (antigo) | Para quê aqui | Sugestão | Motivo |
|---|---|---|---|
| `time_blocks` | bloqueio de horário | **reescrever** | ficam `org_id`, profissional, início, fim, motivo, autor; saem `resource_id`, `location_id`, `repeat_rule` (fora da v1); chave estrangeira com o mesmo estúdio; trava pela função do item 3 (RG-04) |
| `staff_members` | quem aparece como coluna | **descartar** se E26·3·A ou B (usa membros do item 3); **reescrever** se E26·3·C | no antigo leva e-mail, telefone, cor fora do `DESIGN.md` e comissão (dinheiro), que não são da Agenda |
| `staff_shifts` | expediente por dia da semana | **adiada** (módulo Equipe) | sem tela de cadastro na v1 |
| `time_block_types` | tipos de bloqueio | **adiada** | tem `is_paid` (dinheiro) e cor própria; fora da v1 |
| `resources` | salas e equipamentos | **adiada** | fora da v1 |
| `agenda_waitlist` | lista de espera | **adiada** | fora da v1 |
| `appointments` e status | o que a grade mostra | **na spec do Agendamento** | a Agenda só lê |

## 8. Requisitos não funcionais
| ID | Requisito | Fonte |
|---|---|---|
| RNF-01 | Toda tabela nova tem `org_id` obrigatório, RLS, índice por `org_id` e período, e teste de isolamento. | `ARCHITECTURE.md` §5 |
| RNF-02 | A tela de um dia faz um número fixo de idas ao banco, que não cresce com o número de itens (teto no plano). | `ARCHITECTURE.md` §5 e §11 |
| RNF-03 | WCAG 2.2 AA: contraste, toque 44/40, foco visível, status nunca só por cor, grade navegável por teclado. | `DESIGN.md` §9 |
| RNF-04 | Nome de cliente, motivo do bloqueio ou dado de saúde nunca em URL, registro de erro ou notificação; a URL só leva a data. | `ARCHITECTURE.md` §7 |
| RNF-05 | Todos os textos da Agenda em português, espanhol e inglês, por arquivo de idioma; data e hora no formato do idioma e no fuso do estúdio. | E3·1; `ARCHITECTURE.md` §11 |

## 9. Critérios de aceite
| ID | Critério | Prova |
|---|---|---|
| CA-01 | RN-01 a RN-06 e RN-08 têm teste em `src/domain`, inclusive dia de 23 h e de 25 h, meia-noite e sobreposição encostada. | unidade, CI verde |
| CA-02 | O estúdio A não lê, cria, altera nem apaga bloqueio do estúdio B; bloqueio com profissional de outro estúdio é recusado. | isolamento, CI verde |
| CA-03 | Sem login e sem papel no estúdio: nada é lido nem gravado; cada papel lê e grava só o que a §3 (após E26·1 e E26·2) permite. | teste de banco e do servidor, CI verde |
| CA-04 | Estúdio vindo no pedido é ignorado. | teste do servidor |
| CA-05 | Em 390 e 1440: abre em hoje; troca de dia e Hoje; Equipe N de M; filtros e "Limpar filtros"; criar, alterar, conflito recusado e excluir bloqueio com "Desfazer". | e2e, CI verde |
| CA-06 | Em 390 e 1440: estados carregando, vazio, sem resultado, sem profissional e erro aparecem como na §4. | e2e |
| CA-07 | Uma só peça preta de ação por tela; nenhuma peça, cor ou nome fora do `DESIGN.md`. | checklist §10 do `DESIGN.md`, Revisor de design |
| CA-08 | Checagem automática de acessibilidade sem falha nas duas larguras e status com nome acessível. | e2e |
| CA-09 | Nenhuma URL, registro ou erro contém nome de cliente ou motivo de bloqueio. | teste e revisão do Engenheiro de segurança |
| CA-10 | Cada tabela da §7 tem ADR com saída, motivo, norma e quem conferiu; migration só para as copiadas ou reescritas. | `docs/adr/` × PR |
| CA-11 | Nada aplicado no banco remoto; banco só local até a "Aprovação do merge". | histórico da CI |
| CA-12 | Revisores sem "Bloqueia", veredito do QA e conferência do dono na prévia. | relatórios no PR |

## 10. Dependências
- **Item 2** (fundação técnica): app, pnpm, Vitest, Playwright, CI, banco local, Spec Kit.
- **Item 3** (banco): estúdio com fuso, membros, papéis, função de checagem, molde do teste de isolamento.
- **Item 4** (design system no código): componentes do `DESIGN.md`.
- **Spec "Entrar e camada de serviço"** (E36·A do dono, 28/11/2026: "E36a"; branch `feat/entrar-servico`, antes do
  núcleo): login e as 6 portas que toda ação da Agenda usa.
- **Spec do Agendamento:** tabela e status dos agendamentos, fluxo de marcar e painel. Sem ela, a grade mostra só
  bloqueios e os botões ficam "em desenvolvimento" (RF-08).
- **E22·B:** construção em PR de rascunho; banco só local; nada juntado sem o dono.

## 11. Fora de escopo
Os recursos "depois" da §2.1; marcar, remarcar, mudar status e cancelar agendamento (Agendamento); cadastro de
profissional e expediente (Equipe); unidades (`locations`); busca na Agenda; portal público; banco de produção e publicação.

## 12. Dúvidas ao dono (máx. 3)
E26·1 e E26·2 valem também para a spec do Agendamento, que não repete a pergunta (revisão 5b do Gerente de projeto).

**E26·1 · O que a profissional vê na Agenda e nos agendamentos** (acesso, dado de cliente)
- **A:** tudo do estúdio, com nome das clientes de todas.
- **B:** a própria coluna completa; as outras só como "ocupado", sem cliente nem serviço.
- **C:** só a própria coluna.
- **Recomendo B:** vê o dia da equipe para se organizar, sem ver cliente alheia (RGPD art. 5(1)(c), minimização).

**E26·2 · Quem cria, altera e exclui bloqueios e agendamentos** (cria, remarca e cancela agendamento) (acesso)
- **A:** dona e recepção em todos; a profissional só nos próprios (bloqueios e agendamentos dela).
- **B:** só dona e recepção.
- **C:** qualquer papel, para qualquer profissional.
- **Recomendo A:** a profissional organiza a própria agenda sem mexer na das outras (OWASP ASVS V4, menor
  privilégio).

**E26·3 · Quem aparece como coluna na Agenda** (tela, acesso)
- **A:** quem tem papel profissional, mais a dona (que costuma atender); a recepção não.
- **B:** só quem tem papel profissional.
- **C:** cadastro de profissional à parte, que pode não ter login: pede tela nova, só com o módulo Equipe.
- **Recomendo A:** usa as pessoas do item 3, sem tela nova; "atende ou não" por pessoa vem com a Equipe.

## 13. Assumptions (técnicas e de formato, à vista na aprovação)
1. Grade de 24 h com rolagem até a hora atual (ou ao primeiro item do dia); passos de 15 min na escolha de hora.
2. A escolha do "Equipe N de M" fica guardada no aparelho da pessoa, só com identificadores, sem dado pessoal.
3. Formulário de bloqueio em painel à direita (480 px) no computador e folha de baixo no celular (`DESIGN.md` §8).
4. Ferramenta de acessibilidade automática, teto de itens por dia e teto de idas ao banco: o Arquiteto fixa no plano,
   depois de lida a documentação oficial.
5. ADRs na numeração de `docs/adr/`; uma migration por tabela.
