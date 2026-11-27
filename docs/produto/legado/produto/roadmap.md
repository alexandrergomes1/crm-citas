# KA Beauty OS - Roadmap de execucao

> Revisao: 2026-06-15
> A fila ativa e o status de maturidade estao em
> `docs/core-delivery-control.md`. Este arquivo mantem a direcao por fases.
> Nenhum item deste arquivo, isoladamente, comprova entrega.

## Modelo de colaboracao

| Responsavel | Escopo |
|---|---|
| Alexandre | prioridade, aceite visual, decisoes comerciais e decisoes sensiveis de legal/fiscal/pagamento |
| ChatGPT | orquestracao, organizacao de escopo, documentacao, prompts curtos, revisao de commits e sequenciamento |
| Codex | engenharia tecnica, dominio, banco, migrations, actions, navegacao/estado tecnico, performance, seguranca, testes e integracoes |
| Claude | UX/UI, design system, layout premium, responsividade, menus, cards, modais, drawers, screenshots e aceite visual |

Nenhum botao visual e considerado entregue sem regra, persistencia, erro tratavel
e teste do fluxo correspondente.

ChatGPT nao executa como feature owner visual ou backend. Ele mantem coerencia e
quebra trabalho. Codex e Claude executam fases pequenas e publicam commit/push.

## Prioridade imutavel do produto

O ciclo atual existe para estruturar e concluir os cinco modulos que sustentam
toda a operacao:

1. Cliente;
2. Anamnese;
3. Catalogo;
4. Financeiro e comanda por atendimento;
5. Agenda como orquestradora dos quatro modulos anteriores.

Eles devem evoluir como um unico fluxo operacional:

`cliente -> servico -> agendamento -> anamnese -> atendimento -> comanda -> financeiro -> historico`

Booking publico, marketing, notificacoes, reviews, integracoes de calendario,
compras avancadas e administracao SaaS nao entram em desenvolvimento de produto
antes do gate de conclusao dos cinco modulos core. So sao permitidos trabalhos
nesses modulos secundarios quando forem necessarios para corrigir seguranca,
build ou dependencia direta do core.

## Estado atual

### Superficies operacionais existentes

- autenticacao, organizacoes, roles e RLS;
- equipe, turnos e comissoes;
- clientes, alertas, tags, saldo, documento internacional, DDI e telefone obrigatorio;
- catalogo basico de servicos, produtos, pacotes e planos;
- agenda com views, zoom, filtros, bloqueios, conflitos e contexto clinico;
- anamnese, assinatura, ficha profissional e vinculo canonico a atendimento;
- checkout, split, pagamento parcial continuavel, credito opcional e vale;
- financeiro, relatorios CSV, fidelidade e entitlements.

### Gate atual

Os bloqueadores e o estado comprovado mudam com frequencia e ficam somente em
`core-delivery-control.md`. Em 2026-06-15, o gate continua fechado por:

- P0 transversal de migrations reproduziveis (`REL-DB-01`);
- RLS amplo em areas financeiras, catalogo e cliente;
- mutations compostas ainda pendentes em Cliente/Catalogo/Financeiro;
- E2E financeiro completo ainda ausente;
- UX premium da Comanda ainda nao publicada;
- validacao, retencao e auditoria server-side da anamnese ainda incompletas;
- aceite mobile/desktop completo dos cinco modulos ainda pendente.

## Fase 0 - Integridade transversal P0

Responsavel tecnico: Codex.

1. Checkout atomico e idempotente, incluindo continuacao de pagamento parcial.
2. Transacao de agendamento + itens e pacote + itens.
3. Sinal manual transacional, auditavel e vinculado ao checkout. Concluido.
4. Recorrencia: criacao/edicao transacional e validacao de conflitos. Concluido;
   cancelamento com historico permanece na fila da agenda.
5. Actions da agenda nunca exibem sucesso quando o backend devolve erro.
6. E2E autenticado: cliente, servico, agendamento, anamnese, checkout total e parcial.
7. Performance quente abaixo de 3 segundos nas rotas operacionais.
8. Baseline de producao: p95 de leitura < 1,5 s e mutation < 2 s, sem usar cache
   persistente para ocultar query lenta.
