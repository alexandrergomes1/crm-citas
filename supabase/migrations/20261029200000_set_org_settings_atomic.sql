-- Configurações do estúdio gravadas por mescla atômica (revisão de arquitetura 29 out).
-- Encoding: UTF-8
--
-- Antes, 4 actions liam organizations.settings, mesclavam no app e regravavam o objeto
-- inteiro, ignorando erro da leitura: uma falha de leitura (ou duas abas salvando juntas)
-- apagava as outras chaves (dados fiscais, políticas, métodos de pagamento, horários,
-- cobrança). Agora a mescla é feita no banco, numa única instrução, só para chaves
-- conhecidas, e fica registrada em audit_logs.

create or replace function public.set_org_settings(p_org_id uuid, p_patch jsonb)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_key text;
begin
  if not public.has_permission(p_org_id, 'ajustes.manage') then
    raise exception 'Sem permissao para alterar configuracoes' using errcode = '42501';
  end if;
  if p_patch is null or pg_catalog.jsonb_typeof(p_patch) <> 'object' or p_patch = '{}'::jsonb then
    raise exception 'Configuracao invalida' using errcode = '22023';
  end if;
  for v_key in select pg_catalog.jsonb_object_keys(p_patch) loop
    if v_key not in ('business', 'policies', 'payment_methods', 'working_hours', 'payment_request') then
      raise exception 'Configuracao desconhecida: %', v_key using errcode = '22023';
    end if;
  end loop;

  update public.organizations o
     set settings = coalesce(o.settings, '{}'::jsonb) || p_patch
   where o.id = p_org_id;
  if not found then
    raise exception 'Estudio nao encontrado' using errcode = 'P0002';
  end if;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
  values (p_org_id, (select auth.uid()), 'organizations', 'SETTINGS_SET', p_org_id,
          pg_catalog.jsonb_build_object('keys', (select pg_catalog.jsonb_agg(k) from pg_catalog.jsonb_object_keys(p_patch) k)));
end;
$$;

revoke all on function public.set_org_settings(uuid, jsonb) from public, anon;
grant execute on function public.set_org_settings(uuid, jsonb) to authenticated;
