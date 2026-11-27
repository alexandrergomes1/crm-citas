-- Assinatura da ficha: o banco revalida termos, perguntas obrigatórias e canal; grava IP anonimizado.
-- Encoding: UTF-8
--
-- Antes só o navegador validava: um POST direto assinava sem aceitar os termos. Agora a função
-- confere, contra o snapshot da própria ficha, que
--   * o termo principal (consent_text) foi aceito e cada termo obrigatório também;
--   * termo opcional foi respondido (aceito ou recusado);
--   * pergunta obrigatória tem resposta, e o detalhe pedido depois de um "sim" também;
--   * o canal (link ou modo estúdio) é um dos conhecidos.
-- Erros novos: terms_required, answers_required, channel_invalid (a tela traduz).
--
-- IP (LGPD/RGPD): guardamos só o endereço anonimizado (IPv4 sem o último octeto, IPv6 só os
-- 48 bits da rede). Serve de indício de local/rede da assinatura, não identifica a pessoa
-- sozinho. Fica com a ficha pelo mesmo prazo de guarda e nunca aparece inteiro na tela.
--
-- Compatibilidade: a função de seis parâmetros continua existindo (app antigo); ela chama a nova
-- de sete, sem IP. O app antigo já enviava canal e termo principal, então passa na validação.
set client_encoding = 'UTF8';

create or replace function public.anonymize_ip(p_ip text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_ip is null then null
    when pg_catalog.btrim(p_ip) ~ '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'
      then pg_catalog.regexp_replace(pg_catalog.btrim(p_ip), '\.[0-9]{1,3}$', '.0')
    when pg_catalog.btrim(p_ip) ~ '^[0-9a-fA-F]{1,4}:[0-9a-fA-F]{1,4}:[0-9a-fA-F]{1,4}:'
      then pg_catalog.lower(pg_catalog.regexp_replace(pg_catalog.btrim(p_ip), '^([0-9a-fA-F]{1,4}):([0-9a-fA-F]{1,4}):([0-9a-fA-F]{1,4}):.*$', '\1:\2:\3::'))
    when pg_catalog.btrim(p_ip) ~ '^[0-9a-fA-F:]*::' and pg_catalog.btrim(p_ip) ~ '^[0-9a-fA-F:.]+$'
      then pg_catalog.lower(pg_catalog.regexp_replace(pg_catalog.btrim(p_ip), '::.*$', '::'))
    else null
  end;
$$;
revoke all on function public.anonymize_ip(text) from public, anon;
grant execute on function public.anonymize_ip(text) to authenticated;

create or replace function public.submit_anamnese_signature(
  p_token text, p_answers jsonb, p_signature_name text, p_signature_data_url text,
  p_consent_accepted boolean, p_user_agent text, p_ip text
)
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
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
  if p_token is null or pg_catalog.length(p_token) not between 16 and 200 then
    return pg_catalog.jsonb_build_object('error','not_found');
  end if;
  select * into v from public.anamneses where public_token = p_token for update;
  if not found then return pg_catalog.jsonb_build_object('error','not_found'); end if;
  if v.status = 'signed' then return pg_catalog.jsonb_build_object('error','already_signed'); end if;
  if v.token_expires_at is not null and v.token_expires_at < pg_catalog.now() then
    return pg_catalog.jsonb_build_object('error','expired');
  end if;
  if coalesce(p_consent_accepted,false) = false then
    return pg_catalog.jsonb_build_object('error','consent_required');
  end if;
  if p_signature_data_url is null or pg_catalog.length(p_signature_data_url) < 50 then
    return pg_catalog.jsonb_build_object('error','signature_required');
  end if;
  -- Link público: limita tamanho e formato (assinatura em imagem, respostas em objeto).
  if p_signature_data_url not like 'data:image/%'
     or pg_catalog.length(p_signature_data_url) > 1000000
     or pg_catalog.length(coalesce(p_signature_name, '')) > 160
     or (p_answers is not null and (pg_catalog.jsonb_typeof(p_answers) <> 'object'
         or pg_catalog.pg_column_size(p_answers) > 200000)) then
    return pg_catalog.jsonb_build_object('error','invalid_payload');
  end if;

  -- Canal: link no celular ou modo estúdio (gravado como "tablet", valor histórico).
  if v_answers ->> '__canal' is null or v_answers ->> '__canal' not in ('link', 'tablet') then
    return pg_catalog.jsonb_build_object('error','channel_invalid');
  end if;

  -- Termo principal.
  if pg_catalog.btrim(coalesce(v.consent_text, '')) <> '' and v_answers ->> '__termo_principal' is distinct from 'aceito' then
    return pg_catalog.jsonb_build_object('error','terms_required');
  end if;

  -- Termos e perguntas do snapshot da própria ficha (nunca do modelo atual).
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
          return pg_catalog.jsonb_build_object('error','terms_required');
        end if;
      elsif v_value is null or v_value not in ('aceito', 'recusado') then
        return pg_catalog.jsonb_build_object('error','terms_required');
      end if;
    elsif v_type in ('yes_no', 'multiple_choice', 'text') then
      if v_required and pg_catalog.btrim(coalesce(v_value, '')) = '' then
        return pg_catalog.jsonb_build_object('error','answers_required');
      end if;
      if coalesce(b ->> 'explainWhenAnswer', '') <> '' and v_value = b ->> 'explainWhenAnswer'
         and pg_catalog.btrim(coalesce(v_answers ->> (v_id || '__explain'), '')) = '' then
        return pg_catalog.jsonb_build_object('error','answers_required');
      end if;
    end if;
  end loop;

  update public.anamneses set
    answers            = v_answers,
    signature_name     = p_signature_name,
    signature_data_url = p_signature_data_url,
    consent_accepted   = true,
    signer_user_agent  = pg_catalog.left(p_user_agent, 500),
    signer_ip          = public.anonymize_ip(p_ip),
    status             = 'signed',
    signed_at          = pg_catalog.now(),
    updated_at         = pg_catalog.now()
  where id = v.id;

  return pg_catalog.jsonb_build_object('ok', true, 'signed_at', pg_catalog.now());
end; $function$;

-- Seis parâmetros (app antigo): mesma regra, sem IP.
create or replace function public.submit_anamnese_signature(
  p_token text, p_answers jsonb, p_signature_name text, p_signature_data_url text,
  p_consent_accepted boolean, p_user_agent text
)
 returns jsonb
 language sql
 security definer
 set search_path to ''
as $function$
  select public.submit_anamnese_signature(
    p_token, p_answers, p_signature_name, p_signature_data_url, p_consent_accepted, p_user_agent, null::text);
$function$;

revoke all on function public.submit_anamnese_signature(text, jsonb, text, text, boolean, text) from public;
revoke all on function public.submit_anamnese_signature(text, jsonb, text, text, boolean, text, text) from public;
grant execute on function public.submit_anamnese_signature(text, jsonb, text, text, boolean, text) to anon, authenticated;
grant execute on function public.submit_anamnese_signature(text, jsonb, text, text, boolean, text, text) to anon, authenticated;
