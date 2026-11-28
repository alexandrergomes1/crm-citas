# Plano · Formulários (núcleo): modelos, preencher pelo link e ficha de saúde cifrada

- **Spec:** `specs/20261128-021500-formularios/spec.md` (Draft; 5b e revisão de segurança da spec feitas)
- **Escrito por:** Arquiteto de software · **Norma:** modelo C4 e ADR (mais Clean Architecture; OWASP ASVS 4.0.3 V4,
  V5, V6, V7, V8, V11, nível 3 neste módulo; RGPD art. 5, 7, 9, 25; boas práticas Postgres e Supabase) · **Revisão:**
  5b (Gerente de projeto) feita com ajustes, 28/11; etapa 5 (Analista de requisitos) pendente; segurança: Engenheiro de segurança e Auditor de risco
- **Funciona com as recomendações:** E29·1·A (link), E29·2·A (com E26·1·B e E28·2·B), E29·3·A (caixinha + nome
  digitado). O que muda com outra resposta: §13.
- **Decisões técnicas:** `docs/adr/0014-formularios-cifra-link-e-imutabilidade.md` (Arquiteto, escrito nesta etapa,
  Proposto). Tabelas do antigo: ADR **0013** do Engenheiro de dados (tarefa 3), com a sugestão do §3.8.
- **Bases lidas em 28/11/2026 (não editadas):** item 3 (`feat/banco-ligacao`: ADR 0005, migrations
  `20261128002040` a `20261128002045`, `supabase/moldes/isolamento_tabela_test.sql`, `010_base_estrutura_test.sql`,
  `supabase/config.jsonc`, `package.json`); item 4 (`feat/design-system-codigo`: ADR 0004, `src/app/ui/`); spec E36·A
  (`feat/entrar-servico`, sem plano ainda); planos da Agenda (ADR 0006) e de Clientes (`plan.md`, ADR 0008 por vir).
- **Numeração (decisão técnica do Gerente, 28/11):** testes pgTAP de Formulários na faixa **4xx**; idiomas no bloco
  `formularios` da base comum `src/app/i18n/` (`feat/entrar-servico`).

## 0. PARADA: cofre de chaves (RNF-02) não tem opção gratuita · vira pergunta ao dono
A RNF-02 pede um cofre externo (KMS) que **cifra e decifra ele mesmo**, sem o app segurar a chave mestra. A E23·3·A
diz "só o gratuito; achou custo, para e pergunta; nenhum cartão cadastrado". Lido na documentação oficial em 28/11/2026:

