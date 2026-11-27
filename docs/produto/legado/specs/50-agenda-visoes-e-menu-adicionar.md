# 50 — Agenda: seletor único de visões e menu "Adicionar" (E1c)

Origem: decisões de 04/11/2026 — **A4** (visualizações e atalhos numa folha só: "Mesclar com Fresha") e **F2**
(menu "+" com várias criações: Agendamento, Bloquear horário e Lista de espera). Continua as specs 48 e 49.
O A7 (semana em grade configurável no celular), o A6 (filtros) e o toque em horário vazio no celular ficam para o E1d.

## 1. Seletor único de visões (A4)

Problema: no computador a barra tinha só Dia e Semana; "Vista de 3 dias" e "Vista do mês" viviam escondidas no menu
Opções ("Vistas e grade"). No celular a folha de data mostrava a visualização, mas faltavam os atalhos da agenda.

Regras:
- **Computador**: um único seletor segmentado **Dia | 3 dias | Semana | Mês**, com texto (4 opções precisam de rótulo).
  Os itens "Vista de 3 dias" e "Vista do mês" saem do menu Opções (continuam "Altura da grade" e "Painel lateral").
- As setas anterior/próximo andam **o tamanho da visão**: 1 dia, 3 dias, 7 dias ou 1 mês, e o nome acessível acompanha
  ("Dia anterior", "3 dias anteriores", "Semana anterior", "Mês anterior"…). Regra pura em `src/domain/agenda-views.ts`.
- **Celular**: a folha "Escolher o dia e a visualização" mantém Dia | Lista | Semana e ganha, ao fim, os atalhos
  **Lista de espera** (com a contagem) e **Configurações** (horário de funcionamento e ajustes da agenda).
  3 dias e Mês continuam mostrados como a lista da semana no celular (decisão A7 pendente para o E1d).
- A visão escolhida continua indo na URL (`?vista=`), sem mudar o contrato de rota.

## 2. Menu "Adicionar" (F2)

- **Computador**: o botão "Novo agendamento" vira botão dividido: a parte principal continua criando o agendamento
  (um clique, como hoje) e a seta abre o menu **Agendamento · Bloquear horário · Lista de espera**. O botão avulso
  "Bloquear horário" sai da barra (continua em Opções e no menu).
- **Celular**: a folha do "+" flutuante lista **Novo agendamento · Bloquear horário · Lista de espera**.
- "Lista de espera" no menu abre o painel da lista **já no formulário de adicionar** (quem quer só ver a fila usa
  Opções/Lista de espera). Quem não tem `agenda.manage` não vê os itens de criar; quem não tem `agenda.block` não vê Bloquear.

## 3. Organização do código

`AgendaScreen` estava em 253 linhas. O cabeamento de navegação (ir, passo, novo, rótulo do período) sai para
`_board/useAgendaNav.ts`, e o menu de criação é um componente próprio (`_board/AddMenu.tsx`), para a tela ficar < 300 linhas.

## 4. Critérios de aceite

1. Computador: Dia | 3 dias | Semana | Mês trocam a visão e a URL; a visão atual aparece marcada.
2. As setas andam 1, 3, 7 dias ou 1 mês conforme a visão, e o nome da seta acompanha.
3. O menu Opções não tem mais "Vista de 3 dias" nem "Vista do mês".
4. Menu da seta do botão: Bloquear horário abre o painel de bloqueio; Lista de espera abre o painel no formulário.
5. Celular: o "+" lista os três itens; a folha de data traz Lista de espera e Configurações.
6. Vitest do domínio, typecheck, lint, E2E da agenda (inclui os 4 testes antigos corrigidos); prints 1440 e 390.

## 5. Validação do dono (depois do deploy)

- Trocar entre Dia, 3 dias, Semana e Mês e usar as setas em cada uma.
- Abrir a seta do botão "Novo agendamento" e testar as três criações.
- No celular, abrir o "+" e a folha da data; conferir Lista de espera e Configurações.
