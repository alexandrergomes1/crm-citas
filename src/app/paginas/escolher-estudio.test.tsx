// Tela Escolher empresa (spec RF-11 a RF-14, RF-33, CA-20; ficha E41·4·A). renderToString, sem jsdom.
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join } from 'node:path'
import { renderToString } from 'react-dom/server'
import { describe, expect, it } from 'vitest'
import { textosDe } from '@/app/i18n/textos'
import { EscolherEstudioVista, inicialDe, type EstadoEscolher } from './escolher-estudio'

const nada = () => {}
const estudios = [
  { orgId: '00000000-0000-4000-8000-000000000001', nome: 'Estúdio Aurora' },
  { orgId: '00000000-0000-4000-8000-000000000002', nome: 'Clínica Lírio' },
]
const vista = (estado: EstadoEscolher, idioma: 'pt' | 'es' | 'en' = 'pt') =>
  renderToString(
    <EscolherEstudioVista textos={textosDe(idioma)} idioma={idioma} estado={estado} onEscolher={nada} onTentar={nada} onSair={nada} />,
  )

describe('Escolher empresa · lista', () => {
  const html = vista({ tipo: 'lista', estudios })

  it('título, contador no subtítulo e "Sair" claro, sem botão preto (DESIGN.md §8b)', () => {
    expect(html).toContain('>Escolher empresa</h1>')
    expect(html).toContain('>2 empresas<')
    expect(html).not.toContain('ds-botao--principal')
    expect(html).toMatch(/ds-botao--claro[^>]*>.*Sair/)
  })

  it('cada linha é um botão com o nome da empresa; quadrado e › são enfeite', () => {
    expect(html.match(/<button type="button" class="ds-linha escolher__linha"/g)).toHaveLength(2)
    expect(html).toContain('<span aria-hidden="true" class="escolher__enfeite">')
    expect(html).toContain('>Estúdio Aurora<')
    expect(html).toContain('>Clínica Lírio<')
  })

  it('o identificador da empresa não aparece na página (RF-33)', () => {
    for (const { orgId } of estudios) expect(html).not.toContain(orgId)
  })

  it('uma empresa: "1 empresa"', () => {
    expect(vista({ tipo: 'lista', estudios: estudios.slice(0, 1) })).toContain('>1 empresa<')
  })

  it('o quadrado mostra a letra do nome próprio, não a da palavra genérica (E47·1·A)', () => {
    expect(html).toMatch(/aria-label="Estúdio Aurora"><span aria-hidden="true">A<\/span>/)
    expect(html).toMatch(/aria-label="Clínica Lírio"><span aria-hidden="true">L<\/span>/)
  })
})

describe('Letra do quadrado da empresa (DESIGN.md §8b; E47·1·A)', () => {
  it.each([
    // exemplos do DESIGN.md §8b
    ['Estúdio Aurora', 'A'],
    ['Clínica Lírio', 'L'],
    ['Salão Bela', 'B'],
    ['Studio da Ana', 'A'],
    ['Spa', 'S'],
    ['Bela Pele', 'B'],
    // passo 1: sem diferença de maiúscula e acento; todas as genéricas da lista
    ['ESTUDIO aurora', 'A'],
    ['estúdio Órbita', 'Ó'],
    ['Salón Rosa', 'R'],
    ['Barbería Toro', 'T'],
    ['Barbearia Navalha', 'N'],
    ['Barbershop Kings', 'K'],
    ['Espaço Zen', 'Z'],
    ['Espacio Luz', 'L'],
    ['Centro Vida', 'V'],
    ['Center Glow', 'G'],
    ['Centre Belle', 'B'],
    ['Instituto Pele', 'P'],
    ['Institute Skin', 'S'],
    ['Ateliê Unha', 'U'],
    ['Atelier Marie', 'M'],
    ['Clinic Derma', 'D'],
    ['Salon Iris', 'I'],
    // pula só a primeira palavra, uma vez
    ['Estúdio Clínica Lírio', 'C'],
    ['Spa Spa', 'S'],
    // genérica fora do começo não é pulada
    ['Aurora Estúdio', 'A'],
    // passo 2: ligações depois da genérica, uma ou mais
    ['Clínica do Lírio', 'L'],
    ['Studio of the Sun', 'S'],
    ['Centro de la Belleza', 'B'],
    ['Salón del Mar', 'M'],
    ['Espaço das Flores', 'F'],
    ['Instituto dos Olhos', 'O'],
    ['Studio el Toro', 'T'],
    // ligação no começo, sem genérica antes: não é pulada
    ['Da Vinci Estética', 'D'],
    // passo 3: letra ou número, como está escrito, em maiúscula
    ['Estúdio 24 Horas', '2'],
    ['Estúdio "Íris"', 'Í'],
    ['Espaço éclat', 'É'],
    ['Estúdio Aná', 'A'],
    ['Studio Élan', 'É'],
    ['  Estúdio   Aurora  ', 'A'],
    // passo 4: nada sobra → a primeira letra da palavra pulada; sem letra nem número → o primeiro caractere
    ['Estúdio', 'E'],
    ['Clínica da', 'C'],
    ['Estúdio ★', 'E'],
    ['★★', '★'],
    ['', ''],
    ['   ', ''],
    // dedução do código: a palavra seguinte sem letra passa à próxima
    ['Estúdio & Bela', 'B'],
  ])('%j → %j', (nome, letra) => {
    expect(inicialDe(nome)).toBe(letra)
  })
})

