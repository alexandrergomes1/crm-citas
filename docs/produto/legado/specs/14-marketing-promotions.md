# Spec 14 - Marketing, promoções, cupons e reviews

## Goal

Permitir campanhas segmentadas e benefícios rastreáveis sem misturar desconto
manual, cupom, oferta, vale-presente ou pedido de avaliação.

## Business Rules

- Cupom possui código opcional, validade, elegibilidade, limite e serviços.
- Oferta registra motivo comercial e patrocinador.
- Vale-presente mantém saldo financeiro próprio.
- Campanhas respeitam consentimento, opt-out, frequência e limite diário.
- Pedido de review não pode filtrar clientes para manipular avaliação pública;
  o fluxo deve respeitar as políticas da plataforma de reviews.

## Data

`campaigns`, `segments`, `coupons`, `offers`, `message_jobs`, `review_requests`,
`marketing_opt_outs`, `audit_logs`.

## Status

Segmentos derivados e vale-presente básico existem. Campanhas, cupons, ofertas,
reviews e automações estão planejados após mensageria P2.

## Acceptance Criteria

- [ ] Benefício aplicado fica identificado na comanda.
- [ ] Campanha registra público, consentimento, resultado e falhas.
- [ ] Não há envio duplicado por atendimento.
