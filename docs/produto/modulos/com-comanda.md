# Módulo: Comanda/Checkout (COM)

> A conta de cada atendimento: revisar os itens, dar desconto ou aceitar gorjeta, receber (em uma ou várias formas), guardar sem pagar e quitar depois.
> Ao concluir, gera o comprovante interno e atualiza saldo, vale, estoque e caixa.

**Telas e rotas:** `/{org}/checkout` (lista), `/{org}/checkout/{id}` (a comanda do atendimento) e `/{org}/checkout/nova` (venda avulsa) · `/{org}/financeiro/comandas` (lista, consulta e relatórios), `/{org}/financeiro/comandas/{id}` e `/nova` · `/{org}/financeiro/vales` (vale-presente) · `/pagar/{token}` (cobrança por link, módulo Cobranças) · **Código:** `src/workspace/financeiro/comandas`, `src/workspace/financeiro/vales`, `src/workspace/financeiro/checkout-data.server.ts`, `checkout-map.ts` · **Spec(s):** sem spec do Checkout no crm-agenda (o Checkout aparece só em `docs/specs/screens/agendamento.md` como "fora desta entrega"). No legado: `docs/produto/legado/specs/09-checkout-pos-sales.md`, `10-payments-policy-deposits.md`, `33-studio-settings-receipt.md`, `41-finance-reports-dre-saldos-vales.md`, `42-padrao-de-interface.md`, `46-padrao-fresha-aprovado.md`, `54-novo-agendamento-pendencias.md`.

Siglas da coluna Origem: `R1` a `R5` = relatórios em `docs/reorganizacao/levantamento/` (letra = seção, depois fonte). `reg:N` = linha N de `docs/decisoes/historico/registro-ate-2026-11-24.md`. "antigo" = Beauty System; "atual" = crm-agenda. Nome: o legado ora diz "Comanda", ora "Checkout" (ver pendências).

