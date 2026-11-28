#!/usr/bin/env node
// PROPOSTA (destino: .claude/hooks/guarda.mjs; ADR 0003 · T1). Trava do Claude Code (PreToolUse): antes de cada
// ação da IA, barra o que só o dono autoriza. Saída 2 = barra e mostra o motivo; saída 0 = passa.
// Regras de origem: AGENTS.md §1 (nunca publicar, nunca mudar o banco remoto), §6 (segredos, escopo) e §8
// (branches, merge só com a autorização gravada na spec). É barreira contra engano, não contra má-fé: lê o
// texto do comando, e por isso também barra quando o texto proibido só aparece citado.
// Sem conseguir conferir (regras ausentes, GitHub ilegível, prazo): barra (ISO 31000, falhar fechado).
// As regras de envio vêm de .githooks/pre-push.mjs (fonte única, ADR 0003 · T2).
// Testes: node .claude/hooks/guarda.test.mjs
import { execFileSync } from 'node:child_process';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export class Barrado extends Error {}
const barra = (motivo) => { throw new Barrado(motivo); };

// Ferramentas MCP (nomes lidos na trava do projeto antigo).
const MCP_BANCO = /^mcp__.+__(apply_migration|execute_sql)$/;
const MCP_CLOUDFLARE = /^mcp__.*cloudflare.*__execute$/i;
const MCP_GRAVA_BRANCH = /^mcp__.+__(push_files|create_or_update_file|delete_file)$/i;
const MCP_ABRE_PR = /^mcp__.+__create_pull_request$/i;
const MCP_FUNDE_PR = /^mcp__.+__merge_pull_request$/i;
const MCP_MERGE_AUTOMATICO = /^mcp__.+__enable_pr_auto_merge$/i;
// MCP do Supabase e da Vercel: só passa o que lê (lista fechada por prefixo); o resto barra, porque muda o
// remoto ou publica. Barrados assim, entre outros (nomes lidos em supabase.com/docs/guides/getting-started/mcp
// em 28/11/2026): deploy_edge_function, create_edge_function_secret, create/delete/merge/rebase/reset_branch,
// create/pause/restore_project, update_storage_config, run_notebook, confirm_cost. Da Vercel, a doc oficial só
// lista ferramentas de leitura; qualquer outra (publicar, promover, voltar versão, variável, domínio) barra.
const MCP_SO_LEITURA = /^((get|list|search|query)_[a-z_]*|generate_typescript_types|web_fetch_vercel_url)$/i;
// Nome MCP = mcp__<servidor>__<ferramenta>; o servidor pode ter "_" (ex.: plugin_supabase_supabase).
export const mcpRemotoQueMuda = (tool) => {
  const m = /^mcp__(.+)__([^_].*?)$/.exec(String(tool));
  return Boolean(m && /supabase|vercel/i.test(m[1]) && !MCP_SO_LEITURA.test(m[2].split('__').pop()));
};

