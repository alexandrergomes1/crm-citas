# Plano · Agendamento (núcleo, item 5 da fila): criar, remarcar, cancelar e mudar o status

- **Spec:** `specs/20261128-020500-agendamento/spec.md` (Draft; revisão 5b feita)
- **Escrito por:** Arquiteto de software · **Norma:** modelo C4 e ADR (mais Clean Architecture, Twelve-Factor, WCAG 2.2,
  OWASP ASVS 4.0.3 V4 e V11.1, boas práticas do Postgres e do Supabase) · **Revisão:** pendente (etapa 5 Analista de
  requisitos; 5b Gerente de projeto)
- **Funciona com as recomendações:** E26·1·B, E26·2·A, E26·3·A (Agenda), E27·1·A, E27·2·A. O que muda com outra: §12.
- **Decisões técnicas deste plano:** `docs/adr/0010-agendamento-gravacao-horario-e-desfazer.md`. **Decisões de banco:**
  `docs/adr/0009-agendamento-tabelas-do-antigo.md`, escrito pelo Engenheiro de dados na tarefa T3 (não neste plano).
- **Depende da spec "Entrar e camada de serviço" (E36·A, do dono):** login, sessão, as 6 portas e o registro (porta 6)
  vêm de lá, antes do núcleo. **Este plano não os constrói**; usa o contrato do §5.1.
- **Bases lidas em 28/11/2026 (só leitura, nada editado lá):**
  - item 2 (`chore/fundacao-tecnica`): `plan.md`, ADR 0002 e 0003, `package.json`, `eslint.config.mjs`, `src/`, `ci.yml`;
  - item 3 (`feat/banco-ligacao`): `plan.md`, ADR 0005, as 4 migrations (`estudios`, `membros`, `trava_por_estudio`,
    `politicas_base`), o molde `supabase/moldes/isolamento_tabela_test.sql` e o teste `010_base_estrutura_test.sql`
    (ele exige que `authenticated` execute **só** as funções listadas em `public` e `app`, §4.6);
  - item 4 (`feat/design-system-codigo`): `plan.md`, ADR 0004, `src/app/ui/*` (botao, camadas, campos, contador,
    estados, estrutura, etiqueta-status, icone, seletor, bloco-lista, conteudo);
  - Agenda (`feat/agenda`): `plan.md`, `tasks.md`, ADR 0006 (idiomas em `src/app/i18n/`, dia do estúdio por `Intl`, tetos);
  - Clientes (`feat/clientes`): `plan.md` (`unique (org_id, id)` em `clientes`; `app.cliente_visivel` a substituir;
    `ultima_visita` mantida pelo Agendamento; `adicionarCliente` serve à E27·1·A);
  - Catálogo (`feat/catalogo`): `spec.md` (RF-02: a duração gravada no agendamento não muda; RF-08: leitura dos serviços
    ativos pela camada de serviço), `plan.md` e ADR 0012 (`public.servicos` com `unique (org_id, id)`, alvo das chaves
    compostas do Agendamento; `servicosAtivosParaAgendar` em `src/server/catalogo/consultas.ts`; com E30·3·B,
    `public.servicos_profissionais`);
  - Checkout (`feat/checkout`): `spec.md` RF-17 e CA-02b (com checkout Pago ou Sem valor, nada vai a Cancelado nem Ausência).
- **Conferido na documentação oficial (28/11/2026):** Postgres 17 `btree_gist` (traz classe de operador GiST para
  `uuid`; extensão "trusted"); `CREATE TABLE ... EXCLUDE ... WHERE (predicado)`; código `23P01` (`exclusion_violation`);
  `pg_advisory_xact_lock`. Supabase "Extensions": `btree_gist` e `dblink` estão na lista do Supabase; instalar com
  `create extension ... with schema extensions`. **Não verificado no banco local** (§13).
- **Antigo** (E22·B, só leitura, nada copiado): `20260601000005_appointments.sql`, `20260614_002_agenda_atomic_appointment_rpcs.sql`,
  `20261030220000_appointment_status_arrived.sql` (a spec §7 cita os dois últimos).

## 1. Resumo (C4)
**Contexto:** dona, recepção e profissional; nenhum sistema externo novo (avisos à cliente ficam fora, spec §12).
**Contêiner:** o app (TanStack Start) e o banco (Postgres do Supabase). Nada novo.
**Componentes (fluxo de "Salvar" na etapa 4):**

```
src/app/paginas/agendamento/*  (etapas, painel, remarcar, status)
   │ chama (corpo do pedido; na URL só o id do agendamento)
   ▼
src/server/agendamento/acoes.ts ── 6 portas da spec Entrar (E36·A): quem é · estúdio da sessão · papel · esquema ·
   │                               banco com trava, um pedido de gravação · registro pelo gatilho
   ├─► src/domain/agendamento/*  (status e transições, horário e fuso, acesso)  ─► reusa src/domain/agenda/{dia,bloqueio}.ts
   ├─► src/server/catalogo (serviços ativos e duração) · src/server/clientes (busca, adicionarCliente) · src/server/agenda (colunas)
   ▼
src/data/agendamento/*  ──►  public.agendamentos · public.agendamento_itens · public.agendamento_historico  (RLS)
                             gatilhos: transições, conflito com bloqueio, duração do Catálogo, histórico, última visita
                             exclusão GiST: dois agendamentos da mesma profissional nunca se cruzam
```

A Agenda passa a ler os agendamentos do dia (sua 4ª ida ao banco, ADR 0006 · D3) e a abrir o Novo agendamento e o painel.

## 2. Lacunas para o Analista de requisitos (a spec não cobre; não decido, `AGENTS.md` §4)
- **L-1 · Agendamentos na grade da Agenda.** O plano da Agenda (§5.5) deixa para esta spec "a leitura dos agendamentos"
  e ligar "Novo agendamento", "Agendar" e o toque no cartão. A spec do Agendamento não lista isso. **Recomendo** incluir
  (arquivos no §10, marcados "Agenda"); sem isso o CA-08 não se prova (o painel abre pelo cartão).
