-- Spec 20261128-030000-entrar-servico · RF-18 · plan.md §5a · ADR 0020 (D3, D4, D7) · ADR 0019 (D21).
-- Cópia da matriz padrão do código (src/domain/acesso/chaves.ts e matriz.ts) e a função de acesso do banco.
-- A fonte é o código: esta migration e as dos módulos só inserem as linhas que o código tem, e o teste
-- 110_matriz_permissoes_test.sql (com supabase/matriz/matriz.test.ts) fica vermelho se divergirem (ADR 0020 · D8).
-- Nesta spec a matriz nasce sem linhas de módulo: o Entrar não tem ação do modo estúdio.
-- Depois do merge, linha nova ou mudada é migration nova, nunca edição desta (ADR 0019 · D9).

-- Catálogo fechado de chaves `modulo.acao` (ADR 0020 · D2). Chave fora daqui = ninguém pode, nem a dona.
create table app.chaves_permissao (
  chave text primary key check (chave ~ '^[a-z][a-z_]{0,30}\.[a-z][a-z_]{0,30}$')
);

-- Matriz padrão: uma linha por papel × chave, só recepção e profissional; a dona tem tudo por regra fixa
-- (ADR 0020 · D4). Célula ausente = não pode. Alcance: todos ou proprios (D3).
create table app.matriz_permissoes (
  papel text not null check (papel in ('recepcao', 'profissional')),
  chave text not null references app.chaves_permissao (chave),
  alcance text not null check (alcance in ('todos', 'proprios')),
  primary key (papel, chave)
);
-- A chave primária começa por papel: a chave estrangeira precisa de índice próprio em chave (apagar ou mudar uma
-- chave do catálogo não varre a matriz inteira; guia de índices do Postgres, "Indexes and foreign keys").
create index matriz_permissoes_chave_idx on app.matriz_permissoes (chave);

-- Ninguém com login lê nem grava direto: RLS ligada e forçada, sem política, sem privilégio (ADR 0019 · D1).
alter table app.chaves_permissao enable row level security;
alter table app.chaves_permissao force row level security;
alter table app.matriz_permissoes enable row level security;
alter table app.matriz_permissoes force row level security;
revoke all on table app.chaves_permissao from public, anon, authenticated, service_role;
revoke all on table app.matriz_permissoes from public, anon, authenticated, service_role;

-- Linhas geradas da matriz do código (nesta spec, nenhuma). Molde para as migrations dos módulos:
--   insert into app.chaves_permissao (chave) values ('<modulo>.<acao>');
--   insert into app.matriz_permissoes (papel, chave, alcance) values ('<papel>', '<modulo>.<acao>', '<alcance>');

-- Função de acesso das políticas: estúdio e papel vêm da sessão (app.estudio_da_sessao e app.papel_da_sessao),
-- nunca do pedido (ADR 0005 · D2). Pede uma chave e o alcance que a política exige:
--   'todos'    → só quem tem alcance todos;
--   'proprios' → quem tem proprios ou todos (a política junta a condição de "próprios" do módulo).
-- Falha fechada (ASVS V4.1.5): sem login, sem estúdio escolhido, chave fora do catálogo, alcance fora da lista ou
-- argumento nulo → false. Dona → true em toda chave do catálogo. Uso na política: `(select app.pode('x.ver', 'todos'))`.
create function app.pode(p_chave text, p_alcance text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select case
      when p_alcance is null or p_alcance not in ('todos', 'proprios') then false
      when not exists (select 1 from app.chaves_permissao c where c.chave = p_chave) then false
      when s.papel = 'dona' then true
      else exists (
        select 1 from app.matriz_permissoes m
        where m.papel = s.papel and m.chave = p_chave
          and (m.alcance = 'todos' or p_alcance = 'proprios'))
    end
    from (select app.estudio_da_sessao() as org_id, app.papel_da_sessao() as papel) s
    where s.org_id is not null and s.papel is not null
  ), false)
$$;

revoke all on function app.pode(text, text) from public, anon, authenticated, service_role;
grant execute on function app.pode(text, text) to authenticated;
-- service_role só executa o pré-pedido (ADR 0019 · D17): revoke explícito também nas 4 funções da trava do item 3,
-- que nasceram com revoke só de public e anon (sem efeito se ela já não tinha; o teste 010_ confere a lista).
revoke all on function app.estudio_da_sessao() from service_role;
revoke all on function app.papel_da_sessao() from service_role;
revoke all on function app.eh_dona() from service_role;
revoke all on function app.escolher_estudio(uuid) from service_role;
