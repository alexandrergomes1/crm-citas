# Spec 29 - Acesso, papéis, módulos por estúdio e administração master

## Status

Base de banco e domínio implementada nesta entrega (migration
`20261028210000_access_modules_platform.sql`, `src/domain/access.ts`,
`src/data/auth/access.ts`). Telas de equipe e acessos, convite e área master
ficam para a fase comercial. Desenho de referência: artefato V25 (AjustesPlano,
AdminEstudios, AdminEstudio, AdminPlanos).

## Decisões (28 out 2026)

- **Piloto solo:** hoje o sistema é usado só pela Karenn (proprietária). Perfis de
  acesso entram no escopo da versão comercial, mas a estrutura de segurança já nasce
  pronta para eles.
- **Login:** continua no **Supabase Auth** (e-mail e senha), no mesmo projeto do banco.
  Motivo: a RLS usa `auth.uid()` direto, sem ponte entre provedores; a sessão já é
  verificada no `proxy.ts` com `getClaims()`. Trocar para outro provedor (Clerk, Auth0,
  Vercel) só se faltar algo que o Supabase não ofereça (ex.: SSO corporativo). Vercel não
  tem autenticação própria para usuários do app.
- **Papéis oferecidos na interface:** proprietária (owner), administração (admin),
  recepção (receptionist), profissional (professional, inclusive terceira). `manager`,
  `finance` e `viewer` continuam no banco por compatibilidade.
- **Administração master:** é do Beauty System, fora dos estúdios (`platform_admins`).
  Escrita nessa tabela só com service_role.
- **Planos fixos + extras**, configuráveis pelo master por estúdio.

## 1. Regras de acesso (banco)

| Regra | Onde |
|---|---|
| Toda tabela de negócio tem `org_id` e RLS | checagem `supabase/tests/10_security_checks.sql` |
| Só a proprietária concede owner ou admin; admin concede papéis operacionais | políticas `user_roles_insert/update/delete` |
| Ninguém concede, altera ou remove o próprio papel | gatilho `tg_user_roles_guard` |
| O estúdio sempre tem ao menos uma proprietária ativa | gatilho `tg_user_roles_guard` |
| Mudança de papel, plano ou módulo vai para `audit_logs` | gatilho `tg_audit_access_change` |
| Ninguém grava log de auditoria em nome de outra pessoa | política `audit_insert_member` |
| `anon` não executa funções de negócio; exceção: link público da anamnese | bloco final da migration + checagem 3 |
| Funções security definer com `search_path` fixo | checagem 2 |

## 2. Módulos e planos

- `modules`: registro (`is_core` sempre ligado; `depends_on`).
  Núcleo: agenda, clientes, catalogo, financeiro, anamnese.
- `plans` + `plan_modules` (`included` ou `extra` com preço).
- `org_subscriptions` (plano e status: trial, active, suspended, canceled) e
  `org_modules` (extra ligado ou exceção desligada, com preço e motivo).
- `org_enabled_modules(org)` e `org_has_module(org, key)`: núcleo + incluídos + extras −
  desligados, respeitando dependências. Estúdio suspenso ou cancelado fica só com o núcleo
  (dados preservados).
- Estúdio novo entra em teste no Profissional por 30 dias. Estúdios existentes (piloto)
  entram no **Completo**: nada que já funciona some.
- Leitura de plano e módulos: membros do estúdio e master. Escrita: só master.

| Módulo | Básico | Profissional | Completo |
|---|---|---|---|
| Agenda, Clientes, Catálogo, Comandas e Financeiro, Anamnese | núcleo | núcleo | núcleo |
| Mensagens | extra 12 € | incluído | incluído |
| Equipe e comissões | — | incluído | incluído |
| Cobrança por transferência (spec 30) | extra 5 € | incluído | incluído |
| Avaliações no Google (usa Mensagens) | — | extra 9 € | incluído |
| Reserva online | extra 15 € | extra 15 € | incluído |
| Fidelidade | extra 12 € | extra 12 € | incluído |
| Campanhas e segmentos (usa Mensagens) | — | extra 15 € | incluído |
| Estoque e compras | — | extra 12 € | incluído |
| Relatórios avançados e DRE | — | — | incluído |
| Várias unidades | — | — | extra 29 € cada |

Preços de exemplo, editáveis pelo master.

## 3. Matriz de permissões (interface e Server Actions)

`src/domain/access.ts` (`can`, `canGrantRole`, `resolveEnabledModules`). O banco continua
sendo a autoridade; a matriz serve para esconder o que não se pode usar e recusar cedo.