## Recursos
| ID | Recurso | Estado | Onde | Origem |
|---|---|---|---|---|
| COM-01 | Comanda única por atendimento; abre só com o atendimento; rota genérica de checkout volta para a agenda | pronto (antigo) · pronto (atual) | `/checkout/{id}` | R4 B spec 09:13-45,76-83; R5 B scope-master:73; R2 B STATUS:32 |
| COM-02 | Venda avulsa (sem atendimento) | pronto (atual: "comanda e venda avulsa"; menu marca "Agenda") · descartado (antigo: "sem checkout avulso nem carrinho global") | `/checkout/nova`, `/financeiro/comandas/nova` | R2 B STATUS:32, history:39; R3 B audit:28; R4 B spec 09:18-21,88-93 |
| COM-03 | Etapas: Agendamento › Revisar › (Gorjeta) › Pagar › Concluído; barra com o nome de cada etapa | pronto (antigo e atual) | `/checkout/{id}` | R4 B spec 54:124-136; R1 B inv:85; R1 A L-1111-07 |
| COM-04 | Estados da venda: rascunho (sem pagamento), parcial (pagamento insuficiente, com débito rastreável) e paga; pagamentos posteriores até zerar; cancelar a venda não apaga atendimento nem histórico | pronto (antigo) | `/checkout/{id}` | R4 B spec 09:27-45; R5 B scope-master:80-81 |
| COM-05 | Itens (serviços, produtos, pacote, extras), desconto, cupom, taxa de serviço, gorjeta e nota | pronto (antigo) | `/checkout/{id}` | R4 B spec 09:27-28; R5 B scope-master:74-75 |
| COM-06 | Formas de pagamento: dinheiro, cartão débito e crédito, transferência, Bizum, vale-presente, crédito da cliente; configuráveis por estúdio; moeda EUR | pronto (antigo) · pronto, uma forma de cada vez (atual) | Pagar | R4 B spec 09:47-53; R1 B inv:87; R5 B scope-master:77-78 |
| COM-07 | Várias formas no mesmo pagamento (pagamento dividido), cartões de pagamento quadrados, "Usar saldo" com chave, lista "Pagamentos", "Faltam X", botão "Pagar 85,00 €" (CARD-05) | pronto "split" (antigo) · planejado, não aplicado (atual) | Pagar | R5 B scope-master:76; R1 B inv:87, reg:270; R1 A CARD-05 |
| COM-08 | Painel "Desconto \| Gorjeta \| + Taxa" e item "Desconto, gorjeta ou taxa" no ⋮; poder pôr os três na mesma venda | pronto, gorjeta no ⋮ (antigo) · planejado, não aplicado (atual) | ⋮ do Checkout | R4 B spec 54:124-136; R1 B rv:88; R1 A CARD-06, CARD-11b, L-1111-04 |
| COM-09 | Gorjeta flexível (Sem gorjeta, 5 €, 10 €, 10 %, Outro), como no Fresha; etapa própria ou no ⋮ | pronto/planejado, sem estado explícito (antigo) · planejado (atual, pedidos de 07/11) | menu ⋮, etapa Gorjeta | R4 B spec 46:107-110; R3 B falas:96-97 |
| COM-10 | Ajustes › Financeiro: desconto e gorjeta ligam separados; "No menu ⋮" ou "Etapa própria"; "Motivo obrigatório" e lista de motivos de desconto | planejado, não aplicado (atual) | Ajustes › Financeiro | R1 A CARD-06-AJ; R3 B fase1:122 (G10) |
| COM-11 | Resumo em cascata no rodapé; tocar no Total abre o "Detalhe"; setinha só com detalhe (CARD-15) | planejado, não aplicado (atual) | rodapé do Checkout | R1 A L-1111-05, CARD-15; R1 B rv:88 |
| COM-12 | Dividir pagamento, "Usar crédito da cliente" (em Revisar ou só em Pagar) e "Ao concluir esta venda" | em aberto, sem spec nem fila (atual) | Checkout | R1 B rv:92, inv:95; R1 D reg:279 |
| COM-13 | Crédito positivo da cliente usado só por escolha, desligado por padrão; o texto "false" não liga; alternar reconcilia sem apagar pagamento parcial deliberado | pronto (antigo) · parcial, E2E financeiro pendente | Pagar | R4 B spec 09:41,77-81; R5 B scope-master:79 |
| COM-14 | Excedente recebido vira crédito da cliente (`overpayment_credit`); pagar menos que o total vira crédito por opção (G10) | pronto (antigo) · planejado (atual, G10) | Pagar | R4 A spec 09:95-99; R5 B scope-master:80; R3 B fase1:122 |
| COM-15 | Sinal: abatido na mesma comanda, não vira crédito genérico; trilha itemizada com edição e estorno | pronto (antigo) | agenda, Checkout | R4 A spec 10:3-5,30; R5 B core-delivery-control:69,177 |
| COM-16 | Checkout atômico e idempotente (uma única operação de banco: bloqueio, venda, itens, pagamentos, transação, vale, extratos, auditoria); continuação parcial aditiva | pronto (spec 22, `[x]`; core-delivery-control) · critério `[ ]` na spec 09 | banco | spec 22:37-52,103-104 (legado/specs/22-operational-integrity-and-audit.md); spec 09:84-85; R5 B 360 |
| COM-17 | Cópia (snapshot) imutável de itens, preços, custos e pagamentos em cada venda | pronto (antigo) | banco | R4 B spec 09:43,55-64; R5 B scope-master:82 |
| COM-18 | Reembolso total e parcial (estorno) | pronto (atual: inventário) · parcial pronto (antigo) · "Estorno parcial fica para depois" (v26) | Financeiro › Comandas (`refund-actions`) | R1 B inv:91, v26-mobile-ux:63,74; R5 B painel; R1 F-11 |
| COM-19 | Comprovante interno ao concluir ("Documento interno, sem valor fiscal"), número = referência da venda; sem emissão fiscal | pronto (antigo, `[x]`) | ao concluir | spec 33:24-26,46-47 (legado/specs/33-studio-settings-receipt.md); spec 09:88-93 |
| COM-20 | Vale-presente como pagamento: pede o código, mostra o saldo, usa até o que falta; validação e resgate | pronto (antigo) · "resgatar vale no checkout sem teste" (atual) | Pagar | R5 B scope-master:78; R1 A L-1111-03; R3 B audit:28 |
| COM-21 | Vales-presente na lista: saldo em circulação, filtro por situação, emitir (valor, código, destinatário, validade), copiar, cancelar com confirmação, CSV; emitir e cancelar exigem `comanda.operate` | pronto (antigo) | `/financeiro/vales` | R4 B spec 41:69-73,79 |
| COM-22 | Cada uso de vale e cada lançamento de saldo gravados num extrato que só cresce, na mesma transação | pronto (antigo; ledger) · critério `[ ]` na spec 09 | banco | R4 B spec 23:60-63,103; R4 B spec 09:85 |
| COM-23 | Trava da ficha de saúde: assinatura da cliente impede iniciar e fechar; avaliação da profissional pendente impede fechar, mas pode ser liberada com motivo (campo "Motivo" e "Liberar e concluir pagamento") | pronto/parcial (antigo) | Checkout (ver ANA-17, ANA-18) | R4 B spec 12:76-79,131-154 |
| COM-24 | Notas na comanda: fixas e do atendimento no contexto; notas gerais por contador; painel lateral ou folha | pronto (antigo, aprovado) | Checkout (ver CLI-16) | R4 B spec 28:32-40 |
| COM-25 | Retoque incluído mostrado na comanda; o menu do item aplica valor zero (checkout aceita preço 0, o desconto fica no item e no total) | pronto (antigo) | item da comanda | R4 B catalog-01:18-20 |
| COM-26 | Tela Checkout própria: janela larga (≥1100 px) com a agenda atrás, cartão único da cliente, etapas Revisar › Pagar | pronto (antigo, "aprovado 07/11", sem frase) · planejado, "fora desta entrega" (atual) | `/checkout/{id}` | R4 B spec 54:94-98,124-136; R3 B agd:178 |
| COM-27 | Comanda premium estilo Fresha: cliente e contexto à esquerda, itens e pagamento à direita; ação principal óbvia; secundárias no menu padrão; sem mudar a regra financeira | em andamento (antigo, jun/2026) | Checkout | R5 B agenda-operational-scope:364-391, roadmap:158 |
| COM-28 | Retorno contextual: o atendimento nunca joga para o Financeiro; "Atendimento #1061" e "Comanda #0042 · cliente"; X e voltar levam à Agenda; concluir mostra "Voltar à agenda" e "Ver recibo" | pronto (retorno, 9229bcea) · planejado (V26) | Checkout | R5 B roadmap:157, v26-mobile-ux:32-38 |
| COM-29 | Renomear "Comanda" para "Checkout" em toda a interface; visões Em aberto, Parciais, Concluídos, Estornados e Cancelados, com busca por cliente e número, pelo ☰ da Agenda e pelo Financeiro | planejado (proposta, spec 42) · specs 09, 33 e 41 mantêm "Comandas" | menu | R4 B spec 42:75-77; R4 F |
| COM-30 | Lista de comandas abertas, parciais e sem pagamento (pertence à Agenda e ao Financeiro); "Checkouts em aberto" no ⋮ da Agenda | pronto | Agenda ⋮, `/financeiro/comandas` | R4 B spec 09:20-21; R3 B ag:50 |
| COM-31 | Observações fixas (alergias etc.) sempre visíveis nas comandas abertas; campo de observação só pelo menu "Adicionar observação" | planejado (antigo) | Checkout | R5 B product-vision-detail:25-27 |
| COM-32 | Cobrança por link e transferência com comprovante; cobrança de crédito por link: só owner, admin e manager confirmam; pagamento por link lançado direto na comanda | pronto (Cobranças) · planejado (lançar na comanda) | `/pagar/{token}`, Financeiro › Cobranças | R4 B spec 30:18-36,42-44; R4 A spec 09:99 |
| COM-33 | Estoque, direitos de pacote e plano, pontos, comissão e caixa sem efeito em dobro ao concluir | parcial (antigo) | banco | R5 B roadmap:150-155 |
| COM-34 | Margem bruta por item | parcial (antigo) | relatórios | R5 B scope-master:83 |
| COM-35 | Meta de desempenho: leitura p95 < 1,5 s e gravação < 2 s, em produção | planejado (antigo) | — | R4 B spec 09:66-72 |
| COM-36 | Edição de item na comanda cobre preço, profissional e duração | pronto (core-delivery-control) · "editar duração na comanda" adiado (spec 35) | item da comanda | R5 B 360; R4 B spec 35:52-56 |
| COM-37 | Pagamento com troco, janela de dinheiro com teclado, recibo por e-mail, gorjeta depois do atendimento (até 30 dias), Tap to Pay, eVouchers | referência de mercado e Fresha (sem decisão) | — | R3 B fr/03-comanda-checkout:47-57,65-68, M/booksy:104-120, M/treatwell:100-110; R5 B 481, 486 |
| COM-38 | Fora de escopo: caixa de balcão genérico (POS), carrinho global, fechamento de caixa dentro da comanda, terminal físico e emissão fiscal | descartado (antigo) | — | R4 B spec 09:88-93 |
| COM-40 | Dados do comprovante, em Ajustes: nome comercial, razão social, NIF/CIF/NIE (aceita formato espanhol ou português, sem validar dígito), endereço, código postal, cidade, telefone, e-mail, rodapé editável (até 300 caracteres); só proprietária e administração salvam; sem bloqueio fiscal | pronto (antigo, 29/10, `[x]`) | Ajustes › Clínica, comprovante | spec 33:15-41,43-48 |
| COM-41 | Políticas de sinal e cancelamento em texto (até 1.000 caracteres), vistas pela equipe e depois nos links públicos e na reserva online | pronto (antigo, texto); uso nos links públicos planejado | Ajustes, `/pagar/{token}` | spec 33:22-23,34,41 |
| COM-42 | Venda entra nos relatórios do Financeiro só quando quitada (`sales.paid_at`, fuso do estúdio); estorno total sai da base, devolução parcial aparece à parte; comissões usam a mesma regra | pronto (antigo) | Financeiro › Relatórios | spec 41:35-37 |
| COM-43 | Saldos de clientes (crédito e dívida): totais, busca, filtro, ordenação, CSV, linha abre o perfil | pronto (antigo) | `/financeiro/saldos` | spec 41:64-67 (ver CLI-30) |
| COM-44 | Erros do checkout nunca viram sucesso: ação que falha numa escrita dependente não devolve sucesso; JSON do navegador validado; reenvio não duplica venda, pagamento, transação ou pontos; resgate de vale detecta concorrência de saldo | pronto (antigo) | servidor | spec 22:13-22,35 |
| COM-39 | E2E de rascunho, total, parcial, continuação, crédito e vale; recibo no celular; polimento final | planejado/parcial | — | R4 B spec 09:86; R5 B implementation-gap-map:123-138 |

