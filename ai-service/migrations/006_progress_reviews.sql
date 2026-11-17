-- =====================================================================
-- 006 – Đánh giá tổng hợp nhiều nhận xét video (theo dõi lâu dài)
--   Ba mẹ chọn "Đánh giá" trên các video đã phân tích của cùng một hoạt
--   động / nhóm hoạt động → AI đọc lại các nhận xét + số đo (không xem lại
--   video vì video đã bị xóa) và viết nhận xét về sự thay đổi theo thời gian.
--   Vẫn KHÔNG chấm đạt / chưa đạt.
--   Cùng một tập insight + cùng prompt_version → dùng lại kết quả cũ.
-- =====================================================================

CREATE TABLE IF NOT EXISTS ai_vision.progress_reviews (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id       uuid NOT NULL,                     -- child.children.id
    requested_by   uuid NOT NULL,                     -- account.users.id
    activity_ref   varchar(64),                       -- NULL khi gom nhiều hoạt động cùng nhóm
    activity_group varchar(20) NOT NULL
                   CHECK (activity_group IN ('gross_motor','fine_motor','language',
                                             'cognitive_social','music','storytelling')),
    activity_title varchar(300) NOT NULL,
    insight_ids    uuid[] NOT NULL CHECK (cardinality(insight_ids) >= 2),  -- đã sắp xếp
    period_from    timestamptz NOT NULL,              -- video sớm nhất
    period_to      timestamptz NOT NULL,              -- video muộn nhất
    -- { "summary", "progress", "keepPracticing", "nextSteps", "seeSpecialist", "specialistNote" }
    result         jsonb NOT NULL,
    -- [ { key, label, unit, points: [ {insightId, at, value} ], change } ]
    metrics        jsonb NOT NULL DEFAULT '[]'::jsonb,
    llm_model      varchar(50),
    prompt_version varchar(20) NOT NULL,
    usage          jsonb,
    created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS progress_reviews_child_idx
    ON ai_vision.progress_reviews (child_id, created_at DESC);
CREATE INDEX IF NOT EXISTS progress_reviews_reuse_idx
    ON ai_vision.progress_reviews (child_id, prompt_version, insight_ids);
