# Tarefas · Revisão do processo (item 4b da fila)

- **Em dia com:** E67·A (28/11/2026; E66·1 a E66·3 em aberto, na aprovação da spec) · ajustes da 5b aplicados
- **Spec:** `spec.md` · **Plano:** `plan.md` · **Escrito por:** Arquiteto de software · **Norma:** modelo C4 e ADR
- **Regra (T6):** um arquivo, um agente por vez; cada tarefa faz commit do que é sua antes de devolver; proibido
  `git stash`, `git reset --hard` e `git checkout -- <arquivo>`. Tarefas marcadas **[P]** podem rodar juntas (os
  arquivos não se cruzam). Sem a ADR 0023, recomenda-se uma de cada vez.
- **Nada começa antes** da spec com "Status: Approved" e da etapa 7b (portão do Gerente), já pela T4.

## Antes da construção (etapas 5 a 7)
- [ ] **T-00 · Gerente de projeto (5b):** revisa spec, plano, tarefas e ADR 0022 (só lê). **Documentador** grava o
  relatório literal em `revisao-5b.md`.
- [ ] **T-01 · Analista de requisitos (7):** mensagem de aprovação no molde (E66·1 a E66·3; linha RF-20 do plano §2.4;
  aviso dos 10 pedidos de permissão de `.claude/`); grava "Aprovação do dono" e as respostas E66 na spec. O
  **Documentador** grava a mesma aprovação em `docs/decisoes/` (libera a mudança do `AGENTS.md`).
- [ ] **T-02 · Gerente de projeto (7b):** spec, plano e tarefas com o mesmo "Em dia com"; 5b sem "pendente".

## Commit 1 · Registros trazidos da `feat/agenda` (plano §3.1)
- [ ] **T-10 · Documentador:** copia de `85501a0` `docs/BACKLOG.md`, `docs/STATUS.md` e as decisões, com a E26·1·B
  igual à da `previas` e a linha nova "E26·1·B (substituída na Agenda e no Agendamento)"; copia a auditoria para
  `docs/auditorias/2026-11-28-processo-agenda.md`.
- [ ] **T-11 · Engenheiro de DevOps [P com T-10]:** copia de `85501a0` as duas specs (`banco-ligacao`,
  `design-system-codigo`).
- Confere (T-10 e T-11): `git diff 85501a0` vazio nos arquivos exatos; trava `decisao-com-prova.mjs origin/previas`
  com saída 0 (caminho do plano §7).

## Commit 2 · Pastas (RF-18 a RF-20)
- [ ] **T-20 · Engenheiro de segurança:** confere as 4 revisões de conversa (dado de terceiro, segredo); veredito por
  arquivo, em `revisao-texto.md`.
- [ ] **T-21 · Documentador:** copia as aprovadas na T-20 para `docs/auditorias/conversas/2026-11-28-sessao-<id>.md`.
- [ ] **T-22 · Arquiteto [P com T-21]:** escreve `docs/guias/pastas.md` (plano §2.1).
- [ ] **T-23 · Analista de requisitos [P com T-21 e T-22]:** caminhos novos na spec ("Fontes", Anexo A).

## Commit 3 · Travas fora de `.claude/` e linhas velhas (RF-01, 02, 04, 05, 06, 09)
- [ ] **T-30 · Designer de produto:** `DESIGN.md` §10 item 9 (T1).
- [ ] **T-31 · Analista de requisitos [P com T-30, T-32, T-33]:** `docs/guias/processo-sdd.md`: etapa 3 (E44), etapa 6
  (T2), etapa 7 (T5), linha 7b (T4), tira o §6.
