# Módulo: Plataforma (PLT)

> O que sustenta o app por baixo: entrar e sair, vários estúdios no mesmo sistema sem se misturarem, banco de dados, segurança, cópia de segurança, hospedagem e a proteção de dados das clientes (RGPD).
> O dono quase não vê isto na tela, mas é o que decide se o sistema pode abrir para clientes reais.

**Telas e rotas:** `/login`, `/logout`, `/reset-password`, `/trocar-senha`, `/` (raiz), `/{org}/configuracoes?secao=dados`, páginas públicas `/forms/{token}` e `/pagar/{token}`; o resto é infraestrutura sem tela · **Código:** `src/auth/`, `src/server/`, `src/data/`, `src/lib/safe-redirect.ts`, `src/lib/public-paths.ts`, `src/server/public-headers.ts`, `src/domain/access.ts`, `supabase/migrations`, `supabase/tests`, `scripts/db/`, `.github/workflows/` (CI, backup, migrations, segurança) · **Spec(s):** só `docs/specs/teste-funcoes-servidor.md` (rascunho) no atual. Fatos em `docs/reference/database.md`, `server.md`, `stack.md`, `project.md`, `docs/runbooks/backup-restore.md`, `go-live.md`, `SECURITY.md`. No legado: specs 03, 19, 21, 22, 23, 47; `docs/produto/legado/produto/security-baseline.md`, `saas-stack-decision.md`; `docs/produto/legado/legal/`.

