-- =====================================================================
-- 008 – Lịch tiêm đầy đủ: TCMR + vắc xin dịch vụ
-- Nguồn: lịch TCMR (docs/tieu_chuan_tham_khao.md § 3.1) và lịch tiêm cho trẻ
-- theo tháng tuổi của VNVC (vnvc.vn, cập nhật 30/07/2025). Cần chuyên môn duyệt
-- trước khi phát hành.
--
--   1. Phác đồ thay thế nhau (choice_group / choice_option): mỗi bé theo 1 phương
--      án trong nhóm, vd 5 trong 1 + bại liệt + DPT (TCMR) HOẶC 6 trong 1 (dịch vụ)
--   2. Sản phẩm (tên thương mại) + số liều của từng sản phẩm, vd Rotarix 2 liều
--   3. Mũi theo tuần tuổi (6 tuần), theo khoảng cách với mũi trước, mũi nhắc lặp lại
--   4. Ghi sổ: sản phẩm đã tiêm, lần lặp (cúm hằng năm...)
--   5. Bé theo dõi / bỏ theo dõi vắc xin nào (child_vaccine_plans)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Vắc xin: nhóm phác đồ thay thế
-- ---------------------------------------------------------------------
ALTER TABLE health.vaccines
    ADD COLUMN choice_group   varchar(30),           -- vd 'dtp': các phương án loại trừ nhau
    ADD COLUMN choice_option  varchar(30),           -- vd 'tcmr' / '6in1'; nhiều vắc xin có thể chung 1 phương án
    ADD COLUMN choice_label   varchar(100),          -- tên phương án hiển thị cho phụ huynh
    ADD COLUMN choice_default boolean NOT NULL DEFAULT false,  -- phương án mặc định khi bé chưa chọn
    ADD COLUMN sort_order     smallint NOT NULL DEFAULT 100,
    ADD CONSTRAINT vaccines_choice_check CHECK (
        (choice_group IS NULL AND choice_option IS NULL AND NOT choice_default)
        OR (choice_group IS NOT NULL AND choice_option IS NOT NULL));

-- ---------------------------------------------------------------------
-- 2. Sản phẩm vắc xin
-- ---------------------------------------------------------------------
CREATE TABLE health.vaccine_products (
    id          serial PRIMARY KEY,
    vaccine_id  int NOT NULL REFERENCES health.vaccines(id),
    code        varchar(40) NOT NULL UNIQUE CHECK (code ~ '^[a-z0-9-]{2,40}$'),
    name        varchar(100) NOT NULL,
    origin      varchar(60),                          -- nước sản xuất
    dose_count  smallint CHECK (dose_count BETWEEN 1 AND 20),  -- NULL = theo lịch của vắc xin
    note        text,
    is_active   boolean NOT NULL DEFAULT true
);

-- ---------------------------------------------------------------------
-- 3. Lịch tiêm
-- ---------------------------------------------------------------------
ALTER TABLE health.vaccine_schedules
    ADD COLUMN age_weeks           smallint CHECK (age_weeks BETWEEN 0 AND 52),   -- có giá trị thì thay age_months
    ADD COLUMN after_schedule_id   int REFERENCES health.vaccine_schedules(id),   -- tính từ mũi trước + min_interval_days
    ADD COLUMN repeat_every_months smallint CHECK (repeat_every_months BETWEEN 1 AND 120),
    ADD COLUMN repeat_until_months smallint CHECK (repeat_until_months BETWEEN 1 AND 216),
    ADD COLUMN is_mandatory        boolean,           -- NULL = theo vắc xin; vd mũi nhắc dịch vụ của vắc xin TCMR
    ADD CONSTRAINT vaccine_schedules_after_check CHECK (after_schedule_id IS DISTINCT FROM id),
    ADD CONSTRAINT vaccine_schedules_repeat_check
        CHECK ((repeat_every_months IS NULL) = (repeat_until_months IS NULL));

