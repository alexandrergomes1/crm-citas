# Spec · Fundação técnica (item 2 da fila)

- **Status:** Approved
- **Aprovação do dono:** "E37a, E23-2a, E23-3a, e38a," · 28/11/2026 ·
  https://claude.ai/code/session_018cV8b9epaQJNqguG5c5Aqb · Gravado pelo Analista de requisitos (E16·3).
  Significado: E37·A = spec aprovada, incluindo o R15 (textos do `AGENTS.md` §1 e do `docs/guias/processo-sdd.md` §5),
  e o PR #4 é juntado primeiro · E23·2·A = prévia na Cloudflare depois, em spec própria · E23·3·A = só o gratuito ·
  E38·A = travas do Claude ligadas em `.claude/` num PR próprio, depois do PR #4.
- **Aprovação do merge:** "E37a" (E37·A: "eu junto o PR #4 primeiro") · 28/11/2026 ·
  https://claude.ai/code/session_018cV8b9epaQJNqguG5c5Aqb · commit `d4aa972` (PR #4), CI verde nos 5 jobs.
  Gravado pelo Engenheiro de DevOps.
- **Branch:** `chore/fundacao-tecnica` (a partir da `previas`)
- **Escrito por:** Analista de requisitos · Norma: IEEE 29148 e BABOK · **Revisão:** pendente (etapa 5b, Gerente de projeto)
- **Tipo de trabalho:** Código, Banco (só o banco local) e Segurança (gitleaks, Dependabot, CI). Revisores pelo
  `docs/guias/processo-sdd.md` §3. A página vazia não é tela de produto: sem ficha visual (a confirmar na etapa 5b).

## 1. Origem (pedido do dono)
- `docs/BACKLOG.md` item 2: "Fundação técnica: ferramentas, app vazio, Spec Kit instalado, travas automáticas
  (gitleaks e Dependabot, E14·3) e CI; travas automáticas: trazer as do projeto antigo pela skill trazer-do-antigo,
  com autorização do dono item por item".
- E14·3: "E14·3 aprovo (se for gratuito ver limmites tbm)".
- Pedido (travas): "recupera as travas pra vc nao tomar decisao e saber falar comigo".
- `AGENTS.md` §1: os comandos entram com a spec da fundação; antes de enviar, checagem de tipos, lint e testes.
- Contexto do dono em 28/11/2026: o repositório fica **público** de propósito, para usar os minutos grátis do
  GitHub Actions: "Eu deixei público o projeto para vc ter os actions pra usar se preciso pq no privado tá sem
  limite. Salvo se conseguires mudar entre público e privado qdo precisar ." (E19·1 troca, PR #2; ver §8, D1).
