# DESIGN.md · design system do crm-citas

> **Aprovado pelo dono em 27/11/2026** (o design feito com ele nesse dia). Fonte única de aparência e comportamento
> das telas: toda tela segue só o que está aqui. Peça, cor, nome ou medida que não está aqui **não se usa**: entra
> aqui primeiro, com aprovação do dono. Escrito pelo Designer de produto; normas: WCAG 2.2, Material Design, Apple HIG.
> Imagens: `docs/design/imagens/`. **Se texto e imagem divergirem, vale este texto; a imagem é corrigida.** Canvas com todas as versões, para consulta: `docs/design/README.md`.
>
> **Comentário do dono para debater depois (27/11, não é decisão):** "nao gostei do botao branco e prefiro o preto
> em cada tela e o de agendar outra cor sem competir". Hoje vale o que está abaixo.

## 1. Hierarquia: três níveis de atenção

| Nível | O que é | Como aparece |
|---|---|---|
| 1 · O que fazer | a ação principal da tela | **preto cheio**, uma por tela |
| 2 · Onde estou e o que escolhi | navegação e seleção | discreto: trilho claro com o escolhido em branco; item atual do menu em fundo claro com o ícone azul ardósia |
| 3 · O conteúdo | informação | texto preto; detalhe em cinza; cor só para estado, sempre com ícone e palavra |

Se duas coisas da mesma tela disputam o olho, uma delas está no nível errado.

## 2. Camadas de profundidade (quatro)

1. **Fundo** `--page #ECEBE6`: atrás de tudo.
2. **Superfície** `--card #FFFFFF`: cabeçalho, blocos de conteúdo, menus, painéis, barras. O cabeçalho do celular é separado do conteúdo por uma sombra leve; no computador, a barra do topo por uma linha de 1 px.
3. **Controle** `--btn #F2F1ED`: botão claro, trilho do seletor, item atual do menu. **Controle nunca fica direto sobre o fundo**, sempre sobre uma superfície branca.
4. **Destaque**: só o escolhido (branco, um pouco acima, com sombra leve) e a ação (preta).

## 3. Cores (cada uma com um papel só)

| Token | Valor | Papel |
|---|---|---|
| `--page` | #ECEBE6 | fundo |
| `--card` | #FFFFFF | superfície |
| `--btn` / `--track` | #F2F1ED | controle claro e trilho do seletor |
| `--line` | #EAE9E4 | linha fina entre itens de uma lista |
| `--ink` | #16181D | texto principal, ação principal (inclusive o Agendar do celular), marcado (caixinha, interruptor) |
| `--ink2` | #4A4F57 | texto de apoio, rótulo de campo; número da pílula de contador |
| `--ink3` | #5E636B | detalhe, cabeçalho de tabela, quantidade, texto de exemplo no campo |
| `--field` | #8C9098 | contorno de campo (3,2:1) |
| `--id` | #3E5C76 | azul ardósia: **só onde estou** (ícone do menu atual, item atual da barra de baixo). Nunca botão, nunca contador |
| `--brand` | #7A5A22 | dourado: só a inicial da empresa |
| `--warn` / `--warnSoft` | #9A5B06 / #FBEFD9 | âmbar: pendente, reservado, aguardando · o claro também é o fundo da pílula de contador com pendência (número em #8A5205) |
| `--ok` / `--okInk` / `--okSoft` | #1F6B45 / #17583A / #E3F0E8 | verde: ícone (`--ok`) e texto (`--okInk`) de concluído, pago, em dia · o claro só como fundo de ícone |
| `--danger` / `--dangerSoft` | #B3261E / #FBEAE8 | vermelho: erro, ausência, bloqueio, excluir · o claro só como fundo do ícone de erro |
| `--c1`…`--c4` | #7D5A8C · #B0583A · #A07A2C · #5C7F6A | cor de categoria, na ordem em que as categorias foram criadas (a 5ª volta à 1ª): faixa de 4 px à esquerda da linha, sempre com o nome escrito (cabeçalho do grupo ou detalhe da linha) |

Contraste conferido: todo texto ≥ 4,5:1 sobre fundo, superfície e trilho; contorno de campo ≥ 3:1. Temas Barbearia e Essencial: mesmas regras, cores a definir com o dono.

## 4. Texto, espaços, formas, alturas

