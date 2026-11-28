# Plano · Catálogo (primeira versão): serviços e categorias

- **Spec:** `specs/20261128-022000-catalogo/spec.md` (Draft; revisão 5b feita; E30·1 a E30·3 em aberto)
- **Escrito por:** Arquiteto de software · **Norma:** modelo C4 e ADR (mais Clean Architecture, Twelve-Factor, WCAG 2.2,
  OWASP ASVS 4.0.3 V4 e V5, ISO 4217, boas práticas do Postgres e do Supabase) · **Revisão:** pendente (etapa 5
  Analista de requisitos; 5b Gerente de projeto)
- **Decisões técnicas deste plano:** `docs/adr/0012-catalogo-dinheiro-uso-e-tetos.md`. **Decisões de banco (tabelas do
  antigo):** `docs/adr/0011-catalogo-tabelas-do-antigo.md`, escrito pelo Engenheiro de dados na tarefa T3 (não aqui).
- **Dependência fixada pelo dono (E36·A):** login, sessão, as 6 portas e a auditoria (porta 6) vêm da spec própria
  "Entrar e camada de serviço" (branch `feat/entrar-servico`), construída antes do núcleo. O Catálogo **usa**, não constrói.
- **Bases lidas em 28/11/2026 (só leitura, nada editado lá):**
  - item 2 (`chore/fundacao-tecnica`, `/home/user/wt-fundacao`): `package.json` (scripts `typecheck`, `lint`, `test`,
    `test:e2e`, `db:start`, `db:test`), ADR 0002 (D3 lint de camadas, D10 pgTAP, D11 Playwright 390×844 e 1440×900);
  - item 3 (`feat/banco-ligacao`, `/home/user/wt-banco`): `plan.md` §3 a §8, ADR 0005, migrations
    `20261128002040_estudios.sql` a `20261128002045_politicas_base.sql` (conferidas no código: `public.estudios.moeda
    text not null check (moeda ~ '^[A-Z]{3}$')`, `public.membros (org_id, user_id)` como chave, `app.estudio_da_sessao()`,
    `app.papel_da_sessao()`, `app.eh_dona()`, `force row level security`, `revoke all` de `anon` e `authenticated`),
    `supabase/moldes/isolamento_tabela_test.sql` e `supabase/tests/database/010_base_estrutura_test.sql`;
  - item 4 (`feat/design-system-codigo`, `/home/user/wt-ds`): `plan.md` §5, ADR 0004, `src/app/ui/*` (conferidos:
    `LinhaLista` com `categoria`, `categoriaDaOrdem`, `CabecalhoGrupo`, `Tabela`, `Seletor`, `MenuAcoesLinha`,
    `Janelinha`, `Folha`, `Painel`, `Aviso`, `CampoTexto`, `CampoSelecao`, `BuscaTela`, `EstadoVazio`, `SemResultado`,
    `Erro`, `Carregando`, `BarraTopo`, `Submenu`, `CabecalhoCelular`, `BarraBaixo`, `ListaSecoes`, `Contador`, `Icone`);
  - Agenda (`feat/agenda`, `/home/user/wt-agenda`): `plan.md` (§3 E26·3, §5.1 contrato da camada de serviço, §5.5
    idiomas) e ADR 0006 (D1 idiomas sem biblioteca, D6 dúvida respondida vira constante);
  - Checkout (`feat/checkout`, só a spec): RF-03, RF-05, RN-01, RN-02 (o que ele espera do Catálogo);
  - antigo (`crm-agenda`, só leitura, E22·B): **só os nomes** dos objetos das migrations de catálogo (lista na L-2).

## 1. Resumo (C4)
**Contexto:** dona, recepção e profissional usam a tela Catálogo; Agendamento e Checkout leem serviços dele. Nenhum
sistema externo novo.
**Contêiner:** o app do item 2 (TanStack Start) e o banco do item 3, com a camada de serviço da E36·A.
**Componentes (uma leitura da lista e uma gravação):**

```
/catalogo/servicos?categoria=<id>&situacao=ativos&ordem=nome&pagina=1   (só ids e opções na URL: RNF-04)
   │ loader / ação da tela
   ▼
src/server/catalogo/{listar,servicos,categorias}.ts ── 6 portas da E36·A (quem é · estúdio da sessão · papel ·
   │ usa regras puras                                  esquema · banco com trava · registro)
   ▼                                   ▼ com a sessão da pessoa
src/domain/catalogo/*               src/data/catalogo/* ──► public.categorias, public.servicos
(preço, duração, nome, lista,                              (+ public.servicos_profissionais se E30·3·B)
 acesso)                                                   RLS: org_id = (select app.estudio_da_sessao())

Agendamento e Checkout (servidor) ──► src/server/catalogo/consultas.ts (RF-08; contexto já passado pelas portas)
```

## 2. Lacunas para o Analista de requisitos (a spec não cobre; não decido, `AGENTS.md` §4)
Cada uma com recomendação; o plano funciona com a recomendação e diz o que muda na outra.

- **L-1 · E30·1, E30·2 e E30·3 sem resposta.** O plano usa as recomendações (A, A, A) e mostra no §3 o que muda em cada
  outra. Construção só depois das respostas (T0).
