-- set_role_permissions: trocas com dependência numa transação só. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values ('00000000-0000-0000-0000-000000000e11', 'dono7@teste.local');
insert into public.organizations (id, slug, name) values ('00000000-0000-0000-0000-000000000e1a', 'batch-a', 'Estúdio A');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000000e11', '00000000-0000-0000-0000-000000000e1a', 'owner');

create function pg_temp.expect(p_ok boolean, p_msg text) returns void language plpgsql as $$
begin
  if not coalesce(p_ok, false) then raise exception 'FALHOU: %', p_msg; end if;
end $$;
create function pg_temp.state_of(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return sqlstate;
end $$;
grant execute on function pg_temp.expect(boolean, text), pg_temp.state_of(text) to authenticated;

select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000e11', 'role', 'authenticated')::text, true);
select set_config('role', 'authenticated', true);

-- Liga preencher + ler para a recepção de uma vez.
select pg_temp.expect(public.set_role_permissions('00000000-0000-0000-0000-000000000e1a', 'receptionist',
  '[{"permission":"anamnese.fill_professional","allowed":true},{"permission":"clientes.view_clinical","allowed":true}]') = 2, 'duas trocas gravadas');

-- Segunda troca inválida: a primeira não pode ficar gravada.
do $$ begin
  perform pg_temp.expect(pg_temp.state_of($q$select public.set_role_permissions('00000000-0000-0000-0000-000000000e1a', 'receptionist',
    '[{"permission":"comanda.refund","allowed":true},{"permission":"inexistente.x","allowed":true}]')$q$) = '22023', 'lote com troca inválida é recusado');
  perform pg_temp.expect(pg_temp.state_of($q$select public.set_role_permissions('00000000-0000-0000-0000-000000000e1a', 'receptionist', '[]')$q$) = '22023', 'lote vazio recusado');
end $$;

reset role;
select pg_temp.expect((select count(*) = 2 from public.org_role_permissions
  where org_id = '00000000-0000-0000-0000-000000000e1a' and role = 'receptionist'), 'só as duas primeiras trocas existem');
select pg_temp.expect(not exists (select 1 from public.org_role_permissions
  where org_id = '00000000-0000-0000-0000-000000000e1a' and permission = 'comanda.refund'), 'troca do lote recusado foi desfeita');

rollback;
\o
\echo 'liberações em lote: ok'