- E22·B (28/11/2026): travas do antigo autorizadas e construção em PR de rascunho (ver §5).
- Por que o item 2 anda com o item 1 ainda em revisão: o "Pedido (núcleo de uma vez)" ("veja se consegue construir
  todo o núcleo com os devidos papéis rodando adequadamente nele (...) talvez pulando a regra de um item por vez") e a
  resposta E22·B, que autoriza specs e construção em PRs de rascunho, sem merge sem o dono (`docs/decisoes/`, PR #2).

## 2. Objetivo
Deixar o projeto pronto para construir com segurança: um app vazio que roda, as quatro camadas no lugar, testes e
checagens automáticas a cada PR, banco local para testes e o Spec Kit instalado. Nada de produto ainda.

## 3. Requisitos

| # | Requisito | Fonte |
|---|---|---|
| R1 | App vazio com TypeScript, React e TanStack Start, gerido por pnpm, que sobe em modo de desenvolvimento e gera build sem erro. A única página mostra só o texto "crm-citas" (nome provisório), sem design. | `ARCHITECTURE.md` §12; E3·3 |
| R2 | Pastas `src/app`, `src/server`, `src/domain`, `src/data` e `supabase/` usadas como no `ARCHITECTURE.md` §3; os `AGENTS.md` e `CLAUDE.md` das pastas ficam intactos. | `ARCHITECTURE.md` §3; E15 |
| R3 | Uma regra automática (lint) barra importação proibida entre camadas: `src/domain` não importa tela, servidor, dados nem framework; `src/app` não importa `src/data` nem o cliente do banco. | `ARCHITECTURE.md` §3; `src/*/AGENTS.md` |
| R4 | Vitest com 1 teste de exemplo em cada camada que tiver código. | `ARCHITECTURE.md` §11 |
| R5 | Playwright com 1 teste da página vazia nas larguras 390 px e 1440 px. | `DESIGN.md` §9; E15·1 |
| R6 | Checagem de tipos e lint, sem erro no projeto inteiro. | `AGENTS.md` §1 |
| R7 | Scripts fixos no `package.json` para: tipos, lint, testes, testes de tela, banco local e teste do banco. A lista exata de nomes fica no plano. | `AGENTS.md` §1 |
| R8 | Supabase local (linha de comando com Docker), com 1 migration vazia e 1 teste de banco de exemplo que passa. Nada liga a banco remoto. | `ARCHITECTURE.md` §3 e §8; `AGENTS.md` §1 |
| R9 | Spec Kit instalado conforme `processo-sdd.md` §5: pastas `specs/AAAAMMDD-HHMMSS-nome/` (numeração por data e hora), sem criar branch (a branch `tipo/area-assunto` é aberta pelo Engenheiro de DevOps na etapa 2), constituição que só aponta para o `AGENTS.md`. A instalação não sobrescreve `AGENTS.md`, `CLAUDE.md`, `.claude/agents/` nem `.claude/skills/`. Os nomes dos comandos do Spec Kit entram no `processo-sdd.md` §5. | `processo-sdd.md` §5; `AGENTS.md` §6 |
| R10 | CI no GitHub Actions a cada PR para `previas` e para `main`, rodando: tipos, lint, testes, testes de tela (390 e 1440), banco local com a migration e o teste de banco, e gitleaks. | `AGENTS.md` §8; `ARCHITECTURE.md` §8 ("nada vai direto à `previas` ou à `main`: só por PR com CI verde") |
| R11 | gitleaks procura segredo no histórico inteiro e em cada PR; achou, a CI fica vermelha. | E14·3; `SECURITY.md` §2 e §7 |
| R12 | Dependabot ligado para as dependências do pnpm e para as ações do GitHub Actions. | E14·3; `SECURITY.md` §7 |
| R13 | Gratuidade e limites de GitHub Actions, Dependabot e gitleaks em repositório público confirmados na documentação oficial, com link e data, no plano. Achou custo ou limite que afete o projeto: o trabalho para e vira pergunta ao dono. | E14·3 ("se for gratuito ver limites tbm") |
| R14 | Testes e CI usam só dados fictícios; nenhum dado pessoal ou de saúde, nenhum segredo. | `AGENTS.md` §6; E5·1 |
| R15 | `AGENTS.md` §1 recebe a lista de comandos do R7. O texto exato vai no plano e é aprovado pelo dono junto com esta spec; o Documentador registra a aprovação em `docs/decisoes/`. Junto, vai à aprovação do dono a mudança de regra no `docs/guias/processo-sdd.md` §5 (linhas 61 a 63: o nome da branch não vem do Spec Kit; nomes dos comandos), com o texto exato no plano. | `AGENTS.md` §1 e cabeçalho; `processo-sdd.md` (aprovado no E11) |
| R16 | Documentos de controle (`docs/STATUS.md`, `docs/BACKLOG.md`, `CHANGELOG.md`) e a seção "Como rodar" do `README.md` atualizados no mesmo PR, pelo Documentador. | `AGENTS.md` §9 |

## 4. Fora de escopo
Publicar (Cloudflare, Wrangler, prévia online) · banco remoto (desenvolvimento ou produção) · segredos em qualquer
cofre · qualquer módulo · design system (item 4 da fila) · tabelas, trava RLS e teste de isolamento por estúdio
(item 3) · ligar o banco existente · mudar configurações do repositório no GitHub (visibilidade, proteção de branch).

## 5. Travas do projeto antigo (autorizadas pelo E22·B)
O dono respondeu ao E22 em 28/11/2026: "O banco de dados atual é tudo de desenvolvimento, todos os dados são
fictícios. O que se tem são as tabelas e regras dele. Então use se precisar. E22b Bom trabalho e obrigado."
(`docs/decisoes/`, PR #2). Fica autorizado ler e trazer do projeto antigo as travas automáticas deste item, pela
skill `trazer-do-antigo`.
- R17: cada trava é decidida pelo papel da área (copiar, reescrever ou descartar), com o motivo em `docs/adr/` e a
  conferência de outro papel (`AGENTS.md` §3 regra 4; E16·1). Dado real e segredo nunca vêm.
- A lista das travas trazidas e a decisão de cada uma ficam no plano, antes de construir.
- Construção em PR de rascunho antes da aprovação da spec é permitida (E22·B); nada é juntado sem o dono.

## 6. Critérios de aceite (verificáveis)

| # | Critério | Prova |
|---|---|---|
| CA1 | Numa cópia limpa, instalar as dependências e rodar o script de build termina sem erro. | saída da CI |
| CA2 | O teste do Playwright abre a página e acha o texto "crm-citas" em 390 px e em 1440 px, sem rolagem lateral. | relatório da CI |
| CA3 | Existe 1 teste Vitest em cada camada com código, e todos passam. | relatório da CI |
| CA4 | Um arquivo de teste com importação proibida (ex.: `src/domain` importando `src/data`) faz o lint falhar; sem ele, o lint passa. | teste feito pelo QA, registrado no veredito |
| CA5 | Checagem de tipos e lint passam sem erro. | saída da CI |
| CA6 | O banco local sobe, aplica a migration vazia e o teste de banco passa, na máquina e na CI. | saída da CI |
| CA7 | A CI roda sozinha num PR para `previas` com todos os passos do R10, e fica verde. | link da execução |
| CA8 | Um segredo falso de teste num commit descartável faz o gitleaks deixar a CI vermelha (prova feita em branch de teste, apagada depois). | link da execução |
| CA9 | O arquivo de configuração do Dependabot existe e o GitHub o aceita sem erro. | aba do Dependabot no GitHub |
| CA10 | O plano traz os links oficiais que confirmam gratuidade e limites (R13). | `plan.md` |
| CA11 | O Spec Kit cria a pasta `specs/AAAAMMDD-HHMMSS-nome/` de uma spec de teste e não cria branch (a branch segue a etapa 2 do `processo-sdd.md`); a constituição só aponta para o `AGENTS.md`; `AGENTS.md`, `CLAUDE.md`, `.claude/agents/` e `.claude/skills/` sem mudança fora do R15. | `git diff` revisado |
| CA12 | Nenhum arquivo fora da lista do plano muda; nenhum segredo, dado pessoal ou endereço de banco remoto no repositório. | revisão de código e gitleaks |
| CA13 | `AGENTS.md` §1, `processo-sdd.md` §5 e o "Como rodar" do `README.md` trazem os comandos reais, iguais aos scripts. | revisão de texto |

## 7. Dúvidas para o dono (2)

**Respondidas em 28/11/2026 ("E23-2a, E23-3a"):** E23·2·A (prévia na Cloudflare depois, em spec própria) e
E23·3·A (só o gratuito; achou custo, para e pergunta).

(A E23·1, sobre as travas do antigo, saiu: já respondida pelo E22·B, ver §5.)

**E23·2 · Prévia online na Cloudflare (precisa da sua conta e de um token)**
- E23·2·A: depois, numa spec própria antes do item 4 (primeira tela de verdade). → nada de conta ou token agora.
- E23·2·B: agora, nesta spec. → você cria a conta e o token, e o guarda no cofre do GitHub.
- **Recomendo A:** o app vazio não tem o que conferir, e token é acesso a produção; melhor só quando houver tela.

**E23·3 · Custo**
- E23·3·A: só o gratuito; achou custo, para e pergunta. → nenhum cartão cadastrado.
- E23·3·B: aceitar gasto até um teto mensal que você define.
- **Recomendo A:** em repositório público, GitHub Actions, Dependabot e gitleaks devem ser gratuitos (a confirmar
  no plano, R13), e o Supabase roda local.

## 8. Dependências e riscos (para o dono ver; não são Assumptions)
- **D1 · Repositório público:** decidido pelo dono em 28/11/2026 (troca do E19·1, registrada em `docs/decisoes/`,
  PR #2): o repositório fica público. O `SECURITY.md` §1, que diz "este é privado", é corrigido em PR próprio, fora
  desta spec. Em repositório público, tudo o que entra fica visível: o gitleaks no histórico inteiro (R11) e o log
  com o segredo escondido são a proteção.
- **D2 · PR do Dependabot:** cada atualização vira um PR que pede revisão e merge autorizado. O plano confere na
  documentação oficial para qual branch vão os PRs de segurança (nunca direto à `main`, `AGENTS.md` §8).
- **D3 · CI obrigatória:** a CI só barra o merge se a `previas` e a `main` exigirem a CI verde (configuração do
  GitHub, que é do dono). Fica para pedido separado, com os cliques exatos.

## 9. Assumptions (decisões técnicas pela norma; recuse pelo número)
1. Versões: as estáveis atuais de Node (versão de suporte longo), pnpm, TanStack Start, React, TypeScript, Vitest,
   Playwright, Supabase CLI e Spec Kit, lidas na documentação oficial no plano e fixadas no repositório (Twelve-Factor, fator II).
2. Teste de banco com a ferramenta oficial de teste do Supabase local (confirmada na documentação no plano).
3. Lint de camadas por regra de importação no próprio lint (sem ferramenta extra, se a oficial bastar; `AGENTS.md` §3 regra 6).
4. gitleaks pela versão aberta (linha de comando), sem chave; se a ação oficial pedir licença, usa-se a linha de comando.
5. CI com permissão mínima de leitura, ações fixadas por versão exata e sem gatilho que exponha segredo a PR de fora
   (OWASP ASVS 4.0.3 V14.2; boas práticas de segurança do GitHub Actions).
6. Playwright só com o navegador Chromium nas duas larguras; outros navegadores entram por spec, se o dono pedir.
7. Dependabot com verificação semanal e PRs para a `previas` (onde a documentação permitir; ver D2).
