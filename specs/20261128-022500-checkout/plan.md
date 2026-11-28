# Plano · Checkout v1 (núcleo): fechar a conta de um agendamento e registrar o pagamento

- **Spec:** `specs/20261128-022500-checkout/spec.md` (Draft; Auditor de risco e revisão 5b feitos; E31·1 a E31·3 em aberto)
- **Escrito por:** Arquiteto de software · **Norma:** modelo C4 e ADR (mais Clean Architecture, Twelve-Factor, WCAG 2.2,
  OWASP ASVS 4.0.3 V4, V5, V7 e V11.1, ISO 4217, boas práticas do Postgres e do Supabase) · **Revisão:** pendente
  (etapa 5 Analista de requisitos; 5b Gerente de projeto)
- **Decisões técnicas:** `docs/adr/0017-dinheiro-checkout-e-caixa-ordem-trava-e-autor.md` (escrito junto com o plano do
  Caixa; mora na `feat/caixa` e chega aqui pelo merge, §9). **Decisões por tabela do antigo:**
  `docs/adr/0015-checkout-tabelas-do-antigo.md`, escrito pelo Engenheiro de dados na T3 (não aqui).
- **Portão:** construção em PR de rascunho pode começar antes da aprovação (E22·B); o pedido de merge só com a spec
  "Status: Approved" e as respostas E31 gravadas.
- **Dependência fixada pelo dono (E36·A):** login, sessão, as 6 portas, a transação por ação e o registro (porta 6) vêm
  da spec "Entrar e camada de serviço" (`feat/entrar-servico`). O Checkout **usa**, não constrói.
- **Bases lidas em 28/11/2026 (só leitura, nada editado lá):** item 3 (`/home/user/wt-banco`: ADR 0005, as 4
  migrations, molde de isolamento; `estudios.moeda` com `grant update` para a dona; E24·3 em aberto); item 4
  (`/home/user/wt-ds`: `src/app/ui/*`); spec E36·A (`/home/user/wt-entrar/.../spec.md`: RF-16, RF-22, RF-24, RF-29,
  RF-34); Catálogo (`/home/user/wt-catalogo`: `plan.md` §4.3 `public.servicos` com `unique (org_id, id)`,
  `preco_centavos integer` 0 a 10 000 000, `consultas.ts` `servicosParaCobrar`; ADR 0012 · D1 a D3, `on delete
  restrict`); Agendamento (`/home/user/wt-agendamento`: `plan.md` §4.3 `public.agendamentos` com status e
  `unique (org_id, id)`, §4.4 "a trava do RF-17 é do Checkout", `src/data/agendamento/checkout.ts` como encaixe; ADR
  0010 · D1, D5, D6); Caixa (`/home/user/wt-caixa`: spec, `plan.md`, ADR 0017). Antigo: **não relido** pelo Arquiteto;
  as sugestões do §4.1 partem do §7 da spec.

## 1. Resumo (C4)
**Contexto:** dona e recepção (E31·2·A) fecham a conta no painel do agendamento; o pagamento em dinheiro entra no
caixa aberto (E31·1·A). Nenhum sistema externo (sem processador; registro à mão).
**Contêiner:** o app (TanStack Start) e o banco (Postgres do Supabase), com a camada de serviço da E36·A.
**Componentes (fluxo de "Pagar <valor>"):**

```
src/app/paginas/checkout/* (Revisar · Pagar · Concluído · Ver checkout)    URL só com o id do agendamento (RNF-03)
   │ envia: chave, agendamentoId, servicoIds[], pagamentos[{forma, valor}]  (nunca preço, total ou caixa)
   ▼
src/server/checkout/fechar.ts ── 6 portas da E36·A, uma transação por ação
   ├─► src/domain/checkout/* (status permitido, total, soma, formas, acesso, registro, resumo)
   ├─► src/server/catalogo/consultas.ts (preços atuais) · consulta do Agendamento (status, serviços) · Clientes (nome, só na tela)
   ▼  com a sessão da pessoa
src/data/checkout/* ──► public.checkouts · public.checkout_itens · public.checkout_pagamentos   (RLS)
                        gatilhos: preço e nome copiados do Catálogo, total conferido no fim, imutável, RF-17
                        pagamento → public.caixas (trava a linha, soma no esperado e na versão; ADR 0017 · D2)
```

