-- Revisão de funções de 29 out, parte 4: edição de série recorrente.
-- Encoding: UTF-8.
-- update_recurrence_series_atomic:
--   1. só edita ocorrências ainda em aberto (Reservado, Agendado, Confirmado, Iniciado),
--      a mesma regra da tela. Antes, uma chamada direta reescrevia atendimento Concluído
--      ou com Ausência (histórico).
--   2. com um único serviço, a duração nova da série vai também para o item (spec 35);
--      sem isso, editar o item depois voltaria o agendamento para a duração antiga.
-- Ajuste por substituição exata no corpo atual (a função continua igual no resto).
set client_encoding = 'UTF8';

do $$
declare
  v_def text := pg_catalog.pg_get_functiondef('public.update_recurrence_series_atomic'::regproc);
  v_a text := 'and a.status not in (''Cancelado'', ''Pago'', ''Pago Parcial'')';
  v_b text := E'      and recurrence_id = p_recurrence_id;\n\n    v_updated := v_updated + 1;';
begin
  if (pg_catalog.length(v_def) - pg_catalog.length(pg_catalog.replace(v_def, v_a, ''))) / pg_catalog.length(v_a) <> 1 then
    raise exception 'Trecho de status não encontrado em update_recurrence_series_atomic';
  end if;
  if (pg_catalog.length(v_def) - pg_catalog.length(pg_catalog.replace(v_def, v_b, ''))) / pg_catalog.length(v_b) <> 1 then
    raise exception 'Trecho do update não encontrado em update_recurrence_series_atomic';
  end if;
  v_def := pg_catalog.replace(v_def, v_a, 'and a.status in (''Reservado'', ''Agendado'', ''Confirmado'', ''Iniciado'')');
  v_def := pg_catalog.replace(v_def, v_b, E'      and recurrence_id = p_recurrence_id;\n\n'
    || E'    -- Um serviço só: a duração da série é a do item (spec 35).\n'
    || E'    if p_duration_minutes between 5 and 720 then\n'
    || E'      update public.appointment_items ai\n'
    || E'      set duration_minutes = p_duration_minutes\n'
    || E'      where ai.org_id = p_org_id\n'
    || E'        and ai.appointment_id = v_id\n'
    || E'        and (select pg_catalog.count(*) from public.appointment_items x\n'
    || E'             where x.org_id = p_org_id and x.appointment_id = v_id) = 1;\n'
    || E'    end if;\n\n'
    || E'    v_updated := v_updated + 1;');
  execute v_def;
end $$;
