-- UTF-8
-- ============================================================
-- KA Beauty OS · Acesso, papéis, módulos por estúdio e administração master
-- Spec: docs/specs/29-access-roles-modules.md
--
-- O que esta migration faz:
--   1. helper has_org_role() e is_platform_admin();
--   2. platform_admins: administradores master do Beauty System (fora dos estúdios);
--   3. registro de módulos, planos fixos e extras por estúdio, com org_has_module();
--   4. user_roles: só a proprietária concede owner/admin; ninguém altera o próprio
--      papel; a última proprietária ativa não pode ser removida;
--   5. audit_logs: ninguém grava log em nome de outro usuário;
--   6. auditoria automática de papéis, plano e módulos;
--   7. funções security definer de negócio deixam de ser executáveis por anon
--      (exceto as dos links públicos: anamnese e cobrança).
-- Aditiva e idempotente: pode rodar de novo sem efeito colateral.
-- ============================================================

-- ─── 1. Helpers ─────────────────────────────────────────────
create or replace function public.has_org_role(p_org_id uuid, p_roles text[])
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select exists (
    select 1
    from public.user_roles ur
    where ur.org_id = p_org_id
      and ur.user_id = (select auth.uid())
      and ur.active = true
      and ur.role::text = any (p_roles)
  );
$$;

revoke all on function public.has_org_role(uuid, text[]) from public, anon;
grant execute on function public.has_org_role(uuid, text[]) to authenticated, service_role;

-- ─── 2. Administração master ────────────────────────────────
create table if not exists public.platform_admins (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  note       text,
  created_at timestamptz not null default now()
);
comment on table public.platform_admins is 'Administradores master do Beauty System. Escrita só com service_role.';
alter table public.platform_admins enable row level security;

drop policy if exists platform_admins_select_self on public.platform_admins;
create policy platform_admins_select_self on public.platform_admins
  for select to authenticated
  using (user_id = (select auth.uid()));

revoke insert, update, delete, truncate on public.platform_admins from anon, authenticated;

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select exists (select 1 from public.platform_admins pa where pa.user_id = (select auth.uid()));
$$;

revoke all on function public.is_platform_admin() from public, anon;
grant execute on function public.is_platform_admin() to authenticated, service_role;

-- ─── 3. Módulos e planos ────────────────────────────────────
create table if not exists public.modules (
  key         text primary key check (key ~ '^[a-z][a-z_]{1,39}$'),
  name        text not null,
  description text not null default '',
  is_core     boolean not null default false,
  depends_on  text[] not null default '{}',
  position    int not null default 0,
  active      boolean not null default true
);
comment on table public.modules is 'Registro de módulos do produto. is_core = sempre ligado em qualquer plano.';

create table if not exists public.plans (
  key                 text primary key check (key ~ '^[a-z][a-z_]{1,39}$'),
  name                text not null,
  monthly_price_cents int  not null default 0 check (monthly_price_cents >= 0),
  currency            text not null default 'EUR',
  limits              jsonb not null default '{}',
  position            int  not null default 0,
  active              boolean not null default true
);
comment on table public.plans is 'Planos fixos. limits: {"staff": n, "automated_messages_month": n, "storage_gb": n}.';

create table if not exists public.plan_modules (
  plan_key          text not null references public.plans(key) on update cascade,
  module_key        text not null references public.modules(key) on update cascade,
  mode              text not null check (mode in ('included', 'extra')),
  extra_price_cents int  check (extra_price_cents is null or extra_price_cents >= 0),
  primary key (plan_key, module_key),
  check (mode = 'included' or extra_price_cents is not null)
);
create index if not exists idx_plan_modules_module on public.plan_modules (module_key);

create table if not exists public.org_subscriptions (
  org_id          uuid primary key references public.organizations(id) on delete cascade,
  plan_key        text not null references public.plans(key) on update cascade,
  status          text not null default 'active' check (status in ('trial', 'active', 'suspended', 'canceled')),
  trial_ends_at   timestamptz,
  limits_override jsonb not null default '{}',
  notes           text,
  updated_at      timestamptz not null default now(),
  updated_by      uuid references auth.users(id) on delete set null
);
create index if not exists idx_org_subscriptions_plan on public.org_subscriptions (plan_key);

