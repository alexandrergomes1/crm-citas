import { describe, expect, expectTypeOf, it } from 'vitest'
import { CODIGOS_DO_BANCO, ErroDoBanco } from '@/data/erros'
import {
  CODIGOS_DE_ERRO,
  Recusa,
  codigoDoErro,
  ehCodigoDeErro,
  falha,
  sucesso,
  type CodigoDoBancoNaLista,
} from './erros'

describe('códigos de erro (RF-22)', () => {
  it('lista fechada, na ordem da spec', () => {
    expect(CODIGOS_DE_ERRO).toEqual([
      'sem_login',
      'estudio_trocado',
      'sem_estudio',
      'sem_permissao',
      'entrada_invalida',
      'conflito',
      'limite',
      'erro_interno',
    ])
  })

  it('todo código do banco está na lista', () => {
    for (const codigo of CODIGOS_DO_BANCO) expect(ehCodigoDeErro(codigo)).toBe(true)
    expectTypeOf<CodigoDoBancoNaLista>().toEqualTypeOf<true>()
  })

  it('resultado como valor, nunca exceção', () => {
    expect(sucesso(3)).toEqual({ ok: true, valor: 3 })
    expect(falha('limite')).toEqual({ ok: false, codigo: 'limite' })
  })
})

describe('codigoDoErro (CA-12)', () => {
  it('Recusa e ErroDoBanco mantêm o código', () => {
    expect(codigoDoErro(new Recusa('sem_permissao'))).toBe('sem_permissao')
    expect(codigoDoErro(new ErroDoBanco('conflito'))).toBe('conflito')
  })

  it('qualquer outra coisa → erro_interno', () => {
    expect(codigoDoErro(new Error('permission denied for table app.registro'))).toBe('erro_interno')
    expect(codigoDoErro('texto')).toBe('erro_interno')
    expect(codigoDoErro({ codigo: 'sem_login' })).toBe('erro_interno')
  })

  it('a mensagem de Recusa é só o código', () => {
    expect(new Recusa('limite').message).toBe('limite')
  })
})
