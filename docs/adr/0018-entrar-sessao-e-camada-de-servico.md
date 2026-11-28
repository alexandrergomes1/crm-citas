# ADR 0018 · Entrar, sessão e camada única de serviço (as 6 portas)

- **Status:** Proposto · decisões técnicas (`AGENTS.md` §5) · 28/11/2026. Vale quando a spec
  `specs/20261128-030000-entrar-servico/spec.md` for aprovada pelo dono.
- **Autor:** Arquiteto de software · **Norma:** modelo C4 e ADR; OWASP ASVS 4.0.3 (V2, V3, V4, V5, V7, V8, nível 2);
  Clean Architecture; Twelve-Factor (III, config no ambiente); RGPD art. 5(1)(c) e (e)
- **Conferência (E16·1):** pendente · Engenheiro de segurança e Auditor de risco (D2 a D10); Revisor de código (D1, D11 a
  D15); Engenheiro de dados que não escreveu (D3, D5 a D8). Decisões de banco (tabelas, funções, testes): **ADR 0019**, do
  Engenheiro de dados, escrito na construção.
- **Aviso ao dono:** em uma linha, junto do pedido de aprovação da spec (`AGENTS.md` §3 regra 3).
- **Detalhe e fontes:** `specs/20261128-030000-entrar-servico/plan.md` (§3 a §8 e §15).
- **Projeto antigo:** nada copiado (a E22·B autorizou só travas e migrations do núcleo; login não entra).

## Contexto
A spec pede entrar com e-mail e senha pelo Supabase Auth só no servidor, cookie que o navegador não lê, nenhum cliente do
banco no navegador, as 6 portas como caminho único, registro sem dado pessoal e "só gratuito" (E23·3·A). Os planos do
núcleo (Agenda §5.1, Agendamento §5.1 e ADR 0010 D1) dependem do contrato e pedem **uma transação por ação**. Três fatos
das fontes oficiais mudam o desenho:
1. tempo máximo e corte por parada do Supabase Auth são **só do plano Pro** (guia "User sessions");
2. o endereço `/auth/v1/user` (o `getUser`) está no balde de **30 pedidos por 5 min por IP**, e todo pedido sai do mesmo
   servidor; repassar o IP da pessoa (`Sb-Forwarded-For`) **exige a chave secreta** (guia "Rate limits"), proibida aqui;
3. na Data API (PostgREST) **um pedido é uma transação**, e a função de pré-pedido (`pgrst.db_pre_request`) roda dentro
   dela, antes da consulta (guia "Securing your API"; PostgREST, "Transactions").

## Decisões

