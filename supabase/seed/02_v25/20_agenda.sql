-- KA Beauty OS — seed V25, parte: Agenda, fichas, comandas, bloqueios e saldos pelas funções reais. Encoding: UTF-8
-- Incluído por supabase/seed/02_v25_dados_teste.sql (não rodar sozinho).

-- ─── 4. Agenda, fichas e comandas pelas funções reais (como a dona) ───
-- p_final: agendado | confirmado | confirmado_assinada | cancelado | faltou | iniciado | concluido
--          | pago | parcial (p_valor = valor pago) | rascunho (falta a Ficha Profissional)
--          | pacote (vende o pacote Brows Repair) | coberto (usa uma sessão do pacote)
-- A tabela anamneses é fechada para a API (20261114040000): o seed acha a ficha pendente como dono do banco,
-- no papel de "a cliente recebeu o link". O banco guarda só o hash do link (20261114100000): a assinatura usa a mesma
-- regra do link (anamnese_sign_internal, canal "link"), chamada como dono do banco. A Ficha Profissional continua
-- pela função real.
create function pg_temp.fichas_pendentes(p_org uuid, p_appointment uuid)
returns table (id uuid, requires_professional boolean, template_snapshot jsonb, client_name text)
language sql security definer set search_path = '' as $f$
  select an.id, an.requires_professional, an.template_snapshot, an.client_name
  from public.anamneses an where an.org_id = p_org and an.appointment_id = p_appointment and an.status = 'pending'
$f$;
create function pg_temp.assinar(p_id uuid, p_answers jsonb, p_name text)
returns jsonb language sql security definer set search_path = '' as $f$
  select public.anamnese_sign_internal(p_id, 'link', p_answers, p_name,
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
    true, 'Seed V25', null)
$f$;
grant execute on function pg_temp.fichas_pendentes(uuid, uuid), pg_temp.assinar(uuid, jsonb, text) to authenticated;

create function pg_temp.atender(p_chave text, p_cliente int, p_prof text, p_dia int, p_hora text, p_servicos text[],
  p_final text, p_metodo text, p_valor numeric, p_sinal numeric, p_obs text, p_origem text)
returns uuid language plpgsql as $$
declare
  v_org uuid := current_setting('seed.org_id')::uuid;
  v_cliente uuid := pg_temp.cliente(p_cliente);
  v_prof uuid := pg_temp.sid(case p_prof when 'K' then 'prof-karenn' else 'prof-bruna' end);
  v_inicio timestamptz := pg_temp.em(p_dia, p_hora);
  v_itens jsonb; v_comanda jsonb; v_total numeric; v_dur int; v_id uuid; v_pagar numeric; v_ret jsonb;
  v_ficha record;