## 2. Lacunas para o Analista de requisitos (a spec não cobre; não decido, `AGENTS.md` §4)
- **L-1 · E31·1, E31·2, E31·3 sem resposta.** O plano usa A, A, A e mostra no §11 o que muda.
- **L-2 · Serviço do agendamento arquivado no Catálogo depois de marcado.** O RF-02 só diz que o serviço **adicionado**
  é ativo. **Recomendo:** o que já estava no agendamento pode ser cobrado mesmo arquivado (pelo preço atual do
  Catálogo); só o adicionado precisa estar ativo. Na outra opção, a conta de um agendamento com serviço arquivado não
  fecha sem tirá-lo.
- **L-3 · Quantos itens por conta.** A spec limita 5 linhas de pagamento, mas não os itens. **Recomendo** 20 (o
  Agendamento aceita 10 e "Adicionar" soma alguns; limite de entrada, ASVS V11.1.4). Texto de tela: confirmar.
- **L-4 · Moeda do estúdio que muda (E24·3 em aberto; dinheiro).** O preço do Catálogo é lido como centavos da moeda
  **atual** do estúdio, e o checkout guarda essa moeda (RF-15). Se a dona trocar a moeda, preços antigos mudam de
  sentido (Catálogo L-3), e o caixa aberto recusa pagamento na moeda nova (Caixa L-2). Decisão do dono pela E24·3.
- **L-5 · Leituras de outros módulos.** O Checkout precisa ler, pelo servidor do outro módulo (ADR 0010 · D5), o status
  e os serviços do agendamento e o nome da cliente para o resumo. O plano do Agendamento não tem uma consulta para outros
  módulos (só `verAgendamento`, que é ação com portas) e o de Clientes não foi conferido para isso. **Recomendo** que
  os dois planos ganhem `consultas.ts` (como o do Catálogo); senão, este plano os cria (lista §8, condicional).
- **L-6 · Profissional e "Ver checkout".** Com E31·2·A, a profissional não fecha nem vê o checkout; no painel dela o
  botão não aparece. Confirmar no texto da E31·2 que "ver" vai junto.
- **L-7 (só texto):** o cabeçalho diz "Branch: `feat/checkout` (a partir da `previas`)"; a branch é empilhada (§9).

## 3. Dúvidas em aberto: o plano usa a recomendação
Cada resposta vira **uma constante** em `src/domain/checkout/acesso.ts` e `src/domain/checkout/regras.ts` e **uma**
versão das políticas e restrições; nada de chave de liga e desliga.

## 4. Banco (tipo Banco; quem decide a forma é o Engenheiro de dados, ADR 0015)

### 4.1 Decisão por tabela do antigo · **sugestão ao Engenheiro de dados, que decide na T3** (ADR 0015, conferido por outra instância, E16·1)
| Antigo | Sugestão | Motivo |
|---|---|---|
| `sales` | **reescrever** como `public.checkouts` | concordo com a spec: centavos (`bigint`, ADR 0017 · D5), sem `client_name` (a cliente vem pelo agendamento), sem rascunho, parcial, desconto, gorjeta e saldo; entra chave e resumo (ADR 0017 · D3) |
| `sale_items` | **reescrever** como `public.checkout_itens` | só serviço; nome e preço **copiados pelo banco** do Catálogo (RF-04; ADR 0017 · D6) |
| `sale_payments` | **reescrever** como `public.checkout_pagamentos` | formas da E31·1; ligação com o caixa pela migration M4 (RF-18) |
| `checkout_requests` | **trocar por chave única na linha do checkout** | ADR 0017 · D3: o checkout nasce de uma vez, então não há pedido à parte para guardar |
| `sale_refunds`, `sale_partial_refunds` | **adiada** (spec "estorno e desconto") | concordo |
| `sale_counters` | **descartar** (por ora) | concordo |
| `transactions` | **adiada** (Financeiro) | concordo; o Caixa lê o dinheiro pela linha do caixa (ADR 0017 · D2) |
| `gift_cards`, `appointment_deposits` | **descartar** nesta spec | concordo (E21·3·B) |
| funções do antigo de fechar e estornar | **descartar** | gravação pela camada de serviço e gatilhos (ADR 0017 · D6); o Engenheiro de dados confere no corpo se recebem estúdio do pedido |

