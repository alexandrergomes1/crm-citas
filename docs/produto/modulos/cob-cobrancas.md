# Módulo: Cobranças (COB)

> Cobrar a cliente fora do balcão: o estúdio manda um link, a cliente paga por transferência e anexa o comprovante, a equipe confere e dá baixa.
> Inclui o sinal do agendamento e, mais adiante, cupom, oferta e pagamento online.

**Telas e rotas:** página pública `/pagar/$token` (existe: `src/routes/pagar.$token.tsx`) · folha de conferência dentro de Comandas, `/{org}/financeiro/comandas?cobrancas=1` · botões "Pedir por link" no agendamento e "Cobrar por link" no perfil da cliente · contas de recebimento em Ajustes › Pagamentos · **Código:** `src/workspace/cobrancas/`, `src/public-pay/`, regras em `src/domain/payment-request*.ts` · **Spec(s):** sem spec no crm-agenda. Antigo: `docs/produto/legado/specs/30-payment-request-transfer.md` (implementada em 29/10/2026) e `10-payments-policy-deposits.md` (sinal).

## Recursos
| ID | Recurso | Estado | Onde | Origem |
|---|---|---|---|---|
| COB-01 | Link `/pagar/<token>` sem login, uso único, com validade (24 h por padrão), em espanhol, inglês ou português (espanhol é o padrão) | pronto (antigo) · pronto (atual) | `/pagar/$token` | legado spec 30:23-26,45-47,99-103; R2 B STATUS:32,35 |
| COB-02 | A cliente vê valor, motivo e prazo, e as formas aceitas: Bizum (número), transferência SEPA (titular, IBAN, BIC, banco) e Pix (chave) quando configurado; botão copiar em cada dado e texto de referência ("SINAL-1061") | pronto (antigo) · pronto (atual) | `/pagar/$token` | legado spec 30:23-28 |
| COB-03 | Orientação "escolha transferência imediata"; anexar comprovante (foto ou PDF, até 10 MB) e confirmar | pronto (antigo) · pronto (atual) | `/pagar/$token` | legado spec 30:29-30,99 |
| COB-04 | Situações do pedido: aguardando pagamento, comprovante enviado, confirmado, recusado (com motivo), expirado, cancelado. Link já pago mostra "pago" | pronto (antigo) · pronto (atual) | Financeiro › Cobranças | legado spec 30:31-36,91-94 |
| COB-05 | Conferência no estúdio: abertas, encerradas, todas; ver comprovante (link de 5 min); confirmar recebimento (Bizum ou transferência); recusar com motivo; cancelar cobrança; pedido vencido ainda pode ser confirmado | pronto (antigo) · pronto (atual; abre dentro de Comandas) | `/financeiro/comandas?cobrancas=1` | legado spec 30:54-57; legado spec 41:27-28; R4 B 30 |
| COB-06 | Confirmar lança o valor uma só vez como sinal, pagamento da comanda ou crédito da cliente, com auditoria; o comprovante sozinho nunca dá baixa | pronto (antigo) · pronto (atual) | Cobranças | legado spec 30:31-36,91-94,101 |
| COB-07 | Onde cobrar: Agenda › atendimento › Registrar sinal › "Pedir por link" (sinal) e perfil da cliente › Movimentos de saldo › "Cobrar por link" (crédito) | pronto (antigo) · pronto (atual) | Agenda e Clientes | legado spec 30:40-44; R4 B 30 |
| COB-08 | Pagamento da comanda pelo link entra como crédito da cliente e é usado na comanda com "usar crédito" | pronto (antigo, V1) · não declarado (atual) | checkout | legado spec 30:42-44 |
| COB-09 | Lançar o pagamento do link direto na comanda (sem passar por crédito) | planejado ("fica para depois") (antigo) · não declarado (atual) | checkout | legado spec 30:42-44; R4 D |
| COB-10 | Link de pagamento como forma de pagamento no checkout: comprovante só na Transferência; a equipe anexa ou a cliente envia (se ligado em Ajustes › Pagamentos); a equipe confere; a cliente recebe confirmação | a definir (desenho 11/11; "?" se aplicado) | checkout · Ajustes › Pagamentos | R1 A L-1111-06 (reg:190; livro:118-125); R5 A registro.md:63 |
| COB-11 | Contas de recebimento (várias): tipo (Bizum, SEPA, Pix), titular, IBAN ou chave, banco, ativa; texto de orientação editável; validade padrão do link; comprovante obrigatório ou não | pronto (antigo) · pronto (atual) | Ajustes › Pagamentos | legado spec 30:75-78; ver `aju-ajustes.md` |
| COB-12 | Sinal manual: vinculado ao agendamento, abatido na mesma comanda, com entidade própria, idempotência e função transacional (caixa, nota, auditoria) | pronto (antigo) · pronto (atual) | Agenda › Registrar sinal | legado spec 10:23-25,30; R5 B roadmap:76; R1 B inv:80 |
| COB-13 | Aviso ao estúdio quando chega um comprovante | planejado (depende de Mensagens) (antigo) · não declarado (atual) | — | legado spec 30:62-63,100 |
| COB-14 | Pendências de baixo risco do `/pagar`: link continua visível se o módulo for desligado; referência de 24 bits sem unicidade; limpeza de arquivos órfãos; limite de requisições | pendente (antigo) · ICEBOX "precisa de spec" (atual) | `/pagar/$token` | legado spec 30:71-73; R5 D revisao-30-10:16; R2 B ICEBOX:12 |
| COB-15 | Idempotência em `/pagar` e nos webhooks (chamada repetida não duplica efeito) | planejado P2 (antigo) · planejado, precisa de spec (atual) | a definir | legado spec 10:31-32; R2 B ICEBOX:12 |
| COB-16 | Política de pagamento variável por serviço, cliente, canal e antecedência; reconciliação; estorno que restaura saldos e audita | planejado P2 (antigo) · não declarado (atual) | a definir | legado spec 10:7-14,25-26,31-32 |
| COB-17 | Depósito online por provedor (Stripe e outros) com webhook idempotente: link de reserva → pagamento → confirmação automática → "reserva paga" → comanda cobra só a diferença | planejado, não iniciado (antigo; sem Stripe no código) · não declarado (atual) | a definir | R5 B product-vision-detail:56-63,116-122; roadmap:200,283; agenda-operational-scope:458-489 |
| COB-18 | Cupom de desconto: por serviço, com ou sem código, validade, nome e descrição; na comanda, desconto OU cupom, com o motivo registrado | planejado, sem tabela nem tela (antigo) · não declarado (atual) | checkout | R5 B product-vision-detail:88-91; core-delivery-control:69,179 (CORE-COUPON-01) |
| COB-19 | Oferta (ex.: parceria com influenciadora, 100% de desconto controlado) e vender vale-presente | planejado (antigo) · não declarado (atual) | checkout | R5 B product-vision-detail:88-91; roadmap:216 |
| COB-20 | Quitar o débito de uma comanda anterior (hoje só aparece, sem ação) | planejado (antigo, CORE-DEBT-01 e P1) · não declarado (atual) | checkout | R5 B core-delivery-control:69,178; revisao-30-10:30 |
| COB-21 | Qualidade da página `/pagar`: teste só do link inválido; título "Pago" fixo; "ficha não encontrada" sempre em espanhol e com o nome "KA Beauty" | parcial (atual) | `/pagar/$token` | R3 B audit:31; R2 B STATUS:35 |
| COB-22 | Prévia `/dev/pagar` em três idiomas para ver a página sem banco | pronto (antigo) · perdido na migração (atual) | — | legado spec 30:5-6; R3 F (vitrine `/dev/v25` perdida) |
| COB-23 | Referência de concorrente (Booksy): "No-Show Protection" e "Trusted Client", úteis para sinal e cobrança | referência | — | R5 F (booksy:122-131) |

