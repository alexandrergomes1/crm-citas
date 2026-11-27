#!/usr/bin/env node
// Testa o gancho pre-push sem git. Uso: node .githooks/pre-push.test.mjs
import { motivos } from './pre-push.mjs';
import { spawnSync } from 'node:child_process';
import { cpSync, mkdtempSync, mkdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const Z = '0000000000000000000000000000000000000000';
const L = 'a'.repeat(40);
const R = 'b'.repeat(40);
const linha = (ref, shaLocal = L, shaRemoto = Z) => `refs/heads/x ${shaLocal} ${ref} ${shaRemoto}`;
const avanca = () => true;
const forca = () => false;
const casos = [
  ['branch nova no padrão passa', motivos(linha('refs/heads/feat/agenda-filtro'), avanca), 0],
  ['branch de decisão (padrão que saiu) barra', motivos(linha('refs/heads/decisao/2026-11-24-p12'), avanca), 1],
  ['branch reorganizacao-arquivos (exceção que saiu) barra', motivos(linha('refs/heads/reorganizacao-arquivos'), avanca), 1],
  ['envio à previas barra', motivos(linha('refs/heads/previas', L, R), avanca), 1],
  ['envio à main barra', motivos(linha('refs/heads/main'), avanca), 1],
  ['apagar a main barra', motivos(linha('refs/heads/main', Z, R), avanca), 1],
  ['nome fora do padrão barra', motivos(linha('refs/heads/minhabranch'), avanca), 1],
  ['envio forçado barra', motivos(linha('refs/heads/feat/agenda-filtro', L, R), forca), 1],
  ['avanço normal passa', motivos(linha('refs/heads/feat/agenda-filtro', L, R), avanca), 0],
  ['apagar branch comum passa', motivos(linha('refs/heads/velha', Z, R), avanca), 0],
  ['tag passa', motivos(`refs/tags/v1 ${L} refs/tags/v1 ${Z}`, avanca), 0],
  ['várias refs: conta cada uma', motivos(`${linha('refs/heads/main')}\n${linha('refs/heads/ruim')}`, avanca), 2],
  ['entrada vazia passa', motivos('', avanca), 0],
];
let falhas = 0;
// O gancho rodando de verdade numa pasta com espaço e acento barra (saída 1), não sai calado.
{
  const aqui = dirname(fileURLToPath(import.meta.url));
  const pasta = mkdtempSync(join(tmpdir(), 'gancho com espaço-'));
  mkdirSync(join(pasta, '.githooks'));
  mkdirSync(join(pasta, '.claude', 'hooks'), { recursive: true });
  cpSync(join(aqui, 'pre-push.mjs'), join(pasta, '.githooks', 'pre-push.mjs'));
  cpSync(join(aqui, '..', '.claude', 'hooks', 'regras-de-envio.mjs'), join(pasta, '.claude', 'hooks', 'regras-de-envio.mjs'));
  const r = spawnSync('node', [join(pasta, '.githooks', 'pre-push.mjs')], { input: linha('refs/heads/main'), encoding: 'utf8' });
  rmSync(pasta, { recursive: true, force: true });
  casos.push(['rodando numa pasta com espaço, barra a main', r.status === 1 ? [1] : [], 1]);
}
for (const [nome, obtido, esperado] of casos) {
  const ok = obtido.length === esperado;
  if (!ok) falhas += 1;
  console.log(`${ok ? 'ok   ' : 'FALHA'} ${nome}${ok ? '' : ` (esperado ${esperado}, obtido ${obtido.length}: ${obtido.join('; ')})`}`);
}
console.log(`\n${casos.length - falhas}/${casos.length} casos certos`);
process.exit(falhas ? 1 : 0);
