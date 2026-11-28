# Plano · Agenda (primeira versão, item 5 da fila)

- **Spec:** `specs/20261128-020000-agenda/spec.md` (Draft; revisão 5b feita)
- **Escrito por:** Arquiteto de software · **Norma:** modelo C4 e ADR (mais Clean Architecture, Twelve-Factor, WCAG 2.2,
  OWASP ASVS 4.0.3 V4 e boas práticas do Postgres e do Supabase) · **Revisão:** pendente (etapa 5 Analista de
  requisitos; 5b Gerente de projeto)
- **Decisões técnicas deste plano:** `docs/adr/0006-agenda-tempo-idiomas-e-tetos.md`. **Decisões de banco:**
  `docs/adr/0007-agenda-tabelas-do-antigo.md`, escrito pelo Engenheiro de dados na tarefa T3 (não neste plano).
- **Bases lidas em 28/11/2026 (só leitura, nada editado lá):**
  - item 2 (`chore/fundacao-tecnica`): `plan.md`, ADR 0002, `package.json`, `eslint.config.mjs`, `src/`;
  - item 3 (`feat/banco-ligacao`): `plan.md` §3 a §5 e ADR 0005 (`public.estudios`, `public.membros`,
    `app.estudio_da_sessao()`, `app.papel_da_sessao()`, `app.eh_dona()`, molde `supabase/moldes/isolamento_tabela_test.sql`).
    As migrations de lá existem só como arquivos vazios (em construção): **os nomes vêm do plano, não do código**;
  - item 4 (`feat/design-system-codigo`): `plan.md` e ADR 0004 (tokens em `src/app/estilos/tokens.css`, componentes
    `src/app/ui/*`, ícones só por `src/app/ui/icone.tsx`, `@axe-core/playwright`);
  - spec do Agendamento (`feat/agendamento`, Draft), só para alinhar a regra de conflito (RF-04 de lá).
- **Conferido no código instalado** (item 2, `node_modules`): `createServerFn` com `.validator(...)` e `.middleware(...)`
  em `@tanstack/start-client-core@1.170.39`; o validador aceita Standard Schema (`router-core` `validators.d.ts`);
  `getCookie`, `setCookie`, `getRequest` em `@tanstack/start-server-core@1.169.45`. Node 26.13.1 tem `Intl` e `Temporal`.

## 1. Resumo (C4)
**Contexto:** dona, recepção e profissional usam a tela Agenda; nenhum sistema externo novo.
**Contêiner:** o app do item 2 (TanStack Start) e o banco do item 3. A Agenda é o **primeiro módulo que liga
`src/data` ao banco** (item 3, `plan.md` §8).
**Componentes (fluxo de uma leitura do dia):**

```
/agenda?dia=AAAA-MM-DD  (src/app/routes/agenda.tsx, só a data na URL: RNF-04)
   │ loader chama
   ▼
src/server/agenda/ler-dia.ts ── 6 portas (quem é · estúdio da sessão · papel · esquema · banco com trava · registro)
   │ usa regras puras                        │ lê com a sessão da pessoa
   ▼                                         ▼
src/domain/agenda/* (dia, bloqueio,       src/data/agenda/* ──► public.bloqueios + public.membros + public.estudios
grade, acesso)                                                     (RLS: org_id = app.estudio_da_sessao())
```

Gravações (criar, alterar, excluir bloqueio) seguem o mesmo caminho por `src/server/agenda/bloqueios.ts`.

## 2. Lacunas para o Analista de requisitos (a spec não cobre; não decido, `AGENTS.md` §4)
Achadas ao planejar. Cada uma com recomendação; o plano abaixo funciona com a recomendação e diz o que muda na outra.

- **L-1 · Login, sessão e registro (portas 1, 2 e 6) não têm spec.** O RF-09 e o CA-03 pedem as 6 portas e "sem login,
  nada", mas não existe tela de entrar, leitura da sessão no servidor, ligação do app ao banco nem a tabela do
  registro (o item 3, `plan.md` §8, deixa a auditoria para "spec própria, antes do primeiro módulo que grava").
  Sem login o dono também não confere a Agenda na prévia (CA-12). Os 7 módulos do núcleo precisam da mesma peça.
  - **L-1·A (recomendo):** spec própria "Entrar e camada de serviço" (portas 1 a 6 em `src/server/portas/`, cliente
    do banco em `src/data/cliente.ts`, tabela do registro, tela Entrar), antes de construir qualquer módulo do núcleo.
    É ordem da fila: vai ao dono pelo Gerente de projeto. A Agenda usa o contrato do §5.1.
  - **L-1·B:** tudo isso entra nesta spec (arquivos extras no §9.B). Custo: a spec cresce, passa de 3 dúvidas de acesso
    (tela de entrar e prazo de guarda do registro são decisões do dono) e o `AGENTS.md` §4 manda dividir; os outros
    módulos esperam a Agenda.
