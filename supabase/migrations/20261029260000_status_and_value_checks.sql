-- Regras mínimas de status e valor no banco (revisão de banco 29 out).
-- Encoding: UTF-8
--
-- appointments.status era texto livre: um valor fora da lista (ex.: "Ausencia" sem acento) passava
-- e sumia dos índices parciais e das checagens de conflito, liberando ou travando horários sem
-- motivo visível. Agora só os 9 status canônicos (src/domain/appointment-status.ts), e o fim
-- precisa ser depois do início. Vale-presente: saldo entre zero e o valor inicial.
-- Produção conferida: todas as linhas já cumprem as regras.

alter table public.appointments
  add constraint appointments_status_canonical check (status in (
    'Reservado', 'Agendado', 'Confirmado', 'Iniciado', 'Concluído', 'Pago Parcial', 'Pago', 'Ausência', 'Cancelado'
  )),
  add constraint appointments_period_valid check (end_at > start_at);

alter table public.gift_cards
  add constraint gift_cards_remaining_within_initial check (remaining_value >= 0 and remaining_value <= initial_value);
