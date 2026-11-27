# Módulo: Marketing (MKT)

> Campanhas para quem autorizou receber, grupos de clientes (segmentos), cupons, ofertas e pedido de avaliação no Google.
> Hoje existem campanhas em rascunho e fila manual; **nada é enviado sozinho**.

**Telas e rotas:** `/{org}/marketing` (abre a primeira área liberada), `/marketing/campanhas`, `/marketing/avaliacoes` · **Código:** `src/workspace/marketing` (`campanhas/`, `ReviewsView.tsx`), `src/domain/marketing.ts`, `marketing-foundation.ts` · **Spec(s):** sem spec no atual. No legado: `docs/produto/legado/specs/14-marketing-promotions.md`, `28-navegacao-marketing-ajustes.md`, `19-integrations-google-meta-analytics.md`.

Como ler a coluna Origem: "legado 14:24" = `docs/produto/legado/specs/14-marketing-promotions.md` linha 24. "R4 B 14" = relatório R4, seção B, spec 14. Outros usam o caminho curto do arquivo.

## Recursos
| ID | Recurso | Estado | Onde | Origem |
|---|---|---|---|---|
| MKT-01 | Menu único Marketing com quatro áreas: Mensagens, Campanhas, Avaliações, Fidelidade; respeita módulo do plano e permissão | pronto | `/marketing`, `MarketingFrame.tsx` | legado 28:9,21; R4 B 28-nav; R2 B STATUS:33 |
| MKT-02 | Campanhas: rascunho, público, modelo, fila só em estados "rascunho" ou "manual", nunca "enviado" | pronto, sem envio (atual) · fundação pronta e pausada (antigo, MKT-01A) | `/marketing/campanhas` (`campanhas/MarketingView.tsx`) | R2 B STATUS:33; R3 B audit:29; R5 B delivery-review-2026-06-16-marketing-foundation:13-39 |
| MKT-03 | Só para quem autorizou: o sistema avisa quantas clientes não autorizaram; confere de novo na hora de enviar | pronto | `campanhas/ConsentNotice.tsx` | R2 A regras-de-produto #3; R2 C C66 (`history.md:55,68,70`); legado 14:13 |
| MKT-04 | Segmentos derivados: VIP, fiéis, novos, inativos, aniversário | pronto (derivados) | Campanhas | legado 14:24; R5 B scope-master:124 |
| MKT-05 | Construtor de público: serviço, última visita, aniversário, inativos, etiquetas, gasto, cidade, idioma, consentimento | planejado (MKT-01) | futuro Campanhas | R5 B future-modules-map:50-64 |
| MKT-06 | "Sem retorno" = 60 dias sem voltar (G6) | planejado | Clientes e segmentos | R3 B fase1:118; R1 A G6 |
| MKT-07 | Limite de frequência e limite diário por campanha; teto de custo por campanha/mês | planejado | futuro Campanhas | legado 14:13; R5 B messaging-provider-research:84-106 |
| MKT-08 | Cupons: código opcional, validade, elegibilidade, limite, serviços | planejado (depois da mensageria) | sem tela | legado 14:10,24-25 |
| MKT-09 | Ofertas: motivo comercial e patrocinador; diferente de desconto manual, cupom e vale | planejado | sem tela | legado 14:5-6,11,24-25 |
| MKT-10 | Benefício aplicado aparece identificado na comanda; sem envio duplicado por atendimento | planejado | Comanda; Campanhas | legado 14:29-31 |
| MKT-11 | Vale-presente com saldo próprio (a venda e o uso ficam em Comanda/Checkout) | pronto (básico) | ver módulo Comanda/Checkout | legado 14:12,24; R4 B 14, 41 |
| MKT-12 | Avaliações no Google: ao fechar a comanda, "agradecer e pedir avaliação", "só agradecer" ou "não enviar"; automático 2 horas depois, por WhatsApp ou e-mail | planejado (antigo) · pronto (R2) × "em breve" (R3 e a tela) | `/marketing/avaliacoes` (`ReviewsView.tsx`, `ReviewsParts.tsx`) | R2 B STATUS:33; R3 B audit:29; R4 B 14; R1 B Main.dc.html; `ReviewsView.tsx:63` |
| MKT-13 | Regras do pedido de avaliação: link do Google, modo e regra de 90 dias | planejado P1 | Avaliações | R5 B revisao-30-10:28 |
| MKT-14 | Pedido de avaliação por caixa no checkout ou pergunta do sistema; momento e gatilho na criação do tipo de mensagem | planejado | Comanda; Avaliações | R5 B product-vision-detail:82-85 |
| MKT-15 | Painel de reputação Google e integração Google Business e Meta (OAuth no servidor, token cifrado) | planejado, "não iniciado" | sem tela | legado 19:24; R5 B scope-master:137; R5 B roadmap:285 |
| MKT-16 | Retorno por procedimento: intervalo mínimo entre sessões e gatilho de retoque ou renovação; alimenta a automação "saudade" | planejado P1 | Automações (Mensagens) | R5 B revisao-30-10:25 |
| MKT-17 | Jornadas: aniversário, reativação, pós-atendimento, avaliação (usam Mensagens › Automações) | planejado | Mensagens | R5 B future-modules-map:50-64; R5 B scope-master:125 |
| MKT-18 | Marketing e Avaliações são módulos do plano: Campanhas extra 15 € no Profissional, Avaliações extra 9 €, ambos incluídos no Completo (preços de exemplo) | pronto como dado (base de banco) | Ajustes › Plano | legado 29:61,64; R4 B 29 |
| MKT-19 | Prints do Fresha: Marketing (7) e Avaliações (10) | referência, sem legenda | `docs/fresha-prints-referencia/07-marketing`, `05-avaliacoes` | R3 B fr/07-marketing/README.md:11-17; fr/05-avaliacoes/README.md:11-20 |

