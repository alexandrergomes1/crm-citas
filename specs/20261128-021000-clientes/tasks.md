# Tarefas · Clientes, primeira versão (item 5 da fila, núcleo)

- **Spec:** `spec.md` · **Plano:** `plan.md` · **ADR:** `docs/adr/<NNNN>-clientes-dados-busca-e-pedidos.md`
- **Escrito por:** Arquiteto de software · Norma: modelo C4 e ADR · **Revisão:** etapa 5 e 5b pendentes
- Com as recomendações E28·1·A, E28·2·B (com E26·1·B) e E28·3·A; outra resposta muda as tarefas pelo `plan.md` §12.
- **Construção só em PR de rascunho** (E22·B); nada é juntado sem "Status: Approved", "Aprovação do dono" e a
  autorização do merge gravada (`AGENTS.md` §3 regra 1 e §8). Só os arquivos do `plan.md` §9. Banco só local; a IA nunca
  aplica nada no banco remoto (`AGENTS.md` §1). Falhou: refaz e confere; o mesmo erro duas vezes, para e relata.
  Commits pequenos, Conventional Commits, citando a spec.

## Preparo

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 1 | Juntar por merge na `feat/clientes` a `feat/banco-ligacao` e depois a `feat/design-system-codigo` (`plan.md` §10); conferir que já têm as migrations do item 3 e os componentes do item 4 com commit (B-5); senão, parar e relatar | Engenheiro de DevOps | merge sem conflito; arquivos presentes; árvore limpa |
| 2 | Escrever o ADR com as decisões do `plan.md` §3.6 (por tabela do antigo) e §13 (D1 a D9); pedir o número ao Documentador | Engenheiro de dados (tabelas) e Arquiteto de software (D1 a D9) | ADR com saída, motivo e norma por linha; conferência em branco |
| 3 | Ler na doc oficial: `pg_trgm` no Supabase (R-4); `createServerFn`, rotas de servidor e rotas por pasta do TanStack Start (R-2); README do `libphonenumber-js` 1.13.17 (D1) | Engenheiro de dados (1º) e Engenheiro de software (2º e 3º) | fontes anotadas no PR; se algo não existir como no plano, parar e pedir ajuste |
| 4 | Conferir B-4 (país do estúdio): se o item 3 não trouxer `pais`, usar a M0 | Engenheiro de dados | decisão anotada no ADR |

## Fase A · Banco local

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 5 | M0 (se preciso) e M1 `extensoes_busca` | Engenheiro de dados | `pnpm db:start` aplica sem erro |
| 6 | M2 `clientes` (`plan.md` §3.1): colunas, `check`, índices, RLS ligada, `revoke all` | Engenheiro de dados | aplica sem erro |
| 7 | M3 `clientes_apagamentos` (§3.2) | Engenheiro de dados | aplica sem erro |
| 8 | M4 `clientes_funcoes` (§3.3): 5 funções `security definer`, `search_path = ''`, `revoke`/`grant`; `reaplicar_apagamentos` sem `grant` a `authenticated` | Engenheiro de dados | aplica sem erro |
| 9 | M5 `clientes_politicas` (§3.4): políticas `to authenticated` e privilégios por coluna | Engenheiro de dados | aplica sem erro |
| 10 | Testes `clientes_100` a `clientes_150` (§7.2), com o molde do item 3 e dados fictícios escritos do zero | Engenheiro de dados | `pnpm db:test` verde, inclusive os testes dos itens 2 e 3 |
| 11 | Prova de que o teste pega erro: tirar `S` ou `V` de uma política numa cópia descartável, ver vermelho, desfazer | Engenheiro de dados | vermelho visto e desfeito; nada no commit |

