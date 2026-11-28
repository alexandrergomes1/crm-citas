# Tarefas · Clientes, primeira versão (item 5 da fila, núcleo)

- **Spec:** `spec.md` · **Plano:** `plan.md` · **ADR:** `docs/adr/0008-clientes-dados-busca-e-pedidos.md`
- **Escrito por:** Arquiteto de software · Norma: modelo C4 e ADR · **Revisão:** 5b (Gerente de projeto) devolvida com
  5 ajustes, feitos em 28/11; etapa 5 pendente
- Com as recomendações E28·1·A, E28·2·B (com E26·1·B) e E28·3·A; outra resposta muda as tarefas pelo `plan.md` §12.
- **Construir em PR de rascunho pode** (E22·B); **juntar só depois** do portão da tarefa 19 (spec "Approved" com
  "Aprovação do dono") e da autorização do merge gravada (`AGENTS.md` §3 regra 1 e §8). Só os arquivos do `plan.md` §9.
  Banco só local; a IA nunca aplica nada no banco remoto (`AGENTS.md` §1). Falhou: refaz e confere; o mesmo erro duas
  vezes, para e relata. Commits pequenos, Conventional Commits, citando a spec.

## Preparo

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 1 | Juntar por merge na `feat/clientes`, nesta ordem: `feat/banco-ligacao` (item 3), `feat/design-system-codigo` (item 4), `feat/entrar-servico` (E36·A) (`plan.md` §10). Cada uma só quando tiver o que a fase seguinte usa com commit (B-5); senão, essa fase espera | Engenheiro de DevOps | merge sem conflito; árvore limpa |
| 2 | Escrever o ADR 0008 com as decisões do `plan.md` §3.6 (por tabela do antigo) e §13 (D1 a D9) | Engenheiro de dados (tabelas) e Arquiteto de software (D1 a D9) | ADR com saída, motivo e norma por linha; conferência em branco |
| 3 | Ler na doc oficial: `pg_trgm` no Supabase (R-4); `createServerFn`, rotas de servidor e rotas por pasta do TanStack Start (R-2); README do `libphonenumber-js` 1.13.17 (D1) | Engenheiro de dados (1º) e Engenheiro de software (2º e 3º) | fontes anotadas no PR; se algo não existir como no plano, parar e pedir ajuste |
| 4 | Conferir B-4 (país do estúdio): se o item 3 não trouxer `pais`, usar a M0 | Engenheiro de dados | decisão anotada no ADR |

## Ficha visual (etapa 6) · antes de construir qualquer tela

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 5 | Desenho das telas no canvas, pelo `DESIGN.md`: lista 390/1440, perfil e abas, painel e tela de Adicionar/Editar, aviso de duplicado, folha de Filtros e Ordenar, janelinha de Excluir, estados; peças novas para o `DESIGN.md` (título do perfil, agendar daqui, "Exportar dados da cliente"); textos pt, es, en | Designer de produto | `ficha-visual.md` e `ficha/*.png` com dados fictícios |
| 6 | Conferir a ficha pelo checklist `DESIGN.md` §10 | Revisor de design | relatório sem "Bloqueia"; ficha pronta para o dono |

## Fase A · Banco local (depois do item 3 juntado)

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 7 | M0 (se preciso) e M1 `extensoes_busca` | Engenheiro de dados | `pnpm db:start` aplica sem erro |
| 8 | M2 `clientes` (`plan.md` §3.1): colunas, `check`, índices, RLS ligada, `revoke all` | Engenheiro de dados | aplica sem erro |
| 9 | M3 `clientes_apagamentos` (§3.2) | Engenheiro de dados | aplica sem erro |
| 10 | M4 `clientes_funcoes` (§3.3): 5 funções `security definer`, `search_path = ''`, `revoke`/`grant`; `reaplicar_apagamentos` sem `grant` a `authenticated` | Engenheiro de dados | aplica sem erro |
| 11 | M5 `clientes_politicas` (§3.4): políticas `to authenticated` e privilégios por coluna | Engenheiro de dados | aplica sem erro |
| 12 | Testes `clientes_100` a `clientes_150` (§7.2), com o molde do item 3 e dados fictícios escritos do zero | Engenheiro de dados | `pnpm db:test` verde, inclusive os testes dos itens 2 e 3 |
| 13 | Prova de que o teste pega erro: tirar `S` ou `V` de uma política numa cópia descartável, ver vermelho, desfazer | Engenheiro de dados | vermelho visto e desfeito; nada no commit |

