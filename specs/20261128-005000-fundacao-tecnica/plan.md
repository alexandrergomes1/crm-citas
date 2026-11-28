# Plano · Fundação técnica (item 2 da fila)

- **Spec:** `specs/20261128-005000-fundacao-tecnica/spec.md` (Draft)
- **Escrito por:** Arquiteto de software · Norma: modelo C4 e ADR (mais Twelve-Factor, OWASP ASVS 4.0.3 V14.2 e o guia de
  segurança do GitHub Actions) · **Revisão:** pendente (etapa 5 Analista de requisitos; 5b Gerente de projeto)
- **Decisões técnicas:** `docs/adr/0002-fundacao-tecnica-ferramentas-e-versoes.md`
- **Fontes lidas em 27/11/2026.** Nada aqui é adivinhado (`AGENTS.md` §6); o que não pôde ser lido está em §11 "não verificado".

## 1. Resumo (C4, nível de contêiner)
Um único contêiner de app (TanStack Start sobre Vite, React, TypeScript) com as quatro camadas do `ARCHITECTURE.md` §3
dentro de `src/`; um banco Postgres **só local** (Supabase CLI em Docker); a CI no GitHub Actions; o Dependabot; o
Spec Kit como ferramenta do processo. Nenhum sistema externo é chamado (sem Cloudflare, sem banco remoto, sem segredo).

## 2. Versões fixadas e fonte
Regra de escolha (ADR 0002 · D4): a última versão estável publicada **há pelo menos 3 dias** em 27/11/2026, compatível
com as outras (mesma janela do Dependabot, que espera 3 dias por padrão, e acima do mínimo de 1 dia do pnpm). Todas
exatas (sem `^`), no `package.json` e no `pnpm-lock.yaml` (Twelve-Factor, fator II).

| Item | Versão | Fonte lida |
|---|---|---|
| Node.js | 26.13.1 (LTS ativa "Lithium", de 10/11/2026) | `https://nodejs.org/dist/index.json`; `https://raw.githubusercontent.com/nodejs/Release/main/schedule.json` (v26: LTS desde 28/10/2026, fim 30/04/2029; v22 só até 30/04/2027) |
| pnpm | 12.23.0 (`packageManager` no `package.json`) | `npm view pnpm dist-tags` |
| @tanstack/react-start | 1.169.7 | `npm view`; pede `node >=22.12.0`, `vite >=8.0.0`, React 18 ou 19 |
| @tanstack/react-router | 1.170.46 (a mesma que o Start usa) | `npm view @tanstack/react-start@1.169.7 dependencies` |
| react, react-dom | 19.3.1 | `npm view` |
| typescript | 6.0.3 | `npm view`; **não** 7.0.2: o typescript-eslint aceita só `>=4.8.4 <6.1.0` (`https://typescript-eslint.io/users/dependency-versions/`) |
| vite | 8.3.8 (8.4.0 tem 1 dia) | `npm view vite time` |
| @vitejs/plugin-react | 6.3.0 | `npm view`; pede `vite ^8.0.0` |
| vitest | 5.1.1 (5.1.2 tem 2 dias) | `npm view vitest time`; pede Node `^22.12 \|\| ^24 \|\| >=26` |
| @playwright/test | 1.65.1 | `npm view`; `https://playwright.dev/docs/ci-intro` |
| supabase (CLI, dependência de dev) | 3.4.0 | `npm view`; `https://supabase.com/docs/guides/local-development/cli/getting-started` ("Pin the version in package.json") |
| eslint | 10.15.0 (10.16.0 saiu hoje) | `npm view eslint time` |
| @eslint/js | 10.0.1 | `npm view`; pede `eslint ^10` |
| typescript-eslint | 8.74.0 | `npm view`; pede `eslint ^10` e TS `<6.1.0` |
| globals | 17.14.0 | `npm view` |
| @types/node | 26.6.7 | `npm view @types/node time` |
| @types/react / @types/react-dom | 19.3.1 / 19.3.0 | `npm view` |
| gitleaks (imagem oficial) | `zricethezav/gitleaks:v8.30.1@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f` | Docker Hub (API de tags); `https://proxy.golang.org/github.com/gitleaks/gitleaks/v8/@latest` (v8.30.1); licença MIT (`raw.githubusercontent.com/gitleaks/gitleaks/master/LICENSE`) |
| Spec Kit (`specify-cli`) | 1.4.5 (tag `v1.4.5`, commit `6ba8beefff8d6408cadd62038e92d459093e33a8`) | `https://pypi.org/pypi/specify-cli/json`; `CHANGELOG.md` do repositório oficial (1.4.5 de 25/11/2026); `https://github.github.io/spec-kit/installation.html` |
| actions/checkout | v7.0.1 · `3d3c42e5aac5ba805825da76410c181273ba90b1` | `git ls-remote` no repositório oficial |
| actions/setup-node | v7.1.0 · `949feb2413d6458794dcd2491c4babbbce0c15c1` | idem; README oficial (`node-version-file`, `cache`) |
| pnpm/action-setup | v6.1.1 · `73e46992e05b19abd31f2f3c20e0e7370d762115` (commit da tag anotada) | idem; README oficial ("supports pnpm v12"; lê `packageManager`) |
| actions/upload-artifact | v7.0.2 · `cf430e030ddbb5b0abf93d22962f4752f3646cd9` | idem |