### 4.2 Migrations (com `pnpm exec supabase migration new <nome>`; carimbo **depois** das do Agendamento, do Catálogo e de **todas** as do Caixa, ADR 0017 · D1)
| # | Nome | Conteúdo (sugestão; forma final do Engenheiro de dados) |
|---|---|---|
| M1 | `checkouts` | guarda: para com erro claro se `public.agendamentos`, `public.servicos` ou `public.caixas` não existirem; tabela §4.3, índices, RLS ligada e forçada, `revoke all` |
| M2 | `checkout_itens` | idem |
| M3 | `checkout_pagamentos` | idem, ainda sem caixa |
| M4 | `checkout_pagamento_caixa` | **a ligação do RF-18:** coluna `caixa_id`, chave composta `(org_id, caixa_id) → public.caixas (org_id, id) on delete restrict`, `check (forma <> 'dinheiro' or caixa_id is not null)`, gatilho da trava (§4.4) |
| M5 | `checkout_regras` | os outros gatilhos do §4.4, inclusive o do RF-17 em `public.agendamentos` |
| M6 | `checkout_politicas` | políticas e privilégios por coluna do §4.5 |

### 4.3 Tabelas (sugestão)
`S` = `org_id = (select app.estudio_da_sessao())` · `P` = `(select app.papel_da_sessao())` · `T` = 9 007 199 254 740 991.

**`public.checkouts`**
| Coluna | Tipo e regra |
|---|---|
| `id` | `uuid primary key default gen_random_uuid()`; `unique (org_id, id)` |
| `org_id` | `uuid not null default (app.estudio_da_sessao()) references public.estudios (org_id) on delete cascade`; sem privilégio de gravação |
| `agendamento_id` | `uuid not null`; `foreign key (org_id, agendamento_id) references public.agendamentos (org_id, id) on delete restrict` (RF-09) |
| `estado` | `text not null check (estado in ('pago','sem_valor'))`; posto pelo gatilho (total > 0 → pago; = 0 → sem_valor, E31·3·A) |
| `moeda` | `text not null`; posta pelo gatilho de `estudios.moeda` (RF-15) |
| `total_centavos` | `bigint not null check (total_centavos between 0 and T)`; conferido no fim da transação (§4.4) |
| `fechado_por`, `fechado_em` | `uuid null` (gatilho, `app.autor_da_sessao()`, ADR 0017 · D7), `timestamptz not null default now()` |
| `chave`, `resumo` | `uuid not null`, `text not null check (resumo ~ '^[0-9a-f]{64}$')`; `unique (org_id, chave)` (RNF-02) |

- **Um fechado por agendamento (RF-08, ADR 0017 · D4):** `create unique index checkouts_um_fechado on public.checkouts (org_id, agendamento_id) where estado in ('pago','sem_valor')`.
- Índices: o do índice parcial serve à leitura por agendamento; `(org_id, fechado_em desc)`.

**`public.checkout_itens`:** `org_id`, `checkout_id`, `ordem smallint not null check (ordem between 1 and 20)` (L-3),
`servico_id uuid not null`, `nome text not null`, `preco_centavos integer not null check (preco_centavos between 0 and
10000000)`; `primary key (org_id, checkout_id, ordem)`; `(org_id, checkout_id) → checkouts (org_id, id) on delete
restrict`; `(org_id, servico_id) → public.servicos (org_id, id) on delete restrict` (ADR 0012 · D3: serviço cobrado não se
apaga no Catálogo). `nome` e `preco_centavos` **postos pelo gatilho**, nunca pelo pedido.

**`public.checkout_pagamentos`:** `org_id`, `checkout_id`, `ordem smallint not null check (ordem between 1 and 5)`,
`forma text not null check (forma in ('dinheiro','debito','credito','pix','bizum','transferencia','outra'))` (E31·1),
`valor_centavos bigint not null check (valor_centavos between 1 and T)`; `primary key (org_id, checkout_id, ordem)`;
`(org_id, checkout_id) → checkouts (org_id, id) on delete restrict`. **M4:** `caixa_id uuid null`, posto pelo gatilho;
`(org_id, caixa_id) → public.caixas (org_id, id) on delete restrict`; `check (forma <> 'dinheiro' or caixa_id is not null)`.
Índice `(org_id, caixa_id, forma)` (resumo por forma do Caixa).

