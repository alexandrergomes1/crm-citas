---
name: falar-com-o-dono
description: "Montar a mensagem ao dono do crm-citas em toda parada (pergunta, ficha visual, aprovação da spec, pedido de merge ou de publicação), pelo molde docs/moldes/pergunta.md. Use sempre que for parar esperando o dono."
---
> Rascunho para o dono aprovar (E16). Escrito por: Arquiteto de software · Revisado por: (a preencher)

Receita: só aponta. A regra vale onde está escrita: `AGENTS.md` §5 e §7 e `docs/moldes/pergunta.md`.

1. **Pode perguntar?** Só sobre tela, dinheiro, dado de cliente ou de saúde, acesso, produção e ordem da fila. Decisão técnica não se pergunta: decida pela norma, registre e avise em uma linha (`AGENTS.md` §5).
2. **Já respondido?** Procure em `docs/decisoes/` e na spec. Resposta registrada não volta como pergunta (`AGENTS.md` §5).
3. **Escolha o molde** da parada em `docs/moldes/pergunta.md`: pergunta, ficha visual, aprovação da spec, pedido de merge ou de publicação.
4. **Abra com** o código, o assunto e qual papel fala e qual norma seguiu (`AGENTS.md` §3 item 5; molde, "Regras de toda mensagem").
5. **Escreva curto**, legível no celular: o que é, como está, opções com código, o que acontece em cada uma, como se desfaz, recomendação, quem revisou (`AGENTS.md` §7).
6. **Nada de lista ou documento longo:** o detalhe fica no arquivo, com o link (`AGENTS.md` §7). No máximo 3 dúvidas por spec, juntas (`AGENTS.md` §4).
7. **Uma mensagem por parada**, que se entende sozinha (molde, "Regras de toda mensagem").
8. **Avise no celular** em uma linha, sem dado pessoal, pelo meio de aviso da ferramenta em uso; sem ele, diga ao dono em uma linha que não pôde avisar (`AGENTS.md` §7).
9. **Pare** até a resposta. Depois, `documentador` registra (`.claude/agents/documentador.md`).

- Termo técnico com uma linha de explicação na primeira vez (`AGENTS.md` §7).
- Pedido para o dono fazer algo: link, cliques e nomes exatos (`AGENTS.md` §7).
- Proibido o que está em "Proibido" do molde.
