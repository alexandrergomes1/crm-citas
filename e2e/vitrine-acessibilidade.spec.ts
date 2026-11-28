// CA-5 · 0 violação WCAG A e AA na vitrine, fechada e com cada camada aberta (spec §8; plan.md §8; ADR 0004 · D5).
import AxeBuilder from '@axe-core/playwright'
import { expect, test, type Page } from '@playwright/test'

const etiquetas = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa']

async function violacoes(page: Page) {
  const resultado = await new AxeBuilder({ page }).withTags(etiquetas).analyze()
  return resultado.violations.map((v) => `${v.id}: ${v.nodes.map((n) => n.target.join(' ')).join(' | ')}`)
}

const ehCelular = () => test.info().project.name === 'celular'

test.beforeEach(async ({ page }) => {
  await page.goto('/vitrine')
  await expect(page.locator('.vt-valor').first()).not.toBeEmpty()
  await expect(page.locator('.ds-carregando[data-visivel="sim"]')).toBeAttached()
})

test('vitrine fechada', async ({ page }) => {
  expect(await violacoes(page)).toEqual([])
})

test('com a janelinha aberta', async ({ page }) => {
  await page.getByRole('button', { name: 'Abrir janelinha' }).click()
  await expect(page.getByRole('dialog')).toBeVisible()
  expect(await violacoes(page)).toEqual([])
})

test('com a folha (celular) ou o painel (computador) aberto', async ({ page }) => {
  await page.getByRole('button', { name: ehCelular() ? 'Abrir folha' : 'Abrir painel' }).click()
  await expect(page.getByRole('dialog', { name: 'Filtros' })).toBeVisible()
  expect(await violacoes(page)).toEqual([])
})

test('com o menu aberto', async ({ page }) => {
  await page.getByRole('region', { name: 'RC-13 · Menu aberto' }).getByRole('button', { name: 'Opções', exact: true }).click()
  await expect(page.getByRole('menu', { name: 'Opções' })).toBeVisible()
  expect(await violacoes(page)).toEqual([])
})
