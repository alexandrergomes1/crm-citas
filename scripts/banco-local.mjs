#!/usr/bin/env node
// Roda um comando com as variáveis do banco LOCAL (spec specs/20261128-030000-entrar-servico, plan.md §8, tarefa D1;
// ADR 0018 · D9, D16 e D17; ADR 0019 · D15 e D19). Twelve-Factor III: a configuração chega pelo ambiente do processo.
//
// Uso: node scripts/banco-local.mjs [--com-admin] <comando> [argumentos...]
//   --com-admin  põe também a chave local de administração (SUPABASE_CHAVE_ADMIN_LOCAL). Só para tests/ e e2e/
//                (tasks.md, regras); sem a opção, a variável é TIRADA do ambiente do filho, mesmo se veio de fora.
//
// O que faz, nesta ordem:
//   1. lê `supabase status -o json` (CLI 3.4.0 do projeto; chaves API_URL, PUBLISHABLE_KEY, SECRET_KEY, DB_URL);
//      recusa se o endereço não for 127.0.0.1/localhost (nunca o banco remoto, AGENTS.md §1);
//   2. gera, por execução, SEGREDO_TENTATIVAS e CHAVE_SERVIDOR_BANCO aleatórios (32 bytes, base64url);
//   3. grava como `postgres`, no banco local, o SHA-256 dos bytes UTF-8 da chave do servidor em app.chaves_servidor
//      (ADR 0019 · D15). A tabela aceita no máximo 2 linhas: antes, apaga todas menos a mais nova (uma outra execução
//      em curso, ex.: o servidor do e2e, continua valendo); no fim, apaga a própria;
//   4. roda o comando com SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, SEGREDO_TENTATIVAS, CHAVE_SERVIDOR_BANCO
//      (os nomes de src/data/ambiente.ts) e, com --com-admin, SUPABASE_CHAVE_ADMIN_LOCAL; devolve o código de saída dele.
//
// A chave de assinatura local (D17) NÃO é gerada aqui: o Auth só a lê ao subir, e o `pnpm db:start` já grava uma nova
// a cada execução (ADR 0019 · D19). Aqui só se confere que o arquivo existe e não está vazio, sem lê-lo.
//
// Nada é impresso nem gravado em arquivo: os valores só existem na memória deste processo e no ambiente do filho.
// O SQL leva só o hash (que não é segredo, D15), nunca a chave.
import { spawn, spawnSync } from 'node:child_process'
import { createHash, randomBytes } from 'node:crypto'
import { statSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

const RAIZ = fileURLToPath(new URL('..', import.meta.url))
const SUPABASE = fileURLToPath(new URL('../node_modules/.bin/supabase', import.meta.url))
const ARQUIVO_ASSINATURA = fileURLToPath(new URL('../supabase/signing_keys.json', import.meta.url))
const VARIAVEL_ADMIN = 'SUPABASE_CHAVE_ADMIN_LOCAL'

function parar(motivo) {
  // Só o motivo, nunca um valor (ASVS V7.1.1: segredo fora do registro).
  process.stderr.write(`banco-local: ${motivo}\n`)
  process.exit(1)
}

function local(endereco) {
  try {
    const { hostname } = new URL(endereco)
    return hostname === '127.0.0.1' || hostname === 'localhost'
  } catch {
    return false
  }
}

function supabase(args) {
  // stdout e stderr capturados: a saída do status tem as chaves e a do db query tem linhas do banco.
  return spawnSync(SUPABASE, args, { cwd: RAIZ, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] })
}

/** `supabase db query` no alvo padrão (local; nunca --remote). Uma instrução por chamada (a CLI não aceita várias). */
function consultar(sql) {
  const r = supabase(['db', 'query', sql])
  return r.status === 0 && !r.stdout.includes('"_tag":"Error"')
}

// --- argumentos ---
const args = process.argv.slice(2)
const comAdmin = args[0] === '--com-admin'
if (comAdmin) args.shift()
if (args.length === 0) parar('uso: node scripts/banco-local.mjs [--com-admin] <comando> [argumentos...]')

// --- 1. status do banco local ---
const status = supabase(['status', '-o', 'json'])
if (status.status !== 0) parar('banco local fora do ar; rode `pnpm db:start` antes')
let dados
try {
  dados = JSON.parse(status.stdout)
} catch {
  parar('saída de `supabase status -o json` não é JSON')
}
const { API_URL, PUBLISHABLE_KEY, SECRET_KEY, DB_URL } = dados ?? {}
if (typeof API_URL !== 'string' || typeof PUBLISHABLE_KEY !== 'string' || typeof DB_URL !== 'string') {
  parar('`supabase status -o json` sem API_URL, PUBLISHABLE_KEY ou DB_URL (Auth e Data API de pé?)')
}
if (!local(API_URL) || !local(DB_URL)) parar('o banco não é local; este script só serve ao banco local')
if (comAdmin && typeof SECRET_KEY !== 'string') parar('`supabase status -o json` sem SECRET_KEY')

// Chave de assinatura local (D17): gravada pelo `pnpm db:start`; "[]" (2 bytes) = nenhuma chave.
let tamanho = 0
try {
  tamanho = statSync(ARQUIVO_ASSINATURA).size
} catch {
  // tamanho 0: cai na recusa abaixo
}
if (tamanho <= 2) parar('supabase/signing_keys.json ausente ou vazio; rode `pnpm db:start`')

// --- 2. segredos da execução ---
const aleatorio = () => randomBytes(32).toString('base64url') // 43 caracteres (mínimo 32, src/data/ambiente.ts)
const segredoTentativas = aleatorio()
const chaveServidor = aleatorio()
const hash = createHash('sha256').update(chaveServidor, 'utf8').digest('hex')

// --- 3. hash da chave no banco local, como postgres ---
if (
  !consultar(
    'delete from app.chaves_servidor where hash not in ' +
      '(select hash from app.chaves_servidor order by criada_em desc limit 1)',
  )
) {
  parar('não conseguiu abrir espaço em app.chaves_servidor no banco local')
}
if (!consultar(`insert into app.chaves_servidor (hash) values (decode('${hash}', 'hex'))`)) {
  parar('não conseguiu gravar o hash da chave do servidor no banco local')
}

let limpo = false
function limpar() {
  if (limpo) return
  limpo = true
  consultar(`delete from app.chaves_servidor where hash = decode('${hash}', 'hex')`)
}

// --- 4. comando filho ---
const ambiente = { ...process.env }
delete ambiente[VARIAVEL_ADMIN]
ambiente.SUPABASE_URL = API_URL
ambiente.SUPABASE_PUBLISHABLE_KEY = PUBLISHABLE_KEY
ambiente.SEGREDO_TENTATIVAS = segredoTentativas
ambiente.CHAVE_SERVIDOR_BANCO = chaveServidor
if (comAdmin) ambiente[VARIAVEL_ADMIN] = SECRET_KEY

const [comando, ...resto] = args
const filho = spawn(comando, resto, { cwd: process.cwd(), env: ambiente, stdio: 'inherit' })

for (const sinal of ['SIGINT', 'SIGTERM', 'SIGHUP']) {
  process.on(sinal, () => filho.kill(sinal))
}
filho.on('error', () => {
  limpar()
  parar(`não conseguiu rodar o comando "${comando}"`)
})
filho.on('exit', (codigo, sinal) => {
  limpar()
  if (sinal) {
    process.removeAllListeners(sinal)
    process.kill(process.pid, sinal)
    return
  }
  process.exit(codigo ?? 1)
})
