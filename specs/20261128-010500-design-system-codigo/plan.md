# Plano · Design system no código (item 4 da fila)

- **Spec:** `specs/20261128-010500-design-system-codigo/spec.md` (Draft; revisão 5b feita com ajustes, 28/11)
- **Escrito por:** Arquiteto de software · Norma: modelo C4 e ADR (mais WCAG 2.2, WAI-ARIA Authoring Practices e
  Twelve-Factor) · **Revisão:** etapa 5 (Spec Kit): não roda, porque o Spec Kit entra com o item 2, ainda não
  juntado · etapa 5b (Gerente de projeto): feita com ajustes, 28/11
- **Decisões técnicas:** `docs/adr/0004-design-system-no-codigo.md`
- **Base técnica:** item 2 (`chore/fundacao-tecnica`, `plan.md` e ADR 0002 de lá): mesma pilha e versões. Nenhuma
  versão do item 2 muda aqui.
- **Fontes lidas em 28/11/2026.** Nada aqui é adivinhado (`AGENTS.md` §6); o que não pôde ser lido está em §12.

## 1. Resumo (C4, nível de componente, dentro do contêiner "app" do item 2)
Tudo mora em `src/app` (`ARCHITECTURE.md` §3). Três partes, de baixo para cima:
1. **Tokens** (`src/app/estilos/tokens.css`): todas as cores, medidas, raios, sombras e foco do `DESIGN.md` como
   propriedades CSS (`--nome: valor`). É o **único** arquivo com número ou cor escrito.
2. **Componentes base** (`src/app/ui/`): React + CSS próprio, que só usa `var(--...)`. Não falam com `src/server` nem
   com o banco, não têm texto de módulo (recebem o texto pronto, RC-23 e RC-24).
3. **Vitrine** (`/vitrine`): página interna que mostra tokens e componentes com dados fictícios.

Sem chamada a sistema externo: fonte e ícones vêm empacotados no próprio app.

## 2. Bibliotecas novas (só 3) e fonte lida
Regra de versão igual à do item 2 (ADR 0002 · D4): última estável com pelo menos 3 dias em 28/11/2026, exata.

| Pacote | Versão | Tipo | Licença | Por quê | Fonte lida |
|---|---|---|---|---|---|
| `lucide-react` | 1.79.0 (24/11; a 1.80.0 tem menos de 3 dias) | dependência | ISC | o `DESIGN.md` §5 nomeia ícones Lucide; um componente por ícone, sem efeito colateral (`"sideEffects": false`) | `npm view lucide-react time`; pacote baixado: os 28 nomes do `DESIGN.md` §5 e §8b existem em `dist/esm/icons/` (ex.: `clock`, `calendar-plus`, `door-open`, `shield-alert`, `chart-column`), e também os candidatos de função da E25·2 (`x`, `chevron-*`, `plus`, `funnel`, `bell`, `search`, `ellipsis-vertical`, `circle-question-mark`, `panel-left`, `arrow-up-down`, `calendar-days`); pede React `^19` (ok com 19.3.1) |
| `@fontsource-variable/geist` | 5.3.0 (19/07/2026) | dependência | OFL-1.1 | Geist servida pelo app (Assumption 2 da spec); uma fonte variável cobre 400, 500 e 600; família `'Geist Variable'` | `npm view`; pacote baixado: `index.css` com `@font-face` `font-weight: 100 900`, `woff2`, `font-display: swap`, subconjuntos latin e latin-ext |
| `@axe-core/playwright` | 4.14.1 (24/11) | dev | MPL-2.0 (só ferramenta de teste) | CA-5: checagem automática WCAG A e AA na vitrine | `npm view` (pede `node >=22.12.0`, `playwright-core >=1.0.0`; usa `axe-core ~4.14.1`); `https://playwright.dev/docs/accessibility-testing` (`AxeBuilder`, `withTags`); o `axe.js` 4.14.1 tem as etiquetas `wcag2a`, `wcag2aa`, `wcag21a`, `wcag21aa`, `wcag22aa` |