"Estado" é o que os documentos dizem; o código é conferido quando o módulo entra em trabalho. Conferido só para "Onde": as rotas `checkout` (índice, `$id`, `nova`), `financeiro/comandas`, `financeiro/vales` e a pasta `src/workspace/financeiro` existem.

## Decisões
| ID | Decisão | Situação | Origem |
|---|---|---|---|
| COM-D01 | Comanda nasce do atendimento; checkout é liquidar a comanda, não um caixa de balcão; todo novo atendimento exige cliente cadastrado; pagamento parcial aceita pagamentos depois; crédito é por escolha; débito é aviso, não bloqueio; cache não corrige consulta lenta | **sugestão a confirmar** (12/06/2026, sem prova; "Aprovada" na spec) | R5 A (product-capability-audit-2026-06-12.md:12-21); R4 A spec 09:3-21 |
| COM-D02 | Pagar numa tela só, 5 formas (Dinheiro, Cartão, Bizum, Transferência, Vale-presente), sem tela "dividir pagamento"; "Usar saldo" só em Pagar; "Faltam X"; finalizar com valor em aberto só se ligado em Ajustes › Financeiro; gorjeta só "Sem gorjeta" e "Personalizado" | **sugestão a confirmar** (11/11, livro, sem frase) · L-1111. Conflita com COM-D06 (várias formas) | R5 A L-1111 (livro.txt:771-868,398); R1 A "Livro 15, 16" |
| COM-D03 | Vale-presente pede o código, mostra o saldo e usa até o que falta | **sugestão a confirmar** (11/11, 17h57, sem frase) · L-1111-03 | R1 A L-1111-03 (reg:187) |
| COM-D04 | Um item no ⋮ e painel só para desconto, gorjeta e taxa | **sugestão a confirmar** (11/11, 17h12, sem frase) · L-1111-04; refinada por CARD-11b | R1 A L-1111-04 (reg:188); R5 A 61 |
| COM-D05 | Resumo em cascata no rodapé; tocar no Total abre o detalhe | **sugestão a confirmar** (11/11, 17h57, sem frase) · L-1111-05 | R1 A L-1111-05 (reg:189); R5 A 62 |
| COM-D06 | CARD-05: cartões de pagamento quadrados, não escolhidos menores e cinza, várias formas, "Usar saldo" com chave, "Faltam", "Pagar 85,00 €" | **sugestão a confirmar** (19/11, aceite em lote: "Minhas escolhas de 19/11 valem") | R1 A CARD-05 (reg:270), A.0 "Aceite 19/11" |
| COM-D07 | CARD-06: painel Desconto \| Gorjeta \| + Taxa | **sugestão a confirmar** (19/11, aceite em lote) | R1 A CARD-06 (reg:271) |
| COM-D08 | CARD-06-AJ: Ajustes › Financeiro com desconto e gorjeta separados, "No menu ⋮" ou "Etapa própria", "Motivo obrigatório" | **sugestão a confirmar** (19/11, aceite em lote) | R1 A CARD-06-AJ (reg:272) |
| COM-D09 | CARD-11b (C2): item "Desconto, gorjeta ou taxa" no ⋮ do Checkout | **sugestão a confirmar** (19/11, aceite em lote) | R1 A CARD-11b (reg:276) |
| COM-D10 | CARD-15: resumo fechado no rodapé; aberto vira "Detalhe"; setinha só com detalhe | **sugestão a confirmar** (19/11, aceite em lote; atribuída a "sugestão do Alexandre" sem frase) | R1 A CARD-15 (reg:277) |
| COM-D11 | Gorjeta no menu ⋮ "como no Fresha" (Sem gorjeta / personalizada em % ou €); etapas "Revisar › Pagar"; janela larga | Menu de gorjeta como no Fresha (sem gorjeta; personalizada em % ou €): **a confirmar** (antes: vale) (pedido dele: "menu de gorjeta deve ser similar ao fresha (sem gorjeta e gorjeta personalizada e ai abre seletor de % ou $$ e valor.", 07/11/2026, 21h31) · etapas "Revisar › Pagar" e janela larga: **sugestão a confirmar** (aprovado 07/11, sem frase) | R4 A spec 54:124-136; R4 B spec 46:107-110 |
| COM-D12 | Gorjeta opcional no configurador, etapa separada ou no ⋮, como no Fresha | **a confirmar** (antes: vale) (pedido dele: "nao deve ter uma etapa de gorjeta fixa. isso deve ser inserido no configurador como opcional. exibir etapa separada de gorjeta ou em opções (3 pontinhos).", 07/11/2026, 20h00) | R3 B falas:96-97 |
| COM-D13 | Pagar menos que o total vira crédito (por opção); motivos de desconto configuráveis, obrigatório ou opcional (G10) | **sugestão a confirmar** (09/11, aceite em lote) | R1 A G10 (reg:126) |
| COM-D14 | Sinal maior que o total vira crédito; atendimento Cancelado ou Ausência não pode ser cobrado; cobrança de crédito por link só owner, admin e manager | **sugestão a confirmar** (29/10, sem prova) | R4 A spec 09:95-99 |
| COM-D15 | Sinal confirmado reduz a comanda; não vira crédito genérico solto | **sugestão a confirmar** (sem prova) | R4 A spec 10:7-12 |
| COM-D16 | Renomear Comanda para Checkout em toda a interface | **sugestão a confirmar** (proposta da spec 42; as specs 09, 33 e 41 ainda dizem "Comanda") | R4 A spec 42 §9:75-77; consolidado §4 item 23 |
| COM-D17 | Estorno parcial: "fora do escopo" (v26) contra "Reembolso total e parcial" que já existe | **sugestão a confirmar** (conflito aberto, F-11) | R1 F-11; R1 B inv:91, v26-mobile-ux:63,74; consolidado §4 item 17 |
| COM-D18 | Comanda e checkout usam o ícone de recibo com linhas (sem cifrão; o app é em euro) | **sugestão a confirmar** (18/11, camada 8, sem frase verificada) · CAM8-04 | reg:239 |
| COM-D19 | Comprovante interno sem valor fiscal; sem emissão fiscal nem terminal físico | **sugestão a confirmar** (sem prova) | R4 A spec 33:24-26; spec 09:88-93 |
| COM-D20 | Toda venda guarda cópia imutável de itens, preços, custos e pagamentos; cancelar venda não apaga histórico | **sugestão a confirmar** (sem prova) | R4 A spec 09:43-45 |
| COM-D21 | Liberar o fechamento sem a avaliação da profissional, com motivo | **sugestão a confirmar** (29/10, sem frase) · ver ANA-D05 | R4 A spec 12:131-148 |
| COM-D22 | "Seu pedido: poder pôr os três (desconto, gorjeta, taxa) na mesma venda ... como um carrinho" e "a sua ideia" (cliente envia comprovante): atribuições da IA, sem frase | **sugestão a confirmar** (fichas do Cardápio de 11/11) | R1 A "Fichas do Cardápio 11/11" (cardapio*.py) |
| COM-D23 | Dinheiro e dado de cliente: só o dono decide; a IA só decide a parte técnica | **sugestão a confirmar** (regra do projeto, deve ser revalidada) | consolidado (R2 C06, C08) |

