# Auditoria de processo e de coerência · crm-citas, branch `feat/agenda`

Auditor independente · Normas: ISO 19011 (auditoria), IEEE 29148 (requisitos), heurísticas de Nielsen, WCAG 2.2.
Base: `feat/agenda` no commit `aa3cbeb` (28/11/2026). Nada foi editado no repositório.

---

## 1. Veredito (3 linhas)

1. A estrutura está certa: os arquivos têm papel, os 14 papéis de IA mais o dono cobrem as etapas e não falta papel. O que falhou foram as **passagens** entre etapas: o que acontece depois de uma resposta do dono, depois da aprovação, e quando dois agentes trabalham juntos.
2. Correção de um fato: a **1ª ficha não desobedeceu o `DESIGN.md`**. O `DESIGN.md` aprovado em 27/11 mandava "Novo agendamento" na Agenda e "Agendar" no celular. Quem foi contra a regra foi a **v3**, com "+ Novo ▾", que o §6 proíbe. Essa troca veio de gravar ao pé da letra a palavra solta do dono ("+novo") e de o Designer recomendar mudar a regra. O Revisor de design deixou passar.
3. Bastam umas 7 travas curtas, quase todas em arquivos que já existem: uma linha no checklist, uma etapa de portão, a spec reescrita limpa e um agente por arquivo. Elas pedem o "sim" do dono, porque mexem em `AGENTS.md`, `processo-sdd.md`, `DESIGN.md` §10 e nos agentes.

---

## 2. Divergências da ficha da Agenda

### 2.1 Histórico do "Novo" × "Adicionar" (conferido no git)

| Versão | O que a ficha mostrou | O `DESIGN.md` da época dizia | Situação |
|---|---|---|---|
| v1 (`3fe4e94`) | "Novo agendamento" (computador), "Agendar" (celular), bloqueio em Opções | §5 "na Agenda, 'Novo agendamento'"; §6 "Novo agendamento · Agendar"; §7 Agenda "Novo agendamento" (`git show 2dad348:DESIGN.md`) | **seguia** o `DESIGN.md` |
| Fala do dono E55·4 | "tem de ser um botão +novo com opções" | §6 "Adicionar ▾ = cria mais de um tipo"; "Adicionar: nunca Novo" | a intenção ("botão com opções") já existia no §6 como "Adicionar ▾" |
| Spec §16 (`217a715`) | gravou **"+ Novo"** como requisito (RF-08) | idem | o Analista gravou a palavra, não a intenção |
| v3 (`1a6ee42`, `501c5a3`) | imagens com "+ Novo ▾" e "Novo" na barra; E60·5 recomendando **B: mudar a regra em todo o app** | §6 proíbe "Novo" | **contra** o §6; o Revisor de design liberou "com ressalvas" |
| v4 (`d3f9a43`) | "+ Adicionar ▾" (E60·5: "pode ser adicionar ao inves de novo") | atualizado no mesmo commit pelo Designer | coerente, mas **sem revisão** |

A causa de fundo está no próprio `DESIGN.md`. Ele já tinha uma contradição escondida: a Agenda tinha nome próprio ("Novo agendamento"), mas a regra geral (§6) manda "Adicionar ▾" quando o botão cria mais de um tipo. A contradição apareceu quando o bloqueio entrou no botão de criar.

### 2.2 Ficha v4 × `DESIGN.md` de hoje

