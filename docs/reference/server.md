# Servidor: fatos deste projeto

O que nenhuma skill de mercado pode saber. O **método** (autorização, validação, erro, idempotência,
consulta) vem das skills de mercado listadas na skill `server-functions`; este documento
guarda só os fatos, e vence quando houver conflito. Pastas: `docs/reference/project.md`.

## Peças da casa
| Para | Use | Onde |
|---|---|---|
| Exigir login | `requireAuth()` | `src/data/auth/session.ts` |
| Acesso ao estúdio pelo endereço | `requireOrgAccess(orgSlug)` | `src/data/auth/session.ts` |
| Acesso ao estúdio pelo id que veio do formulário (quem decide é o banco) | `requireOrgIdAccess(orgId)` → `{ user, org, role }` | `src/data/auth/session.ts` |
| Permissão numa página | `requirePermission(orgSlug, permissao)`, `requireModule(orgSlug, modulo)` | `src/data/auth/access.ts` |
| Permissão numa ação que já tem estúdio e papel | `orgCan(orgId, role, permissao)` | `src/data/auth/access.ts` |
| Transformar erro do banco em mensagem para a pessoa | `actionErrorMessage(err)` | `src/lib/action-error.ts` |
| Limite de tentativas nos links públicos | contagem no banco (tabela `public_link_hits`); `src/server/ip-bucket.ts` só agrupa o endereço de rede | — |
| Cabeçalhos das páginas sensíveis | `SENSITIVE_HEADERS` | `src/server/public-headers.ts` |
| Cabeçalhos de toda resposta | `src/server/request-middleware.ts` | — |

O acesso (usuário, estúdio, papel) é memorizado por pedido: conferi-lo de novo dentro da mesma
requisição não custa outra ida ao banco.

## Regras da casa
- Regra de negócio em `src/domain` (TypeScript puro). Banco só em `src/data`.
- Escrita em vários passos (pagamento + caixa + saldo) é uma função do banco (RPC), numa transação.
- Auditoria de ação sensível é gravada pelo banco, não por `insert` livre da aplicação.
- Resposta de ação: `{ ok: true, … }` ou `{ ok: false, error }`, com a mensagem em português para a pessoa. Nunca o texto cru do banco.
- `service_role` só onde a RLS do usuário não alcança (fotos da ficha, páginas públicas, esqueci a senha, criar acesso de pessoa da equipe).
- Idas ao banco: `docs/reference/db-budget.md`; função nova entra no teste do orçamento.
- Teste mínimo: unidade da regra em `src/domain` e E2E provando que outro estúdio recebe erro.

## Páginas sem login e cabeçalhos sensíveis
Levam `Cache-Control: private, no-store`, `X-Robots-Tag: noindex, nofollow` e
`Referrer-Policy: same-origin` (lista em `src/lib/public-paths.ts` e `src/server/public-headers.ts`):
- com **token no endereço**: `/forms/<token>` (ficha da cliente), `/pagar/<token>` (cobrança) e `/reset-password`;
- o modo estúdio, `/<estúdio>/anamnese-tablet`;
- `/login`, `/logout`, `/booking`, `/api/webhooks` e as chamadas de função de servidor (`/_serverFn/`).

`/trocar-senha` **não** está nessa lista: depende de sessão e não leva token.
O link da ficha é guardado só como hash, com validade; "Reenviar link" gera um novo e o anterior deixa de valer.

## Como está hoje (não descreva como se já existisse)
- Cabeçalhos em toda resposta: HSTS, `nosniff`, `Referrer-Policy`. A política de conteúdo (CSP) tem **só** `frame-ancestors 'none'`; a CSP completa ainda não existe.
- Turnstile **não está no código** (está previsto na stack, para a virada). O limite de tentativas é a contagem no banco.
- Idempotência em `/pagar` e nos webhooks **não existe**: item da fila, precisa de spec.

## Onde este projeto contraria o mercado (e a prova)
| O mercado manda | Aqui | Prova |
|---|---|---|
| Token nunca no endereço | Token no endereço **só** nas páginas públicas, com os três cabeçalhos acima | o link é mandado à cliente por mensagem; `src/server/public-headers.ts` |
| Teste de integração contra banco real para toda rota nova | Unidade em `src/domain` + E2E de outro estúdio | a CI roda Vitest e Playwright; o teste automático das funções de servidor está na fila |
| Rodar o comando de verificação na máquina antes de afirmar | A prova é o resultado da CI do PR | `docs/projeto/tecnico.md` §CI |
