# Spec 42 · Padrão de interface do sistema

Status: proposta para aprovação (30/10/2026) · Origem: 49 capturas do Fresha enviadas pela Karenn + material público do Fresha e do Booksy, cruzados com o app atual.
Objetivo: um único jeito de montar topo, menus, filtros, painéis e densidade em **toda** tela. Tela nova só entra se seguir esta spec; telas atuais são auditadas contra ela (seção 9).

## 1. Princípios

1. **Conteúdo primeiro.** O cromo (topo + controles) ocupa no máximo 2 linhas no celular (≈ 96 pt) antes do conteúdo.
2. **Um ícone por função, sempre o mesmo.** Quem aprende numa tela já sabe usar nas outras.
3. **Resumo no controle, detalhe no painel.** O botão mostra *quanto* está ativo (contador); o painel mostra *o quê*.
4. **Foco ao abrir.** Tudo que pede mais que uma escolha rápida abre em tela cheia, ancorado no topo, com ações fixas embaixo.
5. **Nossa identidade de botão** (retangular, raio 10). Não copiamos o oval do Fresha; copiamos a organização.

## 2. Anatomia da tela (celular, 390 px)

| Faixa | Altura | Conteúdo |
|---|---|---|
| Barra superior | 48 | Esquerda: ☰ (raiz do módulo) ou ← (tela interna). Centro/linha 1: título **ou** controle de contexto. Direita: até 3 ícones (🔍, funil, +). |
| Linha de contexto (opcional) | 44 | Período, equipe, abas. Nunca mais de uma. |
| Conteúdo | resto | Rola; a barra superior fica fixa. |
| Barra inferior do app | 56 + safe-area | Navegação principal. Nunca cobre conteúdo (padding-bottom). |
| Rodapé de ações (só detalhes e fluxos) | 64 | `[⋮] [secundário] [primário]`, fixo acima da barra inferior ou no lugar dela. |

**Título de tela no celular.** Telas internas (detalhe, fluxo) sempre têm título (← Título). Telas-raiz de módulo mostram título **só** quando a primeira linha não é um controle de contexto. Na Agenda o título "Agenda" sai: a linha de período (Qui, 30 out ▾) ocupa o lugar e a barra inferior já diz onde a pessoa está. No computador o título continua na barra superior (há espaço).

## 3. Os ícones e o que cada um abre

| Ícone | Nome | Onde | Abre |
|---|---|---|---|
| ☰ | Menu | Raiz de módulo, à esquerda | Painel lateral/tela cheia com **navegação do módulo** (ex.: Agenda › Lista de espera, Bloqueios, Checkouts em aberto, Opções de exibição). Nunca ações de um objeto. |
| ⋮ | Mais ações | Cartão, linha, cabeçalho de detalhe, rodapé de ações | **Ações do objeto** em foco (editar, duplicar, arquivar…). Menu no computador; folha com X no celular. Componente único `MoreButton`. |
| + | Criar | Direita da barra superior; na Agenda vira botão flutuante | Se há 1 tipo: abre direto o formulário. Se há vários (Agendamento, Bloqueio, Cliente, Venda): menu curto. |
| 🔍 | Buscar | Barra superior | Expande o campo na própria barra (celular) ou campo fixo (computador). Ícone preenche o botão (22 px dentro de 44). |
| Funil | Filtros | Barra superior | Painel de filtros (seção 5). Mostra **contador** do número de critérios ativos. |
| Pessoas | Equipe | Linha de contexto (Agenda) | Painel de equipe (seção 6). Mostra contador `n/total`. |

O ⋯ (horizontal) fica reservado à aba **Mais** da barra inferior (navegação). Regras: nunca ⋯ e ⋮ para a mesma função; nunca duas ações de criar; Bloquear horário mora dentro do `+`, não como botão próprio.

## 4. Botão flutuante

Máximo **um** por tela, só na **Agenda** no celular (criar agendamento), canto inferior direito, acima da barra inferior, 56 px. Nas demais telas o `+` fica na barra superior. Motivo: a Agenda tem a barra superior ocupada por período/equipe/filtros e é a tela mais usada com uma mão.

## 5. Painéis e filtros