- **L-2 · Spec §7 incompleta.** A lista do antigo não cita objetos de catálogo que existem lá e que o CA-10 exige com
  ADR: migrations `20260615173836_catalog_fk_indexes`, `20260615174119_catalog_rls_hardening` (políticas
  `catalog_categories_*` e de pacotes e planos), `20260615174121_catalog_atomic_rpcs` (`replace_service_staff_atomic`,
  `upsert_service_package_atomic`), `20260615174426_catalog_protected_deletion` (`prevent_used_catalog_item_delete` e os
  gatilhos `protect_used_*_delete`), `20261114030000_catalog_reads` (`catalog_screen`), `20261114030100_catalog_writes`
  (`catalog_save_service`, `catalog_save_category`, `catalog_delete_item`, `catalog_duplicate_item`,
  `catalog_reorder_services`, `catalog_set_flags`, `catalog_audit_row` e gatilhos `catalog_audit_*`),
  `20261114130200_permissoes_catalogo_funcoes`, e a tabela `subscription_plan_services`. **Recomendo:** acrescentar
  essas linhas ao §7 (sugestões no §4.1 deste plano) para o ADR 0011 cobrir tudo.
- **L-3 · Moeda com outro número de casas e troca da moeda (dinheiro; vai ao dono pelo Analista).** "Centavos" só vale
  para moeda de 2 casas (ISO 4217: JPY tem 0, BHD tem 3). E o item 3 deixa a dona alterar `estudios.moeda`
  (`grant update (... moeda ...)`): trocar EUR por outra moeda muda o sentido de todo preço já gravado, sem conversão.
  A spec §11 põe "troca da moeda" fora de escopo, mas o banco já permite. **Recomendo:** (a) mesma regra do Checkout
  RN-02: só moeda de 2 casas; o servidor recusa gravar preço em outra (`moeda_nao_suportada`); (b) a troca de moeda
  vira dúvida do dono numa spec própria (Ajustes), e até lá a T3 avalia com o Engenheiro de dados travar `moeda` quando
  houver serviço (mudança na base do item 3, que pede ajuste e 5b lá).
- **L-4 · Fração de centavo no banco.** Coluna `integer` recebendo `10.5` **arredonda sem erro** (conversão de
  atribuição do Postgres). A recusa de fração (RN-01, CA-01) só se prova no servidor (esquema de inteiro) e no domínio;
  no banco a prova é o tipo e a faixa. Ajuste só de texto no CA-01, se o Analista quiser.
- **L-5 · Faixa da categoria na tabela do computador.** A spec §4 pede a faixa de 4 px na linha da tabela (1440); a
  `Tabela` do item 4 não tem essa opção (só `LinhaLista` tem). **Recomendo:** acrescentar uma propriedade opcional
  `categoria` por linha em `src/app/ui/bloco-lista.tsx` e `.css`, mostrada na ficha visual e conferida pelo Revisor de
  design (é peça que o `DESIGN.md` já descreve). Na outra opção, a faixa sai da tabela e a spec muda.
- **L-6 · Duplicar com nome único (tela).** O RF-05 abre o formulário com os mesmos dados, e o RN-04 recusa nome igual:
  Salvar sem mudar o nome sempre dá erro. **Recomendo:** a ficha visual (etapa 6) mostra o nome já com o erro "nome
  repetido" no campo, sem texto novo; a outra opção (sufixo como "(cópia)") é texto de tela e vai ao dono.
- **L-7 · "Nunca usado" (RF-04) depende de tabelas que ainda não existem.** O Catálogo não sabe o que o Agendamento e
  o Checkout gravam. Decisão técnica (ADR 0012 · D3): quem usa o serviço aponta para ele com chave estrangeira
  `on delete restrict`; o Catálogo traduz a recusa em `servico_em_uso`. **Pede** uma linha nas specs do Agendamento
  (`agendamento_itens`, nome do plano do Agendamento, com `on delete restrict` para `servicos`) e do Checkout (itens da venda). Até lá, CA-05 se prova com tabela de teste no pgTAP (§4.4).
- **L-8 (só texto da spec):** o cabeçalho diz "Branch: `feat/catalogo` (da `previas`)", mas a branch é empilhada (§10).

## 3. Dúvidas E30 em aberto: o plano usa a recomendação; o que muda em cada outra
A resposta vira **uma constante** em `src/domain/catalogo/acesso.ts` e **uma** versão das políticas e restrições; não
se constroem as variantes nem chave de liga e desliga (mesma regra do ADR 0006 · D6).

