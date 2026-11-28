# Spec · Revisão do processo (item 4b da fila)

- **Pasta:** `specs/20261128-180247-processo-revisao/` · **Branch:** `chore/processo-revisao` (a partir da `previas`)
- **Tipo:** texto e regras (`docs/guias/processo-sdd.md` §3) · **Escrita por:** Analista de requisitos ·
  **Norma:** IEEE 29148 e BABOK
- **Status:** Draft
- **Aprovação do dono:** (pendente)
- **Aprovação do merge:** (pendente)
- **Fontes:** fila da `feat/agenda` (item 4b) · `docs/decisoes/2026-11-27-fundacao.md` da `feat/agenda` (linhas
  "E65 (sim)", "Ordem (...)", "Pergunta do dono (pasta specs)", "Crítica do dono (E64)", "Pedido (links
  clicáveis)", "Pedido (seguir o aprovado...)", "Pedido (ler o DESIGN.md...)") ·
  `specs/20261128-020000-agenda/auditoria-processo.md` §4 e §5 da `feat/agenda` · as 4 revisões de conversas
  (Documentador, 28/11, só leitura; sessões `7Rj`, `9ep`, `8F1`, `958`).

## 1. Pedido literal do dono (28/11/2026, https://claude.ai/code/session_018cV8b958nnbLyXPMKPeaNK)
- **E65:** "E65 sim" (as 8 travas T1 a T8 do relatório de auditoria, §4).
- **Rever o processo:** "precisa rever todo o processo de desenvolvimento para fechar tudo e qualquer furo... arrume
  tudo o que deve para acabar com esses erros amadores."
- **Bloco do que precisa do dono:** "preciso que separe tbm onde começa sua resposta que eu preciso ler e dar
  atenção em todas as respostas que precisam de mim e de forma clara... ajuste isso no projeto."
- **Registrar toda proposta futura:** "toda proposta de melhoria que eu falo e que vc menciona recomendar para
  quando chegar o momento no futuro deve ser registrada... tudo que é importante e falado para fazer deve entrar no
  backlog ou arquivo correspondente para nao ficar cheios de remendo."
- **Revisar as conversas:** "deves revisar as conversas anteriores deste projeto para ver tudo que falamos e o que
  nao foi devidamente registrado onde deve ser"
- **Ler o DESIGN.md e toda decisão no arquivo:** "vc deve garantir que leiam o design.md.. nao pode ficar começando a
  ter bagunça nos arquivos e escrever uma coisa e construir outra.. isso não pode deixar acontecer de forma nenhuma
  e toda decisao vai pros arquivos correspondentes, nada de só aqui pra nao se perder."
- **Links clicáveis:** "qualquer link de arquivo que eu precise ler, tem que me mandar o link para eu abrir, seja
  abrir aqui dentro do Claude, ou seja para abrir pelo Git, caso eu não esteja no Claude ainda. Nada de caminho de
  coisas que eu precise ler que não tem como eu clicar e abrir"
- **Seguir o aprovado e usar referências para agregar:** "se tava escrito uma coisa, era só vc seguir e nao mudar e
  me induzir a outra decisao divergente. (...) as imagens que mando sao pra te ajudar e nao pra vc fazer fiel de
  forma tendenciosa.. (...) sao coisas simples de decidir."
- **Dizer o que se decide (crítica E64):** "vc nao me trouxe sobre o que devo decidir, nao posso aprovar algo que
  nao sei o que é. falha sua." Mesma falha antes, na E38 (11:59): "Sobre esse item E38, não entendi… precisa me
  trazer mais clareza para… não fazer nenhuma besteira."
- **Pasta specs:** "na pasta specs ta cheeeeeio de arquivos, auditorias, etc... isso ta certo? nao vai se perder no
  meio do caminho?"

## 2. O que muda (requisitos)
Cada requisito diz de onde vem. O "como" e a lista final de arquivos são do Arquiteto, no `plan.md`.

### 2.1 As 8 travas aprovadas (E65·1 a E65·8)
- **RF-01 (E65·1 = T1).** O texto da T1 (Anexo A) entra no `DESIGN.md` §10 (item 9) e em
  `.claude/agents/revisor-design.md`.
