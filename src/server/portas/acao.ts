// Molde único das ações do servidor (ADR 0018 · D12; spec RF-16, RF-21). Único arquivo que importa createServerFn (lint).
//
// Como declarar uma ação (o compilador do TanStack Start só reconhece `.handler(...)` no nível do módulo,
// atribuído a uma variável; por isso o molde tem duas partes, sempre juntas):
//
//   export const criarBloqueio = acaoPost.handler(
//     acao({ nome: 'agenda.bloqueio.criar', metodo: 'POST', sessao: 'estudio', permissao: podeBloquear,
//            entrada: z.strictObject({ ... }), grava: true, trabalho: async (ctx, dados) => { ... } }),
//   )
//
// - `acaoGet`/`acaoPost` são os construtores (createServerFn); o método do construtor tem de ser o `metodo` da
//   definição (conferido a cada pedido e no molde.test.ts).
// - `.validator` só de passagem (`unknown`): a porta 4 é feita depois das portas 1 a 3, em executar.ts (D13).
// - A tela chama `criarBloqueio({ data: { estudioDaTela, dados } })` e recebe `{ ok, valor } | { ok: false, codigo }`.
import { createServerFn, createServerOnlyFn } from '@tanstack/react-start'
import { getCookies, getRequest, getRequestIP, setCookie, setResponseHeader } from '@tanstack/react-start/server'
import type { z } from 'zod'
import { lerAmbiente } from '@/data/ambiente'
import { abrirConexao } from '@/data/sessao'
import { registrar } from './catalogo'
import type { Resultado } from './erros'
import { executar } from './executar'
import type { DefinicaoDeAcao, DefinicaoQualquer, Infra, Modo } from './tipos'

/** Construtor das ações de leitura (GET). */
export const acaoGet = createServerFn({ method: 'GET' }).validator((dados: unknown) => dados)
/** Construtor das ações que gravam (POST). */
export const acaoPost = createServerFn({ method: 'POST' }).validator((dados: unknown) => dados)

/** Dependências reais; só no servidor. */
const infraReal: Infra = {
  ambiente: () => lerAmbiente(process.env),
  abrirConexao,
  agora: () => Date.now(),
  esperar: (ms) => new Promise((pronto) => setTimeout(pronto, ms)),
  novoPedidoId: () => crypto.randomUUID(),
}

// Lê o pedido e grava a resposta pelo TanStack Start; o resto é executar.ts (sem framework).
const atender = createServerOnlyFn(
  async (def: DefinicaoQualquer, corpo: unknown, metodo: string): Promise<Resultado<unknown>> => {
    const pedido = getRequest()
    const cookies = Object.entries(getCookies()).map(([nome, valor]) => ({ nome, valor }))
    // IP só para a chave HMAC do limite (D8): cf-connecting-ip no Workers; no Node local, o do pedido.
    const ip = pedido.headers.get('cf-connecting-ip') ?? getRequestIP() ?? null

    const resposta = await executar(
      def,
      { metodo, corpo, cookies, cabecalho: (nome) => pedido.headers.get(nome), ip },
      infraReal,
    )

    for (const { nome, valor, opcoes } of resposta.cookies) setCookie(nome, valor, opcoes)
    for (const [nome, valor] of Object.entries(resposta.cabecalhos)) setResponseHeader(nome, valor)
    // Toda resposta de ação: nada em cache (RF-06, ADR 0018 · D10).
    setResponseHeader('Cache-Control', 'no-store')
    return resposta.resultado
  },
)

/** Contexto que o TanStack Start entrega ao manipulador (só o que o molde usa). */
type ChamadaDoServidor = { readonly data: unknown; readonly method: string }

/**
 * Declara uma ação: confere o molde, põe no catálogo e devolve o manipulador para `acaoGet/acaoPost.handler(...)`.
 * Fora do molde (nome, modo, método) → erro ao carregar o módulo.
 */
export function acao<E extends z.ZodType, S, M extends Modo = 'estudio'>(
  def: DefinicaoDeAcao<E, S, M>,
): ((chamada: ChamadaDoServidor) => Promise<Resultado<S>>) & { readonly definicaoDaAcao: DefinicaoQualquer } {
  const definicao = def as unknown as DefinicaoQualquer
  registrar(definicao)
  const manipulador = (chamada: ChamadaDoServidor) =>
    atender(definicao, chamada.data, chamada.method) as Promise<Resultado<S>>
  // A definição fica presa ao manipulador: molde.test.ts confere que o construtor (acaoGet/acaoPost) é o do `metodo`.
  return Object.assign(manipulador, { definicaoDaAcao: definicao })
}
