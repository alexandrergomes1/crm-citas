-- Anamnese: validade do link configurável, registro de envio e abertura, versão e país do modelo.
-- Encoding: UTF-8
--
-- Aditiva e compatível com o app que está em produção:
--   * colunas novas com padrão ou nulas; nenhuma função muda de assinatura (só ganham campos);
--   * get_anamnese_by_token(text) continua só de leitura e devolve campos a mais; a abertura é
--     registrada pela versão com dois parâmetros (get_anamnese_by_token(text, boolean)), que o
--     app antigo não chama;
--   * create_anamnese_atomic NÃO é reescrita: um gatilho de INSERT aplica a validade padrão do
--     estúdio e grava versão e país do modelo no snapshot, para qualquer caminho que crie ficha.
set client_encoding = 'UTF8';

-- 1. Colunas -----------------------------------------------------------------------------------
alter table public.anamneses
  add column if not exists first_opened_at timestamptz,
  add column if not exists last_opened_at timestamptz;

alter table public.anamnese_templates
  add column if not exists version integer not null default 1,
  add column if not exists country text not null default 'ES';

alter table public.anamnese_templates
  add constraint anamnese_templates_version_check check (version >= 1),
  add constraint anamnese_templates_country_check check (country ~ '^[A-Z]{2}$');

comment on column public.anamneses.first_opened_at is 'Primeira vez que a cliente abriu o link (pendente e no prazo).';
comment on column public.anamneses.last_opened_at is 'Última abertura do link; gravada no máximo uma vez por minuto.';
comment on column public.anamnese_templates.version is 'Sobe a cada edição de conteúdo; a ficha guarda a versão no snapshot e não muda depois.';
comment on column public.anamnese_templates.country is 'País (ISO 3166-1 alfa-2) cuja norma de privacidade o modelo segue.';

-- 2. Histórico de envio e abertura ----------------------------------------------------------------
create table if not exists public.anamnese_events (
  id          uuid        primary key default gen_random_uuid(),
  org_id      uuid        not null references public.organizations(id) on delete cascade,
  anamnese_id uuid        not null references public.anamneses(id) on delete cascade,
  kind        text        not null check (kind in ('sent', 'opened', 'renewed')),
  channel     text        check (channel in ('whatsapp', 'qr', 'studio', 'copy')),
  user_id     uuid,
  meta        jsonb       not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);
comment on table public.anamnese_events is
  'Envio do link (canal e quem enviou), renovação e primeira abertura pela cliente. Só por função (spec 12).';
create index if not exists idx_anamnese_events_org_created on public.anamnese_events (org_id, created_at desc);
create index if not exists idx_anamnese_events_anamnese on public.anamnese_events (anamnese_id, created_at desc);

alter table public.anamnese_events enable row level security;
revoke all on public.anamnese_events from anon;
revoke insert, update, delete, truncate, trigger, references on public.anamnese_events from authenticated;
drop policy if exists anamnese_events_select on public.anamnese_events;
create policy anamnese_events_select on public.anamnese_events for select to authenticated
  using (org_id in (select public.auth_org_ids()) and public.has_permission(org_id, 'anamnese.view_status'));

-- 3. Gatilho: modelo muda de versão; ficha nova guarda versão e país e a validade do estúdio ----------
create or replace function public.anamnese_templates_bump_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (new.title, new.questions, new.consent_text, new.consent_version, new.professional_form, new.country)
     is distinct from
     (old.title, old.questions, old.consent_text, old.consent_version, old.professional_form, old.country) then
    new.version := old.version + 1;
  else
    new.version := old.version;
  end if;
  return new;
end;
$$;
revoke all on function public.anamnese_templates_bump_version() from public, anon, authenticated;

drop trigger if exists trg_anamnese_templates_bump_version on public.anamnese_templates;
create trigger trg_anamnese_templates_bump_version
  before update on public.anamnese_templates
  for each row execute function public.anamnese_templates_bump_version();

