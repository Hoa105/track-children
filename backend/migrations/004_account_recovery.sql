-- =====================================================================
-- 004 – Hỗ trợ khôi phục tài khoản qua hotline
--   1. Đổi email / SĐT đăng nhập khi người dùng mất cả hai (mất máy, đổi số)
--   2. Admin hủy yêu cầu xóa tài khoản khi người dùng không tự đăng nhập lại được
-- Admin KHÔNG chuyển quyền chủ hồ sơ trẻ — sau khi lấy lại tài khoản,
-- phụ huynh tự làm trên app (child.ownership_transfers, F23.11).
-- =====================================================================

INSERT INTO admin.permissions (code, description) VALUES
  ('user.recover', 'Khôi phục tài khoản: đổi email / SĐT, hủy yêu cầu xóa (bắt buộc xác minh danh tính)')
ON CONFLICT (code) DO NOTHING;

INSERT INTO admin.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM admin.roles r
JOIN admin.permissions p ON p.code = 'user.recover'
WHERE r.code IN ('super_admin', 'support')
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------
-- 1. Đổi thông tin đăng nhập
-- Không áp dụng ngay: chờ 48 giờ (effective_at) và gửi cảnh báo tới email / SĐT
-- cũ, để chủ thật kịp chặn nếu người gọi hotline mạo danh.
-- verified_items: các mục admin đã đối chiếu, tối thiểu 3, vd
--   ["full_name","old_contact","child_birth","signup_month","last_device","id_card"]
-- ---------------------------------------------------------------------
CREATE TABLE account.contact_change_requests (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             uuid NOT NULL REFERENCES account.users(id),
    old_email           citext,
    old_phone           varchar(16),
    new_email           citext,
    new_phone           varchar(16) CHECK (new_phone ~ '^\+[1-9][0-9]{7,14}$'),   -- E.164
    verified_items      jsonb NOT NULL CHECK (jsonb_typeof(verified_items) = 'array' AND jsonb_array_length(verified_items) >= 3),
    note                text NOT NULL,                     -- kênh liên hệ, mô tả cuộc gọi
    status              varchar(15) NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending','applied','cancelled','failed')),
    effective_at        timestamptz NOT NULL DEFAULT now() + interval '48 hours',
    requested_by        uuid NOT NULL REFERENCES admin.admin_users(id),
    cancelled_by_admin  uuid REFERENCES admin.admin_users(id),
    cancelled_by_user   boolean NOT NULL DEFAULT false,    -- chủ thật bấm "Không phải tôi" trong cảnh báo
    failure_reason      text,
    resolved_at         timestamptz,
    created_at          timestamptz NOT NULL DEFAULT now(),
    CHECK (new_email IS NOT NULL OR new_phone IS NOT NULL)
);
-- Mỗi tài khoản chỉ 1 yêu cầu đang chờ
CREATE UNIQUE INDEX one_open_contact_change
    ON account.contact_change_requests (user_id) WHERE status = 'pending';
CREATE INDEX ON account.contact_change_requests (effective_at) WHERE status = 'pending';

-- Job định kỳ: áp dụng các yêu cầu đã qua 48 giờ.
-- Thông tin mới để chưa xác minh — người dùng đăng nhập bằng OTP gửi tới số / email mới
-- là xác minh luôn. Mọi phiên cũ bị thu hồi.
CREATE OR REPLACE FUNCTION account.apply_due_contact_changes() RETURNS int AS $$
DECLARE
  r account.contact_change_requests%ROWTYPE;
  v_applied int := 0;
BEGIN
  FOR r IN SELECT * FROM account.contact_change_requests
           WHERE status = 'pending' AND effective_at <= now()
           ORDER BY effective_at FOR UPDATE SKIP LOCKED
  LOOP
    BEGIN
      UPDATE account.users SET
        email             = COALESCE(r.new_email, email),
        email_verified_at = CASE WHEN r.new_email IS NOT NULL THEN NULL ELSE email_verified_at END,
        phone             = COALESCE(r.new_phone, phone),
        phone_verified_at = CASE WHEN r.new_phone IS NOT NULL THEN NULL ELSE phone_verified_at END
      WHERE id = r.user_id AND status <> 'deleted';
      IF NOT FOUND THEN
        RAISE EXCEPTION 'Tài khoản đã bị xóa';
      END IF;
      DELETE FROM account.user_sessions WHERE user_id = r.user_id;
      UPDATE account.contact_change_requests SET status = 'applied', resolved_at = now() WHERE id = r.id;
      v_applied := v_applied + 1;
    EXCEPTION
      WHEN unique_violation THEN   -- email / SĐT mới đã thuộc tài khoản khác
        UPDATE account.contact_change_requests
          SET status = 'failed', failure_reason = 'Email hoặc SĐT mới đã được tài khoản khác sử dụng', resolved_at = now()
          WHERE id = r.id;
      WHEN OTHERS THEN
        UPDATE account.contact_change_requests
          SET status = 'failed', failure_reason = SQLERRM, resolved_at = now()
          WHERE id = r.id;
    END;
  END LOOP;
  RETURN v_applied;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------
-- 2. Admin hủy yêu cầu xóa tài khoản
-- Bình thường đăng nhập lại trong 30 ngày là tự hủy; hàm này cho trường hợp
-- người dùng gọi hotline vì không đăng nhập được. Chỉ hủy được khi còn 'pending'
-- — đã ẩn danh hóa ('completed') thì không khôi phục được.
-- ---------------------------------------------------------------------
ALTER TABLE account.data_deletion_requests
    ADD COLUMN IF NOT EXISTS cancelled_at       timestamptz,
    ADD COLUMN IF NOT EXISTS cancelled_by_admin uuid REFERENCES admin.admin_users(id),
    ADD COLUMN IF NOT EXISTS cancel_note        text;

CREATE OR REPLACE FUNCTION account.admin_cancel_deletion(p_request_id uuid, p_admin_id uuid, p_note text)
RETURNS void AS $$
DECLARE
  v_user_id uuid;
BEGIN
  UPDATE account.data_deletion_requests
    SET status = 'cancelled', cancelled_at = now(), cancelled_by_admin = p_admin_id, cancel_note = p_note
    WHERE id = p_request_id AND status = 'pending'
    RETURNING user_id INTO v_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Deletion request % is not pending', p_request_id;
  END IF;
  UPDATE account.users SET status = 'active' WHERE id = v_user_id AND status = 'pending_deletion';
END;
$$ LANGUAGE plpgsql;
