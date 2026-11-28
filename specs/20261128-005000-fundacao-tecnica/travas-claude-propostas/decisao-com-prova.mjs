#!/usr/bin/env node
// PROPOSTA (destino: .claude/hooks/decisao-com-prova.mjs; ADR 0003 · T3). Aprovação com prova, na CI.
// Regras: AGENTS.md §3 regra 1 e §8; docs/guias/processo-sdd.md etapas 7 e 13. Compara a branch com a base
// e falha (saída 1) quando:
// - uma spec (specs/*/spec.md) tem "Status: Approved" sem a linha "Aprovação do dono" com fala literal
//   entre aspas, data e link;
// - a linha "Aprovação do merge" está preenchida sem fala literal, data, link e commit (SHA);
// - uma spec que já está na base muda a "Aprovação do dono" ou a "Aprovação do merge" já preenchidas;
// - em docs/decisoes/, um arquivo é apagado, uma linha da tabela já juntada muda ou some (só se acrescenta),
//   ou uma linha nova não tem código e resposta literal entre aspas, ou o arquivo não tem link da conversa.
// As funções puras também servem à trava do Claude Code (guarda.mjs), no merge.
// Uso: node decisao-com-prova.mjs [base]   (base padrão: origin/previas)
// Testes: node decisao-com-prova.test.mjs
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export const PASTA_DECISOES = 'docs/decisoes/';
export const SPEC = /^specs\/[^/]+\/spec\.md$/;

