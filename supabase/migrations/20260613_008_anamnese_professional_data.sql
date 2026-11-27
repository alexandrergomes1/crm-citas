-- KA Beauty OS — Suporte a secção profissional em templates e fichas de anamnese
-- Encoding: UTF-8

ALTER TABLE anamnese_templates
  ADD COLUMN IF NOT EXISTS professional_form JSONB DEFAULT NULL;

ALTER TABLE anamneses
  ADD COLUMN IF NOT EXISTS professional_data JSONB DEFAULT NULL;
