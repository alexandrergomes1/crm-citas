# Spec 30 - Cobrança por transferência com comprovante

## Status

Implementada em 29 out 2026 (branch `feat/payment-request-transfer`), atrás do módulo
`cobranca`. Banco: `20261029020000_payment_requests.sql` (depende da migration de acesso
`20261028210000`). Testes: `supabase/tests/30_payment_requests.sql`,
`src/domain/payment-request*.test.ts`. Prévia sem banco: `/dev/pagar?lang=es|en|pt`.
Não envolve emissão fiscal nem integração bancária; serve para o estúdio pedir sinal ou
saldo por transferência e dar baixa com segurança.

## Objetivo

Enviar à cliente um link de cobrança com o valor, os dados para pagar e um campo para
anexar o comprovante. A profissional confere e dá baixa: o valor vira sinal do
agendamento ou pagamento da comanda, ou crédito da cliente.

## Fluxo

1. No agendamento (sinal) ou na comanda (saldo), "Pedir pagamento por transferência".
   Escolhe valor, conta de destino e validade (padrão 24 h). Envia por WhatsApp ou e-mail
   com modelo de mensagem.
2. A cliente abre o link (sem login, token com validade e uso único):
   - valor, motivo e prazo;
   - formas aceitas: **Bizum** (número), **transferência SEPA** (titular, IBAN, BIC,
     banco), **Pix** (chave, para clientes do Brasil) quando configurado;
   - botão "copiar" em cada dado e o texto de referência ("SINAL-1061");
   - orientação: "Escolha **transferência imediata** no seu banco. A transferência comum
     pode levar 1 a 2 dias úteis, e o horário só fica garantido quando o valor chega.";
   - anexar comprovante (foto ou PDF, até 10 MB) e confirmar.
3. O estúdio recebe aviso. Status do pedido: **aguardando pagamento → comprovante enviado →
   confirmado** (ou recusado com motivo, ou expirado).
4. "Confirmar recebimento" só depois de ver o dinheiro na conta. A confirmação lança o
   valor como sinal (`appointment_deposits`), pagamento na comanda ou crédito
   (`client_balance_entries`), com auditoria. O comprovante sozinho nunca dá baixa
   automática.

## Como ficou (V1)

- **Onde cobrar:** Agenda › atendimento › Registar sinal › **Pedir por link** (sinal);
  perfil da cliente › Movimentos de saldo › **Cobrar por link** (crédito).
- **Pagamento da comanda:** entra como crédito da cliente e é usado na comanda com
  "usar crédito". Lançar direto na comanda fica para depois (a RPC da comanda exige o
  pedido inteiro de itens e pagamentos).
- **Link:** `/pagar/<token>?lang=es|en|pt`, espanhol por padrão (clientes em Benalmádena).
  Mostrado uma única vez, com "Copiar mensagem" e "Enviar no WhatsApp". O banco guarda
  só o hash; não dá para reenviar o mesmo link depois (crie outro e cancele o antigo).
- **Comprovante:** o navegador envia direto ao Storage por URL assinada de um caminho só
  (Vercel limita o corpo a 4,5 MB); o servidor confere o tipo real pelos primeiros bytes
  e registra. As RPCs de envio (`begin_payment_proof_upload`, `submit_payment_proof`) só
  aceitam o servidor (service_role); a pessoa com o link não as chama direto. Cada URL de
  upload reserva uma vaga antes de ser entregue: no máximo 5 por pedido, mesmo em
  paralelo. O tamanho registrado vem do Storage. Falha ao registrar não apaga o arquivo.
- **Conferência:** Financeiro › **Cobranças** (abertas, encerradas, todas), "Ver
  comprovante" (URL assinada de 5 min), "Confirmar recebimento" (escolhe Bizum ou
  transferência), "Recusar" (com motivo) e "Cancelar cobrança". Pedido vencido ainda pode
  ser confirmado, porque o dinheiro pode chegar depois do prazo.
- **Quem faz:** criar e confirmar sinal: proprietária, administração, gestão, recepção e
  financeiro. Cobrança de crédito (criar e confirmar) segue a regra do saldo:
  proprietária, administração e gestão. O caixa registra Bizum ou transferência, não
  dinheiro. Contas de recebimento: proprietária e administração.
- **Aviso ao estúdio** quando chega comprovante: ainda não (depende do módulo Mensagens).
  Por enquanto a aba Cobranças mostra quantos comprovantes esperam conferência.

## Revisão de segurança (29 out 2026)

Revisão independente apontou e foi corrigido: exclusão de comprovante por caminho não
verificado; limite de arquivos contornável em paralelo; envio aceito direto por anon com
tipo e tamanho informados pelo chamador; crédito criado por papel que não confirma;
função de status marcada `immutable` usando `now()`; crédito lançado como dinheiro.
Pendentes (baixo risco): link continua visível se o módulo for desligado depois (o envio
de comprovante já recusa); referência de 24 bits sem unicidade; limpeza de arquivos
órfãos de uploads não concluídos; limite de requisições no `/pagar`.

## Ajustes do estúdio

Contas de recebimento (várias): tipo (Bizum, SEPA, Pix), titular, IBAN/chave, banco, ativa;
texto de orientação editável; validade padrão do link; se pede comprovante obrigatório.

## Dados (direção)

`payment_accounts` (org_id, tipo, titular, iban_or_key, bic, banco, ativa),
`payment_requests` (org_id, client_id, appointment_id, sale_id, amount, currency, reason,
reference, account_ids, token_hash, expires_at, status, confirmed_by, confirmed_at,
reject_reason), `payment_request_files` (bucket privado `payment-proofs`, pasta por
org/pedido). RLS por org_id; o link público usa RPC por token (hash, validade, uso único),
igual à anamnese.

## Regras

- Token guardado só como hash; link expira; reabrir depois de confirmado mostra "pago".
- Comprovante em bucket privado; leitura só pelo estúdio, com URL assinada curta.
- Confirmar e recusar exigem papel com `comanda.operate` e ficam auditados.
- Idempotência: um pedido confirmado não lança o valor duas vezes.
- Sem bloqueios fiscais: o sistema registra, não emite fatura nem decide tributação.

## Critérios de aceite

- [x] Cliente vê dados com botão copiar e a orientação de transferência imediata.
- [ ] Comprovante anexado aparece para o estúdio em até 1 minuto (aviso). Aparece na lista; aviso ativo depende de Mensagens.
- [x] Confirmação lança sinal ou crédito uma única vez, com auditoria.
- [x] Link expirado ou já pago não aceita novo comprovante.
- [x] Link público a 390 px e 1440 px (prévia `/dev/pagar`).
