---
name: planejar-tarefa
description: "Planejar uma tarefa do crm-citas, das etapas 1 a 7 do docs/guias/processo-sdd.md: pegar a tarefa, abrir a branch, spec, plano, conferência, ficha visual (só tela) e parada na aprovação do dono. Use quando a tarefa ainda não tem spec aprovada."
---
> Aprovado pelo dono em 27/11/2026 (E16). Escrito por: Arquiteto de software · Revisado por: Gerente de projeto

Receita: só aponta. A regra vale onde está escrita: `AGENTS.md` §3 a §5 e §7, `docs/guias/processo-sdd.md` §2 a §4.

1. **Tarefa:** chame `gerente-projeto`. Só o primeiro item livre de `docs/BACKLOG.md` ou o pedido literal do dono (`AGENTS.md` §5).
2. **Branch:** chame `engenheiro-devops`: `tipo/area-assunto`, a partir da `previas` (`AGENTS.md` §8).
3. **Spec:** chame `analista-requisitos`: `spec.md` com critérios de aceite, até 3 dúvidas com recomendação e "Assumptions" (`AGENTS.md` §4).
4. **Plano:** chame `arquiteto-software`: `plan.md` (como e quais arquivos podem mudar), `tasks.md` e ADR em `docs/adr/` se houver decisão técnica, avisada ao dono em uma linha (`AGENTS.md` §3 item 3).
5. **Conferir os três:** chame `analista-requisitos` para a análise do Spec Kit, sem problema crítico (`processo-sdd.md` §2, etapa 5).
5b. **Revisar spec e plano:** chame `gerente-projeto`, em todo tipo, antes da ficha visual e do dono (`processo-sdd.md` §2, etapa 5b).
6. **Ficha visual, só tela:** `designer-produto` faz as imagens de antes e depois nas larguras do `DESIGN.md`; `revisor-design` confere antes do dono. Quem fala é o Designer de produto, no molde "Ficha visual" (`docs/moldes/pergunta.md`). Pare e avise no celular pela receita `falar-com-o-dono` (`AGENTS.md` §7).
7. **Aprovação:** `analista-requisitos` monta a mensagem "Aprovação da spec" (`docs/moldes/pergunta.md`). **Pare aqui** e avise no celular (`AGENTS.md` §7).

- Aprovada = "Status: Approved" e a linha "Aprovação do dono" (fala literal, data, link) (`AGENTS.md` §3 item 1).
- Depois de cada resposta do dono, `documentador` registra em `docs/decisoes/` o que fica fora de spec (`.claude/agents/documentador.md`). A linha "Aprovação do dono" na spec, o `analista-requisitos` grava (E16·3).
- Quem escreveu um arquivo não o revisa (`AGENTS.md` §3 item 2). Construir só pela receita `construir-tarefa`.
- Acesso, dado de cliente ou de saúde, dinheiro e produção nunca em "Assumptions" (`AGENTS.md` §4).
