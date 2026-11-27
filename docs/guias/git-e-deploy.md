# Guia · Git, PR, merge e publicação

Branch = linha de trabalho separada. PR = pedido para juntar uma branch na outra. Merge = a junção.

## Branches
- **Uma tarefa, uma branch**, criada a partir da `previas`, no padrão `tipo/area-assunto` (ex.: `chore/base-enxuta`). Duas tarefas nunca dividem branch.
- **Nunca enviar direto** à `previas`, à `main` ou à `master`: só por PR.
- Proibido: envio forçado, envio de todas as branches de uma vez, pular o gancho de envio (`--no-verify`, troca de `core.hooksPath`), `git reset --hard`.
- Commits pequenos, no padrão Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`), citando a spec.
- Os documentos de controle (lista em `processo-sdd.md`) vão no PR da própria tarefa, nunca em PR à parte.
- A exclusão automática da branch depois do merge está ligada no GitHub.

## Degraus e ambientes
| Degrau | Branch | Onde se vê | Quando atualiza |
|---|---|---|---|
| Tarefa | `tipo/area-assunto` | prévia da branch `https://<branch-com-hifens>-crm-citas-previas.alexandrergomes.workers.dev` e a CI do PR | a cada envio |
| Integração e prévia | `previas` | https://crm-citas-previas.alexandrergomes.workers.dev | quando um PR autorizado é juntado |
| Produção | `main` | https://crm-citas.alexandrergomes.workers.dev (Worker `crm-citas`; criar na Cloudflare) | só pelo pedido de publicação |
- A Cloudflare (Workers Builds) publica cada envio no link da branch, com o banco de desenvolvimento. Antes do merge, o dono confere a tela no link da branch; depois, na `previas`.
- **Publicar à mão é proibido** (`pnpm deploy`, Cloudflare pela linha de comando ou MCP): a publicação sai do GitHub pela Cloudflare.
- Banco de desenvolvimento único e migrations: `banco.md`. Bancos e demais endereços: `docs/reference/project.md`.

## PR e CI
- PR sempre para a `previas`, no molde `.github/pull_request_template.md`; tirar do rascunho para o E2E e a procura de segredos rodarem.
- O que conta como prova: `testes.md` e a tabela de tipos de `processo-sdd.md`. Teto de PRs abertos e colisão, conferidos antes de começar: `processo-sdd.md`.
- O repositório é privado no plano gratuito do GitHub: **não há proteção de branch**; a CI avisa e não impede. A barreira é o pedido de merge só com CI verde e a trava, que só vale no Claude Code (`.claude/hooks/TRAVAS.md`). Para outras ferramentas, o gancho `.githooks/pre-push` repete as regras de envio onde alguém rodou `git config core.hooksPath .githooks`.

## O que a CI confere
| Quando | O quê | Arquivo |
|---|---|---|
| Todo envio em PR, menos só texto (`docs/**`, `*.md`, `.claude/**`) | tipos, lint, unidade, build, conferência do deploy sem publicar, zero `next/*`, banco do zero com testes | `.github/workflows/ci.yml` |
| PR fora de rascunho | E2E nas duas larguras (`DESIGN.md` §11), com capturas (artefato `capturas-telas`, 90 dias; o passo das capturas não bloqueia) | `.github/workflows/e2e.yml` |
| PR fora de rascunho e `main` | procura de segredos (gitleaks) | `.github/workflows/seguranca.yml` |
| PR que mexe em travas, workflows, specs, Spec Kit, decisões ou controle | testes das travas e conferência das aprovações | `.github/workflows/base.yml` |
| Envio em `previas` ou `main` com migration | aplica no banco de desenvolvimento | `.github/workflows/migrations-dev.yml` |

## Merge de tarefa (`previas`)
Lugar único do passo a passo do merge; `AGENTS.md` §6 traz só a regra.
1. **Pedido:** só com CI verde no último commit X, revisores sem "Bloqueia" e veredito APROVADO (`revisao.md`) e documentos de controle no PR. Pôr o rótulo `aguardando-merge` no PR e mandar o pedido no molde `docs/moldes/pergunta.md` (variante "pedido de merge"), citando o SHA de X, com o link do PR e, em tela, o link da prévia da branch e as capturas da CI.
2. **Depois do pedido, nenhum outro envio na branch.** Quem pede não tira o rótulo: envio novo depois do pedido, o dono tira o rótulo ou autoriza de novo, e há revisão e pedido novos.
3. **Autorização:** o dono responde com clareza no chat (o código do pedido ou palavras que digam juntar aquele PR). Sem clareza, pergunta-se de novo.
4. **Registro:** na spec da tarefa, seção "Aprovação do merge": resposta literal entre aspas, data, link da conversa e SHA de X. Vai num commit Y que só mexe nessa seção, filho único de X; é o único envio aceito depois do pedido.
5. **Merge:** squash, conferindo que o último commit do PR é Y (`expectedHeadSha`). No Claude Code o único caminho que a trava deixa passar é a ferramenta de merge do MCP do GitHub, com essa conferência; merge automático, `gh pr merge` e chamada direta à API com "merge" são barrados.
6. **Depois:** conferir que entrou na `previas` e mandar o link da prévia.
- **Por que dois commits:** gravar a autorização muda o SHA. A autorização vale para X, que o dono viu e a CI aprovou; Y só acrescenta o registro.

## Prova local (CI sem minutos do GitHub)
Se a CI não roda por falta de minutos do GitHub (aviso de cobrança), vale a prova local: quem pede o merge roda na sessão os testes da CI que der e grava os resultados na linha `Prova local:` da seção "Aprovação do merge" da spec; o que não rodou sai como "não verificado".
Só vale no merge de tarefa (nunca na publicação), e só quando toda verificação que falhou traz a anotação de cobrança ("spending limit" ou "account payments have failed"), nenhuma está pendente e as demais passaram. Falha real junto, anotação ilegível ou falta da linha: não vale (`.claude/hooks/TRAVAS.md` §1).

## Publicação (`previas` → `main`)
- PR `previas` → `main`, título "Publicar: …", **só com módulo fechado**. Pedido no molde (variante "pedido de publicação"), com o rótulo, e autorização clara como no merge.
- Registro: `docs/decisoes/AAAA-MM-DD-publicacao-pr-N.md` (molde `docs/moldes/decisao.md`, "Vale para" = "PR nº N · SHA <último commit>"), num PR pequeno próprio à `previas`, só com esse arquivo, juntado com CI verde, squash e SHA conferido. É a única exceção que mantém PR de decisão.
- Depois, a publicação se junta com **merge commit** (nunca squash: as branches divergiriam), conferindo o SHA.
- Migration na produção: mesmo caminho, depois do backup do dia conferido. Prova local não vale na publicação.

## Origem
`AGENTS.md` §6 · `docs/projeto/tecnico.md` §Ambientes, §CI, §Merge e publicação, §Conferências · `.claude/hooks/TRAVAS.md` §1, §2, §3, §5, §7 · `scripts/conferir-pedido.mjs` · `.github/pull_request_template.md` · `docs/reference/project.md` (Ambientes, Fatos do GitHub) · `.claude/skills/sdd-construir/SKILL.md` · `docs/projeto/estrutura.md` §Controle.
