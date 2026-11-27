-- KA Beauty OS — Ciclo de vida da ficha profissional da anamnese
-- Encoding: UTF-8
-- requires_professional: se esta ficha exige preenchimento/conclusão da parte do profissional
-- professional_completed_at: marca quando o profissional concluiu a sua parte

ALTER TABLE anamneses
  ADD COLUMN IF NOT EXISTS requires_professional BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE anamneses
  ADD COLUMN IF NOT EXISTS professional_completed_at TIMESTAMPTZ DEFAULT NULL;
