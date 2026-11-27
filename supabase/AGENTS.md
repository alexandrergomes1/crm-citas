# Pasta: supabase · banco (migrations, testes, dados de exemplo)

Vale junto com o `AGENTS.md` da raiz.

**O que mora aqui:** `migrations/` (uma mudança por arquivo, nome `AAAAMMDDHHMMSS_descricao.sql`), `tests/` (testes de banco, inclusive isolamento entre estúdios e `10_security_checks.sql`) e `seed/` (dados de exemplo).

**Regras**
- Toda mudança é migration nova, escrita à mão, sem `begin`/`commit` dentro; a que já está na `previas` não se edita, corrige-se com outra (`docs/guias/banco.md`).
- Toda tabela com `org_id uuid not null`, RLS e teste de isolamento em `tests/` (estúdio A não lê nem grava no B) (`docs/guias/banco.md`).
- Chave estrangeira nova entre tabelas do estúdio é composta com `org_id`; política nova `to authenticated` com `(select auth.uid())` (`docs/guias/banco.md`).
- A migration tem de funcionar com o código das duas branches enquanto prévia e produção usam o mesmo banco: nada de apagar ou renomear coluna no PR que para de usá-la (`docs/guias/banco.md`).
- Seeds e migrations em UTF-8 explícito (`docs/guias/banco.md`).
- A prova é o job de banco da CI (banco do zero com todas as migrations e os testes) (`docs/guias/testes.md`).

**Nunca**
- Aplicar no banco remoto pela IA (`db push`, `db pull`, `psql` remoto, conexão de IA ao banco): a migration chega pela CI depois do merge.
- `create index concurrently` (quebra depois do merge).
- Migration na produção sem autorização do dono.

## Origem
`.claude/rules/banco-dados.md` · `.claude/skills/db-migrations/SKILL.md` · `docs/reference/database.md` · `docs/reference/project.md` §Pastas · `AGENTS.md` §1 e §6 · estrutura real (`ls supabase`, 27/11/2026).
