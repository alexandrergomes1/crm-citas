# Spec 17 — Equipe: Profissionais, Turnos e Comissões

## Goal
Permitir que a clínica gerencie profissionais (nome, cor, função, comissão), seus horários de disponibilidade por dia da semana (turnos) e configurações de visibilidade no booking online.

## Entidades

### StaffMember
`id · org_id · name · display_name · email · phone · color(hex) · avatar_url · bio · role(string) · commission_pct · online_booking · visible · active · position`

### StaffShift
`id · org_id · staff_id · day_of_week(0=Dom…6=Sab) · start_time(HH:MM) · end_time(HH:MM) · active`

## Telas

### /[orgSlug]/equipe
- Grid de cards de profissionais (avatar/iniciais, nome, função, cor, turnos resumidos)
- Header: "Equipe" + botão "Novo profissional"
- Toggle ativo / botão editar em cada card
- Empty state global

### StaffForm (Dialog — criar e editar)
- Nome* (exibido na Agenda)
- Nome de exibição (público — booking)
- Função (livre, ex: "Esteticista", "Manicure")
- Email, telefone
- Cor* (palette 16 cores — identificação na Agenda)
- Comissão % padrão
- Online booking (Switch) — aparece no portal público
- Visível (Switch) — aparece nas listas

### ShiftsPanel (embutido no StaffForm — tab "Horários")
- 7 linhas (Dom–Sab), cada uma com:
  - Toggle de dia ativo
  - Hora início / Hora fim (quando ativo)
- Padrão: Seg–Sex 09:00–18:00

## Regras de negócio
- Profissional inativo não aparece na Agenda nem no modal de agendamento
- `online_booking=false` → não aparece no portal público
- Cor é obrigatória — usada como coluna na Agenda
- Turnos definem disponibilidade (verificação de conflitos na Agenda)
- Comissão padrão é herdada pelos itens de agendamento (pode ser sobrescrita por serviço)
- Staff sem user_id é "externo" — não tem login no sistema

## RLS
- SELECT: qualquer membro da org
- INSERT/UPDATE/DELETE: owner, admin, manager

## Dependências
- Sem deps de outros módulos de negócio
- Desbloqueia: Agenda (colunas de profissionais), Checkout (comissões)

## Acceptance Criteria
- [ ] Criar profissional com cor e turnos → aparece na Agenda como coluna
- [ ] Editar turnos → mudança reflete no modal de agendamento (disponibilidade)
- [ ] Toggle ativo=false → some da seleção da Agenda
- [ ] mobile 390px ok — cards em coluna única, Dialog em sheet
- [ ] typecheck zero · lint zero
