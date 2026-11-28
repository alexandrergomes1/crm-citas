# Tarefas · Entrar e camada de serviço (as 6 portas) · E36·A

- **Spec:** `spec.md` · **Plano:** `plan.md` · **ADR:** `docs/adr/0018-entrar-sessao-e-camada-de-servico.md` (e o 0019,
  escrito na tarefa B1)
- **Escrito por:** Arquiteto de software · **Norma:** modelo C4 e ADR · **Revisão:** 5b (Gerente de projeto) feita com ajustes, 28/11; etapa 5 (Analista de
  requisitos) pendente
- **Pode começar antes da aprovação**, só em PR de rascunho (E22·B): banco, dados e servidor (B1 a B7, S1 a S8, D1 a D3)
  começam já; as telas (T1 a T3) esperam só a ficha **feita e conferida** (P3, P4), não o "sim" do dono, que vem com a
  aprovação da spec. O portão continua no pedido de merge: nada é juntado sem "Status: Approved", "Aprovação do dono" e a
  autorização do merge gravada (`AGENTS.md` §3 regra 1 e §8). Banco só local; a IA nunca aplica nada no remoto
  nem publica (`AGENTS.md` §1).
- Só os arquivos do `plan.md` §10. Biblioteca, API ou comando só depois de lido na fonte (`AGENTS.md` §6). Falhou: refaz e
  confere; o mesmo erro duas vezes, para e relata. Commits pequenos, Conventional Commits, citando a spec.
- Dados de teste sempre fictícios. Nenhum segredo em código, chat, registro ou arquivo; a chave local de administração só
  em memória, só em `tests/` e `e2e/`.

## Preparação

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| P1 | Juntar por merge na `feat/entrar-servico` a `feat/banco-ligacao` e a `feat/design-system-codigo`; resolver os conflitos do `plan.md` §12 sem mudar o conteúdo deles | Engenheiro de DevOps | árvore limpa; `pnpm install`, `typecheck`, `lint`, `test`, `db:start`, `db:test` verdes como nos itens 3 e 4 |
| P2 | Abrir o PR de rascunho empilhado (base: a branch do item 3, ou a `previas` se 3 e 4 já entraram) | Engenheiro de DevOps | PR em rascunho, CI rodando |
| P3 | Ficha visual: Entrar (vazio, carregando, erro, limite), Escolher estúdio (lista, carregando, erro), Sua conta (com e sem troca), em 390 e 1440, lado a lado com o `DESIGN.md`; lista dos nomes e peças novos (`plan.md` §7 e L-4) | Designer de produto | `ficha-visual.md` e `ficha/` prontos |
| P4 | Conferir a ficha pelo `DESIGN.md` §10 e ajustar até não haver "Bloqueia". O "sim" do dono à ficha vem junto da aprovação da spec (etapas 6 e 7); com ele, o Designer grava os nomes e peças no `DESIGN.md` antes do pedido de merge | Revisor de design; Designer de produto | ficha conferida; depois do "sim", resposta gravada pelo Documentador e `DESIGN.md` atualizado |

## Construção · Banco (Engenheiro de dados)

| # | Passo | Feito quando |
|---|---|---|
| B1 | Escrever o ADR 0019 (desenho de M1 a M5, privilégios, troca da linha D9 do ADR 0005, como os nomes de estúdio chegam à tela Escolher estúdio) dentro do `plan.md` §6 | ADR com motivo e norma em cada linha |
| B2 | Mudar o `db:start` (`plan.md` §8) e `auth.enable_signup: false`; conferir que o Auth sobe sem `mailpit` (R-4) e que uma migration consegue `alter role authenticator set pgrst.db_pre_request` (R-1). Se R-1 falhar: parar e relatar | `pnpm db:start` com Auth e Data API respondendo; R-1 e R-4 anotados no PR |
| B3 | M1 `registro` e M2 `registro_funcoes` | aplica sem erro |
| B4 | M3 `sessoes` e M4 `tentativas_entrada` | aplica sem erro |
| B5 | M5 `estudios_da_pessoa_e_pre_pedido`; conferir a forma de `request.path` (R-2) | aplica sem erro; R-2 anotado |
| B6 | Testes `060_` a `100_`, a lista nova do `010_` e o molde `registro_tabela_test.sql` | `pnpm db:test` verde, inclusive os do item 3 |
| B7 | Prova de que pega erro: numa cópia local, tirar o pré-pedido e o gatilho e ver `100_` e `060_` vermelhos; desfazer | vermelho visto e desfeito; nada no commit |

## Construção · Servidor, dados e regras (Engenheiro de software)

