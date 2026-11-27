# 53 — Agenda: agendamento sem cliente (walk-in)

Atualizado em: 2026-11-06 00:36 (Paris). Ajuste de nomes ao guia aprovado da spec 52 (4 passos, "Avisos" virou menu da Revisão); o conteúdo segue rascunho.

> **RASCUNHO PARA APROVAÇÃO. Nada deste documento está implementado.** É só o plano: não há código, migration
> nem mudança de tela neste commit. Nenhuma tabela foi alterada (as consultas ao banco foram somente leitura).

Origem: o dono aprovou ter o "sem cliente" de verdade, como o Fresha faz com **Walk-in**: o agendamento fica
**sem cliente identificada**. Hoje o botão "Sem cadastro" do Guia de agendamento (spec 52) cria uma *cliente
rápida* (nome + telefone), que é outra coisa: continua havendo uma cliente no cadastro. Esta spec define o que
muda para existir agendamento sem cliente.

## 1. Decisão e escopo

- O agendamento pode ser salvo **sem cliente** (walk-in): serve para quem chega sem cadastro e não quer deixar
  nome nem telefone.
- Continua possível cadastrar uma cliente rápida (nome + telefone) e escolher uma cliente existente.
- Walk-in **não** é uma cliente chamada "Walk-in" no cadastro (isso poluiria a lista, a busca e os relatórios).
  É a ausência de cliente, marcada de forma explícita no agendamento.
- Dá para **identificar a cliente depois** (editar o agendamento e escolher/cadastrar a cliente), por exemplo
  quando ela decide deixar o telefone na hora de pagar.

