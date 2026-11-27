-- Liberar o fechamento da comanda sem a avaliação da profissional, com motivo (spec 12).
-- Encoding: UTF-8
--
-- Decisão do Alexandre (29 out): a assinatura da cliente continua trava dura para iniciar; a
-- avaliação profissional pendente não trava mais o caixa sem saída. Quem tem
-- anamnese.override_checkout_gate (padrão: proprietária, administração, gestão) libera com
-- motivo, registrado em anamnese_gate_overrides e audit_logs.

-- 1. Padrão por papel com a nova liberação ---------------------------------------------------
create or replace function public.role_default_permissions()
returns table (role text, permission text)
language sql
immutable
set search_path = ''
as $$
  select r.role, p.permission
  from (values
    ('owner', array['agenda.view_all', 'agenda.view_own', 'agenda.manage', 'agenda.block_time', 'clientes.view', 'clientes.manage', 'clientes.view_clinical', 'catalogo.view', 'catalogo.manage', 'comanda.operate', 'comanda.refund', 'financeiro.view', 'financeiro.manage', 'anamnese.view_status', 'anamnese.fill_professional', 'anamnese.manage_templates', 'anamnese.override_checkout_gate', 'mensagens.use', 'mensagens.configure', 'equipe.view', 'equipe.manage', 'acesso.manage', 'acesso.grant_admin', 'ajustes.manage']),
    ('admin', array['agenda.view_all', 'agenda.view_own', 'agenda.manage', 'agenda.block_time', 'clientes.view', 'clientes.manage', 'clientes.view_clinical', 'catalogo.view', 'catalogo.manage', 'comanda.operate', 'comanda.refund', 'financeiro.view', 'financeiro.manage', 'anamnese.view_status', 'anamnese.fill_professional', 'anamnese.manage_templates', 'anamnese.override_checkout_gate', 'mensagens.use', 'mensagens.configure', 'equipe.view', 'equipe.manage', 'acesso.manage', 'ajustes.manage']),
    ('manager', array['agenda.view_all', 'agenda.view_own', 'agenda.manage', 'agenda.block_time', 'clientes.view', 'clientes.manage', 'clientes.view_clinical', 'catalogo.view', 'catalogo.manage', 'comanda.operate', 'comanda.refund', 'financeiro.view', 'financeiro.manage', 'anamnese.view_status', 'anamnese.fill_professional', 'anamnese.manage_templates', 'anamnese.override_checkout_gate', 'mensagens.use', 'mensagens.configure', 'equipe.view', 'equipe.manage']),
    ('receptionist', array['agenda.view_all', 'agenda.view_own', 'agenda.manage', 'agenda.block_time', 'clientes.view', 'clientes.manage', 'catalogo.view', 'comanda.operate', 'anamnese.view_status', 'mensagens.use', 'equipe.view']),
    ('professional', array['agenda.view_own', 'agenda.block_time', 'clientes.view', 'clientes.view_clinical', 'catalogo.view', 'anamnese.view_status', 'anamnese.fill_professional', 'mensagens.use']),
    ('finance', array['agenda.view_all', 'clientes.view', 'catalogo.view', 'comanda.operate', 'comanda.refund', 'financeiro.view', 'financeiro.manage', 'equipe.view']),
    ('viewer', array['agenda.view_all', 'clientes.view', 'catalogo.view', 'equipe.view'])
  ) as r(role, perms),
  unnest(r.perms) as p(permission);
$$;

-- 2. Registro das liberações ------------------------------------------------------------------
create table if not exists public.anamnese_gate_overrides (
  id             uuid        primary key default gen_random_uuid(),
  org_id         uuid        not null references public.organizations(id) on delete cascade,
  appointment_id uuid        not null,
  anamnese_id    uuid        not null references public.anamneses(id) on delete cascade,
  reason         text        not null check (char_length(btrim(reason)) between 5 and 300),
  created_by     uuid        references auth.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  constraint anamnese_gate_overrides_appointment_same_org
    foreign key (appointment_id, org_id) references public.appointments (id, org_id) on delete cascade,
  unique (org_id, appointment_id, anamnese_id)
);
comment on table public.anamnese_gate_overrides is
  'Fechamento de comanda liberado sem a avaliação profissional da ficha (spec 12). Só por função.';
