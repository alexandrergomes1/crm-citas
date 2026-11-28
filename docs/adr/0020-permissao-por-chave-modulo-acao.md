# ADR 0020 · Porta 3 por chave `modulo.acao` e matriz padrão no código

- **Status:** Aceito · 28/11/2026 · decisões técnicas (`AGENTS.md` §5). Entra na branch `feat/entrar-servico`, antes do
  primeiro módulo (recomendação abaixo, seguida pelo Gerente de projeto); RF-18 da spec já ajustada pelo Analista de
  requisitos (chave `modulo.acao`, matriz padrão, a mesma no servidor e no banco, personalização no item 6a).
- **Autor:** Arquiteto de software · **Norma:** modelo C4 e ADR; OWASP ASVS 4.0.3 V1.4.4 (um só mecanismo de acesso),
  V1.4.5 (acesso por função e dado, não só por papel), V4.1.1 (decidido no servidor), V4.1.3 (menor privilégio),
  V4.1.5 (falha fechada), V4.2.1 (dado de outra pessoa); RGPD art. 9 e 32; LGPD art. 11.
- **Conferência (E16·1):** a cargo do Revisor de código (contrato da porta 3, catálogo, matriz) e do Engenheiro de
  segurança (acesso, falha fechada, saúde à parte) na revisão do PR #7; a parte do banco (D7, D8), pelo Engenheiro de
  dados que não a escreveu. Pendente até essa revisão.
- **Dentro de:** ADR 0018 (D12, molde único) e ADR 0005 (T5 e T6, adiados; T7 descartado). **Substitui** o tipo
  `Permissao` do `plan.md` §4 do Entrar (lista de papéis ou função do papel).
- **Origem:** E42·A ajustada (28/11/2026): personalização só no item 6a da fila, "desde que não prejudique o
  desenvolvimento". Ideias do antigo autorizadas em E43·A (`docs/produto/avaliacao-crm-agenda/permissoes-e-pin.md`
  #1, #4 a #7, #11 a #15 e "Modelo proposto"), reescritas aqui; **nada copiado** do `crm-agenda`.
- **Aviso ao dono:** em uma linha, junto do pedido de aprovação da spec (`AGENTS.md` §3 regra 3).