## Decisões
| ID | Decisão | Situação | Origem |
|---|---|---|---|
| COB-D01 | O comprovante sozinho nunca dá baixa: só "Confirmar recebimento" depois de ver o dinheiro na conta | **sugestão a confirmar** (sem prova) | legado spec 30:33-36 |
| COB-D02 | Pagamento da comanda pelo link entra como crédito da cliente; lançar direto na comanda fica para depois | **sugestão a confirmar** (sem prova) | legado spec 30:42-47 |
| COB-D03 | O link mostra-se uma vez, só o hash fica guardado; para reenviar, cria-se outro e cancela-se o antigo; o link expira e, depois de confirmado, mostra "pago" | **sugestão a confirmar** (sem prova) | legado spec 30:45-49,91 |
| COB-D04 | Comprovante em bucket privado; leitura só pelo estúdio, com URL assinada curta; o navegador envia direto ao armazenamento; no máximo 5 por pedido | **sugestão a confirmar** (sem prova) | legado spec 30:48-53,92 |
| COB-D05 | Confirmar e recusar exigem `comanda.operate` e ficam auditados; criar e confirmar sinal: proprietária, administração, gestão, recepção e financeiro; crédito: proprietária, administração e gestão; contas de recebimento: proprietária e administração | **sugestão a confirmar** (sem prova) | legado spec 30:58-61,93 |
| COB-D06 | O caixa registra Bizum ou transferência, nunca dinheiro, nas cobranças por link | **sugestão a confirmar** (sem prova) | legado spec 30:60-61 |
| COB-D07 | Sem bloqueio fiscal: o sistema registra, não emite fatura nem decide imposto | **sugestão a confirmar** ("decisão de 28 out" sem frase) | legado spec 30:95; legado spec 33:24-26 |
| COB-D08 | Registrar pagamentos, sinais, estornos e receita por inteiro; evitar reporte à Hacienda não é requisito; banco, IBAN e adquirente seguem assessoria fiscal (item 9 corrigido) | **sugestão a confirmar** (sem prova) | R5 A product-vision-detail:150-160 |
| COB-D09 | Pedido de cobrança vencido ainda pode ser confirmado, porque o dinheiro pode chegar depois do prazo | **sugestão a confirmar** (sem prova) | legado spec 30:54-57 |
| COB-D10 | Espanhol é o idioma padrão do link (clientes em Benalmádena); `?lang=es`, `en` ou `pt` | **sugestão a confirmar** (sem prova) | legado spec 30:45-47 |
| COB-D11 | O sinal confirmado reduz o saldo da comanda; não vira crédito genérico desconectado do atendimento | **sugestão a confirmar** (sem prova) | legado spec 10:12-13 |
| COB-D12 | A cobrança por transferência fica atrás do módulo `cobranca` (extra de 5 € no plano Básico; incluída no Profissional e Completo, preços de exemplo) | **sugestão a confirmar** (sem prova) | legado spec 30:3-4; legado spec 29 (tabela de módulos) |
| COB-D13 | Sinal antecipado: pesquisar antes (Stripe, SumUp, PayPal, Revolut Business, Wise Business, transferência, link de pagamento); não escolher o provedor sem decisão formal | **sugestão a confirmar** (sem prova) | R5 B agenda-operational-scope:458-489 |
| COB-D14 | Link de pagamento é forma de pagamento; comprovante só na Transferência; cliente envia se ligado em Ajustes › Pagamentos (L-1111-06) | **sugestão a confirmar** (sem prova; 11/11, 17h57 e 23h49) | R1 A reg:190; R5 A registro.md:63 |
| COB-D15 | Revisão de segurança de 29/10 já corrigida: exclusão de comprovante por caminho não verificado, limite de arquivos em paralelo, envio direto por anon, crédito criado por papel que não confirma, função `immutable` usando `now()`, crédito lançado como dinheiro | **sugestão a confirmar** (registro de correção, sem prova do dono) | legado spec 30:65-73 |