| Permissão | Proprietária | Admin | Recepção | Profissional |
|---|:-:|:-:|:-:|:-:|
| Agenda de todas | ✓ | ✓ | ✓ | — (só a própria) |
| Clientes: ver e editar | ✓ | ✓ | ✓ | ver as que atende |
| Dados clínicos (anamnese) | ✓ | ✓ | — | ✓ |
| Comanda: operar | ✓ | ✓ | ✓ | — |
| Estorno | ✓ | ✓ | — | — |
| Financeiro e relatórios | ✓ | ✓ | — | — |
| Catálogo: editar | ✓ | ✓ | — | — |
| Equipe e acessos | ✓ | ✓ (sem conceder admin) | — | — |
| Ajustes do estúdio | ✓ | ✓ | — | — |

Permissão de um módulo desligado não vale, mesmo para a proprietária.

## 4. Pendências para a fase multiusuário

- Restringir na RLS o que a profissional terceira vê (só os próprios agendamentos e
  clientes que atende) e o que a recepção vê do financeiro. Hoje a RLS permite leitura por
  qualquer membro do estúdio; para o piloto solo isso não muda nada.
  (Feito em 29 out para dados clínicos: ver 4c.)
- Convite por e-mail, aceite, troca de estúdio, perfil e preferências do usuário
  (vista inicial por aparelho, profissional padrão, atalhos fixos no "Mais").
- Menu gerado por `getAccessContext()` (módulos + papel).
- Telas da área master e fila de pedidos de ativação.
- "Entrar como o estúdio" (suporte) com motivo, prazo de 1 h e auditoria visível.

## 4b. Na interface (29 out 2026)

- O layout do estúdio lê papel e módulos (`getAccessContext`) e o menu (lateral,
  gaveta e barra inferior) mostra só o que o plano e o papel permitem
  (`visibleNav` em `src/app-shell/nav-config.ts`). Quem barra de verdade continua
  sendo o banco e as páginas.
- Marketing e Fidelidade respondem 404 quando o módulo está desligado
  (`requireModule`). Equipe exige `equipe.view` (`requirePermission`).
- **Equipe não depende do módulo "Equipe e comissões".** O estúdio solo do plano
  Básico também precisa editar o próprio cadastro de profissional e os horários. O
  módulo libera várias profissionais e comissões (limite `staff` do plano), não a tela.
- Configurações › **Plano** (só proprietária e administração): plano, situação
  (teste, ativo, suspenso), total por mês, limites, módulos ativos e extras para
  ativar com preço. Ativar é com o suporte; não há pedido automático ainda.
- Transição: enquanto o banco não recebe a migration 20261028210000, a função
  `org_enabled_modules` não existe e o app mostra todos os módulos, como antes
  (`isMissingModulesRpc`). A aba Plano mostra "Plano ainda não configurado".

## 4c. Dados clínicos da anamnese no banco (29 out 2026)

- `anamneses` (SELECT) e as fotos da ficha (storage `anamnese-photos`) só admitem owner,
  admin, manager e professional. Recepção, visualizadora e financeiro não leem a tabela.
- A recepção opera as fichas por funções `security definer` que checam o papel:
  `list_anamnese_status` (título, situação, link, datas; nenhum campo clínico),
  `get_appointment_anamnese_gate`, `create_anamnese_atomic` (devolve a ficha sem campos
  clínicos) e o gatilho de vínculo automático da ficha ao incluir serviço.
- No app, as listas que não precisam de resposta ou assinatura (agenda, comanda, consentimentos
  da recepção, uso de modelo) leem o status por `listAnamneseStatus`; só quem tem
  `clientes.view_clinical` lê a tabela (`listAnamneses`, `getAnamneseById`).
- Teste de banco: `supabase/tests/112_anamnese_clinical_read.sql`.

## 5. Testes

- `pnpm db:verify`: aplica todas as migrations num Postgres limpo, roda as checagens
  estáticas e os testes de comportamento (isolamento entre estúdios, concessão de papéis,
  última proprietária, módulos e dependências, suspensão, auditoria, anon).
- Vitest: `src/domain/access.test.ts`, `src/domain/plan.test.ts`,
  `src/app-shell/nav-config.test.ts`, `src/data/auth/access.test.ts`,
  `src/lib/safe-redirect.test.ts`.
- Prévia sem banco: `/dev/plano`.
- CI: `.github/workflows/db-security.yml`.

## Critérios de aceite

- [x] Estúdio A não lê nem altera dados do estúdio B.
- [x] Admin não concede owner/admin; ninguém altera o próprio papel; sempre há uma proprietária.
- [x] Módulo extra só liga pelo master; dependências e suspensão respeitadas.
- [x] Mudanças de acesso, plano e módulo ficam auditadas.
- [x] Login não redireciona para fora do site depois de entrar.
- [x] Menu e páginas respeitam módulos do plano e papel.
- [x] Estúdio vê o próprio plano e os extras disponíveis.
- [ ] Telas de equipe e acessos (fase comercial).
- [x] RLS dos dados clínicos da anamnese e das fotos por papel.
- [ ] RLS por papel do restante (agenda da profissional, financeiro da recepção) na fase multiusuário.