9. Migrations reproduziveis para banco novo convergir ao contrato usado pelo codigo.

Gate de saida:

- typecheck, lint, Vitest e build limpos;
- rollback testado;
- nenhuma duplicacao por reenvio;
- fluxo critico coberto por Playwright;
- ambiente novo consegue reproduzir schema esperado.

## Fase 1 - Fechamento dos cinco modulos core

As cinco frentes abaixo pertencem a mesma fase. A ordem orienta dependencias,
mas nenhuma e considerada concluida isoladamente se a integracao ponta a ponta
estiver quebrada.

Claude executa UX/UI e Codex executa backend, integridade, performance e testes.
ChatGPT decompõe e revisa as fases antes de cada envio. O detalhamento de
propriedade esta em `docs/collaboration-operating-model.md`.

### 1. Cliente P1

Specs relacionadas: Cliente, operacionalidade e integridade.

1. Cliente obrigatorio em todo novo atendimento. Parcialmente concluido.
2. Nome e telefone obrigatorios. Concluido em `bf7fa53`.
3. Documento internacional com tipo e numero. Concluido em `bf7fa53`.
4. Telefone com DDI e padrao Espanha `+34`. Concluido em `bf7fa53`.
5. Alertas multiplos, alergias e notas fixas com historico.
6. Saldo e ledger de origem na ficha do cliente.
7. Historico consolidado de atendimentos, vendas, beneficios e formularios.
8. Validacao profissional de dados vindos da Ficha Cliente antes de atualizar cadastro.
9. Retencao, anonimização e bloqueio de booking auditavel.

### 2. Anamnese P1

Contrato operacional detalhado: `docs/agenda-operational-scope.md`.

1. Builder com secoes, cabecalhos, informacao e tipos de resposta completos.
2. Vinculo consistente entre template, servico, cliente e atendimento.
3. Ficha Cliente e Ficha Profissional como partes da mesma anamnese.
4. Ficha profissional inequivocamente vinculada ao atendimento.
5. Pendencias do cliente e do profissional.
6. E2E permanente Agenda -> Ficha -> Comanda -> retorno. Concluido em `8f3ed77`.
7. Consentimento, evidencias server-side, auditoria e retencao RGPD/GDPR.
8. Recibo completo da Ficha Cliente.
9. Consentimento separado de uso de imagem.
10. Idioma consistente em perguntas, respostas, labels e recibo.
11. Edicao/retificacao segura de ficha preenchida.

### 3. Catalogo P1

Specs: `07` e `08`.

1. Separar bundle, pacote de sessoes e membership.
2. Modelo transacional de bundle com ordem e preco por item.
3. Tipo de preco: gratuito, a partir de, fixo e sob avaliacao.
4. Arquivar/restaurar, duplicar e exclusao protegida.
5. Locais, profissionais, recursos e formularios como regras do servico.
6. Busca, filtros, ordenacao e contratos para agenda/comanda.
7. Claude redesenha catalogo e editores apos os contratos serem fechados.

### 4. Financeiro e comanda P1

Specs: `09`, `10`, `11`, `15`, `18`, `21` e `22`.

1. Comanda sempre vinculada ao atendimento.
2. Checkout atomico e idempotente.
3. Draft, pagamento parcial e quitacao posterior.
4. Credito opcional, debito e ledger de origem.
5. Sinal vinculado a comanda, vales e beneficios transacionais.
6. Estoque, entitlements, pontos, comissao e caixa sem efeitos duplicados.
7. Comandas abertas e parciais consultaveis pelo Financeiro.
8. Retorno contextual Agenda/Anamnese/Comanda sem redirecionamento destrutivo. Concluido em `9229bcea`.
9. Comanda premium estilo Fresha, com contexto/cliente separado de itens/pagamento. Em andamento com Claude, ainda nao publicada.

### 5. Agenda operacional P1

Specs: `04`, `05`, `23` e `24`.

