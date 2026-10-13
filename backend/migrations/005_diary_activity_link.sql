-- =====================================================================
-- 005 – Nhật ký video theo hoạt động (giai đoạn 1)
--   - Gắn nhật ký với hoạt động, phụ huynh tự đánh giá + đánh dấu từng bước
--   - Quản lý video trên MinIO (storage_key, thời lượng ≤ 90 giây, trạng thái upload)
--   - Consent dùng video cho AI theo TỪNG TRẺ + văn bản điều khoản 'ai_training'
-- Kế hoạch: docs/database/ke-hoach-nhat-ky-video-ai.md
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Nhật ký ↔ hoạt động. Nhật ký thường để activity_id = null.
-- Xóa hoạt động không làm mất nhật ký (SET NULL); self_rating khi đó cũng
-- phải bỏ — xem trigger bên dưới.
-- ---------------------------------------------------------------------
ALTER TABLE diary.diary_entries
    ADD COLUMN activity_id uuid REFERENCES activity.activities(id) ON DELETE SET NULL,
    ADD COLUMN self_rating varchar(15)
        CHECK (self_rating IN ('done','with_help','not_yet')),
    ADD CONSTRAINT diary_entries_rating_needs_activity
        CHECK (self_rating IS NULL OR activity_id IS NOT NULL);

-- Lấy nhật ký theo hoạt động của trẻ (màn chi tiết hoạt động)
CREATE INDEX diary_entries_activity_idx
    ON diary.diary_entries (child_id, activity_id, entry_date DESC)
    WHERE deleted_at IS NULL AND activity_id IS NOT NULL;

-- ---------------------------------------------------------------------
-- 2. Bé làm được bước nào (activity.activity_steps)
-- ---------------------------------------------------------------------
CREATE TABLE diary.diary_entry_steps (
    entry_id uuid NOT NULL REFERENCES diary.diary_entries(id) ON DELETE CASCADE,
    step_id  uuid NOT NULL REFERENCES activity.activity_steps(id) ON DELETE CASCADE,
    achieved boolean NOT NULL,
    PRIMARY KEY (entry_id, step_id)
);
CREATE INDEX ON diary.diary_entry_steps (step_id);

-- Bước phải thuộc đúng hoạt động của nhật ký
CREATE OR REPLACE FUNCTION diary.check_entry_step_activity() RETURNS trigger AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM diary.diary_entries e
    JOIN activity.activity_steps s ON s.activity_id = e.activity_id
    WHERE e.id = NEW.entry_id AND s.id = NEW.step_id
  ) THEN
    RAISE EXCEPTION 'Step % does not belong to the activity of diary entry %', NEW.step_id, NEW.entry_id;
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_diary_entry_steps_activity BEFORE INSERT OR UPDATE ON diary.diary_entry_steps
    FOR EACH ROW EXECUTE FUNCTION diary.check_entry_step_activity();

-- Đổi / bỏ hoạt động của nhật ký (kể cả do xóa hoạt động -> SET NULL):
-- bỏ đánh giá và các bước không còn thuộc hoạt động mới
CREATE OR REPLACE FUNCTION diary.on_entry_activity_change() RETURNS trigger AS $$
BEGIN
  IF NEW.activity_id IS NULL THEN
    NEW.self_rating := NULL;
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_diary_entries_activity_change BEFORE UPDATE OF activity_id ON diary.diary_entries
    FOR EACH ROW WHEN (OLD.activity_id IS DISTINCT FROM NEW.activity_id)
    EXECUTE FUNCTION diary.on_entry_activity_change();

CREATE OR REPLACE FUNCTION diary.cleanup_entry_steps() RETURNS trigger AS $$
BEGIN
  DELETE FROM diary.diary_entry_steps es
  WHERE es.entry_id = NEW.id
    AND NOT EXISTS (SELECT 1 FROM activity.activity_steps s
                    WHERE s.id = es.step_id AND s.activity_id = NEW.activity_id);
  RETURN NULL;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_diary_entries_cleanup_steps AFTER UPDATE OF activity_id ON diary.diary_entries
    FOR EACH ROW WHEN (OLD.activity_id IS DISTINCT FROM NEW.activity_id)
    EXECUTE FUNCTION diary.cleanup_entry_steps();

-- ---------------------------------------------------------------------
-- 3. Video nhật ký trên MinIO
-- storage_key: khóa object trong bucket (url có thể là presigned / CDN, đổi được).
-- status: uploading -> ready | failed; deleted = đã xóa object, chờ dọn dòng.
-- Dòng cũ (đã có url) mặc định 'ready'.
-- ---------------------------------------------------------------------
ALTER TABLE diary.diary_media
    ADD COLUMN storage_key      text,
    ADD COLUMN thumbnail_url    text,
    ADD COLUMN duration_seconds smallint CHECK (duration_seconds > 0 AND duration_seconds <= 90),
    ADD COLUMN size_bytes       bigint CHECK (size_bytes >= 0),
    ADD COLUMN status           varchar(12) NOT NULL DEFAULT 'ready'
        CHECK (status IN ('uploading','ready','failed','deleted')),
    ADD COLUMN created_at       timestamptz NOT NULL DEFAULT now(),
    ADD CONSTRAINT diary_media_duration_video_only
        CHECK (duration_seconds IS NULL OR media_type = 'video');
CREATE UNIQUE INDEX diary_media_storage_key_idx
    ON diary.diary_media (storage_key) WHERE storage_key IS NOT NULL;
CREATE INDEX ON diary.diary_media (entry_id, sort_order);
-- Job dọn upload treo / object đã xóa
CREATE INDEX ON diary.diary_media (status, created_at) WHERE status IN ('uploading','failed','deleted');

-- ---------------------------------------------------------------------
-- 4. Consent dùng video cho AI — theo từng trẻ, chỉ chủ hồ sơ bật / tắt (backend kiểm tra).
-- Vết đồng ý với văn bản điều khoản nằm ở account.user_consents (doc_type 'ai_training').
-- Rút consent: ai_training_consent = false, giữ _at / _by = thời điểm & người rút;
-- backend gọi ai-service xóa pose_sequences / nhãn của trẻ.
-- ---------------------------------------------------------------------
ALTER TABLE child.children
    ADD COLUMN ai_training_consent    boolean NOT NULL DEFAULT false,
    ADD COLUMN ai_training_consent_at timestamptz,
    ADD COLUMN ai_training_consent_by uuid REFERENCES account.users(id),
    ADD CONSTRAINT children_ai_consent_check
        CHECK (NOT ai_training_consent OR (ai_training_consent_at IS NOT NULL AND ai_training_consent_by IS NOT NULL));

-- ---------------------------------------------------------------------
-- 5. Văn bản điều khoản AI
-- ---------------------------------------------------------------------
ALTER TABLE account.legal_documents
    DROP CONSTRAINT IF EXISTS legal_documents_doc_type_check,
    ADD CONSTRAINT legal_documents_doc_type_check
        CHECK (doc_type IN ('terms','privacy','data_policy','ai_training'));
