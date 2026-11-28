import { describe, expect, it } from 'vitest'
import { ErroDoBanco, codigoDe, codigoDoAuth, codigoDoPostgrest } from './erros'

describe('codigoDoPostgrest (CA-12)', () => {
  it('código da lista vindo do pré-pedido passa como está', () => {
    expect(codigoDoPostgrest({ code: 'sem_login', message: 'x' })).toBe('sem_login')
    expect(codigoDoPostgrest({ code: 'estudio_trocado' })).toBe('estudio_trocado')
    expect(codigoDoPostgrest({ code: 'sem_estudio' })).toBe('sem_estudio')
    expect(codigoDoPostgrest({ code: 'sem_permissao' })).toBe('sem_permissao')
    expect(codigoDoPostgrest({ code: 'erro_interno' })).toBe('erro_interno')
  })

  it('exclusão e chave única → conflito', () => {
    expect(codigoDoPostgrest({ code: '23P01' })).toBe('conflito')
    expect(codigoDoPostgrest({ code: '23505' })).toBe('conflito')
  })

  it('token recusado pelo PostgREST → sem_login', () => {
    expect(codigoDoPostgrest({ code: 'PGRST301' })).toBe('sem_login')
    expect(codigoDoPostgrest({ code: 'PGRST303' })).toBe('sem_login')
  })

  it('o resto → erro_interno, sem nada do texto', () => {
    const erro = { code: '42P01', message: 'relation "app.segredo" does not exist', details: 'Maria' }
    expect(codigoDoPostgrest(erro)).toBe('erro_interno')
    expect(codigoDoPostgrest(null)).toBe('erro_interno')
    expect(codigoDoPostgrest('texto')).toBe('erro_interno')
    expect(codigoDoPostgrest({ code: 'entrada_invalida' })).toBe('erro_interno')
  })
})

describe('codigoDoAuth', () => {
  it('senha errada, conta inexistente e bloqueada dão o mesmo código (RF-02)', () => {
    expect(codigoDoAuth({ code: 'invalid_credentials', status: 400 })).toBe('sem_login')
    expect(codigoDoAuth({ code: 'user_not_found', status: 404 })).toBe('sem_login')
    expect(codigoDoAuth({ code: 'user_banned', status: 400 })).toBe('sem_login')
    expect(codigoDoAuth({ code: 'email_not_confirmed', status: 400 })).toBe('sem_login')
  })

  it('limite do Auth → limite', () => {
    expect(codigoDoAuth({ code: 'over_request_rate_limit', status: 429 })).toBe('limite')
    expect(codigoDoAuth({ status: 429 })).toBe('limite')
  })

  it('sessão do Auth acabada → sem_login', () => {
    expect(codigoDoAuth({ code: 'session_not_found', status: 403 })).toBe('sem_login')
    expect(codigoDoAuth({ code: 'refresh_token_already_used', status: 400 })).toBe('sem_login')
  })

  it('falha de rede ou desconhecida → erro_interno', () => {
    expect(codigoDoAuth(new TypeError('fetch failed'))).toBe('erro_interno')
    expect(codigoDoAuth({ status: 500 })).toBe('erro_interno')
    expect(codigoDoAuth(undefined)).toBe('erro_interno')
  })
})

describe('ErroDoBanco', () => {
  it('a mensagem é só o código', () => {
    const erro = new ErroDoBanco('conflito')
    expect(erro.message).toBe('conflito')
    expect(codigoDe(erro)).toBe('conflito')
  })

  it('qualquer outra coisa → erro_interno', () => {
    expect(codigoDe(new Error('duplicate key value violates unique constraint'))).toBe('erro_interno')
  })
})
