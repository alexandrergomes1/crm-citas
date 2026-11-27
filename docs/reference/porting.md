# Porte do Next.js para o TanStack Start

Referência da skill `port-module`. Repositório de origem e pastas: `docs/reference/project.md`.

## Como é o módulo na origem
Pasta `app/(workspace)/[orgSlug]/<modulo>/`:
- `page.tsx` assíncrona: lê params e searchParams, chama `requirePermission(orgSlug, '<modulo>.view')`, busca em `src/data` e passa props para `<Modulo>Screen`.
- `actions.ts` com `'use server'`: Zod, `requireOrgIdAccess` + `orgCan`, chama `src/data`, `revalidatePath(...)`, devolve `{ error }` via `actionErrorMessage`.
- Componentes cliente usam `next/link`, `useRouter`, `usePathname`, `useSearchParams`.

## Tabela de troca
| Next | TanStack Start |
|---|---|
| `page.tsx` assíncrona | rota em `src/routes/` com `loader` que chama uma server function de leitura; `validateSearch` com o mesmo parser de `src/domain` (ex.: `parseClientListQuery`) |
| `params` / `searchParams` | `Route.useParams()` / `Route.useSearch()` |
| `requirePermission` no topo da página | `beforeLoad` da rota do estúdio + checagem de novo dentro da server function (a tela nunca é a única barreira) |
| Server Action (`'use server'`) | `createServerFn({ method: 'POST' }).validator(schemaZod).handler(...)`, seguindo a skill `server-functions` |
| `revalidatePath` / `revalidateTag` | `router.invalidate()` ou `queryClient.invalidateQueries({ queryKey })` depois do sucesso |
| `redirect()` / `notFound()` | `throw redirect({ to })` / `throw notFound()` do `@tanstack/react-router` |
| `next/link` | `Link` do `@tanstack/react-router` (via adaptador `src/lib/nav`) |
| `useRouter().push/replace/refresh` | `useNavigate()` / `router.invalidate()` (via adaptador) |
| `usePathname` / `useSearchParams` | `useLocation()` / `Route.useSearch()` |
| `loading.tsx` | `pendingComponent` da rota |
| `error.tsx` | `errorComponent` da rota |
| `cookies()` de `next/headers` | cookies da requisição do Start (adaptador em `src/data/supabase.ts`) |

## Adaptadores (já feitos)
- `src/lib/nav`: `Link`, `useNav()` (push, replace, refresh), `usePath()`. Telas e design system importam daqui, nunca do roteador direto.
- `src/data/supabase.ts`, `src/data/auth/session.ts`, `src/data/auth/access.ts`, `src/data/preferences/repository.ts`: recebem os cookies da requisição e devolvem erro tipado em vez de `redirect()`; a rota decide o que fazer.
- `src/app-shell` e os componentes do design system que navegam (EmptyState, MobileHeader, NavRow, SaveBar/useDraftForm, SectionedPage, SidePanel) importam de `src/lib/nav`.