begin
  select jsonb_agg(jsonb_build_object('service_id', s.id, 'service_name', s.name, 'price', s.price,
           'duration_minutes', s.duration_minutes) order by k.ord),
         jsonb_agg(jsonb_build_object('item_type', 'SERVICE', 'item_id', s.id, 'name', s.name, 'category', c.name,
           'unit_price', s.price, 'quantity', 1, 'total_price', s.price) order by k.ord),
         sum(s.price), sum(s.duration_minutes)
    into v_itens, v_comanda, v_total, v_dur
  from unnest(p_servicos) with ordinality k(chave, ord)
  join public.services s on s.id = pg_temp.sid('servico-' || k.chave) and s.org_id = v_org
  left join public.service_categories c on c.id = s.category_id;
  if coalesce(jsonb_array_length(v_itens), 0) <> cardinality(p_servicos) then
    raise exception 'Serviço desconhecido em %', p_chave;
  end if;

  begin
    v_id := public.create_appointment_atomic(v_org, v_cliente, v_prof, v_inicio, v_inicio + make_interval(mins => v_dur), v_dur,
      case when p_final in ('agendado', 'cancelado') then 'Agendado' else 'Confirmado' end,
      p_origem, p_obs, null, v_total, v_itens, false);
  exception when sqlstate '23P01' then
    raise notice 'Horário ocupado: agendamento % pulado', p_chave;
    return null;
  end;

  if p_sinal > 0 then
    perform public.register_appointment_deposit_atomic(v_org, v_id, p_sinal, 'BIZUM', pg_temp.sid('sinal-' || p_chave));
  end if;

  -- A cliente assina a ficha pelo link; a profissional conclui a parte dela antes de cobrar.
  if p_final in ('confirmado_assinada', 'iniciado', 'concluido', 'pago', 'parcial', 'rascunho', 'pacote', 'coberto') then
    for v_ficha in select * from pg_temp.fichas_pendentes(v_org, v_id) loop
      v_ret := pg_temp.assinar(v_ficha.id, pg_temp.respostas(v_ficha.template_snapshot), v_ficha.client_name);
      if v_ret ? 'error' then raise exception 'Ficha de % não assinada: %', p_chave, v_ret->>'error'; end if;
      if v_ficha.requires_professional and p_final in ('pago', 'parcial', 'pacote', 'coberto') then
        -- 20261114040500: a função antiga saiu da API; a Ficha Profissional grava por anamnese_save_professional.
        perform public.anamnese_save_professional(v_org, v_ficha.id, '{}'::jsonb, '{"photos": []}'::jsonb,
          'Procedimento sem intercorrências.', true);
      end if;
    end loop;
  end if;

  if p_final = 'cancelado' then perform public.set_appointment_status_atomic(v_org, v_id, 'Cancelado'); return v_id; end if;
  if p_final = 'faltou' then perform public.set_appointment_status_atomic(v_org, v_id, 'Ausência'); return v_id; end if;
  if p_final in ('agendado', 'confirmado', 'confirmado_assinada') then return v_id; end if;
  perform public.set_appointment_status_atomic(v_org, v_id, 'Iniciado');
  if p_final = 'iniciado' then return v_id; end if;
  perform public.set_appointment_status_atomic(v_org, v_id, 'Concluído');
  if p_final = 'concluido' then return v_id; end if;

  if p_final = 'pacote' then
    select jsonb_build_array(jsonb_build_object('item_type', 'PACKAGE', 'item_id', p.id, 'name', p.name, 'category', 'Pacote',
             'unit_price', p.price, 'quantity', 1, 'total_price', p.price)), p.price
      into v_comanda, v_total
    from public.service_packages p where p.id = pg_temp.sid('pacote-brows-repair');
  elsif p_final = 'coberto' then
    select jsonb_agg(i || jsonb_build_object('unit_price', 0, 'total_price', 0, 'covered_by_entitlement', true,
             'entitlement_id', (select e.id from public.client_entitlements e where e.org_id = v_org and e.client_id = v_cliente
                                  and e.status = 'active' order by e.created_at limit 1)))
      into v_comanda from jsonb_array_elements(v_comanda) i;
    v_total := 0;
  end if;
  v_pagar := case when p_final = 'parcial' then p_valor else v_total - p_sinal end;
  perform public.confirm_checkout_atomic(v_org, jsonb_build_object(
    'request_id', pg_temp.sid('comanda-' || p_chave), 'appointment_id', v_id,
    'mode', case when p_final = 'rascunho' then 'draft' else 'finalize' end,
    'items', v_comanda, 'discount', 0, 'tip', 0, 'service_fee', 0, 'use_credit', false, 'note', '',
    'payments', case when p_final = 'rascunho' or v_pagar <= 0 then '[]'::jsonb
                     else jsonb_build_array(jsonb_build_object('method', p_metodo, 'amount', v_pagar)) end));
  return v_id;
end $$;
grant execute on function pg_temp.atender(text, int, text, int, text, text[], text, text, numeric, numeric, text, text) to authenticated;

