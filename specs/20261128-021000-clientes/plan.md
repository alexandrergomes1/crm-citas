# Plano · Clientes, primeira versão (item 5 da fila, núcleo)

- **Spec:** `specs/20261128-021000-clientes/spec.md` (Draft; 5b e revisão de segurança feitas)
- **Escrito por:** Arquiteto de software · **Norma:** modelo C4 e ADR (mais Clean Architecture, OWASP ASVS 4.0.3 V4, V5,
  V7, V8; RGPD art. 15, 17, 20 e 32; LGPD art. 18; boas práticas Postgres e Supabase) · **Revisão:** etapa 5 (Analista
  de requisitos) e 5b (Gerente de projeto) pendentes
- **Funciona com as recomendações:** E28·1·A, E28·2·B (com E26·1·B da Agenda), E28·3·A. O que muda com outra resposta: §12.
- **Bases lidas em 28/11/2026 (não editadas):** item 2 (`chore/fundacao-tecnica`: `plan.md`, ADR 0002, `package.json`,
  `eslint.config.mjs`, `src/`); item 3 (`feat/banco-ligacao`: `plan.md`, ADR 0005, as 4 migrations de rascunho da
  pasta de trabalho); item 4 (`feat/design-system-codigo`: `plan.md`, ADR 0004). Spec do Agendamento (`feat/agendamento`)
  só para o nome das ligações. Do antigo (só leitura, nada copiado): as migrations que a spec §8 lista.
- **Decisões técnicas:** `docs/adr/<NNNN>-clientes-dados-busca-e-pedidos.md` (número: o próximo livre, dado pelo
  Documentador ao abrir o PR; outros módulos planejam em paralelo). Escrito na tarefa 2, antes de qualquer migration.

## 1. Resumo (C4)
**Contexto:** dona, recepção e profissional usam o app do estúdio; nenhum sistema externo novo. O arquivo exportado
vai só para o aparelho de quem pediu.
**Contêiner:** o app (TanStack Start) e o banco (Postgres do Supabase), como no item 2. Nada novo.
**Componentes do módulo (dentro do app e do banco):**

```
src/app/paginas/clientes/*  ──►  src/server/clientes/acoes.ts  ──►  src/domain/clientes/*  (regras puras)
  (lista, perfil, painel)         (6 portas, uma por ação)    │
                                  src/server/clientes/        ▼
                                  exportar.ts (arquivo)    src/data/clientes/*  ──►  public.clientes (RLS)
                                                                                     public.clientes_apagamentos
                                                                                     app.cliente_visivel() e
                                                                                     funções de Clientes
                                  src/data/clientes/atendimentos.ts ──► (tabela do Agendamento, quando existir)
```

## 2. Pré-requisitos e bloqueios (para o Gerente de projeto)
A construção começa em PR de rascunho (E22·B), mas cada fase só começa quando a base dela existe.

| # | Falta | Bloqueia | Recomendação |
|---|---|---|---|
| B-1 | **Sessão e ligação do app ao banco**: login, cliente do banco no `src/data` com a sessão da pessoa, leitura do endereço e das chaves do ambiente (RF-08 do item 3 deixou "para a primeira spec que ligar `src/data`"). Nenhuma spec do núcleo cobre o login. | Fase C (servidor e dados reais) e o e2e com banco | spec própria, antes do primeiro módulo; a ordem da fila é do dono (`AGENTS.md` §5). Clientes **não** traz login |
| B-2 | **Molde das 6 portas** (`src/server/portas/`): sessão, estúdio, papel, validação, banco, registro, iguais em todo módulo (`ARCHITECTURE.md` §4 "mesmo molde") | Fase C | entra com B-1 (mesma spec) para os 7 módulos não fazerem 7 moldes |
| B-3 | **Auditoria (porta 6)**: o plano do item 3 §8 manda a spec dela entrar "antes do primeiro módulo que grava dado de cliente". Clientes é esse módulo | pedido de merge (RF-11) | spec própria antes do merge de Clientes |
| B-4 | **País do estúdio**: a spec pede o telefone "já preenchido com o país do estúdio", e `public.estudios` do item 3 não tem país (só fuso, moeda, idioma) | o campo telefone (RN-02) | o item 3 ganha a coluna `pais` (ISO 3166-1 alfa-2, `check ~ '^[A-Z]{2}$'`) no próprio plano; se não der a tempo, Clientes traz a migration M0 do §3 (já na lista fechada, condicional) |
| B-5 | Itens 3 e 4 ainda sem construção na branch (as migrations do item 3 estão só na pasta de trabalho, sem commit; componentes do item 4 não existem) | Fases A e B | esperar os commits deles e juntar de novo (§10) |
| B-6 | **Cópia diária** (E5·3): onde fica o diário de apagamentos fora do banco e o passo de restauração (DP-07, §6.3) | produção (não o merge na `previas`) | requisito escrito para a spec da cópia diária, já agora |

