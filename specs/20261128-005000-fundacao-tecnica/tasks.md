# Tarefas · Fundação técnica (item 2 da fila)

- **Spec:** `spec.md` · **Plano:** `plan.md` · **ADR:** `docs/adr/0002-fundacao-tecnica-ferramentas-e-versoes.md`
- **Escrito por:** Arquiteto de software · Norma: modelo C4 e ADR · **Revisão:** pendente (etapas 5 e 5b)
- **Pode começar antes da aprovação**, só em PR de rascunho (E22·B, spec §5); nada é juntado sem a spec com "Status: Approved",
  a linha "Aprovação do dono" e a autorização do merge (`AGENTS.md` §3 regra 1 e §8). Se a aprovação mudar a spec, o
  construído se ajusta antes da revisão.
- Só os arquivos do `plan.md` §3. Falhou: refaz e confere; o mesmo erro duas vezes, para e relata (`AGENTS.md` §6).
- Commits pequenos, Conventional Commits, citando a spec (`CONTRIBUTING.md` §5). Ninguém revisa o que fez.

## Construção

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 1 | Confirmar a branch `chore/fundacao-tecnica` (a partir da `previas`) e a árvore limpa | Engenheiro de DevOps | `git status` vazio |
| 2 | Pôr `/home/user/tools/node-v26.13.1-linux-x64/bin` à frente no `PATH` (Node 26.13.1 já instalado e conferido por SHA-256) e instalar pnpm 12.23.0; criar `.nvmrc` e `package.json` (`"type": "module"`, `packageManager: "pnpm@12.23.0"`, `engines.node`); instalar as versões **exatas** do `plan.md` §2; `.gitignore` (dependências, saídas de build, relatórios de teste, `.env*`, `supabase/.temp`). Se o pnpm acusar build não aprovado ou versão nova demais: parar e chamar o Engenheiro de segurança (R-4) | Engenheiro de software | `pnpm install --frozen-lockfile` limpo |
| 3 | `tsconfig.json`, `vite.config.ts` (`srcDirectory: 'src/app'`), `src/app/router.tsx`, `routes/__root.tsx`, `routes/index.tsx`, `paginas/inicio.tsx` (só o texto `crm-citas`); gerar e versionar `routeTree.gen.ts` | Engenheiro de software | `pnpm dev` mostra a página; `pnpm build` sem erro; `pnpm typecheck` sem erro |
| 4 | `eslint.config.mjs` com a base e o lint de camadas do `plan.md` §4; `eslint.camadas.test.ts` | Engenheiro de software | `pnpm lint` sem erro; o teste de camadas passa |
| 5 | `vitest.config.ts`; `src/app/paginas/inicio.test.tsx` (`renderToString` acha `crm-citas`); `src/domain/exemplo.ts` e o teste | Engenheiro de software | `pnpm test` verde |
| 6 | `playwright.config.ts` (projetos `celular` 390×844 e `computador` 1440×900, Chromium, `webServer` `pnpm dev`); `e2e/inicio.spec.ts` (texto e sem rolagem lateral); apagar `e2e/.gitkeep` | Engenheiro de software | `pnpm test:e2e` verde nos 2 projetos |
| 7 | `supabase init` (via `pnpm exec`); conferir que o `config.jsonc` não liga projeto remoto; `supabase migration new fundacao` (vazia, só comentário); `supabase/tests/database/fundacao_test.sql` em pgTAP no molde oficial (`begin` · `plan(1)` · `has_schema('public')` · `finish()` · `rollback`); scripts `db:*`; ler a forma oficial de desligar a telemetria e aplicar só se achada (R-10); apagar `supabase/.gitkeep` | Engenheiro de dados | `pnpm db:start`, `pnpm db:test`, `pnpm db:stop` verdes na máquina; nenhum `link`, `db push`, `--remote` |
| 8 | Spec Kit: `uvx --from specify-cli==1.4.5 specify init --here --force --integration claude --script sh --ignore-agent-tools`; `feature_numbering` → `timestamp`; constituição de uma linha apontando para o `AGENTS.md`; **sem** a extensão `git`; conferir que só surgiram `.specify/**` e as 9 pastas `.claude/skills/speckit-*`; criar uma spec de teste, ver a pasta com data e hora, apagar | Engenheiro de DevOps | `git diff --stat` dentro do `plan.md` §3 |
| 9 | `.github/workflows/ci.yml` (4 jobs, gatilhos, permissões e ações fixadas por commit do `plan.md` §8); `.github/dependabot.yml`; apagar `.github/.gitkeep` | Engenheiro de DevOps | YAML válido; nenhum segredo, nenhum `pull_request_target` |
| 10 | Rodar na máquina todos os scripts e o gitleaks em contêiner sobre o histórico inteiro | Engenheiro de DevOps | tudo verde; nenhum achado |
| 10b | Travas do antigo (R17): para cada T1 a T18 do `plan.md` §13, decidir copiar, reescrever ou descartar (a sugestão do Arquiteto é ponto de partida, não ordem); registrar cada decisão e o motivo em `docs/adr/0003-travas-do-projeto-antigo.md`; construir só as que entram, com teste próprio, nos arquivos de destino do §3; o job `travas` no `ci.yml`; `groups` no `dependabot.yml`. Nada de dado real ou segredo do antigo; ler o antigo só em `/home/user/crm-agenda` (só leitura) | Engenheiro de DevOps (CI e ganchos); o papel da área se a trava for de banco ou tela | ADR 0003 completo; `node` nos testes das travas verde |
| 11 | Texto: `AGENTS.md` §1 (exato do `plan.md` §6), `processo-sdd.md` §5 linhas 61 a 63 (exato do §7) e `README.md` "Como rodar" (os comandos do §5 e, se T6 entrar, `git config core.hooksPath .githooks`) | Documentador | igual ao plano, palavra por palavra |
| 12 | Abrir o PR `chore/fundacao-tecnica` → `previas` (rascunho permitido pelo E22·B); CI roda sozinha | Engenheiro de DevOps | todos os jobs verdes (CA7) |

