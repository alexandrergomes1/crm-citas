// Chamadas às funções de sessão do banco (plan.md §3 e §6; nomes do plano, desenho no ADR 0019 do Engenheiro de dados)
// e ao Auth (getClaims, signInWithPassword, signOut local). Uma conexão por pedido.
// Respostas do banco conferidas com esquema: forma inesperada → erro_interno (falha fechada).
// Nada de getSession() no servidor (guia SSR do Supabase): getClaims confere a assinatura do token.
import { z } from 'zod'
import { idiomaValido, type Idioma } from '@/domain/idioma'
import type { Ambiente } from './ambiente'
import {
  criarCliente,
  type Banco,
  type CabecalhosDoPedido,
  type CookieDoPedido,
  type SaidaDoCliente,
} from './cliente'
import { ErroDoBanco, codigoDoAuth, codigoDoPostgrest, type CodigoDoBanco } from './erros'

export type Papel = 'dona' | 'recepcao' | 'profissional'

/** Declarações do token que o servidor usa (só identificadores; nada de e-mail). */
export type Declaracoes = { readonly usuarioId: string; readonly sessaoId: string }

/** Linha de `public.contexto_da_sessao()`; `orgId` e `papel` vazios antes de escolher o estúdio. */
export type ContextoDaSessao = {
  readonly usuarioId: string
  readonly orgId: string | null
  readonly papel: Papel | null
  /** Idioma padrão do estúdio escolhido; vazio antes de escolher. */
  readonly idioma: Idioma | null
  readonly fuso: string | null
  readonly moeda: string | null
}

export type EstudioDaPessoa = { readonly orgId: string; readonly nome: string }

/** Resultado de entrar com senha no Auth. */
export type ResultadoDaSenha = { readonly ok: true } | { readonly ok: false; readonly codigo: CodigoDoBanco }

export interface Conexao {
  /** Porta 1: assinatura e validade do token (getClaims). Sem token válido → null. */
  quemE(): Promise<Declaracoes | null>
  /** Portas 1 e 2 no banco: sessão viva, 12 h, 1 h parada e estúdio esperado (pré-pedido). Recusa → ErroDoBanco. */
  contexto(): Promise<ContextoDaSessao>
  /** Porta 6, recusa nas portas 2 a 5: melhor esforço, nunca lança. */
  registrarRecusa(acao: string, codigo: string): Promise<void>
  /** Marca a sessão como encerrada no banco (não apaga). Recusa → ErroDoBanco. */
  encerrarSessao(): Promise<void>
  /** signOut({ scope: 'local' }) e apaga os cookies da sessão; roda sempre, nunca lança. */
  sairLocal(): Promise<void>
  /** Limite de tentativas (D8): true = pode tentar. */
  conferirTentativa(chaveIp: string, chaveConta: string): Promise<boolean>
  entrarComSenha(email: string, senha: string): Promise<ResultadoDaSenha>
  /** Linha de tentativa que falha: só evento, resultado, quando e pedido (RF-24a). Melhor esforço. */
  registrarTentativaFalha(): Promise<void>
  /** Cria a linha da sessão e devolve quantos estúdios ativos a pessoa tem. */
  iniciarSessao(): Promise<number>
  meusEstudios(): Promise<EstudioDaPessoa[]>
  escolherEstudio(orgId: string): Promise<void>
  /** Acesso entregue ao trabalho (porta 5). */
  readonly banco: Banco
  iniciarTrabalho(grava: boolean): void
  terminarTrabalho(): void
  readonly violou: boolean
  saida(): SaidaDoCliente
}

export type OpcoesDaConexao = {
  readonly ambiente: Ambiente
  readonly cookies: readonly CookieDoPedido[]
  readonly cabecalhos: CabecalhosDoPedido
  /** Só para teste. */
  readonly fetch?: typeof fetch
}

const uuid = z.uuid()

const linhaDoContexto = z.object({
  usuario_id: uuid,
  org_id: uuid.nullable(),
  papel: z.enum(['dona', 'recepcao', 'profissional']).nullable(),
  idioma: z.string().nullable(),
  fuso: z.string().max(64).nullable(),
  moeda: z.string().max(8).nullable(),
})

const linhaDeEstudio = z.object({ org_id: uuid, nome: z.string().max(200) })

// Função que devolve uma linha pode chegar como objeto ou como lista de uma linha (PostgREST).
const umaLinha = (dados: unknown): unknown => (Array.isArray(dados) ? (dados.length === 1 ? dados[0] : null) : dados)

