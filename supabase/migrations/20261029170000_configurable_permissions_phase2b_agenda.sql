-- Perfis e liberações configuráveis, fase 2b (spec 37): agenda.
-- Encoding: UTF-8
--
-- 1. Nova liberação agenda.block_time (bloquear horários). Padrão = quem já podia: owner, admin,
--    manager, receptionist e professional. Profissional segue podendo bloquear o próprio horário.
-- 2. Escritas da agenda (criar, editar, reagendar, status, série, itens) passam a exigir
--    agenda.manage. Antes as RPCs e a política de UPDATE aceitavam 'professional' (divergência 1
--    do spec 37): o padrão agora é igual à matriz e a dona pode ligar para a profissional.
-- 3. A política de INSERT de appointments só exigia ser membro do estúdio (até 'viewer' inseria
--    direto pela API); passa a exigir agenda.manage.

-- 1. Padrão por papel (com agenda.block_time) -----------------------------------------------------
create or replace function public.role_default_permissions()
returns table (role text, permission text)
language sql
immutable
set search_path = ''
as $$
  select r.role, p.permission
  from (values
    ('owner', array['agenda.view_all', 'agenda.view_own', 'agenda.manage', 'agenda.block_time', 'clientes.view', 'clientes.manage', 'clientes.view_clinical', 'catalogo.view', 'catalogo.manage', 'comanda.operate', 'comanda.refund', 'financeiro.view', 'financeiro.manage', 'anamnese.view_status', 'anamnese.fill_professional', 'anamnese.manage_templates', 'mensagens.use', 'mensagens.configure', 'equipe.view', 'equipe.manage', 'acesso.manage', 'acesso.grant_admin', 'ajustes.manage']),
    ('admin', array['agenda.view_all', 'agenda.view_own', 'agenda.manage', 'agenda.block_time', 'clientes.view', 'clientes.manage', 'clientes.view_clinical', 'catalogo.view', 'catalogo.manage', 'comanda.operate', 'comanda.refund', 'financeiro.view', 'financeiro.manage', 'anamnese.view_status', 'anamnese.fill_professional', 'anamnese.manage_templates', 'mensagens.use', 'mensagens.configure', 'equipe.view', 'equipe.manage', 'acesso.manage', 'ajustes.manage']),
    ('manager', array['agenda.view_all', 'agenda.view_own', 'agenda.manage', 'agenda.block_time', 'clientes.view', 'clientes.manage', 'clientes.view_clinical', 'catalogo.view', 'catalogo.manage', 'comanda.operate', 'comanda.refund', 'financeiro.view', 'financeiro.manage', 'anamnese.view_status', 'anamnese.fill_professional', 'anamnese.manage_templates', 'mensagens.use', 'mensagens.configure', 'equipe.view', 'equipe.manage']),
    ('receptionist', array['agenda.view_all', 'agenda.view_own', 'agenda.manage', 'agenda.block_time', 'clientes.view', 'clientes.manage', 'catalogo.view', 'comanda.operate', 'anamnese.view_status', 'mensagens.use', 'equipe.view']),
    ('professional', array['agenda.view_own', 'agenda.block_time', 'clientes.view', 'clientes.view_clinical', 'catalogo.view', 'anamnese.view_status', 'anamnese.fill_professional', 'mensagens.use']),
    ('finance', array['agenda.view_all', 'clientes.view', 'catalogo.view', 'comanda.operate', 'comanda.refund', 'financeiro.view', 'financeiro.manage', 'equipe.view']),
    ('viewer', array['agenda.view_all', 'clientes.view', 'catalogo.view', 'equipe.view'])
  ) as r(role, perms),
  unnest(r.perms) as p(permission);
$$;

-- 2. RPCs da agenda -----------------------------------------------------------------------------
do $rewrite$
declare
  r record;
  v_def text;
  v_count integer;
  v_pattern constant text := 'if\s+v_role\s+is\s+null\s+or\s+v_role\s+not\s+in\s*\([^)]*\)\s+then';
begin
  for r in
    select * from (values
      ('cancel_recurrence_series_atomic', 'agenda.manage'),
      ('create_appointment_atomic', 'agenda.manage'),
      ('create_recurring_appointments_atomic', 'agenda.manage'),
      ('reschedule_appointment_atomic', 'agenda.manage'),
      ('set_appointment_status_atomic', 'agenda.manage'),
      ('update_appointment_atomic', 'agenda.manage'),
      ('update_appointment_item_atomic', 'agenda.manage'),
      ('update_recurrence_series_atomic', 'agenda.manage'),
      ('create_time_blocks_atomic', 'agenda.block_time'),
      ('delete_time_block_atomic', 'agenda.block_time')
    ) as t(fn, perm)
  loop
    select pg_get_functiondef(p.oid) into v_def
    from pg_proc p
    where p.pronamespace = 'public'::regnamespace and p.proname = r.fn;
    if v_def is null then
      raise exception 'Funcao % nao encontrada', r.fn;
    end if;
    select count(*) into v_count from regexp_matches(v_def, v_pattern, 'g');
    if v_count <> 1 then
      raise exception 'Funcao %: padrao encontrado % vez(es), esperado 1', r.fn, v_count;
    end if;
    execute regexp_replace(v_def, v_pattern, format('if not public.has_permission(p_org_id, %L) then', r.perm));
  end loop;
end;
$rewrite$;

-- 3. Políticas -----------------------------------------------------------------------------------
drop policy if exists "appointments: criar" on public.appointments;
create policy "appointments: criar" on public.appointments for insert to authenticated
  with check (public.has_permission(org_id, 'agenda.manage'));

drop policy if exists "appointments: editar" on public.appointments;
create policy "appointments: editar" on public.appointments for update to authenticated
  using (public.has_permission(org_id, 'agenda.manage'));

drop policy if exists "appt_items: inserir" on public.appointment_items;
create policy "appt_items: inserir" on public.appointment_items for insert to authenticated
  with check (public.has_permission(org_id, 'agenda.manage'));
drop policy if exists "appt_items: alterar" on public.appointment_items;
create policy "appt_items: alterar" on public.appointment_items for update to authenticated
  using (public.has_permission(org_id, 'agenda.manage'))
  with check (public.has_permission(org_id, 'agenda.manage'));
drop policy if exists "appt_items: apagar" on public.appointment_items;
create policy "appt_items: apagar" on public.appointment_items for delete to authenticated
  using (public.has_permission(org_id, 'agenda.manage'));

drop policy if exists time_blocks_insert on public.time_blocks;
create policy time_blocks_insert on public.time_blocks for insert to authenticated
  with check (public.has_permission(org_id, 'agenda.block_time'));
drop policy if exists time_blocks_update on public.time_blocks;
create policy time_blocks_update on public.time_blocks for update to authenticated
  using (public.has_permission(org_id, 'agenda.block_time'))
  with check (public.has_permission(org_id, 'agenda.block_time'));
drop policy if exists time_blocks_delete on public.time_blocks;
create policy time_blocks_delete on public.time_blocks for delete to authenticated
  using (public.has_permission(org_id, 'agenda.block_time'));
