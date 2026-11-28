# Estado do projeto

> Aprovado pelo dono em 27/11/2026 (E18). Escrito por: Documentador · Revisado por: Gerente de projeto

## Onde estamos (28/11, manhã)
- **Na `previas`:** PRs #1 (base), #2 (item 1), #3 (ordem E21·1) e #4 (item 2, fundação técnica). A branch
  `chore/base-fundacao` o dono apaga no PR #1 (botão "Delete branch"; E19·1).
- **PR #5 rascunho** (`feat/banco-ligacao`, item 3): construído e testado no banco local.
- **PR #6 rascunho** (`feat/design-system-codigo`, item 4): construído, com ficha e capturas.
- **PR #7 rascunho** (`feat/entrar-servico`, item 4a Entrar, E36·A): banco (commit `4f13862`) e servidor S1–S6
  (commit `5f085a3`); typecheck e lint limpos, 344 testes de unidade, 13 de integração verdes e 2 pendentes.
  Falta: T1–T3 (telas, esperam E41), i18n em `src/app/i18n` e `src/app/navegacao.ts`,
  `tests/integracao/registro.test.ts`, revisões (código, dados, segurança, auditor de risco, design), QA e CI.
- **Só com spec, plano e tarefas revisados** (sem código, esperam aprovação): `feat/agenda`, `feat/agendamento`,
  `feat/clientes`, `feat/formularios`, `feat/catalogo`, `feat/checkout`, `feat/caixa`
  (`specs/20261128-020000-agenda` até `specs/20261128-023000-caixa`).
- **Respostas do dono:** `docs/decisoes/2026-11-27-fundacao.md`.

## Esperando o dono
1. **Relatório** com as 34 perguntas (E24·1–3, E25·1–3, E26·1–3, E27·1–2, E28·1–3, E29·1–3, E40, E30·1–3,
   E31·1–3, E32·1–3, E39·1–3, E41·1–4) e a aprovação das 10 specs:
   https://claude.ai/artifact/FoTgdyW2jT3bVD9WQS3PQb. Cada pergunta já vem marcada na recomendação. O texto completo
   de cada uma está na spec da pasta respectiva (seção de dúvidas); E40 em `specs/20261128-021500-formularios/plan.md`
   §0; E41 em `specs/20261128-030000-entrar-servico/ficha-visual.md`.
2. **E38·A:** instalar as travas em `.claude/` com o dono presente (a gravação pede permissão na tela;
   `specs/20261128-005000-fundacao-tecnica/travas-claude-propostas/`, ADR 0003).
3. D2 (PRs do Dependabot e a `main`): pedido separado, com os cliques exatos.

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

## Pendências técnicas para a próxima conversa
Para Engenheiro de software, Arquiteto e Engenheiro de segurança; nenhuma é decisão do dono.
1. **Arquiteto:** revisar a divergência do contrato §4 do plano do Entrar: cada ação é
   `export const x = acaoPost.handler(acao({...}))`, porque o TanStack Start só aceita `.handler` no nível do
   módulo; a entrada fica `unknown` na chamada.
2. `src/app/start.ts` foi escrito antes da T2 (liga CSRF por origem e `no-store`): registrar no plano.
3. Removido `x-estudio-esperado` da chamada a `registrar_recusa` (senão a recusa por estúdio trocado nunca era
   registrada).
4. **Segurança:** a ação GET leva dados em `?payload=` (risco de `estudioDaTela` na URL, RF-33); senha de 200
   caracteres não cria conta no Auth local (suspeita do limite de 72 bytes do bcrypt, não confirmado); o CA-18a
   prova com 64.
5. **DevOps:** a variável `SUPABASE_CHAVE_ADMIN_LOCAL` (nome provisório) é usada no preparo da integração;
   combinar o nome e pôr na CI.
6. **Não verificado:** CA-09, CA-09a, CA-15, contagem do registro no CA-04, Workers, e2e, `pnpm dev` com recarga.
7. As revisões de código e de segurança do commit `5f085a3` começaram e foram interrompidas pela troca de
   conversa: refazer.
8. Avisos ao dono já dados: R-13 (`/auth/v1` fora da trava, só o limite por IP do Auth) e R-3 (limite do Auth
   compartilhado; passo a passo no pedido de merge do Entrar). Chave de servidor e chave de assinatura no banco
   online só com autorização de publicação.

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
