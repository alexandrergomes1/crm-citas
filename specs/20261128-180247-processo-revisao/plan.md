# Plano · Revisão do processo (item 4b da fila)

- **Em dia com:** E67·A (28/11/2026; E66·1 a E66·3 em aberto, na aprovação da spec) · ajustes da 5b do Gerente aplicados
- **Spec:** `specs/20261128-180247-processo-revisao/spec.md` (commit `1b9fe13`) · **Branch:** `chore/processo-revisao`
- **Escrito por:** Arquiteto de software · **Norma:** modelo C4 e ADR · **Revisa:** Gerente de projeto (etapa 5b)
- **Tipo:** texto e regras (`docs/guias/processo-sdd.md` §3). Prova: revisão de outro papel e CI verde.
- **Decisão técnica deste plano:** [ADR 0022](../../docs/adr/0022-regra-das-pastas-e-registros-entre-branches.md)
  (regra das pastas e passagem dos registros da `feat/agenda`).

## 1. Como fica (resumo)
1. Primeiro commit traz os registros que estão só na `feat/agenda` (§3), sem conflito e com a CI verde.
2. A regra das pastas passa a morar em `docs/guias/pastas.md` (§2); a auditoria e as 4 revisões de conversa vão para
   `docs/auditorias/`.
3. As travas T1 a T8 e as ordens de 28/11 entram nos arquivos donos, cada arquivo com um papel só (§4).
4. Os 10 arquivos de `.claude/` ficam num bloco próprio, feito com o dono presente para dar a permissão (§5).
5. Commits por tema, um agente por arquivo de cada vez (§6). Prova no §7.

## 2. Regra das pastas (RF-18 a RF-20)

### 2.1 O texto da regra (vai para `docs/guias/pastas.md`, escrito pelo Arquiteto)
Teste de uma pergunta: **o arquivo acaba com a tarefa?** Sim → `specs/<pasta>/`. Não (vale depois dela ou para mais
de uma) → `docs/`.

| Lugar | Só isto | Quem grava |
|---|---|---|
| `specs/<AAAAMMDD-HHMMSS-nome>/` | `spec.md`, `plan.md`, `tasks.md`; o que o Spec Kit gera ali (`research.md`, `data-model.md`, `contracts/`, `quickstart.md`, `checklists/`); `ficha-visual.md` e `ficha/` (imagens); as revisões gravadas da tarefa, uma por papel: `revisao-<papel>.md` (ex.: `revisao-design.md`, T1; `revisao-5b.md`); nova rodada entra como seção nova no mesmo arquivo | o papel da etapa |
| `docs/auditorias/AAAA-MM-DD-<assunto>.md` | auditoria de processo ou de coerência que vale para mais de uma tarefa | quem audita; o Documentador arquiva |
| `docs/auditorias/conversas/AAAA-MM-DD-sessao-<id curto>.md` | revisão de conversa (o que foi dito × onde está registrado) | Documentador |
| `docs/produto/avaliacao-crm-agenda/<módulo>-ideias.md` | leitura do projeto antigo (só leitura, E43·A, E44) | Analista de requisitos |
| `docs/decisoes/` · `docs/adr/` · `docs/guias/` · `docs/moldes/` · `docs/design/` · `docs/produto/` · `docs/BACKLOG.md` · `docs/STATUS.md` | como no `AGENTS.md` §10 | o dono do arquivo |

- **Exceção nomeada:** `specs/20261128-005000-fundacao-tecnica/travas-claude-propostas/` (a CI lê
  `specs/*/travas-claude-propostas/`; sai no PR das travas do Claude, E38·A1).
- **O que não cabe em nenhum lugar:** não se grava. O Documentador aponta o arquivo solto e o Arquiteto decide o
  lugar em ADR antes do commit. Pasta nova em `docs/` só por ADR.
- **Nunca no repositório:** rascunho de sessão (pasta temporária), cópia de conversa inteira, dado pessoal de
  terceiros, segredo.
- O `AGENTS.md` §10 (Mapa) ganha: "pastas `docs/guias/pastas.md` · auditorias `docs/auditorias/`" (CA-04).

### 2.2 Conferência dos arquivos de hoje (RF-19)

