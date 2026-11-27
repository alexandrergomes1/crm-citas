# Módulo: Agenda (AGE)

> A tela onde a recepção vê o dia, a semana e o mês de cada profissional, cria e move atendimentos, bloqueia horários e cuida da
> lista de espera. O atendimento aberto e o "Novo agendamento" são outro módulo (Agendamento, AGD).

**Telas e rotas:** `/{org}/agenda` (parâmetros `?data=`, `?vista=`, `?prof=`, `?hora=`, `?repetir=`; `?ag=` e `?novo=1` abrem o Agendamento) · **Código:** `src/workspace/agenda/` (`_board`, `_block`, `_waitlist`, `_repeat`, `_data`, `_lib`; rota em `src/routes/$orgSlug/agenda.tsx`, todas existem) · **Spec(s):** `docs/specs/screens/agenda.md` (aprovada por aceite em lote; ver Decisões) · legado: `docs/produto/legado/specs/04, 05, 23, 24, 25, 26, 35, 36, 40, 46, 48, 49, 50` e `docs/produto/legado/produto/agenda-operational-scope.md`

Siglas das origens: "R3 B ag:47" = relatório R3, seção B, `agenda.md` linha 47. "R4 B 05" = R4, seção B, spec 05 do legado. "reg:39" = `docs/decisoes/historico/registro-ate-2026-11-24.md` linha 39. "inv" = `docs/design/inventario/agenda-e-agendamento.md`. Origens como "04:33-36", "52:105-121" ou "10:23-25" (sem prefixo) são spec do legado (`docs/produto/legado/specs/NN-*.md`) e linha, lidas inteiras. Todos os relatórios estão em `docs/reorganizacao/levantamento/`. Onde o relatório R4 marca como "Agenda" um recurso do guia de novo agendamento, ele está em AGD, conforme `docs/reorganizacao/02-mapa-de-modulos.md`.

