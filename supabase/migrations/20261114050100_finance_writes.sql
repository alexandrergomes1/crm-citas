-- Financeiro: gravações em UMA ida ao banco cada (porte para o TanStack Start, orçamento de chamadas).
-- Reaproveita as funções de dinheiro que já funcionam (confirm_checkout_atomic, pay_payable_atomic, caixa,
-- estornos, comissões): aqui só ficam os envoltórios que juntam o que o app fazia em várias idas.
--   * finance_create_entry: lançamento manual (antes: INSERT direto pela API), com chave do pedido.
--   * finance_save_payable / finance_pay_payable / finance_delete_payable: contas a pagar, com a próxima conta
--     da recorrência criada na MESMA transação do pagamento (antes: 3 a 5 idas, sem tudo-ou-nada).
--   * finance_set_payable_invoice / finance_payable_invoice_path: fatura anexada (o arquivo vai ao armazenamento
--     pelo app; aqui só o caminho, conferido contra o estúdio e a conta).
--   * checkout_confirm: confere a Ficha Profissional e cobra numa ida (antes: gate + cobrança + 2 leituras);
--     repetição pela chave do pedido devolve duplicate (checkout_request_done).
--   * finance_record_export: registra a exportação CSV (quem, o quê, quantas linhas) depois de conferir a permissão.
-- Auditoria nova por gatilho (finance_audit_row) em contas a pagar, lançamentos sem venda e vales-presente: grava
-- para QUALQUER caminho (estas funções, as antigas, a API direta), com auth.uid() e só valores e situação (nunca
-- nome de cliente, descrição livre ou código de vale). A política audit_insert_member não é tocada.
-- Encoding: UTF-8
set client_encoding = 'UTF8';

-- ─── Chave do pedido (idempotência na criação) ─────────────────────────────────────────────────────
-- Lançamento manual e conta nova levam a chave do pedido (gerada pela tela por envio) e a assinatura dos dados
-- (md5 dos campos, como checkout_requests.payload_hash): repetir o mesmo envio (duplo clique, rede que reenviou)
-- devolve o registro já criado com duplicate, sem gravar de novo; a mesma chave com outros dados é recusada.
alter table public.transactions add column if not exists request_id uuid;
alter table public.transactions add column if not exists request_hash text;
alter table public.payables add column if not exists request_id uuid;
alter table public.payables add column if not exists request_hash text;
create unique index if not exists transactions_org_request_key on public.transactions (org_id, request_id) where request_id is not null;
create unique index if not exists payables_org_request_key on public.payables (org_id, request_id) where request_id is not null;