**Não entram** (reuse antes de criar, `AGENTS.md` §3 regra 6; ADR 0004): Tailwind, CSS-in-JS, biblioteca de componentes
(Radix, React Aria), Storybook, jsdom e Testing Library, Stylelint, comparação de pixels.

## 3. Lista FECHADA de arquivos que podem mudar
Fora desta lista nada muda (`AGENTS.md` §6). Arquivo novo que uma ferramenta crie fora daqui: parar e relatar.

**Raiz (Engenheiro de software)**
- `package.json` (só as 3 dependências do §2), `pnpm-lock.yaml`
- `eslint.config.mjs` (só o bloco do §6.4) e `eslint.camadas.test.ts` (só os 2 casos do §6.4)

**Estilos e componentes (Engenheiro de software)**
- `src/app/estilos/app.css` · `tokens.css` · `base.css` (o `base.css` também leva o CSS do ícone, classes `ds-ic` e
  `ds-ic--14` a `ds-ic--24`, só com os tokens `--ic-*`; registrado depois da revisão de código, 28/11)
- `src/app/ui/icone.tsx` (o único que importa `lucide-react`)
- `src/app/ui/` em pares `.tsx` + `.css`: `botao` (RC-1, RC-2, RC-3) · `contador` (RC-4) · `seletor` (RC-6) ·
  `campos` (RC-7, RC-8, RC-9) · `etiqueta-status` (RC-10) · `bloco-lista` (RC-11, RC-12, RC-22) · `camadas` (RC-13 a
  RC-16) · `estados` (RC-17) · `estrutura` (RC-5, RC-18, RC-19) · `conteudo` (RC-20, RC-21)
- `src/app/ui/tokens.test.ts` (CA-1, CA-2) · `src/app/ui/contraste.test.ts` (RA-1) · `src/app/ui/componentes.test.tsx`

**Rotas e vitrine (Engenheiro de software)**
- `src/app/routes/__root.tsx` (só o `links` da folha de estilo e a referência `vite/client`, §6.1)
- `src/app/routes/vitrine.tsx` · `src/app/routeTree.gen.ts` (gerado, versionado)
- `src/app/paginas/vitrine.tsx` · `src/app/paginas/vitrine.css` · `src/app/paginas/vitrine-dados.ts`
- `e2e/vitrine.spec.ts` (CA-3, CA-4, CA-6, CA-7) · `e2e/vitrine-acessibilidade.spec.ts` (CA-5)

**CI (Engenheiro de DevOps)**: `.github/workflows/ci.yml`, só um passo no job `telas` (§8).

**Ficha visual (Designer de produto)**: `specs/20261128-010500-design-system-codigo/ficha-visual.md` e
`specs/20261128-010500-design-system-codigo/ficha/*.png` (capturas 390 e 1440 da vitrine, dados fictícios).

**Texto**: `DESIGN.md`, **só** as linhas que o dono aprovar em E25·2 e E25·3, escritas pelo
Designer de produto · `docs/STATUS.md`, `docs/BACKLOG.md`, `CHANGELOG.md`, `docs/decisoes/` (respostas E25), pelo
Documentador.

**Processo**: `specs/20261128-010500-design-system-codigo/{spec.md,plan.md,tasks.md}` ·
`docs/adr/0004-design-system-no-codigo.md`.

**Intactos:** `src/app/AGENTS.md`, `src/app/CLAUDE.md`, `src/app/paginas/inicio.tsx` e o teste dela, `src/domain`,
`src/server`, `src/data`, `supabase/`, `ARCHITECTURE.md`, `vite.config.ts`, `vitest.config.ts`, `playwright.config.ts`,
`tsconfig.json`.

## 4. Tokens (RT-1 a RT-9) · `src/app/estilos/tokens.css`
- Tudo em `:root`. Cores de RT-1 com o **nome exato** do `DESIGN.md` §3 (`--page`, `--warnSoft`, `--okInk`...).
- Nomes que o `DESIGN.md` não dá (Assumption 1 da spec), no mesmo estilo:

| Grupo | Tokens |
|---|---|
| RT-2 | `--pillSoft: rgba(22,24,29,.07)` · `--warnInk: #8A5205` · `--selRing: #D8D7D1` |
| RT-3 | `--font: 'Geist Variable', system-ui, sans-serif` · `--fs-20` `--fs-18` `--fs-16` `--fs-15` `--fs-14` `--fs-13` `--fs-12` `--fs-11` · `--fw-normal: 400` `--fw-medio: 500` `--fw-forte` · `--lh-titulo` `--lh-texto` (os dois últimos e `--fw-forte` dependem de E25·2) |
| RT-4 | `--sp-4` `--sp-8` `--sp-12` `--sp-16` `--sp-20` `--sp-24` `--sp-32` · `--margem` (16 celular, 24 computador) · `--entre-blocos: 12px` |
| RT-5 | `--r-pilula: 999px` · `--r-bloco: 20px` (bloco e menu aberto) · `--r-campo-multi: 16px` · `--r-menu-recolhido: 16px` · `--r-janelinha: 24px` · `--r-folha: 28px` · `--r-inicial: 10px` · `--r-caixinha: 7px` · `--r-contador: 10px` |
| RT-6 | `--sombra-flutua` · `--sombra-escolhido` (anel `--selRing` + sombra) · `--sombra-cabecalho` · `--borda: 1px` |
| RT-7 | `--h-controle` e `--toque` (44 celular, 40 computador) · `--h-campo: 44px` · `--h-linha-lista: 64px` · `--h-barra-baixo: 72px` · `--h-cabecalho: 64px` · `--h-linha-tabela: 40px` · `--h-cab-tabela: 36px` · `--h-barra-topo: 64px` · `--w-menu-aberto: 232px` · `--w-menu-recolhido: 84px` · `--w-submenu: 216px` · `--h-seletor: 44px` · `--h-seletor-item: 36px` · `--folga-seletor: 4px` · `--d-agendar: 52px` · `--h-status: 36px` · `--d-caixinha: 22px` · `--w-interruptor: 44px` · `--h-interruptor: 26px` · `--h-contador: 20px` · `--w-contador-min: 20px` · `--folga-contador: 7px` · `--folga-btn-ic-esq: 12px` · `--folga-btn-ic-dir: 10px` · `--espaco-ic: 6px` · `--w-titulo-barra: 280px` · `--w-busca-geral: 320px` · `--w-busca-tela: 280px` · `--w-menu-flutua: 240px` · `--w-janelinha: 340px` · `--w-painel: 480px` · `--d-bolinha: 40px` · `--d-bolinha-tabela: 24px` · `--d-bolinha-tempo: 36px` · `--d-ponto: 8px` · `--w-faixa: 4px` · `--w-linha-tempo: 2px` |
| RT-8 | `--foco-cor: var(--ink3)` · `--foco-largura: 2px` · `--foco-afastado: 2px` · `--opac-desativado: .6` · `--atraso-carregando: 300ms` |
| Ícone (só com E25·2) | `--ic-14` `--ic-16` `--ic-18` `--ic-20` `--ic-24` · `--ic-traco` |
| Troca de desenho (criados na construção, registrados depois da revisão de código, 28/11) | `--fs-texto` (15 celular, 14 computador) · `--mostra-celular` (`flex` / `none`) · `--mostra-computador` (`none` / `flex`) · `--w-busca-tela-atual` (100 % celular, `--w-busca-tela` computador) |
| Movimento (criado na construção, registrado depois da revisão de código, 28/11) | `--dur-interruptor: 150ms` (duração do movimento do interruptor: duração escrita fora do `tokens.css` seria valor solto, RT-9; só vale sem "movimento reduzido", RA-6) |

