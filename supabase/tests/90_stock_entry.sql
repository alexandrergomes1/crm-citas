-- Movimento manual de estoque. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000009a1', 'estoque@teste.local'),
  ('00000000-0000-0000-0000-0000000009a2', 'recep-estoque@teste.local');
insert into public.organizations (id, slug, name) values ('00000000-0000-0000-0000-0000000009aa', 'estoque-a', 'Estoque');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-0000000009a1', '00000000-0000-0000-0000-0000000009aa', 'owner'),
  ('00000000-0000-0000-0000-0000000009a2', '00000000-0000-0000-0000-0000000009aa', 'receptionist');
insert into public.products (id, org_id, name, price, stock_qty) values
  ('00000000-0000-0000-0000-0000000009f1', '00000000-0000-0000-0000-0000000009aa', 'Sérum', 30, 5);

create function pg_temp.expect(p_ok boolean, p_msg text) returns void language plpgsql as $$
begin
  if not coalesce(p_ok, false) then raise exception 'FALHOU: %', p_msg; end if;
end $$;
grant execute on function pg_temp.expect(boolean, text) to authenticated;

select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000009a1', 'role', 'authenticated')::text, true);
select set_config('role', 'authenticated', true);
do $$
declare v_ok boolean := false;
begin
  begin
    perform public.register_stock_entry_atomic('00000000-0000-0000-0000-0000000009aa', '00000000-0000-0000-0000-0000000009f1', 'saida', 7, null);
  exception when numeric_value_out_of_range then v_ok := sqlerrm like 'Estoque insuficiente%';
  end;
  perform pg_temp.expect(v_ok, 'saída maior que o estoque é recusada');
  perform pg_temp.expect(public.register_stock_entry_atomic('00000000-0000-0000-0000-0000000009aa',
    '00000000-0000-0000-0000-0000000009f1', 'ajuste', 0, 'Inventário') = 0, 'ajuste zera o estoque');
end $$;
reset role;
select pg_temp.expect((select count(*) from public.audit_logs where operation = 'STOCK_AJUSTE') = 1, 'ajuste vai para a auditoria');

select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000009a2', 'role', 'authenticated')::text, true);
select set_config('role', 'authenticated', true);
do $$
declare v_ok boolean := false;
begin
  begin
    perform public.register_stock_entry_atomic('00000000-0000-0000-0000-0000000009aa', '00000000-0000-0000-0000-0000000009f1', 'entrada', 3, null);
  exception when insufficient_privilege then v_ok := true;
  end;
  perform pg_temp.expect(v_ok, 'recepção não movimenta estoque pela função');
end $$;
reset role;

rollback;
\o
\echo 'estoque: ok'