Regra: só vale decisão registrada em `docs/decisoes/` (molde de pergunta). Tudo desta tabela é **a confirmar**; a situação antiga fica entre parênteses só como histórico e volta a ser perguntada quando o módulo for trabalhado (resposta 15a do dono, 24/11/2026).

## Regras de negócio
- A comanda é o registro comercial do atendimento; checkout é só a ação de liquidar. Venda avulsa é à parte (COM-02).
- Atendimento Cancelado ou Ausência não pode ser cobrado.
- Pagamento já gravado não pode ser reduzido nem trocado na continuação; só o valor novo gera nova transação.
- Sem pagamento, a comanda fica rascunho; pagamento insuficiente gera parcial com débito rastreável; quitar muda venda e atendimento para pago.
- Crédito da cliente só é usado quando ela ou a equipe escolhe; o excedente recebido vira crédito.
- O sinal confirmado abate a mesma comanda; sinal maior que o total vira crédito.
- Cada venda guarda cópia imutável de itens, preços, custos e pagamentos; cancelar a venda não apaga o atendimento nem o histórico financeiro.
- O checkout é uma operação só e pode ser repetida sem duplicar (idempotente): venda, itens, pagamentos, transação, vale, extratos e auditoria juntos.
- Saldo e vale-presente só mudam com lançamento no extrato, na mesma transação.
- Assinatura da cliente pendente impede iniciar e fechar; avaliação profissional pendente impede fechar, mas pode ser liberada com motivo e permissão (ANA-18).
- Cobrança de crédito por link só é confirmada por owner, admin e manager.
- Emitir e cancelar vale-presente exige `comanda.operate`.
- Valor zero é aceito no item (retoque incluído); o desconto fica no item e no total.
- Comprovante é interno, sem valor fiscal.
- Moeda: EUR.
- Toda tabela tem `org_id` e RLS; dinheiro e dado de cliente só o dono decide (CLAUDE.md).
- Estoque, direito de pacote, pontos, comissão e caixa não podem ter efeito em dobro ao concluir.

