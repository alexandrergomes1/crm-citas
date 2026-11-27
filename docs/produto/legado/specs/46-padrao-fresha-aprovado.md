# Spec 46 — Padrão Fresha aprovado (mockup v3.4)

> Fonte: mockup clicável aprovado em 30/10/2026 (artefato "fresha-mock", versão 7) e as correções do
> responsável do produto. Regra de ouro: **copiar o Fresha em layout e melhorar só onde a melhoria é clara**.
> Nenhuma função existente pode sumir. Este documento é também o checklist de revisão do PR
> (cada item tem um código `Gx`, `Ax`, `Fx`… usado nos testes e na revisão final).

## Princípios globais

- **G1 Botões em pílula** (`.btn`, `.ib`). Chips e badges seguem a forma escolhida em Aparência.
- **G2 Seleção sempre com caixinha quadrada com check** (`✓`), em qualquer lista de opções: filtros, status,
  "Termina" do repetir, etc. **Nunca** bolinha (radio): bolinha sugere escolha única e o responsável rejeitou
  esse padrão. Quando a escolha é única, a lista usa o check à direita da linha (padrão do menu), não bolinha.
- **G3 Menus com várias opções/subopções são lista de linhas**: ícone à esquerda, rótulo, resumo do valor atual
  (cinza) e seta `›`. A linha **expande** (acordeão, uma por vez, seta gira) ou **abre a tela/folha relacionada**.
  Nunca uma cascata de grupos de checkboxes soltos. Vale para toda a aplicação (filtros da agenda, filtros de
  clientes, Ações, ⋮, Opções).
- **G4 Botões de ferramenta são ícone com texto opcional.** Em Ajustes › Aparência há "Botões da barra:
  Só ícone / Ícone e texto" (por aparelho, como a densidade). Todo botão de ferramenta tem `aria-label`.
- **G5 Aparência (Ajustes › Aparência)**: tema (estética/barbearia/essencial), forma (reto/suave/pílula),
  tamanho dos elementos (**ultra compacta / compacta (padrão) / confortável**, com diferença real de botões, campos,
  linhas, texto e espaços; números em `primitives.css`; no celular o toque continua ≥ 44 px), claro/escuro, botões da
  barra (só ícone/ícone e texto). Tudo por aparelho (localStorage), aplicado em `<html data-*>` antes da pintura
  (sem piscar). Os valores antigos `compacta` e `confortavel` continuam válidos.
- **G6 Cor**: bronze `#7A5A22` como primária (já aprovada). Preto nunca é cor primária.
- **G7 Nada de linhas que não clicam**: toda linha de menu/lista que parece clicável é clicável.
- **G9 Ajustes só grava ao Salvar.** Nenhuma seção grava ao tocar numa chave ou escolha: as edições ficam em rascunho
  (`useDraftForm`, lógica em `src/domain/draft.ts`) e a `SaveBar` fixa no rodapé (acima da barra do celular, com a área
  segura) tem **Salvar** (bronze) e **Descartar**, ativos só com alteração. Sair com alteração (voltar, X, link do menu,
  trocar de seção, fechar a aba) pergunta "Descartar alterações?". Aparência mostra a prévia ao vivo e só persiste ao
  Salvar. Ações imediatas por natureza (trocar senha, definir PIN, criar/apagar perfil, conta de pagamento) mantêm
  confirmação ou botão próprio. Seções com muitos grupos usam linhas expansíveis (G3).
- **G8 Toque mínimo 40 px**, mobile-first (390 px) e desktop (1440 px), nenhum arquivo de tela > 300 linhas.

## Agenda

- **A1 Equipe**: botão **só ícone** (pessoas) com bolinha de contagem quando nem toda a equipe está selecionada;
  com "Ícone e texto" mostra "Toda a equipe"/nome. Em desktop e celular. Abre o menu de equipe (caixinhas).
- **A2 Filtros**: ícone de filtros com contador. Abre (popover no desktop, folha no celular) a **lista de linhas
  expansíveis** (G3): Status, Profissionais (se houver mais de uma), Ficha Cliente, Sinal, Canal de origem,
  Pagamento, Serviço, Tipo de bloqueio, Bloqueios (mostrar). Resumo cinza à direita ("Todos", "1 filtro").
  Rodapé: "Limpar filtros" e o botão de resultado. Com filtro ativo aparece a faixa "Filtrando por … [chips]
  Limpar" sob a barra.