- **RF-02 (E65·2 = T2).** O texto da T2 entra no `docs/guias/processo-sdd.md` (etapa 6) e em
  `.claude/agents/designer-produto.md`.
- **RF-03 (E65·3 = T3).** O texto da T3 troca o passo 9 de `.claude/skills/falar-com-o-dono/SKILL.md`. A linha
  "Em dia com: <último código>" passa a existir no topo da spec, do plano, das tarefas e da ficha de cada tarefa
  aberta nesta branch.
- **RF-04 (E65·4 = T4).** A etapa 7b entra no `docs/guias/processo-sdd.md` §2 e o passo 0 de
  `.claude/skills/construir-tarefa/SKILL.md` ganha a frase da T4.
- **RF-05 (E65·5 = T5).** O texto da T5 entra no `AGENTS.md` §4 e no `docs/guias/processo-sdd.md` §2, etapa 7.
- **RF-06 (E65·6 = T6).** O texto da T6 entra no `AGENTS.md` §6. A negação de `git stash*` e `git reset --hard*`
  em `.claude/settings.json` **não** entra aqui: vai no PR das travas do Claude (E38·A1, item 2 da fila), e a fila
  passa a dizer isso. O uso de `git worktree` por agente que escreve em paralelo fica numa ADR do Engenheiro de
  DevOps (auditoria §4, "mudanças técnicas").
- **RF-07 (E65·7 = T7).** A ficha curta de tela (4 pontos do `DESIGN.md` mais a Assumption 6 da Agenda) é uma
  parada própria do Designer de produto, na `feat/agenda`. Aqui só se registra, no item 5 da fila, que ela é o
  primeiro passo quando a Agenda voltar. Esta spec não responde nenhum dos 4 pontos.
- **RF-08 (E65·8 = T8).** O texto da T8 entra em `.claude/agents/analista-requisitos.md`, em "Faz".
- **RF-09 (auditoria §4, "mudanças técnicas e de texto, sem regra nova", e ordem de rever o processo).** Saem as
  linhas velhas de `src/app/AGENTS.md` (larguras), `ARCHITECTURE.md` §11 (larguras), `docs/guias/processo-sdd.md` §6
  e do cabeçalho e dos links de `CONTRIBUTING.md`. As da Agenda (frases velhas da spec §4, cabeçalho do plano e das
  tarefas com `daf9bd2`, ADR 0006 · D18, spec reescrita limpa) ficam na `feat/agenda` e entram como linha no item 5
  da fila.

### 2.2 As ordens do dono de 28/11
- **RF-10 (bloco do que precisa do dono).** Toda mensagem ao dono, de qualquer papel, começa com um bloco separado
  com o que ele precisa ler e decidir. Se não há nada, o bloco diz isso. Depois vem a parte "só para informar".
  Isso entra em `docs/moldes/pergunta.md` ("Regras de toda mensagem" e cada molde),
  `.claude/skills/falar-com-o-dono/SKILL.md` e `AGENTS.md` §7.
- **RF-11 (dizer o que se decide).** Cada pergunta e cada dúvida diz **o que é** e **o que muda** antes das opções.
  Uma mensagem só com códigos ("E64·A?") é proibida. Entra no molde, em "Regras" e em "Proibido".
- **RF-12 (links clicáveis).** Todo arquivo citado para o dono ler vai com o link clicável: do Claude, quando houver,
  ou do GitHub (`https://github.com/alexandrergomes1/crm-citas/blob/<branch>/<caminho>`). Caminho solto, nunca.
  Entra no molde, na skill `falar-com-o-dono` e no `AGENTS.md` §7.
- **RF-13 (registrar toda proposta futura).** Toda proposta para o futuro, dita pelo dono ou recomendada por um papel,
  fica registrada no mesmo turno: na fila (`docs/BACKLOG.md`) ou no arquivo da área. Nunca fica só na conversa.
  Entra no `AGENTS.md` §5 e em `.claude/agents/documentador.md`. A fila ganha um lugar para essas propostas que não
  mexe na ordem aprovada: a ordem continua do dono (`AGENTS.md` §5).