## 3. Migrations (Fase A, Engenheiro de dados)
Criadas com `pnpm exec supabase migration new <nome>` (molde do item 3). Uma por tabela (Assumption 6), mais funções e
políticas, como no item 3.

| # | Nome | Conteúdo |
|---|---|---|
| M0 | `estudios_pais` (**só se B-4 não vier no item 3**) | `alter table public.estudios add column pais text check (pais ~ '^[A-Z]{2}$')`; `grant update (pais)` à dona pela política já existente |
| M1 | `extensoes_busca` | `pg_trgm` no esquema `extensions` (busca por parte do nome e do telefone com índice, RNF-03); disponibilidade e esquema lidos na doc oficial do Supabase antes (§13) |
| M2 | `clientes` | tabela §3.1, índices, RLS ligada sem política, `revoke all` de `anon` e `authenticated` |
| M3 | `clientes_apagamentos` | diário §3.2, RLS ligada, `revoke all` (ninguém com login lê nem grava direto) |
| M4 | `clientes_funcoes` | funções §3.3 |
| M5 | `clientes_politicas` | políticas e privilégios por coluna §3.4 |

### 3.1 `public.clientes` (sugestão para o Engenheiro de dados decidir no ADR)
| Coluna | Tipo e regra |
|---|---|
| `id` | `uuid primary key default gen_random_uuid()` |
| `org_id` | `uuid not null default app.estudio_da_sessao() references public.estudios (org_id) on delete cascade`; sem privilégio de gravação (RN-05: o servidor nem manda) |
| `nome` | `text`, `check (char_length(btrim(nome)) between 1 and 120)` (RN-01) |
| `nome_busca` | `text`: nome sem acento, minúsculo, gerado pela regra de `src/domain` (§5) e gravado pelo servidor; `check (nome_busca = lower(nome_busca))` |
| `telefone` | `text`, `check (telefone ~ '^\+[1-9][0-9]{6,14}$')` (E.164; RN-02; a validade por país é de `src/domain`) |
| `email` | `text` nulo, `check (email = lower(email))` (RN-03) |
| `nascimento` | `date` nulo, `check (nascimento >= '1900-01-01')`; "não futura" no domínio e no servidor (depende do fuso) |
| `ultima_visita` | `date` nulo (RF-08); a spec do Agendamento a mantém (§3.5) |
| `arquivada_em`, `apagada_em` | `timestamptz` nulos |
| `criada_por` | `uuid not null default auth.uid()`, sem privilégio de gravação |
| `criada_em`, `alterada_em` | `timestamptz not null default now()`; `alterada_em` por gatilho `before update` |

- **Cliente ativa × apagada:** `check ((apagada_em is null and nome is not null and nome_busca is not null and telefone is
  not null) or (apagada_em is not null and nome is null and nome_busca is null and telefone is null and email is null and
  nascimento is null))`. Telefone obrigatório é E28·1·A.
- **Chaves e índices:** `unique (org_id, id)` (para `agendamentos (org_id, cliente_id)` ligar só no mesmo estúdio, como
  no antigo 20260619225200); `(org_id, telefone)` **não único** (E28·1·A); GIN `gin_trgm_ops` em `nome_busca` e em
  `telefone`; `(org_id, ultima_visita desc nulls last, id)` e `(org_id, nome_busca, id)` com `where apagada_em is null`,
  para a ordem e a página por cursor (§4.3).
- **Saem** (a sugestão da spec §8 vale como está): `cpf`, documento, `gender`, cidade, `notes`, `fixed_notes`, `alert_*`,
  `tags`, `contact_pref`, `status` em texto, `balance`, `total_spent`, `loyalty_*`, `source`, `location_id`, consentimento
  de imagem, `merged_*`, `blocked_*`.

### 3.2 `public.clientes_apagamentos` (diário, só identificadores)
`org_id uuid not null`, `cliente_id uuid not null`, `apagada_em timestamptz not null default now()`, `primary key (org_id,
cliente_id)`. Sem nenhum dado pessoal. Escrito só por `app.apagar_cliente`. Serve à restauração (§6.3).

