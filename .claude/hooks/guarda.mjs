#!/usr/bin/env node
// Trava do Claude Code (PreToolUse): bloqueia ações que só o dono do projeto autoriza.
// Saída 2 = bloqueia e mostra o motivo ao agente. Saída 0 = deixa passar.
// Erro inesperado dentro da trava bloqueia (melhor parar do que deixar passar em silêncio).
// É uma barreira contra engano, não contra má-fé: confere o texto do comando, e por isso também
// barra quando o texto proibido aparece só citado (mensagem de commit, busca). No plano atual do
// GitHub não há proteção de branch: esta trava é a única barreira para o Claude.
// Spec: .claude/hooks/TRAVAS.md (§1 merge, §2 envio, §3 produção, banco, segredos e workflows).
// Testes: node .claude/hooks/guarda.test.mjs
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
// Os módulos locais são carregados por import() dentro de try (em carregar(), no fim do arquivo): arquivo
// ausente ou com erro de sintaxe bloqueia (saída 2), em vez de derrubar a trava com saída 1, que deixaria passar.
let nomeValido, PADRAO_TEXTO, ehDecisao, problemasDaDecisao, shaAprovado, PASTA_DECISOES, secao, problemasDaAprovacaoDoMerge, alteraSoAprovacaoDoMerge, problemaDaSpec, APROVADA;
// Branches em que nada entra por envio direto: só por PR (lista em regras-de-envio.mjs).
let PROTEGIDAS = 'main|master|previas';
async function carregar() {
  const envio = await import('./regras-de-envio.mjs');
  const dec = await import('./decisao-com-prova.mjs');
  ({ nomeValido, PADRAO_TEXTO } = envio);
  PROTEGIDAS = envio.PROTEGIDAS.join('|');
  ({ ehDecisao, problemasDaDecisao, shaAprovado, PASTA: PASTA_DECISOES, secao, problemasDaAprovacaoDoMerge, alteraSoAprovacaoDoMerge, problemaDaSpec, APROVADA } = dec);
  for (const f of [nomeValido, ehDecisao, problemasDaDecisao, shaAprovado, secao, problemasDaAprovacaoDoMerge, alteraSoAprovacaoDoMerge, problemaDaSpec]) {
    if (typeof f !== 'function') throw new Error('regras incompletas');
  }
  if (!(APROVADA instanceof RegExp)) throw new Error('regras incompletas');
}
// Ferramentas MCP que gravam direto num banco. A conexão MCP do Supabase aponta para a
// produção (docs/reference/project.md), por isso ficam bloqueadas sempre.
const MCP_BANCO = /^mcp__.+__(apply_migration|execute_sql)$/;
// Ferramentas do MCP do GitHub que gravam arquivo direto numa branch.
const MCP_GRAVA_BRANCH = /^mcp__.+__(push_files|create_or_update_file|delete_file)$/i;
const MCP_ABRE_PR = /^mcp__.+__create_pull_request$/i;
const MCP_FUNDE_PR = /^mcp__.+__merge_pull_request$/i;
const MCP_MERGE_AUTOMATICO = /^mcp__.+__enable_pr_auto_merge$/i;
// Ferramentas do MCP do GitHub que trocam os rótulos de um issue ou PR (a lista inteira) e as que tiram ou mudam um rótulo.
const MCP_TROCA_ROTULOS = /^mcp__.+__(issue_write|update_issue|update_pull_request|pull_request_write)$/i;
const MCP_MEXE_EM_ROTULO = /^mcp__.+__\w*label\w*$/i;
// Disparar rotina do GitHub Actions pelo MCP (equivalente ao "gh workflow run").
const MCP_DISPARA_ROTINA = /^mcp__.+__(actions_run_trigger|run_workflow|rerun_workflow_run|rerun_failed_jobs)$/i;
// A ferramenta de execução do MCP da Cloudflare altera serviço em produção.
const MCP_CLOUDFLARE = /^mcp__.*cloudflare.*__execute$/i;

const raiz = process.env.CLAUDE_PROJECT_DIR ?? process.cwd();

const block = (motivo) => {
  process.stderr.write(`Bloqueado pela trava do projeto: ${motivo}\n`);
  process.exit(2);
};
// Qualquer erro fora dos try abaixo também bloqueia.
process.on('uncaughtException', (erro) => block(`a trava falhou (${String(erro?.message ?? erro).slice(0, 100)}). Avise o dono do projeto.`));
process.on('unhandledRejection', (erro) => block(`a trava falhou (${String(erro?.message ?? erro).slice(0, 100)}). Avise o dono do projeto.`));

function git(args) {
  return execFileSync('git', args, { cwd: raiz, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 3000 }).trim();
}

// Branch em que se está. GUARDA_BRANCH_TESTE existe só para o arquivo de testes.
function branchAtual() {
  if (process.env.GUARDA_BRANCH_TESTE !== undefined) return process.env.GUARDA_BRANCH_TESTE;
  try { return git(['rev-parse', '--abbrev-ref', 'HEAD']); } catch { return ''; }
}

// ---- Leitura do GitHub (pela API, nunca pela cópia local) e do git -------------------------
// GUARDA_GH_TESTE existe só para o arquivo de testes: caminho de um JSON com o que o GitHub e o git
// devolveriam ({ pr: {numero, base, head, sha, rascunho, rotulos}, prs: {numero: pr}, pais: {sha: [pais]},
// compare: {status, arquivos: [[nome, situação]]} (de X para Y), comparacoes: {'de...ate': compare},
// conteudo: {'ref:caminho': texto}, ci: {sha: situação}, prDaBranch: {numero, sha, rotulos}, issue: {rotulos},
// local: {sha, pais, arquivos: [[situação, nome]], arquivosDoPr: [nome], conteudo} }), ou "erro".
// Qualquer falha de leitura devolve null, e quem chama bloqueia.
function fixture() {
  const f = process.env.GUARDA_GH_TESTE;
  if (f === undefined) return undefined;
  if (f === 'erro') return null;
  return JSON.parse(readFileSync(f, 'utf8'));
}
const INICIO = Date.now();
const PRAZO_MS = 90000; // abaixo dos 120 s do hook no settings.json: sem tempo, bloqueia (nunca "passa" por vencer)
function gh(args) {
  const resta = PRAZO_MS - (Date.now() - INICIO);
  if (resta < 2000) throw new Error('prazo da trava esgotado lendo o GitHub');
  return execFileSync('gh', args, { cwd: raiz, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: Math.min(15000, resta) });
}

