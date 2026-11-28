// Ordem das portas e corte na primeira recusa (CA-07), entrada fora do esquema (CA-08), erros só por código (CA-12),
// com Auth e banco falsos (plan.md §9).
import { describe, expect, it, vi } from 'vitest'
import { z } from 'zod'
import type { Banco } from '@/data/cliente'
import { ErroDoBanco } from '@/data/erros'
import type { Conexao, ContextoDaSessao } from '@/data/sessao'
import { alcanceNaMatriz, type LinhaDaMatriz } from '@/domain/acesso/matriz'
import type { ChaveDe } from '@/domain/acesso/chaves'
import { Recusa } from './erros'
import { TEMPO_MINIMO_SEM_SESSAO_MS, executar } from './executar'
import type { Chave, DefinicaoDeAcao, FonteDeAlcance, Infra, Modo, PedidoHttp } from './tipos'

const ORG_A = '11111111-2222-4333-8444-555555555555'
const PESSOA = '0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d'
const PEDIDO = '6f1c2d3e-4a5b-4c6d-8e7f-8a9b0c1d2e3f'

// Catálogo e matriz fictícios da porta 3 (o do sistema nasce vazio nesta spec; ADR 0020).
const CATALOGO_TESTE = { teste: ['ver', 'criar'] } as const
const MATRIZ_TESTE: readonly LinhaDaMatriz<ChaveDe<typeof CATALOGO_TESTE>>[] = [
  { papel: 'recepcao', chave: 'teste.criar', alcance: 'todos' },
  { papel: 'profissional', chave: 'teste.ver', alcance: 'proprios' },
]
const fonteDeTeste: FonteDeAlcance = (sessao, chave) =>
  alcanceNaMatriz(CATALOGO_TESTE, MATRIZ_TESTE, sessao.papel, chave)
/** Chave do catálogo fictício (fora do tipo `Chave` do sistema, que está vazio). */
const chave = (texto: string) => texto as unknown as Chave

const contextoA: ContextoDaSessao = {
  usuarioId: PESSOA,
  orgId: ORG_A,
  papel: 'recepcao',
  idioma: 'es',
  fuso: 'Europe/Madrid',
  moeda: 'EUR',
}

type Falsos = {
  claims?: boolean
  contexto?: ContextoDaSessao | ErroDoBanco
  violou?: boolean
}

/** Conexão falsa que anota cada passo, para provar a ordem. */
function conexaoFalsa(falsos: Falsos = {}) {
  const passos: string[] = []
  let violou = false
  const conexao: Conexao = {
    quemE: vi.fn(async () => {
      passos.push('quemE')
      return falsos.claims === false ? null : { usuarioId: PESSOA, sessaoId: PEDIDO }
    }),
    contexto: vi.fn(async () => {
      passos.push('contexto')
      const c = falsos.contexto ?? contextoA
      if (c instanceof ErroDoBanco) throw c
      return c
    }),
    registrarRecusa: vi.fn(async (acao: string, codigo: string) => {
      passos.push(`recusa:${acao}:${codigo}`)
    }),
    encerrarSessao: vi.fn(async () => {
      passos.push('encerrar')
    }),
    sairLocal: vi.fn(async () => {
      passos.push('sairLocal')
    }),
    conferirTentativa: vi.fn(async () => true),
    entrarComSenha: vi.fn(async () => ({ ok: true as const })),
    registrarTentativaFalha: vi.fn(async () => {}),
    iniciarSessao: vi.fn(async () => 1),
    meusEstudios: vi.fn(async () => []),
    escolherEstudio: vi.fn(async () => {}),
    banco: {} as Banco,
    iniciarTrabalho: vi.fn((grava: boolean) => {
      passos.push(`iniciarTrabalho:${grava}`)
      if (falsos.violou) violou = true
    }),
    terminarTrabalho: vi.fn(() => {
      passos.push('terminarTrabalho')
    }),
    get violou() {
      return violou
    },
    saida: () => ({ cookies: [], cabecalhos: {} }),
  }
  return { conexao, passos }
}

