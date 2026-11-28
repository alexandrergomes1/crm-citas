#!/usr/bin/env node
// PROPOSTA (destino: .claude/hooks/guarda.test.mjs). Testa a trava sem GitHub (ambiente falso) e, no fim,
// roda o processo de verdade. Uso: node guarda.test.mjs
import { spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { conferir, Barrado } from './guarda.mjs';
import * as dec from './decisao-com-prova.mjs';

// Raiz do projeto: a primeira pasta acima com .githooks/pre-push.mjs (vale em .claude/hooks e na pasta da proposta).
const aqui = dirname(fileURLToPath(import.meta.url));
let raiz = aqui;
while (!existsSync(join(raiz, '.githooks', 'pre-push.mjs')) && dirname(raiz) !== raiz) raiz = dirname(raiz);
const regras = await import(pathToFileURL(join(raiz, '.githooks', 'pre-push.mjs')).href);

const X = '1'.repeat(40);
const Y = '2'.repeat(40);
const LINK = 'https://claude.ai/code/session_teste';
const spec = (merge = '(pendente)', branch = 'feat/agenda-filtro') => `# Spec

- **Status:** Approved
- **Aprovação do dono:** "E30 aprovo" · 28/11/2026 · ${LINK}
- **Aprovação do merge:** ${merge}
- **Branch:** \`${branch}\`
`;
const MERGE = `"E31 ok" · 29/11/2026 · ${LINK} · commit \`${X.slice(0, 7)}\``;
const NOME = 'specs/20261128-000000-x/spec.md';

// gh: mapa "args juntos" -> saída; git: idem. Chave ausente = falha de leitura (null).
function amb({ branch = 'feat/agenda-filtro', gh = {}, git = {} } = {}) {
  return { branch: () => branch, gh: (a) => gh[a.join(' ')] ?? null, git: (a) => git[a.join(' ')] ?? null };
}
const R = 'dono/repo';
function ghMerge({ base = 'previas', rascunho = 'false', pais = X, arquivos = `${NOME}\tmodified`, depois = spec(MERGE), ciX = 'completed success', ciY = 'completed success' } = {}) {
  return {
    [`api repos/${R}/pulls/7 --jq [.base.ref, .head.ref, .head.sha, (.draft | tostring)] | join(" ")`]: `${base} feat/agenda-filtro ${Y} ${rascunho}`,
    [`api repos/${R}/commits/${Y} --jq .parents[].sha`]: pais,
    [`api repos/${R}/compare/${X}...${Y} --jq .status, (.files[] | .filename + "\t" + .status)`]: `ahead\n${arquivos}`,
    [`api -H Accept: application/vnd.github.raw repos/${R}/contents/${NOME}?ref=${X}`]: spec(),
    [`api -H Accept: application/vnd.github.raw repos/${R}/contents/${NOME}?ref=${Y}`]: depois,
    [`api --paginate repos/${R}/commits/${X}/check-runs?per_page=100 --jq .check_runs[] | .status + " " + (.conclusion // "")`]: ciX,
    [`api repos/${R}/commits/${X}/status --jq .state + " " + (.total_count | tostring)`]: 'pending 0',
    [`api --paginate repos/${R}/commits/${Y}/check-runs?per_page=100 --jq .check_runs[] | .status + " " + (.conclusion // "")`]: ciY,
    [`api repos/${R}/commits/${Y}/status --jq .state + " " + (.total_count | tostring)`]: 'pending 0',
  };
}
const merge = (extra = {}) => ({ tool_name: 'mcp__github__merge_pull_request', tool_input: { owner: 'dono', repo: 'repo', pullNumber: 7, expectedHeadSha: Y, ...extra } });
const bash = (command) => ({ tool_name: 'Bash', tool_input: { command } });
const gitWorkflow = {
  'ls-tree -d --name-only HEAD:specs': '20261128-000000-x',
  'show HEAD:specs/20261128-000000-x/spec.md': spec(),
  'show HEAD:specs/20261128-000000-x/plan.md': 'Arquivos: `.github/workflows/ci.yml`',
};

const casos = [
  // Envio
  ['push da branch certa passa', bash('git push -u origin feat/agenda-filtro'), amb(), 'passa'],
  ['push sem refspec na branch certa passa', bash('git push'), amb(), 'passa'],
  ['push à previas barra', bash('git push origin previas'), amb(), 'barra'],
  ['push HEAD:main barra', bash('git push origin HEAD:main'), amb(), 'barra'],
  ['push estando na main barra', bash('git push'), amb({ branch: 'main' }), 'barra'],
  ['push forçado barra', bash('git push --force-with-lease origin feat/agenda-filtro'), amb(), 'barra'],
  ['push -f barra', bash('git push -f'), amb(), 'barra'],
  ['push +refspec barra', bash('git push origin +feat/agenda-filtro'), amb(), 'barra'],
  ['push --no-verify barra', bash('git push --no-verify'), amb(), 'barra'],
  ['push --all barra', bash('git push --all origin'), amb(), 'barra'],
  ['push de nome fora do padrão barra', bash('git push origin minhabranch'), amb(), 'barra'],
  ['push com 2>&1 não esconde o destino', bash('git push origin main 2>&1'), amb(), 'barra'],
  ['commit que cita "push" passa', bash('git commit -m "docs: como fazer push"'), amb(), 'passa'],
  ['ligar core.hooksPath em .githooks passa', bash('git config core.hooksPath .githooks'), amb(), 'passa'],
  ['trocar core.hooksPath barra', bash('git config core.hooksPath /dev/null'), amb(), 'barra'],
  ['git reset --hard barra', bash('git reset --hard origin/previas'), amb(), 'barra'],
  // Merge e API
  ['gh pr merge barra', bash('gh pr merge 7 --squash'), amb(), 'barra'],
  ['API do GitHub com merge barra', bash('gh api repos/dono/repo/pulls/7/merge -X PUT'), amb(), 'barra'],
  ['API escrevendo em git/refs barra', bash('gh api repos/dono/repo/git/refs -f ref=refs/heads/x -f sha=abc'), amb(), 'barra'],
  ['gh api só lendo passa', bash('gh api repos/dono/repo/pulls/7'), amb(), 'passa'],
  ['gh pr create para a main barra', bash('gh pr create --base main --head feat/agenda-filtro'), amb(), 'barra'],
  ['gh pr create para a previas passa', bash('gh pr create --base previas --draft'), amb(), 'passa'],
  // Publicar e banco remoto
  ['wrangler deploy barra', bash('pnpm exec wrangler deploy'), amb(), 'barra'],
  ['wrangler deploy --dry-run passa', bash('pnpm exec wrangler deploy --dry-run'), amb(), 'passa'],
  ['pnpm deploy barra', bash('pnpm run deploy'), amb(), 'barra'],
  ['supabase link barra', bash('pnpm exec supabase link --project-ref abc'), amb(), 'barra'],
  ['supabase db push barra', bash('pnpm exec supabase db push'), amb(), 'barra'],
  ['supabase test db --linked barra', bash('pnpm exec supabase test db --linked'), amb(), 'barra'],
  ['pnpm db:test passa', bash('pnpm db:test'), amb(), 'passa'],
  ['psql remoto barra', bash('psql "postgresql://u@db.exemplo.supabase.co:5432/postgres"'), amb(), 'barra'],
  ['psql local passa', bash('psql postgresql://postgres@127.0.0.1:54322/postgres'), amb(), 'passa'],
  ['gravação no banco pelo MCP barra', { tool_name: 'mcp__supabase__execute_sql', tool_input: {} }, amb(), 'barra'],
  ['Cloudflare pelo MCP barra', { tool_name: 'mcp__cloudflare__execute', tool_input: {} }, amb(), 'barra'],
  // Segredos
  ['cat .env barra', bash('cat .env'), amb(), 'barra'],
  ['cat .env.example passa', bash('cat .env.example'), amb(), 'passa'],
  ['gravar > .env.local barra', bash('echo X=1 > .env.local'), amb(), 'barra'],
  ['Read .env barra', { tool_name: 'Read', tool_input: { file_path: '/p/.env' } }, amb(), 'barra'],
  ['Read README passa', { tool_name: 'Read', tool_input: { file_path: '/p/README.md' } }, amb(), 'passa'],
  ['Write .dev.vars barra', { tool_name: 'Write', tool_input: { file_path: '/p/.dev.vars' } }, amb(), 'barra'],
  ['rm -rf / barra', bash('rm -rf /'), amb(), 'barra'],
  // Migrations e workflows
  ['editar migration já na previas barra', { tool_name: 'Edit', tool_input: { file_path: '/p/supabase/migrations/1_a.sql' } },
    amb({ git: { 'rev-parse --verify --quiet origin/previas': 'abc', 'cat-file -e origin/previas:supabase/migrations/1_a.sql': '' } }), 'barra'],
  ['editar migration nova passa', { tool_name: 'Edit', tool_input: { file_path: '/p/supabase/migrations/2_b.sql' } },
    amb({ git: { 'rev-parse --verify --quiet origin/previas': 'abc' } }), 'passa'],
  ['workflow listado no plano da branch passa', { tool_name: 'Write', tool_input: { file_path: '/p/.github/workflows/ci.yml' } }, amb({ git: gitWorkflow }), 'passa'],
  ['workflow fora do plano barra', { tool_name: 'Write', tool_input: { file_path: '/p/.github/workflows/outro.yml' } }, amb({ git: gitWorkflow }), 'barra'],
  ['workflow de outra branch barra', { tool_name: 'Write', tool_input: { file_path: '/p/.github/workflows/ci.yml' } }, amb({ branch: 'feat/outra-coisa', git: gitWorkflow }), 'barra'],
  ['rm de workflow pela linha de comando sem plano barra', bash('rm .github/workflows/outro.yml'), amb({ git: gitWorkflow }), 'barra'],
  // MCP do GitHub
  ['MCP grava na previas barra', { tool_name: 'mcp__github__push_files', tool_input: { owner: 'd', repo: 'r', branch: 'previas', files: [] } }, amb(), 'barra'],
  ['MCP grava na branch certa passa', { tool_name: 'mcp__github__create_or_update_file', tool_input: { owner: 'd', repo: 'r', branch: 'feat/agenda-filtro', path: 'docs/x.md' } }, amb(), 'passa'],
  ['MCP abre PR para a main barra', { tool_name: 'mcp__github__create_pull_request', tool_input: { base: 'main', head: 'feat/agenda-filtro' } }, amb(), 'barra'],
  ['MCP merge automático barra', { tool_name: 'mcp__github__enable_pr_auto_merge', tool_input: {} }, amb(), 'barra'],
  // Merge pelo MCP
  ['merge com tudo certo passa', merge(), amb({ gh: ghMerge() }), 'passa'],
  ['merge sem expectedHeadSha barra', merge({ expectedHeadSha: undefined }), amb({ gh: ghMerge() }), 'barra'],
  ['merge com SHA antigo barra', merge({ expectedHeadSha: X }), amb({ gh: ghMerge() }), 'barra'],
  ['merge na main barra (publicar)', merge(), amb({ gh: ghMerge({ base: 'main' }) }), 'barra'],
  ['merge de rascunho barra', merge(), amb({ gh: ghMerge({ rascunho: 'true' }) }), 'barra'],
  ['merge com último commit de merge (2 pais) barra', merge(), amb({ gh: ghMerge({ pais: `${X}\n${'3'.repeat(40)}` }) }), 'barra'],
  ['merge com outro arquivo no último commit barra', merge(), amb({ gh: ghMerge({ arquivos: 'src/x.ts\tmodified' }) }), 'barra'],
  ['merge com autorização sem fala literal barra', merge(), amb({ gh: ghMerge({ depois: spec(`29/11/2026 · ${LINK} · commit ${X.slice(0, 7)}`) }) }), 'barra'],
  ['merge com autorização de outro commit barra', merge(), amb({ gh: ghMerge({ depois: spec(`"ok" · 29/11/2026 · ${LINK} · commit abcdef1`) }) }), 'barra'],
  ['merge com spec de outra branch barra', merge(), amb({ gh: ghMerge({ depois: spec(MERGE, 'feat/outra-coisa') }) }), 'barra'],
  ['merge com CI vermelha no autorizado barra', merge(), amb({ gh: ghMerge({ ciX: 'completed success\ncompleted failure' }) }), 'barra'],
  ['merge com CI pendente no autorizado barra', merge(), amb({ gh: ghMerge({ ciX: 'in_progress ' }) }), 'barra'],
  ['merge com CI pendente no último passa', merge(), amb({ gh: ghMerge({ ciY: 'queued ' }) }), 'passa'],
  ['merge sem conseguir ler o GitHub barra', merge(), amb(), 'barra'],
];

let falhas = 0;
const conta = (nome, ok, detalhe = '') => {
  if (!ok) falhas += 1;
  console.log(`${ok ? 'ok   ' : 'FALHA'} ${nome}${ok ? '' : ` ${detalhe}`}`);
};
for (const [nome, input, ambiente, esperado] of casos) {
  let obtido = 'passa';
  let motivo = '';
  try { conferir(input, ambiente, regras, dec); } catch (e) {
    if (!(e instanceof Barrado)) { obtido = 'erro'; motivo = e.message; } else { obtido = 'barra'; motivo = e.message; }
  }
  conta(nome, obtido === esperado, `(esperado ${esperado}, obtido ${obtido}: ${motivo})`);
}

// O processo de verdade: barra com saída 2, passa com 0, e barra se não achar as regras.
const roda = (input, dir = raiz) => spawnSync(process.execPath, [join(aqui, 'guarda.mjs')], {
  input: typeof input === 'string' ? input : JSON.stringify(input), encoding: 'utf8', env: { ...process.env, CLAUDE_PROJECT_DIR: dir },
}).status;
conta('processo: push à main sai com 2', roda(bash('git push origin main')) === 2);
conta('processo: ler o README sai com 0', roda({ tool_name: 'Read', tool_input: { file_path: 'README.md' } }) === 0);
conta('processo: entrada ilegível comum sai com 0', roda('isto não é json') === 0);
conta('processo: entrada ilegível de banco sai com 2', roda('execute_sql {') === 2);
const vazia = mkdtempSync(join(tmpdir(), 'guarda sem regras-'));
conta('processo: sem .githooks/pre-push.mjs, barra (saída 2)', roda({ tool_name: 'Read', tool_input: { file_path: 'README.md' } }, vazia) === 2);
rmSync(vazia, { recursive: true, force: true });

const total = casos.length + 5;
console.log(`\n${total - falhas}/${total} casos certos`);
process.exit(falhas ? 1 : 0);
