# Tarefas · Agenda (primeira versão)

- **Spec:** `spec.md` (Approved) · **Plano:** `plan.md` · **ADR:** 0006 (Arquiteto), 0007 (Engenheiro de dados, na T3)
- **Escrito por:** Arquiteto de software · **Norma:** modelo C4 e ADR · **Revisão:** pendente (etapa 5 e 5b, refeitas
  depois da revisão MP1 de 28/11/2026)
- Só os arquivos do `plan.md` §10. Cada tarefa termina com `pnpm typecheck`, `pnpm lint` e `pnpm test`; mais
  `pnpm db:test` se mexeu em `supabase/` ou na matriz, `pnpm test:integracao` se mexeu em servidor ou dados e
  `pnpm test:e2e` se mexeu em tela. Commits pequenos, Conventional Commits, citando a spec. Nada no banco remoto
  (`AGENTS.md` §1). Biblioteca, API ou comando só depois de lido na fonte (`AGENTS.md` §6).

## Antes de construir (portão)
- [ ] **T0** · Gerente de projeto e Analista de requisitos: lacunas L-2 e L-4 do `plan.md` §3.1 levadas ao dono (L-3 vai
  pela ficha). **À espera do dono:** E54·1 a E54·8 (`plan.md` §3.3); o núcleo segue sem elas. Pessoa que deixou de ser
  coluna: pendência da Equipe (spec §12, `plan.md` §3.2).