## Recursos
| ID | Recurso | Estado | Onde | Origem |
|---|---|---|---|---|
| AGE-01 | Visões Dia, 3 dias, Semana e Mês (setas andam o tamanho da visão; 3 dias e Mês viram lista da semana no celular) | pronto (antigo) · pronto (atual) | `/agenda?vista=` | R4 B 05, 50 (50:12-20); R5 B scope-master:39; R1 B rv:74, inv:23; R3 B audit:24 |
| AGE-02 | Um ícone abre o painel de visão e altura das horas (AG20, AGT1: Compacta, Normal, Ampla) | pronto (atual, "aplicado") · contestado: a barra mostra "Dia ▾" em texto, "a conferir" | barra do computador | R3 B ag:47 (contestado em padrao:154, audit:62); R1 B inv:23; R4 B 50 |
| AGE-03 | Altura da hora: 44/60/84 px no computador e 44/52/64 no celular (antes: zoom compacto, confortável, amplo) | pronto (antigo) · pronto (atual); não acompanha o nível de tamanho | grade | R4 B 05; R3 B ag:31; R1 B CAM4-04 (reg:217) |
| AGE-04 | Sem coluna lateral: a equipe vira o botão Profissionais e o Status vai para Filtros (CMP-A1). Antes: sidebar e subnav (descartados) | pronto (atual) · descartado (antigo V3) | barra | R3 B ag:20; R1 B reg:249; R5 B |
| AGE-05 | Barra do computador: ‹ Hoje ›, data ▾, visões; à direita Profissionais, Lista de espera, Filtros (funil), ⋮, Novo agendamento ▾ | pronto (atual) | `_board/Toolbar` | R3 B ag:21 |
| AGE-06 | Número no Profissionais só quando a agenda mostra parte da equipe (AG8); no celular o número passou para o botão "Agenda" | pronto no computador (atual) · parcial no celular | barra | R3 B ag:22, ag:80; R1 B reg:46 |
| AGE-07 | Número na Lista de espera | pronto (atual) | barra | R3 B ag:23 |
| AGE-08 | Filtros por profissional, status (caixinhas, várias marcações), tipo de item, tipo de bloqueio e serviço | pronto (antigo) · pronto (atual) | Filtros | R4 B 25 (25:22,59); R1 B inv:26; R3 B ag:24 |
| AGE-09 | Filtros por canal, pagamento, criação e segmento de cliente; filtros salvos | planejado (antigo, "ausente") · planejado (atual); a lista de filtros do inventário já traz canal, criado por e pagamento: conferir | Filtros | R4 B 24 (24:37); R5 B scope-master:42; R3 B opm:122-137, fr/README:49; R1 B inv:26 |
| AGE-10 | Status no cartão só com ícone (mapa de 7 ícones); nome na dica, no leitor de tela, no Tab e no toque | parcial (atual: balão no Tab; no celular só enquanto o dedo segura) | cartão | R3 B ag:25, ag:46; R1 B inv:43 |
| AGE-11 | € no cartão igual nos dois aparelhos: verde = pago, âmbar = falta cobrar (AG15) | parcial, "não verificado" (atual) · ícones de pagamento no bloco (Booksy, referência) | cartão | R3 B ag:38; R1 B reg:53; R5 B |
| AGE-12 | Resumo do dia em uma linha, faixa de 40 px; contador "N reservados" (zero some) | pronto (atual) · contador parcial "não verificado" | rodapé do quadro | R3 B ag:26, ag:36, ag:85-86; R1 B inv:44 |
| AGE-13 | Resumo de Semana, 3 dias e Mês com valor previsto e reservados | parcial, "não verificado" (atual) | rodapé | R3 B ag:37; R1 B reg:52 |
| AGE-14 | "Previstos" conta a Ausência? (pergunta em aberto; recomendação: tirar) | a definir | resumo | R1 B own:55 |
| AGE-15 | Botão que abre o resumo do dia (AG2·C) | descartado por ora (atual) | — | R3 B ag:72, ag:117 |
| AGE-16 | Cartão com fundo neutro e faixa em tons próximos (AG24·B, CAM1-11); valores dos tons não definidos | planejado (atual, "não aplicado") | cartão | R1 B reg:71, rv:93; R3 B ag:49 |
| AGE-17 | Celular: botão "Agenda" abre folha com visões, altura, profissionais, Filtros, Lista de espera, Lembretes de amanhã, Checkouts em aberto, Bloquear horário e Configurações da agenda (a folha da data fica só com o calendário) | pronto (atual, "aplicado"); o nome "Agenda" no botão falta no PR #123 | `_board/AgendaSheet`, `MobileTopBar` | R3 B ag:48; R1 B inv:34-35; padrao:136 |
| AGE-18 | Celular: visão Lista com intervalos livres tocáveis ("Livre 14:30–16:00"), cabeçalho de 1 linha, visão lembrada no aparelho | planejado (antigo V26) · planejado (atual) | celular | R5 B v26-mobile-ux:13; R1 B v26:27-29 |
| AGE-19 | Celular: agenda em cartões agrupados por profissional (E1·A), grade e semana como opção. O dono reclamou em 23/11 que o celular "só mostra em lista" | planejado, nada escolhido (atual) | celular | R3 B fechar:227-233; falas:139 |
| AGE-20 | Dia vazio no celular: "Nenhum atendimento neste dia" e botão "Novo agendamento" (AGT4) | pronto (atual, só sem filtro, sem bloqueio e com agenda ligada) | `MobileBoard` | R3 B ag:52; R1 B reg:78 |
| AGE-21 | Ações do cartão: Tab e botão direito abrem o menu; no celular segurar abre ações e tocar abre o agendamento (AGT12, AGT24) | pronto (atual); iPhone "não verificado" | cartão | R3 B ag:54; R1 B reg:83, 92 |
| AGE-22 | ⋮ da agenda: Exportar CSV, Checkouts em aberto, Imprimir, Horário de funcionamento, Lembretes de amanhã; sem "Altura da grade"; Imprimir e Exportar só no computador (AGT2, 5, 15, 16) | pronto (atual) | `_board/OptionsMenu` | R3 B ag:50; R1 B inv:28; inv §1 |
| AGE-23 | Lupa de busca: sai da barra do computador (vale a busca global do topo); fica no celular (AG16·A) | pronto (atual) · conferência visual pendente | barra | R3 B ag:21, ag:79, ag:106; R1 B reg:55 |
| AGE-24 | Menu "Adicionar": Agendamento, Bloquear horário, Lista de espera; "Novo ▾" na barra apertada (~1024 px) | pronto (antigo) · pronto (atual) | `_board/AddMenu` | R4 B 50 (50:7-34); R3 B ag:34, ag:94 |
| AGE-25 | Sem legenda de ícones no pé da Semana | pronto (atual) | rodapé | R3 B ag:35, ag:95 |
| AGE-26 | Botões só com ícone: 32 px no computador, 40 px no celular (toque 44); dourado só no botão principal, escolhido e hoje em preto; Lucide traço 1,75, nunca emoji | pronto (atual) | todo o quadro | R3 B ag:28-29, ag:33; R1 B reg:47, 201 |
| AGE-27 | "Formulário" no lugar de "Ficha" nos textos da agenda | pronto (atual); a imagem da camada 8 ainda escreve "Ficha" | rodapés, filtros, cartão | R3 B ag:32; ag:135 |
| AGE-28 | Prévia ao passar o mouse (350 ms, só mouse): horário, cliente, telefone, alerta, serviços, total, situação, nota, profissional; sem dado clínico | pronto (antigo) · referência Fresha, sem decisão (atual) | cartão | R4 B 36 (36:3,11-31); R3 B fr/notas-etiquetas:28 |
| AGE-29 | Bloqueio de horário: único ou semanal, com tipo, título, motivo (atalhos e "Outro (digitar)" até 120 caracteres), Salvar, Excluir, Repetir | pronto (antigo) · pronto (atual) | `_block/TimeBlockPanel` | R4 B 05, 25, 48; R1 B inv:46 |
| AGE-30 | Tipos de bloqueio por estúdio (Indisponível, Reunião, Almoço, Pausa, Formação, Outro; cor, pago) e permissão de reservas online | pronto (antigo); editor de tipos e ligação ao motor público planejados | bloqueio | R4 B 25 (25:15-34, 64-71); R5 B archive/audits |
| AGE-31 | Recorrência de bloqueio: diária, semanal, mensal, até 60 ocorrências; mensal usa dia âncora | pronto (antigo) · sem registro no atual | bloqueio | R4 B 25 (25:36-44); R4 A 25; mapa linha 63 |
| AGE-32 | Seletor de horário de 15 min (botão 24 h, grade, "Digitar o horário") em todo campo de horário da agenda | pronto (antigo) · planejado G7 (atual) | campos de horário | R4 B 48; R3 B fase1:119 |
| AGE-33 | Datas rápidas no calendário: +2, +4, +6 semanas e +3 meses | pronto (antigo) · planejado G7 (atual) | calendário | R4 B 49 (49:25-35); 52:199 |
| AGE-34 | Lista de espera: adicionar, tirar da lista, oferecer o horário por WhatsApp (`agenda_waitlist`) | pronto (antigo) · pronto (atual) | `_waitlist/` | R4 B 40 (40:33-37); R1 B inv:45 |
| AGE-35 | Lista de espera que oferece o horário sozinha quando alguém cancela | planejado P1 (antigo) · planejado (atual); nunca feito | — | R5 B revisao-30-10:26; R3 B falas:108 |
| AGE-36 | Arrastar para remarcar | pronto (antigo) · pronto sem teste (atual) | cartão | R5 B core-delivery:51; R3 B audit:24 |
| AGE-37 | Status "Chegou", número sequencial "#N" por estúdio, "Criado por" e autor no histórico | pronto (antigo); a proposta M7 tira o "Chegou" | cartão, histórico | R4 B 40 (40:22-31); R3 D M7 |
| AGE-38 | Status operacional (Reservado, Agendado, Confirmado, Iniciado, Concluído, Ausência, Cancelado) separado do financeiro (Pago, Pago parcial); matriz de ações por status | planejado na spec 26 · pronto no AGENDA-CORE-02 (antigo); sem registro no atual | domínio | R4 B 26 (26:20-58); R5 B archive/audits/agenda-status-notes-core-02 |
| AGE-39 | Conflito de horário bloqueia (profissional, bloqueio); adjacentes não conflitam; override gerencial exige motivo e fica auditado | pronto (antigo); tela de override fora do escopo | domínio, RPCs | R4 B 23 (23:33-55, 87-93); R5 B scope-master:41 |
| AGE-40 | Visibilidade: `agenda.view_all` × `agenda.view_own` (só a profissional ligada à conta), filtrada no servidor e no banco | pronto (antigo); restrição por papel no restante planejada | acesso | R4 B 40 (40:5-13); R4 B 29, 37 |
| AGE-41 | Lembretes de amanhã: contador no menu, sem envio automático até haver motor de automações | parcial (antigo) | ⋮ da agenda | R4 B 40 (40:44-47); R3 B ag:50 |
| AGE-42 | Recorrência de atendimento (intervalo, data final, escopo "esta e futuras"); hoje só `FREQ;COUNT` e cancelar série ainda atinge ocorrências passadas | parcial (antigo); nada no atual | `_repeat/` | R4 B 24 (24:46,130-144), 23:113, 46:130; R5 B scope-master:193-203 |
| AGE-43 | Atividade do agendamento (linha do tempo por `audit_logs`; ícone no topo do agendamento). Detalhe no AGD-17 | parcial (antigo) · planejado E7·A (atual) | agendamento | R4 B 24 (24:47,118-128); R3 B fechar:275-281, falas:114 |
| AGE-44 | Duração própria por item do atendimento (5 a 720 min); total = soma dos itens; item pago ou cancelado trava | pronto (antigo) | ficha e modal | R4 B 35 (35:12-45, 64-77) |
| AGE-45 | "Incluído no pacote" derivado na leitura; o consumo só acontece ao fechar o checkout | pronto (antigo) | cartão, ficha | R4 B 40 (40:38-42) |
| AGE-46 | Cancelar com sinal numa transação (crédito, devolver ou ficar com o sinal; motivo; idempotente) | pronto (antigo); v26 pede folha própria de cancelar | cancelar | R4 B 40 (40:15-20), 54; R5 B v26-mobile-ux:53-58 |
| AGE-47 | Celular: "Antes do atendimento" em 3 chips (Confirmado, Formulário assinado, Sinal); preparação e atividade em folha à parte; cancelar já pago com devolução | planejado (V26) | celular | R5 B v26-mobile-ux:39-58 |
| AGE-48 | Ficha pendente ao iniciar: janelinha "Abrir ficha" ou "Iniciar mesmo assim" (registrado na Atividade); bloqueio real só se o modelo da ficha bloqueia o início | registrado (antigo, sem prova) · não aplicado (atual) | início do atendimento | R5 A L-1111 (livro); R1 B reg |
| AGE-49 | Avisos do sistema num sininho no topo (G2) | planejado ("item para depois") | topo | R3 B fase1:114; R1 B reg:118 |
| AGE-50 | Google Calendar (mão única primeiro, duas vias só depois de validar) | planejado, não iniciado (antigo) | integrações | R4 B 19; R5 B roadmap:204, product-vision-detail:111-114 |
| AGE-51 | Galeria antes/depois e painel de contexto da cliente (abas Resumo, Alertas, Preferências, Histórico) | planejado, sem dono (antigo, "prioridade nº 1") | agendamento | R5 B core-delivery-control:68, revisao-30-10:24 |
| AGE-52 | Agenda mobile da recepção: lista de ações, desfazer, PWA com push | planejado P1 (antigo) | celular | R5 B revisao-30-10:31 |
| AGE-53 | Faixa de dias que cruza o mês mostra "outubro e novembro" | pronto (antigo, "aceito por clareza") | faixa de dias | R4 A 52 §0 (52:45) |
| AGE-54 | Fora do expediente a partir dos turnos; cancelado fica no histórico mas não aparece na grade nem na contagem do mês | pronto (antigo) | grade | R4 B 05 (05:45-46, 131-146) |
| AGE-55 | Recursos compartilhados, capacidade simultânea e conflitos avançados; restrição de profissional à própria agenda no banco | planejado/adiado (antigo) | — | R4 B 05 (05:153-160), 37:102-103; R5 B roadmap:212 |
| AGE-56 | Estados que faltam desenhar: "Novo ▾" aberto, foco, vazio, carregando, erro, painéis Profissionais e Filtros abertos | planejado (lacuna) | quadro | R3 B ag:131, padrao:174 |
| AGE-57 | Detalhes do celular propostos pelo Claude, sem escolha do dono: ícone e texto do botão "Agenda", contador, ícones do painel, balão do status (pílula escura 12 px), faixa de dia vazio, "Horário de funcionamento" × "Configurações da agenda" | planejado (sem escolha do dono) | celular | R3 B ag:56-63 |
| AGE-58 | Referências de mercado (sem decisão): Booksy (ícones no bloco, modos "Full size" e "Fit to page", esquemas Vivid e Pastel), Treatwell ("£" pré-pago, "!" a pagar, botão No Show), Fresha (Todos os filtros, Configurações do calendário) | referência | — | R5 B; R3 B fr/agenda-agendamento-05-11 |
| AGE-59 | Modal criar/editar atendimento: cliente (busca), profissional, data, hora, duração, status, observações, canal; contexto da cliente (saldo, tier, alerta); Salvar, Salvar como Confirmado, Cancelar | pronto (antigo, scope-master:33); critérios da spec 04 sem marcação | modal do quadro | 04:33-36, 78-94 |
| AGE-60 | Detalhe lateral do atendimento: resumo e ações de status Confirmar, Iniciar, Concluir, Ausência, Cancelar, com alertas da cliente | pronto (antigo, scope-master:36); no atual vira o Agendamento aberto (AGD) | sheet | 04:42-45 |
| AGE-61 | Canal de origem do agendamento: manual, WhatsApp, online, telefone | pronto (antigo) | modal | 04:88 |
| AGE-62 | Visão Mês: sete colunas, contagem e primeiros atendimentos do dia; clicar no dia abre a visão Dia; cancelados fora da contagem | pronto (antigo, incremento 1) | visão Mês | 05:48-53 |
| AGE-63 | Grade de 30 min; Dia com uma coluna por profissional; 3 dias e Semana com uma coluna por data e profissional; fora do turno aparece como "Fora do expediente" | pronto (antigo, incremento 1) | grade | 05:39-44, 80 |
| AGE-64 | Remover só uma ocorrência de bloqueio semanal sem apagar a série; semanal de 2 a 12 ocorrências no primeiro incremento (a spec 25 amplia para 60) | pronto (antigo) | bloqueio | 05:58-59, 69, 77, 138-139 |
| AGE-65 | Permissões por papel: owner, admin, manager e recepção veem tudo e criam e removem bloqueios; profissional vê e cria bloqueios; finance e viewer só leitura | pronto (antigo); restrição de profissional à própria agenda planejada | acesso | 05:22-27 |
| AGE-66 | Estados da tela: carregando (skeleton), período vazio clicável, equipe vazia com botão para cadastrar, salvando, erro inline e toast, celular 390 px com FAB | pronto (antigo) | quadro | 04:111-120; 05:122-129 |
| AGE-67 | Tipos de bloqueio padrão criados para estúdios existentes e futuros; título até 120 caracteres; lock por estúdio e profissional; audit log | pronto (antigo) | bloqueio | 25:46-53 |
| AGE-68 | Motivo do bloqueio: um campo só com lista e "Outro (digitar)"; o tipo é o de nome igual ao motivo; "Mais opções" só com mostrar motivo na agenda, descrição e reservas online | pronto (antigo, entrega 1 do E1) | bloqueio | 48:30-46 |
| AGE-69 | Seletor de horário aceita "1410", "14:10" ou "930"; horário inválido mostra "Use HH:MM, ex.: 14:30" e não é aplicado; popover no computador, folha no celular; alvos de 44 px | pronto (antigo) | campos de horário | 48:14-25, 62 |
| AGE-70 | Menu Adicionar com permissão: sem `agenda.manage` não vê as criações; sem `agenda.block` não vê Bloquear; "Lista de espera" abre o formulário de adicionar | pronto (antigo, E1c) | `AddMenu` | 50:24-29 |
| AGE-71 | Celular: folha da data com Dia, Lista, Semana e atalhos Lista de espera (com contagem) e Configurações; 3 dias e Mês aparecem como lista da semana | pronto (antigo, E1c); semana configurável no celular fica para o E1d | celular | 50:17-19 |
| AGE-72 | Eventos da Atividade por `audit_logs`: criado, alterado, remarcado, status, nota, formulário vinculado, sinal, checkout aberto, pagamento, recorrência criada e alterada, cancelado; sem dado clínico no registro | parcial (antigo, cobertura incompleta) | atividade | 24:118-128, 174 |
| AGE-73 | Recorrência de atendimento (contrato): frequência semanal com intervalo; quantidade ou data final; `recurrence_id`; validar todas as ocorrências antes de gravar; editar só esta, esta e futuras ou a série; preservar pagos | parcial (antigo: criação e edição transacionais; faltam intervalo, data final e escopo) | recorrência | 24:130-144 |
| AGE-74 | Registros append-only de saldo da cliente, pontos de fidelidade, uso de vale e auditoria (base para Clientes, Fidelidade e Financeiro) | pronto (antigo, backend) | banco | 23:57-67 |
| AGE-75 | Operações atômicas no banco: criar e editar atendimento e itens, status com histórico, reagendar, bloquear, cancelar série; lock por horário; datas no fuso do estúdio | pronto (antigo) | banco | 23:69-85; 24:166-173 |
| AGE-76 | Reagendar, ausência e cancelar nunca mostram sucesso quando o servidor recusa | pronto (antigo) | ações do quadro | 23:74; 24:81, 168-169, 184 |
| AGE-77 | Duração do item pela ficha passa por `update_appointment_atomic`: fim que encosta em outro atendimento ou bloqueio avisa; owner, admin e manager podem salvar mesmo assim, registrado nas notas internas | pronto (antigo) | ficha | 35:33-38, 73-74 |
| AGE-78 | Preço e profissional do item: `update_appointment_item_atomic` (audita `APPOINTMENT_ITEM_UPDATED`); item com quantidade diferente de 1 ou com desconto por item não se edita pela ficha | pronto (antigo) | ficha | 35:71-76 |
| AGE-79 | Seletor de duração: passos de 5 min até 4 h e depois de 15 min; itens antigos (`null`) seguem o catálogo; mudar o catálogo não altera agendamentos já feitos | pronto (antigo) | modal, ficha | 35:14-19 |
| AGE-80 | Prévia ao passar o mouse: selos "Pago parcial", "Falta cobrar", "Anamnese pendente", "Recorrente"; também abre com Tab; Esc fecha; sem botões; sem consulta nova | pronto (antigo) | cartão | 36:15-18, 26-28, 38 |
| AGE-81 | Ligação conta × profissional em Equipe › "Conta de acesso"; sem profissional ligada, aviso e agenda vazia | pronto (antigo) | Equipe | 40:12-13 |
| AGE-82 | Cancelar com sinal: modos `credit` (exige `financeiro.manage` e `comanda.operate`), `refund` e `fee`; `cancel_reason`; notas antigas "Cancelado:" continuam lidas | pronto (antigo) | cancelar | 40:17-20 |
| AGE-83 | Lista de espera: cliente, serviço, profissional, janelas; "agendar" liga a entrada ao agendamento criado; oferecer abre o WhatsApp para quem atende enviar | pronto (antigo) | `_waitlist/` | 40:35-37 |
| AGE-84 | "Incluído no pacote" vai do horário mais próximo ao mais distante e só no alcance `agenda.view_all` | pronto (antigo) | cartão | 40:38-42 |
| AGE-85 | Lembretes de amanhã: conta quem está em Reservado ou Agendado e ainda não confirmou; abre o dia de amanhã; o envio é pelo WhatsApp de cada cartão | parcial (antigo) | ⋮ da agenda | 40:46-47 |
| AGE-86 | Domínio de status do antigo: nove valores (Reservado, Agendado, Confirmado, Iniciado, Concluído, Pago Parcial, Pago, Ausência, Cancelado); fluxo Agendado › Confirmado › Iniciado › Concluído › Pago; Cancelado e Ausência terminais | pronto (antigo) | domínio | 04:68-69, 96-98 |
| AGE-87 | Matriz de ações por status: Reservado (confirmar, cancelar, reagendar, ausência); Agendado e Confirmado (iniciar, cancelar, reagendar, ausência, comanda); Iniciado (concluir, cancelar com cautela, comanda); Concluído (ver comanda, recibo, notas); Pago (bloquear alterações críticas); Ausência e Cancelado (histórico, novo atendimento) | planejado na spec 26 ("planned") | domínio | 26:44-58 |
| AGE-88 | Pago e Pago Parcial tratados como estado financeiro; migrar para leitura derivada da comanda, sem migração destrutiva | planejado (antigo) | domínio | 26:37-42 |
| AGE-89 | Períodos fechados (feriado, estúdio fechado), junto com a lista de espera, depois da agenda estável | planejado (antigo; só a lista de espera existe) | agenda | R5 B roadmap:205 |

