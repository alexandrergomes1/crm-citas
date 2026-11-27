#!/usr/bin/env node
// Testa o hook de início em pastas temporárias: arquivos presentes, ausentes e malformados.
// Uso: node .claude/hooks/inicio-de-sessao.test.mjs   (sai com 1 se algum caso falhar)
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const hook = join(dirname(fileURLToPath(import.meta.url)), 'inicio-de-sessao.mjs');

function rodar(arquivos, args = [], envExtra = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'inicio-'));
  for (const [rel, conteudo] of Object.entries(arquivos)) {
    mkdirSync(dirname(join(dir, rel)), { recursive: true });
    // Valor { link: 'alvo' } cria um link simbólico para a pasta alvo (relativa à pasta do teste).
    if (conteudo && typeof conteudo === 'object') symlinkSync(join(dir, conteudo.link), join(dir, rel), 'dir');
    else writeFileSync(join(dir, rel), conteudo);
  }
  const r = spawnSync('node', [hook, ...args], {
    encoding: 'utf8',
    // Pacotes de método: só os casos que criam "pacotes/..." conferem; os outros não procuram nada.
    // CLAUDE_CODE_REMOTE e CLAUDE_CODE_SYNC_PLUGINS vazios por padrão: o resultado não depende de onde o teste roda.
    env: { ...process.env, CLAUDE_PROJECT_DIR: dir, INICIO_SEM_GIT: '1', CLAUDE_CODE_REMOTE: '', CLAUDE_CODE_SYNC_PLUGINS: '',
      INICIO_PACOTES_DIR: Object.keys(arquivos).some((k) => k.startsWith('pacotes/')) ? join(dir, 'pacotes') : '',
      // Plugins da conta: só os casos que criam "synced/..." conferem.
      INICIO_SYNCED_DIR: Object.keys(arquivos).some((k) => k.startsWith('synced/')) ? join(dir, 'synced') : '', ...envExtra },
  });
  rmSync(dir, { recursive: true, force: true });
  return r;
}

const fila = '# Fila\n\n1. **Primeira tarefa.** NÃO CONSTRUIR.\n   Detalhe da primeira.\n2. Segunda tarefa.\n';
const estado = '# Estado\n\n## Ponto de partida\nTrabalho parou em X.\n\n## Feito\nNada.\n';

