# Tarefas · Design system no código (item 4 da fila)

- **Spec:** `spec.md` · **Plano:** `plan.md` · **ADR:** `docs/adr/0004-design-system-no-codigo.md`
- **Escrito por:** Arquiteto de software · Norma: modelo C4 e ADR · **Revisão:** etapa 5 (Spec Kit): não roda, porque o
  Spec Kit entra com o item 2, ainda não juntado · etapa 5b (Gerente de projeto): feita com ajustes, 28/11
- **A construção pode correr antes da aprovação, só em PR de rascunho** empilhado sobre a `chore/fundacao-tecnica`
  (E22·B, decisão do dono de 28/11 registrada no PR #2; spec D-1). **Nada é juntado sem o dono:** a spec precisa de
  "Status: Approved", da linha "Aprovação do dono" e da autorização do merge (`AGENTS.md` §3 regra 1 e §8). Se as
  respostas E25·1 a E25·3 mudarem algo, o construído se ajusta antes da revisão.
- **Paradas do dono (tipo Tela, `processo-sdd.md` §4):** ficha visual com as perguntas E25·1 a E25·3 (passo 13a),
  aprovação da spec (13b) e pedido de merge com o link da prévia (20). Cada uma com aviso no celular (`AGENTS.md` §7).
- Só os arquivos do `plan.md` §3. Falhou: refaz e confere; o mesmo erro duas vezes, para e relata (`AGENTS.md` §6).
- Commits pequenos, Conventional Commits, citando a spec. Ninguém revisa o que fez.

## Antes de construir

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 0a | **Feito (28/11).** Lacunas L-1, L-2 e L-3 do `plan.md` §10 levadas à spec (E25·2, E25·3 e cabeçalho, commit `f4f8d2e`); a branch `feat/design-system-codigo` já recebeu a `chore/fundacao-tecnica` (merge `3ac0b37`) | Analista de requisitos; Engenheiro de DevOps | feito |
| 0b | PR de rascunho da `feat/design-system-codigo` com base `chore/fundacao-tecnica` (redirecionado à `previas` quando o item 2 for juntado) | Engenheiro de DevOps | PR de rascunho aberto; `git status` vazio |

## Construção (etapa 8)

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 1 | Instalar as 3 versões exatas do `plan.md` §2 (`lucide-react` e `@fontsource-variable/geist` em `dependencies`; `@axe-core/playwright` em `devDependencies`). Se o pnpm acusar build não aprovado ou versão nova demais: parar e chamar o Engenheiro de segurança | Engenheiro de software | `pnpm install --frozen-lockfile` limpo; `package.json` com só essas 3 linhas novas |
| 2 | `src/app/estilos/tokens.css` (todos os tokens do `plan.md` §4; os de E25·2 e E25·3 com o valor recomendado, ajustado se o dono responder outro), `base.css` (fonte, foco, movimento reduzido) e `app.css` (os `@import`); ligar no `__root.tsx` pelo molde `?url` | Engenheiro de software | `pnpm dev` mostra a fonte Geist; `pnpm build` sem erro |
| 3 | `src/app/ui/tokens.test.ts` e `contraste.test.ts` (`plan.md` §7) | Engenheiro de software | `pnpm test` verde (CA-1, CA-2, RA-1) |
| 4 | `src/app/ui/icone.tsx` e o bloco de lint do `plan.md` §6.4, com os 2 casos novos no `eslint.camadas.test.ts` | Engenheiro de software | `pnpm lint` e `pnpm test` verdes |
| 5 | Componentes `botao`, `contador`, `seletor`, `campos`, `etiqueta-status` (`.tsx` + `.css`) | Engenheiro de software | tipos, lint e teste CA-2 verdes |
| 6 | Componentes `bloco-lista`, `camadas`, `estados`, `estrutura`, `conteudo` | Engenheiro de software | idem |
| 7 | `src/app/ui/componentes.test.tsx` (`plan.md` §7) | Engenheiro de software | `pnpm test` verde |
| 8 | Rota `src/app/routes/vitrine.tsx` (pela resposta da E25·1), `paginas/vitrine.tsx`, `vitrine.css`, `vitrine-dados.ts` (só fictícios); gerar e versionar `routeTree.gen.ts` | Engenheiro de software | `/vitrine` abre em `pnpm dev`; um quadro por RC-1 a RC-22 e o de tokens |
| 9 | `e2e/vitrine.spec.ts` e `e2e/vitrine-acessibilidade.spec.ts` (`plan.md` §8) | Engenheiro de software | `pnpm test:e2e` verde em `celular` e `computador`; os 2 PNG gerados |
| 10 | Passo `capturas-vitrine` no job `telas` do `ci.yml` (`plan.md` §8) | Engenheiro de DevOps | YAML válido; ação fixada pelo commit do ADR 0002 |
| 11 | Rodar `pnpm typecheck`, `pnpm lint`, `pnpm test`, `pnpm test:e2e`; empurrar o PR de rascunho | Engenheiro de software | CI verde; artefato `capturas-vitrine` com 2 PNG |

## Ficha visual (etapa 6, depois do passo 11)

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 12 | `ficha-visual.md` e `ficha/*.png`: imagens 01, 02, 03 e 06 × capturas 390 e 1440, uma linha por diferença ("igual", "vale o texto", "defeito") | Designer de produto | ficha completa; defeitos voltam ao passo 5 ou 6 |
| 13 | Conferir a ficha e a vitrine pelo `DESIGN.md` §10 (os 8 itens) | Revisor de design | veredito sem "Bloqueia" |
| 13a | **Parada do dono (etapa 6):** levar a ficha visual e as perguntas E25·1, E25·2 e E25·3 juntas, numa mensagem no molde `docs/moldes/pergunta.md`, com aviso no celular | Gerente de projeto | respostas do dono recebidas |
| 13b | **Parada do dono (etapa 7):** aprovação da spec; gravar na spec "Status: Approved" e a linha "Aprovação do dono" (fala literal, data, link) | Dono aprova; Analista de requisitos grava | spec aprovada e gravada |
| 14 | Depois do 13b, se o dono aprovou E25·2 ou E25·3: escrever só essas linhas no `DESIGN.md`; se a resposta diferir da recomendação, ajustar o construído (volta aos passos 2 a 9) | Designer de produto; Engenheiro de software no ajuste | texto igual à resposta do dono; Revisor de design confere |

## Revisão (etapa 9)

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 15 | Revisar o código: camadas, RT-9, acessibilidade nos padrões do WAI-ARIA, testes, escopo do `plan.md` §3 (`git diff --name-only chore/fundacao-tecnica...HEAD`) | Revisor de código | relatório sem "Bloqueia" |
| 16 | Revisar o ADR 0004 | Revisor de código | "Revisão" preenchida no ADR |
| 17 | Veredito de CA-1 a CA-10 pelo `plan.md` §11, com o link da CI e do artefato | Analista de qualidade (QA) | veredito com links |
| 18 | Conferir o pedido, item por item (etapa 10) | Analista de requisitos | conferência registrada na spec |
| 19 | Fila, estado, `CHANGELOG.md` e respostas E25 em `docs/decisoes/`, no mesmo PR (etapa 11) | Documentador | arquivos atualizados |

## Merge (etapas 12 e 13)

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| 20 | **Parada do dono (etapa 12):** pedido de merge no molde, com o commit citado, a CI verde e o **link da prévia** (conferência do dono na prévia, `AGENTS.md` §9); só depois de o item 2 ser juntado e o PR redirecionado à `previas` | Gerente de projeto | autorização do dono no chat |
| 21 | Gravar "Aprovação do merge" na spec (fala literal, data, link, commit) e juntar só esse commit (etapa 13) | Engenheiro de DevOps | merge feito; envio novo depois do pedido pede revisão e pedido novos |
