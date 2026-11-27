# Spec 05 - Agenda Avancada, Bloqueios e Equipe

**Status:** Implementada - incremento 1 (`time_blocks` verificada no remoto em 2026-06-13)
**Aprovacao de produto:** visao do dono registrada em `docs/product-vision-detail.md` em 2026-06-11

## Feature Trace

- Product Vision: item 4 - Agenda robusta
- Scope Master: backlog 9 - Agenda avancada
- Architecture: Agenda como nucleo operacional
- Design System: `CalendarGrid`, `TimeBlock`, `SegmentedControl`, `FilterBar`, `Dialog`
- Specs relacionadas: `04-agenda-core.md`, `17-team-management-commissions.md`

## Goal

Transformar a agenda diaria existente em uma superficie operacional que permita consultar
periodos diferentes, filtrar profissionais, ajustar a densidade visual e registrar
indisponibilidades sem converter bloqueios em atendimentos.

## Users

| Perfil | Permissao |
|---|---|
| owner, admin, manager | Ver todos, criar e remover bloqueios |
| receptionist | Ver todos, criar e remover bloqueios |
| professional | Ver agenda e criar bloqueios; restricao ao proprio staff fica para o vinculo user/staff |
| finance, viewer | Somente leitura quando a rota for liberada para esses perfis |

## Screens

### Toolbar da Agenda

- Navegacao por periodo anterior, hoje e proximo.
- Views: Dia, 3 dias, Semana e Mes.
- Zoom: compacto, confortavel e amplo.
- Filtro multi-profissional: nenhum selecionado significa todos.
- Acoes primarias: Novo agendamento e Bloquear horario.

### Calendario Dia / 3 dias / Semana

- Grade temporal de 30 minutos.
- Dia: uma coluna por profissional.
- 3 dias/Semana: uma coluna por combinacao data + profissional.
- Horarios fora do turno aparecem como `TimeBlock` "Fora do expediente".
- Bloqueios persistidos aparecem acima da grade e podem ser removidos.
- Agendamentos cancelados permanecem no historico, mas nao aparecem na grade operacional.

### Visao Mes

- Grade mensal de sete colunas.
- Cada dia mostra contagem e os primeiros atendimentos.
- Clique em um dia abre a view Dia naquela data.
- Cancelados nao entram na contagem operacional.

### Modal Bloquear Horario

- Profissional, data, inicio, fim e motivo.
- Recorrencia opcional semanal.
- Quantidade de ocorrencias entre 2 e 12 quando recorrente.

## Main Flow

1. Usuario acessa a Agenda; a URL define `date` e `view`.
2. Server Component calcula o periodo e carrega agendamentos, bloqueios, equipe e servicos.
3. Usuario troca view, periodo, zoom ou profissionais.
4. Usuario cria um bloqueio unico ou semanal.
5. Server Action revalida autenticacao, organizacao, payload e pertencimento do profissional.
6. Repositorio grava os bloqueios com `org_id`; a Agenda e revalidada.
7. Usuario pode abrir um bloqueio e remover apenas aquela ocorrencia.

## Business Rules

- `start_at` deve ser anterior a `end_at`.
- Bloqueio deve iniciar e terminar no mesmo dia neste incremento.
- Profissional e obrigatorio.
- Recorrencia semanal gera ocorrencias concretas; `repeat_rule` registra a regra de origem.
- Remover uma ocorrencia nao remove as demais.
- Cancelar atendimento atualiza status para `Cancelado`; nao faz exclusao fisica.
- `Pago` e estado financeiro e nao substitui `Concluido` na semantica do atendimento.
- Turnos de `staff_shifts` definem a faixa visual de expediente.
- Toda leitura e escrita usa `org_id`; IDs recebidos do cliente nunca sao confiados sem validacao.

## Data Contract

```ts
type AgendaViewMode = 'day' | '3days' | 'week' | 'month';

interface TimeBlockInput {
  staff_id: string;
  date: string;       // YYYY-MM-DD
  start_time: string; // HH:mm
  end_time: string;   // HH:mm
  reason?: string;
  recurrence: 'none' | 'weekly';
  repeat_count: number;
}

interface TimeBlockRow {
  id: string;
  org_id: string;
  staff_id: string | null;
  resource_id: string | null;
  location_id: string | null;
  start_at: string;
  end_at: string;
  reason: string | null;
  repeat_rule: string | null;
  created_by: string | null;
  created_at: string;
}
```

## RLS And Permissions

- `time_blocks` mantem RLS habilitado.
- SELECT exige membership na organizacao.
- INSERT/DELETE exige role operacional permitida.
- Server Action chama `requireOrgAccess`.
- `staff_id` deve existir na mesma `org_id`.
- Retornos de Server Actions contem apenas sucesso/erro, nunca registros completos.

## UX States

- Loading: skeleton existente da Agenda.
- Empty staff: CTA para cadastrar equipe.
- Empty period: grade vazia continua clicavel.
- Saving: botoes do modal ficam desabilitados e mostram loading.
- Error: mensagem inline e toast quando aplicavel.
- Mobile 390px: toolbar quebra em linhas, filtros rolam horizontalmente e a grade mantem scroll.

## Acceptance Criteria

- [ ] Views Dia, 3 dias, Semana e Mes funcionam por URL.
- [ ] Zoom altera a altura dos slots sem recarregar a pagina.
- [ ] Filtro permite um, varios ou todos os profissionais.
- [ ] Turnos configurados na Equipe aparecem como disponibilidade na Agenda.
- [ ] Bloqueio unico aparece imediatamente apos salvar.
- [ ] Bloqueio semanal cria de 2 a 12 ocorrencias.
- [ ] Uma ocorrencia pode ser removida sem apagar a serie.
- [ ] Agendamentos cancelados nao aparecem na grade nem na contagem mensal.
- [ ] Server Actions validam payload, auth, org e staff.
- [ ] Componentes de tela permanecem abaixo de 300 linhas.
- [ ] Typecheck, lint, Vitest e build passam.
- [ ] E2E cobre troca de view e fluxo de bloqueio.
- [ ] Screenshots desktop 1440px e mobile 390px sao gerados.

## Tests

- Vitest: calculo dos periodos e recorrencia semanal.
- Playwright: trocar Dia/Semana/Mes, filtrar profissional e abrir modal de bloqueio.
- Playwright autenticado: criar e remover bloqueio quando credenciais de teste estiverem disponiveis.

## Out Of Scope

- Editar serie inteira de recorrencia.
- Recorrencia diaria, mensal ou RRULE arbitraria.
- Drag and drop.
- Google Calendar two-way sync.
- Restricao automatica de professional ao proprio `staff_id`.
- Recursos compartilhados (sala/equipamento) e conflitos bloqueantes.