create table if not exists public.org_modules (
  org_id      uuid not null references public.organizations(id) on delete cascade,
  module_key  text not null references public.modules(key) on update cascade,
  enabled     boolean not null default true,
  price_cents int check (price_cents is null or price_cents >= 0),
  reason      text,
  updated_at  timestamptz not null default now(),
  updated_by  uuid references auth.users(id) on delete set null,
  primary key (org_id, module_key)
);
create index if not exists idx_org_modules_module on public.org_modules (module_key);
comment on table public.org_modules is 'Extras ligados e exceções por estúdio. enabled=false desliga um módulo mesmo se o plano incluir (exceto core).';

alter table public.modules           enable row level security;
alter table public.plans             enable row level security;
alter table public.plan_modules      enable row level security;
alter table public.org_subscriptions enable row level security;
alter table public.org_modules       enable row level security;

-- catálogo de módulos e planos: leitura para usuários logados; escrita só master
drop policy if exists modules_select on public.modules;
create policy modules_select on public.modules for select to authenticated using (true);
drop policy if exists modules_platform_write on public.modules;
create policy modules_platform_write on public.modules for all to authenticated
  using ((select public.is_platform_admin())) with check ((select public.is_platform_admin()));

drop policy if exists plans_select on public.plans;
create policy plans_select on public.plans for select to authenticated using (true);
drop policy if exists plans_platform_write on public.plans;
create policy plans_platform_write on public.plans for all to authenticated
  using ((select public.is_platform_admin())) with check ((select public.is_platform_admin()));

drop policy if exists plan_modules_select on public.plan_modules;
create policy plan_modules_select on public.plan_modules for select to authenticated using (true);
drop policy if exists plan_modules_platform_write on public.plan_modules;
create policy plan_modules_platform_write on public.plan_modules for all to authenticated
  using ((select public.is_platform_admin())) with check ((select public.is_platform_admin()));

-- assinatura e módulos do estúdio: membros leem; só master altera
drop policy if exists org_subscriptions_select on public.org_subscriptions;
create policy org_subscriptions_select on public.org_subscriptions for select to authenticated
  using (public.has_org_role(org_id, array['owner', 'admin']) or (select public.is_platform_admin()));
drop policy if exists org_subscriptions_platform_write on public.org_subscriptions;
create policy org_subscriptions_platform_write on public.org_subscriptions for all to authenticated
  using ((select public.is_platform_admin())) with check ((select public.is_platform_admin()));

drop policy if exists org_modules_select on public.org_modules;
create policy org_modules_select on public.org_modules for select to authenticated
  using (public.has_org_role(org_id, array['owner', 'admin']) or (select public.is_platform_admin()));
drop policy if exists org_modules_platform_write on public.org_modules;
create policy org_modules_platform_write on public.org_modules for all to authenticated
  using ((select public.is_platform_admin())) with check ((select public.is_platform_admin()));

revoke all on public.modules, public.plans, public.plan_modules, public.org_subscriptions, public.org_modules from anon;
revoke truncate, trigger, references on public.modules, public.plans, public.plan_modules, public.org_subscriptions, public.org_modules,
  public.platform_admins, public.user_roles, public.audit_logs from anon, authenticated;

-- Módulos ativos de um estúdio: core + incluídos no plano + extras ligados − desligados,
-- respeitando dependências. Estúdio suspenso ou cancelado: só core.
create or replace function public.org_enabled_modules(p_org_id uuid)
returns setof text
language plpgsql
stable
security definer
set search_path to ''
as $$
declare
  v_status text;
  v_plan   text;
  v_trial  timestamptz;
