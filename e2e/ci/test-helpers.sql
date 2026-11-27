-- Ajuda só do E2E na CI (Supabase local, nunca produção; NÃO é migration e não está em supabase/migrations).
-- Apaga uma cliente de teste e tudo que depende dela, inclusive ficha assinada (que o gatilho de evidência
-- protege). Só a chave de serviço executa; o app não usa. Encoding: UTF-8
create or replace function public.e2e_purge_client(p_client_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  -- A ficha assinada é imutável: o gatilho fica desligado só dentro desta função (tudo ou nada).
  alter table public.anamneses disable trigger trg_protect_signed_anamnese_evidence;
  delete from public.anamneses where client_id = p_client_id;
  alter table public.anamneses enable trigger trg_protect_signed_anamnese_evidence;

  delete from public.client_notes where client_id = p_client_id;
  delete from public.appointment_deposits where client_id = p_client_id;
  delete from public.client_entitlement_entries where client_id = p_client_id;
  delete from public.client_entitlements where client_id = p_client_id;
  delete from public.transactions where sale_id in (select id from public.sales where client_id = p_client_id);
  delete from public.sale_payments where sale_id in (select id from public.sales where client_id = p_client_id);
  delete from public.sale_items where sale_id in (select id from public.sales where client_id = p_client_id);
  delete from public.sales where client_id = p_client_id;
  delete from public.transactions where client_id = p_client_id
    or sale_id in (select id from public.sales where client_id = p_client_id);
  delete from public.appointments where client_id = p_client_id;
  delete from public.clients where id = p_client_id;
end;
$$;
revoke all on function public.e2e_purge_client(uuid) from public, anon, authenticated;
grant execute on function public.e2e_purge_client(uuid) to service_role;
