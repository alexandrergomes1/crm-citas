# ADR 0005 · Base da trava por estúdio: o que vem do antigo, tabela por tabela, e a função de acesso

- **Status:** Proposto · decisões técnicas (`AGENTS.md` §5) · 28/11/2026. Vale quando a spec
  `specs/20261128-010000-banco-ligacao/spec.md` for aprovada pelo dono.
- **Autor:** Engenheiro de dados · **Norma:** boas práticas oficiais do Postgres (CREATE POLICY, SECURITY DEFINER com
  `search_path` fixo, privilégios por coluna) e do Supabase (guia de RLS e recomendações de desempenho de RLS, linter do
  banco), RGPD art. 5(1)(c) (minimização), OWASP ASVS 4.0.3 V4.1 e V4.2 (controle de acesso).
- **Conferência (E16·1, RG-02):** pendente · Engenheiro de dados (outra instância, que não escreveu) e Auditor de risco.
  Acesso: Engenheiro de segurança.
- **Aviso ao dono:** em uma linha, junto do pedido de aprovação da spec (`AGENTS.md` §3 regra 3).
- **Detalhe:** `specs/20261128-010000-banco-ligacao/plan.md` §3 a §6.

## Contexto
A spec manda trazer do antigo (`crm-agenda`, só leitura, E22·B) apenas a base da trava: estúdio, membros, papéis e a
função de checagem, cada item com saída **copiar, reescrever, descartar ou adiada** (RG-02). Lidos só os arquivos de
migration abaixo; nenhum seed, dado ou segredo foi aberto (RG-01):
`20260601000001_foundation.sql`, `20260609_001_foundation.sql` (as duas criam as mesmas tabelas),
`20261029130000_configurable_role_permissions.sql`, `20261031300000_custom_profiles.sql`.

## Decisões por item

| # | Item do antigo | Saída | No crm-citas | Motivo e norma |
|---|---|---|---|---|
| T1 | `organizations` | **Reescrever** | `public.estudios` | Fica a ideia (inquilino com fuso, moeda e idioma). Muda: a chave chama-se `org_id` (mesmo nome em toda tabela, RG-04 e CA-03); fuso, moeda e idioma **sem valor padrão** (o antigo punha `America/Sao_Paulo`, `BRL`, `pt-BR` em tudo; RF-09 e CA-13 pedem preenchido de propósito); idioma só `pt`, `es`, `en` (ISO 639-1, CA-13); moeda no formato ISO 4217 (3 letras maiúsculas); fuso conferido contra `pg_timezone_names` (no antigo era texto livre). Saem `slug`, logo, contato, endereço, `plan`, `settings jsonb` e `active`: são de módulos futuros (portal, ajustes, planos, vida do estúdio) e não servem à trava (minimização, RGPD art. 5(1)(c)) |
| T2 | `profiles` | **Descartar** | — | Repete a chave de `user_roles` (`user_id`, `org_id`) e guarda dado pessoal (nome, telefone, foto) que a trava não usa (minimização). Achado de segurança: a política `profiles_insert_own` só confere `user_id = auth.uid()`, então qualquer pessoa com login cria linha em **qualquer** estúdio, e `profiles_update_own` deixa trocar o `org_id` da própria linha (ASVS V4.2.1). O nome da profissional entra na spec da Agenda |
| T3 | `user_roles` | **Reescrever** | `public.membros` | Vínculo pessoa × estúdio e papel numa tabela só (chave `org_id, user_id`). Papéis de 7 para 3: `dona`, `recepcao`, `profissional` (`ARCHITECTURE.md` §6; RF-06). Sai `location_id` (unidades fora de escopo, spec §8). Entra `estudio_atual` (qual estúdio vale na sessão, ver D2). Escrita só pela dona do estúdio da sessão, com privilégio por coluna (ninguém grava `org_id` de outro estúdio nem `estudio_atual` de outra pessoa) |
| T4 | Funções `auth_org_ids()` e `auth_user_role(p_org_id)` | **Reescrever** | `app.estudio_da_sessao()`, `app.papel_da_sessao()`, `app.eh_dona()` | No antigo: `SECURITY DEFINER` **sem** `search_path` fixo (o linter do Supabase marca, regra 0011; um esquema plantado sequestra a função), no esquema exposto pela API, e `auth_user_role` recebe o estúdio como parâmetro, o que a RF-03 proíbe. No novo: sem parâmetro, `set search_path = ''`, esquema `app` fora da API, execução negada a `public` e `anon`, chamada envolvida em `(select ...)` nas políticas (recomendação de desempenho de RLS do Supabase) |
| T5 | `role_default_permissions()`, `has_permission(p_org_id, p)`, `my_permissions`, `get_permission_matrix` | **Adiada** (spec de cada módulo) | — | O que cada papel pode fazer é decisão de acesso e vira dúvida ao dono na spec do módulo (RG-03). Também recebem `p_org_id` de fora (RF-03). A base entrega só `app.papel_da_sessao()` e `app.eh_dona()`, suficientes para as travas destas duas tabelas |
| T6 | `org_role_permissions` (+ `set_role_permission`, `reset_role_permissions`) | **Adiada** (spec da tela de equipe e acessos) | — | Exceções do estúdio à matriz só existem quando houver a matriz (T5) e a tela que as mostra (RF-06). As funções gravam em `audit_logs`, fora de escopo |
| T7 | `org_profiles`, `org_profile_permissions` (+ 6 funções) | **Descartar** | — | Três camadas de resolução (perfil > papel no estúdio > padrão) para um recurso que o `ARCHITECTURE.md` §6 deixa para "depois". RF-06: sem estas tabelas, não há papéis configuráveis nesta spec. Se o dono pedir, o desenho começa do zero sobre `membros` |
| T8 | `set_updated_at()` / `update_updated_at()` e gatilhos | **Descartar** | — | As tabelas novas não têm coluna de alteração; quem fez o quê é a porta 6 (auditoria, spec própria) |
| T9 | Extensões `pgcrypto` e `uuid-ossp` | **Descartar** | — | `gen_random_uuid()` é nativa do Postgres desde a 13 (o local é 17, `supabase/config.jsonc`) |
| T10 | Privilégios: o antigo confia nos privilégios padrão do Supabase (tudo para `anon` e `authenticated`) e deixa a RLS decidir | **Reescrever** | `revoke all` de `anon` e `authenticated` em cada tabela; `grant` só do necessário, por coluna | Defesa em profundidade: sem login não há nem privilégio (RF-05); o que a pessoa não pode gravar nem chega à política (ASVS V4.1.3, menor privilégio) |
| — | `locations`, `audit_logs` | Fora de escopo | — | Spec §8 (unidades; auditoria da porta 6) |

