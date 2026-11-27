-- Anamnese (porte): alcance "só minha agenda" e acesso direto pela API fechado. Dado de saúde (RGPD art. 9).
-- Encoding: UTF-8
set client_encoding = 'UTF8';
--
-- 1. anamneses.created_by: quem gerou a ficha. Preenchido SEMPRE pelo banco (gatilho: auth.uid() no INSERT,
--    imutável no UPDATE); as fichas antigas recebem o autor do registro ANAMNESE_CREATED / ANAMNESE_AUTO_LINKED.
-- 2. Regra ÚNICA de alcance (anamnese_row_in_scope), usada por todas as funções: quem vê a agenda inteira
--    (agenda_full_view_orgs) vê todas as fichas; os demais, só as dos próprios atendimentos e as que geraram.
-- 3. Tabela anamneses FECHADA para a API (sem SELECT/INSERT/UPDATE/DELETE para authenticated e anon): ler e
--    gravar só por funções SECURITY DEFINER que conferem estúdio, permissão e alcance (e gravam CLINICAL_READ na
--    leitura clínica). Assim ninguém forja ficha "assinada", token, validade ou fotos por PATCH/INSERT direto.
-- 4. Fotos (Storage anamnese-photos): sem política para authenticated. O servidor envia, assina (300 s) e apaga
--    com a chave de serviço, só depois de uma função do banco autorizar o caminho (<estúdio>/<ficha>/<arquivo>).
-- 5. CHECKs nas tabelas (NOT VALID + VALIDATE).
-- 6. audit_insert_member: saem CLINICAL_READ, PROFESSIONAL_*, ANAMNESE_PENDING_DELETED (anamnese: só gatilho ou
--    função DEFINER de leitura) e STOCK_* (o Catálogo grava estoque por gatilho DEFINER desde 20261114030100).
--    Lista = versão vigente do main (20261114020100) menos esses nove. audit_logs.created_at sempre = now()
--    (gatilho), para nenhum registro nascer com data forjada. Índice para os "últimos acessos" da ficha.
-- Efeito no app antigo (beauty-system, mesmo banco de desenvolvimento): as telas de anamnese de lá liam e
-- gravavam a tabela direto e deixam de funcionar (o app antigo não vai para produção).

-- ─── 1. Quem gerou a ficha ──────────────────────────────────────────────────────────────────────
alter table public.anamneses add column if not exists created_by uuid;
comment on column public.anamneses.created_by is
  'Quem gerou a ficha (gravado pelo banco no INSERT, imutável). Define o alcance de quem só vê a própria agenda.';

-- Fichas antigas: autor do primeiro registro de criação. O gatilho que protege a ficha assinada compara todas as
-- colunas; ele fica desligado só durante este preenchimento, num único bloco (desligar, preencher e religar
-- acontecem juntos ou nada acontece).
do $$
begin
  alter table public.anamneses disable trigger trg_protect_signed_anamnese_evidence;
  update public.anamneses a set created_by = l.user_id
  from (
    select distinct on (al.record_id) al.record_id, al.user_id
    from public.audit_logs al
    where al.table_name = 'anamneses' and al.operation in ('ANAMNESE_CREATED', 'ANAMNESE_AUTO_LINKED') and al.user_id is not null
    order by al.record_id, al.created_at
  ) l
  where a.id = l.record_id and a.created_by is null;
  alter table public.anamneses enable trigger trg_protect_signed_anamnese_evidence;
end;
$$;

create or replace function public.anamneses_set_created_by()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := (select auth.uid());
  else
    new.created_by := old.created_by;
  end if;
  return new;
end;
$$;
revoke all on function public.anamneses_set_created_by() from public, anon, authenticated;
drop trigger if exists trg_anamneses_created_by on public.anamneses;
create trigger trg_anamneses_created_by
  before insert or update on public.anamneses
  for each row execute function public.anamneses_set_created_by();

create index if not exists idx_anamneses_org_created_by on public.anamneses (org_id, created_by) where created_by is not null;
create index if not exists idx_anamneses_org_created_at on public.anamneses (org_id, created_at desc, id);