- **L-2 · Nome no cabeçalho da coluna.** `public.membros` não tem nome (ADR 0005 · T2 deixou "o nome da profissional"
  para esta spec). A spec não diz de onde vem o nome nem quem o grava (é dado pessoal da equipe). Recomendo: uma
  coluna de nome de exibição (só o que aparece na coluna), gravada por tarefa interna até existir a Equipe; em
  desenvolvimento, só nomes fictícios. Forma exata no banco: Engenheiro de dados, tarefa T3.
- **L-3 · Peças que o `DESIGN.md` não tem.** Grade de horas, cabeçalho da coluna, cartão do agendamento, bloqueio na
  grade, linha da hora atual, data em pílula com calendário e a escolha do "Equipe N de M". A spec (§4) manda parar e
  entrar no `DESIGN.md` com o dono primeiro: entram pela ficha visual (etapa 6, tarefa T2), nunca na construção.
- **L-4 · Banco local para as telas.** O `db:start` do item 2 desliga Auth, API e gateway (`-x gotrue,...,kong,...`); um
  app com login precisa deles nos testes de tela, e o job `telas` da CI hoje não sobe banco. Com L-1·A resolve-se lá;
  com L-1·B, aqui (`package.json`, `.github/workflows/ci.yml`, Engenheiro de DevOps).
- **L-5 (só texto da spec):** o cabeçalho diz "Branch: `feat/agenda` (da `previas`)", mas a branch é empilhada sobre
  as bases (§10). Ajustar a linha.

## 3. Dúvidas E26 em aberto: o plano usa a recomendação; o que muda em cada outra
A resposta vira **uma constante** em `src/domain/agenda/acesso.ts` e **uma** versão das políticas; não se constroem as
três variantes nem chave de liga e desliga.

| Dúvida | Com a recomendação (base deste plano) | Se o dono escolher outra |
|---|---|---|
| E26·1 · o que a profissional vê | **B:** lê todas as linhas do estúdio; nas colunas das outras, o servidor tira o motivo do bloqueio e manda só "Bloqueio" (e, quando o Agendamento existir, só "ocupado"). A máscara é regra de `acesso.ts`, aplicada em `ler-dia.ts` antes de a resposta sair | **A:** sem máscara (menos código, teste 130 lê tudo). **C:** a política de leitura de `bloqueios` passa a `S and (papel <> 'profissional' or profissional_id = auth.uid())`; a profissional vê só a própria coluna ("Equipe 1 de 1"); mudam `acesso.ts`, a migration M2, os testes 130 e 140 e o e2e da profissional |
| E26·2 · quem cria, altera e exclui bloqueio | **A:** dona e recepção em qualquer profissional do estúdio; profissional só com `profissional_id = auth.uid()` (políticas de insert, update e delete com essa condição; o servidor confere antes, porta 3) | **B:** políticas de escrita só para `dona` e `recepcao`; a profissional não vê a entrada de criar bloqueio nem o ⋮. **C:** escrita para qualquer papel do estúdio. Mudam só `acesso.ts`, M2, o teste 130 e o e2e da profissional |
| E26·3 · quem é coluna | **A:** membros ativos com papel `dona` ou `profissional` | **B:** só `profissional` (muda uma condição em `colunas.ts`, `acesso.ts`, na conferência de profissional do bloqueio e no teste 140). **C:** **para o plano**: nasce a tabela de profissionais (o `staff_members` passa de "descartar" a "reescrever"), a ligação do bloqueio muda de `membros` para ela e depende da Equipe; plano refeito e nova 5b |

## 4. Banco (tipo Banco; quem decide é o Engenheiro de dados)

### 4.1 Decisão por tabela do antigo · **Engenheiro de dados decide no passo T3** (ADR 0007, conferido por outra instância)
Sugestões do Arquiteto, por cima das do Analista (spec §7). Nada se copia: "reescrever" é mesma intenção, código novo.

