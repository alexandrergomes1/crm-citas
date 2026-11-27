# Spec 35 — Duração por item do agendamento (AGD-ITEM-EDIT-01)

Status: implementada em `feat/item-duration` (29 out 2026). Dono: Claude.

## Problema

Editar um serviço do agendamento cobria preço e profissional, mas não o tempo.
No Fresha a recepção ajusta a duração de cada serviço (ex.: um retoque de 30 min
de um serviço que no catálogo tem 60). Aqui a duração vinha sempre do catálogo, e
o bloco na agenda não refletia o tempo real reservado.

## Regra

- Cada item de agendamento guarda a própria duração (`appointment_items.duration_minutes`).
- Itens antigos ficam com `null` e continuam valendo a duração do catálogo.
- A duração de um item é a do momento do agendamento. Mudar o catálogo depois não
  altera agendamentos já feitos.
- Limites: 5 a 720 minutos (banco, servidor e tela). Na tela: passos de 5 min até 4 h,
  depois de 15 min.
- A duração do agendamento é a soma das durações dos serviços. O horário de início
  não muda; muda o fim.
- O total do agendamento é a soma dos preços dos itens (mesma regra do modal). Antes,
  adicionar, remover ou mudar o preço de um serviço pela ficha não atualizava o total,
  e ele ficava diferente da comanda (achado na revisão: 1 agendamento em produção com
  total 310 e itens somando 270). Agora os três caminhos recalculam o total.

## Onde se edita

1. **Novo/editar agendamento** (modal): cada serviço mostra um seletor de duração ao
   lado do preço. O total de tempo atualiza na hora.
2. **Ficha do agendamento** (lápis do serviço): preço, profissional e duração juntos.
   - Se só preço/profissional mudam, segue a atualização simples de antes.
   - Se a duração muda, a gravação passa pela RPC `update_appointment_atomic`, a mesma
     do modal. Assim valem a checagem de conflito de horário, a regra de status e a
     auditoria.
   - Se o novo fim encosta em outro atendimento ou bloqueio da mesma profissional, a
     tela avisa. Proprietária, administração e gestão podem salvar mesmo assim; o
     conflito forçado fica registrado nas notas internas (regra já existente da RPC).

## Banco

Migrations `20261029040000_appointment_item_duration.sql` (coluna, criar e editar) e
`20261029040100_recurring_item_duration.sql` (recorrência):

- coluna nova, nula, com `check (duration_minutes between 5 and 720)`;
- `create_appointment_atomic`, `update_appointment_atomic` e
  `create_recurring_appointments_atomic` passam a validar e gravar `duration_minutes`
  do item. As três são as definições de produção (conferidas por md5) com só essas
  mudanças. O app atual já envia `duration_minutes` em cada item, então o código em
  produção continua funcionando antes e depois da migration.

## Fora do escopo

- Horário de início por item (serviços em sequência com profissionais diferentes).
- Tempo de pausa/processamento dentro do serviço (Fresha "processing time").
- Comanda/checkout: a duração aparece, mas não se edita lá.

## Testes

- `supabase/tests/50_appointment_item_duration.sql`: grava a duração, recusa fora dos
  limites, item sem duração continua aceito.
- `src/domain/item-duration.test.ts`: duração efetiva, soma, opções do seletor.

## Regras de edição de itens (revisão de 29 out 2026)

- Quem edita: só quem tem `agenda.manage` (spec 29). Profissional não edita itens.
- Travado: atendimento Pago, Pago Parcial, Cancelado ou Ausência não aceita mudar, adicionar
  nem remover serviço. Vale na ação, na RPC e, desde a migration `20261029070000`, no banco
  (gatilho `trg_lock_closed_appointment_items`; RLS de escrita só para owner, admin, manager e
  recepção).
- Preço e profissional: RPC `update_appointment_item_atomic` (trava o agendamento, soma o
  total no banco, audita `APPOINTMENT_ITEM_UPDATED`).
- Duração, adicionar e remover serviço: RPC `update_appointment_atomic`, com checagem de
  conflito e `force` só para gestão.
- Itens com quantidade diferente de 1 ou desconto por item não são editados pela ficha
  (a ação recusa); o total do agendamento é a soma dos preços dos itens.
- Série recorrente com vários serviços: a edição de série muda só as ocorrências em aberto.
