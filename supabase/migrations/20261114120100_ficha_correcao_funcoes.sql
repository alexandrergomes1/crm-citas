-- Corrigir ficha de anamnese assinada sem perder o original (spec docs/specs/ficha-correcao.md), parte 2: funções.
-- Encoding: UTF-8
set client_encoding = 'UTF8';
--
-- Ações (cada uma = acesso do pedido + UMA função; permissão, alcance, trava da linha e auditoria no banco):
--   anamnese_correction_request  "Reenviar para a cliente corrigir": ficha nova do mesmo modelo (o snapshot da
--                                assinada), cliente e atendimento, com as respostas que valem já preenchidas (sem o
--                                canal e sem os termos: a cliente aceita de novo). Pede ver o status E ler dado clínico
--                                (quem abre o link vê as respostas). Correção pendente que já existe volta a mesma (o
--                                app gera o link novo ao copiar). Só a parte da cliente: a Ficha Profissional continua
--                                na ficha original (a correção nasce sem parte profissional).
--   anamnese_correct_answers     "Corrigir respostas" pela profissional (preencher + ler dado clínico): motivo (até
--                                500), versão nova em anamnese_answer_versions; a assinada não muda. Só perguntas
--                                respondíveis da ficha; obrigatórias continuam respondidas.
-- Leituras: anamnese_ficha_screen devolve as respostas que valem, a original (se corrigida), o aviso da edição e as
-- ligações; list_anamnese_status ganha replaces_anamnese_id e superseded_by e, quando a pergunta é por atendimento
-- (Agenda, Comanda, Financeiro), não mostra a correção ainda pendente (a anterior continua valendo).
-- Trava do checkout: a ficha que vale por (atendimento, modelo) é a original até a correção ser assinada; depois, a
-- correção. A Ficha Profissional pendente continua travando (fica na original).
-- Recriadas com a correção: create_anamnese_atomic e ensure_appointment_anamnese_for_item (o único do atendimento
-- vale só para a original), anamneses_audit (ANAMNESE_SUPERSEDED na anterior quando a correção é assinada).

-- ─── Respostas que valem e o bloco "correção" da ficha aberta ───────────────────────────────────
-- Só para outras funções do banco (que já conferiram permissão e alcance).
create or replace function public.anamnese_current_answers_internal(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select v.answers from public.anamnese_answer_versions v
                   where v.anamnese_id = a.id and v.org_id = a.org_id
                   order by v.version desc limit 1), a.answers)
  from public.anamneses a where a.id = p_id;
$$;
revoke all on function public.anamnese_current_answers_internal(uuid) from public, anon, authenticated, service_role;

create or replace function public.anamnese_correction_payload_internal(p_row public.anamneses)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_edit public.anamnese_answer_versions;
  v_replaces jsonb;
  v_newer jsonb;
  v_pending jsonb;
begin
  select * into v_edit from public.anamnese_answer_versions v
  where v.anamnese_id = p_row.id and v.org_id = p_row.org_id order by v.version desc limit 1;
  if p_row.replaces_anamnese_id is not null then
    select pg_catalog.jsonb_build_object('id', o.id, 'signed_at', o.signed_at) into v_replaces
    from public.anamneses o where o.id = p_row.replaces_anamnese_id and o.org_id = p_row.org_id;
  end if;
  select pg_catalog.jsonb_build_object('id', n.id, 'signed_at', n.signed_at) into v_newer
  from public.anamneses n where n.replaces_anamnese_id = p_row.id and n.org_id = p_row.org_id and n.status = 'signed';
  select pg_catalog.jsonb_build_object('id', n.id, 'created_at', n.created_at) into v_pending
  from public.anamneses n where n.replaces_anamnese_id = p_row.id and n.org_id = p_row.org_id and n.status = 'pending';
  return pg_catalog.jsonb_build_object(
    'answers', coalesce(v_edit.answers, p_row.answers),
    'signed_answers', case when v_edit.id is not null then p_row.answers end,
    'correction', pg_catalog.jsonb_build_object(
      'replaces', v_replaces,
      'superseded_by', v_newer,
      'pending_correction', v_pending,
      'edit', case when v_edit.id is not null then pg_catalog.jsonb_build_object(
        'version', v_edit.version, 'edited_at', v_edit.created_at, 'reason', v_edit.reason,
        'changed', pg_catalog.to_jsonb(v_edit.changed_keys),
        'edited_by_name', (select p.full_name from public.profiles p
                           where p.org_id = p_row.org_id and p.user_id = v_edit.edited_by limit 1)) end));
end;
$$;
revoke all on function public.anamnese_correction_payload_internal(public.anamneses) from public, anon, authenticated, service_role;

-- ─── "Reenviar para a cliente corrigir" ─────────────────────────────────────────────────────────
create or replace function public.anamnese_correction_request(p_org_id uuid, p_anamnese_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_old public.anamneses;
  v_new_id uuid;
  v_answers jsonb;
  v_terms text[];
begin
  if v_uid is null or not public.has_permission(p_org_id, 'anamnese.view_status')
     or not public.has_permission(p_org_id, 'clientes.view_clinical') then
    raise exception 'Sem permissão para pedir a correção da ficha' using errcode = '42501';
  end if;
  if not public.anamnese_in_scope(p_org_id, p_anamnese_id) then
    raise exception 'Ficha não encontrada' using errcode = 'P0002';
  end if;
  select * into v_old from public.anamneses a where a.org_id = p_org_id and a.id = p_anamnese_id for update;
  if not found or v_old.status <> 'signed' then
    raise exception 'Só a ficha assinada pode ser reenviada para correção' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.anamneses n where n.org_id = p_org_id and n.replaces_anamnese_id = v_old.id and n.status = 'signed') then
    raise exception 'Esta ficha já foi substituída: corrija a mais nova' using errcode = 'P0001';
  end if;
  -- Já pedida e ainda pendente: a mesma (o link novo nasce ao copiar, enviar ou mostrar o QR).
  select n.id into v_new_id from public.anamneses n
  where n.org_id = p_org_id and n.replaces_anamnese_id = v_old.id and n.status = 'pending';
  if found then
    return pg_catalog.jsonb_build_object('id', v_new_id, 'created', false);
  end if;

  -- Respostas que valem, sem o canal e sem os termos (a cliente aceita de novo ao assinar).
  select coalesce(pg_catalog.array_agg(b ->> 'id'), '{}') into v_terms
  from pg_catalog.jsonb_array_elements(case when pg_catalog.jsonb_typeof(v_old.template_snapshot -> 'questions') = 'array'
                                            then v_old.template_snapshot -> 'questions' else '[]'::jsonb end) b
  where pg_catalog.jsonb_typeof(b) = 'object' and b ->> 'type' = 'consent' and b ->> 'id' is not null;
  v_answers := public.anamnese_current_answers_internal(v_old.id) - array['__canal', '__termo_principal'] - v_terms;

  -- O link criado aqui não sai (só o hash): o app gera um link novo quando a equipe copia ou envia.
  insert into public.anamneses (
    org_id, template_id, template_title, template_snapshot, client_id, client_name, appointment_id, status, answers,
    requires_professional, token_hash, token_expires_at, consent_text, consent_version, replaces_anamnese_id
  ) values (
    p_org_id, v_old.template_id, v_old.template_title, v_old.template_snapshot, v_old.client_id, v_old.client_name,
    v_old.appointment_id, 'pending', v_answers, false,
    public.public_token_hash_internal(public.public_token_new_internal()), pg_catalog.now() + interval '7 days',
    v_old.consent_text, v_old.consent_version, v_old.id
  )
  returning id into v_new_id;
  -- Mesmo modelo da assinada: o gatilho de criação põe a versão atual do modelo; volta a da ficha corrigida.
  update public.anamneses set template_snapshot = v_old.template_snapshot where id = v_new_id and org_id = p_org_id;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
  values (p_org_id, v_uid, 'anamneses', 'ANAMNESE_CREATED', v_new_id,
          pg_catalog.jsonb_build_object('appointment_id', v_old.appointment_id, 'template_id', v_old.template_id,
            'client_id', v_old.client_id, 'replaces', v_old.id));
  return pg_catalog.jsonb_build_object('id', v_new_id, 'created', true);
