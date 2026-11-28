# Plano · Caixa (núcleo): abrir, movimentar e fechar o dinheiro do balcão

- **Spec:** `specs/20261128-023000-caixa/spec.md` (Draft; Auditor de risco e revisão 5b feitos; E32·1 a E32·3 e, do
  Checkout, E31·1 e E31·3 em aberto)
- **Escrito por:** Arquiteto de software · **Norma:** modelo C4 e ADR (mais Clean Architecture, Twelve-Factor, WCAG 2.2,
  OWASP ASVS 4.0.3 V4, V5, V7 e V11.1, ISO 4217, boas práticas do Postgres e do Supabase) · **Revisão:** pendente
  (etapa 5 Analista de requisitos; 5b Gerente de projeto)
- **Decisões técnicas:** `docs/adr/0017-dinheiro-checkout-e-caixa-ordem-trava-e-autor.md` (deste plano e do Checkout,
  mora nesta branch). **Decisões por tabela do antigo:** `docs/adr/0016-caixa-tabelas-do-antigo.md`, escrito pelo
  Engenheiro de dados na T3 (não aqui).
- **Portão:** a construção em PR de rascunho pode começar antes da aprovação (E22·B); o pedido de merge só com a spec
  "Status: Approved" e as respostas E32, E31·1, E31·3 e **E24·3** (moeda do estúdio, item 3) gravadas. Até a resposta
  da E24·3 vale a **recusa provisória** (falha fechada, L-2), e o pedido de merge a mostra ao dono.
- **Dependência fixada pelo dono (E36·A):** login, sessão, as 6 portas, a transação por ação e o registro (porta 6) vêm
  da spec "Entrar e camada de serviço" (`feat/entrar-servico`, spec lida). O Caixa **usa**, não constrói.
- **Bases lidas em 28/11/2026 (só leitura, nada editado lá):** item 3 (`/home/user/wt-banco`: ADR 0005, migrations
  `estudios` a `politicas_base`, conferido `estudios.moeda text not null check (moeda ~ '^[A-Z]{3}$')` e
  `grant update (... moeda ...)` para a dona, o molde `supabase/moldes/isolamento_tabela_test.sql`, `package.json` com
  `db:test` = `supabase test db`); item 4 (`/home/user/wt-ds`: `src/app/ui/*`); spec E36·A
  (`/home/user/wt-entrar/specs/20261128-030000-entrar-servico/spec.md`: RF-16 contrato, RF-22 códigos, RF-24 campos do
  registro, RF-29 E6·1 fora, RF-34 base de idiomas); Catálogo (`/home/user/wt-catalogo`: `plan.md`, ADR 0012);
  Agendamento (`/home/user/wt-agendamento`: `plan.md`, ADR 0010); spec do Checkout (`/home/user/wt-checkout`).
  Antigo: **não relido** pelo Arquiteto; as sugestões do §4.1 partem do §7 da spec.

## 1. Resumo (C4)
**Contexto:** dona e recepção usam a tela Caixa; o Checkout grava pagamentos que entram no caixa aberto (E31·1).
Nenhum sistema externo novo.
**Contêiner:** o app (TanStack Start) e o banco (Postgres do Supabase), com a camada de serviço da E36·A.
**Componentes:**

```
/caixa (Caixa atual) · /caixa/historico?pagina=N · /caixa/historico?caixa=<uuid>   (só ids e página na URL: RNF-04)
   │ loader / ação da tela
   ▼
src/server/caixa/{ler,abrir,movimentar,fechar}.ts ── 6 portas da E36·A, uma transação por ação
   ├─► src/domain/caixa/*  (valores, esperado, diferença, acesso, registro, resumo)  ─► reusa src/domain/catalogo/preco.ts
   ▼  com a sessão da pessoa
src/data/caixa/* ──► public.caixas · public.caixa_movimentos  (RLS; gatilhos; contador vivo e versão, ADR 0017 · D2)
                     encaixes do Checkout: entradas-por-forma.ts, atendimentos-sem-checkout.ts (ADR 0017 · D9)

Checkout (migration dele, feat/checkout) ──► trava e soma na linha de public.caixas (ADR 0017 · D1, D2)
```

## 2. Lacunas para o Analista de requisitos (a spec não cobre; não decido, `AGENTS.md` §4)
- **L-1 · E32·1, E32·2, E32·3 sem resposta** (e E31·1, E31·3 do Checkout). O plano usa as recomendações (A, A, A; E31·1·A;
  E31·3·A) e mostra no §11 o que muda. Construção em rascunho pode andar; o merge, não.
- **L-2 · Moeda do estúdio muda com caixa aberto (E24·3 em aberto no item 3; dinheiro).** O item 3 deixa a dona alterar
  `estudios.moeda`. O caixa guarda a moeda da abertura (RF-13). A E24·3 é **portão do pedido de merge**. Até a
  resposta vale a **recusa provisória** (falha fechada): o banco recusa pagamento, sangria e suprimento em moeda
  diferente da do caixa; o pedido de merge mostra isso ao dono, que decide pela E24·3 (o mesmo ponto da L-3 do Catálogo).
