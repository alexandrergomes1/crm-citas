-- Páginas públicas, parte 2: ficha pelo link (/forms) e modo estúdio, em UMA ida ao banco por página ou ação.
-- Encoding: UTF-8
set client_encoding = 'UTF8';
--
-- Funções do link (só o servidor chama, com a chave de serviço; anon e authenticated não executam):
--   public_anamnese_open      abre o link: confere hash + validade + status, limite por IP e por token; registra a
--                             primeira abertura. Inválido, vencido, assinado ou bloqueado: a MESMA resposta (null).
--   public_anamnese_sign      assina: respostas + consentimento + assinatura de uma vez (tudo-ou-nada), só pendente
--                             e no prazo; erro do link sempre 'not_found'.
--   public_anamnese_calendar  .ics do atendimento enquanto o link vale (pendente ou já assinada, sem dado clínico).
-- Modo estúdio (pessoa logada da equipe; o aparelho entregue só usa estas):
--   studio_team_screen, studio_anamnese_open, studio_anamnese_sign, studio_mode_enter.
-- Antigas get_anamnese_by_token (1 e 2 parâmetros) e submit_anamnese_signature (6 e 7) saem: liam o token em claro e
-- eram executáveis por anon.
-- Auditoria (gatilho DEFINER anamneses_audit): ANAMNESE_SIGNED (canal, sem respostas) e ANAMNESE_LINK_REISSUED.
-- Depois de assinada a ficha é imutável (protect_signed_anamnese_evidence, já existente).

drop function if exists public.get_anamnese_by_token(text, boolean);
drop function if exists public.get_anamnese_by_token(text);
drop function if exists public.submit_anamnese_signature(text, jsonb, text, text, boolean, text);
drop function if exists public.submit_anamnese_signature(text, jsonb, text, text, boolean, text, text);

-- ─── Peças internas (sem execução para ninguém) ──────────────────────────────────────────────────

-- Só o que a tela da cliente usa: nome do estúdio, perguntas e termos do snapshot da ficha, nome da cliente (para
-- preencher), validade e o atendimento (data e serviços). Sem id da ficha (vai uma referência curta), sem telefone,
-- e-mail, assinatura ou dado de outra ficha.
create or replace function public.anamnese_public_payload_internal(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'reference',          'AN-' || pg_catalog.upper(pg_catalog.left(pg_catalog.replace(a.id::text, '-', ''), 8)),
    'status',             a.status,
    'client_name',        a.client_name,
    'org_name',           o.name,
    'template_title',     a.template_title,
    'questions',          case when a.status = 'pending' then coalesce(a.template_snapshot -> 'questions', '[]'::jsonb) else '[]'::jsonb end,
    'answers',            case when a.status = 'pending' then coalesce(a.answers, '{}'::jsonb) else '{}'::jsonb end,
    'consent_text',       case when a.status = 'pending' then a.consent_text end,
    'consent_version',    a.consent_version,
    'signed_at',          a.signed_at,
    'expired',            a.token_expires_at is null or a.token_expires_at < pg_catalog.now(),
    'expires_at',         a.token_expires_at,
    'org_timezone',       o.timezone,
    'org_address',        nullif(pg_catalog.btrim(pg_catalog.concat_ws(', ', o.address, o.city)), ''),
    'appointment_at',     ap.start_at,
    'appointment_end_at', ap.end_at,
    'appointment_service', case when ap.id is not null then (
      select pg_catalog.string_agg(i.name, ' · ' order by i.created_at, i.id)
      from public.appointment_items i
      where i.appointment_id = ap.id and i.org_id = ap.org_id and pg_catalog.lower(i.type) = 'service') end
  )
  from public.anamneses a
  join public.organizations o on o.id = a.org_id
  left join public.appointments ap on ap.id = a.appointment_id and ap.org_id = a.org_id and ap.status <> 'Cancelado'
  where a.id = p_id;
$$;
revoke all on function public.anamnese_public_payload_internal(uuid) from public, anon, authenticated, service_role;