## Fase B · Regras e telas (depois do item 4 juntado e da ficha conferida, tarefa 6)

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 14 | `pnpm add` exato de `libphonenumber-js@1.13.17` (o `zod` vem da `feat/entrar-servico`) | Engenheiro de software | `package.json` e `pnpm-lock.yaml` só com ele |
| 15 | `src/domain/clientes/*` e testes (§5): RN-01 a RN-04, RN-07, RN-08, busca, última visita, permissões, exportação, duplicado | Engenheiro de software | `pnpm test` verde (CA-01) |
| 16 | Só o bloco `clientes` em `src/app/i18n/{pt,es,en}.ts` (pasta comum que nasce na `feat/entrar-servico`, formato do ADR 0006; R-9: sem ela juntada, a tarefa espera) | Engenheiro de software, com os textos da ficha | teste de idiomas da pasta verde |
| 17 | Rotas, páginas, `preferencias.ts`, `clientes.test.tsx`, pela ficha conferida; `src/data/clientes/exemplo-local.ts` para a tela rodar sem banco | Engenheiro de software | `pnpm typecheck`, `pnpm lint`, `pnpm test` verdes |
| 18 | `e2e/clientes*.spec.ts` (§7.3) com o adaptador local; parte que depende de login marcada como pendente | Engenheiro de software | `pnpm test:e2e` verde em 390 e 1440 |

## Portão · spec aprovada

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 19 | A spec tem "Status: Approved" e a linha "Aprovação do dono" (fala literal, data, link), com as respostas E28 gravadas; se a resposta não for a recomendada, ajustar plano e tarefas pelo §12 antes de seguir | Analista de requisitos grava; Gerente de projeto confere | linhas presentes; sem elas nada segue para revisão nem merge |

## Fase C · Servidor e dados reais (depois da `feat/entrar-servico` juntada, E36·A)

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 20 | `src/server/clientes/esquemas.ts` e `acoes.ts` pelo molde das 6 portas da `feat/entrar-servico` (§4.1); `src/data/clientes/repositorio.ts` e `atendimentos.ts` (vazio até o Agendamento) | Engenheiro de software | `acoes.test.ts` e `repositorio.test.ts` verdes: ordem das portas, 401/403, `org_id` no corpo recusado (CA-04), teto de idas (RNF-02), CA-07b, registro sem dado pessoal (CA-08) |
| 21 | `src/server/clientes/exportar.ts` (§6.1) | Engenheiro de software | `exportar.test.ts` verde: cabeçalhos `no-store`, nome sem dado pessoal, só a cliente, nada guardado (CA-07) |
| 22 | Trocar o adaptador local pelo real no e2e e rodar o fluxo completo com o login de teste da `feat/entrar-servico` | Engenheiro de software | `pnpm test:e2e` verde em 390 e 1440 (CA-05, CA-06, CA-09) |
| 23 | `pnpm db:stop`; `pnpm typecheck`, `pnpm lint`, `pnpm test`, `pnpm test:e2e`, `pnpm db:test` | Engenheiro de software | tudo verde; jobs da CI verdes |

## Revisão (etapa 9)

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 24 | Revisar código, camadas e escopo (`git diff --name-only` × `plan.md` §9) | Revisor de código | relatório sem "Bloqueia" |
| 25 | Revisar migrations, funções, políticas e testes; conferir o ADR 0008 item por item e preencher "Conferência" | Engenheiro de dados (outra instância, que não construiu) | relatório sem "Bloqueia"; ADR conferido (CA-10) |
| 26 | Revisar dado pessoal e acesso: DP-01 a DP-08, CA-07, CA-07b, CA-08, R-6 e R-7; requisito da cópia diária (§6.3) | Engenheiro de segurança | relatório sem "Bloqueia" |
| 27 | Revisar o risco: funções `security definer`, apagamento que não volta, exportação, nenhum seed ou dado do antigo | Auditor de risco | relatório sem "Bloqueia" |
| 28 | Conferir as telas construídas contra a ficha aprovada e o checklist `DESIGN.md` §10 | Revisor de design | relatório sem "Bloqueia" |
| 29 | Veredito de CA-01 a CA-12, com links | Analista de qualidade (QA) | veredito no PR |

## Fechamento (etapas 10 a 13)

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 30 | Conferir o pedido item por item (RF-01 a RF-11, RN-01 a RN-08, DP-01 a DP-08) | Analista de requisitos | tudo cumprido ou relatado |
| 31 | `docs/STATUS.md`, `docs/BACKLOG.md`, `CHANGELOG.md`, `docs/decisoes/` (respostas E28) no mesmo PR | Documentador | no PR |
| 32 | Confirmar que a `feat/entrar-servico` (com a auditoria, E36·A) está na `previas` e que a base do PR é a `previas`; pedido de merge no molde, com o commit, a CI verde e o link da prévia | Gerente de projeto | mensagem enviada e aviso no celular |
| 33 | Gravar "Aprovação do merge" e juntar só esse commit | Engenheiro de DevOps | merge feito |
