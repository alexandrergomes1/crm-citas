// Vitrine em 390 (celular) e 1440 (computador): CA-3, CA-4, CA-6, CA-7, RA-2, RA-6 (spec §8; plan.md §8).
import { expect, test, type Locator, type Page } from '@playwright/test'

const quadros = [
  'Tokens',
  'RC-1 · Botão',
  'RC-2 · Botão de ícone',
  'RC-3 · Botão com ícone e nome',
  'RC-4 · Contador',
  'RC-5 · Agendar',
  'RC-6 · Seletor',
  'RC-7 · Campos',
  'RC-8 · Busca',
  'RC-9 · Caixinha e interruptor',
  'RC-10 · Etiqueta e status',
  'RC-11 · Bloco',
  'RC-12 · Lista e tabela',
  'RC-13 · Menu aberto',
  'RC-14 · Janelinha de confirmação',
  'RC-15 · Aviso',
  'RC-16 · Folha e painel',
  'RC-17 · Estados de tela',
  'RC-18 · Estrutura do computador',
  'RC-19 · Estrutura do celular',
  'RC-20 · Bolinha e Sua conta',
  'RC-21 · Linha do tempo',
  'RC-22 · Resumo de valores',
] as const

const quadro = (page: Page, nome: (typeof quadros)[number]) => page.getByRole('region', { name: nome, exact: true })

async function caixa(alvo: Locator) {
  const c = await alvo.boundingBox()
  if (!c) throw new Error('sem caixa: elemento invisível')
  return c
}

async function abrirVitrine(page: Page) {
  await page.goto('/vitrine')
  // a vitrine lê os valores do tokens.css no navegador: quando aparecem, a página já está ativa (hidratada)
  await expect(page.locator('.vt-valor').first()).not.toBeEmpty()
}

const ehCelular = () => test.info().project.name === 'celular'

test.beforeEach(async ({ page }) => {
  await abrirVitrine(page)
})

test('CA-3 · os 22 componentes e os tokens aparecem, cada um no seu quadro', async ({ page }) => {
  for (const nome of quadros) await expect(quadro(page, nome)).toBeVisible()

  const botoes = quadro(page, 'RC-1 · Botão')
  for (const nome of ['Adicionar', 'Cancelar', 'Excluir', 'Exportar']) {
    await expect(botoes.getByRole('button', { name: nome }).first()).toBeVisible()
  }
  await expect(botoes.getByRole('button', { name: 'Exportar' })).toBeDisabled()
  await expect(botoes.getByText('em desenvolvimento')).toBeVisible()

  for (const nome of ['Fechar', 'Voltar', 'Opções', 'Ajuda', 'Notificações', 'Filtros', 'Recolher menu']) {
    await expect(quadro(page, 'RC-2 · Botão de ícone').getByRole('button', { name: nome, exact: true })).toBeVisible()
  }

  await expect(quadro(page, 'RC-4 · Contador').getByText('21, 4 pendentes')).toBeAttached()
  await expect(quadro(page, 'RC-6 · Seletor').getByRole('tablist', { name: 'Abas do agendamento' })).toBeVisible()

  const campos = quadro(page, 'RC-7 · Campos')
  await expect(campos.getByRole('textbox', { name: 'Telefone' })).toHaveAttribute('aria-invalid', 'true')
  await expect(campos.getByText('Informe o telefone para enviar lembretes.')).toBeVisible()
  await expect(campos.getByRole('combobox', { name: 'Categoria' })).toBeVisible()
  await expect(campos.getByRole('textbox', { name: 'Código' })).toBeDisabled()

  await expect(quadro(page, 'RC-8 · Busca').getByRole('searchbox', { name: 'Buscar serviço' })).toBeVisible()
  await expect(quadro(page, 'RC-9 · Caixinha e interruptor').getByRole('checkbox', { name: 'Marcado', exact: true })).toBeChecked()
  await expect(quadro(page, 'RC-9 · Caixinha e interruptor').getByRole('switch', { name: 'Ligado', exact: true })).toBeChecked()
  await expect(quadro(page, 'RC-10 · Etiqueta e status').getByRole('img', { name: 'Reservado' })).toBeVisible()
  await expect(quadro(page, 'RC-10 · Etiqueta e status').getByRole('button', { name: 'Confirmado. Trocar status' })).toBeVisible()

  const estados = quadro(page, 'RC-17 · Estados de tela')
  await expect(estados.getByText('Ainda não há serviços')).toBeVisible()
  await expect(estados.getByRole('button', { name: 'Limpar filtros' })).toBeVisible()
  await expect(estados.getByRole('button', { name: 'Tentar de novo' })).toBeVisible()
  // carregando: linhas só depois de 0,3 s, anunciadas ao leitor
  await expect(estados.getByRole('status').filter({ hasText: 'Carregando serviços' })).toBeAttached()

  if (ehCelular()) {
    await expect(page.getByRole('navigation', { name: 'Navegação principal' })).toBeVisible()
    await expect(page.getByRole('navigation', { name: 'Seções de Formulários' })).toBeVisible()
  } else {
    await expect(page.getByRole('navigation', { name: 'Menu principal aberto' })).toBeVisible()
    await expect(page.getByRole('navigation', { name: 'Menu principal recolhido' })).toBeVisible()
    await expect(page.getByRole('navigation', { name: 'Seções do Catálogo' })).toBeVisible()
    await expect(page.getByRole('searchbox', { name: 'Buscar no sistema' }).first()).toBeVisible()
    await expect(page.getByRole('table', { name: 'Clientes' })).toBeVisible()
  }
})

