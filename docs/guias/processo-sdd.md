# Guia do processo · Spec-Driven Development com o Spec Kit

> **Aprovado pelo dono em 27/11/2026 (E11).** Escrito pelo Gerente de projeto e pelo Analista de requisitos.
> Normas: Kanban (fluxo), IEEE 29148 (requisitos) e o método oficial do GitHub Spec Kit.
> Regras de fundo: `AGENTS.md` §3 a §5, §8 e §9. Este guia diz o passo a passo.

## 1. O que é
Toda tarefa começa por uma **spec** (o que fazer e por quê), depois o **plano** (como) e as **tarefas** (os passos).
Só então se constrói. O Spec Kit é a ferramenta que gera e confere esses três arquivos. Cada tarefa tem a sua pasta
em `specs/AAAAMMDD-HHMMSS-nome/` com `spec.md`, `plan.md` e `tasks.md`.

Palavras usadas aqui: **branch** (cópia separada do projeto para uma tarefa) · **commit** (um pacote de mudança
salvo) · **PR** (pedido para juntar uma branch na outra) · **merge** (juntar) · **CI** (testes automáticos do GitHub
a cada envio) · **prévia** (endereço onde o dono vê a mudança antes de ir para o ar).

## 2. Passo a passo de uma tarefa

| # | Etapa | Papel | O que sai | Dono? |
|---|---|---|---|---|
| 1 | Pegar a tarefa | Gerente de projeto | o primeiro item livre de `docs/BACKLOG.md` ou o pedido literal do dono | não |
| 2 | Abrir a branch | Engenheiro de DevOps | `tipo/area-assunto`, a partir da `previas` | não |
| 3 | Escrever a spec | Analista de requisitos | `spec.md`: o que muda, critérios de aceite, até 3 dúvidas, "Assumptions" | — |
| 4 | Planejar | Arquiteto de software | `plan.md` (como e quais arquivos podem mudar) e `tasks.md` | — |
| 5 | Conferir os três | Analista de requisitos | a análise do Spec Kit sem problema crítico | — |
| 6 | Ficha visual (só tela) | Designer de produto + Revisor de design | imagens de antes e depois, nas larguras de teste do `DESIGN.md` | **sim** |
| 7 | Aprovação | Dono | spec com "Status: Approved" e a linha "Aprovação do dono" (fala literal, data, link) | **sim** |
| 8 | Construir | Engenheiro de software | só os arquivos do plano; testes junto | não |
| 9 | Revisar | os revisores do tipo (§3) e o QA | relatórios e veredito; nada com "Bloqueia" | não |
| 10 | Conferir o pedido | Analista de requisitos | o que o dono pediu foi cumprido, item por item | não |
| 11 | Fechar | Documentador | fila, estado e registros atualizados no mesmo PR | não |
| 12 | Pedir o merge | Gerente de projeto | mensagem no molde, com o commit e a CI verde; em tela, o link da prévia | **sim** |
| 13 | Juntar | Engenheiro de DevOps | grava "Aprovação do merge" na spec (fala, data, link, commit) e junta só esse commit | não |

- Toda etapa marcada "sim" sai com o aviso no celular (`AGENTS.md` §7).
- Depois do pedido de merge, só entra na branch o commit que grava a "Aprovação do merge". Qualquer outra mudança
  pede revisão e pedido novos.

## 3. Quem revisa cada tipo de trabalho
O QA dá o veredito em todos os tipos.

| Tipo | Revisores | Prova (`AGENTS.md` §9) |
|---|---|---|
| Código | Revisor de código | testes de unidade e CI verde |
| Banco | Engenheiro de dados (quem não fez) e Auditor de risco | teste de isolamento por estúdio e CI verde |
| Tela | Revisor de design | teste de ponta a ponta e conferência do dono na prévia (junto do pedido de merge) |
| Segurança, dinheiro, login, ficha de saúde, integração | Auditor de risco e Engenheiro de segurança | o da área, mais a revisão de risco |
| Texto e regras | outro papel que não escreveu | revisão |

## 4. Paradas do dono por tarefa
- **Tela:** ficha visual · aprovação da spec · pedido de merge com o link da prévia (3 paradas).
- **Código, banco e integração:** aprovação da spec · pedido de merge (2 paradas).
- **Texto e regras:** aprovação · pedido de merge (2 paradas).
- Outra parada só se a construção achar algo que a spec não cobre.

## 5. O Spec Kit
- Ordem oficial: criar a spec → esclarecer dúvidas → planejar → gerar tarefas → analisar → implementar → convergir
  (implementar e convergir se repetem até a ferramenta dizer que convergiu).
- Na instalação: pastas com data e hora (`feature_numbering: timestamp`) e o nome da branch fixado no padrão
  `tipo/area-assunto`, porque o Spec Kit sozinho usa outro padrão.
- Os nomes exatos dos comandos entram aqui depois de instalada a versão, lida a documentação oficial dela.
- A constituição do Spec Kit só aponta para o `AGENTS.md`.

## 6. Lacuna
As larguras de teste das telas (celular e computador) ainda não estão no `DESIGN.md`. Entram nele com aprovação do
dono antes da primeira tela.
