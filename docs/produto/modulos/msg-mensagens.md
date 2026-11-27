# Módulo: Mensagens (MSG)

> Falar com a cliente por WhatsApp, e-mail e (talvez) SMS: conversas, modelos de texto, automações, lembretes e o histórico do que foi enviado.
> Hoje o sistema guarda modelos e testa o canal, mas **não envia nada sozinho**.

**Telas e rotas:** `/{org}/mensagens` (Conversas), `/mensagens/modelos`, `/mensagens/modelos/$id`, `/mensagens/automacoes`, `/mensagens/historico`, `/mensagens/canais`; webhook `/api/webhooks/whatsapp` · **Código:** `src/workspace/mensagens`, `src/lib/messaging`, `src/lib/email`, `src/domain/messaging*.ts`, `src/lib/client-messaging.ts` (link `wa.me`, só no antigo) · **Spec(s):** sem spec no atual. No legado: `docs/produto/legado/specs/13`, `43`, `44` (e `24`, `40`, `52`, `30` em partes).

Como ler a coluna Origem: "legado 43:10" = `docs/produto/legado/specs/43-whatsapp-qr.md` linha 10. "R4 B 43" = relatório R4, seção B, spec 43. "R5 B ..." = R5 seção B. Outros usam o caminho curto do arquivo.