## Regras de negócio
- O comprovante nunca dá baixa sozinho; um humano confere o dinheiro na conta e confirma.
- Confirmar duas vezes não lança o valor duas vezes.
- Link: só o hash fica guardado, expira, uso único; reabrir depois de confirmado mostra "pago".
- A pessoa com o link não chama as funções de envio direto; só o servidor registra o comprovante.
- Comprovante fica em armazenamento privado; leitura só por link assinado de curta duração.
- Sinal confirmado abate a comanda do próprio atendimento, nunca vira crédito solto.
- O sistema registra tudo por inteiro e não emite documento fiscal.
- Pagamento, webhook, estorno e expiração devem ser idempotentes e reconciliáveis (meta, ainda não feita).

## Pendências e perguntas
| Pergunta ou pendência | Origem |
|---|---|
| Idempotência em `/pagar` e webhooks precisa de spec (nível C) | R2 B ICEBOX:12 |
| Limite de requisições em `/forms` e `/pagar` "precisa do OK do Alexandre", pendente desde junho | R5 D revisao-profunda:149-150; R5 F |
| Qual provedor de pagamento online e qual validação fiscal e legal? Nada foi escolhido | R5 D roadmap/agenda-operational-scope (8 decisões abertas) |
| Aviso ao estúdio de comprovante recebido depende de Mensagens, que não envia nada sozinho hoje | legado spec 30:62-63; R2 B STATUS:33 |
| Cupom e débito de comanda anterior precisam de spec própria | R5 B core-delivery-control:69,178-179 |
| Conferir se o link `/pagar` do atual cobre tudo da spec 30 (comprovante, recusar, cancelar, aviso); só "pronto" no STATUS | R2 B STATUS:32 |
| Teste só do link inválido e título "Pago" fixo na página pública | R3 B audit:31 |
| Link como forma de pagamento no checkout (L-1111-06) está desenhado e sem confirmação de que foi aplicado | R1 A L-1111-06 |

## Referências
- Legado: `docs/produto/legado/specs/30-payment-request-transfer.md`, `10-payments-policy-deposits.md`, `29-access-roles-modules.md` (módulo `cobranca`), `41-finance-reports-dre-saldos-vales.md:27-28`.
- Legado de produto: `docs/produto/legado/produto/product-vision-detail.md:56-63,88-91,150-160`, `roadmap.md:200,216,283`, `agenda-operational-scope.md:458-489`.
- Atual: `docs/STATUS.md:32,35`; `docs/ICEBOX.md:12`; `docs/decisoes/historico/registro-ate-2026-11-24.md:63` (L-1111-06).
- Banco (antigo): migration `20261029020000_payment_requests.sql`; testes `supabase/tests/30_payment_requests.sql`.

Regra: só vale decisão registrada em `docs/decisoes/` (molde de pergunta). Tudo desta tabela é **a confirmar**; a situação antiga fica entre parênteses só como histórico e volta a ser perguntada quando o módulo for trabalhado (resposta 15a do dono, 24/11/2026).