## Contexto
Hoje a porta 3 (`src/server/portas/executar.ts`, `podeOPapel`) aceita `readonly Papel[]` ou `(papel) => boolean`
(`tipos.ts`, `Permissao`), e os planos dos módulos (ex.: Agenda §5.1, "a regra pura de `acesso.ts` passada como função
do papel") seguem esse molde. Com isso, a decisão "quem pode" fica espalhada em cada ação. Quando vier o item 6a
(perfis por módulo e ação, ajuste por pessoa, papéis padrão personalizáveis), cada ação de cada módulo teria de ser
reescrita, e o servidor e o banco poderiam divergir (defeito #10 do antigo: a tela liberava, o banco não seguia).

## Decisões

| # | Decisão | Motivo e norma |
|---|---|---|
| D1 | **Toda ação do modo `estudio` declara uma chave** `permissao: '<modulo>.<acao>'`, nunca papel nem função. O módulo da chave é o primeiro trecho do nome da ação (`agenda.bloqueio.criar` → `agenda.*`); o molde (`conferirDefinicao`) recusa chave fora do catálogo ou de outro módulo. `'qualquer'` continua só nos modos sem estúdio da lista fechada (ADR 0018 · D12) | ASVS V1.4.4 e V1.4.5: um mecanismo só, por função; a ação diz **o que** faz, não **quem** pode |
| D2 | **Catálogo fechado no código** (`src/domain/acesso/`), tipado (`as const`: chave errada não compila). Ações base: `ver`, `criar`, `editar`, `remover`. Sensíveis, sempre à parte da base: `ver_saude` (ficha de saúde), `estornar`, `exportar`, `gerenciar_acessos`. Uma spec de módulo só acrescenta chave sensível nova com aprovação do dono na spec (ex. a decidir no Caixa: `caixa.ver_historico`, E32·3·A). Chave fora do catálogo → `sem_permissao` | Modelo proposto 1; ideia #12 (saúde à parte: RGPD art. 9, LGPD art. 11); ASVS V4.1.5 |
| D3 | **Valor de cada célula = alcance:** `todos`, `proprios` ou ausente (= não pode). A porta 3 recusa quando não há alcance e entrega `ctx.alcance` ao trabalho. O que "próprios" quer dizer (a própria coluna, as clientes que atendeu, as fichas das próprias clientes) é regra do módulo (`src/domain/<modulo>/acesso.ts`) e da política do banco, que recebem o **alcance**, nunca o papel | As respostas E26·1·B, E26·2·A, E28·2·B e E29·2·A são "só os próprios", não sim/não; ASVS V4.2.1. Assim o 6a liga e desliga alcance sem tocar na regra do módulo |
| D4 | **Matriz padrão no código** (`src/domain/acesso/matriz.ts`), uma linha por papel × chave, só para `recepcao` e `profissional`. **A dona tem tudo** (`todos` em toda chave) por regra fixa, não por linha, e não é editável. Célula que não está na matriz = não pode. Cada spec de módulo acrescenta as próprias linhas, com a resposta do dono citada ao lado | Ideias #1 e #4; Modelo proposto 2 e 4; ASVS V4.1.3 e V4.1.5. Atende E42·A: em desenvolvimento só o dono usa, como dona, com acesso total |
| D5 | **Módulo nunca decide por papel.** `ContextoEstudio` deixa de levar `papel` ao trabalho e passa a levar `alcance` (o papel segue na sessão e no registro). Teste do molde falha se um trabalho ler o papel | Sem isso, um `if (papel === ...)` escondido sobrevive ao 6a (defeito #10 do antigo) |
| D6 | **Fonte de permissões injetada na porta 3:** `alcanceDe(sessao, chave)`, hoje lido da matriz do código. Todas as ações dependem só dela | Clean Architecture (dependência por contrato); é o ponto único que o 6a troca |
| D7 | **Mesma matriz no banco**, sem duas regras escritas à mão: a matriz do código é a fonte; o banco recebe uma cópia **gerada** dela (lista de linhas papel, chave, alcance, levada por migration de cada módulo, nunca editada no lugar depois do merge) e uma função de acesso sem parâmetro de estúdio (papel e estúdio da sessão, ADR 0005 · D2) que as políticas chamam com a chave e o alcance. Dona → tudo; chave desconhecida → nada. A forma exata (tabela em `app` ou função constante, nomes, gerador) é do Engenheiro de dados no ADR do banco | Ideia #15 ("uma fonte só"); Modelo proposto 6; ADR 0005 · D1 e D3 |
| D8 | **Teste na CI que trava se divergirem:** no job `banco`, depois das migrations no banco local, um teste compara, linha a linha, a matriz exportada do código com a cópia no banco (e dona = tudo, chave fora do catálogo = nada); diferença → vermelho. No job de unidade: toda ação do catálogo de ações tem chave do catálogo de chaves, e toda chave usada por política existe no catálogo | Ideia #15; Modelo proposto 9; ASVS V4.1.1 |
| D9 | **Lista efetiva só para a tela:** a tela pode receber as chaves que a pessoa tem para esconder botões; esconder não protege, quem decide é a porta 3 e o banco | Ideia #11; ASVS V4.1.1 |
| D10 | **Item 6a só troca a origem**: a matriz do código vira o padrão de fábrica; o banco ganha perfis (cópia inteira de um papel, sem camadas), ajuste por pessoa (uma camada, com motivo e prazo) e só as exceções; `alcanceDe` e a função do banco passam a ler a efetiva. As ações, as chaves e as regras `acesso.ts` dos módulos **não mudam**. Travas do 6a já fixadas aqui: ninguém se dá mais do que tem (inclusive ao atribuir perfil, defeito #8), ninguém mexe em si, sempre uma dona ativa, `gerenciar_acessos` e `ver_saude` só a dona concede, toda mudança com antes e depois na porta 6 | Ideias #1, #5, #6, #7, #13; ideia #14 (estúdio da sessão, nunca do pedido) já vale; ideia #3 (3 camadas) segue descartada (ADR 0005 · T7) |

## Matriz padrão inicial (das respostas do dono; a dona tem tudo e não aparece)

| Chave | Recepção | Profissional | Resposta |
|---|---|---|---|
| `agenda.ver` | todos | próprios (as outras colunas só "ocupado") | E26·1·B |
| `agenda.criar`, `agenda.editar`, `agenda.remover` | todos | próprios | E26·2·A |
| `agendamento.ver` / `.criar` / `.editar` / `.remover` | todos | próprios | E26·1·B e E26·2·A ("vale também para o Agendamento") |
| `clientes.ver` | todos | próprios (atendeu, tem marcada ou cadastrou) | E28·2·B |
| `formularios.ver` (situação da ficha) | todos | próprios | E29·2·A |
| `formularios.ver_saude` (respostas) | — | próprios | E29·2·A |
| `formularios.editar` (modelos) | — | — | E29·2·A ("dona edita modelos") |
| `catalogo.criar`, `catalogo.editar`, `catalogo.remover` | — | — | E30·1·A |
| `checkout.criar` (receber) | todos | — | E31·2·A |
| `caixa.ver`, `caixa.criar`, `caixa.editar` (operar) | todos | — | E32·3·A |
| `caixa.ver_historico` | — | — | E32·3·A ("histórico só a dona") |
| `equipe.gerenciar_acessos` | — | — | Modelo proposto 5 |

Células **sem resposta do dono** (ex.: `clientes.criar` e `.editar`, `catalogo.ver`, `checkout.estornar`, `*.exportar`,
edição de ficha pela profissional da troca do E29·3) **não entram por suposição**: até a spec do módulo trazer a
resposta, ficam ausentes (só a dona pode), e a dúvida vai ao dono na spec do módulo (`AGENTS.md` §4: acesso nunca vai
para "Assumptions").

## Custo e onde entra

**No código do Entrar (branch `feat/entrar-servico`):**
- `src/server/portas/tipos.ts`: `Permissao` vira chave do catálogo (ou `'qualquer'` fora do modo `estudio`);
  `ContextoEstudio` troca `papel` por `alcance`; `Infra` ganha a fonte `alcanceDe`.
- `src/server/portas/executar.ts`: `podeOPapel` vira consulta a `alcanceDe` (falha fechada mantida); `ctx.alcance`.
- `src/server/portas/catalogo.ts`: `conferirDefinicao` confere chave no catálogo e do mesmo módulo do nome.
- `src/server/portas/acao.ts`: exemplo do comentário e `infraReal` com a fonte da matriz.
- Testes: `src/server/portas/executar.test.ts` e `molde.test.ts` (trocar `['dona', 'recepcao']` e as funções por
  chaves; novos: chave fora do catálogo, chave de outro módulo, dona tem tudo, ausente = não, trabalho sem `papel`).
- Novos: `src/domain/acesso/chaves.ts`, `src/domain/acesso/matriz.ts` e `matriz.test.ts` (catálogo e matriz; nesta
  spec a matriz nasce **vazia de linhas de módulo**, porque o Entrar não tem ação do modo `estudio`).
- `src/server/sessao/acoes.ts`: **sem mudança** (as 5 ações usam `'qualquer'`, modos sem estúdio).
- Banco (Engenheiro de dados, ADR próprio): uma migration com a cópia vazia e a função de acesso, e o teste de
  comparação da D8 no `pnpm db:test`.
- Documentos: RF-18 da spec (feito, Analista de requisitos); `plan.md` §3.2, §4, §5a e §10 e `tasks.md` S7 e B7
  (Arquiteto, 28/11).

**Fora desta branch:** os planos de Agenda, Agendamento, Clientes, Formulários, Catálogo, Checkout e Caixa (nas
branches deles) trocam "função do papel" por chave e alcance e citam as linhas da matriz que acrescentam.

**Recomendação:** entra **nesta branch, antes do primeiro módulo**. É pequeno (4 arquivos alterados, 2 testes, 3
arquivos novos, 1 migration) porque ainda nenhuma ação do modo `estudio` existe; depois do primeiro módulo, cada ação
e cada política escrita por papel teria de ser refeita, que é o que a condição do E42·A pede para evitar.

## Consequências
- O dono, como dona, tem acesso total durante o desenvolvimento, sem configuração (E42·A).
- Módulos novos só declaram chaves e linhas; não escrevem regra de papel.
- O item 6a não reabre os módulos; reabre só a fonte da porta 3 e a função do banco.
- Para desfazer qualquer linha: ADR novo que a substitui, com o motivo.

## Riscos e não verificado
- Forma e desempenho da função de acesso no banco (chamada em toda política, `(select ...)`): não verificado; fica com
  o Engenheiro de dados.
- O nome das chaves por módulo (`agenda` e `agendamento` separados ou juntos) pode mudar com os planos dos módulos;
  a matriz acima segue os nomes das specs atuais e não foi conferida contra os planos de cada branch, só o da Agenda.
- Teste "trabalho não lê o papel" (D5): forma (tipo, lint ou teste) não verificada.
- Nenhum teste rodado; nenhum código alterado por este ADR.
