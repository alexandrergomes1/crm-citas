# ADR 0012 · Catálogo: preço sem número flutuante, "em uso" pela chave de quem usa, tetos e idiomas por módulo

- **Status:** Proposto · decisões técnicas (`AGENTS.md` §5) · 28/11/2026. Vale quando a spec
  `specs/20261128-022000-catalogo/spec.md` for aprovada pelo dono.
- **Autor:** Arquiteto de software · **Norma:** modelo C4 e ADR; Clean Architecture; ISO 4217; OWASP ASVS 4.0.3 V5.1.4
  e V11.1; `ARCHITECTURE.md` §3, §5 e §11 · **Revisão:** pendente (Revisor de código; D1 e D2 também Auditor de risco,
  por ser dinheiro; D3 também Engenheiro de dados)
- **Aviso ao dono:** em uma linha, junto do pedido de aprovação da spec (`AGENTS.md` §3 regra 3).
- **Detalhe:** `specs/20261128-022000-catalogo/plan.md` §4 a §6. Decisões de banco por tabela do antigo: ADR 0011, do
  Engenheiro de dados.

## Contexto
O Catálogo é o primeiro módulo que guarda dinheiro (preço, RN-01, RN-02) e que outros módulos usam (RF-08: Agendamento
e Checkout). A spec pede "excluir só se nunca usado" (RF-04) antes de existirem as tabelas que usam o serviço, lista
paginada com teto de idas ao banco (RNF-02, Assumption 8) e textos em três idiomas (RNF-03), com vários módulos do
núcleo sendo escritos em paralelo.

## Decisões

| # | Decisão | Motivo e norma |
|---|---|---|
| D1 | Preço em **centavos inteiros** do começo ao fim (tela → servidor → banco → Checkout). Ler o texto digitado converte para centavos por manipulação de texto, com os separadores do idioma tirados de `Intl.NumberFormat.formatToParts`; mostrar passa ao `Intl.NumberFormat` o valor como **texto decimal** montado do inteiro ("230.00"), nunca `centavos / 100`. Casas da moeda por `resolvedOptions().maximumFractionDigits`. Sem biblioteca de dinheiro | número com vírgula flutuante perde centavo (0,1 + 0,2); o `Intl` é nativo e já é a base de idiomas (ADR 0006 · D1; reuso, `AGENTS.md` §3 regra 6); as casas vêm da tabela ISO 4217 que o próprio `Intl` traz. Moeda de outro número de casas espera a L-3 do plano (dono) |
| D2 | Tipo e faixa do preço em três lugares: esquema do servidor (inteiro, faixa da E30·2), domínio (mesma regra, com teste) e `check` no banco. A recusa de fração se prova no servidor, porque o banco arredonda calado ao converter para `integer` | ASVS V5.1.4 (tipo e faixa no servidor) e V11.1 (regra de negócio no servidor); defesa em profundidade no banco; o arredondamento é conversão de atribuição do Postgres (L-4) |
| D3 | "Serviço usado" = existe linha de outro módulo que aponta para ele por chave estrangeira composta `(org_id, servico_id) → servicos (org_id, id) on delete restrict`. O Catálogo não consulta as tabelas dos outros: tenta apagar e traduz o erro `23503` em `servico_em_uso`. Até o Agendamento e o Checkout existirem, a prova usa tabela de teste no pgTAP | Clean Architecture (a dependência aponta de quem usa para o Catálogo, nunca o contrário); o banco garante sem corrida entre conferir e apagar; descarta o gatilho do antigo que conhecia as tabelas de todos (`prevent_used_catalog_item_delete`) |
| D4 | Tetos: página de **50** serviços (`limit 51`), até **200** categorias por tela (`limit 201`, aviso se passar), leitura da lista com **≤ 2 idas** ao banco (+1 se o contexto da E36·A não trouxer idioma e moeda), gravação com **≤ 3** (ler o atual para o registro, gravar, registrar). Paginação por número de página, com ordem estável (chave + `id`) | `ARCHITECTURE.md` §5 e §11; abaixo do `max_rows` 1000 da API local; 50 linhas de 64 px cabem em poucas rolagens no celular; deslocamento simples basta para centenas de serviços por estúdio. Provado por teste do servidor que conta as idas |
| D5 | Textos do módulo em `src/app/i18n/catalogo/{pt,es,en}.ts`, juntados pela base de idiomas (uma linha por módulo), em vez de um arquivo único por idioma para todos | mantém o ADR 0006 · D1 (mesma técnica, sem biblioteca) e evita que sete branches do núcleo, em paralelo, mexam nas mesmas linhas; o tipo continua acusando chave faltando. Pede à base de idiomas (E36·A ou Agenda) aceitar dicionário por módulo |
| D6 | A resposta da E30·1 e da E30·3 vira constante em `src/domain/catalogo/acesso.ts` e uma versão das políticas; sem chave de liga e desliga | mesma regra do ADR 0006 · D6 (OWASP ASVS V1.4 e V4.1: menor superfície) |

## Consequências
- O Checkout recebe preço em centavos e a moeda do estúdio (RF-08) e guarda a cópia (RF-04 de lá); a mesma técnica de
  D1 vale para ele.
- As specs do Agendamento e do Checkout precisam declarar a chave `on delete restrict` para o Catálogo (plano L-7).
- Se a base de idiomas preferir arquivo único, só a D5 muda (ADR novo); o resto não depende dela.
- Para desfazer qualquer linha: ADR novo que a substitui, com o motivo.
