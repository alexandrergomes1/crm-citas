# Módulo: Catálogo (CAT)

> Tudo o que o estúdio vende: serviços (com categorias), pacotes de sessões, combos, planos de assinatura e produtos com estoque.
> Agenda, comanda e reserva online leem este catálogo.

**Telas e rotas:** `/{org}/catalogo` (serviços e categorias) · `/{org}/catalogo/pacotes` · `/{org}/catalogo/produtos` · `/{org}/catalogo/combos` · `/{org}/catalogo/planos` (cada editor abre por `?novo=1` ou `?editar={id}`; produtos também `?foco=estoque`) · há ainda `/{org}/anterior/catalogo` (redirecionamento do catálogo antigo) · **Código:** `src/workspace/catalogo` (`_services`, `_packages`, `_bundles`, `_plans`, `_products`, `_shared`) · **Spec(s):** sem spec no crm-agenda (só a auditoria). No legado: `docs/produto/legado/specs/07-catalog-services-products.md`, `08-packages-memberships.md`, `catalog-01-regras-por-servico.md`, `catalog-02-produtos-combos-planos.md`.

Siglas da coluna Origem: `R1` a `R5` = relatórios em `docs/reorganizacao/levantamento/` (letra = seção, depois fonte). `reg:N` = linha N de `docs/decisoes/historico/registro-ate-2026-11-24.md`. "antigo" = Beauty System; "atual" = crm-agenda.

