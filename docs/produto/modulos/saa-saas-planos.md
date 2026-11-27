# Módulo: SaaS e Planos (SAA)

> O sistema como produto para vários estúdios: planos (Básico, Profissional, Completo), módulos ligados ou desligados por estúdio, cobrança, área do administrador da plataforma e suporte.
> Hoje existe a base no banco e a aba "Plano" em Ajustes; a cobrança e a área master ainda não existem.

**Telas e rotas:** Ajustes › Plano (`/{org}/configuracoes`, seção `plano`; só proprietária e administração). Planejadas: área master, fila de pedidos de ativação, "Entrar como o estúdio" · **Código:** `src/workspace/ajustes/PlanSection.tsx`, `PlanParts.tsx`, `src/domain/plan.ts`, `plan-presentation.ts`, `src/domain/access.ts` (chaves de módulo), `src/data/plan/` · **Spec(s):** sem spec no atual (ICEBOX item 22, "a examinar, sem valor de decisão"). No legado: `docs/produto/legado/specs/20-saas-admin-billing.md`, `29-access-roles-modules.md`, `produto/saas-stack-decision.md`.

Como ler a coluna Origem: "legado 29:55-67" = `docs/produto/legado/specs/29-access-roles-modules.md` linhas 55 a 67. "R4 B 29" = relatório R4, seção B, spec 29.

## Recursos
| ID | Recurso | Estado | Onde | Origem |
|---|---|---|---|---|
| SAA-01 | Registro de módulos e planos no banco (`modules`, `plans`, `plan_modules`, `org_subscriptions`, `org_modules`, funções `org_enabled_modules` e `org_has_module`); núcleo sempre ligado: agenda, clientes, catálogo, financeiro, anamnese | pronto, base de banco (antigo) · "só mockup V25" e "botões desligados" (atual) | banco; `src/domain/plan.ts` | legado 29:43-53,148-152; R4 B 29; R1 B canvas.json (t-plano); R3 B audit:30 |
| SAA-02 | Três planos fixos (Básico, Profissional, Completo) mais extras com preço; preços de exemplo 29, 59 e 99 € e extras (Mensagens 12 €, Cobrança por transferência 5 €, Avaliações 9 €, Reserva online 15 €, Fidelidade 12 €, Campanhas 15 €, Estoque 12 €, Várias unidades 29 € cada) | pronto como dado; preços são de exemplo, editáveis pelo master | Ajustes › Plano | legado 29:26,55-69; R4 B 29; R1 B Main.dc.html |
| SAA-03 | Menu e páginas respeitam módulos do plano e o papel; Marketing e Fidelidade respondem 404 com módulo desligado | pronto (antigo) | `src/app-shell/nav-config.ts`; `requireModule` | legado 29:104-109,151 |
| SAA-04 | Ajustes › Plano: plano, situação (teste, ativo, suspenso), total por mês, limites e uso, módulos ativos e extras com preço; "Plano ainda não configurado" enquanto não houver | pronto (antigo e código) · parcial: botões desligados (R3) | `PlanSection.tsx` | legado 29:113-118,152; R3 B audit:30 |
| SAA-05 | Pedido de ativação de módulo: a janela existe (valor, nova mensalidade, liberação em até 1 dia útil), mas o botão "Pedir ativação" está desligado; ativar é com o suporte | parcial | `PlanParts.tsx` (`ActivationDialog`) | legado 29:113-115 |
| SAA-06 | Estúdio novo entra em teste de 30 dias no Profissional; estúdios existentes do piloto entram no Completo; suspenso ou cancelado fica só com o núcleo (dados preservados) | pronto, base de banco | banco | legado 29:48-52 |
| SAA-07 | Limites do plano validados no servidor (ex.: número de profissionais); suspensão preserva dados | planejado (spec 20) · base de banco (spec 29) | servidor | legado 20:13-14; legado 29:110-112; R4 B 20 |
| SAA-08 | Área master (telas) e fila de pedidos de ativação; master é do Beauty System, fora dos estúdios (`platform_admins`), escrita só com `service_role` | planejado; só mockup V25 (AdminEstudios, AdminEstudio, AdminPlanos) | sem tela | legado 29:24-26,99; R4 B 29; R1 B canvas.json (t-plano) |
| SAA-09 | "Entrar como o estúdio" (suporte): motivo, prazo de 1 h, expira, auditoria visível; nunca com `service_role` no navegador | planejado | sem tela | legado 29:100; legado 20:11-12,29 |
| SAA-10 | Cobrança SaaS (`saas_plans`, `subscriptions`, `billing_events`, `usage_counters`), separada do financeiro do estúdio; webhooks de cobrança idempotentes | planejado P3/P4 | sem tela | legado 20:10,16-23,28 |
| SAA-11 | Criar estúdio (organização): escolher endereço (slug), configurações, marca, idioma, administrador inicial, limites, domínio próprio opcional | planejado (SAAS-TENANT-01); o slug existe, falta o fluxo | sem tela | R5 B future-modules-map:108-118; R5 B implementation-gap-map:51; R2 B ICEBOX item 26 (`ICEBOX.md:33`) |
| SAA-12 | Módulos por perfil e plano: ligar e desligar, acesso por papel, menu gerado, valida no servidor (não só na tela), upgrade e downgrade | planejado (SAAS-MODULES-01) · base pronta (antigo) | servidor | R5 B future-modules-map:122-131; R5 B roadmap:251-260 |
| SAA-13 | Alinhar as chaves de módulo (reserva, estoque, relatórios, unidades) com o que de fato existe | planejado P1 | `src/domain/access.ts:26-30` | R5 B revisao-30-10:32 |
| SAA-14 | Cadastro público de estúdio novo, planos de cobrança, domínios white-label, marketplace, integrações, API do WhatsApp, marketing automático, booking além do núcleo | "não ativo agora" | — | R5 B future-modules-map:154-162 |
| SAA-15 | Vários estúdios por login: seletor de organização e relatório consolidado ("Várias unidades", extra 29 € cada) | planejado; a tabela `locations` existe sem tela | — | R5 B roadmap:230-243; R5 B revisao-30-10:35; legado 29:67 |
| SAA-16 | Lista do que falta para vender: planos e cobrança, cadastro de estúdio novo, termos de uso, política de privacidade, nome do produto | planejado ("a examinar, sem valor de decisão") | sem tela | R2 B ICEBOX item 22 (`ICEBOX.md:29`) |
| SAA-17 | Modelo de receita do pacote (assinatura com site incluído, extra "Reserva online", taxa por cliente nova do marketplace) | em aberto | — | R5 B ecossistema:67-69 |
| SAA-18 | Créditos de mensagem (módulo "Créditos") ligado por plano | planejado (ver MSG-12) | — | legado 44:22 |
| SAA-19 | Relatórios avançados e DRE só no Completo | planejado/pronto como dado de plano | Ajustes › Plano | legado 29:66; R4 B 29 |
| SAA-20 | Estrutura antiga do SaaS: `organizations.plan` (texto, padrão 'trial') existe e não é lido pelo código; `organizations.plan` vira chave para `saas_plans` | parcial (antigo, junho) | banco | R5 B roadmap:230-243,251-260 |
| SAA-21 | Pilha técnica para o SaaS (cofre de segredos, filas, observabilidade etc.) | decisão técnica antiga, não é recurso de tela | — | `docs/produto/legado/produto/saas-stack-decision.md` |