-- Primeira e última abertura (no máximo uma gravação por minuto), só para ficha pendente e no prazo.
create or replace function public.anamnese_mark_opened_internal(p_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v record;
begin
  select a.id, a.org_id, a.first_opened_at, a.last_opened_at into v
  from public.anamneses a
  where a.id = p_id and a.status = 'pending' and a.token_expires_at >= pg_catalog.now()
  for update;
  if found and (v.last_opened_at is null or v.last_opened_at < pg_catalog.now() - interval '1 minute') then
    update public.anamneses
       set last_opened_at = pg_catalog.now(), first_opened_at = coalesce(v.first_opened_at, pg_catalog.now())
     where id = v.id;
    if v.first_opened_at is null then
      insert into public.anamnese_events (org_id, anamnese_id, kind) values (v.org_id, v.id, 'opened');
    end if;
  end if;
end;
$$;
revoke all on function public.anamnese_mark_opened_internal(uuid) from public, anon, authenticated, service_role;

-- Assinatura (link ou modo estúdio): o banco reconfere, contra o snapshot da própria ficha, termos, perguntas
-- obrigatórias e o canal; grava respostas, consentimento, assinatura e prova (aparelho e IP anonimizado) num UPDATE
-- só. Ficha que não está pendente e no prazo: 'not_found' (a mesma resposta para inválido, vencido e usado).
create or replace function public.anamnese_sign_internal(
  p_id uuid, p_channel text, p_answers jsonb, p_signature_name text, p_signature_data_url text,
  p_consent_accepted boolean, p_user_agent text, p_ip text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v public.anamneses;
  v_answers jsonb := coalesce(p_answers, '{}'::jsonb);
  v_blocks jsonb;
  b jsonb;
  v_id text;
  v_type text;
  v_required boolean;
  v_value text;
begin
  select * into v from public.anamneses where id = p_id for update;
  if not found or v.status <> 'pending' or v.token_expires_at is null or v.token_expires_at < pg_catalog.now() then
    return pg_catalog.jsonb_build_object('error', 'not_found');
  end if;
  if coalesce(p_consent_accepted, false) = false then
    return pg_catalog.jsonb_build_object('error', 'consent_required');
  end if;
  if p_signature_data_url is null or pg_catalog.length(p_signature_data_url) < 50 then
    return pg_catalog.jsonb_build_object('error', 'signature_required');
  end if;
  -- Formato e tamanho: assinatura em PNG (base64) até 1 MB; nome até 160; respostas em objeto de textos curtos.
  if pg_catalog.length(p_signature_data_url) > 1000000
     or p_signature_data_url !~ '^data:image/png;base64,[A-Za-z0-9+/]+={0,2}$'
     or pg_catalog.char_length(pg_catalog.btrim(coalesce(p_signature_name, ''))) not between 1 and 160
     or pg_catalog.jsonb_typeof(v_answers) <> 'object'
     or pg_catalog.pg_column_size(v_answers) > 200000
     or (select pg_catalog.count(*) from pg_catalog.jsonb_object_keys(v_answers)) > 500
     or exists (select 1 from pg_catalog.jsonb_each(v_answers) e
                where pg_catalog.jsonb_typeof(e.value) <> 'string'
                   or pg_catalog.char_length(e.key) > 120
                   or pg_catalog.char_length(e.value #>> '{}') > 5000)
     or pg_catalog.char_length(coalesce(p_user_agent, '')) > 2000 then
    return pg_catalog.jsonb_build_object('error', 'invalid_payload');
  end if;

  -- Canal: o do caminho usado (link no celular ou modo estúdio, gravado como "tablet", valor histórico).
  if p_channel not in ('link', 'tablet') or v_answers ->> '__canal' is distinct from p_channel then
    return pg_catalog.jsonb_build_object('error', 'channel_invalid');
  end if;

  if pg_catalog.btrim(coalesce(v.consent_text, '')) <> '' and v_answers ->> '__termo_principal' is distinct from 'aceito' then
    return pg_catalog.jsonb_build_object('error', 'terms_required');
  end if;

  v_blocks := case when pg_catalog.jsonb_typeof(v.template_snapshot -> 'questions') = 'array'
                   then v.template_snapshot -> 'questions' else '[]'::jsonb end;
  for b in select value from pg_catalog.jsonb_array_elements(v_blocks) loop
    if pg_catalog.jsonb_typeof(b) <> 'object' then continue; end if;
    v_id := b ->> 'id';
    v_type := b ->> 'type';
    if v_id is null then continue; end if;
    v_required := (b -> 'required') = 'true'::jsonb;
    v_value := v_answers ->> v_id;
    if v_type = 'consent' then
      if v_required then
        if v_value is distinct from 'aceito' then
          return pg_catalog.jsonb_build_object('error', 'terms_required');
        end if;
      elsif v_value is null or v_value not in ('aceito', 'recusado') then
        return pg_catalog.jsonb_build_object('error', 'terms_required');
      end if;
    elsif v_type in ('yes_no', 'multiple_choice', 'text') then
      if v_required and pg_catalog.btrim(coalesce(v_value, '')) = '' then
        return pg_catalog.jsonb_build_object('error', 'answers_required');
      end if;
      if coalesce(b ->> 'explainWhenAnswer', '') <> '' and v_value = b ->> 'explainWhenAnswer'
         and pg_catalog.btrim(coalesce(v_answers ->> (v_id || '__explain'), '')) = '' then
        return pg_catalog.jsonb_build_object('error', 'answers_required');
      end if;
    end if;
  end loop;

  update public.anamneses set
    answers            = v_answers,
    signature_name     = pg_catalog.btrim(p_signature_name),
    signature_data_url = p_signature_data_url,
    consent_accepted   = true,
    signer_user_agent  = pg_catalog.left(p_user_agent, 500),
    signer_ip          = public.anonymize_ip(p_ip),
    status             = 'signed',
    signed_at          = pg_catalog.now(),
    updated_at         = pg_catalog.now()
  where id = v.id and status = 'pending';

  return pg_catalog.jsonb_build_object('ok', true, 'signed_at', pg_catalog.now());
end;
$$;
revoke all on function public.anamnese_sign_internal(uuid, text, jsonb, text, text, boolean, text, text) from public, anon, authenticated, service_role;

-- Ficha pelo token: hash + limites. Devolve o id só quando o link vale (pendente e no prazo); senão null e conta
-- como erro do IP. p_bucket_token: limite próprio de abrir (60) ou assinar (10) por token em 10 min.
create or replace function public.anamnese_by_token_internal(p_token text, p_client_key text, p_token_bucket text, p_token_limit integer)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_hash text;
  v_id uuid;
begin
  -- Por IP: 120 pedidos e 20 links errados em 10 min; passou disso, todo link responde como inexistente.
  if not public.public_link_throttle_internal('form_ip', p_client_key, 120, 600)
     or not public.public_link_throttle_internal('form_miss_ip', p_client_key, 20, 600, false) then
    return null;
  end if;
  if p_token is not null and p_token ~ '^[A-Za-z0-9_-]{16,200}$' then
    v_hash := public.public_token_hash_internal(p_token);
    select a.id into v_id from public.anamneses a
    where a.token_hash = v_hash and a.status = 'pending' and a.token_expires_at >= pg_catalog.now();
  end if;
  if v_id is null then
    perform public.public_link_throttle_internal('form_miss_ip', p_client_key, 20, 600);
    return null;
  end if;
  if not public.public_link_throttle_internal(p_token_bucket, v_hash, p_token_limit, 600) then
    return null;
  end if;
  return v_id;
end;
$$;
revoke all on function public.anamnese_by_token_internal(text, text, text, integer) from public, anon, authenticated, service_role;

-- O modo estúdio está ligado em Ajustes › Ficha de saúde (padrão: ligado).
create or replace function public.anamnese_studio_mode_on_internal(p_org_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select (o.settings #> '{anamnese,studio_mode}') is distinct from 'false'::jsonb
                   from public.organizations o where o.id = p_org_id and o.active), false);
$$;
revoke all on function public.anamnese_studio_mode_on_internal(uuid) from public, anon, authenticated, service_role;

-- ─── Link público (/forms): só o servidor (chave de serviço) ─────────────────────────────────────

create or replace function public.public_anamnese_open(p_token text, p_client_key text, p_record boolean)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_id uuid := public.anamnese_by_token_internal(p_token, p_client_key, 'form_token', 60);
begin
  if v_id is null then return null; end if;
  if coalesce(p_record, false) then
    perform public.anamnese_mark_opened_internal(v_id);
  end if;
  return public.anamnese_public_payload_internal(v_id);
end;
$$;
revoke all on function public.public_anamnese_open(text, text, boolean) from public, anon, authenticated;
grant execute on function public.public_anamnese_open(text, text, boolean) to service_role;

-- Limite estourado (do IP, ou do link: 10 tentativas em 10 min) responde 'rate_limited' ("tente mais tarde"): só quem
-- tem o link vê o do link, e o do IP vale para qualquer link. Inválido, vencido ou usado: 'not_found'.
create or replace function public.public_anamnese_sign(
  p_token text, p_client_key text, p_answers jsonb, p_signature_name text, p_signature_data_url text,
  p_consent_accepted boolean, p_user_agent text, p_ip text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_hash text;
  v_id uuid;
begin
  if not public.public_link_throttle_internal('form_ip', p_client_key, 120, 600)
     or not public.public_link_throttle_internal('form_miss_ip', p_client_key, 20, 600, false) then
    return pg_catalog.jsonb_build_object('error', 'rate_limited');
  end if;
  if p_token is not null and p_token ~ '^[A-Za-z0-9_-]{16,200}$' then
    v_hash := public.public_token_hash_internal(p_token);
    select a.id into v_id from public.anamneses a
    where a.token_hash = v_hash and a.status = 'pending' and a.token_expires_at >= pg_catalog.now();
  end if;
  if v_id is null then
    perform public.public_link_throttle_internal('form_miss_ip', p_client_key, 20, 600);
    return pg_catalog.jsonb_build_object('error', 'not_found');
  end if;
  if not public.public_link_throttle_internal('sign_token', v_hash, 10, 600) then
    return pg_catalog.jsonb_build_object('error', 'rate_limited');
  end if;
  return public.anamnese_sign_internal(v_id, 'link', p_answers, p_signature_name, p_signature_data_url,
    p_consent_accepted, p_user_agent, p_ip);
end;
$$;
revoke all on function public.public_anamnese_sign(text, text, jsonb, text, text, boolean, text, text) from public, anon, authenticated;
grant execute on function public.public_anamnese_sign(text, text, jsonb, text, text, boolean, text, text) to service_role;

-- "Adicionar ao calendário": enquanto o link vale (pendente, ou assinada há pouco: a cliente baixa depois de
-- assinar) e com atendimento não cancelado. Só data, serviços, estúdio e endereço; nada clínico.
create or replace function public.public_anamnese_calendar(p_token text, p_client_key text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_hash text;
  v_id uuid;
  v jsonb;
begin
  if not public.public_link_throttle_internal('form_ip', p_client_key, 120, 600)
     or not public.public_link_throttle_internal('form_miss_ip', p_client_key, 20, 600, false) then
    return null;
  end if;
  if p_token is not null and p_token ~ '^[A-Za-z0-9_-]{16,200}$' then
    v_hash := public.public_token_hash_internal(p_token);
    select a.id into v_id from public.anamneses a
    where a.token_hash = v_hash and a.token_expires_at >= pg_catalog.now();
  end if;
  if v_id is null then
    perform public.public_link_throttle_internal('form_miss_ip', p_client_key, 20, 600);
    return null;
  end if;
  if not public.public_link_throttle_internal('form_token', v_hash, 60, 600) then return null; end if;
  v := public.anamnese_public_payload_internal(v_id);
  if v ->> 'appointment_at' is null then return null; end if;
  return pg_catalog.jsonb_build_object(
    'reference', v -> 'reference', 'org_name', v -> 'org_name', 'template_title', v -> 'template_title',
    'org_address', v -> 'org_address', 'appointment_at', v -> 'appointment_at',
    'appointment_end_at', v -> 'appointment_end_at', 'appointment_service', v -> 'appointment_service');
end;
$$;
revoke all on function public.public_anamnese_calendar(text, text) from public, anon, authenticated;
grant execute on function public.public_anamnese_calendar(text, text) to service_role;

-- ─── Modo estúdio (pessoa da equipe logada) ──────────────────────────────────────────────────────

create or replace function public.studio_mode_assert_internal(p_org_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'anamnese.view_status') then
    raise exception 'Sem permissão para usar o modo estúdio' using errcode = '42501';
  end if;
  if not public.anamnese_studio_mode_on_internal(p_org_id) then
    raise exception 'O modo estúdio está desligado em Ajustes › Ficha de saúde.' using errcode = 'P0001';
  end if;
end;
$$;
revoke all on function public.studio_mode_assert_internal(uuid) from public, anon, authenticated, service_role;

-- Tela da equipe: quem tem ficha hoje (fuso do estúdio), só agendamentos no alcance de quem vê, e o PIN.
create or replace function public.studio_team_screen(p_org_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tz text;
  v_from timestamptz;
  v_rows jsonb;
begin
  perform public.studio_mode_assert_internal(p_org_id);
  select coalesce(nullif(o.timezone, ''), 'Europe/Madrid') into v_tz from public.organizations o where o.id = p_org_id;
  v_from := ((pg_catalog.now() at time zone v_tz)::date)::timestamp at time zone v_tz;

  select coalesce(pg_catalog.jsonb_agg(r.row order by r.start_at, r.id), '[]'::jsonb) into v_rows
  from (
    select ap.id, ap.start_at, pg_catalog.jsonb_build_object(
      'appointment_id', ap.id, 'client_id', ap.client_id, 'client_name', ap.client_name, 'start_at', ap.start_at,
      'services', (select pg_catalog.string_agg(i.name, ' · ' order by i.created_at, i.id) from public.appointment_items i
                   where i.org_id = ap.org_id and i.appointment_id = ap.id and pg_catalog.lower(i.type) = 'service'),
      'template_id', tpl.id, 'template_title', coalesce(tpl.title, f.template_title),
      'ficha', case when f.id is not null then pg_catalog.jsonb_build_object('id', f.id, 'status', f.status) end
    ) as row
    from public.appointments ap
    left join lateral (
      select t.id, t.title from public.appointment_items i
      join public.anamnese_templates t on t.id = i.anamnese_template_id and t.org_id = i.org_id
      where i.org_id = ap.org_id and i.appointment_id = ap.id and i.anamnese_template_id is not null
      order by i.created_at, i.id limit 1
    ) tpl on true
    left join lateral (
      select a.id, a.status, a.template_title from public.anamneses a
      where a.org_id = ap.org_id and a.appointment_id = ap.id
      order by (a.status = 'pending') desc, a.created_at desc limit 1
    ) f on true
    where ap.org_id = p_org_id
      and ap.start_at >= v_from and ap.start_at < v_from + interval '1 day'
      and ap.status not in ('Cancelado', 'Faltou', 'Ausência')
      and public.anamnese_row_in_scope(p_org_id, ap.id, null)
      and (tpl.id is not null or f.id is not null
           or exists (select 1 from public.appointment_items i
                      where i.org_id = ap.org_id and i.appointment_id = ap.id and i.requires_anamnese))
    limit 200
  ) r;

  return pg_catalog.jsonb_build_object(
    'rows', v_rows,
    'timezone', v_tz,
    'pin_configured', exists (select 1 from public.studio_mode_pins p where p.org_id = p_org_id),
    'can_create_pin', public.has_permission(p_org_id, 'ajustes.manage'));
end;
$$;
revoke all on function public.studio_team_screen(uuid) from public, anon;
grant execute on function public.studio_team_screen(uuid) to authenticated;

-- Ficha no aparelho do estúdio: mesmos campos do link + situação (aberta, assinada ou vencida) e se há PIN. p_record:
-- o aparelho já está com a cliente (a abertura conta).
create or replace function public.studio_anamnese_open(p_org_id uuid, p_anamnese_id uuid, p_record boolean)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v record;
begin
  perform public.studio_mode_assert_internal(p_org_id);
  if not public.anamnese_in_scope(p_org_id, p_anamnese_id) then return null; end if;
  select a.id, a.status, a.token_expires_at into v from public.anamneses a
  where a.org_id = p_org_id and a.id = p_anamnese_id;
  if not found then return null; end if;
  if coalesce(p_record, false) then perform public.anamnese_mark_opened_internal(v.id); end if;
  return public.anamnese_public_payload_internal(v.id) || pg_catalog.jsonb_build_object(
    'state', case when v.status = 'signed' then 'signed'
                  when v.token_expires_at is null or v.token_expires_at < pg_catalog.now() then 'expired'
                  else 'open' end,
    'pin_configured', exists (select 1 from public.studio_mode_pins p where p.org_id = p_org_id),
    'can_create_pin', public.has_permission(p_org_id, 'ajustes.manage'));
end;
$$;
revoke all on function public.studio_anamnese_open(uuid, uuid, boolean) from public, anon;
grant execute on function public.studio_anamnese_open(uuid, uuid, boolean) to authenticated;

create or replace function public.studio_anamnese_sign(
  p_org_id uuid, p_anamnese_id uuid, p_answers jsonb, p_signature_name text, p_signature_data_url text,
  p_consent_accepted boolean, p_user_agent text, p_ip text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  perform public.studio_mode_assert_internal(p_org_id);
  if not exists (select 1 from public.studio_mode_pins p where p.org_id = p_org_id)
     or not public.anamnese_in_scope(p_org_id, p_anamnese_id) then
    return pg_catalog.jsonb_build_object('error', 'not_found');
  end if;
  return public.anamnese_sign_internal(p_anamnese_id, 'tablet', p_answers, p_signature_name, p_signature_data_url,
    p_consent_accepted, p_user_agent, p_ip);
end;
$$;
revoke all on function public.studio_anamnese_sign(uuid, uuid, jsonb, text, text, boolean, text, text) from public, anon;
grant execute on function public.studio_anamnese_sign(uuid, uuid, jsonb, text, text, boolean, text, text) to authenticated;

-- Entregar o aparelho: modo ligado, PIN definido (senão ninguém destrava) e, com ficha, só ficha pendente e no prazo;
-- registra o envio pelo modo estúdio. Antes: 3 idas (PIN, lista de fichas, registro).
create or replace function public.studio_mode_enter(p_org_id uuid, p_anamnese_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v record;
begin
  perform public.studio_mode_assert_internal(p_org_id);
  if not exists (select 1 from public.studio_mode_pins p where p.org_id = p_org_id) then
    raise exception 'O estúdio ainda não definiu o PIN. Peça à gestão em Ajustes › Ficha de saúde.' using errcode = 'P0001';
  end if;
  if p_anamnese_id is null then return; end if;
  if not public.anamnese_in_scope(p_org_id, p_anamnese_id) then
    raise exception 'Ficha não encontrada' using errcode = 'P0002';
  end if;
  select a.status, a.token_expires_at into v from public.anamneses a where a.org_id = p_org_id and a.id = p_anamnese_id;
  if v.status = 'signed' then
    raise exception 'Esta ficha já foi assinada.' using errcode = 'P0001';
  end if;
  if v.token_expires_at is null or v.token_expires_at < pg_catalog.now() then
    raise exception 'O link desta ficha venceu. Renove em Anamnese › Fichas.' using errcode = 'P0001';
  end if;
  perform public.log_anamnese_send(p_org_id, p_anamnese_id, 'studio');
end;
$$;
revoke all on function public.studio_mode_enter(uuid, uuid) from public, anon;
grant execute on function public.studio_mode_enter(uuid, uuid) to authenticated;

-- ─── Leituras da equipe sem o campo do link (revisão de 14/11) ──────────────────────────────────────
-- O banco guarda só o hash: public_token ficou sempre vazio. Sai do retorno das leituras (e token_hash nunca sai).
-- Corpo igual às versões vigentes (20261114020000, 20261114040100, 20261114040700), só sem o campo.
drop function if exists public.list_anamnese_status(uuid, uuid[], uuid, uuid, text, uuid[]);
CREATE OR REPLACE FUNCTION public.list_anamnese_status(p_org_id uuid, p_appointment_ids uuid[] DEFAULT NULL::uuid[], p_client_id uuid DEFAULT NULL::uuid, p_template_id uuid DEFAULT NULL::uuid, p_status text DEFAULT NULL::text, p_ids uuid[] DEFAULT NULL::uuid[])
 RETURNS TABLE(id uuid, org_id uuid, template_id uuid, template_title text, client_id uuid, client_name text, appointment_id uuid, status text, requires_professional boolean, professional_completed_at timestamp with time zone, source_service_id uuid, token_expires_at timestamp with time zone, consent_version text, consent_accepted boolean, signed_at timestamp with time zone, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'anamnese.view_status') then
    raise exception 'Sem permissão para consultar fichas de anamnese' using errcode = '42501';
  end if;
  return query
  select
    a.id, a.org_id, a.template_id, a.template_title, a.client_id, a.client_name,
    a.appointment_id, a.status, a.requires_professional, a.professional_completed_at, a.source_service_id,
    a.token_expires_at, a.consent_version, a.consent_accepted, a.signed_at, a.created_at, a.updated_at
  from public.anamneses a
  where a.org_id = p_org_id
    and (p_appointment_ids is null or a.appointment_id = any (p_appointment_ids))
    and (p_client_id is null or a.client_id = p_client_id)
    and (p_template_id is null or a.template_id = p_template_id)
    and (p_status is null or a.status = p_status)
    and (p_ids is null or a.id = any (p_ids))
    and public.anamnese_row_in_scope(a.org_id, a.appointment_id, a.created_by)
  order by a.created_at desc, a.id
  limit 1000;
end;
$function$;
revoke all on function public.list_anamnese_status(uuid, uuid[], uuid, uuid, text, uuid[]) from public, anon;
grant execute on function public.list_anamnese_status(uuid, uuid[], uuid, uuid, text, uuid[]) to authenticated, service_role;
CREATE OR REPLACE FUNCTION public.agenda_appointment_detail(p_org_id uuid, p_appointment_id uuid, p_more boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  v_row jsonb;
  v_client_id uuid;
  v_created_by uuid;
  v_fichas boolean := public.has_permission(p_org_id, 'anamnese.view_status');
  v_history jsonb;
  v_ficha_rows jsonb := '[]'::jsonb;
begin
  select pg_catalog.to_jsonb(a) || pg_catalog.jsonb_build_object(
      'appointment_items', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(i) order by i.created_at, i.id)
        from public.appointment_items i where i.appointment_id = a.id and i.org_id = a.org_id), '[]'::jsonb),
      'clients', (
        select pg_catalog.jsonb_build_object('id', c.id, 'full_name', c.full_name, 'alert_text', c.alert_text,
          'alert_type', c.alert_type, 'fixed_notes', c.fixed_notes, 'phone', c.phone)
          || case when p_more then pg_catalog.jsonb_build_object('balance', c.balance, 'total_spent', c.total_spent,
               'loyalty_points', c.loyalty_points, 'birth_date', c.birth_date) else '{}'::jsonb end
        from public.clients c where c.id = a.client_id and c.org_id = a.org_id)),
    a.client_id, a.created_by
  into v_row, v_client_id, v_created_by
  from public.appointments a
  where a.org_id = p_org_id and a.id = p_appointment_id;
  if v_row is null then
    return null;
  end if;

  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'status', h.status, 'created_at', h.created_at, 'changed_by', h.changed_by) order by h.created_at desc), '[]'::jsonb)
  into v_history
  from public.appointment_status_history h
  where h.org_id = p_org_id and h.appointment_id = p_appointment_id;

  if v_fichas then
    select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(s) order by s.created_at desc, s.id), '[]'::jsonb)
    into v_ficha_rows
    from public.list_anamnese_status(p_org_id, array[p_appointment_id], null, null, null) s;
  end if;

  return pg_catalog.jsonb_build_object(
    'appointment', v_row,
    'fichas', v_ficha_rows,
    'deposits', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', d.id, 'amount', d.amount, 'method', d.method, 'created_at', d.created_at) order by d.created_at)
      from public.appointment_deposits d
      where d.org_id = p_org_id and d.appointment_id = p_appointment_id and d.status = 'confirmed'), '[]'::jsonb),
    'history', v_history,
    'client_appointments', case when v_client_id is null then '[]'::jsonb else coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', x.id, 'start_at', x.start_at, 'status', x.status,
        'appointment_items', coalesce((
          select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('name', i.name) order by i.created_at, i.id)
          from public.appointment_items i where i.appointment_id = x.id and i.org_id = x.org_id), '[]'::jsonb))
        order by x.start_at desc)
      from (
        -- Os 200 mais recentes (o app reordena do mais antigo para o mais novo).
        select a.id, a.org_id, a.start_at, a.status from public.appointments a
        where a.org_id = p_org_id and a.client_id = v_client_id
        order by a.start_at desc
        limit 200
      ) x), '[]'::jsonb) end,
    'client_signed_at', case when v_fichas and v_client_id is not null then (
      select max(s.signed_at) from public.list_anamnese_status(p_org_id, null, v_client_id, null, 'signed') s) end,
    'sale', (
      select pg_catalog.jsonb_build_object(
        'id', s.id, 'number', s.number, 'status', s.status, 'total', s.total, 'paid_amount', s.paid_amount,
        'sale_payments', coalesce((
          select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('method', p.method, 'amount', p.amount) order by p.created_at, p.id)
          from public.sale_payments p where p.sale_id = s.id and p.org_id = s.org_id), '[]'::jsonb),
        'sale_items', coalesce((
          select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('item_type', si.item_type))
          from public.sale_items si where si.sale_id = s.id and si.org_id = s.org_id), '[]'::jsonb))
      from public.sales s
      where s.org_id = p_org_id and s.appointment_id = p_appointment_id and s.status <> 'cancelled'
      order by s.created_at desc
      limit 1),
    'ficha_events', case when v_fichas then coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(e) order by f.ord, e.created_at desc)
      from pg_catalog.jsonb_array_elements(v_ficha_rows) with ordinality as f(ficha, ord)
      cross join lateral public.list_anamnese_events(p_org_id, (f.ficha ->> 'id')::uuid, 20) e), '[]'::jsonb)
      else '[]'::jsonb end,
    'names', coalesce((
      select pg_catalog.jsonb_object_agg(p.user_id, p.full_name)
      from public.profiles p
      where p.org_id = p_org_id
        and p.user_id in (
          select v_created_by
          union
          select (h ->> 'changed_by')::uuid from pg_catalog.jsonb_array_elements(v_history) h)
        and nullif(pg_catalog.btrim(p.full_name), '') is not null), '{}'::jsonb)
  );
