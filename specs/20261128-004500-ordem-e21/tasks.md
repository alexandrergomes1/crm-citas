# Tarefas · Ordem de entrada das partes (E21·1) e repositório público

- **Escrito por:** Arquiteto de software · **Norma:** C4, ADR · **Plano:** `plan.md` desta pasta
- Nada começa antes de "Status: Approved" na spec.

| # | Tarefa | Papel | Arquivo | Pronto quando |
|---|---|---|---|---|
| T1 | Nova ordem na coluna "Quando entra" e frase da ordem citando E21·1 | Arquiteto de software | `ARCHITECTURE.md` §2 | CA1, CA2 |
| T2 | Repositório público; aviso privado do GitHub existe; meio segue E14·1 | Arquiteto de software (o Engenheiro de segurança só tem ferramentas de leitura) | `SECURITY.md` §1 | CA3 |
| T3 | Registrar as falas do dono (E21·1 e troca do E19·1) só se o PR #2 (`docs/produto-modulos`) não tiver entrado antes; se entrou, nada a gravar (evita conflito) | Documentador | `docs/decisoes/2026-11-27-fundacao.md` | falas literais com data e link, ou "já gravado pelo PR #2" |
| T4 | Atualizar estado (e versões, se valer) | Documentador | `docs/STATUS.md`, `CHANGELOG.md` | estado da tarefa correto |
| T5 | Revisão cruzada (quem escreveu não revisa) | Documentador (T1, `ARCHITECTURE.md`); Engenheiro de segurança (T2, `SECURITY.md`); Analista de requisitos (T3, T4) | — | sem "Bloqueia" (CA5) |
| T6 | Conferências do `plan.md` §4 e veredito | QA | — | escopo só do `plan.md` §1 (CA4) |
| T7 | Conferência do pedido, CA1 a CA5 | Analista de requisitos | — | todos cumpridos |
| T8 | Pedido de merge no molde, com commit e exceção "sem CI" se a CI não existir | Gerente de projeto | — | autorização do dono gravada na spec |

Ordem: T1 e T2 (Arquiteto) → T3, T4 → T5 → T6 → T7 → T8.
