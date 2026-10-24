/*
This migration is intentionally a no-op.

The target auth design gives every admin the same authorization class and
does not include roles, permissions, invitations, or role assignments. The
old contents are kept in this historical file only as migration provenance;
existing databases are cleaned by 012_auth_schema_alignment.sql.
CREATE TABLE admin.roles (
    id          serial PRIMARY KEY,
    code        varchar(50) NOT NULL UNIQUE,      -- super_admin, content_manager, moderator, support
    name        varchar(100) NOT NULL,
    description text
);

CREATE TABLE admin.permissions (
    id          serial PRIMARY KEY,
    code        varchar(100) NOT NULL UNIQUE,     -- vd: criteria.write, kb.manage, user.lock
    description text
);

CREATE TABLE admin.role_permissions (
    role_id       int NOT NULL REFERENCES admin.roles(id) ON DELETE CASCADE,
    permission_id int NOT NULL REFERENCES admin.permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE admin.admin_user_roles (
    admin_user_id uuid NOT NULL REFERENCES admin.admin_users(id) ON DELETE CASCADE,
    role_id       int  NOT NULL REFERENCES admin.roles(id) ON DELETE CASCADE,
    PRIMARY KEY (admin_user_id, role_id)
);

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

INSERT INTO admin.permissions(code,description) VALUES ('user.recover','Account recovery') ON CONFLICT DO NOTHING;
INSERT INTO admin.role_permissions(role_id,permission_id) SELECT r.id,p.id FROM admin.roles r CROSS JOIN admin.permissions p WHERE r.code IN ('super_admin','support') AND p.code='user.recover' ON CONFLICT DO NOTHING;
*/
