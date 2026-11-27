-- Corrigir ficha de anamnese assinada sem perder o original (spec docs/specs/ficha-correcao.md), parte 1: estrutura.
-- Encoding: UTF-8
set client_encoding = 'UTF8';
--
-- 1. anamneses.replaces_anamnese_id: a ficha nova que a cliente corrige e assina de novo ("Reenviar para a cliente
--    corrigir") aponta para a assinada que ela corrige. A anterior NÃO muda (continua protegida por
--    protect_signed_anamnese_evidence): "substituída" é calculado — existe uma ficha ASSINADA que aponta para ela.
--    Enquanto a nova estiver pendente, a anterior continua valendo. Uma correção por ficha (índice único); revogar a
--    correção pendente libera pedir outra.
--    O índice único (estúdio, atendimento, modelo) passa a valer só para a ficha original (sem replaces): a correção
--    tem o mesmo atendimento e modelo.
-- 2. anamnese_answer_versions: "Corrigir respostas" pela profissional. Cada correção é uma versão nova das respostas
--    (com motivo, quem e quando); a ficha assinada guarda a original intocada (a trava não foi afrouxada). Sem acesso
--    pela API: leitura e gravação só pelas funções do banco (20261114120100). Auditoria por gatilho DEFINER:
--    quem, quando, versão e QUAIS perguntas mudaram (só os ids, nunca as respostas nem o motivo).

-- Espera no máximo 5 s pelas travas de anamneses (índices, coluna e restrições pedem trava forte): se a tabela estiver
-- ocupada, a migration falha e é rodada de novo, em vez de enfileirar todos os pedidos atrás dela.
set lock_timeout = '5s';

-- ─── 1. Ficha que corrige outra ─────────────────────────────────────────────────────────────────
-- Chave (id, org_id) para as ligações entre fichas e versões do mesmo estúdio.
create unique index if not exists uq_anamneses_id_org on public.anamneses (id, org_id);

alter table public.anamneses add column if not exists replaces_anamnese_id uuid;
alter table public.anamneses
  add constraint anamneses_replaces_same_org foreign key (replaces_anamnese_id, org_id)
    references public.anamneses (id, org_id),
  add constraint anamneses_replaces_not_self check (replaces_anamnese_id is null or replaces_anamnese_id <> id);
comment on column public.anamneses.replaces_anamnese_id is
  'Ficha assinada que esta corrige (a cliente responde e assina de novo). A anterior fica "substituída" quando esta é assinada.';

-- Uma correção por ficha (pendente ou assinada).
create unique index if not exists uq_anamneses_replaces on public.anamneses (replaces_anamnese_id)
  where replaces_anamnese_id is not null;

-- O único (estúdio, atendimento, modelo) vale para a original; a correção repete atendimento e modelo.
drop index if exists public.uq_anamneses_appointment_template;
create unique index uq_anamneses_appointment_template on public.anamneses (org_id, appointment_id, template_id)
  where appointment_id is not null and template_id is not null and replaces_anamnese_id is null;

reset lock_timeout;

-- ─── 2. Versões das respostas corrigidas pela profissional ─────────────────────────────────────
create table if not exists public.anamnese_answer_versions (
  id           uuid        primary key default gen_random_uuid(),
  org_id       uuid        not null references public.organizations (id) on delete cascade,
  anamnese_id  uuid        not null,
  version      integer     not null check (version >= 1),
  answers      jsonb       not null check (pg_catalog.jsonb_typeof(answers) = 'object' and pg_catalog.octet_length(answers::text) <= 250000),
  changed_keys text[]      not null check (pg_catalog.cardinality(changed_keys) between 1 and 500),
  reason       text        not null check (pg_catalog.char_length(pg_catalog.btrim(reason)) between 1 and 500),
  edited_by    uuid        references auth.users (id) on delete set null,
  created_at   timestamptz not null default pg_catalog.now(),
  constraint anamnese_answer_versions_ficha_same_org foreign key (anamnese_id, org_id)
    references public.anamneses (id, org_id) on delete cascade,
  unique (anamnese_id, version)
);
comment on table public.anamnese_answer_versions is
  'Respostas corrigidas pela profissional depois da assinatura (motivo, quem, quando). A original assinada fica em '
  'anamneses.answers, intocada. Só pelas funções do banco (sem acesso pela API).';
create index if not exists idx_anamnese_answer_versions_org on public.anamnese_answer_versions (org_id, anamnese_id);
create index if not exists idx_anamnese_answer_versions_edited_by on public.anamnese_answer_versions (edited_by);

alter table public.anamnese_answer_versions enable row level security;
revoke all on table public.anamnese_answer_versions from public, anon, authenticated, service_role;

-- Auditoria (regra de 14/11): gatilho DEFINER, sem execução para ninguém. Só ids das perguntas, nunca respostas/motivo.
create or replace function public.anamnese_answer_versions_audit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
  values (new.org_id, (select auth.uid()), 'anamneses', 'ANAMNESE_ANSWERS_CORRECTED', new.anamnese_id,
          pg_catalog.jsonb_build_object('version', new.version, 'changed', pg_catalog.to_jsonb(new.changed_keys)));
  return null;
end;
$$;
revoke all on function public.anamnese_answer_versions_audit() from public, anon, authenticated, service_role;

drop trigger if exists trg_anamnese_answer_versions_audit on public.anamnese_answer_versions;
create trigger trg_anamnese_answer_versions_audit
  after insert on public.anamnese_answer_versions
  for each row execute function public.anamnese_answer_versions_audit();