## Decisões
Colunas: o ID antigo vem em negrito no começo da decisão. "Aceite em lote" = "aceito todas", "Sim" ou "valem".

| ID | Decisão | Situação | Origem |
|---|---|---|---|
| AGE-D01 | **AG1 (nomes)** Nomes do app: Reservado, Confirmado, Chegou, Iniciado, Concluído, Ausência, Cancelado; sem "Faltou" e sem "A confirmar"; joinha no Confirmado | **a confirmar** (antes: vale) ("não é pra usar faltou e a confirmar, já foi resolvido isso no meu entendimento por Reservado, icone de joinha no confirmado, etc...", 20/11/2026) | R1 A.1 reg:39; R3 A; falas:113 |
| AGE-D02 | **AG1 (A)** Status no cartão só com ícone; mapa Reservado relógio âmbar, Confirmado joinha, Chegou porta, Iniciado play, Concluído ✓ verde, Ausência pessoa com x vermelho, Cancelado x cinza | **sugestão a confirmar** (aceite em lote "Minhas escolhas de 19/11 valem", 19/11) | R1 reg:39; R3 A ag:5-6 |
| AGE-D03 | **AG2·A** Resumo do dia em uma linha de texto (o B, blocos, sai) | **sugestão a confirmar** (lote 19/11) | R1 reg:40 |
| AGE-D04 | **AG2·C** Botão que abre o resumo do dia: ideia do dono deixada aberta | **sugestão a confirmar** (em aberto; fora desta entrega) | R1 reg:40; R3 ag:72 |
| AGE-D05 | **AG3·B** Celular: Profissionais só ícone, Lista de espera no ⋮. Substituída pela AG21 (reg:41 não foi marcada "substituída") | **sugestão a confirmar** (lote 19/11; superada) | R1 reg:41, F-15 |
| AGE-D06 | **AG8** Número no Profissionais só quando mostra parte da equipe | **sugestão a confirmar** ("aceitou a recomendação", sem frase) | R1 reg:46 |
| AGE-D07 | **AG9** Botões só ícone: 32 px no computador, 40 px no celular | **sugestão a confirmar** ("aceitou a recomendação", sem frase) | R1 reg:47 |
| AGE-D08 | **AG11·A** "Novo ▾" na barra apertada | **a confirmar** (antes: vale) ("decidido por: AG11·A, AG12·B", 20/11/2026) | R1 reg:48; R3 A; R2 A sem frase no BACKLOG |
| AGE-D09 | **AG12·B** Sem legenda de ícones no pé da Semana | **a confirmar** (antes: vale) (mesma frase, 20/11/2026) | R1 reg:49; R3 A |
| AGE-D10 | **AG13·A** Palavra "reservados" no contador do resumo | **a confirmar** (antes: vale) ("AG13·A, AG14·B, AG15·A - ok.", 20/11/2026: resposta item a item, com uma letra e um desenho para cada; mesma forma de AG11 e AG12) | R1 reg:51; R3 A |
| AGE-D11 | **AG14·B** Semana, 3 dias e Mês com valor previsto e reservados | **a confirmar** (antes: vale) (mesma resposta, 20/11/2026) | R1 reg:52; R3 A |
| AGE-D12 | **AG15·A** € verde = pago, âmbar = falta cobrar | **a confirmar** (antes: vale) (mesma resposta, 20/11/2026) | R1 reg:53; R3 A |
| AGE-D13 | **AGL1 a AGL9** Propostas do Claude (nome do status no teclado, carregando, erro, dia vazio etc.) | **sugestão a confirmar** (não aprovadas; ele pediu "a, b, c" comparados; viraram AG16 a AG19 e a Fase 1) | R1 reg:54 |
| AGE-D14 | **AG16·A (CMP-A4)** Lupa sai da barra do computador; vale a busca global do topo | **a confirmar** (antes: vale) ("icone de lupa atual nas telas deve sair, vamos manter a busca global do topo no desktop", 20/11/2026, 19h24) | R1 reg:55; R3 A ag:21 |
| AGE-D52 | **AG16·A, parte do celular** A lupa fica na barra do celular (separada da AGE-D14) | **sugestão a confirmar** (a frase de 20/11 cobre só o computador; a parte do celular veio do aceite em lote "aceito todas", 22/11, 15h53; proposta E4) | R1 reg:55; fechar-ds E4 |
| AGE-D15 | **AG17·A** Mantém 8 px entre botões e encurta os textos | **sugestão a confirmar** ("aceito todas", 22/11, 15h53, lote) | R1 reg:56 |
| AGE-D16 | **AG18·A** Faixa do resumo com 40 px | **sugestão a confirmar** (sem prova; a spec cita o registro sem trazer frase) | R3 A ag:106; R1 reg:57 |
| AGE-D17 | **AG19·A** Balão do nome do status também no Tab e no toque | **sugestão a confirmar** (lote 22/11) | R1 reg:58 |
| AGE-D18 | **AG20** Um ícone abre o painel de visões e altura das horas; substitui o trilho de textos de CMP-A4 | **a confirmar** (antes: vale) ("o que eu recomendei na verdade foi um ícone, você clica e tem as opções lá de densidade, entendeu? De tamanhos.", 20/11/2026) | R1 reg:59; R3 A; falas:53 |
| AGE-D19 | **AG21** Celular: botão "Agenda" abre folha com visão, altura, profissionais, Filtros, Lista de espera etc. (muda AG3·B) | **a confirmar** (antes: vale) (resposta dele ao AG21, mesmo hesitante: "Não ficou muito claro esse AG21 em termos de texto, mas seria o A teoricamente.", 20/11/2026; a barra em texto é conferida na NAV-D08) | R1 reg:60, F-10; falas:101 |
| AGE-D20 | **AG24·B** Cartões com fundo neutro e faixa em tons próximos (segue CAM1-11) | **sugestão a confirmar** (lote 22/11); tons não definidos | R1 reg:71; R3 ag:49 |
| AGE-D21 | **CAM1-11** Agenda: "cores bem próximas"; agendamento e comanda sem faixas coloridas, só etiqueta pequena | **a confirmar** (antes: vale) ("a questão da agenda, eu entendo, pode ter cores diferentes, mas cores bem próximas…", 20/11/2026) | R1 reg:205; falas:27-28 |
| AGE-D22 | **AG27·A, AGT27** "Bloquear horário" no painel "Agenda" e no ⋮; "Configurações" vira "Configurações da agenda" | **sugestão a confirmar** (lote 22/11) | R1 reg:74, 94 |
| AGE-D23 | **AGT1** Painel de visão: "Altura das horas: Compacta, Normal, Ampla" | **sugestão a confirmar** (lote 22/11) | R1 reg:75 |
| AGE-D24 | **AGT2, AGT5, AGT15, AGT16** ⋮ da agenda: Exportar CSV; Checkouts em aberto também no computador; sai "Altura da grade"; Imprimir e Exportar só no computador | **sugestão a confirmar** (lote 22/11) | R1 reg:76, 79, 86, 87 |
| AGE-D25 | **AGT3** "Abrir ficha da cliente" vira "Ver cliente" no cartão | **sugestão a confirmar** (lote 22/11) | R1 reg:77 |
| AGE-D26 | **AGT4** Dia vazio: "Nenhum atendimento neste dia" e "Novo agendamento" | **sugestão a confirmar** (lote 22/11) | R1 reg:78 |
| AGE-D27 | **AGT6** Celular: resumo do dia numa linha embaixo da faixa de dias | **sugestão a confirmar** (lote 22/11) | R1 reg:80 |
| AGE-D28 | **AGT12, AGT24** Ações do cartão com Tab e botão direito; no celular segurar abre ações e tocar abre o agendamento | **sugestão a confirmar** (lote 22/11) | R1 reg:83, 92 |
| AGE-D29 | **AGT13** Celular: Dia, Lista, Semana no painel "Agenda"; folha da data só calendário | **sugestão a confirmar** (lote 22/11) | R1 reg:84 |
| AGE-D30 | **AGT9, 10, 11, 17, 18, 22, 26** Fora da lista: "resolvidos pela tela de hoje" | **sugestão a confirmar** (sem frase) | R1 reg:109 |
| AGE-D31 | **CMP-A1** Sai a segunda coluna; Equipe vira botão Profissionais; Status vai a Filtros | **sugestão a confirmar** (19/11, sem frase; o repositório não guarda as respostas do comparativo) | R1 reg:249, F-23 |
| AGE-D32 | **CAM4-04** Altura da hora 44/60/84 (computador) e 44/52/64 (celular) | **sugestão a confirmar** (17/11, sem frase) | R1 reg:217 |
| AGE-D33 | **CAM1-07, CMP-B2, CAM6-01, CAM6-02** Dourado só no botão principal; escolhido e hoje em preto | **sugestão a confirmar** (sem frase). O V25 do antigo manda botão escuro e o antigo 45/46 manda bronze | R1 reg:201; R1 F-31 |
| AGE-D34 | **CAM8-02, CAM8-03** Lucide traço 1,75; Filtros com funil | **sugestão a confirmar** (sem frase) | R1 reg:237-238 |
| AGE-D35 | **CMP-E2** "Formulário" no lugar de "Ficha" nos textos | **a confirmar** (antes: vale) (resposta dele "Só o nome por enquanto", 19/11/2026, 10h43, à pergunta E2 escrita por inteiro; vale o nome nos textos; o "Concordo com proposta" de 06/11 é anterior) | R3 A (falas:77, 181); R1 F-1 |
| AGE-D36 | **AG-1111** Decisões de estrutura e visual da Agenda de 11/11 (documento fora do repositório) | **sugestão a confirmar** (sem prova no git) | R1 reg:195, F-20 |
| AGE-D37 | **G2** Avisos do sistema num sininho (item para depois) | **sugestão a confirmar** (lote 22/11) | R1 reg:118; R3 fase1:114 |
| AGE-D38 | **Reprovação dos PRs #123 e #124** da Agenda | **a confirmar** (antes: vale) ("ambas estão longe de cumprir tudo que já foi definido", 23/11/2026) | R2 A BACKLOG item 18 |
| AGE-D39 | **Duas frentes** em branches e prévias separadas | **a confirmar** (antes: vale) ("construir duas frentes em branchs e prévias separadas", 23/11/2026); em construção | R2 A BACKLOG item 18 |
| AGE-D40 | **Pacote de 23/11**: fechar o #123, usar o #124 só como base técnica e construir a partir de imagem das três telas | **sugestão a confirmar** (pergunta aberta, sem resposta registrada) | R1 D own:13 |
| AGE-D41 | **Spec 23** Sobreposição passa a bloquear (substitui o "só avisa" da spec 04); override futuro exige motivo e auditoria | **sugestão a confirmar** ("aprovada pelo responsável do produto", sem frase) | R4 A 23 (23:3-10, 33-55) |
| AGE-D42 | **Spec 25** Bloqueio com tipos e recorrência até 60; sem recorrência infinita | **sugestão a confirmar** ("solicitação direta de 19/06", sem frase) | R4 A 25 (25:3-7, 36-44) |
| AGE-D43 | **Spec 35** Duração própria por item; só `agenda.manage` edita itens; item fechado trava | **sugestão a confirmar** (sem frase) | R4 A 35 |
| AGE-D44 | **Spec 36** Prévia ao passar o mouse, só com mouse, sem dado clínico | **sugestão a confirmar** (sem frase) | R4 A 36 |
| AGE-D45 | **Spec 40** Visibilidade, cancelar com sinal, "Chegou", número sequencial, lista de espera, lembretes manuais | **sugestão a confirmar** (sem frase; implementado em 30/10) | R4 A 40 |
| AGE-D46 | **Specs 48, 49, 50** (04/11) Seletor de horário de 15 min; datas rápidas; visões numa folha; menu "Adicionar" | **sugestão a confirmar** (sem frase) | R4 A 48, 49, 50 |
| AGE-D47 | **Spec 46 (06/11)** Cada ação existe uma vez só ("o dono pediu o padrão do Fresha, sem duplicidade") | **sugestão a confirmar** (parafraseado, sem frase) | R4 A 46 (46:81-85) |
| AGE-D48 | **Vocabulário de status**: o antigo usa Agendado, Check-in, Em atendimento, Faltou; o AG1 usa Reservado, Iniciado, Ausência; a spec 54 troca os rótulos; "Chegou" pode sair (M7) | **sugestão a confirmar** (conflito entre specs 04, 26, 40 e 54; só o dono resolve) | R4 F; R3 F-12; 01-consolidado §4-8 |
| AGE-D49 | **V26 mobile** "Atendimento = Agenda + Comanda"; quem atende não sai da Agenda para pagar, estornar ou cancelar | **sugestão a confirmar** ("feedback de 29/10/2026", sem frase) | R1 A v26-mobile-ux:3-8; R5 A |
| AGE-D50 | **Google Calendar** mão única primeiro, depois duas vias | **sugestão a confirmar** ("recomendação", sem prova) | R5 A product-vision-detail:111-114 |
| AGE-D51 | **Aprovação das specs de Agenda e Agendamento** ("aceito todas" 22/11, 15h53, reconfirmado 22h49: "isso tudo ja tinha sido definido…") | **sugestão a confirmar** (aceite em lote; a reconfirmação de 22h49 não traz resposta nova) | R3 A ag:41; R1 reg:111 |

