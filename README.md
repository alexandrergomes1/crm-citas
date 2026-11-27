# crm-agenda (nome provisório)

Sistema de gestão (SaaS) para estúdios de estética: agenda, clientes, ficha de anamnese, comanda, caixa, financeiro, mensagens, marketing e fidelidade. Para a dona do estúdio, a recepção e as profissionais, com uso intenso no celular. Lançamento em Espanha, Brasil e Portugal. Em construção: porte do sistema antigo (`beauty-system`, Next.js) para TanStack Start na Cloudflare.

## Stack
TanStack Start e Router (React 19) · TypeScript estrito · Vite · Tailwind v4 · Radix e Lucide · Geist · Zod e React Hook Form · Supabase (Postgres com RLS por `org_id`, Auth, Storage) · Cloudflare Workers · Vitest, Testing Library e Playwright · ESLint · pnpm. Lista decidida, com o que ainda não está instalado: `docs/reference/stack.md`. Confira no `package.json` antes de usar uma biblioteca.

## Como rodar
Precisa de Node 22 ou mais novo e pnpm 10.

| Para | Comando |
|---|---|
| Instalar | `pnpm install --frozen-lockfile` |
| Rodar local (porta 3000) | `pnpm dev` |
| Checar antes de enviar | `pnpm typecheck` · `pnpm lint` · `pnpm test` |
| Só na CI (GitHub) | `pnpm test:e2e` (ponta a ponta) · `pnpm db:verify` (banco do zero com testes; precisa de `psql` e Postgres local) · `pnpm build` |
| Regenerar os tipos do banco | `pnpm db:types` |
| Nunca à mão | `pnpm deploy` e aplicar migration no banco remoto: a publicação e as migrations saem do GitHub |

Usuário e senha de teste nunca ficam no repositório nem no chat.

## Onde está cada coisa
| Caminho | O que é |
|---|---|
| `AGENTS.md` | Constituição: regras para qualquer IA ou pessoa. **Comece por aqui** |
| `CLAUDE.md` | Só o que é exclusivo do Claude Code |
| `ARCHITECTURE.md` | Camadas, fluxo de dados, banco, hospedagem, ambientes |
| `DESIGN.md` | Design system único: tokens, peças, regras de tela |
| `CONTRIBUTING.md` | Como trabalhar: spec, branch, commit, PR, merge |
| `SECURITY.md` | Segredos, acesso, dado de saúde, o que fazer se algo vazar |
| `CHANGELOG.md` · `GLOSSARY.md` | O que entrou em cada publicação · termos do domínio |
| `src/domain/` | Regras de negócio puras (TypeScript, com teste) |
| `src/data/` | Único lugar que fala com o banco; checagens de acesso em `src/data/auth/` |
| `src/server/` | Peças do servidor: cabeçalhos, origem, limite de tentativas |
| `src/workspace/` | Telas por módulo (agenda, clientes, anamnese, catálogo, financeiro…) |
| `src/routes/` | Rotas do TanStack Router |
| `src/design-system/` · `src/styles/` | Componentes e tokens de tela |
| `src/app-shell/` · `src/public-forms/` · `src/public-pay/` · `src/studio-mode/` | Navegação · ficha pública · cobrança pública · modo estúdio |
| `supabase/` | Migrations, seeds e testes de banco |
| `e2e/` | Testes de ponta a ponta (Playwright) |
| `specs/` | Uma pasta por tarefa (Spec Kit): spec, plano, tarefas |
| `docs/guias/` | Um guia neutro por área (banco, servidor, telas, testes, processo…) |
| `docs/produto/` | Produto e módulos (`modulos/` = linha de base; `legado/` = sistema antigo, só leitura) |
| `docs/BACKLOG.md` · `STATUS.md` · `OWNER.md` · `ROADMAP.md` | Fila · estado · perguntas ao dono · fases |
| `docs/decisoes/` · `docs/adr/` | Decisões do dono fora de spec · decisões técnicas |
| `docs/reference/` | Fatos de banco, servidor, endereços e stack |
| `docs/moldes/` · `docs/postmortems/` · `docs/runbooks/` | Moldes · incidentes · manuais de operação |
| `docs/arquivo-antigo/` | Tudo o que saiu de uso, só leitura |
| `.claude/` · `.specify/` · `.github/` | Cascas do Claude Code · Spec Kit · CI e molde de PR |

## Origem
`README.md` atual · `AGENTS.md` 2.0 §0, §1, §9 · `docs/README.md` · `docs/projeto/produto.md`, `estrutura.md` §Pastas · `docs/reference/project.md` §Pastas e §Comandos · `docs/reference/stack.md` · `package.json` · `docs/reorganizacao/06-plano-etapa5.md` §3.