| Tabela (antigo) | Sugestão | Motivo |
|---|---|---|
| `time_blocks` | **reescrever** como `public.bloqueios` | ficam estúdio, profissional, início, fim, motivo e autor; saem `resource_id`, `location_id`, `repeat_rule` (fora da v1) e qualquer tipo ou cor; ligação composta com o estúdio (RN-07) |
| `staff_members` | **descartar** (E26·3·A ou B) | as colunas saem de `public.membros` (item 3); e-mail, telefone, cor e comissão não são da Agenda (RGPD art. 5(1)(c)). Com E26·3·C, **reescrever** (§3) |
| `staff_shifts`, `time_block_types`, `resources`, `agenda_waitlist` | **adiada** | fora da v1 (spec §2.1 e §7) |
| `appointments` | **na spec do Agendamento** | a Agenda só lê, quando a tabela existir |
| (novo) nome de exibição (L-2) | **coluna nova em `public.membros`** por migration própria, ou tabela à parte ligada por `(org_id, user_id)` | o Engenheiro de dados escolhe; a sugestão é a coluna (menos uma ida ao banco por tela) |

### 4.2 Migrations (criadas com `pnpm exec supabase migration new <nome>`, formato do item 2)
| # | Nome | Conteúdo (sugestão; forma final do Engenheiro de dados) |
|---|---|---|
| M1 | `agenda_nome_exibicao` | só se a T3 escolher a coluna: `nome_exibicao text` em `public.membros`, com tamanho máximo; grava só a dona do estúdio (privilégio por coluna) ou tarefa interna |
| M2 | `agenda_bloqueios` | tabela, RLS ligada, `revoke all` de `anon` e `authenticated`, `grant` por coluna, políticas, índices e restrições do §4.3 |

### 4.3 `public.bloqueios` (sugestão)
| Coluna | Tipo e regra |
|---|---|
| `id` | `uuid primary key default gen_random_uuid()` |
| `org_id` | `uuid not null` |
| `profissional_id` | `uuid not null` |
| `inicio`, `fim` | `timestamptz not null`; `check (fim > inicio)`; `check (fim - inicio >= interval '5 minutes')` (RN-03) |
| `motivo` | `text null`, `check (char_length(motivo) <= 200)` (RN-03) |
| `criado_por` | `uuid not null default auth.uid()` (quem gravou; não é registro de auditoria) |
| `criado_em` | `timestamptz not null default now()` |

- **Ligação composta (RN-07):** `foreign key (org_id, profissional_id) references public.membros (org_id, user_id)`: a
  chave primária `(org_id, user_id)` do item 3 serve de alvo; um bloqueio nunca aponta para pessoa de outro estúdio.
- **Mesmo dia do estúdio (RN-03):** a regra é de `src/domain` (com teste); no banco, defesa por gatilho que lê
  `public.estudios.fuso_horario` (o Engenheiro de dados decide se entra).
- **Sem sobreposição entre bloqueios (RN-04), defesa no banco:** restrição de exclusão
  `exclude using gist (org_id with =, profissional_id with =, tstzrange(inicio, fim, '[)') with &&)` (encostar não
  conflita); pede a extensão `btree_gist` (não verificado no banco local, §12). Conflito **bloqueio × agendamento** só
  pode ser conferido no banco quando a tabela do Agendamento existir: fica com a spec do Agendamento (RF-04 de lá), nas
  duas direções; até lá, a Agenda confere no servidor com a mesma regra pura.
- **Índices:** `(org_id, profissional_id, inicio)` (consulta do dia e conflito); o índice da exclusão.
- **Políticas** (`to authenticated`; `S` = `org_id = (select app.estudio_da_sessao())`; `P` = `(select app.papel_da_sessao())`):
  ler `S`; criar, alterar e apagar `S and (P in ('dona','recepcao') or (P = 'profissional' and profissional_id = (select auth.uid())))`
  (E26·2·A); alterar com `using` e `with check` iguais; ninguém grava `org_id` nem `criado_por` de outro (privilégio por
  coluna: `update (profissional_id, inicio, fim, motivo)`). A profissional do bloqueio tem de ser coluna (E26·3·A:
  papel `dona` ou `profissional`, ativa): conferência no `with check` ou no gatilho, à escolha do Engenheiro de dados.