## Recursos
| ID | Recurso | Estado | Onde | Origem |
|---|---|---|---|---|
| PLT-01 | Login com e-mail e senha no Supabase Auth, em 2 etapas (primeiro o e-mail, depois a senha); mensagem fixa "e-mail ou senha incorretos" | pronto (atual: login) · fase 0 pronta (antigo) | `/login`; `src/auth/LoginForm.tsx`, `email-step.ts` | R2 B STATUS:27; R4 B spec 47:36-53; legado spec 47 §5 |
| PLT-02 | Sair da sessão só por POST (o GET foi removido para evitar sair por link de outro site) | pronto | `/logout`; `routes/logout.ts` | `routes/logout.ts` (comentário); R2 C70 |
| PLT-03 | Esqueci a senha e criar senha: link enviado pela equipe (`/reset-password`); consumido só ao enviar o formulário | pronto | `/reset-password`; `src/auth/reset-actions*.ts` | R4 B spec 47:§1; R2 B STATUS:35 |
| PLT-04 | Esqueci a senha por e-mail na produção (SMTP próprio, endereço em Redirect URLs, link de 3600 s) | planejado | painel do Supabase | R2 D.2 ICEBOX:19 |
| PLT-05 | Primeiro acesso com senha provisória: a pessoa cria a própria senha antes de usar o estúdio | pronto | `/trocar-senha` | R2 A regras-de-produto 6; `routes/trocar-senha.tsx` |
| PLT-06 | Sessão: sessão vencida leva ao login; depois do login só vai para caminho interno do app | pronto | `src/lib/safe-redirect.ts`; `src/data/auth/session.ts` | R4 A spec 03 (Decisão 28 out); R4 B spec 47 §1 |
| PLT-07 | Sem cadastro público: o acesso nasce por convite da dona do estúdio | pronto (regra) | Ajustes › Acessos | R4 B spec 47:13,52-53; legado spec 03 (fora de escopo) |
| PLT-08 | Entrar com código de 6 dígitos por e-mail | planejado (fase 1; depende de SMTP próprio) | slot `alternatives` do `AuthCard` | R4 B spec 47:73-85 |
| PLT-09 | Entrar com Google (e Apple só se houver app iOS), só para quem já foi convidado | planejado (fase 2); antigo spec 03: "fora do escopo v1" | `AuthCard` | R4 B spec 47; spec 03:121-126 |
| PLT-10 | MFA (segundo fator) obrigatório para dona, admin e financeiro; passkeys só quando saírem do modo experimental | planejado (fase 3) | — | R4 B spec 47; legado security-baseline §2 |
| PLT-11 | Proteção contra senha vazada (exige plano Pro do Supabase), política de senha (10+ ao criar, 6+ no login) | planejado, antes de clientes reais | painel do Supabase | R4 B spec 47:13,52-53 |
| PLT-12 | Limite de tentativas no login e no PIN; Turnstile (CAPTCHA); limite nas páginas públicas | planejado: hoje só existe a contagem no banco; Turnstile "não está no código" | login, modo estúdio, `/forms`, `/pagar` | R2 D.2 ICEBOX:23 (item 40); server.md:42-45; R5 B revisao-30-10:16 |
| PLT-13 | Convite com aceite, remover pessoa da equipe, criar estúdio novo sem a chave de serviço | planejado (precisa de spec) | Ajustes › Acessos | R2 D.2 ICEBOX:33 (item 26); R4 B spec 29 |
| PLT-14 | Vários estúdios no mesmo sistema (multiestúdio): toda tabela tem `org_id`, o endereço traz o estúdio e o banco confere se a pessoa pertence a ele | pronto | `/{org}/...`; `organizations`, `user_roles` | R4 B spec 03:35-42; database.md:28 |
| PLT-15 | Uma pessoa em vários estúdios (`user_roles`) | pronto na tabela · sem trocador de estúdio na tela (ver NAV-24) | banco | R4 B spec 03; R4 B spec 02 |
| PLT-16 | Papéis: owner, admin, manager, professional, receptionist, finance, viewer; permissões por papel e exceções do estúdio | pronto | `src/domain/access.ts`; Ajustes › Perfis | R4 B spec 29, 37; R2 B STATUS:34 |
| PLT-17 | Módulos por estúdio: o plano liga e desliga módulos | pronto como dado (base); telas de plano e área master só em mockup | `has_permission`, `NavAccess` | R4 B spec 29; R2 B ICEBOX:29 |
| PLT-18 | Teste de que o estúdio A não lê nem grava no estúdio B, para toda tabela ou política nova ou alterada | pronto (regra) · parcial: políticas sem teste ainda (ICEBOX 14) | `supabase/tests/` | database.md:39; R2 D.2 ICEBOX:14 |
| PLT-19 | Testes multiestúdio: apagar um estúdio inteiro, mover dado, o que fazer com a ficha quando o estúdio cancela | planejado (precisa de spec) | — | R2 D.2 ICEBOX:13 |
| PLT-20 | Proteção ativa (RLS) em toda tabela do estúdio; a CI reprova tabela sem RLS, sem `org_id`, política aberta, função `security definer` sem `search_path` ou aberta ao anônimo | pronto | `supabase/tests/10_security_checks.sql` | database.md:16-26; R2 C76 |
| PLT-21 | Chave estrangeira composta com `org_id` (um registro nunca aponta para outro estúdio): só em 3 relações antigas; em tabela nova é obrigatória; as simples (mensagens, marketing, locais) ficam para depois | parcial · planejado (item 46) | `118_tenant_composite_fks.sql` | database.md:28-30; R2 D.2 ICEBOX:50 |
| PLT-22 | Migrations reproduzíveis: a CI cria um banco vazio, roda todas em ordem e roda os testes (`pnpm db:verify`) | pronto | `scripts/db/`; `.github/workflows/ci.yml` | R5 B core-delivery:110-117; R2 C115; database.md:7-11 |
| PLT-23 | Aplicação automática das migrations no banco de desenvolvimento ao fundir; produção só com autorização do dono e backup do dia conferido | pronto | `.github/workflows/migrations-dev.yml` | database.md:7-11; R2 C75 |
| PLT-24 | Escrita em vários passos numa função do banco, numa transação; auditoria gravada pelo banco, não por `insert` livre | pronto | `src/data/`; funções SQL | server.md:23-30; R2 C77 |
| PLT-25 | Checkout atômico e idempotente (venda, pagamentos, lançamentos, pontos, vale com bloqueio); reenvio não duplica | pronto (antigo `[x]`) · parcial: a spec 09 ainda tem `[ ]` | RPC do checkout | R4 B spec 22:37-52,103-104; R4 F |
| PLT-26 | Saldos e pontos só por extrato (ledgers que só acrescentam: saldo, pontos, vale-presente, auditoria) | pronto (antigo) | tabelas `*_entries`, `audit_logs` | R4 A spec 23:57-67 |
| PLT-27 | Orçamento de idas ao banco: tela logada 2, página pública 1, ação 2; sem consulta em laço; função nova entra no teste do orçamento | pronto (regra) · o teste só trava as funções da lista | `docs/reference/db-budget.md`; `src/data/supabase-calls.test.ts` | R2 C80; R2 A regras-de-produto 5 |
| PLT-28 | Função de servidor: confere dados com Zod, confere estúdio e permissão, audita; resposta `{ ok: true }` ou `{ ok: false, error }` em português, nunca o texto cru do banco | pronto | `src/server/`, `src/**/actions.server.ts` | server.md:23-30; R2 C77 |
| PLT-29 | A chave `service_role` só no servidor e só onde a RLS não alcança (fotos da ficha, páginas públicas, esqueci a senha, criar acesso) | pronto | `src/server/` | server.md:25-30; R4 A spec 03 |
| PLT-30 | Cabeçalhos de segurança: HSTS, `nosniff`, `Referrer-Policy` em toda resposta; páginas sem login com `no-store`, `noindex`, `Referrer-Policy: same-origin` (`/trocar-senha` fora da lista) | pronto | `src/server/public-headers.ts`; `src/lib/public-paths.ts` | server.md:32-40; R2 C70 |
| PLT-31 | Política de conteúdo (CSP) completa | planejado: hoje só `frame-ancestors 'none'` | cabeçalhos | server.md:42; R2 D.2 ICEBOX:23 |
| PLT-32 | Link da ficha guardado só como hash, com validade; "Reenviar link" gera novo e invalida o anterior | pronto | `/forms/{token}` | server.md:40; R2 A regras-de-produto 7 |
| PLT-33 | Idempotência em `/pagar` e nos webhooks (reenvio não duplica) | planejado (precisa de spec) | `/pagar`, `/api/webhooks/whatsapp` | R2 D.2 ICEBOX:12; server.md:45 |
| PLT-34 | Teste automático de que toda função de servidor recusa sem sessão e com sessão de outro estúdio; lista das funções públicas | planejado (rascunho: escolha A, B ou A+B pendente; recomendação B com A de barreira) | `docs/specs/teste-funcoes-servidor.md` | R3 B teste-funcoes:3-23; R2 D.2 ICEBOX:32 |
| PLT-35 | Segredos só nos painéis da Cloudflare e nos segredos do GitHub; a CI procura segredo em todo PR (gitleaks); Dependabot para dependências | pronto | `.github/workflows/seguranca.yml` | SECURITY.md:6; R2 C64; stack.md:46-51 |
| PLT-36 | Auditoria completa antes da virada (cada perfil só vê o que deve; quem lê e altera a ficha de saúde; proteção em todas as tabelas; limite nos links públicos; registro de decisões contra o app) | planejado | — | go-live.md:11; R2 D.2 ICEBOX:10 |
| PLT-37 | Uma rodada escopada do `claude-security` | planejado, bloqueado (precisa da autorização do dono) | — | R2 D.2 ICEBOX:20 |
| PLT-38 | Roteiros escritos: rotação de segredo e vazamento de dados (aviso à autoridade em 72 h) | planejado (não escritos) | `SECURITY.md` resume | R2 D.2 ICEBOX:15,16; R2 C65 |
| PLT-39 | Dado pessoal em log: conferir com a skill de observabilidade | planejado | logs | R2 D.2 ICEBOX:47 |
| PLT-40 | Backup diário do banco: cifrado (AES-256), guardado no Cloudflare R2 na União Europeia, retenção 8, 35 e 100 dias | pronto e provado em 13/11; agendamento desligado até a virada | `.github/workflows/backup-diario.yml`; `backup-restore.md` | backup-restore.md:3-13; R2 B |
| PLT-41 | Teste mensal de restauração (restaura num banco descartável e confere clientes, agendamentos e estúdios) | pronto; agendamento desligado até a virada | `teste-restauracao.yml` | backup-restore.md:13-14 |
| PLT-42 | Segunda cópia no Backblaze B2 | planejado (obrigatório antes da virada) | — | backup-restore.md:36-37 |
| PLT-43 | Cópia diária das fotos da anamnese (Storage) no backup | planejado (precisa de spec) | — | R2 D.2 ICEBOX:21 |
| PLT-44 | Usuário só de leitura para o backup | planejado | banco | R2 D.2 ICEBOX:22 (item 39) |
| PLT-45 | Alerta de backup atrasado (mais de 26 h) e painel de Operação | planejado, bloqueado por decisão (só os avisos de cada ferramenta ou painel próprio?) | — | go-live.md:37; R2 D.2 ICEBOX:18 |
| PLT-46 | Faxina diária das fotos órfãs da anamnese | planejado (vai com a virada; precisa de chave de serviço no GitHub) | — | R2 D.2 ICEBOX:34; go-live.md:31 |
| PLT-47 | Hospedagem: Cloudflare Workers (prévia por PR e produção só do `main`); Workers pago e domínio próprio na virada; Supabase Pro | pronto (prévia e produção de teste) · planejado (virada) | `wrangler`, Workers Builds | stack.md; go-live.md |
| PLT-48 | Duas pistas: prévia (`previas`) atualiza sozinha ao "pode fundir"; produção só com "pode publicar" | pronto | GitHub, Cloudflare | adr/2026-11-17-dois-degraus.md:13-18; OWNER |
| PLT-49 | Sentry (UE, sem dado pessoal), UptimeRobot e `/health`, Workers Logs, PostHog | planejado (no go-live ou depois) | — | stack.md:34; go-live.md:35-41 |
| PLT-50 | Lista única da virada: 12 itens "antes de ligar", 7 "no dia" e rotina "depois de ligar" | planejado | `docs/runbooks/go-live.md` | go-live.md:7-41 |
| PLT-51 | Desligar a Vercel e arquivar o sistema antigo 30 dias depois da virada; Fresha em paralelo por 2 semanas | planejado | — | R2 B ROADMAP:14; go-live.md:34 |
| PLT-52 | Teste de acessibilidade automático (axe) nos E2E; regressão visual com imagens de referência | planejado | — | R2 D.2 ICEBOX:54, 42 |
| PLT-53 | Integrações Google Calendar, Meta e analytics (nenhum dado clínico em analytics) | planejado, não iniciado (antigo) | — | R4 B spec 19:5-15,22-31 |
| PLT-54 | Código morto: 18 módulos usados só pelos testes e cerca de 30 funções de dados sem uso; `docs/` com 61 MB e 100 imagens repetidas | planejado (Fase 4) | `src/domain`, `src/data` | R3 B audit:37-41 |
| PLT-55 | Medição de desempenho por tela (rotina sem IA); limites do Workers (CPU, subrequisições) em `db-budget.md` | planejado | — | R2 D.2 ICEBOX:41,45 |
| PLT-56 | Benchmark de desempenho do antigo (`pnpm perf:core`) e metas de abertura | pronto (antigo) · sem equivalente declarado no atual | — | R4 B spec 21:41-47 |
| PLT-57 | Vitrine `/showcase` dentro do app | descartado (cancelada em 22/11) | — | R3 B vit:5; BACKLOG:22 |
| PLT-58 | Trocar para Vite, Router, Query e Hono | descartado (registrado); reabre só se um canal externo pedir API pública ou o teste de funções não cobrir todas | — | adr/2026-11-15-stack-start.md:29-38 |
| PLT-59 | API pública (Hono e OpenAPI) para a reserva online | planejado depois | — | R2 B stack:21 |
| PLT-60 | Fotos do Fresha com nome e telefone de clientes reais no repositório (225 arquivos, 11 MB) | planejado: tirar do repositório e do histórico (N2·A, aceite em lote); nada feito | `docs/fresha-prints-referencia/` | R3 B audit:171; fase1:133; R1 A.2 N2 |
| PLT-61 | Ambientes de banco: desenvolvimento = projeto antigo (Beauty System); produção = projeto crm-agenda; prévia e produção ainda usam o mesmo banco; a conexão MCP aponta para a produção | pronto (fato) | `docs/reference/project.md` | stack.md; database.md; R2 C101 |
| PLT-62 | Banco de dados para o Brasil: um segundo banco em São Paulo só se a medição mostrar lentidão | planejado (condicional) | — | R2 A.2 ROADMAP:16-19 |

