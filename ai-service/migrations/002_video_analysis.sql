-- =====================================================================
-- 002 – Phân tích video nhật ký (giai đoạn 2), schema ai_vision
--   - Hàng đợi xử lý video (FOR UPDATE SKIP LOCKED, không cần Redis)
--   - Kết quả AI theo rule / model / llm, phản hồi 👍/👎 của phụ huynh
--   - Chuỗi khung xương (MediaPipe Pose) — CHỈ lưu khi trẻ có consent AI
-- media_id, entry_id, child_id, activity_id, user_id là uuid bên DB chính,
-- không có khóa ngoại. Xóa trẻ / xóa video / rút consent: backend gọi API
-- ai-service xóa dữ liệu tương ứng (CASCADE từ video_analysis_jobs).
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS ai_vision;

-- ---------------------------------------------------------------------
-- 1. Hàng đợi xử lý video — mỗi diary_media tối đa 1 job
-- Worker lấy việc:
--   SELECT ... FROM ai_vision.video_analysis_jobs
--   WHERE status = 'pending' AND run_after <= now()
--   ORDER BY created_at FOR UPDATE SKIP LOCKED LIMIT 1;
-- skipped: hoạt động không bật AI, video không thấy đủ khớp (required_visible)...
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ai_vision.video_analysis_jobs (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    media_id      uuid NOT NULL UNIQUE,              -- diary.diary_media.id
    entry_id      uuid NOT NULL,                     -- diary.diary_entries.id
    child_id      uuid NOT NULL,
    activity_id   uuid NOT NULL,
    storage_key   text NOT NULL,                     -- khóa object MinIO
    status        varchar(10) NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','running','done','failed','skipped')),
    attempts      smallint NOT NULL DEFAULT 0,
    run_after     timestamptz NOT NULL DEFAULT now(),   -- lùi lịch khi retry
    started_at    timestamptz,
    finished_at   timestamptz,
    error         text,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS video_jobs_pending_idx
    ON ai_vision.video_analysis_jobs (run_after, created_at) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS video_jobs_child_idx
    ON ai_vision.video_analysis_jobs (child_id);
CREATE INDEX IF NOT EXISTS video_jobs_activity_idx
    ON ai_vision.video_analysis_jobs (activity_id, created_at DESC);

-- ---------------------------------------------------------------------
-- 2. Kết quả AI cho từng video
-- Một job có thể có nhiều kết quả (rule + model chạy song song để so sánh);
-- is_primary = kết quả hiển thị cho phụ huynh, tối đa 1 / job.
-- result: { "steps": [ { "step_number": 1, "verdict": "observed", "score": 0.82,
--                        "evidence": { "count": 3, "t": [1.2, 2.0, 2.9] } } ], ... }
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ai_vision.ai_evaluations (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id         uuid NOT NULL REFERENCES ai_vision.video_analysis_jobs(id) ON DELETE CASCADE,
    method         varchar(10) NOT NULL CHECK (method IN ('rule','model','llm')),
    model_version  varchar(50),                      -- ai_vision.model_registry.version (method = 'model')
    rubric_version int,                              -- activities.ai_rubric->'version' (method = 'rule')
    result         jsonb NOT NULL,
    overall        varchar(15) NOT NULL
                   CHECK (overall IN ('observed','partial','not_observed','unclear')),
    confidence     numeric(4,3) CHECK (confidence BETWEEN 0 AND 1),
    is_primary     boolean NOT NULL DEFAULT true,
    latency_ms     int,
    created_at     timestamptz NOT NULL DEFAULT now(),
    CHECK (method <> 'rule'  OR rubric_version IS NOT NULL),
    CHECK (method <> 'model' OR model_version IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS ai_evaluations_job_idx ON ai_vision.ai_evaluations (job_id);
CREATE UNIQUE INDEX IF NOT EXISTS ai_evaluations_one_primary
    ON ai_vision.ai_evaluations (job_id) WHERE is_primary;

-- ---------------------------------------------------------------------
-- 3. Phản hồi 👍/👎 của phụ huynh — nhãn yếu
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ai_vision.parent_feedback (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    evaluation_id uuid NOT NULL REFERENCES ai_vision.ai_evaluations(id) ON DELETE CASCADE,
    user_id       uuid NOT NULL,                     -- account.users.id
    is_correct    boolean NOT NULL,
    comment       text,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (evaluation_id, user_id)
);

-- ---------------------------------------------------------------------
-- 4. Chuỗi khung xương — dữ liệu để train (giai đoạn 3)
-- Chỉ ghi khi child.children.ai_training_consent = true tại thời điểm xử lý;
-- consented_at là mốc consent backend gửi kèm job. Rút consent -> xóa dòng.
-- keypoints: mảng float32 nén, shape [frame_count, num_keypoints, 4] (x, y, z, visibility).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ai_vision.pose_sequences (
    job_id        uuid PRIMARY KEY REFERENCES ai_vision.video_analysis_jobs(id) ON DELETE CASCADE,
    pose_model    varchar(50) NOT NULL,              -- vd mediapipe_pose_landmarker_full
    fps           numeric(5,2) NOT NULL CHECK (fps > 0),
    frame_count   int NOT NULL CHECK (frame_count > 0),
    num_keypoints smallint NOT NULL CHECK (num_keypoints > 0),
    keypoints     bytea NOT NULL,
    consented_at  timestamptz NOT NULL,
    created_at    timestamptz NOT NULL DEFAULT now()
);

-- =====================================================================
-- Gắn trigger updated_at cho bảng mới
-- =====================================================================
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT table_schema, table_name FROM information_schema.columns
    WHERE column_name = 'updated_at' AND table_schema = 'ai_vision'
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM information_schema.triggers
      WHERE trigger_schema = r.table_schema
        AND event_object_table = r.table_name
        AND trigger_name = format('trg_%s_updated_at', r.table_name)
    ) THEN
      EXECUTE format(
        'CREATE TRIGGER trg_%1$s_updated_at BEFORE UPDATE ON %2$I.%1$I
           FOR EACH ROW EXECUTE FUNCTION common.set_updated_at()',
        r.table_name, r.table_schema);
    END IF;
  END LOOP;
END $$;
