# Spec · Ligar o banco existente: base da trava por estúdio e regras para trazer as tabelas

- **Status:** Approved
- **Aprovação do dono:** "Aprovo as specs: Entrar e camada de serviço, Trava por estúdio no banco, Design system no código, Agenda, Agendamento, Clientes, Formulários, Catálogo, Checkout, Caixa." · 28/11/2026 · https://claude.ai/code/session_018cV8b8F1poNHjA4eEd3VyN
  (`docs/decisoes/2026-11-27-fundacao.md`, linha "Aprovação das specs") · gravado pelo Analista de requisitos (E16·3)
- **Aprovação do merge:** (pendente)
- **Item da fila:** 3 (`docs/BACKLOG.md`), em paralelo aos itens 1 e 2 por ordem do dono (E22·B, §1)
- **Branch:** `feat/banco-ligacao`, única do item 3 (spec, plano, construção e registros), já com a `chore/fundacao-tecnica`
  juntada por merge; PR de rascunho empilhado sobre ela, nunca juntado nela; a base passa à `previas` quando o item 2
  entrar, antes do pedido de merge; nada é juntado sem o dono (E22·B)
- **Tipo:** Banco (`docs/guias/processo-sdd.md` §3) · **Revisores:** Engenheiro de dados (quem não fez), Auditor de
  risco e Engenheiro de segurança (acesso) e QA
- **Escrito por:** Analista de requisitos · **Norma:** IEEE 29148 e BABOK
- **Fontes:** pedido (a) anterior ao E1; E22·B; `AGENTS.md` §1, §3 regra 4, §5, §6; `ARCHITECTURE.md` §3 a §8;
  `SECURITY.md` §2 a §5; `src/data/AGENTS.md`; E3·2, E5·1, E5·2, E6·1, E6·2, E16·1.

## 1. Pedido e ordens do dono (literal)
> "cria uma pasta nova do projeto, DO ZERO (...) e só ligamos no banco, pega o design aprovado, etc..." — pedido (a), anterior ao E1.

> "O banco de dados atual é tudo de desenvolvimento, todos os dados são fictícios. O que se tem são as tabelas e regras
> dele. Então use se precisar. E22b Bom trabalho e obrigado." — E22·B, 28/11/2026,
> https://claude.ai/code/session_018cV8b9epaQJNqguG5c5Aqb (registrada em `docs/decisoes/2026-11-27-fundacao.md`,
> linha "E22·B", na branch `docs/produto-modulos`, PR #2).

**O que o E22·B manda:** specs e construção em PRs de rascunho, em paralelo; nada é juntado sem o dono; banco só
local. Autoriza ler e trazer do antigo as travas e as migrations e regras do núcleo, cada item decidido pelo papel da
área (copiar, reescrever, descartar) com ADR e revisão de outro papel. Dado real e segredo nunca vêm. O banco
existente é de desenvolvimento, com dados fictícios.

## 2. O que é "ligar o banco existente"
O crm-citas passa a usar como **banco de desenvolvimento** o projeto Supabase que já existe (`ARCHITECTURE.md` §8),
desde que na UE (E24·1). O esquema não é herdado em bloco: entra **tabela por tabela**, como migrations no
repositório do crm-citas (`supabase/`), cada tabela decidida pelo Engenheiro de dados (E16·1) com ADR e revisão.
A IA nunca aplica nada no remoto: só a CI, depois da "Aprovação do merge" gravada na spec.

**Divisão:** esta spec cobre só (a) a **base da trava por estúdio** e (b) as **regras gerais** para trazer cada
tabela (§5). As tabelas de cada módulo do núcleo (E3·2) entram na spec daquele módulo, com as dúvidas dela (até 3).

## 3. Escopo desta spec: a base da trava
1. **Estúdio** (o inquilino; dono do `org_id`), com moeda, idioma padrão e fuso horário (RF-09).
2. **Membros:** a pessoa ligada a um estúdio.
3. **Papéis e permissões:** o papel da pessoa em cada estúdio (dona, recepção, profissional; `ARCHITECTURE.md` §6).
4. **Função de checagem de acesso:** diz, a partir da sessão, de qual estúdio a pessoa é e o que o papel dela pode;
   é a base das travas RLS de todas as tabelas (`ARCHITECTURE.md` §4, portas 2, 3 e 5).
