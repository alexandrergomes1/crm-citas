#!/usr/bin/env node
// Aprovação com prova (spec: .claude/hooks/TRAVAS.md §4). Na CI, compara a branch com a de integração e
// falha (saída 1) quando:
// - uma spec (specs/*/spec.md) diz "Approved" sem a linha "Aprovação do dono" com resposta literal entre
//   aspas, data e link (link da conversa, ou um arquivo de docs/decisoes/ que exista e valha para a spec);
// - a seção "Aprovação do merge" de uma spec está preenchida sem resposta literal, data, link e SHA;
// - uma spec que já está na branch de integração muda a linha "Aprovação do dono", as "Clarifications"
//   ou a "Aprovação do merge" (mudança é spec nova);
// - um arquivo novo em docs/decisoes/ (inclusive a ficha do módulo, AAAA-MM-DD-base-<módulo>.md) não tem
//   pergunta enviada, opção escolhida, resposta literal entre aspas, data e link; "sim" ou "ok" sozinho
//   só passa se a opção escolhida traz o código (ex.: P12·A);
// - um arquivo de decisão já juntado é alterado ou apagado (mudança é decisão nova com "Substitui").
// O registro antigo (docs/decisoes/historico/) e o LEIA.md não são decisões: ficam de fora.
// As funções puras também são usadas pela trava (guarda.mjs) e pelo conferir-pedido.
// Uso: node .claude/hooks/decisao-com-prova.mjs [base]   (base padrão: origin/previas)
// Testes: node .claude/hooks/decisao-com-prova.test.mjs
import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export const PASTA = 'docs/decisoes/';

// Arquivo que é uma decisão (e não o LEIA.md nem o histórico).
export const ehDecisao = (caminho) =>
  caminho.startsWith(PASTA) && caminho.endsWith('.md') && !caminho.startsWith(`${PASTA}historico/`) && caminho !== `${PASTA}LEIA.md`;

// Ficha curta do passado de um módulo: docs/decisoes/AAAA-MM-DD-base-<módulo>.md.
export const ehBase = (caminho) => /(^|\/)\d{4}-\d{2}-\d{2}-base-[a-z0-9]+(-[a-z0-9]+)*\.md$/.test(caminho);

// Texto de exemplo dos moldes: se ficou, o campo está vazio.
const EXEMPLOS = ['texto completo ou resumo fiel', 'palavras próprias"', '"…"', 'AAAA-MM-DD', 'link da mensagem ou do comentário', 'link da conversa', 'ex.: mensagem do dono'];
const SO_CONCORDA = new Set(['ok', 'okay', 'sim', 'yes', 'aceito', 'aceita', 'aceito todas', 'pode seguir', 'recommended', 'recomendado', 'recomendada']);
// Código de opção, como P12·A ou Q1·B.
const CODIGO = /\b[A-Z]{1,3}\d+[a-z]?\s*·\s*[A-Z]\b/;
const DATA = /\b\d{4}-\d{2}-\d{2}\b/;
const LINK = /https?:\/\/\S+/;
const CITADA = /["“]([^"”]+)["”]/;

// Linhas "| Campo | valor |" da tabela do molde, com o nome do campo em minúsculas.
export function campos(texto) {
  const out = {};
  for (const l of String(texto).split('\n')) {
    const m = /^\|\s*([^|]+?)\s*\|\s*(.*?)\s*\|\s*$/.exec(l);
    if (m && !/^-+$/.test(m[1])) out[m[1].toLowerCase()] = m[2];
  }
  return out;
}

const pega = (c, inicio) => {
  const chave = Object.keys(c).find((k) => k.startsWith(inicio));
  return chave ? c[chave].trim() : '';
};
const vazio = (v) => !v || EXEMPLOS.some((e) => v.includes(e)) || /a confirmar/i.test(v);

// Lista de problemas de um arquivo de decisão (vazia = ok).
export function problemasDaDecisao(caminho, texto) {
  const c = campos(texto);
  const p = [];
  if (vazio(pega(c, 'pergunta como foi enviada'))) p.push('falta a pergunta como foi enviada');
  const opcao = pega(c, 'opção escolhida');
  if (vazio(opcao)) p.push('falta a opção escolhida');
  const resposta = pega(c, 'resposta do dono');
  const citada = CITADA.exec(resposta);
  if (vazio(resposta) || !citada) p.push('falta a resposta literal do dono, entre aspas');
  else if (SO_CONCORDA.has(citada[1].trim().toLowerCase().replace(/[.!,;\s]+$/, '')) && !CODIGO.test(opcao)) {
    p.push(`a resposta "${citada[1].trim()}" só vale com o código da opção recomendada em "Opção escolhida" (ex.: P12·A)`);
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(pega(c, 'data'))) p.push('falta a data (AAAA-MM-DD)');
  if (!LINK.test(pega(c, 'prova'))) p.push('falta o link da conversa (campo Prova)');
  if (ehBase(caminho) && vazio(pega(c, 'vale para'))) p.push('a ficha do módulo precisa dizer o módulo em "Vale para"');
  return p;
}

// SHA citado no campo "Vale para" de uma decisão (autorização de publicação), ou '' se não houver.
const SHA = /\bSHA\)?\s*:?\s*`?([0-9a-fA-F]{7,40})\b/;
export function shaAprovado(texto) {
  const m = SHA.exec(pega(campos(texto), 'vale para'));
  return m ? m[1].toLowerCase() : '';
}

// Texto de uma seção "## <título>" (sem o título), até o próximo "## " ou o fim; '' se não existe.
export function secao(texto, titulo) {
  const linhas = String(texto).split('\n');
  const ini = linhas.findIndex((l) => new RegExp(`^##\\s+${titulo}\\s*$`, 'i').test(l.trim()));
  if (ini < 0) return '';
  const fim = linhas.findIndex((l, i) => i > ini && /^##\s/.test(l));
  return linhas.slice(ini + 1, fim < 0 ? undefined : fim).join('\n');
}

