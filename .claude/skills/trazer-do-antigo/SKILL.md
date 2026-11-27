---
name: trazer-do-antigo
description: "Trazer um item do projeto antigo (repositório alexandrergomes1/crm-agenda, só leitura) para o crm-citas. Use só quando o dono autorizou aquele item, um por um; sem a autorização, nada se copia."
---
> Rascunho para o dono aprovar (E16). Escrito por: Arquiteto de software · Revisado por: Gerente de projeto

Receita: só aponta. A regra vale onde está escrita: `AGENTS.md` §3 itens 1 a 4, §5 e §6.

1. **Autorização:** só o item que o dono autorizou, um por um, com a fala dele registrada em `docs/decisoes/` ou na spec (`AGENTS.md` §3 item 4 e §5). Sem ela: peça pela receita `falar-com-o-dono` e pare.
2. **Quem lê:** o papel da área do item (tabela do `AGENTS.md` §2; agentes em `.claude/agents/`). O antigo é só leitura.
3. **Compare** o item com os arquivos aprovados: `AGENTS.md`, `ARCHITECTURE.md`, `DESIGN.md`, `SECURITY.md` e o `src/*/AGENTS.md` da pasta. Em conflito, vale a ordem do `AGENTS.md` §6; o antigo não está nela e não vence (dedução).
4. **Decida** copiar, reescrever ou descartar, com o motivo e a norma. Decisão técnica: o papel decide e avisa em uma linha; se toca tela, dinheiro, dado de cliente ou de saúde, acesso ou produção, é pergunta ao dono (`AGENTS.md` §5).
5. **Registre** a decisão técnica em `docs/adr/` (`AGENTS.md` §3 item 3). A resposta do dono, o `documentador` registra.
6. **Revisão:** outro papel, que não trouxe o item, confere cada item copiado (`AGENTS.md` §3 itens 2 e 4), pelo tipo em `docs/guias/processo-sdd.md` §3.
7. **Entrar no produto:** só pelo fluxo, com spec aprovada e nos arquivos do plano (`AGENTS.md` §3 item 1 e §6): receitas `planejar-tarefa` e `construir-tarefa`.

- Segredo, senha ou dado pessoal ou de saúde do antigo nunca vem junto (`AGENTS.md` §6).
- Proibido adivinhar: o que o antigo usa só se aceita depois de lido no código ou na documentação oficial (`AGENTS.md` §6).
