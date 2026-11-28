// Preparo dos testes de integração (plan.md §9; ADR 0018 · D14). Roda com o banco local de pé (pnpm db:start) e as
// variáveis postas por scripts/banco-local.mjs (tarefa D1, Engenheiro de DevOps). Nada é impresso nem gravado.
// A chave local de administração só existe aqui (tests/) e só em memória: cria as contas e os estúdios fictícios.
// Sem as variáveis, os testes ficam pulados (não passam nem falham): ver `bancoPronto`.
import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import { lerAmbiente, type Ambiente } from '@/data/ambiente'
import type { CookieAGravar, CookieDoPedido } from '@/data/cliente'
import { abrirConexao } from '@/data/sessao'
import { executar } from '@/server/portas/executar'
import type { DefinicaoDeAcao, FonteDeAlcance, Infra, Modo, RespostaHttp } from '@/server/portas/tipos'
import type { z } from 'zod'

// Nome combinado com a tarefa D1 (scripts/banco-local.mjs). Se D1 escolher outro, muda só aqui.
const VARIAVEL_DA_CHAVE_ADMIN = 'SUPABASE_CHAVE_ADMIN_LOCAL'

export const ambiente: Ambiente | null = lerAmbiente(process.env)
const chaveAdmin = process.env[VARIAVEL_DA_CHAVE_ADMIN]

/** Banco local com Auth, Data API e as variáveis da execução. */
export const bancoPronto = ambiente !== null && Boolean(chaveAdmin)

const pedidosFeitos: string[] = []
/** Id do último pedido que passou pelas portas (para achar a linha do registro dele; CA-09a). */
export const ultimoPedido = (): string => {
  const id = pedidosFeitos.at(-1)
  if (!id) throw new Error('nenhum pedido feito')
  return id
}

export const infra: Infra = {
  ambiente: () => ambiente,
  abrirConexao,
  agora: () => Date.now(),
  esperar: (ms) => new Promise((pronto) => setTimeout(pronto, ms)),
  novoPedidoId: () => {
    const id = crypto.randomUUID()
    pedidosFeitos.push(id)
    return id
  },
}

const RAIZ = fileURLToPath(new URL('../..', import.meta.url))
const SUPABASE = fileURLToPath(new URL('../../node_modules/.bin/supabase', import.meta.url))
const FORMA_UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

/** Confere que o valor é uuid antes de pô-lo numa consulta (só ids gerados pelo teste entram no SQL). */
export function uuid(valor: string): string {
  if (!FORMA_UUID.test(valor)) throw new Error('valor não é uuid')
  return `'${valor}'::uuid`
}

/** Máquinas aceitas como banco local: só a própria máquina. */
const MAQUINAS_LOCAIS = new Set(['127.0.0.1', 'localhost', '[::1]', '::1'])

/**
 * O endereço do banco aponta para a própria máquina? Endereço ilegível conta como não (falha fechada).
 * Exportada para o teste; o endereço nunca é impresso (leva a senha local).
 */
export function ehBancoLocal(endereco: unknown): boolean {
  if (typeof endereco !== 'string') return false
  try {
    const url = new URL(endereco)
    return (url.protocol === 'postgresql:' || url.protocol === 'postgres:') && MAQUINAS_LOCAIS.has(url.hostname)
  } catch {
    return false
  }
}

let alvoLocalConferido = false

/**
 * Antes da primeira consulta, confere pela própria CLI que o alvo é o banco local (`supabase status -o json`, campo
 * DB_URL em 127.0.0.1, localhost ou ::1); qualquer outra coisa recusa e nenhuma consulta sai (revisão de segurança R2;
 * AGENTS.md §1: a IA nunca mexe no banco remoto). A saída tem chaves locais: fica só em memória, nunca impressa.
 */
function conferirAlvoLocal(): void {
  if (alvoLocalConferido) return
  const r = spawnSync(SUPABASE, ['status', '-o', 'json'], { cwd: RAIZ, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] })
  let endereco: unknown
  try {
    endereco = r.status === 0 ? (JSON.parse(r.stdout) as { DB_URL?: unknown }).DB_URL : undefined
  } catch {
    endereco = undefined
  }
  if (!ehBancoLocal(endereco)) throw new Error('alvo do banco não é o local: consulta recusada')
  alvoLocalConferido = true
}

/**
 * Uma instrução SQL no banco LOCAL, como `postgres`, pela CLI do projeto (`supabase db query`, alvo local por padrão;
 * nunca `--remote`; AGENTS.md §1), depois de conferido o alvo (`conferirAlvoLocal`). Só para ler o registro e empurrar
 * o relógio da sessão para trás (CA-04, CA-09, CA-15). Devolve as linhas; erro → exceção sem o texto do banco.
 */
export function sql<T = Record<string, unknown>>(consulta: string): T[] {
  conferirAlvoLocal()
  const r = spawnSync(SUPABASE, ['db', 'query', '--output-format', 'json', consulta], {
    cwd: RAIZ,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  })
  if (r.status !== 0 || r.stdout.includes('"_tag":"Error"')) throw new Error('consulta ao banco local falhou')
  return linhasDaSaida<T>(r.stdout)
}

/**
 * Etiqueta do comando que a CLI responde, em vez de JSON, a instrução de escrita sem linhas de volta. Conferido rodando
 * `supabase db query --output-format json` (CLI 3.4.0) nos dois modos (com e sem `AI_AGENT`/`CLAUDECODE`): a saída é
 * igual, só a etiqueta (`INSERT 0 1`, `INSERT 0 0`, `UPDATE 2`, `UPDATE 0`, `DELETE 0`). Só estas três contam.
 */
const ETIQUETA_SEM_LINHAS = /^(?:INSERT 0|UPDATE|DELETE) \d+$/

/**
 * Linhas da saída de `supabase db query --output-format json` (CLI 3.4.0). A forma muda com quem roda, conferido
 * rodando o comando: com `AI_AGENT` ou `CLAUDECODE` no ambiente (sessão de IA) vem `{"boundary", "rows", "warning"}`;
 * sem elas (CI, terminal comum) vem só a lista `[...]`. Insert, update ou delete sem linhas de volta respondem só a
 * etiqueta do comando (`ETIQUETA_SEM_LINHAS`) → lista vazia. Qualquer outra coisa (aviso em texto, JSON de outra forma,
 * saída vazia) → exceção, nunca uma lista vazia por engano (ADR 0018 · D22). Exportada para o teste.
 */
export function linhasDaSaida<T = Record<string, unknown>>(saida: string): T[] {
  const texto = saida.trim()
  if (ETIQUETA_SEM_LINHAS.test(texto)) return []
  let dados: unknown
  try {
    dados = JSON.parse(texto)
  } catch {
    throw new Error('saída da consulta em forma desconhecida')
  }
  if (Array.isArray(dados)) return dados as T[]
  const linhas = dados !== null && typeof dados === 'object' ? (dados as { rows?: unknown }).rows : undefined
  if (Array.isArray(linhas)) return linhas as T[]
  throw new Error('saída da consulta em forma desconhecida')
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
    /** Fonte da porta 3 só para ações de teste com catálogo de teste (ADR 0020 · D6); sem ela, a matriz do código. */
    alcanceDe?: FonteDeAlcance,
  ): Promise<RespostaHttp<S>> {
    const resposta = await executar(
      def,
      { metodo: def.metodo, corpo, cookies: this.lista(), cabecalho: () => null, ip: this.ip },
      alcanceDe ? { ...infra, alcanceDe } : infra,
    )
    this.aplicar(resposta.cookies)
    return resposta
  }
}