## Recursos
| ID | Recurso | Estado | Onde | Origem |
|---|---|---|---|---|
| CAT-01 | Serviços e categorias | pronto (antigo) · pronto (atual) | `/catalogo` | R4 B spec 08:39-45; R5 B scope-master:62; R2 B STATUS:30; R3 B audit:26 |
| CAT-02 | Serviço com nome, categoria, descrição, preço, tipo de preço (fixo ou "a partir de"), duração 15 a 240 min, buffer 0 a 60 min, comissão %, reserva online e ativo; categoria com 12 cores e emoji; serviço inativo some da Agenda e do Checkout; buffer invisível à cliente; preço 0 é válido | planejado (spec 07, critérios `[ ]`) · pronto (spec 08) | `/catalogo`, editor do serviço, `CategoryDialog` | R4 B spec 07:12-38; R4 B spec 08:39-45 |
| CAT-03 | Tipo de preço canônico: gratuito (força 0), a partir de, fixo e sob avaliação (extensão KA Beauty); valor e apresentação nunca divergem | parcial (gratuito explícito hoje depende de preço 0; "sob avaliação" pronto) | editor do serviço | R4 B spec 08:46,61-70 |
| CAT-04 | Profissionais habilitados por serviço (`service_staff`); modelo de anamnese por serviço; serviço exige ficha | pronto (antigo) | editor do serviço | R4 B spec 08:43-47; R5 B scope-master:66-67; R5 B archive/dev-scope:68-80 |
| CAT-05 | Durabilidade do resultado (1 a 120 meses) e sinal por serviço (fixo ou porcentagem; o novo agendamento soma o sinal sugerido e liga "Pedir sinal" sozinho; valor fixo nunca passa do preço) | pronto (antigo) | editor do serviço (`ServiceRulesFields`) | R4 B catalog-01:5-20; R5 B core-delivery-control:53 |
| CAT-06 | Retoque incluído: janela de 1 a 365 dias; o perfil da cliente avisa "Retoque de X vence em N dias"; a comanda aplica valor zero; a visita seguinte na janela consome o direito; dispensar pede motivo; atalhos +2, +4, +6 semanas e +3 meses | pronto (antigo, regra por serviço) · planejado (atual, G7) | editor do serviço, perfil, comanda | R4 B catalog-01:5-20; R1 A G7 (reg:123) |
| CAT-07 | Serviço sem duração (`duration_minutes = 0`): ocupa 15 min na agenda, combo e comanda; nunca reservado online | pronto (antigo) | editor do serviço | R4 B catalog-01:22-25 |
| CAT-08 | Pacotes de sessões (`service_packages`): compra cria direito da cliente, sessões em atendimentos separados, validade, saldo, histórico; pacote cancelado ou vencido nunca volta a ficar ativo | pronto (antigo e atual) · parcial, sem teste que salve (atual) | `/catalogo/pacotes` | R4 B spec 08:117-126; R5 B scope-master:64; R2 A regras-de-produto #4; R3 B audit:26 |
| CAT-09 | Combos (`service_bundles`): 2 ou mais serviços diferentes no mesmo agendamento, preço alocado por item fechando com o preço do combo, "Ratear", economia e duração; Ativo, Inativo, Arquivado; duplicar cria inativo | pronto (antigo) · pronto (atual) | `/catalogo/combos` | R4 B catalog-02:42-46; R4 B spec 08:82-115; R2 B STATUS:30 |
| CAT-10 | Combos na agenda e na comanda: seleção separada de serviços, expande em itens com origem, preço e duração; polimento pendente | parcial (antigo) | agenda, comanda | R5 B implementation-gap-map:43,90-103; R5 B 502 (CAT-02B, 14bd1b0) |
| CAT-11 | Planos de assinatura (`subscription_plans`): mensal, trimestral ou anual, sessões por período, preço do período, valor por sessão, serviços incluídos (nenhum marcado = todos); Ativo e Inativo ("Colocar à venda") | pronto (antigo) · parcial, sem teste (atual); recorrência e operação comercial não iniciadas | `/catalogo/planos` | R4 B catalog-02:48-51; R5 B scope-master:65; R5 B archive/dev-scope:68-80 |
| CAT-12 | Membership com cobrança recorrente real: benefícios por ciclo, estado de cobrança separado do consumo, falha de cobrança não apaga histórico | planejado (antigo) | — | R4 B spec 08:128-134,171-176 |
| CAT-13 | Produtos: marca, SKU, categoria, estoque com mínimo, custo, margem e lucro, preço, estado; visões Todos, Ativos, Estoque baixo, Sem estoque, Inativos; aviso de reposição | pronto (antigo) · pronto (atual) | `/catalogo/produtos` | R4 B catalog-02:29-37; R5 B scope-master:63; R3 B audit:26 |
| CAT-14 | Estoque só muda por movimento (Entrada soma, Saída recusa abaixo de zero, Ajuste define o total); só gerente; auditado; últimos 30 lançamentos; estoque inicial na criação | pronto (antigo) | editor do produto (`StockPanel`) | R4 B catalog-02:34-39 |
| CAT-15 | Excluir produto com vendas ou lançamentos arquiva em vez de apagar; duplicar; ativar e desativar | pronto (antigo) | menu da linha | R4 B catalog-02:39-40 |
| CAT-16 | Seções do Catálogo (Serviços, Pacotes, Produtos, Combos, Planos) com painel lateral e contagem no computador, controle segmentado no celular; sem selo "Anterior"; redirecionamento 308 de `/anterior/catalogo` | pronto (antigo) · atual: CMP-A1 troca o painel por trilho na barra | `/catalogo/*` | R4 B spec 28-navegacao-marketing-ajustes:10,22; R4 B catalog-02:7-27; R1 A CMP-A1 |
| CAT-17 | Cada seção tem busca, filtros, visões, colunas, exportar CSV, menu da linha e Novo; editor lateral no computador e tela cheia no celular | pronto para Produtos, Combos e Planos (antigo) | `/catalogo/*` | R4 B catalog-02:21-27,62-70 |
| CAT-18 | Busca, filtros e ordenação, ordem de categorias e itens, duplicar serviço, link rápido de reserva, arquivar separado de desativar | planejado ("ausente" para serviços, antigo) | `/catalogo` | R4 B spec 08:48-52,109-115; R5 A roadmap:138-143 |
| CAT-19 | Exclusão permanente protegida (só sem referências, com confirmação forte, auditada) | parcial (antigo) · atual: categoria não se apaga; pacote e plano só desativam | `/catalogo` | R4 B spec 08:53,111-115,159-160; R3 B audit:26 |
| CAT-20 | Locais e recursos (sala, equipamento) obrigatórios por serviço; horários e dias de reserva online; capacidade simultânea | planejado (antigo; recursos adiados) | editor do serviço | R4 B spec 08:54-55,72-80; R5 B scope-master:67; R5 B archive/dev-scope:68-80 |
| CAT-21 | Adicionais (add-ons) e imagens do serviço | planejado (antigo) · referência Booksy | editor do serviço | R4 B spec 08:56-57; R5 B product-vision-detail:53-54 |
| CAT-22 | Preço e duração por profissional ou por local; formulários múltiplos por serviço | planejado/parcial (antigo: existe um modelo padrão) | editor do serviço | R4 B spec 08:58-59; R5 B roadmap:138-143 |
| CAT-23 | Vender combo ou plano numa comanda (hoje o checkout aceita SERVICE, PRODUCT e PACKAGE); por isso Combos e Planos não têm contagem de vendas | planejado (antigo) | comanda | R4 B catalog-02:57-60; R1 D (mapa de módulos) |
| CAT-24 | Importação em lote de produtos e planos (item "Em breve" no menu Opções) | planejado (antigo) | Opções | R4 B catalog-02:57-60 |
| CAT-25 | Cor por categoria do Catálogo | planejado, lacuna sem decisão (atual) | categorias | R1 B rv:93; R3 B padrao:174; R1 D rv:93 |
| CAT-26 | Catálogo real da Karenn (PDF de 9 páginas): o seed não bate com o PDF (faltam Neutralización e Revitalización labial, Diseño de cejas em 4 variantes, depilação com linha, microneedling, laser; preços divergem em Dermaplaning e Laminado) | aberto (P0 de 30/10) · conferir na virada | seed, Catálogo | R5 B revisao-30-10:17; R5 B 535 |
| CAT-27 | Descrição do serviço por IA (Gemini Flash-Lite, chave só no servidor) | pronto (antigo) | editor do serviço | R5 B archive/dev-scope:68-80; R4 B spec 08:171-176 |
| CAT-28 | Comissão por serviço e impostos (comissão também no cadastro da equipe) | parcial (antigo) | editor do serviço | R5 B scope-master:68; R4 B spec 07:12 |
| CAT-29 | Margem bruta por item vendido | parcial (antigo) | relatórios | R5 B scope-master:83 |
| CAT-30 | Referência de mercado: add-ons, combos, variantes, tempo de preparo e processamento, mensagem e perguntas à cliente (Booksy); Menu e destaque (Treatwell); serviço no print do Fresha (Locais, Colaboradores, Recursos, Adicionais, Agendamento online, Imagens, Formulários, Comissões) | referência (sem decisão); prioridade proposta no antigo: tipo de preço, colaboradores, formulários, comissões | — | R3 B M/booksy:170-181, M/treatwell:148-150; R5 B product-vision-detail:53-54, 483 |
| CAT-31 | Testes `catalogo-v25` pulados desde a migração; E2E em `e2e/catalogo-v25.spec.ts` | pendência | — | R3 B vit:11, audit:44; R4 B catalog-02:71 |

