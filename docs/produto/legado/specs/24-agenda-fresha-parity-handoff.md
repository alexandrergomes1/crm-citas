# Spec 24 - Agenda: paridade operacional

## Status

Aprovada. Execução controlada por `docs/core-delivery-control.md`.

- Claude: desenho das telas, menus, hierarquia visual e validação mobile/desktop.
- Codex: contratos, regras de negócio, migrations, actions, performance, testes e auditoria.
- Esta spec não autoriza copiar identidade visual ou código do Fresha. A referência é
  de capacidade operacional e fluxo.

## Fontes

- Imagens locais em `docs/fresha-prints-referencia/`, inventariadas em `docs/fresha-prints-referencia/README.md`.
- Anexos enviados pelo responsável do produto em 2026-06-12.
- Legado: `D:/ALEXANDRE/Alexandre/projetos/.DEV/ka-beauty/docs/specs/agenda-master-plan.md`.
- Fresha, criar agendamentos:
  https://www.fresha.com/help-center/knowledge-base/calendar/25-create-appointments-1
- Fresha, agendamentos recorrentes:
  https://www.fresha.com/help-center/knowledge-base/calendar/26-create-repeat-appointments-1
- Fresha, agendamentos em grupo:
  https://www.fresha.com/help-center/knowledge-base/calendar/102046-create-and-manage-group-appointments
- Fresha, bloqueio de clientes:
  https://www.fresha.com/help-center/knowledge-base/clients/101931-block-clients-from-booking
- Fresha, cadastro e configurações do cliente:
  https://www.fresha.com/help-center/knowledge-base/clients/207-update-client-details

## Diagnóstico do sistema atual

Legenda: pronto, parcial, ausente.

| Capacidade | Estado atual | Evidência / lacuna |
|---|---|---|
| Dia, 3 dias, semana e mês | pronto | `AgendaToolbar` e `AgendaView` |
| Zoom e filtro multi-profissional | pronto | toolbar atual |
| Filtro por status | pronto | toolbar atual |
| Filtros avançados e salvos | ausente | canal, pagamento, serviço, criação e segmento ainda não possuem contrato completo |
| Bloqueio único e semanal | pronto | `TimeBlockModal` e actions |
| Reagendar | pronto | `RescheduleSection` |
| Ausência e cancelamento | pronto | actions de status |
| Checkout a partir do agendamento | pronto | `AppointmentSheet` |
| Pagamento parcial posterior | pronto | checkout aceita continuação de venda parcial |
| Sinal manual | pronto | RPC transacional, idempotente e auditável |
| Nota do agendamento | pronto | ação rápida e edição persistida |
| Adicionar formulário | pronto | ação cria ficha vinculada ao atendimento |
| Recorrência de atendimento | parcial | criação/edição/cancelamento transacionais; faltam intervalo, data final e escopo "esta e futuras" |
| Atividade do agendamento | parcial | timeline existe; cobertura de audit logs ainda incompleta |
| Nova reserva contextual | pronto | herda cliente e contexto disponível |
| Agendamento em grupo | ausente | não há contrato nem entidade de grupo |
| Ações do cliente na agenda | parcial | perfil, alertas e tags existem fora da sheet |
| Mensagens | ausente | domínio inicial de marketing não equivale a conversa operacional |
| Bloquear cliente | pronto | bloqueio com motivo, autor, audit log e override gerencial |
| Teste de contato | ausente | não há entidade clínica específica |

## Superfície visual

As imagens em `docs/fresha-prints-referencia/` são o contrato de referência visual desta spec.
Claude deve confrontar cada entrega com o manifesto, sem copiar a identidade do
Fresha. Divergência deliberada precisa ser registrada aqui, não em outro
cronograma.

### 1. Detalhe do agendamento

O detalhe deve separar três níveis:

1. Cabeçalho operacional: cliente, status, data, hora, profissional e serviços.
2. Ações primárias: pagamento/checkout e próxima transição de status.
3. Menu de ações rápidas para comandos secundários.

O menu de ações rápidas deve prever:

| Ação | Decisão de produto | Prioridade |
|---|---|---|
| Adicionar nota | implementar; nota do atendimento, não nota fixa do cliente | P1 |
| Adicionar formulário | implementar; gerar ou vincular anamnese ao atendimento | P1 |
| Ver atividade | implementar após escrita confiável em `audit_logs` | P1 |
| Definir como recorrente | implementar criação de série com escopo explícito | P1 |
| Adicionar ao grupo | manter no desenho como evolução, não ativar sem backend | P2 |
| Nova reserva | implementar herdando cliente e, opcionalmente, serviços | P1 |
| Remarcar | manter; já funcional | P0 |
| Ausência | manter; exigir retorno de erro antes de mostrar sucesso | P0 |
| Cancelar | manter como status e histórico, nunca exclusão física | P0 |

Não exibir comandos sem backend funcional. Itens futuros podem aparecer apenas em
protótipo isolado, nunca no produto como botão inerte.

### 2. Pagamento e checkout

