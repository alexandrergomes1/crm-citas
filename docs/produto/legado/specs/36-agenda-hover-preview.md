# Spec 36 — Prévia do agendamento ao passar o mouse (AGD-HOVER-01)

Status: implementada em `feat/agenda-hover` (29 out 2026). Dono: Claude.

## Problema

Na agenda do computador, para saber o básico de um atendimento (serviços, telefone,
pagamento, notas) era preciso abrir a ficha lateral. O Fresha mostra uma prévia ao
passar o mouse; a recepção usa isso o dia inteiro para responder ligações.

## Comportamento

- **Só em aparelho com mouse** (`(hover: hover) and (pointer: fine)`). No celular e no
  tablet nada muda: tocar abre a ficha, como antes.
- Mouse parado sobre o bloco por 350 ms abre a prévia ao lado do bloco (à direita; se
  não couber, à esquerda; nunca sai da tela). Sair do bloco fecha.
- Foco pelo teclado (Tab) também abre; `Esc` fecha. Clique continua abrindo a ficha.
- A prévia é só leitura: não tem botões (ações ficam na ficha).

## Conteúdo

1. Horário início–fim e duração.
2. Cliente; telefone, quando houver.
3. Alerta da cliente (ex.: alergia), em destaque, quando houver.
4. Serviços: nome, duração e preço de cada um; total.
5. Situação: status do atendimento; selos de "Pago parcial", "Falta cobrar", "Anamnese
   pendente", "Recorrente".
6. Nota do agendamento (até 140 caracteres).
7. Profissional.

Nada clínico (respostas de anamnese) aparece na prévia.

## Implementação

- Design system: `src/design-system/AppointmentPreview` (cartão + posicionamento em
  portal). `AppointmentCard` recebe `preview` opcional.
- Montagem dos dados: `src/domain/agenda-preview.ts` (puro, testado).
- `AgendaCalendar` monta a prévia com o que a agenda já carrega (sem consulta nova).

## Testes

- `src/domain/agenda-preview.test.ts`: duração, total, nota cortada, selos.
- Screenshot da prévia em 1440px; 390px sem mudança.
