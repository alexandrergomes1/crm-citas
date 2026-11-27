# Módulo: Fidelidade (FID)

> Pontos que a cliente ganha por comprar, extrato de cada movimento, níveis (Classic, Silver, Gold, Black) e, no futuro, recompensas, validade e indicação.
> Hoje: pontos, extrato, ajuste manual e quatro níveis fixos. Recompensas e resgate ainda não existem.

**Telas e rotas:** `/{org}/fidelidade` (dentro do menu Marketing) · **Código:** `src/workspace/fidelidade` (`FidelidadeView.tsx`, `LoyaltyRanking.tsx`, `LoyaltyDialogs.tsx`), `src/domain/loyalty.ts`, `loyalty-presentation.ts` · **Spec(s):** sem spec no atual. No legado: `docs/produto/legado/specs/15-loyalty-rewards.md` e o mapa inteiro `docs/produto/legado/produto/fidelidade-mapa-futuro.md` (usado inteiro abaixo, seções 1 a 10).

Como ler a coluna Origem: "mapa §3:25" = `fidelidade-mapa-futuro.md`, seção 3, linha 25. "legado 15:9" = spec 15, linha 9. "R4 B 15" = relatório R4, seção B, spec 15.

## Recursos
| ID | Recurso | Estado | Onde | Origem |
|---|---|---|---|---|
| FID-01 | Pontos por comprar na comanda, lançados num livro (ledger) que nunca é sobrescrito | pronto | `/fidelidade`; `src/domain/loyalty.ts` | legado 15:9,22; R5 B scope-master:115,118; legado 23:57-67,103; R2 B STATUS:32 |
| FID-02 | Extrato: cada movimento explicado (origem, pontos, saldo depois) | pronto | Fidelidade › cliente | legado 15:27; legado 23:57-67; mapa §4:30 |
| FID-03 | Ajuste manual de pontos, com motivo e registro de auditoria | pronto | Fidelidade (`LoyaltyDialogs.tsx`) | legado 15:22; R5 B scope-master:119; mapa §4:30 |
| FID-04 | Quatro níveis fixos (Classic, Silver, Gold, Black) com barra de progresso | pronto · "Ouro" tem dois limites diferentes, 1.500 e 3.000 pontos (a limpar na Fase 4) | Fidelidade; `loyalty.ts:71` (Gold 3000) | R5 B scope-master:116; mapa:3-4; R3 B audit:28; R2 B BACKLOG:24 |
| FID-05 | Ranking e busca de clientes do programa | pronto | Fidelidade (`LoyaltyRanking.tsx`) | mapa §7:47 |
| FID-06 | Checkout idempotente não duplica pontos; estorno ou cancelamento gera lançamento inverso | regra no antigo; critério do estorno aberto (`[ ]`) · não verificado (atual) | Comanda | legado 15:11-12,29 |
| FID-07 | Regras de acúmulo configuráveis por estúdio: pontos por valor gasto (ex.: 1 por 1 €), por serviço, quantidade, nível e período | planejado | futuro Fidelidade › Regras | mapa §1:10; legado 15:10 |
| FID-08 | Multiplicador por serviço, categoria, produto, nível, dia da semana ou período ("pontos em dobro") | planejado | Regras | mapa §1:11 |
| FID-09 | Pontos por ação: primeira visita, indicação aprovada, avaliação publicada, aniversário, ficha preenchida | planejado | Regras | mapa §1:12 |
| FID-10 | Teto por comanda e por período; arredondamento; o que não pontua (pacote já pago, brinde, desconto total) | planejado | Regras | mapa §1:13 |
| FID-11 | Níveis editáveis: nome, cor, faixa de pontos ou gasto em 12 meses | planejado | futuro Níveis | mapa §2:17 |
| FID-12 | Benefícios por nível: multiplicador, desconto fixo, prioridade na lista de espera, brinde de aniversário | planejado | Níveis | mapa §2:18 |
| FID-13 | Subida e descida de nível: na hora ou recalculada por mês; carência antes de rebaixar; aviso ao subir | planejado | Níveis | mapa §2:19-20 |
| FID-14 | Catálogo de recompensas: desconto em € ou %, serviço grátis, produto, upgrade, vale-presente | planejado P3 | futuro Recompensas | legado 15:22-23; mapa §3:23 |
| FID-15 | Recompensa com custo em pontos, validade, limite por cliente e mês, nível mínimo, serviços elegíveis, estoque | planejado P3 | Recompensas | mapa §3:24; legado 15:13 |
| FID-16 | Resgate na comanda, na mesma transação; estorno devolve pontos e benefício | planejado P3 (`[ ]`) | Comanda | legado 15:13,28-29; mapa §3:25 |
| FID-17 | Resgate manual pela recepção; autoatendimento no portal ou reserva online (futuro) | planejado | Recompensas; Reserva online | mapa §3:26 |
| FID-18 | Validade dos pontos: nunca, 6, 12 ou 24 meses; vence por lote (o mais antigo primeiro); aviso de pontos a vencer | planejado | futuro Regras; `expires_at` | mapa §4:29 |
| FID-19 | Bloqueio de resgate por fraude ou abuso (cliente marcada, limite diário) | planejado | Recompensas | mapa §4:31 |
| FID-20 | Indicação: código ou link; pontos para quem indicou e para quem chegou, só depois da primeira comanda paga | planejado | futuro Indicação e aniversário | mapa §5:34 |
| FID-21 | Bônus de aniversário (pontos ou brinde) com janela de validade e mensagem automática | planejado | Indicação e aniversário | mapa §5:35 |
| FID-22 | Cashback opcional (saldo em € em vez de pontos): coexiste ou substitui? | a definir | — | mapa §5:36 |
| FID-23 | Cartão ou selo digital ("a 10ª limpeza é grátis") como modelo alternativo | a definir | — | mapa §5:37; R3 B M/booksy.md:141-155 |
| FID-24 | Retenção por quantidade de procedimentos ou pontuação por procedimento, cálculo automático por atendimento, saldo na ficha | planejado | Fidelidade; ficha da cliente | R5 B product-vision-detail:72-74 |
| FID-25 | Saldo e histórico visíveis para a própria cliente; relatório emitido × resgatado; benefício de pacote ou membro | planejado (LOY-01) | portal; Relatórios | R5 B future-modules-map:77-87 |
| FID-26 | Mensagens do programa: boas-vindas, pontos ganhos, pontos a vencer, subiu de nível, recompensa disponível; idioma e canal por cliente | planejado | atalho para Mensagens › Modelos | mapa §6:40-42; mapa §7:52 |
| FID-27 | Visão geral e relatórios: pontos em circulação, clientes ativas, resgates do mês, passivo (pontos × valor do ponto), expiração, retorno, custo do programa | planejado | futuro Visão geral e Relatórios | mapa §7:46,53 |
| FID-28 | Oito seções do módulo (padrão `SectionedPage`, com Fechar e Voltar): Visão geral, Clientes, Regras, Níveis, Recompensas, Indicação e aniversário, Mensagens do programa, Relatórios | planejado; hoje só "Clientes" (ranking, busca, extrato, ajuste) | `/fidelidade` | mapa §7:44-53 |
| FID-29 | Permissões `fidelidade.view`, `.adjust`, `.configure`, `.redeem`; auditoria de toda mudança de regra, nível ou ajuste | planejado (o código tem só a chave de módulo `fidelidade`) | Ajustes › Perfis | mapa §8:56-57; `src/domain/access.ts:29` |
| FID-30 | Regras versionadas: a mudança vale daqui para frente e nunca reescreve o histórico | planejado | Regras | mapa §8:58 |
| FID-31 | Fidelidade é módulo do plano (extra 12 € no Básico e Profissional; incluído no Completo); responde 404 se desligado | pronto como dado e regra de menu | Ajustes › Plano | legado 29:63,108; R4 B 29 |
| FID-32 | Pontos no cartão da cliente no agendamento (ícone de pontos) | planejado ("não cumpre") | Agendamento (CARD-09·B) | R1 B rv:82; R3 B agd:25 |
| FID-33 | Módulo antigo de fidelidade no domínio usado só pelos testes ("ou se liga ao app, ou sai") | parcial | `src/domain` | R3 B audit:40 |