- **RF-14 (ler o DESIGN.md e toda decisão no arquivo).**
  - (1) Todo papel que desenha, constrói ou revisa tela lê o `DESIGN.md` antes. Os 14 agentes já mandam isso: fica
    como está.
  - (2) Divergência entre o que se construiu e o que está escrito (`DESIGN.md`, ficha, spec, plano) é defeito que
    bloqueia. Entra em `.claude/agents/revisor-design.md` e `.claude/agents/revisor-codigo.md`.
  - (3) Coberto pela T3 (RF-03).
  - (4) Coberto pela T4 (RF-04).
- **RF-15 (seguir o aprovado e usar referências para agregar).**
  - O que está aprovado se segue. Mudar exige mostrar ao dono, com o risco, que muda regra aprovada: coberto pela T1
    e pela T2.
  - As referências do dono (ex.: Fresha) servem para avaliar e agregar, nunca para copiar fielmente. Entra em
    `.claude/agents/designer-produto.md` e no molde "Ficha visual".
  - O que é "decisão simples" que o Designer decide sozinho fica escrito: a que não cria peça, nome, ícone nem token
    e não muda regra aprovada (limite da T2). O resto pede o "sim" do dono.
- **RF-16 (julgar só o que vê).** Fala do dono de 28/11 (15:47): "me cabe julgar apenas o que estou vendo… temos os
  devidos papéis e revisores para garantir…". Hoje está só na spec da Agenda. Entra no molde: o dono decide pelo que
  a mensagem mostra, e a conferência técnica é dos revisores, antes da mensagem.
- **RF-17 (rever todo o processo).** A tabela do §3 tem uma linha por achado das 4 revisões e da auditoria. Cada
  linha tem destino e situação. No fim (etapa 10), cada linha está "feito", "fila" ou "fora deste item, com
  motivo".

### 2.3 Organização das pastas (pergunta do dono)
- **RF-18.** Passa a existir uma **regra escrita do que fica em cada pasta**: `specs/<pasta>/` (o que é spec, plano,
  tarefas, ficha, relatório de revisão e auditoria) e `docs/*`. Diz também onde vai o que não é nenhum desses. O
  desenho da regra e o arquivo onde ela mora são do Arquiteto, no plano. A regra respeita o lugar que a T1 já fixa
  (`specs/<pasta>/revisao-design.md`).
- **RF-19.** Os arquivos que já existem nesta branch são conferidos contra a regra. O plano lista o que se move e o
  que fica, com o motivo, e corrige os links que apontam para o que se move.
- **RF-20.** A mensagem de aprovação responde à pergunta do dono em uma linha.

### 2.4 Registros que faltam ou estão no lugar errado (as 4 revisões)
- **RF-21.** Cada linha "falta" do §3 é corrigida no arquivo de destino, por quem é dono do arquivo (Documentador:
  fila, estado e decisões; Arquiteto: `ARCHITECTURE.md` e ADR; Engenheiro de segurança: `SECURITY.md`; Analista:
  `docs/produto/`; Engenheiro de DevOps: ADR de ferramentas).
- **RF-22.** Item que é decisão do dono e ainda não tem resposta não é decidido aqui. As 3 dúvidas do §5 vão juntas
  na aprovação. Os outros entram na fila como "a decidir com o dono", com a origem e o motivo (acesso, dado,
  dinheiro ou produção), nunca em "Assumptions".
- **RF-23.** O que mora noutra branch (Agenda, Agendamento e as specs dos módulos) não muda aqui. Ganha só uma linha
  na fila ou no `docs/STATUS.md`, se ainda não tiver.

## 3. Tabela única · o que falta registrar ou está no lugar errado
Legenda da origem: **A** = auditoria-processo.md · **7Rj, 9ep, 8F1, 958** = revisão da conversa (nº da linha ou
hora). Situação: **feito** (já está no lugar certo) · **falta** (corrige-se neste item) · **fila** (entra na fila
como item ou ideia, sem decidir) · **dúvida** (§5) · **fora** (outra branch, com motivo) · **nada** (não precisa).