- **L-3 · Recepção depois de fechar (E32·3·A).** Pela recomendação, a recepção vê só o caixa aberto e o histórico só a
  dona. Ao confirmar o fechamento, a recepção vê o resultado (esperado, contado, diferença) uma vez, na resposta da
  ação, e depois não vê mais. **Recomendo** deixar assim (é o que a E32·3·A diz); confirmar no texto da E32·3.
- **L-4 · (fechada pela 5b):** o teto técnico de **9 007 199 254 740 991 centavos** é decisão técnica (ASVS V11.1.4),
  no ADR 0017 · D5; só ajuste de texto no RN-03 e no CA-01.
- **L-5 (só texto):** o cabeçalho diz "Branch: `feat/caixa` (a partir da `previas`)"; a branch é empilhada (§9).

## 3. Dúvidas em aberto: o plano usa a recomendação
Cada resposta vira **uma constante** em `src/domain/caixa/acesso.ts` e `src/domain/caixa/regras.ts` e **uma** versão
das políticas e restrições; nada de chave de liga e desliga (como ADR 0006 · D6 e ADR 0012 · D6).

## 4. Banco (tipo Banco; quem decide a forma é o Engenheiro de dados, ADR 0016)

### 4.1 Decisão por tabela do antigo · **sugestão ao Engenheiro de dados, que decide na T3** (ADR 0016, conferido por outra instância, E16·1)
Por cima das sugestões da spec §7. Nada se copia: "reescrever" é mesma intenção, código novo.

| Antigo | Sugestão | Motivo |
|---|---|---|
| `cash_sessions` | **reescrever** como `public.caixas` (§4.3) | concordo com a spec: centavos `bigint` (ADR 0017 · D5), sem `responsible_name` (autor pelo id, ADR 0017 · D7), esperado/contado/diferença em colunas inteiras (só dinheiro, E32·2·A), sem reabrir nem `left_in_drawer`; ficam as ideias do índice único parcial, da coerência Aberto/Fechado e do `unique (org_id, id)`; entra o contador vivo e a versão (ADR 0017 · D2) |
| `cash_movements` | **reescrever** como `public.caixa_movimentos` | concordo: só sangria e suprimento, motivo obrigatório (3 a 200), chave composta `(org_id, caixa_id)`, sem alteração nem exclusão |
| `transactions.cash_session_id` e o gatilho que carimba o caixa | **descartar** | concordo: a ligação é da migration do Checkout (RF-03; ADR 0017 · D1) |
| `transactions` | **adiada** (Financeiro) | concordo |
| funções do antigo de abrir, movimentar e fechar | **descartar** | a gravação passa pela camada de serviço e por gatilhos (ADR 0017 · D6); o Engenheiro de dados confere no corpo se recebem estúdio do pedido (o item 3 RF-03 proíbe) |

### 4.2 Migrations (com `pnpm exec supabase migration new <nome>`; carimbo depois das bases empilhadas e **antes** de toda migration do Checkout, ADR 0017 · D1)
| # | Nome | Conteúdo (sugestão; forma final do Engenheiro de dados) |
|---|---|---|
| M1 | `caixa_autor_da_sessao` | `app.autor_da_sessao()` (ADR 0017 · D7): `security definer`, `set search_path = ''`, `stable`, devolve `auth.uid()`; `revoke all ... from public, anon, authenticated` |
| M2 | `caixas` | tabela §4.3, índices, `enable` e `force row level security`, `revoke all` de `anon` e `authenticated` |
| M3 | `caixa_movimentos` | idem |
| M4 | `caixa_regras` | funções de gatilho e gatilhos do §4.4 |
| M5 | `caixa_politicas` | políticas e privilégios por coluna do §4.5 |

### 4.3 Tabelas (sugestão)
`S` = `org_id = (select app.estudio_da_sessao())` · `P` = `(select app.papel_da_sessao())`. Teto `T` = 9 007 199 254 740 991.