test('CA-4 · medidas do DESIGN.md §4 e §8b', async ({ page }) => {
  const controle = ehCelular() ? 44 : 40

  expect((await caixa(quadro(page, 'RC-1 · Botão').getByRole('button', { name: 'Cancelar' }))).height).toBe(controle)
  const fechar = await caixa(quadro(page, 'RC-2 · Botão de ícone').getByRole('button', { name: 'Fechar' }))
  expect([fechar.width, fechar.height]).toEqual([controle, controle])
  expect((await caixa(quadro(page, 'RC-7 · Campos').getByRole('textbox', { name: 'Nome' }))).height).toBe(44)

  const seletor = quadro(page, 'RC-6 · Seletor')
  expect((await caixa(seletor.getByRole('tablist', { name: 'Abas do agendamento' }))).height).toBe(44)
  expect((await caixa(seletor.getByRole('tab', { name: 'Resumo' }))).height).toBe(44)
  expect((await caixa(seletor.locator('.ds-seletor__desenho').first())).height).toBe(36)

  expect((await caixa(quadro(page, 'RC-5 · Agendar').locator('.ds-agendar__circulo'))).height).toBe(52)
  const pilula = await caixa(quadro(page, 'RC-4 · Contador').locator('.ds-contador').first())
  expect(pilula.height).toBe(20)
  expect(pilula.width).toBeGreaterThanOrEqual(20)

  const marcaveis = quadro(page, 'RC-9 · Caixinha e interruptor')
  const caixinha = await caixa(marcaveis.getByRole('checkbox', { name: 'Marcado', exact: true }))
  expect([caixinha.width, caixinha.height]).toEqual([22, 22])
  const interruptor = await caixa(marcaveis.getByRole('switch', { name: 'Ligado', exact: true }))
  expect([interruptor.width, interruptor.height]).toEqual([44, 26])
  expect((await caixa(marcaveis.locator('.ds-marcavel').first())).height).toBeGreaterThanOrEqual(controle)

  const status = await caixa(quadro(page, 'RC-10 · Etiqueta e status').locator('.ds-botao-status__desenho'))
  expect(status.height).toBe(36)
  expect((await caixa(quadro(page, 'RC-10 · Etiqueta e status').locator('.ds-botao-status'))).height).toBe(44)
  expect((await caixa(quadro(page, 'RC-12 · Lista e tabela').locator('.ds-linha').first())).height).toBeGreaterThanOrEqual(64)

  if (ehCelular()) {
    expect((await caixa(page.getByRole('navigation', { name: 'Navegação principal' }))).height).toBe(72)
    expect((await caixa(quadro(page, 'RC-19 · Estrutura do celular').locator('.ds-cabecalho').first())).height).toBe(64)
  } else {
    expect((await caixa(page.getByRole('navigation', { name: 'Menu principal aberto' }))).width).toBe(232)
    expect((await caixa(page.getByRole('navigation', { name: 'Menu principal recolhido' }))).width).toBe(84)
    expect((await caixa(page.getByRole('navigation', { name: 'Seções do Catálogo' }))).width).toBe(216)
    expect((await caixa(quadro(page, 'RC-18 · Estrutura do computador').locator('.ds-barra-topo'))).height).toBe(64)
    expect((await caixa(quadro(page, 'RC-18 · Estrutura do computador').locator('.ds-barra-topo__titulo'))).width).toBe(280)
    expect((await caixa(quadro(page, 'RC-18 · Estrutura do computador').getByRole('searchbox', { name: 'Buscar no sistema' }))).width).toBe(320)
    expect((await caixa(quadro(page, 'RC-8 · Busca').getByRole('searchbox', { name: 'Buscar serviço' }))).width).toBe(280)
    const tabela = page.getByRole('table', { name: 'Clientes' })
    expect((await caixa(tabela.locator('th').first())).height).toBe(36)
    expect((await caixa(tabela.locator('td').first())).height).toBe(40)

    await quadro(page, 'RC-14 · Janelinha de confirmação').getByRole('button', { name: 'Abrir janelinha' }).click()
    expect((await caixa(page.getByRole('dialog'))).width).toBe(340)
    await page.keyboard.press('Escape')
    await quadro(page, 'RC-16 · Folha e painel').getByRole('button', { name: 'Abrir painel' }).click()
    expect((await caixa(page.getByRole('dialog', { name: 'Filtros' }))).width).toBe(480)
    await page.keyboard.press('Escape')
    await quadro(page, 'RC-13 · Menu aberto').getByRole('button', { name: 'Opções', exact: true }).click()
    expect((await caixa(page.getByRole('menu', { name: 'Opções' }))).width).toBe(240)
  }
})