| # | Item | Fala ou origem | Arquivo de destino | Situação |
|---|---|---|---|---|
| 1 | Travas T1 a T8 | "E65 sim"; A §4 | ver RF-01 a RF-08 | falta (T6 em parte no PR E38·A1; T7 na `feat/agenda`) |
| 2 | Linhas velhas (larguras, Lacuna, cabeçalho e links do CONTRIBUTING) | A §4 | `src/app/AGENTS.md`, `ARCHITECTURE.md` §11, `processo-sdd.md` §6, `CONTRIBUTING.md` | falta |
| 3 | Ajustes da Agenda (spec §4, cabeçalhos com `daf9bd2`, ADR 0006 · D18, spec limpa) | A §4 | `feat/agenda`; linha no item 5 da fila | fora + fila |
| 4 | Bloco do que precisa do dono | ordem 28/11; 958 #49 | molde, skill `falar-com-o-dono`, `AGENTS.md` §7 | falta |
| 5 | Dizer o que se decide antes das opções | crítica E64; 958 #7 (E38, repetiu) | molde; `docs/decisoes/` (crítica da E38) | falta |
| 6 | Links clicáveis | 8F1 #37; 958 #6 | molde, skill `falar-com-o-dono`, `AGENTS.md` §7 | falta (hoje só em decisões) |
| 7 | Registrar toda proposta futura | ordem 28/11; 958 #50 | `AGENTS.md` §5, `documentador.md`, fila | falta |
| 8 | Divergência entre o escrito e o construído bloqueia | 958 #41 | `revisor-design.md`, `revisor-codigo.md` | falta |
| 9 | Toda resposta vai ao arquivo; o Documentador confere | 958 #42, #48 ("o documentador achei que fosse pra isso") | T3; `documentador.md` | falta |
| 10 | Seguir o aprovado; referências para agregar; o que é "simples" | 958 #36 a #40; A 2.2 #11 | `designer-produto.md`, molde "Ficha visual", `DESIGN.md` §10 | falta |
| 11 | "me cabe julgar apenas o que estou vendo" | 958 #19 | molde; `docs/decisoes/` | falta (hoje só na spec da Agenda) |
| 12 | Regra do que fica em cada pasta | pergunta do dono (pasta specs) | arquivo que o Arquiteto escolher | falta |
| 13 | Rótulo "Desfaz-se assim", que o dono não entendeu | 9ep #14 | molde | falta |
| 14 | E44: ler a parte do antigo do módulo ao fazer a spec | 8F1 #40 | `planejar-tarefa`, `processo-sdd.md`, `analista-requisitos.md` | falta |
| 15 | Avaliar o antigo sem tendência; o antigo não é verdade | 8F1 #10 | skill `trazer-do-antigo` | falta |
| 16 | Não anexar o `crm-agenda` à sessão sem autorização | 7Rj 22:40 | skill `trazer-do-antigo` e `CONTRIBUTING.md` | falta |
| 17 | Aprovação do merge dos itens 3 e 4 | 958 #13; 9ep "à parte" | specs (feito em `5cf0e08`, `feat/agenda`); a fila ainda diz "a gravar" | feito na spec · falta na fila |
| 18 | Branch `chore/base-fundacao` já não existe no GitHub | 8F1 #3; 9ep B7 | `docs/STATUS.md` e `docs/decisoes/` | falta (marcar feito) |
| 19 | Fundo dos botões claros nos estados | 958 #39 | `DESIGN.md` §8 (`feat/agenda`) | feito |
| 20 | Exemplos Fresha ("freshamobile") | 958 #17, #30 | material visto (informado pela conversa principal); a spec da Agenda ainda diz "não lido" | feito em parte · fora (nota da spec na `feat/agenda`) |
| 21 | Pesquisa de nomes do produto (domínio e marca), sem pressa | 7Rj E3·3 | fila (ideia) | fila |
| 22 | Fresha como referência do produto | 7Rj 19:37 | `docs/produto/README.md` | falta |
| 23 | Cadastro sozinho e período de teste do estúdio novo | 7Rj E4 | `docs/produto/cadastro-de-estudio-e-assinatura.md`; fila "a decidir" (dinheiro) | falta + fila |
| 24 | Termos de uso e política de privacidade | 7Rj E4 | `SECURITY.md` §7 (pendência antes da produção) e fila | falta + fila |
| 25 | Página de status e aviso de queda | 7Rj E4; o dono: "acho que ninguem fica avisando quedas nao" | `ARCHITECTURE.md` §11 ou fila | dúvida E66·2 |
| 26 | Avisos ao usuário dentro do sistema e por e-mail | 7Rj E4 | fila (ideia) | fila |
| 27 | Recuperação a qualquer momento (paga) quando houver muitos estúdios | 7Rj E5·3 | `ARCHITECTURE.md` §9 (opção futura); fila "a decidir" (dinheiro) | falta + fila |
| 28 | Botão branco × preto e "Agendar" de outra cor, "para debater depois" | 7Rj 20:33 | fila (ideia para debater); `DESIGN.md` já cita | fila |
| 29 | Trava automática "revisor só lê e roda testes" | 7Rj 20:42 | item 2 da fila (PR E38·A1) | fila |
| 30 | 7 itens de segurança sem documento (ex.: encarregado de dados, prazo de resposta a quem avisa falha) | 7Rj 21:06 | `SECURITY.md` §7 | falta (o Engenheiro de segurança relê a conversa para listar os 7) |
| 31 | Central de ajuda "como a da Cloudflare" | 7Rj 21:12 | `docs/produto/central-de-ajuda.md` | falta |
| 32 | gitleaks também na sessão (proposta sem resposta) | 7Rj 21:12 | ADR do DevOps (decisão técnica) e `CONTRIBUTING.md` | falta |
| 33 | Páginas antigas do canvas com nomes de teste | 7Rj 22:41 (pergunta sem resposta) | `docs/design/README.md` | dúvida E66·3 |
| 34 | Prévia online na Cloudflare (E23·2·A) | 9ep #18; 8F1 P2 | fila (item próprio; a ordem é do dono) | fila |
| 35 | Só serviços gratuitos (E23·3·A), regra geral | 9ep #19 | `ARCHITECTURE.md` §12 | falta |
| 36 | Opção de captcha no entrar (R-13) | 9ep B2 | fila "a decidir" (acesso) | fila |
| 37 | Configurar o banco online (hash da chave do servidor, chaves assimétricas) | 9ep B4 | `SECURITY.md` §7 (antes da produção) | falta |
| 38 | Skills do TanStack não aprovadas ("recomendo manter") | 9ep B5 | ADR (decisão técnica do DevOps) | falta |
| 39 | Prazo de guarda do registro de auditoria e das sessões | 9ep B6; ADR 0018 e 0019 | `SECURITY.md` §7 | dúvida E66·1 |
| 40 | Cadastro e convite de equipe (senha até 72 bytes, "Esqueci a senha" E39·1·B, trava antes de estúdios reais) | 9ep B10; 8F1 #26 | fila (item) e `docs/produto/equipe.md` | falta + fila |
| 41 | Planos da Agenda e do Agendamento voltam à 5b | 9ep B11 | `docs/STATUS.md` | falta |
| 42 | Cloudflare R2 também para arquivos (assinaturas, fotos) | 8F1 #4 | `ARCHITECTURE.md` | falta |
| 43 | Análise de espaço e cotas por estúdio (E40·B) | 8F1 #6 | ADR nova do Arquiteto; fila | fila |
| 44 | Módulo opcional por estúdio (E31·1) | 8F1 #20 | `ARCHITECTURE.md` e `docs/produto/caixa.md` | falta |
| 45 | Exceções E40·B e E39·3·i ausentes do `ARCHITECTURE.md` | 8F1 #32, #33 | `ARCHITECTURE.md` aponta para `SECURITY.md` §5 | falta |
| 46 | Pessoa em dois estúdios marcada no mesmo horário | 8F1 P5 | pergunta da spec do Agendamento; fila "a decidir" (acesso) | fila (hoje só no STATUS) |
| 47 | Dupla verificação em produção e link mágico (E39·2·A) | 8F1 #27 | fila (ideia) | fila |
| 48 | Respostas E27 a E32, E29·1, E29·3, E31, E45, E46, E64·A e "Aprovação do dono" das 6 specs | 8F1 #14 a #42; 958 #54 | specs dos módulos, nas branches deles | fora (já pendência no `docs/STATUS.md`) |
| 49 | Pergunta "multi empresa em hora errada?" e a resposta dada | 958 #12 (14:17) | `docs/decisoes/` | falta (o Documentador lê a resposta na conversa) |
| 50 | "depois do merge, siga para a Agenda" | 958 #14 | `docs/decisoes/` | falta |
| 51 | Grade "ou do colaborador" (horário de cada profissional) | 958 #18 | item 5 da fila (visões) e `docs/produto/equipe.md` | falta + fila |
| 52 | Explicar ao dono a "grade só no horário de funcionamento" | 958 #26 | pergunta aberta da spec "Agenda · visões" (item 5) | fila |
| 53 | Crítica da ficha da Agenda (17:23) e a resposta (auditoria) | 958 #43 | `docs/decisoes/` e `docs/STATUS.md` | falta |
| 54 | Revisão das conversas: feita, com as 4 conversas | 958 #55; linha "Ordem (revisar as conversas)" | `docs/decisoes/` (marcar feito, citar as 4) | falta |
| 55 | "Pode pedir as liberações que precisar" | 9ep #10 | só valeu naquela hora | nada |
| 56 | As 4 lacunas do Arquiteto de 27/11 (21:34) e o trecho da conversa 7Rj antes de 27/11 18:13 | 7Rj | — | não verificado |

