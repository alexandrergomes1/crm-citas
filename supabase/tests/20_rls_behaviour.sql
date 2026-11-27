-- ============================================================
-- Comportamento de RLS, papéis e módulos com usuários simulados.
-- Roda numa transação e desfaz tudo no fim.
-- Encoding: UTF-8
-- ============================================================
\set ON_ERROR_STOP 1
\o /dev/null
begin;

-- ─── fixtures (como postgres, sem usuário logado) ───────────
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'dona-a@teste.local'),
  ('00000000-0000-0000-0000-0000000000a2', 'admin-a@teste.local'),
  ('00000000-0000-0000-0000-0000000000a3', 'prof-a@teste.local'),
  ('00000000-0000-0000-0000-0000000000a4', 'nova-a@teste.local'),
  ('00000000-0000-0000-0000-0000000000b1', 'dona-b@teste.local'),
  ('00000000-0000-0000-0000-0000000000f1', 'master@teste.local');

insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-00000000000a', 'teste-a', 'Estúdio A'),
  ('00000000-0000-0000-0000-00000000000b', 'teste-b', 'Estúdio B');

insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000000a', 'owner'),
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-00000000000a', 'admin'),
  ('00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-00000000000a', 'professional'),
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-00000000000b', 'owner');

insert into public.clients (org_id, full_name) values
  ('00000000-0000-0000-0000-00000000000a', 'Cliente A'),
  ('00000000-0000-0000-0000-00000000000b', 'Cliente B');

insert into public.platform_admins (user_id) values ('00000000-0000-0000-0000-0000000000f1');

