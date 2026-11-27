-- Impressão digital do schema public (funções, políticas, colunas, constraints, triggers,
-- índices e grants). Rode no banco real e num replay local e compare com
-- scripts/db/diff-fingerprint.py para achar diferenças entre produção e repositório.
-- Encoding: UTF-8
select kind||'|'||k||'|'||h as line from (
 select 'fn' kind, p.proname||'('||pg_get_function_identity_arguments(p.oid)||')' k,
   md5(regexp_replace(p.prosrc,'\s+',' ','g'))||':'||p.prosecdef||':'||coalesce(array_to_string(p.proconfig,','),'') h
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'
 union all
 select 'pol', tablename||'.'||policyname, cmd||':'||array_to_string(roles,',')||':'||md5(coalesce(qual,''))||':'||md5(coalesce(with_check,'')) from pg_policies where schemaname='public'
 union all
 select 'col', table_name||'.'||column_name, data_type||':'||is_nullable||':'||md5(coalesce(column_default,'')) from information_schema.columns where table_schema='public'
 union all
 select 'con', c.conrelid::regclass::text||'.'||c.conname, md5(pg_get_constraintdef(c.oid)) from pg_constraint c join pg_namespace n on n.oid=c.connamespace where n.nspname='public'
 union all
 select 'trg', t.tgrelid::regclass::text||'.'||t.tgname, t.tgfoid::regproc::text from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and not t.tgisinternal
 union all
 select 'idx', indexname, md5(indexdef) from pg_indexes where schemaname='public'
 union all
 select 'grant', p.proname||'('||pg_get_function_identity_arguments(p.oid)||')', 'anon='||has_function_privilege('anon',p.oid,'execute')||',auth='||has_function_privilege('authenticated',p.oid,'execute') from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'
) s order by 1;