const REPO = 'alexandrergomes1/crm-citas';
// Rótulo que a IA põe no PR ao mandar o pedido de merge ao dono (docs/guias/git-e-deploy.md §Merge de tarefa).
const ROTULO = 'aguardando-merge';
const SPEC_DA_TAREFA = /^specs\/[^/]+\/spec\.md$/;

function lerPr(numero, repo) {
  const fx = fixture();
  if (fx !== undefined) { const p = fx?.prs?.[numero] ?? fx?.pr; return p ? { rotulos: [], ...p } : null; }
  try {
    if (!/^\d+$/.test(String(numero))) return null;
    const [base, head, sha, rascunho, rotulos = ''] = gh(['api', `repos/${repo}/pulls/${numero}`, '--jq',
      '[.base.ref, .head.ref, .head.sha, (.draft | tostring), ([.labels[].name] | join(","))] | join(" ")']).trim().split(' ');
    return base && head && sha ? { numero: String(numero), base, head, sha, rascunho: rascunho === 'true', rotulos: rotulos.split(',').filter(Boolean) } : null;
  } catch { return null; }
}

// Pais de um commit, pelo GitHub.
function paisDe(sha, repo) {
  const fx = fixture();
  if (fx !== undefined) return fx?.pais?.[sha] ?? null;
  try { return gh(['api', `repos/${repo}/commits/${sha}`, '--jq', '.parents[].sha']).split('\n').filter(Boolean); } catch { return null; }
}

// Verificações de um commit: 'verde' só se há verificação e todas terminaram bem; 'vermelha' se alguma falhou,
// mesmo com outras rodando; 'pendente'; 'sem'. 'sem-minutos' só quando a CI não rodou por falta de minutos do
// GitHub: toda verificação que falhou tem anotação de cobrança, nenhuma está pendente e as demais passaram
// (no merge de tarefa vale como verde só com a linha "Prova local" na "Aprovação do merge", TRAVAS.md §1).
// runs: [{id, status, conclusion}]; status: {state, total}; anotacoesDe(id): lista de mensagens, ou null.
const FALHOU = /^(failure|cancelled|timed_out|action_required|startup_failure|stale)$/;
const COBRANCA = /spending limit|account payments have failed/i;
function classificarCi(runs, status, anotacoesDe) {
  if (runs.length === 0 && status.total === 0) return 'sem';
  const falhas = runs.filter((r) => r.status === 'completed' && FALHOU.test(r.conclusion));
  const statusFalhou = status.total > 0 && ['failure', 'error'].includes(status.state);
  const pendente = runs.some((r) => r.status !== 'completed') || (status.total > 0 && status.state === 'pending');
  const demaisOk = runs.every((r) => falhas.includes(r) || (r.status === 'completed' && /^(success|skipped|neutral)$/.test(r.conclusion)))
    && (status.total === 0 || status.state === 'success');
  if (falhas.length || statusFalhou) {
    if (statusFalhou || pendente || !demaisOk) return 'vermelha';
    const deCobranca = falhas.every((r) => { const a = anotacoesDe(r.id); return Array.isArray(a) && a.length > 0 && a.every((m) => COBRANCA.test(String(m))); });
    return deCobranca ? 'sem-minutos' : 'vermelha';
  }
  if (pendente) return 'pendente';
  return demaisOk ? 'verde' : 'vermelha';
}
function situacaoDaCi(sha, repo) {
  const fx = fixture();
  if (fx !== undefined) {
    const c = fx?.ci?.[sha];
    if (c === undefined || c === null || typeof c === 'string') return c ?? null;
    return classificarCi(c.runs, c.status, (id) => c.anotacoes?.[id] ?? null);
  }
  try {
    const runs = gh(['api', '--paginate', `repos/${repo}/commits/${sha}/check-runs?per_page=100`, '--jq', '.check_runs[] | [(.id | tostring), .status, (.conclusion // "")] | join(" ")'])
      .split('\n').filter(Boolean).map((l) => { const [id, s, conclusion = ''] = l.split(' '); return { id, status: s, conclusion }; });
    const status = JSON.parse(gh(['api', `repos/${repo}/commits/${sha}/status`, '--jq', '{state: .state, total: .total_count}']));
    const anotacoesDe = (id) => {
      try {
        if (!/^\d+$/.test(id)) return null;
        return gh(['api', '--paginate', `repos/${repo}/check-runs/${id}/annotations`, '--jq', '.[].message']).split('\n').filter(Boolean);
      } catch { return null; }
    };
    return classificarCi(runs, status, anotacoesDe);
  } catch { return null; }
}

// A seção "Aprovação do merge" tem a linha "Prova local:" preenchida (comandos e resultados rodados na sessão)?
const PROVA_LOCAL = /^[ \t]*(?:[-*][ \t]*)?(?:\*\*)?Prova local:?(?:\*\*)?:?[ \t]*\S.{9,}$/im;
const temProvaLocal = (spec) => spec !== null && PROVA_LOCAL.test(secao(spec, 'Aprovação do merge'));

// O que mudou entre dois commits: { status, arquivos: [[nome, situação]] }.
function comparar(de, ate, repo) {
  const fx = fixture();
  if (fx !== undefined) return fx === null ? null : (fx.comparacoes?.[`${de}...${ate}`] ?? (/^[0-9a-f]{40}$/i.test(de) ? fx.compare : null) ?? null);
  try {
    const [status, ...linhas] = gh(['api', `repos/${repo}/compare/${de}...${ate}`, '--jq', '.status, (.files[] | .filename + "\t" + .status)']).split('\n').filter(Boolean);
    return { status, arquivos: linhas.map((l) => l.split('\t')) };
  } catch { return null; }
}

// Conteúdo de um arquivo num commit, pelo GitHub.
function conteudoEm(caminho, ref, repo) {
  const fx = fixture();
  if (fx !== undefined) return fx?.conteudo?.[`${ref}:${caminho}`] ?? null;
  try { return gh(['api', '-H', 'Accept: application/vnd.github.raw', `repos/${repo}/contents/${caminho}?ref=${ref}`]); } catch { return null; }
}