Ações sempre fixadas pelo **commit completo**, com a versão em comentário (ADR 0002 · D7).

## 3. Lista FECHADA de arquivos e pastas que podem mudar
Fora desta lista, nada muda (`AGENTS.md` §6, escopo estrito; CA12). Arquivo novo que uma ferramenta crie fora daqui: parar
e relatar.

**Raiz (Engenheiro de software, salvo indicado)**
- `package.json`, `pnpm-lock.yaml`, `.nvmrc`, `.gitignore`
- `pnpm-workspace.yaml` — **só** se o `pnpm install` acusar `ERR_PNPM_IGNORED_BUILDS`; cada pacote liberado em
  `allowBuilds` passa pelo Engenheiro de segurança
- `tsconfig.json`, `vite.config.ts`, `vitest.config.ts`, `playwright.config.ts`, `eslint.config.mjs`,
  `eslint.camadas.test.ts`

**Camadas**
- `src/app/router.tsx`, `src/app/routeTree.gen.ts` (gerado pelo TanStack, versionado), `src/app/routes/__root.tsx`,
  `src/app/routes/index.tsx`, `src/app/paginas/inicio.tsx`, `src/app/paginas/inicio.test.tsx`
- `src/domain/exemplo.ts`, `src/domain/exemplo.test.ts`
- `src/server/` e `src/data/`: **sem arquivo novo** (não há código nelas nesta spec)
- `src/*/AGENTS.md` e `src/*/CLAUDE.md`: **intactos** (R2)

**Telas (teste)**: `e2e/inicio.spec.ts`; apagar `e2e/.gitkeep`

**Banco local (Engenheiro de dados)**: `supabase/config.jsonc` e `supabase/.gitignore` (criados por `supabase init`),
`supabase/migrations/<data-hora>_fundacao.sql`, `supabase/tests/database/fundacao_test.sql`; apagar `supabase/.gitkeep`

**CI e travas (Engenheiro de DevOps)**: `.github/workflows/ci.yml`, `.github/dependabot.yml`; apagar `.github/.gitkeep`

**Spec Kit (Engenheiro de DevOps)**: `.specify/**` (criado por `specify init`); `.claude/skills/speckit-*/SKILL.md`
(9 pastas **novas**: analyze, checklist, clarify, constitution, converge, implement, plan, specify, tasks). As 4 skills e
os 14 papéis existentes em `.claude/` **não mudam**. O `specify init` não pode criar `.claude/settings.json` (só a
trava T5 do §13 o cria).

**Travas do antigo (R17; Engenheiro de DevOps; só o que a decisão final de cada trava, no ADR 0003, mandar):**
`.claude/settings.json` (só `hooks` e `permissions.deny`), `.claude/hooks/TRAVAS.md`, `.claude/hooks/guarda.mjs`,
`.claude/hooks/guarda.test.mjs`, `.claude/hooks/regras-de-envio.mjs`, `.claude/hooks/decisao-com-prova.mjs`,
`.claude/hooks/decisao-com-prova.test.mjs`, `.claude/hooks/inicio-de-sessao.mjs`,
`.claude/hooks/inicio-de-sessao.test.mjs`, `.githooks/pre-push`, `.githooks/pre-push.mjs`, `.githooks/pre-push.test.mjs`,
o job `travas` no `.github/workflows/ci.yml`, a chave `groups` no
`.github/dependabot.yml`, e `docs/adr/0003-travas-do-projeto-antigo.md`.

**Texto (Documentador)**: `AGENTS.md` §1, só o parágrafo "Comandos" (§6 deste plano); `docs/guias/processo-sdd.md` §5,
só as linhas 61 a 63 (texto exato do §7 deste plano, aprovado pelo dono junto com a spec); `README.md`, só a seção "Como rodar" (R16 e CA13: os mesmos
comandos do §5); `docs/STATUS.md`, `docs/BACKLOG.md`, `CHANGELOG.md` (R16); `docs/decisoes/` (fala de 28/11 sobre
repositório público e aprovação do R15).

**Processo**: `specs/20261128-005000-fundacao-tecnica/{spec.md,plan.md,tasks.md}`;
`specs/20261128-005000-fundacao-tecnica/travas-claude-propostas/` (7 arquivos: `decisao-com-prova.mjs`,
`decisao-com-prova.test.mjs`, `guarda.mjs`, `guarda.test.mjs`, `inicio-de-sessao.mjs`, `inicio-de-sessao.test.mjs`,
`settings.json`; propostas das travas T1, T3, T4 e T5 do §13, fora de `.claude/` até a decisão do ADR 0003);
`docs/adr/0002-fundacao-tecnica-ferramentas-e-versoes.md`. (`.specify/**` e `.claude/skills/speckit-*/SKILL.md` já
estão no bloco "Spec Kit" acima.)