### 4.4 Testes pgTAP (`supabase/tests/database/`, banco local, `pnpm db:test`)
| Arquivo | Prova |
|---|---|
| `110_agenda_bloqueios_isolamento_test.sql` | cópia do molde do item 3 para `bloqueios`: A não lê, cria, altera nem apaga de B; sem papel e sem login, nada (CA-02, CA-03) |
| `120_agenda_bloqueios_regras_test.sql` | profissional de outro estúdio recusada (ligação composta); fim ≤ início, menos de 5 min e motivo de 201 caracteres recusados; sobreposição recusada; encostar aceito; dois dias recusado se o gatilho entrar (CA-02, RN-03, RN-04) |
| `130_agenda_bloqueios_papeis_test.sql` | E26·2·A: dona e recepção gravam em qualquer coluna; profissional só na própria; recepção não vira coluna (CA-03) |
| `140_agenda_colunas_test.sql` | só se M1 entrar: nome de exibição isolado por estúdio; só a dona grava; `anon` nada |

O teste `010_base_estrutura_test.sql` do item 3 já confere que toda tabela de `public` tem `org_id` e RLS: passa a
valer também para `bloqueios`.

## 5. Código por camada (regra de dependência do `ARCHITECTURE.md` §3, já travada pelo lint do item 2)

### 5.1 Contrato que a Agenda usa da camada de serviço (L-1)
A Agenda **não** escreve as portas. Usa (de `src/server/portas/`, da spec da L-1·A) uma função que monta a ação:
recebe a permissão pedida, o esquema da entrada e o trabalho; antes do trabalho resolve as portas 1 a 4 e entrega um
contexto com `usuarioId`, `orgId` e `papel` (lidos da sessão; o `orgId` nunca vem da entrada), e o acesso ao banco
com a sessão da pessoa (porta 5); depois grava o registro (porta 6) com nome do evento e identificadores, sem texto
livre. Erros saem como **códigos** (ex.: `sem_login`, `sem_permissao`, `entrada_invalida`, `conflito`), nunca com dado.
Se a spec da L-1·A der outro formato, só `ler-dia.ts` e `bloqueios.ts` se ajustam.

**Recomendação para aquela spec (não decidida aqui, sem ADR):** ligar o servidor ao banco pelo `@supabase/supabase-js`
2.119.2 com `@supabase/ssr` 0.12.7 (MIT; o `ssr` pede `supabase-js ^2.114.0`), com a sessão da pessoa em cookie que o
navegador não lê e **nenhum cliente do banco no navegador**, para que a regra "o navegador nunca fala com o banco"
(`ARCHITECTURE.md` §4) valha de fato; validação por `zod` 4.6.7 (MIT; Standard Schema, aceito pelo `.validator` do
TanStack Start). Alternativa: ligação direta ao Postgres por transação com o papel e o token da pessoa (como os
testes pgTAP fazem), sem a API do Supabase exposta. Versões lidas por `npm view` em 28/11 (todas com mais de 3 dias).

### 5.2 `src/domain/agenda/` (TypeScript puro, com teste; Engenheiro de software)
| Arquivo | O que tem | Regras |
|---|---|---|
| `tipos.ts` | `Instante` (milissegundos UTC), `Intervalo`, `DiaDoEstudio` (`AAAA-MM-DD` + fuso), `ItemDaGrade` (bloqueio ou agendamento), `Coluna`, `Papel` | — |
| `dia.ts` | limites do dia no fuso (`inicioDoDia`, `fimDoDia`), hoje no fuso, dia anterior e seguinte, corte do item na borda do dia | RN-01, RN-02, RF-01, RF-02 |
| `bloqueio.ts` | validar bloqueio (fim > início, ≥ 5 min, mesmo dia, motivo ≤ 200) e achar conflito com uma lista de ocupados `[início, fim)` da mesma profissional, ignorando Cancelado e Ausência e o próprio item ao alterar | RN-03, RN-04 |
| `grade.ts` | distribuir itens sobrepostos lado a lado (faixas por coluna, sem esconder nenhum); aplicar filtros (status, bloqueio; Cancelado escondido por padrão); contar filtros ligados; conferir o teto de itens | RN-05, RN-06, RN-08, RF-06 |
| `acesso.ts` | quem é coluna (E26·3), o que cada papel pode gravar (E26·2), o que sai mascarado para cada papel (E26·1) | RN-07, §3 |

