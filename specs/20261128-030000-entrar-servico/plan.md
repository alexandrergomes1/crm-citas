# Plano · Entrar e camada de serviço (as 6 portas) · E36·A

- **Spec:** `specs/20261128-030000-entrar-servico/spec.md` (Draft; E39·1, E39·2 e E39·3 sem resposta)
- **Escrito por:** Arquiteto de software · **Norma:** modelo C4 e ADR (mais OWASP ASVS 4.0.3 nível 2, Clean Architecture,
  Twelve-Factor, boas práticas do Postgres e do Supabase) · **Revisão:** 5b (Gerente de projeto) feita com
  ajustes, 28/11; etapa 5 (Analista de requisitos) pendente
- **Decisões técnicas:** `docs/adr/0018-entrar-sessao-e-camada-de-servico.md` (D1 a D15). **Decisões de banco:**
  `docs/adr/0019-...md`, escrito pelo Engenheiro de dados na tarefa B1 (não neste plano), dentro dos limites do §6.
- **Bases lidas em 28/11/2026 (só leitura):** item 2 (esta branch: `package.json`, `vite.config.ts`, `eslint.config.mjs`,
  `ci.yml`, `supabase/config.jsonc`, `src/`); item 3 (`/home/user/wt-banco`: ADR 0005, `plan.md` R-1 a R-7, as 4
  migrations, os testes `010_` a `050_`, o molde); item 4 (`/home/user/wt-ds`: `plan.md`, `src/app/ui/*`); Agenda
  (`/home/user/wt-agenda`: ADR 0006, `plan.md` §5); Agendamento (`plan.md` §5.1 e ADR 0010 D1); Clientes (`plan.md`
  R-7, B-1). Fontes oficiais: §15.
- **Projeto antigo:** nada copiado.

## 1. Resumo (C4)
**Contexto:** a pessoa da equipe usa o navegador; o sistema fala com o Supabase (Auth e banco, na UE). Nenhum sistema
externo novo; nada pago (E23·3·A).

**Contêineres:** navegador (só HTML e JavaScript da tela; nenhum cliente nem chave do banco) → servidor TanStack Start
(hoje Node; depois Cloudflare Workers) → Supabase Auth (entrar, renovar, sair) e Data API (PostgREST) → Postgres.

**Componentes do servidor:**
```
src/app/start.ts ── middleware global: CSRF · Cache-Control no-store
src/app/routes/* ──► ações (createServerFn só dentro de acao.ts)
                        │
src/server/portas/acao.ts ──► executar.ts (sem framework):
   1 quem é: getClaims() ──► 1+2 contexto da sessão no banco (sessão viva? 12 h? 30 min? estúdio, papel, idioma)
   3 o que pode (papel) ──► 4 dados certos (zod estrito) ──► 5 trabalho com ctx.banco (1 gravação no máximo)
   6 registro: gatilho no banco (gravou) · função de recusa (recusou nas portas 2 a 5)
                        │
src/data/cliente.ts ── createServerClient (cookie HttpOnly) + cabeçalhos x-pedido, x-acao, x-estudio-esperado
                        │  Data API: 1 pedido = 1 transação
Postgres: pré-pedido public.antes_do_pedido() ─► consulta ─► gatilhos de registro ─► COMMIT ou desfaz tudo
```

## 2. Decisões (resumo; texto e motivo no ADR 0018)
Bibliotecas (D1) · Data API com token da pessoa, não ligação direta (D2) · uma transação = um pedido de gravação (D3) ·
porta 1 por `getClaims` + sessão no banco, sem `getUser` a cada pedido (D4) · tempo pelo banco (D5) · `estudio_trocado`
no pré-pedido (D6) · registro por gatilho e funções limitadas (D7) · limite de tentativas com HMAC e tempo mínimo (D8) ·
cookie `__Host-`, HttpOnly, Secure, Lax, variáveis sem `VITE_` (D9) · CSRF e no-store (D10) · erros como valor (D11) ·
molde único e catálogo (D12) · zod estrito depois das portas 1 a 3 (D13) · banco local com Auth (D14) · idiomas (D15) ·
só o servidor fala com a Data API, por chave guardada como hash (D16) · chave de assinatura assimétrica (D17).

## 3. Fluxos

### 3.1 Entrar (ação `sessao.entrar`, modo `nenhuma`)
1. Mede o início. Se o pedido já traz cookie de sessão: encerra essa sessão primeiro (3.4), para nascer uma nova (RF-05).
2. Porta 4: `{ email, senha }` estrito; e-mail até 254, senha de 1 a 1024 caracteres, **sem cortar nem alterar** (RF-32).
3. Limite (D8): `public.conferir_tentativa(chave_ip, chave_conta)` (executável por `anon`). Passou → `limite`.
4. `signInWithPassword` pelo cliente do servidor. Falhou → `public.registrar_tentativa_falha(pedido)` (`anon`; só
   evento, resultado, quando, pedido).
5. Deu certo → com o token novo, `public.iniciar_sessao(pedido)`: recusa `session_id` já visto e entrada por senha com
   mais de 60 s (`amr` do token); cria a linha da sessão (D4) só se a pessoa tem ao menos um estúdio ativo, grava `sessao.entrar` com `usuario_id` e `org_id` vazio, devolve o número de estúdios ativos.
   Zero → `signOut({ scope: 'local' })`, apaga cookie e trata como falha (mesma mensagem, RF-11).
