# Ficha visual · Agenda (E55)

- **Spec:** `spec.md` (§3, §4, RF-01 a RF-11, RN-03 a RN-06, RN-08, CA-13) · **Plano:** `plan.md` §3.1 (L-2, L-3,
  L-4), §5.6 e §7 · **Tarefa:** P3
- **Escrito por:** Designer de produto · **Norma:** WCAG 2.2, Material Design, Apple HIG · **Fonte:** só o `DESIGN.md`;
  base visual: canvas do dono `docs/design/canvas/N8AgendaPc` e `N8AgendaCel` (pedido (c)), sem o que o `DESIGN.md`
  não tem (vermelho da linha do "agora", "€ previstos", busca na Agenda, faixa da semana)
- **Conferência:** Revisor de design (P4), 1ª rodada: **Bloqueia** (9 itens e 1 imagem faltando), corrigidos; 2ª
  rodada: **Libera com ressalvas** (5 ressalvas), corrigidas nesta versão (ver "Correções"). **"Sim" do dono:**
  pendente.
- **Protótipo:** HTML estático fora do repositório, com o `tokens.css`, o `base.css` e o CSS das peças do item 4
  (`botao`, `contador`, `campos`, `etiqueta-status`, `camadas`, `estados`, `estrutura`, `sua-conta`); fonte Geist;
  ícones Lucide. Capturas com Playwright (Chromium), 390 × 844 e 1440 × 900, escala 2×. Peças novas (L-3) desenhadas só
  com `var(--...)`. Dados fictícios: equipe Ana Souza (dona), Bruna Reis, Carla Lima; dia sábado, 28 nov 2026.

---

## Mensagem ao dono (molde "Ficha visual")

**E55 · Tela Agenda** (fala o Designer de produto · norma WCAG 2.2; já conferida pelo Revisor de design)
- **O que é:** a primeira tela do dia, com uma coluna por pessoa da equipe, os atendimentos e os bloqueios de horário.
  **Antes:** `ficha/inicio-antes-390.png` (hoje, a tela inicial só tem a barra com Sua conta). **Depois:**
  `ficha/agenda-dia-dona-390.png` e `-1440.png`; todas as telas no arquivo da ficha.
- **E55·1 · Nome no topo de cada coluna:** **A** um "nome de exibição" novo, só para isto (`agenda-dia-dona`) · **B** o
  começo do e-mail (`alternativa-e55-1-b-email`) · **C** "Profissional 1, 2, 3" (`alternativa-e55-1-c-numero`).
  **Recomendo A:** as colegas veem só o nome, sem parte do e-mail (RGPD, minimização).
- **E55·2 · Entrar no sistema abre a Agenda:** **A** sim (`agenda-dia-dona`) · **B** fica a tela vazia de hoje
  (`inicio-antes`). **Recomendo A:** um toque a menos no balcão.
- **E55·3 · O que muda na tela, como nas imagens:** (1) quem não é dona nem recepção vê os horários das colegas só
  como "Ocupado", cinza e sem detalhe; (2) cada atendimento é um cartão cinza claro que nunca fica menor que um dedo;
  (3) no celular cabem 2 colunas e as outras rolam para o lado (o pior caso, com 3 atendimentos ao mesmo tempo, está
  em `agenda-celular-pior-caso-390`); (4) no celular, "Hoje" fica entre as setas do dia, embaixo do título. **A**
  aceitar assim · **B** no celular, uma coluna por vez (`alternativa-e55-3-b-uma-coluna-390`) · **C** trocar algo
  (diga qual). **Recomendo A:** vê-se o dia de duas pessoas de uma vez, como no seu canvas. Lista completa de peças e
  nomes no arquivo.
- **E55·4 · Onde se cria um bloqueio:** **A** em "Opções" (`agenda-opcoes-bloquear`) · **B** botão próprio na barra
  (`alternativa-e55-4-b-botao-1440`) · **C** só tocando num horário vazio (depende da ideia E54·1). **Recomendo A:** o
  botão próprio disputa o olho com "Novo agendamento".