const casos = [
  ['tudo presente', { 'docs/BACKLOG.md': fila, 'docs/STATUS.md': estado },
    (s) => s.includes('Primeira tarefa') && s.includes('Detalhe da primeira') && !s.includes('Segunda tarefa')
      && !s.includes('Trabalho parou em X') && !s.includes('P-01') && !s.includes('AVISO') && !s.includes('aguardando-merge')],
  ['PRs com o rótulo aguardando-merge aparecem', { 'docs/BACKLOG.md': fila },
    (s) => s.includes('aguardando-merge') && s.includes('autorização do dono') && s.includes('#140 feat/agenda-filtro') && !s.includes('decisões juntadas') && !s.includes('Juntadas'), [],
    { INICIO_GH_TESTE: '#140 feat/agenda-filtro' }],
  ['sem PR aguardando: não imprime a seção', { 'docs/BACKLOG.md': fila },
    (s) => !s.includes('aguardando-merge') && s.includes('Primeira tarefa'), [], { INICIO_GH_TESTE: '' }],
  ['GitHub fora do ar: avisa e segue', { 'docs/BACKLOG.md': fila },
    (s) => s.includes('não consegui listar os PRs com o rótulo aguardando-merge') && s.includes('Primeira tarefa'), [], { INICIO_GH_TESTE: 'erro' }],
  ['diz branch e commit na primeira linha', { 'docs/BACKLOG.md': fila },
    (s) => s.split('\n')[0].includes('sem git')],
  ['pergunta da tarefa no item: não repete a do OWNER', { 'docs/BACKLOG.md': '# Fila\n\n1. Tarefa X. **Aguardando escolha:** pergunta P1.\n', 'docs/OWNER.md': '## Perguntas à sua espera\n1. **Outra:** (A)?\n' },
    (s) => s.includes('pergunta P1') && !s.includes('Outra:')],
  ['nenhum arquivo', {},
    (s) => s.includes('Fila sem item em aberto') && s.includes('AVISO') && s.includes('docs/BACKLOG.md')],
  ['fila sem item 1', { 'docs/BACKLOG.md': '# Fila\n\nsem itens\n', 'docs/STATUS.md': estado },
    (s) => s.includes('Fila sem item em aberto') && s.includes('AVISO') && s.includes('não tem item em aberto')],
  ['aviso sobrevive ao corte de tamanho', { 'docs/BACKLOG.md': `1. ${'x'.repeat(5000)}\n` },
    (s) => s.length <= 1520 && s.includes('AVISO') && s.includes('não consegui listar'), [], { INICIO_GH_TESTE: 'erro' }],
  ['item 1 riscado: imprime o próximo', { 'docs/BACKLOG.md': '# Fila\n\n1. ~~Primeira tarefa.~~\n   feita no PR 9\n2. **Segunda tarefa.**\n   detalhe da segunda\n3. Terceira.\n', 'docs/STATUS.md': estado },
    (s) => s.includes('Segunda tarefa') && s.includes('detalhe da segunda') && !s.includes('Primeira tarefa') && !s.includes('Terceira') && !s.includes('AVISO')],
  ['item riscado com o til antes do número', { 'docs/BACKLOG.md': '# Fila\n\n~~1. Primeira.~~\n2. Segunda tarefa.\n', 'docs/STATUS.md': estado },
    (s) => s.includes('Segunda tarefa') && !s.includes('Primeira')],
  ['todos riscados: avisa', { 'docs/BACKLOG.md': '# Fila\n\n1. ~~Primeira.~~\n', 'docs/STATUS.md': estado },
    (s) => s.includes('Fila sem item em aberto') && s.includes('AVISO')],
  ['regras numeradas antes de "## Agora" não são tarefa', { 'docs/BACKLOG.md': '# Fila\n\n## Pronto para começar\n1. tem spec ligada\n2. cabe em um PR\n\n## Agora\n\n1. **Tarefa de verdade.**\n   detalhe\n', 'docs/STATUS.md': estado },
    (s) => s.includes('Tarefa de verdade') && !s.includes('tem spec ligada')],
  ['item aberto com um trecho riscado no meio continua sendo a tarefa', { 'docs/BACKLOG.md': '# Fila\n\n## Agora\n\n1. ~~Primeira.~~\n2. Segunda: (a) ~~parte feita~~ (b) parte que falta · próxima\n3. Terceira.\n', 'docs/STATUS.md': estado },
    (s) => s.includes('parte que falta') && !s.includes('Terceira')],
  ['item riscado com negrito', { 'docs/BACKLOG.md': '# Fila\n\n## Agora\n\n1. **~~Primeira.~~**\n2. Segunda tarefa.\n', 'docs/STATUS.md': estado },
    (s) => s.includes('Segunda tarefa') && !s.includes('Primeira')],
  ['diz de onde leu', { 'docs/BACKLOG.md': fila, 'docs/STATUS.md': estado },
    (s) => s.split('\n')[0].includes('arquivo local')],
  ['imprime a primeira pergunta do dono', { 'docs/BACKLOG.md': fila, 'docs/STATUS.md': estado, 'docs/OWNER.md': '# Dono\n\n## Perguntas à sua espera\nUma por conversa.\n\n1. **Idiomas:** (A) ou (B)?\n2. Outra pergunta.\n' },
    (s) => s.includes('Idiomas') && !s.includes('Outra pergunta')],
  ['sem docs/OWNER.md não reclama da pergunta', { 'docs/BACKLOG.md': fila, 'docs/STATUS.md': estado },
    (s) => !s.includes('Pergunta à espera')],
  ['depois de resumo automático avisa no topo', { 'docs/BACKLOG.md': fila, 'docs/STATUS.md': estado },
    (s) => s.includes('conversa resumida') && s.indexOf('conversa resumida') < s.indexOf('Próxima tarefa'), ['--resumida']],
  ['início normal não avisa resumo', { 'docs/BACKLOG.md': fila, 'docs/STATUS.md': estado },
    (s) => !s.includes('conversa resumida')],
  ['arquivos malformados', { 'docs/BACKLOG.md': '\u0000\u0001||||', 'docs/OWNER.md': '|||\n| a |\n' },
    (s) => s.includes('Fila sem item em aberto')],
  ['arquivos enormes respeitam o limite', { 'docs/BACKLOG.md': `1. ${'x'.repeat(5000)}\n`, 'docs/STATUS.md': estado },
    (s) => s.length <= 1520],
  ['sem nenhum pacote de método: avisa no topo, com os nomes', { 'docs/BACKLOG.md': fila, 'docs/STATUS.md': estado, 'pacotes/.vazio': '' },
    (s) => s.includes('FALTAM pacotes') && s.includes('design-skills') && s.includes('Superpowers') && s.indexOf('FALTAM') < s.indexOf('Próxima tarefa')],
  ['pacote faltando não bloqueia: o trabalho segue como "não verificado"', { 'docs/BACKLOG.md': fila, 'docs/STATUS.md': estado, 'pacotes/.vazio': '' },
    (s) => s.includes('O trabalho segue') && s.includes('não verificado') && !s.includes('pare antes') && !s.includes('não se entrega')],
  ['com todos os pacotes: não avisa', { 'docs/BACKLOG.md': fila, 'docs/STATUS.md': estado, ...todosOsPacotes() },
    (s) => !s.includes('FALTAM') && !s.includes('AVISO')],
  ['falta só um pacote: cita só ele', { 'docs/BACKLOG.md': fila, 'docs/STATUS.md': estado, ...todosOsPacotes('design-handoff') },
    (s) => s.includes('FALTAM pacotes de método: Design.') && !s.includes('design-skills')],
  ['peça dentro de link simbólico conta', { 'docs/BACKLOG.md': fila, 'docs/STATUS.md': estado,
    ...todosOsPacotes('design-critique'), 'real/design-critique/SKILL.md': 'x', 'pacotes/skills/design-critique': { link: 'real/design-critique' } },
    (s) => !s.includes('FALTAM')],
  ['.md fora de agents/ e commands/ não conta', { 'docs/BACKLOG.md': fila, 'docs/STATUS.md': estado,
    ...todosOsPacotes('commit'), 'pacotes/synced/x/cmd/docs/commit.md': 'x' },
    (s) => s.includes('FALTAM pacotes de método: commit-commands.')],
  ['pasta de pacotes inexistente: avisa e não quebra', { 'docs/BACKLOG.md': fila, 'docs/STATUS.md': estado, 'pacotes/../outra/.x': '' },
    (s) => s.includes('FALTAM pacotes') && s.includes('Primeira tarefa')],
  ['aviso de pacotes sobrevive ao corte de tamanho', { 'docs/BACKLOG.md': `1. ${'x'.repeat(5000)}\n`, 'docs/STATUS.md': estado, 'pacotes/.vazio': '' },
    (s) => s.length <= 1520 && s.includes('FALTAM pacotes') && s.includes('Backend Design')],
  ['nuvem sem a variável de cópia: diz que nasceu sem plugins e manda o dono abrir a conversa', { 'docs/BACKLOG.md': fila, 'docs/STATUS.md': estado, 'pacotes/.vazio': '' },
    (s) => s.includes('FALTAM pacotes') && s.includes('nasceu sem receber os plugins') && s.includes('botão Nova conversa') && s.includes('CLAUDE.md, Conversas') && !s.includes('process.md') && !s.includes('ainda em andamento'), [], { CLAUDE_CODE_REMOTE: 'true' }],
  ['nuvem com a variável de cópia: diz para esperar a cópia', { 'docs/BACKLOG.md': fila, 'docs/STATUS.md': estado, 'pacotes/.vazio': '' },
    (s) => s.includes('FALTAM pacotes') && s.includes('ainda em andamento') && !s.includes('nasceu sem'), [], { CLAUDE_CODE_REMOTE: 'true', CLAUDE_CODE_SYNC_PLUGINS: '1' }],
  ['fora da nuvem: mantém o texto de sempre', { 'docs/BACKLOG.md': fila, 'docs/STATUS.md': estado, 'pacotes/.vazio': '' },
    (s) => s.includes('FALTAM pacotes') && s.includes('Pacotes de ferramentas') && !s.includes('nasceu sem') && !s.includes('ainda em andamento')],
  ['nuvem com a variável de cópia valendo "true": também espera a cópia', { 'docs/BACKLOG.md': fila, 'docs/STATUS.md': estado, 'pacotes/.vazio': '' },
    (s) => s.includes('ainda em andamento') && !s.includes('nasceu sem'), [], { CLAUDE_CODE_REMOTE: 'true', CLAUDE_CODE_SYNC_PLUGINS: 'true' }],
  ['CLAUDE_CODE_REMOTE valendo "false": é local, não diz que nasceu sem plugins', { 'docs/BACKLOG.md': fila, 'docs/STATUS.md': estado, 'pacotes/.vazio': '' },
    (s) => s.includes('FALTAM pacotes') && s.includes('Pacotes de ferramentas') && !s.includes('nasceu sem') && !s.includes('ainda em andamento'), [], { CLAUDE_CODE_REMOTE: 'false' }],
  ['depois de resumo propõe /clear ou conversa aberta pelo dono', { 'docs/BACKLOG.md': fila, 'docs/STATUS.md': estado },
    (s) => s.includes('proponha o /clear'), ['--resumida']],
  ['nuvem com todos os pacotes no disco: não avisa, mesmo sem a variável', { 'docs/BACKLOG.md': fila, 'docs/STATUS.md': estado, ...todosOsPacotes() },
    (s) => !s.includes('FALTAM') && !s.includes('AVISO'), [], { CLAUDE_CODE_REMOTE: 'true' }],
  ['aviso de nuvem sem plugins sobrevive ao corte de tamanho', { 'docs/BACKLOG.md': `1. ${'x'.repeat(5000)}\n`, 'docs/STATUS.md': estado, 'pacotes/.vazio': '' },
    (s) => s.length <= 1520 && s.includes('botão Nova conversa'), [], { CLAUDE_CODE_REMOTE: 'true' }],
  ['plugin da conta sem decisão no settings: avisa com o nome', { 'docs/BACKLOG.md': fila, 'docs/STATUS.md': estado,
    '.claude/settings.json': JSON.stringify({ enabledPlugins: { 'velho@synced': false, 'usado@synced': true } }),
    'synced/org/a/.claude-plugin/plugin.json': '{"name":"velho"}', 'synced/org/b/.claude-plugin/plugin.json': '{"name":"usado"}', 'synced/org/c/.claude-plugin/plugin.json': '{"name":"novo"}' },
    (s) => s.includes('sem decisão neste projeto') && s.includes('novo') && !s.includes('velho') && !s.includes('usado,')],
  ['todos os plugins decididos: não avisa', { 'docs/BACKLOG.md': fila, 'docs/STATUS.md': estado,
    '.claude/settings.json': JSON.stringify({ enabledPlugins: { 'velho@synced': false } }), 'synced/org/a/.claude-plugin/plugin.json': '{"name":"velho"}' },
    (s) => !s.includes('sem decisão') && !s.includes('AVISO')],
  ['muitos plugins sem decisão: cita 3 e conta o resto', { 'docs/BACKLOG.md': fila, 'docs/STATUS.md': estado,
    '.claude/settings.json': '{}', ...Object.fromEntries(['p1', 'p2', 'p3', 'p4', 'p5'].map((n) => [`synced/org/${n}/.claude-plugin/plugin.json`, `{"name":"${n}"}`])) },
    (s) => s.includes('p1, p2, p3 e mais 2') && !s.includes('p4')],
  ['settings ilegível: não avisa nem cai', { 'docs/BACKLOG.md': fila, 'docs/STATUS.md': estado,
    '.claude/settings.json': '{quebrado', 'synced/org/a/.claude-plugin/plugin.json': '{"name":"x"}' },
    (s) => !s.includes('sem decisão') && s.includes('Próxima tarefa')],
];

