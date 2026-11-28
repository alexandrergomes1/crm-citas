#!/usr/bin/env node
// PROPOSTA (destino: .claude/hooks/inicio-de-sessao.test.mjs). Uso: node inicio-de-sessao.test.mjs
import { spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { proximaTarefa, fase, montar, LIMITE } from './inicio-de-sessao.mjs';

const fila = `| # | Tarefa | Fonte | Situação |
|---|---|---|---|
| 1 | Base | E8 | feito |
| 2 | Fundação técnica | E14·3 | livre |
| 3 | Banco | E1 | livre |`;
const estado = '## Onde estamos\n- **Fase:** fundação técnica.\n';

const casos = [
  ['acha o 1º item livre', proximaTarefa(fila) === '2 · Fundação técnica'],
  ['fila sem item livre dá vazio', proximaTarefa(fila.replace(/livre/g, 'feito')) === ''],
  ['lê a fase', fase(estado) === 'fundação técnica.'],
  ['monta com a próxima tarefa', montar({ branch: 'feat/x-y', commit: 'abc1234', fila, estado }).includes('## Próxima tarefa\n- 2 · Fundação técnica')],
  ['avisa o que não leu', montar({ fila: '', estado: '', naoLidos: ['docs/BACKLOG.md'] }).includes('AVISO do hook')],
  ['avisa conversa resumida', montar({ fila, estado, resumida: true }).includes('resumida')],
  ['respeita o limite', montar({ fila: `| 1 | ${'x'.repeat(3000)} | E | livre |`, estado }).length <= LIMITE],
];

// O processo de verdade: nos arquivos reais do projeto acha a próxima tarefa; sem arquivos, avisa e sai com 0.
const aqui = dirname(fileURLToPath(import.meta.url));
let raiz = aqui;
while (!existsSync(join(raiz, 'docs', 'BACKLOG.md')) && dirname(raiz) !== raiz) raiz = dirname(raiz);
const roda = (dir) => spawnSync(process.execPath, [join(aqui, 'inicio-de-sessao.mjs')], { encoding: 'utf8', env: { ...process.env, CLAUDE_PROJECT_DIR: dir, INICIO_SEM_GIT: '1' } });
const real = roda(raiz);
casos.push(['nos arquivos reais: saída 0 e próxima tarefa', real.status === 0 && /## Próxima tarefa\n- \d+ · /.test(real.stdout) && !real.stdout.includes('AVISO do hook')]);
const vazia = mkdtempSync(join(tmpdir(), 'inicio sem arquivos-'));
const semNada = roda(vazia);
rmSync(vazia, { recursive: true, force: true });
casos.push(['sem arquivos: saída 0 com aviso', semNada.status === 0 && semNada.stdout.includes('AVISO do hook')]);

let falhas = 0;
for (const [nome, ok] of casos) {
  if (!ok) falhas += 1;
  console.log(`${ok ? 'ok   ' : 'FALHA'} ${nome}`);
}
console.log(`\n${casos.length - falhas}/${casos.length} casos certos`);
process.exit(falhas ? 1 : 0);
