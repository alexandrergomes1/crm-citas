-- Dados do E2E na CI (Supabase local, nunca produção). Encoding: UTF-8
-- Variáveis: :owner_id e :recep_id (usuários criados pela API de admin do Auth local).
\set ON_ERROR_STOP 1

insert into public.organizations (id, slug, name, timezone, currency, locale)
values ('0e2e0000-0000-4000-8000-000000000001', 'e2e-studio', 'Estúdio E2E', 'Europe/Madrid', 'EUR', 'pt-BR');

insert into public.user_roles (user_id, org_id, role) values
  (:'owner_id', '0e2e0000-0000-4000-8000-000000000001', 'owner'),
  (:'recep_id', '0e2e0000-0000-4000-8000-000000000001', 'receptionist');

-- Perfil da dona no estúdio: a função que grava nota da cliente exige o perfil do autor.
insert into public.profiles (user_id, org_id, full_name)
values (:'owner_id', '0e2e0000-0000-4000-8000-000000000001', 'Dona E2E')
on conflict (user_id, org_id) do nothing;

insert into public.staff_members (id, org_id, name, active)
values ('0e2e0000-0000-4000-8000-000000000010', '0e2e0000-0000-4000-8000-000000000001', 'Ana E2E', true);
insert into public.services (id, org_id, name, price, duration_minutes, active)
values ('0e2e0000-0000-4000-8000-000000000020', '0e2e0000-0000-4000-8000-000000000001', 'Limpeza de pele', 80, 60, true);
insert into public.clients (id, org_id, full_name, phone)
values ('0e2e0000-0000-4000-8000-000000000030', '0e2e0000-0000-4000-8000-000000000001', 'Lucía Prado', '+34600000000');

-- Agendamento concluído (pronto para cobrar), criado pelas funções reais como a dona.
select set_config('request.jwt.claims', json_build_object('sub', :'owner_id', 'role', 'authenticated')::text, false);
set role authenticated;
select public.create_appointment_atomic(
  '0e2e0000-0000-4000-8000-000000000001', '0e2e0000-0000-4000-8000-000000000030', '0e2e0000-0000-4000-8000-000000000010',
  date_trunc('day', now()) + interval '9 hours', date_trunc('day', now()) + interval '10 hours', 60, 'Confirmado', 'MANUAL', null, null, 80,
  '[{"service_id":"0e2e0000-0000-4000-8000-000000000020","service_name":"Limpeza de pele","price":80}]'::jsonb, false
) as appointment_id \gset
select public.set_appointment_status_atomic('0e2e0000-0000-4000-8000-000000000001', :'appointment_id', 'Iniciado');
select public.set_appointment_status_atomic('0e2e0000-0000-4000-8000-000000000001', :'appointment_id', 'Concluído');
reset role;

\echo E2E_CHECKOUT_APPOINTMENT_ID=:appointment_id

-- Ficha de anamnese com link público (sem atendimento, para não travar a cobrança acima).
insert into public.anamnese_templates (id, org_id, title, questions)
values ('0e2e0000-0000-4000-8000-000000000040', '0e2e0000-0000-4000-8000-000000000001', 'Ficha E2E',
        '[{"id":"q1","type":"text","text":"Tem alguma alergia?","required":true}]'::jsonb);
select set_config('request.jwt.claims', json_build_object('sub', :'owner_id', 'role', 'authenticated')::text, false);
set role authenticated;
select (public.create_anamnese_atomic(
  '0e2e0000-0000-4000-8000-000000000001', '0e2e0000-0000-4000-8000-000000000040',
  '0e2e0000-0000-4000-8000-000000000030', 'Lucía Prado', null, false
)).public_token as anamnese_token \gset
reset role;

\echo E2E_ANAMNESE_TOKEN=:anamnese_token

-- Plano completo no estúdio do E2E: liga Mensagens, Avaliações e os demais módulos pagos.
insert into public.org_subscriptions (org_id, plan_key, status)
values ('0e2e0000-0000-4000-8000-000000000001', 'completo', 'active')
on conflict (org_id) do update set plan_key = 'completo', status = 'active';
