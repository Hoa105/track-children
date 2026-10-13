import React, { createContext, useContext, useState } from "react";
import * as authApi from "./authApi.js";
import { ROLE_PERMISSIONS } from "./session.js";

const STORAGE_KEY = "tc-admin-session";
const AuthContext = createContext(null);

// Chỉ giữ phiên trong sessionStorage (đóng tab là đăng xuất). Khi có backend,
// access token sống ngắn, refresh token nằm trong cookie httpOnly.
function readSession() {
  try {
    const session = JSON.parse(window.sessionStorage.getItem(STORAGE_KEY)) ?? null;
    // Bản mock: tính lại quyền theo vai trò mỗi lần tải trang, để quyền mới thêm vào
    // session.js có hiệu lực ngay. Khi có API thì thay bằng GET /admin/auth/me.
    if (session?.admin) session.admin.permissions = ROLE_PERMISSIONS[session.admin.role] ?? [];
    return session;
  } catch {
    return null;
  }
}

function writeSession(session) {
  try {
    if (session) window.sessionStorage.setItem(STORAGE_KEY, JSON.stringify(session));
    else window.sessionStorage.removeItem(STORAGE_KEY);
  } catch {
    // Trình duyệt chặn storage: phiên chỉ sống trong bộ nhớ
  }
}

export function AuthProvider({ children }) {
  const [session, setSession] = useState(readSession);

  function start(result) {
    writeSession(result);
    setSession(result);
  }

  const value = {
    admin: session?.admin ?? null,
    async login(email, password) {
      start(await authApi.login(email, password));
    },
    async acceptInvitation(token, details) {
      start(await authApi.acceptInvitation(token, details));
    },
    async completeFirstLogin(temporaryPassword, newPassword) {
      await authApi.completeFirstLogin(session.admin.id, temporaryPassword, newPassword);
      start({ ...session, admin: { ...session.admin, mustChangePassword: false } });
    },
    async logout() {
      await authApi.logout();
      start(null);
    },
    updateProfile(changes) {
      start({ ...session, admin: { ...session.admin, ...changes } });
    },
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  return useContext(AuthContext);
}