- [ ] **T1** · Engenheiro de DevOps: conferir que a `feat/agenda` está em dia com a `previas` (PR #7 dentro) e abrir o
  PR de rascunho com base na `previas`. Sem merge de bases (não há mais branch empilhada).

## Fase 1 · Ficha visual (etapa 6)
- [ ] **T2** · Designer de produto: `ficha-visual.md` e `ficha/*.png` em 390 e 1440: dia com bloqueios, cartões de
  cada status (dados fictícios), coluna "Ocupado" vista pela profissional, Equipe N de M, filtros, painel e folha de
  bloqueio, janelinha de excluir, os seis estados; propõe as peças da L-3 e a resposta da L-4. Revisor de design
  confere pelo `DESIGN.md` §10; o dono aprova; o Designer grava no `DESIGN.md` só as linhas aprovadas.

## Fase 2 · Banco (Engenheiro de dados)
- [ ] **T3** · **Decide** tabela por tabela (`plan.md` §4.1) e a forma de `public.bloqueios` (§4.3: condição "é
  coluna", leitura de "ocupados", gatilho do mesmo dia, `btree_gist` ou gatilho, `on delete` da ligação sem cascata, pendência da Equipe, spec §12).
  Escreve `docs/adr/0007-agenda-tabelas-do-antigo.md`; leitura do antigo só das migrations citadas na spec (nada
  copiado). M1 só depois da L-2.
- [ ] **T4** · Migrations M2 (`agenda_permissoes`: chaves, 8 linhas, `app.acoes_que_gravam`) e M3 (`agenda_bloqueios`),
  e M1 se a L-2 pedir, com `pnpm exec supabase migration new`; data e hora depois de `20261128035000`.
- [ ] **T5** · pgTAP `110_` (só a linha entre os marcadores, igual a `JSON.stringify(exportarMatriz())` da T6), `120_`
  a `150_`, `160_` (se M1) e `010_` (se preciso); `pnpm db:start`, `pnpm db:test`, `pnpm db:stop` verdes. Numa cópia
  local, tirar uma linha da M2 deixa o `110_` vermelho (visto e desfeito).

## Fase 3 · Matriz e domínio (Engenheiro de software; teste antes do código)
- [ ] **T6** · `src/domain/acesso/chaves.ts` (`MODULOS.agenda`), `matriz.ts` (8 linhas, resposta ao lado) e
  `matriz.test.ts`; `supabase/matriz/matriz.test.ts` verde com a linha nova do `110_` (feito junto com a T5).
- [ ] **T7** · `tipos.ts`, `dia.ts` + `dia.test.ts` (RN-01, RN-02; 23 h, 25 h, meia-noite que não existe).
- [ ] **T8** · `bloqueio.ts` + teste (RN-03, RN-04; encostar; Cancelado e Ausência; alterar ignora o próprio).
- [ ] **T9** · `grade.ts` + teste (RN-05, RN-06, RN-08, contador; `ocupado` nunca filtrado).
- [ ] **T10** · `acesso.ts` + teste: `ehColuna`, `veCompleta`, `podeGravarNa` (linha antiga e nova), `paraResposta`;
  só alcance e `usuarioId`, nunca papel (`plan.md` §2.3 a §2.5).
- [ ] **T11** · Apagar `src/domain/exemplo.ts` e `exemplo.test.ts`.

## Fase 4 · Contrato, dados e servidor (Engenheiro de software)
- [ ] **T12** · Contrato (`plan.md` §2.6 e §2.7): `alcances` no `ContextoEstudio` (`tipos.ts`, `executar.ts`,
  `executar.test.ts`: mesma fonte da porta 3, ausente = não pode, fonte que lança = não pode); `orgId` em `SessaoLida`
  (`acoes.ts`, `acoes.test.ts`, `tests/integracao/entrar.test.ts`, `SEM_SESSAO` em `__root.tsx`).
- [ ] **T13** · `src/data/agenda/{colunas,bloqueios}.ts` por `clienteDoBanco(ctx.banco)`; o Engenheiro de dados confere
  as consultas.
- [ ] **T14** · `src/server/agenda/esquemas.ts` e `ler-dia.ts` + teste (`acaoPost`, `agenda.ver`, `grava: false`;
  CA-04; CA-13; ≤ 3 leituras; `alcances` na resposta).
- [ ] **T15** · `src/server/agenda/bloqueios.ts` + teste (três ações, chaves `agenda.criar/.editar/.remover`;
  ≤ 1 leitura + 1 gravação; `23P01` → `conflito`; CA-09).
- [ ] **T16** · `tests/integracao/agenda.test.ts` (CA-03, CA-04, CA-13) com o banco local.

## Fase 5 · Telas (Engenheiro de software, pela ficha aprovada)
- [ ] **T17** · Bloco `agenda` em `src/app/i18n/{pt,es,en}.ts`; `i18n.test.ts` verde.
- [ ] **T18** · Peças aprovadas na T2 em `src/app/ui/` (`grade-agenda`, `seletor-data` e ajustes pedidos), com
  `componentes.test.tsx`, `app.css`, vitrine e `e2e/vitrine.spec.ts`.
- [ ] **T19** · `src/app/navegacao.ts`, `src/app/routes/_app.tsx` e `src/app/routes/_app/agenda.tsx`
  (`validateSearch` só `dia`; `loader` com `estudioDaTela`); L-4 só se aprovada.
- [ ] **T20** · `src/app/paginas/agenda/*` + `agenda.test.tsx` (RF-11: ⋮ e entrada de bloqueio pelos `alcances`).
- [ ] **T21** · `e2e/preparo-global.ts` (contas), `e2e/agenda.spec.ts` (CA-05, CA-09, CA-13),
  `e2e/agenda-estados.spec.ts` (CA-06), `e2e/agenda-acessibilidade.spec.ts` (CA-08); verdes em 390 e 1440.
- [ ] **T22** · Conferir o escopo: `git diff --name-only origin/previas...HEAD` contra o `plan.md` §10; todos os
  comandos verdes; CI verde no PR de rascunho.

## Fase 6 · Revisão (etapa 9; quem construiu não revisa)
- [ ] **T23** · Revisor de código: camadas, contrato tocado (T12), CA-04, escopo, ADR 0006.
- [ ] **T24** · Engenheiro de dados (outra instância) e Auditor de risco: migrations, políticas, pgTAP, cópia da matriz,
  ADR 0007 item por item (E16·1, CA-10, CA-11, CA-14).
- [ ] **T25** · Engenheiro de segurança e Auditor de risco: chaves e alcance, "Ocupado" nas duas camadas, `alcances` e
  `orgId` na tela, CA-03, CA-09, CA-13.
- [ ] **T26** · Revisor de design: capturas 390 e 1440 contra a ficha aprovada e o `DESIGN.md` §10 (CA-07).
- [ ] **T27** · QA: veredito CA-01 a CA-14, com os links da CI.

## Fase 7 · Fechar
- [ ] **T28** · Analista de requisitos: confere o pedido item por item (etapa 10).
- [ ] **T29** · Documentador: `docs/STATUS.md`, `docs/BACKLOG.md`, `CHANGELOG.md`, `docs/decisoes/` no mesmo PR.
- [ ] **T30** · Gerente de projeto: pedido de merge no molde, com o commit, a CI verde e o link da prévia; aviso no
  celular.