**`public.caixas`**
| Coluna | Tipo e regra |
|---|---|
| `id` | `uuid primary key default gen_random_uuid()`; `unique (org_id, id)` (alvo de `caixa_movimentos` e do pagamento do Checkout) |
| `org_id` | `uuid not null default (app.estudio_da_sessao()) references public.estudios (org_id) on delete cascade`; sem privilégio de gravação |
| `moeda` | `text not null`, posta pelo gatilho a partir de `estudios.moeda` (RF-13) |
| `status` | `text not null default 'aberto' check (status in ('aberto','fechado'))` |
| `valor_inicial_centavos` | `bigint not null check (valor_inicial_centavos between 0 and T)` (E32·1·A: zero permitido) |
| `observacao` | `text null check (observacao is null or char_length(observacao) between 1 and 300)` (nunca vai ao registro) |
| `dinheiro_esperado_centavos` | `bigint not null check (dinheiro_esperado_centavos between 0 and T)`; começa = inicial; só gatilhos mudam (ADR 0017 · D2) |
| `versao` | `bigint not null default 0`; só gatilhos mudam |
| `aberto_por`, `aberto_em` | `uuid null`, `timestamptz not null default now()`; autor pelo gatilho (`app.autor_da_sessao()`, ADR 0017 · D7) |
| `chave_abertura`, `resumo_abertura` | `uuid not null`, `text not null check (resumo_abertura ~ '^[0-9a-f]{64}$')`; `unique (org_id, chave_abertura)` (RNF-02) |
| `contado_centavos` | `bigint null check (contado_centavos between 0 and T)` |
| `esperado_fechamento_centavos` | `bigint null` (cópia do esperado no fechamento) |
| `diferenca_centavos` | `bigint generated always as (contado_centavos - esperado_fechamento_centavos) stored` (RN-06) |
| `motivo_diferenca` | `text null check (motivo_diferenca is null or char_length(btrim(motivo_diferenca)) between 5 and 300)` |
| `fechado_por`, `fechado_em` | `uuid null`, `timestamptz null`; pelo gatilho |
| `chave_fechamento`, `resumo_fechamento` | `uuid null`, `text null`; `unique (org_id, chave_fechamento)` |

- **Coerência (`check`):** `status = 'aberto'` ⇒ contado, esperado do fechamento, fechado_em, chave e resumo do
  fechamento nulos; `status = 'fechado'` ⇒ todos preenchidos (salvo `fechado_por`, anulável pela E6·1) e
  `(diferenca_centavos = 0) or motivo_diferenca is not null`.
- **Um aberto por estúdio (RF-02, ADR 0017 · D4):** `create unique index caixas_um_aberto on public.caixas (org_id) where status = 'aberto'`.
- **Índices:** `(org_id, aberto_em desc, id)` (histórico, RF-11).

**`public.caixa_movimentos`**
| Coluna | Tipo e regra |
|---|---|
| `id` | `uuid primary key default gen_random_uuid()` |
| `org_id` | como em `caixas` |
| `caixa_id` | `uuid not null`; **não** vem do pedido: o gatilho põe o caixa aberto do estúdio (RN-07); `foreign key (org_id, caixa_id) references public.caixas (org_id, id) on delete restrict` |
| `tipo` | `text not null check (tipo in ('sangria','suprimento'))` |
| `valor_centavos` | `bigint not null check (valor_centavos between 1 and T)` |
| `motivo` | `text not null check (char_length(btrim(motivo)) between 3 and 200)` |
| `feito_por`, `feito_em` | `uuid null` (gatilho, D7), `timestamptz not null default now()` |
| `chave`, `resumo` | como em `caixas`; `unique (org_id, chave)` |

- **Índices:** `(org_id, caixa_id, feito_em)`.

### 4.4 Regras no banco (M4; todas `security definer`, `set search_path = ''`, nomes qualificados, sem `execute` para `authenticated`)
| Gatilho | Regra | Requisito |
|---|---|---|
| `before insert` em `caixas` | `status` = aberto; `moeda` ← `estudios.moeda` do estúdio; `dinheiro_esperado_centavos` ← `valor_inicial_centavos`; `versao` ← 0; `aberto_por` ← `app.autor_da_sessao()`; `aberto_em` ← `now()`; ignora o que vier nesses campos | RF-01, RF-13, ADR 0017 · D6, D7 |
| `before update` em `caixas` | linha `fechado` não muda (nem a dona, RF-09); de `aberto` só duas mudanças: (a) contador e versão, colunas sem privilégio para `authenticated` (só os gatilhos `security definer` as mudam) e com o resto igual; (b) **fechar**: só `status → fechado` com `contado_centavos`, `motivo_diferenca`, `chave_fechamento`, `resumo_fechamento`; o gatilho põe `esperado_fechamento_centavos ← dinheiro_esperado_centavos`, `fechado_por ← app.autor_da_sessao()`, `fechado_em ← now()` | RF-06, RF-09, RN-06 |
| `before delete` em `caixas` e `caixa_movimentos` | sempre recusa | RF-09 |
| `before insert` em `caixa_movimentos` | trava e atualiza o caixa aberto do estúdio numa só instrução (`update public.caixas set dinheiro_esperado_centavos = ... ± valor, versao = versao + 1 where org_id = new.org_id and status = 'aberto' returning id, moeda`); sem caixa aberto → recusa; moeda do estúdio ≠ moeda do caixa → recusa (L-2); sangria que deixaria negativo → o `check` recusa (RN-05); `new.caixa_id` ← o id devolvido; autor e data pelo gatilho | RF-05, RN-04, RN-05, RN-07, ADR 0017 · D2 |
| `before update` em `caixa_movimentos` | sempre recusa | RF-09 |

