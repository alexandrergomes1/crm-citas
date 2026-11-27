# Spec 25 - AGENDA-BLOCKS-FILTERS-01

**Status:** Implementada e validada

**DRI:** Codex, ponta a ponta

**Aprovação de produto:** solicitação direta de 2026-06-19

## Objetivo

Evoluir a Agenda com tipos de indisponibilidade por organização, bloqueios mais
completos, recorrência básica controlada e filtros operacionais, sem redesenhar a
identidade visual nem alterar módulos adjacentes.

## Escopo aprovado

- Tipos: Indisponível, Reunião, Almoço, Pausa, Formação e Outro.
- Bloqueio: tipo, título, data, início/fim, duração, profissional, frequência,
  nota até 255 caracteres e permissão de reservas online.
- Recorrência: `none`, `daily`, `weekly` e `monthly`, materializada em no máximo
  60 ocorrências por operação.
- Filtros: profissional, status, tipo de item, tipo de bloqueio e serviço.
- UI funcional com os componentes atuais do design system.
- Vitest para regras e isolamento; Playwright no preview da Agenda.

## Contrato de dados

`time_block_types` pertence à organização, usa RLS e possui `name`, `color`,
`is_paid`, `active`, `created_at` e `updated_at`.

`time_blocks` recebe `time_block_type_id`, `title`, `notes`,
`allow_online_booking`, `recurrence_frequency`, `recurrence_count`,
`recurrence_series_id` e `updated_at`. A FK composta
`(org_id, time_block_type_id)` impede associações entre tenants.

## Recorrência

A aplicação expande a regra em ocorrências concretas antes de chamar a RPC
atômica. A expansão preserva o horário local da organização em mudanças de DST.
Recorrência mensal usa o dia âncora e limita ao último dia de meses curtos.

Não há recorrência infinita: `recurrence_count` deve estar entre 1 e 60;
frequências recorrentes exigem ao menos duas ocorrências. Personalização RRULE,
edição e remoção de série inteira ficam fora deste incremento.

## Autorização e invariantes

- Server Action autentica e autoriza o papel operacional.
- A RPC valida profissional ativo e tipo ativo na mesma organização.
- RLS limita leitura/escrita por `org_id` e papel.
- Início deve ser anterior ao fim; título tem até 120 e nota até 255 caracteres.
- A operação é atômica, usa lock por organização/profissional e grava audit log.
- Tipos padrão são criados para organizações existentes e futuras.

## Critérios de aceite

- [x] Bloqueio simples e tipado.
- [x] Recorrência diária, semanal e mensal limitada.
- [x] Filtros de item, profissional, status, tipo e serviço.
- [x] Defesa tenant-safe no contrato, RLS, RPC e filtro de apresentação.
- [x] Componentes de tela abaixo de 300 linhas.
- [x] Gate final: typecheck, lint, testes, build e evidência Playwright.

## Fora do escopo

- Editor de tipos de bloqueio.
- Recorrência personalizada ou sem fim.
- Edição/exclusão de série inteira.
- Filtros de pagamento, canal, criação e segmento sem fonte confiável atual.
- Integração da permissão online com um motor público de disponibilidade ainda
  não conectado aos bloqueios da Agenda.
