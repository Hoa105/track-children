-- =====================================================================
-- 003 – Nhãn chuyên gia & quản lý model (giai đoạn 3), schema ai_vision
--   - Chuyên gia gán nhãn từng bước trên admin web, 2 người / video
--   - Phiên bản model train trên chuỗi keypoint; chỉ bật khi tốt hơn rule rõ rệt
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Nhãn chuyên gia — chỉ gán cho video có pose_sequences (đã có consent)
-- labeler_id = admin.admin_users.id bên DB chính (quyền ai.video.label).
-- unusable: video không dùng được (khuất người, sai hoạt động...).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ai_vision.expert_labels (
    job_id      uuid NOT NULL REFERENCES ai_vision.video_analysis_jobs(id) ON DELETE CASCADE,
    labeler_id  uuid NOT NULL,
    step_number smallint NOT NULL CHECK (step_number > 0),
    label       varchar(10) NOT NULL CHECK (label IN ('done','partial','not_yet','unusable')),
    note        text,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (job_id, labeler_id, step_number)
);
CREATE INDEX IF NOT EXISTS expert_labels_labeler_idx
    ON ai_vision.expert_labels (labeler_id, created_at DESC);

-- Video đủ 2 người gán nhãn, kèm số bước 2 người lệch nhau (cần người thứ 3 phân xử)
CREATE OR REPLACE VIEW ai_vision.labeling_agreement AS
WITH per_step AS (
    SELECT job_id, step_number, count(DISTINCT label) AS n_labels
    FROM ai_vision.expert_labels
    GROUP BY job_id, step_number
)
SELECT l.job_id,
       count(DISTINCT l.labeler_id) AS labelers,
       (SELECT count(*) FROM per_step p WHERE p.job_id = l.job_id AND p.n_labels > 1) AS disputed_steps
FROM ai_vision.expert_labels l
GROUP BY l.job_id;

-- ---------------------------------------------------------------------
-- 2. Phiên bản model
-- activity_ids: các hoạt động model áp dụng. Bật model = is_active true;
-- rollback = tắt bản mới, bật lại bản cũ. Mỗi hoạt động tối đa 1 model active
-- (kiểm tra bằng trigger vì activity_ids là mảng).
-- metrics: { "f1_macro": 0.81, "rule_f1_macro": 0.72, "n_test": 240, ... }
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ai_vision.model_registry (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    version       varchar(50) NOT NULL UNIQUE,
    activity_ids  uuid[] NOT NULL CHECK (cardinality(activity_ids) > 0),
    metrics       jsonb NOT NULL DEFAULT '{}'::jsonb,
    onnx_path     text NOT NULL,                     -- khóa object MinIO / đường dẫn file
    is_active     boolean NOT NULL DEFAULT false,
    trained_at    timestamptz,
    activated_at  timestamptz,
    created_by    uuid,                              -- admin.admin_users.id
    note          text,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS model_registry_active_idx
    ON ai_vision.model_registry USING gin (activity_ids) WHERE is_active;

CREATE OR REPLACE FUNCTION ai_vision.check_one_active_model() RETURNS trigger AS $$
BEGIN
  IF NEW.is_active AND EXISTS (
    SELECT 1 FROM ai_vision.model_registry m
    WHERE m.is_active AND m.id <> NEW.id AND m.activity_ids && NEW.activity_ids
  ) THEN
    RAISE EXCEPTION 'Another active model already covers one of these activities';
  END IF;
  IF NEW.is_active THEN
    IF TG_OP = 'INSERT' THEN
      NEW.activated_at := now();
    ELSIF NOT OLD.is_active THEN
      NEW.activated_at := now();
    END IF;
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_model_registry_one_active ON ai_vision.model_registry;
CREATE TRIGGER trg_model_registry_one_active BEFORE INSERT OR UPDATE OF is_active, activity_ids
    ON ai_vision.model_registry
    FOR EACH ROW EXECUTE FUNCTION ai_vision.check_one_active_model();

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
