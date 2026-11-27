# Pasta: src/server · peças do servidor

Vale junto com o `AGENTS.md` da raiz.

**O que mora aqui:** o que roda em toda requisição no Cloudflare Worker: cabeçalhos (`request-middleware.ts`, `public-headers.ts`), limite de corpo (`body-gate.ts`), agrupamento de endereço de rede (`ip-bucket.ts`), redirecionamentos antigos, erros e formulários. As funções de servidor dos módulos ficam nos arquivos `*.server.ts` de cada pasta.

**Regras**
- Ordem fixa de toda função de servidor: validar com Zod estrito → sessão e estúdio → permissão → executar por `src/data` → auditoria pelo banco quando sensível → resposta `{ ok, … }` (`docs/guias/servidor.md`).
- Regra de negócio em `src/domain`; banco só por `src/data` (`AGENTS.md` §5).
- Páginas sem login e com token no endereço levam `no-store`, `noindex` e `Referrer-Policy: same-origin` (`docs/guias/servidor.md`).
- Resposta de erro em português para a pessoa, nunca o texto cru do banco (`docs/guias/servidor.md`).
- Teste mínimo: unidade da regra e E2E provando que outro estúdio recebe erro (`docs/guias/testes.md`).

**Nunca**
- Descrever proteção que não existe (CSP completa, Turnstile, idempotência em `/pagar`).
- Dado pessoal, de saúde, token ou senha em log.
- Pagamento, webhook ou `service_role` sem parar e perguntar.

## Origem
`.claude/rules/servidor.md` · `.claude/skills/server-functions/SKILL.md` · `docs/reference/server.md` · estrutura real (`ls src/server`, 27/11/2026).
