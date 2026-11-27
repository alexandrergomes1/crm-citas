-- Chaves estrangeiras compostas: registro filho só aponta para pai do MESMO estúdio.
-- Encoding: UTF-8
--
-- Revisão de banco (29 out): fora do catálogo, nada impedia, por exemplo, um agendamento do
-- estúdio A apontar para a cliente do estúdio B (bastava conhecer o UUID e editar a linha).
-- As FKs simples continuam (definem o ON DELETE); as compostas garantem o mesmo org_id.
-- Produção conferida antes: zero linhas fora do padrão em todas as relações abaixo.

alter table public.appointments add constraint appointments_id_org_key unique (id, org_id);
alter table public.sales add constraint sales_id_org_key unique (id, org_id);

alter table public.appointments
  add constraint appointments_client_same_org foreign key (org_id, client_id) references public.clients (org_id, id),
  add constraint appointments_staff_same_org foreign key (staff_id, org_id) references public.staff_members (id, org_id);

alter table public.appointment_items
  add constraint appointment_items_appointment_same_org foreign key (appointment_id, org_id) references public.appointments (id, org_id);

alter table public.appointment_deposits
  add constraint appointment_deposits_appointment_same_org foreign key (appointment_id, org_id) references public.appointments (id, org_id);

alter table public.sales
  add constraint sales_appointment_same_org foreign key (appointment_id, org_id) references public.appointments (id, org_id),
  add constraint sales_client_same_org foreign key (org_id, client_id) references public.clients (org_id, id),
  add constraint sales_staff_same_org foreign key (staff_id, org_id) references public.staff_members (id, org_id);

alter table public.sale_items
  add constraint sale_items_sale_same_org foreign key (sale_id, org_id) references public.sales (id, org_id);

alter table public.sale_payments
  add constraint sale_payments_sale_same_org foreign key (sale_id, org_id) references public.sales (id, org_id);

alter table public.transactions
  add constraint transactions_sale_same_org foreign key (sale_id, org_id) references public.sales (id, org_id),
  add constraint transactions_client_same_org foreign key (org_id, client_id) references public.clients (org_id, id);

alter table public.client_balance_entries
  add constraint client_balance_entries_client_same_org foreign key (org_id, client_id) references public.clients (org_id, id);

alter table public.loyalty_point_entries
  add constraint loyalty_point_entries_client_same_org foreign key (org_id, client_id) references public.clients (org_id, id);

alter table public.client_entitlements
  add constraint client_entitlements_client_same_org foreign key (org_id, client_id) references public.clients (org_id, id);
