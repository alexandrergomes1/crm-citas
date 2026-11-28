// Escolher estúdio e Trocar de estúdio no navegador (spec specs/20261128-030000-entrar-servico; plan.md §9; T3).
// CA-19 escolher, carregando, erro, trocar e sair · CA-20 idioma do estúdio depois de escolher (RF-35).
// Pessoa fictícia com dois estúdios: "Estúdio Lírio" (pt) e "Estudio Nube" (es), criados pelo preparo global.
import { expect, test, type APIResponse, type Page, type Route } from '@playwright/test'
import { capturar, conta, ehCelular, entrar, esperarPagina, violacoes } from './preparo-global'

const SERVIDOR = '**/_serverFn/**'

/**
 * Intercepta só a resposta de `estudio.listar` (a que traz os nomes dos estúdios): as outras ações seguem intactas.
 * `comListar` decide o que fazer com ela (segurar ou derrubar).
 */
async function naLista(
  page: Page,
  nomeDeUmEstudio: string,
  comListar: (rota: Route, resposta: APIResponse, corpo: string) => Promise<void>,
) {
  await page.route(SERVIDOR, async (rota) => {
    if (rota.request().method() !== 'GET') return rota.fallback()
    const resposta = await rota.fetch()
    const corpo = await resposta.text()
    if (corpo.includes(nomeDeUmEstudio)) return comListar(rota, resposta, corpo)
    return rota.fulfill({ response: resposta, body: corpo })
  })
}

/** Abre Sua conta e devolve a caixa (folha no celular, menu no computador). */
async function abrirConta(page: Page, nome: string, celular: boolean) {
  await esperarPagina(page)
  await page.getByRole('button', { name: nome }).click()
  const caixa = celular ? page.getByRole('dialog', { name: nome }) : page.getByRole('menu', { name: nome })
  await expect(caixa).toBeVisible()
  return caixa
}

test('escolher, carregando, erro, trocar e sair, com o idioma de cada estúdio (CA-19, CA-20)', async ({ page }, info) => {
  const c = conta(info, 'dois')
  const [lirio, nube] = c.estudios.map((e) => e.nome) as [string, string]
  const celular = ehCelular(info)

  // Dois estúdios e nenhum escolhido: Entrar leva a Escolher estúdio (RF-11)
  await entrar(page, c, '/escolher-estudio')
  expect(new URL(page.url()).search).toBe('')
  await expect(page.getByRole('heading', { name: 'Escolher estúdio' })).toBeVisible()
  const lista = page.getByRole('list', { name: 'Escolher estúdio' })
  await expect(lista.locator('.ds-linha__titulo')).toHaveText([lirio, nube])
  await expect(page.getByText('2 estúdios')).toBeVisible()
  await capturar(page, info, 'escolher-estudio')
  expect(await violacoes(page)).toEqual([])

  // Carregando: a lista demora; aparecem as linhas cinza e o anúncio "Carregando estúdios"
  let liberar: () => void = () => {}
  const segurado = new Promise<void>((pronto) => (liberar = pronto))
  await naLista(page, lirio, async (rota, resposta, corpo) => {
    await segurado
    await rota.fulfill({ response: resposta, body: corpo })
  })
  await page.reload()
  await expect(page.locator('.ds-carregando[data-visivel="sim"]')).toBeVisible()
  await expect(page.getByRole('status')).toHaveText('Carregando estúdios')
  await capturar(page, info, 'escolher-estudio-carregando')
  expect(await violacoes(page)).toEqual([])
  liberar()
  await expect(lista.getByRole('button')).toHaveCount(2)
  await page.unroute(SERVIDOR)

  // Erro: só o título e "Tentar de novo" (sem parágrafo vazio), com "Sair" embaixo
  await naLista(page, lirio, (rota) => rota.abort())
  await page.reload()
  await expect(page.getByText('Não foi possível carregar')).toBeVisible()
  await expect(page.locator('.ds-estado p')).toHaveCount(1)
  await expect(page.locator('main p:empty')).toHaveCount(0)
  await expect(page.getByRole('button', { name: 'Sair' })).toBeVisible()
  await capturar(page, info, 'escolher-estudio-erro')
  expect(await violacoes(page)).toEqual([])
  await page.unroute(SERVIDOR)
  await page.getByRole('button', { name: 'Tentar de novo' }).click()
  await expect(lista.locator('.ds-linha__titulo')).toHaveText([lirio, nube])

  // Escolher o estúdio em espanhol: a área com sessão passa a espanhol (RF-35, CA-20)
  await lista.getByRole('button', { name: nube }).click()
  await page.waitForURL((url) => url.pathname === '/')
  await expect(page.locator('html')).toHaveAttribute('lang', 'es')
  await expect(page.locator('.ds-bolinha')).toHaveText(c.email[0]!.toUpperCase())
  const tuCuenta = await abrirConta(page, 'Tu cuenta', celular)
  await expect(tuCuenta.getByText('Cambiar de estudio')).toBeVisible()
  await capturar(page, info, 'sua-conta-com-troca-es')
  expect(await violacoes(page)).toEqual([])

  // Trocar de estúdio: volta à lista (ainda no idioma do estúdio atual) e escolhe o de português
  await tuCuenta.getByText('Cambiar de estudio').click()
  await page.waitForURL('**/escolher-estudio')
  await expect(page.getByRole('heading', { name: 'Elegir estudio' })).toBeVisible()
  const listaEs = page.getByRole('list', { name: 'Elegir estudio' })
  await expect(listaEs.locator('.ds-linha__titulo')).toHaveText([lirio, nube])
  await capturar(page, info, 'trocar-estudio')
  expect(await violacoes(page)).toEqual([])
  await listaEs.getByRole('button', { name: lirio }).click()
  await page.waitForURL((url) => url.pathname === '/')
  await expect(page.locator('html')).toHaveAttribute('lang', 'pt')

  // Sua conta com mais de um estúdio: "Trocar de estúdio" aparece (RF-14)
  const suaConta = await abrirConta(page, 'Sua conta', celular)
  await expect(suaConta.getByText('Trocar de estúdio')).toBeVisible()
  await capturar(page, info, 'sua-conta-com-troca')
  expect(await violacoes(page)).toEqual([])

  // Sair
  await suaConta.getByText('Sair', { exact: true }).click()
  await page.waitForURL('**/entrar')
  await expect(page.getByRole('heading', { name: 'Entrar' })).toBeVisible()
})