### Privacidade (RGPD)
| ID | Recurso | Estado | Onde | Origem |
|---|---|---|---|---|
| PLT-63 | Dado pessoal nunca em log, endereço, ferramenta de erro ou resposta a quem não deve; a ficha de anamnese é dado de saúde (RGPD art. 9) | pronto (regra escrita) · conferência de log ainda planejada (PLT-39) | todo o código | SECURITY.md:4-5; R2 C63; R5 B security-baseline §8 |
| PLT-64 | Consentimento por finalidade, cada uma separada: atendimento, ficha de segurança, ficha profissional, assinatura, foto interna, imagem pública, WhatsApp operacional, marketing, avaliação no Google, pagamento | planejado (modelo de 10 finalidades) | — | legado legal §4; R5 B legal; R5 F.2-2 |
| PLT-65 | Modelo de dados do consentimento: textos por país, idioma e versão (`consent_templates`) e registro por cliente (`client_consents`: valor aceito, recusado ou retirado, versão, idioma, quem registrou, origem, data) | planejado (direção de arquitetura, "não implementar às cegas") | banco | legado legal §6 |
| PLT-66 | Imagem pública (antes e depois no marketing) em Sim ou Não separado; a recusa aparece para a profissional e não bloqueia o atendimento; foto interna de avaliação é outra coisa | planejado | Anamnese, Clientes | legado legal §3.2, §7.1; R5 B legal |
| PLT-67 | Texto de privacidade curto e visível, com o texto completo ao abrir; guardar a versão aceita | planejado | formulário público | legado legal §3.3, §5 |
| PLT-68 | Jurisdição configurável por estúdio (ES, PT, BR, GLOBAL); não chamar de "LGPD" o termo global | planejado | `organizations` (campos propostos) | legado legal §1, §6; R5 A |
| PLT-69 | Direitos da pessoa: acesso, apagamento e portabilidade (arts. 15, 17 e 20) | planejado, bloqueado por decisão (ICEBOX 9); "não coberto ainda" | — | R2 D.2 ICEBOX:9; database.md:51-53 |
| PLT-70 | Prazo de retenção de anamnese, fotos e notas; apagar ou arquivar | planejado, sem prazo definido | — | legado legal §8 pergunta 6; database.md:51-53 |
| PLT-71 | Base legal, registro de tratamento e política de privacidade e termos de uso públicos | planejado (as páginas não existem; o login omite o rodapé por isso) | — | ICEBOX:9, 29; R4 B spec 47:§4 item 7 |
| PLT-72 | Cifra em repouso da ficha de anamnese | planejado | banco | database.md:51-53; R2 C68 |
| PLT-73 | Contrato com o estúdio (quem é controlador e quem é operador) e contas da empresa com 2 administradores | planejado | — | R2 D.2 ICEBOX:9; legado legal §7.3 |
| PLT-74 | Auditoria de quem lê e altera a ficha de saúde; tela de consulta da auditoria (`audit_logs` hoje sem consulta administrativa) | planejado | — | legado security-baseline §3, §5; R5 B (backend sem superfície) |
| PLT-75 | Registro do consentimento com data, hora e IP (e IP e agente do navegador na assinatura da ficha) | parcial / planejado (parte entregue na spec 12 do antigo) | `/forms/{token}` | R4 B spec 22:74-78; R5 B checklists/security:14-28 |
| PLT-76 | Marketing só para quem disse SIM; recusa vale por meio; o envio confere de novo na hora; opt-out antes do envio | pronto (regra no atual) · planejado (motor de envio) | Marketing | R2 C66; R2 A regras-de-produto 3 |
| PLT-77 | Ficha assinada pode ser corrigida sem perder o original | pronto (risco aceito: o link da correção leva as respostas anteriores; validade padrão 7 dias) | Anamnese | R2 C67; adr/2026-11-19-regras-de-produto.md:6 |
| PLT-78 | Recepção vê só o status da ficha, não o conteúdo clínico (leitura clínica por papel) | pronto (antigo) · o menu mostra Anamnese a quem não pode (R3 B audit:27) | RLS | R4 A spec 29; R5 A |
| PLT-79 | Quem vê o texto do alerta da cliente (alergia) na agenda: hoje toda a equipe que vê a agenda, mesmo sem permissão de clientes | pendência para o dono (recomendação B: só quem vê clientes) | Agenda | OWNER:59 (pergunta 4) |
| PLT-80 | Menores de idade não são atendidos (sem fluxo de responsável) | decidido no antigo, sem prova | Clientes | legado legal §7.2; R5 A 7.2 |
| PLT-81 | Anonimização com retenção legal e política de exclusão da cliente (hoje só arquivar; "Excluir cliente" saiu da tela) | planejado | Clientes | R4 B spec 06; R5 B roadmap:112 |
| PLT-82 | Dado clínico nunca em analytics, marketplace ou prévia; IP truncado | não veio ao atual como regra escrita | — | R5 F.2-2; R5 A |
| PLT-83 | Seção "Privacidade" em Ajustes | parcial: existe no código e não aparece no menu | `src/workspace/ajustes/sections.ts` | R3 B audit:30 |
| PLT-84 | Subprocessadores com contrato: DPA do Sentry, Cloudflare, Supabase, Resend; `docs/legal` (pasta de DPAs) não existe | planejado | `docs/legal` (inexistente) | stack.md:31; R2 C71, F-18; R5 F |
| PLT-85 | Termos legais da anamnese por país e idioma, revisados por profissional antes de produção | planejado | Anamnese | R5 B; legado legal; R4 B spec 27 |
| PLT-86 | Storage: um bucket por finalidade (catálogo, fotos de cliente e anamnese, documentos assinados, uploads internos), privado por padrão, URL assinada, nada público para foto clínica, sem uso em marketing sem consentimento de imagem | planejado (antigo) | Storage | R5 B security-baseline:158-172 |
| PLT-87 | Validação de UUID, campo opcional vazio vira `null`, checkout lê cliente e profissional do agendamento gravado, leituras independentes em paralelo; ações validam estúdio, papel, UUID e JSON | pronto (antigo) | funções de servidor | legado spec 21:27-40,107-117 (R4 B); R5 B product-vision-detail:97-104 |
| PLT-88 | Entidades de domínio do antigo a reaproveitar (Client, Appointment, Sale, GiftCard, LoyaltyTier e outras) e tabelas que faltavam (memberships, audit_logs, client_entitlements, marketing_*, loyalty_*, public_booking_requests e outras) | referência (antigo) | `src/domain`, banco | R5 B scope-master:145-158 |
| PLT-89 | Arquitetura do antigo: camadas de código, modelo de dados-alvo por área e o que reaproveitar (domínio com 87 testes, migrations como referência; não copiar `*Manager.tsx`) | referência (antigo) | — | R5 B architecture:126-139,163-209,220-232 |
| PLT-90 | Padrões exigidos antes de módulos grandes: casco, base de segurança, orçamento de desempenho, checklists de produção, regra Server Component × Action × RPC | planejado (antigo) | — | R5 B saas-stack-decision:101-110 |
| PLT-91 | Análise de infraestrutura de 29/10: gatilhos de mudança de plano, custo de sair do Supabase, Realtime não usado, estimativa de consumo por estúdio | informativo (antigo; Vercel e Supabase) | — | R5 B hospedagem-e-banco:35-40,94,113,119-135,167,222,236-251 |
| PLT-92 | Orçamento de CI: 2.000 min/mês, cancelamento de execução repetida, docs fora da CI, conferências locais antes do PR | histórico (antigo) | CI | R5 B politica-de-deploy:35-61 |
| PLT-93 | Diagnósticos de desempenho de junho (Next.js): autenticação repetida, compilação lenta em dev, metas p95 por rota e por ação | histórico (antigo) | — | R5 B performance-diagnostic-2026-06-13:9-135; agenda-reliability-audit-2026-06-14:53-63 |

