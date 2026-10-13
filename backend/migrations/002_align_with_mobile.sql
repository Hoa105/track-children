-- =====================================================================
-- 002 – Đồng bộ schema với mobile app + chiến lược xóa tài khoản
--   1. Gắn trigger updated_at cho mọi bảng (001 mới tạo hàm, chưa gắn)
--   2. F23: phạm vi quyền chia sẻ khớp ShareSection của mobile
--   3. F23.11: yêu cầu chuyển quyền chủ hồ sơ
--   4. F05.2: mũi tiêm phụ huynh tự thêm (vắc xin dịch vụ, tiêm bù...)
--   5. F01: username (tên hiển thị công khai trong cộng đồng)
--   6. F09/F20: nhóm hoạt động + nội dung chi tiết có cấu trúc
--   7. F06: số mốc đạt / tổng số mốc của bài đánh giá
--   8. F01.6: xóa tài khoản = ẩn danh hóa (xem docs/database/README.md)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Trigger updated_at
-- ---------------------------------------------------------------------
-- Chạy lại ở cuối file để gắn cả cho bảng mới tạo trong migration này.
CREATE OR REPLACE FUNCTION common.attach_updated_at_triggers() RETURNS void AS $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT c.table_schema, c.table_name
    FROM information_schema.columns c
    JOIN information_schema.tables t
      ON t.table_schema = c.table_schema AND t.table_name = c.table_name AND t.table_type = 'BASE TABLE'
    WHERE c.column_name = 'updated_at'
      AND c.table_schema NOT IN ('pg_catalog', 'information_schema', 'public')
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.triggers
      WHERE trigger_schema = r.table_schema
        AND event_object_table = r.table_name
        AND trigger_name = format('trg_%s_updated_at', r.table_name)
    ) THEN
      EXECUTE format(
        'CREATE TRIGGER %I BEFORE UPDATE ON %I.%I FOR EACH ROW EXECUTE FUNCTION common.set_updated_at()',
        format('trg_%s_updated_at', r.table_name), r.table_schema, r.table_name);
    END IF;
  END LOOP;
END; $$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------
-- 2. F23.2 – Phạm vi quyền chia sẻ
-- Khớp mobile ShareSection: growth, assessment, vaccination (gồm cả mọc răng),
-- diary (= ShareSection.journal), activities (trạng thái "Đã làm").
-- Thông tin cơ bản của bé: người được chia sẻ luôn xem được, chỉ chủ sửa
-- -> không cần dòng quyền. Chatbot là dữ liệu cấp tài khoản -> không chia sẻ.
-- ---------------------------------------------------------------------
-- teething gộp vào vaccination: lấy mức quyền cao hơn
INSERT INTO child.child_member_permissions (member_id, data_scope, access_level)
SELECT member_id, 'vaccination', access_level
FROM child.child_member_permissions WHERE data_scope = 'teething'
ON CONFLICT (member_id, data_scope) DO UPDATE
  SET access_level = CASE
    WHEN 'edit' IN (child_member_permissions.access_level, EXCLUDED.access_level) THEN 'edit'
    WHEN 'view' IN (child_member_permissions.access_level, EXCLUDED.access_level) THEN 'view'
    ELSE 'none' END;

DELETE FROM child.child_member_permissions WHERE data_scope IN ('profile', 'teething', 'chatbot');

ALTER TABLE child.child_member_permissions
    DROP CONSTRAINT IF EXISTS child_member_permissions_data_scope_check,
    ADD CONSTRAINT child_member_permissions_data_scope_check
        CHECK (data_scope IN ('growth','assessment','vaccination','diary','activities'));

UPDATE child.child_invitations
SET proposed_permissions = (proposed_permissions - 'profile' - 'teething' - 'chatbot')
    || CASE WHEN proposed_permissions ? 'teething' AND NOT proposed_permissions ? 'vaccination'
            THEN jsonb_build_object('vaccination', proposed_permissions->'teething')
            ELSE '{}'::jsonb END
WHERE proposed_permissions ?| ARRAY['profile','teething','chatbot'];

