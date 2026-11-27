-- Migration: add unique constraint on staff_shifts(staff_id, day_of_week)
-- Required for upsert with onConflict in server actions
-- Encoding: UTF-8

alter table staff_shifts
  add constraint uq_staff_shifts_staff_day unique (staff_id, day_of_week);