-- ─── 2. Regra única de alcance ──────────────────────────────────────────────────────────────────
-- DEFINER: precisa ver appointments/staff_members sem a RLS de quem chama. Só responde sim/não para auth.uid().
create or replace function public.anamnese_row_in_scope(p_org_id uuid, p_appointment_id uuid, p_created_by uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  -- Sempre verdadeiro ou falso (nunca nulo): quem chama usa "not" e nulo deixaria passar.
  select coalesce((select auth.uid()) is not null and (
    p_org_id in (select public.agenda_full_view_orgs())
    or p_created_by is not distinct from (select auth.uid()) and p_created_by is not null
    or (p_appointment_id is not null and exists (
      select 1 from public.appointments ap
      join public.staff_members sm on sm.id = ap.staff_id and sm.org_id = ap.org_id
      where ap.id = p_appointment_id and ap.org_id = p_org_id and sm.user_id = (select auth.uid())
    ))
  ), false);
$$;
revoke all on function public.anamnese_row_in_scope(uuid, uuid, uuid) from public, anon;
grant execute on function public.anamnese_row_in_scope(uuid, uuid, uuid) to authenticated;

-- A ficha (pelo id) está no alcance de quem chama? Para quem tem algum acesso à anamnese no estúdio.
create or replace function public.anamnese_in_scope(p_org_id uuid, p_anamnese_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (public.has_permission(p_org_id, 'anamnese.view_status') or public.has_permission(p_org_id, 'clientes.view_clinical'))
     and exists (
       select 1 from public.anamneses a
       where a.org_id = p_org_id and a.id = p_anamnese_id
         and public.anamnese_row_in_scope(a.org_id, a.appointment_id, a.created_by)
     );
$$;
revoke all on function public.anamnese_in_scope(uuid, uuid) from public, anon;
grant execute on function public.anamnese_in_scope(uuid, uuid) to authenticated;

-- ─── 3. Tabela fechada para a API ───────────────────────────────────────────────────────────────
-- A RLS continua ligada (sem política para ninguém além do dono); quem tem acesso usa as funções DEFINER.
revoke all on table public.anamneses from public, anon, authenticated;
drop policy if exists anamneses_select on public.anamneses;
drop policy if exists anamneses_insert on public.anamneses;
drop policy if exists anamneses_update on public.anamneses;
drop policy if exists anamneses_delete_pending on public.anamneses;

-- ─── 4. Fotos no Storage ────────────────────────────────────────────────────────────────────────
-- Sem ler, enviar ou apagar direto: o servidor faz isso com a chave de serviço depois de anamnese_photo_change,
-- anamnese_ficha_screen, anamnese_ficha_photos, anamnese_client_photos ou anamnese_delete_pending autorizarem.
drop policy if exists "anamnese_photos_select" on storage.objects;
drop policy if exists "anamnese_photos_insert" on storage.objects;
drop policy if exists "anamnese_photos_delete" on storage.objects;
drop policy if exists "anamnese_photos_update" on storage.objects;

-- ─── 5. CHECKs ──────────────────────────────────────────────────────────────────────────────────
alter table public.anamneses
  add constraint anamneses_status_check check (status in ('pending', 'signed')) not valid,
  add constraint anamneses_professional_data_check check (
    professional_data is null
    or (pg_catalog.jsonb_typeof(professional_data) = 'object' and pg_catalog.octet_length(professional_data::text) <= 250000)) not valid,
  add constraint anamneses_professional_notes_check check (
    professional_notes is null or pg_catalog.char_length(professional_notes) <= 5000) not valid;
alter table public.anamneses validate constraint anamneses_status_check;
alter table public.anamneses validate constraint anamneses_professional_data_check;
alter table public.anamneses validate constraint anamneses_professional_notes_check;

alter table public.anamnese_templates
  add constraint anamnese_templates_title_check check (pg_catalog.char_length(pg_catalog.btrim(title)) between 1 and 120) not valid,
  add constraint anamnese_templates_questions_check check (
    pg_catalog.jsonb_typeof(questions) = 'array' and pg_catalog.octet_length(questions::text) <= 600000) not valid,
  add constraint anamnese_templates_description_check check (description is null or pg_catalog.char_length(description) <= 500) not valid;
alter table public.anamnese_templates validate constraint anamnese_templates_title_check;
alter table public.anamnese_templates validate constraint anamnese_templates_questions_check;
alter table public.anamnese_templates validate constraint anamnese_templates_description_check;
-- País: anamnese_templates_country_check já existe (20261030400000).

-- ─── 6. Auditoria ───────────────────────────────────────────────────────────────────────────────
-- Versão vigente (20261114020100) sem CLINICAL_READ, PROFESSIONAL_DRAFT_SAVED / COMPLETED / NOTES_UPDATED /
-- REOPENED, ANAMNESE_PENDING_DELETED e STOCK_ENTRADA / SAIDA / AJUSTE. Nada novo entra aqui (regra de 14/11: auditoria nova só por gatilho ou função DEFINER de leitura).
drop policy if exists audit_insert_member on public.audit_logs;
create policy audit_insert_member on public.audit_logs for insert to authenticated
  with check (
    org_id in (select public.auth_org_ids())
    and user_id = (select auth.uid())
    and public.has_org_role(org_id, array['owner', 'admin', 'manager', 'receptionist', 'professional', 'finance'])
    and (
      (table_name, operation) in (
        ('appointments', 'APPOINTMENT_CREATED'),
        ('appointments', 'APPOINTMENT_UPDATED'),
        ('appointments', 'APPOINTMENT_RESCHEDULED'),
        ('appointments', 'STATUS_CHANGE'),
        ('appointments', 'RECURRENCE_CREATED'),
        ('appointments', 'RECURRENCE_UPDATED'),
        ('appointments', 'RECURRENCE_CANCELLED'),
        ('appointment_items', 'APPOINTMENT_ITEM_UPDATED'),
        ('time_blocks', 'TIME_BLOCKS_CREATED'),
        ('time_blocks', 'TIME_BLOCK_DELETED'),
        ('clients', 'CLIENT_BOOKING_BLOCKED'),
        ('clients', 'CLIENT_BOOKING_UNBLOCKED'),
        ('organizations', 'SETTINGS_SET'),
        -- O2: editar cliente, consentimento de marketing e devolução de sessão.
        ('clients', 'CLIENT_UPDATED'),
        ('clients', 'MARKETING_CONSENT_SET'),
        ('client_entitlements', 'ENTITLEMENT_SESSION_RESTORED'),
        -- Agenda: troca da cliente do agendamento (agenda_change_client).
        ('appointments', 'APPOINTMENT_CLIENT_CHANGED')
      )
    )
  );

create index if not exists idx_audit_logs_org_table_record on public.audit_logs (org_id, table_name, record_id, created_at desc);

-- Data do registro sempre a do banco (quem insere direto não escolhe created_at).
create or replace function public.audit_logs_force_created_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.created_at := pg_catalog.now();
  return new;
end;
$$;
revoke all on function public.audit_logs_force_created_at() from public, anon, authenticated;
drop trigger if exists trg_audit_logs_created_at on public.audit_logs;
create trigger trg_audit_logs_created_at
  before insert on public.audit_logs
  for each row execute function public.audit_logs_force_created_at();
