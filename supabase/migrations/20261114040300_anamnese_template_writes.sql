-- Anamnese (porte): ações dos modelos de ficha em UMA ida ao banco, com permissão e auditoria no banco.
-- Encoding: UTF-8
set client_encoding = 'UTF8';
--
-- SECURITY INVOKER (a RLS de anamnese_templates exige anamnese.manage_templates para gravar):
--   anamnese_check_template     conferência do conteúdo (tamanhos e formatos)
--   anamnese_save_template      salvar/publicar modelo (antes: inserir/atualizar + publicar, 2 idas)
--   anamnese_template_action    publicar, voltar a rascunho, excluir, duplicar (antes: ler + criar + publicar)
--   anamnese_template_usage     uso do modelo antes de excluir (antes: status + comandas, 2 idas)
--   anamnese_import_templates   modelos do sistema (antes: 1 + 1 por modelo, 5 idas)
-- Auditoria (regra de 14/11): gatilho AFTER em anamnese_templates (SECURITY DEFINER, sem execução para ninguém),
-- para qualquer caminho que grave: criado, conteúdo ou descrição salvos, publicado/rascunho e excluído. Grava
-- auth.uid(), id, título e versão; o conteúdo do modelo não vai para a auditoria.

-- ─── Modelos ───────────────────────────────────────────────────────────────────────────────────────
-- Conteúdo do modelo conferido no banco (o app também confere com Zod): tamanhos e formatos.
create or replace function public.anamnese_check_template(p_template jsonb)
returns void
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_title text := pg_catalog.btrim(coalesce(p_template ->> 'title', ''));
begin
  if pg_catalog.jsonb_typeof(p_template) is distinct from 'object' then
    raise exception 'Modelo inválido' using errcode = '22023';
  end if;
  if v_title = '' or pg_catalog.char_length(v_title) > 120 then
    raise exception 'Dê um nome ao modelo (até 120 letras)' using errcode = '22023';
  end if;
  if pg_catalog.char_length(coalesce(p_template ->> 'description', '')) > 500
     or pg_catalog.char_length(coalesce(p_template ->> 'consent_text', '')) > 20000
     or pg_catalog.char_length(coalesce(p_template ->> 'consent_version', '')) > 40 then
    raise exception 'Texto grande demais no modelo' using errcode = '22023';
  end if;
  if pg_catalog.jsonb_typeof(p_template -> 'questions') is distinct from 'array'
     or pg_catalog.jsonb_array_length(p_template -> 'questions') not between 1 and 300
     or pg_catalog.octet_length((p_template -> 'questions')::text) > 600000 then
    raise exception 'Perguntas do modelo inválidas' using errcode = '22023';
  end if;
  if p_template ? 'country' and (p_template ->> 'country') !~ '^[A-Z]{2}$' then
    raise exception 'País inválido' using errcode = '22023';
  end if;
  if p_template ? 'professional_form' and pg_catalog.jsonb_typeof(p_template -> 'professional_form') not in ('object', 'null') then
    raise exception 'Parte profissional inválida' using errcode = '22023';
  end if;
end;
$$;
revoke all on function public.anamnese_check_template(jsonb) from public, anon;
grant execute on function public.anamnese_check_template(jsonb) to authenticated;

