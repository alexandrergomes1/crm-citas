---
name: construir-tarefa
description: "Construir, revisar e pedir o merge de uma tarefa do crm-citas, das etapas 8 a 13 do docs/guias/processo-sdd.md. Use só quando a spec da tarefa tem Status: Approved e a linha Aprovação do dono."
---
> Rascunho para o dono aprovar (E16). Escrito por: Arquiteto de software · Revisado por: (a preencher)

Receita: só aponta. A regra vale onde está escrita: `AGENTS.md` §3, §6, §8 e §9, `docs/guias/processo-sdd.md` §2 a §4.

0. **Confira a spec:** sem "Status: Approved" e "Aprovação do dono", pare e use `planejar-tarefa` (`AGENTS.md` §3 item 1).
8. **Construir:** só os arquivos do plano, com testes (`AGENTS.md` §6). Código: `engenheiro-software`. Banco: `engenheiro-dados`. Integração: `engenheiro-integracoes`. Antes de enviar: checagem de tipos, lint e testes (`AGENTS.md` §1).
9. **Revisar:** os revisores do tipo (`processo-sdd.md` §3), nunca quem construiu (`AGENTS.md` §3 item 2):
   - Código: `revisor-codigo` · Banco: `engenheiro-dados` (outra instância, que não fez) e `auditor-risco` · Tela: `revisor-design`.
   - Segurança, dinheiro, login, ficha de saúde, integração: `auditor-risco` e `engenheiro-seguranca`.
   - Por último, `analista-qa` junta os relatórios e dá o veredito com a prova do tipo (`AGENTS.md` §9). Algo com "Bloqueia": não segue (`processo-sdd.md` §2, etapa 9).
10. **Conferir o pedido:** `analista-requisitos`, item por item.
11. **Fechar:** `documentador` atualiza fila, estado e registros no mesmo PR.
12. **Pedir o merge:** `engenheiro-devops` informa a CI; `gerente-projeto` manda o "Pedido de merge" (`docs/moldes/pergunta.md`) com o commit, a CI verde e, em tela, o link da prévia. **Pare** e avise no celular (`AGENTS.md` §7).
13. **Juntar:** `engenheiro-devops` grava "Aprovação do merge" na spec (fala, data, link, commit) e junta só esse commit (`AGENTS.md` §8).

- Depois do pedido, só entra o commit da "Aprovação do merge"; outra mudança pede revisão e pedido novos (`processo-sdd.md` §2).
- A construção achou algo que a spec não cobre: pare e pergunte ao dono (`AGENTS.md` §4). Mesmo erro duas vezes: pare e relate (`AGENTS.md` §6).
- Produção (`previas` → `main`): só com "Pedido de publicação" e autorização clara do dono (`AGENTS.md` §8). A IA nunca publica nem aplica mudança no banco remoto (`AGENTS.md` §1).
