# AGENTS.md · src/data (acesso ao banco)

> Rascunho para o dono aprovar (E15). Escrito por: Arquiteto de software · Revisado por: (a preencher) · Norma: modelo C4, Clean Architecture, padrão agents.md, boas práticas Postgres e Supabase.
> Fonte: `AGENTS.md`, `ARCHITECTURE.md`, `SECURITY.md`, `docs/guias/processo-sdd.md`. Este arquivo não cria regra nova.

## O que mora aqui
O único lugar que fala com o banco (`ARCHITECTURE.md` §3). Só `src/server` chama esta pasta. O esquema do banco mora em `supabase/`, não aqui.

## Regras que valem aqui
- Toda leitura e gravação passa pela trava por estúdio (RLS), com a sessão da pessoa (`ARCHITECTURE.md` §4, porta 5).
- A chave de serviço, que passa por cima da trava, só em tarefas internas listadas (`ARCHITECTURE.md` §4; `SECURITY.md` §2).
- Toda tabela do estúdio tem `org_id` e trava RLS; o estúdio vem da sessão, nunca do pedido (`ARCHITECTURE.md` §4 e §5).
- Listas sempre paginadas e limite de idas ao banco por tela (`ARCHITECTURE.md` §5 e §11).
- Respostas da ficha de saúde gravadas cifradas; a chave fica fora do banco, num cofre (`ARCHITECTURE.md` §7; `SECURITY.md` §4).
- Esquema do banco, tabela ou coluna só depois de lido no código ou na documentação oficial (`AGENTS.md` §6).

## Nunca aqui
- Ser chamado direto pela tela ou pelo navegador (`ARCHITECTURE.md` §3 e §4).
- Mudar o banco fora de migration, ou aplicar mudança no banco remoto: só a CI aplica (`ARCHITECTURE.md` §3 e §8; `AGENTS.md` §1).
- Dado pessoal ou de saúde em registro de erro; segredo no código (`ARCHITECTURE.md` §7; `SECURITY.md` §2).

## Prova exigida
Código: testes de unidade e CI verde. Se a tarefa toca tabela ou trava, é do tipo Banco: teste de isolamento por estúdio e CI verde (`AGENTS.md` §9; `docs/guias/processo-sdd.md` §3).
