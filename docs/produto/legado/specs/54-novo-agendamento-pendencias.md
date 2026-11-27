# 54 — Novo agendamento: itens sem função ("em desenvolvimento") e pendências

Atualizado em: 2026-11-06 12:18 (Paris)

Lista "para depois" do Novo agendamento aprovado em 05/11 (spec 52 §0). Regra: o que já tem função no app fica
funcionando; o que não tem aparece como no desenho aprovado, **desabilitado com a etiqueta "em desenvolvimento"**
(`SoonTag` no design system). Nada aqui inventa função nem tabela nova. "Existe função?" foi conferido no código em 06/11.

Estado: rodada A (moldura, passos 1 a 3) e rodada B (Revisão, menus, passo 1 sem Continuar) prontas.

## A. Itens com a etiqueta "em desenvolvimento" na tela

| Item | Onde aparece | Existe função? | O que falta |
|------|--------------|----------------|-------------|
| **Enviar link da anamnese** | Menu Avisos e sinal | Parcial: a ficha é gerada por `createAnamneseLinkAction` (`AnamneseSheet`) a partir de um agendamento **já salvo**; antes de salvar não há agendamento | Decidir: enviar ao salvar (opção no salvar) ou só depois de salvo |
| **Enviar ficha de anamnese** | Menu Ações rápidas ⋮ | Igual ao anterior | Igual ao anterior |
| **Agendamento em grupo** | Menu Ações rápidas ⋮ | Não | Spec e modelo de agendamento com várias clientes |
| **Nova reserva** | Menu Ações rápidas ⋮ | Não existe no guia (a spec 52 dizia "Nova reserva não existe no guia") | Definir o que é (reserva sem cliente? spec 53) |
| **Adicionar alergia** | Menu Ações do cliente | Parcial: `updateClientAlertAction` (módulo Clientes) grava `alert_type = allergy`, o guia não a chama | Ligar a ação (campo do texto da alergia) ao menu |
| **Adicionar tag** | Menu Ações do cliente | Não há etiquetas livres da cliente (só filtros e `alert_type`) | Modelo de tags de cliente |
| **Bloquear cliente** | Menu Ações do cliente | Parcial: `ClientBlockDialog` existe no perfil (`clientes/[clientId]`), não no guia | Reaproveitar o diálogo no menu |
| **Excluir cliente** | Menu Ações do cliente | Não: só existe arquivar (`archiveClientsAction`); excluir perde histórico | Política de exclusão (LGPD) antes de qualquer botão |

## B. O que o desenho mostra e ficou de fora (sem dado ou sem função)

| Item | Onde aparece no desenho | Por que ficou de fora | O que falta |
|------|-------------------------|-----------------------|-------------|
| **Idioma** da cliente ("Português (BR)") | Coluna da cliente, Revisão | A tabela `clients` não guarda idioma | Campo de idioma na cliente |
| **"Anamnese vence em n dias"** | Coluna da cliente / aviso da Revisão | O banco não guarda validade da ficha assinada. Hoje o aviso mostra **"Anamnese pendente"** quando algum serviço pede a ficha e a cliente não assinou | Validade da ficha (por modelo) para calcular "vence em" |
| **Pacote "2 de 5 sessões · até 20 dez"** | Aviso de pacote | Só se conhece as sessões **livres** (`available`) e a validade; o total de sessões não vem no cartão da cliente | Levar o total de sessões ao `ClientPackageCard` |
| **Etiqueta "1 agend. sem retorno"** | Coluna da cliente | Não há regra de "sem retorno" | Regra de retorno (spec 53) |
| **Lembrete 24 h ligar/desligar por agendamento** | Menu Avisos e sinal | O lembrete é automático (Mensagens › Automações) e não tem opção por agendamento: aparece **ligado e sem poder desligar** | Opção por agendamento no modelo |
| **Aba Produtos** vendendo produto | Passo 2 e "+ Produto" da Revisão | Produto entra no checkout (regra do banco): a aba e o botão avisam isso | Mudar a regra do banco |
| **Pacote "5 × 45 min · validade 90 dias"** no texto da linha | Passo 2 | `service_bundles` é um conjunto de serviços com preço; a linha mostra "n serviços · duração" | Venda de pacote de sessões (`client_packages`) pelo guia |
| **Valor "a definir"** (serviço sem preço) | Passo 2 | O catálogo não tem o estado "valor definido pela profissional" | Campo no catálogo e total com valor aberto |
| **Ver atividade, Remarcar, Ausência, Cancelar** | Ações rápidas ⋮ | Só existem no agendamento já salvo; o menu traz só a nota | Nada (não construir agora) |

