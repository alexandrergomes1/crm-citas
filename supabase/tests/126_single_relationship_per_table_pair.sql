-- Uma ligação só entre cada par de tabelas (20261029320000). Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

create function pg_temp.expect(p_ok boolean, p_msg text) returns void language plpgsql as $$
begin
  if not coalesce(p_ok, false) then raise exception 'FALHOU: %', p_msg; end if;
end $$;

-- Duas FKs entre as mesmas tabelas tornam ambíguas as consultas encadeadas da API (PGRST201).
do $$
declare v_pairs text;
begin
  select string_agg(conrelid::regclass || '→' || confrelid::regclass || ' (' || n || ')', ', ') into v_pairs
  from (
    select conrelid, confrelid, count(*) n
    from pg_constraint
    where contype = 'f' and connamespace = 'public'::regnamespace and conrelid <> confrelid
      -- auth.users não é exposto pela API, então não há consulta encadeada ambígua.
      and confrelid::regclass::text not like 'auth.%'
      -- Pares antigos que o código sempre consulta com o nome da FK (src/data/catalog).
      and conrelid::regclass::text not in ('package_services', 'service_staff')
    group by 1, 2 having count(*) > 1
  ) d;
  perform pg_temp.expect(v_pairs is null, 'pares de tabelas com mais de uma FK: ' || coalesce(v_pairs, ''));
end $$;

-- Exclusão em cascata continua: apagar o atendimento leva os itens.
insert into public.organizations (id, slug, name) values ('00000000-0000-0000-0000-000000000f6a', 'fk-uma', 'Estúdio A');
insert into public.clients (id, org_id, full_name) values ('00000000-0000-0000-0000-000000000f6c', '00000000-0000-0000-0000-000000000f6a', 'X');
insert into public.appointments (id, org_id, client_id, client_name, start_at, end_at, duration_minutes, status)
values ('00000000-0000-0000-0000-000000000f6b', '00000000-0000-0000-0000-000000000f6a', '00000000-0000-0000-0000-000000000f6c', 'X',
        '2035-01-01 10:00+00', '2035-01-01 11:00+00', 60, 'Agendado');
insert into public.appointment_items (org_id, appointment_id, name, price)
values ('00000000-0000-0000-0000-000000000f6a', '00000000-0000-0000-0000-000000000f6b', 'Limpeza', 50);
delete from public.appointments where id = '00000000-0000-0000-0000-000000000f6b';
select pg_temp.expect((select count(*) = 0 from public.appointment_items where appointment_id = '00000000-0000-0000-0000-000000000f6b'),
  'itens apagados junto com o atendimento');

rollback;
\o
\echo 'uma ligação por par de tabelas: ok'
