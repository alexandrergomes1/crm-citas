-- Item 3 · spec 20261128-010000-banco-ligacao · plan.md §3.2 · ADR 0005 (T2, T3, T10).
-- A pessoa ligada a um estúdio, com o seu papel. Sem nome, telefone ou e-mail (minimização).
-- RLS ligada sem política: fecha tudo até a migration politicas_base.

create table public.membros (
  org_id        uuid        not null references public.estudios (org_id) on delete cascade,
  user_id       uuid        not null references auth.users (id) on delete cascade,
  papel         text        not null check (papel in ('dona', 'recepcao', 'profissional')),
  ativo         boolean     not null default true,
  estudio_atual boolean     not null default false,
  criado_em     timestamptz not null default now(),
  primary key (org_id, user_id)
);
comment on table public.membros is 'Vínculo pessoa × estúdio e papel. estudio_atual: o estúdio que vale na sessão (no máximo um por pessoa).';

create index membros_user_id_idx on public.membros (user_id);
create unique index membros_estudio_atual_unico on public.membros (user_id) where estudio_atual;

alter table public.membros enable row level security;
revoke all on table public.membros from anon, authenticated;
