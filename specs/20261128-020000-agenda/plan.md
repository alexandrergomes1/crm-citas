# Plano · Agenda (primeira versão, item 5 da fila)

- **Spec:** `specs/20261128-020000-agenda/spec.md` (Approved; ajustes 2 e 3 nos commits `217a715` e `a0159f6`)
- **Escrito por:** Arquiteto de software · **Norma:** modelo C4 e ADR (mais Clean Architecture, Twelve-Factor, WCAG 2.2,
  OWASP ASVS 4.0.3 V4 e boas práticas do Postgres e do Supabase) · **Revisão:** pendente (etapa 5 Analista de
  requisitos; 5b Gerente de projeto)
- **Revisão de 28/11/2026 (spec §16 e §17):** sai o "Ocupado" e toda leitura de "ocupados" (E58·A); saem RF-16 a RF-20
  (E57·B, só "em desenvolvimento"); entram RF-12 a RF-15, RF-21 e RF-22 (E54·1, ·2, ·3, ·4, E54·5 trocada, E55·1·A a
  E55·4); L-2 e L-4 resolvidas (E55·1·A, E55·2·A). **Ponto aberto:** grade da v1, E59 do dono (§3.2).
- **Decisões técnicas deste plano:** `docs/adr/0006-agenda-tempo-idiomas-e-tetos.md` (D1 a D16). **Decisões de banco:**
  `docs/adr/0007-agenda-tabelas-do-antigo.md`, do Engenheiro de dados na tarefa T3 (não neste plano).
- **Lido no código da `previas` em 28/11/2026 (nada editado):** `src/server/portas/{acao,tipos,catalogo,executar,erros}.ts`
  e `molde.test.ts`; `src/domain/acesso/{chaves,matriz}.ts` e `matriz.test.ts`; `src/data/{cliente,erros,sessao}.ts`;
  `src/server/sessao/acoes.ts`; `src/app/routes/{__root,_app}.tsx`, `src/app/routes/_app/index.tsx`,
  `src/app/i18n/textos.ts`, `src/app/ui/*` (exportações: `MenuAcoes`, `CampoSelecao`, `Painel`, `Folha`, `Janelinha`,
  `Aviso`, `Seletor`, `Agendar`, entre outras), `src/app/estilos/app.css`; `supabase/migrations/*` (inclusive
  `20261128002042_membros.sql` e `20261128002045_politicas_base.sql`: `membros` sem nome, `grant update (papel, ativo)`,
  `membros_ler` para todo membro do estúdio); `supabase/moldes/*`; `supabase/tests/database/010_` e `110_`;
  `supabase/matriz/matriz.test.ts`; `e2e/preparo-global.ts`; `tests/integracao/preparo.ts`; `playwright.config.ts`;
  `package.json`; `eslint.config.mjs`; ADR 0004, 0018 (D18, D24), 0019 e 0020. A `ficha-visual.md` está em mudança
  pelo Designer: não é fonte deste plano.

