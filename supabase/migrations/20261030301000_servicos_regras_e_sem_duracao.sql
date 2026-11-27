-- Catálogo: regras por serviço (durabilidade, retoque incluído, sinal) e serviço sem duração.
-- Encoding: UTF-8
--
-- Pendências do redesenho V25 (quadros PCatalogoEditor e PCatalogo):
--   1. Durabilidade do resultado (meses), retoque incluído (janela em dias sem cobrança) e sinal
--      exigido por serviço (valor fixo ou porcentagem).
--   2. Serviço "sem duração" (produto/venda rápida, serviço sem tempo): duration_minutes = 0.
--      Fica fora da reserva online; na agenda ocupa um encaixe curto de 15 min.
--
-- Compatibilidade com o app anterior: colunas novas nulas; a RPC ganha UM parâmetro novo com
-- padrão nulo (p_rules) - quem a chama com os 15 parâmetros antigos continua igual e uma edição
-- sem p_rules NÃO apaga as regras; nenhum serviço existente tem duração 0.

-- ─── 1. Colunas e CHECKs ─────────────────────────────────────────────────────────────────────

alter table public.services
  add column if not exists result_months integer,
  add column if not exists retouch_included_days integer,
  add column if not exists deposit_type text,
  add column if not exists deposit_value numeric(10,2);

alter table public.services drop constraint if exists services_rules_check;
alter table public.services add constraint services_rules_check check (
  (result_months is null or result_months between 1 and 120)
  and (retouch_included_days is null or retouch_included_days between 1 and 365)
  and (
    (deposit_type is null and deposit_value is null)
    or (deposit_type = 'fixed' and deposit_value > 0 and deposit_value <= 100000)
    or (deposit_type = 'percent' and deposit_value > 0 and deposit_value <= 100)
  )
) not valid;
alter table public.services validate constraint services_rules_check;

-- Duração 0 = sem duração. Fora desse caso, os limites de sempre.
alter table public.services drop constraint if exists services_catalog_values_check;
alter table public.services add constraint services_catalog_values_check check (
  btrim(name) <> ''
  and price >= 0
  and price_type in ('free', 'from', 'fixed', 'on_request')
  and (duration_minutes = 0 or duration_minutes between 15 and 480)
  and buffer_minutes between 0 and 120
  and commission_pct between 0 and 100
  and (price_type not in ('free', 'on_request') or price = 0)
) not valid;
alter table public.services validate constraint services_catalog_values_check;

alter table public.services drop constraint if exists services_no_duration_not_online;
alter table public.services add constraint services_no_duration_not_online check (
  duration_minutes > 0 or not online_booking
) not valid;
alter table public.services validate constraint services_no_duration_not_online;

-- ─── 2. Gravar serviço ───────────────────────────────────────────────────────────────────────
-- Mesma função de 20260615174121 (checagem de permissão idêntica), com duração 0 aceita e o
-- parâmetro opcional p_rules: {"result_months": 6, "retouch_included_days": 60,
-- "deposit_type": "fixed" | "percent", "deposit_value": 20}. Chaves ausentes ou nulas limpam a
-- regra; p_rules nulo não mexe nas regras que já existem.

drop function if exists public.upsert_catalog_service_atomic(
  uuid, uuid, uuid, text, text, numeric, text, integer, integer, numeric, boolean, uuid, boolean, boolean, uuid[]
);

create or replace function public.upsert_catalog_service_atomic(
  p_org_id uuid,
  p_service_id uuid,
  p_category_id uuid,
  p_name text,
  p_description text,
  p_price numeric,
  p_price_type text,
  p_duration_minutes integer,
  p_buffer_minutes integer,
  p_commission_pct numeric,
  p_requires_anamnese boolean,
  p_anamnese_template_id uuid,
  p_online_booking boolean,
  p_active boolean,
  p_staff_ids uuid[],
  p_rules jsonb default null
)
returns uuid
language plpgsql
set search_path = 'public'
as $$
declare
  v_service_id uuid;
  v_price numeric(10,2);
  v_online boolean;
  v_rules boolean := p_rules is not null;
  v_result integer;
  v_retouch integer;
  v_deposit_type text;
  v_deposit_value numeric(10,2);
