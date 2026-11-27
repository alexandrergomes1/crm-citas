#!/usr/bin/env node
// Conferências antes de começar (spec: .claude/hooks/TRAVAS.md §5; valores: docs/guias/processo-sdd.md §Planejar, passo 2).
// Roda no começo das skills sdd-planejar e sdd-construir. Barra (saída 1) com o motivo quando:
// - já há 3 PRs de trabalho abertos além do desta branch (Dependabot não conta);
// - outro PR aberto, ou branch com envio nos últimos 7 dias, mexe nos mesmos arquivos;
// - o nome da branch está fora do padrão;
// - na construção, a spec não está aprovada com a linha "Aprovação do dono" (resposta literal, data, link).
// Uso:
//   node scripts/conferir-pedido.mjs planejar [--branch tipo/area-assunto] [--arquivos a,b]
//   node scripts/conferir-pedido.mjs construir --spec specs/NNN-nome [--arquivos a,b]
// Lê o GitHub pelo gh e as branches pela cópia local (faz git fetch antes). Sem conseguir ler: barra.
// Testes: node scripts/conferir-pedido.test.mjs
import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { nomeValido, ehProtegida, PADRAO_TEXTO } from '../.claude/hooks/regras-de-envio.mjs';
import { problemaDaSpec, APROVADA } from '../.claude/hooks/decisao-com-prova.mjs';

export const TETO = 3;
const REPO = 'alexandrergomes1/crm-citas';
// Documentos de controle (docs/guias/processo-sdd.md §Documentos de controle) mudam em quase todo PR, pelo
// organizador: não contam como colisão.
const CONTROLE = ['docs/BACKLOG.md', 'docs/ROADMAP.md', 'docs/STATUS.md', 'docs/OWNER.md'];
const naoConta = (head) => head.startsWith('dependabot/');

// Função pura: devolve a lista de motivos para barrar (vazia = pode seguir).
// prs: [{ numero, head, arquivos }]; recentes: { branch: [arquivos] }; spec: { caminho, texto } | null;
// ler(caminho): texto de um arquivo de decisão citado na linha "Aprovação do dono", ou null.
export function conferir({ modo, branch, arquivos, prs, recentes, spec, ler }) {
  const motivos = [];
  if (!branch || ehProtegida(branch)) motivos.push('sem branch de tarefa: diga o nome com --branch (a tarefa nunca roda na previas nem na main)');
  else if (!nomeValido(branch)) motivos.push(`nome de branch fora do padrão (${branch}); use ${PADRAO_TEXTO}`);

  const outros = prs.filter((p) => p.head !== branch && !naoConta(p.head));
  if (outros.length >= TETO) motivos.push(`já há ${outros.length} PRs de trabalho abertos (${outros.map((p) => `#${p.numero}`).join(', ')}); o teto é ${TETO}`);

  const meus = new Set(arquivos.filter((a) => !CONTROLE.includes(a)));
  const choques = [];
  for (const p of prs) {
    if (p.head === branch || p.head.startsWith('dependabot/')) continue;
    const comum = p.arquivos.filter((a) => meus.has(a));
    if (comum.length) choques.push(`PR #${p.numero} (${p.head}): ${comum.slice(0, 5).join(', ')}`);
  }
  const comPr = new Set(prs.map((p) => p.head));
  for (const [b, lista] of Object.entries(recentes)) {
    if (b === branch || comPr.has(b) || ehProtegida(b)) continue;
    const comum = lista.filter((a) => meus.has(a));
    if (comum.length) choques.push(`branch ${b}: ${comum.slice(0, 5).join(', ')}`);
  }
  if (choques.length) motivos.push(`colisão com trabalho aberto nos mesmos arquivos: ${choques.join(' · ')}`);

  if (modo === 'construir') {
    if (!spec) motivos.push('faltou --spec specs/NNN-nome');
    else if (!APROVADA.test(spec.texto)) motivos.push(`${spec.caminho} não está aprovada (Status diferente de Approved)`);
    else {
      const p = problemaDaSpec(spec.texto, ler, spec.caminho);
      if (p) motivos.push(`${spec.caminho}: ${p}`);
    }
  }
  return motivos;
}

const git = (args) => execFileSync('git', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 30000 }).trim();
const gh = (args) => execFileSync('gh', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 30000 }).trim();
const linhas = (s) => s.split('\n').filter(Boolean);