// PR aberto de uma branch: { numero, sha, rotulos }, false se não há, null se não deu para ler.
function prDaBranch(branch, repo = REPO) {
  const fx = fixture();
  if (fx !== undefined) return fx === null ? null : (fx.prDaBranch ? { rotulos: [], ...fx.prDaBranch } : false);
  try {
    if (!/^[\w.-]+\/[\w.-]+$/.test(repo)) return null;
    const linha = gh(['api', `repos/${repo}/pulls?state=open&head=${repo.split('/')[0]}:${encodeURIComponent(branch)}`, '--jq',
      '.[0] | select(. != null) | [(.number | tostring), .head.sha, .base.ref, ([.labels[].name] | join(","))] | join(" ")']).trim();
    if (!linha) return false;
    const [numero, sha, base, ...resto] = linha.split(' ');
    return numero && sha && base ? { numero, sha, base, rotulos: resto.join(' ').split(',').filter(Boolean) } : null;
  } catch { return null; }
}

// Rótulos atuais de um issue ou PR, pelo GitHub (lista; null se não deu para ler).
function rotulosDaIssue(numero, repo) {
  const fx = fixture();
  if (fx !== undefined) return fx?.issue?.rotulos ?? null;
  try {
    if (!/^\d+$/.test(String(numero)) || !/^[\w.-]+\/[\w.-]+$/.test(repo)) return null;
    return gh(['api', `repos/${repo}/issues/${numero}`, '--jq', '.labels[].name']).split('\n').filter(Boolean);
  } catch { return null; }
}

// Arquivos que o PR mexe até o commit X: o que mudou da base (ponto em que a branch saiu) até X.
function arquivosDoPrAte(base, x, repo) {
  const c = comparar(base, x, repo);
  return c ? c.arquivos.map(([nome]) => nome) : null;
}

// A pasta specs/<pasta>/ do arquivo foi adicionada ou alterada no próprio PR (lista de arquivos do PR até X)?
const pastaDaSpecNoPr = (spec, arquivos) => {
  const pasta = spec.replace(/spec\.md$/, '');
  return Array.isArray(arquivos) && arquivos.some((a) => a.startsWith(pasta));
};

// O commit local que um envio manda (src do refspec), pela cópia local.
function envioLocal(src) {
  const fx = fixture();
  if (fx !== undefined) {
    const l = fx?.local;
    if (!l?.sha) return null;
    return { sha: l.sha, pais: () => l.pais ?? null, arquivos: () => l.arquivos ?? null, arquivosDoPr: () => l.arquivosDoPr ?? null, conteudo: (ref, c) => l.conteudo?.[`${ref}:${c}`] ?? null };
  }
  let sha;
  try { sha = git(['rev-parse', '--verify', '--quiet', `${src}^{commit}`]); } catch { return null; }
  if (!/^[0-9a-f]{40}$/.test(sha)) return null;
  const tenta = (f) => { try { return f(); } catch { return null; } };
  return {
    sha,
    pais: () => tenta(() => git(['rev-list', '--parents', '-n', '1', sha]).split(' ').slice(1)),
    arquivos: (de) => tenta(() => git(['diff', '--name-status', '--no-renames', de, sha]).split('\n').filter(Boolean).map((l) => l.split('\t'))),
    // Arquivos do PR até X: da base local (origin/<base>) até X, pelo ponto em que a branch saiu.
    arquivosDoPr: (base, x) => tenta(() => git(['diff', '--name-only', '--no-renames', `origin/${base}...${x}`]).split('\n').filter(Boolean)),
    conteudo: (ref, c) => tenta(() => git(['show', `${ref}:${c}`])),
  };
}

// '' se a spec, de X para Y, só ganhou a seção "Aprovação do merge" completa e citando X; senão, o problema.
function conferirSoAprovacao(antes, depois, x) {
  if (antes === null || depois === null) return 'não consegui ler a spec antes e depois do registro';
  if (!alteraSoAprovacaoDoMerge(antes, depois)) return 'o commit muda a spec fora da seção "Aprovação do merge" (ou não muda a seção)';
  const p = problemasDaAprovacaoDoMerge(secao(depois, 'Aprovação do merge'), x);
  return p.length ? `seção "Aprovação do merge": ${p.join('; ')}` : '';
}

// ---- Trava do merge (TRAVAS.md §1) ---------------------------------------------------------
// Método de merge por base (docs/guias/git-e-deploy.md §Merge de tarefa): tarefa na integração = squash;
// publicação na produção = merge commit (squash faria as duas branches divergirem).
const METODO = { previas: 'squash', main: 'merge', master: 'merge' };
// Autorização de publicação: arquivo próprio em docs/decisoes/, num PR pequeno à previas (o nº é o do PR de publicação).
const PUBLICACAO = /^docs\/decisoes\/\d{4}-\d{2}-\d{2}-publicacao-pr-(\d+)\.md$/;

// Lê e confere a decisão de publicação num commit; devolve o SHA citado em "Vale para".
function conferirDecisaoDePublicacao(nome, ref, repo) {
  const texto = conteudoEm(nome, ref, repo);
  if (texto === null) block(`não consegui ler ${nome} no GitHub.`);
  const problemas = problemasDaDecisao(nome, texto);
  if (problemas.length) block(`${nome}: ${problemas.join('; ')}.`);
  const sha = shaAprovado(texto);
  if (!sha) block(`${nome}: "Vale para" precisa citar o SHA do commit autorizado do PR de publicação.`);
  return sha;
}

// PR pequeno à previas só com a autorização de publicação (única exceção de PR de decisão): um arquivo novo
// docs/decisoes/AAAA-MM-DD-publicacao-pr-N.md, completo, citando o último commit do PR N (previas → main,
// com o rótulo aguardando-merge); CI verde no PR pequeno. Devolve false se o PR não é desse tipo.
function conferirPrDaAutorizacaoDePublicacao(pr, repo) {
  const c = comparar(pr.base, pr.sha, repo);
  if (!c || c.arquivos.length !== 1) return false;
  const [nome, situacao] = c.arquivos[0];
  const m = PUBLICACAO.exec(nome);
  if (!m || situacao !== 'added') return false;
  const sha = conferirDecisaoDePublicacao(nome, pr.sha, repo);
  const pub = lerPr(m[1], repo);
  if (!pub) block(`não consegui ler no GitHub o PR de publicação nº ${m[1]}.`);
  if (!/^(main|master)$/.test(pub.base) || pub.head !== 'previas') block(`${nome}: o PR nº ${m[1]} não é de publicação (previas → main).`);
  if (!pub.rotulos.includes(ROTULO)) block(`o PR de publicação nº ${m[1]} não tem o rótulo ${ROTULO}: o pedido de publicação ao dono ainda não saiu.`);
  if (!pub.sha.toLowerCase().startsWith(sha)) block(`${nome}: "Vale para" cita ${sha}, mas o último commit do PR de publicação é ${pub.sha.slice(0, 7)}.`);
  const ci = situacaoDaCi(pr.sha, repo);
  if (ci !== 'verde') block(ci === null ? 'não consegui ler a CI deste PR no GitHub.' : `a CI deste PR (${pr.sha.slice(0, 7)}) não está toda verde (${ci}).`);
  return true;
}

