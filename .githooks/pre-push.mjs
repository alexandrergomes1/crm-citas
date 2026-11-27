#!/usr/bin/env node
// Gancho pre-push (spec: .claude/hooks/TRAVAS.md §8): as regras de envio do §4 para quem não é o
// Claude Code. Barra: envio à previas ou à main; envio forçado (o commit remoto não está na
// história do que se envia); branch fora do padrão de nome. Apagar branch comum e enviar tag passam.
// Limite: pode ser pulado (--no-verify) e só vale onde core.hooksPath aponta para .githooks.
// O git manda na entrada uma linha por ref: <ref local> <sha local> <ref remota> <sha remoto>.
// Testes: node .githooks/pre-push.test.mjs
import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { ehProtegida, nomeValido, PADRAO_TEXTO } from '../.claude/hooks/regras-de-envio.mjs';

const ZERO = /^0+$/;

// Função pura: motivos para barrar (vazia = passa). ehAncestral(remoto, local) diz se é avanço normal.
export function motivos(entrada, ehAncestral) {
  const out = [];
  for (const linha of String(entrada).split('\n').map((l) => l.trim()).filter(Boolean)) {
    const [, shaLocal, refRemota, shaRemoto] = linha.split(/\s+/);
    if (!refRemota?.startsWith('refs/heads/')) continue; // tag ou outra ref
    const branch = refRemota.slice('refs/heads/'.length);
    if (ehProtegida(branch)) { out.push(`envio direto à ${branch}: só por PR`); continue; }
    if (ZERO.test(shaLocal)) continue; // apagar branch comum
    if (!nomeValido(branch)) out.push(`branch fora do padrão de nome (${branch}); use ${PADRAO_TEXTO}`);
    if (!ZERO.test(shaRemoto) && !ehAncestral(shaRemoto, shaLocal)) out.push(`envio forçado em ${branch} (o commit remoto não está na história; faça git fetch e merge)`);
  }
  return out;
}

// Comparação por URL: funciona com espaço, acento e caminho do Windows.
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  let entrada = '';
  process.stdin.on('data', (c) => (entrada += c));
  process.stdin.on('end', () => {
    const ehAncestral = (a, b) => {
      try { execFileSync('git', ['merge-base', '--is-ancestor', a, b], { stdio: 'ignore' }); return true; } catch { return false; }
    };
    const m = motivos(entrada, ehAncestral);
    if (m.length) {
      process.stderr.write(`Envio barrado pela trava do projeto (.githooks/pre-push):\n${m.map((x) => `  - ${x}`).join('\n')}\n`);
      process.exit(1);
    }
    process.exit(0);
  });
}