- **Fechar (servidor, §5.3):** `update public.caixas set status = 'fechado', contado_centavos = $c, motivo_diferenca = $m,
  chave_fechamento = $k, resumo_fechamento = $r where id = $id and status = 'aberto' and versao = $v` dentro da
  transação da ação. 0 linhas → o servidor relê: já fechado com a mesma chave e o mesmo resumo → devolve o resultado
  (RNF-02); fechado de outro jeito → "este caixa já foi fechado"; versão diferente → "entrou um pagamento novo, confira a
  contagem" (RF-10). A linha da versão também espera um pagamento ou movimento em andamento (ADR 0017 · D2).
- A trava só vale no nível padrão (`READ COMMITTED`); se a E36·A usar outro nível, o teste 760 acusa.
- **O pagamento do Checkout** (ligar ao caixa, somar no esperado se for dinheiro, somar na versão) é gatilho **da
  migration do Checkout** (ADR 0017 · D1). Aqui não há nada do Checkout.

### 4.5 Travas RLS e privilégios (M5; toda política `to authenticated`; E32·3·A)
| Tabela | Ler | Criar | Alterar | Apagar | Privilégio de `authenticated` |
|---|---|---|---|---|---|
| `caixas` | `S and (P = 'dona' or (P = 'recepcao' and status = 'aberto'))` | with check `S and P in ('dona','recepcao')` | using `S and P in ('dona','recepcao') and status = 'aberto'`; with check `S and P in ('dona','recepcao')` | ninguém | `select`; `insert (valor_inicial_centavos, observacao, chave_abertura, resumo_abertura)`; `update (status, contado_centavos, motivo_diferenca, chave_fechamento, resumo_fechamento)` |
| `caixa_movimentos` | `S and (P = 'dona' or (P = 'recepcao' and` o caixa está aberto`))` | with check `S and P in ('dona','recepcao')` | ninguém | ninguém | `select`; `insert (tipo, valor_centavos, motivo, chave, resumo)` |

- `update ... returning` e `insert ... returning` pedem também a política de leitura: na recepção, a linha que acabou de
  fechar deixa de ser visível. O servidor **não** usa `returning` no fechamento; calcula o resultado na mesma transação
  antes do `update` (pela regra do domínio, com o esperado lido sob a trava) e o banco confere (não verificado, §12).
- A profissional não tem leitura nem escrita (E32·3·A).
- **Nenhuma função nova executável por `authenticated`**: a lista do `010_base_estrutura_test.sql` do item 3 não muda.

### 4.6 Testes pgTAP (`supabase/tests/database/`, banco local, `pnpm db:test`; faixa **7xx**; dados fictícios escritos do zero, RG-07)
| Arquivo | Prova |
|---|---|
| `700_caixa_isolamento_test.sql` | molde do item 3 para `caixas` e `caixa_movimentos`: A não lê, cria, altera nem apaga de B; sem papel e sem login, nada (CA-09) |
| `710_caixa_regras_test.sql` | nasce aberto com moeda do estúdio e esperado = inicial; inicial 0 aceito, −1 e T+1 recusados; segundo aberto recusado (`23505`); `aberto_por`, `caixa_id`, `versao`, `esperado` vindos do pedido ignorados ou recusados (sem privilégio); moeda trocada no estúdio com caixa aberto → movimento recusado (L-2) (CA-01, CA-02, CA-04 parte do banco) |
| `720_caixa_movimentos_test.sql` | sangria e suprimento mudam esperado e versão; sangria > esperado recusada; sem caixa aberto recusados; motivo com 2 e 201 caracteres recusado; mesma chave grava um (CA-03) |
| `730_caixa_fechamento_test.sql` | fechar grava esperado, contado, diferença; diferença ≠ 0 sem motivo recusada; versão antiga → 0 linhas; fechar duas vezes → um fechamento; caixa fechado não muda nem apaga, nem pela dona; nenhum movimento entra nele (CA-05, CA-07) |
| `740_caixa_papeis_test.sql` | E32·3·A: dona e recepção abrem, movimentam e fecham; recepção não lê caixa fechado nem os movimentos dele; profissional nada (CA-10 no banco) |
| `750_caixa_autor_test.sql` | autor = quem gravou (pela sessão); ninguém grava autor nulo nem de outra pessoa; `app.autor_da_sessao()` sem `execute` para `authenticated` (ADR 0017 · D7; CA-11 parte do banco) |
| `760_caixa_concorrencia_test.sql` | duas ligações de verdade (`dblink`, criada só no teste, esquema `extensions`, como o 240 do Agendamento): abrir × abrir → um; fechar × fechar → um; sangria × fechar → a sangria entra antes ou é recusada, nunca em caixa fechado; sangria × sangria → a gaveta não fica negativa (CA-02, CA-03, CA-06 parte do Caixa) |

O `010_base_estrutura_test.sql` do item 3 passa a valer para as duas tabelas. Prova de que os testes pegam erro: numa
cópia local, tirar o `where` do índice parcial ou a condição da versão e ver o teste ficar vermelho; desfazer.