// O texto sem a seção "## <título>" (título e corpo), para comparar o resto.
export function semSecao(texto, titulo) {
  const linhas = String(texto).split('\n');
  const ini = linhas.findIndex((l) => new RegExp(`^##\\s+${titulo}\\s*$`, 'i').test(l.trim()));
  if (ini < 0) return String(texto).trimEnd();
  const fim = linhas.findIndex((l, i) => i > ini && /^##\s/.test(l));
  return [...linhas.slice(0, ini), ...(fim < 0 ? [] : linhas.slice(fim))].join('\n').trimEnd();
}

// Linha "Aprovação do dono" da spec (formato da spec completa ou da tabela da spec curta), ou ''.
export function linhaAprovacaoDoDono(texto) {
  for (const l of String(texto).split('\n')) {
    const m = /^\*\*Aprovação do dono\*\*:\s*(.*)$/.exec(l.trim()) ?? /^\|\s*Aprovação do dono\s*\|\s*(.*?)\s*\|\s*$/.exec(l.trim());
    if (m) return m[1].trim();
  }
  return '';
}

const semComentarios = (t) => String(t).replace(/<!--[\s\S]*?-->/g, '');
const literal = (t) => { const m = CITADA.exec(t); return m && !/^\s*\[?resposta literal\]?\s*$/i.test(m[1]) && m[1] !== '…' ? m[1].trim() : ''; };

// Problemas da seção "Aprovação do merge" (vazia = ok). Com shaX, a seção tem de citar esse commit.
export function problemasDaAprovacaoDoMerge(corpo, shaX) {
  const t = semComentarios(corpo);
  const p = [];
  if (!literal(t)) p.push('falta a resposta literal do dono, entre aspas');
  if (!DATA.test(t)) p.push('falta a data (AAAA-MM-DD)');
  if (!LINK.test(t)) p.push('falta o link da conversa');
  const sha = SHA.exec(t)?.[1]?.toLowerCase() ?? '';
  if (!sha) p.push('falta o SHA do commit autorizado');
  else if (shaX && !String(shaX).toLowerCase().startsWith(sha)) p.push(`o SHA autorizado (${sha}) não é o do commit pedido (${String(shaX).slice(0, 7)})`);
  return p;
}

// A seção "Aprovação do merge" está preenchida (não é só o molde)?
const preenchida = (corpo) => { const t = semComentarios(corpo); return Boolean(literal(t)) || SHA.test(t); };

// Y só mexe na seção "Aprovação do merge" de X (e mexe nela).
export const alteraSoAprovacaoDoMerge = (antes, depois) =>
  String(antes) !== String(depois)
  && semSecao(antes, 'Aprovação do merge') === semSecao(depois, 'Aprovação do merge')
  && secao(antes, 'Aprovação do merge').trim() !== secao(depois, 'Aprovação do merge').trim();

// Partes que não mudam numa spec que já está na branch de integração (lista do que mudou).
export function mudancasProibidasNaSpec(antes, depois) {
  const out = [];
  if (linhaAprovacaoDoDono(antes) !== linhaAprovacaoDoDono(depois)) out.push('a linha "Aprovação do dono"');
  if (secao(antes, 'Clarifications').trim() !== secao(depois, 'Clarifications').trim()) out.push('as "Clarifications"');
  if (secao(antes, 'Aprovação do merge').trim() !== secao(depois, 'Aprovação do merge').trim()) out.push('a "Aprovação do merge"');
  return out;
}

// Spec que diz "Approved" (linha **Status**: Approved, ou "| Status | Approved |" na spec curta).
export const APROVADA = /^(\*\*Status\*\*:\s*Approved\s*$|\|\s*Status\s*\|\s*Approved\s*\|)/im;
// Devolve o problema da spec, ou '' se ela não diz Approved ou tem a "Aprovação do dono" completa
// (e a "Aprovação do merge", quando preenchida). ler(caminho) devolve o texto de um arquivo, ou null:
// serve para a linha que cita, como link, uma decisão de docs/decisoes/ que vale para a pasta da spec.
export function problemaDaSpec(texto, ler, pastaDaSpec) {
  if (!APROVADA.test(texto)) return '';
  const aprov = linhaAprovacaoDoDono(texto);
  if (!aprov) return 'diz "Approved" sem a linha "Aprovação do dono" (resposta literal, data, link da conversa)';
  const faltas = [];
  if (!literal(aprov)) faltas.push('resposta literal entre aspas');
  if (!DATA.test(aprov)) faltas.push('data (AAAA-MM-DD)');
  if (!LINK.test(aprov)) {
    const citadas = [...aprov.matchAll(/docs\/decisoes\/[\w./-]+\.md/g)].map((m) => m[0]).filter(ehDecisao);
    // Caminho do Windows (barra invertida) vira barra; a pasta tem de aparecer inteira (não como começo de outra).
    const pasta = String(pastaDaSpec).replace(/\\/g, '/').replace(/\/spec\.md$/, '').replace(/\/$/, '');
    const cita = new RegExp(`${pasta.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(?![\\w-])`);
    const vale = citadas.some((c) => { const t = ler(c); return t !== null && cita.test(pega(campos(t), 'vale para')); });
    if (!vale) faltas.push('link da conversa (ou decisão em docs/decisoes/ que exista e valha para esta spec)');
  }
  if (faltas.length) return `a linha "Aprovação do dono" está sem: ${faltas.join(', ')}`;
  const merge = secao(texto, 'Aprovação do merge');
  if (merge && preenchida(merge)) {
    const p = problemasDaAprovacaoDoMerge(merge);
    if (p.length) return `seção "Aprovação do merge": ${p.join('; ')}`;
  }
  return '';
}

// Comparação por URL: funciona com espaço, acento e caminho do Windows.
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const base = process.argv[2] ?? 'origin/previas';
  const git = (args) => execFileSync('git', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
  const erros = [];
  // --no-renames: arquivo de decisão renomeado aparece como apagado (proibido) + novo.
  const mudancas = git(['diff', '--name-status', '--no-renames', `${base}...HEAD`, '--', PASTA])
    .split('\n').filter(Boolean).map((l) => l.split('\t'));
  for (const [status, caminho] of mudancas) {
    if (!ehDecisao(caminho)) continue;
    if (status !== 'A') { erros.push(`${caminho}: decisão já juntada não se altera nem se apaga; faça uma decisão nova com "Substitui"`); continue; }
    for (const p of problemasDaDecisao(caminho, readFileSync(caminho, 'utf8'))) erros.push(`${caminho}: ${p}`);
  }
  const specs = git(['ls-files', 'specs/*/spec.md']).split('\n').filter(Boolean);
  for (const s of specs) {
    const texto = readFileSync(s, 'utf8');
    const p = problemaDaSpec(texto, (c) => (existsSync(join(process.cwd(), c)) ? readFileSync(join(process.cwd(), c), 'utf8') : null), s);
    if (p) erros.push(`${s}: ${p}`);
    let antes = null;
    try { antes = git(['show', `${base}:${s}`]); } catch { /* spec nova: ainda não está na integração */ }
    if (antes !== null) {
      for (const m of mudancasProibidasNaSpec(antes, texto)) erros.push(`${s}: já está na ${base} e mudou ${m}; mudança é spec nova`);
    }
  }
  if (erros.length) {
    console.error(`Aprovações com prova: ${erros.length} problema(s).`);
    for (const e of erros) console.error(`  - ${e}`);
    console.error('Moldes: .specify/templates/overrides/spec-template.md e docs/moldes/decisao.md. Regras: .claude/hooks/TRAVAS.md §4.');
    process.exit(1);
  }
  console.log(`Aprovações com prova: ${mudancas.filter(([, c]) => ehDecisao(c)).length} decisão(ões) nova(s) e ${specs.length} spec(s) conferidas.`);
}
