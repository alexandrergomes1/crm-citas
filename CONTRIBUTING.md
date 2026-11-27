# Como contribuir com o crm-citas

> Rascunho para o dono aprovar (E14). Escrito por: Engenheiro de DevOps · Revisado por: (a preencher) ·
> Norma: trunk-based development, Conventional Commits e DORA. Este arquivo só resume e aponta: a regra
> vale onde está escrita (`AGENTS.md`, `ARCHITECTURE.md`, `docs/guias/processo-sdd.md`, `docs/moldes/pergunta.md`).

## 1. Antes de começar
Leia o `AGENTS.md` (regras de trabalho), o `ARCHITECTURE.md` (como o sistema é montado) e o `DESIGN.md`
(aparência). A pasta em que você mexe pode ter o próprio `AGENTS.md`; a ordem em conflito está no `AGENTS.md` §6.

## 2. De onde vem a tarefa
Só do primeiro item livre de `docs/BACKLOG.md` ou de um pedido literal do dono. Ninguém escolhe nem inventa
tarefa (`AGENTS.md` §5).

## 3. Branch
Uma tarefa, uma branch, sempre criada a partir da `previas`, com o nome `tipo/area-assunto`
(ex.: `feat/agenda-bloqueio-horario`). Os degraus `branch → previas → main` estão no `ARCHITECTURE.md` §8.

## 4. Spec antes de código
Nada é construído sem spec aprovada pelo dono. O passo a passo (spec, plano, tarefas, revisão) está em
`docs/guias/processo-sdd.md`; as regras de fundo, no `AGENTS.md` §3 e §4.

## 5. Commits
Pequenos, no padrão Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`), citando a spec. Exemplo:

```
feat: bloqueio de horário na agenda (specs/AAAAMMDD-HHMMSS-bloqueio-horario/spec.md)
```

Antes de enviar, rode a checagem de tipos, o lint e os testes (`AGENTS.md` §1).

## 6. PR e revisão
Abra o PR da sua branch para a `previas`. Quem revisa cada tipo de trabalho e qual é a prova estão em
`docs/guias/processo-sdd.md` §3 e no `AGENTS.md` §9. Quem constrói não revisa. Os documentos de controle
(fila, estado, registros) vão no mesmo PR.

## 7. Merge e publicação
Só com CI verde, revisão sem bloqueio e autorização do dono no chat, gravada na spec ("Aprovação do merge").
O pedido segue o molde `docs/moldes/pergunta.md` (pedido de merge; pedido de publicação para `previas → main`).
Regras: `AGENTS.md` §8 e `docs/guias/processo-sdd.md` §2 (etapas 12 e 13).

## 8. O que nunca fazer
- Enviar direto à `previas` ou à `main`, ou juntar sem autorização do dono.
- Publicar ou aplicar mudança no banco remoto: o banco só muda pela CI (`AGENTS.md` §1, `ARCHITECTURE.md` §8).
- Pôr segredo, dado pessoal ou de saúde em código, registro, endereço (URL) ou notificação (`AGENTS.md` §6).
- Mexer fora dos arquivos que o plano permite, ou adivinhar biblioteca, API, esquema ou comando.
- Copiar algo do projeto antigo sem autorização do dono, item por item (`AGENTS.md` §3).
- Enviar outra mudança depois do pedido de merge sem refazer a revisão e o pedido.
