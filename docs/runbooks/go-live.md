# Virada: lista única

Tudo o que precisa acontecer antes de abrir a produção a clientes reais. Lista para **executar na
virada**, com a ordem do dono do projeto; antes disso, serve para nada ficar esquecido. Cada linha
aponta o item da fila (`docs/ICEBOX.md`) quando houver.

## Antes de ligar
| # | O quê | Item da fila |
|---|---|---|
| 1 | **Proteção de dados (RGPD):** direitos da pessoa, retenção, base legal do consentimento, registro de tratamento, cifra da anamnese, contrato com o estúdio, política de privacidade | 9 |
| 2 | **Auditoria completa**, feita depois do layout: cada perfil só vê o que deve; quem lê e altera a ficha de saúde e se fica registrado; proteção ativa em todas as tabelas, sem brecha entre estúdios; links públicos com limite de tentativas. Inclui conferir o registro de decisões contra o app | 10 |
| 3 | Roteiro de vazamento de dados (uma página; aviso à autoridade em até 72 horas) | 16 |
| 4 | Roteiro de rotação de segredo | 15 |
| 5 | Idempotência em pagamento e webhooks | 12 |
| 6 | Testes de isolamento que faltam e testes de apagar estúdio inteiro | 13, 14 |
| 7 | Cópia das fotos da anamnese no backup; usuário só de leitura para o backup | 38, 39 |
| 8 | Política de conteúdo (CSP) completa | 40 |
| 9 | Esqueci a senha por e-mail: SMTP próprio, endereço em Redirect URLs, prazo do link em 3600 s | 19 |
| 10 | Varredura de segurança escopada, uma vez, com autorização | 20 |
| 11 | Turnstile e limite de tentativas no login e no PIN (previstos na stack, ainda não instalados) | 40 |
| 12 | **Idiomas:** o sistema entra em produção em português, espanhol e inglês (decisão de 20/11, `docs/adr/2026-11-20-idiomas.md`) | a criar |

## No dia
| # | O quê |
|---|---|
| 1 | Aplicar as migrations no banco de produção, com autorização e backup conferido |
| 2 | Trocar para o projeto de produção: `SUPABASE_SERVICE_ROLE_KEY`, endereço do banco do backup e as variáveis do Worker |
| 3 | Planos pagos: Workers (o uso de CPU medido passa do plano gratuito) e Supabase |
| 4 | Domínio próprio; variável `APP_ORIGIN` com o endereço novo |
| 5 | **Religar o backup:** restaurar os dois agendamentos (`backup-diario.yml`: `17 3 * * *`; `teste-restauracao.yml`: `41 5 2 * *`), com os segredos da produção; rodar uma vez à mão e conferir a restauração. Segunda cópia no Backblaze |
| 6 | Faxina diária das fotos órfãs da anamnese (precisa de uma chave de serviço guardada no GitHub) |
| 7 | Fresha em paralelo por 2 semanas depois de ligar, como o plano previa |

## Operação, depois de ligar
- Sentry (plano gratuito, a confirmar) com estes cuidados de RGPD: organização na região UE (não se troca depois); DPA assinado e Sentry listado como subprocessador; endereços com token (`/forms`, `/pagar`, links de senha) limpos dos erros e dos nomes de transação; `sendDefaultPii` desligado e limpeza no servidor do Sentry ligada, sem guardar IP; sem gravação de sessão; rastreamento de desempenho desligado no começo; nunca dado de anamnese.
- Avisos de disponibilidade e de erro (as contas do UptimeRobot, do Sentry e do Resend já existem) e alerta se o último backup tiver mais de 26 horas. Se será só o aviso pronto de cada ferramenta ou um painel próprio é pergunta ao dono (`docs/OWNER.md`).
- Alerta de custo em dois níveis: 70% do limite, informativo; 90% e com projeção de estourar antes da renovação, urgente.
- Medição de CPU e de tempo por tela como rotina mensal, sem IA.
- Rodada agrupada de testes na branch de produção, sem IA, só quando ela mudou desde a última rodada: duas vezes por semana no começo, depois semanal, depois quinzenal se não achar nada.
- Primeira revisão trimestral de automações e conexões (`docs/reference/project.md`, "Fatos do GitHub").
- Publicação em conjunto, uma ou duas vezes por semana, em horário de pouco movimento.

Como o backup funciona e como restaurar: `docs/runbooks/backup-restore.md`.
