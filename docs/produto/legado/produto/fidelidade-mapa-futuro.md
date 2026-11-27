# Fidelidade — mapa de recursos e configurações (futuro)

Status: **mapeamento** (sem implementação). Base atual: pontos, extrato (ledger), ajuste manual e 4 níveis fixos
(Classic, Silver, Gold, Black) — ver `docs/specs/15-loyalty-rewards.md`. Esta página lista o que um módulo de
fidelidade completo precisa ter, no estilo Fresha/Booksy, para virar specs por incremento.

Fidelidade vive dentro do menu **Marketing** (ver `docs/specs/28-navegacao-marketing-ajustes.md`).

## 1. Como a cliente ganha (regras de acúmulo)
- Pontos por valor gasto (ex.: 1 ponto a cada 1 €), configurável por org.
- Multiplicador por serviço/categoria/produto, por nível, por dia da semana ou período (campanha "pontos em dobro").
- Pontos por ação: primeira visita, indicação aprovada, avaliação publicada, aniversário, ficha preenchida.
- Teto por comanda e por período; arredondamento; o que **não** pontua (pacote já pago, brinde, desconto total).
- Estorno/cancelamento gera lançamento inverso (já previsto na spec 15).

## 2. Níveis (tiers)
- Criar/editar níveis: nome, cor, faixa de pontos **ou** gasto acumulado em 12 meses.
- Benefícios por nível: multiplicador, desconto fixo, prioridade na lista de espera, brinde de aniversário.
- Regra de subida/descida: imediata ou recalculada mensalmente; período de carência antes de rebaixar.
- Aviso automático (WhatsApp/e-mail) ao subir de nível.

## 3. Recompensas e resgate
- Catálogo: desconto em €/%, serviço grátis, produto, upgrade, vale-presente.
- Custo em pontos, validade, limite por cliente/mês, nível mínimo, serviços elegíveis, estoque (quando produto).
- Resgate **na comanda** (mesma transação), com estorno devolvendo pontos e benefício.
- Resgate manual pela recepção e autoatendimento (portal/reserva online no futuro).

## 4. Validade e saldo
- Expiração configurável (nunca, 6/12/24 meses), expiração por lote (FIFO), aviso de pontos a vencer.
- Saldo, extrato explicado por movimento, ajuste manual com motivo e auditoria (já existe).
- Bloqueio de resgate por fraude/abuso (cliente marcada, limite diário).

## 5. Indicação, aniversário e extras
- Código/link de indicação: pontos para quem indicou e para quem chegou, só após a primeira comanda paga.
- Bônus de aniversário (pontos ou brinde) com janela de validade; mensagem automática.
- Cashback opcional (saldo em € em vez de pontos) — decidir se coexiste ou substitui.
- Cartão/selo digital ("a 10ª limpeza é grátis") como modelo alternativo ao de pontos.

## 6. Comunicação (liga com Mensagens)
- Modelos: boas-vindas ao programa, pontos ganhos, pontos a vencer, subiu de nível, recompensa disponível.
- Canais e idiomas por cliente (pt-BR, EN, ES) — ver `docs/architecture/i18n-multiidioma.md`.
- Opt-in/opt-out (LGPD/GDPR) registrado; nunca mensagem de fidelidade sem consentimento de marketing.

## 7. Telas e configurações dentro do módulo
Seções sugeridas (padrão `SectionedPage`, com Fechar/Voltar):
1. **Visão geral** — pontos em circulação, clientes ativas, resgates do mês, passivo (pontos × valor do ponto).
2. **Clientes** — ranking, busca, extrato, ajuste (existe hoje).
3. **Regras** — acúmulo, multiplicadores, exclusões.
4. **Níveis** — criar/editar/benefícios.
5. **Recompensas** — catálogo e resgates pendentes.
6. **Indicação e aniversário**.
7. **Mensagens do programa** (atalho para modelos de Mensagens).
8. **Relatórios** — resgates, expiração, retorno (clientes do programa vs fora), custo do programa.

## 8. Permissões e auditoria
- `fidelidade.view`, `fidelidade.adjust`, `fidelidade.configure`, `fidelidade.redeem`.
- Toda alteração de regra, nível ou ajuste manual com audit log (spec 22).
- Regras versionadas: mudança vale daqui para frente, nunca reescreve o histórico.

## 9. Dados necessários (além do atual)
`loyalty_programs` (config por org), `loyalty_rules`, `loyalty_tiers` (editáveis), `loyalty_rewards`,
`loyalty_redemptions`, `loyalty_referrals`, lotes de pontos com validade em `loyalty_point_entries` (campo `expires_at`).
Tudo com `org_id` + RLS; RPCs `_atomic` para acúmulo e resgate dentro da comanda.

## 10. Ordem sugerida de entrega
1. Regras de acúmulo configuráveis + níveis editáveis.
2. Catálogo de recompensas + resgate na comanda (fecha os critérios abertos da spec 15).
3. Validade/expiração + avisos.
4. Indicação e aniversário.
5. Relatórios e mensagens do programa.