5. **Teste de isolamento** dessas tabelas e um molde do teste para as specs dos módulos.

Candidatas do antigo para este escopo (inventário, nada copiado): `organizations` (o estúdio), `profiles` (a pessoa
no estúdio), `user_roles` (papel da pessoa no estúdio), `org_role_permissions` (exceções do estúdio à matriz padrão
de permissões), `org_profiles` e `org_profile_permissions` (perfis de acesso criados pelo estúdio e suas exceções).

## 4. Requisitos funcionais
| ID | Requisito | Fonte |
|---|---|---|
| RF-01 | O banco de desenvolvimento do crm-citas é o projeto Supabase existente, se estiver na UE; senão, vale E24·1. | pedido (a); E5·1; §8 |
| RF-02 | Existem as tabelas de estúdio, membros e papéis, e a função de checagem de acesso, cada uma decidida (copiar, reescrever, descartar) com ADR. | E22·B; E16·1 |
| RF-03 | O estúdio vem da sessão, nunca do pedido; a função de checagem não aceita estúdio vindo de fora. | `ARCHITECTURE.md` §4 |
| RF-04 | Pessoa sem papel num estúdio não lê nem grava nada daquele estúdio. | `ARCHITECTURE.md` §4 e §6 |
| RF-05 | Quem não tem login não lê nem grava nenhuma tabela do estúdio. | `ARCHITECTURE.md` §4 |
| RF-06 | Os papéis iniciais são dona, recepção e profissional; papéis configuráveis só se o Engenheiro de dados mantiver as tabelas de perfil, e o que o estúdio vê disso vai à spec do módulo que tiver a tela. | `ARCHITECTURE.md` §6; `AGENTS.md` §5 |
| RF-07 | O que o crm-citas faz com o esquema antigo e os dados fictícios do projeto existente segue E24·2. | `AGENTS.md` §5 |
| RF-08 | O app lê endereço e chaves do banco do ambiente, guardadas só nos cofres; a chave de serviço só em tarefas internas listadas. | `SECURITY.md` §2; Twelve-Factor III |
| RF-09 | Cada estúdio guarda a sua moeda, o seu idioma padrão (português, espanhol ou inglês) e o seu fuso horário; a coluna exata o Engenheiro de dados decide no plano, com ADR. | `ARCHITECTURE.md` §11 ("Idiomas, fuso horário e moeda por estúdio"); E3·1 |

## 5. Regras gerais para trazer cada tabela (valem para as specs dos módulos)
| ID | Regra | Fonte |
|---|---|---|
| RG-01 | Do antigo só se leem migrations e travas (E22·B); seeds, dados e segredos não se leem nem se trazem. | E22·B; `AGENTS.md` §6 |
| RG-02 | Cada tabela tem uma saída registrada em ADR: **copiar**, **reescrever**, **descartar** ou **adiada (vai para a spec do módulo)**, com motivo, norma e o papel que conferiu. | E16·1; `AGENTS.md` §3 regras 3 e 4 |
| RG-03 | Decisão de tabela que muda o que o estúdio vê, regra de dinheiro, dado de cliente ou de saúde, ou acesso, vira dúvida ao dono na spec do módulo; o resto é decisão técnica avisada em uma linha. | `AGENTS.md` §5 |
| RG-04 | Toda tabela do estúdio tem `org_id` obrigatório, trava RLS pela função de checagem, índice por `org_id` e teste de isolamento. | `ARCHITECTURE.md` §5 e §11 |
| RG-05 | Mudança de banco só por migration em `supabase/`; antes do merge, só em banco local; no remoto, só pela CI depois da "Aprovação do merge". A IA nunca aplica (nem por linha de comando, nem por MCP). | `AGENTS.md` §1; E22·B |
| RG-06 | Dado de saúde só entra cifrado, com a chave em cofre, pela spec da ficha (consentimento, DPIA). | E5·2; `ARCHITECTURE.md` §7 |
| RG-07 | Dados de teste escritos do zero, fictícios. | `AGENTS.md` §6 |
| RG-08 | As exceções E6·1 e E6·2 valem como estão: nenhuma tabela registra a entrada do dono nem o que ele faz no modo suporte. | `ARCHITECTURE.md` §6 |

