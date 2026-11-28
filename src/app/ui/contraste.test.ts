// RA-1 · contraste dos pares de tokens (spec §7; plan.md §7; ADR 0004 · D5).
// Fórmula da WCAG 2.2 (definições "relative luminance" e "contrast ratio"), escrita aqui; valores lidos do tokens.css.
// Desativado fica fora: a WCAG 1.4.3 isenta componente inativo.
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'

const css = readFileSync(join(import.meta.dirname, '..', 'estilos', 'tokens.css'), 'utf8').replace(/\/\*[\s\S]*?\*\//g, '')

type Rgba = { r: number; g: number; b: number; a: number }

function token(nome: string): Rgba {
  const m = new RegExp(`--${nome}\\s*:\\s*([^;]+);`).exec(css)
  const valor = m?.[1]?.trim()
  if (!valor) throw new Error(`token --${nome} não achado`)
  const hex = /^#([0-9a-f]{6})$/i.exec(valor)
  if (hex?.[1]) {
    const n = Number.parseInt(hex[1], 16)
    return { r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255, a: 1 }
  }
  const rgba = /^rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)$/.exec(valor)
  if (rgba) return { r: Number(rgba[1]), g: Number(rgba[2]), b: Number(rgba[3]), a: Number(rgba[4]) }
  throw new Error(`--${nome}: valor não é cor (${valor})`)
}

/** Cor com transparência composta sobre um fundo opaco */
function sobre(frente: Rgba, fundo: Rgba): Rgba {
  const mistura = (f: number, b: number) => f * frente.a + b * (1 - frente.a)
  return { r: mistura(frente.r, fundo.r), g: mistura(frente.g, fundo.g), b: mistura(frente.b, fundo.b), a: 1 }
}

function luminancia({ r, g, b }: Rgba): number {
  const canal = (c: number) => {
    const s = c / 255
    return s <= 0.04045 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4
  }
  return 0.2126 * canal(r) + 0.7152 * canal(g) + 0.0722 * canal(b)
}

function razao(a: Rgba, b: Rgba): number {
  const [claro, escuro] = [luminancia(a), luminancia(b)].sort((x, y) => y - x) as [number, number]
  return (claro + 0.05) / (escuro + 0.05)
}

const branco: Rgba = { r: 255, g: 255, b: 255, a: 1 }
const fundos = ['page', 'card', 'track'] as const
const textos = ['ink', 'ink2', 'ink3', 'okInk', 'danger', 'warn'] as const

describe('RA-1 · contraste (WCAG 2.2 AA)', () => {
  it('a fórmula confere com o valor conhecido: preto sobre branco = 21', () => {
    expect(razao({ r: 0, g: 0, b: 0, a: 1 }, branco)).toBeCloseTo(21, 5)
  })

  for (const texto of textos) {
    for (const fundo of fundos) {
      it(`texto --${texto} sobre --${fundo} ≥ 4,5:1`, () => {
        expect(razao(token(texto), token(fundo))).toBeGreaterThanOrEqual(4.5)
      })
    }
  }

  it('número --warnInk sobre --warnSoft ≥ 4,5:1 (pílula com pendência)', () => {
    expect(razao(token('warnInk'), token('warnSoft'))).toBeGreaterThanOrEqual(4.5)
  })

  for (const fundo of ['card', 'track'] as const) {
    it(`número --ink2 sobre --pillSoft composta em --${fundo} ≥ 4,5:1 (pílula cinza)`, () => {
      expect(razao(token('ink2'), sobre(token('pillSoft'), token(fundo)))).toBeGreaterThanOrEqual(4.5)
    })
  }

  for (const fundo of ['ink', 'brand'] as const) {
    it(`branco sobre --${fundo} ≥ 4,5:1`, () => {
      expect(razao(branco, token(fundo))).toBeGreaterThanOrEqual(4.5)
    })
  }

  it('contorno de campo --field sobre --card ≥ 3:1 (só sobre superfície branca, DESIGN.md §2)', () => {
    expect(razao(token('field'), token('card'))).toBeGreaterThanOrEqual(3)
  })

  for (const icone of ['ok', 'warn', 'danger', 'id'] as const) {
    it(`ícone --${icone} sobre --card ≥ 3:1 (WCAG 1.4.11)`, () => {
      expect(razao(token(icone), token('card'))).toBeGreaterThanOrEqual(3)
    })
  }

  it('ícone de erro --danger sobre --dangerSoft ≥ 3:1', () => {
    expect(razao(token('danger'), token('dangerSoft'))).toBeGreaterThanOrEqual(3)
  })

  for (const c of ['c1', 'c2', 'c3', 'c4'] as const) {
    it(`faixa de categoria --${c} sobre --card ≥ 3:1 (WCAG 1.4.11)`, () => {
      expect(razao(token(c), token('card'))).toBeGreaterThanOrEqual(3)
    })
  }
})
