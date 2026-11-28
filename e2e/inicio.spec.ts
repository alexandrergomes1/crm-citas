import { expect, test } from '@playwright/test'

test('a página inicial mostra crm-citas sem rolagem lateral', async ({ page }) => {
  await page.goto('/')
  await expect(page.getByText('crm-citas', { exact: true })).toBeVisible()
  const semRolagemLateral = await page.evaluate(
    () => document.documentElement.scrollWidth <= document.documentElement.clientWidth,
  )
  expect(semRolagemLateral).toBe(true)
})