### 4.4 Regras no banco (M4 e M5; todas `security definer`, `set search_path = ''`, nomes qualificados, sem `execute` para `authenticated`)
| Gatilho | Regra | Requisito |
|---|---|---|
| `before insert` em `checkouts` | lê o agendamento do mesmo estúdio com `for share` (espera uma troca de status em andamento); status fora de `chegou`, `iniciado`, `concluido` → recusa; `moeda` ← `estudios.moeda`; `estado` pelo total; autor e data pelo gatilho; ignora o resto | RF-01, RF-15, ADR 0017 · D6, D7 |
| `before insert` em `checkout_itens` e `checkout_pagamentos` | o checkout foi criado **nesta mesma transação** (senão recusa: nada se acrescenta depois); itens: `nome` e `preco_centavos` ← `public.servicos` do mesmo estúdio; serviço arquivado só se estiver no agendamento (L-2) | RF-02 a RF-04, RF-07, RF-10 |
| `before insert` em `checkout_pagamentos` (**M4, a trava do RF-18**) | numa instrução: `update public.caixas set versao = versao + 1, dinheiro_esperado_centavos = dinheiro_esperado_centavos + (case when new.forma = 'dinheiro' then new.valor_centavos else 0 end) where org_id = new.org_id and status = 'aberto' returning id, moeda`; achou → moeda do caixa ≠ do checkout recusa (Caixa L-2), senão `new.caixa_id` ← id; não achou → `dinheiro` recusa (código próprio, "abra o caixa"), outra forma fica com `caixa_id` nulo (E31·1·A; Caixa RF-10) | RF-11, RF-18; Caixa RF-03, RF-10, RNF-03; ADR 0017 · D2 |
| `constraint trigger ... deferrable initially deferred` em `checkouts`, `checkout_itens`, `checkout_pagamentos` | no fim da transação: ≥ 1 item; `total_centavos` = soma dos itens; total > 0 ⇒ 1 a 5 pagamentos e soma = total; total = 0 ⇒ nenhum pagamento (E31·3·A) | RF-05 a RF-07, RN-03, RN-04 |
| `before update or delete` nas três | sempre recusa (nem a dona, nenhuma via) | RF-10, CA-07 |
| `before update of status` em `public.agendamentos` | `para` em `cancelado` ou `ausencia` com checkout `pago` ou `sem_valor` → recusa com código próprio ("tem checkout; cancelar depende do estorno") | RF-17, CA-02b; Agendamento §4.4 |

- A trava vale no `READ COMMITTED` (padrão). Fechar o caixa e pagar disputam a **mesma linha** de `public.caixas`; quem
  chega depois espera e reavalia (ADR 0017 · D2). Provado no teste 650.
- O gatilho do RF-17 é `security definer`: vale também para a profissional, que não lê checkouts (E31·2·A).

### 4.5 Travas RLS e privilégios (M6; toda política `to authenticated`; E31·2·A)
| Tabela | Ler | Criar | Alterar · Apagar | Privilégio de `authenticated` |
|---|---|---|---|---|
| `checkouts` | `S and P in ('dona','recepcao')` | with check igual | ninguém | `select`; `insert (agendamento_id, total_centavos, chave, resumo)` |
| `checkout_itens` | igual | igual | ninguém | `select`; `insert (checkout_id, ordem, servico_id)` |
| `checkout_pagamentos` | igual | igual | ninguém | `select`; `insert (checkout_id, ordem, forma, valor_centavos)` |

- Sem privilégio em `caixa_id`, `nome`, `preco_centavos`, `estado`, `moeda`, autor: o pedido não os grava (RF-03, Caixa RF-03).
- **Nenhuma função nova executável por `authenticated`**: a lista do `010_base_estrutura_test.sql` não muda.

