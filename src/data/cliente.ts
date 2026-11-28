// Cliente do Supabase, só no servidor, um por pedido (guia SSR do Supabase; ADR 0018 · D2, D3, D9, D16).
// - cookie da sessão: __Host-, HttpOnly, Secure, SameSite=Lax, Path=/ (o @supabase/ssr 0.12.7 vem com httpOnly falso);
// - todo pedido à Data API leva x-chave-servidor e os cabeçalhos do pedido (x-pedido, x-acao, x-estudio-esperado);
// - na fase do trabalho, conta as gravações: grava falso com gravação, ou segunda gravação → recusa sem enviar.
// Só chave pública: chave secreta ou de serviço nunca aqui (RF-20). createBrowserClient nunca (lint).
import { createServerClient } from '@supabase/ssr'
import type { SupabaseClient } from '@supabase/supabase-js'
import type { Ambiente } from './ambiente'
import { ErroDoBanco } from './erros'

/** Nome-base do cookie; o @supabase/ssr pode partir o valor em `__Host-sessao.0`, `.1`, ... */
export const NOME_DO_COOKIE = '__Host-sessao'

/** Opções fixas de todo cookie da sessão (ASVS V3.4.1 a V3.4.3). `__Host-` exige Secure, Path=/ e nenhum Domain. */
export const OPCOES_DO_COOKIE = {
  httpOnly: true,
  secure: true,
  sameSite: 'lax',
  path: '/',
} as const

export type CookieDoPedido = { readonly nome: string; readonly valor: string }
export type CookieAGravar = {
  readonly nome: string
  readonly valor: string
  readonly opcoes: typeof OPCOES_DO_COOKIE & { readonly maxAge: number }
}

/** Saída que o adaptador HTTP aplica à resposta. */
export type SaidaDoCliente = {
  readonly cookies: readonly CookieAGravar[]
  readonly cabecalhos: Readonly<Record<string, string>>
}

/** Cabeçalhos que o pré-pedido do banco confere (plan.md §3.2 e §6 M5). */
export type CabecalhosDoPedido = {
  readonly pedidoId: string
  readonly acao: string
  readonly estudioEsperado?: string
}

declare const marcaDoBanco: unique symbol
/**
 * Acesso ao banco entregue ao trabalho (porta 5). Opaco para src/server: só as funções de src/data o usam
 * (com `clienteDoBanco`), e o tipo do Supabase não sai desta pasta.
 */
export type Banco = { readonly [marcaDoBanco]: true }

type Estado = {
  fase: 'portas' | 'trabalho'
  grava: boolean
  gravacoes: number
  violou: boolean
}

const clientes = new WeakMap<Banco, SupabaseClient>()

/** Só para src/data: o cliente atrás do Banco. */
export function clienteDoBanco(banco: Banco): SupabaseClient {
  const cliente = clientes.get(banco)
  if (!cliente) throw new ErroDoBanco('erro_interno')
  return cliente
}

/** É cookie da sessão? (o próprio nome ou um pedaço `nome.N`, como o @supabase/ssr grava) */
export const ehCookieDaSessao = (nome: string): boolean =>
  nome === NOME_DO_COOKIE || nome.startsWith(`${NOME_DO_COOKIE}.`) || nome.startsWith(`${NOME_DO_COOKIE}-`)

const caminhoDe = (entrada: RequestInfo | URL): string =>
  new URL(entrada instanceof Request ? entrada.url : String(entrada)).pathname

function ehGravacao(entrada: RequestInfo | URL, init?: RequestInit): boolean {
  if (!caminhoDe(entrada).startsWith('/rest/v1/')) return false
  const metodo = (init?.method ?? (entrada instanceof Request ? entrada.method : 'GET')).toUpperCase()
  return metodo !== 'GET' && metodo !== 'HEAD'
}

export type ClienteDoPedido = {
  readonly supabase: SupabaseClient
  readonly banco: Banco
  /** Começa a fase do trabalho: a partir daqui as gravações contam. */
  iniciarTrabalho(grava: boolean): void
  /** Terminou o trabalho: volta às portas (registro de recusa, saída). */
  terminarTrabalho(): void
  /** O trabalho tentou gravar sem poder, ou gravou duas vezes? */
  readonly violou: boolean
  /** Apaga todos os cookies da sessão que o pedido trouxe (Sair, sessão morta). */
  apagarCookiesDaSessao(): void
  saida(): SaidaDoCliente
}

