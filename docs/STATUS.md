# Estado do projeto

> Aprovado pelo dono em 27/11/2026 (E18). Escrito por: Documentador · Revisado por: Gerente de projeto

## Onde estamos
- **Fase:** base de regras quase pronta. Ainda não há código.
- **Branch:** `chore/base-fundacao`.
- **Respostas do dono:** `docs/decisoes/2026-11-27-fundacao.md`.

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

## Falta na base
- `docs/produto/`: um arquivo por módulo (item 1 da fila).
- Pendências: e-mail de segurança quando houver domínio (E14·1); gitleaks e Dependabot (E14·3); travas automáticas do projeto antigo (item 2 da fila).

## Como continuar numa conversa nova

**Onde estão as coisas**
- Repositório `alexandrergomes1/crm-citas`, branch `chore/base-fundacao` (a base). A branch `previas` foi criada vazia, a partir de `main`.
- Respostas do dono: `docs/decisoes/2026-11-27-fundacao.md`.
- Histórico anterior ao projeto novo: repositório `crm-agenda`, branches `chore/reorganizacao-base` (pasta `docs/reorganizacao/`) e `feat/ds-premium` (spec do design). **Só se lê com autorização do dono, item por item** (`AGENTS.md` §3 regra 4; pedido (c) em `docs/decisoes/2026-11-27-fundacao.md`).

**Próximo passo**
1. O Engenheiro de DevOps abre o PR `chore/base-fundacao` → `previas`, e o Gerente de projeto pede o merge ao dono no molde (`docs/moldes/pergunta.md`).
2. Item 1 da fila (`docs/BACKLOG.md`).

**Prompt pronto para o dono colar**

```
Leia AGENTS.md do repositório alexandrergomes1/crm-citas (branch chore/base-fundacao). Estado: docs/STATUS.md. Decisões: docs/decisoes/2026-11-27-fundacao.md. Use os papéis de .claude/agents e as skills de .claude/skills em tudo, declarando papel e norma. Primeiro: abra o PR da base (chore/base-fundacao → previas), faça a revisão e me peça o merge no molde. Depois: item 1 da fila (docs/BACKLOG.md). Nada se constrói nem se copia do projeto antigo sem a minha autorização.
```