test('RA-2 · todo botão visível tem área de toque de 44 (celular) ou 40 (computador)', async ({ page }) => {
  const toque = ehCelular() ? 44 : 40
  const pequenos = await page.locator('button:visible').evaluateAll(
    (botoes, minimo) =>
      botoes
        .map((b) => ({ nome: b.getAttribute('aria-label') ?? b.textContent ?? '', r: b.getBoundingClientRect() }))
        .filter(({ r }) => r.width < minimo || r.height < minimo)
        .map(({ nome, r }) => `${nome} ${r.width}x${r.height}`),
    toque,
  )
  expect(pequenos).toEqual([])
})

test('CA-6 · Tab percorre os controles com o anel de 2 px visível, sem tabindex positivo', async ({ page }) => {
  expect(await page.locator('[tabindex]:not([tabindex="0"]):not([tabindex="-1"])').count()).toBe(0)
  const semAnel: string[] = []
  const vistos = new Set<string>()
  let anterior = ''
  for (let i = 0; i < 400; i++) {
    await page.keyboard.press('Tab')
    const foco = await page.evaluate(() => {
      const el = document.activeElement as HTMLElement | null
      if (!el || el === document.body) return null
      const estilo = getComputedStyle(el)
      const r = el.getBoundingClientRect()
      return {
        chave: `${el.tagName}|${el.id}|${el.getAttribute('aria-label') ?? ''}|${el.textContent?.slice(0, 30) ?? ''}|${r.x}|${r.y + window.scrollY}`,
        anel: estilo.outlineStyle === 'solid' && estilo.outlineWidth === '2px',
      }
    })
    if (!foco) break
    // o campo de data tem dia, mês e ano: o Tab passa por eles sem trocar de elemento
    if (foco.chave === anterior) continue
    if (vistos.has(foco.chave)) break
    anterior = foco.chave
    vistos.add(foco.chave)
    if (!foco.anel) semAnel.push(foco.chave)
  }
  expect(vistos.size).toBeGreaterThan(40)
  expect(semAnel).toEqual([])
})

