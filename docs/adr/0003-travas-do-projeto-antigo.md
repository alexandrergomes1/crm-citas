# ADR 0003 · Travas do projeto antigo, CI e Dependabot da fundação

- **Status:** Proposto · decisões técnicas (`AGENTS.md` §5) · 28/11/2026. Vale quando a spec
  `specs/20261128-005000-fundacao-tecnica/spec.md` for aprovada pelo dono.
- **Autor:** Engenheiro de DevOps · Norma: trunk-based development e DORA; OWASP ASVS 4.0.3 V1.1, V1.4 e V14.2; ISO 31000
- **Conferência (E16·1):** pendente · Auditor de risco (decisões, passo 15b) · Revisor de código (código das travas, 15c) ·
  Engenheiro de segurança (`settings.json` e CI, 15)
- **Origem:** spec R17 e E22·B; `plan.md` §8 e §13. Lido só para isto em `/home/user/crm-agenda` (só leitura), em 28/11/2026:
  `.githooks/`, `.claude/hooks/`, `.claude/settings.json`, `.github/`. Nada de dado real ou segredo veio.

## Restrição desta sessão (pendência)
Gravar em `.claude/` pede aprovação do dono, que não foi dada nesta sessão. Por isso as travas com destino em `.claude/`
estão **propostas, não ligadas**, em `specs/20261128-005000-fundacao-tecnica/travas-claude-propostas/`, com os mesmos
nomes dos destinos: `settings.json` → `.claude/settings.json`; `guarda.mjs`, `decisao-com-prova.mjs`,
`inicio-de-sessao.mjs` e os três `*.test.mjs` → `.claude/hooks/`. Depois da aprovação do dono, copiar sem mudar nada e
apagar a pasta da proposta no mesmo PR. O job `travas` da CI já testa as duas pastas (prefere `.claude/hooks` quando
existir), então a cópia não pede mudança no workflow. Enquanto isso, a trava do Claude Code **não está ativa**.
A pasta da proposta está fora da lista do `plan.md` §3: entrou por ordem do coordenador desta sessão; o Revisor de
código confere (CA12).

## Decisões por trava (copiar, reescrever ou descartar)

| # | Trava do antigo | Decisão | Motivo e norma |
|---|---|---|---|
| T1 | `guarda.mjs` (620 linhas) + teste | **Reescrever** (proposta, ~290 linhas, 94 casos de teste) | Mesma intenção (`AGENTS.md` §1, §6 e §8), sem o que aqui não existe: rótulo `aguardando-merge`, métodos de merge, "CI sem minutos", PR pequeno de publicação. Barra: envio à `previas`/`main`/`master`, forçado, `--all`/`--no-verify`, nome fora de `tipo/area-assunto`, trocar `core.hooksPath` (salvo para `.githooks`), `git reset --hard`; merge pelo `gh` ou pela API; merge pelo MCP fora da regra (base `previas`, fora de rascunho, `expectedHeadSha` = último commit Y, Y filho único de X que só grava a linha "Aprovação do merge" da spec da branch, completa e citando X, spec "Approved", CI verde em X); **merge na `main` sempre** (juntar na produção é publicar, `AGENTS.md` §1); publicar (`wrangler deploy`, `deploy`); Supabase remoto (`link`, `db push/pull/execute`, `--linked`, `--remote`, `--db-url`) e `psql` remoto; banco e Cloudflare pelo MCP; ler ou gravar `.env`; editar migration já na `previas`; mudar workflow que o plano da spec da branch não lista. Revisão de 28/11 (Engenheiro de segurança e Auditor de risco): entrada que não é JSON barra; curinga que pode casar segredo (`.e*`, `.*`); gravar em `.claude/settings*.json`, `.claude/hooks/` e `.githooks/` (a trava não se desliga sozinha; atualizar a trava passa a ser feito pelo dono); escrita pela API em `rulesets` e `branches/*/protection`; MCP do Supabase e da Vercel fora de uma lista fechada de leitura (`get_`, `list_`, `search_`, `query_`, `generate_typescript_types`, `web_fetch_vercel_url`), o que barra `deploy_edge_function`, `create_edge_function_secret`, `create/delete/merge/rebase/reset_branch`, `create/pause/restore_project`, `update_storage_config`, `run_notebook` e qualquer ferramenta da Vercel que não seja de leitura. Sem conseguir conferir: barra (ISO 31000, falhar fechado; defesa em profundidade, ASVS V1.1) |
| T2 | `regras-de-envio.mjs` | **Descartar como arquivo; regras mantidas** em `.githooks/pre-push.mjs` | O gancho de git não pode depender de um arquivo de `.claude/` (que ainda não existe e só vale para o Claude). Fonte única das regras de envio no gancho; a T1 importa dali. Tirada a exceção `decisao/`, que é do antigo |
| T3 | `decisao-com-prova.mjs` + teste (CI) | **Reescrever** (proposta, 27 casos) | Mesma regra (`AGENTS.md` §3 regra 1 e §8) no formato **deste** projeto: campos de cabeçalho da spec (`- **Aprovação do dono:**`) e a tabela de `docs/decisoes/` (só se acrescenta linha; linha nova com código e fala entre aspas; arquivo com link). Roda no job `travas` em todo PR |
| T4 | `inicio-de-sessao.mjs` + teste | **Reescrever enxuto** (proposta, 9 casos) | Ajuda a não escolher tarefa (`AGENTS.md` §5). Lê só `docs/BACKLOG.md` e `docs/STATUS.md`; tirados `docs/OWNER.md`, rótulos, pacotes e plugins da máquina, que aqui não existem |
| T5 | `.claude/settings.json` | **Reescrever** (proposta): só `hooks` e `permissions.deny` | Descartados `enabledPlugins` (da máquina do dono) e `allow` (menor privilégio, ASVS V1.4). `deny` = a lista do antigo **menos** os `speckit-*` (aqui todos se usam, `plan.md` §7) e as skills do produto antigo, mais `Edit(/.claude/**)`, `Edit(/.githooks/**)` e `Read(**/.env*)`. Na doc oficial (code.claude.com/docs/en/permissions, lida em 28/11) as regras `Write(path)` não casam com nada; quem cobre o Write é o `Edit(path)`, por isso não há `Write(...)`. O `Read(**/.env*)` também barra ler o `.env.example`. Revisão do Engenheiro de segurança obrigatória |
| T6 | `.githooks/pre-push` (+ `.mjs` e teste) | **Copiar e conferir**, com o ajuste do T2 | Regra do `AGENTS.md` §8 para qualquer ferramenta. 18 casos, um deles rodando o gancho numa pasta com espaço e acento. Liga-se com `git config core.hooksPath .githooks` (o Documentador põe no "Como rodar") |
| T7 | `.github/workflows/base.yml` | **Reescrever** como job `travas` do `ci.yml` | Ações fixadas por commit; roda sempre (sem filtro de pastas), porque é rápido e o check precisa existir para o ruleset do D3 |
| T8 | `scripts/conferir-pedido.mjs` | **Descartar** | Rodava dentro das skills, que aqui não mudam (R9); nome de branch fica no T2/T6, spec aprovada no T3. O limite de 3 PRs seria regra nova, só do dono |
| T9 | `seguranca.yml` (gitleaks-action v2) | **Descartar** | Coberto pelo job `segredos` (ADR 0002 · D5) |
| T10 | `.github/dependabot.yml` | **Reescrever em parte**: só a chave `groups` | Menos PRs: menores e correções juntos, versão maior sozinha; ações num grupo. Semanal (Assumption 7), não mensal |
| T11 | `ci.yml`, `e2e.yml` | **Descartar** | Substituídos pelo `plan.md` §8; ações sem commit fixo e Cloudflare (fora de escopo) |
| T12 | `pull_request_template.md` | **Fora do item 2** | Não é trava |
| T13 | `.claude/rules/`, `.cursor/rules/` | **Descartar** | Duplicam os `src/*/AGENTS.md` (E15) |
| T14 a T16 | migrations no remoto, backup, replay do esquema | **Descartar agora** | Banco remoto e segredos fora desta spec; candidatos do item 3 e da spec de recuperação |
| T17 | `.gitleaks.toml` | **Descartar agora** | Nenhuma chave no repositório; exceção só quando existir |
| T18 | scripts do `package.json` | **Já coberto** | `plan.md` §5 |
| — | `.claude/hooks/TRAVAS.md` | **Descartar** | Este ADR e o cabeçalho de cada arquivo são a descrição; duas fontes divergem |

