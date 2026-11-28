# Tarefas · Agenda (primeira versão)

- **Spec:** `spec.md` (Approved; ajustes 2 e 3, commits `217a715` e `a0159f6`) · **Plano:** `plan.md` · **ADR:** 0006
  (Arquiteto), 0007 (Engenheiro de dados, na T3)
- **Escrito por:** Arquiteto de software · **Norma:** modelo C4 e ADR · **Revisão:** pendente (etapa 5 e 5b, refeitas
  depois dos ajustes 2 e 3 de 28/11/2026)
- Só os arquivos do `plan.md` §10. Cada tarefa termina com `pnpm typecheck`, `pnpm lint` e `pnpm test`; mais
  `pnpm db:test` se mexeu em `supabase/` ou na matriz, `pnpm test:integracao` se mexeu em servidor ou dados e
  `pnpm test:e2e` se mexeu em tela. Commits pequenos, Conventional Commits, citando a spec. Nada no banco remoto
  (`AGENTS.md` §1). Biblioteca, API ou comando só depois de lido na fonte (`AGENTS.md` §6).
- **Fora desta spec (E57·B, E58·A):** "Ocupado", chave de ocupação e RF-16 a RF-20. Nenhuma tarefa os constrói.

## Antes de construir (portão)
- [ ] **T0** · Gerente de projeto: **E59 do dono** (grade 08:00–20:00 que se alarga, ou 24 h com rolagem; `plan.md`
  §3.2). Sem resposta, vale 24 h; com "A", o Analista muda a Assumption 1 da spec antes da T9. Pessoa que deixou de ser
  coluna: pendência da Equipe (spec §12).
- [ ] **T1** · Engenheiro de DevOps: conferir que a `feat/agenda` está em dia com a `previas` e abrir o PR de rascunho
  com base na `previas`.

## Fase 1 · Ficha visual (etapa 6)
- [ ] **T2** · Designer de produto: ficha em 390 e 1440 com "+ Novo" (duas opções), menu do horário vazio, linha do
  "agora", nome de exibição e iniciais no topo da coluna (e o texto de quem ainda não tem nome), seletor de horários
  (e a hora repetida no dia de 25 h), atalhos de motivo, profissional só com a própria coluna, "Dia ▾" e lupa "em
  desenvolvimento", os seis estados; peças da L-3. Revisor de design confere; o dono aprova; o Designer grava no
  `DESIGN.md` só as linhas aprovadas (e a da tela inicial, §8b).

## Fase 2 · Banco (Engenheiro de dados)
- [ ] **T3** · **Decide** tabela por tabela (`plan.md` §4.1), a forma de `nome_exibicao` em `public.membros` (ADR 0006
  · D14) e a de `public.bloqueios` (§4.3: condição "é coluna", gatilho do mesmo dia, `check` do passo de 15 min,
  `btree_gist` ou gatilho, ligação sem cascata). Escreve `docs/adr/0007-agenda-tabelas-do-antigo.md`; leitura do antigo
  só das migrations citadas na spec (nada copiado).
- [ ] **T4** · Migrations M1 (`agenda_nome_exibicao`), M2 (`agenda_permissoes`: chaves, 8 linhas,
  `app.acoes_que_gravam`) e M3 (`agenda_bloqueios`), com `pnpm exec supabase migration new`; data e hora depois de
  `20261128035000`.
- [ ] **T5** · pgTAP `110_` (só a linha entre os marcadores, igual a `JSON.stringify(exportarMatriz())` da T6), `120_`
  a `160_` e `010_` (se preciso); `pnpm db:start`, `pnpm db:test`, `pnpm db:stop` verdes. Numa cópia local, tirar uma
  linha da M2 deixa o `110_` vermelho (visto e desfeito).

## Fase 3 · Matriz e domínio (Engenheiro de software; teste antes do código)
- [ ] **T6** · `src/domain/acesso/chaves.ts` (`MODULOS.agenda` com `ver`, `criar`, `editar`, `remover`), `matriz.ts`
  (8 linhas, resposta ao lado) e `matriz.test.ts`; `supabase/matriz/matriz.test.ts` verde com a linha nova do `110_`.
- [ ] **T7** · `tipos.ts`, `dia.ts` + `dia.test.ts` (RN-01, RN-02, `posicaoDoAgora` da RF-14; 23 h, 25 h, meia-noite
  que não existe).
- [ ] **T8** · `horarios.ts` + `horarios.test.ts` (RN-09, RN-10: opções em passos de 15 min nos dias de 23, 24 e 25 h,
  `estaNoPasso`, `fimSugerido` com 1 h, acompanhar e parar no fim do dia).
- [ ] **T9** · `bloqueio.ts` + teste (RN-03, RN-04, passo; encostar; Cancelado e Ausência; alterar ignora o próprio).
- [ ] **T10** · `grade.ts` + teste (RN-05, RN-06, RN-08, contador; `faixaVisivel` só se E59·A).
- [ ] **T11** · `acesso.ts` + teste: `ehColuna`, `colunasVisiveis`, `podeGravarNa` (linha antiga e nova); só alcance e
  `usuarioId`, nunca papel.
