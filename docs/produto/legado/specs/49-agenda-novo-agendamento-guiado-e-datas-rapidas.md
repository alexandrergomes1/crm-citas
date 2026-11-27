# 49 — Agenda: novo agendamento guiado e datas rápidas (E1b)

Origem: decisões de 04/11/2026 sobre os itens **A8** (agendamento guiado) e **A5** (datas rápidas) do estudo
Fresha × KA. Continua a spec 48 (E1a). Visões da agenda (A4/A7) ficam para o E1c; "Criado em" (A6) para o E1d.

## 1. Novo agendamento guiado (A8)

Problema: no computador a tela mostrava Quando antes de Serviços, e no celular o contrário; não havia um
lugar que mostrasse tudo o que seria salvo.

Regras:
- **Mesma ordem nos dois tamanhos**: Cliente → Serviços → Quando → Avisos e sinal → Notas → Resumo.
  No computador a cliente fica na coluna da esquerda; no celular é a primeira linha da tela.
- **Resumo** (bloco final, também no celular): Cliente, Serviços (quantidade e duração total), Quando
  (dia · início – fim, com a repetição se houver), Profissional e Total. O que ainda falta aparece em
  destaque (ícone tracejado + texto de aviso: "Escolha a cliente", "Adicione pelo menos um serviço").
- Regra do resumo é pura (`src/domain/agenda-summary.ts`) e testada; a tela só desenha as linhas.
- O rodapé (Total + Salvar/Agendar) não muda.

Fora desta entrega: **agendamento sem cadastro de verdade** ("sem reserva", cliente nulo). Hoje "Sem cadastro"
cria uma cliente rápida (nome + telefone), como antes. Cliente nula mexe no modelo do agendamento, na
comanda avulsa e nos relatórios; entra no E2 (cliente/comanda/cadastro) junto com o cadastro rápido
separado do "sem reserva".

## 2. Datas rápidas no calendário (A5)

- Atalhos opcionais **+2 semanas, +4 semanas, +6 semanas e +3 meses** abaixo do calendário.
- **Opt-in** pela propriedade `quickFrom` do `MonthCalendar` / `DateField` (desligado por padrão, então
  Bloqueio, painel de data do quadro e demais usos não mudam).
- **Dia de referência** (`quickFrom`): ao **remarcar**, a data atual do agendamento; ao **criar**, o dia em que
  a tela abriu. Não é o dia escolhido agora: assim os atalhos não "andam" a cada toque.
- Tocar num atalho escolhe a data, leva o calendário ao mês dela e fecha o seletor (como tocar num dia).
  O atalho cujo dia está escolhido aparece ligado.
- "+3 meses" mantém o dia do mês; se o mês de chegada for mais curto, vai para o último dia (30 nov → 28 fev).
- Regra pura em `src/domain/agenda-quick-dates.ts`, testada.

## 3. Critérios de aceite

1. Novo agendamento: a ordem das seções é a mesma em 1440 px e em 390 px.
2. O Resumo reflete cliente, serviços, quando e total, e mostra o que falta antes de salvar.
3. Calendário de Data (novo agendamento) e de remarcação mostram as quatro datas rápidas; Bloqueio não.
4. Escolher "+2 semanas" muda a data e o resumo.
5. Vitest do domínio verde; typecheck e lint sem avisos; E2E da agenda verde; prints 1440 e 390.

## 4. Validação do dono (depois do deploy)

- Abrir um horário livre e conferir a ordem das seções no computador e no celular.
- Adicionar serviço, trocar data/hora e ver o Resumo atualizar; conferir o aviso do que falta.
- Abrir o calendário da Data e tocar nas datas rápidas; remarcar um agendamento e repetir.
- Criar o agendamento e confirmar que salvou no dia/horário do Resumo.