end;
$$;
revoke all on function public.anamnese_correction_request(uuid, uuid) from public, anon;
grant execute on function public.anamnese_correction_request(uuid, uuid) to authenticated;

-- ─── "Corrigir respostas" (profissional) ────────────────────────────────────────────────────────
-- p_answers: só as perguntas alteradas ({id: texto}); texto vazio apaga a resposta. Devolve a versão gravada.
create or replace function public.anamnese_correct_answers(p_org_id uuid, p_anamnese_id uuid, p_answers jsonb, p_reason text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_reason text := pg_catalog.btrim(coalesce(p_reason, ''));
  v_row public.anamneses;
  v_blocks jsonb;
  v_allowed text[];
  v_current jsonb;
  v_new jsonb;
  v_changed text[];
  v_version integer;
  e record;
  b jsonb;
begin
  if v_uid is null or not public.has_permission(p_org_id, 'anamnese.fill_professional')
     or not public.has_permission(p_org_id, 'clientes.view_clinical') then
    raise exception 'Sem permissão para corrigir respostas da ficha' using errcode = '42501';
  end if;
  if v_reason = '' then
    raise exception 'Escreva o motivo da correção' using errcode = '22023';
  end if;
  if pg_catalog.char_length(v_reason) > 500 then
    raise exception 'Motivo grande demais (até 500 caracteres)' using errcode = '22023';
  end if;
  if p_answers is null or pg_catalog.jsonb_typeof(p_answers) <> 'object'
     or (select pg_catalog.count(*) from pg_catalog.jsonb_object_keys(p_answers)) > 500
     or exists (select 1 from pg_catalog.jsonb_each(p_answers) x
                where pg_catalog.jsonb_typeof(x.value) <> 'string' or pg_catalog.char_length(x.key) > 120
                   or pg_catalog.char_length(x.value #>> '{}') > 5000) then
    raise exception 'Respostas inválidas' using errcode = '22023';
  end if;
  if not public.anamnese_in_scope(p_org_id, p_anamnese_id) then
    raise exception 'Ficha não encontrada' using errcode = 'P0002';
  end if;
  select * into v_row from public.anamneses a where a.org_id = p_org_id and a.id = p_anamnese_id for update;
  if not found then
    raise exception 'Ficha não encontrada' using errcode = 'P0002';
  end if;
  if v_row.status <> 'signed' then
    raise exception 'Ficha pendente: a cliente responde pelo link' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.anamneses n where n.org_id = p_org_id and n.replaces_anamnese_id = v_row.id) then
    raise exception 'Esta ficha tem uma correção enviada à cliente: corrija a mais nova ou revogue o link dela' using errcode = 'P0001';
  end if;

  v_blocks := case when pg_catalog.jsonb_typeof(v_row.template_snapshot -> 'questions') = 'array'
                   then v_row.template_snapshot -> 'questions' else '[]'::jsonb end;
  select coalesce(pg_catalog.array_agg(k), '{}') into v_allowed
  from pg_catalog.jsonb_array_elements(v_blocks) q
  cross join lateral (values (q ->> 'id'), ((q ->> 'id') || '__explain')) ks(k)
  where pg_catalog.jsonb_typeof(q) = 'object' and q ->> 'type' in ('yes_no', 'multiple_choice', 'text') and q ->> 'id' is not null;
  if exists (select 1 from pg_catalog.jsonb_object_keys(p_answers) k where k <> all (v_allowed)) then
    raise exception 'Pergunta que não está nesta ficha' using errcode = '22023';
  end if;

  v_current := public.anamnese_current_answers_internal(v_row.id);
  v_new := v_current;
  for e in select x.key, pg_catalog.btrim(x.value #>> '{}') as value from pg_catalog.jsonb_each(p_answers) x loop
    v_new := case when e.value = '' then v_new - e.key else v_new || pg_catalog.jsonb_build_object(e.key, e.value) end;
  end loop;
  select coalesce(pg_catalog.array_agg(k order by k), '{}') into v_changed
  from pg_catalog.jsonb_object_keys(p_answers) k
  where (v_current ->> k) is distinct from (v_new ->> k);
  if pg_catalog.cardinality(v_changed) = 0 then
    raise exception 'Nenhuma resposta mudou' using errcode = '22023';
  end if;

  -- Obrigatórias continuam respondidas (mesma regra da assinatura).
  for b in select value from pg_catalog.jsonb_array_elements(v_blocks) loop
    continue when pg_catalog.jsonb_typeof(b) <> 'object' or coalesce(b ->> 'type', '') not in ('yes_no', 'multiple_choice', 'text');
    if ((b -> 'required') = 'true'::jsonb and pg_catalog.btrim(coalesce(v_new ->> (b ->> 'id'), '')) = '')
       or (coalesce(b ->> 'explainWhenAnswer', '') <> '' and v_new ->> (b ->> 'id') = b ->> 'explainWhenAnswer'
           and pg_catalog.btrim(coalesce(v_new ->> ((b ->> 'id') || '__explain'), '')) = '') then
      raise exception 'Responda as perguntas obrigatórias' using errcode = '22023';
    end if;
  end loop;

  select coalesce(max(v.version), 0) + 1 into v_version from public.anamnese_answer_versions v
  where v.anamnese_id = v_row.id and v.org_id = p_org_id;
  insert into public.anamnese_answer_versions (org_id, anamnese_id, version, answers, changed_keys, reason, edited_by)
  values (p_org_id, v_row.id, v_version, v_new, v_changed, v_reason, v_uid);
  return pg_catalog.jsonb_build_object('version', v_version);
end;
$$;
revoke all on function public.anamnese_correct_answers(uuid, uuid, jsonb, text) from public, anon;
grant execute on function public.anamnese_correct_answers(uuid, uuid, jsonb, text) to authenticated;

-- ─── Status das fichas (Agenda, Comanda, Financeiro, perfil) ────────────────────────────────────
-- Recriada (20261114040500) com duas colunas novas no fim; muda o tipo de retorno, por isso drop + create.
-- Pergunta por atendimento: a correção pendente não aparece (a anterior continua valendo).
drop function if exists public.list_anamnese_status(uuid, uuid[], uuid, uuid, text, uuid[]);
create function public.list_anamnese_status(p_org_id uuid, p_appointment_ids uuid[] DEFAULT NULL::uuid[], p_client_id uuid DEFAULT NULL::uuid, p_template_id uuid DEFAULT NULL::uuid, p_status text DEFAULT NULL::text, p_ids uuid[] DEFAULT NULL::uuid[])
 RETURNS TABLE(id uuid, org_id uuid, template_id uuid, template_title text, client_id uuid, client_name text, appointment_id uuid, status text, requires_professional boolean, professional_completed_at timestamp with time zone, source_service_id uuid, token_expires_at timestamp with time zone, consent_version text, consent_accepted boolean, signed_at timestamp with time zone, created_at timestamp with time zone, updated_at timestamp with time zone, replaces_anamnese_id uuid, superseded_by uuid)
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
    a.token_expires_at, a.consent_version, a.consent_accepted, a.signed_at, a.created_at, a.updated_at,
    a.replaces_anamnese_id,
    (select n.id from public.anamneses n where n.replaces_anamnese_id = a.id and n.org_id = a.org_id and n.status = 'signed')
  from public.anamneses a
  where a.org_id = p_org_id
    and (p_appointment_ids is null or a.appointment_id = any (p_appointment_ids))
    and (p_client_id is null or a.client_id = p_client_id)
    and (p_template_id is null or a.template_id = p_template_id)
    and (p_status is null or a.status = p_status)
    and (p_ids is null or a.id = any (p_ids))
    and (p_appointment_ids is null or p_ids is not null or a.replaces_anamnese_id is null or a.status <> 'pending')
    and public.anamnese_row_in_scope(a.org_id, a.appointment_id, a.created_by)
  order by a.created_at desc, a.id
  limit 1000;
end;
$function$;
revoke all on function public.list_anamnese_status(uuid, uuid[], uuid, uuid, text, uuid[]) from public, anon;
grant execute on function public.list_anamnese_status(uuid, uuid[], uuid, uuid, text, uuid[]) to authenticated, service_role;

-- Lista da Anamnese e ficha aberta: as ligações (recriada de 20261114100100 com as duas chaves no fim).
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
        where i.appointment_id = ap.id and i.org_id = p_org_id and pg_catalog.lower(i.type) = 'service') end,
      'replaces_anamnese_id', a.replaces_anamnese_id,
      'superseded_by', (select n.id from public.anamneses n
                        where n.replaces_anamnese_id = a.id and n.org_id = p_org_id and n.status = 'signed'))
    order by o.ord), '[]'::jsonb)
  from pg_catalog.unnest(p_ids) with ordinality o(id, ord)
  join public.anamneses a on a.id = o.id and a.org_id = p_org_id
  left join public.clients c on c.id = a.client_id and c.org_id = p_org_id
  -- Atendimento só se a pessoa o enxerga (agenda inteira ou dela).
  left join public.appointments ap on ap.id = a.appointment_id and ap.org_id = p_org_id
    and public.anamnese_row_in_scope(p_org_id, ap.id, null);
