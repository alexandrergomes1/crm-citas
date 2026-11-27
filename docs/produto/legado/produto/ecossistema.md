# Ecossistema KA Beauty: visão e avaliação

Status: **pauta de projeto, não aprovada para construção** (29 out 2026). Registro pedido pelo
Alexandre. O foco atual continua sendo deixar o sistema estável, seguro e com os módulos
conversando; nada daqui entra na fila antes disso.

## A proposta

O estúdio compra ou assina o sistema e ganha, junto:

1. **Sistema operacional** (agenda, clientes, anamnese, comanda, financeiro): o que existe hoje.
2. **Site e página de agendamento próprios** (spec 38): a página do estúdio, com reserva online.
3. **Presença no marketplace** (spec 39): um portal público de busca onde clientes finais
   encontram estúdios e serviços, como Fresha, Booksy e Treatwell.
4. **Impulsionamento**: nós trazemos clientes finais para o marketplace e profissionais para o
   sistema (os dois lados).
5. **Ferramentas para o estúdio impulsionar o próprio site**: ligação com o projeto de
   marketing completo do Alexandre (o Gerador de site/Instagram e campanhas), oferecido como
   extra.

## Avaliação

**Faz sentido como direção.** É o mesmo desenho dos concorrentes que deram certo: o software
segura o estúdio (custo de troca alto) e o marketplace dá ao estúdio um motivo para pagar além
da operação. O diferencial que já está registrado na spec 39 (nunca cobrar comissão sobre
cliente que já é do estúdio, origem da reserva visível) é um bom argumento de venda contra
Fresha e Treatwell.

**Mas são produtos diferentes, com ordem obrigatória:**

| Peça | Onde vive | Quando faz sentido | Por quê |
|---|---|---|---|
| Sistema | Este repositório | Agora | Sem ele estável, nada abaixo se sustenta |
| Site + agendamento do estúdio (38) | Este repositório, módulo "Reserva online" | Depois do núcleo validado | Usa agenda, catálogo e regras de sinal do próprio sistema; é extensão natural |
| Marketplace (39) | Mesmo banco, app/rota pública separada | Só com vários estúdios ativos na mesma cidade | Marketplace com 1 estúdio não existe; é um problema de densidade, não de código |
| Impulsionamento (aquisição dos dois lados) | Operação de marketing, não código | Junto com o marketplace | Custo real é mídia e equipe, não software |
| Gerador / marketing do estúdio | **Projeto à parte**, integrado | Pode andar em paralelo, como produto próprio | Atende qualquer pequeno negócio, não só estética; não deve carregar as regras de saúde e RGPD do sistema |

**Recomendação:** manter o Gerador e as campanhas como projeto separado (repositório e
produto próprios), ligado ao sistema por pontos de integração claros, em vez de fundir tudo:

- link de agendamento e catálogo do estúdio publicados pelo sistema e consumidos pelo site;
- origem da reserva (`booking_source`) gravada pelo sistema, para o estúdio ver o que cada
  campanha trouxe;
- avaliações verificadas (spec 39, M2) e pedido de avaliação no Google (já existe) alimentando
  a prova social do site;
- conta única no futuro, quando os dois produtos tiverem clientes pagantes.

Assim cada produto pode ser vendido sozinho, o sistema não herda a complexidade do Gerador, e
a integração vira argumento de pacote ("Completo + Marketing").

## Riscos

- **Dispersão de foco:** quatro frentes com um time pequeno. Mitigação: ordem acima, uma por vez.
- **Ovo e galinha do marketplace:** sem clientes finais o estúdio não vê valor; sem estúdios a
  cliente não acha nada. Começar por uma cidade (Costa del Sol) e pelo diretório (M0) sem
  conta de consumidora.
- **Concorrência estabelecida na Espanha:** Treatwell e Fresha já têm tráfego. O caminho é
  nicho (micropigmentação, estética avançada) e regra justa de comissão, não volume.
- **Dados de saúde:** nada clínico sai do estúdio para o marketplace ou para o Gerador (regra já
  escrita na spec 39).
- **Custo de infraestrutura** sobe com tráfego público anônimo: ver o comparativo de hospedagem
  e banco em `docs/infra/`.

## Próximo passo quando for a hora

Decidir o modelo de receita do pacote (assinatura com site incluído, extra "Reserva online",
taxa por cliente nova do marketplace) e fazer 5 a 10 entrevistas com donas de estúdio antes de
escrever spec nova.