| Dúvida | Com a recomendação (base deste plano) | Se o dono escolher outra |
|---|---|---|
| E30·1 · quem grava | **A:** só `dona` grava (políticas de insert, update e delete com `(select app.eh_dona())`); recepção e profissional só leem; a tela esconde Adicionar e ⋮ de escrita, e o servidor recusa (porta 3) | **B:** `(select app.papel_da_sessao()) in ('dona','recepcao')`. **C:** só a condição do estúdio. Mudam `acesso.ts`, as políticas de M1 e M2, o teste 540 e o e2e de papéis |
| E30·2 · forma do preço | **A:** `preco_centavos integer not null check (preco_centavos between 0 and 10000000)` (0,00 a 100 000,00 em moeda de 2 casas); domínio igual | **C:** faixa `between 1 and 10000000`. **B:** mais `a_partir_de boolean not null default false` em `servicos`, campo na tela, chave nos três idiomas, e o RF-08 entrega a marca ao Checkout (o Checkout volta ao dono pela spec dele, §10 de lá) |
| E30·3 · quem faz cada serviço | **A:** sem tabela nova; `consultas.ts` não filtra por profissional; filtro "profissional" fica "em desenvolvimento" | **B:** migration M3 `servicos_profissionais`, teste 550, `src/data/catalogo/servicos-profissionais.ts`, campo de escolha no formulário, filtro "profissional" ligado; quem pode ser ligado segue a E26·3 da Agenda (papel `dona` ou `profissional`, ativo, pela recomendação de lá) |

## 4. Banco (tipo Banco; quem decide é o Engenheiro de dados)

### 4.1 Decisão por tabela e objeto do antigo · **Engenheiro de dados decide na T3** (ADR 0011, conferido por outra instância, E16·1)
Sugestões do Arquiteto, por cima das do Analista (spec §7). Nada se copia: "reescrever" é mesma intenção, código novo.

| Antigo | Sugestão | Motivo |
|---|---|---|
| `service_categories` | **reescrever** como `public.categorias` | igual à spec §7; mais `ordem_cor` fixada na criação (RN-06) |
| `services` | **reescrever** como `public.servicos` | igual à spec §7; preço `integer` em centavos (o antigo usa `numeric(10,2)`); duração 5–720 de 5 em 5 (o antigo aceita 0); sai `alterado_em`: quem mudou e quando é a porta 6 (mesma linha do ADR 0005 · T8) |
| `service_staff` | **reescrever** como `public.servicos_profissionais` **só se E30·3·B**; senão **adiada** | ligação a `public.membros (org_id, user_id)`, quem atende pela E26·3 |
| `staff_services` | **descartar** | spec §7 (nasce sem `org_id`) |
| `products`, pacotes, combos, `subscription_plans`, `subscription_plan_services` | **adiada** | spec §2 |
| `upsert_catalog_service_atomic`, `catalog_save_service`, `catalog_save_category`, `catalog_duplicate_item`, `catalog_delete_item`, `catalog_set_flags`, `catalog_reorder_services`, `replace_service_staff_atomic`, `catalog_screen` | **descartar** | gravação e leitura passam pela camada de serviço (`ARCHITECTURE.md` §4); funções de banco que recebem o estúdio do pedido ferem o RN-07 (o Engenheiro de dados confere no corpo) |
| `prevent_used_catalog_item_delete` e gatilhos `protect_used_*_delete` | **descartar** | substituídos por chave estrangeira `on delete restrict` de quem usa (ADR 0012 · D3): a regra fica com quem cria o uso, sem gatilho que conhece as tabelas dos outros módulos |
| `catalog_audit_row` e gatilhos `catalog_audit_*` | **descartar** | o registro é a porta 6 da E36·A |
| políticas `catalog_*`, `services_*` e índices de `catalog_fk_indexes` | **reescrever** | novas políticas sobre `app.estudio_da_sessao()` (§4.3); índices por `org_id` (RG-04) |

### 4.2 Migrations (criadas com `pnpm exec supabase migration new <nome>`; data e hora depois das do item 3 e da E36·A)
| # | Nome | Conteúdo (sugestão; forma final do Engenheiro de dados) |
|---|---|---|
| M1 | `catalogo_categorias` | tabela `public.categorias`, RLS ligada e forçada, `revoke all` de `anon` e `authenticated`, `grant` por coluna, políticas, índices, restrições e gatilho de `ordem_cor` |
| M2 | `catalogo_servicos` | tabela `public.servicos`, idem, chave composta para `categorias` |
| M3 | `catalogo_servicos_profissionais` | **só se E30·3·B** |

### 4.3 Forma sugerida
`S` = `org_id = (select app.estudio_da_sessao())` · `G` = condição de quem grava pela E30·1 (A: `(select app.eh_dona())`).

**`public.categorias`**
| Coluna | Tipo e regra |
|---|---|
| `id` | `uuid primary key default gen_random_uuid()` |
| `org_id` | `uuid not null default (app.estudio_da_sessao()) references public.estudios (org_id) on delete cascade` (o estúdio nasce da sessão, RN-07; ninguém tem `insert` em `org_id`) |
| `nome` | `text not null`, `check (nome = btrim(nome) and char_length(nome) between 1 and 60)` (RN-04) |
| `ordem_cor` | `integer not null check (ordem_cor >= 1)`; gatilho `before insert` põe `coalesce(max(ordem_cor), 0) + 1` do estúdio; não se altera (sem `grant update`) (RN-06) |
| `criado_em` | `timestamptz not null default now()` |