6. Um estúdio → escolhe sozinho (3.3). Mais de um → já escolhido e ativo segue nele; senão vai a Escolher estúdio.
7. Completa até **700 ms** desde o passo 1, em todo resultado (RF-02). Resposta: só `ok`, `limite` ou
   `sem_login` (uma frase para e-mail errado, senha errada, sem conta e sem estúdio; na linha de falha, o resultado é
   esse mesmo código).

### 3.2 Cada pedido de uma ação (modo `estudio`)
Todo pedido do servidor à Data API leva `x-chave-servidor` (ADR 0018 · D16); sem ela, o pré-pedido recusa tudo, de
`anon` ou de `authenticated`. Ordem fixa (RF-17), a primeira recusa para tudo:
1. **Porta 1:** `getClaims()`; sem token válido → `sem_login` (nada no banco, RF-28).
2. Envelope `{ estudioDaTela, dados }`: `estudioDaTela` é `uuid` obrigatório neste modo; forma errada → `entrada_invalida`.
3. **Portas 1 e 2 no banco:** `public.contexto_da_sessao()` (POST, com `x-estudio-esperado`). O pré-pedido recusa sessão
   morta, vencida (12 h) ou parada (30 min) → `sem_login` (o servidor então encerra a sessão, 3.4) e estúdio diferente →
   `estudio_trocado`. Sem estúdio escolhido → `sem_estudio`. Devolve `usuarioId`, `orgId`, `papel`, `idioma`, `fuso`,
   `moeda` e atualiza o "último uso".
4. **Porta 3:** `permissao(papel)` → `sem_permissao`.
5. **Porta 4:** `entrada.safeParse(dados)` com `z.strictObject` → `entrada_invalida`, sem trabalho e sem banco de dados
   do módulo (ver L-2).
6. **Porta 5:** `trabalho(ctx, dados)`; `ctx.banco` manda os cabeçalhos `x-chave-servidor`, `x-pedido`, `x-acao` (o
   nome da ação) e `x-estudio-esperado` em todo pedido; em pedido que grava, o pré-pedido recusa `x-pedido` fora do formato
   `uuid` e `x-acao` fora de `app.acoes_que_gravam`; `grava: false` com gravação, ou segunda gravação → `erro_interno`.
7. **Porta 6:** gravou → as linhas saem do gatilho, na mesma transação. Recusa nas etapas 2 a 6 →
   `public.registrar_recusa(acao, codigo, pedido)` (melhor esforço; se falhar, a resposta não muda).
8. Resposta `{ ok: true, valor }` ou `{ ok: false, codigo }`; sempre `Cache-Control: no-store`.

Modo `pessoa` (lista de estúdios, escolher, trocar, sair): passos 1, 3 (sem cabeçalho de estúdio; `orgId` pode ser vazio),
4 com "qualquer papel", 5 a 8. Modo `opcional` (`sessao.ler`): sem sessão devolve só o idioma do `Accept-Language`.

### 3.3 Escolher e trocar de estúdio
- `public.meus_estudios()` → `org_id` e `nome` só dos estúdios com papel **ativo** da pessoa, por nome, até 50 (RF-13;
  meio decidido pelo Engenheiro de dados no ADR 0019, lacuna §7 da spec).
- `public.escolher_estudio(p_org_id, p_pedido)`, **`security invoker`** (RF-12): chama `app.escolher_estudio` e grava
  `estudio.escolher` (primeira vez na sessão) ou `estudio.trocar` com o `org_id` novo, na mesma transação. Sem vínculo
  ativo → `sem_permissao`, nada muda (CA-05).

### 3.4 Sair e tempo
- **Sair:** `public.encerrar_sessao(p_pedido)` (marca a linha como encerrada, **sem apagar**; grava `sessao.sair` com o
  `org_id` da sessão ou vazio) → `signOut({ scope: 'local' })`, que roda **mesmo se** a marcação for recusada ou falhar →
  apaga os cookies → vai a Entrar. O token antigo, mesmo com assinatura válida,
  é recusado pelo pré-pedido no pedido seguinte (CA-13).
- **Tempo (E39·3·B, se aprovada):** 12 h desde `entrou_em` e 30 min desde `ultimo_uso` (atualizado no passo 3 de 3.2,
  no máximo uma vez por minuto). Vencida → a linha é marcada encerrada e nunca volta (o mesmo `session_id` é recusado
  por `iniciar_sessao`) → `sem_login` → o servidor chama `signOut({ scope: 'local' })` → Entrar; nada gravado se perde (RF-07). Com E39·3·A: só 12 h.
  Com E39·3·C: 30 dias, sem corte por parada.

## 4. Contrato da camada de serviço (fixo; os módulos dependem dele)
`src/server/portas/acao.ts` (único arquivo que importa `createServerFn`):

