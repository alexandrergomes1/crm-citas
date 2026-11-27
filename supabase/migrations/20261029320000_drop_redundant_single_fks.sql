-- Uma ligação só por par de tabelas: remove as FKs simples que as compostas por estúdio cobrem.
-- Encoding: UTF-8
--
-- Incidente 29 out, 11:05: 20261029210000 criou FKs compostas (coluna, org_id) ao lado das
-- FKs simples antigas. Com duas ligações entre as mesmas tabelas, a API (PostgREST) recusa
-- consultas encadeadas como appointments → appointment_items e clients → appointments
-- (PGRST201, "more than one relationship"), e Início, Agenda e Clientes deram erro.
--
-- A FK composta garante tudo o que a simples garantia (a linha-mãe existe) e ainda o mesmo
-- estúdio. Aqui a simples sai e a composta herda a regra de exclusão dela (CASCADE ou
-- RESTRICT); as que eram NO ACTION continuam iguais.

do $fix$
declare
  r record;
  v_def text;
  v_clause text;
  v_done integer := 0;
begin
  for r in
    select c.oid as single_oid, c.conname as single_name, c.confdeltype as single_del,
           s.oid as comp_oid, s.conname as comp_name, s.confdeltype as comp_del,
           c.conrelid::regclass as child
    from pg_constraint c
    join pg_constraint s
      on s.conrelid = c.conrelid and s.confrelid = c.confrelid
     and s.contype = 'f' and s.conname like '%\_same\_org' and c.conkey[1] = any (s.conkey)
    where c.contype = 'f' and array_length(c.conkey, 1) = 1
      and c.connamespace = 'public'::regnamespace
  loop
    if r.comp_del <> 'a' then
      raise exception '%: FK composta % já tem regra de exclusão própria', r.child, r.comp_name;
    end if;
    v_clause := case r.single_del
      when 'a' then ''
      when 'c' then ' ON DELETE CASCADE'
      when 'r' then ' ON DELETE RESTRICT'
      else null
    end;
    if v_clause is null then
      raise exception '%: FK % tem regra de exclusão % sem equivalente composto', r.child, r.single_name, r.single_del;
    end if;

    execute format('alter table %s drop constraint %I', r.child, r.single_name);
    if v_clause <> '' then
      v_def := pg_get_constraintdef(r.comp_oid);
      execute format('alter table %s drop constraint %I', r.child, r.comp_name);
      execute format('alter table %s add constraint %I %s%s', r.child, r.comp_name, v_def, v_clause);
    end if;
    v_done := v_done + 1;
  end loop;

  if v_done = 0 then
    raise exception 'Nenhuma FK simples redundante encontrada';
  end if;
  raise notice 'FKs simples removidas: %', v_done;
end;
$fix$;

-- A API relê o esquema na hora.
notify pgrst, 'reload schema';
