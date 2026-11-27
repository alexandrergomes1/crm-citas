# Clientes: cidade e estado, uso de imagem, mesclagem, importação e exportação auditada

Migration: `20261030300000_clientes_cidade_imagem_mesclagem.sql` · Testes: `supabase/tests/127_merge_clients_atomic.sql`.

## Cidade e estado ou província
- `clients.city` e `clients.state_region` (texto opcional, 1 a 120 caracteres depois de aparar).
- Formulário (Mais dados), perfil (Detalhes), busca da lista e CSV de exportação.

## Uso de imagem (divulgação das fotos)
- `clients.image_use_consent` (padrão `false`), com `image_use_consent_at` e `image_use_consent_by` carimbados
  pelo banco (gatilho `trg_clients_image_consent`). A API não escolhe quem nem quando.
- Cada mudança grava auditoria `IMAGE_CONSENT_GRANTED` ou `IMAGE_CONSENT_REVOKED`.
- Quem altera: `clientes.manage`. Controle no formulário e no cartão "Uso de imagem" do perfil.
- A seção Fotos do perfil mostra o selo "Divulgação permitida" ou "Divulgação não permitida".
  O uso interno (prontuário) não depende da autorização; divulgação (site, redes, campanhas)
  só usa foto de quem autorizou (`src/domain/client-image-consent.ts`, `splitByImageConsent`).
- Fotos: dado clínico, só com `clientes.view_clinical`; endereços assinados por 1 hora.

## Mesclagem atômica de duplicados
- RPC `merge_clients_atomic(org, keep, merge)`, exige `clientes.manage`, uma transação.
- Move agendamentos, notas, anamneses (assinadas incluídas, sem alterar a evidência), vendas, transações, sinais,
  pedidos de pagamento, vale-presentes, pacotes, mensagens, preferências, extrato de saldo e pontos.
- Soma saldo, total gasto e pontos; junta etiquetas e alertas; preenche campos vazios; consentimento de imagem
  fica só se os dois autorizaram.
- A ficha repetida fica `Inativo` com `merged_into`, `merged_at`, `merged_by`. Repetir a mesma mescla devolve
  `already_merged: true`. Mesclar numa ficha que já foi mesclada em outra é recusado.
- Auditoria `CLIENT_MERGED`. Tela: painel Clientes duplicados, botão Mesclar com confirmação.

## Importação por CSV
- Opções › Importar clientes. A planilha é lida no navegador (`src/domain/client-import.ts`): colunas Nome e
  Telefone obrigatórias; E-mail, Cidade, Estado, Nascimento, Origem, Etiquetas e Observações opcionais.
- Prévia antes de gravar: quantos entram, quantos já existem (mesmo telefone ou e-mail) e linhas recusadas.
- Limite de 2.000 linhas; lotes de 200 atômicos; repetir a importação não duplica. Exige `clientes.manage`.

## Exportação auditada
- RPC `log_clients_export(org, count, filters)` (exige `clientes.view`) grava `CLIENTS_EXPORTED` com quem, quando,
  quantos e o filtro. A exportação só devolve o arquivo depois do registro.

## Fora desta entrega
- "Nova visão" (visões salvas da lista): precisa de modelo de preferências próprio e contagem por visão.