Fora: `SECURITY.md` (D1, fora da spec), `.claude/rules/`, `.cursor/`, `scripts/` (ver §13),
`ARCHITECTURE.md`, `DESIGN.md`, `CONTRIBUTING.md`, qualquer configuração do repositório no GitHub.

## 4. Estrutura das camadas no código
- O TanStack Start aceita a opção `srcDirectory` no plugin do Vite (lida no esquema de
  `@tanstack/start-plugin-core@1.172.0`, `dist/esm/vite/schema.d.ts`). Usa-se `tanstackStart({ srcDirectory: 'src/app' })`:
  roteador, rotas e árvore gerada moram em `src/app`, como o `ARCHITECTURE.md` §3 pede. Molde dos arquivos:
  `https://tanstack.com/start/latest/docs/framework/react/build-from-scratch` (`router.tsx` com `getRouter()`,
  `routes/__root.tsx`, `routes/index.tsx`; `resolve.tsconfigPaths: true`; plugin do React **depois** do Start;
  `verbatimModuleSyntax` **desligado**).
- A rota `/` só importa `src/app/paginas/inicio.tsx`, que mostra o texto `crm-citas` (R1). Sem CSS, sem design.
- `src/domain/exemplo.ts`: uma função pura de exemplo, marcada como "exemplo da fundação; sai quando entrar a primeira
  regra real". `src/server` e `src/data` ficam só com as regras da pasta (sem código, sem teste: R4 fala de camada "que
  tiver código").
- Atalho de importação `@/*` → `./src/*` no `tsconfig.json` (`paths`, sem `baseUrl`, que o TypeScript 6 desaconselha).
- **Lint de camadas (R3)** com a regra nativa `no-restricted-imports` do ESLint, opção `patterns` com `regex`
  (`https://eslint.org/docs/latest/rules/no-restricted-imports`), em blocos por pasta no `eslint.config.mjs`:
  - `src/domain/**`: barra `^(@/|(\.\./)+)(app|server|data)(/|$)` e os pacotes `react`, `react-dom`, `@tanstack/*`,
    `@supabase/*`, `vite`.
  - `src/app/**`: barra `^(@/|(\.\./)+)data(/|$)` e `@supabase/*`.
  - Base: `@eslint/js` recomendado + `typescript-eslint` recomendado (`https://typescript-eslint.io/getting-started/`).
    `src/app/routeTree.gen.ts` fica fora do lint (gerado).
- **Prova automática do lint:** `eslint.camadas.test.ts` (Vitest) chama a API `ESLint` com textos de exemplo e caminhos
  falsos (`src/domain/x.ts` importando `@/data/y` e `../data/y`; `src/app/x.tsx` importando `@supabase/supabase-js`) e
  espera erro; e um caso permitido sem erro. Assim o CA4 vira teste que roda a cada PR, além da prova manual do QA.

## 5. Comandos fixos do projeto (scripts do `package.json`, R7)

| Script | Comando | Para quê |
|---|---|---|
| `dev` | `vite dev` | app local em `http://localhost:3000` |
| `build` | `vite build` | gerar o app (CA1) |
| `typecheck` | `tsc --noEmit` | checagem de tipos |
| `lint` | `eslint . --max-warnings 0` | lint, inclui as camadas |
| `test` | `vitest run` | testes de unidade (camadas e lint de camadas) |
| `test:e2e` | `playwright test` | telas em 390 e 1440 px (Chromium) |
| `db:start` | `supabase start -x gotrue,realtime,storage-api,imgproxy,kong,mailpit,postgrest,postgres-meta,studio,edge-runtime,logflare,vector,supavisor` | banco local (só o Postgres; nomes do `-x` lidos em `https://supabase.com/docs/reference/cli/supabase-start`) |
| `db:stop` | `supabase stop` | desligar o banco local |
| `db:test` | `supabase test db` | testes do banco **local** (pgTAP); `https://supabase.com/docs/reference/cli/supabase-test-db` |

Proibido em script, CI ou tarefa: `supabase link`, `supabase db push`, `--remote`, `--linked` (`AGENTS.md` §1).
`supabase test db` só vai ao remoto com `--remote` (fonte acima); sem ele, é o banco local.

## 6. Texto exato para o `AGENTS.md` §1 (R15; aprovado pelo dono junto com a spec)
Substitui só a frase "**Comandos:** entram com a spec da fundação (ainda não há código). Já fixo: antes de enviar, a IA
roda a checagem de tipos, o lint e os testes." pelo texto abaixo; o resto do parágrafo fica igual.