- `Checkout` abre a comanda completa.
- `Pagar agora` só deve existir quando houver fluxo curto claramente definido.
- Sinal de reserva não é sinônimo de checkout.
- Crédito positivo do cliente deve continuar opcional e desligado por padrão.
- Débito é aviso não impeditivo.
- Pagamento parcial deve permitir novos pagamentos até zerar o saldo.
- `Pago`, `Pago parcial` e `Concluído` são estados diferentes.

### 3. Ações do cliente dentro do agendamento

O menu contextual do cliente deve prever:

| Ação | Regra |
|---|---|
| Ver perfil | navegar para a ficha 360° |
| Remover cliente | só desvincula do agendamento; não apaga cadastro |
| Mensagens | abrir histórico operacional quando a integração existir |
| Alerta da equipe | alerta fixo visível em agenda e checkout |
| Alergia | registro clínico destacado e auditável |
| Teste de contato | entidade com serviço/produto, resultado, data, validade e profissional |
| Tag | usar tags configuráveis, não somente enum fixo no frontend |
| Editar dados | editar cadastro sem perder o contexto do agendamento |
| Bloquear cliente | bloquear booking online com motivo; permitir override interno auditado |
| Excluir cliente | ação administrativa com retenção e anonimização GDPR |

`Remover cliente`, `bloquear` e `excluir` não podem compartilhar a mesma semântica.

## Contratos de backend necessários

### Atividade

Usar `audit_logs` como fonte da timeline:

- `entity_type = appointment`;
- `entity_id = appointment.id`;
- ações: created, updated, rescheduled, status_changed, note_added,
  form_linked, deposit_registered, checkout_opened, payment_added,
  recurrence_created, recurrence_updated e cancelled;
- snapshots mínimos, usuário e data;
- nenhuma PII clínica desnecessária no payload de auditoria.

### Recorrência

A criação de série deve:

- aceitar frequência semanal e intervalo;
- aceitar quantidade ou data final;
- gerar um `recurrence_id`;
- validar conflitos de todas as ocorrências antes de gravar;
- gravar todas as ocorrências em uma transação;
- suportar editar apenas esta, esta e futuras, ou toda a série;
- preservar atendimentos pagos e histórico.

A criação e a atualização de série usam RPCs transacionais desde 2026-06-13.
Ambas validam todas as ocorrências antes de escrever, preservam atendimentos
pagos/cancelados e exigem papel gerencial para override de conflito.

### Grupo

Criar somente após decisão de produto:

- `appointment_groups`: organização, nome, capacidade e regra de booking;
- `appointments.group_id`;
- serviços podem compartilhar horário sem compartilhar pagamento;
- cada cliente mantém status, anamnese, comanda e consentimento próprios.

### Restrições do cliente

Não reutilizar `clients.status` para todos os casos. O bloqueio de booking precisa
de motivo, autor, data, estado ativo e trilha de auditoria.

### Teste de contato

Entidade sugerida: `client_patch_tests`, com `org_id`, `client_id`, `service_id`,
produto/substância, aplicado em, leitura em, resultado, observação, profissional e
anexos futuros.

## Correções de confiabilidade antes do redesenho

- `handleCancel` e `handleAbsent` verificam `result.error`.
- sinal, checkout, criação/edição de atendimento, status, reagendamento,
  bloqueios e cancelamento de série usam RPCs transacionais.
- conflitos concorrentes são serializados por advisory lock.
- horários são persistidos conforme a timezone da organização.
- alertas, notas fixas e saldo do cliente carregam junto do atendimento.
- atividade visual ainda não consolida todos os eventos de `audit_logs`.

Claude pode redesenhar a superfície, mas esses comandos não devem ser apresentados
como concluídos antes das correções de backend.

## Performance

- O resumo do cliente necessário à sheet deve vir junto da leitura do agendamento.
- Dados secundários, como atividade completa e mensagens, podem carregar sob demanda.
- Abertura quente da sheet não deve disparar consultas sequenciais obrigatórias.
- Mutations devem retornar erro estruturado e impedir toast de sucesso falso.
- Listagens por período devem usar índices por `org_id`, `staff_id` e `start_at`.

## Testes obrigatórios

- E2E: criar atendimento, abrir comanda e cancelar — concluído em 1440px e 390px.
- E2E: abrir agendamento e executar reagendamento e ausência.
- E2E: criar recorrência e editar uma ocorrência, futuras e série.
- E2E: gerar/vincular anamnese a partir do agendamento.
- E2E: checkout total, parcial e pagamento posterior.
- Integração: rollback de recorrência e sinal.
- E2E visual pelo Claude: 1440px e 390px.

## Ordem restante

1. REL-ANA-05: unificar o gate clínico usado por Agenda e Checkout.
2. CORE-AGD-UX: paridade do manifesto Fresha, atividade e recorrência avançada.
3. CORE-E2E-01: completar status, reagendamento, recorrência e pagamento.
4. CORE-PERF-01: eliminar carregamentos client-side evitáveis e manter p95.
5. P2: grupos, mensagens e teste de contato.