### 4.6 Testes pgTAP (`supabase/tests/database/`, banco local, `pnpm db:test`; faixa **6xx**; dados fictícios escritos do zero)
| Arquivo | Prova |
|---|---|
| `600_checkout_isolamento_test.sql` | molde do item 3 nas três tabelas; agendamento, serviço ou caixa de B num checkout de A recusado pela chave composta (CA-06, CA-09) |
| `610_checkout_regras_test.sql` | status permitidos e recusados (CA-04 no banco); nome e preço vêm do Catálogo, preço do pedido sem privilégio; total ≠ soma dos itens recusado no `commit`; soma dos pagamentos 1 centavo acima e abaixo recusada; linha 0 e 6ª linha recusadas; total zero sem pagamento → `sem_valor`, com pagamento recusado; item ou pagamento acrescentado em outra transação recusado (CA-01, CA-02) |
| `620_checkout_imutavel_test.sql` | update e delete recusados nas três, também com a sessão da dona; preço mudado no Catálogo não muda o item; serviço cobrado não se apaga no Catálogo (CA-03, CA-07) |
| `630_checkout_unico_idempotencia_test.sql` | segundo fechado do mesmo agendamento → `23505` no índice parcial; mesma chave → `23505` na chave (o servidor compara o resumo) (CA-05 sequencial) |
| `640_checkout_caixa_test.sql` | E31·1·A: dinheiro sem caixa aberto recusado; cartão e Pix sem caixa ficam nulos; com caixa, entram nele; dinheiro soma no esperado e toda forma soma na versão; `caixa_id` do pedido sem privilégio; caixa fechado não recebe; moeda diferente recusada; **esperado − inicial − suprimentos + sangrias = soma do dinheiro ligado** (CA-08; Caixa CA-04) |
| `650_checkout_concorrencia_test.sql` | duas ligações de verdade (`dblink`, como o 240 do Agendamento): dois fechamentos do mesmo agendamento com chaves diferentes → um; mesma chave → um; dinheiro × fechar caixa nas duas ordens (pagamento antes: o fechamento com a versão velha recusa; fechamento antes: o dinheiro é recusado); cartão × fechar → fica sem caixa, nunca em caixa fechado; cancelar agendamento × fechar checkout → um dos dois, nunca os dois; abrir caixa × dinheiro (CA-05; Caixa CA-06) |
| `660_checkout_agendamento_test.sql` | RF-17: com checkout `pago` ou `sem_valor`, Cancelado e Ausência recusados (também pela profissional dona do atendimento); sem checkout, aceitos (CA-02b) |
| `670_checkout_papeis_test.sql` | E31·2·A: dona e recepção leem e criam; profissional nada (CA-10 no banco) |
| `680_checkout_autor_test.sql` | `fechado_por` = quem gravou, pela sessão; ninguém grava outro autor nem nulo (ADR 0017 · D7; CA-11 parte do banco) |

## 5. Código por camada (regra de dependência do `ARCHITECTURE.md` §3, travada pelo lint do item 2)

### 5.1 Contrato usado da E36·A
Igual ao do Caixa (`/home/user/wt-caixa/specs/20261128-023000-caixa/plan.md` §5.1): portas, contexto com `usuarioId`,
`orgId`, `papel`, banco com a sessão **numa transação por ação**, registro pelo contexto com **detalhes estruturados**
(ADR 0017 · D8), códigos de RF-22. Sem transação por ação, este plano volta à 5b. O módulo **nunca** grava o registro
por conta própria (ADR 0017 · D7).

### 5.2 `src/domain/checkout/` (TypeScript puro, com teste; Engenheiro de software)
| Arquivo | O que tem | Regras |
|---|---|---|
| `tipos.ts` | `Checkout`, `Item`, `Pagamento`, `Forma` (lista E31·1), `Estado`, códigos de erro | — |
| `regras.ts` | status que abrem o checkout; `total(itens)`; `conferirPagamentos(total, linhas)` (até 5, > 0, soma igual; total zero sem linha); constantes E31·1 (dinheiro exige caixa) e E31·3 (zero permitido, sem teto) | RF-01, RF-05, RF-06, RN-03, RN-04 |
| `valores.ts` | reusa `src/domain/catalogo/preco.ts` (ler e mostrar) e o teto `T` de `src/domain/caixa/valores.ts`; moeda de 2 casas | RN-01, RN-02 |
| `acesso.ts` | constante da E31·2 (papel × fechar e ver) | RF-12 |
| `registro.ts` | detalhes do registro: `checkout_id`, `agendamento_id`, `total`, `moeda`, `pagamentos [{forma, valor}]`, `caixa_id?`; **nenhum texto** (ADR 0017 · D8) | RF-13 |
| `resumo.ts` | conteúdo canônico (agendamento, serviços na ordem, linhas de pagamento) para a idempotência | RNF-02 |

Testes (CA-01, CA-02, CA-04): total; ±1 centavo; 0, 5 e 6 linhas; total zero com e sem linha; moeda de 0 e 3 casas
recusada; os 7 status; resumo igual para o mesmo conteúdo e diferente para outro.

### 5.3 `src/server/checkout/` (Engenheiro de software)
| Arquivo | O que tem |
|---|---|
| `esquemas.ts` | abrir e ver (`agendamentoId` uuid); fechar (`chave` uuid, `agendamentoId`, `servicoIds` 1 a 20 uuid, `pagamentos` 0 a 5 de `{forma, valor inteiro}`). **Sem preço, total, caixa, moeda ou estúdio**; chave desconhecida descartada |
| `ler.ts` | `abrirCheckout` (status e serviços do agendamento, preços **atuais** pelo `servicosParaCobrar` do Catálogo, nome da cliente só para a tela, se já tem checkout); `verCheckout` (resumo gravado) |
| `fechar.ts` | `fecharCheckout`: relê agendamento e preços; calcula total e confere pelo domínio; resumo SHA-256 (Web Crypto); grava checkout, itens e pagamentos na transação. Erros: `23505` na chave → mesmo resumo devolve o existente, outro → `conflito`; `23505` no índice parcial → `ja_tem_checkout`; soma → `soma_diferente`; dinheiro sem caixa → `abra_o_caixa`; status → `status_nao_permite`. Registro `checkout.fechado` (detalhes do `registro.ts`) |
| `*.test.ts` (2) | banco falso: estúdio, preço, total e caixa do pedido ignorados (CA-03); papel × ação (CA-10); mesma chave e mesmo conteúdo → mesmo resultado, outro → `conflito` (CA-05 no servidor); registro sem nome de cliente nem texto (marcador fictício, CA-11); idas ≤ teto (§6) |

