# Plano · Ligar o banco: base da trava por estúdio (item 3 da fila)

- **Spec:** `specs/20261128-010000-banco-ligacao/spec.md` (Draft, revisão 5b feita)
- **Escrito por:** Engenheiro de dados (banco), pelo Arquiteto de software · **Norma:** modelo C4 e ADR; boas práticas
  oficiais do Postgres e do Supabase · **Revisão:** pendente (etapa 5 Analista de requisitos; 5b Gerente de projeto)
- **Decisões técnicas:** `docs/adr/0005-banco-base-trava-por-estudio.md` (saída de cada item do antigo e desenho)
- **Base técnica:** item 2 (`chore/fundacao-tecnica`): `supabase/config.jsonc`, migration `20261128000921_fundacao.sql`,
  `supabase/tests/database/fundacao_test.sql`, scripts `db:start`, `db:test`, `db:stop`, ADR 0002 · D10.
- **Antigo lido** (E22·B, só leitura, só migrations da base): os 4 arquivos listados no ADR 0005. Nenhum seed, dado
  ou segredo aberto.

## 1. Resumo (C4)
**Contexto:** nada muda para quem usa; nenhum sistema externo novo.
**Contêiner:** o banco Postgres do Supabase ganha a base da trava. Só `src/server` → `src/data` falará com ele, com a
sessão da pessoa (`ARCHITECTURE.md` §3 e §4); nenhuma linha de app nesta spec.
**Componentes no banco:**

```
auth.users ──< public.membros >── public.estudios        (tabelas, RLS ligada)
                   ▲
                   │ lê (SECURITY DEFINER, search_path '')
app.estudio_da_sessao() · app.papel_da_sessao() · app.eh_dona() · app.escolher_estudio(p)
                   ▲
                   │ usadas por
políticas RLS de estudios e membros (e, depois, de toda tabela de módulo)
```

## 2. Construção empilhada (E22·B)
- Os documentos (spec, plano, tarefas, ADR 0005) ficam na `feat/banco-ligacao`.
- A construção sai de uma branch nova criada **a partir da `chore/fundacao-tecnica`** (precisa do `supabase/` e da CI do
  item 2). Nome sugerido: `feat/banco-trava-estudio`; quem cria é o Engenheiro de DevOps. PR de rascunho com base na
  `chore/fundacao-tecnica`; depois do merge do item 2, a base do PR passa à `previas`.
- Antes de começar: conferir que a `chore/fundacao-tecnica` ainda tem os arquivos da linha "Base técnica" acima.

## 3. Migrations novas (nesta ordem)
Criadas com `pnpm exec supabase migration new <nome>` (gera `supabase/migrations/<AAAAMMDDHHMMSS>_<nome>.sql`; formato
igual ao `20261128000921_fundacao.sql`). Uma por tabela (spec §11 Assumption 1), mais a da função e a das políticas,
porque as funções leem `membros` e as políticas usam as funções.

| # | Nome | Conteúdo |
|---|---|---|
| M1 | `estudios` | tabela `public.estudios`, RLS ligada sem política (fecha tudo até M4), `revoke all` de `anon` e `authenticated`, gatilho do fuso |
| M2 | `membros` | tabela `public.membros`, RLS ligada sem política, índices, `revoke all` de `anon` e `authenticated` |
| M3 | `trava_por_estudio` | esquema `app`, as 4 funções, `revoke`/`grant` de execução |
| M4 | `politicas_base` | políticas de `estudios` e `membros`; `grant` por coluna a `authenticated` |

### 3.1 `public.estudios` (RF-02, RF-09, CA-13)
| Coluna | Tipo e regra |
|---|---|
| `org_id` | `uuid primary key default gen_random_uuid()` (é o próprio estúdio; mesmo nome das outras tabelas, RG-04) |
| `nome` | `text not null`, `check (char_length(btrim(nome)) between 1 and 120)` |
| `moeda` | `text not null`, `check (moeda ~ '^[A-Z]{3}$')` (ISO 4217), sem padrão |
| `idioma` | `text not null`, `check (idioma in ('pt','es','en'))` (ISO 639-1), sem padrão |
| `fuso_horario` | `text not null`, sem padrão; gatilho `app.conferir_fuso()` `before insert or update of fuso_horario` recusa nome fora de `pg_timezone_names` (código `22023`) |
| `criado_em` | `timestamptz not null default now()` |

O gatilho mora em M1; por isso M1 cria o esquema `app` (`create schema if not exists app`) e M3 só o completa.

