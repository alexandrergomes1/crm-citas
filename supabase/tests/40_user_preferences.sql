-- Preferências: cada pessoa só vê e grava as próprias. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'p1@teste.local'),
  ('00000000-0000-0000-0000-0000000000a2', 'p2@teste.local'),
  ('00000000-0000-0000-0000-0000000000a3', 'p3@teste.local');
insert into public.organizations (id, slug, name) values
  ('00000000-0000-0000-0000-00000000000a', 'pref-a', 'A'),
  ('00000000-0000-0000-0000-00000000000b', 'pref-b', 'B');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000000a', 'owner'),
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-00000000000a', 'owner'),
  ('00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-00000000000b', 'owner');

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

select pg_temp.login('00000000-0000-0000-0000-0000000000a1');
insert into public.user_preferences (user_id, org_id, prefs)
values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000000a', '{"mobile": {"start_page": "agenda"}}');
do $$ begin
  begin
    insert into public.user_preferences (user_id, org_id, prefs)
    values ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-00000000000a', '{}');
    raise exception 'FALHOU: gravou preferência de outra pessoa';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.user_preferences (user_id, org_id, prefs)
    values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000000b', '{}');
    raise exception 'FALHOU: gravou em estúdio do qual não faz parte';
  exception when insufficient_privilege then null; end;
end $$;
reset role; select set_config('request.jwt.claims', '', true);

select pg_temp.login('00000000-0000-0000-0000-0000000000a2');
select pg_temp.expect((select count(*) from public.user_preferences) = 0, 'outra proprietária não vê preferências alheias');
do $$ begin
  update public.user_preferences set prefs = '{}' where user_id = '00000000-0000-0000-0000-0000000000a1';
  perform pg_temp.expect(not found, 'não altera preferência alheia');
end $$;
reset role; select set_config('request.jwt.claims', '', true);

select pg_temp.expect((select prefs->'mobile'->>'start_page' from public.user_preferences where user_id = '00000000-0000-0000-0000-0000000000a1') = 'agenda', 'preferência mantida');

rollback;
\o
\echo 'preferências: ok'
