-- UTF-8
-- Adds user-controlled visibility flag to anamnese_templates.
-- active = false means soft-deleted (never shown anywhere).
-- is_active = false means deactivated by user (excluded from new-anamnese selectors,
--             but existing fichas preserve their snapshot and are unaffected).

ALTER TABLE anamnese_templates
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN anamnese_templates.is_active IS
  'User-controlled visibility. false = hidden from selectors; fichas already created are unaffected.';
