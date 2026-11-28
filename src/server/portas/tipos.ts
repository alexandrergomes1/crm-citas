// Tipos do contrato da camada de serviço (plan.md §4; ADR 0018 · D11 a D13). Os módulos dependem deles.
import type { z } from 'zod'
import type { Ambiente } from '@/data/ambiente'
import type { Banco, CookieAGravar, CookieDoPedido } from '@/data/cliente'
import type { Conexao, ContextoDaSessao, OpcoesDaConexao, Papel } from '@/data/sessao'
import type { Idioma } from '@/domain/idioma'
import type { Resultado } from './erros'

export type { Papel }
export const PAPEIS: readonly Papel[] = ['dona', 'recepcao', 'profissional']

/** `estudio` para todo módulo; os outros só para a lista fechada de catalogo.ts (D12). */
export type Modo = 'estudio' | 'pessoa' | 'opcional' | 'nenhuma'

export type Metodo = 'GET' | 'POST'

/** Entregue ao trabalho de toda ação de módulo (porta 5). */
export type ContextoEstudio = {
  readonly pedidoId: string
  readonly usuarioId: string
  readonly orgId: string
  readonly papel: Papel
  readonly idioma: Idioma
  readonly fuso: string
  readonly moeda: string
  /** Token da pessoa + cabeçalhos do pedido; no máximo 1 gravação (D3). */
  readonly banco: Banco
}

/** Ações da pessoa antes ou fora do estúdio (listar, escolher, trocar, sair). */
export type ContextoPessoa = {
  readonly pedidoId: string
  readonly usuarioId: string
  readonly orgId: string | null
  readonly papel: Papel | null
  readonly idioma: Idioma
  readonly conexao: Conexao
}

/** `sessao.ler`: com ou sem sessão. */
export type ContextoOpcional = {
  readonly pedidoId: string
  readonly idiomaDoNavegador: Idioma
  readonly sessao: ContextoDaSessao | null
  readonly conexao: Conexao
}

/** `sessao.entrar`: sem sessão. */
export type ContextoSemSessao = {
  readonly pedidoId: string
  /** Pedido trouxe cookie de sessão? (RF-05: encerra antes de entrar de novo) */
  readonly temCookieDeSessao: boolean
  /** IP da pessoa, só para a chave HMAC do limite (nunca gravado; D8). */
  readonly ip: string | null
  readonly segredoTentativas: string
  readonly conexao: Conexao
}

export type ContextoDo<M extends Modo> = M extends 'estudio'
  ? ContextoEstudio
  : M extends 'pessoa'
    ? ContextoPessoa
    : M extends 'opcional'
      ? ContextoOpcional
      : ContextoSemSessao

/** Regra pura de src/domain/<modulo>/acesso.ts, ou a lista de papéis. `qualquer` só fora do modo estudio. */
export type Permissao<M extends Modo = Modo> =
  | readonly Papel[]
  | ((papel: Papel) => boolean)
  | (M extends 'estudio' ? never : 'qualquer')

export type NomeDaAcao = `${string}.${string}`

export type DefinicaoDeAcao<E extends z.ZodType, S, M extends Modo = 'estudio'> = {
  /** ex.: 'agenda.bloqueio.criar'; único no catálogo; só [a-z_.], até 64 (app.registro). */
  readonly nome: NomeDaAcao
  /** POST quando grava. */
  readonly metodo: Metodo
  readonly sessao: M
  readonly permissao: Permissao<M>
  /** z.strictObject(...); sem campo de estúdio. */
  readonly entrada: E
  readonly grava: boolean
  readonly trabalho: (ctx: ContextoDo<M>, dados: z.output<E>) => Promise<S>
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any -- catálogo guarda definições de qualquer forma
export type DefinicaoQualquer = DefinicaoDeAcao<z.ZodType, any, Modo>

/** O que chega do adaptador HTTP (sem framework). */
export type PedidoHttp = {
  readonly metodo: string
  readonly corpo: unknown
  readonly cookies: readonly CookieDoPedido[]
  readonly cabecalho: (nome: string) => string | null
  readonly ip: string | null
}

/** O que o adaptador HTTP aplica à resposta. */
export type RespostaHttp<S> = {
  readonly resultado: Resultado<S>
  readonly cookies: readonly CookieAGravar[]
  readonly cabecalhos: Readonly<Record<string, string>>
}

/** Dependências de fora (trocadas por falsas nos testes). */
export type Infra = {
  readonly ambiente: () => Ambiente | null
  readonly abrirConexao: (opcoes: OpcoesDaConexao) => Conexao
  readonly agora: () => number
  readonly esperar: (ms: number) => Promise<void>
  readonly novoPedidoId: () => string
}
