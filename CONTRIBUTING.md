# Como contribuir

Vale para qualquer IA ou pessoa. A regra está no `AGENTS.md`; o passo a passo está em `docs/guias/processo-sdd.md` (spec, plano, aprovação) e `docs/guias/git-e-deploy.md` (branch, CI, merge, publicação). Este arquivo é o caminho em uma página.

## 1. Escolher a tarefa
Só o primeiro item livre de `docs/BACKLOG.md` ou um pedido do dono com a citação literal. Item parado esperando o dono: siga para o próximo da fila, na ordem, se estiver livre e não depender da resposta; na dúvida, pare.

## 2. Branch
Uma tarefa, uma branch `tipo/area-assunto` (ex.: `feat/agenda-lista`, `chore/base-enxuta`), criada a partir da `previas`. Antes de começar, a conferência (`scripts/conferir-pedido.mjs`): teto de PRs e colisão em `docs/guias/processo-sdd.md` (Planejar, passo 2).

## 3. Spec (SDD com o GitHub Spec Kit)
- Nada se constrói sem **spec aprovada**: `specs/NNN-nome/spec.md` com "Status: Approved" e a linha "Aprovação do dono" (resposta literal, data, link da conversa).
- Cada tarefa tem a pasta `specs/NNN-nome/` (`spec.md`, `plan.md`, `tasks.md`), numerada por data e hora. Moldes em `.specify/templates/overrides/`; spec curta em `docs/moldes/spec-curta.md` (só texto, link, documento, biblioteca sem mudança de comportamento; nunca tela, banco, dinheiro ou acesso).
- O plano lista os **arquivos permitidos**; só eles mudam.
- Até 3 dúvidas por spec, juntas na mesma mensagem de aprovação, no molde `docs/moldes/pergunta.md`. A aprovação é de um resumo curto.
- Primeira tarefa num módulo: antes, a ficha curta do passado (`AGENTS.md` §3). Tela: antes, a ficha visual (`DESIGN.md`, `docs/guias/telas.md`).

## 4. Construir
- Siga o guia da área (`docs/guias/banco.md`, `servidor.md`, `telas.md`, `testes.md`, `porte.md`…) e o `AGENTS.md` da pasta.
- Antes de enviar: `pnpm typecheck` · `pnpm lint` · `pnpm test`. Isso só evita envio quebrado; a prova é a CI.
- Commits pequenos, Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`), citando a spec.
- Os documentos de controle (lista em `docs/guias/processo-sdd.md`) vão no PR da própria tarefa.

## 5. PR, CI e revisão
- PR para a `previas`, com o molde `.github/pull_request_template.md`. Nunca envio direto à `previas` nem à `main`.
- A CI do GitHub roda tipos, lint, testes, build, banco do zero com testes e, fora de rascunho, ponta a ponta nas duas larguras (`DESIGN.md` §11) com capturas e procura de segredos. Lista das rotinas: `docs/guias/git-e-deploy.md`.
- Revisores do tipo de trabalho (`docs/guias/revisao.md`), sem "Bloqueia". Quem constrói não revisa.
- Tela: o dono confere na prévia da branch antes do merge.

## 6. Merge (autorizado pelo dono)
Regra: `AGENTS.md` §6. Passo a passo do merge, prova local (CI sem minutos do GitHub) e publicação na produção: `docs/guias/git-e-deploy.md`.

## 7. Travas
Programas que barram ações perigosas (envio direto às branches protegidas, envio forçado, merge sem autorização, publicação à mão, migration no banco remoto, leitura de `.env`): `.claude/hooks/TRAVAS.md`. Para quem não usa o Claude Code (Cursor, Codex, pessoa), as regras de envio valem pelo gancho `.githooks/pre-push`, ligado com `git config core.hooksPath .githooks`.

## Pronto quando
`AGENTS.md` §7.

## Origem
`AGENTS.md` 2.0 §2, §3, §6, §7 · `docs/projeto/tecnico.md` §CI, §Merge e publicação, §Fila, §Conferências, §Spec Kit · `docs/projeto/estrutura.md` §Controle, §Spec curta · `.claude/hooks/TRAVAS.md` §1, §2, §3, §5, §7 · `docs/moldes/pergunta.md` · `docs/reorganizacao/06-plano-etapa5.md` §5b.