- **A3 Bloquear horário**: campo de **motivo livre** (digitável) + atalhos (Almoço, Folga, Reunião, Curso,
  Pessoal, Médico). Linhas Dia / Início / Fim / Repetir (abre a folha de repetição, A5) e interruptor "Bloquear
  para toda a equipe". É um bloqueio comum da agenda.
- **A4 Opções (⋮ da agenda)**: Bloquear horário, Lista de espera, Lembretes de amanhã, etc. — em lista com ícone.
- **A5 Repetir (flexível)**, usado no novo agendamento, no bloqueio e em "Repetir agendamento":
  frequência (Não se repete / Todo dia / Toda semana / Todo mês), "A cada N" (1–N), dias da semana (D S T Q Q S S,
  ao menos um) quando semanal, término (Nunca / Em uma data / Depois de N vezes — caixinhas, G2) e uma linha de
  resumo ("A cada 2 semanas · ter, qui · 8 vezes"). "Nunca" é gerado até o limite de série (52 ocorrências).
  Domínio puro (`src/domain/`), com testes.

## Agendamento (tela/painel)

- **P1 Cabeçalho colorido pelo status** (faixa suave), com data/hora **no topo** (botão que abre o reagendar),
  o botão de status (`● Pendente ⌄`) e fechar. Sob eles: faixa de horário · duração · profissional ·
  (`↻ repetição`, **só** quando o agendamento se repete; nada de "não se repete").
- **P2 Cartão da cliente**: nome (abre o perfil), telefone, etiqueta (VIP), avatar. Linha de ações:
  **Ações ⌄**, **Ligar** (ícone), **Anamnese** (ícone prancheta-check, P3). Alerta (ex.: alergia) e nota fixa
  dentro do cartão.
- **P3 Anamnese**: ícone prancheta com check. Pendente → balãozinho com número (1) em âmbar; assinada → flag
  verde de check; só aparece se o agendamento tem/exige ficha. Abre a folha **"Anamnese"** com: anamnese
  (pendente/assinada, reenviar, copiar link, excluir ficha, abrir) e **Ficha profissional** (preenchida no
  atendimento; sem ela o checkout não é pago). Mantém a trava do checkout e "Liberar sem a ficha".
- **P4 Sem bloco "Preparação" e sem chips "Lembrete/Ficha/Sinal"** no corpo do agendamento. Sinal vive no
  rodapé (P7); lembrete vive em Ações (P5) e no Histórico.
- **P5 Menu Ações** (lista com ícones): Nova reserva, Ligar, Mensagem no WhatsApp, **Reenviar lembrete**,
  Ver perfil.
- **P6 Corpo**: card "Serviços" (cada serviço com profissional, duração, preço, ⋮; `+ Serviço`, `+ Produto`,
  "Tempo total"), selo "No pacote" quando for o caso, card com "Observação do agendamento" (só a equipe vê,
  aparece no checkout) e **Histórico ›**.
- **P7 Rodapé**: `Total`, `Sinal` (linha clicável: "+ Adicionar" sem sinal; "Sinal pago · Bizum −20,00 €" com
  sinal; abre registrar/pedir sinal), `A pagar`, e os botões ⋮ (Mais ações), **Pagar agora**, **Checkout**.
- **P8 Histórico** (folha): duas abas — **Automáticos** (lembrete enviado, confirmação recebida, ficha
  assinada pelo link, sinal registrado) e **Equipe e cliente** (criou, alterou horário, nota, pedido da
  cliente). Linha do tempo.
- **P9 Mais ações (⋮)** continuam: reagendar, repetir agendamento (A5), nova reserva, mensagem, nota,
  checkout, histórico, perfil, editar série, canal, trocar cliente, cancelar (com política do sinal).

### Revisão de 06/11/2026 — Agendamento no formato aprovado e sem botões repetidos

O painel do agendamento existente (ver/editar) estava no modelo antigo (440 px, uma coluna). Passou ao formato aprovado em 05/11 para o
Novo agendamento, e cada ação existe **uma vez só** (o dono pediu o padrão do Fresha, sem duplicidade). Vale acima de P2, P5, P6, P7 e P9:

- **Painel**: 680 px à direita no computador, com "Expandir"; cabeçalho colorido pelo estado (P1) segue. Celular: tela cheia.
- **Cliente (P2)**: no computador, **coluna de 216 px à esquerda** (avatar, nome, telefone, etiquetas, alerta, **Ações ⌄** + **Ver perfil** +
  ícone da Anamnese, link **Trocar cliente**, nota fixa e linhas pequenas: aniversário, próximo agendamento, visitas…). No celular, cartão
  compacto no topo (o "Sobre a cliente" fica na linha do card de observação). O nome **não é link**; sem ícone solto de telefone.
