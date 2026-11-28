// Página inicial (fundação, R1). Desde o Entrar (specs/20261128-030000-entrar-servico, plan.md §7 e §10), "/" é
// área com sessão: sem sessão vai a Entrar; o teste entra antes com a conta fictícia de um estúdio.
import { expect, test } from '@playwright/test'
import { conta, entrar } from './preparo-global'

test('sem sessão, a página inicial leva a Entrar', async ({ page }) => {
  await page.goto('/')
  await page.waitForURL('**/entrar')
  await expect(page.getByRole('heading', { name: 'Entrar' })).toBeVisible()
})

test('com sessão, a página inicial mostra crm-citas sem rolagem lateral', async ({ page }, info) => {
  await entrar(page, conta(info, 'um'))
  await expect(page.getByText('crm-citas', { exact: true })).toBeVisible()
  const semRolagemLateral = await page.evaluate(
    () => document.documentElement.scrollWidth <= document.documentElement.clientWidth,
  )
  expect(semRolagemLateral).toBe(true)
})