function infraFalsa(conexao: Conexao, ambiente = true, alcanceDe: FonteDeAlcance | null = fonteDeTeste) {
  let relogio = 1_000
  const infra: Infra = {
    ambiente: () =>
      ambiente
        ? {
            supabaseUrl: 'http://127.0.0.1:54321',
            chavePublica: 'sb_publishable_ficticia',
            segredoTentativas: 's'.repeat(32),
            chaveServidor: 'c'.repeat(32),
          }
        : null,
    abrirConexao: vi.fn(() => conexao),
    agora: () => relogio,
    esperar: vi.fn(async (ms: number) => {
      relogio += ms
    }),
    novoPedidoId: () => PEDIDO,
    ...(alcanceDe ? { alcanceDe: vi.fn(alcanceDe) } : {}),
  }
  return infra
}

const pedido = (corpo: unknown, metodo = 'POST'): PedidoHttp => ({
  metodo,
  corpo,
  cookies: [],
  cabecalho: (nome) => (nome === 'accept-language' ? 'en' : null),
  ip: '203.0.113.7',
})

function definicao<M extends Modo = 'estudio'>(
  mudar: Partial<DefinicaoDeAcao<z.ZodType, unknown, M>> = {},
  passos: string[] = [],
): DefinicaoDeAcao<z.ZodType, unknown, M> {
  return {
    nome: 'teste.criar',
    metodo: 'POST',
    sessao: 'estudio' as M,
    permissao: chave('teste.criar'),
    entrada: z.strictObject({ titulo: z.string().min(1).max(10) }),
    grava: true,
    trabalho: vi.fn(async (_ctx: unknown, dados: unknown) => {
      passos.push('trabalho')
      return { recebido: dados }
    }),
    ...mudar,
  } as DefinicaoDeAcao<z.ZodType, unknown, M>
}

const corpoCerto = { estudioDaTela: ORG_A, dados: { titulo: 'ok' } }

