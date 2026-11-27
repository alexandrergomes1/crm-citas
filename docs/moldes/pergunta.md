# Molde de mensagem ao dono

Toda parada do dono é **uma mensagem só**, autossuficiente (dá para responder sem ler a conversa), legível no celular, e sai junto com o aviso no celular. Termo técnico usual com a explicação entre parênteses na primeira vez da conversa, ex.: "merge (juntar uma branch na outra)".

**Só se pergunta** o que aparece na tela, dinheiro, dado de cliente ou de saúde, acesso, produção e a ordem da fila. Decisão técnica não é pergunta: a IA decide e avisa em uma linha.
**Resposta:** "sim" vale quando a mensagem tem uma única pergunta com uma recomendação. Com mais de uma escolha, o dono responde com os códigos (ex.: "P1·A, P2·B") ou palavras próprias. Se a resposta não casa com nenhuma opção, pergunte de novo só aquele ponto.
**Registro:** na spec (seções "Clarifications", "Aprovação do dono" e "Aprovação do merge") ou, fora de spec, em `docs/decisoes/` (molde `decisao.md`), no PR da tarefa. Nunca PR à parte.

## Aprovação de spec e plano (com as dúvidas)
**Aprovação: [nome da tarefa] (item #NNN da fila)**
- **O que muda para você:** 2 a 4 linhas, em português simples (o plano em resumo de leigo).
- **Dúvidas** (no máximo 3), cada uma:
  - **P1 · [assunto]:** pergunta em uma frase. **P1·A:** … → o que acontece · **P1·B:** … → o que acontece. **Recomendo P1·A:** motivo em uma frase.
- **O que a IA decidiu sozinha (suposições):** lista curta; recuse qualquer uma pelo número.
- **Risco e como se desfaz:** uma ou duas linhas.
- **Parecer do revisor:** quem revisou e "nenhum Bloqueia" ou o achado.
- **Responda:** sem dúvidas, "sim" aprova; com dúvidas, os códigos de cada uma (ex.: "P1·A, P2·B, aprovo").

## Pergunta avulsa (o que a spec não cobre, ordem da fila, regra)
**Pergunta [código]: [assunto em até 8 palavras]** · O que é · Como está hoje (fato, com arquivo ou imagem) · Opções com o código completo e o que acontece em cada uma · Desfaz-se assim · Recomendação (motivo técnico ou de produto, nunca "já foi aprovado antes").

## Variante: ficha de tela
Formato completo em `docs/guias/telas.md` §2 (no Claude Code, pela skill `design-decision`). Até 4 decisões por ficha, cada uma com código (AG4, opções AG4·A, AG4·B), imagem real de hoje e de cada opção nas duas larguras, o que muda na tela e recomendação. A linha de base aparece como fato, não como pergunta. Uma vez por ficha: impacto, desfaz-se assim e parecer do `design-critic`.

## Variante: ficha curta do módulo (passado, uma vez por módulo)
**Base do módulo [nome]: está certo assim?** · imagem do que o app (`previas`) mostra hoje, nas duas larguras · resumo em até 6 linhas do que o arquivo do módulo diz, com o que ainda está "a confirmar" · onde o app e o arquivo divergem, se houver.
- **Sim:** fecha o passado deste módulo; vira a linha de base e não volta como pergunta.
- **Não:** diga o que muda; vira tarefa (ou entra na tarefa em curso, se couber nela).
- **Recomendação** em uma frase. Registro em `docs/decisoes/AAAA-MM-DD-base-<módulo>.md`.

## Variante: pedido de merge
**Merge do PR nº [n] ([código, ex.: M12]): [o que entra, em até 8 palavras]** · link do PR · commit `[SHA curto]`
- **O que entra:** em português simples; em tela, o link da prévia da branch para conferir antes do merge, mais as capturas da CI nas duas larguras.
- **Prova:** CI verde no commit citado; veredito do `critico-qa`; o que ficou "não verificado".
- **Conflita com outro PR aberto?** sim (qual) ou não.
- **Risco e como se desfaz.** · **Recomendação.**
- **Para autorizar:** responda "[código] juntar" (ou "sim"). A IA grava a sua resposta na spec e junta esse commit; qualquer mudança depois dele pede revisão e pedido novos.

## Variante: pedido de publicação (produção)
**Publicar na produção: PR nº [n] `previas` → `main` ([código])** · link do PR · commit `[SHA curto]`
- **Módulos ou recursos fechados que vão**, cada um com a data em que o dono os viu na prévia. · **Migrations que vão junto** (ou "nenhuma").
- **O que o cliente vai notar.** · **Risco e como se desfaz.** · **Recomendação.**
- **Para autorizar:** responda "[código] publicar" (ou "sim"). A IA grava a resposta em `docs/decisoes/AAAA-MM-DD-publicacao-pr-N.md` num PR pequeno à `previas` (só esse arquivo), junta-o e depois junta a publicação com merge commit (nunca squash).

## Proibido
- Mais de uma mensagem por parada, ou mais de 3 dúvidas por spec (fora a ficha, até 4 decisões).
- Pergunta sobre o que já está na linha de base ou já respondido, sem o dono pedir.
- Pergunta visual sem imagem de antes e depois.
- Decisão antiga como motivo da recomendação; resumo que esconde o que muda.
