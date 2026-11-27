# Molde de mensagem ao dono

> Aprovado pelo dono em 27/11/2026 (E9). Ajustes da revisão aprovados em 27/11/2026 (E12·2).
> Escrito por: Gerente de projeto · Revisado por: Gerente de projeto (outra instância, que não escreveu) ·
> Norma: Scrum Guide e Kanban. Regra: `AGENTS.md` §7. Vale para toda parada em que a IA espera o dono.

## Regras de toda mensagem
- **Uma mensagem por parada**, que se entende sozinha, sem ler a conversa, e cabe no celular.
- Começa com o **código e o assunto** e diz **qual papel fala e qual norma seguiu**.
- Termo técnico com uma linha de explicação na primeira vez.
- **Nunca** uma lista ou um documento longo: o detalhe fica no arquivo, com o link; a mensagem resume.
- Cada escolha tem código (ex.: E9·A). Com uma pergunta só e uma recomendação, "sim" vale; com mais, o dono
  responde com os códigos.
- Sai com o aviso no celular, em uma linha, sem dado pessoal; sem meio de aviso, diga ao dono em uma linha que não
  pôde avisar.

## Pergunta ou aprovação de arquivo
**[Código] · [assunto em até 8 palavras]** (fala o [papel] · norma [X])
- **O que é:** uma ou duas linhas. **Como está hoje:** o fato, com o link do arquivo ou a imagem.
- **Opções:** **[Código]·A** … → o que acontece · **[Código]·B** … → o que acontece.
- **Recomendo [A]:** o motivo, com a norma ou o fato (nunca "já foi decidido antes").
- **Revisado por:** o papel que conferiu e o que ele achou.
- **Desfaz-se assim:** uma linha. **Responda:** o formato exato.

## Ficha visual (só tela)
**[Código] · [tela]** (fala o Designer de produto · norma WCAG 2.2; já conferida pelo Revisor de design)
- Imagens de antes e depois, nas larguras de teste do `DESIGN.md`.
- Até 4 decisões, cada uma com código, opções e recomendação.
- **Desfaz-se assim** e **Responda**.

## Aprovação da spec
**[Código] · Aprovar a spec: [tarefa]** (fala o Analista de requisitos · norma IEEE 29148)
- Link da spec. **O que muda para você:** 2 a 4 linhas.
- **Dúvidas** (no máximo 3, juntas), cada uma com código, opções e recomendação.
- **O que o papel decidiu sozinho ("Assumptions"):** resumo curto, com link; recuse qualquer uma pelo número.
- **Revisado por** · **Risco e como se desfaz** · **Responda:** os códigos.
- A resposta é gravada na spec como "Aprovação do dono" (fala literal, data, link).

## Pedido de merge
**Merge do PR [nº] ([código]) · [o que entra, em até 8 palavras]** (fala o Gerente de projeto · norma Kanban)
- Link do PR e commit `[SHA curto]`. **O que entra:** em português simples; em tela, o link da prévia.
- **Prova:** CI verde no commit citado · prova do tipo (`AGENTS.md` §9) · revisores sem "Bloqueia" · veredito do
  QA · documentos de controle no PR · o que ficou "não verificado".
- **Risco e como se desfaz** · **Recomendação.**
- **Responda:** "[código] juntar". A IA grava em "Aprovação do merge" a fala literal, a data, o link e o commit, e
  junta só esse commit. Se outra mudança entrar na branch antes, a revisão e o pedido são refeitos.

## Pedido de publicação (produção)
**Publicar: PR [nº] `previas` → `main` ([código])** (fala o Engenheiro de DevOps · norma DORA)
- Link do PR e commit `[SHA curto]`. O que vai, o que o estúdio vai notar, mudanças de banco junto (ou "nenhuma").
- **Risco e como se desfaz** · **Recomendação.** · **Responda:** "[código] publicar".

## Proibido
- Mais de uma mensagem por parada; mais de 3 dúvidas por spec.
- Perguntar o que já foi respondido, sem o dono reabrir.
- Pergunta visual sem imagem de antes e depois.
- Resumo que esconde o que muda.
