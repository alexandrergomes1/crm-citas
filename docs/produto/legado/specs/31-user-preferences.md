# Spec 31 - Preferências da pessoa: tela inicial, agenda e barra do celular

## Status

Implementada em 29 out 2026 (branch `feat/user-preferences`). Pedido do responsável do
produto em 28 out: "customizar o perfil com itens fixos e visão padrão, seja no celular
ou em outra visão".

## Objetivo

Cada pessoa escolhe, separado para **celular** e **computador**:

1. **Tela inicial** depois de entrar: Início, Agenda, Clientes, Comandas ou Financeiro.
2. **Visão padrão da agenda**: dia, 3 dias, semana ou mês.
3. **Barra inferior do celular**: os 4 atalhos ao lado de Início (padrão: Agenda,
   Clientes, Catálogo, Financeiro). Módulo desligado ou sem permissão não aparece,
   mesmo que esteja escolhido.

## Regras

- Preferência é por pessoa **e** por estúdio (`user_preferences`, chave user_id + org_id).
- RLS: cada pessoa lê e grava só as próprias preferências, e só em estúdio do qual faz
  parte. Ninguém (nem a proprietária) altera a preferência de outra pessoa.
- O aparelho é identificado pelo navegador (celular = user-agent de telefone; tablet e
  computador usam "computador"). O link com `?view=` explícito sempre vence.
- Valores inválidos são ignorados e voltam ao padrão (domínio `src/domain/preferences.ts`).
- Sem a tabela (banco antigo), tudo funciona com os padrões.

## Onde mexe

- Configurações › Conta › **Minhas preferências**.
- `app/page.tsx` e o login (sem `next`) levam para a tela inicial escolhida.
- Agenda sem `?view=` abre na visão escolhida para o aparelho.
- `MobileNav` usa os atalhos escolhidos.

## Critérios de aceite

- [x] Celular e computador com escolhas independentes.
- [x] Agenda abre na visão escolhida; `?view=` continua mandando.
- [x] Barra do celular respeita módulos e papel.
- [x] RLS testada: pessoa não lê nem grava preferências de outra.