end;
$function$;
CREATE OR REPLACE FUNCTION public.agenda_appointment_fichas(p_org_id uuid, p_appointment_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
begin
  if not exists (select 1 from public.appointments a where a.org_id = p_org_id and a.id = p_appointment_id) then
    return pg_catalog.jsonb_build_object('fichas', '[]'::jsonb, 'templates', '[]'::jsonb);
  end if;
  return pg_catalog.jsonb_build_object(
    'fichas', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'id', s.id, 'template_title', s.template_title, 'status', s.status, 'signed_at', s.signed_at,
          'requires_professional', s.requires_professional, 'professional_completed_at', s.professional_completed_at, 'token_expires_at', s.token_expires_at)
        order by s.created_at desc, s.id)
      from public.list_anamnese_status(p_org_id, array[p_appointment_id], null, null, null) s), '[]'::jsonb),
    'templates', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', t.id, 'title', t.title) order by t.title, t.id)
      from public.anamnese_templates t where t.org_id = p_org_id and t.active), '[]'::jsonb)
  );
end;
$function$;
CREATE OR REPLACE FUNCTION public.anamnese_ficha_screen(p_org_id uuid, p_anamnese_id uuid, p_view text DEFAULT 'ficha'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := (select auth.uid());
  v_row public.anamneses;
  v_status jsonb;
  v_ficha jsonb;
begin
  if p_view is null or p_view not in ('ficha', 'janela') then
    raise exception 'Visão inválida' using errcode = '22023';
  end if;
  if v_uid is null or not (public.has_permission(p_org_id, 'anamnese.view_status') or public.has_permission(p_org_id, 'clientes.view_clinical')) then
    raise exception 'Sem permissão para consultar fichas de anamnese' using errcode = '42501';
  end if;

  if not public.has_permission(p_org_id, 'clientes.view_clinical') then
    select pg_catalog.to_jsonb(s) into v_status
    from public.list_anamnese_status(p_org_id, p_ids => array[p_anamnese_id]) s;
    return case when v_status is null then null else pg_catalog.jsonb_build_object('clinical', false, 'ficha', v_status) end;
  end if;

  select a.* into v_row
  from public.anamneses a
  where a.org_id = p_org_id and a.id = p_anamnese_id
    and public.anamnese_row_in_scope(a.org_id, a.appointment_id, a.created_by);
  if not found then
    return null;
  end if;

  -- Sem registro da leitura, a ficha não é entregue (a falha do INSERT desfaz tudo).
  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
  values (p_org_id, v_uid, 'anamneses', 'CLINICAL_READ', v_row.id, pg_catalog.jsonb_build_object('source', p_view));

  v_ficha := (pg_catalog.to_jsonb(v_row) - array['public_token', 'token_hash', 'created_by', 'signer_ip'])
    || pg_catalog.jsonb_build_object('signer_ip', public.anamnese_mask_ip_internal(v_row.signer_ip));
  if p_view = 'janela' then
    return pg_catalog.jsonb_build_object('clinical', true,
      'ficha', v_ficha - array['professional_notes', 'professional_data']
        || pg_catalog.jsonb_build_object('professional_notes', null, 'professional_data', null));
  end if;

  return pg_catalog.jsonb_build_object(
    'clinical', true,
    'ficha', v_ficha,
    'client', case when public.has_permission(p_org_id, 'clientes.view') then (
      select pg_catalog.jsonb_build_object('id', c.id, 'full_name', c.full_name, 'phone', c.phone, 'email', c.email,
        'birth_date', c.birth_date, 'alert_text', c.alert_text)
      from public.clients c where c.id = v_row.client_id and c.org_id = p_org_id) end,
    'appointment', (
      select pg_catalog.jsonb_build_object('start_at', ap.start_at, 'status', ap.status, 'service_label', (
        select pg_catalog.string_agg(i.name, ' · ' order by i.created_at, i.id)
        from public.appointment_items i
        where i.appointment_id = ap.id and i.org_id = p_org_id and pg_catalog.lower(i.type) = 'service'))
      from public.appointments ap
      where ap.id = v_row.appointment_id and ap.org_id = p_org_id and public.anamnese_row_in_scope(p_org_id, ap.id, null)),
    -- Últimos acessos: só para quem lê a auditoria (dona, administração, gestão; mesma regra de audit_select_manager)
    -- e só as operações que esta ficha gera (leitura clínica e Ficha Profissional), nunca outra coisa com o mesmo id.
    'accesses', case when public.auth_user_role(p_org_id) in ('owner', 'admin', 'manager') then coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'operation', l.operation, 'created_at', l.created_at,
          'user_name', (select p.full_name from public.profiles p where p.org_id = p_org_id and p.user_id = l.user_id limit 1))
        order by l.created_at desc, l.id)
      from (
        select al.id, al.operation, al.created_at, al.user_id from public.audit_logs al
        where al.org_id = p_org_id and al.table_name = 'anamneses' and al.record_id = v_row.id
          and al.operation in ('CLINICAL_READ', 'PROFESSIONAL_DRAFT_SAVED', 'PROFESSIONAL_COMPLETED',
                               'PROFESSIONAL_NOTES_UPDATED', 'PROFESSIONAL_REOPENED',
                               'PROFESSIONAL_PHOTO_ADDED', 'PROFESSIONAL_PHOTO_REMOVED', 'PROFESSIONAL_PHOTO_UPLOAD_AUTHORIZED')
        order by al.created_at desc, al.id
        limit 8
      ) l), '[]'::jsonb) else '[]'::jsonb end,
    'events', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'id', e.id, 'anamnese_id', e.anamnese_id, 'client_name', v_row.client_name, 'kind', e.kind, 'channel', e.channel,
          'user_name', (select p.full_name from public.profiles p where p.org_id = p_org_id and p.user_id = e.user_id limit 1),
          'meta', e.meta, 'created_at', e.created_at) order by e.created_at desc, e.id)
      from (
        select ev.* from public.anamnese_events ev
        where ev.org_id = p_org_id and ev.anamnese_id = v_row.id
        order by ev.created_at desc, ev.id
        limit 50
      ) e), '[]'::jsonb)
  );
