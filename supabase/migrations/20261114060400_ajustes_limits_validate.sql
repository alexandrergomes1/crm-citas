-- Ajustes: valida as restrições criadas em 20261114060300 nas linhas existentes (leitura da tabela sem bloquear
-- gravações). Separado para que a trava forte da criação seja curta.
-- Encoding: UTF-8
set client_encoding = 'UTF8';
alter table public.staff_members validate constraint staff_members_name_len;
alter table public.staff_members validate constraint staff_members_display_name_len;
alter table public.staff_members validate constraint staff_members_role_len;
alter table public.staff_members validate constraint staff_members_email_len;
alter table public.staff_members validate constraint staff_members_phone_len;
alter table public.staff_members validate constraint staff_members_color_hex;
alter table public.staff_members validate constraint staff_members_commission_range;
alter table public.staff_shifts validate constraint staff_shifts_time_format;
alter table public.staff_shifts validate constraint staff_shifts_end_after_start;
alter table public.organizations validate constraint organizations_name_len;
alter table public.organizations validate constraint organizations_phone_len;
alter table public.organizations validate constraint organizations_email_len;
alter table public.organizations validate constraint organizations_address_len;
alter table public.organizations validate constraint organizations_city_len;
alter table public.organizations validate constraint organizations_currency_code;
alter table public.profiles validate constraint profiles_full_name_len;