## Recursos
| ID | Recurso | Estado | Onde | Origem |
|---|---|---|---|---|
| MSG-01 | Conversas: caixa tipo WhatsApp Web, com WhatsApp e e-mail juntos | planejado (antigo: "fora do escopo agora", legado 43:26,74) · desligado e só em mockup (atual) | `/mensagens` (`ConversationsView.tsx`) | legado 43:26,74; R3 B audit:29 (plano de recuperação); R1 B Main.dc.html |
| MSG-02 | Modelos de mensagem: criar, editar, prévia, variáveis | pronto (atual) · versão e idioma por modelo planejados (antigo) | `/mensagens/modelos`, `/modelos/$id` (`TemplateEditor.tsx`) | R3 B audit:29; legado 13:11; R5 B messaging-flow:129-205 (MSG-01) |
| MSG-03 | Automações: lista de regras que mandam mensagem sozinhas | parcial: a tela existe, a lista é fixa e mostra "0 ligadas" | `/mensagens/automacoes` (`AutomationsView.tsx`) | R3 B audit:29; R5 B scope-master:125 |
| MSG-04 | Motor de envio: fila, tentativas limitadas, sem envio duplicado, status guardado, um envio por ocorrência | planejado (antigo P2, "nunca feito") · planejado, "adiado de propósito" (atual) | sem tela; servidor | legado 13:10,23-24,28; R3 B audit:46; R2 B ICEBOX item 24 (`ICEBOX.md:31`) |
| MSG-05 | Lembretes e avisos automáticos: confirmação, lembrete (24 h antes), pós-atendimento, aniversário, recuperação de inativas, ficha 48 h antes, cuidados, retoque, "saudade" | planejado | Mensagens › Automações | legado 13:5-6; R5 B revisao-30-10:22; R5 B product-vision-detail:77-79; R5 B scope-master:125 |
| MSG-06 | Histórico de envios: quem, canal, modelo, cliente, agendamento, hora, status | pronto, base (`messaging_provider_log`) | `/mensagens/historico` (`HistoryView.tsx`) | legado 43:23, 44:9; R4 B 43, 44 |
| MSG-07 | Log honesto: "aberto no WhatsApp" nunca vira "enviado" sem confirmação do provedor | planejado | Histórico | R5 B messaging-flow:129-205 (MSG-02); R5 F (regra em 4 lugares); R1 B Main.dc.html |
| MSG-08 | Canal WhatsApp pela API oficial da Meta (Cloud API), com webhook assinado que atualiza entregue, lido, falhou | pronto, base; liga por variáveis do servidor (antigo) · existe no código, ligado a um número só para todos os estúdios (atual) | `/mensagens/canais` (`MetaCloudPanel.tsx`); `src/routes/api/webhooks/whatsapp.ts`; `src/lib/messaging/meta-cloud.server.ts` | legado 43:8-16; R4 B 43; R3 B audit:29 |
| MSG-09 | Canal WhatsApp por QR (WAHA): conectar, estados, desconectar, mensagem de teste | pronto, base (antigo) · descartado, "WAHA nunca" (atual); não há `waha.ts` no código | só no antigo | legado 43:18-26,28-50; R2 B stack:42 (`docs/reference/stack.md`); R3 B audit:46 |
| MSG-10 | Canal e-mail pelo Resend: teste de envio, resposta vai ao e-mail do estúdio; Brevo pode trocar | pronto, base (antigo) · existe (atual); "primeiro opção grátis" planejado (G5) | `/mensagens/canais` (`EmailChannel.tsx`, `EmailTestPanel.tsx`); `src/lib/email/resend.server.ts` | legado 44:5-10; R4 B 44; R1 B G5 (`reg:121`); R3 B fase1:117 |
| MSG-11 | SMS: só como plano B (lembrete crítico sem WhatsApp, depois de falha); sem SMS de marketing por padrão | planejado, sem decisão | sem tela | R5 B messaging-provider-research:84-106,177-185; R5 B scope-master:126 |
| MSG-12 | Revenda de créditos: franquia grátis por canal, pacotes acima, saldo e extrato por estúdio, compra por cartão (Stripe), alerta de saldo baixo, módulo "Créditos" | planejado ("mapeada, não construída") | sem tela | legado 44:3,12-22 |
| MSG-13 | Mensagens manuais: tela para mandar uma mensagem avulsa | planejado, sem item na fila | sem tela | R2 B ICEBOX item 41 (`ICEBOX.md:24`); R1 B reg:176 |
| MSG-14 | Link `wa.me` manual (abre o WhatsApp de quem atende); "manual link only until provider decision" | pronto (antigo, `src/lib/client-messaging.ts`) · usado nos botões da cliente (atual) | botão WhatsApp no cartão da cliente | R5 B roadmap:284; R3 B opm:408 |
| MSG-15 | Item "Mensagem no WhatsApp" no menu Ações da cliente (mesma lista nas duas telas do agendamento) | pronto na tela (inventário) · decisão AGS7 só em lote | Agendamento › Ações ▾ | `docs/design/inventario/agenda-e-agendamento.md:55`; R1 A AGS7 (`reg:106`) |
| MSG-16 | Enviar a ficha de saúde por WhatsApp (telefone com DDI; sem telefone, orienta cadastrar; não registra como enviado) | parcial (antigo) | Anamnese e Agendamento | R5 B agenda-operational-scope:415-427; R5 B messaging-flow:109-123 (MSG-00) |
| MSG-17 | Conversa operacional na agenda (histórico com a cliente dentro do agendamento) | planejado P2 ("ausente") | Agenda | legado 24:51,105,203 |
| MSG-18 | Lembrete "24 h antes" no menu Avisos e sinal: aparece ligado, mas sem motor por trás | pronto na tela, sem motor (antigo) | Agendamento › Avisos e sinal | legado 52:54-55; legado 40:46-47; R4 F |
| MSG-19 | Opt-out e preferência de canal por cliente (marketing separado do operacional) | planejado (antigo) · consentimento de marketing "só SIM" pronto em Clientes (atual) | Clientes; futuro Mensagens | legado 13:12,30; R5 B messaging-flow:209-249; R2 B STATUS:28 |
| MSG-20 | Modelos por idioma; WhatsApp exige modelo aprovado pela Meta em cada idioma | planejado | Mensagens › Modelos | `docs/produto/legado/produto/i18n-multiidioma.md:33`; legado 13:11 |
| MSG-21 | Camada n8n (webhook, retry, idempotência) entre o sistema e o provedor; n8n não é fonte da verdade | planejado, não decidido | sem tela | R5 B messaging-flow:129-205 (MSG-04); R5 B messaging-provider-research:49-82 |
| MSG-22 | Aviso ao estúdio quando chega comprovante de pagamento | planejado (depende de Mensagens) | `/pagar`; Cobranças | legado 30:62-63,100 |
| MSG-23 | Caixa de conversas, verificação de número, mídia, alerta de sessão caída (próximos passos do QR) | planejado, preso à decisão do QR | só no antigo | legado 43:26,58,74-76 |

"Estado" é o que os documentos dizem; o código é conferido quando o módulo entra em trabalho.

