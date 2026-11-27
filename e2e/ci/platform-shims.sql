-- Objetos que existem no projeto Supabase de produção (criados pela plataforma) e não no
-- Supabase local. Só para o E2E. Encoding: UTF-8
-- "RLS automático" do Supabase: em produção é um gatilho de evento; aqui só a função existe.
create or replace function public.rls_auto_enable() returns event_trigger
language plpgsql as $$ begin null; end $$;