| # | Ponto | Ficha / imagens | `DESIGN.md` | Tipo |
|---|---|---|---|---|
| 1 | Ícone do botão Equipe | `users` nas imagens e no padrão do plano, até a E63 | §5 "um ícone por coisa"; `users` já é Clientes | regra quebrada por padrão |
| 2 | "Equipe" com dois ícones | botão com ícone de pessoas | §8b: módulo Equipe = `briefcase` | a mesma coisa com dois ícones (Nielsen 4) |
| 3 | Vazio com Agendamento | "Novo agendamento" com contorno | §8 e §6: vazio usa "Adicionar <item>". Só que §6 proíbe "Adicionar agendamento" e só autoriza "Bloquear horário" no vazio | o `DESIGN.md` se contradiz; a ficha escolheu sem registrar a exceção |
| 4 | Botão do meio em todo o app | "nas outras telas abre **a mesma folha**" (opções da Agenda) | §6 "Adicionar = criar o item da lista que está na tela". Nas outras telas também há "+ Adicionar" de contorno no topo | dois "Adicionar" diferentes na mesma tela (Clientes). Também diverge do ADR 0006 · D18 ("cada tela entrega as suas opções") |
| 5 | Token do anel do escolhido | `--selRing` | §3 não tem esse token (§8b dá o valor solto #D8D7D1) | nome fora do `DESIGN.md` |
| 6 | Busca no computador | barra da grade começa em Hoje, sem busca da tela | §5 "busca da tela: primeiro item da barra"; só o celular da Agenda tem exceção | exceção não escrita |
| 7 | Ordem da barra da grade | Hoje · ‹ › · data · Dia ▾ · Equipe · Filtros · Lista de espera | §8b só define a "barra da lista" | lacuna |
| 8 | Canto 10 do cartão | §7b | §4 "Formas" lista as exceções e não tem o cartão | o `DESIGN.md` não bate consigo |
| 9 | Modo de ver no celular | ☰ | §5 "Modo de ver: celular igual (Dia ▾)" × §5 "☰ abre as visões da Agenda" | contradição antiga do `DESIGN.md` |
| 10 | Itens "a confirmar" dentro do `DESIGN.md` | E63 e Assumption 6 gravados no §5, §6 e §7b como "a confirmar pelo dono" | o cabeçalho diz que o que não foi aprovado "não se usa" | a fonte aprovada carrega pendências |
| 11 | "Decisões do Designer" gravadas no `DESIGN.md` | "+" redondo no "Nunca"; Agenda do celular sem "+ Adicionar"; botões claros nos estados | o cabeçalho pede o "sim" do dono. A ordem do dono de 28/11 (3) deixa o papel decidir "o simples" | conflito de regra: falta dizer o que é "simples" |
| 12 | Revisão e "sim" | "A v4 ainda não foi revista"; sem linha "Sim do dono" | processo-sdd etapa 6 | etapa aberta, mas o plano e as tarefas já tratam a v4 como fonte |

### 2.3 A ficha duplica o `DESIGN.md`?

- **Papel previsto** (`processo-sdd.md` etapa 6; molde "Ficha visual"): imagens de antes e depois, nas duas larguras, e até 4 decisões com código. É um **pedido de decisão**, não uma fonte de regra.
- **O arquivo de hoje faz mais que isso.** Tem 238 linhas e, além das imagens:
  - (a) "Decisões do Designer", com 11 regras de desenho;
  - (b) "Comportamento para quem constrói", que repete e detalha a spec §4;
  - (c) "Nomes e peças da Agenda", que repete o `DESIGN.md` §7b;
  - (d) a lista "Gravado no `DESIGN.md`".
- O `plan.md` (cabeçalho) e o `tasks.md` dizem que a ficha "**passa a ser fonte**". Na prática há três fontes da mesma tela: o `DESIGN.md` §7b, a spec §4 e a ficha. Elas só se acertam pela frase "em conflito vale o `DESIGN.md`".
- **Resposta ao dono:** a ficha não nasceu para concorrer com o `DESIGN.md`. A de hoje passou do papel dela e virou um segundo documento de design. A trava T2 (§4) põe cada coisa no seu lugar: imagens e decisões na ficha, peças e nomes no `DESIGN.md`, comportamento na spec.

### 2.4 Spec, plano, tarefas e ADRs × `DESIGN.md` e entre si

| Arquivo | Achado |
|---|---|
| `spec.md` §4 | Frase velha: "A forma do botão do meio... o Designer avalia e mostra na ficha (§18)" (já decidido). "Opções (o que fica dentro sai da ficha nova)" também ficou velho. |
| `spec.md` §13 Assumption 6 | "A profissional não vê o botão Equipe" está em Assumptions e "confirma no pedido de merge". É **o que aparece na tela**, que pelo `AGENTS.md` §5 é pergunta ao dono, e a confirmação viria depois da construção. |
| `spec.md` §14 a §19 | Seis seções de ajuste. A §14 ainda descreve "Ocupado" no §3 e §4, coisa que não vale mais. A §16 abre com "Histórico... vale a §17/§18". Quem lê precisa juntar tudo de cabeça. |
| `spec.md` aprovação | A spec foi aprovada **antes** da ficha e do plano, junto com outras 10 (28/11). A etapa 6 veio depois da 7, e a spec aprovada mudou seis vezes sem regra para "mudança depois da aprovação". |
| `plan.md` | Cabeçalho: "Revisão: pendente (5 e 5b)". Cita os ajustes até `de894bf`, mas não a §19 (`daf9bd2`), embora o conteúdo da §19 esteja no corpo. Cita o ADR 0007, que ainda não existe (vem na T3, o que é aceitável). |
| `tasks.md` | O portão não tem a conferência do Gerente que o dono pediu (decisões, "Pedido (ler o DESIGN.md)", item 4). A T0a diz que a E63 "não para a construção" e deixa como padrão o `users`, que quebra o §5. A T21 diz "pela ficha aprovada", mas a v4 não tem "sim". |
| ADR 0006 · D18 | Decide comportamento de tela em outras telas: a folha mostra as opções da Agenda, e "Bloquear horário" leva à `/agenda`. Isso é tela, não decisão técnica, e diverge da ficha (ver 2.2 #4). Status "Proposto, revisão pendente". |
| ADR 0021 | Coerente com a spec (§3, RF-10, CA-13). Status "Proposto, revisão pendente". |

---

## 3. Problemas de organização

### 3.1 Papel de cada arquivo

| Arquivo | Papel | Problema |
|---|---|---|
| `README.md` | entrada e mapa | ok |
| `AGENTS.md` | regras | não tem regra de mudança depois da aprovação nem de trabalho em paralelo |
| `ARCHITECTURE.md` | planta | §11 "duas larguras que o `DESIGN.md` vai definir" ficou velho |
| `DESIGN.md` | aparência, fonte única | tem contradições internas (2.2 #3, #8, #9); guarda pendências e decisões do Designer sem regra clara; o §7b virou spec de módulo (lista longa de frases da Agenda) |
| `specs/*/ficha-visual.md` | pedido de decisão visual | virou uma 2ª fonte de design (2.3); não tem molde de arquivo |
| `specs/*/spec.md` | requisito | ajustes empilhados (§14 a §19) |
| `docs/decisoes/2026-11-27-fundacao.md` | falas do dono fora de spec | um arquivo só para todos os dias, com nome "fundação"; repete detalhes que já estão nas specs |
| `docs/STATUS.md` | estado | repete o "Já aprovado" de `decisoes/` (aceitável) |
| `docs/adr/` | decisões técnicas | ADR 0006 com decisão de tela (D18); falta da 0007 à 0017 na numeração (reservas não ditas) |
| `docs/moldes/` | só `pergunta.md` | falta o molde do arquivo da ficha e do relatório de revisão |
| `docs/guias/` | só `processo-sdd.md` | §6 "Lacuna" velho; não tem etapa "depois da resposta do dono" |
| `src/app/AGENTS.md` | regras da pasta | "Larguras ainda não definidas" ficou velho |
| `CONTRIBUTING.md` | resumo | o cabeçalho ainda diz "Rascunho para o dono aprovar (E14)", mas o STATUS dá E14 como aprovado; os links apontam para `feat/entrar-servico` |

### 3.2 Papéis e skills: buracos no fluxo

1. **Ninguém é dono da "propagação"** da resposta do dono: spec, `DESIGN.md`, ficha, plano e ADR. A `falar-com-o-dono` passo 9 só cita o Documentador (`decisoes/`) e o Analista ("Aprovação do dono"). As "Clarifications" e o `DESIGN.md` não têm responsável nem prazo. Por isso cada seção da spec termina com "Para o Arquiteto: o plano não foi tocado", e ninguém aciona o Arquiteto.
2. **Não há portão antes da construção.** A 5b do Gerente vem antes da ficha e confere "fluxo e escopo". Nada confere, depois da ficha e das respostas, se os 5 arquivos estão em dia.
3. **O `DESIGN.md` não tem fluxo de mudança:** quem escreve, quem revisa, quando precisa do "sim" do dono.
4. **Ninguém orquestra o paralelismo.** A conversa principal lança agentes, mas não há regra de "um arquivo por agente".
5. **O Analista grava a palavra do dono sem conferir no `DESIGN.md`.** Essa é a origem do "+ Novo".
6. **O relatório do Revisor de design não fica guardado.** Só sobra "Libera com ressalvas" no cabeçalho da ficha, sem os 8 itens do §10 respondidos um por um.

### 3.3 Regra escrita que ninguém cumpre por falta de trava

| Regra | Onde está | Por que não pega |
|---|---|---|
| "Toda resposta do dono vai, na hora, para o arquivo" e "antes da construção o Gerente confere" | só em `docs/decisoes/` (pedido de 28/11) | não está em `processo-sdd.md`, nos agentes, nas skills nem no `tasks.md` |
| "Peça fora do `DESIGN.md` não se usa; entra primeiro, com o dono" | cabeçalho do `DESIGN.md`, §10 item 8 | o Designer grava "decisão do Designer" direto; o Revisor libera imagem com opção fora da regra quando ela vem "como pergunta" |
| "Tela: 3 paradas do dono" | `processo-sdd.md` §4 | a Agenda já teve E54, E55, E57, E58, E59, E60 e E63; ninguém conta |
| "Aprovação depois da ficha" (etapa 6 → 7) | `processo-sdd.md` §2 | aprovação em bloco de 10 specs antes das fichas |
| "Quem constrói não revisa", "escopo estrito" | `AGENTS.md` §3 e §6 | sem trava automática: `.claude/settings.json` e os hooks não existem (E38·A1 pendente); o `.githooks` só vale com `git config` manual |
| Assumptions sem tela, acesso ou dado | `AGENTS.md` §4 e §5 | a Assumption 6 (tela) passou pela 5b |

---

## 4. Causas e travas propostas

| Falha | Causa raiz | Trava |
|---|---|---|
| a. "Novo" × "Adicionar" | (1) contradição escondida no `DESIGN.md`; (2) Analista gravou a palavra do dono, não a intenção; (3) Designer mostrou a opção fora da regra como imagem principal e recomendou mudar a regra | T1, T7, T8 |
| b. Revisor de design não pegou | checklist §10 item 8 genérico; opção fora da regra "como pergunta" passou; relatório sem rastro | T1 |
| c. Respostas só na conversa | não há etapa nem dono para "depois da resposta" | T3 |
| d. Plano não atualizado | passagem por nota ("Para o Arquiteto") sem quem a dispare; não há portão | T3, T4 |
| e. Dois agentes no mesmo arquivo / `git stash` | agentes em paralelo na mesma pasta de trabalho, sem regra nem trava; no reflog, `HEAD@{10}: reset: moving to HEAD` entre `501c5a3` e `1ecf1b6` é a marca do `git stash` | T6 |
| f. Spec com §14 a §19 | aprovação antes da ficha e falta de regra de "mudança depois da aprovação"; o costume do Spec Kit de acrescentar "Clarifications" virou seções inteiras | T5 |

### Textos exatos propostos

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

Mudanças técnicas e de texto, sem regra nova:
- tirar as frases velhas da spec §4;
- pôr o `daf9bd2` no cabeçalho do `plan.md` e do `tasks.md`;
- corrigir `src/app/AGENTS.md` (larguras), `ARCHITECTURE.md` §11, `processo-sdd.md` §6 e o cabeçalho do `CONTRIBUTING.md`;
- passar o comportamento de tela do ADR 0006 · D18 para a spec e a ficha (T7);
- usar uma pasta de trabalho separada (`git worktree`) por agente que escreve em paralelo (ADR do DevOps).

---

## 5. O que precisa do dono e o que é técnico

**Precisa de aprovação do dono (muda regra aprovada):**
- `AGENTS.md` §4 e §6 (T5, T6): o próprio arquivo pede decisão registrada em `docs/decisoes/`.
- `docs/guias/processo-sdd.md` etapas 6, 7 e 7b (T2, T4, T5), aprovado na E11.
- `DESIGN.md` §10 item 9 (T1) e as respostas da ficha T7 (tela).
- Agentes e skills aprovados na E12 e na E16: `revisor-design.md` (T1), `designer-produto.md` (T2), `analista-requisitos.md` (T8), `falar-com-o-dono` (T3), `construir-tarefa` (T4).
- `docs/moldes/pergunta.md`, só se o dono quiser escrever no molde "Ficha visual" a regra "imagem principal = `DESIGN.md`; alternativa marcada 'muda regra aprovada'" (repete a T1; opcional).

**Recomendação:** uma mensagem só ao dono, com um código para o pacote T1 a T8 (sim ou não por número). A ficha T7 vai como parada própria, porque é de tela.

**Técnico (o papel decide, registra e avisa em uma linha):**
- a negação de `git stash` no `.claude/settings.json`, dentro do PR da E38·A1, que o dono já aprovou;
- `git worktree` por agente (ADR do DevOps);
- reescrever a spec da Agenda limpa, juntando §14 a §19 sem mudar o conteúdo: texto do Analista, revisado por outro papel;
- acertar o cabeçalho do plano e das tarefas;
- corrigir as linhas velhas em `src/app/AGENTS.md`, `ARCHITECTURE.md` §11, `processo-sdd.md` §6 e `CONTRIBUTING.md`. São correções de fato em arquivo aprovado: outro papel revisa e o dono é avisado em uma linha.

**Não verificado:**
- a conversa com o dono (só o que foi gravado no repositório);
- as imagens PNG, uma por uma (a comparação foi pelo texto da ficha e pelos nomes dos arquivos);
- os relatórios do Revisor de design das rodadas 1 a 3, que não estão no repositório.