ALTER TABLE child.child_invitations
    ADD CONSTRAINT child_invitations_permission_keys_check
        CHECK ((proposed_permissions - ARRAY['growth','assessment','vaccination','diary','activities']) = '{}'::jsonb);

-- Màn "Được chia sẻ với tôi" tra theo user_id (UNIQUE (child_id, user_id) không dùng được)
CREATE INDEX IF NOT EXISTS child_members_user_idx ON child.child_members (user_id) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS child_invitations_invitee_idx ON child.child_invitations (invitee_user_id) WHERE status = 'pending';

-- ---------------------------------------------------------------------
-- 3. F23.11 – Chuyển quyền chủ hồ sơ
-- Chủ đề nghị 1 thành viên đang active nhận hồ sơ; người đó đồng ý thì
-- child.accept_ownership_transfer() đổi chủ trong 1 transaction, chủ cũ ở lại
-- làm thành viên với quyền Xem & sửa toàn bộ (giống SharePermissions.coCare).
-- ---------------------------------------------------------------------
CREATE TABLE child.ownership_transfers (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id      uuid NOT NULL REFERENCES child.children(id) ON DELETE CASCADE,
    from_user_id  uuid NOT NULL REFERENCES account.users(id),
    to_user_id    uuid NOT NULL REFERENCES account.users(id),
    status        varchar(15) NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','accepted','declined','cancelled','expired')),
    expires_at    timestamptz NOT NULL,
    responded_at  timestamptz,
    created_at    timestamptz NOT NULL DEFAULT now(),
    CHECK (from_user_id <> to_user_id)
);
-- Mỗi hồ sơ chỉ có 1 đề nghị đang mở
CREATE UNIQUE INDEX one_open_ownership_transfer
    ON child.ownership_transfers (child_id) WHERE status = 'pending';
CREATE INDEX ON child.ownership_transfers (to_user_id) WHERE status = 'pending';

CREATE OR REPLACE FUNCTION child.accept_ownership_transfer(p_transfer_id uuid, p_user_id uuid)
RETURNS void AS $$
DECLARE
  t child.ownership_transfers%ROWTYPE;
  v_old_member child.child_members%ROWTYPE;
  v_new_member_id uuid;
BEGIN
  SELECT * INTO t FROM child.ownership_transfers WHERE id = p_transfer_id FOR UPDATE;
  IF NOT FOUND OR t.status <> 'pending' OR t.to_user_id <> p_user_id THEN
    RAISE EXCEPTION 'Ownership transfer % is not open for user %', p_transfer_id, p_user_id;
  END IF;
  IF t.expires_at < now() THEN
    UPDATE child.ownership_transfers SET status = 'expired', responded_at = now() WHERE id = t.id;
    RAISE EXCEPTION 'Ownership transfer % has expired', p_transfer_id;
  END IF;
  PERFORM 1 FROM child.children
    WHERE id = t.child_id AND owner_user_id = t.from_user_id AND deleted_at IS NULL FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Child % is no longer owned by %', t.child_id, t.from_user_id;
  END IF;

  -- Đánh dấu accepted trước, để trigger hủy đề nghị khi xóa member (bước 1) bỏ qua dòng này
  UPDATE child.ownership_transfers SET status = 'accepted', responded_at = now() WHERE id = t.id;

  -- 1) xóa dòng member của chủ mới (quyền cascade theo)
  DELETE FROM child.child_members
    WHERE child_id = t.child_id AND user_id = t.to_user_id AND status = 'active'
    RETURNING * INTO v_old_member;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User % is not an active member of child %', t.to_user_id, t.child_id;
  END IF;

  -- 2) đổi chủ
  UPDATE child.children SET owner_user_id = t.to_user_id WHERE id = t.child_id;

  -- 3) chủ cũ ở lại làm thành viên, Xem & sửa toàn bộ
  INSERT INTO child.child_members (child_id, user_id, status)
    VALUES (t.child_id, t.from_user_id, 'active')
    ON CONFLICT (child_id, user_id) DO UPDATE SET status = 'active', joined_at = now(), ended_at = NULL
    RETURNING id INTO v_new_member_id;
  DELETE FROM child.child_member_permissions WHERE member_id = v_new_member_id;
  INSERT INTO child.child_member_permissions (member_id, data_scope, access_level)
    SELECT v_new_member_id, s, 'edit'
    FROM unnest(ARRAY['growth','assessment','vaccination','diary','activities']) AS s;

