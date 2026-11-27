# 48 — Agenda: bloqueio de horário e seletor de horário (E1)

Origem: decisões de 04/11/2026 (itens A4–A8 do estudo Fresha × KA e duas correções avulsas).
Esta spec cobre a **primeira entrega do E1**: as duas correções avulsas. Os itens A4–A8 e F2 entram em
entregas seguintes do E1, cada uma com seu bloco neste arquivo.

## Entrega 1 — correções avulsas

### 1.1 Seletor de horário (todo campo de horário da agenda)

Problema: o campo "Início"/"Hora" do agendamento, da remarcação e da lista de espera é um texto livre;
a pessoa digita e pode errar o formato.

Regras:
- O campo de horário é um **botão** que mostra o horário em 24 h ("14:00"). Tocar abre o seletor:
  popover preso ao campo no computador, folha de baixo no celular.
- O seletor lista o dia todo **de 15 em 15 minutos**, em grade de 4 colunas, com o horário atual
  destacado e rolado para o centro. Tocar num horário escolhe e fecha.
- O seletor também tem o campo **"Digitar o horário"** para o minuto exato (ex.: 14:10). Aceita
  `1410`, `14:10` ou `930`; horário inválido mostra "Use HH:MM, ex.: 14:30" e não é aplicado.
- Alvos de 44 px no celular. Sem o relógio do navegador (24 h em qualquer aparelho).
- A linha "Início"/"Fim" do bloqueio usa o mesmo corpo de seletor (sem duplicar código), aberto em painel
  lateral no computador e folha de baixo no celular, como as linhas Dia e Repetir.
- Digitar: com 4 dígitos (`1410`) o horário vale na hora; com 3 (`930`) vale ao sair do campo ou no Enter.
  O texto não é reescrito enquanto o campo tem foco. Ao escolher na lista no computador, o foco volta ao campo.

Fora desta entrega: os campos de horário de Ajustes (expediente, turnos) e do Caixa continuam com o
campo do navegador; entram numa entrega própria.

### 1.2 Bloqueio de horário: motivo sem redundância

Problema: o motivo vem como campo de texto + uma fila de atalhos (Almoço, Folga, Reunião, Curso,
Pessoal, Médico e os tipos cadastrados), e "Mais opções" repete o mesmo assunto com o seletor
"Tipo de bloqueio".

Regras:
- **Um único campo "Motivo"**: lista compacta com os motivos predefinidos (tipos cadastrados primeiro,
  depois os sugeridos) e a opção **"Outro (digitar)"**.
- Escolher um motivo da lista preenche o motivo. Escolher "Outro (digitar)" mostra logo abaixo o campo
  **"Digite o motivo"** já com o foco, até 120 caracteres.
- Ao editar um bloqueio cujo motivo não está na lista, o campo abre em "Outro" com o texto preenchido.
- Ao editar, o tipo gravado **não muda** se o motivo não for alterado.
- O **tipo cadastrado deixa de ser escolhido à mão**: é o tipo cujo nome é igual ao motivo; sem
  correspondência, vale o tipo genérico (ou o atual, ao editar). "Mais opções" fica só com: mostrar o
  motivo na agenda, descrição e permitir reservas online.
- Sem fila de chips no bloqueio. O componente `ReasonPicker` (cancelar e estornar) não muda.

## Domínio (puro, com testes)

- `agenda-calendar`: `parseTimeInput(raw)` e `timeSlots(step)`.
- `agenda-time-blocks`: `BLOCK_REASON_OTHER` e `reasonChoice(reason, shortcuts, other)`.

## Testes

- Vitest: funções de domínio acima.
- Playwright (`e2e/agenda-advanced.spec.ts`): o bloqueio mostra "Motivo" com a lista e "Digite o motivo"
  ao escolher "Outro"; o campo "Início" do agendamento abre o seletor e escolher 14:15 grava 14:15.
- Capturas 390 px e 1440 px do bloqueio e do seletor.

## Critérios de aceite

1. Nenhum campo de horário da agenda aceita um formato inválido sem aviso.
2. O bloqueio tem um único lugar para o motivo e nenhum controle repetido em "Mais opções".
3. Typecheck, lint, Vitest e E2E da CI verdes; arquivos de tela abaixo de 300 linhas.