```ts
type Papel = 'dona' | 'recepcao' | 'profissional'
type CodigoDeErro = 'sem_login' | 'estudio_trocado' | 'sem_estudio' | 'sem_permissao'
  | 'entrada_invalida' | 'conflito' | 'limite' | 'erro_interno'
type Resultado<S> = { ok: true; valor: S } | { ok: false; codigo: CodigoDeErro }

type ContextoEstudio = {
  pedidoId: string; usuarioId: string; orgId: string; papel: Papel
  idioma: 'pt' | 'es' | 'en'; fuso: string; moeda: string
  banco: Banco            // de src/data: token da pessoa + cabeçalhos do pedido; ≤ 1 gravação
}

acao<E extends z.ZodType, S>(def: {
  nome: `${string}.${string}`          // ex.: 'agenda.bloqueio.criar'; único no catálogo
  metodo: 'GET' | 'POST'               // POST quando grava
  sessao: 'estudio'                    // 'pessoa' | 'opcional' | 'nenhuma' só na lista fechada de src/server/sessao
  permissao: readonly Papel[] | ((papel: Papel) => boolean)   // regra pura de src/domain/<modulo>/acesso.ts
  entrada: E                           // z.strictObject(...); sem campo de estúdio
  grava: boolean
  trabalho: (ctx: ContextoEstudio, dados: z.output<E>) => Promise<S>
}): ServerFn<{ estudioDaTela: string; dados: z.input<E> }, Resultado<S>>
```
- Conflito do banco (ex.: exclusão `23P01`, chave `23505`) vira `conflito` no mapa de `src/data/erros.ts`; o resto,
  `erro_interno`. Nenhum texto do banco sai.
- A tela manda `estudioDaTela` (o `orgId` que ela recebeu); recebeu `estudio_trocado` → recarrega (RF-15).
- `src/domain` não recebe `ctx.banco`: recebe valores por parâmetro (`src/domain/AGENTS.md`).
- Gravação em mais de uma tabela: uma função `public.<modulo>_<acao>(...)`, `security invoker`, chamada por `ctx.banco`
  (ADR 0018 · D3). Leitura: quantos pedidos o teto do módulo permitir, cada um conferido pelo pré-pedido.

## 5. `src/server` e `src/data` (Engenheiro de software)

