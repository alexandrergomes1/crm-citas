-- Link público da anamnese sempre expira (AGENTS: "tokens de anamnese expiram").
-- Encoding: UTF-8. As funções de criação já gravam 7 dias; o banco passa a garantir isso
-- também para qualquer inserção direta, e uma ficha sem prazo deixa de existir.
update public.anamneses
   set token_expires_at = coalesce(created_at, pg_catalog.now()) + interval '7 days'
 where token_expires_at is null;

alter table public.anamneses
  alter column token_expires_at set default (pg_catalog.now() + interval '7 days');

alter table public.anamneses
  alter column token_expires_at set not null;
