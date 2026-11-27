-- Depois do estorno, o atendimento pode ser cobrado de novo numa comanda nova.
-- Encoding: UTF-8
--
-- Estornar a comanda deixa a venda 'cancelled' e o atendimento Concluído. Para corrigir um
-- valor errado basta cobrar de novo, mas havia uma venda por atendimento (índice único) e o
-- checkout sempre pegava a venda existente, mesmo a cancelada. Aqui:
--   * a unicidade (org, atendimento) vale só para vendas não canceladas;
--   * confirm_checkout_atomic ignora a venda cancelada ao procurar a venda do atendimento
--     (troca exata de um trecho; falha se o trecho não aparecer exatamente uma vez).
-- A comanda cancelada continua guardada, com o histórico do estorno.
set client_encoding = 'UTF8';

drop index if exists public.idx_sales_org_appointment_unique;
create unique index if not exists idx_sales_org_appointment_unique
  on public.sales (org_id, appointment_id)
  where appointment_id is not null and status <> 'cancelled';

do $rewrite$
declare
  v_def text;
  v_count integer;
  v_pattern constant text := 'from public\.sales\s+where appointment_id = v_appointment_id\s+and org_id = p_org_id\s+for update';
begin
  select pg_get_functiondef('public.confirm_checkout_atomic(uuid, jsonb)'::regprocedure) into v_def;
  select count(*) into v_count from regexp_matches(v_def, v_pattern, 'g');
  if v_count <> 1 then
    raise exception 'confirm_checkout_atomic: trecho da busca da venda encontrado % vez(es), esperado 1', v_count;
  end if;
  execute regexp_replace(v_def, v_pattern,
    'from public.sales where appointment_id = v_appointment_id and org_id = p_org_id and status <> ''cancelled'' for update');
end;
$rewrite$;
