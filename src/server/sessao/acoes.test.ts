// Fluxos de sessão (plan.md §3.1 a §3.4) com Auth e banco falsos; chaves do limite (D8).
import { describe, expect, it, vi } from 'vitest'
import type { Banco } from '@/data/cliente'
import { ErroDoBanco } from '@/data/erros'
import type { Conexao, ContextoDaSessao } from '@/data/sessao'
import { acoesDoCatalogo } from '../portas/catalogo'
import type { ContextoPessoa, ContextoSemSessao } from '../portas/tipos'
import { entradaDeEntrar, trabalhoDeEntrar } from './acoes'
import { chavesDaTentativa, normalizarEmail } from './tentativas'

const ORG_A = '11111111-2222-4333-8444-555555555555'
const ORG_B = '22222222-3333-4444-8555-666666666666'
const PESSOA = '0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d'
const PEDIDO = '6f1c2d3e-4a5b-4c6d-8e7f-8a9b0c1d2e3f'
const SEGREDO = 'segredo-ficticio-de-teste-com-32-caracteres'

const contexto = (mudar: Partial<ContextoDaSessao> = {}): ContextoDaSessao => ({
  usuarioId: PESSOA,
  orgId: null,
  papel: null,
  idioma: null,
  fuso: null,
  moeda: null,
  ...mudar,
})

function conexaoFalsa(mudar: Partial<Conexao> = {}) {
  const passos: string[] = []
  const anotar =
    <T,>(nome: string, valor: T) =>
    async (...args: unknown[]) => {
      passos.push(args.length ? `${nome}(${args.map(String).join(',')})` : nome)
      return valor
    }
  const conexao: Conexao = {
    quemE: vi.fn(anotar('quemE', { usuarioId: PESSOA, sessaoId: PEDIDO })),
    contexto: vi.fn(anotar('contexto', contexto())),
    registrarRecusa: vi.fn(anotar('registrarRecusa', undefined)),
    encerrarSessao: vi.fn(anotar('encerrarSessao', undefined)),
    sairLocal: vi.fn(anotar('sairLocal', undefined)),
    conferirTentativa: vi.fn(async () => {
      passos.push('conferirTentativa')
      return true
    }),
    entrarComSenha: vi.fn(async () => {
      passos.push('entrarComSenha')
      return { ok: true as const }
    }),
    registrarTentativaFalha: vi.fn(anotar('registrarTentativaFalha', undefined)),
    iniciarSessao: vi.fn(anotar('iniciarSessao', 1)),
    meusEstudios: vi.fn(anotar('meusEstudios', [{ orgId: ORG_A, nome: 'Estúdio Fictício A' }])),
    escolherEstudio: vi.fn(anotar('escolherEstudio', undefined)),
    banco: {} as Banco,
    iniciarTrabalho: vi.fn(),
    terminarTrabalho: vi.fn(),
    violou: false,
    saida: () => ({ cookies: [], cabecalhos: {} }),
    ...mudar,
  }
  return { conexao, passos }
}

const ctxEntrar = (conexao: Conexao, mudar: Partial<ContextoSemSessao> = {}): ContextoSemSessao => ({
  pedidoId: PEDIDO,
  temCookieDeSessao: false,
  ip: '203.0.113.7',
  segredoTentativas: SEGREDO,
  conexao,
  ...mudar,
})

const credenciais = { email: 'pessoa@exemplo.test', senha: 'senha-ficticia' }

const motivo = async (promessa: Promise<unknown>) => {
  try {
    await promessa
    return 'ok'
  } catch (erro) {
    return (erro as { codigo?: string }).codigo
  }
}

