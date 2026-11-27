# Beauty System — SaaS Stack Decision

Status: architecture decision / active governance
Owner: Alexandre + ChatGPT orchestration
Last updated: 2026-06-17

## 1. Decision

Beauty System will use a hybrid SaaS architecture, not a pure SPA/CSR architecture.

Approved direction:

```txt
Next.js App Router
+ Server Components for secure initial data loading
+ Client Components for rich interactions
+ Server Actions / Route Handlers as internal BFF
+ Supabase Postgres/Auth/RLS/RPC for data and transactional rules
+ Vercel for deploy, preview, performance and production delivery
```

## 2. Why not SPA-only

SPA/CSR-only is not the default architecture for this system because:

- it would move too much data fetching and state handling to the browser;
- it increases risk of exposing sensitive operational data paths;
- it weakens the benefit of server-side authorization and tenant loading;
- it can increase client JavaScript and reduce perceived performance;
- it forces the project to create a full API layer earlier than necessary.

Beauty System is an authenticated operational SaaS, not a public content site and not a simple client-only app.

## 3. Rendering policy

| Surface | Default approach |
|---|---|
| Layout/AppShell | Server-first shell + client navigation where needed |
| Agenda | Server initial data + client interaction for calendar/sheet |
| Clientes | Server initial data + client search/tabs/forms |
| Catálogo | Server initial data + client tabs/forms |
| Anamnese public token | Server token validation + client form interaction |
| Comanda/Checkout | Hybrid: server authorization/data + client calculation/interactions |
| Financeiro | Server-first with filters and charts client-side when needed |
| Marketing future | Server-first lists + client campaign editing |

## 4. API/BFF policy

Do not create a full REST API now.

Use:

| Need | Use |
|---|---|
| Load page data | Server Component + repository |
| UI mutation | Server Action |
| Critical transaction | Supabase RPC |
| External webhook | Route Handler `/api/...` |
| Future public/mobile API | Versioned Route Handler with explicit auth |

Rule:

> Route Handlers are for external integrations, webhooks, provider callbacks and future public/mobile APIs. They are not required for every internal UI action.

## 5. Backend/data policy

The backend contract is:

```txt
UI
→ Server Component / Server Action / Route Handler
→ Repository/domain validation
→ Supabase table/RPC/RLS
```

Rules:

- Domain logic should not be hidden inside UI components.
- Server Actions must validate input and permissions.
- Critical writes must be transactional or idempotent.
- RLS remains the data safety boundary.
- RPCs are preferred for multi-step financial/agenda operations.
- `service_role` is server-only and never reaches the browser.

## 6. Current stack assessment

Current stack is coherent and should be kept:

- Next.js App Router;
- React;
- TypeScript;
- Supabase SSR/Auth/Postgres;
- Radix primitives;
- Tailwind/token-based CSS;
- Vitest;
- Playwright;
- Vercel.

Primary issue is not the stack. The primary issue is lack of formal standards for layout, security, API boundaries and production configuration.

## 7. Required architecture standards

Before large new modules, the project needs:

1. AppShell/sidebar navigation standard;
2. security baseline;
3. performance budget;
4. Supabase production checklist;
5. Vercel production checklist;
6. review gate for Server Component vs Client Component vs Action vs RPC.

## 8. Immediate next architecture decisions

Approved:

- keep Supabase Auth for now;
- keep Supabase RLS/roles as tenant boundary;
- keep Next.js as BFF, not a separate backend service;
- do not migrate to SPA-only;
- do not create a broad public API yet;
- add API only where external integration requires it.

Deferred:

- Clerk/Auth0/WorkOS/Auth.js replacement;
- standalone backend service;
- GraphQL;
- mobile API;
- public SaaS signup;
- official WhatsApp/SMS provider integration.

## 9. Acceptance rule

Any future technical prompt that changes architecture must state:

- whether it uses Server Component, Client Component, Server Action, RPC or Route Handler;
- why that layer is appropriate;
- whether sensitive data stays server-side;
- whether RLS/org_id/role checks are preserved;
- whether the change affects performance or client JS size.