| Arquivo | Onde está | Fica ou vai | Motivo |
|---|---|---|---|
| spec, plan, tasks de `produto-modulos`, `ordem-e21`, `fundacao-tecnica`, `banco-ligacao`, `design-system-codigo`, `entrar-servico` | `previas` | fica | é da tarefa |
| `ficha-visual.md` e `ficha/` de `design-system-codigo` e `entrar-servico` | `previas` | fica | é da tarefa |
| `fundacao-tecnica/travas-claude-propostas/` (7 arquivos) | `previas` | fica (exceção) | a CI lê esse caminho; item 2 aberto |
| `docs/produto/avaliacao-crm-agenda/` (3 arquivos) | `previas` | fica | já é o lugar das leituras do antigo |
| `docs/design/canvas/`, `docs/design/imagens/` | `previas` | fica | histórico do design (E10·1); nomes: E66·3 |
| `specs/20261128-020000-agenda/auditoria-processo.md` | só `feat/agenda` | **vai** para `docs/auditorias/2026-11-28-processo-agenda.md` (cópia exata, nesta branch) | vale para o processo todo, não só para a Agenda; é a fonte do 4b |
| `specs/20261128-020000-agenda/ideias-do-antigo.md` | só `feat/agenda` | **vai**, mas na `feat/agenda`, para `docs/produto/avaliacao-crm-agenda/agenda-ideias.md` | é leitura do antigo; só a Agenda usa (RF-23); linha no item 5 da fila |
| `specs/20261128-020000-agenda/` spec, plan, tasks, ficha-visual, ficha/ | só `feat/agenda` | fica | é da tarefa |
| 4 revisões de conversa (`sessao-7Rj.md`, `sessao-9ep.md`, `sessao-8F1.md`, `sessao-958.md`) | fora do repositório (pasta temporária da sessão) | **entram** em `docs/auditorias/conversas/2026-11-28-sessao-<id>.md`, cópia exata, depois da conferência do Engenheiro de segurança | são a fonte da tabela §3 da spec; sem elas o dono não abre a origem (RF-12). Conferência feita aqui: sem dado de terceiros, sem segredo; só falas do próprio dono (como já em `docs/decisoes/`), ids de sessão já públicos e o caminho local da pasta. Se a conferência achar dado de terceiro, aquele arquivo não entra e a linha dele fica "não verificado" |
| `docs/guias/.gitkeep`, `docs/moldes/.gitkeep`, `specs/.gitkeep` | `previas` | fica | não atrapalha; tirar não é pedido |

### 2.3 Links que mudam (RF-19)
- `docs/decisoes/2026-11-27-fundacao.md`, linha "E65 (sim)" (ainda não está na `previas`; pode mudar): link da
  auditoria passa a `https://github.com/alexandrergomes1/crm-citas/blob/previas/docs/auditorias/2026-11-28-processo-agenda.md`.
- `docs/STATUS.md`: links para a auditoria (Documentador reescreve o estado de qualquer modo).
- Esta spec, "Fontes" e título do Anexo A: caminho novo da auditoria e das 4 revisões (Analista).
- Na `feat/agenda` (depois, fora deste PR): os links da spec e do plano da Agenda para a auditoria e para as ideias.

