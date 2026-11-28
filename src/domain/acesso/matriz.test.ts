// Catálogo e matriz de permissões (ADR 0020 · D2 a D4, D7, D8; spec RF-18; plan.md §5a).
// Catálogo e matriz fictícios para os casos (o do sistema nasce vazio nesta spec); depois, o do sistema.
import { describe, expect, it } from 'vitest'
import { CHAVES, MODULOS, chavesDe, ehChave, ehChaveDe, moduloDaChave, type Chave, type ChaveDe } from './chaves'
import {
  MATRIZ_PADRAO,
  PAPEIS,
  alcanceNaMatriz,
  alcancePadrao,
  conferirMatriz,
  exportarMatriz,
  exportarMatrizDe,
  type LinhaDaMatriz,
} from './matriz'

const FICTICIO = {
  agenda: ['ver', 'criar'],
  formularios: ['ver', 'ver_saude'],
} as const
type ChaveFicticia = ChaveDe<typeof FICTICIO>

const MATRIZ: readonly LinhaDaMatriz<ChaveFicticia>[] = [
  { papel: 'recepcao', chave: 'agenda.ver', alcance: 'todos' },
  { papel: 'profissional', chave: 'agenda.ver', alcance: 'proprios' },
  { papel: 'profissional', chave: 'formularios.ver_saude', alcance: 'proprios' },
]

const alcance = (papel: unknown, chave: unknown) => alcanceNaMatriz(FICTICIO, MATRIZ, papel, chave)

describe('catálogo de chaves (ADR 0020 · D1, D2)', () => {
  it('chaves são modulo.acao, em ordem alfabética', () => {
    expect(chavesDe(FICTICIO)).toEqual(['agenda.criar', 'agenda.ver', 'formularios.ver', 'formularios.ver_saude'])
  })

  it('texto fora do catálogo não é chave', () => {
    expect(ehChaveDe(FICTICIO, 'agenda.ver')).toBe(true)
    for (const fora of ['agenda.remover', 'caixa.ver', 'agenda', '', 'AGENDA.VER', null, 1, {}]) {
      expect(ehChaveDe(FICTICIO, fora)).toBe(false)
    }
  })

  it('módulo da chave é o trecho antes do primeiro ponto', () => {
    expect(moduloDaChave('agenda.ver')).toBe('agenda')
    expect(moduloDaChave('formularios.ver_saude')).toBe('formularios')
    expect(moduloDaChave('semponto')).toBeNull()
    expect(moduloDaChave('.ver')).toBeNull()
  })

  it('chave fora do catálogo não compila', () => {
    // @ts-expect-error — 'agenda.ver' não está no catálogo do sistema nesta spec
    const errada: Chave = 'agenda.ver'
    expect(ehChave(errada)).toBe(false)
  })
})

describe('matriz · alcance (ADR 0020 · D3, D4)', () => {
  it('dona tem tudo: todos em toda chave do catálogo, sem linha', () => {
    for (const chave of chavesDe(FICTICIO)) expect(alcance('dona', chave)).toBe('todos')
    expect(MATRIZ.some(({ papel }) => (papel as string) === 'dona')).toBe(false)
  })

  it('ausente = não pode', () => {
    expect(alcance('recepcao', 'agenda.criar')).toBeNull()
    expect(alcance('recepcao', 'formularios.ver_saude')).toBeNull()
    expect(alcance('profissional', 'formularios.ver')).toBeNull()
  })

  it('alcance todos e proprios saem como estão na linha', () => {
    expect(alcance('recepcao', 'agenda.ver')).toBe('todos')
    expect(alcance('profissional', 'agenda.ver')).toBe('proprios')
    expect(alcance('profissional', 'formularios.ver_saude')).toBe('proprios')
  })

  it('chave fora do catálogo = não pode, mesmo para a dona (falha fechada)', () => {
    for (const papel of PAPEIS) {
      expect(alcance(papel, 'caixa.ver')).toBeNull()
      expect(alcance(papel, 'agenda.remover')).toBeNull()
      expect(alcance(papel, undefined)).toBeNull()
    }
  })

  it('papel desconhecido ou vazio = não pode', () => {
    for (const papel of ['Dona', 'admin', '', null, undefined]) expect(alcance(papel, 'agenda.ver')).toBeNull()
  })

  it('linha com alcance desconhecido = não pode', () => {
    const torta = [{ papel: 'recepcao', chave: 'agenda.ver', alcance: 'sim' }] as unknown as LinhaDaMatriz<ChaveFicticia>[]
    expect(alcanceNaMatriz(FICTICIO, torta, 'recepcao', 'agenda.ver')).toBeNull()
  })
})

describe('conferência da matriz (ADR 0020 · D4, D8)', () => {
  it('matriz em ordem: sem motivo', () => {
    expect(conferirMatriz(FICTICIO, MATRIZ)).toEqual([])
  })

  it('linha da dona, chave fora do catálogo, alcance desconhecido e repetida são apontadas', () => {
    const torta = [
      { papel: 'dona', chave: 'agenda.ver', alcance: 'todos' },
      { papel: 'recepcao', chave: 'caixa.ver', alcance: 'todos' },
      { papel: 'recepcao', chave: 'agenda.criar', alcance: 'sim' },
      { papel: 'profissional', chave: 'agenda.ver', alcance: 'proprios' },
      { papel: 'profissional', chave: 'agenda.ver', alcance: 'todos' },
    ] as unknown as LinhaDaMatriz<ChaveFicticia>[]
    expect(conferirMatriz(FICTICIO, torta)).toHaveLength(4)
  })
})

describe('exportação para o banco (ADR 0020 · D7, D8)', () => {
  it('chaves e linhas em ordem estável, só dados', () => {
    const embaralhada = [MATRIZ[2]!, MATRIZ[0]!, MATRIZ[1]!]
    const exportada = exportarMatrizDe(FICTICIO, embaralhada)
    expect(exportada).toEqual({
      chaves: ['agenda.criar', 'agenda.ver', 'formularios.ver', 'formularios.ver_saude'],
      linhas: [
        { papel: 'profissional', chave: 'agenda.ver', alcance: 'proprios' },
        { papel: 'profissional', chave: 'formularios.ver_saude', alcance: 'proprios' },
        { papel: 'recepcao', chave: 'agenda.ver', alcance: 'todos' },
      ],
    })
    expect(JSON.parse(JSON.stringify(exportada))).toEqual(exportada)
  })
})

describe('catálogo e matriz do sistema', () => {
  it('toda linha usa chave do catálogo, nenhuma é da dona, nenhuma repetida', () => {
    expect(conferirMatriz(MODULOS, MATRIZ_PADRAO)).toEqual([])
  })

  it('nesta spec: catálogo e matriz vazios de módulo (ADR 0020, "Custo")', () => {
    expect(CHAVES).toEqual([])
    expect(exportarMatriz()).toEqual({ chaves: [], linhas: [] })
  })

  it('a dona tem todos em toda chave do sistema; ninguém tem fora dele', () => {
    for (const chave of CHAVES) expect(alcancePadrao('dona', chave)).toBe('todos')
    expect(alcancePadrao('dona', 'agenda.ver' as Chave)).toBeNull()
  })
})
