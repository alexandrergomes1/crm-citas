# Arquitetura

Só o que está no repositório hoje. Regras de cada área: `docs/guias/` (`banco`, `servidor`, `telas`). Fatos com nomes exatos: `docs/reference/database.md`, `server.md`, `project.md`, `stack.md`. Em conflito, os fatos de `docs/reference/` vencem este resumo.

## Visão geral
Um único Worker da Cloudflare serve o app (TanStack Start sobre Vite, React 19). O banco é Supabase (Postgres). SSR desligado por padrão (`src/start.ts`): o servidor manda só o casco HTML; telas e dados carregam no navegador e falam com o servidor por server functions do Start.

```
navegador (telas: src/workspace, src/design-system, src/app-shell, src/routes)
   │  chama server function (createServerFn, validada com Zod)
   ▼
Worker Cloudflare (src/start.ts → middlewares de src/server/)
   │  ação *.server.ts: confere acesso (src/data/auth) → valida com o esquema do domínio (src/domain) → grava ou lê
   ▼
src/data (único lugar que fala com o banco, supabase-js / @supabase/ssr)
   ▼
Supabase Postgres (RLS por org_id; funções RPC para escrita em vários passos)
```

## Camadas
| Pasta | Papel | Regra |
|---|---|---|
| `src/domain/` | Regra de negócio pura (agenda, anamnese, acesso, financeiro…) | TypeScript puro, sem React nem banco; todo módulo com teste Vitest ao lado (`*.test.ts`) |
| `src/data/` | Repositórios por assunto (`clients/`, `appointments/`, `finance/`…), cliente Supabase (`supabase.ts`), tipos gerados (`database.generated.ts`, por `pnpm db:types`) | Único lugar que fala com o banco. Acesso: `src/data/auth/` (`requireAuth`, `requireOrgAccess`, `requireOrgIdAccess`, `requirePermission`, `orgCan`) |
| `src/server/` | Peças do servidor: middlewares de pedido (`request-middleware.ts`), cabeçalhos (`public-headers.ts`), origem do app, IP e limite de tentativas, `runtime.server.ts` | Sem regra de negócio |
| `src/workspace/<módulo>/` | Telas por módulo e as ações dele (`*.ts` declara a server function; `*.server.ts` executa) | Tela só com peças do design system; regra fica em `src/domain` |
| `src/routes/` | Rotas do TanStack Router (`$orgSlug`, `forms.$token`, `pagar.$token`, `login`, `api/`…) | Arquivo gerado: `src/routeTree.gen.ts` |
| `src/design-system/` · `src/styles/` | Componentes (Radix, Lucide) e tokens (`globals.css`) | Fonte única de design: `DESIGN.md` |
| `src/lib/` | Utilidades comuns (erro para a pessoa em `action-error.ts`, caminhos públicos, datas do estúdio, navegação) | — |
| `src/auth/` · `src/app-shell/` · `src/public-forms/` · `src/public-pay/` · `src/studio-mode/` | Login e senha · navegação · ficha pública · cobrança pública · modo estúdio (tablet) | — |
| `supabase/` | `migrations/` (nome `AAAAMMDDHHMMSS_descricao.sql`), `seed/`, `tests/` (segurança e isolamento) | Migration nova sempre; a que está na `previas` não se edita |
| `e2e/` | Playwright nas duas larguras de conferência (`DESIGN.md` §11), com capturas | — |

## Fluxo de um pedido
1. Middlewares, nesta ordem (`src/start.ts`): cabeçalhos de segurança → endereços antigos (308) → checagem de origem → sessão → trava do modo estúdio → tamanho do corpo.
2. A server function valida a entrada com Zod e chama a ação `*.server.ts` por `runServer`.
3. A ação confere login, estúdio e papel (`src/data/auth/`), valida pelo esquema de `src/domain`, chama `src/data` e devolve a resposta com erro em português (`actionErrorMessage`), nunca o texto cru do banco.
4. Escrita em vários passos (pagamento + caixa + saldo) é uma função do banco (RPC), numa transação. Auditoria de ação sensível é gravada pelo banco.
5. Acesso (usuário, estúdio, papel) é memorizado por pedido (`src/data/request-scope.ts`): conferir de novo na mesma requisição não custa outra ida ao banco. Orçamento de idas ao banco: `docs/guias/servidor.md`.

