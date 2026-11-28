# Tarefas · Checkout v1 (núcleo)

- **Spec:** `spec.md` · **Plano:** `plan.md` · **ADR:** 0017 (Arquiteto, chega pela `feat/caixa`), 0015 (Engenheiro de
  dados, na T3)
- **Escrito por:** Arquiteto de software · **Norma:** modelo C4 e ADR; método do Spec Kit
- Só os arquivos do `plan.md` §8. Quem constrói não revisa. Antes de enviar: `pnpm typecheck`, `pnpm lint`, `pnpm test`,
  `pnpm db:test` (banco **local**). A IA nunca aplica no banco remoto nem publica.
- Construção em PR de rascunho pode começar antes da aprovação (E22·B); o pedido de merge só com "Status: Approved", as
  respostas E31·1 a E31·3 gravadas e o Caixa e o Agendamento já na `previas`.

## Preparo
| # | Tarefa | Papel | Pronto quando |
|---|---|---|---|
| T0 | Conferir E31·1–E31·3, E24·3 e as lacunas L-2 a L-6; se outra que não a recomendação, aplicar o §11 do plano (ou parar e voltar à 5b) | Gerente de projeto | respostas citadas no PR |
| T1 | Branch empilhada: merge de `feat/agendamento` e `feat/caixa` (nesta ordem); PR de rascunho | Engenheiro de DevOps | CI roda na pilha; ADR 0017 presente; nada juntado numa base |
| T2 | **Ficha visual antes das telas** (etapa 6): Revisar, Pagar, Concluído (e "sem valor"), Ver checkout, botão no painel, em 390 e 1440; nomes que faltam no `DESIGN.md` §6 (avançar; formas) | Designer de produto; confere o Revisor de design; aprova o dono | ficha aprovada; linhas do `DESIGN.md` gravadas |

## Banco (Engenheiro de dados)
| # | Tarefa | Pronto quando |
|---|---|---|
| T3 | ADR 0015: saída de cada linha do plano §4.1, com motivo e norma; lê só as migrations do antigo citadas na spec §7 (E22·B) | ADR escrito; conferência por outra instância e pelo Auditor de risco (E16·1) |
| T4 | Migrations M1 a M6 (plano §4.2 a §4.5), carimbo **depois** de todas as do Caixa, do Agendamento e do Catálogo; guarda na M1; M4 = ligação pagamento → caixa (RF-18) | `pnpm db:start` e `pnpm db:test` verdes no local |
| T5 | pgTAP 600 a 680 (plano §4.6), inclusive concorrência com duas ligações (650); provar que cada teste pega o erro | verdes; prova do vermelho relatada |

## Código (Engenheiro de software)
| # | Tarefa | Pronto quando |
|---|---|---|
| T6 | `src/domain/checkout/*` e testes (plano §5.2) | CA-01, CA-02, CA-04 em unidade verdes |
| T7 | `src/data/checkout/*` e a **troca dos 3 encaixes** (`src/data/agendamento/checkout.ts`, `src/data/caixa/entradas-por-forma.ts`, `src/data/caixa/atendimentos-sem-checkout.ts`) | consultas conferidas pelo Engenheiro de dados; testes do Agendamento e do Caixa continuam verdes |
| T8 | `src/server/checkout/*` e testes (plano §5.3); `consultas.ts` do Agendamento e de Clientes só se L-5 mandar | CA-03, CA-05, CA-10, CA-11 no servidor verdes; idas ≤ teto (§6) |
| T9 | Telas, rota, botão do painel e bloco `checkout` dos idiomas (plano §5.5), **só depois da T2** | `checkout.test.tsx` verde |
| T10 | e2e (plano §7) nos projetos 390 e 1440 | verdes |

## Revisão (ninguém revisa o que fez)
| # | Tarefa | Papel | Pronto quando |
|---|---|---|---|
| T11 | Código e escopo (`git diff --name-only` contra o §8) | Revisor de código | sem "Bloqueia" |
| T12 | Banco: migrations, pgTAP, ADR 0015 item por item; gatilho em `public.agendamentos` (com o Engenheiro de dados do Agendamento) e em `public.caixas` (com o do Caixa) | Engenheiro de dados (outra instância) e Auditor de risco | sem "Bloqueia" |
| T13 | **Dinheiro e acesso:** recálculo no servidor e no banco, um fechado por agendamento, idempotência, ligação com o caixa e corrida com o fechamento, RF-17, E31·2, registro sem texto livre, **E6·1 sem contorno**, ADR 0017 | **Auditor de risco** e **Engenheiro de segurança** | sem "Bloqueia" |
| T14 | Tela: checklist `DESIGN.md` §10, capturas 390 e 1440 | Revisor de design | sem "Bloqueia" |
| T15 | Veredito CA-01 a CA-16 | Analista de qualidade (QA) | veredito no PR |

## Fechar
| # | Tarefa | Papel |
|---|---|---|
| T16 | Conferir o pedido item por item | Analista de requisitos |
| T17 | `docs/STATUS.md`, `docs/BACKLOG.md`, `CHANGELOG.md`, `docs/decisoes/` no mesmo PR; numeração de ADR e pgTAP | Documentador |
| T18 | Pedido de merge no molde, com commit, CI verde e link da prévia, **depois** do merge do Caixa | Gerente de projeto |