- Fuso e "agora" chegam por parâmetro (`src/domain/AGENTS.md`). Cálculo do dia só com `Intl.DateTimeFormat` (ADR 0006 · D2).
- Testes obrigatórios (CA-01): `Europe/Lisbon` e `America/New_York` em dia de 23 h e de 25 h; fuso em que a meia-noite
  não existe no dia da troca (`America/Santiago`, e `America/Sao_Paulo` em 04/11/2018, quando o Brasil ainda trocava
  à meia-noite): o dia começa no primeiro instante que tem aquela data; item que cruza a meia-noite nos dois dias;
  encostar não é conflito; Cancelado e Ausência não conflitam; teto passado gera aviso.
- `src/domain/exemplo.ts` e `exemplo.test.ts` **saem** (o item 2 os marcou "sai quando entrar a primeira regra real").

### 5.3 `src/server/agenda/` (Engenheiro de software)
| Arquivo | O que tem |
|---|---|
| `esquemas.ts` | esquemas de entrada: `dia` (`AAAA-MM-DD`), bloqueio (profissional `uuid`, data, início, fim em passos do dia, motivo opcional ≤ 200), `id` do bloqueio. **Sem campo de estúdio**; chave desconhecida é descartada (CA-04) |
| `ler-dia.ts` | ação de leitura (`GET`): estúdio, fuso e idioma da sessão → limites do dia (`dia.ts`) → colunas → bloqueios do dia com teto (`limit` teto + 1) → máscara de `acesso.ts` → resposta. **No máximo 3 idas ao banco** (ADR 0006 · D3) |
| `bloqueios.ts` | `criarBloqueio`, `alterarBloqueio`, `excluirBloqueio` (`POST`): porta 3 por `acesso.ts`; regras de `bloqueio.ts` com os ocupados da profissional naquele dia; gravação; registro `agenda.bloqueio.criado`, `.alterado`, `.excluido` com `bloqueio_id` e `profissional_id`, **sem o motivo** (RF-09). Violação da exclusão do banco volta como `conflito` |
| `ler-dia.test.ts`, `bloqueios.test.ts` | com o acesso ao banco trocado por um falso: estúdio no pedido ignorado (CA-04); sem login e sem papel, nada lido nem gravado (CA-03); profissional não grava na coluna de outra (E26·2·A); motivo mascarado nas outras colunas (E26·1·B); motivo nunca no registro nem no erro (CA-09); número de idas ao banco ≤ 3 (RNF-02) |

### 5.4 `src/data/agenda/` (Engenheiro de software; consultas conferidas pelo Engenheiro de dados)
| Arquivo | O que tem |
|---|---|
| `estudio.ts` | fuso, idioma e moeda do estúdio da sessão (uma ida) |
| `colunas.ts` | membros ativos que são coluna (E26·3·A), com o nome de exibição (L-2), ordenados por nome (uma ida) |
| `bloqueios.ts` | bloqueios que cruzam `[inicioDoDia, fimDoDia)` das colunas pedidas, com `limit`; criar, alterar, apagar por `id` (a trava faz o resto). Nenhum filtro por `org_id` vindo de fora: a RLS decide |

Sem teste de unidade próprio (são consultas); a prova é o pgTAP (§4.4) e o e2e (§7).

### 5.5 `src/app/` (Engenheiro de software; desenho do Designer de produto na ficha)
- **Rota** `src/app/routes/agenda.tsx`: `validateSearch` aceita só `dia` (`AAAA-MM-DD`); sem `dia`, hoje no fuso do
  estúdio (RF-01). O `loader` chama `ler-dia`. Nada além da data na URL (RNF-04).
- **Navegação** `src/app/navegacao.ts`: o mapa único do `DESIGN.md` §7, com a Agenda ligada e os outros módulos "em
  desenvolvimento", para o menu da estrutura do item 4 (RC-18, RC-19).
- **Tela** em `src/app/paginas/agenda/`, só com componentes do item 4 (`botao`, `contador`, `seletor`, `campos`,
  `etiqueta-status`, `camadas`, `estados`, `estrutura`, `icone`) e as peças novas que o dono aprovar na ficha (L-3):

