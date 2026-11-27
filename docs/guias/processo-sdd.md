# Guia · Processo (Spec-Driven Development)

Spec = o documento que diz o que vai ser feito, aprovado pelo dono antes de qualquer código. A regra zero e as paradas do dono estão no `AGENTS.md` §2–3; aqui fica o passo a passo.

## Motor: GitHub Spec Kit
- Versão fixa **v1.4.4**. Instalar ou atualizar (só numa tarefa com spec): `uv tool install specify-cli --from git+https://github.com/github/spec-kit.git@v1.4.4` e `specify init --here --integration <IA usada>` (hoje: `claude`). `.specify/` e as skills geradas vão para o Git; ninguém edita as geradas: ajuste só por `.specify/templates/overrides/`.
- Cada tarefa em `specs/NNN-nome/` (`spec.md`, `plan.md`, `tasks.md`), numeração por data e hora. "A spec" = essa pasta aprovada. `.specify/feature.json` não vai para o Git: na construção, a pasta se aponta com `SPECIFY_FEATURE_DIRECTORY=specs/NNN-nome`.
- A branch tem o nosso nome (`git-e-deploy.md`); a extensão `git` do Spec Kit não se instala.
- Não se usam: `constitution` (a constituição é o `AGENTS.md`), `clarify` (pergunta uma a uma; aqui as dúvidas vão juntas), `converge` (cria tarefas sozinho) e `checklist` (os revisores fazem esse papel).

| Etapa | Comando do Spec Kit | Nossa camada |
|---|---|---|
| Planejar | `specify` | branch; ficha antes, se for tela; até 3 dúvidas |
| Plano e tarefas (menos spec curta) | `plan` → `tasks` → `analyze` | revisor da spec, se o tipo pede |
| Aprovação | — | uma mensagem: dúvidas + spec e plano em resumo + suposições |
| Construir | `implement` | guia do tipo, só arquivos permitidos |
| Revisar · merge | — | revisores do tipo + veredito; pedido de merge; o dono autoriza; merge (`git-e-deploy.md`) |

## Tipos de trabalho
| Tipo | Nível | Seção extra da spec | Guia que se segue | Prova / pronto quando |
|---|---|---|---|---|
| Tela | B (C se tocar banco ou servidor) | estados (carregando, vazio, erro, sucesso), larguras, imagem aprovada, inventário de recursos | `telas.md` + `DESIGN.md` | CI com capturas nas duas larguras |
| Funcionalidade (regra, servidor) | C | contrato, quem pode, erros | `servidor.md` | CI (testes da spec) |
| Dados (banco) | C | tabela, isolamento entre estúdios, migração, volta atrás | `banco.md` | CI (banco do zero com testes) |
| Integração | C | serviço, credencial, falha e repetição, registro de envio | `servidor.md` | CI + teste no ambiente de testes do serviço |
| Manutenção e bug | B | o que está errado, como saber que ficou pronto | o da área do arquivo; bug: depurar com método antes de corrigir | CI |
| Porte do sistema antigo | conforme o tipo | origem e destino | `porte.md` | CI com capturas |
| Configuração, trava, CI | C | o que muda no comportamento da IA | `.claude/hooks/TRAVAS.md` | CI (testes das travas) |
| Documento | A | o que muda e por quê | — | spec cumprida, só arquivos permitidos |
Nível: A só texto · B código sem banco e sem servidor · C banco, servidor, dinheiro, acesso, login, páginas públicas, integração, ficha de saúde. Revisores de cada tipo: `revisao.md`. Camadas de teste: `testes.md`.

**Spec curta** (só `spec.md`, molde `docs/moldes/spec-curta.md`: o quê · arquivos · pronto quando, com a aprovação do dono). Lista fechada: correção de texto, link, biblioteca sem mudança de comportamento, documento. Nunca tela, banco, dinheiro ou acesso.

