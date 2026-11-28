# ADR 0010 · Agendamento: gravação numa transação, hora local no fuso, "Desfazer", tetos e reuso entre módulos

- **Status:** Proposto · decisões técnicas (`AGENTS.md` §5) · 28/11/2026. Vale quando a spec
  `specs/20261128-020500-agendamento/spec.md` for aprovada pelo dono.
- **Autor:** Arquiteto de software · **Norma:** modelo C4 e ADR; Clean Architecture; OWASP ASVS 4.0.3 V4.1 e V11.1;
  `ARCHITECTURE.md` §3 a §5 e §11 · **Revisão:** pendente (Revisor de código; D1 e D3 também Engenheiro de dados)
- **Aviso ao dono:** em uma linha, junto do pedido de aprovação da spec (`AGENTS.md` §3 regra 3).
- **Detalhe:** `specs/20261128-020500-agendamento/plan.md` §4.4, §5 e §6. Decisões de banco (tabelas do antigo, forma da
  garantia de conflito): ADR 0009, do Engenheiro de dados.

## Contexto
O Agendamento é o primeiro módulo que grava várias linhas numa ação (agendamento, itens, histórico), o primeiro com
máquina de status com "Desfazer" e o primeiro cujo horário vem de data e hora local escolhidas pela pessoa. Ele usa
peças da Agenda, de Clientes e do Catálogo, construídos em paralelo, e a camada de serviço da spec "Entrar e camada de
serviço" (E36·A). O `AGENTS.md` §3 regra 6 manda reusar antes de criar.

## Decisões

| # | Decisão | Motivo e norma |
|---|---|---|
| D1 | Cada ação que grava é **uma transação** com a sessão da pessoa (exigido do contrato da spec Entrar); as regras que dependem de outras linhas (transição, desfazer, duração do Catálogo, fim coerente, histórico, conflito com bloqueio) ficam em gatilhos do banco; **nenhuma função nova executável por `authenticated`** | ação atômica (ASVS V11.1.6; RNF-02); o banco é a última trava mesmo se o servidor errar (defesa em profundidade, ASVS V4.1.3); sem função chamável, a superfície não cresce e a lista do teste `010_` do item 3 não muda. Alternativa descartada: função de gravação `security definer` chamada pelo servidor, que pede esquema exposto e entra na lista do `010_` |
| D2 | Data e hora local → instante pela regra "compatível": hora que não existe (início do horário de verão) anda para a frente o tamanho do salto; hora que se repete (fim do horário de verão) fica com a primeira. Duração em minutos corridos (fim = início + soma). Só `Intl`, sobre `src/domain/agenda/dia.ts` | é a regra padrão do `Temporal` (`disambiguation: "compatible"`) e a do iCalendar (RFC 5545 §3.3.5; texto não relido nesta etapa), conhecida e testável; o `Temporal` não é usado pelo mesmo motivo do ADR 0006 · D2; minutos corridos são o tempo real do atendimento. A conferência (etapa 4) mostra o resultado à pessoa. Testado em Lisboa e Nova York nos dias de troca (CA-03) |
| D3 | "Desfazer" = a troca inversa exata da **última** troca de status, feita pela **mesma pessoa**, desde que nada tenha mudado depois; nunca sai de Cancelado ou Ausência (esses pedem a janelinha). Conferido no domínio, no servidor e no gatilho do banco pelo histórico; sem prazo no servidor até o `DESIGN.md` definir a duração do aviso | RF-08 ("só volta ao status imediatamente anterior"); o histórico já existe (RF-09), então não há estado extra; outra pessoa não desfaz a troca alheia (ASVS V4.1). Concluído é final para a troca comum, mas o desfazer da conclusão errada é permitido (Assumption 2 da spec) |
| D4 | Tetos: até **10 serviços** e **24 h** por agendamento; idas ao banco por ação: criar ≤ 3 (durações do Catálogo, ocupados da profissional, transação), remarcar ≤ 3, trocar ou desfazer status ≤ 2, ver o painel ≤ 2; a leitura do dia da Agenda passa de 3 para **4** idas (ADR 0006 · D3, como lá previsto), dentro do mesmo teto de 500 itens | `ARCHITECTURE.md` §5 e §11 (limite de idas por tela; um estúdio não atrapalha os outros); limite de tamanho de entrada (ASVS V11.1.4); provado por teste do servidor que conta as idas |
| D5 | Reuso entre módulos só por servidor e domínio, nunca pelos dados do outro: conflito e dia do estúdio pela regra de `src/domain/agenda/` (uma regra só, RF-06); busca e cadastro rápido de cliente pelas ações de `src/server/clientes`; serviços ativos pela leitura do Catálogo em `src/server/catalogo`; profissionais pelas colunas da Agenda | `AGENTS.md` §3 regra 6; Clean Architecture (cada módulo é dono dos seus dados); "não há segunda regra" (spec RF-06). Se a regra da Agenda virar geral, muda de pasta num ADR novo (ADR 0006, Consequências) |
| D6 | RF-17 do Checkout: o domínio recebe "tem checkout fechado" por parâmetro; `src/data/agendamento/checkout.ts` devolve "não" até a spec do Checkout trocar esse arquivo pela consulta real e pôr a trava no banco (gatilho na migration dela, que é dona da tabela) | a tabela do checkout ainda não existe; um ponto de encaixe só, sem chave de liga e desliga; a trava fica no banco quando houver o que travar |
| D7 | Na URL só o id do agendamento (`/agenda?agendamento=<uuid>`) e a rota `/agendar`; cliente buscada, serviços e etapa ficam na memória da tela; a busca vai no corpo do pedido | RNF-04 e `ARCHITECTURE.md` §7 (nenhum dado pessoal em URL); id não é dado pessoal |
| D8 | Textos nas chaves `agendamento.*` dos arquivos de idioma da Agenda (`src/app/i18n/`, ADR 0006 · D1); nenhuma estrutura nova | RNF-05; reuso. O plano de Clientes usa outra pasta (`src/app/paginas/clientes/textos/`): divergência levada ao Gerente de projeto para um só molde no núcleo |

## Consequências
- A spec Entrar precisa oferecer transação por ação; se não oferecer, o plano do Agendamento volta à 5b (D1).
- O Checkout troca `src/data/agendamento/checkout.ts` e acrescenta a trava do RF-17 no banco (D6).
- A Agenda passa a ter 4 idas na leitura do dia (D4); o ADR 0006 · D3 fica atualizado por este.
- Para desfazer qualquer linha: ADR novo que a substitui, com o motivo.