## Decisões
| ID | Decisão | Situação | Origem |
|---|---|---|---|
| MSG-D01 (G4) | WhatsApp por QR só para teste; para clientes, a API oficial | **sugestão a confirmar** (aceite em lote "aceito todas", 22/11; 04/11 e 13/11 sem frase) | R1 A G4 (`reg:120`); `docs/decisoes/historico/registro-ate-2026-11-24.md:120`; R3 B fase1:116 |
| MSG-D02 (G5) | E-mail: primeiro uma opção grátis (Mailchimp, Zoho, Google); Resend só se não houver outra. "Vale quando se ligar o e-mail." | **sugestão a confirmar** (lote; 04/11 sem frase). Conflita com a base já em Resend (MSG-10) | R1 A G5 (`reg:121`); R3 B fase1:117 |
| MSG-D03 | "WAHA nunca": o QR via servidor próprio fica fora; WhatsApp = `wa.me` manual agora e API oficial da Meta com lembretes automáticos depois | **sugestão a confirmar** (sem frase; "decisão do Alexandre" só citada) | `docs/reference/stack.md:42`; R2 A stack (registro de mudanças); R3 B audit:46 |
| MSG-D04 | Envio automático e motor de automações adiados de propósito, vão para a fila "depois" | **sugestão a confirmar** | R3 B audit:46; R2 B ICEBOX:31 |
| MSG-D05 | Mensageria começa simples: link manual, depois modelos semi-automáticos, depois n8n, depois API oficial quando volume e retorno justificarem | **sugestão a confirmar** (texto "Current decision" de 16/06, sem frase) | R5 A messaging-flow:15-31 |
| MSG-D06 | Não integrar provedor real ainda: fundação agnóstica, ações manuais primeiro, só decidir o provedor depois de consentimento, opt-out, volume e retorno validados | **sugestão a confirmar** ("Executive decision" de 16/06, sem frase) | R5 A messaging-provider-research:7-17,141-162 |
| MSG-D07 | Log honesto: só conta como enviada a mensagem que o provedor confirmou | **sugestão a confirmar** (mockup V25 e documento antigo, sem frase) | R1 B Main.dc.html; R5 A messaging-flow; R5 F |
| MSG-D08 | Começar já pelo QR, "como se fosse um navegador web", e ir amadurecendo o módulo (pedido da Karenn, 30/10). Quem pediu foi a Karenn, não o dono | **sugestão a confirmar** (contrariada por D03) | legado 43:3; R4 A 43 |
| MSG-D09 (AGS7) | Mesma lista de ações da cliente nas duas telas; o item se chama "Mensagem no WhatsApp" | **sugestão a confirmar** ("Sim", 23/11/2026 00h46, aceite em lote de 8 itens; o registro diz "Decidida") | R1 A AGS7 (`reg:106`); `docs/decisoes/historico/registro-ate-2026-11-24.md:106` |
| MSG-D10 | Mensagens entra na barra inferior do celular no lugar de Catálogo? Hoje está em "Mais" (sem resposta) | **sugestão a confirmar** (pergunta aberta no mockup) | R1 D Main.dc.html |
| MSG-D11 | Lembretes automáticos de WhatsApp e reserva online no centro do que se vende (N3·A) | **sugestão a confirmar** (lote "aceito todas", 22/11) | R1 A N3·A (`reg:130`); `docs/specs/plans/2026-11-22-fase1-lista-unica.md:134` |

## Regras de negócio
- Falha de mensageria nunca desfaz uma operação já confirmada (agenda, checkout, ficha). Origem: legado 13:14; 43:39.
- Cada gatilho cria no máximo um envio por ocorrência; o envio em fila exige chave de idempotência. Origem: legado 13:28; R5 B messaging-provider-research:126-139.
- Envio e falha ficam registrados e auditáveis; nunca se mostra "enviado" sem confirmação. Origem: legado 13:29; MSG-D07.
- Marketing só vai para quem disse SIM; recusa vale por canal; quem foi mesclada ou bloqueada nunca entra; o envio confere o consentimento de novo na hora. Opt-out não bloqueia mensagem essencial permitida. Origem: R2 C66 (`history.md:55,68,70`); legado 13:30. Detalhe em MKT.
- Chaves de provedor ficam só no servidor (`WHATSAPP_CLOUD_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID`, `WHATSAPP_VERIFY_TOKEN`, `WHATSAPP_APP_SECRET`, `RESEND_API_KEY`, `EMAIL_FROM`); o navegador nunca fala com o provedor. Origem: legado 13:13; 43:16,37-38; 44:7.
- Webhook do WhatsApp é assinado; sem assinatura válida, nada é gravado. Origem: legado 43:10; `src/lib/messaging/signature.server.ts`.
- Sem dado clínico em mensagem de marketing. Origem: R5 B messaging-flow:35-86.
- Mensagem de fidelidade e de marketing só com consentimento de marketing. Origem: `docs/produto/legado/produto/fidelidade-mapa-futuro.md:42`.
- Modelo tem versão e idioma; a variável do texto é validada antes de salvar. Origem: legado 13:11.
- O QR do WhatsApp (se um dia voltar) é não oficial: número exclusivo, só clientes que já conversam, sem massa, e o aviso aparece na tela. Origem: legado 43:53,57.
- Permissões: `mensagens.use` (recepção e acima) e `mensagens.configure` (canais). Origem: legado 43:4; `src/domain/access.ts:48,61`.