-- ---------------------------------------------------------------------
-- 4. Sổ tiêm của bé
-- ---------------------------------------------------------------------
ALTER TABLE health.child_vaccinations
    ADD COLUMN product_id int REFERENCES health.vaccine_products(id),
    ADD COLUMN occurrence smallint NOT NULL DEFAULT 0 CHECK (occurrence BETWEEN 0 AND 100),  -- lần lặp của mũi nhắc
    DROP CONSTRAINT child_vaccinations_child_id_schedule_id_key,
    ADD CONSTRAINT child_vaccinations_schedule_occurrence_key UNIQUE (child_id, schedule_id, occurrence),
    ADD CONSTRAINT child_vaccinations_occurrence_kind_check CHECK (schedule_id IS NOT NULL OR occurrence = 0);

-- ---------------------------------------------------------------------
-- 5. Bé theo dõi vắc xin nào. Không có dòng = mặc định:
--    vắc xin ngoài nhóm phác đồ -> theo dõi; trong nhóm -> theo phương án mặc định
--    (hoặc phương án đã có mũi ghi sổ).
-- ---------------------------------------------------------------------
CREATE TABLE health.child_vaccine_plans (
    child_id    uuid NOT NULL REFERENCES child.children(id) ON DELETE CASCADE,
    vaccine_id  int NOT NULL REFERENCES health.vaccines(id),
    included    boolean NOT NULL,
    updated_by  uuid REFERENCES account.users(id),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (child_id, vaccine_id)
);

SELECT common.attach_updated_at_triggers();

-- =====================================================================
-- SEED
-- =====================================================================

-- ---------------------------------------------------------------------
-- Sửa vắc xin đã có (007)
-- ---------------------------------------------------------------------
UPDATE health.vaccines SET name = 'Bại liệt uống (OPV)', disease = 'Bại liệt'
WHERE code = 'polio';
UPDATE health.vaccines SET is_mandatory = false WHERE code = 'rota';   -- VNVC: vắc xin dịch vụ

UPDATE health.vaccines v SET
    choice_group = c.grp, choice_option = c.opt, choice_label = c.label,
    choice_default = c.def, sort_order = c.sort
FROM (VALUES
  ('bcg',     NULL,  NULL,     NULL,                                        false, 10),
  ('hepb',    NULL,  NULL,     NULL,                                        false, 11),
  ('5in1',    'dtp', 'tcmr',   'TCMR: 5 trong 1 + bại liệt OPV/IPV + nhắc DPT', true, 20),
  ('polio',   'dtp', 'tcmr',   'TCMR: 5 trong 1 + bại liệt OPV/IPV + nhắc DPT', true, 21),
  ('dpt',     'dtp', 'tcmr',   'TCMR: 5 trong 1 + bại liệt OPV/IPV + nhắc DPT', true, 23),
  ('rota',    NULL,  NULL,     NULL,                                        false, 30),
  ('measles', NULL,  NULL,     NULL,                                        false, 40),
  ('mr',      NULL,  NULL,     NULL,                                        false, 41),
  ('je',      'je',  'jevax',  'Jevax: 3 mũi (TCMR) + nhắc lúc 5 tuổi',     true, 50)
) AS c(code, grp, opt, label, def, sort)
WHERE v.code = c.code;

-- ---------------------------------------------------------------------
-- Vắc xin mới
-- ---------------------------------------------------------------------
INSERT INTO health.vaccines
    (code, name, disease, is_mandatory, choice_group, choice_option, choice_label, choice_default, sort_order, description)
