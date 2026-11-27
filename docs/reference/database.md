# Banco: fatos deste projeto

O que nenhuma skill de mercado pode saber. O **método** (modelagem, RLS, índices, migration segura)
vem das skills de mercado listadas na skill `db-migrations`; este documento guarda só os fatos, e
vence quando houver conflito. Endereços e nomes dos bancos: `docs/reference/project.md`.

## Como uma migration chega ao banco
1. Arquivo novo na pasta de migrations, nome no formato de `docs/reference/project.md`. Sem `begin`/`commit` dentro (o script recusa).
2. **No PR**, a CI recria um banco vazio, roda todas as migrations em ordem e depois os testes de banco (`pnpm db:verify` faz o mesmo na máquina). Esse replay **não** embrulha cada arquivo em transação.
3. **No merge na branch de integração (e também na de produção)**, uma rotina do GitHub (`migrations-dev.yml`) aplica as migrations que faltam no banco de **desenvolvimento**, cada arquivo numa transação só. Ninguém aplica à mão.
4. **Produção:** só com autorização do dono do projeto, depois do backup do dia conferido.

Consequência: o que funciona no replay do PR pode falhar no passo 3, depois do merge. Banco vazio
também não prova nada sobre tabela com dados.

## O que a CI já trava sozinha (não gaste revisão nisso)
`supabase/tests/10_security_checks.sql` reprova o PR se houver: tabela sem RLS; tabela sem `org_id`;
política aberta (`true`); função `security definer` sem `search_path`; função `security definer`
executável por `anon`; função interna exposta; visão `internal_read` com colunas diferentes da
tabela, sem `security_barrier`, com gravação concedida, ou schema `internal_read` acessível a `anon`;
texto com acento corrompido. Outros testes travam: gravação livre no registro de auditoria
(`123_…`) e duas relações entre o mesmo par de tabelas (`126_…`, causa do erro PGRST201 na API).

**Não está travado, embora pareça:** o teste `118_tenant_composite_fks.sql` prova a chave composta
só em três relações que já existem (agendamento → cliente, venda → agendamento, lançamento →
cliente). Chave estrangeira simples numa tabela **nova** passa na CI: é conferência do `risk-auditor`.

## Nomes e estruturas da casa
- **Inquilino:** toda tabela do estúdio tem `org_id uuid not null`. Chave estrangeira **nova** entre tabelas do estúdio é composta com `org_id`, para um registro nunca apontar para outro estúdio. As antigas são compostas só em parte (agenda, vendas, lançamentos, saldos); várias continuam simples (mensagens, marketing, locais) e só mudam por item da fila.
- **Permissão na leitura:** política com `org_id in (select public.auth_orgs_with_permission('<módulo>.view'))`, uma vez por consulta.
- **Leitura entre módulos:** função `security invoker` de outro módulo lê `clients`, `sales`, `sale_items`, `sale_payments`, `services`, `products`, `service_categories`, `service_packages`, `service_bundles` e `service_bundle_items` pelas visões do schema `internal_read` (não exposto pela API) e confere a própria permissão. Coluna nova numa dessas tabelas: recriar a visão.
- **Colunas com grant:** em `services` e `products`, coluna nova precisa de `grant select (coluna) … to authenticated`; custo e comissão só saem por função.
- **Tabela gravada só por função:** sem política de escrita, `revoke` da gravação para `anon` e `authenticated`; a função é `definer` e confere login, estúdio e permissão.
- **Função:** padrão da casa é `revoke all on function … from public, anon` e depois `grant execute` só a quem usa (em geral `authenticated`).
- **Política nova:** com `to authenticated` e `(select auth.uid())`. As antigas ainda têm `auth.uid()` solto em muitos lugares; só mudam pelo item 6 da fila, com teste de isolamento.
- **Chave primária:** nas tabelas do estúdio, `uuid` com `gen_random_uuid()` (há tabelas de plataforma com chave de texto).
- **Dinheiro em coluna nova:** `numeric(12,2)`. As colunas centrais antigas (catálogo, financeiro) são `numeric(10,2)` e ficam como estão; mudar é decisão registrada.
- **Hora** em `time` ou `timestamptz`; **seeds** em UTF-8 explícito.
- **Teste de isolamento:** toda tabela ou política nova ou alterada ganha teste em `supabase/tests/` provando que o estúdio A não lê nem grava no B.
- **Enquanto prévia e produção usarem o mesmo banco:** a migration tem de funcionar com o código das duas branches (nada de apagar ou renomear coluna no mesmo PR que para de usá-la).

## Onde este projeto contraria o mercado (e a prova)
| O mercado manda | Aqui | Prova |
|---|---|---|
| `create index concurrently` em tabela com dados | **Proibido.** | `scripts/db/apply-dev.sh` aplica cada arquivo com `--single-transaction`, e `concurrently` não roda em transação. O replay do PR não pega: quebraria só depois do merge |
| Iterar no banco com `execute_sql` e gerar a migration com `db pull` | **Proibido.** Migration é escrita à mão, em arquivo. | A conexão MCP aponta para a produção (`docs/reference/project.md`); não há pasta `supabase/schemas/` |
| Rodar os advisors antes de fechar a mudança | Só depois de aplicada no banco de desenvolvimento, e hoje **sem ferramenta**: peça ao dono do projeto ou escreva "não verificado" | idem |
| Chave primária UUIDv7 ou identity | Mantém `gen_random_uuid()` | padrão das tabelas do estúdio; trocar é decisão registrada, não escolha de PR |
| Carga ou correção de dados dentro da migration | Evitar; se for inevitável, arquivo separado e dito no PR | cada arquivo é uma transação: carga grande trava a tabela |

## Não coberto ainda (itens da fila)
Direito de acesso, apagamento e portabilidade (RGPD); prazo de retenção; cifra em repouso da ficha
de anamnese; apagar um estúdio inteiro; `--single-transaction` também no replay do PR.