/** Converte `{ data, error }` do postgrest-js: erro → ErroDoBanco com o código; nada do texto segue. */
function conferir<T>(resposta: { data: unknown; error: unknown }, esquema: z.ZodType<T>): T {
  if (resposta.error) throw new ErroDoBanco(codigoDoPostgrest(resposta.error))
  const lido = esquema.safeParse(resposta.data)
  if (!lido.success) throw new ErroDoBanco('erro_interno')
  return lido.data
}

const semRetorno = z.unknown()

export function abrirConexao(opcoes: OpcoesDaConexao): Conexao {
  const cliente = criarCliente(opcoes)
  const { supabase } = cliente
  const pedido = opcoes.cabecalhos.pedidoId

  const rpc = async <T>(nome: string, args: Record<string, unknown> | undefined, esquema: z.ZodType<T>): Promise<T> => {
    let resposta: { data: unknown; error: unknown }
    try {
      resposta = await supabase.rpc(nome, args)
    } catch (erro) {
      throw erro instanceof ErroDoBanco ? erro : new ErroDoBanco('erro_interno')
    }
    return conferir(resposta, esquema)
  }

  return {
    async quemE() {
      try {
        const { data, error } = await supabase.auth.getClaims()
        if (error || !data) return null
        const usuarioId = uuid.safeParse(data.claims.sub)
        const sessaoId = uuid.safeParse(data.claims.session_id)
        if (!usuarioId.success || !sessaoId.success || data.claims.role !== 'authenticated') return null
        return { usuarioId: usuarioId.data, sessaoId: sessaoId.data }
      } catch {
        return null
      }
    },

    async contexto() {
      const linha = await rpc('contexto_da_sessao', undefined, z.unknown())
      const lido = linhaDoContexto.safeParse(umaLinha(linha))
      if (!lido.success) throw new ErroDoBanco('erro_interno')
      const { usuario_id, org_id, papel, idioma, fuso, moeda } = lido.data
      return {
        usuarioId: usuario_id,
        orgId: org_id,
        papel,
        idioma: idioma === null ? null : idiomaValido(idioma),
        fuso,
        moeda,
      }
    },

    async registrarRecusa(acao, codigo) {
      try {
        await supabase.rpc('registrar_recusa', { p_acao: acao, p_codigo: codigo, p_pedido: pedido })
      } catch {
        // melhor esforço: a resposta não muda (plan.md §3.2 passo 7)
      }
    },

    async encerrarSessao() {
      await rpc('encerrar_sessao', { p_pedido: pedido }, semRetorno)
    },

    async sairLocal() {
      try {
        await supabase.auth.signOut({ scope: 'local' })
      } catch {
        // segue: o cookie é apagado de qualquer jeito (ADR 0018 · D4; R-16)
      }
      cliente.apagarCookiesDaSessao()
    },

    async conferirTentativa(chaveIp, chaveConta) {
      return rpc('conferir_tentativa', { p_chave_ip: chaveIp, p_chave_conta: chaveConta }, z.boolean())
    },

    async entrarComSenha(email, senha) {
      try {
        const { error } = await supabase.auth.signInWithPassword({ email, password: senha })
        return error ? { ok: false, codigo: codigoDoAuth(error) } : { ok: true }
      } catch {
        return { ok: false, codigo: 'erro_interno' }
      }
    },

    async registrarTentativaFalha() {
      try {
        await supabase.rpc('registrar_tentativa_falha', { p_pedido: pedido })
      } catch {
        // melhor esforço
      }
    },

    async iniciarSessao() {
      return rpc('iniciar_sessao', { p_pedido: pedido }, z.number().int().min(0))
    },

    async meusEstudios() {
      const linhas = await rpc('meus_estudios', undefined, z.array(linhaDeEstudio).max(50))
      return linhas.map(({ org_id, nome }) => ({ orgId: org_id, nome }))
    },

    async escolherEstudio(orgId) {
      await rpc('escolher_estudio', { p_org_id: orgId, p_pedido: pedido }, semRetorno)
    },

    banco: cliente.banco,
    iniciarTrabalho: (grava) => cliente.iniciarTrabalho(grava),
    terminarTrabalho: () => cliente.terminarTrabalho(),
    get violou() {
      return cliente.violou
    },
    saida: () => cliente.saida(),
  }
}