create index if not exists idx_anamnese_gate_overrides_anamnese on public.anamnese_gate_overrides (anamnese_id);
create index if not exists idx_anamnese_gate_overrides_created_by on public.anamnese_gate_overrides (created_by);

alter table public.anamnese_gate_overrides enable row level security;
revoke all on public.anamnese_gate_overrides from anon;
revoke insert, update, delete, truncate, trigger, references on public.anamnese_gate_overrides from authenticated;
drop policy if exists anamnese_gate_overrides_select on public.anamnese_gate_overrides;
create policy anamnese_gate_overrides_select on public.anamnese_gate_overrides for select to authenticated
  using (public.has_permission(org_id, 'anamnese.view_status'));

-- 3. Trava do fechamento ignora a pendência profissional liberada -----------------------------
do $rewrite$
declare
  v_def text;
  v_count integer;
  v_pattern constant text := '(and\s+an\.professional_completed_at\s+is\s+null)(\s+then\s+''PROFESSIONAL_PENDING'')';
begin
  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p
  where p.pronamespace = 'public'::regnamespace and p.proname = 'get_appointment_anamnese_gate';
  if v_def is null then
    raise exception 'Funcao get_appointment_anamnese_gate nao encontrada';
  end if;
  select count(*) into v_count from regexp_matches(v_def, v_pattern, 'g');
  if v_count <> 2 then
    raise exception 'get_appointment_anamnese_gate: padrao encontrado % vez(es), esperado 2', v_count;
  end if;
  execute regexp_replace(v_def, v_pattern,
    '\1 and not exists (select 1 from public.anamnese_gate_overrides o where o.org_id = p_org_id and o.appointment_id = p_appointment_id and o.anamnese_id = an.id)\2',
    'g');
end;
$rewrite$;

-- 4. Liberar com motivo -------------------------------------------------------------------------
create or replace function public.override_anamnese_checkout_gate(
  p_org_id uuid, p_appointment_id uuid, p_reason text
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text := pg_catalog.btrim(coalesce(p_reason, ''));
  v_count integer := 0;
begin
  if not public.has_permission(p_org_id, 'anamnese.override_checkout_gate') then
    raise exception 'Sem permissao para liberar o fechamento sem a avaliacao' using errcode = '42501';
  end if;
  if pg_catalog.char_length(v_reason) < 5 or pg_catalog.char_length(v_reason) > 300 then
    raise exception 'Escreva o motivo (de 5 a 300 caracteres)' using errcode = '22023';
  end if;
  if not exists (select 1 from public.appointments a where a.id = p_appointment_id and a.org_id = p_org_id) then
    raise exception 'Agendamento nao encontrado' using errcode = 'P0002';
  end if;

  insert into public.anamnese_gate_overrides (org_id, appointment_id, anamnese_id, reason, created_by)
  select p_org_id, p_appointment_id, an.id, v_reason, (select auth.uid())
  from public.anamneses an
  where an.org_id = p_org_id
    and an.appointment_id = p_appointment_id
    and an.status = 'signed'
    and an.requires_professional
    and an.professional_completed_at is null
  on conflict (org_id, appointment_id, anamnese_id) do nothing;
  get diagnostics v_count = row_count;

  if v_count = 0 then
    raise exception 'Nao ha avaliacao profissional pendente para liberar neste atendimento' using errcode = 'P0001';
  end if;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
  values (p_org_id, (select auth.uid()), 'appointments', 'ANAMNESE_GATE_OVERRIDE', p_appointment_id,
          pg_catalog.jsonb_build_object('reason', v_reason, 'fichas', v_count));
  return v_count;
end;
$$;

revoke all on function public.override_anamnese_checkout_gate(uuid, uuid, text) from public, anon;
grant execute on function public.override_anamnese_checkout_gate(uuid, uuid, text) to authenticated;