### 3.3 Funções (esquema `app`, `security definer`, `set search_path = ''`, nomes qualificados, `revoke` de `public` e `anon`)
| Função | Regra |
|---|---|
| `app.cliente_visivel(p_cliente uuid) returns boolean` | dona e recepção: `true` para cliente de `estudio_da_sessao()`; profissional: `criada_por = auth.uid()` (ver L-1). A spec do Agendamento a **substitui** (`create or replace`) somando "tem ou teve agendamento com ela" (E28·2·B) |
| `app.telefone_em_uso(p_telefone text, p_exceto uuid) returns uuid` | procura no estúdio da sessão, entre não apagadas; devolve o `id` só se `cliente_visivel`, senão `'00000000-…'` fixo (sinal "existe, sem nome"); `null` se não há. Nunca olha outro estúdio (RN-04, CA-02, CA-07b) |
| `app.arquivar_cliente(p_cliente uuid, p_arquivar boolean)` | só dona e recepção (E28·2·B); grava `arquivada_em`; `42501` para os outros |
| `app.apagar_cliente(p_cliente uuid)` | só dona (E28·3·A); no estúdio da sessão; põe nulos em nome, `nome_busca`, telefone, e-mail, nascimento; grava `apagada_em` e a linha do diário, na mesma transação; repetir não dá erro |
| `app.reaplicar_apagamentos(p_ids uuid[])` | **sem** `grant` a `authenticated`: só a tarefa interna da restauração (lista do `SECURITY.md` §2), com a chave de serviço; refaz o apagamento de cada id (idempotente) |

### 3.4 Travas RLS (M5)
`S` = `org_id = (select app.estudio_da_sessao())`; `V` = `(select app.cliente_visivel(id))`.

| Ação | Política | Privilégio de `authenticated` |
|---|---|---|
| Ler | `S and V` | `select` |
| Criar | with check `S and app.papel_da_sessao() in ('dona','recepcao','profissional')` | `insert (nome, nome_busca, telefone, email, nascimento)` |
| Alterar | using e with check `S and V and apagada_em is null` | `update (nome, nome_busca, telefone, email, nascimento)` |
| Arquivar, desarquivar, apagar | só pelas funções §3.3 | sem privilégio direto em `arquivada_em`, `apagada_em`, `org_id`, `criada_por` |
| Apagar linha (`delete`) | nenhuma | nenhum (apagar é anonimizar, RN-07) |

Atenção (Postgres): `insert ... returning` exige que a linha passe também na política de leitura; por isso a
profissional vê o que criou (L-1) e o servidor não depende de `returning` para quem não vê.

### 3.5 Última visita (RF-08) · sugestão
**Guardar** em `clientes.ultima_visita` (como `last_visit` no antigo 20260601000002), porque a lista ordena e pagina
por ela: calcular a cada página varreria os agendamentos de todas as clientes (RNF-02, RNF-03). Quem mantém é a spec do
Agendamento, por gatilho quando o status entra ou sai de Concluído, com a data no fuso do estúdio. Até lá fica nula
("nunca"), como a spec §11 já prevê. A regra (data do último Concluído no fuso) mora em `src/domain/clientes/ultima-visita.ts`
e o teste do Agendamento confere que o gatilho dá o mesmo resultado. Alternativa: calcular por consulta lateral; só
se o Engenheiro de dados provar no teste de volume (§7.2) que cabe.

### 3.6 Tabelas e funções do antigo (decide o Engenheiro de dados, no ADR, conferido por outra instância)
| Antigo | Sugestão do Analista (spec §8) | Observação do Arquiteto |
|---|---|---|
| `clients` | reescrever | desenho §3.1; nada copiado |
| `client_notes` | adiada (Formulários) | — |
| `client_balance_entries` | adiada (Checkout e Financeiro) | — |
| `client_entitlements`, `client_entitlement_entries` | adiada (Catálogo e Checkout) | — |
| `client_marketing_preferences` | adiada (Marketing) | — |
| `client_list_summary`, `client_profile`, mesclagem, bloqueio | descartar | a leitura é consulta direta com RLS (§4.3); sem função de leitura `security definer` (menos superfície, ASVS V4.1.3) |

## 4. Camadas e as 6 portas
### 4.1 Molde de cada ação (`src/server/clientes/acoes.ts`)
Cada ação é uma função de servidor do TanStack Start (nome e uso lidos na doc oficial ao construir, §13) que chama, nesta
ordem, o molde de B-2: **1** sessão válida, senão 401 · **2** estúdio da sessão (o que vier no pedido é descartado pelo
esquema: chave `org_id` ou parecida no corpo dá erro de validação, CA-04) · **3** `pode(papel, acao)` de
`src/domain/clientes/permissoes.ts`, senão 403 · **4** esquema `zod` de `src/server/clientes/esquemas.ts` + regras de
`src/domain` · **5** `src/data/clientes` com a sessão da pessoa (a RLS confere de novo) · **6** registro com `{acao,
cliente_id, membro_id, org_id, quando}`, nunca nome, telefone, e-mail, nascimento ou texto buscado (RF-11).

