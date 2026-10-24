// Sample data for unfinished admin-management screens only. Authentication uses the backend.
import { AuthError } from "./adminAuth.js";
export { AuthError, login, logout, changePassword, completeFirstLogin, passwordProblem, updateProfile, profileProblem } from "./adminAuth.js";

export const mockAdmins = [
  { id: "a1", email: "lan@trackchildren.vn", fullName: "Lan Nguyễn", role: "super_admin", status: "active", lastLogin: "12/10/2026 08:02", createdAt: "01/06/2026", failed: 0 },
  { id: "a2", email: "thanh@trackchildren.vn", fullName: "Nguyễn Thanh", role: "content_manager", status: "active", lastLogin: "11/10/2026 17:40", createdAt: "03/06/2026", failed: 0 },
  { id: "a3", email: "tri@trackchildren.vn", fullName: "Minh Trí", role: "moderator", status: "active", lastLogin: "12/10/2026 07:15", createdAt: "15/07/2026", failed: 0 },
  { id: "a4", email: "phuong@trackchildren.vn", fullName: "Hà Phương", role: "support", status: "locked", lastLogin: "20/09/2026 10:30", createdAt: "02/08/2026", failed: 0 },
  // Thành viên vừa được thêm — admin đặt mật khẩu tạm, lần đăng nhập đầu phải đổi
  { id: "a5", email: "quang@trackchildren.vn", fullName: "Trần Quang", role: "content_manager", status: "active", lastLogin: null, createdAt: "10/10/2026", failed: 0, mustChangePassword: true },
];

// admin.admin_invitations — token gốc chỉ có trong link mời; DB lưu hash
export const mockInvitations = [
  { id: "i1", token: "demo-invite", email: "quang@trackchildren.vn", fullName: "Trần Quang", role: "content_manager", invitedBy: "Lan Nguyễn", status: "pending", createdAt: "10/10/2026", expiresAt: "17/10/2026" },
  { id: "i2", token: "old-invite", email: "hoa@trackchildren.vn", fullName: null, role: "support", invitedBy: "Lan Nguyễn", status: "expired", createdAt: "01/09/2026", expiresAt: "08/09/2026" },
];


const unavailable = async () => { throw new AuthError("Chức năng này chưa được kết nối backend. Vui lòng liên hệ Super Admin."); };
export const requestPasswordReset = unavailable, getInvitation = unavailable, acceptInvitation = unavailable, checkResetToken = unavailable, resetPassword = unavailable;