- **Fonte:** Geist. **Escala:** 20 forte (título da tela) · 18 forte (título de folha e janela) · 16 forte (título de bloco) · 15 (texto no celular) · 14 (texto e botão no computador) · 13 (detalhe, subtítulo, tabela do computador) · 12 (cabeçalho de tabela, etiqueta, número de contador) · 11 (mínimo: só barra de baixo, menu recolhido, hora da grade).
- **Espaços:** 4 · 8 · 12 · 16 · 20 · 24 · 32. Margem da tela 16 no celular e 24 no computador; entre blocos 12.
- **Formas:** tudo em pílula (botão, campo de uma linha, busca, chip, seletor, item de menu aberto, aviso). Exceções: bloco e menu aberto canto 20; campo de várias linhas canto 16; item do menu recolhido 16; janelinha 24; folha 28 no topo; quadrado da inicial 10; caixinha 7.
- **Alturas:** celular 44 (botão, campo, botão de ícone), linha de lista 64, barra de baixo 72, cabeçalho 64. Computador 40 (botão, busca, botão de ícone, item de menu), linha de tabela 40 com texto 13, barra do topo 64, menu aberto 232 e recolhido 84, submenu 216.
- **Toque:** 44 no celular e 40 no computador, mesmo quando o desenho é menor (área invisível).
- **Sombra:** só no que flutua (menu aberto, folha, painel, aviso), no escolhido do seletor e na borda do cabeçalho.

## 5. Controles (um desenho para cada tipo)