- **L-2 · E27·2·B "entra depois sem mudar os dados" não vale** com a garantia no banco (RNF-02): o encaixe pede uma
  coluna nova (`encaixe`) e mudar a exclusão e o gatilho (§12). **Recomendo** corrigir o texto da recomendação antes de ir
  ao dono; a recomendação A não muda.
- **L-3 · Quanto tempo o "Desfazer" fica à vista.** O `DESIGN.md` não diz a duração do aviso. O servidor e o banco só
  aceitam desfazer a **última** troca da **mesma pessoa** (ADR 0010 · D3), sem prazo. A duração vai à ficha visual (etapa 6).
- **L-4 · Cliente arquivada.** A spec não diz se se agenda cliente arquivada. **Recomendo:** a busca da etapa 1 mostra só
  as ativas (a lista padrão de Clientes); o banco recusa só cliente apagada (sem nome).
- **L-5 · Hora que não existe ou que se repete no dia da troca de horário** (CA-03). **Resolvida pelo Analista** (RF-17
  e Assumption 9 da spec): hora que não existe é recusada com mensagem; hora repetida fica com a primeira (ADR 0010 · D2).
- **L-6 (só texto):** o cabeçalho diz "Branch: `feat/agendamento` (a partir da `previas`)", mas ela é empilhada (§11).

## 3. Dúvidas em aberto: o plano usa a recomendação
Cada resposta vira uma constante em `src/domain/agendamento/acesso.ts` e **uma** versão das políticas; nada de chave de
liga e desliga (como o ADR 0006 · D6). O que muda com outra resposta está no §12.

## 4. Banco (tipo Banco; quem decide é o Engenheiro de dados, ADR 0009)

### 4.1 Decisão por tabela do antigo · **Engenheiro de dados decide na T3** (ADR 0009, conferido por outra instância)
Sugestões do Arquiteto por cima das do Analista (spec §7). Nada se copia: "reescrever" é mesma intenção, código novo.

| Antigo | Sugestão | Motivo |
|---|---|---|
| `appointments` | **reescrever** como `public.agendamentos` (§4.3) | concordo com a spec; também saem `client_name`, `staff_name` (copiados, dado pessoal duplicado), dinheiro (Checkout), recorrência, cor, ficha |
| `appointment_items` | **reescrever** como `public.agendamento_itens` | só serviço, ordem e duração (copiada do Catálogo pelo banco, Catálogo RF-02) |
| `appointment_status_history` | **reescrever** como `public.agendamento_historico` | RF-09, sem `changed_by_name` |
| `appointment_counters` | **descartar** (v1) | concordo com a spec |
| `appointment_deposits` | **descartar** nesta spec | concordo (E21·3) |
| funções `agenda_status_transition_allowed`, `agenda_assert_slot_available`, `create_appointment_atomic` (e as de alterar) | **descartar** | recebem `p_org_id` do pedido (o item 3 RF-03 proíbe), copiam nome de cliente e de profissional, ficam em `public` (exposto). A **ideia** do antigo (trava por profissional antes de conferir o horário) volta reescrita no §4.4 |

### 4.2 Migrations (com `pnpm exec supabase migration new <nome>`; carimbo depois das bases empilhadas)
| # | Nome | Conteúdo (sugestão; forma final do Engenheiro de dados) |
|---|---|---|
| M1 | `agendamento_extensoes` | `create extension if not exists btree_gist with schema extensions` (no `extensions`, não em `public`: o teste `010_` conta funções de `public`) |
| M2 | `agendamentos` | tabela §4.3, exclusão, índices, `enable` e `force row level security`, `revoke all` de `anon` e `authenticated` |
| M3 | `agendamento_itens` | idem |
| M4 | `agendamento_historico` | idem |
| M5 | `agendamento_regras` | funções de gatilho e gatilhos do §4.4, também em `public.bloqueios` (Agenda); `create or replace` de `app.cliente_visivel` (Clientes); o gatilho genérico de registro `app.registrar_mudanca()` (spec Entrar, ADR 0018 · D7) nas 3 tabelas, pelo molde do ADR 0019 |
| M6 | `agendamento_politicas` | políticas e privilégios por coluna do §4.5 |
| M7 | `agendamento_criar` | a função `public.agendamento_criar` do §4.5a |

### 4.3 Tabelas (sugestão)
`S` = `org_id = (select app.estudio_da_sessao())`; `P` = `(select app.papel_da_sessao())`; `U` = `(select auth.uid())`.

**`public.agendamentos`**
| Coluna | Tipo e regra |
|---|---|
| `id` | `uuid primary key default gen_random_uuid()`; mais `unique (org_id, id)` (alvo das ligações compostas, também do Checkout) |
| `org_id` | `uuid not null default app.estudio_da_sessao() references public.estudios (org_id) on delete cascade`; sem privilégio de gravação (como Clientes D7) |
| `profissional_id` | `uuid not null`; `foreign key (org_id, profissional_id) references public.membros (org_id, user_id)` |
| `cliente_id` | `uuid not null`; `foreign key (org_id, cliente_id) references public.clientes (org_id, id)` |
| `inicio`, `fim` | `timestamptz not null`; `check (fim > inicio)`; `check (fim - inicio <= interval '24 hours')` (ADR 0010 · D4) |
| `status` | `text not null default 'reservado'`, `check (status in ('reservado','confirmado','chegou','iniciado','concluido','ausencia','cancelado'))` |
| `criado_por` | `uuid not null default auth.uid()`; `criado_em timestamptz not null default now()` |

