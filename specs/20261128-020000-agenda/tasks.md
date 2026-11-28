# Tarefas · Agenda (primeira versão)

- **Spec:** `spec.md` · **Plano:** `plan.md` · **ADR:** 0006 (Arquiteto), 0007 (Engenheiro de dados, na T3)
- **Escrito por:** Arquiteto de software · **Norma:** modelo C4 e ADR · **Revisão:** pendente (etapa 5 e 5b)
- Só os arquivos do `plan.md` §9.A. Cada tarefa termina com `pnpm typecheck`, `pnpm lint` e `pnpm test`; mais
  `pnpm db:test` se mexeu em `supabase/` e `pnpm test:e2e` se mexeu em tela. Commits pequenos, Conventional Commits,
  citando a spec. Nada no banco remoto (`AGENTS.md` §1).

## Antes de construir (portão)
- [ ] **T0** · Gerente de projeto e Analista de requisitos: E26·1, E26·2, E26·3 respondidas e gravadas; L-1 a L-5 do
  `plan.md` §2 resolvidas (L-1 vai ao dono como ordem da fila); spec "Approved" com a linha "Aprovação do dono".
  Se L-1·B: o plano ganha o §9.B e volta à 5b. Se E26·3·C: o plano para e é refeito.
- [ ] **T1** · Engenheiro de DevOps: merge de `feat/banco-ligacao` e `feat/design-system-codigo` (e da branch da
  camada de serviço, com L-1·A) na `feat/agenda`; regenerar `src/app/routeTree.gen.ts` se houver conflito; conferir os
  arquivos das bases do cabeçalho do plano; PR de rascunho empilhado.

## Fase 1 · Ficha visual (etapa 6, antes da aprovação do dono)
- [ ] **T2** · Designer de produto: `ficha-visual.md` e `ficha/*.png` em 390 e 1440: dia com bloqueios, cartões de
  cada status (dados fictícios), Equipe N de M, filtros, painel e folha de bloqueio, janelinha de excluir, os seis
  estados; propõe as peças da L-3 para o `DESIGN.md`. Revisor de design confere pelo `DESIGN.md` §10; o dono aprova; o
  Designer grava no `DESIGN.md` só as linhas aprovadas.

## Fase 2 · Banco (Engenheiro de dados)
- [ ] **T3** · **Decide** tabela por tabela (`plan.md` §4.1: `time_blocks`, `staff_members`, `staff_shifts`,
  `time_block_types`, `resources`, `agenda_waitlist`, nome de exibição da L-2) e a forma de `public.bloqueios` (§4.3:
  gatilho do mesmo dia, `btree_gist` ou gatilho para a exclusão, onde conferir que a profissional é coluna). Escreve
  `docs/adr/0007-agenda-tabelas-do-antigo.md`; leitura do antigo só das migrations citadas na spec (E22·B, nada copiado).
- [ ] **T4** · Migrations M1 (se a T3 escolher a coluna) e M2, com `pnpm exec supabase migration new`; data e hora
  depois das do item 3.
- [ ] **T5** · pgTAP 110 (cópia do molde), 120, 130 e 140 (se M1); `pnpm db:start`, `pnpm db:test`, `pnpm db:stop` verdes.

## Fase 3 · Domínio (Engenheiro de software; teste antes do código)
- [ ] **T6** · `tipos.ts`, `dia.ts` + `dia.test.ts` (RN-01, RN-02; 23 h, 25 h, meia-noite que não existe).
- [ ] **T7** · `bloqueio.ts` + teste (RN-03, RN-04; encostar; Cancelado e Ausência; alterar ignora o próprio).
- [ ] **T8** · `grade.ts` + teste (RN-05, RN-06, RN-08, contador de filtros).
- [ ] **T9** · `acesso.ts` + teste com a resposta gravada das E26.
- [ ] **T10** · Apagar `src/domain/exemplo.ts` e `exemplo.test.ts`.

## Fase 4 · Dados e servidor (Engenheiro de software)
- [ ] **T11** · `src/data/agenda/{estudio,colunas,bloqueios}.ts` pelo contrato da camada de serviço (`plan.md` §5.1);
  o Engenheiro de dados confere as consultas.
- [ ] **T12** · `src/server/agenda/esquemas.ts` e `ler-dia.ts` + teste (CA-03, CA-04, máscara E26·1, ≤ 3 idas).
- [ ] **T13** · `src/server/agenda/bloqueios.ts` + teste (criar, alterar, excluir; conflito; registro sem motivo; CA-09).

## Fase 5 · Telas (Engenheiro de software, pela ficha aprovada)
- [ ] **T14** · `src/app/i18n/*` + `i18n.test.ts` (pt, es, en).
- [ ] **T15** · `src/app/navegacao.ts` e `src/app/routes/agenda.tsx` (`validateSearch` só `dia`; `loader`).
- [ ] **T16** · `src/app/paginas/agenda/*` + `agenda.test.tsx`, só com componentes do item 4 e as peças aprovadas na T2.
- [ ] **T17** · `e2e/preparo/agenda-dados.ts`, `e2e/agenda.spec.ts` (CA-05, CA-09), `e2e/agenda-estados.spec.ts`
  (CA-06), `e2e/agenda-acessibilidade.spec.ts` (CA-08); verdes em 390 e 1440.
- [ ] **T18** · Conferir o escopo: `git diff --name-only <base>...HEAD` contra o `plan.md` §9.A; todos os comandos verdes;
  CI verde no PR de rascunho.

## Fase 6 · Revisão (etapa 9; quem construiu não revisa)
- [ ] **T19** · Revisor de código: camadas, CA-04, escopo, ADR 0006.
- [ ] **T20** · Engenheiro de dados (outra instância) e Auditor de risco: migrations, políticas, pgTAP, ADR 0007 item por
  item (E16·1, CA-10, CA-11).
- [ ] **T21** · Engenheiro de segurança e Auditor de risco: acesso por papel (E26), CA-03, CA-09.
- [ ] **T22** · Revisor de design: capturas 390 e 1440 contra a ficha aprovada e o `DESIGN.md` §10 (CA-07).
- [ ] **T23** · QA: veredito CA-01 a CA-12, com os links da CI.

## Fase 7 · Fechar
- [ ] **T24** · Analista de requisitos: confere o pedido item por item (etapa 10).
- [ ] **T25** · Documentador: `docs/STATUS.md`, `docs/BACKLOG.md`, `CHANGELOG.md`, `docs/decisoes/` no mesmo PR.
- [ ] **T26** · Gerente de projeto: base do PR na `previas`; pedido de merge no molde, com o commit, a CI verde e o link
  da prévia; aviso no celular.