describe('sessao.entrar (plan.md §3.1)', () => {
  it('um estúdio: confere limite, entra, inicia a sessão e escolhe sozinho', async () => {
    const { conexao, passos } = conexaoFalsa()
    expect(await trabalhoDeEntrar(ctxEntrar(conexao), credenciais)).toEqual({ destino: 'inicio' })
    expect(passos).toEqual(['conferirTentativa', 'entrarComSenha', 'iniciarSessao', 'meusEstudios', `escolherEstudio(${ORG_A})`])
  })

  it('a senha chega igual, sem cortar (64 e 128 caracteres; CA-18a)', async () => {
    for (const tamanho of [64, 128]) {
      const senha = `${' '}${'é'.repeat(tamanho - 2)}${' '}`
      const lida = entradaDeEntrar.parse({ email: credenciais.email, senha })
      expect(lida.senha).toBe(senha)
      const { conexao } = conexaoFalsa()
      await trabalhoDeEntrar(ctxEntrar(conexao), lida)
      expect(conexao.entrarComSenha).toHaveBeenCalledWith(credenciais.email, senha)
    }
  })

  it('entrada estrita: campo a mais, vazio ou senha acima de 128 → recusada (ASVS V2.1.2)', () => {
    expect(entradaDeEntrar.safeParse({ ...credenciais, lembrar: true }).success).toBe(false)
    expect(entradaDeEntrar.safeParse({ email: '', senha: 'x' }).success).toBe(false)
    expect(entradaDeEntrar.safeParse({ email: 'a@b.c', senha: '' }).success).toBe(false)
    expect(entradaDeEntrar.safeParse({ email: 'a@b.c', senha: 'x'.repeat(129) }).success).toBe(false)
    expect(entradaDeEntrar.safeParse({ email: 'a@b.c', senha: 'x'.repeat(128) }).success).toBe(true)
  })

  it('com cookie de sessão: encerra a anterior antes (RF-05)', async () => {
    const { conexao, passos } = conexaoFalsa()
    await trabalhoDeEntrar(ctxEntrar(conexao, { temCookieDeSessao: true }), credenciais)
    expect(passos.slice(0, 4)).toEqual(['quemE', 'encerrarSessao', 'sairLocal', 'conferirTentativa'])
  })

  it('encerrar a anterior falhando: signOut local roda mesmo assim', async () => {
    const { conexao, passos } = conexaoFalsa({
      encerrarSessao: vi.fn(async () => {
        throw new ErroDoBanco('sem_login')
      }),
    })
    await trabalhoDeEntrar(ctxEntrar(conexao, { temCookieDeSessao: true }), credenciais)
    expect(passos).toContain('sairLocal')
  })

  it('limite passado → limite, sem ir ao Auth (CA-14)', async () => {
    const { conexao } = conexaoFalsa({ conferirTentativa: vi.fn(async () => false) })
    expect(await motivo(trabalhoDeEntrar(ctxEntrar(conexao), credenciais))).toBe('limite')
    expect(conexao.entrarComSenha).not.toHaveBeenCalled()
  })

  it('senha errada ou sem conta → sem_login e linha de falha (RF-24a)', async () => {
    const { conexao } = conexaoFalsa({ entrarComSenha: vi.fn(async () => ({ ok: false as const, codigo: 'sem_login' as const })) })
    expect(await motivo(trabalhoDeEntrar(ctxEntrar(conexao), credenciais))).toBe('sem_login')
    expect(conexao.registrarTentativaFalha).toHaveBeenCalledTimes(1)
    expect(conexao.iniciarSessao).not.toHaveBeenCalled()
  })

  it('limite do Auth → limite; falha de rede → erro_interno', async () => {
    const limite = conexaoFalsa({ entrarComSenha: vi.fn(async () => ({ ok: false as const, codigo: 'limite' as const })) })
    expect(await motivo(trabalhoDeEntrar(ctxEntrar(limite.conexao), credenciais))).toBe('limite')
    const rede = conexaoFalsa({ entrarComSenha: vi.fn(async () => ({ ok: false as const, codigo: 'erro_interno' as const })) })
    expect(await motivo(trabalhoDeEntrar(ctxEntrar(rede.conexao), credenciais))).toBe('erro_interno')
  })

  it('sem estúdio ativo → mesma resposta (sem_login), sessão encerrada e linha de falha (RF-11)', async () => {
    const { conexao, passos } = conexaoFalsa({
      iniciarSessao: vi.fn(async () => {
        passos.push('iniciarSessao')
        return 0
      }),
    })
    expect(await motivo(trabalhoDeEntrar(ctxEntrar(conexao), credenciais))).toBe('sem_login')
    expect(passos.slice(-3)).toEqual(['iniciarSessao', 'sairLocal', 'registrarTentativaFalha'])
  })

  it('iniciar_sessao recusa (session_id já visto, amr antigo) → sem_login, signOut e linha de falha (RF-24a, CA-09a)', async () => {
    const { conexao, passos } = conexaoFalsa({
      iniciarSessao: vi.fn(async () => {
        passos.push('iniciarSessao')
        throw new ErroDoBanco('sem_login')
      }),
    })
    expect(await motivo(trabalhoDeEntrar(ctxEntrar(conexao), credenciais))).toBe('sem_login')
    expect(passos.slice(-3)).toEqual(['iniciarSessao', 'sairLocal', 'registrarTentativaFalha'])
    expect(conexao.registrarTentativaFalha).toHaveBeenCalledTimes(1)
  })

  it('iniciar_sessao com erro do banco que não é sem_login → erro_interno, sem linha de falha', async () => {
    const { conexao } = conexaoFalsa({
      iniciarSessao: vi.fn(async () => {
        throw new ErroDoBanco('erro_interno')
      }),
    })
    expect(await motivo(trabalhoDeEntrar(ctxEntrar(conexao), credenciais))).toBe('erro_interno')
    expect(conexao.sairLocal).toHaveBeenCalled()
    expect(conexao.registrarTentativaFalha).not.toHaveBeenCalled()
  })

  it('mais de um estúdio, nenhum escolhido → Escolher estúdio', async () => {
    const { conexao } = conexaoFalsa({ iniciarSessao: vi.fn(async () => 2) })
    expect(await trabalhoDeEntrar(ctxEntrar(conexao), credenciais)).toEqual({ destino: 'escolher_estudio' })
    expect(conexao.escolherEstudio).not.toHaveBeenCalled()
  })

  it('mais de um estúdio, um já escolhido e ativo → segue nele', async () => {
    const { conexao } = conexaoFalsa({
      iniciarSessao: vi.fn(async () => 3),
      contexto: vi.fn(async () => contexto({ orgId: ORG_B, papel: 'dona' })),
    })
    expect(await trabalhoDeEntrar(ctxEntrar(conexao), credenciais)).toEqual({ destino: 'inicio' })
  })
})