- **Conflito no banco (RF-04, RNF-02, CA-04):** `exclude using gist (org_id with =, profissional_id with =,
  tstzrange(inicio, fim, '[)') with &&) where (status not in ('cancelado','ausencia'))`. Encostar não cruza (`[)`);
  Cancelado e Ausência não ocupam; dois pedidos ao mesmo tempo: o segundo espera o primeiro e recebe `23P01`
  (a exclusão funciona como o `unique` sob concorrência, doc do Postgres). Precisa de `btree_gist` para o `uuid with =`.
- As ligações compostas a membro e cliente usam `NO ACTION` (conferido no fim do comando): apagar o estúdio leva tudo
  em cascata pelo `org_id`; apagar um membro ou uma cliente com agendamento é recusado (o histórico fica). A ligação do
  item ao serviço é `on delete restrict` (abaixo): serviço já agendado não se exclui (o Catálogo oferece Arquivar).
- **Índices:** `(org_id, inicio)` (dia da Agenda), `(org_id, profissional_id, inicio)` (ocupados), `(org_id, cliente_id,
  inicio desc)` (atendimentos da cliente e `cliente_visivel`); o índice da exclusão.

**`public.agendamento_itens`**: `org_id uuid not null`, `agendamento_id uuid not null`, `ordem smallint not null check
(ordem between 1 and 10)` (ADR 0010 · D4), `servico_id uuid not null`, `duracao_min int not null`, `primary key (org_id,
agendamento_id, ordem)`; `foreign key (org_id, agendamento_id) references public.agendamentos (org_id, id) on delete
cascade`; `foreign key (org_id, servico_id) references public.servicos (org_id, id) on delete restrict` (o `unique (org_id, id)`
já está no plano do Catálogo; `restrict` casa com o `23503` → `servico_em_uso` de lá). `duracao_min` é **gravada pelo gatilho** a partir do Catálogo, nunca pelo pedido.

**`public.agendamento_historico`**: `id uuid primary key default gen_random_uuid()`, `org_id uuid not null`,
`agendamento_id uuid not null` (ligação composta como acima, `on delete cascade`), `de text null` (nulo na criação),
`para text not null`, `origem text not null check (origem in ('criacao','troca','remarcacao','desfazer'))`, `por uuid not
null default auth.uid()`, `em timestamptz not null default now()`; índice `(org_id, agendamento_id, em desc)`. Sem nome.
Escrito só pelo gatilho (RF-09). Não é a auditoria (porta 6, spec Entrar).

### 4.4 Regras no banco (M5; todas `security definer`, `set search_path = ''`, nomes qualificados, `revoke all ... from public, anon, authenticated`)
| Gatilho | Regra | Requisito |
|---|---|---|
| `before insert` em `agendamentos` | nasce `reservado`; `inicio >= now()`; a profissional é membro **ativo** com papel `dona` ou `profissional` (E26·3·A); cliente não apagada (L-4) | RF-01, RF-03, RF-07, RF-13 |
| `before update` em `agendamentos` | **troca de status** só pela tabela do RF-07; **desfazer** = o inverso exato da última linha do histórico com `origem = 'troca'`, feita por `U`, e nunca saindo de Cancelado ou Ausência (ADR 0010 · D3); **remarcar** (mudou `inicio`, `fim` ou `profissional_id`) só de `reservado` ou `confirmado`, põe `reservado`, confere `inicio >= now()` e a profissional como no insert; mudar status e horário no mesmo comando: recusado | RF-05, RF-07, RF-08, RF-13 |
| `before insert` em `agendamento_itens` | copia `duracao_min` do serviço do Catálogo (ativo, mesmo estúdio); recusa serviço arquivado | RF-02, RF-03 |
| `constraint trigger ... deferrable initially deferred` em `agendamentos` e `agendamento_itens` | no fim da transação: pelo menos 1 item e `fim = inicio + soma(duracao_min)` | RF-02 |
| `after insert or update of status, inicio, fim, profissional_id` em `agendamentos` | grava a linha do histórico (`criacao`, `troca`, `remarcacao` ou `desfazer`) | RF-09, CA-07 |
| conflito **agendamento × bloqueio**, nas duas direções (gatilho em `agendamentos` e em `public.bloqueios` da Agenda) | trava a linha da profissional em `public.membros` (`for no key update`, não bloqueia a conferência das chaves estrangeiras) **ou** `pg_advisory_xact_lock` por estúdio e profissional; depois procura cruzamento `[)` na outra tabela (só agendamentos que ocupam); achou → `raise ... using errcode = '23P01'` (o servidor da Agenda já traduz esse código para `conflito`) | RF-04, RNF-02 |
| `after insert or update of status` em `agendamentos` | quando o status entra ou sai de `concluido`, refaz `clientes.ultima_visita` (data do último Concluído no fuso de `estudios.fuso_horario`) | Clientes RF-08, plano dele §3.5 |
| `create or replace function app.cliente_visivel(p_cliente uuid)` | soma, para a profissional, "tem ou teve agendamento com ela" (`profissional_id = U`) ao que Clientes já dá | Clientes E28·2·B |

- A trava da segunda linha só funciona no nível de isolamento padrão (READ COMMITTED: cada comando da função vê o que
  já foi gravado). Se a camada de serviço usar outro nível, o teste `agendamento_240` acusa.
- **RF-17 (Checkout):** a tabela do checkout nasce na spec do Checkout, depois desta. **A trava no banco é dela** (gatilho
  `before update of status` em `agendamentos`, na migration do Checkout). Aqui fica só o ponto de encaixe do servidor (§5.3).