### Backend e contratos

1. Timeline de atividade usando `audit_logs`.
2. Criacao de recorrencia de atendimento.
3. Gerar/vincular anamnese pela acao rapida.
4. Status visivel de Ficha Cliente e Ficha Profissional no painel. Concluido em `9229bcea`.
5. Nova reserva herdando cliente.
6. Bloqueio de booking do cliente com motivo e override auditado.
7. Teste de contato como registro clinico especifico.

### Handoff visual para Claude

1. Reorganizar detalhe do agendamento.
2. Menu de acoes rapidas sem botoes inertes.
3. Acoes contextuais do cliente.
4. Estados de loading, erro e permissao.
5. Screenshots e aceite em 1440px e 390px.

Agendamento em grupo fica em P2, apos recorrencia e atividade.

### Gate de conclusao do core

Os cinco modulos so passam para concluidos quando:

- criar e editar cliente, servico e atendimento funciona com banco real;
- atendimento recupera notas, alertas, saldo, beneficios e anamnese;
- comanda nasce do atendimento e aceita draft, parcial e quitacao posterior;
- checkout atualiza financeiro, saldo, estoque, beneficios e historico atomicamente;
- erros nao produzem falso sucesso;
- fluxos criticos possuem E2E autenticado;
- p95 atende as metas da Fase 0;
- Claude entrega e valida os estados visuais em 1440px e 390px.

## Fase 2 - Modulos secundarios bloqueados ate o gate

1. Booking publico com disponibilidade real.
2. Deposito online por provedor compativel com UE e webhook idempotente.
3. Politicas de cancelamento, remarcacao e no-show.
4. Confirmacao, lembrete, pos-atendimento e review.
5. Fila, opt-out, rate limiting e logs de envio.
6. Google Calendar inicialmente unidirecional; duas vias so apos validacao operacional.
7. Lista de espera e periodos fechados apos o nucleo da agenda estar estavel.

Qualquer escolha de conta, IBAN ou provedor deve cumprir as obrigacoes fiscais,
contabeis e de reporte aplicaveis. Ocultacao de receita nao e requisito do produto.

## Fase 3 - Expansao

- agendamentos em grupo;
- recursos e capacidade simultanea avancada;
- fornecedores, pedidos de compra e reposicao;
- recompensas de fidelidade;
- cupons, ofertas e vale-presente avancado;
- reputacao, Google Reviews e Meta (mapeamento detalhado abaixo);
- SaaS admin, billing e limites por plano (mapeamento detalhado abaixo).

## Modularidade por plano e integracoes - mapeamento

> Mapa de planejamento e sequenciamento tecnico, nao autorizacao de
> construcao. A "Prioridade imutavel do produto" continua valendo: nenhum
> item abaixo entra em desenvolvimento antes do gate dos cinco modulos core
> fechar. Excecao: desenho de schema e aditivo, de baixo risco, e nao compete
> com o core - pode ser fechado antes sem violar o gate.

### Estado real hoje, nao especulacao

- `organizations.plan` existe desde a fundacao
  (`supabase/migrations/20260601000001_foundation.sql`, coluna `text not null
  default 'trial'`) e **nao e lido por nenhum codigo do app hoje** - nenhuma
  tela, action ou middleware verifica esse valor. E a base a reaproveitar,
  nao recriar do zero.
- `profiles` e `user_roles` ja sao `unique(user_id, org_id)` - um unico login
  (`auth.users`) ja pode ter perfil/role em varias `organizations` isoladas
  por RLS. **Multi-loja para o mesmo dono ja e suportado estruturalmente.**
  Falta seletor de organizacao na UI e, se for regra de negocio, relatorio
  consolidado entre organizations do mesmo dono. Isso reforca a recomendacao
  ja dada sobre a pergunta de contas Vercel/Supabase por cliente: nao separar
  - o `org_id` + RLS ja isola dados por tenant; fragmentar contas cria N
  deploys, N bancos e N faturas para manter em vez de um sistema que escala
  por linha.