"Estado" é o que os documentos dizem; o código é conferido quando o módulo entra em trabalho.

## Decisões
| ID | Decisão | Situação | Origem |
|---|---|---|---|
| SAA-D01 | A matriz módulo × plano é só proposta técnica; preço, nomes e composição dos planos são decisão comercial do dono | **sugestão a confirmar** (sem resposta dele) | R5 A roadmap:262-277; R5 F |
| SAA-D02 | Planos fixos mais extras configuráveis pelo master por estúdio | **sugestão a confirmar** (spec do antigo, sem frase) | legado 29:26 |
| SAA-D03 | Estúdio novo: 30 dias de teste no Profissional; estúdios do piloto no Completo; suspenso ou cancelado só com o núcleo | **sugestão a confirmar** | legado 29:48-52 |
| SAA-D04 | Master é do Beauty System, fora dos estúdios; escrita só com `service_role`; superadmin nunca usa `service_role` no navegador | **sugestão a confirmar** | legado 29:24-25; legado 20:11 |
| SAA-D05 | "Equipe" não depende do módulo "Equipe e comissões": o estúdio solo também edita o próprio cadastro e horários | **sugestão a confirmar** | legado 29:110-112 |
| SAA-D06 | Cobrança SaaS separada do financeiro do estúdio | **sugestão a confirmar** | legado 20:10 |
| SAA-D07 | Primeiro o sistema operacional da clínica; SaaS comercial, cobrança e marketplace depois | **sugestão a confirmar** | R5 B scope-master:21; R5 A scope-master |
| SAA-D08 | "Fidelidade e Relatórios avançados saíram do menu da Karenn" (menu mostra só módulos ativos) | **sugestão a confirmar** (mockup V25) | R1 B Main.dc.html |
| SAA-D09 | O que falta para vender é lista para o dono decidir; a própria fila diz "sem valor de decisão" | **sugestão a confirmar** (não há resposta dele) | R2 B ICEBOX item 22 (`ICEBOX.md:29`) |
| SAA-D10 | O gerador de sites é projeto separado, não fundido no SaaS | **sugestão a confirmar** ("Recomendação") | R5 A ecossistema:39-50 |

