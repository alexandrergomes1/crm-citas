# Fila de trabalho

**A tarefa é o primeiro item não riscado de "Agora".** Quem termina risca (`~~texto~~`) sem renumerar. A ordem é do
dono (`AGENTS.md` §3). Um item = uma conversa = uma branch. O detalhe de cada item mora no arquivo citado, não aqui.
O que não é para agora: `docs/ROADMAP.md` (por módulo) e `docs/ICEBOX.md`. Regras da fila: `docs/guias/processo-sdd.md`
§Documentos de controle e §Fila parada.

Estados: **próxima** · **em andamento — branch/PR** · **aguardando escolha** · **bloqueada** (diz por quê) ·
**precisa de spec** · **adiado** (cita a decisão). Nível: A texto · B código sem banco · C banco, servidor, dinheiro, acesso, saúde.

## Agora

1. **Fundação do crm-citas.** Base de regras e guias, travas, Spec Kit, app mínimo, banco copiado do crm-agenda, CI. Spec `specs/20261127-000000-fundacao/spec.md`; decisão `docs/decisoes/2026-11-27-projeto-novo.md`; ADR `docs/adr/0001-repositorio-novo.md`. Nível C (trava e CI) · **em andamento — branch `chore/base-fundacao`**
2. **Design system no código**, pelo `DESIGN.md` (6ª edição): tokens e peças em `src/design-system/` e `src/styles/`, com a página interna "Peças" que mostra cada peça nos estados e nas duas larguras. Nível B, tela · **precisa de spec**
3. **Agenda** (`docs/produto/modulos/age-agenda.md`): porte do crm-agenda por spec própria, já no design novo. · **precisa de spec**
4. **Agendamento** (`agd-agendamento.md`): porte por spec própria, já no design novo. · **precisa de spec**
5. **Clientes** (`cli-clientes.md`): porte por spec própria, já no design novo. · **precisa de spec**
6. **Anamnese** (`ana-anamnese.md`): porte por spec própria, já no design novo. Nível C (dado de saúde) · **precisa de spec**
7. **Catálogo** (`cat-catalogo.md`): porte por spec própria, já no design novo. · **precisa de spec**
8. **Comanda** (`com-comanda.md`): porte por spec própria, já no design novo. Nível C (dinheiro) · **precisa de spec**
9. **Financeiro** (`fin-financeiro.md`): porte por spec própria, já no design novo. Nível C (dinheiro) · **precisa de spec**
10. **Caixa** (`cai-caixa.md`): porte por spec própria, já no design novo. Nível C (dinheiro) · **precisa de spec**
11. **Cobranças** (`cob-cobrancas.md`): porte por spec própria, já no design novo. Nível C (dinheiro, página pública) · **precisa de spec**
12. **Estoque e compras** (`est-estoque-compras.md`): porte do que existe (ajuste de estoque) por spec própria, já no design novo. · **precisa de spec**
13. **Equipe e acessos** (`eqp-equipe-acessos.md`): porte por spec própria, já no design novo. Nível C (acesso) · **precisa de spec**
14. **Ajustes** (`aju-ajustes.md`): porte por spec própria, já no design novo. · **precisa de spec**
15. **Mensagens** (`msg-mensagens.md`): porte por spec própria, já no design novo. · **precisa de spec**
16. **Marketing** (`mkt-marketing.md`): porte por spec própria, já no design novo. · **precisa de spec**
17. **Fidelidade** (`fid-fidelidade.md`): porte por spec própria, já no design novo. · **precisa de spec**
18. **SaaS e planos** (`saa-saas-planos.md`): porte do que existe (tabelas) por spec própria. · **precisa de spec**
19. **Importação** (`imp-importacao.md`): porte do que existe (clientes por CSV) por spec própria, já no design novo. · **precisa de spec**
20. **Navegação** (`nav-navegacao.md`): porte por spec própria, já no design novo. · **precisa de spec**
21. **Plataforma** (`plt-plataforma.md`): porte do que existe (login, sessão, páginas públicas) por spec própria, já no design novo. Nível C (acesso) · **precisa de spec**

Módulos sem código no crm-agenda (Reserva online, Idiomas) não são porte: ficam no `docs/ROADMAP.md`.
Ações que só o dono faz: `docs/OWNER.md`, "Só você pode fazer".