describe('executar · modo estudio · ordem das portas (CA-07)', () => {
  it('tudo certo: quemE → contexto → trabalho, com ctx da sessão', async () => {
    const { conexao, passos } = conexaoFalsa()
    const def = definicao({}, passos)
    const infra = infraFalsa(conexao)
    const resposta = await executar(def, pedido(corpoCerto), infra)

    expect(resposta.resultado).toEqual({ ok: true, valor: { recebido: { titulo: 'ok' } } })
    expect(passos).toEqual(['quemE', 'contexto', 'iniciarTrabalho:true', 'trabalho', 'terminarTrabalho'])
    expect(infra.abrirConexao).toHaveBeenCalledWith(
      expect.objectContaining({
        cabecalhos: { pedidoId: PEDIDO, acao: 'teste.criar', estudioEsperado: ORG_A },
      }),
    )
    const [ctx] = vi.mocked(def.trabalho).mock.calls[0]!
    expect(ctx).toMatchObject({ pedidoId: PEDIDO, usuarioId: PESSOA, orgId: ORG_A, alcance: 'todos', idioma: 'es' })
    expect(infra.alcanceDe).toHaveBeenCalledWith(contextoA, 'teste.criar')
  })

  it('porta 1: sem token → sem_login, nada no banco e nada registrado (RF-28)', async () => {
    const { conexao, passos } = conexaoFalsa({ claims: false })
    const def = definicao({}, passos)
    const resposta = await executar(def, pedido(corpoCerto), infraFalsa(conexao))
    expect(resposta.resultado).toEqual({ ok: false, codigo: 'sem_login' })
    expect(passos).toEqual(['quemE'])
  })

  it('envelope sem estudioDaTela → entrada_invalida antes do contexto', async () => {
    const { conexao, passos } = conexaoFalsa()
    const def = definicao({}, passos)
    const resposta = await executar(def, pedido({ dados: { titulo: 'ok' } }), infraFalsa(conexao))
    expect(resposta.resultado).toEqual({ ok: false, codigo: 'entrada_invalida' })
    expect(passos).toEqual(['quemE', 'recusa:teste.criar:entrada_invalida'])
  })

  it('envelope com campo a mais → entrada_invalida', async () => {
    const { conexao, passos } = conexaoFalsa()
    const resposta = await executar(
      definicao({}, passos),
      pedido({ ...corpoCerto, orgId: ORG_A }),
      infraFalsa(conexao),
    )
    expect(resposta.resultado).toEqual({ ok: false, codigo: 'entrada_invalida' })
    expect(passos).not.toContain('trabalho')
  })

  it('sessão morta, vencida ou parada → sem_login, encerra no navegador, sem linha de recusa', async () => {
    const { conexao, passos } = conexaoFalsa({ contexto: new ErroDoBanco('sem_login') })
    const resposta = await executar(definicao({}, passos), pedido(corpoCerto), infraFalsa(conexao))
    expect(resposta.resultado).toEqual({ ok: false, codigo: 'sem_login' })
    expect(passos).toEqual(['quemE', 'contexto', 'encerrar', 'sairLocal'])
  })

  it('sessão vencida: encerrarSessao falha → ainda sem_login e signOut local (plan.md §3.4)', async () => {
    const { conexao, passos } = conexaoFalsa({ contexto: new ErroDoBanco('sem_login') })
    vi.mocked(conexao.encerrarSessao).mockImplementationOnce(async () => {
      passos.push('encerrar')
      throw new ErroDoBanco('erro_interno')
    })
    const resposta = await executar(definicao({}, passos), pedido(corpoCerto), infraFalsa(conexao))
    expect(resposta.resultado).toEqual({ ok: false, codigo: 'sem_login' })
    expect(passos).toEqual(['quemE', 'contexto', 'encerrar', 'sairLocal'])
  })

  it('porta 2: estúdio trocado em outro aparelho → estudio_trocado, sem trabalho (CA-06)', async () => {
    const { conexao, passos } = conexaoFalsa({ contexto: new ErroDoBanco('estudio_trocado') })
    const resposta = await executar(definicao({}, passos), pedido(corpoCerto), infraFalsa(conexao))
    expect(resposta.resultado).toEqual({ ok: false, codigo: 'estudio_trocado' })
    expect(passos).toEqual(['quemE', 'contexto', 'recusa:teste.criar:estudio_trocado'])
  })

  it('sem estúdio escolhido → sem_estudio', async () => {
    const { conexao, passos } = conexaoFalsa({ contexto: { ...contextoA, orgId: null, papel: null } })
    const resposta = await executar(definicao({}, passos), pedido(corpoCerto), infraFalsa(conexao))
    expect(resposta.resultado).toEqual({ ok: false, codigo: 'sem_estudio' })
    expect(passos).not.toContain('trabalho')
  })

  it('porta 3: célula ausente → sem_permissao, antes da porta 4, sem trabalho nem banco do módulo', async () => {
    const { conexao, passos } = conexaoFalsa({ contexto: { ...contextoA, papel: 'profissional' } })
    const def = definicao({}, passos)
    // Entrada também errada: a porta 3 recusa primeiro.
    const resposta = await executar(def, pedido({ estudioDaTela: ORG_A, dados: { x: 1 } }), infraFalsa(conexao))
    expect(resposta.resultado).toEqual({ ok: false, codigo: 'sem_permissao' })
    expect(passos).toEqual(['quemE', 'contexto', 'recusa:teste.criar:sem_permissao'])
    expect(def.trabalho).not.toHaveBeenCalled()
  })

  it.each([
    ['dona', 'teste.criar', 'todos'],
    ['dona', 'teste.ver', 'todos'],
    ['recepcao', 'teste.criar', 'todos'],
    ['profissional', 'teste.ver', 'proprios'],
  ] as const)('porta 3: %s em %s → ctx.alcance %s', async (papel, permissao, alcance) => {
    const { conexao } = conexaoFalsa({ contexto: { ...contextoA, papel } })
    const def = definicao({ permissao: chave(permissao) })
    const resposta = await executar(def, pedido(corpoCerto), infraFalsa(conexao))
    expect(resposta.resultado.ok).toBe(true)
    const [ctx] = vi.mocked(def.trabalho).mock.calls[0]!
    expect(ctx).toMatchObject({ alcance })
  })

  it('o trabalho recebe o alcance e não o papel (ADR 0020 · D5)', async () => {
    const { conexao } = conexaoFalsa({ contexto: { ...contextoA, papel: 'dona' } })
    const def = definicao()
    await executar(def, pedido(corpoCerto), infraFalsa(conexao))
    const [ctx] = vi.mocked(def.trabalho).mock.calls[0]!
    expect(ctx).toHaveProperty('alcance', 'todos')
    expect(ctx).not.toHaveProperty('papel')
    expect(JSON.stringify(Object.values(ctx as object))).not.toContain('dona')
    // No tipo também: o trabalho do modo estudio não enxerga papel.
    const trabalho: DefinicaoDeAcao<z.ZodType, unknown>['trabalho'] = async (c) => {
      // @ts-expect-error — ContextoEstudio não tem papel
      return c.papel
    }
    expect(trabalho).toBeTypeOf('function')
  })

  it('chave fora do catálogo → sem_permissao, mesmo para a dona', async () => {
    const { conexao, passos } = conexaoFalsa({ contexto: { ...contextoA, papel: 'dona' } })
    const def = definicao({ permissao: chave('teste.remover') }, passos)
    const resposta = await executar(def, pedido(corpoCerto), infraFalsa(conexao))
    expect(resposta.resultado).toEqual({ ok: false, codigo: 'sem_permissao' })
    expect(passos).not.toContain('trabalho')
  })

  it('sem fonte injetada: usa a matriz do código, que não tem a chave de teste → sem_permissao', async () => {
    const { conexao, passos } = conexaoFalsa({ contexto: { ...contextoA, papel: 'dona' } })
    const resposta = await executar(definicao({}, passos), pedido(corpoCerto), infraFalsa(conexao, true, null))
    expect(resposta.resultado).toEqual({ ok: false, codigo: 'sem_permissao' })
    expect(passos).not.toContain('trabalho')
  })

  it.each<[string, FonteDeAlcance]>([
    ['lança', () => {
      throw new Error('quebrou')
    }],
    ['devolve alcance desconhecido', () => 'sim' as never],
    ['devolve true', () => true as never],
  ])('fonte que %s → sem_permissao (falha fechada)', async (_nome, fonte) => {
    const { conexao, passos } = conexaoFalsa()
    const resposta = await executar(definicao({}, passos), pedido(corpoCerto), infraFalsa(conexao, true, fonte))
    expect(resposta.resultado).toEqual({ ok: false, codigo: 'sem_permissao' })
    expect(passos).not.toContain('trabalho')
  })
})

