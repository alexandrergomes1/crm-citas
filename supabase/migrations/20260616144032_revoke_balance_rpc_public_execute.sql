-- KA Beauty OS - Restrict manual client balance adjustment RPC execution
-- Encoding: UTF-8

revoke all on function public.adjust_client_balance_atomic(
  uuid, uuid, text, numeric, text, uuid
) from public, anon;
grant execute on function public.adjust_client_balance_atomic(
  uuid, uuid, text, numeric, text, uuid
) to authenticated;
