// Xác thực admin — BẢN MOCK, cùng chữ ký với API backend dự kiến
// (docs/api/README.md § Admin auth). Khi backend sẵn sàng chỉ cần thay thân
// các hàm bằng fetch(`${BACKEND}/admin/auth/...`).
import { ROLE_PERMISSIONS } from "./session.js";

const delay = (ms = 350) => new Promise((resolve) => setTimeout(resolve, ms));
const MAX_FAILED_ATTEMPTS = 5;

// admin.admin_users + admin_user_roles (dữ liệu mẫu)
export const mockAdmins = [
  { id: "a1", email: "lan@trackchildren.vn", fullName: "Lan Nguyễn", role: "super_admin", status: "active", lastLogin: "12/10/2026 08:02", createdAt: "01/06/2026", password: "MatKhau@2026", failed: 0 },
  { id: "a2", email: "thanh@trackchildren.vn", fullName: "Nguyễn Thanh", role: "content_manager", status: "active", lastLogin: "11/10/2026 17:40", createdAt: "03/06/2026", password: "MatKhau@2026", failed: 0 },
  { id: "a3", email: "tri@trackchildren.vn", fullName: "Minh Trí", role: "moderator", status: "active", lastLogin: "12/10/2026 07:15", createdAt: "15/07/2026", password: "MatKhau@2026", failed: 0 },
  { id: "a4", email: "phuong@trackchildren.vn", fullName: "Hà Phương", role: "support", status: "locked", lastLogin: "20/09/2026 10:30", createdAt: "02/08/2026", password: "MatKhau@2026", failed: 0 },
  // Thành viên vừa được thêm — admin đặt mật khẩu tạm, lần đăng nhập đầu phải đổi
  { id: "a5", email: "quang@trackchildren.vn", fullName: "Trần Quang", role: "content_manager", status: "active", lastLogin: null, createdAt: "10/10/2026", password: "TamThoi@2026", failed: 0, mustChangePassword: true },
];

// admin.admin_invitations — token gốc chỉ có trong link mời; DB lưu hash
export const mockInvitations = [
  { id: "i1", token: "demo-invite", email: "quang@trackchildren.vn", fullName: "Trần Quang", role: "content_manager", invitedBy: "Lan Nguyễn", status: "pending", createdAt: "10/10/2026", expiresAt: "17/10/2026" },
  { id: "i2", token: "old-invite", email: "hoa@trackchildren.vn", fullName: null, role: "support", invitedBy: "Lan Nguyễn", status: "expired", createdAt: "01/09/2026", expiresAt: "08/09/2026" },
];

const resetTokens = { "demo-reset": "lan@trackchildren.vn" };

export class AuthError extends Error {}

function toSessionAdmin(admin) {
  return { id: admin.id, email: admin.email, fullName: admin.fullName, role: admin.role, permissions: ROLE_PERMISSIONS[admin.role], mustChangePassword: Boolean(admin.mustChangePassword) };
}

// POST /admin/auth/login → { accessToken, admin }  (refresh token trong cookie httpOnly)
export async function login(email, password) {
  await delay();
  const admin = mockAdmins.find((item) => item.email.toLowerCase() === email.trim().toLowerCase());
  // Cùng một thông báo cho sai email / sai mật khẩu để không lộ email nào tồn tại
  const invalid = new AuthError("Email hoặc mật khẩu không đúng.");
  if (!admin) throw invalid;
  if (admin.status === "locked") throw new AuthError("Tài khoản đã bị khóa. Liên hệ Super Admin.");
  if (admin.failed >= MAX_FAILED_ATTEMPTS) throw new AuthError("Sai mật khẩu quá nhiều lần. Thử lại sau 15 phút hoặc đặt lại mật khẩu.");
  if (admin.password !== password) {
    admin.failed += 1;
    throw invalid;
  }
  admin.failed = 0;
  return { accessToken: `mock-${admin.id}`, admin: toSessionAdmin(admin) };
}

// POST /admin/auth/logout — thu hồi phiên hiện tại
export async function logout() {
  await delay(100);
}

// POST /admin/auth/forgot-password — luôn trả 204 (không lộ email có tồn tại hay không)
export async function requestPasswordReset() {
  await delay();
}

// GET /admin/auth/invitations/{token}
export async function getInvitation(token) {
  await delay(200);
  const invitation = mockInvitations.find((item) => item.token === token);
  if (!invitation || invitation.status !== "pending") throw new AuthError("Lời mời không tồn tại, đã được dùng hoặc đã hết hạn.");
  return invitation;
}

// POST /admin/auth/invitations/{token}/accept → { accessToken, admin }
export async function acceptInvitation(token, { fullName, password }) {
  const invitation = await getInvitation(token);
  let admin = mockAdmins.find((item) => item.email === invitation.email);
  if (!admin) {
    admin = { id: `a${Date.now()}`, email: invitation.email, createdAt: "Hôm nay", failed: 0 };
    mockAdmins.push(admin);
  }
  Object.assign(admin, { fullName, role: invitation.role, status: "active", lastLogin: "Vừa xong", password });
  invitation.status = "accepted";
  return { accessToken: `mock-${admin.id}`, admin: toSessionAdmin(admin) };
}

// GET /admin/auth/reset-password/{token}
export async function checkResetToken(token) {
  await delay(200);
  if (!resetTokens[token]) throw new AuthError("Link đặt lại mật khẩu không hợp lệ hoặc đã hết hạn.");
  return { email: resetTokens[token] };
}

// POST /admin/auth/reset-password/{token} — thu hồi mọi phiên cũ của admin
export async function resetPassword(token, password) {
  const { email } = await checkResetToken(token);
  const admin = mockAdmins.find((item) => item.email === email);
  admin.password = password;
  admin.failed = 0;
  delete resetTokens[token];
}

// POST /admin/auth/change-password
export async function changePassword(adminId, currentPassword, newPassword) {
  await delay();
  const admin = mockAdmins.find((item) => item.id === adminId);
  if (!admin || admin.password !== currentPassword) throw new AuthError("Mật khẩu hiện tại không đúng.");
  admin.password = newPassword;
}

// POST /admin/auth/first-login-password — bắt buộc ở lần đăng nhập đầu
// với mật khẩu tạm do admin đặt khi thêm thành viên
export async function completeFirstLogin(adminId, temporaryPassword, newPassword) {
  await delay();
  const admin = mockAdmins.find((item) => item.id === adminId);
  if (!admin || admin.password !== temporaryPassword) throw new AuthError("Mật khẩu được cấp không đúng.");
  if (newPassword === temporaryPassword) throw new AuthError("Mật khẩu mới phải khác mật khẩu được cấp.");
  admin.password = newPassword;
  admin.mustChangePassword = false;
}

// Quy tắc mật khẩu admin — kiểm tra lại ở backend
export function passwordProblem(password, confirm) {
  if (password.length < 10) return "Mật khẩu cần tối thiểu 10 ký tự.";
  if (!/[A-Za-z]/.test(password) || !/\d/.test(password)) return "Mật khẩu cần có cả chữ và số.";
  if (confirm !== undefined && password !== confirm) return "Mật khẩu xác nhận không khớp.";
  return null;
}