## Planejar (até a aprovação)
1. **Origem:** 1º item livre de `docs/BACKLOG.md` ou pedido do dono com a citação literal.
2. **Conferências:** `node scripts/conferir-pedido.mjs planejar --branch <branch>`. Barra, com o motivo, quando: **teto de PRs** — já há 3 outros PRs de trabalho abertos, sem contar o desta branch (Dependabot não conta); **colisão** — outro PR aberto, ou branch com envio nos últimos 7 dias, mexe nos mesmos arquivos (documentos de controle não contam); nome de branch fora do padrão. Barrou: avise o dono e pare.
3. Crie a branch a partir da `previas` (`git-e-deploy.md`).
4. **Primeira tarefa num módulo** (não existe `docs/decisoes/*-base-<módulo>.md`): a ficha curta do módulo (molde `docs/moldes/pergunta.md`, variante "ficha curta do módulo") é a primeira parada. "Sim": o passado vira linha de base. "Não": as mudanças entram nesta tarefa se couberem; senão viram item da fila na posição que o dono disser. Não se repete no mesmo módulo.
5. **Tela:** antes da spec, a ficha visual (`telas.md`), criticada pelo revisor de design. Parada. A escolha vai em "Clarifications".
6. **Spec, plano e tarefas:** leia a linha de base (item da fila, `docs/produto/`, o `AGENTS.md` da pasta, o arquivo do módulo em `docs/produto/modulos/`, a tela de hoje no código); ela vai em "Como está hoje" e não se pergunta de novo. A spec diz o quê, sem técnica; "Arquivos permitidos", "Como verificar", "Riscos" e a parte técnica do tipo vão no plano (molde `.specify/templates/overrides/`). Rode plano, tarefas e análise sem esperar as respostas, marcando o que depende de cada dúvida.
7. **Dúvidas:** até 3 `[NEEDS CLARIFICATION]`, só nos assuntos de pergunta do `AGENTS.md` §3, cada uma com 2 ou 3 opções e recomendação. O resto vai em "Assumptions".
8. **Revisor da spec**, se o tipo pede (`revisao.md`). Lacuna que ele aponta entra como dúvida, dentro do mesmo limite de 3; passou, a tarefa se divide ou para.
9. **Aprovação:** uma mensagem só, no molde `docs/moldes/pergunta.md` ("Aprovação de spec e plano"): o que muda em resumo de leigo, dúvidas com recomendação, suposições, risco e parecer do revisor. Parada.
10. **Resposta:** grave em "## Clarifications" no formato do Spec Kit (`### Session AAAA-MM-DD` · `- Q: … → A: … ("resposta literal")`), aplique na spec e no plano e preencha "Aprovação do dono" (literal, data, link da conversa) e "Status: Approved" só quando a resposta aprovar. Se a resposta mudou o escopo, mostre só o que mudou e pergunte de novo. Commit e envio com os documentos de controle.

## Construir (spec aprovada)
1. `node scripts/conferir-pedido.mjs construir --spec specs/NNN-nome` (confere também a "Aprovação do dono"). Barrou: avise e pare.
2. Execute a spec (`implement`; spec curta: edição direta), seguindo o guia do tipo. A pasta `specs/NNN-nome/` é sempre permitida (marcar tarefas feitas); mudar `.gitignore` e parecidos só se a spec pedir. Teste antes do código onde a spec pede.
3. **Só os "Arquivos permitidos".** Precisou de outro, ou a spec não cobre: pare e leve a pergunta ao dono no molde. Nunca o "mais provável".
4. Antes de enviar: `pnpm typecheck`, `pnpm lint`, `pnpm test`. Falhou: corrija dentro da spec ou relate.
5. Commits pequenos citando a spec; envie só a branch da tarefa. Atualize os documentos de controle na mesma branch.
6. PR para a `previas`, fora de rascunho; espere a CI.
7. **Revisão:** revisores do tipo em paralelo, depois o veredito (`revisao.md`). REPROVADO: corrija e revise uma vez, só o diff da correção; reprovado de novo, pare e relate ao dono.
8. **Fechamento:** veredito APROVADO, CI verde no último envio, `git status` sem segredo nem arquivo fora da spec.
9. **Pedido de merge, autorização, registro e merge:** `git-e-deploy.md`.
10. Depois do merge: link da prévia ao dono. Ajuste pedido depois de ver a prévia é tarefa nova, com a frase dele como pedido; sem ficha visual quando a frase já diz o que fica na tela.

## Onde se registra cada resposta
| Resposta | Onde | Quem grava |
|---|---|---|
| Dúvida e escolha da ficha de uma spec | spec, "Clarifications" | quem escreve a spec |
| Aprovação da spec | spec, "Aprovação do dono" + "Status: Approved" | quem escreve a spec |
| Autorização do merge | spec, "Aprovação do merge" (`git-e-deploy.md`) | quem pede o merge |
| Ficha curta do módulo | `docs/decisoes/AAAA-MM-DD-base-<módulo>.md` | quem cuida do controle |
| Ordem da fila, regra geral | `docs/decisoes/` (molde `docs/moldes/decisao.md`) | quem cuida do controle |
| Publicação | `docs/decisoes/AAAA-MM-DD-publicacao-pr-N.md` (`git-e-deploy.md`) | quem pede a publicação |
| Decisão técnica | suposição na spec ou `docs/adr/` (molde `docs/moldes/adr.md`) | a IA, avisando em uma linha |
| Incidente | `docs/postmortems/` (molde `docs/moldes/postmortem.md`) | — |
- Tudo no commit da própria tarefa; nunca PR à parte (a única exceção é a publicação).
- Spec já na `previas`: "Aprovação do dono", "Clarifications" e "Aprovação do merge" não mudam (mudança é spec nova). Decisão já juntada não se apaga nem se reescreve: decisão nova com "Substitui". A CI confere (`.claude/hooks/TRAVAS.md` §4).
- Limite conhecido: a IA escreve com a conta do dono, então um registro falso é possível; ele fica no histórico do Git e passa pelos olhos do dono no pedido de merge.