// Só o merge pelo MCP, com o método da base e expectedHeadSha = Y (último commit do PR). Tarefa: rótulo
// aguardando-merge; Y filho único de X; X→Y só na seção "Aprovação do merge" do spec.md de uma pasta de spec
// que o PR adiciona ou altera, citando X, com resposta literal, data e link. Publicação: Y só traz o arquivo
// novo docs/decisoes/AAAA-MM-DD-publicacao-pr-N.md (juntado antes pelo PR pequeno), citando X. Nos dois: CI
// verde em X e nada falhando em Y. Sem conseguir conferir: barra.
function conferirMerge(numero, repo, esperado, metodo) {
  const pr = lerPr(numero, repo);
  if (!pr) block('não consegui conferir este PR no GitHub (base, origem, último commit e rótulos). Confira à mão antes.');
  const producao = /^(main|master)$/.test(pr.base);
  if (producao && pr.head !== 'previas') block('fundir na branch de produção um PR que não é o de publicação. A base de trabalho é a branch de integração.');
  if (!producao && pr.base !== 'previas') return;
  if (metodo !== METODO[pr.base]) block(`método de merge "${metodo || 'não informado'}" na ${pr.base}: use merge_method "${METODO[pr.base]}"${producao ? ' (publicação: merge commit, nunca squash)' : ' (tarefa)'}.`);
  if (pr.rascunho) block('o PR ainda é rascunho: tire do rascunho e espere a CI rodar de novo antes do merge.');
  if (!/^[0-9a-f]{40}$/i.test(esperado) || esperado.toLowerCase() !== pr.sha.toLowerCase()) {
    block(`merge sem expectedHeadSha igual ao último commit do PR (${pr.sha.slice(0, 7)}, o commit que grava a autorização do dono), com o SHA inteiro.`);
  }
  if (!producao && conferirPrDaAutorizacaoDePublicacao(pr, repo)) return;
  if (!pr.rotulos.includes(ROTULO)) block(`o PR não tem o rótulo ${ROTULO}: o pedido de merge ao dono ainda não saiu (ou saiu e foi retirado).`);
  const y = pr.sha;
  const pais = paisDe(y, repo);
  if (!pais) block('não consegui ler o commit anterior ao último do PR no GitHub.');
  if (pais.length !== 1) block(`o último commit do PR (${y.slice(0, 7)}) tem ${pais.length} pais: tem de ser um commit só, sobre o commit autorizado.`);
  const x = pais[0];
  const c = comparar(x, y, repo);
  if (!c) block('não consegui comparar o commit autorizado com o último commit do PR no GitHub.');
  if (c.status !== 'ahead' || c.arquivos.length !== 1) block(`o último commit do PR tem de mexer num arquivo só; mexe em ${c.arquivos.length}.`);
  const [nome, situacao] = c.arquivos[0];
  let specY = null;
  if (producao) {
    const m = PUBLICACAO.exec(nome);
    if (!m || m[1] !== String(pr.numero) || situacao !== 'added') {
      block(`o último commit da publicação mexe em ${nome} ("${situacao}"): só vale o arquivo novo ${PASTA_DECISOES}AAAA-MM-DD-publicacao-pr-${pr.numero}.md, juntado antes pelo PR pequeno à previas.`);
    }
    const sha = conferirDecisaoDePublicacao(nome, y, repo);
    if (!x.toLowerCase().startsWith(sha)) block(`${nome}: "Vale para" precisa citar o SHA do commit autorizado (${x.slice(0, 7)}).`);
  } else {
    if (!SPEC_DA_TAREFA.test(nome) || situacao !== 'modified') block(`o último commit do PR mexe em ${nome} ("${situacao}"): só vale a seção "Aprovação do merge" do spec.md da spec do PR.`);
    const doPr = arquivosDoPrAte(pr.base, x, repo);
    if (!doPr) block('não consegui ler no GitHub os arquivos que o PR mexe.');
    if (!pastaDaSpecNoPr(nome, doPr)) block(`${nome}: a autorização tem de ir na spec que o próprio PR adiciona ou altera.`);
    specY = conteudoEm(nome, y, repo);
    const problema = conferirSoAprovacao(conteudoEm(nome, x, repo), specY, x);
    if (problema) block(`${nome}: ${problema}.`);
  }
  // CI sem minutos do GitHub (aviso de cobrança): só no merge de tarefa, e só com a "Prova local" gravada na spec.
  const semMinutosOk = (ci) => ci === 'sem-minutos' && !producao && temProvaLocal(specY);
  const SEM_PROVA = 'a CI não rodou por falta de minutos do GitHub: grave na "Aprovação do merge" a linha "Prova local:" com os comandos rodados na sessão e os resultados';
  const ciX = situacaoDaCi(x, repo);
  if (ciX !== 'verde' && !semMinutosOk(ciX)) {
    block(ciX === null ? 'não consegui ler a CI do commit autorizado no GitHub.'
      : ciX === 'sem-minutos' && !producao ? `${SEM_PROVA} (commit autorizado ${x.slice(0, 7)}).`
        : `a CI do commit autorizado (${x.slice(0, 7)}) não está toda verde (${ciX}).`);
  }
  const ciY = situacaoDaCi(y, repo);
  if (ciY === null) block('não consegui ler as verificações do último commit do PR no GitHub.');
  if (ciY === 'vermelha') block(`há verificação falhando no último commit do PR (${y.slice(0, 7)}).`);
  if (ciY === 'sem-minutos' && !semMinutosOk(ciY)) block(`${SEM_PROVA} (último commit ${y.slice(0, 7)}).`);
}