## 5. Código por camada (regra de dependência do `ARCHITECTURE.md` §3, travada pelo lint do item 2)

### 5.1 Contrato usado da E36·A (não se escreve aqui)
O de `src/server/portas/` (spec Entrar RF-16): permissão, esquema, trabalho; contexto com `usuarioId`, `orgId`, `papel`
da sessão e o banco com a sessão da pessoa **numa transação por ação**; registro (porta 6) pelo contexto; códigos de
erro de RF-22. **Pedidos a essa spec** (recomendação, mesmos do Catálogo e do Agendamento): o contexto trazer `moeda`,
`idioma` e `fuso` do estúdio; o registro aceitar **detalhes estruturados** (uuid, inteiro, código) além dos ids (ADR
0017 · D8); a transação por ação. Sem a transação, este plano volta à 5b. Sem moeda e fuso no contexto, entra
`src/data/estudio.ts` (condicional, §8).

### 5.2 `src/domain/caixa/` (TypeScript puro, com teste; Engenheiro de software)
| Arquivo | O que tem | Regras |
|---|---|---|
| `tipos.ts` | `Caixa`, `Movimento`, `Centavos`, `Situacao` (Confere, Sobra, Falta), códigos de erro | — |
| `valores.ts` | inteiro, ≥ 0 ou > 0, ≤ T (ADR 0017 · D5); moeda de 2 casas; leitura e formato pelo `lerPreco` e `formatarPreco` de `src/domain/catalogo/preco.ts` (reuso, sem alterar; só a faixa é daqui) | RN-01 a RN-03 |
| `regras.ts` | `esperado(inicial, dinheiroDoCheckout, suprimentos, sangrias)`; `podeSangrar`; `diferenca` e `situacao`; motivo obrigatório; constantes das E32·1 e E32·2 | RN-04 a RN-06, RF-05 a RF-07 |
| `acesso.ts` | constante da E32·3 (papel × abrir, movimentar, fechar, ver aberto, ver histórico) | RF-11, CA-10 |
| `registro.ts` | tipo fechado dos detalhes do registro: `caixa_id`, `movimento_id`, `tipo`, valores em centavos, `moeda`, `situacao`; **nenhum texto** (ADR 0017 · D8) | RF-12 |
| `resumo.ts` | conteúdo canônico de cada ação (ordem fixa dos campos) para o resumo da idempotência; o SHA-256 é feito no servidor | RNF-02 |

Testes (CA-01): esperado com todos os tipos; Confere/Sobra/Falta; 0 inicial; −1, T+1, fração, moeda de 0 e 3 casas
(JPY, BHD) recusados; sangria igual ao esperado aceita e 1 centavo a mais recusada; resumo igual para o mesmo conteúdo e
diferente para outro.

### 5.3 `src/server/caixa/` (Engenheiro de software)
| Arquivo | O que tem |
|---|---|
| `esquemas.ts` | entradas: abrir (`chave` uuid, `valorInicial` inteiro, `observacao?` ≤ 300), movimento (`chave`, `tipo`, `valor` inteiro, `motivo` 3–200), contar (`caixaId`, `contado` inteiro), fechar (`chave`, `caixaId`, `contado`, `versao` inteiro, `motivo?` 5–300), histórico (`pagina` ≥ 1), ver (`caixaId`). **Sem estúdio, sem caixa nos movimentos, sem esperado**; chave desconhecida descartada |
| `ler.ts` | `lerCaixaAtual` (aberto, movimentos paginados, resumo por forma pelo encaixe; **sem o esperado** na E32·2·A), `listarHistorico` (20 por página, `limit 21`), `verCaixa` |
| `abrir.ts` | `abrirCaixa`: resumo SHA-256 (Web Crypto `crypto.subtle.digest`), insert; `23505` na chave → mesma chave e resumo devolve o existente, outro resumo → `conflito`; `23505` no índice parcial → `caixa_ja_aberto`. Registro `caixa.aberto` (`caixa_id`, `valor_inicial`, `moeda`) |
| `movimentar.ts` | `registrarSangria`, `registrarSuprimento`: idem; recusa do banco → `sem_caixa_aberto`, `sangria_maior_que_esperado`. Registro `caixa.sangria` / `caixa.suprimento` (`caixa_id`, `movimento_id`, `valor`, `moeda`), **sem motivo** |
| `fechar.ts` | `contarCaixa` (passo 1: recebe o contado, devolve esperado, diferença, situação e a `versao`; não grava; o aviso de atendimentos sem checkout pelo encaixe, só o número); `fecharCaixa` (passo 2: update com a versão, §4.4; códigos `caixa_ja_fechado`, `entrou_pagamento_novo`, `motivo_obrigatorio`). Registro `caixa.fechado` (`caixa_id`, `esperado`, `contado`, `diferenca`, `situacao`, `moeda`), **sem motivo** |
| `*.test.ts` (4) | banco trocado por um falso: estúdio e caixa no pedido ignorados; sem login e sem papel nada; papel × ação (E32·3·A); contagem cega (a resposta de `lerCaixaAtual` não traz o esperado; `contarCaixa` só depois do contado, CA-08); mesma chave e mesmo conteúdo → mesmo resultado; outro conteúdo → `conflito`; detalhes do registro sem nenhum texto (marcador fictício no motivo não aparece, CA-11); idas ao banco ≤ teto (§6) |

