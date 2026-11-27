# Guia · Banco de dados

Vale para qualquer mudança no esquema do banco: tabela, coluna, política RLS, função, visão, índice.
RLS = Row Level Security, a trava do Postgres que separa os dados de cada estúdio.
Fatos do banco (o que a CI já trava, nomes da casa, onde o projeto contraria o mercado): `docs/reference/database.md`. Em conflito com qualquer prática geral, vence esse arquivo.

## Antes de começar
- Spec aprovada da tarefa (`specs/NNN-nome/`: spec, plano e tarefas). Só os "Arquivos permitidos" do plano (`processo-sdd.md`).
- Método geral (modelagem, segurança do Supabase, RLS com desempenho, migration segura) vem da prática de mercado. No Claude Code ele vem das skills `backend-design:data-modeling-discipline`, `supabase:supabase` (sem a parte "Making and Committing Schema Changes"), `supabase:supabase-postgres-best-practices` e `backend-design:migration-safety`.
- Banco só se acessa pelo código em `src/data`. Regra de negócio fica em `src/domain` (`servidor.md`).

## Migration
1. Toda mudança é **migration nova**, escrita à mão, em `supabase/migrations/`, com nome de 14 dígitos: `AAAAMMDDHHMMSS_descricao.sql`.
2. Sem `begin`/`commit` dentro do arquivo (o script de aplicar recusa).
3. **Migration que já está na `previas` não se edita**: corrige-se com outra. A que foi criada no PR em curso pode ser editada.
4. **Proibido `create index concurrently`**: cada arquivo é aplicado numa transação só, e `concurrently` não roda em transação. O replay do PR não pega; quebra depois do merge.
5. Carga ou correção de dados dentro da migration: evitar; se for inevitável, arquivo separado e dito no PR.
6. Seeds em UTF-8 explícito.
7. Regenere os tipos do banco (`pnpm db:types` → `src/data/database.generated.ts`) no mesmo PR.

## Inquilino (estúdio), RLS e grants
- Toda tabela do estúdio tem `org_id uuid not null`, RLS ligada e **teste de isolamento**.
- **Teste de isolamento:** toda tabela ou política nova ou alterada ganha teste em `supabase/tests/` provando que o estúdio A não lê nem grava no B. Escreva antes de fechar a migration. Sem ele, o revisor de risco bloqueia (`revisao.md`).
- Chave estrangeira **nova** entre tabelas do estúdio é composta com `org_id`; `on delete` escrito, com a razão no PR.
- Política de leitura: `org_id in (select public.auth_orgs_with_permission('<módulo>.view'))`.
- Política nova: `to authenticated` e `(select auth.uid())`.
- Função: `revoke all on function … from public, anon`, depois `grant execute` só a quem usa (em geral `authenticated`).
- Tabela gravada só por função: sem política de escrita, `revoke` da gravação para `anon` e `authenticated`; a função é `security definer` e confere login, estúdio e permissão.
- Em `services` e `products`, coluna nova precisa de `grant select (coluna) … to authenticated`; custo e comissão só saem por função.
- Leitura entre módulos pelas visões do schema `internal_read`. Coluna nova numa tabela que tem visão: recriar a visão.
- Chave primária: `uuid` com `gen_random_uuid()`. Dinheiro em coluna nova: `numeric(12,2)`. Hora em `time` ou `timestamptz`.
- Lista completa e exceções antigas: `docs/reference/database.md`, "Nomes e estruturas da casa".

## Banco de desenvolvimento único
- Um banco de desenvolvimento serve todas as branches e a prévia; a produção usa o mesmo banco até a virada (`docs/reference/project.md`).
- Por isso a migration **tem de funcionar com o código das duas branches**: nada de apagar ou renomear coluna no mesmo PR que para de usá-la.
- Mudança que não cabe num deploy traz os passos em ordem no PR.

## Como a migration chega ao banco
1. No PR, a CI recria um banco vazio, roda todas as migrations e os testes de `supabase/tests/` (`testes.md`).
2. No merge na `previas` (e na `main`), a rotina `migrations-dev.yml` aplica no banco de desenvolvimento o que falta, cada arquivo numa transação. Depois do merge, confira que ela ficou verde.
3. Produção: só com autorização do dono, depois do backup do dia conferido (`git-e-deploy.md`).
- **Ninguém aplica à mão.** Proibido para a IA: gravar no banco pelo MCP (`apply_migration`, `execute_sql`), `supabase db push`, `db pull`, `supabase link`, `psql` contra banco remoto, rodar o script de aplicar. A trava do Claude Code barra as formas comuns (`.claude/hooks/TRAVAS.md` §3).
- Advisors do Supabase: só depois de aplicada no desenvolvimento; sem ferramenta, peça ao dono ou escreva "não verificado".

## Orçamento de idas ao banco
`servidor.md` §Orçamento de idas ao banco.

## Pare e pergunte
- A mudança perde dado ou não tem caminho de volta.
- Não dá para escrever o teste de isolamento.
- A prática de mercado e `docs/reference/database.md` se contradizem num ponto que ele não cobre.
- A migration precisa ir para a produção.

## Revisão e prova
Tipo "Dados", nível C. Revisores: `revisao.md`. Prova: CI com o banco do zero e os testes (`testes.md`).

## Origem
`.claude/skills/db-migrations/SKILL.md` · `.claude/rules/banco-dados.md` · `docs/reference/database.md` · `docs/reference/db-budget.md` · `docs/reference/project.md` · `.claude/hooks/TRAVAS.md` §3 · `.github/workflows/migrations-dev.yml` · `AGENTS.md` §5–6 · `docs/projeto/tecnico.md` §Ambientes.