## 6. Requisitos não funcionais
| ID | Requisito | Fonte |
|---|---|---|
| RNF-01 | Projeto do banco, cópias e fornecedores na UE (ou com DPA e base de transferência). | E5·1; `ARCHITECTURE.md` §7 |
| RNF-02 | Nenhum segredo e nenhum dado de pessoa no repositório, em migration ou dado de teste. | `AGENTS.md` §6 |

## 7. Critérios de aceite (verificáveis)
| ID | Critério | Como se prova |
|---|---|---|
| CA-01 | Cada candidata da §3 tem ADR com saída (copiar, reescrever, descartar ou adiada), motivo, norma e o papel que conferiu. | `docs/adr/` |
| CA-02 | Há migration em `supabase/` só para as candidatas com saída copiar ou reescrever, e para a função de checagem; nenhuma tabela de módulo. | arquivos do PR × ADRs |
| CA-03 | Cada tabela do estúdio desta spec tem `org_id` não nulo e RLS ligada. | teste automático na CI |
| CA-04 | O teste prova que o estúdio A não lê, não cria, não altera e não apaga linha do estúdio B, em cada tabela desta spec. | teste de isolamento na CI, verde |
| CA-05 | O teste prova que pessoa sem papel no estúdio e quem não tem login não leem nem gravam nada. | teste automático na CI |
| CA-06 | A função de checagem ignora estúdio mandado no pedido. | teste automático na CI |
| CA-07 | Há molde do teste de isolamento para as specs dos módulos. | arquivo em `supabase/` e revisão |
| CA-08 | Nenhuma migration aplicada no remoto fora da CI; aplicação só depois da "Aprovação do merge". | histórico da CI e da spec |
| CA-09 | Região do projeto na UE, com prova sem chave nem dado pessoal (E24·1). | registro da conferência |
| CA-10 | Nenhum segredo, seed ou dado do antigo no PR. | gitleaks verde (item 2 da fila) e revisão |
| CA-11 | O projeto existente foi tratado exatamente como E24·2. | revisão do Auditor de risco |
| CA-12 | Revisão do tipo Banco e de acesso sem "Bloqueia" e veredito do QA. | relatórios no PR |
| CA-13 | Todo estúdio tem moeda, idioma padrão e fuso horário preenchidos; idioma fora de português, espanhol e inglês é recusado; a moeda segue a regra escolhida em E24·3. | teste automático na CI |

## 8. Fora de escopo
- As tabelas de cada módulo do núcleo (Agenda, Agendamento, Clientes, Formulários, Catálogo, Checkout, Caixa):
  entram na spec do módulo (anexo A, informativo).
- `locations` (unidades do estúdio): decisão na spec do módulo que a usar primeiro.
- Tabelas fora do núcleo (fidelidade, marketing, estoque, contas a pagar, vale-presente, planos e módulos da
  plataforma, administradores, cobrança por link, páginas públicas, PIN do modo estúdio, preferências, `audit_logs`).
- Cifra da ficha de saúde (spec própria); banco de produção e publicação; telas e `src/server`.
- Auditoria da porta 6 e cópia diária (E5·3): o Arquiteto indica no plano onde entram.

## 9. Dependências
- Item 2 da fila (CI, gitleaks, app vazio): sem CI não há quem aplique a migration nem prove o isolamento.
- PR #2 (`docs/produto-modulos`), onde está gravada a E22·B.

## 10. Dúvidas ao dono (máx. 3)
**E24·1 · Região do banco existente** (dados na UE, E5·1)
- **Como ver:** abra https://supabase.com/dashboard/project/qjcabltvchmzmpigiyrv/settings/general e olhe o campo
  "Region". Responda só a região, sem chave.
- **E24·1·A:** está na UE → é o banco de desenvolvimento do crm-citas.
- **E24·1·B:** fora da UE → cria-se um projeto novo na UE para desenvolvimento; o existente fica só para consulta.
- **Recomendo:** A se for UE; senão B (E5·1). Desfaz-se trocando o endereço do banco nos cofres.

**E24·2 · O que acontece com o esquema antigo no banco existente** (acesso, ambiente)
- Hoje o projeto existente tem as tabelas do antigo e dados fictícios; o esquema novo é diferente.
- **E24·2·A:** o crm-citas assume o projeto: a CI, depois da "Aprovação do merge", limpa o esquema antigo e os dados
  fictícios e aplica o novo; o app antigo deixa de funcionar nesse banco.
