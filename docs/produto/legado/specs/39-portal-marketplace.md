# Spec 39 - Portal público / marketplace

## Status

Proposta (29 out 2026), pedida pelo Alexandre. Depende da spec 38 (site de agendamento do
estúdio) em produção e de vários estúdios ativos na mesma cidade: com um só estúdio não existe
marketplace. Pesquisa de mercado e riscos: `docs/reviews/2026-10-29-revisao-profunda.md`.

## Objetivo

Um portal onde qualquer pessoa encontra estúdios e serviços de estética perto dela, compara e
reserva, como Fresha, Booksy e Treatwell, mas com regras justas para o estúdio: **nunca cobrar
comissão sobre cliente que já é do estúdio**, origem de cada reserva visível e contestável, e
dados clínicos que nunca saem do estúdio.

## Fases

- **M0 – Diretório:** perfis públicos indexáveis dos estúdios que aderirem (adesão opcional),
  busca por cidade e tipo de serviço. A reserva acontece na página do estúdio (spec 38). Sem
  conta de consumidora.
- **M1 – Conta da cliente:** login (Supabase Auth), "minhas reservas" em todos os estúdios,
  favoritos, busca "disponível hoje". Cada estúdio vê só o próprio histórico da cliente.
- **M2 – Avaliações verificadas:** só depois de atendimento concluído e pago, uma por
  atendimento, janela de 30 dias, resposta do estúdio, denúncia com moderação, selo
  "verificada". Critérios de ranking públicos.
- **M3 – Monetização e Google:** modelo de receita decidido (assinatura, taxa fixa por cliente
  nova ou percentual com teto) e Reserve with Google como parceiro da plataforma (redirect).

## Regras

- Adesão ao marketplace por estúdio, desligável a qualquer momento sem perder o site próprio.
- Cliente "nova" do marketplace: não está na base do estúdio e não foi atendida nos últimos
  365 dias. Cliente da base nunca gera taxa, venha de onde vier.
- Atribuição gravada e imutável (`booking_source`, `first_touch_at`); o estúdio vê a origem de
  cada reserva e pode contestar.
- Papéis de dados (GDPR/LOPDGDD): o estúdio é controlador dos dados da cliente e da anamnese;
  o KA Beauty OS é operador. No marketplace, a plataforma é controladora da conta da
  consumidora e precisa de consentimento explícito para compartilhar dados com cada estúdio.
- Nenhum dado clínico no marketplace, em buscas, avaliações ou analytics.
- Avaliação falsa é proibida (Diretiva Omnibus): informar como as avaliações são verificadas.
- Transparência de ranking (Regulamento P2B 2019/1150).

## Dados (propostos)

`consumer_accounts`, `consumer_org_links` (consentimento por estúdio), `reviews`
(`appointment_id` único, status de moderação, resposta), `review_reports`,
`marketplace_listings` (adesão, categorias, cidade, coordenadas), `marketplace_fees`
(quando houver monetização). RLS separando o espaço da consumidora do espaço do estúdio.

## Validar antes de construir

- Parecer jurídico: DSA (serviços digitais), P2B, Omnibus, DPO e avaliação de impacto (DPIA)
  para estética com procedimento médico-estético, idade mínima (14 anos na LOPDGDD).
- Pagamentos: conta conectada por estúdio para não cair em regras de serviço de pagamento.
- Densidade: número mínimo de estúdios por cidade para abrir o diretório.

## Critérios de aceite (M0)

- [ ] Estúdio adere e sai do diretório sem afetar o site próprio.
- [ ] Busca por cidade e serviço devolve só estúdios publicados e serviços publicáveis.
- [ ] Perfil do estúdio indexável (SSR, schema.org, sitemap) sem expor dados de clientes.
- [ ] Reserva vinda do diretório grava `booking_source = 'marketplace'`.
