# 52 — Agenda: Guia de agendamento (passo a passo obrigatório)

Atualizado em: 2026-11-06 00:36 (Paris)

Origem: decisão A8 (04/11/2026) e a cobrança do dono: "vc criou um resumo do guia e não um passo a passo
levando o usuário pro caminho que deve seguir obrigatoriamente para criar um agendamento guiado e correto.
O guia não é uma coisinha bonitinha, o nome é claro, GUIA."

Substitui a tela de "Novo agendamento" da spec 49 (seções + bloco Resumo). Mantém da spec 49: a mesma ordem
nos dois tamanhos, as datas rápidas (E1b), o "o que falta" explícito e o rodapé com Total.

## 0. Novo agendamento aprovado (05/11/2026): o que mudou nesta spec

Fonte: telas aprovadas pelo dono (painel lateral `desktop-pn-*` 1440x900 e tela cheia `mobile-m*` 390x844) e o fluxo
Fresha de referência (`docs/fresha-prints-referencia/02-agendamento-novo`, só referência). Esta seção **substitui** o que a ela se opõe
mais abaixo; o histórico fica, marcado como **substituído**.

- **4 passos** (3 com o horário vindo da agenda): **Cliente, Serviços, Quando, Revisão**. ~~5 passos~~. O título do passo 4 é **"Revisão"** (cabeçalho "Passo 4 de 4 · Revisão", como no desenho aprovado); ~~Revisão e salvar~~ (substituído em 06/11).
- **"Avisos" deixa de ser passo**: vira o menu **"Avisos e sinal"** dentro da Revisão (pronto; o antigo `StepNotices` foi apagado
  e a lógica está em `useNotices`, `NoticesPanel` e `ReviewLayer`). ~~O cartão de avisos continua dentro da Revisão atual~~ (substituído em 06/11).
- **"Quando" volta a ser o 3º passo**, antes da Revisão (~~Avisos antes de Quando~~; a pendência do dono sobre a
  ordem Avisos/Quando (§8.2) fica **resolvida**: Avisos sai da lista de passos).
- **Computador (≥ 1024 px)**: o guia abre como **painel lateral de ~680 px** sobre a agenda (agenda e menu do app
  visíveis atrás, com leve escurecimento), com **Expandir** (tela cheia) e **Fechar**. Cabeçalho: "Novo agendamento",
  "Passo n de 4 · <título> · <dia> · <profissional>" e 4 segmentos de progresso. Passo 1 em coluna única; passos 2 a 4
  com a coluna da cliente de **216 px** à esquerda e o passo à direita; rodapé com Total e botões. ~~Tela cheia fixa~~.
- **Celular (390 px)**: tela cheia (fechar no passo 1, voltar nos demais; título do passo e "Novo agendamento · passo n de 4"),
  com cartões "Cliente" e "Serviços" com **Editar** acima do passo. Alvos de toque ≥ 40 px.
- **Passo 1 Cliente**: busca "Nome ou telefone", **Cadastrar cliente**, **Sem reserva (balcão)** (mantém o comportamento
  de "Sem cadastro": cliente rápida), "Sugeridas para este horário".
- **Passo 2 Serviços e produtos**: busca; "Reservado recentemente" (2 últimos serviços da cliente); abas Todos, Serviços,
  Pacotes, Produtos; lista com **caixas de seleção (vários serviços)**, duração e preço; o pacote aparece na mesma lista
  (etiqueta "Pacote") e o preço entra no total; rodapé "n serviços · duração" + Total. Produtos entram no checkout (regra
  do banco): a aba existe e avisa isso (ver `54-novo-agendamento-pendencias.md`).
- **Passo 3 Quando**: seletor de profissional, "Escolha no calendário" (com as datas rápidas), faixa de 7 dias (dias sem
  expediente em cinza), grade de horários (riscados = ocupados) com a duração do agendamento, digitação do minuto exato
  ("Outro horário") e **estado sem vagas**: "<prof> não tem horários disponíveis nesta data", "Disponível a partir de
  <data>", **Próxima data disponível**, **Verificar todos os profissionais** e o link "entrar na lista de espera" (a lista
  que já existe no app); Continuar desabilitado.
- **Passo 1 sem "Continuar"** (aprovado): o rodapé mostra só **Total** e **Cancelar**, nos dois tamanhos. Escolher uma
  cliente da lista, cadastrar (Usar esta cliente) ou **Sem reserva** avança **direto ao passo 2**
  (`hasContinueButton`, `advanceAfterClient`). Quem volta ao passo 1 com a cliente já escolhida vê o cartão dela com um
  "Continuar" no próprio cartão (para não ficar sem caminho de ida) e "Trocar cliente". ~~Continuar desabilitado no passo 1~~.
- **Abas do passo 2** (Todos, Serviços, Pacotes, Produtos): a aba ativa em fundo escuro e texto claro (`Chip tone="dark"`).
- **Faixa de dias**: quando cruza o mês mostra "outubro e novembro" (aceito pelo dono, por clareza).
- **Passo 4 Revisão** (aprovado): cartão/faixa de **data e hora com Alterar** (leva ao passo Quando); **Serviços** em
  sequência (barra de cor da profissional, hora, duração, "1×", profissional, preço) com **+ Serviço, + Pacote, + Produto**
  (produto avisa que entra no checkout); cartão **Avisos e sinal** com **Ajustar**; **+ Adicionar observação** (só no
  computador; no celular a observação entra pelo menu ⋮); coluna da cliente com aniversário, pontos, "cliente desde" e os
  avisos de anamnese pendente e de pacote com sessões livres (o que o banco já tem; idioma e "anamnese vence em n dias" ficam
  de fora, ver spec 54); rodapé com **Total, Sinal agora, A pagar no atendimento**, **⋮**, **Voltar** e **Salvar agendamento**
  (celular: "Total · sinal x" + total, ⋮ e "Salvar"). Mantidos: "O que falta" por passo, Repetir (pelo menu ⋮), erro do servidor e
  "Salvar mesmo assim". Regras puras em `src/domain/agenda-review.ts`.