begin
  -- Sem usuário: só service_role ou conexão administrativa direta (fail closed).
  if (select auth.uid()) is null then
    if coalesce((select auth.jwt()) ->> 'role', '') <> 'service_role'
       and session_user not in ('postgres', 'supabase_admin') then
      raise exception 'Autenticação obrigatória' using errcode = '42501';
    end if;
  elsif not exists (select 1 from public.user_roles ur where ur.org_id = p_org_id and ur.user_id = (select auth.uid()) and ur.active)
        and not (select public.is_platform_admin()) then
    raise exception 'Sem acesso a este estúdio' using errcode = '42501';
  end if;

  select s.status, s.plan_key, s.trial_ends_at into v_status, v_plan, v_trial
  from public.org_subscriptions s where s.org_id = p_org_id;

  -- Teste vencido conta como suspenso: fica só o núcleo, dados preservados.
  if v_status = 'trial' and v_trial is not null and v_trial < now() then
    v_status := 'suspended';
  end if;

  return query
  with wanted as (
    select m.key
    from public.modules m
    where m.active and (
      m.is_core
      or (coalesce(v_status, 'active') in ('trial', 'active') and (
            exists (select 1 from public.plan_modules pm where pm.plan_key = v_plan and pm.module_key = m.key and pm.mode = 'included')
            or exists (select 1 from public.org_modules om where om.org_id = p_org_id and om.module_key = m.key and om.enabled)
          )
          and not exists (select 1 from public.org_modules om where om.org_id = p_org_id and om.module_key = m.key and not om.enabled))
    )
  )
  select w.key from wanted w
  join public.modules m on m.key = w.key
  where m.depends_on <@ (select coalesce(array_agg(w2.key), '{}') from wanted w2)
  order by m.position;
end;
$$;

revoke all on function public.org_enabled_modules(uuid) from public, anon;
grant execute on function public.org_enabled_modules(uuid) to authenticated, service_role;

create or replace function public.org_has_module(p_org_id uuid, p_module text)
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select case
    when (select auth.uid()) is not null
         and not exists (select 1 from public.user_roles ur where ur.org_id = p_org_id and ur.user_id = (select auth.uid()) and ur.active)
         and not (select public.is_platform_admin())
      then false
    else exists (select 1 from public.org_enabled_modules(p_org_id) k where k = p_module)
  end;
$$;

revoke all on function public.org_has_module(uuid, text) from public, anon;
grant execute on function public.org_has_module(uuid, text) to authenticated, service_role;

-- Seeds do catálogo de módulos e planos (valores de exemplo; editáveis pelo master)
insert into public.modules (key, name, description, is_core, depends_on, position) values
  ('agenda',      'Agenda',                     'Dia, semana, bloqueios e agendamento',            true,  '{}', 10),
  ('clientes',    'Clientes',                   'Cadastro, perfil, notas e histórico',              true,  '{}', 20),
  ('catalogo',    'Catálogo',                   'Serviços, pacotes e preços',                       true,  '{}', 30),
  ('financeiro',  'Comandas e Financeiro',      'Comanda, caixa, contas, comissões',                true,  '{}', 40),
  ('anamnese',    'Anamnese',                   'Fichas, termos, tablet e link',                    true,  '{}', 50),
  ('mensagens',   'Mensagens',                  'WhatsApp, e-mail, modelos e automações',           false, '{}', 60),
  ('equipe',      'Equipe e comissões',         'Profissionais, horários e acessos',                false, '{}', 70),
  ('avaliacoes',  'Avaliações no Google',       'Agradecimento e pedido de avaliação',              false, '{mensagens}', 80),
  ('cobranca',    'Cobrança por transferência', 'Link com dados bancários e envio de comprovante',  false, '{}', 85),
  ('reserva',     'Reserva online',             'Página pública com horários livres',               false, '{}', 90),
  ('fidelidade',  'Fidelidade',                 'Pontos, níveis e recompensas',                     false, '{}', 100),
  ('marketing',   'Campanhas e segmentos',      'Aniversário, saudade, ofertas',                    false, '{mensagens}', 110),
  ('estoque',     'Estoque e compras',          'Produtos, insumos e fornecedores',                 false, '{}', 120),
  ('relatorios',  'Relatórios avançados e DRE', 'Por profissional, serviço e período',              false, '{}', 130),
  ('unidades',    'Várias unidades',            'Mais de um endereço na mesma conta',               false, '{}', 140)
on conflict (key) do nothing;

insert into public.plans (key, name, monthly_price_cents, limits, position) values
  ('basico',       'Básico',       2900, '{"staff": 1,  "automated_messages_month": 0,    "storage_gb": 2}',  10),
  ('profissional', 'Profissional', 5900, '{"staff": 3,  "automated_messages_month": 1000, "storage_gb": 5}',  20),
  ('completo',     'Completo',     9900, '{"staff": 10, "automated_messages_month": 5000, "storage_gb": 20}', 30)
on conflict (key) do nothing;