- **Revisado por:** Revisor de design, 2ª rodada: Libera com ressalvas (as 5 ressalvas corrigidas).
- **Desfaz-se assim:** troca-se a linha no `DESIGN.md` e o texto no arquivo de idioma; a E55·1 sai com uma mudança no
  banco; a E55·2 volta a rota `/` à tela de hoje.
- **Responda:** os códigos, por exemplo "E55·1·A E55·2·A E55·3·A E55·4·A".

---

## Imagens

| Antes | Celular (390) | Computador (1440) |
|---|---|---|
| Tela inicial de hoje | ![](ficha/inicio-antes-390.png) | ![](ficha/inicio-antes-1440.png) |

| Depois · estado | Celular (390) | Computador (1440) |
|---|---|---|
| Dia, dona ou recepção (todas as colunas) | ![](ficha/agenda-dia-dona-390.png) | ![](ficha/agenda-dia-dona-1440.png) |
| Dia, profissional (a própria coluna primeiro; nas outras só "Ocupado", sem Ausência nem Cancelado) | ![](ficha/agenda-dia-profissional-390.png) | ![](ficha/agenda-dia-profissional-1440.png) |
| Celular, pior caso: 3 itens que se cruzam e itens de 15 e de 5 min | ![](ficha/agenda-celular-pior-caso-390.png) | ![](ficha/agenda-celular-pior-caso-1440.png) |
| Dia na v1, antes do Agendamento (só bloqueios; "Novo agendamento" em desenvolvimento) | ![](ficha/agenda-dia-v1-sem-agendamento-390.png) | ![](ficha/agenda-dia-v1-sem-agendamento-1440.png) |
| Vazio na v1 ("Bloquear horário") | ![](ficha/agenda-vazio-v1-390.png) | ![](ficha/agenda-vazio-v1-1440.png) |
| Vazio com o Agendamento ("Novo agendamento") | ![](ficha/agenda-vazio-390.png) | ![](ficha/agenda-vazio-1440.png) |
| Carregando | ![](ficha/agenda-carregando-390.png) | ![](ficha/agenda-carregando-1440.png) |
| Erro | ![](ficha/agenda-erro-390.png) | ![](ficha/agenda-erro-1440.png) |
| Sem resultado (filtro esconde tudo) | ![](ficha/agenda-sem-resultado-390.png) | ![](ficha/agenda-sem-resultado-1440.png) |
| Sem profissional (Hoje, Equipe, Filtros e funil esmaecidos) | ![](ficha/agenda-sem-profissional-390.png) | ![](ficha/agenda-sem-profissional-1440.png) |
| Passou do teto de itens (RN-08) | ![](ficha/agenda-teto-390.png) | ![](ficha/agenda-teto-1440.png) |
| Opções aberto: "Bloquear horário" funciona (E55·4·A) | ![](ficha/agenda-opcoes-bloquear-390.png) | ![](ficha/agenda-opcoes-bloquear-1440.png) |
| Modo de ver (☰ no celular, "Dia ▾" no computador) | ![](ficha/agenda-modo-de-ver-390.png) | ![](ficha/agenda-modo-de-ver-1440.png) |
| Equipe 2 de 3 | ![](ficha/agenda-equipe-390.png) | ![](ficha/agenda-equipe-1440.png) |
| Filtros (Cancelado desligado por padrão, RN-06) | ![](ficha/agenda-filtros-390.png) | ![](ficha/agenda-filtros-1440.png) |
| Filtros da profissional ("Os filtros valem só para a sua coluna.") | ![](ficha/agenda-filtros-profissional-390.png) | ![](ficha/agenda-filtros-profissional-1440.png) |
| Bloqueio · criar (dona/recepção) | ![](ficha/bloqueio-criar-390.png) | ![](ficha/bloqueio-criar-1440.png) |
| Bloqueio · criar (profissional: campo só leitura, com marca) | ![](ficha/bloqueio-criar-profissional-390.png) | ![](ficha/bloqueio-criar-profissional-1440.png) |
| Bloqueio · editar, com ⋮ aberto (Excluir) | ![](ficha/bloqueio-editar-390.png) | ![](ficha/bloqueio-editar-1440.png) |
| Bloqueio · conflito recusado (RN-04) | ![](ficha/bloqueio-conflito-390.png) | ![](ficha/bloqueio-conflito-1440.png) |
| Bloqueio · excluir, janelinha sobre o painel | ![](ficha/bloqueio-excluir-confirmar-390.png) | ![](ficha/bloqueio-excluir-confirmar-1440.png) |
| Bloqueio · excluído, aviso com "Desfazer" | ![](ficha/bloqueio-excluido-desfazer-390.png) | ![](ficha/bloqueio-excluido-desfazer-1440.png) |