END; $$ LANGUAGE plpgsql;

-- Thành viên rời / bị thu hồi -> hủy đề nghị chuyển quyền đang mở cho họ
CREATE OR REPLACE FUNCTION child.cancel_transfer_on_member_end() RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.status = 'active' THEN
    RETURN NULL;
  END IF;
  UPDATE child.ownership_transfers SET status = 'cancelled', responded_at = now()
  WHERE child_id = OLD.child_id AND to_user_id = OLD.user_id AND status = 'pending';
  RETURN NULL;
END; $$ LANGUAGE plpgsql;
CREATE TRIGGER trg_child_members_cancel_transfer
  AFTER DELETE OR UPDATE OF status ON child.child_members
  FOR EACH ROW WHEN (OLD.status = 'active')
  EXECUTE FUNCTION child.cancel_transfer_on_member_end();

-- ---------------------------------------------------------------------
-- 4. F05.2 – Mũi tiêm tự thêm
-- Một dòng child_vaccinations là: mũi theo lịch TCMR (schedule_id) HOẶC
-- mũi phụ huynh tự thêm (custom_name). Mũi 'planned' có thể có ngày hẹn.
-- ---------------------------------------------------------------------
ALTER TABLE health.vaccine_schedules
    ADD COLUMN dose_label varchar(50);              -- "Mũi 1", "Liều sơ sinh", "Nhắc lại"

ALTER TABLE health.child_vaccinations
    ALTER COLUMN schedule_id DROP NOT NULL,
    ADD COLUMN vaccine_id        int REFERENCES health.vaccines(id),  -- tùy chọn: mũi tự thêm chọn từ danh mục
    ADD COLUMN custom_name       varchar(150),       -- tên vắc xin do phụ huynh nhập
    ADD COLUMN custom_disease    varchar(200),       -- phòng bệnh gì
    ADD COLUMN dose_label        varchar(50),
    ADD COLUMN scheduled_date    date,               -- ngày hẹn tiêm
    ADD COLUMN appointment_place varchar(200),       -- nơi hẹn tiêm (trước khi tiêm)
    ADD COLUMN note              text,
    ADD CONSTRAINT child_vaccinations_kind_check
        CHECK ((schedule_id IS NOT NULL AND custom_name IS NULL AND vaccine_id IS NULL)
            OR (schedule_id IS NULL AND custom_name IS NOT NULL)),
    -- Mũi tự thêm luôn có ngày: ngày hẹn hoặc ngày đã tiêm
    ADD CONSTRAINT child_vaccinations_custom_date_check
        CHECK (schedule_id IS NOT NULL OR scheduled_date IS NOT NULL OR vaccinated_at IS NOT NULL);

CREATE INDEX child_vaccinations_custom_idx
    ON health.child_vaccinations (child_id, scheduled_date) WHERE schedule_id IS NULL;

-- ---------------------------------------------------------------------
-- 5. F01 – username: tên đăng nhập / tên hiển thị trong cộng đồng
-- Nullable để tài khoản đã ẩn danh hóa (mục 8) giải phóng username.
-- ---------------------------------------------------------------------
ALTER TABLE account.users
    ADD COLUMN username citext UNIQUE
        CHECK (username ~ '^[a-z0-9_.]{3,30}$');