### 5.4 `src/data/caixa/` (Engenheiro de software; consultas conferidas pelo Engenheiro de dados)
| Arquivo | O que tem |
|---|---|
| `caixas.ts` | ler o aberto (com `versao` e esperado, só para o servidor); histórico paginado; ler um; inserir; fechar com versão |
| `movimentos.ts` | inserir; página dos movimentos do caixa |
| `entradas-por-forma.ts` | **encaixe** (ADR 0017 · D9): devolve lista vazia; a tela mostra "em desenvolvimento" (RF-14). A `feat/checkout` troca pela soma por forma dos pagamentos do caixa |
| `atendimentos-sem-checkout.ts` | **encaixe**: devolve "em desenvolvimento" (spec §9). A `feat/checkout` troca pela contagem real (RF-08) |
| `exemplo-local.ts` | dados fictícios, escritos do zero, para o e2e do pagamento em dinheiro enquanto o Checkout não existe (RF-14, CA-12) |

Nenhum filtro por `org_id` vindo de fora: a RLS decide.

### 5.5 `src/app/` (Engenheiro de software; desenho do Designer de produto na ficha visual, **antes** das telas)
- **Rotas:** `src/app/routes/caixa.tsx` (Caixa atual; no celular, Abrir e Fechar como tela sem barra) e
  `src/app/routes/caixa.historico.tsx` (`validateSearch` só `pagina` inteiro e `caixa` uuid para o detalhe).
- **Navegação:** uma linha em `src/app/navegacao.ts` liga o Caixa (`banknote`, 5º no menu do computador, dentro de
  **Mais** no celular, `DESIGN.md` §7), com o submenu Caixa atual · Histórico (o Histórico só para quem a E32·3 deixa).
- **Telas** em `src/app/paginas/caixa/`, só com componentes do item 4 e as peças que o dono aprovar na ficha:

| Arquivo | O que tem |
|---|---|
| `atual.tsx` | fechado (`EstadoVazio` "Nenhum caixa aberto" + Abrir caixa) e aberto (bloco "Aberto por", lista paginada, resumo por forma, Fechar caixa, Opções ▾ / ⋮ com Sangria e Suprimento; "aberto desde <data>") |
| `abrir.tsx` | `Painel` 480 (1440) ou tela sem barra (390): Valor inicial com o símbolo da moeda, Observação |
| `movimento.tsx` | `Janelinha` 340 (1440) ou `Folha` (390): Valor, Motivo com o aviso de não escrever dado de cliente ou de saúde |
| `fechar.tsx` | passo 1 (aviso de atendimentos sem checkout, sem nomes; Dinheiro contado), passo 2 (esperado, contado, diferença com palavra e ícone; Motivo quando ≠ 0; janelinha "não se desfaz") |
| `historico.tsx` e `ver.tsx` | `Tabela` (1440) ou `LinhaLista` 64 (390), paginação; detalhe só leitura |
| `caixa.css` | só `var(--...)` do `tokens.css` |
| `caixa.test.tsx` | `renderToString`: uma ação preta por tela; diferença e estado sempre com palavra; nenhum texto fixo fora dos idiomas; a tela do passo 1 não tem o esperado |

- **Idiomas (RNF-05):** bloco `caixa` na base comum `src/app/i18n/{pt,es,en}.ts` da `feat/entrar-servico` (RF-34 de
  lá; ordem do coordenador, 28/11), com o texto de cada código de erro do §5.3. Valores pelo `formatarPreco`; datas no
  fuso do estúdio.
- Os nomes e peças que faltam no `DESIGN.md` (spec §4) entram pela ficha (etapa 6), nunca na construção.

## 6. Tetos (ADR 0017 e `ARCHITECTURE.md` §5 e §11)
- Movimentos do caixa aberto: 50 por página (`limit 51`); histórico: 20 por página (`limit 21`); ordem estável (data + `id`).
- Idas ao banco: ler o caixa atual ≤ 3 (caixa, movimentos, resumo por forma) + 1 do aviso no passo 1; abrir, movimentar,
  fechar ≤ 3 cada (ler, gravar, registro), além das portas.

