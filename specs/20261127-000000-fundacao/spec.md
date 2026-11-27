# Feature Specification: Fundação do crm-citas

**Feature Branch**: `chore/base-fundacao`
**Created**: 2026-11-27
**Status**: Approved
**Aprovação do dono**: "P-E5·4: sim, vamos começar um novo em folha. (...) https://github.com/alexandrergomes1/crm-citas Criei esta pasta. Construa profissionalmente como falei." · 2026-11-27 · https://claude.ai/code/session_018cV8b7RjDnCe1vNegjYzNy
**Tipo**: Configuração, trava, CI (nível C) · **Item da fila**: 1 · **Módulo**: nenhum (base do repositório)
**Pedido do dono**: a resposta acima à pergunta P-E5·4 (registro em `docs/decisoes/2026-11-27-projeto-novo.md`)
**Input**: "Repositório novo do zero, ligado só ao banco, com a base nova e o design aprovado; módulos do antigo entram um a um, já no design novo."

## Como está hoje (linha de base)
O repositório `crm-citas` foi criado pelo dono e recebeu a base nova escrita no `crm-agenda` (`docs/reorganizacao/nova-base/`): `AGENTS.md`, `CLAUDE.md`, `README.md`, `ARCHITECTURE.md`, `DESIGN.md` (6ª edição), `CONTRIBUTING.md`, `SECURITY.md`, `GLOSSARY.md`, guias em `docs/guias/`, moldes, módulos em `docs/produto/modulos/` e o `AGENTS.md` de cada pasta. O `crm-agenda` fica congelado (`docs/adr/0001-repositorio-novo.md`).

## Fora do escopo
- Telas e componentes de módulo (entram pelos itens 2 em diante, cada um com spec própria).
- Ligação ao banco real (chaves, rotina de migrations ativa) e qualquer publicação: só na virada, por spec própria.
- Mudança de regra nos guias, em `DESIGN.md` ou na constituição além de consertar caminhos.

## Clarifications

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Trabalhar no repositório novo com as mesmas proteções (Priority: P1)
Quem trabalha no projeto (IA ou pessoa) abre o `crm-citas` e encontra as regras, os guias, as travas e o Spec Kit funcionando, sem depender do repositório antigo.
**Why this priority**: o dono exige que as travas voltem a valer antes de qualquer trabalho.
**Independent Test**: os testes das travas passam; o início de sessão cita `crm-citas` e a fila nova.
**Acceptance Scenarios**:
1. **Given** uma conversa nova, **When** ela começa, **Then** o início de sessão mostra a branch, o item 1 da fila e nenhuma pergunta pendente.
2. **Given** um envio direto à `previas` ou à `main`, **When** a IA tenta, **Then** a trava barra.

### User Story 2 - App mínimo e CI (Priority: P2)
O repositório instala, checa tipos, lint, testes e build, e a CI do GitHub roda essas checagens e o banco do zero com as migrations copiadas.
**Independent Test**: CI verde no PR da fundação.

### Edge Cases
- GitHub sem a branch `previas`: a trava barra editar migration (bloqueia por segurança) e o início de sessão lê o arquivo local.

## Requirements *(mandatory)*

### Functional Requirements
- **FR-001**: Base de regras e guias no lugar final, com todo caminho citado em `AGENTS.md`, `CLAUDE.md` e `README.md` existindo.
- **FR-002**: Travas do `crm-agenda` copiadas (`.claude/settings.json`, `.claude/hooks/`, `.githooks/`, `scripts/conferir-pedido.mjs`), com caminhos e nome do repositório ajustados e testes verdes.
- **FR-003**: Agentes e skills da casa em `.claude/` como cascas finas que só apontam para `docs/guias/`.
- **FR-004**: Spec Kit v1.4.4 instalado; `.specify/memory/constitution.md` só aponta para `AGENTS.md`; moldes do projeto em `.specify/templates/overrides/`.
- **FR-005**: App mínimo (TanStack Start) que instala e passa nas checagens.
- **FR-006**: Migrations, seeds e testes do banco copiados do `crm-agenda` sem mudança.
- **FR-007**: CI do GitHub e molde de PR.
- **FR-008**: Documentos de controle novos: fila, estado, página do dono, plano, fila de depois, decisão P-E5·4, ADR 0001.

## Success Criteria *(mandatory)*

### Measurable Outcomes
- **SC-001**: testes das travas, do gancho de envio e das conferências 100 % verdes.
- **SC-002**: CI verde no PR da fundação (ou prova local, se faltar minuto do GitHub).
- **SC-003**: nenhum caminho citado em `AGENTS.md`, `CLAUDE.md` e `README.md` sem arquivo.

## Assumptions
- Os endereços de prévia e produção já usam o nome `crm-citas`; os Workers ainda precisam ser criados na Cloudflare (pendência do dono).
- A ordem dos itens de módulo na fila segue a tabela de módulos do plano do `crm-agenda`; o dono pode mudar.

## Aprovação do merge
<!-- Preenchida só depois da autorização clara do dono ao pedido de merge, num commit que mexe só nesta seção (docs/guias/git-e-deploy.md §Merge de tarefa). -->
- PR nº: · Commit autorizado (SHA): · Resposta do dono (literal): "" · Data: · Link da conversa:

## Seção do tipo
O que muda no comportamento da IA: nada de novo. As travas do `crm-agenda` voltam a valer aqui, iguais, apontando para os guias novos e para o repositório `alexandrergomes1/crm-citas`.
