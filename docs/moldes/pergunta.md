# Molde de mensagem ao dono

> **Rascunho para o dono aprovar (E9).** Regra: `AGENTS.md` §7. Vale para toda parada em que a IA espera o dono.

## Regras de toda mensagem
- **Uma mensagem por parada**, que se entende sozinha, sem ler a conversa, e cabe no celular.
- Começa com o **código e o assunto**, e diz **qual papel fala**.
- Termo técnico com uma linha de explicação na primeira vez.
- **Nunca** uma lista ou um documento longo: o detalhe fica no arquivo, com o link; a mensagem resume.
- Cada escolha tem código (ex.: E9·A). Com uma pergunta só e uma recomendação, "sim" vale; com mais, o dono
  responde com os códigos.
- Sai junto com o aviso no celular.

## Pergunta ou aprovação
**[Código] · [assunto em até 8 palavras]** (fala o [papel])
- **O que é:** uma ou duas linhas.
- **Como está hoje:** o fato, com o link do arquivo ou a imagem.
- **Opções:** **[Código]·A** … → o que acontece · **[Código]·B** … → o que acontece.
- **Recomendo [A]:** o motivo, com a norma ou o fato (nunca "já foi decidido antes").
- **Desfaz-se assim:** uma linha.
- **Responda:** o formato exato da resposta.

## Pedido de merge
**Merge do PR [nº] ([código]) · [o que entra, em até 8 palavras]** (fala o Gerente de projeto)
- Link do PR e commit `[SHA curto]`.
- **O que entra:** em português simples; em tela, o link da prévia.
- **Prova:** CI verde no commit citado; veredito do QA; o que ficou "não verificado".
- **Risco e como se desfaz.** · **Recomendação.**
- **Responda:** "[código] juntar". A IA grava a resposta na spec e junta só esse commit.

## Pedido de publicação (produção)
**Publicar: PR [nº] `previas` → `main` ([código])** (fala o Engenheiro de DevOps)
- O que vai, o que o estúdio vai notar, mudanças de banco junto (ou "nenhuma").
- **Risco e como se desfaz.** · **Recomendação.**
- **Responda:** "[código] publicar".

## Proibido
- Mais de uma mensagem por parada; mais de 3 dúvidas por spec.
- Perguntar o que já foi respondido, sem o dono reabrir.
- Pergunta visual sem imagem de antes e depois.
- Resumo que esconde o que muda.
