-- Liberações configuráveis, fase 2a (spec 37): catálogo, equipe e marketing. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000da1', 'dono2@teste.local'),
  ('00000000-0000-0000-0000-000000000da2', 'recep2@teste.local'),
  ('00000000-0000-0000-0000-000000000da3', 'gest2@teste.local'),
  ('00000000-0000-0000-0000-000000000da4', 'fora2@teste.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-000000000daa', 'perm2-a', 'Estúdio A'),
  ('00000000-0000-0000-0000-000000000dab', 'perm2-b', 'Estúdio B');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000000da1', '00000000-0000-0000-0000-000000000daa', 'owner'),
  ('00000000-0000-0000-0000-000000000da2', '00000000-0000-0000-0000-000000000daa', 'receptionist'),
  ('00000000-0000-0000-0000-000000000da3', '00000000-0000-0000-0000-000000000daa', 'manager'),
  ('00000000-0000-0000-0000-000000000da4', '00000000-0000-0000-0000-000000000dab', 'owner');

create function pg_temp.expect(p_ok boolean, p_msg text) returns void language plpgsql as $$
begin
  if not coalesce(p_ok, false) then raise exception 'FALHOU: %', p_msg; end if;
end $$;
grant execute on function pg_temp.expect(boolean, text) to authenticated;

create function pg_temp.state_of(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return sqlstate;
end $$;
grant execute on function pg_temp.state_of(text) to authenticated;

select set_config('role', 'authenticated', true);

-- Padrão: gestão cadastra catálogo, equipe e marketing; recepção não.
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000da3', 'role', 'authenticated')::text, true);
do $$
begin
  perform pg_temp.expect(pg_temp.state_of($q$insert into public.service_categories (org_id, name) values ('00000000-0000-0000-0000-000000000daa', 'Faciais')$q$) = 'ok', 'gestão cria categoria');
  perform pg_temp.expect(pg_temp.state_of($q$insert into public.products (org_id, name) values ('00000000-0000-0000-0000-000000000daa', 'Sérum')$q$) = 'ok', 'gestão cria produto');
  perform pg_temp.expect(pg_temp.state_of($q$insert into public.staff_members (org_id, name) values ('00000000-0000-0000-0000-000000000daa', 'Ana')$q$) = 'ok', 'gestão cria profissional');
  perform pg_temp.expect(pg_temp.state_of($q$insert into public.marketing_segments (org_id, name) values ('00000000-0000-0000-0000-000000000daa', 'Inativas')$q$) = 'ok', 'gestão cria segmento');
end $$;

select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000da2', 'role', 'authenticated')::text, true);
do $$
begin
  perform pg_temp.expect(pg_temp.state_of($q$insert into public.service_categories (org_id, name) values ('00000000-0000-0000-0000-000000000daa', 'Corporais')$q$) = '42501', 'recepção não cria categoria por padrão');
  perform pg_temp.expect(pg_temp.state_of($q$insert into public.products (org_id, name) values ('00000000-0000-0000-0000-000000000daa', 'Creme')$q$) = '42501', 'recepção não cria produto por padrão');
  perform pg_temp.expect(pg_temp.state_of($q$insert into public.staff_members (org_id, name) values ('00000000-0000-0000-0000-000000000daa', 'Bia')$q$) = '42501', 'recepção não cria profissional por padrão');
  perform pg_temp.expect(pg_temp.state_of($q$insert into public.marketing_segments (org_id, name) values ('00000000-0000-0000-0000-000000000daa', 'VIP')$q$) = '42501', 'recepção não cria segmento por padrão');
  perform pg_temp.expect(pg_temp.state_of($q$select public.upsert_catalog_service_atomic('00000000-0000-0000-0000-000000000daa', '{}'::jsonb)$q$) in ('42501', '42883'), 'recepção não grava serviço por padrão');
end $$;

-- Dona liga catálogo, equipe e marketing para a recepção.
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000da1', 'role', 'authenticated')::text, true);
select public.set_role_permission('00000000-0000-0000-0000-000000000daa', 'receptionist', 'catalogo.manage', true);
select public.set_role_permission('00000000-0000-0000-0000-000000000daa', 'receptionist', 'equipe.manage', true);
select public.set_role_permission('00000000-0000-0000-0000-000000000daa', 'receptionist', 'mensagens.configure', true);

select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000da2', 'role', 'authenticated')::text, true);
do $$
begin
  perform pg_temp.expect(pg_temp.state_of($q$insert into public.service_categories (org_id, name) values ('00000000-0000-0000-0000-000000000daa', 'Corporais')$q$) = 'ok', 'recepção com liberação cria categoria');
  perform pg_temp.expect(pg_temp.state_of($q$insert into public.products (org_id, name) values ('00000000-0000-0000-0000-000000000daa', 'Creme')$q$) = 'ok', 'recepção com liberação cria produto');
  perform pg_temp.expect(pg_temp.state_of($q$insert into public.staff_members (org_id, name) values ('00000000-0000-0000-0000-000000000daa', 'Bia')$q$) = 'ok', 'recepção com liberação cria profissional');
  perform pg_temp.expect(pg_temp.state_of($q$insert into public.marketing_segments (org_id, name) values ('00000000-0000-0000-0000-000000000daa', 'VIP')$q$) = 'ok', 'recepção com liberação cria segmento');
  -- Não vaza para o outro estúdio.
  perform pg_temp.expect(pg_temp.state_of($q$insert into public.service_categories (org_id, name) values ('00000000-0000-0000-0000-000000000dab', 'Intrusa')$q$) = '42501', 'liberação não vale em outro estúdio');
end $$;

-- Dona desliga catálogo e marketing para a gestão: passa a ser barrada.
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000da1', 'role', 'authenticated')::text, true);
select public.set_role_permission('00000000-0000-0000-0000-000000000daa', 'manager', 'catalogo.manage', false);
select public.set_role_permission('00000000-0000-0000-0000-000000000daa', 'manager', 'mensagens.configure', false);

select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000da3', 'role', 'authenticated')::text, true);
do $$
begin
  perform pg_temp.expect(pg_temp.state_of($q$insert into public.service_categories (org_id, name) values ('00000000-0000-0000-0000-000000000daa', 'Massagens')$q$) = '42501', 'gestão sem liberação não cria categoria');
  perform pg_temp.expect(pg_temp.state_of($q$insert into public.marketing_segments (org_id, name) values ('00000000-0000-0000-0000-000000000daa', 'Novas')$q$) = '42501', 'gestão sem liberação não cria segmento');
  perform pg_temp.expect(pg_temp.state_of($q$insert into public.staff_members (org_id, name) values ('00000000-0000-0000-0000-000000000daa', 'Clara')$q$) = 'ok', 'equipe da gestão segue como estava');
end $$;

reset role;
rollback;
\o
\echo 'liberações fase 2a (catálogo, equipe, marketing): ok'