end;
$function$;
CREATE OR REPLACE FUNCTION public.anamnese_items_internal(p_org_id uuid, p_ids uuid[])
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'id', a.id, 'status', a.status, 'token_expires_at', a.token_expires_at, 'signed_at', a.signed_at,
      'requires_professional', a.requires_professional, 'professional_completed_at', a.professional_completed_at,
      'created_at', a.created_at, 'client_id', a.client_id, 'client_name', a.client_name,
      'template_id', a.template_id, 'template_title', a.template_title, 'appointment_id', a.appointment_id,
      'client_phone', case when public.has_permission(p_org_id, 'clientes.view') then c.phone end,
      'client_alert', case when public.has_permission(p_org_id, 'clientes.view') then c.alert_text end,
      'appointment_at', ap.start_at,
      'service_label', case when ap.id is not null then (
        select pg_catalog.string_agg(i.name, ' · ' order by i.created_at, i.id)
        from public.appointment_items i
        where i.appointment_id = ap.id and i.org_id = p_org_id and pg_catalog.lower(i.type) = 'service') end)
    order by o.ord), '[]'::jsonb)
  from pg_catalog.unnest(p_ids) with ordinality o(id, ord)
  join public.anamneses a on a.id = o.id and a.org_id = p_org_id
  left join public.clients c on c.id = a.client_id and c.org_id = p_org_id
  -- Atendimento só se a pessoa o enxerga (agenda inteira ou dela).
  left join public.appointments ap on ap.id = a.appointment_id and ap.org_id = p_org_id
    and public.anamnese_row_in_scope(p_org_id, ap.id, null);
