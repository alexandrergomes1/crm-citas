// Lista fechada dos códigos de erro (spec RF-22; ADR 0018 · D11). A tela traduz cada um numa frase genérica.
// Nada além do código sai na resposta: nem mensagem do banco, nem pilha, nem identificador (ASVS V7.4.1).
import { ErroDoBanco, codigoDe, type CodigoDoBanco } from '@/data/erros'

export const CODIGOS_DE_ERRO = [
  'sem_login',
  'estudio_trocado',
  'sem_estudio',
  'sem_permissao',
  'entrada_invalida',
  'conflito',
  'limite',
  'erro_interno',
] as const
export type CodigoDeErro = (typeof CODIGOS_DE_ERRO)[number]

export type Resultado<S> = { readonly ok: true; readonly valor: S } | { readonly ok: false; readonly codigo: CodigoDeErro }

/** Os códigos do banco são parte desta lista (conferido no teste). */
export type CodigoDoBancoNaLista = CodigoDoBanco extends CodigoDeErro ? true : false

export const ehCodigoDeErro = (valor: unknown): valor is CodigoDeErro =>
  typeof valor === 'string' && (CODIGOS_DE_ERRO as readonly string[]).includes(valor)

export const sucesso = <S>(valor: S): Resultado<S> => ({ ok: true, valor })
export const falha = (codigo: CodigoDeErro): Resultado<never> => ({ ok: false, codigo })

/** Recusa lançada pelo trabalho de uma ação (ex.: regra do módulo). Só o código segue. */
export class Recusa extends Error {
  readonly codigo: CodigoDeErro
  constructor(codigo: CodigoDeErro) {
    super(codigo)
    this.name = 'Recusa'
    this.codigo = codigo
  }
}

/** Qualquer coisa lançada → código da lista; o resto é erro_interno. */
export function codigoDoErro(erro: unknown): CodigoDeErro {
  if (erro instanceof Recusa) return erro.codigo
  if (erro instanceof ErroDoBanco) return codigoDe(erro)
  return 'erro_interno'
}
