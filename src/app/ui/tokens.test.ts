// CA-1 e CA-2 (spec §8; plan.md §7; ADR 0004 · D7).
// CA-1: lê a tabela do DESIGN.md §3 (fonte única, sem lista copiada) e compara com o tokens.css;
//       RT-2 a RT-8 comparados com a lista do plan.md §4.
// CA-2: nenhuma cor, sombra, raio ou medida escrita solta fora do tokens.css (RT-9).
import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'

const raiz = join(import.meta.dirname, '..', '..', '..')
const ler = (...partes: string[]) => readFileSync(join(raiz, ...partes), 'utf8')

const semComentarios = (css: string) => css.replace(/\/\*[\s\S]*?\*\//g, '')

/** Declarações de um bloco `seletor { ... }` (o primeiro que casar) */
function declaracoes(css: string, inicio: RegExp): Map<string, string> {
  const texto = semComentarios(css)
  const achado = inicio.exec(texto)
  if (!achado) throw new Error(`bloco não achado: ${inicio}`)
  const abre = texto.indexOf('{', achado.index + achado[0].length - 1)
  const fecha = texto.indexOf('}', abre)
  const mapa = new Map<string, string>()
  for (const linha of texto.slice(abre + 1, fecha).split(';')) {
    const m = /^\s*(--[\w-]+)\s*:\s*([\s\S]+?)\s*$/.exec(linha)
    if (m?.[1] && m[2]) mapa.set(m[1], m[2].replace(/\s+/g, ' '))
  }
  return mapa
}

const tokensCss = ler('src/app/estilos/tokens.css')
const raizTokens = declaracoes(tokensCss, /^:root\s*\{/m)
const computador = declaracoes(tokensCss, /@media[^{]*\{\s*:root\s*\{/)

/** Linhas da tabela "## 3. Cores" do DESIGN.md: nome(s) → valor(es) */
function coresDoDesign(): Array<[string, string]> {
  const design = ler('DESIGN.md')
  const secao = /## 3\. Cores[\s\S]*?(?=\n## )/.exec(design)?.[0]
  if (!secao) throw new Error('DESIGN.md §3 não achado')
  const pares: Array<[string, string]> = []
  for (const linha of secao.split('\n')) {
    if (!linha.startsWith('| `--')) continue
    const [, colNomes = '', colValores = ''] = linha.split('|')
    let nomes = [...colNomes.matchAll(/--[A-Za-z0-9]+/g)].map((m) => m[0])
    const valores = [...colValores.matchAll(/#[0-9A-Fa-f]{6}/g)].map((m) => m[0])
    // "`--c1`…`--c4`": faixa
    const faixa = /--([a-z]+)(\d+)`…`--\1(\d+)/.exec(colNomes)
    if (faixa?.[1] && faixa[2] && faixa[3]) {
      nomes = []
      for (let i = Number(faixa[2]); i <= Number(faixa[3]); i++) nomes.push(`--${faixa[1]}${i}`)
    }
    nomes.forEach((nome, i) => pares.push([nome, (valores.length === 1 ? valores[0] : valores[i]) ?? '']))
  }
  return pares
}

/** plan.md §4 (RT-2 a RT-8 e ícones), valores do DESIGN.md §4, §5, §8b */
const esperadoRaiz: Record<string, string> = {
  '--pillSoft': 'rgba(22,24,29,.07)',
  '--warnInk': '#8A5205',
  '--selRing': '#D8D7D1',
  '--font': "'Geist Variable', system-ui, sans-serif",
  '--fs-20': '20px', '--fs-18': '18px', '--fs-16': '16px', '--fs-15': '15px',
  '--fs-14': '14px', '--fs-13': '13px', '--fs-12': '12px', '--fs-11': '11px',
  '--fw-normal': '400', '--fw-medio': '500',
  // PONTO A MUDAR (E25·2): forte, alturas de linha e ícones pela recomendação A (canvas aprovado)
  '--fw-forte': '600', '--lh-titulo': '1.2', '--lh-texto': '1.4',
  '--ic-14': '14px', '--ic-16': '16px', '--ic-18': '18px', '--ic-20': '20px', '--ic-24': '24px', '--ic-traco': '1.75',
  '--sp-4': '4px', '--sp-8': '8px', '--sp-12': '12px', '--sp-16': '16px', '--sp-20': '20px', '--sp-24': '24px', '--sp-32': '32px',
  '--margem': '16px', '--entre-blocos': '12px',
  '--r-pilula': '999px', '--r-bloco': '20px', '--r-campo-multi': '16px', '--r-menu-recolhido': '16px',
  '--r-janelinha': '24px', '--r-folha': '28px', '--r-inicial': '10px', '--r-caixinha': '7px', '--r-contador': '10px',
  '--sombra-flutua': '0 16px 40px rgba(22,24,29,.18)',
  '--sombra-escolhido': '0 0 0 1px var(--selRing), 0 1px 3px rgba(22,24,29,.14)',
  '--sombra-cabecalho': '0 1px 0 var(--line), 0 6px 14px -10px rgba(22,24,29,.25)',
  '--borda': '1px',
  '--h-controle': '44px', '--toque': '44px', '--h-campo': '44px', '--h-linha-lista': '64px', '--h-barra-baixo': '72px',
  '--h-cabecalho': '64px', '--h-linha-tabela': '40px', '--h-cab-tabela': '36px', '--h-barra-topo': '64px',
  '--w-menu-aberto': '232px', '--w-menu-recolhido': '84px', '--w-submenu': '216px', '--h-seletor': '44px',
  '--h-seletor-item': '36px', '--folga-seletor': '4px', '--d-agendar': '52px', '--h-status': '36px',
  '--d-caixinha': '22px', '--w-interruptor': '44px', '--h-interruptor': '26px', '--h-contador': '20px',
  '--w-contador-min': '20px', '--folga-contador': '7px', '--folga-btn-ic-esq': '12px', '--folga-btn-ic-dir': '10px',
  '--espaco-ic': '6px', '--w-titulo-barra': '280px', '--w-busca-geral': '320px', '--w-busca-tela': '280px',
  '--w-menu-flutua': '240px', '--w-janelinha': '340px', '--w-painel': '480px', '--d-bolinha': '40px',
  '--d-bolinha-tabela': '24px', '--d-bolinha-tempo': '36px', '--d-ponto': '8px', '--w-faixa': '4px', '--w-linha-tempo': '2px',
  '--foco-cor': 'var(--ink3)', '--foco-largura': '2px', '--foco-afastado': '2px', '--opac-desativado': '.6',
  '--atraso-carregando': '300ms',
}

/** Computador (DESIGN.md §4): margem 24, controle e toque 40, texto 14 */
const esperadoComputador: Record<string, string> = {
  '--fs-texto': 'var(--fs-14)',
  '--margem': '24px',
  '--h-controle': '40px',
  '--toque': '40px',
}

describe('CA-1 · tokens iguais ao DESIGN.md', () => {
  const cores = coresDoDesign()

  it('a tabela do DESIGN.md §3 foi lida (21 cores, de --page a --c4)', () => {
    expect(cores.map(([n]) => n)).toEqual([
      '--page', '--card', '--btn', '--track', '--line', '--ink', '--ink2', '--ink3', '--field', '--id', '--brand',
      '--warn', '--warnSoft', '--ok', '--okInk', '--okSoft', '--danger', '--dangerSoft', '--c1', '--c2', '--c3', '--c4',
    ])
  })

  it.each(coresDoDesign())('RT-1 %s = %s', (nome, valor) => {
    expect(raizTokens.get(nome)?.toUpperCase()).toBe(valor.toUpperCase())
  })

  it.each(Object.entries(esperadoRaiz))('RT-2 a RT-8 %s = %s', (nome, valor) => {
    expect(raizTokens.get(nome)).toBe(valor)
  })

  it.each(Object.entries(esperadoComputador))('computador %s = %s', (nome, valor) => {
    expect(computador.get(nome)).toBe(valor)
  })

  it('ponto de troca celular → computador em 840 px (PONTO A MUDAR: E25·3, recomendação A)', () => {
    expect(semComentarios(tokensCss)).toMatch(/@media \(min-width: 840px\)/)
  })
})

describe('CA-2 · nada solto fora do tokens.css (RT-9)', () => {
  const pastaUi = join(raiz, 'src/app/ui')
  const arquivosCss = [
    ...readdirSync(pastaUi).filter((f) => f.endsWith('.css')).map((f) => `src/app/ui/${f}`),
    'src/app/estilos/base.css',
    'src/app/estilos/app.css',
    'src/app/paginas/vitrine.css',
  ]
  const arquivosTsx = [
    ...readdirSync(pastaUi).filter((f) => f.endsWith('.tsx') && !f.endsWith('.test.tsx')).map((f) => `src/app/ui/${f}`),
    'src/app/paginas/vitrine.tsx',
    'src/app/paginas/vitrine-dados.ts',
  ]
  const proibidos: Array<[string, RegExp]> = [
    ['#', /#/],
    ['rgb(', /rgba?\(/],
    ['hsl(', /hsla?\(/],
    ['número com px, rem ou em', /\d(px|rem|em)\b/],
  ]

  it('há arquivos para varrer', () => {
    expect(arquivosCss.length).toBeGreaterThan(10)
    expect(arquivosTsx.length).toBeGreaterThan(10)
  })

  it.each(arquivosCss)('%s só usa var(--...)', (arquivo) => {
    const texto = semComentarios(ler(arquivo))
    for (const [nome, re] of proibidos) expect(re.test(texto), `${arquivo}: ${nome}`).toBe(false)
  })

  it.each(arquivosTsx)('%s sem cor, medida nem style={...}', (arquivo) => {
    const texto = ler(arquivo)
    for (const [nome, re] of proibidos) expect(re.test(texto), `${arquivo}: ${nome}`).toBe(false)
    expect(/style=\{/.test(texto), `${arquivo}: style={...}`).toBe(false)
  })

  it('o ponto de troca (@media com largura) só existe no tokens.css', () => {
    for (const arquivo of arquivosCss) {
      expect(/@media[^{]*width/.test(semComentarios(ler(arquivo))), arquivo).toBe(false)
    }
  })
})