### 2.4 Resposta ao dono (RF-20, uma linha, na mensagem de aprovação)
"Não estava certo: a pasta de cada tarefa passa a guardar só spec, plano, tarefas, ficha e as revisões dela;
auditorias e revisões de conversa vão para [docs/auditorias](https://github.com/alexandrergomes1/crm-citas/tree/chore/processo-revisao/docs/auditorias),
e a regra fica em [docs/guias/pastas.md](https://github.com/alexandrergomes1/crm-citas/blob/chore/processo-revisao/docs/guias/pastas.md)
(plano: [plan.md §2](https://github.com/alexandrergomes1/crm-citas/blob/chore/processo-revisao/specs/20261128-180247-processo-revisao/plan.md))."
Os links valem depois do commit 2 (pastas); antes dele, o link do plano é o único que abre. Depois do merge, o
Documentador troca `chore/processo-revisao` por `previas` nos links que ficarem em arquivo.

## 3. Registros que estão só na `feat/agenda` (spec §9, ADR 0022)

### 3.1 O que entra, como (primeiro commit: Documentador nos registros e na auditoria; Engenheiro de DevOps só nas duas specs)
| Arquivo | Como | Confere |
|---|---|---|
| `docs/BACKLOG.md` | cópia exata do `85501a0` | `git diff 85501a0 -- docs/BACKLOG.md` vazio |
| `docs/STATUS.md` | cópia exata do `85501a0` | idem |
| `specs/20261128-010000-banco-ligacao/spec.md` e `specs/20261128-010500-design-system-codigo/spec.md` | cópia exata do `85501a0` ("Aprovação do merge" dos itens 3 e 4, commit `5cf0e08`) | idem |
| `docs/decisoes/2026-11-27-fundacao.md` | cópia do `85501a0` **menos uma linha**: a E26·1·B fica igual à da `previas`; o texto da substituição vai como linha nova no fim, "E26·1·B (substituída na Agenda e no Agendamento)", com a fala literal da ordem de 28/11 já citada na linha da `feat/agenda` | `git diff origin/previas` só com linhas acrescentadas; trava `decisao-com-prova.mjs origin/previas` com saída 0 |
| `docs/auditorias/2026-11-28-processo-agenda.md` | cópia exata de `85501a0:specs/20261128-020000-agenda/auditoria-processo.md` | `git diff 85501a0:<antigo> HEAD:<novo>` vazio |

Fato conferido nesta sessão (pasta temporária, apagada depois): a cópia exata das decisões reprova a trava
(`linha já gravada mudou ou sumiu: | E26·1·B |`); com a E26·1·B igual à da `previas` e a linha nova, a trava passa.

**Não entram:** `DESIGN.md` da Agenda (E59, E60), ADR 0006 e 0021, spec, plano, tarefas e ficha da Agenda, a ficha
do Entrar mudada na `feat/agenda`. São da Agenda e não estão autorizados a entrar na `previas` (spec §8). O `DESIGN.md`
§10 item 9 (T1) entra aqui no fim da lista; a `feat/agenda` mexeu só no item 1, 7 linhas acima: o merge junta sem
conflito (a conferir no passo 3 do §3.2).

### 3.2 Ordem de merge recomendada
1. **Congelar:** até o merge do 4b, nenhum commit na `feat/agenda` em `docs/BACKLOG.md`, `docs/STATUS.md`,
   `docs/decisoes/`, nas duas specs copiadas e no `DESIGN.md` §10. Resposta nova do dono se grava nesta branch.
2. **`chore/processo-revisao` → `previas`** (PR, CI verde, revisão, autorização do dono).
3. **`previas` → `feat/agenda`** (merge, Engenheiro de DevOps, como no `af9b196`): nos três documentos de controle,
   fica a versão da `previas`; conferir com `git diff 85501a0 HEAD -- <arquivo>` que só aparece o que o 4b
   acrescentou. Isso também conserta a linha E26·1·B que reprovaria a CI do PR da Agenda. Depois, na própria
   `feat/agenda`: apagar a auditoria velha, mover as ideias (§2.2), corrigir links, ficha T7 (RF-07).
4. O PR das travas do Claude (E38·A1) não tem arquivo em comum com o 4b fora da fila e do estado; pode vir antes ou
   depois. A posição na fila é do dono; o técnico só pede que quem vier depois traga a `previas` antes do PR.
   **Se a E38·A1 entrar antes**, o caminho da trava muda de
   `specs/20261128-005000-fundacao-tecnica/travas-claude-propostas/decisao-com-prova.mjs` para
   `.claude/hooks/decisao-com-prova.mjs` (destino escrito no próprio arquivo): os comandos do §3.1 e do §7 usam o novo,
   e a exceção do §2.1 deixa de existir.
5. As outras branches de módulo (`feat/agendamento` e as demais): trazem a `previas` antes de qualquer trabalho.

## 4. Arquivos permitidos (lista fechada, CA-07)
Um papel por arquivo. "Revisa" é a etapa 9 (texto, outro papel que não escreveu). O Gerente de projeto só tem
Read, Grep e Glob (`.claude/agents/gerente-projeto.md`): não escreve nada; revisa. `AGENTS.md`, `processo-sdd.md` e
o molde passam ao Analista de requisitos, e o Gerente revisa. Os relatórios de quem só lê (Gerente, Revisor de
design) são gravados, com o texto literal deles, pelo Documentador. Na etapa 10 o Analista confere cada RF e cada
linha do §3 da spec; nos três arquivos que ele mesmo escreveu, vale a revisão do Gerente (quem constrói não revisa).

| # | Arquivo | O que muda | Requisito / linha §3 | Escreve | Revisa |
|---|---|---|---|---|---|
| 1 | `docs/BACKLOG.md` | cópia (§3.1); seção "Propostas e itens a decidir (sem ordem)" com a frase "a ordem é do dono"; linhas de fila, "a decidir" e "fora" | RF-06, RF-07, RF-09, RF-13, RF-22, RF-23; §3: 3, 7, 17, 20, 21, 23, 24, 25 (se E66·2·A), 26–29, 34, 36, 39 (item de construção, se A ou B), 40, 43, 46, 47, 51, 52 | Documentador | Gerente |
| 2 | `docs/STATUS.md` | cópia; estado do 4b; links novos; 18, 41, 53 | RF-17, RF-23; §3: 18, 41, 53 | Documentador | Gerente |
| 3 | `docs/decisoes/2026-11-27-fundacao.md` | linhas novas (§3.1); linha da aprovação desta spec, que libera a mudança do `AGENTS.md` (linha 9); link da E65; linhas novas: crítica E38, "me cabe julgar", 49, 50, 53, 54 (revisão das conversas feita), branch `chore/base-fundacao` apagada; respostas E66 | RF-11, RF-16, RF-17; §3: 5, 11, 18, 49, 50, 53, 54 | Documentador | Gerente |
| 4 | `specs/20261128-010000-banco-ligacao/spec.md`, `specs/20261128-010500-design-system-codigo/spec.md` | só a cópia exata | §3: 17 | Engenheiro de DevOps | Gerente |
| 5 | `docs/auditorias/2026-11-28-processo-agenda.md` | cópia exata (1º commit) | RF-19 | Documentador | Gerente |
| 6 | `docs/auditorias/conversas/2026-11-28-sessao-7Rj.md`, `-9ep.md`, `-8F1.md`, `-958.md` | cópia exata, depois da conferência | RF-17, RF-19 | Documentador (conferência antes: Engenheiro de segurança) | Gerente |
| 7 | `docs/guias/pastas.md` (novo) | a regra do §2.1 | RF-18 | Arquiteto | Gerente |
| 8 | `docs/adr/0022-...md` | este commit; Status muda para Aceito na aprovação | RF-18, spec §9 | Arquiteto | Gerente (5b) |
| 9 | `AGENTS.md` | §4 T5; §5 RF-13; §6 T6; §7 RF-10 e RF-12; §10 mapa. **Só muda com a aprovação do dono registrada em `docs/decisoes/`** (cabeçalho do `AGENTS.md`): a "Aprovação do dono" desta spec ganha também uma linha nas decisões (Documentador, linha 3), antes deste arquivo mudar | RF-05, RF-06, RF-10, RF-12, RF-13, CA-04 | Analista de requisitos | Gerente |
| 10 | `docs/guias/processo-sdd.md` | etapa 3 (E44), etapa 6 (T2), etapa 7 (T5), linha 7b (T4); sai o §6 "Lacuna" | RF-02, RF-04, RF-05, RF-09; §3: 2, 14 | Analista de requisitos | Gerente |
| 11 | `docs/moldes/pergunta.md` | bloco "▶ PRECISA DE VOCÊ" / "▶ Nada para você" e "Só para informar"; "o que é" e "o que muda" antes das opções; link clicável; "Como voltar atrás" (A2); "Ficha visual": referências para agregar e "decisão simples"; "o dono decide pelo que vê"; "Proibido": mensagem só com códigos, caminho solto | RF-10, RF-11, RF-12, RF-15, RF-16; §3: 4, 5, 6, 10, 11, 13 | Analista de requisitos | Gerente |
| 12 | `DESIGN.md` | §10 item 9 (T1), texto do Anexo A | RF-01; §3: 10 | Designer de produto | Revisor de design |
| 13 | `ARCHITECTURE.md` | §11: tira "larguras que o `DESIGN.md` vai definir" e aponta 390 e 1440; §9 recuperação a qualquer momento como opção futura paga; §12 só gratuito (E23·3·A) e R2 para arquivos; módulo opcional por estúdio (E31·1); exceções E40·B e E39·3·i apontam para `SECURITY.md` §5; §11 página de status só se E66·2·B | RF-09, RF-21; §3: 2, 25, 27, 35, 42, 44, 45 | Arquiteto | Gerente |
| 14 | `src/app/AGENTS.md` | linha 22: larguras 390 e 1440 px (E15·1), sem citar o §6 que sai | RF-09; §3: 2 | Arquiteto | Gerente |
| 15 | `SECURITY.md` | §7: termos e política de privacidade; os 7 itens de 27/11 (relidos na conversa 7Rj; o que não achar: "não verificado"); banco online (hash da chave do servidor, chave assimétrica); prazo de guarda (E66·1) | RF-21; §3: 24, 30, 37, 39 | Engenheiro de segurança | Gerente |
| 16 | `CONTRIBUTING.md` | cabeçalho "Aprovado pelo dono (E14)"; links de `feat/entrar-servico` → `previas`; §8 "não anexar o `crm-agenda` à sessão sem autorização"; gitleaks na sessão (aponta ADR 0024) | RF-09; §3: 2, 16, 32 | Engenheiro de DevOps | Gerente |
| 17 | `docs/adr/0023-pasta-de-trabalho-por-agente.md` (novo) | `git worktree` por agente que escreve em paralelo | RF-06 | Engenheiro de DevOps | Arquiteto |
| 18 | `docs/adr/0024-gitleaks-na-sessao.md` (novo) | gitleaks também antes de enviar, na sessão | §3: 32 | Engenheiro de DevOps | Arquiteto |
| 19 | `docs/adr/0025-skills-do-tanstack.md` (novo) | manter ou não as skills do TanStack | §3: 38 | Engenheiro de DevOps | Arquiteto |
| 20 | `docs/produto/README.md` | Fresha como referência para avaliar e agregar | §3: 22 | Analista de requisitos | Gerente |
| 21 | `docs/produto/cadastro-de-estudio-e-assinatura.md` | cadastro sozinho e teste do estúdio novo, como "a decidir" (dinheiro) | §3: 23 | Analista de requisitos | Gerente |
| 22 | `docs/produto/equipe.md` | convite e cadastro de equipe (72 bytes, "Esqueci a senha" E39·1·B, trava antes de estúdios reais); grade por profissional | §3: 40, 51 | Analista de requisitos | Gerente |
| 23 | `docs/produto/caixa.md` | caixa opcional por estúdio (E31·1) | §3: 44 | Analista de requisitos | Gerente |
| 24 | `docs/produto/central-de-ajuda.md` | "como a da Cloudflare" | §3: 31 | Analista de requisitos | Gerente |
| 25 | `specs/20261128-180247-processo-revisao/spec.md` | "Em dia com"; caminhos novos (§2.3); Status e "Aprovação do dono" na etapa 7; "Aprovação do merge" na 13 (DevOps) | RF-03, RF-19 | Analista de requisitos (merge: DevOps) | Gerente |
| 26 | `specs/20261128-180247-processo-revisao/plan.md`, `tasks.md` | estes arquivos; "Em dia com" a cada resposta | RF-03 | Arquiteto | Gerente (5b) |
| 27 | `specs/20261128-180247-processo-revisao/revisao-5b.md`, `revisao-texto.md`, `revisao-design.md` (novos) | relatórios gravados das revisões (regra §2.1), texto literal de quem revisou | CA-08 | Documentador (Gerente e Revisor de design só leem) | — |
| 28 | `CHANGELOG.md` | uma linha do 4b | AGENTS.md §9 | Documentador | Gerente |
| 29 | `docs/design/README.md` e `docs/design/canvas/*` | só se E66·3 for B (trocar nomes) ou C (apagar) | §3: 33 | Designer de produto | Revisor de design |
| 30–39 | os 10 arquivos de `.claude/` do §5 | — | — | Arquiteto | ver §5 |

Fora da lista, nada muda. `.claude/settings.json`, `.claude/hooks/` e `.github/` não mudam (spec §8).

## 5. Arquivos de `.claude/` (E38·A: permissão do dono na hora)
| # | Arquivo | O que muda | Requisito | Revisa |
|---|---|---|---|---|
| 30 | `.claude/agents/revisor-design.md` | "Faz": texto T1; divergência entre o escrito e o construído bloqueia | RF-01, RF-14(2) | Revisor de design (o arquivo é dele, não o escreveu) e Gerente |
| 31 | `.claude/agents/designer-produto.md` | "Nunca": texto T2; "Faz": referências para agregar, nunca copiar; "decisão simples" = dentro do limite da T2 | RF-02, RF-15 | Revisor de design |
| 32 | `.claude/agents/analista-requisitos.md` | "Faz": texto T8; ler a parte do antigo do módulo ao fazer a spec (E44) | RF-08; §3: 14 | Gerente |
| 33 | `.claude/agents/documentador.md` | registrar toda proposta futura no mesmo turno; conferir, depois de cada resposta, que cada papel gravou (A3) | RF-13; §3: 9 | Gerente |
| 34 | `.claude/agents/revisor-codigo.md` | divergência entre o escrito e o construído bloqueia | RF-14(2) | Gerente |
| 35 | `.claude/agents/gerente-projeto.md` | "Quando": etapa 7b (portão). **Fora da lista provável da spec §7**: a T4 manda "o portão 7b do `gerente-projeto`" e o agente não tem a etapa | RF-04 | Gerente (o arquivo é dele, mas quem escreve é o Arquiteto) |
| 36 | `.claude/skills/falar-com-o-dono/SKILL.md` | passo 9 = T3; bloco do que precisa do dono; links clicáveis | RF-03, RF-10, RF-12 | Analista |
| 37 | `.claude/skills/construir-tarefa/SKILL.md` | passo 0: frase da T4 | RF-04 | Gerente |
| 38 | `.claude/skills/planejar-tarefa/SKILL.md` | ler a parte do antigo do módulo (E44), com autorização | §3: 14 | Gerente |
| 39 | `.claude/skills/trazer-do-antigo/SKILL.md` | avaliar sem tendência, o antigo não é verdade; não anexar o `crm-agenda` à sessão sem autorização | §3: 15, 16 | Gerente |

**Como fica a permissão:**
- A mensagem de aprovação da spec avisa, numa linha do bloco "precisa de você": "na construção, o Claude vai pedir 10
  vezes permissão para gravar em `.claude/` (lista no plano §5); aceite cada uma; recusou, aquele arquivo fica
  pendente".
- Os 10 arquivos são feitos juntos, num bloco só (tarefa T-C do `tasks.md`), na conversa principal e com o dono
  presente, para que os pedidos de permissão cheguem a ele de uma vez. Não verificado se um subagente em segundo plano
  consegue fazer o pedido; por isso, conversa principal.
- Sem a permissão (dono ausente ou recusa): o arquivo não muda, a linha dele fica "pendente" na spec (§9 dela) e na
  fila, e o resto do 4b segue. RF-01 a RF-04, RF-08, RF-14 e RF-15 só ficam "feito" com os arquivos de `.claude/`
  gravados; sem eles, saem "em parte" no pedido de merge, e o dono decide se junta assim.
- Nenhum desses arquivos é `settings.json` nem gancho: a trava de comandos (`git stash*`, `git reset --hard*`) segue
  no PR da E38·A1.

## 6. Ordem e paralelismo (T6)
- **Um arquivo, um agente por vez.** Cada tarefa do `tasks.md` tem um papel e uma lista de arquivos; duas tarefas só
  rodam juntas quando as listas não se cruzam, e cada agente faz commit do que é seu antes de devolver. Proibido
  `git stash`, `git reset --hard` e `git checkout -- <arquivo>`. Até a ADR 0023 existir, o recomendado é uma tarefa
  de cada vez nesta pasta de trabalho.
- **Commits por tema** (spec §9), na ordem: (1) registros trazidos · (2) pastas · (3) travas nos arquivos fora de
  `.claude/` · (4) molde e `AGENTS.md` §7 · (5) `.claude/` · (6) registros das 4 revisões (produto, segurança,
  planta, ADRs) · (7) fecho do Documentador. Cada commit cita a spec (Conventional Commits).

## 7. Prova (`AGENTS.md` §9, tipo texto)
- **Revisão de texto por outro papel** (coluna "Revisa" do §4 e §5), gravada em `revisao-texto.md` e, para o
  `DESIGN.md` §10 e os agentes de tela, em `revisao-design.md`. Nenhum "Bloqueia".
- **Etapa 10:** o Analista confere RF-01 a RF-23 e cada linha da tabela §3 ("feito", "fila" ou "fora, com motivo").
- **CI verde nos 5 jobs.** O job `travas` importa aqui: o passo "Aprovações com prova" confere as decisões (só
  acrescentar) e as linhas de aprovação das specs; os testes de gancho não mudam, porque nenhum gancho muda. O job
  `segredos` (gitleaks) varre as cópias em `docs/auditorias/`.
- **Antes de enviar, na sessão:** `pnpm typecheck`, `pnpm lint`, `pnpm test` (`AGENTS.md` §1) e
  `node specs/20261128-005000-fundacao-tecnica/travas-claude-propostas/decisao-com-prova.mjs origin/previas` com saída 0
  (se a E38·A1 entrar antes: `node .claude/hooks/decisao-com-prova.mjs origin/previas`, §3.2 passo 4).
- **Conferência das cópias:** `git diff` vazio contra `85501a0` nos arquivos do §3.1 (menos a linha E26·1·B).

## 8. Riscos
| Risco | Como se trata |
|---|---|
| Commit na `feat/agenda` nos documentos de controle antes do merge do 4b | congelamento (§3.2 passo 1); se acontecer, o Documentador leva a linha para esta branch antes do PR |
| Dono não está presente para a permissão de `.claude/` | os 10 arquivos ficam "pendentes" (§5); o resto segue |
| Revisão de conversa com dado de terceiro | conferência do Engenheiro de segurança antes do commit; achou, o arquivo não entra |
| PR grande | commits por tema (§6); revisão por commit |
| A T1 diz que o Revisor de design "grava o relatório", mas o agente dele só lê | o Documentador grava o texto literal do relatório; muda o lugar, não o sentido (spec A6). Dar Write ao revisor seria mudança de regra: fica para o dono, se quiser |
| Itens que pedem reler conversa (§3: 30, 49) | quem relê grava o que achar; o que não achar sai "não verificado", sem inventar (CA-06) |

## 9. Decisões técnicas deste plano (cada uma em uma linha)
1. Regra das pastas em `docs/guias/pastas.md`, apontada pelo `AGENTS.md` §10 (ADR 0022).
2. `docs/auditorias/` nova, com `conversas/` (ADR 0022).
3. As 4 revisões de conversa entram no repositório, cópia exata, depois da conferência de segurança.
4. Registros trazidos por cópia de arquivo, não por merge nem cherry-pick; a E26·1·B fica como na `previas` e a
   substituição vira linha nova, porque a trava da CI só aceita acrescentar (conferido).
5. Ordem: 4b na `previas` primeiro; depois a `feat/agenda` traz a `previas`, fica com a versão dela nos documentos de
   controle e faz as próprias mudanças de lugar.
6. `gerente-projeto.md` entra na lista por causa da T4 (fora da lista provável da spec).
7. Os 10 arquivos de `.claude/` num bloco só, na conversa principal, com o dono presente.
8. O Gerente só lê (Read, Grep, Glob): revisa tudo e não escreve; `AGENTS.md`, guia e molde são do Analista; os
   relatórios de quem só lê, o Documentador grava (ajuste da 5b).
9. Cópia dos registros e da auditoria: Documentador (`AGENTS.md` §2); Engenheiro de DevOps só nas duas specs.
10. `AGENTS.md` só muda depois da linha de aprovação nas decisões (cabeçalho do `AGENTS.md`).

## 10. Não verificado
- Que o merge `previas` → `feat/agenda` junte o `DESIGN.md` §10 sem conflito (só calculado pela distância dos
  trechos; confere-se no passo 3 do §3.2).
- Se um subagente consegue pedir a permissão de `.claude/` ao dono.
- O conteúdo dos 7 itens de segurança de 27/11 e da resposta das 14:17 (dependem de reler a conversa).
- As fontes legais da recomendação E66·1 (Engenheiro de segurança confere).