> **Comandos** (scripts do `package.json`): `pnpm install` · `pnpm dev` (app local) · `pnpm build` · `pnpm typecheck`
> (checagem de tipos) · `pnpm lint` · `pnpm test` (testes de unidade) · `pnpm test:e2e` (telas em 390 e 1440 px) ·
> `pnpm db:start` e `pnpm db:stop` (banco local) · `pnpm db:test` (testes do banco local). Antes de enviar, a IA roda
> `pnpm typecheck`, `pnpm lint` e `pnpm test`; mais `pnpm test:e2e` se mexeu em tela e `pnpm db:test` se mexeu em `supabase/`.

## 7. Spec Kit (R9)
- Instalação (doc: `https://github.github.io/spec-kit/how-to/existing-projects.html`):
  `uvx --from specify-cli==1.4.5 specify init --here --force --integration claude --script sh --ignore-agent-tools`,
  com a árvore limpa (base revisável). Testado em pasta vazia de rascunho em 27/11/2026: cria só `.specify/**` e
  `.claude/skills/speckit-*/SKILL.md` (9); não cria `AGENTS.md`, `CLAUDE.md` nem `.claude/settings.json`.
- Numeração: em `.specify/init-options.json`, `"feature_numbering": "timestamp"` (o comando `specify` lê essa chave e usa
  `AAAAMMDD-HHMMSS`; fonte: `templates/commands/specify.md` do repositório oficial). O `init` grava `sequential`: trocar.
- **Branch:** a extensão `git` do Spec Kit **não** se instala. Motivo: o modelo de branch dela exige que o último trecho
  comece pelo número (`{number}-{slug}`; fonte: `extensions/git/README.md`), então não gera `tipo/area-assunto`. A branch
  continua sendo aberta pelo Engenheiro de DevOps na etapa 2, como o `processo-sdd.md` §2 já manda. Sem a extensão, o
  Spec Kit cria a pasta da spec e não cria branch (mesma fonte, "Graceful Degradation"). Ver §10 R-2 (CA11).
- Constituição `.specify/memory/constitution.md`: só uma linha que aponta para o `AGENTS.md` (R9).
- **Texto exato novo do `processo-sdd.md` §5, linhas 61 a 63** (o guia foi aprovado no E11; este texto vai à aprovação
  do dono junto com a spec, como o do `AGENTS.md` §1 no R15). Substitui as duas frases "Na instalação: pastas com data e
  hora (...) usa outro padrão." e "Os nomes exatos dos comandos entram aqui (...) oficial dela.":
  > - Na instalação (Spec Kit 1.4.5): pastas com data e hora (`feature_numbering: timestamp`). O Spec Kit não cria a
  >   branch: o modelo de branch dele não gera `tipo/area-assunto`, por isso a branch é aberta pelo Engenheiro de DevOps
  >   na etapa 2, nesse padrão.
  > - Comandos, no chat do Claude Code: `/speckit-specify` e `/speckit-clarify` (etapa 3) · `/speckit-plan`,
  >   `/speckit-checklist` e `/speckit-tasks` (etapa 4) · `/speckit-analyze` (etapa 5) · `/speckit-implement` e
  >   `/speckit-converge` (etapa 8, repetidos até "Converged") · `/speckit-constitution` só aponta para o `AGENTS.md`.
- Motivo da troca: o texto aprovado diz que a instalação fixa o nome da branch; a ferramenta oficial não consegue
  (fonte acima). A intenção do dono (branch `tipo/area-assunto`) fica igual; muda só quem a cria.

## 8. CI (R10, R11) · `.github/workflows/ci.yml`
- **Quando roda:** `pull_request` para `previas` e `main`; `push` em `previas` e `main` (o verde fica registrado depois do
  merge). Nunca `pull_request_target` (dá segredo e escrita a código de fora; boas práticas do GitHub Actions).
- **Segurança da CI:** `permissions: contents: read` no topo; nenhum segredo usado; `actions/checkout` com
  `persist-credentials: false`; ações fixadas por commit (§2); `concurrency` por branch com `cancel-in-progress: true`;
  `timeout-minutes: 15` por job. PR do Dependabot roda com token só de leitura e sem segredos (fonte:
  `https://docs.github.com/en/code-security/dependabot/troubleshooting-dependabot/troubleshooting-dependabot-on-github-actions`),
  o que basta porque a CI não usa segredo.
- **Jobs (em paralelo, `ubuntu-latest`):**

| Job | Passos | Prova |
|---|---|---|
| `verificar` | checkout → pnpm/action-setup → setup-node (`node-version-file: .nvmrc`, `cache: pnpm`) → `pnpm install --frozen-lockfile` → `pnpm typecheck` → `pnpm lint` → `pnpm test` → `pnpm build` | CA1, CA3, CA4 (automático), CA5 |
| `telas` | o mesmo preparo → `pnpm exec playwright install --with-deps chromium` → `pnpm test:e2e`; relatório enviado como artefato **só se falhar**, `retention-days: 7` | CA2 |
| `banco` | o mesmo preparo → `pnpm db:start` → `pnpm db:test` → `pnpm db:stop` (sempre) | CA6 |
| `travas` (só se T1 a T7 do §13 entrarem) | checkout → setup-node → `node` nos testes de cada trava trazida → JSON do `.claude/settings.json` válido | R17 |
| `segredos` | checkout com `fetch-depth: 0` → `docker run --rm -v "$GITHUB_WORKSPACE:/repo" <imagem do §2> git --redact --verbose --log-opts=HEAD /repo` (código de saída 1 se achar; `--log-opts=HEAD` pelo S1 do ADR 0003) | CA8, CA12 |