## Fase B · Regras e telas (sem banco)

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 12 | `pnpm add` exato de `libphonenumber-js@1.13.17` e `zod@4.6.7` (este só se B-2 não o trouxer) | Engenheiro de software | `package.json` e `pnpm-lock.yaml` só com eles |
| 13 | `src/domain/clientes/*` e testes (§5): RN-01 a RN-04, RN-07, RN-08, busca, última visita, permissões, exportação, duplicado | Engenheiro de software | `pnpm test` verde (CA-01) |
| 14 | Desenho das telas pelo `DESIGN.md` (lista 390/1440, perfil e abas, painel e tela de Adicionar/Editar, aviso de duplicado, folha de Filtros e Ordenar, janelinha de Excluir, estados); textos pt, es, en | Designer de produto | desenho e textos entregues; peça ou nome fora do `DESIGN.md` listado para a ficha |
| 15 | Rotas, páginas, `preferencias.ts`, `textos/*`, `textos.test.ts`, `clientes.test.tsx`; `src/data/clientes/exemplo-local.ts` para a tela rodar sem banco | Engenheiro de software | `pnpm typecheck`, `pnpm lint`, `pnpm test` verdes |
| 16 | `e2e/clientes*.spec.ts` (§7.3) com o adaptador local; parte que depende de login marcada como pendente | Engenheiro de software | `pnpm test:e2e` verde em 390 e 1440 |
| 17 | Ficha visual (etapa 6): capturas 390 e 1440 com dados fictícios, peças novas para o `DESIGN.md` (título do perfil, agendar daqui, "Exportar dados da cliente") | Designer de produto; confere o Revisor de design | ficha conferida, pronta para o dono |

## Fase C · Servidor e dados reais · só depois de B-1 e B-2

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 18 | `src/server/clientes/esquemas.ts` e `acoes.ts` pelo molde das 6 portas (§4.1); `src/data/clientes/repositorio.ts` e `atendimentos.ts` (vazio até o Agendamento) | Engenheiro de software | `acoes.test.ts` e `repositorio.test.ts` verdes: ordem das portas, 401/403, `org_id` no corpo recusado (CA-04), teto de idas (RNF-02), CA-07b, registro sem dado pessoal (CA-08) |
| 19 | `src/server/clientes/exportar.ts` (§6.1) | Engenheiro de software | `exportar.test.ts` verde: cabeçalhos `no-store`, nome sem dado pessoal, só a cliente, nada guardado (CA-07) |
| 20 | Trocar o adaptador local pelo real no e2e e rodar o fluxo completo com login de teste | Engenheiro de software | `pnpm test:e2e` verde em 390 e 1440 (CA-05, CA-06, CA-09) |
| 21 | `pnpm db:stop`; `pnpm typecheck`, `pnpm lint`, `pnpm test`, `pnpm test:e2e`, `pnpm db:test` | Engenheiro de software | tudo verde; jobs da CI verdes |

## Revisão (etapa 9)

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 22 | Revisar código, camadas e escopo (`git diff --name-only` × `plan.md` §9) | Revisor de código | relatório sem "Bloqueia" |
| 23 | Revisar migrations, funções, políticas e testes; conferir o ADR item por item e preencher "Conferência" | Engenheiro de dados (outra instância, que não construiu) | relatório sem "Bloqueia"; ADR conferido (CA-10) |
| 24 | Revisar dado pessoal e acesso: DP-01 a DP-08, CA-07, CA-07b, CA-08, R-6 e R-7; requisito da cópia diária (§6.3) | Engenheiro de segurança | relatório sem "Bloqueia" |
| 25 | Revisar o risco: funções `security definer`, apagamento que não volta, exportação, nenhum seed ou dado do antigo | Auditor de risco | relatório sem "Bloqueia" |
| 26 | Conferir as telas pelo checklist `DESIGN.md` §10 | Revisor de design | relatório sem "Bloqueia" |
| 27 | Veredito de CA-01 a CA-12, com links | Analista de qualidade (QA) | veredito no PR |

## Fechamento (etapas 10 a 13)

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 28 | Conferir o pedido item por item (RF-01 a RF-11, RN-01 a RN-08, DP-01 a DP-08) | Analista de requisitos | tudo cumprido ou relatado |
| 29 | `docs/STATUS.md`, `docs/BACKLOG.md`, `CHANGELOG.md`, `docs/decisoes/` (respostas E28) no mesmo PR | Documentador | no PR |
| 30 | Confirmar que a auditoria (B-3) está juntada e a base do PR é a `previas`; pedido de merge no molde, com o commit, a CI verde e o link da prévia | Gerente de projeto | mensagem enviada e aviso no celular |
| 31 | Gravar "Aprovação do merge" e juntar só esse commit | Engenheiro de DevOps | merge feito |