### 4.5 Travas RLS e privilégios (M6; toda política `to authenticated`)
| Tabela | Ler | Criar | Alterar | Apagar | Privilégio de `authenticated` |
|---|---|---|---|---|---|
| `agendamentos` | `S` (E26·1·B: a profissional vê a linha das outras para "ocupado"; o servidor tira cliente e serviço, §5.3) | with check `S and (P in ('dona','recepcao') or (P = 'profissional' and profissional_id = U))` (E26·2·A) | using e with check iguais ao criar | ninguém (cancelar é status) | `select`; `insert (profissional_id, cliente_id, inicio, fim)`; `update (profissional_id, inicio, fim, status)` |
| `agendamento_itens` | `S and (P <> 'profissional' or` o agendamento é dela`)` | with check: o agendamento é do estúdio, ainda `reservado` e gravável por quem pede (mesma regra) | ninguém (v1) | ninguém | `select`; `insert (agendamento_id, ordem, servico_id)` |
| `agendamento_historico` | como os itens | ninguém (só o gatilho) | ninguém | ninguém | `select` |

- Os gatilhos não pedem `execute` de quem grava; a única função nova executável por `authenticated` é a do §4.5a.
- `insert ... returning` exige passar também na política de leitura (Postgres): vale para os três papéis aqui.

### 4.5a Função de criar (M7; ADR 0010 · D1, revisto pelo contrato da spec Entrar)
Na Data API um pedido é uma transação, e a ação pode fazer **um** pedido de gravação (ADR 0018 · D3). Criar grava
agendamento e itens, então usa `public.agendamento_criar(p_cliente uuid, p_profissional uuid, p_inicio timestamptz,
p_fim timestamptz, p_servicos uuid[]) returns uuid`: `language plpgsql`, **`security invoker`**, `set search_path = ''`,
nomes qualificados; insere o agendamento (o `org_id` vem do valor padrão da sessão; **nenhum parâmetro de estúdio**) e um
item por serviço, na ordem do vetor (1 a 10, senão `22023`); devolve o id. RLS e privilégios por coluna valem lá dentro
(é a pessoa que grava); os gatilhos do §4.4 também. `revoke all ... from public, anon`; `grant execute ... to
authenticated`. Entra na lista de funções do `010_base_estrutura_test.sql` (que a spec Entrar já transforma em lista;
ADR 0019). Remarcar, trocar status e desfazer são **um** `update` de `agendamentos` cada: sem função.

### 4.6 Testes pgTAP (`supabase/tests/database/`, banco local, `pnpm db:test`; dados fictícios escritos do zero, RG-07)
| Arquivo | Prova |
|---|---|
| `agendamento_200_isolamento_test.sql` | molde do item 3 para as 3 tabelas: A não lê, cria, altera nem apaga de B; sem papel e sem login, nada; profissional, cliente ou serviço de B num agendamento de A recusado pela ligação composta (CA-05) |
| `agendamento_210_regras_test.sql` | nasce `reservado`; status de fora recusado; início no passado recusado; `duracao_min` do pedido ignorada (vem do Catálogo); fim ≠ início + soma recusado no `commit` (com `set constraints all immediate`); sem item recusado; 11 itens e mais de 24 h recusados; recepção não é profissional; cliente apagada recusada (RF-01 a RF-03, RF-13) |
| `agendamento_220_transicoes_test.sql` | cada par de status: os 10 da tabela do RF-07 aceitos, os outros 39 (inclui "para o mesmo") recusados; desfazer só da última troca e só pela mesma pessoa; desfazer saindo de Cancelado ou Ausência recusado; remarcar em Chegou recusado; remarcar Confirmado volta a Reservado (CA-01 no banco, RF-05, RF-08) |
| `agendamento_230_conflito_test.sql` | cruzar recusado (`23P01`); encostar aceito; Cancelado e Ausência não ocupam; bloqueio ocupa agendamento e agendamento ocupa bloqueio; remarcar ignora o próprio; outra profissional no mesmo horário aceita (CA-02 no banco) |
| `agendamento_240_concorrencia_test.sql` | duas ligações de verdade pela extensão `dblink` (criada só dentro do teste, no esquema `extensions`): a primeira grava sem confirmar, a segunda espera e, depois do `commit` da primeira, recebe `23P01`; o mesmo para agendamento × bloqueio. Limpa o que as ligações confirmaram (CA-04, RNF-02) |
| `agendamento_250_papeis_test.sql` | E26·2·A: dona e recepção em qualquer profissional; profissional só nos próprios (criar, remarcar, status), não passa o agendamento para outra; E26·1·B: profissional lê a linha das outras, mas não os itens nem o histórico delas; `cliente_visivel` substituída (CA-06) |
| `agendamento_260_historico_test.sql` | criar, cada troca, remarcar e desfazer geram uma linha cada, com `por` = quem gravou; ninguém com login grava ou altera o histórico; `ultima_visita` igual à regra de `src/domain/clientes/ultima-visita.ts` (mesmos casos, inclusive troca de horário) (CA-07, RF-09) |
| `agendamento_270_criar_test.sql` | `agendamento_criar` é `security invoker` com `search_path` vazio; `anon` e `public` sem `execute`; grava agendamento e itens juntos ou nada (serviço de outro estúdio no meio do vetor → nada gravado); profissional não cria para outra pela função (a RLS vale); 0 e 11 serviços recusados (CA-04, CA-05, CA-06) |
| `agendamento_280_registro_test.sql` | pelo molde `supabase/moldes/registro_tabela_test.sql` (spec Entrar) nas 3 tabelas: cada gravação gera uma linha de registro com o nome da ação, sem dado pessoal; falha do registro desfaz a gravação (RF-10, CA-07) |

O `010_base_estrutura_test.sql` (item 3, já em lista pela spec Entrar) passa a valer para as 3 tabelas novas (org_id,
RLS forçada, índice por `org_id`, nenhum privilégio de `anon`) e **ganha uma linha**: `public.agendamento_criar(...)`
na lista do que `authenticated` executa. Prova de que os testes pegam erro: numa cópia local, tirar o `where` da exclusão
ou o `S` de uma política e ver o teste ficar vermelho; desfazer.