"Estado" é o que os documentos dizem; o código é conferido quando o módulo entra em trabalho.

## Privacidade (RGPD)
**RGPD não bloqueia o desenvolvimento.** As telas e funções podem ser construídas e testadas com dados de teste. A conferência de proteção de dados é feita **antes da virada** (antes de abrir o sistema a clientes reais): ela é o item 1 da lista "Antes de ligar" em `docs/runbooks/go-live.md`, junto com a auditoria completa (item 2) e os roteiros de vazamento e de rotação de segredo (itens 3 e 4). Hoje a produção está parada e só tem dados de teste (OWNER:8).

Duas observações do que os documentos dizem:
- O item 9 da geladeira (`docs/ICEBOX.md`) continua "bloqueado por decisão" e pergunta: (A) um especialista em proteção de dados confere o sistema, ou (B) a proteção atual basta? O aceite em lote "aceito todas" (22/11) marcou "especialista antes de abrir a clientes" (5·A), mas isso é **sugestão a confirmar**.
- Os textos do registro legado (`docs/produto/legado/legal/privacy-consent-risk-register.md`, 15/06/2026) são "guia de produto e arquitetura", não texto jurídico final: não copiar para a produção sem validação de profissional.

**O que o legado registrou (guardado aqui para não se perder).** Consentimento granular, uma finalidade por vez; o serviço não pode depender de consentimento sem relação com ele (cliente que recusa imagem pública ou marketing continua atendida); informação em camadas (resumo curto e texto completo) com a versão aceita guardada; dado de saúde com cuidado extra (acesso por papel, auditoria, poucos campos, retenção definida, nunca para segmentar marketing); desenho que já nasce com privacidade (minimizar, separar, ocultar, informar, controlar, demonstrar). Fontes citadas no registro: a lei espanhola de proteção de dados (LOPDGDD, BOE), o guia de privacidade desde o desenho da autoridade espanhola (AEPD, 2019) e o RGPD (UE 2016/679).