## Revisão (etapa 9)

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 13 | Revisar o código (camadas, configs, testes, escopo do §3) | Revisor de código | relatório sem "Bloqueia" |
| 14 | Revisar o banco local (migration, teste, scripts sem remoto) | Engenheiro de dados que **não** fez o passo 7, e Auditor de risco | relatório sem "Bloqueia" |
| 15 | Revisar CI e segredos: permissões, gatilhos, ações por commit, `--redact`, Dependabot, `allowBuilds` (se houver), skills de terceiros do Spec Kit em `.claude/skills/speckit-*`; as travas trazidas e o `.claude/settings.json` | Engenheiro de segurança e Auditor de risco | relatórios sem "Bloqueia" |
| 15b | Conferir as decisões do ADR 0003, trava por trava (E16·1: outro papel confere) | Auditor de risco | conferência registrada no ADR 0003 |
| 15c | Revisar o ADR 0002 (D1 a D4, D9 a D11 pelo Revisor de código; D5 a D8 pelo Auditor de risco) e o ADR 0003 (Revisor de código no código das travas; Auditor de risco nas decisões) | Revisor de código e Auditor de risco | "Revisão" preenchida nos dois ADR, sem "Bloqueia" |
| 16 | Prova do CA8 em branch descartável com token falso; apagar a branch | QA com o Engenheiro de segurança | job `segredos` vermelho, achado mascarado; branch apagada |
| 17 | Veredito de CA1 a CA13 pelo `plan.md` §11, incluindo a prova manual do CA4 e o CA9 na aba do Dependabot | Analista de qualidade (QA) | veredito com links |
| 18 | Revisar o texto do passo 11, incluindo o `README.md` (CA13) | Analista de requisitos | igual aos scripts |

## Fechamento (etapas 10 a 13)

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 19 | Conferir o pedido item por item (R1 a R17) | Analista de requisitos | tudo cumprido ou relatado |
| 20 | `docs/STATUS.md`, `docs/BACKLOG.md`, `CHANGELOG.md`, `docs/decisoes/` (fala de 28/11 e aprovação do R15) no mesmo PR | Documentador | no PR |
| 21 | Pedido de merge no molde, com o commit e a CI verde; em seguida, o pedido separado do D2 e do D3 (`plan.md` §10) | Gerente de projeto | mensagem enviada e aviso no celular |
| 22 | Gravar "Aprovação do merge" e juntar só esse commit | Engenheiro de DevOps | merge feito |
