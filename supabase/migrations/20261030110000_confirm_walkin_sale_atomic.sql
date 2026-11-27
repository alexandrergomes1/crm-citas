-- Venda avulsa atômica: atendimento + itens + venda + pagamentos + caixa numa transação só.
-- Encoding: UTF-8
--
-- Antes o app criava um atendimento "Concluído" (create_appointment_atomic, que exige
-- agenda.manage e horário livre da profissional) e só depois cobrava (confirm_checkout_atomic).
-- Se o pagamento falhasse, sobrava um atendimento Concluído órfão que conta como visita.
-- Agora confirm_walkin_sale_atomic faz tudo de uma vez:
--   * permissão comanda.operate (não exige agenda.manage);
--   * não confere conflito de horário (venda avulsa não ocupa agenda);
--   * qualquer falha (vale inválido, ficha pendente, estoque, pacote) desfaz o atendimento também;
--   * idempotente por request_id: repetir a chamada devolve a mesma venda, sem segundo atendimento.
-- O pagamento em si é o confirm_checkout_atomic, chamado na mesma transação, então as regras
-- de itens, sinal, crédito, vale, pacote, estoque, pontos e saldo são exatamente as da comanda.
--
-- Aditiva: função nova; nada que o app antigo usa muda.
set client_encoding = 'UTF8';