## Regras de negócio
- Atendimento sobreposto na mesma profissional não é salvo; bloqueio e atendimento também não se sobrepõem; horários colados não conflitam (R4 B 23).
- Item de atendimento pago, pago parcial, cancelado ou ausente não muda (trava no banco) (R4 B 35).
- Cancelar ou marcar ausência com sinal acerta o sinal na mesma transação: ficar, guardar como crédito ou devolver (R4 B 40, 54).
- Série de bloqueio ou de atendimento: editar atinge só as ocorrências em aberto; recorrência de bloqueio tem no máximo 60 ocorrências (R4 B 23, 25).
- Horários seguem o fuso do estúdio; todo atendimento exige cliente, exceto "Sem reserva (balcão)" na tela nova (R4 B 23; AGD-38).
- Quem só tem `agenda.view_own` vê só a própria agenda; o filtro é no servidor e no banco (R4 B 40).
- Ação que ainda não funciona fica visível e desligada ("em desenvolvimento"); ação sem permissão some (G9, AGS5). A spec 24 do antigo mandava não exibir ação sem função: regra em conflito (R3 F-5; R4 F).
- A prévia ao passar o mouse nunca mostra dado clínico (R4 B 36).
- Nada só no mouse: o que aparece no mouse aparece também no foco do teclado (CAM9-03) (R3 B agd:66).
- Cancelado não aparece na grade nem na contagem do mês (R4 B 05).
- "Lembretes de amanhã" só contam; não enviam nada até haver motor de automações (R4 B 40).
- Novo agendamento e bloqueio começam e terminam no mesmo dia (primeira fase) (04:66; 05:74).
- Cancelar atualiza o status para Cancelado; nunca há exclusão física (05:78; 24:82).
- Pago é estado financeiro e não substitui Concluído (05:79; 24:95).
- Status vindos do navegador precisam estar no conjunto canônico; salto inválido é recusado; Cancelado, Ausência e Pago são terminais; status e histórico gravam na mesma transação (23:35-40).
- O Fresha deixa agendar sobre um bloqueio; aqui fica mais restrito até existir override auditado, que exigirá papel gerencial e motivo (23:52-55).
- Registros de saldo, pontos, vales e auditoria só se acrescentam, com `org_id` e RLS (23:59-67).
- Todo acesso usa `org_id`; ids vindos do cliente nunca são confiados; as ações devolvem só sucesso ou erro (05:81, 120).
- Bloqueio: início antes do fim; título até 120 e nota até 255 caracteres; tipo e profissional ativos da mesma organização (25:49-51).
- Recorrência de bloqueio: 1 a 60 ocorrências; recorrentes pedem ao menos 2; o horário local vale nas mudanças de horário de verão (25:39-44).
- Série de atendimentos: validar todas as ocorrências antes de gravar; preservar pagos e cancelados; override de conflito só com papel gerencial (24:136-144).
- Duração do item vai de 5 a 720 min, muda o fim e não o início; o total é a soma dos preços dos itens (35:14-25).
- Só `agenda.manage` edita itens; a escrita no banco é só de owner, admin, manager e recepção (35:66-70).
- Cancelar com sinal em crédito exige `financeiro.manage` e `comanda.operate`; devolver exige `comanda.operate`; repetir não duplica o crédito (40:18-20).
- Número do agendamento e quem criou não mudam depois (40:30-31).
- "Incluído no pacote" não consome sessão; o consumo é só no fechamento da comanda (40:40-41).
- Datas rápidas partem do dia em que a tela abriu (ao criar) ou da data atual do agendamento (ao remarcar); "+3 meses" cai no último dia do mês curto (49:30-34).
- Resumo da cliente chega junto da leitura do agendamento; sem consultas em sequência; índices por `org_id`, `staff_id` e `start_at` (24:179-185).