| Ação | Papéis (E28·2·B, E28·3·A) | Registro |
|---|---|---|
| `listarClientes` (lista, busca, filtros, ordem, página) | dona, recepção, profissional (só as visíveis) | não (leitura) |
| `verCliente`, `listarAtendimentos` | idem | não |
| `verificarTelefone` (aviso de duplicado) | dona, recepção, profissional | não |
| `adicionarCliente`, `editarCliente` | dona, recepção, profissional | sim |
| `arquivarCliente`, `desarquivarCliente` | dona, recepção | sim |
| `exportarCliente` (arquivo) | dona | sim |
| `excluirCliente` | dona | sim |

### 4.2 Regras por camada (lint do item 2 vale; nenhuma regra nova)
- `src/domain/clientes/*`: TypeScript puro + `libphonenumber-js` (biblioteca pura, não é framework nem banco).
- `src/app/paginas/clientes/*`: só chama `src/server`; só componentes do item 4 (`src/app/ui`).
- Busca, filtros e cursor vão no **corpo** do pedido, nunca na URL (DP-04). URL do perfil: `/clientes/<id>`. Filtros e
  ordem guardados no aparelho (`localStorage`, chave sem dado pessoal; Assumption 5); a busca não.

### 4.3 Lista, busca e página (RF-01, RF-02, RN-08, RNF-02, RNF-03; Assumptions 1 e 2)
- Página de **50**; cursor = só o `id` da última linha (o servidor acha o valor de ordem pelo id na mesma consulta), sem
  nome no pedido. Ordem "Última visita": `ultima_visita desc nulls last, id`; "Nome": `nome_busca, id`.
- Busca: a partir de 2 letras ou 3 dígitos, com espera de 300 ms; nome → `nome_busca ilike '%'||termo||'%'` (termo
  normalizado pelo domínio, com `%` e `_` escapados); só dígitos → `telefone like '%'||digitos||'%'`. Com menos de 3
  letras o índice de trigramas não ajuda (doc do `pg_trgm`): ver R-3.
- **Teto de idas ao banco por ação** (provado com um contador no adaptador de teste): lista = 3 (papel da sessão,
  página, total do subtítulo); perfil = 3 (papel, cliente, 1ª página de atendimentos, 20 itens); gravações = 3 (papel,
  telefone em uso, gravação). Não cresce com o número de clientes.

## 5. Regras puras (`src/domain/clientes/`)
| Arquivo | Regra | Requisito |
|---|---|---|
| `cliente.ts` | validar nome (RN-01), e-mail (RN-03), nascimento (RN-03, "hoje" no fuso do estúdio recebido por parâmetro); montar a cliente para gravar | RF-03, RF-05, RF-09 |
| `telefone.ts` | número no país escolhido → E.164, válido para o país (RN-02), com `libphonenumber-js` | RN-02 |
| `busca.ts` | normalizar nome (minúsculo, sem acento por `normalize('NFD')`), extrair dígitos, tamanho mínimo, escapar curingas | RF-02 |
| `ultima-visita.ts` | data do último Concluído no fuso do estúdio | RF-08 |
| `permissoes.ts` | matriz papel × ação do §4.1 | §3 da spec |
| `exportacao.ts` | montar o documento exportado e o nome do arquivo (§6.1) | DP-08 |
| `duplicado.ts` | o que o aviso pode mostrar (com nome só se visível) | RN-04, E28·1·A |

RF-09 (cadastro rápido do Agendamento) usa `cliente.ts` e `telefone.ts` e a ação `adicionarCliente`: nenhuma regra
duplicada no Agendamento.

## 6. Pedidos da cliente (RGPD e LGPD; E28·3·A)
### 6.1 Exportar (RF-10, DP-08, CA-07)
- Rota de servidor `GET /clientes/<id>/exportar` (só o id na URL), só dona, pelas 6 portas.
- **Formato:** JSON (UTF-8), estruturado, de uso comum e lido por máquina (RGPD art. 20(1); Assumption 4). Conteúdo:
  `exportado_em`, dados da cliente (nome, telefone, e-mail, nascimento, cliente desde) e atendimentos (data, serviço,
  status; profissional só pelo primeiro nome, ponto para o Engenheiro de segurança, R-6). Nada de outra cliente.