## C. Itens que já funcionam (sem etiqueta)

Editar dados do cliente (perfil `?editar=1`, outra aba), Enviar WhatsApp, Ligar (Ver cliente e Trocar cliente saíram do menu em 06/11: são o botão Ver perfil e o link Trocar cliente), Ver perfil,
Adicionar observação, Ajustar avisos e sinal, Repetir agendamento, Descartar agendamento, Pedir confirmação (WhatsApp ao
salvar), sinal em € ou % (abre o registro do sinal com o valor), + Serviço, + Pacote, + Produto (aviso), lista de espera.

## Diferenças do desenho aprovado (rodada B)

- **Continuar dentro do cartão da cliente no passo 1**: só aparece quando a pessoa volta ao passo 1 com a cliente já escolhida
  (o rodapé segue só com Total e Cancelar). Sem ele não haveria caminho de ida.
- **Ligar** no menu Ações do cliente: não está no desenho, mas já existia no menu antigo (não regredir).
- **Menu Ações do cliente** abre logo abaixo do botão Ações (no desenho aprovado ele aparece mais abaixo na coluna).
- **Rótulos do passo 1 já escolhido** (cartão): mantém o menu Ações antigo (WhatsApp e Ligar), pois é um estado fora do desenho.
- **Barra de cor dos serviços**: usa a cor da profissional (o desenho mostra sempre verde).
- **Enviar ficha de anamnese** (⋮) aparece com a etiqueta (o desenho não a traz); idem **Enviar link da anamnese**.
- **Digitação do minuto exato** ("Outro horário") e o aviso de disponibilidade existem (spec 52 §6) mas não estão no desenho.
- "Rascunho" no cabeçalho e o subtítulo com a faixa de horário no celular saíram (o cabeçalho aprovado não os traz).
- Mês da faixa de dias: "outubro e novembro" quando cruza o mês (aceito pelo dono).
- ~~**Aviso azul de pacote no passo 2**~~: **removido em 06/11** (comentário do dono: pacote e anamnese não aparecem nesta etapa). Fica a marca
  "Incluído no pacote" na linha do serviço e o aviso de pacote na Revisão.
- **Cartão "Serviços" no celular, passo 3**: o desenho aprovado o mostra com horários (m4) e só o omite no desenho do estado sem vagas (m4b);
  o guia mostra nos dois estados (consistência com m4). Se o dono quiser igual ao m4b, é um ajuste de uma linha em `NewAppointmentScreen.tsx`.
- **Texto repetido de WhatsApp e Ligar** em `ReviewMenus.tsx` e `ClientAside.ClientActions` (mesmo comportamento do menu antigo):
  extrair para `_lib/links` fica para uma limpeza futura (sugestão 12 da revisão).
- **Título do passo 4**: "Revisão" (cabeçalho "Passo 4 de 4 · Revisão"), como no desenho. ~~Revisão e salvar~~ (corrigido em 06/11).

## Leitura do cartão da cliente por permissão (06/11)

`getClientCardAction` devolve e-mail, aniversário, pontos, "cliente desde" e os últimos serviços (`recent`) **só** a quem tem
`agenda.view_all` ou `agenda.manage`. Quem só tem `agenda.view_own` recebe o cartão básico (nome, telefone, saldo, alertas,
anamnese, primeira visita) e a tela omite o que falta (a coluna da cliente não mostra aniversário, pontos nem "cliente desde"; o
passo 2 não mostra "Reservado recentemente"). Os pacotes continuam só para `agenda.view_all`. Vitest:
`board-actions.client-card.test.ts`.

## Horários que já passaram e busca da próxima data (06/11)

- Hoje, no passo "Quando", os horários antes de agora (fuso do estúdio) aparecem riscados e desabilitados; dia anterior a hoje fica
  todo riscado; dia futuro não muda. Regra pura `slotCutoff` + `slotGrid(..., notBefore)` em `src/domain/agenda-slots.ts`, com "agora"
  injetado (`useSlotClock`; a prévia fixa 27 out 12:40). O horário digitado em "Outro horário" não passa por esse corte.
- "Próxima data disponível" olha no máximo 14 dias (`NEXT_DATE_LIMIT`, antes 60) e é cancelada ao fechar o passo ou trocar dia,
  profissional ou duração (`AbortSignal`: a busca para antes da próxima leitura).