-- Salvar rascunho ou publicar. Modelo novo nasce com is_active = p_publish; existente só muda de estado ao publicar
-- (como antes). Campos ausentes no pedido ficam como estão (consent_text, consent_version, country, professional_form).
create or replace function public.anamnese_save_template(p_org_id uuid, p_template_id uuid, p_template jsonb, p_publish boolean)
returns uuid
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_id uuid;
begin
  if v_uid is null or not public.has_permission(p_org_id, 'anamnese.manage_templates') then
    raise exception 'Sem permissão para editar modelos de ficha' using errcode = '42501';
  end if;
  perform public.anamnese_check_template(p_template);

  if p_template_id is null then
    insert into public.anamnese_templates (org_id, title, description, questions, consent_text, consent_version,
      professional_form, country, is_active)
    values (
      p_org_id, pg_catalog.btrim(p_template ->> 'title'), nullif(p_template ->> 'description', ''), p_template -> 'questions',
      coalesce(nullif(p_template ->> 'consent_text', ''), ''), coalesce(nullif(p_template ->> 'consent_version', ''), 'lgpd-v1'),
      case when p_template ? 'professional_form' and pg_catalog.jsonb_typeof(p_template -> 'professional_form') = 'object'
           then p_template -> 'professional_form' end,
      coalesce(p_template ->> 'country', 'ES'), coalesce(p_publish, false))
    returning id into v_id;
  else
    perform 1 from public.anamnese_templates t
    where t.org_id = p_org_id and t.id = p_template_id and t.active
    for update;
    if not found then
      raise exception 'Modelo de anamnese ativo não encontrado' using errcode = 'P0002';
    end if;
    update public.anamnese_templates t set
      title = pg_catalog.btrim(p_template ->> 'title'),
      description = nullif(p_template ->> 'description', ''),
      questions = p_template -> 'questions',
      consent_text = case when coalesce(p_template ->> 'consent_text', '') <> '' then p_template ->> 'consent_text' else t.consent_text end,
      consent_version = case when coalesce(p_template ->> 'consent_version', '') <> '' then p_template ->> 'consent_version' else t.consent_version end,
      professional_form = case when p_template ? 'professional_form' then nullif(p_template -> 'professional_form', 'null'::jsonb) else t.professional_form end,
      country = coalesce(p_template ->> 'country', t.country),
      is_active = case when p_publish then true else t.is_active end,
      updated_at = pg_catalog.now()
    where t.org_id = p_org_id and t.id = p_template_id
    returning id into v_id;
  end if;

  return v_id;
end;
$$;
revoke all on function public.anamnese_save_template(uuid, uuid, jsonb, boolean) from public, anon;
grant execute on function public.anamnese_save_template(uuid, uuid, jsonb, boolean) to authenticated;

-- p_action: 'publish' | 'unpublish' | 'delete' (sai das novas fichas; as fichas guardam a cópia) | 'duplicate'
-- (cópia em rascunho). Devolve o id do modelo (a cópia, ao duplicar).
create or replace function public.anamnese_template_action(p_org_id uuid, p_template_id uuid, p_action text)
returns uuid
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_tpl public.anamnese_templates;
  v_id uuid := p_template_id;
begin
  if v_uid is null or not public.has_permission(p_org_id, 'anamnese.manage_templates') then
    raise exception 'Sem permissão para editar modelos de ficha' using errcode = '42501';
  end if;
  if p_action is null or p_action not in ('publish', 'unpublish', 'delete', 'duplicate') then
    raise exception 'Ação inválida' using errcode = '22023';
  end if;
  select t.* into v_tpl from public.anamnese_templates t
  where t.org_id = p_org_id and t.id = p_template_id and t.active
  for update;
  if not found then
    raise exception 'Modelo de anamnese ativo não encontrado' using errcode = 'P0002';
  end if;

  if p_action in ('publish', 'unpublish') then
    update public.anamnese_templates set is_active = (p_action = 'publish')
    where org_id = p_org_id and id = p_template_id;
  elsif p_action = 'delete' then
    update public.anamnese_templates set active = false
    where org_id = p_org_id and id = p_template_id;
  else
    insert into public.anamnese_templates (org_id, title, description, questions, consent_text, consent_version,
      professional_form, country, is_active)
    values (p_org_id, pg_catalog.left(v_tpl.title || ' (cópia)', 120), v_tpl.description, v_tpl.questions,
      v_tpl.consent_text, v_tpl.consent_version, v_tpl.professional_form, v_tpl.country, false)
    returning id into v_id;
  end if;

  return v_id;
end;
$$;
revoke all on function public.anamnese_template_action(uuid, uuid, text) from public, anon;
grant execute on function public.anamnese_template_action(uuid, uuid, text) to authenticated;

-- Fichas que usam o modelo e se a comanda do atendimento já foi paga (sem nome: só conta). Até 1000.
create or replace function public.anamnese_template_usage(p_org_id uuid, p_template_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not public.has_permission(p_org_id, 'anamnese.manage_templates') then
    raise exception 'Sem permissão para editar modelos de ficha' using errcode = '42501';
  end if;
  return coalesce((
    select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'appointment_id', s.appointment_id,
        'paid', s.appointment_id is not null and exists (
          select 1 from public.sales sa
          where sa.org_id = p_org_id and sa.appointment_id = s.appointment_id and sa.status = 'paid')))
    from public.list_anamnese_status(p_org_id, p_template_id => p_template_id) s), '[]'::jsonb);
