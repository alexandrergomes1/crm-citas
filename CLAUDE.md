@AGENTS.md

## Só para o Claude Code
As regras são as do `AGENTS.md` e de `docs/guias/`. Aqui fica só o que existe no Claude Code.

- **Ao começar:** confira modelo e esforço da conversa (ferramenta `get_session`) contra a tabela abaixo; não bateu, diga ao dono em uma linha. Modelo só se troca logo depois do `/clear`, antes da primeira mensagem.

  | Trabalho | Modelo | Esforço |
  |---|---|---|
  | Nível C: banco, dinheiro, acesso, ficha de saúde | `claude-opus-5-5` | alto |
  | Decisão com o dono: ficha, spec, conferência contra a escolha dele | `claude-opus-5-5` | médio |
  | O resto: tela ou código com spec, texto, fila, manutenção | `claude-sonnet-5-5` | médio |

  Vale a primeira linha que casar, de cima para baixo. Pedido do dono vence a tabela. Agentes do fluxo herdam o modelo da conversa; revisores usam o modelo escrito no próprio arquivo.
- **Aviso no celular:** toda vez que parar esperando o dono (ficha, aprovação, pergunta, pedido de merge ou de publicação, erro que só ele resolve), chame a ferramenta `PushNotification` com uma linha: o que se espera dele e o código da pergunta. Nunca dado pessoal, de saúde ou segredo no aviso. Sem a ferramenta na sessão: diga ao dono em uma linha.
- **Plan Mode:** só para explorar antes da spec (ele só lê).
- **A conversa principal orquestra os papéis** (`docs/guias/processo-sdd.md` §Papéis) pelos agentes de `.claude/agents/`.
- **Agentes e skills ficam em `.claude/`** (`agents/`, `skills/`) e são cascas finas: cada um só diz "leia `docs/guias/<x>.md` e siga". Regra nova nunca nasce em `.claude/`. Fluxo: tarefa sem spec aprovada → skill `sdd-planejar`; spec aprovada → skill `sdd-construir` (as duas seguem `docs/guias/processo-sdd.md`). Skills `speckit-*` são geradas pelo Spec Kit: não se editam.
- Skill citada que não aparece na sessão: avise o dono em uma linha; o que dependia dela sai "não verificado". Plugins ligados neste projeto: os de `.claude/settings.json` (`enabledPlugins`).
- **Conversas:** depois do merge, proponha o `/clear` com o prompt pronto da próxima tarefa e o modelo; quem digita é o dono. Antes do `/clear`: nada pendente no `git status`; item pela metade marcado na fila; pergunta sem resposta em `docs/OWNER.md`. A IA nunca abre conversa (bloqueado em `.claude/settings.json`: conversa criada por outra nasce sem os plugins da conta).
- Travas de `.claude/hooks/` (`TRAVAS.md`) e bloqueios de `.claude/settings.json` não se contornam.

## Origem
`CLAUDE.md` atual · `docs/projeto/tecnico.md` §Modelos, §Conversas, §Plugins ligados, §Spec Kit · `docs/reference/project.md` §Pacotes de ferramentas · `docs/reorganizacao/06-plano-etapa5.md` §3 e §5b.