## 1. Resumo (C4)
**Contexto:** dona, recepção e profissional usam a tela Agenda; nenhum sistema externo novo.
**Contêiner:** o app (TanStack Start) e o banco local do Supabase, já ligados pelo Entrar (PR #7).
**Componentes (uma leitura do dia):**

```
/            → redireciona para /agenda (RF-12, E55·2·A)
/agenda?dia=AAAA-MM-DD   (src/app/routes/_app/agenda.tsx; só a data na URL da tela: RNF-04)
   │ loader → lerDia({ data: { estudioDaTela, dados: { dia } } })   (POST: ADR 0018 · D18)
   ▼
src/server/agenda/ler-dia.ts = acaoPost.handler(acao({ permissao: 'agenda.ver', grava: false, ... }))
   │ 6 portas de src/server/portas/executar.ts → ctx { usuarioId, orgId, alcance, alcances, idioma, fuso, ... }
   │ regras puras                               │ leitura com o token da pessoa (ctx.banco)
   ▼                                            ▼
src/domain/agenda/*                    src/data/agenda/* ──► public.membros (com nome_exibicao) · public.bloqueios
(dia, horários, bloqueio, grade, acesso)                      (RLS por estúdio + app.pode(chave, alcance))
```

Gravações (criar, alterar, excluir bloqueio) seguem o mesmo caminho por `src/server/agenda/bloqueios.ts`.

## 2. Acesso (spec §3, RF-09 a RF-11, CA-03, CA-13, CA-14; ADR 0020)

### 2.1 Chaves e linhas da matriz que a Agenda acrescenta
Em `src/domain/acesso/chaves.ts`: `MODULOS.agenda = ['ver', 'criar', 'editar', 'remover']` (nenhuma chave de ocupação,
E58·A). Em `src/domain/acesso/matriz.ts`, `MATRIZ_PADRAO` ganha 8 linhas, com a resposta citada ao lado:

| Chave | Recepção | Profissional | Resposta |
|---|---|---|---|
| `agenda.ver` | `todos` | `proprios` | E26·1·B lida pela ordem de 28/11 e pela E58·A (só a própria coluna) |
| `agenda.criar`, `agenda.editar`, `agenda.remover` | `todos` | `proprios` | E26·2·A |

A dona tem tudo por regra fixa (ADR 0020 · D4): não tem linha. A cópia no banco é a migration M2 (§4.2), e a linha do
`110_matriz_permissoes_test.sql` entre os marcadores passa a ser o `JSON.stringify(exportarMatriz())` novo; o
`supabase/matriz/matriz.test.ts` e o pgTAP `110_` travam a diferença (ADR 0020 · D7, D8).

### 2.2 Ações e chaves (ADR 0020 · D1: o módulo da chave é o primeiro trecho do nome)
| Ação (`nome`) | `permissao` | `metodo` / `grava` | O que faz |
|---|---|---|---|
| `agenda.dia.ler` | `agenda.ver` | `POST` / `false` | lê colunas e itens de um dia |
| `agenda.bloqueio.criar` | `agenda.criar` | `POST` / `true` | cria bloqueio (e o "Desfazer" do excluir) |
| `agenda.bloqueio.alterar` | `agenda.editar` | `POST` / `true` | altera bloqueio |
| `agenda.bloqueio.excluir` | `agenda.remover` | `POST` / `true` | exclui bloqueio |

`POST` também na leitura: o molde recusa `GET` no modo `estudio` (`conferirDefinicao`; ADR 0018 · D18). As três que
gravam entram em `app.acoes_que_gravam` pela M2.

### 2.3 O que "próprios" quer dizer na Agenda (ADR 0020 · D3)
`src/domain/agenda/acesso.ts` recebe **alcance e `usuarioId`, nunca papel** (ADR 0020 · D5):
- `colunasVisiveis(alcanceVer, usuarioId, colunas)`: `todos` → todas; `proprios` → só a coluna `usuarioId` (ou
  nenhuma, se a pessoa não é coluna).
- `podeGravarNa(alcanceDaChave, usuarioId, profissionalId)`: `todos` → qualquer coluna; `proprios` → só a própria. Ao
  alterar, vale para a linha antiga **e** para a nova.
- Recepção não é coluna: com `proprios` (só possível no item 6a) ela não veria coluna nenhuma (estado "sem
  profissional"); nada a fazer agora.

### 2.4 Só a própria coluna, em duas camadas (E58·A; spec §3, RF-10, CA-13) · ADR 0006 · D7
- **Sem "Ocupado" nesta spec:** nenhuma chave, leitura, item nem peça de "Ocupado". "Ver as outras" e "ver ocupação"
  entram no item 6a.
- **Banco:** a política de leitura de `bloqueios` só entrega a linha a quem tem `agenda.ver` `todos` ou (`proprios` e
  `profissional_id = auth.uid()`). Fica como defesa, não por causa do "Ocupado": se o servidor errar, o banco não dá as
  outras colunas.
- **Servidor:** com `ctx.alcance === 'proprios'`, a leitura do dia pede ao banco só a coluna da pessoa e devolve só ela;
  o teste do servidor confere que nenhuma outra coluna nem item sai (CA-13). `public.membros` continua legível por todo
  membro (`membros_ler`, item 3): o servidor não manda à tela as outras pessoas (minimização, RGPD art. 5(1)(c)).
- **Conflito (RN-04):** com `proprios`, a pessoa só grava na própria coluna, então o conflito só precisa da própria
  coluna, que a RLS já entrega. Nenhuma leitura de horário de outra coluna.

### 2.5 Colunas pelo papel das colegas × ADR 0020 · D5 · ADR 0006 · D8
**Compatível, com quatro condições** (sem mudança desde a revisão MP1): (1) o papel da pessoa da sessão fica fora do
trabalho, só o alcance decide; (2) "é coluna" mora num lugar só de cada lado: `ehColuna(membro)` em `acesso.ts` (ativo e
papel `dona` ou `profissional`) e uma condição no banco que recusa bloqueio de quem não é coluna (RN-07); (3) o servidor
não manda o papel das colegas à tela, só `id`, nome de exibição e iniciais; (4) se o item 6a separar "atende clientes"
do papel, só `ehColuna` e a condição do banco mudam, com pergunta ao dono na spec do 6a.

### 2.6 O que a tela recebe para esconder botões (RF-11; ADR 0020 · D9) · ADR 0006 · D11
O `ContextoEstudio` ganha `alcances` (só leitura): o alcance de cada chave do módulo da ação, pela mesma fonte da porta
3 (`infra.alcanceDe`; falha fechada). `agenda.dia.ler` devolve esses alcances; a tela esconde o ⋮, o "Bloquear
horário" do "+ Novo" e o menu do horário vazio (RF-13) onde a pessoa não grava. Esconder não protege: quem decide é a
porta 3 e o banco. **Revisores de D10/D11:** Revisor de código, Engenheiro de segurança e Auditor de risco, ninguém que
construiu o Entrar.

### 2.7 Estúdio da tela · ADR 0006 · D10
`SessaoLida` ganha `orgId: string | null` (identificador, sem dado pessoal; contexto da rota, nunca na URL). Mudam
`src/server/sessao/acoes.ts`, o teste dele, `tests/integracao/entrar.test.ts` e o `SEM_SESSAO` de
`src/app/routes/__root.tsx`. Recebeu `estudio_trocado` → a tela recarrega (RF-15 do Entrar).

## 3. Lacunas e pontos abertos

### 3.1 Resolvidas pela spec de 28/11
- **L-2 · Nome da coluna:** E55·1·A (RF-21). Onde mora: §4.1 e ADR 0006 · D14.
- **L-4 · Tela inicial:** E55·2·A (RF-12): `/` redireciona para `/agenda` (§5.6).
- **L-3 · Peças que o `DESIGN.md` não tem** (grade de horas, cabeçalho de coluna com nome e iniciais, cartão do
  agendamento, bloqueio na grade, linha do "agora", data em pílula com calendário, escolha do "Equipe N de M",
  atalhos de motivo): seguem pela ficha visual (T2), com o dono, antes da construção da tela. Reuso antes de criar:
  `MenuAcoes` para "+ Novo" e para o menu do horário vazio; `CampoSelecao` para o seletor de horários (D15), se a ficha
  não pedir outra peça.
- **Para o Designer (não decido):** texto que aparece quando a pessoa ainda não tem nome de exibição (D14); como o
  seletor mostra a hora repetida no dia de 25 h (D15); se o "Agendar" da barra de baixo vira "+ Novo" (spec §4).

### 3.2 Grade da v1 · espera a E59 do dono
A spec (RN-01, Assumption 1) e este plano seguem com **24 h e rolagem** até o dono responder. O que muda em cada opção:

| | E59·A · 08:00 a 20:00, que se alarga para caber item fora | E59·B · 24 h com rolagem |
|---|---|---|
| Spec | o Analista muda a Assumption 1 e acrescenta a regra da faixa (RN nova, com teste no CA-01) | nada muda |
| Domínio | função nova `faixaVisivel(dia, itens)` em `grade.ts`: começa em `min(08:00, início do primeiro item, arredondado para baixo na hora)` e termina em `max(20:00, fim do último item, arredondado para cima)`, cortada no dia do estúdio (RN-01, 23 h e 25 h); teste a mais | nada a mais |
| Tela | a grade desenha só a faixa; o menu do horário vazio (RF-13) só existe dentro dela; a linha do "agora" fora da faixa não aparece (ou alarga a faixa: escolha do Designer com o dono) | rolagem até a hora atual ou ao primeiro item |
| Seletor de horários | **não muda**: continua o dia inteiro (RN-09), para poder bloquear fora da faixa | igual |
| Banco, servidor, tetos | nada muda | nada muda |
| Risco | 08–20 é fixo, não é o horário de funcionamento (que foi para a spec seguinte, E57·B); estúdio que abre às 07:00 vê a grade começar às 08:00 até ter item cedo | grade longa no celular; a rolagem até o "agora" esconde as horas vazias |

Arquivos: os de A já estão na lista do §10 (`grade.ts`, `grade.test.ts`, `grade.tsx`, `grade-agenda`); nenhum novo.

### 3.3 Pessoa que deixou de ser coluna
Pendência da spec da Equipe (spec §12); defesa: a ligação sem apagar em cascata (§4.3).

### 3.4 Ideias do antigo (E54) · situação
| Ideia | Situação | Onde entra |
|---|---|---|
| E54·1 menu no horário vazio | aprovada (RF-13) | `grade.tsx` e a peça de grade em `src/app/ui/`; abre por toque, Enter e Espaço (WCAG 2.1.1); escondido pela RF-11 |
| E54·2 linha do "agora" | aprovada (RF-14) | `dia.ts` (`posicaoDoAgora(dia, fuso, agora)`, nulo fora do dia) e a peça de grade; cor do `DESIGN.md` (Designer) |
| E54·3 atalhos de motivo | aprovada (RF-22) | lista fixa de 5 chaves de texto em `bloqueio-painel.tsx`, textos no bloco `agenda` dos 3 idiomas; o atalho só preenche o campo motivo (RN-03); sem tabela, sem "Médico" |
| E54·4 1 h e fim que acompanha | aprovada (RF-15, RN-10) | `horarios.ts` (`fimSugerido`, função pura com teste) e `bloqueio-painel.tsx` |
| E54·5 | **trocada** pelo seletor de horários (RF-15, RN-09) | `horarios.ts` (opções do seletor) e `esquemas.ts` + `bloqueios.ts` (recusa no servidor); ADR 0006 · D15 |
| E54·6, ·7, ·8 | fora (E57·B) | spec seguinte |

## 4. Banco (tipo Banco; quem decide a forma final é o Engenheiro de dados)

### 4.1 Decisão por tabela do antigo · Engenheiro de dados decide na T3 (ADR 0007, conferido por outra instância)
| Tabela (antigo) | Sugestão | Motivo |
|---|---|---|
| `time_blocks` | **reescrever** como `public.bloqueios` | ficam estúdio, profissional, início, fim, motivo e autor; saem `resource_id`, `location_id`, `repeat_rule`, tipo e cor |
| `staff_members` | **descartar** (E26·3·A; spec §7) | as colunas saem de `public.membros`; e-mail, telefone, cor e comissão não são da Agenda |
| `staff_shifts`, `time_block_types`, `resources`, `agenda_waitlist` | **adiada** | fora da v1 |
| `appointments` | **na spec do Agendamento** | a Agenda só lê, quando a tabela existir |
| (novo) nome de exibição | **coluna `nome_exibicao` em `public.membros`** (ADR 0006 · D14) | ver abaixo |

**Onde mora o nome de exibição (D14):** em `public.membros`, por vínculo pessoa × estúdio.
- Por vínculo, não por pessoa: a mesma pessoa pode estar em dois estúdios e cada um mostra o nome que quiser; o
  isolamento por estúdio vem da RLS que `membros` já tem (`ARCHITECTURE.md` §5).
- Não em `auth.users` (metadados): a própria pessoa muda os metadados pela API de Auth, sem passar pelas portas, e
  eles valem para todos os estúdios.
- Não em tabela nova: seria mais uma ida por tela (teto D3) e mais RLS e teste, para um campo só.
- Forma sugerida: `nome_exibicao text null`, `check (char_length(btrim(nome_exibicao)) between 1 and 60)`; **sem**
  `grant update` para `authenticated` nesta spec (não há tela de edição; o módulo Equipe acrescenta o privilégio e a
  ação). Em desenvolvimento, nomes fictícios postos pelo preparo dos testes (`e2e/preparo-global.ts`,
  `tests/integracao/preparo.ts`) e pelo `supabase/tests/database/010_` se ele precisar. Sem gatilho de registro novo
  (nenhuma ação grava o campo).
- Nunca o e-mail no lugar (RF-21). Iniciais: calculadas na tela a partir do nome, nunca guardadas.

### 4.2 Migrations (`pnpm exec supabase migration new <nome>`; data e hora depois de `20261128035000`)
| # | Nome | Conteúdo (sugestão; forma final do Engenheiro de dados) |
|---|---|---|
| M1 | `agenda_nome_exibicao` | `alter table public.membros add column nome_exibicao ...` (§4.1); `comment on column`; sem novo `grant` |
| M2 | `agenda_permissoes` | `insert` em `app.chaves_permissao` (4 chaves `agenda.*`) e em `app.matriz_permissoes` (8 linhas do §2.1), no molde de `20261128035000_matriz_permissoes.sql`; `insert` em `app.acoes_que_gravam` das 3 ações que gravam |
| M3 | `agenda_bloqueios` | tabela, RLS ligada e forçada, `revoke all` de `anon` e `authenticated`, `grant` por coluna, políticas por `app.pode(...)`, índices, restrições e o gatilho `create trigger bloqueios_registro after insert or update or delete on public.bloqueios for each row execute function app.registrar_mudanca('id')` |

### 4.3 `public.bloqueios` (sugestão)
| Coluna | Tipo e regra |
|---|---|
| `id` | `uuid primary key default gen_random_uuid()` |
| `org_id` | `uuid not null` |
| `profissional_id` | `uuid not null` |
| `inicio`, `fim` | `timestamptz not null`; `check (fim > inicio)`; `check (fim - inicio >= interval '5 minutes')` (RN-03); defesa do passo (RN-09): `check` de segundos zero e minuto múltiplo de 15 em UTC, se o Engenheiro de dados decidir (D15) |
| `motivo` | `text null`, `check (char_length(motivo) <= 200)` (RN-03) |
| `criado_por` | `uuid not null default auth.uid()` |
| `criado_em` | `timestamptz not null default now()` |

- **Ligação composta (RN-07):** `foreign key (org_id, profissional_id) references public.membros (org_id, user_id)`,
  **sem** `on delete cascade` (§3.3; apagar em cascata dispararia o gatilho de registro sem `x-acao`, que recusa).
- **Profissional é coluna (RN-07, E26·3·A):** uma condição só (§2.5), conferida ao criar **e** ao alterar (CA-14).
- **Mesmo dia do estúdio (RN-03):** regra de `src/domain` (com teste); defesa no banco por gatilho que lê
  `public.estudios.fuso_horario`, se o Engenheiro de dados decidir.
- **Sem sobreposição entre bloqueios (RN-04):** `exclude using gist (org_id with =, profissional_id with =,
  tstzrange(inicio, fim, '[)') with &&)`; pede `btree_gist` (não verificado no banco local, §12). `23P01` já vira
  `conflito` em `src/data/erros.ts`. Bloqueio × agendamento: na spec do Agendamento.
- **Índices:** `(org_id, profissional_id, inicio)` e o da exclusão (o `010_` exige índice que comece por `org_id`).
- **Políticas** (`to authenticated`; `S` = `org_id = (select app.estudio_da_sessao())`; `pode(c, a)` =
  `(select app.pode(c, a))`; `eu` = `profissional_id = (select auth.uid())`):
  - ler: `S and (pode('agenda.ver','todos') or (pode('agenda.ver','proprios') and eu))`;
  - criar: `with check S and coluna and (pode('agenda.criar','todos') or (pode('agenda.criar','proprios') and eu))`;
  - alterar: `using` e `with check` com `agenda.editar` (linha antiga e nova), `coluna` no `with check`;
  - apagar: `using S and (pode('agenda.remover','todos') or (pode('agenda.remover','proprios') and eu))`;
  - `grant update (profissional_id, inicio, fim, motivo)`: ninguém grava `org_id` nem `criado_por`.
- **Sem função de "ocupados"** (E58·A): nenhuma função `security definer` nova; o `010_` só muda se a lista de
  privilégios por tabela pedir `bloqueios`.

### 4.4 Testes pgTAP (`supabase/tests/database/`, `pnpm db:test`)
| Arquivo | Prova |
|---|---|
| `110_matriz_permissoes_test.sql` | **só** a linha entre os marcadores (e o `plan(...)` se houver casos `agenda.*`) |
| `120_agenda_bloqueios_isolamento_test.sql` | molde `supabase/moldes/isolamento_tabela_test.sql`: A não lê, cria, altera nem apaga de B; sem papel e sem login, nada (CA-02, CA-03) |
| `130_agenda_bloqueios_regras_test.sql` | RN-03, RN-04, RN-07 (e o passo de RN-09, se o `check` entrar) **ao criar e ao alterar** (CA-14) |
| `140_agenda_bloqueios_permissoes_test.sql` | chave e alcance (CA-03, CA-13, CA-14): dona e recepção em qualquer coluna; profissional só na própria, ao criar, alterar (linha antiga e nova) e apagar; profissional não lê nenhuma linha de outra coluna; chave apagada da matriz → nada |
| `150_registro_bloqueios_test.sql` | molde `supabase/moldes/registro_tabela_test.sql` (porta 6; motivo nunca no registro, RF-09) |
| `160_agenda_nome_exibicao_test.sql` | nome isolado por estúdio (A não lê o de B); `authenticated` não grava o campo, nem a dona; `anon` nada; tamanho 1 a 60 |
| `010_base_estrutura_test.sql` | só se a lista de privilégios por tabela pedir `bloqueios` |

## 5. Código por camada (regra de dependência do `ARCHITECTURE.md` §3, travada pelo lint)

### 5.1 Contrato da camada de serviço (lido em `src/server/portas/`; não se muda além do §2.6)
- Cada ação: `export const x = acaoPost.handler(acao({ nome, metodo: 'POST', sessao: 'estudio', permissao: '<chave>',
  entrada: z.strictObject({...}), grava, trabalho }))`.
- A tela chama `x({ data: { estudioDaTela, dados } })`, tipa com `ChamadaDaTela<typeof x, typeof entrada>` e recebe
  `{ ok: true, valor } | { ok: false, codigo }`.
- `trabalho(ctx, dados)`: `ctx` = `ContextoEstudio` (com `alcances`, §2.6). `src/domain` recebe só valores.
- Recusa do módulo: `throw new Recusa('entrada_invalida' | 'conflito' | 'sem_permissao')`; erro do banco por
  `codigoDoErro`.
- No máximo **uma** gravação por ação (`src/data/cliente.ts` conta). Registro (porta 6): gatilho na M3.

### 5.2 `src/domain/agenda/` (TypeScript puro, com teste; Engenheiro de software)
| Arquivo | O que tem | Regras |
|---|---|---|
| `tipos.ts` | `Instante`, `Intervalo`, `DiaDoEstudio`, `ItemDaGrade` (`bloqueio`, `agendamento`), `Coluna`, `MembroDaEquipe` | — |
| `dia.ts` | limites do dia no fuso, hoje no fuso, dia anterior e seguinte, corte do item na borda, `posicaoDoAgora` | RN-01, RN-02, RF-01, RF-02, RF-14 |
| `horarios.ts` | `PASSO_MINUTOS = 15`; `horariosDoDia(dia, fuso)` (instantes do início ao fim do dia em passos de 15 min, com o rótulo local, inclusive 23 h e 25 h); `estaNoPasso(instante, dia)`; `fimSugerido(inicio, fimAtual, dia)` | RN-09, RN-10, RF-15 |
| `bloqueio.ts` | validar (fim > início, ≥ 5 min, mesmo dia, no passo, motivo ≤ 200) e achar conflito `[início, fim)` na mesma coluna, ignorando Cancelado, Ausência e o próprio item ao alterar | RN-03, RN-04, RN-09 |
| `grade.ts` | itens sobrepostos lado a lado; filtros (status, bloqueio; Cancelado escondido por padrão); contador; teto; (`faixaVisivel` só se E59·A, §3.2) | RN-05, RN-06, RN-08, RF-06 |
| `acesso.ts` | `ehColuna`, `colunasVisiveis`, `podeGravarNa`, só por alcance e `usuarioId` | RN-07, RF-10, §2.3 a §2.5 |

- Fuso e "agora" por parâmetro; cálculo do dia só com `Intl.DateTimeFormat` (ADR 0006 · D2).
- Testes (CA-01, CA-15): `Europe/Lisbon` e `America/New_York` em dia de 23 h e de 25 h; meia-noite que não existe
  (`America/Santiago`; `America/Sao_Paulo` em 04/11/2018); cruzar a meia-noite; encostar; Cancelado e Ausência; teto;
  `horariosDoDia` com 92, 96 e 100 opções nos dias de 23, 24 e 25 h (mais a borda final); `estaNoPasso` recusa :07 e
  segundos; `fimSugerido` (1 h, acompanha, para no fim do dia); `acesso.test.ts`: `todos`/`proprios` × própria
  coluna/outra, ao criar e ao alterar.
- `src/domain/exemplo.ts` e `exemplo.test.ts` **saem**.

### 5.3 `src/server/agenda/` (Engenheiro de software)
| Arquivo | O que tem |
|---|---|
| `esquemas.ts` | `z.strictObject` de cada ação: `{ dia }` (`AAAA-MM-DD`); bloqueio `{ profissionalId (uuid), inicio, fim (instantes ISO com fuso), motivo? (≤ 200) }`; alterar = o mesmo + `id`; excluir `{ id }`. Sem campo de estúdio: campo a mais → `entrada_invalida` |
| `ler-dia.ts` | `agenda.dia.ler`: limites do dia (`dia.ts`, `ctx.fuso`) → colunas (1 ida; com `proprios`, só a própria) → bloqueios das colunas visíveis (1 ida, `limit` teto + 1) → `{ dia, colunas: [{ id, nome }], itens, passouDoTeto, alcances }`. Nada de outra coluna com `proprios` |
| `bloqueios.ts` | três ações que gravam: `podeGravarNa` pelo `ctx.alcance` (falhou: `sem_permissao`, sem ir ao banco) → `estaNoPasso` e mesmo dia (falhou: `entrada_invalida`, sem ir ao banco; CA-15) → 1 leitura (linha antiga, ao alterar e excluir, e os itens da coluna no dia, num pedido só) → `bloqueio.ts` (falhou: `entrada_invalida` ou `conflito`) → 1 gravação |
| `ler-dia.test.ts`, `bloqueios.test.ts` | `trabalho` com `ctx` falso: campo de estúdio em `dados` → `entrada_invalida` (CA-04); profissional não grava em outra coluna nem move bloqueio entre colunas; com `proprios`, a resposta só tem a coluna da pessoa (CA-13); hora fora do passo → `entrada_invalida` (CA-15); motivo nunca em erro (CA-09); ≤ 2 leituras no dia, ≤ 1 leitura + 1 gravação por ação (RNF-02) |

O `molde.test.ts` já percorre todo arquivo com `acao({`: as ações da Agenda entram nele sem mudar o teste.

### 5.4 `src/data/agenda/` (Engenheiro de software; consultas conferidas pelo Engenheiro de dados)
| Arquivo | O que tem |
|---|---|
| `colunas.ts` | membros ativos que são coluna, com `nome_exibicao`, por `clienteDoBanco(ctx.banco)`; com `proprios`, filtra pelo `usuarioId`; o papel só para `ehColuna`, não sai do servidor |
| `bloqueios.ts` | bloqueios que cruzam `[inicioDoDia, fimDoDia)` das colunas pedidas, com `limit`; linha antiga + itens de uma coluna num pedido; criar, alterar, apagar por `id`. Nenhum filtro por `org_id` vindo de fora |

Sem teste de unidade próprio; a prova é o pgTAP, `tests/integracao/agenda.test.ts` e o e2e.

### 5.5 `tests/integracao/agenda.test.ts` (banco local, `pnpm test:integracao`)
Pelas 6 portas reais: sem login e sem papel, nada (CA-03); `estudioDaTela` de outro estúdio → `estudio_trocado` (CA-04);
profissional recebe só a própria coluna, sem item de outra (CA-13); recepção grava em qualquer coluna, profissional só
na própria (CA-03); hora fora do passo recusada (CA-15).

### 5.6 `src/app/` (Engenheiro de software; desenho do Designer de produto na ficha)
- **Rota** `src/app/routes/_app/agenda.tsx`: `validateSearch` só `dia`; sem `dia`, hoje no fuso, no servidor. `loader`
  chama `lerDia` com `estudioDaTela = context.sessao.orgId` (§2.7). Folha `agenda.css` pelo `head` com `?url`.
- **`/` abre a Agenda (RF-12):** `src/app/routes/_app/index.tsx` passa a redirecionar para `/agenda` (`redirect` do
  TanStack Router no `beforeLoad`); `src/app/paginas/inicio.tsx` e `inicio.test.tsx` saem (só a rota os usa);
  `e2e/inicio.spec.ts` passa a provar o redirecionamento. A linha "tela inicial até a Agenda existir" do `DESIGN.md`
  §8b é do Designer.
- **Estrutura** `src/app/routes/_app.tsx` e `src/app/navegacao.ts`: menu principal (1440) e barra de baixo (390) pelo
  mapa do `DESIGN.md` §7, Agenda ligada e os outros "em desenvolvimento".
- **Peças novas do `DESIGN.md` (L-3) em `src/app/ui/`** (ADR 0006 · D12): `grade-agenda.tsx` e `.css` (grade,
  cabeçalho de coluna com nome e iniciais, cartões do agendamento e do bloqueio, linha do "agora", horário vazio que
  abre menu), `seletor-data.tsx` e `.css`, com `componentes.test.tsx`, `@import` em `app.css` e a vitrine. Ajustes em
  peça existente só se a ficha pedir (`campos`, `estrutura`, `camadas`, `estados`, `icone`, `botao`).
- **Tela** em `src/app/paginas/agenda/`:

| Arquivo | O que tem |
|---|---|
| `agenda.tsx` | composição: barra do topo com **+ Novo** (1440) ou cabeçalho e barra de baixo (390), barra da grade, grade, estados |
| `barra.tsx` | Hoje, setas, data, Dia ▾ (só Dia; os outros "em desenvolvimento", CA-16), Equipe N de M, Filtros ▾ com contador, Lista de espera e Opções "em desenvolvimento"; no celular, a lupa "em desenvolvimento" |
| `novo.tsx` | **+ Novo** pelo `MenuAcoes`: "Novo agendamento" ("em desenvolvimento" até o Agendamento) e "Bloquear horário" (escondido sem `agenda.criar`) |
| `grade.tsx` | grade pela peça `grade-agenda` (24 h com rolagem até o "agora" ou o primeiro item; faixa da E59·A se aprovada); linha do "agora" na coluna de hoje (RF-14); horário vazio com menu por toque e teclado (RF-13), escondido onde a pessoa não grava; ⋮ escondido pelos `alcances` |
| `bloqueio-painel.tsx` | criar e alterar: `Painel` (1440) ou `Folha` (390); início e fim por seletor de horários (`horariosDoDia`), sem campo de digitar; nasce com 1 h e o fim acompanha (`fimSugerido`); atalhos Almoço · Folga · Reunião · Curso · Pessoal preenchem o motivo; com `proprios`, profissional só a própria pessoa; Excluir no ⋮ com `Janelinha` e `Aviso` com "Desfazer" |
| `filtros.tsx` | `Painel`/`Folha`: status e bloqueio; "Limpar filtros" |
| `equipe.tsx`, `equipe-guardada.ts` | escolha de colunas (M = colunas que a pessoa vê); guarda no aparelho só os identificadores escondidos, por estúdio (D5) |
| `agenda.css` | só `var(--...)` |
| `agenda.test.tsx` | `renderToString`: uma só ação preta ("+ Novo"); status com nome acessível; nenhum campo de digitar hora; nenhum texto fixo fora do arquivo de idioma; nome de exibição no topo da coluna, nunca o e-mail |

- **Idiomas (RNF-05):** bloco `agenda` em `src/app/i18n/{pt,es,en}.ts` (textos, atalhos de motivo, frases dos códigos
  de erro, "empresa"/"business"); `textos.ts`, `formatar.ts` e `i18n.test.ts` intactos.
- **Agendamento ainda não construído (RF-08):** "Novo agendamento" (no "+ Novo" e no menu do horário vazio) e o toque
  no cartão ficam "em desenvolvimento"; a grade mostra só bloqueios.

## 6. Desfazer, tetos e estados (ADR 0006)
- **Desfazer a exclusão (D4):** "Desfazer" chama `agenda.bloqueio.criar` com os dados guardados na memória da tela.
- **Teto de itens (D3):** 500 por dia, lidos com `limit 501`; passou, a tela avisa (RN-08).
- **Teto de idas ao banco no trabalho (D3):** leitura do dia ≤ 2 (colunas, bloqueios); gravação 1 leitura + 1 gravação.
- **Erro:** "Tentar de novo" refaz o `loader`. **Carregando:** `Carregando` de `src/app/ui/estados.tsx` (0,3 s).

## 7. Testes de tela (Playwright, projetos `celular` 390 e `computador` 1440)
Dados fictícios no banco **local**. Contas (dona, recepção, duas profissionais, estúdios A e B, com nome de exibição
fictício) no `e2e/preparo-global.ts`; os bloqueios são criados pelos testes, pela tela ou pela ação (ADR 0006 · D13).

| Arquivo | Prova |
|---|---|
| `e2e/agenda.spec.ts` | CA-05: `/` abre a Agenda em hoje; troca de dia e Hoje; Equipe N de M; filtros e "Limpar filtros"; "+ Novo" com as duas opções; menu do horário vazio por toque e por teclado; criar (só seletor, 1 h, atalho), alterar, conflito recusado, excluir com "Desfazer"; nome de exibição nas colunas. CA-13: como profissional, só a própria coluna. CA-15: nenhum campo de digitar hora. CA-16: outros formatos do "Dia ▾" e lupa "em desenvolvimento". CA-09: a URL só tem `dia` |
| `e2e/agenda-estados.spec.ts` | CA-06: carregando, vazio, sem resultado, sem profissional, erro |
| `e2e/agenda-acessibilidade.spec.ts` | CA-08: `AxeBuilder` com `wcag2a`, `wcag2aa`, `wcag21a`, `wcag21aa`, `wcag22aa`, com painel, folha, menus e janelinha abertos; grade e menu do horário vazio por teclado |

## 8. Papéis
| Etapa | Papel |
|---|---|
| Branch e PR de rascunho (T1) | Engenheiro de DevOps |
| Ficha visual e peças novas do `DESIGN.md` (T2) | Designer de produto; confere o Revisor de design; aprova o dono |
| Decisão por tabela, migrations, pgTAP (T3 a T5) | Engenheiro de dados |
| Matriz, domínio, servidor, dados, telas, idiomas, e2e (T6 a T22) | Engenheiro de software |
| Revisar código | Revisor de código |
| Revisar o contrato tocado (§2.6, §2.7) | Revisor de código, Engenheiro de segurança e Auditor de risco, ninguém que construiu o Entrar |
| Revisar banco e o ADR 0007 item por item (E16·1) | Engenheiro de dados (outra instância) e Auditor de risco |
| Revisar acesso e privacidade (chaves, alcance, só a própria coluna, nome de exibição, CA-09, CA-13) | Engenheiro de segurança e Auditor de risco |
| Revisar a tela | Revisor de design |
| Veredito CA-01 a CA-16 | Analista de qualidade (QA) |
| Conferir o pedido · registros · pedido de merge | Analista de requisitos · Documentador · Gerente de projeto |

## 9. Branch (Engenheiro de DevOps)
`feat/agenda` sai da `previas` (PR #7 dentro). PR de rascunho com base na `previas`; nada é juntado sem o dono (E22·B).
Conflito esperado só em `src/app/routeTree.gen.ts` (regenera-se).

## 10. Arquivos (lista FECHADA)
Fora desta lista nada muda (`AGENTS.md` §6). Arquivo que uma ferramenta crie fora daqui: parar e relatar. "(se ...)" =
só com a condição cumprida, registrada no PR.

**Banco (Engenheiro de dados):** `supabase/migrations/<ts>_agenda_nome_exibicao.sql` · `<ts>_agenda_permissoes.sql` ·
`<ts>_agenda_bloqueios.sql` · `supabase/tests/database/110_matriz_permissoes_test.sql` (só a linha entre os marcadores e
o `plan(...)`) · `120_agenda_bloqueios_isolamento_test.sql` · `130_agenda_bloqueios_regras_test.sql` ·
`140_agenda_bloqueios_permissoes_test.sql` · `150_registro_bloqueios_test.sql` · `160_agenda_nome_exibicao_test.sql` ·
`010_base_estrutura_test.sql` (se privilégio por tabela ou a coluna nova pedir) ·
`docs/adr/0007-agenda-tabelas-do-antigo.md`.

**Acesso:** `src/domain/acesso/chaves.ts` (só `MODULOS.agenda`) · `src/domain/acesso/matriz.ts` (só as 8 linhas) ·
`src/domain/acesso/matriz.test.ts`.

**Contrato (§2.6 e §2.7):** `src/server/portas/tipos.ts` e `executar.ts` (só `alcances`) · `executar.test.ts` ·
`src/server/sessao/acoes.ts` (só `orgId`) · `acoes.test.ts` · `tests/integracao/entrar.test.ts` (só a forma de
`sessao.ler`).

**Domínio:** `src/domain/agenda/{tipos,dia,horarios,bloqueio,grade,acesso}.ts` e
`{dia,horarios,bloqueio,grade,acesso}.test.ts`; apagar `src/domain/exemplo.ts` e `exemplo.test.ts`.

**Servidor:** `src/server/agenda/{esquemas,ler-dia,bloqueios}.ts` e `{ler-dia,bloqueios}.test.ts`.

**Dados:** `src/data/agenda/{colunas,bloqueios}.ts`.

**Integração:** `tests/integracao/agenda.test.ts` · `tests/integracao/preparo.ts` (só o nome de exibição fictício nas
contas, se o teste pedir).

**Telas:** `src/app/routes/_app/agenda.tsx` · `src/app/routes/_app/index.tsx` (redirecionar, RF-12) ·
`src/app/routes/_app.tsx` · `src/app/routes/__root.tsx` (só o `SEM_SESSAO`) · `src/app/routeTree.gen.ts` (gerado) ·
`src/app/navegacao.ts` · `src/app/paginas/agenda/{agenda,barra,novo,grade,bloqueio-painel,filtros,equipe}.tsx` ·
`src/app/paginas/agenda/equipe-guardada.ts` · `agenda.css` · `agenda.test.tsx` · `src/app/i18n/{pt,es,en}.ts` (só o
bloco `agenda`) · `src/app/paginas/inicio.tsx` e `inicio.test.tsx` (apagar; hoje só `_app/index.tsx` os usa) ·
`e2e/inicio.spec.ts`.

**Design system (só peças aprovadas na ficha):** `src/app/ui/grade-agenda.tsx` e `.css` · `src/app/ui/seletor-data.tsx`
e `.css` · `src/app/ui/componentes.test.tsx` · `src/app/estilos/app.css` (só os `@import`) ·
`src/app/paginas/vitrine.tsx` · `vitrine-dados.ts` · `vitrine.css` (se a vitrine pedir) · `e2e/vitrine.spec.ts` ·
(se a ficha pedir) `src/app/ui/{campos,estrutura,camadas,estados,icone,botao}.tsx` com os `.css` de cada uma ·
`src/app/estilos/tokens.css` e `src/app/ui/tokens.test.ts` (se token novo aprovado, ex.: cor da linha do "agora") ·
`src/app/paginas/sua-conta.tsx` e `sua-conta.css` (se a ficha mudar o lugar de Sua conta).

**Testes de tela:** `e2e/preparo-global.ts` (só as contas da Agenda e o nome de exibição) · `e2e/agenda.spec.ts` ·
`e2e/agenda-estados.spec.ts` · `e2e/agenda-acessibilidade.spec.ts`.

**Ficha visual (Designer de produto):** `specs/20261128-020000-agenda/ficha-visual.md` e `ficha/*.png`.

**Texto:** `DESIGN.md`, só as linhas que o dono aprovar na ficha (Designer de produto) · `docs/STATUS.md`,
`docs/BACKLOG.md`, `CHANGELOG.md`, `docs/decisoes/` (Documentador).

**Processo:** `specs/20261128-020000-agenda/{spec.md,plan.md,tasks.md,ideias-do-antigo.md}` ·
`docs/adr/0006-agenda-tempo-idiomas-e-tetos.md`.

**Saiu desta lista (28/11):** tudo de "Ocupado" (peça, ícone, leitura e função de "ocupados") e tudo de RF-16 a RF-20
(`lista.ts`, `agenda.mes.ler`, resumo da coluna, horário de funcionamento, busca da lupa).

**Intactos:** `src/server/portas/{acao,catalogo,erros}.ts` e `molde.test.ts`, `src/server/http/**`,
`src/data/{cliente,erros,sessao,ambiente}.ts`, `src/app/i18n/{textos,formatar}.ts` e `i18n.test.ts`,
`src/app/estilos/base.css`, as migrations e os testes do banco já existentes (menos `110_` e `010_` como acima),
`supabase/moldes/**`, `supabase/matriz/**`, `supabase/config.jsonc`, `supabase/seed.sql`, `scripts/**`,
`src/*/AGENTS.md`, `src/*/CLAUDE.md`, `package.json`, `pnpm-lock.yaml`, `eslint.config.mjs`, `playwright.config.ts`,
`.github/**`, `ARCHITECTURE.md`, `AGENTS.md`.

## 11. Critério → prova
| CA | Prova | Quem confere |
|---|---|---|
| CA-01 | `src/domain/agenda/*.test.ts` verdes | QA |
| CA-02 | pgTAP 120, 130 e 160 | Engenheiro de dados revisor; QA |
| CA-03 | pgTAP 120 e 140; `matriz.test.ts`, `supabase/matriz/matriz.test.ts` e `110_`; testes do servidor e `tests/integracao/agenda.test.ts` | QA; Engenheiro de segurança |
| CA-04 | `tests/integracao/agenda.test.ts` e testes do servidor | Revisor de código |
| CA-05, CA-06 | `e2e/agenda.spec.ts`, `e2e/agenda-estados.spec.ts` e `e2e/inicio.spec.ts` nos 2 projetos | QA |
| CA-07 | checklist `DESIGN.md` §10 nas capturas 390 e 1440 | Revisor de design |
| CA-08 | `e2e/agenda-acessibilidade.spec.ts` nos 2 projetos | QA |
| CA-09 | testes do servidor, pgTAP 150 e e2e (URL, registro, erro) e revisão | Engenheiro de segurança |
| CA-10 | ADR 0007 com cada tabela da spec §7 e a coluna nova; migrations só das reescritas | Auditor de risco |
| CA-11 | histórico da CI; nenhum `supabase link`, `db push`, `--remote` ou `--linked` | Auditor de risco |
| CA-12 | relatórios sem "Bloqueia"; veredito do QA; conferência do dono na prévia | Gerente de projeto |
| CA-13 | `ler-dia.test.ts`, pgTAP 140, `tests/integracao/agenda.test.ts`, `e2e/agenda.spec.ts` | Engenheiro de segurança; QA |
| CA-14 | pgTAP 130 e 140 (cada regra ao criar e ao alterar) | Engenheiro de dados revisor |
| CA-15 | `horarios.test.ts`, `bloqueio.test.ts`, `bloqueios.test.ts`, `tests/integracao/agenda.test.ts`; `agenda.test.tsx` (sem campo de digitar hora) | QA; Revisor de código |
| CA-16 | `git diff` × spec (nenhum arquivo de RF-16 a RF-20) e `e2e/agenda.spec.ts` | Revisor de código; QA |
| Escopo | `git diff --name-only origin/previas...HEAD` comparado com o §10 | Revisor de código |

## 12. Riscos e não verificado
- **Não verificado:** `btree_gist` no banco local (sem ela, a exclusão do §4.3 vira gatilho); desempenho de
  `app.pode(...)` em cada política (ADR 0020, risco aberto); o `Intl` do Node e do Chromium na meia-noite que não
  existe e nos rótulos repetidos do dia de 25 h (o teste do CA-01 prova); `Temporal` no Cloudflare Workers (por isso não
  se usa); `redirect` no `beforeLoad` da rota `/_app/` com a versão do TanStack Router instalada (ler a documentação
  antes da T19); que todo fuso aceito por `estudios_conferir_fuso` tenha deslocamento múltiplo de 15 min (D15; o teste
  de `horarios.ts` confere os fusos usados, não todos).
- **E59 sem resposta:** a grade segue 24 h; se vier A, entram `faixaVisivel` e a mudança da Assumption 1 (§3.2), sem
  arquivo novo.
- O §2.6 e o §2.7 tocam arquivos do Entrar já juntados: se os revisores de D10/D11 recusarem, RF-11 e o envelope ficam
  sem caminho e o plano volta à 5b.
- `membros_ler` deixa todo membro ler o nome de exibição das colegas direto no banco; hoje a API direta está barrada
  pela chave do servidor (ADR 0018 · D16) e o servidor não manda as outras colunas com `proprios`. Se o item 6a ou a
  Equipe abrirem acesso direto, rever.
- Numeração: ADR 0007 e os pgTAP `120_` a `160_` podem colidir com specs do núcleo em branches paralelas; o
  Documentador confere no PR.