describe('executar · porta 4 (CA-08)', () => {
  const casos: [string, unknown][] = [
    ['campo a mais', { titulo: 'ok', orgId: ORG_A }],
    ['tipo errado', { titulo: 3 }],
    ['tamanho acima do limite', { titulo: 'x'.repeat(11) }],
    ['texto vazio', { titulo: '' }],
    ['sem dados', undefined],
  ]
  for (const [nome, dados] of casos) {
    it(`${nome} → entrada_invalida, trabalho e banco do módulo não chamados`, async () => {
      const { conexao, passos } = conexaoFalsa()
      const def = definicao({}, passos)
      const resposta = await executar(def, pedido({ estudioDaTela: ORG_A, dados }), infraFalsa(conexao))
      expect(resposta.resultado).toEqual({ ok: false, codigo: 'entrada_invalida' })
      expect(def.trabalho).not.toHaveBeenCalled()
      expect(passos).toEqual(['quemE', 'contexto', 'recusa:teste.criar:entrada_invalida'])
    })
  }
})

describe('executar · porta 5 e erros (CA-12)', () => {
  it('erro do banco no trabalho → só o código, e linha de recusa', async () => {
    const { conexao, passos } = conexaoFalsa()
    const def = definicao({
      trabalho: async () => {
        throw new ErroDoBanco('conflito')
      },
    })
    const resposta = await executar(def, pedido(corpoCerto), infraFalsa(conexao))
    expect(resposta.resultado).toEqual({ ok: false, codigo: 'conflito' })
    expect(passos.at(-1)).toBe('recusa:teste.criar:conflito')
  })

  it('exceção com texto do banco ou dado pessoal → erro_interno, nada do texto na resposta', async () => {
    const { conexao } = conexaoFalsa()
    const def = definicao({
      trabalho: async () => {
        throw new Error('duplicate key "maria@exemplo.test" at app.clientes; stack...')
      },
    })
    const resposta = await executar(def, pedido(corpoCerto), infraFalsa(conexao))
    expect(resposta.resultado).toEqual({ ok: false, codigo: 'erro_interno' })
    expect(JSON.stringify(resposta)).not.toMatch(/maria|clientes|stack/)
  })

  it('Recusa do módulo passa só o código', async () => {
    const { conexao } = conexaoFalsa()
    const def = definicao({
      trabalho: async () => {
        throw new Recusa('sem_permissao')
      },
    })
    expect((await executar(def, pedido(corpoCerto), infraFalsa(conexao))).resultado).toEqual({
      ok: false,
      codigo: 'sem_permissao',
    })
  })

  it('gravação a mais ou sem poder → erro_interno, mesmo com trabalho "ok" (D3)', async () => {
    const { conexao } = conexaoFalsa({ violou: true })
    const resposta = await executar(definicao(), pedido(corpoCerto), infraFalsa(conexao))
    expect(resposta.resultado).toEqual({ ok: false, codigo: 'erro_interno' })
  })

  it('o trabalho recebe grava da definição', async () => {
    const { conexao, passos } = conexaoFalsa()
    await executar(definicao({ grava: false }), pedido(corpoCerto), infraFalsa(conexao))
    expect(passos).toContain('iniciarTrabalho:false')
  })

  it('método diferente do declarado → erro_interno, nada aberto', async () => {
    const { conexao } = conexaoFalsa()
    const infra = infraFalsa(conexao)
    const resposta = await executar(definicao(), pedido(corpoCerto, 'GET'), infra)
    expect(resposta.resultado).toEqual({ ok: false, codigo: 'erro_interno' })
    expect(infra.abrirConexao).not.toHaveBeenCalled()
  })

  it('variável de ambiente faltando → erro_interno (falha fechada)', async () => {
    const { conexao } = conexaoFalsa()
    const infra = infraFalsa(conexao, false)
    const resposta = await executar(definicao(), pedido(corpoCerto), infra)
    expect(resposta.resultado).toEqual({ ok: false, codigo: 'erro_interno' })
    expect(infra.abrirConexao).not.toHaveBeenCalled()
  })

  it('registro de recusa que falha não muda a resposta', async () => {
    const { conexao } = conexaoFalsa({ contexto: new ErroDoBanco('estudio_trocado') })
    vi.mocked(conexao.registrarRecusa).mockRejectedValueOnce(new Error('caiu'))
    const resposta = await executar(definicao(), pedido(corpoCerto), infraFalsa(conexao))
    expect(resposta.resultado).toEqual({ ok: false, codigo: 'estudio_trocado' })
  })
})

