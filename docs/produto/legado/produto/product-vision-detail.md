# KA Beauty OS — Visão Detalhada do Produto (requisitos do dono)

> Captura fiel das diretrizes do dono (2026-06-11) para não se perderem e evitar
> repetição. Complementa `scope-master.md` (matriz/status). Espelho: **Fresha**.
> Cada item vira épico no backlog.

## 1. Crédito/débito do cliente (refinamento)
- Abatimento de saldo positivo no checkout é **opcional** (toggle) — exibir saldo, cliente **pode manter crédito**.
- Aviso **não impeditivo** de saldo em aberto: na comanda e ao agendar.
- Ficha do cliente: exibir crédito **ou** débito.
- **Identificar a origem** de cada movimento: comanda nº, pagamento antecipado, pagamento a mais, compra de cartão-presente. → exige **ledger** `client_balance_entries` (cliente, tipo, valor, origem, ref_id, data).
- Status: toggle de crédito ✅; aviso na comanda e ao agendar ✅; falta consolidar ledger + origem.

## 2. Anamnese (visão completa — formulário rico)
- Ficha **vinculada a um serviço** (criar por tipo de procedimento, conforme necessidade).
- Estrutura flexível/modular/bonita: **cabeçalho com dados**, blocos de **texto informativo**, **perguntas** (resposta do cliente), **assinatura**, **ficha de consentimento**.
- Envio **antes** ou **durante** o atendimento.
- **Ficha do profissional** vinculada à ficha do cliente: anotações do atendimento, salvas **por atendimento**, exibíveis no cadastro do cliente.
- Decisão UX: vincular template↔serviço pela **aba do serviço** ou pela **anamnese** (escolher o melhor fluxo).
- Status: builder com texto informativo ✅, vínculo a serviço ✅ e viewer/notas
  profissionais ✅; faltam cabeçalhos/seções, múltipla seleção explícita,
  ficha profissional inequivocamente por atendimento e pendência auditável.

## 3. Comanda / Ficha do cliente (observações)
- Observações importantes fixas: **alergias** e detalhes que a profissional precisa saber.
- Opção de **obs fixa** que sempre aparece nas comandas abertas.
- Comanda mais **clean**: campo de obs **não fica visível vazio** — usar menu "Adicionar observação". Mostrar só o que importa.

## 4. Agenda robusta
- **Bloqueio de horário** (compromisso), com **recorrência** opcional, por profissional.
- Controle de **horário de agenda por profissional**.
- Visões: **dia / 3 dias / semana / mês** + **controle de zoom**.
- Exibir **um / vários / todos** os profissionais. **Filtros**.
- **Status coerentes**: Agendado, Confirmado (cliente confirmou presença), Pago (≠ concluído), Ausência, Cancelar (**exclui** o atendimento).
- **Análise de integração de calendário** (ver seção Análises).
- Status: views dia/3 dias/semana/mês + zoom ✅; filtro multi-profissional ✅;
  bloqueio único/semanal + remoção de ocorrência ✅; criação/edição/cancelamento
  de recorrência transacionais ✅; faltam intervalo/data final, escopo "esta e
  futuras", atividade e filtros operacionais completos.

## 5. Ações rápidas (print Fresha) — avaliar
Do print: Adicionar nota · Adicionar formulário · Ver atividade do agendamento · Definir como recorrente · Adicionar ao agendamento de grupo · Nova reserva · Remarcar · Ausência · Cancelar.
- **Implementar**: Adicionar nota, Adicionar formulário (anamnese), Remarcar, Ausência, Cancelar (já temos vários). **Avaliar**: recorrente, agendamento de grupo, ver atividade (timeline).

## 6. Ações do cliente na comanda (print Fresha) — avaliar
Do print: Remover cliente · Mensagens · Adicionar alerta de equipe · Adicionar alergia · Cadastrar teste de contato · Adicionar tag · Editar dados · Bloquear cliente · Excluir cliente.
- **Implementar**: Adicionar alerta/alergia (liga ao item 3), tag, editar dados. **Avaliar**: mensagens (liga a marketing), bloquear cliente.

