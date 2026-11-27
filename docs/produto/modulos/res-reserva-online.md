# Módulo: Reserva online e Site (RES)

> Página pública do estúdio onde a cliente escolhe serviço, profissional e horário e reserva sozinha, 24 horas por dia, com sinal online.
> Depois, um marketplace (portal que reúne vários estúdios). Hoje só existem as páginas públicas com token (ficha, pagar, senha); **o site de reserva não existe**.

**Telas e rotas:** públicas hoje: `/forms/$token`, `/pagar/$token`, `/reset-password`, `/trocar-senha`, `/login`. Planejadas: `/b/[slug]` (com redirect de `/booking/[org]`) · **Código:** `src/routes/forms.$token.index.tsx`, `forms.$token.calendar.ts`, `pagar.$token.tsx`, `reset-password.tsx`, `trocar-senha.tsx`; domínio inicial `src/domain/public-booking.ts` e `agenda-slots.ts`; módulo `reserva` em `src/domain/access.ts:28`; não há pasta de reserva em `src/workspace` e não há rota `/b/` · **Spec(s):** sem spec no atual. No legado: `docs/produto/legado/specs/16-online-booking-public.md`, `38-site-de-agendamento-do-estudio.md`, `39-portal-marketplace.md`; `docs/produto/legado/produto/ecossistema.md`.

Como ler a coluna Origem: "legado 38:23-25" = `docs/produto/legado/specs/38-site-de-agendamento-do-estudio.md` linhas 23 a 25. "R4 B 38" = relatório R4, seção B, spec 38.

