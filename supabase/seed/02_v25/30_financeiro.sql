-- KA Beauty OS — seed V25, parte: Contas a pagar, lançamentos e modelos de mensagem. Encoding: UTF-8
-- Incluído por supabase/seed/02_v25_dados_teste.sql (não rodar sozinho).

-- ─── 5. Contas a pagar e lançamentos ─────────────────────────
create temp table seed_pagamento (chave text primary key, transacao uuid not null);
grant select, insert on seed_pagamento to authenticated;

insert into public.payables (id, org_id, description, category, value, due_date, status, vendor, created_by)
select pg_temp.sid('conta-' || c.chave), current_setting('seed.org_id')::uuid, c.descr, c.cat, c.valor, pg_temp.dia(c.vence),
       case when c.pago is null and c.vence < 0 then 'overdue' else 'pending' end, c.fornecedor, current_setting('seed.owner_id')::uuid
from (values
  ('01', 'Descartáveis e luvas', 'Materiais', 74.20, -5, null::int, 'Distribuidora Dental'),
  ('02', 'Internet e telefone', 'Serviços', 49.90, 1, null, 'Operadora Costa del Sol'),
  ('03', 'Aluguel do estúdio · ' || pg_temp.mes(pg_temp.dia(0) + 30), 'Aluguel', 650.00, 3, null, 'Imobiliária Marbella'),
  ('04', 'Contabilidade', 'Serviços', 85.00, 3, null, 'Gestoría Málaga'),
  ('05', 'Luz e água', 'Utilidades', 96.00, 9, null, 'Companhia de energia'),
  ('06', 'Curso de pigmentação', 'Formação', 320.00, 19, null, 'Academia Brows'),
  ('07', 'Aluguel do estúdio · ' || pg_temp.mes(pg_temp.dia(0)), 'Aluguel', 650.00, -27, -27, 'Imobiliária Marbella'),
  ('08', 'Compra de pigmentos', 'Materiais', 186.40, 0, 0, 'Pigmentos Nouveau'),
  ('09', 'Internet e telefone', 'Serviços', 49.90, -29, -29, 'Operadora Costa del Sol'),
  ('10', 'Contabilidade', 'Serviços', 85.00, -27, -26, 'Gestoría Málaga'),
  ('11', 'Luz e água', 'Utilidades', 92.10, -21, -21, 'Companhia de energia'),
  ('12', 'Descartáveis e luvas', 'Materiais', 68.50, -35, -34, 'Distribuidora Dental'),
  ('13', 'Seguro do estúdio', 'Serviços', 120.00, -15, -15, 'Seguros Andalucía'),
  ('14', 'Material de limpeza', 'Materiais', 34.80, -10, -10, 'Limpiezas Sol')
) c(chave, descr, cat, valor, vence, pago, fornecedor);

set local role authenticated;
do $$
declare r record;
begin
  for r in select * from (values ('07', 650.00, -27), ('08', 186.40, 0), ('09', 49.90, -29), ('10', 85.00, -26),
                                 ('11', 92.10, -21), ('12', 68.50, -34), ('13', 120.00, -15), ('14', 34.80, -10)) p(chave, valor, dia) loop
    insert into seed_pagamento values ('conta-' || r.chave,
      public.pay_payable_atomic(current_setting('seed.org_id')::uuid, pg_temp.sid('conta-' || r.chave), r.valor, pg_temp.dia(r.dia)));
  end loop;
end $$;
reset role;

-- A despesa gerada ao pagar a conta ganha ID do seed, para a próxima rodada achá-la.
update public.transactions t set id = pg_temp.sid('despesa-' || p.chave)
from seed_pagamento p where t.id = p.transacao and t.org_id = current_setting('seed.org_id')::uuid;

insert into public.transactions (id, org_id, type, category, description, value, method, date, status, created_by, created_at)
select pg_temp.sid(l.chave), current_setting('seed.org_id')::uuid, l.tipo, l.cat, l.descr, l.valor, l.metodo, pg_temp.dia(l.dia),
       'completed', current_setting('seed.owner_id')::uuid, pg_temp.em(l.dia, '18:30')
from (values
  ('lanc-01', 'expense', 'outro', 'Café e água para clientes', 18.60, 'CASH', -3),
  ('lanc-02', 'expense', 'marketing', 'Anúncio no Instagram', 40.00, 'CARD_CREDIT', -12),
  ('lanc-03', 'income', 'produto', 'Pomada cicatrizante', 15.00, 'CASH', -2)
) l(chave, tipo, cat, descr, valor, metodo, dia);

-- ─── 6. Modelos de mensagem (avaliação e marketing) ──────────
insert into public.marketing_message_templates (id, org_id, name, channel, purpose, language, subject, body, active, created_by, updated_by)
select pg_temp.sid('mensagem-' || m.chave), current_setting('seed.org_id')::uuid, m.nome, m.canal, m.uso, 'es', m.assunto, m.texto, true,
       current_setting('seed.owner_id')::uuid, current_setting('seed.owner_id')::uuid
from (values
  ('avaliacao', 'Agradecimento com avaliação', 'whatsapp_provider', 'review_request', null,
   '¡Gracias por venir hoy, {cliente}! Fue un placer cuidar de ti con {service}. Si te gustó, tu opinión en Google nos ayuda muchísimo: {reviewLink}'),
  ('agradecimento', 'Agradecimento simples', 'whatsapp_provider', 'manual', null,
   '¡Gracias por venir hoy, {cliente}! Fue un placer atenderte. Un abrazo, {clinicName}'),
  ('cuidados', 'Cuidados após o procedimento', 'whatsapp_provider', 'aftercare', null,
   'Durante los próximos 7 días, evita el sol directo, piscinas y maquillaje en la zona tratada. Cualquier duda, escríbenos.'),
  ('aniversario', 'Aniversário', 'whatsapp_provider', 'birthday', null,
   '¡Feliz cumpleaños, {cliente}! Tienes un regalo esperándote este mes en {clinicName}.'),
  ('saudade', 'Saudade · 60 dias', 'email_provider', 'inactive_recovery', 'Hace tiempo que no te vemos',
   'Hace tiempo que no te vemos, {cliente}. ¿Reservamos tu próxima cita? Responde a este correo o llama al {clinicPhone}.')
) m(chave, nome, canal, uso, assunto, texto)
on conflict (id) do update set name = excluded.name, channel = excluded.channel, purpose = excluded.purpose,
  subject = excluded.subject, body = excluded.body, active = true, archived_at = null;