describe('executar · outros modos', () => {
  it('pessoa: sem estudioDaTela, sem cabeçalho de estúdio, orgId pode ser vazio', async () => {
    const { conexao, passos } = conexaoFalsa({ contexto: { ...contextoA, orgId: null, papel: null, idioma: null } })
    const def = definicao<'pessoa'>({ sessao: 'pessoa', permissao: 'qualquer', entrada: z.strictObject({}) }, passos)
    const infra = infraFalsa(conexao)
    const resposta = await executar(def, pedido({ dados: {} }), infra)
    expect(resposta.resultado.ok).toBe(true)
    expect(infra.abrirConexao).toHaveBeenCalledWith(
      expect.objectContaining({ cabecalhos: { pedidoId: PEDIDO, acao: 'teste.criar' } }),
    )
    const [ctx] = vi.mocked(def.trabalho).mock.calls[0]!
    // sem estúdio, o idioma vem do navegador
    expect(ctx).toMatchObject({ orgId: null, papel: null, idioma: 'en', conexao })
    // só o modo estudio conta gravações
    expect(passos).not.toContain('iniciarTrabalho:true')
  })

  it('pessoa: estudioDaTela no corpo → entrada_invalida', async () => {
    const { conexao } = conexaoFalsa()
    const def = definicao<'pessoa'>({ sessao: 'pessoa', permissao: 'qualquer', entrada: z.strictObject({}) })
    const resposta = await executar(def, pedido({ estudioDaTela: ORG_A, dados: {} }), infraFalsa(conexao))
    expect(resposta.resultado).toEqual({ ok: false, codigo: 'entrada_invalida' })
  })

  it('opcional sem sessão: trabalho roda com sessão vazia e idioma do navegador', async () => {
    const { conexao, passos } = conexaoFalsa({ claims: false })
    const def = definicao<'opcional'>(
      { sessao: 'opcional', permissao: 'qualquer', metodo: 'GET', grava: false, entrada: z.strictObject({}) },
      passos,
    )
    const resposta = await executar(def, pedido(undefined, 'GET'), infraFalsa(conexao))
    expect(resposta.resultado.ok).toBe(true)
    const [ctx] = vi.mocked(def.trabalho).mock.calls[0]!
    expect(ctx).toMatchObject({ sessao: null, idiomaDoNavegador: 'en' })
    expect(passos).toEqual(['quemE', 'trabalho'])
  })

  it('opcional com sessão vencida: encerra e segue como sem sessão', async () => {
    const { conexao, passos } = conexaoFalsa({ contexto: new ErroDoBanco('sem_login') })
    const def = definicao<'opcional'>(
      { sessao: 'opcional', permissao: 'qualquer', metodo: 'GET', grava: false, entrada: z.strictObject({}) },
      passos,
    )
    const resposta = await executar(def, pedido(undefined, 'GET'), infraFalsa(conexao))
    expect(resposta.resultado.ok).toBe(true)
    expect(passos).toEqual(['quemE', 'contexto', 'encerrar', 'sairLocal', 'trabalho'])
  })

  it('nenhuma: completa até o tempo mínimo em todo resultado (RF-02)', async () => {
    for (const corpo of [{ dados: { titulo: 'ok' } }, { dados: { titulo: '' } }]) {
      const { conexao } = conexaoFalsa()
      const def = definicao<'nenhuma'>({ sessao: 'nenhuma', permissao: 'qualquer' })
      const infra = infraFalsa(conexao)
      await executar(def, pedido(corpo), infra)
      expect(infra.esperar).toHaveBeenCalledWith(TEMPO_MINIMO_SEM_SESSAO_MS)
    }
  })

  it('nenhuma: não confere token nem contexto antes do trabalho', async () => {
    const { conexao, passos } = conexaoFalsa()
    const def = definicao<'nenhuma'>({ sessao: 'nenhuma', permissao: 'qualquer' }, passos)
    await executar(def, { ...pedido({ dados: { titulo: 'ok' } }), cookies: [{ nome: '__Host-sessao.0', valor: 'x' }] }, infraFalsa(conexao))
    expect(passos).toEqual(['trabalho'])
    const [ctx] = vi.mocked(def.trabalho).mock.calls[0]!
    expect(ctx).toMatchObject({ temCookieDeSessao: true, ip: '203.0.113.7', pedidoId: PEDIDO })
  })
})
