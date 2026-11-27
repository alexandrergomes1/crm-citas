#!/usr/bin/env node
// Testa as funções de decisao-com-prova.mjs sem git. Uso: node .claude/hooks/decisao-com-prova.test.mjs
import {
  problemasDaDecisao, problemaDaSpec, shaAprovado, ehDecisao, secao, problemasDaAprovacaoDoMerge,
  alteraSoAprovacaoDoMerge, mudancasProibidasNaSpec,
} from './decisao-com-prova.mjs';

const decisao = ({ pergunta = 'Pergunta D2: prova de aprovação (texto completo)', opcao = 'D2·B', resposta = '"D2b"', data = '2026-11-24',
  prova = 'https://claude.ai/code/session_x', vale = 'regra geral' } = {}) => `# Decisão
| | |
|---|---|
| Pergunta como foi enviada | ${pergunta} |
| Opções apresentadas | A … · B … |
| Opção escolhida | ${opcao} |
| Resposta do dono (literal) | ${resposta} |
| Data | ${data} |
| Prova | ${prova} |
| Vale para | ${vale} |
| Substitui | — |
`;
const molde = `| Pergunta como foi enviada | texto completo ou resumo fiel |
| Opção escolhida | código (ex.: P12·A) ou "palavras próprias" |
| Resposta do dono (literal) | "…" |
| Data | AAAA-MM-DD |
| Prova | link da conversa |`;

const n = (caminho, texto) => problemasDaDecisao(caminho, texto).length;
const casos = [
  ['decisão completa passa', n('docs/decisoes/2026-11-24-d2.md', decisao()), 0],
  ['decisão sem Veredito nem SHA passa', n('docs/decisoes/2026-11-24-d2.md', decisao({ vale: 'fila' })), 0],
  ['código de opção como resposta passa', n('docs/decisoes/a.md', decisao({ resposta: '"b6a"' })), 0],
  ['palavras próprias passam', n('docs/decisoes/a.md', decisao({ resposta: '“quero sem faixa”' })), 0],
  ['molde sem preencher barra os 5 campos', n('docs/decisoes/a.md', molde), 5],
  ['"sim" com o código da opção escolhida passa', n('docs/decisoes/a.md', decisao({ resposta: '"sim"', opcao: 'sim (= P12·A, a recomendação)' })), 0],
  ['"ok" com o código da opção escolhida passa', n('docs/decisoes/a.md', decisao({ resposta: '"ok"', opcao: 'Q1·B' })), 0],
  ['"ok" sem código na opção escolhida barra', n('docs/decisoes/a.md', decisao({ resposta: '"ok"', opcao: 'a recomendada' })), 1],
  ['"Pode seguir." sem código barra', n('docs/decisoes/a.md', decisao({ resposta: '"Pode seguir."', opcao: 'sim' })), 1],
  ['resposta sem aspas barra', n('docs/decisoes/a.md', decisao({ resposta: 'D2b' })), 1],
  ['"a confirmar" barra', n('docs/decisoes/a.md', decisao({ opcao: 'a confirmar' })), 1],
  ['data em outro formato barra', n('docs/decisoes/a.md', decisao({ data: '24/11/2026' })), 1],
  ['prova sem link barra', n('docs/decisoes/a.md', decisao({ prova: 'conversa de hoje' })), 1],
  ['ficha do módulo completa passa', n('docs/decisoes/2026-11-25-base-agenda.md', decisao({ vale: 'módulo docs/produto/modulos/agenda.md' })), 0],
  ['ficha do módulo sem "Vale para" barra', n('docs/decisoes/2026-11-25-base-agenda.md', decisao({ vale: '' })), 1],
  ['ficha do módulo sem link barra', n('docs/decisoes/2026-11-25-base-agenda.md', decisao({ vale: 'agenda', prova: 'chat' })), 1],
  ['SHA aprovado é lido do "Vale para"', shaAprovado(decisao({ vale: 'PR nº 12 · SHA 9cd81a5e' })) === '9cd81a5e' ? 0 : 1, 0],
  ['data em "Vale para" não vira SHA', shaAprovado(decisao({ vale: 'PR nº 12 de 20261124' })) === '' ? 0 : 1, 0],
  ['SHA em maiúscula é lido', shaAprovado(decisao({ vale: 'PR nº 12 · SHA 9CD81A5' })) === '9cd81a5' ? 0 : 1, 0],
  ['LEIA.md não é decisão', ehDecisao('docs/decisoes/LEIA.md') ? 1 : 0, 0],
  ['histórico não é decisão', ehDecisao('docs/decisoes/historico/registro-ate-2026-11-24.md') ? 1 : 0, 0],
  ['arquivo de decisão é decisão', ehDecisao('docs/decisoes/2026-11-24-d2.md') ? 1 : 0, 1],
];

