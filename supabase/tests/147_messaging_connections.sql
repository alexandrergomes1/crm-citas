-- Conexões de mensagem (20261101100000): só quem configura escreve; quem usa lê; outro estúdio não vê.
-- Desfaz tudo no fim.
-- Encoding: UTF-8
\set ON_ERROR_STOP 1
\o /dev/null
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000001471', 'dona-msg@teste.local'),
  ('00000000-0000-0000-0000-000000001472', 'recep-msg@teste.local'),
  ('00000000-0000-0000-0000-000000001473', 'outra-msg@teste.local');
insert into public.organizations (id, slug, name, timezone) values
  ('00000000-0000-0000-0000-00000000147a', 'msg-a', 'Estúdio A', 'Europe/Madrid'),
  ('00000000-0000-0000-0000-00000000147b', 'msg-b', 'Estúdio B', 'Europe/Madrid');
insert into public.user_roles (user_id, org_id, role) values
  ('00000000-0000-0000-0000-000000001471', '00000000-0000-0000-0000-00000000147a', 'owner'),
  ('00000000-0000-0000-0000-000000001472', '00000000-0000-0000-0000-00000000147a', 'receptionist'),
  ('00000000-0000-0000-0000-000000001473', '00000000-0000-0000-0000-00000000147b', 'owner');

create function pg_temp.expect(p_ok boolean, p_msg text) returns void language plpgsql as $$
begin
  if not coalesce(p_ok, false) then raise exception 'FALHOU: %', p_msg; end if;
end $$;
create function pg_temp.state_of(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return sqlstate;
end $$;
create function pg_temp.login(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

grant execute on function pg_temp.expect(boolean, text), pg_temp.state_of(text), pg_temp.login(uuid) to authenticated;

-- Dona cria a conexão do estúdio A.
select pg_temp.login('00000000-0000-0000-0000-000000001471');
insert into public.messaging_connections (org_id, provider, session_name, status)
  values ('00000000-0000-0000-0000-00000000147a', 'waha_qr', 'org-msg-a', 'awaiting_scan');
select pg_temp.expect((select count(*) from public.messaging_connections) = 1, 'dona vê a própria conexão');

-- Uma conexão por canal e estúdio.
select pg_temp.expect(pg_temp.state_of($q$insert into public.messaging_connections (org_id, provider, session_name)
  values ('00000000-0000-0000-0000-00000000147a', 'waha_qr', 'outra')$q$) = '23505', 'segunda conexão do mesmo canal é recusada');
-- Estado inválido é recusado.
select pg_temp.expect(pg_temp.state_of($q$update public.messaging_connections set status = 'qualquer'$q$) = '23514', 'status inválido recusado');

-- Recepção lê, mas não escreve a conexão; registra e lê envios.
select pg_temp.login('00000000-0000-0000-0000-000000001472');
select pg_temp.expect((select count(*) from public.messaging_connections) = 1, 'recepção vê a conexão');
select pg_temp.expect(pg_temp.state_of($q$update public.messaging_connections set status = 'connected'$q$) = 'ok'
  and (select status from public.messaging_connections) = 'awaiting_scan', 'recepção não altera a conexão (0 linhas)');
select pg_temp.expect(pg_temp.state_of($q$delete from public.messaging_connections$q$) = 'ok'
  and (select count(*) from public.messaging_connections) = 1, 'recepção não apaga a conexão');
-- Registro de envio (20261114090100): só quem configura grava, só teste, com o próprio usuário como autor, enviado ou falhou.
select pg_temp.expect(pg_temp.state_of($q$insert into public.messaging_provider_log (org_id, provider, purpose, recipient, body, status, created_by)
  values ('00000000-0000-0000-0000-00000000147a', 'waha_qr', 'teste', '34600000000', 'Teste', 'sent', '00000000-0000-0000-0000-000000001472')$q$) = '42501',
  'recepção não registra envio');
select pg_temp.login('00000000-0000-0000-0000-000000001471');
insert into public.messaging_provider_log (org_id, provider, purpose, recipient, body, status, created_by)
  values ('00000000-0000-0000-0000-00000000147a', 'waha_qr', 'teste', '34600000000', 'Teste', 'sent', '00000000-0000-0000-0000-000000001471');
-- Registro de e-mail (provedor e canal novos); canal inválido é recusado.
insert into public.messaging_provider_log (org_id, provider, channel, purpose, recipient, body, status, created_by)
  values ('00000000-0000-0000-0000-00000000147a', 'resend', 'email', 'teste', 'cliente@teste.local', 'Teste', 'sent', '00000000-0000-0000-0000-000000001471');
select pg_temp.expect(pg_temp.state_of($q$insert into public.messaging_provider_log (org_id, provider, channel, purpose, recipient, body, status, created_by)
  values ('00000000-0000-0000-0000-00000000147a', 'resend', 'fax', 'teste', 'x', 'x', 'sent', '00000000-0000-0000-0000-000000001471')$q$) = '23514', 'canal inválido recusado');
-- Não registra envio em outro estúdio.
select pg_temp.expect(pg_temp.state_of($q$insert into public.messaging_provider_log (org_id, provider, purpose, recipient, body, created_by)
  values ('00000000-0000-0000-0000-00000000147b', 'waha_qr', 'teste', '34600000000', 'x', '00000000-0000-0000-0000-000000001471')$q$) = '42501', 'envio em outro estúdio é recusado');
select pg_temp.login('00000000-0000-0000-0000-000000001472');
select pg_temp.expect((select count(*) from public.messaging_provider_log) = 2, 'recepção lê os envios');

-- Outro estúdio não enxerga nada.
select pg_temp.login('00000000-0000-0000-0000-000000001473');
select pg_temp.expect((select count(*) from public.messaging_connections) = 0, 'outro estúdio não vê conexões');
select pg_temp.expect((select count(*) from public.messaging_provider_log) = 0, 'outro estúdio não vê envios');

rollback;
\o
select 'ok: 147_messaging_connections' as result;
