# Tarefas · Agendamento (núcleo, primeira versão)

- **Spec:** `spec.md` · **Plano:** `plan.md` · **ADR:** 0010 (Arquiteto), 0009 (Engenheiro de dados, na T3)
- **Escrito por:** Arquiteto de software · **Norma:** modelo C4 e ADR · **Revisão:** pendente (etapa 5 e 5b)
- Só os arquivos do `plan.md` §10. Cada tarefa termina com `pnpm typecheck`, `pnpm lint` e `pnpm test`; mais
  `pnpm db:test` se mexeu em `supabase/` e `pnpm test:e2e` se mexeu em tela. Commits pequenos, Conventional Commits,
  citando a spec. Nada no banco remoto (`AGENTS.md` §1). Teste antes do código no domínio.

## Antes de construir
- [ ] **T0** · Gerente de projeto e Analista de requisitos: a construção em PR de rascunho pode começar (E22·B), com as
  recomendações das dúvidas em aberto (E26, E27, E30·3); quando o dono responder, a resposta é gravada e, se diferente,
  aplica-se o `plan.md` §12 (com E27·2·B ou E26·3·C, o plano volta à 5b). O portão "Approved" fica no pedido de merge (T25).
- [ ] **T1** · Engenheiro de DevOps: merge, nesta ordem, de `feat/banco-ligacao`, `feat/design-system-codigo`, da
  branch da spec "Entrar e camada de serviço" (E36·A), de `feat/agenda`, `feat/clientes` e `feat/catalogo` na
  `feat/agendamento`; regenerar `routeTree.gen.ts`; conferir que os arquivos das bases do cabeçalho do plano estão lá;
  PR de rascunho empilhado.

## Fase 1 · Ficha visual (etapa 6, antes da aprovação do dono)
- [ ] **T2** · Designer de produto: `ficha-visual.md` e `ficha/*.png` em 390 e 1440 (dados fictícios): as 4 etapas,
  painel, menu de status, janelinha de cancelar, aviso com "Desfazer" (e a duração dele, L-3), remarcar, conflito, os
  estados; nomes que faltam no `DESIGN.md` §6; textos es e en. Revisor de design confere pelo `DESIGN.md` §10; o dono
  aprova; o Designer grava no `DESIGN.md` só as linhas aprovadas.

## Fase 2 · Banco (Engenheiro de dados; só com as tabelas de Clientes e do Catálogo na branch)
- [ ] **T3** · **Decide** tabela por tabela e as funções do antigo (`plan.md` §4.1) e a forma da garantia de conflito
  (exclusão com `btree_gist`, trava por profissional para bloqueio × agendamento); confere no banco local que
  `btree_gist` e `dblink` existem. Escreve `docs/adr/0009-agendamento-tabelas-do-antigo.md` (leitura do antigo só das
  migrations citadas, E22·B, nada copiado).
- [ ] **T4** · Migrations M1 a M7 (`plan.md` §4.2 a §4.5a: inclui o gatilho de registro da spec Entrar e a função
  `public.agendamento_criar`, `security invoker`) com `pnpm exec supabase migration new`; carimbo depois das bases.
- [ ] **T5** · pgTAP `agendamento_200` a `agendamento_280`; a linha de `agendamento_criar` na lista do `010_`;
  `pnpm db:start`, `pnpm db:test`, `pnpm db:stop` verdes, incluindo o `010_`; prova de que os testes pegam erro (tirar o `where` da exclusão ou o `S`, ver vermelho, desfazer).

## Fase 3 · Domínio (Engenheiro de software)
- [ ] **T6** · `tipos.ts`, `status.ts` + `status.test.ts` (49 pares, desfazer, remarcar, RF-17).
- [ ] **T7** · `horario.ts` + `horario.test.ts` (fusos e trocas de horário do `plan.md` §5.2, passado, tetos, conflito
  pela regra da Agenda).
- [ ] **T8** · `acesso.ts` + `acesso.test.ts` (E26·2·A, E26·1·B).

## Fase 4 · Dados e servidor (Engenheiro de software; só com a spec Entrar na branch)
- [ ] **T9** · `src/data/agendamento/{agendamentos,checkout,exemplo-local}.ts` pelo contrato do `plan.md` §5.1; o
  Engenheiro de dados confere as consultas.
- [ ] **T10** · `src/server/agendamento/esquemas.ts` e `acoes.ts` + `acoes.test.ts` (ações por `acao(...)`, um pedido
  de gravação por ação, recusas de regra em `valor`, conflito sem dado, registro sem dado pessoal, teto de idas, reuso de
  Clientes, Catálogo e Agenda).
- [ ] **T11** · Agenda (L-1): `src/data/agenda/agendamentos.ts`, `src/server/agenda/ler-dia.ts` e teste (4 idas, máscara
  E26·1·B, teto de 500).

## Fase 5 · Telas (Engenheiro de software, pela ficha aprovada)
- [ ] **T12** · Chaves `agendamento.*` em `src/app/i18n/{pt,es,en}.ts` (base comum da `feat/entrar-servico`; o `i18n.test.ts` fica verde; inclui `hora_inexistente`).
- [ ] **T13** · `src/app/routes/agendar.tsx`; `agenda.tsx` com o parâmetro `agendamento`; `navegacao.ts`.
- [ ] **T14** · `src/app/paginas/agendamento/*` + `agendamento.test.tsx`, só com componentes do item 4 e as peças da T2.
- [ ] **T15** · Agenda (L-1): `paginas/agenda/{agenda,barra,cartao}.tsx` abrem o Novo agendamento e o painel;
  `e2e/agenda.spec.ts` ajustado.
- [ ] **T16** · `e2e/preparo/agendamento-dados.ts`, `e2e/agendamento.spec.ts`, `-estados.spec.ts`,
  `-acessibilidade.spec.ts`; verdes em 390 e 1440.
- [ ] **T17** · Conferir o escopo: `git diff --name-only <base>...HEAD` contra o `plan.md` §10; todos os comandos verdes;
  CI verde no PR de rascunho.

## Fase 6 · Revisão (etapa 9; quem construiu não revisa)
- [ ] **T18** · Revisor de código: camadas, reuso (ADR 0010 · D5), escopo, ADR 0010.
- [ ] **T19** · Engenheiro de dados (outra instância) e Auditor de risco: migrations, gatilhos, exclusão, pgTAP (com o 240
  de concorrência), ADR 0009 item por item (E16·1, CA-11, CA-12). O Engenheiro de dados da Agenda confere o gatilho em
  `public.bloqueios`.
- [ ] **T20** · Engenheiro de segurança e Auditor de risco: acesso por papel (E26), CA-05, CA-06, CA-10, o `cliente_id`
  visível na linha alheia (`plan.md` §13).
- [ ] **T21** · Revisor de design: capturas 390 e 1440 contra a ficha aprovada e o `DESIGN.md` §10 (CA-09).
- [ ] **T22** · QA: veredito CA-01 a CA-14, com os links da CI.

## Fase 7 · Fechar
- [ ] **T23** · Analista de requisitos: confere o pedido item por item (etapa 10).
- [ ] **T24** · Documentador: `docs/STATUS.md`, `docs/BACKLOG.md`, `CHANGELOG.md`, `docs/decisoes/` no mesmo PR;
  confere a numeração dos ADRs 0009 e 0010.
- [ ] **T25** · Gerente de projeto: **portão** — spec "Approved" com a linha "Aprovação do dono" e as respostas E26, E27
  e E30·3 gravadas; base do PR na `previas`; pedido de merge no molde, com o commit, a CI verde e o link
  da prévia; aviso no celular.
