#!/usr/bin/env node
// Testa a trava sem tocar em banco nem em git: alimenta guarda.mjs pela entrada padrão.
// Precisa da referência local origin/previas (para o caso de migration já integrada).
// Uso: node .claude/hooks/guarda.test.mjs   (sai com 1 se algum caso falhar)
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { readdirSync, readFileSync, mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';

const aqui = dirname(fileURLToPath(import.meta.url));
const guarda = join(aqui, 'guarda.mjs');
const raiz = join(aqui, '..', '..');
// Uma migration que existe de verdade no repositório, para os casos de edição.
const pastaMigrations = join(raiz, 'supabase', 'migrations');
let migrationExistente = '';
try {
  const nome = readdirSync(pastaMigrations).find((f) => f.endsWith('.sql'));
  if (nome) migrationExistente = join(pastaMigrations, nome);
} catch { /* sem a pasta: os casos abaixo falham e avisam */ }
const migrationNova = join(pastaMigrations, '29990101000000_ainda_nao_existe.sql');

const BARRA = 2;
const PASSA = 0;
const bash = (command) => JSON.stringify({ tool_name: 'Bash', tool_input: { command } });
const arquivo = (tool_name, file_path) => JSON.stringify({ tool_name, tool_input: { file_path } });
const mcp = (tool_name, tool_input = { query: 'select 1' }) => JSON.stringify({ tool_name, tool_input });

// Merge (TRAVAS.md §1). X = commit que o dono autorizou; Y = commit que só grava a autorização na spec.
const X = 'abc1234def5678abc1234def5678abc1234def56';
const Y = 'fedcba9876543210fedcba9876543210fedcba98';
const SPEC = 'specs/20261125-agenda-filtro/spec.md';
const LINK = 'https://claude.ai/code/session_x';
const MOLDE_MERGE = '- PR nº: · Commit autorizado (SHA): · Resposta do dono (literal): "" · Data: · Link da conversa:';
const specAntes = `# Spec\n\n**Status**: Approved\n**Aprovação do dono**: "P1·A" · 2026-11-24 · ${LINK}\n\n## Clarifications\n- Q: a? → A: B ("B")\n\n`
  + `## Aprovação do merge\n<!-- molde -->\n${MOLDE_MERGE}\n\n## Seção do tipo\ntexto\n`;
const registro = (sha = X.slice(0, 7), resposta = '"M3·A, pode juntar"') =>
  `- PR nº: 12 · Commit autorizado (SHA): ${sha} · Resposta do dono (literal): ${resposta} · Data: 2026-11-25 · Link da conversa: ${LINK}`;
const specDepois = (linha = registro()) => specAntes.replace(MOLDE_MERGE, linha);
const specComProva = specDepois(`${registro()}\n- Prova local: pnpm typecheck ok · pnpm lint ok · pnpm test 120/120 · pnpm test:e2e não verificado`);
// CI que não rodou por falta de minutos: verificações como o GitHub as devolve (id, status, conclusion), o
// status comum e as anotações de cada verificação (null = não deu para ler). extra troca anotações; mais, soma verificações.
const COBRANCA = 'The job was not started because recent account payments have failed or your spending limit needs to be increased.';
const semMinutos = (extra = {}, mais = []) => ({
  runs: [{ id: 1, status: 'completed', conclusion: 'success' }, { id: 2, status: 'completed', conclusion: 'failure' }, { id: 4, status: 'completed', conclusion: 'failure' }, ...mais],
  status: { state: 'pending', total: 0 },
  anotacoes: { 2: [COBRANCA], 4: ['Spending limit reached'], ...extra },
});
// Decisão de publicação sem spec (molde docs/moldes/decisao.md).
const publicacaoSemSpec = (sha = X.slice(0, 7)) => `| | |\n|---|---|\n| Pergunta como foi enviada | Publicar o PR nº 12 |\n| Opção escolhida | U1·A |\n`
  + `| Resposta do dono (literal) | "U1·A" |\n| Data | 2026-11-25 |\n| Prova | ${LINK} |\n| Vale para | PR nº 12 · SHA ${sha} |\n`;
const DEC = 'docs/decisoes/2026-11-25-u1.md';
// Autorização de publicação: arquivo próprio, num PR pequeno à previas (TRAVAS.md §1).
const DEC_PUB = 'docs/decisoes/2026-11-25-publicacao-pr-12.md';
const D = '1111111111222222222233333333334444444444'; // último commit do PR da autorização de publicação
const comando = (resto) => `gh pr ${'merge'} ${resto}`;

function casosDeMerge() {
  const mcpMerge = (extra = {}) => mcp('mcp__github__merge_pull_request', { owner: 'o', repo: 'r', pullNumber: 12, expectedHeadSha: Y, merge_method: 'squash', ...extra });
  const pubMerge = (extra = {}) => mcpMerge({ merge_method: 'merge', ...extra });
  const noPr = (arquivos) => ({ [`previas...${X}`]: { status: 'ahead', arquivos } });
  const tarefa = (extra = {}) => ({ pr: { numero: '12', base: 'previas', head: 'feat/x-y', sha: Y, rotulos: ['aguardando-merge'] },
    pais: { [Y]: [X] }, compare: { status: 'ahead', arquivos: [[SPEC, 'modified']] },
    comparacoes: noPr([[SPEC, 'added'], ['src/a.ts', 'added']]),
    conteudo: { [`${X}:${SPEC}`]: specAntes, [`${Y}:${SPEC}`]: specDepois() }, ci: { [X]: 'verde', [Y]: 'pendente' }, ...extra });
  const pr = (extra = {}) => ({ numero: '12', base: 'previas', head: 'feat/x-y', sha: Y, rotulos: ['aguardando-merge'], ...extra });
  const publicacao = (extra = {}) => tarefa({ pr: pr({ base: 'main', head: 'previas' }), ...extra });
  const pubDecisao = (texto = publicacaoSemSpec(), situacao = 'added', nome = DEC_PUB) =>
    publicacao({ compare: { status: 'ahead', arquivos: [[nome, situacao]] }, conteudo: { [`${Y}:${nome}`]: texto } });
  // PR pequeno à previas só com a autorização de publicação do PR nº 12 (cujo último commit é X).
  const prDaAutorizacao = (extra = {}) => ({
    pr: { numero: '13', base: 'previas', head: 'docs/publicacao-pr-12', sha: D, rotulos: [] },
    prs: { 12: { numero: '12', base: 'main', head: 'previas', sha: X, rotulos: ['aguardando-merge'] } },
    comparacoes: { [`previas...${D}`]: { status: 'ahead', arquivos: [[DEC_PUB, 'added']] } },
    conteudo: { [`${D}:${DEC_PUB}`]: publicacaoSemSpec() }, ci: { [D]: 'verde' }, ...extra });
  const mergeDaAutorizacao = (extra = {}) => mcpMerge({ pullNumber: 13, expectedHeadSha: D, ...extra });
  const conteudo = (depois) => ({ conteudo: { [`${X}:${SPEC}`]: specAntes, [`${Y}:${SPEC}`]: depois } });
  const B = 'feat/agenda-trabalho';
  return [
    ['merge com rótulo, Y filho único de X, só a "Aprovação do merge" e CI verde', mcpMerge(), PASSA, B, tarefa()],
    ['merge com CI verde também em Y', mcpMerge(), PASSA, B, tarefa({ ci: { [X]: 'verde', [Y]: 'verde' } })],
    ['merge sem expectedHeadSha', mcpMerge({ expectedHeadSha: undefined }), BARRA, B, tarefa()],
    ['merge com expectedHeadSha diferente do último commit', mcpMerge({ expectedHeadSha: X }), BARRA, B, tarefa()],
    ['merge com expectedHeadSha curto', mcpMerge({ expectedHeadSha: Y.slice(0, 7) }), BARRA, B, tarefa()],
    ['merge sem o rótulo aguardando-merge', mcpMerge(), BARRA, B, tarefa({ pr: pr({ rotulos: [] }) })],
    ['merge com Y de dois pais (merge commit)', mcpMerge(), BARRA, B, tarefa({ pais: { [Y]: [X, 'eee0000'] } })],
    ['merge sem conseguir ler os pais de Y', mcpMerge(), BARRA, B, tarefa({ pais: {} })],
    ['merge com Y que mexe em outro arquivo', mcpMerge(), BARRA, B, tarefa({ compare: { status: 'ahead', arquivos: [[SPEC, 'modified'], ['src/a.ts', 'modified']] } })],
    ['merge com Y que mexe em outra seção da spec', mcpMerge(), BARRA, B, tarefa(conteudo(specDepois().replace('texto', 'outro')))],
    ['merge com Y que muda arquivo fora de specs/*/spec.md', mcpMerge(), BARRA, B, tarefa({ compare: { status: 'ahead', arquivos: [['docs/a.md', 'modified']] } })],
    ['merge com a seção citando outro commit', mcpMerge(), BARRA, B, tarefa(conteudo(specDepois(registro('9999999'))))],
    ['merge com a seção sem resposta literal', mcpMerge(), BARRA, B, tarefa(conteudo(specDepois(registro(X.slice(0, 7), 'pode')).replace('""', '')))],
    ['merge sem conseguir ler a spec', mcpMerge(), BARRA, B, tarefa({ conteudo: {} })],
    ['merge com CI vermelha em X', mcpMerge(), BARRA, B, tarefa({ ci: { [X]: 'vermelha', [Y]: 'pendente' } })],
    ['merge com CI pendente em X', mcpMerge(), BARRA, B, tarefa({ ci: { [X]: 'pendente', [Y]: 'pendente' } })],
    ['merge sem CI em X', mcpMerge(), BARRA, B, tarefa({ ci: { [X]: 'sem', [Y]: 'pendente' } })],
    ['merge com verificação falhando em Y', mcpMerge(), BARRA, B, tarefa({ ci: { [X]: 'verde', [Y]: 'vermelha' } })],
    ['merge sem conseguir ler a CI', mcpMerge(), BARRA, B, tarefa({ ci: {} })],
    // CI sem minutos do GitHub (aviso de cobrança): vale a prova local gravada na "Aprovação do merge".
    ['merge com CI sem minutos e a linha "Prova local" passa', mcpMerge(), PASSA, B, tarefa({ ...conteudo(specComProva), ci: { [X]: semMinutos(), [Y]: semMinutos() } })],
    ['merge com CI sem minutos (situação pronta) e a linha "Prova local" passa', mcpMerge(), PASSA, B, tarefa({ ...conteudo(specComProva), ci: { [X]: 'sem-minutos', [Y]: 'sem-minutos' } })],
    ['merge com CI sem minutos sem a linha "Prova local" barra', mcpMerge(), BARRA, B, tarefa({ ci: { [X]: semMinutos(), [Y]: semMinutos() } })],
    ['merge com CI sem minutos e "Prova local" vazia barra', mcpMerge(), BARRA, B, tarefa({ ...conteudo(specDepois(`${registro()}\n- Prova local:`)), ci: { [X]: semMinutos(), [Y]: semMinutos() } })],
    ['merge com falha real junto da falha de cobrança barra', mcpMerge(), BARRA, B, tarefa({ ...conteudo(specComProva), ci: { [X]: semMinutos({ 2: ['Process completed with exit code 1.'] }), [Y]: semMinutos() } })],
    ['cobrança + \'Process completed with exit code 1\' no mesmo job: barra', mcpMerge(), BARRA, B, tarefa({ ...conteudo(specComProva), ci: { [X]: semMinutos({ 2: [COBRANCA, 'Process completed with exit code 1.'] }), [Y]: semMinutos() } })],
    ['merge com anotações ilegíveis barra', mcpMerge(), BARRA, B, tarefa({ ...conteudo(specComProva), ci: { [X]: semMinutos({ 2: null }), [Y]: semMinutos() } })],
    ['merge com falha de cobrança e verificação pendente barra', mcpMerge(), BARRA, B, tarefa({ ...conteudo(specComProva), ci: { [X]: semMinutos({}, [{ id: 3, status: 'in_progress', conclusion: '' }]), [Y]: semMinutos() } })],
    ['merge com falha de cobrança e status externo falhando barra', mcpMerge(), BARRA, B, tarefa({ ...conteudo(specComProva), ci: { [X]: { ...semMinutos(), status: { state: 'failure', total: 1 } }, [Y]: semMinutos() } })],
    ['merge com falha sem anotação barra', mcpMerge(), BARRA, B, tarefa({ ...conteudo(specComProva), ci: { [X]: semMinutos({ 2: [] }), [Y]: semMinutos() } })],
    ['publicação com CI sem minutos continua barrando', pubMerge(), BARRA, B, { ...pubDecisao(), ci: { [X]: 'sem-minutos', [Y]: 'sem-minutos' } }],
    ['PR em rascunho não se funde', mcpMerge(), BARRA, B, tarefa({ pr: pr({ rascunho: true }) })],
    ['publicação com a autorização em docs/decisoes/…-publicacao-pr-12.md citando X', pubMerge(), PASSA, B, pubDecisao()],
    ['publicação com a autorização na spec (caminho que saiu) barra', pubMerge(), BARRA, B, publicacao()],
    ['publicação com decisão de outro nome barra', pubMerge(), BARRA, B, pubDecisao(publicacaoSemSpec(), 'added', DEC)],
    ['publicação com a autorização de outro PR barra', pubMerge(), BARRA, B, pubDecisao(publicacaoSemSpec(), 'added', 'docs/decisoes/2026-11-25-publicacao-pr-99.md')],
    ['publicação, decisão citando outro commit', pubMerge(), BARRA, B, pubDecisao(publicacaoSemSpec('9999999'))],
    ['publicação, decisão incompleta', pubMerge(), BARRA, B, pubDecisao(publicacaoSemSpec().replace(LINK, 'conversa'))],
    ['publicação, decisão alterada (não nova)', pubMerge(), BARRA, B, pubDecisao(publicacaoSemSpec(), 'modified')],
    ['tarefa não aceita decisão nova no lugar da spec', mcpMerge(), BARRA, B, { ...pubDecisao(), pr: pr() }],
    // Método de merge: previas = squash (tarefa); main = merge commit (publicação).
    ['merge de tarefa sem método barra', mcpMerge({ merge_method: undefined }), BARRA, B, tarefa()],
    ['merge de tarefa com merge commit barra', mcpMerge({ merge_method: 'merge' }), BARRA, B, tarefa()],
    ['merge de tarefa com rebase barra', mcpMerge({ merge_method: 'rebase' }), BARRA, B, tarefa()],
    ['publicação com squash barra', pubMerge({ merge_method: 'squash' }), BARRA, B, pubDecisao()],
    ['publicação sem método barra', pubMerge({ merge_method: undefined }), BARRA, B, pubDecisao()],
    // A spec do commit Y tem de ser de uma pasta adicionada ou alterada no próprio PR.
    ['merge com Y numa spec que o PR não mexe barra', mcpMerge(), BARRA, B, tarefa({ comparacoes: noPr([['src/a.ts', 'modified']]) })],
    ['merge com Y numa spec cuja pasta vizinha o PR mexe barra', mcpMerge(), BARRA, B, tarefa({ comparacoes: noPr([['specs/20261125-agenda-filtro-2/spec.md', 'added']]) })],
    ['merge com Y na spec de pasta alterada pelo plano passa', mcpMerge(), PASSA, B, tarefa({ comparacoes: noPr([['specs/20261125-agenda-filtro/plan.md', 'modified']]) })],
    ['merge sem conseguir ler os arquivos do PR barra', mcpMerge(), BARRA, B, tarefa({ comparacoes: {} })],
    // PR pequeno à previas com a autorização de publicação (única exceção de PR de decisão).
    ['PR da autorização de publicação passa', mergeDaAutorizacao(), PASSA, B, prDaAutorizacao()],
    ['PR da autorização com merge commit barra', mergeDaAutorizacao({ merge_method: 'merge' }), BARRA, B, prDaAutorizacao()],
    ['PR da autorização com expectedHeadSha errado barra', mergeDaAutorizacao({ expectedHeadSha: X }), BARRA, B, prDaAutorizacao()],
    ['PR da autorização citando outro commit barra', mergeDaAutorizacao(), BARRA, B, prDaAutorizacao({ conteudo: { [`${D}:${DEC_PUB}`]: publicacaoSemSpec('9999999') } })],
    ['PR da autorização incompleta barra', mergeDaAutorizacao(), BARRA, B, prDaAutorizacao({ conteudo: { [`${D}:${DEC_PUB}`]: publicacaoSemSpec().replace(LINK, 'conversa') } })],
    ['PR da autorização com o PR de publicação sem rótulo barra', mergeDaAutorizacao(), BARRA, B, prDaAutorizacao({ prs: { 12: { numero: '12', base: 'main', head: 'previas', sha: X, rotulos: [] } } })],
    ['PR da autorização para PR que não é de publicação barra', mergeDaAutorizacao(), BARRA, B, prDaAutorizacao({ prs: { 12: { numero: '12', base: 'previas', head: 'feat/x-y', sha: X, rotulos: ['aguardando-merge'] } } })],
    ['PR da autorização com outro arquivo junto barra', mergeDaAutorizacao(), BARRA, B, prDaAutorizacao({ comparacoes: { [`previas...${D}`]: { status: 'ahead', arquivos: [[DEC_PUB, 'added'], ['src/a.ts', 'modified']] } } })],
    ['PR da autorização com CI vermelha barra', mergeDaAutorizacao(), BARRA, B, prDaAutorizacao({ ci: { [D]: 'vermelha' } })],
    ['PR da autorização com CI pendente barra', mergeDaAutorizacao(), BARRA, B, prDaAutorizacao({ ci: { [D]: 'pendente' } })],
    ['PR da autorização em rascunho barra', mergeDaAutorizacao(), BARRA, B, prDaAutorizacao({ pr: { numero: '13', base: 'previas', head: 'docs/publicacao-pr-12', sha: D, rotulos: [], rascunho: true } })],
    ['PR de trabalho na produção', mcpMerge(), BARRA, B, tarefa({ pr: pr({ base: 'main' }) })],
    ['PR de branch decisao/* passa pela trava inteira', mcpMerge(), BARRA, B, tarefa({ pr: pr({ head: 'decisao/2026-11-24-p12', rotulos: [] }) })],
    ['PR em outra base não é conferido', mcpMerge(), PASSA, B, tarefa({ pr: pr({ base: 'feat/outra-base' }) })],
    ['merge sem conseguir conferir o PR', mcpMerge(), BARRA, B, 'erro'],
    ['merge sem número', mcp('mcp__github__merge_pull_request', { owner: 'o', repo: 'r', expectedHeadSha: Y }), BARRA, B, tarefa()],
    ['merge pelo gh, mesmo com tudo certo', bash(comando('12 --squash')), BARRA, B, tarefa()],
    ['merge pelo gh sem número', bash(comando('--squash')), BARRA, B, tarefa()],
    ['merge automático pelo gh', bash(comando('12 --auto --squash')), BARRA, B, tarefa()],
    ['merge automático pelo MCP', mcp('mcp__github__enable_pr_auto_merge', { owner: 'o', repo: 'r', pullNumber: 12 }), BARRA],
    ['merge pela API GraphQL', bash('gh api graphql -f query="mutation { mergePullRequest(input: {}) { clientMutationId } }"'), BARRA],
    ['merge pela API com curl', bash('curl -X PUT https://api.github.com/repos/a/b/pulls/12/merge'), BARRA],
    ['merge pela API direta', bash('gh api -X PUT repos/a/b/pulls/12/merge'), BARRA],
  ];
}

// Envio com o rótulo aguardando-merge (TRAVAS.md §1): só um commit Y sobre X que só grava a autorização.
function casosDeEnvio() {
  const B = 'feat/x-y';
  const comRotulo = (local = {}) => ({ prDaBranch: { numero: '12', sha: X, rotulos: ['aguardando-merge'] },
    local: { sha: Y, pais: [X], arquivos: [['M', SPEC]], arquivosDoPr: [SPEC, 'src/a.ts'], conteudo: { [`${X}:${SPEC}`]: specAntes, [`${Y}:${SPEC}`]: specDepois() }, ...local } });
  const mcpGrava = (tool, extra = {}) => mcp(`mcp__github__${tool}`, { owner: 'o', repo: 'r', branch: B, path: 'docs/a.md', ...extra });
  const rotulo = { prDaBranch: { numero: '12', sha: X, rotulos: ['aguardando-merge'] } };
  const conteudo = (depois) => ({ conteudo: { [`${X}:${SPEC}`]: specAntes, [`${Y}:${SPEC}`]: depois } });
  return [
    ['envio em branch sem PR', bash('git push -u origin feat/x-y'), PASSA, B, {}],
    ['envio em branch com PR sem o rótulo', bash('git push'), PASSA, B, { prDaBranch: { numero: '12', sha: X, rotulos: [] } }],
    ['envio com rótulo: o commit que só grava a autorização passa', bash('git push'), PASSA, B, comRotulo()],
    ['envio com rótulo: refspec HEAD:branch com o commit certo passa', bash('git push origin HEAD:feat/x-y'), PASSA, B, comRotulo()],
    ['envio com rótulo: nada novo (Y = X) passa', bash('git push'), PASSA, B, comRotulo({ sha: X })],
    ['envio com rótulo: commit que mexe em código barra', bash('git push'), BARRA, B, comRotulo({ arquivos: [['M', SPEC], ['M', 'src/a.ts']] })],
    ['envio com rótulo: commit que mexe em outra seção da spec barra', bash('git push origin feat/x-y'), BARRA, B, comRotulo(conteudo(specDepois().replace('texto', 'outro')))],
    ['envio com rótulo: dois commits depois de X barra', bash('git push'), BARRA, B, comRotulo({ pais: ['ccc1111'] })],
    ['envio com rótulo: autorização citando outro commit barra', bash('git push'), BARRA, B, comRotulo(conteudo(specDepois(registro('9999999'))))],
    ['envio com rótulo sem conseguir ler o git local barra', bash('git push'), BARRA, B, comRotulo({ sha: null })],
    ['envio sem conseguir ler o PR da branch barra', bash('git push'), BARRA, B, 'erro'],
    ['envio com rótulo: spec de pasta que o PR não mexe barra', bash('git push'), BARRA, B, comRotulo({ arquivosDoPr: ['src/a.ts'] })],
    ['envio com rótulo sem conseguir ler os arquivos do PR barra', bash('git push'), BARRA, B, comRotulo({ arquivosDoPr: null })],
    // Gravação pelo MCP numa branch cujo PR tem o rótulo: barrada sempre (o commit Y vai pelo git).
    ['MCP push_files em branch com rótulo barra', mcpGrava('push_files', { files: [{ path: SPEC, content: 'x' }] }), BARRA, B, rotulo],
    ['MCP create_or_update_file em branch com rótulo barra', mcpGrava('create_or_update_file'), BARRA, B, rotulo],
    ['MCP delete_file em branch com rótulo barra', mcpGrava('delete_file'), BARRA, B, rotulo],
    ['MCP create_or_update_file em branch com PR sem rótulo passa', mcpGrava('create_or_update_file'), PASSA, B, { prDaBranch: { numero: '12', sha: X, rotulos: [] } }],
    ['MCP create_or_update_file sem conseguir ler o PR barra', mcpGrava('create_or_update_file'), BARRA, B, 'erro'],
  ];
}

// A IA não tira o rótulo aguardando-merge (TRAVAS.md §1): só o dono destrava.
function casosDeRotulo() {
  const R = 'aguardando-merge';
  const comRotulo = { issue: { rotulos: [R, 'outro'] } };
  const semRotulo = { issue: { rotulos: ['outro'] } };
  const issue = (extra) => mcp('mcp__github__issue_write', { method: 'update', owner: 'o', repo: 'r', issue_number: 12, ...extra });
  const B = 'feat/agenda-trabalho';
  return [
    ['gh pr edit --remove-label do rótulo barra', bash(`gh pr edit 12 --remove-label ${R}`), BARRA],
    ['gh pr edit --remove-label entre aspas barra', bash(`gh pr edit 12 --remove-label "${R}"`), BARRA],
    ['gh pr edit --remove-label= com lista barra', bash(`gh pr edit 12 --remove-label=outro,${R}`), BARRA],
    ['gh issue edit --remove-label do rótulo barra', bash(`gh issue edit 12 --remove-label ${R}`), BARRA],
    ['gh label delete do rótulo barra', bash(`gh label delete ${R} --yes`), BARRA],
    ['gh label edit do rótulo barra', bash(`gh label edit ${R} --name outro`), BARRA],
    ['gh api DELETE no rótulo do PR barra', bash(`gh api -X DELETE repos/o/r/issues/12/labels/${R}`), BARRA],
    ['gh api DELETE de todos os rótulos barra', bash('gh api -X DELETE repos/o/r/issues/12/labels'), BARRA],
    ['gh api PUT trocando os rótulos sem ele barra', bash('gh api -X PUT repos/o/r/issues/12/labels -f "labels[]=outro"'), BARRA],
    ['curl DELETE no rótulo barra', bash(`curl -X DELETE https://api.github.com/repos/o/r/issues/12/labels/${R}`), BARRA],
    ['GraphQL que tira rótulos barra', bash('gh api graphql -f query="mutation { removeLabelsFromLabelable(input: {}) { clientMutationId } }"'), BARRA],
    ['GraphQL que limpa os rótulos barra', bash('gh api graphql -f query="mutation { clearLabelsFromLabelable(input: {}) { clientMutationId } }"'), BARRA],
    ['GraphQL updatePullRequest com labelIds barra', bash('gh api graphql -f query="mutation { updatePullRequest(input: {pullRequestId: \\"P\\", labelIds: []}) { clientMutationId } }"'), BARRA],
    ['GraphQL updateIssue com labelIds barra', bash('gh api graphql -f query="mutation { updateIssue(input: {id: \\"I\\", labelIds: [\\"L\\"]}) { clientMutationId } }"'), BARRA],
    ['GraphQL updatePullRequest só com título passa', bash('gh api graphql -f query="mutation { updatePullRequest(input: {pullRequestId: \\"P\\", title: \\"x\\"}) { clientMutationId } }"'), PASSA],
    ['gh api PATCH no issue trocando os rótulos barra', bash('gh api -X PATCH repos/o/r/issues/12 -f "labels[]=outro"'), BARRA],
    ['gh api PATCH no PR trocando os rótulos barra', bash('gh api --method PATCH repos/o/r/pulls/12 -f labels[]=outro'), BARRA],
    ['curl PATCH no issue trocando os rótulos barra', bash(`curl -X PATCH https://api.github.com/repos/o/r/issues/12 -d '{"labels":["outro"]}'`), BARRA],
    ['gh api PATCH no PR só com título passa', bash('gh api -X PATCH repos/o/r/pulls/12 -f title=x'), PASSA],
    ['gh pr edit --add-label do rótulo passa', bash(`gh pr edit 12 --add-label ${R}`), PASSA],
    ['gh pr edit --remove-label de outro rótulo passa', bash('gh pr edit 12 --remove-label outro'), PASSA],
    ['gh api POST acrescentando o rótulo passa', bash(`gh api -X POST repos/o/r/issues/12/labels -f "labels[]=${R}"`), PASSA],
    ['gh api DELETE de outro rótulo passa', bash('gh api -X DELETE repos/o/r/issues/12/labels/outro'), PASSA],
    ['MCP troca os rótulos sem ele, num PR que o tem, barra', issue({ labels: ['outro'] }), BARRA, B, comRotulo],
    ['MCP troca os rótulos mantendo ele passa', issue({ labels: [R] }), PASSA, B, comRotulo],
    ['MCP troca os rótulos de PR sem ele passa', issue({ labels: ['outro'] }), PASSA, B, semRotulo],
    ['MCP atualiza sem mexer nos rótulos passa', issue({ title: 'x' }), PASSA, B, comRotulo],
    ['MCP troca os rótulos sem conseguir ler barra', issue({ labels: [] }), BARRA, B, 'erro'],
    ['MCP cria issue com rótulos passa', mcp('mcp__github__issue_write', { method: 'create', owner: 'o', repo: 'r', title: 'x', labels: ['bug'] }), PASSA],
    ['MCP apaga o rótulo do repositório barra', mcp('mcp__github__label_write', { method: 'delete', owner: 'o', repo: 'r', name: R }), BARRA],
    ['MCP renomeia o rótulo barra', mcp('mcp__github__label_write', { method: 'update', owner: 'o', repo: 'r', name: R, new_name: 'x' }), BARRA],
    ['MCP cria o rótulo passa', mcp('mcp__github__label_write', { method: 'create', owner: 'o', repo: 'r', name: R }), PASSA],
    ['MCP tira o rótulo de um PR barra', mcp('mcp__github__remove_label', { owner: 'o', repo: 'r', issue_number: 12, label: R }), BARRA],
  ];
}

// Workflows (TRAVAS.md §3): Write/Edit (e gravação pelo MCP) em .github/workflows/** só se estiver nos "Arquivos
// permitidos" de uma spec aprovada da branch (Status Approved e "Aprovação do dono" completa), lida do commit.
const SPEC_OK = '# Spec\n\n**Status**: Approved\n**Branch**: `chore/ci-cache`\n**Aprovação do dono**: "P1·A" · 2026-11-25 · https://claude.ai/code/session_x\n';
const PLANO = '# Plano\n\n## Arquivos permitidos\n\n- `.github/workflows/ci.yml` (editar)\n\n## Riscos\n- `.github/workflows/e2e.yml` citado fora da lista\n';
function repoComPlano(spec, { origem = true } = {}) {
  const r = mkdtempSync(join(tmpdir(), 'guarda-plano-'));
  const g = (...a) => execFileSync('git', ['-c', 'user.email=t@t', '-c', 'user.name=t', '-c', 'commit.gpgsign=false', ...a], { cwd: r, stdio: 'ignore' });
  g('init', '-q', '-b', 'chore/ci-cache');
  mkdirSync(join(r, 'specs', '20261125-ci-cache'), { recursive: true });
  writeFileSync(join(r, 'specs', '20261125-ci-cache', 'spec.md'), spec);
  writeFileSync(join(r, 'specs', '20261125-ci-cache', 'plan.md'), PLANO);
  g('add', '-A');
  g('commit', '-q', '-m', 'x');
  // O MCP grava na branch do GitHub: a trava lê a spec só de refs/remotes/origin/<branch>.
  if (origem) g('update-ref', 'refs/remotes/origin/chore/ci-cache', 'HEAD');
  return r;
}
const raizComPlano = repoComPlano(SPEC_OK);
const raizRascunho = repoComPlano(SPEC_OK.replace('Approved', 'Draft'));
const raizSemAprovacao = repoComPlano(SPEC_OK.replace(/\*\*Aprovação do dono\*\*.*\n/, ''));
// Plano mudado só na cópia de trabalho (sem commit): não vale.
const raizSoNaCopia = repoComPlano(SPEC_OK);
writeFileSync(join(raizSoNaCopia, 'specs', '20261125-ci-cache', 'plan.md'), PLANO.replace('ci.yml` (editar)', 'ci.yml` (editar)\n- `.github/workflows/e2e.yml` (editar)'));
// Sem origin/<branch> (só a branch local): o MCP não confia na cópia local.
const raizSoLocal = repoComPlano(SPEC_OK, { origem: false });
// Branch local à frente da origin, com o plano listando e2e.yml só no commit local: para o MCP não vale.
const raizLocalAFrente = repoComPlano(SPEC_OK);
writeFileSync(join(raizLocalAFrente, 'specs', '20261125-ci-cache', 'plan.md'), PLANO.replace('ci.yml` (editar)', 'ci.yml` (editar)\n- `.github/workflows/e2e.yml` (editar)'));
execFileSync('git', ['-c', 'user.email=t@t', '-c', 'user.name=t', '-c', 'commit.gpgsign=false', 'commit', '-q', '-am', 'y'], { cwd: raizLocalAFrente, stdio: 'ignore' });
function casosDeWorkflow() {
  const R = raizComPlano;
  const wf = (tool, nome, r = R) => JSON.stringify({ tool_name: tool, tool_input: { file_path: join(r, '.github', 'workflows', nome) } });
  const C = 'chore/ci-cache';
  const mcpWf = (tool, extra) => mcp(`mcp__github__${tool}`, { owner: 'o', repo: 'r', branch: C, ...extra });
  return [
    ['Edit de workflow com spec em rascunho barra', wf('Edit', 'ci.yml', raizRascunho), BARRA, C, {}, raizRascunho],
    ['Edit de workflow com spec Approved sem "Aprovação do dono" barra', wf('Edit', 'ci.yml', raizSemAprovacao), BARRA, C, {}, raizSemAprovacao],
    ['Edit de workflow que só a cópia de trabalho do plano lista barra', wf('Edit', 'e2e.yml', raizSoNaCopia), BARRA, C, {}, raizSoNaCopia],
    ['Edit de workflow que o plano commitado lista passa', wf('Edit', 'ci.yml', raizSoNaCopia), PASSA, C, {}, raizSoNaCopia],
    ['MCP create_or_update_file de workflow da lista passa', mcpWf('create_or_update_file', { path: '.github/workflows/ci.yml' }), PASSA, C, {}, R],
    ['MCP create_or_update_file de workflow fora da lista barra', mcpWf('create_or_update_file', { path: '.github/workflows/e2e.yml' }), BARRA, C, {}, R],
    ['MCP push_files com workflow fora da lista barra', mcpWf('push_files', { files: [{ path: 'docs/a.md' }, { path: '.github/workflows/e2e.yml' }] }), BARRA, C, {}, R],
    ['MCP push_files com workflow da lista passa', mcpWf('push_files', { files: [{ path: '.github/workflows/ci.yml' }] }), PASSA, C, {}, R],
    ['MCP delete_file de workflow fora da lista barra', mcpWf('delete_file', { path: '.github/workflows/e2e.yml' }), BARRA, C, {}, R],
    ['MCP de workflow sem origin/<branch> (só a branch local) barra', mcpWf('create_or_update_file', { path: '.github/workflows/ci.yml' }), BARRA, C, {}, raizSoLocal],
    ['MCP de workflow que só o commit local lista (origin atrás) barra', mcpWf('create_or_update_file', { path: '.github/workflows/e2e.yml' }), BARRA, C, {}, raizLocalAFrente],
    ['Edit de workflow que o commit local lista passa', wf('Edit', 'e2e.yml', raizLocalAFrente), PASSA, C, {}, raizLocalAFrente],
    ['MCP de workflow numa branch sem spec barra', mcp('mcp__github__create_or_update_file', { owner: 'o', repo: 'r', branch: 'feat/outra-coisa', path: '.github/workflows/ci.yml' }), BARRA, C, {}, R],
    ['Edit de workflow nos "Arquivos permitidos" do plano', wf('Edit', 'ci.yml'), PASSA, C, {}, R],
    ['Write de workflow nos "Arquivos permitidos" do plano', wf('Write', 'ci.yml'), PASSA, C, {}, R],
    ['Edit de workflow fora dos "Arquivos permitidos"', wf('Edit', 'e2e.yml'), BARRA, C, {}, R],
    ['Write de workflow novo fora da lista', wf('Write', 'novo.yml'), BARRA, C, {}, R],
    ['MultiEdit de workflow fora da lista', wf('MultiEdit', 'e2e.yml'), BARRA, C, {}, R],
    ['Edit de workflow numa branch sem spec', wf('Edit', 'ci.yml'), BARRA, 'feat/outra-coisa', {}, R],
    ['Edit de workflow no Windows fora da lista', arquivo('Edit', 'D:\\repo\\.github\\workflows\\e2e.yml'), BARRA, C, {}, R],
    ['gravar workflow pela linha de comando fora da lista', bash('echo x > .github/workflows/e2e.yml'), BARRA, C, {}, R],
    ['sed -i em workflow fora da lista', bash('sed -i s/a/b/ .github/workflows/e2e.yml'), BARRA, C, {}, R],
    ['apagar workflow fora da lista', bash('git rm .github/workflows/e2e.yml'), BARRA, C, {}, R],
    ['sed -i em workflow da lista', bash('sed -i s/a/b/ .github/workflows/ci.yml'), PASSA, C, {}, R],
    ['ler workflow passa', bash('cat .github/workflows/e2e.yml'), PASSA, C, {}, R],
    ['Read de workflow passa', arquivo('Read', join(R, '.github', 'workflows', 'e2e.yml')), PASSA, C, {}, R],
    ['Edit de .github fora de workflows passa', arquivo('Edit', join(R, '.github', 'dependabot.yml')), PASSA, C, {}, R],
  ];
}

const casos = [
  // Banco pelo MCP
  ['MCP apply_migration', mcp('mcp__Supabase-Crm-Agenda__apply_migration'), BARRA],
  ['MCP execute_sql', mcp('mcp__Supabase-Crm-Agenda__execute_sql'), BARRA],
  ['MCP apply_migration de outro servidor', mcp('mcp__outro__apply_migration'), BARRA],
  ['MCP de leitura (list_tables)', mcp('mcp__Supabase-Crm-Agenda__list_tables'), PASSA],
  ['MCP de leitura (get_advisors)', mcp('mcp__Supabase-Crm-Agenda__get_advisors'), PASSA],
  // GitHub pelo MCP
  ['MCP push_files no main', mcp('mcp__github__push_files', { branch: 'main' }), BARRA],
  ['MCP push_files em previas', mcp('mcp__github__push_files', { branch: 'previas' }), BARRA],
  ['MCP create_or_update_file em previas', mcp('mcp__github__create_or_update_file', { branch: 'refs/heads/previas' }), BARRA],
  ['MCP delete_file no main', mcp('mcp__github__delete_file', { branch: 'main' }), BARRA],
  ['MCP PR de branch de trabalho com base main', mcp('mcp__github__create_pull_request', { base: 'main', head: 'minha-branch' }), BARRA],
  ['MCP push_files em branch de trabalho', mcp('mcp__github__push_files', { branch: 'claude/minha-branch' }), PASSA],
  ['MCP PR com base previas', mcp('mcp__github__create_pull_request', { base: 'previas', head: 'minha-branch' }), PASSA],
  ['MCP PR de publicação previas → main', mcp('mcp__github__create_pull_request', { base: 'main', head: 'previas' }), PASSA],
  ['MCP de leitura do GitHub', mcp('mcp__github__list_pull_requests', {}), PASSA],
  // Entrada ilegível
  ['ilegível citando apply_migration', '{"tool_name":"mcp__x__apply_migration", quebrado', BARRA],
  ['ilegível citando execute_sql', 'execute_sql {{{', BARRA],
  ['ilegível sem relação com banco', '{quebrado', PASSA],
  ['entrada vazia', '', PASSA],
  ['JSON nulo', 'null', PASSA],
  // Git
  ['push no main', bash('git push origin main'), BARRA],
  ['push em previas', bash('git push origin previas'), BARRA],
  ['push no main com opção no meio (git -C)', bash('git -C . push origin main'), BARRA],
  ['push no main por refspec', bash('git push origin HEAD:main'), BARRA],
  ['push no main com +', bash('git push origin +main'), BARRA],
  ['push no main entre aspas', bash('git push origin "main"'), BARRA],
  ['push forçado', bash('git push --force origin minha-branch'), BARRA],
  ['push forçado com opção no meio', bash('git -c x=y push -f origin b'), BARRA],
  ['push com --force-with-lease', bash('git push --force-with-lease origin b'), BARRA],
  ['push forçado por refspec com +', bash('git push origin +minha-branch'), BARRA],
  ['push em branch de trabalho', bash('git push -u origin claude/minha-branch'), PASSA],
  ['push em branch com "main" no nome', bash('git push origin feature/main-fix'), PASSA],
  ['push em branch terminada em -f', bash('git push origin feat/x-f'), PASSA],
  ['mensagem de commit citando o main', bash('git commit -m "regra do main"'), PASSA],
  ['fetch da branch de integração', bash('git fetch origin previas'), PASSA],
  // Deploy e banco pela linha de comando
  ['deploy manual', bash('wrangler deploy'), BARRA],
  ['deploy com --dry-run só em outro trecho', bash('wrangler deploy && echo --dry-run'), BARRA],
  ['deploy de ensaio', bash('wrangler deploy --dry-run'), PASSA],
  ['supabase db push', bash('supabase db push'), BARRA],
  ['supabase db execute', bash('supabase db execute --file x.sql'), BARRA],
  ['supabase db reset remoto', bash('supabase db reset --linked'), BARRA],
  ['supabase --linked antes do subcomando', bash('supabase --linked db reset'), BARRA],
  ['supabase migration up remoto', bash('supabase migration up --db-url postgres://x'), BARRA],
  ['aplicar migration à mão', bash('bash scripts/db/apply-dev.sh'), BARRA],
  ['aplicar migration à mão, depois de outro comando', bash('cd repo && ./scripts/db/apply-dev.sh'), BARRA],
  ['ler o script de aplicar migration', bash('grep -n begin scripts/db/apply-dev.sh'), PASSA],
  ['ver trecho do script de aplicar migration', bash('sed -n 85,100p scripts/db/apply-dev.sh'), PASSA],
  ['psql em banco remoto por URL', bash('psql postgresql://postgres:x@db.abc.supabase.co:5432/postgres -c "select 1"'), BARRA],
  ['psql com variável de endereço do banco', bash('psql "$SUPABASE_DB_URL" -f x.sql'), BARRA],
  ['supabase db reset local', bash('supabase db reset'), PASSA],
  ['psql em banco local', bash('psql postgresql://postgres:postgres@localhost:5432/postgres -c "select 1"'), PASSA],
  ['psql local sem endereço', bash('psql -X -q -f x.sql'), PASSA],
  ['replay local das migrations', bash('pnpm db:verify'), PASSA],
  // Arquivos
  ['rm -rf na raiz', bash('rm -rf / '), BARRA],
  ['rm -fr na raiz', bash('rm -fr /'), BARRA],
  ['rm -rf na pasta atual', bash('rm -rf ./'), BARRA],
  ['rm -rf em tudo', bash('rm -rf *'), BARRA],
  ['rm -rf numa pasta específica', bash('rm -rf ./dist'), PASSA],
  ['rm -rf em node_modules', bash('rm -rf node_modules'), PASSA],
  ['editar .env', arquivo('Write', '/repo/.env'), BARRA],
  ['editar .env.example', arquivo('Edit', '/repo/.env.example'), PASSA],
  ['editar migration já integrada', arquivo('Edit', migrationExistente), BARRA],
  ['sobrescrever migration já integrada', arquivo('Write', migrationExistente), BARRA],
  ['criar migration nova', arquivo('Write', migrationNova), PASSA],
  ['corrigir migration criada no próprio PR', arquivo('Edit', migrationNova), PASSA],
  ['editar arquivo comum', arquivo('Edit', '/repo/src/domain/x.ts'), PASSA],
  ['comando comum', bash('pnpm test'), PASSA],
  ['git reset --hard', bash('git reset --hard origin/previas'), BARRA],
  ['git reset leve', bash('git reset HEAD~1'), PASSA],
  ['ler .env pelo Read', arquivo('Read', '/repo/.env'), BARRA],
  ['ler .env.local pelo Read', arquivo('Read', '/repo/.env.local'), BARRA],
  ['ler .env.example pelo Read', arquivo('Read', '/repo/.env.example'), PASSA],
  ['ler arquivo comum pelo Read', arquivo('Read', '/repo/src/a.ts'), PASSA],
  ['buscar dentro do .env pelo Grep', JSON.stringify({ tool_name: 'Grep', tool_input: { pattern: 'KEY', path: '/repo/.env' } }), BARRA],
  ['Grep com filtro .env*', JSON.stringify({ tool_name: 'Grep', tool_input: { pattern: 'KEY', glob: '**/.env*' } }), BARRA],
  ['Grep comum', JSON.stringify({ tool_name: 'Grep', tool_input: { pattern: 'env', path: '/repo/src' } }), PASSA],
  ['Glob procurando .env', JSON.stringify({ tool_name: 'Glob', tool_input: { pattern: '**/.env' } }), BARRA],
  ['Glob comum', JSON.stringify({ tool_name: 'Glob', tool_input: { pattern: '**/*.ts' } }), PASSA],
  ['push de branch fora do padrão', bash('git push -u origin minhabranch'), BARRA],
  ['push de branch sem área-assunto', bash('git push -u origin feat/agenda'), BARRA],
  ['push de branch decisao/* (padrão que saiu)', bash('git push -u origin decisao/2026-11-24-p12'), BARRA],
  ['push de decisão sem data', bash('git push -u origin decisao/p12-agenda'), BARRA],
  ['push de HEAD para nome fora do padrão', bash('git push origin HEAD:outra'), BARRA],
  ['push de HEAD para nome no padrão', bash('git push origin HEAD:fix/agenda-hora'), PASSA],
  ['push sem destino numa branch fora do padrão', bash('git push'), BARRA, 'reorganizacao'],
  ['push com redirecionamento da saída', bash('git push origin feat/x-y 2>&1 | tail -2'), PASSA],
  ['push com 2>&1 antes da main', bash('git push origin 2>&1 main'), BARRA],
  ['push com 2>&1 antes da previas', bash('git push origin 2>&1 previas'), BARRA],
  ['push com 2>&1 antes de HEAD:main', bash('git push origin 2>&1 HEAD:main'), BARRA],
  ['push com &> antes da previas', bash('git push origin &>/dev/null previas'), BARRA],
  ['push com 2>/dev/null antes da previas', bash('git push origin 2>/dev/null previas'), BARRA],
  ['push com > solto antes da main', bash('git push origin > log main'), BARRA],
  ['push com 2>&1 e branch no padrão', bash('git push origin feat/x-y 2>&1'), PASSA],
  ['push com 2>/dev/null e nome fora do padrão', bash('git push origin 2>/dev/null fora-do-padrao'), BARRA],
  ['push com </dev/null e nome fora do padrão', bash('git push origin </dev/null fora-do-padrao'), BARRA],
  ['push com curinga de refspec', bash("git push origin 2>/dev/null 'refs/heads/*:refs/heads/*'"), BARRA],
  ['git config push.default', bash('git config push.default matching'), BARRA],
  ['git config remote.origin.push', bash("git config remote.origin.push 'refs/heads/*:refs/heads/*'"), BARRA],
  ['git config remote.origin.mirror', bash('git config remote.origin.mirror true'), BARRA],
  ['git config comum passa', bash('git config user.name x'), PASSA],
  ['nl do .env', bash('nl .env'), BARRA],
  ['diff do .env', bash('diff .env /dev/null'), BARRA],
  ['curinga que casa .env', bash('cat .*env'), PASSA], // limite conhecido (TRAVAS.md §3): curinga fica de fora
  ['curinga .en?', bash('cat .en?'), PASSA], // limite conhecido (TRAVAS.md §3)
  ['node lendo o .env', bash('node -e "require(\'fs\').readFileSync(\'.env\')"'), PASSA], // limite conhecido (TRAVAS.md §3)
  ['grep recursivo sem excluir o .env', bash('grep -rn SUPABASE .'), PASSA], // limite conhecido (TRAVAS.md §3): busca recursiva fica de fora
  ['grep recursivo excluindo o .env', bash("grep -rn --exclude='.env*' SUPABASE ."), PASSA],
  ['grep comum num arquivo', bash('grep -n x src/a.ts'), PASSA],
  ['MCP de gravação com repository', mcp('mcp__x__push_files', { repository: 'a/b' }), BARRA],
  ['push com <& antes da main', bash('git push origin <&0 main'), BARRA],
  ['push com 0<&- antes da previas', bash('git push origin 0<&- previas'), BARRA],
  ['push com >| antes da main', bash('git push origin >|log main'), BARRA],
  ['push com 2>| antes da previas', bash('git push origin 2>|log previas'), BARRA],
  ['push com >| e branch no padrão', bash('git push origin feat/x-y >|log'), PASSA],
  ['push com >& (sem número) antes da previas', bash('git push origin >&/dev/null previas'), BARRA],
  ['push com >&log antes da main', bash('git push origin >&log main'), BARRA],
  ['push com ">& log" antes da main', bash('git push origin >& log main'), BARRA],
  ['teste de arquivo com [ ] passa', bash('[ -f package.json ] && echo sim'), PASSA],
  ['[[ ]] passa', bash('[[ -n "$X" ]] && echo sim'), PASSA],
  ['ls * passa', bash('ls *'), PASSA],
  ['git add de pasta com * passa', bash('git add src/*'), PASSA],
  ['commit que cita .env no texto passa', bash('git commit -m "docs: explica o .env no README"'), PASSA],
  ['echo .env no .gitignore passa', bash('echo .env >> .gitignore'), PASSA],
  ['grep recursivo comum passa', bash('grep -rn foo src'), PASSA],
  ['push com redirecionamento para arquivo', bash('git push origin feat/x-y >log.txt'), PASSA],
  ['push da branch reorganizacao-arquivos (exceção que saiu)', bash('git push'), BARRA, 'reorganizacao-arquivos'],
  ['push de tag não confere nome', bash('git push origin refs/tags/v1'), PASSA],
  ['apagar branch remota não confere nome', bash('git push origin --delete velha'), PASSA],
  ['API REST muda a ref da previas', bash('gh api -X PATCH repos/o/r/git/refs/heads/previas -f sha=abc'), BARRA],
  ['API REST grava arquivo na main', bash('gh api -X PUT repos/o/r/contents/x -f branch=main -f content=eA=='), BARRA],
  ['API REST apaga a previas', bash('gh api -X DELETE repos/o/r/git/refs/heads/previas'), BARRA],
  ['API REST com campos (POST implícito) em refs', bash('gh api repos/o/r/git/refs -f ref=refs/heads/main -f sha=abc'), BARRA],
  ['curl gravando na API em refs', bash('curl -X PATCH https://api.github.com/repos/o/r/git/refs/heads/main -d x'), BARRA],
  ['API REST lendo uma ref passa', bash('gh api repos/o/r/git/refs/heads/previas'), PASSA],
  ['API REST criando comentário', bash('gh api -X POST repos/o/r/issues/1/comments -f body=oi'), PASSA],
  ['push de todas as branches', bash('git push --all origin'), BARRA],
  ['push pulando o gancho', bash('git push --no-verify origin feat/x-y'), BARRA],
  ['push trocando o gancho', bash('git -c core.hooksPath=/dev/null push origin feat/x-y'), BARRA],
  ['push com git entre aspas na previas', bash("'git' push origin HEAD:previas"), BARRA],
  ['cat do .env', bash('cat .env'), BARRA],
  ['source do .env', bash('source .env && echo $X'), BARRA],
  ['grep no .env.local', bash('grep -r KEY .env.local'), BARRA],
  ['cat do .dev.vars', bash('cat .dev.vars'), BARRA],
  ['cat do .env.production.local', bash('cat .env.production.local'), BARRA],
  ['cat do .dev.vars.staging', bash('cat .dev.vars.staging'), BARRA],
  ['ler o .env por redirecionamento', bash('wc -l < .env'), BARRA],
  ['cp do .env.example para .env', bash('cp .env.example .env'), BARRA],
  ['push com refspec ":" (todas as que casam)', bash('git push origin :'), BARRA],
  ['push com push.default=matching', bash('git -c push.default=matching push'), BARRA],
  ['MCP de documentos com delete_file passa', mcp('mcp__claude_docs__delete_file', { id: 'x' }), PASSA],
  ['cat do .dev.vars.example passa', bash('cat .dev.vars.example'), PASSA],
  ['cat do .env.example passa', bash('cat .env.example'), PASSA],
  ['Read do .dev.vars', arquivo('Read', '/repo/.dev.vars'), BARRA],
  ['Read do .env no Windows', arquivo('Read', 'D:\\proj\\crm-citas\\.env'), BARRA],
  ['Write do .env no Windows', arquivo('Write', 'D:\\proj\\crm-citas\\.env'), BARRA],
  ['MCP grava arquivo sem branch (vai para a padrão)', mcp('mcp__github__create_or_update_file', { owner: 'o', repo: 'r', path: 'x' }), BARRA],
  ['MCP de GitHub com outro nome funde sem conferir', mcp('mcp__gh2__merge_pull_request', { owner: 'o', repo: 'r', pullNumber: 9, expectedHeadSha: Y }), BARRA, 'feat/agenda-trabalho', 'erro'],
  ['MCP dispara a rotina de migrations', mcp('mcp__github__actions_run_trigger', { workflow_id: 'migrations-dev.yml' }), BARRA],
  ['MCP dispara a CI comum', mcp('mcp__github__actions_run_trigger', { workflow_id: 'ci.yml' }), PASSA],
  ['gh run rerun da rotina de backup', bash('gh run rerun 123 # backup-diario'), BARRA],
  // Merge, envio com rótulo e workflows. O quinto campo simula o que o GitHub e o git devolveriam (ver fixture()
  // no guarda.mjs); o sexto, quando existe, é a pasta do projeto.
  ...casosDeMerge(),
  ...casosDeEnvio(),
  ...casosDeWorkflow(),
  ...casosDeRotulo(),
  ['push sem destino estando na branch de integração', bash('git push'), BARRA, 'previas'],
  ['push de HEAD estando na branch de produção', bash('git push origin HEAD'), BARRA, 'main'],
  ['push sem destino em branch de trabalho', bash('git push'), PASSA],
  ['push forçado com opções juntas (-fu)', bash('git push -fu origin x'), BARRA],
  ['mensagem de commit que cita push no main', bash('git commit -m "trava: push direto no main fica barrado"'), PASSA],
  ['git log entre branches', bash('git log main..HEAD --oneline'), PASSA],
  ['git diff contra a branch de integração', bash('git diff origin/previas --stat'), PASSA],
  ['criar branch a partir da integração', bash('git checkout -b x origin/previas'), PASSA],
  ['deploy pelo script do package.json', bash('pnpm run deploy'), BARRA],
  ['deploy por wrangler versions', bash('wrangler versions deploy'), BARRA],
  ['deploy por npx com versão', bash('npx wrangler@latest deploy'), BARRA],
  ['aplicar migration com variável na frente', bash('DB_URL=x bash scripts/db/apply-dev.sh'), BARRA],
  ['aplicar migration com bash -x', bash('bash -x scripts/db/apply-dev.sh'), BARRA],
  ['aplicar migration por caminho absoluto', bash('/home/user/repo/scripts/db/apply-dev.sh'), BARRA],
  ['psql com a variável que o script usa', bash('psql "$DB_URL" -c "select 1"'), BARRA],
  ['psql com variável de banco local', bash('psql "$LOCAL_DB_URL" -c "select 1"'), PASSA],
  ['supabase db pull', bash('supabase db pull nome'), BARRA],
  ['supabase link', bash('supabase link --project-ref x'), BARRA],
  ['supabase migration repair', bash('supabase migration repair --status applied 1'), BARRA],
  ['gh pr create com base main', bash('gh pr create --base main --head claude/x'), BARRA],
  ['gh pr create de publicação', bash('gh pr create --base main --head previas'), PASSA],
  ['gh pr create com base previas', bash('gh pr create --base previas'), PASSA],
  ['disparar a rotina de migrations à mão', bash('gh workflow run migrations-dev.yml'), BARRA],
  ['gravar .env por redirecionamento', bash('echo SEGREDO=1 > .env'), BARRA],
  ['gravar .env.example por redirecionamento', bash('echo SEGREDO= > .env.example'), PASSA],
  ['sed -i numa migration', bash('sed -i s/a/b/ supabase/migrations/20260601000003_catalog.sql'), BARRA],
  ['sed -n numa migration (só leitura)', bash('sed -n 1,5p supabase/migrations/20260601000003_catalog.sql'), PASSA],
  ['MCP da Cloudflare que executa', mcp('mcp__Cloudflare__execute', {}), BARRA],
  ['MCP da Cloudflare de busca', mcp('mcp__Cloudflare__search', {}), PASSA],
];

let falhas = 0;
const pastaFx = mkdtempSync(join(tmpdir(), 'guarda-'));
// O quarto campo, quando existe, é a branch em que a trava deve achar que está; o quinto, o GitHub e o git
// simulados (sem ele: GitHub sem PR nenhum, para os testes nunca irem à rede); o sexto, a pasta do projeto.
for (const [i, [nome, entrada, esperado, branch = 'feat/agenda-trabalho', gh = {}, pasta = raiz]] of casos.entries()) {
  const env = { ...process.env, CLAUDE_PROJECT_DIR: pasta, GUARDA_BRANCH_TESTE: branch };
  delete env.GUARDA_GH_TESTE;
  if (gh === 'erro') env.GUARDA_GH_TESTE = 'erro';
  else { env.GUARDA_GH_TESTE = join(pastaFx, `${i}.json`); writeFileSync(env.GUARDA_GH_TESTE, JSON.stringify(gh)); }
  const r = spawnSync('node', [guarda], { input: entrada, encoding: 'utf8', env });
  const ok = r.status === esperado;
  if (!ok) falhas += 1;
  console.log(`${ok ? 'ok   ' : 'FALHA'} ${esperado === BARRA ? 'barra' : 'passa'}  ${nome}${ok ? '' : `  (saiu ${r.status}) ${r.stderr.trim()}`}`);
}
rmSync(pastaFx, { recursive: true, force: true });
for (const r of [raizComPlano, raizRascunho, raizSemAprovacao, raizSoNaCopia, raizSoLocal, raizLocalAFrente]) rmSync(r, { recursive: true, force: true });
// A trava sem os módulos de regras (arquivo ausente ou quebrado) tem de bloquear (saída 2), nunca sair com 1.
{
  const pasta = mkdtempSync(join(tmpdir(), 'guarda sem regras-'));
  writeFileSync(join(pasta, 'guarda.mjs'), readFileSync(guarda, 'utf8'));
  const r = spawnSync('node', [join(pasta, 'guarda.mjs')], { input: bash('ls'), encoding: 'utf8', env: { ...process.env, CLAUDE_PROJECT_DIR: raiz } });
  rmSync(pasta, { recursive: true, force: true });
  const ok = r.status === BARRA;
  if (!ok) falhas += 1;
  casos.push(['sem os módulos de regras']);
  console.log(`${ok ? 'ok   ' : 'FALHA'} barra  sem os módulos de regras, a trava bloqueia${ok ? '' : `  (saiu ${r.status})`}`);
}
console.log(`\n${casos.length - falhas}/${casos.length} casos certos`);
process.exit(falhas ? 1 : 0);