| Arquivo | O que tem |
|---|---|
| `agenda.tsx` | composição: barra do topo (1440) ou cabeçalho e barra de baixo (390), barra da grade, grade, estados (§4 da spec) |
| `barra.tsx` | Hoje, setas, data em pílula com calendário, Dia ▾ (só Dia; os outros "em desenvolvimento"), Equipe N de M, Filtros ▾ com contador, Lista de espera e Opções "em desenvolvimento" |
| `grade.tsx` | grade de 24 h por coluna, rolagem até a hora atual ou ao primeiro item; navegação por teclado (RNF-03) |
| `cartao.tsx` | cartão do agendamento (hora, cliente, serviço, status; só o ícone no cartão pequeno, nome para o leitor) e bloqueio (`lock` + "Bloqueio" + motivo, se a pessoa pode ver) |
| `bloqueio-painel.tsx` | criar e alterar: painel 480 à direita (1440) ou folha de baixo (390); Excluir no ⋮ com janelinha e aviso com "Desfazer" |
| `filtros.tsx` | painel (1440) e folha (390): status e bloqueio; "Limpar filtros"; "Mostrar N <itens>" |
| `equipe.tsx`, `equipe-guardada.ts` | escolha de colunas; guarda no aparelho só os identificadores escondidos, por estúdio (spec Assumption 2) |
| `agenda.css` | só `var(--...)` do `tokens.css` (regra RT-9 do item 4) |
| `agenda.test.tsx` | `renderToString`: uma só ação preta; status com nome acessível; nenhum texto fixo fora do arquivo de idioma |

- **Idiomas (RNF-05)** em `src/app/i18n/`: `pt.ts` (fonte das chaves), `es.ts`, `en.ts`, `textos.ts` (escolha pelo
  idioma do estúdio, troca de `{marcadores}`, plural por `Intl.PluralRules`), `formatar.ts` (data e hora por
  `Intl.DateTimeFormat` no idioma e no fuso do estúdio), `i18n.test.ts` (as três têm as mesmas chaves, nenhuma vazia,
  os mesmos marcadores). Código de erro do servidor vira texto aqui. Sem biblioteca (ADR 0006 · D1).
- **Agendamento ainda não construído (RF-08):** "Novo agendamento", "Agendar" e o toque no cartão ficam "em
  desenvolvimento"; a grade mostra só bloqueios. Quando a spec do Agendamento entrar, ela acrescenta a leitura dos
  agendamentos em `src/data` e a terceira ida ao banco vira quarta (teto passa a 4, no ADR dela).

## 6. Desfazer, tetos e estados (decisões técnicas, ADR 0006)
- **Desfazer a exclusão:** o aviso guarda na memória da tela os dados do bloqueio excluído; "Desfazer" chama
  `criarBloqueio` com eles (mesmas portas, mesmo conflito; novo `id`; registro de criação). Se outro item ocupou o
  horário no meio, a tela diz o conflito. Nada fica guardado no banco depois de excluído (D4).
- **Teto de itens por dia:** 500 itens na consulta do dia (todas as colunas à vista); passou, a tela avisa e sugere
  esconder colunas (RN-08) (D3).
- **Teto de idas ao banco por tela:** 3 na leitura do dia (estúdio, colunas, bloqueios) e 3 numa gravação (ocupados
  da profissional, gravar, registro), além do que a camada de serviço fizer para a sessão (D3).
- **Estado de erro:** "Tentar de novo" refaz o `loader`. Carregando: o componente de estados do item 4 (atraso de 0,3 s).

## 7. Testes de tela (Playwright, projetos `celular` 390 e `computador` 1440 do item 2)
Dados só fictícios, criados no banco **local** pelo preparo do teste (estúdios A e B, dona, recepção, duas profissionais,
nomes inventados). A sessão de teste vem da camada de serviço (L-1).

| Arquivo | Prova |
|---|---|
| `e2e/preparo/agenda-dados.ts` | cria e apaga os dados fictícios do teste no banco local |
| `e2e/agenda.spec.ts` | CA-05: abre em hoje; anterior, seguinte, calendário e Hoje; Equipe N de M; filtros, contador e "Limpar filtros"; criar, alterar, conflito recusado, excluir com janelinha e "Desfazer"; profissional sem ⋮ nas colunas das outras e sem motivo delas (E26·1·B, E26·2·A). CA-09: a URL só tem `dia`; o motivo e os nomes não aparecem em URL nem no console |
| `e2e/agenda-estados.spec.ts` | CA-06: carregando (resposta atrasada por `page.route`), vazio, sem resultado, sem profissional, erro (resposta 500 por `page.route`) |
| `e2e/agenda-acessibilidade.spec.ts` | CA-08: `AxeBuilder` com `wcag2a`, `wcag2aa`, `wcag21a`, `wcag21aa`, `wcag22aa` (o mesmo do item 4) com a tela fechada e com painel, folha e janelinha abertos; grade percorrida por teclado; status com nome acessível |