| Alternativas (não recomendadas) | Celular (390) | Computador (1440) |
|---|---|---|
| E55·1·B · começo do e-mail no topo da coluna | ![](ficha/alternativa-e55-1-b-email-390.png) | ![](ficha/alternativa-e55-1-b-email-1440.png) |
| E55·1·C · "Profissional 1, 2, 3" | ![](ficha/alternativa-e55-1-c-numero-390.png) | ![](ficha/alternativa-e55-1-c-numero-1440.png) |
| E55·3·B · celular com uma coluna por vez ("Equipe 1 de 3"; o 1440 não muda) | ![](ficha/alternativa-e55-3-b-uma-coluna-390.png) | ![](ficha/alternativa-e55-3-b-uma-coluna-1440.png) |
| E55·4·B · botão "Bloquear horário" na barra da grade (o 390 fica igual à A: ⋮) | ![](ficha/alternativa-e55-4-b-botao-390.png) | ![](ficha/alternativa-e55-4-b-botao-1440.png) |

## Comportamento (para quem constrói e para o e2e)
- **Uma peça preta:** "Novo agendamento" (computador) e "Agendar" (celular). Na v1, sem o Agendamento (RF-08):
  "Novo agendamento" esmaecido com "em desenvolvimento" logo à direita dele, antes do divisor (longe de Opções); o Agendar da barra e o toque no cartão de agendamento
  abrem um aviso "em desenvolvimento" (no 390 não cabe a nota ao lado). Painel e folha abertos têm o próprio preto
  (Salvar, Mostrar N itens), e a tela de trás não conta (`DESIGN.md` §8b).
- **Opções não é "em desenvolvimento":** o botão funciona porque tem "Bloquear horário"; só Exportar e Imprimir, dentro
  dele, ficam esmaecidos com "em desenvolvimento". (A spec §4 diz Opções "em desenvolvimento"; com a E55·4·A, o
  Analista de requisitos ajusta essa linha.)
- **Computador:** barra do topo (título, data por extenso, busca geral, Opções ▾, Novo agendamento, ajuda,
  Notificações, Sua conta); barra da grade num bloco branco: Hoje · ‹ › · data em pílula ▾ (abre o calendário) ·
  Dia ▾ · (à direita) Equipe N de M · Filtros ▾ · Lista de espera (em desenvolvimento). Sua conta passa para a barra do
  topo (muda `sua-conta.tsx`, previsto no plano §5.6).
- **Celular:** cabeçalho com ☰ (Modo de ver), "Agenda" e a data embaixo como botão ▾ (abre o calendário; área de toque
  estendida para 44), funil, sininho e Sua conta; embaixo, na mesma faixa branca, ‹ Hoje › · Equipe N de M · ⋮
  (Opções). **Hoje sai do cabeçalho** (spec §4) porque, com o funil ligado (funil + pílula), a data quebrava em 3
  linhas; o Analista ajusta a linha da spec com o "sim" da E55·3. Lista de espera fica na folha do ☰, em
  desenvolvimento. Duas colunas de 160 à vista; as outras rolam para o lado, com esmaecido na ponta (o mesmo do
  seletor, §5); o cabeçalho das colunas rola junto.
- **Colunas:** ordem fixa da equipe; com `agenda.ver` "próprios", a própria coluna vem primeiro. Cabeçalho: bolinha 24
  com as iniciais e o nome (vem da E55·1).
