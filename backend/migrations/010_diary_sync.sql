-- =====================================================================
-- 010 – Đồng bộ nhật ký giữa mobile và backend (F07)
--   1. Lĩnh vực phát triển (khớp nhãn trên mobile)
--   2. diary_entries: mã do mobile sinh (client_ref), giờ ghi, hoạt động
--      ngoài kho (ý tưởng có sẵn trong app), bản sao nhận xét AI mới nhất
--   3. Ảnh nhật ký: tạm lưu data URL trong diary_media.url (chưa có MinIO)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Lĩnh vực
-- ---------------------------------------------------------------------
INSERT INTO criteria.developmental_domains (code, name, sort_order) VALUES
  ('gross_motor',      'Vận động thô',     1),
  ('fine_motor',       'Vận động tinh',    2),
  ('language',         'Ngôn ngữ',         3),
  ('cognitive',        'Nhận thức',        4),
  ('social_emotional', 'Xã hội – Cảm xúc', 5)
ON CONFLICT (code) DO NOTHING;

-- 009 gắn lĩnh vực cho hoạt động khi bảng còn trống → chạy lại phần đó
INSERT INTO activity.activity_domains (activity_id, domain_id)
SELECT a.id, d.id
FROM activity.activities a
JOIN activity.activity_groups g ON g.id = a.group_id
JOIN criteria.developmental_domains d ON d.code = CASE g.code
    WHEN 'gross_motor' THEN 'gross_motor'
    WHEN 'fine_motor'  THEN 'fine_motor'
    WHEN 'language'    THEN 'language'
  END
ON CONFLICT DO NOTHING;
INSERT INTO activity.activity_domains (activity_id, domain_id)
SELECT a.id, d.id
FROM activity.activities a
JOIN activity.activity_groups g ON g.id = a.group_id
JOIN criteria.developmental_domains d ON d.code IN ('cognitive', 'social_emotional')
WHERE g.code = 'cognitive_social'
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------
-- 2. Nhật ký
-- ---------------------------------------------------------------------
ALTER TABLE diary.diary_entries
    ADD COLUMN client_ref    varchar(80),    -- id nhật ký phía mobile (journal_…)
    ADD COLUMN entry_at      timestamp,      -- giờ ghi theo giờ máy phụ huynh; entry_date = ngày của nó
    ADD COLUMN activity_ref  varchar(80),    -- id hoạt động phía mobile (uuid kho hoặc ý tưởng có sẵn)
    ADD COLUMN activity_name varchar(200),
    ADD COLUMN video_insight jsonb;          -- bản sao nhận xét AI (gốc ở ai_vision.diary_video_insights)

CREATE UNIQUE INDEX diary_entries_client_ref_key
    ON diary.diary_entries (child_id, client_ref) WHERE client_ref IS NOT NULL;