"Estado" é o que os documentos dizem; o código é conferido quando o módulo entra em trabalho. Conferido só para "Onde": as rotas `catalogo` (índice, pacotes, produtos, combos, planos) e as pastas `_services`, `_packages`, `_bundles`, `_plans`, `_products` existem.

## Decisões
| ID | Decisão | Situação | Origem |
|---|---|---|---|
| CAT-D01 | Retoque incluído no procedimento com prazo; dispensa pede motivo; atalhos +2, +4, +6 semanas e +3 meses (G7) | **sugestão a confirmar** (05/11, aceite em lote) | R1 A G7 (reg:123) |
| CAT-D02 | Pacote cancelado ou vencido nunca volta a ficar ativo (travado no banco) | **sugestão a confirmar** (só data 14/11, sem frase) · regras-de-produto #4 | R2 A regras-de-produto #4 (history.md:69) |
| CAT-D03 | Bundle (serviços juntos), pacote de sessões e membership são entidades separadas; `service_packages` mantém a semântica de pacote de sessões até migration explícita | **sugestão a confirmar** (12/06/2026, "anexos do responsável", sem frase) | R4 A spec 08:3-5,14-24,125-126 |
| CAT-D04 | Combo: soma de preço alocado × quantidade fecha com o preço do combo; ao menos 2 serviços diferentes; ordem dos itens guardada; nome e valor históricos preservados na venda | **sugestão a confirmar** (sem prova) | R4 A spec 08:84-92; catalog-02:42-46 |
| CAT-D05 | Estoque só muda por movimento, nunca pelo formulário do produto; excluir produto com histórico arquiva | **sugestão a confirmar** (sem prova) | R4 A catalog-02:34-40 |
| CAT-D06 | Serviço sem duração (0) nunca é reservado online e ocupa 15 min | **sugestão a confirmar** (sem prova) | R4 A catalog-01:22-25 |
| CAT-D07 | Sinal por serviço: o valor fixo nunca passa do preço; "Pedir sinal" liga sozinho e a pessoa pode desligar | **sugestão a confirmar** (sem prova) | R4 A catalog-01:14-18 |
| CAT-D08 | Planos: editar um plano inativo não o reativa (o editor sempre envia `active`) | **sugestão a confirmar** (sem prova) | R4 B catalog-02:51 |
| CAT-D09 | Serviço inativo não aparece na Agenda nem no Checkout; reserva online só disponibiliza no portal; buffer invisível à cliente | **sugestão a confirmar** (spec 07, sem prova) | R4 B spec 07:34-38 |
| CAT-D10 | Segunda coluna sai do Catálogo; as seções viram trilho na barra | **sugestão a confirmar** (19/11, ficha, sem frase) · CMP-A1 | R1 A CMP-A1 (reg:249) |
| CAT-D11 | Cor por categoria: sem decisão (lacuna do design system, vai na ficha da própria tela) | **sugestão a confirmar** (nunca decidida) | R1 D rv:93; R3 B padrao:174 |
| CAT-D12 | Permissões: só `catalogo.manage` altera; categorias e serviços só por owner, admin e manager | **sugestão a confirmar** (sem prova) | R4 B catalog-02:53-55; R4 B spec 07:40-42 |

