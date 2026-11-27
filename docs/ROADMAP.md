# Plano: fases e módulos até o lançamento

Uma página. O que fazer agora: `docs/BACKLOG.md`. O detalhe de cada módulo: `docs/produto/modulos/`.

## Fases
| Fase | O que é | Situação |
|---|---|---|
| F0 Fundação | Repositório novo: regras, travas, Spec Kit, app mínimo, banco copiado, CI (item 1) | **em andamento** |
| F1 Design system | `DESIGN.md` 6ª edição no código, página "Peças" (item 2) | não começada |
| F2 Porte no design novo | Um módulo por vez do crm-agenda, por spec própria (itens 3 a 21) | não começada |
| F3 Telas do lançamento | O que nunca foi feito: reserva online, idiomas, motor de mensagens, importação do Fresha | não começada |
| F4 Virada | Ligar este repositório ao banco real e à publicação; portão de privacidade (RGPD) antes | sem data; só com a ordem do dono |
| F5 Faxina | Arquivar o crm-agenda e desligar o que ele publica, depois da virada | não começada |

## Módulos
| Módulo | Arquivo | No crm-agenda | Aqui |
|---|---|---|---|
| Agenda · Agendamento | `age-agenda.md` · `agd-agendamento.md` | portado | itens 3 e 4 |
| Clientes · Anamnese · Catálogo | `cli-clientes.md` · `ana-anamnese.md` · `cat-catalogo.md` | portado | itens 5 a 7 |
| Comanda · Financeiro · Caixa · Cobranças | `com-comanda.md` · `fin-financeiro.md` · `cai-caixa.md` · `cob-cobrancas.md` | portado | itens 8 a 11 |
| Estoque e compras | `est-estoque-compras.md` | só ajuste de estoque | item 12 |
| Equipe e acessos · Ajustes | `eqp-equipe-acessos.md` · `aju-ajustes.md` | portado | itens 13 e 14 |
| Mensagens · Marketing · Fidelidade | `msg-mensagens.md` · `mkt-marketing.md` · `fid-fidelidade.md` | portado em parte | itens 15 a 17 |
| SaaS e planos · Importação | `saa-saas-planos.md` · `imp-importacao.md` | tabelas · CSV de clientes | itens 18 e 19 |
| Navegação · Plataforma | `nav-navegacao.md` · `plt-plataforma.md` | portado | itens 20 e 21 |
| Design system | `ds-design-system.md` | v1, substituída pela 6ª edição | item 2 |
| Reserva online · Idiomas | `res-reserva-online.md` · `idi-idiomas.md` | não | F3 |

## O que não muda sem decisão registrada
- A stack: `docs/reference/stack.md`. O banco: o mesmo do crm-agenda (`docs/adr/0001-repositorio-novo.md`).
- Nada roda no computador do dono: o trabalho é no Claude Code na nuvem, uma tarefa por conversa.
