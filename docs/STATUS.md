# Estado do projeto

> Aprovado pelo dono em 27/11/2026 (E18). Escrito por: Documentador · Revisado por: Gerente de projeto

## Onde estamos (28/11, noite)
- **Na `previas`:** PRs #1 a #4. A branch `chore/base-fundacao` está toda na `previas`; o dono autorizou apagar, mas
  o acesso desta sessão recusou: **o dono apaga** em https://github.com/alexandrergomes1/crm-citas/branches (lixeira).
- **Respostas do relatório gravadas** (`docs/decisoes/2026-11-27-fundacao.md`) e **as 10 specs aprovadas**. Só a spec
  do Entrar já tem a linha "Aprovação do dono" (esta branch); as outras 9 recebem a linha quando a branch de cada uma
  for trabalhada (esta sessão só envia à `feat/entrar-servico`). Respostas com ajuste ou pedido junto (E29·1, E31·1,
  E31·2, E32·1, E39·2, E39·3) entram no texto de cada spec pelo Analista de requisitos nessa hora.
- **PR #7 (`feat/entrar-servico`), item 4a: em pedido de merge (PR #7)** (tarefa F3, Gerente de projeto).
  CI 5/5 verde no `13d6b9d`. Revisores (código, segurança, design, dados, auditor de risco): todos "Libera com
  ressalvas". QA: "Libera com ressalvas". **CA-22 depende do dono:** conferir as telas na prévia (E23·2·A).
  Depois do `13d6b9d` entraram `afc5198` (texto da spec) e `6b1f3a2` (teste de pedido forjado, RF-10) e este
  registro; o pedido de merge cita o último commit do PR, com a CI verde nele.
  [Spec](https://github.com/alexandrergomes1/crm-citas/tree/feat/entrar-servico/specs/20261128-030000-entrar-servico) ·
  [como rodar](https://github.com/alexandrergomes1/crm-citas/blob/feat/entrar-servico/CONTRIBUTING.md#9-como-rodar).
- **Avaliação do antigo** (só leitura, nada copiado; E43·A autorizou as ideias): `docs/produto/avaliacao-crm-agenda/`
  `regras-do-banco.md` (74 regras, 2 leituras), `seguranca-do-banco.md` (25) e `permissoes-e-pin.md`. Banco do antigo
  **esgotado** para o núcleo. As ideias entram em cada spec quando a branch dela for trabalhada.
- **Matriz de permissões (ADR 0020, E42·A):** porta 3 por chave `modulo.acao`; S7 (`bfbb9b9`) e B7 (`8fd1a24`);
  385 testes de unidade; `pnpm db:test` não rodou (sem Docker). Personalização: item 6a da fila.
- **Specs revisadas, sem código** (aprovadas): agenda, agendamento, clientes, formulários, catálogo, checkout, caixa.

## Esperando o dono
1. **E38·A1:** travas em `.claude/` depois do merge do Entrar (PR #7), numa conversa nova, num PR só para elas.
   **D2:** PRs do Dependabot e a `main`.
2. Apagar `chore/base-fundacao` (o dono, na página de branches).
3. Item 4a em pedido de merge (PR #7): autorização do merge (F3, Gerente de projeto) e conferência das telas na
   prévia (CA-22).

**Respondidas em 28/11 e ainda por aplicar nas specs (Analista, quando cada branch for trabalhada):** E29·1 (PIN),
E29·3 (troca), E31·1 (caixa opcional), E32·1 (aviso de caixa aberto), E40·B, E45·A (Checkout e Caixa), E46·A
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
| E24–E41 | respostas do relatório de 28/11 e aprovação das 10 specs (detalhe e falas em `docs/decisoes/`) |

## Pendências técnicas para a próxima conversa
1. **Ressalvas do Entrar, em dívida** (aceitas para o merge; o dono decide se viram item da fila):
   (a) cópias de peças do design system em
   [`src/app/paginas/`](https://github.com/alexandrergomes1/crm-citas/tree/feat/entrar-servico/src/app/paginas),
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
- Repositório `alexandrergomes1/crm-citas`; trabalho em curso na branch `feat/entrar-servico` (PR #7).
- Respostas do dono: `docs/decisoes/2026-11-27-fundacao.md`.
- Projeto antigo (`crm-agenda`): **só se lê com autorização do dono, item por item** (`AGENTS.md` §3 regra 4).

**Prompt pronto para o dono colar**

```
Leia AGENTS.md do repositório alexandrergomes1/crm-citas (branch feat/entrar-servico). Estado: docs/STATUS.md. Decisões: docs/decisoes/2026-11-27-fundacao.md. Use os papéis de .claude/agents e as skills de .claude/skills em tudo, declarando papel e norma. Minhas respostas do relatório: <cole aqui a resposta copiada da página>. Grave as respostas e aprovações, depois siga as pendências do STATUS (revisões do Entrar, telas, módulos). Nada se copia do projeto antigo sem a minha autorização item por item.
```
