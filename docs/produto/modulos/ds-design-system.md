# Módulo: Design system (DS)

> As regras visuais do app inteiro: cores, letras, tamanhos, botões, listas, avisos, ícones e comportamentos. Vale para todas as telas, em computador e celular.
> Neste arquivo vale o que o dono respondeu a uma pergunta ou pediu com as próprias palavras (regra de 23/11, abaixo); o resto está marcado como **sugestão a confirmar**, inclusive a regra "v1 fechado, não se reabre".

**Telas e rotas:** não tem rota própria; aparece em todas as telas. A escolha do dono fica em `/{org}/configuracoes?secao=aparencia` (forma e tamanho dos elementos) · **Código:** `src/design-system/` (peças), `src/design-system/primitives.css`, `src/styles/globals.css` · **Spec(s):** sem spec aprovada. O que vale hoje está em `docs/design/design-system/regras-vigentes.md` (resumo escrito pela IA) e em `docs/decisoes/historico/registro-ate-2026-11-24.md` (histórico). A proposta de 23/11 para fechar as divergências está em `docs/specs/plans/2026-11-23-fechar-design-system.md` (nada escolhido).

## Recursos
| ID | Recurso | Estado | Onde | Origem |
|---|---|---|---|---|
| DS-01 | Camada 1, cores: só 9 cores (branco, B #F7F7F4, C #F1F1EC, D #E4E4DE, D2 #D0D0C8, texto E, texto secundário E2 #6A6E76, dourado F #7A5A22, mais âmbar, verde e vermelho de estado) | pronto (atual: regras-vigentes marca ✅) · pronto V25 (antigo) | `src/styles/globals.css` | registro CAM1-01 (reg:196); regras-vigentes:10; R1 A.3 |
| DS-02 | Dourado só no botão principal, um por tela | parcial: dourado fora do botão em 8 arquivos (regras-vigentes:11); a proposta de 23/11 conta cerca de 25 lugares | em `agenda/_new/GuideFrame.tsx`, `catalogo/_shared/FiltersButton.tsx`, `app-shell/Sidebar.tsx` e outros | CAM1-07, CAM1-OPEN-02 (reg:201); regras-vigentes:11; fechar-ds C2 |
| DS-03 | Escolhido fica preto (chip, caixinha, chave, dia) ou cinza C com ✓ (linha, menu); nunca dourado | pronto nas peças · parcial nos arquivos acima | peças do DS | CAM6-01, CAM6-02, CMP-B2, CARD-08 (reg:226-227); regras-vigentes:12 |
| DS-04 | Âmbar, verde e vermelho só para estado e sempre com palavra ou ícone com nome; informação em cinza, sem azul | parcial: verde de enfeite em 4 arquivos | `agenda/_new/GuideClientColumn.tsx`, `financeiro/_components/comanda/SplitStep.tsx` e outros | CAM7-02 (reg:233); regras-vigentes:13-14 |
| DS-05 | Fundo branco; cartão, painel e folha brancos com contorno D; sem sombra (sombra só no que flutua); escurecimento atrás de janela 35% | parcial: código ainda em 52% (reg:202), enquanto regras-vigentes:26 marca ✅ | `src/styles/globals.css` | CAM1-03, CAM1-08, CAM2-04 (reg:198, 202, 209); R1 F-5 |
| DS-06 | Cor das profissionais na agenda: cores só bem próximas; agendamento e comanda sem faixas coloridas (só etiqueta pequena) | planejado: valores dos "tons próximos" não definidos; código ainda usa faixas azul, tijolo e dourada | agenda e agendamento | CAM1-11 (reg:205); AG24·B; regras-vigentes:93; fechar-ds C1 |
| DS-07 | Cabeçalho do agendamento sem cor de estado | pronto (regras-vigentes ✅) | `DateHeader.tsx` (agenda) | CAM1-09 (reg:203); regras-vigentes:19 |
| DS-08 | Camada 2, formas: Reto, Misto (padrão) e Pílula; Misto = botão em pílula, campo e busca 8, chip 6, cartão 12 | pronto (Reto: botão ainda pílula) · 3 temas e formas prontos (antigo) | Ajustes › Aparência | CAM2-01 a 03 (reg:206-208); CMP-C1; regras-vigentes:24 |
| DS-09 | Camada 3, letras: 6 tamanhos (12, 13, 14, 15, 17, 22); pesos 400, 500, 600 (600 só no título da página e no total); fonte Geist | parcial: 20 tamanhos em uso e peso 600 em 437 lugares (proposta de 23/11) | código inteiro | CAM3-01, CAM3-02 (reg:210-211); fechar-ds T2, T3; regras-vigentes:30-31 |
| DS-10 | Números de dinheiro alinhados à direita, com dígitos de largura igual; rótulo em cinza E2 e valor em preto sem negrito | pronto (números) · parcial (rótulo e valor) | peça `Money` | CAM3-04, CAM1-02 (reg:197, 213) |
| DS-11 | Camada 4, tamanho: 4 níveis (Ultra 75%, Compacto 85% padrão, Normal 100%, Grande 110%); tudo cresce junto | pronto | Ajustes › Aparência; `src/design-system/primitives.css` | CAM4-01 (reg:214); regras-vigentes:39 |
| DS-12 | Alvo de toque: 40 px no computador, 44 px no celular, mesmo com o botão encolhido | pronto (atual) · antigo: spec 01 diz 40 px, V25 diz 44 px | `primitives.css` | CAM4-02, CAM4-05 (reg:215, 218); R4 B spec 01:30-34; R5 F |
| DS-13 | Altura da hora na agenda como controle à parte (44/60/84 no computador, 44/52/64 no celular) | parcial: não acompanha o nível de tamanho; em Normal e Grande o texto do cartão de 1 h corta | agenda | CAM4-04 (reg:217); regras-vigentes:41 |
| DS-14 | Respiro entre blocos e esqueleto das páginas (Lista, Agenda, Painel de tarefa, Detalhe, Ajustes) | planejado: 4 versões escritas, "nunca decidido" (régua de 20/11, CMP-C2 20/16 e 16/12, P1 a P7 de 23/11) | todas as telas | CAM4-03 (reg:216); regras-vigentes:44-52; R3 B padrao:78-93 |
| DS-15 | Escala de respiro do Radix e do shadcn (4, 8, 12, 16, 24, 32, 48), margens 16 celular e 24 computador | planejado: proposta, nada escolhido (pedido do dono de 23/11) | todas as telas | fechar-ds R1 a R5; R2 A.2 |
| DS-16 | Camada 5, botões e campos: foco em anel cinza de 2 px; contorno D no campo e no botão secundário (D2 no só-ícone); obrigatório com * cinza; erro com contorno vermelho de 1 px e mensagem com ícone | parcial: foco ainda preto, campo em D2, erro com 2 px (regras-vigentes ⚠️) · o README do DS diz "sim" (contradição) | peças `Field`, `Input`, `Button` | CAM5-01 a 03 (reg:220-222); regras-vigentes:58-60; README do DS:13; R1 F-5 |
| DS-17 | Altura dos botões (32 no computador, 40 no celular) e botões de horário mais justos | a definir (proposta T1 e N1·A) | peça `Button` | fechar-ds T1; R1 A.2 N1 |
| DS-18 | Peça desativada a 50% | pronto | peças do DS | CAM5-04 (reg:223) |
| DS-19 | Camada 6, seletores, listas e menus: caixinha onde cabe mais de uma escolha, linha ou cartão com ✓ onde cabe uma só (sem bolinha de rádio); ⋮ sempre visível; tocar na linha abre | pronto (Status da Agenda com caixinhas) | peças `Checkbox`, `ChoiceList`, `ChoiceRows`, `ActionMenu` | CAM6-01 a 03, CMP-B1 (reg:226-228, 253); regras-vigentes:62 |
| DS-20 | Voltar, fechar e expandir em círculo cheio (cor B); setinha de abrir bloco solta; setinha do cartão da cliente em bolinha | parcial: ✕ sem círculo em várias janelas | `MobileHeader`, `IconButton` | CAM6-05, CAM6-06, CMP-D2 (reg:230-231); fechar-ds F1; regras-vigentes:63 |
| DS-21 | Todo painel, folha ou diálogo no celular com X visível de 44 px | pronto (item 1 da auditoria v26 "feito") | peças de folha | v26-mobile-ux:7-11; R1 B |
| DS-22 | Um modelo só de menu: preso ao botão no computador, folha de baixo com título no celular, um aberto por vez, Esc ou clique fora fecham | planejado: hoje 6 jeitos de abrir menu (proposta M1) · regra escrita "sem frase dele" | `ActionMenu`, `Sheet`, `SidePanel` | R3 B padrao:99; fechar-ds M1 |
| DS-23 | Setinha que mostra que abre: ▾ no botão que abre menu, › na linha que leva a outra tela | a definir (proposta M4) | todas as telas | fechar-ds M4; R5 A comentário de 08/11 |
| DS-24 | Abas e segmentos (Tabs, SegmentedControl, TabBar): segmentos para trocar a forma de ver, abas sublinhadas para trocar de seção | "Proposta" no registro; Tabs e SegmentedControl sem uso ou feitos à mão (27 segmentos e 4 abas) | `src/design-system/Tabs`, `SegmentedControl` | STATUS:41-42; fechar-ds M5; R3 B audit:37 |
| DS-25 | Camada 7, avisos e estados: aviso flutuante claro embaixo; info cinza; atenção âmbar; erro vermelho; tela vazia com ícone em quadrado B; carregando só depois de 300 ms | pronto | `Toast`, `Notice`, `EmptyState`, `LoadingState`, `ErrorState` | CAM7-01 a 04 (reg:232-235); regras-vigentes:65 |
| DS-26 | Camada 8, ícones: Lucide, traço 1,75, 6 tamanhos com nome (Micro a Extra); Filtros = funil; mais ações = ⋮; comanda = recibo sem cifrão; nunca emoji | pronto | `src/styles/globals.css` (escala `--ic-k`) | CAM8-01 a 04 (reg:236-239); README do DS:25-30 |
| DS-27 | Camada 9, comportamentos: tempos 150/200/150 ms; aviso de 5 s (8 s com Desfazer; erro fica até fechar); folha no celular; Esc fecha; movimento reduzido respeitado | pronto | peças do DS | CAM9-01 a 03 (reg:240-242); regras-vigentes:67 |
| DS-28 | Aparência em Ajustes: forma (Reto, Misto, Pílula) e 4 níveis de tamanho | pronto (atual) · antigo: claro/escuro e "botões da barra só ícone" não existem (G4, G5 da spec 46) | `/{org}/configuracoes?secao=aparencia`; `ajustes/AppearanceSection.tsx` | R1 B rv:25,39; R4 B spec 46:8-33,124-127 |
| DS-29 | Tema claro e escuro | descartado na v1 (spec 01 do antigo) · pendente (G5 da spec 46) · nada no atual | — | R4 B spec 01:79-83; spec 46:124-127 |
| DS-30 | Temas Barbearia e Essencial (cores próprias, para outros tipos de negócio) | pronto (antigo, 3 temas) · "Proposta, sem uso pelo Studio Karenn" (atual) | tokens do DS | R5 B design-system.md:5-22; registro CAM1-OPEN-02 (reg:17); STATUS:41 |
| DS-31 | Cores c1 a c4 das profissionais (azul, tijolo, dourado, verde) "ficam como estão", sempre com nome | pronto · em conflito com CAM1-11 (a definir) | agenda | registro CAM1-OPEN-02 (reg:17); fechar-ds C1 |
| DS-32 | Peças prontas do DS no código: cerca de 60 peças em `src/design-system` (Button, Field, Sheet, SidePanel, Toast, KpiCard, PageHeader, StatusChip, SummaryList, ToggleRow e outras) | pronto · parcial: Tabs, KpiCard, PageHeader, SummaryList, ToggleRow, StatusChip e SegmentedControl sem uso (código morto) | `src/design-system/` | R3 B audit:37; fechar:178-180 |
| DS-33 | Peças da camada 10 (cartão da cliente, Notas, Formulários, passos do novo agendamento, cartões de pagamento, painel Desconto \| Gorjeta \| + Taxa, resumo em cascata) | planejado: "nenhuma está nas peças do DS nem no código ainda" (regras-vigentes:8) | módulos Agendamento e Comanda/Checkout | CARD-05, 06, 09, 10, 11b, 15, CMP-D2 a D4 (reg:258-260 e seção Cardápio revisto); regras-vigentes:75-85 |
| DS-34 | Camada 10, telas no visual novo: fechar as 42 divergências da página de escolhas | parcial / em andamento (Agenda na prévia, Agendamento não) | todas as telas | R2 B ROADMAP:11; BACKLOG:23; fechar-ds |
| DS-35 | Palavras padrão: "Formulário" (não "Ficha"), "Atividade" (não "Histórico"), "Sem reserva (balcão)", notas "Nota da reserva · Nota fixa cliente · Nota do agendamento" | parcial: o app ainda escreve "Ficha Cliente", "Observação do agendamento", "Histórico" | textos das telas | CMP-E1 a E3 (reg:261-263); regras-vigentes:35 |
| DS-36 | Lacunas sem decisão: cor da bolinha da cliente, cor por categoria do Catálogo, quadrado dourado com a inicial do estúdio, valores dos "tons próximos" | a definir | agenda e catálogo | regras-vigentes:93; R3 B padrao:174 |
| DS-37 | Contraste de contorno (se há valor mínimo) | a definir: "consta que você dispensou", sem mensagem guardada | todas as telas | OWNER:53; R3 B audit:83 |
| DS-38 | Referência viva: página "Beauty System Design System" no claude.ai (versões 40 a 42) e cópia por camada em `docs/design/design-system/camada-NN-*` | pronto como referência · diferença entre o DS do código e o publicado ainda sem dono (ICEBOX 33) | `docs/design/design-system/` | README do DS:5; R2 D.2 ICEBOX:43 |
| DS-39 | Spec 01 do antigo: 37 componentes, página `/dev/design-system`, todos os estados (padrão, hover, foco, desligado, carregando, erro), componente até 300 linhas | planejado no antigo (critérios `[ ]`) · a vitrine `/showcase` do atual foi cancelada | — | R4 B spec 01:30-34; R3 B vit:5 |
| DS-40 | Layout limpo e padrão Fresha (specs 45 e 46): menos cor, menos caixa, botão principal bronze, caixinha quadrada, menu em lista com acordeão | parcial (antigo; Agenda e ficha do cliente) · substituído pelo v1 no atual | — | R4 B spec 45:5-26, spec 46:8-33 |
| DS-41 | Livro de padrões 10 a 12/11 (16 padrões com "OK" do dono sem frase) e cardápio de 11/11 | histórico: vale o registro quando divergem (padroes/README:3) | `docs/design/padroes/livro-2026-11-12/` | R1 A.5; R1 F-1 |
| DS-42 | Design system V3 (azul-petróleo, rosa) e V25 (quadro de out/nov) | descartado (V3) · histórico, "substituído pelo v1" (V25, G12) | `docs/design/v25-mockups`, `docs/produto/legado` | R5 B design-system V3; registro G12 (reg:128) |
| DS-43 | Tamanho das peças: botão 32/40, chip 30/40, campo 36/44, item de menu 40, linha 48/68, barra do topo 48/56, menu lateral 84/240, toque 40/44 (computador/celular) | pronto (regra escrita) · o DS só confere a altura do botão (DS-17) | todas as telas | R3 B padrao:60-76 (`specs/plans/2026-11-23-padrao-agenda-e-agendamento.md`) |
| DS-44 | Densidade e botões da spec 42 §8: Compacto (padrão) × Confortável; botão 40/44 px; padding 1em/1.15em; ícone-texto .45em/.5em; fonte 14/600 e 15/600; linha de lista 52/60; respiro entre seções 12/16; padding de cartão 12/14 e 16/18; toque nunca abaixo de 40 px; escala 4 · 8 · 12 · 16 · 24 | planejado no antigo (spec "proposta para aprovação", 30/10) · diverge do atual (4 níveis, DS-11; botão 32/40, DS-17) | peça `Button`, listas, cartões | legado spec 42:59-73 |
| DS-45 | Componentes a criar da spec 42 §11: `MoreButton` (⋮), `ContextBar` (período, equipe, abas), `CountBadge`, `AccordionRow` e `AccordionList`, `FullPanel` (tela cheia presa no topo, rodapé fixo), `ActionBar` (rodapé `[⋮][secundário][primário]`), `Fab`; nenhum acima de 300 linhas | planejado no antigo · conferir contra as peças do atual (DS-32) quando entrar em trabalho | `src/design-system/` | legado spec 42:93-95 |
| DS-46 | Auditoria das telas por ondas (spec 42 §10): onda 1 Agenda; onda 2 Clientes, Catálogo, Financeiro; onda 3 Anamnese, Marketing/Mensagens, Ajustes e Mais; cada onda com capturas 390 e 1440 px antes e depois e E2E do fluxo crítico; desvios conhecidos por módulo (chips de seleção única, topo de ~194 pt, ⋯ e ⋮ misturados, abas em chips, lista sem resumo do valor) | planejado no antigo (nenhuma onda marcada) · a NAV-D17 cobre só a aprovação da spec | todas as telas | legado spec 42:79-91 (R4 B) |
| DS-47 | Achados de experiência do antigo (29/10): controles < 40 px e sem rótulo no checkout, dinheiro em 3 formatos, informação só em tooltip, sino e menu do usuário sem função e sem "Sair", contraste baixo em selos, termos misturados | histórico (sistema antigo) | — | R5 B revisao-profunda:78-97 |
| DS-48 | Hotfix de abas UX-SYSTEM-02B (`globals.css` sem BOM, cor das abas no `layout.tsx`, Catálogo com abas próprias) | histórico, pronto no antigo | — | R5 B delivery-review-2026-06-16-ledger-front-tabs-hotfix:40-61 |

"Estado" é o que os documentos dizem; o código é conferido quando o módulo entra em trabalho.

## Decisões
| ID | Decisão | Situação | Origem |
|---|---|---|---|
| DS-D01 | Design system v1 (camadas 1 a 9) fechado: "não se reabre; o que foi escolhido vale" | **sugestão a confirmar** (as camadas foram registradas sem frase do dono; o registro diz que valem "a confirmar") | CLAUDE.md:87; README do DS:31; reg:8; R1 F-13; fechar-ds P1 |
| DS-D02 | Lacuna dentro do v1: a IA não aplica sozinha; junta numa ficha curta e espera a escolha do dono | **a confirmar** (antes: vale) ("Propõe e espera meu ok antes de aplicar", 19/11/2026, resposta à pergunta "quando faltar um detalhe pequeno dentro das peças básicas já escolhidas, o que a IA deve fazer?") | adr/2026-11-19-lacunas-do-design-system.md:6,15-18 |
| DS-D03 | O sistema é mobile first (menus, submenus, telas, chips e abas pensados para o celular primeiro) | **a confirmar** (antes: vale) (pedido dele, frase própria: "O sistema tem de ser mobile first…", 23/11/2026, 12h58) | R3 A; falas-do-dono:85 |
| DS-D04 | Telas minimalistas, densidade baixa ou média, bom respiro lateral e superior (G3); o quanto, vê-se na prévia (N1) | **a confirmar** (antes: vale) a direção (frases dele: "minimalista, baixa ou média densidade, clean", 15/11 e 20/11); os números são **sugestão a confirmar** | R1 A.2 G3 (reg:117); falas-do-dono tema 1 |
| DS-D05 | Regras de respiro seguem o Radix e o shadcn | **a confirmar** (antes: vale) como direção (pedido dele: "Regras de respiro, devem seguir o radix/shadn", 23/11/2026); a escala e as medidas (R1 a R5) são **sugestão a confirmar** | R2 A.2; fechar-ds R1 a R5 |
| DS-D06 | Seletor de forma Reto, Misto e Pílula, com Misto como padrão (CAM2-01) | **a confirmar** (antes: vale) (frase dele: "formato anterior tava melhor, pode fechar", 17/11/2026; pergunta de 17/11 não guardada no repositório) | R1 A.3; reg:206 |
| DS-D07 | Cores com direção de agenda: "cores bem próximas"; no agendamento e na comanda, sem faixas, só etiqueta pequena (CAM1-11) | **a confirmar** (antes: vale) (frase dele de 20/11/2026: "pode ter cores diferentes, mas cores bem próximas… exceto se for uma tag, uma etiquetinha pequena"); os valores dos tons são **sugestão a confirmar** | R1 A.3; reg:205 |
| DS-D08 | O que a IA propõe se chama "sugerido", não "decidido" (G1) | **a confirmar** (antes: vale) (frase dele: "Não vamos usar o termo decididas, vamos usar sugeridas", 20/11/2026) | R1 A.2 G1 |
| DS-D09 | Nomes das notas: Nota da reserva · Nota fixa cliente · Nota do agendamento (CMP-E1) | **a confirmar** (antes: vale) (frase dele de 19/11/2026, 10h43: "Nota da reserva - Nota fixa cliente - Nota do agendamento (não é 'da cliente'…)") | R3 A; reg:261 |
| DS-D10 | "Formulário" no lugar de "Ficha" nos textos; o menu "Formulários" com vários tipos fica para spec própria (CMP-E2) | **a confirmar** (antes: vale) (resposta dele "Só o nome por enquanto", 19/11/2026, 10h43, à pergunta E2 escrita por inteiro: "o menu lateral 'Anamnese' passa a se chamar 'Formulários'… No agendamento fica 'Formulário pendente' e 'Abrir formulário'"; vale o nome nos textos; o menu "Formulários" com vários tipos fica para spec própria) | falas-do-dono:181; reg:262 |
| DS-D11 | Paleta de 9 cores e uso (CAM1-01 a 05) | **sugestão a confirmar** (registro com "Alexandre, 16/11" sem frase) | reg:196-200 |
| DS-D12 | Dourado só no botão principal, um por tela (CAM1-07); botão principal dourado contra escuro (V25) contra bronze (specs 45 e 46) | **sugestão a confirmar** (a proposta de 23/11 pergunta de novo: C2; "aceito sua recomendação" de 19/11 17h09 respondeu a pergunta que não está anexada) | reg:201; fechar-ds C2; R3 A; consolidado §4-15 |
| DS-D13 | Botões só-ícone de 32 px e dourado no novo agendamento | Dourado no novo agendamento: **a confirmar** (antes: vale) (resposta ao item da pergunta, "aceito sua recomendação", 19/11/2026, 17h09; igual à AGD-D05) · botões só-ícone de 32 px: **sugestão a confirmar** (pergunta não anexada) | R3 A; fechar-ds C2, T1 |
| DS-D14 | Cabeçalho do agendamento sem cor de estado (CAM1-09) | **sugestão a confirmar** (sem frase; a frase de CAM1-11 cobre só a comanda) | reg:203 |
| DS-D15 | Formas Reto e Pílula: valores de canto; sombra só no que flutua (CAM2-02 a 04) | **sugestão a confirmar** | reg:207-209 |
| DS-D16 | Escala de letras 12/13/14/15/17/22 e pesos 400/500/600; cabeçalho de tabela cinza 12 px; números tabulares (CAM3) | **sugestão a confirmar** (a proposta de 23/11 pergunta T2 e T3) | reg:210-213; fechar-ds T2, T3 |
| DS-D17 | 4 níveis de tamanho, toque 40/44 e botão que encolhe (CAM4-01, 02, 05) | **sugestão a confirmar** | reg:214-218 |
| DS-D18 | Respiro H2 por nível e régua de 20/11 (CAM4-03, CMP-C2 "A") | **sugestão a confirmar** (CMP-C2: resposta em letra, 19/11, sem a frase no repositório; a régua de 20/11 é "proposta do Claude, nunca aceita") | reg:216, 256; R3 F-7, F-20 |
| DS-D19 | Botões e campos: foco cinza de 2 px, contorno D, obrigatório com * cinza, erro de 1 px (CAM5-01 a 03) | **sugestão a confirmar** | reg:220-222 |
| DS-D20 | Seletores: dia e horário escolhidos, caixinha preta, ⋮ sempre visível, voltar e fechar em círculo, seta solta (CAM6-01 a 06) | **sugestão a confirmar** (pedidos dele de 08/11 sobre o círculo no voltar são de antes; o registro é sem frase) | reg:226-231; fechar-ds F1 |
| DS-D21 | Caixinha onde cabe mais de uma escolha; ✓ onde só cabe uma (CMP-B1) | **sugestão a confirmar** (resposta em letra ao comparativo; a proposta M3 pergunta de novo) | reg:253; fechar-ds M3 |
| DS-D22 | Avisos, estados, ícones Lucide, comportamentos (CAM7, CAM8, CAM9) | **sugestão a confirmar** (CAM8-03 "Alexandre, 18/11" sem frase; CAM8-01 "tamanhos coerentes com cada lugarzinho" é pedido dele sem data exata) | reg:232-242 |
| DS-D23 | Cantos "Misto" confirmados no comparativo (CMP-C1 "A") | **sugestão a confirmar** (resposta em letra, sem frase no repositório) | reg:255; fechar-ds F2 |
| DS-D24 | Escolhas de 19/11 ("Minhas escolhas de 19/11 valem") para AG1 a AG10 e CARD-05 a CARD-15 | **sugestão a confirmar** (aceite em lote a uma lista) | R1 A.0, F-9; reg:35 |
| DS-D25 | Lista única da Fase 1 de 22/11 ("aceito todas"): inclui G1 a G12 e N1 a N6 | **sugestão a confirmar** (aceite em lote) | R1 A.0; reg:67 |
| DS-D26 | V25 é histórico, substituído pelo v1 (G12); as 11 recomendações antigas do Cardápio ficam como "sugeridas" | **sugestão a confirmar** (proposta da IA aceita em lote) | reg:128 |
| DS-D27 | Temas Barbearia e Essencial ficam como "proposta, sem uso" (CAM1-OPEN-02) | **sugestão a confirmar** | reg:17 |
| DS-D28 | Contraste de contorno dispensado | **sugestão a confirmar** (nenhuma mensagem dele guardada; pergunta 1 do OWNER aberta, sem recomendação) | OWNER:53; R3 B audit:83 |
| DS-D29 | Mensagem de ação sem permissão: some (AGS5) ou fica desativada com o motivo (camada 7) | **sugestão a confirmar** (as duas regras valem na escrita; M9 pergunta) | reg:81; fechar-ds M9 |
| DS-D30 | Gênero dos textos: feminino ("Nova cliente", v26) contra neutro (13/11) | **sugestão a confirmar** (sem resposta) | v26-auditoria-fluxos:32; consolidado §4-22 |
| DS-D31 | Vitrine `/showcase` não entra; testa-se na prévia | **a confirmar** (antes: vale) (frase dele: "nao vai entrar esse showcase e site adicional nao.. o que tiver de testar seja feito no dominio final -previas…", 22/11/2026, 23h15) | reg:144; R1 A.0 |
| DS-D32 | A decisão de design só existe com a frase dele e a data; o resto é "proposta do Claude, a confirmar" | **a confirmar** (antes: vale) (frase dele: "Vc tem de ignorar qq coisa escrita falando que eu aprovei ou mandei pq foi a IA que escreveu e não eu." + "Opção A", 23/11/2026) | adr/2026-11-23-decisao-com-prova.md; R1 A.0 |

Regra: só vale decisão registrada em `docs/decisoes/` (molde de pergunta). Tudo desta tabela é **a confirmar**; a situação antiga fica entre parênteses só como histórico e volta a ser perguntada quando o módulo for trabalhado (resposta 15a do dono, 24/11/2026).

## Regras de negócio
- Só o dono decide o que aparece na tela (imagem, layout, texto). Detalhe que nenhuma decisão cobre vira proposta na ficha da tela e espera a escolha (DS-D02).
- Um botão principal por tela. Escolhido nunca fica dourado. Cor de estado nunca enfeita.
- Nunca emoji; ícones só do Lucide, com tamanho de uma escala.
- Alvo de toque de 40 px no computador e 44 px no celular (sugestão a confirmar: conflito de 40 contra 44 no antigo).
- Todo painel, folha ou diálogo no celular tem X visível de 44 px.
- Tela até 300 linhas e arquivo até 500; nada de cor ou medida fora dos tokens; fonte Geist.
- Conferir sempre a tela em 1440 px e em 390 px.
- Quando o registro e esta página divergem, vale o registro de decisões; quando as camadas e a prévia divergem, a prévia não vence: a diferença vira pergunta para o dono.
- Mudar uma decisão = linha nova no registro; a antiga vira "Substituída". Decidida nunca é apagada.

## Pendências e perguntas
| Pergunta ou pendência | Origem |
|---|---|
| As escolhas antigas sem frase (cerca de 155 linhas `[S]`) valem ou voltam como pergunta? Mesmo para as camadas 1 a 9? (P1 da página de 23/11) | consolidado §4-1; fechar-ds P1 |
| Densidade padrão: peças pequenas (Compacto) com respiro do shadcn, ou Normal, ou um nível só? (P2) | fechar-ds P2 |
| Escala de respiro: só 4, 8, 12, 16, 24, 32, 48 (R1); margem da tela 16 e 24 ou 16 e 32 (R2); dentro e entre cartões (R3); entre seções (R4); menus e campos (R5) | fechar-ds R1 a R5 |
| Altura dos botões 32/40 (T1); tamanhos de texto 6 ou 5 (T2); peso 600 só no título e no total (T3) | fechar-ds T1 a T3 |
| Cores da agenda (C1); onde o dourado aparece (C2); aviso de formulário pendente com ponto verde ou âmbar (C3) | fechar-ds C1 a C3 |
| Círculo em volta de ✕, voltar e expandir (F1); cantos Misto ou shadcn (F2) | fechar-ds F1, F2 |
| Menu único (M1); submenu ao lado ou dentro (M2); caixinha ou ✓ (M3); setinha (M4); abas e segmentos (M5); status nome e ícone (M6); quais status (M7); notas e formulários aparecem quando (M8); ação sem permissão (M9); segurar o cartão (M10) | fechar-ds M1 a M10 |
| Telas: agenda no celular (E1, E2), troca de visão (E3), lupa (E4), "+ Novo" repetido (E5), janela do agendamento (E6), atividade (E7), mesma janela do novo e aberto (E8), avisos e sinal (E9), rodapé nos passos (E10), janela de ação (E11), cartão da cliente (E12) | fechar-ds E1 a E12 |
| Palavras: "Ver cliente" ou "Ver perfil" (E13); Formulário, Ficha e Anamnese (E14); nomes das notas (E15); sinal em ausência (E16); "decidido" ou "sugerido" (E17) | fechar-ds E13 a E17 |
| Contraste de contorno: confirmar a dispensa ou ver exemplos na prévia? (pergunta 1 do OWNER) | OWNER:53 |
| Método de escolha de tela: imagem aprovada uma vez, página A/B, link da prévia ou ficha no Design do claude.ai? | consolidado §4-3; R3 F-3 |
| Cor do botão principal e alvo de toque: dourado, escuro ou bronze; 40 ou 44 px | consolidado §4-15 |
| Qual é a fonte única de decisão: registro de design, página de escolhas ou specs? | consolidado §4-20; R3 F-6 |
| Diferença entre o DS do código e o publicado (ICEBOX 33): a IA confere antes de cada ficha, ou segue como está? | R2 D.2 ICEBOX:43 |
| Modo claro e escuro: entra algum dia? | R4 B spec 46 G5 |
| Respostas do comparativo de 19/11 ficaram só no navegador (`comparativo-ds-v1`); a frase do dono não está no repositório | R1 A.7, F-23 |
| Arquivos com dourado fora da regra, verde de enfeite, foco preto, erro de 2 px, escurecimento 52%: aplicar só com ordem do dono | regras-vigentes:11-13,26,58-60; reg:202 |
| Cópia do DS "KA Beauty OS" (PR #64, fechado sem fundir) e 86 grupos de imagens repetidas (CAM10-IMG-01) | consolidado; R1 D |
| Spec 42 do antigo ficou "proposta para aprovação" (30/10): densidade §8, ondas §10 e componentes §11 (DS-44 a DS-46) valem no atual ou ficam como histórico? | legado spec 42:3,59-95 (R4 D) |
| S1 a S5: 145 medidas da Agenda e do Agendamento fora dos tokens; a pergunta foi trocada por P1 a P7, mas o achado segue sem destino | R2 D STATUS:9 (`docs/STATUS.md:9`) |
| `tokens.css` só troca o azul de informação por cinza quando alguém salva um token | R1 D reg:138 |
| Achados 23 a 29 da auditoria v26 (folha "Enviar link", linhas de atenção de 21 px, chips de 26 px), não verificados | v26-auditoria-fluxos:36-42 (R1 D; R5 D) |
| Perguntas sem resposta do V25: "Aprova a V20 como padrão das telas de lista?" e "Agendar fixo ou só ao passar o mouse?" (V25 substituído pelo v1, reg:128) | v25-mockups/PDecisao.dc.html (R1 D) |
| Teste do `ActionMenu` falhando no antigo (size-10 × size-7, toque de 40 px divergente), 20/06 (histórico) | R5 D agenda-status-notes-core-02-2026-06-19:85,105 |

## Referências
- Resumo do que vale: `docs/design/design-system/regras-vigentes.md`. Histórico com a prova: `docs/decisoes/historico/registro-ate-2026-11-24.md`. Camadas com imagem final: `docs/design/design-system/camada-01-cores` a `camada-10-telas`. Comparativo de 19/11: `docs/design/design-system/comparativo-2026-11-19/`.
- ADRs: `docs/adr/2026-11-18-design-system-v1-congelado.md` (substituída), `docs/adr/2026-11-19-lacunas-do-design-system.md`, `docs/adr/2026-11-19-desenho-para-decidir.md`, `docs/adr/2026-11-23-decisao-com-prova.md`.
- Proposta de 23/11 (42 divergências): `docs/specs/plans/2026-11-23-fechar-design-system.md`. Falas do dono: `docs/specs/plans/2026-11-23-falas-do-dono-por-tema.md`.
- Legado: `docs/produto/legado/specs/01-design-system.md`, `45-layout-limpo.md`, `46-padrao-fresha-aprovado.md`, `42-padrao-de-interface.md`; `docs/design/v25-implementacao.md`, `v25-mockups/`, `v26-mobile-ux.md`, `v26-auditoria-fluxos.md`.
- Referências de mercado: `docs/fresha-prints-referencia/`, `docs/referencias-mercado/`.
- Levantamento: R1 A.3 a A.8, B, C, F; R3 B (Design system), F; R4 B specs 01, 45, 46; R5 B (Design system).
