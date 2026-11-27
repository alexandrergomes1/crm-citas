-- Funções de gatilho não são chamadas pela API: tira o EXECUTE de quem não precisa.
-- Encoding: UTF-8
set client_encoding = 'UTF8';
revoke all on function public.stamp_client_image_consent() from public, anon, authenticated;
revoke all on function public.guard_client_merge_columns() from public, anon, authenticated;
revoke all on function public.assign_appointment_number() from public, anon, authenticated;
revoke all on function public.protect_appointment_number() from public, anon, authenticated;