VALUES
  ('ipv',       'Bại liệt tiêm (IPV)',            'Bại liệt',                                         true,  'dtp', 'tcmr', 'TCMR: 5 trong 1 + bại liệt OPV/IPV + nhắc DPT', true, 22, NULL),
  ('6in1',      'Vaccine 6 trong 1',              'Bạch hầu, ho gà, uốn ván, bại liệt, viêm gan B, Hib', false, 'dtp', '6in1', 'Dịch vụ: 6 trong 1 (thay 5 trong 1, bại liệt, nhắc DPT)', false, 24, 'Có thể dùng 5 trong 1 không chứa viêm gan B (Pentaxim) thay thế.'),
  ('rsv',       'Kháng thể RSV (Beyfortus)',      'Virus hợp bào hô hấp (RSV)',                       false, NULL, NULL, NULL, false, 12, 'Trẻ nguy cơ cao có thể cần thêm 1 liều ở mùa RSV thứ 2 (thường từ 12 tháng).'),
  ('pcv',       'Phế cầu',                        'Viêm phổi, viêm màng não, viêm tai giữa do phế cầu', false, NULL, NULL, NULL, false, 31, NULL),
  ('acyw',      'Não mô cầu ACYW (MenQuadfi/Nimenrix)', 'Viêm màng não do não mô cầu nhóm A, C, Y, W', false, 'men-acyw', 'from-6w', 'MenQuadfi / Nimenrix: từ 6 tuần tuổi', true, 32, 'Mũi nhắc tiếp theo từ 15 tuổi nếu còn nguy cơ.'),
  ('menactra',  'Não mô cầu ACYW (Menactra)',     'Viêm màng não do não mô cầu nhóm A, C, Y, W',      false, 'men-acyw', 'menactra', 'Menactra: từ 9 tháng tuổi', false, 33, 'Mũi nhắc từ 15 tuổi.'),
  ('menb',      'Não mô cầu B (Bexsero)',         'Viêm màng não do não mô cầu nhóm B',               false, 'men-b', 'bexsero', 'Bexsero: từ 2 tháng tuổi', true, 34, NULL),
  ('menbc',     'Não mô cầu BC (VA-Mengoc-BC)',   'Viêm màng não do não mô cầu nhóm B, C',            false, 'men-b', 'mengoc-bc', 'VA-Mengoc-BC: từ 6 tháng tuổi', false, 35, 'Chỉ dùng khi chưa tiêm Bexsero.'),
  ('ev71',      'Tay chân miệng EV71 (Envacgen)', 'Tay chân miệng do EV71',                            false, NULL, NULL, NULL, false, 36, NULL),
  ('flu',       'Cúm mùa',                        'Cúm',                                              false, NULL, NULL, NULL, false, 42, 'Lần đầu tiêm dưới 9 tuổi: 2 mũi cách nhau ít nhất 4 tuần, sau đó nhắc hằng năm.'),
  ('varicella', 'Thủy đậu',                       'Thủy đậu',                                         false, NULL, NULL, NULL, false, 43, NULL),
  ('mmr',       'Sởi – Quai bị – Rubella (MMR)',  'Sởi, quai bị, rubella',                            false, NULL, NULL, NULL, false, 44, NULL),
  ('imojev',    'Viêm não Nhật Bản (Imojev)',     'Viêm não Nhật Bản',                                false, 'je', 'imojev', 'Imojev: 2 mũi, từ 9 tháng tuổi', false, 51, NULL),
  ('hepa',      'Viêm gan A',                     'Viêm gan A',                                       false, 'hepa', 'hepa', 'Viêm gan A (Avaxim): 2 mũi', true, 60, NULL),
  ('twinrix',   'Viêm gan A + B (Twinrix)',       'Viêm gan A, viêm gan B',                           false, 'hepa', 'twinrix', 'Viêm gan A + B (Twinrix): 2 mũi', false, 61, NULL),
  ('typhoid',   'Thương hàn',                     'Thương hàn',                                       false, NULL, NULL, NULL, false, 70, 'Nhắc lại mỗi 3 năm.'),
  ('cholera',   'Tả (Morcvax)',                   'Tả',                                               false, NULL, NULL, NULL, false, 71, 'Vắc xin uống.'),
  ('ppsv23',    'Phế cầu 23 (Pneumovax 23)',      'Bệnh do 23 type phế cầu',                          false, NULL, NULL, NULL, false, 72, 'Thường dành cho trẻ có nguy cơ cao, hỏi ý kiến bác sĩ.'),
  ('dengue',    'Sốt xuất huyết (Qdenga)',        'Sốt xuất huyết Dengue',                            false, NULL, NULL, NULL, false, 80, NULL)
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------
-- Sản phẩm (dose_count chỉ ghi khi khác lịch chung của vắc xin)
-- ---------------------------------------------------------------------
INSERT INTO health.vaccine_products (vaccine_id, code, name, origin, dose_count)
SELECT v.id, p.code, p.name, p.origin, p.doses
FROM (VALUES
  ('hepb',      'heberbiovac',   'Heberbiovac HB',        'Cuba',      NULL::smallint),
  ('hepb',      'gene-hbvax',    'Gene-HBvax',            'Việt Nam',  NULL),
  ('bcg',       'ivactuber',     'Ivactuber',             'Việt Nam',  NULL),
  ('rsv',       'beyfortus',     'Beyfortus (nirsevimab)', 'Pháp',     NULL),
  ('6in1',      'infanrix-hexa', 'Infanrix Hexa',         'Bỉ',        NULL),
  ('6in1',      'hexaxim',       'Hexaxim',               'Pháp',      NULL),
  ('rota',      'rotarix',       'Rotarix',               'Bỉ',        2),
  ('rota',      'rotateq',       'RotaTeq',               'Mỹ',        3),
  ('rota',      'rotavin',       'Rotavin-M1',            'Việt Nam',  2),
  ('pcv',       'synflorix',     'Synflorix',             'Bỉ',        NULL),
  ('pcv',       'prevenar-13',   'Prevenar 13',           'Bỉ',        NULL),
  ('pcv',       'vaxneuvance',   'Vaxneuvance',           'Mỹ',        NULL),
  ('pcv',       'prevenar-20',   'Prevenar 20',           'Bỉ',        NULL),
  ('acyw',      'menquadfi',     'MenQuadfi',             'Mỹ',        NULL),
  ('acyw',      'nimenrix',      'Nimenrix',              'Bỉ',        NULL),
  ('menactra',  'menactra',      'Menactra',              'Mỹ',        NULL),
  ('menb',      'bexsero',       'Bexsero',               'Ý',         NULL),
  ('menbc',     'va-mengoc-bc',  'VA-Mengoc-BC',          'Cuba',      NULL),
  ('ev71',      'envacgen',      'Envacgen',              'Đài Loan',  NULL),
  ('flu',       'vaxigrip-tetra', 'Vaxigrip Tetra',       'Pháp',      NULL),
  ('flu',       'influvac-tetra', 'Influvac Tetra',       'Hà Lan',    NULL),
  ('flu',       'gcflu',         'GCFlu Quadrivalent',    'Hàn Quốc',  NULL),
  ('flu',       'ivacflu-s',     'Ivacflu-S',             'Việt Nam',  NULL),
  ('measles',   'mvvac',         'MVVac',                 'Việt Nam',  NULL),
  ('varicella', 'varilrix',      'Varilrix',              'Bỉ',        NULL),
  ('varicella', 'varivax',       'Varivax',               'Mỹ',        NULL),
  ('varicella', 'barycela',      'Barycela',              'Hàn Quốc',  NULL),
  ('mmr',       'priorix',       'Priorix',               'Bỉ',        NULL),
  ('mmr',       'mmr-ii',        'MMR-II',                'Mỹ',        NULL),
  ('mmr',       'proquad',       'ProQuad (MMR + thủy đậu)', 'Mỹ',     NULL),
  ('je',        'jevax',         'Jevax',                 'Việt Nam',  NULL),
  ('imojev',    'imojev',        'Imojev',                'Thái Lan',  NULL),
  ('hepa',      'avaxim-80',     'Avaxim 80U',            'Pháp',      NULL),
  ('twinrix',   'twinrix',       'Twinrix',               'Bỉ',        NULL),
  ('typhoid',   'typhim-vi',     'Typhim Vi',             'Pháp',      NULL),
  ('typhoid',   'typhoid-vi',    'Typhoid Vi',            'Việt Nam',  NULL),
  ('cholera',   'morcvax',       'Morcvax',               'Việt Nam',  NULL),
  ('ppsv23',    'pneumovax-23',  'Pneumovax 23',          'Mỹ',        NULL),
  ('dengue',    'qdenga',        'Qdenga',                'Đức',       NULL)
) AS p(vaccine_code, code, name, origin, doses)
JOIN health.vaccines v ON v.code = p.vaccine_code
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------
-- Lịch tiêm: sửa mũi đã có + thêm mũi mới
-- after = mã mũi trước; interval = số ngày tối thiểu sau mũi trước
-- ---------------------------------------------------------------------
UPDATE health.vaccine_schedules SET age_weeks = 6, age_months = 1, offset_days = 12, age_from_days = 42,
    note = 'Vaccine uống. Rotarix / Rotavin 2 liều, RotaTeq 3 liều.'