- [ ] **T-32 · Arquiteto [P]:** `ARCHITECTURE.md` §11 (larguras) e `src/app/AGENTS.md` linha 22.
- [ ] **T-33 · Engenheiro de DevOps [P]:** `CONTRIBUTING.md` (cabeçalho, links para `previas`, §8 "não anexar o
  `crm-agenda` sem autorização", gitleaks na sessão).
- [ ] **T-34 · Analista de requisitos (depois da T-31 e da linha de aprovação nas decisões, T-01):** `AGENTS.md` §4 (T5), §6 (T6).

## Commit 4 · Molde e `AGENTS.md` (RF-10 a RF-13, RF-16; CA-02, CA-03, CA-04)
- [ ] **T-40 · Analista de requisitos:** `docs/moldes/pergunta.md` (plano §4 linha 11).
- [ ] **T-41 · Analista de requisitos (depois da T-40):** `AGENTS.md` §5 (RF-13), §7 (RF-10, RF-12), §10 (pastas e auditorias).

## Commit 5 · `.claude/` (E38·A: permissão do dono na hora; plano §5)
- [ ] **T-C · Arquiteto, na conversa principal, com o dono presente:** os 10 arquivos do plano §5 (linhas 30 a 39),
  um de cada vez. Cada pedido de permissão recusado: o arquivo fica "pendente" na spec e na fila; os outros seguem.

## Commit 6 · Registros das 4 revisões (RF-21, RF-22; plano §4 linhas 13, 15, 17 a 24)
- [ ] **T-60 · Arquiteto [P]:** `ARCHITECTURE.md` §9, §12, módulo opcional, exceções → `SECURITY.md` §5; §11 só se E66·2·B.
- [ ] **T-61 · Engenheiro de segurança [P]:** `SECURITY.md` §7 (termos e privacidade, 7 itens relidos na 7Rj,
  banco online, guarda E66·1).
- [ ] **T-62 · Engenheiro de DevOps [P]:** ADR 0023 (`git worktree` por agente), 0024 (gitleaks na sessão), 0025
  (skills do TanStack).
- [ ] **T-63 · Analista de requisitos [P]:** `docs/produto/README.md`, `cadastro-de-estudio-e-assinatura.md`,
  `equipe.md`, `caixa.md`, `central-de-ajuda.md`.
- [ ] **T-64 · Designer de produto [P]:** `docs/design/` só se E66·3 for B ou C.

## Commit 7 · Fecho (etapa 11)
- [ ] **T-70 · Documentador:** fila (seção sem ordem, "a decidir", linhas "fora"; itens 2, 3, 4, 4b, 5; item novo
  "guardar o IP de cada entrada", com spec própria, se E66·1·A, linha 57 da spec), estado,
  decisões (linhas do plano §4 linha 3), `CHANGELOG.md`; confere que cada papel gravou (A3).
- [ ] **T-71 · Arquiteto:** ADR 0022 "Aceito"; "Em dia com" do plano e das tarefas.

## Revisão e merge (etapas 9 a 13)
- [ ] **T-90 · Revisores (plano §4 e §5, coluna "Revisa"):** um relatório por papel; Revisor de design em
  `revisao-design.md`, os outros em `revisao-texto.md`; o Documentador grava o texto literal de quem só lê. Nenhum "Bloqueia".
- [ ] **T-91 · QA:** veredito com a CI verde (5 jobs) e a trava de aprovações com saída 0.
- [ ] **T-92 · Analista de requisitos (10):** RF-01 a RF-23 e cada linha do §3 da spec.
- [ ] **T-93 · Gerente de projeto (12):** pedido de merge no molde novo, com a ordem de merge do plano §3.2.
- [ ] **T-94 · Engenheiro de DevOps (13):** grava "Aprovação do merge" e junta só o commit autorizado.

## Depois do merge (fora deste PR; linha no item 5 da fila)
- [ ] **Engenheiro de DevOps, na `feat/agenda`:** merge da `previas`, com a versão dela nos documentos de controle.
- [ ] **Documentador e Analista, na `feat/agenda`:** apagar a auditoria velha, mover `ideias-do-antigo.md` para
  `docs/produto/avaliacao-crm-agenda/agenda-ideias.md`, corrigir links; depois, a ficha T7 do Designer.
