# Travas · crm-citas

Trava = programa que roda sozinho e barra a IA (hook do Claude Code, antes de cada ação dela) ou falha no PR (CI do GitHub). Esta página descreve as travas principais; não é lista fechada: o código (`guarda.mjs`) e os testes são a referência. Mudança aqui é tarefa do tipo "Configuração, trava, CI", revisada por `code-reviewer` e `risk-auditor`.
Limite que não some: repositório privado no plano gratuito do GitHub, sem proteção de branch. A CI só avisa; a trava do Claude Code só vale para o Claude; o gancho de git vale onde foi ligado.

## 1. Merge (`guarda.mjs`)
A IA sugere, o dono autoriza no chat e a IA junta (`docs/guias/git-e-deploy.md` §Merge de tarefa).
- **Só um caminho passa:** a ferramenta de merge do MCP, com `expectedHeadSha` igual ao último commit Y do PR e o método da base: `merge_method: "squash"` na `previas` (tarefa), `"merge"` na `main` (publicação); outro método ou nenhum, barra. Antes, a trava confere pelo GitHub (nunca pela cópia local): PR fora de rascunho e com o rótulo `aguardando-merge`; Y tem um único pai X; o diff X→Y só mexe na seção "Aprovação do merge" do `spec.md` de uma pasta `specs/*/` que o próprio PR adiciona ou altera (da base até X); a seção cita o SHA de X, com resposta literal entre aspas, data e link; CI toda verde em X e nenhuma verificação falhando em Y.
- **Publicação (`previas` → `main`):** a autorização vai no arquivo `docs/decisoes/AAAA-MM-DD-publicacao-pr-N.md` (N = nº do PR de publicação; molde `docs/moldes/decisao.md`, "Vale para" com o SHA do último commit do PR de publicação), num PR pequeno próprio à `previas`, a única exceção de PR de decisão (publicação é rara). A trava junta esse PR pequeno só se ele traz apenas esse arquivo novo, completo, citando o último commit do PR N (que tem de ser `previas` → `main` com o rótulo), com CI verde, squash e `expectedHeadSha`. Depois, no merge da publicação, Y é esse arquivo (filho único de X) e a trava confere que ele cita X.
- **CI sem minutos:** Se a CI não roda por falta de minutos do GitHub (aviso de cobrança), vale a prova local: a IA roda na sessão os testes da CI que der e grava os resultados na linha 'Prova local' da Aprovação do merge; o que não rodou sai como 'não verificado'. A trava conta a CI como "sem minutos" só quando toda verificação que falhou tem anotação de cobrança ("spending limit" ou "account payments have failed"), nenhuma está pendente e as demais passaram; aí, no merge de tarefa, ela vale como verde só com a linha `Prova local:` preenchida na "Aprovação do merge". Falha real junto, anotação ilegível, falta da linha ou publicação: barra.
- **Barrados sempre:** merge sem `expectedHeadSha`, merge automático, o comando de merge do `gh` e qualquer chamada direta à API do GitHub com "merge" (REST ou GraphQL; o nome do rótulo não conta).
- **Envio depois do pedido:** com o rótulo `aguardando-merge`, a trava barra o envio por git na branch, menos um único commit sobre X que só mexe na seção "Aprovação do merge" da spec do PR, e barra toda gravação pelo MCP do GitHub (`push_files`, `create_or_update_file`, `delete_file`) nessa branch. Sem conseguir ler o PR, barra.
- **O rótulo só o dono tira:** a trava barra a IA tirar `aguardando-merge`: `--remove-label` em `gh pr edit` ou `gh issue edit`; `gh label delete` ou `edit`; `gh api` ou `curl` com DELETE em `/labels/aguardando-merge` ou em `/labels`, PUT em `/labels` ou PATCH no próprio issue ou PR (`/issues/N`, `/pulls/N`) com o campo `labels` que troca os rótulos sem ele, GraphQL que tira ou limpa rótulos (`removeLabelsFromLabelable`, `clearLabelsFromLabelable`) ou troca a lista (`updatePullRequest`/`updateIssue` com `labelIds`); ferramentas do MCP que tiram, apagam ou renomeiam o rótulo ou trocam a lista de rótulos de um PR que o tem. Envio novo depois do pedido: o dono tira o rótulo ou autoriza de novo.
- Limite conhecido: a IA escreve com a conta do dono, então uma autorização falsa é possível; ela fica no histórico do Git com o link da conversa.
- Limite conhecido: a trava lê o texto do comando, então não pega o rótulo guardado em variável de shell (ex.: `L=…; gh pr edit N --remove-label $L`) nem o corpo enviado por arquivo (`--input`).