## Outras decisões desta etapa

| # | Decisão | Motivo e norma |
|---|---|---|
| S1 | gitleaks com `--log-opts=HEAD` (todo commit que chega a HEAD; no PR, base + PR), além do `--redact` do plano | Com `fetch-depth: 0` o checkout baixa **todas** as branches e o gitleaks, sem esse ajuste, varre todas. Testado em 28/11: sem ele, 3 achados (regra `generic-api-key`, `SUPABASE_ANON_KEY` em `wrangler.jsonc`) no commit `191ec2f` da branch `chore/base-fundacao`, que **não** está na história desta branch; com ele, 11 commits e nada achado. A CI barra o que entra; o achado em outra branch vai ao Engenheiro de segurança e ao dono (repositório público) |
| S2 | `-u "$(id -u):$(id -g)"` no `docker run` do gitleaks | `plan.md` §10 R-7 (git recusa pasta de outro dono) |
| S3 | Job `banco` roda `pnpm exec supabase telemetry disable` antes do `db:start` | R-10; comando existente na CLI 3.4.0 (`supabase telemetry --help`), informado pelo Engenheiro de dados |
| S4 | Registro: o Engenheiro de dados mudou o `project_id` do `supabase/config.jsonc` para `"crm-citas"` | Nome fixo do projeto local, igual em toda máquina e na CI (não depende do nome da pasta). Decisão dele; registrada aqui a pedido do coordenador |
| S5 | Cinco jobs com nomes curtos e fixos (`verificar`, `telas`, `banco`, `segredos`, `travas`) | São os nomes de check que o ruleset do D3 vai exigir |

## Limites conhecidos
- A T1 lê o texto do comando: não pega tudo (variável de shell, curinga, outra forma de gravar arquivo). O gancho
  `pre-push` pode ser pulado com `--no-verify` e só vale onde foi ligado. Sem o ruleset do D3, nada disso impede o merge
  no GitHub.
- A T1 lê o GitHub pelo `gh`; sem `gh` autenticado, todo merge pela IA é barrado (falha fechada).
- Os nomes de ferramentas MCP vêm da trava antiga; MCPs de publicação de outros fornecedores não estão na lista.

## Consequências
- Para ligar a trava do Claude Code: aprovação do dono para gravar em `.claude/`, cópia da pasta da proposta, job
  `travas` verde. Para desfazer qualquer decisão: ADR novo que substitui a linha, com o motivo.
