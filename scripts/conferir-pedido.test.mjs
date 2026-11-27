#!/usr/bin/env node
// Testa a função pura de conferir-pedido.mjs, sem rede. Uso: node scripts/conferir-pedido.test.mjs
import { conferir } from './conferir-pedido.mjs';

const pr = (numero, head, arquivos = []) => ({ numero, head, arquivos });
const dec = '| Vale para | spec specs/x |\n';
const base = { modo: 'planejar', branch: 'feat/agenda-filtro', arquivos: ['src/a.ts'], prs: [], recentes: {}, spec: null, ler: () => dec };
const aprovada = { caminho: 'specs/x/spec.md', texto: '**Status**: Approved\n**Aprovação do dono**: "P1·A" · 2026-11-24 · https://claude.ai/code/session_x\n' };
const antiga = { caminho: 'specs/x/spec.md', texto: '**Status**: Approved\nAprovação: docs/decisoes/2026-11-24-p1.md\n' };
const n = (extra) => conferir({ ...base, ...extra }).length;
const casos = [
  ['tudo livre passa', n({}), 0],
  ['branch fora do padrão barra', n({ branch: 'reorganizacao' }), 1],
  ['na previas sem --branch barra', n({ branch: 'previas' }), 1],
  ['branch de decisão (padrão que saiu) barra', n({ branch: 'decisao/2026-11-24-p1' }), 1],
  ['branch reorganizacao-arquivos (exceção que saiu) barra', n({ branch: 'reorganizacao-arquivos' }), 1],
  ['3 PRs de trabalho abertos barra', n({ prs: [pr(1, 'feat/a-b'), pr(2, 'fix/c-d'), pr(3, 'docs/e-f')] }), 1],
  ['2 PRs abertos passa', n({ prs: [pr(1, 'feat/a-b'), pr(2, 'fix/c-d')] }), 0],
  ['Dependabot não conta no teto', n({ prs: [pr(1, 'feat/a-b'), pr(2, 'fix/c-d'), pr(3, 'dependabot/npm/x')] }), 0],
  ['PR decisao/* conta no teto (a exceção saiu)', n({ prs: [pr(1, 'feat/a-b'), pr(2, 'fix/c-d'), pr(4, 'decisao/2026-11-24-p1')] }), 1],
  ['o PR da própria branch não conta no teto', n({ prs: [pr(1, 'feat/a-b'), pr(2, 'fix/c-d'), pr(3, 'feat/agenda-filtro')] }), 0],
  ['PR aberto no mesmo arquivo barra', n({ prs: [pr(1, 'feat/a-b', ['src/a.ts'])] }), 1],
  ['PR aberto em outro arquivo passa', n({ prs: [pr(1, 'feat/a-b', ['src/b.ts'])] }), 0],
  ['documento de controle não é colisão', n({ arquivos: ['docs/BACKLOG.md'], prs: [pr(1, 'feat/a-b', ['docs/BACKLOG.md'])] }), 0],
  ['branch recente no mesmo arquivo barra', n({ recentes: { 'feat/outra-coisa': ['src/a.ts'] } }), 1],
  ['a própria branch recente não conta', n({ recentes: { 'feat/agenda-filtro': ['src/a.ts'] } }), 0],
  ['construir com spec aprovada passa', n({ modo: 'construir', spec: aprovada }), 0],
  ['construir sem --spec barra', n({ modo: 'construir' }), 1],
  ['construir com spec em rascunho barra', n({ modo: 'construir', spec: { caminho: 'specs/x/spec.md', texto: '**Status**: Draft\n' } }), 1],
  ['construir com spec Approved sem a linha "Aprovação do dono" barra', n({ modo: 'construir', spec: antiga }), 1],
  ['construir com a linha sem link barra', n({ modo: 'construir', spec: { caminho: 'specs/x/spec.md', texto: '**Status**: Approved\n**Aprovação do dono**: "P1·A" · 2026-11-24\n' } }), 1],
];
let falhas = 0;
for (const [nome, obtido, esperado] of casos) {
  const ok = obtido === esperado;
  if (!ok) falhas += 1;
  console.log(`${ok ? 'ok   ' : 'FALHA'} ${nome}${ok ? '' : ` (esperado ${esperado}, obtido ${obtido})`}`);
}
console.log(`\n${casos.length - falhas}/${casos.length} casos certos`);
process.exit(falhas ? 1 : 0);
