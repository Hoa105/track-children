-- =====================================================================
-- 006 – AI nhận xét video theo luật (giai đoạn 2)
--   - Admin bật AI và cấu hình rubric cho từng hoạt động (chỉ nhóm vận động thô / tinh)
--   - Loại thông báo khi có nhận xét AI
--   - Quyền soạn rubric và gán nhãn video
-- Kết quả phân tích nằm ở DB AI (ai_vision), xem ai-service/migrations/002_video_analysis.sql.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Rubric AI của hoạt động
-- ai_rubric (jsonb), vd:
--   { "version": 1, "pose": "body",
--     "required_visible": ["left_ankle","right_ankle","left_hip","right_hip"],
--     "checks": [ { "step_number": 1, "feature": "both_ankles_lift",
--                   "params": {...}, "pass_if": { "count_gte": 2 } } ] }
-- step_number khớp activity.activity_steps.step_number. Sửa rubric phải tăng "version"
-- (ai_vision.ai_evaluations.rubric_version ghi lại version đã dùng).
-- ---------------------------------------------------------------------
ALTER TABLE activity.activities
    ADD COLUMN ai_assessable boolean NOT NULL DEFAULT false,
    ADD COLUMN ai_rubric     jsonb,
    ADD CONSTRAINT activities_ai_rubric_check CHECK (
        ai_rubric IS NULL OR (
            jsonb_typeof(ai_rubric) = 'object'
            AND jsonb_typeof(ai_rubric -> 'version') = 'number'
            AND jsonb_typeof(ai_rubric -> 'checks') = 'array'
            AND jsonb_array_length(ai_rubric -> 'checks') > 0
        )),
    ADD CONSTRAINT activities_ai_assessable_needs_rubric
        CHECK (NOT ai_assessable OR ai_rubric IS NOT NULL);

CREATE INDEX activities_ai_assessable_idx ON activity.activities (id) WHERE ai_assessable;

-- ---------------------------------------------------------------------
-- 2. Thông báo khi đã có nhận xét AI cho video nhật ký
-- ---------------------------------------------------------------------
INSERT INTO notification.notification_types (code, name, trigger_event, default_channel) VALUES
  ('ai_video_result', 'Đã có nhận xét AI cho video nhật ký', 'ai_video_evaluated', 'push')
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------
-- 3. Quyền admin
-- ---------------------------------------------------------------------
INSERT INTO admin.permissions (code, description) VALUES
  ('ai.rubric.manage', 'Bật AI và soạn rubric đánh giá video cho hoạt động'),
  ('ai.video.label',   'Xem video đã có consent và gán nhãn chuyên gia')
ON CONFLICT (code) DO NOTHING;

INSERT INTO admin.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM admin.roles r
JOIN admin.permissions p ON p.code IN ('ai.rubric.manage', 'ai.video.label')
WHERE r.code IN ('super_admin', 'content_manager')
ON CONFLICT DO NOTHING;