const LITERAL = /["“]([^"”]{2,})["”]/;
const DATA = /\b(\d{2}\/\d{2}\/\d{4}|\d{4}-\d{2}-\d{2})\b/;
const LINK = /https:\/\/\S+/;
// Commit citado depois da palavra "commit" ou "SHA"; um número de 8 algarismos (data AAAAMMDD) não conta.
const SHA = /\b(?:commit|sha)\b[\s:`*()\wà-ú-]*?`?\b(?!\d{8}\b)([0-9a-f]{7,40})\b/i;

// Valor de um campo do cabeçalho da spec: "- **Campo:** valor" (com ou sem o hífen; dois-pontos dentro ou fora).
export function campo(texto, nome) {
  const re = new RegExp(`^\\s*(?:[-*]\\s*)?\\*\\*${nome}:?\\*\\*:?\\s*(.*)$`, 'i');
  for (const l of String(texto).split('\n')) {
    const m = re.exec(l);
    if (m) return m[1].trim();
  }
  return null;
}

export const pendente = (v) => v === null || v === '' || /^\(?\s*pendente\b/i.test(v) || /^[—–-]$/.test(v);
export const aprovada = (texto) => /^approved\b/i.test(campo(texto, 'Status') ?? '');
export const shaCitado = (v) => (SHA.exec(String(v ?? ''))?.[1] ?? '').toLowerCase();

// O que falta numa linha de aprovação (vazia = completa). comSha: a do merge pede o commit.
export function faltasDaAprovacao(valor, comSha = false) {
  const v = String(valor ?? '');
  const f = [];
  const lit = LITERAL.exec(v)?.[1]?.trim() ?? '';
  if (!lit || lit === '…' || lit === '...') f.push('fala literal do dono entre aspas');
  if (!DATA.test(v)) f.push('data');
  if (!LINK.test(v)) f.push('link da conversa');
  if (comSha && !shaCitado(v)) f.push('commit autorizado (SHA)');
  return f;
}

// Problemas de uma spec (lista vazia = ok).
export function problemasDaSpec(texto) {
  const p = [];
  if (aprovada(texto)) {
    const dono = campo(texto, 'Aprovação do dono');
    if (pendente(dono)) p.push('diz "Approved" sem a "Aprovação do dono" (fala literal, data, link)');
    else {
      const f = faltasDaAprovacao(dono);
      if (f.length) p.push(`"Aprovação do dono" sem: ${f.join(', ')}`);
    }
  }
  const merge = campo(texto, 'Aprovação do merge');
  if (!pendente(merge)) {
    if (!aprovada(texto)) p.push('"Aprovação do merge" preenchida numa spec que não está "Approved"');
    const f = faltasDaAprovacao(merge, true);
    if (f.length) p.push(`"Aprovação do merge" sem: ${f.join(', ')}`);
  }
  return p;
}

// Spec que já está na base: aprovação preenchida lá não muda (mudança é spec nova).
export function mudancasProibidasNaSpec(antes, depois) {
  const out = [];
  for (const nome of ['Aprovação do dono', 'Aprovação do merge']) {
    const a = campo(antes, nome);
    if (!pendente(a) && a !== campo(depois, nome)) out.push(`a "${nome}" já gravada`);
  }
  return out;
}

// Só a linha "Aprovação do merge" muda de antes para depois (e muda): é o commit do passo 13.
export function mudaSoAprovacaoDoMerge(antes, depois) {
  const a = String(antes).split('\n');
  const d = String(depois).split('\n');
  if (a.length !== d.length) return false;
  const diferentes = a.map((l, i) => (l === d[i] ? -1 : i)).filter((i) => i >= 0);
  if (diferentes.length !== 1) return false;
  const re = /^\s*(?:[-*]\s*)?\*\*Aprovação do merge:?\*\*/i;
  return re.test(a[diferentes[0]]) && re.test(d[diferentes[0]]);
}

// Linhas de dados das tabelas com a coluna "Resposta literal": [{linha, codigo, resposta}].
export function linhasDeDecisao(texto) {
  const out = [];
  let col = -1;
  for (const l of String(texto).split('\n')) {
    if (!l.trim().startsWith('|')) { col = -1; continue; }
    const cel = l.trim().replace(/^\||\|$/g, '').split('|').map((c) => c.trim());
    if (col < 0) { col = cel.findIndex((c) => /^resposta literal/i.test(c)); continue; }
    if (cel.every((c) => /^:?-+:?$/.test(c))) continue; // separador
    out.push({ linha: l.trimEnd(), codigo: cel[0] ?? '', resposta: cel[col] ?? '' });
  }
  return out;
}

// Problemas de um arquivo de decisões: antes = texto na base (null se é novo), depois = null se apagado.
export function problemasDaDecisao(antes, depois) {
  if (depois === null) return ['arquivo de decisões apagado: decisão gravada não se apaga (mudança é decisão nova)'];
  const p = [];
  const ja = antes === null ? [] : linhasDeDecisao(antes).map((r) => r.linha);
  const agora = linhasDeDecisao(depois);
  const linhasAgora = new Set(agora.map((r) => r.linha));
  for (const l of ja) if (!linhasAgora.has(l)) p.push(`linha já gravada mudou ou sumiu: ${l.slice(0, 60)}`);
  const jaSet = new Set(ja);
  for (const r of agora) {
    if (jaSet.has(r.linha)) continue;
    if (!r.codigo) p.push(`linha nova sem código: ${r.linha.slice(0, 60)}`);
    if (!LITERAL.test(r.resposta)) p.push(`linha nova sem resposta literal entre aspas: ${r.linha.slice(0, 60)}`);
  }
  if (!LINK.test(depois)) p.push('falta o link da conversa');
  return p;
}

// Só roda quando chamado direto (não quando importado).
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const base = process.argv[2] ?? 'origin/previas';
  const git = (args) => execFileSync('git', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
  const naBase = (c) => { try { return git(['show', `${base}:${c}`]); } catch { return null; } };
  const erros = [];
  const mudancas = git(['diff', '--name-status', '--no-renames', `${base}...HEAD`, '--', PASTA_DECISOES])
    .split('\n').filter(Boolean).map((l) => l.split('\t'));
  for (const [status, c] of mudancas) {
    if (!c.endsWith('.md')) continue;
    const depois = status === 'D' ? null : readFileSync(c, 'utf8');
    for (const p of problemasDaDecisao(naBase(c), depois)) erros.push(`${c}: ${p}`);
  }
  const specs = git(['ls-files', 'specs/*/spec.md']).split('\n').filter((s) => SPEC.test(s));
  for (const s of specs) {
    const texto = readFileSync(s, 'utf8');
    for (const p of problemasDaSpec(texto)) erros.push(`${s}: ${p}`);
    const antes = naBase(s);
    if (antes !== null) for (const m of mudancasProibidasNaSpec(antes, texto)) erros.push(`${s}: já está na ${base} e mudou ${m}; mudança é spec nova`);
  }
  if (erros.length) {
    console.error(`Aprovações com prova: ${erros.length} problema(s).`);
    for (const e of erros) console.error(`  - ${e}`);
    console.error('Regras: AGENTS.md §3 regra 1 e §8; docs/adr/0003-travas-do-projeto-antigo.md (T3).');
    process.exit(1);
  }
  console.log(`Aprovações com prova: ${mudancas.length} arquivo(s) de decisão mudado(s) e ${specs.length} spec(s) conferidas.`);
}