Fora desta spec: venda avulsa do checkout (`confirm_walkin_sale_atomic` hoje exige cliente: "Escolha a cliente da
venda"). Se o dono quiser o mesmo walk-in lá, vira uma spec seguinte; aqui só é citado onde a comanda do
agendamento é afetada.

## 2. (a) O que o banco aceita hoje

Consulta somente leitura no projeto Supabase do beauty-system (04/11/2026) e leitura das migrations:

| Fato | Evidência |
|------|-----------|
| `appointments.client_id` é **NOT NULL** no banco real | `information_schema.columns`: `is_nullable = NO` |
| Nem sempre foi assim: a migration 005 criou a coluna **nula** e a `20260614_007_enforce_appointment_client.sql` a tornou obrigatória de propósito ("Every appointment must reference a client"), depois de preencher os antigos pelo nome | `supabase/migrations/20260601000005_appointments.sql:11` e `20260614_007_enforce_appointment_client.sql:70` |
| `appointments.client_name` é `text NOT NULL` (guarda uma cópia do nome) | `information_schema.columns` |
| Chave estrangeira composta `appointments_client_same_org (org_id, client_id) → clients(org_id, id)` | `pg_constraint` |
| Unique `(org_id, client_id, id)`, usada pela FK de `client_notes (org_id, client_id, appointment_id)` | `pg_constraint`; `20260619225200_agenda_status_notes_core_02.sql:40` |
| Outras tabelas com `client_id NOT NULL` ligadas ao agendamento: `appointment_deposits`, `payment_requests`, `agenda_waitlist`, `client_balance_entries`, `client_entitlements`, `client_entitlement_entries`, `loyalty_point_entries`, `marketing_message_queue`, `client_notes` | `information_schema.columns` |
| Já aceitam cliente nula: `sales.client_id`, `transactions.client_id`, `anamneses.client_id`, `gift_card_redemptions.client_id`, `messaging_provider_log.client_id`, `marketing_message_events.client_id` (mas `sales.client_name` e `anamneses.client_name` são NOT NULL) | `information_schema.columns` |
| RLS ligado em `appointments`, com `org_id` em todas as políticas (`has_permission(org_id, 'agenda.manage')` para criar/editar; ver por `agenda_full_view_orgs()` / `agenda_own_view_orgs()` + equipe; apagar para owner/admin/manager) | `pg_policies`, `pg_class.relrowsecurity` |
| `create_appointment_atomic` e `update_appointment_atomic` **exigem** cliente (`Cliente nao encontrado nesta organizacao`), checam bloqueio da cliente e copiam `full_name` para `client_name` | corpo das funções (`pg_get_functiondef`) |
| `create_recurring_appointments_atomic` também recebe `p_client_id` | `pg_proc` |
| Trigger `enforce_appointment_insert_integrity` confere que a cliente pertence à organização | `pg_trigger`, `pg_get_functiondef` |
| `register_appointment_deposit_atomic` **já recusa** agendamento sem cliente: `Agendamento sem cliente cadastrado` (errcode 23502) | `pg_get_functiondef` |
| `confirm_checkout_atomic` / `confirm_checkout_partial` **já tratam** `appointments.client_id is null` (pulam saldo e fidelidade) | `20260613_010_confirm_checkout_atomic.sql:111, 299, 329, 409` |
| `ensure_appointment_anamnese_for_item` cria a ficha com `v_appointment.client_id` e `client_name` | `pg_get_functiondef` |

**Resposta:** a tabela de agendamentos **não aceita cliente nula hoje**. A coluna já foi nula no começo e foi
fechada por decisão (migration 007), então esta spec **reverte uma decisão anterior** e precisa de aprovação
consciente do dono. O restante do banco já está meio preparado: checkout e sinal tratam "sem cliente".

## 3. (b) O que muda quando não há cliente

| Área | Hoje | Com walk-in |
|------|------|-------------|
| **Agenda (quadro e cartões)** | Mostra `client_name` | Mostra o rótulo de walk-in (§4). O cartão não tem etiquetas de cliente (VIP, alergia, crédito). |
| **Painel do agendamento** (`ClientCard.tsx`, `AboutClient.tsx`) | Cartão da cliente com Ações, Ligar, WhatsApp, Reenviar lembrete, Ver perfil, Anamnese | Sem cartão da cliente: no lugar, um aviso "Sem cliente identificada" com o botão **Identificar cliente** (escolher ou cadastrar). Somem Ligar, WhatsApp, Reenviar lembrete, Ver perfil e Anamnese. |
| **Guia de agendamento** (spec 52) | Passo 1 exige cliente; ~~passos 2 a 5~~ (hoje 2 a 4) mostram o painel da cliente | Passo 1 ganha a opção **Walk-in** (válido sem cliente). Painel/cartão da cliente nos passos 2 a 4 viram "Walk-in" com "Trocar cliente" (para identificar; ~~passos 2 a 5~~, substituído em 06/11). No menu "Avisos e sinal" da Revisão (~~passo Avisos~~): confirmação pelo WhatsApp e sinal ficam desabilitados com o motivo ("Sem telefone"). |
| **Comanda / checkout** | `confirm_checkout_atomic` já pula saldo e fidelidade se `client_id` é nulo | Funciona; sem saldo, crédito, fidelidade nem pacote da cliente. `sales.client_name` é NOT NULL: usar o rótulo de walk-in. Pagamento por crédito/saldo e vale ficam indisponíveis (exigem cliente). |
| **Pacotes e cobertura** (`package-coverage.ts`, `draftPackageMarks`) | Marca serviço coberto pelo pacote da cliente | Sem cliente não há pacote: nenhuma marca. |
| **Sinal e cobranças** | `register_appointment_deposit_atomic` recusa sem cliente; `payment_requests.client_id` NOT NULL | "Pedir sinal" desabilitado no guia; ação do painel some. Mantém a recusa do banco como segunda barreira. |
| **Anamnese / ficha** | Serviço que exige ficha cria `anamneses` com a cliente | Serviço que exige ficha **exige cliente**: o guia avisa "Este serviço pede ficha: identifique a cliente" e o passo Serviços/Revisão não deixa salvar sem ela (ou o sistema trava a mudança de status, como no `enforce_appointment_anamnese_status_gate`). Decisão a confirmar (§7). |
| **Lembretes e WhatsApp** | Lembrete 24 h e confirmação usam o telefone da cliente | Sem telefone, **não há lembrete nem confirmação**. A automação de lembretes ignora agendamento sem cliente; nenhum envio, nenhum registro de envio com `client_id` nulo (a tabela `messaging_provider_log` aceita nulo, mas não deve haver envio). "Reenviar lembrete" some. |
| **Relatórios** | Agrupam por cliente, contam clientes novas, retorno, ticket por cliente | O faturamento e a contagem de atendimentos incluem o walk-in. Rankings e métricas **por cliente** (clientes novas, retorno, recorrência, aniversários, saldo) **excluem** walk-in, com uma linha "Walk-in" separada onde a soma precisar bater. Precisa de revisão relatório a relatório (§7). |
| **Histórico da cliente** | Lista agendamentos por `client_id` | Walk-in não aparece em nenhuma ficha. Ao identificar a cliente depois, o agendamento entra no histórico dela. |
| **Lista de espera** | `agenda_waitlist.client_id` NOT NULL | Sem mudança: lista de espera continua exigindo cliente (walk-in não espera). |
| **Recorrência ("Repetir")** | `create_recurring_appointments_atomic` recebe a cliente | Walk-in **não repete** (a opção fica desabilitada): repetir exige saber quem é. |
| **Mesclagem de clientes** (`merge_clients_atomic`) | Move agendamentos entre clientes | Sem mudança; agendamento sem cliente não entra. |
| **Busca global** | Acha agendamento pelo nome da cliente | Acha pelo rótulo de walk-in e pelo número do agendamento. |
| **Auditoria / histórico de status** | `appointment_status_history` por agendamento | Sem mudança. Identificar a cliente depois deve registrar o fato (quem, quando) no histórico do agendamento. |

## 4. (c) O que a tela mostra

O Fresha usa **"Walk-in"** no lugar da cliente. Proposta, pendente de aprovação do texto:

| Onde | Texto |
|------|-------|
| Rótulo no quadro, cartões, listas e busca | **Walk-in** |
| Passo 1 do guia (botão) | **Walk-in (sem cliente)** com a ajuda "Sem nome e sem telefone. Dá para identificar a cliente depois." |
| Passo 1, depois de escolher | Cartão "Walk-in" com os botões **Identificar cliente** e **Trocar cliente** (sem Ligar nem WhatsApp) |
| Resumo da revisão (linha Cliente) | `Walk-in` |
| ~~Avisos (passo 4)~~ menu "Avisos e sinal" da Revisão (substituído em 06/11) | Confirmação pelo WhatsApp: "Walk-in não tem telefone." Sinal: "Precisa de cliente identificada." |
| Painel do agendamento | "Sem cliente identificada" + **Identificar cliente** |
| Rotina de relatório (linha própria) | "Walk-in (sem cliente)" |

O botão atual **Sem cadastro** (que cria cliente rápida) muda de nome para não confundir com walk-in: fica
**Nova cliente** (cadastro rápido, sem outro botão para a mesma coisa) e **Walk-in** é a opção sem cliente.
**Decisão do dono:** manter "Walk-in" em inglês (como o Fresha) ou usar "Sem cliente" em português na interface.

## 5. (d) Migração

Uma migration nova, com timestamp, UTF-8 explícito, **sem alterar nenhuma migration existente** (regra do
repositório). Nome proposto: `supabase/migrations/20261105090000_appointments_walkin.sql` (ajustar para o
primeiro timestamp livre, posterior ao último existente, hoje `20261101110000`).

1. `alter table public.appointments alter column client_id drop not null;`
2. `alter table public.appointments add column is_walkin boolean not null default false;` e uma constraint
   `appointments_client_or_walkin check (client_id is not null or is_walkin)`: a ausência de cliente só vale
   quando o agendamento foi **marcado** como walk-in. Isso evita que um erro de código grave agendamento sem
   cliente por acidente. Com cliente, `is_walkin` fica `false` (e uma constraint contrária impede os dois:
   `check (not (client_id is not null and is_walkin))`).
3. A FK composta `appointments_client_same_org` e o unique `(org_id, client_id, id)` **continuam** (FK composta com
   coluna nula não é checada; `client_notes` continua exigindo cliente e não é afetada).
4. Funções:
   - `create_appointment_atomic`: `p_client_id` pode ser nulo se `p_walkin = true`; `client_name` recebe o rótulo
     (parâmetro `p_walkin_label`, padrão "Walk-in"); pula bloqueio de cliente; nunca aceita `p_client_id` nulo com
     `p_walkin = false`.
   - `update_appointment_atomic`: permite **identificar** (walk-in → cliente: define `client_id`, copia o nome,
     `is_walkin = false`, regista no histórico) e impede o caminho contrário se já houver sinal, ficha, pacote ou
     comanda ligados à cliente.
   - `enforce_appointment_insert_integrity`: só confere a organização da cliente quando `client_id` não é nulo.
   - `create_recurring_appointments_atomic`: continua exigindo cliente (walk-in não repete).
   - `ensure_appointment_anamnese_for_item` / gate de status: tratar cliente nula (recusar com mensagem clara ou
     pular, conforme a decisão do §7).
   - `register_appointment_deposit_atomic`: já recusa; manter.
5. **RLS preservado**: nenhuma tabela nova e nenhuma política muda; `org_id` segue em todas as políticas de
   `appointments` e o walk-in herda a mesma proteção. Não se concede nada novo a `anon`.
6. `src/data/database.types.ts` regenerado; tipos de `AppointmentRow` (`client_id: string | null`).
7. Reversão: não dá para voltar `client_id` a NOT NULL enquanto existirem walk-ins. O plano de volta é
   identificar (ou cadastrar uma cliente genérica por organização) antes; documentar na própria migration.
8. Antes de aplicar em produção: consulta de contagem (sem walk-ins hoje, então a migration não toca em linhas
   existentes) e teste em ambiente local (`supabase db reset`) com os E2E de agenda.

## 6. Mudanças de código (resumo, para estimar)

- Domínio puro `src/domain/agenda-guide.ts`: `hasClient: boolean` vira a escolha do passo 1
  (`client | walkin | none`); o passo 1 é válido com cliente **ou** walk-in; `reviewMissing` e o texto
  "Escolha uma cliente para continuar" passam a dizer "Escolha uma cliente ou Walk-in". Vitest novo.
- Guia (`_new/`): `ClientChooser` ganha Walk-in e troca "Sem cadastro"; passos 2 a 4 mostram o cartão "Walk-in" (~~2 a 5~~);
  `NoticesPanel` (~~`StepNotices`~~, apagado em 06/11) desabilita confirmação e sinal; `StepReview` mostra o rótulo; repetir desabilitado.
- Agenda e painel (`ClientCard`, `AboutClient`, `AppointmentScreen`, `board.ts`, `detail.ts`): lidar com
  `client_id` nulo (os tipos `clients: ... | null` já existem nas leituras), "Identificar cliente" no painel.
- Server actions (`agenda/actions.ts`, `appointment-query-actions.ts`): aceitar walk-in, validar permissões como hoje.
- Lembretes: a automação ignora agendamento sem cliente.
- Relatórios: revisão um a um (tarefa própria, §7).

## 7. Perguntas ao dono e riscos

1. **Texto**: "Walk-in" ou "Sem cliente"? (§4)
2. **Serviço que exige ficha de anamnese** com walk-in: bloquear o salvar (exigir cliente) ou permitir e exigir a
   cliente só na hora de iniciar o atendimento? Recomendação: exigir cliente na hora de **iniciar**, pois
   o walk-in muitas vezes só se identifica ao chegar.
3. **Venda avulsa** do checkout também deve aceitar walk-in? (hoje exige cliente)
4. **Relatórios**: rankings por cliente excluem walk-in e há uma linha própria? Falta revisar cada relatório
   (financeiro, marketing, clientes) para ver o impacto exato; esta spec não os auditou um a um.
5. **Reverte uma decisão anterior** (migration 007, "todo agendamento tem cliente"): confirmar.
6. **LGPD**: walk-in reduz dado pessoal guardado; identificar depois exige o mesmo consentimento de hoje.

## 8. Ordem sugerida de entrega (depois da aprovação)

1. Migration + funções + tipos (banco), com testes de banco.
2. Domínio do guia + Vitest.
3. Guia (passo 1, avisos, revisão) + E2E nos dois tamanhos.
4. Agenda e painel do agendamento (rótulo, "Identificar cliente").
5. Lembretes (ignorar walk-in) e comanda (rótulo em `sales.client_name`).
6. Relatórios, um a um.

## 9. Critérios de aceite (quando for implementado)

1. É possível salvar um agendamento Walk-in sem nome nem telefone, nos dois tamanhos.
2. O agendamento aparece no quadro e na busca com o rótulo definido, sem etiquetas de cliente.
3. Nenhum lembrete nem confirmação sai para um walk-in; "Pedir sinal" fica indisponível.
4. A comanda do walk-in fecha (pagamento sem saldo nem crédito) e entra no faturamento.
5. Identificar a cliente depois liga o agendamento ao histórico dela e fica registrado.
6. `appointments` mantém RLS por `org_id`; `anon` não ganha acesso; migration com timestamp e UTF-8.
7. Vitest do domínio, testes de banco das funções e E2E desktop e mobile.
