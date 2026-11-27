# Orçamento de idas ao banco

Vale para toda tela e toda função de servidor, nova ou portada. Não existe "fazer agora e otimizar
depois". Pastas e arquivos citados: `docs/reference/project.md`. O que as skills de mercado ensinam sobre
consulta (laço, paginação, índice) vem de `backend-design:query-discipline`; aqui ficam só os números da casa.

## Limites
- **Abrir uma tela logada: 2 idas ao banco.** O contexto de acesso (`my_access_context`,
  memorizado por pedido) + **1 função de leitura da tela** (exemplo: `client_list_rows`).
- **Abrir uma página pública: 1 ida.**
- **Uma ação (gravar, excluir, mover): 2 idas.** O contexto de acesso + 1 gravação.
- **Arquivo guardado (foto, anexo): +1 ida**, dita no PR.

Tela que precisa de dados de várias tabelas junta tudo numa função SQL `SECURITY INVOKER` com
`search_path = ''` (a RLS continua valendo), nunca em várias consultas soltas. Ação que mexe em
várias tabelas vira uma função no banco, que também garante tudo-ou-nada.

## Proibido
- Consulta dentro de laço.
- A mesma tabela lida duas vezes no mesmo pedido.
- Buscar tudo para filtrar no código.
- `select *` em lista.

## Lista grande
Paginação no banco e índice que cubra o filtro e a ordem.

## Como se mede
Cada função de servidor nova entra no teste do orçamento (`src/data/supabase-calls.test.ts`) com o
número fixo esperado. O teste roda na CI e trava regressão **das funções listadas**; função que
ficou fora da lista não é pega (item 45 de `docs/ICEBOX.md`), por isso o `code-reviewer` confere. O PR traz a tabela antes x depois quando a função substitui outra.

## Função nova no banco
Migration nova, teste de banco e `risk-auditor` (skill `db-migrations`).

## Exceção
Só com justificativa escrita no PR (exemplo: envio de arquivo).

## Ainda não medido
Limites do Cloudflare Workers (tempo de CPU, subrequisições por pedido) e tempo limite da API do
banco. Item 30 de `docs/ICEBOX.md`.
