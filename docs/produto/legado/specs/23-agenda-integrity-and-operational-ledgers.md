# Spec 23 - Integridade da agenda e ledgers operacionais

## Status

Aprovada pelo responsavel do produto em 2026-06-12. Escopo exclusivamente de
backend, dominio, banco e testes; sem criacao de telas, menus ou layout.

As tabelas de ledger e todas as RPCs operacionais da agenda estao aplicadas no
Supabase remoto. Em 2026-06-14, create/update/status/reagendamento/bloqueios e
cancelamento de serie passaram a usar somente o caminho transacional.

## Goal

Impedir estados operacionais impossiveis na agenda e criar a base auditavel
para saldo de cliente, fidelidade e vale-presente.

## Referencias

- Legado KA Beauty: agenda, fidelidade e gift cards como memoria de requisitos.
- Specs 04, 05, 09, 15, 21 e 22.

Referencias oficiais do Fresha consultadas em 2026-06-12:

- Bloqueios, recorrencia e override manual:
  https://www.fresha.com/help-center/knowledge-base/calendar/102079-create-and-manage-blocked-time-in-your-calendar
- Carteira do cliente:
  https://www.fresha.com/help-center/knowledge-base/clients/206-manage-client-wallets-1
- Atividade de vales por emissao, resgate, expiracao e reembolso:
  https://www.fresha.com/help-center/knowledge-base/reports/363-gift-card-by-time-period-1
- Fidelidade por pontos e tiers:
  https://www.fresha.com/help-center/knowledge-base/clients/563-client-loyalty-overview

## Regras da agenda

- Apenas `owner`, `admin`, `manager`, `receptionist` e `professional` alteram a
  agenda.
- Status recebidos do navegador devem pertencer ao conjunto canonico.
- Saltos de status invalidos sao rejeitados no dominio.
- `Cancelado`, `Ausencia` e `Pago` sao terminais nas actions operacionais.
- Alteracao de status e gravacao de historico devem ocorrer na mesma transacao.
- Criar, editar ou reagendar nao pode sobrepor outro atendimento ativo do mesmo
  profissional.
- Bloqueios nao podem sobrepor atendimentos ou outros bloqueios.
- Horarios adjacentes nao sao conflito.
- Um futuro override gerencial exigira motivo e audit log; ate existir esse
  contrato, a sobreposicao e bloqueada.

Esta regra substitui o warning nao bloqueante da fase inicial da Spec 04. A
agenda atual ja possui bloqueios persistidos e precisa trata-los como
indisponibilidade, conforme a evolucao aprovada na Spec 05.

O Fresha permite que a equipe agende manualmente sobre um bloqueio. O KA Beauty
OS fica temporariamente mais restritivo porque ainda nao possui o controle de
override auditado. A criacao desse controle e responsabilidade do fluxo visual;
o backend deve exigir papel gerencial e motivo quando ele for implementado.

## Ledgers

As tabelas abaixo sao append-only:

- `client_balance_entries`: origem, variacao e saldo posterior.
- `loyalty_point_entries`: origem, pontos e saldo posterior.
- `gift_card_redemptions`: cada uso de vale, venda e saldo posterior.
- `audit_logs`: operacoes sensiveis com usuario, registro e snapshots.

Todas possuem `org_id`, RLS e indices por entidade/data. A aplicacao nao deve
passar a depender delas antes da migration estar aplicada no ambiente remoto.

## Entrega deste incremento

- Validacao de papel nas mutations da agenda.
- Validacao canonica e transicoes de status no dominio.
- Deteccao de conflito em criar, editar, reagendar e bloquear horario.
- Erro de reagendamento devolvido ao fluxo existente.
- RPC `set_appointment_status_atomic` chamada pelo repositorio, com fallback
  restrito ao erro conhecido da versao remota.
- Migration corretiva dos helpers RLS e auditoria de mudanca de status.
- Migration idempotente dos quatro ledgers.
- RPCs atomicas para criar/editar atendimento e itens, reagendar, bloquear e
  cancelar serie.
- Interpretacao de data/hora na timezone da organizacao.
- `client_id` obrigatorio em todo atendimento, com correcao dos historicos.
- Triggers rejeitam status inicial terminal e referencias cross-tenant em itens.
- Indices das relacoes centrais e retirada da RPC administrativa
  `rls_auto_enable()` da API publica.

## Fora de escopo

- UI de override de conflito.
- Edicao visual de recorrencia.
- Tela de extrato, auditoria ou atividade.
- Checkout transacional completo.
- Telas de extrato dos ledgers.

## Acceptance criteria

- [x] Typecheck, lint, Vitest e build passam.
- [x] Transicoes invalidas sao rejeitadas por teste unitario.
- [x] Horarios adjacentes continuam permitidos.
- [x] Agenda rejeita sobreposicao com atendimento e bloqueio.
- [x] Reagendamento nao exibe sucesso quando o backend rejeita a operacao.
- [x] Migration e idempotente e nao apaga dados.
- [x] Tabelas de ledger aplicadas no Supabase remoto.
- [x] Migration corretiva aplicada e RPCs atomicas validadas no Supabase remoto.
- [x] Rollback validado quando um item de servico invalido interrompe a criacao.
- [x] Bypass direto com status terminal ou servico de outra org e rejeitado.
- [x] E2E autenticado cria atendimento, abre a comanda e cancela em 1440px e 390px.

## Regras do banco (29 out 2026)

- Edição de série recorrente atinge só ocorrências em aberto e leva a duração ao item único.
- Item de atendimento Pago, Pago Parcial, Cancelado ou Ausência não muda (gatilho no banco).
- Backlog: `cancel_recurrence_series_atomic` ainda cancela ocorrências passadas e iniciadas.
