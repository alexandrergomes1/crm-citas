#!/usr/bin/env node
// Confere o pacote do navegador (spec specs/20261128-030000-entrar-servico, CA-03, RF-04; plan.md §8 e §9; tarefa D2).
// Roda depois de `pnpm build`: o Vite do TanStack Start grava o que vai ao navegador em dist/client e o do servidor em
// dist/server (visto no build de 28/11/2026). Só dist/client é conferido: o servidor PODE falar com o Supabase.
//
// Falha (saída 1) se achar, em qualquer arquivo de dist/client (texto ou binário, lido byte a byte):
//   - "supabase", sem diferença de maiúscula (biblioteca, endereço *.supabase.co, nomes de variável);
//   - formas de chave do Supabase: "sb_publishable_", "sb_secret_", "service_role" e começo de JWT ("eyJhbGciOi");
//   - a porta da Data API local (":54321");
//   - o VALOR de SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, SUPABASE_CHAVE_ADMIN_LOCAL, CHAVE_SERVIDOR_BANCO e
//     SEGREDO_TENTATIVAS, se estiverem no ambiente (ex.: `node scripts/banco-local.mjs pnpm pacote:conferir`).
// Pasta ausente ou vazia também falha (sem pacote não há prova).
// Só imprime o arquivo e o NOME do que achou, nunca o valor (ASVS V7.1.1).
import { readdirSync, readFileSync, statSync } from 'node:fs'
import { join, relative } from 'node:path'
import { fileURLToPath } from 'node:url'

const RAIZ = fileURLToPath(new URL('..', import.meta.url))
const pasta = process.argv[2] ? join(process.cwd(), process.argv[2]) : join(RAIZ, 'dist', 'client')

/** [nome mostrado, texto procurado, sem diferença de maiúscula?] */
const procurados = [
  ['palavra supabase', 'supabase', true],
  ['chave publicável (sb_publishable_)', 'sb_publishable_', false],
  ['chave secreta (sb_secret_)', 'sb_secret_', false],
  ['papel service_role', 'service_role', false],
  ['começo de JWT', 'eyJhbGciOi', false],
  ['porta da Data API local', ':54321', false],
]
for (const nome of [
  'SUPABASE_URL',
  'SUPABASE_PUBLISHABLE_KEY',
  'SUPABASE_CHAVE_ADMIN_LOCAL',
  'CHAVE_SERVIDOR_BANCO',
  'SEGREDO_TENTATIVAS',
]) {
  const valor = process.env[nome]?.trim()
  if (valor) procurados.push([`valor de ${nome}`, valor, false])
}

function arquivos(dir) {
  const lista = []
  for (const item of readdirSync(dir, { withFileTypes: true })) {
    const caminho = join(dir, item.name)
    if (item.isDirectory()) lista.push(...arquivos(caminho))
    else if (item.isFile()) lista.push(caminho)
  }
  return lista
}

let todos
try {
  if (!statSync(pasta).isDirectory()) throw new Error()
  todos = arquivos(pasta)
} catch {
  process.stderr.write(`conferir-pacote: ${relative(RAIZ, pasta) || pasta} não existe; rode \`pnpm build\` antes\n`)
  process.exit(1)
}
if (todos.length === 0) {
  process.stderr.write('conferir-pacote: pasta do pacote vazia; rode `pnpm build` antes\n')
  process.exit(1)
}

const achados = []
for (const arquivo of todos) {
  const bytes = readFileSync(arquivo)
  const texto = bytes.toString('latin1')
  const minusculo = texto.toLowerCase()
  for (const [nome, alvo, semCaixa] of procurados) {
    const onde = semCaixa ? minusculo : texto
    if (onde.includes(semCaixa ? alvo.toLowerCase() : alvo)) achados.push(`${relative(RAIZ, arquivo)}: ${nome}`)
  }
}

if (achados.length > 0) {
  process.stderr.write(`conferir-pacote: o pacote do navegador tem o que não pode (CA-03):\n  ${achados.join('\n  ')}\n`)
  process.exit(1)
}
process.stdout.write(`conferir-pacote: ${todos.length} arquivos em ${relative(RAIZ, pasta)}, nada do Supabase (CA-03)\n`)