## 8. Papéis
| Etapa | Papel |
|---|---|
| Branch empilhada (T1) | Engenheiro de DevOps |
| Ficha visual e peças novas do `DESIGN.md` (T2, etapa 6) | Designer de produto; confere o Revisor de design; aprova o dono |
| Decisão por tabela e migrations, testes do banco (T3 a T5) | Engenheiro de dados |
| Domínio, servidor, dados, telas, idiomas, e2e (T6 a T16) | Engenheiro de software |
| Revisar código | Revisor de código |
| Revisar banco e conferir o ADR 0007 item por item (E16·1) | Engenheiro de dados (outra instância, que não construiu) e Auditor de risco |
| Revisar acesso e privacidade (E26, CA-09) | Engenheiro de segurança e Auditor de risco |
| Revisar a tela (checklist `DESIGN.md` §10, capturas 390 e 1440) | Revisor de design |
| Veredito CA-01 a CA-12 | Analista de qualidade (QA) |
| Conferir o pedido · registros · pedido de merge | Analista de requisitos · Documentador · Gerente de projeto |

## 9. Arquivos (lista FECHADA)
Fora desta lista nada muda (`AGENTS.md` §6). Arquivo que uma ferramenta crie fora daqui: parar e relatar.

### 9.A Com L-1·A (recomendado)
**Banco (Engenheiro de dados):** `supabase/migrations/<ts>_agenda_nome_exibicao.sql` (só se a T3 escolher a coluna) ·
`supabase/migrations/<ts>_agenda_bloqueios.sql` · `supabase/tests/database/110_agenda_bloqueios_isolamento_test.sql` ·
`120_agenda_bloqueios_regras_test.sql` · `130_agenda_bloqueios_papeis_test.sql` · `140_agenda_colunas_test.sql` (só com
M1) · `docs/adr/0007-agenda-tabelas-do-antigo.md`.

**Domínio:** `src/domain/agenda/{tipos,dia,bloqueio,grade,acesso}.ts` e `{dia,bloqueio,grade,acesso}.test.ts`; apagar
`src/domain/exemplo.ts` e `src/domain/exemplo.test.ts`.

**Servidor:** `src/server/agenda/{esquemas,ler-dia,bloqueios}.ts` e `{ler-dia,bloqueios}.test.ts`.

**Dados:** `src/data/agenda/{estudio,colunas,bloqueios}.ts`.

**Telas:** `src/app/routes/agenda.tsx` · `src/app/routeTree.gen.ts` (gerado) · `src/app/navegacao.ts` ·
`src/app/paginas/agenda/{agenda,barra,grade,cartao,bloqueio-painel,filtros,equipe}.tsx` ·
`src/app/paginas/agenda/equipe-guardada.ts` · `src/app/paginas/agenda/agenda.css` ·
`src/app/paginas/agenda/agenda.test.tsx` · `src/app/i18n/{pt,es,en,textos,formatar}.ts` · `src/app/i18n/i18n.test.ts`.

**Testes de tela:** `e2e/preparo/agenda-dados.ts` · `e2e/agenda.spec.ts` · `e2e/agenda-estados.spec.ts` ·
`e2e/agenda-acessibilidade.spec.ts`.

**Ficha visual (Designer de produto):** `specs/20261128-020000-agenda/ficha-visual.md` e `specs/20261128-020000-agenda/ficha/*.png`.

**Texto:** `DESIGN.md`, **só** as linhas das peças da L-3 que o dono aprovar na ficha (Designer de produto) ·
`docs/STATUS.md`, `docs/BACKLOG.md`, `CHANGELOG.md`, `docs/decisoes/2026-11-27-fundacao.md` (respostas E26 e das
lacunas) (Documentador).

**Processo:** `specs/20261128-020000-agenda/{spec.md,plan.md,tasks.md}` · `docs/adr/0006-agenda-tempo-idiomas-e-tetos.md`.

**Intactos:** `src/app/ui/**` e `src/app/estilos/**` (peça nova da L-3 que for componente geral pede ajuste deste
plano), `src/server/portas/**` e `src/data/cliente.ts` (da L-1·A), `src/*/AGENTS.md`, `src/*/CLAUDE.md`,
`supabase/config.jsonc`, `supabase/seed.sql`, as migrations dos itens 2 e 3, `package.json`, `pnpm-lock.yaml`,
`eslint.config.mjs`, `playwright.config.ts`, `.github/**`, `ARCHITECTURE.md`, `AGENTS.md`.

