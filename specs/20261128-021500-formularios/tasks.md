# Tarefas · Formulários (núcleo): modelos, link e ficha de saúde cifrada

- **Spec:** `spec.md` · **Plano:** `plan.md` · **ADR:** 0013 (Engenheiro de dados, tabelas do antigo) e
  `docs/adr/0014-formularios-cifra-link-e-imutabilidade.md` (Arquiteto)
- **Escrito por:** Arquiteto de software · Norma: modelo C4 e ADR · **Revisão:** etapa 5 e 5b pendentes
- Com as recomendações E29·1·A, E29·2·A (com E26·1·B e E28·2·B) e E29·3·A; outra resposta muda pelo `plan.md` §13.
- **Parada aberta:** cofre de chaves sem opção gratuita (`plan.md` §0). A fase D e o merge esperam o dono.
- Construir em PR de rascunho pode (E22·B); juntar só depois do portão (tarefa 22) e da autorização do merge gravada.
  Só os arquivos do `plan.md` §8. Banco só local; a IA nunca aplica nada no banco remoto. Falhou: refaz e confere; o
  mesmo erro duas vezes, para e relata. Commits pequenos, Conventional Commits, citando a spec.

## Preparo
| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 1 | Levar ao dono a pergunta do cofre (`plan.md` §0), no molde, junto ou antes da aprovação da spec | Gerente de projeto | resposta gravada em `docs/decisoes/` pelo Documentador |
| 2 | Juntar por merge: `feat/banco-ligacao`, `feat/design-system-codigo`, `feat/entrar-servico`, `feat/clientes` (`plan.md` §11), cada uma quando a fase que a usa for começar | Engenheiro de DevOps | merge sem conflito; árvore limpa |
| 3 | ADR 0013: decisão por tabela do antigo (`plan.md` §3.8), lendo só as migrations da spec §7 | Engenheiro de dados | saída, motivo e norma por linha; conferência em branco |
| 4 | Confirmar com os donos das bases: B-3 (ação pública), B-4 (registro sem login), B-5 (lista do teste 010) | Gerente de projeto | resposta anotada no PR; o que faltar fica como bloqueio |
| 5 | Ler na doc oficial: ação de servidor, cabeçalhos por rota e rota pública do TanStack Start (R-3) | Engenheiro de software | fontes no PR; diferente do plano, para e pede ajuste |
| 6 | Lista dos requisitos ASVS nível 3 do módulo, com a prova de cada um (`plan.md` §7) | Engenheiro de segurança | lista no PR antes da fase C |

## Ficha visual (etapa 6) · antes de qualquer tela
| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 7 | Desenho 390/1440: Fichas, Adicionar ficha (com o link ao salvar), Ver ficha com e sem permissão, Modelos, editor de perguntas, página da cliente (vazia, erro, link indisponível, "Ficha enviada"), assinatura, janelinha de Excluir, estados; peças novas do `DESIGN.md`; textos pt, es, en | Designer de produto | `ficha-visual.md` e `ficha/*.png` com dados fictícios |
| 8 | Conferir pelo checklist `DESIGN.md` §10 | Revisor de design | relatório sem "Bloqueia" |

## Fase A · Banco local
| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 9 | M1 a M6 (`plan.md` §3.1 a §3.5): tabelas, `check`, gatilhos de imutabilidade, índices, RLS ligada e forçada, `revoke all` | Engenheiro de dados | `pnpm db:start` aplica sem erro |
| 10 | M7 e M9 (§3.6): funções com sessão e políticas | Engenheiro de dados | aplica sem erro |
| 11 | M8 (§3.7): esquema `ficha_link`, as 2 funções e as 2 passagens em `public`; `anon` só nelas | Engenheiro de dados | aplica sem erro |
| 12 | Testes `400` a `460` (§5.2), molde do item 3, dados fictícios; `010` só se B-5 pedir | Engenheiro de dados | `pnpm db:test` verde, inclusive itens 2, 3 e Clientes |
| 13 | Prova de que o teste pega erro (tirar `S` numa cópia descartável, ver vermelho, desfazer) | Engenheiro de dados | vermelho visto e desfeito; nada no commit |

