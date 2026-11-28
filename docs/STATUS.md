# Estado do projeto

> Aprovado pelo dono em 27/11/2026 (E18). Escrito por: Documentador · Revisado por: Gerente de projeto

## Onde estamos (28/11, tarde)
- **Na `previas`:** PRs #1 a #4. A branch `chore/base-fundacao` está toda na `previas`; o dono autorizou apagar, mas
  o acesso desta sessão recusou: **o dono apaga** em https://github.com/alexandrergomes1/crm-citas/branches (lixeira).
- **Respostas do relatório gravadas** (`docs/decisoes/2026-11-27-fundacao.md`) e **as 10 specs aprovadas**. Só a spec
  do Entrar já tem a linha "Aprovação do dono" (esta branch); as outras 9 recebem a linha quando a branch de cada uma
  for trabalhada (esta sessão só envia à `feat/entrar-servico`). Respostas com ajuste ou pedido junto (E29·1, E31·1,
  E31·2, E32·1, E39·2, E39·3) entram no texto de cada spec pelo Analista de requisitos nessa hora.
- **PR #7 rascunho** (`feat/entrar-servico`): spec Approved; P4 feita; matriz de permissões (ADR 0020, S7 e B7).
  Revisões: código, segurança, design, dados e **auditor de risco: liberam com ressalvas**, ressalvas resolvidas
  (último `d91ec4a`). Unidade: 398 verdes. Banco: 11 migrations e 12 arquivos pgTAP verdes (280) num Postgres 16
  local com papéis e auth simulados (não é o Supabase oficial; a prova final é a CI). T1 e T2 feitas (`e61ad94`: telas
  Entrar, Escolher estúdio, Sua conta; pt/es/en; 481 testes; build sem servidor em `dist/client`). Depois: T3, integração
  e revisões das telas feitas (até `829bb85`); o que falta está nas pendências técnicas, item 1. Não verificado: integração e e2e (precisam do Supabase local).
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
| E47·1·A, E47·2·A, E47·3·A | ajustes das telas do Entrar; termo neutro no lugar de "estúdio" (Designer decide) |
| E48·A | a IA pode enviar à `feat/entrar-servico` (PR #7) |
| E24–E41 | respostas do relatório de 28/11 e aprovação das 10 specs (detalhe e falas em `docs/decisoes/`) |

## Pendências técnicas para a próxima conversa
1. **Entrar, antes do pedido de merge** (branch `feat/entrar-servico`, até `829bb85`; E48·A): (a) inicial da bolinha,
   (b) parágrafo vazio de Escolher estúdio, (c) T3 em [`e2e/`](https://github.com/alexandrergomes1/crm-citas/tree/feat/entrar-servico/e2e)
   e (d) [`tests/integracao/registro.test.ts`](https://github.com/alexandrergomes1/crm-citas/blob/feat/entrar-servico/tests/integracao/registro.test.ts)
   **feitos**; (e) revisões feitas, ressalvas resolvidas. **Falta:** aplicar E47 (letra do nome próprio, termo neutro
   no lugar de "estúdio" a definir pelo Designer, ícone `user` no
   [`DESIGN.md`](https://github.com/alexandrergomes1/crm-citas/blob/feat/entrar-servico/DESIGN.md), tirar "crm-citas"
   da tela inicial); segunda revisão; QA; CI do PR #7; prévia para o dono conferir as telas (E23·2·A: spec própria).
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