## 7. Testes de tela (Playwright, projetos `celular` 390 e `computador` 1440 do item 2)
| Arquivo | Prova |
|---|---|
| `e2e/preparo/caixa-dados.ts` | cria e apaga estúdios A e B, dona, recepção, profissional, no banco **local** (fictícios) |
| `e2e/caixa.spec.ts` | CA-12: abrir, suprimento, sangria, pagamento em dinheiro (pelo `exemplo-local.ts`), fechar com Falta e motivo, ver no Histórico (dona); recepção sem Histórico; a URL só tem ids e página |
| `e2e/caixa-estados.spec.ts` | CA-13: vazio, carregando (`page.route` atrasado), erro (500), sucesso, "já existe um caixa aberto", "entrou um pagamento novo" |
| `e2e/caixa-acessibilidade.spec.ts` | `AxeBuilder` com as etiquetas do item 4 nas telas, na janelinha e na folha; teclado; diferença com nome acessível |

## 8. Arquivos (lista FECHADA)
Fora desta lista nada muda (`AGENTS.md` §6). Arquivo que uma ferramenta crie fora daqui: parar e relatar.

**Banco (Engenheiro de dados):** `supabase/migrations/<ts>_caixa_autor_da_sessao.sql`, `<ts>_caixas.sql`,
`<ts>_caixa_movimentos.sql`, `<ts>_caixa_regras.sql`, `<ts>_caixa_politicas.sql` ·
`supabase/tests/database/700_caixa_isolamento_test.sql` a `760_caixa_concorrencia_test.sql` (7 arquivos, §4.6) ·
`docs/adr/0016-caixa-tabelas-do-antigo.md`.

**Domínio:** `src/domain/caixa/{tipos,valores,regras,acesso,registro,resumo}.ts` e
`{valores,regras,acesso,registro,resumo}.test.ts`.

**Servidor:** `src/server/caixa/{esquemas,ler,abrir,movimentar,fechar}.ts` e `{ler,abrir,movimentar,fechar}.test.ts`.

**Dados:** `src/data/caixa/{caixas,movimentos,entradas-por-forma,atendimentos-sem-checkout,exemplo-local}.ts` ·
`src/data/estudio.ts` (só se a E36·A não trouxer moeda e fuso no contexto).

**Telas:** `src/app/routes/caixa.tsx` · `src/app/routes/caixa.historico.tsx` · `src/app/routeTree.gen.ts` (gerado) ·
`src/app/navegacao.ts` (só a linha do Caixa) · `src/app/paginas/caixa/{atual,abrir,movimento,fechar,historico,ver}.tsx`
· `src/app/paginas/caixa/caixa.css` · `src/app/paginas/caixa/caixa.test.tsx` · `src/app/i18n/{pt,es,en}.ts` (só o bloco
`caixa`).

**Testes de tela:** `e2e/preparo/caixa-dados.ts` · `e2e/caixa.spec.ts` · `e2e/caixa-estados.spec.ts` ·
`e2e/caixa-acessibilidade.spec.ts`.

**Ficha visual (Designer de produto):** `specs/20261128-023000-caixa/ficha-visual.md` e `specs/20261128-023000-caixa/ficha/*.png`.

**Texto:** `DESIGN.md`, só as linhas que o dono aprovar na ficha (spec §4) (Designer de produto) · `docs/STATUS.md`,
`docs/BACKLOG.md`, `CHANGELOG.md`, `docs/decisoes/2026-11-27-fundacao.md` (respostas E32 e das lacunas) (Documentador).

**Processo:** `specs/20261128-023000-caixa/{spec.md,plan.md,tasks.md}` ·
`docs/adr/0017-dinheiro-checkout-e-caixa-ordem-trava-e-autor.md`.

**Intactos:** `src/app/ui/**`, `src/app/estilos/**`, `src/server/portas/**` e o cliente do banco (E36·A),
`src/domain/catalogo/**` (reusado, não alterado), as migrations e testes dos itens 2 e 3, da E36·A e dos outros
módulos (inclusive `010_base_estrutura_test.sql`), `supabase/config.jsonc`, `supabase/seed.sql`, `supabase/moldes/**`,
`package.json`, `pnpm-lock.yaml` (nenhuma dependência nova), `eslint.config.mjs`, `playwright.config.ts`, `.github/**`,
`src/*/AGENTS.md`, `src/*/CLAUDE.md`, `ARCHITECTURE.md`, `AGENTS.md`, `SECURITY.md`. **Nada do Checkout** (ADR 0017 · D1).

## 9. Branch (decisão do Engenheiro de DevOps)
`feat/caixa` recebe, **por merge**, nesta ordem: `feat/banco-ligacao` e `feat/design-system-codigo` (já com a
`chore/fundacao-tecnica`), `feat/entrar-servico` (E36·A) e `feat/catalogo` (reuso do `preco.ts`); de novo sempre que
elas ganharem commit. **Não** recebe Checkout nem Agendamento. `src/app/navegacao.ts` nasce na `feat/entrar-servico`
(decisão já tomada); o Caixa só acrescenta a linha dele. PR de rascunho empilhado; nunca se junta numa
base. A `feat/checkout` fica **em cima** desta (ADR 0017 · D1). Quando as bases entrarem na `previas`, a base do PR
passa à `previas`, antes do pedido de merge. Conflitos esperados: `routeTree.gen.ts` (regenera), `navegacao.ts` e os
arquivos de idioma (soma de linhas), carimbo das migrations (o Engenheiro de dados regenera, sempre antes das do Checkout).

