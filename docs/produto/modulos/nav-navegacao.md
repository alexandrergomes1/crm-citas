# Módulo: Navegação e Shell (NAV)

> O "casco" do app: menu lateral, barra de cima, barra de baixo do celular, tela "Mais", buscar e criar de qualquer lugar, fechar e voltar. Também guarda o mapa de todas as telas do app e de qual módulo cada uma é.
> Vale o que o dono respondeu a uma pergunta ou pediu com as próprias palavras (regra de 23/11, abaixo); o resto está como **sugestão a confirmar**.

**Telas e rotas:** `/{org}` (casco de todo o estúdio), `/{org}/mais`, `/{org}/$` (módulo ainda não trazido) · **Código:** `src/app-shell/` (menu, barra, busca, atalhos), `src/lib/nav/`, `src/domain/screen-origin.ts`, `src/domain/access.ts` · **Spec(s):** sem spec no atual. No legado: `docs/produto/legado/specs/02-app-shell-mobile-first.md`, `28-navegacao-marketing-ajustes.md`, `42-padrao-de-interface.md`, `46-padrao-fresha-aprovado.md` (final). Decisões atuais no registro de design: CMP-A1 a A4, CAM6-04, AG16, AG20, AG21.

## Recursos
| ID | Recurso | Estado | Onde | Origem |
|---|---|---|---|---|
| NAV-01 | Menu lateral: estreito (84 px, ícone e nome curto) de 1024 a 1439 px; aberto (240 px) a partir de 1440; dá para recolher | pronto (atual: regras-vigentes ✅) · V25: trilho 84 px pronto · spec 02 do antigo: 240 px fixo a partir de 1280, "colapsável fora do escopo" | `src/app-shell/Sidebar.tsx`, `SidebarContext.tsx` | CAM6-04 (reg:229); regras-vigentes:64; R4 B spec 02:30-34,89-93; R5 B v25-implementacao:72-84 |
| NAV-02 | Itens do menu e sua ordem: Agenda, Clientes, Catálogo, Anamnese, Financeiro, Marketing e, no rodapé, Ajustes; seções "Principal", "Operação" e "Crescimento" | pronto (código) | `src/app-shell/nav-config.ts:28-43` | R1 B rv:64; `nav-config.ts` ("Navegação do quadro aprovado V25") |
| NAV-03 | O item some se o módulo está desligado no plano ou se a pessoa não tem permissão (só esconde; quem barra de verdade é o banco) | pronto (código) | `visibleNav` em `nav-config.ts`; `NavAccessContext.tsx` | R4 B spec 28-nav:9; R4 B spec 29; `nav-config.ts` |
| NAV-04 | Barra inferior do celular: 4 atalhos e "Mais" (76 px mais a área segura; alvo de 44 px; nunca cobre o conteúdo) | pronto (atual) · planejado (spec 02: até 5 itens) · V25 pronto | `src/app-shell/TabBar.tsx`, `MobileTabsContext.tsx` | R5 B v25-implementacao:72-84; R4 B spec 02:30-34; R4 B spec 31 (atalhos escolhidos pela pessoa) |
| NAV-05 | Tela "Mais" do celular: Estúdio, nome da pessoa, atalhos, grupos de módulos com uma linha de descrição, Ajustes e Sair (por POST) | pronto | `/{org}/mais`; `src/app-shell/MoreMenu.tsx` | R1 B (V25 NavegacaoMais); `routes/$orgSlug/mais.tsx` |
| NAV-06 | Barra de cima no computador: caminho da tela, busca global ⌘K, ajuda, avisos, botão "Novo" | pronto (código; V25: 56 px) | `src/app-shell/TopBar.tsx` | R5 B v25-implementacao:72-84 |
| NAV-07 | Avisos do sistema num sininho no topo (G2) | planejado: o ícone existe na barra, sem avisos reais; "entra como item para depois" | `TopBar.tsx` (ícone `Bell`) | reg:118 (G2); R3 B fase1:114 |
| NAV-08 | Busca global ⌘K: clientes e serviços do estúdio, ações de criar e atalhos para os módulos | pronto | `src/app-shell/GlobalSearch.tsx`, `search-actions.ts` | AG16 (reg:55); `GlobalSearch.tsx` |
| NAV-09 | Botão "Novo": Agendamento, Cliente, Serviço, Venda avulsa, Pacote, com atalhos de teclado e abrindo o formulário pela URL | pronto | `src/app-shell/NewMenu.tsx`, `nav-config.ts` (`CREATE_ACTIONS`) | R1 B (V25 Navegacao · Botão Novo) |
| NAV-10 | Fechar e voltar em toda tela do celular: topo fixo com ‹ e X de 44 px; só a Agenda (a "casa") fica sem X | pronto (atual: X de 44 px) · pronto (antigo spec 28 `[x]` 19) | `src/design-system/MobileHeader`; `ScreenOrigin.tsx` | R4 B spec 28-nav:7,19; R1 B v26; v26-mobile-ux:7-11 |
| NAV-11 | ‹ dá um passo na hierarquia; X fecha o fluxo todo e volta à última tela raiz visitada; com alteração não salva pergunta "Descartar alterações?" | pronto (antigo) · não declarado (atual) | `src/domain/screen-origin.ts`, `ScreenOrigin.tsx`, `design-system/SaveBar/leave-guard` | R4 B spec 46:132-141 |
| NAV-12 | Voltar, Fechar e Cancelar têm sentidos separados (Voltar retorna; Fechar fecha sem cancelar; Cancelar só subação ou destrutivo); em janela que não é sequência: ✕ no topo e "Cancelar" embaixo | pronto (antigo V3, reaparece em outros documentos) · a definir (atual: proposta E11) | peças de janela | R5 B legacy design-v3 ui-rules:63-77; fechar-ds E10, E11 |
| NAV-13 | Preservar contexto: Voltar leva ao ponto de onde a pessoa veio (comanda › ficha profissional › comanda; cliente › nova reserva mantendo a cliente) | parcial (antigo: "retorno contextual pronto") | `?de=agenda` no checkout; `screen-origin` | R5 B agenda-operational-scope:393-413; roadmap:157 |
| NAV-14 | Ajustes reúne a Equipe (Profissionais, Acessos, Perfis e liberações); "Equipe" sai do menu; os endereços antigos `/equipe*` levam para Ajustes | pronto | `/{org}/configuracoes/equipe`, `/acessos`, `/perfis`; `routes/$orgSlug/equipe/*` (redirecionam) | R4 B spec 28-nav:8,20 |
| NAV-15 | Marketing num menu só: Mensagens, Campanhas, Avaliações e Fidelidade; `/marketing` abre a primeira área liberada; "Mensagens" e "Fidelidade" acendem o item Marketing | pronto | `routes/$orgSlug/marketing/index.tsx`; `activeNavHref` | R4 B spec 28-nav:6-13 |
| NAV-16 | Catálogo com Serviços, Pacotes, Produtos, Combos e Planos; o endereço antigo `/anterior/catalogo` redireciona | pronto | `/{org}/catalogo/*`; `routes/$orgSlug/anterior/catalogo*.tsx` | R4 B spec 28-nav:13 |
| NAV-17 | Checkout aberto a partir da Agenda não muda de módulo: o menu mantém Agenda acesa e o ‹ volta ao dia; `/checkout` leva à lista de Checkouts do Financeiro | pronto (código) · proposta (spec 42 do antigo §9) | `activeNavHref`; `routes/$orgSlug/checkout/*` | R4 B spec 42:§9; `nav-config.ts` |
| NAV-18 | Sem segunda coluna ao lado do conteúdo: Equipe vira botão "Profissionais" na barra, Status vai para Filtros, seções do Catálogo viram trilho na barra | pronto na Agenda (PR #80) · ⚠️ falta em Clientes e Catálogo · V25 mantinha painel de 248 px (≥1280) | Agenda, Clientes, Catálogo | CMP-A1 (reg:249); regras-vigentes:73; R1 A.8 PGuia |
| NAV-19 | Menu de seções (Ajustes, Perfil, Editar cliente): ícone à esquerda e › no fim, sempre, no computador e no celular | planejado / parcial (Ajustes) | Ajustes, Perfil | CMP-A2 (reg:250) |
| NAV-20 | Barra das listas: busca à esquerda; à direita, nesta ordem, visão ▾, Filtros (funil), ⋮ e o botão dourado | parcial | Clientes, Catálogo e outras listas | CMP-A3 (reg:251); regras-vigentes:74 |
| NAV-21 | Barra da Agenda: ‹ Hoje ›, data, botão de visão; à direita Profissionais, Lista de espera, Filtros, ⋮, Novo agendamento; sem lupa no computador (busca só no topo); celular com botão "Agenda" | pronto | Agenda | AG16, AG20, AG21, CMP-A4 (reg:55-60, 252); regras-vigentes:75 |
| NAV-22 | A tela inicial é o dia da Agenda: `/{org}` redireciona; o V25 não tem tela "Início" | pronto (código) · planejado (V25 Main: "Início" como primeiro item do menu quando a Agenda for aprovada) | `routes/$orgSlug/index.tsx`; `HOME_HREF` | R1 A.8 Main; `nav-config.ts` |
| NAV-23 | Tela inicial por aparelho e visão padrão (Preferências da pessoa); `/` manda para ela, ou para o login | pronto | Ajustes › Preferências; `routes/index.tsx` | R4 B spec 31; `routes/index.tsx` |
| NAV-24 | Trocar de estúdio na barra de cima (a pessoa que pertence a mais de um estúdio) | planejado (spec 02 do antigo: "org switcher"); sem tela no atual | `src/app-shell/TopBar.tsx` (não tem) | R4 B spec 02:30-34 |
| NAV-25 | Caminho da tela (breadcrumb) na barra de cima | planejado (spec 02) · mostrado na barra no atual | `TopBar.tsx` | R4 B spec 02:30-34; `TopBar.tsx` |
| NAV-26 | Esc fecha qualquer janela ou folha | planejado (spec 02) · pronto (atual, camada 9) | peças do DS | R4 B spec 02:30-34; CAM9-03 (reg:242) |
| NAV-27 | Menus e submenus no celular: um modelo só (folha de baixo com título; submenu troca o conteúdo da mesma folha, com ‹) | planejado: hoje 6 jeitos de abrir menu (proposta M1) | todas as telas | fechar-ds M1, M2 |
| NAV-28 | Padrão de interface do antigo (spec 42): ☰ navegação do módulo, ⋮ ações do objeto, + criar, lupa, funil com contador, pessoas com `n/total`; botão flutuante só na Agenda; painéis em tela cheia; Semana em grade ou lista | planejado, proposta (antigo) · substituído em parte por CMP-A3 e CMP-A4 | — | R4 B spec 42:14-73; R4 A spec 42 |
| NAV-29 | Botão flutuante "+" no celular | proposta: peça `Fab` existe; "+" flutuante dourado ou preto é pergunta C2 | `src/design-system/Fab` | R4 B spec 42:§4; fechar-ds C2 |
| NAV-30 | Telas fora do casco (login, páginas públicas, modo estúdio) não mostram menu | pronto | `src/routes/login.tsx`, `forms.$token.index.tsx`, `pagar.$token.tsx`, `$orgSlug_.anamnese-tablet.tsx` | R2 C70; R4 B spec 12 |
| NAV-31 | Tela "Módulo em migração" para endereço que ainda não existe (rota coringa) | parcial: o texto diz que só Clientes, Agenda e Anamnese foram trazidos (desatualizado) | `routes/$orgSlug/$.tsx`; `ComingSoonPage.tsx` | R3 B audit:32 |
| NAV-32 | Erro do banco ao carregar o estúdio manda ao login sem aviso | parcial ⚠️ | `routes/$orgSlug.tsx` (`errorComponent`) | R3 B audit:32 |
| NAV-33 | Telas que faltam desenhar: Entrar e acesso, Equipe básica, Ajustes do estúdio, Importação da Fresha, Recibo, Mensagens manuais | planejado | — | reg:176; R2 B ICEBOX:24; ROADMAP:12 |
| NAV-34 | Mensagens na barra inferior no lugar de Catálogo? (hoje está em "Mais") | a definir (sem resposta) | `TabBar.tsx` | R1 A.8 Main; R1 D |
| NAV-35 | Módulos ainda sem tela no V25 ("Documentado"): Início, Equipe, Reserva online com sinal, Fidelidade, Relatórios e DRE, estoque e compras, galeria antes e depois, Privacidade | planejado (parte já existe em outras telas) | — | R1 A.8 Main |
| NAV-36 | Subnavegação de módulo lateral (mockup `app-shell-premium-options`; V3) | descartado: contradiz CMP-A1; V3 aposentado | `docs/design/mockups/` | R1 A.7; R5 A V3 app-shell-navigation-standard |
| NAV-37 | Seção "Privacidade" dentro de Ajustes | parcial: existe como seção no código e não aparece no menu | `src/workspace/ajustes/sections.ts` | R3 B audit:30 |
| NAV-38 | Marcador de versão no rodapé do menu e da tela Mais (prévia, build) | pronto | `src/app-shell/BuildStamp.tsx` | `MoreMenu.tsx` |
| NAV-39 | Critério de aceite do fluxo inteiro no celular: serviço → profissional → cliente → agendar → conferir agenda (grade e lista) → editar e remarcar → confirmar e chegada → ficha → iniciar → concluir → cobrar → estornar ou cancelar → voltar; X em toda folha, uma ação principal, 44 px, sem texto cortado, sem rolagem lateral, barra inferior sem cobrir conteúdo | a definir (antigo: "decidido", sem prova) | celular | R5 B v26-mobile-ux:65-71 |

"Estado" é o que os documentos dizem; o código é conferido quando o módulo entra em trabalho.

## Mapa de telas (todas as rotas de `src/routes`)
`{org}` = o estúdio na URL. "Redireciona" = o endereço só leva para outra tela (links antigos). São 63 arquivos em `src/routes` (62 telas e endereços, mais a raiz `__root.tsx`); o módulo é o do `docs/reorganizacao/02-mapa-de-modulos.md`.

### Acesso e páginas públicas (fora do casco)
| Endereço | Arquivo em `src/routes/` | Módulo | O que é |
|---|---|---|---|
| (toda página) | `__root.tsx` | Navegação | Raiz do app: documento HTML, fontes, estilos e aparência do aparelho antes da pintura |
| `/` | `index.tsx` | Plataforma | Raiz: manda para a tela inicial da pessoa, ou para o login |
| `/login` | `login.tsx` | Plataforma | Entrar (e-mail e senha, em 2 etapas) |
| `/logout` | `logout.ts` | Plataforma | Sair (só POST) |
| `/reset-password` | `reset-password.tsx` | Plataforma | Esqueci / criar senha pelo link |
| `/trocar-senha` | `trocar-senha.tsx` | Plataforma | Primeiro acesso com senha provisória |
| `/forms/{token}` | `forms.$token.index.tsx` | Anamnese (página pública; no mapa de módulos: Reserva online/Site) | A cliente preenche e assina o formulário pelo link |
| `/forms/{token}/calendar` | `forms.$token.calendar.ts` | Anamnese (idem) | "Adicionar ao calendário" da ficha (só GET) |
| `/pagar/{token}` | `pagar.$token.tsx` | Cobranças | A cliente paga ou envia o comprovante pelo link |
| `/api/webhooks/whatsapp` | `api/webhooks/whatsapp.ts` | Mensagens | Avisos de entrega do WhatsApp oficial (assinatura da Meta) |
| `/{org}/anamnese-tablet` | `$orgSlug_.anamnese-tablet.tsx` | Anamnese | Modo estúdio (aparelho do estúdio, com PIN), tela cheia |

### Casco do estúdio
| Endereço | Arquivo em `src/routes/` | Módulo | O que é |
|---|---|---|---|
| (todo `/{org}/...`) | `$orgSlug.tsx` | Navegação | Casco: estúdio, papel, módulos, menu, barra; carrega uma vez |
| `/{org}` | `$orgSlug/index.tsx` | Navegação | Redireciona para a Agenda |
| `/{org}/mais` | `$orgSlug/mais.tsx` | Navegação | Tela "Mais" do celular |
| `/{org}/{qualquer coisa}` | `$orgSlug/$.tsx` | Navegação | "Módulo em migração" para endereço que não existe |
| `/{org}/anterior/catalogo` | `$orgSlug/anterior/catalogo.tsx` | Navegação (Catálogo) | Redireciona para o Catálogo (links antigos) |
| `/{org}/anterior/catalogo/...` | `$orgSlug/anterior/catalogo/$.tsx` | Navegação (Catálogo) | Redireciona para Serviços |

### Agenda e Agendamento
| Endereço | Arquivo em `src/routes/` | Módulo | O que é |
|---|---|---|---|
| `/{org}/agenda` | `$orgSlug/agenda.tsx` | Agenda | Agenda; o agendamento aberto e o novo agendamento abrem nela (`?ag=`, `?novo=1`) |

### Clientes
| Endereço | Arquivo em `src/routes/` | Módulo | O que é |
|---|---|---|---|
| `/{org}/clientes` | `$orgSlug/clientes/index.tsx` | Clientes | Lista de clientes |
| `/{org}/clientes/{id}` | `$orgSlug/clientes/$clientId.tsx` | Clientes | Perfil da cliente |

### Catálogo (e estoque)
| Endereço | Arquivo em `src/routes/` | Módulo | O que é |
|---|---|---|---|
| (casco do Catálogo) | `$orgSlug/catalogo.tsx` | Catálogo | Um carregamento para as cinco abas |
| `/{org}/catalogo` | `$orgSlug/catalogo/index.tsx` | Catálogo | Serviços e categorias |
| `/{org}/catalogo/pacotes` | `$orgSlug/catalogo/pacotes.tsx` | Catálogo | Pacotes |
| `/{org}/catalogo/combos` | `$orgSlug/catalogo/combos.tsx` | Catálogo | Combos |
| `/{org}/catalogo/planos` | `$orgSlug/catalogo/planos.tsx` | Catálogo | Planos |
| `/{org}/catalogo/produtos` | `$orgSlug/catalogo/produtos.tsx` | Catálogo (Estoque/Compras) | Produtos e estoque |

### Anamnese
| Endereço | Arquivo em `src/routes/` | Módulo | O que é |
|---|---|---|---|
| `/{org}/anamnese` | `$orgSlug/anamnese/index.tsx` | Anamnese | Visão geral do mês |
| `/{org}/anamnese/fichas` | `$orgSlug/anamnese/fichas/index.tsx` | Anamnese | Lista de fichas |
| `/{org}/anamnese/fichas/{id}` | `$orgSlug/anamnese/fichas/$id.tsx` | Anamnese | Uma ficha |
| `/{org}/anamnese/modelos` | `$orgSlug/anamnese/modelos/index.tsx` | Anamnese | Lista de modelos |
| `/{org}/anamnese/modelos/{id}` | `$orgSlug/anamnese/modelos/$id.tsx` | Anamnese | Editor de modelo |
| `/{org}/anamnese/termos` | `$orgSlug/anamnese/termos.tsx` | Anamnese | Termos |

### Comanda/Checkout, Financeiro e Caixa
| Endereço | Arquivo em `src/routes/` | Módulo | O que é |
|---|---|---|---|
| `/{org}/checkout` | `$orgSlug/checkout/index.tsx` | Comanda/Checkout | Redireciona para a lista de Checkouts |
| `/{org}/checkout/nova` | `$orgSlug/checkout/nova.tsx` | Comanda/Checkout | Venda avulsa |
| `/{org}/checkout/{id}` | `$orgSlug/checkout/$id.tsx` | Comanda/Checkout | Comanda em tela cheia (Revisar, Pagar, Concluída) |
| `/{org}/financeiro` | `$orgSlug/financeiro/index.tsx` | Financeiro | Visão geral |
| `/{org}/financeiro/comandas` | `$orgSlug/financeiro/comandas/index.tsx` | Comanda/Checkout | Checkouts do mês |
| `/{org}/financeiro/comandas/nova` | `$orgSlug/financeiro/comandas/nova.tsx` | Comanda/Checkout | Redireciona para `/checkout/nova` |
| `/{org}/financeiro/comandas/{id}` | `$orgSlug/financeiro/comandas/$id.tsx` | Comanda/Checkout | Redireciona para `/checkout/{id}` |
| `/{org}/financeiro/caixa` | `$orgSlug/financeiro/caixa.tsx` | Caixa | Caixa: abrir, movimentos, fechar, histórico |
| `/{org}/financeiro/contas` | `$orgSlug/financeiro/contas.tsx` | Financeiro | Contas a pagar |
| `/{org}/financeiro/comissoes` | `$orgSlug/financeiro/comissoes.tsx` | Financeiro | Comissões do mês |
| `/{org}/financeiro/dre` | `$orgSlug/financeiro/dre.tsx` | Financeiro | DRE gerencial |
| `/{org}/financeiro/relatorios` | `$orgSlug/financeiro/relatorios.tsx` | Financeiro | Relatórios |
| `/{org}/financeiro/saldos` | `$orgSlug/financeiro/saldos.tsx` | Financeiro | Saldos das clientes |
| `/{org}/financeiro/vales` | `$orgSlug/financeiro/vales.tsx` | Financeiro (vale-presente também em Comanda/Checkout) | Vales-presente |

### Marketing, Mensagens e Fidelidade
| Endereço | Arquivo em `src/routes/` | Módulo | O que é |
|---|---|---|---|
| `/{org}/marketing` | `$orgSlug/marketing/index.tsx` | Marketing | Redireciona para a primeira área liberada |
| `/{org}/marketing/campanhas` | `$orgSlug/marketing/campanhas.tsx` | Marketing | Campanhas (sem envio real) |
| `/{org}/marketing/avaliacoes` | `$orgSlug/marketing/avaliacoes.tsx` | Marketing | Avaliações no Google |
| `/{org}/fidelidade` | `$orgSlug/fidelidade.tsx` | Fidelidade | Pontos, ranking e níveis |
| `/{org}/mensagens` | `$orgSlug/mensagens/index.tsx` | Mensagens | Conversas |
| `/{org}/mensagens/modelos` | `$orgSlug/mensagens/modelos/index.tsx` | Mensagens | Modelos |
| `/{org}/mensagens/modelos/{id}` | `$orgSlug/mensagens/modelos/$id.tsx` | Mensagens | Editor de modelo |
| `/{org}/mensagens/automacoes` | `$orgSlug/mensagens/automacoes.tsx` | Mensagens | Automações |
| `/{org}/mensagens/historico` | `$orgSlug/mensagens/historico.tsx` | Mensagens | Histórico |
| `/{org}/mensagens/canais` | `$orgSlug/mensagens/canais.tsx` | Mensagens | Canais (WhatsApp, e-mail) |

### Ajustes e Equipe
| Endereço | Arquivo em `src/routes/` | Módulo | O que é |
|---|---|---|---|
| `/{org}/configuracoes` | `$orgSlug/configuracoes/index.tsx` | Ajustes | Ajustes (`?secao=estudio`, `horario`, `atendimento`, `plano`, `pagamentos`, `dados`, `ficha`, `aparencia`, `preferencias`) |
| `/{org}/configuracoes/equipe` | `$orgSlug/configuracoes/equipe.tsx` | Equipe/Acessos | Profissionais |
| `/{org}/configuracoes/acessos` | `$orgSlug/configuracoes/acessos.tsx` | Equipe/Acessos | Acessos |
| `/{org}/configuracoes/perfis` | `$orgSlug/configuracoes/perfis.tsx` | Equipe/Acessos | Perfis e liberações |
| `/{org}/equipe` | `$orgSlug/equipe/index.tsx` | Equipe/Acessos | Redireciona para Ajustes › Profissionais |
| `/{org}/equipe/acessos` | `$orgSlug/equipe/acessos.tsx` | Equipe/Acessos | Redireciona para Ajustes › Acessos |
| `/{org}/equipe/perfis` | `$orgSlug/equipe/perfis.tsx` | Equipe/Acessos | Redireciona para Ajustes › Perfis |

Fora de `src/routes` (não é rota de tela): `src/routeTree.gen.ts` é gerado sozinho.

## Decisões
| ID | Decisão | Situação | Origem |
|---|---|---|---|
| NAV-D01 | O sistema é mobile first (menus, submenus, telas e subtelas, chips e abas pensados para o celular) | **a confirmar** (antes: vale) (pedido dele, frase própria: "O sistema tem de ser mobile first…", 23/11/2026, 12h58) | R3 A; falas-do-dono:85 |
| NAV-D02 | A lupa atual sai da barra da Agenda no computador; fica a busca global do topo; no celular a lupa precisa de prova no momento oportuno (AG16) | **a confirmar** (antes: vale) no computador (frase dele: "icone de lupa atual nas telas deve sair, vamos manter a busca global do topo no desktop", 20/11/2026, 19h24); a lupa do celular fica **a definir** (proposta E4) | reg:55; R1 A.1; fechar-ds E4 |
| NAV-D03 | Sem segunda coluna ao lado do conteúdo (CMP-A1): Equipe vira o botão "Profissionais"; Status vai para Filtros; seções do Catálogo viram trilho na barra | **sugestão a confirmar** (resposta em letra ao comparativo de 19/11; não há frase no repositório) | reg:249; R1 A.7, F-23 |
| NAV-D04 | Submenu sempre dentro, não ao lado (frase dele de 18/11: "definimos nao ter submenu lateral e sim dentro") contra o pedido de 05/11 ("exibissimo tbm o menu lateral e a tela ficasse dividida como o dele") | **sugestão a confirmar** (as duas falas são pedidos dele; não está claro se são o mesmo assunto: menu do app × submenu; proposta M2) | falas-do-dono:84,151,267; fechar-ds M2 |
| NAV-D05 | Menu lateral: estreito (84 px) de 1024 a 1439 e aberto (240 px) a partir de 1440, recolhível (CAM6-04, S4·A, ex-ORD-08) | **sugestão a confirmar** (a ficha de 15/11 atribui a ele "aberto com opção de recolher"; a Mesa de 16/11 recomendou 84 px; o registro não traz frase) | reg:229; R1 A.7 ORD-08, F-27 |
| NAV-D06 | Menu de seções: ícone à esquerda e › no fim, sempre, no computador e no celular (CMP-A2) | **sugestão a confirmar** (a IA recomendou "sem › no computador"; o registro diz o contrário, sem frase dele) | reg:250; R1 F-4 |
| NAV-D07 | Barra das listas: busca à esquerda e, à direita, visão ▾, Filtros (funil), ⋮ e botão dourado (CMP-A3) | **sugestão a confirmar** | reg:251; L-1111-08 (reg:192) |
| NAV-D08 | Barra da Agenda como no teste de 11/11, com os controles de AG20 (um ícone abre visão e altura das horas) e AG21·A (botão "Agenda" no celular) | **sugestão a confirmar** (AG20 e AG21: frases dele de 20/11 estão no registro; a barra "em texto" contesta o AG20 e a proposta E3 pergunta de novo) | reg:59-60, 252; R3 F-8; fechar-ds E2, E3 |
| NAV-D09 | Barra inferior do celular com atalhos e "Mais"; Mensagens em "Mais" | **sugestão a confirmar** (quadro V25 sem frase; V25 é histórico, G12) | R1 A.8 PGuia, Main; reg:128 |
| NAV-D10 | Fechar e voltar em toda tela do celular, com X de 44 px; ‹ dá um passo e X volta à tela raiz | **sugestão a confirmar** (feedback de 29/10 sem frase; spec 28 e spec 46 do antigo sem prova) | v26-mobile-ux:3-11; R4 A spec 28, 46 |
| NAV-D11 | Equipe, Acessos e Perfis dentro de Ajustes; Marketing em um menu só; Produtos e planos no Catálogo | **sugestão a confirmar** (spec 28 do antigo, "sem prova") | R4 A spec 28-nav |
| NAV-D12 | Ação que ainda não funciona fica visível e desligada, com "em desenvolvimento" (G9); exceção: "Excluir cliente" e "Agendamento em grupo" saem da tela | a regra G9 é **sugestão a confirmar** (frases de 05/11 e 08/11 citadas pela IA; aceite em lote); a exceção **a confirmar** (antes: vale) ("Saem da tela", 22/11/2026, 16h21) | reg:125; R1 A.1 |
| NAV-D13 | Sem permissão de editar clientes, as ações somem (AGS5) | **sugestão a confirmar** (aceite "Sim" a 8 sugestões, 23/11, 00h46; a camada 7 diz "não esconder"; proposta M9) | reg:104; fechar-ds M9 |
| NAV-D14 | Avisos do sistema num sininho no topo (G2), "entra como item para depois" | **sugestão a confirmar** (fala de 20/11 citada; gravada pelo "aceito todas") | reg:118 |
| NAV-D15 | Início do app: o dia da Agenda; não há tela "Início" | **sugestão a confirmar** (nota no código sobre o quadro V25; sem frase) | `nav-config.ts`; R1 A.8 Main |
| NAV-D16 | Checkout aberto da Agenda continua dentro da Agenda; "Comanda" passa a se chamar "Checkout" | o primeiro ponto é **sugestão a confirmar** (spec 42 do antigo, proposta sem aprovação); o nome "Comanda" ou "Checkout" é **a definir** (specs 09, 33 e 41 mantêm "Comanda") | R4 B spec 42; consolidado §4-23 |
| NAV-D17 | Padrão de interface do antigo (spec 42): ☰, ⋮, +, funil, equipe com contador, botão flutuante só na Agenda | **sugestão a confirmar** (proposta de 30/10 "para aprovação", sem aprovação registrada) | R4 A spec 42 |
| NAV-D18 | O nome do item de menu "Anamnese" passa a ser "Formulários" junto com a spec própria dos formulários | **a confirmar** (antes: vale) (resposta dele "Só o nome por enquanto", 19/11/2026, 10h43, à pergunta E2 escrita por inteiro: "o menu lateral 'Anamnese' passa a se chamar 'Formulários'… No agendamento fica 'Formulário pendente' e 'Abrir formulário'"; vale o nome nos textos; o menu "Formulários" com vários tipos fica para spec própria) | falas-do-dono:181; reg:262 |
| NAV-D19 | Telas do lançamento que faltam desenhar: Entrar e acesso, Equipe básica, Ajustes do estúdio, Importação, Recibo, Mensagens manuais | **sugestão a confirmar** (lista do registro; "falta") | reg:176 |
| NAV-D20 | Tela "Mais": atalhos escolhidos pela pessoa e tela inicial por aparelho | **a confirmar** (antes: vale) (pedido dele de 28/10/2026, frase citada na spec 31 do antigo: "customizar o perfil com itens fixos e visão padrão, seja no celular ou em outra visão"; igual à AJU-D10) | R4 A (Antigo) spec 31 |

Regra: só vale decisão registrada em `docs/decisoes/` (molde de pergunta). Tudo desta tabela é **a confirmar**; a situação antiga fica entre parênteses só como histórico e volta a ser perguntada quando o módulo for trabalhado (resposta 15a do dono, 24/11/2026).

## Regras de negócio
- O menu só mostra o que a pessoa pode usar (módulo ligado e permissão), mas esconder botão não é segurança: quem barra de verdade é o banco e cada função de servidor.
- A barra inferior do celular nunca cobre conteúdo (usa a área segura).
- Toda tela do celular, menos a Agenda, tem "Fechar e voltar"; nenhum painel no celular existe sem X visível de 44 px.
- Todo endereço antigo continua funcionando e só redireciona (equipe, anterior/catálogo, financeiro/comandas, `?tab=` do Financeiro).
- Link com `next` só aceita caminho interno do app (sem redirecionamento para fora).
- Páginas sem login (ficha, pagamento, senha, modo estúdio) não mostram o menu e não aparecem em buscadores.
- O botão "Novo" abre o formulário pela URL, então o atalho funciona de qualquer tela.
- Um botão principal por tela; só Agenda tem botão flutuante (proposta).
- Mudança de lugar ou nome de ação atualiza o inventário no mesmo PR.

## Pendências e perguntas
| Pergunta ou pendência | Origem |
|---|---|
| Painel do módulo e coluna lateral: CMP-A1 tirou a coluna; o V25 e o mockup propõem painel de 248 px ou subnavegação; Clientes e Catálogo ainda têm coluna | consolidado §4-16; R1 F-28, F-31; regras-vigentes:73 |
| Submenu ao lado ou dentro (M2) e menu único (M1) | fechar-ds M1, M2 |
| Mensagens entra na barra inferior no lugar de Catálogo? | R1 A.8 Main |
| Troca de estúdio na barra de cima: precisa existir antes de haver mais de um estúdio por pessoa? | R4 B spec 02 |
| "Comanda" ou "Checkout" no menu e nos textos? | consolidado §4-23 |
| Menu lateral: aberto por padrão (240) ou estreito (84)? A ficha de 15/11 usava 1536 px; o registro usa 1440 px | R1 F-27 |
| Ação sem função fica visível e desligada (G9) ou não aparece? Sem permissão some ou fica desativada? | consolidado §4-7; fechar-ds M9 |
| Sininho de avisos: quais avisos entram e onde ficam (G2) | reg:118 |
| Texto de "Módulo em migração" e o aviso de erro do banco precisam de texto novo | R3 B audit:32 |
| Telas que faltam desenhar (NAV-33) e módulos "documentados" sem tela (NAV-35) | reg:176; R1 A.8 Main |
| Lupa no celular: manter até haver teste ou tirar também (E4) | fechar-ds E4 |
| Gênero dos textos do menu e dos botões (feminino ou neutro) | consolidado §4-22 |
| Tabs e segmentos: que peça usar para trocar de seção (M5) | fechar-ds M5 |
| Auditoria v26 "não corrigido": selects Radix sem X, KeyboardInset, alvos de 40 px no perfil | v26-auditoria-fluxos:44-55 |
| Inventário de ações desatualizado (itens "em breve" que já saíram ou entraram) | R1 F-8 |

## Referências
- Spec 42 do antigo, partes de navegação: §1 a §7 aqui (NAV-28, NAV-29, NAV-D16, NAV-D17); §8 densidade e botões, §10 auditoria por ondas e §11 componentes (`ContextBar`, `ActionBar`, `MoreButton`, `Fab`) estão em DS-44 a DS-46.
- Legado: `docs/produto/legado/specs/02-app-shell-mobile-first.md`, `28-navegacao-marketing-ajustes.md`, `42-padrao-de-interface.md`, `45-layout-limpo.md`, `46-padrao-fresha-aprovado.md`, `31-user-preferences.md`; `docs/design/v25-implementacao.md`, `v25-mockups/` (PGuia, Main), `v26-mobile-ux.md`, `v26-auditoria-fluxos.md`.
- Atual: `docs/decisoes/historico/registro-ate-2026-11-24.md` (CMP-A1 a A4, CAM6, AG16, AG20, AG21, G2, G9), `docs/design/design-system/regras-vigentes.md` §7, `docs/design/inventario/agenda-e-agendamento.md`, `docs/specs/plans/2026-11-23-fechar-design-system.md` (M1 a M10, E1 a E12).
- Mockup contrário às decisões: `docs/design/mockups/app-shell-premium-options.html` (usa subnavegação e Tabler Icons; contradiz CMP-A1 e CAM8-02).
- Referências de mercado: `docs/fresha-prints-referencia/`, `docs/referencias-mercado/` (Fresha, Booksy, Treatwell).
- Levantamento: R1 A.7, A.8, B, F-4, F-27, F-28, F-31; R3 B audit:32; R4 B specs 02, 28, 42, 46; R5 B (Navegação/Shell).