set local role authenticated;
do $$
declare r record; w int; j int;
begin
  for r in select * from (values
    -- Hoje (Karenn = K, Bruna = B)
    ('hoje-ana', 1, 'K', 0, '10:00', '{brows_repair}'::text[], 'coberto', null, null::numeric, 0::numeric, 'Brows Repair · sessão 2 de 3', 'MANUAL'),
    ('hoje-irene', 14, 'K', 0, '12:00', '{microblading}', 'iniciado', null, null, 20, null, 'WHATSAPP'),
    ('hoje-monica', 15, 'K', 0, '16:00', '{diseno_lujo}', 'agendado', null, null, 0, null, 'ONLINE'),
    ('hoje-noelia', 16, 'B', 0, '09:30', '{limpieza_profunda}', 'pago', 'CARD_DEBIT', null, 0, null, 'MANUAL'),
    ('hoje-claudia', 17, 'B', 0, '11:30', '{peeling}', 'pago', 'CASH', null, 0, null, 'PHONE'),
    ('hoje-carla', 18, 'B', 0, '14:00', '{limpieza_express}', 'confirmado', null, null, 0, null, 'WHATSAPP'),
    ('hoje-sofia', 4, 'B', 0, '16:00', '{dermaplaning,hydragloss}', 'confirmado', null, null, 20, null, 'WHATSAPP'),
    -- Semana atual e próxima
    ('sem-rosa', 19, 'K', -1, '10:00', '{shadow}', 'pago', 'CARD_CREDIT', null, 0, null, 'MANUAL'),
    ('sem-marisol', 20, 'K', -1, '15:00', '{laminado}', 'pago', 'CASH', null, 0, null, 'ONLINE'),
    ('sem-irene-s', 28, 'B', -1, '10:00', '{hidratacao}', 'faltou', null, null, 0, null, 'ONLINE'),
    ('sem-noelia-p', 29, 'B', -2, '12:00', '{limpieza_express}', 'cancelado', null, null, 0, null, 'WHATSAPP'),
    ('sem-cristina', 27, 'B', -4, '11:00', '{limpieza_profunda}', 'pago', 'BIZUM', null, 0, null, 'MANUAL'),
    ('sem-irene-s2', 28, 'B', -7, '16:00', '{hidratacao}', 'pago', 'CARD_DEBIT', null, 0, null, 'MANUAL'),
    ('sem-noelia-p2', 29, 'B', -11, '16:00', '{limpieza_express}', 'pago', 'CASH', null, 0, null, 'PHONE'),
    ('sem-sara', 30, 'B', -12, '15:00', '{dermaplaning}', 'pago', 'CARD_DEBIT', null, 0, null, 'MANUAL'),
    ('fut-vera', 21, 'K', 1, '10:00', '{lip_blush}', 'confirmado', null, null, 0, null, 'WHATSAPP'),
    ('fut-tania', 22, 'K', 1, '14:30', '{henna}', 'agendado', null, null, 0, null, 'ONLINE'),
    ('fut-lucia', 2, 'B', 1, '10:30', '{limpieza_profunda}', 'confirmado', null, null, 0, null, 'WHATSAPP'),
    ('fut-carmen', 10, 'K', 2, '12:30', '{aquarele}', 'confirmado', null, null, 0, 'Primeira visita', 'PHONE'),
    ('fut-alicia', 23, 'K', 2, '16:00', '{depilacao}', 'confirmado', null, null, 0, null, 'ONLINE'),
    ('fut-nuria', 13, 'B', 2, '12:00', '{hidratacao}', 'agendado', null, null, 0, null, 'ONLINE'),
    ('fut-lola', 24, 'K', 3, '16:30', '{diseno_basico}', 'confirmado', null, null, 0, null, 'WHATSAPP'),
    ('fut-amparo', 25, 'K', 3, '17:15', '{laminado}', 'agendado', null, null, 0, null, 'ONLINE'),
    ('fut-sara', 30, 'B', 3, '15:00', '{dermaplaning}', 'confirmado_assinada', null, null, 0, null, 'WHATSAPP'),
    ('fut-teresa', 26, 'K', 4, '10:00', '{microblading}', 'confirmado_assinada', null, null, 0, null, 'MANUAL'),
    ('fut-julia', 5, 'B', 4, '10:00', '{limpieza_express}', 'confirmado', null, null, 0, null, 'WHATSAPP'),
    ('fut-laura', 12, 'K', 5, '13:00', '{hydragloss}', 'cancelado', null, null, 0, null, 'ONLINE'),
    ('fut-elena', 3, 'K', 6, '09:30', '{diseno_lujo}', 'confirmado', null, null, 0, null, 'WHATSAPP'),
    ('fut-cristina', 27, 'B', 7, '17:00', '{limpieza_profunda}', 'agendado', null, null, 0, null, 'ONLINE'),
    ('fut-rocio', 11, 'K', 8, '11:30', '{retoque_anual}', 'agendado', null, null, 0, null, 'PHONE'),
    ('fut-sofia', 4, 'K', 10, '16:00', '{shadow}', 'agendado', null, null, 0, 'Shadow · retoque incluído', 'WHATSAPP'),
    ('fut-ana', 1, 'K', 14, '11:00', '{brows_repair}', 'agendado', null, null, 0, 'Brows Repair · sessão 3 de 3', 'MANUAL'),
    -- Histórico das clientes dos mockups
    ('hist-lucia-peeling', 2, 'B', -6, '10:30', '{peeling}', 'rascunho', null, null, 0, null, 'WHATSAPP'),
    ('hist-elena-diseno', 3, 'K', -8, '09:30', '{diseno_lujo}', 'pago', 'CARD_DEBIT', null, 0, null, 'WHATSAPP'),
    ('hist-elena-retoque', 3, 'K', -8, '10:30', '{retoque_anual}', 'pago', 'CARD_DEBIT', null, 0, null, 'WHATSAPP'),
    ('hist-sofia-hidrat', 4, 'B', -18, '16:00', '{hidratacao}', 'pago', 'CASH', null, 0, null, 'MANUAL'),
    ('hist-julia-derma', 5, 'B', -24, '11:00', '{dermaplaning}', 'rascunho', null, null, 0, null, 'MANUAL'),
    ('hist-lucia-1', 2, 'B', -27, '11:00', '{limpieza_profunda}', 'pago', 'CARD_DEBIT', null, 0, null, 'WHATSAPP'),
    ('hist-elena-2', 3, 'K', -36, '09:30', '{diseno_lujo}', 'pago', 'CARD_DEBIT', null, 0, null, 'WHATSAPP'),
    ('hist-sofia-2', 4, 'B', -39, '16:00', '{hidratacao}', 'pago', 'BIZUM', null, 0, null, 'WHATSAPP'),
    ('hist-ana-pacote', 1, 'K', -41, '10:00', '{brows_repair}', 'pacote', 'CARD_DEBIT', null, 0, 'Brows Repair · sessão 1 de 3', 'MANUAL'),
    ('hist-julia-2', 5, 'B', -45, '15:00', '{limpieza_express}', 'pago', 'CASH', null, 0, null, 'ONLINE'),
    ('hist-paula', 6, 'K', -46, '15:00', '{microblading}', 'pago', 'TRANSFER', null, 0, null, 'MANUAL'),
    ('hist-lucia-2', 2, 'B', -48, '11:00', '{limpieza_profunda}', 'pago', 'CARD_DEBIT', null, 0, null, 'WHATSAPP'),
    ('hist-marina', 7, 'K', -55, '14:00', '{shadow}', 'parcial', 'CARD_CREDIT', 195, 0, null, 'MANUAL'),
    ('hist-sofia-shadow', 4, 'K', -60, '10:00', '{shadow}', 'pago', 'CARD_CREDIT', null, 0, null, 'MANUAL'),
    ('hist-ana-basico', 1, 'K', -62, '12:00', '{diseno_basico}', 'pago', 'CASH', null, 0, null, 'MANUAL'),
    ('hist-elena-3', 3, 'K', -64, '09:30', '{diseno_lujo}', 'pago', 'CARD_DEBIT', null, 0, null, 'WHATSAPP'),
    ('hist-julia-3', 5, 'B', -66, '15:00', '{limpieza_express}', 'pago', 'BIZUM', null, 0, null, 'ONLINE'),
    ('hist-lucia-3', 2, 'B', -69, '11:00', '{limpieza_profunda}', 'pago', 'CARD_DEBIT', null, 0, null, 'WHATSAPP'),
    ('hist-marta-gloss', 8, 'K', -74, '10:00', '{hydragloss}', 'pago', 'CASH', null, 0, null, 'MANUAL'),
    ('hist-marta-lips', 8, 'K', -74, '11:00', '{lip_blush}', 'pago', 'CARD_DEBIT', null, 0, null, 'MANUAL'),
    ('hist-beatriz-basico', 9, 'K', -97, '12:00', '{diseno_basico}', 'pago', 'CARD_DEBIT', null, 0, null, 'ONLINE'),
    ('hist-beatriz-derma', 9, 'B', -97, '15:00', '{dermaplaning}', 'pago', 'CARD_DEBIT', null, 0, null, 'ONLINE')
  ) plano(chave, cliente, prof, dia, hora, servicos, final, metodo, valor, sinal, obs, origem)
  order by dia, hora loop -- o pacote de Ana é vendido antes da sessão de hoje que o usa
    perform pg_temp.atender(r.chave, r.cliente, r.prof, r.dia, r.hora, r.servicos, r.final, r.metodo, r.valor, r.sinal, r.obs, r.origem);
  end loop;

  -- 12 semanas de movimento: 2 atendimentos por semana para cada profissional, no fim do dia.
  for w in 2..12 loop
    for j in 0..3 loop
      perform pg_temp.atender(format('hist-s%s-%s', w, j), 11 + (w * 4 + j) % 20, case when j % 2 = 0 then 'K' else 'B' end,
        -(7 * w) + 1 + j, case when j % 2 = 0 then '17:30' else '17:45' end,
        array[case when j % 2 = 0
          then (array['diseno_lujo','laminado','henna','diseno_basico','hydragloss','depilacao'])[1 + (w + j) % 6]
          else (array['limpieza_profunda','hidratacao','limpieza_express'])[1 + (w + j) % 3] end],
        'pago', (array['CARD_DEBIT','CASH','BIZUM','CARD_CREDIT'])[1 + (w * 3 + j) % 4], null, 0, null,
        (array['MANUAL','WHATSAPP','ONLINE','PHONE'])[1 + (w + j) % 4]);
    end loop;
  end loop;