### 5.4 `src/data/checkout/` e os encaixes que o Checkout troca (ADR 0017 · D9; ADR 0010 · D6)
| Arquivo | O que tem |
|---|---|
| `src/data/checkout/checkouts.ts` | gravar checkout, itens e pagamentos na transação da ação; ler por agendamento; ler um |
| `src/data/agendamento/checkout.ts` (**troca** o encaixe do Agendamento) | `temCheckoutFechado(id)` pela consulta real |
| `src/data/caixa/entradas-por-forma.ts` (**troca** o encaixe do Caixa) | soma por forma dos pagamentos do caixa |
| `src/data/caixa/atendimentos-sem-checkout.ts` (**troca** o encaixe do Caixa) | quantos agendamentos de hoje (fuso do estúdio) em Chegou, Iniciado ou Concluído sem checkout fechado; só o número (Caixa RF-08) |
| `src/data/checkout/exemplo-local.ts` | dados fictícios, escritos do zero, para o plano B (RF-16) |

### 5.5 `src/app/` (Engenheiro de software; desenho do Designer de produto na ficha visual, **antes** das telas)
- **Rota:** `src/app/routes/checkout.tsx` (`validateSearch` só `agendamento` uuid); no 390, tela sem barra com o botão do
  rodapé; no 1440, o painel de 480. Se a ficha escolher abrir dentro do painel do agendamento, muda
  `src/app/routes/agenda.tsx` (só o parâmetro `checkout`) em vez da rota própria.
- **Painel do agendamento:** `src/app/paginas/agendamento/painel.tsx` liga o botão "Checkout" (quem a E31·2 deixa) e o
  troca por "Ver checkout" depois de pago (`DESIGN.md` §6).
- **Telas** em `src/app/paginas/checkout/`: `revisar.tsx` (itens, "Adicionar" serviço, ⋮ para tirar, "Total ▴ valor"),
  `pagar.tsx` (linhas forma + valor, "Adicionar" forma, quanto falta à vista, "Pagar <valor>" ativo só com a soma igual),
  `concluido.tsx` (resumo; "Concluído, sem valor"; "Fechar"), `ver.tsx` (só leitura), `checkout.css` (só
  `var(--...)`), `checkout.test.tsx` (uma ação preta; estado com palavra; nenhum texto fixo fora dos idiomas; tela
  Pagar sem campo de preço).
- **Idiomas (RNF-04):** bloco `checkout` na base comum `src/app/i18n/{pt,es,en}.ts` da `feat/entrar-servico`, com os
  nomes das formas e o texto de cada código de erro. Os nomes que faltam no `DESIGN.md` §6 entram pela ficha.

## 6. Tetos
- Itens por conta: 20 (L-3); linhas de pagamento: 5; lista de serviços para "Adicionar": 50 por página (Catálogo).
- Idas ao banco: abrir ≤ 3 (agendamento e itens, preços, checkout existente); fechar ≤ 4 (agendamento, preços,
  transação, registro); ver ≤ 2.

## 7. Testes de tela (Playwright, projetos `celular` 390 e `computador` 1440)
| Arquivo | Prova |
|---|---|
| `e2e/preparo/checkout-dados.ts` | estúdios A e B, dona, recepção, profissional, cliente, serviços, agendamento em Chegou, caixa aberto; tudo fictício, banco **local** |
| `e2e/checkout.spec.ts` | CA-12: fechar com duas formas (dinheiro e cartão), erro de soma, "Ver checkout", Cancelar recusado depois de pago; dinheiro sem caixa → "abra o caixa"; profissional sem o botão; a URL só tem o id |
| `e2e/checkout-estados.spec.ts` | CA-13: vazio, carregando, erro, sucesso, "agendamento já tem checkout"; "em desenvolvimento" do plano B |
| `e2e/checkout-acessibilidade.spec.ts` | `AxeBuilder` nas 3 etapas e no "Ver checkout"; teclado |