- **"Ocupado" (E26·1·B, RN-04, CA-13):** só o que ocupa horário vira "Ocupado": os bloqueios e os agendamentos ativos.
  **Agendamento com Ausência ou Cancelado não aparece** nas colunas que a pessoa não vê completas (na imagem, a Paula
  Gil das 16:30, Ausência na coluna da Bruna, some da visão da Carla). "Ocupado" não é botão, não recebe foco por
  toque, só é lido ("Ocupado, 10:30 a 11:00"). Filtros não agem nas colunas "Ocupado"; para a profissional, o painel de
  Filtros abre com a linha "Os filtros valem só para a sua coluna." e o "Mostrar N itens" conta só os itens da
  coluna dela (5 na imagem).
- **Altura mínima e toque (WCAG 2.5.8; `DESIGN.md` §4):** a hora mede 64 px; o cartão desenha a duração, mas **nunca
  fica abaixo de 44 px no celular e 40 px no computador**. Quando essa altura mínima faz um cartão cobrir o seguinte,
  os dois passam a ficar **lado a lado**, pela mesma regra dos que se cruzam de verdade (RN-05); a hora escrita no
  cartão continua a real. Assim nenhum alvo fica abaixo de 40/44 de altura, mesmo com bloqueio de 5 min ou passo de
  15 min (`agenda-celular-pior-caso`).
- **No máximo 3 lado a lado ("+N"):** até 3 itens que se cruzam ficam lado a lado; com 4 ou mais, ficam os 2 primeiros
  e o 3º lugar vira um cartão **"+N"** (N = os que não cabem), em `--btn`, com a altura mínima, que abre a lista do
  horário (menu no computador, folha no celular); o leitor lê "+3 itens a partir das 09:30". Assim cada cartão do
  celular tem pelo menos ~48 px de largura (coluna de 160 ÷ 3) e 44 de altura (`agenda-celular-pior-caso`: 5 itens às
  09:30–10:30 viram 2 cartões e "+3").
- **Cartão estreito (lado a lado):** o status aparece **só com o ícone**, sem a palavra, e o nome do status vai para o
  leitor (`DESIGN.md` §5); nome e horário terminam em reticências. "Ocupado" estreito leva sempre o horário na 2ª
  linha.
- **Conteúdo do cartão (sozinho na coluna):** de 1 h ou mais: nome, "início–fim · serviço" e o status com ícone e palavra; de 45 min:
  nome e ícone do status, e a hora com o serviço; menos de 45 min: uma linha "hora + nome" e o ícone. O que não cabe
  vai para o leitor de tela (`DESIGN.md` §5: no cartão pequeno, só o ícone). Todo texto cortado termina em reticências.
- **Teclado (RNF-03):** cada coluna é um grupo com o nome da pessoa; Tab percorre os cartões por coluna e por hora;
  Enter abre. O nome acessível começa pelo texto visível (WCAG 2.5.3).
- **Bloqueio:** painel 480 à direita (computador) e folha de baixo (celular), título "Bloqueio de horário" (nome do
  status no §5). Campos: Profissional*, Data*, Início*, Fim* (seleção ▾ em passos de 15 min, a `CampoSelecao` que já
  existe), Motivo (várias linhas, até 200). Com alcance "próprios", Profissional fica **só leitura**: sem contorno, fundo
  `--page`, sem ▾, e a frase "Você bloqueia só a sua agenda." embaixo, ligada ao campo (`aria-describedby`). Ao editar,
  ⋮ (Opções) no topo do painel com Excluir em vermelho → **a janelinha abre por cima do painel, que fica atrás** →
  aviso "Bloqueio excluído" com "Desfazer". Salvar fecha e mostra o aviso "Bloqueio salvo".
- **Erros do bloqueio:** conflito (RN-04) numa linha acima de Salvar, com ícone, `role="alert"`, sem contorno vermelho
  (não se diz qual item conflita). Fim antes do início ou menos de 5 min (RN-03): erro no campo Fim, com contorno
  vermelho e frase embaixo. Desfazer que bate em horário ocupado: aviso "Não foi possível desfazer: o horário já foi
  ocupado."
