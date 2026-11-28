#!/usr/bin/env node
// PROPOSTA (destino: .claude/hooks/inicio-de-sessao.mjs; ADR 0003 · T4). Início de sessão (SessionStart), enxuto:
// imprime branch e commit, a próxima tarefa (1º item "livre" de docs/BACKLOG.md, AGENTS.md §5) e a fase
// de docs/STATUS.md. Até 1.500 caracteres; sem regras (as regras são o AGENTS.md). Nunca derruba a sessão:
// em erro, diz o que não conseguiu ler e sai com 0. Não lê o GitHub.
// INICIO_SEM_GIT=1 pula o git (testes). Testes: node .claude/hooks/inicio-de-sessao.test.mjs
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export const LIMITE = 1500;

// Primeiro item da tabela da fila com a situação "livre": "nº · tarefa".
export function proximaTarefa(fila) {
  for (const l of String(fila).split('\n')) {
    const cel = l.trim().replace(/^\||\|$/g, '').split('|').map((c) => c.trim());
    if (cel.length >= 3 && /^\d+$/.test(cel[0]) && /^livre$/i.test(cel[cel.length - 1])) return `${cel[0]} · ${cel[1]}`;
  }
  return '';
}

// Linha "- **Fase:** ..." de docs/STATUS.md.
export function fase(estado) {
  const m = /^\s*-\s*\*\*Fase:?\*\*:?\s*(.+)$/m.exec(String(estado));
  return m ? m[1].trim() : '';
}

export function montar({ branch, commit, fila, estado, naoLidos = [], resumida = false }) {
  const linhas = ['# Início de sessão (trava do projeto)', `- Branch: ${branch || '(desconhecida)'} · commit ${commit || '(desconhecido)'}`];
  const t = proximaTarefa(fila);
  linhas.push(`## Próxima tarefa\n- ${t || '(nenhum item livre achado em docs/BACKLOG.md)'}`);
  const f = fase(estado);
  if (f) linhas.push(`- Fase: ${f}`);
  if (resumida) linhas.push('- Aviso: a conversa foi resumida; releia o AGENTS.md antes de seguir.');
  if (naoLidos.length) linhas.push(`- AVISO do hook: não consegui ler ${naoLidos.join(', ')}.`);
  linhas.push('Regras: AGENTS.md. Só o 1º item livre da fila ou um pedido literal do dono (AGENTS.md §5).');
  const texto = linhas.join('\n');
  return texto.length > LIMITE ? `${texto.slice(0, LIMITE - 1)}…` : texto;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const raiz = process.env.CLAUDE_PROJECT_DIR ?? process.cwd();
    const naoLidos = [];
    const ler = (rel) => { try { return readFileSync(join(raiz, rel), 'utf8'); } catch { naoLidos.push(rel); return ''; } };
    const git = (args) => {
      if (process.env.INICIO_SEM_GIT) return '';
      try { return execFileSync('git', args, { cwd: raiz, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 3000 }).trim(); } catch { return ''; }
    };
    process.stdout.write(`${montar({
      branch: git(['rev-parse', '--abbrev-ref', 'HEAD']),
      commit: git(['rev-parse', '--short', 'HEAD']),
      fila: ler('docs/BACKLOG.md'),
      estado: ler('docs/STATUS.md'),
      naoLidos,
      resumida: process.argv.includes('--resumida'),
    })}\n`);
  } catch (e) {
    process.stdout.write(`AVISO do hook de início de sessão: ${String(e?.message ?? e).slice(0, 100)}\n`);
  }
  process.exit(0);
}