// Specs
const LINK = 'https://claude.ai/code/session_x';
const ler = (c) => (c === 'docs/decisoes/2026-11-24-d2.md' ? decisao({ vale: 'spec specs/20261124-x' }) : null);
const spec = (status, aprovacao = '', resto = '') => `# Feature Specification: X\n\n**Status**: ${status}\n${aprovacao}\n${resto}`;
const linha = (txt) => `**Aprovação do dono**: ${txt}`;
const S = 'specs/20261124-x/spec.md';
const merge = (corpo) => `\n## Aprovação do merge\n<!-- comentário do molde -->\n${corpo}\n`;
const MOLDE_MERGE = '- PR nº: · Commit autorizado (SHA): · Resposta do dono (literal): "" · Data: · Link da conversa:';
const X = 'abc1234def5678abc1234def5678abc1234def56';
const MERGE_OK = `- PR nº: 12 · Commit autorizado (SHA): ${X.slice(0, 7)} · Resposta do dono (literal): "M3·A, pode juntar" · Data: 2026-11-25 · Link da conversa: ${LINK}`;
const specs = [
  ['spec Draft sem aprovação passa', problemaDaSpec(spec('Draft'), ler, S), ''],
  ['spec do molde (lista de situações) passa', problemaDaSpec(spec('Draft · Approved · Done'), ler, S), ''],
  ['spec Approved com a linha completa passa', problemaDaSpec(spec('Approved', linha(`"P1·A" · 2026-11-24 · ${LINK}`)), ler, S), ''],
  ['spec Approved sem a linha "Aprovação do dono" barra', problemaDaSpec(spec('Approved'), ler, S), 'x'],
  ['linha sem resposta entre aspas barra', problemaDaSpec(spec('Approved', linha(`P1·A · 2026-11-24 · ${LINK}`)), ler, S), 'x'],
  ['linha com o texto do molde barra', problemaDaSpec(spec('Approved', linha('"[resposta literal]" · [DATA] · [link da conversa]')), ler, S), 'x'],
  ['linha sem data barra', problemaDaSpec(spec('Approved', linha(`"P1·A" · ${LINK}`)), ler, S), 'x'],
  ['linha sem link barra', problemaDaSpec(spec('Approved', linha('"P1·A" · 2026-11-24')), ler, S), 'x'],
  ['linha citando decisão em docs/decisoes/ que vale para a spec passa', problemaDaSpec(spec('Approved', linha('"D2b" · 2026-11-24 · `docs/decisoes/2026-11-24-d2.md`')), ler, S), ''],
  ['linha citando decisão de outra spec barra', problemaDaSpec(spec('Approved', linha('"D2b" · 2026-11-24 · `docs/decisoes/2026-11-24-d2.md`')), ler, 'specs/20261125-y/spec.md'), 'x'],
  ['linha citando decisão que não existe barra', problemaDaSpec(spec('Approved', linha('"D2b" · 2026-11-24 · `docs/decisoes/2026-11-25-zz.md`')), ler, S), 'x'],
  ['spec curta Approved com a linha completa passa', problemaDaSpec(`| Status | Approved |\n| Aprovação do dono | "S1·A" · 2026-11-24 · ${LINK} |`, ler, S), ''],
  ['spec curta Approved com o molde barra', problemaDaSpec('| Status | Approved |\n| Aprovação do dono | "resposta literal" · data · link da conversa |', ler, S), 'x'],
  ['"Aprovação do merge" do molde (vazia) passa', problemaDaSpec(spec('Approved', linha(`"P1·A" · 2026-11-24 · ${LINK}`), merge(MOLDE_MERGE)), ler, S), ''],
  ['"Aprovação do merge" completa passa', problemaDaSpec(spec('Approved', linha(`"P1·A" · 2026-11-24 · ${LINK}`), merge(MERGE_OK)), ler, S), ''],
  ['"Aprovação do merge" sem SHA barra', problemaDaSpec(spec('Approved', linha(`"P1·A" · 2026-11-24 · ${LINK}`), merge(MERGE_OK.replace(X.slice(0, 7), ''))), ler, S), 'x'],
  ['"Aprovação do merge" sem link barra', problemaDaSpec(spec('Approved', linha(`"P1·A" · 2026-11-24 · ${LINK}`), merge(MERGE_OK.replace(LINK, ''))), ler, S), 'x'],
  ['"Aprovação do merge" sem data barra', problemaDaSpec(spec('Approved', linha(`"P1·A" · 2026-11-24 · ${LINK}`), merge(MERGE_OK.replace('2026-11-25', ''))), ler, S), 'x'],
];