- **Estados:** carregando com as linhas cinza do §8 no lugar da grade, depois de 0,3 s, anunciado "Carregando a agenda".
  **Vazio na v1:** "Ainda não há bloqueios neste dia" · "Bloqueie um horário quando alguém não puder atender." ·
  "Bloquear horário" (contorno; abre o painel). **Vazio com o Agendamento:** "Ainda não há agendamentos neste dia" ·
  "Marque um agendamento para este dia." · "Novo agendamento" (contorno). Sem resultado com "Limpar filtros". Sem
  profissional: Hoje, Dia ▾, Equipe, Filtros e o funil esmaecidos, "Ver equipe" em desenvolvimento. Erro com "Tentar de
  novo". Teto como linha acima da grade (`role="status"`).

### Nota para o Arquiteto de software (não toco no `plan.md`)
O `plan.md` §2.4 diz que cada agendamento que ocupa horário sai como "Ocupado". Para a tela ficar certa, **o servidor
também filtra**: nas colunas que a pessoa não vê completas, agendamento com status Ausência ou Cancelado **não sai na
resposta** (nem como "Ocupado"), pela mesma lista do RN-04 que `bloqueio.ts` usa no conflito; e a leitura de
"ocupados" do banco (§4.3) deixa esses status de fora. Sem isso, a profissional deduz pelo "Ocupado" um horário que
está livre, e o número de "Ocupado" revela as ausências das colegas (E26·1·B, CA-13). Vale quando o Agendamento
existir; com só bloqueios, não muda nada. Teste sugerido em `ler-dia.test.ts`: Ausência e Cancelado de outra coluna
não aparecem.

## Onde uma ideia E54 mudaria a tela (o dono ainda não respondeu; as imagens estão **sem** elas)
- **E54·1:** tocar ou dar Enter num horário vazio abriria um menu com "Novo agendamento" e "Bloquear horário", já com a
  hora e a pessoa; seria a 2ª entrada do bloqueio, além de Opções.
- **E54·2:** uma linha de 2 px atravessaria a coluna de hoje na hora atual, com a hora na coluna das horas; a cor
  precisa entrar no `DESIGN.md` (o vermelho do canvas é erro).
- **E54·3:** abaixo do Motivo, chips "Almoço · Folga · Reunião · Curso · Pessoal" que preenchem o campo.
- **E54·4:** o painel nasceria com Fim = Início + 1 h, e o Fim andaria junto quando o Início passa dele.
- **E54·5:** Início e Fim virariam campos de digitar ("1410" → 14:10), em vez da seleção ▾.
- **E54·6:** embaixo do nome no cabeçalho da coluna, "3 atendimentos · 4 h 50 min" em 12 `--ink3` (só na coluna
  completa).
- **E54·7:** o calendário da data marcaria com um ponto os dias que têm itens.
- **E54·8:** a folha do ☰ ganharia "Lista" ativa no celular, com os itens em ordem e "Livre 14:30–16:00" entre eles.

## Nomes e peças novos (fora do `DESIGN.md`; entram nele com a E55·3)
**Peças e regras:**
1. **Grade do dia:** coluna das horas 56 (computador) e 44 (celular), hora 11 `--ink3`, 64 px por hora, linha da hora
   e das colunas em `--line`, sobre a superfície `--card`.
2. **Cabeçalho da coluna:** 44 de altura, bolinha 24 (`--btn`, iniciais `--ink2`, a mesma da cliente na tabela) e nome
   13 forte. A bolinha da cliente passa a servir também à pessoa da equipe.
3. **Cartão do agendamento e do bloqueio:** botão em `--btn` (controle sobre superfície), **canto 10** (hoje só o
   quadrado da inicial), três conteúdos por duração; bloqueio com `lock` e "Bloqueio · motivo".
4. **Altura mínima do cartão: 44 no celular e 40 no computador**, e "lado a lado" quando a altura mínima cobre o
   seguinte; **no máximo 3 lado a lado**, e com 4 ou mais o 3º lugar vira o cartão **"+N"** que abre a lista do
   horário; em cartão lado a lado o status é só o ícone e o "Ocupado" põe o horário na 2ª linha.
