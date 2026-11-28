// Preparo global do e2e (spec specs/20261128-030000-entrar-servico, plan.md §8 e §9; tarefa T3).
// Cria contas e estúdios fictícios novos a cada execução e entrega aos testes, por variável de ambiente, só e-mails,
// senhas fictícias da rodada e o endereço do banco local (para o CA-03 olhar a rede). Nada é impresso nem gravado.
//
// A chave local de administração só existe num processo filho, rodado por `scripts/banco-local.mjs --com-admin`
// (tarefa D1): este mesmo arquivo, executado pelo Node, cria as contas e sai. O servidor do app (webServer) roda pelo
// script SEM a chave de administração (tasks.md: só tests/ e e2e/ a recebem).
//
// Também exporta as ajudas comuns dos testes (entrar, acessibilidade, capturas), porque o plano não abre outro arquivo.
import { spawnSync } from 'node:child_process'
import { randomBytes } from 'node:crypto'
import { mkdirSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import type { Page, TestInfo } from '@playwright/test'

type Idioma = 'pt' | 'es' | 'en'
type Papel = 'dona' | 'recepcao' | 'profissional'
type EstudioDaConta = { readonly nome: string; readonly idioma: Idioma; readonly papel: Papel }
export type Conta = { readonly email: string; readonly senha: string; readonly estudios: readonly EstudioDaConta[] }

/** Projetos do playwright.config.ts: cada um tem as próprias contas (o limite de 10 tentativas é por conta). */
export const PROJETOS = ['celular', 'computador'] as const
type Projeto = (typeof PROJETOS)[number]
type TipoDeConta = 'um' | 'dois'
type Preparo = { readonly supabaseUrl: string; readonly contas: Record<Projeto, Record<TipoDeConta, Conta>> }

const VARIAVEL = 'E2E_PREPARO'
const RAIZ = fileURLToPath(new URL('..', import.meta.url))

// ---------------------------------------------------------------------------------------------------------------
// Processo filho: cria as contas com a chave de administração (só aqui) e devolve o endereço do banco local.
// ---------------------------------------------------------------------------------------------------------------
async function criarContas(): Promise<void> {
  const { createClient } = await import('@supabase/supabase-js')
  const url = process.env.SUPABASE_URL
  const chaveAdmin = process.env.SUPABASE_CHAVE_ADMIN_LOCAL
  const chaveServidor = process.env.CHAVE_SERVIDOR_BANCO
  if (!url || !chaveAdmin || !chaveServidor) throw new Error('banco local não preparado')
  const contas = JSON.parse(await lerEntrada()) as Conta[]
  // O pré-pedido exige a chave do servidor em todo pedido à Data API (ADR 0018 · D16).
  const admin = createClient(url, chaveAdmin, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { 'x-chave-servidor': chaveServidor, 'x-pedido': crypto.randomUUID() } },
  })
  for (const conta of contas) {
    const { data, error } = await admin.auth.admin.createUser({ email: conta.email, password: conta.senha, email_confirm: true })
    if (error || !data.user) throw new Error('não criou a pessoa fictícia')
    for (const estudio of conta.estudios) {
      const criado = await admin
        .from('estudios')
        .insert({ nome: estudio.nome, moeda: 'EUR', idioma: estudio.idioma, fuso_horario: 'Europe/Madrid' })
        .select('org_id')
        .single()
      if (criado.error || !criado.data) throw new Error('não criou o estúdio fictício')
      const vinculo = await admin
        .from('membros')
        .insert({ org_id: criado.data.org_id as string, user_id: data.user.id, papel: estudio.papel, ativo: true })
      if (vinculo.error) throw new Error('não vinculou a pessoa fictícia')
    }
  }
  process.stdout.write(JSON.stringify({ supabaseUrl: new URL(url).origin }))
}

function lerEntrada(): Promise<string> {
  return new Promise((pronto, falhou) => {
    let texto = ''
    process.stdin.setEncoding('utf8')
    process.stdin.on('data', (pedaco) => (texto += pedaco))
    process.stdin.on('end', () => pronto(texto))
    process.stdin.on('error', falhou)
  })
}

