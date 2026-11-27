-- Histórico de auditoria: gravação direta pela API só para os registros que o app grava como a própria pessoa.
-- Encoding: UTF-8
--
-- Revisão de segurança (29 out): a política audit_insert_member aceitava qualquer
-- table_name/operation vindos da API. Um membro podia gravar no histórico, em nome próprio,
-- entradas que só funções privilegiadas produzem (ROLE_PERMISSION_SET, DATA_FIX,
-- PAYMENT_REQUEST_CONFIRMED, LOYALTY_ADJUST, ANAMNESE_GATE_OVERRIDE, checkout_create...),
-- poluindo a trilha que a dona usa para conferir o que aconteceu.
--
-- As funções SECURITY DEFINER rodam como dona da tabela e não passam por esta política.
-- Aqui ficam só os pares (tabela, operação) gravados por funções SECURITY INVOKER, pelo
-- gatilho de exclusão de anamnese pendente e pela leitura de ficha clínica no app
-- (CLINICAL_READ). Uma operação nova gravada como invoker precisa entrar nesta lista.

drop policy if exists audit_insert_member on public.audit_logs;
create policy audit_insert_member on public.audit_logs for insert to authenticated
  with check (
    org_id in (select public.auth_org_ids())
    and user_id = (select auth.uid())
    and public.has_org_role(org_id, array['owner', 'admin', 'manager', 'receptionist', 'professional', 'finance'])
    and (
      (table_name, operation) in (
        ('appointments', 'APPOINTMENT_CREATED'),
        ('appointments', 'APPOINTMENT_UPDATED'),
        ('appointments', 'APPOINTMENT_RESCHEDULED'),
        ('appointments', 'STATUS_CHANGE'),
        ('appointments', 'RECURRENCE_CREATED'),
        ('appointments', 'RECURRENCE_UPDATED'),
        ('appointments', 'RECURRENCE_CANCELLED'),
        ('appointment_items', 'APPOINTMENT_ITEM_UPDATED'),
        ('time_blocks', 'TIME_BLOCKS_CREATED'),
        ('time_blocks', 'TIME_BLOCK_DELETED'),
        ('anamneses', 'ANAMNESE_PENDING_DELETED'),
        ('anamneses', 'PROFESSIONAL_DRAFT_SAVED'),
        ('anamneses', 'PROFESSIONAL_COMPLETED'),
        ('anamneses', 'PROFESSIONAL_NOTES_UPDATED'),
        ('anamneses', 'PROFESSIONAL_REOPENED'),
        ('anamneses', 'CLINICAL_READ'),
        ('clients', 'CLIENT_BOOKING_BLOCKED'),
        ('clients', 'CLIENT_BOOKING_UNBLOCKED'),
        ('organizations', 'SETTINGS_SET'),
        -- register_stock_entry_atomic grava 'STOCK_' || upper(p_type), p_type em entrada/saida/ajuste.
        ('products', 'STOCK_ENTRADA'),
        ('products', 'STOCK_SAIDA'),
        ('products', 'STOCK_AJUSTE')
      )
    )
  );
