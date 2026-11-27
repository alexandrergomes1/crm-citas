# Spec 38 - Site de agendamento online do estúdio

## Status

Proposta (29 out 2026), pedida pelo Alexandre. Amplia a spec 16 (booking público), que continua
valendo para as regras de disponibilidade. Não implementar antes do núcleo validado (agenda,
checkout, anamnese, perfis) e de um teste E2E do caminho principal. Pesquisa de mercado:
`docs/reviews/2026-10-29-revisao-profunda.md`, seção "Mercado".

## Objetivo

Cada estúdio tem a própria página pública, bonita e rápida no celular, onde a cliente escolhe o
serviço, a profissional e o horário e reserva sozinha, 24 horas por dia, usando a agenda real.
Sem comissão sobre reservas vindas dos canais do próprio estúdio (link, QR code, Instagram,
Google), que é a maior reclamação contra Fresha, Booksy e Treatwell.

## Escopo do MVP

- Rota pública `/b/[slug]` (o `scope-master.md` previa `/booking/[org]`; manter um redirect).
  Idiomas: espanhol, português e inglês, escolhidos pela cliente.
- Página do estúdio: nome, fotos, endereço com mapa (link externo), horário de funcionamento,
  política de cancelamento e de sinal visível antes de confirmar.
- Fluxo: serviço → profissional (ou "qualquer uma") → dia e horário → dados da cliente
  (nome, telefone, e-mail) com código de confirmação (OTP por WhatsApp, SMS ou e-mail) →
  sinal, se a política exigir → confirmação.
- Depois de confirmar: e-mail/mensagem com link para remarcar ou cancelar (por token, dentro da
  política) e arquivo `.ics` para o calendário.
- Anamnese: nunca no formulário público. Se o serviço exige ficha, o link tokenizado da spec 12
  é enviado depois da reserva (já existe, expira em 7 dias).
- Configuração do estúdio: ligar/desligar o site, escolher serviços e profissionais publicáveis
  (`online_booking` já existe em serviços, produtos e profissionais), antecedência mínima e
  máxima, intervalo entre horários, política de sinal (spec 10).
- Módulo `reserva` da spec 29 (já existe a chave); só aparece para quem tem o módulo no plano.

## Regras

- Disponibilidade sempre calculada no servidor e sem cache, respeitando turnos, bloqueios
  (`time_blocks.allow_online_booking`), recursos, intervalos e bloqueio de booking da cliente.
- Reserva temporária do horário (`booking_holds`, expira em ~10 min) e garantia no banco de que
  duas reservas nunca ocupam o mesmo horário da mesma profissional (constraint de exclusão
  `tstzrange` + `btree_gist`, avaliar com o encaixe forçado que já existe).
- Cliente identificada por telefone E.164 e e-mail normalizado **só dentro do estúdio**; sem
  duplicar cadastro.
- Acesso anônimo apenas por funções `security definer` com `search_path` fixo que devolvem
  campos seguros. Nunca liberar SELECT direto de tabelas para `anon`.
- Anti-abuso: limite por IP, telefone e estúdio; CAPTCHA invisível; OTP; registro das tentativas.
- Origem gravada e imutável em cada agendamento: `booking_source` (`link`, `qr`, `instagram`,
  `google`, `marketplace`, `campanha`) e `first_touch_at`.
- Sinal online por provedor de pagamento da UE com conta do estúdio; webhook idempotente; o sinal
  entra direto na comanda (`appointment_deposits`, spec 10).
- Dados clínicos nunca em analytics nem pixels; pixels só com consentimento de cookies.
- SEO: página renderizada no servidor, schema.org `BeautySalon`/`Service`/`Offer`, `hreflang`
  (es, pt, en), sitemap. A disponibilidade fica fora do cache.

## Dados (propostos)

`org_public_profiles` (publicado, textos, fotos, endereço, coordenadas, idiomas, políticas),
`organizations.public_slug` único + `slug_redirects`, `booking_holds`, `public_booking_requests`
(com chave de idempotência), `booking_otp_challenges`, colunas `booking_source`/`first_touch_at`
em `appointments`. Toda tabela com `org_id` e RLS.

## Fora do MVP

Conta da cliente com login, avaliações, marketplace (spec 39), pacotes e vale-presente online,
Reserve with Google (integração por redirect exige parceria; no MVP basta o link de
agendamento no Perfil da Empresa no Google).

## Critérios de aceite

- [ ] Reserva feita no celular em até 4 toques depois de escolher o serviço.
- [ ] Duas reservas simultâneas no mesmo horário: só uma confirma.
- [ ] Cliente existente reconhecida pelo telefone, sem cadastro duplicado.
- [ ] Sinal pago aparece na comanda do atendimento.
- [ ] Serviço que exige anamnese envia o link da ficha depois da reserva.
- [ ] Remarcar e cancelar pelo link respeitam a política.
- [ ] Nenhuma tabela exposta a `anon`; teste de banco cobrindo as funções públicas.
- [ ] E2E Playwright em 390 e 1440 px.
