# Estado do projeto

> Aprovado pelo dono em 27/11/2026 (E18). Escrito por: Documentador · Revisado por: Gerente de projeto

## Onde estamos (28/11, tarde)
- **Na `previas`:** PRs #1 a #4. A branch `chore/base-fundacao` está toda na `previas`; o dono autorizou apagar, mas
  o acesso desta sessão recusou: **o dono apaga** em https://github.com/alexandrergomes1/crm-citas/branches (lixeira).
- **Respostas do relatório gravadas** (`docs/decisoes/2026-11-27-fundacao.md`) e **as 10 specs aprovadas**. Só a spec
  do Entrar já tem a linha "Aprovação do dono" (esta branch); as outras 9 recebem a linha quando a branch de cada uma
  for trabalhada (esta sessão só envia à `feat/entrar-servico`). Respostas com ajuste ou pedido junto (E29·1, E31·1,
  E31·2, E32·1, E39·2, E39·3) entram no texto de cada spec pelo Analista de requisitos nessa hora.
- **PR #7 rascunho** (`feat/entrar-servico`): spec Approved; P4 feita (nomes, ícones e "tela sem menu" no `DESIGN.md`);
  revisões de código, segurança e design: aprovam com ressalvas, ressalvas resolvidas (commits `f5bed79`, `99d0877`);
  typecheck e lint limpos, 353 testes de unidade. Falta: T1–T3 (telas), i18n, `tests/integracao/registro.test.ts`,
  auditor de risco, revisão de dados, QA e CI. Não verificado aqui (sem Docker): `pnpm db:test`, integração, e2e.
- **Avaliação do antigo** (só leitura, nada copiado; E43·A autorizou as ideias): `docs/produto/avaliacao-crm-agenda/`
  `regras-do-banco.md` (74 regras, 2 leituras), `seguranca-do-banco.md` (25) e `permissoes-e-pin.md`. Banco do antigo
  **esgotado** para o núcleo. As ideias entram em cada spec quando a branch dela for trabalhada.
- **Matriz de permissões (ADR 0020, E42·A):** porta 3 por chave `modulo.acao`; S7 (`bfbb9b9`) e B7 (`8fd1a24`);
  385 testes de unidade; `pnpm db:test` não rodou (sem Docker). Personalização: item 6a da fila.
- **Specs revisadas, sem código** (aprovadas): agenda, agendamento, clientes, formulários, catálogo, checkout, caixa.

## Esperando o dono
1. **E44:** outras partes do antigo que valeria ler (código de regras, testes de tela); o dono discute e libera.
2. **E45:** estúdio sem o módulo Caixa: o pagamento em dinheiro é aceito sem caixa? (a regra do Checkout exige caixa).
3. **E46:** guardar o histórico de mudança de preço (antigo, novo, quem mudou)?
4. **E38·A:** travas em `.claude/` com o dono presente. **D2:** PRs do Dependabot e a `main`.
5. Apagar `chore/base-fundacao` (o dono, na página de branches).

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
| E24–E41 | respostas do relatório de 28/11 e aprovação das 10 specs (detalhe e falas em `docs/decisoes/`) |

## Pendências técnicas para a próxima conversa
1. Entrar: T1–T3 (telas) com as notas da ficha (autocomplete, olho sem `aria-pressed`, nenhuma consulta automática
   renova a sessão); provar na T2 que `acaoPost.handler` importado separa servidor e navegador (`pnpm build`).
2. Entrar: auditor de risco, revisão de dados (Engenheiro de dados que não fez), QA; CI no PR #7.
3. Achado do Engenheiro de dados: pessoa em dois estúdios pode ser marcada no mesmo horário nos dois (Analista).
4. DevOps: nome da variável `SUPABASE_CHAVE_ADMIN_LOCAL` na CI. `prettier --check` acusa 17 arquivos (não é check
   exigido; conferir).
5. Avisos já dados: R-13, R-3. Chave de servidor e de assinatura no banco online só com autorização de publicação.

## Falta na base
- E-mail de segurança quando houver domínio (E14·1); travas do Claude Code em `.claude/` (E38·A).

## Como continuar numa conversa nova

**Onde estão as coisas**
- Repositório `alexandrergomes1/crm-citas`; trabalho em curso na branch `feat/entrar-servico` (PR #7).
- Respostas do dono: `docs/decisoes/2026-11-27-fundacao.md`.
- Projeto antigo (`crm-agenda`): **só se lê com autorização do dono, item por item** (`AGENTS.md` §3 regra 4).

**Prompt pronto para o dono colar**

```
Leia AGENTS.md do repositório alexandrergomes1/crm-citas (branch feat/entrar-servico). Estado: docs/STATUS.md. Decisões: docs/decisoes/2026-11-27-fundacao.md. Use os papéis de .claude/agents e as skills de .claude/skills em tudo, declarando papel e norma. Minhas respostas do relatório: <cole aqui a resposta copiada da página>. Grave as respostas e aprovações, depois siga as pendências do STATUS (revisões do Entrar, telas, módulos). Nada se copia do projeto antigo sem a minha autorização item por item.
```
