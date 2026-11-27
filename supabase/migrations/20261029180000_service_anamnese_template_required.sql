-- Serviço que exige anamnese precisa ter o modelo da ficha escolhido.
-- Encoding: UTF-8
--
-- Sem modelo, a trava do atendimento recusa iniciar ("O serviço X exige anamnese, mas não
-- possui modelo configurado") e o erro só aparece na hora de atender. Agora o cadastro recusa
-- antes. Em produção, os 5 serviços nessa situação foram corrigidos antes desta migration
-- (registro em audit_logs, operação DATA_FIX).

alter table public.services
  add constraint services_anamnese_template_required
  check (not requires_anamnese or anamnese_template_id is not null);
