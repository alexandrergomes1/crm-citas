# Estado do projeto

> Aprovado pelo dono em 27/11/2026 (E18). Escrito por: Documentador · Revisado por: Gerente de projeto

## Onde estamos (28/11, noite)
- **Na `previas`:** PRs #1 a #4 e o **PR #7 (Entrar e camada de serviço, item 4a), juntado** no commit `2dad348`
  (E49·A, "E49a juntar"). Os PRs #5 (trava por estúdio no banco) e #6 (design system no código) entraram dentro
  do #7 e **seguem abertos sem uso**. A branch `chore/base-fundacao` está toda na `previas`; **o dono apaga** em
  https://github.com/alexandrergomes1/crm-citas/branches (lixeira).
- **Revisão do processo (item 4b), em curso** (ordem do dono de 28/11): travas E65·1 a E65·8 aprovadas ("E65 sim"),
  molde com o bloco do que precisa do dono, registro de toda proposta futura, revisão das conversas anteriores
  (em curso), organização da pasta `specs/` (pergunta do dono, a responder com proposta).
- **Agenda (item 5), parada até a revisão do processo** (ordem do dono), na `feat/agenda` (a branch já existia; pedido do dono "pode criar a branch da
  Agenda"). [Spec](https://github.com/alexandrergomes1/crm-citas/blob/feat/agenda/specs/20261128-020000-agenda/spec.md) com "Status: Approved" e os ajustes E54 a E58;
  plano e [ficha visual](https://github.com/alexandrergomes1/crm-citas/tree/feat/agenda/specs/20261128-020000-agenda/ficha) sendo atualizados pelo Arquiteto e pelo Designer.
  E59 e E60 respondidas (28/11); o Analista grava o detalhe na spec. Sem código ainda.
- **Ordem da fila (E57·B):** a Agenda sai antes sem as visões, que aparecem "em desenvolvimento"; a spec
  "Agenda · visões e horário de funcionamento" vem logo depois ([fila](https://github.com/alexandrergomes1/crm-citas/blob/feat/agenda/docs/BACKLOG.md), item 5).
- **Avaliação do antigo** (só leitura, nada copiado; E43·A autorizou as ideias): `docs/produto/avaliacao-crm-agenda/`.
  As ideias entram em cada spec quando a branch dela for trabalhada (E44).
- **Matriz de permissões (ADR 0020, E42·A):** porta 3 por chave `modulo.acao`. Personalização: item 6a da fila.
- **Specs revisadas, sem código** (aprovadas): agendamento, clientes, formulários, catálogo, checkout, caixa. Cada uma
  recebe a linha "Aprovação do dono" e os ajustes (E29·1, E31·1, E31·2, E32·1, E39·2, E39·3) quando a branch dela
  for trabalhada.

## Esperando o dono
1. **E38·A1:** travas em `.claude/` agora que o Entrar entrou, numa conversa nova, num PR só para elas.
   **D2:** PRs do Dependabot e a `main`.
2. Apagar `chore/base-fundacao` (o dono, na página de branches). Fechar ou não os PRs #5 e #6 (abertos sem uso).

**Respondidas em 28/11 e ainda por aplicar nas specs (Analista, quando cada branch for trabalhada):** E29·1 (PIN),
E29·3 (troca), E64·A (Agendamento: a profissional vê e abre só os dela; spec na branch `feat/agendamento`), E31·1 (caixa opcional), E32·1 (aviso de caixa aberto), E40·B, E45·A (Checkout e Caixa), E46·A
(Catálogo), E44 (ler a parte do antigo de cada módulo ao fazer a spec), ideias E43·A de cada módulo.

## Já aprovado

| Código | O quê |
|---|---|
| E1 | estrutura de pastas e nomes |
| E2, E2b | equipe de 15 papéis e lista de ferramentas (proposta) |
| E3 | idiomas, núcleo da primeira versão, nome provisório |
| E4 | camada única de serviço, painel admin, ordem de entrada |
| E5 | conferência AWS e ASVS, dados na UE, ficha de saúde cifrada, metas de recuperação |
| E6 | `ARCHITECTURE.md` (com as exceções E6·1 e E6·2) |
| E7 | `AGENTS.md` e nomes novos (E7·1) |
| E8 | ordem dos arquivos da base |
| E9 | molde de mensagem (`docs/moldes/pergunta.md`) |
| E10 | `DESIGN.md` e canvas em `docs/design/` |
| E11 | guia do processo (`docs/guias/processo-sdd.md`) |
| E12 | papéis do Claude, ajustes do molde, imagens do design |
| E13 | detalhes visuais (contador, pílula, funil) |
| E14 | `SECURITY.md`, `CONTRIBUTING.md`, gitleaks e Dependabot (pendência) |
| E15 | regras das 4 pastas de código; larguras 390 px e 1440 px |
| E16 | as 4 skills e as regras de cópia, bloqueio e gravação das aprovações |
| E17 | etapa 5b: o Gerente de projeto confere spec e plano antes do dono |
| E18 | ordem da fila (`docs/BACKLOG.md`, itens 1 a 10); este estado e o `README.md` seguem como referência aprovada |
| E19 | merge do PR #1 (base) na `previas` |
| E19·1 (troca) | apagar `chore/base-fundacao`; o repositório fica público |
| E20 | item 1: ler o projeto antigo só para listar os módulos; nada se copia |
| E21 | spec do item 1 e lista de módulos; nova ordem dos itens 6 a 10 (E21·1) |
| E21·2 | a ficha de saúde fica dentro de Formulários |
| E21·3 | cobrança à cliente e vale-presente entram depois do núcleo |
| E22·B | pacote da madrugada: specs e construção em PRs de rascunho, banco só local |
| E23·2·A, E23·3·A | prévia na Cloudflare depois, em spec própria; só gratuito, achou custo para e pergunta |
| E33 | merge do PR #2 (item 1), sem CI |
| E34 | spec da ordem E21·1 (PR #3) e merge |
| E35 | `previas` como branch padrão e ruleset `protecao` em `main` e `previas` |
| E36 | item novo da fila: Entrar e camada de serviço, antes do núcleo |
| E37·A | spec do item 2 (com o R15) e ordem de merge #4, #2, #3 |
| E38·A | ligar as travas do Claude em `.claude/` num PR próprio (pendente da permissão na hora) |
| E38·A1 | travas do Claude depois do merge do Entrar, conversa nova, PR próprio (troca o "pendente" da E38·A) |
| E47·1·A, E47·2·A, E47·3·A | ajustes das telas do Entrar; termo neutro no lugar de "estúdio": "empresa" (pt, es), "business" (en) |
| E48·A | a IA pode enviar à `feat/entrar-servico` (PR #7) |
| E49·A | merge do PR #7 (item 4a) na `previas`, commit `2dad348` |
| E54–E58 | ajustes da spec da Agenda; E57·B: visões da Agenda em spec própria, logo depois |
| E65 | as 8 travas T1 a T8 da auditoria do processo da Agenda, a aplicar pelo fluxo (item 4b) |
| E24–E41 | respostas do relatório de 28/11 e aprovação das 10 specs (detalhe e falas em `docs/decisoes/`) |

## Pendências técnicas para a próxima conversa
1. **Pendências que ficaram do Entrar (dívidas a–f)**, aceitas no merge do PR #7; o dono decide se viram item da fila:
   (a) cópias de peças do design system em
   [`src/app/paginas/`](https://github.com/alexandrergomes1/crm-citas/tree/previas/src/app/paginas),
   porque `src/app/ui` estava fora dos arquivos permitidos (plano §10); (b) seta para cima do menu;
   (c) barra provisória N1/N2; (d) o endereço `/escolher-estudio` ainda mostra "estudio";
   (e) **R-A: `cf-connecting-ip` a corrigir antes de qualquer publicação**; (f) relatório público do Playwright
   na CI. **Para o Arquiteto registrar em ADR** (decisões técnicas do Engenheiro de software): servidor do e2e sem
   a chave admin e `globalSetup` em processo filho; `reuseExistingServer: false`; `PLAYWRIGHT_CHROMIUM`; leitura
   dos dois formatos da saída de `supabase db query` (mudam com as variáveis `AI_AGENT`/`CLAUDECODE`).
2. Sem Docker aqui: o banco pode ser testado num Postgres 16 local com papéis e auth simulados (`/var/tmp/pgscratch`,
   porta 54329: stub de `anon`, `authenticated`, `service_role`, `auth.uid()`, `auth.jwt()`, `auth.users`, pgcrypto,
   btree_gist e pgtap no esquema `extensions`). Não substitui o `pnpm db:test`.
3. Achado do Engenheiro de dados: pessoa em dois estúdios pode ser marcada no mesmo horário nos dois (Analista).
4. DevOps: nome da variável `SUPABASE_CHAVE_ADMIN_LOCAL` na CI; `prettier --check` acusa 17 arquivos.
5. Avisos já dados: R-13, R-3, R-17. Chave de servidor e de assinatura no banco online só com autorização de publicação.

## Falta na base
- E-mail de segurança quando houver domínio (E14·1); travas do Claude Code em `.claude/` (E38·A1, depois do merge do Entrar).

## Como continuar numa conversa nova

**Onde estão as coisas**
- Repositório `alexandrergomes1/crm-citas`; trabalho em curso na branch `feat/agenda` (Agenda, item 5).
- Respostas do dono: `docs/decisoes/2026-11-27-fundacao.md`.
- Projeto antigo (`crm-agenda`): **só se lê com autorização do dono, item por item** (`AGENTS.md` §3 regra 4).

**Prompt pronto para o dono colar**

```
Leia AGENTS.md do repositório alexandrergomes1/crm-citas (branch feat/agenda). Estado: docs/STATUS.md. Decisões: docs/decisoes/2026-11-27-fundacao.md. Use os papéis de .claude/agents e as skills de .claude/skills em tudo, declarando papel e norma. Minhas respostas do relatório: <cole aqui a resposta copiada da página>. Grave as respostas e aprovações, depois siga as pendências do STATUS (Agenda, travas E38·A1, dívidas do Entrar). Nada se copia do projeto antigo sem a minha autorização item por item.
```
