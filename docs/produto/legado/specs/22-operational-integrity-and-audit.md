# Spec 22 - Integridade operacional, auditoria e performance

## Status

Em andamento. Esta spec cobre backend e qualidade; não inclui criação ou
redesenho de telas.

## Goal

Garantir que os fluxos críticos de agenda, checkout, clientes, catálogo e
financeiro sejam autorizados, validados, atômicos, auditáveis e rápidos.

## Regras obrigatórias

- Toda Server Action valida sessão, organização e papel permitido no servidor.
- IDs opcionais de `FormData` convertem string vazia para `null`.
- JSON vindo do navegador nunca usa `JSON.parse` sem captura e validação Zod.
- Nenhuma action retorna sucesso quando uma escrita dependente falhou.
- Operações com mais de uma escrita de negócio usam uma transação PostgreSQL.
- Operações financeiras, clínicas e administrativas sensíveis geram
  `audit_logs`.
- Reenvio do checkout não pode duplicar venda, pagamento, transação ou pontos.

## Entregue nesta etapa

- Autorização explícita por organização e papel nas actions de clientes,
  catálogo, equipe, configurações, financeiro, vales e anamnese.
- Autorização por slug reduzida a uma consulta relacional para organização e
  papel.
- Validação compartilhada de JSON com Zod.
- Agenda rejeita UUID e JSON inválidos antes do banco e verifica erro ao gravar
  itens.
- Checkout carrega o resumo do cliente junto do agendamento, removendo uma
  consulta sequencial.
- Resgate de vale usa comparação otimista de saldo para detectar concorrência.

## P0 - Checkout atômico

Criar uma RPC PostgreSQL única para:

1. bloquear a venda/agendamento e validar idempotência;
2. criar ou atualizar `sales`;
3. substituir `sale_items` e registrar `sale_payments`;
4. registrar `transactions`;
5. atualizar agendamento e cliente;
6. resgatar vale-presente com lock;
7. registrar ledger de saldo, pontos e `audit_logs`;
8. confirmar tudo ou desfazer tudo.

Pagamento `partial` aceita pagamentos posteriores até zerar `balance`. A
continuação é aditiva: pagamentos persistidos não podem ser reduzidos ou
trocados, e apenas o incremento atualiza caixa e saldo do cliente.

## P0 - Migrations remotas

- `time_blocks` foi verificada no Supabase remoto em 2026-06-12.
- Ledgers operacionais, `gift_card_redemptions` e `appointment_deposits` foram
  verificados no Supabase remoto em 2026-06-13.
- `set_appointment_status_atomic` esta ativa no remoto com helpers RLS
  qualificados e auditoria atomica desde 2026-06-13.
- `register_stock_entry_atomic` esta ativa no remoto e evita divergencia entre
  a quantidade do produto e o ledger `stock_entries`.
- Consolidar as duas séries de migrations existentes e definir uma ordem
  canônica sem apagar migrations históricas.

## P1 - Outras transações

- criação/edição de agendamento + itens;
- ajuste de saldo + transação/ledger;
- baixa de conta a pagar + transação;
- pacote + serviços;
- profissional + turnos.

## P1 - Privacidade

- Capturar IP e user-agent da anamnese no servidor/RPC, não do `FormData`.
- Adicionar rate limiting ao formulário público por token.
- Registrar acesso e assinatura clínica em `audit_logs`.

## Performance targets

- Autorização: `auth.getUser()` + uma consulta de acesso por request.
- Checkout: sem consulta tardia do cliente.
- Checkout atômico: uma chamada RPC para a gravação completa.
- Abertura quente das rotas operacionais abaixo de 3 segundos com Supabase
  remoto.

## Testes obrigatórios

- Unitários: UUID vazio, UUID PostgreSQL legado, JSON inválido e cálculos.
- Integração: rollback de cada etapa da RPC e concorrência de vale.
- E2E autenticado: criar cliente, serviço, agendamento vinculado e comanda.
- E2E: pagamento parcial seguido de quitação.
- E2E: snapshots desktop 1440px e mobile 390px aprovados pelo responsável de
  layout.

## Acceptance criteria

- [x] Typecheck, lint e Vitest passam.
- [x] Actions críticas validam organização e papel.
- [x] Agenda não ignora falha ao gravar itens.
- [x] Checkout elimina a consulta sequencial do cliente.
- [x] Checkout é transacional e idempotente.
- [x] Pagamento parcial pode ser quitado depois.
- [x] Vales possuem ledger de redenções.
- [x] Audit logs são gravados.
- [ ] Fluxos críticos possuem E2E autenticado.