const definicao = (nome: string) => {
  const def = acoesDoCatalogo().find((d) => d.nome === nome)
  if (!def) throw new Error(`sem ${nome}`)
  return def
}

const ctxPessoa = (conexao: Conexao): ContextoPessoa => ({
  pedidoId: PEDIDO,
  usuarioId: PESSOA,
  orgId: ORG_A,
  papel: 'dona',
  idioma: 'pt',
  conexao,
})

describe('sessao.sair (plan.md §3.4)', () => {
  it('marca a sessão e chama signOut local', async () => {
    const { conexao, passos } = conexaoFalsa()
    await definicao('sessao.sair').trabalho(ctxPessoa(conexao) as never, {})
    expect(passos).toEqual(['encerrarSessao', 'sairLocal'])
  })

  it('signOut local roda mesmo se a marcação falhar (D4)', async () => {
    const { conexao } = conexaoFalsa({
      encerrarSessao: vi.fn(async () => {
        throw new ErroDoBanco('erro_interno')
      }),
    })
    await definicao('sessao.sair').trabalho(ctxPessoa(conexao) as never, {})
    expect(conexao.sairLocal).toHaveBeenCalledTimes(1)
  })
})

describe('estudio.listar e estudio.escolher (plan.md §3.3)', () => {
  it('listar devolve os estúdios da pessoa', async () => {
    const { conexao } = conexaoFalsa()
    expect(await definicao('estudio.listar').trabalho(ctxPessoa(conexao) as never, {})).toEqual([
      { orgId: ORG_A, nome: 'Estúdio Fictício A' },
    ])
  })

  it('escolher passa o orgId; sem vínculo → o código do banco segue (CA-05)', async () => {
    const { conexao } = conexaoFalsa()
    await definicao('estudio.escolher').trabalho(ctxPessoa(conexao) as never, { orgId: ORG_B })
    expect(conexao.escolherEstudio).toHaveBeenCalledWith(ORG_B)

    const recusa = conexaoFalsa({
      escolherEstudio: vi.fn(async () => {
        throw new ErroDoBanco('sem_permissao')
      }),
    })
    expect(await motivo(definicao('estudio.escolher').trabalho(ctxPessoa(recusa.conexao) as never, { orgId: ORG_B }))).toBe(
      'sem_permissao',
    )
  })

  it('escolher só aceita uuid', () => {
    expect(definicao('estudio.escolher').entrada.safeParse({ orgId: 'B' }).success).toBe(false)
  })
})