## 7. Relatórios — decisão de arquitetura
**Recomendação:** híbrido. Filtros + **exportação CSV por tela** (financeiro, clientes, agenda, vendas) desde já, porque o dado já está na tela; **+** uma tela "Relatórios" só para os consolidados que cruzam módulos (receita por profissional/serviço/método/período, retenção, no-show). Não duplicar o que a tela já mostra.

## 8. Módulo de serviços (print Fresha) — avaliar
Do print "Editar serviço": Informações básicas, **Locais**, **Colaboradores** (profissionais permitidos), **Recursos** (sala/equipamento), **Adicionais de serviço**, Agendamento online, Imagens do portfólio, **Formulários** (anamnese!), **Comissões**, Configurações. **Tipo de preço: Gratuito / De (a partir) / Fixo**. **Tipo de tratamento** (marketplace).
- **Implementar (prioritário)**: tipo de preço (gratuito/de/fixo), colaboradores permitidos, formulários (vínculo anamnese), comissões. **Depois**: locais, recursos, adicionais, imagens, agendamento online.

## 9. Pagamento antecipado de reserva (planejamento — alta taxa de remarcação)
Objetivo: cobrar sinal na reserva; abater no checkout (cobrar só a diferença).
- **Conformidade**: o provedor deve operar legalmente na Espanha/UE, registrar
  integralmente os pagamentos e atender às obrigações fiscais e de reporte.
- Fluxo: **link de reserva** → cliente paga (UX intuitiva) → **confirmação automática** ao sistema → status **"reserva paga"** → valor já consta na comanda → checkout cobra só a diferença.
- Avaliar adquirência física e online por confiabilidade de API/webhook,
  reconciliação, custos, segurança e disponibilidade geográfica.
- **Análise** (ver seção). Requer validação fiscal/legal antes da integração.

## 10. Catálogo avançado / Estoque / Compras
- **Planos de assinatura / packs de sessões** (ex.: pack 3 sessões microagulhamento).
- **Pedidos de produtos para estoque**; **fornecedores por produto**.
- **Periodicidade de reposição**: sistema controla, ou usuário informa ciclo/tempo de cobertura e **sistema calcula**.
- **Pedidos de compra**.

## 11. Fidelidade (estratégia de retenção)
- Por **quantidade de procedimentos** OU **pontuação por procedimento** OU outra ideia de mercado.
- **Parâmetros configuráveis**; cálculo **automático a cada atendimento**; exibir **saldo na ficha** do cliente.
- Definir o que o cliente ganha / pode trocar (recompensas).

## 12. Marketing (mensageria)
- Tipos: agendamento efetuado, lembrete (timing configurável em **horas/dias**), agradecimento pós-atendimento, pedido de avaliação, remarketing de inativos (X tempo sem comparecer), campanha por **público-alvo**.
- **Fila de envio** para evitar block.
- Lembrete para reagendar, aniversário, recompensar fiéis, reconquistar inativos.

## 13. Avaliações (Google) — estratégia
- Integração com Google para centralizar reviews.
- **Nem todo cliente** deve receber pedido (evitar má experiência pública).
- No checkout: **habilitar envio** (checkbox) e/ou **sistema pergunta** se quer enviar.
- Na criação do tipo de msg: escolher **momento** (ao finalizar comanda / automático) e **gatilho** (pergunta adicional, checkbox, ambos).

## 14. Vale-presente / Ofertas / Cupons (finalidades distintas)
- **Vender vale-presente**.
- **Oferta** (ex.: parceria influencer = 100% desconto na comanda, controlado — evita lançar desconto solto sem motivo).
- **Cupom**: vinculável a um serviço, com/sem código, para vale-presente ou não, **validade, nome, descrição**.
- Comanda: opção de **desconto OU vincular cupom** (com rastreabilidade do porquê).

