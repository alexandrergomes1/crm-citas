// Página inicial (fundação, R1). Desde o Entrar (specs/20261128-030000-entrar-servico, plan.md §7 e §10), "/" é
// área com sessão: sem sessão vai a Entrar; o teste entra antes com a conta fictícia de um estúdio.
import { expect, test } from '@playwright/test'
import { conta, entrar } from './preparo-global'

test('sem sessão, a página inicial leva a Entrar', async ({ page }) => {
  await page.goto('/')
  await page.waitForURL('**/entrar')
  await expect(page.getByRole('heading', { name: 'Entrar' })).toBeVisible()
})

// Tela inicial (DESIGN.md §8b; E47·3·A): só a barra do topo com Sua conta; sem texto solto nem o nome do sistema.
test('com sessão, a página inicial mostra só a barra do topo, sem rolagem lateral', async ({ page }, info) => {
  const c = conta(info, 'um')
  await entrar(page, c)
  await expect(page.getByRole('banner').getByRole('button', { name: 'Sua conta' })).toBeVisible()
  await expect(page.getByRole('main')).toHaveText('')
  await expect(page.getByText('crm-citas')).toHaveCount(0)
  // O único texto da página é a inicial da bolinha (DESIGN.md §8b)
  expect((await page.locator('body').innerText()).trim()).toBe(c.email[0]!.toUpperCase())
  const semRolagemLateral = await page.evaluate(
    () => document.documentElement.scrollWidth <= document.documentElement.clientWidth,
  )
  expect(semRolagemLateral).toBe(true)
})