"Estado" é o que os documentos dizem; o código é conferido quando o módulo entra em trabalho.

## Decisões
| ID | Decisão | Situação | Origem |
|---|---|---|---|
| FID-D01 | Fidelidade vive dentro do menu Marketing | **sugestão a confirmar** (spec 28 marcada pronta, sem frase) | mapa:7; legado 28:9,21 |
| FID-D02 | Pontos são lançados num livro (ledger), nunca apenas sobrescritos na cliente | **sugestão a confirmar** (regra da spec antiga, sem frase) | legado 15:9; legado 23:57-67 |
| FID-D03 | Regras versionadas: mudança vale daqui para frente | **sugestão a confirmar** (mapa sem prova) | mapa §8:58 |
| FID-D04 | Ordem de entrega: 1) regras de acúmulo e níveis editáveis; 2) recompensas e resgate na comanda; 3) validade e avisos; 4) indicação e aniversário; 5) relatórios e mensagens | **sugestão a confirmar** (proposta do antigo) | mapa §10:65-70 |
| FID-D05 | Ordem pós-núcleo: Marketing, depois Fidelidade, depois Acesso, depois SaaS | **sugestão a confirmar** | R5 B future-modules-map:38-46 |
| FID-D06 | Fidelidade básica no núcleo de todos os planos (proposta técnica) × extra de 12 € na spec 29. Dois lados se contradizem | **sugestão a confirmar** (decisão comercial é do dono) | R5 B roadmap:262-277; legado 29:63 |
| FID-D07 | Fidelidade e Relatórios avançados "saíram do menu da Karenn" | **sugestão a confirmar** (texto de mockup V25) | R1 B Main.dc.html |
| FID-D08 | Dois limites de "Ouro" (1.500 e 3.000) serão limpos na Fase 4 | **sugestão a confirmar** (Fase 4 aceita em lote "aceito todas", 22/11) | R2 B BACKLOG:24 (`docs/BACKLOG.md:24`); R3 B audit:28 |

