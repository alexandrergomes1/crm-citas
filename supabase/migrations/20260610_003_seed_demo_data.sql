-- ============================================================
-- KA Beauty OS — Seed de dados de demonstração (produtos, caixa, contas)
-- Encoding: UTF-8 (aplicar SEMPRE via MCP/conexão UTF-8)
-- Idempotente: UUIDs fixos + ON CONFLICT DO NOTHING
-- Org alvo: a1b2c3d4-0000-0000-0000-000000000001
-- ============================================================

-- ─── Produtos ────────────────────────────────────────────────
INSERT INTO products (id, org_id, name, description, price, cost_price, sku, stock_qty, stock_alert, category_id, brand, unit, active, position) VALUES
  ('d1000001-0000-0000-0000-000000000001','a1b2c3d4-0000-0000-0000-000000000001','Sérum Vitamina C 30ml','Antioxidante de uso diário, ilumina e uniformiza',189.90, 72.00,'SER-VITC-30',24,5,'c1000001-0000-0000-0000-000000000002','Dermage','un',true,1),
  ('d1000001-0000-0000-0000-000000000002','a1b2c3d4-0000-0000-0000-000000000001','Protetor Solar FPS 50','Toque seco, com cor, proteção UVA/UVB',119.90, 41.00,'PSL-FPS50',40,8,'c1000001-0000-0000-0000-000000000002','La Roche','un',true,2),
  ('d1000001-0000-0000-0000-000000000003','a1b2c3d4-0000-0000-0000-000000000001','Ácido Hialurônico Sérum','Hidratação profunda e preenchimento de linhas finas',229.90, 88.00,'SER-AH-30',18,5,'c1000001-0000-0000-0000-000000000002','Skinceuticals','un',true,3),
  ('d1000001-0000-0000-0000-000000000004','a1b2c3d4-0000-0000-0000-000000000001','Creme Anti-idade Noturno','Renovação celular com retinol encapsulado',259.90,102.00,'CRM-NOITE',15,4,'c1000001-0000-0000-0000-000000000002','Dermage','un',true,4),
  ('d1000001-0000-0000-0000-000000000005','a1b2c3d4-0000-0000-0000-000000000001','Gel de Limpeza Facial','Limpeza suave para todos os tipos de pele',89.90, 28.00,'GEL-LIMP',50,10,'c1000001-0000-0000-0000-000000000002','Vichy','un',true,5),
  ('d1000001-0000-0000-0000-000000000006','a1b2c3d4-0000-0000-0000-000000000001','Óleo Corporal Firmador','Massagem e firmeza, ativos drenantes',149.90, 53.00,'OLE-FIRM',22,5,'c1000001-0000-0000-0000-000000000003','Weleda','un',true,6),
  ('d1000001-0000-0000-0000-000000000007','a1b2c3d4-0000-0000-0000-000000000001','Máscara Facial Hidratante','Sessão intensiva de hidratação (unidade)',49.90, 14.00,'MAS-HIDR',60,12,'c1000001-0000-0000-0000-000000000002','Caudalie','un',true,7),
  ('d1000001-0000-0000-0000-000000000008','a1b2c3d4-0000-0000-0000-000000000001','Tônico Adstringente','Controle de oleosidade e poros',69.90, 21.00,'TON-ADST',35,8,'c1000001-0000-0000-0000-000000000002','Bioré','un',true,8)
ON CONFLICT (id) DO NOTHING;

-- ─── Caixa (transactions) — junho/2026 ───────────────────────
INSERT INTO transactions (id, org_id, type, category, description, value, method, date, status) VALUES
  ('e1000001-0000-0000-0000-000000000001','a1b2c3d4-0000-0000-0000-000000000001','income','servico','Atendimento — Marina Oliveira',  450.00,'PIX',        '2026-06-09','completed'),
  ('e1000001-0000-0000-0000-000000000002','a1b2c3d4-0000-0000-0000-000000000001','income','servico','Atendimento — Sofia Rodrigues',  280.00,'CARD_CREDIT','2026-06-09','completed'),
  ('e1000001-0000-0000-0000-000000000003','a1b2c3d4-0000-0000-0000-000000000001','income','produto','Venda — Sérum Vitamina C',       189.90,'PIX',        '2026-06-09','completed'),
  ('e1000001-0000-0000-0000-000000000004','a1b2c3d4-0000-0000-0000-000000000001','income','servico','Atendimento — Camila Torres',    620.00,'CARD_DEBIT', '2026-06-10','completed'),
  ('e1000001-0000-0000-0000-000000000005','a1b2c3d4-0000-0000-0000-000000000001','income','servico','Atendimento — Fernanda Lima',    340.00,'CASH',       '2026-06-10','completed'),
  ('e1000001-0000-0000-0000-000000000006','a1b2c3d4-0000-0000-0000-000000000001','expense','fornecedor','Compra de insumos — EstéticaPro', 380.00,'TRANSFER',  '2026-06-08','completed'),
  ('e1000001-0000-0000-0000-000000000007','a1b2c3d4-0000-0000-0000-000000000001','expense','operacional','Material descartável',           95.00,'PIX',       '2026-06-10','completed')
ON CONFLICT (id) DO NOTHING;

-- ─── Contas a pagar (payables) ───────────────────────────────
INSERT INTO payables (id, org_id, description, category, value, due_date, status, vendor) VALUES
  ('f1000001-0000-0000-0000-000000000001','a1b2c3d4-0000-0000-0000-000000000001','Aluguel da clínica — Junho','fixo',     3200.00,'2026-06-05','pending','Imobiliária Silva'),
  ('f1000001-0000-0000-0000-000000000002','a1b2c3d4-0000-0000-0000-000000000001','Fornecedor EstéticaPro','fornecedor',     1850.00,'2026-06-20','pending','EstéticaPro'),
  ('f1000001-0000-0000-0000-000000000003','a1b2c3d4-0000-0000-0000-000000000001','Energia elétrica','fixo',                  420.00,'2026-06-25','pending','EDP'),
  ('f1000001-0000-0000-0000-000000000004','a1b2c3d4-0000-0000-0000-000000000001','Assinatura KA Beauty OS','operacional',    299.00,'2026-06-01','paid','KA Beauty OS')
ON CONFLICT (id) DO NOTHING;
