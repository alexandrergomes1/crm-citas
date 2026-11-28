-- Item 3 · spec 20261128-010000-banco-ligacao · plan.md §3.1 · ADR 0005 (T1, T10, D1, D4).
-- O estúdio (inquilino). A chave chama-se org_id, como em toda tabela do estúdio (RG-04).
-- RLS ligada sem política: fecha tudo até a migration politicas_base.

create schema if not exists app;
revoke all on schema app from public;
comment on schema app is 'Funções da trava por estúdio. Fora de api.schemas: não é exposto pela API.';

create table public.estudios (
  org_id       uuid        primary key default gen_random_uuid(),
  nome         text        not null check (char_length(btrim(nome)) between 1 and 120),
  moeda        text        not null check (moeda ~ '^[A-Z]{3}$'),
  idioma       text        not null check (idioma in ('pt', 'es', 'en')),
  fuso_horario text        not null,
  criado_em    timestamptz not null default now()
);
comment on table public.estudios is 'Estúdio (inquilino). Moeda ISO 4217, idioma ISO 639-1 (pt, es, en), fuso IANA.';

-- O fuso precisa existir em pg_timezone_names; um check não pode ter subconsulta.
create function app.conferir_fuso()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- Nulo segue para o not null da coluna (erro 23502), que o Postgres confere depois do gatilho.
  if new.fuso_horario is not null and not exists (select 1 from pg_catalog.pg_timezone_names t where t.name = new.fuso_horario) then
    raise exception 'Fuso horario invalido' using errcode = '22023';
  end if;
  return new;
end;
$$;
revoke all on function app.conferir_fuso() from public, anon, authenticated;

create trigger estudios_conferir_fuso
  before insert or update of fuso_horario on public.estudios
  for each row execute function app.conferir_fuso();

alter table public.estudios enable row level security;
revoke all on table public.estudios from anon, authenticated;