## 15. Navegação nos sistemas (legado + atual)
- Dono quer navegar nos dois para mapear mais recursos. Ação: orientar como subir o legado (`ka-beauty`, `pnpm dev`) e o atual; documentar URLs. (Ver Próximas ações.)

## 16. Bugs reportados
- ✅ **Checkout "erro de UUID"**: corrigido em duas frentes: campos opcionais
  vazios viram `null` com `optionalUuid`, e UUIDs válidos para PostgreSQL não
  dependem dos bits RFC exigidos por `z.string().uuid()`.
- Serviço/produto/cliente/agenda: actions agora validam organização, papel,
  UUIDs e JSON antes da escrita. Operações compostas ainda precisam das
  transações descritas em `docs/specs/22-operational-integrity-and-audit.md`.
- Novos agendamentos agora exigem cliente cadastrado da mesma organização;
  registros históricos sem cliente continuam liquidáveis.

---

## Análises pedidas

### A. Integração de calendário (item 4)
- **Google Calendar** (API, OAuth) — melhor custo/benefício: 2 vias, grátis, ubíquo. Recomendado como 1ª integração (sync de bloqueios e atendimentos por profissional).
- **Cal.com** (open-source, self-host) — flexível, bom para reserva pública; pode substituir parte do booking.
- **Calendly** — fechado, foco em reserva externa; menos aderente (já teremos booking próprio).
- **Recomendação**: agenda própria robusta primeiro; depois **Google Calendar 2-way sync por profissional** (cada profissional conecta sua conta). Cal.com como referência de UX de disponibilidade.

### B. Pagamento antecipado / IBAN não-ES (item 9)
- Avaliar provedores licenciados para operar na Espanha/UE com base em
  disponibilidade, custos, API, webhook, reconciliação e suporte.
- **Modelo recomendado**: link de reserva com **depósito** via provedor de pagamento (não cartão direto na clínica) → webhook de confirmação → status "reserva paga" → entra como pré-pagamento na comanda.
- O sistema registra integralmente sinal, pagamento, estorno e receita; não deve
  ser desenhado para evitar reporte fiscal.
- Não implementar antes de validação fiscal e contábil.

### C. Relatórios (item 7) — ver seção 7 acima (híbrido).

---

## Auditoria dos anexos de 2026-06-12

O mapeamento inicial dos itens 5, 6 e 8 registrou os nomes das ações, mas não
definiu contratos, dependências, prioridade e critérios de aceite. A cobertura
completa foi consolidada em:

- `docs/specs/24-agenda-fresha-parity-handoff.md`;
- `docs/specs/08-packages-memberships.md`;
- `docs/roadmap.md`.

Principais correções:

- recorrência de bloqueio não equivale a recorrência de atendimento;
- editar uma série existente não equivale a criar recorrência;
- o print de "seleção/pack" representa bundle de serviços no mesmo atendimento,
  não pacote de sessões;
- atividade exige escrita em `audit_logs`, não apenas uma nova tela;
- remover cliente do agendamento, bloquear booking e excluir cadastro são ações
  distintas;
- `Pagar agora`, sinal e checkout precisam de semânticas separadas;
- ações visuais não podem aparecer antes de backend e tratamento de erro.

## Correção de conformidade do item 9

Esta seção substitui qualquer orientação anterior sobre "baixo/zero reporte",
IBAN estrangeiro usado para ocultação ou redução deliberada de reporte fiscal.

- O produto deve registrar integralmente pagamentos, sinais, estornos e receita.
- A escolha de banco, IBAN, adquirente ou fintech deve seguir assessoria fiscal e
  jurídica na Espanha/União Europeia.
- Não é requisito técnico nem comercial evitar reporte à Hacienda.
- O critério técnico será: API/webhook confiável, idempotência, reconciliação,
  segurança, custos, disponibilidade geográfica e conformidade.
