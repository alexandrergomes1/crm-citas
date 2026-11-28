# Spec · Agenda (primeira versão)

- **Status:** Approved
- **Aprovação do dono:** "Aprovo as specs: Entrar e camada de serviço, Trava por estúdio no banco, Design system no
  código, Agenda, Agendamento, Clientes, Formulários, Catálogo, Checkout, Caixa." com as respostas "E26·1·B",
  "E26·2·A" e "E26·3·A" · 28/11/2026 · https://claude.ai/code/session_018cV8b8F1poNHjA4eEd3VyN
  (`docs/decisoes/2026-11-27-fundacao.md`, linha "Aprovação das specs") · gravado pelo Analista de requisitos (E16·3)
- **Aprovação do merge:** (pendente)
- **Pasta:** `specs/20261128-020000-agenda/` · **Branch:** `feat/agenda`, a partir da `previas`, que já tem a trava por
  estúdio, o design system e o Entrar (PR #7, com os PRs #5 e #6); construção em PR de rascunho, nada é juntado sem o
  dono (E22·B)
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
  Nos ajustes de 28/11 (§14): `docs/adr/0020-permissao-por-chave-modulo-acao.md`,
  `docs/produto/avaliacao-crm-agenda/` (3 arquivos) e, pela E44, a parte da Agenda do `crm-agenda` (só leitura, nada
  copiado; lista em `ideias-do-antigo.md`). Nos ajustes 2 (§16): `ficha-visual.md` (E55), `supabase/migrations/`
  (todas, 28/11), `docs/produto/ajustes.md` e `equipe.md`, `DESIGN.md` §5 (busca), `src/app/ui/campos.tsx`
  (`BuscaGeral`) e `docs/adr/0020-permissao-por-chave-modulo-acao.md` (D2, D4, D10).

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

**Ampliação de escopo pedida pelo dono em 28/11 (§16) foi para a spec seguinte (E57·B, §17):** formatos de visão em
cards, resumo da coluna, dias marcados no calendário, grade no horário de funcionamento e lupa no celular ficam na spec
**"Agenda · visões e horário de funcionamento"**. Nesta, onde houver botão deles, aparece "em desenvolvimento".

### 2.1 Recursos da lista candidata (`docs/produto/agenda.md`)
| Recurso | Primeira versão | Motivo |
|---|---|---|
| visões dia, 3 dias, semana e mês | **só Dia**; os outros formatos ficam "em desenvolvimento" no "Dia ▾" | E57·B (§17): formatos em cards e modo "Lista" (E54·6/7/8) vão para a spec seguinte |
| status no cartão | **sim** | sem ele a grade não diz o que está acontecendo |
| bloqueio de horário | **só único** | repetido depois |
| conflito de horário | **sim, para bloqueio** | o conflito ao marcar agendamento é da spec do Agendamento |
| filtros | **sim: status e bloqueio** | profissional vai pelo "Equipe N de M"; serviço e etiqueta dependem de Catálogo e Clientes |
| altura das horas | depois | ajuste de conforto |
| lista de espera | depois | botão aparece como "em desenvolvimento" (`DESIGN.md` §7 e §8) |
| arrastar para remarcar | depois | remarcar é do Agendamento |
| resumo do dia | depois | o resumo por coluna (E54·6) vai para a spec seguinte (E57·B, §17); o do dia inteiro pode envolver valores (dinheiro) |
| exportar e imprimir | depois | "Opções" aparece como "em desenvolvimento" |
| aviso no sininho | depois | depende de notificações e da fila de envios |
| ligação com Google Agenda | depois | integração externa, spec própria |

## 3. Quem usa e o que cada papel vê
| Papel | Vê | Pode |
|---|---|---|
| Dona | a agenda inteira do seu estúdio | criar, alterar e excluir bloqueio de qualquer coluna (tem tudo, ADR 0020 · D4) |
| Recepção | a agenda inteira do seu estúdio | criar, alterar e excluir bloqueio de qualquer coluna (E26·2·A) |
| Profissional | **só a própria coluna**; as outras não aparecem, nem como "Ocupado" (ordem do dono de 28/11, §16, que substitui a E26·1·B; E58·A, §17) | criar, alterar e excluir só os bloqueios da própria coluna (E26·2·A) |
| Sem papel no estúdio ou sem login | nada | nada |

Nenhum papel vê dado de outro estúdio (`ARCHITECTURE.md` §5). O cartão nunca mostra dado de saúde.

**Chaves de permissão (E42·A, ADR 0020).** Cada ação da Agenda declara uma chave; o módulo nunca decide pelo papel,
recebe só o alcance (`todos` ou `proprios`). A dona tem tudo, por regra fixa. Durante o desenvolvimento só o dono usa,
como dona (E42·A); a personalização vem no item 6a sem mudar a Agenda.

| Chave | Recepção | Profissional | Resposta |
|---|---|---|---|
| `agenda.ver` | todos | próprios | E26·1·B, lida pela ordem de 28/11 (§16) e pela E58·A (§17) |
| `agenda.criar`, `agenda.editar`, `agenda.remover` (bloqueio) | todos | próprios | E26·2·A |

Na Agenda, **"próprios"** quer dizer a coluna da própria pessoa: ver tudo dela; gravar só bloqueio com ela como
profissional. Com `agenda.ver` "próprios", as colunas das outras **não aparecem** nem saem do servidor. **Sem
"Ocupado" nesta spec** (E58·A): nenhuma chave de ocupação, nenhum cartão "Ocupado".

**"Ver as outras" e "ver ocupação" entram com a tela de perfis (item 6a, E58·A).** Até lá não há tela para ajustar
perfil e a profissional fica só com a própria coluna (E42·A). A forma de "ver ocupação" (chave nova; ADR 0020 · D2
fecha o catálogo em `ver`, `criar`, `editar`, `remover` e as sensíveis) é decidida no item 6a, não aqui.

## 4. Telas e estados
Só peças, nomes e medidas do `DESIGN.md`. Peça que faltar para no caminho e entra no `DESIGN.md` com o dono primeiro.
Em todo texto de tela, aviso e mensagem, o negócio de quem usa se chama **"empresa"** (pt, es) e **"business"** (en),
nunca "estúdio" nem "clínica" (E47·1·A, `DESIGN.md` §6). Nesta spec, "estúdio" é o nome técnico (`estudio`, `org_id`).

**Tela Agenda** (título "Agenda", `DESIGN.md` §6; módulo sem seções, §7).
- **Computador (1440):** barra do topo: título e subtítulo (data do dia) · busca geral · Opções (o que fica dentro sai
  da ficha nova) · **+ Adicionar ▾** (preto, única ação principal; abre as opções "Novo agendamento" e "Bloquear
  horário", E55·4 trocada, E60·1·A e E60·5, §18; nome do `DESIGN.md` §6, "Novo" não é nome de botão) · ajuda ·
  Notificações · Sua conta. Barra da
  grade: Hoje · seta de dia anterior e seguinte · data em pílula com calendário · **Dia ▾** · **Equipe N de M** (ícone
  de pessoas, E60·4, §18) · **Filtros ▾** · **Lista de espera** ("em desenvolvimento").
- **Celular (390):** cabeçalho com ☰ (abre as visões da Agenda), data, **lupa** ("em desenvolvimento"; a busca vai
  para a spec seguinte, E57·B), funil, sininho e Sua conta (nível 1); faixa da grade com ‹ Hoje › · Equipe N de M · ⋮ (E55·3·A: Hoje sai do cabeçalho); barra de baixo
  com o botão do meio **só com ícone, sem nome** (E60·2, §18), Agenda atual em azul. Filtros em folha de baixo. Duas
  colunas à vista e as outras rolando para o lado (E55·3·A). A forma do botão do meio e a do "Adicionar" do topo nas
  telas do celular (com nome ou só "+"), a partir das imagens do dono, o Designer avalia e mostra na ficha (§18).
  **A Agenda no celular não tem "+ Adicionar" no topo:** quem cria é o botão do meio da barra (E60·2; ficha v4 e
  `DESIGN.md` §5, "Adicionar no celular"). O ícone do botão Equipe espera a resposta do dono à E63 (`DESIGN.md` §5).
- **Topo de cada coluna:** o **nome de exibição** da pessoa e as iniciais (E55·1·A, RF-21).
- **Grade:** faixa de **08:00 a 20:00** que se alarga quando há item fora dela e, no dia de hoje, até a hora atual
  (E59·A, RN-11, §18; ADR 0006 · D17), com rolagem (Assumption 1). Grade no horário de funcionamento: spec seguinte
  (E57·B, §17).
- **Cartão do agendamento:** hora de início e fim, nome da cliente, serviço, ícone de status (no cartão pequeno só o
  ícone, com o nome no leitor de tela; ícones Lucide do `DESIGN.md` §5). Tocar abre o agendamento (spec do
  Agendamento).
- **Bloqueio na grade:** ícone `lock` e a palavra "Bloqueio", com o motivo se houver.
- **Bloqueio · criar e alterar:** campos profissional*, data*, início*, fim*, motivo, com os atalhos **Almoço · Folga ·
  Reunião · Curso · Pessoal** que preenchem o motivo (E54·3, RF-22); Salvar · Cancelar. **Início e
  fim só por seletor de horários predefinidos, nunca digitados** (E54·5 trocada, RN-09). Novo bloqueio nasce com 1 h
  (E54·4, RN-10). Excluir no ⋮, em vermelho, com janelinha de confirmação e aviso depois. Entradas: "+ Adicionar ▾" ›
  "Bloquear horário" e o toque num horário vazio (E54·1, RF-13); sem botão próprio de bloqueio (E60·1·A, §18). Com alcance "próprios", o campo profissional fica só com a própria
  pessoa.

**Estados (`DESIGN.md` §8):** carregando (linhas cinza só depois de 0,3 s, anunciado ao leitor de tela) · vazio na v1
(sem o Agendamento construído; dia sem bloqueio: grade à vista, "Ainda não há bloqueios neste dia", "Bloqueie um
horário quando alguém não puder atender." e "Bloquear horário" com contorno; ficha v4 e `DESIGN.md` §7b) · vazio com o
Agendamento (dia sem agendamento nem bloqueio: grade à vista, "Ainda não há agendamentos neste dia" e "Novo
agendamento" com contorno) · sem
resultado (filtro esconde tudo: o que foi filtrado e "Limpar filtros") · sem profissional (estúdio sem ninguém que
seja coluna pela E26·3·A, o que só acontece sem dona ativa: frase e caminho para a Equipe, "em desenvolvimento" até o
módulo existir) · erro (o que houve e "Tentar de
novo") · sucesso (aviso depois de salvar ou excluir bloqueio, com "Desfazer" no excluir).

## 5. Requisitos funcionais
| ID | Requisito | Fonte |
|---|---|---|
| RF-01 | A Agenda abre no dia de hoje, no fuso do estúdio. | `ARCHITECTURE.md` §11 |
| RF-02 | A pessoa troca de dia (anterior, seguinte, calendário) e volta com **Hoje**. | `DESIGN.md` §6 e §7 |
| RF-03 | Há uma coluna para cada pessoa ativa com papel profissional e para a dona; a recepção não é coluna (E26·3·A). **Equipe N de M** escolhe quais aparecem; N é o número à vista e M o total **das colunas que a pessoa pode ver** (§3: a profissional tem só a dela). O botão usa o ícone de pessoas (E60·4); a profissional não o vê (Assumption 6). | `DESIGN.md` §6 e §7; E26·3·A; ordem de 28/11; E60·4 (§18) |
| RF-04 | A grade mostra os agendamentos e os bloqueios do dia de cada coluna à vista. | `docs/produto/agenda.md` |
| RF-05 | O cartão mostra o status com o ícone do `DESIGN.md` §5 e o nome acessível. | `DESIGN.md` §5 e §9 |
| RF-06 | **Filtros** por status e por bloqueio (mostrar ou esconder), com a pílula de contador de filtros ligados e "Limpar filtros". | `DESIGN.md` §5 e §7 |
| RF-07 | Criar, alterar e excluir bloqueio único de uma profissional, com início e fim no mesmo dia. | `docs/produto/agenda.md` |
| RF-08 | **+ Adicionar ▾** (peça preta; E60·5, §18) abre as opções: "Novo agendamento" (leva ao fluxo do Agendamento) e "Bloquear horário" (abre o bloqueio); nenhuma outra opção sem pedido do dono. Tocar num cartão abre o agendamento. Sem a spec do Agendamento construída, "Novo agendamento" e o toque no cartão aparecem como "em desenvolvimento". O bloqueio não tem botão próprio (E60·1·A). | `DESIGN.md` §5 e §8; E55·4 trocada (§16); E60·1·A e E60·5 (§18) |
| RF-09 | Toda ação passa pelas 6 portas e declara a chave da §3 (`agenda.ver`, `.criar`, `.editar`, `.remover`); a porta 3 confere a chave e entrega o alcance; criar, alterar e excluir bloqueio fica no registro (porta 6), sem dado pessoal nem o texto do motivo. | `ARCHITECTURE.md` §4; E42·A, ADR 0020 |
| RF-10 | Com `agenda.ver` "próprios", a pessoa vê só a própria coluna; as outras não aparecem nem saem do servidor, nem como "Ocupado" (§3). Com alcance "próprios" de gravar, grava só bloqueio da própria coluna. | ordem de 28/11 (substitui a E26·1·B); E58·A; E26·2·A |
| RF-11 | A tela recebe as chaves que a pessoa tem só para esconder o que ela não pode usar (ex.: o ⋮ e a entrada de bloqueio nas colunas das outras); quem decide é a porta 3 e o banco. | ADR 0020 · D9; E43·A (`permissoes-e-pin.md` #11) |
| RF-12 | Entrar no sistema (endereço `/`) abre a Agenda. | E55·2·A |
| RF-13 | Tocar ou dar Enter num horário vazio de uma coluna abre um menu com "Novo agendamento" e "Bloquear horário", já com a hora e a pessoa da coluna; quem não pode gravar naquela coluna não vê o menu. | E54·1 (§16); E26·2·A; WCAG 2.1.1 |
| RF-14 | Na coluna de hoje, uma linha marca a hora atual, no fuso do estúdio, com a hora na coluna das horas, em **azul** (E60·3·A; o tom exato vem do `DESIGN.md`, Designer). Se a hora atual está fora de 08:00–20:00, a grade se alarga até ela (RN-11). | E54·2 (§16); E60·3·A e E59·A (§18); ADR 0006 · D17 |
| RF-15 | No bloqueio, início e fim se escolhem só num seletor de horários predefinidos (RN-09); novo bloqueio nasce com 1 h e o fim anda junto quando o início passa dele (RN-10). | E54·4, E54·5 trocada (§16) |
| RF-16 a RF-20 | **Saíram desta spec** (formatos de visão em cards e modo "Lista", resumo da coluna, dias marcados no calendário, grade no horário de funcionamento, lupa no celular): vão para a spec seguinte **"Agenda · visões e horário de funcionamento"**. Aqui, o "Dia ▾" (outros formatos) e a lupa do celular aparecem "em desenvolvimento" (`DESIGN.md` §7 e §8). Os IDs ficam reservados. | E57·B (§17) |
| RF-21 | O topo de cada coluna mostra o **nome de exibição** da pessoa, campo novo só para isto; sem tela de edição na v1 (módulo Equipe); em desenvolvimento, nomes fictícios. Nunca o e-mail. | E55·1·A |
| RF-22 | No bloqueio, os atalhos **Almoço · Folga · Reunião · Curso · Pessoal** preenchem o motivo com um toque; o texto continua editável (RN-03). Nenhum atalho de saúde (sem "Médico"). Textos dos atalhos nos três idiomas (RNF-05). | E54·3 aprovada (§17) |

## 6. Regras de negócio (verificáveis)
| ID | Regra |
|---|---|
| RN-01 | O dia vai de 00:00 a 24:00 no fuso do estúdio, inclusive nos dias de troca de horário de verão (23 h ou 25 h). |
| RN-02 | Agendamento ou bloqueio que cruza a meia-noite aparece nos dois dias, cortado na borda. |
| RN-03 | Bloqueio: fim depois do início; mínimo 5 min; início e fim no mesmo dia do estúdio; motivo opcional, até 200 caracteres. |
| RN-04 | Bloqueio não pode sobrepor outro bloqueio nem agendamento ativo (que não seja Cancelado nem Ausência) da mesma profissional; a tela diz o conflito e não salva. Encostar (fim de um = início do outro) não é conflito. |
| RN-05 | Itens sobrepostos na mesma coluna aparecem lado a lado, sem esconder nenhum. |
| RN-06 | Cancelados não aparecem por padrão; o filtro de status os mostra. |
| RN-07 | O estúdio de toda leitura e gravação vem da sessão, nunca do pedido; a profissional do bloqueio tem de ser do mesmo estúdio e ser coluna (E26·3·A). |
| RN-08 | A consulta de um dia traz só o dia e as colunas à vista, com teto de itens; passou do teto, a tela avisa em vez de cortar calado. |
| RN-09 | O seletor de hora oferece só horários em passos fixos (15 min, Assumption 1) dentro do dia do estúdio; o servidor recusa hora fora do passo. Não há campo de digitar hora. |
| RN-10 | Novo bloqueio: fim = início + 1 h. Se o início passa do fim, o fim vira início + 1 h. O fim nunca passa do fim do dia do estúdio (RN-03): se passaria, para no fim do dia, e a pessoa vê o fim mudado no seletor. |
| RN-11 | A grade mostra de 08:00 a 20:00. Item que começa antes ou termina depois alarga a faixa até a hora cheia antes do primeiro ou depois do último; no dia de hoje, a hora atual fora da faixa também a alarga, até a hora cheia anterior ou seguinte. Nenhum item fica fora da tela, e a faixa nunca passa do dia do estúdio (RN-01). Em outro dia, a hora atual não conta. |

## 7. Tabelas
Base da trava (estúdio, membros, papéis, função de checagem) vem do item 3. Cada linha abaixo é **sugestão** do
Analista; quem decide é o Engenheiro de dados no plano, com ADR e revisão de outro papel (E16·1; RG-02 do item 3).

| Tabela (antigo) | Para quê aqui | Sugestão | Motivo |
|---|---|---|---|
| `time_blocks` | bloqueio de horário | **reescrever** | ficam `org_id`, profissional, início, fim, motivo, autor; saem `resource_id`, `location_id`, `repeat_rule` (fora da v1); chave estrangeira com o mesmo estúdio; trava pela função do item 3 (RG-04) |
| `staff_members` | quem aparece como coluna | **descartar** (E26·3·A: usa membros do item 3) | no antigo leva e-mail, telefone, cor fora do `DESIGN.md` e comissão (dinheiro), que não são da Agenda |
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
| CA-01 | RN-01 a RN-06 e RN-08 a RN-11 têm teste em `src/domain`, inclusive dia de 23 h e de 25 h, meia-noite, sobreposição encostada e a faixa 08:00–20:00 alargada por item antes, item depois e hora atual fora dela (só no dia de hoje). | unidade, CI verde |
| CA-02 | O estúdio A não lê, cria, altera nem apaga bloqueio do estúdio B; bloqueio com profissional de outro estúdio é recusado. | isolamento, CI verde |
| CA-03 | Sem login e sem papel no estúdio: nada é lido nem gravado; cada papel lê e grava só o que a §3 permite (ordem de 28/11 no lugar da E26·1·B, E26·2·A, E26·3·A), pela chave e pelo alcance, iguais no servidor e no banco (ADR 0020 · D7 e D8). | teste de banco e do servidor, CI verde |
| CA-04 | Pedido que traz estúdio é recusado (`estudio_trocado`, contrato da camada de serviço, spec Entrar RF-15/CA-05), sem ler nem gravar nada. | teste do servidor |
| CA-05 | Em 390 e 1440: `/` abre a Agenda em hoje; troca de dia e Hoje; Equipe N de M com o ícone de pessoas, e a profissional sem esse botão; filtros e "Limpar filtros"; "+ Adicionar ▾" com as duas opções e nenhum botão com o nome "Novo"; botão do meio da barra do celular só com ícone e nome acessível, e a Agenda do celular sem "+ Adicionar" no topo; grade de 08:00 a 20:00 e alargada (RN-11); linha da hora atual em azul; menu do horário vazio por toque e por teclado; criar (só por seletor, nascendo com 1 h, atalho de motivo), alterar, conflito recusado e excluir bloqueio com "Desfazer"; nome de exibição no topo das colunas. | e2e, CI verde |
| CA-06 | Em 390 e 1440: estados carregando, vazio, sem resultado, sem profissional e erro aparecem como na §4. | e2e |
| CA-07 | Uma só peça preta de ação por tela; nenhuma peça, cor ou nome fora do `DESIGN.md`. | checklist §10 do `DESIGN.md`, Revisor de design |
| CA-08 | Checagem automática de acessibilidade sem falha nas duas larguras e status com nome acessível. | e2e |
| CA-09 | Nenhuma URL, registro ou erro contém nome de cliente ou motivo de bloqueio. | teste e revisão do Engenheiro de segurança |
| CA-10 | Cada tabela da §7 tem ADR com saída, motivo, norma e quem conferiu; migration só para as copiadas ou reescritas. | `docs/adr/` × PR |
| CA-11 | Nada aplicado no banco remoto; banco só local até a "Aprovação do merge". | histórico da CI |
| CA-12 | Revisores sem "Bloqueia", veredito do QA e conferência do dono na prévia. | relatórios no PR |
| CA-13 | Como profissional: a resposta do servidor não traz as colunas das outras (nem como "Ocupado"), e a tela mostra só a coluna dela. | teste do servidor e e2e, CI verde |
| CA-15 | Hora fora do passo, ou digitada, é recusada pelo servidor; a tela não tem campo de digitar hora. | unidade e teste do servidor |
| CA-16 | Nada de RF-16 a RF-20 é construído nesta spec; em 390 e 1440, os outros formatos do "Dia ▾" e a lupa do celular aparecem "em desenvolvimento". | spec × PR; e2e |
| CA-14 | Cada regra do bloqueio no banco (RN-03, RN-04, RN-07, chave e alcance) é testada ao criar **e** ao alterar. | teste de banco, CI verde (E43·A, `regras-do-banco.md` #54) |

## 10. Dependências
- **Item 2** (fundação técnica): app, pnpm, Vitest, Playwright, CI, banco local, Spec Kit.
- **Item 3** (banco): estúdio com fuso, membros, papéis, função de checagem, molde do teste de isolamento (na
  `previas`, PR #7).
- **Item 4** (design system no código): componentes do `DESIGN.md` (na `previas`, PR #7).
- **Spec "Entrar e camada de serviço"** (E36·A do dono, 28/11/2026: "E36a"; juntada na `previas` pelo PR #7): login e
  as 6 portas que toda ação da Agenda usa, com a porta 3 por chave e alcance (ADR 0020).
- **Spec do Agendamento:** tabela e status dos agendamentos, fluxo de marcar e painel. Sem ela, a grade mostra só
  bloqueios e os botões ficam "em desenvolvimento" (RF-08).
- **E22·B:** construção em PR de rascunho; banco só local; nada juntado sem o dono.

## 11. Fora de escopo
Os recursos "depois" da §2.1; marcar, remarcar, mudar status e cancelar agendamento (Agendamento); cadastro de
profissional e expediente (Equipe); tela de editar o nome de exibição (Equipe); tela de ajustar perfil, "ver as
outras" e "ver ocupação" (item 6a, E58·A); unidades (`locations`); portal público; banco de produção e publicação.
Formatos de visão em cards, resumo da coluna, dias marcados, grade no horário de funcionamento e busca pela lupa no
celular: spec seguinte "Agenda · visões e horário de funcionamento" (E57·B).

## 12. Dúvidas ao dono (máx. 3)
**Respondidas em 28/11/2026** (`docs/decisoes/2026-11-27-fundacao.md`, link
https://claude.ai/code/session_018cV8b8F1poNHjA4eEd3VyN), e valem também para o Agendamento:
- **E26·1 · O que a profissional vê:** "E26·1·B": a própria coluna completa; as outras só como "ocupado".
  **Substituída pelo dono em 28/11 (§16):** por padrão só a própria; as outras só com a liberação no perfil.
- **E26·2 · Quem cria, altera e exclui bloqueios e agendamentos:** "E26·2·A": dona e recepção em todos; a profissional
  só nos próprios.
- **E26·3 · Quem aparece como coluna:** "E26·3·A": quem tem papel profissional, mais a dona; a recepção não.

**Pendência para a spec da Equipe (não é dúvida da Agenda):** quando uma pessoa deixar de ser coluna (perder o papel
profissional ou ser desativada) e ainda tiver bloqueios ou agendamentos marcados, eles não podem sumir da Agenda sem
aviso. Na v1 isso não acontece pelo produto: não há tela nem ação do servidor que mude papel ou `ativo` (só o módulo
Equipe, fora de escopo, §11), e durante o desenvolvimento só o dono usa (E42·A). O banco já deixa a dona mudar
`papel` e `ativo` (`supabase/migrations/20261128002045_politicas_base.sql`, política `membros_alterar`), mas nenhum
caminho do app usa isso. A pergunta vai ao dono na spec da Equipe; a Agenda não para.

**Situação em 28/11/2026, depois da resposta do dono (§17):** nenhuma dúvida aberta nesta spec.
- **E56·1 e E56·2:** saíram junto com RF-19 e RF-20 para a spec seguinte "Agenda · visões e horário de funcionamento"
  (E57·B). O dono disse que não entendeu "grade só no horário de funcionamento"; o Gerente de projeto explica, e a
  pergunta volta lá, não aqui.
- **E56·3:** respondida pela aprovação da E54·3 ("E54·3: OK"): atalhos Almoço · Folga · Reunião · Curso · Pessoal, sem
  "Médico" (RF-22). O "não entendi" do dono sobre a E56·3 fica coberto por essa resposta.

Texto das E56 como foi feito, para a spec seguinte (histórico; E56·1 e E56·2 não valem como decisão aqui):
- **E56·1 · De onde vem o horário de funcionamento (RF-19).** Hoje **não existe** no sistema: a tabela `estudios` tem
  só nome, moeda, idioma e fuso; `membros` não tem expediente; o expediente do antigo (`staff_shifts`) está adiado
  (§7, módulo Equipe), e "horário" é recurso do módulo Ajustes, que vem depois do núcleo.
  **A** horário da empresa por dia da semana, guardado no banco já na v1, sem tela para editar até o Ajustes (em
  desenvolvimento, posto pelo preparo de teste); o da colaboradora vem com a Equipe; item fora do horário alarga a
  grade para aparecer, nunca some · **B** igual à A, com uma tela simples de "Horário de funcionamento" já na Agenda
  (mais tela e mais banco agora) · **C** a grade fica em 24 h até o Ajustes e a Equipe existirem.
  **Recomendo A:** atende o pedido sem puxar outro módulo para dentro, e nenhum atendimento some da tela.
- **E56·2 · O que a lupa acha (RF-20).** A busca do computador hoje é só o campo, sem resultado definido
  (`BuscaGeral`). **A** na Agenda, acha agendamentos e bloqueios pelo nome da cliente ou do serviço, só nas colunas que
  a pessoa vê completas, e leva ao dia do item · **B** é a busca geral do sistema (clientes, agendamentos, tudo), que
  pede spec própria · **C** a lupa fica "em desenvolvimento" até a busca geral existir. **Recomendo A:** é o que se
  procura no balcão, e não mostra a ninguém o que ela não pode ver (dado de cliente).
- **E56·3 · Atalhos de motivo do bloqueio (E54·3, sem resposta em 28/11).** **A** aprovar: chips "Almoço · Folga ·
  Reunião · Curso · Pessoal" que preenchem o motivo, sem "Médico" (dado de saúde) · **B** não aprovar: só o texto
  livre. **Recomendo A:** menos digitação no balcão, combina com a troca da E54·5 (escolher em vez de digitar).

## 13. Assumptions (técnicas e de formato, à vista na aprovação)
1. Grade de 08:00 a 20:00 que se alarga por item fora dela e, no dia de hoje, até a hora atual (E59·A, RN-11; ADR 0006
   · D17), com rolagem até a hora atual (ou ao primeiro item do dia); passos de 15 min no seletor de hora (RN-09). A
   grade de 24 h saiu (E59·A, §18); a do horário de funcionamento vem na spec seguinte (E57·B).
2. A escolha do "Equipe N de M" fica guardada no aparelho da pessoa, só com identificadores, sem dado pessoal.
3. Formulário de bloqueio em painel à direita (480 px) no computador e folha de baixo no celular (`DESIGN.md` §8).
4. Ferramenta de acessibilidade automática, teto de itens por dia e teto de idas ao banco: o Arquiteto fixa no plano,
   depois de lida a documentação oficial.
5. ADRs na numeração de `docs/adr/`; uma migration por tabela.
6. **A profissional não vê o botão "Equipe N de M"** (leitura da E60·4·A: ela só tem a própria coluna). O dono
   respondeu só o ícone ("bonequinhos"); a ficha mostra a tela da profissional sem o botão para o "sim" dele. Não é
   acesso: o que ela vê já está fechado pela E58·A (RF-10); aqui é só esconder um botão sem escolha.
7. O botão do meio da barra do celular tem nome para o leitor de tela (WCAG 2.2, 4.1.2), embora sem nome à vista
   (E60·2).

## 14. Ajustes (28/11/2026, depois da aprovação)
Aplicação de respostas já registradas do dono; nenhum requisito novo. Escrito pelo
Analista de requisitos (IEEE 29148 e BABOK).

| Onde | O que mudou | Por quê |
|---|---|---|
| topo | "Status: Approved" e a linha "Aprovação do dono" | aprovação de 28/11 (E16·3) |
| topo, Branch | sai da `previas` (já com o PR #7), não mais empilhada | o Entrar foi juntado (PR #7) |
| §3 | tabela com as respostas; chaves `agenda.ver/.criar/.editar/.remover` e alcance; "próprios" e "Ocupado" na Agenda | E26·1·B, E26·2·A, E42·A, ADR 0020 · D1 a D5 |
| §3 e §4 | "Ocupado" sem status e filtros que não agem nas colunas das outras | consequência da E26·1·B ("só como ocupado"): mostrar o status ou deixar o filtro de status agir revelaria o que a resposta esconde |
| §4 | "empresa"/"business" em todo texto de tela | E47·1·A, `DESIGN.md` §6 |
| §4 | cartão "Ocupado"; campo profissional só a própria pessoa com alcance "próprios"; estado "sem profissional" só sem dona ativa | E26·1·B, E26·2·A, E26·3·A |
| §5 | RF-03 com a E26·3·A; RF-09 com a chave; RF-10 (alcance) e RF-11 (esconder botões pela chave) | E26, E42·A, ADR 0020 · D9; E43·A (`permissoes-e-pin.md` #11) |
| §6, RN-07 | a profissional do bloqueio tem de ser coluna | E26·3·A |
| §7 | `staff_members`: descartar | E26·3·A |
| §9 | CA-03 com chave e alcance; CA-13 ("Ocupado"); CA-14 (regra testada ao criar e ao alterar) | E26, ADR 0020 · D7 e D8; E43·A (`regras-do-banco.md` #54) |
| §10 | itens 3, 4 e o Entrar já na `previas` | PR #7 |
| §12 | E26 respondidas; pendência para a spec da Equipe (pessoa que deixa de ser coluna) | `AGENTS.md` §4; revisão 5b do Gerente de projeto: não acontece na v1 |
| §15 | ideias do antigo, fora dos requisitos | E44 |

**Sem mudança na Agenda v1:** E30·3·B (quem faz cada serviço) é do Catálogo e do Agendamento; as colunas seguem a
E26·3·A e o filtro por serviço está em "depois". Das ideias "aproveitar" da E43·A, as demais não são da Agenda (base,
Agendamento, Formulários, Checkout, Caixa).

**Para o Arquiteto (o `plan.md` não foi tocado):** o plano ainda fala em "função do papel" (§5.1), mostra "Bloqueio"
sem motivo nas colunas das outras (§3) e trata as E26 como em aberto; precisa seguir a §3 acima, a RF-10 e a CA-13.

## 15. Ideias do projeto antigo (E44)
Lista em [`ideias-do-antigo.md`](ideias-do-antigo.md): 8 ideias (E54·1 a E54·8; A = aprovar, B = não aprovar) e as descartadas, cada uma com o
risco de vício. Só entram com a autorização do dono, item por item (`AGENTS.md` §3 regra 4). **Em 28/11 (§16):**
E54·1, ·2 e ·4 aprovadas, com as travas fixadas na lista; E54·5 trocada (seletor, não digitação); E54·6, ·7 e ·8
respondidas dentro da ampliação "formatos de visão", que foi para a spec seguinte (E57·B, §17); E54·3 aprovada em 28/11 (§17, RF-22). Cada aprovada é **reescrita** do nosso jeito,
com ADR e revisão de outro papel (E16·1); nada se copia do antigo.

## 16. Clarifications · ajustes 2 (28/11/2026, respostas à ficha E55 e às ideias E54)
> Histórico. Onde esta seção fala de "Ocupado", liberação no perfil, RF-16 a RF-20 e E56, vale a §17 (E57·B, E58·A).
> Onde fala de "+ Novo", "Agendar" e bloqueio "dentro ou separado", vale a §18 (E60·1·A, E60·2, E60·5).

Escrito pelo Analista de requisitos (IEEE 29148 e BABOK). Resposta do dono, **28/11/2026**,
https://claude.ai/code/session_018cV8b958nnbLyXPMKPeaNK, literal:

> "E54-1, e54-2, e54-4, e54-5: tem de ser um seletor com horários predefinidos e não para preencher.
> E54-6, e54-7, e54-8 (eu enviei um arquivo com exemplos de ideias de visão (freshamobile) com vários formato de
> visão e configurações de formatos. A prioridade é sempre por cards (acho).
> A grade de horários exibidas tem de ser conforme o horário de funcionamento ou do colaborador para não ficar 24hs
> aberto ocupando espaço desnecessário.
> OBS: a maioria das coisas que me envia da forma que vem me cabe julgar apenas o que estou vendo, pois é inviável ler
> linha a linha de código, por isso temos os devidos papéis e revisores para garantir que tudo esteja sendo construído
> corretamente e chegue a mim o necessário e claro para decisão.
> E55-4: Retirar o novo agendamento fixo e tem de ser um botão +novo com opções de agendamento, bloqueio de horário
> etc... e avaliar um configurador de botão de bloqueio integrado ao novo ou separado.
> E no mobile senti falta de uma lupa de busca na agenda como tem no pc.
> Nas colunas dos profissionais mostrar o nome de exibição da profissional.
> E cada profissional só vê o dela e não dos demais. Salvo se tiver no perfil liberar pra ver ou ver ocupação (exibe
> marcado mas info bloqueada/ocupado como o exemplo que deu).
> E55-2a, e55-3a"

| Fala | Leitura registrada | O que muda | Tipo |
|---|---|---|---|
| E54·1, ·2, ·4 | aprovadas | RF-13, RF-14, RF-15, RN-10, CA-05 | resposta |
| E54·5 + "seletor com horários predefinidos" | **trocada**: a hora se escolhe num seletor de horários em passos fixos, nunca se digita | §4, RF-15, RN-09, CA-15 | resposta |
| E54·3 | **sem resposta** | vira E56·3 (§12) | pendente |
| E54·6, ·7, ·8 + arquivo de exemplos | aprovadas como **formatos de visão configuráveis, prioridade em cards**; escopo exato com a ficha nova | §2, §2.1, RF-16, RF-17, RF-18, CA-16 | **ampliação de escopo** |
| grade no horário de funcionamento | ordem nova; o dado **não existe** hoje (E56·1) | §4, RF-19, Assumption 1, CA-16 | **ampliação de escopo** |
| OBS | o dono julga o que vê; o detalhe técnico fica com os papéis e revisores | nenhum requisito; vale para as mensagens | orientação |
| E55·4 | **trocada**: sai o "Novo agendamento" fixo; entra **"+ Novo"** com opções; o Designer avalia o bloqueio dentro do "+ Novo" ou separado | §4, RF-08, CA-05 | resposta |
| lupa no celular | ordem nova | §4, RF-20, §11 | **ampliação de escopo** |
| nome de exibição | **E55·1·A** | §4, RF-21, CA-05 | resposta |
| "cada profissional só vê o dela" | ordem nova que **substitui a E26·1·B**: padrão = só a própria coluna; perfil pode liberar ver (completas) ou ver ocupação ("Ocupado") | §3, RF-03, RF-10, CA-13 | acesso (dono decidiu) |
| E55·2·A | `/` abre a Agenda | RF-12, CA-05 | resposta |
| E55·3·A | peças e nomes da ficha; celular com 2 colunas; Hoje na faixa | §4 | resposta; o item (1) da E55·3 ("Ocupado" para quem não é dona nem recepção) passa a valer só com a liberação de ocupação |

**Arquivo de exemplos do dono ("freshamobile"):** não chegou a esta conversa; não lido. No repositório há
`docs/design/canvas/RefFresha3.dc.html` a `RefFresha5.dc.html`, que podem ser esse material ou parte dele: o Designer
confere com o dono.

**Para o Arquiteto (`plan.md`, `tasks.md` e ADR não foram tocados):** RF-10 e CA-13 mudam o padrão da profissional
(só a própria coluna; a leitura de "ocupados" só com a liberação); chave nova de ocupação e se o "Ocupado" se constrói
na v1 (§3; ADR 0020 · D2, D4, D10); `/` abre a Agenda; nome de exibição é campo novo no banco (Engenheiro de dados);
seletor sem digitação e servidor recusando hora fora do passo; RF-18 a RF-20 não entram no plano antes da ficha nova
e de E56·1 e E56·2.
**Para o Designer:** ficha nova com "+ Novo" (e se o bloqueio fica dentro ou separado), lupa no celular, se o
"Agendar" da barra de baixo vira "+ Novo", cor da linha do "agora", formatos de visão (cards), resumo por coluna e dias
marcados; a ficha atual cita Opções com "Bloquear horário" (E55·4·A), que deixou de valer.
**Ampliação de escopo:** decidida pelo dono na §17 (E57·B): RF-16 a RF-20 vão para a spec seguinte.

## 17. Clarifications · ajustes 3 (28/11/2026, respostas E54·3, E57 e E58)
Escrito pelo Analista de requisitos (IEEE 29148 e BABOK). Resposta do dono, **28/11/2026**,
https://claude.ai/code/session_018cV8b958nnbLyXPMKPeaNK, literal:

> "E54·3: OK / E57: NAO entendi sobre "grade so no horario de funcionamento" / E57-B / E56-3: nao entendi como ficara
> isso / E58-A / segue os exemplos fresha para ajudar a enriquecer o nosso."

| Fala | Leitura registrada | O que muda | Tipo |
|---|---|---|---|
| "E54·3: OK" | E54·3 **aprovada**: atalhos Almoço · Folga · Reunião · Curso · Pessoal; sem "Médico" (dado de saúde) | §4, RF-22, CA-05, §15 | resposta |
| "E56-3: nao entendi como ficara isso" | coberta pela E54·3 aprovada (E56·3·A); não volta como pergunta | §12 | resposta |
| "E57-B" | RF-16 a RF-20 (formatos em cards e "Lista", resumo da coluna, dias marcados, grade no horário de funcionamento, lupa no celular) e as dúvidas E56·1 e E56·2 **saem desta spec** e vão para a spec seguinte **"Agenda · visões e horário de funcionamento"**; aqui, onde houver botão, "em desenvolvimento" | §2, §2.1, §4, §5, CA-16, §11, §12, Assumption 1 | resposta (escopo) |
| "E57: NAO entendi sobre grade so no horario de funcionamento" | o assunto ficou para a spec seguinte; o Gerente de projeto explica ao dono | §12 | registro |
| "E58-A" | a profissional vê **só a própria coluna**; "ver as outras" e "ver ocupação" entram com a tela de perfis (item 6a); **sem "Ocupado" nesta spec** | §3, §4, RF-10, CA-13, §11 | acesso (dono decidiu) |
| "segue os exemplos fresha" | material de referência para a spec seguinte (visões); não chegou a esta conversa, não lido | nenhum requisito aqui | referência |

**Para o Arquiteto (`plan.md`, `tasks.md` e ADR não foram tocados):** sai do plano a chave de ocupação e o cartão
"Ocupado" (§3, CA-13); sai tudo de RF-16 a RF-20; entra RF-22 (atalhos de motivo, só texto, sem tabela nova).

## 18. Clarifications · ajustes 4 (28/11/2026, respostas E59 e E60·1 a E60·5 da ficha v3)
Escrito pelo Analista de requisitos (IEEE 29148 e BABOK). Resposta do dono, **28/11/2026**,
https://claude.ai/code/session_018cV8b958nnbLyXPMKPeaNK, literal:

> "E59-A, E60-A, E60-2: imagem anexo. sem nome, apenas icone. E60-3A, E60-4: icone deve ser dos bonequinhos, E60-5:
> pode ser adicionar ao inves de novo. fui pelo exemplo que tava na tela, vc que me induziu a isso. se tava adicionar
> pra que colocou novo agendamento? se tava escrito uma coisa, era só vc seguir e nao mudar e me induzir a outra
> decisao divergente. eu vou respondendo o que vc me mostra, se nao mostra, tas querendo me induzir ao erro. e as
> imagens que mando sao pra te ajudar e nao pra vc fazer fiel de forma tendenciosa.. a ideia era vc criar a sua e ver o
> fresha e agregar ao seu ou ver o que fica melhor.. e nao ser tendencioso.. se nao podes criar algo ruim no final e ter
> de ficar remendando tdo depois com mil mudanças.. mas claro, o design anterior foi aprovado, e os do fresha é para
> trazer toda customização e formas de ver algumas coisas pra agregar. mandei duas imagens exemplo sobre o "novo
> agendamento" para avaliar.3 imagem sobre o fundo dos botoes.. ao inves de branco seco que fica feio.. isso ´ra pra
> te ajudar e nao como regra.. tem de avaliar o que fica melhor. sao coisas simples de decidir."

Três imagens anexas, do nosso canvas "Prova · Serviços no celular" (não ficam no repositório): (1) topo com "+
Adicionar" e o botão do meio da barra só com o ícone de calendário com "+"; (2) topo com um botão redondo só com "+" e
a barra só com ícone; (3) estados vazios com "+ Adicionar serviço" e "Limpar filtros" em fundo cinza claro, não branco.

| Fala | Leitura registrada | O que muda | Tipo |
|---|---|---|---|
| "E59-A" | faixa de 08:00 a 20:00 que se alarga por item fora dela e, hoje, até a hora atual (ADR 0006 · D17); sai a grade de 24 h | §4, RF-14, RN-11, CA-01, CA-05, Assumption 1 | resposta |
| "E60-A" | lido como **E60·1·A**: o bloqueio se cria dentro do botão de criar e tocando num horário vazio, sem botão próprio, fora de Opções | §4, RF-08, RF-13 | resposta |
| "E60-2: imagem anexo. sem nome, apenas icone" | o botão do meio da barra do celular fica **só com ícone, sem nome à vista** (com nome para o leitor de tela, Assumption 7); a forma (preto ou claro) e o que ele abre o Designer avalia a partir das imagens 1 e 2 e mostra na ficha | §4, CA-05 | resposta; forma com o Designer |
| "E60-3A" | linha da hora atual **azul** | RF-14, CA-05 | resposta |
| "E60-4: icone deve ser dos bonequinhos" | o botão "Equipe N de M" usa o ícone de pessoas (Lucide, nome exato pelo Designer no `DESIGN.md` §5); a profissional não vê o botão: leitura, Assumption 6, à vista na ficha | §4, RF-03, CA-05 | resposta + leitura |
| "E60-5: pode ser adicionar ao inves de novo" | o botão se chama **"+ Adicionar ▾"**, como o `DESIGN.md` §6 já manda; "Novo" sai como nome de botão; as opções seguem "Novo agendamento" e "Bloquear horário" | §4, RF-08, CA-05 | resposta |
| "fui pelo exemplo que tava na tela, vc que me induziu..." | o que já está aprovado (`DESIGN.md`, ficha anterior) se segue; a pergunta mostra o que vale e não propõe mudar sem pedido; as referências (Fresha, imagens do dono) servem para avaliar e agregar, nunca para copiar | nenhum requisito; vale para as fichas e mensagens | orientação |
| imagem 3 (fundo dos botões claros nos estados vazios) | ajuda, não regra: o Designer avalia o fundo dos botões claros | nenhum requisito aqui | referência |

**Para o Designer (ficha e `DESIGN.md` não foram tocados):** forma do botão do meio e do "Adicionar" do topo no
celular, a partir das imagens 1 e 2; ícone de pessoas no "Equipe"; fundo dos botões claros (imagem 3); a ficha mostra
a profissional sem o "Equipe" (Assumption 6).
**Para o Arquiteto (`plan.md`, `tasks.md` e ADR não foram tocados):** RN-11 é a regra do ADR 0006 · D17 e do
alargamento por item, agora na spec; CA-01 a cobre.

## 19. Ajustes 5 (28/11/2026, auditoria do Gerente de projeto)
Escrito pelo Analista de requisitos (IEEE 29148 e BABOK). Nenhum requisito novo: a spec passa a dizer o que a ficha v4
e o `DESIGN.md` já gravam.

| Onde | O que mudou | Fonte |
|---|---|---|
| §4, Estados | vazio da v1: "Ainda não há bloqueios neste dia" com "Bloquear horário"; o vazio com "Novo agendamento" fica para quando o Agendamento existir | ficha v4; `DESIGN.md` §7b e §8 |
| §4, Celular; CA-05 | a Agenda no celular não tem "+ Adicionar" no topo; cria pelo botão do meio da barra | E60·2; ficha v4; `DESIGN.md` §5 |
| §4, Celular | o ícone do botão Equipe espera a E63 | `DESIGN.md` §5 e §7b |
