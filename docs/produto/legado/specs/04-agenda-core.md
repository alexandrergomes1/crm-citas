# Spec — 04 Agenda Core

**Status:** Aprovada para implementação (Fase 3)
**Referências legadas:** `agenda-master-plan.md`, `agenda-core.md`

---

## Goal

Implementar o eixo operacional central do KA Beauty OS: a agenda interna.
Profissionais e recepção gerenciam o dia, veem contexto do cliente e controlam status de atendimentos.

---

## Users

| Persona | Uso |
|---|---|
| Recepção | Cria/edita agendamentos, confirma presença, acompanha dia |
| Profissional | Consulta sua agenda do dia, altera status, vê contexto do cliente |
| Gestor | Visão geral da equipe, planning semanal |

---

## Screens

### 1. Agenda Principal (`/[orgSlug]/agenda`)
- **Header:** título "Agenda", navegação data (← hoje →), switcher Dia/Semana, botão "Novo agendamento"
- **FilterBar (desktop):** profissional, status; badge com count ativo
- **CalendarGrid:** colunas por profissional, horário 07:00–22:00, 1px/minuto, appointment cards posicionados absolutamente
- **Mobile:** coluna única por profissional selecionado, scroll vertical, botão FAB "+"

### 2. Modal Criar/Editar Agendamento
- Campos: cliente (busca), profissional (select), data, hora início, duração (→ hora fim), status, observações, canal de origem
- Contexto do cliente ao selecionar: saldo, tier, alerta
- Actions: Salvar | Salvar como Confirmado | Cancelar

### 3. Card de Agendamento (inline na grade)
- Nome do cliente, serviço principal, horário, StatusBadge
- Clique: abre detalhe lateral (sheet) com contexto completo + ações

### 4. Detalhe do Agendamento (Sheet lateral)
- Resumo: cliente, serviço, profissional, horário, status
- Ações de status: Confirmar / Iniciar / Concluir / Ausência / Cancelar
- Alertas do cliente (se houver)

---

## Main Flow

```
1. Usuário acessa /[orgSlug]/agenda
2. Sistema carrega appointments do dia atual (Server Component)
3. Usuário navega entre datas (client-side, URL param ?date=YYYY-MM-DD)
4. Usuário clica em horário vazio → abre modal de criar agendamento
5. Usuário clica em card existente → abre sheet de detalhe
6. Usuário muda status no detalhe → Server Action atualiza banco
7. Agenda re-renderiza com novo status
```

---

## Business Rules

- Novo agendamento requer cliente cadastrado e pertencente à organização
- `start_at` e `end_at` devem ser no mesmo dia (para esta fase)
- Não há sobreposição forçada — warning visual apenas (não bloquear)
- Status flow: Agendado → Confirmado → Iniciado → Concluído → Pago (checkout fase 6)
- Cancelado e Ausência são terminais
- Bloqueios de tempo aparecem como TimeBlock na grade (não como appointment)

---

## Data Contract

```ts
// Entrada do modal
interface AppointmentInput {
  client_id:        string;          // cliente cadastrado da organização
  client_name:      string;          // snapshot derivado no servidor
  staff_id?:        string | null;
  staff_name:       string;
  start_at:         string;          // ISO 8601 com timezone
  end_at:           string;
  duration_minutes: number;
  status:           AppointmentStatus;
  notes?:           string | null;
  source:           'MANUAL' | 'WHATSAPP' | 'ONLINE' | 'PHONE';
  location_id?:     string | null;
  org_id:           string;          // injetado server-side
  total:            number;          // 0 na criação (calculado no checkout)
  discount:         number;          // 0 na criação
  tip:              number;          // 0 na criação
}

type AppointmentStatus =
  | 'Reservado' | 'Agendado' | 'Confirmado' | 'Iniciado'
  | 'Concluído' | 'Pago Parcial' | 'Pago' | 'Ausência' | 'Cancelado';
```

---

## RLS And Permissions

- Leitura/escrita: roles `owner`, `admin`, `manager`, `receptionist`, `professional`
- `professional` vê apenas seus próprios agendamentos (future: via `staff_id = user staff_id`)
- RLS já implementado na migration `005_appointments.sql`

---

## UX States

| Estado | Comportamento |
|---|---|
| Carregando | CalendarGrid com skeleton rows |
| Sem agendamentos | EmptyState dentro da grade |
| Agendamento criado | Toast success + card aparece na grade |
| Erro ao criar | Toast error com mensagem |
| Status atualizado | Badge muda imediatamente (optimistic) |
| Mobile | Single column, FAB verde no bottom-right |

---

## Acceptance Criteria

- [ ] Agenda do dia carrega em < 1s (dados reais ou empty state)
- [ ] Navegação de data funciona sem reload (URL param)
- [ ] Modal abre e fecha corretamente em desktop e mobile
- [ ] Criar agendamento salva no banco e aparece na grade
- [ ] Alterar status atualiza visualmente em < 500ms
- [ ] Nenhum componente de tela > 300 linhas
- [ ] Build limpo sem erros

---

## Out Of Scope (Fase 3)

- Checkout e pagamento (Fase 6)
- Anamnese vinculada (Fase 8)
- WhatsApp/lembretes (Fase 9)
- Pacotes/planos (Fase 10)
- Recorrência de agendamentos
- Google Calendar sync
- Drag & drop de cards
- Visualização Semana/Mês (apenas Dia nesta fase; semana em Fase 4)
