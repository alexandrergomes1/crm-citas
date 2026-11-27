# Spec 26 — AGENDA-STATUS-NOTES-CORE

Status: planned
Owner: Alexandre + ChatGPT orchestration
Last updated: 2026-06-19

## Objetivo

Consolidar duas bases core da Agenda/Clientes:

1. matriz operacional de status e ações do agendamento;
2. histórico/timeline de notas do cliente e do atendimento.

A entrega deve ser técnica/core, sem redesenhar a Agenda. A aplicação visual premium será feita depois com os padrões globais de interação.

## Por que isso existe

A Agenda é o centro operacional do sistema. A interface futura precisa saber, sem dedução visual, quais ações estão permitidas em cada estado e como as notas clínicas/operacionais aparecem no contexto do cliente e do atendimento.

## Status de agendamento — direção de produto

Separar mentalmente:

- status operacional do atendimento;
- status financeiro/pagamento.

### Status operacional recomendados

- `Reservado`: pré-reserva/slot guardado, especialmente útil para futuro canal online ou reserva ainda não confirmada.
- `Agendado`: atendimento criado e ainda não confirmado.
- `Confirmado`: cliente/profissional confirmou presença.
- `Iniciado`: atendimento em execução.
- `Concluído`: atendimento realizado/finalizado operacionalmente.
- `Ausência`: cliente não compareceu.
- `Cancelado`: atendimento cancelado.

### Status financeiro

- `Pago Parcial` e `Pago` existem hoje como status canônicos legados, mas devem ser tratados como estado financeiro/transitório.
- A direção de produto é migrar para leitura derivada da comanda/pagamentos quando o contrato financeiro permitir.
- Não remover esses status neste incremento sem migração segura.
- Não introduzir mudanças destrutivas no banco nesta fase.

## Matriz operacional inicial

A matriz abaixo orienta ações permitidas. Codex deve ajustar conforme o domínio atual e os testes existentes.

| Status atual | Ações operacionais esperadas |
|---|---|
| Reservado | Confirmar, cancelar, reagendar, marcar ausência se aplicável |
| Agendado | Confirmar, iniciar, cancelar, reagendar, marcar ausência, abrir comanda |
| Confirmado | Iniciar, cancelar, reagendar, marcar ausência, abrir comanda |
| Iniciado | Concluir, cancelar com cautela, abrir comanda |
| Concluído | Abrir/ver comanda, ver recibo quando houver, ver ficha/notas |
| Pago Parcial | Ver/abrir comanda, finalizar pagamento, manter compatibilidade |
| Pago | Ver comanda/recibo, bloquear alterações críticas |
| Ausência | Ver histórico, reagendar novo atendimento se fluxo existir |
| Cancelado | Ver histórico, reagendar novo atendimento se fluxo existir |

## Notas — direção de produto

As notas devem evoluir de campo simples para timeline histórica.

### Tipos de notas

- Nota do cliente: nota geral associada ao cliente, não necessariamente a um atendimento.
- Nota de atendimento: nota vinculada a um appointment específico.
- Nota fixa/importante: nota que deve aparecer no agendamento/contexto do cliente.

### Campos mínimos recomendados

- `id`;
- `org_id`;
- `client_id`;
- `appointment_id`, opcional;
- `author_id`;
- `note_type`: `client`, `appointment`, `fixed` ou equivalente;
- `body`;
- `note_date`, padrão hoje;
- `created_at`;
- `updated_at`;
- `deleted_at`, se soft delete já for padrão;
- anexos: fora da primeira entrega, mas preparar extensão futura sem complicar agora.

### Regras

- notas pertencem à organização;
- notas não vazam entre tenants;
- appointment vinculado deve pertencer ao mesmo cliente e org;
- nota pode ser criada a partir do perfil do cliente;
- nota pode ser criada a partir do agendamento;
- no agendamento, deve ser possível saber se existem notas do cliente/atendimento;
- anexos ficam pendentes para etapa futura, salvo se já houver infraestrutura existente.

## UX futura esperada

### Perfil do cliente

Seção Notas com tabs/segmentos:

- Notas do cliente;
- Notas de atendimento;
- eventualmente Notas fixas/importantes.

Exibir em timeline por mês/data, com autor, data, vínculo com atendimento e ações.

### Agenda / AppointmentSheet

Mostrar indicador discreto:

- `Notas` ativo quando houver notas;
- contador quando possível;
- acesso a notas do cliente e do atendimento;
- criar nota do atendimento com data padrão hoje;
- não deixar notas dominar serviço/procedimento.

## Fora do escopo desta spec

- UI premium final da Agenda;
- FilterSheet/ActionMenu globais;
- anexos reais;
- comentários colaborativos em tempo real;
- edição avançada de histórico;
- migração destrutiva de status de pagamento.

## Critérios de aceite futuros

- matriz de ações/status documentada e testada;
- helper de ações disponíveis por status/contexto;
- notas históricas com RLS e isolamento por org;
- criação de nota de cliente e nota de atendimento;
- leitura de timeline por cliente;
- indicador de notas no contexto do agendamento;
- relatório de pendências para UI premium.