begin
  if not public.has_permission(p_org_id, 'catalogo.manage') then
    raise exception 'catalog permission denied' using errcode = '42501';
  end if;
  if btrim(coalesce(p_name, '')) = ''
     or p_price < 0
     or p_price_type not in ('free', 'from', 'fixed', 'on_request')
     or (p_duration_minutes <> 0 and p_duration_minutes not between 15 and 480)
     or p_buffer_minutes not between 0 and 120
     or p_commission_pct not between 0 and 100 then
    raise exception 'invalid service data' using errcode = '22023';
  end if;
  if p_category_id is not null and not exists (select 1 from public.service_categories where id = p_category_id and org_id = p_org_id) then
    raise exception 'category belongs to another organization' using errcode = '23514';
  end if;
  if p_anamnese_template_id is not null and not exists (select 1 from public.anamnese_templates where id = p_anamnese_template_id and org_id = p_org_id) then
    raise exception 'anamnese template belongs to another organization' using errcode = '23514';
  end if;
  if exists (
    select 1 from unnest(coalesce(p_staff_ids, '{}'::uuid[])) as requested(staff_id)
    where not exists (select 1 from public.staff_members staff where staff.id = requested.staff_id and staff.org_id = p_org_id)
  ) then
    raise exception 'staff member belongs to another organization' using errcode = '23514';
  end if;

  v_price := case when p_price_type in ('free', 'on_request') then 0 else p_price end;
  -- Sem duração não vai para a reserva online.
  v_online := p_online_booking and p_duration_minutes > 0;

  if v_rules then
    v_result := nullif(p_rules ->> 'result_months', '')::integer;
    v_retouch := nullif(p_rules ->> 'retouch_included_days', '')::integer;
    v_deposit_type := nullif(p_rules ->> 'deposit_type', '');
    v_deposit_value := nullif(p_rules ->> 'deposit_value', '')::numeric;
    if v_deposit_type is null then
      v_deposit_value := null;
    end if;
  end if;

  if p_service_id is null then
    insert into public.services (
      org_id, category_id, name, description, price, price_type, cost_amount, duration_minutes, buffer_minutes,
      requires_anamnese, anamnese_template_id, online_booking, commission_pct, position, active,
      result_months, retouch_included_days, deposit_type, deposit_value
    ) values (
      p_org_id, p_category_id, btrim(p_name), nullif(btrim(coalesce(p_description, '')), ''), v_price, p_price_type, 0,
      p_duration_minutes, p_buffer_minutes, p_requires_anamnese, p_anamnese_template_id, v_online, p_commission_pct, 0, p_active,
      v_result, v_retouch, v_deposit_type, v_deposit_value
    ) returning id into v_service_id;
  else
    update public.services set
      category_id = p_category_id,
      name = btrim(p_name),
      description = nullif(btrim(coalesce(p_description, '')), ''),
      price = v_price,
      price_type = p_price_type,
      duration_minutes = p_duration_minutes,
      buffer_minutes = p_buffer_minutes,
      requires_anamnese = p_requires_anamnese,
      anamnese_template_id = p_anamnese_template_id,
      online_booking = v_online,
      commission_pct = p_commission_pct,
      active = p_active,
      result_months = case when v_rules then v_result else result_months end,
      retouch_included_days = case when v_rules then v_retouch else retouch_included_days end,
      deposit_type = case when v_rules then v_deposit_type else deposit_type end,
      deposit_value = case when v_rules then v_deposit_value else deposit_value end
    where id = p_service_id and org_id = p_org_id
    returning id into v_service_id;
    if v_service_id is null then
      raise exception 'service not found' using errcode = 'P0002';
    end if;
  end if;

  perform public.replace_service_staff_atomic(p_org_id, v_service_id, p_staff_ids);
  return v_service_id;
end;
$$;

revoke all on function public.upsert_catalog_service_atomic(
  uuid, uuid, uuid, text, text, numeric, text, integer, integer, numeric, boolean, uuid, boolean, boolean, uuid[], jsonb
) from public, anon;
grant execute on function public.upsert_catalog_service_atomic(
  uuid, uuid, uuid, text, text, numeric, text, integer, integer, numeric, boolean, uuid, boolean, boolean, uuid[], jsonb
) to authenticated;