$function$;

-- Seção Anamnese do perfil (recriada de 20261114040200): a substituída mostra a ligação para a nova.
create or replace function public.anamnese_client_fichas(p_org_id uuid, p_client_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_clinical boolean;
  v_rows jsonb;
begin
  if v_uid is null or not public.has_permission(p_org_id, 'clientes.view') then
    raise exception 'Sem permissão para ver clientes' using errcode = '42501';
  end if;
  if not public.has_permission(p_org_id, 'anamnese.view_status') then
    return '[]'::jsonb;
  end if;
  v_clinical := public.has_permission(p_org_id, 'clientes.view_clinical');
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'id', s.id, 'template_title', s.template_title, 'status', s.status, 'signed_at', s.signed_at,
      'created_at', s.created_at, 'requires_professional', s.requires_professional,
      'professional_completed_at', s.professional_completed_at,
      'replaces_anamnese_id', s.replaces_anamnese_id, 'superseded_by', s.superseded_by,
      'signature_name', case when v_clinical then a.signature_name end)
    order by s.created_at desc, s.id), '[]'::jsonb)
  into v_rows
  from (
    select * from public.list_anamnese_status(p_org_id, p_client_id => p_client_id) ls
    order by ls.created_at desc, ls.id
    limit 100
  ) s
  left join public.anamneses a on a.id = s.id and a.org_id = p_org_id;

  if v_clinical then
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
    select p_org_id, v_uid, 'anamneses', 'CLINICAL_READ', (f ->> 'id')::uuid,
           pg_catalog.jsonb_build_object('source', 'client_profile_fichas')
    from pg_catalog.jsonb_array_elements(v_rows) f
    where f ->> 'signature_name' is not null;
  end if;
  return v_rows;
end;
$$;

-- ─── Trava da Ficha (início e checkout) ─────────────────────────────────────────────────────────
-- Recriada (20261031400000 + 20261029240000): por (atendimento, modelo) vale UMA ficha — a original até a correção
-- ser assinada, depois a correção (nunca a correção pendente). A Ficha Profissional pendente de qualquer ficha do
-- atendimento/modelo continua travando o checkout (ela fica na original; a correção nasce sem parte profissional).
CREATE OR REPLACE FUNCTION public.get_appointment_anamnese_gate_raw(p_org_id uuid, p_appointment_id uuid, p_stage text)
 RETURNS TABLE(issue_code text, template_id uuid, template_title text, service_name text, anamnese_id uuid)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_role text;
