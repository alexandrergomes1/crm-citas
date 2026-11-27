# Spec · Ligar o banco existente (núcleo, tabela por tabela)

- **Status:** Draft
- **Aprovação do dono:** (pendente)
- **Aprovação do merge:** (pendente)
- **Item da fila:** 3 (`docs/BACKLOG.md`) · **Branch:** `feat/banco-ligacao` (a partir da `previas`)
- **Tipo:** Banco (`docs/guias/processo-sdd.md` §3) · **Revisores:** Engenheiro de dados (quem não fez), Auditor de risco e QA
- **Escrito por:** Analista de requisitos · **Norma:** IEEE 29148 e BABOK
- **Fontes:** pedido (a) anterior ao E1; E22·B (28/11); `AGENTS.md` §1, §3 regra 4, §6; `ARCHITECTURE.md` §3 a §9;
  `SECURITY.md` §2 a §5; `src/data/AGENTS.md`; decisões E3·2, E4·1, E5·1, E5·2, E6·1, E6·2, E16·1
  (`docs/decisoes/2026-11-27-fundacao.md`).

## 1. Pedido do dono (literal)
> "cria uma pasta nova do projeto, DO ZERO (...) e só ligamos no banco, pega o design aprovado, etc..." — pedido (a), anterior ao E1.

> "O banco de dados atual é tudo de desenvolvimento, todos os dados são fictícios. O que se tem são as tabelas e regras
> dele. Então use se precisar. E22b" — 28/11/2026, repassada pelo Gerente de projeto (link: a gravar pelo Documentador
> em `docs/decisoes/`).

**Alcance do E22·B, como repassado:** autoriza ler e trazer as travas e as migrations do núcleo do projeto antigo, só
leitura; banco só local, nada no remoto; cada tabela decidida pelo Engenheiro de dados com ADR e revisão de outro
papel; dado real e segredo nunca vêm. **Fatos do dono:** o banco existente é de desenvolvimento e os dados nele são
fictícios.

## 2. O que é "ligar o banco existente"
O crm-citas passa a usar como **banco de desenvolvimento** o projeto Supabase que já existe (`ARCHITECTURE.md` §8),
desde que na UE (E24·1). O esquema **não** é herdado em bloco: entra **tabela por tabela**, como migrations no
repositório do crm-citas (`supabase/`). Para cada tabela, o Engenheiro de dados decide **copiar, reescrever ou
descartar** (E16·1), registra motivo e norma em `docs/adr/`, e outro papel confere. Toda tabela do estúdio nasce com
`org_id`, trava RLS e teste de isolamento. A IA nunca aplica nada no remoto: só a CI, depois da "Aprovação do merge"
gravada nesta spec. O banco de produção, separado, não faz parte desta spec.

## 3. Ordem
1. **Base da trava** (dedução de `ARCHITECTURE.md` §4 a §6: sem ela não há `org_id` nem papel na sessão).
2. **Núcleo (E3·2), um módulo por vez:** Agenda, Agendamento, Clientes, Formulários, Catálogo, Checkout, Caixa.
3. Nenhuma tabela fora do núcleo nesta spec.

## 4. Tabelas candidatas no projeto antigo (inventário, nada copiado)
Lido em `crm-agenda/supabase/migrations/` (177 arquivos, só leitura, E22·B), pelos comandos `create table` e
comentários. A decisão de cada uma é do Engenheiro de dados (E16·1); esta lista não é decisão.

| Grupo | Tabela (antigo) | Para que serve no antigo |
|---|---|---|
| Base da trava | `organizations` | o estúdio (inquilino) |
| | `profiles` | a pessoa dentro de um estúdio |
| | `user_roles` | papel da pessoa no estúdio |
| | `org_role_permissions` | exceções do estúdio à matriz padrão de permissões por papel |
| | `org_profiles`, `org_profile_permissions` | perfis de acesso criados pelo estúdio e suas exceções |
| | `locations` | unidades físicas do estúdio |
| Agenda | `staff_members` | profissionais e equipe |
| | `staff_shifts` | horário de trabalho por dia da semana |
| | `time_blocks`, `time_block_types` | bloqueios de horário e seus tipos |
| | `resources` | salas e equipamentos |
| | `agenda_waitlist` | fila de espera |
| Agendamento | `appointments` | o agendamento |
| | `appointment_items` | serviços e produtos do agendamento |
| | `appointment_status_history` | histórico de status |
| | `appointment_counters` | último número de agendamento por estúdio |
| | `appointment_deposits` | sinal pago no agendamento (dinheiro) |
| Clientes | `clients` | a cliente do estúdio |
| | `client_notes` | notas e observações da cliente |
| | `client_balance_entries` | saldo da cliente, lançamento a lançamento (dinheiro) |
| | `client_entitlements`, `client_entitlement_entries` | sessões compradas em pacote ou plano e seu consumo |
| Formulários | `anamnese_templates` | modelos de ficha (perguntas e termo de consentimento) |
| | `anamneses` | a ficha respondida e assinada (dado de saúde) |
| | `anamnese_answer_versions` | correções da profissional depois da assinatura (dado de saúde) |
| | `anamnese_events` | envio, renovação e abertura do link da ficha |
| | `anamnese_gate_overrides` | comanda fechada sem a avaliação da ficha |
| Catálogo | `service_categories`, `services` | categorias e serviços |
| | `staff_services`, `service_staff` | quem faz cada serviço (duas tabelas para o mesmo fim) |
| | `products` | produtos para venda e uso em serviço |
| | `service_packages`, `service_package_items`, `package_services` | pacotes de sessões (duas tabelas de itens) |
| | `service_bundles`, `service_bundle_items` | combos feitos no mesmo atendimento |
| Checkout | `sales`, `sale_items`, `sale_payments` | comanda, itens e pagamentos |
| | `sale_refunds`, `sale_partial_refunds` | estorno total e devoluções parciais |
| | `sale_counters` | último número de comanda por estúdio |
| | `checkout_requests` | trava contra fechamento duplicado da comanda |
| Caixa | `cash_sessions`, `cash_movements` | caixa do dia (abertura, fechamento, sangria, suprimento) |
| | `transactions` | lançamentos de receita e despesa |