- **Ações ⌄ (P5)**: Nova reserva, Ligar, Mensagem no WhatsApp, Reenviar lembrete. **Sem** Ver perfil e **sem** Trocar cliente.
- **⋮ (P9)**: só o que não tem botão próprio: Iniciar atendimento (pendente), Repetir agendamento, Enviar ficha da cliente, Editar série,
  Canal do agendamento, Cancelar. **Saíram do ⋮** (já têm botão): Reagendar (data no cabeçalho), Nova reserva e WhatsApp (Ações), Adicionar nota
  (card de observação), Registrar sinal (linha Sinal), Ir para o checkout (botão Checkout), Ver histórico (linha Histórico), Ver perfil da
  cliente e Trocar cliente (coluna da cliente).
- **Densidade**: textos 12–14 px, cartões com 8–12 px de respiro; rodapé de ~133 px no computador e ~106 px no celular (antes 167 px).
  No celular o rodapé mostra Total, Sinal e A pagar lado a lado.
- **Rolagem**: os filhos da coluna rolável têm `shrink-0`. Sem isso, em tela curta (1366×640, celular pequeno) o card
  "Observação / Sobre a cliente / Histórico" encolhia a 2 px e o conteúdo ficava escondido e sem rolagem (E2E: `agendamento-painel.spec.ts`).
- No **Novo agendamento** o menu "Ações do cliente" também perdeu "Ver cliente" e "Trocar cliente" (já são o botão **Ver perfil** e o link
  **Trocar cliente**). "Editar dados do cliente" continua (abre o perfil em modo de edição, outra aba).

## Novo agendamento

- **N1** A linha de repetição mostra o **resumo** ("Não se repete" / "Toda semana · ter · 8 vezes") e abre a
  folha de repetição (A5). Data/hora/profissional em linhas clicáveis com ícone e seta.

## Checkout

- **C1 Gorjeta flexível**: chips `Sem · 5 € · 10 € · 10 % · Outro`; "Outro" abre campo para digitar o valor
  em € (e aceita percentual). A gorjeta entra no total e no recibo como já entra hoje.

## Clientes

- **F1 Filtros de clientes**: mesma lista expansível (G3): Ordenar por, Situação (ativas/arquivadas),
  Etiquetas e origem, Última visita, Saldo. Caixinhas (G2).
- **F2 Ficha › Atendimentos em linha do tempo**, agrupada por mês, com chips Todos / Próximos / Concluídos /
  Cancelados; cada nó traz data · hora e o cartão do atendimento (Abrir, Checkout / Ver venda, Nova reserva).

## Não-objetivos / preservados

- Nada de fiscal. Nenhuma regra de domínio muda sem teste. Nenhuma migration é removida.
- Todas as funções do "Mapa das funções" do mockup continuam acessíveis (ver lista no PR).

## Pendências conhecidas (revisão independente, 31/10/2026)

- **G5 claro/escuro**: ainda não existe (faltam tokens escuros); tema, forma, densidade e botões da barra estão prontos.
- **G4**: "Só ícone / Ícone e texto" vale na Agenda; barras de Clientes, Catálogo, Financeiro e Mensagens ainda têm pílulas de texto fixas.
- **P8**: o histórico ainda não registra "lembrete enviado", "horário alterado", "nota adicionada" nem "pedido da cliente" (não há eventos salvos para isso).
- **N1**: Data/Início/Profissional seguem como campos no desktop (no celular é a linha-resumo com seta).
- A recorrência gravada no banco é só `FREQ;COUNT`; "a cada 2 semanas · ter, qui" não é guardado na série.

## Navegação do celular: regras fechadas (onda 3)

- **Topo fixo** (`.sticky-bar`) em toda tela interna do celular; a Agenda é a casa e não tem X.
- **‹ dá um passo** na hierarquia; **X fecha o fluxo todo** e volta à última tela raiz visitada (`src/domain/screen-origin.ts`,
  `src/app-shell/ScreenOrigin.tsx`). Com alteração não salva, o X também pergunta "Descartar alterações?" (leave-guard).
- O X usa `router.replace`: o botão Voltar do aparelho ainda passa pelas telas do meio (o navegador não deixa apagar entradas
  do histórico). Aceito e documentado.
- O checkout (`ComandaFlow`) tem X próprio, que leva à Agenda ou às Comandas conforme de onde veio.
- Alvos de toque no celular: ≥ 44 px em qualquer tamanho (área invisível em botões, ícones, interruptores e caixinhas; o
  controle segmentado tem mínimo de 40 px mais o respiro).