| # | Passo | Feito quando |
|---|---|---|
| S1 | Dependências do ADR 0018 · D1, versões exatas; ler no `.d.ts` instalado `createServerClient`, `cookieOptions`, `getClaims`, `signInWithPassword`, `signOut`, `rpc` | `pnpm install` sem aviso de versão; fontes no PR |
| S2 | `eslint.config.mjs` e `eslint.camadas.test.ts` (`plan.md` §8): os casos novos dão erro, os permitidos passam | `pnpm test` verde |
| S3 | `src/domain/idioma.ts` com teste | verde |
| S4 | `src/data/*` (`plan.md` §5): ambiente, cliente com cookie HttpOnly e contagem de gravações, chamadas de sessão, mapa de erros, com testes | verde; nenhum `getSession`, nenhuma chave secreta |
| S5 | `src/server/portas/*` e `src/server/http/middleware.ts` (contrato do `plan.md` §4); testes CA-07, CA-08, CA-12, CA-21 | verde |
| S6 | `src/server/sessao/*` (fluxos do `plan.md` §3.1 a §3.4), com teste de unidade | verde |
| S7 | `scripts/banco-local.mjs` precisa existir (tarefa D1) antes de S8 | — |
| S8 | `tests/integracao/*` e `vitest.integracao.config.ts`: CA-01, CA-04, CA-05, CA-06, CA-09, CA-09a, CA-13, CA-14, CA-15, CA-16, CA-18 | `pnpm test:integracao` verde com o banco local |

## Construção · Telas (Engenheiro de software) · só depois de P3 e P4

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| T1 | `src/app/i18n/*` no formato do ADR 0006 · D1, com o teste (CA-20) | Engenheiro de software | verde |
| T2 | `src/app/start.ts`, rotas e páginas do `plan.md` §7, só com componentes do item 4 e textos dos arquivos de idioma; campo Senha com mostrar e esconder como está na ficha (P3); se o dono pedir mudança na aprovação, ajusta antes do pedido de merge | Engenheiro de software | `typecheck`, `lint`, `test` verdes |
| T3 | `e2e/*` e `playwright.config.ts`: CA-02, CA-03 (rede), CA-13, CA-18a, CA-19, CA-20, com `AxeBuilder`, nos projetos `celular` e `computador` | Engenheiro de software | `pnpm test:e2e` verde com o banco local |

## Construção · CI (Engenheiro de DevOps)

| # | Passo | Feito quando |
|---|---|---|
| D1 | Ler `supabase status -o json` da CLI 3.4.0 (R-5) e escrever `scripts/banco-local.mjs` (nada impresso nem gravado em arquivo) | `pnpm test:integracao` acha o banco; nenhum valor no log |
| D2 | `scripts/conferir-pacote.mjs` depois de ler a pasta de saída do `build` (R-10) | falha se achar `supabase`, o endereço ou a chave no pacote do navegador |
| D3 | `ci.yml` (`plan.md` §8): jobs `banco`, `telas` e `verificar` ajustados; nomes, permissões e ações fixadas iguais | os 5 jobs verdes no PR |

## Revisão (etapa 9)

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| R1 | Código, molde e contrato (ADR 0018 · D11 a D15; lista do §10) | Revisor de código | sem "Bloqueia" |
| R2 | Migrations e testes; ADR 0019 conferido item por item | Engenheiro de dados que **não** construiu | sem "Bloqueia"; conferência preenchida |
| R3 | Sessão, cookie, CSRF, limite, registro, privilégios de `anon`, chave secreta fora de `src/` (ADR 0018 · D2 a D10) | Engenheiro de segurança | sem "Bloqueia" |
| R4 | Riscos R-1 a R-12, funções `security definer`, pré-pedido, R-3 | Auditor de risco | sem "Bloqueia" |
| R5 | Telas pelo `DESIGN.md` §10, nas capturas do e2e | Revisor de design | sem "Bloqueia" |
| R6 | Veredito de CA-01 a CA-22 pelo `plan.md` §9 | Analista de qualidade (QA) | veredito com links |

## Fechamento (etapas 10 a 13)

| # | Passo | Papel | Feito quando |
|---|---|---|---|
| F1 | Conferir o pedido item por item (RF-01 a RF-35, RNF-01 a RNF-05) e as lacunas L-1 a L-4 | Analista de requisitos | tudo cumprido ou relatado |
| F2 | `CHANGELOG.md`, `CONTRIBUTING.md`, `docs/STATUS.md`, `docs/BACKLOG.md` e respostas do dono no mesmo PR | Documentador | no PR |
| F3 | Pedido de merge no molde, com o commit, a CI verde, o link da prévia e o passo a passo para o dono no painel do Supabase (cadastro aberto desligado; limite do Auth, R-3) | Gerente de projeto | mensagem enviada e aviso no celular |
| F4 | Gravar "Aprovação do merge" e juntar só esse commit | Engenheiro de DevOps | merge feito |