$function$;

-- ─── Auditoria da ficha (gatilho DEFINER) ────────────────────────────────────────────────────────
-- Recriada (20261114040400) com: assinatura (ANAMNESE_SIGNED: só o canal, nunca respostas, nome ou IP) e link novo
-- (ANAMNESE_LINK_REISSUED: sem token nem hash). O resto igual.
create or replace function public.anamneses_audit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if tg_op = 'DELETE' then
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data)
    values (old.org_id, v_uid, 'anamneses', 'ANAMNESE_PENDING_DELETED', old.id,
            pg_catalog.jsonb_build_object('status', old.status, 'client_id', old.client_id,
              'appointment_id', old.appointment_id, 'template_title', old.template_title));
    return null;
  end if;

  if old.status = 'pending' and new.status = 'signed' then
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
    values (new.org_id, v_uid, 'anamneses', 'ANAMNESE_SIGNED', new.id,
            pg_catalog.jsonb_build_object('channel', case when new.answers ->> '__canal' in ('link', 'tablet')
                                                          then new.answers ->> '__canal' end));
  end if;

  if old.token_hash is not null and new.token_hash is distinct from old.token_hash
     and old.created_at <> pg_catalog.now() then
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
    values (new.org_id, v_uid, 'anamneses', 'ANAMNESE_LINK_REISSUED', new.id,
            pg_catalog.jsonb_build_object('expires_at', new.token_expires_at));
  end if;

  if new.professional_completed_at is distinct from old.professional_completed_at then
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
    values (new.org_id, v_uid, 'anamneses',
            case when new.professional_completed_at is null then 'PROFESSIONAL_REOPENED' else 'PROFESSIONAL_COMPLETED' end,
            new.id,
            pg_catalog.jsonb_build_object('completed', old.professional_completed_at is not null),
            pg_catalog.jsonb_build_object('completed', new.professional_completed_at is not null,
              'has_data', coalesce(new.professional_data, '{}'::jsonb) <> '{}'::jsonb));
  elsif new.professional_data is distinct from old.professional_data then
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
    values (new.org_id, v_uid, 'anamneses', 'PROFESSIONAL_DRAFT_SAVED', new.id,
            pg_catalog.jsonb_build_object('has_data', coalesce(old.professional_data, '{}'::jsonb) <> '{}'::jsonb),
            pg_catalog.jsonb_build_object('has_data', coalesce(new.professional_data, '{}'::jsonb) <> '{}'::jsonb));
  end if;

  if new.professional_data -> 'photos' is distinct from old.professional_data -> 'photos'
     and pg_catalog.jsonb_typeof(new.professional_data -> 'photos') = 'array' then
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
    select new.org_id, v_uid, 'anamneses', 'PROFESSIONAL_PHOTO_ADDED', new.id, pg_catalog.jsonb_build_object('path', p)
    from pg_catalog.jsonb_array_elements_text(new.professional_data -> 'photos') p
    where not coalesce(old.professional_data -> 'photos', '[]'::jsonb) @> pg_catalog.jsonb_build_array(p);
  end if;

  if new.professional_notes is distinct from old.professional_notes then
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
    values (new.org_id, v_uid, 'anamneses', 'PROFESSIONAL_NOTES_UPDATED', new.id,
            pg_catalog.jsonb_build_object('has_note', new.professional_notes is not null,
              'length', pg_catalog.char_length(coalesce(new.professional_notes, ''))));
  end if;

  if new.token_expires_at is distinct from old.token_expires_at and new.status = 'pending'
     and old.created_at <> pg_catalog.now() then
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
    values (new.org_id, v_uid, 'anamneses', 'ANAMNESE_LINK_RENEWED', new.id,
            pg_catalog.jsonb_build_object('expires_at', old.token_expires_at),
            pg_catalog.jsonb_build_object('expires_at', new.token_expires_at));
  end if;
  return null;
end;
$$;
revoke all on function public.anamneses_audit() from public, anon, authenticated, service_role;

drop trigger if exists trg_anamneses_audit on public.anamneses;
create trigger trg_anamneses_audit
  after update of professional_completed_at, professional_data, professional_notes, token_expires_at, status, token_hash
     or delete
  on public.anamneses
  for each row execute function public.anamneses_audit();