| Arquivo | O que tem |
|---|---|
| `src/server/portas/executar.ts` | as portas na ordem do §3.2, sem framework (recebe cookies, cabeçalhos e corpo; devolve resultado, cookies a gravar e cabeçalhos) |
| `src/server/portas/acao.ts` | adaptador TanStack Start: `createServerFn({ method })`, `.validator` só de passagem (`unknown`), lê pedido e cookies (`getRequest`, `getCookie`), grava cookies e cabeçalhos (`setCookie`, `setResponseHeader`); registra a ação no catálogo |
| `src/server/portas/tipos.ts`, `erros.ts`, `catalogo.ts` | tipos do §4; códigos; catálogo único das ações e lista fechada dos modos sem estúdio |
| `src/server/http/middleware.ts` | middleware global: `Cache-Control: no-store` em toda resposta de página e de ação |
| `src/server/sessao/acoes.ts` | `sessao.entrar`, `sessao.ler`, `sessao.sair`, `estudio.listar`, `estudio.escolher` (fluxos do §3) |
| `src/server/sessao/tentativas.ts` | chaves HMAC-SHA-256 (WebCrypto) de IP e e-mail normalizado; IP de `cf-connecting-ip`, ou do pedido no Node local |
| `src/server/portas/executar.test.ts`, `erros.test.ts`, `molde.test.ts`, `src/server/sessao/acoes.test.ts` | unidade, com Auth e banco falsos (§9) |
| `src/data/ambiente.ts` | lê e valida por pedido `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `SEGREDO_TENTATIVAS`, `CHAVE_SERVIDOR_BANCO`; faltou → `erro_interno` (falha fechada) |
| `src/data/cliente.ts` | `createServerClient` com `cookies.getAll/setAll` (aplica também os cabeçalhos de cache que o `setAll` entrega) e `cookieOptions` `{ name: '__Host-sessao', httpOnly: true, secure: true, sameSite: 'lax', path: '/' }`; tipo `Banco` (sem expor o tipo do Supabase a `src/server`); `global.headers` com `x-chave-servidor` e os cabeçalhos do pedido; `global.fetch` que conta gravações |
| `src/data/sessao.ts` | chamadas às funções do §6 (contexto, iniciar, encerrar, tentativas, meus estúdios, escolher, recusa) |
| `src/data/erros.ts` | erro do PostgREST ou do Auth → código de RF-22; nada do texto original segue |
| `src/data/cliente.test.ts`, `src/data/erros.test.ts` | opções do cookie; contagem de gravações; mapa de erros |
| `src/domain/idioma.ts` (+ `.test.ts`) | `Accept-Language` → `pt`, `es` ou `en`; fora deles, `pt` |

Nunca: `getSession()` no servidor; chave secreta ou de serviço em `src/`; `@supabase/*` fora de `src/data`.

## 6. Banco (Engenheiro de dados decide o desenho no ADR 0019, dentro destes limites)
Migrations por `pnpm exec supabase migration new <nome>`, depois das do item 3 (carimbo maior). Sugestão de 5:

| # | Nome | Precisa ter |
|---|---|---|
| M1 | `registro` | `app.registro` (fora da API): `quando` (UTC), `evento` (só `[a-z_.]`, até 64), `resultado` (lista fechada: `ok` e os códigos de RF-22), `usuario_id`, `org_id`, `objetos uuid[]` (até 10), `pedido_id`; RLS ligada e forçada, sem política, `revoke all`; gatilho que recusa `update`, `delete` e `truncate`; `check`: linha `sessao.entrar` que não é `ok` sem `usuario_id`, `org_id` e objetos. Nada de texto livre |
| M2 | `registro_funcoes` | `app.registrar_mudanca()` (gatilho genérico `after insert or update or delete for each row`: evento de `x-acao`, objetos das colunas `uuid` nomeadas nos argumentos do gatilho, `org_id` da linha igual ao da sessão); `app.registrar_recusa` e a passagem `public.registrar_recusa` (só para a própria pessoa, código da lista, teto por pessoa); `public.registrar_tentativa_falha(p_pedido)` para `anon`, teto global por minuto; acima dele grava uma só linha de resumo por minuto com resultado `limite` (o teto não esconde falhas) e não dá erro; o gatilho recusa gravação sem `x-acao` válido |
| M3 | `sessoes` | `app.sessoes` (`session_id` chave, `user_id`, `entrou_em`, `ultimo_uso`, `encerrada_em`), fora da API, RLS forçada; **nenhuma linha é apagada** (encerrar, vencer e parar só marcam `encerrada_em`; gatilho recusa `delete`); `public.iniciar_sessao` (recusa `session_id` já existente e `amr` de senha com mais de 60 s), `public.encerrar_sessao`, `public.contexto_da_sessao` (passagens `security invoker` para funções `app.*` `security definer` com `search_path = ''`); limites 12 h, 30 min e 60 s numa só função |
| M4 | `tentativas_entrada` | `app.tentativas_entrada` (chave `bytea` do HMAC, janela, contagem), fora do registro e fora da API; `public.conferir_tentativa(p_chave_ip, p_chave_conta)` para `anon`: apaga vencidas, conta e soma; 10 por conta e 30 por IP em 15 min; teto global de linhas (acima dele, `limite`) |
| M5 | `estudios_da_pessoa_e_pre_pedido` | `public.meus_estudios()` e `public.escolher_estudio(p_org_id, p_pedido)` (`security invoker`, RF-12); `public.antes_do_pedido()` registrada com `alter role authenticator set pgrst.db_pre_request` e `notify pgrst, 'reload config'` (guia oficial): para **todo** pedido, recusa sem `x-chave-servidor` cujo SHA-256 esteja em `app.chaves_servidor` (D16); para `authenticated`, recusa sessão sem linha viva (menos em `rpc/iniciar_sessao`, que faz a própria conferência de D4), `x-estudio-esperado` diferente e, em pedido que grava, `x-pedido` e `x-acao` fora da regra (D6), com `raise sqlstate 'PGRST'` e os códigos `sem_login`, `estudio_trocado` e `erro_interno`. Mais `app.chaves_servidor` (só hash) e `app.acoes_que_gravam` (lista fechada; cada módulo acrescenta as suas na própria migration) |

- Privilégios: `anon` executa **só** `conferir_tentativa` e `registrar_tentativa_falha`; `authenticated`, só as funções
  `public` acima e as 4 do item 3. O teste `010_` do item 3 ganha essa lista (ADR 0019 substitui a linha D9 do ADR 0005).
- `supabase/config.jsonc`: `auth.enable_signup: false` (RF-09, CA-16) e `auth.signing_keys_path` para chave assimétrica
  gerada a cada execução, num arquivo fora do repositório (`.gitignore`; ADR 0018 · D17). `auth.sessions` **não** se liga
  (é do Pro; o local ficaria diferente do remoto). Realtime e Storage continuam desligados no local; nenhuma tabela entra
  na publicação `supabase_realtime` e nenhum balde de Storage é criado (o teste `010_` confere a publicação).
- Testes pgTAP novos: `060_registro_test.sql` (CA-10, CA-11 com tabela temporária e gatilho, RF-26), `070_sessoes_test.sql`
  (iniciar, encerrar, 12 h, 30 min, CA-15; **não ressuscita**: `session_id` encerrado, vencido ou parado recusado por
  `iniciar_sessao`, `amr` antigo recusado, `delete` recusado), `080_passagem_test.sql` (CA-17: `security invoker`, sem execução para
  `public` e `anon`), `090_tentativas_test.sql` (limites, vencimento, forma da linha de falha, teto global, CA-14 no banco),
  `100_pre_pedido_test.sql` (`estudio_trocado`; sessão morta; sem chave do servidor, com chave errada e com chave certa, para
  `anon` e `authenticated`; gravação sem `x-pedido`, com `x-acao` ausente ou fora da lista; `rpc/iniciar_sessao` sem linha
  viva só passa pela conferência de D4; com `request.headers` e `request.jwt.claims` postos no teste). Molde novo `supabase/moldes/registro_tabela_test.sql` para cada módulo provar o gatilho.

## 7. `src/app` (Engenheiro de software; desenho do Designer de produto na ficha)

| Arquivo | O que tem |
|---|---|
| `src/app/start.ts` | `createStart` com `requestMiddleware: [createCsrfMiddleware({ filter: serverFn }), semCache]` |
| `src/app/routes/__root.tsx` | `lang` do idioma de `sessao.ler`; o resto do item 2 e do item 4 fica |
| `src/app/routes/entrar.tsx`, `escolher-estudio.tsx` | telas; nada na URL além do caminho (RF-33) |
| `src/app/routes/_app.tsx`, `_app/index.tsx` | área com sessão: `beforeLoad` chama `sessao.ler`; sem sessão → `/entrar`; sem estúdio → `/escolher-estudio`. O `index.tsx` do item 2 passa para `_app/index.tsx`. A trava real é a porta 1 em cada ação (guia SSR do Supabase: `beforeLoad` só protege o desenho) |
| `src/app/paginas/entrar.tsx` (+ `.css`, `.test.tsx`) | E-mail e Senha (campos do item 4, Senha com mostrar e esconder, sem `maxlength` abaixo de 1024, colar permitido), uma ação preta, estados carregando, erro e sucesso |
| `src/app/paginas/escolher-estudio.tsx` (+ `.css`, `.test.tsx`) | lista de nomes, carregando, erro com "Tentar de novo" |
| `src/app/paginas/sua-conta.tsx` (+ `.test.tsx`) | menu (1440) e folha (390) do item 4: Trocar de estúdio (só com mais de um), Sair, e os outros itens "em desenvolvimento" |
| `src/app/i18n/pt.ts`, `es.ts`, `en.ts`, `textos.ts`, `formatar.ts`, `i18n.test.ts` | ADR 0006 · D1: chaves do `pt.ts` como tipo das outras; blocos `comum`, `erros` (uma frase por código), `entrar`, `escolherEstudio`, `suaConta`; os módulos só acrescentam blocos |
| `src/app/ui/campos.tsx`, `src/app/ui/icone.tsx` (item 4) | **só se a ficha for aprovada:** campo Senha com mostrar e esconder e os ícones dele |
| `src/app/routeTree.gen.ts` | gerado |

Nomes e peças fora do `DESIGN.md` (botão "Entrar", rótulos "E-mail" e "Senha", título "Escolher estúdio", mostrar e
esconder senha, frases de erro, inicial da bolinha Sua conta) entram no `DESIGN.md` pela ficha (RF-31).

## 8. Banco local e CI (scripts `db:*`: Engenheiro de dados · dependências e outros scripts: Engenheiro de software · CI: Engenheiro de DevOps)
- `package.json`: `db:start` tira `gotrue`, `kong` e `postgrest` do `-x` (o resto continua desligado); scripts novos
  `test:integracao` (Vitest com `vitest.integracao.config.ts`) e `pacote:conferir` (CA-03). Dependências do D1.
- `scripts/banco-local.mjs`: roda `supabase status -o json`, põe no ambiente do comando filho `SUPABASE_URL`,
  `SUPABASE_PUBLISHABLE_KEY`, um `SEGREDO_TENTATIVAS` e uma `CHAVE_SERVIDOR_BANCO` aleatórios da execução (grava o hash da chave no banco local como
  `postgres`), gera a chave de assinatura local (D17) e, **só para `tests/` e `e2e/`**, a chave
  local de administração; nada é impresso nem gravado em arquivo.
- `playwright.config.ts`: `webServer` por `scripts/banco-local.mjs`; `globalSetup` cria as contas fictícias.
- `ci.yml`: job `banco` → `db:start` → `db:test` → `test:integracao` → `db:stop`; job `telas` → telemetria desligada →
  `db:start` → `test:e2e` → `db:stop`; job `verificar` → depois do `build`, `pacote:conferir`. Permissões, ações fixadas e
  nomes de job continuam os do ADR 0002 e 0003. Nenhum segredo, nenhum banco remoto.
- `tsconfig.json` inclui `tests`. `eslint.config.mjs`: `src/server` e `src/app` não importam `@supabase/*`; `src/data` não
  importa `src/app` nem `src/server`; `createServerFn` só em `src/server/portas/acao.ts`; `createBrowserClient` nunca.

## 9. Testes e prova de cada critério

| CA | Prova | Onde |
|---|---|---|
| CA-01 | sucesso cria sessão; senha errada, sem conta e sem estúdio dão a mesma resposta; medianas de tempo a menos de 100 ms entre si (10 tentativas cada) | `tests/integracao/entrar.test.ts` |
| CA-02 | `context.cookies()`: `httpOnly`, `secure`, `sameSite: 'Lax'`; `document.cookie` sem o cookie; `localStorage` e `sessionStorage` vazios | `e2e/entrar.spec.ts` |
| CA-03 | pacote do navegador sem `supabase`, sem o endereço e sem a chave; nenhum pedido da página ao Supabase (`page.on('request')`) | `scripts/conferir-pacote.mjs`; e2e |
| CA-04 | percorre o catálogo: cada ação sem cookie e com sessão vencida → `sem_login`; contagem do registro e das tabelas igual antes e depois | `tests/integracao/portas.test.ts` |
| CA-05, CA-06 | pessoa de A e B com A escolhido manda B → `estudio_trocado`, nada lido nem gravado; só de A escolhe B → `sem_permissao`; troca em "outro aparelho" (segundo cookie) → a tela antiga recebe `estudio_trocado` | integração e `100_` |
| CA-07, CA-08 | ordem das portas e corte na primeira recusa, com espiões; entrada fora do esquema não chama o trabalho nem o banco do módulo | `executar.test.ts` |
| CA-09, CA-09a | linhas com os campos de RF-24 e RF-24a; busca dos e-mails e textos do teste no registro acha zero; contador fora do registro e vencido apagado | `tests/integracao/registro.test.ts`; `090_` |
| CA-10, CA-11 | ninguém altera ou apaga; `anon` sem privilégio; registro que falha desfaz a gravação | `060_` |
| CA-12 | respostas só com códigos; erro do banco simulado não vaza texto | `erros.test.ts`; integração |
| CA-13 | token guardado antes de Sair → recusado depois, e o cookie antigo não cria sessão nova (renovar + `iniciar_sessao` → recusado); chamada direta à Data API com token e chave pública, sem `x-chave-servidor` → recusada; `no-store` em toda resposta; voltar no navegador não mostra dado | integração; e2e |
| CA-14 | 11ª tentativa da mesma conta → `limite` com a frase genérica | integração |
| CA-15 | `ultimo_uso` e `entrou_em` empurrados para trás no banco local → `sem_login` | `070_`; integração |
| CA-16 | conta nova pelo Auth recusada; `enable_signup` falso no `config.jsonc` | integração; leitura |
| CA-17 | `security invoker`; sem execução para `anon` e `public`; nenhuma chave secreta em `src/` | `080_`; `molde.test.ts` |
| CA-18, CA-18a | só estúdios ativos; senha de 64 e de 200 caracteres chega igual ao servidor | integração; e2e; `entrar.test.tsx` |
| CA-19 | entrar, erro, carregando, escolher, trocar, sair em 390 e 1440, com `AxeBuilder` (`wcag2a`, `wcag2aa`, `wcag21aa`, `wcag22aa`) | `e2e/entrar.spec.ts`, `e2e/escolher-estudio.spec.ts` |
| CA-20 | mesmas chaves, nada vazio, mesmos marcadores; idioma do estúdio depois de escolher | `i18n.test.ts`; e2e |
| CA-21 | `createServerFn` fora de `acao.ts` dá erro de lint; ação fora do catálogo ou modo sem estúdio fora da lista falha | `eslint.camadas.test.ts`; `molde.test.ts` |
| CA-22 | relatórios sem "Bloqueia", veredito do QA, conferência do dono na prévia | PR |

Dados de teste sempre fictícios, escritos do zero. O teste deve ficar vermelho quando se tira a trava (prova de que pega
erro: tirar o pré-pedido ou o gatilho numa cópia local e ver `100_`/`060_` falharem; desfazer).

## 10. Arquivos (lista FECHADA)
Nenhum outro muda. `docs/decisoes/`, `docs/BACKLOG.md` e `docs/STATUS.md` só pelo Documentador.

| Arquivo | Papel |
|---|---|
| `package.json`: scripts `db:*` · dependências e os outros scripts (`test:integracao`, `pacote:conferir`) | Engenheiro de dados · Engenheiro de software |
| `pnpm-lock.yaml`, `tsconfig.json`, `eslint.config.mjs`, `eslint.camadas.test.ts`, `vitest.integracao.config.ts` | Engenheiro de software |
| `src/server/portas/{acao,executar,tipos,erros,catalogo}.ts`, `src/server/portas/{executar,erros,molde}.test.ts` | Engenheiro de software |
| `src/server/http/middleware.ts`, `src/server/sessao/{acoes,tentativas}.ts`, `src/server/sessao/acoes.test.ts` | Engenheiro de software |
| `src/data/{ambiente,cliente,sessao,erros}.ts`, `src/data/{cliente,erros}.test.ts` | Engenheiro de software (consultas conferidas pelo Engenheiro de dados) |
| `src/domain/idioma.ts`, `src/domain/idioma.test.ts` | Engenheiro de software |
| `src/app/start.ts`, `src/app/routes/{__root,entrar,escolher-estudio,_app}.tsx`, `src/app/routes/_app/index.tsx`, `src/app/routes/index.tsx` (sai), `src/app/routeTree.gen.ts` | Engenheiro de software |
| `src/app/paginas/{entrar,escolher-estudio,sua-conta}.tsx`, os `.css` e `.test.tsx` deles | Engenheiro de software |
| `src/app/i18n/{pt,es,en,textos,formatar}.ts`, `src/app/i18n/i18n.test.ts` | Engenheiro de software |
| `src/app/ui/campos.tsx`, `src/app/ui/campos.css`, `src/app/ui/icone.tsx` (como na ficha; o "sim" do dono vem com a aprovação da spec) | Engenheiro de software |
| `supabase/migrations/<ts>_{registro,registro_funcoes,sessoes,tentativas_entrada,estudios_da_pessoa_e_pre_pedido}.sql` (nomes finais no ADR 0019) | Engenheiro de dados |
| `supabase/tests/database/010_base_estrutura_test.sql` (só a lista de privilégios), `060_` a `100_` (5 novos), `supabase/moldes/registro_tabela_test.sql` | Engenheiro de dados |
| `supabase/config.jsonc` (só `auth.enable_signup` e `auth.signing_keys_path`), `.gitignore` (arquivo da chave local) | Engenheiro de dados |
| `tests/integracao/{preparo,entrar,portas,registro,sessao}.test.ts` (o `preparo` sem `.test`) | Engenheiro de software |
| `e2e/preparo-global.ts`, `e2e/entrar.spec.ts`, `e2e/escolher-estudio.spec.ts`, `e2e/inicio.spec.ts` (passa a entrar antes), `playwright.config.ts` | Engenheiro de software |
| `scripts/banco-local.mjs`, `scripts/conferir-pacote.mjs`, `.github/workflows/ci.yml` | Engenheiro de DevOps |
| `docs/adr/0018-...md` (este plano) · `docs/adr/0019-...md` | Arquiteto · Engenheiro de dados |
| `specs/20261128-030000-entrar-servico/ficha-visual.md` e `ficha/` · `DESIGN.md` (nomes e peças, só depois do "sim" do dono à ficha) | Designer de produto |
| `specs/20261128-030000-entrar-servico/spec.md` (aprovação e ajustes das lacunas do §13) | Analista de requisitos |
| `CHANGELOG.md`, `CONTRIBUTING.md` ("Como rodar" com o banco local), `docs/STATUS.md`, `docs/BACKLOG.md` | Documentador |

## 11. Papéis

| Etapa | Papel |
|---|---|
| Branch empilhada e CI | Engenheiro de DevOps |
| Migrations, pgTAP, molde, ADR 0019, `config.jsonc` | Engenheiro de dados |
| `src/server`, `src/data`, `src/domain`, `src/app`, testes de unidade, integração e e2e | Engenheiro de software |
| Ficha visual (Entrar, Escolher estúdio, Sua conta, em 390 e 1440) e proposta para o `DESIGN.md` | Designer de produto |
| Revisar código e o molde (D11 a D15) | Revisor de código |
| Revisar banco e conferir o ADR 0019 item por item | Engenheiro de dados (outra instância) e Auditor de risco |
| Revisar acesso, sessão, cookie, registro, limite (D2 a D10) | Engenheiro de segurança e Auditor de risco |
| Revisar tela e ficha (`DESIGN.md` §10) | Revisor de design |
| Veredito CA-01 a CA-22 | Analista de qualidade (QA) |
| Conferir o pedido; ajustar a spec pelas lacunas | Analista de requisitos |
| Registros | Documentador |

## 12. Branch empilhada (decisão do Engenheiro de DevOps, como no item 3)
`feat/entrar-servico` recebe por **merge** a `feat/banco-ligacao` (item 3) e a `feat/design-system-codigo` (item 4); PR
de rascunho (E22·B); nunca se junta nelas. Conflitos esperados: `package.json`, `pnpm-lock.yaml`, `eslint.config.mjs`,
`__root.tsx`, `routeTree.gen.ts`, `e2e/inicio.spec.ts`. Quando os itens 3 e 4 entrarem na `previas`, a base do PR passa
à `previas`, antes do pedido de merge. Se o item 3 ou 4 mudar nomes (funções, componentes), este plano volta à 5b.

## 13. Lacunas para o Analista de requisitos e efeito nos outros planos
- **L-1 · RF-06:** a spec oferece "conferir no Auth a cada pedido" ou "token curto". O plano confere a sessão **no banco** a
  cada pedido (ADR 0018 · D4), porque o `getUser` cai no limite de 30/5 min por IP do servidor e token curto gasta o balde
  de renovação (150/5 min, o mesmo para todos). Pede ajustar o texto do RF-06 e do CA-13.
- **L-2 · CA-08:** "nenhuma ida ao banco" não cabe com a porta 2 antes da 4 (o estúdio e o papel vêm do banco). O plano
  garante: entrada inválida não chama o trabalho e não lê nem grava dado; só houve a leitura do contexto da sessão.
- **L-3 · E39:** o plano usa E39·3·B; A ou C mudam só os valores (§3.4). E39·1 e E39·2 não mudam o plano.
- **L-4 · tela:** inicial da bolinha Sua conta sem nome guardado (proposta: primeira letra do e-mail da própria pessoa) e
  "Sair" (nome barrado no `DESIGN.md` §6 como sinônimo de Fechar, mas listado no §8b): o Designer leva à ficha.
- **Registro (5b, 28/11):** Agenda e Agendamento ajustam os planos ao §4 (já pedido) e voltam à 5b quando esta spec ficar Approved.
- **Efeito nos planos:** Agenda §5.3 (campo a mais passa a dar `entrada_invalida`; `estudioDaTela` no envelope) e
  Agendamento §5.1 e ADR 0010 D1 (gravação de várias tabelas vira função `security invoker`) voltam à 5b; Clientes R-7 e B-1
  ficam respondidos (Data API, ADR 0018 · D2).

## 14. Riscos e não verificado
- **R-1** · Registrar o pré-pedido por migration (`alter role authenticator`) no banco local e no remoto: guia oficial
  manda rodar como SQL; permissão do papel `postgres` para isso numa migration **não verificada** (tarefa B2 prova no local).
- **R-2** · Forma exata de `request.path` para liberar `rpc/iniciar_sessao` no pré-pedido: **não verificada** (teste `100_`).
- **R-2a** · Que o `amr` de senha guarda a hora da entrada também depois de renovar o token: **não verificado** no Auth
  local (integração prova; se não guardar, `iniciar_sessao` usa só "`session_id` nunca visto", que com D16 já fecha o
  caminho, e o Auditor de risco reconfere).
- **R-3** · Projeto remoto: entrar e renovar de todos os estúdios saem do mesmo servidor e dividem o balde do Auth
  (150/5 min por IP). Subir esse limite é configuração de produção: vai ao dono, com passo a passo, no pedido de merge.
- **R-4** · `supabase start` sem `mailpit`: o Auth sobe sem ele? **Não verificado**; se não subir, `mailpit` sai do `-x`.
- **R-5** · Nomes das variáveis de `supabase status -o json` na CLI 3.4.0: **não verificados** (tarefa D1 lê).
- **R-6** · Cookie `__Host-` e `Secure` em `http://localhost` no Chromium do Playwright: **não verificado** (CA-02 prova;
  se falhar, o prefixo vale só fora do local, com ADR novo).
- **R-7** · `no-store` e o cache de voltar do Chromium (bfcache): **não verificado** (CA-13 prova; se mostrar dado, a tela
  recarrega ao voltar).
- **R-8** · `@supabase/ssr` sempre grava o cookie com 400 dias (código instalado ignora `maxAge` próprio): a validade real
  é a do banco (12 h e 30 min). Aceito.
- **R-9** · Cloudflare Workers: `supabase-js`, WebCrypto e `cf-connecting-ip` **não verificados** lá (não há publicação
  nesta spec; o Node local é o que roda).
- **R-10** · Pasta do pacote do navegador para o CA-03 (`dist/client` ou outra): **não verificada** (lida no `build`).
- **R-11** · (fechado por D16) chamar a Data API direto com o próprio token: recusado sem a chave do servidor. Resta:
  quem roubar a chave do servidor e um token passa pelo pré-pedido; a chave só vive no cofre e troca-se com 2 hashes ativos.
- **R-13** · O Auth (`/auth/v1`) não passa pelo pré-pedido: com a chave pública (que nunca sai do servidor, mas o Supabase a
  trata como pública), alguém pode tentar senha direto no Auth, sem o nosso limite por conta; vale só o limite por IP do
  Auth. Fechar pede recurso do Auth que não foi verificado no plano gratuito: vai ao dono no pedido de merge, com o risco.
- **R-14** · Remoto com chave de assinatura simétrica: `getClaims` chamaria o Auth a cada pedido (guias SSR e de chaves) e
  cairia no limite de 30/5 min por IP. Trocar para chave assimétrica é configuração de produção: vai ao dono (D17).
- **R-15** · `supabase gen signing-key` e `auth.signing_keys_path` na CLI 3.4.0: **não verificados** (tarefa B2).
- **R-16** · Se `signOut({ scope: 'local' })` também falhar ao sair, o token de acesso vale até vencer (até 1 h); o cookie
  já foi apagado e, com D16, só o servidor o usaria. Aceito, com a linha marcada assim que o banco voltar.
- **Fora de escopo, registrado:** prazo de guarda do registro e de `app.sessoes` é dado de cliente e decisão do dono
  (spec da vida do estúdio, `SECURITY.md` §7); até lá nada se apaga.
- **R-12** · Medida de tempo do CA-01 pode oscilar na CI; tolerância de 100 ms e 10 amostras.

## 15. Fontes lidas (28/11/2026)
- Supabase: `guides/auth/sessions` (Pro para tempo e parada; `session_id`; sessão apagada ao sair),
  `guides/auth/server-side/creating-a-client` (TanStack Start; `getClaims`; `setAll` com cabeçalhos de cache; nunca
  `getSession`), `guides/auth/rate-limits` (baldes por IP; `/auth/v1/user`; `Sb-Forwarded-For` só com chave secreta),
  `guides/api/securing-your-api` (pré-pedido, `request.headers`, `raise sqlstate 'PGRST'`, GET só leitura),
  `guides/auth/signing-keys` (verificação local e cache de 10 a 20 min), `guides/local-development/cli/config`
  (`auth.enable_signup`, `auth.sessions.*`, `auth.rate_limit.*`).
- PostgREST (`docs/references/transactions.rst` e `errors.rst`, repositório oficial): um pedido = uma transação;
  pré-pedido dentro dela; modo só leitura em GET.
- TanStack Start (repositório oficial, `docs/start/framework/react/guide/`): `server-functions.md` (mesma origem, CSRF),
  `middleware.md` (global, ordem, `start.ts`), `environment-variables.md` (ler por pedido no Workers).
- Código instalado (`/home/user/wt-banco/node_modules`): `start-client-core` 1.170.39 (`createCsrfMiddleware`,
  `createStart`), `start-server-core` 1.169.45 (`getRequestIP`, cookies, `setResponseHeader`), `start-plugin-core`
  1.172.0 (`start.ts` em `srcDirectory`). Pacotes baixados por `npm pack`: `@supabase/ssr` 0.12.7 (`httpOnly: false`
  padrão, `maxAge` de 400 dias), `@supabase/auth-js` 2.119.2 (`getUser` → `session_not_found` depois de sair; `signOut`
  padrão `global`; `getClaims` com `session_id`), `@supabase/supabase-js` 2.119.2 (`global.fetch`, `global.headers`).
- Supabase CLI 3.4.0: `supabase start --help` (lista do `-x`), `supabase status --help` (`-o json`).
- `npm view` (28/11): `@supabase/supabase-js` 2.119.2 (19/11), `@supabase/ssr` 0.12.7 (08/09), `zod` 4.6.7 (12/10), MIT.
