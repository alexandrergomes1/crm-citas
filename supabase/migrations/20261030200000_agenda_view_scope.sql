-- Agenda: quem vê o quê (agenda.view_all x agenda.view_own) também no banco.
-- Encoding: UTF-8
set client_encoding = 'UTF8';
--
-- Até aqui as duas liberações eram só texto na tela: a leitura de appointments, time_blocks,
-- appointment_items, appointment_deposits e appointment_status_history valia para qualquer
-- membro do estúdio. Agora:
--   * agenda.view_all (ou agenda.manage, comanda.operate, financeiro.view, que precisam dos
--     agendamentos para trabalhar) lê tudo do estúdio;
--   * só agenda.view_own lê os agendamentos da profissional ligada à pessoa
--     (staff_members.user_id = auth.uid()) e os bloqueios dela e do estúdio inteiro;
--   * sem nenhuma dessas, não lê a agenda.
-- Aditiva e compatível com o app antigo: quem tem papel padrão com view_all (dona, administração,
-- gestão, recepção, financeiro, leitura) não percebe diferença. A profissional (só view_own)
-- passa a ver apenas os próprios atendimentos; para não deixar ninguém sem agenda no dia do
-- deploy, a profissional que ainda não tem ligação é ligada pelo e-mail (mesmo e-mail da conta
-- e do cadastro da equipe, no mesmo estúdio).

-- 1. Funções de apoio (executadas uma vez por consulta, não por linha) ---------------------------
create or replace function public.agenda_full_view_orgs()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select o.org_id
  from (
    select distinct ur.org_id
    from public.user_roles ur
    where ur.user_id = (select auth.uid()) and ur.active = true
  ) o
  where public.has_permission(o.org_id, 'agenda.view_all')
     or public.has_permission(o.org_id, 'agenda.manage')
     or public.has_permission(o.org_id, 'comanda.operate')
     or public.has_permission(o.org_id, 'financeiro.view');
$$;

create or replace function public.agenda_own_view_orgs()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select o.org_id
  from (
    select distinct ur.org_id
    from public.user_roles ur
    where ur.user_id = (select auth.uid()) and ur.active = true
  ) o
  where public.has_permission(o.org_id, 'agenda.view_own');
$$;

create or replace function public.agenda_my_staff_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select sm.id from public.staff_members sm where sm.user_id = (select auth.uid());
$$;

revoke all on function public.agenda_full_view_orgs() from public, anon;
revoke all on function public.agenda_own_view_orgs() from public, anon;
revoke all on function public.agenda_my_staff_ids() from public, anon;
grant execute on function public.agenda_full_view_orgs() to authenticated, service_role;
grant execute on function public.agenda_own_view_orgs() to authenticated, service_role;
grant execute on function public.agenda_my_staff_ids() to authenticated, service_role;

-- 2. Políticas de leitura ----------------------------------------------------------------------
drop policy if exists "appointments: ver" on public.appointments;
create policy "appointments: ver" on public.appointments for select to authenticated
  using (
    org_id in (select public.agenda_full_view_orgs())
    or (org_id in (select public.agenda_own_view_orgs()) and staff_id in (select public.agenda_my_staff_ids()))
  );

drop policy if exists "time_blocks_select" on public.time_blocks;
create policy "time_blocks_select" on public.time_blocks for select to authenticated
  using (
    org_id in (select public.agenda_full_view_orgs())
    or (
      org_id in (select public.agenda_own_view_orgs())
      and (staff_id is null or staff_id in (select public.agenda_my_staff_ids()))
    )
  );

-- Itens, sinais e histórico seguem o agendamento (a consulta ao agendamento já passa pela política acima).
drop policy if exists "appt_items: ver" on public.appointment_items;
create policy "appt_items: ver" on public.appointment_items for select to authenticated
  using (exists (
    select 1 from public.appointments a
    where a.id = appointment_items.appointment_id and a.org_id = appointment_items.org_id
  ));

drop policy if exists "appointment_deposits_select" on public.appointment_deposits;
create policy "appointment_deposits_select" on public.appointment_deposits for select to authenticated
  using (exists (
    select 1 from public.appointments a
    where a.id = appointment_deposits.appointment_id and a.org_id = appointment_deposits.org_id
  ));

drop policy if exists "appt_history: ver" on public.appointment_status_history;
create policy "appt_history: ver" on public.appointment_status_history for select to authenticated
  using (exists (
    select 1 from public.appointments a
    where a.id = appointment_status_history.appointment_id and a.org_id = appointment_status_history.org_id
  ));

-- 3. Gatilhos de integridade não dependem de quem escreve ---------------------------------------------
-- Estes gatilhos conferem se o agendamento pertence ao estúdio (e se já está fechado) lendo
-- appointments. Como invoker, quem só tem agenda.view_own deixaria de "ver" os agendamentos das
-- colegas: a profissional preencheria a ficha profissional de um atendimento que não é dela e
-- falharia, e a trava de agendamento fechado deixaria passar o que não enxerga. Rodam como dono,
-- igual às funções de trava da ficha (get_appointment_anamnese_gate).
alter function public.enforce_anamnese_relation_integrity() security definer;
alter function public.enforce_anamnese_relation_integrity() set search_path = '';
alter function public.enforce_appointment_item_integrity() security definer;
alter function public.enforce_appointment_item_integrity() set search_path = '';
alter function public.lock_closed_appointment_items() security definer;
alter function public.lock_closed_appointment_items() set search_path = '';
revoke all on function public.enforce_anamnese_relation_integrity() from public, anon, authenticated;
revoke all on function public.enforce_appointment_item_integrity() from public, anon, authenticated;
revoke all on function public.lock_closed_appointment_items() from public, anon, authenticated;

-- 4. Ligação por e-mail para quem ainda não tem profissional ligada ---------------------------
-- Uma profissional por conta e estúdio; só entra quem tem papel ativo no mesmo estúdio.
update public.staff_members sm
set user_id = pick.user_id
from (
  select distinct on (u.id, sm2.org_id) sm2.id as staff_id, u.id as user_id
  from public.staff_members sm2
  join auth.users u on lower(u.email) = lower(sm2.email)
  join public.user_roles ur on ur.user_id = u.id and ur.org_id = sm2.org_id and ur.active = true
  where sm2.user_id is null
    and sm2.email is not null and btrim(sm2.email) <> ''
    and not exists (
      select 1 from public.staff_members linked
      where linked.org_id = sm2.org_id and linked.user_id = u.id
    )
  order by u.id, sm2.org_id, sm2.active desc, sm2.position, sm2.id
) pick
where sm.id = pick.staff_id;
