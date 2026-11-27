-- Mensagens e Marketing: ações em UMA ida ao banco cada, tudo-ou-nada (porte para o TanStack Start, orçamento de chamadas).
-- Antes (beauty-system): salvar modelo existente = ler + gravar; duplicar = ler + ler + gravar; criar campanha = prévia
-- (clientes, preferências, serviços) + gravar; preparar fila = campanha + modelo + prévia + gravar (4 a 7 idas); gravar a
-- conexão e o registro de teste eram INSERT/UPSERT soltos. Agora cada ação é UMA função.
-- Todas SECURITY INVOKER: a RLS continua valendo por baixo e cada função confere a liberação (has_permission) ANTES de
-- gravar, com mensagem em português; a linha mexida é travada (for update) da leitura até a gravação.
-- Limites no banco: nome do modelo e da campanha até 120, assunto 160, texto 2000, descrição da campanha 500.
-- Consentimento: a fila de envio NUNCA inclui quem pediu para não receber nem quem tem marketing_allowed = false no
-- canal (marketing_audience com p_enforce_consent), mesmo na campanha de "Auditoria de consentimento".
-- Políticas: gravar modelos, campanhas, fila e eventos passa a seguir a liberação mensagens.configure (antes: papéis
-- fixos dona, administração e gestão; o padrão por papel é o mesmo, mas agora os perfis configuráveis também valem).
-- O registro de envios (messaging_provider_log) só aceita linha de TESTE de quem configura, com o próprio usuário como
-- autor, com situação "enviado" ou "falhou". Isso NÃO prova envio: é só a linha de um teste (finalidade "teste", nunca
-- campanha nem cliente). A confirmação de entrega (entregue, lida) só vem do aviso assinado da Meta (servidor).
-- Auditoria (audit_logs): por GATILHO, não por função chamável. A política audit_insert_member NÃO é recriada nem
-- ganha pares. Conexão e desconexão de canal, campanha (criada, mudada, arquivada, apagada) e preparo da fila de
-- envio. Funções SECURITY DEFINER com search_path vazio, execução revogada de todos, usuário = auth.uid() e guarda de
-- cascata (apagar o estúdio inteiro não grava auditoria).
-- Automações: o sistema antigo não guarda estado de automação (todas aparecem desligadas, sem tabela); não há o que
-- auditar até o motor de envio existir.
-- Guardas no banco (gatilhos BEFORE na fila, nos eventos e nas campanhas): a fila recusa cliente que recusou o MEIO
-- (recusa em qualquer canal de WhatsApp vale para os dois), mesclada, bloqueada ou de outro estúdio; campanha, modelo e
-- cliente de uma linha têm de ser do mesmo estúdio dela. Valem para qualquer caminho de gravação (função ou tabela).
-- Leitura da fila, dos eventos, do registro de envios, das campanhas e dos modelos exige mensagens.use ou
-- mensagens.configure, avaliada uma vez por consulta (auth_orgs_with_permission, padrão do Financeiro).
-- Teste de envio: no máximo 5 por hora por estúdio e 3 por hora por pessoa, contados ANTES de chamar o provedor.
-- Não mexe em função nem em tabela do sistema antigo além das políticas e dos limites acima.
-- Encoding: UTF-8
set client_encoding = 'UTF8';

