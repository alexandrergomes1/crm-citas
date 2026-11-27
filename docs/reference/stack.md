# Stack — fonte única (13/11/2026)

Congelada por 60 dias (até 12/01/2027). Mudança só dizendo qual linha mudou e por quê, registrada no fim.
Legenda: J = já · G = no go-live · D = depois (com gatilho).

## Instalado hoje x previsto
Este documento lista a stack **decidida**, que inclui o que ainda não foi instalado. Confira no
`package.json` antes de usar uma biblioteca. Em 19/11/2026:

| Instalado e em uso | Previsto, ainda **não** instalado |
|---|---|
| TanStack Start e Router · React 19 · Vite · Tailwind v4 · Radix · Lucide · cmdk · Geist · Zod · react-hook-form · Supabase (`@supabase/ssr`, `supabase-js`) · Vitest · Testing Library · Playwright · ESLint 9 · Wrangler | TanStack Query, Table e Virtual · next-themes · Motion · Paraglide (idiomas: a decisão está na fila) · axe · Sentry · Turnstile |

Também previsto e ainda não ligado: cópia diária do Storage; restauração testada todo mês (o agendamento
está desligado até a virada); CSP completa. Lista da virada: `docs/runbooks/go-live.md`.

## Tela
TypeScript strict · Vite 8 · TanStack Start (start-server-core ≥ 1.169.39) · TanStack Router · TanStack Query (ainda sem uso no código em 15/11) · TanStack Table + Virtual (listas longas) · React 19 · Tailwind v4 · design system próprio (Radix + CVA + Lucide) · Geist via @fontsource-variable · next-themes (confirmar no piloto) · Motion + View Transitions · React Hook Form + Zod 4 · Paraglide (es/pt/en) · libphonenumber-js + Intl · SSR desligado por padrão.

## Servidor
Server functions do Start com Zod + acesso ao estúdio + permissão + auditoria (J) · src/domain e src/data reaproveitados (J) · rotinas: tabela outbox no Postgres + Cloudflare Cron de 1 min (G) · trabalho noturno no GitHub Actions (G) · webhooks com assinatura e idempotência (D) · API pública Hono + OpenAPI no mesmo Worker (D: reserva online).

## Dados
Supabase Postgres UE · RLS por org_id · @supabase/ssr + tipos gerados (J) · Supabase Auth com SMTP do Resend (G) · Supabase Storage, guardar caminho e nunca link, foto comprimida no aparelho (G) · Supabase CLI + replay das migrations no CI (J) · Realtime na agenda (D) · KV só para limite de tentativas (D).
Projetos: desenvolvimento = Beauty System (antigo); produção = crm-agenda.

## Backup e redundância
pg_dump diário criptografado (senha forte, AES-256) via GitHub Actions → R2 UE + 2ª cópia Backblaze B2; retenção 7/4/3; chave fora do GitHub (J) · cópia diária do Storage para o R2 (G) · restauração testada todo mês (J) · sinal de vida de cada rotina (J) · Supabase Pro (G) · plano B: build testado uma vez fora da Cloudflare (G) · DNS exportado + 2 administradores (J). Metas: até 4 h fora do ar, até 24 h de dados.

## Hospedagem, rede, segurança
Cloudflare Workers (Free no desenvolvimento, Paid US$ 5 no go-live) · Smart Placement · deploy pelo Workers Builds ligado ao GitHub: prévia por PR, produção só do main · DNS, WAF, Turnstile, limite de tentativas no login e no PIN · CSP, HSTS e cabeçalhos · segredos só na Cloudflare e no GitHub · pnpm com versões travadas e idade mínima · Dependabot · gitleaks no CI · DPAs em docs/legal antes do go-live.

## Observabilidade
Sentry org UE (navegador @sentry/react, servidor @sentry/cloudflare; sem replay nas fichas; sem dado pessoal) (G) · Workers Logs (G) · audit_log no Postgres · UptimeRobot + /health + página de status (G) · relatório semanal de qualidade (G) · PostHog UE (D: 2º estúdio).

## Integrações
Resend (G) · WhatsApp: wa.me manual (G), API oficial da Meta com os lembretes automáticos (D), WAHA nunca · pagamentos: transferência com comprovante (G), Stripe e Asaas (D).

## Qualidade
Vitest · Playwright 390/1440 · testes de isolamento do banco · axe · ESLint 9 · CI no GitHub Actions (runner fixo ubuntu-24.04).

## Custo
Desenvolvimento ~US$ 1/mês · go-live ~US$ 31/mês (Supabase Pro 25 + Workers 5 + domínio).

## Registro de mudanças
- 13/11: Renovate → Dependabot (já vem no GitHub, sem app a instalar). CodeQL e secret scanning saem: em repositório privado de conta pessoal não são grátis; o gitleaks no CI cobre os segredos.
- 13/11: Sentry e Resend sem conector no Claude (decisão do Alexandre): painel + segredos.
- 13/11: chave age → senha forte com AES-256 (gpg, já vem no GitHub): o Alexandre não precisa instalar nada para gerar a chave. A senha fica no gerenciador de senhas e como segredo do GitHub (necessária para o teste mensal de restauração).
- 15/11: Start mantido, sem troca. A alternativa Vite + Router + Query + Hono (análise de 14/11) não foi adotada: ver `docs/adr/2026-11-15-stack-start.md`. Motivo principal: a troca agora mexeria em 48 arquivos de funções de servidor que já passaram nos testes, e o benefício do Hono (API pública) só entra quando um canal externo pedir.
- 15/11: correção na linha de Tela: o Query consta como usado, mas nenhum arquivo do código o importa ainda.
- Gatilhos para reabrir: canal externo real pedir API pública (reserva online, integração de terceiros), ou o teste de funções de servidor não conseguir cobrir todas.
