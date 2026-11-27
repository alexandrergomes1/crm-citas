-- KA Beauty OS - Cover clinical gate foreign keys
-- Encoding: UTF-8

create index if not exists idx_appointment_items_anamnese_template_id
  on public.appointment_items (anamnese_template_id);

create index if not exists idx_anamneses_source_service_id
  on public.anamneses (source_service_id);
