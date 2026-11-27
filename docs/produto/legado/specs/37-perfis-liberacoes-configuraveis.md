# Spec 37 - Perfis e liberações configuráveis por estúdio

## Status

Fase 1 implementada (29 out 2026): banco, `can()` efetivo e tela em Configurações > Perfis. Fase 2a implementada (29 out 2026): catálogo, equipe e marketing. Fase 2b implementada (29 out 2026): agenda. Complementa a spec 29 (papéis, módulos, administração).

## Objetivo

Cada estúdio decide, por perfil, o que cada pessoa pode fazer. Exemplo do produto:
"A recepção edita anamnese? E mexe no caixa?" vira um interruptor ligado ou desligado,
sem mudar código. Tudo modular: o banco guarda só as exceções ao padrão.

## Modelo

- **Papéis do sistema** continuam os de `user_roles.role` (owner, admin, manager,
  receptionist, professional, finance, viewer). Perfis personalizados (nomes próprios)
  ficam para a fase 2.
- **Padrão** de cada papel: a matriz `ROLE_PERMISSIONS` (`src/domain/access.ts`) espelhada
  na função SQL `public.role_default_permissions()`. Um teste Vitest compara as duas.
- **Exceção do estúdio**: tabela `org_role_permissions (org_id, role, permission, allowed)`.
  Linha presente vale mais que o padrão; sem linha, vale o padrão.
- **Efetivo**: `public.has_permission(org_id, permission)` (banco) e
  `my_permissions(org_id)` (lista da pessoa logada, usada pela interface).

## Regras

| Regra | Onde |
|---|---|
| Proprietária (owner) tem tudo e não é editável | `has_permission`, `set_role_permission` |
| Só quem tem `acesso.manage` altera liberações | `set_role_permission` |
| Liberações do papel `admin` e as permissões `acesso.*` só a proprietária altera | `set_role_permission` |
| Mudança vira linha em `audit_logs` (`ROLE_PERMISSION_SET` / `ROLE_PERMISSIONS_RESET`) | `set_role_permission`, `reset_role_permissions` |
| Voltar ao padrão apaga as exceções do papel | `reset_role_permissions` |
| Módulo desligado no plano continua vencendo a liberação | `can()` no app (`org_enabled_modules`) |
| O banco é a autoridade: RLS e RPCs usam `has_permission`, a interface só esconde cedo | migrations |

## Permissões novas e ajustes na matriz

- Nova: `anamnese.view_status` - ver o andamento das fichas e criar ficha para um
  atendimento, sem ler conteúdo clínico. Padrão: owner, admin, manager, recepção, profissional.
- `clientes.view_clinical` - ler o conteúdo clínico das fichas e fotos. Padrão: owner,
  admin, manager, profissional.
- `anamnese.fill_professional` - preencher, editar e apagar ficha pendente.
- `comanda.refund` passa a ser padrão também do papel `manager` (o banco já permitia
  estornar saldo; a matriz antiga divergia). Decisão: manter o comportamento em uso.
- `financeiro.manage` (padrão inclui `finance`) passa a governar o ajuste manual de saldo
  do cliente (antes fixo em owner, admin, manager).

## Fase 1: o que o banco já respeita

| Objeto | Permissão |
|---|---|
| Política `anamneses_select` e fotos no storage | `clientes.view_clinical` |
| Políticas `anamneses_update` e `anamneses_delete_pending`, `save_anamnese_professional_*` | `anamnese.fill_professional` |
| Política `anamneses_insert`, `create_anamnese_atomic`, `list_anamnese_status` | `anamnese.view_status` |
| `get_appointment_anamnese_gate` | `anamnese.view_status` ou `comanda.operate` |
| `confirm_checkout_atomic`, `register_appointment_deposit_atomic`, `void_appointment_deposit_atomic` | `comanda.operate` |
| `adjust_client_balance_atomic` | `financeiro.manage` |
| `reverse_client_balance_entry_atomic` | `comanda.refund` |
| Políticas de `transactions` (leitura) | `financeiro.view` |

## Fase 2a: catálogo, equipe e marketing

Os padrões não mudam (as listas fixas antigas eram exatamente proprietária, administração e gestão).

| Objeto | Permissão |
|---|---|
| Políticas de `services`, `service_categories`, `service_bundles`, `service_bundle_items`, `service_packages`, `package_services`, `service_staff`, `products`, `subscription_plans` (inserir, editar, apagar) | `catalogo.manage` |
| `upsert_catalog_service_atomic`, `upsert_service_package_atomic`, `upsert_service_bundle_atomic`, `replace_service_staff_atomic`, `archive_`, `duplicate_` e `restore_service_bundle` | `catalogo.manage` |
| Políticas de `staff_members` e `staff_shifts` | `equipe.manage` |
| Políticas de `marketing_campaigns`, `marketing_message_queue`, `marketing_message_templates`, `marketing_segments`, `marketing_message_events` (inserir) | `mensagens.configure` |

