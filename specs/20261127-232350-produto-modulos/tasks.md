# Tarefas · Módulos do produto em `docs/produto/`

- **Escrito por:** Arquiteto de software · **Norma:** C4, ADR · **Plano:** `plan.md` desta pasta · 27/11/2026

| # | Passo | Papel |
|---|---|---|
| 1 | Conferir spec, plano e tarefas com a análise do Spec Kit (etapa 5) | Analista de requisitos |
| 2 | Revisar fluxo e escopo da spec e do plano (etapa 5b) | Gerente de projeto |
| 3 | Levar E21·1, E21·2 e E21·3 ao dono, num só recado, e avisar no celular | Gerente de projeto |
| 4 | Registrar as respostas em `docs/decisoes/2026-11-27-fundacao.md` | Documentador |
| 5 | Ajustar a tabela da spec §3 às respostas e gravar "Status: Approved" e "Aprovação do dono" | Analista de requisitos |
| 6 | Se a tabela mudou, ajustar a lista de arquivos do `plan.md` §2 | Arquiteto de software |
| 7 | Escrever um arquivo por módulo no molde do `plan.md` §3, só a partir da spec §3, sem abrir o antigo | Engenheiro de software |
| 8 | Escrever `docs/produto/README.md` (frase do sistema e índice) e apagar `docs/produto/.gitkeep` | Engenheiro de software |
| 9 | Rodar as conferências do `plan.md` §5 e corrigir o que falhar antes de entregar | Engenheiro de software |
| 10 | Revisar o texto e rodar §5.1 a §5.5; anexar a saída ao PR; "Bloqueia" volta ao passo 7 | Documentador (revisor de texto) |
| 11 | Veredito, refazendo §5.1 a §5.3 | QA |
| 12 | Conferir o pedido item por item (etapa 10) | Analista de requisitos |
| 13 | Atualizar `docs/BACKLOG.md`, `docs/STATUS.md` e, se valer, `CHANGELOG.md`, no mesmo PR | Documentador |
| 13b | Ler o que o Documentador escreveu (passos 4 e 13: `docs/decisoes/2026-11-27-fundacao.md`, BACKLOG, STATUS, CHANGELOG) e devolver o que achar; "Bloqueia" volta ao Documentador | Gerente de projeto |
| 14 | Pedir o merge no molde (`docs/moldes/pergunta.md`), com o commit; como a CI ainda não existe (entra no item 2 da fila), o pedido traz a exceção "merge sem CI" para o dono autorizar, como no E19, com as conferências do `plan.md` §5 no lugar da CI | Gerente de projeto |
| 15 | Gravar "Aprovação do merge" na spec e juntar só esse commit | Engenheiro de DevOps |
