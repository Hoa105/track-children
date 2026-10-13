// Mã vai trò khớp seed admin.roles.code (backend/migrations/003_admin_auth.sql)
export const ADMIN_ROLES = [
  { code: "support", label: "Hỗ trợ người dùng" },
  { code: "moderator", label: "Kiểm duyệt viên" },
  { code: "content_manager", label: "Quản lý nội dung" },
  { code: "super_admin", label: "Super Admin" },
];

export const PERMISSIONS = [
  { code: "report.read", label: "Xem dashboard & thống kê" },
  { code: "user.read", label: "Xem người dùng" },
  { code: "user.lock", label: "Khóa / mở khóa người dùng" },
  { code: "user.recover", label: "Khôi phục tài khoản (đổi SĐT / email, hủy yêu cầu xóa)" },
  { code: "child.stats", label: "Thống kê hồ sơ trẻ" },
  { code: "child.support_view", label: "Tra cứu hồ sơ trẻ để hỗ trợ" },
  { code: "criteria.write", label: "Bộ tiêu chí & tiêu chí AI đề xuất" },
  { code: "activity.write", label: "Hoạt động & nhóm" },
  { code: "health.write", label: "Tiêm chủng, dinh dưỡng, chuẩn WHO" },
  { code: "reference.write", label: "Nguồn tham chiếu" },
  { code: "kb.manage", label: "Kho tri thức AI" },
  { code: "chatbot.monitor", label: "Giám sát chatbot" },
  { code: "community.moderate", label: "Kiểm duyệt cộng đồng" },
  { code: "notification.write", label: "Thông báo & nhắc lịch" },
  { code: "legal.write", label: "Điều khoản & chính sách" },
  { code: "admin.manage", label: "Quản trị viên & vai trò" },
  { code: "audit.read", label: "Nhật ký hoạt động" },
];

// Bản sao seed admin.role_permissions — khi có API, quyền lấy từ GET /admin/auth/me
export const ROLE_PERMISSIONS = {
  super_admin: PERMISSIONS.map((permission) => permission.code),
  content_manager: ["report.read", "child.stats", "criteria.write", "activity.write", "health.write", "reference.write", "kb.manage", "chatbot.monitor", "notification.write", "legal.write"],
  moderator: ["report.read", "user.read", "community.moderate"],
  support: ["report.read", "user.read", "user.lock", "user.recover", "child.stats", "child.support_view"],
};

export function roleLabel(code) {
  return ADMIN_ROLES.find((role) => role.code === code)?.label ?? code;
}

export function can(admin, permission) {
  return !permission || (admin?.permissions ?? []).includes(permission);
}

export function initialsOf(name) {
  const words = name.trim().split(/\s+/);
  return (words.length > 1 ? words[0][0] + words[words.length - 1][0] : words[0].slice(0, 2)).toUpperCase();
}