- **Motivo dos 4 tokens de troca:** o ponto de troca de 840 px (E25·3) só pode estar escrito no `tokens.css`
  (RT-9 / CA-2 proíbem `px` fora dele, e propriedade CSS não funciona dentro de `@media`). Por isso o `@media` do
  `tokens.css` troca o valor destes tokens, e os componentes só os leem, sem `@media` próprio.

- **Celular × computador:** um só ponto de troca, `@media (min-width: <E25·3>)`, só no `tokens.css` (troca `--margem`,
  `--h-controle`, `--toque`, `--fs-texto`, `--mostra-*` e `--w-busca-tela-atual`); os componentes que mudam de desenho
  (RC-18 × RC-19) só leem esses tokens. O
  número vem da resposta da E25·3. A vitrine e os testes usam 390 e 1440, longe de qualquer ponto de troca proposto.
- **RT-9 / CA-2:** nenhum `#`, `rgb(`, `rgba(`, `hsl(` nem número com `px`, `rem` ou `em` fora do `tokens.css`; nenhum
  `style={...}` nos `.tsx` de `src/app/ui` e `src/app/paginas/vitrine.tsx`. Provado por teste (§7).

## 5. Componentes base (RC-1 a RC-24)
- **Classes CSS com prefixo `ds-`** (ex.: `ds-botao`, `ds-botao--principal`), um `.css` por arquivo de componente,
  todos juntados no `app.css` por `@import` (Vite junta `@import` sozinho: `https://vite.dev/guide/features`, "@import
  Inlining and Rebasing"). Folha única ligada no `__root.tsx` pelo molde oficial do TanStack Start (`import appCss from
  '../estilos/app.css?url'` e `links: [{ rel: 'stylesheet', href: appCss }]`, com `/// <reference types="vite/client" />`;
  fonte: `docs/start/framework/react/guide/tailwind-integration.md` do repositório oficial).
- **Ícones:** só por `src/app/ui/icone.tsx`, que importa por nome **só** os ícones do `DESIGN.md` §5 e §8b (e os de
  função, se a E25·2 for aprovada), sempre com `aria-hidden="true"`; o nome acessível fica no botão. Lint barra
  `lucide-react` fora desse arquivo (§6.4).
- **Acessibilidade sem biblioteca** (ADR 0004 · D2), pelos padrões do WAI-ARIA Authoring Practices:
  - Seletor (RC-6): padrão "Tabs" (`role="tablist"`, `tab`, `aria-selected`, setas, Home e End, foco itinerante).
  - Menu aberto (RC-13): padrão "Menu Button" (`aria-haspopup`, `aria-expanded`, setas, Esc devolve o foco ao botão).
  - Janelinha, folha e painel (RC-14, RC-16): elemento nativo `<dialog>` aberto com `showModal()`: o resto da página
    fica inerte e Esc fecha (comportamento do navegador); o foco volta ao botão que abriu.
  - Aviso (RC-15) e carregando (RC-17): região `role="status"` (`aria-live="polite"`); carregando aparece só depois de
    `--atraso-carregando` e anuncia o texto recebido.
  - Toque (RA-2): o botão tem `min-width` e `min-height` `var(--toque)` mesmo quando o desenho é menor.
  - Foco (RA-3): `:focus-visible` com `outline: var(--foco-largura) solid var(--foco-cor)` e `outline-offset:
    var(--foco-afastado)`.
  - Movimento (RA-6): toda transição dentro de `@media (prefers-reduced-motion: no-preference)`.
- **Contador (RC-4):** recebe `total` e `pendente`; `total = 0` não desenha nada; com `pendente > 0` usa `--warnSoft` e
  `--warnInk` e o nome acessível diz "N, M pendentes" (texto recebido pronto, RC-23).
- **Status (RC-10):** mapa fixo status → ícone (`clock`, `thumbs-up`...) no `etiqueta-status.tsx`; no modo "só ícone" o
  nome vai para o leitor (`aria-label` ou texto escondido visualmente).
