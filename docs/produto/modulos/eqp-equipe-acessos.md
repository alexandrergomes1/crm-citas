# Módulo: Equipe e Acessos (EQP)

> Quem trabalha no estúdio, o que cada pessoa pode fazer e quanto cada profissional ganha de comissão.
> Cada estúdio liga e desliga as liberações de cada perfil, sem mudar código.

**Telas e rotas:** `/{org}/configuracoes/equipe` (profissionais e turnos) · `/configuracoes/acessos` (pessoas com login) · `/configuracoes/perfis` (perfis e liberações). Os endereços antigos `/{org}/equipe`, `/equipe/acessos` e `/equipe/perfis` existem em `src/routes` e só redirecionam · **Código:** `src/workspace/ajustes/equipe/`, `ajustes/acessos/`, `ajustes/perfis/`; regras em `src/domain/access.ts`, `access-catalog.ts`, `access-profiles.ts`, `access-draft.ts`, `commissions.ts` · **Spec(s):** sem spec no crm-agenda. Antigo: `docs/produto/legado/specs/17-team-management-commissions.md`, `29-access-roles-modules.md`, `37-perfis-liberacoes-configuraveis.md`, `28-navegacao-marketing-ajustes.md` (regras 2 e 6).

## Recursos
| ID | Recurso | Estado | Onde | Origem |
|---|---|---|---|---|
| EQP-01 | Cadastro de profissional: nome, nome público, função, e-mail, telefone, cor (16 opções, usada como coluna da Agenda), comissão % padrão, aparece na reserva online, visível, ativo | planejado (antigo, spec 17 com critérios `[ ]`; a spec 05 já trata como existente) · pronto (atual) | `/configuracoes/equipe` | legado spec 17:8-45,54-59; R4 B 17; R2 B STATUS:34; R3 B audit:30 |
| EQP-02 | Turnos por dia da semana (padrão Seg a Sex, 09:00 a 18:00); definem a disponibilidade e os conflitos da Agenda | planejado (antigo) · pronto (atual, dentro de Equipe) | `/configuracoes/equipe` (aba Horários) | legado spec 17:36,43-44; R4 B 17 |
| EQP-03 | Profissional sem login é "externa": existe na agenda, não entra no sistema; profissional inativa não aparece na Agenda nem no agendamento | planejado (antigo) · não declarado (atual) | `/configuracoes/equipe` | legado spec 17 (Regras); R4 A 17 |
| EQP-04 | Comissão % padrão herdada pelos itens do agendamento; pode ser trocada por serviço | planejado (antigo) · não declarado (atual) | Equipe e Catálogo | legado spec 17:43-44; ver `fin-financeiro.md` FIN-09 |
| EQP-05 | Criar acesso (login) para uma pessoa, por senha ou por link; trocar perfil | pronto (atual; "senha no novo acesso" em andamento no antigo) | `/configuracoes/acessos` | R2 B STATUS:34; R2 A regras-de-produto #6; R5 B painel-da-jornada.html:89 |
| EQP-06 | Papéis: proprietária, administração, recepção e profissional (inclusive terceira) na interface; gestão, financeiro e somente leitura continuam no banco | pronto (antigo, base de banco e domínio) · não declarado (atual) | banco + `src/domain/access.ts` | legado spec 29:21-23,146-152; R4 B 29 |
| EQP-07 | Matriz de permissões por papel (agenda, clientes, dados clínicos, comanda, estorno, financeiro, catálogo, equipe, ajustes) | pronto (antigo) · não declarado (atual) | `src/domain/access.ts` | legado spec 29:28-39,71-88 |
| EQP-08 | Proteções: ninguém concede, muda ou remove o próprio papel; o estúdio sempre tem ao menos uma proprietária; administração não concede proprietária nem administração; tudo vai para a auditoria | pronto (antigo) · não declarado (atual) | banco (gatilhos) | legado spec 29:71-88; R4 B 29 |
| EQP-09 | Perfis e liberações configuráveis por estúdio: interruptor por permissão, marca "diferente do padrão", botão "Voltar ao padrão"; proprietária não editável | pronto (antigo, fases 1, 2a e 2b) · pronto (atual) | `/configuracoes/perfis` | legado spec 37:3-5,20-35,117-123; R2 B STATUS:34; R3 B audit:30 |
| EQP-10 | Perfis personalizados com nome do estúdio ("Recepção sênior"): criar a partir de um perfil-base, ligar e desligar liberações, apagar, trocar o perfil de cada pessoa | pronto (antigo) · pronto (atual, dentro de Perfis e Acessos) | `/configuracoes/perfis` e `/acessos` | legado spec 28-nav:13,23; R4 B 28-nav |
| EQP-11 | Liberações novas: ver status da ficha sem ler o conteúdo, preencher ficha como profissional, ler conteúdo clínico, bloquear horário, estornar para gestão | pronto (antigo) · não declarado (atual) | `/configuracoes/perfis` | legado spec 37:39-47,89-91 |
| EQP-12 | Agenda configurável por perfil: criar e alterar agendamentos (`agenda.manage`) e bloquear horário (`agenda.block_time`) | pronto (antigo) · não declarado (atual) | `/configuracoes/perfis` | legado spec 37:79-105 |
| EQP-13 | Agenda "ver tudo" × "só a minha"; ligar cada profissional à conta de acesso antes de dar "só a minha" | pronto, com pendência de dado (antigo) · não declarado (atual) | Agenda | R5 B core-delivery-control:51 |
| EQP-14 | Menu mostra só o que o plano e o papel permitem; módulo desligado vence a liberação | pronto (antigo) · pronto (atual, "menu, permissões") | menu | legado spec 29:98,104-109,151; R3 B audit:32 |
| EQP-15 | Equipe dentro de Ajustes (Profissionais, Acessos, Perfis); "Equipe" sai do menu principal | pronto (antigo) · pronto (atual) | `/configuracoes/*` | legado spec 28-nav regra 2; R4 B 28-nav |
| EQP-16 | Convite por e-mail com aceite; remover pessoa da equipe; criar estúdio novo sem a chave de serviço; trocar de estúdio | planejado (antigo, fase comercial) · planejado, precisa de spec (atual) | a definir | legado spec 29:90-100,153; R2 B ICEBOX:33; R1 B v26-auditoria:46 |
| EQP-17 | Segurança por papel no banco para o resto: profissional terceira vê só a própria agenda e os clientes que atende; recepção sem financeiro | planejado (antigo, fase multiusuário) · "permissões pela API" no dev, não na produção (atual) | banco | legado spec 29:92-95,155; R2 B STATUS:54 (PR #37) |
| EQP-18 | Fase 2 de perfis: estoque, cobranças, demais tabelas financeiras e outras ainda em lista fixa de papéis | planejado (antigo) · não declarado (atual) | banco | legado spec 37:75-77; R5 B revisao-codigo-e-banco:129-135 |
| EQP-19 | Tela da pessoa (perfil, trocar senha, sair, dados da conta), gestão de colaboradores e auditoria de ações sensíveis (CORE-ACCESS-01) | planejado (antigo) · parte pronta em Ajustes › Minha conta (atual) | Ajustes | R5 B future-modules-map:91-104; implementation-gap-map:50 |
| EQP-20 | Verificação em duas etapas (MFA) para proprietária, administração, financeiro e gestão com acesso financeiro | planejado (antigo, "não" aplicado) · não declarado (atual) | login | R5 A security-baseline:21-41 |
| EQP-21 | Tela da área master (planos, estúdios, "Entrar como o estúdio" com motivo, prazo de 1 h e auditoria) e fila de pedidos de ativação | planejado (antigo) · só mockup V25 (atual); dono do assunto é `saas-planos` | a definir | legado spec 29:96-100; R1 B (Main.dc.html) |
| EQP-22 | A nota da cliente ainda usa lista fixa de funções, não as permissões | parcial (atual) | Clientes | R3 B audit:23; plano de recuperação 22/11 §2 |
| EQP-23 | O menu mostra Anamnese a quem não tem permissão (e a pessoa é jogada na Agenda) | parcial (atual) | menu | R3 B audit:27 |

## Decisões
| ID | Decisão | Situação | Origem |
|---|---|---|---|
| EQP-D01 | Piloto solo: hoje só a Karenn (proprietária) usa; perfis de acesso entram na versão comercial, mas a segurança já nasce pronta (spec 29, 28/10/2026) | **sugestão a confirmar** (sem prova) | legado spec 29:11-14 |
| EQP-D02 | Login continua no Supabase Auth; não migrar para Clerk, Auth0, WorkOS ou Auth.js agora; convite formal depois, nunca criar usuário por SQL | **sugestão a confirmar** (sem prova) | legado spec 29:15-20; R5 A security-baseline:21-41 |
| EQP-D03 | Papéis na interface: proprietária, administração, recepção e profissional (inclusive terceira); gestão, financeiro e somente leitura ficam no banco | **sugestão a confirmar** (sem prova) | legado spec 29:21-23 |
| EQP-D04 | "Equipe" não depende do módulo "Equipe e comissões": o módulo libera várias profissionais e comissões, não a tela (o estúdio solo também edita o próprio cadastro) | **sugestão a confirmar** (sem prova) | legado spec 29:110-112 |
| EQP-D05 | Ninguém concede, altera ou remove o próprio papel; sempre há uma proprietária ativa; só a proprietária concede owner e admin; administração concede papéis operacionais | **sugestão a confirmar** (sem prova) | legado spec 29:71-88 |
| EQP-D06 | Criar acesso e trocar perfil exigem `acesso.manage`; Administração só com `acesso.grant_admin`; senha provisória obriga a trocar ao entrar (senha criada pelo link da pessoa, não) (14/11/2026) | **sugestão a confirmar** ("decididas na revisão de 14/11", sem frase) | R2 A regras-de-produto #6 (adr/2026-11-19-regras-de-produto.md:11) |
| EQP-D07 | O banco é a autoridade; a interface só esconde cedo. A tela nunca promete o que o banco não cumpre: só aparecem como interruptor as permissões respeitadas de ponta a ponta | **sugestão a confirmar** (sem prova) | legado spec 37:107-115; legado spec 29 §3 (frase antes da matriz) |
| EQP-D08 | `comanda.refund` passa a ser padrão também da gestão ("manter o comportamento em uso"); `financeiro.manage` governa o ajuste manual de saldo da cliente | **sugestão a confirmar** (sem prova) | legado spec 37:44-47 |
| EQP-D09 | A agenda é configurável por perfil. "Decisão do Alexandre (29 out)", sem frase dele; profissional só consulta por padrão e a dona pode ligar "Criar e alterar agendamentos" | **sugestão a confirmar** (a fonte cita o dono sem aspas) | legado spec 37:79-105 |
| EQP-D10 | Perfis personalizados do estúdio com papel-base gravado em `user_roles.role`; administração só concedida por proprietária ou administração; ninguém troca o próprio perfil (Lote 3) | **sugestão a confirmar** (sem prova) | legado spec 28-nav:13 |
| EQP-D11 | Marketing, Fidelidade, Acesso, Tenant e Administração do SaaS ficam pausados até novo aceite explícito do responsável | **sugestão a confirmar** (sem prova) | R5 A core-delivery-control:205 |
| EQP-D12 | Não criar menus por papel antes de definir a imposição no backend | **sugestão a confirmar** (sem prova) | R5 A security-baseline:88 |
| EQP-D13 | Perfis ficam para a "fase 2" (spec 37) e foram entregues pela regra 6 da spec 28-nav: vale o mais recente | **sugestão a confirmar** (sem prova) | legado spec 37:16-17; legado spec 28-nav:13,23; R4 F |
| EQP-D14 | Comissão padrão é herdada pelos itens do agendamento e pode ser trocada por serviço | **sugestão a confirmar** (sem prova) | legado spec 17:43-44 |
| EQP-D15 | Ação sem permissão: some (AGS5, decidido para a Agenda) × aparece desativada (camada 7 "não esconder"); o mesmo caso ainda é pergunta aberta (M9) | **sugestão a confirmar** (aberta) | R3 A agd:79; R3 D fechar:209-215; R3 F-5 |

## Regras de negócio
- O banco decide quem pode o quê; a tela só esconde o que a pessoa não pode usar.
- Ninguém muda o próprio papel; o estúdio nunca fica sem proprietária.
- Só a proprietária concede proprietária ou administração; as liberações da administração e as permissões de acesso só ela altera.
- Voltar ao padrão apaga as exceções daquele papel; toda mudança de liberação, papel, plano ou módulo vai para a auditoria.
- Módulo desligado no plano vence qualquer liberação, até para a proprietária.
- Profissional inativa não aparece na Agenda; só quem tem `online_booking` aparece na reserva online.
- Recepção vê o andamento da ficha de saúde, nunca o conteúdo clínico, a não ser que a dona ligue `clientes.view_clinical`.
- Outro estúdio nunca vê nem altera as exceções deste.

## Pendências e perguntas
| Pergunta ou pendência | Origem |
|---|---|
| Spec 17 está sem status e com critérios `[ ]`, mas as specs 05, 29 e 37 tratam a Equipe como existente | R4 F |
| A comissão por serviço, por profissional e o fechamento por período não têm spec; a spec 41 só cita a seção | R4 F; R5 B revisao-30-10:30 |
| Convite com aceite, remover pessoa e criar estúdio sem chave de serviço precisam de spec (nível C) | R2 B ICEBOX:33 |
| Telas faltantes do lançamento: "Equipe básica" e "Entrar e acesso" ainda sem desenho | R1 D (reg:176); R2 B ICEBOX:24 |
| Alerta da cliente (alergia) aparece para quem não tem permissão de ver clientes: (A) fica ou (B) só ícone? | docs/OWNER.md (pergunta 4); R3 D agd:160 |
| Divergências de perfis 1 (profissional na agenda) e 3 (rotina sem usuário no gate clínico) | R5 D revisao-codigo-e-banco:126-127 |
| Limite conhecido: o banco não restringe a edição da agenda à própria profissional | legado spec 37:100-103 |
| Permissões pela API (PR #37) já no banco de desenvolvimento, ainda não na produção | R2 B STATUS:54 |
| Spec 29 diz "Piloto solo, Karenn"; o CLAUDE.md diz dono Alexandre. Quem é "o responsável" em cada decisão? | R4 F |
| Guia de testes do painel antigo: criar acesso com senha, perfis personalizados | R5 D painel-da-jornada.html:139-145 |
| Notas da cliente e "reabrir ficha" como liberações configuráveis (pendente na revisão profunda) | R5 D revisao-profunda:149-152 |

## Referências
- Legado: `docs/produto/legado/specs/17-team-management-commissions.md`, `29-access-roles-modules.md`, `37-perfis-liberacoes-configuraveis.md`, `28-navegacao-marketing-ajustes.md`, `31-user-preferences.md` (preferências da pessoa, em `aju-ajustes.md`).
- Legado de produto: `docs/produto/legado/produto/security-baseline.md:21-41,63-88`, `future-modules-map.md:91-104`, `implementation-gap-map.md:50`.
- Atual: `docs/adr/2026-11-19-regras-de-produto.md` (item 6); `docs/STATUS.md:34,54`; `docs/ICEBOX.md:33`.
- Banco (antigo): migrations `20261028210000_access_modules_platform.sql`, `20261029130000_configurable_role_permissions.sql`; testes `102`, `113`, `115`, `142`.

Regra: só vale decisão registrada em `docs/decisoes/` (molde de pergunta). Tudo desta tabela é **a confirmar**; a situação antiga fica entre parênteses só como histórico e volta a ser perguntada quando o módulo for trabalhado (resposta 15a do dono, 24/11/2026).