create or replace function public.anamneses_apply_defaults()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_days_text text;
  v_tpl record;
begin
  -- Validade padrão do estúdio (Ajustes › Ficha de saúde); sem ajuste, vale o que a função gravou (7 dias).
  select o.settings #>> '{anamnese,link_days}' into v_days_text
  from public.organizations o where o.id = new.org_id;
  if v_days_text in ('1', '3', '7', '15', '30') then
    new.token_expires_at := pg_catalog.now() + pg_catalog.make_interval(days => v_days_text::integer);
  end if;

  -- Versão e país do modelo no momento do envio: o snapshot não muda depois.
  if new.template_id is not null and new.template_snapshot is not null
     and pg_catalog.jsonb_typeof(new.template_snapshot) = 'object' then
    select t.version, t.country into v_tpl from public.anamnese_templates t where t.id = new.template_id;
    if found then
      new.template_snapshot := new.template_snapshot
        || pg_catalog.jsonb_build_object('template_version', v_tpl.version, 'template_country', v_tpl.country);
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.anamneses_apply_defaults() from public, anon, authenticated;

drop trigger if exists trg_anamneses_apply_defaults on public.anamneses;
create trigger trg_anamneses_apply_defaults
  before insert on public.anamneses
  for each row execute function public.anamneses_apply_defaults();