## Pendências e perguntas
| Pergunta ou pendência | Origem |
|---|---|
| WhatsApp para clientes: API oficial da Meta direta ou provedor aprovado (BSP)? | R5 D revisao-30-10:22; R5 D messaging-provider-research:164-175 |
| E-mail: Brevo (grátis, 300/dia) ou Resend? Contratar SMS? | R5 D painel-da-jornada.html:131-138; R1 A G5 |
| O WhatsApp está ligado a um número só para todos os estúdios: como fica com vários estúdios? | R3 B audit:29; legado 43:43 (`single` ou `per_org`) |
| A tela de Conversas, Automações e Avaliações está desligada ou "em breve": ligar, esconder ou deixar visível e desligada (G9)? | R3 B audit:29; `docs/specs/plans/2026-11-22-fase1-lista-unica.md:121` (G9) |
| Quando fazer o motor de envio? Sem ele, "lembrete automático" na tela é só aparência (MSG-18) | R4 F (spec 52:54-55 × 13:23-24) |
| Domínio de envio do Resend (SPF, DKIM, DMARC), servidor ou número dedicado: quem providencia? | R4 D 43, 44, 47; R2 E (segredos do Worker) |
| Duas gerações de requisito: a nova (fila, confirmação, "saudade", caixa de conversas) não pede opt-out nem log honesto, que a antiga exige | R5 F |
| A tela "Mensagens manuais" não tem item na fila: precisa de ficha, spec e código | R2 B ICEBOX item 41; R1 B reg:176 |
| Chave estrangeira composta com `org_id` em mensagens e marketing | R2 B ICEBOX item 46 (`ICEBOX.md:50`) |
| Revisar custos: tarifa Meta por mensagem entregue (Espanha: utilidade € 0,0166, marketing € 0,0585) mudam; conferir na hora de implementar | legado 44:19; R5 B messaging-provider-research:31-47 |
| Provedor "AWA" citado e não confirmado: registrar site, preço, status BSP, termos, API, SMS e suporte a números da Espanha | R5 D messaging-provider-research:108-124 |

## Referências
- Specs do legado: `docs/produto/legado/specs/13-notifications-whatsapp-email.md`, `43-whatsapp-qr.md`, `44-email-e-creditos.md`, `24-agenda-fresha-parity-handoff.md` (linhas 51, 105, 203), `30-payment-request-transfer.md` (62-63), `40-agenda-visibilidade-chegou-espera.md` (46-47), `52-guia-de-agendamento.md` (54-55), `28-navegacao-marketing-ajustes.md` (Mensagens dentro do menu Marketing).
- Documentos do antigo (via R5): `operations/messaging-flow.md`, `operations/messaging-provider-research.md`, `product/revisao-30-10.md`, `product/painel-da-jornada.html`.
- Plano de recuperação: `docs/specs/plans/2026-11-22-auditoria-e-plano-de-recuperacao.md` (linhas 29 e 46); lista única `2026-11-22-fase1-lista-unica.md` (G4, G5, N3).
- Prints do Fresha: `docs/fresha-prints-referencia/07-marketing`, `05-avaliacoes` (sem legenda). Mockup V25: `docs/design/v25-mockups/Main.dc.html`.
- Decisões de design: `docs/decisoes/historico/registro-ate-2026-11-24.md`.

Regra: só vale decisão registrada em `docs/decisoes/` (molde de pergunta). Tudo desta tabela é **a confirmar**; a situação antiga fica entre parênteses só como histórico e volta a ser perguntada quando o módulo for trabalhado (resposta 15a do dono, 24/11/2026).