- **Nome do arquivo:** `cliente-<id>-<AAAAMMDD>.json`, sem nome nem telefone (`Content-Disposition: attachment`).
- **Sem cache:** `Cache-Control: no-store`, `Pragma: no-cache`, `X-Content-Type-Options: nosniff` (ASVS V8.2.1, V14.4).
- **Nada guardado no servidor:** o documento é montado em memória e devolvido na mesma resposta; nenhum `Storage`,
  arquivo temporário, fila ou registro de erro com o conteúdo (o Worker nem tem disco). O registro (porta 6) só diz
  "exportado, cliente <id>, por <membro>".

### 6.2 Excluir (RN-07, RF-10)
⋮ do perfil → janelinha de confirmação (texto avisa que não se desfaz) → `excluirCliente` → `app.apagar_cliente`. Agenda e
perfil mostram "Cliente removida" (texto do arquivo de idioma) quando `apagada_em` não é nulo.

### 6.3 Como o apagado não volta numa restauração (DP-07; dependência B-6)
1. O apagamento grava, na mesma transação, o id em `clientes_apagamentos` (só ids).
2. **Requisito para a spec da cópia diária** (B-6): manter uma cópia desse diário **fora do banco**, só de inclusão e
   atualizada a cada apagamento (senão uma perda total levaria junto os apagamentos do dia), na UE, só com ids.
3. Roteiro de restauração (mesma spec): restaurar → antes de abrir o sistema, a tarefa interna chama
   `app.reaplicar_apagamentos(<ids do diário de fora com data depois da cópia>)` → confere 0 dado pessoal nessas linhas
   → abre. O teste mensal de restauração prova o passo.
4. Restos físicos: a linha antiga fica no arquivo do Postgres até o `VACUUM` e no histórico de recuperação até ele
   vencer; vale o mesmo prazo de guarda das cópias que a cliente é informada (DP-07).
5. Prova já em Clientes: `clientes_140_apagar_test.sql` simula a restauração (devolve a linha antiga como `postgres`),
   chama `reaplicar_apagamentos` e confere que nenhum campo pessoal volta, e que repetir não dá erro.
Alternativa descartada: cifra por cliente com chave apagada ("crypto-shredding"): pede cofre de chaves e cifra de todos
os campos, sem ganho para dado que não é de saúde na v1.

## 7. Testes
### 7.1 Unidade (Vitest; CA-01, CA-04, CA-07, CA-07b, CA-08)
`src/domain/clientes/*.test.ts` (um por arquivo do §5); `src/server/clientes/acoes.test.ts` (ordem das portas; 401 e 403;
`org_id` no corpo recusado; profissional não recebe nome nem serviço que não vê; teto de idas; registro sem dado
pessoal); `src/server/clientes/exportar.test.ts` (cabeçalhos, nome do arquivo, conteúdo só da cliente, nada gravado);
`src/app/paginas/clientes/textos.test.ts` (pt, es, en com as mesmas chaves, nenhuma vazia); `clientes.test.tsx`
(`renderToString`, como no item 4).
Varredura de dado pessoal (CA-08): os testes do servidor usam nome, telefone e e-mail fictícios marcados e conferem que
nenhum aparece em URL, registro, mensagem de erro ou aviso.

### 7.2 Banco (pgTAP, `supabase/tests/database/`, dados fictícios escritos do zero; CA-02, CA-03, CA-07, CA-07b, RNF-03)
| Arquivo | Prova |
|---|---|
| `clientes_100_isolamento_test.sql` | cópia do molde do item 3 (`supabase/moldes/isolamento_tabela_test.sql`) para `clientes` e `clientes_apagamentos`: A não lê, cria, altera, arquiva nem apaga cliente de B; sem papel e sem login nada; `org_id` de B no insert recusado |
| `clientes_110_papeis_test.sql` | matriz do §4.1 (E28·2·B, E28·3·A): profissional lê só o que `cliente_visivel` deixa, cria, edita as que vê, recebe `42501` em arquivar e apagar; recepção `42501` em apagar; dona tudo |
| `clientes_120_telefone_test.sql` | mesmo telefone em B não dá sinal em A; em A, para a profissional que não vê a dona do número, só o sinal "existe, sem nome"; E28·1·A deixa gravar o repetido |
| `clientes_130_regras_test.sql` | `check` do §3.1 (E.164, nome, e-mail minúsculo, nascimento, coerência ativa × apagada) |
| `clientes_140_apagar_test.sql` | depois de apagar, nenhum campo pessoal se lê; diário com a linha; restauração simulada + `reaplicar_apagamentos` (§6.3); `authenticated` sem execução de `reaplicar_apagamentos` |
| `clientes_150_volume_test.sql` | 50 000 clientes fictícias num estúdio, `analyze`; `explain` da busca por nome, por dígitos e das duas ordens sem `Seq Scan` em `clientes` (RNF-03) |

