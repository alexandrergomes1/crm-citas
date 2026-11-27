-- Quem não é membro do estúdio para na checagem de papel, não na RLS. Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000007a1', 'fora@teste.local');
insert into public.organizations (id, slug, name) values ('00000000-0000-0000-0000-0000000007aa', 'guard-a', 'Guard');

create function pg_temp.expect(p_ok boolean, p_msg text) returns void language plpgsql as $$
begin
  if not coalesce(p_ok, false) then raise exception 'FALHOU: %', p_msg; end if;
end $$;
grant execute on function pg_temp.expect(boolean, text) to authenticated;

select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000007a1', 'role', 'authenticated')::text, true);
select set_config('role', 'authenticated', true);

do $$
declare v_ok boolean;
begin
  v_ok := false;
  begin
    perform public.get_appointment_anamnese_gate('00000000-0000-0000-0000-0000000007aa', gen_random_uuid(), 'start');
  exception when insufficient_privilege then v_ok := true;
  end;
  perform pg_temp.expect(v_ok, 'gate da anamnese barra quem não é membro');

  v_ok := false;
  begin
    perform public.archive_service_bundle('00000000-0000-0000-0000-0000000007aa', gen_random_uuid());
  exception when insufficient_privilege then v_ok := true;
  end;
  perform pg_temp.expect(v_ok, 'arquivar pacote barra quem não é membro');

  v_ok := false;
  begin
    perform public.set_appointment_status_atomic('00000000-0000-0000-0000-0000000007aa', gen_random_uuid(), 'Confirmado');
  exception when insufficient_privilege then v_ok := true;
  end;
  perform pg_temp.expect(v_ok, 'mudar status barra quem não é membro');
end $$;

reset role;
select pg_temp.expect(not exists (
  select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace
    and (p.prosrc ~ 'if v_role not in \(' or p.prosrc ~ 'if public\.auth_user_role\(p_org_id\) not in \(')
), 'nenhuma função sem a guarda');

rollback;
\o
\echo 'papel nulo: ok'
