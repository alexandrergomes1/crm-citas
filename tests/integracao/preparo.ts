// Preparo dos testes de integração (plan.md §9; ADR 0018 · D14). Roda com o banco local de pé (pnpm db:start) e as
// variáveis postas por scripts/banco-local.mjs (tarefa D1, Engenheiro de DevOps). Nada é impresso nem gravado.
// A chave local de administração só existe aqui (tests/) e só em memória: cria as contas e os estúdios fictícios.
// Sem as variáveis, os testes ficam pulados (não passam nem falham): ver `bancoPronto`.
import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import { lerAmbiente, type Ambiente } from '@/data/ambiente'
import type { CookieAGravar, CookieDoPedido } from '@/data/cliente'
import { abrirConexao } from '@/data/sessao'
import { executar } from '@/server/portas/executar'
import type { DefinicaoDeAcao, Infra, Modo, RespostaHttp } from '@/server/portas/tipos'
import type { z } from 'zod'

// Nome combinado com a tarefa D1 (scripts/banco-local.mjs). Se D1 escolher outro, muda só aqui.
const VARIAVEL_DA_CHAVE_ADMIN = 'SUPABASE_CHAVE_ADMIN_LOCAL'

export const ambiente: Ambiente | null = lerAmbiente(process.env)
const chaveAdmin = process.env[VARIAVEL_DA_CHAVE_ADMIN]

/** Banco local com Auth, Data API e as variáveis da execução. */
export const bancoPronto = ambiente !== null && Boolean(chaveAdmin)

export const infra: Infra = {
  ambiente: () => ambiente,
  abrirConexao,
  agora: () => Date.now(),
  esperar: (ms) => new Promise((pronto) => setTimeout(pronto, ms)),
  novoPedidoId: () => crypto.randomUUID(),
}

/** Cliente de administração local; manda a chave do servidor (o pré-pedido exige em todo pedido, D16). */
export function admin(): SupabaseClient {
  if (!ambiente || !chaveAdmin) throw new Error('banco local não preparado')
  return createClient(ambiente.supabaseUrl, chaveAdmin, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { 'x-chave-servidor': ambiente.chaveServidor, 'x-pedido': crypto.randomUUID() } },
  })
}

/** Sufixo novo por execução: o limite de tentativas (15 min) não carrega de uma rodada para outra. */
export const rodada = crypto.randomUUID().slice(0, 8)
let contador = 0
export const emailFicticio = (nome: string) => `${nome}.${rodada}.${++contador}@exemplo.test`
/** IP de documentação (RFC 5737) diferente por chamada. */
export const ipFicticio = () => `198.51.100.${(++contador % 250) + 1}`

export async function criarPessoa(email: string, senha: string): Promise<string> {
  const { data, error } = await admin().auth.admin.createUser({ email, password: senha, email_confirm: true })
  if (error || !data.user) throw new Error('não criou a pessoa fictícia')
  return data.user.id
}

export async function criarEstudio(nome: string, idioma: 'pt' | 'es' | 'en' = 'pt'): Promise<string> {
  const { data, error } = await admin()
    .from('estudios')
    .insert({ nome: `${nome} ${rodada}`, moeda: 'EUR', idioma, fuso_horario: 'Europe/Madrid' })
    .select('org_id')
    .single()
  if (error || !data) throw new Error('não criou o estúdio fictício')
  return data.org_id as string
}

export async function vincular(
  orgId: string,
  userId: string,
  papel: 'dona' | 'recepcao' | 'profissional',
  ativo = true,
): Promise<void> {
  const { error } = await admin().from('membros').insert({ org_id: orgId, user_id: userId, papel, ativo })
  if (error) throw new Error('não vinculou a pessoa fictícia')
}

/** Um "navegador": guarda os cookies que o servidor manda, como o navegador faria. */
export class Navegador {
  private readonly cookies = new Map<string, string>()
  constructor(readonly ip: string = ipFicticio()) {}

  lista(): CookieDoPedido[] {
    return [...this.cookies].map(([nome, valor]) => ({ nome, valor }))
  }

  /** Cópia: o "cookie antigo" guardado antes de Sair (CA-13). */
  copia(): Navegador {
    const outro = new Navegador(this.ip)
    for (const [nome, valor] of this.cookies) outro.cookies.set(nome, valor)
    return outro
  }

  aplicar(cookies: readonly CookieAGravar[]): void {
    for (const { nome, valor, opcoes } of cookies) {
      if (opcoes.maxAge > 0) this.cookies.set(nome, valor)
      else this.cookies.delete(nome)
    }
  }

  async chamar<E extends z.ZodType, S, M extends Modo>(
    def: DefinicaoDeAcao<E, S, M>,
    corpo: unknown,
  ): Promise<RespostaHttp<S>> {
    const resposta = await executar(
      def,
      { metodo: def.metodo, corpo, cookies: this.lista(), cabecalho: () => null, ip: this.ip },
      infra,
    )
    this.aplicar(resposta.cookies)
    return resposta
  }
}