## 4. Critérios de aceite
- **CA-01.** Os textos de T1, T2, T3, T4, T5, T6 (parte do `AGENTS.md`) e T8 estão nos arquivos indicados com a
  redação do Anexo A. Muda só o que o lugar pede (número do item, link), e o plano mostra cada mudança.
- **CA-02.** `docs/moldes/pergunta.md` e a skill `falar-com-o-dono` mandam: (a) o bloco do que precisa do dono
  primeiro, ou a frase de que não há nada; (b) depois, "só para informar"; (c) cada pergunta com "o que é" e "o que
  muda" antes das opções; (d) link clicável em todo arquivo citado; (e) mensagem só com códigos em "Proibido".
- **CA-03.** O `AGENTS.md` §5 e o `documentador.md` mandam registrar toda proposta futura no mesmo turno. A fila
  tem o lugar das propostas sem ordem, e a frase de que a ordem é do dono.
- **CA-04.** A regra das pastas existe num arquivo só, que o `README.md` ou o `AGENTS.md` §10 (Mapa) apontam. Os
  arquivos da branch seguem a regra ou aparecem na lista de exceções do plano, com o motivo.
- **CA-05.** Cada linha "falta" do §3 está corrigida no destino. Cada linha "fila" está na fila, com a origem. Cada
  linha "fora" tem a linha na fila ou no STATUS.
