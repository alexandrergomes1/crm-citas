# Tarefas · Catálogo (primeira versão)

- **Spec:** `spec.md` · **Plano:** `plan.md` · **ADR:** 0012 (Arquiteto), 0011 (Engenheiro de dados, na T3)
- **Escrito por:** Arquiteto de software · **Norma:** modelo C4 e ADR · **Revisão:** pendente (etapa 5 e 5b)
- Só os arquivos do `plan.md` §9. Cada tarefa termina com `pnpm typecheck`, `pnpm lint` e `pnpm test`; mais
  `pnpm db:test` se mexeu em `supabase/` e `pnpm test:e2e` se mexeu em tela. Commits pequenos, Conventional Commits,
  citando a spec. Nada no banco remoto (`AGENTS.md` §1). Dados de teste só fictícios, escritos do zero.

## Antes de construir (portão)
- [ ] **T0** · Gerente de projeto e Analista de requisitos: E30·1, E30·2, E30·3 respondidas e gravadas; L-2 a L-8 do
  `plan.md` §2 resolvidas (L-3 é dinheiro: vai ao dono); spec "Entrar e camada de serviço" (`feat/entrar-servico`,
  E36·A) construída, com a base `src/app/i18n/{pt,es,en}.ts` e `navegacao.ts`. O "Approved" da spec não é portão
  daqui: fica no pedido de merge (T21, E22·B). Se a E30 vier diferente da recomendação, aplicar o `plan.md` §3 e voltar à 5b.
- [ ] **T1** · Engenheiro de DevOps: merge de `feat/banco-ligacao`, `feat/design-system-codigo` e `feat/entrar-servico`
  na `feat/catalogo`; regenerar `src/app/routeTree.gen.ts` se houver
  conflito; conferir os arquivos das bases do cabeçalho do plano; PR de rascunho empilhado.

## Fase 1 · Ficha visual (etapa 6, antes da aprovação do dono)
- [ ] **T2** · Designer de produto: `ficha-visual.md` e `ficha/*.png` em 390 e 1440: nível 1 do celular, lista com
  grupos e tabela com a faixa (L-5), formulário (painel e tela), ⋮ com Desarquivar, janelinha de excluir e "em uso",
  Duplicar com nome repetido (L-6), gestão de categorias, filtros com situação, os cinco estados; propõe os nomes e
  peças que faltam (spec §4). Revisor de design confere pelo `DESIGN.md` §10; o dono aprova; o Designer grava no
  `DESIGN.md` só as linhas aprovadas.

## Fase 2 · Banco (Engenheiro de dados)
- [ ] **T3** · **Decide** cada linha do `plan.md` §4.1 (e da L-2) e a forma do §4.3 (colação ou coluna normalizada para o
  nome único; `org_id` com padrão da sessão; gatilho de `ordem_cor`; L-3 b). Escreve
  `docs/adr/0011-catalogo-tabelas-do-antigo.md`; leitura do antigo só das migrations citadas (E22·B, nada copiado).
- [ ] **T4** · Migrations M1 e M2 (e M3 se E30·3·B) com `pnpm exec supabase migration new`; data e hora depois das do
  item 3 e da E36·A.
- [ ] **T5** · pgTAP 510 e 520 (cópias do molde), 530, 540 (e 550 se E30·3·B); `pnpm db:start`, `pnpm db:test`,
  `pnpm db:stop` verdes; o `010_` do item 3 continua verde.

## Fase 3 · Domínio (Engenheiro de software; teste antes do código)
- [ ] **T6** · `tipos.ts`, `preco.ts` + teste (RN-01, RN-02; EUR e BRL em pt, es, en; ler sem flutuante; fração
  recusada; moeda de outras casas conforme L-3).
- [ ] **T7** · `duracao.ts` + teste (RN-03) e `nome.ts` + teste (RN-04).
- [ ] **T8** · `servico.ts` + teste (erro por campo) e `lista.ts` + teste (situação, ordem estável, página, grupos,
  contadores sem zero).
- [ ] **T9** · `acesso.ts` + teste com a resposta gravada das E30.
- [ ] **T10** · Apagar `src/domain/exemplo.ts` e `exemplo.test.ts`, se ainda existirem.

## Fase 4 · Dados e servidor (Engenheiro de software)
- [ ] **T11** · `src/data/catalogo/{categorias,servicos}.ts` (e `servicos-profissionais.ts` se E30·3·B; `src/data/estudio.ts`
  só se a E36·A não trouxer idioma e moeda), pelo contrato do `plan.md` §5.1; consultas conferidas pelo Engenheiro de dados.
- [ ] **T12** · `src/server/catalogo/esquemas.ts` e `listar.ts` + teste (filtros, página 50, idas ≤ teto, estúdio do
  pedido ignorado).
- [ ] **T13** · `servicos.ts` e `categorias.ts` + testes (cada papel × ação; fração e faixa; `23505`, `23503`; registro
  com preço antes e depois, sem nome de pessoa).
- [ ] **T14** · `consultas.ts` + teste (ativos para o Agendamento; preço e moeda para o Checkout; arquivado marcado).

## Fase 5 · Telas e idiomas (Engenheiro de software)
- [ ] **T15** · bloco `catalogo` em `src/app/i18n/{pt,es,en}.ts` (base da `feat/entrar-servico`); textos dos códigos de erro e da duração.
- [ ] **T16** · L-5: `categoria` opcional por linha em `src/app/ui/bloco-lista.tsx` e `.css`, mais o caso em
  `componentes.test.tsx`.
- [ ] **T17** · Rotas `catalogo.tsx` e `catalogo.servicos.tsx`, linha em `navegacao.ts`, `src/app/paginas/catalogo/*`
  e `catalogo.test.tsx`, conforme a ficha aprovada.

## Fase 6 · Testes de tela (Engenheiro de software)
- [ ] **T18** · `e2e/preparo/catalogo-dados.ts`, `e2e/catalogo.spec.ts`, `e2e/catalogo-estados.spec.ts`,
  `e2e/catalogo-acessibilidade.spec.ts` verdes nos projetos 390 e 1440.

## Fase 7 · Revisão e fecho
- [ ] **T19** · Revisões em paralelo: Revisor de código; Engenheiro de dados (outra instância) e Auditor de risco
  (banco, ADR 0011 item por item); **Auditor de risco e Engenheiro de segurança (dinheiro e acesso)**; Revisor de
  design (checklist e capturas). Nenhum "Bloqueia".
- [ ] **T20** · QA: veredito CA-01 a CA-12 pelo `plan.md` §11; escopo pelo `git diff --name-only` × §9.
- [ ] **T21** · Analista de requisitos confere o pedido; Documentador atualiza `docs/STATUS.md`, `docs/BACKLOG.md`,
  `CHANGELOG.md` e `docs/decisoes/` no mesmo PR; Gerente de projeto pede o merge no molde, com commit, CI verde e
  link da prévia; o portão "Approved" (spec com a linha "Aprovação do dono") é conferido aqui, antes do pedido (E22·B).
