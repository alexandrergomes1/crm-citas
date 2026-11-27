# Spec 01 — Design System

## Feature Trace
- Roadmap: Fase 1 — Design System Completo
- Source: `docs/design-system.md`, `ka-beauty/docs/design-system.md`
- Bloqueia: todas as features de negócio

## Goal

Criar o design system base que todas as telas do app interno usarão. Impede que telas futuras quebrem o padrão visual.

## Users

Todos os perfis — o design system serve ao app como um todo.

## Screens

- `/dev/design-system` — página de showcase de todos os componentes (apenas em desenvolvimento)

## Main Flow

1. Design tokens definidos em `src/app/globals.css`
2. Componente criado em `src/design-system/<Component>/index.tsx`
3. Componente documentado com exemplos de todos os estados
4. Screenshot Playwright gerado (desktop + mobile)
5. Componente exportado em `src/design-system/index.ts`

## Business Rules

- Nenhum componente de tela pode usar CSS ad-hoc em vez de um componente do design system
- Todo componente deve ter todos os estados: default, hover, focus, disabled, loading, error
- Tap target mínimo: 40px em qualquer dispositivo
- Nenhum componente > 300 linhas

## Data Contract

N/A — design system não acessa dados.

## RLS And Permissions

N/A

## UX States

Cada componente deve implementar:
- `default` — estado normal
- `hover` — feedback visual no hover
- `focus` — ring de foco acessível
- `disabled` — desabilitado sem interação
- `loading` — skeleton ou spinner
- `error` — estado de erro com feedback claro

## Acceptance Criteria

- [ ] Todos os 37 componentes listados em `docs/design-system.md` criados
- [ ] Página `/dev/design-system` renderiza todos os componentes
- [ ] Nenhum overflow horizontal em 390px
- [ ] Screenshot desktop 1440px tirado com Playwright
- [ ] Screenshot mobile 390px tirado com Playwright
- [ ] `pnpm typecheck` passa sem erros
- [ ] `pnpm build` passa sem erros

## Tests

```ts
// e2e/design-system.spec.ts
test('design system desktop', async ({ page }) => {
  await page.goto('/dev/design-system');
  await expect(page).toHaveScreenshot('design-system-desktop.png');
});

test('design system mobile', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/dev/design-system');
  await expect(page).toHaveScreenshot('design-system-mobile.png');
});
```

## Out Of Scope

- Modo escuro (não é prioritário na v1)
- Storybook (substituído pela página `/dev/design-system`)
- Animações complexas (usar CSS transition simples)