describe('Escolher empresa · carregando e erro', () => {
  it('carregando é anunciado (role="status")', () => {
    expect(vista({ tipo: 'carregando' })).toContain('role="status"')
  })

  it('erro: só o título e "Tentar de novo", com "Sair" embaixo', () => {
    const html = vista({ tipo: 'erro' })
    expect(html).toContain('Não foi possível carregar')
    expect(html).toContain('Tentar de novo')
    expect(html.indexOf('Tentar de novo')).toBeLessThan(html.lastIndexOf('Sair'))
  })

  it('erro: nenhum parágrafo vazio nem frase de detalhe (ficha, ressalvas da 2ª rodada)', () => {
    const html = vista({ tipo: 'erro' })
    expect(html).not.toMatch(/<p[^>]*>\s*<\/p>/)
    expect(html).not.toContain('ds-estado__frase')
    expect(html).toContain('<p class="ds-estado__titulo" role="alert">Não foi possível carregar</p>')
    expect(html).toContain('ds-estado__icone--erro')
  })

  it('erro anunciado ao leitor de tela, uma vez só (WCAG 4.1.3; revisão de design R4)', () => {
    const html = vista({ tipo: 'erro' })
    expect(html.match(/role="alert"/g)).toHaveLength(1)
    expect(vista({ tipo: 'lista', estudios })).not.toContain('role="alert"')
  })

  it('o título recebe foco por programa, fora da ordem do Tab (WCAG 2.4.3; revisão de design R4)', () => {
    expect(vista({ tipo: 'carregando' })).toMatch(/<h1 class="tela-sem-menu__titulo" tabindex="-1">/i)
  })
})

describe('Escolher empresa · idiomas (CA-20)', () => {
  it.each(['es', 'en'] as const)('em %s', (idioma) => {
    const t = textosDe(idioma)
    const html = vista({ tipo: 'lista', estudios }, idioma)
    expect(html).toContain(`>${t.escolherEstudio.titulo}</h1>`)
    expect(html).toContain(`>${t.comum.sair}<`)
  })
})

describe('Nenhuma consulta automática renova a sessão (ADR 0018 · D5; plan.md §3.4)', () => {
  const raiz = join(import.meta.dirname, '..')
  const arquivos = (pasta: string): string[] =>
    readdirSync(pasta).flatMap((nome) => {
      const caminho = join(pasta, nome)
      if (statSync(caminho).isDirectory()) return arquivos(caminho)
      return /\.(ts|tsx)$/.test(nome) && !/\.test\.tsx?$/.test(nome) && nome !== 'routeTree.gen.ts' ? [caminho] : []
    })
  const proibidos = [
    /setInterval\s*\(/,
    /refetchInterval/,
    /refetchOnWindowFocus/,
    /refetchOnReconnect/,
    /addEventListener\(\s*['"](focus|visibilitychange|online)['"]/,
    /defaultPreload|preload=/,
  ]

  it.each(arquivos(raiz).map((a) => [a.slice(raiz.length + 1), a]))('%s', (_nome, caminho) => {
    const texto = readFileSync(caminho, 'utf8')
    for (const re of proibidos) expect(re.test(texto), `${caminho}: ${re}`).toBe(false)
  })
})