-- 4. Registrar envio ---------------------------------------------------------------------------------
create or replace function public.log_anamnese_send(p_org_id uuid, p_anamnese_id uuid, p_channel text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_ficha record;
  v_id uuid;
begin
  if v_uid is null or not public.has_permission(p_org_id, 'anamnese.view_status') then
    raise exception 'Sem permissão para registrar envio de ficha' using errcode = '42501';
  end if;
  if p_channel is null or p_channel not in ('whatsapp', 'qr', 'studio', 'copy') then
    raise exception 'Canal de envio inválido' using errcode = '22023';
  end if;

  select a.id, a.status, a.token_expires_at into v_ficha
  from public.anamneses a where a.id = p_anamnese_id and a.org_id = p_org_id for update;
  if not found then
    raise exception 'Ficha não encontrada' using errcode = 'P0002';
  end if;
  if v_ficha.status = 'signed' then
    raise exception 'Ficha já assinada' using errcode = 'P0001';
  end if;

  -- Duplo clique ou nova tentativa em 10 s: devolve o registro que já existe.
  select e.id into v_id from public.anamnese_events e
  where e.anamnese_id = p_anamnese_id and e.kind = 'sent' and e.channel = p_channel and e.user_id = v_uid
    and e.created_at > pg_catalog.now() - interval '10 seconds'
  order by e.created_at desc limit 1;
  if found then return v_id; end if;

  insert into public.anamnese_events (org_id, anamnese_id, kind, channel, user_id, meta)
  values (p_org_id, p_anamnese_id, 'sent', p_channel, v_uid,
          pg_catalog.jsonb_build_object('expires_at', v_ficha.token_expires_at))
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.log_anamnese_send(uuid, uuid, text) from public, anon;
grant execute on function public.log_anamnese_send(uuid, uuid, text) to authenticated;

-- 5. Validade do link (24 h, 3, 7, 15 ou 30 dias) ------------------------------------------------------
create or replace function public.set_anamnese_link_validity(p_org_id uuid, p_anamnese_id uuid, p_days integer)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_ficha record;
  v_until timestamptz;
begin
  if v_uid is null or not public.has_permission(p_org_id, 'anamnese.view_status') then
    raise exception 'Sem permissão para alterar a validade do link' using errcode = '42501';
  end if;
  if p_days is null or p_days not in (1, 3, 7, 15, 30) then
    raise exception 'Validade inválida' using errcode = '22023';
  end if;

  select a.id, a.status, a.token_expires_at into v_ficha
  from public.anamneses a where a.id = p_anamnese_id and a.org_id = p_org_id for update;
  if not found then
    raise exception 'Ficha não encontrada' using errcode = 'P0002';
  end if;
  if v_ficha.status = 'signed' then
    raise exception 'Ficha já assinada' using errcode = 'P0001';
  end if;

  v_until := pg_catalog.now() + pg_catalog.make_interval(days => p_days);
  update public.anamneses set token_expires_at = v_until where id = p_anamnese_id and org_id = p_org_id;

  -- Link que já tinha vencido e foi reaberto fica registrado.
  if v_ficha.token_expires_at < pg_catalog.now() then
    insert into public.anamnese_events (org_id, anamnese_id, kind, user_id, meta)
    values (p_org_id, p_anamnese_id, 'renewed', v_uid,
            pg_catalog.jsonb_build_object('days', p_days, 'expires_at', v_until));
  end if;
  return v_until;
end;
$$;
revoke all on function public.set_anamnese_link_validity(uuid, uuid, integer) from public, anon;
grant execute on function public.set_anamnese_link_validity(uuid, uuid, integer) to authenticated;

-- 6. Eventos para a visão geral e para a linha do tempo da ficha ---------------------------------------
create or replace function public.list_anamnese_events(p_org_id uuid, p_anamnese_id uuid default null, p_limit integer default 30)
returns table (
  id uuid,
  anamnese_id uuid,
  client_name text,
  kind text,
  channel text,
  user_name text,
  meta jsonb,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.has_permission(p_org_id, 'anamnese.view_status') then
    raise exception 'Sem permissão para consultar fichas de anamnese' using errcode = '42501';
  end if;
  return query
  select e.id, e.anamnese_id, a.client_name, e.kind, e.channel,
         (select p.full_name from public.profiles p where p.org_id = e.org_id and p.user_id = e.user_id limit 1),
         e.meta, e.created_at
  from public.anamnese_events e
  join public.anamneses a on a.id = e.anamnese_id and a.org_id = e.org_id
  where e.org_id = p_org_id
    and (p_anamnese_id is null or e.anamnese_id = p_anamnese_id)
  order by e.created_at desc, e.id
  limit least(greatest(coalesce(p_limit, 30), 1), 100);
end;
$$;
revoke all on function public.list_anamnese_events(uuid, uuid, integer) from public, anon;
grant execute on function public.list_anamnese_events(uuid, uuid, integer) to authenticated;

-- 7. Abertura do link (público) ---------------------------------------------------------------------------
-- A leitura de sempre ganha os campos que a tela da cliente pede: validade, data do atendimento e fuso.
-- Nada clínico: o mesmo que a cliente já vê no WhatsApp. Atendimento cancelado não é mostrado.
create or replace function public.get_anamnese_by_token(p_token text)
 returns jsonb
 language sql
 stable security definer
 set search_path to ''
as $function$
  select jsonb_build_object(
    'id',                 a.id,
    'status',             a.status,
    'client_name',        a.client_name,
    'org_name',           o.name,
    'template_title',     a.template_title,
    'questions',          case when v.open then coalesce(a.template_snapshot->'questions', '[]'::jsonb) else '[]'::jsonb end,
    'answers',            case when v.open then coalesce(a.answers, '{}'::jsonb) else '{}'::jsonb end,
    'consent_text',       case when v.open then a.consent_text end,
    'consent_version',    a.consent_version,
    'signature_name',     null,
    'signature_data_url', null,
    'signed_at',          a.signed_at,
    'expired',            v.expired,
    'expires_at',         a.token_expires_at,
    'org_timezone',       o.timezone,
    'org_address',        case when not v.expired then nullif(pg_catalog.btrim(concat_ws(', ', o.address, o.city)), '') end,
    'appointment_at',     case when not v.expired then ap.start_at end,
    'appointment_end_at', case when not v.expired then ap.end_at end,
    'appointment_service', case when not v.expired and ap.id is not null then (
      select pg_catalog.string_agg(i.name, ' · ' order by i.created_at, i.id)
      from public.appointment_items i
      where i.appointment_id = ap.id and i.org_id = ap.org_id and pg_catalog.lower(i.type) = 'service'
    ) end
  )
  from public.anamneses a
  join public.organizations o on o.id = a.org_id
  left join public.appointments ap on ap.id = a.appointment_id and ap.org_id = a.org_id and ap.status <> 'Cancelado'
  cross join lateral (
    select (a.token_expires_at is not null and a.token_expires_at < pg_catalog.now()) as expired
  ) e
  cross join lateral (
    select e.expired, (a.status <> 'signed' and not e.expired) as open
  ) v
  where p_token is not null
    and pg_catalog.length(p_token) between 16 and 200
    and a.public_token = p_token;
$function$;

-- Mesma leitura, registrando a abertura (só ficha pendente e no prazo; no máximo uma gravação por minuto).
-- Quem chama decide: o app não registra quando o pedido vem de robô de pré-visualização.
create or replace function public.get_anamnese_by_token(p_token text, p_record boolean)
 returns jsonb
 language plpgsql
 volatile security definer
 set search_path to ''
as $function$
declare
  v record;
begin
  if coalesce(p_record, false) and p_token is not null and pg_catalog.length(p_token) between 16 and 200 then
    select a.id, a.org_id, a.first_opened_at, a.last_opened_at into v
    from public.anamneses a
    where a.public_token = p_token and a.status = 'pending' and a.token_expires_at >= pg_catalog.now()
    for update;
    if found and (v.last_opened_at is null or v.last_opened_at < pg_catalog.now() - interval '1 minute') then
      update public.anamneses
         set last_opened_at = pg_catalog.now(),
             first_opened_at = coalesce(v.first_opened_at, pg_catalog.now())
       where id = v.id;
      if v.first_opened_at is null then
        insert into public.anamnese_events (org_id, anamnese_id, kind) values (v.org_id, v.id, 'opened');
      end if;
    end if;
  end if;
  return public.get_anamnese_by_token(p_token);
end;
$function$;

revoke all on function public.get_anamnese_by_token(text) from public;
revoke all on function public.get_anamnese_by_token(text, boolean) from public;
grant execute on function public.get_anamnese_by_token(text) to anon, authenticated;
grant execute on function public.get_anamnese_by_token(text, boolean) to anon, authenticated;

-- 8. Ajustes da ficha (validade padrão e modo estúdio) -------------------------------------------------------
-- Função própria (não mexe em set_org_settings): só quem pode alterar ajustes do estúdio.
create or replace function public.set_anamnese_settings(p_org_id uuid, p_link_days integer, p_studio_mode boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'ajustes.manage') then
    raise exception 'Sem permissão para alterar configurações' using errcode = '42501';
  end if;
  if p_link_days is null or p_link_days not in (1, 3, 7, 15, 30) then
    raise exception 'Validade inválida' using errcode = '22023';
  end if;
  if p_studio_mode is null then
    raise exception 'Modo estúdio inválido' using errcode = '22023';
  end if;

  update public.organizations o
     set settings = pg_catalog.jsonb_set(
           coalesce(o.settings, '{}'::jsonb), '{anamnese}',
           pg_catalog.jsonb_build_object('link_days', p_link_days, 'studio_mode', p_studio_mode), true)
   where o.id = p_org_id;
  if not found then
    raise exception 'Estúdio não encontrado' using errcode = 'P0002';
  end if;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
  values (p_org_id, (select auth.uid()), 'organizations', 'ANAMNESE_SETTINGS_SET', p_org_id,
          pg_catalog.jsonb_build_object('link_days', p_link_days, 'studio_mode', p_studio_mode));
end;
$$;
revoke all on function public.set_anamnese_settings(uuid, integer, boolean) from public, anon;
grant execute on function public.set_anamnese_settings(uuid, integer, boolean) to authenticated;
