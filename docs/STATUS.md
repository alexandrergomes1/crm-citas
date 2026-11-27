# Estado do projeto

> Aprovado pelo dono em 27/11/2026 (E18). Escrito por: Documentador · Revisado por: Gerente de projeto

## Onde estamos
- **Fase:** base de regras na `previas` (PR #1, E19); item 1 da fila (módulos em `docs/produto/`) em revisão. Ainda não há código.
- **Branch:** `docs/produto-modulos`.
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
| E19 | merge do PR #1 (base) na `previas` |
| E19·1 (troca) | apagar `chore/base-fundacao`; o repositório fica público |
| E20 | item 1: ler o projeto antigo só para listar os módulos; nada se copia |
| E21 | spec do item 1 e lista de módulos; nova ordem dos itens 6 a 10 (E21·1) |
| E21·2 | a ficha de saúde fica dentro de Formulários |
| E21·3 | cobrança à cliente e vale-presente entram depois do núcleo |

## Falta na base
- Pendências: e-mail de segurança quando houver domínio (E14·1); gitleaks e Dependabot (E14·3); travas automáticas do projeto antigo (item 2 da fila).
- Apagar a branch `chore/base-fundacao`: o acesso da IA foi recusado; o dono apaga no PR #1 (E19·1).
- Corrigir `ARCHITECTURE.md` §2 (ordem, E21·1) e `SECURITY.md` §1 ("privado", E19·1 troca) no PR `docs/ordem-e21`.
- E22 (núcleo de uma vez): resposta pendente; sem ela, segue a opção A (só specs).

## Como continuar numa conversa nova

**Onde estão as coisas**
- Repositório `alexandrergomes1/crm-citas`: a base está na `previas` (PR #1); o item 1 está na branch `docs/produto-modulos`.
- Respostas do dono: `docs/decisoes/2026-11-27-fundacao.md`.
- Histórico anterior ao projeto novo: repositório `crm-agenda`, branches `chore/reorganizacao-base` (pasta `docs/reorganizacao/`) e `feat/ds-premium` (spec do design). **Só se lê com autorização do dono, item por item** (`AGENTS.md` §3 regra 4; pedido (c) em `docs/decisoes/2026-11-27-fundacao.md`).

**Próximo passo**
1. Revisão do PR do item 1 (`docs/produto-modulos` → `previas`) e pedido de merge ao dono no molde (`docs/moldes/pergunta.md`).
2. PR `docs/ordem-e21` (`ARCHITECTURE.md` §2 e `SECURITY.md` §1) e resposta do dono ao E22.
3. Item 2 da fila (`docs/BACKLOG.md`).

**Prompt pronto para o dono colar**

```
Leia AGENTS.md do repositório alexandrergomes1/crm-citas (branch previas). Estado: docs/STATUS.md. Decisões: docs/decisoes/2026-11-27-fundacao.md. Use os papéis de .claude/agents e as skills de .claude/skills em tudo, declarando papel e norma. Primeiro: termine o PR do item 1 (docs/produto-modulos → previas) e me peça o merge no molde. Depois: primeiro item livre da fila (docs/BACKLOG.md). Nada se constrói nem se copia do projeto antigo sem a minha autorização.
```
