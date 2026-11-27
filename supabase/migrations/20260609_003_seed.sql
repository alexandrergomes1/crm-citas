-- ============================================================
-- KA Beauty OS — Migration 003: Seed Data
-- Encoding: UTF-8
-- IMPORTANTE: Execute APÓS criar o usuário no Supabase Auth
-- ============================================================

-- ─── 1. Organização KA Beauty ─────────────────────────────────────────────────
insert into organizations (id, slug, name, phone, email, city, timezone, currency, locale, plan)
values (
  'a1b2c3d4-0000-0000-0000-000000000001',
  'ka-beauty',
  'KA Beauty Clínica',
  '(11) 99000-1234',
  'contato@kabeauty.com.br',
  'São Paulo',
  'America/Sao_Paulo',
  'BRL',
  'pt-BR',
  'premium'
);

-- ─── 2. Localização principal ─────────────────────────────────────────────────
insert into locations (id, org_id, name, address, city, phone, timezone)
values (
  'b1b2c3d4-0000-0000-0000-000000000001',
  'a1b2c3d4-0000-0000-0000-000000000001',
  'Unidade Jardins',
  'Rua Oscar Freire, 123 — Jardins',
  'São Paulo',
  '(11) 3000-1234',
  'America/Sao_Paulo'
);

-- ─── 3. Categorias de serviços ────────────────────────────────────────────────
insert into service_categories (id, org_id, name, color, position) values
  ('c1000001-0000-0000-0000-000000000001', 'a1b2c3d4-0000-0000-0000-000000000001', 'Medicina Estética',  '#F43F5E', 0),
  ('c1000001-0000-0000-0000-000000000002', 'a1b2c3d4-0000-0000-0000-000000000001', 'Estética Facial',   '#8B5CF6', 1),
  ('c1000001-0000-0000-0000-000000000003', 'a1b2c3d4-0000-0000-0000-000000000001', 'Estética Corporal', '#10B981', 2),
  ('c1000001-0000-0000-0000-000000000004', 'a1b2c3d4-0000-0000-0000-000000000001', 'Sobrancelha & Cílios', '#F59E0B', 3);

-- ─── 4. Serviços (sem ID fixo — gerado automaticamente) ──────────────────────
insert into services (org_id, category_id, name, price, duration_minutes, buffer_minutes, commission_pct, online_booking, position) values
  -- Medicina Estética
  ('a1b2c3d4-0000-0000-0000-000000000001', 'c1000001-0000-0000-0000-000000000001', 'Botox Facial', 890.00, 60, 15, 30, true, 0),
  ('a1b2c3d4-0000-0000-0000-000000000001', 'c1000001-0000-0000-0000-000000000001', 'Preenchimento Labial', 1200.00, 60, 15, 30, true, 1),
  ('a1b2c3d4-0000-0000-0000-000000000001', 'c1000001-0000-0000-0000-000000000001', 'Bioestimulador de Colágeno', 2400.00, 90, 15, 35, true, 2),
  -- Facial
  ('a1b2c3d4-0000-0000-0000-000000000001', 'c1000001-0000-0000-0000-000000000002', 'Limpeza de Pele', 280.00, 60, 10, 25, true, 0),
  ('a1b2c3d4-0000-0000-0000-000000000001', 'c1000001-0000-0000-0000-000000000002', 'Peeling Químico', 380.00, 60, 10, 25, true, 1),
  ('a1b2c3d4-0000-0000-0000-000000000001', 'c1000001-0000-0000-0000-000000000002', 'Microagulhamento', 450.00, 90, 15, 25, true, 2),
  ('a1b2c3d4-0000-0000-0000-000000000001', 'c1000001-0000-0000-0000-000000000002', 'Hydra Glow', 320.00, 60, 10, 25, true, 3),
  -- Corporal
  ('a1b2c3d4-0000-0000-0000-000000000001', 'c1000001-0000-0000-0000-000000000003', 'Drenagem Linfática', 180.00, 60, 5, 20, true, 0),
  ('a1b2c3d4-0000-0000-0000-000000000001', 'c1000001-0000-0000-0000-000000000003', 'Massagem Modeladora', 220.00, 60, 5, 20, true, 1),
  -- Sobrancelha & Cílios
  ('a1b2c3d4-0000-0000-0000-000000000001', 'c1000001-0000-0000-0000-000000000004', 'Design de Sobrancelha', 80.00, 45, 5, 20, true, 0),
  ('a1b2c3d4-0000-0000-0000-000000000001', 'c1000001-0000-0000-0000-000000000004', 'Extensão de Cílios', 250.00, 120, 10, 25, true, 1),
  ('a1b2c3d4-0000-0000-0000-000000000001', 'c1000001-0000-0000-0000-000000000004', 'Combo Cílios + Sobrancelha', 310.00, 150, 10, 25, true, 2);