- As specs de modularidade e integracao ja existem e ja tem tabelas
  desenhadas: `20-saas-admin-billing.md` (`saas_plans`, `subscriptions`,
  `billing_events`, `usage_counters`, `support_access_grants`) e
  `19-integrations-google-meta-analytics.md` (`integration_configs`,
  `oauth_connections`, `webhook_events`, `calendar_sync_entries`,
  `review_requests`). Falta sequenciar e implementar, nao desenhar do zero.

### Mecanismo de gating, para quando for construido

1. Registro central `MODULES` (chave, nome, modulo pai, dependencias).
2. `hasModuleAccess(orgId, moduleKey)` avaliado sempre no servidor - layout
   de cada rota de modulo bloqueia acesso, e Server Actions sensiveis
   revalidam de novo. Defesa em profundidade, mesma disciplina ja usada em
   RLS: esconder botao no client nunca e controle de acesso.
3. `organizations.plan` deixa de ser texto livre e vira FK para `saas_plans`.
4. Limite por uso (`usage_counters`) usa o mesmo padrao de audit log ja usado
   no restante do sistema.

### Matriz modulo x plano - proposta tecnica inicial, decisao comercial e sua

| Modulo | Nucleo | Intermediario | Avancado |
|---|---|---|---|
| Agenda, Cliente, Anamnese, Catalogo, Financeiro/Comanda | incluido | incluido | incluido |
| Notificacoes WhatsApp automaticas (lembrete/confirmacao) | fora | incluido | incluido |
| Online booking publico | fora | incluido | incluido |
| Google Calendar / Reviews / Meta | fora | parcial | incluido |
| Marketing (campanhas/segmentacao) | fora | fora | incluido |
| Fidelidade avancada (recompensas customizadas) | basico | incluido | incluido |
| Multi-loja com relatorio consolidado | fora | fora | incluido |

Este agrupamento e ponto de partida tecnico para discussao. Preco, nome dos
planos e o que entra em cada um sao decisao comercial do responsavel do
produto - o mecanismo de bloqueio sustenta qualquer composicao que for
decidida, sem precisar reescrever codigo por causa de reprecificacao.

### Integracoes - prontidao real hoje

| Integracao | Spec | Estado real | Falta para comecar |
|---|---|---|---|
| Stripe / deposito online | `10-payments-policy-deposits.md` | Nao iniciado. Sinal manual presencial ja e transacional e auditavel; gatilho online nao existe. Sem dependencia `stripe` no `package.json`. | SDK, Route Handler de webhook idempotente, reconciliacao |
| WhatsApp Business API | `13-notifications-whatsapp-email.md` | Hoje so existe link `wa.me` manual (`src/lib/client-messaging.ts`) - abre o WhatsApp do atendente, nao envia nada automatico. Atalho de navegador, nao integracao. | Provedor (Meta Cloud API ou BSP), fila, templates aprovados, opt-out |
| Google Calendar / Reviews / Meta | `19-integrations-google-meta-analytics.md` | Nao iniciado. | OAuth server-side, token criptografado, sync unidirecional primeiro |

### Nota de processo

Modularidade, integracoes e custo de servidor sao, pelo
`collaboration-operating-model.md`, trilha padrao do Codex (dominio,
integracoes, performance), nao da Claude. Este mapeamento foi respondido
diretamente porque foi perguntado diretamente, e porque o proprio modelo de
colaboracao diz que nenhuma tarefa fica parada so por estar fora da trilha de
quem esta disponivel no momento. Recomenda-se que este mapeamento passe por
auditoria do Codex antes de virar spec formal - verificacao cruzada prevista
no proprio modelo, nao desconfianca do conteudo.

## Regras de passagem

1. Feature nasce de spec em `docs/specs/` ou escopo operacional validado.
2. Backend composto exige transacao e idempotencia.
3. Fluxo critico exige Playwright.
4. Tela usa design system e fica abaixo de 300 linhas por componente.
5. Entrega visual exige screenshots 1440px e 390px.
6. Nenhuma etapa e marcada pronta apenas porque a interface existe.
