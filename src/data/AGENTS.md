# Pasta: src/data · acesso ao banco

Vale junto com o `AGENTS.md` da raiz.

**O que mora aqui:** o único código que fala com o banco (Supabase): leituras e gravações por módulo (`appointments/`, `clients/`, `finance/`…), checagens de acesso (`auth/`), tipos gerados (`database.generated.ts`) e o teste do orçamento de idas ao banco (`supabase-calls.test.ts`).

**Regras**
- Acesso ao estúdio e permissão pelas peças de `auth/` (`requireOrgIdAccess`, `orgCan`…); o `org_id` que vem da tela nunca é verdade (`docs/guias/servidor.md`).
- Idas ao banco dentro do orçamento (`docs/guias/servidor.md` §Orçamento de idas ao banco).
- Tela com várias tabelas lê por uma função SQL; escrita em vários passos é uma função do banco, numa transação (`docs/guias/banco.md`).
- Tipos do banco regenerados com `pnpm db:types` no mesmo PR da migration (`docs/guias/banco.md`).
- Erro do banco nunca vai cru para a pessoa: `actionErrorMessage` (`docs/guias/servidor.md`).

**Nunca**
- `service_role` para o que a RLS do usuário alcança.
- Nome, telefone, resposta de ficha, token ou senha em log.

## Origem
`.claude/rules/banco-dados.md` · `.claude/skills/server-functions/SKILL.md` · `.claude/skills/db-migrations/SKILL.md` · `docs/reference/server.md` · `docs/reference/db-budget.md` · `docs/reference/project.md` §Pastas · estrutura real (`ls src/data`, 27/11/2026).