- `unique (org_id, id)` (alvo da chave composta de `servicos`). Nome único sem maiúsculas e acentos: índice único em
  `(org_id, nome collate <colação ICU não determinística, nível 1>)` (documentação do Postgres, "Nondeterministic
  Collations"), ou coluna normalizada; o Engenheiro de dados escolhe (não verificado no banco local, §12).
- `grant select`, `insert (nome)`, `update (nome)`, `delete`. Políticas: ler `S`; criar, alterar (`using` e `with check`
  iguais) e apagar `S and G`.

**`public.servicos`**
| Coluna | Tipo e regra |
|---|---|
| `id` | `uuid primary key default gen_random_uuid()` |
| `org_id` | como em `categorias` |
| `categoria_id` | `uuid not null`; `foreign key (org_id, categoria_id) references public.categorias (org_id, id) on delete restrict` (RN-05; categoria com serviço não se apaga, RF-06) |
| `nome` | `text not null`, `check (nome = btrim(nome) and char_length(nome) between 1 and 120)`; único como em `categorias` (RN-04) |
| `duracao_min` | `integer not null`, `check (duracao_min between 5 and 720 and duracao_min % 5 = 0)` (RN-03) |
| `preco_centavos` | `integer not null`, `check (preco_centavos between 0 and 10000000)` (RN-01, E30·2·A) |
| `arquivado` | `boolean not null default false` (RF-03) |
| `criado_em` | `timestamptz not null default now()` |

- `unique (org_id, id)` (alvo das chaves compostas do Agendamento, do Checkout e de M3). Índices: `(org_id, categoria_id)`
  e `(org_id, arquivado, nome)`.
- `grant select`, `insert (categoria_id, nome, duracao_min, preco_centavos)`,
  `update (categoria_id, nome, duracao_min, preco_centavos, arquivado)`, `delete`. Políticas como em `categorias`.

**`public.servicos_profissionais` (só E30·3·B):** `org_id`, `servico_id`, `profissional_id`; chave `(org_id, servico_id,
profissional_id)`; `(org_id, servico_id)` → `servicos (org_id, id) on delete cascade`; `(org_id, profissional_id)` →
`membros (org_id, user_id) on delete cascade`; gatilho confere papel pela E26·3 e vínculo ativo; `grant select, insert,
delete`; políticas ler `S`, gravar `S and G`.

### 4.4 Testes pgTAP (`supabase/tests/database/`, banco local, `pnpm db:test`; faixa 5xx do Catálogo, decisão técnica)
| Arquivo | Prova |
|---|---|
| `510_catalogo_categorias_isolamento_test.sql` | cópia do molde do item 3: A não lê, cria, altera nem apaga de B; sem papel e sem login, nada (CA-02, CA-03) |
| `520_catalogo_servicos_isolamento_test.sql` | idem para `servicos` (CA-02, CA-03) |
| `530_catalogo_restricoes_test.sql` | duração 0, 4, 7, 721, negativa recusadas e 5, 720 aceitas; preço −1 e 10 000 001 recusados, 0 e 10 000 000 aceitos; nome vazio, com espaço na ponta, 61/121 caracteres e repetido ("Depilação" × "depilacao") recusado; categoria de outro estúdio recusada (chave composta); categoria com serviço (ativo ou arquivado) não se apaga; serviço apontado por uma **tabela de teste** com `on delete restrict`, criada e desfeita dentro da transação, não se apaga (CA-05, L-7); `ordem_cor` não muda ao apagar outra e a nova não repete a de uma viva (RN-06) |
| `540_catalogo_papeis_test.sql` | E30·1·A: dona grava, recepção e profissional só leem; `org_id` de B no `insert` recusado e `insert` sem `org_id` nasce no estúdio da sessão (CA-03, CA-04 no banco) |
| `550_catalogo_servicos_profissionais_test.sql` | só E30·3·B: isolamento (molde), recepção não pode ser ligada, pessoa de outro estúdio recusada |

O `010_base_estrutura_test.sql` do item 3 já confere `org_id`, RLS ligada e forçada e nenhum privilégio para `anon`
em toda tabela de `public`: passa a valer para as novas.

## 5. Código por camada (regra de dependência do `ARCHITECTURE.md` §3, travada pelo lint do item 2)

### 5.1 Contrato usado da camada de serviço (E36·A; não se escreve aqui)
O mesmo do plano da Agenda §5.1: uma função monta a ação com a permissão pedida, o esquema da entrada e o trabalho;
entrega um contexto com `usuarioId`, `orgId`, `papel` (da sessão; nunca da entrada) e o acesso ao banco com a sessão da
pessoa; grava o registro (porta 6) com nome do evento e campos estruturados, sem texto livre; erros saem como códigos.
**Pedido a essa spec (recomendação, não decidido aqui):** o contexto trazer também `idioma` e `moeda` do estúdio, lidos
uma vez por pedido, para nenhum módulo repetir essa leitura. Sem isso, entra `src/data/estudio.ts` (§9, condicional).
Se o formato for outro, só os arquivos de `src/server/catalogo/` se ajustam.

### 5.2 `src/domain/catalogo/` (TypeScript puro, com teste; Engenheiro de software)
| Arquivo | O que tem | Regras |
|---|---|---|
| `tipos.ts` | `Servico`, `Categoria`, `Centavos` (inteiro), `CodigoMoeda`, `Papel`, códigos de erro | — |
| `preco.ts` | casas da moeda por `Intl.NumberFormat(...).resolvedOptions().maximumFractionDigits`; recusa moeda que não seja de 2 casas (L-3); `validarPreco` (inteiro, faixa da E30·2); `lerPreco(texto, idioma, moeda)` → centavos **sem número com vírgula flutuante** (separadores do idioma por `formatToParts`); `formatarPreco(centavos, idioma, moeda)` passando o valor como **texto decimal** ao `Intl.NumberFormat` (ADR 0012 · D1) | RN-01, RN-02 |
| `duracao.ts` | `validarDuracao` (inteiro, 5–720, múltiplo de 5); `partesDaDuracao(min)` → `{ horas, minutos }` (o texto "1 h 30 min" sai do arquivo de idioma) | RN-03 |
| `nome.ts` | aparar pontas, tamanhos, chave de comparação sem maiúsculas e acentos (`normalize('NFD')` sem marcas) para o aviso antecipado; o banco tem a palavra final (`23505` → `nome_repetido`) | RN-04 |
| `servico.ts` | `validarServico` e `validarCategoria`: juntam as regras e devolvem erro **por campo** (para o contorno vermelho) | RN-01 a RN-05 |
| `lista.ts` | opções de situação (Ativos padrão, Arquivados), ordenação (Nome padrão, Preço, Duração; empate por `id`), tamanho da página, agrupamento por categoria (celular), contadores sem zero, contagem de filtros ligados | RF-07, RN-08 |
| `acesso.ts` | constante da E30·1 (o que cada papel lê e grava) e da E30·3 | RF-09, §3 |

- Testes (CA-01): EUR e BRL em `pt`, `es`, `en` ("230,00 €", "R$ 230,00", "€230.00" conforme o `Intl` do Node; o teste
  grava o que sair e o Revisor de design confere com o `DESIGN.md`); `lerPreco` com "1.234,56" em `pt` e "1,234.56" em
  `en`, recusa "12,345" (fração de centavo) e texto; duração 0, −5, 4, 7, 721, 7.5 recusadas, 5 e 720 aceitas, 90 →
  1 h 30 min; nome "  x", "", 121 caracteres, "Depilação" × "DEPILACAO".
- `src/domain/exemplo.ts` e `exemplo.test.ts` saem, se ainda existirem quando a branch receber as bases (a Agenda
  também os apaga; quem vier primeiro).

### 5.3 `src/server/catalogo/` (Engenheiro de software)
| Arquivo | O que tem |
|---|---|
| `esquemas.ts` | entradas com o validador fixado pela E36·A: serviço (`categoriaId` uuid, `nome` texto, `duracaoMin` inteiro, `precoCentavos` **inteiro**: fração recusada aqui, L-4), categoria (`nome`), `id`, filtros da lista (`categoriaId?`, `situacao`, `ordem`, `pagina` inteiro ≥ 1, `busca` ≤ 120). **Sem campo de estúdio**; chave desconhecida descartada (CA-04) |
| `listar.ts` | `listarServicos` e `listarCategorias` (`GET`): página de 50 com `limit 51`; contagem por categoria com os mesmos filtros; teto de idas do §6 |
| `servicos.ts` | `adicionarServico`, `editarServico`, `arquivarServico`, `desarquivarServico`, `excluirServico` (`POST`): porta 3 por `acesso.ts`; regras do domínio; moeda do estúdio conferida (L-3); `23505` → `nome_repetido`, `23503` na exclusão → `servico_em_uso` (a tela oferece Arquivar), `23503` na gravação → `categoria_invalida`. Registro: `catalogo.servico.adicionado`, `.alterado`, `.arquivado`, `.desarquivado`, `.excluido` com `servico_id` e, se o preço mudou, `preco_antes` e `preco_depois` (inteiros) e a moeda (RF-10, CA-06) |
| `categorias.ts` | `adicionarCategoria`, `renomearCategoria`, `excluirCategoria`: `23503` → `categoria_com_servicos`; registro `catalogo.categoria.*` com `categoria_id` |
| `consultas.ts` | para outros módulos (RF-08), recebendo o contexto que já passou pelas portas: `servicosAtivosParaAgendar(ctx)` → id, nome, categoria, duração; `servicosParaCobrar(ctx, ids)` → também `precoCentavos` e `moeda` do estúdio, e `arquivado` (o Checkout decide o que fazer). Sem gravação |
| `*.test.ts` (4) | com o acesso ao banco trocado por um falso: estúdio no pedido ignorado (CA-04); sem login e sem papel nada (CA-03); cada papel × cada ação pela E30·1 (CA-03); fração e preço fora da faixa recusados (CA-01); registro com preço antes e depois e sem nome de pessoa (CA-06); `23503` vira `servico_em_uso` (CA-05); número de idas ≤ teto (RNF-02) |

### 5.4 `src/data/catalogo/` (Engenheiro de software; consultas conferidas pelo Engenheiro de dados)
| Arquivo | O que tem |
|---|---|
| `categorias.ts` | ler as do estúdio com contagem de serviços (filtrada como a lista), `limit` 201; criar, renomear, apagar por `id` |
| `servicos.ts` | página com filtros e ordem (busca por nome com `ilike` e curingas escapados); ler um por `id` (valor antes, para o registro); criar, alterar, arquivar, apagar; ativos para o Agendamento; por ids para o Checkout |
| `servicos-profissionais.ts` | só E30·3·B |

Nenhum filtro por `org_id` vindo de fora: a RLS decide. Sem teste de unidade próprio (são consultas); a prova é o
pgTAP (§4.4) e o e2e (§7). Contagem agregada: forma conforme o cliente do banco da E36·A (não verificado, §12).

### 5.5 `src/app/` (Engenheiro de software; desenho do Designer de produto na ficha)
- **Rotas:** `src/app/routes/catalogo.tsx` (celular: nível 1 com a lista de seções; computador: vai direto a Serviços
  com o `Submenu`) e `src/app/routes/catalogo.servicos.tsx` (`validateSearch` aceita só `categoria` (uuid), `situacao`,
  `ordem`, `pagina`, e `servico` (uuid) para o painel de edição; a busca fica no estado da tela, não na URL: RNF-04).
  As outras seções (Pacotes, Combos, Planos de assinatura, Produtos) mostram "em desenvolvimento".
- **Navegação:** uma linha em `src/app/navegacao.ts` (o menu da casca, que nasce na `feat/entrar-servico`) liga o
  Catálogo (3º item, `tag`).
- **Tela** em `src/app/paginas/catalogo/`, só com componentes do item 4 e as peças que o dono aprovar na ficha:

| Arquivo | O que tem |
|---|---|
| `secoes.tsx` | nível 1 do celular: `ListaSecoes` com ícone, nome, contador e ›; seções não feitas "em desenvolvimento" |
| `servicos.tsx` | composição: `BarraTopo` (1440) ou `CabecalhoCelular` e `BarraBaixo` (390); busca, categoria (`CampoSelecao` 1440 / `Seletor` 390 com contador), Filtros, Ordenar; `Tabela` (1440) ou grupos `CabecalhoGrupo` + `LinhaLista` (390); paginação; os cinco estados (`EstadoVazio`, `SemResultado`, `Carregando`, `Erro`, `Aviso` com "Desfazer" no arquivar) |
| `servico-formulario.tsx` | `Painel` 480 (1440) ou tela sem barra com Salvar preto no rodapé (390): Nome, Categoria, Duração, Preço com o símbolo da moeda; erro por campo; Duplicar abre preenchido (L-6) |
| `acoes-linha.tsx` | `MenuAcoesLinha`: Editar · Duplicar · Arquivar/Desarquivar · Excluir com `Janelinha`; `servico_em_uso` oferece Arquivar; esconde escrita pela E30·1 |
| `categorias.tsx` | adicionar, renomear, excluir categoria; ponto de entrada conforme a ficha |
| `filtros.tsx` | `Painel` (1440) e `Folha` (390): situação (e profissional se E30·3·B); "online" e "pede formulário" "em desenvolvimento"; "Limpar filtros" |
| `catalogo.css` | só `var(--...)` do `tokens.css` (regra RT-9 do item 4) |
| `catalogo.test.tsx` | `renderToString`: uma só ação preta por tela; "+ Adicionar" do celular com contorno; nenhum texto fixo fora do arquivo de idioma; categoria sempre com nome escrito |

- **Idiomas (RNF-03):** um bloco `catalogo` na base comum `src/app/i18n/{pt,es,en}.ts`, que nasce na
  `feat/entrar-servico` (chaves do `pt.ts` como tipo das outras; ADR 0006 · D1; ADR 0012 · D5). Inclui o texto de cada
  código de erro do §5.3 e o formato "N h M min". Nomes de serviço e categoria ficam como o estúdio escreveu.
- **Faixa na tabela (L-5):** propriedade opcional `categoria` por linha em `src/app/ui/bloco-lista.tsx` e
  `bloco-lista.css`, mais um caso em `src/app/ui/componentes.test.tsx`; nada mais muda em `src/app/ui/`.

## 6. Tetos (ADR 0012 · D4)
- **Página:** 50 serviços, lidos com `limit 51` para saber se há próxima; ordem estável (chave da ordem + `id`).
- **Categorias:** até 200 lidas por tela (`limit 201`; passou, a tela avisa, sem cortar calado).
- **Idas ao banco por tela:** leitura da lista **≤ 2** (categorias com contagem; página de serviços), mais 1 se a E36·A
  não trouxer idioma e moeda; gravação **≤ 3** (ler o atual, gravar, registro), além do que as portas fizerem.

## 7. Testes de tela (Playwright, projetos `celular` 390 e `computador` 1440 do item 2)
Dados só fictícios, escritos do zero, no banco **local** (estúdios A e B, dona, recepção, profissional; serviços e
categorias inventados). Sessão de teste pela E36·A.

| Arquivo | Prova |
|---|---|
| `e2e/preparo/catalogo-dados.ts` | cria e apaga os dados fictícios no banco local |
| `e2e/catalogo.spec.ts` | CA-07: adicionar, editar, duplicar, arquivar com "Desfazer", desarquivar, excluir com janelinha (e usado → oferece Arquivar, com a tabela de teste do preparo); adicionar, renomear e excluir categoria; busca, categoria, situação, "Limpar filtros", Ordenar, paginação; recepção e profissional sem Adicionar nem ⋮ de escrita (E30·1·A). RNF-04: a URL só tem ids e opções |
| `e2e/catalogo-estados.spec.ts` | CA-08: vazio, sem resultado, carregando (resposta atrasada por `page.route`), erro (500 por `page.route`), sucesso; seções "em desenvolvimento" |
| `e2e/catalogo-acessibilidade.spec.ts` | CA-09: `AxeBuilder` com as etiquetas do item 4, com a tela fechada e com painel, folha, menu e janelinha abertos; seletor por teclado (padrão Tabs) |

## 8. Papéis
| Etapa | Papel |
|---|---|
| Branch empilhada (T1) | Engenheiro de DevOps |
| Ficha visual e peças que faltam no `DESIGN.md` (T2, etapa 6) | Designer de produto; confere o Revisor de design; aprova o dono |
| Decisão por tabela (ADR 0011), migrations, pgTAP (T3 a T5) | Engenheiro de dados |
| Domínio, servidor, dados, telas, idiomas, e2e (T6 a T17) | Engenheiro de software |
| Revisar código | Revisor de código |
| Revisar banco e conferir o ADR 0011 item por item (E16·1) | Engenheiro de dados (outra instância, que não construiu) e Auditor de risco |
| **Revisar dinheiro** (`preco.ts`, `esquemas.ts`, faixa e tipo em M2, `consultas.ts` para o Checkout, registro do preço) | **Auditor de risco** e Engenheiro de segurança |
| Revisar acesso (E30·1, políticas, CA-03, CA-04) | Engenheiro de segurança e Auditor de risco |
| Revisar a tela (checklist `DESIGN.md` §10, capturas 390 e 1440) | Revisor de design |
| Veredito CA-01 a CA-12 | Analista de qualidade (QA) |
| Conferir o pedido · registros · pedido de merge | Analista de requisitos · Documentador · Gerente de projeto |

## 9. Arquivos (lista FECHADA)
Fora desta lista nada muda (`AGENTS.md` §6). Arquivo que uma ferramenta crie fora daqui: parar e relatar.

**Banco (Engenheiro de dados):** `supabase/migrations/<ts>_catalogo_categorias.sql` ·
`supabase/migrations/<ts>_catalogo_servicos.sql` · `supabase/migrations/<ts>_catalogo_servicos_profissionais.sql` (só
E30·3·B) · `supabase/tests/database/510_catalogo_categorias_isolamento_test.sql` · `520_catalogo_servicos_isolamento_test.sql`
· `530_catalogo_restricoes_test.sql` · `540_catalogo_papeis_test.sql` · `550_catalogo_servicos_profissionais_test.sql`
(só E30·3·B) · `docs/adr/0011-catalogo-tabelas-do-antigo.md`.

**Domínio:** `src/domain/catalogo/{tipos,preco,duracao,nome,servico,lista,acesso}.ts` e
`{preco,duracao,nome,servico,lista,acesso}.test.ts`; apagar `src/domain/exemplo.ts` e `exemplo.test.ts` (se existirem).

**Servidor:** `src/server/catalogo/{esquemas,listar,servicos,categorias,consultas}.ts` e
`{listar,servicos,categorias,consultas}.test.ts`.

**Dados:** `src/data/catalogo/{categorias,servicos}.ts` · `src/data/catalogo/servicos-profissionais.ts` (só E30·3·B) ·
`src/data/estudio.ts` (só se a E36·A não trouxer idioma e moeda no contexto, §5.1).

**Telas:** `src/app/routes/catalogo.tsx` · `src/app/routes/catalogo.servicos.tsx` · `src/app/routeTree.gen.ts` (gerado) ·
`src/app/navegacao.ts` (só a linha do Catálogo; arquivo da `feat/entrar-servico`) · `src/app/paginas/catalogo/{secoes,servicos,servico-formulario,acoes-linha,categorias,filtros}.tsx`
· `src/app/paginas/catalogo/catalogo.css` · `src/app/paginas/catalogo/catalogo.test.tsx` ·
`src/app/i18n/{pt,es,en}.ts` (só o bloco `catalogo`; arquivos da `feat/entrar-servico`) ·
`src/app/ui/bloco-lista.tsx`, `src/app/ui/bloco-lista.css`, `src/app/ui/componentes.test.tsx` (só a L-5).

**Testes de tela:** `e2e/preparo/catalogo-dados.ts` · `e2e/catalogo.spec.ts` · `e2e/catalogo-estados.spec.ts` ·
`e2e/catalogo-acessibilidade.spec.ts`.

**Ficha visual (Designer de produto):** `specs/20261128-022000-catalogo/ficha-visual.md` e `specs/20261128-022000-catalogo/ficha/*.png`.

**Texto:** `DESIGN.md`, **só** as linhas que o dono aprovar na ficha (spec §4: "Desarquivar", situação em Filtros,
gestão de categorias, ícones das seções, formato da Duração) (Designer de produto) · `docs/STATUS.md`,
`docs/BACKLOG.md`, `CHANGELOG.md`, `docs/decisoes/2026-11-27-fundacao.md` (respostas E30 e das lacunas) (Documentador).

**Processo:** `specs/20261128-022000-catalogo/{spec.md,plan.md,tasks.md}` · `docs/adr/0012-catalogo-dinheiro-uso-e-tetos.md`.

**Intactos:** o resto de `src/app/ui/**` e `src/app/estilos/**`, `src/server/portas/**` e o cliente do banco (da
E36·A), `src/*/AGENTS.md`, `src/*/CLAUDE.md`, `supabase/config.jsonc`, `supabase/seed.sql`, `supabase/moldes/**`, as
migrations dos itens 2 e 3 e da E36·A, `package.json`, `pnpm-lock.yaml`, `eslint.config.mjs`, `playwright.config.ts`,
`.github/**`, `ARCHITECTURE.md`, `AGENTS.md`. Nenhuma biblioteca nova.

## 10. Branch (decisão do Engenheiro de DevOps)
- `feat/catalogo` recebe, **por merge**, `feat/banco-ligacao` e `feat/design-system-codigo` (as duas já trazem a
  `chore/fundacao-tecnica`) e `feat/entrar-servico` (E36·A). PR de rascunho empilhado; nunca se junta numa base. Quando
  as bases entrarem na `previas`, a base do PR passa à `previas`, antes do pedido de merge.
- **Base de idiomas e `navegacao.ts`:** nascem na `feat/entrar-servico` (revisão 5b); o Catálogo só acrescenta o bloco
  `catalogo` e a linha do menu.
- Conflitos esperados: `src/app/routeTree.gen.ts` (regenera-se) e as linhas de `navegacao.ts` e dos blocos em `src/app/i18n/{pt,es,en}.ts`.

## 11. Critério → prova
| CA | Prova | Quem confere |
|---|---|---|
| CA-01 | `src/domain/catalogo/*.test.ts` e `src/server/catalogo/servicos.test.ts` (fração, L-4); cor estável: pgTAP 530 | QA; Auditor de risco (preço) |
| CA-02 | pgTAP 510, 520, 530 (e 550) verdes | Engenheiro de dados revisor; QA |
| CA-03 | pgTAP 510, 520, 540; testes do servidor | QA; Engenheiro de segurança |
| CA-04 | testes do servidor; pgTAP 540 | Revisor de código; Engenheiro de segurança |
| CA-05 | pgTAP 530 (tabela de teste); `servicos.test.ts`, `categorias.test.ts`; `consultas.test.ts` (arquivado fora dos ativos) | QA |
| CA-06 | `servicos.test.ts` e `categorias.test.ts` (registro com preço antes e depois, sem nome de pessoa) | Auditor de risco |
| CA-07, CA-08 | `e2e/catalogo.spec.ts` e `e2e/catalogo-estados.spec.ts` verdes nos 2 projetos | QA |
| CA-09 | `catalogo.test.tsx`, `e2e/catalogo-acessibilidade.spec.ts`; checklist `DESIGN.md` §10 nas capturas | Revisor de design; QA |
| CA-10 | ADR 0011 com cada linha do §4.1 (e da L-2), conferência preenchida; migrations só das reescritas | Auditor de risco |
| CA-11 | histórico da CI; nenhum `supabase link`, `db push`, `--remote` ou `--linked` | Auditor de risco |
| CA-12 | relatórios sem "Bloqueia" (inclui dinheiro); veredito do QA; conferência do dono na prévia | Gerente de projeto |
| Escopo | `git diff --name-only <base>...HEAD` comparado com o §9 | Revisor de código |

## 12. Riscos e não verificado
- **Bloqueantes para construir:** E36·A construída; E30 respondidas; L-3 decidida pelo dono (dinheiro).
- Itens 3 e 4 conferidos no código das branches; E36·A ainda sem spec lida: nomes do contrato (§5.1) vêm do plano da
  Agenda. Se mudarem, este plano se ajusta (nova 5b).
- **Não verificado:** colação ICU não determinística e índice único sobre ela no Postgres 17 do banco local (alternativa:
  coluna normalizada); `default (app.estudio_da_sessao())` em coluna com `force row level security` (o teste 540
  prova); a saída exata do `Intl.NumberFormat` para EUR e BRL em `pt`, `es`, `en` no Node 26 e no Chromium do teste;
  `Intl.NumberFormat.format` com texto decimal (ES2023) no Cloudflare Workers; contagem agregada pelo cliente do banco
  que a E36·A escolher; os corpos das funções do antigo da L-2 (lidos só os nomes).
- Numeração: ADR 0011 e 0012 e a faixa 5xx do pgTAP foram dadas a este módulo; o Documentador confere no PR.
- Ordem das `<ts>` das migrations: depois das do item 3 e da E36·A; conferir ao criar.
