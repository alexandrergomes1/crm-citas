# ADR 0001 · Revisão da spec e do plano pelo Gerente e skills só por nome

- **Status:** Decisão 1 (etapa 5b): Proposto, aguarda aprovação do dono (E17), porque é mudança de processo e não só decisão técnica. Decisão 2 (campo das skills): Aceita, decisão técnica · 27/11/2026
- **Autor:** Arquiteto de software · **Revisão:** pendente (outro papel)
- **Aviso ao dono:** as duas foram avisadas ao dono na mensagem do E16, em 27/11/2026 (`AGENTS.md` §3 item 3); a 1 vai à aprovação no E17.

## Contexto
1. Entre a conferência do Spec Kit (etapa 5) e a aprovação do dono (etapa 7), ninguém além de quem escreveu revisava spec e plano juntos, e o `AGENTS.md` §3 item 2 pede que quem constrói não revise.
2. As skills `construir-tarefa` e `trazer-do-antigo` têm efeito grande (construir e enviar; trazer item do projeto antigo). Sem trava, o Claude pode carregá-las sozinho quando acha que o assunto bate.

## Decisão
1. Etapa **5b** em `docs/guias/processo-sdd.md` §2: o Gerente de projeto confere fluxo e escopo da spec e do plano (não os requisitos) em todo tipo de trabalho e devolve o achado a quem escreveu, depois da etapa 5 e antes da ficha visual e da aprovação do dono.
2. `disable-model-invocation: true` no frontmatter de `.claude/skills/construir-tarefa/SKILL.md` e `.claude/skills/trazer-do-antigo/SKILL.md`: elas só rodam quando chamadas pelo nome (`/construir-tarefa`, `/trazer-do-antigo`).

## Motivo e norma
1. Norma: ISTQB, revisão estática (achar defeito no documento antes de construir custa menos). O Gerente cuida do fluxo e não escreveu nem a spec nem o plano; os requisitos continuam com o Analista de requisitos.
2. A documentação oficial do Claude Code (https://code.claude.com/docs/en/skills, "Control who invokes a skill") recomenda esse campo para fluxos com efeito colateral ou em que a hora de rodar importa.

## Consequências
1. Uma revisão a mais por tarefa, sem parada nova do dono. O que o Gerente achar volta a quem escreveu antes de ir ao dono.
2. As duas skills não são carregadas automaticamente nem pré-carregadas em subagentes (efeito descrito na mesma documentação). Quem orquestra precisa chamá-las pelo nome. `planejar-tarefa` e `falar-com-o-dono` continuam automáticas.
3. Para desfazer: tirar a linha 5b do guia, a etapa do agente e o passo da skill, ou tirar o campo do frontmatter. Fica registrado num ADR novo, que substitui este.