Ações do app: `catalogo/actions.ts`, `catalogo/package-actions.ts`, `equipe/actions.ts` e `marketing/actions.ts` usam `orgCan`.

Fase 2 (próximos incrementos): estoque, cobranças,
demais tabelas financeiras e perfis personalizados. O que ainda usa lista fixa de
papéis está listado em `docs/reviews/2026-10-29-revisao-codigo-e-banco.md`.

## Fase 2b: agenda

Decisão do Alexandre (29 out): a agenda é **configurável por perfil**.

| Objeto | Permissão |
|---|---|
| `create_appointment_atomic`, `create_recurring_appointments_atomic`, `update_appointment_atomic`, `reschedule_appointment_atomic`, `set_appointment_status_atomic`, `update_appointment_item_atomic`, `update_recurrence_series_atomic`, `cancel_recurrence_series_atomic` | `agenda.manage` |
| Políticas de `appointments` (inserir, editar) e `appointment_items` (inserir, editar, apagar) | `agenda.manage` |
| `create_time_blocks_atomic`, `delete_time_block_atomic` e políticas de `time_blocks` | `agenda.block_time` (nova) |

- **Nova liberação `agenda.block_time`** (bloquear horários): padrão para proprietária,
  administração, gestão, recepção e profissional, que já podiam. A profissional continua
  bloqueando a própria folga.
- **Divergência 1 resolvida:** as RPCs e a política de edição aceitavam a profissional mesmo
  sem `agenda.manage`. Agora o padrão é igual à matriz (profissional só consulta) e a dona
  pode ligar "Criar e alterar agendamentos" para a profissional.
- **Furo fechado:** a política de inserir em `appointments` só pedia ser membro do estúdio
  (até "somente leitura" inseria direto pela API).
- App: `agenda/actions.ts`, `recurrence-actions.ts` e `time-block-actions.ts` usam `orgCan`;
  a página passa `canManage`/`canBlock` para a agenda, que esconde "Novo", "Bloquear", o
  clique no horário vago e as ações de mudança da ficha do agendamento.
- Ficam com lista fixa: apagar agendamento de vez (`appointments: cancelar`, só gestão),
  forçar encaixe sobre conflito (proprietária, administração e gestão), tipos de bloqueio.
- Limite conhecido: o banco não restringe a edição à agenda da própria profissional; quem
  recebe `agenda.manage` altera qualquer agendamento do estúdio.

Teste de banco 115; testes 102 e 113 atualizados (sem divergências declaradas; 23 permissões).

## Liberações editáveis na fase 1

Só aparecem como interruptor as que o banco e o app respeitam de ponta a ponta:
`clientes.view_clinical`, `anamnese.view_status`, `anamnese.fill_professional`,
`comanda.operate`, `comanda.refund` (`EDITABLE_PERMISSIONS` em `src/domain/access-catalog.ts`).
As demais seguem o padrão do sistema até a fase 2, para a tela nunca prometer o que o banco
não cumpre. Dependência: preencher ficha exige ler ficha (as funções de preenchimento rodam
com os direitos de quem chama); a tela liga as duas juntas e desliga as duas juntas
(`PERMISSION_REQUIRES`).

## Tela

Configurações > "Perfis e liberações" (só owner/admin). Uma coluna por papel
(Recepção, Profissional, Gestão, Financeiro, Somente leitura, Administração), linhas
agrupadas por módulo, interruptor por permissão, marca de "diferente do padrão" e botão
"Voltar ao padrão" por papel. Mobile: um papel por vez, seletor no topo. Interruptores
com área de toque mínima de 40 px.

## Critérios de aceite

1. Com o padrão, o comportamento de recepção, profissional e demais papéis não muda,
   exceto os ajustes da seção "Permissões novas".
2. Ligar `clientes.view_clinical` para a recepção abre o conteúdo das fichas e das fotos;
   desligar fecha de novo, sem deploy.
3. Desligar `comanda.operate` para a recepção bloqueia o fechamento da comanda e o sinal
   no banco (erro 42501) e esconde o caixa na interface.
4. Admin não consegue conceder a si mesmo nem a outro o que só a proprietária concede.
5. Toda mudança aparece em `audit_logs`.
6. Outro estúdio nunca enxerga nem altera as exceções deste.
7. Paridade: `ROLE_PERMISSIONS` (TS) e `role_default_permissions()` (SQL) idênticos.
