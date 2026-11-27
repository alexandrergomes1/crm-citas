# Catálogo: regras por serviço e serviço sem duração

Migration: `20261030301000_servicos_regras_e_sem_duracao.sql` · Testes: `supabase/tests/128_service_rules_and_no_duration.sql`.

## Regras (colunas em `services`)
- `result_months` (durabilidade, 1 a 120 meses).
- `retouch_included_days` (janela do retoque incluído, 1 a 365 dias).
- `deposit_type` (`fixed` ou `percent`) e `deposit_value` (fixo: acima de 0 e até 100.000; porcentagem: acima de 0 e até 100).
  Tipo e valor andam juntos.
- A RPC `upsert_catalog_service_atomic` ganhou o parâmetro opcional `p_rules jsonb`. Sem ele (app antigo), as regras
  do serviço ficam como estão. Chaves: `result_months`, `retouch_included_days`, `deposit_type`, `deposit_value`.
- Editor do serviço: Durabilidade ao lado do preço; linhas Retoque incluído e Exigir sinal em Regras e anamnese.

## Uso das regras
- **Sinal:** o novo agendamento soma o sinal sugerido dos serviços (`depositSuggestion`), liga "Pedir sinal" sozinho
  (a pessoa pode desligar) e leva o valor (`&valor=`) ao diálogo de registrar sinal. Valor fixo nunca passa do preço.
- **Retoque incluído:** o perfil da cliente avisa "Retoque de X vence em N dias" e se já há horário marcado; a comanda
  mostra o retoque incluído e o menu do item aplica valor zero (o checkout aceita preço 0; o desconto fica no item e
  no total, sem pacote).
- Janela de retoque: o atendimento concluído abre a janela; a visita seguinte dentro dela é o retoque e consome o direito.

## Serviço sem duração
- `duration_minutes = 0` significa "sem duração" (antes o mínimo era 15; agora vale 0 ou de 15 a 480).
- Serviço sem duração nunca é reservado online (`online_booking` é forçado a falso) e ocupa um encaixe de 15 minutos
  na agenda, no combo e na comanda (`serviceSlotMinutes`).

## Combos, Produtos e Planos
- Migrados para o Catálogo (`/catalogo/produtos`, `/catalogo/combos`, `/catalogo/planos`), sem selo "Anterior".
  Ver `catalog-02-produtos-combos-planos.md`.