- **Menu Avisos e sinal** (popover de 340 px no computador, painel de baixo no celular): Lembrete pelo WhatsApp (24 h antes;
  automático, aparece ligado e sem opção de desligar), Pedir confirmação (a de antes: abre o WhatsApp ao salvar), Enviar link
  da anamnese (desabilitado, "em desenvolvimento") e **Cobrar sinal** com campo em **€ ou %** (`SegmentedControl unit`), texto
  "Equivale a x % do total. Muda só neste agendamento." e **Concluído**. O sinal liga sozinho quando o catálogo pede e o campo nasce com o
  valor sugerido. O valor em € chega ao salvar como `valor=` do registro do sinal (`acao=sinal`); valor inválido (acima do
  total, texto) bloqueia o salvar com "Corrija o sinal para salvar" (`depositForSave`).
- **Menu Ações do cliente** (computador: coluna, celular: cartão; 06/11: **sem** Ver cliente e **sem** Trocar cliente, que já são o botão Ver perfil e o link Trocar cliente): **funcionam** Editar dados do cliente (perfil
  `?editar=1`), Enviar WhatsApp e Ligar (Ligar não está no desenho, fica para não regredir); **em
  desenvolvimento** Adicionar alergia, Adicionar tag, Bloquear cliente, Excluir cliente.
- **Menu Ações rápidas ⋮**: **funcionam** Adicionar observação, Ajustar avisos e sinal, Repetir agendamento (folha de repetição) e
  Descartar agendamento (pergunta antes); **em desenvolvimento** Enviar ficha de anamnese (precisa de agendamento salvo),
  Agendamento em grupo, Nova reserva; nota "Depois de salvo, este menu também mostra: Ver atividade, Remarcar, Ausência e Cancelar."
  Componentes do DS: `AnchoredPanel`, `ActionList`, `SoonTag` (etiqueta "em desenvolvimento").

## 1. Objetivo

Levar quem agenda por um caminho de **4 passos** (~~5 passos~~, ver §0), **em ordem obrigatória**, até um agendamento completo e correto.
Só o passo atual é editável; não existe tela única com tudo aberto.

## 2. Passos (nesta ordem)

| # | Título | O que a pessoa faz | Válido quando |
|---|--------|--------------------|---------------|
| 1 | Cliente | Escolhe uma cliente existente, cadastra uma nova (nome + telefone) ou usa "Sem reserva (balcão)" | há cliente escolhida |
| 2 | Serviços | Marca serviços (ou pacotes) do catálogo, com busca, recentes e abas; vê o pacote da cliente que cobre o serviço | pelo menos 1 serviço |
| 3 | Quando (só em Novo agendamento sem horário) | Profissional, dia (faixa de 7 dias, calendário e datas rápidas) e horário (grade ou digitação do minuto exato) | data, horário `HH:MM` válido e profissional |
| 4 | Revisão | Conferência, **Avisos e sinal** (menu), observações, repetição e **Salvar agendamento** | cliente, serviços e "Quando" válidos e repetição válida |

> **Substituído (histórico, até 05/11 18:44):** eram 5 passos, Cliente, Serviços, **Avisos**, Quando, Revisão
> (4 sem "Quando"). Avisos era o 3º passo e vinha **antes** de "Quando". Desde 05/11 23:09 Avisos não é passo.

**Regra de entrada (decisão do dono, §8.2), atualizada:** a lista de passos depende de como o guia foi aberto.

- **Clique direto num horário ou dia da agenda** (`initial.fromSlot`, vindo de `hora=` na rota): data, hora e
  profissional já vêm preenchidas e o guia tem **3 passos**: Cliente, Serviços, Revisão. Não há passo
  "Quando"; o fluxo não pede dia/hora no fim. (~~4 passos com Avisos~~.)
- **"Novo agendamento" sem data/hora**: o guia tem os **4 passos** e o horário começa **vazio**; o passo "Quando"
  é o **3º, antes da Revisão** (~~Cliente, Serviços, Avisos, Quando, Revisão~~). Sem horário não há como
  continuar nem salvar. O dia começa no que a agenda está mostrando (só o horário começa vazio).
- Na revisão com o horário da agenda, **Alterar** em "Quando"/"Profissional" (ou a pendência "Quando") traz o passo
  "Quando" para o fluxo, no 3º lugar, logo antes da revisão (passa a "Passo 3 de 4"); a pessoa não perde como mudar dia e hora.
- Vale também para o que abre o guia sem `hora=` (lista de espera, "Repetir agendamento"): o horário é pedido em "Quando".
- ~~**Avisos fica antes de "Quando"**~~ (substituído: Avisos não é mais passo; é o menu "Avisos e sinal" da Revisão).

"Sem cadastro": hoje cria uma **cliente rápida** (nome + telefone), como na spec 49, e o texto da tela diz
exatamente isso ("Cria uma cliente rápida só com nome e telefone, para avisar no WhatsApp"). Cliente nula de
verdade (agendamento sem registro de cliente) continua fora (E2: cliente/comanda/cadastro).

**Telefone do cadastro rápido**: validado pelo país escolhido (padrão Brasil +55), na tela e no servidor, com a
mesma regra de `src/domain/phone-rules.ts` (ver §8.1). A regra provisória de 10 dígitos saiu.

**Cliente escolhida: ações e painel em todos os passos.** Com cliente escolhida, as ações dela existem em
todos os passos (1 a 4), sempre pelo mesmo componente `ClientActions` (`_appointment/ClientAside.tsx`):

- **Ações** (menu com "Mensagem no WhatsApp" e "Ligar", que abre `tel:`), **Ver perfil** (link que abre na
  **mesma aba**, como na tela anterior; sair por ele deixa o rascunho para trás) e **Trocar cliente** (botão
  numa linha só). Ver perfil e Trocar cliente ficam fora do menu. "Nova reserva" não existe no guia. Sem telefone, somem WhatsApp e Ligar (e o menu, se ficar
  vazio). Decisão do dono: Ligar fica dentro do menu Ações, em todos os passos e tamanhos.
- **Passo 1**: cartão "Cliente escolhida" no conteúdo (avatar, nome, telefone, etiquetas, as ações acima e as
  linhas nota fixa, ficha e pacotes). No computador o passo 1 é em coluna única (sem coluna da cliente; aprovado).
- **Passos 2 a 4, computador**: a **coluna da cliente de 216 px** (`GuideClientColumn`, centrada: avatar, nome, e-mail,
  telefone, etiqueta, Ações, Ver perfil e Trocar cliente) fica à esquerda; no passo 3 também o cartão-resumo dos serviços.
  ~~Painel `ClientAside` embutido de 300 px com as linhas nota fixa, ficha e pacotes~~ (substituído; a revisão traz os avisos de anamnese e pacote).
