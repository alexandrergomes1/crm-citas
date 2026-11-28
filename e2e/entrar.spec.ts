// Entrar, Sua conta e Sair no navegador (spec specs/20261128-030000-entrar-servico; plan.md §9; tarefa T3).
// CA-02 cookie e armazenamento · CA-03 nenhuma ida do navegador ao banco · CA-13 no-store e voltar depois de sair ·
// CA-18a senha longa · CA-19 estados com checagem automática de acessibilidade · CA-20 idioma do navegador.
// Projetos `celular` (390) e `computador` (1440); contas fictícias da rodada (e2e/preparo-global.ts).
import { expect, test, type Page, type Request, type Response } from '@playwright/test'
import { capturar, conta, ehCelular, entrar, esperarPagina, origemDoBanco, preencherEntrar, violacoes } from './preparo-global'

const SERVIDOR = '**/_serverFn/**'

/** Guarda os pedidos e as respostas da página (CA-03, CA-13). */
function observar(page: Page) {
  const pedidos: Request[] = []
  const respostas: Response[] = []
  page.on('request', (r) => pedidos.push(r))
  page.on('response', (r) => respostas.push(r))
  return { pedidos, respostas }
}

/** Abre Sua conta: folha no celular, menu no computador (DESIGN.md §8b). */
async function abrirSuaConta(page: Page, celular: boolean) {
  await esperarPagina(page)
  await page.getByRole('button', { name: 'Sua conta' }).click()
  const caixa = celular ? page.getByRole('dialog', { name: 'Sua conta' }) : page.getByRole('menu', { name: 'Sua conta' })
  await expect(caixa).toBeVisible()
  return caixa
}