begin
  v_role := public.auth_user_role(p_org_id);
  if v_role is null or not (public.has_permission(p_org_id, 'anamnese.view_status') or public.has_permission(p_org_id, 'comanda.operate')) then
    raise exception 'Sem permissao para consultar o gate clinico'
      using errcode = '42501';
  end if;

  if p_stage not in ('start', 'checkout') then
    raise exception 'Etapa do gate clinico invalida'
      using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.appointments a
    where a.id = p_appointment_id
      and a.org_id = p_org_id
  ) then
    raise exception 'Agendamento nao encontrado'
      using errcode = 'P0002';
  end if;

  return query
  with fichas as (
    -- Fichas do atendimento sem a correção ainda pendente; "vale" = não substituída por uma correção assinada.
    select an.*,
      not exists (select 1 from public.anamneses n
                  where n.org_id = p_org_id and n.replaces_anamnese_id = an.id and n.status = 'signed') as valid,
      p_stage = 'checkout' and an.requires_professional and an.professional_completed_at is null
        and not exists (select 1 from public.anamnese_gate_overrides o
                        where o.org_id = p_org_id and o.appointment_id = p_appointment_id and o.anamnese_id = an.id) as prof_pending
    from public.anamneses an
    where an.org_id = p_org_id
      and an.appointment_id = p_appointment_id
      and not (an.replaces_anamnese_id is not null and an.status = 'pending')
  ),
  required_items as (
    select
      ai.anamnese_template_id as required_template_id,
      pg_catalog.string_agg(
        distinct ai.name,
        ', ' order by ai.name
      ) as required_service_name
    from public.appointment_items ai
    where ai.org_id = p_org_id
      and ai.appointment_id = p_appointment_id
      and ai.requires_anamnese = true
    group by ai.anamnese_template_id
  ),
  required_issues as (
    select
      case
        when ri.required_template_id is null then 'MISSING_TEMPLATE_CONFIG'
        when an.id is null then 'MISSING_FORM'
        when an.status <> 'signed' then 'CLIENT_PENDING'
        when pp.id is not null then 'PROFESSIONAL_PENDING'
        else null
      end as code,
      ri.required_template_id,
      coalesce(an.template_title, t.title, 'Anamnese') as title,
      ri.required_service_name,
      coalesce(pp.id, an.id) as id
    from required_items ri
    left join public.anamnese_templates t
      on t.id = ri.required_template_id
      and t.org_id = p_org_id
    left join lateral (
      select f.* from fichas f where f.template_id = ri.required_template_id and f.valid
      order by f.created_at desc, f.id limit 1
    ) an on true
    left join lateral (
      select f.id from fichas f where f.template_id = ri.required_template_id and f.prof_pending
      order by f.created_at, f.id limit 1
    ) pp on true
  ),
  manual_issues as (
    select
      case
        when f.valid and f.status <> 'signed' then 'CLIENT_PENDING'
        when f.prof_pending then 'PROFESSIONAL_PENDING'
        else null
      end as code,
      f.template_id,
      f.template_title,
      null::text as required_service_name,
      f.id
    from fichas f
    where f.source_service_id is null
      and not exists (
        select 1
        from required_items ri
        where ri.required_template_id = f.template_id
      )
  )
  select
    issues.code,
    issues.required_template_id,
    issues.title,
    issues.required_service_name,
    issues.id
  from (
    select * from required_issues
    union all
    select * from manual_issues
  ) issues
  where issues.code is not null
  order by issues.required_service_name nulls last, issues.title;
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_anamnese_atomic(p_org_id uuid, p_template_id uuid, p_client_id uuid, p_client_name text, p_appointment_id uuid DEFAULT NULL::uuid, p_requires_professional boolean DEFAULT NULL::boolean)
 RETURNS anamneses
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_role text;
  v_clinical boolean;
  v_template public.anamnese_templates;
  v_appointment public.appointments;
  v_client public.clients;
  v_result public.anamneses;
  v_client_id uuid := p_client_id;
  v_client_name text := nullif(pg_catalog.btrim(p_client_name), '');
  v_token text;
begin
  v_role := public.auth_user_role(p_org_id);
  if v_role is null or not public.has_permission(p_org_id, 'anamnese.view_status') then
    raise exception 'Sem permissao para gerar fichas de anamnese'
      using errcode = '42501';
  end if;
  v_clinical := public.has_permission(p_org_id, 'clientes.view_clinical');

  select * into v_template
  from public.anamnese_templates t
  where t.id = p_template_id
    and t.org_id = p_org_id
    and t.active = true;

  if not found then
    raise exception 'Modelo de anamnese ativo nao encontrado'
      using errcode = 'P0002';
  end if;

  if p_appointment_id is not null then
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(
        p_org_id::text || ':' || p_appointment_id::text || ':' || p_template_id::text,
        0
      )
    );

    select * into v_appointment
    from public.appointments a
    where a.id = p_appointment_id
      and a.org_id = p_org_id
    for update;

    if not found or not public.anamnese_row_in_scope(p_org_id, p_appointment_id, null) then
      raise exception 'Agendamento não encontrado'
        using errcode = 'P0002';
    end if;

    v_client_id := v_appointment.client_id;
    v_client_name := v_appointment.client_name;

    select * into v_result
    from public.anamneses an
    where an.org_id = p_org_id
      and an.appointment_id = p_appointment_id
      and an.template_id = p_template_id
      and an.replaces_anamnese_id is null;

    if found then
      if not v_clinical then
        v_result.answers := '{}'::jsonb;
        v_result.professional_notes := null;
        v_result.professional_data := null;
        v_result.signature_name := null;
        v_result.signature_data_url := null;
        v_result.signer_ip := null;
        v_result.signer_user_agent := null;
      end if;
      v_result.token_hash := null;
      return v_result;
    end if;
  elsif v_client_id is not null then
    select * into v_client
    from public.clients c
    where c.id = v_client_id
      and c.org_id = p_org_id;

    if not found then
      raise exception 'Cliente nao encontrado nesta organizacao'
        using errcode = 'P0002';
    end if;
    v_client_name := v_client.full_name;
  end if;

  if v_client_name is null then
    raise exception 'Informe o cliente'
      using errcode = '22023';
  end if;

  v_token := public.public_token_new_internal();
  insert into public.anamneses (
    org_id, template_id, template_title, template_snapshot, client_id, client_name, appointment_id, status,
    requires_professional, source_service_id, token_hash, token_expires_at, consent_text, consent_version
  )
  values (
    p_org_id,
    v_template.id,
    v_template.title,
    pg_catalog.jsonb_build_object(
      'questions', v_template.questions,
      'consent_text', v_template.consent_text,
      'professional_form', v_template.professional_form
    ),
    v_client_id,
    v_client_name,
    p_appointment_id,
    'pending',
    coalesce(p_requires_professional, v_template.professional_form is not null),
    null,
    public.public_token_hash_internal(v_token),
    pg_catalog.now() + interval '7 days',
    v_template.consent_text,
    v_template.consent_version
  )
  returning * into v_result;

  if p_appointment_id is not null then
    update public.appointments
    set linked_anamnese_id = coalesce(linked_anamnese_id, v_result.id)
    where id = p_appointment_id
      and org_id = p_org_id;
  end if;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
  values (p_org_id, auth.uid(), 'anamneses', 'ANAMNESE_CREATED', v_result.id,
    pg_catalog.jsonb_build_object('appointment_id', p_appointment_id, 'template_id', p_template_id, 'client_id', v_client_id));

  if not v_clinical then
    v_result.answers := '{}'::jsonb;
    v_result.professional_notes := null;
    v_result.professional_data := null;
    v_result.signature_name := null;
    v_result.signature_data_url := null;
    v_result.signer_ip := null;
    v_result.signer_user_agent := null;
  end if;
  -- O token em claro sai só aqui, uma vez; a tabela guarda só o hash.
  v_result.token_hash := null;
  v_result.public_token := v_token;
  return v_result;
