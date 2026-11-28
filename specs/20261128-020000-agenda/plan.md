# Plano · Agenda (primeira versão, item 5 da fila)

- **Spec:** `specs/20261128-020000-agenda/spec.md` (Approved, commit `509b3b7`)
- **Escrito por:** Arquiteto de software · **Norma:** modelo C4 e ADR (mais Clean Architecture, Twelve-Factor, WCAG 2.2,
  OWASP ASVS 4.0.3 V4 e boas práticas do Postgres e do Supabase) · **Revisão:** pendente (etapa 5 Analista de
  requisitos; 5b Gerente de projeto), refeita por causa desta revisão (MP1)
- **Revisão de 28/11/2026 (tarefa MP1 de `specs/20261128-030000-entrar-servico/tasks.md`):** porta 3 por chave e
  alcance (ADR 0020), sem "função do papel"; "Ocupado" da spec §3; E26 respondidas; contrato lido no código da
  `previas` (PR #7); branch sai da `previas`.
- **Decisões técnicas deste plano:** `docs/adr/0006-agenda-tempo-idiomas-e-tetos.md` (D1 a D13). **Decisões de banco:**
  `docs/adr/0007-agenda-tabelas-do-antigo.md`, do Engenheiro de dados na tarefa T3 (não neste plano).
- **Lido no código da `previas` em 28/11/2026 (nada editado):** `src/server/portas/{acao,tipos,catalogo,executar,erros}.ts`
  e `molde.test.ts`; `src/domain/acesso/{chaves,matriz}.ts` e `matriz.test.ts`; `src/data/{cliente,erros,sessao}.ts`;
  `src/server/sessao/acoes.ts`; `src/app/routes/{__root,_app}.tsx`, `src/app/routes/_app/index.tsx`,
  `src/app/i18n/textos.ts`, `src/app/ui/*` (exportações), `src/app/estilos/app.css`; `supabase/migrations/*` (membros,
  trava, políticas base, registro e funções, pré-pedido, matriz); `supabase/moldes/*`;
  `supabase/tests/database/010_` e `110_`; `supabase/matriz/matriz.test.ts`; `e2e/preparo-global.ts`;
  `playwright.config.ts`; `package.json`; `eslint.config.mjs`; ADR 0004, 0018 (D18, D24), 0019 (pelos comentários das
  migrations) e 0020.

## 1. Resumo (C4)
**Contexto:** dona, recepção e profissional usam a tela Agenda; nenhum sistema externo novo.
**Contêiner:** o app (TanStack Start) e o banco local do Supabase, já ligados pelo Entrar (PR #7).
**Componentes (uma leitura do dia):**

```
/agenda?dia=AAAA-MM-DD   (src/app/routes/_app/agenda.tsx; só a data na URL da tela: RNF-04)
   │ loader → lerDia({ data: { estudioDaTela, dados: { dia } } })   (POST: ADR 0018 · D18)
   ▼
src/server/agenda/ler-dia.ts = acaoPost.handler(acao({ permissao: 'agenda.ver', grava: false, ... }))
   │ 6 portas de src/server/portas/executar.ts → ctx { usuarioId, orgId, alcance, alcances, idioma, fuso, ... }
   │ regras puras                               │ leitura com o token da pessoa (ctx.banco)
   ▼                                            ▼
src/domain/agenda/*                    src/data/agenda/* ──► public.membros · public.bloqueios · "ocupados" do banco
(dia, bloqueio, grade, acesso)                                (RLS por estúdio + app.pode(chave, alcance))
```

Gravações (criar, alterar, excluir bloqueio) seguem o mesmo caminho por `src/server/agenda/bloqueios.ts`.

## 2. Acesso (spec §3, RF-09 a RF-11, CA-13, CA-14; ADR 0020)

### 2.1 Chaves e linhas da matriz que a Agenda acrescenta
Em `src/domain/acesso/chaves.ts`: `MODULOS.agenda = ['ver', 'criar', 'editar', 'remover']`. Em
`src/domain/acesso/matriz.ts`, `MATRIZ_PADRAO` ganha 8 linhas, com a resposta citada ao lado de cada uma:

| Chave | Recepção | Profissional | Resposta |
|---|---|---|---|
| `agenda.ver` | `todos` | `proprios` | E26·1·B |
| `agenda.criar`, `agenda.editar`, `agenda.remover` | `todos` | `proprios` | E26·2·A |

A dona tem tudo por regra fixa (ADR 0020 · D4): não tem linha. A cópia no banco é a migration M2 (§4.2), e a linha do
`110_matriz_permissoes_test.sql` entre os marcadores passa a ser o `JSON.stringify(exportarMatriz())` novo; o
`supabase/matriz/matriz.test.ts` (já existente) e o pgTAP `110_` travam a diferença (ADR 0020 · D7, D8).

### 2.2 Ações e chaves (nomes do catálogo; ADR 0020 · D1: o módulo da chave é o primeiro trecho do nome)
| Ação (`nome`) | `permissao` | `metodo` / `grava` | O que faz |
|---|---|---|---|
| `agenda.dia.ler` | `agenda.ver` | `POST` / `false` | lê colunas e itens de um dia |
| `agenda.bloqueio.criar` | `agenda.criar` | `POST` / `true` | cria bloqueio (e o "Desfazer" do excluir) |
| `agenda.bloqueio.alterar` | `agenda.editar` | `POST` / `true` | altera bloqueio |
| `agenda.bloqueio.excluir` | `agenda.remover` | `POST` / `true` | exclui bloqueio |

`POST` também na leitura: o molde recusa `GET` no modo `estudio` (`conferirDefinicao`; ADR 0018 · D18), porque a
entrada iria para a URL. As três que gravam entram em `app.acoes_que_gravam` pela M2 (sem isso o pré-pedido e o gatilho
de registro recusam).

### 2.3 O que "próprios" quer dizer na Agenda (regra do módulo; ADR 0020 · D3)
`src/domain/agenda/acesso.ts` recebe **alcance e `usuarioId`, nunca papel** (o `ContextoEstudio` não tem papel; ADR
0020 · D5):
- `veCompleta(alcanceVer, usuarioId, colunaId)`: `todos` → toda coluna; `proprios` → só `colunaId === usuarioId`.
- `podeGravarNa(alcanceDaChave, usuarioId, profissionalId)`: `todos` → qualquer coluna; `proprios` → só a própria.
  Ao alterar, vale para a linha antiga **e** para a nova (não se move bloqueio de outra para si nem o contrário).
- Recepção não é coluna: com `proprios` (só possível no item 6a) ela não teria coluna própria e veria tudo como
  "Ocupado"; nada a fazer agora.

### 2.4 "Ocupado" (E26·1·B; spec §3, RF-10, CA-13) · ADR 0006 · D7
- Nas colunas que a pessoa não vê completas, cada bloqueio (e, quando o Agendamento existir, cada agendamento que
  ocupa horário, RN-04) sai do servidor só como `{ tipo: 'ocupado', colunaId, inicio, fim }`: sem `id`, cliente,
  serviço, status nem motivo. A tela não abre, não mostra ⋮ e os filtros não agem nessas colunas (`grade.ts` só filtra
  itens `bloqueio`/`agendamento`, nunca `ocupado`).
- **Duas camadas:** (1) o banco não entrega a linha completa de outra coluna a quem tem `agenda.ver` só `proprios`
  (política de leitura de `bloqueios` com `app.pode('agenda.ver', 'todos') or (app.pode('agenda.ver', 'proprios') and
  profissional_id = auth.uid())`); os horários das outras colunas vêm de uma leitura do banco que devolve só
  `profissional_id, inicio, fim` (§4.3); (2) o servidor monta a resposta pelo `acesso.ts` e o teste do servidor confere
  que nenhum campo a mais sai (CA-13). A forma exata da leitura de "ocupados" é do Engenheiro de dados (ADR 0007).

### 2.5 Colunas pelo papel das colegas × ADR 0020 · D5 (dúvida do Analista) · ADR 0006 · D8
**Decisão: compatível, com quatro condições.** A D5 proíbe o módulo de decidir **o que a pessoa da sessão pode** pelo
papel dela (o `if (papel === ...)` que sobreviveria ao item 6a). Ler o papel das **colegas** para saber quem é coluna
não decide acesso: aplica um dado do estúdio a uma regra de negócio que o dono fixou (E26·3·A, "quem tem papel
profissional, mais a dona"). Condições:
1. O papel da pessoa da sessão continua fora do trabalho; só o alcance decide o que ela vê e grava.
2. A regra "é coluna" mora num lugar só de cada lado: `ehColuna(membro)` em `src/domain/agenda/acesso.ts` (ativo e
   papel `dona` ou `profissional`) e uma só condição no banco (na política de gravação ou numa função, à escolha do
   Engenheiro de dados), usada para recusar bloqueio de quem não é coluna (RN-07).
3. O servidor não manda o papel das colegas à tela: só `id`, nome de exibição (L-2) e se a coluna está completa
   (minimização, RGPD art. 5(1)(c)). Ler `membros.papel` já é permitido a todo membro do estúdio (`membros_ler`, item 3):
   nada novo fica exposto.
4. Se o item 6a separar "atende clientes" do papel (perfis personalizados), o critério passa a ser um atributo próprio
   e a pergunta volta ao dono na spec do 6a; só `ehColuna` e a condição do banco mudam.

### 2.6 O que a tela recebe para esconder botões (RF-11; ADR 0020 · D9) · ADR 0006 · D11
O trabalho hoje só recebe o alcance **da chave da ação** (`ctx.alcance`). Para a tela esconder o ⋮ e a entrada de
bloqueio, a leitura do dia precisa do alcance de `agenda.criar`, `.editar` e `.remover`. Decisão: o `ContextoEstudio`
ganha `alcances` (só leitura), com o alcance de cada chave **do módulo da ação**, calculado pela mesma fonte da porta 3
(`infra.alcanceDe`; falha fechada: ausente = não pode). `agenda.dia.ler` devolve esses alcances à tela. Esconder não
protege: quem decide é a porta 3 e o banco. Mudança pequena em `src/server/portas/{tipos,executar}.ts` e no teste.
**Revisores de D10/D11:** Revisor de código, Engenheiro de segurança e Auditor de risco, ninguém que construiu o Entrar.

### 2.7 Estúdio da tela · ADR 0006 · D10
O modo `estudio` exige `estudioDaTela` (uuid) no envelope (`executar.ts`), mas `sessao.ler` hoje só devolve
`comEstudio`. Decisão: `SessaoLida` ganha `orgId: string | null` (identificador, sem dado pessoal; vai no contexto da
rota, nunca na URL). Mudam `src/server/sessao/acoes.ts`, o teste dele, `tests/integracao/entrar.test.ts` (forma
esperada) e o `SEM_SESSAO` de `src/app/routes/__root.tsx`. Recebeu `estudio_trocado` → a tela recarrega (RF-15 do
Entrar). **Revisores de D10/D11:** Revisor de código, Engenheiro de segurança e Auditor de risco, ninguém que construiu o Entrar.

## 3. Lacunas e o que espera o dono

### 3.1 Para o Analista de requisitos (a spec não cobre; não decido, `AGENTS.md` §4)
- **L-2 · Nome no cabeçalho da coluna (dado pessoal da equipe).** `public.membros` não tem nome. Recomendo: uma coluna
  de nome de exibição (só o que aparece na coluna), gravada só pela dona até existir a Equipe; em desenvolvimento, só
  nomes fictícios. Até a resposta, a T3 decide tudo menos a M1 e o teste `160_`.
- **L-3 · Peças que o `DESIGN.md` não tem** (grade de horas, cabeçalho de coluna, cartão do agendamento, cartão
  "Ocupado", bloqueio na grade, data em pílula com calendário, escolha do "Equipe N de M", campo de hora): entram pela
  ficha visual (T2), com o dono, antes da construção da tela.
- **L-4 · Tela inicial.** O `DESIGN.md` §8b diz que a tela inicial vale "até a Agenda existir". Recomendo: com a
  Agenda, `/` leva a `/agenda`. É tela: vai à ficha visual (T2), e só com o "sim" mudam `src/app/routes/_app/index.tsx`,
  `src/app/paginas/inicio.tsx`, o teste dele e `e2e/inicio.spec.ts`.

Resolvidas desde a versão anterior: login e portas (Entrar, PR #7); banco local com Auth nas telas (Entrar mudou o
`db:start`); linha "Branch" da spec; CA-04 (`estudio_trocado`, spec §9).

### 3.2 Pessoa que deixou de ser coluna
Pendência da spec da Equipe (spec §12); defesa: a ligação sem apagar em cascata.

### 3.3 À espera do dono · ideias do antigo E54·1 a E54·8 (`ideias-do-antigo.md`; nada entra sem "sim", item por item)
Nenhuma está no plano. Se aprovada, entra assim (o Analista põe na spec, o plano volta à 5b):

| Ideia | Onde entraria | Efeito no teto e no banco |
|---|---|---|
| E54·1 menu no horário vazio | `grade.tsx` e a peça de grade em `src/app/ui/`; abre também pelo teclado; escondido pela RF-11 | nenhum |
| E54·2 linha do "agora" | `dia.ts` (posição do agora no fuso) e a peça de grade; cor pelo `DESIGN.md` | nenhum |
| E54·3 atalhos de motivo | bloco `agenda` dos 3 arquivos de idioma e `bloqueio-painel.tsx` | nenhum (só texto) |
| E54·4 1 h e fim que acompanha | `bloqueio.ts` (função pura com teste) e `bloqueio-painel.tsx` | nenhum |
| E54·5 hora sem dois-pontos | `src/domain/agenda/hora.ts` (por idioma, com teste) e o campo de hora em `src/app/ui/campos.tsx` | nenhum |
| E54·6 resumo por coluna | `grade.ts` (soma) e a resposta de `agenda.dia.ler`; só na coluna completa | nenhum |
| E54·7 dias marcados no calendário | ação nova `agenda.mes.ler` (`agenda.ver`), leitura nova em `src/data/agenda/`; "próprios" só os dias dela | uma ida por mês aberto (ADR novo) |
| E54·8 modo Lista no celular | visão nova no "Dia ▾", `src/domain/agenda/lista.ts`, página nova; "livre" depende do expediente (Equipe) | nenhum |

## 4. Banco (tipo Banco; quem decide é o Engenheiro de dados)

### 4.1 Decisão por tabela do antigo · Engenheiro de dados decide na T3 (ADR 0007, conferido por outra instância)
| Tabela (antigo) | Sugestão | Motivo |
|---|---|---|
| `time_blocks` | **reescrever** como `public.bloqueios` | ficam estúdio, profissional, início, fim, motivo e autor; saem `resource_id`, `location_id`, `repeat_rule`, tipo e cor |
| `staff_members` | **descartar** (E26·3·A; spec §7) | as colunas saem de `public.membros`; e-mail, telefone, cor e comissão não são da Agenda (RGPD art. 5(1)(c)) |
| `staff_shifts`, `time_block_types`, `resources`, `agenda_waitlist` | **adiada** | fora da v1 (spec §2.1 e §7) |
| `appointments` | **na spec do Agendamento** | a Agenda só lê, quando a tabela existir |
| (novo) nome de exibição (L-2) | **espera a L-2**; sugestão: coluna em `public.membros` | uma ida a menos por tela |

### 4.2 Migrations (`pnpm exec supabase migration new <nome>`; data e hora depois de `20261128035000`)
| # | Nome | Conteúdo (sugestão; forma final do Engenheiro de dados) |
|---|---|---|
| M1 | `agenda_nome_exibicao` | só com a L-2 respondida: `nome_exibicao` em `public.membros`, tamanho máximo, privilégio por coluna |
| M2 | `agenda_permissoes` | `insert` em `app.chaves_permissao` (4 chaves `agenda.*`) e em `app.matriz_permissoes` (8 linhas do §2.1), no molde da migration `20261128035000_matriz_permissoes.sql`; `insert` em `app.acoes_que_gravam` das 3 ações que gravam |
| M3 | `agenda_bloqueios` | tabela, RLS ligada e forçada, `revoke all` de `anon` e `authenticated`, `grant` por coluna, políticas por `app.pode(...)`, índices, restrições, a leitura de "ocupados" (§2.4) e o gatilho `create trigger bloqueios_registro after insert or update or delete on public.bloqueios for each row execute function app.registrar_mudanca('id')` (molde do comentário de `20261128013147_registro_funcoes.sql`) |

### 4.3 `public.bloqueios` (sugestão)
| Coluna | Tipo e regra |
|---|---|
| `id` | `uuid primary key default gen_random_uuid()` |
| `org_id` | `uuid not null` |
| `profissional_id` | `uuid not null` |
| `inicio`, `fim` | `timestamptz not null`; `check (fim > inicio)`; `check (fim - inicio >= interval '5 minutes')` (RN-03) |
| `motivo` | `text null`, `check (char_length(motivo) <= 200)` (RN-03) |
| `criado_por` | `uuid not null default auth.uid()` |
| `criado_em` | `timestamptz not null default now()` |

- **Ligação composta (RN-07):** `foreign key (org_id, profissional_id) references public.membros (org_id, user_id)`,
  **sem** `on delete cascade` (pendência da Equipe, spec §12; §3.2). Atenção: apagar em cascata dispararia o gatilho de registro sem
  `x-acao` da lista, que recusa e desfaz a gravação inteira.
- **Profissional é coluna (RN-07, E26·3·A):** uma condição só (§2.5 item 2), conferida ao criar **e** ao alterar
  (CA-14).
- **Mesmo dia do estúdio (RN-03):** regra de `src/domain` (com teste); defesa no banco por gatilho que lê
  `public.estudios.fuso_horario`, se o Engenheiro de dados decidir.
- **Sem sobreposição entre bloqueios (RN-04):** `exclude using gist (org_id with =, profissional_id with =,
  tstzrange(inicio, fim, '[)') with &&)` (encostar não conflita); pede `btree_gist` (não verificado no banco local, §12).
  O código `23P01` já vira `conflito` em `src/data/erros.ts`. Bloqueio × agendamento: na spec do Agendamento, nas duas
  direções; até lá a Agenda confere no servidor com a mesma regra pura.
- **Índices:** `(org_id, profissional_id, inicio)` e o da exclusão (o `010_` exige índice que comece por `org_id`).
- **Políticas** (`to authenticated`; `S` = `org_id = (select app.estudio_da_sessao())`; `pode(c, a)` =
  `(select app.pode(c, a))`; `eu` = `profissional_id = (select auth.uid())`):
  - ler: `S and (pode('agenda.ver','todos') or (pode('agenda.ver','proprios') and eu))`;
  - criar: `with check S and coluna and (pode('agenda.criar','todos') or (pode('agenda.criar','proprios') and eu))`;
  - alterar: `using` e `with check` com `agenda.editar` (linha antiga e nova), `coluna` no `with check`;
  - apagar: `using S and (pode('agenda.remover','todos') or (pode('agenda.remover','proprios') and eu))`;
  - `grant update (profissional_id, inicio, fim, motivo)`: ninguém grava `org_id` nem `criado_por`.
- **"Ocupados" das outras colunas (§2.4):** leitura que devolve só `profissional_id, inicio, fim` das colunas do estúdio
  no intervalo pedido, para quem tem ao menos `pode('agenda.ver','proprios')`. Sugestão: função em `app`
  (`security definer`, `search_path` vazio, estúdio da sessão, sem parâmetro de estúdio, com teto de linhas) e passagem
  `public.agenda_ocupados(p_inicio, p_fim)` `security invoker`, no molde de `public.registrar_recusa`; chamada com
  `rpc(..., { get: true })` (ADR 0018 · D18). Se nascer função `security definer`, a lista do `010_` muda junto.

### 4.4 Testes pgTAP (`supabase/tests/database/`, `pnpm db:test`; `110_` já é da matriz)
| Arquivo | Prova |
|---|---|
| `110_matriz_permissoes_test.sql` | **só** a linha entre os marcadores (e o `plan(...)` se o Engenheiro de dados acrescentar casos `agenda.*`) |
| `120_agenda_bloqueios_isolamento_test.sql` | cópia do molde `supabase/moldes/isolamento_tabela_test.sql`: A não lê, cria, altera nem apaga de B; sem papel e sem login, nada (CA-02, CA-03) |
| `130_agenda_bloqueios_regras_test.sql` | RN-03, RN-04 e RN-07 **ao criar e ao alterar** (CA-14): outro estúdio, recepção como profissional, fim ≤ início, < 5 min, 201 caracteres, sobreposição, encostar aceito, dois dias (se o gatilho entrar) |
| `140_agenda_bloqueios_permissoes_test.sql` | chave e alcance (CA-03, CA-13, CA-14): dona e recepção em qualquer coluna; profissional só na própria, ao criar, alterar (linha antiga e nova) e apagar; profissional não lê linha nem motivo de outra; "ocupados" só com início e fim; chave apagada da matriz → nada |
| `150_registro_bloqueios_test.sql` | cópia do molde `supabase/moldes/registro_tabela_test.sql` para `bloqueios` (porta 6; motivo nunca no registro, RF-09) |
| `160_agenda_colunas_test.sql` | só com M1: nome isolado por estúdio; só a dona grava; `anon` nada |
| `010_base_estrutura_test.sql` | só se a T3 criar função `security definer` ou se a lista de privilégios por tabela pedir `bloqueios` |

## 5. Código por camada (regra de dependência do `ARCHITECTURE.md` §3, travada pelo lint)

### 5.1 Contrato da camada de serviço (lido em `src/server/portas/`; não se muda além do §2.6)
- Cada ação: `export const x = acaoPost.handler(acao({ nome, metodo: 'POST', sessao: 'estudio', permissao: '<chave>',
  entrada: z.strictObject({...}), grava, trabalho }))` (molde do comentário de `acao.ts`).
- A tela chama `x({ data: { estudioDaTela, dados } })` e tipa com `ChamadaDaTela<typeof x, typeof entrada>`; recebe
  `{ ok: true, valor } | { ok: false, codigo }` (`erros.ts`, lista fechada).
- `trabalho(ctx, dados)`: `ctx` = `ContextoEstudio` (`pedidoId`, `usuarioId`, `orgId`, `alcance`, `alcances` do §2.6,
  `idioma`, `fuso`, `moeda`, `banco`). `src/domain` recebe só valores, nunca `ctx.banco`.
- Regra do módulo recusa com `throw new Recusa('entrada_invalida' | 'conflito' | 'sem_permissao')` (`erros.ts`); erro
  do banco vem como `ErroDoBanco` de `src/data` e vira código por `codigoDoErro`.
- No máximo **uma** gravação por ação (`src/data/cliente.ts` conta; a segunda nem sai e vira `erro_interno`). Cada
  gravação da Agenda toca só `bloqueios`: sem função de gravação no banco.
- Registro (porta 6): gatilho na M3; recusas, `registrarRecusa` do molde. O código da Agenda não grava registro.

### 5.2 `src/domain/agenda/` (TypeScript puro, com teste; Engenheiro de software)
| Arquivo | O que tem | Regras |
|---|---|---|
| `tipos.ts` | `Instante`, `Intervalo`, `DiaDoEstudio`, `ItemDaGrade` (`bloqueio`, `agendamento`, `ocupado`), `Coluna`, `MembroDaEquipe` | — |
| `dia.ts` | limites do dia no fuso, hoje no fuso, dia anterior e seguinte, corte do item na borda | RN-01, RN-02, RF-01, RF-02 |
| `bloqueio.ts` | validar (fim > início, ≥ 5 min, mesmo dia, motivo ≤ 200) e achar conflito `[início, fim)` na mesma coluna, ignorando Cancelado, Ausência e o próprio item ao alterar | RN-03, RN-04 |
| `grade.ts` | itens sobrepostos lado a lado; filtros (status, bloqueio; Cancelado escondido por padrão; `ocupado` nunca filtrado); contador; teto | RN-05, RN-06, RN-08, RF-06, CA-13 |
| `acesso.ts` | `ehColuna` (E26·3·A), `veCompleta`, `podeGravarNa`, `paraResposta` (monta o item completo ou "Ocupado") — só por alcance e `usuarioId` | RN-07, RF-10, §2.3 a §2.5 |

- Fuso e "agora" por parâmetro. Cálculo do dia só com `Intl.DateTimeFormat` (ADR 0006 · D2).
- Testes (CA-01): `Europe/Lisbon` e `America/New_York` em dia de 23 h e de 25 h; meia-noite que não existe
  (`America/Santiago`; `America/Sao_Paulo` em 04/11/2018); cruzar a meia-noite; encostar; Cancelado e Ausência; teto.
  `acesso.test.ts`: `todos`/`proprios` × própria coluna/outra, ao criar e ao alterar (linha antiga e nova).
- `src/domain/exemplo.ts` e `exemplo.test.ts` **saem** (marcados pelo item 2 para sair na primeira regra real).

### 5.3 `src/server/agenda/` (Engenheiro de software)
| Arquivo | O que tem |
|---|---|
| `esquemas.ts` | `z.strictObject` de cada ação: `{ dia }` (`AAAA-MM-DD`); bloqueio `{ profissionalId (uuid), dia, inicio, fim (HH:MM em passos de 15 min), motivo? (≤ 200) }`; alterar = o mesmo + `id`; excluir `{ id }`. Sem campo de estúdio: campo a mais → `entrada_invalida` |
| `ler-dia.ts` | `agenda.dia.ler`: limites do dia (`dia.ts`, `ctx.fuso`) → colunas (1 ida) → bloqueios completos que a RLS deixa (1 ida, `limit` teto + 1) → só com `ctx.alcance === 'proprios'`: "ocupados" das outras (1 ida) → `acesso.paraResposta` → `{ dia, colunas: [{ id, nome, completa }], itens, passouDoTeto, alcances }` |
| `bloqueios.ts` | três ações que gravam: `podeGravarNa` pelo `ctx.alcance` (falhou: `sem_permissao`, sem ir ao banco) → 1 leitura (a linha antiga, ao alterar e excluir, e os ocupados da coluna no dia, num pedido só) → `bloqueio.ts` (falhou: `entrada_invalida` ou `conflito`) → 1 gravação. Corrida: a exclusão do banco recusa (`conflito`) |
| `ler-dia.test.ts`, `bloqueios.test.ts` | `trabalho` com `ctx` falso (o molde e as portas são testados no Entrar): campo de estúdio em `dados` → `entrada_invalida` (CA-04); profissional não grava na coluna de outra, nem move bloqueio entre colunas (E26·2·A); resposta com `proprios` sem `id`, motivo, cliente, serviço nem status nas outras colunas (CA-13); motivo nunca em erro (CA-09); ≤ 3 leituras no dia, ≤ 1 leitura + 1 gravação por ação (RNF-02) |

O teste do molde (`molde.test.ts`) já percorre todo arquivo de `src/` com `acao({` e confere método, chave do catálogo
e mesmo módulo: as ações da Agenda entram nele sem mudar o teste.

### 5.4 `src/data/agenda/` (Engenheiro de software; consultas conferidas pelo Engenheiro de dados)
| Arquivo | O que tem |
|---|---|
| `colunas.ts` | membros ativos que são coluna, com o nome de exibição (L-2), por `clienteDoBanco(ctx.banco)`; devolve `MembroDaEquipe` (o papel só para `ehColuna`, não sai do servidor) |
| `bloqueios.ts` | bloqueios que cruzam `[inicioDoDia, fimDoDia)` das colunas pedidas, com `limit`; "ocupados" por `rpc(..., { get: true })`; linha antiga + ocupados de uma coluna num pedido; criar, alterar, apagar por `id`. Nenhum filtro por `org_id` vindo de fora: a RLS decide |

Sem teste de unidade próprio (consultas); a prova é o pgTAP (§4.4), `tests/integracao/agenda.test.ts` e o e2e.

### 5.5 `tests/integracao/agenda.test.ts` (Engenheiro de software; banco local, `pnpm test:integracao`)
Pelas 6 portas reais (harness de `tests/integracao/preparo.ts`): sem login e sem papel, nada (CA-03); `estudioDaTela`
de outro estúdio → `estudio_trocado`, nada lido nem gravado (CA-04); profissional recebe "Ocupado" sem detalhes nas
outras colunas (CA-13); recepção grava em qualquer coluna, profissional só na própria (CA-03).

### 5.6 `src/app/` (Engenheiro de software; desenho do Designer de produto na ficha)
- **Rota** `src/app/routes/_app/agenda.tsx` (dentro da área com sessão do `_app.tsx`): `validateSearch` só `dia`
  (`AAAA-MM-DD`); sem `dia`, hoje no fuso, calculado no servidor. `loader` chama `lerDia` com
  `estudioDaTela = context.sessao.orgId` (§2.7). Folha `agenda.css` pelo `head` com `?url`, como `entrar.css`.
- **Estrutura** `src/app/routes/_app.tsx` e `src/app/navegacao.ts`: menu principal (1440) e barra de baixo (390) pelo
  mapa único do `DESIGN.md` §7, Agenda ligada e os outros "em desenvolvimento". Sua conta segue em `BarraSuaConta`; se a
  ficha a puser dentro da barra do topo, mudam `src/app/paginas/sua-conta.tsx` e `.css`.
- **Peças novas do `DESIGN.md` (L-3) ficam em `src/app/ui/`**, não em `src/app/paginas/` (ADR 0006 · D12; lição do
  ADR 0018 · D24): `src/app/ui/grade-agenda.tsx` e `.css` (grade, cabeçalho de coluna, cartões do agendamento, de
  bloqueio e "Ocupado"), `src/app/ui/seletor-data.tsx` e `.css` (Hoje, setas, data em pílula com calendário), campo de
  hora em `src/app/ui/campos.tsx` (se a ficha não usar `CampoSelecao`), com `componentes.test.tsx`, o `@import` em
  `src/app/estilos/app.css` e a vitrine (`src/app/paginas/vitrine.tsx`, `vitrine-dados.ts`, `e2e/vitrine.spec.ts`).
  Ajustes em peça existente, só se a ficha pedir: `estrutura.tsx` (barra da grade no `BarraTopo`), `camadas.tsx`
  (`MenuAcoesLinha`, `Painel`, `Folha`, `Janelinha`, `Aviso`), `estados.tsx`, `icone.tsx` (ícone do "Ocupado"), com o
  `.css` de cada uma; token novo só com o `DESIGN.md` (`tokens.css`, `tokens.test.ts`).
- **Tela** em `src/app/paginas/agenda/`:

| Arquivo | O que tem |
|---|---|
| `agenda.tsx` | composição: barra do topo (1440) ou cabeçalho e barra de baixo (390), barra da grade, grade, estados (spec §4) |
| `barra.tsx` | Hoje, setas, data, Dia ▾ (só Dia; os outros "em desenvolvimento"), Equipe N de M, Filtros ▾ com contador, Lista de espera e Opções "em desenvolvimento" |
| `grade.tsx` | grade de 24 h pela peça `grade-agenda`, rolagem até a hora atual ou ao primeiro item; teclado (RNF-03); ⋮ e entrada de bloqueio escondidos pelos `alcances` (RF-11); "Ocupado" sem toque nem ⋮ |
| `bloqueio-painel.tsx` | criar e alterar: `Painel` (1440) ou `Folha` (390); com `proprios`, profissional só a própria pessoa; Excluir no ⋮ com `Janelinha` e `Aviso` com "Desfazer" |
| `filtros.tsx` | `Painel`/`Folha`: status e bloqueio; "Limpar filtros"; só sobre colunas completas |
| `equipe.tsx`, `equipe-guardada.ts` | escolha de colunas; guarda no aparelho só os identificadores escondidos, por estúdio (ADR 0006 · D5) |
| `agenda.css` | só `var(--...)` (teste `tokens.test.ts`, RT-9) |
| `agenda.test.tsx` | `renderToString`: uma só ação preta; status com nome acessível; "Ocupado" sem ⋮; nenhum texto fixo fora do arquivo de idioma |

- **Idiomas (RNF-05):** a Agenda acrescenta o bloco `agenda` (textos da tela, frases dos códigos de erro dela,
  "empresa"/"business" pela E47·1·A) em `src/app/i18n/{pt,es,en}.ts`; `textos.ts`, `formatar.ts` e `i18n.test.ts`
  ficam intactos (o teste já confere mesmas chaves, nenhuma vazia, mesmos marcadores).
- **Agendamento ainda não construído (RF-08):** "Novo agendamento", "Agendar" e o toque no cartão ficam "em
  desenvolvimento"; a grade mostra só bloqueios. A spec do Agendamento acrescenta a leitura dos agendamentos (o teto
  sobe no ADR dela).

## 6. Desfazer, tetos e estados (ADR 0006)
- **Desfazer a exclusão (D4):** o aviso guarda na memória da tela os dados do bloqueio excluído; "Desfazer" chama
  `agenda.bloqueio.criar` com eles (mesmas portas, mesmo conflito, novo `id`). Se o horário foi ocupado, diz o conflito.
- **Teto de itens (D3):** 500 por dia (todas as colunas à vista), lidos com `limit 501`; passou, a tela avisa (RN-08).
- **Teto de idas ao banco no trabalho (D3):** leitura do dia ≤ 3 (colunas, bloqueios, "ocupados" só com `proprios`);
  gravação 1 leitura + 1 gravação. Fora isso, só o que as portas fazem para a sessão.
- **Erro:** "Tentar de novo" refaz o `loader`. **Carregando:** `Carregando` de `src/app/ui/estados.tsx` (0,3 s).

## 7. Testes de tela (Playwright, projetos `celular` 390 e `computador` 1440)
Dados só fictícios, no banco **local**. As contas (dona, recepção, duas profissionais, estúdios A e B) entram no
`e2e/preparo-global.ts` (único lugar com a chave local de administração, ADR 0018); os **bloqueios** são criados pelos
próprios testes, pela tela ou pela ação com a sessão da dona, porque o gatilho de registro recusa gravação sem pessoa e
sem `x-acao` (ADR 0006 · D13).

| Arquivo | Prova |
|---|---|
| `e2e/agenda.spec.ts` | CA-05: abre em hoje; anterior, seguinte, calendário e Hoje; Equipe N de M; filtros, contador e "Limpar filtros"; criar, alterar, conflito recusado, excluir com janelinha e "Desfazer". CA-13: como profissional, outras colunas só "Ocupado", sem ⋮, filtros sem efeito nelas. CA-09: a URL só tem `dia`; motivo e nomes fora da URL e do console |
| `e2e/agenda-estados.spec.ts` | CA-06: carregando (resposta atrasada por `page.route`), vazio, sem resultado, sem profissional, erro |
| `e2e/agenda-acessibilidade.spec.ts` | CA-08: `AxeBuilder` com `wcag2a`, `wcag2aa`, `wcag21a`, `wcag21aa`, `wcag22aa`, tela fechada e com painel, folha e janelinha abertos; grade por teclado |

## 8. Papéis
| Etapa | Papel |
|---|---|
| Branch e PR de rascunho (T1) | Engenheiro de DevOps |
| Ficha visual e peças novas do `DESIGN.md` (T2, etapa 6) | Designer de produto; confere o Revisor de design; aprova o dono |
| Decisão por tabela, migrations, pgTAP (T3 a T5) | Engenheiro de dados |
| Matriz no código, domínio, servidor, dados, telas, idiomas, e2e (T6 a T18) | Engenheiro de software |
| Revisar código | Revisor de código |
| Revisar o contrato tocado (§2.6, §2.7; ADR 0006 · D10 e D11) | Revisor de código, Engenheiro de segurança e Auditor de risco, ninguém que construiu o Entrar |
| Revisar banco e conferir o ADR 0007 item por item (E16·1) | Engenheiro de dados (outra instância) e Auditor de risco |
| Revisar acesso e privacidade (chaves, alcance, "Ocupado", CA-09, CA-13) | Engenheiro de segurança e Auditor de risco |
| Revisar a tela (checklist `DESIGN.md` §10) | Revisor de design |
| Veredito CA-01 a CA-14 | Analista de qualidade (QA) |
| Conferir o pedido · registros · pedido de merge | Analista de requisitos · Documentador · Gerente de projeto |

## 9. Branch (Engenheiro de DevOps)
`feat/agenda` sai da `previas`, que já tem a trava por estúdio, o design system e o Entrar (PR #7). Não há mais branch
empilhada nem merge de bases: os passos de preparação de merge da versão anterior (antiga T1) não são mais precisos.
PR de rascunho com base na `previas`; nada é juntado sem o dono (E22·B). Conflito esperado só em
`src/app/routeTree.gen.ts` (regenera-se, não se edita à mão).

## 10. Arquivos (lista FECHADA)
Fora desta lista nada muda (`AGENTS.md` §6). Arquivo que uma ferramenta crie fora daqui: parar e relatar. "(se ...)" =
só com a condição cumprida, registrada no PR.

**Banco (Engenheiro de dados):** `supabase/migrations/<ts>_agenda_permissoes.sql` · `<ts>_agenda_bloqueios.sql` ·
`<ts>_agenda_nome_exibicao.sql` (se L-2) · `supabase/tests/database/110_matriz_permissoes_test.sql` (só a linha entre os
marcadores e o `plan(...)`) · `120_agenda_bloqueios_isolamento_test.sql` · `130_agenda_bloqueios_regras_test.sql` ·
`140_agenda_bloqueios_permissoes_test.sql` · `150_registro_bloqueios_test.sql` · `160_agenda_colunas_test.sql` (se M1) ·
`010_base_estrutura_test.sql` (se função `security definer` nova ou privilégio por tabela) ·
`docs/adr/0007-agenda-tabelas-do-antigo.md`.

**Acesso (Engenheiro de software):** `src/domain/acesso/chaves.ts` (só `MODULOS.agenda`) · `src/domain/acesso/matriz.ts`
(só as 8 linhas) · `src/domain/acesso/matriz.test.ts` (o caso "catálogo do sistema vazio" passa a esperar as chaves
`agenda.*`).

**Contrato (Engenheiro de software; §2.6 e §2.7):** `src/server/portas/tipos.ts` e `src/server/portas/executar.ts` (só
`alcances` no `ContextoEstudio`) · `src/server/portas/executar.test.ts` · `src/server/sessao/acoes.ts` (só `orgId` em
`SessaoLida`) · `src/server/sessao/acoes.test.ts` · `tests/integracao/entrar.test.ts` (só a forma esperada de
`sessao.ler`).

**Domínio:** `src/domain/agenda/{tipos,dia,bloqueio,grade,acesso}.ts` e `{dia,bloqueio,grade,acesso}.test.ts`; apagar
`src/domain/exemplo.ts` e `src/domain/exemplo.test.ts`.

**Servidor:** `src/server/agenda/{esquemas,ler-dia,bloqueios}.ts` e `{ler-dia,bloqueios}.test.ts`.

**Dados:** `src/data/agenda/{colunas,bloqueios}.ts`.

**Integração:** `tests/integracao/agenda.test.ts`.

**Telas:** `src/app/routes/_app/agenda.tsx` · `src/app/routes/_app.tsx` · `src/app/routes/__root.tsx` (só o
`SEM_SESSAO`) · `src/app/routeTree.gen.ts` (gerado) · `src/app/navegacao.ts` ·
`src/app/paginas/agenda/{agenda,barra,grade,bloqueio-painel,filtros,equipe}.tsx` ·
`src/app/paginas/agenda/equipe-guardada.ts` · `src/app/paginas/agenda/agenda.css` ·
`src/app/paginas/agenda/agenda.test.tsx` · `src/app/i18n/{pt,es,en}.ts` (só o bloco `agenda`).

**Design system (Engenheiro de software, só peças aprovadas na ficha):** `src/app/ui/grade-agenda.tsx` e `.css` ·
`src/app/ui/seletor-data.tsx` e `.css` · `src/app/ui/componentes.test.tsx` · `src/app/estilos/app.css` (só os
`@import`) · `src/app/paginas/vitrine.tsx` · `src/app/paginas/vitrine-dados.ts` · `src/app/paginas/vitrine.css` (se a vitrine pedir) ·
`e2e/vitrine.spec.ts` ·
(se a ficha pedir) `src/app/ui/{campos,estrutura,camadas,estados,icone}.tsx` com os `.css` de cada uma ·
`src/app/estilos/tokens.css` e `src/app/ui/tokens.test.ts` (se token novo aprovado) ·
`src/app/paginas/sua-conta.tsx` e `sua-conta.css` (se a ficha mudar o lugar de Sua conta) ·
`src/app/routes/_app/index.tsx`, `src/app/paginas/inicio.tsx`, `inicio.test.tsx`, `e2e/inicio.spec.ts` (se L-4).

**Testes de tela:** `e2e/preparo-global.ts` (só as contas da Agenda) · `e2e/agenda.spec.ts` ·
`e2e/agenda-estados.spec.ts` · `e2e/agenda-acessibilidade.spec.ts`.

**Ficha visual (Designer de produto):** `specs/20261128-020000-agenda/ficha-visual.md` e `ficha/*.png`.

**Texto:** `DESIGN.md`, **só** as linhas das peças que o dono aprovar na ficha (Designer de produto) · `docs/STATUS.md`,
`docs/BACKLOG.md`, `CHANGELOG.md`, `docs/decisoes/2026-11-27-fundacao.md` (respostas L-2, L-4, E54) (Documentador).

**Processo:** `specs/20261128-020000-agenda/{spec.md,plan.md,tasks.md}` · `docs/adr/0006-agenda-tempo-idiomas-e-tetos.md`.

**Intactos:** `src/server/portas/{acao,catalogo,erros}.ts` e `molde.test.ts`, `src/server/http/**`,
`src/data/{cliente,erros,sessao,ambiente}.ts`, `src/app/i18n/{textos,formatar}.ts` e `i18n.test.ts`,
`src/app/estilos/base.css`, as migrations e os testes do banco já existentes (menos `110_` e `010_` como acima),
`supabase/moldes/**`, `supabase/matriz/**`, `supabase/config.jsonc`, `supabase/seed.sql`, `scripts/**`,
`tests/integracao/preparo.ts`, `src/*/AGENTS.md`, `src/*/CLAUDE.md`, `package.json`, `pnpm-lock.yaml`,
`eslint.config.mjs`, `playwright.config.ts`, `.github/**`, `ARCHITECTURE.md`, `AGENTS.md`.

## 11. Critério → prova
| CA | Prova | Quem confere |
|---|---|---|
| CA-01 | `src/domain/agenda/*.test.ts` verdes | QA |
| CA-02 | pgTAP 120 e 130 | Engenheiro de dados revisor; QA |
| CA-03 | pgTAP 120 e 140; `matriz.test.ts`, `supabase/matriz/matriz.test.ts` e `110_` (código = banco); `ler-dia.test.ts`, `bloqueios.test.ts`, `tests/integracao/agenda.test.ts` | QA; Engenheiro de segurança |
| CA-04 | `tests/integracao/agenda.test.ts` (`estudio_trocado`) e testes do servidor (campo de estúdio em `dados`) | Revisor de código |
| CA-05, CA-06 | `e2e/agenda.spec.ts` e `e2e/agenda-estados.spec.ts` nos 2 projetos | QA |
| CA-07 | checklist `DESIGN.md` §10 nas capturas 390 e 1440 | Revisor de design |
| CA-08 | `e2e/agenda-acessibilidade.spec.ts` nos 2 projetos | QA |
| CA-09 | testes do servidor, pgTAP 150 e e2e (URL, registro, erro) e revisão | Engenheiro de segurança |
| CA-10 | ADR 0007 com cada tabela da spec §7; migrations só das reescritas | Auditor de risco |
| CA-11 | histórico da CI; nenhum `supabase link`, `db push`, `--remote` ou `--linked` | Auditor de risco |
| CA-12 | relatórios sem "Bloqueia"; veredito do QA; conferência do dono na prévia | Gerente de projeto |
| CA-13 | `ler-dia.test.ts`, pgTAP 140, `tests/integracao/agenda.test.ts`, `e2e/agenda.spec.ts` | Engenheiro de segurança; QA |
| CA-14 | pgTAP 130 e 140 (cada regra ao criar e ao alterar) | Engenheiro de dados revisor |
| Escopo | `git diff --name-only origin/previas...HEAD` comparado com o §10 | Revisor de código |

## 12. Riscos e não verificado
- **Não verificado:** `btree_gist` no banco local (sem ela, a exclusão do §4.3 vira gatilho); desempenho de
  `app.pode(...)` chamado em cada política (ADR 0020, risco já aberto); se `rpc(..., { get: true })` serve a função de
  "ocupados" sem gravar nada (ADR 0018 · D18 diz que sim, não rodado aqui); o `Intl` do Node 26 e do Chromium na
  meia-noite que não existe (o teste do CA-01 prova); `Temporal` no Cloudflare Workers (por isso não se usa).
- O §2.6 e o §2.7 tocam arquivos do Entrar já juntados: se os revisores de D10/D11 recusarem,
  RF-11 e o envelope ficam sem caminho e o plano volta à 5b.
- L-2 sem resposta: as colunas não têm nome; a tela não pode ir à ficha visual completa sem ela.
- Numeração: ADR 0007 e os pgTAP `120_` a `160_` podem colidir com as specs do núcleo em branches paralelas; o
  Documentador confere no PR e renumera se preciso.