### 3.2 `public.membros` (RF-02, RF-04, RF-06)
| Coluna | Tipo e regra |
|---|---|
| `org_id` | `uuid not null references public.estudios(org_id) on delete cascade` |
| `user_id` | `uuid not null references auth.users(id) on delete cascade` |
| `papel` | `text not null`, `check (papel in ('dona','recepcao','profissional'))` |
| `ativo` | `boolean not null default true` |
| `estudio_atual` | `boolean not null default false` |
| `criado_em` | `timestamptz not null default now()` |

Chave `primary key (org_id, user_id)` (serve de índice por `org_id`, RG-04); índice `(user_id)`; índice único parcial
`(user_id) where estudio_atual` (no máximo um estúdio da sessão por pessoa). Sem nome, telefone ou e-mail (ADR 0005 · T2).

### 3.3 Função de checagem de acesso (M3; RF-03, CA-06)
Todas `security definer`, `set search_path = ''`, nomes qualificados (`public.membros`, `auth.uid()`); `revoke all ... from
public, anon`; `grant execute ... to authenticated`; `grant usage on schema app to authenticated`; `revoke all on schema
app from public`. O esquema `app` **não** entra em `api.schemas` (o `config.jsonc` não muda).

| Função | Retorno | Regra |
|---|---|---|
| `app.estudio_da_sessao()` | `uuid` | `org_id` da linha de `membros` com `user_id = auth.uid()`, `ativo` e `estudio_atual`; `null` sem login, sem vínculo ativo ou sem estúdio escolhido. **Sem parâmetro**; não lê nenhuma declaração do token além de `sub` (via `auth.uid()`) |
| `app.papel_da_sessao()` | `text` | `papel` da mesma linha; `null` nos mesmos casos |
| `app.eh_dona()` | `boolean` | `coalesce(app.papel_da_sessao() = 'dona', false)` |
| `app.escolher_estudio(p_org_id uuid)` | `boolean` | `volatile`, `plpgsql`. Sem login → erro `42501`. Sem vínculo ativo da **própria pessoa** em `p_org_id` → erro `42501`, nada muda. Senão, em dois comandos (o índice único é conferido linha a linha): zera `estudio_atual` das linhas da pessoa e liga a de `p_org_id` |

`escolher_estudio` recebe um estúdio, mas só grava a escolha da própria pessoa entre os estúdios em que ela já tem papel;
a checagem (`estudio_da_sessao`) continua sem entrada de fora (ADR 0005 · D2).

## 4. Travas RLS (M4; RF-03 a RF-05, RG-04)
Toda política `to authenticated`; `S` = `org_id = (select app.estudio_da_sessao())`; `D` = `(select app.eh_dona())`.

| Tabela | Ler | Criar | Alterar | Apagar | Privilégio de `authenticated` |
|---|---|---|---|---|---|
| `estudios` | `S` | ninguém | `S and D` (using e with check) | ninguém | `select`; `update (nome, moeda, idioma, fuso_horario)` |
| `membros` | `S or user_id = (select auth.uid())` | with check `S and D` | `S and D` (using e with check) | `S and D` | `select`; `insert (org_id, user_id, papel)`; `update (papel, ativo)`; `delete` |

- `anon` sem nenhum privilégio nas duas tabelas e sem execução nas funções (RF-05).
- Ler as próprias linhas em `membros` deixa a pessoa ver em quais estúdios tem papel (para escolher); não mostra nada
  de estúdio em que ela não tem papel (RF-04).
- Ninguém com login cria ou apaga estúdio, nem grava `estudio_atual` direto: só pela função ou por tarefa interna.
- `service_role` passa por cima da RLS (Supabase); nesta spec nenhuma tarefa interna a usa (RF-08, `SECURITY.md` §2).

## 5. Testes pgTAP de isolamento (CA-03 a CA-07, CA-13)
Em `supabase/tests/database/`, um arquivo por assunto, cada um `begin; select plan(n); ... select * from finish();
rollback;` (molde oficial, igual ao `fundacao_test.sql`). Preparo dentro do próprio arquivo, como `postgres`: pessoas
fictícias escritas do zero em `auth.users` (só `id` e um e-mail `@exemplo.test`, RG-07), estúdios A e B, vínculos.
Login simulado com `set local role authenticated` e `set local request.jwt.claims = '{"sub":"<uuid>","role":"authenticated"}'`
(é o que `auth.uid()` lê); sem login com `set local role anon`. Sem extensão de ajuda de terceiros (reuso: só pgTAP,
que já vem no Supabase).