end;
$function$;

CREATE OR REPLACE FUNCTION public.ensure_appointment_anamnese_for_item()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_appointment public.appointments;
  v_template public.anamnese_templates;
  v_anamnese_id uuid;
begin
  if not new.requires_anamnese or new.anamnese_template_id is null then return new; end if;
  select * into v_appointment from public.appointments a
  where a.id = new.appointment_id and a.org_id = new.org_id;
  select * into v_template from public.anamnese_templates t
  where t.id = new.anamnese_template_id and t.org_id = new.org_id;
  if not found then
    raise exception 'Modelo de anamnese nao pertence a esta organizacao' using errcode = '23503';
  end if;
  insert into public.anamneses (
    org_id, template_id, template_title, template_snapshot, client_id,
    client_name, appointment_id, status, requires_professional,
    source_service_id, public_token, token_expires_at, consent_text, consent_version
  ) values (
    new.org_id, v_template.id, v_template.title,
    pg_catalog.jsonb_build_object(
      'questions', v_template.questions,
      'consent_text', v_template.consent_text,
      'professional_form', v_template.professional_form
    ),
    v_appointment.client_id, v_appointment.client_name, v_appointment.id,
    'pending', v_template.professional_form is not null, new.ref_id,
    pg_catalog.encode(extensions.gen_random_bytes(16), 'hex'),
    pg_catalog.now() + interval '7 days',
    v_template.consent_text, v_template.consent_version
  )
  on conflict (org_id, appointment_id, template_id)
    where appointment_id is not null and template_id is not null and replaces_anamnese_id is null
  do nothing returning id into v_anamnese_id;
  if v_anamnese_id is null then
    select an.id into v_anamnese_id from public.anamneses an
    where an.org_id = new.org_id
      and an.appointment_id = new.appointment_id
      and an.template_id = new.anamnese_template_id
      and an.replaces_anamnese_id is null;
  else
    insert into public.audit_logs (
      org_id, user_id, table_name, operation, record_id, new_data
    ) values (
      new.org_id, auth.uid(), 'anamneses', 'ANAMNESE_AUTO_LINKED', v_anamnese_id,
      pg_catalog.jsonb_build_object(
        'appointment_id', new.appointment_id,
        'template_id', new.anamnese_template_id,
        'service_id', new.ref_id
      )
    );
  end if;
  update public.appointments
  set linked_anamnese_id = coalesce(linked_anamnese_id, v_anamnese_id)
  where id = new.appointment_id and org_id = new.org_id;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.anamneses_audit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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

  -- Correção assinada: a ficha que ela corrige passa a "substituída" (a anterior não muda; o registro fica nela).
  if old.status = 'pending' and new.status = 'signed' and new.replaces_anamnese_id is not null then
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
    values (new.org_id, v_uid, 'anamneses', 'ANAMNESE_SUPERSEDED', new.replaces_anamnese_id,
            pg_catalog.jsonb_build_object('superseded_by', new.id));
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
    || pg_catalog.jsonb_build_object('signer_ip', public.anamnese_mask_ip_internal(v_row.signer_ip))
    -- Correção (20261114120100): respostas valendo (última versão corrigida ou a assinada), a original assinada só
    -- quando houve correção ("Ver original assinada") e as ligações com a ficha anterior e a nova.
    || public.anamnese_correction_payload_internal(v_row);
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
                               'PROFESSIONAL_PHOTO_ADDED', 'PROFESSIONAL_PHOTO_REMOVED', 'PROFESSIONAL_PHOTO_UPLOAD_AUTHORIZED',
                               'ANAMNESE_ANSWERS_CORRECTED')
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

-- ─── Situação "substituida" nos totais, no filtro e na visão geral da Anamnese ────────────────────
-- A substituída (correção assinada pela cliente) deixa de contar como concluída; a pendência profissional que fica
-- nela continua aparecendo como "profissional" (ela trava o checkout). A versão de 4 argumentos sai.
create or replace function public.anamnese_stage_internal(p_status text, p_requires boolean, p_completed timestamptz, p_expires timestamptz, p_superseded boolean)
returns text
language sql
stable
set search_path = ''
as $$
  select case
    when p_status = 'signed' then case when p_requires and p_completed is null then 'profissional'
                                       when p_superseded then 'substituida' else 'concluida' end
    when p_expires is not null and p_expires < pg_catalog.now() then 'expirado'
    else 'aguardando'
  end;
