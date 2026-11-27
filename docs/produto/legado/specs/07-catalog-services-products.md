# Spec 07 — Catálogo: Serviços e Produtos

## Goal
Permitir que a clínica gerencie serviços (procedimentos) organizados por categorias, com preço, duração, buffer, comissão e flag de agendamento online.

## Entidades

### ServiceCategory
`id · org_id · name · color(hex) · icon(emoji?) · position · active`

### Service
`id · org_id · category_id · name · description · price · price_type('fixed'|'from') · duration_minutes · buffer_minutes · commission_pct · online_booking · active · position`

## Telas

### /[orgSlug]/catalogo
- Sidebar esquerda: lista de categorias com contagem + "Todas"
- Grid direito: cards de serviços filtrados
- Header: "Catálogo" + botões "Novo serviço" / "Nova categoria"
- Empty state por categoria e global

### ServiceCard
- Nome, badge de categoria, preço em destaque, duração + buffer
- Comissão %, toggle online booking, botão editar, toggle ativo

### ServiceForm (Dialog — criar e editar)
- nome*, categoria*, descrição, preço*, tipo de preço
- duração* (15–240 min), buffer (0–60 min)
- comissão %, online booking (Switch), ativo (Switch)

### CategoryForm (Dialog — criar e editar)
- nome*, cor (palette 12 cores), ícone emoji opcional

## Regras de negócio
- Serviço inativo não aparece na Agenda nem no Checkout
- `online_booking=true` apenas disponibiliza no portal público
- `price=0` é válido (serviço gratuito / incluído em pacote)
- Buffer é invisível ao cliente — adicionado internamente ao `end_at`

## RLS
- SELECT: qualquer membro da org
- INSERT/UPDATE/DELETE: owner, admin, manager

## Dependências
- Sem deps de outros módulos de negócio
- Desbloqueia: Agenda (modal), Checkout, Online Booking

## Acceptance Criteria
- [ ] Criar serviço com todos os campos → aparece na lista
- [ ] Editar preço/duração → Agenda reflete na criação de agendamento
- [ ] Toggle ativo=false → some da seleção do modal de Agenda
- [ ] Criar categoria → disponível no form de serviço
- [ ] typecheck zero · lint zero · mobile 390px ok