export type OpcoesDoCliente = {
  readonly ambiente: Ambiente
  readonly cookies: readonly CookieDoPedido[]
  readonly cabecalhos: CabecalhosDoPedido
  /** Só para teste: fetch falso. */
  readonly fetch?: typeof fetch
}

export function criarCliente({ ambiente, cookies, cabecalhos, fetch: fetchBase = fetch }: OpcoesDoCliente): ClienteDoPedido {
  const estado: Estado = { fase: 'portas', grava: false, gravacoes: 0, violou: false }
  const gravar = new Map<string, CookieAGravar>()
  const cabecalhosDaResposta: Record<string, string> = {}
  let atuais = cookies.map(({ nome, valor }) => ({ name: nome, value: valor }))

  const fetchContado: typeof fetch = (entrada, init) => {
    // A linha de recusa vai sem o estúdio esperado: com ele, o pré-pedido recusaria de novo (estudio_trocado) e a
    // recusa nunca ficaria registrada. O org_id da linha vem da sessão, no banco (ADR 0019).
    if (caminhoDe(entrada) === '/rest/v1/rpc/registrar_recusa') {
      const semEstudio = new Headers(init?.headers)
      semEstudio.delete('x-estudio-esperado')
      init = { ...init, headers: semEstudio }
    }
    if (estado.fase === 'trabalho' && ehGravacao(entrada, init)) {
      estado.gravacoes += 1
      if (!estado.grava || estado.gravacoes > 1) {
        estado.violou = true
        return Promise.reject(new ErroDoBanco('erro_interno'))
      }
    }
    return fetchBase(entrada, init)
  }

  const enfileirar = (nome: string, valor: string, maxAge: number) => {
    gravar.set(nome, { nome, valor, opcoes: { ...OPCOES_DO_COOKIE, maxAge } })
    atuais = atuais.filter((c) => c.name !== nome)
    if (maxAge > 0) atuais.push({ name: nome, value: valor })
  }

  const global: Record<string, string> = {
    'x-chave-servidor': ambiente.chaveServidor,
    'x-pedido': cabecalhos.pedidoId,
    'x-acao': cabecalhos.acao,
  }
  if (cabecalhos.estudioEsperado) global['x-estudio-esperado'] = cabecalhos.estudioEsperado

  const supabase = createServerClient(ambiente.supabaseUrl, ambiente.chavePublica, {
    cookieOptions: { name: NOME_DO_COOKIE, ...OPCOES_DO_COOKIE },
    cookies: {
      getAll: () => atuais,
      setAll: (lista, cabecalhosDeCache) => {
        // Opções fixas aqui, não as que a biblioteca manda (defesa: nunca httpOnly falso).
        for (const { name, value, options } of lista) {
          if (!ehCookieDaSessao(name)) continue
          enfileirar(name, value, typeof options.maxAge === 'number' ? options.maxAge : 0)
        }
        Object.assign(cabecalhosDaResposta, cabecalhosDeCache)
      },
    },
    global: { headers: global, fetch: fetchContado },
    // Nada de Realtime nem de Storage nesta spec.
  })

  const banco = {} as Banco
  clientes.set(banco, supabase)

  return {
    supabase,
    banco,
    iniciarTrabalho(grava) {
      estado.fase = 'trabalho'
      estado.grava = grava
      estado.gravacoes = 0
    },
    terminarTrabalho() {
      estado.fase = 'portas'
    },
    get violou() {
      return estado.violou
    },
    apagarCookiesDaSessao() {
      for (const { nome } of cookies) if (ehCookieDaSessao(nome)) enfileirar(nome, '', 0)
      for (const { name } of [...atuais]) if (ehCookieDaSessao(name)) enfileirar(name, '', 0)
    },
    saida() {
      return { cookies: [...gravar.values()], cabecalhos: { ...cabecalhosDaResposta } }
    },
  }
}