- [ ] **T12** · Apagar `src/domain/exemplo.ts` e `exemplo.test.ts`.

## Fase 4 · Contrato, dados e servidor (Engenheiro de software)
- [ ] **T13** · Contrato (`plan.md` §2.6 e §2.7): `alcances` no `ContextoEstudio` (`tipos.ts`, `executar.ts`,
  `executar.test.ts`: mesma fonte da porta 3, ausente = não pode, fonte que lança = não pode); `orgId` em `SessaoLida`
  (`acoes.ts`, `acoes.test.ts`, `tests/integracao/entrar.test.ts`, `SEM_SESSAO` em `__root.tsx`).
- [ ] **T14** · `src/data/agenda/{colunas,bloqueios}.ts` (colunas com `nome_exibicao`; com `proprios`, só a própria);
  o Engenheiro de dados confere as consultas.
- [ ] **T15** · `src/server/agenda/esquemas.ts` e `ler-dia.ts` + teste (`agenda.ver`, `grava: false`; CA-04; CA-13: só
  a própria coluna com `proprios`; ≤ 2 leituras; `alcances` na resposta).
- [ ] **T16** · `src/server/agenda/bloqueios.ts` + teste (três ações; hora fora do passo → `entrada_invalida` sem ir ao
  banco, CA-15; ≤ 1 leitura + 1 gravação; `23P01` → `conflito`; CA-09).
- [ ] **T17** · `tests/integracao/agenda.test.ts` (CA-03, CA-04, CA-13, CA-15) com o banco local.

## Fase 5 · Telas (Engenheiro de software, pela ficha aprovada)
- [ ] **T18** · Bloco `agenda` em `src/app/i18n/{pt,es,en}.ts` (com os 5 atalhos de motivo); `i18n.test.ts` verde.
- [ ] **T19** · Peças aprovadas na T2 em `src/app/ui/` (`grade-agenda`, `seletor-data` e ajustes pedidos), com
  `componentes.test.tsx`, `app.css`, vitrine e `e2e/vitrine.spec.ts`.
- [ ] **T20** · `src/app/navegacao.ts`, `src/app/routes/_app.tsx`, `src/app/routes/_app/agenda.tsx` (`validateSearch`
  só `dia`; `loader` com `estudioDaTela`) e `src/app/routes/_app/index.tsx` redirecionando para `/agenda` (RF-12;
  `redirect` lido na documentação do TanStack Router antes); apagar `src/app/paginas/inicio.tsx` e `inicio.test.tsx`;
  `e2e/inicio.spec.ts` prova o redirecionamento.
- [ ] **T21** · `src/app/paginas/agenda/*` + `agenda.test.tsx`: "+ Novo" (RF-08), menu do horário vazio (RF-13), linha do
  "agora" (RF-14), seletor de horários sem campo de digitar e 1 h (RF-15), atalhos (RF-22), nome de exibição (RF-21),
  "Dia ▾" e lupa "em desenvolvimento" (CA-16), ⋮ e entradas de bloqueio pelos `alcances` (RF-11).
- [ ] **T22** · `e2e/preparo-global.ts` (contas com nome fictício), `e2e/agenda.spec.ts` (CA-05, CA-09, CA-13, CA-15,
  CA-16), `e2e/agenda-estados.spec.ts` (CA-06), `e2e/agenda-acessibilidade.spec.ts` (CA-08); verdes em 390 e 1440.
- [ ] **T23** · Conferir o escopo: `git diff --name-only origin/previas...HEAD` contra o `plan.md` §10; todos os
  comandos verdes; CI verde no PR de rascunho.

## Fase 6 · Revisão (etapa 9; quem construiu não revisa)
- [ ] **T24** · Revisor de código: camadas, contrato tocado (T13), CA-04, CA-15, CA-16, escopo, ADR 0006.
- [ ] **T25** · Engenheiro de dados (outra instância) e Auditor de risco: migrations, políticas, pgTAP, cópia da matriz,
  coluna `nome_exibicao`, ADR 0007 item por item (E16·1, CA-10, CA-11, CA-14).
- [ ] **T26** · Engenheiro de segurança e Auditor de risco: chaves e alcance, só a própria coluna nas duas camadas,
  `alcances` e `orgId` na tela, nome de exibição (nunca e-mail), CA-03, CA-09, CA-13.
- [ ] **T27** · Revisor de design: capturas 390 e 1440 contra a ficha aprovada e o `DESIGN.md` §10 (CA-07).
- [ ] **T28** · QA: veredito CA-01 a CA-16, com os links da CI.

## Fase 7 · Fechar
- [ ] **T29** · Analista de requisitos: confere o pedido item por item (etapa 10).
- [ ] **T30** · Documentador: `docs/STATUS.md`, `docs/BACKLOG.md`, `CHANGELOG.md`, `docs/decisoes/` no mesmo PR.
- [ ] **T31** · Gerente de projeto: pedido de merge no molde, com o commit, a CI verde e o link da prévia; aviso no
  celular.
