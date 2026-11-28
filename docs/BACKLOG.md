# Fila de tarefas

> Aprovado pelo dono em 27/11/2026 (E18). Escrito por: Documentador · Revisado por: Gerente de projeto

**Como usar:** o primeiro item livre é o que se faz (`AGENTS.md` §5). Só o Documentador muda este arquivo.
Cada item entra por spec própria (`docs/guias/processo-sdd.md`).

**Ordem aprovada pelo dono (E18 e E21·1).** A ordem dos itens 6 a 10 vem da E21·1, que substitui a da E4·3 e a da E18; a API pública entra por último, depois do marketplace, e só quando precisar (E21·1, E4·1). O item 4a entra logo
antes do núcleo (E36·A); a spec "Agenda · visões e horário de funcionamento" entra logo depois da Agenda (E57·B); leva "4a" para não mudar os números citados nas decisões E18 e E21·1. Fontes: pedidos anteriores ao E1, E3·2, E4·3, E8, E14·3, pedido de módulos de ajuda e IA
(`docs/decisoes/2026-11-27-fundacao.md`) e `ARCHITECTURE.md` §2.

| # | Tarefa | Fonte | Situação |
|---|---|---|---|
| 1 | Terminar a base: um arquivo por módulo em `docs/produto/`, com autorização do dono para ler o projeto antigo | E8 (item 8), pedido (b) anterior ao E1, E20, E21, E33 | feito (PR #2) |
| 2 | Fundação técnica: ferramentas, app vazio, Spec Kit instalado, travas automáticas (gitleaks e Dependabot, E14·3) e CI; travas automáticas: trazer as do projeto antigo pela skill trazer-do-antigo, com autorização do dono item por item (pedido da mensagem 41) | `AGENTS.md` §1, E14·3, Pedido (travas) | feito (PR #4) |
| 3 | Ligar o banco existente, tabela por tabela, com autorização do dono item por item | pedido (a) anterior ao E1, `AGENTS.md` §3 regra 4 | na `previas` dentro do PR #7 (E49·A); aprovação do merge a gravar na spec (PR #5 segue aberto sem uso) |
| 4 | Design system no código | `DESIGN.md` | na `previas` dentro do PR #7 (E49·A); aprovação do merge a gravar na spec (PR #6 segue aberto sem uso) |
| 4a | Entrar e camada de serviço (login, sessão, 6 portas, auditoria, base de idiomas) | E36·A, E4·1, E3·1 | feito (PR #7) |
| 5 | Núcleo, um módulo por spec: Agenda, Agenda · visões e horário de funcionamento (formatos em cards, grade no horário de funcionamento, lupa no celular, resumo da coluna, dias marcados), Agendamento, Clientes, Formulários, Catálogo, Checkout, Caixa | E3·2, `ARCHITECTURE.md` §2, E57·B | Agenda: em planejamento (`feat/agenda`); os outros: livre |
| 6 | Os outros módulos, um por vez, incluindo a central de ajuda e o assistente de IA | E3·2, pedido do dono (módulos), E21·1 | livre |
| 6a | Perfis e permissões ajustáveis (por módulo e ação, por pessoa, papéis padrão personalizáveis); até lá só o dono usa, com acesso total | E42·A (ajustada) | livre |
| 7 | Painel admin básico | E4·2, E4·3, E21·1 | livre |
| 8 | Cadastro de estúdio e cobrança da assinatura | E4·3, E21·1 | livre |
| 9 | Portal público do estúdio (reserva online) | E4·3, E21·1 | livre |
| 10 | Marketplace | E4·3, E21·1 | livre |