## Fase B · Regras e telas (após item 4 e tarefa 8)
| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 14 | `src/domain/formularios/*` e testes (§4.4) | Engenheiro de software | `pnpm test` verde (CA-01, CA-02) |
| 15 | Só o bloco `formularios` em `src/app/i18n/{pt,es,en}.ts` | Engenheiro de software | teste de idiomas verde |
| 16 | Rotas e páginas do app e da página da cliente, pela ficha conferida, com `exemplo-local.ts` | Engenheiro de software | `pnpm typecheck`, `pnpm lint`, `pnpm test` verdes |
| 17 | `e2e/formularios*.spec.ts` com o adaptador local; partes com login e banco marcadas pendentes | Engenheiro de software | `pnpm test:e2e` verde em 390 e 1440 |

## Fase C · Servidor com cofre local (após E36·A, B-3 e B-4)
| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 18 | `src/server/cofre/{cofre,cofre-local}.ts`, `cifra.ts`, `mascarar.ts` e testes (§4.3) | Engenheiro de software | `cifra.test.ts`, `cofre-local.test.ts`, `mascarar.test.ts` verdes |
| 19 | `acoes.ts`, `esquemas.ts`, `link.ts`, `src/data/formularios/*` (§4.1, §4.2) | Engenheiro de software | `acoes.test.ts`, `link.test.ts`, `repositorio.test.ts` verdes (CA-05 a CA-09) |
| 20 | `cifra.integracao.test.ts` contra o banco local (§5.3) | Engenheiro de software | verde (CA-04, com cofre local) |
| 21 | e2e com o banco local e o login de teste, incluindo `formularios-link.spec.ts` (§5.4) | Engenheiro de software | verde em 390 e 1440 (CA-07, CA-10, CA-11) |

## Portão · spec aprovada
| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 22 | Spec "Approved" com "Aprovação do dono" e respostas E29 e do cofre gravadas; resposta diferente da recomendada: ajustar pelo §13 antes de seguir | Analista de requisitos grava; Gerente confere | linhas presentes |

## Fase D · Cofre real (só depois da resposta do dono, `plan.md` §0)
| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 23 | Confirmar região na UE e contrato (DPA) do cofre escolhido; ler a doc oficial da API (ou, se §0·B, a do segredo do Worker) | Engenheiro de segurança | fontes no PR |
| 24 | ADR novo do cofre (substitui a linha D6 do ADR 0014): onde fica a chave, como se troca, quem cifra e decifra | Arquiteto de software | ADR escrito; conferido na tarefa 29 |
| 25 | `cofre-kms.ts` e teste (com dublê da API; nenhuma credencial no repositório nem na CI); credencial só no cofre da Cloudflare, posta pelo dono | Engenheiro de software | testes verdes; nenhum segredo no diff (gitleaks) |
| 26 | `pnpm db:stop`; `pnpm typecheck`, `pnpm lint`, `pnpm test`, `pnpm test:e2e`, `pnpm db:test` | Engenheiro de software | tudo verde; CI verde |

## Revisão (etapa 9)
| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 27 | Código, camadas e escopo (`git diff --name-only` × `plan.md` §8) | Revisor de código | sem "Bloqueia" |
| 28 | Migrations, funções, políticas, pgTAP; ADR 0013 item por item | Engenheiro de dados (outra instância) | sem "Bloqueia"; ADR conferido (CA-12) |
| 29 | Cifra, cofre, link, máscara do token, registro, nível 3 (lista da tarefa 6) | Engenheiro de segurança | sem "Bloqueia" |
| 30 | Risco: ADR 0014 e o do cofre (CA-13), funções `security definer`, funções de `anon` (R-4), B-5, nada do antigo | Auditor de risco | sem "Bloqueia" |
| 31 | Telas contra a ficha aprovada e `DESIGN.md` §10 | Revisor de design | sem "Bloqueia" |
| 32 | Veredito CA-01 a CA-14 | QA | veredito no PR |

## Fechamento (etapas 10 a 13)
| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 33 | Conferir o pedido item por item (RF-01 a RF-14, RNF-01 a RNF-08) | Analista de requisitos | cumprido ou relatado |
| 34 | `docs/STATUS.md`, `docs/BACKLOG.md`, `CHANGELOG.md`, `docs/decisoes/` no mesmo PR | Documentador | no PR |
| 35 | Bases na `previas` e base do PR na `previas`; pedido de merge no molde, com commit, CI verde e link da prévia | Gerente de projeto | mensagem enviada e aviso no celular |
| 36 | Gravar "Aprovação do merge" e juntar só esse commit | Engenheiro de DevOps | merge feito |
