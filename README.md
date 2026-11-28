# crm-citas

> Aprovado pelo dono em 27/11/2026 (E18). Escrito por: Documentador · Revisado por: Gerente de projeto

Sistema de gestão (SaaS) para estúdios de estética, usado pela dona, pela recepção e pelas profissionais, com o
celular em primeiro lugar. Idiomas de uso: português, espanhol e inglês. Nome provisório (E3·3).

**Comece por [`AGENTS.md`](AGENTS.md)** (regras de trabalho).

## Stack
TypeScript, React com TanStack Start, Supabase (Postgres), Cloudflare Workers, pnpm, Vitest e Playwright.
Versões e bibliotecas extras entram por spec (`ARCHITECTURE.md` §12).

## Como rodar
**Precisa ter:** Node 26.13.1 (arquivo `.nvmrc`; o `package.json` aceita `>=26.13.1 <27`), pnpm 12.23.0 (campo
`packageManager`) e Docker (só para o banco local). Nenhuma senha ou chave é necessária.

1. Instalar as dependências: `pnpm install`
2. Ligar a trava de envio (uma vez por cópia do repositório): `git config core.hooksPath .githooks`. Ela barra o
   envio direto à `previas` ou à `main` e nome de branch fora de `tipo/area-assunto` (`AGENTS.md` §8)
3. Rodar o app: `pnpm dev` e abrir `http://localhost:3000`

**Comandos fixos** (scripts do `package.json`):

| Comando | Para quê |
|---|---|
| `pnpm build` | gerar o app |
| `pnpm typecheck` | checagem de tipos |
| `pnpm lint` | lint, inclui as camadas |
| `pnpm test` | testes de unidade |
| `pnpm test:e2e` | telas em 390 e 1440 px (Chromium) |
| `pnpm db:start` | ligar o banco local (só o Postgres, em Docker) |
| `pnpm db:test` | testes do banco **local** |
| `pnpm db:stop` | desligar o banco local |

Antes de enviar: `pnpm typecheck`, `pnpm lint` e `pnpm test`; mais `pnpm test:e2e` se mexeu em tela e `pnpm db:test`
se mexeu em `supabase/`. O banco remoto nunca muda daqui: só pela CI (`AGENTS.md` §1).

## Mapa

| O quê | Onde |
|---|---|
| Regras de trabalho | `AGENTS.md` |
| Planta | `ARCHITECTURE.md` |
| Aparência | `DESIGN.md` |
| Design (canvas e imagens) | `docs/design/` |
| Segurança | `SECURITY.md` |
| Como contribuir | `CONTRIBUTING.md` |
| Fila | `docs/BACKLOG.md` |
| Estado | `docs/STATUS.md` |
| Decisões do dono | `docs/decisoes/` |
| Decisões técnicas | `docs/adr/` |
| Guias | `docs/guias/` |
| Moldes | `docs/moldes/` |
| Produto | `docs/produto/` |
| Specs | `specs/` |
| Versões | `CHANGELOG.md` |
| Regras de cada pasta | `src/*/AGENTS.md` |
| Testes de tela | `e2e/` |
| CI | `.github/` |
| Papéis e receitas do Claude Code | `.claude/` (só apontam para os guias) |
