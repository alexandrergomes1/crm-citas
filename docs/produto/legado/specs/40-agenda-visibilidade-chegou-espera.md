# Spec 40 — Agenda: visibilidade, cancelar com sinal, Chegou, número, lista de espera e pacote

Estado: implementado em 30 out 2026 (migrations `20261030200000` a `20261030240000`, testes SQL 127 a 131).

## 1. Ver tudo x só a minha agenda

- `agenda.view_all`: todas as profissionais. `agenda.view_own`: só os agendamentos das profissionais ligadas à conta
  (`staff_members.user_id`). Sem nenhuma das duas, a Agenda não abre.
- Servidor: `resolveAgendaAccess` (`agenda/_data/scope.ts`) decide o alcance; consultas e Server Actions filtram por
  `staff_id`. Banco: políticas SELECT de `appointments`, `time_blocks`, `appointment_items`, `appointment_deposits` e
  `appointment_status_history` usam `agenda_full_view_orgs()`, `agenda_own_view_orgs()` e `agenda_my_staff_ids()`.
- Tela: sem a linha "Todas as profissionais", só a própria coluna; sem profissional ligada, aviso e agenda vazia.
- Ligação conta x profissional: Equipe > "Conta de acesso" (e preenchimento por e-mail na migration).

## 2. Cancelar com sinal atômico

`cancel_appointment_settle_deposit_atomic(org, agendamento, motivo, modo, série)`: cancela (um ou a série futura),
grava `appointments.cancel_reason` e acerta o sinal na mesma transação (`credit` = crédito no saldo, `refund` =
anula, `fee` = fica com o estúdio). Idempotente: repetir não duplica crédito. `credit` exige `financeiro.manage` e
`comanda.operate`; `refund`, `comanda.operate`. Notas antigas "Cancelado:" continuam lidas (`cancelReasonOf`).

## 3. Status "Chegou"

Entre Confirmado e Iniciado. CHECK, transições, RPCs e gatilhos aceitam o status; a trava da Ficha Cliente vale para
chegar e iniciar. Cor, rótulo, contagem e filtro "Chegaram" no quadro; ação "Marcar chegada" no detalhe e no cartão.

## 4. Número e autor

`appointments.number` sequencial por estúdio (`appointment_counters`, sem corrida, com preenchimento dos antigos) e
`created_by`; `appointment_status_history.changed_by`. Imutáveis (`protect_appointment_number`). Tela: "#N",
"Criado por <nome> em <data>" e autor em cada mudança da atividade.

## 5. Lista de espera e pacote

- `agenda_waitlist` (org_id, cliente, serviço, profissional, janelas, status `waiting|offered|scheduled|removed`),
  RLS por `agenda.manage`. Ações: adicionar, oferecer horário (registra `offered_at`/`offered_for`; o WhatsApp abre
  para quem atende enviar), agendar (liga a entrada ao agendamento criado) e tirar da lista.
- "Incluído no pacote": derivada na leitura (`assignPackageCoverage`), por cliente, entre os serviços de
  agendamentos abertos (não pagos) e as sessões livres de `client_entitlements` ativos e não vencidos, do horário
  mais próximo ao mais distante. Não grava nada e não consome sessão: o consumo continua só em
  `confirm_checkout_atomic`, que também tira o agendamento da lista de abertos (por isso não há consumo duplicado).
  Só no alcance `agenda.view_all`.

## 6. Lembretes de amanhã

O menu Opções mostra quantas clientes de amanhã (Reservado ou Agendado) ainda não confirmaram e abre o dia de amanhã.
Não há envio automático: o envio é pelo WhatsApp de cada cartão, até existir o motor de automações.

## Critérios de aceite

- pgTAP 127 a 131 (caminho feliz, permissão negada, idempotência, isolamento entre estúdios).
- Vitest: `agenda-scope`, `agenda-cancel-reason`, `agenda-waitlist`, `agenda-package-coverage`.
- E2E `e2e/agenda-advanced.spec.ts` na prévia `/dev/v25/agenda` (`?extras=1` mostra Chegou e pacote).