5. **"Ocupado":** área em `--page` ("fora do seu alcance"), canto 10, "Ocupado" 12 forte `--ink2` e horário 12
   `--ink3`; sem ícone, sem toque, sem ⋮. Uso novo do `--page` dentro de um bloco. Só bloqueio e agendamento ativo.
6. **Celular:** data como botão ▾ no subtítulo do cabeçalho; faixa da grade (‹ Hoje › · Equipe · ⋮) colada ao
   cabeçalho, com **Hoje fora do cabeçalho**; rolagem lateral das colunas com esmaecido na ponta.
7. **Equipe N de M:** menu aberto (computador) e folha (celular) com caixinhas, aplicando na hora.
8. **Linha de aviso no topo da grade** (teto, RN-08): ícone `circle-alert` e frase 13 `--ink2`.
9. **Campo só leitura:** sem contorno, fundo `--page`, sem ▾ e frase 13 `--ink3` embaixo que diz por quê (o
   `DESIGN.md` §8 não tem esse estado).
10. **Valor "6 de 7" na linha que abre (Filtros › Status):** texto 13 `--ink2` à direita (`ds-abre__valor`), **fora da
    pílula de contador**: não é um total, é quantos de quantos estão ligados. O contador de filtros ligados continua
    na pílula, no botão Filtros.
11. **Lista de espera dentro da folha "Modo de ver" (☰) no celular**, em desenvolvimento: no 390 não há lugar na faixa
    e a lista é outra forma de ver a Agenda.
12. **Ícones novos:** `menu` (☰; o §5 cita o ☰ sem nome de ícone), `list-ordered` (Lista de espera, que o §5 manda ter
    ícone e nome) e **`calendar-range` no "Dia ▾"** (o `calendar-days` fica só para o calendário da data, e o
    `calendar` só para o módulo Agenda: um ícone por coisa, §5).

**Nomes:** Ocupado · Bloqueio · Bloquear horário · Bloqueio de horário (título; já é nome de status) · Profissional ·
Data · Início · Fim · Motivo · "Exemplo: almoço" · "Você bloqueia só a sua agenda." · Bloqueio salvo · Bloqueio
excluído · "Excluir este bloqueio?" · "O horário fica livre na agenda." · Exportar · Imprimir · Modo de ver · Dia ·
3 dias · Semana · Mês · Equipe (título da folha) · Status · Bloqueios · Mostrar bloqueios · Mostrar N itens · N de M
(valor da linha) · Dia anterior · Dia seguinte · "escolher data" (leitor) · "Ainda não há bloqueios neste dia" ·
"Bloqueie um horário quando alguém não puder atender." · "Ainda não há agendamentos neste dia" · "Marque um agendamento
para este dia." · "Nenhum item com os filtros ligados" · "Os filtros escondem todos os itens deste dia." · "Ainda não há
ninguém na agenda" · "Cada pessoa da equipe que atende aparece aqui como uma coluna." · Ver equipe · "Não foi possível
carregar a agenda" · "Carregando a agenda" (leitor) · "Este dia tem mais de 500 itens e nem todos aparecem. Escolha
menos pessoas em Equipe." · "Já há um bloqueio ou agendamento neste horário. Escolha outro horário." · "O fim tem de ser
depois do início." · "O bloqueio tem de ter pelo menos 5 minutos." · "Não foi possível desfazer: o horário já foi
ocupado." · "Os filtros valem só para a sua coluna." · "+N" e "N itens a partir das HH:MM" (leitor). Nenhum texto diz "estúdio" (E47).

## Decisões para o dono (detalhe da mensagem acima)

### E55·1 · De onde vem o nome no topo de cada coluna (L-2; dado pessoal da equipe)
Hoje o sistema não guarda nome da pessoa, só o e-mail.
- **E55·1·A:** um campo novo, **"nome de exibição"**, só para isto: as colegas veem só esse nome e as iniciais. Na v1
  não há tela para editar (é do módulo Equipe); em desenvolvimento os nomes são fictícios, postos pelo preparo de teste.
- **E55·1·B:** o começo do e-mail (antes do @) → sem campo novo, mas mostra às colegas parte do e-mail, que muitas
  vezes é o nome completo ou um apelido pessoal ("carlalima.estetica").
