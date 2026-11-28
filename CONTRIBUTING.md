# Como contribuir com o crm-citas

> Rascunho para o dono aprovar (E14). Escrito por: Engenheiro de DevOps · Revisado por: Gerente de projeto ·
> Norma: trunk-based development, Conventional Commits e DORA. Este arquivo só resume e aponta: a regra
> vale onde está escrita (`AGENTS.md`, `ARCHITECTURE.md`, `docs/guias/processo-sdd.md`, `docs/moldes/pergunta.md`).

## 1. Antes de começar
Leia o `AGENTS.md` (regras de trabalho), o `ARCHITECTURE.md` (como o sistema é montado) e o `DESIGN.md`
(aparência). A pasta em que você mexe pode ter o próprio `AGENTS.md`; a ordem em conflito está no `AGENTS.md` §6.

## 2. De onde vem a tarefa
Só do primeiro item livre de `docs/BACKLOG.md` ou de um pedido literal do dono. A IA não escolhe nem inventa
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
- Publicar sem autorização do dono ou aplicar mudança no banco remoto: o banco só muda pela CI (`AGENTS.md` §1, `ARCHITECTURE.md` §8).
- Pôr segredo, dado pessoal ou de saúde onde o `AGENTS.md` §6 proíbe.
- Mexer fora dos arquivos que o plano permite, ou adivinhar biblioteca, API, esquema ou comando (`AGENTS.md` §6).
- Enviar outra mudança depois do pedido de merge sem refazer a revisão e o pedido.

## 9. Como rodar
Os comandos são os scripts do [`package.json`](https://github.com/alexandrergomes1/crm-citas/blob/feat/entrar-servico/package.json)
(lista no `AGENTS.md` §1). Só o banco **local**: nada aqui liga ao banco remoto.

1. `pnpm install`.
2. `pnpm typecheck`, `pnpm lint` e `pnpm test` (não precisam do banco).
3. `pnpm db:start` sobe o banco local do Supabase (precisa de Docker) e grava uma chave de assinatura nova em
   `supabase/signing_keys.json` a cada vez. `pnpm db:test` roda os testes do banco; `pnpm db:stop` desliga.
4. Com o banco de pé:
   - `pnpm test:integracao`: testes de `tests/integracao/`;
   - `pnpm test:e2e`: telas em 390 e 1440 px. O servidor do app sobe sozinho e nunca reaproveita um já ligado.

Os dois passam por [`scripts/banco-local.mjs`](https://github.com/alexandrergomes1/crm-citas/blob/feat/entrar-servico/scripts/banco-local.mjs):
ele lê `supabase status`, recusa endereço que não seja `127.0.0.1`/`localhost`, gera chaves novas a cada execução
(nunca impressas nem gravadas em arquivo) e as passa ao comando. A chave local de administração só vai para
`tests/` e para o preparo do `e2e/` (opção `--com-admin`); o servidor do app roda sem ela. Se o banco estiver
fora do ar, o script para e pede `pnpm db:start`.

Chromium instalado fora do lugar padrão: ponha o caminho do executável em `PLAYWRIGHT_CHROMIUM`
([`playwright.config.ts`](https://github.com/alexandrergomes1/crm-citas/blob/feat/entrar-servico/playwright.config.ts)).