WHERE code = 'rota-1';
UPDATE health.vaccine_schedules SET note = 'Vaccine uống.' WHERE code = 'rota-2';
UPDATE health.vaccine_schedules SET note = 'Chỉ với vaccine 3 liều (RotaTeq).' WHERE code = 'rota-3';

INSERT INTO health.vaccine_schedules
    (vaccine_id, code, dose_number, dose_label, age_weeks, age_months, offset_days, age_from_days,
     min_interval_days, repeat_every_months, repeat_until_months, is_mandatory, note)
SELECT v.id, s.code, s.dose, s.label, s.weeks,
       coalesce(s.months, s.weeks * 7 / 30), coalesce(s.offset_days, s.weeks * 7 % 30, 0),
       coalesce(s.weeks * 7, s.months * 30 + coalesce(s.offset_days, 0)),
       s.interval_days, s.repeat_months, s.until_months, s.mandatory, s.note
FROM (VALUES
  -- vaccine,   code,          dose, label,           weeks, months, offset, interval, repeat, until, mandatory, note
  ('rsv',       'rsv-1',       1, 'Liều duy nhất',    NULL::smallint, 0::smallint, NULL::smallint, NULL::int, NULL::smallint, NULL::smallint, NULL::boolean, 'Nên dùng trong 6 tháng đầu, trước hoặc trong mùa RSV.'),
  ('ipv',       'ipv-1',       1, 'Mũi 1',            NULL, 5,  NULL, NULL, NULL, NULL, NULL, 'Theo lịch TCMR — đối chiếu hướng dẫn Bộ Y tế hiện hành.'),
  ('ipv',       'ipv-2',       2, 'Mũi 2',            NULL, 9,  NULL, NULL, NULL, NULL, NULL, 'Theo lịch TCMR — đối chiếu hướng dẫn Bộ Y tế hiện hành.'),
  ('6in1',      '6in1-1',      1, 'Mũi 1',            6,    NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  ('6in1',      '6in1-2',      2, 'Mũi 2',            NULL, 3,  NULL, 28,   NULL, NULL, NULL, NULL),
  ('6in1',      '6in1-3',      3, 'Mũi 3',            NULL, 4,  NULL, 28,   NULL, NULL, NULL, NULL),
  ('6in1',      '6in1-4',      4, 'Nhắc lại',         NULL, 18, NULL, 180,  NULL, NULL, NULL, 'Trong khoảng 15–24 tháng tuổi.'),
  ('pcv',       'pcv-1',       1, 'Mũi 1',            6,    NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  ('pcv',       'pcv-2',       2, 'Mũi 2',            NULL, 3,  NULL, 28,   NULL, NULL, NULL, NULL),
  ('pcv',       'pcv-3',       3, 'Mũi 3',            NULL, 4,  NULL, 28,   NULL, NULL, NULL, NULL),
  ('pcv',       'pcv-4',       4, 'Nhắc lại',         NULL, 12, NULL, 56,   NULL, NULL, NULL, NULL),
  ('acyw',      'acyw-1',      1, 'Mũi 1',            6,    NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  ('acyw',      'acyw-2',      2, 'Mũi 2',            NULL, 4,  NULL, 56,   NULL, NULL, NULL, NULL),
  ('acyw',      'acyw-3',      3, 'Nhắc lại',         NULL, 12, NULL, 56,   NULL, NULL, NULL, NULL),
  ('menactra',  'menactra-1',  1, 'Mũi 1',            NULL, 9,  NULL, NULL, NULL, NULL, NULL, NULL),
  ('menactra',  'menactra-2',  2, 'Mũi 2',            NULL, 12, NULL, 90,   NULL, NULL, NULL, 'Cách mũi 1 ít nhất 3 tháng.'),
  ('menb',      'menb-1',      1, 'Mũi 1',            NULL, 2,  NULL, NULL, NULL, NULL, NULL, NULL),
  ('menb',      'menb-2',      2, 'Mũi 2',            NULL, 4,  NULL, 56,   NULL, NULL, NULL, NULL),
  ('menb',      'menb-3',      3, 'Nhắc lại',         NULL, 12, NULL, 180,  NULL, NULL, NULL, NULL),
  ('menbc',     'menbc-1',     1, 'Mũi 1',            NULL, 6,  NULL, NULL, NULL, NULL, NULL, NULL),
  ('menbc',     'menbc-2',     2, 'Mũi 2',            NULL, 6,  NULL, 45,   NULL, NULL, NULL, 'Cách mũi 1 từ 6–8 tuần.'),
  ('ev71',      'ev71-1',      1, 'Mũi 1',            NULL, 2,  NULL, NULL, NULL, NULL, NULL, NULL),
  ('ev71',      'ev71-2',      2, 'Mũi 2',            NULL, 4,  NULL, 28,   NULL, NULL, NULL, NULL),
  ('ev71',      'ev71-3',      3, 'Nhắc lại',         NULL, 18, NULL, 180,  NULL, NULL, NULL, 'Trong khoảng 15–24 tháng tuổi.'),
  ('flu',       'flu-1',       1, 'Mũi 1',            NULL, 6,  NULL, NULL, NULL, NULL, NULL, NULL),
  ('flu',       'flu-2',       2, 'Mũi 2',            NULL, 6,  NULL, 28,   NULL, NULL, NULL, 'Cách mũi 1 ít nhất 4 tuần.'),
  ('flu',       'flu-yearly',  3, 'Nhắc hằng năm',    NULL, 18, NULL, 180,  12,   72,   NULL, 'Tiêm nhắc mỗi năm, tốt nhất trước mùa cúm.'),
  ('varicella', 'varicella-1', 1, 'Mũi 1',            NULL, 9,  NULL, NULL, NULL, NULL, NULL, 'Varilrix từ 9 tháng; Varivax / Barycela từ 12 tháng.'),
  ('varicella', 'varicella-2', 2, 'Mũi 2',            NULL, 12, NULL, 90,   NULL, NULL, NULL, 'Cách mũi 1 ít nhất 3 tháng.'),
  ('imojev',    'imojev-1',    1, 'Mũi 1',            NULL, 9,  NULL, NULL, NULL, NULL, NULL, NULL),
  ('imojev',    'imojev-2',    2, 'Mũi 2',            NULL, 24, NULL, 365,  NULL, NULL, NULL, '12–24 tháng sau mũi 1.'),
  ('mmr',       'mmr-1',       1, 'Mũi 1',            NULL, 12, NULL, NULL, NULL, NULL, NULL, 'Priorix có thể tiêm từ 9 tháng.'),
  ('mmr',       'mmr-2',       2, 'Mũi 2',            NULL, 18, NULL, 28,   NULL, NULL, NULL, 'Trong khoảng 15–24 tháng tuổi.'),
  ('mmr',       'mmr-3',       3, 'Mũi 3',            NULL, 48, NULL, 28,   NULL, NULL, NULL, 'Từ 4 tuổi (khuyến cáo với Priorix).'),
  ('hepa',      'hepa-1',      1, 'Mũi 1',            NULL, 12, NULL, NULL, NULL, NULL, NULL, NULL),
  ('hepa',      'hepa-2',      2, 'Mũi 2',            NULL, 18, NULL, 180,  NULL, NULL, NULL, '6–18 tháng sau mũi 1.'),
  ('twinrix',   'twinrix-1',   1, 'Mũi 1',            NULL, 12, NULL, NULL, NULL, NULL, NULL, NULL),
  ('twinrix',   'twinrix-2',   2, 'Mũi 2',            NULL, 18, NULL, 180,  NULL, NULL, NULL, NULL),
  ('typhoid',   'typhoid-1',   1, 'Mũi 1',            NULL, 24, NULL, NULL, 36,   72,   NULL, 'Nhắc lại mỗi 3 năm.'),
  ('cholera',   'cholera-1',   1, 'Liều 1',           NULL, 24, NULL, NULL, NULL, NULL, NULL, 'Vắc xin uống.'),
  ('cholera',   'cholera-2',   2, 'Liều 2',           NULL, 24, NULL, 14,   NULL, NULL, NULL, 'Cách liều 1 ít nhất 2 tuần.'),
  ('ppsv23',    'ppsv23-1',    1, 'Mũi duy nhất',     NULL, 24, NULL, NULL, NULL, NULL, NULL, NULL),
  ('je',        'je-4',        4, 'Nhắc lại',         NULL, 60, NULL, 365,  NULL, NULL, false, 'Mũi nhắc dịch vụ lúc 5 tuổi.'),
  ('dengue',    'dengue-1',    1, 'Mũi 1',            NULL, 48, NULL, NULL, NULL, NULL, NULL, 'Từ 4 tuổi.'),
  ('dengue',    'dengue-2',    2, 'Mũi 2',            NULL, 48, NULL, 90,   NULL, NULL, NULL, '3 tháng sau mũi 1.')
) AS s(vaccine_code, code, dose, label, weeks, months, offset_days, interval_days, repeat_months, until_months, mandatory, note)
JOIN health.vaccines v ON v.code = s.vaccine_code
ON CONFLICT (vaccine_id, dose_number) DO NOTHING;

-- Mũi tính từ mũi trước: cùng vắc xin, số mũi liền trước
UPDATE health.vaccine_schedules s SET after_schedule_id = prev.id
FROM health.vaccine_schedules prev
WHERE prev.vaccine_id = s.vaccine_id AND prev.dose_number = s.dose_number - 1
  AND s.after_schedule_id IS NULL
  AND s.code IN ('6in1-2','6in1-3','6in1-4','pcv-2','pcv-3','pcv-4','acyw-2','acyw-3',
                 'menactra-2','menb-2','menb-3','menbc-2','ev71-2','ev71-3','flu-2','flu-yearly',
                 'varicella-2','imojev-2','mmr-2','mmr-3','hepa-2','twinrix-2','cholera-2','je-4',
                 'dengue-2','rota-2','rota-3','je-2');

-- Rotavirus & VNNB (007) có khoảng cách tối thiểu với mũi trước
UPDATE health.vaccine_schedules SET min_interval_days = 28 WHERE code IN ('rota-2', 'rota-3');
UPDATE health.vaccine_schedules SET min_interval_days = 7  WHERE code = 'je-2';
UPDATE health.vaccine_schedules SET min_interval_days = 365 WHERE code = 'je-3';
UPDATE health.vaccine_schedules s SET after_schedule_id = prev.id
FROM health.vaccine_schedules prev
WHERE s.code = 'je-3' AND prev.code = 'je-2';
