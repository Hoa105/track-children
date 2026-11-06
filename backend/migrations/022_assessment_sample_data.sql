-- 022 - Local/demo data for the developmental assessment admin UI.
-- Safe to run more than once: stable codes and the question-set code are unique.

BEGIN;

INSERT INTO development.question_sets
    (id, code, age_months, version, locale, source_name, status, created_by)
VALUES
    (
        'a7a7d2e4-6bc4-4cc4-9ec4-2b6e887a1200',
        'demo-12m-v1',
        12,
        'v1',
        'vi-VN',
        'Bộ mẫu kiểm thử đánh giá phát triển',
        'in_review',
        (SELECT id FROM admin.admin_users WHERE email = 'sample.admin@trackchildren.vn' LIMIT 1)
    )
ON CONFLICT (code) DO NOTHING;

INSERT INTO development.content_items
    (id, kind, stable_code, question_set_id, source_domain, app_domain, order_index, created_by, updated_by)
SELECT
    seed.id,
    'skill',
    seed.stable_code,
    qs.id,
    seed.source_domain,
    seed.app_domain,
    seed.order_index,
    admin.id,
    admin.id
FROM (
    VALUES
        ('a7a7d2e4-6bc4-4cc4-9ec4-2b6e887a1201'::uuid, 'demo-12m-gross-01', 'movement_physical', 'gross_motor', 1),
        ('a7a7d2e4-6bc4-4cc4-9ec4-2b6e887a1202'::uuid, 'demo-12m-fine-01', 'movement_physical', 'fine_motor', 2),
        ('a7a7d2e4-6bc4-4cc4-9ec4-2b6e887a1203'::uuid, 'demo-12m-language-01', 'language_communication', 'language_communication', 3),
        ('a7a7d2e4-6bc4-4cc4-9ec4-2b6e887a1204'::uuid, 'demo-12m-cognitive-01', 'cognitive', 'cognitive', 4),
        ('a7a7d2e4-6bc4-4cc4-9ec4-2b6e887a1205'::uuid, 'demo-12m-social-01', 'social_emotional', 'social_emotional', 5),
        ('a7a7d2e4-6bc4-4cc4-9ec4-2b6e887a1206'::uuid, 'demo-12m-language-02', 'language_communication', 'language_communication', 6)
) AS seed(id, stable_code, source_domain, app_domain, order_index)
JOIN development.question_sets qs ON qs.code = 'demo-12m-v1'
LEFT JOIN admin.admin_users admin ON admin.email = 'sample.admin@trackchildren.vn'
ON CONFLICT (kind, stable_code) DO NOTHING;

INSERT INTO development.content_revisions
    (content_item_id, revision, locale, payload, source_refs, created_by)
SELECT
    ci.id,
    1,
    'vi-VN',
    seed.payload::jsonb,
    '[{"type":"demo","label":"Dữ liệu mẫu kiểm thử giao diện admin"}]'::jsonb,
    admin.id
FROM (
    VALUES
        ('demo-12m-gross-01', '{"prompt":"Bé có thể tự đứng lên và bước vài bước khi có người hỗ trợ không?","answerOptions":["Đạt","Chưa đạt","Chưa quan sát"]}'),
        ('demo-12m-fine-01', '{"prompt":"Bé có thể nhặt một vật nhỏ bằng ngón cái và ngón trỏ không?","answerOptions":["Đạt","Chưa đạt","Chưa quan sát"]}'),
        ('demo-12m-language-01', '{"prompt":"Bé có phản ứng hoặc quay lại khi được gọi tên không?","answerOptions":["Đạt","Chưa đạt","Chưa quan sát"]}'),
        ('demo-12m-cognitive-01', '{"prompt":"Bé có tìm đồ vật bị che khuất một phần không?","answerOptions":["Đạt","Chưa đạt","Chưa quan sát"]}'),
        ('demo-12m-social-01', '{"prompt":"Bé có bắt chước các cử chỉ đơn giản của người lớn không?","answerOptions":["Đạt","Chưa đạt","Chưa quan sát"]}'),
        ('demo-12m-language-02', '{"prompt":"Bé có sử dụng âm hoặc từ đơn giản để yêu cầu điều mình muốn không?","answerOptions":["Đạt","Chưa đạt","Chưa quan sát"]}')
) AS seed(stable_code, payload)
JOIN development.content_items ci
  ON ci.stable_code = seed.stable_code AND ci.kind = 'skill'
LEFT JOIN admin.admin_users admin ON admin.email = 'sample.admin@trackchildren.vn'
ON CONFLICT (content_item_id, revision) DO NOTHING;

COMMIT;
