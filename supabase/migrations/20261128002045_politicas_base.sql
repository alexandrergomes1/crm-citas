-- Item 3 · spec 20261128-010000-banco-ligacao · plan.md §4 · ADR 0005 (D3, T10).
-- S = org_id = (select app.estudio_da_sessao())  ·  D = (select app.eh_dona())
-- Sem login (anon): nenhum privilégio. Com login: só o necessário, por coluna.

-- estudios: ler S; alterar S e D; ninguém cria nem apaga.
grant select on table public.estudios to authenticated;
grant update (nome, moeda, idioma, fuso_horario) on table public.estudios to authenticated;

create policy estudios_ler on public.estudios
  for select to authenticated
  using (org_id = (select app.estudio_da_sessao()));

create policy estudios_alterar on public.estudios
  for update to authenticated
  using (org_id = (select app.estudio_da_sessao()) and (select app.eh_dona()))
  with check (org_id = (select app.estudio_da_sessao()) and (select app.eh_dona()));

-- membros: ler S ou as próprias linhas; alterar e apagar S e D.
-- Criar vínculo não é permitido a ninguém com login: o convite passa pelo servidor, com aceite
-- (ADR 0005, Consequências). Um insert direto revelaria se um id tem conta (erro 23503).
grant select, delete on table public.membros to authenticated;
grant update (papel, ativo) on table public.membros to authenticated;

create policy membros_ler on public.membros
  for select to authenticated
  using (org_id = (select app.estudio_da_sessao()) or user_id = (select auth.uid()));

create policy membros_alterar on public.membros
  for update to authenticated
  using (org_id = (select app.estudio_da_sessao()) and (select app.eh_dona()))
  with check (org_id = (select app.estudio_da_sessao()) and (select app.eh_dona()));

create policy membros_apagar on public.membros
  for delete to authenticated
  using (org_id = (select app.estudio_da_sessao()) and (select app.eh_dona()));
