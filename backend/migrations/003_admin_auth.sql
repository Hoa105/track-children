-- =====================================================================
-- 003 – Đăng nhập & quản lý tài khoản web admin (F11)
--   - Không có tự đăng ký: super admin đầu tiên tạo bằng scripts/create-admin.ps1,
--     các admin khác được MỜI qua email rồi tự đặt mật khẩu (admin_invitations).
--   - Phiên đăng nhập (refresh token), quên mật khẩu, khóa tạm khi sai mật khẩu nhiều lần.
--   - Seed vai trò + quyền (mã quyền khớp admin-web/src/app/navigation.js).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Tài khoản admin: chống dò mật khẩu
-- ---------------------------------------------------------------------
ALTER TABLE admin.admin_users
    ADD COLUMN failed_login_attempts smallint NOT NULL DEFAULT 0,
    ADD COLUMN locked_until          timestamptz,     -- khóa tạm sau 5 lần sai (khác status = 'locked' do admin khóa)
    ADD COLUMN password_changed_at   timestamptz;

-- ---------------------------------------------------------------------
-- Lời mời quản trị viên — thay cho đăng ký
-- Link mời chứa token gốc; DB chỉ lưu hash. Chấp nhận lời mời = tạo admin_users
-- + gán vai trò trong 1 transaction (backend).
-- ---------------------------------------------------------------------
CREATE TABLE admin.admin_invitations (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email        citext NOT NULL,
    full_name    varchar(150),
    role_id      int NOT NULL REFERENCES admin.roles(id),
    token_hash   text NOT NULL UNIQUE,
    invited_by   uuid REFERENCES admin.admin_users(id) ON DELETE SET NULL,
    status       varchar(15) NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending','accepted','cancelled','expired')),
    expires_at   timestamptz NOT NULL,
    accepted_at  timestamptz,
    admin_user_id uuid REFERENCES admin.admin_users(id) ON DELETE SET NULL,   -- tài khoản được tạo
    created_at   timestamptz NOT NULL DEFAULT now()
);
-- Mỗi email chỉ có 1 lời mời đang mở
CREATE UNIQUE INDEX one_pending_admin_invitation
    ON admin.admin_invitations (email) WHERE status = 'pending';

-- ---------------------------------------------------------------------
-- Phiên đăng nhập admin (refresh token) — tách khỏi account.user_sessions
-- ---------------------------------------------------------------------
CREATE TABLE admin.admin_sessions (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_user_id      uuid NOT NULL REFERENCES admin.admin_users(id) ON DELETE CASCADE,
    refresh_token_hash text NOT NULL UNIQUE,
    ip_address         inet,
    user_agent         text,
    expires_at         timestamptz NOT NULL,
    last_used_at       timestamptz NOT NULL DEFAULT now(),
    revoked_at         timestamptz,
    created_at         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON admin.admin_sessions (admin_user_id) WHERE revoked_at IS NULL;

-- ---------------------------------------------------------------------
-- Quên mật khẩu admin
-- ---------------------------------------------------------------------
CREATE TABLE admin.admin_password_resets (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_user_id uuid NOT NULL REFERENCES admin.admin_users(id) ON DELETE CASCADE,
    token_hash    text NOT NULL UNIQUE,
    expires_at    timestamptz NOT NULL,
    used_at       timestamptz,
    created_at    timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- Luôn còn ít nhất 1 super admin đang hoạt động
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION admin.ensure_active_super_admin() RETURNS trigger AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM admin.admin_users u
    JOIN admin.admin_user_roles ur ON ur.admin_user_id = u.id
    JOIN admin.roles r ON r.id = ur.role_id
    WHERE r.code = 'super_admin' AND u.status = 'active'
  ) AND EXISTS (SELECT 1 FROM admin.admin_users) THEN
    RAISE EXCEPTION 'At least one active super_admin is required';
  END IF;
  RETURN NULL;
END; $$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER trg_admin_users_keep_super_admin
  AFTER UPDATE OF status OR DELETE ON admin.admin_users
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION admin.ensure_active_super_admin();
CREATE CONSTRAINT TRIGGER trg_admin_user_roles_keep_super_admin
  AFTER UPDATE OR DELETE ON admin.admin_user_roles
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION admin.ensure_active_super_admin();

-- ---------------------------------------------------------------------
-- Seed vai trò & quyền
-- ---------------------------------------------------------------------
INSERT INTO admin.roles (code, name, description) VALUES
  ('super_admin',     'Super Admin',        'Toàn quyền, quản lý quản trị viên'),
  ('content_manager', 'Quản lý nội dung',   'Bộ tiêu chí, hoạt động, dữ liệu tham chiếu, kho tri thức AI'),
  ('moderator',       'Kiểm duyệt viên',    'Xử lý báo cáo và nội dung cộng đồng'),
  ('support',         'Hỗ trợ người dùng',  'Tra cứu, khóa / mở khóa tài khoản người dùng')
ON CONFLICT (code) DO NOTHING;

INSERT INTO admin.permissions (code, description) VALUES
  ('report.read',        'Xem dashboard & thống kê'),
  ('user.read',          'Xem danh sách người dùng'),
  ('user.lock',          'Khóa / mở khóa người dùng'),
  ('child.stats',        'Xem thống kê hồ sơ trẻ (tổng hợp)'),
  ('child.support_view', 'Tra cứu một hồ sơ trẻ để hỗ trợ (chỉ thông tin hành chính, bắt nhập lý do, có ghi log)'),
  ('criteria.write',     'Quản lý bộ tiêu chí, duyệt tiêu chí AI đề xuất'),
  ('activity.write',     'Quản lý hoạt động & nhóm'),
  ('health.write',       'Quản lý tiêm chủng, mọc răng, dinh dưỡng, chuẩn WHO'),
  ('reference.write',    'Quản lý nguồn tham chiếu'),
  ('kb.manage',          'Quản lý kho tri thức AI'),
  ('chatbot.monitor',    'Giám sát chatbot'),
  ('community.moderate', 'Kiểm duyệt cộng đồng'),
  ('notification.write', 'Quản lý thông báo & nhắc lịch'),
  ('legal.write',        'Quản lý điều khoản & chính sách'),
  ('admin.manage',       'Quản lý quản trị viên & vai trò'),
  ('audit.read',         'Xem nhật ký hoạt động')
ON CONFLICT (code) DO NOTHING;

INSERT INTO admin.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM admin.roles r
JOIN admin.permissions p ON
     r.code = 'super_admin'
  OR (r.code = 'content_manager' AND p.code IN ('report.read','child.stats','criteria.write','activity.write','health.write','reference.write','kb.manage','chatbot.monitor','notification.write','legal.write'))
  OR (r.code = 'moderator'       AND p.code IN ('report.read','user.read','community.moderate'))
  OR (r.code = 'support'         AND p.code IN ('report.read','user.read','user.lock','child.stats','child.support_view'))
ON CONFLICT DO NOTHING;