$$;
revoke all on function public.anamnese_stage_internal(text, boolean, timestamptz, timestamptz, boolean) from public, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.anamnese_counts_internal(p_org_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select pg_catalog.jsonb_build_object(
    'todas', pg_catalog.count(*),
    'aguardando', pg_catalog.count(*) filter (where s = 'aguardando'),
    'profissional', pg_catalog.count(*) filter (where s = 'profissional'),
    'concluida', pg_catalog.count(*) filter (where s = 'concluida'),
    'expirado', pg_catalog.count(*) filter (where s = 'expirado'),
    'substituida', pg_catalog.count(*) filter (where s = 'substituida'))
  from (
    select public.anamnese_stage_internal(a.status, a.requires_professional, a.professional_completed_at, a.token_expires_at,
             exists (select 1 from public.anamneses n where n.replaces_anamnese_id = a.id and n.org_id = a.org_id and n.status = 'signed')) s
    from public.anamneses a
    where a.org_id = p_org_id and public.anamnese_row_in_scope(a.org_id, a.appointment_id, a.created_by)
  ) x;
$function$;

CREATE OR REPLACE FUNCTION public.anamnese_fichas_page(p_org_id uuid, p_q text, p_stage text, p_template_id uuid, p_sort text, p_page integer, p_per_page integer, p_link uuid, p_send boolean, p_from timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_q text := nullif(pg_catalog.btrim(coalesce(p_q, '')), '');
  v_ids uuid[];
  v_total integer;
  v_blocking integer;
  v_urgent uuid;
  v_matrix jsonb;
  v_out jsonb;
begin
  perform public.anamnese_require_status_internal(p_org_id);
  if pg_catalog.char_length(coalesce(p_q, '')) > 100 or coalesce(p_stage, 'todas') not in ('todas', 'aguardando', 'profissional', 'concluida', 'expirado', 'substituida')
     or coalesce(p_sort, 'atendimento') not in ('atendimento', 'cliente', 'validade')
     or p_page is null or p_page < 1 or p_per_page is null or p_per_page not between 1 and (case when p_send then 100 else 2000 end) then
    raise exception 'Filtro inválido' using errcode = '22023';
  end if;

  with b as (
    select a.id, a.client_name, a.created_at, a.signed_at, a.token_expires_at, a.template_id,
           public.anamnese_stage_internal(a.status, a.requires_professional, a.professional_completed_at, a.token_expires_at,
             exists (select 1 from public.anamneses n where n.replaces_anamnese_id = a.id and n.org_id = a.org_id and n.status = 'signed')) s,
           ap.start_at appt
    from public.anamneses a
    left join public.appointments ap on ap.id = a.appointment_id and ap.org_id = a.org_id
      and public.anamnese_row_in_scope(a.org_id, ap.id, null)
    left join public.clients c on c.id = a.client_id and c.org_id = a.org_id
    where a.org_id = p_org_id
      and public.anamnese_row_in_scope(a.org_id, a.appointment_id, a.created_by)
      and (v_q is null or pg_catalog.concat_ws(' ', a.client_name, a.template_title,
            case when public.has_permission(p_org_id, 'clientes.view') then c.phone end,
            (select pg_catalog.string_agg(i.name, ' ') from public.appointment_items i
             where i.appointment_id = ap.id and i.org_id = a.org_id and pg_catalog.lower(i.type) = 'service'))
           operator(pg_catalog.~~*) ('%' || pg_catalog.replace(pg_catalog.replace(pg_catalog.replace(v_q, '\', '\\'), '%', '\%'), '_', '\_') || '%'))
  ), f as (
    select * from b where p_template_id is null or b.template_id = p_template_id
  ), g as (
    select * from f where coalesce(p_stage, 'todas') = 'todas' or s = p_stage
  ), o as (
    select id, pg_catalog.row_number() over (order by
      case when p_sort = 'cliente' then g.client_name end asc,
      case when p_sort = 'validade' then coalesce(g.signed_at + interval '12 months', g.token_expires_at) end asc nulls last,
      case when coalesce(p_sort, 'atendimento') = 'atendimento' then g.appt end desc nulls last,
      g.created_at desc, g.id) n
    from g
  )
  select (select pg_catalog.count(*) from g), (select pg_catalog.count(*) from g where s = 'profissional'),
         (select pg_catalog.array_agg(id order by n) from o where n > (p_page - 1) * p_per_page and n <= p_page * p_per_page),
         (select id from b where s = 'aguardando' and appt between pg_catalog.now() - interval '1 day' and pg_catalog.now() + interval '3 days'
          order by appt limit 1),
         -- Para o "Mostrar N fichas" da folha de filtros: com a busca atual, quantas por modelo e situação.
         (select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('template_id', m.template_id, 'stage', m.s, 'n', m.n)), '[]'::jsonb)
          from (select template_id, s, pg_catalog.count(*) n from b group by template_id, s) m)
  into v_total, v_blocking, v_ids, v_urgent, v_matrix;

  v_out := pg_catalog.jsonb_build_object(
    'rows', public.anamnese_items_internal(p_org_id, coalesce(v_ids, '{}'::uuid[])),
    'total', v_total,
    'blocking', v_blocking,
    'matrix', v_matrix,
    'counts', public.anamnese_counts_internal(p_org_id),
    'urgent', public.anamnese_items_internal(p_org_id, case when v_urgent is null then '{}'::uuid[] else array[v_urgent] end) -> 0,
    'link', case when p_link is not null and public.anamnese_in_scope(p_org_id, p_link)
                 then public.anamnese_items_internal(p_org_id, array[p_link]) -> 0 end);

  if p_send then
    v_out := v_out || pg_catalog.jsonb_build_object(
      'clients', case when public.has_permission(p_org_id, 'clientes.view') then coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', c.id, 'full_name', c.full_name, 'phone', c.phone,
          'last_visit', c.last_visit) order by c.full_name, c.id)
        from (select cl.id, cl.full_name, cl.phone, cl.last_visit from public.clients cl
              where cl.org_id = p_org_id order by cl.full_name, cl.id limit 200) c), '[]'::jsonb) else '[]'::jsonb end,
      'appointments', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', a.id, 'client_id', a.client_id, 'start_at', a.start_at,
          'status', a.status, 'items', coalesce((
            select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('name', i.name, 'templateId', i.anamnese_template_id) order by i.created_at, i.id)
            from public.appointment_items i
            where i.appointment_id = a.id and i.org_id = p_org_id and pg_catalog.lower(i.type) = 'service'), '[]'::jsonb))
          order by a.start_at, a.id)
        from (select ap.id, ap.client_id, ap.start_at, ap.status from public.appointments ap
              where ap.org_id = p_org_id and ap.start_at >= coalesce(p_from, pg_catalog.now() - interval '1 day')
                and public.anamnese_row_in_scope(p_org_id, ap.id, null)
              order by ap.start_at, ap.id limit 200) a), '[]'::jsonb),
      'templates', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', t.id, 'title', t.title, 'is_active', t.is_active,
          'professional_form', t.professional_form) order by t.title, t.id)
        from public.anamnese_templates t where t.org_id = p_org_id and t.active), '[]'::jsonb));
  end if;
  return v_out;
end;
$function$;

