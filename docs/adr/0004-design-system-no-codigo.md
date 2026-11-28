# ADR 0004 · Design system no código: CSS próprio, acessibilidade sem biblioteca, ícones, fonte e testes

- **Status:** Proposto · decisões técnicas (`AGENTS.md` §5) · 28/11/2026. Vale quando a spec
  `specs/20261128-010500-design-system-codigo/spec.md` for aprovada pelo dono.
- **Autor:** Arquiteto de software · **Revisão:** pendente (Revisor de código)
- **Aviso ao dono:** em uma linha, junto do pedido de aprovação da spec (`AGENTS.md` §3 item 3).
- **Detalhe e fontes:** `specs/20261128-010500-design-system-codigo/plan.md` §2 a §8. Base: ADR 0002 (versões do item 2).

## Contexto
A spec do item 4 pede os tokens do `DESIGN.md`, 22 componentes base, uma vitrine, WCAG 2.2 AA, testes em 390 e 1440 e
capturas. O `AGENTS.md` §3 regra 6 manda reusar antes de criar; o `DESIGN.md` é exato (cores, medidas, sombras) e
proíbe peça fora dele, então uma biblioteca de estilo ou de componentes traria valores e desenhos próprios a desligar.

## Decisões

| # | Decisão | Motivo e norma |
|---|---|---|
| D1 | Tokens como propriedades CSS num só arquivo (`src/app/estilos/tokens.css`); componentes com CSS próprio global, classes com prefixo `ds-`, um `.css` por arquivo, juntados por `@import` numa folha ligada pelo molde `?url` do TanStack Start. Sem Tailwind, sem CSS-in-JS, sem CSS Modules | os tokens do `DESIGN.md` viram `--nome: valor` sem tradução; zero dependência; `@import` é nativo do Vite (doc "Features"); o `?url` em `links` é o molde oficial do TanStack Start. CSS Modules funcionariam no Vite, mas o caminho com renderização no servidor do Start não foi lido na doc (proibido adivinhar, `AGENTS.md` §6) |
| D2 | Acessibilidade sem biblioteca de componentes: `<dialog>` nativo com `showModal()` (janelinha, folha, painel) e os padrões "Tabs" e "Menu Button" do WAI-ARIA Authoring Practices escritos à mão | o navegador já prende a página de trás e fecha com Esc no `<dialog>` modal; só dois padrões de teclado a escrever; WCAG 2.2 (2.1.1, 2.4.7, 4.1.2). Risco: erro de teclado feito à mão; tratado por axe e teste de teclado em 390 e 1440 (CA-5, CA-6) |
| D3 | Ícones por `lucide-react` 1.79.0 (ISC), importados **só** em `src/app/ui/icone.tsx`; lint barra o pacote no resto de `src/app` | o `DESIGN.md` §5 nomeia ícones Lucide; um arquivo só garante "um ícone por coisa" (`DESIGN.md` §5) e que nenhum ícone fora da lista entre; regra nativa do ESLint, como no ADR 0002 · D3 |
| D4 | Fonte por `@fontsource-variable/geist` 5.3.0 (OFL-1.1), servida pelo próprio app, com `system-ui` de reserva | Assumption 2 da spec (sem serviço externo a cada visita; RGPD: nenhum endereço da pessoa enviado a terceiro); uma fonte variável cobre 400, 500 e 600 |
| D5 | Acessibilidade automática por `@axe-core/playwright` 4.14.1 (só desenvolvimento) com as etiquetas `wcag2a`, `wcag2aa`, `wcag21a`, `wcag21aa`, `wcag22aa`; contraste de **todos** os pares de tokens por teste de unidade próprio, com a fórmula da WCAG 2.2 | o axe é o indicado na doc de acessibilidade do Playwright, mas só confere o que está desenhado; o teste dos tokens cobre todo par previsto, inclusive os que nenhuma tela usa ainda (WCAG 1.4.3 e 1.4.11) |
| D6 | Sem comparação automática de pixels (`toHaveScreenshot`) neste item; capturas inteiras em 390 e 1440 como artefato da CI (7 dias) e comparação humana na ficha visual | as imagens aprovadas são quadros do canvas, não a vitrine: a diferença seria sempre total; a doc do Playwright avisa que a imagem muda com sistema, fonte e máquina. Linha de base de pixels entra quando houver tela de módulo estável |
| D7 | O teste de tokens lê a tabela do `DESIGN.md` §3 como fonte (não copia a lista) | fonte única (`DESIGN.md`, cabeçalho): mudou o `DESIGN.md` com o dono, o teste acusa o código desatualizado |
| D8 | Vitrine em `/vitrine`, travada por `import.meta.env.DEV` ou `VITE_VITRINE=ligada` (se o dono escolher E25·1·A) | Vite: só variáveis `VITE_` chegam ao navegador, e esta não é segredo; produção responde "não encontrado" (ASVS V14.3: não expor página interna) |

## Consequências
- Mudar uma cor ou medida é mudar uma linha do `tokens.css`, depois do `DESIGN.md`; o teste D7 garante a ordem.
- Os temas Barbearia e Essencial, quando aprovados, entram como outro conjunto de valores dos mesmos tokens.
- Ícone novo pede o `DESIGN.md` com o dono e uma linha no `icone.tsx`.
- Se o molde `?url` não juntar os `@import` (não verificado), troca-se por um `?url` por arquivo, registrado aqui.
- Para desfazer qualquer decisão: ADR novo que substitui esta linha, com o motivo.