| Opção | O que a fonte oficial diz | Cumpre RNF-02? | Gratuito (E23·3·A)? |
|---|---|---|---|
| AWS KMS (https://aws.amazon.com/kms/pricing/) | 20 000 pedidos/mês grátis; **cada chave do cliente custa US$ 1/mês**; 1ª e 2ª troca automática somam US$ 1/mês cada | sim | **não** (US$ 1 a 3/mês) |
| Google Cloud KMS (https://cloud.google.com/kms/pricing) | "You must sign up for billing before you can start using Cloud KMS"; chave SOFTWARE US$ 0,000082192/h (~US$ 0,06/mês por versão) + US$ 0,03 por 10 000 operações; grátis só chaves do **Autokey** (100 versões, 10 000 operações/mês), que é feito para chaves de recursos do próprio Google (CMEK, https://cloud.google.com/kms/docs/autokey-overview) | sim (Autokey para uso direto do app: não verificado) | **não** (cobrança cadastrada; centavos/mês) |
| Azure Key Vault (https://azure.microsoft.com/en-us/pricing/details/key-vault/) | preço por 10 000 operações (valores não carregaram na página); conta grátis com crédito de 30 dias | sim | **não** |
| Infisical KMS (https://infisical.com/pricing; https://infisical.com/docs/documentation/platform/kms/overview) | "applications never have access to the keys"; na tabela de planos, "KMS & HSM support" não está nos planos gratuitos | sim | **não** |
| OpenBao, motor "transit" (https://openbao.org/docs/secrets/transit/) | software livre que cifra como serviço e não guarda o dado | sim | software sim; **precisa de servidor ligado na UE** (custo de hospedagem) |
| Cloudflare Secrets Store (https://developers.cloudflare.com/secrets-store/) | guarda segredo para o Worker usar (beta) | **não**: o app recebe a chave | sim |
| Supabase Vault | mora dentro do banco | **não** (a spec exclui) | sim |

**Conclusão:** não há opção que cumpra a RNF-02 e seja gratuita. O plano **para neste ponto** (fase D, §10) e o
Gerente de projeto leva ao dono, no relatório, a pergunta E40 (texto do Gerente, 5b):

> **E40 · Cofre da chave das fichas de saúde** — A: Google Cloud KMS na Europa, centavos de dólar por mês, cartão
> cadastrado (cumpre a norma); B: chave no próprio app, grátis (cumpre a cifra exigida no nível 2, ASVS V6.1.2, mas não
> a V6.4.2, de nível 3, que o SECURITY.md adota para a ficha; exceção do dono no ARCHITECTURE.md); C: cofre em servidor
> próprio na Europa (cumpre; custa hospedagem e manutenção). Recomendo A (ASVS V6.4.2 nível 3; RGPD art. 32, medidas
> adequadas ao risco).

Texto da E40 com as correções do Engenheiro de segurança (28/11): V6.4.2 é de nível 3; B cumpre V6.1.2 (nível 2).

**Fase D com E40·A (Google Cloud KMS), como fica:**
- **Envelope, não cifra direta.** A doc oficial limita cada pedido de cifrar a **64 KiB** de texto em chave SOFTWARE
  (8 KiB em HSM; https://cloud.google.com/kms/docs/reference/rest/v1/projects.locations.keyRings.cryptoKeys/encrypt) e
  diz que o KMS foi feito para cifrar chaves (https://cloud.google.com/kms/docs/envelope-encryption). Uma ficha pode
  passar de 200 KB (100 perguntas × 2 000 caracteres), então o app gera uma chave por ficha, cifra a ficha com ela e
  manda ao KMS **só essa chave** (32 bytes) para embrulhar. A chave mestra nunca sai do KMS; a chave da ficha fica na
  memória do app só durante o pedido. Isso fica fora da V6.4.2 ao pé da letra e está registrado no ADR 0014 D1, para o
  Auditor de risco (CA-13).
- **Permissão do Worker:** a conta do Worker só pode cifrar e decifrar **com uma chave** (o papel do IAM dado na própria
  chave, não no projeto); sem criar, trocar, destruir nem ler outras chaves. Nome exato do papel lido na doc na tarefa 23.
- **Registro de uso do KMS:** Cifrar e Decifrar geram registro "Data Access" (https://cloud.google.com/kms/docs/audit-logging),
  que precisa ser ligado (se vem ligado e se tem custo no Cloud Logging: não verificado). O registro mostra só a conta do
  Worker, nunca a pessoa: o app não manda ao KMS nada que identifique quem pediu, então o modo suporte do dono continua
  sem registro (E6·1, como está). A prova de quem abriu a ficha é o registro da porta 6 (RF-12).
- Região na UE e contrato (DPA): **não verificados**, conferidos pelo Engenheiro de segurança antes da fase D (tarefa 23).

Tudo o mais deste plano não depende da resposta: o app fala com o cofre por uma porta (`CofreDeChaves`, §4.3) e os
testes usam um cofre local falso, só para teste, com dado fictício (E22·B).

## 1. Resumo (C4)
**Contexto:** dona, recepção e profissional usam o app; a **cliente do estúdio** abre a página do link no próprio
celular, sem login; sistema externo novo: o **cofre de chaves** (KMS, §0). Nenhum envio por WhatsApp ou e-mail.
**Contêiner:** o app (TanStack Start, Cloudflare Workers), o banco (Postgres do Supabase) e o cofre (KMS).
**Componentes:**

```
src/app/paginas/formularios/*  ──►  src/server/formularios/acoes.ts ──►  src/domain/formularios/* (regras puras)
 (Fichas, Modelos, painéis)          (6 portas, molde E36·A)        │
                                     src/server/formularios/cifra.ts ──► src/server/cofre/ (porta CofreDeChaves)
                                                                    │      ├─ cofre-local.ts (só teste)
src/app/paginas/ficha-link/*  ──►  src/server/formularios/link.ts  │      └─ cofre-kms.ts (fase D, após o dono)
 (página da cliente, /f#token)      (ação pública, sem login)       ▼
                                                        src/data/formularios/* ──► tabelas formularios_* (RLS)
                                                                                   app.* (funções com sessão)
                                                                                   ficha_link.* + public.ficha_link_*
                                                                                   (só o link, sem login)
```

## 2. Pré-requisitos e bloqueios (para o Gerente de projeto)
| # | Falta | Bloqueia | Recomendação |
|---|---|---|---|
| B-1 | **Cofre de chaves** (§0, E40) | fase D (cofre real) e o pedido de merge | pergunta E40 ao dono; até lá, só o cofre local de teste |
| B-2 | Login, molde das 6 portas, `zod`, auditoria e limite de tentativas por endereço (E36·A, `feat/entrar-servico`, ainda sem plano) | fase C | Formulários só usa |
| B-3 | **Ação pública** no molde da E36·A: o RF-21 dela barra ação fora do molde, e o link não tem login. É preciso uma variante declarada "pública por link" (porta 1 = token; porta 2 = estúdio da ficha, dado pela função do banco; porta 3 = ler perguntas e assinar; portas 4 a 6 iguais) | página da cliente | pedir ao plano da E36·A; se não vier, o trabalho da página para e o Gerente decide (não se cria um segundo molde aqui) |
| B-4 | **Registro sem login**: o registro da E36·A aceita linhas de quem tem sessão (RF-26 dela); a assinatura pelo link grava linha sem `usuario_id`, com o `org_id` da ficha | RF-12 (assinar) | o plano da E36·A define o meio; Formulários grava a linha de dentro de `ficha_link.assinar` usando esse meio |
| B-5 | **Teste 010 do item 3** conta as funções que `anon` e `authenticated` executam (lista fixa). Formulários dá a `anon` exatamente 2 funções (`public.ficha_link_abrir`, `public.ficha_link_assinar`) e a `authenticated` as funções do §3.6. Clientes e a E36·A também acrescentam funções | `pnpm db:test` | o Engenheiro de dados do item 3 (ou da E36·A) torna a lista extensível; senão Formulários **só acrescenta seus nomes** à lista do 010, conferido pelo Auditor de risco (linha condicional da lista fechada) |
| B-6 | Clientes (`feat/clientes`): `public.clientes` com `unique (org_id, id)`, `app.cliente_visivel()` e `nome_busca` | fase A (chave estrangeira), RF-05, RF-13 | Formulários usa; não altera |
| B-7 | Itens 3 e 4 com construção na branch | fases A e B | esperar e juntar (§11) |
| B-8 | **Agendamento** (`feat/agendamento`): amplia `app.cliente_visivel()` para "atendeu ou tem marcada" (E28·2·B), de que a E29·2·A depende | só o alcance da profissional (CA-06); não bloqueia construção nem merge | até ele entrar, vale a regra de Clientes (L-1 de Clientes: as que ela cadastrou); `420` testa a função como estiver e o Agendamento repete a prova no teste dele |

## 3. Banco (Fase A, Engenheiro de dados) · sugestão a decidir no ADR 0013
Migrations criadas com `pnpm exec supabase migration new <nome>`, uma por tabela (Assumption 4), mais funções, link e
políticas. Toda tabela: `org_id uuid not null default (select app.estudio_da_sessao())` (sem privilégio de gravação),
`enable` e `force row level security`, índice que começa por `org_id`, `revoke all` de `anon` e `authenticated` e só o
`grant` necessário (molde do item 3, ADR 0005 D7 e D9).

| # | Migration | Conteúdo |
|---|---|---|
| M1 | `formularios_modelos` | §3.1 |
| M2 | `formularios_modelo_versoes` | §3.2 |
| M3 | `formularios_fichas` | §3.3 |
| M4 | `formularios_respostas` | §3.4 (só cifrado) |
| M5 | `formularios_links` | §3.5 (só o resumo do token) |
| M6 | `formularios_link_limite` | §3.5 (limite por estúdio) |
| M7 | `formularios_funcoes` | §3.6 (com sessão) |
| M8 | `formularios_link_funcoes` | §3.7 (esquema `ficha_link` e passagem em `public`) |
| M9 | `formularios_politicas` | §3.6 (RLS e privilégios) |

### 3.1 `formularios_modelos`
`id uuid pk default gen_random_uuid()`, `org_id`, `versao_atual int not null default 1`, `arquivado_em timestamptz`,
`criado_por uuid not null default auth.uid()`, `criado_em timestamptz not null default now()`; `unique (org_id, id)`.
Título e conteúdo ficam só na versão (uma fonte da verdade).

### 3.2 `formularios_modelo_versoes` (versão = linha que não muda; RF-03, CA-01)
`org_id`, `modelo_id`, `versao int check (versao >= 1)`, `titulo text check (char_length(btrim(titulo)) between 1 and 120)`,
`perguntas jsonb check (jsonb_typeof(perguntas) = 'array' and jsonb_array_length(perguntas) between 1 and 100)`,
`termo text check (char_length(btrim(termo)) between 1 and 10000)`, `criada_por`, `criada_em`;
`primary key (org_id, modelo_id, versao)`, chave estrangeira `(org_id, modelo_id)` → modelos. Gatilho `before update or
delete` recusa sempre (`42501`); `update` e `delete` sem privilégio. Forma de cada pergunta (id estável, tipo dos 5 do
RF-02, texto até 500, obrigatória, até 20 opções de até 120) validada no domínio e no esquema do servidor (não em
`check`: a regra é testável em `src/domain`). Conteúdo do modelo não é dado de saúde (é escrito pelo estúdio, sem
cliente): fica em claro.

### 3.3 `formularios_fichas`
`id uuid pk`, `org_id`, `cliente_id uuid not null`, `modelo_id`, `versao int not null`, `situacao text not null default
'aguardando' check (situacao in ('aguardando','concluida'))`, `meio text check (meio in ('link'))` (nulo até assinar;
`'estudio'` entra com o modo PIN), `assinada_em timestamptz`, `substituida_por uuid` (E29·3·A), `criada_por`, `criada_em`.
- Chaves estrangeiras: `(org_id, cliente_id)` → `clientes (org_id, id)`; `(org_id, modelo_id, versao)` → versões; a
  ficha nunca liga a cliente ou modelo de outro estúdio.
- `check ((situacao = 'aguardando') = (assinada_em is null))`; `check (substituida_por is null or situacao = 'concluida')`.
- Gatilho: ficha `concluida` não se apaga e só aceita uma mudança: `substituida_por` de nulo para um id do mesmo estúdio.
- Nenhum nome de cliente copiado (no antigo, `client_name`); a lista junta com `clientes` pela RLS.
- Índices: `(org_id, criada_em desc, id)` (Ordenar "Data", proposta da spec §4), `(org_id, cliente_id)`, `(org_id, modelo_id)`.

### 3.4 `formularios_respostas` (só cifrado; RNF-01, RF-08, RF-09, CA-03, CA-04)
| Coluna | Tipo e regra |
|---|---|
| `org_id`, `ficha_id` | `primary key (org_id, ficha_id)`, chave estrangeira para a ficha |
| `cifra` | `bytea not null`, `check (octet_length(cifra) between 29 and 1100000)`: 1 byte de formato + 12 de IV + texto + 16 da etiqueta (AES-256-GCM, ADR 0014 D1). Dentro: as respostas **e** o nome digitado na assinatura |
| `chave_envelope` | `bytea not null`: a chave da ficha cifrada pelo cofre (a chave mestra nunca sai do cofre) |
| `chave_ref` | `text not null`, `check (char_length(chave_ref) <= 300)`: nome da versão da chave mestra (para a troca, CA-04) |
| `formato` | `smallint not null check (formato = 1)` |
| `termo_aceito` | `boolean not null check (termo_aceito)` (RF-07, RF-08) |
| `versao` | `int not null` (a versão do modelo e do termo aceitos, repetida de propósito para a prova, RF-08) |
| `assinada_em` | `timestamptz not null default now()` (hora do servidor do banco, RF-08) |

- Sem IP, sem aparelho, sem texto em claro (RF-08, RNF-01). Nenhuma coluna `text`/`jsonb` com resposta: o teste `450`
  confere pelo catálogo.
- Imutável: gatilho `before update or delete` recusa sempre; sem privilégio de `update`, `delete` nem `insert` para
  `authenticated` (só `ficha_link.assinar` grava, §3.7).

### 3.5 `formularios_links` e `formularios_link_limite` (RF-06, RNF-04, RNF-04b)
- `formularios_links`: `org_id`, `ficha_id` (`primary key (org_id, ficha_id)`: um link por ficha), `resumo bytea not null
  unique check (octet_length(resumo) = 32)` (SHA-256), `vence_em timestamptz not null`, `criado_em`. **Nunca o token.**
  Sem privilégio para ninguém com login; escrito por `app.gerar_link_ficha` e apagado ao assinar ou excluir.
- `formularios_link_limite`: `org_id`, `minuto timestamptz`, `contagem int`, `primary key (org_id, minuto)`; escrito só por
  `ficha_link.*`; linhas de mais de 1 dia apagadas pela própria função. Sem dado pessoal, sem IP.

### 3.6 Funções com sessão e travas (M7, M9) · E29·2·A
Esquema `app`, `security definer`, `set search_path = ''`, nomes qualificados, `revoke` de `public` e `anon`.

| Função | Regra |
|---|---|
| `app.ficha_respostas_visiveis(p_ficha uuid) returns boolean` | dona: `true` no estúdio da sessão; profissional: `app.cliente_visivel(cliente_id)` (Clientes; o Agendamento a amplia, E28·2·B); recepção: `false` |
| `app.salvar_versao_modelo(p_modelo uuid, p_titulo, p_perguntas, p_termo) returns int` | só dona; cria o modelo (se `p_modelo` nulo) ou a versão `versao_atual + 1`; devolve a versão |
| `app.arquivar_modelo(p_modelo uuid, p_arquivar boolean)` | só dona |
| `app.excluir_modelo(p_modelo uuid)` | só dona e só se nenhuma ficha o usa (RF-04); apaga as versões junto (único caminho que apaga versão, gatilho liberado por variável de transação local da própria função) |
| `app.gerar_link_ficha(p_ficha uuid, p_resumo bytea)` | dona, recepção, profissional (esta só com `cliente_visivel`); ficha `aguardando`; troca a linha do link (o anterior deixa de valer) e põe `vence_em = now() + 7 dias`. Recebe **só o resumo**: o token nunca chega ao banco |

| Tabela | Ler (`select`, `to authenticated`) | Gravar |
|---|---|---|
| modelos e versões | `S` (os três papéis escolhem modelo) | só pelas funções acima |
| fichas | `S and (papel in ('dona','recepcao') or app.cliente_visivel(cliente_id))` | `insert (cliente_id, modelo_id, versao)` com check `S` + modelo ativo na versão atual + cliente visível; `delete` só `aguardando` (RF-10); `update` nenhum |
| respostas | `S and app.ficha_respostas_visiveis(ficha_id)` (recepção não recebe nem a cifra, RF-11, CA-06) | nenhum |
| links, limite | nenhum | nenhum |

`S` = `org_id = (select app.estudio_da_sessao())`.

### 3.7 Link sem login (M8; RF-14, RNF-04, CA-05, CA-07) · ADR 0014 D3 e D4
- Esquema próprio **`ficha_link`** (fora de `api.schemas`, como `app`), com duas funções `security definer`,
  `set search_path = ''`. `anon` recebe `usage` em `ficha_link` e `execute` **só** nelas; nada em `app` (o 010 continua
  valendo para `app`).
- Passagem em `public` (`security invoker`), porque a API só expõe `public` (`supabase/config.jsonc`):
  `public.ficha_link_abrir(p_token text)` e `public.ficha_link_assinar(p_token text, p_cifra bytea, p_chave_envelope
  bytea, p_chave_ref text, p_versao int)`. São as **únicas** funções que `anon` executa (B-5).
- O servidor chama com a chave pública do banco e **sem** a chave de serviço (RF-14, CA-05).

| Função | Regra |
|---|---|
| `ficha_link.abrir(p_token text)` | `if char_length(p_token) <> 43 then` resposta vazia; `v := pg_catalog.sha256(convert_to(p_token,'UTF8'))` (núcleo do Postgres 17, lido na doc oficial); acha a linha de `formularios_links` com `resumo = v`, `vence_em > now()` e ficha `aguardando`; soma 1 em `formularios_link_limite` do estúdio da ficha e recusa com `limite` acima de 60/min; devolve **só**: `ficha_id`, `org_id` (para o servidor montar o AAD, nunca vão ao navegador), nome e idioma do estúdio, título, perguntas e termo da versão. Não achou: o mesmo resultado vazio para vencido, assinado, renovado, excluído ou inexistente |
| `ficha_link.assinar(...)` | refaz a busca pelo resumo **na mesma transação** com `for update`; confere `p_versao` = versão da ficha e tamanho da cifra; grava `formularios_respostas` com `termo_aceito = true`, põe a ficha `concluida`, `meio = 'link'`, `assinada_em = now()`, apaga o link e grava o registro (B-4). Não aceita id de ficha nem de estúdio do pedido |

O token: 32 bytes de `crypto.getRandomValues` (256 bits, acima dos 128 da RNF-04 a), em base64url sem `=` (43
caracteres). O resumo no servidor (Web Crypto `SHA-256`, ao gerar) e no banco (`sha256`, ao abrir) é o mesmo cálculo
sobre os bytes UTF-8 do texto. Token de alta entropia dispensa hash lento (ASVS V6.3; ADR 0014 D3).

### 3.8 Tabelas do antigo (decide o Engenheiro de dados no ADR 0013, conferido por outra instância; CA-12)
| Antigo | Sugestão do Analista (spec §7) | Observação do Arquiteto |
|---|---|---|
| `anamnese_templates` | reescrever em modelo + versão | §3.1 e §3.2; sem país fixo, sem termo pronto |
| `anamneses` | reescrever como ficha | §3.3 a §3.5; sai `answers` em claro, `client_name`, IP, aparelho, link em texto |
| `anamnese_answer_versions` | descartar (E29·3·A) | volta cifrada só com E29·3·C (§13) |
| `anamnese_events` | descartar | o registro da porta 6 cobre o RF-12 |
| `anamnese_gate_overrides` | descartar | trava do checkout é depois |
Nenhuma linha, seed nem resposta do antigo é trazida (E22·B).

## 4. Camadas
### 4.1 Ações com sessão (`src/server/formularios/acoes.ts`, molde E36·A)
Portas 1 a 6 em ordem; estúdio da sessão; `org_id` no corpo dá `entrada_invalida`. Registro (porta 6) com `{evento,
ficha_id | modelo_id, usuario_id, org_id, quando}`, nunca resposta, nome, título ou termo (RF-12, CA-08).

| Ação | Papéis (E29·2·A) | Registro |
|---|---|---|
| `listarModelos`, `verModelo` | dona, recepção, profissional | não |
| `salvarModelo`, `duplicarModelo`, `arquivarModelo`, `excluirModelo` | dona | sim |
| `listarFichas` (busca por nome da cliente e título do modelo, RF-13; filtros situação e data; página de 50 por cursor de id) | os três (profissional só clientes visíveis) | não |
| `adicionarFicha` (cria + gera link) | os três (RF-05) | `ficha.criar`, `ficha.link` |
| `renovarLink` | os três | `ficha.link_renovar` |
| `verFicha` (situação, modelo, versão, data) | os três | não |
| `verRespostas` (decifra) | dona; profissional com `ficha_respostas_visiveis` | **sim**, `ficha.respostas_abrir` (RF-12) |
| `excluirFicha` (só `aguardando`) | os três | `ficha.excluir` |

Teto de idas por ação, provado por contador no adaptador de teste: lista 3 (papel, página, total); ver respostas 3 ao
banco + 1 ao cofre; gravações 3.

### 4.2 Ação pública do link (`src/server/formularios/link.ts`, variante de B-3)
- `abrirFichaPorLink({ token })` e `assinarFichaPorLink({ token, respostas, termoAceito, nomeAssinatura })`, por **POST
  com o token no corpo**. Esquema: token `^[A-Za-z0-9_-]{43}$`.
- Assinar: (1) `ficha_link.abrir` traz a versão; (2) `src/domain/formularios/validar-respostas.ts` confere RF-07
  (obrigatórias, tipos, 2 000 caracteres, caixinha marcada, nome com 3 a 120 caracteres); falhou, nada se grava;
  (3) `cifra.ts` cifra; (4) `ficha_link.assinar`. Respostas: "Ficha enviada" sem repetir nada.
- Limite por endereço (RNF-04b): o limitador da E36·A (B-2), 20 pedidos/10 min por endereço, contador fora do registro;
  por estúdio: §3.7. Passou: a mesma mensagem genérica.
- Sem cookie, logo sem CSRF; o token é a credencial (ASVS V3.5).
- Máscara do token (RNF-04 d): `src/server/formularios/mascarar.ts` troca qualquer texto de 43 caracteres base64url por
  `[token]` antes de qualquer registro ou monitoramento; teste com erro forçado.

### 4.3 Cifra e cofre (ADR 0014 D1 e D6)
- `src/server/cofre/cofre.ts`: porta `CofreDeChaves { embrulhar(chave: Uint8Array): Promise<{ envelope, ref }>;
  desembrulhar(envelope, ref): Promise<Uint8Array> }`. A chave mestra só existe dentro do cofre.
- `src/server/formularios/cifra.ts`: por ficha, chave nova AES-256-GCM (Web Crypto, existente no Workers, doc oficial
  `developers.cloudflare.com/workers/runtime-apis/web-crypto/`), IV de 12 bytes aleatório, **AAD = `formato|org_id|ficha_id|versao`**
  (a cifra não serve em outra linha: dado trocado ou alterado é recusado, CA-04); a chave da ficha é embrulhada pelo
  cofre e apagada da memória ao fim do pedido; nunca vai a registro.
- `src/domain/formularios/envelope.ts` (puro): montar e ler o formato (`1 byte formato | IV | texto+etiqueta`) e o AAD.
- `src/server/cofre/cofre-local.ts`: cofre falso **só para teste e banco local**, chave gerada na memória do processo,
  nunca no repositório; recusa iniciar se o ambiente não for de teste/local. Simula a troca de versão (CA-04).
- `src/server/cofre/cofre-kms.ts`: **fase D, só depois da resposta do dono (§0)**.
- Envelope (a chave da ficha passa pela memória do app durante o pedido): o KMS aceita até 64 KiB por pedido (§0) e a
  ficha pode passar de 200 KB; a chave mestra não sai. Fora da V6.4.2 ao pé da letra; registrado no ADR 0014 D1 para o
  Auditor de risco (CA-13).

### 4.4 Regras puras (`src/domain/formularios/`)
| Arquivo | Regra | Requisito |
|---|---|---|
| `modelo.ts` | validar título, perguntas (5 tipos, ids estáveis, limites), termo; decidir se a edição cria versão | RF-01 a RF-03 |
| `ficha.ts` | situações, o que cada situação permite (excluir, copiar link, substituir) | RF-05, RF-09, RF-10 |
| `validar-respostas.ts` | RF-07 contra a versão | RF-07, CA-02 |
| `envelope.ts` | formato e AAD | RNF-01 |
| `link.ts` | prazo de 7 dias, forma do token | RF-06 |
| `permissoes.ts` | matriz do §4.1 (constante E29·2·A, como ADR 0006 D6) | RF-11 |

### 4.5 Telas
- App: `src/app/routes/formularios/{index,fichas,modelos}.tsx` (Visão geral e Termos no lugar, "em desenvolvimento").
  Busca, filtros e cursor no corpo do pedido, nunca na URL. Respostas só em memória: nada em `localStorage`; resposta
  com `Cache-Control: no-store` (RNF-03).
- Página da cliente: rota pública `src/app/routes/f.tsx`, endereço **`/f#<token>`** (ADR 0014 D2): o fragmento não vai
  ao servidor nem ao `Referer`; o JS lê `location.hash` e manda o token no corpo. Cabeçalhos: `Referrer-Policy:
  no-referrer`, `Cache-Control: no-store`, `X-Robots-Tag: noindex`, CSP `script-src 'self'` (nenhum script de terceiros).
  Página sem nada do app (sem menu, sem sessão). Idioma = `estudios.idioma` devolvido por `abrir`.

## 5. Testes
### 5.1 Unidade (Vitest)
Um `.test.ts` por arquivo do §4.4; `cifra.test.ts` (ida e volta; AAD de outra ficha recusado; byte alterado recusado;
troca de versão no cofre local e a ficha antiga legível; a chave da ficha não aparece em nenhum registro);
`acoes.test.ts` (ordem das portas, 401/403, `org_id` no corpo, recepção não recebe respostas, teto de idas, registro
sem dado: varredura por textos fictícios marcados, CA-08, CA-09); `link.test.ts` (token inválido, limite, a mesma
mensagem nos 5 casos do CA-07, nada gravado em falha, CA-02); `mascarar.test.ts`; `formularios.test.tsx`
(`renderToString`, como no item 4). O teste da base `src/app/i18n/` já cobre o bloco novo.

### 5.2 Banco (pgTAP, `supabase/tests/database/`, faixa 4xx, dados fictícios escritos do zero)
| Arquivo | Prova |
|---|---|
| `400_formularios_estrutura_test.sql` | 6 tabelas com `org_id`, RLS ligada e forçada, índice por `org_id`; `anon` executa só as 2 funções de passagem e nada em `app`; funções `security definer` com `search_path` vazio; esquema `ficha_link` fora da API |
| `410_formularios_isolamento_test.sql` | molde do item 3 para modelos, versões, fichas e respostas: A não lê, cria, altera nem apaga de B; sem papel e sem login nada (CA-05) |
| `420_formularios_papeis_test.sql` | E29·2·A: recepção não lê respostas; profissional só das clientes visíveis; só dona mexe em modelo (CA-06, CA-06b) |
| `430_formularios_versoes_test.sql` | editar cria versão; versão antiga não muda nem se apaga; ficha presa à versão (CA-01) |
| `440_formularios_imutavel_test.sql` | ficha concluída e respostas: `update`/`delete` recusados até como dona da tabela; só `substituida_por` uma vez (CA-03) |
| `450_formularios_cifra_test.sql` | "resposta cifrada no banco": pelo catálogo, nenhuma coluna `text`/`json`/`jsonb` em `formularios_respostas` além de `chave_ref`; `cifra` recusa texto curto e formato ≠ 1; `termo_aceito = false` recusado (RNF-01) |
| `460_formularios_link_test.sql` | `anon` abre só a ficha do resumo; token de outra ficha (mesmo estúdio e outro) não lê nem grava; vencido, assinado, renovado, excluído e inexistente dão o mesmo resultado; `formularios_links` não tem coluna de token; limite por estúdio age; nenhuma das funções usa `service_role` (CA-05, CA-07) |
Prova de que o teste pega erro: tirar a condição `S` de uma política numa cópia descartável, ver `410` vermelho, desfazer.

### 5.3 Integração (Vitest contra o banco local com Auth, harness da E36·A)
`src/server/formularios/cifra.integracao.test.ts` (CA-04): assina pelo servidor uma ficha com a resposta conhecida
`ALERGIA-TESTE-7f3a` e o nome `NOME-TESTE-91c2`; depois lê **direto** no Postgres (sem o app), em `row_to_json` de
todas as tabelas `formularios_*`, e confere que nenhum dos dois textos aparece; com o cofre local trocado de versão, a
ficha antiga abre; com um byte da `cifra` alterado à mão, abrir dá erro; sem o cofre, não abre.

### 5.4 Ponta a ponta (Playwright, projetos `celular` 390 e `computador` 1440)
- `e2e/formularios-link.spec.ts` (preenchimento pelo link, CA-07, CA-10): abre `/f#<token>` de teste; a rede observada
  mostra que **nenhum pedido ao servidor tem o token no endereço** (só no corpo); cabeçalhos `no-referrer` e `no-store`;
  todos os scripts da mesma origem; preencher, erro de obrigatória com ícone e texto, caixinha desmarcada de início,
  assinar, "Ficha enviada"; abrir de novo dá "Este link não está mais disponível; fale com o estúdio"; nenhum dado da
  cliente na página; `localStorage` e `sessionStorage` vazios; axe sem falha (RNF-06).
- `e2e/formularios.spec.ts`: criar modelo, editar (vira versão 2), criar ficha, copiar link, ver ficha com e sem
  permissão, excluir pendente com janelinha (CA-10).
- `e2e/formularios-estados.spec.ts`: vazio, sem resultado, carregando (0,3 s), erro, sucesso (CA-11).
- Antes da E36·A juntada, só a parte de tela roda, com adaptador local fictício; o fluxo completo fica "não verificado".

## 6. Idiomas (RNF-07)
Só o bloco **`formularios`** em `src/app/i18n/pt.ts`, `es.ts`, `en.ts` (base comum da `feat/entrar-servico`, formato
ADR 0006 D1); `textos.ts`, `formatar.ts` e `i18n.test.ts` não mudam. Inclui os textos da página da cliente (que usa o
idioma do estúdio). pt sai do `DESIGN.md` e da spec; es e en pelo Designer de produto, revisados por outro papel.

## 7. Requisitos de nível 3 (RNF-05)
O Engenheiro de segurança lista no PR, antes da fase C, os requisitos ASVS nível 3 deste módulo, cada um com a prova
(tarefa 6). Já previstos aqui: V6.1.2/V6.2.7 (§4.3), V6.4.1/V6.4.2 nível 3 (§0), V8.2.1/V8.3.1 (§4.5), V8.3.5 (§4.1), V6.3.1 (§3.7).

## 8. Lista FECHADA de arquivos
Fora desta lista nada muda (`AGENTS.md` §6). Arquivo novo que uma ferramenta crie fora daqui: parar e relatar.

**Banco (Engenheiro de dados)**
- `supabase/migrations/<ts>_formularios_modelos.sql`, `_formularios_modelo_versoes.sql`, `_formularios_fichas.sql`,
  `_formularios_respostas.sql`, `_formularios_links.sql`, `_formularios_link_limite.sql`, `_formularios_funcoes.sql`,
  `_formularios_link_funcoes.sql`, `_formularios_politicas.sql` (9)
- `supabase/tests/database/400_formularios_estrutura_test.sql` a `460_formularios_link_test.sql` (7)
- `supabase/tests/database/010_base_estrutura_test.sql`: **só se B-5 não for resolvido antes**, e só acrescentando os
  nomes das funções de Formulários nas listas de `anon` e `authenticated`
- `docs/adr/0013-formularios-tabelas-do-antigo.md`

**Regras (Engenheiro de software)**: `src/domain/formularios/{modelo,ficha,validar-respostas,envelope,link,permissoes}.ts`
e um `.test.ts` para cada.

**Servidor e dados (Engenheiro de software; fase C)**: `src/server/formularios/{acoes,esquemas,link,cifra,mascarar}.ts`,
`acoes.test.ts`, `link.test.ts`, `cifra.test.ts`, `mascarar.test.ts`, `cifra.integracao.test.ts`;
`src/server/cofre/{cofre,cofre-local}.ts` e `cofre-local.test.ts`; `src/data/formularios/{repositorio,link,exemplo-local}.ts`
e `repositorio.test.ts`.

**Fase D (só após a resposta E40, §0), linhas condicionais:**
- Se **E40·A** (ou **C**): `src/server/cofre/cofre-kms.ts` e `cofre-kms.test.ts`; `package.json`/`pnpm-lock.yaml` só se
  o cofre pedir biblioteca (lida na doc oficial, linha no ADR do cofre).
- Se **E40·B**: `src/server/cofre/cofre-segredo.ts` e `cofre-segredo.test.ts` (chave lida do segredo do Worker); e
  `ARCHITECTURE.md` §7, **só** a linha da exceção declarada, escrita pelo Documentador com a fala literal do dono
  (o Arquiteto não a escreve; `AGENTS.md` §6).
- Em qualquer opção: `docs/adr/<próximo número livre>-formularios-cofre.md` (Arquiteto; substitui a linha D6 do ADR 0014).

**Telas (Engenheiro de software, pela ficha aprovada)**
- `src/app/routes/formularios/{index,fichas,modelos}.tsx`, `src/app/routes/f.tsx`, `src/app/routeTree.gen.ts` (gerado)
- `src/app/paginas/formularios/{fichas,painel-ficha,ver-ficha,modelos,editor-modelo,confirmar-excluir}.tsx`,
  `formularios.css`, `formularios.test.tsx`
- `src/app/paginas/ficha-link/{pagina,assinatura}.tsx`, `ficha-link.css`
- `src/app/i18n/pt.ts`, `es.ts`, `en.ts`: **só** o bloco `formularios`
- `e2e/formularios.spec.ts`, `e2e/formularios-link.spec.ts`, `e2e/formularios-estados.spec.ts`

**Ficha visual (Designer de produto, conferida pelo Revisor de design ANTES de qualquer tela)**:
`specs/20261128-021500-formularios/ficha-visual.md` e `ficha/*.png` (390 e 1440, dados fictícios), com as peças que faltam
no `DESIGN.md` (spec §4: "Copiar link", botão de envio da página, peça de assinatura, editor de perguntas, Ordenar
"Data"). **Texto (Designer, só com o dono):** `DESIGN.md`, só as linhas aprovadas na ficha.

**Decisão técnica (Arquiteto):** `docs/adr/0014-formularios-cifra-link-e-imutabilidade.md`; o ADR do cofre na fase D (acima).
**Processo:** `specs/20261128-021500-formularios/{spec,plan,tasks}.md` · `docs/STATUS.md`, `docs/BACKLOG.md`,
`CHANGELOG.md`, `docs/decisoes/` (respostas E29 e a do cofre), pelo Documentador.

**Intactos:** `src/*/AGENTS.md`, `src/*/CLAUDE.md`, `src/app/ui/**`, `src/app/estilos/**`, `src/server/portas/**`
(E36·A), a base de `src/app/i18n/`, as migrations de Clientes e dos itens 2 e 3, `supabase/config.jsonc`,
`eslint.config.mjs`, `ARCHITECTURE.md` (salvo a linha condicional de E40·B), `SECURITY.md`, `.github/**`.

## 9. Papéis
| Etapa | Papel |
|---|---|
| Migrations, funções, políticas, pgTAP, ADR 0013 | Engenheiro de dados |
| Regras, servidor, cifra (com o cofre local), dados, telas, idiomas, testes | Engenheiro de software |
| Ficha visual, desenho, textos es e en | Designer de produto |
| Ficha e telas contra `DESIGN.md` §10 | Revisor de design |
| Lista ASVS nível 3; revisão de cifra, link, registro, cofre | **Engenheiro de segurança** |
| Revisão de risco: ADR 0014 (CA-13), funções `security definer`, função de `anon`, B-5 | **Auditor de risco** |
| Banco e ADR 0013 item por item (E16·1) | Engenheiro de dados (outra instância) |
| Código | Revisor de código |
| Veredito CA-01 a CA-14 | QA |
| Pergunta do cofre ao dono (§0) | Gerente de projeto |

## 10. Fases
A banco (após item 3 e Clientes) · B regras e telas (após item 4 e ficha conferida) · C servidor com cofre local (após
E36·A, B-3, B-4) · **D cofre real (após a resposta do dono, §0)** · revisão e merge. Nada é juntado sem a fase D feita ou
sem a exceção declarada pelo dono (§0 opção B).

## 11. Branch (decisão do Engenheiro de DevOps)
`feat/formularios` recebe por **merge**, nesta ordem, `feat/banco-ligacao`, `feat/design-system-codigo`,
`feat/entrar-servico` e `feat/clientes` (que já leva as três); junta de novo sempre que ganharem commit; PR de rascunho
empilhado; nunca se junta nelas. Quando todas estiverem na `previas`, a base do PR passa à `previas`, antes do pedido de merge.

## 12. Lacunas para o Analista de requisitos (não decido; `AGENTS.md` §4)
- **L-1 · "Copiar link" depois de criada a ficha.** Com só o resumo no banco (RNF-04 a), o token não pode ser mostrado
  de novo. Proposta: o link aparece ao "Salvar" a ficha; depois, "Copiar link" no ⋮ **gera um link novo** e o anterior
  deixa de valer (é o "renovar" do RF-06), com aviso na tela. É tela e acesso: muda o texto do RF-06 e do §4.
- **L-2 · Como marcar "substituída" (E29·3·A).** A spec não diz onde a equipe faz a ficha nova que substitui a antiga.
  Proposta: ⋮ de ficha concluída, "Substituir" (nome novo, vai à ficha visual) cria a ficha nova já ligada. O banco já
  suporta (`substituida_por`).
- **L-3 · Página só com JavaScript.** O token no fragmento exige JS na página da cliente; sem JS, a página explica. Cabe
  na RNF-06?
- **L-4 · Dependências novas da E36·A:** B-3 (ação pública) e B-4 (registro sem login) entram como dependência na spec §9.

## 13. Se o dono responder diferente
| Resposta | Muda |
|---|---|
| E29·1·B (só no estúdio) | saem M5, M6, M8, `link.ts`, `f.tsx`, `ficha-link/*`, `460` e `formularios-link.spec.ts`; entra o modo no estúdio (spec própria, PIN) |
| E29·2·B | `ficha_respostas_visiveis` dá `true` à profissional; incoerente com E28·2·B (o trabalho para) |
| E29·2·C | dá `true` a todos; não recomendado (dado de saúde à recepção) |
| E29·3·B | `cifra` também leva a imagem do traço (limite de tamanho sobe; peça de desenho na ficha) |
| E29·3·C | entra `formularios_respostas_correcoes` (cifrada, só inclusão, com motivo) e a ação "Corrigir" |
| E40·B | a fase D usa `cofre-segredo.ts` (chave no segredo do Worker) em vez de `cofre-kms.ts`; ADR do cofre substitui D6; a exceção entra no `ARCHITECTURE.md` §7 com a fala do dono (linhas condicionais do §8) |
| E40·C | como E40·A, com o OpenBao (motor transit) no lugar do KMS; hospedagem na UE entra como ferramenta nova, confirmada com o dono |

## 14. Riscos e não verificado
- R-1 · Nada construído nem rodado; bases dos itens 3, 4, E36·A e Clientes ainda em construção.
- R-2 · Sem resposta E40 (B-1), a construção chega até o cofre local; **sem resposta do dono, não há merge**.
- R-3 · Como o TanStack Start declara ação sem login, põe cabeçalhos por rota e lê o corpo por POST: **não verificado**.
- R-4 · Se a passagem em `public` for chamada pela API REST com a chave pública, qualquer um na internet também a chama
  sem passar pelo servidor (a chave pública é pública). As duas funções aceitam isso por desenho (só agem com token
  válido e com limite por estúdio), mas o limite por endereço do servidor não vale para quem chama direto. O Auditor
  decide se basta ou se pede ligação direta ao Postgres com papel próprio (fica com a decisão de ligação da E36·A, R-7 de Clientes).
- R-5 · Credencial do Worker para o cofre: quem a roubar **e** tiver uma cópia do banco decifra. Mitigação: credencial só
  com permissão de cifrar/decifrar uma chave, registro de uso do lado do cofre. A confirmar com o cofre escolhido.
- R-6 · Região na UE e contrato (DPA) do cofre: não verificados.
- R-7 · Limites (60/min por estúdio, 20/10 min por endereço, 1,1 MB de cifra): números do papel, revistos pelo Engenheiro de segurança.
- R-8 · Carimbos de migration com módulos em paralelo: o Engenheiro de dados regenera se houver conflito.
