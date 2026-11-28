import { describe, expect, it } from 'vitest'
import { idiomaDoNavegador, idiomaValido } from './idioma'

describe('idiomaDoNavegador (Accept-Language)', () => {
  it('sem cabeçalho → pt', () => {
    expect(idiomaDoNavegador(undefined)).toBe('pt')
    expect(idiomaDoNavegador(null)).toBe('pt')
    expect(idiomaDoNavegador('')).toBe('pt')
  })

  it('aceita variante regional', () => {
    expect(idiomaDoNavegador('es-ES')).toBe('es')
    expect(idiomaDoNavegador('en-GB,en;q=0.9')).toBe('en')
    expect(idiomaDoNavegador('PT-br')).toBe('pt')
  })

  it('segue o peso q', () => {
    expect(idiomaDoNavegador('pt;q=0.5, es;q=0.8, en;q=0.1')).toBe('es')
  })

  it('empate mantém a ordem do cabeçalho', () => {
    expect(idiomaDoNavegador('en, es')).toBe('en')
  })

  it('pula idiomas fora da lista', () => {
    expect(idiomaDoNavegador('fr-FR, de;q=0.9, es;q=0.5')).toBe('es')
  })

  it('q=0 recusa; q inválido também', () => {
    expect(idiomaDoNavegador('es;q=0, en;q=abc')).toBe('pt')
  })

  it('só idiomas fora da lista → pt', () => {
    expect(idiomaDoNavegador('fr, de, *')).toBe('pt')
  })

  it('cabeçalho grande demais é ignorado', () => {
    expect(idiomaDoNavegador(`es,${'x'.repeat(600)}`)).toBe('pt')
  })
})

describe('idiomaValido (estudios.idioma)', () => {
  it('aceita os três', () => {
    expect(idiomaValido('es')).toBe('es')
    expect(idiomaValido('en')).toBe('en')
  })

  it('o resto vira pt', () => {
    expect(idiomaValido('fr')).toBe('pt')
    expect(idiomaValido(null)).toBe('pt')
    expect(idiomaValido(3)).toBe('pt')
  })
})