## Regras de negócio
- Um estúdio nunca vê nem altera dados de outro. Origem: legado 20:27; legado 29:146.
- O plano e os módulos são lidos por membros do estúdio e pelo master; só o master escreve. Origem: legado 29:53.
- Módulo extra só liga pelo master; dependências (ex.: Avaliações e Campanhas usam Mensagens) e suspensão são respeitadas. Origem: legado 29:48,148; `src/domain/access.ts:36-37`.
- Quem barra de verdade é o banco e as páginas; o menu é só conveniência. Origem: legado 29:106-107.
- Mudança de acesso, plano e módulo fica auditada. Origem: legado 29:149.
- Acesso de suporte é temporário, com motivo, expiração e registro. Origem: legado 20:12,29.
- Webhook de cobrança é idempotente. Origem: legado 20:28.
- Suspender preserva os dados e segue a política do contrato. Origem: legado 20:14.
- Enquanto o plano não estiver configurado, todos os módulos ficam liberados (piloto). Origem: legado 29:116-118; `PlanSection.tsx`.

## Pendências e perguntas
| Pergunta ou pendência | Origem |
|---|---|
| Preços de exemplo (29, 59, 99 €) e o que entra em cada plano: quem decide e quando? | R5 A roadmap:262-277; legado 29:69 |
| Nome do produto, termos de uso e política de privacidade: não existem | R2 B ICEBOX item 22; R4 D 47 |
| "Plano": os botões estão desligados. Deixar visível e desligado (G9) ou esconder? | R3 B audit:30; R1 A G9 |
| Quando virá a área master e o criar-estúdio? Hoje o suporte faz à mão | R2 B ICEBOX item 26; legado 29:153 |
| Convite com aceite para quem já usa o sistema em outro estúdio, remover pessoa da equipe, criar estúdio novo sem a chave de serviço (nível C, precisa de spec) | R2 B ICEBOX item 26 (`ICEBOX.md:33`) |
| Mockup V25 "Main" com plano e módulos é só desenho; há divergência com a aba Plano do código | R1 B Main.dc.html; R1 B canvas.json |
| Matriz do roadmap antigo (fidelidade no núcleo; reserva e WhatsApp automático no Intermediário) × spec 29 (fidelidade extra 12 €) | R5 B roadmap:262-277; legado 29:55-67 |
| Entrevistas com donas de estúdio antes de qualquer spec de pacote vendável | R5 B ecossistema:67-69 |
| Pagamento: Stripe e Asaas só "depois" | `docs/reference/stack.md:38` |
| Planos pagos do Workers e do Supabase na virada (custo da plataforma, não do cliente) | `docs/runbooks/go-live.md:28` |

## Referências
- Specs do legado: `docs/produto/legado/specs/20-saas-admin-billing.md`, `29-access-roles-modules.md` (inteira, seções 2, 4b e aceite), `28-navegacao-marketing-ajustes.md`; `docs/produto/legado/produto/future-modules-map.md`, `saas-stack-decision.md`, `ecossistema.md`, `implementation-gap-map.md`, `roadmap.md`.
- Mockup V25: `docs/design/v25-mockups/Main.dc.html` (planos), `AjustesPlano`, `AdminEstudios`, `AdminPlanos`; `docs/design/v25-implementacao.md:99`.
- Módulos vizinhos: MSG (créditos), RES (módulo `reserva`), FID e MKT (módulos do plano), Equipe/Acessos (papéis).

Regra: só vale decisão registrada em `docs/decisoes/` (molde de pergunta). Tudo desta tabela é **a confirmar**; a situação antiga fica entre parênteses só como histórico e volta a ser perguntada quando o módulo for trabalhado (resposta 15a do dono, 24/11/2026).