| Arquivo | Prova |
|---|---|
| `010_base_estrutura_test.sql` | toda tabela de `public` tem `org_id` não nulo e RLS ligada (consulta a `pg_class` e `information_schema`, vale para tabelas futuras); `anon` sem privilégio em tabela de `public`; as 4 funções de `app` são `security definer` com `search_path=''`; `anon` sem execução; `app.estudio_da_sessao` tem 0 parâmetros (CA-03, CA-06) |
| `020_isolamento_estudios_test.sql` | dona de A lê só A; alterar B atinge 0 linhas e B fica igual; criar e apagar estúdio recusado (`42501`); recepção de A não altera A; pessoa sem papel lê 0; `anon` recebe `42501` (CA-04, CA-05) |
| `030_isolamento_membros_test.sql` | dona de A não cria vínculo em B (`42501`), não altera nem apaga vínculo de B (0 linhas); recepção e profissional de A não criam, alteram nem apagam; vínculo inativo não lê nada; gravar `estudio_atual` direto recusado (`42501`); sem papel lê 0; `anon` `42501` (CA-04, CA-05) |
| `040_funcao_acesso_test.sql` | token com `org_id`, `app_metadata.org_id` ou `user_metadata.org_id` de B não muda nada: a função devolve A e só A é lido; `escolher_estudio(B)` sem vínculo em B → `42501` e continua A; pessoa com papel em A e B escolhe B e passa a ler só B; sem login → `null` (CA-06) |
| `050_estudio_configuracao_test.sql` | idioma `fr`, `PT` ou nulo recusado; moeda `eur`, `EU` ou nula recusada; fuso `Marte/Base` ou nulo recusado, também ao alterar; `EUR`/`es`/`Europe/Madrid` aceito (CA-13) |

**Molde (CA-07):** `supabase/moldes/isolamento_tabela_test.sql`, com marcadores `<tabela>` e `<coluna>`, as mesmas
provas de ler/criar/alterar/apagar entre A e B, sem papel e sem login. Fica **fora** de `supabase/tests/` para não rodar
como teste; a spec de cada módulo copia para `supabase/tests/database/`.

## 6. Arquivos (lista FECHADA)
Nenhum outro arquivo muda. `supabase/config.jsonc`, `supabase/seed.sql`, `src/**`, `package.json` e a migration da
fundação **não** mudam.

| Arquivo | Papel | Fase |
|---|---|---|
| `supabase/migrations/<ts>_estudios.sql` | Engenheiro de dados | A |
| `supabase/migrations/<ts>_membros.sql` | Engenheiro de dados | A |
| `supabase/migrations/<ts>_trava_por_estudio.sql` | Engenheiro de dados | A |
| `supabase/migrations/<ts>_politicas_base.sql` | Engenheiro de dados | A |
| `supabase/tests/database/010_base_estrutura_test.sql` a `050_estudio_configuracao_test.sql` (5 arquivos, §5) | Engenheiro de dados | A |
| `supabase/moldes/isolamento_tabela_test.sql` | Engenheiro de dados | A |
| `docs/adr/0005-banco-base-trava-por-estudio.md` (escrito nesta etapa; a conferência é preenchida na revisão) | Engenheiro de dados; conferência de outros | A |
| `.github/workflows/banco-dev.yml` | Engenheiro de DevOps | B |
| `specs/20261128-010000-banco-ligacao/spec.md` (só as linhas de aprovação) | Analista de requisitos | — |
| `docs/STATUS.md`, `docs/BACKLOG.md`, `CHANGELOG.md`, `docs/decisoes/2026-11-27-fundacao.md` (respostas E24·1 e E24·2) | Documentador | — |

## 7. Como o banco remoto muda (só a CI; a IA nunca) · Fase B
- **Fase A** (este PR, já agora): tudo só no banco local; o job `banco` do `ci.yml` do item 2 (`db:start` → `db:test` →
  `db:stop`) roda as migrations e os testes novos sem mudar nada. Proibido em script, tarefa ou chat: `supabase link`,
  `db push`, `--remote`, `--linked`, MCP do Supabase com escrita (`AGENTS.md` §1).