test('CA-6 · setas, Home e End trocam a aba do seletor', async ({ page }) => {
  const abas = quadro(page, 'RC-6 · Seletor').getByRole('tablist', { name: 'Abas do agendamento' })
  await abas.getByRole('tab', { name: 'Resumo' }).focus()
  await page.keyboard.press('ArrowRight')
  await expect(abas.getByRole('tab', { name: 'Notas' })).toBeFocused()
  await expect(abas.getByRole('tab', { name: 'Notas' })).toHaveAttribute('aria-selected', 'true')
  await expect(quadro(page, 'RC-6 · Seletor').getByText('Ainda não há notas')).toBeVisible()
  await page.keyboard.press('End')
  await expect(abas.getByRole('tab', { name: 'Atividade' })).toHaveAttribute('aria-selected', 'true')
  await page.keyboard.press('Home')
  await expect(abas.getByRole('tab', { name: 'Resumo' })).toHaveAttribute('aria-selected', 'true')
  await page.keyboard.press('ArrowLeft')
  await expect(abas.getByRole('tab', { name: 'Atividade' })).toBeFocused()
})

test('CA-6 · Esc fecha janelinha, folha ou painel e menu, e devolve o foco', async ({ page }) => {
  const abrirJanelinha = quadro(page, 'RC-14 · Janelinha de confirmação').getByRole('button', { name: 'Abrir janelinha' })
  await abrirJanelinha.click()
  const janelinha = page.getByRole('dialog', { name: 'Excluir "Limpeza simples"?' })
  await expect(janelinha).toBeVisible()
  await page.keyboard.press('Escape')
  await expect(janelinha).toBeHidden()
  await expect(abrirJanelinha).toBeFocused()

  const abrirCamada = quadro(page, 'RC-16 · Folha e painel').getByRole('button', {
    name: ehCelular() ? 'Abrir folha' : 'Abrir painel',
  })
  await abrirCamada.click()
  const camada = page.getByRole('dialog', { name: 'Filtros' })
  await expect(camada).toBeVisible()
  await expect(camada.getByRole('button', { name: 'Mostrar 8 clientes' })).toBeVisible()
  await page.keyboard.press('Escape')
  await expect(camada).toBeHidden()
  await expect(abrirCamada).toBeFocused()

  const opcoes = quadro(page, 'RC-13 · Menu aberto').getByRole('button', { name: 'Opções', exact: true })
  await opcoes.click()
  const menu = page.getByRole('menu', { name: 'Opções' })
  await expect(menu).toBeVisible()
  await expect(menu.getByRole('menuitem', { name: 'Importar' })).toBeFocused()
  await page.keyboard.press('ArrowDown')
  await expect(menu.getByRole('menuitem', { name: 'Exportar' })).toBeFocused()
  await page.keyboard.press('Escape')
  await expect(menu).toBeHidden()
  await expect(opcoes).toBeFocused()

  const linha = quadro(page, 'RC-13 · Menu aberto').getByRole('button', { name: 'Opções da linha' })
  await linha.click()
  await expect(page.getByRole('menu', { name: 'Opções da linha' }).getByRole('menuitem')).toHaveText([
    'Editar',
    'Duplicar',
    'Arquivar',
    'Excluir',
  ])
})

test('RA-6 · com movimento reduzido nenhuma transição tem duração', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' })
  const comDuracao = await page.evaluate(() => {
    const achados: string[] = []
    for (const el of document.querySelectorAll('*')) {
      for (const pseudo of [null, '::before', '::after']) {
        const e = getComputedStyle(el, pseudo)
        const duracoes = `${e.transitionDuration},${e.animationDuration}`.split(',').map((d) => Number.parseFloat(d))
        if (duracoes.some((d) => d > 0)) achados.push(`${el.className}${pseudo ?? ''}`)
      }
    }
    return achados
  })
  expect(comDuracao).toEqual([])
})

test('sem rolagem lateral e CA-7 · captura da vitrine inteira', async ({ page }, testInfo) => {
  const semRolagemLateral = await page.evaluate(
    () => document.documentElement.scrollWidth <= document.documentElement.clientWidth,
  )
  expect(semRolagemLateral).toBe(true)
  await expect(page.locator('.ds-carregando[data-visivel="sim"]')).toBeAttached()
  await page.screenshot({ fullPage: true, path: testInfo.outputPath(`vitrine-${testInfo.project.name}.png`) })
})
