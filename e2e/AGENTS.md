# Pasta: e2e · testes de ponta a ponta (Playwright)

Vale junto com o `AGENTS.md` da raiz.

**O que mora aqui:** os testes que abrem o app de verdade (`*.spec.ts`), as capturas de tela (`capturas-telas.spec.ts`), o preparo do banco local da CI (`ci/`) e dados fixos de teste (`fixtures/`).

**Regras**
- Rodam só na CI (`pnpm test:e2e`), nas duas larguras de `DESIGN.md` §11 (`docs/guias/testes.md`; `AGENTS.md` §1).
- Tela nova entra na lista `TELAS` de `capturas-telas.spec.ts`; as capturas saem como artefato `capturas-telas` do PR (`docs/guias/telas.md` §4).
- Toda função de servidor nova tem E2E provando que outro estúdio recebe erro (`docs/guias/servidor.md`).
- Usuário e senha de teste só por variável de ambiente (`E2E_EMAIL`, `E2E_PASSWORD`), nunca em arquivo (`AGENTS.md` §5).

**Nunca**
- Escrever usuário, senha ou token de teste no código ou no chat.

## Origem
`docs/reference/project.md` ("Como ver uma tela", §Pastas) · `docs/reference/server.md` (teste mínimo) · `.claude/skills/ui-standards/SKILL.md` ("Entregar") · `docs/projeto/tecnico.md` §CI · `e2e/capturas-telas.spec.ts` · estrutura real (`ls e2e`, 27/11/2026).