## Pendências e perguntas
| Pergunta ou pendência | Origem |
|---|---|
| Dividir pagamento, "Usar crédito da cliente" (Revisar ou só Pagar) e "Ao concluir esta venda": qual opção? Sem spec nem item na fila | R1 D reg:279, rv:92, inv:95 |
| Várias formas no mesmo pagamento: o livro (11/11) diz "sem tela dividir"; CARD-05 (19/11) diz "várias formas". Qual vale? | R1 A L-1111, CARD-05; R1 B inv:87 |
| Estorno parcial: sai (v26) ou fica (inventário)? | R1 F-11; consolidado §4 item 17 |
| Nome "Comanda" ou "Checkout" na tela, no menu e nos textos | R4 F; consolidado §4 item 23 |
| Venda avulsa: a spec 09 a exclui, o STATUS atual diz que existe. Qual vale? E a spec 53 (agendamento sem cliente) pergunta sobre venda avulsa | R4 B spec 09:18-21; R2 B STATUS:32; R4 D spec 53:137-147 |
| Tela Checkout própria (CARD-05, 06 e 11b) ainda sem spec de tela e "fora desta entrega" | R3 B agd:178; R1 B rv:87-92 |
| Critérios abertos da spec 09: RPC transacional cobrindo toda a liquidação, extrato de saldo e vale na mesma transação, E2E de rascunho, total, parcial, continuação, crédito e vale | R4 D spec 09:84-86 |
| Testes do banco da liberação do fechamento (recepção sem a permissão não libera) | R4 D spec 12:152-154 |
| Pagamento por link lançado direto na comanda ("para depois") | R4 D spec 30:42-44 |
| Resgatar vale no checkout sem teste; venda avulsa marca "Agenda" no menu | R3 B audit:28 |
| Contas pagas antes de `pay_payable_atomic` podem contar duas vezes no DRE (afeta receitas da comanda nos relatórios) | R4 D spec 41:60-62 |
| Pagamento em partes (2º parcial pela API direta) e painel que devolve todos os créditos: fatos conhecidos | R2 D STATUS:54-60 |
| Gênero dos textos: "Nova cliente" (v26) contra neutro (PASSAGEM 13/11) | consolidado §4 item 22 |
| Livro de 11/11: linha "Pagar" e "Cartão da cliente" em revisão; conflito do ⋮ do Checkout | R5 D registro.md:70, livro.txt:150-155 |
| Decidir se a ficha de anamnese é enviada ao salvar o agendamento ou só depois | R4 D spec 54:15 |
| Imagem da camada 8 desenha cifrão onde o ícone decidido é recibo | R2 D BACKLOG.md:34 |

