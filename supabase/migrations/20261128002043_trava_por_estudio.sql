-- Item 3 · spec 20261128-010000-banco-ligacao · plan.md §3.3 · ADR 0005 (T4, D1, D2).
-- Função de checagem de acesso: o estúdio vem da sessão (auth.uid()), nunca do pedido (RF-03).
-- SECURITY DEFINER com search_path vazio e nomes qualificados; esquema app fora da API.

create function app.estudio_da_sessao()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.org_id
  from public.membros m
  where m.user_id = (select auth.uid()) and m.ativo and m.estudio_atual
$$;

create function app.papel_da_sessao()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select m.papel
  from public.membros m
  where m.user_id = (select auth.uid()) and m.ativo and m.estudio_atual
$$;

create function app.eh_dona()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(app.papel_da_sessao() = 'dona', false)
$$;

-- Só grava a escolha da própria pessoa entre os estúdios em que ela já tem papel ativo.
create function app.escolher_estudio(p_org_id uuid)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'Login obrigatorio' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.membros m
    where m.user_id = v_user and m.org_id = p_org_id and m.ativo
  ) then
    raise exception 'Sem acesso a este estudio' using errcode = '42501';
  end if;
  -- Dois comandos: o índice único parcial é conferido linha a linha.
  update public.membros set estudio_atual = false where user_id = v_user and estudio_atual;
  update public.membros set estudio_atual = true where user_id = v_user and org_id = p_org_id;
  return true;
end;
$$;

revoke all on function app.estudio_da_sessao() from public, anon;
revoke all on function app.papel_da_sessao() from public, anon;
revoke all on function app.eh_dona() from public, anon;
revoke all on function app.escolher_estudio(uuid) from public, anon;
grant execute on function app.estudio_da_sessao() to authenticated;
grant execute on function app.papel_da_sessao() to authenticated;
grant execute on function app.eh_dona() to authenticated;
grant execute on function app.escolher_estudio(uuid) to authenticated;
grant usage on schema app to authenticated;