**Ordem de implementação sugerida no legado (a confirmar):** LEGAL-01 pesquisa e modelo de texto; LEGAL-02 arquitetura de consentimento; ANA-LEGAL-01 anamnese com resumo e imagem pública Sim ou Não; MSG-LEGAL-01 consentimento e opt-out das mensagens; PAY-LEGAL-01 revisão do provedor de pagamento e sinal.

**Perguntas abertas de RGPD** (as 8 do legado, ainda sem resposta nos documentos, mais as do atual):
1. Quais procedimentos exigem anamnese obrigatória?
2. Quais procedimentos exigem foto interna de evidência?
3. Qual é a jurisdição no lançamento: só Espanha, Espanha, Portugal e Brasil, ou configurável desde o primeiro dia?
4. Qual é o papel final de controlador e de operador, por estúdio e para quem opera o sistema? ("contrato com a Karenn" no ICEBOX 9 contra "contrato com o estúdio" no go-live.)
5. Quais provedores vão processar mensagens oficiais, pagamentos, armazenamento, analytics ou avaliações?
6. Qual prazo de retenção vale para anamnese, fotos e notas da profissional?
7. Como a pessoa pede acesso, correção, apagamento, restrição ou portabilidade?
8. A mensagem operacional de WhatsApp precisa de aceite explícito já na primeira versão, ou basta aviso claro como comunicação de serviço?
9. Especialista antes de abrir a clientes, ou a proteção atual basta? (ICEBOX 9)
10. As fotos do Fresha com dados reais saem do repositório e do histórico do git (reescrever o histórico)? Ou ficam, com o risco? (N2)
11. Quem vê o texto do alerta de alergia na agenda? (OWNER, pergunta 4)
12. A senha do backup fica só no gerenciador de senhas, ou também em papel? (SECURITY.md contra backup-restore.md)