insert into public.plan_modules (plan_key, module_key, mode, extra_price_cents) values
  ('basico', 'mensagens', 'extra', 1200), ('basico', 'cobranca', 'extra', 500), ('basico', 'reserva', 'extra', 1500), ('basico', 'fidelidade', 'extra', 1200),
  ('profissional', 'mensagens', 'included', null), ('profissional', 'equipe', 'included', null), ('profissional', 'cobranca', 'included', null),
  ('profissional', 'avaliacoes', 'extra', 900), ('profissional', 'reserva', 'extra', 1500), ('profissional', 'fidelidade', 'extra', 1200),
  ('profissional', 'marketing', 'extra', 1500), ('profissional', 'estoque', 'extra', 1200),
  ('completo', 'mensagens', 'included', null), ('completo', 'equipe', 'included', null), ('completo', 'cobranca', 'included', null),
  ('completo', 'avaliacoes', 'included', null), ('completo', 'reserva', 'included', null), ('completo', 'fidelidade', 'included', null),
  ('completo', 'marketing', 'included', null), ('completo', 'estoque', 'included', null), ('completo', 'relatorios', 'included', null),
  ('completo', 'unidades', 'extra', 2900)
on conflict (plan_key, module_key) do nothing;

-- Estúdios existentes (piloto) entram no Completo: nada que já funciona deixa de aparecer.
insert into public.org_subscriptions (org_id, plan_key, status, notes)
select o.id, 'completo', 'active', 'Piloto: plano completo atribuído na migração de módulos'
from public.organizations o
on conflict (org_id) do nothing;

-- Novo estúdio ganha assinatura em teste no Profissional.
create or replace function public.tg_org_default_subscription()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
begin
  insert into public.org_subscriptions (org_id, plan_key, status, trial_ends_at)
  values (new.id, 'profissional', 'trial', now() + interval '30 days')
  on conflict (org_id) do nothing;
  return new;
end;
$$;
revoke all on function public.tg_org_default_subscription() from public, anon, authenticated;

drop trigger if exists trg_org_default_subscription on public.organizations;
create trigger trg_org_default_subscription
  after insert on public.organizations
  for each row execute function public.tg_org_default_subscription();

-- ─── 4. user_roles: concessão de papéis ─────────────────────
drop policy if exists "roles: admin gerencia" on public.user_roles;
drop policy if exists roles_manage_owner on public.user_roles;  -- fundação antiga 20260601*
drop policy if exists user_roles_insert on public.user_roles;
drop policy if exists user_roles_update on public.user_roles;
drop policy if exists user_roles_delete on public.user_roles;

-- owner concede qualquer papel; admin concede papéis operacionais
create policy user_roles_insert on public.user_roles for insert to authenticated
  with check (
    public.has_org_role(org_id, array['owner'])
    or (public.has_org_role(org_id, array['admin']) and role::text not in ('owner', 'admin'))
  );

create policy user_roles_update on public.user_roles for update to authenticated
  using (
    public.has_org_role(org_id, array['owner'])
    or (public.has_org_role(org_id, array['admin']) and role::text not in ('owner', 'admin'))
  )
  with check (
    public.has_org_role(org_id, array['owner'])
    or (public.has_org_role(org_id, array['admin']) and role::text not in ('owner', 'admin'))
  );

create policy user_roles_delete on public.user_roles for delete to authenticated
  using (
    public.has_org_role(org_id, array['owner'])
    or (public.has_org_role(org_id, array['admin']) and role::text not in ('owner', 'admin'))
  );

create or replace function public.tg_user_roles_guard()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_org uuid := coalesce(new.org_id, old.org_id);
  v_remaining int;
begin
  -- Exclusão do estúdio inteiro (cascata): nada a proteger.
  if tg_op = 'DELETE' and not exists (select 1 from public.organizations o where o.id = v_org) then
    return old;
  end if;

  -- Serializa mudanças de papel por estúdio (evita duas donas se removerem ao mesmo tempo).
  perform pg_advisory_xact_lock(hashtextextended('user_roles:' || v_org::text, 0));

  if tg_op = 'UPDATE' and (new.user_id <> old.user_id or new.org_id <> old.org_id) then
    raise exception 'Papel não muda de pessoa nem de estúdio; remova e conceda de novo' using errcode = '42501';
  end if;

  -- service_role e migrations (sem usuário) passam; regras valem para pessoas logadas
  if v_uid is not null then
    if tg_op in ('UPDATE', 'DELETE') and old.user_id = v_uid then
      raise exception 'Ninguém pode alterar o próprio papel' using errcode = '42501';
    end if;
    if tg_op = 'INSERT' and new.user_id = v_uid then
      raise exception 'Ninguém pode conceder papel a si mesmo' using errcode = '42501';
    end if;
  end if;

  if tg_op in ('UPDATE', 'DELETE') and old.role::text = 'owner' and old.active then
    select count(*) into v_remaining
    from public.user_roles ur
    where ur.org_id = v_org and ur.role::text = 'owner' and ur.active and ur.id <> old.id;
    if v_remaining = 0 and (tg_op = 'DELETE' or new.role::text <> 'owner' or not new.active) then
      raise exception 'O estúdio precisa de pelo menos uma proprietária ativa' using errcode = '23514';
    end if;
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;
revoke all on function public.tg_user_roles_guard() from public, anon, authenticated;