| # | Decisão | Motivo e norma |
|---|---|---|
| D1 | `@supabase/supabase-js` 2.119.2, `@supabase/ssr` 0.12.7 (só `createServerClient`; `createBrowserClient` barrado pelo lint) e `zod` 4.6.7, versões exatas | MIT; mais de 3 dias publicadas (ADR 0002 · D4; `npm view` em 28/11); o `ssr` pede `supabase-js ^2.114.0`. Reuso (`AGENTS.md` §3 regra 6): é o cliente oficial |
| D2 | O servidor fala com o banco **pela Data API**, com a chave pública e o token da pessoa; **não** por ligação direta ao Postgres | o banco confere a assinatura do token: o servidor não consegue agir como outra pessoa e não guarda senha de banco (ASVS V1.4, menor privilégio; RF-12, RF-20). Alternativa descartada: ligação direta com `set local role` e declarações por transação, que daria ao servidor o poder de se passar por qualquer pessoa e pede senha do banco no Worker |
| D3 | **Uma transação por ação** = no máximo **um pedido de gravação** à Data API por ação. Ação que grava em mais de uma tabela chama **uma** função do módulo em `public`, `security invoker` (a trava RLS vale). O acesso ao banco entregue ao trabalho conta os pedidos de gravação e recusa o segundo (`erro_interno`) | PostgREST: um pedido = uma transação; falha em qualquer ponto desfaz tudo (ASVS V11.1.6, ação atômica; RF-15, RF-27). Consequência: o Agendamento (ADR 0010 D1, "nenhuma função nova") volta à 5b, como o plano dele já prevê |
| D4 | **Porta 1:** `getClaims()` (assinatura e validade; renova perto de vencer) e, no mesmo passo, a **sessão conferida no banco** a cada pedido (tabela própria por `session_id`). **Sair** apaga essa linha, chama `signOut({ scope: 'local' })` e apaga o cookie. Não se usa `getUser()` a cada pedido | o token antigo fica recusado logo depois de Sair (RF-06, CA-13), sem pôr o Auth no caminho de cada pedido: `getUser` cairia no balde de 30/5 min por IP do servidor. O guia "User sessions" indica conferir o `session_id` numa tabela. `getSession()` nunca no servidor (guia SSR). `scope: 'local'` porque o padrão `global` derruba todos os aparelhos (código do `auth-js` 2.119.2) |
| D5 | **Tempo da sessão** (E39·3, recomendação B): 12 h desde a entrada e 30 min parado, feitos **pelo banco** na tabela de D4, valores numa só função | o Auth do plano gratuito não corta (Pro); E23·3·A. Cumpre ASVS V3.3.2 nível 2. Se o dono escolher A ou C, muda só o valor (A: sem corte por parada; C: 30 dias, exceção declarada) |
| D6 | **Porta 2:** o estúdio vem de `app.estudio_da_sessao()`. O estúdio que a tela mostrava vai no cabeçalho `x-estudio-esperado`; a função de pré-pedido compara e recusa com `estudio_trocado` **na mesma transação** de cada pedido (leitura e gravação). A mesma função recusa token sem sessão viva (D4, D5) | RF-15 pede a comparação na transação da gravação; o valor só é comparado, nunca usado (ASVS V4.2.1). Como roda em todo pedido da Data API, vale também se alguém usar o próprio token fora do app (defesa em profundidade, ASVS V1.4) |
| D7 | **Porta 6:** (a) gravação de módulo → **gatilho genérico de registro** em cada tabela do estúdio, mesma transação (falhou, desfaz); nome do evento e identificador do pedido pelos cabeçalhos `x-acao` e `x-pedido`; (b) recusa nas portas 2 a 5 → o servidor grava a linha por função limitada; (c) entrar, sair, escolher e trocar → as funções de sessão gravam; (d) tentativa que falha → função própria executável por `anon`, que só aceita os campos de RF-24a e tem teto por minuto; `anon` não tem privilégio no registro | registro que não depende de o módulo lembrar (ASVS V7.1.3, V7.2.1); a gravação some se o registro falhar (RF-27); só identificadores, nunca texto livre (RF-25, ASVS V7.1.1). Nota do Engenheiro de segurança: a linha de falha precisa de função própria com limite, sem abrir o registro a `anon` |
| D8 | **Limite de tentativas** no banco, numa tabela **fora do registro**, com chave HMAC-SHA-256 (segredo do servidor) do IP e do e-mail; 10 por conta e 30 por IP em 15 min; linhas vencidas apagadas a cada chamada. **Tempo mínimo** de 700 ms em toda resposta de entrar | ASVS V2.2.1 (abaixo de 100 falhas por hora por conta); minimização e prazo curto (RGPD art. 5(1)(c) e (e)): o banco nunca vê IP nem e-mail, e o HMAC impede achar o IP por tentativa e erro. O limite do Auth vale para o servidor inteiro (fato 2), por isso o limite por pessoa é nosso. Tempo mínimo: conta inexistente responde mais rápido no Auth (RF-02, enumeração) |
| D9 | Cookie da sessão: `HttpOnly`, `Secure`, `SameSite=Lax`, `Path=/`, nome com prefixo `__Host-` (opção `cookieOptions` do `ssr`); variáveis `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` e `SEGREDO_TENTATIVAS` **sem** prefixo `VITE_`, lidas a cada pedido | o `ssr` 0.12.7 vem com `httpOnly: false` (código instalado): sem a opção, o JavaScript leria o token (ASVS V3.4.1 a V3.4.3). O guia do Supabase para TanStack Start usa `VITE_`, que mandaria o endereço e a chave ao navegador (RF-04): não seguido. Ler por pedido: guia de variáveis do TanStack Start (Workers) |
| D10 | CSRF: `createCsrfMiddleware` do TanStack Start em `src/app/start.ts`, mais `SameSite=Lax` e gravação só por `POST`; `Cache-Control: no-store` em toda resposta por um middleware global | ASVS V4.2.2 (RF-10), V8.2.1 (RF-06). O arquivo `start.ts` mora em `srcDirectory` (código instalado do `start-plugin-core`); com ele, o CSRF precisa ser posto à mão (doc oficial) |
| D11 | Erros saem como **valor** (`{ ok: false, codigo }`), nunca como exceção ao navegador; lista fechada de códigos de RF-22; o mapa de erro do banco para código fica em `src/data` | ASVS V7.4.1: nada de mensagem do banco, pilha ou identificador na resposta (RF-22, CA-12) |
| D12 | **Molde único:** só `src/server/portas/acao.ts` importa `createServerFn` (lint); toda ação entra num catálogo único; os modos sem estúdio (`nenhuma`, `opcional`, `pessoa`) só para os nomes de uma lista fechada | RF-16, RF-21, CA-21; o catálogo permite o teste "sem sessão, nada passa" percorrer todas (CA-04) |
| D13 | **Porta 4** com `z.strictObject` (campo a mais → `entrada_invalida`), feita pelo molde **depois** das portas 1 a 3, e não pelo `.validator` do TanStack Start | RF-17 e RF-19: a ordem fica no nosso código, testada sem o framework (CA-07). Consequência: o plano da Agenda (§5.3, "chave desconhecida é descartada") se ajusta |
| D14 | Banco local com Auth e Data API: `db:start` passa a subir `gotrue`, `kong` e `postgrest`; cadastro aberto desligado no `supabase/config.jsonc`; contas fictícias de teste pela API admin local **só** em `tests/` e `e2e/`, com a chave local lida do `supabase status` na hora (nunca em `src/` nem no repositório) | CA-01, CA-04, CA-16 precisam do Auth; RF-09; `SECURITY.md` §2. A chave local é do Docker da máquina, não de projeto remoto |
| D15 | Idiomas: base de `src/app/i18n/` no formato do ADR 0006 · D1, com os blocos `comum`, `erros`, `entrar`, `escolherEstudio` e `suaConta`; antes de entrar, idioma pelo `Accept-Language` (regra pura em `src/domain/idioma.ts`); depois, `estudios.idioma` | RF-34, RF-35, Assumption 1 da spec; reuso do `Intl` |

## Consequências
- Todo módulo declara ações só por `acao(...)`, liga o gatilho de registro em cada tabela nova (molde do ADR 0019) e grava
  com um pedido só por ação; ação que toca mais de uma tabela tem função `public` `security invoker` (Agendamento e
  Checkout se ajustam).
- Toda tabela de `public` com `org_id` fica alcançável pela Data API para quem tem token; a trava RLS, o pré-pedido (D6) e
  o gatilho de registro (D7) valem também nesse caminho. O token nunca chega ao JavaScript da página (D9).
- O limite do Auth por IP (fato 2) vale para todos os estúdios juntos no projeto remoto: ver o plano §14 (risco R-3).
- Para desfazer qualquer linha: ADR novo que a substitui, com o motivo.
