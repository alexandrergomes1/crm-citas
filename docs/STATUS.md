# Estado do projeto

> Aprovado pelo dono em 27/11/2026 (E18). Escrito por: Documentador · Revisado por: Gerente de projeto

## Onde estamos
- **Na `previas`:** base de regras (PR #1, E19), item 1 da fila (PR #2, E33), item 2, fundação técnica (PR #4, E37·A)
  e a ordem E21·1 no `ARCHITECTURE.md` §2 e no `SECURITY.md` (PR #3, E34). A `previas` é a branch padrão do GitHub,
  protegida pelo ruleset `protecao` (E35).
- **PRs abertos:** #5 (item 3, banco, rascunho), #6 (item 4, design system, rascunho) e o da E36 (item 4a, Entrar e
  camada de serviço, branch `feat/entrar-servico`; spec em revisão, PR ainda não aberto quando isto foi escrito).
  Specs do núcleo em branches próprias (`feat/agenda`, `feat/agendamento`, `feat/clientes`, `feat/formularios`,
  `feat/catalogo`, `feat/checkout`, `feat/caixa`).
- **Respostas do dono:** `docs/decisoes/2026-11-27-fundacao.md`.

## Pendências do dono
1. **E38 · travas do Claude:** gravar em `.claude/` pede a permissão do dono na hora; fica para quando ele estiver
   presente (`specs/20261128-005000-fundacao-tecnica/travas-claude-propostas/`, ADR 0003).
2. **Spec do item 3** (banco, PR #5): aprovar e responder E24·1 a E24·3.
3. **Spec do item 4** (design system, PR #6): aprovar e responder E25·1 a E25·3.
4. **Spec do item 4a** (Entrar e camada de serviço, E36): aprovar e responder E39·1 a E39·3.
5. **Specs do núcleo:** aprovar e responder Agenda E26·1–3, Agendamento E27·1–2, Clientes E28·1–3, Formulários
   E29·1–3, Catálogo E30·1–3, Checkout E31·1–3, Caixa E32·1–3.
6. D2 (PRs do Dependabot e a `main`): pedido separado, com os cliques exatos.

## Já aprovado

| Código | O quê |
|---|---|
| E1 | estrutura de pastas e nomes |
| E2, E2b | equipe de 15 papéis e lista de ferramentas (proposta) |
| E3 | idiomas, núcleo da primeira versão, nome provisório |
| E4 | camada única de serviço, painel admin, ordem de entrada |
| E5 | conferência AWS e ASVS, dados na UE, ficha de saúde cifrada, metas de recuperação |
| E6 | `ARCHITECTURE.md` (com as exceções E6·1 e E6·2) |
| E7 | `AGENTS.md` e nomes novos (E7·1) |
| E8 | ordem dos arquivos da base |
| E9 | molde de mensagem (`docs/moldes/pergunta.md`) |
| E10 | `DESIGN.md` e canvas em `docs/design/` |
| E11 | guia do processo (`docs/guias/processo-sdd.md`) |
| E12 | papéis do Claude, ajustes do molde, imagens do design |
| E13 | detalhes visuais (contador, pílula, funil) |
| E14 | `SECURITY.md`, `CONTRIBUTING.md`, gitleaks e Dependabot (pendência) |
| E15 | regras das 4 pastas de código; larguras 390 px e 1440 px |
| E16 | as 4 skills e as regras de cópia, bloqueio e gravação das aprovações |
| E17 | etapa 5b: o Gerente de projeto confere spec e plano antes do dono |
| E18 | ordem da fila (`docs/BACKLOG.md`, itens 1 a 10); este estado e o `README.md` seguem como referência aprovada |
| E19 | merge do PR #1 (base) na `previas` |
| E19·1 (troca) | apagar `chore/base-fundacao`; o repositório fica público |
| E20 | item 1: ler o projeto antigo só para listar os módulos; nada se copia |
| E21 | spec do item 1 e lista de módulos; nova ordem dos itens 6 a 10 (E21·1) |
| E21·2 | a ficha de saúde fica dentro de Formulários |
| E21·3 | cobrança à cliente e vale-presente entram depois do núcleo |
| E22·B | pacote da madrugada: specs e construção em PRs de rascunho, banco só local |
| E23·2·A, E23·3·A | prévia na Cloudflare depois, em spec própria; só gratuito, achou custo para e pergunta |
| E33 | merge do PR #2 (item 1), sem CI |
| E34 | spec da ordem E21·1 (PR #3) e merge |
| E35 | `previas` como branch padrão e ruleset `protecao` em `main` e `previas` |
| E36 | item novo da fila: Entrar e camada de serviço, antes do núcleo |
| E37·A | spec do item 2 (com o R15) e ordem de merge #4, #2, #3 |
| E38·A | ligar as travas do Claude em `.claude/` num PR próprio (pendente da permissão na hora) |

## Item 2 da fila · fundação técnica
- **Situação:** feito, PR #4 juntado na `previas` (E37·A, 28/11/2026).
- **Spec:** `specs/20261128-005000-fundacao-tecnica/`.

## Falta na base
- Pendências: e-mail de segurança quando houver domínio (E14·1); travas do Claude Code em `.claude/` (E38·A).
- Apagar a branch `chore/base-fundacao`: o acesso da IA foi recusado; o dono apaga no PR #1 (E19·1).

## Como continuar numa conversa nova

**Onde estão as coisas**
- Repositório `alexandrergomes1/crm-citas`: a base (PR #1), os itens 1 e 2 (PRs #2 e #4) e a ordem E21·1 (PR #3) estão na `previas`.
- Respostas do dono: `docs/decisoes/2026-11-27-fundacao.md`.
- Histórico anterior ao projeto novo: repositório `crm-agenda`, branches `chore/reorganizacao-base` (pasta `docs/reorganizacao/`) e `feat/ds-premium` (spec do design). **Só se lê com autorização do dono, item por item** (`AGENTS.md` §3 regra 4; pedido (c) em `docs/decisoes/2026-11-27-fundacao.md`).

**Próximo passo**
1. Dono: ler o relatório da madrugada e responder as pendências acima.
2. Item 4a: abrir o PR da E36 e levar a spec ao dono.

**Prompt pronto para o dono colar**

```
Leia AGENTS.md do repositório alexandrergomes1/crm-citas (branch previas). Estado: docs/STATUS.md. Decisões: docs/decisoes/2026-11-27-fundacao.md. Use os papéis de .claude/agents e as skills de .claude/skills em tudo, declarando papel e norma. Primeiro: as pendências do dono em docs/STATUS.md. Depois: primeiro item livre da fila (docs/BACKLOG.md). Nada se constrói nem se copia do projeto antigo sem a minha autorização.
```