## 10. Critério → prova
| CA | Prova | Quem confere |
|---|---|---|
| CA-01 | `src/domain/caixa/*.test.ts`; pgTAP 710 | QA; Auditor de risco |
| CA-02 | pgTAP 710 e 760; `abrir.test.ts` | Engenheiro de dados revisor; Auditor de risco |
| CA-03 | `regras.test.ts`; pgTAP 720 e 760 | QA |
| CA-04 | parte do banco: pgTAP 710 (caixa do pedido ignorado); a ligação com o pagamento se prova no Checkout (pgTAP 640 e 650 de lá) | Auditor de risco |
| CA-05, CA-07 | pgTAP 730; `fechar.test.ts` | QA |
| CA-06 | pgTAP 760 (sangria × fechar) e, no Checkout, 650 (pagamento × fechar) | Engenheiro de dados revisor; Auditor de risco |
| CA-08 | `ler.test.ts` e `fechar.test.ts` (cega; aviso não impede); a contagem real do aviso, no Checkout | QA |
| CA-09 | pgTAP 700 | QA; Engenheiro de segurança |
| CA-10 | pgTAP 740; testes do servidor; `acesso.test.ts` | Engenheiro de segurança |
| CA-11 | testes do servidor (registro sem texto); pgTAP 750; revisão da E6·1 (autor pela sessão, sem contorno) | Engenheiro de segurança; Auditor de risco |
| CA-12, CA-13 | e2e do §7 nos 2 projetos; checklist `DESIGN.md` §10 | QA; Revisor de design |
| CA-14 | ADR 0016 com cada linha do §4.1, conferência preenchida | Auditor de risco |
| CA-15 | histórico da CI; nenhum `supabase link`, `db push`, `--remote`, `--linked` | Auditor de risco |
| CA-16 | relatórios sem "Bloqueia"; veredito do QA; conferência do dono na prévia | Gerente de projeto |
| Escopo | `git diff --name-only <base>...HEAD` contra o §8 | Revisor de código |

## 11. Se o dono responder diferente
| Resposta | O que muda |
|---|---|
| **E32·1·B** | `check (valor_inicial_centavos > 0)`; o gatilho do movimento e o do pagamento (Checkout) recusam caixa aberto antes de "hoje" no fuso do estúdio; testes 710, 720 |
| **E32·1·C** | **para:** sai o índice parcial; entra a escolha do caixa (por ponto ou pessoa) nos gatilhos daqui e do Checkout; plano refeito, nova 5b (ADR 0017, Consequências) |
| **E32·2·B** | `lerCaixaAtual` traz o esperado; o passo 1 o mostra; muda `caixa.test.tsx` e `ler.test.ts` |
| **E32·2·C** | reabrir: tabela de fechamentos anteriores, nova ação e política só da dona; plano refeito, nova 5b |
| **E32·3·B** | leitura dos fechados também para a recepção (política e `acesso.ts`); teste 740 |
| **E32·3·C** | criar, alterar e movimentar só `dona`; recepção só lê o aberto; teste 740 e e2e |
| **E31·1·C** | o Caixa não recebe entradas do Checkout; os encaixes ficam vazios; spec ajustada antes (spec §9) |

## 12. Riscos e não verificado
- **Bloqueante para construir servidor e dados:** E36·A na branch com transação por ação. Domínio, banco e telas (plano
  B) podem andar antes.
- **E6·1 à vista (risco aceito pelo dono, RF-12):** no modo "entrar como o estúdio", abrir, sangria, suprimento e fechar
  ficam sem autor e sem registro; o estúdio pode atribuir uma diferença a uma funcionária. Este plano não contorna: deixa
  um ponto só (`app.autor_da_sessao()` e o registro da E36·A) para a spec do painel admin ligar o modo (ADR 0017 · D7).
- **E24·3 em aberto (moeda):** com troca de moeda permitida, o caixa aberto recusa entradas na moeda nova (L-2).
- **Não verificado:** o comportamento do `UPDATE` com `where versao = $v` sob concorrência no banco local (o teste 760
  prova); que o privilégio por coluna basta para só os gatilhos mudarem contador e versão (o teste 710 tenta pelo
  pedido); a política de
  leitura no `update` sem `returning` para a recepção; `dblink` na imagem local do Supabase CLI 3.4.0 (mesmo risco do
  Agendamento; sem ele o teste 760 vai para fora do pgTAP e volta à 5b); `crypto.subtle.digest` no Cloudflare Workers e
  no Node 26 (conferir na documentação oficial na T6); `src/domain/catalogo/preco.ts` ainda não construído (nomes do
  plano do Catálogo).
- Numeração: ADR 0016 e 0017 e a faixa 7xx são deste módulo; o Documentador confere no PR.
