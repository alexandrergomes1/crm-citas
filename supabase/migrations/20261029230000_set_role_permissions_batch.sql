-- Liberações com dependência gravadas juntas (revisão de arquitetura 29 out).
-- Encoding: UTF-8
--
-- "Preencher ficha" exige "ler conteúdo clínico". O app gravava as duas trocas em chamadas
-- separadas: uma falha no meio deixava preencher ligado sem leitura. Agora todas as trocas
-- vão numa função só (uma transação), reaproveitando set_role_permission (permissões,
-- regras da proprietária e auditoria continuam lá).

create or replace function public.set_role_permissions(
  p_org_id uuid, p_role text, p_changes jsonb
)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_change jsonb;
  v_count integer := 0;
begin
  if p_changes is null or pg_catalog.jsonb_typeof(p_changes) <> 'array'
     or pg_catalog.jsonb_array_length(p_changes) = 0 or pg_catalog.jsonb_array_length(p_changes) > 10 then
    raise exception 'Lista de liberacoes invalida' using errcode = '22023';
  end if;
  for v_change in select * from pg_catalog.jsonb_array_elements(p_changes) loop
    if pg_catalog.jsonb_typeof(v_change -> 'permission') <> 'string'
       or pg_catalog.jsonb_typeof(v_change -> 'allowed') <> 'boolean' then
      raise exception 'Liberacao invalida' using errcode = '22023';
    end if;
    perform public.set_role_permission(p_org_id, p_role, v_change ->> 'permission', (v_change ->> 'allowed')::boolean);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke all on function public.set_role_permissions(uuid, text, jsonb) from public, anon;
grant execute on function public.set_role_permissions(uuid, text, jsonb) to authenticated;