// Seção "Aprovação do merge", mudança só nela e imutabilidade da spec já na previas.
const base = spec('Approved', linha(`"P1·A" · 2026-11-24 · ${LINK}`), `\n## Clarifications\n- Q: a? → A: B ("B")\n${merge(MOLDE_MERGE)}\n## Seção do tipo\ntexto\n`);
const comMerge = base.replace(MOLDE_MERGE, MERGE_OK);
const outros = [
  ['seção lida até o próximo título', secao(comMerge, 'Aprovação do merge').includes('M3·A') && !secao(comMerge, 'Aprovação do merge').includes('Seção do tipo') ? 0 : 1, 0],
  ['seção completa que cita X passa', problemasDaAprovacaoDoMerge(secao(comMerge, 'Aprovação do merge'), X).length, 0],
  ['seção que cita outro commit barra', problemasDaAprovacaoDoMerge(secao(comMerge, 'Aprovação do merge'), 'fff9999aaa').length, 1],
  ['seção vazia (molde) barra quando se exige X', problemasDaAprovacaoDoMerge(secao(base, 'Aprovação do merge'), X).length > 0 ? 1 : 0, 1],
  ['mudança só na "Aprovação do merge" é aceita', alteraSoAprovacaoDoMerge(base, comMerge) ? 0 : 1, 0],
  ['mudança também em outra seção barra', alteraSoAprovacaoDoMerge(base, comMerge.replace('texto', 'outro texto')) ? 1 : 0, 0],
  ['sem mudança nenhuma não conta como registro', alteraSoAprovacaoDoMerge(base, base) ? 1 : 0, 0],
  ['spec na previas: mudar "Aprovação do dono" barra', mudancasProibidasNaSpec(base, base.replace('"P1·A"', '"P1·B"')).length, 1],
  ['spec na previas: mudar "Clarifications" barra', mudancasProibidasNaSpec(base, base.replace('("B")', '("C")')).length, 1],
  ['spec na previas: mudar "Aprovação do merge" barra', mudancasProibidasNaSpec(base, comMerge).length, 1],
  ['spec na previas: mudar outra seção passa', mudancasProibidasNaSpec(base, base.replace('texto', 'outro texto')).length, 0],
];

let falhas = 0;
for (const [nome, obtido, esperado] of [...casos, ...outros]) {
  if (obtido !== esperado) { falhas++; console.error(`FALHOU: ${nome} (esperado ${esperado}, obtido ${obtido})`); }
}
for (const [nome, obtido, esperado] of specs) {
  if (Boolean(obtido) !== Boolean(esperado)) { falhas++; console.error(`FALHOU: ${nome} (obtido "${obtido}")`); }
}
const total = casos.length + outros.length + specs.length;
console.log(`${total - falhas}/${total} casos`);
process.exit(falhas ? 1 : 0);