- **Passos 2 a 4, celular**: um cartão compacto "Cliente · nome · Editar" (e, no passo 3, "Serviços · resumo · Editar")
  fica acima do passo. Editar leva ao passo da informação. ~~Cartão `ClientRowMobile` de cerca de 380 px~~ (substituído).
  As ações da cliente (Ações, Ver perfil, Trocar cliente) ficam no cartão do passo 1 e na coluna do computador.
- **Trocar cliente** nos passos 2 a 4 tira a cliente e leva ao passo 1 para escolher outra; os passos
  seguintes seguem a regra de ordem (`a revisar` se ficarem inválidos).

Isto **não** é o cartão da coluna do agendamento (`_appointment/ClientCard.tsx`), que tem o menu Ações com
Nova reserva, Ligar, WhatsApp, Reenviar lembrete e Ver perfil, o Ligar em ícone, o nome como link e o botão de
Anamnese. O guia usa o painel da cliente da tela de "Novo agendamento" anterior (fbf5302); dele, Reenviar
lembrete, Anamnese e Nova reserva não existiam na tela anterior (são de um agendamento já criado).

Profissional por serviço: o modelo guarda a profissional de cada item, mas a tela nunca deixou escolher uma por
serviço. Neste guia a profissional de "Quando" vale para todos os serviços; itens que já chegam com profissional
própria (ex.: "Repetir agendamento") mantêm a dela.

## 3. Regras de ordem

- **Só o passo atual é editável**, e só ele aparece: não há lista de passos (os 4 segmentos do cabeçalho do painel só mostram o avanço). Cada passo abre a sua tela, em sequência.
- **Continuar** (passos 2 e 3; o passo 1 não tem o botão, ver §0) fica desabilitado enquanto o passo atual não é válido e **mostra o que falta**
  ("Adicione pelo menos um serviço para continuar"). No último passo (Revisão) o botão é **Salvar agendamento**.
- **Voltar** vai ao passo anterior sem condição. No passo 1 o rodapé tem só **Cancelar** (nos dois tamanhos).
- **Navegação direta** (só pelos botões "Alterar …"/"Voltar ao passo n" da revisão e pelo atalho do rodapé):
  permitida para o passo atual e para qualquer passo anterior já alcançado, desde que todos os passos antes do
  alvo estejam válidos. Nunca para frente de um passo inválido ou de um passo ainda não alcançado.
- **Continuar também respeita a ordem**: só avança se o passo atual é válido **e** nenhum passo anterior está
  inválido (`canAdvance`: o primeiro passo inválido é o atual ou vem depois). Se um passo anterior ficou
  inválido, o botão fica desabilitado e diz o que falta desse passo (`continueState`).
- **Estados do passo**: `concluído` (alcançado e válido), `atual`, `a revisar` (alcançado, mas ficou inválido
  depois de uma alteração anterior) e `bloqueado` (ainda não alcançado).
- **Alterar um passo anterior**: os seguintes continuam `concluídos` se ainda forem válidos; senão ficam
  `a revisar`. Se há passos já alcançados à frente e todos estão válidos, aparece o atalho
  "Voltar ao passo n" para não refazer o caminho.
- **Lista de passos** (`guideSteps(slotKnown)`): 3 passos com o horário vindo da agenda, 4 sem ele (§2; ~~4 e 5~~). "Passo n de
  m" usa o m da lista. `canGoTo`, `canAdvance`, `firstInvalidStep`, `startProgress`, `guideStart` e `continueState`
  usam o tamanho da lista de `GuideInput.slotKnown`; `revealWhen` traz "Quando" de volta (Alterar, na revisão).
  A revisão cobra cliente, serviços **e** "Quando" mesmo sem o passo, para nunca salvar sem dia, hora e profissional.
- **Início** (`startProgress`, `guideStart`): o guia abre no primeiro passo inválido, de 1 a 3. Do zero, no
  passo 1 "Cliente". Só com cliente, no passo 2 "Serviços". Com cliente e serviço já válidos (lista de espera,
  repetir, cliente + serviço pelo horário livre), no 3º passo: **"Quando"** em Novo agendamento sem horário (é o primeiro
  inválido) ou a **Revisão** com o horário vindo da agenda, com os anteriores concluídos. (~~3º passo "Avisos"~~.)
- **Início vindo de "Repetir agendamento"** (`abrir=repetir`): o guia só abre na **revisão** (último passo) se já
  está todo válido. Se não está, abre no primeiro passo inválido, como acima, e a folha de repetição **abre
  uma vez**, quando a pessoa chegar à revisão (o que só acontece com o guia válido). Em qualquer dos dois
  caminhos a folha não reabre sozinha depois de aberta.
- **Fechar** (X, Esc ou Cancelar): se algo foi preenchido ou alterado em relação ao que a tela abriu,
  pergunta "Descartar agendamento?" com "Continuar editando" e "Descartar". Sem alteração, fecha direto.
  (A tela anterior não tinha essa pergunta; passa a ter.)

## 4. Revisão (último passo: 4 de 4, ou 3 de 3 com o horário da agenda)

- **Substituído em 06/11 pelo desenho aprovado (§0):** o resumo em linhas ("O que será salvo") saiu; a Revisão traz data e hora com
  "Alterar", serviços, cartão "Avisos e sinal", observação e o rodapé com Total, Sinal agora e A pagar no atendimento.
  A cliente fica na coluna (computador) ou no cartão (celular), com "Trocar cliente" que leva ao passo 1.