## 8. Arquivos (lista FECHADA)
Fora desta lista nada muda (`AGENTS.md` §6). Arquivo que uma ferramenta crie fora daqui: parar e relatar.

**Banco (Engenheiro de dados):** `supabase/migrations/<ts>_checkouts.sql`, `<ts>_checkout_itens.sql`,
`<ts>_checkout_pagamentos.sql`, `<ts>_checkout_pagamento_caixa.sql`, `<ts>_checkout_regras.sql`,
`<ts>_checkout_politicas.sql` · `supabase/tests/database/600_checkout_isolamento_test.sql` a
`680_checkout_autor_test.sql` (9 arquivos, §4.6) · `docs/adr/0015-checkout-tabelas-do-antigo.md`.

**Domínio:** `src/domain/checkout/{tipos,regras,valores,acesso,registro,resumo}.ts` e
`{regras,valores,acesso,registro,resumo}.test.ts`.

**Servidor:** `src/server/checkout/{esquemas,ler,fechar}.ts` e `{ler,fechar}.test.ts` ·
`src/server/agendamento/consultas.ts` e `src/server/clientes/consultas.ts` (só se os planos de lá não os trouxerem, L-5;
só leitura, para outros módulos).

**Dados:** `src/data/checkout/{checkouts,exemplo-local}.ts` · `src/data/agendamento/checkout.ts` (troca) ·
`src/data/caixa/entradas-por-forma.ts` e `src/data/caixa/atendimentos-sem-checkout.ts` (troca).

**Telas:** `src/app/routes/checkout.tsx` (ou `src/app/routes/agenda.tsx`, só o parâmetro, conforme a ficha) ·
`src/app/routeTree.gen.ts` (gerado) · `src/app/paginas/agendamento/painel.tsx` (só o botão) ·
`src/app/paginas/checkout/{revisar,pagar,concluido,ver}.tsx` · `src/app/paginas/checkout/checkout.css` ·
`src/app/paginas/checkout/checkout.test.tsx` · `src/app/i18n/{pt,es,en}.ts` (só o bloco `checkout`).

**Testes de tela:** `e2e/preparo/checkout-dados.ts` · `e2e/checkout.spec.ts` · `e2e/checkout-estados.spec.ts` ·
`e2e/checkout-acessibilidade.spec.ts` · `e2e/agendamento.spec.ts` (só se ele conferir o "Checkout" desativado).

**Ficha visual (Designer de produto):** `specs/20261128-022500-checkout/ficha-visual.md` e `specs/20261128-022500-checkout/ficha/*.png`.

**Texto:** `DESIGN.md`, só as linhas aprovadas na ficha (avançar de Revisar para Pagar; nomes das formas) (Designer de
produto) · `docs/STATUS.md`, `docs/BACKLOG.md`, `CHANGELOG.md`, `docs/decisoes/2026-11-27-fundacao.md` (respostas E31 e
das lacunas) (Documentador).

**Processo:** `specs/20261128-022500-checkout/{spec.md,plan.md,tasks.md}`. O ADR 0017 chega pela `feat/caixa`.

**Intactos:** `src/app/ui/**`, `src/app/estilos/**`, `src/server/portas/**` e o cliente do banco (E36·A),
`src/domain/{catalogo,caixa,agendamento}/**` (reusados, não alterados), o resto de `src/server/{caixa,catalogo,agendamento}/**`
e de `src/data/{caixa,agendamento}/**`, as migrations e testes dos itens 2 e 3, da E36·A, do Caixa e dos outros módulos,
`supabase/config.jsonc`, `supabase/seed.sql`, `supabase/moldes/**`, `package.json`, `pnpm-lock.yaml` (nenhuma
dependência nova), `eslint.config.mjs`, `playwright.config.ts`, `.github/**`, `src/*/AGENTS.md`, `src/*/CLAUDE.md`,
`ARCHITECTURE.md`, `AGENTS.md`, `SECURITY.md`.

## 9. Branch (decisão do Engenheiro de DevOps)
`feat/checkout` recebe, **por merge**, nesta ordem: `feat/agendamento` (já com itens 2, 3, 4, a E36·A, Agenda, Clientes
e Catálogo) e `feat/caixa`; de novo sempre que elas ganharem commit. Fica **em cima** do Caixa (ADR 0017 · D1): o pedido
de merge do Checkout só depois do merge do Caixa e do Agendamento na `previas`, com a base do PR passada à `previas`.
PR de rascunho empilhado; nunca se junta numa base. Conflitos esperados: `routeTree.gen.ts` (regenera), arquivos de
idioma (soma de linhas), carimbo das migrations (o Engenheiro de dados regenera; as do Checkout sempre por último).

