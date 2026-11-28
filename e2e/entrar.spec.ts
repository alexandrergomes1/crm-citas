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

  // Sua conta com uma empresa só: sem "Trocar de empresa" (RF-14)
  const caixa = await abrirSuaConta(page, ehCelular(info))
  await expect(caixa.getByText('Trocar de empresa')).toHaveCount(0)
  await expect(caixa.getByText('Sair', { exact: true })).toBeVisible()
  // Itens do menu aberto em pílula, mesmo os de duas linhas (DESIGN.md §4; revisão de design R6)
  if (!ehCelular(info)) {
    for (const item of await caixa.getByRole('menuitem').all()) await expect(item).toHaveCSS('border-radius', '999px')
  }
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

test('Sua conta: aria-expanded fechado e aberto, Esc devolve o foco, setas e menu dentro da tela (revisão de código 1 e 2)', async ({
  page,
}, info) => {
  const c = conta(info, 'um')
  const celular = ehCelular(info)
  await entrar(page, c)
  await esperarPagina(page)
  const botao = page.getByRole('button', { name: 'Sua conta' })
  const caixa = celular ? page.getByRole('dialog', { name: 'Sua conta' }) : page.getByRole('menu', { name: 'Sua conta' })
  await expect(botao).toHaveAttribute('aria-haspopup', celular ? 'dialog' : 'menu')
  await expect(botao).toHaveAttribute('aria-expanded', 'false')

  // Aberto por toque: aria-expanded true; Esc fecha, aria-expanded volta a false e o foco volta ao botão
  await botao.click()
  await expect(caixa).toBeVisible()
  await expect(botao).toHaveAttribute('aria-expanded', 'true')
  await page.keyboard.press('Escape')
  await expect(caixa).toBeHidden()
  await expect(botao).toHaveAttribute('aria-expanded', 'false')
  await expect(botao).toBeFocused()
  if (celular) return

  // Computador: seta para baixo no botão abre o menu no primeiro item; as setas andam entre os itens
  const itens = caixa.getByRole('menuitem')
  await page.keyboard.press('ArrowDown')
  await expect(caixa).toBeVisible()
  await expect(botao).toHaveAttribute('aria-expanded', 'true')
  await expect(itens.first()).toBeFocused()
  await page.keyboard.press('ArrowUp')
  await expect(itens.last()).toBeFocused()

  // O menu fica dentro da tela, a --margem das bordas (DESIGN.md §4)
  const caixaNaTela = (await caixa.boundingBox())!
  const largura = await page.evaluate(() => document.documentElement.clientWidth)
  const margem = await page.evaluate(() => Number.parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--margem')))
  expect(caixaNaTela.x).toBeGreaterThanOrEqual(margem - 0.5)
  expect(caixaNaTela.x + caixaNaTela.width).toBeLessThanOrEqual(largura - margem + 0.5)

  await page.keyboard.press('Escape')
  await expect(caixa).toBeHidden()
  await expect(botao).toBeFocused()
  // Seta para cima no botão também abre o menu
  await page.keyboard.press('ArrowUp')
  await expect(itens.first()).toBeFocused()
  await capturar(page, info, 'sua-conta-teclado')
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

test('antes da página ficar interativa: Entrar não envia, nada vai ao endereço e o digitado fica (revisões R1, R-B)', async ({
  page,
  context,
}, info) => {
  const c = conta(info, 'um')
  const { pedidos } = observar(page)
  // Segura todo o JavaScript da página: o HTML do servidor fica na tela, sem React (antes da hidratação)
  let liberar: () => void = () => {}
  const segurado = new Promise<void>((pronto) => (liberar = pronto))
  await page.route('**/*', async (rota) => {
    if (rota.request().resourceType() === 'script') await segurado
    await rota.fallback()
  })
  // Módulos seguram o DOMContentLoaded: espera só a resposta e o título desenhado pelo servidor
  await page.goto('/entrar', { waitUntil: 'commit' })
  await expect(page.getByRole('heading', { name: 'Entrar' })).toBeVisible()

  const botao = page.getByRole('button', { name: 'Entrar' })
  const email = page.getByLabel('E-mail')
  const senha = page.getByLabel('Senha', { exact: true })
  await expect(botao).toBeDisabled()
  await expect(page.locator('form')).toHaveAttribute('method', 'post')
  await email.fill(c.email)
  await senha.fill(c.senha)
  // Enter no campo (envio implícito do HTML) e toque no botão: com o botão desativado, nenhum envio nativo
  await senha.press('Enter')
  await botao.click({ force: true })
  await page.waitForTimeout(500)
  expect(pedidos.filter((p) => p.resourceType() === 'document' && p.method() === 'POST').map((p) => p.url())).toEqual([])
  expect(pedidos.map((p) => p.url()).filter((u) => u.includes(c.senha) || u.includes(encodeURIComponent(c.senha)))).toEqual([])
  expect(new URL(page.url()).pathname).toBe('/entrar')
  expect(new URL(page.url()).search).toBe('')
  await expect(email).toHaveValue(c.email)
  await expect(senha).toHaveValue(c.senha)

  // Página interativa: o botão acorda, o digitado continua e a entrada vai pela ação do servidor
  liberar()
  await expect(botao).toBeEnabled()
  await expect(email).toHaveValue(c.email)
  await expect(senha).toHaveValue(c.senha)
  await page.unroute('**/*')
  await botao.click()
  await page.waitForURL((url) => url.pathname === '/')
  expect(pedidos.filter((p) => p.resourceType() === 'document' && p.method() === 'POST')).toEqual([])
  expect((await context.cookies()).some((k) => k.name.startsWith('__Host-sessao'))).toBe(true)
})

test('POST nativo em /entrar (se o botão fosse forçado): a página volta como está, sem a senha e sem sessão (revisões R1, R-B)', async ({
  page,
  context,
}, info) => {
  const c = conta(info, 'um')
  // O mesmo pedido que o navegador faria com o formulário sem React: corpo de formulário, nada no endereço
  const resposta = await page.request.post('/entrar', { form: { email: c.email, senha: c.senha } })
  expect(resposta.status()).toBe(200)
  expect(new URL(resposta.url()).search).toBe('')
  expect(resposta.headers()['cache-control']).toContain('no-store')
  const corpo = await resposta.text()
  expect(corpo).toContain('Entrar')
  expect(corpo).not.toContain(c.senha)
  expect(corpo).not.toContain(c.email)
  expect(corpo).not.toContain(encodeURIComponent(c.email))
  // O corpo é ignorado: ninguém entra por esse caminho
  expect((await context.cookies()).filter((k) => k.name.startsWith('__Host-sessao'))).toEqual([])
})

test('pedido forjado de outro site à ação Entrar é recusado; da mesma origem é aceito (RF-10, ASVS V4.2.2)', async ({
  page,
  playwright,
  baseURL,
}, info) => {
  const c = conta(info, 'um')
  // O pedido de verdade da ação Entrar (endereço, cabeçalhos e corpo), parado antes de chegar ao servidor
  let capturado: Request | undefined
  await page.route(SERVIDOR, async (rota) => {
    if (rota.request().method() !== 'POST') return rota.fallback()
    capturado = rota.request()
    await rota.abort()
  })
  await page.goto('/entrar')
  await preencherEntrar(page, c)
  await expect.poll(() => capturado).toBeDefined()
  const pedido = capturado!
  await page.unroute(SERVIDOR)

  // Repetido fora do navegador, com a origem de cada caso (o resto dos cabeçalhos e o corpo iguais)
  const fora = ['origin', 'referer', 'cookie', 'host', 'content-length']
  const cabecalhos = Object.fromEntries(
    Object.entries(await pedido.allHeaders()).filter(([k]) => !fora.includes(k) && !k.startsWith('sec-fetch-') && !k.startsWith(':')),
  )
  const corpo = pedido.postDataBuffer() ?? undefined
  const origem = new URL(baseURL!).origin
  const enviar = async (extra: Record<string, string>) => {
    const r = await playwright.request.newContext()
    const resposta = await r.post(pedido.url(), { headers: { ...cabecalhos, ...extra }, data: corpo, maxRedirects: 0 })
    const resultado = {
      status: resposta.status(),
      sessao: resposta.headersArray().some((h) => h.name.toLowerCase() === 'set-cookie' && h.value.startsWith('__Host-sessao')),
    }
    await r.dispose()
    return resultado
  }

  // Outro site: Origin de fora, o que o navegador marca como cross-site, ou nenhuma prova de origem → 403, sem sessão
  const forjados: Record<string, string>[] = [
    { origin: 'https://site-de-fora.example' },
    { 'sec-fetch-site': 'cross-site', origin: 'https://site-de-fora.example' },
    { 'sec-fetch-site': 'same-site' },
    { referer: 'https://site-de-fora.example/pagina' },
    {},
  ]
  for (const extra of forjados) {
    expect(await enviar(extra), JSON.stringify(extra)).toEqual({ status: 403, sessao: false })
  }
  // A mesma origem do app: a ação roda e a entrada dá certo
  expect(await enviar({ origin: origem })).toEqual({ status: 200, sessao: true })
  expect(await enviar({ 'sec-fetch-site': 'same-origin' })).toEqual({ status: 200, sessao: true })
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
