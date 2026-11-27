# Spec 33 - Ajustes do estúdio e comprovante interno

## Status

Implementada em 29 out 2026 (branch `feat/studio-settings`). Núcleo do go-live
(auditoria de módulos, seção 10, itens 3 e 5).

## Problema encontrado

Configurações › Clínica só oferecia fusos do Brasil. O estúdio está em
`Europe/Madrid`; ao salvar a tela, o seletor caía no primeiro fuso da lista
(`America/Sao_Paulo`) e a agenda passaria a mostrar os horários com 4 a 5 horas de
diferença. A moeda também tinha "EUR — Real brasileiro" duplicado.

## Objetivo

1. **Dados do estúdio** que aparecem no comprovante: nome comercial, razão social,
   NIF/CIF/NIE, endereço, código postal, cidade, telefone, e-mail.
2. **Regiões e moeda** corretas para Espanha, Portugal, Reino Unido e Brasil. O fuso
   atual do estúdio sempre aparece na lista, mesmo que não esteja entre os comuns:
   salvar a tela nunca troca o fuso sem a pessoa escolher.
3. **Políticas** em texto: sinal e cancelamento (aparecem para a equipe e, depois, nos
   links públicos e na reserva online).
4. **Comprovante interno** ao concluir a comanda: dados do estúdio no topo, número do
   comprovante (referência da venda), rodapé editável e a frase "Documento interno, sem
   valor fiscal". Sem bloqueio fiscal em nenhum ponto (decisão de 28 out).

## Dados

- Colunas existentes de `organizations`: name, phone, email, address, city, timezone,
  currency.
- `organizations.settings.business`: legal_name, tax_id, postal_code, receipt_footer.
- `organizations.settings.policies`: deposit, cancellation.
- Sem migration: tudo no jsonb `settings`, mesclado sem apagar outras chaves.

## Regras

- Só proprietária e administração salvam (igual às outras abas).
- NIF/CIF/NIE: aceita formato espanhol ou português; não valida dígito para não
  bloquear (só orienta quando parece incompleto).
- Textos com limite (rodapé 300, políticas 1000).

## Critérios de aceite

- [x] Fuso `Europe/Madrid` aparece e fica selecionado; salvar não muda o fuso.
- [x] Dados do recibo salvos e exibidos no comprovante.
- [x] Comprovante com "Documento interno, sem valor fiscal".
- [x] Telas a 390 px e 1440 px.
