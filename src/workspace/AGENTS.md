# Pasta: src/workspace · telas do estúdio (app logado)

Vale junto com o `AGENTS.md` da raiz.

**O que mora aqui:** uma pasta por módulo (`agenda/`, `clientes/`, `catalogo/`, `financeiro/`, `anamnese/`, `mensagens/`, `marketing/`, `fidelidade/`, `cobrancas/`, `ajustes/`, `client-notes/`), com as telas e as funções de servidor do módulo (`*.server.ts`). Cada módulo tem o seu arquivo em `docs/produto/modulos/` (tabela "Pastas e arquivo do módulo" em `docs/guias/processo-sdd.md`).

**Regras**
- Toda tela segue `DESIGN.md` e `docs/guias/telas.md`: spec da tela aprovada, ficha visual antes, só tokens e componentes de `src/design-system/`.
- Até 300 linhas por arquivo de tela e 500 por arquivo; textos num lugar só do arquivo (`docs/guias/telas.md` §3).
- Regra de negócio em `src/domain`; banco só por `src/data`; função de servidor na ordem fixa (`docs/guias/servidor.md`).
- Conferência nas duas larguras (`DESIGN.md` §11); tela nova entra em `e2e/capturas-telas.spec.ts` (`docs/guias/telas.md` §4).
- Primeira tarefa num módulo: a ficha curta do passado antes de tudo (`AGENTS.md` §3).

**Nunca**
- Peça, cor, medida ou texto fora de `DESIGN.md` e da spec.
- Copiar código do sistema antigo (`docs/produto/legado/`) como modelo.
- Ficha de anamnese (dado de saúde) em log, endereço ou notificação (`SECURITY.md`).

## Origem
`.claude/rules/ui-layout.md` · `.claude/skills/ui-standards/SKILL.md` · `docs/projeto/estrutura.md` §Pastas · `src/workspace/agenda/AGENTS.md` · `AGENTS.md` §3 e §5 · estrutura real (`ls src/workspace`, 27/11/2026).