- **gitleaks pela linha de comando (imagem oficial), não pela gitleaks-action.** A ação não pede licença em conta pessoal
  (README da gitleaks-action: "`GITLEAKS_LICENSE` ... required for organizations, not required for user accounts"), mas
  desde a v2 tem licença própria (não MIT), pede `GITHUB_TOKEN` e comenta no PR. A linha de comando é MIT, não pede token,
  e continua grátis se o repositório for para uma organização. `--redact` esconde o segredo no log, que é **público**.
  Varre a cada execução todo o histórico que chega a HEAD (no PR, base + PR), não as outras branches (S1 do ADR 0003; R11).
- **Playwright** (`playwright.config.ts`): 2 projetos Chromium, `celular` (390×844) e `computador` (1440×900); `webServer`
  com `pnpm dev`, `url: http://localhost:3000`, `reuseExistingServer: !process.env.CI`
  (`https://playwright.dev/docs/test-webserver`). O teste acha "crm-citas" e confere
  `document.documentElement.scrollWidth <= clientWidth` (sem rolagem lateral, CA2).
- **Dependabot** (`.github/dependabot.yml`, R12): `version: 2`; `package-ecosystem: "npm"` (cobre pnpm v7 a v12) e
  `"github-actions"`, ambos `directory: "/"`, `schedule.interval: "weekly"`, `target-branch: "previas"`,
  `open-pull-requests-limit: 5`, `cooldown.default-days: 3`. Fonte:
  `https://docs.github.com/en/code-security/dependabot/working-with-dependabot/dependabot-options-reference`. A imagem do
  gitleaks (dentro de `run:`) não é atualizada pelo Dependabot: troca manual por PR.

## 9. Gratuidade e limites (R13, CA10) · lidos em 27/11/2026

| Serviço | O que diz a fonte oficial | Efeito no projeto |
|---|---|---|
| GitHub Actions | "The use of standard GitHub-hosted runners is free: In public repositories ... For Dependabot" e "Standard GitHub-hosted runners in public repositories ... does not reduce the included compute usage" (`https://docs.github.com/en/billing/concepts/product-billing/github-actions`) | minutos grátis com runner padrão; **não** usar runner maior ("Larger runners are billed for public repositories") |
| Armazenamento do Actions | plano Free: 500 MB de artefatos, 10 GB de cache por repositório; "If your account does not have a valid payment method on file, usage is blocked" (mesma página) | sem cartão não há cobrança: o uso para. Relatório do Playwright só em falha e por 7 dias |
| Limites de execução | Free: 20 jobs ao mesmo tempo; 6 h por job (`https://docs.github.com/en/actions/reference/limits`) | 4 jobs de até 15 min: folga |
| Dependabot | execução dos PRs do Dependabot grátis em runner padrão (página de cobrança acima) | sem custo |
| gitleaks | linha de comando MIT; ação sem licença para conta pessoal (README oficial da gitleaks-action) | sem custo, sem chave |
| Regras de branch (para o D3) | "Rulesets are available in public repositories with GitHub Free" (`https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets`) | D3 possível sem custo |
| Supabase | roda local em Docker; nada de projeto remoto | sem custo |

Nenhum custo ou limite que afete o projeto foi achado (R13 não para o trabalho). O plano segue só o gratuito, como recomenda a E23·3·A; a resposta da E23·3 é do dono e
está pendente.

## 10. Riscos, com recomendação

**D2 · PRs do Dependabot e a `main`.** Fato lido: com `target-branch`, os PRs de **versão** vão para a `previas`, mas
"security updates always use the default branch for the repository" (página de opções do Dependabot). Hoje a branch
padrão é a `main`: um PR de **segurança** apontaria para a produção. O nosso `dependabot.yml` só configura atualizações
de versão; as de segurança são um botão das configurações do repositório (do dono).
- D2·A: o dono muda a branch padrão para `previas` (Settings → General → Default branch). Segurança e versão vão para a
  `previas`; PR novo já abre para a `previas`. Desfaz: voltar a branch padrão para `main`.
- D2·B: a `main` fica padrão e as "Dependabot security updates" ficam desligadas; só alertas, e a correção entra pelo PR
  semanal para a `previas`. Desfaz: ligar o botão. Custo: até 1 semana de atraso numa correção.
- D2·C: deixar ligado e fechar sem juntar todo PR do Dependabot para a `main`, refazendo na `previas`. Custo: ruído e risco
  de juntar por engano.
