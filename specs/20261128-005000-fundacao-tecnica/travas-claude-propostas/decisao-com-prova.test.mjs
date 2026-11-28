#!/usr/bin/env node
// PROPOSTA (destino: .claude/hooks/decisao-com-prova.test.mjs). Testa as funções sem git.
// Uso: node decisao-com-prova.test.mjs
import {
  campo, problemasDaSpec, mudancasProibidasNaSpec, mudaSoAprovacaoDoMerge, problemasDaDecisao, shaCitado, faltasDaAprovacao,
} from './decisao-com-prova.mjs';

const LINK = 'https://claude.ai/code/session_teste';
const spec = ({ status = 'Draft', dono = '(pendente)', merge = '(pendente)' } = {}) => `# Spec · X

- **Status:** ${status}
- **Aprovação do dono:** ${dono}
- **Aprovação do merge:** ${merge}
- **Branch:** \`feat/agenda-filtro\`

## 1. Origem
texto
`;
const DONO = `"E30 aprovo" · 28/11/2026 · ${LINK}`;
const MERGE = `"merge E31 ok" · 2026-11-29 · ${LINK} · commit \`abc1234\``;

const decisoes = (linhas) => `# Decisões do dono · teste

Só as respostas literais do dono. Link: ${LINK}

| Código | O que foi aprovado | Resposta literal |
|---|---|---|
${linhas.join('\n')}
`;
const L1 = '| E1 | Estrutura | "E1: OK." |';
const L2 = '| E2 | Equipe | "e2 aprovo." |';

const n = (lista) => lista.length;
const casos = [
  ['campo lê o formato da spec', campo(spec(), 'Status') === 'Draft' ? 0 : 1, 0],
  ['spec em rascunho, tudo pendente, passa', n(problemasDaSpec(spec())), 0],
  ['spec aprovada com aprovação completa passa', n(problemasDaSpec(spec({ status: 'Approved', dono: DONO }))), 0],
  ['spec aprovada sem aprovação do dono barra', n(problemasDaSpec(spec({ status: 'Approved' }))), 1],
  ['aprovação sem aspas barra', n(problemasDaSpec(spec({ status: 'Approved', dono: `E30 aprovo · 28/11/2026 · ${LINK}` }))), 1],
  ['aprovação sem data barra', n(problemasDaSpec(spec({ status: 'Approved', dono: `"E30 aprovo" · ${LINK}` }))), 1],
  ['aprovação sem link barra', n(problemasDaSpec(spec({ status: 'Approved', dono: '"E30 aprovo" · 28/11/2026' }))), 1],
  ['faltas listadas uma a uma', faltasDaAprovacao('nada').length, 3],
  ['merge completo passa', n(problemasDaSpec(spec({ status: 'Approved', dono: DONO, merge: MERGE }))), 0],
  ['merge sem commit barra', n(problemasDaSpec(spec({ status: 'Approved', dono: DONO, merge: `"ok" · 2026-11-29 · ${LINK}` }))), 1],
  ['merge numa spec em rascunho barra', n(problemasDaSpec(spec({ merge: MERGE }))), 1],
  ['SHA lido depois de "commit"', shaCitado(MERGE) === 'abc1234' ? 0 : 1, 0],
  ['SHA em maiúscula vira minúscula', shaCitado('Commit autorizado (SHA): ABC1234F') === 'abc1234f' ? 0 : 1, 0],
  ['data não vira SHA', shaCitado('commit de 20261129') === '' ? 0 : 1, 0],
  ['spec na base: aprovação gravada não muda',
    n(mudancasProibidasNaSpec(spec({ status: 'Approved', dono: DONO }), spec({ status: 'Approved', dono: `"outra" · 28/11/2026 · ${LINK}` }))), 1],
  ['spec na base: gravar o merge pendente pode',
    n(mudancasProibidasNaSpec(spec({ status: 'Approved', dono: DONO }), spec({ status: 'Approved', dono: DONO, merge: MERGE }))), 0],
  ['spec na base: merge gravado não muda',
    n(mudancasProibidasNaSpec(spec({ status: 'Approved', dono: DONO, merge: MERGE }), spec({ status: 'Approved', dono: DONO }))), 1],
  ['commit só da linha do merge é reconhecido',
    mudaSoAprovacaoDoMerge(spec({ status: 'Approved', dono: DONO }), spec({ status: 'Approved', dono: DONO, merge: MERGE })) ? 0 : 1, 0],
  ['commit que muda outra linha não é só do merge',
    mudaSoAprovacaoDoMerge(spec({ status: 'Approved', dono: DONO }), spec({ status: 'Approved', dono: DONO, merge: MERGE }).replace('texto', 'outro')) ? 1 : 0, 0],
  ['decisões: arquivo novo completo passa', n(problemasDaDecisao(null, decisoes([L1, L2]))), 0],
  ['decisões: acrescentar linha passa', n(problemasDaDecisao(decisoes([L1]), decisoes([L1, L2]))), 0],
  ['decisões: mudar linha gravada barra', n(problemasDaDecisao(decisoes([L1, L2]), decisoes([L1, '| E2 | Equipe | "outra fala" |']))), 1],
  ['decisões: apagar linha gravada barra', n(problemasDaDecisao(decisoes([L1, L2]), decisoes([L1]))), 1],
  ['decisões: apagar o arquivo barra', n(problemasDaDecisao(decisoes([L1]), null)), 1],
  ['decisões: linha nova sem aspas barra', n(problemasDaDecisao(decisoes([L1]), decisoes([L1, '| E3 | Algo | sim |']))), 1],
  ['decisões: linha nova sem código barra', n(problemasDaDecisao(decisoes([L1]), decisoes([L1, '|  | Algo | "sim" |']))), 1],
  ['decisões: arquivo sem link barra', n(problemasDaDecisao(null, decisoes([L1]).replace(LINK, '(link)'))), 1],
];

let falhas = 0;
for (const [nome, obtido, esperado] of casos) {
  const ok = obtido === esperado;
  if (!ok) falhas += 1;
  console.log(`${ok ? 'ok   ' : 'FALHA'} ${nome}${ok ? '' : ` (esperado ${esperado}, obtido ${obtido})`}`);
}
console.log(`\n${casos.length - falhas}/${casos.length} casos certos`);
process.exit(falhas ? 1 : 0);