- "O que falta": se algum passo ficou pendente, a lista é **agrupada por passo** (`groupIssuesByStep`): um
  botão por passo (Cliente, Serviços, Quando) com todas as pendências daquele passo no texto ("Escolha a data
  · Escolha o horário (HH:MM) · Escolha a profissional"); só o primeiro pendente é alcançável. O erro da
  repetição aparece sem botão de passo. Nada de alerta de equipe fixo.
- Observações do agendamento (internas; "+ Adicionar observação" ou pelo menu ⋮) e Repetir (a folha de repetição que já existe, aberta por "Repetir agendamento" no menu ⋮). A folha de
  repetição vinda de `abrir=repetir` abre **uma vez só** (regra em §3): o pedido é consumido na primeira
  montagem da revisão; ao sair e voltar, ela não reabre sozinha ("Repetir agendamento" no menu ⋮ continua abrindo-a).
- Erro do servidor (conflito de horário etc.) aparece aqui, com "Salvar mesmo assim" para quem pode gerenciar,
  como já era.

## 5. Tamanhos

> **Substituído em 05/11 23:09**: a moldura abaixo (tela cheia nos dois tamanhos, "Passo n de 5", coluna de 300 px) vale
> só como histórico; ver §0 (painel de ~680 px no computador, tela cheia no celular, "Passo n de 4").

O subtítulo do cabeçalho do celular (o do computador não tem subtítulo, como antes) volta a ser, como na tela anterior (master `7266061`), a **faixa de horário** do
agendamento ("14:00 – 14:45", início – fim pela duração dos serviços) assim que há cliente e serviço; antes
disso mostra "Horário livre de …" (aberto por um horário livre) ou o dia.

Mesmo guia, mesmos passos e mesma ordem; só muda a moldura:

- **Computador (≥ 1024 px)**: painel lateral de ~680 px (Expandir/Fechar; 4 segmentos de progresso no cabeçalho); nos passos 2 a 4, a coluna da cliente de 216 px à esquerda e o passo
  à direita, com rodapé (Total, Voltar, Continuar). (~~Sem barra de progresso~~: os 4 segmentos aprovados a trazem de volta, só como indicação, sem lista de passos nem texto de dica.) O aviso "Rascunho" do cabeçalho aparece quando há pelo menos um serviço (como na
  tela anterior); o que decide a pergunta de descartar continua sendo qualquer alteração.
- **Celular (390 px)**: "Novo agendamento · passo 2 de 4" (só o texto), o passo em tela cheia e rodapé fixo
  com Total, Voltar e Continuar. Alvos de toque ≥ 40 px, sem rolagem horizontal.

## 6. O que não muda

- Datas rápidas no calendário (+2, +4, +6 semanas e +3 meses, `quickFrom` = dia em que a tela abriu).
- Seletor de horário de 15 em 15 min e digitação do minuto exato, com aviso de horário inválido.
- Recorrência (`createRecurringAppointmentAction`, `validateRecurrence`), pacote coberto (`draftPackageMarks`),
  sugestão de sinal, abrir o WhatsApp da confirmação e abrir o registro do sinal depois de salvar.
- Aviso de disponibilidade da profissional (livre / ocupada / fora do expediente).
- Ações de servidor e permissões: nada muda; o guia só decide quando chamá-las.

## 7. Estrutura técnica

- Regra pura em `src/domain/agenda-guide.ts` (passos, validade, o que falta, navegação, rótulo do botão,
  mudança em relação ao início), com Vitest. Sem React/Next/Supabase.
- Design system: o guia usa `Button` (com a prop booleana nova `wrap`, texto que quebra no rodapé do
  celular; os atalhos "Voltar ao passo n", "Ver mensagem" e "Automações" são `Button` ghost), `Input`,
  `Switch`, `NavRow` (props novas `leading` e `chevron`), `EmptyState` (`compact` e `children`), `Avatar`,
  `Notice` e componentes novos: `SummaryList` (conferência da revisão), `Card` (o contêiner `.card`),
  `ToggleRow` (linha de ajuste com interruptor, dos Avisos), `PhoneField` (telefone por país) e `FieldButton`
  (botão com a aparência de campo, usado pelos campos de data e horário). A lista de passos `StepList` foi criada e
  **removida** depois da simplificação pedida pelo dono, por não ter mais uso. Os campos `_new/fields.tsx` e
  `_new/time-picker.tsx` e as linhas de serviço (`ServiceLines`) já não usam as classes cruas `inp`/`btn`: usam
  `FieldButton`, `Input` e `Button` do DS. Ficam fora do DS, por decisão: `RepeatRow` (a linha "Repetir",
  compartilhada com o painel do agendamento) e as classes utilitárias de layout (`flex`, `gap`, espaçamentos) que
  cada tela usa para se organizar.
- Esc: `FullScreen` não fecha a tela inteira quando há menu, lista ou janelinha (`[data-popover-panel]`, o
  `Popover` da Agenda) aberta; o Esc fecha só ela. Sem nada aberto, fecha a tela como antes.
- Telas em `app/(workspace)/[orgSlug]/agenda/_new/`: um componente por passo (`StepClient`, `StepServices`,
  `StepWhen`, `StepReview`; os avisos e o sinal são o menu `NoticesPanel` (com `useNotices`) aberto pela `ReviewLayer`; ~~`StepNotices`~~ foi apagado em 06/11), `GuideFrame` (painel lateral/tela cheia, cabeçalho e segmentos), `GuideClientColumn`
  (coluna da cliente de 216 px), `GuideFooter` e `NewAppointmentScreen` (estado e moldura). Regras puras novas: `src/domain/agenda-slots.ts` (grade de horários, faixa de dias, próxima data) e `src/domain/deposit-input.ts` (sinal em € ou %). Nenhum arquivo de tela acima de 300 linhas.
- Prévia `/dev/v25/agenda?novo=1` (sem cliente nem serviço: começa do zero; `&cliente=1&servico=1`
  chega preenchida). A prévia injeta o "salvar" e o cadastro rápido de exemplo (sem banco) pelo mesmo
  contexto das demais leituras da Agenda (`AgendaLoaders.newAppointment`).

## 8. Critérios de aceite

1. O guia abre como "Novo agendamento" (nome acessível "Guia de agendamento") e cada passo mostra "Passo n de m" (m = 4, ou 3 com o horário vindo da agenda; ~~5 e 4~~) e o seu título.
2. Os passos aparecem na ordem Cliente, Serviços, Quando, Revisão (sem Quando quando o horário vem da agenda), no computador (painel lateral de ~680 px, Expandir/Fechar) e no celular (tela cheia). ~~Cliente, Serviços, Avisos, Quando, Revisão~~.
3. Do zero, o passo 1 não tem "Continuar": o rodapé só tem Total e Cancelar e não há como chegar ao passo 2 sem escolher
   cliente (não existe lista de passos). (~~Continuar desabilitado~~.)
4. Escolher uma cliente (ou cadastrar, ou Sem reserva) leva direto ao passo 2; o passo 2 só avança com pelo menos um serviço (o botão diz o que falta).
4a. Revisão aprovada: data e hora com Alterar, serviços em sequência, + Serviço/+ Pacote/+ Produto, cartão Avisos e sinal, rodapé
   com Total, Sinal agora e A pagar; menus Avisos e sinal (€/%, valor chega ao salvar), Ações do cliente e Ações rápidas ⋮ com os
   itens sem função desabilitados e com a etiqueta "em desenvolvimento" (E2E `guia-agendamento-revisao.spec.ts`; Vitest
   `agenda-review`, `deposit-input`, `agenda-guide`, `ActionPanel`, `StepReview`, `NoticesPanel`).
5. O passo "Quando" (3º; só sem horário vindo da agenda) traz a profissional, a faixa de 7 dias, "Escolha no calendário" com as quatro datas rápidas, a grade de horários (riscados = ocupados), a digitação do minuto exato e, sem vagas, o estado "não tem horários disponíveis" com Próxima data disponível, Verificar todos os profissionais e lista de espera; a data rápida
   muda a data mostrada.
6. ~~O passo 3 ("Avisos") sempre deixa continuar~~ (substituído: Avisos é o menu "Avisos e sinal" da Revisão, já pronto; o Salvar segue funcionando).
7. O último passo mostra o resumo (cliente, serviços, quando, profissional, avisos, total), observações e repetição.
7a. O passo 2 permite marcar vários serviços (caixas), buscar, usar os recentes da cliente e as abas Todos/Serviços/Pacotes/Produtos; o total e "n serviços · duração" acompanham.
7b. O sinal (regra pura) aceita valor em € ou %, converte, mostra "Equivale a x % do total" e recusa valores fora de 0 ao total (Vitest `deposit-input.test.ts`).
8. Salvar chama a criação, e ao terminar abre o agendamento criado (confirmação já usada pelo app).
9. Voltar a um passo anterior, alterar e seguir mantém os passos seguintes válidos; se o alterado os invalida,
   ficam "a revisar" e não dá para saltar sobre eles.
10. Cadastro de nova cliente exige nome e telefone válido para o país escolhido (padrão Brasil +55; §8.1); "Sem cadastro" usa o mesmo
    cadastro rápido e o texto diz "cliente rápida".
11. Fechar com algo preenchido pergunta antes de descartar; sem alteração fecha direto.
12. Pacote da cliente que cobre o serviço aparece no passo 2.
13. Datas rápidas, horário de 15 em 15 min com digitação e aviso de horário inválido seguem funcionando.
14. Com a cliente escolhida, os passos têm Ver perfil (link, mesma aba), Trocar cliente (uma linha só) e, dentro do menu
    Ações, WhatsApp e Ligar (`tel:`). Hoje só o passo 1 usa `ClientActions`; nos passos 2 a 4 a coluna da cliente (computador) usa `ClientActionsButton` e o menu `ReviewMenus`; no celular, os passos 2 e 3 têm só "Editar" (como no desenho aprovado). ~~Em todos os passos 1 a 4, nos dois tamanhos~~ (substituído em 06/11).
15. "Continuar" não avança quando um passo anterior está inválido (Vitest em `canAdvance`/`continueState`).
16. A revisão agrupa "O que falta" por passo, com um botão por passo (Vitest `groupIssuesByStep` e
    `StepReview.test.tsx`).
17. A folha de repetição vinda de `abrir=repetir` abre uma vez só: na revisão se o guia abriu válido, ou ao chegar
    na revisão se abriu em passo inválido (Vitest `guideStart`; E2E nos dois casos).
18. Esc com a janelinha da data aberta fecha só ela; sem ela, fecha o guia; o painel do agendamento continua
    fechando com Esc (E2E nos dois tamanhos).
19. ~~No celular o subtítulo mostra a faixa de horário (E2E).~~ Substituído em 2026-11-05: o subtítulo mostra "Novo agendamento · passo n de 4".
20. ~~O aviso "Rascunho" do computador aparece quando há serviço (E2E).~~ Substituído em 2026-11-05: o desenho aprovado não tem o aviso "Rascunho".
21. Regra de ordem em Vitest; E2E em desktop-chrome e mobile-chrome; typecheck e lint sem avisos; capturas
    1440 e 390 de cada passo.
22. Simplificação pedida pelo dono ("é só abrir a tela passo a passo, sem exibir nada mais"): o guia não mostra lista de
    passos, barra de progresso nem texto de dica; só "Passo n de m", o título e a tela do passo, com Voltar e
    Continuar (os 4 segmentos do cabeçalho do painel, aprovados em 05/11, só indicam o avanço) (E2E: sem `navigation` "Passos do guia" nem `progressbar`). O cartão da cliente e o menu Ações ficam como
    estavam.
23. Regra de entrada: com o horário vindo da agenda o guia tem 3 passos (sem "Quando"); em Novo agendamento sem
    data/hora tem 4, o horário começa vazio e o passo "Quando" é o 3º, antes da Revisão, e bloqueia Continuar até
    haver horário (Vitest `guideSteps`, `canAdvance`, `continueState`, `revealWhen`; E2E "regra de entrada 1" e "2").

## 8.0 Aguardando decisão do dono

- ~~Painel da cliente no passo 1 e altura do cartão no celular~~: **resolvidos** pelo desenho aprovado em 05/11 (§0: passo 1 em coluna única; celular com cartões compactos "Editar").
- Telefone por país: se vale também para cadastros já existentes e quais países a clínica atende (§8.1).

## 8.1 Pendências fora desta rodada

- **Telefone por país (DDI): implementado para número novo ou alterado.** Decisão do dono: a quantidade de dígitos
  depende do país; começa por Brasil, Portugal e Espanha e cobre a Europa.
  - Regra pura em `src/domain/phone-rules.ts` (sem React, Next nem Supabase), com Vitest (`phone-rules.test.ts`):
    `validatePhone(número, país)`, `detectPhoneCountry`, `toInternationalInput` e a lista `PHONE_COUNTRIES`
    (Brasil primeiro e padrão, Portugal, Espanha e depois a Europa em ordem alfabética). Digitar "+DDI" no campo
    troca o país; "00DDI" vale como "+DDI". Mensagens: "Faltam dígitos para Brasil.", "Dígitos a mais para …",
    "Número inválido para …".
  - **Dependência nova: `libphonenumber-js` 1.13.15** (pnpm, licença MIT), usada só em `phone-rules.ts` com os
    metadados completos (`libphonenumber-js/max`). Motivo: manter a tabela de planos de numeração de cada país à
    mão (Brasil com 8 ou 9 dígitos e DDD, Portugal e Espanha com 9, o resto da Europa) fica errada com o tempo; a
    biblioteca é a que o Google mantém para isso e cobre todos os países europeus. Os metadados completos
    pesam mais que os mínimos (cerca de 145 KB contra 80 KB, antes de comprimir), mas só os mínimos aceitam
    qualquer número com o tamanho certo (testado: um número espanhol "6xx" passava como português).
  - Tela: componente `PhoneField` do DS (seletor com bandeira e DDI, padrão Brasil +55, e o campo do número),
    usado no cadastro rápido do guia (`_new/ClientChooser.tsx`) e no cadastro de cliente
    (`clientes/ClientFormParts.tsx`, `IdentityFields`). `Select` ganhou `short` (texto curto no campo fechado).
  - Servidor, mesma regra: `agenda/appointment-query-actions.ts` (`createClientQuickAction`, antes
    `phone.trim().length < 3`) e `clientes/actions.ts` (`createClient` sempre; `updateClient` só quando o
    telefone mudou em relação ao guardado). Testes: `appointment-query-actions.test.ts` e `actions.phone.test.ts`.
  - Guardado em formato internacional, como já era: `clients.phone` = "+DDI número" e `clients.phone_country_code`
    = "+DDI". Consulta somente leitura ao banco (30 clientes): todos têm "+" e `+34`, então **nenhuma migração
    é necessária** e nenhum dado existente foi alterado. Sem DDI na lista de países, o número digitado com "+DDI"
    continua valendo (a biblioteca conhece o país).
  - **Dados já cadastrados não são revalidados.** Editar um cliente sem mexer no telefone grava o telefone
    como está guardado (nem reformata). A regra só vale ao criar, ao trocar o número ou ao trocar o país.
  - Onde o telefone ainda tem regra própria e **não foi mexido** (rodada própria, depende da resposta do dono):
    importação de clientes `src/domain/client-import.ts:129` (pelo menos 6 dígitos), reserva online
    `src/domain/public-booking.ts:129` (pelo menos 6 caracteres) e `ClientSchema.phone` em
    `clientes/actions.ts:24` (`min(3)`, `max(40)`, só o formato do campo).
  - **Perguntas ao dono:** (1) quais países a clínica atende, para ordenar a lista (hoje: Brasil, Portugal,
    Espanha e depois a Europa); (2) aplicar a regra aos cadastros já existentes? Hoje não é aplicada; se sim,
    seria um relatório (sem alterar) dos números que a regra recusaria, antes de qualquer correção.
- "Sem cadastro" de verdade (agendamento com cliente nula): depende de E2 (cliente/comanda/cadastro).
- Profissional por serviço (o modelo guarda, a tela usa uma só para todos).
- `RepeatRow` ainda não é componente do DS (ver §7). Outros pontos da Agenda fora do guia ainda usam `btn`/`inp` (ex.: botão "Novo agendamento" do dia fechado no celular, `MobileBoard`).
- Outras telas do app ainda usam a classe `.card` direto; só o guia migrou para o componente `Card`.

## 8.2 Comparação com o fluxo Fresha 04/11

Fonte: 5 prints enviados pelo dono em `docs/fresha-prints-referencia/novo-agendamento-04-11/` (branch `docs/referencias-fresha-04-11`,
commit `4eb4d05`, com README). Referência de sequência, capacidade e hierarquia; não copiar marca nem textos.
Só entra aqui o que está nos prints; o que não aparece neles não foi inferido.

**Sequência do Fresha (prints):** 1 Selecionar cliente → 2 Selecionar serviço → 3 Resumo (com data e hora já
definidas) **ou** 4 Serviços com profissional + Continuar (quando ainda falta data/hora) → 5 Selecione um horário
→ conclui. Cada tela ocupa o espaço inteiro, sem painel explicativo ao lado.

| # | Fresha | Este guia hoje | Diferença |
|---|--------|----------------|-----------|
| Ordem | Cliente, Serviço, (Profissional), Horário, Resumo | ~~Novo agendamento: Cliente, Serviços, Avisos, **Quando**, Revisão e salvar. Horário da agenda: Cliente, Serviços, Avisos, Revisão~~ (substituído em 06/11; hoje: Cliente, Serviços, Quando, Revisão; com horário da agenda: Cliente, Serviços, Revisão) | **Depois da regra de entrada e da correção de ordem (K1):** o passo de horário aparece só sem horário e é o último antes da Revisão, como no Fresha (que não tem Avisos nem Revisão separada); Avisos fica antes dele |
| Quantidade de passos | Varia: o passo de horário some se data e hora já vieram do clique na agenda | ~~4 ou 5~~ (hoje 3 ou 4), "Passo n de m" | **Igual na regra**; o indicador "Passo n de m" não existe nos prints |
| 1 Cliente | Busca ("Pesquisar cliente ou deixar em branco para clientes sem reserva"); **Cadastrar cliente**; **Sem reserva** (cliente de balcão); lista de clientes **com o telefone** | Busca "Nome ou telefone"; **Nova cliente** e **Sem cadastro** (hoje cria cliente rápida com nome e telefone; walk-in de verdade está no rascunho da spec 53); lista "Sugeridas para este horário" com última/próxima visita, **sem telefone** na linha | Telefone na lista; lista sugerida por horário (extra nosso); "Sem reserva" do Fresha é cliente sem cadastro, o nosso exige telefone |
| 2 Serviço | Tela própria "Selecionar serviço": busca por nome, "Reservado recentemente" com contagem, categorias com contagem, cada serviço com duração e preço (preço riscado com desconto), serviços de pacote com "n serviços" | Passo "Serviços": lista dos escolhidos e botões **+ Serviço** / **+ Produto** que abrem `ServicePicker` em janela presa ao botão (computador) ou folha (celular) | Escolher serviço não é uma tela do passo, é janela/folha; busca por nome, "Reservado recentemente" e contagem por categoria não foram conferidos no `ServicePicker` nesta rodada; **+ Produto** não existe nos prints do Fresha |
| 3 Resumo | Cabeçalho com a data (seletor); cartão da cliente (nome, telefone, etiqueta, **Ações**, ligar, e-mail); data e hora; repetição ("Não se repete"); serviços (hora, duração, profissional); **Adicionar serviço**; **Total** e **A pagar**; rodapé **⋮**, **Checkout**, **Salvar** | ~~Passo 5 "Revisão e salvar"~~ (hoje passo 4 "Revisão"): "O que falta" por passo, conferência, observações, **Repetir**, rodapé com Total, Voltar e **Salvar agendamento** | Sem botão **Checkout** no guia; sem **A pagar**; sem **⋮** no rodapé; no Fresha data/hora e repetição ficam no mesmo cartão do resumo; "O que falta" e observações não aparecem nos prints |
| 4 Serviços + profissional | Cartão da cliente; serviço com **seletor de profissional por serviço** (avatar + nome); Adicionar serviço; Total e A pagar; **Continuar** em largura total | Profissional é um só para o agendamento, escolhido em "Quando" (o modelo guarda por item, a tela usa um só: ver §8.1) | Profissional por serviço no passo de serviços; avatar no seletor |
| 5 Horário | "Selecione um horário": seletor de profissional, ícone de calendário, faixa de dias do mês (dias sem vaga em cinza), "Horários disponíveis" em lista, "Escolha no calendário", Total e A pagar, **Continuar desabilitado até escolher** | Passo "Quando" (4º): data (calendário e datas rápidas +2, +4, +6 semanas e +3 meses), horário (lista de 15 em 15 min e digitação), profissional | Faixa de dias do mês com dias sem vaga em cinza e "Escolha no calendário"; datas rápidas e digitação do horário são extras nossos |
| Cartão da cliente | Aparece no topo dos passos 3 e 4, com Ações, ligar e e-mail como ícones | ~~Passos 2 a 5~~ (hoje 2 a 4): cartão (celular) ou coluna da esquerda (computador) com **Ações** (WhatsApp, Ligar), Ver perfil e Trocar cliente | Ícones soltos de ligar e e-mail versus menu Ações (decisão do dono: Ligar dentro de Ações); e-mail não está no cartão; no Fresha o cartão não aparece nos passos 1, 2 e 5 |
| Avisos | Não aparecem nos prints | ~~Passo 3 "Avisos"~~ (substituído em 06/11: menu "Avisos e sinal" na Revisão) com confirmação por WhatsApp, lembrete 24 h, sinal | Extra nosso, agora dentro da Revisão |
| Rodapé | Total e A pagar; Continuar (largura total) | Total; Voltar; Continuar; atalho "Ir para …" | Atalho "Ir para …" e botão Voltar visível não aparecem nos prints (o passo 5 tem seta de voltar no topo) |
| Indicador de passo | Não há "Passo n de 5" nos prints | "Passo n de 5" + título | Indicador extra nosso (pedido do dono: indicador simples) |

### Regra de entrada (informada pelo dono)

- Clique direto num horário ou dia da agenda: data e hora já vêm preenchidas e o fluxo **não** pede dia/hora no fim.
- "Novo agendamento" sem data/hora: o fluxo pede dia e hora **no fim** (passo 5 do Fresha) antes de concluir; sem
  horário não há como concluir ("Continuar" desabilitado).

**Hoje:** a tela recebe `initial.fromSlot` (`agenda/page.tsx:112`, `fromSlot: !!sp.hora`), então a diferença entre os
dois casos já chega ao guia sem mudar a rota. (Estado anterior à regra, só para registro: "Quando" era sempre o
passo 3 nos dois casos e "Novo agendamento" sem hora partia de um horário padrão da página.)

### Estado real depois da regra de entrada (implementada)

> **Substituído em 06/11 (histórico da correção K1):** os trechos abaixo sobre "5 passos", "Avisos antes de Quando" e as capturas
> `guia-passo-{1..5}` descrevem o fluxo de 05/11 e já não valem. Hoje: 4 passos (3 com o horário da agenda), sem Avisos; capturas
> `guia-passo-{1..4}-*`, `guia-horario-livre-passo-{1..3}-*` e `novo-*` (ver §0).

- Lista de passos derivada de `GuideInput.slotKnown` (`guideSteps`): ~~4 passos com o horário vindo da agenda (sem
  "Quando"), 5 em Novo agendamento sem horário~~ (hoje 3 e 4). A rota **não mudou**: `slotKnown` é o `initial.fromSlot` que
  `agenda/page.tsx:112` já passava (`fromSlot: !!sp.hora`). Em Novo agendamento o horário começa vazio e o passo
  "Quando" bloqueia Continuar até haver horário.
- ~~**Posição de "Quando" (correção K1 da auditoria de 05/11):**~~ (substituído em 06/11: Quando volta a ser o 3º passo) sem data/hora vinda do clique, "Quando" é o **último
  passo antes de Revisão** (Cliente, Serviços, Avisos, Quando, Revisão), conforme o pedido do dono: dia e
  hora "no final, pra concluir". Antes ele ficava logo depois de Serviços. Com o horário do clique continua sem o
  passo (4 passos). `ALL_STEPS` troca a ordem de Avisos e Quando; `guideSteps`, `stepIndex`, `revealWhen` (Quando
  entra no 4º lugar, a revisão anda um) e `startProgress` (abre em Avisos, 3º passo, nas duas entradas) seguem a
  lista; `canGoTo`, `canAdvance`, `firstInvalidStep` e `continueState` não mudaram de código (usam a validade de
  cada passo na ordem da lista) e têm Vitest para as duas entradas.
- "Passo n de m" com m dinâmico (4 ou 5). Domínio e Vitest: `agenda-guide.test.ts`, bloco "regra de entrada".
- E2E (desktop 1440 e mobile 390, `e2e/guia-agendamento.spec.ts` e `e2e/guia-agendamento-acoes.spec.ts`, ajudantes em `e2e/fixtures/guia.ts`): "regra de entrada 1" (clique no horário: 4 passos,
  sem "Quando", salva), "regra de entrada 1 · Alterar quando" (o passo volta para o fluxo) e "regra de entrada 2"
  (Novo agendamento sem data/hora: "Quando" depois de Avisos e antes da Revisão, só conclui com dia e hora). Prévia: `/dev/v25/agenda?novo=1`
  (sem horário) e `?novo=1&hora=14:00` (clique no horário).
- Capturas: `e2e/screenshots/guia-passo-{1..4}-*` (Novo agendamento, 4 passos: 3 = Quando, 4 = Revisão; ~~1..5 com Avisos~~) e
  `guia-horario-livre-passo-{1..3}-*` (horário vindo da agenda, 3 passos), mais `novo-*` (telas aprovadas).

### Pendências de decisão do dono (nada disto foi alterado)

1. **[Resolvida em 05/11 23:09: Avisos deixa de ser passo e vira o menu "Avisos e sinal" da Revisão; "Quando" é o 3º passo.]** **Onde fica "Avisos"** em relação ao resumo do Fresha: o Fresha não tem esse passo; no fluxo de hoje ele vem
   **antes de "Quando"** (3º passo de 5 e de 4), logo depois de Serviços. A ordem Avisos → Quando (e não Quando →
   Avisos) é decisão do dono **pendente**: veio da correção de "Quando por último", sem confirmação sobre Avisos.
   **Pergunta: manter Avisos antes de Quando, mover para depois (Quando, Avisos, Revisão), fundir na Revisão ou remover?**
2. **"Revisão" × resumo do Fresha:** no Fresha o resumo (passo 3) já é a tela de conferência com Salvar e
   Checkout; aqui a revisão é o último passo, sem Checkout.
3. **Passos e elementos nossos que não existem nos prints do Fresha** (mantidos, sem remover): ~~passo "Avisos"~~ (agora menu da Revisão);
   indicador "Passo n de m"; atalho "Ir para …" e Voltar no rodapé; "O que falta" e observações na revisão; datas
   rápidas e digitação do horário; "Alterar quando" na revisão (traz o passo de volta); lista "Sugeridas para este horário" no passo 1; botão **+ Produto**.
4. **Elementos do Fresha que o guia não tem:** Checkout no rodapé do resumo; A pagar; ⋮ no rodapé; profissional
   por serviço; faixa de dias com horários disponíveis; ícone de e-mail no cartão da cliente; telefone na lista de
   clientes; "Reservado recentemente" e contagem por categoria (a conferir no `ServicePicker`).
5. **Cartão da cliente nos passos 1, 2 e 5 do Fresha:** o print mostra o cartão só nos passos 3 e 4; já estava
   pendente aqui (§8.0) manter o cartão em todos os passos.
6. **"Sem reserva" × "Sem cadastro":** o Fresha cria um agendamento sem cliente cadastrada; o guia exige telefone.
   Depende da spec 53 (rascunho).

### Revisão independente de 3f93ff2: achados e estado

| # | Achado | Estado |
|---|--------|--------|
| 1 | "Novo", menu Agendamento, "+" do celular, bottom sheet e dia fechado mandavam `hora` e pulavam "Quando" | **Corrigido.** `newAt(date, null, staff)` não leva `hora`; só o clique direto num horário livre (grade e linhas do celular) leva. E2E: "Novo agendamento"/menu Agendamento (computador) e Criar > Novo agendamento (celular) navegam sem `hora`; com `?novo=1` o "Quando" aparece e "Continuar" fica bloqueado até escolher o horário. O clique direto num horário livre (grade do computador com o SlotMenu, linhas "Livre" do celular) **não** tem E2E próprio: na prévia "Toda a equipe" ele não é estável; o código é o mesmo `newAt(date, time, staff)` de antes e a entrada com `hora=` é coberta por "regra de entrada 1". |
| 2 | Telefone com 0 de tronco ("011 91234-5678", BR) virava "+55 011..." | **Corrigido.** `validatePhone` guarda "+DDI" + número nacional sem o tronco (`+55 11 91234 5678`, também para 021 etc.), no cadastro rápido da Agenda e em Clientes (criar e editar quando o telefone muda). wa.me usa só os dígitos (`5511912345678`) e Ligar abre `tel:+dígitos`. Testes de domínio e das ações. |
| 3 | Classes cruas `inp`/`btn` em `fields.tsx`, `time-picker.tsx`, `ServiceLines`, `PhoneField` | **Corrigido.** Novo `FieldButton` no DS; `Input` e `Button` nos demais. Não tocados (fora do pedido): `btn` em `MobileBoard` (dia fechado), outros `tel:` (`ClientCard`, `client-api`, comanda). |
| 4 | Trocar o país com "+55..." digitado guardava +55 com Espanha | **Corrigido.** `switchPhoneCountry` tira o DDI digitado ao trocar o país; o número nacional é validado pelo novo país. Vitest e E2E. |
| 5 | Cálculo de fim (limite de 24 h) e de início de cada linha na tela | **Corrigido.** `src/domain/agenda-draft-times.ts` (`endTime`, `lineStartTimes`) com Vitest. |
| 6 | `guia-agendamento.spec.ts` com 525 linhas | **Corrigido.** Dividido em dois arquivos (entrada e fluxo; ações, telefone e Esc) com ajudantes em `e2e/fixtures/guia.ts`; todos abaixo de 500 linhas. |
| 7 | "+1 555..." com Brasil selecionado | **Corrigido.** Vale o DDI do número digitado; a mensagem de erro cita o DDI quando ele não está entre os países oferecidos. |
| 8 | Rótulo do último passo desabilitado | **Corrigido.** Diz a pendência específica ("Escolha uma cliente para salvar"). |
| 9 | Asserção vazia em `agenda-guide.test.ts` | **Corrigido.** Substituída por uma que falha se `canGoTo` regredir. |
| 10 | `StepList` sem uso | **Corrigido.** Removido do DS (ver §7). |
| 11 | `SummaryList` com `Button size="sm"` sem efeito | **Corrigido.** Prop removida. |

## 9. Validação do dono (depois do deploy)

- Abrir "Novo agendamento" num horário livre e ver que o guia pede a cliente primeiro e não deixa pular.
- Percorrer os 4 passos no computador (painel lateral) e no celular (tela cheia) e salvar.
- Voltar do passo 4 ao 1, trocar a cliente e conferir que os passos seguintes seguem concluídos.
- Fechar no meio e conferir a pergunta antes de descartar.
