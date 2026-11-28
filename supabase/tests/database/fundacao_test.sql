-- Teste de exemplo do banco local (spec 20261128-005000-fundacao-tecnica, R8 e CA6).
-- Molde oficial: https://supabase.com/docs/guides/local-development/testing/overview
begin;
select plan(1);

select has_schema('public', 'o esquema public existe');

select * from finish();
rollback;