Prova de que o teste pega erro: numa cópia local descartável, tirar `S` ou `V` de uma política e ver `100` ou `110`
ficar vermelho; desfazer (como a tarefa 8 do item 3).

### 7.3 Telas (Playwright, projetos `celular` 390 e `computador` 1440 do item 2; CA-05, CA-06, CA-09)
- `e2e/clientes.spec.ts`: adicionar, editar, erro de campo, aviso de duplicado, buscar por nome e por telefone, filtros e
  "Limpar filtros", Ordenar, arquivar com "Desfazer", perfil e as duas abas, excluir (dona) com a janelinha, exportar
  (o download tem o nome sem dado pessoal), e a URL nunca contém o texto buscado.
- `e2e/clientes-estados.spec.ts`: carregando (só depois de 0,3 s), vazio, sem resultado, aba vazia, erro.
- `e2e/clientes-acessibilidade.spec.ts`: `@axe-core/playwright` (item 4) com as mesmas etiquetas WCAG, lista, perfil,
  painel e janelinha abertos; sem rolagem lateral.
- Dados fictícios. Com B-1 pronto, contra o banco local com login de teste; antes dele, só a parte de tela roda, com um
  adaptador de dados de exemplo local (como o RF-15 do Agendamento), e o e2e completo fica "não verificado".

## 8. Idiomas (RNF-04)
`src/app/paginas/clientes/textos/pt.ts`, `es.ts`, `en.ts`: o mesmo tipo de chaves (o TypeScript acusa chave faltando) e
o teste de §7.1. O idioma vem de `estudios.idioma`; datas por `Intl.DateTimeFormat` com `timeZone` do estúdio (nativo,
sem biblioteca; reuse). Os textos em pt saem do `DESIGN.md` §6 e §8 e da spec; es e en, pelo Designer de produto, com
revisão de outro papel. Se uma spec de idiomas comum entrar antes, Clientes passa a usá-la (ADR novo).

## 9. Lista FECHADA de arquivos
Fora desta lista nada muda (`AGENTS.md` §6). Arquivo novo que uma ferramenta crie fora daqui: parar e relatar.

**Banco (Engenheiro de dados)**
- `supabase/migrations/<ts>_estudios_pais.sql` (**só** se B-4 não vier do item 3)
- `supabase/migrations/<ts>_extensoes_busca.sql`, `<ts>_clientes.sql`, `<ts>_clientes_apagamentos.sql`,
  `<ts>_clientes_funcoes.sql`, `<ts>_clientes_politicas.sql`
- `supabase/tests/database/clientes_100_isolamento_test.sql` a `clientes_150_volume_test.sql` (6 arquivos, §7.2)
- `docs/adr/<NNNN>-clientes-dados-busca-e-pedidos.md` (decisões por tabela §3.6 e técnicas §13; conferência preenchida
  na revisão)

**Regras (Engenheiro de software)**: `src/domain/clientes/{cliente,telefone,busca,ultima-visita,permissoes,exportacao,duplicado}.ts`
e um `.test.ts` para cada.

**Servidor e dados (Engenheiro de software; Fase C, depois de B-1 e B-2)**: `src/server/clientes/acoes.ts`,
`esquemas.ts`, `exportar.ts`, `acoes.test.ts`, `exportar.test.ts`; `src/data/clientes/repositorio.ts`,
`atendimentos.ts` (vazio até o Agendamento: devolve lista vazia), `exemplo-local.ts` (adaptador fictício só para teste
de tela, §7.3), `repositorio.test.ts`.

**Telas (Engenheiro de software, pelo desenho do Designer de produto)**
- `src/app/routes/clientes/index.tsx`, `src/app/routes/clientes/$clienteId.tsx`, `src/app/routeTree.gen.ts` (gerado)
- `src/app/paginas/clientes/{lista,perfil,painel-cliente,filtros-ordem,confirmar-excluir}.tsx`, `clientes.css`,
  `preferencias.ts`, `textos/{pt,es,en}.ts`, `textos.test.ts`, `clientes.test.tsx`
- `e2e/clientes.spec.ts`, `e2e/clientes-estados.spec.ts`, `e2e/clientes-acessibilidade.spec.ts`

