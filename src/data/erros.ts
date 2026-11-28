// Erro do banco (PostgREST) ou do Auth → código da lista fechada de RF-22 (ADR 0018 · D11; plan.md §4).
// Nada do texto original segue: só o código sai daqui (ASVS V7.4.1; CA-12).

/** Códigos que o banco e o Auth podem produzir. É parte da lista de src/server/portas/erros.ts. */
export const CODIGOS_DO_BANCO = [
  'sem_login',
  'estudio_trocado',
  'sem_estudio',
  'sem_permissao',
  'conflito',
  'limite',
  'erro_interno',
] as const
export type CodigoDoBanco = (typeof CODIGOS_DO_BANCO)[number]

const ehCodigoDoBanco = (valor: unknown): valor is CodigoDoBanco =>
  typeof valor === 'string' && (CODIGOS_DO_BANCO as readonly string[]).includes(valor)

/** Erro levado entre src/data e src/server; a mensagem é só o código (nada do banco). */
export class ErroDoBanco extends Error {
  readonly codigo: CodigoDoBanco
  constructor(codigo: CodigoDoBanco) {
    super(codigo)
    this.name = 'ErroDoBanco'
    this.codigo = codigo
  }
}

// Conflito de dado (PostgreSQL, apêndice A): exclusão (agenda sobreposta) e chave única.
const CONFLITO = new Set(['23P01', '23505'])
// PostgREST (errors.rst): token inválido ou vencido.
const TOKEN_RECUSADO = new Set(['PGRST301', 'PGRST303'])

/**
 * Erro do PostgREST (objeto `error` do postgrest-js) → código.
 * O pré-pedido e as funções do banco recusam com `raise sqlstate 'PGRST'` e o código da lista no campo
 * `code` (guia "Securing your API"); esse código passa como está. O resto vira erro_interno.
 */
export function codigoDoPostgrest(erro: unknown): CodigoDoBanco {
  const codigo = (erro as { code?: unknown } | null)?.code
  if (ehCodigoDoBanco(codigo)) return codigo
  if (typeof codigo === 'string') {
    if (CONFLITO.has(codigo)) return 'conflito'
    if (TOKEN_RECUSADO.has(codigo)) return 'sem_login'
  }
  return 'erro_interno'
}

// Auth (lista de códigos do auth-js 2.119.2, lib/error-codes).
const AUTH_SEM_LOGIN = new Set([
  'invalid_credentials',
  'email_not_confirmed',
  'user_banned',
  'user_not_found',
  'session_not_found',
  'session_expired',
  'refresh_token_not_found',
  'refresh_token_already_used',
  'bad_jwt',
])
const AUTH_LIMITE = new Set(['over_request_rate_limit'])

/** Erro do Auth → código. E-mail errado, senha errada e conta bloqueada dão o mesmo `sem_login` (RF-02). */
export function codigoDoAuth(erro: unknown): CodigoDoBanco {
  const { code, status } = (erro ?? {}) as { code?: unknown; status?: unknown }
  if (typeof code === 'string') {
    if (AUTH_SEM_LOGIN.has(code)) return 'sem_login'
    if (AUTH_LIMITE.has(code)) return 'limite'
  }
  if (status === 429) return 'limite'
  if (status === 400 || status === 401 || status === 403) return 'sem_login'
  return 'erro_interno'
}

/** Qualquer coisa lançada → código (ErroDoBanco mantém o seu; o resto é erro_interno). */
export function codigoDe(erro: unknown): CodigoDoBanco {
  return erro instanceof ErroDoBanco ? erro.codigo : 'erro_interno'
}
