# Artefatos, endereços e serviços

Lista única do que fica fora do repositório. **Regra:** antes de criar uma página (artefato) nova, procure aqui;
se já existe uma para o assunto, atualize a mesma. Página nova entra nesta lista no mesmo commit.
Levantado em 23/11/2026 (`docs/reorganizacao/01-consolidado.md` §6).

## Páginas no claude.ai (artefatos)
| Endereço | O que é | Situação |
|---|---|---|
| claude.ai/artifact/95s7auBtPAReAohQmy15cQ | Proposta e andamento da reorganização | **em uso** |
| claude.ai/artifact/YBjctyzxXKNjDnf7ArZKGo | Design system publicado (versões 40 a 42) | referência; a confirmar (Q1 = A) |
| claude.ai/artifact/7FMM8AKnUTuVtjB54wcGhP | Canvas da Agenda (AG1 a AG15, lacunas) | histórico |
| claude.ai/artifact/8VJGZZmXcGydTZhvVZedod | Ficha de tela inteira v1/v2; AG24 a AG27 | histórico |
| claude.ai/artifact/P2XeWVomMgDGzmvFvjdc2e | Lista única da Fase 1 ("aceito todas") | histórico |
| claude.ai/artifact/75dfnF6iwExz8xp6Betbte | Estudo de layout de 20/11 (P1 a P3) | histórico |
| claude.ai/artifact/W4c4wxScPYuxy8w9GThAwN | Sugestões S1 a S5 e comparação #123/#124 | histórico |
| claude.ai/artifact/3oiyjjPjUqU4uUhvnyFU2j | 42 divergências do design system | histórico |
| claude.ai/artifact/Fboqqjjtwr3yXAH2zSMh3Y | Fotos das duas versões da Agenda (#127) | histórico |
| claude.ai/artifact/NxjfwSLoZMj1N81a5q8nT6 | Design system "KA Beauty OS" (#64, não fundido) | histórico |
| claude.ai/artifact/5ZEWXe3nyEva3bGtqkDmXZ | Comparativo do design system de 19/11 (respostas ficaram só no navegador) | histórico |
| claude.ai/code/artifact/24e4ae39-6822-4d21-a496-d1d643c090ec | Comparativo (outro endereço) | histórico |
| claude.ai/artifact/AN3BbPu56KJFqfMh7kDp8R | Livro de padrões KA Beauty | histórico |
| claude.ai/artifact/3yydB1zhNrxqHLNPBpaZtj | Mesa de decisão antiga | histórico |

## Ambientes do app
| Endereço | O que é |
|---|---|
| crm-agenda-previas.alexandrergomes.workers.dev | Prévia (branch `previas`) |
| crm-agenda.alexandrergomes.workers.dev | Produção (branch `main`) |
| ka-mesa.alexandrergomes.workers.dev | Mesa antiga (Worker `ka-mesa`), sem uso; desligar com ok do dono |
| crm-agenda-preview.alexandrergomes.workers.dev | Proposta não fundida (#114) |

## Serviços
| Serviço | Uso |
|---|---|
| Supabase `qjcabltvchmzmpigiyrv` | Banco de desenvolvimento e teste |
| Supabase `bwpltaufyenmumsfaczb` | Banco de produção (o MCP do Supabase aponta para ele: uso bloqueado) |
| Cloudflare (Workers, R2 `crm-agenda` na UE) | App e backup cifrado |
| Backblaze B2 | 2ª cópia do backup (previsto) |
| GitHub `alexandrergomes1/crm-agenda` · `alexandrergomes1/beauty-system` | Repositório atual · antigo (só leitura) |
| Vercel (`studio-sites`, `kabeautysys`, `v0-sgautomotive`) | Projetos antigos a desligar depois da virada |
| Previstos na virada | Sentry, UptimeRobot, Resend, PostHog, Turnstile, Workers Logs |
| Integrações citadas | WhatsApp (Meta Cloud API), Brevo, Stripe, Asaas, Twilio, n8n |

## Fora do repositório (perdido ou só local)
Respostas do comparativo de 19/11 (`localStorage` do navegador); geradores de imagem em `/home/claude/r10shots`;
corpos dos PRs #45 a #49; fontes das falas do dono (`anteriores.md`).