**Achados para o Engenheiro de dados e o Auditor de risco** (indícios da leitura, não verificados a fundo):
- `staff_services`, `package_services` e `service_package_items` foram criadas sem `org_id` (contraria `ARCHITECTURE.md` §5).
- `anamneses.answers` guarda as respostas da ficha em `jsonb` sem cifra aparente (contraria E5·2): copiar não serve.
- Várias tabelas são criadas em duas migrations (`20260601…` e `20260609_001_foundation`); o formato final só sai de
  todas as migrations em ordem, não de uma só.
- Há tabelas fora do núcleo ligadas às do núcleo (ex.: `appointment_deposits` aponta para `transactions` e `sales`;
  `client_entitlements` para planos e pacotes).

## 5. Requisitos funcionais
| ID | Requisito | Fonte |
|---|---|---|
| RF-01 | O banco de desenvolvimento do crm-citas é o projeto Supabase existente, se estiver na UE; senão, vale a opção escolhida em E24·1. | pedido (a); E5·1; §8 |
| RF-02 | A leitura do antigo se limita às migrations e travas das tabelas da §4 (E22·B); seeds, dados e segredos do antigo não são lidos nem trazidos. | E22·B; `AGENTS.md` §6 |
| RF-03 | Para cada tabela, o Engenheiro de dados decide copiar, reescrever ou descartar, com motivo e norma num ADR em `docs/adr/`, e outro papel confere. | E16·1; `AGENTS.md` §3 regras 3 e 4 |
| RF-04 | Decisão de tabela que muda o que o estúdio vê, regra de dinheiro (sinal, saldo, comanda, caixa), dado de cliente ou de saúde, ou acesso, vira pergunta ao dono antes de construir; o resto é decisão técnica avisada em uma linha. | `AGENTS.md` §5 |
| RF-05 | Cada tabela entra por migration versionada em `supabase/`; nenhuma mudança de banco fora de migration. | `ARCHITECTURE.md` §3 e §8 |
| RF-06 | Toda tabela do estúdio tem `org_id` obrigatório e trava RLS que só devolve e só aceita linhas do estúdio da sessão. | `ARCHITECTURE.md` §4 e §5 |
| RF-07 | Quem não tem login não lê nem grava nenhuma tabela do estúdio. | `ARCHITECTURE.md` §4 |
| RF-08 | As migrations vão ao remoto só pela CI, depois da "Aprovação do merge"; a IA nunca aplica (nem por linha de comando, nem por MCP). Antes disso, só em banco local. | `AGENTS.md` §1; E22·B |
| RF-09 | O que o crm-citas faz com o esquema antigo e os dados fictícios já presentes no projeto existente segue E24·2. | `AGENTS.md` §5 (produção, acesso) |
| RF-10 | O app lê endereço e chaves do banco do ambiente, guardadas só nos cofres; a chave de serviço só em tarefas internas listadas. | `SECURITY.md` §2; Twelve-Factor III |

## 6. Requisitos não funcionais
| ID | Requisito | Fonte |
|---|---|---|
| RNF-01 | Projeto do banco, cópias e fornecedores na UE (ou com DPA e base de transferência). | E5·1; `ARCHITECTURE.md` §7 |
| RNF-02 | Nenhum segredo e nenhum dado de pessoa no repositório, em migration ou dado de teste; dados de teste fictícios e escritos do zero. | `AGENTS.md` §6 |
| RNF-03 | As tabelas com dado de saúde (`anamneses`, `anamnese_answer_versions`) só entram com as respostas cifradas e a chave em cofre (E5·2, ASVS V6.1.2), pela spec própria da ficha (consentimento, DPIA); nesta spec entram só modelos e eventos sem resposta de saúde, se o Engenheiro de dados os mantiver. | E5·2; `ARCHITECTURE.md` §7 |
| RNF-04 | Índices por `org_id` para listas paginadas e poucas idas ao banco por tela. | `ARCHITECTURE.md` §5 e §11 |
| RNF-05 | As exceções E6·1 e E6·2 valem como estão: nenhuma tabela desta spec registra a entrada do dono nem o que ele faz no modo suporte. | `ARCHITECTURE.md` §6; `AGENTS.md` §6 |

