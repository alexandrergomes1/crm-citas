#!/usr/bin/env node
// Início de sessão (SessionStart), enxuto (spec: .claude/hooks/TRAVAS.md §6). Imprime só: branch e
// commit · próxima tarefa (1º item livre da fila) · pergunta pendente dessa tarefa (ou a 1ª de
// docs/OWNER.md) · PRs com o rótulo aguardando-merge (esperando a autorização do dono) · avisos
// (plugin sem decisão, pacote faltando, conversa resumida). Até 1.500 caracteres. Sem regras: as
// regras são o AGENTS.md. Nunca derruba a sessão: em erro, diz o que não conseguiu ler e sai com 0.
// Só lê o GitHub para listar os PRs com o rótulo (tempo curto; falhou, vira aviso).
// Testes: node .claude/hooks/inicio-de-sessao.test.mjs
import { execFileSync } from 'node:child_process';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const LIMITE = 1500; // caracteres; a saída entra em toda conversa
const raiz = process.env.CLAUDE_PROJECT_DIR ?? process.cwd();
const naoLidos = [];
const resumida = process.argv.includes('--resumida');

// De onde se leu: a versão da branch de integração (commit e data) ou o disco. Se a cópia estiver
// velha, isto aparece na primeira linha.
function origem() {
  if (process.env.INICIO_SEM_GIT) return 'arquivo local';
  try {
    const v = execFileSync('git', ['log', '-1', '--format=%h %cs', 'origin/previas'], {
      cwd: raiz, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 3000,
    }).trim();
    return v ? `previas ${v}` : 'arquivo local';
  } catch {
    return 'arquivo local';
  }
}

