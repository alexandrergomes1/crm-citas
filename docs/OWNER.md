# Owner (página do dono)

Para o Alexandre ler. Uma página, em linguagem simples. A IA atualiza no fim de cada tarefa. O histórico até 27/11
fica no repositório antigo `crm-agenda` (congelado, só consulta).

## Onde estamos
- **Agora:** a fundação do crm-citas (item 1 da fila), na branch `chore/base-fundacao`: regras, guias, travas,
  Spec Kit, app mínimo, banco copiado e CI. Nenhuma tela ainda.
- **Depois:** o design system no código, com a página "Peças" (item 2), e então um módulo por vez, cada um com spec
  própria, já no design novo.
- **Produção:** nenhuma. Nada vai para o ar sem você autorizar um pedido de publicação.

## O que você faz agora
Nada. Quando a fundação estiver pronta, a IA te manda o pedido de merge (juntar a branch na `previas`), com aviso no celular.

## Como você comanda
- **"Qual é a próxima?"** — a IA responde com a próxima tarefa e o porquê.
- **"Primeiro o X"** — a IA muda a ordem da fila.
- **Merge** (juntar um PR, pacote de mudança, na prévia): a IA sugere com CI verde e revisão feita; você autoriza com
  clareza no chat (o código do pedido). **Publicação** (levar à produção): do mesmo jeito.
- **"Sim"** vale quando a mensagem tem uma única pergunta com uma recomendação; com mais de uma, responda com os códigos.
- **"/clear"** — ao terminar uma tarefa, a IA avisa e você digita `/clear`; conversa nova só você abre.
- Você decide o que aparece na tela, dinheiro, dado de cliente, acesso, produção e a ordem. O resto a IA decide e te avisa em uma linha.

## Perguntas à sua espera
Nenhuma além das que vierem no pedido de merge da fundação.

## Só você pode fazer
- Criar no GitHub as branches `main` e `previas` (as duas a partir de `kabeauty1`, a única que existe hoje) e marcar `previas` como padrão: https://github.com/alexandrergomes1/crm-citas/branches → New branch → nome `main`, depois de novo com `previas`; por fim Settings → General → Default branch → `previas`. Sem a `previas`, não há PR nem merge da fundação.
- Mais tarde, as chaves da CI e da publicação (Supabase, Cloudflare) no GitHub: a IA te manda o passo a passo quando chegar a hora, nunca pelo chat.
