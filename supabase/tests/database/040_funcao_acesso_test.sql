-- Item 3 · spec 20261128-010000-banco-ligacao · plan.md §5 · CA-06: a checagem ignora o estúdio mandado no pedido
-- Molde oficial: https://supabase.com/docs/guides/local-development/testing/overview
-- Login simulado: set_config('request.jwt.claims') + set local role authenticated (é o que auth.uid() lê).
begin;
select plan(12);

-- Preparo (como postgres): pessoas e estúdios fictícios, escritos do zero (RG-07).
-- A = ...0a · B = ...0b · a1 dona A · a2 recepção A · a3 profissional A · b1 dona B
-- c1 sem papel · d1 vínculo inativo em A · m1 profissional em A (atual) e recepção em B
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'a1@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000a2', 'a2@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000a3', 'a3@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000b1', 'b1@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000c1', 'c1@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000d1', 'd1@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000e1', 'e1@exemplo.test'),
  ('00000000-0000-0000-0000-0000000000f1', 'f1@exemplo.test');

insert into public.estudios (org_id, nome, moeda, idioma, fuso_horario) values
  ('00000000-0000-0000-0000-00000000000a', 'Estudio A', 'EUR', 'pt', 'Europe/Lisbon'),
  ('00000000-0000-0000-0000-00000000000b', 'Estudio B', 'EUR', 'es', 'Europe/Madrid');

insert into public.membros (org_id, user_id, papel, ativo, estudio_atual) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a1', 'dona', true, true),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a2', 'recepcao', true, true),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a3', 'profissional', true, true),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000b1', 'dona', true, true),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000d1', 'recepcao', false, true),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000f1', 'profissional', true, true),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000f1', 'recepcao', true, false);

-- dona de A com o estúdio B "mandado" de três jeitos no token
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated","org_id":"00000000-0000-0000-0000-00000000000b","app_metadata":{"org_id":"00000000-0000-0000-0000-00000000000b"},"user_metadata":{"org_id":"00000000-0000-0000-0000-00000000000b"}}',
  true);
set local role authenticated;
select is(app.estudio_da_sessao(), '00000000-0000-0000-0000-00000000000a'::uuid, 'org_id no token é ignorado: continua A');
select results_eq('select org_id from public.estudios',
  array['00000000-0000-0000-0000-00000000000a'::uuid], 'com B no token, lê só A');
select is(app.papel_da_sessao(), 'dona', 'papel vem do vínculo em A');
select throws_ok($$select app.escolher_estudio('00000000-0000-0000-0000-00000000000b')$$,
  '42501', null, 'escolher B sem vínculo em B é recusado');
select is(app.estudio_da_sessao(), '00000000-0000-0000-0000-00000000000a'::uuid, 'depois da recusa, continua A');
reset role;

-- pessoa com papel em A (atual) e em B
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f1","role":"authenticated"}', true);
set local role authenticated;
select results_eq('select org_id from public.estudios',
  array['00000000-0000-0000-0000-00000000000a'::uuid], 'pessoa de A e B, com A escolhido, lê só A');
select ok(app.escolher_estudio('00000000-0000-0000-0000-00000000000b'), 'ela escolhe B');
select results_eq('select org_id from public.estudios',
  array['00000000-0000-0000-0000-00000000000b'::uuid], 'agora lê só B');
select is(app.papel_da_sessao(), 'recepcao', 'e o papel passa a ser o de B');
reset role;

-- vínculo inativo não escolhe
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d1","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select app.escolher_estudio('00000000-0000-0000-0000-00000000000a')$$,
  '42501', null, 'vínculo inativo não escolhe o estúdio');
reset role;

-- sem login
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
set local role authenticated;
select is(app.estudio_da_sessao(), null, 'sem sub no token, nenhum estúdio');
reset role;
select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_ok('select app.estudio_da_sessao()', '42501', null, 'sem login não chama a checagem');
reset role;

select * from finish();
rollback;