| Peça | Para quê | Computador | Celular | Nunca |
|---|---|---|---|---|
| Ação principal | o mais importante da tela | "+ Adicionar" preto na barra do topo (na Agenda, "Novo agendamento") | **Agendar**, preto, no meio da barra de baixo; em tela sem barra, o botão do rodapé (Checkout, Salvar); em tela sem menu, o botão preto do bloco (Entrar) | duas pretas na mesma tela |
| Adicionar no celular | criar o item da tela | — | "+ Adicionar" **com contorno** (1 px `--ink3`, fundo transparente), com nome, no topo da tela | preto (o preto do celular é o Agendar) ou cinza (cinza é ferramenta) |
| Ação secundária | outras ações da tela | "Opções ▾" claro | ⋮ no topo (nome "Opções") | outro nome para o mesmo menu |
| Botão de ícone | fechar, voltar, ⋮, ajuda, notificações, funil; mostrar/esconder senha, dentro do campo, à direita | sem fundo | sem fundo | fundo cinza em ícone universal |
| Ícone ou ícone + nome | — | ícone **e** nome em Filtros, Ordenar, Categoria, Modelo, modo de ver, Equipe e Lista de espera; **só nome** em Opções, Hoje e nas ações principais com texto | ícone sozinho só nos universais e no funil | ícone sozinho em ação que não é universal |
| ☰ e ⋮ | navegar × agir | ícone de painel abre e recolhe o menu | ☰ abre as visões da Agenda; ⋮ ações do objeto onde está | ação no ☰; navegação no ⋮ |
| Menu principal | trocar de módulo | coluna com ícone e nome; atual em fundo claro com ícone azul; recolhe para 84 px quando o módulo tem seções | barra de baixo: Agenda, Clientes, Agendar, Catálogo, Mais; atual em azul com ponto | preto no item atual |
| Seções | trocar de tela dentro do módulo | submenu ao lado, sem repetir o nome do módulo | lista de seções (nível 1) com ícone simples, nome, quantidade e ›; a seção é o nível 2 com ‹ | aba ou seletor |
| Seletor | uma entre poucas opções à vista: abas do painel; categorias no celular | trilho claro, escolhido branco | igual; se não cabe, rola com esmaecido na ponta | preto no escolhido; aba que some quando vazia |
| Aba vazia | nada a mostrar ainda | fica no lugar; estado vazio com "Adicionar <coisa>" | igual | esconder a aba; adicionar só pelo ⋮ |
| Categoria | agrupar a lista | botão "Categoria: Todas ▾" na barra da lista | o seletor | coluna lateral |
| Modo de ver | a mesma coisa de outro jeito | botão com ícone: "Dia ▾", "Mês ▾" | igual | várias opções expostas |
| Busca da tela | achar algo nesta tela | campo em pílula, primeiro item da barra | campo em pílula, com o funil ao lado | lupa sozinha (exceção: Agenda no celular) |
| Busca geral | achar qualquer coisa | "Buscar no sistema ⌘K" no topo | — | confundir com a busca da tela |
| Filtros | esconder o que não interessa | "Filtros ▾" com a pílula de contador dentro; abre painel à direita | funil sem fundo quando nenhum filtro está ligado; com filtro ligado, funil e pílula no mesmo botão claro; abre folha de baixo | filtro solto na tela; valores dos filtros escritos na tela |
| Ordenar | mudar a ordem | "Ordenar: <ordem atual> ▾" | primeira linha da folha de Filtros, escrita "Ordenar" com o valor à direita | "Ajustar ordem" (é mover à mão; fica em Opções) |
| Contador | quantos há ali | **pílula cinza suave** (fundo rgba(22,24,29,.07), número 12 `--ink2`) com o **total**; a mesma pílula em **âmbar suave** (`--warnSoft`, número #8A5205) quando há pendência dentro, e o número continua o total; no subtítulo, número e palavra ("4 pendentes"); igual nas seções, no seletor, nas abas, nas listas e nos botões | igual · sempre o total, mesmo em dia · zero não aparece | número solto sem pílula; número flutuando sobre ícone; pílula escura ou azul |
| Contador em botão de ícone | filtros ligados, avisos não lidos | o ícone e a pílula juntos no mesmo botão (funil + 2; sininho + 3 em âmbar suave, porque não lido pede atenção) | igual | número flutuando no canto do ícone |
| Etiqueta | marca da cliente ou item | ícone + palavra, sem fundo | igual | fundo colorido; cor fora de estado |
| Status | situação | botão "ícone + nome ▾" no agendamento; ícone + palavra nas listas | igual; no cartão pequeno da Agenda só o ícone (nome no leitor) | bolinha de cor |
| Topo | ajuda, notificações, sua conta | ajuda, sininho com a pílula ao lado e Sua conta, sempre | sininho e Sua conta só no topo do nível 1 de cada módulo; nas telas internas, ‹ voltar | contador preto ou azul |
| Ações de uma linha | editar, duplicar, arquivar, excluir | ⋮ no fim da linha | igual; as ações do agendamento ficam no ⋮ do topo do painel | ações da linha no topo da tela |
| Resumo de valores | totais no rodapé | "Total ▴ valor"; ▴ abre o detalhe | igual | valor repetido |

**Status do agendamento (ícones Lucide):** Reservado `clock` · Confirmado `thumbs-up` · Chegou `door-open` · Iniciado `play` · Concluído `circle-check` · Ausência `user-x` · Cancelado `circle-x` · Bloqueio de horário `lock`.
**Situação de formulário:** Aguardando a cliente `hourglass` (âmbar) · Bloqueia o checkout `shield-alert` (vermelho) · Concluída `circle-check` (verde).
**Etiquetas:** 1ª visita `user-plus` · VIP `crown` · Recorrente `repeat` · Retoque pendente `brush` (âmbar) · Alergia `circle-alert`.
**Senha:** Mostrar `eye` · Esconder `eye-off`. **Sua conta sem e-mail:** `user` (na bolinha, no lugar da inicial; E47·2·A). **Um ícone por coisa em todo o app**; o mapa de ícones entra aqui com aprovação do dono.

## 6. Nomes dos botões

| Nome | Quando | Nunca escrever |
|---|---|---|
| Adicionar | criar o item da lista que está na tela | Novo, Nova cliente, Criar, Cadastrar, Enviar formulário |
| Adicionar ▾ | o mesmo botão cria mais de um tipo (serviço ou produto no agendamento; receita ou despesa no Financeiro) | + Serviço, + Produto |
| Adicionar <coisa> | dentro de um estado vazio ou de uma aba: Adicionar nota | Nova nota, Criar |
| Novo agendamento · Agendar | Agenda (computador) · botão do meio da barra (celular) | Adicionar agendamento |
| Opções | menu de ações secundárias (importar, exportar, imprimir, ajustar ordem); no celular é o ⋮ | Ações, Menu |
| Ordenar: <ordem> | mudar a ordem | Classificar, Ajustar ordem |
| Filtros · Limpar filtros · Mostrar N <itens> | abrir, desligar e aplicar filtros | Filtrar, Aplicar, OK, Limpar |
| Buscar <coisa> | texto do campo | Pesquisar, Procurar |
| Categoria: Todas · Modelo: Todos | botão de categoria | Filtrar por… |
| Ver <coisa> · Dados ▾ | abrir o detalhe · abrir mais dados no próprio cartão | Abrir, Detalhes, Mais |
| Editar · Duplicar · Arquivar · Excluir | ⋮ da linha, nesta ordem; Excluir em vermelho e pede confirmação | Apagar, Remover, Copiar |
| Salvar · Cancelar · Fechar · Voltar | formulários (Cancelar desfaz e fecha); ✕ fecha e volta para onde estava; ‹ volta uma etapa | Gravar, Confirmar, Sair (no sentido de fechar), Retornar |
| Abrir o menu · Recolher menu | menu do computador | Expandir, Minimizar |
| Hoje · Equipe N de M · Lista de espera | atalhos da Agenda | Agora, Profissionais, Espera |
| Checkout · Pagar <valor> · Cancelar agendamento | agendamento e pagamento | Cobrar, Finalizar, Desmarcar |
| Mais | só o último item da barra de baixo | Menu, Outros |
| Ajuda · Notificações · Sua conta | topo | Suporte, Avisos, Perfil |
| Entrar | ação da tela Entrar | Login, Acessar |
| Entrando… | estado do botão Entrar enquanto envia | — |
| Sair | encerrar a sessão (Sua conta, Escolher empresa) | Logout, Desconectar |
| Mostrar senha · Esconder senha | botão do olho no campo Senha (nome no leitor) | — |
| E-mail · Senha | rótulos dos campos da tela Entrar | — |
| Escolher empresa · Entrar | títulos das telas sem menu | Escolher estúdio |
| Trocar de empresa | item do menu Sua conta (só com mais de uma empresa) | Trocar de estúdio |
| 1 empresa · N empresas | contador no subtítulo de Escolher empresa | estúdios |
| Carregando empresas · Não foi possível carregar | textos só para o leitor de tela (Escolher empresa) | — |
| "Não foi possível entrar. Confira o e-mail e a senha e tente de novo." | erro da tela Entrar | — |
| **Título da tela** | computador: na primeira seção do módulo, o nome do módulo; nas outras, o nome da seção. Celular: nível 1 (lista de seções) leva o nome do módulo; nível 2 leva sempre o nome da seção | "Visão geral" como título |

**Palavra para o negócio de quem usa o sistema (E47·1·A, termo escolhido pelo Designer por delegação do dono):**
**empresa** (pt) · **empresa** (es) · **business** (en; plural "businesses"). Vale em toda tela, aviso e mensagem; é
feminina em pt e es ("a empresa", "uma empresa"). Nunca escrever estúdio, clínica, salão, estabelecimento, conta (é a
da pessoa: Sua conta, Minha conta) nem workspace. "Unidade" fica livre para um local dentro da empresa, se vier.
Os nomes técnicos (`estudio`, `org_id`) não mudam. Motivo: o produto não é de um mercado só (pedido do dono);
"empresa" é a palavra comum do dono de pequeno negócio em pt e es e cabe no celular ("Trocar de empresa", 17
caracteres); "business" é a palavra simples do mesmo sentido em en, sem o jargão de "workspace" (Nielsen 2: falar a
língua de quem usa; Nielsen 4: uma palavra só para a mesma coisa). Fontes: Fresha (workspace = conta do negócio; location = unidade)
https://www.fresha.com/help-center/knowledge-base/workspace-settings/101696-switch-between-workspaces · Trinks, Avec e
Belasis usam "estabelecimento"/"salão", que prendem a um mercado ou a um lugar físico.

## 7. O que é o quê, por módulo

| Módulo | Ação principal | Seções | Categoria | Filtros (dentro do botão) | Modo de ver | Outros |
|---|---|---|---|---|---|---|
| Agenda | Novo agendamento | — | — | status, profissional, serviço, bloqueio, etiqueta | Dia ▾ | Hoje · Equipe N de M · Lista de espera · Opções |
| Clientes | Adicionar | — | — | etiquetas, cadastro, saldo, última visita, aniversário, origem | — | Ordenar · Opções |
| Catálogo | Adicionar | Serviços · Pacotes · Combos · Planos de assinatura · Produtos | Categoria | online, profissional, pede formulário | — | Ordenar · Opções |
| Financeiro | Adicionar ▾ | Visão geral · Relatórios · DRE · Contas a pagar · Comissões | — | tipo, forma de pagamento, profissional | Mês ▾ | Opções |
| Formulários | Adicionar | Visão geral · Fichas · Modelos · Termos | Modelo | situação, profissional, data | — | Ordenar · Opções |

Os outros módulos seguem o mesmo molde, um por spec. O lugar de cada módulo e seção vem de um mapa só (configuração da navegação), para mudar de lugar sem mexer nas telas.

## 8. Campos, camadas e estados

- **Campos:** rótulo acima; obrigatório com * cinza; erro com contorno vermelho e mensagem com ícone embaixo; seleção e data em pílula com ▾ ou calendário; nota em campo de várias linhas (canto 16); caixinha e interruptor pretos quando ligados.
  Erro que não pode dizer qual campo falhou: numa linha acima da ação, com ícone e palavra, `role="alert"`, sem contorno
  vermelho. Carregando de envio: botão esmaecido com "…ndo" (ex.: "Entrando…"), campos só leitura, sem linhas cinza.
- **Botões especiais:** Excluir com texto vermelho; desativado esmaecido (opacidade 60 %); quando a função ainda não existe, o texto ao lado diz "em desenvolvimento".
- **Por cima:** menu aberto (Opções e ⋮) branco com sombra; janelinha de confirmação para o que não se desfaz; aviso embaixo depois de uma ação, com "Desfazer" quando der; folha de baixo no celular (filtros, menus) com linhas que abrem com ▾/▴; painel à direita no computador (filtros; agendamento com 480 px).
- **Estados de toda tela:** vazio (ícone, frase, "Adicionar <coisa>" com contorno), sem resultado (o que foi buscado e "Limpar filtros"), carregando (linhas cinza só depois de 0,3 s, anunciado ao leitor de tela), erro (o que houve e "Tentar de novo"), sucesso (aviso).

## 8b. Medidas exatas (para quem constrói)

| Peça | Medida |
|---|---|
| Sombra do que flutua | `0 16px 40px rgba(22,24,29,.18)` |
| Escolhido do seletor | fundo branco; anel 1 px #D8D7D1 + `0 1px 3px rgba(22,24,29,.14)` |
| Borda do cabeçalho do celular | `0 1px 0 --line` + `0 6px 14px -10px rgba(22,24,29,.25)` |
| Seletor | trilho com 4 px de folga; item 36 (total 44) no celular e no computador; texto 13; contador dentro: a pílula (regra do contador) |
| Agendar (barra) | círculo 52 preto `--ink`, ícone `calendar-plus` branco, nome "Agendar" 11 forte |
| Botão de status | 36 de altura, área de toque 44 |
| Caixinha · interruptor | 22 com canto 7 · 44 × 26 |
| Anel de foco | 2 px `--ink3`, afastado 2 px |
| Larguras (computador) | título da barra 280 · busca geral 320 · busca da tela 280 · menu aberto 240 · janelinha 340 · painel 480 |
| Campo de formulário | 44 no celular e no computador |
| Cabeçalho de tabela | 36, texto 12 forte `--ink3` |
| Cabeçalho de grupo na lista | 14 forte + quantidade na pílula cinza (regra do contador) |
| Contadores | pílula 20 de altura, mínimo 20 de largura, 7 de folga lateral, canto 10; número 12 (cinza: 500 `--ink2`; pendência: 600 #8A5205 sobre `--warnSoft`) · em botão de ícone: ícone + pílula, folga 12/10, espaço 6 |

**Posição dos controles no computador.** Barra do topo: título e subtítulo · busca geral · Opções · ação principal · divisor · ajuda · notificações · Sua conta. Barra da lista (bloco branco): busca da tela · Categoria · Filtros · (à direita) Ordenar.

**Ordem do menu principal:** Agenda · Clientes · Catálogo · Estoque · Caixa · Financeiro · Formulários · Mensagens · Marketing · Fidelidade · Equipe; Ajustes fixo embaixo. Ícones: `calendar`, `users`, `tag`, `warehouse`, `banknote`, `chart-column`, `clipboard-list`, `message-circle`, `megaphone`, `heart`, `briefcase`, `settings`.

**Ordem padrão de "Ordenar":** Clientes "Última visita" · Catálogo "Nome" · Formulários "Atendimento".

**Peças de conteúdo:**
- **Bolinha da cliente:** 40 no celular, 24 na tabela do computador; fundo `--btn`, iniciais `--ink2` 13 forte; nunca colorida.
- **Sua conta:** bolinha 40 com a inicial da pessoa (inicial = primeira letra do e-mail da pessoa), fundo `--btn`; sem e-mail, o ícone `user` no lugar da inicial (E47·2·A; o nome no leitor continua "Sua conta"); abre a folha (celular) ou o menu (computador) Sua conta: Minha conta · Preferências · Meu faturamento · Trocar de empresa (só com mais de uma) · Sair.
- **Quadrado da inicial da empresa** (Escolher empresa; 10 de canto, `--brand`; enfeite, `aria-hidden`, o nome da linha é o nome da empresa). A letra (E47·1·A):
  1. Pega a primeira palavra do nome. Se ela, sem diferença de maiúscula e acento, é uma destas, pula: estúdio, studio,
     clínica, clinic, salão, salón, salon, barbearia, barbería, barbershop, spa, espaço, espacio, centro, center,
     centre, instituto, institute, ateliê, atelier. Pula só a primeira palavra, uma vez.
  2. Depois dela, pula também as ligações: de, da, do, das, dos, del, la, el, the, of.
  3. A letra é o primeiro caractere de letra ou número da palavra seguinte, em maiúscula, como está escrito (com acento).
  4. Se nada sobra depois de pular, usa a primeira letra da própria palavra pulada ("Estúdio" → E); nome sem letra nem número usa o primeiro caractere.
  Exemplos: "Estúdio Aurora" → A · "Clínica Lírio" → L · "Salão Bela" → B · "Studio da Ana" → A · "Spa" → S ·
  "Bela Pele" → B.
- **Linha do tempo:** acontecimentos do mais novo para o mais antigo, agrupados por dia ("Hoje", "Ontem"); cada item com ícone em bolinha 36 `--btn`, título 15 forte, detalhe 13 `--ink2` e hora 12 `--ink3` à direita; uma linha de 2 px `--line` liga as bolinhas; não lido com ponto `--id` de 8 (é "onde estou": o que ainda não foi visto).
- **Aviso no celular (push):** nome da empresa + o tipo do aviso ("Novo agendamento para amanhã"); nunca nome de cliente nem dado de saúde.

**Botão preto dentro de folha, painel ou janelinha:** o botão de confirmar da camada aberta é preto (Mostrar 8 clientes, Excluir na janelinha em vermelho); enquanto a camada está aberta, a tela de trás não conta.

**Tela sem menu** (Entrar, Escolher empresa): fundo `--page` e um bloco `--card` canto 20; no computador, 480 de
largura, centrado; no celular, largura toda, margem 16, no alto; título 20 forte com o nome da tela; sem barra, sem nome
do sistema, sem logotipo; a ação é a peça preta (Entrar) ou a lista (Escolher empresa); "Sair" claro no fim do bloco.

**Tela inicial** (até a Agenda existir; E47·3·A): só a barra do topo com Sua conta, sobre o fundo `--page`; sem texto
solto e sem o nome do sistema na tela.

**Textos de estado vazio:** "Ainda não há <itens>" + uma frase do que fazer + "Adicionar <item>" (ex.: "Ainda não há notas" · "Adicionar nota").

## 9. Acessibilidade (sempre)

Contraste AA; toque 44/40; foco visível (anel de 2 px); nada só por cor (estado e pendência com palavra ou nome no leitor); seletor com papel de abas; status e botões de ícone com nome; movimento reduzido respeitado.

**Larguras de teste:** toda tela é testada em 390 px (celular) e 1440 px (computador) (E15·1).

## 10. Checklist de quem revisa uma tela (antes do dono ver)

1. Só há **uma** peça preta de ação na tela (no celular, o Agendar da barra)? O "+ Adicionar" do celular está com contorno e com nome?
2. Algum controle está direto sobre o fundo cinza? (Não pode.)
3. Cada controle é de um tipo do §5, com o desenho e o nome de §5 e §6?
4. Azul aparece só em "onde estou"? Âmbar só em pendência/estado? Todo contador está na pílula do §5 (cinza = total; âmbar = há pendência), nenhum número solto ou flutuando sobre ícone?
5. Busca em campo, filtros no botão, ordenar como "Ordenar: …", categoria como botão (computador) ou seletor (celular)?
6. Título da tela segue a regra do §6?
7. Toque, contraste e nomes acessíveis conferidos? Estados vazio, sem resultado, carregando e erro existem?
8. Alguma peça, cor ou nome **fora** deste arquivo? Se sim, a tela para e a peça entra aqui primeiro.