## 7. Critérios de aceite (verificáveis)
| ID | Critério | Como se prova |
|---|---|---|
| CA-01 | Cada tabela da §4 tem ADR com decisão (copiar, reescrever ou descartar), motivo, norma e o papel que conferiu. | `docs/adr/` |
| CA-02 | Há migration em `supabase/` só para as tabelas com decisão copiar ou reescrever, e nenhuma outra. | arquivos do PR × ADRs |
| CA-03 | Cada tabela do estúdio tem `org_id` não nulo e RLS ligada. | teste automático na CI |
| CA-04 | Para cada tabela, o teste prova que o estúdio A não lê, não cria, não altera e não apaga linha do estúdio B. | teste de isolamento na CI, verde |
| CA-05 | Sem login, nenhuma tabela do estúdio é lida ou gravada. | teste automático na CI |
| CA-06 | Nenhuma migration aplicada no remoto fora da CI; a aplicação só depois da "Aprovação do merge". | histórico da CI e desta spec |
| CA-07 | Região do projeto na UE, com prova sem chave nem dado pessoal (E24·1). | registro da conferência |
| CA-08 | Nenhum segredo, seed ou dado do antigo no PR. | gitleaks verde (item 2 da fila) e revisão |
| CA-09 | Nenhuma resposta de ficha de saúde gravável sem cifra. | revisão do Auditor de risco e do Engenheiro de segurança |
| CA-10 | O projeto existente foi tratado exatamente como E24·2. | revisão do Auditor de risco |
| CA-11 | Revisão do tipo Banco sem "Bloqueia" e veredito do QA. | relatórios no PR |

## 8. Fora de escopo
- Tabelas fora do núcleo (fidelidade, marketing, estoque, contas a pagar, vale-presente, planos de assinatura,
  módulos e planos da plataforma, administradores, cobrança por link, páginas públicas, PIN do modo estúdio,
  preferências de tela, `audit_logs`).
- Cifra da ficha de saúde e as respostas dela (spec própria, `ARCHITECTURE.md` §7).
- Banco de produção e publicação (`previas` → `main`).
- Telas, `src/server` e regras de negócio dos módulos (item 5 da fila).
- Auditoria da porta 6 e cópia diária (E5·3): o Arquiteto indica no plano onde entram.

## 9. Dependências
- Item 2 da fila (CI, gitleaks, app vazio): sem CI não há quem aplique a migration nem prove o isolamento.
- Gravação do E22·B em `docs/decisoes/` pelo Documentador, com o link.

## 10. Dúvidas ao dono (máx. 3)
**E24·1 · Região do banco existente** (dados na UE, E5·1)
- O que se pede: o dono confere, no painel do Supabase, nas configurações do projeto, a região, e responde sem chave.
- **E24·1·A:** está na UE → é o banco de desenvolvimento do crm-citas.
- **E24·1·B:** fora da UE → cria-se um projeto novo na UE para desenvolvimento; o existente fica só para consulta.
- **Recomendo:** A se for UE; senão B (E5·1). Desfaz-se trocando o endereço do banco nos cofres.

**E24·2 · O que acontece com o esquema antigo no banco existente** (acesso, ambiente)
- Hoje o projeto existente tem as tabelas do antigo e dados fictícios; o esquema novo é diferente.
- **E24·2·A:** o crm-citas assume o projeto: a CI, depois da "Aprovação do merge", limpa o esquema antigo e os dados
  fictícios e aplica o novo; o app antigo deixa de funcionar nesse banco.
- **E24·2·B:** o existente fica intocado para o antigo; o crm-citas usa um projeto novo de desenvolvimento na UE.
- **Recomendo A:** dados fictícios (fala do dono), o esquema antigo continua guardado nas migrations do antigo e
  pode ser recriado; um projeto só evita custo e confusão. Desfaz-se recriando o esquema antigo pelas migrations dele.

## 11. Assumptions (decisões técnicas do papel, à vista na aprovação)
1. Uma migration por tabela, com data e hora no nome, na pasta de migrations do Supabase em `supabase/` (caminho exato após ler a documentação oficial).
2. A ferramenta do teste de isolamento é escolhida pelo Arquiteto no plano, depois de lida a documentação oficial.
3. Dados de teste escritos do zero, fictícios; nada vem dos seeds do antigo.
4. Os ADRs seguem a numeração de `docs/adr/` (próximo: 0002).