-- ---------------------------------------------------------------------
-- 6. F09 / F20 – Nhóm hoạt động
-- detail_kind quyết định màn chi tiết: move (các bước), music (lời bài hát),
-- story (đoạn truyện + câu hỏi gợi ý).
-- ---------------------------------------------------------------------
CREATE TABLE activity.activity_groups (
    id           serial PRIMARY KEY,
    code         varchar(40) NOT NULL UNIQUE,
    name         varchar(100) NOT NULL,
    description  text,
    emoji        varchar(16),
    tint_hex     varchar(9),
    detail_kind  varchar(10) NOT NULL DEFAULT 'move' CHECK (detail_kind IN ('move','music','story')),
    sort_order   smallint NOT NULL DEFAULT 0,
    is_active    boolean NOT NULL DEFAULT true,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE activity.activities
    ADD COLUMN group_id          int REFERENCES activity.activity_groups(id),
    ADD COLUMN goal              text,               -- mục tiêu
    ADD COLUMN material_items    text[],             -- danh sách chuẩn bị (thay cho materials dạng text)
    ADD COLUMN safety_note       text,
    ADD COLUMN needs_adult       boolean NOT NULL DEFAULT false,   -- tag "Cần người lớn ngồi cạnh"
    ADD COLUMN lyrics            text,               -- music
    ADD COLUMN movement_tip      text,               -- music
    ADD COLUMN story_paragraphs  text[],             -- story
    ADD COLUMN questions_to_ask  text;               -- story
CREATE INDEX activities_group_idx ON activity.activities (group_id, age_from_months) WHERE status = 'published';

INSERT INTO activity.activity_groups (code, name, description, emoji, tint_hex, detail_kind, sort_order) VALUES
  ('gross_motor', 'Vận động thô', 'Các bài tập giúp bé lẫy, ngồi, bò, đi vững.', '🏃', '#E4F3EA', 'move', 1),
  ('fine_motor', 'Vận động tinh', 'Rèn khéo tay, phối hợp tay – mắt cho bé.', '✋', '#EDEBFA', 'move', 2),
  ('language', 'Ngôn ngữ', 'Khuyến khích bé bập bẹ, nói từ, ghép câu.', '💬', '#FDF0D8', 'move', 3),
  ('cognitive_social', 'Nhận thức & Cảm xúc xã hội', 'Phát triển tư duy, cảm xúc và kỹ năng xã hội.', '🧠', '#E4F3EA', 'move', 4),
  ('music', 'Âm nhạc & âm thanh', 'Giúp bé cảm nhận nhịp điệu và âm thanh.', '🎵', '#EDEBFA', 'music', 5),
  ('story', 'Kể chuyện', 'Nuôi dưỡng trí tưởng tượng và ngôn ngữ qua chuyện kể.', '📖', '#FDF0D8', 'story', 6);

-- ---------------------------------------------------------------------
-- 7. F06 – Số mốc đạt / tổng (mobile hiển thị "6/7", "Đạt 22/25 mốc")
-- ---------------------------------------------------------------------
ALTER TABLE assessment.assessment_domain_results
    ADD COLUMN achieved_count smallint,
    ADD COLUMN total_count    smallint,
    ADD CONSTRAINT assessment_domain_results_counts_check
        CHECK (achieved_count BETWEEN 0 AND total_count);

ALTER TABLE assessment.assessments
    ADD COLUMN achieved_count smallint,
    ADD COLUMN total_count    smallint,
    ADD CONSTRAINT assessments_counts_check
        CHECK (achieved_count BETWEEN 0 AND total_count);

-- ---------------------------------------------------------------------
-- 8. F01.6 – Xóa tài khoản = ẨN DANH HÓA, không DELETE dòng users
-- Lý do: users được tham chiếu từ nhật ký, số đo, lời mời, log... của hồ sơ
-- trẻ mà người khác vẫn dùng. Giữ dòng (id) nhưng xóa toàn bộ thông tin cá nhân.
-- Luồng: data_deletion_requests (chờ 30 ngày, đăng nhập lại = hủy)
--        -> job gọi account.anonymize_user() khi tới scheduled_at.
-- ---------------------------------------------------------------------
ALTER TABLE account.users
    ADD COLUMN deleted_at timestamptz,
    DROP CONSTRAINT IF EXISTS users_check,
    ADD CONSTRAINT users_contact_check
        CHECK (status = 'deleted' OR email IS NOT NULL OR phone IS NOT NULL),
    ADD CONSTRAINT users_deleted_at_check
        CHECK ((status = 'deleted') = (deleted_at IS NOT NULL));

CREATE OR REPLACE FUNCTION account.anonymize_user(p_user_id uuid) RETURNS void AS $$
BEGIN
  PERFORM 1 FROM account.users WHERE id = p_user_id AND status <> 'deleted' FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User % not found or already deleted', p_user_id;
  END IF;

  -- Hồ sơ trẻ đang sở hữu phải được chuyển quyền (F23.11) hoặc xóa trước
  IF EXISTS (SELECT 1 FROM child.children WHERE owner_user_id = p_user_id AND deleted_at IS NULL) THEN
    RAISE EXCEPTION 'User % still owns child profiles: transfer or delete them first', p_user_id;
  END IF;

  -- Phiên, thiết bị, mã xác thực
  DELETE FROM account.user_sessions      WHERE user_id = p_user_id;
  DELETE FROM account.device_tokens      WHERE user_id = p_user_id;
  DELETE FROM account.verification_codes WHERE user_id = p_user_id;
  UPDATE account.user_consents SET ip_address = NULL WHERE user_id = p_user_id;  -- giữ làm bằng chứng đồng ý

  -- Quyền truy cập hồ sơ trẻ của người khác (trigger tự hủy đề nghị chuyển quyền)
  DELETE FROM child.child_members WHERE user_id = p_user_id;
  UPDATE child.child_invitations SET status = 'cancelled', responded_at = now()
    WHERE status = 'pending' AND (inviter_id = p_user_id OR invitee_user_id = p_user_id);
  UPDATE child.ownership_transfers SET status = 'cancelled', responded_at = now()
    WHERE status = 'pending' AND (from_user_id = p_user_id OR to_user_id = p_user_id);

  -- Dữ liệu cấp tài khoản
  DELETE FROM activity.activity_favorites               WHERE user_id = p_user_id;
  DELETE FROM notification.user_notification_settings   WHERE user_id = p_user_id;
  DELETE FROM notification.notifications                WHERE user_id = p_user_id;
  DELETE FROM notification.reminders                    WHERE user_id = p_user_id;
  DELETE FROM community.post_likes                      WHERE user_id = p_user_id;
  DELETE FROM community.post_saves                      WHERE user_id = p_user_id;
  UPDATE community.posts         SET status = 'removed' WHERE author_id = p_user_id;
  UPDATE community.post_comments SET status = 'removed' WHERE author_id = p_user_id;

  -- Nhật ký / số đo đã ghi cho hồ sơ của người khác: GIỮ (thuộc dữ liệu của trẻ),
  -- tác giả hiển thị là "Người dùng đã xóa".

  UPDATE account.users SET
    email = NULL, phone = NULL, username = NULL,
    password_hash = '!deleted',                     -- không phải hash hợp lệ -> không đăng nhập được
    full_name = 'Người dùng đã xóa', avatar_url = NULL,
    gender = NULL, date_of_birth = NULL, relationship = NULL,
    email_verified_at = NULL, phone_verified_at = NULL,
    status = 'deleted', deleted_at = now()
  WHERE id = p_user_id;

  UPDATE account.data_deletion_requests SET status = 'completed', completed_at = now()
    WHERE user_id = p_user_id AND status IN ('pending','processing');
END; $$ LANGUAGE plpgsql;

-- Hồ sơ trẻ bị xóa mềm (deleted_at) được xóa hẳn sau thời gian lưu giữ;
-- mọi dữ liệu con (số đo, tiêm chủng, nhật ký...) xóa theo ON DELETE CASCADE.
CREATE OR REPLACE FUNCTION child.purge_deleted_children(p_retention interval DEFAULT interval '30 days')
RETURNS int AS $$
DECLARE n int;
BEGIN
  DELETE FROM child.children WHERE deleted_at < now() - p_retention;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END; $$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------
DO $$ BEGIN PERFORM common.attach_updated_at_triggers(); END $$;