test('entrar: carregando, sucesso, cookie só do servidor e nenhuma ida ao banco (CA-02, CA-03, CA-13, CA-18a, CA-19)', async ({
  page,
  context,
}, info) => {
  const c = conta(info, 'um')
  const { pedidos, respostas } = observar(page)

  // Sem sessão, "/" vai a Entrar; o endereço é só o caminho (RF-33)
  await page.goto('/')
  await page.waitForURL('**/entrar')
  expect(new URL(page.url()).search).toBe('')
  await expect(page.getByRole('heading', { name: 'Entrar' })).toBeVisible()
  await expect(page.locator('html')).toHaveAttribute('lang', 'pt')
  await esperarPagina(page)
  await capturar(page, info, 'entrar-vazio')
  expect(await violacoes(page)).toEqual([])

  // CA-18a: 70 caracteres entram inteiros (sem maxlength) e chegam ao servidor (a entrada dá certo)
  const senha = page.getByLabel('Senha', { exact: true })
  await expect(senha).not.toHaveAttribute('maxlength')
  await page.getByLabel('E-mail').fill(c.email)
  await senha.fill(c.senha)
  expect(c.senha.length).toBeGreaterThanOrEqual(64)
  expect(await senha.inputValue()).toBe(c.senha)

  // Mostrar e esconder a senha (E41·2·A)
  await page.getByRole('button', { name: 'Mostrar senha' }).click()
  await expect(senha).toHaveAttribute('type', 'text')
  await capturar(page, info, 'entrar-senha-mostrada')
  await page.getByRole('button', { name: 'Esconder senha' }).click()
  await expect(senha).toHaveAttribute('type', 'password')

  // Carregando: a resposta da ação fica parada um pouco para o estado ser visto e conferido
  let liberar: () => void = () => {}
  const segurado = new Promise<void>((pronto) => (liberar = pronto))
  await page.route(SERVIDOR, async (rota) => {
    if (rota.request().method() === 'POST') await segurado
    await rota.fallback()
  })
  await page.getByRole('button', { name: 'Entrar' }).click()
  const botao = page.getByRole('button', { name: 'Entrando…' })
  await expect(botao).toHaveAttribute('aria-busy', 'true')
  await expect(botao).toHaveAttribute('aria-disabled', 'true')
  await expect(page.getByLabel('E-mail')).toHaveAttribute('readonly')
  await expect(page.getByRole('status')).toHaveText('Entrando…')
  await capturar(page, info, 'entrar-carregando')
  expect(await violacoes(page)).toEqual([])
  liberar()
  await page.waitForURL((url) => url.pathname === '/')
  await page.unroute(SERVIDOR)

  // Sucesso: a área com sessão, com a inicial do e-mail na bolinha Sua conta (DESIGN.md §8b)
  await expect(page.getByRole('button', { name: 'Sua conta' })).toBeVisible()
  await expect(page.locator('.ds-bolinha')).toHaveText(c.email[0]!.toUpperCase())
  await capturar(page, info, 'inicio-com-sessao')
  expect(await violacoes(page)).toEqual([])

  // CA-02: cookie HttpOnly, Secure, Lax; invisível ao JavaScript; nada no armazenamento do navegador
  const cookies = (await context.cookies()).filter((k) => k.name.startsWith('__Host-sessao'))
  expect(cookies.length).toBeGreaterThan(0)
  for (const k of cookies) expect(k).toMatchObject({ httpOnly: true, secure: true, sameSite: 'Lax', path: '/' })
  expect(await page.evaluate(() => document.cookie)).not.toContain('sessao')
  expect(await page.evaluate(() => [localStorage.length, sessionStorage.length])).toEqual([0, 0])

  // Sua conta com um estúdio só: sem "Trocar de estúdio" (RF-14)
  const caixa = await abrirSuaConta(page, ehCelular(info))
  await expect(caixa.getByText('Trocar de estúdio')).toHaveCount(0)
  await expect(caixa.getByText('Sair', { exact: true })).toBeVisible()
  await capturar(page, info, 'sua-conta-sem-troca')
  expect(await violacoes(page)).toEqual([])

  // CA-03: nenhum pedido da página ao banco; nada pessoal em endereço nenhum (RF-33)
  const banco = origemDoBanco()
  expect(pedidos.length).toBeGreaterThan(0)
  expect(pedidos.map((p) => p.url()).filter((u) => u.startsWith(banco) || /\/(auth|rest)\/v1\//.test(u))).toEqual([])
  expect(pedidos.map((p) => p.url()).filter((u) => u.includes(c.email) || u.includes(encodeURIComponent(c.email)))).toEqual([])
  expect(pedidos.map((p) => p.url()).filter((u) => u.includes(c.senha))).toEqual([])

  // CA-13: toda página e toda resposta de ação com no-store
  const conferidas = respostas.filter((r) => r.request().resourceType() === 'document' || r.url().includes('/_serverFn/'))
  expect(conferidas.some((r) => r.url().includes('/_serverFn/'))).toBe(true)
  for (const r of conferidas) expect(r.headers()['cache-control'], r.url()).toContain('no-store')
})

test('entrar com senha errada: frase única, senha limpa, foco na Senha (CA-19 erro)', async ({ page }, info) => {
  const c = conta(info, 'um')
  await page.goto('/entrar')
  await preencherEntrar(page, { email: c.email, senha: 'senha-errada-ficticia' })
  await expect(page.getByRole('alert')).toHaveText('Não foi possível entrar. Confira o e-mail e a senha e tente de novo.')
  const senha = page.getByLabel('Senha', { exact: true })
  await expect(senha).toBeFocused()
  await expect(senha).toHaveValue('')
  await expect(page.getByLabel('E-mail')).toHaveValue(c.email)
  expect(new URL(page.url()).pathname).toBe('/entrar')
  expect(new URL(page.url()).search).toBe('')
  await capturar(page, info, 'entrar-erro')
  expect(await violacoes(page)).toEqual([])
})

test('sair: volta a Entrar, o cookie some e voltar no navegador não mostra dado (CA-13, CA-19 sair)', async ({
  page,
  context,
}, info) => {
  const c = conta(info, 'um')
  await entrar(page, c)
  // Uma página com dado no histórico (a lista com o nome do estúdio), para o "voltar" ter para onde ir. Ir de novo ao
  // mesmo endereço substituiria a entrada do histórico em vez de criar outra.
  const estudio = c.estudios[0]!.nome
  await page.goto('/escolher-estudio')
  await expect(page.getByRole('button', { name: estudio })).toBeVisible()
  await page.goto('/')
  await expect(page.getByRole('button', { name: 'Sua conta' })).toBeVisible()

  const caixa = await abrirSuaConta(page, ehCelular(info))
  await caixa.getByText('Sair', { exact: true }).click()
  await page.waitForURL('**/entrar')
  await expect(page.getByRole('heading', { name: 'Entrar' })).toBeVisible()
  expect((await context.cookies()).filter((k) => k.name.startsWith('__Host-sessao'))).toEqual([])
  await capturar(page, info, 'depois-de-sair')
  expect(await violacoes(page)).toEqual([])

  // Voltar: a página com sessão não volta do cache; quem aparece é Entrar
  await page.goBack()
  await page.waitForURL('**/entrar')
  await expect(page.getByRole('heading', { name: 'Entrar' })).toBeVisible()
  await expect(page.getByText(estudio)).toHaveCount(0)
  await expect(page.getByRole('button', { name: 'Sua conta' })).toHaveCount(0)
})

// CA-20: antes de escolher o estúdio, vale o idioma do navegador (spec RF-34)
for (const [locale, idioma, titulo, rotulo] of [
  ['es-ES', 'es', 'Entrar', 'Correo electrónico'],
  ['en-GB', 'en', 'Sign in', 'Email'],
] as const) {
  test.describe(`Entrar em ${idioma}`, () => {
    test.use({ locale })
    test(`textos em ${idioma} (CA-20)`, async ({ page }) => {
      await page.goto('/entrar')
      await expect(page.locator('html')).toHaveAttribute('lang', idioma)
      await expect(page.getByRole('heading', { name: titulo })).toBeVisible()
      await expect(page.getByLabel(rotulo)).toBeVisible()
      expect(await violacoes(page)).toEqual([])
    })
  })
}
