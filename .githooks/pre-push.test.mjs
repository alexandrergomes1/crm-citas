#!/usr/bin/env node
// Testa o gancho pre-push. Uso: node .githooks/pre-push.test.mjs
import { motivos, nomeValido, ehProtegida } from './pre-push.mjs';
import { spawnSync } from 'node:child_process';
import { cpSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const Z = '0'.repeat(40);
const L = 'a'.repeat(40);
const R = 'b'.repeat(40);
const linha = (ref, shaLocal = L, shaRemoto = Z) => `refs/heads/x ${shaLocal} ${ref} ${shaRemoto}`;
const avanca = () => true;
const forca = () => false;
const n = (entrada, anc = avanca) => motivos(entrada, anc).length;
const casos = [
  ['branch nova no padrão passa', n(linha('refs/heads/chore/fundacao-tecnica')), 0],
  ['envio à previas barra', n(linha('refs/heads/previas', L, R)), 1],
  ['envio à main barra', n(linha('refs/heads/main')), 1],
  ['envio à master barra', n(linha('refs/heads/master')), 1],
  ['apagar a main barra', n(linha('refs/heads/main', Z, R)), 1],
  ['nome fora do padrão barra', n(linha('refs/heads/minhabranch')), 1],
  ['nome sem hífen no assunto barra', n(linha('refs/heads/feat/agenda')), 1],
  ['nome com maiúscula barra', n(linha('refs/heads/feat/Agenda-filtro')), 1],
  ['envio forçado barra', n(linha('refs/heads/feat/agenda-filtro', L, R), forca), 1],
  ['avanço normal passa', n(linha('refs/heads/feat/agenda-filtro', L, R)), 0],
  ['apagar branch comum passa', n(linha('refs/heads/velha', Z, R)), 0],
  ['tag passa', n(`refs/tags/v1 ${L} refs/tags/v1 ${Z}`), 0],
  ['várias refs: conta cada uma', n(`${linha('refs/heads/main')}\n${linha('refs/heads/ruim')}`), 2],
  ['entrada vazia passa', n(''), 0],
  ['nomeValido aceita tipo/area-assunto', nomeValido('docs/adr-travas') ? 0 : 1, 0],
  ['ehProtegida aceita refs/heads/', ehProtegida('refs/heads/previas') ? 1 : 0, 1],
];

// O gancho rodando de verdade, numa pasta com espaço e acento: barra a main (saída 1) e deixa passar o certo (saída 0).
{
  const aqui = dirname(fileURLToPath(import.meta.url));
  const pasta = mkdtempSync(join(tmpdir(), 'gancho com espaço-'));
  cpSync(join(aqui, 'pre-push.mjs'), join(pasta, 'pre-push.mjs'));
  const roda = (entrada) => spawnSync(process.execPath, [join(pasta, 'pre-push.mjs')], { input: entrada, encoding: 'utf8' }).status;
  const barra = roda(linha('refs/heads/main'));
  const passa = roda(linha('refs/heads/feat/agenda-filtro'));
  rmSync(pasta, { recursive: true, force: true });
  casos.push(['rodando de verdade, barra a main', barra === 1 ? 1 : 0, 1]);
  casos.push(['rodando de verdade, deixa passar branch certa', passa === 0 ? 0 : 1, 0]);
}

let falhas = 0;
for (const [nome, obtido, esperado] of casos) {
  const ok = obtido === esperado;
  if (!ok) falhas += 1;
  console.log(`${ok ? 'ok   ' : 'FALHA'} ${nome}${ok ? '' : ` (esperado ${esperado}, obtido ${obtido})`}`);
}
console.log(`\n${casos.length - falhas}/${casos.length} casos certos`);
process.exit(falhas ? 1 : 0);
