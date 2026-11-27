-- Número sequencial da comanda por estúdio e data da quitação da venda.
-- Encoding: UTF-8
--
-- 1. sales.number: "Comanda #0042", sequencial por estúdio, sem corrida. O número vem de um
--    contador por estúdio (sale_counters) atualizado com INSERT ... ON CONFLICT DO UPDATE
--    RETURNING na mesma transação da venda: duas vendas simultâneas do mesmo estúdio esperam
--    uma pela outra e nunca repetem; venda desfeita (rollback) devolve o número. Preenchido
--    por gatilho BEFORE INSERT, então confirm_checkout_atomic e o app antigo continuam como
--    estão. Vendas existentes ganham número pela ordem de criação.
-- 2. sales.paid_at: momento em que a venda ficou quitada (status 'paid'). A comissão e os
--    relatórios passam a usar essa data, não a da criação (comanda criada em 31/out e paga em
--    03/nov é de novembro; parcial de setembro quitada em outubro é de outubro). Preenchido por
--    gatilho quando o status passa a 'paid'; vendas antigas usam o último pagamento.
-- Aditiva: colunas novas anuláveis, nenhuma função existente muda de assinatura.
set client_encoding = 'UTF8';

-- Nenhuma venda nasce entre o preenchimento e a criação do gatilho.
do $$ begin lock table public.sales in share row exclusive mode; end $$;

alter table public.sales
  add column if not exists number integer,
  add column if not exists paid_at timestamptz;

comment on column public.sales.number is
  'Número sequencial da comanda dentro do estúdio (exibido como #0042).';
comment on column public.sales.paid_at is
  'Quando a venda ficou quitada (status paid). Base da comissão e dos relatórios por período.';

-- Contador por estúdio. Só as funções do banco escrevem (sem política = ninguém pela API).
create table if not exists public.sale_counters (
  org_id      uuid    primary key references public.organizations(id) on delete cascade,
  last_number integer not null default 0 check (last_number >= 0)
);
comment on table public.sale_counters is
  'Último número de comanda usado por estúdio (sales.number). Atualizado só pelo gatilho de sales.';
alter table public.sale_counters enable row level security;
revoke all on public.sale_counters from public, anon, authenticated;

-- Preenche as vendas existentes pela ordem de criação (desempate pelo id).
with ordered as (
  select id, row_number() over (partition by org_id order by created_at, id) as n
  from public.sales
  where number is null
)
update public.sales s
   set number = o.n
  from ordered o
 where s.id = o.id;

insert into public.sale_counters (org_id, last_number)
select org_id, max(number)
from public.sales
where number is not null
group by org_id
on conflict (org_id) do update set last_number = greatest(public.sale_counters.last_number, excluded.last_number);

-- Vendas quitadas antes desta migration: último pagamento registrado; sem pagamento
-- (cobertas por pacote ou crédito), a última atualização da venda.
update public.sales s
   set paid_at = coalesce(
         (select max(p.created_at) from public.sale_payments p where p.sale_id = s.id and p.org_id = s.org_id),
         s.updated_at,
         s.created_at)
 where s.status = 'paid' and s.paid_at is null;

create or replace function public.sales_assign_number()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.number is null then
    insert into public.sale_counters as c (org_id, last_number)
    values (new.org_id, 1)
    on conflict (org_id) do update set last_number = c.last_number + 1
    returning c.last_number into new.number;
  end if;
  return new;
end;
$$;

create or replace function public.sales_set_paid_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status = 'paid' and (tg_op = 'INSERT' or old.status is distinct from 'paid') then
    new.paid_at := coalesce(new.paid_at, pg_catalog.now());
  end if;
  return new;
end;
$$;

revoke all on function public.sales_assign_number() from public, anon, authenticated;
revoke all on function public.sales_set_paid_at() from public, anon, authenticated;

drop trigger if exists trg_sales_assign_number on public.sales;
create trigger trg_sales_assign_number
before insert on public.sales
for each row execute function public.sales_assign_number();

drop trigger if exists trg_sales_set_paid_at on public.sales;
create trigger trg_sales_set_paid_at
before insert or update of status on public.sales
for each row execute function public.sales_set_paid_at();

create unique index if not exists sales_org_number_key on public.sales (org_id, number);
create index if not exists sales_org_paid_at_idx on public.sales (org_id, paid_at) where paid_at is not null;

alter table public.sales
  alter column number set not null;