CREATE OR REPLACE FUNCTION public.anamnese_overview(p_org_id uuid, p_month_start timestamp with time zone, p_month_end timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_ids uuid[];
begin
  perform public.anamnese_require_status_internal(p_org_id);
  with f as (
    select a.id, a.appointment_id, a.created_at, a.signed_at, a.professional_completed_at, a.token_expires_at,
           public.anamnese_stage_internal(a.status, a.requires_professional, a.professional_completed_at, a.token_expires_at,
             exists (select 1 from public.anamneses n where n.replaces_anamnese_id = a.id and n.org_id = a.org_id and n.status = 'signed')) s,
           (select ap.start_at from public.appointments ap where ap.id = a.appointment_id and ap.org_id = a.org_id) appt
    from public.anamneses a
    where a.org_id = p_org_id and public.anamnese_row_in_scope(a.org_id, a.appointment_id, a.created_by)
  )
  select pg_catalog.array_agg(distinct id) into v_ids from (
    (select id from f where s = 'aguardando' and appt between pg_catalog.now() - interval '1 day' and pg_catalog.now() + interval '8 days' order by appt limit 10)
    union all (select id from f where s = 'profissional' order by signed_at limit 10)
    union all (select id from f where s = 'expirado' order by token_expires_at desc limit 10)
    union all (select id from f order by greatest(created_at, signed_at, professional_completed_at) desc limit 10)
  ) x;

  return pg_catalog.jsonb_build_object(
    'counts', public.anamnese_counts_internal(p_org_id),
    'month', (
      select pg_catalog.jsonb_build_object(
        'total', pg_catalog.count(*),
        'aguardando', pg_catalog.count(*) filter (where s = 'aguardando'),
        'profissional', pg_catalog.count(*) filter (where s = 'profissional'),
        'concluida', pg_catalog.count(*) filter (where s = 'concluida'))
      from (
        select public.anamnese_stage_internal(a.status, a.requires_professional, a.professional_completed_at, a.token_expires_at,
             exists (select 1 from public.anamneses n where n.replaces_anamnese_id = a.id and n.org_id = a.org_id and n.status = 'signed')) s,
               coalesce((select ap.start_at from public.appointments ap where ap.id = a.appointment_id and ap.org_id = a.org_id), a.created_at) d
        from public.anamneses a
        where a.org_id = p_org_id and public.anamnese_row_in_scope(a.org_id, a.appointment_id, a.created_by)
      ) m where d >= p_month_start and d < p_month_end),
    -- Concluídas cuja validade (12 meses depois da assinatura) termina nos próximos 30 dias; a mais próxima.
    'expiring', (
      select pg_catalog.jsonb_build_object('count', pg_catalog.count(*),
        'first', (pg_catalog.array_agg(pg_catalog.jsonb_build_object('client_name', e.client_name, 'until', e.until) order by e.until))[1])
      from (
        select a.client_name, a.signed_at + interval '12 months' until
        from public.anamneses a
        where a.org_id = p_org_id and a.status = 'signed'
          and (not a.requires_professional or a.professional_completed_at is not null)
          and a.signed_at + interval '12 months' between pg_catalog.now() - interval '1 day' and pg_catalog.now() + interval '31 days'
          and not exists (select 1 from public.anamneses n where n.replaces_anamnese_id = a.id and n.org_id = a.org_id and n.status = 'signed')
          and public.anamnese_row_in_scope(a.org_id, a.appointment_id, a.created_by)
      ) e),
    'rows', public.anamnese_items_internal(p_org_id, coalesce(v_ids, '{}'::uuid[])),
    'events', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'id', e.id, 'anamnese_id', e.anamnese_id, 'client_name', e.client_name, 'kind', e.kind, 'channel', e.channel,
          'user_name', e.user_name, 'meta', e.meta, 'created_at', e.created_at) order by e.created_at desc, e.id)
      from (
        select ev.id, ev.anamnese_id, a.client_name, ev.kind, ev.channel, ev.meta, ev.created_at,
               (select p.full_name from public.profiles p where p.org_id = ev.org_id and p.user_id = ev.user_id limit 1) user_name
        from public.anamnese_events ev
        join public.anamneses a on a.id = ev.anamnese_id and a.org_id = ev.org_id
        where ev.org_id = p_org_id and public.anamnese_row_in_scope(a.org_id, a.appointment_id, a.created_by)
        order by ev.created_at desc, ev.id
        limit 20
      ) e), '[]'::jsonb)
  );
end;
$function$;

drop function if exists public.anamnese_stage_internal(text, boolean, timestamptz, timestamptz);