## Recursos
| ID | Recurso | Estado | Onde | Origem |
|---|---|---|---|---|
| RES-01 | Páginas públicas com link e token: ficha de saúde, pagamento, esqueci a senha, trocar senha, login | pronto | `/forms/$token`, `/pagar/$token`, `/reset-password`, `/trocar-senha`, `/login` | R2 B STATUS:35; R3 B audit:31; R4 B 30, 47 |
| RES-02 | Página "ficha não encontrada" aparece sempre em espanhol e com "KA Beauty" | parcial | `/forms/$token` | R3 B audit:31 |
| RES-03 | Páginas públicas sem login: sem cache, sem indexação, sem referência (`/booking` já está na lista) | pronto (regra de servidor) | `src/lib/public-paths.ts` | R2 C C70 (`docs/reference/server.md:32-40`) |
| RES-04 | Site público do estúdio em `/b/[slug]`: nome, fotos, endereço com mapa (link), horário, política de cancelamento e de sinal visível antes de confirmar | planejado (proposta) | `/b/[slug]` (não existe) | legado 38:19-22; R4 B 38; R3 B audit:167 |
| RES-05 | Fluxo da cliente: serviço, profissional (ou "qualquer uma"), dia e horário, dados com código de confirmação (WhatsApp, SMS ou e-mail), sinal, confirmação | planejado | `/b/[slug]` | legado 38:23-25 |
| RES-06 | Booking 24/7 com a disponibilidade real da agenda, recalculada no servidor, sem cache; só serviços, locais e profissionais publicáveis | planejado P2; "domínio inicial de slots existe" | servidor; `agenda-slots.ts` | legado 16:5-14,23-25; legado 38:37-38 |
| RES-07 | Reserva temporária do horário (~10 min) e garantia no banco de que duas reservas nunca ocupam o mesmo horário da mesma profissional | planejado (`[ ]`) | banco | legado 38:39-41,71; legado 16:29 |
| RES-08 | Cliente reconhecida por telefone E.164 e e-mail normalizado só dentro do estúdio, sem cadastro duplicado | planejado | servidor | legado 38:42-43,72; legado 16:11,30 |
| RES-09 | Anti-abuso: limite por IP, telefone e estúdio; CAPTCHA invisível; código de confirmação; registro das tentativas | planejado | servidor | legado 38:46; legado 16:14 |
| RES-10 | Acesso anônimo só por funções `security definer` com `search_path` fixo; nenhuma tabela exposta ao papel `anon` | planejado | banco | legado 38:44-45,76 |
| RES-11 | Origem de cada reserva gravada e imutável (`booking_source`: link, qr, instagram, google, marketplace, campanha; `first_touch_at`) | planejado | banco; relatórios | legado 38:47-48; legado 39:34 |
| RES-12 | Sinal online por provedor de pagamento da UE, com conta do estúdio; webhook idempotente; o sinal entra direto na comanda | planejado (Stripe e Asaas "depois") | `/b/[slug]`; Cobranças | legado 38:49-50; legado 16:13; `docs/reference/stack.md:38`; R5 B revisao-30-10:35 |
| RES-13 | Depois de confirmar: e-mail ou mensagem com link para remarcar ou cancelar (por token, dentro da política) e arquivo `.ics` | planejado | e-mail; página do link | legado 38:26-27,75 |
| RES-14 | Ficha de saúde nunca no formulário público; se o serviço exige, o link da ficha (expira em 7 dias) vai depois da reserva | planejado (o link tokenizado já existe) | Anamnese | legado 38:28-29,74 |
| RES-15 | Configuração do estúdio: ligar e desligar o site, escolher serviços e profissionais publicáveis, antecedência mínima e máxima, intervalo entre horários, política de sinal | planejado (`online_booking` já existe em serviços, produtos e profissionais) | Ajustes | legado 38:30-32 |
| RES-16 | Módulo `reserva` do plano: extra 15 € no Básico e Profissional, incluído no Completo; só aparece para quem tem o módulo | pronto como dado (chave do módulo) | Ajustes › Plano | legado 29:62; legado 38:33; `src/domain/access.ts:28` |
| RES-17 | Site em espanhol, português e inglês, escolhidos pela cliente; SEO (página no servidor, schema.org BeautySalon/Service/Offer, hreflang, sitemap); prefixo `/en`, `/es` só aqui | planejado | `/b/[slug]` | legado 38:19-20,52-53; `i18n-multiidioma.md:17` |
| RES-18 | Permissão "reservas online" do bloqueio de horário ligada ao motor público de disponibilidade (`time_blocks.allow_online_booking`) | em aberto | Agenda › Bloqueio | legado 25:70-71; legado 38:38; R5 D (agenda-blocks-filters-01) |
| RES-19 | Reserva online e lembretes automáticos no centro do que se vende; segundo piloto numa barbearia em BH; pacote Brasil (real, Pix, LGPD); "nada novo fora dos dois pilotos até o marco 2" | planejado (N3·A, sem item na fila) | — | R3 B audit:167; R3 B fase1:134; R1 A N3·A (`reg:130`) |
| RES-20 | Protótipo "Marcavez" como única especificação da reserva online | referência (sem arquivo no repositório) | — | R3 B audit:167 |
| RES-21 | Marketplace M0 Diretório: perfis públicos indexáveis de quem aderiu, busca por cidade e serviço; reserva na página do estúdio; sem conta de consumidora | planejado (proposta) | portal (não existe) | legado 39:18-20,57-62 |
| RES-22 | Marketplace M1 Conta da cliente: login, "minhas reservas" em todos os estúdios, favoritos, "disponível hoje"; cada estúdio vê só o próprio histórico | planejado (proposta) | portal | legado 39:21-22 |
| RES-23 | Marketplace M2 Avaliações verificadas: só depois de atendimento concluído e pago, uma por atendimento, 30 dias, resposta do estúdio, denúncia, selo "verificada" | planejado (proposta) | portal | legado 39:23-25 |
| RES-24 | Marketplace M3 Dinheiro e Google: modelo de receita (assinatura, taxa fixa por cliente nova, ou percentual com teto) e Reserve with Google por redirect | planejado, em aberto | portal | legado 39:26-27; R4 D 39 |
| RES-25 | Adesão ao marketplace por estúdio, desligável a qualquer hora sem perder o site próprio | planejado | Ajustes | legado 39:31,59 |
| RES-26 | Marketplace: nunca cobrar comissão sobre cliente da base; "nova" = fora da base e sem atendimento nos últimos 365 dias | planejado (regra) | portal | legado 39:11-14,32-33; R5 B ecossistema:25-27 |
| RES-27 | Reserve with Google, Facebook e Instagram bookings, conta da cliente com login, avaliações, pacotes e vale-presente online no site | fora do MVP · "fora da v1" (spec 00) | — | legado 38:62-66; legado 00:61-67; R4 F |
| RES-28 | API pública (Hono + OpenAPI) para canais externos | planejado, "depois" | servidor | `docs/reference/stack.md:21`; R2 B stack:21 |
| RES-29 | Ecossistema: site e página de agendamento, marketplace, impulsionamento (aquisição dos dois lados), e o gerador de sites como projeto separado ligado por integração | pauta, não aprovada | — | R5 B ecossistema:3-19,29-50 |
| RES-30 | Prints do Fresha: reservas online (Facebook, Instagram, Google Reserve, links diretos) e site público | referência, sem legenda | `docs/fresha-prints-referencia/08-reservas-online`, `09-site-publico` | R3 B fr/08-reservas-online/README.md:11-14; fr/09-site-publico/README.md:11-15 |
| RES-31 | Dados propostos do site de reserva: `org_public_profiles`, `organizations.public_slug`, `slug_redirects`, `booking_holds`, `public_booking_requests`, `booking_otp_challenges` | planejado (antigo) | banco | legado spec 38:55-60 (R4 B) |
| RES-32 | Dados do marketplace: `consumer_accounts`, `consumer_org_links`, `reviews`, `review_reports`, `marketplace_listings`, `marketplace_fees` | planejado (antigo) | banco | legado spec 39:43-48 (R4 B) |