## 5. Código por camada (regra de dependência do `ARCHITECTURE.md` §3, já travada pelo lint do item 2)

### 5.1 Contrato que o Agendamento usa da spec "Entrar e camada de serviço" (E36·A)
Contrato fixado pela spec Entrar (`feat/entrar-servico`, plano §4, ADR 0018). O Agendamento **não** escreve portas,
sessão nem registro. Cada ação é `acao({ nome, metodo, sessao: 'estudio', permissao, entrada, grava, trabalho })` de
`src/server/portas/acao.ts`, que devolve `{ ok: true, valor } | { ok: false, codigo }`. O `trabalho` recebe
`ctx` (`usuarioId`, `orgId`, `papel`, `idioma`, `fuso`, `moeda`, `banco`) e pode fazer **no máximo um pedido de
gravação** por `ctx.banco` (o segundo é recusado). `permissao` é a regra pura de `src/domain/agendamento/acesso.ts`;
`entrada` é `z.strictObject` (campo a mais → `entrada_invalida`, ADR 0018 · D13). O registro (porta 6) é feito pelo
gatilho genérico em cada tabela, com o nome da ação vindo do cabeçalho `x-acao` (ADR 0018 · D7).
- **Códigos de erro:** só a lista fechada do contrato (`sem_login`, `estudio_trocado`, `sem_estudio`, `sem_permissao`,
  `entrada_invalida`, `conflito`, `limite`, `erro_interno`); `23P01` vira `conflito` em `src/data/erros.ts` (Entrar).
- **Recusas de regra** que a tela precisa explicar não são erro do contrato: voltam em `valor` como `{ feito: false,
  motivo }`, com `motivo` em `'hora_inexistente' | 'passado' | 'troca_invalida' | 'nao_remarca' | 'tem_checkout'`
  (lista em `src/domain/agendamento/tipos.ts`; texto nos idiomas). Recusa do gatilho numa corrida (outra pessoa trocou o
  status no meio) sai `erro_interno` e a tela oferece "Tentar de novo" (ADR 0010, Consequências).

### 5.2 `src/domain/agendamento/` (TypeScript puro, com teste; Engenheiro de software)
| Arquivo | O que tem | Requisitos |
|---|---|---|
| `tipos.ts` | `Status` (os 7), `Agendamento`, `Item`, `Troca` (de, para, origem, por) | — |
| `status.ts` | tabela de transições; finais; `podeTrocar(de, para, { temCheckoutFechado })` (Cancelado e Ausência recusados com checkout fechado, RF-17); `podeDesfazer(ultimaTroca, quem, statusAtual)`; `podeRemarcar(status)` e o status depois de remarcar; o que pede janelinha (Cancelado, Ausência) e o que tem "Desfazer" | RF-05, RF-07, RF-08, Checkout RF-17 |
| `horario.ts` | data e hora local → instante no fuso do estúdio (ADR 0010 · D2, sobre `src/domain/agenda/dia.ts`): hora que não existe → `hora_inexistente`; hora repetida → a primeira; fim = início + soma das durações em minutos corridos; início no passado (o "agora" chega por parâmetro); conflito pela **mesma** regra de `src/domain/agenda/bloqueio.ts` (ADR 0010 · D5); tetos de 10 serviços e 24 h | RF-02, RF-04, RF-12, RF-13, RF-17 |
| `acesso.ts` | quem cria, remarca e troca status (E26·2·A); o que sai do painel e da grade para a profissional em agendamento de outra (E26·1·B: só "ocupado"; a regra da grade continua em `src/domain/agenda/acesso.ts`) | RF-11 |

- Testes obrigatórios: `status.test.ts` com os 49 pares (CA-01) e os casos de desfazer, remarcar e RF-17;
  `horario.test.ts` com `Europe/Lisbon` em 29/03/2026 (01:30 não existe → recusada com `hora_inexistente`; serviço de 120 min às
  00:30 termina às 03:30) e 25/10/2026 (01:30 duas vezes → a primeira), `America/New_York` em 08/03/2026 e 01/11/2026, encostar, Cancelado
  e Ausência, remarcar ignora o próprio, passado por 1 s (CA-02, CA-03); `acesso.test.ts` papel × ação (CA-06).

### 5.3 `src/server/agendamento/` (Engenheiro de software)
| Arquivo | O que tem |
|---|---|
| `esquemas.ts` | `z.strictObject` para: criar (cliente `uuid`, 1 a 10 serviços `uuid`, profissional `uuid`, data `AAAA-MM-DD`, hora `HH:MM` em passos de 15 min), remarcar (id, profissional, data, hora), trocar status (id, para), desfazer (id, id da troca), ver (id). **Sem estúdio, sem fim, sem duração** (vêm da sessão e do Catálogo); campo a mais → `entrada_invalida` |
| `acoes.ts` | por `acao(...)`: `agendamento.criar` (`POST`, grava: **um** pedido, a função `agendamento_criar`), `agendamento.remarcar`, `agendamento.status.trocar`, `agendamento.status.desfazer` (`POST`, grava: **um** `update` cada), `agendamento.ver` (`GET`). Serviços ativos e durações pela leitura do Catálogo (`servicosAtivosParaAgendar`, pelo servidor); conferência pelo domínio com os ocupados da profissional naquele intervalo; recusas de regra em `valor` (§5.1); RF-17 por `src/data/agendamento/checkout.ts`. O registro é o gatilho genérico, com o nome da ação; nada de nome, telefone ou texto (RF-10) |
| `acoes.test.ts` | com o banco trocado por um falso: estúdio no pedido ignorado; sem login e sem papel nada; profissional não grava na de outra (E26·2·A); profissional não recebe cliente nem serviço de agendamento alheio (E26·1·B); fim e duração do pedido ignorados; conflito vira código sem dado; registro e erro sem nome, telefone ou texto (CA-07, CA-10); idas ao banco dentro do teto (ADR 0010 · D4) |

