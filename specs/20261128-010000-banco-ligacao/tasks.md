# Tarefas · Ligar o banco: base da trava por estúdio (item 3 da fila)

- **Spec:** `spec.md` · **Plano:** `plan.md` · **ADR:** `docs/adr/0005-banco-base-trava-por-estudio.md`
- **Escrito por:** Engenheiro de dados (banco), pelo Arquiteto de software · Norma: modelo C4 e ADR; boas práticas
  Postgres e Supabase · **Revisão:** 5b (Gerente de projeto) feita com ajustes, 28/11; etapa 5 pendente
- **Pode começar antes da aprovação**, só em PR de rascunho (E22·B); nada é juntado sem "Status: Approved", "Aprovação do
  dono" e a autorização do merge gravada (`AGENTS.md` §3 regra 1 e §8).
- Só os arquivos do `plan.md` §6. A IA nunca aplica nada no banco remoto (`AGENTS.md` §1). Falhou: refaz e confere; o
  mesmo erro duas vezes, para e relata (`AGENTS.md` §6). Commits pequenos, Conventional Commits, citando a spec.

## Construção · Fase A (banco local)

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 1 | Trabalhar na `feat/banco-ligacao` (branch única do item 3, já com a `chore/fundacao-tecnica` juntada por merge); conferir que ela tem `supabase/config.jsonc`, `20261128000921_fundacao.sql`, `fundacao_test.sql` e os scripts `db:*`; árvore limpa | Engenheiro de DevOps | `git status` vazio; arquivos presentes |
| 2 | Ler na referência oficial da CLI: `supabase migration new`, `supabase test db` (pasta que roda, R-3) e conferir na imagem local se `auth.users` e `auth.uid()` existem com o `-x` do `db:start` (R-1, R-2) | Engenheiro de dados | fontes anotadas no PR; se R-1 falhar, parar e pedir ajuste do plano |
| 3 | M1 `estudios` (`plan.md` §3.1): `create schema if not exists app`, tabela, `check`, gatilho do fuso, RLS ligada, `revoke all` de `anon` e `authenticated` | Engenheiro de dados | `pnpm db:start` aplica sem erro |
| 4 | M2 `membros` (§3.2): tabela, chave, índices, RLS ligada, `revoke all` | Engenheiro de dados | aplica sem erro |
| 5 | M3 `trava_por_estudio` (§3.3): as 4 funções, `search_path = ''`, `revoke`/`grant` de execução e do esquema | Engenheiro de dados | aplica sem erro |
| 6 | M4 `politicas_base` (§4): políticas `to authenticated` e `grant` por coluna | Engenheiro de dados | aplica sem erro |
| 7 | Testes `010_` a `050_` (§5), dados fictícios escritos do zero | Engenheiro de dados | `pnpm db:test` verde, inclusive `fundacao_test.sql` |
| 8 | Prova de que o teste pega erro: numa cópia local descartável, tirar o `S` de uma política e ver `020_` ou `030_` ficar vermelho; desfazer | Engenheiro de dados | vermelho visto e desfeito; nada disso no commit |
| 9 | Molde `supabase/moldes/isolamento_tabela_test.sql` (§5) | Engenheiro de dados | arquivo com marcadores; `pnpm db:test` não o roda |
| 10 | `pnpm db:stop`; `pnpm typecheck`, `pnpm lint`, `pnpm test` (nada de app muda, mas o `AGENTS.md` §1 pede) | Engenheiro de dados | tudo verde |
| 11 | Abrir PR de rascunho da `feat/banco-ligacao`, empilhado sobre a `chore/fundacao-tecnica`; nunca juntar nela. Quando o item 2 entrar, passar a base do PR à `previas`, **antes** do pedido de merge (passo 21) | Engenheiro de DevOps | job `banco` e `segredos` verdes; base = `previas` antes do passo 21 |

## Construção · Fase B (aplicação pela CI) · só depois de E24·1 e E24·2 gravadas

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 12 | Ler a referência oficial da CLI 3.4.0 para aplicar migrations por endereço de banco, modo de ensaio e `test db` remoto (R-4); escrever `.github/workflows/banco-dev.yml` pelo `plan.md` §7 | Engenheiro de DevOps | YAML válido; gatilho só `push` na `previas`; `environment: desenvolvimento`; nenhum segredo no arquivo |
| 13 | Se o dono escolher E24·2·A: o tratamento do histórico do antigo é passo destrutivo fora da lista de arquivos atual; vira ajuste do `plan.md` com nova 5b, revisão do Auditor de risco e pedido próprio ao dono | Engenheiro de DevOps com Engenheiro de dados | plano ajustado e 5b nova feita; nada rodado |
| 14 | Pedir ao dono, no molde, criar o ambiente `desenvolvimento` com aprovação dele e o segredo do endereço do banco (link e cliques exatos) | Gerente de projeto | dono confirma; nenhum valor no chat |

## Revisão (etapa 9)

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 15 | Revisar migrations, testes e molde; conferir o ADR 0005 item por item (T1 a T10) e preencher "Conferência" | Engenheiro de dados que **não** construiu | relatório sem "Bloqueia"; ADR conferido |
| 16 | Revisar o risco: funções `security definer`, políticas, privilégios, Fase B e E24·2 | Auditor de risco | relatório sem "Bloqueia" |
| 17 | Revisar acesso: RF-03 a RF-05, `escolher_estudio`, ambiente e segredo da Fase B | Engenheiro de segurança | relatório sem "Bloqueia" |
| 18 | Veredito de CA-01 a CA-13 pelo `plan.md` §10 | Analista de qualidade (QA) | veredito com links |

## Fechamento (etapas 10 a 13)

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 19 | Conferir o pedido item por item (RF-01 a RF-09, RG-01 a RG-08) | Analista de requisitos | tudo cumprido ou relatado |
| 20 | `docs/STATUS.md`, `docs/BACKLOG.md`, `CHANGELOG.md`, `docs/decisoes/` (E24·1, E24·2) no mesmo PR | Documentador | no PR |
| 21 | Pedido de merge no molde, com o commit e a CI verde | Gerente de projeto | mensagem enviada e aviso no celular |
| 22 | Gravar "Aprovação do merge" e juntar só esse commit; o `banco-dev.yml` aplica no `push` à `previas`, com aprovação do dono no ambiente | Engenheiro de DevOps | merge feito; job da Fase B verde |