- **E55·1·C:** "Profissional 1, 2, 3" até existir a Equipe → nenhum dado pessoal, mas a recepção não sabe quem é quem.
- **Recomendo A:** mostra só o necessário (RGPD art. 5(1)(c), minimização) e fala a língua de quem usa (Nielsen 2).

### E55·2 · O endereço inicial (`/`) abre a Agenda (L-4)
- **E55·2·A:** com a Agenda pronta, entrar no sistema leva direto à Agenda; a "tela inicial" vazia sai do `DESIGN.md`.
- **E55·2·B:** fica a tela inicial vazia; a pessoa toca em Agenda no menu.
- **Recomendo A:** o `DESIGN.md` §8b já diz que a tela inicial vale "até a Agenda existir", e a Agenda é o uso do
  balcão (Nielsen 7, eficiência).

### E55·3 · Peças e nomes novos da Agenda (L-3), como nas imagens
- **E55·3·A:** aceitar a lista acima, com o celular em 2 colunas à vista e as outras rolando para o lado → entra no
  `DESIGN.md` §4, §5, §6, §8 e §8b e nos arquivos de idioma. **Custo honesto:** quando 3 itens se cruzam na mesma
  pessoa, cada cartão do celular fica com ~48 px de largura e mostra só "C…" e o ícone; com 4 ou mais, aparece "+N" e
  é preciso um toque a mais para ver os outros (`agenda-celular-pior-caso-390`).
- **E55·3·B:** igual, mas no celular **uma coluna por vez**, trocada pelo Equipe ("Equipe 1 de 3") → cartões largos,
  sem corte, mas a recepção vê uma pessoa por vez.
- **E55·3·C:** aceitar e trocar algum → diga qual e o novo.
- **Recomendo A:** no dia comum, 2 colunas de 160 mostram nome e hora; o corte do pior caso é raro e o toque abre o
  item inteiro. É o desenho do canvas do dono (N8). "Ocupado" sem ícone cumpre a E26·1·B, e o fundo `--page` diz "não é
  seu" sem usar cor de estado.

### E55·4 · Por onde se cria um bloqueio
- **E55·4·A:** "Bloquear horário" dentro de **Opções** (Opções ▾ no computador, ⋮ no celular), e no vazio da v1;
  tocar num bloqueio abre para editar.
- **E55·4·B:** botão claro "Bloquear horário" na barra da grade (computador; no celular continua no ⋮) → mais à vista,
  mas disputa o olho com "Novo agendamento" (§1: "uma delas está no nível errado").
- **E55·4·C:** só tocando num horário vazio → depende da E54·1·A; sem ela, não haveria como criar.
- **Recomendo A:** o §5 manda as ações secundárias da tela para Opções; com a E54·1·A, o horário vazio vira um atalho a
  mais.

**Desfaz-se assim:** mudar a linha no `DESIGN.md` e o texto no arquivo de idioma; a tela lê dali. E55·1 desfaz-se com
uma migration que tira o campo. E55·2 desfaz-se voltando a rota `/` à tela inicial.
**Responda:** os códigos, por exemplo "E55·1·A E55·2·A E55·3·A E55·4·A". Com o "sim", o Designer grava as peças e
os nomes no `DESIGN.md`.

## Correções da 1ª rodada (Revisor de design: Bloqueia)
| # | Pedido | O que mudou |
|---|---|---|
| 1 | Ausência e Cancelado não viram "Ocupado" | desenho (a Paula Gil some da visão da profissional), Comportamento e nota ao Arquiteto |
| 2 | Toque abaixo de 44/40 e de 24 | altura mínima 44/40 com lado a lado; regra na lista (item 4); imagem do pior caso |
| 3 | Reticências em todo corte; pior caso honesto | nome e detalhe com reticências; `agenda-celular-pior-caso`; custo escrito na E55·3·A |
| 4 | "Equipe 3 de 3" com 2 marcadas; data em 3 linhas | `agenda-equipe-390` com "2 de 3"; Hoje vai para a faixa e a data não quebra |
| 5 | Opções na v1; caminho do vazio da v1 | Opções funciona (só Exportar e Imprimir em desenvolvimento); `agenda-vazio-v1` com "Bloquear horário" |
| 6 | Sem profissional: esmaecer Filtros e funil | feito nas duas larguras |
| 7 | "6 de 7", ícone do "Dia ▾", só leitura, Lista de espera | "6 de 7" na lista (item 10); "Dia ▾" com `calendar-range` (item 12); só leitura com marca (item 9); Lista de espera na lista (item 11) |
| 8 | Painel atrás da janelinha | `bloqueio-excluir-confirmar` com o painel atrás |
| 9 | Mensagem ao dono | seção "Mensagem ao dono", com as imagens das alternativas, a E55·3 em 4 mudanças e "Revisado por" |
| — | Profissional com Filtros aberto | `agenda-filtros-profissional` |

