# Agenda · Ideias do projeto antigo (E44)

- **Escrito por:** Analista de requisitos · **Norma:** IEEE 29148 e BABOK (análise de documentos e de sistema existente)
- **Pedido do dono:** E44 (28/11/2026): "Qdo vc for desenvolver o módulo em questão e criar a spec ai vc vê o que
  complementa/agrega pra já não iniciar com vícios." (`docs/decisoes/2026-11-27-fundacao.md`, linha "E44")
- **O que foi lido (só leitura, nada copiado, `AGENTS.md` §3 regra 4):** no `crm-agenda` (commit `98248ec`), as regras
  da Agenda em `src/domain/agenda*.ts` e testes, `src/workspace/agenda/` (`_board`, `_block`, `_lib`), os testes de
  banco `supabase/tests/135_agenda_view_scope.sql` e `150_agenda_reads_writes.sql`, o teste de tela
  `e2e/agenda-operational.spec.ts` e `docs/specs/screens/agenda.md` (rascunho antigo, só para entender; não vale como
  decisão, pedido (c) do dono). Não lido: o que é do Agendamento (`_new`, `_appointment`, status, cancelar, remarcar).
  Não achei segredo nem dado real.
- **Situação:** nenhuma destas ideias entra nos requisitos agora. Cada uma volta ao dono para autorizar **item por
  item** (`AGENTS.md` §3 regra 4). Autorizada, o papel da área reescreve do nosso jeito, com ADR e revisão de outro
  papel (E16·1), e o Analista de requisitos a põe na spec.
- **Responda por item:** "E54·1·A" (aprovar) ou "E54·1·B" (não aprovar), e assim até E54·8.

## As 8 que mais agregam

| Código | O que é (português simples) | Onde está no antigo | Por que agrega | Risco de vício |
|---|---|---|---|---|
| E54·1 | Tocar num horário vazio da grade abre um menu pequeno com "Novo agendamento" e "Bloquear horário", já com a hora e a profissional daquela coluna | `src/workspace/agenda/_board/SlotMenu.tsx`, `useBoardHandlers.ts` | responde o "ponto de entrada do bloqueio" que a spec deixou para a ficha visual (§4); é o padrão do mercado (o próprio antigo cita Fresha e Booksy) | o antigo só abria com mouse ou toque: tem de abrir também pelo teclado (WCAG 2.2, 2.1.1); na coluna de outra profissional, a profissional não vê o menu (E26·2·A); "Novo agendamento" fica "em desenvolvimento" até o Agendamento (RF-08) |
| E54·2 | Linha do "agora" na coluna de hoje, com a hora marcada na coluna das horas, no fuso da empresa | `src/domain/agenda-now.ts`, `_board/TimeGrid.tsx` | mostra no balcão onde o dia está; completa a "Assumption" 1 (rolar até a hora atual) | no antigo a marca era uma pílula vermelha: vermelho é erro e Excluir no `DESIGN.md`, a cor tem de vir do `DESIGN.md` com o dono; a hora vem do fuso da empresa, nunca do aparelho |
| E54·3 | Atalhos de motivo do bloqueio (Almoço, Folga, Reunião, Curso, Pessoal), além do texto livre | `src/domain/agenda-time-blocks.ts` (`BLOCK_REASON_SHORTCUTS`), `_block/ReasonField.tsx` | menos digitação no balcão e motivos iguais entre pessoas | o antigo tinha "Médico", que convida a escrever dado de saúde no motivo (RGPD art. 9): sai; o antigo misturava os atalhos com "tipos de bloqueio" (tabela adiada, com `is_paid`, dinheiro): aqui só texto; os atalhos precisam dos 3 idiomas (RNF-05) |
| E54·4 | Novo bloqueio nasce com 1 h; se a pessoa põe o início depois do fim, o fim anda junto (início + 1 h) | `_block/TimeBlockPanel.tsx` (`changeStart`) | evita o erro "fim antes do início" (RN-03) antes de salvar | o antigo cortava em 23:59 e deixava o bloqueio terminar antes do pedido; aqui o fim nunca passa do fim do dia da empresa (RN-03) e a pessoa vê a mudança |
| E54·5 | No campo de hora, digitar sem dois-pontos vale: "1410" vira 14:10 e "930" vira 09:30 | `src/domain/agenda-calendar.ts` (`parseTimeInput`) | rapidez no balcão e no teclado numérico do celular | em inglês a hora pode ser de 12 h (RNF-05): "930" fica ambíguo (manhã ou noite); precisa da regra por idioma, com teste |
| E54·6 | No topo de cada coluna, o resumo da profissional no dia: "3 atendimentos · 4 h 50 min ocupadas", sem valores | `src/domain/agenda-board.ts` (`staffDaySummary`), `_lib/board-view.ts` | a dona e a recepção veem a carga de cada uma sem abrir nada | "resumo do dia" está em "depois" na §2.1 (o do antigo levava valores em dinheiro: sai); para a profissional, o resumo das colunas das outras revelaria a agenda delas, que ela não vê (E58·A e a ordem do dono de 28/11, "cada profissional só vê o dela"): **fica fixo que a profissional vê o resumo só da própria coluna** |
| E54·7 | O calendário da data marca os dias que têm agendamento ou bloqueio | `supabase/tests/150_agenda_reads_writes.sql` (`agenda_marked_days`), migration `20261114020000` | ajuda a achar o dia ao escolher a data | é uma ida a mais ao banco por mês aberto (RNF-02); para a profissional, marcar os dias das outras revelaria a agenda delas: **fica fixo que a profissional vê marcados só os dias dela** (E58·A e a ordem do dono de 28/11) |
| E54·8 | No celular, um modo "Lista" do dia: os atendimentos em ordem e os intervalos livres como linhas tocáveis ("Livre 14:30–16:00") | `src/domain/agenda-day-list.ts`, `agenda-mobile-mode.ts`, `_board/MobileDayList.tsx` | em 390 px várias colunas não cabem; a spec deixou a disposição do celular para a ficha visual (§4) | "livre" depende do expediente de cada profissional (adiado, módulo Equipe); sem ele, "livre" é qualquer hora; **é uma visão nova e amplia o escopo da §2.1 da spec ("só Dia")**: aprovar é aceitar essa ampliação; entra no "Dia ▾" e na ficha visual |

