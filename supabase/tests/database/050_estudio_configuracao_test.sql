-- Item 3 · spec 20261128-010000-banco-ligacao · plan.md §5 · CA-13: moeda, idioma e fuso do estúdio
-- Molde oficial: https://supabase.com/docs/guides/local-development/testing/overview
-- Login simulado: set_config('request.jwt.claims') + set local role authenticated (é o que auth.uid() lê).
begin;
select plan(14);

-- Preparo (como postgres): pessoas e estúdios fictícios, escritos do zero (RG-07).
-- A = ...0a · B = ...0b · a1 dona A · a2 recepção A · a3 profissional A · b1 dona B
-- c1 e e1 sem papel · d1 vínculo inativo em A · f1 profissional em A (atual) e recepção em B
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

select lives_ok($$insert into public.estudios (nome, moeda, idioma, fuso_horario) values ('Valido', 'EUR', 'es', 'Europe/Madrid')$$,
  'EUR, es e Europe/Madrid aceitos');
select lives_ok($$insert into public.estudios (nome, moeda, idioma, fuso_horario) values ('Valido 2', 'BRL', 'en', 'America/Sao_Paulo')$$,
  'BRL, en e America/Sao_Paulo aceitos');
select throws_ok($$insert into public.estudios (nome, moeda, idioma, fuso_horario) values ('X', 'EUR', 'fr', 'Europe/Paris')$$,
  '23514', null, 'idioma fr recusado');
select throws_ok($$insert into public.estudios (nome, moeda, idioma, fuso_horario) values ('X', 'EUR', 'PT', 'Europe/Lisbon')$$,
  '23514', null, 'idioma PT recusado');
select throws_ok($$insert into public.estudios (nome, moeda, idioma, fuso_horario) values ('X', 'EUR', null, 'Europe/Lisbon')$$,
  '23502', null, 'idioma vazio recusado');
select throws_ok($$insert into public.estudios (nome, moeda, idioma, fuso_horario) values ('X', 'eur', 'pt', 'Europe/Lisbon')$$,
  '23514', null, 'moeda eur recusada');
select throws_ok($$insert into public.estudios (nome, moeda, idioma, fuso_horario) values ('X', 'EU', 'pt', 'Europe/Lisbon')$$,
  '23514', null, 'moeda EU recusada');
select throws_ok($$insert into public.estudios (nome, idioma, fuso_horario) values ('X', 'pt', 'Europe/Lisbon')$$,
  '23502', null, 'moeda vazia recusada (sem padrão)');
select throws_ok($$insert into public.estudios (nome, moeda, idioma, fuso_horario) values ('X', 'EUR', 'pt', 'Marte/Base')$$,
  '22023', null, 'fuso inexistente recusado');
select throws_ok($$insert into public.estudios (nome, moeda, idioma, fuso_horario) values ('X', 'EUR', 'pt', 'posix/Europe/Madrid')$$,
  '22023', null, 'fuso não canônico (posix/) recusado');
select throws_ok($$insert into public.estudios (nome, moeda, idioma, fuso_horario) values ('X', 'EUR', 'pt', 'Factory')$$,
  '22023', null, 'fuso fictício Factory recusado');
select throws_ok($$insert into public.estudios (nome, moeda, idioma) values ('X', 'EUR', 'pt')$$,
  '23502', null, 'fuso vazio recusado (sem padrão)');

-- ao alterar, como dona de A
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$update public.estudios set fuso_horario = 'Marte/Base' where org_id = '00000000-0000-0000-0000-00000000000a'$$,
  '22023', null, 'fuso inexistente recusado ao alterar');
select throws_ok($$update public.estudios set idioma = 'fr' where org_id = '00000000-0000-0000-0000-00000000000a'$$,
  '23514', null, 'idioma fr recusado ao alterar');
reset role;

select * from finish();
rollback;