Cliente nova na etapa 1 (E27·1·A) chama a ação `adicionarCliente` de **Clientes** (plano dela, RF-09): nenhuma regra de
cliente repetida aqui. A busca da etapa 1 usa `listarClientes` de Clientes; a lista de profissionais, as colunas da Agenda.

### 5.4 `src/data/agendamento/` (Engenheiro de software; consultas conferidas pelo Engenheiro de dados)
| Arquivo | O que tem |
|---|---|
| `agendamentos.ts` | criar pela função `agendamento_criar` (um pedido); ler um por id (com itens e última troca); ocupados de uma profissional num intervalo; trocar status; remarcar. Nenhum filtro por `org_id` vindo de fora: a RLS decide |
| `checkout.ts` | `temCheckoutFechado(id)`: devolve "não" até a spec do Checkout trocar este arquivo pela consulta real (encaixe do RF-17) |
| `exemplo-local.ts` | dados fictícios, escritos do zero, só para o teste de tela enquanto Clientes ou Catálogo não existem (RF-15, CA-13) |

Leitura dos agendamentos do dia para a grade: **`src/data/agenda/agendamentos.ts`** (Agenda, L-1), chamada por
`src/server/agenda/ler-dia.ts` como 4ª ida, dentro do teto de 500 itens (ADR 0006 · D3).

### 5.5 `src/app/` (Engenheiro de software; desenho do Designer de produto na ficha visual)
- **Rotas:** `src/app/routes/agendar.tsx` (as 4 etapas; no 390, tela sem barra com ‹ e "Salvar"; no 1440, o painel de
  480 sobre a Agenda); `src/app/routes/agenda.tsx` aceita também `agendamento=<uuid>` (abre o painel; L-1). Na URL **só**
  o id; cliente buscada, serviços e etapa ficam na memória da tela (RNF-04, CA-10).
- **Telas** em `src/app/paginas/agendamento/`, só com componentes do item 4 e as peças que o dono aprovar na ficha:

| Arquivo | O que tem |
|---|---|
| `novo.tsx` | as 4 etapas e o rodapé; voltar uma etapa; estados de cada etapa (vazio, sem resultado, carregando, erro, sucesso) |
| `etapa-cliente.tsx` | "Buscar cliente" (paginada), "Adicionar cliente" de contorno com nome e telefone (E27·1·A); "em desenvolvimento" sem Clientes |
| `etapa-servicos.tsx` | serviços ativos do Catálogo, soma da duração; "Ainda não há serviços" ou "em desenvolvimento" |
| `etapa-horario.tsx` | profissional, data, hora em passos de 15 min |
| `etapa-conferencia.tsx` | resumo com início e fim no fuso do estúdio e "Salvar"; conflito: "horário ocupado", sem nome |
| `painel.tsx` | painel do agendamento: botão de status "ícone + nome ▾", ⋮ com remarcar e "Cancelar agendamento", "Checkout" desativado com "em desenvolvimento" |
| `status.tsx` | menu de status com as trocas permitidas; janelinha para Cancelado e Ausência; aviso com "Desfazer" nas outras |
| `remarcar.tsx` | profissional, data, hora; "Salvar" e "Cancelar" |
| `agendamento.css` | só `var(--...)` do `tokens.css` |
| `agendamento.test.tsx` | `renderToString`: uma só ação preta; status com ícone e nome acessível; nenhum texto fixo fora dos idiomas |

- **Agenda (L-1):** `src/app/paginas/agenda/{agenda,barra,cartao}.tsx` e `src/app/navegacao.ts` trocam o "em
  desenvolvimento" de "Novo agendamento", "Agendar" e do toque no cartão pela abertura real.
- **Idiomas (RNF-05):** chaves `agendamento.*` em `src/app/i18n/{pt,es,en}.ts`, a base comum que nasce na
  `feat/entrar-servico` (molde do ADR 0006 · D1; Agenda e Clientes usam a mesma; ADR 0010 · D8); códigos de erro do
  servidor (inclui `hora_inexistente`, RF-17) viram texto ali; datas e horas por `src/app/i18n/formatar.ts` no fuso do
  estúdio. O teste `src/app/i18n/i18n.test.ts` da base confere as três (mesmas chaves, nenhuma vazia, mesmos marcadores).
- Os nomes que faltam no `DESIGN.md` §6 (botão de avançar etapa, ação de remarcar no ⋮) entram pela ficha (etapa 6), nunca na construção.

## 6. Testes de tela (Playwright, projetos `celular` 390 e `computador` 1440 do item 2)
Dados só fictícios, criados no banco **local** pelo preparo; a sessão de teste vem da spec Entrar.

| Arquivo | Prova |
|---|---|
| `e2e/preparo/agendamento-dados.ts` | cria e apaga estúdios A e B, dona, recepção, duas profissionais, clientes e serviços inventados, um bloqueio |
| `e2e/agendamento.spec.ts` | CA-08: criar nas 4 etapas (inclui cliente nova), remarcar, trocar status com "Desfazer", cancelar com a janelinha, erro de conflito (sem nome de cliente); profissional sem ⋮ em agendamento alheio. CA-10: a URL só tem o id; nome e telefone fictícios marcados não aparecem na URL nem no console |
| `e2e/agendamento-estados.spec.ts` | CA-09 e CA-13: carregando (resposta atrasada por `page.route`), vazio, sem resultado, erro (500 por `page.route`), sucesso; "em desenvolvimento" com o adaptador `exemplo-local.ts` |
| `e2e/agendamento-acessibilidade.spec.ts` | `AxeBuilder` com `wcag2a`, `wcag2aa`, `wcag21a`, `wcag21aa`, `wcag22aa` (como o item 4) nas 4 etapas, no painel, no menu de status e na janelinha; teclado; status com nome acessível (RNF-01) |

