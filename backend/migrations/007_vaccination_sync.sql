-- =====================================================================
-- 007 – Đồng bộ tiêm chủng giữa backend, mobile và web admin (F05.2, F16.1)
--   1. vaccine_schedules: mã mũi ổn định (khớp VaccineDose.id của mobile),
--      mốc tuổi theo tháng + số ngày lệch (mobile tính ngày dự kiến theo lịch
--      tháng, không theo số ngày), ẩn mũi thay vì xóa (đã có lịch sử tiêm tham chiếu)
--   2. child_vaccinations: mã do mobile sinh cho mũi tự thêm (custom-…)
--   3. Seed danh mục vắc xin + lịch TCMR (docs/tieu_chuan_tham_khao.md § 3.1)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Lịch tiêm
-- ---------------------------------------------------------------------
ALTER TABLE health.vaccine_schedules
    ADD COLUMN code        varchar(40) UNIQUE CHECK (code ~ '^[a-z0-9-]{2,40}$'),
    ADD COLUMN age_months  smallint CHECK (age_months BETWEEN 0 AND 216),
    ADD COLUMN offset_days smallint NOT NULL DEFAULT 0 CHECK (offset_days BETWEEN 0 AND 365),
    ADD COLUMN is_active   boolean NOT NULL DEFAULT true;

-- Dòng cũ (nếu có) suy ra mốc tháng từ age_from_days
UPDATE health.vaccine_schedules
SET age_months = age_from_days / 30, offset_days = age_from_days % 30
WHERE age_months IS NULL;

ALTER TABLE health.vaccine_schedules ALTER COLUMN age_months SET NOT NULL;

-- ---------------------------------------------------------------------
-- 2. Mũi tự thêm: giữ mã của mobile để cập nhật / xóa đúng dòng
-- ---------------------------------------------------------------------
ALTER TABLE health.child_vaccinations
    ADD COLUMN client_ref varchar(80),   -- VaccineDose.id của mũi tự thêm
    ADD COLUMN group_ref  varchar(80),   -- VaccineDose.groupId: các mũi của cùng 1 vắc xin tự thêm
    ADD CONSTRAINT child_vaccinations_client_ref_check
        CHECK ((schedule_id IS NULL) = (client_ref IS NOT NULL));

CREATE UNIQUE INDEX child_vaccinations_client_ref_key
    ON health.child_vaccinations (child_id, client_ref) WHERE client_ref IS NOT NULL;

-- ---------------------------------------------------------------------
-- 3. Seed danh mục & lịch TCMR (khớp mobile/lib/services/vaccination_schedule.dart)
-- ---------------------------------------------------------------------
INSERT INTO health.vaccines (code, name, disease, is_mandatory) VALUES
  ('bcg',     'BCG',                        'Lao',                                       true),
  ('hepb',    'Viêm gan B sơ sinh',         'Viêm gan B',                                true),
  ('5in1',    'Vaccine 5 trong 1',          'Bạch hầu, ho gà, uốn ván, viêm gan B, Hib', true),
  ('polio',   'Bại liệt (OPV/IPV)',         'Bại liệt',                                  true),
  ('rota',    'Rotavirus',                  'Tiêu chảy do Rotavirus',                    true),
  ('measles', 'Sởi',                        'Sởi',                                       true),
  ('je',      'Viêm não Nhật Bản B',        'Viêm não Nhật Bản',                         true),
  ('dpt',     'Bạch hầu – ho gà – uốn ván', 'Bạch hầu, ho gà, uốn ván',                  true),
  ('mr',      'Sởi – Rubella (MR)',         'Sởi, Rubella',                              true)
ON CONFLICT (code) DO NOTHING;

INSERT INTO health.vaccine_schedules
    (vaccine_id, code, dose_number, dose_label, age_months, offset_days, age_from_days, note)
SELECT v.id, s.code, s.dose_number, s.dose_label, s.age_months, s.offset_days,
       s.age_months * 30 + s.offset_days, s.note
FROM (VALUES
  ('bcg',     'bcg',         1, 'Mũi duy nhất', 0,  0,  'Tiêm trong 24 giờ đầu sau sinh (hoặc càng sớm càng tốt trong tháng đầu).'),
  ('hepb',    'hepb-0',      1, 'Liều sơ sinh', 0,  0,  'Tiêm trong 24 giờ đầu sau sinh.'),
  ('5in1',    '5in1-1',      1, 'Mũi 1',        2,  0,  NULL),
  ('polio',   'polio-1',     1, 'Mũi 1',        2,  0,  NULL),
  ('rota',    'rota-1',      1, 'Liều 1',       2,  0,  'Vaccine uống.'),
  ('5in1',    '5in1-2',      2, 'Mũi 2',        3,  0,  NULL),
  ('polio',   'polio-2',     2, 'Mũi 2',        3,  0,  NULL),
  ('rota',    'rota-2',      2, 'Liều 2',       3,  0,  'Vaccine uống.'),
  ('5in1',    '5in1-3',      3, 'Mũi 3',        4,  0,  NULL),
  ('polio',   'polio-3',     3, 'Mũi 3',        4,  0,  NULL),
  ('rota',    'rota-3',      3, 'Liều 3',       4,  0,  'Chỉ áp dụng với loại vaccine 3 liều.'),
  ('measles', 'measles-1',   1, 'Mũi 1',        9,  0,  NULL),
  ('je',      'je-1',        1, 'Mũi 1',        12, 0,  'Theo lịch địa phương.'),
  ('je',      'je-2',        2, 'Mũi 2',        12, 14, 'Theo lịch địa phương, 1–2 tuần sau mũi 1.'),
  ('dpt',     'dpt-booster', 1, 'Nhắc lại',     18, 0,  NULL),
  ('mr',      'mr',          1, 'Nhắc lại',     18, 0,  NULL),
  ('je',      'je-3',        3, 'Mũi 3',        24, 0,  'Theo lịch địa phương, 1 năm sau mũi 2.')
) AS s(vaccine_code, code, dose_number, dose_label, age_months, offset_days, note)
JOIN health.vaccines v ON v.code = s.vaccine_code
ON CONFLICT (vaccine_id, dose_number) DO NOTHING;
