# crm-citas

> Rascunho para o dono aprovar (E18). Escrito por: Documentador · Revisado por: Gerente de projeto

Sistema de gestão (SaaS) para estúdios de estética, usado pela dona, pela recepção e pelas profissionais, com o
celular em primeiro lugar. Idiomas de uso: português, espanhol e inglês. Nome provisório (E3·3).

**Comece por [`AGENTS.md`](AGENTS.md)** (regras de trabalho).

## Stack
TypeScript, React com TanStack Start, Supabase (Postgres), Cloudflare Workers, pnpm, Vitest e Playwright.
Versões e bibliotecas extras entram por spec (`ARCHITECTURE.md` §12).

## Como rodar
Entra com a spec da fundação técnica. Ainda não há código.

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
