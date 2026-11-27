# Guia · Servidor

Vale para todo código que roda no servidor e lê ou grava dados: server function, rota de API, webhook.
Fatos do servidor (peças da casa, cabeçalhos, o que ainda não existe): `docs/reference/server.md`. Em conflito com qualquer prática geral, vence esse arquivo.

## Antes de começar
- Spec aprovada da tarefa e só os "Arquivos permitidos" do plano (`processo-sdd.md`).
- Método geral (pensar antes, segurança, autenticar não é autorizar, erro como parte do contrato; idempotência em dinheiro, webhook ou efeito externo; disciplina de consulta em lista ou junção) vem da prática de mercado. No Claude Code: skills `backend-design:think-before-coding`, `security-discipline`, `auth-and-authorization`, `error-handling-as-design` e, quando cabem, `idempotency-and-side-effects` e `query-discipline`.

## Camadas
- Regra de negócio em `src/domain` (TypeScript puro, com teste).
- Banco só em `src/data`.
- Escrita em vários passos (ex.: pagamento + caixa + saldo) é uma função do banco, numa transação (`banco.md`).

## Ordem fixa da casa
1. **Validar** a entrada com Zod estrito (`.strict()`). O `org_id` que vem da tela nunca é verdade.
2. **Sessão e acesso ao estúdio:** `requireOrgIdAccess(orgId)` devolve `{ user, org, role }`.
3. **Permissão:** `orgCan(org.id, role, '<modulo>.<acao>')`.
4. **Executar** por `src/data`; regra em `src/domain`; escrita em vários passos numa função do banco.
5. **Auditoria**, quando a ação é sensível (ficha, dinheiro, permissões, exclusão, exportação), gravada pelo banco, nunca por `insert` livre da aplicação.
6. **Resposta** `{ ok: true, … }` ou `{ ok: false, error }`, com a mensagem em português feita por `actionErrorMessage`. Nunca o texto cru do banco.
7. **Orçamento:** registrar a função no teste do orçamento (`src/data/supabase-calls.test.ts`) com o número de idas esperado.

O acesso (usuário, estúdio, papel) é memorizado por pedido: conferir de novo na mesma requisição não custa outra ida.

## Orçamento de idas ao banco
Lugar único desta regra; os outros guias e pastas apontam para cá. Números completos e exceções: `docs/reference/db-budget.md` (vence este resumo).
- Abrir tela logada: 2 idas (contexto de acesso + 1 função de leitura). Página pública: 1. Ação: 2 (contexto + 1 gravação). Arquivo guardado: +1, dito no PR.
- Tela com dados de várias tabelas: uma função SQL `SECURITY INVOKER` com `search_path = ''`, nunca várias consultas soltas. Ação em várias tabelas: uma função no banco (tudo ou nada).
- Proibido: consulta dentro de laço; a mesma tabela lida duas vezes no mesmo pedido; buscar tudo para filtrar no código; `select *` em lista.
- Lista grande: paginação no banco e índice que cubra filtro e ordem.
- **Como se mede:** toda função de servidor nova entra em `src/data/supabase-calls.test.ts` com o número esperado; a CI trava regressão das funções listadas. Função fora da lista não é pega: o revisor de código confere.
- Exceção só com justificativa escrita no PR. Quando a função substitui outra, o PR traz a tabela antes x depois.

## Páginas sem login
Levam `Cache-Control: private, no-store`, `X-Robots-Tag: noindex, nofollow` e `Referrer-Policy: same-origin`. Lista das páginas e onde os cabeçalhos são postos: `docs/reference/server.md`. Token no endereço só nessas páginas, forte e com validade, e com limite de tentativas.

## Proibido
- `service_role` para algo que a RLS do usuário alcança. Ele só serve onde a RLS não chega (fotos da ficha, páginas públicas, esqueci a senha, criar acesso de pessoa da equipe).
- Nome, telefone, resposta de ficha, token ou senha em log. No log vai id. Dado de saúde e dado pessoal: `AGENTS.md` §5.
- Descrever proteção que não existe (ver "Como está hoje" em `docs/reference/server.md`: CSP completa, Turnstile e idempotência em `/pagar` e webhooks ainda não existem).

## Pare e pergunte
- Função nova que mexe em pagamento ou recebe webhook (a spec de idempotência ainda não existe).
- A função precisa de `service_role`.
- A ação é sensível e não há como auditar pelo banco.
- A spec não diz quem pode executar.

## Teste mínimo
Unidade da regra em `src/domain` e E2E provando que outro estúdio recebe erro (`testes.md`).

## Revisão e prova
Tipo "Funcionalidade" (ou "Integração"), nível C. Revisores: `revisao.md`. Prova: `testes.md`.

## Origem
`.claude/skills/server-functions/SKILL.md` · `.claude/rules/servidor.md` · `docs/reference/server.md` · `docs/reference/db-budget.md` · `.claude/agents/code-reviewer.md` · `AGENTS.md` §5.
