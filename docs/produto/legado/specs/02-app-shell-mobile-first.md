# Spec 02 — App Shell Mobile-First

## Feature Trace
- Roadmap: Fase 0 — Scaffold
- Source: `ka-beauty/docs/design-system.md`, `ka-beauty/docs/rebuild-inventory.md`

## Goal

Criar o shell do app interno — navegação, layout, topbar, sidebar — mobile-first e sem bugs em qualquer dispositivo.

## Users

Todos os perfis que acessam o workspace interno.

## Screens

- Layout raiz: `app/(workspace)/[orgSlug]/layout.tsx`
- Componentes: `src/app-shell/`

## Main Flow

1. Usuário autentica e é redirecionado para `/<orgSlug>/agenda`
2. AppShell renderiza Sidebar (desktop) ou MobileNav (mobile)
3. TopBar mostra o nome da org, breadcrumb e menu do usuário
4. Conteúdo da página ocupa o espaço restante
5. Modais e sheets abrem sobre o conteúdo

## Business Rules

- Bottom nav NUNCA cobre conteúdo (`pb-[calc(56px+env(safe-area-inset-bottom))]`)
- Sidebar desktop sempre visível em ≥ 1280px
- Em mobile, Sidebar é substituída por bottom nav com 5 ítens máximo
- Breadcrumb reflete a rota atual
- TopBar tem org switcher se o usuário pertence a múltiplas orgs

## Data Contract

```ts
interface NavItem {
  href: string;
  label: string;
  icon: LucideIcon;
  badge?: number; // notificações
}
```

## RLS And Permissions

- Acesso ao workspace requer sessão Supabase válida
- `org_id` verificado em todos os dados do workspace

## UX States

- **Loading:** esqueleto do shell enquanto dados da org carregam
- **Mobile:** bottom nav 5 ítens, sidebar colapsada
- **Desktop:** sidebar 240px fixa, topbar completa
- **Sem org:** redireciona para `/login`

## Acceptance Criteria

- [ ] Sidebar renderiza com todos os links de módulo
- [ ] MobileNav com no máximo 5 ítens visíveis
- [ ] Conteúdo não fica coberto pelo bottom nav em 390px
- [ ] TopBar mostra nome da org e menu do usuário
- [ ] ESC fecha qualquer modal/sheet aberto
- [ ] Sem overflow horizontal em 390px
- [ ] Screenshot desktop 1440px + mobile 390px passando

## Tests

```ts
// e2e/app-shell.spec.ts
test('desktop layout', async ({ page }) => {
  await page.goto('/ka-beauty/agenda');
  await expect(page.locator('[data-testid="sidebar"]')).toBeVisible();
  await expect(page).toHaveScreenshot('app-shell-desktop.png');
});

test('mobile layout sem overflow', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/ka-beauty/agenda');
  await expect(page.locator('[data-testid="mobile-nav"]')).toBeVisible();
  const bodyWidth = await page.evaluate(() => document.body.scrollWidth);
  expect(bodyWidth).toBeLessThanOrEqual(390);
  await expect(page).toHaveScreenshot('app-shell-mobile.png');
});
```

## Out Of Scope

- Sidebar colapsável em desktop (pode ser adicionada depois)
- Temas por org (futuro)
- Notificações em tempo real (futuro)