- **Recomendo D2·A** (menor risco; `AGENTS.md` §8). Como mexe em configuração do repositório (fora de escopo da spec,
  e é acesso/produção), vai **no pedido separado do D3**, não como 4ª dúvida desta spec (`AGENTS.md` §4).

**D3 · Proteção de branch.** Sem regra, a CI vermelha não impede o merge. Regras (rulesets) são grátis em repositório
público. Proposta para o pedido separado, com cliques exatos montados pelo Engenheiro de DevOps:
- D3·A: ruleset em `previas` e `main`: exigir PR; exigir os checks `verificar`, `telas`, `banco`, `segredos` (e `travas`, se entrar), com a
  branch atualizada; bloquear force push e apagar; ninguém na lista de exceção; **0 aprovações exigidas** (o dono é a
  única pessoa, e o autor não aprova o próprio PR: a revisão continua sendo a dos papéis e a autorização no chat). Junto:
  em Settings → Actions, "Require approval for all external contributors" para PR de fork, e permissão padrão do token
  só de leitura. Desfaz: desligar o ruleset.
- D3·B: não proteger; a disciplina fica só nas regras escritas. Risco: merge com CI vermelha por engano.
- **Recomendo D3·A**, pedido logo depois do primeiro verde da CI (os nomes dos checks só aparecem para escolha depois de
  rodarem uma vez).

**Outros riscos técnicos**
- R-1 · TypeScript 7 incompatível com o typescript-eslint: fica o 6.0.3 até o typescript-eslint aceitar o 7 (Dependabot vai
  propor; o revisor recusa enquanto o par não fechar).
- R-2 · (resolvido em 28/11) o CA11 foi reescrito pelo Analista: o Spec Kit cria a pasta com data e hora e não cria
  branch; a branch segue a etapa 2.
- R-3 · Node 26.13.1 já está na máquina em `/home/user/tools/node-v26.13.1-linux-x64/bin` (conferido por SHA-256,
  informado pelo coordenador em 28/11/2026): pôr essa pasta à frente no `PATH` antes da tarefa 2. O Node 25+ não traz
  mais o Corepack (fonte não lida nesta sessão: **não verificado**), por isso o pnpm vem pela ação `pnpm/action-setup`
  na CI e por instalação direta na máquina.
- R-4 · pnpm 12 recusa versão com menos de 1 dia (`minimumReleaseAge` padrão 1440 min) e para a instalação se um pacote
  tiver script de instalação não aprovado (`strictDepBuilds` padrão `true`) (`https://pnpm.io/settings/dependency-resolution`,
  `https://pnpm.io/settings/build`). Mantém-se o padrão (protege a cadeia de fornecimento); exceção só com o Eng. de segurança.
- R-5 · Repositório público: logs e artefatos da CI ficam visíveis. Por isso `--redact`, artefato só em falha e só dados
  fictícios (R14).
- R-6 · `db:start` com `-x` (só Postgres) pode não bastar para o `supabase test db`. Se falhar, tirar o `-x` (doc pede
  7 GB de RAM para tudo; o runner padrão aguenta) e registrar no ADR.
- R-7 · gitleaks em contêiner pode recusar o repositório por dono de pasta diferente (aviso do git). Se acontecer, rodar
  com `-u "$(id -u):$(id -g)"`. A prova CA8 mostra.
- R-8 · O lint de camadas casa o texto da importação, não o arquivo resolvido: uma subpasta chamada `app`, `server` ou
  `data` dentro de `src/domain` daria falso alarme. Regra: entre camadas, importar sempre por `@/`. Se ficar curto,
  trocar por `eslint-plugin-boundaries` 7.4.5 (resolve o caminho real) num ADR novo.
- R-9 · O teste de tela usa o servidor de desenvolvimento, não o build: o build de produção só existe com a spec da
  Cloudflare, se o dono escolher E23·2·A (pendente); com E23·2·B, a troca entra nesta spec e o plano é refeito.
- R-10 · Telemetria do Supabase CLI: a página oficial de telemetria deu 404 em 27/11/2026; desligar só depois de ler a
  forma certa (tarefa 7).
- R-11 · (resolvido em 28/11) o `README.md` "Como rodar" entrou no R16 e no CA13 da spec.

## 11. Como provar cada critério de aceite

