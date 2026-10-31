-- =====================================================================
-- 004 – Nhận xét AI cho video nhật ký theo hoạt động (giai đoạn 1 + 2)
--   - Giai đoạn 1: một Video AI API dùng chung cho mọi nhóm hoạt động,
--     trả về quan sát + gợi ý, KHÔNG chấm đạt / chưa đạt.
--   - Giai đoạn 2: nhóm vận động đo thêm bằng MediaPipe (evidence), đưa vào
--     prompt làm bằng chứng cho số lần / số giây.
-- Tách khỏi video_analysis_jobs / ai_evaluations (migration 002): bảng đó
-- gắn với diary_media trên MinIO và chấm điểm theo rubric (overall NOT NULL),
-- còn ở đây video chỉ là file tạm, xóa ngay sau khi phân tích.
-- child_id, requested_by là uuid bên DB chính, không có khóa ngoại.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS ai_vision;

CREATE TABLE IF NOT EXISTS ai_vision.diary_video_insights (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id       uuid NOT NULL,                     -- child.children.id
    requested_by   uuid NOT NULL,                     -- account.users.id
    activity_ref   varchar(64) NOT NULL,              -- id hoạt động phía mobile / activity.activities.id
    activity_group varchar(20) NOT NULL
                   CHECK (activity_group IN ('gross_motor','fine_motor','language',
                                             'cognitive_social','music','storytelling')),
    -- Backend gửi: hoạt động, tiêu chí quan sát của nhóm, tuổi bé, ghi chú phụ huynh,
    -- danh sách số đo cần tính (giai đoạn 2)
    context        jsonb NOT NULL,
    video_path     text,                              -- file tạm; NULL khi đã xóa
    video_seconds  numeric(5,1),
    consented_at   timestamptz NOT NULL,              -- phụ huynh đồng ý gửi video cho AI
    status         varchar(10) NOT NULL DEFAULT 'pending'
                   CHECK (status IN ('pending','running','done','rejected','failed')),
    attempts       smallint NOT NULL DEFAULT 0,
    run_after      timestamptz NOT NULL DEFAULT now(),  -- lùi lịch khi retry
    started_at     timestamptz,
    finished_at    timestamptz,
    -- { "available": true, "detectionRatio": 0.91, "metrics": [ {key, label, value, unit} ] }
    evidence       jsonb,
    -- { "canAssess", "videoIssue", "observations", "comment", "positives",
    --   "nextSteps", "seeSpecialist", "specialistNote" }
    result         jsonb,
    llm_model      varchar(50),
    prompt_version varchar(20),
    usage          jsonb,                             -- token vào / ra để theo dõi chi phí
    error          text,                              -- lỗi nội bộ, không trả cho mobile
    message        text,                              -- lý do hiển thị cho phụ huynh (rejected / failed)
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    CHECK (status <> 'done' OR result IS NOT NULL)
);

-- Worker lấy việc:
--   SELECT ... WHERE status = 'pending' AND run_after <= now()
--   ORDER BY created_at FOR UPDATE SKIP LOCKED LIMIT 1;
CREATE INDEX IF NOT EXISTS diary_video_insights_pending_idx
    ON ai_vision.diary_video_insights (run_after, created_at) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS diary_video_insights_child_idx
    ON ai_vision.diary_video_insights (child_id, created_at DESC);
-- Job treo (worker chết giữa chừng) được trả lại hàng đợi
CREATE INDEX IF NOT EXISTS diary_video_insights_running_idx
    ON ai_vision.diary_video_insights (started_at) WHERE status = 'running';

DROP TRIGGER IF EXISTS trg_diary_video_insights_updated_at ON ai_vision.diary_video_insights;
CREATE TRIGGER trg_diary_video_insights_updated_at BEFORE UPDATE ON ai_vision.diary_video_insights
    FOR EACH ROW EXECUTE FUNCTION common.set_updated_at();