## Documentos de controle
Lista única (os outros arquivos apontam para cá): `docs/BACKLOG.md`, `docs/ROADMAP.md`, `docs/STATUS.md`, `docs/OWNER.md`, `docs/decisoes/`, `docs/produto/modulos/`. Sempre na branch da tarefa em curso, no PR da própria tarefa, nunca em PR à parte.
- Fila: riscar o feito sem renumerar; item novo só a pedido do dono, na posição que ele disser.
- Estado: curto, só onde o trabalho parou. Perguntas abertas: no molde de pergunta.
- Arquivos de módulo: estado do recurso muda só com prova (spec aprovada, PR juntado, o dono viu na prévia). Nada se marca "a confirmar"; o que existe vale como está.
- Duplicação ou arquivo sem dono: não altere; aponte como proposta.

## Pastas e arquivo do módulo
| Pasta | Módulo | Arquivo do módulo |
|---|---|---|
| `src/workspace/agenda/` | Agenda e Agendamento | `age-agenda.md`, `agd-agendamento.md` |
| `src/workspace/clientes/`, `client-notes/` | Clientes | `cli-clientes.md` |
| `src/workspace/anamnese/`, `src/public-forms/` | Anamnese | `ana-anamnese.md` |
| `src/workspace/catalogo/` | Catálogo | `cat-catalogo.md` |
| `src/workspace/financeiro/` | Financeiro, Caixa, Comanda | `fin-financeiro.md`, `cai-caixa.md`, `com-comanda.md` |
| `src/workspace/cobrancas/`, `src/public-pay/` | Cobranças | `cob-cobrancas.md` |
| `src/workspace/mensagens/` | Mensagens | `msg-mensagens.md` |
| `src/workspace/marketing/` | Marketing | `mkt-marketing.md` |
| `src/workspace/fidelidade/` | Fidelidade | `fid-fidelidade.md` |
| `src/workspace/ajustes/` | Ajustes, Equipe | `aju-ajustes.md`, `eqp-equipe-acessos.md` |
| `src/app-shell/` | Navegação | `nav-navegacao.md` |
| `src/design-system/`, `src/styles/` | Design system | `ds-design-system.md` |
| `src/domain/` · `src/data/` · `src/server/` · `supabase/` | regras · banco · servidor · migrations | `docs/reference/` |

Os arquivos de módulo ficam em `docs/produto/modulos/` e são a linha de base (`AGENTS.md` §3). **Toda pasta com `AGENTS.md` (regras da pasta, para qualquer IA) tem ao lado um `CLAUDE.md` com só a linha `@AGENTS.md`**, para o Claude Code ler as mesmas regras.

## Fila parada
Primeiro item parado esperando o dono: avise e siga para o próximo item, na ordem, se estiver livre e não depender da resposta pendente; na dúvida, pare.

## Moldes
Mensagem ao dono (aprovação, pergunta avulsa, ficha, ficha curta do módulo, pedido de merge, pedido de publicação): `docs/moldes/pergunta.md`. Decisão fora de spec: `decisao.md`. Spec curta: `spec-curta.md`. ADR: `adr.md`. Incidente: `postmortem.md`. Spec e plano: `.specify/templates/overrides/`. Tarefas: o do Spec Kit. PR: `.github/pull_request_template.md`.

## Papéis
A conversa principal orquestra os papéis: quem escreve spec e plano, quem constrói, os revisores do tipo de trabalho (`revisao.md`), quem dá o veredito e quem cuida dos documentos de controle. Quem constrói não revisa (`AGENTS.md` §4).

No Claude Code, este fluxo roda pelas skills `sdd-planejar` e `sdd-construir` e pelos agentes `arquiteto` (spec e plano), `construtor` (execução), os revisores do tipo, `critico-qa` (veredito) e `organizador` (controle).

## Origem
`.claude/skills/sdd-planejar/SKILL.md` · `.claude/skills/sdd-construir/SKILL.md` · `.claude/agents/arquiteto.md`, `construtor.md`, `organizador.md` · `docs/projeto/estrutura.md` §Pastas (tabela pasta → arquivo do módulo; `CLAUDE.md` com `@AGENTS.md`) · `CLAUDE.md` atual (a conversa principal orquestra) · `docs/projeto/tecnico.md` §Spec Kit, §Aprovação e registro, §Fila, §Conferências · `docs/moldes/*` · `.claude/hooks/TRAVAS.md` §4–5 · `scripts/conferir-pedido.mjs` · `AGENTS.md` §2–3.
