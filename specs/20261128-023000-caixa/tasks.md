# Tarefas · Caixa (núcleo)

- **Spec:** `spec.md` · **Plano:** `plan.md` · **ADR:** 0017 (Arquiteto), 0016 (Engenheiro de dados, na T3)
- **Escrito por:** Arquiteto de software · **Norma:** modelo C4 e ADR; método do Spec Kit
- Só os arquivos do `plan.md` §8. Quem constrói não revisa. Antes de enviar: `pnpm typecheck`, `pnpm lint`, `pnpm test`,
  `pnpm db:test` (banco **local**). A IA nunca aplica no banco remoto nem publica.
- Construção em PR de rascunho pode começar antes da aprovação (E22·B); o pedido de merge só com "Status: Approved" e as
  respostas E32·1 a E32·3, E31·1, E31·3 e **E24·3** gravadas (até a E24·3, vale a recusa provisória, mostrada ao dono no pedido).

## Preparo
| # | Tarefa | Papel | Pronto quando |
|---|---|---|---|
| T0a | Conferir que as respostas E32·1–E32·3, E31·1, E31·3 e E24·3 estão gravadas (só confere) | Gerente de projeto | respostas citadas no PR |
| T0b | Resposta diferente da recomendação: aplicar o §11 do plano, ou parar e voltar à 5b onde ele manda | Arquiteto de software | plano ajustado, ou parada relatada |
| T1 | Branch empilhada: merge de `feat/banco-ligacao`, `feat/design-system-codigo`, `feat/entrar-servico`, `feat/catalogo` (`navegacao.ts` vem da `feat/entrar-servico`); PR de rascunho | Engenheiro de DevOps | CI roda na pilha; nada juntado numa base |
| T2 | **Ficha visual antes das telas** (etapa 6): Caixa atual fechado e aberto, Abrir, Sangria/Suprimento, Fechar (2 passos), Histórico, Ver, em 390 e 1440; nomes e peças que faltam no `DESIGN.md` (spec §4) | Designer de produto; confere o Revisor de design; aprova o dono | ficha aprovada; linhas do `DESIGN.md` gravadas |

## Banco (Engenheiro de dados)
| # | Tarefa | Pronto quando |
|---|---|---|
| T3 | ADR 0016: saída de cada linha do plano §4.1 (sugestão do Arquiteto), com motivo e norma; lê só as migrations do antigo citadas na spec §7 (E22·B, RG-01) | ADR escrito; conferência por outra instância do Engenheiro de dados e pelo Auditor de risco (E16·1) |
| T4 | Migrations M1 a M5 (plano §4.2 a §4.5), carimbo depois das bases e antes de qualquer migration do Checkout | `pnpm db:start` e `pnpm db:test` verdes no local |
| T5 | pgTAP 700 a 760 (plano §4.6), inclusive concorrência com duas ligações; provar que cada teste pega o erro (tirar a regra numa cópia local, ver vermelho, desfazer) | verdes; prova do vermelho relatada |

## Código (Engenheiro de software)
| # | Tarefa | Pronto quando |
|---|---|---|
| T6 | `src/domain/caixa/*` e testes (plano §5.2); conferir `crypto.subtle.digest` e `Intl` na documentação oficial antes de usar | CA-01 em unidade verde |
| T7 | `src/data/caixa/*` (plano §5.4), com os dois encaixes vazios e o `exemplo-local.ts` | consultas conferidas pelo Engenheiro de dados |
| T8 | `src/server/caixa/*` e testes (plano §5.3), pelo contrato da E36·A | CA-02 a CA-11 na parte do servidor verdes; idas ≤ teto (§6) |
| T9 | Telas, rotas, navegação e bloco `caixa` dos idiomas (plano §5.5), **só depois da T2** | `caixa.test.tsx` verde; checagem de tipos acusa chave faltando |
| T10 | e2e (plano §7) nos projetos 390 e 1440 | verdes |

## Revisão (ninguém revisa o que fez)
| # | Tarefa | Papel | Pronto quando |
|---|---|---|---|
| T11 | Código e escopo (`git diff --name-only` contra o §8) | Revisor de código | sem "Bloqueia" |
| T12 | Banco: migrations, pgTAP, ADR 0016 item por item | Engenheiro de dados (outra instância) e Auditor de risco | sem "Bloqueia" |
| T13 | **Dinheiro e acesso:** contador vivo e versão, sangria, fechamento, concorrência, teto técnico, idempotência, E32·3, registro sem texto livre, **E6·1 sem contorno** (`app.autor_da_sessao()`), ADR 0017 | **Auditor de risco** e **Engenheiro de segurança** | sem "Bloqueia" |
| T14 | Tela: checklist `DESIGN.md` §10, capturas 390 e 1440 | Revisor de design | sem "Bloqueia" |
| T15 | Veredito CA-01 a CA-16 | Analista de qualidade (QA) | veredito no PR |

## Fechar
| # | Tarefa | Papel |
|---|---|---|
| T16 | Conferir o pedido item por item | Analista de requisitos |
| T17 | `docs/STATUS.md`, `docs/BACKLOG.md`, `CHANGELOG.md`, `docs/decisoes/` no mesmo PR; numeração de ADR e pgTAP | Documentador |
| T18 | Pedido de merge no molde, com commit, CI verde e link da prévia; **antes do Checkout** (ADR 0017 · D1) | Gerente de projeto |