## Referências
- Specs do legado: `docs/produto/legado/specs/09-checkout-pos-sales.md`, `10-payments-policy-deposits.md`, `14-marketing-promotions.md` (vale básico), `22-operational-integrity-and-audit.md`, `23-agenda-integrity-and-operational-ledgers.md`, `30-payment-request-transfer.md`, `33-studio-settings-receipt.md`, `35-appointment-item-duration.md`, `41-finance-reports-dre-saldos-vales.md`, `42-padrao-de-interface.md`, `46-padrao-fresha-aprovado.md`, `54-novo-agendamento-pendencias.md`.
- Produto do legado: `docs/produto/legado/produto/scope-master.md`, `roadmap.md`, `implementation-gap-map.md`, `agenda-operational-scope.md`.
- Fresha: `fr/03-comanda-checkout/README.md` (17 itens "a descrever"); `fr/README.md:55-57` (gorjeta, desconto, taxa, nota "implementado, hierarquia em revisão"; pagamento dividido "implementado").
- Registro de design: `docs/decisoes/historico/registro-ate-2026-11-24.md` (L-1111-03 a 07, CARD-05, 06, 06-AJ, 11b, 15, CAM8-04) e o cardápio revisto de 19/11 (`docs/design/design-system/camada-10-telas/cardapio-revisto-2026-11-19/`, `11bC2-menu-do-checkout.jpg`).
- Módulos ligados: Clientes (CLI, saldo e notas), Anamnese (ANA, trava), Catálogo (CAT, itens), Caixa, Cobranças, Financeiro, Fidelidade (pontos), Estoque/Compras.
