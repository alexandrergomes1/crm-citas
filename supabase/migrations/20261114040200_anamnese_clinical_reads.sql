-- Anamnese (porte): leituras clínicas. Cada uma confere sessão + permissão no estúdio + alcance e grava
-- CLINICAL_READ dentro dela antes de devolver (regra de auditoria de 14/11). SECURITY DEFINER por isso.
-- Encoding: UTF-8
set client_encoding = 'UTF8';

-- IP da assinatura mascarado já no banco (igual a maskIp do app): só os dois primeiros blocos.
create or replace function public.anamnese_mask_ip_internal(p_ip text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_ip is null then null
    when p_ip ~ '^[0-9]{1,3}\.[0-9]{1,3}\.' then pg_catalog.regexp_replace(p_ip, '^([0-9]{1,3})\.([0-9]{1,3})\..*$', '\1.\2.•••.•••')
    else pg_catalog.array_to_string((pg_catalog.string_to_array(p_ip, ':'))[1:2], ':') || ':••••'
  end;
$$;
revoke all on function public.anamnese_mask_ip_internal(text) from public, anon, authenticated;

-- ─── Ficha aberta ───────────────────────────────────────────────────────────────────────────────
-- p_view 'ficha': a tela da ficha (cliente + profissional, cadastro, atendimento, acessos, andamento).
-- p_view 'janela': a ficha por cima do perfil da cliente; só o que ela mostra (sem nota, dados da profissional,
-- cadastro, acessos e andamento).
-- Sem leitura clínica (e com anamnese.view_status): só o status. Fora do alcance, outro estúdio ou inexistente: nulo.
create or replace function public.anamnese_ficha_screen(p_org_id uuid, p_anamnese_id uuid, p_view text default 'ficha')
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
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

  v_ficha := (pg_catalog.to_jsonb(v_row) - array['public_token', 'created_by', 'signer_ip'])
    || pg_catalog.jsonb_build_object(
      'public_token', case when v_row.status = 'pending' and v_row.token_expires_at >= pg_catalog.now() then v_row.public_token end,
      'signer_ip', public.anamnese_mask_ip_internal(v_row.signer_ip));
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
                               'PROFESSIONAL_PHOTO_ADDED', 'PROFESSIONAL_PHOTO_REMOVED')
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
$$;
revoke all on function public.anamnese_ficha_screen(uuid, uuid, text) from public, anon;
grant execute on function public.anamnese_ficha_screen(uuid, uuid, text) to authenticated;

-- ─── Fotos de uma ficha (endereços renovados sob demanda) ───────────────────────────────────────
-- Caminhos das fotos da Ficha Profissional (só os do formato <estúdio>/<ficha>/<arquivo>), com CLINICAL_READ.
create or replace function public.anamnese_ficha_photos(p_org_id uuid, p_anamnese_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_paths jsonb;
begin
  if v_uid is null or not public.has_permission(p_org_id, 'clientes.view_clinical') then
    raise exception 'Sem acesso a dados clínicos' using errcode = '42501';
  end if;
  select coalesce(pg_catalog.jsonb_agg(p), '[]'::jsonb) into v_paths
  from public.anamneses a
  cross join lateral pg_catalog.jsonb_array_elements_text(
    case when pg_catalog.jsonb_typeof(a.professional_data -> 'photos') = 'array' then a.professional_data -> 'photos' else '[]'::jsonb end) p
  where a.org_id = p_org_id and a.id = p_anamnese_id
    and public.anamnese_row_in_scope(a.org_id, a.appointment_id, a.created_by)
    and p like p_org_id::text || '/' || p_anamnese_id::text || '/%';
  if pg_catalog.jsonb_array_length(v_paths) > 0 then
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
    values (p_org_id, v_uid, 'anamneses', 'CLINICAL_READ', p_anamnese_id, pg_catalog.jsonb_build_object('source', 'ficha_photos'));
  end if;
  return v_paths;
end;
$$;
revoke all on function public.anamnese_ficha_photos(uuid, uuid) from public, anon;
grant execute on function public.anamnese_ficha_photos(uuid, uuid) to authenticated;

-- ─── Perfil da cliente ──────────────────────────────────────────────────────────────────────────
-- Fotos de antes e depois (por ficha), pedidas ao abrir a seção Fotos (não a cada abertura do perfil).
-- Um CLINICAL_READ por ficha cujas fotos saem. Sem leitura clínica: lista vazia, nada gravado. Só caminhos da
-- própria ficha (<estúdio>/<ficha>/...): o servidor assina com a chave de serviço o que sair daqui.
create or replace function public.anamnese_client_photos(p_org_id uuid, p_client_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_photos jsonb;
begin
  if v_uid is null or not public.has_permission(p_org_id, 'clientes.view_clinical') then
    return '[]'::jsonb;
  end if;
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'id', x.id, 'template_title', x.template_title, 'created_at', x.created_at, 'signed_at', x.signed_at,
      'professional_data', pg_catalog.jsonb_build_object('photos', x.photos)) order by x.created_at desc), '[]'::jsonb)
  into v_photos
  from (
    select a.id, a.template_title, a.created_at, a.signed_at, (
        select pg_catalog.jsonb_agg(p)
        from pg_catalog.jsonb_array_elements_text(
          case when pg_catalog.jsonb_typeof(a.professional_data -> 'photos') = 'array' then a.professional_data -> 'photos' else '[]'::jsonb end) p
        where p like a.org_id::text || '/' || a.id::text || '/%') as photos
    from public.anamneses a
    where a.org_id = p_org_id and a.client_id = p_client_id
      and public.anamnese_row_in_scope(a.org_id, a.appointment_id, a.created_by)
    order by a.created_at desc
    limit 100
  ) x
  where pg_catalog.jsonb_typeof(x.photos) = 'array' and pg_catalog.jsonb_array_length(x.photos) > 0;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
  select p_org_id, v_uid, 'anamneses', 'CLINICAL_READ', (f ->> 'id')::uuid, pg_catalog.jsonb_build_object('source', 'client_profile_photos')
  from pg_catalog.jsonb_array_elements(v_photos) f;
  return v_photos;
end;
$$;
revoke all on function public.anamnese_client_photos(uuid, uuid) from public, anon;
grant execute on function public.anamnese_client_photos(uuid, uuid) to authenticated;

-- Seção Anamnese do perfil. Antes o app lia a tabela inteira (respostas, assinatura, IP) só para listar.
-- Agora: status (list_anamnese_status, com alcance) e, para quem tem leitura clínica, o nome escrito na
-- assinatura, com um CLINICAL_READ por ficha cujo nome sai. DEFINER: a tabela é fechada para a API.
create or replace function public.anamnese_client_fichas(p_org_id uuid, p_client_id uuid)
returns jsonb
language plpgsql
volatile
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
revoke all on function public.anamnese_client_fichas(uuid, uuid) from public, anon;
grant execute on function public.anamnese_client_fichas(uuid, uuid) to authenticated;