### 9.B Arquivos a mais só se o dono escolher L-1·B (plano volta à 5b antes)
`package.json` e `pnpm-lock.yaml` (`@supabase/supabase-js`, `@supabase/ssr`, `zod`, scripts do banco para as telas) ·
`src/server/portas/*.ts` e testes · `src/data/cliente.ts` · migration e teste pgTAP da tabela do registro ·
rota e página Entrar · `e2e/preparo/sessao.ts` · `playwright.config.ts` · `.github/workflows/ci.yml` (job `telas` com
banco; Engenheiro de DevOps) · um ADR da camada de serviço.

## 10. Branch (decisão do Engenheiro de DevOps)
- `feat/agenda` recebe, **por merge**, a `feat/banco-ligacao` e a `feat/design-system-codigo` (as duas já trazem a
  `chore/fundacao-tecnica`); com L-1·A, também a branch da camada de serviço. PR de rascunho empilhado; nunca se junta
  numa base. Quando as bases entrarem na `previas`, a base do PR passa à `previas`, antes do pedido de merge.
- Conflito esperado só em `src/app/routeTree.gen.ts` (regenera-se, não se edita à mão). Antes de construir: conferir
  que os arquivos das três bases do cabeçalho estão na branch.

## 11. Critério → prova
| CA | Prova | Quem confere |
|---|---|---|
| CA-01 | `src/domain/agenda/*.test.ts` verdes (23 h, 25 h, meia-noite que não existe, cruzar a meia-noite, encostar, teto) | QA |
| CA-02 | pgTAP 110 e 120 verdes | Engenheiro de dados revisor; QA |
| CA-03 | pgTAP 110 e 130; `ler-dia.test.ts` e `bloqueios.test.ts` | QA; Engenheiro de segurança |
| CA-04 | `ler-dia.test.ts` e `bloqueios.test.ts` (estúdio no pedido ignorado) | Revisor de código |
| CA-05, CA-06 | `e2e/agenda.spec.ts` e `e2e/agenda-estados.spec.ts` verdes nos 2 projetos | QA |
| CA-07 | checklist `DESIGN.md` §10 sobre as capturas 390 e 1440 | Revisor de design |
| CA-08 | `e2e/agenda-acessibilidade.spec.ts` verde nos 2 projetos | QA |
| CA-09 | testes do servidor e do e2e (URL, registro, erro) e revisão | Engenheiro de segurança |
| CA-10 | ADR 0007 com cada tabela da spec §7, conferência preenchida; migrations só das reescritas | Auditor de risco |
| CA-11 | histórico da CI; nenhum `supabase link`, `db push`, `--remote` ou `--linked` | Auditor de risco |
| CA-12 | relatórios sem "Bloqueia"; veredito do QA; conferência do dono na prévia | Gerente de projeto |
| Escopo | `git diff --name-only <base>...HEAD` comparado com o §9 | Revisor de código |

## 12. Riscos e não verificado
- **L-1 é bloqueante para construir** (§2): sem a camada de serviço não há portas 1, 2 e 6, nem sessão no e2e.
- Item 3 e item 4 não estão construídos: nomes de funções, tabelas e componentes vêm dos planos deles. Se mudarem, este
  plano se ajusta (nova 5b).
- **Não verificado:** a extensão `btree_gist` no banco local do Supabase (sem ela, a exclusão do §4.3 vira gatilho);
  se `@supabase/ssr` 0.12.7 grava o cookie da sessão fora do alcance do JavaScript da página e se `supabase-js` roda
  no Cloudflare Workers (spec da L-1); o comportamento do `Intl` do Node 26 e do Chromium do Playwright na meia-noite
  que não existe (o teste do CA-01 prova); se o Cloudflare Workers tem `Temporal` (por isso não se usa, ADR 0006 · D2);
  a documentação online do `createServerFn` (conferido só no `.d.ts` instalado: o nome é `.validator`).
- Numeração dos ADRs: 0006 e 0007 podem colidir com as specs dos outros módulos do núcleo, escritas em paralelo; o
  Documentador confere no PR e renumera se preciso.
- Ordem das `<ts>` das migrations: as da Agenda precisam vir depois das do item 3 (data e hora maiores); conferir ao
  criar.
