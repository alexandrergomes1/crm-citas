set lock_timeout = '5s';

alter table public.clients
  add column if not exists document_type text,
  add column if not exists document_number text,
  add column if not exists phone_country_code text;

comment on column public.clients.document_type is
  'International personal document type: dni, nie, nif, passport, cpf or other.';
comment on column public.clients.document_number is
  'Personal document number. Validation is intentionally country-neutral.';
comment on column public.clients.phone_country_code is
  'International calling code such as +34. Null means legacy or unknown.';

update public.clients
set
  document_number = coalesce(nullif(btrim(document_number), ''), nullif(btrim(cpf), '')),
  document_type = case
    when nullif(btrim(document_number), '') is not null then document_type
    when nullif(btrim(cpf), '') is not null then coalesce(document_type, 'cpf')
    else document_type
  end,
  phone_country_code = case
    when phone_country_code is not null then phone_country_code
    when phone like '+351%' then '+351'
    when phone like '+34%' then '+34'
    when phone like '+55%' then '+55'
    else null
  end
where
  (document_number is null and nullif(btrim(cpf), '') is not null)
  or phone_country_code is null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'clients_document_type_check'
      and conrelid = 'public.clients'::regclass
  ) then
    alter table public.clients
      add constraint clients_document_type_check
      check (
        document_type is null
        or document_type in ('dni', 'nie', 'nif', 'passport', 'cpf', 'other')
      ) not valid;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'clients_phone_country_code_check'
      and conrelid = 'public.clients'::regclass
  ) then
    alter table public.clients
      add constraint clients_phone_country_code_check
      check (
        phone_country_code is null
        or phone_country_code ~ '^\+[1-9][0-9]{0,3}$'
      ) not valid;
  end if;
end
$$;

alter table public.clients
  validate constraint clients_document_type_check;

alter table public.clients
  validate constraint clients_phone_country_code_check;
