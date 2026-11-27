# Feature Specification: [NOME DA TAREFA]

<!-- Molde do projeto (override do Spec Kit). Os títulos em inglês são os que os comandos do Spec Kit procuram: não traduza. Conteúdo em português simples, sem detalhe técnico (isso vai no plano). -->

**Feature Branch**: `tipo/area-assunto`
**Created**: [DATA]
**Status**: Draft · Approved · Done · Superseded (por NNN) · Cancelled. Approved só com a linha "Aprovação do dono" preenchida.
**Aprovação do dono**: "[resposta literal]" · [DATA] · [link da conversa]
**Tipo**: um dos tipos de `docs/guias/processo-sdd.md` §Tipos de trabalho · **Item da fila**: #NNN · **Módulo**: `docs/produto/modulos/<mod>.md`, recursos <IDs>
**Pedido do dono**: citação literal, data e link (ou o item da fila)
**Input**: "$ARGUMENTS"

## Como está hoje (linha de base)
O app e o arquivo do módulo como estão, com arquivo ou imagem. É o ponto de partida, não se reconfirma (`AGENTS.md` §3).

## Fora do escopo
O que esta spec não faz.

## Clarifications
<!-- Formato do Spec Kit. Uma linha por resposta do dono: `- Q: <pergunta> → A: <opção escolhida> ("<resposta literal>")`, sob `### Session AAAA-MM-DD`. -->

## User Scenarios & Testing *(mandatory)*
Jornadas de quem usa, em ordem de importância (P1, P2…), cada uma testável sozinha.

### User Story 1 - [título] (Priority: P1)
[a jornada em linguagem simples]
**Why this priority**: …
**Independent Test**: …
**Acceptance Scenarios**:
1. **Given** [situação], **When** [ação], **Then** [resultado]

### Edge Cases
- O que acontece quando …?

## Requirements *(mandatory)*

### Functional Requirements
- **FR-001**: O sistema DEVE …
- Dúvida: `[NEEDS CLARIFICATION: pergunta]`. No máximo 3 por spec, só para o que muda tela, dinheiro, dado de cliente, acesso ou produção e não está na linha de base.

### Key Entities *(se houver dados)*
- **[Entidade]**: o que representa (sem detalhe de banco).

## Success Criteria *(mandatory)*

### Measurable Outcomes
- **SC-001**: resultado medível, do ponto de vista de quem usa.

## Assumptions
Palpites informados pela prática de mercado, em português simples. Vão à vista na mensagem de aprovação; o dono pode recusar qualquer um.

## Aprovação do merge
<!-- Preenchida só depois da autorização clara do dono ao pedido de merge, num commit que mexe só nesta seção (docs/guias/git-e-deploy.md §Merge de tarefa). -->
- PR nº: · Commit autorizado (SHA): · Resposta do dono (literal): "" · Data: · Link da conversa:

## Seção do tipo
Campos de quem usa que `docs/guias/processo-sdd.md` §Tipos de trabalho define para o tipo (tela: estados carregando, vazio, erro e sucesso, larguras, imagem aprovada, inventário de recursos; dados: o que um estúdio pode e não pode ver). O lado técnico vai no plano.