"Estado" é o que os documentos dizem; o código é conferido quando o módulo entra em trabalho.

## Decisões
| ID | Decisão | Situação | Origem |
|---|---|---|---|
| RES-D01 | Sem comissão sobre reservas vindas dos canais do próprio estúdio (link, QR, Instagram, Google); nunca cobrar sobre cliente que já é do estúdio | **sugestão a confirmar** ("pedida pelo Alexandre", 29/10, sem frase) | legado 38:12-15; legado 39:11-14,32-34; R4 A 38, 39 |
| RES-D02 (N3·A) | A direção de 11/11 vale: reserva online e lembretes automáticos no centro, piloto em BH, pacote Brasil; a ordem se decide depois da Fase 4 | **sugestão a confirmar** (lote "aceito todas", 22/11) | R1 A N3·A (`reg:130`); `docs/decisoes/historico/registro-ate-2026-11-24.md:130`; `docs/specs/plans/2026-11-22-fase1-lista-unica.md:134` |
| RES-D03 | Rota `/b/[slug]`, com redirect de `/booking/[org]` | **sugestão a confirmar** (proposta) | legado 38:19 |
| RES-D04 | Não construir antes do núcleo validado (agenda, checkout, anamnese, perfis) e de um teste ponta a ponta do caminho principal | **sugestão a confirmar** | legado 38:5-7; R5 A ecossistema:3-5 |
| RES-D05 | Ficha de saúde nunca no formulário público; dados clínicos nunca em analytics, pixels, buscas ou avaliações | **sugestão a confirmar** | legado 38:28-29,51; legado 39:39 |
| RES-D06 | Marketplace só com vários estúdios na mesma cidade; começar pela Costa del Sol, diretório M0 sem conta de consumidora | **sugestão a confirmar** ("Recomendação") | legado 39:5-7; R5 B ecossistema:25-27,55-61 |
| RES-D07 | Ordem obrigatória: sistema agora; site depois do núcleo; marketplace por último; o gerador de sites é projeto à parte | **sugestão a confirmar** ("Recomendação") | R5 A ecossistema:29-50 |
| RES-D08 | Estúdio é controlador dos dados da cliente e da ficha; KA Beauty OS é operador; no marketplace, a plataforma controla a conta da consumidora, com consentimento por estúdio | **sugestão a confirmar** | legado 39:36-38 |
| RES-D09 | O sinal entra direto na comanda do atendimento | **sugestão a confirmar** | legado 38:49-50,73 |
| RES-D10 | "Google Reserve" e "Facebook/Instagram bookings" ficam fora da v1; "Marketplace multi-clínica" e "Billing SaaS" também | **sugestão a confirmar** (spec 00 do antigo; não está dito se voltam) | legado 00:61-67; R4 F |
| RES-D11 | Booking público e site só depois do gate do núcleo (Fase 2 do roadmap antigo) | **sugestão a confirmar** | R5 B roadmap:199; R5 B README.md:11 |