## Pendências e perguntas
| Pergunta ou pendência | Origem |
|---|---|
| "Previstos" no resumo inclui a Ausência? (recomenda tirar) | R1 D own:55 |
| Detalhes do celular sem decisão (AGE-57): ícone e texto do botão "Agenda", balão, dia vazio | R1 D own:57; R3 ag:56-63 |
| Qual versão vira base da Agenda: abertos #123, #124, #126, #129 e 5 branches de versão; teto de 3 PRs | 01-consolidado §4-4; R6 F |
| "Faltam 3 correções" (CHANGELOG) × "7 correções" (BACKLOG) da Agenda | R2 F-12 |
| Valores dos "tons próximos" do cartão (AG24·B) não definidos | R3 ag:49; R1 reg:93 |
| AG20 contestado: o código mostra "Dia ▾" em texto; o registro fala de um ícone | R3 F-8; padrao:154 |
| O dono reclamou em 23/11 que o celular só mostra lista e não cartões; o V26 propõe visão Lista. Qual vale? | falas:139; R5 B v26-mobile-ux:27 |
| Joinha no Confirmado e ícone de histórico no topo "já decididos", não aplicados (23/11, 11h16) | falas:114 |
| Vocabulário de status e "Chegou" (AGE-D48) | 01-consolidado §4-8 |
| Filtros avançados e filtros salvos: confirmar quais já existem no código | R1 inv:26 × R3 opm:122 |
| Altura do rodapé: 40 px (AG2) × 48 px (quadro AG12) em Semana | R3 ag:128 |
| Teste de recorrência, arrastar, bloqueio, espera e sinal sem E2E | R3 B audit:24 |
| Tela de override gerencial de conflito não existe | R4 B 23:87-93 |
| Contraste do âmbar e do vermelho no cartão (informação: 5,1 a 6,5 : 1 no tema claro) | R3 ag:134 |
| Mapeamento das cores de status do V3 antigo para o V25 e o design system atual | R5 F |
| A matriz de status e ações da spec 26 ainda está "planned" e sem confirmação de que foi entregue | R4 F; 26:3, 126-134 |
| `cancel_recurrence_series_atomic` ainda cancela ocorrências passadas e iniciadas | 23:113 |
| Editar "só esta", "esta e futuras" ou a série inteira ainda não existe | 24:46, 139 |
| A Atividade ainda não consolida todos os eventos de `audit_logs` | 24:47, 174 |
| Ordem restante do antigo: REL-ANA-05 (gate clínico unificado), CORE-AGD-UX, CORE-E2E-01, CORE-PERF-01 e P2 (grupos, mensagens, teste de contato) | 24:197-203 |
| E2E exigidos no antigo (reagendar, ausência, recorrência esta/futuras/série, anamnese, checkout parcial) sem registro no atual | 24:187-195 |
| Restrição automática de profissional ao próprio `staff_id` ainda planejada | 04:106; 05:26, 159 |
| Horário de início por item e tempo de processamento dentro do serviço ficaram fora; a comanda não edita duração | 35:52-56 |
| Semana em grade configurável no celular, filtros, "Criado em" e toque em horário vazio no celular ficaram para o E1d | 50:3-5, 18-19; 49:4 |
| Campos de horário de Ajustes e do Caixa seguem com o campo do navegador | 48:27-28 |
| A spec 04 diz que a sobreposição só avisa; a spec 23 diz que bloqueia (vale a 23) | 04:67; 23:48-50 |
| Critérios de aceite das specs 04, 05, 48, 49 e 50 sem marcação de cumprido | 04:124-132; 05:131-145; 48:60-64; 49:37-43; 50:36-43 |
| CAM10-AGE-01: Agenda reprovada pelo dono em 19/11, 00h17; o print não está no git | R1 D reg:31 |
| Validação do dono depois do deploy, pela lista de verificação da spec 50 (visões e menu Adicionar) | legado spec 50:45-49 (R4 D) |
| Migration `agenda_status_notes_core_02` do antigo não validada no remoto na entrega (histórico) | R5 D agenda-status-notes-core-02-2026-06-19:62,104 |

