-- Forçar encaixe sobre conflito de horário vira liberação configurável (spec 37).
-- Encoding: UTF-8
--
-- Antes: lista fixa owner/admin/manager nas 4 RPCs da agenda e no app. Agora
-- agenda.override_conflict, com o mesmo padrão; a dona pode liberar para a recepção.

create or replace function public.role_default_permissions()
returns table (role text, permission text)
language sql
immutable
set search_path = ''
as $$
  select r.role, p.permission
  from (values
    ('owner', array['agenda.view_all', 'agenda.view_own', 'agenda.manage', 'agenda.block_time', 'agenda.override_conflict', 'clientes.view', 'clientes.manage', 'clientes.view_clinical', 'catalogo.view', 'catalogo.manage', 'comanda.operate', 'comanda.refund', 'financeiro.view', 'financeiro.manage', 'anamnese.view_status', 'anamnese.fill_professional', 'anamnese.manage_templates', 'anamnese.override_checkout_gate', 'mensagens.use', 'mensagens.configure', 'equipe.view', 'equipe.manage', 'acesso.manage', 'acesso.grant_admin', 'ajustes.manage']),
    ('admin', array['agenda.view_all', 'agenda.view_own', 'agenda.manage', 'agenda.block_time', 'agenda.override_conflict', 'clientes.view', 'clientes.manage', 'clientes.view_clinical', 'catalogo.view', 'catalogo.manage', 'comanda.operate', 'comanda.refund', 'financeiro.view', 'financeiro.manage', 'anamnese.view_status', 'anamnese.fill_professional', 'anamnese.manage_templates', 'anamnese.override_checkout_gate', 'mensagens.use', 'mensagens.configure', 'equipe.view', 'equipe.manage', 'acesso.manage', 'ajustes.manage']),
    ('manager', array['agenda.view_all', 'agenda.view_own', 'agenda.manage', 'agenda.block_time', 'agenda.override_conflict', 'clientes.view', 'clientes.manage', 'clientes.view_clinical', 'catalogo.view', 'catalogo.manage', 'comanda.operate', 'comanda.refund', 'financeiro.view', 'financeiro.manage', 'anamnese.view_status', 'anamnese.fill_professional', 'anamnese.manage_templates', 'anamnese.override_checkout_gate', 'mensagens.use', 'mensagens.configure', 'equipe.view', 'equipe.manage']),
    ('receptionist', array['agenda.view_all', 'agenda.view_own', 'agenda.manage', 'agenda.block_time', 'clientes.view', 'clientes.manage', 'catalogo.view', 'comanda.operate', 'anamnese.view_status', 'mensagens.use', 'equipe.view']),
    ('professional', array['agenda.view_own', 'agenda.block_time', 'clientes.view', 'clientes.view_clinical', 'catalogo.view', 'anamnese.view_status', 'anamnese.fill_professional', 'mensagens.use']),
    ('finance', array['agenda.view_all', 'clientes.view', 'catalogo.view', 'comanda.operate', 'comanda.refund', 'financeiro.view', 'financeiro.manage', 'equipe.view']),
    ('viewer', array['agenda.view_all', 'clientes.view', 'catalogo.view', 'equipe.view'])
  ) as r(role, perms),
  unnest(r.perms) as p(permission);
$$;

do $rewrite$
declare
  r record;
  v_def text;
  v_count integer;
  v_pattern constant text := 'if\s+p_force_override\s+and\s+v_role\s+not\s+in\s*\([^)]*\)\s+then';
begin
  for r in
    select unnest(array['create_appointment_atomic', 'create_recurring_appointments_atomic',
                        'update_appointment_atomic', 'update_recurrence_series_atomic']) as fn
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
    execute regexp_replace(v_def, v_pattern,
      'if p_force_override and not public.has_permission(p_org_id, ''agenda.override_conflict'') then');
  end loop;
end;
$rewrite$;