## Decisões de desenho

| # | Decisão | Motivo e norma |
|---|---|---|
| D1 | Funções da trava no esquema `app`, que **não** entra em `api.schemas` do `supabase/config.jsonc` | Guia do Supabase: funções `SECURITY DEFINER` não ficam em esquema exposto; o navegador não fala com o banco (`ARCHITECTURE.md` §4) |
| D2 | O estúdio da sessão é `membros.estudio_atual` da pessoa do login (`auth.uid()`), com no máximo um por pessoa (índice único parcial); troca só por `app.escolher_estudio(p_org_id)`, que confere vínculo ativo | RF-03: a função de checagem não tem parâmetro; o que vem no pedido (inclusive dentro do token) é ignorado. Alternativa guardada: declaração no token por gancho de acesso do Supabase Auth; não escolhida agora porque pede configurar o Auth do projeto remoto (produção e acesso, `AGENTS.md` §5) e o teste local roda sem o serviço de Auth |
| D3 | Toda política é `to authenticated` e compara `org_id = (select app.estudio_da_sessao())`; escrita também pede `(select app.eh_dona())` | Guia de RLS do Supabase (papel explícito; função envolvida em `select` para rodar uma vez por consulta) |
| D4 | Validação: `check` para idioma, moeda e papel; gatilho `before insert or update` para o fuso (consulta a `pg_timezone_names`, que um `check` não pode fazer) | Documentação do Postgres (CREATE TABLE: expressão de `check` não pode ter subconsulta) |
| D5 | Teste de isolamento em pgTAP com `supabase test db`, banco local | ADR 0002 · D10; spec §11 Assumption 2 |
| D6 | Aplicação no banco remoto de desenvolvimento só por um job da CI no `push` à `previas`, num ambiente do GitHub com aprovação do dono, construído só depois das respostas E24·1 e E24·2 | `AGENTS.md` §1 e §8; RG-05; `plan.md` §7 |

## Consequências
- Cada módulo cria as próprias permissões e políticas sobre `app.estudio_da_sessao()` e `app.papel_da_sessao()`, e
  copia o molde `supabase/moldes/isolamento_tabela_test.sql`.
- Pessoa em mais de um estúdio vê um de cada vez; a tela de troca de estúdio vai à spec que tiver essa tela.
- Ninguém com login cria ou apaga estúdio: isso é do cadastro de estúdio (`ARCHITECTURE.md` §2), por tarefa interna.
- A dona pode tirar o próprio papel de dona; a regra "sempre uma dona" é decisão de acesso e vai à spec da tela de equipe.
- Para desfazer qualquer linha: ADR novo que a substitui, com o motivo.