drop trigger if exists trg_user_roles_guard on public.user_roles;
create trigger trg_user_roles_guard
  before insert or update or delete on public.user_roles
  for each row execute function public.tg_user_roles_guard();

-- ─── 5. audit_logs: sem log em nome de outra pessoa ─────────
drop policy if exists audit_insert_member on public.audit_logs;
drop policy if exists audit_insert_any on public.audit_logs;    -- fundação antiga 20260601*
-- As funções atômicas (security invoker) gravam o log com auth.uid(); por isso o insert continua
-- aberto a membros, mas só no próprio nome.
create policy audit_insert_member on public.audit_logs for insert to authenticated
  with check (
    org_id in (select public.auth_org_ids())
    and user_id = (select auth.uid())
  );
revoke update, delete, truncate on public.audit_logs from anon, authenticated;

-- ─── 6. Auditoria automática de acesso, plano e módulos ─────
create or replace function public.tg_audit_access_change()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_org uuid;
  v_row jsonb := to_jsonb(coalesce(new, old));
begin
  v_org := (v_row ->> 'org_id')::uuid;
  -- Estúdio sendo excluído: não há onde registrar.
  if not exists (select 1 from public.organizations o where o.id = v_org) then
    return coalesce(new, old);
  end if;
  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (
    v_org,
    (select auth.uid()),
    tg_table_name,
    tg_op,
    case when v_row ? 'id' then (v_row ->> 'id')::uuid else null end,
    case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end,
    case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end
  );
  return coalesce(new, old);
end;
$$;
revoke all on function public.tg_audit_access_change() from public, anon, authenticated;

drop trigger if exists trg_audit_user_roles on public.user_roles;
create trigger trg_audit_user_roles after insert or update or delete on public.user_roles
  for each row execute function public.tg_audit_access_change();

drop trigger if exists trg_audit_org_subscriptions on public.org_subscriptions;
create trigger trg_audit_org_subscriptions after insert or update or delete on public.org_subscriptions
  for each row execute function public.tg_audit_access_change();

drop trigger if exists trg_audit_org_modules on public.org_modules;
create trigger trg_audit_org_modules after insert or update or delete on public.org_modules
  for each row execute function public.tg_audit_access_change();

-- ─── 7. anon não executa funções de negócio ─────────────────
-- Exceções: o link público da anamnese (token com validade) é usado sem login.
-- O revoke inclui PUBLIC porque o Postgres concede EXECUTE a PUBLIC por padrão.
do $$
declare
  f record;
begin
  for f in
    select p.oid::regprocedure as sig,
           has_function_privilege('authenticated', p.oid, 'execute') as auth_had
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
      and p.prokind = 'f'
      and p.proname not in ('get_anamnese_by_token', 'submit_anamnese_signature',
                            -- link público de cobrança (20261029020000), se a migration rodar de novo
                            'get_payment_request_by_token')
  loop
    execute format('revoke execute on function %s from public, anon', f.sig);
    -- Preserva quem já podia: authenticated só volta a ter acesso se já tinha antes
    -- (funções *_internal continuam fechadas).
    if f.auth_had then
      execute format('grant execute on function %s to authenticated', f.sig);
    end if;
    execute format('grant execute on function %s to service_role', f.sig);
  end loop;
end $$;

-- Funções criadas daqui em diante não ficam executáveis por anon nem por PUBLIC sem grant explícito.
alter default privileges in schema public revoke execute on functions from anon;
alter default privileges revoke execute on functions from public;