## Descartadas (uma linha cada)

| Ideia do antigo | Onde | Motivo |
|---|---|---|
| Bloquear a equipe toda, pulando quem tem atendimento | `tests/150`, `_block/TimeBlockPanel.tsx` | já avaliada e descartada na v1 (`docs/produto/avaliacao-crm-agenda/regras-do-banco.md` #62): só se o dono pedir |
| Bloqueio repetido (todo dia, semana ou mês, até 60 vezes) | `src/domain/agenda-time-blocks.ts` | fora da v1 (§2.1: "só único"); fica para a spec do bloqueio repetido |
| Interruptor "Mostrar o motivo na agenda" ("Bloqueado") | `agenda-time-blocks.ts` (`BLOCK_HIDDEN_TITLE`), `_block/BlockOptions.tsx` | a E26·1·B já esconde o motivo das outras profissionais; o interruptor seria um campo a mais sem ganho |
| Campo "Descrição" (255 caracteres) além do motivo | `_block/BlockOptions.tsx` | segundo texto livre, mais lugar para dado pessoal (RGPD art. 5(1)(c)); o motivo basta |
| "Permitir reservas online" no bloqueio | `_block/BlockOptions.tsx` | depende do portal público (fim da fila, E21·1) |
| Filtros por canal, sinal, pagamento, formulário e origem | `src/domain/agenda-board.ts` | dependem de outros módulos ou de dinheiro; a v1 filtra só status e bloqueio (RF-06) |
| Rodapé do dia com "€ previstos" e "janelas livres" | `src/domain/agenda-board.ts` (`daySummary`) | dinheiro e expediente; "resumo do dia" está em "depois" |
| Grade de 09 h a 19 h que se alarga para caber os itens | `src/domain/agenda-calendar.ts` (`gridHours`) | a ideia de alargar ficou superada pela E59·A: a v1 tem a faixa 08:00–20:00 que se alarga (RN-11, ADR 0006 · D17), escrita do nosso jeito, nada copiado; a grade pelo expediente vai para a spec seguinte (E57·B) |
| Aviso "este usuário ainda não está ligado a uma profissional" | `src/domain/agenda-scope.ts` | não se aplica: aqui as colunas saem das pessoas da equipe (E26·3·A), não de um cadastro à parte |
| Guardar os dias lidos por 60 s no navegador | `src/workspace/agenda/_lib/day-batcher.ts` | decisão técnica do Arquiteto; guarda no navegador pode mostrar horário velho; o RNF-02 já limita as idas |
| Edição de bloqueio que conflita é recusada e o antigo fica | `tests/150` | já coberto: alterar é um pedido só e o conflito é recusado sem gravar (RN-04, CA-05) |
| Teste de tela com login real num banco compartilhado e data sorteada no futuro | `e2e/agenda-operational.spec.ts` | vício: depende de banco remoto e de conta real; aqui o teste usa o banco local (CA-11) |
| Visões 3 dias, Semana e Mês, altura das horas, lista de espera, arrastar, exportar | `src/domain/agenda-views.ts` e `_board/` | já estão em "depois" na §2.1 |

## Não verificado
- Li o antigo por arquivos de regra, testes e trechos de tela, não linha a linha; nada foi rodado.
- Códigos E54·1 a E54·8 (revisão 5b do Gerente de projeto: E50·I confunde ao digitar e E51 a E53 lembram a E5·1 a
  E5·3); outras specs em branches paralelas podem usar o mesmo número: o Gerente de projeto confere antes de mandar.