// ---------------------------------------------------------------------------------------------------------------
// globalSetup do Playwright (processo principal): monta as contas da rodada e chama o filho.
// ---------------------------------------------------------------------------------------------------------------
export default function preparoGlobal(): void {
  const rodada = randomBytes(4).toString('hex')
  // Senha de 70 caracteres ASCII (CA-18a: 64 ou mais; o Auth aceita até 72 bytes) para quem tem um estúdio.
  const senhaLonga = () => `${randomBytes(48).toString('base64url')}-ficticia`.padEnd(70, 'x').slice(0, 70)
  const senha = () => `${randomBytes(12).toString('base64url')}-ficticia`
  const contasDe = (projeto: Projeto): Record<TipoDeConta, Conta> => ({
    // A inicial da bolinha Sua conta é a primeira letra do e-mail: "U" e "D" (DESIGN.md §8b).
    um: {
      email: `um.${projeto}.${rodada}@exemplo.test`,
      senha: senhaLonga(),
      estudios: [{ nome: `Estúdio Aurora ${rodada}`, idioma: 'pt', papel: 'dona' }],
    },
    dois: {
      email: `dois.${projeto}.${rodada}@exemplo.test`,
      senha: senha(),
      estudios: [
        { nome: `Estúdio Lírio ${rodada}`, idioma: 'pt', papel: 'dona' },
        { nome: `Estudio Nube ${rodada}`, idioma: 'es', papel: 'recepcao' },
      ],
    },
  })
  const contas: Preparo['contas'] = { celular: contasDe('celular'), computador: contasDe('computador') }

  const filho = spawnSync(
    process.execPath,
    ['scripts/banco-local.mjs', '--com-admin', process.execPath, '--no-warnings', fileURLToPath(import.meta.url)],
    {
      cwd: RAIZ,
      encoding: 'utf8',
      input: JSON.stringify(PROJETOS.flatMap((p) => [contas[p].um, contas[p].dois])),
      env: { ...process.env, E2E_CRIAR_CONTAS: 'sim' },
      stdio: ['pipe', 'pipe', 'inherit'],
      timeout: 120_000,
    },
  )
  if (filho.status !== 0) throw new Error('preparo do e2e: não criou as contas fictícias (banco local de pé?)')
  const { supabaseUrl } = JSON.parse(filho.stdout) as { supabaseUrl: string }
  const preparo: Preparo = { supabaseUrl, contas }
  // Passa aos trabalhadores do Playwright pelo ambiente (o globalSetup roda antes deles).
  process.env[VARIAVEL] = JSON.stringify(preparo)
}

if (process.env.E2E_CRIAR_CONTAS === 'sim' && process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  criarContas().then(
    () => process.exit(0),
    () => {
      process.stderr.write('preparo do e2e: falhou ao criar as contas fictícias\n')
      process.exit(1)
    },
  )
}

// ---------------------------------------------------------------------------------------------------------------
// Ajudas dos testes
// ---------------------------------------------------------------------------------------------------------------
function preparo(): Preparo {
  const texto = process.env[VARIAVEL]
  if (!texto) throw new Error('preparo do e2e ausente (globalSetup)')
  return JSON.parse(texto) as Preparo
}

/** Conta fictícia do projeto em curso. */
export function conta(info: TestInfo, tipo: TipoDeConta): Conta {
  const projeto = info.project.name as Projeto
  return preparo().contas[projeto][tipo]
}

/** Origem do banco local (CA-03: o navegador nunca fala com ela). */
export const origemDoBanco = (): string => preparo().supabaseUrl

export const ehCelular = (info: TestInfo): boolean => info.project.name === 'celular'
const largura = (info: TestInfo) => (ehCelular(info) ? '390' : '1440')

/**
 * Espera a página ficar interativa (React hidratado): antes disso, "Entrar" faria o envio nativo do formulário e a
 * página recarregaria vazia. No servidor de desenvolvimento, "rede parada" marca o fim da carga dos módulos.
 */
export async function esperarPagina(page: Page): Promise<void> {
  await page.waitForLoadState('networkidle')
}

/** Preenche e envia Entrar (em português, o idioma do navegador do teste). */
export async function preencherEntrar(page: Page, { email, senha }: Pick<Conta, 'email' | 'senha'>): Promise<void> {
  await esperarPagina(page)
  await page.getByLabel('E-mail').fill(email)
  await page.getByLabel('Senha', { exact: true }).fill(senha)
  await page.getByRole('button', { name: 'Entrar' }).click()
}

/** Abre o app, entra e espera a página de destino. */
export async function entrar(page: Page, c: Conta, destino: '/' | '/escolher-estudio' = '/'): Promise<void> {
  await page.goto('/')
  await page.waitForURL('**/entrar')
  await preencherEntrar(page, c)
  await page.waitForURL((url) => url.pathname === destino)
}

/** Etiquetas da checagem automática (plan.md §9, CA-19). */
export const ETIQUETAS_AXE = ['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa']

export async function violacoes(page: Page): Promise<string[]> {
  const { default: AxeBuilder } = await import('@axe-core/playwright')
  const resultado = await new AxeBuilder({ page }).withTags(ETIQUETAS_AXE).analyze()
  return resultado.violations.map((v) => `${v.id}: ${v.nodes.map((n) => n.target.join(' ')).join(' | ')}`)
}

/**
 * Captura da tela inteira para o Revisor de design: em `E2E_CAPTURAS` (pasta fora do repositório) se a variável vier;
 * senão, na pasta de saída do teste (test-results/, fora do git). Escala 1 (Desktop Chrome).
 */
export async function capturar(page: Page, info: TestInfo, nome: string): Promise<void> {
  const pasta = process.env.E2E_CAPTURAS
  const arquivo = `${nome}-${largura(info)}.png`
  const destino = pasta ? path.join(pasta, arquivo) : info.outputPath(arquivo)
  mkdirSync(path.dirname(destino), { recursive: true })
  await page.screenshot({ path: destino, fullPage: true, animations: 'disabled' })
}
