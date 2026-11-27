# Guia · Porte de módulo

Receita para portar um módulo do sistema de origem (`alexandrergomes1/beauty-system`, Next.js App Router) para o TanStack Start sem mudar as telas nem as regras. É conteúdo todo do projeto: nenhuma prática de mercado trata deste porte.

## Princípio
Trocar só o encanamento: rotas, carregamento de dados, ações e navegação. A tela (componentes `*Screen` e filhos) e `src/domain` continuam iguais. As consultas de `src/data` podem ser reescritas para caber no orçamento, sem mudar o que a tela recebe. Mudança visual não entra no porte: vai para o fluxo de tela (`processo-sdd.md`).

## Leia antes
- A spec aprovada da tarefa (`specs/NNN-nome/`).
- `docs/reference/porting.md`: como é o módulo na origem, tabela de troca Next → TanStack, adaptadores já feitos (`src/lib/nav` e os de `src/data`).
- `servidor.md` para cada ação, com o orçamento de idas ao banco.
- Função de leitura nova no banco: `banco.md`, e o plano de execução da consulta (o orçamento conta idas, não custo).

## Passos
1. Liste as rotas, ações e chamadas `revalidatePath` do módulo. Escreva a lista no PR.
2. Copie os componentes de tela sem mudar a aparência; troque só os imports de navegação para o adaptador `src/lib/nav`.
3. Crie a rota com `loader` e as server functions, uma por ação. Uma ação da tela = uma ida ao servidor.
4. Registre cada server function nova no teste do orçamento, com o número esperado.
5. Traga os E2E do módulo da origem **sem editar as asserções**.
6. Abra o PR e cite o resultado da CI.
7. Capturas nas duas larguras de conferência (`testes.md`), comparadas com o sistema de origem.

## Proibido
- Mudar aparência ou regra de negócio no porte.
- Deixar o orçamento para depois.
- Import de `next/*` no módulo portado (a CI reprova).

## Pare e pergunte
- Uma asserção de E2E precisa mudar: é sinal de mudança de comportamento.
- O módulo não tem spec e a origem é ambígua.
- O orçamento não fecha sem mudar o que a tela recebe.

## Pronto quando
E2E do módulo iguais e passando na CI, orçamento cumprido e medido, capturas sem diferença visual, revisores do nível do PR sem "Bloqueia" (`revisao.md`).

## Origem
`.claude/skills/port-module/SKILL.md` · `docs/reference/porting.md` · `docs/reference/project.md` (repositório de origem) · `.github/workflows/ci.yml` (zero `next/*`).