**Raiz (Engenheiro de software)**: `package.json` e `pnpm-lock.yaml`, só `libphonenumber-js` 1.13.17 e `zod` 4.6.7
(§13; `zod` sai daqui se B-2 já o trouxer).

**Ficha visual (Designer de produto)**: `specs/20261128-021000-clientes/ficha-visual.md` e `ficha/*.png` (390 e 1440,
dados fictícios). **Texto (Designer de produto, só com o dono):** `DESIGN.md`, só as linhas aprovadas na ficha (título do
perfil, botão de agendar daqui, "Exportar dados da cliente").

**Processo**: `specs/20261128-021000-clientes/{spec.md,plan.md,tasks.md}` · `docs/STATUS.md`, `docs/BACKLOG.md`,
`CHANGELOG.md`, `docs/decisoes/2026-11-27-fundacao.md` (respostas E28), pelo Documentador.

**Intactos:** `src/*/AGENTS.md`, `src/*/CLAUDE.md`, `src/app/ui/**` e `src/app/estilos/**` (item 4), `src/server/portas/**`
(B-2), as migrations e testes dos itens 2 e 3, `supabase/config.jsonc`, `eslint.config.mjs`, `src/domain/exemplo.ts`
(sai na spec que o Gerente indicar, para não haver conflito entre módulos paralelos), `ARCHITECTURE.md`, `SECURITY.md`,
`.github/**`.

## 10. Branch (decisão do Engenheiro de DevOps)
`feat/clientes` recebe por **merge** a `feat/banco-ligacao` e a `feat/design-system-codigo` (cada uma já com a
`chore/fundacao-tecnica`), nessa ordem, antes da Fase A; e de novo sempre que elas ganharem commit. PR de rascunho
empilhado; nunca se junta nelas. Quando os itens 2, 3 e 4 entrarem na `previas`, a base do PR passa à `previas`, antes
do pedido de merge.

## 11. Papéis
| Etapa | Papel |
|---|---|
| Migrations, funções, políticas, pgTAP, ADR das tabelas | Engenheiro de dados |
| Regras, servidor, dados, telas, idiomas, testes de unidade e e2e | Engenheiro de software |
| Desenho das telas, ficha visual, textos es e en | Designer de produto |
| Revisão do código | Revisor de código |
| Revisão do banco e conferência do ADR item por item (E16·1) | Engenheiro de dados (outra instância, que não construiu) |
| Dado pessoal, acesso, exportar e apagar (DP-01 a DP-08) | Engenheiro de segurança e Auditor de risco |
| Telas e ficha antes do dono | Revisor de design |
| Veredito CA-01 a CA-12 | Analista de qualidade (QA) |

## 12. Se o dono responder diferente
| Resposta | O que muda no plano |
|---|---|
| **E28·1·B** (repetido não salva) | índice único parcial `(org_id, telefone) where apagada_em is null`; `verificarTelefone` vira erro de campo; `clientes_120` testa a recusa (`23505`) e que a recusa não revela cliente de outro estúdio. Mais 0 arquivos |
| **E28·1·C** (mais documento, gênero, cidade) | 3 colunas em §3.1 e nos privilégios; validação de documento por país em `src/domain` (biblioteca a escolher, nova linha no ADR); exportação e idiomas crescem; DP-03 muda na spec. Mais 1 arquivo de regra e teste |
| **E28·2·A** (vê todas) | `cliente_visivel` devolve `true` para os três papéis; o aviso de duplicado sempre com nome; `clientes_110` muda; o Agendamento não substitui a função. Exige E26·1·A |
| **E28·2·C** (igual à recepção) | como E28·2·A, e `arquivar_cliente` aceita a profissional |
| **E28·3·B** (suporte faz à mão) | saem `exportar.ts`, `exportacao.ts`, `confirmar-excluir.tsx` e os passos de e2e; `apagar_cliente` perde o `grant` a `authenticated` e vira tarefa interna listada com chave de serviço (`SECURITY.md` §2); exportar à mão pede roteiro e uma spec do painel admin. Não recomendado: o suporte passaria a tocar dado de cliente |
| **E28·3·C** (só excluir) | saem `exportar.ts`, `exportar.test.ts`, `exportacao.ts` e o passo de e2e do download |
| **E26·1·A** com **E28·2·B** | incoerente (spec §13): o trabalho para até o dono alinhar |

