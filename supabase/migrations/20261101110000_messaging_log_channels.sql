-- Registro de envios também para e-mail (Resend, Brevo) e, depois, SMS.
-- Encoding: UTF-8

alter table public.messaging_provider_log drop constraint if exists messaging_provider_log_provider_check;
alter table public.messaging_provider_log
  add constraint messaging_provider_log_provider_check check (provider in ('waha_qr', 'meta_cloud', 'resend', 'brevo'));

alter table public.messaging_provider_log add column if not exists channel text not null default 'whatsapp';
alter table public.messaging_provider_log drop constraint if exists messaging_provider_log_channel_check;
alter table public.messaging_provider_log
  add constraint messaging_provider_log_channel_check check (channel in ('whatsapp', 'email', 'sms'));
