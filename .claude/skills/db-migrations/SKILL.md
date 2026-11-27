---
name: db-migrations
description: Como fazer qualquer mudança no schema do banco (tabela, coluna, política RLS, função, visão, índice) neste projeto. Diz quais skills de mercado carregar, onde o projeto as contraria e como a migration é testada e aplicada. Use antes de escrever qualquer migration.
---

# db-migrations

Leia `docs/guias/banco.md` (§Antes de começar, §Migration, §Inquilino, RLS e grants, §Como a migration chega ao banco) e siga, com os fatos de `docs/reference/database.md` e as regras de `supabase/AGENTS.md`. Aplicar migration no banco remoto é barrado (`.claude/hooks/TRAVAS.md` §3).

Nenhuma regra mora aqui: em dúvida, vale `AGENTS.md` e o guia.
