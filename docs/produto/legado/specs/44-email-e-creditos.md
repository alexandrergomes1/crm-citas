# Spec 44 · E-mail (Resend) e revenda de créditos

Status: e-mail implementado como base (30/10/2026); revenda mapeada, não construída. Fase atual: desenvolvimento.

## 1. E-mail agora

- Provedor: **Resend** (chave `RESEND_API_KEY`; remetente `EMAIL_FROM`, padrão `onboarding@resend.dev` só para teste). Plano grátis: 3.000/mês e 100/dia; pago US$ 20/mês (50.000).
- Tela: Mensagens › Canais › E-mail mostra estado e envia e-mail de teste. Resposta vai para o e-mail do estúdio (Ajustes › Estúdio).
- Todo envio grava `messaging_provider_log` (`channel = 'email'`, `provider = 'resend'`).
- O provedor fica atrás de `src/lib/email/resend.ts`; trocar por Brevo (`provider = 'brevo'` já aceito no banco) é trocar esse adaptador.

## 2. Revenda de créditos (mapa, estilo Fresha)

Modelo: a plataforma tem a conta no provedor; cada estúdio tem franquia grátis mensal por canal e, acima dela, compra crédito com cartão.

| Canal | Franquia grátis (ideia) | Acima disso | Custo do provedor |
|---|---|---|---|
| E-mail | Resend grátis enquanto couber; depois plano pago da plataforma | Pacote de e-mails | US$ 20/50 mil (Resend); SES US$ 0,10/mil |
| WhatsApp | 1.000 respostas de serviço por número (Meta) | Mensagens de modelo (utilidade/marketing) repassadas | Espanha: utilidade € 0,0166, marketing € 0,0585. Brasil: R$ 0,0350 e R$ 0,3217 |
| SMS | Nenhuma | Crédito pré-pago | Twilio: Espanha US$ 0,0875, Brasil US$ 0,0599 por segmento; Brevo vende por créditos (preço de Espanha/Brasil a confirmar na conta) |

Peças a construir depois: saldo e extrato por estúdio (`org_id`), consumo registrado no log, compra por cartão (Stripe), alerta de saldo baixo, módulo "Créditos" ligado por plano. Fase de desenvolvimento: sem cobrança real; o registro de envios já alimenta o consumo.