## 13. Decisões técnicas (vão ao ADR na tarefa 2)
| # | Decisão | Motivo e norma |
|---|---|---|
| D1 | Telefone por `libphonenumber-js` 1.13.17 (MIT, 19/11/2026, mais de 3 dias, regra do ADR 0002 · D4) | Assumption 3; biblioteca de mercado da numeração internacional (reuse, `AGENTS.md` §3 regra 6). Funções e conjunto de metadados lidos no README oficial ao construir (não lido nesta etapa) |
| D2 | Esquema da porta 4 por `zod` 4.6.7 (MIT, 12/10/2026), salvo se B-2 escolher outro | `ARCHITECTURE.md` §4 porta 4 ("com esquema"); ASVS V5.1 |
| D3 | Busca por `pg_trgm` com GIN sobre `nome_busca` (normalizado no domínio) e `telefone` | RNF-03 sem varrer a tabela; normalizar no domínio deixa a regra testável (CA-01) e evita `unaccent` em índice, que não é imutável (doc do Postgres) |
| D4 | Página por cursor de id (50 itens), teto de 3 idas ao banco por ação | `ARCHITECTURE.md` §5 e §11; sem dado pessoal no cursor (DP-04) |
| D5 | Apagar = anonimizar a linha + diário só de ids; arquivar e apagar só por funções com papel conferido | RN-07; histórico preservado; privilégio por coluna não distingue papéis (Postgres), a função sim (ASVS V4.1.3) |
| D6 | Exportar em JSON montado em memória, `no-store`, nome com id e data | RGPD art. 20; ASVS V8.2.1, V8.3 |
| D7 | `org_id` e `criada_por` com valor padrão da sessão e sem privilégio de gravação | RN-05; o pedido não consegue nem tentar (defesa em profundidade) |
| D8 | `ultima_visita` guardada, mantida pela spec do Agendamento | §3.5 |
| D9 | Textos por arquivo TS por idioma, datas por `Intl` | RNF-04; sem biblioteca nova |

## 14. Lacunas para o Analista de requisitos (não decido; `AGENTS.md` §4)
- **L-1 · E28·2·B e a cliente recém-criada.** Pelo texto, a profissional vê só quem "já atendeu ou tem marcada com ela":
  logo depois de "Adicionar" em Clientes, ela não veria a própria cadastrada (e o banco recusa o `returning`). Proposta:
  a opção B diz "e as que ela cadastrou". É acesso: muda o texto da E28·2·B antes de ir ao dono, sem virar 4ª dúvida.
- **L-2 · País do estúdio (B-4):** a spec lista "estúdio com fuso e país" como entrega do item 3, que não o tem.
  Ajustar a dependência do item 3 ou aceitar a M0 aqui.
- **L-3 · Auditoria (B-3):** a spec trata o registro como existente; o item 3 o empurra para spec própria. Fica explícito
  na §11 da spec como dependência de merge.

## 15. Riscos e não verificado
- R-1 · Nada foi construído nem rodado. Bases dos itens 3 e 4 sem construção (B-5).
- R-2 · `createServerFn`, rotas de servidor (`GET` para o arquivo) e rotas por pasta do TanStack Start: nomes e moldes
  **não verificados** nesta etapa; lidos na doc oficial na tarefa 1, antes de escrever.
- R-3 · Busca com 2 letras não usa o índice de trigramas (precisa de 3); com estúdio grande, pode varrer. Medir no
  `clientes_150`; se passar do teto, subir o mínimo para 3 letras, o que muda a Assumption 2 (volta ao Analista).
- R-4 · Disponibilidade e esquema do `pg_trgm` na imagem local do Supabase CLI 3.4.0: **não verificado**.
- R-5 · `db:start` do item 2 desliga Auth e PostgREST; o e2e com login depende de B-1 (pode mudar o `package.json`
  lá, não aqui).
- R-6 · Nome da profissional no arquivo exportado é dado de terceira (RGPD art. 20(4)): o Engenheiro de segurança decide
  manter só o primeiro nome ou tirar.
- R-7 · Se o servidor falar com o banco pela API REST do Supabase, as tabelas de `public` com `grant` a `authenticated`
  ficam alcançáveis pelo navegador com o token da pessoa, o que o `ARCHITECTURE.md` §4 proíbe ("navegador nunca fala
  direto com o banco"). A forma de ligar (REST com esquema fora da API, ou ligação direta ao Postgres com papel e
  declarações por transação) é decisão de B-1; Clientes fica isolado disso atrás de `src/data/clientes/repositorio.ts`.
- R-8 · Numeração de ADR e de migrations com 7 módulos em paralelo: conflito de número na hora do merge; o Documentador
  dá o número e o Engenheiro de dados regenera o carimbo da migration se preciso.