-- ─── 5. Profissionais ─────────────────────────────────────────────────────────
insert into staff_members (id, org_id, location_id, name, display_name, email, color, role, commission_pct, position) values
  ('e0000001-0000-0000-0000-000000000001', 'a1b2c3d4-0000-0000-0000-000000000001', 'b1b2c3d4-0000-0000-0000-000000000001',
   'Ana Lima', 'Ana', 'ana@kabeauty.com.br', '#F43F5E', 'professional', 30, 0),
  ('e0000001-0000-0000-0000-000000000002', 'a1b2c3d4-0000-0000-0000-000000000001', 'b1b2c3d4-0000-0000-0000-000000000001',
   'Beatriz Costa', 'Beatriz', 'beatriz@kabeauty.com.br', '#8B5CF6', 'professional', 30, 1),
  ('e0000001-0000-0000-0000-000000000003', 'a1b2c3d4-0000-0000-0000-000000000001', 'b1b2c3d4-0000-0000-0000-000000000001',
   'Carla Mendes', 'Carla', 'carla@kabeauty.com.br', '#10B981', 'professional', 25, 2),
  ('e0000001-0000-0000-0000-000000000004', 'a1b2c3d4-0000-0000-0000-000000000001', 'b1b2c3d4-0000-0000-0000-000000000001',
   'Diana Santos', 'Diana', 'diana@kabeauty.com.br', '#F59E0B', 'professional', 25, 3);

-- ─── 6. Turnos dos profissionais (Seg–Sex, 8h–18h) ──────────────────────────
insert into staff_shifts (org_id, staff_id, day_of_week, start_time, end_time)
select
  'a1b2c3d4-0000-0000-0000-000000000001',
  s.id,
  d.day,
  '08:00',
  '18:00'
from staff_members s
cross join (values (1),(2),(3),(4),(5)) as d(day)
where s.org_id = 'a1b2c3d4-0000-0000-0000-000000000001';

-- ─── 7. Clientes de exemplo (sem ID fixo — gerado automaticamente) ───────────
insert into clients (org_id, full_name, phone, email, birth_date, tags, status, total_spent, loyalty_tier) values
  ('a1b2c3d4-0000-0000-0000-000000000001', 'Marina Oliveira', '(11) 99123-4567', 'marina@email.com', '1988-03-15', '{VIP}', 'active', 4200.00, 'gold'),
  ('a1b2c3d4-0000-0000-0000-000000000001', 'Sofia Rodrigues', '(11) 98234-5678', 'sofia@email.com', '1992-07-22', '{Fiel}', 'active', 2800.00, 'silver'),
  ('a1b2c3d4-0000-0000-0000-000000000001', 'Camila Torres', '(11) 97345-6789', 'camila@email.com', '1995-11-30', '{Novo}', 'active', 380.00, 'bronze'),
  ('a1b2c3d4-0000-0000-0000-000000000001', 'Fernanda Lima', '(11) 96456-7890', 'fernanda@email.com', '1985-05-10', '{VIP}', 'active', 6750.00, 'platinum'),
  ('a1b2c3d4-0000-0000-0000-000000000001', 'Juliana Matos', '(11) 95567-8901', 'juliana@email.com', '1990-09-18', '{Fiel}', 'active', 1920.00, 'silver');

-- ─── 8. Vincular usuário owner ────────────────────────────────────────────────
-- Substitua YOUR-USER-UUID pelo UUID de Authentication → Users
-- insert into profiles (user_id, org_id, full_name)
-- values ('YOUR-USER-UUID', 'a1b2c3d4-0000-0000-0000-000000000001', 'Seu Nome');
--
-- insert into user_roles (user_id, org_id, role, location_id)
-- values ('YOUR-USER-UUID', 'a1b2c3d4-0000-0000-0000-000000000001', 'owner', 'b1b2c3d4-0000-0000-0000-000000000001');