- **Excluir (RC-1, RC-14):** texto `--danger` sem fundo (vale o texto do `DESIGN.md` §8, não a imagem 06).
- **Estrutura (RC-18, RC-19):** só visual, com itens fictícios recebidos por propriedade; sem rota real (Assumption 4).

## 6. Rotas, vitrine e lint

### 6.1 `__root.tsx`
Só ganha a folha de estilo (§5). `lang="pt"` e o resto ficam.

### 6.2 `/vitrine` e onde fica (E25·1)
- Com **E25·1·A** (recomendado): `beforeLoad` lança `notFound()` quando `!import.meta.env.DEV &&
  import.meta.env.VITE_VITRINE !== 'ligada'`. Fontes: `https://vite.dev/guide/env-and-mode` (`import.meta.env.DEV`;
  só variáveis `VITE_` chegam ao navegador) e o `not-found.d.ts` do `@tanstack/router-core` instalado ("can be thrown or
  returned"). A prévia liga `VITE_VITRINE=ligada` no build dela (spec da prévia; `VITE_VITRINE` não é segredo). Em
  produção a rota responde "não encontrado".
- Com **E25·1·B**: sem o `beforeLoad`; a trava de login entra com a spec do login (até lá a vitrine não vai à produção).
- `<meta name="robots" content="noindex">` na vitrine, nos dois casos.

### 6.3 Vitrine (RV-1 a RV-3)
- `vitrine-dados.ts`: só dados fictícios (nomes inventados, sem dado de saúde; RV-2). Os textos dos botões seguem o
  `DESIGN.md` §6.
- Cada quadro é um `<section aria-labelledby>` com título, sobre bloco branco (controle nunca sobre `--page`) e no
  máximo uma ação preta (RV-3). Quadros: Tokens (cores com nome e valor, texto, espaços, raios, sombras) e um por
  RC-1 a RC-22, com as variações e estados de RV-1.
- Folha, painel, janelinha e menu têm botão "Abrir ..." no quadro, para teste e conferência.

### 6.4 Lint
Novo bloco no `eslint.config.mjs` para `src/app/**`, **menos** `src/app/ui/icone.tsx`: `no-restricted-imports` com
`patterns` `regex: '^lucide-react(/|$)'` e a mensagem "Ícone só por src/app/ui/icone.tsx (DESIGN.md §5)". A regra de
camadas do item 2 continua (os dois padrões entram no mesmo bloco, porque um bloco posterior substitui a opção do
anterior para os mesmos arquivos). `eslint.camadas.test.ts` ganha 2 casos: `src/app/x.tsx` importando `lucide-react`
dá erro; `src/app/ui/icone.tsx` importando `lucide-react` passa.

## 7. Testes de unidade (Vitest, ambiente `node` do item 2, sem jsdom)
| Arquivo | Prova |
|---|---|
| `tokens.test.ts` | **CA-1:** lê a tabela do `DESIGN.md` §3 (fonte única, sem lista copiada) e os tokens do `tokens.css`; cada nome e valor de RT-1 bate; RT-2 a RT-8 batem com a lista do §4 deste plano. **CA-2:** varre `src/app/ui/*.css`, `src/app/estilos/base.css`, `src/app/paginas/vitrine.css` e os `.tsx` do §3 pelas proibições do §4 (RT-9); 0 ocorrência |
| `contraste.test.ts` | **RA-1**, com a fórmula de luminância relativa da WCAG 2.2 (definição "relative luminance") escrita no próprio teste, lendo os valores do `tokens.css`: texto (`--ink`, `--ink2`, `--ink3`, `--okInk`, `--danger`, `--warn`) ≥ 4,5:1 sobre `--page`, `--card` e `--track`; `--warnInk` sobre `--warnSoft`; `--ink2` sobre `--pillSoft` composta sobre `--card` e `--track`; branco sobre `--ink` e `--brand`; contorno `--field` ≥ 3:1 sobre `--card`; ícones de estado e `--id` ≥ 3:1; `--c1` a `--c4` ≥ 3:1 sobre `--card` (WCAG 1.4.11). Desativado fica fora (WCAG 1.4.3 isenta componente inativo) |
| `componentes.test.tsx` | `renderToString`: contador com zero não desenha; pendência usa a classe âmbar e o nome acessível; menu na ordem Editar · Duplicar · Arquivar · Excluir; status só-ícone tem nome; seletor tem `tablist`/`tab`/`aria-selected`; botão de ícone sem nome não compila (tipo obrigatório); nenhum texto fixo de módulo (os textos vêm das propriedades) |

Conta feita nesta etapa, só para orientar (a prova é o teste): `--ink3` 5,07 · `--warn` 4,54 sobre `--page`;
`--field` 3,20 sobre `--card`, mas **2,83 sobre `--track` e 2,68 sobre `--page`**: campo só sobre superfície branca
(regra do `DESIGN.md` §2), e o teste confere só esse par; `--c3` 3,95.

## 8. Testes de tela (Playwright, projetos `celular` 390 e `computador` 1440 do item 2)
- `e2e/vitrine.spec.ts`:
  - **CA-3:** acha cada um dos 22 componentes pelo nome acessível do quadro (`getByRole('region', { name })`) e as
    variações de RV-1.
  - **CA-4:** `boundingBox()` das peças de RT-7 no projeto certo (botão 44/40, campo 44, seletor 36 em 44, Agendar 52,
    pílula 20 de altura e ≥ 20 de largura, caixinha 22, interruptor 44 × 26, janelinha 340, painel 480, menu 232/84,
    barra de baixo 72, cabeçalho 64) e a área de toque ≥ 44 (celular) / ≥ 40 (computador) de todo botão (RA-2).
  - **CA-6:** Tab percorre os controles com `outline` de 2 px visível (estilo calculado); Esc fecha folha, painel,
    janelinha e menu e devolve o foco; setas, Home e End trocam a aba do seletor.
  - **RA-6:** com `page.emulateMedia({ reducedMotion: 'reduce' })`, nenhuma transição com duração.
  - Sem rolagem lateral (mesma checagem do item 2).
  - **CA-7:** `page.screenshot({ fullPage: true, path: testInfo.outputPath('vitrine-<projeto>.png') })`.
- `e2e/vitrine-acessibilidade.spec.ts` · **CA-5:** `new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa',
  'wcag21a', 'wcag21aa', 'wcag22aa']).analyze()` com a vitrine fechada e com cada camada aberta; `violations` vazio.
- **CI:** no job `telas` do `ci.yml` do item 2, um passo `actions/upload-artifact` (o mesmo commit fixado no ADR 0002)
  **sempre** (`if: always()`), nome `capturas-vitrine`, caminho `test-results/**/vitrine-*.png`, `retention-days: 7`.
  O relatório de falha do item 2 fica como está. Repositório público: só dados fictícios nas capturas (RV-2).
- **Sem comparação automática de pixels** (ADR 0004 · D6). A comparação com as imagens aprovadas é a ficha (§9).

## 9. Ficha visual (etapa 6; CA-8)
`ficha-visual.md` pelo Designer de produto: para as imagens 01, 02, 03 e 06 de `docs/design/imagens/`, lado a lado
com o recorte da captura da vitrine em 390 e em 1440 (arquivos em `ficha/`), e uma linha por diferença: "igual",
"diferente, vale o texto" (ex.: Excluir da imagem 06) ou "defeito" (volta ao Engenheiro de software). O Revisor de
design confere pelo `DESIGN.md` §10 antes do dono. Como a ficha precisa da vitrine pronta, ela é feita depois da
construção em PR de rascunho (E22·B) e antes da aprovação do dono.

## 10. Lacunas para o Analista de requisitos · resolvidas na spec em 28/11 (L-1 → E25·2, L-2 → E25·3, L-3 → cabeçalho)
Achadas ao ler o canvas aprovado (`docs/design/canvas/v6.css`, `K3Controles.dc.html`). Como mudam o que aparece na
tela, vão ao dono pela spec. Proposta: juntar L-1 à E25·2 (mesma natureza: "medida que o `DESIGN.md` não fixa, tirada
do canvas aprovado") e L-2 como E25·3, para ficar em 3 dúvidas.
- **L-1 · Ícones** (resolvida: spec E25·2 e RT-3b). O `DESIGN.md` não fixa tamanho nem traço do ícone, nem o nome Lucide dos ícones de função (✕, ‹,
  ›, ▾, ⋮, +, funil, sininho, ajuda, painel, lupa, calendário, Ordenar). O canvas usa SVG do Lucide com 14, 16, 18, 20 e
  24 px e traço 1,75. Recomendação: A, usar os do canvas e gravar no `DESIGN.md` (como E25·2·A). Sem isso, o
  `icone.tsx` só pode ter os ícones já nomeados e os botões de função não podem ser construídos.
- **L-2 · Ponto de troca celular → computador** (resolvida: spec E25·3 e RT-3b). O `DESIGN.md` testa em 390 e 1440 mas não diz a partir de que
  largura o desenho vira o de computador (tablet). Recomendação: 840 px, a classe "expanded" do Material Design 3
  (window size classes), norma já seguida pelo `DESIGN.md`.
- **L-3 (só texto da spec; resolvida no cabeçalho da spec: branch empilhada sobre a `chore/fundacao-tecnica`):** o cabeçalho da spec diz "Branch: `feat/design-system-codigo` (da `previas`)", mas a
  construção sai da `chore/fundacao-tecnica` (E22·B, D-1). Ajustar a linha.

## 11. Como provar cada critério de aceite
| CA | Como | Quem |
|---|---|---|
| CA-1, CA-2 | `tokens.test.ts` verde | QA |
| CA-3, CA-4, CA-6 | `e2e/vitrine.spec.ts` verde nos 2 projetos | QA |
| CA-5 | `e2e/vitrine-acessibilidade.spec.ts` verde nos 2 projetos; mais `contraste.test.ts` (RA-1) | QA |
| CA-7 | artefato `capturas-vitrine` com os 2 PNG na execução da CI | QA, link |
| CA-8 | `ficha-visual.md` conferida | Designer de produto faz; Revisor de design confere |
| CA-9 | checklist `DESIGN.md` §10 item 8 sobre a vitrine e o `tokens.css` | Revisor de design |
| CA-10 | jobs da CI verdes (`verificar`, `telas`) | QA, link |
| RT-9 e camadas | lint verde e `eslint.camadas.test.ts` | Revisor de código |
| Escopo | `git diff --name-only chore/fundacao-tecnica...HEAD` comparado com o §3 | Revisor de código |

## 12. Não verificado (nesta etapa)
- Nada foi construído nem rodado; nenhum pacote foi instalado no projeto (os 3 foram só baixados em pasta de rascunho
  para ler o conteúdo).
- Se o `?url` do TanStack Start entrega o CSS com os `@import` já juntados e com as fontes do `@fontsource` reescritas
  (a doc oficial mostra o molde com Tailwind; o `@import` puro do Vite não foi testado nesse caminho). Se falhar: um
  `?url` por arquivo no `links` do `__root.tsx` (mesmo molde), registrado no ADR 0004.
- Se o `<dialog>` com `showModal()` passa no axe e no teste de Tab em Chromium 1.65.1 sem ajuste.
- O `ci.yml` do item 2 ainda não existe na `chore/fundacao-tecnica` (tarefa 9 de lá): o passo do §8 depende dele.
- Se a prévia (spec da Cloudflare, E23·2 pendente) consegue ligar `VITE_VITRINE` no build; até ela existir, a vitrine
  só roda na máquina e na CI.
- Páginas `tanstack.com` de "not found" não foram abertas (endereço do repositório deu 404); o uso de `notFound()` em
  `beforeLoad` vem do comentário do tipo instalado.