- **CA-06.** Nenhuma resposta do dono foi inventada: o que não tem resposta está no §5 ou na fila como "a decidir".
- **CA-07.** Só mudam os arquivos que o plano permite (lista provável no §7).
- **CA-08.** A revisão é feita por outro papel que não escreveu, sem "Bloqueia". Quem revisa: o Gerente de projeto
  (5b) e, nos textos de tela (`DESIGN.md` §10 e agentes de tela), o Revisor de design. Na etapa 10, o Analista
  confere cada RF e cada linha do §3.

## 5. Dúvidas (3, juntas, para a aprovação)
- **E66·1 · Quanto tempo se guardam o registro de auditoria e as sessões (dado de cliente).** Hoje nada se apaga
  (ADR 0018 e 0019; `SECURITY.md` §7). Opções: **A** sessões e tentativas de entrar por 6 meses e registro de
  auditoria por 1 ano, depois apaga sozinho · **B** tudo por 5 anos · **C** decidir só antes da produção.
  **Recomendo A:** é o mínimo que a lei brasileira pede para registro de acesso (Marco Civil da Internet, art. 15:
  6 meses) e segue a regra de guardar só o necessário (RGPD art. 5(1)(e); LGPD art. 15 e 16). As fontes são
  conferidas pelo Engenheiro de segurança antes de gravar (não verificado nesta sessão).
- **E66·2 · Página de status e aviso de queda.** Em 27/11 a lista do "que falta" trazia uma página pública que mostra
  se o sistema está no ar, e o dono comentou "acho que ninguem fica avisando quedas nao". Opções: **A** sem página
  de status agora: o monitoramento avisa só o dono, e a ideia fica na fila para rever antes de abrir a estúdios
  reais · **B** página de status pública, grátis, antes da produção. **Recomendo A:** segue a fala do dono e não
  cria trabalho agora (E23·3·A, só grátis). Desfaz-se tirando a ideia da fila.