## Decisões
| ID | Decisão | Situação | Origem |
|---|---|---|---|
| PLT-D01 | Manter o GitHub sem plano pago; a barreira é a trava do Claude Code | **a confirmar** (antes: vale) (frase dele: "sobre o git, como no projeto ja tem a config, vamos manter assim mesmo.", 20/11/2026) | adr/2026-11-17-dois-degraus.md:22; R2 A.1 |
| PLT-D02 | Sem merge automático em prévia ou produção sem a aprovação explícita dele (um PR por entrega validada) | **a confirmar** (antes: vale) (frase dele: "Prefiro manter a regra de 1 PR por entrega funcional validada, mas sem merge automático em prévia ou produção sem minha aprovação explícita", 20/11/2026) | adr/2026-11-20-merge-revisores-e-modelo.md:12,17 |
| PLT-D03 | A vitrine `/showcase` não entra; o que for testar, testa-se no domínio final (prévia) | **a confirmar** (antes: vale) (frase dele, 22/11/2026, 23h15; a aprovação de 18h08 foi desfeita pela de 23h15) | reg:144; R1 A.0 |
| PLT-D04 | Escolha técnica que não aparece na tela, sem custo e sem dado de cliente: a IA decide, registra e avisa | **a confirmar** (antes: vale) (frase dele: "A IA decide, registra e me avisa", 19/11/2026) | adr/2026-11-19-base-de-ia.md:22 |
| PLT-D05 | Decisão do dono só com a pergunta completa, a frase dele e a data | **a confirmar** (antes: vale) (23/11/2026, "Opção A") | adr/2026-11-23-decisao-com-prova.md |
| PLT-D06 | Manter o TanStack Start; não trocar por Vite, Router, Query e Hono | **sugestão a confirmar** (a frase "faça tudo", 15/11, respondeu a pergunta que não está anexada) | adr/2026-11-15-stack-start.md:3,7; R2 A.1 |
| PLT-D07 | Duas pistas: todo PR com base em `previas`; produção só com "pode publicar" e parada até ele aprovar a prévia | **sugestão a confirmar** (registrada pela IA em 17/11 "sem mensagem sua guardada") | adr/2026-11-17-dois-degraus.md:3-6; OWNER:39 |
| PLT-D08 | Hospedar no Cloudflare Workers com deploy pelo GitHub (Workers Builds); migrar do Vercel/Next.js | **sugestão a confirmar** (o antigo diz "o Alexandre trocou a stack", sem frase; a análise de custo de 29/10 ainda recomenda Vercel e Supabase) | R5 A PASSAGEM-2026-11-13:5; R5 F |
| PLT-D09 | Stack congelada por 60 dias (até 12/01/2027); mudança só registrada | **sugestão a confirmar** | stack.md:3; R2 C105 |
| PLT-D10 | Backup: `pg_dump` diário cifrado (senha forte AES-256) para R2 na UE e segunda cópia no Backblaze; chave age trocada por senha forte | **sugestão a confirmar** ("decisão do Alexandre" citada, sem frase) | stack.md:46-51; backup-restore.md |
| PLT-D11 | Agendamento do backup e do teste de restauração desligado até a virada | **sugestão a confirmar** (escolha técnica da IA, 15/11) | backup-restore.md:3; go-live.md:30 |
| PLT-D12 | Dependabot no lugar do Renovate; CodeQL e secret scanning fora; gitleaks na CI; Sentry e Resend sem conector | **sugestão a confirmar** (13/11, "decisão do Alexandre" sem frase) | stack.md:46-51 |
| PLT-D13 | Manter o Supabase Auth; papéis em `user_roles`; RLS obrigatória; sem Clerk, Auth0, WorkOS, Better Auth | **sugestão a confirmar** (28/10 e 31/10 no antigo, sem prova) | R4 A spec 03, 29, 47; R5 A saas-stack-decision |
| PLT-D14 | Login: e-mail e senha como principal; código por e-mail na fase 1; Google na fase 2 (Apple só com app iOS); MFA TOTP na fase 3; sem link mágico; passkeys só depois | **sugestão a confirmar** (estudo da IA em 31/10; fases 1 a 3 dependem de credenciais do dono) | R4 A spec 47 §2 |
| PLT-D15 | Sem cadastro público: acesso por convite | **sugestão a confirmar** | R4 B spec 47:13; security-baseline §6 |
| PLT-D16 | Mercado inicial Espanha e UE, moeda EUR, fuso Europe/Madrid, RGPD desde o início | **sugestão a confirmar** (confirmada do legado, sem frase) | R5 A scope-master:16-21 |
| PLT-D17 | Emissão fiscal fora do escopo ("o sistema não emite nada fiscal") | **sugestão a confirmar** ("por decisão do dono" no legado, sem frase) | R5 A revisao-30-10:6 |
| PLT-D18 | Especialista em proteção de dados antes de abrir a clientes (5·A) | **sugestão a confirmar** (aceite em lote; ICEBOX 9 ainda pergunta) | R1 A.2; R2 D.2 ICEBOX:9 |
| PLT-D19 | Fotos do Fresha com dados reais saem do repositório e do histórico, guardadas antes fora do git (N2·A) | **sugestão a confirmar** (aceite em lote) | R1 A.2 N2; R3 F-17 |
| PLT-D20 | Marketing só para quem disse SIM; recusa vale por meio | **sugestão a confirmar** (regra de 14/11 "decidida" sem frase) | R2 A regras-de-produto 3; history.md:68-70 |
| PLT-D21 | Ficha assinada corrigida sem perder o original; ficha de saúde sem camadas novas sem motivo | **sugestão a confirmar** (datas de 14/11, sem frase) | R2 A regras-de-produto 1-2 |
| PLT-D22 | Link da ficha só como hash, com validade; criar acesso exige permissão; senha provisória obriga trocar | **sugestão a confirmar** (decisão técnica registrada, sem frase) | R2 A regras-de-produto 6-7 |
| PLT-D23 | Todo módulo é portado já otimizado (orçamento de idas ao banco) | **sugestão a confirmar** ("decidido 14/11" sem frase; o limite de 3 segundos "constava sem prova") | R2 A regras-de-produto 5; ICEBOX:45 |
| PLT-D24 | Segredo nunca no código, no chat ou em log; dado pessoal nunca em log; segredos só nos painéis | **sugestão a confirmar** (regra de SECURITY.md, sem prova) | SECURITY.md:6; R2 C64 |
| PLT-D25 | Se algo vazar: avisar o dono sem colar o dado; trocar o segredo; aviso à autoridade em até 72 h | **sugestão a confirmar** | SECURITY.md:12-16; R2 C65 |
| PLT-D26 | Imagem pública separada e opcional; recusa não bloqueia o atendimento; foto interna de avaliação à parte | **sugestão a confirmar** (decisão de produto do legado, sem prova) | legado legal §7.1 |
| PLT-D27 | Menores não são atendidos | **sugestão a confirmar** (legado, sem prova) | legado legal §7.2 |
| PLT-D28 | Não usar "LGPD" como termo global; jurisdição configurável | **sugestão a confirmar** | legado legal §1; R5 A |
| PLT-D29 | O controlador dos dados é a empresa que gere o sistema (risco: em SaaS o estúdio costuma ser o controlador) | **sugestão a confirmar** ("intenção do produto", papel final a validar) | legado legal §7.3; consolidado §4-24 |
| PLT-D30 | WhatsApp: começa informal ou manual; sem motor de campanha até consentimento e opt-out claros | **sugestão a confirmar** (legado de 15/06; no atual, G4: QR só para teste e API oficial para clientes, por aceite em lote) | legado legal §7.4; reg:120 |
| PLT-D31 | Prioridade do antigo: integridade (transações, idempotência, E2E) antes de módulos secundários | **sugestão a confirmar** ("imutável" no legado, sem prova) | R5 A scope-master:215-222; roadmap:23-42 |
| PLT-D32 | Produção parada de propósito até "pode publicar"; hoje sem clientes reais | **sugestão a confirmar** (afirmado na página do dono, sem frase) | OWNER:8,38 |