// Pacotes de mentira no formato do disco: skills em <pasta>/SKILL.md, agentes e comandos em .md.
function todosOsPacotes(semEste) {
  const skills = ['design-critique', 'accessibility-audit', 'interaction-design', 'ux-writing', 'design-systems', 'design-ops', 'design-handoff',
    'verification-before-completion', 'systematic-debugging', 'brainstorming', 'writing-plans'];
  const out = {};
  for (const n of skills) if (n !== semEste) out[`pacotes/synced/x/plug/skills/${n}/SKILL.md`] = '---\n---\n';
  for (const n of ['commit', 'explain-this-query', 'hunt-n-plus-one']) if (n !== semEste) out[`pacotes/synced/x/cmd/commands/${n}.md`] = 'x';
  return out;
}

let falhas = 0;
for (const [nome, arquivos, confere, args = [], env = {}] of casos) {
  const r = rodar(arquivos, args, env);
  const ok = r.status === 0 && confere(r.stdout);
  if (!ok) falhas += 1;
  console.log(`${ok ? 'ok   ' : 'FALHA'} ${nome}  (saída ${r.status}, ${r.stdout.length} caracteres)`);
  if (!ok) console.log(r.stdout, r.stderr);
}
console.log(`\n${casos.length - falhas}/${casos.length} casos certos`);
process.exit(falhas ? 1 : 0);