| CA | Como | Quem |
|---|---|---|
| CA1 | job `verificar` (install com `--frozen-lockfile` + `pnpm build`) verde | QA, link da execução |
| CA2 | job `telas`: 2 projetos (390 e 1440) passam, com a checagem de rolagem lateral | QA |
| CA3 | `pnpm test` lista `src/app/paginas/inicio.test.tsx` e `src/domain/exemplo.test.ts` passando | QA |
| CA4 | automático: `eslint.camadas.test.ts`; manual: o QA cria `src/domain/proibido.ts` importando `@/data/x`, vê `pnpm lint` falhar, apaga, vê passar; registra no veredito | QA |
| CA5 | passos `typecheck` e `lint` do job `verificar` | QA |
| CA6 | job `banco` verde e a mesma sequência na máquina (`db:start`, `db:test`, `db:stop`) | Engenheiro de dados; QA confere |
| CA7 | PR para `previas` dispara os jobs sozinho (os 4 do §8 e o `travas`, se alguma trava for trazida) e todos ficam verdes | QA, link |
| CA8 | branch descartável com um token **falso** num arquivo; job `segredos` vermelho com o achado mascarado; branch apagada depois | QA com o Engenheiro de segurança |
| CA9 | aba Insights → Dependency graph → Dependabot sem erro de configuração | DevOps mostra; QA confere |
| CA10 | §9 deste plano | Analista de requisitos |
| CA11 | `git diff --stat` só com `.specify/**` e `.claude/skills/speckit-*`; criar spec de teste, conferir pasta com data e hora, apagar; constituição com uma linha | QA |
| CA12 | `git diff --name-only previas...HEAD` comparado com o §3; job `segredos` verde | Revisor de código, Auditor de risco |
| CA13 | §5 igual ao `package.json`; `AGENTS.md` §1 e `processo-sdd.md` §5 (linhas 61 a 63) iguais ao §6 e §7; "Como rodar" do `README.md` com os mesmos comandos do §5 | outro papel que não o Documentador (Analista de requisitos) |
| R17 | cada trava do §13 com a decisão final no ADR 0003, conferida por outro papel; teste próprio verde no job `travas` | Engenheiro de DevOps decide; Engenheiro de segurança e Auditor de risco conferem |

## 12. Não verificado (nesta etapa)
- Nada foi construído nem rodado no projeto; só o `specify init` numa pasta vazia de rascunho.
- As páginas de release em `github.com` estão bloqueadas nesta sessão (403 da política de rede): as versões das ações
  vieram de `git ls-remote` e dos README oficiais; as notas de cada release não foram lidas.
- Se o `-x` do `db:start` basta para o `supabase test db` (R-6); o gitleaks em contêiner no runner (R-7); a forma de
  desligar a telemetria do Supabase (R-10); a remoção do Corepack no Node 25+ (R-3).
- Se o Vitest transforma TSX sem o plugin do React no `vitest.config.ts` (o teste de `inicio` usa `renderToString` de
  `react-dom/server`); se o `routeTree.gen.ts` gerado fica igual entre máquinas.
- Se as "Dependabot security updates" já vêm ligadas neste repositório público (afeta o D2 enquanto o dono não decide).
- Se o arquivo do Dependabot precisa estar na branch padrão para valer (afeta quando o CA9 aparece; com D2·A some).
- Travas do antigo (§13): li o cabeçalho, o `TRAVAS.md` e os trechos principais; não li linha a linha os 620 da
  `guarda.mjs` nem rodei nenhum teste do antigo. Se o Cursor lê o `AGENTS.md` sozinho (base da sugestão T10).

## 13. Travas automáticas do projeto antigo (R17; E22·B)
Lido só para listar, em 28/11/2026, em `/home/user/crm-agenda` (só leitura): `.githooks/`, `.github/`, `.claude/settings.json`,
`.claude/hooks/` (com o `TRAVAS.md`), `.claude/rules/`, `.cursor/`, `scripts/` e os scripts do `package.json`. **Nada foi
copiado.** A coluna "Sugestão" é do Arquiteto; a **decisão final** é do Engenheiro de DevOps (CI e ganchos) ou do papel da
área ao construir, no `docs/adr/0003-travas-do-projeto-antigo.md`, conferida por outro papel (E16·1). "Reescrever" =
mesma intenção, código novo, apontando para as regras **deste** projeto (`AGENTS.md`, `processo-sdd.md`), com teste.