## Regras de negócio
- Pontos nunca mudam sem um lançamento no extrato; todo ajuste tem motivo e auditoria. Origem: legado 15:9; mapa §4:30.
- Fazer o mesmo checkout duas vezes não dá pontos duas vezes. Origem: legado 15:11.
- Cancelar ou estornar gera lançamento inverso. Origem: legado 15:12; mapa §1:14.
- Recompensa só vale se a cliente tem elegibilidade, saldo, validade e dentro do limite. Origem: legado 15:13.
- Resgate acontece na mesma transação da comanda. Origem: legado 15:28; mapa §3:25.
- Indicação só pontua depois da primeira comanda paga. Origem: mapa §5:34.
- Mensagem de fidelidade só com consentimento de marketing; opt-in e opt-out registrados. Origem: mapa §6:42.
- Mudança de regra ou nível vale daqui para frente. Origem: mapa §8:58.
- Toda tabela do módulo tem `org_id` e RLS; acúmulo e resgate usam funções `_atomic`. Origem: mapa §9:63.

## Pendências e perguntas
| Pergunta ou pendência | Origem |
|---|---|
| Qual é o limite certo de "Ouro": 1.500 ou 3.000 pontos? | R3 B audit:28 |
| Cashback: coexiste com pontos ou substitui? Cartão de selos entra? | mapa §5:36-37 |
| Pontos ou créditos (LOY-01)? Como interage com o livro de saldo da cliente? | R5 B future-modules-map:77-87 |
| Fidelidade fica no núcleo ou como extra pago? | R5 B roadmap:262-277; legado 29:63 |
| Ligar ou apagar o módulo de regra usado só pelos testes | R3 B audit:40 |
| Quando começa? Fidelidade com recompensas é "Fase 3" do roadmap e "P2" da revisão de 30/10 | R5 B roadmap:215; R5 B revisao-30-10:35 |
| Prints de fidelidade do Fresha e Booksy: não há legenda | R4 F; R3 B M/booksy.md:141-155 |
| Dados necessários: `loyalty_programs`, `loyalty_rules`, `loyalty_tiers` (editáveis), `loyalty_rewards`, `loyalty_redemptions`, `loyalty_referrals`, `expires_at` em `loyalty_point_entries` (precisam de spec nível C) | mapa §9:61-63 |

## Referências
- `docs/produto/legado/produto/fidelidade-mapa-futuro.md` (inteiro, seções 1 a 10); `docs/produto/legado/specs/15-loyalty-rewards.md`; `23-agenda-integrity-and-operational-ledgers.md` (livro de pontos); `28-navegacao-marketing-ajustes.md`; `29-access-roles-modules.md`.
- Fresha: help-center de fidelidade (`legado 24:17-26`). Booksy: `docs/referencias-mercado/booksy.md` (cartão de fidelidade digital).
- Módulos vizinhos: MKT (menu), MSG (avisos), SAA (plano), RES (resgate online).

Regra: só vale decisão registrada em `docs/decisoes/` (molde de pergunta). Tudo desta tabela é **a confirmar**; a situação antiga fica entre parênteses só como histórico e volta a ser perguntada quando o módulo for trabalhado (resposta 15a do dono, 24/11/2026).