Regra: só vale decisão registrada em `docs/decisoes/` (molde de pergunta). Tudo desta tabela é **a confirmar**; a situação antiga fica entre parênteses só como histórico e volta a ser perguntada quando o módulo for trabalhado (resposta 15a do dono, 24/11/2026).

## Regras de negócio
- Toda tabela do estúdio tem `org_id` e proteção por linha (RLS). Um estúdio nunca vê dado de outro.
- Segredo nunca no código, no chat ou em log. Dado pessoal nunca em log.
- A ficha de anamnese é dado de saúde: nunca em log, endereço, ferramenta de erro ou resposta a quem não deve; sem uso em marketing nem em analytics.
- Esconder botão não é segurança: toda função de servidor confere sessão, estúdio e permissão.
- Escrita em vários passos vai numa função do banco, numa transação; reenvio não duplica venda, pagamento nem pontos.
- Migration nova é arquivo novo; a que já está na branch de integração não se edita. Produção só com autorização do dono e backup do dia conferido.
- A chave `service_role` só no servidor e só onde a RLS não alcança.
- Páginas sem login levam `no-store`, `noindex` e `Referrer-Policy: same-origin`.
- O link da ficha vale por tempo limitado e é guardado só como hash; "Reenviar" invalida o anterior.
- Marketing só vai para quem disse SIM; o envio confere de novo na hora.
- Serviço não depende de consentimento sem relação com ele (imagem pública, marketing).
- Backup nunca passa por chat; senha do backup de 40 caracteres ou mais.
- Descrever só a proteção que existe (CSP completa, Turnstile e idempotência em `/pagar` ainda não existem).