end;
$$;
revoke all on function public.anamnese_template_usage(uuid, uuid) from public, anon;
grant execute on function public.anamnese_template_usage(uuid, uuid) to authenticated;

-- Modelos do sistema: cria ou atualiza pelo título (modelo ativo de mesmo título). Até 10 modelos por pedido.
create or replace function public.anamnese_import_templates(p_org_id uuid, p_templates jsonb)
returns integer
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_tpl jsonb;
  v_id uuid;
  v_count integer := 0;
begin
  if v_uid is null or not public.has_permission(p_org_id, 'anamnese.manage_templates') then
    raise exception 'Sem permissão para editar modelos de ficha' using errcode = '42501';
  end if;
  if pg_catalog.jsonb_typeof(p_templates) is distinct from 'array' or pg_catalog.jsonb_array_length(p_templates) not between 1 and 10 then
    raise exception 'Lista de modelos inválida' using errcode = '22023';
  end if;
  for v_tpl in select x from pg_catalog.jsonb_array_elements(p_templates) x loop
    perform public.anamnese_check_template(v_tpl);
    select t.id into v_id from public.anamnese_templates t
    where t.org_id = p_org_id and t.active and t.title = pg_catalog.btrim(v_tpl ->> 'title')
    order by t.created_at, t.id limit 1
    for update;
    if found then
      update public.anamnese_templates set
        description = nullif(v_tpl ->> 'description', ''), questions = v_tpl -> 'questions',
        consent_text = coalesce(nullif(v_tpl ->> 'consent_text', ''), consent_text),
        professional_form = v_tpl -> 'professional_form', updated_at = pg_catalog.now()
      where org_id = p_org_id and id = v_id;
    else
      insert into public.anamnese_templates (org_id, title, description, questions, consent_text, professional_form)
      values (p_org_id, pg_catalog.btrim(v_tpl ->> 'title'), nullif(v_tpl ->> 'description', ''), v_tpl -> 'questions',
              coalesce(v_tpl ->> 'consent_text', ''), v_tpl -> 'professional_form');
    end if;
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;
revoke all on function public.anamnese_import_templates(uuid, jsonb) from public, anon;
grant execute on function public.anamnese_import_templates(uuid, jsonb) to authenticated;


-- ─── Auditoria dos modelos ─────────────────────────────────────────────────────────────────────────
create or replace function public.anamnese_templates_audit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid;
  v_row public.anamnese_templates;
  v_ops text[] := '{}';
  v_op text;
begin
  if tg_op = 'DELETE' then v_row := old; else v_row := new; end if;
  v_org := v_row.org_id;
  -- Sem estúdio (não acontece pela tabela, org_id é obrigatório): não grava.
  if v_org is null then
    return null;
  end if;
  if tg_op = 'INSERT' then
    v_ops := array['ANAMNESE_TEMPLATE_CREATED'];
  elsif tg_op = 'DELETE' or (old.active and not new.active) then
    v_ops := array['ANAMNESE_TEMPLATE_DELETED'];
  else
    if new.version is distinct from old.version or new.description is distinct from old.description then
      v_ops := pg_catalog.array_append(v_ops, 'ANAMNESE_TEMPLATE_SAVED');
    end if;
    if new.is_active is distinct from old.is_active then
      v_ops := pg_catalog.array_append(v_ops, case when new.is_active then 'ANAMNESE_TEMPLATE_PUBLISHED' else 'ANAMNESE_TEMPLATE_UNPUBLISHED' end);
    end if;
  end if;
  foreach v_op in array v_ops loop
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
    values (v_org, (select auth.uid()), 'anamnese_templates', v_op, v_row.id,
            pg_catalog.jsonb_build_object('title', v_row.title, 'version', v_row.version, 'is_active', v_row.is_active));
  end loop;
  return null;
end;
$$;
revoke all on function public.anamnese_templates_audit() from public, anon, authenticated;

drop trigger if exists trg_anamnese_templates_audit on public.anamnese_templates;
create trigger trg_anamnese_templates_audit
  after insert or update or delete on public.anamnese_templates
  for each row execute function public.anamnese_templates_audit();