- **Painel em tela cheia, ancorado no topo** para: filtros, equipe, opções de exibição, qualquer formulário de mais de 2 campos. Estrutura: cabeçalho (X · título · Limpar) / corpo em acordeão / rodapé fixo `[Aplicar (n)]`.
- **Folha de baixo (bottom sheet)** só para escolha rápida (≤ 6 linhas, sem formulário): ações do ⋮, escolher uma forma de pagamento, trocar status.
- **Acordeão**: cada linha tem 52 px com rótulo, **resumo do valor atual** à direita ("Todas", "2 selecionadas") e chevron. Toque expande para baixo com chips, caixas ou segmentado. Uma seção aberta por vez no celular.
- **Contador**: o botão que abre o painel mostra um balão com o número de critérios ativos (não de itens). Zero = sem balão.
- **Filtro global**: critérios de Equipe e Filtros valem para o sistema inteiro daquele dispositivo/usuário (Agenda em todas as vistas, listas, relatórios) e ficam visíveis como balão onde aplicam. Limpar volta ao padrão em todas as telas.

## 6. Equipe (seleção de profissionais)

Botão único na linha de contexto da Agenda, no lugar da fileira de chips: avatar(es) empilhados (até 3) + contador `n/total` + chevron. Painel: acordeão "Quem aparece" com "Toda a equipe" + caixa por profissional (com agendamentos do dia). Seleção múltipla em **todas** as vistas; Dia mostra uma coluna por pessoa selecionada; Semana/3 dias mostram os dias, com as pessoas agrupadas por coluna quando há mais de uma. Com mais de 3 pessoas, rolagem horizontal com cabeçalho fixo.

## 7. Semana: grade e lista (preferência)

Duas apresentações, escolha visível em Semana e lembrada por dispositivo: **Grade** (horas × dias, estilo Fresha) e **Lista** (dia a dia, a nossa). Padrão: Grade no computador, Lista no celular — mas só como ponto de partida; a pessoa muda e o sistema respeita.

## 8. Densidade e botões

Tokens relativos à fonte para botões (mantêm proporção ao mudar a densidade):

| Token | Compacto (padrão) | Confortável |
|---|---|---|
| Altura do botão | 40 px | 44 px |
| Padding horizontal | 1em | 1.15em |
| Espaço ícone-texto | .45em | .5em |
| Fonte | 14 / 600 | 15 / 600 |
| Linha de lista | 52 | 60 |
| Respiro entre seções | 12 | 16 |
| Padding de cartão | 12 / 14 | 16 / 18 |

Alvo de toque nunca abaixo de 40 px. Escala de espaço: 4 · 8 · 12 · 16 · 24.

## 9. Checkout

"Comanda" passa a se chamar **Checkout** em toda a interface. Abrir o checkout a partir da Agenda **não** muda de módulo: a rota é `/[org]/checkout/[id]`, o menu mantém Agenda ativa e o ← volta ao dia na Agenda. O Financeiro recebe os lançamentos por trás. Visões obrigatórias: **Em aberto** (rascunho), **Parciais** (saldo a receber), **Concluídos** e **Estornados/Cancelados**, com busca por cliente/número e acesso pelo ☰ da Agenda e pelo Financeiro.

## 10. Auditoria das telas (a executar, uma onda por módulo)

| Módulo | Principais desvios conhecidos | Onda |
|---|---|---|
| Agenda | Chips de profissional com seleção única; topo com ~194 pt; Filtros e Bloquear como botões grandes; folhas de baixo de altura variável | 1 |
| Clientes | Filtros em botão largo; ⋯ e ⋮ misturados no perfil | 2 |
| Catálogo | Abas e ações competindo no topo; "Mais" fora do padrão | 2 |
| Financeiro | Abas em chips + botão de ação grande; "Comandas" renomeada | 2 |
| Anamnese | Ações da ficha fora do rodapé padrão | 3 |
| Marketing/Mensagens | Canais com ações soltas | 3 |
| Ajustes e Mais | Lista plana sem resumo do valor atual | 3 |

Cada onda: aplicar a spec, capturas 390 px e 1440 px antes/depois, E2E do fluxo crítico, e marcar aqui.

## 11. Componentes do design system a criar

`MoreButton` (⋮ padrão) · `ContextBar` (período/equipe/abas) · `CountBadge` · `AccordionRow` e `AccordionList` · `FullPanel` (tela cheia ancorada no topo com rodapé fixo) · `ActionBar` (rodapé `[⋮][secundário][primário]`) · `Fab`. Nenhum componente acima de 300 linhas.