create or replace function public.confirm_walkin_sale_atomic(p_org_id uuid, p_command jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_request_id uuid;
  v_client_id uuid;
  v_staff_id uuid;
  v_client public.clients;
  v_saved public.checkout_requests;
  v_items jsonb := coalesce(p_command->'items', '[]'::jsonb);
  v_mode text := coalesce(p_command->>'mode', 'finalize');
  v_base jsonb;
  v_inner jsonb;
  v_result jsonb;
  v_appointment_id uuid;
  v_minutes integer;
  v_total numeric(12,2);
  v_end timestamptz := pg_catalog.now();
  v_invalid boolean;
  v_sale_number integer;
  r_item record;
begin
  if v_user_id is null then
    raise exception 'Sessão expirada' using errcode = '42501';
  end if;
  if not public.has_permission(p_org_id, 'comanda.operate') then
    raise exception 'Sem permissão para registrar vendas' using errcode = '42501';
  end if;

  begin
    v_request_id := (p_command->>'request_id')::uuid;
    v_client_id := (p_command->>'client_id')::uuid;
    v_staff_id := nullif(p_command->>'staff_id', '')::uuid;
  exception when invalid_text_representation then
    raise exception 'Identificador inválido' using errcode = '22023';
  end;
  if v_request_id is null or v_client_id is null then
    raise exception 'Escolha a cliente da venda' using errcode = '22023';
  end if;
  if v_mode not in ('finalize', 'draft') then
    raise exception 'Modo de checkout inválido' using errcode = '22023';
  end if;

  -- Duas chamadas com a mesma chave esperam uma pela outra: a segunda já encontra a venda.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_org_id::text || ':walkin:' || v_request_id::text, 0)
  );

  -- Comando enviado ao checkout: o mesmo, sem cliente e profissional, com o atendimento criado.
  v_base := p_command - 'client_id' - 'staff_id';

  select * into v_saved
  from public.checkout_requests
  where org_id = p_org_id and request_id = v_request_id;
  if found then
    if pg_catalog.md5((v_base || pg_catalog.jsonb_build_object('appointment_id', v_saved.appointment_id))::text)
       is distinct from v_saved.payload_hash then
      raise exception 'Chave idempotente reutilizada com dados diferentes' using errcode = '22023';
    end if;
    if v_saved.result is null then
      raise exception 'Venda em processamento; tente novamente' using errcode = '40001';
    end if;
    return v_saved.result || pg_catalog.jsonb_build_object(
      'appointmentId', v_saved.appointment_id,
      'saleNumber', (select s.number from public.sales s
        where s.id = (v_saved.result->>'saleId')::uuid and s.org_id = p_org_id),
      'duplicate', true
    );
  end if;

  if pg_catalog.jsonb_typeof(v_items) <> 'array' or pg_catalog.jsonb_array_length(v_items) = 0 then
    raise exception 'Adicione pelo menos um item à comanda' using errcode = '22023';
  end if;
  select exists (
    select 1
    from pg_catalog.jsonb_array_elements(v_items) item
    where coalesce(item->>'name', '') = ''
      or coalesce((item->>'quantity')::integer, 0) < 1
      or coalesce((item->>'unit_price')::numeric, -1) < 0
      or upper(coalesce(item->>'item_type', '')) not in ('SERVICE', 'PRODUCT', 'PACKAGE')
      or coalesce(nullif(item->>'duration_minutes', '')::integer, 15) not between 5 and 720
  ) into v_invalid;
  if v_invalid then
    raise exception 'Item de comanda inválido' using errcode = '22023';
  end if;

  select * into v_client
  from public.clients c
  where c.id = v_client_id and c.org_id = p_org_id
  for share;
  if not found then
    raise exception 'Cliente não encontrada neste estúdio' using errcode = 'P0002';
  end if;
  if v_staff_id is not null and not exists (
    select 1 from public.staff_members sm
    where sm.id = v_staff_id and sm.org_id = p_org_id and sm.active = true
  ) then
    raise exception 'Profissional inválida' using errcode = '22023';
  end if;
  if exists (
    select 1
    from pg_catalog.jsonb_array_elements(v_items) item
    where upper(item->>'item_type') = 'SERVICE'
      and nullif(item->>'item_id', '') is not null
      and not exists (
        select 1 from public.services s
        where s.id = (item->>'item_id')::uuid and s.org_id = p_org_id
      )
  ) then
    raise exception 'Serviço não pertence a este estúdio' using errcode = '22023';
  end if;

  -- Atendimento da venda: serviços da comanda, terminando agora. Não passa pela checagem de
  -- horário livre. O gatilho de inserção só aceita status inicial de agenda, então nasce
  -- Agendado e vira Concluído logo em seguida (o checkout o leva a Pago ou Pago Parcial).
  select coalesce(sum(coalesce(nullif(item->>'duration_minutes', '')::integer, 15) * (item->>'quantity')::integer), 0),
         coalesce(sum((item->>'unit_price')::numeric * (item->>'quantity')::integer), 0)
    into v_minutes, v_total
  from pg_catalog.jsonb_array_elements(v_items) item
  where upper(item->>'item_type') = 'SERVICE';
  v_minutes := least(1440, greatest(15, v_minutes));

  insert into public.appointments (
    org_id, client_id, client_name, staff_id, start_at, end_at, duration_minutes,
    status, source, internal_notes, total, discount, tip
  ) values (
    p_org_id, v_client.id, v_client.full_name, v_staff_id,
    v_end - pg_catalog.make_interval(mins => v_minutes), v_end, v_minutes,
    'Agendado', 'MANUAL', 'Venda avulsa', pg_catalog.round(v_total, 2), 0, 0
  )
  returning id into v_appointment_id;

  for r_item in
    select item
    from pg_catalog.jsonb_array_elements(v_items) item
    where upper(item->>'item_type') = 'SERVICE'
  loop
    insert into public.appointment_items (
      org_id, appointment_id, type, ref_id, name, price, cost_amount, qty, discount,
      commission_pct, professional_id, duration_minutes
    ) values (
      p_org_id, v_appointment_id, 'service', nullif(r_item.item->>'item_id', '')::uuid,
      r_item.item->>'name', pg_catalog.round((r_item.item->>'unit_price')::numeric, 2), 0,
      (r_item.item->>'quantity')::integer, 0, 0, v_staff_id,
      nullif(r_item.item->>'duration_minutes', '')::integer
    );
  end loop;

  insert into public.appointment_status_history (org_id, appointment_id, status, changed_by, notes)
  values (p_org_id, v_appointment_id, 'Agendado', v_user_id, 'walkin_sale_created');

  update public.appointments set status = 'Concluído'
  where id = v_appointment_id and org_id = p_org_id;
  insert into public.appointment_status_history (org_id, appointment_id, status, changed_by, notes)
  values (p_org_id, v_appointment_id, 'Concluído', v_user_id, 'Venda avulsa');

  -- Cobrança: mesma função da comanda de agendamento, na mesma transação.
  v_inner := v_base || pg_catalog.jsonb_build_object('appointment_id', v_appointment_id);
  v_result := public.confirm_checkout_atomic(p_org_id, v_inner);

  select s.number into v_sale_number
  from public.sales s
  where s.id = (v_result->>'saleId')::uuid and s.org_id = p_org_id;

  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
  values (
    p_org_id, v_user_id, 'appointments', 'WALKIN_SALE', v_appointment_id,
    pg_catalog.jsonb_build_object(
      'request_id', v_request_id, 'client_id', v_client.id, 'sale_id', v_result->>'saleId',
      'mode', v_mode, 'status', v_result->>'status'
    )
  );

  return v_result || pg_catalog.jsonb_build_object(
    'appointmentId', v_appointment_id,
    'saleNumber', v_sale_number
  );
end;
$$;

revoke all on function public.confirm_walkin_sale_atomic(uuid, jsonb) from public, anon;
grant execute on function public.confirm_walkin_sale_atomic(uuid, jsonb) to authenticated;
