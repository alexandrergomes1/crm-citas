# Guia · Testes e prova

Diz que teste existe, onde roda e o que conta como prova de que um trabalho ficou pronto.
CI = os testes automáticos que o GitHub roda em cada envio. **A prova é a CI**, não o que alguém rodou na própria máquina.

## As camadas de teste
| Camada | Ferramenta | Onde ficam | Comando |
|---|---|---|---|
| Unidade (regra de negócio, componentes) | Vitest (ambiente `jsdom`) | `src/**/*.test.ts(x)`; regra em `src/domain` sempre com teste | `pnpm test` |
| Orçamento de idas ao banco | Vitest | `src/data/supabase-calls.test.ts` | `pnpm test` |
| Banco do zero | Postgres 17 + stub do Supabase, sem Docker | migrations em `supabase/migrations/`, testes em `supabase/tests/` | `pnpm db:verify` |
| Ponta a ponta (E2E) | Playwright, Supabase local | `e2e/` | `pnpm test:e2e` |
| Travas e conferências | Node | `.claude/hooks/*.test.mjs`, `.githooks/pre-push.test.mjs`, `scripts/conferir-pedido.test.mjs` | `node <arquivo>.test.mjs` |

- **Teste de isolamento** entre estúdios para toda tabela ou política nova ou alterada: `banco.md`.
- **Teste mínimo de função de servidor:** unidade da regra em `src/domain` e E2E provando que outro estúdio recebe erro (`servidor.md`).
- **E2E trazido do sistema de origem:** sem editar as asserções (`porte.md`).
- Teste antes do código onde a spec pede.

## Quem roda o quê
| Para | Comando | Quem |
|---|---|---|
| Checar antes de enviar | `pnpm typecheck` · `pnpm lint` · `pnpm test` | quem constrói, na sessão (evita envio quebrado; não é a prova) |
| Prova | `pnpm test:e2e` · `pnpm db:verify` · `pnpm build` | só a CI |
| Revisores | nenhum | leem o resultado da CI no PR e o citam (`revisao.md`) |

`pnpm db:verify` precisa de `psql` e de um Postgres local; fora da CI serve para investigar, não como prova.

## O que a CI roda
Cada rotina do GitHub, quando roda e o que confere: `git-e-deploy.md`. O que o teste de segurança do banco (`supabase/tests/10_security_checks.sql`) já trava sozinho, e o que parece travado mas não está: `docs/reference/database.md`.

## Larguras de conferência
As duas de `DESIGN.md` §11; no Playwright, os projetos `mobile-chrome` e `desktop-chrome` do `playwright.config.ts`. Tela nova entra na lista `TELAS` de `e2e/capturas-telas.spec.ts`.
Sem banco local na sessão, não dá para abrir a tela com dados: o que depende disso sai "não verificado".

## Prova por tipo de trabalho
A prova de cada tipo de trabalho (coluna "Prova") está na tabela de tipos de `processo-sdd.md`. Sem prova: "não verificado".

## Prova local (CI sem minutos do GitHub)
`git-e-deploy.md` §Prova local.

## Desempenho de tela
`desempenho.md`.

## Origem
`docs/projeto/estrutura.md` (coluna "Prova") · `docs/projeto/tecnico.md` §CI e §Merge e publicação · `AGENTS.md` §1 e §6 · `.claude/agents/ui-qa.md` · `.claude/agents/construtor.md` · `docs/projeto/DESIGN-SYSTEM.md` · `docs/reference/project.md` ("Como ver uma tela", "Comandos") · `.github/workflows/*` · `package.json` · `playwright.config.ts` · `vitest.config.ts` · `.claude/hooks/TRAVAS.md` §1.