## Banco: Supabase, RLS e org_id
- Multi-estúdio: toda tabela do estúdio tem `org_id uuid not null` e RLS. Chave estrangeira nova entre tabelas do estúdio é composta com `org_id`.
- Leitura com permissão: política com `public.auth_orgs_with_permission('<módulo>.view')`. Leitura entre módulos pelas visões do schema `internal_read` (não exposto pela API).
- `service_role` só onde a RLS do usuário não alcança (fotos da ficha, páginas públicas, esqueci a senha, criar acesso de pessoa da equipe).
- `supabase/tests/10_security_checks.sql` reprova o PR se houver tabela sem RLS ou sem `org_id`, política aberta, função `security definer` mal fechada, entre outros. Toda tabela ou política nova ganha teste de isolamento (o estúdio A não lê nem grava no B).
- Como a migration chega ao banco: replay do zero na CI do PR (`pnpm db:verify`); depois do merge, `migrations-dev.yml` aplica no banco de desenvolvimento, um arquivo por transação; produção só com autorização do dono.

## Páginas sem login
`/forms/<token>`, `/pagar/<token>`, `/reset-password`, o modo estúdio `/<estúdio>/anamnese-tablet`, `/login`, `/logout`, `/booking`, `/api/webhooks` e `/_serverFn/` levam `Cache-Control: private, no-store`, `X-Robots-Tag: noindex, nofollow` e `Referrer-Policy: same-origin` (`src/lib/public-paths.ts`, `src/server/public-headers.ts`). O link da ficha é guardado só como hash, com validade.

## Hospedagem: Cloudflare Workers
- `wrangler.jsonc`: Worker `crm-citas` (prévias: `crm-citas-previas`), entrada `@tanstack/react-start/server-entry`, `nodejs_compat`, Smart Placement, registro automático de cada pedido desligado (o endereço leva token). Só valores públicos em `vars`; a chave `service_role` é segredo do painel da Cloudflare.
- Publicação pelo Workers Builds ligado ao GitHub, nunca à mão.

## Ambientes
| Degrau | Branch | Onde se vê | Banco |
|---|---|---|---|
| Tarefa | `tipo/area-assunto` | prévia da branch (`<branch-com-hifens>-crm-citas-previas.alexandrergomes.workers.dev`) e capturas da CI | desenvolvimento |
| Integração e prévia | `previas` | https://crm-citas-previas.alexandrergomes.workers.dev | desenvolvimento |
| Produção | `main` | Worker `crm-citas` | desenvolvimento até a virada; depois, produção |

Banco de desenvolvimento único para todas as branches: a migration tem de funcionar com o código das duas branches. Detalhe: `docs/guias/git-e-deploy.md`.

## Como está hoje (não descreva como se já existisse)
CSP só com `frame-ancestors 'none'`; Turnstile, Sentry, idiomas (Paraglide), TanStack Query, outbox com Cron e idempotência em `/pagar` e webhooks estão previstos, não construídos (`docs/reference/stack.md`, `server.md`).

## Origem
`docs/projeto/tecnico.md` §Ambientes · `docs/projeto/estrutura.md` §Pastas · `.claude/rules/banco-dados.md`, `servidor.md`, `ui-layout.md` · `src/workspace/agenda/AGENTS.md` · `docs/reference/database.md`, `server.md`, `project.md`, `stack.md` · `package.json` · `wrangler.jsonc` · `src/start.ts` · `src/data/request-scope.ts` · `src/workspace/client-note-actions*.ts`.