| # | Trava (antigo) | O que faz, em uma linha | Sugestão e motivo (norma) |
|---|---|---|---|
| T1 | `.claude/hooks/guarda.mjs` (+ teste) | antes de cada ação do Claude, barra merge sem autorização gravada, envio direto a `previas`/`main`, envio forçado, publicar, banco remoto, ler/gravar `.env`, mexer em workflow sem spec aprovada | **Reescrever**: a intenção é o `AGENTS.md` §1, §6 e §8, mas o antigo cita caminhos, rótulo `aguardando-merge`, métodos de merge e a exceção "CI sem minutos" que aqui não existem (repositório público). Defesa em profundidade (OWASP ASVS V1.1; ISO 31000, tratar o risco na origem); mais curto, com teste |
| T2 | `.claude/hooks/regras-de-envio.mjs` | lista das branches protegidas e o padrão `tipo/area-assunto` | **Copiar e conferir**: 13 linhas, regra igual ao `AGENTS.md` §8 |
| T3 | `.claude/hooks/decisao-com-prova.mjs` (+ teste; roda na CI) | spec "Approved" exige "Aprovação do dono" com fala literal, data e link; "Aprovação do merge" com SHA; decisão gravada não se reescreve | **Reescrever**: regra igual ao `AGENTS.md` §3 regra 1 e §8, mas o formato de `docs/decisoes/` aqui é uma tabela, não um arquivo por decisão |
| T4 | `.claude/hooks/inicio-de-sessao.mjs` (+ teste) | no começo da conversa mostra branch, commit, próxima tarefa da fila e PRs esperando o dono | **Reescrever** enxuto: ajuda a não escolher tarefa (`AGENTS.md` §5), mas lê `docs/OWNER.md` e rótulos que aqui não existem; lê só `docs/BACKLOG.md` e `docs/STATUS.md` |
| T5 | `.claude/settings.json` | liga T1 e T4 como ganchos; nega skills e agentes de mercado que duplicam o fluxo; lista de permissões e de plugins | **Reescrever**: só `hooks` e `permissions.deny` (lista refeita para as skills de hoje). **Descartar** `enabledPlugins` (é da máquina do dono, não do projeto) e a lista `allow` (menor privilégio, ASVS V1.4). Revisão do Engenheiro de segurança obrigatória |
| T6 | `.githooks/pre-push` (+ `.mjs` e teste) | as mesmas regras de envio de T2 para Cursor, Codex e pessoas; vale só onde se liga `core.hooksPath` | **Copiar e conferir**: depende só de T2; regra do `AGENTS.md` §8 vale para qualquer ferramenta |
| T7 | `.github/workflows/base.yml` | roda na CI os testes de T1 a T6 e confere o JSON do `settings.json` | **Reescrever** como job `travas` do nosso `ci.yml`, com as ações fixadas por commit (§2) |
| T8 | `scripts/conferir-pedido.mjs` (+ teste) | antes de planejar ou construir: no máximo 3 PRs abertos, nada de dois PRs nos mesmos arquivos, nome de branch, spec aprovada | **Descartar**: rodava de dentro das skills, que aqui não mudam (R9); nome de branch fica em T2/T6 e spec aprovada em T3. O limite de 3 PRs é regra nova, que só o dono cria |
| T9 | `.github/workflows/seguranca.yml` | gitleaks pela `gitleaks-action@v2` | **Descartar**: já coberto pelo job `segredos` (ADR 0002 · D5); a v2 para de funcionar em 16/09/2026 (README oficial da ação) |
| T10 | `.github/dependabot.yml` | mensal, para a `previas`, junta menores e correções num PR só, no máximo 2 abertos | **Reescrever em parte**: trazer só `groups` (menos PRs); manter semanal (Assumption 7 da spec) |
| T11 | `.github/workflows/ci.yml` e `e2e.yml` | checagens do app, teste de tela, `wrangler deploy --dry-run` | **Descartar**: substituídos pelo §8; usam ações sem fixar commit e Cloudflare (fora de escopo) |
| T12 | `.github/pull_request_template.md` | molde do PR no formato do pedido de merge | **Fora do item 2**: não é trava (só preenche o texto do PR; nada barra se o molde for ignorado). Se o dono quiser, entra numa spec de texto, apontando para `docs/moldes/pergunta.md` |
| T13 | `.claude/rules/*.md` e `.cursor/rules/*.mdc` | regras por pasta (banco, servidor, tela) para Claude e Cursor | **Descartar**: duplicam os `src/*/AGENTS.md` (E15) e citam pastas do antigo; duas fontes da mesma regra divergem |
| T14 | `migrations-dev.yml`, `scripts/db/apply-dev.sh`, `apply-migrations.sh` | aplica migrations no banco remoto de desenvolvimento pela CI | **Descartar agora**: banco remoto está fora desta spec; candidato do item 3 |
| T15 | `backup-diario.yml`, `teste-restauracao.yml` | cópia cifrada do banco em R2 e B2 e teste mensal de restauração (desligados) | **Descartar agora**: usam segredos e banco remoto; candidatos da spec de recuperação (`ARCHITECTURE.md` §9) |
| T16 | `scripts/db/replay-migrations.sh`, `schema-fingerprint.sql`, `diff-fingerprint.py`, `migration-order.txt`, `gen-types.sh`; scripts `db:verify` e `db:types` | refaz as migrations num Postgres puro, compara o esquema e gera os tipos | **Descartar agora**: aqui o teste é `supabase test db` (ADR 0002 · D10) e não há tabela; candidatos do item 3 |
| T17 | `.gitleaks.toml` | regras padrão do gitleaks e exceção para a chave pública do Supabase | **Descartar agora**: não há chave no repositório; exceção a mais em repositório público só quando a chave existir (spec da Cloudflare) |
| T18 | scripts do `package.json` (`lint --max-warnings=0`, `typecheck`, `test`, `test:e2e`) | checagens antes de enviar | **Já coberto** pelo §5 (mesmos nomes) |

Ligar o `.githooks` na máquina (`git config core.hooksPath .githooks`) é configuração local, não arquivo: fica no
"Como rodar" do `README.md` se T6 entrar.