**2ª rodada (Revisor de design: Libera com ressalvas)** · imagens refeitas: `agenda-dia-dona`, `agenda-dia-profissional`,
`agenda-celular-pior-caso`, `agenda-dia-v1-sem-agendamento`, `agenda-vazio-v1`, `agenda-filtros-profissional`,
`bloqueio-criar-profissional` (as duas larguras).

| # | Ressalva | O que mudou |
|---|---|---|
| 1 | "Ocupado" estreito cortado | horário sempre na 2ª linha, com reticências |
| 2 | Palavra do status em cartão estreito | lado a lado: só o ícone; a palavra vai para o leitor |
| 3 | "em desenvolvimento" perto de Opções (1440, v1) | a nota fica à direita do "Novo agendamento", numa linha |
| 4 | "Mostrar N itens" da profissional | conta só a coluna dela ("Mostrar 5 itens") |
| 5 | "+N" depois de 3 lado a lado; "Revisado por"; contrastes | regra na lista (item 4) e no pior caso; linha "Revisado por"; contrastes no "Não verificado" |

## Não verificado
- **Revisor de design:** as correções das 5 ressalvas da 2ª rodada não foram reconferidas.
- **Acessibilidade:** o axe (wcag2a, wcag2aa, wcag21a, wcag21aa, wcag22aa) deu 0 violações nas 58 capturas do
  protótipo (as 14 refeitas na 2ª rodada também); isso não vale para o app real. Não testei com leitor de tela de verdade nem a ordem do Tab na grade. A
  rolagem lateral no celular não foi testada com zoom de 200 % (WCAG 1.4.10).
- **Toque na largura:** com 3 lado a lado, o cartão do celular tem ~48 px de largura (≥ 44); o "+N" só foi desenhado
  com 5 itens, e a lista que ele abre não tem imagem própria.
- **Contraste (calculado pelo Revisor de design, 2ª rodada):** `--ink3` sobre `--page` 5,07:1 (hora da grade e horário
  do "Ocupado") e `--warn` sobre `--btn` 4,80:1 (Reservado no cartão); os dois passam de 4,5:1. Os textos esmaecidos
  (60 %) ficam abaixo de 4,5:1 (a WCAG isenta controle desativado).
- **Imagens estáticas:** menus e camadas abertos desenhados no lugar, sem clique. O protótipo põe `text-decoration:
  none` nos links do menu principal e da barra de baixo, que o CSS do item 4 não tem; no app real eles podem sair
  sublinhados, e o Engenheiro de software precisa conferir.
- **Barra de baixo:** segue o código ("Mais" sem ícone, E25·2 em aberto).
- **Dados:** dia e pessoas fictícios; as imagens mostram de 09:00 a 18:00 ou 19:00, mas a grade real tem 24 h com
  rolagem (Assumption 1 da spec). Cartões de agendamento só aparecem depois da spec do Agendamento.
- **Spec × ficha:** a spec §4 põe "Hoje" no cabeçalho do celular e "Opções" como "em desenvolvimento"; a ficha muda as
  duas coisas e o Analista de requisitos ajusta a spec com o "sim" do dono.
- **Textos em es e en:** não escritos aqui (arquivos de idioma, na construção).
- **Códigos:** o E55 estava livre na `feat/agenda` em 28/11; outras branches podem usar o mesmo número (o Gerente de
  projeto confere antes de mandar).