## Menus e janelinhas nunca saem da tela (06/11)

Defeito relatado: o botão **Ajustar** da Revisão "comia" um pedaço de baixo com zoom 125 % (menu passava 42 px da tela).
Causa: cada menu tinha a sua própria conta de posição. Agora há **uma regra só** em `src/design-system/floating.ts`
(`placeFloating` + `useFloatingPlacement`), usada por Popover da agenda, AnchoredPanel do guia, ActionMenu, FloatingMenu e AnchoredPopover de clientes:

- abre do lado do botão em que cabe (para baixo ou para cima) e troca de lado só se o outro comportar mais;
- a altura máxima é o espaço que sobra; se a tela é curta, o menu rola por dentro;
- nunca passa das bordas laterais (folga de 8 px) e acompanha rolagem, redimensionamento e zoom;
- dentro de painel/diálogo nasce no próprio painel (mantém o foco do Radix); fora, no `body`.

Guarda: `e2e/telas-seguras.spec.ts` abre cada menu em 9 tamanhos (1440×900 até 683×384 de zoom 200 %, celulares 390/360/320 e deitado 844×390)
e confere que menu, rodapé e botão cabem na tela e que a página não ganha rolagem lateral. No código antigo o teste falha em 1093×614 (656 > 614).

## Atendimento padronizado (07/11): etapas no menu, um cartão da cliente, checkout sem repetições

Aprovado pelo dono nas notas do mockup "PROPOSTA · Atendimento e comanda" (D1 a D3):
- **Etapas só no menu de status do cabeçalho** (como no Fresha): Pendente, Cliente confirmou, Check-in, Em atendimento, Concluído, Faltou, cada uma com frase curta. O rodapé do agendamento **não tem** botão de etapa (Confirmar, Marcar chegada, Iniciar): só ⋮, Pagar agora (se falta pagar) e Checkout, **liberado em qualquer etapa**. Cancelado/faltou: Agendar de novo. As regras de troca de status (`appointment-status.ts`) não mudaram.
- **Um cartão da cliente** (`ClientPanel`/`ClientActionRow`) no agendamento novo, no agendamento feito e no checkout (216 px no computador). No checkout "Trocar cliente" fica no menu Ações e "Ver agendamento" é link ao lado do título. Saiu o seletor de status do checkout (rótulo) e o "Salvar rascunho" do rodapé (fica no ⋮; no rodapé só quando o checkout está bloqueado).
- **Lápis e lixeira** ao passar o mouse na linha de serviço do agendamento (computador); celular mantém o ⋮ da linha.
- **Tela curta**: em altura < 520 px o checkout (Revisar) rola por inteiro e o rodapé vem no fim. `e2e/telas-seguras.spec.ts` agora cobre Revisar e Pagar em 9 tamanhos.
- **Pendente de decisão do dono** (mockup "PROPOSTA 2"): etapas configuráveis por empresa (liga/desliga e nomes) em Ajustes › Atendimento. Não implementado.

## P1 · Menu de status igual ao Fresha (aprovado 07/11)

- Menu do cabeçalho com 5 itens, cada um com **ícone e só o nome**, sem legenda: Reservado, Confirmado, Iniciado, Ausência, Cancelar. "Concluído" sai do menu (conclui-se pelo checkout). Legendas/descrições passam a ser escritas pela empresa em Ajustes › Atendimento (mockup P4; não implementado).
- Cancelar deixa o ⋮ e fica no menu de status; abre o mesmo `CancelDialog`. Só habilitado quando `canManage` e o plano de cancelamento permite.
- Iniciado continua bloqueado enquanto a ficha estiver pendente. Rótulos antigos (Agendado, Check-in, Em atendimento, Faltou) trocados em quadro, perfil e histórico.
- Ausência com sinal (guardar/crédito/estorno) é a proposta P2: ainda não implementada.

## P2 · Ausência e Cancelar com sinal (aprovado 07/11)