-- Registro já criado com esta chave: só o id e a assinatura. SECURITY DEFINER porque quem lança (financeiro.manage)
-- pode não ter financeiro.view (a RLS de leitura esconderia o registro e a repetição viraria erro): confere o
-- estúdio e financeiro.manage antes e não devolve mais nada do registro.
create or replace function public.finance_request_existing(p_org_id uuid, p_kind text, p_request_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or p_org_id is null or p_org_id not in (select public.auth_org_ids())
     or not public.has_permission(p_org_id, 'financeiro.manage') then
    raise exception 'Sem permissão' using errcode = '42501';
  end if;
  if p_kind = 'entry' then
    return (select pg_catalog.jsonb_build_object('id', t.id, 'hash', t.request_hash)
            from public.transactions t where t.org_id = p_org_id and t.request_id = p_request_id);
  elsif p_kind = 'payable' then
    return (select pg_catalog.jsonb_build_object('id', p.id, 'hash', p.request_hash)
            from public.payables p where p.org_id = p_org_id and p.request_id = p_request_id);
  end if;
  raise exception 'Tipo inválido' using errcode = '22023';
end;
$$;

-- ─── Lançamento manual (visão geral › Novo lançamento) ─────────────────────────────────────────────
create or replace function public.finance_create_entry(
  p_org_id uuid, p_type text, p_description text, p_value numeric, p_date date,
  p_method text, p_category text, p_party text, p_request_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_id uuid := pg_catalog.gen_random_uuid();
  v_value numeric := pg_catalog.round(p_value, 2);
  v_hash text;
  v_existing jsonb;
begin
  if (select auth.uid()) is null then
    raise exception 'Sessão expirada' using errcode = '42501';
  end if;
  if not public.has_permission(p_org_id, 'financeiro.manage') then
    raise exception 'Sem permissão para lançar no caixa' using errcode = '42501';
  end if;
  if p_request_id is null then
    raise exception 'Pedido sem chave' using errcode = '22023';
  end if;
  v_hash := pg_catalog.md5(pg_catalog.jsonb_build_array(
    p_type, pg_catalog.btrim(coalesce(p_description, '')), v_value, p_date, nullif(pg_catalog.btrim(coalesce(p_method, '')), ''),
    nullif(pg_catalog.btrim(coalesce(p_category, '')), ''), nullif(pg_catalog.btrim(coalesce(p_party, '')), ''))::text);
  v_existing := public.finance_request_existing(p_org_id, 'entry', p_request_id);
  if v_existing is not null then
    if v_existing ->> 'hash' is distinct from v_hash then
      raise exception 'Chave reutilizada com dados diferentes' using errcode = '22023';
    end if;
    return pg_catalog.jsonb_build_object('id', v_existing ->> 'id', 'duplicate', true);
  end if;
  if p_type is null or p_type not in ('income', 'expense') then
    raise exception 'Tipo de lançamento inválido' using errcode = '22023';
  end if;
  if p_description is null or pg_catalog.char_length(pg_catalog.btrim(p_description)) = 0
     or pg_catalog.char_length(p_description) > 200 then
    raise exception 'Escreva a descrição (até 200 letras)' using errcode = '22023';
  end if;
  -- Arredonda antes de conferir: 0,004 vira 0,00 e é recusado.
  if v_value is null or v_value <= 0 or v_value > 1000000 then
    raise exception 'Informe um valor maior que zero' using errcode = '22023';
  end if;
  if p_date is null or p_date < date '2000-01-01' or p_date > date '2100-12-31' then
    raise exception 'Data inválida' using errcode = '22023';
  end if;
  if pg_catalog.char_length(coalesce(p_method, '')) > 40 or pg_catalog.char_length(coalesce(p_category, '')) > 60
     or pg_catalog.char_length(coalesce(p_party, '')) > 120 then
    raise exception 'Dados longos demais' using errcode = '22023';
  end if;
  if pg_catalog.lower(pg_catalog.btrim(coalesce(p_category, ''))) = 'ajuste_saldo' then
    raise exception 'Categoria reservada para ajustes de saldo da cliente' using errcode = '22023';
  end if;

  -- Sem RETURNING nem ON CONFLICT: os dois aplicam a RLS de leitura à linha nova, e quem lança sem financeiro.view
  -- não a leria. A corrida com o mesmo envio cai na chave única e vira repetição.
  begin
    insert into public.transactions (id, org_id, type, description, value, date, method, category, client_name,
                                     status, sale_id, client_id, created_by, request_id, request_hash)
    values (v_id, p_org_id, p_type, pg_catalog.btrim(p_description), v_value, p_date,
            nullif(pg_catalog.btrim(coalesce(p_method, '')), ''), nullif(pg_catalog.btrim(coalesce(p_category, '')), ''),
            nullif(pg_catalog.btrim(coalesce(p_party, '')), ''), 'completed', null, null, (select auth.uid()), p_request_id, v_hash);
  exception when unique_violation then
    v_existing := public.finance_request_existing(p_org_id, 'entry', p_request_id);
    if v_existing is null or v_existing ->> 'hash' is distinct from v_hash then
      raise exception 'Chave reutilizada com dados diferentes' using errcode = '22023';
    end if;
    return pg_catalog.jsonb_build_object('id', v_existing ->> 'id', 'duplicate', true);
  end;
  return pg_catalog.jsonb_build_object('id', v_id, 'duplicate', false);
end;
$$;

-- ─── Contas a pagar ───────────────────────────────────────────────────────────────────────────────

-- Pagar: trava a conta; repetir com o mesmo valor e data devolve duplicate (duplo clique, duas abas).
-- Conta que se repete ganha a próxima (mesmos dados, vencimento seguinte), uma só vez: a próxima leva a chave de
-- origem "recurrence:<conta paga>" (única por estúdio), então nunca nasce duas vezes da mesma conta.
create or replace function public.finance_pay_payable(p_org_id uuid, p_payable_id uuid, p_paid_value numeric, p_paid_date date)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_p public.payables;
  v_value numeric := pg_catalog.round(p_paid_value, 2);
  v_tx uuid;
  v_next date;
  v_next_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Sessão expirada' using errcode = '42501';
  end if;
  if not public.has_permission(p_org_id, 'financeiro.manage') then
    raise exception 'Sem permissão para pagar contas' using errcode = '42501';
  end if;
  if v_value is null or v_value <= 0 or v_value > 1000000 then
    raise exception 'Valor pago inválido' using errcode = '22023';
  end if;
  select * into v_p from public.payables p where p.id = p_payable_id and p.org_id = p_org_id for update;
  if v_p.id is null then
    raise exception 'Conta não encontrada' using errcode = 'P0002';
  end if;
  if v_p.status = 'paid' then
    if v_p.paid_value = v_value and v_p.paid_date = p_paid_date then
      return pg_catalog.jsonb_build_object('duplicate', true);
    end if;
    raise exception 'Esta conta já foi paga' using errcode = 'P0001';
  end if;

  v_tx := public.pay_payable_atomic(p_org_id, p_payable_id, v_value, p_paid_date);

  if v_p.recurrence in ('weekly', 'monthly', 'yearly') then
    -- Mês e ano no calendário: 31/jan + 1 mês = 28 (ou 29)/fev; 29/fev + 1 ano = 28/fev (igual a nextRecurrenceDate).
    v_next := case v_p.recurrence
      when 'weekly' then v_p.due_date + 7
      when 'monthly' then (v_p.due_date + interval '1 month')::date
      else (v_p.due_date + interval '1 year')::date end;
    insert into public.payables (org_id, description, vendor, category, value, due_date, recurrence, notes, status,
                                 created_by, source_key)
    values (p_org_id, v_p.description, v_p.vendor, v_p.category, v_p.value, v_next, v_p.recurrence, v_p.notes,
            'pending', (select auth.uid()), 'recurrence:' || v_p.id::text)
    on conflict (org_id, source_key) where source_key is not null do nothing
    returning id into v_next_id;
  end if;
  return pg_catalog.jsonb_build_object('duplicate', false, 'transaction_id', v_tx, 'next_id', v_next_id);
end;
$$;

-- Criar ou editar (conta paga não muda); "já paga" paga na mesma transação, com a data de hoje no fuso do estúdio.
-- Conta nova leva a chave do pedido: repetir o mesmo envio devolve a conta já criada com duplicate.
create or replace function public.finance_save_payable(
  p_org_id uuid, p_payable_id uuid, p_description text, p_vendor text, p_category text, p_value numeric,
  p_due_date date, p_recurrence text, p_notes text, p_paid_now boolean, p_request_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_id uuid := p_payable_id;
  v_status text;
  v_value numeric := pg_catalog.round(p_value, 2);
  v_recurrence text := case when p_recurrence in ('weekly', 'monthly', 'yearly') then p_recurrence end;
  v_today date;
  v_hash text;
  v_existing jsonb;
begin
  if (select auth.uid()) is null then
    raise exception 'Sessão expirada' using errcode = '42501';
  end if;
  if not public.has_permission(p_org_id, 'financeiro.manage') then
    raise exception 'Sem permissão para editar contas a pagar' using errcode = '42501';
  end if;
  if v_id is null then
    if p_request_id is null then
      raise exception 'Pedido sem chave' using errcode = '22023';
    end if;
    v_hash := pg_catalog.md5(pg_catalog.jsonb_build_array(
      pg_catalog.btrim(coalesce(p_description, '')), nullif(pg_catalog.btrim(coalesce(p_vendor, '')), ''),
      nullif(pg_catalog.btrim(coalesce(p_category, '')), ''), v_value, p_due_date, v_recurrence,
      nullif(pg_catalog.btrim(coalesce(p_notes, '')), ''), coalesce(p_paid_now, false))::text);
    v_existing := public.finance_request_existing(p_org_id, 'payable', p_request_id);
    if v_existing is not null then
      if v_existing ->> 'hash' is distinct from v_hash then
        raise exception 'Chave reutilizada com dados diferentes' using errcode = '22023';
      end if;
      return pg_catalog.jsonb_build_object('id', v_existing ->> 'id', 'duplicate', true);
    end if;
  end if;
  if p_description is null or pg_catalog.char_length(pg_catalog.btrim(p_description)) = 0
     or pg_catalog.char_length(p_description) > 200 then
    raise exception 'Escreva a descrição (até 200 letras)' using errcode = '22023';
  end if;
  if v_value is null or v_value <= 0 or v_value > 1000000 then
    raise exception 'Informe um valor maior que zero' using errcode = '22023';
  end if;
  if p_due_date is null or p_due_date < date '2000-01-01' or p_due_date > date '2100-12-31' then
    raise exception 'Data inválida' using errcode = '22023';
  end if;
  if pg_catalog.char_length(coalesce(p_vendor, '')) > 100 or pg_catalog.char_length(coalesce(p_category, '')) > 60
     or pg_catalog.char_length(coalesce(p_notes, '')) > 500 then
    raise exception 'Dados longos demais' using errcode = '22023';
  end if;

  if v_id is not null then
    select p.status into v_status from public.payables p where p.id = v_id and p.org_id = p_org_id for update;
    if v_status is null then
      raise exception 'Conta não encontrada' using errcode = 'P0002';
    end if;
    if v_status = 'paid' then
      raise exception 'Conta paga não pode ser editada' using errcode = '22023';
    end if;
    update public.payables
       set description = pg_catalog.btrim(p_description), vendor = nullif(pg_catalog.btrim(coalesce(p_vendor, '')), ''),
           category = nullif(pg_catalog.btrim(coalesce(p_category, '')), ''), value = v_value,
           due_date = p_due_date, recurrence = v_recurrence, notes = nullif(pg_catalog.btrim(coalesce(p_notes, '')), '')
     where id = v_id and org_id = p_org_id;
  else
    insert into public.payables (org_id, description, vendor, category, value, due_date, recurrence, notes, status,
                                 created_by, request_id, request_hash)
    values (p_org_id, pg_catalog.btrim(p_description), nullif(pg_catalog.btrim(coalesce(p_vendor, '')), ''),
            nullif(pg_catalog.btrim(coalesce(p_category, '')), ''), v_value, p_due_date, v_recurrence,
            nullif(pg_catalog.btrim(coalesce(p_notes, '')), ''), 'pending', (select auth.uid()), p_request_id, v_hash)
    on conflict (org_id, request_id) where request_id is not null do nothing
    returning id into v_id;
    if v_id is null then
      v_existing := public.finance_request_existing(p_org_id, 'payable', p_request_id);
      if v_existing ->> 'hash' is distinct from v_hash then
        raise exception 'Chave reutilizada com dados diferentes' using errcode = '22023';
      end if;
      return pg_catalog.jsonb_build_object('id', v_existing ->> 'id', 'duplicate', true);
    end if;
  end if;

  if coalesce(p_paid_now, false) then
    v_today := (pg_catalog.now() at time zone public.finance_org_timezone(p_org_id))::date;
    perform public.finance_pay_payable(p_org_id, v_id, v_value, v_today);
  end if;
  return pg_catalog.jsonb_build_object('id', v_id, 'duplicate', false);
end;
$$;

create or replace function public.finance_delete_payable(p_org_id uuid, p_payable_id uuid)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_status text;
begin
  if (select auth.uid()) is null then
    raise exception 'Sessão expirada' using errcode = '42501';
  end if;
  if not public.has_permission(p_org_id, 'financeiro.manage') then
    raise exception 'Sem permissão para excluir contas' using errcode = '42501';
  end if;
  select p.status into v_status from public.payables p where p.id = p_payable_id and p.org_id = p_org_id for update;
  if v_status is null then
    return; -- já excluída (duplo clique): nada a fazer
  end if;
  if v_status = 'paid' then
    raise exception 'Conta paga não pode ser excluída' using errcode = '22023';
  end if;
  delete from public.payables where id = p_payable_id and org_id = p_org_id;
end;
$$;

-- Troca (ou tira, com p_path nulo) a fatura e devolve o caminho anterior, para o app apagar o arquivo velho.
create or replace function public.finance_set_payable_invoice(p_org_id uuid, p_payable_id uuid, p_path text, p_name text)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_prev text;
  v_found boolean;
begin
  if (select auth.uid()) is null then
    raise exception 'Sessão expirada' using errcode = '42501';
  end if;
  if not public.has_permission(p_org_id, 'financeiro.manage') then
    raise exception 'Sem permissão para anexar faturas' using errcode = '42501';
  end if;
  if p_path is not null and (
       p_path not like p_org_id::text || '/' || p_payable_id::text || '/%' or p_path like '%..%'
       or pg_catalog.char_length(p_path) > 300) then
    raise exception 'Fatura inválida' using errcode = '22023';
  end if;
  if pg_catalog.char_length(coalesce(p_name, '')) > 80 then
    raise exception 'Nome da fatura longo demais' using errcode = '22023';
  end if;
  select true, p.invoice_path into v_found, v_prev
  from public.payables p where p.id = p_payable_id and p.org_id = p_org_id for update;
  if v_found is null then
    raise exception 'Conta não encontrada' using errcode = 'P0002';
  end if;
  update public.payables
     set invoice_path = p_path, invoice_name = case when p_path is null then null else coalesce(nullif(p_name, ''), 'fatura') end
   where id = p_payable_id and org_id = p_org_id;
  return pg_catalog.jsonb_build_object('previous', v_prev);
end;
$$;

create or replace function public.finance_payable_invoice_path(p_org_id uuid, p_payable_id uuid)
returns text
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  if not public.has_permission(p_org_id, 'financeiro.view') then
    raise exception 'Sem permissão para ver faturas' using errcode = '42501';
  end if;
  return (select p.invoice_path from public.payables p where p.id = p_payable_id and p.org_id = p_org_id);
end;
$$;

-- ─── Checkout: Ficha Profissional + cobrança numa ida ──────────────────────────────────────────────
-- A chave do pedido do checkout (checkout_requests) não é legível pela API. Para dizer à tela que um envio é
-- repetição, esta função SECURITY DEFINER confere o estúdio e comanda.operate e responde só "esta chave já foi
-- concluída" (nada do pedido em si).
create or replace function public.checkout_request_done(p_org_id uuid, p_request_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or p_org_id is null or p_org_id not in (select public.auth_org_ids())
     or not public.has_permission(p_org_id, 'comanda.operate') then
    raise exception 'Sem permissão para registrar pagamentos' using errcode = '42501';
  end if;
  return exists (select 1 from public.checkout_requests r
                 where r.org_id = p_org_id and r.request_id = p_request_id and r.result is not null);
end;
$$;

-- Ao fechar (mode=finalize; sem mode também conta como fechar, o padrão de confirm_checkout_atomic), ficha pendente
-- devolve {gate: [...]} sem gravar nada (a tela monta o aviso, como antes). A trava continua também DENTRO da
-- cobrança: confirm_checkout_atomic muda o atendimento para Pago/Pago parcial e o gatilho
-- enforce_appointment_anamnese_status_gate recusa com ficha pendente (teste 96 e 153), então chamar a função antiga
-- direto pela API não pula a ficha. Repetição da mesma chave do pedido devolve o resultado guardado com duplicate.
create or replace function public.checkout_confirm(p_org_id uuid, p_command jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_gate jsonb;
  v_result jsonb;
  v_appt uuid;
  v_request uuid;
  v_repeat boolean;
begin
  if (select auth.uid()) is null then
    raise exception 'Sessão expirada' using errcode = '42501';
  end if;
  if not public.has_permission(p_org_id, 'comanda.operate') then
    raise exception 'Sem permissão para registrar pagamentos' using errcode = '42501';
  end if;
  if p_command is null or pg_catalog.jsonb_typeof(p_command) <> 'object'
     or coalesce(p_command ->> 'appointment_id', '') !~ '^[0-9a-fA-F-]{36}$'
     or coalesce(p_command ->> 'request_id', '') !~ '^[0-9a-fA-F-]{36}$' then
    raise exception 'Identificador invalido' using errcode = '22023';
  end if;
  v_appt := (p_command ->> 'appointment_id')::uuid;
  v_request := (p_command ->> 'request_id')::uuid;
  v_repeat := public.checkout_request_done(p_org_id, v_request);

  if not v_repeat and coalesce(p_command ->> 'mode', 'finalize') = 'finalize' then
    select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(g)) into v_gate
    from public.get_appointment_anamnese_gate(p_org_id, v_appt, 'checkout') g;
    if v_gate is not null and pg_catalog.jsonb_array_length(v_gate) > 0 then
      return pg_catalog.jsonb_build_object('gate', v_gate);
    end if;
  end if;

  v_result := public.confirm_checkout_atomic(p_org_id, p_command);
  if v_repeat then
    v_result := v_result || pg_catalog.jsonb_build_object('duplicate', true);
  end if;
  return v_result || pg_catalog.jsonb_build_object(
    'appointmentId', v_appt,
    'saleNumber', (select s.number from public.sales s where s.id = (v_result ->> 'saleId')::uuid and s.org_id = p_org_id));
end;
$$;

-- ─── Exportação CSV registrada ─────────────────────────────────────────────────────────────────────
-- SECURITY DEFINER para gravar em audit_logs sem abrir a política: confere estúdio e permissão da exportação
-- antes, aceita só os tipos fixos das telas e grava quem (auth.uid()), qual lista, quantas linhas e o período.
create or replace function public.finance_record_export(p_org_id uuid, p_kind text, p_rows integer, p_period text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Sessão expirada' using errcode = '42501';
  end if;
  if p_org_id is null or p_org_id not in (select public.auth_org_ids()) then
    raise exception 'Sem acesso a este estúdio.' using errcode = '42501';
  end if;
  if p_kind is null or p_kind not in ('lancamentos', 'contas', 'caixa', 'historico-caixas', 'comandas', 'saldos',
                                      'relatorio', 'dre', 'vales', 'comissoes') then
    raise exception 'Exportação inválida' using errcode = '22023';
  end if;
  if p_kind in ('lancamentos', 'contas', 'saldos', 'relatorio', 'dre', 'comissoes') then
    if not public.has_permission(p_org_id, 'financeiro.view') then
      raise exception 'Sem permissão para exportar' using errcode = '42501';
    end if;
  elsif not (public.has_permission(p_org_id, 'financeiro.view') or public.has_permission(p_org_id, 'comanda.operate')) then
    raise exception 'Sem permissão para exportar' using errcode = '42501';
  end if;
  if p_rows is null or p_rows < 0 or p_rows > 100000 then
    raise exception 'Exportação inválida' using errcode = '22023';
  end if;
  if p_period is not null and (pg_catalog.char_length(p_period) > 40 or p_period !~ '^[0-9a-z_-]*$') then
    raise exception 'Exportação inválida' using errcode = '22023';
  end if;
  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, new_data)
  values (p_org_id, v_uid, 'finance_exports', 'FINANCE_EXPORT', null,
          pg_catalog.jsonb_build_object('kind', p_kind, 'rows', p_rows, 'period', p_period));
end;
$$;

-- ─── Auditoria por gatilho ─────────────────────────────────────────────────────────────────────────
-- Contas a pagar (criar, mudar valor/vencimento/situação/pagamento/fatura, excluir), lançamentos sem venda
-- (lançamento manual, pagamento de conta, ajustes; os da venda já têm a auditoria do checkout) e vales-presente.
-- Só valores e situação; nada de texto livre, nome de cliente ou código de vale.
create or replace function public.finance_audit_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cols text[];
  v_col text;
  v_old_json jsonb;
  v_new_json jsonb;
  v_old jsonb := '{}'::jsonb;
  v_new jsonb := '{}'::jsonb;
  v_prefix text;
begin
  v_cols := case tg_table_name
    when 'payables' then array['value', 'due_date', 'status', 'paid_value', 'paid_date', 'category', 'recurrence', 'source_key']
    when 'transactions' then array['type', 'value', 'method', 'category', 'status', 'date']
    when 'gift_cards' then array['initial_value', 'remaining_value', 'status', 'expires_at']
  end;
  v_prefix := case tg_table_name when 'payables' then 'PAYABLE' when 'transactions' then 'TRANSACTION' else 'GIFT_CARD' end;

  -- Apagar o estúdio inteiro apaga em cascata: sem estúdio não há onde gravar a auditoria.
  if not exists (select 1 from public.organizations o where o.id = coalesce(new.org_id, old.org_id)) then
    return null;
  end if;

  if tg_op = 'DELETE' then
    v_old_json := pg_catalog.to_jsonb(old);
    foreach v_col in array v_cols loop
      v_old := v_old || pg_catalog.jsonb_build_object(v_col, v_old_json -> v_col);
    end loop;
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
    values (old.org_id, auth.uid(), tg_table_name, v_prefix || '_DELETED', old.id, pg_catalog.jsonb_strip_nulls(v_old), null);
    return null;
  end if;

  v_new_json := pg_catalog.to_jsonb(new);
  if tg_op = 'INSERT' then
    foreach v_col in array v_cols loop
      v_new := v_new || pg_catalog.jsonb_build_object(v_col, v_new_json -> v_col);
    end loop;
    insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
    values (new.org_id, auth.uid(), tg_table_name, v_prefix || '_CREATED', new.id, null, pg_catalog.jsonb_strip_nulls(v_new));
    return null;
  end if;

  v_old_json := pg_catalog.to_jsonb(old);
  foreach v_col in array v_cols loop
    if (v_old_json -> v_col) is distinct from (v_new_json -> v_col) then
      v_old := v_old || pg_catalog.jsonb_build_object(v_col, v_old_json -> v_col);
      v_new := v_new || pg_catalog.jsonb_build_object(v_col, v_new_json -> v_col);
    end if;
  end loop;
  if tg_table_name = 'payables' and (v_old_json -> 'invoice_path') is distinct from (v_new_json -> 'invoice_path') then
    v_old := v_old || pg_catalog.jsonb_build_object('invoice', pg_catalog.jsonb_typeof(v_old_json -> 'invoice_path') = 'string');
    v_new := v_new || pg_catalog.jsonb_build_object('invoice', pg_catalog.jsonb_typeof(v_new_json -> 'invoice_path') = 'string');
  end if;
  if v_new = '{}'::jsonb and v_old = '{}'::jsonb then
    return null;
  end if;
  insert into public.audit_logs (org_id, user_id, table_name, operation, record_id, old_data, new_data)
  values (new.org_id, auth.uid(), tg_table_name, v_prefix || '_UPDATED', new.id, v_old, v_new);
  return null;
end;
$$;

drop trigger if exists trg_payables_audit on public.payables;
create trigger trg_payables_audit after insert or update or delete on public.payables
  for each row execute function public.finance_audit_row();

drop trigger if exists trg_gift_cards_audit on public.gift_cards;
create trigger trg_gift_cards_audit after insert or update or delete on public.gift_cards
  for each row execute function public.finance_audit_row();

-- Lançamentos: criados sem venda; qualquer mudança de valor, forma, categoria, situação ou data; exclusão.
-- (Ligar o lançamento a um caixa, cash_session_id, não é mudança de dinheiro e não gera linha.)
drop trigger if exists trg_transactions_audit_insert on public.transactions;
create trigger trg_transactions_audit_insert after insert on public.transactions
  for each row when (new.sale_id is null) execute function public.finance_audit_row();
drop trigger if exists trg_transactions_audit_update on public.transactions;
create trigger trg_transactions_audit_update after update on public.transactions
  for each row when (old.type is distinct from new.type or old.value is distinct from new.value
                     or old.method is distinct from new.method or old.category is distinct from new.category
                     or old.status is distinct from new.status or old.date is distinct from new.date)
  execute function public.finance_audit_row();
drop trigger if exists trg_transactions_audit_delete on public.transactions;
create trigger trg_transactions_audit_delete after delete on public.transactions
  for each row execute function public.finance_audit_row();

-- ─── Execução ──────────────────────────────────────────────────────────────────────────────────────
revoke all on function public.finance_create_entry(uuid, text, text, numeric, date, text, text, text, uuid) from public, anon;
revoke all on function public.finance_pay_payable(uuid, uuid, numeric, date) from public, anon;
revoke all on function public.finance_request_existing(uuid, text, uuid) from public, anon;
revoke all on function public.finance_save_payable(uuid, uuid, text, text, text, numeric, date, text, text, boolean, uuid) from public, anon;
revoke all on function public.finance_delete_payable(uuid, uuid) from public, anon;
revoke all on function public.finance_set_payable_invoice(uuid, uuid, text, text) from public, anon;
revoke all on function public.finance_payable_invoice_path(uuid, uuid) from public, anon;
revoke all on function public.checkout_confirm(uuid, jsonb) from public, anon;
revoke all on function public.checkout_request_done(uuid, uuid) from public, anon;
revoke all on function public.finance_record_export(uuid, text, integer, text) from public, anon;
revoke all on function public.finance_audit_row() from public, anon, authenticated;

grant execute on function public.finance_create_entry(uuid, text, text, numeric, date, text, text, text, uuid) to authenticated;
grant execute on function public.finance_pay_payable(uuid, uuid, numeric, date) to authenticated;
grant execute on function public.finance_request_existing(uuid, text, uuid) to authenticated;
grant execute on function public.finance_save_payable(uuid, uuid, text, text, text, numeric, date, text, text, boolean, uuid) to authenticated;
grant execute on function public.finance_delete_payable(uuid, uuid) to authenticated;
grant execute on function public.finance_set_payable_invoice(uuid, uuid, text, text) to authenticated;
grant execute on function public.finance_payable_invoice_path(uuid, uuid) to authenticated;
grant execute on function public.checkout_confirm(uuid, jsonb) to authenticated;
grant execute on function public.checkout_request_done(uuid, uuid) to authenticated;
grant execute on function public.finance_record_export(uuid, text, integer, text) to authenticated;