## 10. Critério → prova
| CA | Prova | Quem confere |
|---|---|---|
| CA-01 | `src/domain/checkout/*.test.ts`; pgTAP 610 | QA; Auditor de risco |
| CA-02 | `regras.test.ts`, `fechar.test.ts`, pgTAP 610 | QA; Auditor de risco |
| CA-02b | pgTAP 660; `src/server/agendamento` com o encaixe trocado | QA |
| CA-03 | `fechar.test.ts`; pgTAP 610 e 620 | Auditor de risco |
| CA-04 | `regras.test.ts`; pgTAP 610 | QA |
| CA-05 | pgTAP 630 e 650; `fechar.test.ts` | Engenheiro de dados revisor; Auditor de risco |
| CA-06, CA-09 | pgTAP 600 | QA; Engenheiro de segurança |
| CA-07 | pgTAP 620 | Auditor de risco |
| CA-08 | pgTAP 640 e 650; `fechar.test.ts` | Auditor de risco |
| CA-10 | pgTAP 670; `ler.test.ts`, `fechar.test.ts`; e2e (profissional sem botão) | Engenheiro de segurança |
| CA-11 | `fechar.test.ts` (registro sem texto); pgTAP 680; revisão da E6·1 sem contorno | Engenheiro de segurança; Auditor de risco |
| CA-12, CA-13 | e2e do §7 nos 2 projetos; checklist `DESIGN.md` §10 | QA; Revisor de design |
| CA-14 | ADR 0015 com cada linha do §4.1, conferência preenchida | Auditor de risco |
| CA-15 | histórico da CI; nenhum `supabase link`, `db push`, `--remote`, `--linked` | Auditor de risco |
| CA-16 | relatórios sem "Bloqueia"; veredito do QA; conferência do dono na prévia | Gerente de projeto |
| Escopo | `git diff --name-only <base>...HEAD` contra o §8 | Revisor de código |

## 11. Se o dono responder diferente
| Resposta | O que muda |
|---|---|
| **E31·1·B** | o gatilho da M4 recusa **qualquer** forma sem caixa aberto; `check (caixa_id is not null)`; testes 640, 650 |
| **E31·1·C** | sai a M4 inteira e os dois encaixes do Caixa ficam vazios; Caixa ajustado antes (spec de lá §9) |
| **E31·2·B** | criar também a profissional nos próprios atendimentos (política com o `profissional_id` do agendamento); teste 670 e e2e |
| **E31·3·B** | `check (total_centavos <= <teto>)` e a mesma constante no domínio; teste 610 |
| **E31·3·C** | `check (total_centavos > 0)`; sai `sem_valor`; Caixa RF-08 perde o caso; teste 610 |

## 12. Riscos e não verificado
- **Bloqueante para construir servidor e dados:** E36·A com transação por ação; Agendamento, Catálogo e Caixa na branch.
  Domínio e telas (plano B, RF-16) podem andar antes.
- **E6·1 à vista (risco aceito pelo dono):** no modo "entrar como o estúdio", o fechamento fica sem "quem fechou" e sem
  registro; o estúdio pode atribuir a uma funcionária um dinheiro recebido pelo suporte. Este plano não contorna: um ponto
  só (`app.autor_da_sessao()` e o registro da E36·A, ADR 0017 · D7). O estorno nesse modo é risco da spec seguinte (§12 da spec).
- **E24·3 em aberto:** preço lido na moeda atual do estúdio (L-4).
- **Não verificado:** `for share` no gatilho do checkout contra a troca de status do agendamento (o teste 650 prova); a
  regra "mesma transação" para itens e pagamentos (forma do Engenheiro de dados, por ex. comparar o id da transação que
  criou o checkout); gatilho de restrição adiado nas três tabelas com várias linhas; `dblink` na imagem local do
  Supabase CLI 3.4.0 (sem ele o teste 650 sai do pgTAP e volta à 5b); `crypto.subtle.digest` no Workers e no Node 26;
  nomes de `src/server/catalogo/consultas.ts`, `public.servicos`, `public.agendamentos` e `public.caixas` vêm dos planos
  (ainda não construídos); se mudarem, este plano se ajusta (nova 5b).
- Numeração: ADR 0015 e a faixa 6xx são deste módulo; o Documentador confere no PR.
