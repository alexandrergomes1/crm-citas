# CLIENT-01 - Cadastro internacional de cliente

## Objetivo

Suportar o uso inicial na Espanha e Europa sem prender o cadastro a CPF/Brasil.

## Regras

- Nome e telefone são obrigatórios nos novos cadastros completos.
- O DDI padrão para novos clientes é `+34`; outros códigos internacionais são aceitos.
- O telefone continua armazenado em `clients.phone` no formato internacional apresentado pelo usuário.
- `phone_country_code` registra o DDI separadamente quando conhecido.
- Documento usa `document_type` e `document_number`.
- Tipos aceitos: DNI, NIE, NIF, passaporte, CPF e outro.
- Não existe validação rígida de CPF como regra global.
- A coluna legada `cpf` é preservada e migrada para os novos campos.
- Dados de anamnese não atualizam automaticamente o cadastro.

## Compatibilidade

- Clientes antigos podem continuar sem telefone ou DDI no banco.
- CPF existente é copiado para `document_number` e marcado como `cpf`.
- Leituras usam os campos novos e recorrem ao CPF legado apenas como fallback.
