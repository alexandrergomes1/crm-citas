# Spec 03 — Auth Multitenant + RLS

## Feature Trace
- Roadmap: Fase 2 — Data Foundation
- Source: `ka-beauty/docs/auth-strategy.md`, `ka-beauty/docs/architecture.md`

## Decisão 28 out 2026

Login continua no Supabase Auth (e-mail e senha). Papéis, módulos por estúdio e
administração master: ver `29-access-roles-modules.md`. Redirecionamento após login aceita
só caminhos internos (`src/lib/safe-redirect.ts`).

## Goal

Configurar autenticação Supabase com multi-tenancy por `org_id` e Row Level Security em todas as tabelas.

## Users

Todos os perfis. Auth é base para todo o sistema.

## Screens

- `app/(auth)/login/page.tsx` — formulário de login
- `app/(auth)/logout/route.ts` — rota de logout
- Middleware de proteção de rotas

## Main Flow

1. Usuário acessa `/login`, insere email + senha
2. Supabase Auth valida e retorna sessão
3. Middleware verifica sessão em todas as rotas `/(workspace)/`
4. Usuário é redirecionado para `/<orgSlug>/agenda`
5. Todas as queries de dados filtram por `org_id` via RLS

## Business Rules

- RLS em TODA tabela de negócio — sem exceção
- Service role apenas server-side, nunca exposta ao browser
- Sessão expirada redireciona para `/login`
- Um usuário pode pertencer a múltiplas organizações (user_roles)
- `org_id` vem do `orgSlug` na URL + verificação de membership
- Roles: owner, admin, manager, professional, receptionist, finance, viewer

## Data Contract (Schema Base)

```sql
-- Organizações
create table organizations (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  created_at timestamptz default now()
);

-- Profiles (one per user per org)
create table profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  org_id uuid references organizations not null,
  full_name text not null,
  avatar_url text,
  created_at timestamptz default now(),
  unique(user_id, org_id)
);

-- Roles
create type user_role as enum (
  'owner','admin','manager','professional','receptionist','finance','viewer'
);

create table user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  org_id uuid references organizations not null,
  role user_role not null default 'viewer',
  created_at timestamptz default now(),
  unique(user_id, org_id)
);
```

## RLS Patterns

```sql
-- Padrão base para toda tabela
create policy "org_access" on <table>
  for all using (
    org_id in (
      select org_id from user_roles
      where user_id = auth.uid()
    )
  );

-- Role-based write
create policy "manager_write" on <table>
  for insert, update, delete using (
    exists (
      select 1 from user_roles
      where user_id = auth.uid()
        and org_id = <table>.org_id
        and role in ('owner','admin','manager')
    )
  );
```

## UX States

- **Loading:** spinner enquanto verifica sessão
- **Não autenticado:** redireciona para `/login`
- **Sem membership:** página de erro "Acesso negado"
- **Sessão expirada:** redireciona para `/login` com toast

## Acceptance Criteria

- [ ] Login funciona com email + senha
- [ ] Logout limpa sessão e redireciona para `/login`
- [ ] Middleware protege todas as rotas `/(workspace)/`
- [ ] RLS ativo em organizations, profiles, user_roles
- [ ] Usuário sem membership não acessa dados de outra org
- [ ] `pnpm test` passa (testes de RLS com service role)

## Out Of Scope (v1)

- Login social (Google, Apple)
- Magic link
- Two-factor authentication
- Convite de usuário por email (manual por ora)