-- ─── Agenda e Comanda: a original substituída aparece como "Substituída" ────────────────────────
-- Recriadas (20261114100100 e 20261114050000) só com superseded_by nas fichas do atendimento.
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
          'requires_professional', s.requires_professional, 'professional_completed_at', s.professional_completed_at, 'token_expires_at', s.token_expires_at,
          'superseded_by', s.superseded_by)
        order by s.created_at desc, s.id)
      from public.list_anamnese_status(p_org_id, array[p_appointment_id], null, null, null) s), '[]'::jsonb),
    'templates', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', t.id, 'title', t.title) order by t.title, t.id)
      from public.anamnese_templates t where t.org_id = p_org_id and t.active), '[]'::jsonb)
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.checkout_screen(p_org_id uuid, p_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  v_tz text;
  v_today date;
  v_sale public.sales;
  v_appt public.appointments;
  v_appt_id uuid;
  v_client_id uuid;
  v_redirect uuid;
  v_open boolean;
  v_gate jsonb := '[]'::jsonb;
  v_fichas jsonb := '[]'::jsonb;
begin
  perform public.finance_org_timezone(p_org_id);
  if not (public.has_permission(p_org_id, 'comanda.operate') or public.has_permission(p_org_id, 'financeiro.view')) then
    raise exception 'Sem permissão para ver o checkout' using errcode = '42501';
  end if;
  if p_id is null then
    return pg_catalog.jsonb_build_object('not_found', true);
  end if;
  v_tz := public.finance_org_timezone(p_org_id);
  v_today := (pg_catalog.now() at time zone v_tz)::date;

  select * into v_sale from public.sales s where s.id = p_id and s.org_id = p_org_id;
  if v_sale.id is null then
    -- Depois de um estorno o atendimento pode ganhar uma comanda nova: a cancelada fica só no histórico.
    select s.id into v_redirect from public.sales s
    where s.org_id = p_org_id and s.appointment_id = p_id and s.status <> 'cancelled'
    order by s.created_at desc, s.id limit 1;
    if v_redirect is not null then
      return pg_catalog.jsonb_build_object('redirect', v_redirect);
    end if;
    v_appt_id := p_id;
  else
    v_appt_id := v_sale.appointment_id;
  end if;

  if v_appt_id is not null then
    select * into v_appt from public.appointments a where a.id = v_appt_id and a.org_id = p_org_id;
  end if;
  if v_sale.id is null and v_appt.id is null then
    return pg_catalog.jsonb_build_object('not_found', true);
  end if;

  v_client_id := coalesce(v_appt.client_id, v_sale.client_id);
  v_open := v_sale.id is null or v_sale.status in ('draft', 'partial');

  if v_appt.id is not null and public.has_permission(p_org_id, 'anamnese.view_status') then
    select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
             'id', f.id, 'template_title', f.template_title, 'status', f.status, 'signed_at', f.signed_at,
             'requires_professional', f.requires_professional, 'professional_completed_at', f.professional_completed_at,
             'superseded_by', f.superseded_by)
             order by f.created_at desc, f.id), '[]'::jsonb)
    into v_fichas
    from public.list_anamnese_status(p_org_id, array[v_appt.id]) f;
  end if;

  -- Trava da Ficha só para quem cobra (o gate exige comanda.operate ou anamnese.view_status); quem só vê o
  -- financeiro abre a comanda em leitura sem a trava.
  if v_open and v_appt.id is not null
     and (public.has_permission(p_org_id, 'comanda.operate') or public.has_permission(p_org_id, 'anamnese.view_status')) then
    select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(g)), '[]'::jsonb) into v_gate
    from public.get_appointment_anamnese_gate(p_org_id, v_appt.id, 'checkout') g;
  end if;

  return pg_catalog.jsonb_build_object(
    'today', v_today,
    'timezone', v_tz,
    'sale', case when v_sale.id is null then null else pg_catalog.jsonb_build_object(
      'id', v_sale.id, 'number', v_sale.number, 'appointment_id', v_sale.appointment_id, 'client_id', v_sale.client_id,
      'client_name', v_sale.client_name, 'staff_id', v_sale.staff_id, 'status', v_sale.status,
      'subtotal', v_sale.subtotal, 'discount', v_sale.discount, 'tip', v_sale.tip, 'total', v_sale.total,
      'paid_amount', v_sale.paid_amount, 'balance', v_sale.balance, 'notes', v_sale.notes,
      'created_at', v_sale.created_at, 'updated_at', v_sale.updated_at, 'refunded_at', v_sale.refunded_at,
      'refund_reason', v_sale.refund_reason,
      'items', coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
                  'id', i.id, 'item_type', i.item_type, 'item_id', i.item_id, 'name', i.name, 'category', i.category,
                  'unit_price', i.unit_price, 'quantity', i.quantity, 'total_price', i.total_price,
                  'entitlement_id', i.entitlement_id, 'covered_by_entitlement', i.covered_by_entitlement)
                  order by i.created_at, i.id)
                from public.sale_items i where i.sale_id = v_sale.id and i.org_id = p_org_id), '[]'::jsonb),
      'payments', coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
                  'method', pay.method, 'amount', pay.amount, 'gift_card_code', pay.gift_card_code,
                  'reference', pay.reference, 'created_at', pay.created_at) order by pay.created_at, pay.id)
                from public.sale_payments pay where pay.sale_id = v_sale.id and pay.org_id = p_org_id), '[]'::jsonb)
    ) end,
    'appointment', case when v_appt.id is null then null else pg_catalog.jsonb_build_object(
      'id', v_appt.id, 'number', v_appt.number, 'client_id', v_appt.client_id, 'client_name', v_appt.client_name,
      'staff_id', v_appt.staff_id, 'start_at', v_appt.start_at, 'internal_notes', v_appt.internal_notes,
      'items', coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
                  'id', i.id, 'type', i.type, 'ref_id', i.ref_id, 'name', i.name, 'price', i.price, 'qty', i.qty,
                  'duration_minutes', i.duration_minutes, 'professional_id', i.professional_id,
                  'requires_anamnese', i.requires_anamnese) order by i.created_at, i.id)
                from public.appointment_items i where i.appointment_id = v_appt.id and i.org_id = p_org_id), '[]'::jsonb),
      'fichas', v_fichas
    ) end,
    'catalog', public.checkout_catalog(p_org_id),
    'staff', coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
               'id', m.id, 'name', m.name, 'display_name', m.display_name, 'commission_pct', m.commission_pct)
               order by m.position, m.name, m.id)
             from (select x.* from public.staff_members x where x.org_id = p_org_id order by x.position, x.name, x.id limit 500) m), '[]'::jsonb),
    'deposits', case when v_appt.id is null then '[]'::jsonb else coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id', d.id, 'amount', d.amount, 'method', d.method, 'created_at', d.created_at)
               order by d.created_at, d.id)
      from public.appointment_deposits d
      where d.org_id = p_org_id and d.appointment_id = v_appt.id and d.status = 'confirmed'), '[]'::jsonb) end,
    'entitlements', case when v_client_id is null then '[]'::jsonb else coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
               'id', e.id, 'package_name', e.package_name, 'total_sessions', e.total_sessions,
               'used_sessions', e.used_sessions, 'covered_services', e.covered_services, 'expires_at', e.expires_at)
               order by e.purchased_at desc, e.id)
      from (select x.* from public.client_entitlements x
            where x.org_id = p_org_id and x.client_id = v_client_id and x.status = 'active'
            order by x.purchased_at desc, x.id limit 200) e), '[]'::jsonb) end,
    'client', case when v_client_id is null then null else (
      select pg_catalog.jsonb_build_object(
               'full_name', c.full_name, 'phone', c.phone, 'email', c.email, 'tags', c.tags, 'balance', c.balance,
               'fixed_notes', c.fixed_notes, 'alert_text', c.alert_text)
      from public.clients c where c.id = v_client_id and c.org_id = p_org_id) end,
    'visits', case when v_client_id is null then 0 else (
      select pg_catalog.count(*) from public.sales s where s.org_id = p_org_id and s.client_id = v_client_id and s.status = 'paid') end,
    'gate', v_gate,
    'refund', case when v_sale.status = 'cancelled' then (
      select pg_catalog.jsonb_build_object('amount', r.amount, 'destination', r.destination, 'details', r.details)
      from public.sale_refunds r where r.org_id = p_org_id and r.sale_id = v_sale.id
      order by r.created_at desc, r.id limit 1) end,
    'partial_refunded', case when v_sale.status in ('paid', 'partial') then (
      select coalesce(pg_catalog.round(sum(r.amount), 2), 0) from public.sale_partial_refunds r
      where r.org_id = p_org_id and r.sale_id = v_sale.id) else 0 end,
    -- Retoques incluídos: regras do catálogo e os 200 atendimentos concluídos mais recentes da cliente
    -- (a conta da janela é feita em src/domain/service-rules.ts, no fuso do estúdio).
    'retouch_rules', case when v_open and v_client_id is not null then coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('service_id', s.id, 'name', s.name, 'days', s.retouch_included_days)
               order by s.name, s.id)
      from public.services s where s.org_id = p_org_id and s.retouch_included_days is not null), '[]'::jsonb)
      else '[]'::jsonb end,
    'retouch_history', case when v_open and v_client_id is not null then coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
               'status', a.status, 'start_at', a.start_at,
               'service_ids', coalesce((select pg_catalog.jsonb_agg(i.ref_id order by i.created_at, i.id)
                                        from public.appointment_items i
                                        where i.appointment_id = a.id and i.org_id = a.org_id and i.ref_id is not null), '[]'::jsonb))
               order by a.start_at desc)
      from (select x.* from public.appointments x
            where x.org_id = p_org_id and x.client_id = v_client_id
              and x.status in ('Concluído', 'Concluido', 'Pago Parcial', 'Pago')
              and x.id is distinct from v_appt.id
            order by x.start_at desc limit 200) a), '[]'::jsonb)
      else '[]'::jsonb end
  );
end;
$function$;