describe('sessao.ler', () => {
  it('sem sessão: só o idioma do navegador', async () => {
    const { conexao } = conexaoFalsa()
    const lido = await definicao('sessao.ler').trabalho(
      { pedidoId: PEDIDO, idiomaDoNavegador: 'es', sessao: null, conexao } as never,
      {},
    )
    expect(lido).toEqual({ comSessao: false, comEstudio: false, idioma: 'es' })
  })

  it('com estúdio: idioma do estúdio (RF-35)', async () => {
    const { conexao } = conexaoFalsa()
    const lido = await definicao('sessao.ler').trabalho(
      { pedidoId: PEDIDO, idiomaDoNavegador: 'es', sessao: contexto({ orgId: ORG_A, papel: 'dona', idioma: 'en' }), conexao } as never,
      {},
    )
    expect(lido).toEqual({ comSessao: true, comEstudio: true, idioma: 'en' })
  })
})

describe('chaves do limite (D8)', () => {
  it('HMAC-SHA-256 em hexadecimal bytea; nem IP nem e-mail aparecem', async () => {
    const { chaveIp, chaveConta } = await chavesDaTentativa(SEGREDO, '203.0.113.7', 'Pessoa@Exemplo.test')
    for (const chave of [chaveIp, chaveConta]) {
      expect(chave).toMatch(/^\\x[0-9a-f]{64}$/)
      expect(chave).not.toContain('203.0.113.7')
      expect(chave.toLowerCase()).not.toContain('pessoa')
    }
    expect(chaveIp).not.toBe(chaveConta)
  })

  it('mesmo e-mail com maiúsculas e espaços → mesma chave da conta', async () => {
    const a = await chavesDaTentativa(SEGREDO, null, ' Pessoa@Exemplo.TEST ')
    const b = await chavesDaTentativa(SEGREDO, '198.51.100.1', 'pessoa@exemplo.test')
    expect(a.chaveConta).toBe(b.chaveConta)
    expect(a.chaveIp).not.toBe(b.chaveIp)
    expect(normalizarEmail(' A@B.C ')).toBe('a@b.c')
  })

  it('outro segredo → outra chave', async () => {
    const a = await chavesDaTentativa(SEGREDO, '203.0.113.7', 'pessoa@exemplo.test')
    const b = await chavesDaTentativa(`${SEGREDO}-outro`, '203.0.113.7', 'pessoa@exemplo.test')
    expect(a.chaveIp).not.toBe(b.chaveIp)
    expect(a.chaveConta).not.toBe(b.chaveConta)
  })
})
