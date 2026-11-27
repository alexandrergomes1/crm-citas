-- KA Beauty OS — seed V25, parte: Datas do histórico. Encoding: UTF-8
-- Incluído por supabase/seed/02_v25_dados_teste.sql (não rodar sozinho).

-- ─── 7. Datas do histórico ───────────────────────────────────
-- As funções gravam "agora"; aqui cada registro volta para o dia do atendimento.
do $$
declare
  v_org uuid := current_setting('seed.org_id')::uuid;
  v_tz text := pg_temp.tz();
  v_clientes uuid[] := array(select pg_temp.cliente(n) from generate_series(1, 30) n);
  v_livre boolean := true;
  r record;
  v_pago timestamptz;
  v_venda uuid;
begin
  begin
    perform set_config('session_replication_role', 'replica', true);
  exception when insufficient_privilege then
    v_livre := false;
    raise notice 'Sem session_replication_role: fichas assinadas ficam com a data de hoje';
  end;
  for r in select a.id, a.start_at, a.end_at from public.appointments a where a.org_id = v_org and a.client_id = any(v_clientes) loop
    v_pago := least(now(), r.end_at + interval '10 minutes');
    update public.appointments set created_at = least(now(), r.start_at - interval '5 days'), updated_at = least(now(), greatest(r.end_at, now() - interval '1 day'))
     where id = r.id;
    update public.appointment_status_history set created_at = least(now(), case
        when notes = 'appointment_created' then r.start_at - interval '5 days'
        when status = 'Cancelado' then r.start_at - interval '1 day'
        when status = 'Iniciado' then r.start_at
        when status in ('Concluído', 'Ausência') then r.end_at
        else r.end_at + interval '10 minutes' end)
     where appointment_id = r.id;
    update public.appointment_deposits set created_at = least(now(), r.start_at - interval '2 days'), updated_at = least(now(), r.start_at - interval '2 days')
     where appointment_id = r.id;
    update public.transactions t set created_at = d.created_at, date = (d.created_at at time zone v_tz)::date
      from public.appointment_deposits d where d.appointment_id = r.id and t.id = d.transaction_id;
    select id into v_venda from public.sales where org_id = v_org and appointment_id = r.id;
    if v_venda is not null then
      update public.sales set created_at = v_pago, updated_at = v_pago where id = v_venda;
      update public.sale_payments set created_at = v_pago where sale_id = v_venda;
      update public.transactions set created_at = v_pago, date = (v_pago at time zone v_tz)::date where sale_id = v_venda;
      update public.client_balance_entries set created_at = v_pago where sale_id = v_venda;
      update public.loyalty_point_entries set created_at = v_pago where source_id = v_venda;
      update public.client_entitlements set purchased_at = v_pago, created_at = v_pago, updated_at = v_pago,
             expires_at = v_pago + interval '180 days' where sale_id = v_venda;
      update public.checkout_requests set created_at = v_pago where appointment_id = r.id;
    end if;
    update public.client_entitlement_entries set created_at = v_pago where appointment_id = r.id;
    update public.anamneses set
        created_at = least(now(), r.start_at - interval '3 days'),
        token_expires_at = case when status = 'signed' then least(now(), r.start_at - interval '3 days') + interval '7 days' else token_expires_at end,
        signed_at = case when signed_at is not null then least(now(), r.start_at - interval '1 day') end,
        professional_completed_at = case when professional_completed_at is not null then least(now(), r.end_at) end,
        updated_at = least(now(), greatest(r.end_at, r.start_at - interval '1 day'))
     where appointment_id = r.id and (v_livre or status <> 'signed');
  end loop;

  -- Link de Paula Ortega enviado há 17 dias, vencido há 10.
  update public.anamneses set created_at = now() - interval '17 days', updated_at = now() - interval '17 days',
         token_expires_at = now() - interval '10 days'
   where org_id = v_org and client_id = pg_temp.cliente(6) and appointment_id is null and status = 'pending';

  -- Créditos lançados há duas semanas.
  update public.client_balance_entries set created_at = now() - interval '14 days'
   where org_id = v_org and idempotency_key in (pg_temp.sid('saldo-01'), pg_temp.sid('saldo-04'), pg_temp.sid('saldo-05'));
  update public.transactions t set created_at = e.created_at, date = (e.created_at at time zone v_tz)::date
    from public.client_balance_entries e where e.transaction_id = t.id and e.org_id = v_org
     and e.idempotency_key in (pg_temp.sid('saldo-01'), pg_temp.sid('saldo-04'), pg_temp.sid('saldo-05'));

  -- Clientes: cadastro antes da primeira visita; última visita = último atendimento feito.
  update public.clients c set
      created_at = coalesce(x.primeira - interval '20 days', c.created_at),
      last_visit = x.ultima
    from (select client_id, min(start_at) as primeira,
                 max((start_at at time zone v_tz)::date) filter (where status in ('Concluído', 'Pago', 'Pago Parcial') and start_at <= now()) as ultima
          from public.appointments where org_id = v_org and client_id = any(v_clientes) group by client_id) x
   where c.id = x.client_id;
  update public.clients set created_at = now() - interval '3 days' where id = pg_temp.cliente(10);
  if v_livre then perform set_config('session_replication_role', 'origin', true); end if;
end $$;