## Regras de negócio
- O horário é calculado no servidor, sem cache, respeitando turnos, bloqueios, recursos, intervalos e bloqueio de reserva da cliente. Origem: legado 38:37-38.
- Duas reservas ao mesmo tempo no mesmo horário: só uma confirma. Origem: legado 16:29; 38:71.
- Cliente identificada por telefone e e-mail só dentro do estúdio; nunca cadastro duplicado. Origem: legado 38:42-43.
- A origem da reserva é gravada uma vez e não muda; o estúdio vê e pode contestar. Origem: legado 39:34.
- Nenhuma tabela exposta ao `anon`; teste de banco cobre as funções públicas. Origem: legado 38:44-45,76.
- Política de cancelamento e de sinal aparece antes de confirmar; remarcar ou cancelar pelo link respeita a política. Origem: legado 38:21-22,75.
- Avaliação falsa é proibida (Diretiva Omnibus); informar como as avaliações são verificadas; ranking transparente (Regulamento P2B 2019/1150). Origem: legado 39:40-41.
- Antes do marketplace: parecer jurídico (DSA, P2B, Omnibus, DPO, avaliação de impacto, idade mínima de 14 anos), pagamento por conta conectada por estúdio, densidade mínima de estúdios por cidade. Origem: legado 39:50-55.
- Reserva em até 4 toques depois de escolher o serviço; teste ponta a ponta em 390 e 1440 px. Origem: legado 38:70,77.

## Pendências e perguntas
| Pergunta ou pendência | Origem |
|---|---|
| N3: depois da Fase 4, qual é a ordem (reserva online na frente das telas ou depois)? "Nada disso está na fila" | R3 B audit:167; R1 A N3·A |
| Modelo de receita do pacote (assinatura com site incluído, extra "Reserva online", taxa por cliente nova do marketplace) e 5 a 10 entrevistas com donas de estúdio antes de nova spec | R5 B ecossistema:67-69 |
| Sinal online: Stripe, Asaas ou outro provedor da UE? | legado 38:49; `docs/reference/stack.md:38` |
| Marketplace M3: assinatura, taxa fixa ou percentual com teto | legado 39:26-27 |
| Parecer jurídico, conta conectada e densidade mínima antes do marketplace | legado 39:50-55 |
| "Ficha não encontrada" em espanhol com "KA Beauty": corrigir | R3 B audit:31 |
| G7 (retoque incluído, atalhos +2, +4, +6 semanas, +3 meses) aparece classificado aqui no R3, mas pertence a Agendamento e Catálogo | R3 B fase1:119 |
| Política de sinal e de falta aplicada na reserva e na remarcação: planejada, sem dono | R5 B revisao-30-10:23 |
| Telefone na reserva online ainda com regra própria (DDI padrão +55 ou +34?) | R4 D 52 (`legado 52:308-311`); R1 A G8 |
| Conferir a segunda passada de pesquisa (sites da Karenn, SEO, anúncios, estudo do Google) | R5 D revisao-30-10:41-42 |
| Fotos do Fresha: estas imagens de referência (Reservas online, Site público) trazem dados reais de clientes (N2) | R3 B audit:171 |

## Referências
- Specs do legado: `docs/produto/legado/specs/16-online-booking-public.md`, `38-site-de-agendamento-do-estudio.md`, `39-portal-marketplace.md`, `25-agenda-blocks-filters-01.md` (70-71), `29-access-roles-modules.md` (módulo `reserva`), `00-product-operating-model.md` (fora da v1).
- Documentos do antigo: `produto/ecossistema.md`, `produto/revisao-30-10.md`, `docs/reviews/2026-10-29-revisao-profunda.md` (seção Mercado: Fresha cobra 20 % da cliente nova, Booksy Boost 30 %, Treatwell 25 % da 1ª visita; via R5 B).
- Prints do Fresha: `docs/fresha-prints-referencia/08-reservas-online`, `09-site-publico`. Mercado: `docs/referencias-mercado/booksy.md`, `treatwell.md`.
- Módulos vizinhos: CAI e COB (sinal), IDI (idiomas do site), MSG (código de confirmação e lembretes), SAA (módulo do plano).

Regra: só vale decisão registrada em `docs/decisoes/` (molde de pergunta). Tudo desta tabela é **a confirmar**; a situação antiga fica entre parênteses só como histórico e volta a ser perguntada quando o módulo for trabalhado (resposta 15a do dono, 24/11/2026).