-- ─── Modelo de mensagem ────────────────────────────────────────────────────────────────────────────
create or replace function public.messaging_save_template(
  p_org_id uuid,
  p_template_id uuid,
  p_name text,
  p_channel text,
  p_purpose text,
  p_language text,
  p_subject text,
  p_body text
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_name text := pg_catalog.btrim(coalesce(p_name, ''));
  v_subject text := nullif(pg_catalog.btrim(coalesce(p_subject, '')), '');
  v_body text := pg_catalog.btrim(coalesce(p_body, ''));
  v_id uuid;
begin
  if not public.has_permission(p_org_id, 'mensagens.configure') then
    raise exception 'Sem permissão para editar modelos.' using errcode = '42501';
  end if;
  if v_name = '' or pg_catalog.char_length(v_name) > 120 then
    raise exception 'O nome do modelo vai de 1 a 120 caracteres.' using errcode = '22023';
  end if;
  if v_body = '' or pg_catalog.char_length(v_body) > 2000 then
    raise exception 'O texto do modelo vai de 1 a 2000 caracteres.' using errcode = '22023';
  end if;
  if pg_catalog.char_length(coalesce(v_subject, '')) > 160 then
    raise exception 'O assunto passa de 160 caracteres.' using errcode = '22023';
  end if;
  if p_channel is null or p_channel not in ('whatsapp_manual', 'whatsapp_provider', 'sms_provider', 'email_provider', 'internal_note') then
    raise exception 'Canal inválido.' using errcode = '22023';
  end if;
  if p_purpose is null or p_purpose not in ('birthday', 'inactive_recovery', 'aftercare', 'review_request', 'promotion', 'announcement', 'manual') then
    raise exception 'Finalidade inválida.' using errcode = '22023';
  end if;
  if p_language is null or p_language not in ('es', 'pt', 'en', 'auto') then
    raise exception 'Idioma inválido.' using errcode = '22023';
  end if;

  if p_template_id is null then
    insert into public.marketing_message_templates (org_id, name, channel, purpose, language, subject, body, created_by, updated_by)
    values (p_org_id, v_name, p_channel, p_purpose, p_language, v_subject, v_body, auth.uid(), auth.uid())
    returning id into v_id;
  else
    perform 1 from public.marketing_message_templates t
    where t.id = p_template_id and t.org_id = p_org_id for update;
    if not found then
      raise exception 'Modelo não encontrado.' using errcode = 'P0002';
    end if;
    update public.marketing_message_templates
    set name = v_name, channel = p_channel, purpose = p_purpose, language = p_language, subject = v_subject,
        body = v_body, version = version + 1, updated_by = auth.uid()
    where id = p_template_id and org_id = p_org_id
    returning id into v_id;
  end if;
  return v_id;
end;
$$;

-- Arquiva (p_archived = true) ou devolve à lista (false, o "Desfazer").
create or replace function public.messaging_archive_template(p_org_id uuid, p_template_id uuid, p_archived boolean)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if not public.has_permission(p_org_id, 'mensagens.configure') then
    raise exception 'Sem permissão para arquivar modelos.' using errcode = '42501';
  end if;
  update public.marketing_message_templates
  set active = not coalesce(p_archived, true),
      archived_at = case when coalesce(p_archived, true) then pg_catalog.now() else null end,
      updated_by = auth.uid()
  where id = p_template_id and org_id = p_org_id
  returning id into v_id;
  if v_id is null then
    raise exception 'Modelo não encontrado.' using errcode = 'P0002';
  end if;
end;
$$;

create or replace function public.messaging_duplicate_template(p_org_id uuid, p_template_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_src public.marketing_message_templates;
  v_id uuid;
begin
  if not public.has_permission(p_org_id, 'mensagens.configure') then
    raise exception 'Sem permissão para criar modelos.' using errcode = '42501';
  end if;
  select t.* into v_src from public.marketing_message_templates t
  where t.id = p_template_id and t.org_id = p_org_id;
  if not found then
    raise exception 'Modelo não encontrado.' using errcode = 'P0002';
  end if;
  insert into public.marketing_message_templates (org_id, name, channel, purpose, language, subject, body, created_by, updated_by)
  values (p_org_id, pg_catalog.left(v_src.name || ' (cópia)', 120), v_src.channel, v_src.purpose, v_src.language,
          v_src.subject, v_src.body, auth.uid(), auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;

-- ─── Conexão do canal (WhatsApp) ───────────────────────────────────────────────────────────────────
-- Guarda só o estado (provedor, identificação do número, situação, telefone e nome do número): nunca token. Se nada
-- mudou, não grava.
create or replace function public.messaging_save_connection(
  p_org_id uuid,
  p_provider text,
  p_session_name text,
  p_status text,
  p_phone text,
  p_display_name text
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_now timestamptz := pg_catalog.now();
  v_session text := pg_catalog.btrim(coalesce(p_session_name, ''));
begin
  if not public.has_permission(p_org_id, 'mensagens.configure') then
    raise exception 'Sem permissão para configurar o WhatsApp.' using errcode = '42501';
  end if;
  if p_provider is null or p_provider <> 'meta_cloud' then
    raise exception 'Provedor inválido.' using errcode = '22023';
  end if;
  if p_status is null or p_status not in ('disconnected', 'starting', 'awaiting_scan', 'connected', 'failed') then
    raise exception 'Situação da conexão inválida.' using errcode = '22023';
  end if;
  if v_session = '' or pg_catalog.char_length(v_session) > 120
     or pg_catalog.char_length(coalesce(p_phone, '')) > 40 or pg_catalog.char_length(coalesce(p_display_name, '')) > 120 then
    raise exception 'Dados da conexão inválidos.' using errcode = '22023';
  end if;

  insert into public.messaging_connections
    (org_id, channel, provider, session_name, status, phone, display_name, connected_at, status_at, updated_at, created_by)
  values
    (p_org_id, 'whatsapp', p_provider, v_session, p_status, nullif(p_phone, ''), nullif(p_display_name, ''),
     case when p_status = 'connected' then v_now end, v_now, v_now, auth.uid())
  on conflict (org_id, channel) do update
    set provider = excluded.provider, session_name = excluded.session_name, status = excluded.status,
        phone = excluded.phone, display_name = excluded.display_name,
        -- connected_at é desde quando está conectada: só nome ou telefone mudando não zera.
        connected_at = case when excluded.status <> 'connected' then null
                            when public.messaging_connections.status = 'connected' then coalesce(public.messaging_connections.connected_at, v_now)
                            else v_now end,
        status_at = case when public.messaging_connections.status is distinct from excluded.status then v_now
                         else public.messaging_connections.status_at end,
        updated_at = v_now
    where (public.messaging_connections.provider, public.messaging_connections.session_name,
           public.messaging_connections.status, public.messaging_connections.phone,
           public.messaging_connections.display_name)
      is distinct from (excluded.provider, excluded.session_name, excluded.status, excluded.phone, excluded.display_name);
end;
$$;

-- ─── Registro de teste de envio ────────────────────────────────────────────────────────────────────
-- Dois passos em volta da chamada ao provedor (que fica no servidor): (1) messaging_log_test_send ANTES: confere a
-- liberação, aplica o limite de testes por hora (5 por estúdio, 3 por pessoa) e reserva a linha do registro; se recusar, o
-- servidor NÃO chama o provedor; (2) messaging_log_test_result DEPOIS: grava como ficou (enviado ou falhou). A tabela
-- não tem política de atualização: só esta função, que confere login, estúdio e liberação por dentro, muda a linha
-- (e só a que a própria pessoa reservou há pouco).
create or replace function public.messaging_log_test_send(
  p_org_id uuid,
  p_provider text,
  p_channel text,
  p_recipient text,
  p_body text
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if not public.has_permission(p_org_id, 'mensagens.configure') then
    raise exception 'Sem permissão para enviar o teste.' using errcode = '42501';
  end if;
  if p_provider is null or p_provider not in ('meta_cloud', 'resend') then
    raise exception 'Provedor inválido.' using errcode = '22023';
  end if;
  if p_channel is null or p_channel not in ('whatsapp', 'email') then
    raise exception 'Canal inválido.' using errcode = '22023';
  end if;
  if pg_catalog.btrim(coalesce(p_recipient, '')) = '' or pg_catalog.char_length(p_recipient) > 200
     or pg_catalog.btrim(coalesce(p_body, '')) = '' or pg_catalog.char_length(p_body) > 1000 then
    raise exception 'Dados do envio inválidos.' using errcode = '22023';
  end if;

  -- Limite por hora, contado com o estúdio travado (duas abas ao mesmo tempo não furam o limite).
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('messaging_test:' || p_org_id::text, 0));
  if (select pg_catalog.count(*) from public.messaging_provider_log l
      where l.org_id = p_org_id and l.purpose = 'teste' and l.created_at > pg_catalog.now() - interval '1 hour') >= 5
     or (select pg_catalog.count(*) from public.messaging_provider_log l
         where l.org_id = p_org_id and l.purpose = 'teste' and l.created_by = auth.uid()
           and l.created_at > pg_catalog.now() - interval '1 hour') >= 3 then
    raise exception 'Limite de testes de envio por hora (3 por pessoa, 5 por estúdio). Tente de novo mais tarde.' using errcode = 'P0001';
  end if;

  insert into public.messaging_provider_log (org_id, provider, channel, purpose, recipient, body, status, error_message, created_by)
  values (p_org_id, p_provider, p_channel, 'teste', p_recipient, p_body, 'failed', 'Aguardando a resposta do provedor', auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;

-- SECURITY DEFINER (justificado: a tabela não tem política de atualização, de propósito): confere login, estúdio e
-- liberação aqui dentro e só muda a linha de teste reservada pela própria pessoa nos últimos 10 minutos.
create or replace function public.messaging_log_test_result(
  p_org_id uuid,
  p_log_id uuid,
  p_ok boolean,
  p_provider_message_id text,
  p_error text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null or p_org_id is null or p_org_id not in (select public.auth_org_ids()) then
    raise exception 'Sem acesso a este estúdio.' using errcode = '42501';
  end if;
  if not public.has_permission(p_org_id, 'mensagens.configure') then
    raise exception 'Sem permissão para enviar o teste.' using errcode = '42501';
  end if;
  if pg_catalog.char_length(coalesce(p_provider_message_id, '')) > 200 then
    raise exception 'Dados do envio inválidos.' using errcode = '22023';
  end if;
  update public.messaging_provider_log l
  set status = case when p_ok then 'sent' else 'failed' end,
      provider_message_id = case when p_ok then nullif(p_provider_message_id, '') end,
      error_message = case when p_ok then null else pg_catalog.left(coalesce(nullif(p_error, ''), 'Falha no envio'), 500) end
  where l.id = p_log_id and l.org_id = p_org_id and l.purpose = 'teste' and l.created_by = auth.uid()
    and l.error_message = 'Aguardando a resposta do provedor' and l.created_at > pg_catalog.now() - interval '10 minutes'
  returning l.id into v_id;
  if v_id is null then
    raise exception 'Registro de envio não encontrado.' using errcode = 'P0002';
  end if;
end;
$$;
revoke all on function public.messaging_log_test_result(uuid, uuid, boolean, text, text) from public, anon;
grant execute on function public.messaging_log_test_result(uuid, uuid, boolean, text, text) to authenticated;

-- ─── Campanha ──────────────────────────────────────────────────────────────────────────────────────
-- Cria o rascunho e calcula o público estimado no mesmo passo.
create or replace function public.marketing_create_campaign(
  p_org_id uuid,
  p_name text,
  p_description text,
  p_planned_channel text,
  p_purpose text,
  p_template_id uuid,
  p_audience_filter jsonb
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_name text := pg_catalog.btrim(coalesce(p_name, ''));
  v_desc text := nullif(pg_catalog.btrim(coalesce(p_description, '')), '');
  v_filter jsonb := coalesce(p_audience_filter, '{}'::jsonb);
  v_total integer;
  v_id uuid;
  v_tpl public.marketing_message_templates;
begin
  if not public.has_permission(p_org_id, 'mensagens.configure') then
    raise exception 'Sem permissão para gerenciar marketing.' using errcode = '42501';
  end if;
  if v_name = '' or pg_catalog.char_length(v_name) > 120 then
    raise exception 'O nome da campanha vai de 1 a 120 caracteres.' using errcode = '22023';
  end if;
  if pg_catalog.char_length(coalesce(v_desc, '')) > 500 then
    raise exception 'A descrição da campanha passa de 500 caracteres.' using errcode = '22023';
  end if;
  if p_planned_channel is null or p_planned_channel not in ('whatsapp_manual', 'whatsapp_provider', 'sms_provider', 'email_provider', 'internal_note') then
    raise exception 'Canal inválido.' using errcode = '22023';
  end if;
  if p_purpose is null or p_purpose not in ('birthday', 'inactive_recovery', 'aftercare', 'review_request', 'promotion', 'announcement', 'manual') then
    raise exception 'Finalidade inválida.' using errcode = '22023';
  end if;
  if pg_catalog.jsonb_typeof(v_filter) <> 'object' or pg_catalog.pg_column_size(v_filter) > 4000 then
    raise exception 'Filtro de público inválido.' using errcode = '22023';
  end if;
  if exists (select 1 from pg_catalog.jsonb_object_keys(v_filter) k
             where k not in ('clientStatus', 'tagsAny', 'serviceIdsAny', 'inactiveDays', 'birthdayWindowDays',
                             'totalSpentMin', 'totalSpentMax', 'marketingConsent', 'channel')) then
    raise exception 'Filtro de público inválido.' using errcode = '22023';
  end if;
  -- O canal da estimativa e da fila é UM só: o planejado. Filtro sem canal usa o planejado; com outro canal, recusa.
  if v_filter ? 'channel' and v_filter ->> 'channel' is distinct from p_planned_channel then
    raise exception 'O canal do público é diferente do canal da campanha.' using errcode = '22023';
  end if;
  v_filter := v_filter || pg_catalog.jsonb_build_object('channel', p_planned_channel);
  if p_template_id is not null then
    select t.* into v_tpl from public.marketing_message_templates t where t.id = p_template_id and t.org_id = p_org_id;
    if not found then
      raise exception 'Modelo não encontrado neste estúdio.' using errcode = 'P0002';
    end if;
    if v_tpl.archived_at is not null then
      raise exception 'Este modelo está arquivado.' using errcode = '22023';
    end if;
    if v_tpl.channel <> p_planned_channel then
      raise exception 'O modelo é de outro canal.' using errcode = '22023';
    end if;
  end if;

  select pg_catalog.count(*) into v_total from public.marketing_audience(p_org_id, v_filter, false);

  insert into public.marketing_campaigns
    (org_id, name, description, status, planned_channel, purpose, template_id, audience_filter, audience_snapshot,
     estimated_audience_count, created_by, updated_by)
  values
    (p_org_id, v_name, v_desc, 'draft', p_planned_channel, p_purpose, p_template_id, v_filter,
     pg_catalog.jsonb_build_object('estimatedAt', pg_catalog.now(), 'total', v_total, 'unsupported', '[]'::jsonb),
     v_total, auth.uid(), auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.marketing_archive_campaign(p_org_id uuid, p_campaign_id uuid)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if not public.has_permission(p_org_id, 'mensagens.configure') then
    raise exception 'Sem permissão para gerenciar marketing.' using errcode = '42501';
  end if;
  update public.marketing_campaigns
  set status = 'archived', archived_at = pg_catalog.now(), updated_by = auth.uid()
  where id = p_campaign_id and org_id = p_org_id
  returning id into v_id;
  if v_id is null then
    raise exception 'Campanha não encontrada.' using errcode = 'P0002';
  end if;
end;
$$;

-- Itens "prontos" de quem recusou o meio, foi mesclada ou bloqueada depois viram "ignorado". SECURITY DEFINER só porque
-- marketing_client_eligible não é chamável por quem está logado; confere login e liberação aqui dentro, só escreve
-- status 'skipped' (o gatilho de auditoria da fila registra a mudança).
create or replace function public.marketing_skip_ineligible_ready(p_org_id uuid, p_campaign_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_n integer;
begin
  if auth.uid() is null or not public.has_permission(p_org_id, 'mensagens.configure') then
    raise exception 'Sem permissão para preparar fila de marketing.' using errcode = '42501';
  end if;
  update public.marketing_message_queue q
  set status = 'skipped', updated_at = pg_catalog.now()
  where q.org_id = p_org_id and q.campaign_id = p_campaign_id and q.status = 'manual_ready'
    and public.marketing_client_eligible(q.org_id, q.client_id, q.channel) is not true;
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;
revoke all on function public.marketing_skip_ineligible_ready(uuid, uuid) from public, anon;
grant execute on function public.marketing_skip_ineligible_ready(uuid, uuid) to authenticated;

-- Prepara a fila manual da campanha. Nada é enviado. Cada chamada: (1) itens em rascunho cuja cliente saiu do público
-- viram "ignorado"; (2) itens em rascunho que continuam no público recebem o texto e o destino atuais; (3) clientes
-- do público que ainda não têm item entram, em ordem estável (nome, id), até 50 por vez ("preparar em lotes": a 51ª em
-- diante entra na chamada seguinte). Item que saiu de rascunho (pronto, cancelado, ignorado) NUNCA é reaberto.
-- Devolve { drafts: itens em rascunho, added: novos desta chamada, remaining: ainda sem item }.
create or replace function public.marketing_prepare_queue(p_org_id uuid, p_campaign_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_campaign public.marketing_campaigns;
  v_tpl public.marketing_message_templates;
  v_subject text;
  v_body text := 'Mensagem manual para {cliente}';
  v_ids uuid[];
  v_names text[];
  v_recips text[];
  v_added integer;
  v_drafts integer;
  v_remaining integer;
begin
  if not public.has_permission(p_org_id, 'mensagens.configure') then
    raise exception 'Sem permissão para preparar fila de marketing.' using errcode = '42501';
  end if;
  select c.* into v_campaign from public.marketing_campaigns c
  where c.id = p_campaign_id and c.org_id = p_org_id for update;
  if not found then
    raise exception 'Campanha não encontrada.' using errcode = 'P0002';
  end if;
  if v_campaign.status = 'archived' then
    raise exception 'Campanha arquivada.' using errcode = '22023';
  end if;

  if v_campaign.template_id is not null then
    select t.* into v_tpl from public.marketing_message_templates t
    where t.id = v_campaign.template_id and t.org_id = p_org_id;
    if found then
      if v_tpl.archived_at is not null then
        raise exception 'O modelo desta campanha está arquivado.' using errcode = '22023';
      end if;
      if v_tpl.channel <> v_campaign.planned_channel then
        raise exception 'O modelo é de outro canal.' using errcode = '22023';
      end if;
      v_subject := v_tpl.subject;
      v_body := v_tpl.body;
    end if;
  end if;

  -- Público com o consentimento imposto, no canal planejado (o mesmo da estimativa).
  select pg_catalog.array_agg(x.client_id order by x.full_name, x.client_id),
         pg_catalog.array_agg(x.full_name order by x.full_name, x.client_id),
         pg_catalog.array_agg(x.recipient order by x.full_name, x.client_id)
    into v_ids, v_names, v_recips
  from (
    select a.client_id, a.full_name,
           case v_campaign.planned_channel
             when 'email_provider' then coalesce(a.email, '')
             when 'internal_note' then a.client_id::text
             else case when coalesce(a.phone, '') like '+%' or coalesce(a.phone_country_code, '') = ''
                       then coalesce(a.phone, '')
                       else a.phone_country_code || coalesce(a.phone, '') end
           end as recipient
    from public.marketing_audience(
      p_org_id, v_campaign.audience_filter || pg_catalog.jsonb_build_object('channel', v_campaign.planned_channel), true) a
  ) x
  where x.recipient <> '';
  v_ids := coalesce(v_ids, '{}'); v_names := coalesce(v_names, '{}'); v_recips := coalesce(v_recips, '{}');

  update public.marketing_message_queue q
  set status = 'skipped', updated_at = pg_catalog.now()
  where q.org_id = p_org_id and q.campaign_id = p_campaign_id and q.status = 'draft' and q.client_id <> all (v_ids);

  -- Item já marcado como pronto de quem recusou o meio, foi mesclada ou bloqueada depois: também vira "ignorado"
  -- (o envio, manual ou automático, confere o consentimento de novo na hora de enviar).
  perform public.marketing_skip_ineligible_ready(p_org_id, p_campaign_id);

  update public.marketing_message_queue q
  set template_id = v_campaign.template_id, recipient = t.recipient, message_subject = v_subject,
      message_body = pg_catalog.replace(pg_catalog.replace(v_body, '{cliente}', t.full_name), '{clientName}', t.full_name),
      updated_at = pg_catalog.now()
  from rows from (pg_catalog.unnest(v_ids), pg_catalog.unnest(v_names), pg_catalog.unnest(v_recips)) as t(client_id, full_name, recipient)
  where q.org_id = p_org_id and q.campaign_id = p_campaign_id and q.status = 'draft' and q.client_id = t.client_id
    and (q.template_id, q.recipient, q.message_subject, q.message_body) is distinct from
        (v_campaign.template_id, t.recipient, v_subject,
         pg_catalog.replace(pg_catalog.replace(v_body, '{cliente}', t.full_name), '{clientName}', t.full_name));

  with written as (
    insert into public.marketing_message_queue
      (org_id, campaign_id, template_id, client_id, channel, recipient, message_subject, message_body, status,
       idempotency_key, metadata, created_by)
    select p_org_id, p_campaign_id, v_campaign.template_id, t.client_id, v_campaign.planned_channel, t.recipient,
           v_subject,
           pg_catalog.replace(pg_catalog.replace(v_body, '{cliente}', t.full_name), '{clientName}', t.full_name),
           'draft',
           p_campaign_id::text || ':' || t.client_id::text || ':' || v_campaign.planned_channel,
           pg_catalog.jsonb_build_object('source', 'MKT-01A', 'providerEnabled', false),
           auth.uid()
    from rows from (pg_catalog.unnest(v_ids), pg_catalog.unnest(v_names), pg_catalog.unnest(v_recips)) with ordinality as t(client_id, full_name, recipient, ord)
    where not exists (select 1 from public.marketing_message_queue q
                      where q.org_id = p_org_id and q.campaign_id = p_campaign_id and q.client_id = t.client_id)
    order by t.ord
    limit 50
    on conflict (org_id, idempotency_key) do nothing
    returning 1
  )
  select pg_catalog.count(*) into v_added from written;

  select pg_catalog.count(*) into v_drafts from public.marketing_message_queue q
  where q.org_id = p_org_id and q.campaign_id = p_campaign_id and q.status = 'draft';
  select pg_catalog.count(*) into v_remaining from pg_catalog.unnest(v_ids) as u(client_id)
  where not exists (select 1 from public.marketing_message_queue q
                    where q.org_id = p_org_id and q.campaign_id = p_campaign_id and q.client_id = u.client_id);

  return pg_catalog.jsonb_build_object('drafts', v_drafts, 'added', v_added, 'remaining', v_remaining);
end;
$$;

-- ─── Políticas: ler e gravar seguem as liberações, avaliadas UMA vez por consulta ─────────────────
-- Estúdios em que a pessoa pode ver Mensagens (usar ou configurar).
create or replace function public.auth_orgs_messaging_view()
returns setof uuid
language sql
stable
security invoker
set search_path = ''
as $$
  select public.auth_orgs_with_permission('mensagens.use')
  union
  select public.auth_orgs_with_permission('mensagens.configure')
$$;
revoke all on function public.auth_orgs_messaging_view() from public, anon;
grant execute on function public.auth_orgs_messaging_view() to authenticated;

drop policy if exists "marketing_templates_select" on public.marketing_message_templates;
create policy "marketing_templates_select" on public.marketing_message_templates for select to authenticated
  using (org_id in (select public.auth_orgs_messaging_view()));
drop policy if exists "marketing_templates_manage" on public.marketing_message_templates;
create policy "marketing_templates_manage" on public.marketing_message_templates for all to authenticated
  using (org_id in (select public.auth_orgs_with_permission('mensagens.configure')))
  with check (org_id in (select public.auth_orgs_with_permission('mensagens.configure')));

drop policy if exists "marketing_campaigns_select" on public.marketing_campaigns;
create policy "marketing_campaigns_select" on public.marketing_campaigns for select to authenticated
  using (org_id in (select public.auth_orgs_messaging_view()));
drop policy if exists "marketing_campaigns_manage" on public.marketing_campaigns;
create policy "marketing_campaigns_manage" on public.marketing_campaigns for all to authenticated
  using (org_id in (select public.auth_orgs_with_permission('mensagens.configure')))
  with check (org_id in (select public.auth_orgs_with_permission('mensagens.configure')));

drop policy if exists "marketing_queue_select" on public.marketing_message_queue;
create policy "marketing_queue_select" on public.marketing_message_queue for select to authenticated
  using (org_id in (select public.auth_orgs_messaging_view()));
drop policy if exists "marketing_queue_manage" on public.marketing_message_queue;
create policy "marketing_queue_manage" on public.marketing_message_queue for all to authenticated
  using (org_id in (select public.auth_orgs_with_permission('mensagens.configure')))
  with check (org_id in (select public.auth_orgs_with_permission('mensagens.configure')));

-- Eventos: só os manuais (a Meta/servidor grava os do provedor), com o próprio usuário como autor.
drop policy if exists "marketing_events_select" on public.marketing_message_events;
create policy "marketing_events_select" on public.marketing_message_events for select to authenticated
  using (org_id in (select public.auth_orgs_messaging_view()));
drop policy if exists "marketing_events_insert" on public.marketing_message_events;
create policy "marketing_events_insert" on public.marketing_message_events for insert to authenticated
  with check (org_id in (select public.auth_orgs_with_permission('mensagens.configure'))
    and created_by = (select auth.uid())
    and event_type in ('manual_ready', 'manual_link_opened', 'cancelled', 'skipped')
    and status in ('manual_ready', 'opened_manual_link', 'cancelled', 'skipped'));

-- Conexão do canal.
drop policy if exists messaging_connections_select on public.messaging_connections;
create policy messaging_connections_select on public.messaging_connections for select to authenticated
  using (org_id in (select public.auth_orgs_messaging_view()));
drop policy if exists messaging_connections_write on public.messaging_connections;
create policy messaging_connections_write on public.messaging_connections for all to authenticated
  using (org_id in (select public.auth_orgs_with_permission('mensagens.configure')))
  with check (org_id in (select public.auth_orgs_with_permission('mensagens.configure')));

-- Registro de envios: lê quem usa ou configura; pela API só entra linha de TESTE, de quem configura, com o próprio
-- usuário como autor e situação enviado/falhou (fila e entregue vêm do servidor).
drop policy if exists messaging_log_select on public.messaging_provider_log;
create policy messaging_log_select on public.messaging_provider_log for select to authenticated
  using (org_id in (select public.auth_orgs_messaging_view()));
drop policy if exists messaging_log_insert on public.messaging_provider_log;
create policy messaging_log_insert on public.messaging_provider_log for insert to authenticated
  with check (org_id in (select public.auth_orgs_with_permission('mensagens.configure'))
    and purpose = 'teste' and created_by = (select auth.uid()) and status in ('sent', 'failed'));

-- ─── Guardas no banco (valem para qualquer caminho de gravação) ──────────────────────────────────
-- Fila: mesmo estúdio de campanha, modelo e cliente; e quem recusou o meio, está mesclada ou bloqueada não entra nem
-- volta a "rascunho"/"pronto". Cancelar ou ignorar um item sempre é permitido. SECURITY DEFINER só para ler as
-- preferências sem depender de quem grava; ninguém a chama (execução revogada de todos).
create or replace function public.marketing_queue_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ok boolean;
begin
  if new.campaign_id is not null and not exists (
    select 1 from public.marketing_campaigns x where x.id = new.campaign_id and x.org_id = new.org_id) then
    raise exception 'A campanha não é deste estúdio.' using errcode = '23514';
  end if;
  if new.template_id is not null and not exists (
    select 1 from public.marketing_message_templates x where x.id = new.template_id and x.org_id = new.org_id) then
    raise exception 'O modelo não é deste estúdio.' using errcode = '23514';
  end if;
  if new.status in ('draft', 'manual_ready') and (
       tg_op = 'INSERT' or old.status is distinct from new.status or old.client_id is distinct from new.client_id
       or old.channel is distinct from new.channel or old.recipient is distinct from new.recipient) then
    v_ok := public.marketing_client_eligible(new.org_id, new.client_id, new.channel);
    if v_ok is null then
      raise exception 'A cliente não é deste estúdio.' using errcode = '23514';
    elsif not v_ok then
      -- Só o cliente mudou (mesclagem move a fila para a cliente mantida): o item vira "ignorado" em vez de
      -- travar a mesclagem. Qualquer outra mudança para rascunho/pronto continua recusada.
      if tg_op = 'UPDATE' and old.status = new.status and old.channel = new.channel
         and old.recipient is not distinct from new.recipient and old.client_id is distinct from new.client_id then
        new.status := 'skipped';
      else
        raise exception 'Esta cliente não pode receber marketing neste meio (recusou, foi mesclada ou está bloqueada).' using errcode = '23514';
      end if;
    end if;
  elsif tg_op = 'UPDATE' and old.client_id is distinct from new.client_id and not exists (
    select 1 from public.clients c where c.id = new.client_id and c.org_id = new.org_id) then
    raise exception 'A cliente não é deste estúdio.' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function public.marketing_queue_guard() from public, anon, authenticated;
drop trigger if exists marketing_queue_guard on public.marketing_message_queue;
create trigger marketing_queue_guard before insert or update on public.marketing_message_queue
  for each row execute function public.marketing_queue_guard();

-- Eventos: fila, campanha e cliente do mesmo estúdio do evento.
create or replace function public.marketing_event_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (new.queue_id is not null and not exists (select 1 from public.marketing_message_queue x where x.id = new.queue_id and x.org_id = new.org_id))
     or (new.campaign_id is not null and not exists (select 1 from public.marketing_campaigns x where x.id = new.campaign_id and x.org_id = new.org_id))
     or (new.client_id is not null and not exists (select 1 from public.clients x where x.id = new.client_id and x.org_id = new.org_id)) then
    raise exception 'Fila, campanha ou cliente de outro estúdio.' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function public.marketing_event_guard() from public, anon, authenticated;
drop trigger if exists marketing_event_guard on public.marketing_message_events;
create trigger marketing_event_guard before insert or update on public.marketing_message_events
  for each row execute function public.marketing_event_guard();

-- Campanha: o modelo é do mesmo estúdio.
create or replace function public.marketing_campaign_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.template_id is not null and not exists (
    select 1 from public.marketing_message_templates x where x.id = new.template_id and x.org_id = new.org_id) then
    raise exception 'O modelo não é deste estúdio.' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function public.marketing_campaign_guard() from public, anon, authenticated;
drop trigger if exists marketing_campaign_guard on public.marketing_campaigns;
create trigger marketing_campaign_guard before insert or update of template_id, org_id on public.marketing_campaigns
  for each row execute function public.marketing_campaign_guard();

-- O estúdio de uma linha nunca muda (quem configura dois estúdios não move linha de um para o outro). Com org_id fixo,
-- as conferências de "mesmo estúdio" das guardas acima (cliente, campanha, modelo, fila) valem para toda atualização.
create or replace function public.messaging_org_immutable()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.org_id is distinct from old.org_id then
    raise exception 'O estúdio de um registro não pode ser trocado.' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function public.messaging_org_immutable() from public, anon, authenticated;
do $$
declare t text;
begin
  foreach t in array array['marketing_message_queue', 'marketing_message_events', 'marketing_message_templates',
                           'marketing_campaigns', 'messaging_connections', 'messaging_provider_log'] loop
    execute pg_catalog.format('drop trigger if exists messaging_org_immutable on public.%I', t);
    execute pg_catalog.format('create trigger messaging_org_immutable before update of org_id on public.%I for each row execute function public.messaging_org_immutable()', t);
  end loop;
end $$;

-- ─── Permissões de execução: só quem está logado ───────────────────────────────────────────────────
revoke all on function public.messaging_save_template(uuid, uuid, text, text, text, text, text, text) from public, anon;
revoke all on function public.messaging_archive_template(uuid, uuid, boolean) from public, anon;
revoke all on function public.messaging_duplicate_template(uuid, uuid) from public, anon;
revoke all on function public.messaging_save_connection(uuid, text, text, text, text, text) from public, anon;
revoke all on function public.messaging_log_test_send(uuid, text, text, text, text) from public, anon;
revoke all on function public.marketing_create_campaign(uuid, text, text, text, text, uuid, jsonb) from public, anon;
revoke all on function public.marketing_archive_campaign(uuid, uuid) from public, anon;
revoke all on function public.marketing_prepare_queue(uuid, uuid) from public, anon;

grant execute on function public.messaging_save_template(uuid, uuid, text, text, text, text, text, text) to authenticated;
grant execute on function public.messaging_archive_template(uuid, uuid, boolean) to authenticated;
grant execute on function public.messaging_duplicate_template(uuid, uuid) to authenticated;
grant execute on function public.messaging_save_connection(uuid, text, text, text, text, text) to authenticated;
grant execute on function public.messaging_log_test_send(uuid, text, text, text, text) to authenticated;
grant execute on function public.marketing_create_campaign(uuid, text, text, text, text, uuid, jsonb) to authenticated;
grant execute on function public.marketing_archive_campaign(uuid, uuid) to authenticated;
grant execute on function public.marketing_prepare_queue(uuid, uuid) to authenticated;

-- ─── Auditoria por gatilho ─────────────────────────────────────────────────────────────────────────
-- Conexão do canal: conectou, desconectou ou trocou de provedor/número enquanto conectada (apagar a linha = desconectar).
-- Só provedor e situação no registro (nunca token, que não existe nesta tabela).
create or replace function public.messaging_connection_audit_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid := coalesce(new.org_id, old.org_id);
  v_op text;
  v_old jsonb;
  v_new jsonb;
begin
  if not exists (select 1 from public.organizations o where o.id = v_org) then
    return null;
  end if;

  if tg_op = 'DELETE' then
    if old.status <> 'connected' then return null; end if;
    v_op := 'MESSAGING_CHANNEL_DISCONNECTED';
    v_old := pg_catalog.jsonb_build_object('provider', old.provider, 'status', old.status);
    v_new := null;
  elsif tg_op = 'INSERT' then
    if new.status <> 'connected' then return null; end if;
    v_op := 'MESSAGING_CHANNEL_CONNECTED';
    v_new := pg_catalog.jsonb_build_object('provider', new.provider, 'status', new.status);
  else
    if new.status = 'connected' and (old.status <> 'connected' or old.provider is distinct from new.provider
       or old.phone is distinct from new.phone) then
      v_op := 'MESSAGING_CHANNEL_CONNECTED';
    elsif old.status = 'connected' and new.status <> 'connected' then
      v_op := 'MESSAGING_CHANNEL_DISCONNECTED';
    else
      return null;
    end if;
    v_old := pg_catalog.jsonb_build_object('provider', old.provider, 'status', old.status);
    v_new := pg_catalog.jsonb_build_object('provider', new.provider, 'status', new.status);
  end if;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (v_org, auth.uid(), 'messaging_connections', v_op, coalesce(new.id, old.id), v_old, v_new);
  return null;
end;
$$;
revoke all on function public.messaging_connection_audit_row() from public, anon, authenticated;

drop trigger if exists messaging_connection_audit on public.messaging_connections;
create trigger messaging_connection_audit after insert or update or delete on public.messaging_connections
  for each row execute function public.messaging_connection_audit_row();

-- Campanha: criada, mudada (situação, canal, finalidade, modelo), arquivada, apagada.
create or replace function public.marketing_campaign_audit_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid := coalesce(new.org_id, old.org_id);
  v_op text;
  v_old jsonb;
  v_new jsonb;
begin
  if not exists (select 1 from public.organizations o where o.id = v_org) then
    return null;
  end if;

  if tg_op = 'DELETE' then
    v_op := 'MARKETING_CAMPAIGN_DELETED';
    v_old := pg_catalog.jsonb_build_object('status', old.status, 'channel', old.planned_channel, 'purpose', old.purpose);
  elsif tg_op = 'INSERT' then
    v_op := 'MARKETING_CAMPAIGN_CREATED';
    v_new := pg_catalog.jsonb_build_object('status', new.status, 'channel', new.planned_channel, 'purpose', new.purpose,
                                           'estimated_audience', new.estimated_audience_count);
  else
    if new.status = 'archived' and old.status <> 'archived' then
      v_op := 'MARKETING_CAMPAIGN_ARCHIVED';
    else
      v_op := 'MARKETING_CAMPAIGN_UPDATED';
    end if;
    v_old := pg_catalog.jsonb_build_object('status', old.status, 'channel', old.planned_channel, 'purpose', old.purpose,
                                           'template_id', old.template_id);
    v_new := pg_catalog.jsonb_build_object('status', new.status, 'channel', new.planned_channel, 'purpose', new.purpose,
                                           'template_id', new.template_id);
  end if;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (v_org, auth.uid(), 'marketing_campaigns', v_op, coalesce(new.id, old.id), v_old, v_new);
  return null;
end;
$$;
revoke all on function public.marketing_campaign_audit_row() from public, anon, authenticated;

drop trigger if exists marketing_campaign_audit_ins on public.marketing_campaigns;
drop trigger if exists marketing_campaign_audit_upd on public.marketing_campaigns;
drop trigger if exists marketing_campaign_audit_del on public.marketing_campaigns;
create trigger marketing_campaign_audit_ins after insert on public.marketing_campaigns
  for each row execute function public.marketing_campaign_audit_row();
create trigger marketing_campaign_audit_upd after update on public.marketing_campaigns
  for each row when (old.status is distinct from new.status or old.planned_channel is distinct from new.planned_channel
    or old.purpose is distinct from new.purpose or old.template_id is distinct from new.template_id)
  execute function public.marketing_campaign_audit_row();
create trigger marketing_campaign_audit_del after delete on public.marketing_campaigns
  for each row execute function public.marketing_campaign_audit_row();

-- Fila de envio: UMA linha de auditoria por comando (quem preparou, qual campanha, quantos itens), não uma por cliente.
create or replace function public.marketing_queue_audit_stmt()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_op text := case tg_op when 'INSERT' then 'MARKETING_QUEUE_PREPARED' else 'MARKETING_QUEUE_UPDATED' end;
begin
  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  select g.org_id, auth.uid(), 'marketing_message_queue', v_op, g.campaign_id, null,
         pg_catalog.jsonb_build_object('items', g.items, 'channel', g.channel)
  from (select n.org_id, n.campaign_id, n.channel, pg_catalog.count(*) as items
        from new_rows n group by n.org_id, n.campaign_id, n.channel) g
  where exists (select 1 from public.organizations o where o.id = g.org_id);
  return null;
end;
$$;
revoke all on function public.marketing_queue_audit_stmt() from public, anon, authenticated;

drop trigger if exists marketing_queue_audit_ins on public.marketing_message_queue;
drop trigger if exists marketing_queue_audit_upd on public.marketing_message_queue;
create trigger marketing_queue_audit_ins after insert on public.marketing_message_queue
  referencing new table as new_rows for each statement execute function public.marketing_queue_audit_stmt();
create trigger marketing_queue_audit_upd after update on public.marketing_message_queue
  referencing new table as new_rows for each statement execute function public.marketing_queue_audit_stmt();