end $$;

-- Bloqueios de horário (almoço de hoje) e uma formação na semana que vem.
do $$
declare
  v_org uuid := current_setting('seed.org_id')::uuid;
  r record;
begin
  for r in select * from (values
    ('prof-karenn', 'Almoço', 'Almoço', 0, '14:30', '15:30'),
    ('prof-bruna', 'Almoço', 'Almoço', 0, '12:30', '13:30'),
    ('prof-karenn', 'Formação', 'Curso de pigmentação', 9, '09:00', '11:00')
  ) b(prof, tipo, titulo, dia, ini, fim) loop
    begin
      perform public.create_time_blocks_atomic(v_org, pg_temp.sid(r.prof),
        (select id from public.time_block_types where org_id = v_org and name = r.tipo and active),
        r.titulo, null, false, 'none', 1,
        jsonb_build_array(jsonb_build_object('start_at', pg_temp.em(r.dia, r.ini), 'end_at', pg_temp.em(r.dia, r.fim))));
    exception when sqlstate '23P01' then
      raise notice 'Bloqueio % de % pulado: horário ocupado', r.titulo, r.prof;
    end;
  end loop;

  -- Saldos a favor (crédito deixado no estúdio). Marina fica com −35 € pela comanda parcial.
  perform public.adjust_client_balance_atomic(v_org, pg_temp.cliente(1), 'credit', 50, 'Pagamento antecipado', pg_temp.sid('saldo-01'));
  perform public.adjust_client_balance_atomic(v_org, pg_temp.cliente(4), 'credit', 20, 'Troco deixado como crédito', pg_temp.sid('saldo-04'));
  perform public.adjust_client_balance_atomic(v_org, pg_temp.cliente(5), 'credit', 15, 'Troco deixado como crédito', pg_temp.sid('saldo-05'));

  -- Ficha avulsa enviada a Paula Ortega (retoque sem data); o link vence abaixo.
  perform public.create_anamnese_atomic(v_org, pg_temp.sid('modelo-cejas'), pg_temp.cliente(6), null, null, null);
end $$;
reset role;