// Arquivo de segredos: .env, .env.<algo>, .envrc, .dev.vars (o .example não é segredo).
const SEGREDOS = ['.env', '.envrc', '.dev.vars'];
export const ehSegredo = (a) => {
  const s = String(a);
  if (/(^|[/\\*{,])(\.env([.*]|$)|\.envrc$|\.dev\.vars([.*]|$))/.test(s) && !/\.example$/.test(s)) return true;
  // Curinga que pode casar um segredo (ex.: .e*, .*, .dev.v?): o trecho antes do curinga é começo de um nome.
  const ultimo = s.split(/[/\\]/).pop() ?? '';
  if (!/[*?[]/.test(ultimo)) return false;
  const antes = ultimo.split(/[*?[]/)[0];
  return antes.startsWith('.') && SEGREDOS.some((n) => n.startsWith(antes));
};
// A trava não se desliga sozinha: a IA não grava nas próprias travas nem nas regras de envio.
export const ehTrava = (a) => /(^|[/\\])\.claude[/\\](settings[^/\\]*\.json$|hooks([/\\]|$))|(^|[/\\])\.githooks([/\\]|$)/.test(String(a));
const WORKFLOW = /(^|[\\/])\.github[\\/]workflows[\\/]/;
const relWorkflow = (f) => { const n = String(f).replace(/\\/g, '/'); return n.slice(n.indexOf('.github/workflows/')); };

// ---- CI de um commit, pelo GitHub: 'verde', 'vermelha', 'pendente', 'sem' ou null (ilegível) ----------
const FALHOU = /^(failure|cancelled|timed_out|action_required|startup_failure|stale)$/;
function ciDe(amb, repo, sha) {
  const runs = amb.gh(['api', '--paginate', `repos/${repo}/commits/${sha}/check-runs?per_page=100`, '--jq', '.check_runs[] | .status + " " + (.conclusion // "")']);
  const st = amb.gh(['api', `repos/${repo}/commits/${sha}/status`, '--jq', '.state + " " + (.total_count | tostring)']);
  if (runs === null || st === null) return null;
  const lista = runs.split('\n').filter(Boolean).map((l) => l.split(' '));
  const [estado, total] = st.trim().split(' ');
  const comStatus = Number(total) > 0;
  if (lista.length === 0 && !comStatus) return 'sem';
  if (lista.some(([s, c]) => s === 'completed' && FALHOU.test(c ?? '')) || (comStatus && /^(failure|error)$/.test(estado))) return 'vermelha';
  if (lista.some(([s]) => s !== 'completed') || (comStatus && estado === 'pending')) return 'pendente';
  return 'verde';
}

// ---- Merge (AGENTS.md §8; processo-sdd.md etapa 13) ---------------------------------------------------
// Só passa o merge pelo MCP de um PR para a previas, fora de rascunho, com expectedHeadSha = Y (último commit),
// em que Y é filho único de X e só grava a linha "Aprovação do merge" da spec da branch, completa e citando X;
// spec "Approved" com a "Aprovação do dono" completa; CI verde em X e nada falhando em Y. Na main, nunca:
// juntar na produção é publicar, e a IA nunca publica (AGENTS.md §1).
function conferirMerge(ti, amb, dec) {
  const numero = String(ti.pullNumber ?? ti.pull_number ?? '');
  const repo = ti.owner && ti.repo ? `${ti.owner}/${ti.repo}` : '';
  if (!/^\d+$/.test(numero) || !/^[\w.-]+\/[\w.-]+$/.test(repo)) barra('pedido de merge sem número de PR ou repositório.');
  const linha = amb.gh(['api', `repos/${repo}/pulls/${numero}`, '--jq', '[.base.ref, .head.ref, .head.sha, (.draft | tostring)] | join(" ")']);
  if (linha === null) barra('não consegui ler este PR no GitHub. Sem conferir, não junto.');
  const [base, head, y, rascunho] = linha.trim().split(' ');
  if (/^(main|master)$/.test(base)) barra('juntar na main é publicar: a IA nunca publica (AGENTS.md §1). A publicação é do dono.');
  if (base !== 'previas') barra(`PR com base ${base}: só se junta na previas.`);
  if (rascunho === 'true') barra('o PR é rascunho: tire do rascunho e espere a CI antes do merge.');
  const esperado = String(ti.expectedHeadSha ?? '');
  if (!/^[0-9a-f]{40}$/i.test(esperado) || esperado.toLowerCase() !== String(y).toLowerCase()) {
    barra(`merge sem expectedHeadSha igual ao último commit do PR (${String(y).slice(0, 7)}), com o SHA inteiro.`);
  }
  const pais = amb.gh(['api', `repos/${repo}/commits/${y}`, '--jq', '.parents[].sha']);
  if (pais === null) barra('não consegui ler o commit anterior ao último do PR.');
  const listaPais = pais.split('\n').filter(Boolean);
  if (listaPais.length !== 1) barra('o último commit do PR tem de ser um só, sobre o commit autorizado.');
  const x = listaPais[0];
  const cmp = amb.gh(['api', `repos/${repo}/compare/${x}...${y}`, '--jq', '.status, (.files[] | .filename + "\t" + .status)']);
  if (cmp === null) barra('não consegui comparar o commit autorizado com o último commit do PR.');
  const [status, ...arquivos] = cmp.split('\n').filter(Boolean);
  if (status !== 'ahead' || arquivos.length !== 1) barra('o último commit do PR tem de mexer num arquivo só: a spec.');
  const [nome, situacao] = arquivos[0].split('\t');
  if (!dec.SPEC.test(nome) || situacao !== 'modified') barra(`o último commit do PR mexe em ${nome}: só vale a linha "Aprovação do merge" da spec.`);
  const ler = (ref) => amb.gh(['api', '-H', 'Accept: application/vnd.github.raw', `repos/${repo}/contents/${nome}?ref=${ref}`]);
  const antes = ler(x);
  const depois = ler(y);
  if (antes === null || depois === null) barra(`não consegui ler ${nome} antes e depois do registro.`);
  if (!dec.mudaSoAprovacaoDoMerge(antes, depois)) barra(`${nome}: o último commit tem de mudar só a linha "Aprovação do merge".`);
  const problemas = dec.problemasDaSpec(depois);
  if (problemas.length) barra(`${nome}: ${problemas.join('; ')}.`);
  const sha = dec.shaCitado(dec.campo(depois, 'Aprovação do merge'));
  if (!x.toLowerCase().startsWith(sha)) barra(`${nome}: a "Aprovação do merge" cita ${sha}, mas o commit autorizado é ${x.slice(0, 7)}.`);
  if (!String(dec.campo(depois, 'Branch') ?? '').includes(`\`${head}\``)) barra(`${nome}: a spec não é a da branch ${head}.`);
  const ciX = ciDe(amb, repo, x);
  if (ciX !== 'verde') barra(ciX === null ? 'não consegui ler a CI do commit autorizado.' : `a CI do commit autorizado (${x.slice(0, 7)}) não está verde (${ciX}).`);
  const ciY = ciDe(amb, repo, y);
  if (ciY === null || ciY === 'vermelha') barra(ciY === null ? 'não consegui ler a CI do último commit.' : `há verificação falhando no último commit (${y.slice(0, 7)}).`);
}

// ---- Workflows: só os que o plano de uma spec da branch lista (AGENTS.md §6, escopo estrito) -------------
// Lido da versão commitada (git show <ref>:...), nunca da cópia de trabalho.
function conferirWorkflow(rel, amb, dec, branch, ref = 'HEAD') {
  const pastas = amb.git(['ls-tree', '-d', '--name-only', `${ref}:specs`]);
  const ok = branch && pastas !== null && pastas.split('\n').filter(Boolean).some((p) => {
    const spec = amb.git(['show', `${ref}:specs/${p}/spec.md`]) ?? '';
    const plano = amb.git(['show', `${ref}:specs/${p}/plan.md`]) ?? '';
    return String(dec.campo(spec, 'Branch') ?? '').includes(`\`${branch}\``) && plano.includes(rel);
  });
  if (!ok) barra(`alterar ${rel}: o plano da spec da branch ${branch || '(desconhecida)'} não lista este arquivo (versão commitada).`);
}

// Migration que já está na previas não se edita (crie outra). Sem conseguir conferir, trata como integrada.
function migrationIntegrada(file, amb) {
  const rel = file.slice(file.indexOf('supabase/migrations/'));
  if (amb.git(['rev-parse', '--verify', '--quiet', 'origin/previas']) === null) return true;
  return amb.git(['cat-file', '-e', `origin/previas:${rel}`]) !== null;
}

// O que um "git push" envia: destinos dos refspecs, ou a branch atual quando não há refspec.
function destinosDoPush(resto, atual) {
  const tokens = resto.trim().split(/\s+/).filter(Boolean).map((t) => t.replace(/^["']|["']$/g, ''));
  const soltos = [];
  for (let i = 0; i < tokens.length; i += 1) {
    const t = tokens[i];
    if (/^\d*[<>]/.test(t)) { if (/^\d*[<>]+$/.test(t)) i += 1; continue; } // redirecionamento
    if (/^(-d|--delete)$/.test(t)) return [];
    if (/^(-o|--push-option|--repo|--receive-pack|--exec)$/.test(t)) { i += 1; continue; }
    if (t.startsWith('-')) continue;
    soltos.push(t);
  }
  const refspecs = soltos.slice(1);
  if (refspecs.length === 0) return atual ? [atual] : [];
  return refspecs
    .map((r) => (r.includes(':') ? r.split(':')[1] : r))
    .filter((d) => d && !d.startsWith('refs/tags/'))
    .map((d) => d.replace(/^refs\/heads\//, ''))
    .map((d) => (d === 'HEAD' ? atual : d))
    .filter(Boolean);
}

function conferirBash(cmd, amb, regras, dec) {
  const PROT = regras.PROTEGIDAS.join('|');
  // "2>&1", ">&2" e "&>" são redirecionamentos, não separadores: viram espaço antes de cortar o comando.
  const semRedir = cmd.replace(/\d*[<>]&(\d+|-)(?![\w/.~-])/g, ' ').replace(/\d*[<>]&/g, ' >').replace(/&>>?/g, ' >').replace(/\d*>\|/g, ' >');
  for (const parte of semRedir.split(/[\n;&|]+/)) {
    const api = /\bgh\s+api\b/.test(parte) || (/\bcurl\b/.test(parte) && /api\.github\.com/.test(parte));
    // Envio (AGENTS.md §8).
    const push = /\bgit\b["']?(\s+-\S+(\s+[^\s-]\S*)?)*\s+push\b(.*)$/.exec(parte);
    if (push) {
      const resto = push[3] ?? '';
      const atual = amb.branch();
      if (new RegExp(`(\\s|:|\\+|["'])(refs/heads/)?(${PROT})(["']|\\s|$)`).test(resto)) barra('envio direto a uma branch protegida. Abra um PR.');
      if (new RegExp(`^(${PROT})$`).test(atual)) barra('envio a partir de uma branch protegida. Crie uma branch de trabalho.');
      if (/\s--(all|branches|mirror|no-verify)(\s|$)/.test(resto) || /core\.hooksPath|push\.default/i.test(parte) || /\s["']?:["']?(\s|$)/.test(resto)) {
        barra('envio de todas as branches ou que pula o gancho de envio.');
      }
      if (/\s--force\S*(\s|$)/.test(resto) || /\s-[a-zA-Z]*f[a-zA-Z]*(\s|$)/.test(resto) || /\s\+\S/.test(resto)) barra('envio forçado.');
      for (const d of destinosDoPush(resto, atual)) if (!regras.nomeValido(d)) barra(`envio de branch fora do padrão (${d}). Use ${regras.PADRAO_TEXTO}.`);
    }
    if (/\bgit\b.*\bconfig\b/.test(parte)) {
      if (/push\.default|remote\.\S*\.(push|mirror)/i.test(parte)) barra('mudar a configuração de envio do git.');
      if (/core\.hooksPath/i.test(parte) && !/core\.hooksPath\s+["']?\.githooks["']?\s*$/i.test(parte.trim())) barra('core.hooksPath só pode apontar para .githooks.');
    }
    if (/\bgit\b.*\breset\b.*--hard\b/.test(parte)) barra('git reset --hard (apaga trabalho sem volta).');
    // Merge só pela ferramenta do MCP, que a trava confere.
    if (/\bgh\s+pr\s+merge\b/.test(parte)) barra('merge pelo gh. O único caminho é a ferramenta de merge do MCP, com expectedHeadSha, que a trava confere.');
    if (api && /merge/i.test(parte)) barra('chamada direta à API do GitHub com "merge". Use a ferramenta de merge do MCP.');
    const escreve = /(\s-X\s*|--method[=\s]+|--request[=\s]+)["']?(POST|PUT|PATCH|DELETE)/i.test(parte)
      || (/\bgh\s+api\b/.test(parte) && /\s(-f|-F|--field|--raw-field|--input)(\s|=)/.test(parte) && !/(\s-X\s*|--method[=\s]+)["']?GET/i.test(parte))
      || (/\bcurl\b/.test(parte) && /\s(-d|--data\S*)(\s|=)/.test(parte));
    if (api && escreve && (/git\/refs|\/contents\/|\/merges\b/.test(parte) || new RegExp(`\\b(${PROT})\\b`).test(parte))) {
      barra('escrita direta pela API do GitHub numa branch (equivale a envio direto). Use branch de trabalho e PR.');
    }
    if (api && escreve && /\/rulesets\b|\/branches\/[^/\s]+\/protection\b/.test(parte)) {
      barra('mudar ou apagar a proteção de branch (ruleset) pela API. Configuração do repositório é do dono.');
    }
    if (/\bgh\s+pr\s+create\b/.test(parte) && /--base[=\s]+["']?(main|master)\b/.test(parte) && !/--head[=\s]+["']?previas\b/.test(parte)) {
      barra('PR de branch de trabalho para a main. A base é a previas.');
    }
    // Publicar (AGENTS.md §1).
    if (/\bwrangler(@\S+)?\s+((versions|pages)\s+)?deploy\b/.test(parte) && !/--dry-run/.test(parte)) barra('publicar à mão. A IA nunca publica.');
    if (/\b(pnpm|npm|yarn)\s+(run\s+)?deploy\b/.test(parte)) barra('publicar à mão. A IA nunca publica.');
    // Banco remoto (AGENTS.md §1): o banco só muda pela CI.
    if (/\bsupabase\b.*\b(link|db\s+(push|pull|execute|remote)|migration\s+repair)\b/.test(parte) || /\bsupabase\b.*(--linked|--remote|--db-url)/.test(parte)) {
      barra('comando do Supabase contra banco remoto. Só o banco local (pnpm db:start, db:test).');
    }
    if (/\bpsql\b/.test(parte)) {
      const variaveis = [...parte.matchAll(/\$\{?(\w+)/g)].map((m) => m[1]);
      const remota = variaveis.some((v) => /URL|DSN|CONN/i.test(v) && !/LOCAL/i.test(v));
      if (remota || /supabase\.(co|com)/.test(parte) || /postgres(ql)?:\/\/(?![^\s/]*@?(localhost|127\.0\.0\.1))/.test(parte)) barra('psql contra banco remoto. Só banco local.');
    }
    // Segredos (AGENTS.md §6): ler pela linha de comando ou gravar por redirecionamento.
    const palavras = parte.replace(/--exclude(-dir)?=?\S+/g, ' ').split(/[\s<>"'=(),;`]+/).filter(Boolean).map((p) => p.replace(/^.*[/\\]/, ''));
    const nomes = parte.trim().split(/\s+/).filter((p) => !/^\w+=/.test(p));
    const leitor = /^(cat|less|more|head|tail|grep|rg|bat|awk|sed|source|\.|xxd|od|strings|base64|cp|nl|diff|tac|sort|wc)$/.test((nomes[0] ?? '').replace(/^.*[/\\]/, ''));
    if ((leitor || /<\s*\S/.test(parte)) && palavras.some(ehSegredo)) barra('leitura de arquivo de segredos (.env). Segredo nunca na conversa.');
    if (/>\s*["']?\S*\.env(\.(?!example)\w+)?["']?(\s|$)/.test(parte)) barra('gravar arquivo de segredos (.env). Segredo nunca no repositório.');
    if (/\brm\s+-(?=[a-zA-Z]*[rR])(?=[a-zA-Z]*f)[a-zA-Z]+\s+(\/|~\/?|\.\/?|\*)(\s|$)/.test(parte)) barra('remoção ampla de arquivos.');
    if (/\bsed\b[^|]*\s-i/.test(parte) && /supabase\/migrations\//.test(parte)) barra('edição de migration pela linha de comando. Use a ferramenta de edição.');
    const gravaWorkflow = /(^|\s)(tee|cp|mv|rm|install|truncate|ln)\s|\bsed\b[^|]*\s-i|\bgit\b.*\s(rm|mv|checkout|restore)\s|>\s*["']?[^\s>]*\.github\/workflows\//;
    if (/\.github\/workflows\//.test(parte) && gravaWorkflow.test(parte)) {
      for (const m of parte.matchAll(/\.github\/workflows\/[\w.\-/]*/g)) conferirWorkflow(m[0], amb, dec, amb.branch());
    }
    // Gravar nas travas pela linha de comando: comando que grava citando a trava, ou redirecionamento para ela.
    const gravaComando = /(^|\s)(tee|cp|mv|rm|install|truncate|ln|chmod)\s|\bsed\b[^|]*\s-i|\bgit\b.*\s(rm|mv|checkout|restore)\s/;
    const alvosRedir = [...parte.matchAll(/>+\s*["']?([^\s"'>]+)/g)].map((m) => m[1]);
    if ((gravaComando.test(parte) && parte.split(/[\s<>"'=]+/).some(ehTrava)) || alvosRedir.some(ehTrava)) {
      barra('gravar nas travas do projeto (.claude/settings*.json, .claude/hooks, .githooks). Só o dono muda.');
    }
  }
}

// Confere uma chamada de ferramenta. Barra lançando Barrado; volta normal quando passa.
export function conferir(input, amb, regras, dec) {
  const tool = String(input?.tool_name ?? '');
  const ti = input?.tool_input && typeof input.tool_input === 'object' ? input.tool_input : {};
  const PROT = new RegExp(`^(refs/heads/)?(${regras.PROTEGIDAS.join('|')})$`);

  if (MCP_BANCO.test(tool)) barra('gravação direta no banco pelo MCP. O banco só muda por migration aplicada pela CI (AGENTS.md §1).');
  if (MCP_CLOUDFLARE.test(tool)) barra('alteração na Cloudflare pelo MCP. A IA nunca publica (AGENTS.md §1).');
  if (mcpRemotoQueMuda(tool)) barra(`${tool}: muda o remoto ou publica pelo MCP. A IA nunca publica nem muda o banco remoto (AGENTS.md §1).`);
  if (MCP_GRAVA_BRANCH.test(tool) && (ti.owner || ti.repo || ti.branch)) {
    const b = String(ti.branch ?? '').replace(/^refs\/heads\//, '');
    if (!b || PROT.test(b)) barra('gravação direta numa branch protegida pelo MCP do GitHub. Use branch de trabalho e PR.');
    if (!regras.nomeValido(b)) barra(`gravação numa branch fora do padrão (${b}). Use ${regras.PADRAO_TEXTO}.`);
    const caminhos = [ti.path, ...(Array.isArray(ti.files) ? ti.files.map((f) => f?.path) : [])].filter((c) => typeof c === 'string');
    for (const c of caminhos) {
      if (ehSegredo(c)) barra('arquivo de segredos (.env). Segredo nunca no repositório.');
      if (ehTrava(c)) barra('gravar nas travas do projeto pelo MCP. Só o dono muda.');
      if (WORKFLOW.test(c)) conferirWorkflow(relWorkflow(c), amb, dec, b, `refs/remotes/origin/${b}`);
    }
  }
  if (MCP_ABRE_PR.test(tool) && /^(main|master)$/.test(String(ti.base ?? '')) && String(ti.head ?? '') !== 'previas') barra('PR de branch de trabalho para a main. A base é a previas.');
  if (MCP_MERGE_AUTOMATICO.test(tool)) barra('merge automático. O merge sai depois da autorização do dono, pela ferramenta de merge, que a trava confere.');
  if (MCP_FUNDE_PR.test(tool)) conferirMerge(ti, amb, dec);

  if (tool === 'Bash') conferirBash(String(ti.command ?? ''), amb, regras, dec);

  if (['Read', 'Grep', 'Glob'].includes(tool)) {
    const alvos = [ti.file_path, ti.path, ti.glob, tool === 'Glob' ? ti.pattern : undefined].filter((v) => typeof v === 'string');
    if (alvos.some(ehSegredo)) barra('leitura de arquivo de segredos (.env). Segredo nunca na conversa.');
  }
  if (['Write', 'Edit', 'MultiEdit', 'NotebookEdit'].includes(tool)) {
    const file = String(ti.file_path ?? ti.notebook_path ?? '');
    if (ehSegredo(file)) barra('arquivo de segredos (.env). Segredo nunca no repositório.');
    if (ehTrava(file)) barra('gravar nas travas do projeto (.claude/settings*.json, .claude/hooks, .githooks). A trava não se desliga sozinha: só o dono muda.');
    if (/supabase\/migrations\//.test(file.replace(/\\/g, '/')) && migrationIntegrada(file.replace(/\\/g, '/'), amb)) barra('edição de migration que já está na previas. Crie uma migration nova.');
    if (WORKFLOW.test(file)) conferirWorkflow(relWorkflow(file), amb, dec, amb.branch());
  }
}

// Ambiente real: git na pasta do projeto e gh com prazo total abaixo dos 120 s do hook.
export function ambienteReal(raiz) {
  const inicio = Date.now();
  const roda = (bin, args, ms) => {
    try { return execFileSync(bin, args, { cwd: raiz, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: ms }).trim(); } catch { return null; }
  };
  return {
    git: (args) => roda('git', args, 3000),
    gh: (args) => { const resta = 90000 - (Date.now() - inicio); return resta < 2000 ? null : roda('gh', args, Math.min(15000, resta)); },
    branch: () => roda('git', ['rev-parse', '--abbrev-ref', 'HEAD'], 3000) ?? '',
  };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const sai = (motivo) => { process.stderr.write(`Bloqueado pela trava do projeto: ${motivo}\n`); process.exit(2); };
  process.on('uncaughtException', (e) => sai(`a trava falhou (${String(e?.message ?? e).slice(0, 100)}). Avise o dono.`));
  process.on('unhandledRejection', (e) => sai(`a trava falhou (${String(e?.message ?? e).slice(0, 100)}). Avise o dono.`));
  const raiz = process.env.CLAUDE_PROJECT_DIR ?? process.cwd();
  let raw = '';
  process.stdin.on('data', (c) => (raw += c));
  process.stdin.on('end', async () => {
    let regras;
    let dec;
    try {
      regras = await import(pathToFileURL(join(raiz, '.githooks', 'pre-push.mjs')).href);
      dec = await import(new URL('./decisao-com-prova.mjs', import.meta.url).href);
      if (!Array.isArray(regras.PROTEGIDAS) || typeof regras.nomeValido !== 'function' || typeof dec.problemasDaSpec !== 'function') throw new Error('regras incompletas');
    } catch (e) {
      sai(`a trava não conseguiu carregar as regras (${String(e?.message ?? e).slice(0, 100)}). Avise o dono.`);
    }
    let input;
    // Entrada ilegível ou que não é objeto: barra (falhar fechado; ISO 31000).
    try { input = JSON.parse(raw); } catch { sai('entrada ilegível; sem conferir, não deixo passar.'); }
    if (input === null || typeof input !== 'object' || Array.isArray(input)) sai('entrada ilegível; sem conferir, não deixo passar.');
    try {
      conferir(input, ambienteReal(raiz), regras, dec);
    } catch (e) {
      sai(e instanceof Barrado ? e.message : `a trava falhou ao conferir (${String(e?.message ?? e).slice(0, 100)}). Avise o dono.`);
    }
    process.exit(0);
  });
}
