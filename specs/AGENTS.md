# Pasta: specs · especificações (GitHub Spec Kit)

Vale junto com o `AGENTS.md` da raiz.

**O que mora aqui:** uma pasta por tarefa, `specs/AAAAMMDD-HHMMSS-nome/`, com `spec.md` (o quê), `plan.md` (o como) e `tasks.md` (as tarefas). Spec curta: só `spec.md`. Moldes em `.specify/templates/overrides/` e `docs/moldes/spec-curta.md`.

**Regras**
- Nada se constrói sem spec aprovada: `spec.md` com "Status: Approved" e a linha "Aprovação do dono" (resposta literal, data, link) (`AGENTS.md` §2; `docs/guias/processo-sdd.md`).
- No máximo 3 `[NEEDS CLARIFICATION]`, todas com recomendação, na mesma mensagem da aprovação (`AGENTS.md` §2).
- Respostas do dono gravadas na própria spec: "Clarifications", "Aprovação do dono", "Aprovação do merge" (`docs/guias/processo-sdd.md`).
- A seção extra da spec depende do tipo de trabalho; tela traz estados, larguras, imagem aprovada e inventário (`docs/guias/processo-sdd.md`; `docs/guias/telas.md`).
- O plano lista os "Arquivos permitidos"; só eles se mexem (`AGENTS.md` §4).
- O commit da autorização de merge só mexe na seção "Aprovação do merge" (`docs/guias/git-e-deploy.md`).

**Nunca**
- Editar à mão as skills geradas pelo Spec Kit; ajuste só pelos moldes de `.specify/templates/overrides/`.
- Construir a partir de spec em rascunho ou de plano antigo.

## Origem
`AGENTS.md` §2, §3 e §6 · `docs/projeto/tecnico.md` §Spec Kit e §Aprovação e registro · `docs/projeto/estrutura.md` (tipos de trabalho) · estrutura real (`ls specs`, 27/11/2026).
