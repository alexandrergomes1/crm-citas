# Avaliação do antigo · Regras do banco

- **Escrito por:** Engenheiro de dados · **Norma:** boas práticas oficiais do Postgres e do Supabase; OWASP ASVS 4.0.3 V4
- **Pedido do dono (28/11/2026):** ler as regras do banco do `crm-agenda` e ver o que soma ao novo, sem tomar o antigo
  como verdade (`docs/decisoes/2026-11-27-fundacao.md`, linha "Pedido (regras do banco do antigo)").
- **Situação:** só leitura das 177 migrations e dos testes (os seeds não foram lidos). Nada copiado, nenhum SQL trazido.
  Não foi achado segredo nem dado real. Cada "aproveitar" volta ao dono para autorizar item por item
  (`AGENTS.md` §3 regra 4); depois, o papel da área reescreve, com ADR e revisão de outro papel (E16·1).

**Conclusão:** o novo já cobre melhor a maior parte das travas do antigo. Os ganhos reais estão na base de acesso
(membros), nos testes de estrutura e em regras de specs futuras.

| # | Regra (a ideia) | Onde no antigo | Spec nova | Saída | Motivo e norma |
|---|---|---|---|---|---|
| 1 | O estúdio nunca fica sem uma dona ativa (rebaixar, desativar ou apagar a última é recusado, com trava contra corrida) | `20261028210000_access_modules_platform.sql` | Base (membros) | **aproveitar** | Hoje a dona pode se rebaixar ou se apagar e o estúdio fica sem dona; nenhuma branch cobre. ASVS V4.1 |
| 2 | Ninguém muda o próprio papel nem se dá papel | mesmo | Base (membros) | **aproveitar** | ASVS V4.1.3; prepara os perfis configuráveis |
| 3 | Papel não troca de pessoa nem de estúdio | mesmo | Base | já coberto melhor | o novo só libera `papel` e `ativo` |
| 4 | Papel vazio recusado | `20261029060000_null_role_guard.sql` | Base | já coberto | vira item de revisão dos gatilhos novos |
| 5 | Corrigir função por busca e troca de texto na migration | `20261029060000`, `20261029060100` | — | descartar | frágil e não reproduzível |
| 6 | Teste de estrutura das políticas (nenhuma "para tudo", nenhuma que libere tudo, nenhuma sem login; permissivas se somam) | `20261029190000`, `tests/10_security_checks.sql` | Base (teste 010) | **aproveitar** | o furo do antigo nasceu de políticas que se somavam (Supabase RLS) |
| 7 | Toda chave estrangeira com índice, inclusive compostas | `20261029140000`, `20261029310000` | Base (teste 010) | **aproveitar** | alerta 0001 do verificador do Supabase |
| 8 | Regra nova em tabela com dados: criar sem conferir, conferir depois | `20261114060300/060400`, `20261114030200` | Guia de migrations | **aproveitar** | não trava a tabela em produção (doc. do ALTER TABLE) |
| 9 | Lista do que a API pode gravar no registro | `20261029280000` | Base | já coberto melhor | no novo só gatilho grava |
| 10 | Tirar de todos a execução das funções de gatilho | `20261030500000` | Base | já coberto | |
| 11 | Guardas que só valem para a API | `20261029220000`, `20261030300000` | — | descartar | regra vaza para tarefas internas |
| 12 | Bandeira na sessão que abre exceção na ficha assinada | `20261030300000` | Formulários | descartar | porta para contornar a imutabilidade |
| 13 | Imutabilidade pela linha inteira, menos as colunas liberadas | `20260614172305` | Caixa, Checkout | **aproveitar** | coluna nova já nasce protegida. ASVS V11.1 |
| 14 | Status em texto com acento | `20261029260000`, `20261029010000` | — | descartar | gerou erros; o novo usa códigos |
| 15 | Dinheiro em `numeric` com arredondamento | `20261029100000` | Catálogo, Checkout, Caixa | já coberto melhor | o novo usa centavos inteiros |
| 16 | Lista fechada de status; fim depois do início | `20261029260000` | Agenda, Agendamento | já coberto | |
| 17 | Conflito de horário só dentro da função, com "forçar" | `20260614_002`, `20261029270000` | Agendamento | já coberto melhor | o novo usa exclusão GiST no banco |
| 18 | Expediente único por profissional e dia | `20260609_004` | Agenda (depois) | descartar a forma | impede turno partido |
| 19 | Ligação só dentro do mesmo estúdio | `20261029210000` | todos | já coberto | |
| 20 | Nome de pessoa copiado na linha | `20260614_006`, `20261031600000` | — | descartar | dado pessoal duplicado (RGPD art. 5(1)(c)) |
| 21 | Funções que recebem o estúdio do pedido | `20261114020100` e outras | — | descartar | contraria a RF-03 (estúdio da sessão) |
| 22 | Um caixa aberto por estúdio; caixa do lançamento posto pelo gatilho | `20261031600000` | Caixa | já coberto | |
| 23 | Ao abrir caixa, puxar lançamentos sem caixa | `20261031600000` | Caixa | descartar | muda o passado |
| 24 | Caixa fechado exige data de fechamento | `20261031600000` | Caixa | já coberto melhor | |
| 25 | Estorno é lançamento novo de saída, valor positivo; nunca editar | `20261029290000` | Checkout (estorno), Caixa | **aproveitar** | registro histórico; ASVS V11.1 |
| 26 | Devoluções parciais somam no máximo o pago; mesma trava da conta | `20261031200000`, `20261030130000` | Checkout (estorno) | **aproveitar** | impede devolver duas vezes |
| 27 | Pedido repetido com outro valor é recusado | `20261029090000`, `20261029100000` | Checkout, Caixa | já coberto | |
| 28 | Saldo e pontos só pelo extrato que só acrescenta; vale entre 0 e o inicial | `20261029220000`, `20260616102418`, `20261114080000` | Futuro (saldo, pacotes, vale) | **aproveitar** | razão contábil |
| 29 | Mesclar duplicados de uma vez, travando na mesma ordem | `20261030300000` | Clientes (futuro) | **aproveitar** (só quando vier a mesclagem) | com a E28·1·B (telefone repetido não salva) há menos duplicadas, mas elas podem existir por telefone diferente. Correção do orquestrador: o relatório supunha E28·1·A |
| 30 | Ordem fixa de travas em operação com duas linhas | `20261030300000` | Guia; Agendamento (remarcar) | **aproveitar** | evita travamento mútuo (doc. do Postgres) |
| 31 | Quem e quando do consentimento gravados pelo banco; marketing só com consentimento | `20261030300000`, `20261114110000` | Clientes, Marketing (futuro) | **aproveitar** a 1ª parte | RGPD art. 7(1) |
| 32 | Cliente bloqueada para agendar | `20260613_004` | Clientes | descartar (v1) | regra de produto; só se o dono pedir |
| 33 | Cancelar série cancela só datas futuras abertas | `20261029090000` | Agendamento (recorrência, futuro) | **aproveitar** | preserva o histórico |
| 34 | Link público só como hash, com validade | `20261114100000`, `20261029160000` | Formulários | já coberto | |
| 35 | IP da assinatura com final apagado | `20261030400100` | Formulários | já coberto melhor | o novo não grava IP |
| 36 | Fotos em área privada por estúdio, com limite. Defeito: qualquer membro lê foto de saúde e o estúdio vem do caminho | `20260613_012` | Formulários (assinatura E29·3·B, fotos depois) | **aproveitar a ideia, corrigida** | estúdio da sessão, papel e cifra (E5·2; ASVS V12) |
| 37 | Configurações do estúdio em `jsonb` livre | `20261029200000` | Base | já coberto melhor | |
| 38 | Número sequencial por estúdio | `20261030230000`, `20261030100000` | Agendamento, Checkout | descartar (v1) | guardar a ideia se vier documento fiscal |
| 39 | Teste de "uma ligação por par de tabelas" | `20261029320000` | — | descartar | serve à leitura pelo navegador, que o novo proíbe |
| 40 | Visões de leitura iguais às tabelas | `20261114130000` | — | descartar | duplica o esquema |

## Resumo
- 40 regras: **16 com ideia para aproveitar**, 15 já cobertas pelo novo (8 melhor), 9 para descartar.
- Maiores ganhos: #1 e #2 (falha real da base de hoje), #6 (teste das políticas), #7 (índices), #25 e #26 (estorno), #13.
- Achado do novo, não do antigo: uma pessoa com papel em dois estúdios pode ser marcada no mesmo horário nos dois
  (a exclusão do Agendamento é por estúdio). Fica para o Analista de requisitos.

## Não verificado
Nenhum teste rodado nem banco subido; migrations do antigo lidas por cabeçalhos, comentários e trechos, não linha a
linha; ADRs 0007, 0009, 0011, 0013 e 0017 não abertos; a falha da última dona foi deduzida das políticas, não provada.