- **Fase B** só começa depois de E24·1 e E24·2 respondidas e gravadas. `.github/workflows/banco-dev.yml`:
  - gatilho `push` na `previas` com mudança em `supabase/migrations/**` (ou seja, depois do merge autorizado e gravado na
    spec, CA-08); nunca `pull_request`;
  - `environment: desenvolvimento` com aprovação obrigatória do dono (proteção de ambiente do GitHub); o endereço do
    banco fica só como segredo desse ambiente, posto pelo dono (passo a passo com link e cliques no pedido de merge);
  - `permissions: contents: read`, ações fixadas por commit, `persist-credentials: false` (ADR 0002 · D6, D7);
  - passos: o preparo do item 2 → aplicar as migrations no banco de desenvolvimento pela Supabase CLI (comando e opções
    exatos lidos na referência oficial da CLI 3.4.0 na hora de construir; primeiro em modo de ensaio, depois de verdade)
    → `supabase test db` contra o mesmo banco para provar a trava lá;
  - se E24·2·A: o histórico de migrations do antigo nesse banco precisa ser tratado antes do primeiro envio; isso é um
    passo destrutivo, desenhado só depois da resposta, com revisão do Auditor de risco, e não roda sem pedido próprio ao
    dono. Se E24·2·B ou E24·1·B: projeto novo na UE, sem esse passo.
- Sem a Fase B pronta, o PR pode ficar verde mas **não** é pedido o merge (CA-08, CA-09, CA-11 dependem dela).

## 8. Onde entram os itens fora de escopo (spec §8)
- **Auditoria (porta 6):** spec própria, antes do primeiro módulo que grava dado de cliente; tabela só de inserção, com
  `org_id`, RLS e prazo de guarda; respeita E6·1 e E6·2 (RG-08).
- **Cópia diária (E5·3):** spec de produção, com o Engenheiro de DevOps (Cloudflare R2 e Backblaze B2, `ARCHITECTURE.md` §12).
- **RF-08 (endereço e chaves no ambiente):** nesta spec só a CI usa o endereço, como segredo do ambiente (§7). A leitura
  pelo app entra na primeira spec que ligar `src/data`. Analista confere na etapa 5 se aceita essa divisão.

## 9. Papéis
| Etapa | Papel |
|---|---|
| Construir Fase A (migrations, testes, molde) | Engenheiro de dados |
| Construir Fase B (`banco-dev.yml`) | Engenheiro de DevOps |
| Revisar banco (etapa 9) e conferir o ADR 0005 item por item (E16·1) | outra instância do Engenheiro de dados (que não construiu) e Auditor de risco |
| Revisar acesso (funções, políticas, Fase B) | Engenheiro de segurança e Auditor de risco |
| Veredito CA-01 a CA-13 | Analista de qualidade (QA) |
| Conferir o pedido | Analista de requisitos |
| Fila e registros | Documentador |

## 10. Critério → prova
| CA | Prova | Quem confere |
|---|---|---|
| CA-01 | ADR 0005 com T1 a T10 e conferência preenchida | Auditor de risco |
| CA-02 | arquivos do PR × §6 e ADR 0005 | Engenheiro de dados revisor |
| CA-03, CA-06 | `010_` e `040_` verdes no job `banco` | QA |
| CA-04, CA-05 | `020_` e `030_` verdes | QA |
| CA-07 | molde existe e foi revisado | Engenheiro de dados revisor |
| CA-08, CA-11 | Fase B só com `push` na `previas` e aprovação do ambiente; histórico da CI | Auditor de risco |
| CA-09 | resposta E24·1 gravada, sem chave nem dado pessoal | Documentador; Auditor de risco |
| CA-10 | job `segredos` verde; nada de seed ou dado do antigo | Engenheiro de segurança |
| CA-12 | relatórios sem "Bloqueia" | QA |
| CA-13 | `050_` verde | QA |

## 11. Riscos e não verificado
- R-1 · O `db:start` do item 2 desliga o serviço de Auth (`-x gotrue`). Os testes precisam de `auth.users` e `auth.uid()`;
  a imagem do Postgres do Supabase deve criá-los sozinha, mas **não verificado**. Se faltar, tirar `gotrue` do `-x` (muda
  `package.json`: pede ajuste deste plano antes).
- R-2 · Colunas obrigatórias de `auth.users` na versão local: o preparo usa só `id` e `email`; **não verificado**.
- R-3 · Que `supabase test db` roda só `supabase/tests/` e ignora `supabase/moldes/`: **não verificado**; conferir na
  referência da CLI ao construir.
- R-4 · Comando e opções exatos da Fase B (aplicar por endereço do banco, modo de ensaio, `test db` remoto): **não
  verificado**, lidos na referência oficial antes de escrever o workflow.
- R-5 · Privilégios padrão do Supabase dão tudo a `anon` e `authenticated` em tabela nova de `public`; por isso o
  `revoke all` explícito em M1 e M2 e o teste `010_`.
- R-6 · Pessoa sem estúdio escolhido vê nada até chamar `escolher_estudio`; o fluxo de primeira entrada é do servidor,
  em spec futura.
