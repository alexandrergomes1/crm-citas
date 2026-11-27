-- Ajustes: limites no banco (antes só na tela/servidor do app). Restrições NOT VALID aqui (não leem a tabela, trava curta);
-- a validação das linhas existentes vem na migration seguinte (20261114060400). Conferido em 14/11 no banco de
-- desenvolvimento (só leitura): nenhuma linha atual viola estes limites.
-- Encoding: UTF-8
set client_encoding = 'UTF8';
-- Espera no máximo 5 s pela trava da tabela (ADD CONSTRAINT ... NOT VALID é rápido, mas pede trava forte): se a tabela
-- estiver ocupada, a migration falha e é rodada de novo, em vez de enfileirar todos os pedidos atrás dela.
set lock_timeout = '5s';
alter table public.staff_members
  add constraint staff_members_name_len check (char_length(btrim(name)) between 1 and 120) not valid,
  add constraint staff_members_display_name_len check (display_name is null or char_length(display_name) <= 120) not valid,
  add constraint staff_members_role_len check (char_length(role) <= 80) not valid,
  add constraint staff_members_email_len check (email is null or char_length(email) <= 254) not valid,
  add constraint staff_members_phone_len check (phone is null or char_length(phone) <= 40) not valid,
  add constraint staff_members_color_hex check (color ~ '^#[0-9a-fA-F]{6}$') not valid,
  add constraint staff_members_commission_range check (commission_pct >= 0 and commission_pct <= 100) not valid;

alter table public.staff_shifts
  add constraint staff_shifts_time_format check (
    start_time ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' and end_time ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$') not valid,
  add constraint staff_shifts_end_after_start check (not active or end_time > start_time) not valid;

alter table public.organizations
  add constraint organizations_name_len check (char_length(btrim(name)) between 1 and 120) not valid,
  add constraint organizations_phone_len check (phone is null or char_length(phone) <= 40) not valid,
  add constraint organizations_email_len check (email is null or char_length(email) <= 254) not valid,
  add constraint organizations_address_len check (address is null or char_length(address) <= 200) not valid,
  add constraint organizations_city_len check (city is null or char_length(city) <= 80) not valid,
  add constraint organizations_currency_code check (currency ~ '^[A-Z]{3}$') not valid;

alter table public.profiles
  add constraint profiles_full_name_len check (char_length(full_name) <= 120) not valid;
reset lock_timeout;
