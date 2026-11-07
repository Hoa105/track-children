// Backend hiện dùng một lớp quyền duy nhất cho mọi tài khoản quản trị.
export const ADMIN_ROLES = [
  { code: "admin", label: "Quản trị viên" },
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

// Chỉ dùng để trình bày màn hình quản trị chưa nối API. Quyền phiên đăng nhập
// luôn lấy từ payload backend.
export const ROLE_PERMISSIONS = {
  admin: PERMISSIONS.map((permission) => permission.code),
};

export function roleLabel(code) {
  return ADMIN_ROLES.find((role) => role.code === code)?.label ?? code;
}

// Backend hiện cấp toàn quyền cho mọi admin đang hoạt động (role "admin", permissions rỗng)
export function can(admin, permission) {
  if (!permission || admin?.role === "admin") return true;
  return (admin?.permissions ?? []).includes(permission);
}

export function initialsOf(name) {
  const words = name.trim().split(/\s+/);
  return (words.length > 1 ? words[0][0] + words[words.length - 1][0] : words[0].slice(0, 2)).toUpperCase();
}
