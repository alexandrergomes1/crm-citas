// Tela Escolher estúdio (spec RF-11 a RF-14, RF-33, CA-20; ficha E41·4·A). renderToString, sem jsdom.
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join } from 'node:path'
import { renderToString } from 'react-dom/server'
import { describe, expect, it } from 'vitest'
import { textosDe } from '@/app/i18n/textos'
import { EscolherEstudioVista, type EstadoEscolher } from './escolher-estudio'

const nada = () => {}
const estudios = [
  { orgId: '00000000-0000-4000-8000-000000000001', nome: 'Estúdio Aurora' },
  { orgId: '00000000-0000-4000-8000-000000000002', nome: 'Estúdio Lírio' },
]
const vista = (estado: EstadoEscolher, idioma: 'pt' | 'es' | 'en' = 'pt') =>
  renderToString(
    <EscolherEstudioVista textos={textosDe(idioma)} idioma={idioma} estado={estado} onEscolher={nada} onTentar={nada} onSair={nada} />,
  )

describe('Escolher estúdio · lista', () => {
  const html = vista({ tipo: 'lista', estudios })

  it('título, contador no subtítulo e "Sair" claro, sem botão preto (DESIGN.md §8b)', () => {
    expect(html).toContain('>Escolher estúdio</h1>')
    expect(html).toContain('>2 estúdios<')
    expect(html).not.toContain('ds-botao--principal')
    expect(html).toMatch(/ds-botao--claro[^>]*>.*Sair/)
  })

  it('cada linha é um botão com o nome do estúdio; quadrado e › são enfeite', () => {
    expect(html.match(/<button type="button" class="ds-linha escolher__linha"/g)).toHaveLength(2)
    expect(html).toContain('<span aria-hidden="true" class="escolher__enfeite">')
    expect(html).toContain('>Estúdio Aurora<')
    expect(html).toContain('>Estúdio Lírio<')
  })

  it('o identificador do estúdio não aparece na página (RF-33)', () => {
    for (const { orgId } of estudios) expect(html).not.toContain(orgId)
  })

  it('um estúdio: "1 estúdio"', () => {
    expect(vista({ tipo: 'lista', estudios: estudios.slice(0, 1) })).toContain('>1 estúdio<')
  })
})

describe('Escolher estúdio · carregando e erro', () => {
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

describe('Escolher estúdio · idiomas (CA-20)', () => {
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
