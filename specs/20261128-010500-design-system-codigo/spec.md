# Spec · Design system no código

- **Pasta:** `specs/20261128-010500-design-system-codigo/` · **Branch:** `feat/design-system-codigo`, empilhada sobre
  `chore/fundacao-tecnica` (item 2), por merge; PR redirecionado à `previas` quando o item 2 entrar (decisão técnica
  do Engenheiro de DevOps)
- **Item da fila:** 4 de `docs/BACKLOG.md` ("Design system no código", fonte `DESIGN.md`)
- **Tipo:** Tela (`docs/guias/processo-sdd.md` §3 e §4: ficha visual, aprovação da spec, pedido de merge com prévia)
- **Status:** Approved
- **Aprovação do dono:** "Aprovo as specs: Entrar e camada de serviço, Trava por estúdio no banco, Design system no código, Agenda, Agendamento, Clientes, Formulários, Catálogo, Checkout, Caixa." · 28/11/2026 · https://claude.ai/code/session_018cV8b8F1poNHjA4eEd3VyN
  (`docs/decisoes/2026-11-27-fundacao.md`, linha "Aprovação das specs") · gravado pelo Analista de requisitos (E16·3)
- **Aprovação do merge:** "E49a juntar" (E49·A, pedido de merge do PR #7: "Junto vêm os PRs #5 (banco) e #6 (design system). Eles já estão dentro desta branch. Juntar o #7 junta os três.") · 28/11/2026 · https://claude.ai/code/session_018cV8b958nnbLyXPMKPeaNK · pedido no commit `f47837e`, merge na `previas` em `2dad348` (squash do PR #7), CI verde nos 5 jobs · gravado pelo Engenheiro de DevOps.
- **Escrito por:** Analista de requisitos · **Norma:** IEEE 29148, BABOK · **Revisa:** Gerente de projeto (etapa 5b)
- **Fontes lidas:** `AGENTS.md`, `ARCHITECTURE.md` §3, §11, §12, `DESIGN.md` (inteiro), `docs/design/README.md`,
  `docs/design/imagens/` (01 a 06 e provas 1 a 4), `src/app/AGENTS.md`, `docs/guias/processo-sdd.md`,
  `docs/decisoes/2026-11-27-fundacao.md` (E10, E10·1, E12·3, E13, E15·1, Comentário). Projeto antigo: não lido.

## 1. Objetivo
Levar o `DESIGN.md` aprovado (E10) para o código em `src/app`: os tokens, os componentes base que ele define e uma
página interna de vitrine onde o dono e o Revisor de design conferem cada peça, nas larguras 390 e 1440 (E15·1).
Nenhuma tela de módulo é construída aqui.

## 2. Dependências
- **D-1.** Item 2 da fila (fundação técnica: app vazio em TanStack Start, pnpm, Vitest, Playwright, CI). Decisão do
  dono E22·B (28/11/2026, "E22b"; registrada em `docs/decisoes/` na branch `docs/produto-modulos`, PR #2): a
  construção sai em PR de rascunho a partir da branch do item 2 (`chore/fundacao-tecnica`), antes da aprovação
  dela, e nada é juntado sem o dono.
- **D-2.** Spec Kit instalado (item 2), para a checagem automática da etapa 5.

## 3. Escopo
**Dentro:** tokens (§4), componentes base (§5), vitrine (§6), acessibilidade (§7), testes e capturas (§8).
**Fora:** telas dos módulos e o mapa da navegação com rotas reais (§7 do `DESIGN.md`, cada módulo por spec);
temas Barbearia e Essencial (cores "a definir com o dono", `DESIGN.md` §3); mapa de ícones além dos ícones citados
no `DESIGN.md` (quadro `L7Icones` ainda não aprovado, `docs/design/README.md`); textos em espanhol e inglês;
qualquer chamada a `src/server` ou ao banco.

## 4. Requisitos de tokens
Fonte única: `DESIGN.md`. Valor diferente do `DESIGN.md` é defeito.

- **RT-1 Cores** (`DESIGN.md` §3), com o nome e o valor exatos:
  `--page #ECEBE6` · `--card #FFFFFF` · `--btn` e `--track #F2F1ED` · `--line #EAE9E4` · `--ink #16181D` ·
  `--ink2 #4A4F57` · `--ink3 #5E636B` · `--field #8C9098` · `--id #3E5C76` · `--brand #7A5A22` ·
  `--warn #9A5B06` · `--warnSoft #FBEFD9` · `--ok #1F6B45` · `--okInk #17583A` · `--okSoft #E3F0E8` ·
  `--danger #B3261E` · `--dangerSoft #FBEAE8` · `--c1 #7D5A8C` · `--c2 #B0583A` · `--c3 #A07A2C` · `--c4 #5C7F6A`.
- **RT-2 Valores de cor citados fora da tabela** (`DESIGN.md` §5 e §8b), também como token: número da pílula de
  pendência `#8A5205`; fundo da pílula cinza `rgba(22,24,29,.07)`; anel do escolhido do seletor `#D8D7D1`.
- **RT-3 Tipografia** (`DESIGN.md` §4): fonte Geist; escala 20 forte · 18 forte · 16 forte · 15 · 14 · 13 · 12 · 11
  (mínimo, só barra de baixo, menu recolhido, hora da grade); pesos citados 500 e 600 (§8b). Peso de "forte" e
  altura de linha: ver E25·2.
- **RT-3b Ícones e troca de desenho:** tamanho, traço e nome Lucide dos ícones de função: ver E25·2. Largura a partir
  da qual vale o desenho de computador: ver E25·3.
- **RT-4 Espaços** (§4): 4 · 8 · 12 · 16 · 20 · 24 · 32; margem da tela 16 (celular) e 24 (computador); entre blocos 12.
- **RT-5 Raios** (§4, §8b): pílula (botão, campo de uma linha, busca, chip, seletor, item de menu aberto, aviso);
  bloco e menu aberto 20; campo de várias linhas 16; item do menu recolhido 16; janelinha 24; folha 28 no topo;
  quadrado da inicial 10; caixinha 7; pílula de contador 10.
- **RT-6 Sombras** (§8b): o que flutua `0 16px 40px rgba(22,24,29,.18)`; escolhido do seletor anel 1 px `#D8D7D1` +
  `0 1px 3px rgba(22,24,29,.14)`; borda do cabeçalho do celular `0 1px 0 var(--line)` +
  `0 6px 14px -10px rgba(22,24,29,.25)`; barra do topo do computador separada por linha de 1 px. Sombra só nesses
  casos (§4).
- **RT-7 Alturas e larguras** (§4, §8b): celular 44 (botão, campo, botão de ícone), linha de lista 64, barra de baixo
  72, cabeçalho 64; computador 40 (botão, busca, botão de ícone, item de menu), linha de tabela 40, cabeçalho de
  tabela 36, barra do topo 64, menu aberto 232 e recolhido 84, submenu 216; campo de formulário 44 nos dois;
  seletor item 36 (total 44) com 4 de folga; Agendar 52; botão de status 36 (toque 44); caixinha 22; interruptor
  44 × 26; pílula de contador 20 de altura e mínimo 20 de largura, 7 de folga lateral; larguras do computador:
  título da barra 280, busca geral 320, busca da tela 280, menu aberto (Opções e ⋮) 240, janelinha 340, painel 480.
- **RT-8 Foco e estados** (§8, §8b): anel de foco 2 px `--ink3`, afastado 2 px; desativado com opacidade 60 %.
- **RT-9** Nenhuma cor, medida, raio ou sombra é escrita solta nos componentes: todos usam os tokens de RT-1 a RT-8.

## 5. Requisitos de componentes base
Só as peças que o `DESIGN.md` define (§2, §5, §8, §8b). Cada uma com o desenho de celular e de computador quando o
`DESIGN.md` os distingue, com os nomes de §6 e o "Nunca" de §5 respeitado.

| # | Componente | Fonte no `DESIGN.md` |
|---|---|---|
| RC-1 | Botão: ação principal (preto `--ink`), claro (`--btn`), com contorno ("+ Adicionar" do celular, 1 px `--ink3`, fundo transparente), Excluir (texto vermelho, sem fundo), desativado (60 %), nota "em desenvolvimento" | §5, §8 |
| RC-2 | Botão de ícone sem fundo (fechar, voltar, ⋮, ajuda, notificações, funil, ícone de painel) | §5 |
| RC-3 | Botão com ícone e nome (Filtros, Ordenar, Categoria, Modelo, modo de ver, Equipe, Lista de espera) e só nome (Opções, Hoje) | §5 |
| RC-4 | Pílula de contador: cinza (total) e âmbar suave (há pendência); zero não aparece; em botão de ícone (ícone + pílula, folga 12/10, espaço 6) | §5, §8b, E13·1, E13·3 |
| RC-5 | Agendar da barra (círculo 52 preto, `calendar-plus` branco, nome 11 forte) | §5, §8b |
| RC-6 | Seletor com papel de abas: trilho claro, escolhido branco com sombra; rola com esmaecido na ponta quando não cabe; aba vazia fica no lugar | §5, §8b, §9 |
| RC-7 | Campos: uma linha, várias linhas, seleção ▾, data com calendário; rótulo acima, obrigatório com * cinza, erro com contorno vermelho e mensagem com ícone; contorno `--field` | §8, §8b |
| RC-8 | Busca da tela (pílula; no celular com o funil ao lado) e busca geral "Buscar no sistema ⌘K" | §5 |
| RC-9 | Caixinha e interruptor, pretos quando ligados | §8, §8b |
| RC-10 | Etiqueta (ícone + palavra, sem fundo) e Status (botão "ícone + nome ▾" 36; ícone + palavra nas listas; só ícone com nome no leitor) com os ícones Lucide listados em §5 | §5 |
| RC-11 | Bloco (superfície `--card`, canto 20); controle nunca direto sobre `--page` | §2 |
| RC-12 | Linha de lista 64 (com faixa de categoria 4 px), linha e cabeçalho de tabela, cabeçalho de grupo (14 forte + pílula), ⋮ no fim da linha | §3, §4, §5, §8b |
| RC-13 | Menu aberto (Opções e ⋮; Editar · Duplicar · Arquivar · Excluir, nesta ordem) | §5, §6, §8 |
| RC-14 | Janelinha de confirmação (340; Excluir com texto vermelho, sem fundo: vale o texto do `DESIGN.md` §8, não a imagem 06, que mostra fundo vermelho claro) | §8, §8b |
| RC-15 | Aviso embaixo depois de uma ação, com "Desfazer" quando der | §8 |
| RC-16 | Folha de baixo (celular, canto 28 no topo, linhas que abrem com ▾/▴) e painel à direita (computador, 480); botão de confirmar da camada é preto | §8, §8b |
| RC-17 | Estados de tela: vazio ("Ainda não há <itens>" + frase + "Adicionar <item>" com contorno), sem resultado ("Limpar filtros"), carregando (linhas cinza só depois de 0,3 s, anunciado ao leitor), erro ("Tentar de novo"), sucesso (aviso) | §8, §8b |
| RC-18 | Estrutura do computador: barra do topo (ordem de §8b), menu principal aberto/recolhido (atual em fundo claro com ícone `--id`), submenu | §5, §8b |
| RC-19 | Estrutura do celular: cabeçalho 64 com sombra de borda, barra de baixo 72 (Agenda, Clientes, Agendar, Catálogo, Mais; atual em `--id` com ponto), lista de seções (ícone, nome, pílula, ›) | §5, §8b |
| RC-20 | Bolinha da cliente (40 celular, 24 tabela) e Sua conta (bolinha 40), fundo `--btn`, nunca colorida; quadrado da inicial do estúdio (`--brand`) | §3, §8b |
| RC-21 | Linha do tempo (bolinha 36, linha 2 px `--line`, ponto não lido `--id` 8) | §8b |
| RC-22 | Resumo de valores "Total ▴ valor" (▴ abre o detalhe) | §5 |

- **RC-23** Componente recebe texto pronto de quem o usa (não fixa texto de módulo), para os idiomas futuros (`ARCHITECTURE.md` §11).
- **RC-24** Componentes ficam em `src/app`, sem regra de negócio e sem falar com o servidor ou o banco (`ARCHITECTURE.md` §3).

## 6. Requisitos da vitrine
- **RV-1** Uma página interna mostra todos os tokens (amostra de cada cor com nome e valor; escala de texto;
  espaços; raios; sombras) e todos os componentes de §5, com cada variação e estado (normal, foco, desativado,
  erro, ligado/desligado, vazio, carregando).
- **RV-2** Dados da vitrine são fictícios, sem nome real de pessoa e sem dado de saúde (E12·3; `AGENTS.md` §6).
- **RV-3** A vitrine respeita as regras de tela do `DESIGN.md` em cada quadro (uma ação preta por quadro; controle
  sobre superfície branca). Onde fica disponível: E25·1.

## 7. Requisitos de acessibilidade (WCAG 2.2 AA; `DESIGN.md` §9)
- **RA-1** Contraste: texto ≥ 4,5:1 sobre `--page`, `--card` e `--track`; contorno de campo e ícone de estado ≥ 3:1.
- **RA-2** Área de toque ≥ 44 × 44 no celular e ≥ 40 × 40 no computador, mesmo com desenho menor (WCAG 2.5.8).
- **RA-3** Foco visível em todo controle, com o anel de RT-8, e ordem de foco lógica (WCAG 2.4.7, 2.4.11).
- **RA-4** Nada só por cor: estado e pendência com palavra ou nome no leitor (WCAG 1.4.1).
- **RA-5** Seletor com papel e teclado de abas; botão de ícone e status com nome acessível; folha, painel e
  janelinha prendem o foco e fecham com Esc; carregando anunciado ao leitor (WCAG 4.1.2, 4.1.3).
- **RA-6** Movimento reduzido respeitado (preferência do sistema).

## 8. Critérios de aceite (verificáveis)
| # | Critério | Como se prova |
|---|---|---|
| CA-1 | Cada token de RT-1 a RT-8 existe no código com o mesmo nome (cores) e o mesmo valor do `DESIGN.md` | teste de unidade que compara a lista de §4 com os tokens do código; 0 diferença |
| CA-2 | Nenhum valor de cor, sombra ou raio solto nos componentes (RT-9) | checagem automática no lint ou teste; 0 ocorrência |
| CA-3 | Os 22 componentes de §5 aparecem na vitrine com as variações de RV-1 | teste de ponta a ponta que encontra cada um pelo nome acessível |
| CA-4 | Medidas de RT-7 conferem (altura do botão 44/40, seletor 36 em 44, Agendar 52, pílula 20, painel 480 etc.) | teste de ponta a ponta mede as caixas em 390 e 1440 |
| CA-5 | 0 violação de nível A e AA na vitrine | checagem automática de acessibilidade em 390 e 1440 |
| CA-6 | Tab percorre todos os controles com anel visível; Esc fecha folha, painel e janelinha; setas trocam a aba do seletor | teste de ponta a ponta por teclado |
| CA-7 | Captura de tela da vitrine inteira em 390 e 1440 guardada como prova do teste | arquivos de captura gerados pelo teste na CI |
| CA-8 | Capturas da vitrine batem com as imagens aprovadas 01, 02, 03 e 06 de `docs/design/imagens/` (onde texto e imagem divergem, vale o texto: o Excluir é texto vermelho sem fundo, e o Designer de produto registra na ficha visual a diferença da imagem 06) | ficha visual (etapa 6) e Revisor de design pelo checklist §10 |
| CA-9 | Nenhuma peça, cor, nome ou medida fora do `DESIGN.md` | Revisor de design, checklist §10 item 8 |
| CA-10 | Tipos, lint, testes de unidade e de ponta a ponta verdes na CI | CI do PR |

## 9. Ficha visual (etapa 6)
Precisa, porque é tipo Tela. Como as peças já estão aprovadas nas imagens de `docs/design/imagens/` (E10, E12·3),
a ficha é a **comparação lado a lado**: imagem aprovada (antes) × captura da vitrine (depois), em 390 e 1440, feita
pelo Designer de produto e conferida pelo Revisor de design antes do dono.

## 10. Dúvidas para o dono (E25)
**Já decidido, não é pergunta:** o comentário do botão preto e do Agendar fica só registrado; a vitrine segue o
`DESIGN.md` de hoje ("+ Adicionar" com contorno no celular, Agendar preto). Decisão do dono, "Comentário" em
`docs/decisoes/2026-11-27-fundacao.md`: "nao precisa mexer nisso agora. só registro no design."

- **E25·1 · Onde a vitrine fica.** A: só em desenvolvimento e na prévia, fora da produção. B: também na produção,
  atrás do login. Desfaz: ligar ou desligar a rota. **Recomendo A** (não expõe página interna aos estúdios).
- **E25·2 · Medidas que o `DESIGN.md` não fixa: peso "forte", altura de linha e ícones.** A: usar as do canvas
  aprovado (`docs/design/canvas/v6.css` e `K3Controles.dc.html`): forte = 600; altura de linha 1,2 nos títulos e
  1,4 no texto; ícones Lucide com traço 1,75 e tamanhos 14, 16, 18, 20 (padrão) e 24; e os nomes Lucide dos ícones
  de função (✕, ‹, ›, ▾, ⋮, +, funil, sininho, ajuda, painel, lupa, calendário, Ordenar) como no canvas; os ícones
  que o `DESIGN.md` não nomeia, tirados da imagem 03 e do canvas aprovado (ficha visual): Categoria `shapes`, Mais
  `layout-grid`, Equipe `briefcase`, Modelo e seção Modelos `layout-template`, Termos `file-text`, Lista de espera
  `list-ordered`, menu ⋮ Editar `pencil`, Duplicar `copy`, Arquivar `archive`; fundo escurecido da camada aberta
  `rgba(22,24,29,.40)`; quadrado da inicial do estúdio 32 com canto 10; tudo gravado no `DESIGN.md`. B: o Designer
  de produto propõe outros valores (nos ícones sem nome: tirar o ícone até o mapa `L7Icones` ser aprovado).
  Desfaz: troca de um token ou de um nome. **Recomendo A** (é o que está nas imagens aprovadas; §5 pede ícone e nome
  nesses botões; sem isso os botões de função não podem ser construídos). Juntado aqui, e não numa E25·4, porque
  `AGENTS.md` §4 limita a 3 dúvidas por spec e é a mesma natureza (medida e nome que o `DESIGN.md` não fixa).
- **E25·3 · Largura em que a tela vira a de computador** (o `DESIGN.md` testa 390 e 1440, mas não diz onde troca;
  ex.: tablet). A: a partir de 840 px, classe "expanded" do Material Design 3 (norma já seguida pelo `DESIGN.md`).
  B: outra largura escolhida pelo dono. Desfaz: troca de um token. **Recomendo A.**

## 11. Assumptions (decididas pela norma, à vista na aprovação)
- Nomes dos tokens de RT-2 a RT-8 (que o `DESIGN.md` não nomeia) são escolha técnica do Arquiteto no plano; cores de
  RT-1 mantêm o nome exato.
- A fonte Geist é servida pelo próprio app (sem chamar serviço externo a cada visita), com `system-ui` de reserva.
- Ícones pela biblioteca Lucide (citada no `DESIGN.md` §5), só os ícones nomeados no `DESIGN.md` e os de função da E25·2; versão lida na
  documentação oficial no plano.
- Estrutura (RC-18, RC-19) entra só como peça visual com dados fictícios; rotas e mapa de navegação ficam para as
  specs de módulo.
- Ferramentas de teste (checagem de acessibilidade, comparação de capturas) são escolhidas no plano, depois de lida a
  documentação oficial (`AGENTS.md` §6).
</content>
</invoke>