Regra: só vale decisão registrada em `docs/decisoes/` (molde de pergunta). Tudo desta tabela é **a confirmar**; a situação antiga fica entre parênteses só como histórico e volta a ser perguntada quando o módulo for trabalhado (resposta 15a do dono, 24/11/2026).

## Regras de negócio
- Toda tabela do catálogo tem `org_id` e RLS; ver o catálogo é para qualquer membro do estúdio, alterar é só de quem tem `catalogo.manage`.
- Estoque nunca muda sem movimento (entrada, saída ou ajuste), e saída nunca deixa abaixo de zero.
- Produto com venda ou lançamento de estoque não se apaga; arquiva.
- Serviço inativo não aparece na Agenda nem no Checkout.
- Venda e agendamento guardam cópia do nome, ordem e valor dos itens; arquivar serviço não estraga combos nem atendimentos antigos.
- Combo é gravado numa transação só (combo e itens); duplicar cria novos itens, sem compartilhar nada.
- Combo: a soma dos preços alocados fecha com o preço do combo.
- Serviço sem duração não é reservado online.
- Preço de tipo "gratuito" é sempre 0; o valor gravado e o mostrado não divergem.
- Pacote cancelado ou vencido nunca volta a ficar ativo.
- Excluir de vez só sem referências, com confirmação forte e auditoria.
- Descrição por IA: a chave fica só no servidor.

## Pendências e perguntas
| Pergunta ou pendência | Origem |
|---|---|
| Cor por categoria do Catálogo: qual regra? (lacuna) | R1 D rv:93; R3 B padrao:174 |
| Painel lateral ou trilho nas seções do Catálogo (CMP-A1 contra o PGuia/V25 de 248 px) | consolidado §4 item 16; R1 F-28, F-31 |
| Conferir o catálogo real da Karenn (PDF) contra o seed antes da virada | R5 B revisao-30-10:17; consolidado §3 |
| Pacotes, combos e planos sem teste que salve; categoria não se apaga; testes `catalogo-v25` pulados | R3 B audit:26,44; vit:11 |
| Vender combo ou plano na comanda: entra? Hoje o checkout só aceita serviço, produto e pacote | R4 D catalog-02:57-60 |
| Importação em lote de produtos e planos | R4 D catalog-02:57-60 |
| Modelo de receita do pacote e entrevistas com clientes | R5 D ecossistema:67-69 |
| Aviso de erro das telas usa `window.alert` em 9 telas (vale para Catálogo) | R2 D ICEBOX:35 |
| Hotfix de status com acento quebrado (`ConcluÃ­do`) da migration `20260616220600_appointment_bundle_origin` no antigo: conferir que não veio para o atual | R5 B 502 (CAT-02B) |
| Preço e duração por profissional ou local, adicionais, imagens, locais e recursos: entram? em que ordem? | R4 B spec 08:48-59; R5 B product-vision-detail:53-54 |
| Marketplace e cobrança recorrente real de membership ficaram fora do escopo imediato | R4 B spec 08:171-176 |
| Mockups com preços de plano (29, 59, 99 €) e catálogo de exemplo precisam de confirmação | R1 D (Main.dc.html; canvas.json) |

## Referências
- Specs do legado: `docs/produto/legado/specs/07-catalog-services-products.md`, `08-packages-memberships.md`, `catalog-01-regras-por-servico.md`, `catalog-02-produtos-combos-planos.md`, `28-navegacao-marketing-ajustes.md`, `35-appointment-item-duration.md`.
- Produto do legado: `docs/produto/legado/produto/scope-master.md`, `roadmap.md`, `revisao-30-10.md`, `product-vision-detail.md`.
- Fresha (links do spec 08): bundles, disponibilidade, adicionais, arquivar e excluir (`fresha.com/help-center/knowledge-base/catalog/...`).
- Catálogo real: `docs/catalogo-karenn.pdf` (antigo).
- ADR: `docs/adr/2026-11-19-regras-de-produto.md` (#4).
- Módulos ligados: Anamnese (ANA, modelo por serviço), Comanda/Checkout (COM), Estoque/Compras, Agenda e Reserva online.