- **E66·3 · Páginas antigas do canvas com nomes de teste do projeto antigo.** São só histórico (`docs/design/`) e o
  repositório é público. Opções: **A** ficam como estão · **B** trocar os nomes por nomes fictícios novos · **C**
  apagar as páginas antigas. **Recomendo A:** o dono disse que os dados do antigo são fictícios (E22·B) e pediu o
  canvas com as versões (E10·1). A opção C muda a E10·1.

## 6. Assumptions (o papel decidiu; recuse pelo número)
- **A1.** Rótulos do bloco: "▶ PRECISA DE VOCÊ" (ou "▶ Nada para você") e, depois, "Só para informar".
- **A2.** O rótulo "Desfaz-se assim" passa a "Como voltar atrás", com uma linha que explica.
- **A3.** A T3 manda cada papel gravar no seu arquivo. A crítica do dono ("o documentador achei que fosse pra
  isso") vira o papel do Documentador de **conferir**, depois de cada resposta, que todos gravaram, e registrar o
  que faltar. Ele não grava pelos outros.
- **A4.** "Decisão simples" do Designer = a que fica dentro do limite da T2 (RF-15).
- **A5.** As propostas futuras e os itens "a decidir" ficam numa seção da fila **sem número de ordem**. Entram na
  ordem só quando o dono escolher.
- **A6.** O texto das travas é o do Anexo A. Se um destino já mudou desde a auditoria, o plano ajusta só o lugar,
  nunca o sentido.

## 7. Arquivos que mudam (lista provável; a final é do plano)
`AGENTS.md` · `docs/guias/processo-sdd.md` · `docs/moldes/pergunta.md` · `DESIGN.md` (§10) ·
`ARCHITECTURE.md` (§9, §11, §12 e exceções) · `SECURITY.md` (§7) · `CONTRIBUTING.md` · `src/app/AGENTS.md` ·
`.claude/agents/` (`revisor-design.md`, `designer-produto.md`, `analista-requisitos.md`, `documentador.md`,
`revisor-codigo.md`) · `.claude/skills/` (`falar-com-o-dono`, `construir-tarefa`, `planejar-tarefa`,
`trazer-do-antigo`) · `docs/produto/` (`README.md`, `cadastro-de-estudio-e-assinatura.md`, `equipe.md`, `caixa.md`,
`central-de-ajuda.md`) · `docs/adr/` (novas, do DevOps e do Arquiteto) · o arquivo da regra das pastas ·
`docs/BACKLOG.md`, `docs/STATUS.md`, `docs/decisoes/` (Documentador) · `docs/design/README.md` (só se E66·3 for B
ou C) · `CHANGELOG.md`.

## 8. O que não muda
- Nenhuma resposta da Agenda (E54 a E64) nem a ficha T7, que é parada própria.
- Código, banco e telas.
- As specs dos módulos noutras branches.
- `.claude/settings.json` e os hooks (PR da E38·A1).
- A ordem aprovada da fila.

## 9. Dependências e riscos (para o Arquiteto)
- **Base da branch.** Esta branch nasce da `previas`, mas a fila com o item 4b, as decisões de 28/11 (E50 em diante)
  e a auditoria estão só na `feat/agenda`. O plano decide como trazer esses registros sem conflito com a
  `feat/agenda` (decisão técnica, com ADR se for o caso).
- **Gravar em `.claude/`** pede a permissão do dono na hora (E38·A). Sem ela, RF-01 a RF-04, RF-08, RF-14 e RF-15
  ficam "pendentes".
- **Tamanho.** São muitos arquivos de regra num PR só. O plano pode dividir em commits por tema (travas, molde,
  pastas, registros) para a revisão.

## 10. Não verificado
- As conversas inteiras: só as 4 tabelas do Documentador, que também deixam trechos "não verificado" (linha 56).
- A resposta dada ao dono às 14:17 (linha 49) e os 7 itens de segurança de 27/11 (linha 30).
- Que o material da Fresha foi visto (linha 20): é informação da conversa principal, sem registro no repositório.
- As fontes legais da recomendação E66·1.

## Anexo A · Texto exato das travas (auditoria-processo.md §4, `feat/agenda` em `85501a0`)

**T1 · Checklist do Revisor de design**
- `DESIGN.md` §10, acrescentar o item 9: "9. Toda peça, nome, ícone e token da ficha está neste arquivo, com o código da resposta do dono ou marcado 'decisão do Designer'? A imagem principal mostra só o que está aqui; opção que muda regra aprovada vai ao lado, com o rótulo 'muda regra aprovada'. Algum 'não': Bloqueia."
- `.claude/agents/revisor-design.md`, em "Faz", acrescentar: "Responde aos itens 1 a 9 do `DESIGN.md` §10, um por um, e grava o relatório em `specs/<pasta>/revisao-design.md`."

**T2 · A ficha não cria peça nem regra**
- `docs/guias/processo-sdd.md`, etapa 6, coluna "O que sai": "`ficha-visual.md`: só imagens de antes e depois e até 4 decisões. Peça ou nome novo vai como proposta na decisão; entra no `DESIGN.md` só depois do 'sim' do dono. Comportamento vai à spec. A ficha não é fonte para construir."
- `.claude/agents/designer-produto.md`, em "Nunca", acrescentar: "grava no `DESIGN.md` o que o dono ainda não respondeu; recomenda mudar regra aprovada sem mostrar a opção que a segue."

**T3 · Resposta do dono vai para os arquivos no mesmo turno**
- `.claude/skills/falar-com-o-dono/SKILL.md`, trocar o passo 9 por: "9. Pare até a resposta. Depois, no mesmo turno, cada papel grava no seu arquivo: Analista na spec (corpo e linha em 'Mudanças'), Designer no `DESIGN.md` (só tela), Arquiteto no plano, nas tarefas e no ADR, Documentador em `decisoes/` e `STATUS`. Cada arquivo leva no topo 'Em dia com: <último código>'."

**T4 · Portão do Gerente antes de construir**
- `docs/guias/processo-sdd.md`, nova linha 7b: "| 7b | Portão | Gerente de projeto | spec, plano, tarefas, ficha e `DESIGN.md` com o mesmo 'Em dia com'; revisões 5, 5b, de design e ADRs sem 'pendente'; ficha com 'Sim do dono'. Falhou: não constrói | não |"
- `.claude/skills/construir-tarefa/SKILL.md`, passo 0, acrescentar: "e o portão 7b do `gerente-projeto` passou."

**T5 · Spec reescrita limpa**
- `AGENTS.md` §4, acrescentar: "Spec aprovada que muda: o corpo é reescrito para dizer só o que vale; o histórico fica numa tabela 'Mudanças' (data, código, fala literal, o que mudou, commit). Nada de seções 'Ajustes N'. Mudança em tela, acesso, dado, dinheiro ou produção leva nova linha 'Aprovação do dono'."
- `docs/guias/processo-sdd.md` §2, etapa 7, acrescentar: "Tela: só depois da ficha (etapa 6)."

**T6 · Um agente por arquivo e sem `git stash`**
- `AGENTS.md` §6, acrescentar: "Um arquivo, um agente por vez: só se roda em paralelo quando os arquivos de cada um não se cruzam. Cada agente faz commit do que é seu antes de devolver. Proibido `git stash`, `git reset --hard` e `git checkout -- <arquivo>`."
- Trava automática: no PR das travas do Claude (E38·A1), negar `git stash*` e `git reset --hard*` em `.claude/settings.json`.

**T7 · Desfazer as contradições do `DESIGN.md`**
- Uma ficha curta ao dono, pergunta de tela, com 4 pontos e recomendação:
  - vazio da Agenda: "Novo agendamento" × "Adicionar <item>";
  - o botão do meio nas outras telas × o "+ Adicionar" do topo;
  - ícone único para "Equipe" (módulo e botão), que junta a E63;
  - Modo de ver no celular (☰).
- Junto: a Assumption 6 sai das Assumptions e vira pergunta nessa mesma ficha.
- Depois do "sim": o `§4 Formas` ganha o cartão de canto 10, o §3 ganha `--selRing`, e a exceção "Agenda no computador sem busca da tela" fica escrita.

**T8 · O Analista confere a palavra do dono no `DESIGN.md`**
- `.claude/agents/analista-requisitos.md`, em "Faz", acrescentar: "Fala do dono que cita nome de botão, peça ou cor: confira no `DESIGN.md` antes de gravar. Se diverge, grave a intenção (ex.: 'botão de criar com opções') e passe ao Designer, que mostra como recomendada a opção que segue o `DESIGN.md`."