// Envio numa branch cujo PR tem o rótulo aguardando-merge: só um commit sobre X que só grava a autorização
// na spec que o próprio PR adiciona ou altera. O rótulo só o dono tira (a IA não, §Rótulo abaixo).
const DESTRAVA = 'Envio novo depois do pedido: o dono tira o rótulo ou autoriza de novo';
function conferirEnvioComRotulo(src, dst) {
  const pr = prDaBranch(dst);
  if (pr === null) block(`não consegui conferir no GitHub se o PR da branch ${dst} espera a autorização do dono (rótulo ${ROTULO}). Sem conferir, não envio.`);
  if (!pr || !pr.rotulos.includes(ROTULO)) return;
  const x = pr.sha;
  const motivo = `o PR #${pr.numero} tem o rótulo ${ROTULO}: depois do pedido de merge só entra um commit sobre ${x.slice(0, 7)} que mexe só na seção "Aprovação do merge" da spec. ${DESTRAVA}`;
  const local = envioLocal(src);
  if (!local) block(`${motivo} (não consegui ler o commit que vai ser enviado).`);
  if (local.sha === x) return;
  const pais = local.pais();
  if (!pais || pais.length !== 1 || pais[0] !== x) block(`${motivo} (o commit enviado não é filho único de ${x.slice(0, 7)}).`);
  const arquivos = local.arquivos(x);
  if (!arquivos || arquivos.length !== 1 || arquivos[0][0] !== 'M' || !SPEC_DA_TAREFA.test(arquivos[0][1] ?? '')) {
    block(`${motivo} (o commit enviado mexe em ${arquivos ? arquivos.map((a) => a[1]).join(', ') : 'arquivos que não consegui ler'}).`);
  }
  const nome = arquivos[0][1];
  const doPr = local.arquivosDoPr(pr.base ?? 'previas', x);
  if (!doPr) block(`${motivo} (não consegui ler os arquivos que o PR mexe; rode git fetch origin ${pr.base ?? 'previas'}).`);
  if (!pastaDaSpecNoPr(nome, doPr)) block(`${motivo} (${nome} não é a spec que o próprio PR adiciona ou altera).`);
  const problema = conferirSoAprovacao(local.conteudo(x, nome), local.conteudo(local.sha, nome), x);
  if (problema) block(`${motivo} (${nome}: ${problema}).`);
}