// Primeira pergunta à espera do dono, em docs/OWNER.md (seção "Perguntas à sua espera").
function primeiraPergunta(dono) {
  const linhas = dono.split('\n');
  const ini = linhas.findIndex((l) => /^##\s+Perguntas/.test(l));
  if (ini < 0) return '';
  const item = linhas.slice(ini + 1).find((l) => /^\d+\.\s/.test(l));
  return item ? item.replace(/^\d+\.\s+/, '').trim() : '';
}

// Lê a cópia local da branch de integração quando existe (mais atual que a branch de trabalho);
// senão, o arquivo em disco. INICIO_SEM_GIT=1 força o disco (usado nos testes).
function ler(rel, opcional = false) {
  if (!process.env.INICIO_SEM_GIT) {
    try {
      return execFileSync('git', ['show', `origin/previas:${rel}`], {
        cwd: raiz, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 3000,
      });
    } catch { /* sem a referência local: cai para o disco */ }
  }
  try {
    return readFileSync(join(raiz, rel), 'utf8');
  } catch {
    if (!opcional) naoLidos.push(rel);
    return '';
  }
}

// Pacotes de método que a revisão, a crítica e a entrega usam como reforço, nunca como portão (lista e como ligar: docs/reference/project.md,
// "Pacotes de ferramentas"). Na nuvem eles só chegam se estiverem ligados na conta do claude.ai; o
// settings.json do repositório não os instala. Procura o nome de cada peça nos pacotes do disco.
const PACOTES = {
  'design-skills': ['design-critique', 'accessibility-audit', 'interaction-design', 'ux-writing', 'design-systems', 'design-ops'],
  Design: ['design-handoff'],
  Superpowers: ['verification-before-completion', 'systematic-debugging', 'brainstorming', 'writing-plans'],
  'commit-commands': ['commit'],
  'Backend Design': ['explain-this-query', 'hunt-n-plus-one'],
};

// Nomes de peças encontrados: pasta com SKILL.md, ou arquivo .md dentro de agents/ ou commands/.
// Segue link simbólico (skills costumam ser links). Cada pasta raiz tem o próprio limite de entradas.
function pecasNoDisco(raizes) {
  const nomes = new Set();
  let visitados = 0;
  const andar = (dir, nivel, pai) => {
    if (nivel > 9 || visitados > 20000) return;
    let itens;
    try { itens = readdirSync(dir, { withFileTypes: true }); } catch { return; }
    for (const it of itens) {
      visitados += 1;
      let pasta = it.isDirectory();
      if (it.isSymbolicLink()) { try { pasta = statSync(join(dir, it.name)).isDirectory(); } catch { continue; } }
      if (pasta) {
        if (it.name === 'node_modules' || it.name === '.git') continue;
        andar(join(dir, it.name), nivel + 1, it.name);
      } else if (it.name === 'SKILL.md') {
        nomes.add(dir.split(/[\\/]/).pop());
      } else if (/\.md$/.test(it.name) && (pai === 'agents' || pai === 'commands')) {
        nomes.add(it.name.replace(/\.md$/, ''));
      }
    }
  };
  for (const r of raizes) { visitados = 0; andar(r, 0, ''); }
  return nomes;
}

// INICIO_PACOTES_DIR troca as pastas procuradas (usado nos testes). Vazio = sem conferência.
function pacotesFaltando() {
  const env = process.env.INICIO_PACOTES_DIR;
  const raizes = env !== undefined ? env.split(':').filter(Boolean) : [join(homedir(), '.claude', 'plugins'), join(homedir(), '.claude', 'skills')];
  if (raizes.length === 0) return [];
  const achados = pecasNoDisco(raizes);
  return Object.entries(PACOTES)
    .map(([pacote, pecas]) => [pacote, pecas.filter((p) => !achados.has(p))])
    .filter(([, faltam]) => faltam.length > 0)
    .map(([pacote]) => pacote);
}

// Plugins da conta que o .claude/settings.json ainda não decide (nem true nem false em enabledPlugins):
// plugin novo, que entra ligado neste projeto até alguém decidir. Lê o nome no plugin.json de cada
// pasta sincronizada. INICIO_SYNCED_DIR troca a pasta (testes); vazio = sem conferência. Na 1ª abertura
// a cópia pode terminar depois deste hook; o /clear seguinte confere de novo. O settings é lido do disco
// (não da branch de integração, como ler()): é a cópia que o Claude Code aplica nesta sessão.
function pluginsSemDecisao() {
  const env = process.env.INICIO_SYNCED_DIR;
  const base = env !== undefined ? env : join(homedir(), '.claude', 'plugins', 'synced');
  if (!base) return [];
  let decididos;
  try {
    decididos = Object.keys(JSON.parse(readFileSync(join(raiz, '.claude', 'settings.json'), 'utf8')).enabledPlugins ?? {});
  } catch { return []; }
  const nomes = new Set();
  const pastas = (dir) => { try { return readdirSync(dir, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => join(dir, d.name)); } catch { return []; } };
  for (const org of pastas(base)) {
    for (const p of pastas(org)) {
      try { const n = JSON.parse(readFileSync(join(p, '.claude-plugin', 'plugin.json'), 'utf8')).name; if (n) nomes.add(n); } catch { /* sem manifesto */ }
    }
  }
  return [...nomes].filter((n) => !decididos.includes(`${n}@synced`)).sort();
}

// O que fazer quando faltam pacotes. Na nuvem há dois casos, medidos em 20/11/2026 (ADR de 20/11/2026 no repositório antigo crm-agenda):
// conversa aberta pelo dono recebe CLAUDE_CODE_SYNC_PLUGINS=1 e a cópia dos pacotes termina em até ~2 min, depois deste hook;
// conversa criada por outra conversa não tem a variável e nunca recebe os pacotes. Fora da nuvem vale o texto de sempre.
function comoResolver() {
  // Só "true" conta como nuvem (valor medido); "", "0" ou "false" caem no texto de sempre.
  const nuvem = process.env.CLAUDE_CODE_REMOTE === 'true';
  const copiaLigada = ['1', 'true'].includes(String(process.env.CLAUDE_CODE_SYNC_PLUGINS ?? '').toLowerCase());
  if (nuvem && !copiaLigada) {
    return 'Esta conversa nasceu sem receber os plugins da conta (acontece nas conversas criadas por outra conversa, não nas que o dono abre pelo botão Nova conversa). Não adianta esperar: avise o dono na 1ª mensagem e peça que abra a conversa pelo botão Nova conversa (CLAUDE.md, Conversas)';
  }
  if (nuvem) {
    return 'Pode ser a cópia ainda em andamento (leva até 2 min): espere, rode este início de novo e só avise o dono se o aviso continuar; se a cópia já terminou, o pacote não está ligado na conta e o dono clica Add (docs/reference/project.md, "Pacotes de ferramentas")';
  }
  return 'Avise o dono na 1ª mensagem (docs/reference/project.md, "Pacotes de ferramentas")';
}

const corta = (txt, max) => (txt.length > max ? `${txt.slice(0, max).trimEnd()} […]` : txt);

// A tarefa é o primeiro item numerado que não está riscado (~~texto~~), seja qual for o número.
// Item concluído fica riscado na fila; não se renumera, porque os itens se citam pelo número.
function proximoItem(fila) {
  const todas = fila.split('\n');
  // A lista de tarefas começa no título "## Agora" (antes dele há regras numeradas que não são tarefas).
  const agora = todas.findIndex((l) => l.trim() === '## Agora');
  const linhas = agora >= 0 ? todas.slice(agora + 1) : todas;
  const ehItem = (l) => /^(~~)?\d+\.\s/.test(l);
  // Riscado é o item cujo título começa riscado ("1. ~~texto" ou "1. **~~texto"). Um trecho riscado
  // no meio de um item em aberto não o fecha.
  const riscado = (l) => /^\d+\.\s+(\*\*)?~~/.test(l);
  const ini = linhas.findIndex((l) => /^\d+\.\s/.test(l) && !riscado(l));
  if (ini < 0) return '';
  const bloco = [linhas[ini]];
  for (const l of linhas.slice(ini + 1)) {
    if (ehItem(l) || l.startsWith('#')) break;
    bloco.push(l);
  }
  return bloco.join('\n').trim();
}

// Branch e commit desta cópia. INICIO_SEM_GIT: sem git (testes).
function ondeEstou() {
  if (process.env.INICIO_SEM_GIT) return 'sem git';
  try {
    return execFileSync('git', ['log', '-1', '--format=%D|%h', 'HEAD'], { cwd: raiz, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 3000 })
      .trim().replace(/^HEAD -> ([^,|]+)[^|]*\|/, 'branch $1 · commit ').replace(/^[^|]*\|/, 'commit ');
  } catch { return 'sem git'; }
}

// PRs abertos com o rótulo aguardando-merge: pedido de merge esperando a autorização do dono
// (docs/guias/git-e-deploy.md §Merge de tarefa). Lê o GitHub com tempo curto; sem conseguir, devolve null
// (vira aviso). INICIO_GH_TESTE: lista separada por vírgula, ou "erro" (testes).
function prsAguardandoMerge() {
  const teste = process.env.INICIO_GH_TESTE;
  if (teste !== undefined) return teste === 'erro' ? null : teste.split(',').filter(Boolean);
  if (process.env.INICIO_SEM_GIT) return [];
  try {
    return execFileSync('gh', ['api', 'repos/alexandrergomes1/crm-citas/pulls?state=open&per_page=100', '--jq',
      '.[] | select([.labels[].name] | index("aguardando-merge")) | "#\\(.number) \\(.head.ref)"'],
    { cwd: raiz, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 6000 }).split('\n').filter(Boolean);
  } catch { return null; }
}

try {
  const fila = ler('docs/BACKLOG.md');
  const pergunta = primeiraPergunta(ler('docs/OWNER.md', true));
  const um = proximoItem(fila);

  // Os avisos vão logo depois do título, para o corte de tamanho nunca os remover.
  const avisos = [];
  if (resumida) avisos.push('conversa resumida: detalhes podem ter se perdido; confira docs/STATUS.md e a fila e proponha o /clear');
  if (naoLidos.length) avisos.push(`não consegui ler ${naoLidos.join(', ')}`);
  if (fila && !um) avisos.push('docs/BACKLOG.md não tem item em aberto');
  let faltam = [];
  try { faltam = pacotesFaltando(); } catch { avisos.push('não consegui conferir os pacotes de método'); }
  let novos = [];
  try { novos = pluginsSemDecisao(); } catch { /* aviso opcional: nunca derruba */ }
  if (novos.length) avisos.push(`plugin da conta sem decisão neste projeto (entra ligado): ${novos.slice(0, 3).join(', ')}${novos.length > 3 ? ` e mais ${novos.length - 3}` : ''}. Avise o dono em uma linha`);
  if (faltam.length) avisos.push(`FALTAM pacotes de método: ${faltam.join(', ')}. O trabalho segue com as listas do repositório; o que dependia deles sai como "não verificado". ${comoResolver()}`);
  const aguardando = prsAguardandoMerge();
  if (aguardando === null) avisos.push('não consegui listar os PRs com o rótulo aguardando-merge no GitHub');

  const partes = [`# crm-citas: início de sessão (${ondeEstou()}; lido de ${origem()})`];
  if (avisos.length) partes.push(`AVISO do hook de início: ${avisos.join('; ')}.`);
  partes.push(`## Próxima tarefa (primeiro item não riscado de docs/BACKLOG.md)\n${um ? corta(um, 600) : 'Fila sem item em aberto: pergunte ao dono do projeto o que fazer; não invente tarefa.'}`);
  // A pergunta da tarefa já vem no texto do item; sem ela, a primeira de docs/OWNER.md.
  if (pergunta && !/pergunta|aguardando escolha|bloquead/i.test(um)) partes.push(`## Pergunta à espera do dono (docs/OWNER.md)\n${corta(pergunta, 220)}`);
  if (aguardando?.length) partes.push(`## Esperando a autorização do dono (rótulo aguardando-merge)\n${corta(aguardando.join(', '), 220)}`);

  process.stdout.write(`${corta(partes.join('\n\n'), LIMITE)}\n`);
} catch (erro) {
  process.stdout.write(`AVISO do hook de início: falhou (${String(erro?.message ?? erro).slice(0, 120)}). Leia docs/BACKLOG.md e docs/OWNER.md à mão.\n`);
}
process.exit(0);
