// Sua conta (spec RF-14, RF-30; ficha E41; DESIGN.md §8b). renderToString, sem jsdom.
import { renderToString } from 'react-dom/server'
import { describe, expect, it } from 'vitest'
import { textosDe } from '@/app/i18n/textos'
import { BarraSuaConta, itensDaConta } from './sua-conta'

const nada = () => {}
const t = textosDe('pt')

describe('Itens de Sua conta (DESIGN.md §8b)', () => {
  it('com mais de uma empresa: a ordem do §8b, com "Trocar de empresa"', () => {
    expect(itensDaConta(t, 2).map((i) => i.rotulo)).toEqual([
      'Minha conta',
      'Preferências',
      'Meu faturamento',
      'Trocar de empresa',
      'Sair',
    ])
  })

  it('com uma empresa só: sem "Trocar de empresa"', () => {
    expect(itensDaConta(t, 1).map((i) => i.id)).toEqual(['minhaConta', 'preferencias', 'meuFaturamento', 'sair'])
  })

  it('só Trocar de empresa e Sair funcionam; o resto está em desenvolvimento', () => {
    expect(itensDaConta(t, 2).filter((i) => !i.emDesenvolvimento).map((i) => i.id)).toEqual(['trocarDeEstudio', 'sair'])
  })
})

describe('Menu Sua conta (computador)', () => {
  const html = renderToString(
    <BarraSuaConta textos={t} inicial="P" quantosEstudios={2} onTrocar={nada} onSair={nada} abertoInicial="menu" />,
  )

  it('a bolinha com a inicial e o nome "Sua conta"', () => {
    expect(html).toContain('aria-label="Sua conta"')
    expect(html).toMatch(/class="ds-bolinha"[^>]*>P</)
  })

  it('itens em desenvolvimento com aria-disabled e a nota', () => {
    expect(html.match(/role="menuitem"/g)?.length).toBeGreaterThanOrEqual(5)
    expect(html.match(/aria-disabled="true"/g)?.length).toBe(6) // 3 no menu + 3 na folha
    expect(html.match(/em desenvolvimento/g)?.length).toBe(6)
  })

  it('o menu aberto não está escondido', () => {
    expect(html).toMatch(/role="menu"[^>]*class="ds-menu__lista ds-menu__lista--fim"(?![^>]*hidden)/)
  })
})

describe('Sua conta · idiomas (CA-20)', () => {
  it.each(['es', 'en'] as const)('em %s', (idioma) => {
    const tt = textosDe(idioma)
    const html = renderToString(<BarraSuaConta textos={tt} inicial="P" quantosEstudios={2} onTrocar={nada} onSair={nada} />)
    expect(html).toContain(`aria-label="${tt.suaConta.nome}"`)
    expect(html).toContain(`>${tt.suaConta.trocarDeEstudio}<`)
  })
})