## 2. Envio (`guarda.mjs` e `regras-de-envio.mjs`)
Barrados: envio direto à `previas`, `main` ou `master` (também pela API do GitHub com escrita em refs, arquivos ou nessas branches, e pelo MCP de gravação sem branch); envio forçado; `git push` de branch fora do padrão `tipo/area-assunto`; envio de todas as branches (`--all`, `:` sozinho, `push.default`); envio que pula o gancho (`--no-verify`, troca de `core.hooksPath`); `git reset --hard`.

## 3. Produção, banco e segredos (`guarda.mjs`)
Barrados: publicar à mão; Cloudflare pelo MCP; gravação no banco pelo MCP; Supabase e `psql` contra banco remoto; rodar à mão o script de aplicar migration; disparar a rotina de migrations ou de backup pelo MCP ou por `gh run rerun`; editar migration que já está na `previas`; `rm -rf` amplo; gravar `.env`; ler arquivo de segredos (`.env` e variantes, `.envrc`, `.dev.vars`; o `.example` não) pelas ferramentas de leitura e busca e pelos comandos de leitura da linha de comando, com o nome do arquivo ou por redirecionamento. Limite conhecido: curinga e busca recursiva ficam de fora.
Barrado também: Write/Edit e gravação pelo MCP do GitHub (`create_or_update_file`, `push_files`, `delete_file`) em `.github/workflows/**` fora dos "Arquivos permitidos" de uma spec aprovada da branch ("Status: Approved" e a "Aprovação do dono" completa), lida da versão commitada (Write/Edit: `HEAD`; MCP: só `origin/<branch de destino>`, nunca a branch local), nunca da cópia de trabalho. Limite: a trava confere a ferramenta e o texto do comando, não toda forma de escrever no arquivo.
Sem conseguir conferir (arquivo de regras ausente ou com erro, prazo de 120 segundos estourado): barra.

## 4. Aprovação na CI (`decisao-com-prova.mjs`, no `base.yml`)
- Spec com "Status: Approved" precisa da linha "Aprovação do dono" com resposta literal entre aspas, data e link.
- Seção "Aprovação do merge", quando existe: resposta literal entre aspas, data, link e SHA.
- Arquivo novo em `docs/decisoes/` (inclusive `*-base-<módulo>.md`) precisa de pergunta enviada, opção escolhida, resposta literal entre aspas, data e link. "Sim" ou "ok" passa quando a pergunta era única e a opção escolhida traz o código recomendado.
- Spec que já está na `previas`: "Aprovação do dono", "Clarifications" e "Aprovação do merge" não mudam (mudança é spec nova).
- Arquivo de decisão já juntado não se apaga nem se reescreve: mudança é decisão nova com "Substitui". `historico/` e `LEIA.md` ficam de fora.

## 5. Conferências antes de começar (`scripts/conferir-pedido.mjs`)
Rodam no começo das skills `sdd-planejar` e `sdd-construir`. Barram com o motivo: mais de 3 PRs de trabalho abertos (Dependabot não conta); outro PR aberto ou branch com envio nos últimos 7 dias mexendo nos mesmos arquivos; nome de branch fora do padrão; na construção, spec sem "Aprovação do dono".

## 6. Início de sessão (`inicio-de-sessao.mjs`)
Imprime só: branch e commit · próxima tarefa (1º item livre da fila) · pergunta pendente dessa tarefa (ou a 1ª de `docs/OWNER.md`) · PRs com o rótulo `aguardando-merge` (esperando a autorização do dono) · avisos (plugin faltando, conversa resumida). Até 1.500 caracteres. Sem regras: as regras são o `AGENTS.md`.

## 7. Para Cursor e Codex (`.githooks/pre-push`)
As regras de envio do §2 (protegidas, forçado, nome de branch). Vale onde alguém rodou `git config core.hooksPath .githooks`; o ambiente da nuvem faz isso no script de preparo. Pode ser pulado.

## 8. Bloqueios do `.claude/settings.json`
Lista "deny": skills e agentes de mercado que duplicam o nosso fluxo ou revisores, os comandos do Spec Kit que não se usam (`docs/guias/processo-sdd.md` §Motor: GitHub Spec Kit) e a ferramenta de abrir conversa.

## 9. CI das travas (`base.yml`)
Vigia `.claude/hooks/**`, `.github/workflows/**`, `.claude/settings.json`, `docs/decisoes/**`, `specs/**`, `.specify/**`, `.githooks/**`, `scripts/conferir-pedido*` e os documentos de controle, e roda os testes de cada trava acima.