"Estado" é o que os documentos dizem; o código é conferido quando o módulo entra em trabalho.

## Decisões
| ID | Decisão | Situação | Origem |
|---|---|---|---|
| MKT-D01 (regras-de-produto #3) | Marketing só para quem disse SIM (RGPD); o sistema avisa quantas clientes não autorizaram | **sugestão a confirmar** (data 14/11, sem frase; já aplicada no código) | `docs/adr/2026-11-19-regras-de-produto.md:8`; R2 A regras-de-produto #3; R2 A history.md:65-70 |
| MKT-D02 | Pedido de avaliação não pode escolher só quem gostou, para não manipular avaliação pública | **sugestão a confirmar** (regra da spec antiga, sem frase) | legado 14:14-15; R5 A product-capability-audit-2026-06-12:51 |
| MKT-D03 | "Avaliação só para quem saiu satisfeita: feito como você pediu" (texto do mockup V25). Contradiz MKT-D02 e a regra do Google | **sugestão a confirmar** (sem frase do dono; a IA registrou o risco na documentação) | R1 B Main.dc.html ("Preciso que você confirme"); R1 D |
| MKT-D04 | Fundação de Marketing pausada pelo dono: sem provedor nem envio agora | **sugestão a confirmar** (sem prova) | R5 A implementation-gap-map:47 |
| MKT-D05 | Ordem depois do núcleo: Marketing, Fidelidade, Acesso, SaaS (Marketing antes de Acesso). Contradiz MKT-D04 | **sugestão a confirmar** | R5 B future-modules-map:38-46; R5 F |
| MKT-D06 | Marketing sem dado clínico; opt-in separado, opt-out, log; fora da primeira entrega de mensagens | **sugestão a confirmar** | R5 B messaging-flow:35-86 |
| MKT-D07 | Marketing é um menu só, com Fidelidade dentro | **sugestão a confirmar** (spec antiga marcada pronta, sem frase) | legado 28:9,21; `fidelidade-mapa-futuro.md:7` |
| MKT-D08 | Sem envio em massa sem revisão legal; sem SMS de marketing por padrão | **sugestão a confirmar** | R5 B future-modules-map:50-64; R5 B messaging-provider-research:177-185 |
| MKT-D09 | Etiquetas de cliente neutras, com ícone; cor só em ícone ou palavra de estado | **sugestão a confirmar** (prints "enviados pelo Alexandre em 09/11", sem frase) | R5 A fresha-prints-referencia/04-clientes/notas-etiquetas-09-11/README.md:3-4,16 |

## Regras de negócio
- Cliente sem preferência registrada não recebe marketing. Recusa vale por meio (WhatsApp, e-mail). Cliente mesclada ou bloqueada nunca entra. Origem: R2 C C66; legado 14:13.
- O envio, quando existir, confere o consentimento de novo na hora de mandar. Origem: R2 C C66.
- Campanha registra público, consentimento, resultado e falhas, e não manda duas vezes pelo mesmo atendimento. Origem: legado 14:30-31.
- Cupom, oferta, desconto manual e vale-presente são coisas diferentes e não se misturam. Origem: legado 14:5-12.
- Pedido de avaliação não filtra a cliente (política do Google, Diretiva Omnibus). Origem: legado 14:14-15; legado 39:40.
- Fila de campanha nunca marca "enviado" sem confirmação do provedor. Origem: R5 B delivery-review-2026-06-16:13-39.
- Marketing e Avaliações só aparecem para quem tem o módulo no plano; sem módulo a rota responde 404. Origem: legado 29:104-109.
- Benefício aplicado fica identificado na comanda. Origem: legado 14:29.

## Pendências e perguntas
| Pergunta ou pendência | Origem |
|---|---|
| Avaliações: o R2 diz "pronto", o R3 e a tela dizem "em breve". Qual é o estado verdadeiro? | R2 B STATUS:33; R3 B audit:29 |
| Pedir avaliação só a quem saiu satisfeita (MKT-D03) fere a política do Google e a lei de consumo. Manter, ou pedir a todas? | R1 B Main.dc.html; legado 14:14-15 |
| Marketing está pausado (MKT-D04) ou vem logo depois do núcleo (MKT-D05)? | R5 F |
| Avisos prontos de cada ferramenta, por e-mail ou painel próprio (pós-lançamento). A página registra "A, avisos por e-mail" em lote | R3 B fase1:90 |
| Galeria antes/depois e painel de contexto da cliente: "prioridade nº 1" do negócio, sem dono. Ela entra em Marketing ou fica em Agenda/Clientes? | R5 B core-delivery-control:68; R5 B revisao-30-10:24 |
| Cadastro da cliente com avisos e marketing ligados item a item (G10): ainda planejado, sem registro de decisão | R3 B fase1:122 |
| Perda possível: "Segunda passada pendente" da pesquisa de SEO, anúncios, geradores e Google (revisao-30-10:41-42) | R5 D |

## Referências
- Specs do legado: `docs/produto/legado/specs/14-marketing-promotions.md`, `28-navegacao-marketing-ajustes.md`, `19-integrations-google-meta-analytics.md`, `29-access-roles-modules.md` (preços de exemplo).
- Documentos do antigo (via R5): `product/future-modules-map.md`, `product/implementation-gap-map.md`, `product/revisao-30-10.md`, `product-vision-detail.md` (linhas 77-85).
- Prints do Fresha: `docs/fresha-prints-referencia/07-marketing`, `05-avaliacoes`. Mockup V25: `docs/design/v25-mockups/Main.dc.html`, `MktAvaliacoesMobile`.
- ADR: `docs/adr/2026-11-19-regras-de-produto.md`. Módulos vizinhos: MSG (envio), FID (fidelidade), SAA (plano).

Regra: só vale decisão registrada em `docs/decisoes/` (molde de pergunta). Tudo desta tabela é **a confirmar**; a situação antiga fica entre parênteses só como histórico e volta a ser perguntada quando o módulo for trabalhado (resposta 15a do dono, 24/11/2026).
