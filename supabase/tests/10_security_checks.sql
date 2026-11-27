-- ============================================================
-- Checagens estáticas de segurança do schema (falham o replay se violadas)
-- Encoding: UTF-8
-- ============================================================

do $$
declare
  v text;
begin
  -- 1. toda tabela do schema public tem RLS ligada
  select string_agg(c.relname, ', ' order by c.relname) into v
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;
  if v is not null then raise exception 'Tabelas sem RLS: %', v; end if;

  -- 2. toda função security definer fixa o search_path
  select string_agg(p.proname, ', ' order by p.proname) into v
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef
    and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%');
  if v is not null then raise exception 'Security definer sem search_path: %', v; end if;

  -- 3. anon não executa nenhuma função security definer: os links públicos (ficha, cobrança, esqueci a senha)
  --    passam pelo servidor, que chama as funções public_* com a chave de serviço (20261114100100).
  select string_agg(p.proname, ', ' order by p.proname) into v
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef and p.prokind = 'f'
    and has_function_privilege('anon', p.oid, 'execute');
  if v is not null then raise exception 'Funções security definer executáveis por anon: %', v; end if;

  -- 4. tabelas de negócio têm org_id (exceções: catálogo global e administração master)
  select string_agg(c.relname, ', ' order by c.relname) into v
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r'
    and c.relname not in ('organizations', 'platform_admins', 'modules', 'plans', 'plan_modules',
                          -- contador de tentativas das páginas públicas: o IP ou token ainda não tem estúdio
                          'public_link_hits')
    and not exists (select 1 from information_schema.columns k
                    where k.table_schema = 'public' and k.table_name = c.relname and k.column_name = 'org_id');
  if v is not null then raise exception 'Tabelas sem org_id: %', v; end if;

  -- 5. políticas permissivas com using(true) só nos catálogos globais de leitura
  select string_agg(tablename || '.' || policyname, ', ') into v
  from pg_policies
  where schemaname = 'public' and (qual = 'true' or with_check = 'true')
    and tablename not in ('modules', 'plans', 'plan_modules');
  if v is not null then raise exception 'Políticas abertas (true): %', v; end if;

  -- 6. funções *_internal só para o próprio banco (nem authenticated)
  select string_agg(p.proname, ', ' order by p.proname) into v
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname like '%\_internal'
    and (has_function_privilege('authenticated', p.oid, 'execute') or has_function_privilege('anon', p.oid, 'execute'));
  if v is not null then raise exception 'Funções internas expostas: %', v; end if;

  -- 7. nenhuma função com acento corrompido (UTF-8 lido como Latin-1: "Ã§", "Ã£", "Ã­"...)
  select string_agg(p.proname, ', ' order by p.proname) into v
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosrc ~ '[ÃÂ][\u0080-¿]';
  if v is not null then raise exception 'Funções com acentos corrompidos: %', v; end if;

  -- 8. a agenda consegue concluir e marcar ausência
  if not public.agenda_status_transition_allowed('Iniciado', 'Concluído')
     or not public.agenda_status_transition_allowed('Confirmado', 'Ausência') then
    raise exception 'Transições de status com acento não funcionam';
  end if;

  -- 9. cada visão internal_read.X tem as mesmas colunas (nome, tipo e ordem) de public.X: coluna nova na tabela
  --    exige recriar a visão (20261114130000), senão as funções que leem a linha inteira quebram ou perdem a coluna.
  select string_agg(v.relname, ', ' order by v.relname) into v
  from pg_class v join pg_namespace n on n.oid = v.relnamespace
  where n.nspname = 'internal_read' and v.relkind = 'v'
    and (to_regclass('public.' || quote_ident(v.relname)) is null
      or exists (
        (select a.attnum, a.attname, a.atttypid from pg_attribute a
         where a.attrelid = v.oid and a.attnum > 0 and not a.attisdropped
         except
         select b.attnum - (select count(*) from pg_attribute d where d.attrelid = b.attrelid and d.attisdropped and d.attnum > 0 and d.attnum < b.attnum),
                b.attname, b.atttypid from pg_attribute b
         where b.attrelid = ('public.' || quote_ident(v.relname))::regclass and b.attnum > 0 and not b.attisdropped)
        union all
        (select b.attnum - (select count(*) from pg_attribute d where d.attrelid = b.attrelid and d.attisdropped and d.attnum > 0 and d.attnum < b.attnum),
                b.attname, b.atttypid from pg_attribute b
         where b.attrelid = ('public.' || quote_ident(v.relname))::regclass and b.attnum > 0 and not b.attisdropped
         except
         select a.attnum, a.attname, a.atttypid from pg_attribute a
         where a.attrelid = v.oid and a.attnum > 0 and not a.attisdropped)));
  if v is not null then raise exception 'Visões internal_read com colunas diferentes da tabela (recrie a visão): %', v; end if;

  -- 10. internal_read: visões security_barrier, só leitura e sem acesso de anon
  select string_agg(v.relname, ', ' order by v.relname) into v
  from pg_class v join pg_namespace n on n.oid = v.relnamespace
  where n.nspname = 'internal_read' and v.relkind = 'v'
    and not coalesce('security_barrier=true' = any (v.reloptions), false);
  if v is not null then raise exception 'Visões internal_read sem security_barrier: %', v; end if;
  if has_schema_privilege('anon', 'internal_read', 'usage') then raise exception 'anon com acesso ao schema internal_read'; end if;
  select string_agg(table_name || ':' || grantee || ':' || privilege_type, ', ') into v
  from information_schema.role_table_grants
  where table_schema = 'internal_read' and grantee in ('anon', 'authenticated', 'PUBLIC') and privilege_type <> 'SELECT';
  if v is not null then raise exception 'internal_read com gravação concedida: %', v; end if;

  raise notice 'checagens estáticas: ok';
end $$;