function prsAbertos() {
  const lista = linhas(gh(['api', '--paginate', `repos/${REPO}/pulls?state=open&per_page=100`, '--jq', '.[] | "\\(.number) \\(.head.ref)"']));
  return lista.map((l) => {
    const [numero, head] = l.split(' ');
    const arquivos = naoConta(head) ? [] : linhas(gh(['api', '--paginate', `repos/${REPO}/pulls/${numero}/files?per_page=100`, '--jq', '.[].filename']));
    return { numero, head, arquivos };
  });
}

// Branches do GitHub com commit nos últimos 7 dias e os arquivos que mudam contra a previas.
function branchesRecentes() {
  const limite = Date.now() / 1000 - 7 * 24 * 3600;
  const out = {};
  for (const l of linhas(git(['for-each-ref', 'refs/remotes/origin', '--format=%(refname:lstrip=3) %(committerdate:unix)']))) {
    const [b, quando] = l.split(' ');
    if (!b || b === 'HEAD' || Number(quando) < limite || naoConta(b)) continue;
    try { out[b] = linhas(git(['diff', '--name-only', `origin/previas...origin/${b}`])); } catch { /* branch sem base comum: ignora */ }
  }
  return out;
}

// Comparação por URL: funciona com espaço, acento e caminho do Windows.
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const args = process.argv.slice(2);
  const modo = args[0];
  const opcao = (nome) => { const i = args.indexOf(nome); return i >= 0 ? args[i + 1] ?? '' : undefined; };
  if (!['planejar', 'construir'].includes(modo)) {
    console.error('Uso: node scripts/conferir-pedido.mjs planejar|construir [--branch nome] [--spec specs/NNN-nome] [--arquivos a,b]');
    process.exit(2);
  }
  try {
    git(['fetch', '--quiet', '--prune', 'origin']);
    const atual = git(['rev-parse', '--abbrev-ref', 'HEAD']);
    const branch = opcao('--branch') ?? atual;
    const daBranch = ehProtegida(branch) || branch !== atual ? [] : linhas(git(['diff', '--name-only', 'origin/previas...HEAD']));
    const arquivos = [...new Set([...daBranch, ...(opcao('--arquivos') ?? '').split(',').map((a) => a.trim()).filter(Boolean)])];
    const caminhoSpec = opcao('--spec');
    const arquivoSpec = caminhoSpec ? join(caminhoSpec.replace(/\/spec\.md$/, ''), 'spec.md') : '';
    const spec = arquivoSpec && existsSync(arquivoSpec) ? { caminho: arquivoSpec, texto: readFileSync(arquivoSpec, 'utf8') } : null;
    if (caminhoSpec && !spec) throw new Error(`não achei ${arquivoSpec}`);
    const motivos = conferir({ modo, branch, arquivos, prs: prsAbertos(), recentes: branchesRecentes(), spec, ler: (c) => (existsSync(c) ? readFileSync(c, 'utf8') : null) });
    if (motivos.length) {
      console.error(`Conferência (${modo}) barrou:`);
      for (const m of motivos) console.error(`  - ${m}`);
      console.error('Pergunte ao dono (molde docs/moldes/pergunta.md) e pare.');
      process.exit(1);
    }
    console.log(`Conferência (${modo}) ok: branch ${branch}, ${arquivos.length} arquivo(s) conferido(s) contra os PRs abertos e as branches dos últimos 7 dias.`);
  } catch (erro) {
    console.error(`Conferência (${modo}) não conseguiu ler o GitHub ou o git (${String(erro?.message ?? erro).slice(0, 160)}). Sem conferência, não siga: relate ao dono.`);
    process.exit(1);
  }
}
