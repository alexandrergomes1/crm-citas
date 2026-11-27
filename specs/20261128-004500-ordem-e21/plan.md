# Plano · Ordem de entrada das partes (E21·1) e repositório público

- **Escrito por:** Arquiteto de software · **Norma:** C4 (modelo de contexto), ADR
- **Spec:** `spec.md` desta pasta (Status: Draft) · **Tipo:** texto e regras (`docs/guias/processo-sdd.md`)
- **Data:** 28/11/2026
- **Construção:** só depois de "Status: Approved" e da linha "Aprovação do dono" na spec (`AGENTS.md` §3 item 1).

## 1. Arquivos que podem mudar (lista fechada)
Qualquer arquivo fora desta lista bloqueia (`AGENTS.md` §6, escopo estrito).

| Arquivo | Trecho | Quem escreve |
|---|---|---|
| `ARCHITECTURE.md` | só o §2 (coluna "Quando entra" e a frase da ordem) | Arquiteto de software |
| `SECURITY.md` | só o §1 (frase sobre repositório privado e aviso do GitHub) | Engenheiro de segurança |
| `specs/20261128-004500-ordem-e21/` | `spec.md`, `plan.md`, `tasks.md` | o papel dono de cada arquivo |
| `docs/decisoes/2026-11-27-fundacao.md` | registro das falas da E21·1 e da visibilidade | Documentador |
| `docs/STATUS.md` | estado da tarefa | Documentador |
| `CHANGELOG.md` | entrada, se o Documentador julgar que vale | Documentador |

`docs/BACKLOG.md` não muda aqui (spec §3).

## 2. Como fazer
1. Arquiteto muda o `ARCHITECTURE.md` §2 conforme spec §2 itens 1 e 2 (CA1, CA2). Nenhuma outra seção.
2. Engenheiro de segurança muda o `SECURITY.md` §1 conforme spec §2 item 3 (CA3): diz que o repositório é público e
   que o aviso privado do GitHub existe; o meio continua o da E14·1. Não manda usar o aviso do GitHub.
3. Documentador registra as falas em `docs/decisoes/` e atualiza `docs/STATUS.md` (e `CHANGELOG.md`, se valer).

## 3. Quem revisa
- **Revisor de texto:** Documentador (Diátaxis) revisa o `ARCHITECTURE.md` e o `SECURITY.md`; o Engenheiro de
  segurança confere o §2 do `ARCHITECTURE.md` e o Arquiteto confere o §1 do `SECURITY.md` (ninguém revisa o que
  escreveu, `AGENTS.md` §3 item 2). Os registros do Documentador são revisados pelo Analista de requisitos.
- **QA:** veredito, refazendo as conferências do §4.
- **Analista de requisitos:** confere CA1 a CA5 item por item.

## 4. Como verificar
- **CA4 (escopo):** `git diff --name-status previas...HEAD` só lista arquivos do §1; `git diff previas...HEAD --
  ARCHITECTURE.md SECURITY.md` só toca o §2 e o §1, respectivamente.
- **CA2:** `grep -n 'E4·3\|E21·1\|E3·2' ARCHITECTURE.md` — a frase da ordem cita E21·1 e E3·2; E4·3 não aparece
  como ordem em vigor.
- **CA3:** `grep -n -i 'privado\|público' SECURITY.md` — não diz mais "este é privado".
- **CA1 e CA5:** leitura do revisor, linha por linha.

## 5. Pedido de merge
Gerente de projeto pede no molde `docs/moldes/pergunta.md`, com o commit citado (etapa 12). **Exceção "sem CI":** em
28/11/2026 não existe CI (`.github/` só tem `.gitkeep`). Se continuar assim no pedido, ele diz "sem CI: não há
testes automáticos; prova = revisão de outro papel e veredito do QA (`AGENTS.md` §9, tipo texto)", e o dono decide
sabendo disso. Se a CI já existir, ela precisa estar verde.

## 6. Decisão técnica
Não há decisão técnica nova; **não se cria ADR**. É texto que registra decisões do dono (E21·1 e visibilidade), sem
código, banco, ferramenta ou estrutura nova.