// Gravação pelo MCP numa branch cujo PR tem o rótulo: barrada sempre (o commit da autorização vai pelo git).
function conferirMcpComRotulo(branch, repo) {
  const nome = String(branch).replace(/^refs\/heads\//, '');
  const pr = prDaBranch(nome, repo || REPO);
  if (pr === null) block(`não consegui conferir no GitHub se o PR da branch ${nome} espera a autorização do dono (rótulo ${ROTULO}). Sem conferir, não gravo.`);
  if (pr && pr.rotulos.includes(ROTULO)) block(`o PR #${pr.numero} tem o rótulo ${ROTULO}: depois do pedido de merge nada se grava pelo MCP na branch. ${DESTRAVA}.`);
}

// ---- Rótulo aguardando-merge: só o dono tira (TRAVAS.md §1) ----------------------------------
const TIRA_ROTULO = 'tirar o rótulo aguardando-merge. Só o dono destrava: envio novo depois do pedido, o dono tira o rótulo ou autoriza de novo.';
function conferirRotuloNaLinha(parte) {
  const r = ROTULO.replace('-', '\\-');
  if (/\bgh\s+(pr|issue)\s+edit\b/.test(parte) && new RegExp(`--remove-label[=\\s]+["']?[^\\s"']*${r}`).test(parte)) block(TIRA_ROTULO);
  if (/\bgh\s+label\s+(delete|edit)\b/.test(parte) && parte.includes(ROTULO)) block(TIRA_ROTULO);
  const api = /\bgh\s+api\b/.test(parte) || (/\bcurl\b/.test(parte) && /api\.github\.com/.test(parte));
  if (!api) return;
  if (/removeLabelsFromLabelable|clearLabelsFromLabelable|deleteLabel|updateLabel/.test(parte)) block(TIRA_ROTULO);
  // GraphQL que troca a lista inteira de rótulos de um PR ou issue (labelIds).
  if (/\b(updatePullRequest|updateIssue)\b/.test(parte) && /\blabelIds\b/.test(parte)) block(TIRA_ROTULO);
  const metodo = /(\s-X\s*|--method[=\s]+|--request[=\s]+)["']?(PUT|PATCH|DELETE)/i.exec(parte)?.[2]?.toUpperCase();
  // PATCH no próprio issue ou PR com o campo labels troca a lista inteira (como o PUT em /labels).
  if (metodo === 'PATCH' && /\/(issues|pulls)\/\d+["']?(\s|$)/.test(parte) && /\blabels\b/.test(parte) && !parte.includes(ROTULO)) block(TIRA_ROTULO);
  if (!metodo || !/\/labels\b/.test(parte)) return;
  if (new RegExp(`/labels/${r}\\b`).test(parte)) block(TIRA_ROTULO);
  if (metodo === 'DELETE' && /\/labels["']?(\s|$)/.test(parte)) block(TIRA_ROTULO);
  if (metodo === 'PUT' && !parte.includes(ROTULO)) block(TIRA_ROTULO);
}
function conferirRotuloNoMcp(tool, ti) {
  const texto = JSON.stringify(ti);
  if (MCP_MEXE_EM_ROTULO.test(tool) && texto.includes(ROTULO) && /remove|delete|update|edit|rename/i.test(`${tool} ${ti.method ?? ''} ${ti.action ?? ''}`)) block(TIRA_ROTULO);
  if (!MCP_TROCA_ROTULOS.test(tool) || !Array.isArray(ti.labels) || /^create$/i.test(String(ti.method ?? ''))) return;
  if (ti.labels.includes(ROTULO)) return;
  const numero = ti.issue_number ?? ti.issueNumber ?? ti.pullNumber ?? ti.pull_number;
  const atuais = rotulosDaIssue(numero, ti.owner && ti.repo ? `${ti.owner}/${ti.repo}` : REPO);
  if (atuais === null) block(`não consegui ler no GitHub os rótulos atuais de #${numero}: trocar a lista pode ${TIRA_ROTULO}`);
  if (atuais.includes(ROTULO)) block(TIRA_ROTULO);
}

// ---- Workflows (TRAVAS.md §3) --------------------------------------------------------------
// Arquivo em .github/workflows/ só muda se estiver na seção "Arquivos permitidos" do plano (ou da spec) de uma
// spec aprovada da branch: a pasta specs/*/ cujo spec.md ou plan.md cita a branch entre crases e cujo spec.md
// diz "Approved" com a "Aprovação do dono" completa. Tudo lido da versão commitada (git show <ref>:<caminho>),
// nunca da cópia de trabalho. Write/Edit: ref HEAD, branch atual. MCP: só refs/remotes/origin/<branch>.
const WORKFLOW = /(^|[\\/])\.github[\\/]workflows[\\/]/;
const relWorkflow = (f) => { const n = String(f).replace(/\\/g, '/'); return n.slice(n.indexOf('.github/workflows/')); };
function workflowsPermitidos(branch, refs) {
  const out = new Set();
  if (!branch) return out;
  const tenta = (f) => { try { return f(); } catch { return null; } };
  const ref = refs.find((r) => tenta(() => git(['rev-parse', '--verify', '--quiet', `${r}^{commit}`])));
  if (!ref) return out;
  const pastas = tenta(() => git(['ls-tree', '-d', '--name-only', `${ref}:specs`]).split('\n').filter(Boolean)) ?? [];
  const ler = (c) => tenta(() => git(['show', `${ref}:${c}`]));
  for (const nome of pastas) {
    const spec = ler(`specs/${nome}/spec.md`) ?? '';
    const plano = ler(`specs/${nome}/plan.md`) ?? '';
    if (![spec, plano].some((t) => t.includes(`\`${branch}\``))) continue;
    if (!APROVADA.test(spec) || problemaDaSpec(spec, ler, `specs/${nome}`) !== '') continue;
    for (const t of [spec, plano]) for (const m of secao(t, 'Arquivos permitidos').matchAll(/\.github\/workflows\/[\w.\-/]+/g)) out.add(m[0]);
  }
  return out;
}
function conferirWorkflow(rel, branch = branchAtual(), refs = ['HEAD']) {
  if (!workflowsPermitidos(branch, refs).has(rel)) block(`alterar ${rel} fora dos "Arquivos permitidos" da spec aprovada da branch ${branch || '(desconhecida)'} (versão commitada). Workflow só muda quando a spec aprovada o lista.`);
}
// Comando que grava, move ou apaga arquivo (limite conhecido: não pega toda forma de escrever).
const GRAVA_NA_LINHA = /(^|\s)(tee|cp|mv|rm|install|truncate|ln)\s|\bsed\b[^|]*\s-i|\bgit\b.*\s(rm|mv|checkout|restore)\s|>\s*["']?[^\s>]*\.github\/workflows\//;
function conferirWorkflowNaLinha(parte) {
  if (!/\.github\/workflows\//.test(parte) || !GRAVA_NA_LINHA.test(parte)) return;
  for (const m of parte.matchAll(/\.github\/workflows\/[\w.\-/]*/g)) conferirWorkflow(m[0]);
}

// Migration que já existe na branch de integração não se edita. A que foi criada no próprio
// PR (ainda não está lá) pode ser corrigida. Sem conseguir conferir, trata como existente.
function migrationJaIntegrada(file) {
  const rel = file.slice(file.indexOf('supabase/migrations/'));
  try { git(['rev-parse', '--verify', '--quiet', 'origin/previas']); } catch { return true; }
  try { git(['cat-file', '-e', `origin/previas:${rel}`]); return true; } catch { return false; }
}

// O que um "git push" envia: pares { src, dst } dos refspecs depois do remoto, ou HEAD → branch atual
// quando não há refspec. Tag (refs/tags/...) e apagar não contam.
function enviosDoPush(resto) {
  const tokens = resto.trim().split(/\s+/).filter(Boolean).map((t) => t.replace(/^["']|["']$/g, ''));
  const soltos = [];
  let apagar = false;
  for (let i = 0; i < tokens.length; i += 1) {
    const t = tokens[i];
    // Redirecionamento (2>/dev/null, >log, > log) não é destino: pula ele e o alvo dele, e continua lendo.
    if (/^\d*[<>]/.test(t)) { if (/^\d*[<>]+$/.test(t)) i += 1; continue; }
    if (/^(-d|--delete)$/.test(t)) { apagar = true; continue; }
    if (/^(--tags|--follow-tags)$/.test(t)) continue;
    if (/^(-o|--push-option|--repo|--receive-pack|--exec)$/.test(t)) { i += 1; continue; }
    if (t.startsWith('-')) continue;
    soltos.push(t);
  }
  if (apagar) return [];
  const refspecs = soltos.slice(1);
  const atual = branchAtual();
  if (refspecs.length === 0) return atual ? [{ src: 'HEAD', dst: atual }] : [];
  return refspecs
    .map((r) => r.replace(/^\+/, ''))
    .map((r) => (r.includes(':') ? { src: r.split(':')[0], dst: r.split(':')[1] } : { src: r, dst: r }))
    .filter((e) => e.dst && !e.dst.startsWith('refs/tags/'))
    .map((e) => ({ src: e.src, dst: e.dst.replace(/^refs\/heads\//, '') }))
    .map((e) => ({ src: e.src, dst: e.dst === 'HEAD' ? atual : e.dst }))
    .filter((e) => e.dst);
}

function conferirBash(cmd) {
  // Cada trecho entre ; & | e cada linha é conferido sozinho, para um trecho não liberar o outro.
  // "2>&1", ">&2" e "&>" são redirecionamentos, não separadores de comando: viram espaço antes de cortar,
  // senão o "&" corta o comando no meio e o destino do push fica fora do trecho conferido.
  const semRedir = cmd.replace(/\d*[<>]&(\d+|-)(?![\w/.~-])/g, ' ').replace(/\d*[<>]&/g, ' >').replace(/&>>?/g, ' >').replace(/\d*>\|/g, ' >');
  for (const parte of semRedir.split(/[\n;&|]+/)) {
    // "push" como subcomando do git, com opções no meio (git -C . push). Texto solto, como a
    // mensagem de um commit que cita "push", não conta.
    const push = /\bgit\b["']?(\s+-\S+(\s+[^\s-]\S*)?)*\s+push\b(.*)$/.exec(parte);
    if (push) {
      const resto = push[3] ?? '';
      if (new RegExp(`(\\s|:|\\+|["'])(refs/heads/)?(${PROTEGIDAS})(["']|\\s|$)`).test(resto)) block('push direto numa branch protegida. Abra um PR.');
      if (new RegExp(`^(${PROTEGIDAS})$`).test(branchAtual())) block('push a partir de uma branch protegida. Crie uma branch de trabalho.');
      if (/\s--(all|branches|no-verify)(\s|$)/.test(resto) || /core\.hooksPath|push\.default/i.test(parte) || /\s["']?:["']?(\s|$)/.test(resto)) block('push que envia todas as branches ou pula o gancho de envio.');
      if (/\s--(force\S*|mirror)(\s|$)/.test(resto) || /\s-[a-zA-Z]*f[a-zA-Z]*(\s|$)/.test(resto) || /\s\+\S/.test(resto)) block('push forçado.');
      const envios = enviosDoPush(resto);
      for (const { dst } of envios) {
        if (!nomeValido(dst)) block(`push de branch fora do padrão de nome (${dst}). Use ${PADRAO_TEXTO}.`);
      }
      for (const { src, dst } of envios) conferirEnvioComRotulo(src || 'HEAD', dst);
    }
    if (/\bgit\b.*\bconfig\b/.test(parte) && /push\.default|remote\.\S*\.(push|mirror)|core\.hooksPath/i.test(parte)) block('mudar a configuração de envio do git (push.default, remote.*.push, remote.*.mirror, core.hooksPath).');
    if (/\bgit\b.*\breset\b.*--hard\b/.test(parte)) block('git reset --hard (apaga trabalho sem volta).');
    if (/\bgh\s+pr\s+create\b/.test(parte) && /--base[=\s]+["']?(main|master)\b/.test(parte) && !/--head[=\s]+["']?previas\b/.test(parte)) block('PR de branch de trabalho com base na produção. A base é a branch de integração.');
    const merge = /\bgh\s+pr\s+merge\b(.*)$/.exec(parte);
    if (merge) {
      if (/\s--auto\b/.test(merge[1])) block('merge automático. O merge é feito depois da autorização do dono, pela ferramenta de merge do MCP, que a trava confere.');
      block('merge pelo gh. O único caminho é a ferramenta de merge do MCP, com expectedHeadSha, que a trava confere (TRAVAS.md §1).');
    }
    // O nome do rótulo aguardando-merge não conta como "merge" (rótulo tem trava própria, conferirRotuloNaLinha).
    const semRotulo = parte.split(ROTULO).join(' ');
    if (/\bgh\s+api\b/.test(parte) && /merge/i.test(semRotulo)) block('chamada direta à API do GitHub com "merge". Use a ferramenta de merge do MCP, que a trava confere.');
    if (/\bcurl\b/.test(parte) && /api\.github\.com/.test(parte) && /merge/i.test(semRotulo)) block('chamada direta à API do GitHub com "merge". Use a ferramenta de merge do MCP, que a trava confere.');
    // Escrita pela API do GitHub (método diferente de GET) em refs, arquivos ou nas branches protegidas: é envio direto.
    const api = /\bgh\s+api\b/.test(parte) || (/\bcurl\b/.test(parte) && /api\.github\.com/.test(parte));
    const escreve = /(\s-X\s*|--method[=\s]+|--request[=\s]+)["']?(POST|PUT|PATCH|DELETE)/i.test(parte)
      || (/\bgh\s+api\b/.test(parte) && /\s(-f|-F|--field|--raw-field|--input)(\s|=)/.test(parte) && !/(\s-X\s*|--method[=\s]+)["']?GET/i.test(parte))
      || (/\bcurl\b/.test(parte) && /\s(-d|--data\S*)(\s|=)/.test(parte));
    if (api && escreve && (/git\/refs|\/contents\/|\/merges\b/.test(parte) || new RegExp(`\\b(${PROTEGIDAS})\\b`).test(parte))) block('escrita direta pela API do GitHub numa branch (equivale a envio direto). Use branch de trabalho e PR.');
    if (/\bgh\s+run\s+rerun\b/.test(parte) && /migrations|backup/i.test(parte)) block('disparar à mão a rotina de migrations ou de backup. Só com autorização.');
    // Ler arquivo de segredos pela linha de comando: comando de leitura (o primeiro nome do trecho, depois de
    // variáveis VAR=x) com o arquivo citado pelo nome, ou leitura por redirecionamento (< .env). Curinga e
    // busca recursiva ficam fora (limite conhecido, TRAVAS.md §3): a trava é contra engano, não contra má-fé.
    const palavras = parte.replace(/--exclude(-dir)?=?\S+/g, ' ').split(/[\s<>"'=(),;`]+/).filter(Boolean).map((p) => p.replace(/^.*[/\\]/, ''));
    const nomes = parte.trim().split(/\s+/).filter((p) => !/^\w+=/.test(p));
    const leitor = /^(cat|less|more|head|tail|grep|rg|bat|awk|sed|source|\.|xxd|od|strings|base64|cp|nl|diff|tac|sort|wc)$/.test((nomes[0] ?? '').replace(/^.*[/\\]/, ''));
    if ((leitor || /<\s*\S/.test(parte)) && palavras.some(ehSegredo)) block('leitura de arquivo de segredos (.env, .dev.vars). Segredos ficam no painel do serviço, nunca na conversa.');
    if (/\bgh\s+workflow\s+run\b.*(migrations|backup)/.test(parte)) block('disparar à mão a rotina de migrations ou de backup. Só com autorização.');
    // Deploy: wrangler direto (também "wrangler versions deploy", "wrangler@x deploy") ou pelo script do package.json.
    if (/\bwrangler(@\S+)?\s+(versions\s+)?deploy\b/.test(parte) && !/--dry-run/.test(parte)) block('deploy manual. O deploy sai pelo Workers Builds.');
    if (/\b(pnpm|npm|yarn)\s+(run\s+)?deploy\b/.test(parte)) block('deploy manual. O deploy sai pelo Workers Builds.');
    if (/\bsupabase\b.*\b(db\s+(push|pull|execute|remote)|link|migration\s+repair)\b/.test(parte)) block('comando do Supabase contra banco remoto. Siga docs/guias/banco.md.');
    if (/\bsupabase\b.*(--linked|--db-url)/.test(parte)) block('comando do Supabase contra banco remoto. Siga docs/guias/banco.md.');
    // Só a execução do script é bloqueada (com ou sem variável antes, por bash/sh ou direto);
    // ler o arquivo (cat, grep, sed -n) continua livre.
    if (/^\s*(\S+=\S*\s+)*((bash|sh|source|\.)(\s+-\S+)*\s+)?\S*scripts\/db\/apply-(dev|migrations)\.sh/.test(parte)) block('aplicar migration à mão. Quem aplica é a rotina do GitHub, no merge.');
    if (/\bpsql\b/.test(parte)) {
      const variaveis = [...parte.matchAll(/\$\{?(\w+)/g)].map((m) => m[1]);
      const remota = variaveis.some((v) => /URL|DSN|CONN/i.test(v) && !/LOCAL/i.test(v));
      if (remota || /supabase\.(co|com)/.test(parte) || /postgres(ql)?:\/\/(?![^\s/]*@?(localhost|127\.0\.0\.1))/.test(parte)) block('psql contra banco remoto. Só banco local.');
    }
    // rm recursivo e forçado (-rf, -fr, -Rf…) na raiz, na casa, na pasta atual ou em tudo.
    if (/\brm\s+-(?=[a-zA-Z]*[rR])(?=[a-zA-Z]*f)[a-zA-Z]+\s+(\/|~\/?|\.\/?|\*)(\s|$)/.test(parte)) block('remoção ampla de arquivos.');
    // Gravar em arquivo de segredos ou editar migration pela linha de comando, em vez das ferramentas de arquivo.
    if (/>\s*["']?\S*\.env(\.(?!example)\w+)?["']?(\s|$)/.test(parte)) block('arquivo de segredos (.env). Segredos ficam no painel do serviço, nunca no repositório.');
    if (/\bsed\b[^|]*\s-i/.test(parte) && /supabase\/migrations\//.test(parte)) block('edição de migration pela linha de comando. Use a ferramenta de edição (que confere se ela já foi integrada).');
    conferirWorkflowNaLinha(parte);
    conferirRotuloNaLinha(parte);
  }
}

// Arquivo de segredos: .env, .env.<qualquer>, .envrc, .dev.vars (o .example de cada um não é segredo).
// Aceita caminho com / ou \ (Windows) e padrões de busca (*, {, ,).
const ehSegredo = (a) => /(^|[/\\*{,])(\.env([.*]|$)|\.envrc$|\.dev\.vars([.*]|$))/.test(a) && !/\.example$/.test(a);

function conferir(input) {
  const tool = String(input.tool_name ?? '');
  const ti = input.tool_input && typeof input.tool_input === 'object' ? input.tool_input : {};

  if (MCP_BANCO.test(tool)) {
    block('gravação direta no banco pelo MCP. Migration entra por arquivo novo e PR (docs/guias/banco.md); produção só com autorização.');
  }
  if (MCP_CLOUDFLARE.test(tool)) {
    block('alteração na Cloudflare pelo MCP. Só com autorização do dono do projeto.');
  }
  // Só ferramentas de repositório (com owner, repo ou branch), para não confundir com outros MCPs que também têm "delete_file".
  if (MCP_GRAVA_BRANCH.test(tool) && (ti.owner || ti.repo || ti.repository || ti.ref || ti.branch) && (!ti.branch || new RegExp(`^(refs/heads/)?(${PROTEGIDAS})$`).test(String(ti.branch)))) {
    block('gravação direta numa branch protegida pelo MCP do GitHub. Use uma branch de trabalho e PR.');
  }
  if (MCP_GRAVA_BRANCH.test(tool) && (ti.owner || ti.repo || ti.repository || ti.ref || ti.branch)) {
    const b = String(ti.branch).replace(/^refs\/heads\//, '');
    const caminhos = [ti.path, ...(Array.isArray(ti.files) ? ti.files.map((f) => f?.path) : [])].filter((c) => typeof c === 'string');
    // O MCP grava na branch do GitHub: só vale a spec da cópia remota (origin/<branch>), nunca a branch local.
    for (const c of caminhos) if (WORKFLOW.test(c)) conferirWorkflow(relWorkflow(c), b, [`refs/remotes/origin/${b}`]);
    conferirMcpComRotulo(b, ti.owner && ti.repo ? `${ti.owner}/${ti.repo}` : REPO);
  }
  if (/^mcp__/.test(tool)) conferirRotuloNoMcp(tool, ti);
  if (MCP_ABRE_PR.test(tool) && /^(main|master)$/.test(String(ti.base ?? '')) && String(ti.head ?? '') !== 'previas') {
    block('PR de branch de trabalho com base na produção. A base é a branch de integração.');
  }

  if (MCP_DISPARA_ROTINA.test(tool) && /migrations|backup/i.test(JSON.stringify(ti))) block('disparar pelo MCP a rotina de migrations ou de backup. Só com autorização.');
  if (MCP_MERGE_AUTOMATICO.test(tool)) block('merge automático. O merge é feito depois da autorização do dono, pela ferramenta de merge do MCP, que a trava confere.');

  if (MCP_FUNDE_PR.test(tool)) {
    const numero = String(ti.pullNumber ?? '');
    const repo = ti.owner && ti.repo ? `${ti.owner}/${ti.repo}` : '';
    if (!/^\d+$/.test(numero) || !repo) block('pedido de merge sem número de PR ou repositório.');
    conferirMerge(numero, repo, String(ti.expectedHeadSha ?? ''), String(ti.merge_method ?? ti.mergeMethod ?? ''));
  }

  if (tool === 'Bash') conferirBash(String(ti.command ?? ''));

  // Ler arquivo de segredos (.env, mas não .env.example) pelas ferramentas de leitura e busca.
  if (['Read', 'Grep', 'Glob'].includes(tool)) {
    const alvos = [ti.file_path, ti.path, ti.glob, tool === 'Glob' ? ti.pattern : undefined].filter((v) => typeof v === 'string');
    if (alvos.some(ehSegredo)) block('leitura de arquivo de segredos (.env, .dev.vars). Segredos ficam no painel do serviço, nunca na conversa.');
  }

  if (['Write', 'Edit', 'MultiEdit', 'NotebookEdit'].includes(tool)) {
    const file = String(ti.file_path ?? ti.notebook_path ?? '');
    if (ehSegredo(file)) block('arquivo de segredos (.env). Segredos ficam no painel do serviço, nunca no repositório.');
    if (/supabase\/migrations\//.test(file) && migrationJaIntegrada(file)) block('edição de migration que já está na branch de integração. Crie uma migration nova.');
    if (WORKFLOW.test(file)) conferirWorkflow(relWorkflow(file));
  }
}

let raw = '';
process.stdin.on('data', (c) => (raw += c));
process.stdin.on('end', async () => {
  try {
    await carregar();
  } catch (erro) {
    block(`a trava não conseguiu carregar as regras (${String(erro?.message ?? erro).slice(0, 100)}). Avise o dono do projeto.`);
  }
  let input;
  try {
    input = JSON.parse(raw);
  } catch {
    // Entrada ilegível: se parece chamada de banco, bloqueia; o resto segue.
    if (/apply_migration|execute_sql/.test(raw)) block('entrada ilegível numa chamada de banco.');
    process.exit(0);
  }
  if (input === null || typeof input !== 'object') process.exit(0);
  try {
    conferir(input);
  } catch (erro) {
    block(`a trava falhou ao conferir (${String(erro?.message ?? erro).slice(0, 100)}). Avise o dono do projeto.`);
  }
  process.exit(0);
});