## Pendências e perguntas
| Pergunta ou pendência | Origem |
|---|---|
| As 12 perguntas de RGPD da seção "Privacidade (RGPD)" acima | legado legal §8; ICEBOX:9; OWNER:59; consolidado §4-10, 11, 24, 25 |
| Qual é a regra de "virada": só com especialista, ou com a proteção atual? | ICEBOX:9; consolidado §4-10 |
| Quando religar o agendamento do backup (hoje desligado) e quem guarda a senha | backup-restore.md:3,29; go-live.md:30 |
| Retenção do backup: 7, 4 e 3 (stack.md) ou 8, 35 e 100 dias (backup-restore.md)? | R2 F-17 |
| Painel de Operação e alerta de backup: avisos prontos de cada ferramenta, ou painel próprio? | R2 D.2 ICEBOX:18 |
| Rodar uma rodada do `claude-security`? (precisa da autorização do dono) | R2 D.2 ICEBOX:20 |
| Esqueci a senha por e-mail na produção: SMTP, Redirect URL do Supabase, prazo do link | R2 D.2 ICEBOX:19; OWNER:82 |
| Troca das chaves e do banco de backup para a produção (virada) | R2 D.2 ICEBOX:17; go-live.md |
| Nome do produto; domínio próprio | OWNER; R2 D.3 history.md:72-74 |
| Plano do Supabase (proteção contra senha vazada exige Pro) e região | R4 B spec 47 §4 item 9 |
| Teste das funções de servidor: A, B ou A+B | R3 B teste-funcoes:3-23 |
| Lições de segurança de banco do antigo (políticas FOR ALL, chave composta, anônimo só em 3 funções, incidente PGRST201) precisam ser conferidas contra `database.md` | R5 F.2-3 |
| Limite de requisições em `/forms` e `/pagar`: nunca fechado no antigo ("precisa do OK do Alexandre") | R5 B revisao-30-10:16; R5 F |
| Vazamento de dado pessoal em log: conferir | R2 D.2 ICEBOX:47 |
| Trocar a senha de teste e o token da Vercel; decidir projetos Vercel a desconectar (`studio-sites`, `kabeautysys`, `v0-sgautomotive`) | OWNER:76-79 |
| Conexão de leitura ao banco de desenvolvimento no Claude Code (a única hoje aponta para a produção) | OWNER:76 |
| Congelamento das regras de IA até 04/12 e exceções | R2 F-4 |
| `docs/legal` (DPAs) não existe, mas `stack.md` manda registrá-los antes da virada | stack.md:31; R2 F-18 |
| A análise de custo e infraestrutura de 29/10 (Vercel e Supabase) contradiz o destino atual (Cloudflare); confirmar que não vale mais | R5 F; R5 B infra/2026-10-29 |
| Banco sem mudança de comportamento (nível C): medir RLS e testes de isolamento; replay do PR em transação por migration; `(select auth.uid())` nas políticas, com teste; grants das visões `internal_read`, UPDATE sem SELECT e funções `definer` | R2 D BACKLOG:37 (item 6) |
| Consolidar políticas RLS permissivas duplicadas (antigo, depois de `REL-DB-01`) | legado spec 21:81 (R4 D) |
| Números das migrations do PR #37 diferem entre o repositório e o banco de desenvolvimento | R2 D ICEBOX:40 (item 29) |
| Trocar `router.refresh()` e `revalidatePath` por `revalidateTag` (Next.js do antigo; o atual é TanStack Start: conferir se ainda se aplica) | R5 D architecture:64-82 |

## Referências
- Atual: `docs/reference/database.md`, `server.md`, `stack.md`, `db-budget.md`, `project.md`; `docs/runbooks/backup-restore.md`, `go-live.md`; `SECURITY.md`; `docs/ICEBOX.md` (itens 9 a 20, 38 a 41, 46, 54); `docs/specs/teste-funcoes-servidor.md`; `docs/adr/` (stack-start, dois-degraus, regras-de-produto, merge-revisores-e-modelo, decisao-com-prova).
- Legado: `docs/produto/legado/legal/README.md` e `privacy-consent-risk-register.md`; `docs/produto/legado/produto/security-baseline.md`, `saas-stack-decision.md`, `ecossistema.md`, `i18n-multiidioma.md`; `docs/produto/legado/specs/03-auth-multitenant-rls.md`, `19-integrations-google-meta-analytics.md`, `21-action-reliability-and-performance.md`, `22-operational-integrity-and-audit.md`, `23-agenda-integrity-and-operational-ledgers.md`, `47-login-e-autenticacao.md`.
- Levantamento: R2 A.1, A.2, B, C.3, D.2, D.3, F; R3 B (Plataforma), F-17; R4 B (Plataforma), A (specs 03, 21, 22, 23, 47); R5 A, B (Plataforma), F, F.2.
- Fotos de referência com dados reais: `docs/fresha-prints-referencia/` (ver PLT-60).