## 7. Critério → prova
| CA | Prova | Quem confere |
|---|---|---|
| CA-01 | `status.test.ts` (49 pares) e pgTAP 220 | QA |
| CA-02 | `horario.test.ts` e pgTAP 230 | QA; Engenheiro de dados revisor |
| CA-03 | `horario.test.ts` (fusos, troca de horário, passado) | QA |
| CA-04 | pgTAP 240 (duas ligações de verdade) | Engenheiro de dados revisor; Auditor de risco |
| CA-05 | pgTAP 200 | QA; Engenheiro de segurança |
| CA-06 | pgTAP 250, `acoes.test.ts`, `acesso.test.ts` | Engenheiro de segurança |
| CA-07 | pgTAP 260 e `acoes.test.ts` (registro) | QA |
| CA-08, CA-09, CA-13 | e2e do §6 verdes nos 2 projetos; checklist `DESIGN.md` §10 | QA; Revisor de design |
| CA-10 | `acoes.test.ts`, `e2e/agendamento.spec.ts` e revisão | Engenheiro de segurança |
| CA-11 | ADR 0009 com as 5 tabelas e as funções do §4.1, conferência preenchida | Auditor de risco |
| CA-12 | histórico da CI; nenhum `supabase link`, `db push`, `--remote`, `--linked` | Auditor de risco |
| CA-14 | relatórios sem "Bloqueia"; veredito do QA; conferência do dono na prévia | Gerente de projeto |
| Escopo | `git diff --name-only <base>...HEAD` contra o §10 | Revisor de código |

## 8. Papéis
| Etapa | Papel |
|---|---|
| Branch empilhada (T1) | Engenheiro de DevOps |
| Ficha visual, nomes que faltam no `DESIGN.md`, textos es e en (T2) | Designer de produto; confere o Revisor de design; aprova o dono |
| Decisão por tabela (ADR 0009), migrations, pgTAP (T3 a T5) | Engenheiro de dados |
| Domínio, servidor, dados, telas, idiomas, e2e (T6 a T16) | Engenheiro de software |
| Revisar código | Revisor de código |
| Revisar banco e conferir o ADR 0009 item por item (E16·1) | Engenheiro de dados (outra instância) e Auditor de risco |
| Revisar acesso e privacidade (E26, CA-06, CA-10) | Engenheiro de segurança e Auditor de risco |
| Revisar a tela | Revisor de design |
| Veredito CA-01 a CA-14 | Analista de qualidade (QA) |
| Conferir o pedido · registros · pedido de merge | Analista de requisitos · Documentador · Gerente de projeto |

## 9. Ordem de construção
Fase banco só com as tabelas de Clientes e do Catálogo na branch (ligações compostas; **sem** versão provisória sem
chave). Fase servidor e dados só com a spec Entrar na branch. Domínio e telas (com o plano B do RF-15) podem andar antes.

## 10. Arquivos (lista FECHADA)
Fora desta lista nada muda (`AGENTS.md` §6). Arquivo que uma ferramenta crie fora daqui: parar e relatar.

**Banco (Engenheiro de dados):** `supabase/migrations/<ts>_agendamento_extensoes.sql`, `<ts>_agendamentos.sql`,
`<ts>_agendamento_itens.sql`, `<ts>_agendamento_historico.sql`, `<ts>_agendamento_regras.sql`,
`<ts>_agendamento_politicas.sql`, `<ts>_agendamento_criar.sql` · `supabase/tests/database/agendamento_200_isolamento_test.sql` a
`agendamento_280_registro_test.sql` (9 arquivos, §4.6) · `supabase/tests/database/010_base_estrutura_test.sql` (**só**
a linha de `public.agendamento_criar` na lista de funções) · `docs/adr/0009-agendamento-tabelas-do-antigo.md`.

**Domínio:** `src/domain/agendamento/{tipos,status,horario,acesso}.ts` e `{status,horario,acesso}.test.ts`.

**Servidor:** `src/server/agendamento/{esquemas,acoes}.ts` e `acoes.test.ts`.

**Dados:** `src/data/agendamento/{agendamentos,checkout,exemplo-local}.ts`.

**Telas:** `src/app/routes/agendar.tsx` · `src/app/routeTree.gen.ts` (gerado) ·
`src/app/paginas/agendamento/{novo,etapa-cliente,etapa-servicos,etapa-horario,etapa-conferencia,painel,status,remarcar}.tsx` ·
`src/app/paginas/agendamento/agendamento.css` · `src/app/paginas/agendamento/agendamento.test.tsx` ·
`src/app/i18n/{pt,es,en}.ts` (só chaves `agendamento.*`, inclusive os motivos de recusa do §5.1).

**Agenda (só com L-1 aceita):** `src/app/routes/agenda.tsx` (parâmetro `agendamento`) · `src/app/navegacao.ts` ·
`src/app/paginas/agenda/{agenda,barra,cartao}.tsx` · `src/server/agenda/ler-dia.ts` e `ler-dia.test.ts` ·
`src/data/agenda/agendamentos.ts` · `e2e/agenda.spec.ts` (o "em desenvolvimento" do cartão vira abertura).

**Testes de tela:** `e2e/preparo/agendamento-dados.ts` · `e2e/agendamento.spec.ts` · `e2e/agendamento-estados.spec.ts` ·
`e2e/agendamento-acessibilidade.spec.ts`.

**Ficha visual (Designer de produto):** `specs/20261128-020500-agendamento/ficha-visual.md` e `ficha/*.png`.

**Texto:** `DESIGN.md`, só as linhas aprovadas na ficha (Designer de produto) · `docs/STATUS.md`, `docs/BACKLOG.md`,
`CHANGELOG.md`, `docs/decisoes/2026-11-27-fundacao.md` (respostas E27 e das lacunas) (Documentador).