create function pg_temp.login(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

create function pg_temp.expect(p_ok boolean, p_msg text) returns void language plpgsql as $$
begin
  if not coalesce(p_ok, false) then raise exception 'FALHOU: %', p_msg; end if;
end $$;

grant execute on function pg_temp.login(uuid), pg_temp.expect(boolean, text) to authenticated;

-- ─── 1. isolamento entre estúdios ───────────────────────────
select pg_temp.login('00000000-0000-0000-0000-0000000000a1');
select pg_temp.expect((select count(*) from public.clients) = 1, 'dona A vê só a própria cliente');
select pg_temp.expect((select count(*) from public.clients where org_id = '00000000-0000-0000-0000-00000000000b') = 0, 'dona A não vê clientes do B');
reset role;
select set_config('request.jwt.claims', '', true);

select pg_temp.login('00000000-0000-0000-0000-0000000000b1');
select pg_temp.expect((select count(*) from public.clients where full_name = 'Cliente A') = 0, 'dona B não vê Cliente A');
do $$ begin
  update public.clients set full_name = 'invadido' where org_id = '00000000-0000-0000-0000-00000000000a';
  perform pg_temp.expect((select count(*) from public.clients where full_name = 'invadido') = 0, 'dona B não altera cliente do A');
end $$;
reset role;
select set_config('request.jwt.claims', '', true);

-- ─── 2. concessão de papéis ────────────────────────────────
-- Desde 20261114060500 ninguém logado grava user_roles direto pela API (só pelas funções team_grant_access e
-- assign_user_profile, testadas em 154): nem owner para a administração, nem papel operacional.
select pg_temp.login('00000000-0000-0000-0000-0000000000a2');
do $$ begin
  begin
    insert into public.user_roles (user_id, org_id, role) values ('00000000-0000-0000-0000-0000000000a4', '00000000-0000-0000-0000-00000000000a', 'owner');
    raise exception 'FALHOU: admin concedeu owner';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.user_roles (user_id, org_id, role) values ('00000000-0000-0000-0000-0000000000a4', '00000000-0000-0000-0000-00000000000a', 'receptionist');
    raise exception 'FALHOU: admin gravou user_roles direto pela API';
  exception when insufficient_privilege then null; end;
end $$;
do $$ begin
  begin
    update public.user_roles set role = 'owner' where user_id = '00000000-0000-0000-0000-0000000000a2';
    if found then raise exception 'FALHOU: admin promoveu a si mesmo'; end if;
  exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claims', '', true);

select pg_temp.login('00000000-0000-0000-0000-0000000000a1');
do $$ begin
  begin
    update public.user_roles set active = false where user_id = '00000000-0000-0000-0000-0000000000a1';
    raise exception 'FALHOU: dona desativou o próprio acesso';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claims', '', true);

-- última proprietária ativa (mesmo sem usuário logado)
do $$ begin
  begin
    update public.user_roles set active = false where user_id = '00000000-0000-0000-0000-0000000000a1';
    raise exception 'FALHOU: estúdio ficou sem proprietária';
  exception when check_violation then null; end;
end $$;

-- O caminho que vale: a dona dá o acesso pela função do banco (conta nova, sem papel em nenhum estúdio).
select pg_temp.login('00000000-0000-0000-0000-0000000000a1');
select public.team_grant_access('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a4', 'Nova A', 'receptionist', null);
reset role;
select set_config('request.jwt.claims', '', true);
select pg_temp.expect((select count(*) from public.audit_logs where table_name = 'user_roles' and org_id = '00000000-0000-0000-0000-00000000000a') >= 4, 'mudanças de papel ficam na auditoria');

-- ─── 3. módulos e planos ───────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-0000000000a1');
select pg_temp.expect((select status from public.org_subscriptions where org_id = '00000000-0000-0000-0000-00000000000a') = 'trial', 'estúdio novo entra em teste');
select pg_temp.expect(public.org_has_module('00000000-0000-0000-0000-00000000000a', 'agenda'), 'core sempre ligado');
select pg_temp.expect(public.org_has_module('00000000-0000-0000-0000-00000000000a', 'mensagens'), 'Profissional inclui Mensagens');
select pg_temp.expect(not public.org_has_module('00000000-0000-0000-0000-00000000000a', 'avaliacoes'), 'Avaliações é extra no Profissional');
do $$ begin
  begin
    insert into public.org_modules (org_id, module_key) values ('00000000-0000-0000-0000-00000000000a', 'avaliacoes');
    raise exception 'FALHOU: estúdio ligou extra sozinho';
  exception when insufficient_privilege then null; end;
end $$;
do $$ begin
  begin
    perform public.org_enabled_modules('00000000-0000-0000-0000-00000000000b');
    raise exception 'FALHOU: dona A leu módulos do B';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claims', '', true);

select pg_temp.login('00000000-0000-0000-0000-0000000000f1');
insert into public.org_modules (org_id, module_key, price_cents) values ('00000000-0000-0000-0000-00000000000a', 'avaliacoes', 900);
insert into public.org_modules (org_id, module_key, price_cents) values ('00000000-0000-0000-0000-00000000000a', 'marketing', 1500);
reset role;
select set_config('request.jwt.claims', '', true);

select pg_temp.login('00000000-0000-0000-0000-0000000000a1');
select pg_temp.expect(public.org_has_module('00000000-0000-0000-0000-00000000000a', 'avaliacoes'), 'extra ligado pelo master aparece');
select pg_temp.expect(public.org_has_module('00000000-0000-0000-0000-00000000000a', 'marketing'), 'marketing ligado com mensagens ativo');
reset role;
select set_config('request.jwt.claims', '', true);

select pg_temp.login('00000000-0000-0000-0000-0000000000f1');
insert into public.org_modules (org_id, module_key, enabled) values ('00000000-0000-0000-0000-00000000000a', 'mensagens', false);
reset role;
select set_config('request.jwt.claims', '', true);
select pg_temp.login('00000000-0000-0000-0000-0000000000a1');
select pg_temp.expect(not public.org_has_module('00000000-0000-0000-0000-00000000000a', 'marketing'), 'sem Mensagens, Campanhas cai junto');
select pg_temp.expect(not public.org_has_module('00000000-0000-0000-0000-00000000000a', 'avaliacoes'), 'sem Mensagens, Avaliações cai junto');
reset role;
select set_config('request.jwt.claims', '', true);

update public.org_subscriptions set status = 'suspended' where org_id = '00000000-0000-0000-0000-00000000000a';
select pg_temp.login('00000000-0000-0000-0000-0000000000a1');
select pg_temp.expect((select count(*) from public.org_enabled_modules('00000000-0000-0000-0000-00000000000a')) = 5, 'suspenso: só os 5 módulos core');
reset role;
select set_config('request.jwt.claims', '', true);

-- ─── 4. auditoria não aceita log em nome de outro ──────────
select pg_temp.login('00000000-0000-0000-0000-0000000000a3');
do $$ begin
  begin
    insert into public.audit_logs (org_id, user_id, table_name, operation) values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a1', 'x', 'INSERT');
    raise exception 'FALHOU: log forjado em nome de outra pessoa';
  exception when insufficient_privilege then null; end;
end $$;
-- 20261114040000: CLINICAL_READ só por função DEFINER de leitura; o registro em nome próprio usa outra operação da lista.
insert into public.audit_logs (org_id, user_id, table_name, operation) values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a3', 'clients', 'CLIENT_UPDATED');
reset role;
select set_config('request.jwt.claims', '', true);

-- ─── 5. anon ───────────────────────────────────────────────
select pg_temp.expect(not has_function_privilege('anon', 'public.void_appointment_deposit_atomic(uuid, uuid)', 'execute'), 'anon não remove sinal');
select pg_temp.expect(not has_function_privilege('anon', 'public.org_enabled_modules(uuid)', 'execute'), 'anon não lê módulos');
-- 20261114100100: o link público passa pelo servidor (chave de serviço); anon não chama a função direto.
select pg_temp.expect(not has_function_privilege('anon', 'public.public_anamnese_open(text, text, boolean)', 'execute')
  and has_function_privilege('service_role', 'public.public_anamnese_open(text, text, boolean)', 'execute'), 'link público da anamnese só pelo servidor');

-- ─── 6. revisão de segurança ───────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-0000000000a3');
select pg_temp.expect((select count(*) from public.org_subscriptions) = 0, 'profissional não lê dados internos da assinatura');
select pg_temp.expect(not public.org_has_module('00000000-0000-0000-0000-00000000000b', 'agenda'), 'org_has_module responde falso para outro estúdio');
reset role;
select set_config('request.jwt.claims', '', true);

update public.org_subscriptions set status = 'trial', trial_ends_at = now() - interval '1 day' where org_id = '00000000-0000-0000-0000-00000000000a';
select pg_temp.login('00000000-0000-0000-0000-0000000000a1');
select pg_temp.expect((select count(*) from public.org_enabled_modules('00000000-0000-0000-0000-00000000000a')) = 5, 'teste vencido: só o núcleo');
reset role;
select set_config('request.jwt.claims', '', true);

select pg_temp.expect(not has_function_privilege('authenticated', 'public.apply_client_balance_entry_internal'::regproc, 'execute'), 'função interna fechada para usuários');

-- excluir um estúdio inteiro (LGPD) não é barrado pela regra da última proprietária
delete from public.organizations where id = '00000000-0000-0000-0000-00000000000b';
select pg_temp.expect((select count(*) from public.user_roles where org_id = '00000000-0000-0000-0000-00000000000b') = 0, 'estúdio excluído leva os papéis junto');

rollback;
\o
\echo 'comportamento da RLS: ok'