## Referências
- Specs atuais: `docs/specs/screens/agenda.md`; plano `docs/specs/plans/2026-11-23-padrao-agenda-e-agendamento.md`; inventário `docs/design/inventario/agenda-e-agendamento.md`; registro `docs/decisoes/historico/registro-ate-2026-11-24.md` (AG*, AGT*, CAM*, CMP*).
- Canvas: https://claude.ai/artifact/7FMM8AKnUTuVtjB54wcGhP (quadros "Agenda · 1440", "Agenda · 390", "Lacunas da Agenda").
- Specs do legado: `docs/produto/legado/specs/` 04, 05, 23, 24, 25, 26, 35, 36, 40, 46, 48, 49, 50; `docs/produto/legado/produto/agenda-operational-scope.md`, `scope-master.md`, `roadmap.md`, `revisao-30-10.md`.
- Prints do Fresha (referência, não decisão): `docs/fresha-prints-referencia/01-agenda` e `agenda-agendamento-05-11`; Booksy e Treatwell em `docs/referencias-mercado/`.
- Relatórios: `docs/reorganizacao/levantamento/R1` a `R5`; mapa `docs/reorganizacao/02-mapa-de-modulos.md`; regra do dono de 23/11 em `docs/reorganizacao/03-decisoes.md` (Q1).

Regra: só vale decisão registrada em `docs/decisoes/` (molde de pergunta). Tudo desta tabela é **a confirmar**; a situação antiga fica entre parênteses só como histórico e volta a ser perguntada quando o módulo for trabalhado (resposta 15a do dono, 24/11/2026).