- **E24·2·B:** o existente fica intocado para o antigo; o crm-citas usa um projeto novo de desenvolvimento na UE.
- **Recomendo A:** os dados são fictícios (fala do dono) e um projeto só evita custo e confusão.
  **Desfaz-se assim:** o esquema antigo se recria pelas migrations do antigo, mas **os dados fictícios não voltam**.

**E24·3 · Moeda do estúdio** (dinheiro; RF-09)
- Todo preço, comanda e caixa do estúdio usa a moeda dele; a regra de troca define o que acontece com os valores já gravados.
- **E24·3·A:** escolhida no cadastro e fixa depois do primeiro serviço com preço (trocar exige suporte); casas
  decimais pela ISO 4217 (EUR e BRL: 2).
- **E24·3·B:** a dona pode trocar quando quiser; os preços não são convertidos.
- **E24·3·C:** uma moeda só para toda a plataforma (EUR).
- **Recomendo A:** evita valores gravados com a moeda trocada; casas decimais pela norma ISO 4217.
  **Desfaz-se assim:** antes do primeiro preço, troca-se livremente; depois, só pelo suporte.

## 11. Assumptions (decisões técnicas do papel, à vista na aprovação)
1. Uma migration por tabela, com data e hora no nome, na pasta de migrations do Supabase em `supabase/` (caminho exato após ler a documentação oficial).
2. A ferramenta do teste de isolamento é escolhida pelo Arquiteto no plano, depois de lida a documentação oficial.
3. Os ADRs seguem a numeração de `docs/adr/` (este item: ADR 0005).

## Anexo A · Inventário do antigo para as specs dos módulos (informativo, nada decidido)
Lido em `crm-agenda/supabase/migrations/` (177 arquivos, só leitura, E22·B), pelos comandos `create table` e
comentários; mudanças posteriores (`alter table`) não foram analisadas. A saída de cada tabela é decidida na spec do
módulo, pela RG-02.

| Módulo | Tabela (antigo) | Para que serve no antigo |
|---|---|---|
| Agenda | `staff_members`, `staff_shifts` | profissionais e horário de trabalho por dia da semana |
| | `time_blocks`, `time_block_types` | bloqueios de horário e seus tipos |
| | `resources`, `agenda_waitlist` | salas e equipamentos; fila de espera |
| Agendamento | `appointments`, `appointment_items`, `appointment_status_history` | agendamento, itens e histórico de status |
| | `appointment_counters` | último número de agendamento por estúdio |
| | `appointment_deposits` | sinal pago no agendamento (dinheiro) |
| Clientes | `clients`, `client_notes` | a cliente e suas notas |
| | `client_balance_entries` | saldo da cliente, lançamento a lançamento (dinheiro) |
| | `client_entitlements`, `client_entitlement_entries` | sessões compradas em pacote ou plano e seu consumo |
| Formulários | `anamnese_templates`, `anamnese_events`, `anamnese_gate_overrides` | modelos de ficha; envio e abertura do link; comanda fechada sem avaliação |
| | `anamneses`, `anamnese_answer_versions` | ficha respondida e correções (dado de saúde): **adiada**, só com cifra (RG-06) |
| Catálogo | `service_categories`, `services`, `products` | categorias, serviços, produtos |
| | `staff_services`, `service_staff` | quem faz cada serviço (duas tabelas para o mesmo fim) |
| | `service_packages`, `service_package_items`, `package_services` | pacotes de sessões (duas tabelas de itens) |
| | `service_bundles`, `service_bundle_items` | combos no mesmo atendimento |
| Checkout | `sales`, `sale_items`, `sale_payments` | comanda, itens e pagamentos |
| | `sale_refunds`, `sale_partial_refunds`, `sale_counters` | estornos, devoluções parciais, numeração |
| | `checkout_requests` | trava contra fechamento duplicado |
| Caixa | `cash_sessions`, `cash_movements`, `transactions` | caixa do dia, sangria e suprimento, lançamentos |

**Achados (indícios, não verificados a fundo):** `staff_services`, `package_services` e `service_package_items`
nascem sem `org_id`; `anamneses.answers` guarda respostas de saúde sem cifra aparente; várias tabelas são criadas em
duas migrations; há tabelas do núcleo ligadas a tabelas de fora (ex.: `appointment_deposits` → `transactions`).