**Processo:** `specs/20261128-020500-agendamento/{spec.md,plan.md,tasks.md}` · `docs/adr/0010-agendamento-gravacao-horario-e-desfazer.md`.

**Intactos:** `src/app/ui/**`, `src/app/estilos/**`, `src/server/portas/**` e o cliente do banco (spec Entrar),
`src/domain/agenda/**` (reusado, não alterado), `src/domain/clientes/**`, `src/server/clientes/**`, `src/server/catalogo/**`,
`src/data/erros.ts` e os moldes de `supabase/moldes/` (spec Entrar), as migrations e testes dos itens 2 e 3 e dos outros
módulos (o `010_` só ganha a linha dita acima),
`supabase/config.jsonc`, `supabase/seed.sql`, `package.json`, `pnpm-lock.yaml` (nenhuma dependência nova),
`eslint.config.mjs`, `playwright.config.ts`, `.github/**`, `src/*/AGENTS.md`, `src/*/CLAUDE.md`, `ARCHITECTURE.md`, `AGENTS.md`.

## 11. Branch (decisão do Engenheiro de DevOps)
`feat/agendamento` recebe, **por merge**, nesta ordem: `feat/banco-ligacao` e `feat/design-system-codigo` (as duas já
com a `chore/fundacao-tecnica`), a branch da spec "Entrar e camada de serviço" (E36·A, `feat/entrar-servico`, que traz a base de `src/app/i18n/`), e as dos
módulos de que depende: `feat/agenda`, `feat/clientes`, `feat/catalogo`; de novo sempre que elas ganharem commit. O
Checkout **não** entra (ele depende do Agendamento). PR de rascunho empilhado; nunca se junta numa base. Quando as bases
entrarem na `previas`, a base do PR passa à `previas`, antes do pedido de merge. Conflito esperado: `routeTree.gen.ts`
(regenera-se), `src/app/i18n/*` e `navegacao.ts` (soma de linhas), carimbo das migrations (o Engenheiro de dados regenera).

## 12. Se o dono responder diferente
| Resposta | O que muda |
|---|---|
| **E27·1·B** | sai "Adicionar cliente" da etapa 1 e o passo do e2e; nada no banco |
| **E27·2·B** (encaixe) | coluna `encaixe boolean not null default false` (só dona e recepção gravam), `and not encaixe` no `where` da exclusão e no gatilho de bloqueio, registro próprio, aviso na conferência; testes 210, 230, 250; volta à 5b |
| **E26·1·A** | sem máscara no servidor; itens e histórico com leitura `S` para todos; muda 250 e `acesso.ts` |
| **E26·1·C** | leitura de `agendamentos` para a profissional só `profissional_id = U`; o servidor confere o conflito pelo banco (ela não vê os ocupados das outras); muda 250 |
| **E26·2·B** | criar e alterar só `dona` e `recepcao`; a profissional não vê "Novo agendamento" nem o ⋮; muda 250 e o e2e |
| **E26·2·C** | criar e alterar para os 3 papéis em qualquer profissional; muda 250 |
| **E26·3·B** | gatilho e `acesso.ts`: só papel `profissional` |
| **E30·3·B** (Catálogo: quem faz cada serviço) | a etapa 3 só oferece profissionais ligadas a **todos** os serviços escolhidos em `public.servicos_profissionais` (lista vazia = quem atende, pela E26·3); regra em `horario.ts` ou `acesso.ts` com teste; o servidor lê a ligação pela consulta do Catálogo (dentro do teto de criar, ADR 0010 · D4); o gatilho do `before insert` de `agendamento_itens` e o de remarcar recusam profissional não ligada; testes 210 e 250 e um passo do e2e; mais nenhum arquivo |
| **E26·3·C** | **para**: a ligação da profissional muda para a tabela nova da Equipe; plano refeito e nova 5b |

## 13. Riscos e não verificado
- **Bloqueante para construir:** a spec Entrar (E36·A) na branch (contrato do §5.1, gatilho de registro, `010_` em
  lista); as tabelas de Clientes e do
  Catálogo (Fase banco). Nomes de funções, tabelas e arquivos da Agenda, de Clientes e do Catálogo vêm dos planos deles;
  se mudarem, este plano se ajusta (nova 5b).
- O gatilho de conflito com bloqueio grava em `public.bloqueios`, tabela da Agenda: o Engenheiro de dados da Agenda
  confere (o plano dela §4.3 deixa esse lado a esta spec).
- **Não verificado:** `btree_gist` e `dblink` na imagem local do Supabase CLI 3.4.0 (estão na lista da doc; sem a
  `btree_gist`, a exclusão vira gatilho com a mesma trava do §4.4, decisão do Engenheiro de dados no ADR 0009); se o
  `dblink` liga ao próprio banco local no `supabase test db` (sem ele, o CA-04 precisa de um teste com duas ligações fora
  do pgTAP, que muda o `ci.yml` e a lista do §10; volta à 5b); o comportamento do `Intl` do Node 26, do Workers e do
  Chromium nas horas que não existem (o `horario.test.ts` prova o Node); que a função `security invoker` chamada pela Data API respeita os
  privilégios por coluna e o pré-pedido da spec Entrar (o teste 270 prova no banco local).
- Com E26·1·B, a profissional lê, na linha de agendamento de outra, o `cliente_id` (um id, sem nome; a RLS de Clientes
  não lhe mostra a cliente). O servidor não o devolve, mas a tabela fica alcançável pela Data API para quem tem o token
  (ADR 0018, Consequências; o token não chega ao JavaScript da página). Esconder também no banco pediria visão própria: o
  Engenheiro de segurança decide na revisão se é preciso.
- Numeração: ADR 0009 e 0010 e os prefixos `agendamento_2xx` podem colidir com módulos em paralelo; o Documentador
  confere no PR e renumera.
