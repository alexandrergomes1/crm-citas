# Pasta: Agenda e Agendamento

Vale junto com o `AGENTS.md` da raiz e o de `src/workspace/`.

**O que mora aqui:** a tela da Agenda (`AgendaPage.tsx`), o agendamento (`_appointment/`), o novo agendamento (`_new/`), a grade (`_board/`), bloqueios, repetição e lista de espera (`_block/`, `_repeat/`, `_waitlist/`), leituras (`_data/`, `reads.server.ts`) e as ações de servidor (`*-actions.ts`, `actions.server.ts`).

**Regras**
- Antes de mexer: `docs/produto/modulos/age-agenda.md`, `agd-agendamento.md` e a spec aprovada da tarefa.
- O que o arquivo do módulo marca "a confirmar" não vira pergunta: depois da ficha curta do módulo (`AGENTS.md` §3), tudo é linha de base. Vira pergunta só o que a tarefa muda.
- Tela segue `DESIGN.md` (ação principal "Novo agendamento" no computador e "Agendar" no celular; status com os ícones de §5) e `docs/guias/telas.md`.
- Regra de negócio da agenda fica em `src/domain/` (`agenda-*.ts`), nunca no componente (`docs/guias/servidor.md`).
- Ação de servidor na ordem fixa e dentro do orçamento de idas ao banco (`docs/guias/servidor.md`).

**Nunca**
- Copiar o sistema antigo (`docs/produto/legado/`) como modelo.
- Nome de cliente ou dado de saúde em log ou aviso.

## Origem
`src/workspace/agenda/AGENTS.md` atual (todas as regras dele continuam) · `.claude/rules/ui-layout.md` · `docs/projeto/estrutura.md` §Pastas · `docs/reorganizacao/design-system-aprovado/design-6a-edicao.md` §5 e §6 · estrutura real (`ls src/workspace/agenda`, 27/11/2026).