- "Ausência" no menu de status abre a folha "Registrar ausência de {cliente}?". Com sinal confirmado, pergunta o destino: **Ficar com o sinal** (padrão, vira receita), **Guardar como crédito** ou **Estornar sinal**. Sem sinal, só confirma ("não lança nada no caixa"). Aviso pelo WhatsApp opcional.
- Banco: `mark_absent_settle_deposit_atomic` (migration 20261107230000) marca a ausência e acerta o sinal numa transação, com histórico e auditoria; repetir só acerta o sinal pendente.
- Cancelar: a opção de devolver o sinal chama-se **Estornar sinal**; com pagamento, "Estornar no caixa" e o botão "Cancelar e estornar {valor}".
- Menus (status e ⋮) com o respiro aprovado: 8 px de margem, linha só entre grupos, item atual com fundo dourado claro.

## P5 e P6 · Respiro no Novo agendamento e no Agendamento feito (aprovado 07/11)

- Mesma regra do mockup: letra pequena e espaço entre os blocos (24 px entre grupos, 12 px entre itens), separação por espaço e não por linhas.
- Agendamento feito: coluna da cliente com fundo claro e notas em blocos (título em negrito); serviços com barra à esquerda e sem traços; Observação e Histórico em linhas soltas; cartão da cliente no celular com avatar à direita.
- Novo agendamento: listas de clientes e serviços sem traços (serviço marcado com fundo claro), corpo com 24 px entre os blocos, Revisão com serviços em barra.
- Conteúdo, passos e regras iguais ao que estava no ar.

## Checkout (no ar 3) · respiro, gorjeta como no Fresha e janela no computador (aprovado 07/11)

- **Janela no computador (≥ 1100 px):** o checkout abre como janela larga (até 1240 px) à direita; a agenda fica visível,
  esmaecida, à esquerda. O ✕ fica flutuando fora da janela, no canto de cima à esquerda. No celular continua tela cheia.
- **Etapas no topo:** "Revisar › Pagar" em texto; em telas de até 360 px só aparece a etapa atual.
- **Gorjeta como no Fresha:** duas opções, "Sem gorjeta" e "Gorjeta personalizada". A personalizada abre o seletor
  **% | €** e o valor, com a conta "= X para {profissional}". Fica no menu ⋮ do checkout ("Adicionar gorjeta"), junto de
  "Aplicar desconto" e "Adicionar taxa de serviço"; abre a janela "Adicionar gorjeta" com o botão "Adicionar X".
- **Celular:** Desconto, Gorjeta e Taxa saem da lista da Revisão e vão para o ⋮ (sem repetição). Observações do checkout,
  crédito e "Ao concluir esta venda" aparecem também no celular.
- **Respiro:** itens sem linhas divisórias, barra lateral de 3 px na cor da profissional, títulos 13 px; cartão da cliente
  no celular com a foto à direita e a ficha como ícone (assinada ou pendente); notas da cliente como blocos com título.
- **Pagar no computador:** o ⋮ também aparece ao lado de "Voltar".

## P4 · Ajustes › Atendimento: etapas, nomes e gorjeta (aprovado 07/11)

- **Onde:** Ajustes › Atendimento (quem tem `ajustes.manage`). Grava em `organizations.settings.attendance` pela função
  `set_attendance_settings` (migração `20261108000000_attendance_settings.sql`), com registro no histórico de auditoria.
- **Etapas do menu:** Reservado é fixa; Confirmado e Iniciado têm chave. Desligada, a etapa some do menu de status e nada
  fica travado. A etapa atual sempre aparece marcada, mesmo desligada (agendamentos antigos).
- **Nome e descrição:** cada etapa tem o nome escrito pela empresa (até 20 letras, vale no menu e no botão de status) e uma
  descrição só para a equipe (até 120). Vazio = nome padrão do Fresha.
- **Sempre no menu:** Ausência e Cancelar. **Concluído** é automático ao receber o pagamento.
- **Regras:** "Separar chegada e início" traz a etapa **Chegou** (entre Confirmado e Iniciado). "Exigir ficha assinada ao
  iniciar" é a mesma trava de Ajustes › Ficha de saúde. "Exigir uma etapa antes do checkout": o Checkout avisa "Marque
  Iniciado (ou Chegou) no status antes do checkout"; se a empresa não usa nem Iniciado nem Chegou, nada trava.
- **Gorjeta:** Desligada (some do ⋮ e dos ajustes), No menu ⋮ (padrão, como já funcionava) ou Passo próprio
  (Revisar › Gorjeta › Pagar, tela "Selecionar gorjeta" com as mesmas opções e o total atualizado ao lado).
- **À direita:** "Como o menu fica", a prévia do menu com as escolhas.
- **Sem a migração no banco:** o menu e o checkout usam o padrão (tudo como antes) e salvar mostra um aviso amigável.
